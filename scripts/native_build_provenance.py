"""Bind a fresh normal SwiftPM build to its actual verbose compilation trace.

This is build provenance only. Native execution, claim semantics, final source
applicability, resource safety, runtime and item completion remain separate.
Unknown compiler layouts fail closed instead of treating a build plan as execution.
"""
from __future__ import annotations
import base64
import functools
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import zlib
import baseline_producer_witness as witness

SCHEMA = 'autotechno-native-build-provenance.v4'
CHUNK_SCHEMA = 'autotechno-native-build-provenance-chunk.v1'
MAX_METADATA = 128 * 1024 * 1024
MAX_FILES = 50000
ROOT_MODULES = {'AutoTechnoCore': 'Sources/AutoTechnoCore',
                'AutoTechnoDSP': 'Sources/AutoTechnoDSP',
                'AutoTechnoTransport': 'Sources/AutoTechnoTransport',
                'AutoTechnoApp': 'Sources/AutoTechnoApp',
                'AutoTechnoCoreTests': 'Tests/AutoTechnoCoreTests',
                'AutoTechnoAppTests': 'Tests/AutoTechnoAppTests'}


def need(value, label):
    if not value: raise ValueError(label)


def sha(raw): return hashlib.sha256(raw).hexdigest()


def strict(raw):
    def pairs(rows):
        result = {}
        for k,v in rows:
            need(k not in result, 'duplicate provenance JSON key'); result[k]=v
        return result
    def invalid(value): raise ValueError('nonfinite provenance JSON: '+value)
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


def absolute(value):
    need(type(value) is str and 0<len(value)<=8192 and '\x00' not in value and
         not any(ord(c)<32 for c in value) and Path(value).is_absolute() and
         '..' not in Path(value).parts and str(Path(value))==value, 'canonical absolute compiler path')
    return Path(value)


def values(argv, flag):
    result=[]
    for i,arg in enumerate(argv):
        if arg==flag:
            need(i+1<len(argv), 'compiler flag requires a value'); result.append(argv[i+1])
    return result


def dependency_rule(raw):
    """Swift/Clang make dependency output, with escaped paths and continuations."""
    need(type(raw) is bytes and 0<len(raw)<=MAX_METADATA, 'bounded actual dependency output')
    text=raw.decode('utf-8').replace('\\\n','').replace('\\\r\n','')
    rows=[]
    for line in text.splitlines():
        if not line.strip(): continue
        # Darwin paths have no drive colon. An unescaped colon ends the LHS.
        parts=re.split(r'(?<!\\):',line)
        need(len(parts)==2, 'one unambiguous compiler dependency rule')
        target=shlex.split(parts[0]); deps=shlex.split(parts[1])
        need(target and deps, 'nonempty compiler dependency rule')
        need(all(x=='dependencies' or Path(x).is_absolute() for x in target), 'declared absolute target or actual Clang dependency label')
        rows.append(([x if x=='dependencies' else str(absolute(x)) for x in target],[str(absolute(x)) for x in deps]))
    need(rows, 'actual compiler dependency rules required')
    return rows


def commands(raw):
    need(type(raw) is bytes and 0<len(raw)<=MAX_METADATA, 'bounded original verbose build output')
    result=[]
    for line in raw.decode('utf-8').splitlines():
        if not line.startswith(('/', '"/')): continue
        try: args=shlex.split(line)
        except ValueError: raise ValueError('malformed verbose compiler command')
        if not args: continue
        tool=Path(args[0]).name
        if tool not in {'swift-frontend','swiftc','clang','ld','swift-autolink-extract'}: continue
        absolute(args[0]); result.append(args)
    need(result, 'actual verbose compiler commands required, not a SwiftPM plan')
    return result



def clang_arguments(args):
    """Read actual forwarded Clang tokens without confusing -Xcc with a path."""
    if Path(args[0]).name in {'clang','ld'}:return args[1:]
    result=[]
    for i,arg in enumerate(args):
        if arg=='-Xcc':
            need(i+1<len(args) and args[i+1]!='-Xcc','complete actual Clang forwarding')
            result.append(args[i+1])
    return result


