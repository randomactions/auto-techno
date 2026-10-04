#!/usr/bin/env python3
"""Execute fresh whole/role captures, cold checks and exact witness-on/off parity.

This driver owns its subprocesses. It never grants artifact currency, skips a
validator, rewrites an old envelope, or supplies native qualification evidence.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_dependency_contract as dependency
import baseline_capture_transaction as transaction
import baseline_producer_witness as producer
import baseline_render_manifest as whole
import stem_capture_manifest as stems

SCHEMA = 'autotechno-baseline-producer-validation.v1'
LAYOUT = {'whole-mix-render': ('baseline-corpus', 'BaselineRenderIntegrationTests', 'baseline_render_manifest.py'),
          'role-stem-capture': ('baseline-stems', 'StemCaptureIntegrationTests', 'stem_capture_manifest.py')}


def fresh_json(root: Path, name: str, value) -> None:
    path = transaction.local_path(root, name)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream:
        stream.write(producer.ascii_canonical(value))


def select_filter(argv: list[str], target: str) -> list[str]:
    values = list(argv)
    if values.count('--filter') != 1:
        raise producer.ProducerWitnessError('unknown registered native argument layout')
    index = values.index('--filter') + 1
    if index == len(values) or values[index] != producer.PROBE_FILTER:
        raise producer.ProducerWitnessError('native probe filter was not registered')
    values[index] = target
    return values


def normalized_manifest(document: dict, family: str) -> dict:
    value = copy.deepcopy(document)
    if family == 'role-stem-capture':
        # Both original hashes are independently cold-validated against their
        # own whole manifests. Only namespace-derived descriptor bytes differ.
        value.pop('wholeMixManifestSha256')
        for entry in value['entries']:
            for file in entry['files']:
                file.pop('wavPath')
    elif family == 'whole-mix-render':
        for entry in value['entries']:
            entry.pop('wavPath')
    else:
        raise producer.ProducerWitnessError('unsupported parity family')
    return value


def wave_index(document: dict, family: str) -> dict[str, str]:
    result = {}
    for entry in document['entries']:
        rows = [(entry['id'], entry['wavPath'])] if family == 'whole-mix-render' else [
            (entry['id'] + '--' + file['signal'], file['wavPath']) for file in entry['files']]
        for key, path in rows:
            if key in result:
                raise producer.ProducerWitnessError('duplicate parity asset identity')
            result[key] = path
    return result


def exact_bank_parity(root: Path, observed: dict, reference: dict, family: str) -> int:
    if normalized_manifest(observed, family) != normalized_manifest(reference, family):
        raise producer.ProducerWitnessError('native witness-on/off typed evidence differs')
    first, second = wave_index(observed, family), wave_index(reference, family)
    if not first or set(first) != set(second):
        raise producer.ProducerWitnessError('native parity asset coverage differs')
    for identity in first:
        left = transaction.local_path(root, first[identity])
        right = transaction.local_path(root, second[identity])
        a = transaction.output_record(root, first[identity])
        b = transaction.output_record(root, second[identity])
        if a['byteCount'] != b['byteCount'] or a['sha256'] != b['sha256']:
            raise producer.ProducerWitnessError('native witness-on/off WAV bytes differ')
        with left.open('rb') as l, right.open('rb') as r:
            while True:
                lbytes, rbytes = l.read(1024 * 1024), r.read(1024 * 1024)
                if lbytes != rbytes:
                    raise producer.ProducerWitnessError('native exact WAV comparison differs')
                if not lbytes:
                    break
    return len(first)


def foundation_coverage(root: Path, namespace: str) -> dict:
    prefix = 'docs/local/reports/'
    name = prefix + 'baseline-stems-' + namespace + '/foundation-behavior-coverage.json'
    value = dependency.read_json(transaction.local_path(root, name))
    for field, kind in [('wholeMixManifestSha256', 'baseline-corpus'), ('roleStemManifestSha256', 'baseline-stems')]:
        actual = producer.file_hash(transaction.local_path(root, prefix + kind + '-' + namespace + '/manifest.json'), dependency.MAX_METADATA_BYTES)
        if value.get(field) != actual:
            raise producer.ProducerWitnessError('foundation coverage source manifest differs')
    value = copy.deepcopy(value)
    del value['wholeMixManifestSha256'], value['roleStemManifestSha256']
    return value


def execute(root: Path, scratch: Path, corpus_name: str) -> dict:
    # The canonical v1 bank is created only in this isolated checkout. Refuse
    # any existing directory before building, even a failed or empty bank.
    for kind, _, _ in LAYOUT.values():
        for base in ['docs/local/audio/', 'docs/local/reports/']:
            if transaction.local_path(root, base + kind + '-v1').exists():
                raise producer.ProducerWitnessError('canonical isolated output already exists')
    environment = dict(os.environ)
    if producer.CONTROLS & environment.keys():
        raise producer.ProducerWitnessError('driver owns metadata controls')
    environment.update(AUTOTECHNO_RUN_BASELINE_RENDER='1', AUTOTECHNO_RUN_STEM_CAPTURE='1',
                       AUTOTECHNO_CAPTURE_NAMESPACE='v1', AUTOTECHNO_CAPTURE_CORPUS=corpus_name)
    label = 'producer-validation-' + uuid.uuid4().hex
    directory = 'docs/local/reports/' + label
    print('Fresh Release build and native initialization probe', flush=True)
    receipt = producer.prepare_exporter(root, scratch, environment)
    context = producer.capture_context(root, receipt)
    snapshot = dependency.capture(root, context)
    dependency.validate_snapshot(snapshot, root)
    fresh_json(root, directory + '/build.json', receipt)
    fresh_json(root, directory + '/context.json', context)
    fresh_json(root, directory + '/snapshot.json', snapshot)
    corpus = json.loads(dependency.regular_bytes(root, corpus_name))
    identities = sorted(whole.expected_entries(corpus))
    subprocesses, bindings = [], []

    def invoke(argv, env, log_name):
        path = transaction.local_path(root, directory + '/' + log_name)
        with path.open('xb') as output:
            process = subprocess.run(argv, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT, check=False)
        if path.stat().st_size > 16 * 1024 * 1024:
            raise producer.ProducerWitnessError('capture/check diagnostic exceeds bound')
        subprocesses.append({'argv': argv, 'driverEnvironmentSha256': dependency.digest(env),
            'exitCode': process.returncode, 'diagnosticSha256': producer.file_hash(path, 16 * 1024 * 1024)})
        if process.returncode != 0:
            raise producer.ProducerWitnessError('registered capture/check failed; local diagnostic: ' + str(path))
        return process.returncode

    for family, (kind, target, validator) in LAYOUT.items():
        print('Fresh witnessed capture and independent cold check: ' + family, flush=True)
        declared = producer.declaration(root, family, snapshot, receipt)
        declaration_name = directory + '/' + family + '-declaration.json'
        fresh_json(root, declaration_name, declared)
        env = dict(environment, AUTOTECHNO_BASELINE_DEPENDENCY_DECLARATION=declaration_name)
        argv = select_filter(receipt['probeArgv'], target)
        actual = select_filter(receipt['probe']['actualArguments'], target)
        manifest = 'docs/local/reports/' + kind + '-v1/manifest.json'
        witness_name = 'docs/local/reports/' + kind + '-v1/producer-witness.json'
        paths = [manifest, witness_name]
        if family == 'whole-mix-render':
            paths += ['docs/local/audio/' + kind + '-v1/' + identity + '.wav' for identity in identities]
        else:
            paths += ['docs/local/audio/' + kind + '-v1/' + identity + '--' + signal + '.wav'
                      for identity in identities for signal in sorted(stems.SIGNALS)]
            paths.append('docs/local/reports/' + kind + '-v1/foundation-behavior-coverage.json')
        def produce():
            code = invoke(argv, env, family + '-native.log')
            producer.verify_witness(root, dependency.read_json(transaction.local_path(root, witness_name)),
                declared, artifact_name=manifest, actual_arguments=actual)
            return code
        validator_argv = [sys.executable, 'scripts/' + validator, 'check', '--namespace', 'v1', '--corpus', corpus_name]
        def validate():
            return invoke(validator_argv, environment, family + '-cold-check.log')
        bound = transaction.record_fresh_capture(root, family, context, paths,
            {'argv': argv, 'environmentFingerprint': context['captureEnvironmentFingerprint'],
             'compiledInputsFingerprint': declared['producerFingerprint']},
            {'argv': validator_argv, 'environmentFingerprint': dependency.digest(environment),
             'compiledInputsFingerprint': snapshot['families'][family]['analysisFingerprint']},
            produce, validate, upstream_bindings=bindings)
        bindings.append(bound)
        fresh_json(root, directory + '/' + family + '-binding.json', bound)

    reference_namespace = 'cold-' + uuid.uuid4().hex
    reference_environment = dict(environment, AUTOTECHNO_CAPTURE_NAMESPACE=reference_namespace)
    assets = 0
    reference_outputs = []
    for family, (kind, target, validator) in LAYOUT.items():
        print('Witness-disabled reference and exact parity: ' + family, flush=True)
        invoke(select_filter(receipt['probeArgv'], target), reference_environment, family + '-reference-native.log')
        invoke([sys.executable, 'scripts/' + validator, 'check', '--namespace', reference_namespace, '--corpus', corpus_name],
               reference_environment, family + '-reference-cold-check.log')
        first = dependency.read_json(transaction.local_path(root, 'docs/local/reports/' + kind + '-v1/manifest.json'))
        second = dependency.read_json(transaction.local_path(root, 'docs/local/reports/' + kind + '-' + reference_namespace + '/manifest.json'))
        assets += exact_bank_parity(root, first, second, family)
        reference_names = ['docs/local/reports/' + kind + '-' + reference_namespace + '/manifest.json']
        reference_names += list(wave_index(second, family).values())
        if family == 'role-stem-capture':
            reference_names.append('docs/local/reports/' + kind + '-' + reference_namespace + '/foundation-behavior-coverage.json')
        reference_outputs += [transaction.output_record(root, n) for n in sorted(reference_names)]
    if foundation_coverage(root, 'v1') != foundation_coverage(root, reference_namespace):
        raise producer.ProducerWitnessError('foundation behavior coverage differs')
    if dependency.capture(root, context) != snapshot:
        raise producer.ProducerWitnessError('frozen inputs changed during native parity')
    pool = {b['familyId']: b for b in bindings}
    for binding in bindings:
        transaction.validate_binding(binding, root, bindings=pool)
    if [transaction.output_record(root, o['path']) for o in reference_outputs] != reference_outputs:
        raise producer.ProducerWitnessError('reference outputs changed during final validation')
    report = {'schema': SCHEMA, 'gitHead': snapshot['gitHead'], 'snapshotFingerprint': snapshot['snapshotFingerprint'],
        'buildReceiptFingerprint': receipt['receiptFingerprint'], 'bindingFingerprints': {n: b['bindingFingerprint'] for n,b in pool.items()},
        'captureCorpusPath': corpus_name, 'exactWaveAssetCount': assets, 'initialStateCount': len(receipt['probe']['initialStates']),
        'referenceNamespace': reference_namespace, 'referenceOutputs': reference_outputs, 'subprocesses': subprocesses, 'qualification': dict(dependency.QUALIFICATION)}
    report['validationFingerprint'] = dependency.digest(report)
    fresh_json(root, directory + '/validation.json', report)
    print('Verified native whole/role parity; ' + str(assets) + ' exact WAV assets. No currency or qualification claim.', flush=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scratch', type=Path, required=True, help='absent absolute scratch directory for a fresh Release build')
    parser.add_argument('--corpus', default='docs/BASELINE_CORPUS.json')
    args = parser.parse_args()
    try:
        execute(Path(__file__).resolve().parents[1], args.scratch, args.corpus)
    except (producer.ProducerWitnessError, dependency.DependencyContractError, transaction.CaptureTransactionError) as exc:
        print('Producer validation refused: ' + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__': raise SystemExit(main())
