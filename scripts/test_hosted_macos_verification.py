"""Synthetic receipt controls; fixture success is not hosted execution evidence."""
import copy
import contextlib
import gzip
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
import test_tooling_verification as tooling_tests
import test_native_build_provenance as build_tests

SOURCE = 'a' * 40


def fixture(include_retired=False):
    discovery = {library: '\n'.join(f'AutoTechnoCoreTests.OwnerTests/test{i}()' for i in range(128))
                 for library in ['xctest', 'swift-testing']}
    discovery['swift-testing'] += '\n' + '\n'.join(
        'AutoTechnoCoreTests.' + identity.split(':', 1)[1]
        for identity in hosted.ISOLATED_IDENTITIES)
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
        rows.append(dict(receipt=dict(schema='autotechno-hosted-macos-bank.v2', source=SOURCE,
             environment='hosted-macos', bank=bank, banks=hosted.BANKS, discovery=discovery, plan=plan, completedSlices=completed,
             buildProvenanceSHA256=hosted.native_build.record_digest(build_tests.fixture(SOURCE))),
             job=dict(id=100+bank, run_id=50, run_attempt=1, head_sha=SOURCE, name=f'hosted-macos / Complete macOS bank {bank}',
                      status='completed', conclusion='success', steps=[dict(name=n,status='completed',conclusion='success') for n in names])))
    for row in rows:
        row['originalLogSHA256'] = hosted.sha(native_log(row['receipt']))
    return dict(schema=hosted.SCHEMA,source=SOURCE,workflow=dict(id=20,path=hosted.WORKFLOW,state='active'),
                run=dict(id=50,workflow_id=20,run_attempt=1,head_sha=SOURCE,status='completed',conclusion='success',
                         event='workflow_dispatch',repository=dict(full_name='randomactions/auto-techno')),banks=rows)


def native_log(receipt, timestamped=False):
    """Synthetic original stdout paired with transport; never execution evidence."""
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream): hosted.native_build.emit(build_tests.fixture(receipt['source']))
    digest = receipt['buildProvenanceSHA256']
    lines = stream.getvalue().splitlines() + [f"BEGIN native build binding {receipt['bank']}:{digest}"]
    for result in receipt['completedSlices']:
        selected = result['selection']
        lines.append(f"BEGIN native slice {receipt['bank']}:{selected['library']}:{selected['suite']}")
        for identity in result['skippedIdentifiers']:
            name = next(name for name, case in hosted.ALLOWED_SKIPS.items() if case == identity)
            lines.append(f'Test "{name}" skipped.')
        count = result['reportedTests']
        lines.append(f'Executed {count} tests, with 0 failures' if selected['library'] == 'xctest'
                     else f'Test run with {count} tests passed')
    lines.append(f"END native build binding {receipt['bank']}:{digest}")
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        hosted.emit(receipt)
    lines.extend(stream.getvalue().splitlines())
    if receipt['bank'] == 0:
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            hosted.tooling.emit(tooling_tests.fixture(receipt['source']))
        lines.extend(stream.getvalue().splitlines())
    if timestamped:
        lines = ['2026-10-15T08:00:00.0000000Z ' + line for line in lines]
    return ('\n'.join(lines) + '\n').encode()


def execution(raw):
    return dict(schema=hosted.EXECUTION_SCHEMA,environment='hosted-macos',
                scope='complete-native-suites-and-release-build',revision=SOURCE,
                receipt='docs/local/result-records/AT-0039-hosted-macos.json',receiptSHA256=hosted.sha(raw))


def original_logs(bundle):
    return {row['receipt']['bank']: native_log(row['receipt']) for row in bundle['banks']}


