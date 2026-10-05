"""Independent origin preservation and incomplete/promotion rejection controls."""
import copy
import hashlib
import json
import os
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
from types import SimpleNamespace

import baseline_capture_scope as scope
import baseline_dependency_contract as dependency
import baseline_producer_witness as producer
import baseline_retained_capture as retained
import test_baseline_dependency_contract as fixtures


class CaptureScopeTests(unittest.TestCase):
    def fixture(self):
        fixture = fixtures.DependencyContractTests('test_unchanged_snapshot_is_exact_and_not_currency')
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        return fixture

    def test_original_broad_source_identity_survives_navigation_drift_without_retag(self):
        fixture = self.fixture()
        before = fixture.capture()
        original = copy.deepcopy(before)
        names = sorted(['Package.swift', 'docs/BASELINE_CORPUS.json',
                        'docs/ROADMAP_EXECUTION_BASELINE.json', 'Sources/Owner.swift'])
        expected = hashlib.sha256(b''.join(n.encode() + b'\0' + (fixture.root/n).read_bytes() for n in names)).hexdigest()
        self.assertEqual(scope.original_source_fingerprint(fixture.root, before), expected)
        fixture.write('docs/codebase-map.json', '{"navigationChanged":true}')
        fixture.refresh_contract()
        after = fixture.capture()
        self.assertNotEqual(before['executionFingerprint'], after['executionFingerprint'])
        self.assertEqual(scope.original_source_fingerprint(fixture.root, before), expected)
        self.assertEqual(before, original)
        current = hashlib.sha256(b''.join(n.encode() + b'\0' + (fixture.root/n).read_bytes() for n in names)).hexdigest()
        self.assertNotEqual(current, expected)

    def test_resealed_origin_cannot_replace_original_source_bytes(self):
        fixture = self.fixture()
        before = fixture.capture()
        before['files']['Sources/Owner.swift']['sha256'] = '0' * 64
        fixture.reseal(before)
        with self.assertRaisesRegex(dependency.DependencyContractError, 'origin dependency bytes'):
            scope.original_source_fingerprint(fixture.root, before)

    def test_promotion_bit_refuses_even_with_resealed_receipt(self):
        value = {'schema': 'fixture', 'qualification': dict(dependency.QUALIFICATION)}
        value['qualification']['promotionAuthorized'] = True
        value['fingerprint'] = dependency.digest(value)
        with self.assertRaisesRegex(scope.CaptureScopeError, 'qualification'):
            scope.sealed(value, 'fixture', 'fingerprint')

    def test_changed_completion_receipt_is_rejected(self):
        value = {'schema': 'fixture', 'qualification': dict(dependency.QUALIFICATION), 'count': 224}
        value['fingerprint'] = dependency.digest(value)
        value['count'] = 223
        with self.assertRaisesRegex(scope.CaptureScopeError, 'fingerprint'):
            scope.sealed(value, 'fixture', 'fingerprint')

    def test_unknown_completion_semantics_refuse_even_when_resealed(self):
        value = {key: None for key in scope.RECEIPT_FIELDS[scope.driver.SCHEMA]}
        value.update(schema=scope.driver.SCHEMA, qualification=dict(dependency.QUALIFICATION),
                     bypassContent=True)
        value['validationFingerprint'] = dependency.digest({k: v for k, v in value.items() if k != 'validationFingerprint'})
        with self.assertRaisesRegex(scope.CaptureScopeError, 'unknown or missing'):
            scope.sealed(value, scope.driver.SCHEMA, 'validationFingerprint')

    def test_active_job_directory_does_not_establish_completed_capture(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            directory = 'docs/local/reports/producer-validation-' + '0' * 32
            (root/directory).mkdir(parents=True)
            with self.assertRaises(producer.ProducerWitnessError):
                scope.read_completed_capture(root, directory)

    def test_arbitrary_receipt_location_is_not_registered_capture(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root/'docs/local/reports/arbitrary').mkdir(parents=True)
            with self.assertRaisesRegex(scope.CaptureScopeError, 'directory'):
                scope.read_completed_capture(root, 'docs/local/reports/arbitrary')

    def test_resealed_embedded_probe_cannot_replace_actual_probe_file(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            relative = 'docs/local/reports/probe.json'
            path = root/relative
            path.parent.mkdir(parents=True)
            actual = {'initialStates': [{'sessionStateFingerprint': 'a' * 16}]}
            path.write_text(json.dumps(actual))
            build = {'probePath': relative, 'probeSha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'probe': actual}
            self.assertEqual(scope.verify_probe_file(root, build), actual)
            altered = copy.deepcopy(build)
            altered['probe']['initialStates'][0]['sessionStateFingerprint'] = 'b' * 16
            altered['receiptFingerprint'] = dependency.digest(altered)
            with self.assertRaisesRegex(scope.CaptureScopeError, 'embedded initialization probe'):
                scope.verify_probe_file(root, altered)
            self.assertEqual(json.loads(path.read_text()), actual)


class CompletedCaptureReaderTests(unittest.TestCase):
    """Complete synthetic reader records; native tool subprocesses are stubbed.

    All receipt, source, image, initialization, binding, argv, diagnostic and
    exact output checks execute. These fixtures confer no native/cold authority.
    """
    def setUp(self):
        self.fixture = fixtures.DependencyContractTests()
        self.fixture.setUp(); self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.fixture.write('.gitignore', 'docs/local/\n')
        corpus = {'cases': [{'id': 'case', 'rootSeed': 7}], 'routes': [
            {'id': 'route', 'sampleRate': 48000, 'channelCount': 2,
             'routeGeneration': 1, 'routeRecovery': False}]}
        self.fixture.write('docs/BASELINE_CORPUS.json', json.dumps(corpus))
        corpus_sha = producer.file_hash(self.root/'docs/BASELINE_CORPUS.json')
        self.fixture.context.update(corpusSha256=corpus_sha, captureCorpusSha256=corpus_sha)
        self.fixture.refresh_contract(); self.fixture.capture()
        image = self.root / 'docs/local/image'
        image.parent.mkdir(parents=True, exist_ok=True); image.write_bytes(b'original native image fixture')
        states = [{'id': 'case--route', 'rootSeedHex': '0000000000000007',
            **corpus['routes'][0], 'sessionStateFingerprint': '1'*16,
            'renderStateFingerprint': '2'*16, 'graphStateFingerprint': '3'*16}]
        states[0].pop('id'); states[0]['id'] = 'case--route'
        probe = {'schema': producer.PROBE_SCHEMA, 'probeOnly': True,
            'artifactCurrencyEstablished': False, 'promotionAuthorized': False,
            'compiledImagePath': str(image), 'compiledImageSha256': producer.file_hash(image),
            'captureCorpusPath': 'docs/BASELINE_CORPUS.json',
            'captureCorpusSha256': producer.file_hash(self.root/'docs/BASELINE_CORPUS.json'),
            'captureEnvironmentSha256': 'a'*64, 'actualEnvironmentSha256': 'b'*64,
            'initialStates': states, 'initialStateFingerprint': dependency.digest(states),
            'actualArguments': ['native-helper', '--filter', producer.PROBE_FILTER],
            'engineVersion': 'fixture-engine'}
        self.developer = self.root/'docs/local/Developer'
        swift = self.developer/'Toolchains/XcodeDefault.xctoolchain/usr/bin/swift'
        swift.parent.mkdir(parents=True); swift.write_bytes(b'fixture swift driver')
        (swift.parent/'swiftc').write_bytes(b'fixture swift compiler')
        self.sdk = self.root/'docs/local/SDK'; self.sdk.mkdir()
        (self.sdk/'SDKSettings.json').write_text('{}')
        argv = [str(swift), 'build', '--build-tests', '--build-path', '/original/build',
            '-c', 'release', '--jobs', '2', '--triple', 'arm64-apple-macosx',
            '--sdk', str(self.sdk), '-Xswiftc', '-enable-testing']
        self.directory = 'docs/local/reports/producer-validation-' + '0'*32
        probe_path = self.directory + '/probe.json'
        self.write(probe_path, probe)
        self.build = {'schema': producer.BUILD_SCHEMA, 'source': producer.source_freeze(self.root),
            'buildArgv': argv, 'buildConfiguration': 'release',
            'driverEnvironmentSha256': 'c'*64,
            'swiftCompilerIdentity': dependency.digest({'version': 'fixture swift version',
                'driverSha256': producer.file_hash(swift),
                'compilerSha256': producer.file_hash(swift.parent/'swiftc')}),
            'sdkIdentity': dependency.digest({'path': str(self.sdk), 'version': 'fixture sdk version',
                'settingsSha256': producer.file_hash(self.sdk/'SDKSettings.json')}), 'targetTriple': argv[10],
            'compilerFlagsFingerprint': dependency.digest(argv),
            'probeArgv': [argv[0], 'test', '--skip-build', '--no-parallel', *argv[3:], '--filter', producer.PROBE_FILTER],
            'probePath': probe_path, 'probeSha256': producer.file_hash(self.root/probe_path),
            'probe': probe, 'pythonWitness': producer.current_python_witness(),
            'qualification': dict(dependency.QUALIFICATION)}
        self.seal(self.build, 'receiptFingerprint')
        self.context = producer.capture_context(self.root, self.build)
        self.snapshot = dependency.capture(self.root, self.context)
        self.write(self.directory + '/build.json', self.build)
        self.write(self.directory + '/context.json', self.context)
        self.write(self.directory + '/snapshot.json', self.snapshot)
        self.bindings = {}
        processes, reference_outputs = [], []
        namespace = 'cold-' + '1'*32
        for reference in [False, True]:
            for family, (kind, target, validator) in scope.driver.LAYOUT.items():
                selected = namespace if reference else 'v1'
                manifest_name = 'docs/local/reports/' + kind + '-' + selected + '/manifest.json'
                wave = 'docs/local/audio/' + kind + '-' + selected + '/case.wav'
                node = next(n for n in dependency.lifecycle.NODES if n['id'] == family)
                manifest = {'schema': node['schema'], node['versionField']: node['version'],
                    'entries': [{'id': 'case', 'wavPath': wave}] if family == 'whole-mix-render' else [
                        {'id': 'case', 'files': [{'signal': 'kick', 'wavPath': wave}]}]}
                if family == 'role-stem-capture':
                    manifest['wholeMixManifestSha256'] = producer.file_hash(self.root/('docs/local/reports/baseline-corpus-' + selected + '/manifest.json'))
                paths = [manifest_name, wave]
                native_argv = scope.driver.select_filter(self.build['probeArgv'], target)
                cold_argv = [self.build['pythonWitness']['executablePath'], 'scripts/'+validator,
                             'check', '--namespace', selected, '--corpus', probe['captureCorpusPath']]
                declared = None
                if not reference:
                    declared = producer.declaration(self.root, family, self.snapshot, self.build)
                    self.write(self.directory + '/' + family + '-declaration.json', declared)
                    witness_name = 'docs/local/reports/' + kind + '-v1/producer-witness.json'
                    paths.append(witness_name)
                coverage_name = 'docs/local/reports/baseline-stems-' + selected + '/foundation-behavior-coverage.json'
                if family == 'role-stem-capture': paths.append(coverage_name)
                def produce():
                    self.write(manifest_name, manifest)
                    self.fixture.write(wave, 'exact fixture wave bytes')
                    if not reference:
                        witness = {k: declared[k] for k in ['familyId', 'gitHead', 'contractBaselineFingerprint',
                            'dependencySnapshotFingerprint', 'producerFingerprint', 'compiledImagePath',
                            'compiledImageSha256', 'captureCorpusSha256', 'captureEnvironmentSha256', 'initialStates']}
                        witness.update(schema=producer.WITNESS_SCHEMA, qualification=dict(dependency.QUALIFICATION),
                            actualArguments=scope.driver.select_filter(probe['actualArguments'], target),
                            declarationSha256=hashlib.sha256(producer.ascii_canonical(declared)).hexdigest(),
                            artifactSha256=producer.file_hash(self.root/manifest_name))
                        self.write(witness_name, witness)
                    if family == 'role-stem-capture':
                        self.write(coverage_name, {'coverage': 'fixture',
                            'wholeMixManifestSha256': manifest['wholeMixManifestSha256'],
                            'roleStemManifestSha256': producer.file_hash(self.root/manifest_name)})
                    return 0
                if reference:
                    produce()
                    reference_outputs.extend(scope.transaction.output_record(self.root, p) for p in sorted(paths))
                else:
                    binding = scope.transaction.record_fresh_capture(self.root, family, self.context, paths,
                        {'argv': native_argv, 'environmentFingerprint': self.context['captureEnvironmentFingerprint'],
                         'compiledInputsFingerprint': declared['producerFingerprint']},
                        {'argv': cold_argv, 'environmentFingerprint': self.build['driverEnvironmentSha256'],
                         'compiledInputsFingerprint': self.snapshot['families'][family]['analysisFingerprint']},
                        produce, lambda: 0, upstream_bindings=list(self.bindings.values()))
                    self.bindings[family] = binding
                    self.write(self.directory + '/' + family + '-binding.json', binding)
                for operation, args in [('native', native_argv), ('cold-check', cold_argv)]:
                    log = family + '-' + ('reference-' if reference else '') + operation + '.log'
                    self.fixture.write(self.directory + '/' + log, 'successful synthetic operation diagnostic')
                    processes.append({'argv': args, 'driverEnvironmentSha256': self.build['driverEnvironmentSha256'],
                        'exitCode': 0, 'diagnosticSha256': producer.file_hash(self.root/self.directory/log)})
        self.validation = {'schema': scope.driver.SCHEMA, 'gitHead': self.snapshot['gitHead'],
            'snapshotFingerprint': self.snapshot['snapshotFingerprint'],
            'buildReceiptFingerprint': self.build['receiptFingerprint'],
            'bindingFingerprints': {f: b['bindingFingerprint'] for f,b in self.bindings.items()},
            'captureCorpusPath': probe['captureCorpusPath'], 'exactWaveAssetCount': 2, 'initialStateCount': 1,
            'referenceNamespace': namespace, 'referenceOutputs': reference_outputs,
            'subprocesses': processes, 'qualification': dict(dependency.QUALIFICATION)}
        self.save_validation()

    def write(self, name, value):
        self.fixture.write(name, json.dumps(value))

    def seal(self, value, field):
        value[field] = dependency.digest({k:v for k,v in value.items() if k != field})

    def save_validation(self):
        self.seal(self.validation, 'validationFingerprint')
        self.write(self.directory + '/validation.json', self.validation)

    def read(self):
        return scope.read_completed_capture(self.root, self.directory)

    def test_complete_reader_preserves_original_after_current_python_change_or_relocation(self):
        original = self.read()
        before = {p: producer.file_hash(p) for p in (self.root/'docs/local').rglob('*') if p.is_file()}
        for executable, version in [('/relocated/python', producer.sys.version),
                                    ('/changed/python', 'different current Python')]:
            with patch.object(producer.sys, 'executable', executable), patch.object(producer.sys, 'version', version):
                self.assertEqual(self.read(), original)
        self.assertEqual(before, {p: producer.file_hash(p) for p in before})

    def test_full_retained_path_classifies_current_python_without_retag_or_skipping_probe(self):
        original = self.read()
        native_calls = []
        actual_run = retained.subprocess.run
        actual_environment = dict(os.environ)
        def tool(command, **kwargs):
            if command[0] == 'git':
                return actual_run(command, env=actual_environment, **kwargs)
            env, stdout = kwargs['env'], kwargs['stdout']
            if command[-1] == '--version': payload = 'fixture swift version'
            elif command[-1] == '--show-sdk-path': payload = str(self.sdk)
            elif command[-1] == '--show-sdk-version': payload = 'fixture sdk version'
            elif command[-1] == '-print-target-info': payload = json.dumps({'target': {'triple': self.build['targetTriple']}})
            else:
                self.assertEqual(command, self.build['probeArgv'])
                self.assertEqual(env['AUTOTECHNO_RUN_PRODUCER_WITNESS_PROBE'], '1')
                self.write(env['AUTOTECHNO_PRODUCER_WITNESS_PROBE_OUTPUT'], self.build['probe'])
                native_calls.append(command); payload = 'fresh synthetic native probe diagnostic'
            stdout.write(payload.encode()); return SimpleNamespace(returncode=0)
        with patch.dict('os.environ', {'DEVELOPER_DIR': str(self.developer)}), \
                patch.object(producer.sys, 'version', 'different current Python'), \
                patch.object(retained.subprocess, 'run', side_effect=tool):
            for family in producer.FAMILIES:
                result = retained.origin_for_validator(self.root, self.directory, family)
                self.assertEqual(result['action'], 'reanalysis-required')
                self.assertEqual(result['gitHead'], self.snapshot['gitHead'])
                self.assertEqual(result['originSnapshotFingerprint'], self.snapshot['snapshotFingerprint'])
                self.assertFalse(result['qualification']['artifactCurrencyEstablished'])
                current = dependency.capture(self.root, dict(self.context,
                    pythonIdentity=producer.capture_context(self.root, dict(self.build,
                        pythonWitness=producer.current_python_witness()))['pythonIdentity']))
                self.assertEqual(result['currentCaptureContextFingerprint'], dependency.digest(current['context']))
            self.assertEqual(len(native_calls), 2)
        self.assertEqual(self.read(), original)

    def test_old_or_resealed_original_python_witness_refuses(self):
        for change in [lambda b: b.update(schema='autotechno-baseline-producer-build.v1'),
                       lambda b: b.pop('pythonWitness'),
                       lambda b: b['pythonWitness'].update(version='other original'),
                       lambda b: b['pythonWitness'].update(executableSha256='f'*64),
                       lambda b: b['pythonWitness'].update(executablePath='/substituted/python')]:
            build = copy.deepcopy(self.build); change(build); self.seal(build, 'receiptFingerprint')
            self.write(self.directory + '/build.json', build)
            self.validation['buildReceiptFingerprint'] = build['receiptFingerprint']; self.save_validation()
            with self.assertRaises((scope.CaptureScopeError, producer.ProducerWitnessError)): self.read()

    def test_resealed_validator_argv_diagnostic_exit_and_loaded_image_changes_refuse(self):
        original = copy.deepcopy(self.validation)
        for change in [lambda v: v['subprocesses'][1]['argv'].__setitem__(0, '/other/python'),
                       lambda v: v['subprocesses'][1].update(diagnosticSha256='f'*64),
                       lambda v: v['subprocesses'][1].update(exitCode=1)]:
            self.validation = copy.deepcopy(original); change(self.validation); self.save_validation()
            with self.assertRaises(scope.CaptureScopeError): self.read()
        self.validation = original; self.save_validation()
        Path(self.build['probe']['compiledImagePath']).write_bytes(b'substituted native image')
        with self.assertRaises(producer.ProducerWitnessError): self.read()


if __name__ == '__main__':
    unittest.main()