def frontend_arguments(args):
    """Interpret Swift driver forwarding without treating -Xfrontend as a path."""
    if Path(args[0]).name=='swift-frontend':return args[1:]
    if Path(args[0]).name!='swiftc':return []
    result=[]
    for i,arg in enumerate(args):
        if arg=='-Xfrontend':
            need(i+1<len(args) and args[i+1]!='-Xfrontend',
                 'complete actual Swift frontend forwarding')
            result.append(args[i+1])
    return result


def build_commands(raw, build):
    """Manifest evaluation is not a compiled input to the registered products."""
    build=absolute(str(build));result=[]
    for args in commands(raw):
        outputs=values(args,'-o')+values(args,'-emit-module-path')
        inside=[p for p in outputs if Path(p).is_absolute() and Path(p).is_relative_to(build)]
        root=any(name in ROOT_MODULES for name in values(args,'-module-name'))
        if root and outputs:need(len(inside)==len(outputs),'root-module outputs inside registered build')
        if inside:
            need(len(inside)==len(outputs),'one registered output scope per actual command')
            result.append(args)
    need(result,'actual commands emitting registered build outputs required')
    return result


def link_lists(args):
    forwarded=[x for x in args if x!='-Xlinker']
    return values(forwarded,'-filelist')+[x[1:] for x in forwarded if x.startswith('@/')]


def transient_link_path(path):
    p=absolute(path)
    return bool(re.fullmatch(r'inputs-[0-9]+[.]LinkFileList',p.name) and
                p.parent.name.startswith('TemporaryDirectory.') and p.parent.parent.name=='T')


def collect_metadata(raw,build):
    """Read actual emitted files after the standard driver retains intermediates."""
    build=absolute(str(build));metadata={};errors=[]
    paths={str(p) for p in build.rglob('*') if p.is_file() and
           (p.suffix=='.d' or p.name.endswith('.LinkFileList')) and
           not {'checkouts','repositories'}&set(p.relative_to(build).parts)}
    for args in build_commands(raw,build):
        if Path(args[0]).name in {'clang','ld'} and '-c' not in args:
            for path in link_lists(args):
                p=absolute(path)
                need(p.is_relative_to(build) or transient_link_path(path),'known actual retained linker input')
                paths.add(path)
    for path in sorted(paths):
        try:
            p=absolute(path);before=p.stat();content=p.read_bytes();after=p.stat()
            need(0<len(content)<=MAX_METADATA and
                 (before.st_ino,before.st_size,before.st_mtime_ns)==(after.st_ino,after.st_size,after.st_mtime_ns),
                 'stable actual emitted compiler metadata')
            metadata[path]=content
        except (OSError,ValueError) as exc:errors.append(str(exc))
    return metadata,errors

