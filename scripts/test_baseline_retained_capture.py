"""Controls for actual registered re-probing and retained-capture refusal."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import baseline_dependency_contract as dependency
import baseline_retained_capture as retained
import test_baseline_render_manifest as whole_fixtures
import test_stem_capture_manifest as stem_fixtures


class RetainedCaptureTests(unittest.TestCase):
    def build(self):
        argv = ['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift',
            'build', '--build-tests', '--build-path', '/private/tmp/absent-build',
            '-c', 'release', '--jobs', '2', '--triple', 'arm64-apple-macosx',
            '--sdk', '/SDK', '-Xswiftc', '-enable-testing']
        return {'buildArgv': argv, 'buildConfiguration': 'release', 'targetTriple': argv[10],
            'compilerFlagsFingerprint': dependency.digest(argv),
            'probeArgv': [argv[0], 'test', '--skip-build', '--no-parallel', *argv[3:], '--filter', retained.producer.PROBE_FILTER]}

    def test_registered_probe_preserves_exact_original_flags(self):
        build = self.build()
        self.assertEqual(retained.registered_probe(build), build['probeArgv'])
        self.assertEqual(build['buildArgv'][1:3], ['build', '--build-tests'])

    def test_resealed_flag_or_filter_changes_do_not_select_other_native_work(self):
        original = self.build()
        for index, replacement in [(6, 'debug'), (8, '8'), (14, '-Ounchecked'), (3, '--package-path')]:
            build = copy.deepcopy(original)
            build['buildArgv'][index] = replacement
            build['compilerFlagsFingerprint'] = dependency.digest(build['buildArgv'])
            build['probeArgv'] = [build['buildArgv'][0], 'test', '--skip-build', '--no-parallel', *build['buildArgv'][3:], '--filter', retained.producer.PROBE_FILTER]
            with self.assertRaises(retained.RetainedCaptureError): retained.registered_probe(build)
        build = copy.deepcopy(original)
        build['probeArgv'][-1] = 'UnregisteredExporter'
        with self.assertRaises(retained.RetainedCaptureError): retained.registered_probe(build)

    def test_inconsistent_release_or_target_metadata_refuses(self):
        for key, value in [('buildConfiguration', 'debug'), ('targetTriple', 'foreign-target')]:
            build = self.build(); build[key] = value
            with self.assertRaises(retained.RetainedCaptureError): retained.registered_probe(build)

    def test_unregistered_family_cannot_inherit_whole_stem_proof(self):
        with tempfile.TemporaryDirectory() as name:
            with self.assertRaisesRegex(retained.RetainedCaptureError, 'no registered'):
                retained.origin_for_validator(Path(name), 'docs/local/reports/producer-validation-unknown', 'performance-envelope')

    def test_unknown_proof_refuses_whole_validator_without_cold_success_fallback(self):
        fixture = whole_fixtures.BaselineRenderManifestTests('test_complete_manifest_passes')
        fixture.setUp(); self.addCleanup(fixture.doCleanups)
        with patch.dict('os.environ', {retained.PROOF_ENV: 'docs/local/reports/producer-validation-missing'}):
            errors = whole_fixtures.renders.validate(fixture.root)
        self.assertEqual(len(errors), 1)
        self.assertIn('retained capture proof rejected', errors[0])

    def test_unknown_proof_refuses_stem_validator_without_cold_success_fallback(self):
        fixture = stem_fixtures.StemCaptureManifestTests('test_complete_manifest_passes')
        fixture.setUp(); self.addCleanup(fixture.doCleanups)
        with patch.dict('os.environ', {retained.PROOF_ENV: 'docs/local/reports/producer-validation-missing'}):
            errors = stem_fixtures.stems.validate(fixture.root)
        self.assertEqual(len(errors), 1)
        self.assertIn('retained capture proof rejected', errors[0])

    def test_reference_namespace_cannot_receive_canonical_capture_authority(self):
        fixture = whole_fixtures.BaselineRenderManifestTests('test_complete_manifest_passes')
        fixture.setUp(); self.addCleanup(fixture.doCleanups)
        manifest = copy.deepcopy(fixture.manifest)
        for entry in manifest['entries']:
            original = entry['wavPath']
            entry['wavPath'] = original.replace('baseline-corpus-v1/', 'baseline-corpus-reference/')
            fixture.write_bytes(entry['wavPath'], (fixture.root/original).read_bytes())
        fixture.write_json('docs/local/reports/baseline-corpus-reference/manifest.json', manifest)
        self.assertEqual(whole_fixtures.renders.validate(fixture.root, namespace='reference'), [])
        with patch.dict('os.environ', {retained.PROOF_ENV: 'docs/local/reports/producer-validation-missing'}):
            errors = whole_fixtures.renders.validate(fixture.root, namespace='reference')
        self.assertEqual(errors, ['retained capture proof requires its original canonical namespace'])

    def test_synthetic_authorization_does_not_skip_cold_pcm_integrity(self):
        # This isolates the post-authorization content path. It is deliberately
        # not a native producer, context, capture or retained-currency proof.
        fixture = whole_fixtures.BaselineRenderManifestTests('test_complete_manifest_passes')
        fixture.setUp(); self.addCleanup(fixture.doCleanups)
        original = copy.deepcopy(fixture.manifest)
        authorized = {'gitHead': original['gitHead'],
            'contractBaselineFingerprint': original['contractBaselineFingerprint'],
            'sourceFingerprint': original['sourceFingerprint'],
            'captureCorpusPath': 'docs/BASELINE_CORPUS.json',
            'captureCorpusSha256': original['corpusSha256'],
            'manifests': {'whole-mix-render': original}}
        with patch.dict('os.environ', {retained.PROOF_ENV: 'synthetic-content-path-only'}), \
                patch.object(retained, 'origin_for_validator', return_value=authorized):
            self.assertEqual(whole_fixtures.renders.validate(fixture.root), [])
            entry = original['entries'][0]
            changed, _ = fixture.wav(entry['sampleRate'], [0.0, 0.75, -0.25, 0.0])
            fixture.write_bytes(entry['wavPath'], changed)
            errors = whole_fixtures.renders.validate(fixture.root)
            self.assertTrue(any('sha256' in error.lower() or 'pcm' in error.lower() for error in errors), errors)

    def test_loaded_manifest_substitution_refuses_after_synthetic_authorization(self):
        fixture = whole_fixtures.BaselineRenderManifestTests('test_complete_manifest_passes')
        fixture.setUp(); self.addCleanup(fixture.doCleanups)
        original = copy.deepcopy(fixture.manifest)
        fixture.manifest['entries'][0]['qualityOutcome'] = 'substituted'
        fixture.write_manifest(fixture.manifest)
        with patch.dict('os.environ', {retained.PROOF_ENV: 'synthetic-load-race-only'}), \
                patch.object(retained, 'origin_for_validator', return_value={'manifests': {'whole-mix-render': original}}):
            errors = whole_fixtures.renders.validate(fixture.root)
        self.assertEqual(errors, ['loaded whole manifest differs from the independently verified original'])


if __name__ == '__main__': unittest.main()