class HostedMacOSVerificationTests(unittest.TestCase):
    def test_build_trace_is_not_independent_git_or_item_authority_without_explicit_join(self):
        bundle=fixture();logs=original_logs(bundle)
        result=hosted.verify(bundle,SOURCE,logs)
        self.assertTrue(result['originalVerboseBuildBindingsVerified'])
        self.assertFalse(result['compiledBuildClosureIndependentlyAuthenticated'])
        self.assertEqual(set(result['originalBuildBindings']),set(range(16)))
        git=build_tests.fixture()['trackedInputs']
        result=hosted.verify(bundle,SOURCE,logs,compiled_git=git)
        self.assertTrue(result['compiledBuildClosureIndependentlyAuthenticated'])
        self.assertFalse(result['automatedQualityQualification'])
        self.assertFalse(result['runtimeQualification'])
        self.assertFalse(result['item39Complete'])
        bad=dict(git);bad['Package.swift']='0'*64
        with self.assertRaises(ValueError):hosted.verify(bundle,SOURCE,logs,compiled_git=bad)

    def test_successful_build_step_without_original_trace_refuses(self):
        bundle=fixture();logs=original_logs(bundle);bank=0
        logs[bank]=b'\n'.join(line for line in logs[bank].splitlines() if hosted.native_build.CHUNK_SCHEMA.encode() not in line)+b'\n'
        bundle['banks'][bank]['originalLogSHA256']=hosted.sha(logs[bank])
        with self.assertRaisesRegex(ValueError,'original native build chunks required'):hosted.verify(bundle,SOURCE,logs)

    def test_native_build_binding_rejects_missing_duplicate_and_foreign_seals(self):
        for kind in ['missing','duplicate','foreign','late']:
            bundle=fixture();logs=original_logs(bundle);raw=logs[0]
            begin=next(line for line in raw.splitlines(keepends=True) if line.startswith(b'BEGIN native build binding '))
            if kind=='missing':raw=raw.replace(begin,b'')
            elif kind=='duplicate':raw=raw.replace(begin,begin+begin)
            elif kind=='foreign':raw=raw.replace(begin,begin.replace(b'0:',b'1:',1))
            else:raw=raw.replace(begin,b'')+begin
            logs[0]=raw;bundle['banks'][0]['originalLogSHA256']=hosted.sha(raw)
            with self.subTest(kind=kind),self.assertRaises(ValueError):hosted.verify(bundle,SOURCE,logs)

    def test_build_record_cannot_be_emitted_after_native_execution(self):
        bundle=fixture();logs=original_logs(bundle);raw=logs[0]
        lines=raw.splitlines(keepends=True);chunks=[line for line in lines if hosted.native_build.CHUNK_SCHEMA.encode() in line]
        raw=b''.join(line for line in lines if hosted.native_build.CHUNK_SCHEMA.encode() not in line)+b''.join(chunks)
        logs[0]=raw;bundle['banks'][0]['originalLogSHA256']=hosted.sha(raw)
        with self.assertRaisesRegex(ValueError,'sealed before native execution'):hosted.verify(bundle,SOURCE,logs)

    def test_legacy_v3_cannot_borrow_new_build_authority(self):
        bundle=fixture();bundle['schema']='autotechno-hosted-macos-verification.v3'
        with self.assertRaises(ValueError):hosted.verify(bundle,SOURCE,original_logs(bundle))

    def test_original_build_guard_refuses_before_discovery_or_benchmarks(self):
        record=build_tests.fixture();calls=[]
        def output(argv,**kwargs):
            calls.append(argv)
            if argv[0]=='git':return SOURCE if 'rev-parse' in argv else ''
            raise AssertionError('discovery/benchmark called after changed build')
        with mock.patch.object(hosted.platform,'system',return_value='Darwin'), \
             mock.patch.dict(hosted.os.environ,{'GITHUB_ACTIONS':'true','RUNNER_OS':'macOS','GITHUB_SHA':SOURCE}), \
             mock.patch.object(hosted.subprocess,'check_output',side_effect=output), \
             mock.patch.object(hosted,'bounded_regular',return_value=json.dumps(record).encode()), \
             mock.patch.object(hosted.native_build,'git_source_files',return_value=record['trackedInputs']), \
             mock.patch.object(hosted.native_build,'guard',side_effect=ValueError('changed original binary')), \
             mock.patch.object(hosted,'run_logged_native') as native, \
             mock.patch.object(hosted,'emit') as emit:
            with self.assertRaisesRegex(ValueError,'changed original binary'):
                hosted.run_bank(0,Path('/native-build'),Path('/never-created-output'),Path('/original-build.json'))
            native.assert_not_called();emit.assert_not_called()
        self.assertTrue(calls and all(argv[0]=='git' for argv in calls))

    def test_post_native_build_mutation_cannot_emit_a_bank_receipt(self):
        record=build_tests.fixture()
        with tempfile.TemporaryDirectory() as directory:
            def output(argv,**kwargs):
                if argv[0]=='git':return SOURCE if 'rev-parse' in argv else ''
                return 'AutoTechnoCoreTests.Fixture/test()'
            def native(command,root,log):
                log.write_bytes(b'Test run with 1 test passed\n')
                return hosted.subprocess.CompletedProcess(command,0)
            selection=dict(library='swift-testing',suite='Fixture',selector='literal',identifiers=['AutoTechnoCoreTests.Fixture/test()'])
            with mock.patch.object(hosted.platform,'system',return_value='Darwin'), \
                 mock.patch.dict(hosted.os.environ,{'GITHUB_ACTIONS':'true','RUNNER_OS':'macOS','GITHUB_SHA':SOURCE}), \
                 mock.patch.object(hosted.subprocess,'check_output',side_effect=output), \
                 mock.patch.object(hosted,'bounded_regular',return_value=json.dumps(record).encode()), \
                 mock.patch.object(hosted.native_build,'git_source_files',return_value=record['trackedInputs']), \
                 mock.patch.object(hosted.native_build,'guard',side_effect=[None,None,None,None,ValueError('post-native object drift')]), \
                 mock.patch.object(hosted,'plan',return_value={'selected':[selection]}), \
                 mock.patch.object(hosted,'run_logged_native',side_effect=native) as run, \
                 mock.patch.object(hosted,'emit') as emit,contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError,'post-native object drift'):
                    hosted.run_bank(0,Path('/native-build'),Path(directory)/'out',Path('/original-build.json'))
                self.assertEqual(run.call_count,1);emit.assert_not_called()

    def test_discovery_mutation_refuses_before_other_library_or_any_native_slice(self):
        record=build_tests.fixture();calls=[]
        with tempfile.TemporaryDirectory() as directory:
            def output(argv,**kwargs):
                calls.append(argv)
                if argv[0]=='git':return SOURCE if 'rev-parse' in argv else ''
                return 'AutoTechnoCoreTests.Fixture/test()'
            with mock.patch.object(hosted.platform,'system',return_value='Darwin'), \
                 mock.patch.dict(hosted.os.environ,{'GITHUB_ACTIONS':'true','RUNNER_OS':'macOS','GITHUB_SHA':SOURCE}), \
                 mock.patch.object(hosted.subprocess,'check_output',side_effect=output), \
                 mock.patch.object(hosted,'bounded_regular',return_value=json.dumps(record).encode()), \
                 mock.patch.object(hosted.native_build,'git_source_files',return_value=record['trackedInputs']), \
                 mock.patch.object(hosted.native_build,'guard',side_effect=[None,ValueError('discovery metadata drift')]), \
                 mock.patch.object(hosted,'run_logged_native') as native, \
                 mock.patch.object(hosted,'emit') as emit,contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError,'discovery metadata drift'):
                    hosted.run_bank(0,Path('/native-build'),Path(directory)/'out',Path('/original-build.json'))
                native.assert_not_called();emit.assert_not_called()
            discoveries=[row for row in calls if row[0]=='swift']
            self.assertEqual(discoveries,[['swift','test','-v','-Xswiftc','-save-temps','--build-path','/native-build','list','--skip-build','--enable-xctest','--disable-swift-testing']])

    def test_native_invocation_uses_same_original_build_options_and_selector(self):
        record=build_tests.fixture();commands=[]
        with tempfile.TemporaryDirectory() as directory:
            def output(argv,**kwargs):
                if argv[0]=='git':return SOURCE if 'rev-parse' in argv else ''
                commands.append(argv);return 'AutoTechnoCoreTests.Fixture/test()'
            def native(command,root,log):
                commands.append(command);log.write_bytes(b'Test run with 1 test passed\n')
                return hosted.subprocess.CompletedProcess(command,0)
            selection=dict(library='swift-testing',suite='Fixture',selector='literal',identifiers=['AutoTechnoCoreTests.Fixture/test()'])
            with mock.patch.object(hosted.platform,'system',return_value='Darwin'), \
                 mock.patch.dict(hosted.os.environ,{'GITHUB_ACTIONS':'true','RUNNER_OS':'macOS','GITHUB_SHA':SOURCE}), \
                 mock.patch.object(hosted.subprocess,'check_output',side_effect=output), \
                 mock.patch.object(hosted,'bounded_regular',return_value=json.dumps(record).encode()), \
                 mock.patch.object(hosted.native_build,'git_source_files',return_value=record['trackedInputs']), \
                 mock.patch.object(hosted.native_build,'guard') as guard, \
                 mock.patch.object(hosted,'plan',return_value={'selected':[selection]}), \
                 mock.patch.object(hosted,'run_logged_native',side_effect=native), \
                 mock.patch.object(hosted,'emit') as emit,contextlib.redirect_stdout(io.StringIO()):
                hosted.run_bank(0,Path('/native-build'),Path(directory)/'out',Path('/original-build.json'))
                self.assertEqual(guard.call_count,6);emit.assert_called_once()
            prefix=['swift','test','-v','-Xswiftc','-save-temps','--build-path','/native-build']
            self.assertEqual(commands,[prefix+['list','--skip-build','--enable-xctest','--disable-swift-testing'],
                prefix+['list','--skip-build','--disable-xctest','--enable-swift-testing'],
                prefix+['--skip-build','--no-parallel','--disable-xctest','--enable-swift-testing','--filter','literal']])

    def test_existing_full_workflow_owns_fresh_build_and_all_original_selectors(self):
        workflow=(Path(__file__).resolve().parents[1]/'.github/workflows/at0039-hosted-macos.yml').read_text()
        complete=workflow.split('  complete:\n',1)[1].split('  map:\n',1)[0]
        self.assertIn('--prepare-native-build',complete)
        self.assertIn('--build-provenance "$RUNNER_TEMP/at0039-native-build/build-provenance.json"',complete)
        self.assertIn('bank: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]',complete)
        self.assertIn('max-parallel: 4',complete)
        self.assertNotIn('--diagnostic-filter',complete)
        self.assertNotIn('--filter',complete)

    def test_complete_native_matrix_has_only_verification_scope(self):
        bundle = fixture(); result = hosted.verify(bundle, SOURCE, original_logs(bundle))
        self.assertEqual(result['discoveredTests'], 259)
        self.assertEqual(result['executedTests'], 259)
        self.assertTrue(result['completeNativeSuitesAndReleaseBuild'])
        self.assertTrue(result['originalJobLogsVerified'])
        self.assertTrue(result['completeToolingTestsVerified'])
        self.assertTrue(result['originalToolingOutputVerified'])
        self.assertEqual(result['toolingExecutedTests'], 2)
        self.assertEqual((result['run'],result['runAttempt'],result['banks']),(50,1,16))
        self.assertFalse(result['suiteFileHashesIndependentlyVerified'])
        for key in ['localExecution','automatedQualityQualification','runtimeQualification','item39Complete']:
            self.assertFalse(result[key])

    def test_successful_tooling_step_without_original_named_execution_refuses(self):
        bundle = fixture(); logs = original_logs(bundle)
        logs[0] = b'\n'.join(line for line in logs[0].splitlines()
                            if hosted.tooling.CHUNK_SCHEMA.encode() not in line) + b'\n'
        bundle['banks'][0]['originalLogSHA256'] = hosted.sha(logs[0])
        # All native banks, Release/map step statuses and successful tooling
        # step metadata remain intact; none replace the missing actual output.
        with self.assertRaisesRegex(ValueError, 'original tooling chunks required'):
            hosted.verify(bundle, SOURCE, logs)

    def test_generic_foreign_or_failed_tooling_cannot_borrow_complete_native_banks(self):
        invalid = [dict(source=SOURCE, passed=True),
                   dict(tooling_tests.fixture(), source='b'*40),
                   dict(tooling_tests.fixture(), exitCode=1),
                   dict(tooling_tests.fixture(), implementationSHA256='0'*64)]
        for record in invalid:
            bundle = fixture(); logs = original_logs(bundle)
            native = b'\n'.join(line for line in logs[0].splitlines()
                                if hosted.tooling.CHUNK_SCHEMA.encode() not in line) + b'\n'
            stream = io.StringIO()
            with contextlib.redirect_stdout(stream):
                hosted.tooling.emit(record)
            logs[0] = native + stream.getvalue().encode()
            bundle['banks'][0]['originalLogSHA256'] = hosted.sha(logs[0])
            with self.subTest(record=record.keys()), self.assertRaises(ValueError):
                hosted.verify(bundle, SOURCE, logs)

    def test_legacy_outer_receipt_cannot_claim_new_tooling_scope(self):
        bundle = fixture(); bundle['schema'] = 'autotechno-hosted-macos-verification.v2'
        with self.assertRaisesRegex(ValueError, 'exact source'):
            hosted.verify(bundle, SOURCE, original_logs(bundle))

    def test_full_bank_tooling_invokes_complete_original_runner(self):
        root = Path(__file__).resolve().parents[1]
        workflow = (root/'.github/workflows/at0039-hosted-macos.yml').read_text()
        body = workflow.split('- name: Run complete tooling tests\n', 1)[1].split('- name:', 1)[0]
        self.assertIn('if: matrix.bank == 0', body)
        self.assertIn('python3 scripts/tooling_verification.py --source "$GITHUB_SHA"', body)
        self.assertIn('--output "$RUNNER_TEMP/at0039-complete-tooling"', body)
        self.assertNotIn('--pattern', body)
        self.assertNotIn('--skip', body)

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
            hosted.verify(bundle, SOURCE, original_logs(bundle))

    def test_expensive_fixtures_have_dedicated_banks_without_losing_coverage(self):
        discovery = fixture()['banks'][0]['receipt']['discovery']
        heavy = 'AutoTechnoCoreTests.ModalSuccessorReportJoinTests/continuousCalibrationMembershipAndFitting()'
        second = 'AutoTechnoCoreTests.FoundationRhythmicRelationTests/algorithmicFullPhraseCompanionFaults()'
        third = 'AutoTechnoCoreTests.FoundationRhythmicRelationTests/algorithmicFullPhrasePumpBassFaults()'
        neighbors = [second, second.replace('Faults()', 'FaultsExtra()'), third,
                     third.replace('Faults()', 'FaultsExtra()'), heavy, heavy.replace('Fitting()', 'FittingExtra()'),
                     heavy.replace('JoinTests/', 'JoinTestsExtra/'),
                     heavy.replace('Fitting()', 'Fitting(rate:)')]
        discovery['swift-testing'] += '\n' + '\n'.join(
            case for case in neighbors if case not in discovery['swift-testing'].splitlines())
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

    def test_realistic_source_suffixes_isolate_all_three_fixtures_exactly(self):
        discovery = fixture()['banks'][0]['receipt']['discovery']
        discovery['swift-testing'] = '\n'.join(
            case + '/Fixture.swift:42:5' for case in discovery['swift-testing'].splitlines())
        actual = []
        for bank in range(hosted.BANKS):
            result = hosted.plan(discovery, bank, hosted.BANKS)
            cases = [row['library'] + ':' + case for row in result['selected']
                     for case in row['identifiers']]
            actual.extend(cases)
            if bank >= hosted.BANKS - len(hosted.ISOLATED_IDENTITIES):
                identity = hosted.ISOLATED_IDENTITIES[hosted.BANKS - 1 - bank]
                self.assertEqual(cases, [identity.replace(':', ':AutoTechnoCoreTests.', 1)
                                         + '/Fixture.swift:42:5'])
        expected = [lib + ':' + case for lib, text in discovery.items() for case in text.splitlines()]
        self.assertEqual(sorted(actual), sorted(expected))
        self.assertEqual(len(actual), len(set(actual)))

    def test_empty_producer_plan_refuses_before_native_or_receipt(self):
        record = build_tests.fixture()
        with tempfile.TemporaryDirectory() as directory:
            def output(argv, **kwargs):
                if argv[0] == 'git': return SOURCE if 'rev-parse' in argv else ''
                return 'AutoTechnoCoreTests.Fixture/test()'
            with mock.patch.object(hosted.platform, 'system', return_value='Darwin'), \
                 mock.patch.dict(hosted.os.environ, {'GITHUB_ACTIONS':'true', 'RUNNER_OS':'macOS', 'GITHUB_SHA':SOURCE}), \
                 mock.patch.object(hosted.subprocess, 'check_output', side_effect=output), \
                 mock.patch.object(hosted, 'bounded_regular', return_value=json.dumps(record).encode()), \
                 mock.patch.object(hosted.native_build, 'git_source_files', return_value=record['trackedInputs']), \
                 mock.patch.object(hosted.native_build, 'guard'), \
                 mock.patch.object(hosted, 'plan', return_value={'selected':[]}), \
                 mock.patch.object(hosted, 'run_logged_native') as native, \
                 mock.patch.object(hosted, 'emit') as emit, contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError, 'nonempty assigned native bank'):
                    hosted.run_bank(0, Path('/native-build'), Path(directory)/'out', Path('/original-build.json'))
                native.assert_not_called(); emit.assert_not_called()

    def test_skip_only_bank_cannot_replace_native_execution(self):
        receipt = copy.deepcopy(fixture()['banks'][0]['receipt'])
        identity = next(iter(hosted.RETIRED_SKIPS.values()))
        selection = dict(library='swift-testing', suite=identity.split('.')[1].split('/')[0],
                         selector='literal', bank=0, identifiers=[identity])
        receipt['plan']['selected'] = [selection]
        receipt['completedSlices'] = [dict(selection=selection, reportedTests=1,
            explicitlySkippedTests=1, executedTests=0, skippedIdentifiers=[identity],
            exitCode=0, logSHA256='b'*64)]
        with mock.patch.object(hosted, 'plan', return_value=receipt['plan']):
            with self.assertRaisesRegex(ValueError, 'nonempty native execution'):
                hosted.parse_bank(native_log(receipt), SOURCE, 0)

    def test_successful_empty_bank_receipt_cannot_supply_native_evidence(self):
        receipt = copy.deepcopy(fixture()['banks'][0]['receipt'])
        receipt['plan']['selected'] = []
        receipt['completedSlices'] = []
        # Even a self-consistent empty producer plan and original build seals
        # cannot replace a required native execution.
        with mock.patch.object(hosted, 'plan', return_value=receipt['plan']):
            with self.assertRaisesRegex(ValueError, 'nonempty assigned native bank'):
                hosted.parse_bank(native_log(receipt), SOURCE, receipt['bank'])

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
            with self.subTest(index=index),self.assertRaises(ValueError):hosted.verify(d,SOURCE,original_logs(d))

    def test_skips_do_not_become_executed_behavior(self):
        bundle=fixture(include_retired=True)
        result=hosted.verify(bundle,SOURCE,original_logs(bundle))
        self.assertEqual(result['executedTests'],259)
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
            root=Path(folder);bundle=fixture();raw=json.dumps(bundle).encode();record=self.record(raw);e=record['gates'][2]['execution']
            p=root/e['receipt'];p.parent.mkdir(parents=True);p.write_bytes(raw)
            self.assertTrue(hosted.validate_bound_receipt(root,record,e))
            logs=p.parent/(p.stem+'-logs');logs.mkdir()
            for bank,body in original_logs(bundle).items():
                (logs/f'bank-{bank}.log.gz').write_bytes(gzip.compress(body,mtime=0))
            self.assertEqual(hosted.validate_bound_receipt(root,record,e),[])
            p.write_bytes(raw+b' ')
            self.assertTrue(hosted.validate_bound_receipt(root,record,e))
            d=fixture();d['banks'].pop();raw=json.dumps(d).encode();p.write_bytes(raw);e['receiptSHA256']=hosted.sha(raw)
            self.assertTrue(hosted.validate_bound_receipt(root,record,e))

    def test_receipt_json_without_all_originals_cannot_claim_complete_hosted_verification(self):
        bundle=fixture();logs=original_logs(bundle)
        for missing in [None,{},dict(list(logs.items())[:-1])]:
            with self.subTest(missing=missing is None),self.assertRaisesRegex(ValueError,'original job logs'):
                hosted.verify(bundle,SOURCE,missing)
        old=copy.deepcopy(bundle);old['schema']='autotechno-hosted-macos-verification.v1'
        with self.assertRaisesRegex(ValueError,'bundle fields|exact source|schema'):
            hosted.verify(old,SOURCE,logs)
        for bank in logs:
            changed=copy.deepcopy(bundle);bad=dict(logs);bad[bank]=b'{"passed":true}'
            changed['banks'][bank]['originalLogSHA256']=hosted.sha(bad[bank])
            with self.subTest(bank=bank),self.assertRaises(ValueError):
                hosted.verify(changed,SOURCE,bad)

    def test_original_logs_and_native_receipts_cannot_be_substituted_or_resealed_partial(self):
        bundle=fixture();logs=original_logs(bundle)
        for mode in ['digest','missing-native','partial-summary','different-receipt','foreign-bank']:
            changed=copy.deepcopy(bundle);bad=dict(logs)
            if mode=='digest':bad[0]+=b'changed original'
            elif mode=='missing-native':
                stream=io.StringIO()
                with contextlib.redirect_stdout(stream):hosted.emit(changed['banks'][0]['receipt'])
                bad[0]=stream.getvalue().encode()
            elif mode=='partial-summary':bad[0]=bad[0].replace(b'Executed ',b'Missing ',1)
            elif mode=='different-receipt':
                changed['banks'][0]['receipt']['completedSlices'][0]['logSHA256']='d'*64
            else:bad[0]=logs[1]
            if mode!='digest':changed['banks'][0]['originalLogSHA256']=hosted.sha(bad[0])
            with self.subTest(mode=mode),self.assertRaises(ValueError):
                hosted.verify(changed,SOURCE,bad)

    def test_native_run_attempt_is_one_strict_shared_original_attempt(self):
        for boundary in ['run','job']:
            for attempt in [None,True,0,1.0,2]:
                bundle=fixture();target=bundle['run'] if boundary=='run' else bundle['banks'][0]['job']
                if attempt is None:target.pop('run_attempt')
                else:target['run_attempt']=attempt
                with self.subTest(boundary=boundary,attempt=attempt),self.assertRaises(ValueError):
                    hosted.verify(bundle,SOURCE,original_logs(bundle))

    def test_bound_original_archives_refuse_corruption_symlinks_and_oversize(self):
        for mode in ['missing','corrupt','symlink','directory-link','expanded-limit','changed-after-read']:
            with self.subTest(mode=mode),tempfile.TemporaryDirectory() as folder:
                root=Path(folder);bundle=fixture();raw=json.dumps(bundle).encode();record=self.record(raw);e=record['gates'][2]['execution']
                p=root/e['receipt'];p.parent.mkdir(parents=True);p.write_bytes(raw)
                directory=p.parent/(p.stem+'-logs');directory.mkdir()
                for bank,body in original_logs(bundle).items():
                    (directory/f'bank-{bank}.log.gz').write_bytes(gzip.compress(body,mtime=0))
                target=directory/'bank-0.log.gz'
                if mode=='missing':target.unlink()
                elif mode=='corrupt':target.write_bytes(b'invalid gzip')
                elif mode=='symlink':
                    other=target.with_name('other.gz');target.rename(other);target.symlink_to(other)
                elif mode=='directory-link':
                    other=directory.with_name('other');directory.rename(other);directory.symlink_to(other,target_is_directory=True)
                if mode=='expanded-limit':
                    target.write_bytes(gzip.compress(b'x'*1024,mtime=0))
                    with mock.patch.object(hosted,'MAX_LOG_BYTES',32):
                        self.assertIn('bounded original decompressed bytes',
                                      ' '.join(hosted.validate_bound_receipt(root,record,e)))
                elif mode=='changed-after-read':
                    real=hosted.verify
                    def mutate(*args):
                        result=real(*args);target.write_bytes(b'changed');return result
                    with mock.patch.object(hosted,'verify',side_effect=mutate):
                        self.assertTrue(hosted.validate_bound_receipt(root,record,e))
                else:self.assertTrue(hosted.validate_bound_receipt(root,record,e))

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
            collected=(out/'receipt.json').read_bytes();record=self.record(collected)
            binding=record['gates'][2]['execution'];root=Path(folder)/'bound'
            target=root/binding['receipt'];target.parent.mkdir(parents=True);target.write_bytes(collected)
            directory=target.parent/(target.stem+'-logs');directory.mkdir()
            for bank in range(hosted.BANKS):
                original=(out/f'bank-{bank}.log.gz').read_bytes()
                (directory/f'bank-{bank}.log.gz').write_bytes(original)
            self.assertEqual(hosted.validate_bound_receipt(root,record,binding),[])
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
            self.assertIn('register read sp fp pc lr x9', command)
            self.assertIn('image lookup --address $lr', command)
            self.assertIn("disassemble --start-address '$lr-32' --count 24", command)
            self.assertEqual(run.call_args.kwargs['timeout'], 900)
            self.assertIn('/Xcode/MacOSX.platform/Developer/usr/lib',
                          run.call_args.kwargs['env']['DYLD_LIBRARY_PATH'])
            emit.assert_not_called()

    def test_upper_color_component_is_exact_guarded_and_preserves_native_failure(self):
        import textwrap
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/at0039-hosted-macos.yml').read_text()
        self.assertIn('upper-color-stack-readiness', workflow)
        body = workflow.split("<<'PYUPPER'\n", 1)[1].split('          PYUPPER\n', 1)[0]
        code = compile(textwrap.dedent(body), '<upper-color-component>', 'exec')
        exact = 'AutoTechnoCoreTests.LongHorizonEnergyCoordinationTests/upperColorPreparedRecoveryPipeline()'
        for exit_code, raw in [(0, b'Test run with 1 test passed\n'),
                               (0, b'Test run with 0 tests passed\n'),
                               (1, b'assertion failure\n'),
                               (1, b'error: Exited with unexpected signal code 10\n')]:
            with self.subTest(exit_code=exit_code, raw=raw), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); build = root/'at0039-map'; output = root/'at0039-map-build'; output.mkdir()
                record = build_tests.fixture(SOURCE); record['buildPath'] = str(build); record['command'][-1] = str(build)
                def native(command, cwd, log):
                    self.assertEqual(command[:7], ['swift', 'test', '-v', '-Xswiftc', '-save-temps', '--build-path', str(build)])
                    selector = command[-1]
                    self.assertRegex(exact + '/LongHorizonEnergyCoordinationTests.swift:31:4', selector)
                    self.assertNotRegex(exact.replace('Pipeline()', 'PipelineExtra()'), selector)
                    self.assertNotRegex(exact.replace('CoordinationTests/', 'CoordinationTestsExtra/'), selector)
                    log.write_bytes(raw)
                    return hosted.subprocess.CompletedProcess(command, exit_code)
                with mock.patch.dict(os.environ, {'GITHUB_SHA':SOURCE, 'RUNNER_TEMP':directory}), \
                     mock.patch.object(Path, 'cwd', return_value=root), \
                     mock.patch.object(hosted, 'bounded_regular', return_value=json.dumps(record).encode()), \
                     mock.patch.object(hosted.native_build, 'git_source_files', return_value=record['trackedInputs']), \
                     mock.patch.object(hosted.native_build, 'validate') as validate, \
                     mock.patch.object(hosted.native_build, 'guard') as guard, \
                     mock.patch.object(hosted, 'run_logged_native', side_effect=native) as run, \
                     mock.patch.object(hosted, 'diagnose_crash', return_value=0) as debugger:
                    if exit_code == 0 and b'with 1 test passed' in raw:
                        exec(code, {})
                    else:
                        with self.assertRaises(ValueError): exec(code, {})
                    run.assert_called_once(); validate.assert_called_once(); self.assertEqual(guard.call_count, 2)
                    self.assertEqual(debugger.call_count, int(exit_code != 0 and b'unexpected signal code' in raw))
                    self.assertEqual((output/'upper-color-stack-original-native.log').read_bytes(), raw)

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

    def test_silent_build_transport_preserves_exact_original_failure_bytes(self):
        payload=b'verbose original compile trace\n'
        with tempfile.TemporaryDirectory() as directory:
            log=Path(directory)/'original.log';console=io.StringIO()
            with contextlib.redirect_stdout(console):
                result=hosted.run_logged_native([sys.executable,'-c',"import os,sys;os.write(1,"+repr(payload)+");sys.exit(1)"],Path(directory),log,console=False)
            self.assertEqual(result.returncode,1);self.assertEqual(log.read_bytes(),payload);self.assertEqual(console.getvalue(),'')

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

