"""Synthetic controls only; never native capture or quality evidence."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

import test_long_horizon_history_integrity as fixtures
from at0039_primary_verification import VerificationError

import at0039_long_verification as v
SOURCE = 'a' * 40
ENGINE = 'fixture-engine'
fp = lambda text: hashlib.sha256(text.encode()).hexdigest()[:16]


def products():
    development, holdout = list(range(1, 8)), [8, 9]
    protocol = dict(source=SOURCE, developmentRoots=development, holdoutRoots=holdout,
        nativeRates=[44100, 48000], allHistoriesFromInitialState=True,
        eachNativeHistoryMustIndependentlyPassEveryGate=True, noCrossRateHistoryEqualityRequired=True,
        numericCeilingBytes=134217728, maximumRenderPasses=2,
        minimumActualAcceptedBarsPerHistory=7800, requiredCompleteHistories=18,
        archiveImport=False, partialStateImport=False, historicalHistoriesRetagged=False,
        runtimeActivation=False, item39Complete=False)
    cold = dict(source=SOURCE, developmentRoots=development, holdoutRoots=holdout,
        sampleRates=[44100, 48000], primaryPolicyVersion='policy', engineVersion=ENGINE)
    documents, observations = {}, {}
    for seed in development + holdout:
        routes = []
        for rate in v.RATES:
            document = fixtures.fixture(rate); j = document['journey']; j['rootSeed'] = seed
            bars = 7800 if rate == 44100 else 9000
            for family in ['signal', 'semantic', 'effects']: j[family]['rootSeed'] = seed
            signal, semantic, effects = [j[k] for k in ['signal', 'semantic', 'effects']]
            signal['renderedBarCount'] = bars
            for i, row in enumerate(signal['recentPhrases']):
                row.update(rootSeed=seed, startBar=bars-320+i*10)
            semantic.update(observedBarCount=bars, nextExpectedBar=bars,
                trajectoryFingerprint=fp(f'semantic-{seed}-{rate}'),
                tensionDwell=dict(maximumHighDwellBars=0, recoveryBarCount=0),
                eventSignatureRecurrence=dict(observationCount=0, repeatObservationCount=0),
                identityRecall=dict(identityReturnBarCount=0, matchedHomeSignatureBarCount=0),
                dramaticDebt=dict(paidCount=0, zeroAgePaidCount=0, overduePaidCount=0,
                    overdueOutstandingCount=0, oldestOutstandingAgeBars=0), capabilityRecurrence=[])
            signal['trajectoryFingerprint'] = fp(f'signal-{seed}-{rate}')
            effects.update(barCount=bars, materialWorldCount=1,
                meanEffectWorldDistance=0, maximumEffectWorldDistance=0,
                families=[dict(family=name, eligibleBarCount=bars, activeBarCount=0,
                    tailOnlyBarCount=0, recoveryCount=0, maximumActiveRunBars=0,
                    wetBarOccupancy=0) for name in ['generated-graph','pulse-echo',
                    'percussion-echo-texture','spatial-fdn']])
            j['acceptedFrameCount'] = j['endSample'] = bars * round(240/130*rate)
            documents[seed, rate] = document
            routes.append(dict(schemaVersion='autotechno-long-horizon-runtime-observation.v5',
                engineVersion=ENGINE, primaryPolicyVersion='policy', rootSeed=seed,
                sampleRate=rate, sourceFingerprint=fp(f'route-{seed}-{rate}'),
                semanticFingerprint=semantic['trajectoryFingerprint'],
                signalFingerprint=signal['trajectoryFingerprint'],
                observedPhraseCount=780, observedBarCount=bars,
                signalObservationCount=780, signalOmittedPhraseCount=0,
                semanticValues=v.projected_semantics(semantic), effects=v.projected_effects(effects),
                operatorDeltas=[dict(sampleRate=rate, operatorKind=t['operatorKind'],
                    metric=m['metric'], transitionCount=m['observationCount'], meanDelta=m['mean'])
                    for t in signal['operatorTransitions'] for m in t['metricDeltas']]))
        observations[seed] = dict(schemaVersion=v.OBSERVATION, engineVersion=ENGINE,
            primaryPolicyVersion='policy', rootSeed=seed, routes=routes, sourceFingerprint=fp(f'root-{seed}'))
    artifacts = {partition: dict(schemaVersion=v.CORPUS, engineVersion=ENGINE,
        primaryPolicyVersion='policy', fingerprint=fp(partition), observations=[observations[s] for s in seeds])
        for partition,seeds in [('development',development),('holdout',holdout)]}
    profile = dict(profileVersion=v.PROFILE, engineVersion=ENGINE, primaryPolicyVersion='policy',
        sampleRates=list(v.RATES), fingerprint=fp('profile'), developmentJourneyCount=7,
        developmentRootSeeds=development, developmentCorpusFingerprint=fp('development'))
    attacks = ['attack-'+str(i) for i in range(10)]
    suite = dict(schemaVersion=v.ADVERSARIAL, engineVersion=ENGINE,
        profileFingerprint=fp('profile'), sourceObservationFingerprint=observations[1]['sourceFingerprint'],
        fingerprint=fp('adversarial'), passed=True,
        cases=[dict(sampleRate=rate, attack=attack, rejected=True, failedDimensions=['dimension'])
            for rate in v.RATES for attack in attacks])
    accepted = lambda: dict(accepted=True, failedDimensions=[], failedSemanticMetrics=[],
        failedOperatorDeltas=[], failedEffectFamilies=[])
    held = dict(schemaVersion=v.HOLDOUT, engineVersion=ENGINE, qualified=True,
        profileFingerprint=fp('profile'), adversarialFingerprint=fp('adversarial'),
        developmentCorpusFingerprint=fp('development'), holdoutCorpusFingerprint=fp('holdout'),
        fingerprint=fp('held'), journeys=[])
    for seed in holdout:
        verdict = accepted()
        verdict['routeVerdicts'] = [dict(sampleRate=route['sampleRate'],
            sourceFingerprint=route['sourceFingerprint'], verdict=accepted()) for route in observations[seed]['routes']]
        held['journeys'].append(dict(rootSeed=seed, sourceFingerprint=observations[seed]['sourceFingerprint'], verdict=verdict))
    artifacts.update(profile=profile, adversarial=suite, holdoutVerdicts=held)
    log = ''.join(f'AUTOTECHNO_LONG_HORIZON_CALIBRATION {partition}-native root={seed} rate={r["sampleRate"]} accepted=true source={r["sourceFingerprint"]}\n'
        for partition,seeds in [('development',development),('holdout',holdout)] for seed in seeds for r in observations[seed]['routes'])
    log += '\n'.join(f'AUTOTECHNO_LONG_HORIZON_CALIBRATION {label}={artifact["fingerprint"]}'
        for label,artifact in [('profile',profile),('adversarial',suite),('holdout',held)])
    log += '\n✔ Test run with 1 test passed after 1000.0 seconds.\n'
    raw = log.encode()
    status = dict(source=SOURCE, exitCode=0, actualOneNativeTestZeroSkipsPassed=True,
        independentlyAuditedCompleteHistories=18, requiredHistories=18,
        observerErrors=[], all18CompleteHistoryAuditsPassed=True,
        originalLogSHA256=hashlib.sha256(raw).hexdigest())
    return [protocol,cold,documents,artifacts,status,raw,SOURCE,'binding',attacks]


class LongProductTests(unittest.TestCase):
    def test_complete_shape_preserves_different_native_histories_and_has_no_authority(self):
        result=v.verify_products(*products())
        self.assertEqual(result['completeHistories'],18)
        self.assertFalse(result['crossRateHistoryEqualityRequired'])
        for key in ['freshCaptureConstructed','nativeExecutionProven','originalByteContextAuthenticated',
                    'sealedCandidateProductsDecoded','currentSourceApplicabilityVerified',
                    'installedArtifactsVerified','completeResourceQualification','fullPlatformQualified',
                    'runtimeQualification','item39Complete']:
            self.assertIs(result[key],False)

    def test_incomplete_native_matrix_and_weakened_contracts_refuse(self):
        mutations = [lambda a:a[2].pop((9,48000)),
            lambda a:a[0].update(numericCeilingBytes=268435456),
            lambda a:a[0].update(maximumRenderPasses=3),
            lambda a:a[0].update(archiveImport=True),
            lambda a:a[0].update(noCrossRateHistoryEqualityRequired=False),
            lambda a:a[0]['holdoutRoots'].__setitem__(0,1),
            lambda a:a[2][1,44100]['journey'].update(completedRequestedScope=False),
            lambda a:a[2][1,44100]['journey'].update(reservedNumericPeakBytes=268435456)]
        for i,mutate in enumerate(mutations):
            with self.subTest(i=i), self.assertRaises((ValueError,KeyError)):
                args=products();mutate(args);v.verify_products(*args)

    def test_per_rate_reductions_and_holdout_gates_cannot_be_averaged(self):
        mutations = [lambda a:a[3]['development']['observations'][0]['routes'].pop(),
            lambda a:a[3]['development']['observations'][0]['routes'][0].update(sampleRate=48000),
            lambda a:a[3]['development']['observations'][0]['routes'][0]['operatorDeltas'][0].update(meanDelta=0.5),
            lambda a:a[3]['development']['observations'][0]['routes'][0]['semanticValues'][0].update(value=1),
            lambda a:a[3]['development']['observations'][0]['routes'][0]['effects'].pop(),
            lambda a:a[3]['holdoutVerdicts']['journeys'][0]['verdict']['routeVerdicts'].pop(),
            lambda a:a[3]['holdoutVerdicts']['journeys'][0]['verdict']['routeVerdicts'][0]['verdict'].update(accepted=False),
            lambda a:a[3]['adversarial']['cases'].pop(),
            lambda a:a[3]['adversarial']['cases'][0].update(rejected=False),
            lambda a:a[3]['profile'].update(developmentJourneyCount=True)]
        for i,mutate in enumerate(mutations):
            with self.subTest(i=i), self.assertRaises((ValueError,KeyError)):
                args=products();mutate(args);v.verify_products(*args)

    def test_original_terminal_and_native_stdout_are_required(self):
        for mutate in [lambda a:a[4].update(exitCode=True),
                       lambda a:a[4].update(exitCode=1),
                       lambda a:a[4].update(originalLogSHA256='0'*64),
                       lambda a:a[4].update(independentlyAuditedCompleteHistories=7),
                       lambda a:a.__setitem__(5,b'passed')]:
            with self.assertRaises((ValueError,KeyError)):
                args=products();mutate(args);v.verify_products(*args)
        with self.assertRaises((ValueError,KeyError)):
            v.verify_products(*([{'passed':True}]*5),b'passed',SOURCE,'binding',['attack'])

    def test_generic_unpinned_context_refuses_before_any_native_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);(root/'cold.json').write_text('{"passed":true}')
            context=v.Context(root,root,root,root,'cold.json','0'*64,SOURCE,'terminal.json','0'*64)
            with self.assertRaisesRegex(ValueError,'cold proof SHA256'):
                context.inputs()

    def test_original_archives_require_exact_live_bytes_sizes_and_safe_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);live=root/'live.json';live.write_bytes(b'{}')
            archive=root/'original.json.gz';archive.write_bytes(gzip.compress(b'{}',mtime=0))
            context=v.Context(root,root,root,root,'cold.json','0'*64,SOURCE,'terminal.json','0'*64)
            record=dict(archive=archive.name,bytes=2,sha256=hashlib.sha256(b'{}').hexdigest())
            self.assertEqual(context.original(record,live),b'{}')
            for changes in [dict(bytes=True),dict(bytes=3),dict(sha256='0'*64),dict(archive='../escape')]:
                with self.subTest(changes=changes),self.assertRaises((ValueError,OSError)):
                    context.original(dict(record,**changes),live)
            live.write_bytes(b'[]')
            with self.assertRaisesRegex(ValueError,'live original differs'):
                context.original(record,live)
            live.unlink();live.symlink_to(archive)
            with self.assertRaisesRegex(ValueError,'live original size'):
                context.original(record,live)

    def test_a_complete_flag_never_supplies_missing_native_history_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            for name in v.ARTIFACTS.values():(root/name).write_text('{"passed":true}')
            context=v.Context(root,root,root,root,'cold.json','0'*64,SOURCE,'terminal.json','0'*64)
            with self.assertRaisesRegex(ValueError,'file'):
                v.original_paths(context,dict(protocol=products()[0]))

    def test_terminal_preservation_roundtrip_authenticates_every_original_and_refuses_changes(self):
        # Only the cold-context boundary is replaced by unit data. The real CLI
        # cannot use this substitute and independently checks Git/build/runtime.
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);study=root/'study';runner=root/'runner';evidence=root/'evidence'
            for p in [study,runner,evidence]:p.mkdir()
            args=products();protocol,cold,documents,artifacts,status,log,source,binding,attacks=args
            cold.update(buildMetadataSHA256='1'*64,runnerSHA256='2'*64,
                protocolSHA256='3'*64,auditorSHA256='4'*64)
            inputs=dict(source=source,protocol=protocol,cold=cold,inputBindingFingerprint=binding,
                attacks=attacks,coldProofSHA256='5'*64,driverSHA256='6'*64,prePCMAuditSHA256='7'*64)
            context=v.Context(root,study,runner,root,'evidence/cold.json','5'*64,source,
                'evidence/terminal-proof.json','0'*64)
            def write(path,value):path.write_text(json.dumps(value,sort_keys=True)+'\n')
            for (seed,rate),document in documents.items():
                name=f'actual-journey-{seed}-{rate}'
                path=study/(name+'.json');write(path,document)
                observed=v.verify_history(document,binding,list(range(1,10)),'policy',ENGINE)
                write(evidence/(name+'-audit.json'),dict(**observed,source=source,
                    originalRouteSHA256=v.sha(path),coldByteBindingsRechecked=True,historyIndependentlyAudited=True))
            for key,name in v.ARTIFACTS.items():write(study/name,artifacts[key])
            write(runner/'execution-status.json',status)
            (runner/'execution.log').write_bytes(log)
            launch=dict(source=source,coldPrivateAuditSHA256='5'*64,
                buildMetadataSHA256='1'*64,runnerSHA256='2'*64,protocolSHA256='3'*64,
                inputAuditorSHA256='4'*64,driverSHA256='6'*64,prePCMAuditSHA256='7'*64,
                inputBindingFingerprint=binding,pid=100,
                command=[str(runner/'runner'),'--no-parallel','--filter',
                    'LongHorizonPolicyCalibrationIntegrationTests[/.]generateArtifacts'],
                archiveImport=False,partialStateImport=False,runtimeActivation=False)
            write(runner/'execution-launch.json',launch)
            for p in study.glob('*.json'):
                (evidence/(p.name+'.gz')).write_bytes(gzip.compress(p.read_bytes(),mtime=0))
            for name in ['execution-status.json','execution-launch.json']:
                (evidence/name).write_bytes((runner/name).read_bytes())
            (evidence/'original-execution.log.gz').write_bytes(gzip.compress(log,mtime=0))
            with mock.patch.object(v.Context,'inputs',return_value=inputs):
                proof=v.collect_terminal(context)
                self.assertEqual(len(proof['files']),44)
                target=evidence/'terminal-proof.json';write(target,proof)
                context=v.Context(root,study,runner,root,'evidence/cold.json','5'*64,source,
                    'evidence/terminal-proof.json',v.sha(target))
                result=v.verify(context)
                self.assertTrue(result['originalByteContextAuthenticated'])
                self.assertTrue(result['originalNativeExecutionBound'])
                self.assertFalse(result['item39Complete'])
                self.assertFalse(result['currentSourceApplicabilityVerified'])
                self.assertFalse(result['installedArtifactsVerified'])
                path=study/v.ARTIFACTS['profile'];before=path.read_bytes();path.write_text('{"passed":true}')
                with self.assertRaises(ValueError):v.verify(context)
                path.write_bytes(before)
                malformed=copy.deepcopy(proof);malformed['files'][-1]['archive']=malformed['files'][0]['archive']
                write(target,malformed)
                context=v.Context(root,study,runner,root,'evidence/cold.json','5'*64,source,
                    'evidence/terminal-proof.json',v.sha(target))
                with self.assertRaisesRegex(ValueError,'unique original terminal inventory'):v.verify(context)


if __name__=='__main__':unittest.main()
