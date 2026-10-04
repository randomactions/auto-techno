"""Adversarial schema/link tests using synthetic diagnostic metadata, not PCM proof."""
from __future__ import annotations
import copy
import unittest
import tempfile
from pathlib import Path
import current_shared_preparation_envelope_report as report

class CurrentSharedEnvelopeTests(unittest.TestCase):
    def test_qualification_seal_is_required_for_identity(self):
        with tempfile.TemporaryDirectory() as path:
            root = Path(path)
            source = root / 'artifact.swift'
            source.write_text('package static let fingerprint: String? = nil')
            with self.assertRaisesRegex(report.Error, 'unqualified Swift identity'):
                report.swift_string(root, 'artifact.swift', 'fingerprint')
            source.write_text('package static let fingerprint: String? = "qualified-identity"')
            self.assertEqual(report.swift_string(root, 'artifact.swift', 'fingerprint'), 'qualified-identity')
            source.write_text(source.read_text() + '\npackage static let fingerprint = "foreign"')
            with self.assertRaises(report.Error):
                report.swift_string(root, 'artifact.swift', 'fingerprint')

    def fixture(self):
        corpus = {'schema': 'autotechno-baseline-corpus.v1', 'corpusVersion': 1,
            'cases': [{'id': f'case-{i}', 'rootSeed': i + 1, 'checkpoint': f'checkpoint-{i}'} for i in range(7)],
            'routes': [{'id': f'native-{rate}', 'sampleRate': rate, 'channelCount': 2} for rate in [44100, 48000]]}
        identity = {field: 'synthetic-' + field for field in report.IDENTITY}
        raw = dict(identity, **{flag: False for flag in report.FLAGS}, schema=report.SCHEMA,
            executionComplete=True, buildConfiguration='release', maximumReservedNumericBytes=report.MAX_BYTES,
            clock={'kind': 'dispatch-uptime-monotonic', 'unit': 'nanoseconds', 'samplingLocation': 'detached-test-process'},
            memory={'kind': 'getrusage-ru_maxrss', 'unit': 'bytes', 'scope': 'whole-test-process-high-water', 'attribution': 'monotonic-process-bound-not-phase-exclusive'},
            machine={'operatingSystem': 'macOS', 'operatingSystemVersion': 'synthetic', 'hardwareModel': 'synthetic',
                'processor': 'synthetic', 'activeProcessorCount': 1, 'physicalMemoryBytes': 1024, 'lowPowerModeEnabled': False, 'thermalState': 'synthetic'},
            trialPolicy={'warmupCount': 1, 'timedTrialCount': 3, 'caseIds': [case['id'] for case in corpus['cases']],
                'sampleRates': [44100, 48000], 'ordering': 'frozen-corpus-case-route-trial', 'warmupObservationsRetained': True},
            measurementScope='all-baseline-checkpoints-through-current-shared-owner',
            phaseTimingAvailability='not-instrumented-shared-owner', referenceStorageScope='exact-journey-product-held-outside-timed-preparation',
            observations=[], producerObservations=[])
        high_water = 256 * 1024 * 1024
        for case in corpus['cases']:
            for route in corpus['routes']:
                nodes = []
                for index in range(2):
                    node = {key: f'synthetic-{key}-{index}' for key in report.NODE_TEXT}
                    node.update(phraseIndex=index, barCount=4, frameCount=4 * round(240 / 130 * route['sampleRate']),
                        renderPassCount=1, preparedOriginMatches=True, commitEligible=True, requiresQualifiedSuccessor=index == 0)
                    for kind in ['Core', 'Render', 'Graph', 'LongHorizon']:
                        node['incoming' + kind + 'Fingerprint'] = f'{kind}-{index}'
                        node['outgoing' + kind + 'Fingerprint'] = f'{kind}-{index + 1}'
                    nodes.append(node)
                for trial in [-1, 0, 1, 2]:
                    raw['observations'].append({'caseId': case['id'], 'routeId': route['id'], 'sampleRate': route['sampleRate'],
                        'channelCount': 2, 'trialIndex': trial, 'isWarmup': trial < 0, 'outcome': 'commit-eligible',
                        'rootSeed': case['rootSeed'], 'checkpoint': case['checkpoint'], 'sourcePhraseIndex': 0,
                        'replayFingerprint': nodes[0]['replayFingerprint'], 'completePreparationNanoseconds': 1000,
                        'processHighWaterBytesBefore': high_water, 'processHighWaterBytesAfter': high_water + 1,
                        'referenceNodes': copy.deepcopy(nodes), 'nodes': copy.deepcopy(nodes), 'exactJourneyIdentityMatch': True,
                        'ownershipValid': True, 'audioDurationNanoseconds': int(nodes[0]['frameCount'] / route['sampleRate'] * 1e9),
                        'qualityOutcome': 'synthetic-accepted', 'qualityReasonCodes': [], 'reservedPeakWorkingBytes': 64 * 1024 * 1024,
                        'retainedNumericBytes': 32 * 1024 * 1024, 'reservedSourceCount': 2, 'reservedMaximumRenderPassCount': 1})
                    high_water += 1
        for frames in [128, 256, 512, 1024]:
            for trial in range(9):
                raw['producerObservations'].append({'id': f'native-stereo-{frames}--trial-{trial}', 'frameCount': frames,
                    'trialIndex': trial, 'operationCount': 128, 'batchNanoseconds': 1000,
                    'droppedPacketDelta': 0, 'rejectedPacketDelta': 0, 'exactRoundTrip': True})
        return raw, corpus, identity

    def rejected(self, change):
        raw, corpus, identity = self.fixture()
        change(raw)
        with self.assertRaises(report.Error): report.validate(raw, corpus, identity)

    def test_complete_matrix_remains_descriptive(self):
        raw, corpus, identity = self.fixture()
        first = report.validate(raw, corpus, identity)
        self.assertEqual(first, report.validate(copy.deepcopy(raw), corpus, identity))
        self.assertTrue(first['requiredMatrixPassed'])
        self.assertEqual(first['timedAcceptedCount'], 42)
        self.assertTrue(all(first[flag] is False for flag in report.FLAGS))
        # A 256 MiB process high-water is not a violation of the separate 128 MiB numeric reservation.
        self.assertEqual(first['routes'][0]['wholeProcessHighWaterBytesMaximum'] > report.MAX_BYTES, True)

    def test_partial_and_foreign_source_cannot_complete(self):
        self.rejected(lambda raw: raw.update(executionComplete=False))
        self.rejected(lambda raw: raw.update(sourceFingerprint='foreign'))
        self.rejected(lambda raw: raw.update(primaryPolicyVersion='foreign'))
        self.rejected(lambda raw: raw.update(longHorizonPolicyVersion='foreign'))

    def test_membership_order_and_warmups_are_fixed(self):
        self.rejected(lambda raw: raw['observations'].pop())
        self.rejected(lambda raw: raw['observations'].__setitem__(1, copy.deepcopy(raw['observations'][0])))
        self.rejected(lambda raw: raw['observations'].reverse())
        self.rejected(lambda raw: raw['observations'][0].update(isWarmup=False))

    def test_each_continuation_link_is_independent(self):
        for kind in ['Core', 'Render', 'Graph', 'LongHorizon']:
            with self.subTest(kind=kind):
                self.rejected(lambda raw, kind=kind: raw['observations'][0]['nodes'][1].update({'incoming' + kind + 'Fingerprint': 'foreign'}))
        self.rejected(lambda raw: raw['observations'][0]['nodes'][-1].update(requiresQualifiedSuccessor=True))
        self.rejected(lambda raw: raw['observations'][0]['nodes'][0].update(preparedOriginMatches=False))

    def test_identity_flag_cannot_hide_different_products(self):
        self.rejected(lambda raw: raw['observations'][0]['nodes'][0].update(sampleHash='foreign'))
        self.rejected(lambda raw: raw['observations'][0]['nodes'][0].update(candidateEvaluationFingerprint='foreign'))
        self.rejected(lambda raw: raw['observations'][0].update(exactJourneyIdentityMatch=False))

    def test_reservations_geometry_and_numeric_types_fail_closed(self):
        self.rejected(lambda raw: raw['observations'][0].update(reservedPeakWorkingBytes=report.MAX_BYTES + 1))
        self.rejected(lambda raw: raw['observations'][0].update(reservedSourceCount=1))
        self.rejected(lambda raw: raw['observations'][0].pop('retainedNumericBytes'))
        self.rejected(lambda raw: raw['observations'][0]['nodes'][0].update(frameCount=1))
        self.rejected(lambda raw: raw['observations'][0].update(rootSeed=1.0))
        self.rejected(lambda raw: raw['producerObservations'][0].update(droppedPacketDelta=False))
        self.rejected(lambda raw: raw['trialPolicy'].update(warmupCount=True))

    def test_no_capacity_activation_or_phase_timing_claims(self):
        for flag in report.FLAGS:
            with self.subTest(flag=flag): self.rejected(lambda raw, flag=flag: raw.update({flag: True}))
        self.rejected(lambda raw: raw['observations'][0].update(renderEvaluationNanoseconds=1))
        self.rejected(lambda raw: raw.update(phaseTimingAvailability='isolated-dsp'))

    def test_refusal_preserved_without_playable_or_timing_fabrication(self):
        raw, corpus, identity = self.fixture()
        original = raw['observations'][0]
        row = {key: original[key] for key in report.BASE}
        row.update(outcome='target-journey-unavailable', failureCode='synthetic-refusal')
        for index in range(4):
            refused = copy.deepcopy(row)
            refused.update(trialIndex=index - 1, isWarmup=index == 0)
            raw['observations'][index] = refused
        summary = report.validate(raw, corpus, identity)
        self.assertFalse(summary['requiredMatrixPassed'])
        self.assertEqual(summary['refusals'][0]['code'], 'synthetic-refusal')
        raw['observations'][0]['completePreparationNanoseconds'] = 0
        with self.assertRaises(report.Error): report.validate(raw, corpus, identity)

    def test_failure_details_remain_bounded_typed_and_deduplicated(self):
        for details in [[str(i) for i in range(25)], [1], ['same', 'same']]:
            raw, corpus, identity = self.fixture()
            for index in range(4):
                old = raw['observations'][index]
                refused = {key: old[key] for key in report.BASE}
                refused.update(outcome='target-journey-unavailable', failureStage='synthetic',
                    failureCode='synthetic', failureDetails=details)
                raw['observations'][index] = refused
            with self.assertRaises(report.Error): report.validate(raw, corpus, identity)

    def test_reference_cannot_move_even_when_each_trial_matches_itself(self):
        def change(raw):
            for field in ['nodes', 'referenceNodes']:
                raw['observations'][1][field][0]['planFingerprint'] = 'moved-together'
        self.rejected(change)

    def test_producer_matrix_and_unknown_fields_fail_closed(self):
        self.rejected(lambda raw: raw['producerObservations'].pop())
        self.rejected(lambda raw: raw['producerObservations'][0].update(droppedPacketDelta=1))
        self.rejected(lambda raw: raw['producerObservations'][0].update(exactRoundTrip=False))
        self.rejected(lambda raw: raw.update(archiveImport=True))

if __name__ == '__main__': unittest.main()