class HostedWorkflowDispatchRoutingTests(unittest.TestCase):
    """Exercise the registered gateway, not only the reusable workflow body."""
    alias = 'hosted-macos-upper-color-stack-readiness'
    scope = 'upper-color-stack-readiness'
    expected = {
        'complete-hosted-macos': 'complete',
        'hosted-macos-map': 'map-only',
        'hosted-macos-diagnostic': 'protected-continuation-diagnostic',
        'hosted-macos-harmonic-tail-diagnostic': 'harmonic-tail-diagnostic',
        **{'hosted-macos-' + name: name for name in (
            'primary-readiness', 'effect-dose-readiness', 'native-history-readiness',
            'calibration-diagnostic-readiness', 'calibration-fixture-readiness',
            'upper-color-stack-readiness')},
    }

    def setUp(self):
        root = Path(__file__).resolve().parents[1]
        self.gateway = (root / '.github/workflows/windows-distribution.yml').read_text()
        self.called = (root / '.github/workflows/at0039-hosted-macos.yml').read_text()
        self.jobs = dict(re.findall(r'^  ([a-z-]+):\n    if: ([^\n]+)', self.gateway, re.M))
        self.options = re.findall(r'^          - ([a-z-]+)$', self.gateway, re.M)

    def test_diagnostic_is_available_through_registered_gateway(self):
        self.assertEqual(self.options.count(self.alias), 1)
        self.assertIn('uses: ./.github/workflows/at0039-hosted-macos.yml', self.gateway)
        self.assertIn('  workflow_call:\n', self.called)
        self.assertIn(self.scope, self.called.split('        options: [', 1)[1].split(']', 1)[0].split(', '))

    def test_diagnostic_selects_only_hosted_job(self):
        selected = []
        for job, expression in self.jobs.items():
            terms = expression.split(' || ')
            for term in terms:
                self.assertRegex(term, r"^inputs\.validation == '[a-z-]*'$")
            if self.alias in [term.split("'")[1] for term in terms]:
                selected.append(job)
        self.assertEqual(selected, ['hosted-macos'])

    def test_every_hosted_mode_has_exact_scope_and_existing_modes_stay_bound(self):
        expression = re.search(r'^      scope: \$\{\{ (.+) \}\}$', self.gateway, re.M).group(1)
        terms = expression.split(' || ')
        self.assertEqual(terms.pop(), "'complete'")
        mappings = [re.fullmatch(r"inputs\.validation == '([a-z-]+)' && '([a-z-]+)'", term)
                    for term in terms]
        self.assertTrue(all(mappings))
        pairs = [match.groups() for match in mappings]
        self.assertEqual(len(pairs), len(dict(pairs)))
        self.assertEqual(dict(pairs), {key: value for key, value in self.expected.items()
                                      if key != 'complete-hosted-macos'})
        admitted = re.findall(r"inputs\.validation == '([a-z-]+)'", self.jobs['hosted-macos'])
        self.assertCountEqual(admitted, self.expected)
        self.assertTrue(set(self.expected) <= set(self.options))

    def test_diagnostic_cannot_select_complete_or_other_reusable_jobs(self):
        jobs = re.findall(r'^  ([a-z-]+):\n    if: ([^\n]+)', self.called, re.M)
        selected = [job for job, expression in jobs
                    if self.scope in re.findall(r"inputs\.scope == '([a-z-]+)'", expression)]
        self.assertEqual(selected, ['map'])
        self.assertEqual(self.called.count("        if: inputs.scope == 'upper-color-stack-readiness'"), 1)


if __name__ == '__main__':unittest.main()
