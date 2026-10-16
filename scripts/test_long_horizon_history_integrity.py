"""Synthetic integrity controls, never evidence of native capture or quality."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import long_horizon_history_integrity as history


def metrics(count):
    return [dict(metric=name, observationCount=count, minimum=-1.0,
                 mean=0.0, maximum=1.0) for name in history.METRICS]


def fixture(rate=44100, *, effect_schema_version=2):
    phrases, bars, seed = 780, 7800, 1
    signal = dict(schemaVersion=3,
        schemaIdentifier='autotechno-long-horizon-signal-trajectory-report.v3',
        rootSeed=seed, sampleRate=rate, observationCount=phrases, renderedBarCount=bars,
        omittedBarCount=0, omittedPhraseCount=0, metrics=metrics(phrases),
        operatorCounts=[dict(operatorKind=name, observationCount=130) for name in history.OPERATORS],
        operatorTransitions=[dict(operatorKind=name, transitionCount=129 if i == 0 else 130,
            metricDeltas=metrics(129 if i == 0 else 130)) for i, name in enumerate(history.OPERATORS)],
        recentPhrases=[dict(schemaVersion=2,
            schemaIdentifier='autotechno-long-horizon-signal-trajectory.v2',
            rootSeed=seed, sampleRate=rate, phraseIndex=i, startBar=i*10,
            barCount=10, hardGatesPassed=True) for i in range(phrases-32, phrases)],
        recentTransitions=[], recentEpisodes=[])
    semantic = dict(schemaVersion=1, schemaIdentifier='autotechno-long-horizon-semantic.v1',
        rootSeed=seed, engineVersion='fixture-engine', observedPhraseCount=phrases, observedBarCount=bars,
        startingBar=0, startingPhraseIndex=0, nextExpectedBar=bars, nextExpectedPhraseIndex=phrases)
    effects = dict(schemaVersion=effect_schema_version,
        schemaIdentifier=f'autotechno-long-horizon-effect-dose.v{effect_schema_version}',
        rootSeed=seed, phraseCount=phrases, barCount=bars)
    for row in (signal, semantic, effects):
        row.update(availability='available', qualificationStatus='unavailable',
                   qualificationReason='no-calibrated-long-horizon-policy')
    frames = bars * round(240/130*rate)
    document = dict(schema='autotechno-long-horizon-shared-journey.v2',
        inputBindingFingerprint='binding', primaryPolicyVersion='policy',
        sourceScope='current-shared-preparation-primary-only-bootstrap-with-core-recovery',
        memoryScope='numeric-reservation-covers-preparation-chain-not-combined-held-playback',
        presentationScope='offline-selected-retained-pcm-no-device-scheduling-proof',
        journey=dict(rootSeed=seed, sampleRate=rate, completedRequestedScope=True,
            endsAtClosedLeaf=True, requestedMinimumBars=7800, failureDetails=[],
            consumedPhraseCount=phrases, signal=signal, semantic=semantic, effects=effects,
            acceptedFrameCount=frames, accountedRepeats=[], endSample=frames,
            rejectedPreparations=[], newPreparationAttemptCount=phrases,
            ownedChildConsumptionCount=0, reservedNumericPeakBytes=100000000))
    document.update({key: False for key in history.FALSE_CLAIMS})
    return document


class HistoryIntegrityTests(unittest.TestCase):
    @staticmethod
    def recovery_fixture(rate=44100):
        document = fixture(rate, effect_schema_version=3)
        document['schema'] = 'autotechno-long-horizon-shared-journey.v3'
        j = document['journey']
        j['rejectedPreparations'] = [dict(targetPhraseIndex=12,
            requestFingerprint='a'*16, incomingCoreFingerprint='b'*16,
            candidateFingerprint='c'*16, reasonCodes=['quality.guardrail-regression.v1'],
            ordinal=0, wave=0, overdueDebtCount=0,
            rejectedSuccessorPhraseIndex=13, rejectedSuccessorRequestFingerprint='d'*16,
            acceptedTraversalFingerprintBeforeRejection='e'*16,
            rejectedSuccessorDetails=['phrase=13', 'long-continuation:reason=metric-out-of-range'])]
        j['newPreparationAttemptCount'] += 1
        return document

    @staticmethod
    def verify_recovery(document, **kwargs):
        return history.verify_history(document, 'binding', list(range(1,10)), 'policy',
            'fixture-engine', effect_schema_version=3, journey_schema_version=3, **kwargs)

    def test_recovery_format_requires_explicit_bound_version_and_preserves_native_rates(self):
        for rate in (44100, 48000):
            document = self.recovery_fixture(rate)
            row = self.verify_recovery(document)
            self.assertEqual((row['sampleRate'], row['acceptedBars'], row['discardedChainRejections']),
                             (rate, 7800, 1))
            with self.assertRaisesRegex(history.HistoryIntegrityError, 'unsupported journey schema'):
                history.verify_history(document, 'binding', [1], 'policy', 'fixture-engine',
                                       effect_schema_version=3)
        for version in [True, 3.0, '3', None, 4]:
            with self.subTest(version=version), self.assertRaises(history.HistoryIntegrityError):
                history.verify_history(self.recovery_fixture(), 'binding', [1], 'policy',
                    'fixture-engine', effect_schema_version=3, journey_schema_version=version)
        with self.assertRaisesRegex(history.HistoryIntegrityError, 'journey/effect pair'):
            history.verify_history(self.recovery_fixture(), 'binding', [1], 'policy',
                'fixture-engine', journey_schema_version=3)

    def test_discarded_child_receipt_corruption_cannot_supply_a_root_recovery_history(self):
        attacks = [
            lambda r:r.update(targetPhraseIndex=780),
            lambda r:r.update(rejectedSuccessorPhraseIndex=12),
            lambda r:r.update(rejectedSuccessorPhraseIndex=True),
            lambda r:r.update(rejectedSuccessorRequestFingerprint=r['requestFingerprint']),
            lambda r:r.update(rejectedSuccessorRequestFingerprint=None),
            lambda r:r.update(acceptedTraversalFingerprintBeforeRejection='E'*16),
            lambda r:r.update(rejectedSuccessorDetails=None),
            lambda r:r.update(rejectedSuccessorDetails=['phrase=14']),
            lambda r:r.update(rejectedSuccessorDetails=['phrase=13']*2),
            lambda r:r.update(rejectedSuccessorDetails=['phrase=13']+[str(i) for i in range(24)]),
            lambda r:r.update(reasonCodes=['quality.evidence-missing.v1']),
            lambda r:r.update(reasonCodes=['quality.hard-gate-failed.v1']),
            lambda r:r.update(ordinal=10),
            lambda r:r.update(wave=True),
            lambda r:r.update(overdueDebtCount=-1),
            lambda r:r.update(candidateFingerprint='not-a-fingerprint'),
        ]
        for attack in attacks:
            document = self.recovery_fixture();attack(document['journey']['rejectedPreparations'][0])
            with self.subTest(attack=attacks.index(attack)), self.assertRaises(history.HistoryIntegrityError):
                self.verify_recovery(document)

    def test_recovery_receipts_cannot_relabel_a_prefix_or_enter_original_format_authority(self):
        for key,value in [('completedRequestedScope',False),('endsAtClosedLeaf',False),
                          ('requestedMinimumBars',0),('requestedPrefixPhraseCount',405),
                          ('failureCode','successor-chain:successor-rejected')]:
            document=self.recovery_fixture();document['journey'][key]=value
            with self.subTest(key=key), self.assertRaises(history.HistoryIntegrityError):
                self.verify_recovery(document)
        document=self.recovery_fixture();document['schema']='autotechno-long-horizon-shared-journey.v2'
        with self.assertRaisesRegex(history.HistoryIntegrityError,'unbound successor rejection metadata'):
            history.verify_history(document,'binding',[1],'policy','fixture-engine',effect_schema_version=3)

    def test_recovery_history_keeps_ordinary_rejections_and_every_actual_occurrence(self):
        document=self.recovery_fixture();j=document['journey']
        duplicate=copy.deepcopy(j['rejectedPreparations'][0]);j['rejectedPreparations'].append(duplicate)
        ordinary=copy.deepcopy(duplicate)
        for key in ['rejectedSuccessorPhraseIndex','rejectedSuccessorRequestFingerprint',
                    'acceptedTraversalFingerprintBeforeRejection','rejectedSuccessorDetails']:
            ordinary.pop(key)
        ordinary.update(targetPhraseIndex=13,reasonCodes=['quality.hard-gate-failed.v1','quality.symbolic-interest-failed.v1'])
        j['rejectedPreparations'].append(ordinary);j['newPreparationAttemptCount']+=2
        row=self.verify_recovery(document)
        self.assertEqual((row['rejectedPreparations'],row['discardedChainRejections']), (3,2))
        j['rejectedPreparations'][-1]['targetPhraseIndex']=11
        with self.assertRaisesRegex(history.HistoryIntegrityError,'rejection target order'):
            self.verify_recovery(document)
        oversized=self.recovery_fixture()
        oversized['journey']['rejectedPreparations']=[None]*10416
        with self.assertRaisesRegex(history.HistoryIntegrityError,'bounded accepted/recovery step scope'):
            self.verify_recovery(oversized)

    def test_effect_interpretation_requires_the_explicit_bound_pair(self):
        document = fixture(effect_schema_version=3)
        row = history.verify_history(document, 'binding', list(range(1,10)), 'policy',
            'fixture-engine', effect_schema_version=3)
        self.assertEqual(row['acceptedBars'], 7800)
        with self.assertRaises(history.HistoryIntegrityError):
            self.verify(document)
        for version in [True, 3.0, '3', None, 4]:
            with self.subTest(version=version), self.assertRaises(history.HistoryIntegrityError):
                history.verify_history(document, 'binding', list(range(1,10)), 'policy',
                    'fixture-engine', effect_schema_version=version)

    def verify(self, document):
        return history.verify_history(document, 'binding', list(range(1, 10)), 'policy', 'fixture-engine')

    def test_both_native_rates_pass_bounded_integrity_without_authority(self):
        for rate in (44100, 48000):
            row = self.verify(fixture(rate))
            self.assertEqual((row['sampleRate'], row['acceptedBars']), (rate, 7800))

    def test_closed_leaf_overshoot_has_no_score_only_bar_capacity_limit(self):
        document = fixture()
        j = document['journey']
        bars = 9000
        j['signal']['renderedBarCount'] = bars
        j['semantic'].update(observedBarCount=bars, nextExpectedBar=bars)
        j['effects']['barCount'] = bars
        for i, row in enumerate(j['signal']['recentPhrases']):
            row['startBar'] = bars - 320 + i*10
        j['acceptedFrameCount'] = j['endSample'] = bars * round(240/130*44100)
        self.assertEqual(self.verify(document)['acceptedBars'], bars)

    def test_same_length_duplicate_operator_or_metric_is_not_complete_coverage(self):
        for key in ('operatorCounts', 'operatorTransitions', 'metrics', 'metricDeltas'):
            document = fixture()
            signal = document['journey']['signal']
            rows = signal['operatorTransitions'][0][key] if key == 'metricDeltas' else signal[key]
            rows[-1] = copy.deepcopy(rows[0])
            with self.subTest(key=key), self.assertRaisesRegex(history.HistoryIntegrityError, 'exactly once'):
                self.verify(document)

    def test_incomplete_prefix_failure_and_open_leaf_refuse(self):
        for key, value in [('completedRequestedScope', False), ('endsAtClosedLeaf', False),
                           ('requestedMinimumBars', 7799), ('requestedPrefixPhraseCount', 0),
                           ('failureCode', 'refused'), ('failureDetails', ['failed'])]:
            document = fixture()
            document['journey'][key] = value
            with self.subTest(key=key), self.assertRaises(history.HistoryIntegrityError):
                self.verify(document)

    def test_wrong_root_route_binding_policy_or_qualification_refuses(self):
        changes = [lambda d:d.update(inputBindingFingerprint='other'),
                   lambda d:d.update(primaryPolicyVersion='other'),
                   lambda d:d.update(sourceScope='legacy'),
                   lambda d:d['journey']['semantic'].update(engineVersion='other'),
                   lambda d:d['journey'].update(rootSeed=10),
                   lambda d:d['journey'].update(sampleRate=8000)]
        changes += [lambda d, k=k:d.update({k: True}) for k in history.FALSE_CLAIMS]
        for mutate in changes:
            document = fixture()
            mutate(document)
            with self.assertRaises(history.HistoryIntegrityError):
                self.verify(document)

    def test_neutral_fallback_is_not_manufactured_as_operator_support(self):
        document = fixture()
        document['journey']['signal']['operatorCounts'][0]['observationCount'] -= 1
        row = self.verify(document)
        self.assertEqual(row['neutralOperatorObservationCount'], 1)

    def test_metric_support_and_bounds_refuse_false_measurements(self):
        changes = [lambda s:s['metrics'][0].update(observationCount=1),
                   lambda s:s['metrics'][0].update(mean=2),
                   lambda s:s['operatorTransitions'][0]['metricDeltas'][0].update(observationCount=130),
                   lambda s:s['operatorTransitions'][0].update(transitionCount=1),
                   lambda s:s['operatorCounts'][0].update(observationCount=1000)]
        for mutate in changes:
            document = fixture()
            mutate(document['journey']['signal'])
            with self.assertRaises(history.HistoryIntegrityError):
                self.verify(document)

    def test_optional_measurements_preserve_actual_support_without_zero_fill(self):
        document = fixture()
        signal = document['journey']['signal']
        signal['metrics'][0]['observationCount'] -= 3
        signal['operatorTransitions'][0]['metricDeltas'][0]['observationCount'] -= 2
        row = self.verify(document)
        self.assertEqual(row['conditionallyUnavailableSignalObservations'], {history.METRICS[0]: 3})
        self.assertEqual(row['conditionallyUnavailableTransitionObservations'],
                         {'maintain': {history.METRICS[0]: 2}})

    def test_tiny_or_zero_metrics_cannot_hide_an_impossible_mean(self):
        for observed, impossible in ((1e-100, 1e-80), (0.0, 5e-324)):
            document = fixture()
            index = history.METRICS.index('positive-spectral-flux-mean')
            document['journey']['signal']['metrics'][index].update(
                minimum=observed, maximum=observed, mean=impossible)
            with self.subTest(observed=observed), self.assertRaisesRegex(
                    history.HistoryIntegrityError, 'inconsistent metric bounds'):
                self.verify(document)

    def test_native_sum_then_divide_roundoff_remains_representable(self):
        document = fixture()
        row = document['journey']['signal']['metrics'][0]
        total = 0.0
        for _ in range(row['observationCount']):
            total += 1e-100
        row.update(minimum=1e-100, maximum=1e-100, mean=total/row['observationCount'])
        self.verify(document)

    def test_bad_recent_hard_gate_route_or_adjacency_refuses(self):
        for key, value in [('hardGatesPassed', False), ('rootSeed', 2),
                           ('sampleRate', 48000), ('phraseIndex', 0), ('startBar', 0),
                           ('barCount', 17)]:
            document = fixture()
            document['journey']['signal']['recentPhrases'][1][key] = value
            with self.subTest(key=key), self.assertRaises(history.HistoryIntegrityError):
                self.verify(document)

    def test_sample_repeat_attempt_and_ceiling_controls(self):
        document = fixture()
        j = document['journey']
        frames = round(240 / 130 * j['sampleRate'])
        j['accountedRepeats'] = [dict(startSample=frames, endSample=2*frames,
                                    frameCount=frames, barCount=1)]
        j['endSample'] += frames
        self.assertEqual(self.verify(document)['accountedRepeats'], 1)
        mutations = [lambda j:j['accountedRepeats'][0].update(frameCount=99),
                     lambda j:j['accountedRepeats'].append(dict(startSample=frames,
                         endSample=2*frames, frameCount=frames, barCount=1)),
                     lambda j:j.update(endSample=j['endSample']+1),
                     lambda j:j.update(acceptedFrameCount=j['acceptedFrameCount']+1),
                     lambda j:j.update(newPreparationAttemptCount=1),
                     lambda j:j.update(reservedNumericPeakBytes=history.MAX_NUMERIC_BYTES+1)]
        for mutate in mutations:
            changed = copy.deepcopy(document)
            mutate(changed['journey'])
            with self.assertRaises(history.HistoryIntegrityError):
                self.verify(changed)

    def test_boolean_numeric_counters_refuse(self):
        for key in ('omittedBarCount', 'omittedPhraseCount', 'schemaVersion'):
            document = fixture()
            document['journey']['signal'][key] = False
            with self.assertRaises(history.HistoryIntegrityError):
                self.verify(document)

    def test_repeat_bar_geometry_cannot_be_hidden_by_consistent_frame_totals(self):
        for rate in (44100, 48000):
            document = fixture(rate)
            j = document['journey']
            frames_per_bar = round(240 / 130 * rate)
            repeat = dict(startSample=10 * frames_per_bar, endSample=13 * frames_per_bar,
                          frameCount=3 * frames_per_bar, barCount=3)
            j['accountedRepeats'] = [repeat]
            j['endSample'] += repeat['frameCount']
            self.assertEqual(self.verify(document)['accountedRepeats'], 1)
            for fault in ('bar-count', 'fractional-bar', 'unaligned-boundary', 'oversized-phrase'):
                changed = copy.deepcopy(document)
                journey = changed['journey']
                row = journey['accountedRepeats'][0]
                if fault == 'bar-count':
                    row['barCount'] += 1
                elif fault == 'fractional-bar':
                    row['frameCount'] += 1
                    row['endSample'] += 1
                    journey['endSample'] += 1
                elif fault == 'unaligned-boundary':
                    row['startSample'] += 1
                    row['endSample'] += 1
                else:
                    row['barCount'] = 17
                    row['frameCount'] = 17 * frames_per_bar
                    row['endSample'] = row['startSample'] + row['frameCount']
                    journey['endSample'] += 14 * frames_per_bar
                with self.subTest(rate=rate, fault=fault), self.assertRaisesRegex(
                        history.HistoryIntegrityError, 'repeat native bar geometry'):
                    self.verify(changed)

    def test_json_duplicate_nonfinite_and_symlink_refuse(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'data.json'
            for raw in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}', '{"x":1e999}',
                        '{"x":1' + '0'*400 + '}'):
                path.write_text(raw)
                with self.assertRaises(history.HistoryIntegrityError):
                    history.load(path)
            alias = path.with_name('alias.json')
            alias.symlink_to(path)
            with self.assertRaises(history.HistoryIntegrityError):
                history.load(alias)
            with mock.patch.object(history, 'MAX_JSON_BYTES', 8), \
                    self.assertRaisesRegex(history.HistoryIntegrityError, 'bounded JSON'):
                history.load(path)

    def origin(self, base):
        root, runner, resources = (base/name for name in ('origin', 'runner', 'bundle'))
        for directory in (root, runner, resources):
            directory.mkdir()
        inputs = {
            'Package.swift': '// fixture', 'Tests/Fixture.swift': '// fixture',
            'scripts/fixture.py': '# fixture', 'docs/BASELINE_CORPUS.json': '{}',
            'docs/ROADMAP_EXECUTION_BASELINE.json': '{}',
            'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift':
                'static let policyFamilyVersion = "fixture-policy"',
            'Sources/AutoTechnoCore/QualityQualification.swift':
                'static let engineVersion = "fixture-engine"',
            'Tests/AutoTechnoCoreTests/LongHorizonPolicyCalibrationIntegrationTests.swift':
                'private let developmentRoots: [UInt64] = [1,2,3,4,5,6,7]\n'
                'private let holdoutRoots: [UInt64] = [8,9]',
            'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift': '\n'.join(
                f'static let expected{name}Fingerprint: String? = "{i:016x}"'
                for i, name in enumerate(('Profile', 'AdversarialSuite', 'HoldoutQualification'), 1)),
            'Sources/AutoTechnoDSP/Resources/fixture.json': '{}'}
        for name, text in inputs.items():
            path = root/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        subprocess.run(['git', 'init', '--quiet'], cwd=root, check=True)
        subprocess.run(['git', 'add', '.'], cwd=root, check=True)
        subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                        'commit', '--quiet', '-m', 'fixture'], cwd=root, check=True)
        source = history.git(root, 'rev-parse', 'HEAD')
        (runner/'runner').write_bytes(b'synthetic object; no native execution authority')
        obj = runner/'fixture.o'
        obj.write_bytes(b'object fixture')
        (resources/'fixture.json').write_text('{}')
        groups = dict(sources={p:history.sha(root/p) for p in inputs if p.endswith('.swift') and p.startswith('Sources/')},
            testFiles={p:history.sha(root/p) for p in inputs if p.endswith('.swift') and p.startswith('Tests/')},
            objects={str(obj):history.sha(obj)}, resources={'fixture.json':history.sha(resources/'fixture.json')})
        image = history.sha(runner/'runner')
        (runner/'build-metadata.json').write_text(json.dumps(dict(source=source, inputs=groups, executableSHA256=image)))
        (runner/'launch.json').write_text(json.dumps(dict(source=source, archiveImport=False,
            runtimeActivation=False, runnerSHA256=image, developmentRoots=list(range(1, 8)),
            holdoutRoots=[8, 9], sampleRates=[44100, 48000])))
        return root, runner, resources, source

    def test_origin_audit_is_repeatable_and_retains_no_qualification_authority(self):
        with tempfile.TemporaryDirectory() as directory:
            root, runner, resources, source = self.origin(Path(directory))
            context = history.verify_origin(root, runner, resources, source)
            self.assertEqual(context, history.verify_origin(root, runner, resources, source))
            document = fixture()
            document.update(inputBindingFingerprint=context['inputBindingFingerprint'],
                            primaryPolicyVersion=context['primaryPolicyVersion'])
            path = root/'docs/local/report.json'
            # Ignored producer outputs do not modify the original source freeze.
            (root/'.git/info/exclude').write_text('docs/local/\n')
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(document))
            result = history.audit(root, runner, resources, source, [path])
            self.assertEqual(result['verifiedHistories'], 1)
            self.assertEqual(result['requiredHistories'], 18)
            for key in ('nativeExecutionProven', 'longHorizonQualification', 'runtimeQualification', 'item39Complete'):
                self.assertIs(result[key], False)
            with self.assertRaisesRegex(history.HistoryIntegrityError, 'duplicate completed route'):
                history.audit(root, runner, resources, source, [path, path])

    def test_changed_source_object_resource_image_or_cohort_refuses(self):
        for mutation in ('source', 'object', 'resource', 'image', 'cohort',
                         'producer-cohort', 'unbound-engine'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root, runner, resources, source = self.origin(Path(directory))
                if mutation == 'source':
                    (root/'scripts/fixture.py').write_text('# changed')
                elif mutation in ('cohort', 'producer-cohort'):
                    path = runner/'launch.json'
                    value = json.loads(path.read_text())
                    if mutation == 'cohort':
                        value['holdoutRoots'] = [7, 8]
                    else:
                        value['developmentRoots'].reverse()
                    path.write_text(json.dumps(value))
                elif mutation == 'unbound-engine':
                    path = runner/'build-metadata.json'
                    value = json.loads(path.read_text())
                    del value['inputs']['sources']['Sources/AutoTechnoCore/QualityQualification.swift']
                    path.write_text(json.dumps(value))
                else:
                    path = {'object':runner/'fixture.o', 'resource':resources/'fixture.json',
                            'image':runner/'runner'}[mutation]
                    path.write_bytes(b'changed')
                with self.assertRaises(history.HistoryIntegrityError):
                    history.verify_origin(root, runner, resources, source)

    def test_changed_artifact_during_read_refuses(self):
        with tempfile.TemporaryDirectory() as directory:
            root, runner, resources, source = self.origin(Path(directory))
            context = history.verify_origin(root, runner, resources, source)
            document = fixture()
            document.update(inputBindingFingerprint=context['inputBindingFingerprint'],
                            primaryPolicyVersion=context['primaryPolicyVersion'])
            path = root/'docs/local/report.json'
            (root/'.git/info/exclude').write_text('docs/local/\n')
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(document))
            original_load = history.load
            def change_after_read(candidate):
                value = original_load(candidate)
                if candidate == path:
                    candidate.write_text('{}')
                return value
            with mock.patch.object(history, 'load', side_effect=change_after_read), \
                    self.assertRaisesRegex(history.HistoryIntegrityError, 'report changed'):
                history.audit(root, runner, resources, source, [path])

    def test_earlier_artifact_changed_during_later_read_refuses(self):
        with tempfile.TemporaryDirectory() as directory:
            root, runner, resources, source = self.origin(Path(directory))
            context = history.verify_origin(root, runner, resources, source)
            (root/'.git/info/exclude').write_text('docs/local/\n')
            paths = []
            for rate in (44100, 48000):
                document = fixture(rate)
                document.update(inputBindingFingerprint=context['inputBindingFingerprint'],
                                primaryPolicyVersion=context['primaryPolicyVersion'])
                path = root/f'docs/local/report-{rate}.json'
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(document))
                paths.append(path)
            original_load = history.load
            def change_earlier(candidate):
                value = original_load(candidate)
                if candidate == paths[1]:
                    paths[0].write_text('{}')
                return value
            with mock.patch.object(history, 'load', side_effect=change_earlier), \
                    self.assertRaisesRegex(history.HistoryIntegrityError, 'batch completion'):
                history.audit(root, runner, resources, source, paths)

    def test_metric_names_match_the_existing_canonical_swift_contract(self):
        root = Path(__file__).resolve().parents[1]
        text = (root/'Sources/AutoTechnoDSP/LongHorizonSignalTrajectory.swift').read_text()
        block = text.split('package enum LongHorizonSignalMetric:', 1)[1].split('\n}', 1)[0]
        import re
        self.assertEqual(tuple(re.findall(r'case \w+ = "([^"]+)"', block)), history.METRICS)

    def test_loaded_verifier_must_match_its_current_source(self):
        with mock.patch.object(history, '_IMPLEMENTATION_SHA_AT_IMPORT', '0'*64), \
                self.assertRaisesRegex(history.HistoryIntegrityError, 'implementation changed'):
            history.audit(Path('/missing'), Path('/missing'), Path('/missing'), 'a'*40, [])


if __name__ == '__main__':
    unittest.main()
