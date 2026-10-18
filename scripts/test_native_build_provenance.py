"""Synthetic compiler/receipt attacks only; fixtures are never native evidence."""
import contextlib
import copy
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parent))
import native_build_provenance as build

SOURCE='a'*40


def fixture(source=SOURCE):
    root='/checkout';out='/native-build';sdk='/SDK/MacOSX.sdk';frontend='/Toolchain/swift-frontend';clang='/Toolchain/clang';driver='/Toolchain/swift'
    git_files={'Package.swift':build.sha(b'package'),'Package.resolved':build.sha(b'resolution'),
               'scripts/native_build_provenance.py':build.sha(Path(build.__file__).read_bytes())}
    raw_files={};metadata={};lines=[];objects=[]
    def content(path,raw=b'fixture compiled bytes'):
        raw_files[path]=raw;return path
    for module,directory in build.ROOT_MODULES.items():
        relative=directory+'/Fixture.swift';raw=('original '+relative).encode();git_files[relative]=build.sha(raw);content(root+'/'+relative,raw)
        obj=out+'/'+module+'.o';mod=out+'/'+module+'.swiftmodule';dep=out+'/'+module+'.d';objects.append(obj)
        content(obj);content(mod);metadata[dep]=(obj+' : '+root+'/'+relative+'\n').encode()
        lines.append(f'{frontend} -frontend -c -primary-file {root}/{relative} -module-name {module} -sdk {sdk} -emit-dependencies-path {dep} -emit-module-path {mod} -o {obj}')
    accessor=out+'/AutoTechnoDSP.build/DerivedSources/resource_bundle_accessor.swift';content(accessor,b'generated resource accessor')
    obj=out+'/DSP-accessor.o';objects.append(obj);content(obj);dep=out+'/DSP-accessor.d';metadata[dep]=(obj+' : '+accessor+'\n').encode()
    lines.append(f'{frontend} -frontend -c -primary-file {accessor} -module-name AutoTechnoDSP -sdk {sdk} -emit-dependencies-path {dep} -o {obj}')
    c='Sources/CAutoTechnoRealtime/Fixture.c';git_files[c]=build.sha(b'C source');content(root+'/'+c,b'C source');obj=out+'/C.o';objects.append(obj);content(obj)
    dep=out+'/C.d';metadata[dep]=('dependencies : '+root+'/'+c+'\n').encode();lines.append(f'{clang} -c {root}/{c} -isysroot {sdk} -MT dependencies -MF {dep} -o {obj}')
    image=out+'/arm64-apple-macosx/debug/AutoTechnoPackageTests.xctest/Contents/MacOS/AutoTechnoPackageTests';content(image)
    lst=out+'/Objects.LinkFileList';metadata[lst]=('\n'.join(objects)+'\n').encode();lines.append(f'{clang} -o {image} -filelist {lst}')
    content(frontend);content(clang);content(driver);content(sdk+'/SDKSettings.json',b'SDK settings')
    relative='Sources/AutoTechnoDSP/Resources/fixture.json';git_files[relative]=build.sha(b'resource');content(root+'/'+relative,b'resource');content(out+'/AutoTechno_AutoTechnoDSP.bundle/fixture.json',b'resource')
    raw=('\n'.join(lines)+'\nBuild complete!\n').encode();edges=build.trace(raw,root,metadata)
    for p,v in metadata.items():content(p,v)
    runtime=sorted(p for p in raw_files if p.startswith(out+'/'))
    records=[dict(path=p,resolvedPath=p,bytes=len(v),sha256=build.sha(v)) for p,v in sorted(raw_files.items())]
    return dict(schema=build.SCHEMA,source=source,implementationSHA256=build.sha(Path(build.__file__).read_bytes()),
        root=root,buildPath=out,swiftDriverPath=driver,runtimeFilePaths=runtime,
        command=['swift','build','-v','--build-tests','--build-path',out],trackedInputs=git_files,
        originalBuild=build.pack(raw),metadata={p:build.pack(v) for p,v in metadata.items()},trace=edges,files=records,compiledImage=image,exitCode=0)


