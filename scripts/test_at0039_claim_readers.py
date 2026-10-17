"""Synthetic counterexamples; these fixtures provide no native qualification."""
import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parent))
import at0039_claim_readers as r
import at0039_algorithmic_verification as audit
import test_at0039_algorithmic_verification as linear_tests


def energy():
    # Direct finite sample sums, independent of the reader's cumulative integral.
    families=['bipolar-square','bipolar-ramp','sparse-bipolar-pulse']
    scenarios=['intentional-overlap','half-amplitude','double-amplitude','unauthorized-truncation','deleted-required-companion','intentional-absence']
    rows=[]
    for family in families:
        for rate in r.RATES:
            frames=round(rate*240/130); span=round(frames/8)
            samples=[(64 if i%64<32 else -64) if family==families[0] else (i%32-16) if family==families[1] else (64 if i%97==0 else -64 if i%97==1 else 0) for i in range(span)]
            for scenario in scenarios:
                gain={'half-amplitude':.5,'double-amplitude':2,'deleted-required-companion':0,'intentional-absence':0}.get(scenario,1)
                support=span//2 if scenario=='unauthorized-truncation' else span
                windows=[]
                for cell in range(16):
                    a=math.ceil(cell*span/16); b=math.ceil((cell+1)*span/16)
                    kick=sum(x*x for x in samples[a:b])/1048576/(b-a)
                    foundation=sum(x*x*gain*gain for x in samples[a:min(b,support)])/1048576/(b-a) if a<support else 0.0
                    windows.append(dict(start=a,count=b-a,expectedKick=kick,observedKick=kick,expectedFoundation=foundation,observedFoundation=foundation))
                active=sum(w['expectedFoundation']>0 for w in windows)
                rows.append(dict(family=family,split='development' if family==families[0] else 'held-out-construction-family',rate=rate,scenario=scenario,
                    requiredCompanion=scenario!='intentional-absence',missingRequiredCompanion=scenario=='deleted-required-companion',
                    intendedFoundationEnergy=sum(x*x for x in samples)/1048576 if scenario!='intentional-absence' else 0,
                    observedFoundationEnergy=sum(w['observedFoundation']*w['count'] for w in windows),expectedTemporalWindows=active,observedTemporalWindows=active,windows=windows))
    return dict(schema=r.ENERGY,unavailable=['perceptual-masking-harm','band-filter-calibration','score-to-foundation-render-binding','nonlinear-full-mix-quality','population-uncertainty-fixed-construction-families'],rows=rows,failures=[],
        summaries=[dict(family=f,rate=rate,measurements=192,meanAbsoluteError=0,rootMeanSquareError=0,signedError=0) for f in families for rate in r.RATES])


def full_phrase(behavior=None,voice=None):
    schema=r.FULL_COMPANION if voice else r.FULL_BEHAVIOR if behavior else r.FULL_BASS
    noun='companion' if voice else 'bass'
    scenarios=['unaltered','undeclared-bass'] if behavior=='absent' else ['unaltered','deleted-'+noun,'shifted-'+noun,'wrong-voice','zero-intensity']
    rows=[]
    for seed,split in r.ROOTS.items():
        for rate in r.RATES:
            for scenario in scenarios:
                valid=scenario=='unaltered'; original=0 if behavior=='absent' else 2
                row=dict(rootSeed=seed,split=split,sampleRate=rate,scenario=scenario,originalPlanFingerprint='a'*16,
                    renderedPlanFingerprint=('a' if valid else 'b')*16,originalSampleHash='c'*16,renderedSampleHash=('c' if valid else 'd')*16,
                    frameCount=12000,differenceRMS=0 if valid else .01,foundationComplete=valid,vectorComplete=valid,transactionComplete=valid,exactReplay=True)
                if voice:
                    row.update(companionVoice=voice,companionMatchesOriginal=valid,originalCompanionEvents=original,
                        renderedCompanionEvents=original if scenario in ('unaltered','shifted-companion','zero-intensity') else 0)
                else:
                    row.update(originalBassEvents=original,renderedBassEvents=1 if scenario=='undeclared-bass' else original if scenario in ('unaltered','shifted-bass','zero-intensity') else original-1 if behavior else 0)
                    if behavior: row.update(selectedFoundationBehavior=behavior,targetedScoreBars=[2],targetedBassEvents=0 if behavior=='absent' else 1)
                rows.append(row)
    return dict(schema=schema,scope='canonical-full-phrase-render-and-candidate-transaction-binding',rows=rows,
        unavailable=['all-foundation-behaviors','unauthorized-truncation' if voice else 'companion-and-truncation-faults','accepted-continuous-journey','production-calibration','perceptual-quality','full-prepared-commit-fault-matrix','population-error-intervals'])


