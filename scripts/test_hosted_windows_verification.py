"""Synthetic verifier controls; fixture success is never native execution evidence."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hosted_windows_verification as hosted
from hosted_macos_verification import ALLOWED_SKIPS

SOURCE = 'a' * 40


def fixture(with_skip=False, allocation_diagnostic=False):
    discovery = {library: '\n'.join(f'AutoTechnoCoreTests.OwnerTests/test{i}()' for i in range(64))
                 for library in ('xctest', 'swift-testing')}
    if with_skip:
        discovery['swift-testing'] += '\n' + next(iter(ALLOWED_SKIPS.values()))
    if allocation_diagnostic:
        discovery['swift-testing'] += '\nAutoTechnoCoreTests.IterativeSuccessorPreparationTests/selectedStreamAllocationProcess()'
    rows, logs = [], {}
    for bank in range(hosted.BANKS):
        selected = hosted.plan(discovery, bank, hosted.BANKS)
        output = [json.dumps(selected)]
        completed = []
        for s in selected['selected']:
            key = f'{s["library"]}:{s["suite"]}'
            output.append(f'BEGIN native suite slice {key}, bank {bank}/8')
            skip_names = [name for name, identifier in ALLOWED_SKIPS.items()
                          if identifier in s['identifiers'] and s['library'] == 'swift-testing']
            output += [f'↷ Test "{name}" skipped.' for name in skip_names]
            count = len(s['identifiers'])
            output.append(f'Executed {count} tests, with 0 failures' if s['library'] == 'xctest' else
                          f'✔ Test run with {count} tests passed after 0.1 seconds.')
            output.append(f'END native suite slice {key}')
            completed.append(dict(library=s['library'], suite=s['suite'], identifiers=s['identifiers'],
                                  selector=s['selector'], discovered=count, reportedTests=count,
                                  explicitlySkippedTests=len(skip_names), executedTests=count-len(skip_names),
                                  logSHA256='b'*64, exitCode=0))
        result = dict(schema='autotechno-windows-test-bank-result.v2', source=SOURCE, bank=bank, banks=8,
                      discoverySHA256=selected['discoverySHA256'], discoveredIdentifiers=selected['discoveredIdentifiers'],
                      partitionUnit=selected['partitionUnit'], completedSlices=completed, fullWindowsQualification=False)
        output.append(json.dumps(result))
        logs[bank] = ('\n'.join('2026-10-14T00:00:00.0000000Z ' + line for line in output) + '\n').encode()
        job = dict(id=100+bank, run_id=50, run_attempt=1, head_sha=SOURCE,
                   name=f'Windows x64 source validation (bank-{bank})', status='completed', conclusion='success',
                   steps=[dict(name=n, status='completed', conclusion='success') for n in hosted.required_steps(bank)])
        rows.append(dict(bank=bank, job=job, logSHA256=hosted.sha(logs[bank])))
    bundle = dict(schema=hosted.SCHEMA, source=SOURCE, banks=rows,
                  workflow=dict(id=20, path=hosted.WORKFLOW, state='active'),
                  run=dict(id=50, run_attempt=1, workflow_id=20, head_sha=SOURCE, status='completed',
                           conclusion='success', event='workflow_dispatch', repository=dict(full_name='randomactions/auto-techno')))
    return bundle, logs


def replace_record(bundle, logs, schema, mutate, bank=0):
    value = hosted.records(logs[bank].decode(), schema)
    original = json.dumps(value)
    mutate(value)
    logs[bank] = logs[bank].replace(original.encode(), json.dumps(value).encode())
    bundle['banks'][bank]['logSHA256'] = hosted.sha(logs[bank])


class HostedWindowsVerificationTests(unittest.TestCase):
    def test_complete_source_verification_has_no_runtime_authority(self):
        bundle, logs = fixture()
        result = hosted.verify(bundle, SOURCE, logs)
        self.assertEqual(result['discoveredTests'], 128)
        self.assertEqual(result['executedTests'], 128)
        self.assertTrue(result['originalJobLogsVerified'])
        self.assertTrue(result['completeNativeSuitesAndReleaseBuild'])
        for key in ('suiteFileHashesIndependentlyVerified', 'runtimeQualification',
                    'automatedQualityQualification', 'item39Complete'):
            self.assertFalse(result[key])

    def test_only_named_existing_skips_are_separate_from_execution(self):
        bundle, logs = fixture(with_skip=True)
        result = hosted.verify(bundle, SOURCE, logs)
        self.assertEqual(result['executedTests'], 128)
        self.assertEqual(result['explicitlySkippedTests'], 1)
        self.assertEqual(result['discoveredTests'], 129)

    def test_allocation_diagnostic_skip_supplies_no_execution_or_quality_credit(self):
        bundle, logs = fixture(allocation_diagnostic=True)
        result = hosted.verify(bundle, SOURCE, logs)
        self.assertEqual((result['discoveredTests'], result['executedTests'],
                          result['explicitlySkippedTests']), (129, 128, 1))
        for key in ('runtimeQualification', 'automatedQualityQualification', 'item39Complete'):
            self.assertFalse(result[key])
        for bank, raw in logs.items():
            if b'Inspect a single actual streamed chain' in raw:
                replace_record(bundle, logs, 'autotechno-windows-test-bank-result.v2',
                               lambda row: next(s for s in row['completedSlices']
                                                if s['explicitlySkippedTests']).update(executedTests=1), bank)
                with self.assertRaises(ValueError):
                    hosted.verify(bundle, SOURCE, logs)
                break
        else:
            self.fail('allocation diagnostic was not selected and explicitly skipped')

    def test_powershell_line_leading_bom_preserves_original_log_binding(self):
        bundle, logs = fixture()
        logs[0] = logs[0].replace(b'\n2026', b'\n\xef\xbb\xbf2026')
        bundle['banks'][0]['logSHA256'] = hosted.sha(logs[0])
        self.assertEqual(hosted.verify(bundle, SOURCE, logs)['executedTests'], 128)

    def test_failed_partial_foreign_mixed_attempt_or_missing_release_refuse(self):
        changes = [lambda b:b['banks'].pop(), lambda b:b['banks'].__setitem__(1, copy.deepcopy(b['banks'][0])),
                   lambda b:b['run'].__setitem__('head_sha', 'f'*40),
                   lambda b:b['run'].__setitem__('status', 'in_progress'),
                   lambda b:b['run'].__setitem__('conclusion', 'failure'),
                   lambda b:b['run']['repository'].__setitem__('full_name', 'other/repo'),
                   lambda b:b['workflow'].__setitem__('path', '.github/workflows/other.yml'),
                   lambda b:b['banks'][0].__setitem__('bank', False),
                   lambda b:b['banks'][0]['job'].__setitem__('run_attempt', 2),
                   lambda b:b['banks'][0]['job'].__setitem__('head_sha', 'f'*40),
                   lambda b:b['banks'][0]['job'].__setitem__('conclusion', 'cancelled'),
                   lambda b:b['banks'][0]['job']['steps'].pop(),
                   lambda b:b['banks'][0]['job']['steps'][-1].__setitem__('conclusion', 'skipped')]
        for i, change in enumerate(changes):
            bundle, logs = fixture(); change(bundle)
            with self.subTest(i=i), self.assertRaises(ValueError):
                hosted.verify(bundle, SOURCE, logs)

    def test_receipt_cannot_override_actual_counts_or_selectors(self):
        changes = [lambda r:r.__setitem__('source', 'f'*40), lambda r:r.__setitem__('bank', False),
                   lambda r:r.__setitem__('fullWindowsQualification', True),
                   lambda r:r['completedSlices'].pop(),
                   lambda r:r['completedSlices'][0].__setitem__('reportedTests', 0),
                   lambda r:r['completedSlices'][0].__setitem__('exitCode', False),
                   lambda r:r['completedSlices'][0].__setitem__('selector', '.*'),
                   lambda r:r['completedSlices'][0].__setitem__('executedTests', 0),
                   lambda r:r['completedSlices'][0].__setitem__('explicitlySkippedTests', 1)]
        for i, change in enumerate(changes):
            bundle, logs = fixture()
            replace_record(bundle, logs, 'autotechno-windows-test-bank-result.v2', change)
            with self.subTest(i=i), self.assertRaises(ValueError):
                hosted.verify(bundle, SOURCE, logs)

    def test_log_corruption_duplicate_receipts_missing_boundaries_or_unknown_skips_refuse(self):
        changes = [lambda s:s.replace('END native suite slice', 'MISSING native suite slice', 1),
                   lambda s:s.replace('tests passed', 'tests failed', 1),
                   lambda s:s.replace('BEGIN native suite slice swift-testing:OwnerTests, bank 0/8',
                                      'BEGIN native suite slice swift-testing:OtherTests, bank 0/8', 1),
                   lambda s:s + json.dumps(hosted.records(s, 'autotechno-windows-test-bank-result.v2')),
                   lambda s:s.replace('✔ Test run', '↷ Test "Unknown skip" skipped.\n✔ Test run', 1)]
        for i, change in enumerate(changes):
            bundle, logs = fixture(); logs[0] = change(logs[0].decode()).encode()
            bundle['banks'][0]['logSHA256'] = hosted.sha(logs[0])
            with self.subTest(i=i), self.assertRaises(ValueError):
                hosted.verify(bundle, SOURCE, logs)
        bundle, logs = fixture(); logs[0] += b'changed'
        with self.assertRaisesRegex(ValueError, 'log digest'):
            hosted.verify(bundle, SOURCE, logs)

    def test_discovery_assignment_is_recomputed_not_trusted(self):
        bundle, logs = fixture()
        replace_record(bundle, logs, 'autotechno-windows-test-bank-plan.v2',
                       lambda r:r.__setitem__('discoveredSuites', 999))
        with self.assertRaisesRegex(ValueError, 'exhaustive discovery'):
            hosted.verify(bundle, SOURCE, logs)

    def test_collector_retains_originals_and_refuses_running_or_changed_run(self):
        bundle, logs = fixture()
        prefix = 'repos/randomactions/auto-techno/actions/'
        responses = {'runs/50': bundle['run'], 'workflows/20': bundle['workflow'],
                     'runs/50/jobs?per_page=100&filter=latest': dict(total_count=8, jobs=[r['job'] for r in bundle['banks']])}
        def api(command, **kwargs):
            suffix = command[-1].removeprefix(prefix)
            if suffix.endswith('/logs'):
                return logs[int(suffix.split('/')[1])-100]
            return json.dumps(responses[suffix]).encode()
        with tempfile.TemporaryDirectory() as folder, mock.patch.object(hosted.subprocess, 'check_output', side_effect=api):
            output = Path(folder)/'collected'
            result = hosted.collect(50, SOURCE, output)
            self.assertEqual(result['executedTests'], 128)
            for bank, raw in logs.items():
                self.assertEqual(hosted.gzip.decompress((output/f'bank-{bank}.log.gz').read_bytes()), raw)
            with self.assertRaisesRegex(ValueError, 'fresh output'):
                hosted.collect(50, SOURCE, output)
            responses['runs/50'] = {**bundle['run'], 'status': 'in_progress'}
            with self.assertRaisesRegex(ValueError, 'terminal exact-source'):
                hosted.collect(50, SOURCE, Path(folder)/'running')
            self.assertFalse((Path(folder)/'running').exists())

    def test_collector_refuses_run_attempt_change_before_writing(self):
        bundle, logs = fixture()
        calls = 0
        def api(command, **kwargs):
            nonlocal calls
            suffix = command[-1].split('/actions/')[1]
            if suffix == 'runs/50':
                calls += 1
                return json.dumps({**bundle['run'], 'run_attempt': calls}).encode()
            if suffix == 'workflows/20': return json.dumps(bundle['workflow']).encode()
            if suffix.startswith('runs/50/jobs'):
                return json.dumps(dict(total_count=8, jobs=[r['job'] for r in bundle['banks']])).encode()
            return logs[int(suffix.split('/')[1])-100]
        with tempfile.TemporaryDirectory() as folder, mock.patch.object(hosted.subprocess, 'check_output', side_effect=api):
            output = Path(folder)/'changed'
            with self.assertRaisesRegex(ValueError, 'run changed'):
                hosted.collect(50, SOURCE, output)
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