class NativeBuildProvenanceTests(unittest.TestCase):
    def test_actual_trace_has_only_build_scope(self):
        r=fixture();result=build.validate(r,SOURCE,r['trackedInputs'])
        self.assertTrue(result['actualVerboseCompileTraceVerified'])
        self.assertEqual(result['compiledSourceFiles'],7)
        for key in ['nativeExecutionAuthenticated','fullAlgorithmicAcceptanceVerified','runtimeQualification','item39Complete']:
            self.assertIs(result[key],False)

    def test_requested_plan_or_success_banner_is_not_compilation(self):
        for raw in [b'Build complete!\n',b'{"commands":{"compile":"swift-frontend"}}\n',b'/Toolchain/swiftc -module-name AutoTechnoCore\n']:
            r=fixture();r['originalBuild']=build.pack(raw)
            with self.subTest(raw=raw),self.assertRaises(ValueError):build.validate(r,SOURCE,r['trackedInputs'])

    def test_one_missing_real_compilation_cannot_borrow_the_other_modules(self):
        r=fixture();raw=build.unpack(r['originalBuild']);raw=b'\n'.join(line for line in raw.splitlines() if b'-module-name AutoTechnoCore ' not in line)+b'\n';r['originalBuild']=build.pack(raw);del r['metadata']['/native-build/AutoTechnoCore.d']
        with self.assertRaisesRegex(ValueError,'actual compiled root module'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_uncompiled_linked_object_refuses(self):
        r=fixture();p='/native-build/Objects.LinkFileList';r['metadata'][p]=build.pack(build.unpack(r['metadata'][p])+b'/native-build/stale.o\n')
        with self.assertRaisesRegex(ValueError,'lacks actual fresh compiler emission'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_source_and_object_trace_substitution_refuses_even_with_changed_metadata(self):
        r=fixture();raw=build.unpack(r['originalBuild']).replace(b'/checkout/Sources/AutoTechnoCore/Fixture.swift',b'/checkout/Sources/AutoTechnoCore/Other.swift');r['originalBuild']=build.pack(raw)
        metadata={p:build.unpack(v) for p,v in r['metadata'].items()};r['trace']=build.trace(raw,r['root'],metadata)
        with self.assertRaisesRegex(ValueError,'compiled committed source'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_source_file_hash_cannot_be_changed_with_a_self_consistent_trace(self):
        r=fixture();next(row for row in r['files'] if row['path']=='/checkout/Sources/AutoTechnoCore/Fixture.swift')['sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'source bytes equal Git'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_independent_git_inventory_must_equal_all_recorded_inputs(self):
        r=fixture();git=dict(r['trackedInputs']);git['Package.swift']='0'*64
        with self.assertRaisesRegex(ValueError,'matches exact Git'):build.validate(r,SOURCE,git)

    def test_missing_tool_object_module_dependency_or_image_hash_refuses(self):
        for name in ['/Toolchain/swift-frontend','/native-build/AutoTechnoCore.o','/native-build/AutoTechnoCore.swiftmodule','/SDK/MacOSX.sdk/SDKSettings.json',fixture()['compiledImage']]:
            r=fixture();r['files']=[row for row in r['files'] if row['path']!=name]
            with self.subTest(name=name),self.assertRaisesRegex(ValueError,'inputs and outputs bound'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_changed_missing_and_extra_runtime_resources_refuse(self):
        for mutation in ['change','missing','extra']:
            r=fixture();name='/native-build/AutoTechno_AutoTechnoDSP.bundle/fixture.json'
            if mutation=='change':next(row for row in r['files'] if row['path']==name)['sha256']='0'*64
            elif mutation=='missing':r['runtimeFilePaths'].remove(name)
            else:
                p='/native-build/AutoTechno_AutoTechnoDSP.bundle/extra.json';r['runtimeFilePaths']=sorted(r['runtimeFilePaths']+[p]);r['files']=sorted(r['files']+[dict(path=p,resolvedPath=p,bytes=1,sha256='0'*64)],key=lambda x:x['path'])
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):build.validate(r,SOURCE,r['trackedInputs'])

    def test_duplicate_or_unbound_file_records_refuse(self):
        r=fixture();r['files'].append(r['files'][0])
        with self.assertRaisesRegex(ValueError,'unique ordered'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_missing_or_modified_original_emitted_dependencies_refuse(self):
        for mutation in ['missing','hash','foreign']:
            r=fixture();p='/native-build/AutoTechnoCore.d'
            if mutation=='missing':del r['metadata'][p]
            elif mutation=='hash':r['metadata'][p]['sha256']='0'*64
            else:r['metadata']['/elsewhere/foreign.d']=r['metadata'].pop(p)
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):build.validate(r,SOURCE,r['trackedInputs'])

    def test_dependency_target_must_match_its_actual_compiler_command(self):
        for p,raw in [('/native-build/C.d',b'foreign : /checkout/Sources/CAutoTechnoRealtime/Fixture.c\n'),
                      ('/native-build/AutoTechnoCore.d',b'/native-build/stale.o : /checkout/Sources/AutoTechnoCore/Fixture.swift\n')]:
            r=fixture();r['metadata'][p]=build.pack(raw)
            with self.subTest(path=p),self.assertRaises(ValueError):build.validate(r,SOURCE,r['trackedInputs'])

    def test_batched_supplementary_outputs_bind_actual_emitted_dependencies(self):
        r=fixture();raw=build.unpack(r['originalBuild'])
        import re
        raw=re.sub(rb' -emit-dependencies-path [^ \n]+',b' -supplementary-output-file-map /temporary/outputs',raw)
        r['originalBuild']=build.pack(raw);metadata={p:build.unpack(v) for p,v in r['metadata'].items()};r['trace']=build.trace(raw,r['root'],metadata)
        self.assertTrue(build.validate(r,SOURCE,r['trackedInputs'])['actualVerboseCompileTraceVerified'])
        # A requested supplementary map cannot replace missing actual Swift
        # dependency outputs, even while all C dependencies and objects remain.
        for path in list(metadata):
            if path.endswith('.d') and path!='/native-build/C.d':del metadata[path]
        with self.assertRaisesRegex(ValueError,'requires original emitted dependencies'):build.trace(raw,r['root'],metadata)

    def test_unmatched_emitted_dependency_file_refuses(self):
        r=fixture();metadata={p:build.unpack(v) for p,v in r['metadata'].items()}
        metadata['/native-build/stale.d']=b'/native-build/stale.o : /checkout/Package.swift\n'
        with self.assertRaisesRegex(ValueError,'must belong to actual compile output'):build.trace(build.unpack(r['originalBuild']),r['root'],metadata)

    def test_original_metadata_and_pinned_file_bytes_cannot_disagree(self):
        r=fixture();next(row for row in r['files'] if row['path']=='/native-build/C.d')['sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'metadata equals actual pinned bytes'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_missing_or_arbitrary_generated_root_source_refuses(self):
        for replace in [b'/native-build/foreign.swift',b'/checkout/Sources/AutoTechnoDSP/untracked.swift']:
            r=fixture();raw=build.unpack(r['originalBuild']).replace(b'/native-build/AutoTechnoDSP.build/DerivedSources/resource_bundle_accessor.swift',replace)
            r['originalBuild']=build.pack(raw);metadata={p:build.unpack(v) for p,v in r['metadata'].items()};r['trace']=build.trace(raw,r['root'],metadata)
            with self.subTest(path=replace),self.assertRaises(ValueError):build.validate(r,SOURCE,r['trackedInputs'])

    def test_foreign_source_implementation_partial_command_and_bool_exit_refuse(self):
        for change in [dict(source='b'*40),dict(implementationSHA256='0'*64),dict(exitCode=False),dict(command=['swift','build','--target','AutoTechnoCore'])]:
            r=fixture();r.update(change)
            with self.subTest(change=change),self.assertRaises(ValueError):build.validate(r,SOURCE,r['trackedInputs'])

    def test_dependency_paths_preserve_spaces_and_line_continuations(self):
        raw=b'/build/a\\ b.o : /source/space\\ name.swift \\\n /SDK/Header.h\n'
        self.assertEqual(build.dependency_rule(raw),[(['/build/a b.o'],['/source/space name.swift','/SDK/Header.h'])])
        for raw in [b'empty',b'/a :\n',b'/a : relative.swift\n',b'/a : /b:/c\n']:
            with self.subTest(raw=raw),self.assertRaises(ValueError):build.dependency_rule(raw)

    def test_original_transport_round_trip_and_timestamped_lines(self):
        r=fixture();stream=io.StringIO()
        with contextlib.redirect_stdout(stream):build.emit(r)
        raw='\n'.join('2026-10-18T00:00:00Z '+line for line in stream.getvalue().splitlines())
        self.assertEqual(build.decode(raw,SOURCE),r)
        self.assertEqual(build.record_digest(build.decode(raw,SOURCE)),build.record_digest(r))

    def test_transport_rejects_missing_duplicate_foreign_and_changed_chunks(self):
        stream=io.StringIO()
        with contextlib.redirect_stdout(stream):build.emit(fixture())
        rows=[json.loads(line) for line in stream.getvalue().splitlines()]
        cases=[[],rows+[copy.deepcopy(rows[0])]]
        for change in [dict(source='b'*40),dict(bytes=True),dict(sha256='0'*64),dict(index=True),dict(payload='???')]:
            bad=copy.deepcopy(rows);bad[0].update(change);cases.append(bad)
        for bad in cases:
            with self.subTest(rows=len(bad)),self.assertRaises(ValueError):build.decode('\n'.join(json.dumps(row) for row in bad),SOURCE)

    def test_packed_metadata_rejects_trailing_stream_changed_hash_and_excess(self):
        r=build.pack(b'original')
        for change in [dict(sha256='0'*64),dict(bytes=True),dict(bytes=build.MAX_METADATA+1),dict(zlibBase64=r['zlibBase64']+'AAAA')]:
            with self.subTest(change=change),self.assertRaises(ValueError):build.unpack(dict(r,**change))

    def test_actual_pinned_file_mutation_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'object.o';p.write_bytes(b'actual bytes');record=build.file_record(p)
            build.check_files([record]);p.write_bytes(b'changed bytes')
            with self.assertRaisesRegex(ValueError,'changed'):build.check_files([record])

    def test_complete_git_source_is_read_from_original_blobs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);subprocess.run(['git','init','-q',str(root)],check=True)
            (root/'one').write_bytes(b'first');(root/'two').write_bytes(b'second')
            subprocess.run(['git','-C',str(root),'add','one','two'],check=True)
            subprocess.run(['git','-C',str(root),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','original'],check=True)
            source=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip();(root/'one').write_bytes(b'working change')
            self.assertEqual(build.git_source_files(str(root),source),{'one':build.sha(b'first'),'two':build.sha(b'second')})

    def test_empty_support_file_is_bound_as_bytes_without_accepting_an_empty_image(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'empty.h';p.write_bytes(b'')
            record=build.file_record(p);self.assertEqual(record['bytes'],0);build.check_files([record])
        r=fixture();next(row for row in r['files'] if row['path']==r['compiledImage'])['bytes']=0
        with self.assertRaisesRegex(ValueError,'nonempty actual'):build.validate(r,SOURCE,r['trackedInputs'])

    def test_noncanonical_paths_and_duplicate_metadata_json_refuse(self):
        for path in ['/root/../source','/root/./source','/root//source','relative','/root/line\nsource']:
            with self.subTest(path=path),self.assertRaises(ValueError):build.absolute(path)
        with self.assertRaisesRegex(ValueError,'duplicate'):build.strict(b'{"x":1,"x":2}')

    def test_reused_build_directory_is_refused_before_any_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/'root';root.mkdir();scratch=Path(tmp)/'build';scratch.mkdir();output=Path(tmp)/'output'
            runner=mock.Mock()
            with self.assertRaisesRegex(ValueError,'absent normal build'):build.prepare(root,scratch,output,runner)
            runner.assert_not_called()

    def test_actual_failed_build_output_survives_without_success_authority(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);raw=b'original compiler failure\n'
            (root/'original-build.log').write_bytes(raw)
            (root/'build-command-status.json').write_text(json.dumps(dict(command=['swift','build'],exitCode=1)))
            stream=io.StringIO()
            with contextlib.redirect_stdout(stream):r=build.preserve_failure(root,SOURCE,ValueError('actual failure'))
            self.assertEqual(build.unpack(r['originalBuild']),raw)
            self.assertEqual(r['originalCommandStatus']['exitCode'],1)
            self.assertFalse(r['buildProvenanceAuthenticated']);self.assertFalse(r['nativeExecutionAuthenticated'])
            self.assertEqual(build.decode(stream.getvalue(),SOURCE),r)
            with self.assertRaises(ValueError):build.validate(r,SOURCE,fixture()['trackedInputs'])

    def test_no_generic_success_or_extra_authority_fields(self):
        for r in [dict(passed=True),dict(fixture(),runtimeQualification=True)]:
            with self.assertRaises(ValueError):build.validate(r,SOURCE,fixture()['trackedInputs'])


if __name__=='__main__':unittest.main()
