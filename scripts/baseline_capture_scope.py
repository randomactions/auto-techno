#!/usr/bin/env python3
"""Independently read completed native captures without changing their envelopes.

Reading a receipt establishes original capture integrity only. Current dependency
assessment and every cold family/content validator remain separate requirements.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

import baseline_dependency_contract as dependency
import baseline_capture_transaction as transaction
import baseline_producer_witness as producer
import baseline_producer_capture_driver as driver


class CaptureScopeError(RuntimeError):
    pass


RECEIPT_FIELDS = {
    driver.SCHEMA: {'schema', 'gitHead', 'snapshotFingerprint', 'buildReceiptFingerprint',
        'bindingFingerprints', 'captureCorpusPath', 'exactWaveAssetCount', 'initialStateCount',
        'referenceNamespace', 'referenceOutputs', 'subprocesses', 'qualification', 'validationFingerprint'},
    producer.BUILD_SCHEMA: {'schema', 'source', 'buildArgv', 'buildConfiguration',
        'driverEnvironmentSha256', 'swiftCompilerIdentity', 'sdkIdentity', 'targetTriple',
        'compilerFlagsFingerprint', 'probeArgv', 'probePath', 'probeSha256', 'probe',
        'pythonWitness', 'qualification', 'receiptFingerprint'},
}


def sealed(value: object, schema: str, field: str) -> dict[str, Any]:
    if schema == producer.BUILD_SCHEMA and isinstance(value, dict) and value.get('schema') == 'autotechno-baseline-producer-build.v1':
        raise CaptureScopeError('original Python witness unavailable; regeneration required')
    if not isinstance(value, dict) or value.get('schema') != schema:
        raise CaptureScopeError('unsupported completed capture receipt')
    if schema in RECEIPT_FIELDS and set(value) != RECEIPT_FIELDS[schema]:
        raise CaptureScopeError('completed capture receipt has unknown or missing fields')
    if value.get('qualification') != dependency.QUALIFICATION:
        raise CaptureScopeError('capture receipt cannot authorize qualification')
    if value.get(field) != dependency.digest({k: v for k, v in value.items() if k != field}):
        raise CaptureScopeError('completed capture receipt fingerprint mismatch')
    return value


def original_source_fingerprint(root: Path, snapshot: dict[str, Any]) -> str:
    """Reconstruct the original exporter's broad identity from original Git bytes."""
    dependency.validate_snapshot(snapshot, root)
    originals = dependency.committed_files(root, snapshot['gitHead'])
    paths = sorted({'Package.swift', 'docs/BASELINE_CORPUS.json',
                    'docs/ROADMAP_EXECUTION_BASELINE.json'} |
                   {n for n in originals if n.startswith('Sources/')})
    digest = hashlib.sha256()
    for name in paths:
        digest.update(name.encode('utf-8') + b'\0' + originals[name])
    return digest.hexdigest()


def verify_probe_file(root: Path, build: dict[str, Any]) -> dict[str, Any]:
    path = transaction.local_path(root, build['probePath'])
    if producer.file_hash(path, dependency.MAX_METADATA_BYTES) != build['probeSha256']:
        raise CaptureScopeError('actual initialization probe changed')
    actual = dependency.read_json(path)
    if actual != build['probe']:
        raise CaptureScopeError('embedded initialization probe differs from actual probe file')
    return actual


