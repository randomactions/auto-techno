"""Synthetic controls only; never native capture or quality evidence."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

import test_long_horizon_history_integrity as fixtures
from at0039_primary_verification import VerificationError

import at0039_long_verification as v
SOURCE = 'a' * 40
ENGINE = 'fixture-engine'
fp = lambda text: hashlib.sha256(text.encode()).hexdigest()[:16]


def compiler_fixture(root, fmt=v.CURRENT):
    """Synthetic recipe only: no executable, compiler execution or authority."""
    runner = root/'runner'; runner.mkdir()
    source = root/'source'; source.mkdir()
    study = source/'docs/local/reports/current'
    main = runner/'main.swift'; main.write_text(v.expected_main(fmt, SOURCE, study))
    bundle = runner/'bundle'; bundle.mkdir()
    (bundle/'resource.json').write_text('{}')
    accessor = runner/'resource_bundle_accessor.swift'
    accessor.write_text('import Foundation\nextension Foundation.Bundle { static let module = '
        'Bundle(path: "'+str(bundle)+'")! }\n')
    production = {str(source/'Sources'/owner/'fixture.swift'): 'fixture' for owner in
        ['AutoTechnoCore', 'AutoTechnoDSP', 'AutoTechnoTransport']}
    test = str(source/'Tests/fixture.swift')
    obj = str(runner/'fixture.o')
    commands = {key: ['swiftc', str(source/'Sources'/owner/'fixture.swift')]
        for key,owner in [('core','AutoTechnoCore'), ('dsp','AutoTechnoDSP'),
                          ('transport','AutoTechnoTransport')]}
    commands['dsp'].append(str(accessor))
    commands['tests'] = ['swiftc', test, str(main), obj]
    for command in commands.values():command += ['-module-cache-path',str(runner/'ClangModuleCache')]
    metadata = dict(sources={**production,test:'fixture'}, objects={obj:'fixture'},
        compilerSupport={str(main):v.sha(main),str(accessor):v.sha(accessor)}, commands=commands,
        actualRuntimeResources={str(bundle/'resource.json'):v.sha(bundle/'resource.json')})
    return runner, source, study, metadata


def owned_fixture(root):
    runner, source, study, metadata = compiler_fixture(root)
    copies = {}
    for i in range(12):
        p = runner/'compiler-support'/f'input-{i}'; p.parent.mkdir(exist_ok=True)
        p.write_text(f'isolated dependency fixture {i}')
        metadata['compilerSupport'][str(p)] = v.sha(p)
        copies[str(root/'original'/str(i))] = dict(copied=str(p),sha256=v.sha(p))
    target = runner/'copied-compiler-support-bindings.json'
    target.write_text(json.dumps(copies))
    cold = dict(copiedCompilerSupportBindingsSHA256=v.sha(target),
        effectDoseSchemaVersion=3,longPolicyFamilyVersion=22)
    protocol = dict(effectDoseSchemaVersion=3,runtimeObservationVersion=6,
        longObservationVersion=8,longPolicyFamilyVersion=22)
    args=['--no-parallel','--filter',v.CAPTURE_SELECTOR]
    cases=[]
    for i,(arguments,environment) in enumerate([([],{}),(['--help'],{}),(args,{}),
            (args,{'AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION':'1'})]):
        (runner/f'guard-{i}.log').write_bytes(b'')
        cases.append(dict(case=i,arguments=arguments,extraEnvironment=environment,
            exitCode=97,outputBytes=0,actualNativeTests=0))
    (runner/'entry-guard-controls.json').write_text(json.dumps(dict(cases=cases,
        allFourRefusedBeforeTesting=True,captureStarted=False,qualified=False)))
    original = b"e.get('schemaVersion') == 2 and\n            e.get('schemaIdentifier') == 'autotechno-long-horizon-effect-dose.v2'"
    replacement = b"e.get('schemaVersion') == 3 and\n            e.get('schemaIdentifier') == 'autotechno-long-horizon-effect-dose.v3'"
    script=source/'scripts/long_horizon_history_integrity.py'
    script.parent.mkdir();script.write_bytes(original)
    proof=dict(files=[dict(source=str(root/'observer/long_horizon_history_integrity.py'),
        sha256=hashlib.sha256(replacement).hexdigest())])
    inventory={p.resolve(): {} for p in runner.iterdir() if p.is_file()}
    return SimpleNamespace(runner=runner,source_root=source),proof,metadata,cold,protocol,inventory


def products(study_format=v.LEGACY):
    fmt = study_format
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
            document = fixtures.fixture(rate, effect_schema_version=fmt.effect_version)
            j = document['journey']; j['rootSeed'] = seed
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
            routes.append(dict(schemaVersion=fmt.runtime,
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
        observations[seed] = dict(schemaVersion=fmt.observation, engineVersion=ENGINE,
            primaryPolicyVersion='policy', rootSeed=seed, routes=routes, sourceFingerprint=fp(f'root-{seed}'))
    artifacts = {partition: dict(schemaVersion=fmt.corpus, engineVersion=ENGINE,
        primaryPolicyVersion='policy', fingerprint=fp(partition), observations=[observations[s] for s in seeds])
        for partition,seeds in [('development',development),('holdout',holdout)]}
    profile = dict(profileVersion=fmt.profile, engineVersion=ENGINE, primaryPolicyVersion='policy',
        sampleRates=list(v.RATES), fingerprint=fp('profile'), developmentJourneyCount=7,
        developmentRootSeeds=development, developmentCorpusFingerprint=fp('development'))
    attacks = ['attack-'+str(i) for i in range(10)]
    suite = dict(schemaVersion=fmt.adversarial, engineVersion=ENGINE,
        profileFingerprint=fp('profile'), sourceObservationFingerprint=observations[1]['sourceFingerprint'],
        fingerprint=fp('adversarial'), passed=True,
        cases=[dict(sampleRate=rate, attack=attack, rejected=True, failedDimensions=['dimension'])
            for rate in v.RATES for attack in attacks])
    accepted = lambda: dict(accepted=True, failedDimensions=[], failedSemanticMetrics=[],
        failedOperatorDeltas=[], failedEffectFamilies=[])
    held = dict(schemaVersion=fmt.holdout, engineVersion=ENGINE, qualified=True,
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


class CompilerRecipeTests(unittest.TestCase):
    def test_both_known_entrypoints_and_actual_compiler_input_partition(self):
        for fmt in (v.LEGACY,v.CURRENT):
            with self.subTest(fmt=fmt.key),tempfile.TemporaryDirectory() as directory:
                runner,source,study,metadata=compiler_fixture(Path(directory),fmt)
                v.verify_compiler_recipe(runner,metadata,fmt,SOURCE,study)

    def test_unused_inventories_and_extra_linked_sources_or_objects_refuse(self):
        changes=[lambda m:m['commands']['tests'].append('/undeclared.swift'),
            lambda m:m['commands']['tests'].append('/undeclared.o'),
            lambda m:m['objects'].update({'/unused.o':'not an actual linked object'}),
            lambda m:m['commands']['tests'].append(m['commands']['tests'][1]),
            lambda m:m['commands']['core'].append('/hidden-production.swift'),
            lambda m:m['commands']['dsp'].pop(2)]
        for i,change in enumerate(changes):
            with self.subTest(i=i),tempfile.TemporaryDirectory() as directory:
                runner,source,study,metadata=compiler_fixture(Path(directory))
                change(metadata)
                with self.assertRaises(ValueError):
                    v.verify_compiler_recipe(runner,metadata,v.CURRENT,SOURCE,study)

    def test_fake_stdout_main_or_different_resource_accessor_refuses(self):
        for name,text in [('main.swift','print("Test run with 53 tests passed")\n'),
                          ('resource_bundle_accessor.swift','import Foundation\n// another bundle\n')]:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                runner,source,study,metadata=compiler_fixture(Path(directory))
                (runner/name).write_text(text)
                with self.assertRaises(ValueError):
                    v.verify_compiler_recipe(runner,metadata,v.CURRENT,SOURCE,study)

    def test_current_owned_inputs_guards_and_observer_delta_are_exact(self):
        with tempfile.TemporaryDirectory() as directory:
            v.verify_owned_support(*owned_fixture(Path(directory)))

    def test_current_owned_inputs_reject_byte_changes_or_external_cache(self):
        for case in ['copy','cache','duplicate-cache','protocol','cold-boolean','guard-output',
                     'guard-test','observer','generic-copies']:
            with self.subTest(case=case),tempfile.TemporaryDirectory() as directory:
                args=owned_fixture(Path(directory));context,proof,metadata,cold,protocol,inventory=args
                if case=='copy':(context.runner/'compiler-support/input-0').write_text('changed dependency')
                elif case=='cache':metadata['commands']['core'][-1]='/foreign/cache'
                elif case=='duplicate-cache':metadata['commands']['core']+=['-module-cache-path','/foreign/cache']
                elif case=='protocol':protocol['longObservationVersion']=7
                elif case=='cold-boolean':cold['effectDoseSchemaVersion']=3.0
                elif case=='guard-output':(context.runner/'guard-0.log').write_text('Testing started')
                elif case=='guard-test':
                    p=context.runner/'entry-guard-controls.json';data=json.loads(p.read_text())
                    data['cases'][0]['actualNativeTests']=1;p.write_text(json.dumps(data))
                elif case=='observer':proof['files'][0]['sha256']='0'*64
                elif case=='generic-copies':
                    p=context.runner/'copied-compiler-support-bindings.json';p.write_text('{"passed":true}')
                    cold['copiedCompilerSupportBindingsSHA256']=v.sha(p)
                with self.assertRaises((ValueError,KeyError,TypeError)):
                    v.verify_owned_support(*args)


class LongProductTests(unittest.TestCase):
    def test_current_complete_shape_preserves_each_native_history_without_promotion(self):
        result = v.verify_products(*products(v.CURRENT), study_format=v.CURRENT)
        self.assertEqual(result['schema'], 'autotechno-at0039-long-original-product-verification.v2')
        self.assertEqual(result['originalFormat'], 'v22')
        self.assertEqual(result['effectDoseSchemaVersion'], 3)
        self.assertEqual(result['longPolicyFamilyVersion'], 22)
        self.assertFalse(result['crossRateHistoryEqualityRequired'])
        for key in ['nativeExecutionProven', 'originalByteContextAuthenticated',
                    'currentSourceApplicabilityVerified', 'installedArtifactsVerified',
                    'completeResourceQualification', 'fullPlatformQualified',
                    'runtimeQualification', 'item39Complete']:
            self.assertIs(result[key], False)

    def test_known_formats_cannot_borrow_each_others_evidence(self):
        for fmt, other in [(v.LEGACY, v.CURRENT), (v.CURRENT, v.LEGACY)]:
            with self.subTest(fmt=fmt.key), self.assertRaises(ValueError):
                v.verify_products(*products(fmt), study_format=other)
        for rate in v.RATES:
            with self.subTest(rate=rate), self.assertRaises(ValueError):
                args = products(v.CURRENT)
                args[2][1, rate]['journey']['effects'].update(schemaVersion=2,
                    schemaIdentifier='autotechno-long-horizon-effect-dose.v2')
                v.verify_products(*args, study_format=v.CURRENT)

    def test_current_corpus_profile_and_native_gate_versions_refuse_mixed_inputs(self):
        mutations = [lambda a:a[3]['profile'].update(profileVersion=v.LEGACY.profile),
            lambda a:a[3]['development'].update(schemaVersion=v.LEGACY.corpus),
            lambda a:a[3]['development']['observations'][0].update(schemaVersion=v.LEGACY.observation),
            lambda a:a[3]['development']['observations'][0]['routes'][0].update(schemaVersion=v.LEGACY.runtime),
            lambda a:a[3]['adversarial'].update(schemaVersion=v.LEGACY.adversarial),
            lambda a:a[3]['holdoutVerdicts'].update(schemaVersion=v.LEGACY.holdout),
            lambda a:a[3]['holdoutVerdicts']['journeys'][0]['verdict']['routeVerdicts'][1]['verdict'].update(accepted=False)]
        for i, mutate in enumerate(mutations):
            with self.subTest(i=i), self.assertRaises(ValueError):
                args = products(v.CURRENT); mutate(args)
                v.verify_products(*args, study_format=v.CURRENT)

    def test_unknown_or_generic_format_cannot_select_a_constructor(self):
        for key in ['v23', '', True, None, {'passed': True}]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                v.bound_format(key)
        for proof in [dict(passed=True), dict(schema='future'), [], None]:
            with self.subTest(proof=proof), self.assertRaises(ValueError):
                v.cold_format(proof)

    def test_cold_format_cannot_downgrade_native_control_count_before_git(self):
        for fmt, count in [(v.CURRENT,26),(v.LEGACY,53),(v.CURRENT,True),(v.CURRENT,53.0)]:
            with self.subTest(fmt=fmt.key,count=count),tempfile.TemporaryDirectory() as directory:
                root=Path(directory)
                proof=dict(schema=fmt.cold_schema,source=SOURCE,coldNativeControls=count,
                    zeroSkips=True,freshInitialState=True,explicitImmutableRefBoundBeforePCM=True,
                    archiveImport=False,partialStateImport=False,historicalRetag=False,
                    longHorizonQualified=False,fullPlatformQualified=False,runtimeQualified=False,item39Complete=False)
                path=root/'cold.json';path.write_text(json.dumps(proof))
                context=v.Context(root,root,root,root,path.name,v.sha(path),SOURCE,'','')
                with mock.patch.object(v.Context,'git',side_effect=AssertionError('must refuse before Git')):
                    with self.assertRaisesRegex(ValueError,'original cold scope'):
                        context.inputs()

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
        self.terminal_roundtrip(v.LEGACY)

    def test_current_terminal_preservation_roundtrip_preserves_current_version_and_scope(self):
        self.terminal_roundtrip(v.CURRENT)

    def terminal_roundtrip(self, fmt):
        # Only the cold-context boundary is replaced by unit data. The real CLI
        # cannot use this substitute and independently checks Git/build/runtime.
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);study=root/'study';runner=root/'runner';evidence=root/'evidence'
            for p in [study,runner,evidence]:p.mkdir()
            args=products(fmt);protocol,cold,documents,artifacts,status,log,source,binding,attacks=args
            cold.update(buildMetadataSHA256='1'*64,runnerSHA256='2'*64,
                protocolSHA256='3'*64,auditorSHA256='4'*64)
            inputs=dict(source=source,protocol=protocol,formatKey=fmt.key,cold=cold,inputBindingFingerprint=binding,
                attacks=attacks,coldProofSHA256='5'*64,driverSHA256='6'*64,prePCMAuditSHA256='7'*64)
            context=v.Context(root,study,runner,root,'evidence/cold.json','5'*64,source,
                'evidence/terminal-proof.json','0'*64)
            def write(path,value):path.write_text(json.dumps(value,sort_keys=True)+'\n')
            for (seed,rate),document in documents.items():
                name=f'actual-journey-{seed}-{rate}'
                path=study/(name+'.json');write(path,document)
                observed=v.verify_history(document,binding,list(range(1,10)),'policy',ENGINE,
                    effect_schema_version=fmt.effect_version)
                write(evidence/(name+'-audit.json'),dict(**observed,source=source,
                    originalRouteSHA256=v.sha(path),coldByteBindingsRechecked=True,historyIndependentlyAudited=True))
            for key,name in fmt.artifacts.items():write(study/name,artifacts[key])
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
                path=study/fmt.artifacts['profile'];before=path.read_bytes();path.write_text('{"passed":true}')
                with self.assertRaises(ValueError):v.verify(context)
                path.write_bytes(before)
                malformed=copy.deepcopy(proof);malformed['files'][-1]['archive']=malformed['files'][0]['archive']
                write(target,malformed)
                context=v.Context(root,study,runner,root,'evidence/cold.json','5'*64,source,
                    'evidence/terminal-proof.json',v.sha(target))
                with self.assertRaisesRegex(ValueError,'unique original terminal inventory'):v.verify(context)


if __name__=='__main__':unittest.main()