def trace(raw, root, metadata, build):
    """Reconstruct actual source/object/module/link edges from original commands."""
    root=absolute(str(root)); compiled={name:set() for name in ROOT_MODULES}
    objects=set(); modules=set(); tools=set(); linked=set(); dependencies=set(); c_sources=set(); sdks=set(); swift_objects=set(); parsed_dependencies=set(); dependency_targets=set()
    parsed=build_commands(raw,build); link_commands=[]
    for args in parsed:
        tools.add(str(absolute(args[0]))); tool=Path(args[0]).name
        clang=clang_arguments(args);frontend=frontend_arguments(args)
        sdks.update(str(absolute(x)) for x in values(args,'-sdk')+values(clang,'-isysroot')+values(clang,'--sysroot'))
        for p in values(frontend,'-vfsoverlay')+values(clang,'-ivfsoverlay')+values(clang,'-module-map-file'):
            dependencies.add(str(absolute(p)))
        for p in args:
            if p.startswith('-fmodule-map-file='):
                dependencies.add(str(absolute(p.split('=',1)[1])))
        for plugin in values(frontend,'-load-plugin-executable'):
            dependencies.add(str(absolute(plugin.split('#',1)[0])))
        if tool=='swift-frontend' and '-c' in args:
            names=values(args,'-module-name'); need(len(names)==1,'one actual compile module')
            primaries=values(args,'-primary-file')
            sources=[str(absolute(x)) for x in args[1:] if x.endswith('.swift') and Path(x).is_absolute()]
            out=values(args,'-o')
            need(out and all(x.endswith('.o') for x in out), 'actual frontend object outputs')
            need(not primaries or len(primaries)==len(out), 'exact primary-file/object multiplicity')
            actual=primaries if primaries else sources
            need(actual, 'actual source compilation required')
            objects.update(str(absolute(x)) for x in out);swift_objects.update(str(absolute(x)) for x in out)
            if names[0] in compiled:
                compiled[names[0]].update(str(absolute(x)) for x in actual)
        elif tool=='clang' and '-c' in args:
            out=values(args,'-o'); need(len(out)==1 and out[0].endswith('.o'),'actual Clang object output')
            objects.add(str(absolute(out[0])))
            c_sources.update(str(absolute(x)) for x in values(args,'-c'))
        elif tool=='swiftc' and '-modulewrap' in args:
            out=values(args,'-o');need(len(out)==1 and out[0].endswith('.o'),'actual modulewrap object')
            objects.add(str(absolute(out[0])))
        if tool=='swift-frontend':
            for p in values(args,'-emit-module-path')+values(args,'-o'):
                if p.endswith(('.swiftmodule','.pcm')): modules.add(str(absolute(p)))
            for p in values(args,'-emit-dependencies-path'):
                p=str(absolute(p)); need(p in metadata,'original emitted dependency bytes required');parsed_dependencies.add(p)
                emitted=set(values(args,'-o')+values(args,'-emit-module-path')+values(args,'-emit-module-doc-path')+values(args,'-emit-module-source-info-path')+values(args,'-emit-objc-header-path')+values(args,'-emit-abi-descriptor-path'))
                for target,deps in dependency_rule(metadata[p]):
                    need(set(target)&emitted, 'dependency rule belongs to actual frontend output')
                    dependencies.update(deps);dependency_targets.update(target)
        if tool=='clang':
            for p in values(args,'-MF'):
                p=str(absolute(p));need(p in metadata,'original Clang dependency bytes required');parsed_dependencies.add(p)
                targets=values(args,'-MT') or values(args,'-o')
                for target,deps in dependency_rule(metadata[p]):
                    need(target==targets, 'Clang dependency target equals actual command -MT/output')
                    dependencies.update(deps)
        if tool in {'clang','ld'} and '-c' not in args and values(args,'-o'):
            outs=values(args,'-o'); need(len(outs)==1,'actual linker output identity')
            inputs=[x for x in args if x.endswith(('.o','.a')) and Path(x).is_absolute()]
            lists=link_lists(args)
            for p in lists:
                p=str(absolute(p));need(p in metadata,'original actual linker file list required')
                for row in metadata[p].decode('utf-8').splitlines():
                    tokens=shlex.split(row)
                    need(len(tokens)==1,'one exact link input per file-list row');inputs.append(tokens[0])
            if inputs:
                link_commands.append(dict(output=str(absolute(outs[0])),inputs=sorted(set(str(absolute(x)) for x in inputs))))
    # Batched Swift frontends route supplementary outputs through a temporary
    # output map. Authenticate the actual emitted dependency files against the
    # actual object/module outputs, rather than trusting that requested map.
    remaining=[(p,dependency_rule(raw)) for p,raw in metadata.items() if p.endswith('.d') and p not in parsed_dependencies]
    for _,rules in remaining:
        for _,deps in rules:dependencies.update(deps)
    allowed_targets=objects|modules|{p for p in dependencies if p.endswith(('.pcm','.swiftmodule'))}
    for _,rules in remaining:
        for target,_ in rules:
            need(set(target)&allowed_targets,'emitted dependency target must belong to actual compile output or consumed module')
            dependency_targets.update(target)
    need(swift_objects<=dependency_targets,'every actual Swift object requires original emitted dependencies')
    for name,directory in ROOT_MODULES.items():
        need(compiled[name], 'actual compiled root module required: '+name)
        # The validator below separates exact committed module sources from the
        # sole normal SwiftPM-generated DSP Bundle.module accessor.
    need(objects and modules and link_commands and dependencies,'complete actual compilation/link/dependency trace')
    need(len(sdks)==1,'one actual macOS SDK in compiler trace')
    dependencies.update(str(Path(sdk)/'SDKSettings.json') for sdk in sdks)
    need(c_sources,'actual C compilation required')
    for link in link_commands:
        linked.update(link['inputs'])
    # External SDK archive inputs are support dependencies; every build-owned
    # object in a link must have an actual compiler emission in this same trace.
    for p in linked:
        if p.endswith('.o'): need(p in objects, 'linked object lacks actual fresh compiler emission')
    return dict(compiled={k:sorted(v) for k,v in compiled.items()},cSources=sorted(c_sources),sdkPaths=sorted(sdks),objects=sorted(objects),
                modules=sorted(modules),tools=sorted(tools),dependencies=sorted(dependencies),
                links=link_commands)


