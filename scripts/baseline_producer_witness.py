#!/usr/bin/env python3
"""Driver-owned fresh exporter preparation and independent witness verification.

These receipts authenticate the opt-in exporter operation, never quality or
artifact currency. Family validators and Phase-1 remain independently required.
Only macOS's native Swift Testing producer is supported here; unknown layouts
or receipts fail closed rather than substituting a host executable identity.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_dependency_contract as dependency
import baseline_capture_transaction as transaction

DECLARATION_SCHEMA = 'autotechno-baseline-producer-declaration.v1'
WITNESS_SCHEMA = 'autotechno-baseline-producer-witness.v1'
PROBE_SCHEMA = 'autotechno-baseline-producer-probe.v1'
BUILD_SCHEMA = 'autotechno-baseline-producer-build.v2'
PYTHON_SCHEMA = 'autotechno-baseline-python-witness.v1'
PROBE_FILTER = 'BaselineProducerWitnessTests'
FAMILIES = {'whole-mix-render': 'BaselineRenderIntegrationTests',
            'role-stem-capture': 'StemCaptureIntegrationTests'}
CONTROLS = {'AUTOTECHNO_BASELINE_DEPENDENCY_DECLARATION',
            'AUTOTECHNO_RUN_PRODUCER_WITNESS_PROBE', 'AUTOTECHNO_PRODUCER_WITNESS_PROBE_OUTPUT'}
STATE_FIELDS = {'id', 'rootSeedHex', 'sampleRate', 'channelCount', 'routeGeneration',
                'routeRecovery', 'sessionStateFingerprint', 'renderStateFingerprint', 'graphStateFingerprint'}


class ProducerWitnessError(RuntimeError):
    pass


def ascii_canonical(value: Any) -> bytes:
    # Swift's encoder emits literal UTF8 while the dependency schema uses escaped
    # Unicode. Reject unsupported values instead of pretending both hashes match.
    data = json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')
    if not data.isascii():
        raise ProducerWitnessError('unsupported non-ASCII canonical input')
    return data


def file_hash(path: Path, limit: int = 512 * 1024 * 1024) -> str:
    if path.is_symlink() or not path.is_file() or path.stat().st_size > limit:
        raise ProducerWitnessError('compiled image or receipt is not bounded regular bytes')
    before = path.stat()
    h = hashlib.sha256()
    count = 0
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            count += len(chunk)
            if count > limit:
                raise ProducerWitnessError('image grew beyond byte bound')
            h.update(chunk)
    after = path.stat()
    if count != before.st_size or (before.st_size, before.st_mtime_ns, before.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
        raise ProducerWitnessError('image changed while hashing')
    return h.hexdigest()


def source_freeze(root: Path) -> dict[str, Any]:
    if dependency.git(root, 'status', '--porcelain', '--untracked-files=all').strip():
        raise ProducerWitnessError('producer build requires clean committed source')
    names = dependency.inventory(root)
    if sum((root / n).stat().st_size for n in names) > dependency.MAX_TOTAL_BYTES:
        raise ProducerWitnessError('build source inventory exceeds aggregate byte bound')
    files = {n: hashlib.sha256(dependency.regular_bytes(root, n)).hexdigest() for n in names}
    return {'gitHead': dependency.git(root, 'rev-parse', 'HEAD').decode().strip(), 'files': files}


def require_same_source(root: Path, before: dict[str, Any]) -> None:
    if source_freeze(root) != before:
        raise ProducerWitnessError('source changed during exporter build or probe')


def registered_image(bin_path: Path, scratch: Path) -> Path:
    """Select the package's actual test image; never substitute its host runner."""
    if scratch.is_symlink() or not bin_path.is_absolute() or not bin_path.is_relative_to(scratch) or bin_path.is_symlink():
        raise ProducerWitnessError('unknown compiled output layout')
    names = {'AutoTechnoCoreTests', 'AutoTechnoPackageTests'}
    bundles = list(bin_path.glob('*.xctest'))
    producers = [bundle for bundle in bundles if bundle.stem in names]
    # Xcode emits one bundle per declared test target; AppTests is the known
    # companion and does not own the native exporter. Conventional SwiftPM
    # consolidates the tests in the package bundle instead.
    if len(producers) != 1 or any(bundle.stem not in names | {'AutoTechnoAppTests'}
            or bundle.is_symlink() or not bundle.is_dir() for bundle in bundles):
        raise ProducerWitnessError('unknown or ambiguous compiled test bundle layout')
    image = producers[0] / 'Contents/MacOS' / producers[0].stem
    candidate = scratch
    for part in image.relative_to(scratch).parts:
        candidate = candidate / part
        if candidate.is_symlink():
            raise ProducerWitnessError('compiled test image cannot traverse a symlink')
    if not image.resolve().is_relative_to(scratch.resolve()):
        raise ProducerWitnessError('compiled test image escaped registered build')
    file_hash(image)
    return image


