"""Adversarial controls for read-only verification, never capture construction."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import at0039_primary_verification as v

ENGINE = 'unit-test-engine'
SOURCE = 'a' * 40


def trajectory(ordinal=0, partition='development'):
    entry = dict(ordinal=ordinal, rootSeed=ordinal + 100,
                 checkpoints=[dict(phraseIndex=i) for i in range(7)])
    reports, successors, observations = [], [], []
    for rate in [44100, 48000]:
        for checkpoint in v.CHECKPOINTS:
            identity = f'{ordinal}-{rate}-{checkpoint}'
            report = dict(sampleRate=rate, checkpoint=checkpoint, engineVersion=ENGINE,
                evidenceFingerprint=identity, routeFingerprint='route', routeGeneration=1,
                sampleHash='pcm', correctionRenderCount=0,
                selectedCandidateEvidence=dict(graphFingerprint='graph',
                    hardGates={key: True for key in v.HARD_GATES}),
                candidateEvaluation=dict(engineVersion=ENGINE, boundsValid=True,
                    sourceAttemptCount=1, attempts=[{}], selectedAttemptIndex=0),
                commitProvenance=dict(outgoingRenderDSPFingerprint='dsp',
                    outgoingQualityStateFingerprint='quality', selectedSampleHash='pcm',
                    candidateEvaluationFingerprint=identity))
            successor = dict(sampleRate=rate, sourceReportFingerprint=identity,
                routeFingerprint='route', routeGeneration=1,
                sourceOutgoingRenderDSPFingerprint='dsp', successorIncomingQualityFingerprint='quality',
                successorPreviousGraphFingerprint='graph', successorIncomingRenderDSPFingerprint='dsp',
                firstBar=dict(sampleRate=rate), sourceIdentityFingerprint=identity)
            observation = dict(sampleRate=rate, checkpoint=checkpoint, engineVersion=ENGINE,
                hardGatesPassed=True, sourceMetricCount=2,
                metrics=[dict(metric='a', value=1), dict(metric='b', value=2)],
                continuousModalSource=dict(sourceIdentityFingerprint=identity,
                    projection=dict(checkpoint=checkpoint, sampleRate=rate,
                                    sourceReportFingerprint=identity)))
            reports.append(report); successors.append(successor); observations.append(observation)
    row = dict(partition=partition, ordinal=ordinal, originalReportCount=14,
               actualSuccessorCount=14, requiredUnavailableObservationCount=0,
               originalBankFingerprint=f'bank-{ordinal}', artifact=f'{partition}-ordinal-{ordinal}.json')
    data = dict(frozenPlanningEntry=copy.deepcopy(entry),
                actualReportBank=dict(engineVersion=ENGINE, sampleRates=[44100, 48000],
                                      sourceReportCount=14, reports=reports),
                actualSuccessorReceipts=successors, requiredUnavailableObservationCount=0,
                continuousTrajectory=dict(sourceBankFingerprint=f'bank-{ordinal}', observations=observations),
                renderedPhraseCounts={'44100': 8, '48000': 8})
    return data, row, entry


def products():
    cohort = dict(gitHead=SOURCE, historicalCohortsRetagged=False,
                  acceptedInputObjects=['input'], development=[], holdout=[])
    protocol = dict(acceptedExecutionHead=SOURCE, acceptedExecutionInputObjects=['input'],
                    archiveImport=False, sampleRates=[44100, 48000], maximumPeakWorkingBytes=134217728,
                    maximumRenderPasses=2, maximumPhrases=128, profileSchema=1, profileVersion='profile',
                    adversarialSchema=1, adversarialVersion='suite', holdoutSchema=1, holdoutVersion='held')
    qualification = dict(status='offline-adversarial-and-holdout-passed-not-activated',
                         runtimeActivation=False, archiveImport=False, profileFingerprint='profile',
                         adversarialFingerprint='suite', holdoutFingerprint='held')
    manifest = dict(acceptedExecutionHead=SOURCE, historicalContextRetagged=False,
                    acceptedExecutionInputObjects=['input'], completedTrajectories=[],
                    status='captured-not-activated', freshCohortRendered=True,
                    fitStatus='complete-offline-unqualified', originalNativeReportCount=644,
                    actualSuccessorReceiptCount=644, offlineContinuousQualification=qualification)
    documents, corpora, held = {}, {'development': [], 'holdout': []}, []
    for ordinal in range(46):
        partition = 'development' if ordinal < 40 else 'holdout'
        data, row, entry = trajectory(ordinal, partition)
        cohort[partition].append(entry); manifest['completedTrajectories'].append(row)
        documents[ordinal] = data; corpora[partition].append(data['continuousTrajectory'])
        if partition == 'holdout':
            held.append(dict(sourceBankFingerprint=f'bank-{ordinal}', acceptedObservationCount=14,
                sourceObservationCount=14, relationshipFailures=[],
                verdicts=[dict(accepted=True, failedMetrics=[], reasons=[], sampleRate=rate, checkpoint=cp)
                          for rate in [44100, 48000] for cp in v.CHECKPOINTS]))
    artifacts = {part: dict(engineVersion=ENGINE, sourceTrajectoryCount=len(rows),
                            sourceObservationCount=14 * len(rows), trajectories=rows)
                 for part, rows in corpora.items()}
    artifacts.update(profile=dict(engineVersion=ENGINE, schemaVersion=1, profileVersion='profile'),
        adversarial=dict(schemaVersion=1, suiteVersion='suite', profileFingerprint='profile',
            cases=[dict(scenario=str(i), rejected=True, expectedReasons=['reason'], actualReasons=['reason'])
                   for i in range(34)], baselineAcceptanceCount=560, sourceObservationCount=560,
            liveBaselineAcceptanceCount=2, liveBaselineObservationFingerprints=['one', 'two']),
        holdoutVerdicts=dict(schemaVersion=1, qualificationVersion='held', engineVersion=ENGINE,
            profileFingerprint='profile', adversarialSuiteFingerprint='suite',
            acceptedObservationCount=84, sourceObservationCount=84, overlappingSourceBankCount=0,
            calibrationTrajectoryCount=40, holdoutTrajectoryCount=6, trajectories=held),
        qualification=qualification)
    log = '✔ Test run with 1 test passed\n'.encode()
    status = dict(exitCode=0, actualInputsUnchanged=True, oneNativeTestPassed=True,
                  originalLogSHA256=hashlib.sha256(log).hexdigest())
    return [cohort, protocol, manifest, documents, artifacts, status, log, SOURCE, ENGINE]


class PrimaryProductVerificationTests(unittest.TestCase):
    def test_complete_recorded_shape_grants_no_capture_or_completion_authority(self):
        result = v.verify_products(*products())
        self.assertTrue(result['originalNativeProductsConsistent'])
        for key in ['freshCaptureConstructed', 'sealedCandidateProductsDecoded', 'nativePredicatesReexecuted',
                    'currentSourceApplicabilityVerified', 'installedArtifactsVerified',
                    'longHorizonQualified', 'completeResourceQualification', 'fullPlatformQualified',
                    'runtimeQualification', 'item39Complete']:
            self.assertIs(result[key], False)

    def test_successor_order_uses_full_tuple_multiplicity(self):
        data, row, entry = trajectory()
        data['actualSuccessorReceipts'].reverse()
        v.verify_trajectory(data, row, 'development', entry, ENGINE)
        data['actualSuccessorReceipts'][0] = copy.deepcopy(data['actualSuccessorReceipts'][1])
        with self.assertRaises(v.VerificationError):
            v.verify_trajectory(data, row, 'development', entry, ENGINE)

    def test_missing_or_inconsistent_native_trajectory_is_refused(self):
        mutations = {
            'rate': lambda d: d['actualReportBank']['reports'][0].update(sampleRate=48000),
            'checkpoint': lambda d: d['actualReportBank']['reports'][0].update(checkpoint='contrast'),
            'report': lambda d: d['actualReportBank']['reports'].pop(),
            'successor': lambda d: d['actualSuccessorReceipts'].pop(),
            'gate-false': lambda d: d['actualReportBank']['reports'][0]['selectedCandidateEvidence']['hardGates'].update(audioSafetyValid=False),
            'gate-missing': lambda d: d['actualReportBank']['reports'][0]['selectedCandidateEvidence']['hardGates'].pop('audioSafetyValid'),
            'render-bound': lambda d: d['actualReportBank']['reports'][0].update(correctionRenderCount=2),
            'attempts': lambda d: d['actualReportBank']['reports'][0]['candidateEvaluation'].update(sourceAttemptCount=2),
            'selected': lambda d: d['actualReportBank']['reports'][0]['candidateEvaluation'].update(selectedAttemptIndex=1),
            'bounds': lambda d: d['actualReportBank']['reports'][0]['candidateEvaluation'].update(boundsValid=False),
            'tuple': lambda d: d['actualSuccessorReceipts'][0].update(sourceOutgoingRenderDSPFingerprint='changed'),
            'incoming': lambda d: d['actualSuccessorReceipts'][0].update(successorIncomingRenderDSPFingerprint='changed'),
            'next-rate': lambda d: d['actualSuccessorReceipts'][0]['firstBar'].update(sampleRate=8000),
            'pcm': lambda d: d['actualReportBank']['reports'][0]['commitProvenance'].update(selectedSampleHash='changed'),
            'observation': lambda d: d['continuousTrajectory']['observations'][0].update(checkpoint='contrast'),
            'projection': lambda d: d['continuousTrajectory']['observations'][0]['continuousModalSource']['projection'].update(sourceReportFingerprint='changed'),
            'identity': lambda d: d['continuousTrajectory']['observations'][0]['continuousModalSource'].update(sourceIdentityFingerprint='changed'),
            'projected-gates': lambda d: d['continuousTrajectory']['observations'][0].update(hardGatesPassed=False),
            'metric': lambda d: d['continuousTrajectory']['observations'][0]['metrics'][0].update(metric='b'),
            'infinity': lambda d: d['continuousTrajectory']['observations'][0]['metrics'][0].update(value=float('inf')),
            'unavailable': lambda d: d.update(requiredUnavailableObservationCount=1),
            'plan': lambda d: d['frozenPlanningEntry'].update(rootSeed=0),
            'reach': lambda d: d['renderedPhraseCounts'].update({'44100': 1}),
            'engine': lambda d: d['actualReportBank'].update(engineVersion='old'),
            'bank': lambda d: d['continuousTrajectory'].update(sourceBankFingerprint='old'),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                data, row, entry = trajectory(); mutate(data)
                with self.assertRaises(v.VerificationError):
                    v.verify_trajectory(data, row, 'development', entry, ENGINE)

    def test_complete_matrix_and_terminal_receipt_cannot_be_replaced_by_flags(self):
        mutations = {
            'prefix': lambda x: x[2]['completedTrajectories'].pop(),
            'cohort-overlap': lambda x: x[0]['holdout'][0].update(rootSeed=100),
            'same-ordinal': lambda x: x[0]['holdout'][0].update(ordinal=0),
            'import': lambda x: x[1].update(archiveImport=True),
            'budget': lambda x: x[1].update(maximumPeakWorkingBytes=268435456),
            'third-render': lambda x: x[1].update(maximumRenderPasses=3),
            'false-exit': lambda x: x[5].update(exitCode=False),
            'failed-exit': lambda x: x[5].update(exitCode=1),
            'log-digest': lambda x: x[5].update(originalLogSHA256='0' * 64),
            'corpus': lambda x: x[4]['holdout']['trajectories'].pop(),
            'suite': lambda x: x[4]['adversarial']['cases'].pop(),
            'suite-reason': lambda x: x[4]['adversarial']['cases'][0].update(actualReasons=[]),
            'duplicate-holdout': lambda x: x[4]['holdoutVerdicts']['trajectories'][0].update(sourceBankFingerprint='bank-41'),
            'missing-rate': lambda x: x[4]['holdoutVerdicts']['trajectories'][0]['verdicts'][0].update(sampleRate=48000),
            'failed-holdout': lambda x: x[4]['holdoutVerdicts']['trajectories'][0]['verdicts'][0].update(accepted=False),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                args = products(); mutate(args)
                with self.assertRaises((v.VerificationError, KeyError)):
                    v.verify_products(*args)

    def test_strict_json_rejects_duplicate_nonfinite_and_generic_passed_data(self):
        for raw in [b'{"x":1,"x":2}', b'{"x":NaN}', b'{"x":1e400}', b'[]']:
            with self.subTest(raw=raw):
                if raw == b'[]':
                    with tempfile.TemporaryDirectory() as temp:
                        path = Path(temp) / 'record.json'; path.write_bytes(raw)
                        with self.assertRaises(v.VerificationError): v.load(path)
                else:
                    with self.assertRaises(v.VerificationError): v.strict(raw)
        with self.assertRaises(KeyError):
            v.verify_products(*([{'passed': True}] * 6), b'passed', SOURCE, ENGINE)

    def test_paths_and_pinned_origin_refuse_substitution(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root / 'real').mkdir(); (root / 'real' / 'proof').write_bytes(b'{}')
            (root / 'alias').symlink_to(root / 'real', target_is_directory=True)
            for relative in ['../proof', '/proof', 'alias/proof', 'real\\proof']:
                with self.subTest(relative=relative), self.assertRaises(v.VerificationError):
                    v.inside(root, relative)
            context = v.Context(root, root, root, root, 'real/proof', '0' * 64, SOURCE, 'terminal.json', '0' * 64)
            with self.assertRaisesRegex(v.VerificationError, 'cold proof SHA256'):
                context.inputs()


if __name__ == '__main__':
    unittest.main()