def validate_sources(edges,root,build,git_files):
    expected={m:sorted(str(root/n) for n in git_files if n.startswith(directory+'/') and n.endswith('.swift')) for m,directory in ROOT_MODULES.items()}
    for module,directory in ROOT_MODULES.items():
        actual=edges['compiled'][module]
        tracked=[p for p in actual if Path(p).is_relative_to(root/directory)]
        need(tracked==expected[module], 'complete actually compiled committed source/test modules')
        generated=[p for p in actual if p not in tracked]
        if module=='AutoTechnoDSP':
            need(len(generated)==1 and Path(generated[0]).is_relative_to(build) and
                 Path(generated[0]).parts[-3:]==('AutoTechnoDSP.build','DerivedSources','resource_bundle_accessor.swift'),
                 'one normal SwiftPM DSP resource accessor, no additional source')
        else:need(not generated, 'no untracked root-module compilation source')
    need(set(edges['cSources'])>=set(str(root/n) for n in git_files if n.startswith('Sources/CAutoTechnoRealtime/') and n.endswith('.c')),
         'complete actual realtime C compilation')


def file_record(path):
    p=absolute(str(path)); resolved=p.resolve(strict=True)
    need(p.is_file() and 0<=p.stat().st_size<=512*1024*1024,'bounded regular compiled input/output')
    before=p.stat();digest=witness.file_hash(resolved);after=p.stat()
    need((before.st_ino,before.st_size,before.st_mtime_ns)==(after.st_ino,after.st_size,after.st_mtime_ns), 'compiled file changed during provenance capture')
    return dict(path=str(p),resolvedPath=str(resolved),bytes=before.st_size,sha256=digest)


def check_files(records):
    need(type(records) is list and 0<len(records)<=MAX_FILES,'bounded compiled file inventory')
    names=[]
    for record in records:
        need(type(record) is dict and set(record)=={'path','resolvedPath','bytes','sha256'}, 'compiled file fields')
        try:
            observed=file_record(record['path'])
        except (OSError, ValueError) as error:
            raise ValueError('compiled build input/output unavailable: '+record['path']) from error
        need(observed==record,'compiled build input/output changed: '+
             json.dumps(dict(expected=record,observed=observed),sort_keys=True))
        names.append(record['path'])
    need(names==sorted(set(names)),'unique ordered compiled inventory')


def pack(raw):
    need(type(raw) is bytes and 0<len(raw)<=MAX_METADATA,'bounded original build metadata')
    return dict(bytes=len(raw),sha256=sha(raw),zlibBase64=base64.b64encode(zlib.compress(raw)).decode())


def unpack(record):
    need(type(record) is dict and set(record)=={'bytes','sha256','zlibBase64'} and
         type(record['bytes']) is int and 0<record['bytes']<=MAX_METADATA and
         type(record['sha256']) is str and re.fullmatch('[0-9a-f]{64}',record['sha256']) and
         type(record['zlibBase64']) is str and len(record['zlibBase64'])<=MAX_METADATA*2,'bounded original metadata record')
    decoder=zlib.decompressobj();raw=decoder.decompress(base64.b64decode(record['zlibBase64'],validate=True),MAX_METADATA+1)
    need(decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail and
         len(raw)==record['bytes'] and sha(raw)==record['sha256'],'exact complete original build metadata bytes')
    return raw