def read_completed_capture(root: Path, directory: str) -> dict[str, Any]:
    """Verify the registered driver's whole/role witnesses, outputs and parity.

    No caller-supplied invocation callback, inferred success, historical backfill,
    or incomplete job can substitute for the completed registered operation.
    Returned envelopes describe their original source; they are never retagged.
    """
    base = transaction.local_path(root, directory)
    if not directory.startswith('docs/local/reports/producer-validation-') or not base.is_dir():
        raise CaptureScopeError('unknown completed capture directory')
    def read(name):
        path = transaction.local_path(root, directory + '/' + name)
        producer.file_hash(path, dependency.MAX_METADATA_BYTES)
        return dependency.read_json(path)
    validation = sealed(read('validation.json'), driver.SCHEMA, 'validationFingerprint')
    build = sealed(read('build.json'), producer.BUILD_SCHEMA, 'receiptFingerprint')
    snapshot = read('snapshot.json')
    dependency.validate_snapshot(snapshot, root)
    if validation.get('gitHead') != snapshot['gitHead'] or validation.get('snapshotFingerprint') != snapshot['snapshotFingerprint']:
        raise CaptureScopeError('completed validation has a different source freeze')
    if validation.get('buildReceiptFingerprint') != build['receiptFingerprint']:
        raise CaptureScopeError('completed validation has a different build')
    if build['source']['gitHead'] != snapshot['gitHead'] or build['source']['files'] != {n: r['sha256'] for n, r in snapshot['files'].items()}:
        raise CaptureScopeError('actual build source differs from dependency origin')
    probe = verify_probe_file(root, build)
    producer.validate_probe(root, probe, image=Path(probe['compiledImagePath']), corpus_name=probe['captureCorpusPath'])
    if read('context.json') != snapshot['context'] or producer.capture_context(root, build) != snapshot['context']:
        raise CaptureScopeError('native context differs from original dependency context')
    original_python = producer.original_python_witness(build)
    if validation.get('captureCorpusPath') != probe['captureCorpusPath'] or validation.get('initialStateCount') != len(probe['initialStates']):
        raise CaptureScopeError('completed validation has different private initialization coverage')
    bindings = {family: read(family + '-binding.json') for family in driver.LAYOUT}
    if validation.get('bindingFingerprints') != {n: b['bindingFingerprint'] for n, b in bindings.items()}:
        raise CaptureScopeError('completed validation names different capture bindings')
    namespace = validation.get('referenceNamespace')
    if not isinstance(namespace, str) or not namespace.startswith('cold-') or len(namespace) != 37 or any(c not in '0123456789abcdef' for c in namespace[5:]):
        raise CaptureScopeError('unknown registered reference namespace')
    expected_processes = []
    expected_reference_outputs = []
    assets = 0
    for reference in [False, True]:
        for family, (kind, target, validator) in driver.LAYOUT.items():
            selected = namespace if reference else 'v1'
            suffix = 'reference-' if reference else ''
            expected_processes.extend([
                (driver.select_filter(build['probeArgv'], target), family + '-' + suffix + 'native.log'),
                ([original_python['executablePath'], 'scripts/' + validator, 'check', '--namespace', selected, '--corpus', probe['captureCorpusPath']], family + '-' + suffix + 'cold-check.log')])
            # Original commands bind the sealed driver witness. Current Python
            # belongs to later reanalysis and must not rewrite capture history.
            if reference:
                observed_name = 'docs/local/reports/' + kind + '-v1/manifest.json'
                reference_name = 'docs/local/reports/' + kind + '-' + namespace + '/manifest.json'
                observed = dependency.read_json(transaction.local_path(root, observed_name))
                expected = dependency.read_json(transaction.local_path(root, reference_name))
                assets += driver.exact_bank_parity(root, observed, expected, family)
                names = [reference_name, *driver.wave_index(expected, family).values()]
                if family == 'role-stem-capture':
                    names.append('docs/local/reports/' + kind + '-' + namespace + '/foundation-behavior-coverage.json')
                expected_reference_outputs.extend(transaction.output_record(root, n) for n in sorted(names))
                continue
            binding = bindings[family]
            transaction.validate_binding(binding, root, bindings=bindings)
            if binding['originSnapshot'] != snapshot:
                raise CaptureScopeError('capture binding has a different original freeze')
            declared = read(family + '-declaration.json')
            scope = snapshot['families'][family]
            expected_declaration = {'schema': producer.DECLARATION_SCHEMA, 'familyId': family,
                'dependencySnapshotFingerprint': snapshot['snapshotFingerprint'], 'gitHead': snapshot['gitHead'],
                'contractBaselineFingerprint': snapshot['executionFingerprint'],
                'producerInputs': scope['producerInputs'],
                'producerContext': {k: v for k, v in snapshot['context'].items() if k != 'pythonIdentity'},
                'upstreamProducerFingerprints': {n: snapshot['families'][n]['producerFingerprint'] for n in scope['dependencies']},
                'producerFingerprint': scope['producerFingerprint'], 'compiledImagePath': probe['compiledImagePath'],
                'compiledImageSha256': probe['compiledImageSha256'], 'captureCorpusPath': probe['captureCorpusPath'],
                'captureCorpusSha256': probe['captureCorpusSha256'], 'initialStates': probe['initialStates'],
                'captureEnvironmentSha256': probe['captureEnvironmentSha256']}
            if declared != expected_declaration:
                raise CaptureScopeError('producer declaration differs from actual build and original scope')
            manifest = 'docs/local/reports/' + kind + '-v1/manifest.json'
            witness_name = 'docs/local/reports/' + kind + '-v1/producer-witness.json'
            if witness_name not in {o['path'] for o in binding['outputs']}:
                raise CaptureScopeError('fresh binding omits actual native witness')
            producer.verify_witness(root, dependency.read_json(transaction.local_path(root, witness_name)),
                declared, artifact_name=manifest, actual_arguments=driver.select_filter(probe['actualArguments'], target))
            expected_invocation = {'argv': driver.select_filter(build['probeArgv'], target),
                'environmentFingerprint': snapshot['context']['captureEnvironmentFingerprint'],
                'compiledInputsFingerprint': scope['producerFingerprint']}
            if binding['producerInvocation'] != expected_invocation:
                raise CaptureScopeError('binding producer invocation is not the actual registered operation')
    processes = validation.get('subprocesses')
    if not isinstance(processes, list) or len(processes) != len(expected_processes):
        raise CaptureScopeError('completed validation omits registered operations')
    for observed, (argv, log_name) in zip(processes, expected_processes):
        if not isinstance(observed, dict) or set(observed) != {'argv', 'driverEnvironmentSha256', 'exitCode', 'diagnosticSha256'}:
            raise CaptureScopeError('unknown registered operation receipt fields')
        if observed.get('argv') != argv or type(observed.get('exitCode')) is not int or observed['exitCode'] != 0:
            raise CaptureScopeError('registered native or cold operation did not succeed')
        if producer.file_hash(transaction.local_path(root, directory + '/' + log_name), 16 * 1024 * 1024) != observed.get('diagnosticSha256'):
            raise CaptureScopeError('registered operation diagnostic changed')
    for index, family in enumerate(driver.LAYOUT):
        binding = bindings[family]
        validator_record = processes[index * 2 + 1]
        if binding['validatorInvocation'] != {
                'argv': validator_record['argv'],
                'environmentFingerprint': validator_record['driverEnvironmentSha256'],
                'compiledInputsFingerprint': snapshot['families'][family]['analysisFingerprint']}:
            raise CaptureScopeError('binding validator is not the successful registered cold operation')
        if validator_record['driverEnvironmentSha256'] != build['driverEnvironmentSha256']:
            raise CaptureScopeError('cold validator environment differs from actual build environment')
    if validation.get('exactWaveAssetCount') != assets or validation.get('referenceOutputs') != expected_reference_outputs:
        raise CaptureScopeError('completed reference coverage or exact parity differs')
    if driver.foundation_coverage(root, 'v1') != driver.foundation_coverage(root, namespace):
        raise CaptureScopeError('native foundation behavior parity differs')
    return {'originSnapshot': snapshot, 'bindings': bindings,
            'sourceFingerprint': original_source_fingerprint(root, snapshot),
            'validationFingerprint': validation['validationFingerprint'],
            'qualification': dict(dependency.QUALIFICATION)}
