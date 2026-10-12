"""Synthetic receipt controls; fixture success is not hosted execution evidence."""
import copy
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
sys.path.insert(0, str(Path(__file__).resolve().parent))
import hosted_macos_verification as hosted
import result_status_vocabulary as results

SOURCE = 'a' * 40


def fixture(include_retired=False):
    discovery = {library: '\n'.join(f'AutoTechnoCoreTests.OwnerTests/test{i}()' for i in range(128))
                 for library in ['xctest', 'swift-testing']}
    if include_retired:
        discovery['swift-testing'] += '\n' + '\n'.join(hosted.RETIRED_SKIPS.values())
    rows = []
    for bank in range(8):
        plan = hosted.plan(discovery, bank, 8)
        completed = [dict(selection=s, reportedTests=len(s['identifiers']), explicitlySkippedTests=0,
                          executedTests=len(s['identifiers']), skippedIdentifiers=[], exitCode=0, logSHA256='b'*64) for s in plan['selected']]
        for result in completed:
            selected=result['selection']
            skipped=sorted(set(selected['identifiers']) & set(hosted.RETIRED_SKIPS.values())) if selected['library']=='swift-testing' else []
            result.update(skippedIdentifiers=skipped,explicitlySkippedTests=len(skipped),executedTests=result['reportedTests']-len(skipped))
        names = ['Verify macOS environment', 'Build all native tests', 'Execute complete native bank']
        if bank == 0: names += ['Run complete tooling tests', 'Build macOS Release app', 'Validate codebase map']
        rows.append(dict(receipt=dict(schema='autotechno-hosted-macos-bank.v1', source=SOURCE,
             environment='hosted-macos', bank=bank, banks=8, discovery=discovery, plan=plan, completedSlices=completed),
             job=dict(id=100+bank, run_id=50, head_sha=SOURCE, name=f'hosted-macos / Complete macOS bank {bank}',
                      status='completed', conclusion='success', steps=[dict(name=n,status='completed',conclusion='success') for n in names])))
    return dict(schema=hosted.SCHEMA,source=SOURCE,workflow=dict(id=20,path=hosted.WORKFLOW,state='active'),
                run=dict(id=50,workflow_id=20,head_sha=SOURCE,status='completed',conclusion='success',
                         event='workflow_dispatch',repository=dict(full_name='randomactions/auto-techno')),banks=rows)


def execution(raw):
    return dict(schema=hosted.EXECUTION_SCHEMA,environment='hosted-macos',
                scope='complete-native-suites-and-release-build',revision=SOURCE,
                receipt='docs/local/result-records/AT-0039-hosted-macos.json',receiptSHA256=hosted.sha(raw))