def inventory(root):
    def git(*args):return subprocess.check_output(['git','--no-replace-objects','-c','core.fsmonitor=false',*args],cwd=root)
    source=git('rev-parse','HEAD').decode().strip();need(re.fullmatch('[0-9a-f]{40}',source),'exact build source')
    need(not git('status','--porcelain','--untracked-files=all').strip(),'clean immutable native source')
    names=git('ls-files','-z').decode().strip('\0').split('\0');need(0<len(names)<=MAX_FILES,'complete tracked build inputs')
    records={n:sha(witness.dependency.regular_bytes(root,n)) for n in names}
    need(all(sha(git('show',source+':'+n))==d for n,d in records.items()), 'all actual native source bytes equal Git')
    return dict(source=source,files=records)


def runtime_files(build):
    selected=[]
    for p in build.rglob('*'):
        if not p.is_file() or 'checkouts' in p.relative_to(build).parts or 'repositories' in p.relative_to(build).parts:continue
        if p.suffix in {'.o','.a','.dylib','.so','.swiftmodule','.swiftdoc','.swiftsourceinfo','.pcm','.swiftinterface','.swiftdeps','.d','.yaml','.LinkFileList'} or p.name in {'description.json','output-file-map.json'} or '.bundle/' in str(p) or '.xctest/' in str(p) or os.access(p,os.X_OK):
            selected.append(str(p))
    need(0<len(selected)<=MAX_FILES,'complete bounded actual compiled/runtime inventory')
    return sorted(set(selected))


def prepare(root, build, output, run_logged):
    """Fresh normal SwiftPM build once. No native benchmark or probe is executed."""
    root=root.resolve();build=absolute(str(build));output=absolute(str(output))
    need(not build.exists() and not output.exists() and not build.is_relative_to(root) and not output.is_relative_to(root),'absent normal build/output outside immutable source')
    before=inventory(root);output.mkdir(parents=True)
    driver=str(Path(shutil.which('swift') or '').resolve());absolute(driver);need(Path(driver).is_file(),'actual normal Swift driver')
    argv=['swift','build','-v','--build-tests','-Xswiftc','-save-temps','--build-path',str(build)]
    log=output/'original-build.log';result=run_logged(argv,root,log)
    (output/'build-command-status.json').write_text(json.dumps(dict(command=argv,exitCode=result.returncode),sort_keys=True)+'\n')
    need(type(result.returncode) is int and result.returncode==0,'original normal native build failed; retain its output')
    need(inventory(root)==before,'source changed during original normal build')
    metadata,errors=collect_metadata(log.read_bytes(),build)
    need(metadata and sum(map(len,metadata.values()))<=MAX_METADATA,'bounded complete original compiler dependency/link output')
    # Original partial metadata survives any subsequent strict proof refusal.
    (output/'original-compiler-metadata.json').write_text(json.dumps({p:pack(raw) for p,raw in sorted(metadata.items())},sort_keys=True)+'\n')
    (output/'retained-link-metadata-status.json').write_text(json.dumps(dict(errors=errors,paths=sorted(metadata)),sort_keys=True)+'\n')
    need(not errors,'actual retained linker input capture failed: '+'; '.join(errors[:4]))
    edges=trace(log.read_bytes(),root,metadata,build)
    validate_sources(edges,root,build,before['files'])
    bin_path=Path(subprocess.check_output(['swift','build','--show-bin-path','--build-path',str(build)],cwd=root,text=True).strip())
    image=witness.registered_image(bin_path,build)
    need(any(row['output']==str(image) for row in edges['links']),'actual test image is the original linked output')
    runtime=runtime_files(build)
    names=set(runtime)|{driver}|set(edges['objects'])|set(edges['modules'])|set(edges['tools'])|set(edges['dependencies'])
    names.update(p for row in edges['compiled'].values() for p in row)
    names.update(edges['cSources']);names.update(metadata)
    names.update(x for row in edges['links'] for x in row['inputs'])
    files=[file_record(p) for p in sorted(names)];need(len(files)<=MAX_FILES,'bounded exact complete build file inventory')
    record=dict(schema=SCHEMA,source=before['source'],implementationSHA256=sha(Path(__file__).read_bytes()),
        root=str(root),buildPath=str(build),swiftDriverPath=driver,runtimeFilePaths=runtime,command=argv,trackedInputs=before['files'],
        originalBuild=pack(log.read_bytes()),metadata={p:pack(raw) for p,raw in sorted(metadata.items())},
        trace=edges,files=files,compiledImage=str(image),exitCode=0)
    validate(record,before['source'],before['files'])
    need(inventory(root)==before,'source changed before build provenance sealing');check_files(files)
    (output/'build-provenance.json').write_text(json.dumps(record,sort_keys=True)+'\n')
    return record


