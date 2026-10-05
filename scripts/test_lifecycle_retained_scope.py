"""Metadata wiring controls; mocked adapter is not native qualification proof."""
import copy
import io
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import test_baseline_lifecycle_policy as fixtures
import test_phase_one_gate as gate_fixtures
import baseline_retained_capture as retained
import baseline_producer_witness as producer
import baseline_dependency_contract as dependency

gate = gate_fixtures.gate
# Fixture loaders can replace sys.modules after the gate imports lifecycle.
# Patch the actual module invoked by the gate, independent of test load order.
lifecycle = gate.lifecycle


class RetainedLifecycleScopeTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.fixture = fixtures.BaselineLifecyclePolicyTests()
        self.policy = self.fixture.policy()
        self.fixture.write_artifacts(self.root, self.policy)
        self.documents = {}
        for family in lifecycle.RETAINED_FAMILIES:
            node = next(n for n in self.policy['nodes'] if n['id'] == family)
            path = self.root / node['artifactPath']
            document = json.loads(path.read_text())
            document.update(contractBaselineFingerprint='9' * 64, gitHead='a' * 40)
            path.write_text(json.dumps(document))
            self.documents[family] = document

    def origin(self, root, directory, family):
        self.assertEqual(directory, 'explicit-proof')
        return {'gitHead': 'a' * 40, 'originSnapshotFingerprint': 'b' * 64,
            'validationFingerprint': 'c' * 64,
            'contractBaselineFingerprint': '9' * 64, 'sourceFingerprint': '3' * 64,
            'currentGitHead': 'd' * 40, 'currentSnapshotFingerprint': 'e' * 64,
            'currentContractBaselineFingerprint': '1' * 64,
            'currentCaptureContextFingerprint': 'f' * 64,
            'currentSourceFreezeFingerprint': '0' * 64,
            'currentProbeVerification': {
                'probePath': 'docs/local/reports/retained-capture-probe-' + '1' * 32 + '/probe.json',
                'probeSha256': '2' * 64, 'diagnosticSha256': '3' * 64,
                'invocationFingerprint': '4' * 64, 'actualArgumentsFingerprint': '5' * 64},
            'action': 'revalidation-required', 'manifests': copy.deepcopy(self.documents),
            'qualification': {'runtimeInput': False, 'promotionAuthorized': False,
                'artifactCurrencyEstablished': False}}

    def assess(self):
        with patch.dict(os.environ, {retained.PROOF_ENV: 'explicit-proof'}), \
            patch.object(retained, 'origin_for_validator', side_effect=self.origin):
            return lifecycle.assess(self.root, self.policy)

    def test_live_adapter_wiring_preserves_original_envelopes(self):
        before = {f: json.dumps(d, sort_keys=True) for f, d in self.documents.items()}
        assessment = self.assess()
        self.assertEqual(lifecycle.validate_assessment(assessment), [])
        self.assertFalse(assessment['qualification']['contentValidatorsExecuted'])
        for node in assessment['nodes']:
            if node['id'] in lifecycle.RETAINED_FAMILIES:
                self.assertEqual(node['state'], 'current-metadata')
                self.assertEqual(node['identityEnvelope']['contractBaselineFingerprint'], '9' * 64)
                self.assertEqual(node['currentVerification']['currentContractBaselineFingerprint'], '1' * 64)
                self.assertEqual(node['currentVerification']['originGitHead'], 'a' * 40)
            else:
                self.assertIsNone(node['currentVerification'])
        self.assertEqual(before, {f: json.dumps(d, sort_keys=True) for f, d in self.documents.items()})

    def test_default_legacy_path_still_requires_regeneration(self):
        with patch.dict(os.environ, {}, clear=True):
            assessment = lifecycle.assess(self.root, self.policy)
        states = {n['id']: n['state'] for n in assessment['nodes']}
        self.assertEqual(states['whole-mix-render'], 'regeneration-required')
        self.assertTrue(all(n['currentVerification'] is None for n in assessment['nodes']))

    def test_rejected_selector_has_no_current_contract_fallback(self):
        # Even a legacy-current envelope cannot hide a rejected explicit proof.
        for family, document in self.documents.items():
            document['contractBaselineFingerprint'] = '1' * 64
            node = next(n for n in self.policy['nodes'] if n['id'] == family)
            (self.root / node['artifactPath']).write_text(json.dumps(document))
        with patch.dict(os.environ, {retained.PROOF_ENV: 'unknown-proof'}), \
            patch.object(retained, 'origin_for_validator', side_effect=retained.RetainedCaptureError('unknown proof')):
            assessment = lifecycle.assess(self.root, self.policy)
        self.assertEqual(lifecycle.validate_assessment(assessment), [])
        self.assertTrue(all(n['state'] == 'unavailable' for n in assessment['nodes'] if n['id'] in lifecycle.RETAINED_FAMILIES))

    def test_unsupported_stale_family_cannot_inherit_supported_proof(self):
        node = next(n for n in self.policy['nodes'] if n['id'] == 'signal-baseline')
        path = self.root / node['artifactPath']
        document = json.loads(path.read_text()); document['contractBaselineFingerprint'] = '9' * 64
        path.write_text(json.dumps(document))
        assessment = self.assess()
        signal = next(n for n in assessment['nodes'] if n['id'] == 'signal-baseline')
        self.assertEqual(signal['state'], 'regeneration-required')
        self.assertIsNone(signal['currentVerification'])
        self.assertLess(assessment['summary']['current-metadata'], 15)

    def test_loaded_artifact_substitution_refuses(self):
        self.documents['whole-mix-render']['engineVersion'] = 'foreign-engine'
        assessment = self.assess()
        whole = next(n for n in assessment['nodes'] if n['id'] == 'whole-mix-render')
        self.assertEqual(whole['state'], 'unavailable')
        self.assertIn('differs from verified original', whole['reasons'][0])

    def test_resealed_verification_refuses_forbidden_and_malformed_fields(self):
        assessment = self.assess()
        node = next(n for n in assessment['nodes'] if n['id'] == 'whole-mix-render')
        cases = [('familyId', 'performance-envelope'), ('action', 'recapture-required'),
            ('action', []), ('currentContractBaselineFingerprint', 'f' * 64),
            ('originSourceFingerprint', 'f' * 64), ('originGitHead', 'not-a-commit')]
        for key, value in cases:
            changed = copy.deepcopy(node['currentVerification']); changed[key] = value
            changed['verificationFingerprint'] = lifecycle.fingerprint(changed, 'verificationFingerprint')
            self.assertTrue(lifecycle.validate_current_verification(changed, node['id'], node['identityEnvelope'], '1' * 64), key)
        for value in [True, 0, None]:
            changed = copy.deepcopy(node['currentVerification'])
            changed['qualification']['runtimeInput'] = value
            changed['verificationFingerprint'] = lifecycle.fingerprint(changed, 'verificationFingerprint')
            self.assertTrue(lifecycle.validate_current_verification(changed, node['id'], node['identityEnvelope'], '1' * 64))

    def test_resealed_mixed_origin_or_current_pair_refuses(self):
        for key in ['originGitHead', 'originSnapshotFingerprint', 'validationFingerprint',
            'currentGitHead', 'currentSnapshotFingerprint']:
            changed = self.assess()
            child = next(n for n in changed['nodes'] if n['id'] == 'role-stem-capture')
            child['currentVerification'][key] = 'f' * (40 if key.endswith('GitHead') else 64)
            child['currentVerification']['verificationFingerprint'] = lifecycle.fingerprint(child['currentVerification'], 'verificationFingerprint')
            changed['assessmentFingerprint'] = lifecycle.fingerprint(changed, 'assessmentFingerprint')
            self.assertTrue(any('mixes' in e for e in lifecycle.validate_assessment(changed)), key)

    def test_assessment_rejects_missing_node_and_old_schema(self):
        original = self.assess()
        for kind in ['missing-node', 'old-schema']:
            changed = copy.deepcopy(original)
            if kind == 'missing-node': changed['nodes'].pop()
            else: changed['schema'] = 'autotechno-baseline-lifecycle-assessment.v1'
            changed['assessmentFingerprint'] = lifecycle.fingerprint(changed, 'assessmentFingerprint')
            self.assertTrue(lifecycle.validate_assessment(changed), kind)

    def test_resealed_assessment_rejects_missing_verification_and_false_summary(self):
        for kind in ['missing-verification', 'false-summary', 'blocked-parent', 'integer-flags']:
            changed = self.assess()
            if kind == 'missing-verification':
                node = next(n for n in changed['nodes'] if n['id'] == 'whole-mix-render')
                node['currentVerification'] = None
            elif kind == 'false-summary': changed['summary']['current-metadata'] = 999
            elif kind == 'blocked-parent':
                node = next(n for n in changed['nodes'] if n['id'] == 'whole-mix-render')
                node['state'] = 'regeneration-required'
                changed['summary']['current-metadata'] -= 1
                changed['summary']['regeneration-required'] += 1
            else: changed['qualification']['contentValidatorsExecuted'] = 0
            changed['assessmentFingerprint'] = lifecycle.fingerprint(changed, 'assessmentFingerprint')
            self.assertTrue(lifecycle.validate_assessment(changed), kind)

    def test_phase_one_preserves_scope_and_rejects_artifact_hash_substitution(self):
        report = gate_fixtures.PhaseOneGateTests().report()
        report['context']['sourceFingerprints'] = ['3' * 64, '4' * 64]
        scoped = self.assess()
        for artifact in report['artifacts']:
            if artifact['id'] in lifecycle.RETAINED_FAMILIES:
                node = next(n for n in scoped['nodes'] if n['id'] == artifact['id'])
                artifact['contractBaselineFingerprint'] = '9' * 64
                artifact['sourceFingerprint'] = '3' * 64
                v = copy.deepcopy(node['currentVerification'])
                v['currentContractBaselineFingerprint'] = report['context']['contractBaselineFingerprint']
                v['artifactSha256'] = artifact['fileSha256']
                v['verificationFingerprint'] = lifecycle.fingerprint(v, 'verificationFingerprint')
                artifact['currentVerification'] = v
        report['gateFingerprint'] = gate.fingerprint(report, 'gateFingerprint')
        self.assertEqual(gate.validate_report(report, self.policy), [])
        changed = copy.deepcopy(report)
        artifact = next(a for a in changed['artifacts'] if a['id'] == 'whole-mix-render')
        artifact['currentVerification']['artifactSha256'] = 'f' * 64
        artifact['currentVerification']['verificationFingerprint'] = lifecycle.fingerprint(artifact['currentVerification'], 'verificationFingerprint')
        changed['gateFingerprint'] = gate.fingerprint(changed, 'gateFingerprint')
        self.assertTrue(any('different artifact bytes' in e for e in gate.validate_report(changed, self.policy)))
        for kind in ['missing-scope', 'omitted-origin', 'unsupported-family']:
            changed = copy.deepcopy(report)
            artifact = next(a for a in changed['artifacts'] if a['id'] == 'whole-mix-render')
            if kind == 'missing-scope': artifact['currentVerification'] = None
            elif kind == 'omitted-origin': changed['context']['sourceFingerprints'] = ['4' * 64]
            else:
                other = next(a for a in changed['artifacts'] if a['id'] == 'performance-envelope')
                v = copy.deepcopy(artifact['currentVerification']); v['familyId'] = other['id']
                v['verificationFingerprint'] = lifecycle.fingerprint(v, 'verificationFingerprint')
                other['currentVerification'] = v
            changed['gateFingerprint'] = gate.fingerprint(changed, 'gateFingerprint')
            self.assertTrue(gate.validate_report(changed, self.policy), kind)

    def test_post_gate_byte_checks_reject_source_probe_diagnostic_and_invocation_drift(self):
        # Exercise byte/source accounting with a synthetic probe. Native parsing
        # is mocked here; actual current native qualification remains unproved.
        node = next(n for n in self.assess()['nodes'] if n['id'] == 'whole-mix-render')
        value = copy.deepcopy(node['currentVerification'])
        freeze = {'gitHead': value['currentGitHead'], 'files': {}}
        value['currentSourceFreezeFingerprint'] = dependency.digest(freeze)
        path = self.root / value['currentProbePath']; path.parent.mkdir(parents=True)
        probe = {'compiledImagePath': '/private/tmp/synthetic-only-image',
            'captureCorpusPath': 'docs/BASELINE_CORPUS.json', 'actualArguments': ['synthetic-only']}
        path.write_text(json.dumps(probe)); diagnostic = path.with_name('native.log')
        diagnostic.write_text('synthetic-only\n')
        value['currentProbeSha256'] = producer.file_hash(path)
        value['currentProbeDiagnosticSha256'] = producer.file_hash(diagnostic)
        value['currentProbeActualArgumentsFingerprint'] = dependency.digest(probe['actualArguments'])
        with patch.object(producer, 'source_freeze', return_value=freeze), \
            patch.object(producer, 'validate_probe'):
            lifecycle.require_current_verification_bytes(self.root, value)
            for field in ['currentProbeSha256', 'currentProbeDiagnosticSha256',
                'currentSourceFreezeFingerprint', 'currentProbeActualArgumentsFingerprint']:
                changed = copy.deepcopy(value); changed[field] = 'f' * 64
                with self.assertRaises(lifecycle.BaselineLifecycleError):
                    lifecycle.require_current_verification_bytes(self.root, changed)

    def scoped_report(self):
        report = gate_fixtures.PhaseOneGateTests().report()
        report['context']['sourceFingerprints'] = ['3' * 64, '4' * 64]
        scoped = self.assess()
        for artifact in report['artifacts']:
            if artifact['id'] in lifecycle.RETAINED_FAMILIES:
                node = next(n for n in scoped['nodes'] if n['id'] == artifact['id'])
                artifact['contractBaselineFingerprint'] = '9' * 64
                artifact['sourceFingerprint'] = '3' * 64
                v = copy.deepcopy(node['currentVerification'])
                v['currentContractBaselineFingerprint'] = report['context']['contractBaselineFingerprint']
                v['artifactSha256'] = artifact['fileSha256']
                v['verificationFingerprint'] = lifecycle.fingerprint(v, 'verificationFingerprint')
                artifact['currentVerification'] = v
        report['gateFingerprint'] = gate.fingerprint(report, 'gateFingerprint')
        return report

    def test_fresh_receipts_compare_only_after_both_saved_byte_checks(self):
        # Mocked build_report isolates comparison, not the actual 19-gate run.
        before = self.scoped_report(); after = copy.deepcopy(before)
        for a in after['artifacts']:
            v = a.get('currentVerification')
            if v:
                v['currentProbePath'] = 'docs/local/reports/retained-capture-probe-' + '2' * 32 + '/probe.json'
                v['currentProbeSha256'] = '6' * 64
                v['currentProbeDiagnosticSha256'] = '7' * 64
                v['verificationFingerprint'] = lifecycle.fingerprint(v, 'verificationFingerprint')
        after['gateFingerprint'] = gate.fingerprint(after, 'gateFingerprint')
        self.assertEqual(gate.validate_report(after, self.policy), [])
        path = self.root / gate.REPORT_PATH; path.write_text(json.dumps(before))
        (self.root / gate.MARKDOWN_PATH).write_text(gate.render_markdown(before))
        with patch.object(gate, 'build_report', return_value=after), \
            patch.object(lifecycle, 'load_json', return_value=self.policy), \
            patch.object(lifecycle, 'require_current_verification_bytes') as check:
            self.assertEqual(gate.run_check(self.root, io.StringIO()), 0)
            self.assertEqual(check.call_count, 2)
            self.assertEqual({c.args[1]['currentProbeSha256'] for c in check.call_args_list}, {'2' * 64})
        with patch.object(gate, 'build_report', return_value=after), \
            patch.object(lifecycle, 'load_json', return_value=self.policy), \
            patch.object(lifecycle, 'require_current_verification_bytes', side_effect=lifecycle.BaselineLifecycleError('probe changed')):
            with self.assertRaises(lifecycle.BaselineLifecycleError):
                gate.run_check(self.root, io.StringIO())
        self.assertEqual(json.loads(path.read_text()), before)

    def test_fresh_receipt_comparison_preserves_every_semantic_identity(self):
        before = self.scoped_report()
        for key in ['originSnapshotFingerprint', 'validationFingerprint',
            'currentSnapshotFingerprint', 'currentCaptureContextFingerprint',
            'currentSourceFreezeFingerprint', 'currentProbeInvocationFingerprint',
            'currentProbeActualArgumentsFingerprint', 'artifactSha256']:
            changed = copy.deepcopy(before)
            for artifact in changed['artifacts']:
                v = artifact.get('currentVerification')
                if v:
                    v[key] = '8' * 64
                    v['verificationFingerprint'] = lifecycle.fingerprint(v, 'verificationFingerprint')
            changed['gateFingerprint'] = gate.fingerprint(changed, 'gateFingerprint')
            self.assertFalse(gate.same_verified_basis(before, changed), key)


