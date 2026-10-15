"""Synthetic receipt controls; fixture success is not hosted execution evidence."""
import copy
import contextlib
import io
import json
import os
import re
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
    for bank in range(hosted.BANKS):
        plan = hosted.plan(discovery, bank, hosted.BANKS)
        completed = [dict(selection=s, reportedTests=len(s['identifiers']), explicitlySkippedTests=0,
                          executedTests=len(s['identifiers']), skippedIdentifiers=[], exitCode=0, logSHA256='b'*64) for s in plan['selected']]
        for result in completed:
            selected=result['selection']
            skipped=sorted(set(selected['identifiers']) & set(hosted.RETIRED_SKIPS.values())) if selected['library']=='swift-testing' else []
            result.update(skippedIdentifiers=skipped,explicitlySkippedTests=len(skipped),executedTests=result['reportedTests']-len(skipped))
        names = ['Verify macOS environment', 'Build all native tests', 'Execute complete native bank']
        if bank == 0: names += ['Run complete tooling tests', 'Build macOS Release app', 'Validate codebase map']
        rows.append(dict(receipt=dict(schema='autotechno-hosted-macos-bank.v1', source=SOURCE,
             environment='hosted-macos', bank=bank, banks=hosted.BANKS, discovery=discovery, plan=plan, completedSlices=completed),
             job=dict(id=100+bank, run_id=50, head_sha=SOURCE, name=f'hosted-macos / Complete macOS bank {bank}',
                      status='completed', conclusion='success', steps=[dict(name=n,status='completed',conclusion='success') for n in names])))
    return dict(schema=hosted.SCHEMA,source=SOURCE,workflow=dict(id=20,path=hosted.WORKFLOW,state='active'),
                run=dict(id=50,workflow_id=20,head_sha=SOURCE,status='completed',conclusion='success',
                         event='workflow_dispatch',repository=dict(full_name='randomactions/auto-techno')),banks=rows)