def validate(record, source, git_files):
    """Check original byte/trace bindings; external run authentication is separate."""
    need(type(record) is dict and set(record)=={'schema','source','implementationSHA256','root','buildPath','swiftDriverPath','runtimeFilePaths','command','trackedInputs','originalBuild','metadata','trace','files','compiledImage','exitCode'},'complete original native build fields')
    need(record['schema']==SCHEMA and record['source']==source and re.fullmatch('[0-9a-f]{40}',source) and
         record['implementationSHA256']==sha(Path(__file__).read_bytes()),'known exact source/build provenance implementation')
    root=absolute(record['root']);build=absolute(record['buildPath']);image=absolute(record['compiledImage'])
    need(not build.is_relative_to(root) and image.is_relative_to(build),'original build/image outside immutable checkout')
    need(record['command']==['swift','build','-v','--build-tests','-Xswiftc','-save-temps','--build-path',str(build)] and type(record['exitCode']) is int and record['exitCode']==0,'original normal complete build command')
    need(record['trackedInputs']==git_files and type(git_files) is dict and git_files and
         all(type(n) is str and type(d) is str and re.fullmatch('[0-9a-f]{64}',d) for n,d in git_files.items()),'complete original native source inventory matches exact Git source')
    need(git_files.get('scripts/native_build_provenance.py')==record['implementationSHA256'] and
         {'Package.swift','Package.resolved'}<=set(git_files),'original build implementation and package resolution bound')
    need(type(record['metadata']) is dict and 0<len(record['metadata'])<=MAX_FILES,'original emitted compiler metadata')
    metadata={str(absolute(p)):unpack(value) for p,value in record['metadata'].items()}
    need(all((Path(p).is_relative_to(build) and (p.endswith('.d') or p.endswith('.LinkFileList'))) or transient_link_path(p) for p in metadata),'actual emitted metadata or known transient linker input')
    need(sum(map(len,metadata.values()))<=MAX_METADATA,'aggregate compiler metadata bound')
    edges=trace(unpack(record['originalBuild']),root,metadata,build);need(edges==record['trace'],'reconstructed actual compiler/link/dependency trace')
    validate_sources(edges,root,build,git_files)
    need(any(row['output']==str(image) for row in edges['links']),'original native test image link')
    files=record['files'];need(type(files) is list and 0<len(files)<=MAX_FILES,'actual original compiled files required')
    names=[]
    for row in files:
        need(type(row) is dict and set(row)=={'path','resolvedPath','bytes','sha256'},'exact original compiled file fields')
        absolute(row['path']);absolute(row['resolvedPath'])
        need(type(row['bytes']) is int and 0<=row['bytes']<=512*1024*1024 and type(row['sha256']) is str and re.fullmatch('[0-9a-f]{64}',row['sha256']),'actual original compiled file bytes/digest')
        names.append(row['path'])
    need(names==sorted(set(names)),'unique ordered original compiled files')
    runtime=record['runtimeFilePaths'];need(type(runtime) is list and runtime==sorted(set(runtime)) and runtime and all(str(absolute(p))==p and Path(p).is_relative_to(build) for p in runtime),'complete original runtime file inventory')
    driver=str(absolute(record['swiftDriverPath']))
    persistent_metadata={p for p in metadata if Path(p).is_relative_to(build)}
    actual_transient={str(absolute(p)) for args in build_commands(unpack(record['originalBuild']),build) for p in link_lists(args) if not Path(p).is_relative_to(build)}
    need(set(metadata)-persistent_metadata==actual_transient,'exact actual transient linker input inventory')
    required=set(metadata)|set(runtime)|{driver}|set(edges['objects'])|set(edges['modules'])|set(edges['tools'])|set(edges['dependencies'])|{str(image)}
    required.update(p for group in edges['compiled'].values() for p in group)
    required.update(edges['cSources'])
    required.update(x for link in edges['links'] for x in link['inputs'])
    need(required<=set(names),'all original compilation/link/dependency inputs and outputs bound')
    positive=set(edges['objects'])|set(edges['modules'])|set(edges['tools'])|{str(image),driver}
    need(all(row['bytes']>0 for row in files if row['path'] in positive),'nonempty actual compiler/object/module/image bytes')
    lookup={row['path']:row for row in files}
    for name,raw in metadata.items():
        need(lookup[name]['sha256']==sha(raw) and lookup[name]['bytes']==len(raw),'exact emitted dependency/link metadata equals actual pinned bytes')
    resources={n:d for n,d in git_files.items() if n.startswith('Sources/AutoTechnoDSP/Resources/')}
    need(resources,'original committed DSP resources required')
    need(len([p for p in runtime if '/AutoTechno_AutoTechnoDSP.bundle/' in p])==len(resources),'no missing or extra actual DSP runtime resources')
    for name,digest in resources.items():
        suffix='/AutoTechno_AutoTechnoDSP.bundle/'+name.split('Sources/AutoTechnoDSP/Resources/',1)[1]
        matches=[p for p in runtime if p.endswith(suffix)]
        need(len(matches)==1 and lookup[matches[0]]['sha256']==digest,'complete actual source-to-runtime DSP resource bytes')
    for name,digest in git_files.items():
        if str(root/name) in lookup:need(lookup[str(root/name)]['sha256']==digest,'actual compiled original source bytes equal Git')
    return dict(schema=SCHEMA,source=source,actualVerboseCompileTraceVerified=True,
        compiledSourceFiles=sum(map(len,edges['compiled'].values())),linkedImageSHA256=lookup[str(image)]['sha256'],
        originalBuildFileBindings=len(files),nativeExecutionAuthenticated=False,
        fullAlgorithmicAcceptanceVerified=False,runtimeQualification=False,item39Complete=False)


