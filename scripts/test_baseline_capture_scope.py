"""Independent origin preservation and incomplete/promotion rejection controls."""
import copy
import hashlib
import tempfile
from pathlib import Path
import unittest

import baseline_capture_scope as scope
import baseline_dependency_contract as dependency
import baseline_producer_witness as producer
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


if __name__ == '__main__':
    unittest.main()