class ClaimReadersTests(unittest.TestCase):
    def test_source_energy_reintegrates_the_independent_sample_equations(self):
        self.assertEqual(r.read(energy())['checks']['rows'],36)

    def test_expected_and_observed_energy_cannot_be_forged_together(self):
        p=energy(); w=p['rows'][0]['windows'][0]; w['expectedKick']=w['observedKick']=1
        with self.assertRaises(ValueError): r.read(p)

    def test_energy_summaries_geometry_splits_and_fault_witnesses_refuse(self):
        for change in [lambda p:p['rows'][0]['windows'][0].update(count=1),lambda p:p['rows'][0].update(observedTemporalWindows=0),
                lambda p:p['rows'][4].update(missingRequiredCompanion=False),lambda p:p['rows'][5].update(requiredCompanion=True),
                lambda p:p['summaries'][0].update(meanAbsoluteError=1e-30),lambda p:p['rows'][0].update(split='held-out-construction-family')]:
            p=energy(); change(p)
            with self.assertRaises(ValueError): r.read(p)

    def test_all_full_phrase_variants_keep_intent_and_nonlinear_damage_distinct(self):
        for kwargs in [{},{'voice':'rumble'},{'voice':'tunedTom'}]+[{'behavior':b} for b in ['absent','monotone','point','pump','subPulse']]:
            result=r.read(full_phrase(**kwargs))
            self.assertFalse(result['nativeExecutionAuthenticated'])
            self.assertFalse(result['currentSourceApplicability'])
            self.assertFalse(result['checks']['rawPCMIndependentlyRendered'])

    def test_deleted_required_part_is_not_a_successful_absence_control(self):
        p=full_phrase(); p['rows'][1].update(vectorComplete=True,transactionComplete=True,foundationComplete=True)
        with self.assertRaises(ValueError): r.read(p)

    def test_silent_damaged_render_cannot_hide_behind_valid_transaction_flags(self):
        for change in [dict(differenceRMS=0),dict(renderedSampleHash='c'*16),dict(renderedPlanFingerprint='a'*16),dict(exactReplay=False)]:
            p=full_phrase(); p['rows'][1].update(change)
            with self.assertRaises(ValueError): r.read(p)

    def test_full_phrase_zero_intensity_bass_retains_every_scheduled_event(self):
        for behavior in [None,'monotone','point','pump','subPulse']:
            original=full_phrase(behavior)
            r.read(original)
            for index,row in enumerate(original['rows']):
                if row['scenario']!='zero-intensity': continue
                for count in (0,row['originalBassEvents']+1):
                    changed=copy.deepcopy(original)
                    changed['rows'][index]['renderedBassEvents']=count
                    with self.subTest(behavior=behavior,root=row['rootSeed'],rate=row['sampleRate'],count=count):
                        with self.assertRaises(ValueError): r.read(changed)

    def test_absent_behavior_requires_an_actual_undeclared_part_counterexample(self):
        p=full_phrase('absent'); p['rows'][1]['renderedBassEvents']=0
        with self.assertRaises(ValueError): r.read(p)

    def test_wrong_voice_or_targeted_event_count_cannot_change_the_oracle(self):
        for change in [lambda p:p['rows'][1].update(originalBassEvents=3),lambda p:p['rows'][1].update(targetedBassEvents=2),
                       lambda p:p['rows'][0].update(selectedFoundationBehavior='arbitrary')]:
            p=full_phrase('pump'); change(p)
            with self.assertRaises(ValueError): r.read(p)

    def test_missing_duplicate_foreign_rate_root_and_promotion_refuse(self):
        for make in [energy,full_phrase]:
            for change in [lambda p:p['rows'].pop(),lambda p:p['rows'].append(copy.deepcopy(p['rows'][0])),
                           lambda p:p.update(passed=True),lambda p:p['unavailable'].pop()]:
                p=make(); change(p)
                with self.assertRaises(ValueError): r.read(p)
        for field,value in [('sampleRate',True),('sampleRate',96000),('rootSeed',77777),('differenceRMS',math.inf),('exactReplay',1)]:
            p=full_phrase(); p['rows'][0][field]=value
            with self.assertRaises(ValueError): r.read(p)

    def test_every_supported_schema_refuses_generic_or_malformed_json(self):
        for schema in r.READERS:
            for rows in [[],None,[{}],[True]]:
                with self.assertRaises(ValueError): r.read(dict(schema=schema,rows=rows,passed=True))

    def test_report_diagnosis_has_no_platform_prerequisite_or_promotion_authority(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'report.json'; raw=json.dumps(energy()).encode(); path.write_bytes(raw)
            command=[sys.executable,str(Path(audit.__file__)),'--report',str(path),'--report-sha256',hashlib.sha256(raw).hexdigest()]
            child=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(child.returncode,0,child.stderr); result=json.loads(child.stdout)
            for flag in ['nativeExecutionAuthenticated','currentSourceApplicability','fullAlgorithmicAcceptanceVerified','runtimeQualification','item39Complete']:
                self.assertIs(result[flag],False)
            rejected=subprocess.run(command+['--source','a'*40],capture_output=True,text=True)
            self.assertNotEqual(rejected.returncode,0)
            path.write_bytes(raw+b'changed')
            self.assertNotEqual(subprocess.run(command,capture_output=True).returncode,0)

    def test_complete_platform_and_linear_success_cannot_supply_other_claim_products(self):
        bundle,logs=linear_tests.fixture()
        self.assertTrue(audit.verify(bundle,linear_tests.native.SOURCE,logs)['constructedLinearEvidenceVerified'])
        with self.assertRaises(ValueError): audit.verify_claims(bundle,linear_tests.native.SOURCE,logs)

    def test_multi_report_native_framing_requires_exact_count_and_named_completion(self):
        name='Native source release distinguishes score authority from truncation'
        suite='Score-owned foundation rhythm'; raw=json.dumps(energy())
        body=f'◇ Test "{name}" started.\n'+raw+'\n'+raw+f'\n✔ Test "{name}" passed after 0.3 seconds.\n'
        self.assertEqual(len(audit.reports_from_native(body,r.ENERGY,name,suite,2)),2)
        for count in (1,3):
            with self.assertRaises(ValueError): audit.reports_from_native(body,r.ENERGY,name,suite,count)
        with self.assertRaises(ValueError): audit.reports_from_native(body.replace('passed after','failed after'),r.ENERGY,name,suite,2)

    def test_native_identity_registry_matches_existing_test_owners(self):
        root=Path(__file__).resolve().parents[1]
        identities=[]
        for owner,method,name,suite,schema,count,behavior in audit.claim_cases():
            text=(root/'Tests/AutoTechnoCoreTests'/f'{owner}.swift').read_text()
            self.assertIn('func '+method.split('(')[0]+'(',text)
            self.assertIn('"'+name+'"',text); self.assertIn('"'+suite+'"',text)
            self.assertIn(schema,text)
            identities.append((owner,method))
        self.assertEqual(len(identities),len(set(identities)))

    def test_nested_boolean_integer_aliases_are_not_exact_score_facts(self):
        for value,expected in [([True],[1]),({'onsets':[False]},{'onsets':[0]})]:
            with self.assertRaises(ValueError): r.exact(value,expected)


if __name__=='__main__': unittest.main()