class HostedMacOSVerificationTests(unittest.TestCase):
    def test_complete_native_matrix_has_only_verification_scope(self):
        result = hosted.verify(fixture(), SOURCE)
        self.assertEqual(result['discoveredTests'], 256)
        self.assertEqual(result['executedTests'], 256)
        self.assertTrue(result['completeNativeSuitesAndReleaseBuild'])
        for key in ['localExecution','automatedQualityQualification','runtimeQualification','item39Complete']:
            self.assertFalse(result[key])

    def test_partial_mixed_failed_or_falsely_counted_receipts_refuse(self):
        changes = [lambda d:d['banks'].pop(), lambda d:d.__setitem__('source','f'*40),
          lambda d:d['run'].__setitem__('conclusion','failure'),
          lambda d:d['run'].__setitem__('status','in_progress'),
          lambda d:d['run'].__setitem__('head_sha','f'*40),
          lambda d:d['run']['repository'].__setitem__('full_name','other/repo'),
          lambda d:d['workflow'].__setitem__('path','.github/workflows/swift.yml'),
          lambda d:d['banks'][0]['job'].__setitem__('run_id',51),
          lambda d:d['banks'][0]['job'].__setitem__('head_sha','f'*40),
          lambda d:d['banks'][0]['job'].__setitem__('conclusion','cancelled'),
          lambda d:d['banks'][0]['job']['steps'][-1].__setitem__('conclusion','skipped'),
          lambda d:d['banks'][0]['job']['steps'].pop(4),
          lambda d:d['banks'][0]['receipt'].__setitem__('environment','local-macos'),
          lambda d:d['banks'][0]['receipt'].__setitem__('bank',True),
          lambda d:d['banks'][0]['receipt']['completedSlices'].pop(),
          lambda d:d['banks'][0]['receipt']['completedSlices'][0].__setitem__('reportedTests',0),
          lambda d:d['banks'][0]['receipt']['completedSlices'][0].__setitem__('exitCode',False),
          lambda d:d['banks'][0]['receipt']['completedSlices'][0].__setitem__('explicitlySkippedTests',1),
          lambda d:d['banks'][0]['receipt']['plan'].__setitem__('discoveredIdentifiers',255),
          lambda d:d['banks'][0]['receipt']['plan']['selected'][0].__setitem__('selector','.*')]
        for index, change in enumerate(changes):
            d=copy.deepcopy(fixture());change(d)
            with self.subTest(index=index),self.assertRaises(ValueError):hosted.verify(d,SOURCE)

    def test_skips_do_not_become_executed_behavior(self):
        result=hosted.verify(fixture(include_retired=True),SOURCE)
        self.assertEqual(result['executedTests'],256)
        self.assertEqual(result['explicitlySkippedTests'],2)


    def test_only_existing_opt_in_diagnostics_may_skip_without_gate_credit(self):
        for name, identity in hosted.DIAGNOSTIC_SKIPS.items():
            counts=hosted.summarize_log(f'Test "{name}" skipped.\nTest run with 1 test passed',
                                      'swift-testing',1,[identity])
            self.assertEqual(counts['executedTests'],0)
            self.assertEqual(counts['skippedIdentifiers'],[identity])
        for name in ['Combined live/long-horizon successor proof requires sealed current primary identity',
                     'New unexpected test']:
            with self.assertRaises(ValueError):
                hosted.summarize_log(f'Test "{name}" skipped.\nTest run with 1 test passed','swift-testing',1,[])

    def test_native_log_summary_requires_exact_framework_counts(self):
        self.assertEqual(hosted.summarize_log('Test "Legacy random mutation suppression" skipped.\nTest run with 3 tests passed', 'swift-testing',3,[hosted.RETIRED_SKIPS['Legacy random mutation suppression']]),
                         dict(reportedTests=3,explicitlySkippedTests=1,executedTests=2,skippedIdentifiers=[hosted.RETIRED_SKIPS['Legacy random mutation suppression']]))
        self.assertEqual(hosted.summarize_log('Executed 2 tests, with 0 failures', 'xctest',2,[])['executedTests'],2)
        for raw,library,count in [('build complete','swift-testing',1),('Test run with 1 test passed','swift-testing',2),
                                  ('Executed 1 test, with 1 failures','xctest',1),('Test run with 0 tests passed','swift-testing',0)]:
            with self.subTest(raw=raw),self.assertRaises(ValueError):hosted.summarize_log(raw,library,count,[])

    def record(self, raw):
        record=results.new_record('AT-0039');record['revision']=SOURCE
        record['gates'][2].update(status='passed',evidence=['Complete hosted native receipt'],
            limitation='Hosted macOS execution under the approved AT-0039 exception; no local execution claim.',execution=execution(raw))
        record['claim']['missingGates'].remove('full-local-verification')
        return record

    def test_only_authorized_item_gate_and_exact_revision_accept_execution(self):
        vocabulary=json.loads((Path(__file__).resolve().parents[1]/'docs/RESULT_STATUS_VOCABULARY.json').read_text())
        raw=json.dumps(fixture()).encode();record=self.record(raw)
        self.assertEqual(results.validate_record(record,vocabulary),[])
        for change in [lambda d:d.__setitem__('subject','AT-0040'),
                       lambda d:d.__setitem__('revision','b'*40),
                       lambda d:d['gates'][2]['execution'].__setitem__('environment','local'),
                       lambda d:d['gates'][2]['execution'].__setitem__('scope','focused'),
                       lambda d:d['gates'][2]['execution'].__setitem__('receipt','../elsewhere.json'),
                       lambda d:d['gates'][2].__setitem__('status','not-applicable'),
                       lambda d:d['gates'][0].__setitem__('execution',execution(raw))]:
            d=copy.deepcopy(record);change(d)
            self.assertTrue(results.validate_record(d,vocabulary))

    def test_bound_receipt_checks_bytes_and_complete_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);raw=json.dumps(fixture()).encode();record=self.record(raw);e=record['gates'][2]['execution']
            p=root/e['receipt'];p.parent.mkdir(parents=True);p.write_bytes(raw)
            self.assertEqual(hosted.validate_bound_receipt(root,record,e),[])
            p.write_bytes(raw+b' ')
            self.assertTrue(hosted.validate_bound_receipt(root,record,e))
            d=fixture();d['banks'].pop();raw=json.dumps(d).encode();p.write_bytes(raw);e['receiptSHA256']=hosted.sha(raw)
            self.assertTrue(hosted.validate_bound_receipt(root,record,e))

    def test_chunk_transport_is_lossless_and_rejects_partial_or_foreign_payloads(self):
        receipt=fixture()['banks'][0]['receipt'];stream=io.StringIO()
        with contextlib.redirect_stdout(stream):hosted.emit(receipt)
        text=stream.getvalue()
        self.assertEqual(hosted.decode_chunks(text,SOURCE,0),receipt)
        for bad,source,bank in [(text+text,SOURCE,0),(text,'f'*40,0),(text,SOURCE,1),('',SOURCE,0)]:
            with self.assertRaises(ValueError):hosted.decode_chunks(bad,source,bank)
        chunks=[json.loads(line) for line in text.splitlines()]
        chunks[0]['sha256']='f'*64
        with self.assertRaises(ValueError):hosted.decode_chunks('\n'.join(map(json.dumps,chunks)),SOURCE,0)
        for raw in ['{"bank":0,"bank":1}','{"count":NaN}','{"count":Infinity}']:
            with self.assertRaises(ValueError):hosted.strict_json(raw)

    def test_non_native_execution_refuses_before_running_commands(self):
        with mock.patch.object(hosted.platform,'system',return_value='Linux'),mock.patch.object(hosted.subprocess,'check_output') as call:
            with self.assertRaises(ValueError):hosted.run_bank(0,Path('/tmp/build'),Path('/tmp/output'))
            call.assert_not_called()

if __name__ == '__main__':unittest.main()