def current_python_witness() -> dict[str, str]:
    return {'schema': PYTHON_SCHEMA, 'version': sys.version,
        'executablePath': sys.executable,
        'executableSha256': file_hash(Path(sys.executable).resolve())}


def original_python_witness(receipt: dict[str, Any]) -> dict[str, str]:
    """Read sealed original identity without consulting the current interpreter."""
    witness = receipt.get('pythonWitness')
    if receipt.get('schema') != BUILD_SCHEMA or not isinstance(witness, dict) or set(witness) != {
            'schema', 'version', 'executablePath', 'executableSha256'}:
        raise ProducerWitnessError('original Python witness unavailable; regeneration required')
    if witness['schema'] != PYTHON_SCHEMA or not isinstance(witness['version'], str) or not 1 <= len(witness['version']) <= 4096:
        raise ProducerWitnessError('unsupported original Python witness')
    path = witness['executablePath']
    if not isinstance(path, str) or not 1 <= len(path) <= 4096 or not Path(path).is_absolute() or any(ord(c) < 32 for c in path):
        raise ProducerWitnessError('invalid original Python invocation path')
    if not isinstance(witness['executableSha256'], str) or not dependency.HEX.fullmatch(witness['executableSha256']):
        raise ProducerWitnessError('invalid original Python executable identity')
    ascii_canonical(witness)
    return witness


def validate_probe(root: Path, probe: dict[str, Any], *, image: Path, corpus_name: str) -> None:
    if probe.get('schema') != PROBE_SCHEMA or probe.get('probeOnly') is not True or probe.get('artifactCurrencyEstablished') is not False or probe.get('promotionAuthorized') is not False:
        raise ProducerWitnessError('probe cannot establish capture or promotion')
    ascii_canonical(probe)
    if not isinstance(probe.get('compiledImagePath'), str) or Path(probe['compiledImagePath']).resolve() != image.resolve() or probe.get('compiledImageSha256') != file_hash(image):
        raise ProducerWitnessError('probe does not belong to freshly built exporter image')
    corpus = dependency.regular_bytes(root, corpus_name)
    if probe.get('captureCorpusPath') != corpus_name or probe.get('captureCorpusSha256') != hashlib.sha256(corpus).hexdigest():
        raise ProducerWitnessError('probe corpus bytes differ')
    for name in ['captureEnvironmentSha256', 'actualEnvironmentSha256', 'initialStateFingerprint']:
        if not isinstance(probe.get(name), str) or not dependency.HEX.fullmatch(probe[name]):
            raise ProducerWitnessError('missing probe process digest')
    ledger = probe.get('initialStates')
    if not isinstance(ledger, list) or not 1 <= len(ledger) <= 256:
        raise ProducerWitnessError('missing bounded initialization ledger')
    document = json.loads(corpus)
    expected = {c['id'] + '--' + r['id']: (c, r) for c in document['cases'] for r in document['routes']}
    if len(expected) != len(document['cases']) * len(document['routes']):
        raise ProducerWitnessError('duplicate corpus initialization identity')
    ids = []
    for state in ledger:
        if not isinstance(state, dict) or set(state) != STATE_FIELDS or state.get('id') not in expected:
            raise ProducerWitnessError('initialization coverage mismatch')
        case, route = expected[state['id']]
        if state['rootSeedHex'] != f"{case['rootSeed']:016x}":
            raise ProducerWitnessError('actual initialization seed mismatch')
        for name in ['sampleRate', 'channelCount', 'routeGeneration', 'routeRecovery']:
            if type(state[name]) is not type(route[name]) or state[name] != route[name]:
                raise ProducerWitnessError('actual initialization route mismatch')
        for name in ['sessionStateFingerprint', 'renderStateFingerprint', 'graphStateFingerprint']:
            if not isinstance(state[name], str) or not re.fullmatch('[0-9a-f]{16}', state[name]):
                raise ProducerWitnessError('actual initialization fingerprint missing')
        ids.append(state['id'])
    if ids != sorted(expected) or probe['initialStateFingerprint'] != dependency.digest(ledger):
        raise ProducerWitnessError('initialization ledger coverage or hash mismatch')
    transaction.invocation({'argv': probe.get('actualArguments'),
        'environmentFingerprint': probe['actualEnvironmentSha256'],
        'compiledInputsFingerprint': probe['compiledImageSha256']})


