"""Synthetic refusal controls. No native capture, fit, or promotion evidence."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import long_horizon_study_recovery as recovery
from test_long_horizon_history_integrity import fixture


class InterruptedStudyControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.context = dict(source=recovery.ORIGINAL_SOURCE,
            inputBindingFingerprint=recovery.ORIGINAL_BINDING, roots=list(recovery.ROOTS),
            primaryPolicyVersion='policy', engineVersion='fixture-engine',
            buildMetadataSHA256='a'*64, launchSHA256='b'*64)
        self.document = dict(schema='autotechno-interrupted-long-study-recovery.v1',
            authorization=dict(decision='explicit-user-approval',
                scope='preserve-nine-originals-render-nine-missing', statement='Synthetic decision fixture'),
            originalSource=recovery.ORIGINAL_SOURCE, originalInputBinding=recovery.ORIGINAL_BINDING,
            originalBuildMetadataSHA256='a'*64, originalLaunchSHA256='b'*64,
            originalPrimaryPolicyVersion='policy', originalEngineVersion='fixture-engine',
            completedOriginals=[], missingRoutes=[dict(rootSeed=r, sampleRate=s) for r,s in sorted(recovery.MISSING)])
        for root, rate in sorted(recovery.ALL-recovery.MISSING):
            artifact = fixture(rate)
            artifact['inputBindingFingerprint'] = recovery.ORIGINAL_BINDING
            self.set_root(artifact['journey'], root)
            path = self.root / f'{root}-{rate}.json'
            path.write_text(json.dumps(artifact))
            self.document['completedOriginals'].append(dict(rootSeed=root, sampleRate=rate,
                source=recovery.ORIGINAL_SOURCE, inputBindingFingerprint=recovery.ORIGINAL_BINDING,
                origin='preserved-original', freshCapture=False, path=path.name, sha256=recovery.sha(path)))

    def set_root(self, value, root):
        if isinstance(value, dict):
            for key, child in value.items():
                if key=='rootSeed':value[key]=root
                else:self.set_root(child,root)
        elif isinstance(value,list):
            for child in value:self.set_root(child,root)

    def verify(self, document=None):
        return recovery.verify_manifest(document or self.document, self.context, self.root)

    def test_exact_nine_preserved_and_nine_missing_have_no_promotion_authority(self):
        self.assertEqual(len(self.verify()), 9)
        self.assertEqual(len(recovery.MISSING), 9)
        self.assertEqual(len(recovery.ALL), 18)
        self.assertNotIn((141421,44100), recovery.MISSING)
        self.assertIn((141421,48000), recovery.MISSING)

    def test_silent_default_or_wrong_approval_scope_refuses(self):
        for change in ({}, dict(decision='recommended',scope='preserve-nine-originals-render-nine-missing',statement='x'),
                       dict(decision='explicit-user-approval',scope='all-archives',statement='x')):
            d=copy.deepcopy(self.document);d['authorization']=change
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify(d)

    def test_foreign_source_binding_primary_engine_or_metadata_refuses(self):
        for key in ('originalSource','originalInputBinding','originalPrimaryPolicyVersion',
                    'originalEngineVersion','originalBuildMetadataSHA256','originalLaunchSHA256'):
            d=copy.deepcopy(self.document);d[key]='foreign'
            with self.subTest(key=key),self.assertRaises(recovery.history.HistoryIntegrityError):self.verify(d)

    def test_duplicate_unknown_omitted_or_boolean_route_refuses(self):
        for collection in ('completedOriginals','missingRoutes'):
            for mutation in ('duplicate','unknown','omitted','boolean'):
                d=copy.deepcopy(self.document);rows=d[collection]
                if mutation=='duplicate':rows[-1]=copy.deepcopy(rows[0])
                elif mutation=='unknown':rows[-1]['rootSeed']=999999
                elif mutation=='omitted':rows.pop()
                else:rows[-1]['sampleRate']=True
                with self.subTest(collection=collection,mutation=mutation),self.assertRaises(recovery.history.HistoryIntegrityError):self.verify(d)

    def test_completed_route_cannot_be_reclassified_as_fresh_or_foreign_origin(self):
        for key,value in [('freshCapture',True),('origin','fresh-recovery-execution'),
                          ('source','new-head'),('inputBindingFingerprint','new-binding')]:
            d=copy.deepcopy(self.document);d['completedOriginals'][0][key]=value
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify(d)

    def test_changed_original_bytes_refuse_even_if_its_identity_is_unchanged(self):
        row=self.document['completedOriginals'][0];path=self.root/row['path'];path.write_bytes(path.read_bytes()+b'\n')
        with self.assertRaisesRegex(recovery.history.HistoryIntegrityError,'history changed'):self.verify()

    def test_resealed_partial_failed_qualified_or_recovered_original_refuses(self):
        row=self.document['completedOriginals'][0];path=self.root/row['path'];original=json.loads(path.read_text())
        changes=[lambda d:d['journey'].update(completedRequestedScope=False),
                 lambda d:d['journey'].update(failureCode='stopped'),
                 lambda d:d.update(archiveImport=True),lambda d:d.update(longHorizonQualification=True),
                 lambda d:d.update(recoveryProvenance={'foreign':'study'})]
        for change in changes:
            artifact=copy.deepcopy(original);change(artifact);path.write_text(json.dumps(artifact));row['sha256']=recovery.sha(path)
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()

    def test_file_identity_and_path_confinement_refuse_wrong_or_escaping_history(self):
        for path in ('../outside.json','/outside.json',self.document['completedOriginals'][1]['path']):
            d=copy.deepcopy(self.document);d['completedOriginals'][0]['path']=path
            if path.endswith('.json') and (self.root/path).is_file():d['completedOriginals'][0]['sha256']=recovery.sha(self.root/path)
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify(d)

    def test_recovery_binding_depends_on_both_new_input_seals_and_never_retags_original(self):
        values=[recovery.binding('a'*64,'b'*64), recovery.binding('c'*64,'b'*64), recovery.binding('a'*64,'c'*64)]
        self.assertEqual(len(set(values)),3)
        self.assertTrue(all(value!=recovery.ORIGINAL_BINDING and len(value)==16 for value in values))

    def fresh(self):
        meta={'harnessSource':'a'*40}
        spec=recovery.request(141421,48000,self.document,self.context,meta,'b'*64,'c'*64)
        artifact=fixture(48000);self.set_root(artifact['journey'],141421);artifact['inputBindingFingerprint']=spec['recoveryInputBinding']
        artifact['recoveryProvenance']={key:spec[key] for key in ('originalSource','originalInputBinding','harnessSource','manifestSHA256','buildMetadataSHA256')}
        artifact['recoveryProvenance'].update(schema='autotechno-interrupted-long-route-provenance.v1',routeOrigin='fresh-complete-execution-from-initial-state')
        return spec,artifact

    def test_fresh_route_needs_exact_separate_provenance_and_full_history(self):
        spec,artifact=self.fresh();result=recovery.verify_fresh(artifact,spec,self.context)
        self.assertEqual((result['rootSeed'],result['sampleRate']),(141421,48000))
        for change in [lambda d:d.update(inputBindingFingerprint=recovery.ORIGINAL_BINDING),
                       lambda d:d['recoveryProvenance'].update(harnessSource='foreign'),
                       lambda d:d['recoveryProvenance'].update(originalInputBinding='foreign'),
                       lambda d:d['recoveryProvenance'].update(routeOrigin='archived'),
                       lambda d:d['recoveryProvenance'].update(extra='retag'),
                       lambda d:d['journey'].update(requestedPrefixPhraseCount=128)]:
            bad=copy.deepcopy(artifact);change(bad)
            with self.assertRaises(recovery.history.HistoryIntegrityError):recovery.verify_fresh(bad,spec,self.context)

    def test_native_request_factory_refuses_every_completed_pair_and_non_native_rate(self):
        for root,rate in sorted(recovery.ALL-recovery.MISSING)+[(141421,8000)]:
            with self.assertRaises(recovery.history.HistoryIntegrityError):
                recovery.request(root,rate,self.document,self.context,{'harnessSource':'a'*40},'b'*64,'c'*64)

    def test_canonical_route_comparison_covers_body_and_support_up_to_witness(self):
        text='before\n  private static func renderPreparedRoute(abc) { canonical }\n  private struct RefusedSignalInputs: Codable {}'
        self.assertIn('canonical',recovery.canonical_route(text))
        self.assertEqual(recovery.canonical_route(text),recovery.canonical_route(text.replace('before','different harness')))
        self.assertNotEqual(recovery.canonical_route(text),recovery.canonical_route(text.replace('canonical','changed')))



class FrozenBuildControls(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup)
        base=Path(self.temporary.name);self.origin=base/'origin';self.harness=base/'harness';self.runner=base/'original-runner';self.runtime=base/'bundle'
        for p in (self.origin,self.harness,self.runner,self.runtime):p.mkdir()
        self.module=base/'Modules';self.module.mkdir();(self.module/'Core.swiftmodule').write_text('frozen module')
        self.entry=base/'main.swift';self.entry.write_text('entry')
        self.object=base/'core.o';self.object.write_text('frozen object')
        (self.runtime/'profile.json').write_text('frozen resource')
        text='  private static func renderPreparedRoute(x) { canonical }\n  private struct RefusedSignalInputs: Codable {}'
        self.tests={recovery.OWNER:None,'Tests/AutoTechnoCoreTests/Support.swift':None}
        for root in (self.origin,self.harness):
            for name in self.tests:
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text if name==recovery.OWNER else 'support')
        originals={name:recovery.sha(self.origin/name) for name in self.tests}
        self.groups=dict(sources={'Sources/Core.swift':'a'*64},testFiles=originals,
            objects={str(self.object):recovery.sha(self.object)},resources={'profile.json':recovery.sha(self.runtime/'profile.json')})
        self.command=['swiftc','-O','-I',str(self.module),'-module-name','Original',str(self.entry),
            *[str(self.origin/name) for name in self.tests],str(self.object),'-lc++','-o',str(self.runner/'runner')]
        (self.runner/'build-metadata.json').write_text(json.dumps(dict(inputs=self.groups,command=self.command)))
        self.executable=base/'recovery-runner';self.executable.write_text('native binary fixture')
        expected=self.command.copy();expected[expected.index('-module-name')+1]='AT0039InterruptedLongRecoveryRunner';expected[expected.index('-o')+1]=str(self.executable)
        expected[expected.index(str(self.origin/recovery.OWNER))]=str(self.harness/recovery.OWNER)
        self.metadata=dict(schema='autotechno-frozen-long-recovery-build.v1',harnessSource='c'*40,
            originalSource=recovery.ORIGINAL_SOURCE,originalBuildMetadataSHA256='b'*64,inputs=copy.deepcopy(self.groups),
            runtimeResourceBundle=str(self.runtime),supportInputs=recovery.compiler_support(self.command),
            command=expected,executable=str(self.executable),executableSHA256=recovery.sha(self.executable))
        self.document=dict(originRoot=str(self.origin),originalRunnerDirectory=str(self.runner),
                           originalBuildMetadataSHA256='b'*64,runtimeResources=str(self.runtime))

    def verify(self):
        with mock.patch.object(recovery.history,'git',side_effect=lambda root,*args:'c'*40 if args[0]=='rev-parse' else ''):
            return recovery.verify_build(self.harness,self.metadata,self.document)

    def test_same_frozen_linkage_and_complete_module_resource_inputs_pass(self):self.verify()

    def test_changed_production_or_test_membership_and_runtime_bundle_refuse(self):
        baseline=copy.deepcopy(self.metadata)
        for mutate in [lambda m:m['inputs']['sources'].update({'Sources/Core.swift':'0'*64}),
                       lambda m:m['inputs']['objects'].clear(),
                       lambda m:m['inputs']['testFiles'].pop('Tests/AutoTechnoCoreTests/Support.swift'),
                       lambda m:m.update(runtimeResourceBundle=str(self.origin))]:
            self.metadata=copy.deepcopy(baseline);mutate(self.metadata)
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()

    def test_mutated_route_body_and_unrelated_test_refuse(self):
        for name in self.tests:
            p=self.harness/name if name==recovery.OWNER else self.origin/name;original=p.read_bytes();p.write_bytes(original+b'changed')
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()
            p.write_bytes(original)

    def test_changed_or_omitted_module_driver_runtime_and_executable_refuse(self):
        for p in (self.module/'Core.swiftmodule',self.entry,self.runtime/'profile.json',self.executable):
            original=p.read_bytes();p.write_bytes(original+b'changed')
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()
            p.write_bytes(original)
        self.metadata['supportInputs'].pop(str(self.module/'Core.swiftmodule'))
        with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()

    def test_compile_recipe_cannot_link_another_engine_or_disable_optimization(self):
        original=self.metadata['command'].copy()
        for mutate in [lambda c:c.remove('-O'),lambda c:c.insert(-3,'another-engine.o'),lambda c:c.append('-DDEBUG')]:
            self.metadata['command']=original.copy();mutate(self.metadata['command'])
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()

class CompletedRecoveryControls(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup);self.output=Path(self.temporary.name)
        self.document=dict(completedOriginals=[]);self.context=dict(roots=list(recovery.ROOTS),primaryPolicyVersion='policy',engineVersion='fixture-engine')
        self.metadata=dict(harnessSource='a'*40,executableSHA256='d'*64);self.fresh=[]
        for root,rate in sorted(recovery.MISSING):
            case=self.output/f'{root}-{rate}';(case/'native').mkdir(parents=True)
            spec=recovery.request(root,rate,self.document,self.context,self.metadata,'b'*64,'c'*64)
            artifact=fixture(rate)
            InterruptedStudyControls.set_root(self,artifact['journey'],root)
            artifact['inputBindingFingerprint']=spec['recoveryInputBinding'];artifact['recoveryProvenance']={key:spec[key] for key in ('originalSource','originalInputBinding','harnessSource','manifestSHA256','buildMetadataSHA256')}
            artifact['recoveryProvenance'].update(schema='autotechno-interrupted-long-route-provenance.v1',routeOrigin='fresh-complete-execution-from-initial-state')
            p=case/'native'/f'actual-journey-{root}-{rate}.json';p.write_text(json.dumps(artifact));recovery.write(case/'request.json',spec)
            (case/'native.log').write_text(f'Test run with 1 test passed\nrecovered-missing root={root} rate={rate} binding=x\n')
            recovery.write(case/'launch.json',dict(requestSHA256=recovery.sha(case/'request.json'),executableSHA256='d'*64))
            recovery.write(case/'execution-status.json',dict(exitCode=0,originalLogSHA256=recovery.sha(case/'native.log')))
            self.fresh.append(dict(rootSeed=root,sampleRate=rate,path=str(p),sha256=recovery.sha(p),origin='fresh-recovery-execution'))
        self.completed=dict(schema='autotechno-interrupted-long-completed-routes.v1',originalSource=recovery.ORIGINAL_SOURCE,
            harnessSource='a'*40,manifestSHA256='b'*64,buildMetadataSHA256='c'*64,preservedOriginals=[],freshRoutes=self.fresh)
        recovery.write(self.output/'completed-routes.json',self.completed)

    def set_root(self,value,root):InterruptedStudyControls.set_root(self,value,root)

    def verify(self):return recovery.verify_completed(self.output,self.document,self.context,self.metadata,'b'*64,'c'*64)

    def test_nine_complete_separately_bound_route_receipts_pass(self):self.assertEqual(len(self.verify()),9)

    def test_zero_test_selection_or_missing_completion_cannot_count_as_native_pass(self):
        case=self.output/'141421-48000';path=case/'native.log';original=path.read_bytes()
        for text in ('Test run with 0 tests passed\nrecovered-missing root=141421 rate=48000 ', 'Test run with 1 test passed'):
            path.write_text(text);status=dict(exitCode=0,originalLogSHA256=recovery.sha(path));(case/'execution-status.json').write_text(json.dumps(status))
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()
        path.write_bytes(original)

    def test_failed_execution_request_drift_and_resealed_wrong_origin_refuse(self):
        case=self.output/'141421-48000'
        for name,change in [('execution-status.json',lambda d:d.update(exitCode=1)),
                            ('request.json',lambda d:d.update(recoveryInputBinding=recovery.ORIGINAL_BINDING)),
                            ('launch.json',lambda d:d.update(executableSHA256='foreign'))]:
            p=case/name;original=p.read_bytes();d=json.loads(original);change(d);p.write_text(json.dumps(d))
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()
            p.write_bytes(original)
        p=Path(self.fresh[0]['path']);d=json.loads(p.read_text());d['recoveryProvenance']['routeOrigin']='retagged-original';p.write_text(json.dumps(d));self.fresh[0]['sha256']=recovery.sha(p)
        (self.output/'completed-routes.json').write_text(json.dumps(self.completed))
        with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()

    def test_cohort_omission_or_redirected_history_path_refuses_assembly(self):
        for change in [lambda d:d['freshRoutes'].pop(),lambda d:d['freshRoutes'][0].update(path='/other/history.json')]:
            d=copy.deepcopy(self.completed);change(d);(self.output/'completed-routes.json').write_text(json.dumps(d))
            with self.assertRaises(recovery.history.HistoryIntegrityError):self.verify()


if __name__=='__main__':unittest.main()
