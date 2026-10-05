"""Fresh operation, exact output, source freeze and ancestor binding controls."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_capture_transaction as capture
import baseline_dependency_contract as dependency
import test_baseline_dependency_contract as fixture_module


class CaptureTransactionTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixture_module.DependencyContractTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.fixture.write('.gitignore', 'docs/local/\n')
        self.fixture.capture()
        self.context = self.fixture.context
        self.family = 'whole-mix-render'
        self.manifest = 'docs/local/reports/baseline-corpus-v1/manifest.json'
        self.wave = 'docs/local/audio/fresh.wav'
        self.paths = [self.manifest, self.wave]
        self.info = {'argv': ['producer-fixture'], 'environmentFingerprint': 'a' * 64,
                     'compiledInputsFingerprint': 'b' * 64}
        self.calls = []

    def produce(self):
        self.calls.append('producer')
        self.fixture.write(self.manifest, json.dumps({'schema': 'autotechno-baseline-render-manifest.v1',
            'manifestVersion': 1, 'entries': [{'wavPath': self.wave}]}))
        self.fixture.write(self.wave, 'fresh deterministic fixture PCM bytes')
        return 0

    def validate(self):
        self.calls.append('validator')
        return 0

    def bind(self, producer=None, validator=None, paths=None):
        return capture.record_fresh_capture(self.root, self.family, self.context,
            paths or self.paths, self.info, self.info, producer or self.produce,
            validator or self.validate)

    def reseal(self, value):
        value['bindingFingerprint'] = dependency.digest({k: v for k, v in value.items()
                                                        if k != 'bindingFingerprint'})

    def test_success_orders_real_actions_and_binds_live_bytes(self):
        value = self.bind()
        self.assertEqual(self.calls, ['producer', 'validator'])
        capture.validate_binding(value, self.root)
        self.assertEqual([x['path'] for x in value['outputs']], sorted(self.paths))
        self.assertFalse(value['qualification']['artifactCurrencyEstablished'])
        self.assertFalse(value['qualification']['promotionAuthorized'])

    def test_existing_capture_refuses_before_any_producer_action(self):
        self.fixture.write(self.wave, 'historical fixture')
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'backfill'):
            self.bind()
        self.assertEqual(self.calls, [])
        self.assertEqual((self.root / self.wave).read_text(), 'historical fixture')

    def test_failed_producer_never_calls_validator_or_creates_binding(self):
        for code in [1, -9, None, False, True]:
            with self.subTest(code=code), self.assertRaises(capture.CaptureTransactionError):
                self.bind(producer=lambda: code)
        self.assertEqual(self.calls, [])

    def test_failed_validator_retains_failed_output_without_binding(self):
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'validator'):
            self.bind(validator=lambda: 1)
        self.assertTrue((self.root / self.wave).exists())
        self.assertEqual(self.calls, ['producer'])

    def test_validator_must_not_change_producer_bytes(self):
        def mutating_validator():
            self.fixture.write(self.wave, 'changed independently')
            return 0
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'changed capture bytes'):
            self.bind(validator=mutating_validator)

    def test_changed_committed_source_between_producer_and_validator_refuses(self):
        def changed_source():
            self.fixture.write('Sources/Owner.swift', 'changed source')
            self.fixture.capture()
            return 0
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'dependencies changed'):
            self.bind(validator=changed_source)

    def test_dirty_source_between_producer_and_validator_refuses(self):
        def dirty_source():
            self.fixture.write('Sources/Owner.swift', 'dirty source')
            return 0
        with self.assertRaises(dependency.DependencyContractError):
            self.bind(validator=dirty_source)

    def test_missing_manifest_declaration_refuses_before_any_producer_action(self):
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'declared before production'):
            self.bind(paths=[self.wave])
        self.assertEqual(self.calls, [])

    def test_manifest_without_live_pcm_refuses(self):
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'omits manifest or PCM'):
            self.bind(paths=[self.manifest])

    def test_missing_output_and_wrong_family_schema_refuse(self):
        def missing():
            self.produce()
            (self.root / self.wave).unlink()
            return 0
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'missing'):
            self.bind(producer=missing)
        (self.root / self.manifest).unlink()
        def wrong_schema():
            self.produce()
            self.fixture.write(self.manifest, '{"schema":"wrong.v1"}')
            return 0
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'schema'):
            self.bind(producer=wrong_schema)

    def test_corrupted_output_refuses_even_when_binding_fingerprint_is_resealed(self):
        value = self.bind()
        self.fixture.write(self.wave, 'corrupted output')
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'hash/size'):
            capture.validate_binding(value, self.root)

    def test_omitted_pcm_refuses_even_after_resealing(self):
        value = self.bind()
        value['outputs'] = [x for x in value['outputs'] if x['path'] != self.wave]
        self.reseal(value)
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'omits manifest or PCM'):
            capture.validate_binding(value, self.root)

    def test_symlink_escape_duplicate_and_nonlocal_paths_refuse(self):
        (self.root / 'docs/local').mkdir(parents=True, exist_ok=True)
        (self.root / 'docs/local/escape').symlink_to(self.root / 'Sources', target_is_directory=True)
        for paths in [['docs/local/escape/output'], [self.manifest, self.manifest], ['Sources/output']]:
            with self.subTest(paths=paths), self.assertRaises(capture.CaptureTransactionError):
                self.bind(paths=paths)
        self.assertEqual(self.calls, [])

    def test_unknown_family_incomplete_invocation_and_promotion_refuse(self):
        for key in ['environmentFingerprint', 'compiledInputsFingerprint']:
            info = dict(self.info);del info[key]
            with self.assertRaises(capture.CaptureTransactionError):
                capture.invocation(info)
        self.family = 'unknown'
        with self.assertRaises(capture.CaptureTransactionError): self.bind()
        self.family = 'whole-mix-render'
        value = self.bind();value['qualification']['promotionAuthorized'] = True;self.reseal(value)
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'qualification'):
            capture.validate_binding(value, self.root)

    def test_upstream_coverage_refuses_before_producing_a_child(self):
        self.family = 'role-stem-capture'
        self.paths = ['docs/local/reports/baseline-stems-v1/manifest.json', 'docs/local/audio/role.wav']
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'every exact upstream'):
            self.bind()
        self.assertEqual(self.calls, [])

    def test_child_binds_exact_parent_at_same_frozen_source(self):
        parent = self.bind()
        child_manifest = 'docs/local/reports/baseline-stems-v1/manifest.json'
        child_wave = 'docs/local/audio/role.wav'
        def produce_child():
            self.fixture.write(child_manifest, json.dumps({'schema': 'autotechno-role-stem-manifest.v1',
                'manifestVersion': 1, 'entries': [{'files': [{'wavPath': child_wave}]}]}))
            self.fixture.write(child_wave, 'fresh child PCM fixture')
            return 0
        child = capture.record_fresh_capture(self.root, 'role-stem-capture', self.context,
            [child_manifest, child_wave], self.info, self.info, produce_child, lambda: 0,
            upstream_bindings=[parent])
        capture.validate_binding(child, self.root, bindings={"whole-mix-render": parent})
        self.assertEqual(child['upstreamBindings'], {'whole-mix-render': parent['bindingFingerprint']})
        self.assertEqual(parent['originSnapshot'], child['originSnapshot'])

    def test_parent_mutation_during_child_validation_refuses(self):
        parent = self.bind()
        manifest = 'docs/local/reports/baseline-stems-v1/manifest.json'
        wave = 'docs/local/audio/child.wav'
        def producer():
            self.fixture.write(manifest, json.dumps({'schema': 'autotechno-role-stem-manifest.v1',
                'manifestVersion': 1, 'entries': [{'files': [{'wavPath': wave}]}]}))
            self.fixture.write(wave, 'child fixture')
            return 0
        def validator():
            self.fixture.write(self.wave, 'parent changed during child')
            return 0
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'hash/size'):
            capture.record_fresh_capture(self.root, 'role-stem-capture', self.context,
                [manifest, wave], self.info, self.info, producer, validator, upstream_bindings=[parent])

    def test_changed_parent_output_refuses_before_child_producer(self):
        parent = self.bind()
        self.fixture.write(self.wave, 'corrupted parent')
        with self.assertRaisesRegex(capture.CaptureTransactionError, 'hash/size'):
            capture.record_fresh_capture(self.root, 'role-stem-capture', self.context,
                ['docs/local/reports/baseline-stems-v1/manifest.json'], self.info, self.info, self.produce, self.validate,
                upstream_bindings=[parent])
        self.assertEqual(self.calls, ['producer', 'validator'])


if __name__ == '__main__':
    unittest.main()
