"""Original tooling reader controls; synthetic fixtures are not qualification."""
import base64
import contextlib
import copy
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib

import tooling_verification as tooling

SOURCE = 'a' * 40


def fixture(source=SOURCE):
    identities = ['test_fixture.Example.test_one', 'test_fixture.Example.test_two']
    raw = (f'test_one ({identities[0]}) ... ok\n'
           f'test_two ({identities[1]}) ... native diagnostic output\n'
           '{"fixture":"expected-mocked-diagnostic","passed":false}\n'
           'ok\n\n----------------------------------------------------------------------\n'
           'Ran 2 tests in 0.001s\n\nOK\n').encode()
    digest = tooling.sha(Path(tooling.__file__).read_bytes())
    return dict(schema=tooling.SCHEMA, source=source, implementationSHA256=digest,
        python='Synthetic parser fixture, not execution', identities=identities,
        trackedInputs={'scripts/tooling_verification.py': digest, 'scripts/test_fixture.py': 'b'*64},
        ignoredInputs={}, command=[sys.executable, '-m', 'unittest', 'discover', '-s',
            'scripts', '-p', 'test_*.py', '-v'],
        environment={'PYTHONDONTWRITEBYTECODE': '1', 'PYTHONUNBUFFERED': '1'},
        exitCode=0, logSHA256=tooling.sha(raw),
        logBase64=base64.b64encode(raw).decode())


class ToolingOriginalTests(unittest.TestCase):
    def test_complete_named_output_with_intervening_diagnostics(self):
        result = tooling.verify(fixture(), SOURCE)
        self.assertEqual(result['executedTests'], 2)
        self.assertEqual(result['explicitlySkippedTests'], 0)
        self.assertTrue(result['originalToolingOutputVerified'])
        for field in ['runtimeQualification', 'automatedQualityQualification', 'item39Complete']:
            self.assertFalse(result[field])

    def test_generic_passed_json_foreign_source_and_exit_refuse(self):
        for changed in [dict(passed=True), dict(fixture(), source='b'*40),
                        dict(fixture(), exitCode=True), dict(fixture(), exitCode=1),
                        dict(fixture(), environment={}),
                        dict(fixture(), passed=True), dict(fixture(), implementationSHA256='0'*64)]:
            with self.subTest(changed=changed.keys()), self.assertRaises(ValueError):
                tooling.verify(changed, SOURCE)

    def test_missing_duplicate_failed_skipped_or_expected_failure_refuse_even_resealed(self):
        original = fixture(); raw = base64.b64decode(original['logBase64'])
        attacks = [raw.replace(b' ... ok\n', b' ... \n', 1),
            raw.replace(b' ... ok\n', b' ... FAIL\n', 1),
            raw.replace(b' ... ok\n', b" ... skipped 'not executed'\n", 1),
            raw.replace(b' ... ok\n', b' ... expected failure\n', 1),
            raw.replace(b' ... ok\n', b' ... unexpected success\n', 1),
            raw.replace(b' ... ok\n', b' ... ERROR\n', 1),
            raw.replace(b' ... ok\n', b' ... noise\nok\nok\n', 1),
            raw.replace(b'Ran 2 tests', b'Ran 1 test'),
            raw.replace(b'\n\nOK\n', b'\n\nFAILED (failures=1)\n'),
            raw.replace(b'test_one (test_fixture.Example.test_one) ... ok\n', b''),
            raw + raw, raw + b'late fake summary\n']
        for attack in attacks:
            with self.subTest(attack=attack[-70:]), self.assertRaises(ValueError):
                tooling.verify(dict(original, logBase64=base64.b64encode(attack).decode(),
                                    logSHA256=tooling.sha(attack)), SOURCE)

    def test_discovery_and_tracked_owner_cannot_be_omitted_or_substituted(self):
        for change in [lambda x: x['identities'].pop(),
                       lambda x: x['identities'].append(x['identities'][0]),
                       lambda x: x['trackedInputs'].pop('scripts/test_fixture.py'),
                       lambda x: x['trackedInputs'].update({'../foreign.py': 'b'*64}),
                       lambda x: x['ignoredInputs'].update({'foreign.json': 'b'*64}),
                       lambda x: x['ignoredInputs'].update({'docs/local/roadmap-plans/AT-0039.md': True}),
                       lambda x: x.update(identities=[]),
                       lambda x: x.update(identities=None)]:
            row = copy.deepcopy(fixture()); change(row)
            with self.subTest(change=change), self.assertRaises(ValueError):
                tooling.verify(row, SOURCE)

    def test_original_file_digest_is_required(self):
        with self.assertRaisesRegex(ValueError, 'original unittest file bytes'):
            tooling.verify(dict(fixture(), logSHA256='0'*64), SOURCE)

    def test_subset_pattern_or_method_filter_cannot_claim_complete_tooling(self):
        for args in [[sys.executable, '-m', 'unittest', 'test_fixture.Example.test_one'],
                     [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts',
                      '-p', 'test_one.py', '-v'],
                     fixture()['command'] + ['-k', 'test_one']]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                tooling.verify(dict(fixture(), command=args), SOURCE)

    def test_timestamped_transport_reconstructs_exact_original_file(self):
        record = fixture(); stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            tooling.emit(record)
        text = '\n'.join('2026-10-17T16:00:00Z '+line for line in stream.getvalue().splitlines())
        self.assertEqual(tooling.decode(text, SOURCE), record)
        self.assertEqual(tooling.verify(tooling.decode(text, SOURCE), SOURCE)['executedTests'], 2)
        for bad in ['', stream.getvalue()*2, stream.getvalue().replace(SOURCE, 'b'*40),
                    stream.getvalue().replace('"index": 0', '"index": true'),
                    stream.getvalue().replace('"chunks": 1', '"chunks": 2')]:
            with self.subTest(bad=bad[:50]), self.assertRaises(ValueError):
                tooling.decode(bad, SOURCE)

    def test_transport_refuses_trailing_compression_or_inflation(self):
        row = dict(schema=tooling.CHUNK_SCHEMA, source=SOURCE, index=0, chunks=1,
                   bytes=100, sha256='b'*64,
                   payload=base64.b64encode(zlib.compress(b'x'*1000)).decode())
        with mock.patch.object(tooling, 'MAX_RECORD', 100):
            with self.assertRaises(ValueError):
                tooling.decode(json.dumps(row), SOURCE)
        record = fixture(); raw = json.dumps(record).encode()
        row.update(bytes=len(raw), sha256=tooling.sha(raw),
                   payload=base64.b64encode(zlib.compress(raw)+b'trailing').decode())
        with self.assertRaises(ValueError):
            tooling.decode(json.dumps(row), SOURCE)

    def test_duplicate_and_nonfinite_json_refuse(self):
        for raw in ['{"source":1,"source":2}', '{"value":NaN}', '{"value":Infinity}']:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                tooling.strict(raw)


