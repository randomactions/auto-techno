#!/usr/bin/env python3
"""Revalidate an immutable native capture at its original declared context.

Only the registered whole/role exporters are supported. Unknown context, changed
producer inputs or unavailable original binaries require fresh capture. Content
validators still recompute every required fact; this module never promotes.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import uuid

import baseline_dependency_contract as dependency
import baseline_capture_transaction as transaction
import baseline_producer_witness as producer
import baseline_capture_scope as scope

PROOF_ENV = 'AUTOTECHNO_BASELINE_CAPTURE_PROOF'


class RetainedCaptureError(RuntimeError):
    pass


def registered_probe(build: dict) -> list[str]:
    argv = build.get('buildArgv')
    if not isinstance(argv, list) or len(argv) != 15:
        raise RetainedCaptureError('unknown original build invocation')
    if argv[1:3] != ['build', '--build-tests'] or argv[3::2] != [
            '--build-path', '-c', '--jobs', '--triple', '--sdk', '-Xswiftc']:
        raise RetainedCaptureError('unregistered original compiler flags')
    if argv[6] != 'release' or build.get('buildConfiguration') != 'release' or argv[8] != '2' or argv[10] != build.get('targetTriple') or argv[14] != '-enable-testing':
        raise RetainedCaptureError('unsupported original build context')
    expected = [argv[0], 'test', '--skip-build', '--no-parallel', *argv[3:],
                '--filter', producer.PROBE_FILTER]
    if build.get('probeArgv') != expected or build.get('compilerFlagsFingerprint') != dependency.digest(argv):
        raise RetainedCaptureError('probe is not the registered original build')
    return expected


def native_context(root: Path, build: dict) -> dict:
    """Run a new actual initialization probe; never consume an old success file."""
    before = producer.source_freeze(root)
    argv = registered_probe(build)
    environment = dict(os.environ)
    if producer.CONTROLS & environment.keys():
        raise RetainedCaptureError('probe metadata controls must remain driver-owned')
    environment.pop(PROOF_ENV, None)
    environment.update(AUTOTECHNO_RUN_BASELINE_RENDER='1', AUTOTECHNO_RUN_STEM_CAPTURE='1',
        AUTOTECHNO_CAPTURE_NAMESPACE='v1', AUTOTECHNO_CAPTURE_CORPUS=build['probe']['captureCorpusPath'])
    directory = 'docs/local/reports/retained-capture-probe-' + uuid.uuid4().hex
    transaction.local_path(root, directory).mkdir(parents=True)
    def run(command, name, env=environment):
        output = transaction.local_path(root, directory + '/' + name)
        with output.open('xb') as stream:
            result = subprocess.run(command, cwd=root, env=env, stdout=stream,
                stderr=subprocess.STDOUT, check=False)
        producer.file_hash(output, 16 * 1024 * 1024)
        if result.returncode != 0:
            raise RetainedCaptureError('registered current probe/toolchain operation failed: ' + str(output))
        return output.read_bytes()
    developer = environment.get('DEVELOPER_DIR')
    if not developer:
        raise RetainedCaptureError('current developer directory is required')
    swift = Path(developer) / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swift'
    if argv[0] != str(swift):
        raise RetainedCaptureError('current developer directory differs from original compiler')
    version = run([str(swift), '--version'], 'compiler.log').decode().strip()
    compiler = dependency.digest({'version': version,
        'driverSha256': producer.file_hash(swift.resolve()),
        'compilerSha256': producer.file_hash((swift.parent / 'swiftc').resolve())})
    sdk_path = run(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path'], 'sdk-path.log').decode().strip()
    sdk_version = run(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-version'], 'sdk-version.log').decode().strip()
    sdk = dependency.digest({'path': sdk_path, 'version': sdk_version,
        'settingsSha256': producer.file_hash(Path(sdk_path) / 'SDKSettings.json', dependency.MAX_METADATA_BYTES)})
    target = json.loads(run([str(swift), '-print-target-info'], 'target.log'))['target']['triple']
    if compiler != build['swiftCompilerIdentity'] or sdk != build['sdkIdentity'] or target != build['targetTriple'] or sdk_path != build['buildArgv'][12]:
        raise RetainedCaptureError('current compiler, SDK or target requires fresh capture')
    name = directory + '/probe.json'
    output = transaction.local_path(root, name)
    probe_environment = dict(environment, AUTOTECHNO_RUN_PRODUCER_WITNESS_PROBE='1',
        AUTOTECHNO_PRODUCER_WITNESS_PROBE_OUTPUT=name)
    run(argv, 'native.log', probe_environment)
    probe = dependency.read_json(output)
    producer.validate_probe(root, probe, image=Path(build['probe']['compiledImagePath']),
        corpus_name=build['probe']['captureCorpusPath'])
    if probe['actualArguments'] != build['probe']['actualArguments']:
        raise RetainedCaptureError('current initialization invocation differs from registered native probe')
    for field in ['compiledImageSha256', 'captureCorpusPath', 'captureCorpusSha256',
                  'initialStateFingerprint', 'initialStates', 'captureEnvironmentSha256', 'engineVersion']:
        if probe[field] != build['probe'][field]:
            raise RetainedCaptureError('actual current private state/image/environment requires fresh capture')
    producer.require_same_source(root, before)
    current = dict(build, probe=probe, pythonWitness=producer.current_python_witness())
    return {'context': producer.capture_context(root, current),
        'probePath': name,
        'probeSha256': producer.file_hash(output, dependency.MAX_METADATA_BYTES),
        'diagnosticSha256': producer.file_hash(
            transaction.local_path(root, directory + '/native.log'), 16 * 1024 * 1024),
        'invocationFingerprint': dependency.digest(argv),
        'actualArgumentsFingerprint': dependency.digest(probe['actualArguments'])}


def origin_for_validator(root: Path, directory: str, family: str) -> dict:
    """Return original identities only after live current-context verification."""
    if family not in producer.FAMILIES:
        raise RetainedCaptureError('family has no registered retained native producer')
    before = producer.source_freeze(root)
    original = scope.read_completed_capture(root, directory)
    snapshot = original['originSnapshot']
    current = dependency.capture(root, snapshot['context'])
    assessment = dependency.assess(snapshot, current, root)
    if assessment['families'][family]['action'] == 'recapture-required':
        raise RetainedCaptureError('changed or unknown producer dependencies require fresh capture')
    build = dependency.read_json(transaction.local_path(root, directory + '/build.json'))
    native = native_context(root, build)
    context = native['context']
    current = dependency.capture(root, context)
    assessment = dependency.assess(snapshot, current, root)
    if assessment['families'][family]['action'] == 'recapture-required':
        raise RetainedCaptureError('actual current producer context requires fresh capture')
    manifests = {}
    for name, binding in original['bindings'].items():
        node = next(n for n in dependency.lifecycle.NODES if n['id'] == name)
        artifact = node['artifactPath']
        bound = next(o for o in binding['outputs'] if o['path'] == artifact)
        if transaction.output_record(root, artifact) != bound:
            raise RetainedCaptureError('original manifest changed during current-context probing')
        manifests[name] = dependency.read_json(transaction.local_path(root, artifact))
    producer.require_same_source(root, before)
    return {'gitHead': snapshot['gitHead'],
        'originSnapshotFingerprint': snapshot['snapshotFingerprint'],
        'validationFingerprint': original['validationFingerprint'],
        'contractBaselineFingerprint': snapshot['executionFingerprint'],
        'sourceFingerprint': original['sourceFingerprint'],
        'captureCorpusPath': snapshot['context']['captureCorpusPath'],
        'captureCorpusSha256': snapshot['context']['captureCorpusSha256'],
        'currentSnapshotFingerprint': current['snapshotFingerprint'],
        'currentGitHead': current['gitHead'],
        'currentContractBaselineFingerprint': current['executionFingerprint'],
        'currentCaptureContextFingerprint': dependency.digest(current['context']),
        'currentSourceFreezeFingerprint': dependency.digest(before),
        'currentProbeVerification': {k: native[k] for k in (
            'probePath', 'probeSha256', 'diagnosticSha256', 'invocationFingerprint',
            'actualArgumentsFingerprint')},
        'action': assessment['families'][family]['action'],
        'manifests': manifests,
        'qualification': dict(dependency.QUALIFICATION)}