def record_digest(record):
    return sha(json.dumps(record,sort_keys=True,separators=(',',':'),allow_nan=False).encode())


def emit(record):
    raw=json.dumps(record,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
    need(len(raw)<=MAX_METADATA,'bounded complete original native build record')
    encoded=base64.b64encode(zlib.compress(raw)).decode();size=4096
    for index,offset in enumerate(range(0,len(encoded),size)):
        print(json.dumps(dict(schema=CHUNK_SCHEMA,source=record['source'],index=index,
            chunks=(len(encoded)+size-1)//size,bytes=len(raw),sha256=sha(raw),
            payload=encoded[offset:offset+size])),flush=True)


def decode(text,source):
    rows=[]
    for line in text.splitlines():
        start=line.find('{')
        if start<0:continue
        try:row=strict(line[start:])
        except ValueError:continue
        if type(row) is dict and row.get('schema')==CHUNK_SCHEMA:rows.append(row)
    need(0<len(rows)<=MAX_METADATA//4096+1,'complete original native build chunks required')
    common=set();indices=set()
    for row in rows:
        need(set(row)=={'schema','source','index','chunks','bytes','sha256','payload'} and row['source']==source and
             type(row['chunks']) is int and row['chunks']==len(rows),'native build chunk source/count')
        need(type(row['index']) is int and 0<=row['index']<len(rows) and row['index'] not in indices,'unique native build chunk index')
        need(type(row['bytes']) is int and 0<row['bytes']<=MAX_METADATA and type(row['sha256']) is str and re.fullmatch('[0-9a-f]{64}',row['sha256']) and
             type(row['payload']) is str and 0<len(row['payload'])<=4096,'bounded native build chunk')
        indices.add(row['index']);common.add((row['bytes'],row['sha256']))
    need(len(common)==1,'one original native build record')
    decoder=zlib.decompressobj();raw=decoder.decompress(base64.b64decode(''.join(r['payload'] for r in sorted(rows,key=lambda r:r['index'])),validate=True),MAX_METADATA+1)
    size,digest=next(iter(common))
    need(decoder.eof and not decoder.unconsumed_tail and not decoder.unused_data and len(raw)==size and sha(raw)==digest,'exact complete original native build transport')
    return strict(raw)


def test_command(record, *arguments):
    """Keep SwiftPM planning identical to the original verbose save-temps build.

    Even --skip-build discovery can regenerate pinned debug.yaml/description.json
    when the original compiler options are omitted. Never recapture those files
    or exempt their hashes: invoke the same build configuration instead.
    """
    build=record['buildPath']
    need(record['command']==['swift','build','-v','--build-tests','-Xswiftc',
         '-save-temps','--build-path',build], 'known original test build configuration')
    return ['swift','test','-v','-Xswiftc','-save-temps','--build-path',build,*arguments]


def guard(record,root):
    need(inventory(root)==dict(source=record['source'],files=record['trackedInputs']),'original build source changed before/during native tests')
    need(str(Path(shutil.which('swift') or '').resolve())==record['swiftDriverPath'],'normal Swift driver changed before/during native tests')
    check_files(record['files'])
    need(runtime_files(Path(record['buildPath']))==record['runtimeFilePaths'],
        'compiled/runtime file inventory changed before/during native tests')


@functools.lru_cache(maxsize=8)
def git_source_files(root,source):
    """Read the exact complete original Git tree independently of build metadata."""
    need(re.fullmatch('[0-9a-f]{40}',source),'exact original source Git commit')
    args=['git','--no-replace-objects','-c','core.fsmonitor=false','-C',str(root)]
    rows=subprocess.check_output(args+['ls-tree','-r','-z',source]).split(b'\0');entries=[]
    for row in rows:
        if not row:continue
        meta,name=row.split(b'\t',1);mode,kind,oid=meta.split()
        need(kind==b'blob' and mode in (b'100644',b'100755'),'regular complete source Git tree')
        entries.append((name.decode(),oid.decode()))
    need(0<len(entries)<=MAX_FILES,'complete bounded source Git tree')
    data=subprocess.check_output(args+['cat-file','--batch'],input=('\n'.join(oid for _,oid in entries)+'\n').encode())
    result={};offset=0
    for name,oid in entries:
        end=data.index(b'\n',offset);header=data[offset:end].split();need(header[:2]==[oid.encode(),b'blob'],'exact Git source blob response')
        length=int(header[2]);offset=end+1;raw=data[offset:offset+length];need(len(raw)==length and data[offset+length:offset+length+1]==b'\n','complete Git source blob')
        result[name]=sha(raw);offset+=length+1
    need(offset==len(data),'complete exact source Git response')
    return result


def preserve_failure(output,source,error):
    """Preserve a real build or proof failure without creating a success record."""
    log=output/'original-build.log'
    if not log.is_file():return None
    raw=log.read_bytes();need(len(raw)<=MAX_METADATA,'oversized build log remains in original artifact')
    status=output/'build-command-status.json'
    result=dict(schema='autotechno-native-build-failure.v1',source=source,
        implementationSHA256=sha(Path(__file__).read_bytes()),reason=type(error).__name__+': '+str(error),
        originalBuild=pack(raw) if raw else None,originalOutputBytes=len(raw),
        originalCommandStatus=strict(status.read_bytes()) if status.is_file() else None,
        buildProvenanceAuthenticated=False,nativeExecutionAuthenticated=False,
        runtimeQualification=False,item39Complete=False)
    (output/'original-build-failure.json').write_text(json.dumps(result,sort_keys=True)+'\n')
    emit(result);return result