class ActualUnittestExecutionTests(unittest.TestCase):
    def execute_fixture(self, body):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        base = Path(temporary.name); root = base/'repo'; (root/'scripts').mkdir(parents=True)
        shutil.copyfile(tooling.__file__, root/'scripts/tooling_verification.py')
        (root/'.gitignore').write_text('__pycache__/\ndocs/local/\n')
        (root/'scripts/test_fixture.py').write_text('import unittest\n'+body)
        def git(*args):
            return subprocess.check_output(['git', '-c', 'core.fsmonitor=false', *args],
                                           cwd=root, stderr=subprocess.DEVNULL)
        git('init'); git('add', '.')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            'commit', '-m', 'Synthetic unittest execution fixture')
        source = git('rev-parse', 'HEAD').decode().strip()
        output = base/'originals'
        result = subprocess.run([sys.executable, str(root/'scripts/tooling_verification.py'),
            '--source', source, '--output', str(output)], cwd=root, capture_output=True)
        return result, output, source, root

    def test_actual_stdlib_suite_outputs_and_verifies_every_test(self):
        result, output, source, root = self.execute_fixture('''class Example(unittest.TestCase):
    def test_one(self): self.assertEqual(2+2, 4)
    def test_two(self):
        print('Expected intervening diagnostic')
        import os
        os.write(1, b'Actual child file-descriptor output\\n')
        self.assertTrue(True)
''')
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        original = json.loads((output/'original-execution.json').read_text())
        self.assertEqual(tooling.decode(result.stdout.decode(), source), original)
        self.assertEqual(tooling.verify(original, source)['executedTests'], 2)
        self.assertEqual(base64.b64decode(original['logBase64']), (output/'original-unittest.log').read_bytes())
        self.assertIn(b'Actual child file-descriptor output', (output/'original-unittest.log').read_bytes())
        self.assertIn('test_fixture.Example.test_two', original['identities'])
        self.assertFalse(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root).strip())

    def test_actual_failure_and_skip_preserve_originals_and_emit_no_success_transport(self):
        for code in ['self.fail("deliberate control")', 'self.skipTest("deliberate control")']:
            result, output, source, _ = self.execute_fixture(
                'class Example(unittest.TestCase):\n    def test_one(self): '+code+'\n')
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue((output/'original-unittest.log').exists())
            original = json.loads((output/'original-execution.json').read_text())
            self.assertEqual(original['exitCode'], 0 if 'skipTest' in code else 1)
            with self.assertRaises(ValueError):
                tooling.verify(original, source)
            self.assertNotIn(tooling.CHUNK_SCHEMA.encode(), result.stdout)

    def test_actual_input_mutation_refuses_without_a_success_receipt(self):
        result, output, _, _ = self.execute_fixture('''class Example(unittest.TestCase):
    def test_one(self):
        from pathlib import Path
        Path(__file__).write_text('changed original input')
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'input inventory or bytes changed', result.stderr)
        self.assertTrue((output/'original-unittest.log').exists())
        self.assertFalse((output/'verification.json').exists())

    def test_actual_empty_discovery_cannot_emit_a_passing_record(self):
        result, output, _, _ = self.execute_fixture('value = 1\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'complete unique tooling discovery', result.stderr)
        self.assertFalse((output/'original-execution.json').exists())
        self.assertNotIn(tooling.CHUNK_SCHEMA.encode(), result.stdout)


if __name__ == '__main__':
    unittest.main()
