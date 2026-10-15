#!/usr/bin/env python3
"""Recover only the approved missing routes of one interrupted Long study.

Original histories retain their original bytes and provenance. Fresh executions
use the frozen production objects and a separately bound test harness. This does
not establish final-source, capacity, deadline, runtime, or output qualification.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone

import long_horizon_history_integrity as history

ORIGINAL_SOURCE = '5b81cefa3cf491b644dcee64a28cbefdd7bbc17d'
ORIGINAL_BINDING = 'd1f562e91f703a86'
OWNER = 'Tests/AutoTechnoCoreTests/LongHorizonPolicyCalibrationIntegrationTests.swift'
ROOTS = (48291, 77777, 90909, 112358, 141421, 173205, 246813, 271828, 314159)
MISSING = {(141421, 48000)} | {(r, s) for r in ROOTS[5:] for s in (44100, 48000)}
ALL = {(r, s) for r in ROOTS for s in (44100, 48000)}
require = history.require
load = history.load
sha = history.sha


def now():
    return datetime.now(timezone.utc).isoformat()


def pair(row):
    require(isinstance(row, dict) and type(row.get('rootSeed')) is int and
            type(row.get('sampleRate')) is int, 'integer route identity required')
    return row['rootSeed'], row['sampleRate']


def indexed(rows, expected):
    require(isinstance(rows, list), 'route list required')
    keys = [pair(row) for row in rows]
    require(len(keys) == len(set(keys)) and set(keys) == expected,
            'duplicate, unknown or missing route pair')
    return dict(zip(keys, rows))


def canonical_route(source):
    start = source.index('  private static func renderPreparedRoute(')
    end = source.index('  private struct RefusedSignalInputs:', start)
    return source[start:end]


def compiler_support(command):
    paths = {Path(value) for value in command if value.endswith('/main.swift')}
    swift, clang, index = [], [], 0
    while index < len(command):
        if command[index] == '-Xcc':
            require(index + 1 < len(command), 'missing forwarded C argument')
            clang.append(command[index + 1]); index += 2
        else:
            swift.append(command[index]); index += 1
    for arguments in (swift, clang):
        for index, value in enumerate(arguments):
            if value == '-I':
                require(index + 1 < len(arguments), 'missing module search path')
                directory = Path(arguments[index + 1])
                # An unused nonexistent search directory is valid swiftc input.
                # Any module appearing there later changes the complete map.
                require(not directory.exists() or directory.is_dir(), 'invalid compiler module directory')
                paths.update(path for path in directory.rglob('*') if path.is_file())
            elif value.startswith('-fmodule-map-file='):
                paths.add(Path(value.split('=', 1)[1]))
            elif value == '-load-plugin-executable':
                require(index + 1 < len(arguments), 'missing compiler macro executable')
                paths.add(Path(arguments[index + 1].split('#', 1)[0]))
    return {str(path): sha(path) for path in sorted(paths)}


def verify_manifest(document, context, origin):
    require(document.get('schema') == 'autotechno-interrupted-long-study-recovery.v1',
            'unsupported recovery manifest')
    authorization = document.get('authorization', {})
    require(authorization.get('decision') == 'explicit-user-approval' and
            authorization.get('scope') == 'preserve-nine-originals-render-nine-missing' and
            isinstance(authorization.get('statement'), str) and authorization['statement'].strip(),
            'explicit bounded recovery decision must be recorded')
    require(document.get('originalSource') == context['source'] == ORIGINAL_SOURCE and
            document.get('originalInputBinding') == context['inputBindingFingerprint'] == ORIGINAL_BINDING and
            context['roots'] == list(ROOTS), 'exact interrupted study identity required')
    for key in ('buildMetadataSHA256', 'launchSHA256'):
        require(document.get('original' + key[0].upper() + key[1:]) == context[key],
                'original producer metadata seal changed')
    require(document.get('originalPrimaryPolicyVersion') == context['primaryPolicyVersion'] and
            document.get('originalEngineVersion') == context['engineVersion'],
            'original primary policy or engine changed')
    completed = indexed(document.get('completedOriginals'), ALL - MISSING)
    indexed(document.get('missingRoutes'), MISSING)
    for key, row in completed.items():
        require(row.get('origin') == 'preserved-original' and row.get('freshCapture') is False and
                row.get('inputBindingFingerprint') == ORIGINAL_BINDING and
                row.get('source') == ORIGINAL_SOURCE, 'original history cannot be retagged as fresh')
        path = history.relative_file(origin, row.get('path'))
        require(sha(path) == row.get('sha256'), 'preserved original history changed')
        artifact = load(path)
        require('recoveryProvenance' not in artifact, 'foreign recovered history is not an original')
        actual = history.verify_history(artifact, ORIGINAL_BINDING, context['roots'],
                                        context['primaryPolicyVersion'], context['engineVersion'])
        require((actual['rootSeed'], actual['sampleRate']) == key, 'original file route identity')
    return completed


def preflight(manifest):
    before = sha(manifest)
    document = load(manifest)
    origin, runner, resources = [Path(document[key]) for key in
                                ('originRoot', 'originalRunnerDirectory', 'runtimeResources')]
    context = history.verify_origin(origin, runner, resources, ORIGINAL_SOURCE)
    require(document.get('originalRunnerSHA256') == sha(runner / 'runner'),
            'original executable seal changed')
    verify_manifest(document, context, origin)
    require(sha(manifest) == before, 'recovery manifest changed during preflight')
    return document, context, before


def verify_build(harness, metadata, document):
    require(history.git(harness, 'rev-parse', 'HEAD') == metadata.get('harnessSource') and
            not history.git(harness, 'status', '--porcelain', '--untracked-files=all'),
            'clean exact recovery harness source required')
    original = load(Path(document['originalRunnerDirectory']) / 'build-metadata.json')
    require(metadata.get('schema') == 'autotechno-frozen-long-recovery-build.v1' and
            metadata.get('originalSource') == ORIGINAL_SOURCE and
            metadata.get('originalBuildMetadataSHA256') == document['originalBuildMetadataSHA256'],
            'recovery build must name the original compiled candidate')
    groups = metadata.get('inputs', {})
    require(set(groups) == {'sources', 'testFiles', 'objects', 'resources'}, 'complete build inputs required')
    for group in ('sources', 'objects', 'resources'):
        require(groups[group] == original['inputs'][group], 'frozen compiled inputs changed: ' + group)
    runtime = Path(metadata['runtimeResourceBundle'])
    require(runtime.resolve() == Path(document['runtimeResources']).resolve() and
            runtime.is_dir() and not runtime.is_symlink() and
            {str(p.relative_to(runtime)) for p in runtime.rglob('*') if p.is_file()} == set(groups['resources']),
            'actual recovery runtime bundle membership changed')
    for name, digest in groups['resources'].items():
        require(sha(history.relative_file(runtime, name)) == digest, 'actual recovery runtime resource changed')
    tests = groups['testFiles']
    require(set(tests) == set(original['inputs']['testFiles']), 'test input membership changed')
    origin = Path(document['originRoot'])
    for name, digest in tests.items():
        path = history.relative_file(harness if name == OWNER else origin, name)
        require(sha(path) == digest, 'compiled recovery test bytes changed')
        if name != OWNER:
            require(digest == original['inputs']['testFiles'][name], 'unrelated frozen test changed')
    require(canonical_route((harness / OWNER).read_text()) == canonical_route((origin / OWNER).read_text()),
            'canonical route implementation changed')
    extra = metadata.get('supportInputs')
    require(isinstance(extra, dict) and extra and extra == compiler_support(original['command']),
            'all original compiler modules and driver must be bound')
    for name, digest in extra.items():
        path = Path(name)
        require(path.is_absolute() and path.is_file() and not path.is_symlink() and sha(path) == digest,
                'compiled module or entry source changed')
    executable = Path(metadata['executable'])
    require(executable.is_file() and not executable.is_symlink() and
            sha(executable) == metadata.get('executableSHA256'), 'recovery executable changed')
    expected = original['command'].copy()
    entry = next(value for value in expected if value.endswith('/main.swift'))
    start, end = expected.index(entry), expected.index('-lc++')
    expected[start:end] = [entry, *[str((harness if name == OWNER else origin) / name)
                                   for name in original['inputs']['testFiles']],
                           *original['inputs']['objects']]
    expected[expected.index('-o') + 1] = str(executable)
    expected[expected.index('-module-name') + 1] = 'AT0039InterruptedLongRecoveryRunner'
    require(metadata.get('command') == expected and '-O' in expected,
            'compile recipe differs from frozen optimized production/test linkage')
    require(entry in extra, 'compiled driver is not bound')
    return metadata


def binding(metadata_sha, manifest_sha):
    # Distinct domain and complete SHA256 seals bind the new harness. Never
    # substitute the original study's 16-character FNV for these new inputs.
    value = 0xcbf29ce484222325
    for byte in ('autotechno-interrupted-long-recovery-inputs.v1\0' + metadata_sha + manifest_sha).encode():
        value = ((value ^ byte) * 0x100000001b3) & (2**64 - 1)
    result = f'{value:016x}'
    require(result != ORIGINAL_BINDING, 'recovery binding must differ from original')
    return result


def request(root, rate, document, context, metadata, manifest_sha, metadata_sha):
    require((root, rate) in MISSING, 'only an approved missing route may execute')
    return dict(schema='autotechno-interrupted-long-route-request.v1', rootSeed=root, sampleRate=rate,
                originalSource=ORIGINAL_SOURCE, originalInputBinding=ORIGINAL_BINDING,
                harnessSource=metadata['harnessSource'], recoveryInputBinding=binding(metadata_sha, manifest_sha),
                manifestSHA256=manifest_sha, buildMetadataSHA256=metadata_sha,
                primaryPolicyVersion=context['primaryPolicyVersion'],
                preservedCompleteHistoryCount=9, freshCompleteRoute=True)


def verify_fresh(artifact, spec, context):
    result = history.verify_history(artifact, spec['recoveryInputBinding'], context['roots'],
                                    context['primaryPolicyVersion'], context['engineVersion'])
    require((result['rootSeed'], result['sampleRate']) == (spec['rootSeed'], spec['sampleRate']),
            'fresh route differs from request')
    expected = {key: spec[key] for key in ('originalSource', 'originalInputBinding', 'harnessSource',
                                         'manifestSHA256', 'buildMetadataSHA256')}
    expected.update(schema='autotechno-interrupted-long-route-provenance.v1',
                    routeOrigin='fresh-complete-execution-from-initial-state')
    require(artifact.get('recoveryProvenance') == expected, 'fresh recovery provenance must be exact')
    return result


def write(path, value):
    raw = (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n').encode()
    with path.open('xb') as handle:
        handle.write(raw)


def verify_completed(output, document, context, metadata, manifest_sha, metadata_sha):
    """Recheck all nine fresh outputs and their actual native completion receipts."""
    completed = load(output / 'completed-routes.json')
    require(completed.get('schema') == 'autotechno-interrupted-long-completed-routes.v1' and
            completed.get('originalSource') == ORIGINAL_SOURCE and
            completed.get('harnessSource') == metadata['harnessSource'] and
            completed.get('manifestSHA256') == manifest_sha and
            completed.get('buildMetadataSHA256') == metadata_sha and
            completed.get('preservedOriginals') == document['completedOriginals'],
            'complete recovery cohort provenance changed')
    fresh = indexed(completed.get('freshRoutes'), MISSING)
    for (root, rate), row in fresh.items():
        case = output / f'{root}-{rate}'
        artifact = case / 'native' / f'actual-journey-{root}-{rate}.json'
        require(Path(row.get('path', '')).resolve() == artifact.resolve() and
                row.get('origin') == 'fresh-recovery-execution' and sha(artifact) == row.get('sha256'),
                'fresh artifact path, origin or bytes changed')
        spec = request(root, rate, document, context, metadata, manifest_sha, metadata_sha)
        require(load(case / 'request.json') == spec, 'fresh request changed')
        launch, status = load(case / 'launch.json'), load(case / 'execution-status.json')
        require(launch.get('requestSHA256') == sha(case / 'request.json') and
                launch.get('executableSHA256') == metadata['executableSHA256'] and
                status.get('exitCode') == 0 and status.get('originalLogSHA256') == sha(case / 'native.log'),
                'fresh native execution receipt changed or failed')
        log = (case / 'native.log').read_text()
        require(re.search(r'Test run with 1 test passed', log) is not None and
                f'recovered-missing root={root} rate={rate} ' in log,
                'fresh native case completion missing')
        verify_fresh(load(artifact), spec, context)
    return fresh


def assemble(manifest, harness, build, output):
    document, context, manifest_sha = preflight(manifest)
    metadata_sha, metadata = sha(build), load(build)
    verify_build(harness, metadata, document)
    fresh = verify_completed(output, document, context, metadata, manifest_sha, metadata_sha)
    rows = [dict(rootSeed=row['rootSeed'], sampleRate=row['sampleRate'],
                 path=str(Path(document['originRoot']) / row['path']), origin='preserved-original')
            for row in document['completedOriginals']]
    rows += [dict(rootSeed=r, sampleRate=s, path=row['path'], origin='fresh-recovery-execution')
             for (r, s), row in sorted(fresh.items())]
    indexed(rows, ALL)
    case = output / 'assembly'
    case.mkdir(exist_ok=False)
    spec = dict(schema='autotechno-interrupted-long-study-assembly-request.v1',
                provenance=request(141421, 48000, document, context, metadata, manifest_sha, metadata_sha),
                routes=rows)
    write(case / 'request.json', spec)
    request_sha = sha(case / 'request.json')
    env = {k: v for k, v in os.environ.items() if not k.startswith(('AUTOTECHNO_', 'MallocStackLogging'))}
    env.update(AUTOTECHNO_ASSEMBLE_INTERRUPTED_LONG_STUDY='1',
               AUTOTECHNO_INTERRUPTED_LONG_ASSEMBLY_REQUEST=str(case / 'request.json'),
               AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY=str(case / 'native'))
    command = [metadata['executable'], '--no-parallel', '--filter',
               r'LongHorizonPolicyCalibrationIntegrationTests[/.]assembleInterruptedStudy(\(|/|$)']
    with (case / 'native.log').open('xb') as log:
        child = subprocess.Popen(command, cwd=harness, env=env, stdout=log, stderr=subprocess.STDOUT)
        write(case / 'launch.json', dict(pid=child.pid, startedAtUTC=now(), command=command,
              requestSHA256=request_sha, executableSHA256=metadata['executableSHA256']))
        code = child.wait()
    write(case / 'execution-status.json', dict(exitCode=code, finishedAtUTC=now(),
          originalLogSHA256=sha(case / 'native.log')))
    require(code == 0 and re.search(r'Test run with 1 test passed', (case / 'native.log').read_text()),
            'canonical assembly/qualification failed; preserve diagnostics')
    again, c, seal = preflight(manifest)
    require(again == document and c == context and seal == manifest_sha and sha(build) == metadata_sha and
            sha(case / 'request.json') == request_sha, 'assembly inputs changed')
    verify_build(harness, metadata, document)
    verify_completed(output, document, context, metadata, manifest_sha, metadata_sha)
    declaration = load(case / 'native/interrupted-study-assembly.json')
    expected_declaration = dict(schema='autotechno-interrupted-long-study-assembly.v1',
          originalSource=ORIGINAL_SOURCE, originalInputBinding=ORIGINAL_BINDING,
          harnessSource=metadata['harnessSource'], recoveryInputBinding=binding(metadata_sha, manifest_sha),
          manifestSHA256=manifest_sha, buildMetadataSHA256=metadata_sha,
          preservedOriginalHistories=9, freshCompleteHistories=9, declaredOriginalEvidenceAssembly=True,
          originalHistoriesRetagged=False, finalSourceApplicability=False,
          runtimeQualification=False, item39Complete=False)
    require(declaration == expected_declaration,
            'assembly must declare original reuse without final-source or completion authority')
    write(case / 'validation.json', dict(schema='autotechno-interrupted-long-study-assembly-validation.v1',
          originalSource=ORIGINAL_SOURCE, harnessSource=metadata['harnessSource'],
          manifestSHA256=manifest_sha, buildMetadataSHA256=metadata_sha,
          preservedOriginals=9, freshCompleteHistories=9, canonicalTypedQualificationPassed=True,
          originalArtifactsRetagged=False, finalSourceApplicability=False,
          completeAllocatorRSSDeadlineQualification=False, runtimeQualification=False, item39Complete=False,
          artifacts={p.name: sha(p) for p in sorted((case / 'native').glob('*.json'))}))


def run(manifest, harness, build, output):
    document, context, manifest_sha = preflight(manifest)
    metadata_sha, metadata = sha(build), load(build)
    verify_build(harness, metadata, document)
    require(output.resolve().is_relative_to((harness / 'docs/local/reports').resolve()) and
            output.resolve() != (harness / 'docs/local/reports').resolve(), 'confined recovery output required')
    output.mkdir(parents=True, exist_ok=False)
    write(output / 'launch.json', dict(schema='autotechno-interrupted-long-recovery-launch.v1',
          startedAtUTC=now(), originalSource=ORIGINAL_SOURCE, harnessSource=metadata['harnessSource'],
          manifestSHA256=manifest_sha, buildMetadataSHA256=metadata_sha,
          recoveryInputBinding=binding(metadata_sha, manifest_sha), preservedOriginals=9,
          freshRoutes=9, oldOriginalsRetagged=False, item39Complete=False))
    def unchanged():
        d, c, h = preflight(manifest)
        require(d == document and c == context and h == manifest_sha and sha(build) == metadata_sha,
                'recovery inputs changed')
        verify_build(harness, metadata, document)
    fresh = []
    for root, rate in sorted(MISSING):
        unchanged()
        case = output / f'{root}-{rate}'
        case.mkdir(exist_ok=False)
        spec = request(root, rate, document, context, metadata, manifest_sha, metadata_sha)
        write(case / 'request.json', spec)
        request_sha = sha(case / 'request.json')
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(('AUTOTECHNO_', 'MallocStackLogging'))}
        env.update(AUTOTECHNO_RUN_INTERRUPTED_LONG_ROUTE='1',
                   AUTOTECHNO_INTERRUPTED_LONG_ROUTE_REQUEST=str(case / 'request.json'),
                   AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY=str(case / 'native'))
        command = [metadata['executable'], '--no-parallel', '--filter',
                   r'LongHorizonPolicyCalibrationIntegrationTests[/.]renderInterruptedStudyRoute(\(|/|$)']
        started = now()
        with (case / 'native.log').open('xb') as log:
            child = subprocess.Popen(command, cwd=harness, env=env, stdout=log, stderr=subprocess.STDOUT)
            write(case / 'launch.json', dict(pid=child.pid, startedAtUTC=started, command=command,
                                           requestSHA256=request_sha, executableSHA256=metadata['executableSHA256']))
            code = child.wait()
        write(case / 'execution-status.json', dict(exitCode=code, startedAtUTC=started,
              finishedAtUTC=now(), originalLogSHA256=sha(case / 'native.log')))
        require(code == 0, 'native recovery route failed; preserve partial evidence and stop')
        native_log = (case / 'native.log').read_text()
        require(re.search(r'Test run with 1 test passed', native_log) is not None and
                f'recovered-missing root={root} rate={rate} ' in native_log,
                'exact native recovery case did not execute to completion')
        unchanged()
        require(sha(case / 'request.json') == request_sha, 'native request changed')
        artifact = case / 'native' / f'actual-journey-{root}-{rate}.json'
        row = verify_fresh(load(artifact), spec, context)
        row.update(path=str(artifact), sha256=sha(artifact), origin='fresh-recovery-execution',
                   inputBindingFingerprint=spec['recoveryInputBinding'])
        write(case / 'validation.json', dict(**row, originalSource=ORIGINAL_SOURCE,
              harnessSource=metadata['harnessSource'], longHorizonQualification=False,
              completeAllocatorRSSDeadlineQualification=False, runtimeQualification=False, item39Complete=False))
        fresh.append(row)
        print(json.dumps(dict(completedFresh=len(fresh), preservedOriginals=9, rootSeed=root, sampleRate=rate)), flush=True)
    unchanged()
    indexed(fresh, MISSING)
    write(output / 'completed-routes.json', dict(schema='autotechno-interrupted-long-completed-routes.v1',
          originalSource=ORIGINAL_SOURCE, harnessSource=metadata['harnessSource'],
          manifestSHA256=manifest_sha, buildMetadataSHA256=metadata_sha, freshRoutes=fresh,
          preservedOriginals=document['completedOriginals'],
          longHorizonQualification=False, runtimeQualification=False, item39Complete=False))
    # Full corpus/profile/adversarial/holdout fitting remains a separate canonical
    # operation, with all eighteen inputs independently revalidated first.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['preflight', 'run', 'assemble'])
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--harness-root', type=Path)
    parser.add_argument('--build-metadata', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'preflight':
            _, context, seal = preflight(args.manifest)
            print(json.dumps(dict(manifestSHA256=seal, context=context, preservedOriginals=9,
                                  missingRoutes=9, nativeExecutionProven=False, item39Complete=False)))
        else:
            require(all((args.harness_root, args.build_metadata, args.output)), 'run paths required')
            if args.operation == 'run':
                run(args.manifest, args.harness_root, args.build_metadata, args.output)
            else:
                assemble(args.manifest, args.harness_root, args.build_metadata, args.output)
    except (history.HistoryIntegrityError, OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        parser.exit(1, 'Interrupted Long-study recovery failed: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