def prepare_exporter(root: Path, scratch: Path, environment: dict[str, str], *, configuration: str = 'release') -> dict[str, Any]:
    """Execute a fresh build and native probe under this driver's actual control.

    Never accepts caller-supplied success codes or old probe files. The private
    environment is passed to child processes and retained only as hash receipts.
    """
    if sys.platform != 'darwin' or configuration not in {'debug', 'release'}:
        raise ProducerWitnessError('unsupported exporter platform or build configuration')
    if scratch.exists() or not scratch.is_absolute():
        raise ProducerWitnessError('build scratch must be an absent absolute directory')
    if CONTROLS & environment.keys():
        raise ProducerWitnessError('driver owns all witness and probe controls')
    ascii_canonical(environment)
    python_witness = current_python_witness()
    before = source_freeze(root)
    developer = Path(environment['DEVELOPER_DIR'])
    swift = developer / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swift'
    if not swift.is_file():
        raise ProducerWitnessError('missing explicit Xcode compiler')
    operation = 0
    def run(argv, *, process_environment=None):
        nonlocal operation
        operation += 1
        logs = scratch / 'producer-driver-logs'
        logs.mkdir(parents=True, exist_ok=True)
        path = logs / f'{operation:02d}.log'
        with path.open('xb') as output:
            result = subprocess.run(argv, cwd=root, env=environment if process_environment is None else process_environment, stdout=output,
                                    stderr=subprocess.STDOUT, check=False)
        if path.stat().st_size > 16 * 1024 * 1024:
            raise ProducerWitnessError('registered invocation diagnostic exceeds byte bound')
        if result.returncode != 0:
            raise ProducerWitnessError('registered invocation failed; local diagnostic: ' + str(path))
        return path.read_bytes()
    sdk_path = Path(run(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path']).decode().strip())
    sdk_version = run(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-version']).decode().strip()
    sdk_identity = dependency.digest({'path': str(sdk_path), 'version': sdk_version,
        'settingsSha256': file_hash(sdk_path / 'SDKSettings.json', dependency.MAX_METADATA_BYTES)})
    target = json.loads(run([str(swift), '-print-target-info']))['target']['triple']
    options = ['--build-path', str(scratch), '-c', configuration, '--jobs', '2',
               '--triple', target, '--sdk', str(sdk_path), '-Xswiftc', '-enable-testing']
    argv = [str(swift), 'build', '--build-tests', *options]
    run(argv)
    require_same_source(root, before)
    bin_path = Path(run([str(swift), 'build', '--show-bin-path', *options]).decode().strip())
    image = registered_image(bin_path, scratch)
    image_sha = file_hash(image)
    name = 'docs/local/reports/producer-probe-' + uuid.uuid4().hex + '.json'
    output = transaction.local_path(root, name)
    output.parent.mkdir(parents=True, exist_ok=True)
    probe_environment = dict(environment, AUTOTECHNO_RUN_PRODUCER_WITNESS_PROBE='1',
                             AUTOTECHNO_PRODUCER_WITNESS_PROBE_OUTPUT=name)
    probe_argv = [str(swift), 'test', '--skip-build', '--no-parallel', *options,
                  '--filter', PROBE_FILTER]
    run(probe_argv, process_environment=probe_environment)
    if not output.is_file():
        raise ProducerWitnessError('actual native probe did not complete')
    probe = dependency.read_json(output)
    corpus_name = environment.get('AUTOTECHNO_CAPTURE_CORPUS', 'docs/BASELINE_CORPUS.json')
    validate_probe(root, probe, image=image, corpus_name=corpus_name)
    require_same_source(root, before)
    if file_hash(image) != image_sha:
        raise ProducerWitnessError('compiled image changed during probe')
    require_same_source(root, before)
    receipt = {'schema': BUILD_SCHEMA, 'source': before, 'buildArgv': argv,
        'pythonWitness': python_witness,
        'buildConfiguration': configuration, 'driverEnvironmentSha256': dependency.digest(environment),
        'swiftCompilerIdentity': dependency.digest({'version': run([str(swift), '--version']).decode().strip(),
            'driverSha256': file_hash(swift.resolve()),
            'compilerSha256': file_hash((swift.parent / 'swiftc').resolve())}),
        'sdkIdentity': sdk_identity, 'targetTriple': target,
        'compilerFlagsFingerprint': dependency.digest(argv),
        'probeArgv': probe_argv, 'probePath': name, 'probeSha256': file_hash(output, dependency.MAX_METADATA_BYTES),
        'probe': probe, 'qualification': dict(dependency.QUALIFICATION)}
    require_same_source(root, before)
    if current_python_witness() != python_witness:
        raise ProducerWitnessError('driver Python changed during exporter preparation')
    receipt['receiptFingerprint'] = dependency.digest(receipt)
    return receipt


def capture_context(root: Path, receipt: dict[str, Any]) -> dict[str, str]:
    probe = receipt['probe']
    python_witness = original_python_witness(receipt)
    corpus = json.loads(dependency.regular_bytes(root, probe['captureCorpusPath']))
    return {'engineVersion': probe['engineVersion'], 'buildConfiguration': receipt['buildConfiguration'],
        'swiftCompilerIdentity': receipt['swiftCompilerIdentity'], 'sdkIdentity': receipt['sdkIdentity'],
        'targetTriple': receipt['targetTriple'], 'compilerFlagsFingerprint': receipt['compilerFlagsFingerprint'],
        'routeIdentityFingerprint': dependency.digest(corpus['routes']),
        'initialStateFingerprint': probe['initialStateFingerprint'],
        'corpusSha256': hashlib.sha256(dependency.regular_bytes(root, 'docs/BASELINE_CORPUS.json')).hexdigest(),
        'pythonIdentity': dependency.digest({'version': python_witness['version'],
            'executableSha256': python_witness['executableSha256']}),
        'captureCorpusPath': probe['captureCorpusPath'], 'captureCorpusSha256': probe['captureCorpusSha256'],
        'compiledImageSha256': probe['compiledImageSha256'],
        'captureEnvironmentFingerprint': probe['captureEnvironmentSha256']}


def declaration(root: Path, family: str, snapshot: dict[str, Any], receipt: dict[str, Any]) -> dict[str, Any]:
    """Bind a driver-owned fresh receipt; this data alone confers no authority."""
    if family not in FAMILIES or receipt.get('schema') != BUILD_SCHEMA or receipt.get('qualification') != dependency.QUALIFICATION:
        raise ProducerWitnessError('unsupported build receipt or exporter family')
    if receipt.get('receiptFingerprint') != dependency.digest({k: v for k, v in receipt.items() if k != 'receiptFingerprint'}):
        raise ProducerWitnessError('build receipt fingerprint mismatch')
    require_same_source(root, receipt['source'])
    dependency.validate_snapshot(snapshot, root)
    if snapshot['gitHead'] != receipt['source']['gitHead'] or {n: x['sha256'] for n, x in snapshot['files'].items()} != receipt['source']['files']:
        raise ProducerWitnessError('build and dependency snapshot source differ')
    probe = receipt['probe']
    validate_probe(root, probe, image=Path(probe['compiledImagePath']), corpus_name=probe['captureCorpusPath'])
    if file_hash(transaction.local_path(root, receipt['probePath']), dependency.MAX_METADATA_BYTES) != receipt['probeSha256']:
        raise ProducerWitnessError('actual probe output changed')
    context = snapshot['context']
    for target, source in {'initialStateFingerprint': 'initialStateFingerprint',
        'captureCorpusPath': 'captureCorpusPath', 'captureCorpusSha256': 'captureCorpusSha256',
        'compiledImageSha256': 'compiledImageSha256', 'captureEnvironmentFingerprint': 'captureEnvironmentSha256',
        'engineVersion': 'engineVersion'}.items():
        if context[target] != probe[source]:
            raise ProducerWitnessError('capture context differs from actual native probe')
    if context != capture_context(root, receipt):
        raise ProducerWitnessError('capture context differs from actual build and corpus')
    if original_python_witness(receipt) != current_python_witness():
        raise ProducerWitnessError('fresh capture driver Python differs from prepared original')
    scope = snapshot['families'][family]
    return {'schema': DECLARATION_SCHEMA, 'familyId': family,
        'dependencySnapshotFingerprint': snapshot['snapshotFingerprint'], 'gitHead': snapshot['gitHead'],
        'contractBaselineFingerprint': snapshot['executionFingerprint'],
        'producerInputs': scope['producerInputs'], 'producerContext': {k: v for k, v in context.items() if k != 'pythonIdentity'},
        'upstreamProducerFingerprints': {n: snapshot['families'][n]['producerFingerprint'] for n in scope['dependencies']},
        'producerFingerprint': scope['producerFingerprint'], 'compiledImagePath': probe['compiledImagePath'],
        'compiledImageSha256': probe['compiledImageSha256'], 'captureCorpusPath': probe['captureCorpusPath'],
        'captureCorpusSha256': probe['captureCorpusSha256'], 'initialStates': probe['initialStates'],
        'captureEnvironmentSha256': probe['captureEnvironmentSha256']}


def verify_witness(root: Path, witness: dict[str, Any], declared: dict[str, Any], *, artifact_name: str, actual_arguments: list[str]) -> None:
    if witness.get('schema') != WITNESS_SCHEMA or witness.get('qualification') != dependency.QUALIFICATION:
        raise ProducerWitnessError('witness cannot establish currency or quality')
    for key in ['familyId', 'gitHead', 'contractBaselineFingerprint', 'dependencySnapshotFingerprint',
                'producerFingerprint', 'compiledImagePath', 'compiledImageSha256',
                'captureCorpusSha256', 'captureEnvironmentSha256', 'initialStates']:
        if witness.get(key) != declared[key]:
            raise ProducerWitnessError('actual producer witness differs from declared frozen inputs')
    if witness.get('declarationSha256') != hashlib.sha256(ascii_canonical(declared)).hexdigest():
        raise ProducerWitnessError('producer used different declaration bytes')
    if witness.get('actualArguments') != actual_arguments:
        raise ProducerWitnessError('producer actual invocation differs')
    if witness.get('artifactSha256') != file_hash(transaction.local_path(root, artifact_name), dependency.MAX_METADATA_BYTES):
        raise ProducerWitnessError('producer manifest bytes changed')
    if file_hash(Path(declared['compiledImagePath'])) != declared['compiledImageSha256']:
        raise ProducerWitnessError('actual exporter image changed')