def native_log(receipt, timestamped=False):
    """Synthetic original stdout paired with transport; never execution evidence."""
    lines = []
    for result in receipt['completedSlices']:
        selected = result['selection']
        lines.append(f"BEGIN native slice {receipt['bank']}:{selected['library']}:{selected['suite']}")
        for identity in result['skippedIdentifiers']:
            name = next(name for name, case in hosted.ALLOWED_SKIPS.items() if case == identity)
            lines.append(f'Test "{name}" skipped.')
        count = result['reportedTests']
        lines.append(f'Executed {count} tests, with 0 failures' if selected['library'] == 'xctest'
                     else f'Test run with {count} tests passed')
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        hosted.emit(receipt)
    lines.extend(stream.getvalue().splitlines())
    if timestamped:
        lines = ['2026-10-15T08:00:00.0000000Z ' + line for line in lines]
    return ('\n'.join(lines) + '\n').encode()


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

    def test_native_history_components_cover_the_same_disjoint_test_identities(self):
        root = Path(__file__).resolve().parents[1]
        workflow = (root / '.github/workflows/at0039-hosted-macos.yml').read_text()
        filters = dict(re.findall(r"^            ([a-z-]+)\) filter='([^']+)';;", workflow, re.M))
        self.assertEqual(set(filters), {'policy', 'successor', 'live-successor', 'projection'})
        source = (root / 'Tests/AutoTechnoCoreTests/LongHorizonProfessionalPolicyTests.swift').read_text()
        identities = ['AutoTechnoCoreTests.LongHorizonProfessionalPolicyTests/' + name + '()'
                      for name in re.findall(r'^  func (\w+)\(', source, re.M)]
        identities += ['AutoTechnoCoreTests.ProspectiveSuccessorRequestTests/' + name + '()'
                       for name in ['canonicalPreparedSuccessorContext', 'canonicalPreparedLiveSuccessorContext']]
        identities += ['AutoTechnoCoreTests.ModalSuccessorReportJoinTests/preparedValidationLongHorizonProjection()']
        self.assertEqual(len(identities), 21)
        counts = {key: 0 for key in filters}
        for identity in identities:
            owners = [key for key, pattern in filters.items() if re.search(pattern, identity)]
            self.assertEqual(len(owners), 1, identity)
            counts[owners[0]] += 1
            self.assertRegex(identity.replace('/', '.'), filters[owners[0]])
            self.assertRegex(identity + '/TestFile.swift:1:1', filters[owners[0]])
        self.assertEqual(counts, dict(policy=18, successor=1, **{'live-successor': 1}, projection=1))
        for identity in ['AutoTechnoCoreTests.LongHorizonProfessionalPolicyTestsExtra/unrelated()',
                         'AutoTechnoCoreTests.ProspectiveSuccessorRequestTests/canonicalPreparedSuccessorContextExtra()',
                         'AutoTechnoCoreTests.ModalSuccessorReportJoinTests/unrelated()']:
            self.assertFalse(any(re.search(pattern, identity) for pattern in filters.values()))
        self.assertIn('["policy","successor","live-successor","projection"]', workflow)
        self.assertIn("inputs.scope == 'native-history-readiness' && 180 || 90", workflow)
        self.assertIn('fail-fast: false', workflow)

    def test_calibration_component_preserves_native_failure_after_debugger_replay(self):
        import os
        import subprocess
        import textwrap
        root = Path(__file__).resolve().parents[1]
        workflow = (root / '.github/workflows/at0039-hosted-macos.yml').read_text()
        body = workflow.split("PYTHONPATH=scripts python3 - <<'PYTHON'\n", 1)[1].split(
            '          PYTHON\n', 1)[0]
        code = compile(textwrap.dedent(body), '<calibration-component>', 'exec')
        source = (root / 'Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationTests.swift').read_text()
        for exit_code, raw in [(0, b'native success\n'), (1, b'assertion failure\n'),
                               (10, b'Exited with unexpected signal code 10\n')]:
            with tempfile.TemporaryDirectory() as directory:
                def run(command, cwd, log):
                    self.assertIn('--no-parallel', command)
                    self.assertIn('--skip-build', command)
                    selector = command[command.index('--filter') + 1]
                    selected = [name for name in re.findall(r'^    func (\w+)\(', source, re.M)
                                if re.search(selector, 'ProfessionalQualityCalibrationTests/' + name + '()')]
                    self.assertEqual(len(selected), 20)
                    self.assertIn('dottedRhythmCrestPopulationAcrossCandidates', selected)
                    self.assertIn('kickFoundationPairingPopulationProjectionAcrossCandidates', selected)
                    for name in ['modalEventPopulationProjectionAcrossCandidates',
                                 'padPopulationProjectionsAcrossCandidates',
                                 'preparationEvaluatorAvailability',
                                 'activeSpectralRevealProjectionMatchesEvidence',
                                 'spectralRevealPopulationAcrossCandidates']:
                        self.assertIn(name, selected)
                    log.write_bytes(raw)
                    return subprocess.CompletedProcess(command, exit_code)
                with mock.patch.dict(os.environ, RUNNER_TEMP=directory), \
                     mock.patch.object(hosted, 'run_logged_native', side_effect=run) as native, \
                     mock.patch.object(hosted, 'diagnose_crash', return_value=0) as debugger:
                    if exit_code == 0:
                        exec(code, {})
                    else:
                        with self.assertRaisesRegex(ValueError, 'native slice failed'):
                            exec(code, {})
                    native.assert_called_once()
                    self.assertEqual(debugger.call_count, int(exit_code == 10))
                    self.assertEqual((Path(directory) / 'calibration-fixture-native.log').read_bytes(), raw)

    def test_timeout_repartition_preserves_complete_identity_union(self):
        bundle = fixture()
        discovery = bundle['banks'][0]['receipt']['discovery']
        def identities(banks):
            return [selection['library'] + ':' + identifier
                    for bank in range(banks)
                    for selection in hosted.plan(discovery, bank, banks)['selected']
                    for identifier in selection['identifiers']]
        previous, current = identities(8), identities(hosted.BANKS)
        self.assertEqual(hosted.BANKS, 16)
        self.assertEqual(sorted(previous), sorted(current))
        self.assertEqual(len(current), len(set(current)))
        workflow = (Path(__file__).resolve().parents[1] /
                    '.github/workflows/at0039-hosted-macos.yml').read_text()
        self.assertIn('bank: ' + str(list(range(hosted.BANKS))), workflow)
        self.assertIn('max-parallel: 4', workflow)
        bundle['banks'] = bundle['banks'][:8]
        with self.assertRaisesRegex(ValueError, 'all sixteen banks'):
            hosted.verify(bundle, SOURCE)

    def test_expensive_fixtures_have_dedicated_banks_without_losing_coverage(self):
        discovery = fixture()['banks'][0]['receipt']['discovery']
        heavy = 'AutoTechnoCoreTests.ModalSuccessorReportJoinTests/continuousCalibrationMembershipAndFitting()'
        second = 'AutoTechnoCoreTests.FoundationRhythmicRelationTests/algorithmicFullPhraseCompanionFaults()'
        third = 'AutoTechnoCoreTests.FoundationRhythmicRelationTests/algorithmicFullPhrasePumpBassFaults()'
        neighbors = [second, second.replace('Faults()', 'FaultsExtra()'), third,
                     third.replace('Faults()', 'FaultsExtra()'), heavy, heavy.replace('Fitting()', 'FittingExtra()'),
                     heavy.replace('JoinTests/', 'JoinTestsExtra/'),
                     heavy.replace('Fitting()', 'Fitting(rate:)')]
        discovery['swift-testing'] += '\n' + '\n'.join(neighbors)
        expected = sorted(library + ':' + identity for library, text in discovery.items()
                          for identity in text.splitlines())
        actual = []
        for bank in range(hosted.BANKS):
            result = hosted.plan(discovery, bank, hosted.BANKS)
            identities = [row['library'] + ':' + identity for row in result['selected']
                          for identity in row['identifiers']]
            actual.extend(identities)
            if bank == hosted.BANKS - 1:
                self.assertEqual(identities, ['swift-testing:' + heavy])
            elif bank == hosted.BANKS - 2:
                self.assertEqual(identities, ['swift-testing:' + second])
            elif bank == hosted.BANKS - 3:
                self.assertEqual(identities, ['swift-testing:' + third])
            else:
                self.assertNotIn('swift-testing:' + heavy, identities)
                self.assertNotIn('swift-testing:' + second, identities)
                self.assertNotIn('swift-testing:' + third, identities)
            for row in result['selected']:
                matched = [case for case in discovery[row['library']].splitlines()
                           if re.search(row['selector'], case)]
                self.assertEqual(sorted(matched), row['identifiers'])
            reversed_discovery = {key: '\n'.join(reversed(value.splitlines()))
                                  for key, value in discovery.items()}
            self.assertEqual(result, hosted.plan(reversed_discovery, bank, hosted.BANKS))
        self.assertEqual(sorted(actual), expected)
        self.assertEqual(len(actual), len(set(actual)))

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

    def test_allocation_process_diagnostic_skip_requires_exact_opt_in_identity(self):
        name = 'Inspect a single actual streamed chain without an ordinary reference or owner snapshots'
        identity = 'AutoTechnoCoreTests.IterativeSuccessorPreparationTests/selectedStreamAllocationProcess()'
        source = (Path(__file__).resolve().parents[1] /
                  'Tests/AutoTechnoCoreTests/PhrasePreparationReplayIdentityTests.swift').read_text()
        self.assertRegex(source, re.escape('@Test("' + name + '",') +
                         r'\s*\.enabled\(if: ProcessInfo\.processInfo\.environment\[' +
                         r'"AUTOTECHNO_RUN_STREAM_ALLOCATION_INSPECTION"\] == "1"\)\)' +
                         r'\s*@MainActor\s*func selectedStreamAllocationProcess\(\)')
        raw = f'Test "{name}" skipped.\nTest run with 1 test passed'
        self.assertEqual(hosted.summarize_log(raw, 'swift-testing', 1, [identity]),
                         dict(reportedTests=1, explicitlySkippedTests=1, executedTests=0,
                              skippedIdentifiers=[identity]))
        for changed, identifiers in [(raw.replace(name, name + ' extra'), [identity]),
                                     (raw, [identity.replace('Process()', 'ProcessExtra()')]),
                                     (raw, []),
                                     (f'Test "{name}" skipped.\n' + raw, [identity])]:
            with self.subTest(raw=changed, identifiers=identifiers), self.assertRaises(ValueError):
                hosted.summarize_log(changed, 'swift-testing', 1, identifiers)

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

    def test_collection_binds_live_job_logs_and_refuses_changed_run(self):
        bundle=fixture()
        def response(command,**kwargs):
            path=command[-1]
            if path.endswith('/runs/50'): return json.dumps(bundle['run']).encode()
            if path.endswith('/workflows/20'): return json.dumps(bundle['workflow']).encode()
            if '/jobs?' in path:
                return json.dumps(dict(total_count=hosted.BANKS,jobs=[r['job'] for r in bundle['banks']])).encode()
            job=int(path.split('/')[-2])
            return native_log(bundle['banks'][job-100]['receipt'], timestamped=True)
        with tempfile.TemporaryDirectory() as folder,mock.patch.object(hosted.subprocess,'check_output',side_effect=response):
            out=Path(folder)/'complete'
            self.assertTrue(hosted.collect(50,SOURCE,out)['completeNativeSuitesAndReleaseBuild'])
            self.assertEqual(len(list(out.glob('bank-*.log.gz'))),hosted.BANKS)
            with self.assertRaises(ValueError):hosted.collect(50,SOURCE,out)
            def receipt_only(command, **kwargs):
                if command[-1].endswith('/logs'):
                    job = int(command[-1].split('/')[-2]); stream = io.StringIO()
                    with contextlib.redirect_stdout(stream):
                        hosted.emit(bundle['banks'][job-100]['receipt'])
                    return stream.getvalue().encode()
                return response(command, **kwargs)
            with mock.patch.object(hosted.subprocess, 'check_output', side_effect=receipt_only):
                with self.assertRaisesRegex(ValueError, 'original native boundaries'):
                    hosted.collect(50, SOURCE, Path(folder)/'receipt-only')
                self.assertFalse((Path(folder)/'receipt-only').exists())
            calls=0
            def moved(command,**kwargs):
                nonlocal calls
                value=response(command,**kwargs)
                if command[-1].endswith('/runs/50'):
                    calls+=1
                    if calls>1:
                        d=json.loads(value);d['run_attempt']=2;value=json.dumps(d).encode()
                return value
            with mock.patch.object(hosted.subprocess,'check_output',side_effect=moved):
                with self.assertRaises(ValueError):hosted.collect(50,SOURCE,Path(folder)/'moved')
                self.assertFalse((Path(folder)/'moved').exists())

    def test_original_native_summaries_and_receipt_must_agree(self):
        receipt = fixture()['banks'][0]['receipt']
        expected = sum(row['executedTests'] for row in receipt['completedSlices'])
        for timestamped in [False, True]:
            decoded, counts = hosted.parse_bank(native_log(receipt, timestamped), SOURCE, 0)
            self.assertEqual(decoded, receipt)
            self.assertEqual(counts, dict(executedTests=expected, explicitlySkippedTests=0))
        total_skips = 0
        for row in fixture(include_retired=True)['banks']:
            receipt = row['receipt']
            decoded, counts = hosted.parse_bank(native_log(receipt), SOURCE, receipt['bank'])
            self.assertEqual(decoded, receipt)
            total_skips += counts['explicitlySkippedTests']
        self.assertEqual(total_skips, 2)

    def test_receipt_only_or_altered_native_summaries_cannot_supply_execution(self):
        receipt = fixture()['banks'][0]['receipt']; raw = native_log(receipt)
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            hosted.emit(receipt)
        changes = [stream.getvalue().encode(), b'',
                   raw.replace(b'Executed ', b'Missing ', 1),
                   raw.replace(b'with 0 failures', b'with 1 failures', 1),
                   raw.replace(b'BEGIN native slice 0:', b'BEGIN native slice 1:', 1),
                   b'BEGIN native slice 0:foreign:Suite\n' + raw,
                   raw + b'BEGIN native slice 0:foreign:Suite\n',
                   raw.replace(b'BEGIN native slice', b'ABSENT native slice', 1),
                   raw.replace(b'Executed ', b'Missing ', 1) + b'Executed 8 tests, with 0 failures\n']
        altered = copy.deepcopy(receipt); altered['completedSlices'][0]['executedTests'] += 1
        changes.append(native_log(altered))
        altered = copy.deepcopy(receipt); altered['completedSlices'][0]['exitCode'] = False
        changes.append(native_log(altered))
        altered = copy.deepcopy(receipt); altered['plan']['selected'][0]['selector'] = '.*'
        changes.append(native_log(altered))
        for index, bad in enumerate(changes):
            with self.subTest(index=index), self.assertRaises(ValueError):
                hosted.parse_bank(bad, SOURCE, 0)
        for source, bank in [('f'*40, 0), (SOURCE, 1), (SOURCE, True)]:
            with self.subTest(source=source, bank=bank), self.assertRaises(ValueError):
                hosted.parse_bank(raw, source, bank)

    def test_debugger_replay_is_bounded_literal_and_has_no_receipt(self):
        selector = 'IterativeSuccessorPreparationTests[/.]protectedBoundaryRefusal'
        with mock.patch.object(hosted.platform, 'system', return_value='Darwin'), \
             mock.patch.dict(hosted.os.environ, {'GITHUB_ACTIONS':'true', 'RUNNER_OS':'macOS'}, clear=True), \
             mock.patch.object(hosted.subprocess, 'check_output', side_effect=[
                 '/tmp/build/debug', '/Xcode/usr/bin/swift', '/Xcode/MacOSX.platform']), \
             mock.patch.object(hosted.subprocess, 'run', return_value=mock.Mock(returncode=9)) as run, \
             mock.patch.object(hosted, 'emit') as emit:
            self.assertEqual(hosted.diagnose_crash(Path('/tmp/build'), selector), 9)
            command = run.call_args.args[0]
            self.assertEqual(command[command.index('--filter')+1], selector)
            self.assertIn('--no-lldbinit', command)
            self.assertIn('process launch --shell-expand-args false', command)
            self.assertIn('thread backtrace --count 40 all', command)
            self.assertEqual(run.call_args.kwargs['timeout'], 900)
            self.assertIn('/Xcode/MacOSX.platform/Developer/usr/lib',
                          run.call_args.kwargs['env']['DYLD_LIBRARY_PATH'])
            emit.assert_not_called()

    def test_diagnostic_execution_refuses_non_hosted_environment(self):
        with mock.patch.object(hosted.platform,'system',return_value='Darwin'), \
             mock.patch.dict(hosted.os.environ,{},clear=True), \
             mock.patch.object(hosted.subprocess,'check_output') as call:
            with self.assertRaises(ValueError):hosted.diagnose_crash(Path('/tmp/build'),'test')
            call.assert_not_called()

    def test_crash_diagnostic_cannot_replace_native_failure(self):
        for outcome in [0, 9, hosted.subprocess.TimeoutExpired('lldb', 900), OSError('missing debugger')]:
            with self.subTest(outcome=outcome), mock.patch.object(hosted, 'diagnose_crash') as diagnostic:
                if isinstance(outcome, Exception):diagnostic.side_effect = outcome
                else:diagnostic.return_value = outcome
                with self.assertRaisesRegex(ValueError, '^native slice failed$'):
                    hosted.require_native_success(mock.Mock(returncode=1),
                        b'error: Exited with unexpected signal code 10', 'swift-testing', Path('/tmp/build'), 'Suite')
                diagnostic.assert_called_once_with(Path('/tmp/build'), 'Suite')

    def test_success_and_ordinary_failures_do_not_replay(self):
        with mock.patch.object(hosted, 'diagnose_crash') as diagnostic:
            hosted.require_native_success(mock.Mock(returncode=0), b'passed', 'swift-testing', Path('/tmp/build'), 'Suite')
            for raw, library in [(b'assertion failed','swift-testing'),
                                  (b'Exited with unexpected signal code 10','xctest')]:
                with self.assertRaisesRegex(ValueError, '^native slice failed$'):
                    hosted.require_native_success(mock.Mock(returncode=1), raw, library, Path('/tmp/build'), 'Suite')
            diagnostic.assert_not_called()

    def test_native_progress_is_visible_before_exit_and_exact_bytes_are_retained(self):
        for code in [0, 7]:
            with self.subTest(code=code), tempfile.TemporaryDirectory() as directory:
                log = Path(directory) / 'native.log'; console = io.StringIO()
                process = mock.MagicMock(); chunks = [b'begin\n\xe2', b'\x9c\x93 done\n', b'']
                consumed = bytearray()
                def read(size):
                    self.assertEqual(size, 64 * 1024)
                    if consumed:
                        self.assertEqual(log.read_bytes(), bytes(consumed))
                        self.assertIn('begin\n', console.getvalue())
                    chunk = chunks.pop(0); consumed.extend(chunk); return chunk
                process.stdout.read1.side_effect = read
                process.wait.side_effect = lambda: (self.assertEqual(console.getvalue(), 'begin\n✓ done\n') or code)
                process.__enter__.return_value = process
                command = ['swift', 'test', '--filter', 'literal.selector()']
                with mock.patch.object(hosted.subprocess, 'Popen', return_value=process) as spawn, \
                     mock.patch.object(hosted.sys, 'stdout', console), mock.patch.object(hosted, 'emit') as emit:
                    result = hosted.run_logged_native(command, Path(directory), log)
                self.assertEqual(result.returncode, code)
                self.assertEqual(result.args, command)
                self.assertEqual(log.read_bytes(), b'begin\n\xe2\x9c\x93 done\n')
                spawn.assert_called_once_with(command, cwd=Path(directory),
                    stdout=hosted.subprocess.PIPE, stderr=hosted.subprocess.STDOUT)
                emit.assert_not_called()

    def test_focused_windows_utf8_environment_preserves_unicode_and_raw_bytes(self):
        # Real Python console processes, not a native Swift test or qualification receipt.
        payload = "\u25ca diagnostic output; \u2714 original bytes\n".encode('utf-8')
        code = ("import sys; from pathlib import Path; "
                "sys.path.insert(0, sys.argv[2]); import hosted_macos_verification as h; "
                "result=h.run_logged_native([sys.executable,'-c',sys.argv[3]], Path.cwd(), Path(sys.argv[1])); "
                "raise SystemExit(result.returncode)")
        producer = "import os; os.write(1," + repr(payload) + ")"
        with tempfile.TemporaryDirectory() as directory:
            for encoding, expected in [('cp1252', False), ('utf-8', True)]:
                log = Path(directory)/(encoding+'.log')
                result = hosted.subprocess.run([sys.executable,'-c',code,str(log),
                    str(Path(__file__).resolve().parent),producer],
                    env=dict(os.environ,PYTHONIOENCODING=encoding),stdout=hosted.subprocess.PIPE,
                    stderr=hosted.subprocess.PIPE,timeout=30)
                self.assertEqual(log.read_bytes(),payload)
                if expected:
                    self.assertEqual(result.returncode,0,result.stderr.decode('utf-8','replace'))
                    self.assertEqual(result.stdout,payload)
                else:
                    self.assertNotEqual(result.returncode,0)
                    self.assertIn(b'UnicodeEncodeError',result.stderr)

    def test_non_native_execution_refuses_before_running_commands(self):
        with mock.patch.object(hosted.platform,'system',return_value='Linux'),mock.patch.object(hosted.subprocess,'check_output') as call:
            with self.assertRaises(ValueError):hosted.run_bank(0,Path('/tmp/build'),Path('/tmp/output'))
            call.assert_not_called()

if __name__ == '__main__':unittest.main()