class RetainedGateFixtureImportOrderTests(unittest.TestCase):
    def check_order(self, modules):
        # A fresh interpreter preserves the problematic import ordering. Run
        # the existing behavior controls, including both saved receipt-byte
        # checks, rather than asserting only that module aliases match.
        script = """
import importlib, importlib.util, sys, unittest
sys.path.insert(0, sys.argv[1])
for name in sys.argv[3].split(','):
    if name == 'test_lifecycle_retained_scope':
        spec = importlib.util.spec_from_file_location(name, sys.argv[2])
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
    else:
        importlib.import_module(name)
module = sys.modules['test_lifecycle_retained_scope']
suite = unittest.defaultTestLoader.loadTestsFromTestCase(
    module.RetainedLifecycleScopeTests)
result = unittest.TextTestRunner().run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
"""
        result = subprocess.run([
            sys.executable, '-c', script,
            str(Path(fixtures.__file__).resolve().parent),
            str(Path(__file__).resolve()), ','.join(modules),
        ], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_gate_loaded_before_fixture_replacement(self):
        self.check_order([
            'test_phase_one_gate', 'test_baseline_lifecycle_policy',
            'test_lifecycle_retained_scope',
        ])

    def test_affected_tooling_bank_import_order(self):
        self.check_order([
            'test_baseline_capture_scope', 'test_baseline_capture_transaction',
            'test_baseline_dependency_contract', 'test_baseline_producer_capture_driver',
            'test_baseline_producer_witness', 'test_baseline_retained_capture',
            'test_baseline_validation_session', 'test_lifecycle_retained_scope',
            'test_phase_one_gate', 'test_tracked_derived_capture',
            'test_baseline_lifecycle_policy', 'test_baseline_render_manifest',
            'test_stem_capture_manifest', 'test_authority_surface_inventory',
        ])


if __name__ == '__main__': unittest.main()
