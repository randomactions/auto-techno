#!/usr/bin/env python3
"""Cold/reuse equivalence, refusal, and complete aggregate dispatch controls."""
import copy
import io
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_validation_session as session
import test_stereo_compatibility_baseline_report as fixtures
import test_phase_one_gate as gate_fixtures


class ValidationSessionTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.StereoCompatibilityBaselineReportTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        scripts = self.root / "scripts"
        scripts.mkdir()
        for name in ("stereo_compatibility_baseline_report.py", "phase_one_gate.py"):
            shutil.copy2(Path(__file__).with_name(name), scripts / name)
        self.payload_path = self.root / session.stereo.DEFAULT_PAYLOAD
        self.report_path = self.root / session.stereo.DEFAULT_REPORT
        self.payload_path.parent.mkdir(parents=True)
        self.payload_path.write_text(self.fixture.payload_path.read_text())
        self.analysis = session.stereo.StereoAnalysisSession()

    def validate(self, value=None, fingerprint=False):
        session.stereo.validate(value or self.fixture.payload, self.root,
                               fingerprint, self.analysis)

    def warm(self):
        self.validate()
        self.assertEqual(self.analysis.computations, 2)

    def reseal(self, value):
        value["reportFingerprint"] = session.stereo.hashlib.sha256(
            session.stereo.pcm.canonical_bytes({
                key: item for key, item in value.items() if key != "reportFingerprint"
            })).hexdigest()

    def test_cold_and_reused_reports_are_byte_exact(self):
        cold = self.root / "cold.json"
        reused = self.root / "reused.json"
        self.assertEqual(session.stereo.generate(self.payload_path, cold, self.root, io.StringIO()), 0)
        for _ in range(2):
            self.assertEqual(session.stereo.generate(self.payload_path, reused, self.root,
                                                    io.StringIO(), self.analysis), 0)
            self.assertEqual(cold.read_bytes(), reused.read_bytes())
            self.assertEqual(session.stereo.check(reused, self.root, io.StringIO(), self.analysis), 0)
        self.assertEqual(self.analysis.computations, 2)
        self.assertEqual(self.analysis.reuses, 6)
        fresh = session.stereo.StereoAnalysisSession()
        self.assertEqual(session.stereo.check(reused, self.root, io.StringIO(), fresh), 0)
        self.assertEqual(fresh.computations, 2)
        self.assertEqual(fresh.reuses, 0)

    def test_warm_resealed_metric_mutations_are_rejected(self):
        self.warm()
        for field, value in [("sideMeanSquare", 0.5), ("state", "inactive"),
                             ("correlation", None), ("finite", False)]:
            changed = copy.deepcopy(self.fixture.payload)
            changed["assets"][0]["evidence"]["summary"][0][field] = value
            self.reseal(changed)
            with self.assertRaises(session.stereo.StereoCompatibilityBaselineReportError):
                self.validate(changed, True)
        self.assertEqual(self.analysis.computations, 2)

    def test_warm_segment_cardinality_and_extra_fields_are_rejected(self):
        self.warm()
        for operation in (lambda e: e["segments"].pop(),
                          lambda e: e.update(unowned=1)):
            changed = copy.deepcopy(self.fixture.payload)
            operation(changed["assets"][0]["evidence"])
            with self.assertRaises(session.stereo.StereoCompatibilityBaselineReportError):
                self.validate(changed)

    def test_warm_live_pcm_mutation_is_rejected(self):
        self.warm()
        path = self.root / "audio/whole.wav"
        content = bytearray(path.read_bytes())
        content[44:48] = struct.pack("<f", 0.9)
        path.write_bytes(content)
        with self.assertRaises(session.stereo.pcm.PCMComparisonError):
            self.validate()
        self.assertEqual(self.analysis.computations, 2)

    def test_pcm_change_between_scan_and_read_is_rejected(self):
        original = session.stereo.read_channels
        def mutate_then_read(path, expected_pcm_sha256=None):
            content = bytearray(path.read_bytes())
            content[44:48] = struct.pack("<f", 0.9)
            path.write_bytes(content)
            return original(path, expected_pcm_sha256)
        with mock.patch.object(session.stereo, "read_channels", side_effect=mutate_then_read):
            with self.assertRaisesRegex(session.stereo.StereoCompatibilityBaselineReportError,
                                        "between manifest scan and analysis"):
                self.validate()

    def test_changed_contract_or_corpus_is_rejected(self):
        self.warm()
        for relative in ("docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json"):
            path = self.root / relative
            original = path.read_bytes()
            path.write_bytes(original + b" ")
            with self.assertRaises(session.stereo.StereoCompatibilityBaselineReportError):
                self.validate()
            path.write_bytes(original)
        self.assertEqual(self.analysis.computations, 2)

    def test_changed_context_and_implementation_refuse_reuse(self):
        self.warm()
        changed = copy.deepcopy(self.fixture.payload)
        changed["engineVersion"] = "other"
        with self.assertRaisesRegex(session.stereo.StereoCompatibilityBaselineReportError,
                                    "context changed"):
            self.analysis.bind(changed, self.root)
        with mock.patch.object(self.analysis, "_implementation_fingerprint", return_value="changed"):
            with self.assertRaisesRegex(session.stereo.StereoCompatibilityBaselineReportError,
                                        "implementation changed"):
                self.validate()

    def test_memory_bound_falls_back_to_cold_arithmetic(self):
        self.analysis.MAXIMUM_BYTES = 0
        self.validate()
        self.validate()
        self.assertEqual(self.analysis.retained_bytes, 0)
        self.assertEqual(self.analysis.computations, 4)
        self.assertEqual(self.analysis.reuses, 0)

    def test_cached_expected_result_is_not_mutable_by_caller(self):
        self.warm()
        rate, channels = session.stereo.read_channels(self.root / "audio/whole.wav")
        frames = session.stereo.rounded_frames(rate * 240.0 / 130.0)
        value = self.analysis.expected(channels, rate, frames)
        value["summary"][0]["state"] = "forged"
        self.assertNotEqual(self.analysis.expected(channels, rate, frames)["summary"][0]["state"], "forged")

    def command(self, name, verb):
        return [sys.executable, str(self.root / "scripts" / name), verb]

    def invoke(self, runner, name, verb, **kwargs):
        return runner(self.command(name, verb), cwd=self.root,
                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                      text=True, **kwargs)

    def test_driver_adapter_reuses_across_generate_and_check(self):
        fallback = mock.Mock(side_effect=AssertionError("unexpected subprocess"))
        runner = session.ValidationSessionRunner(self.root, fallback)
        for verb in ("generate", "check", "check"):
            result = self.invoke(runner, "stereo_compatibility_baseline_report.py", verb)
            self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(runner.analysis.computations, 2)
        self.assertEqual(runner.analysis.reuses, 4)
        self.assertIn("process-local analysis reuse", result.stdout)

    def test_aggregate_retains_every_subordinate_on_both_passes(self):
        fallback = mock.Mock(return_value=subprocess.CompletedProcess([], 0, stdout="passed"))
        runner = session.ValidationSessionRunner(self.root, fallback)
        self.invoke(runner, "stereo_compatibility_baseline_report.py", "generate")
        expected = gate_fixtures.PhaseOneGateTests().report()
        policy_path = self.root / session.gate.lifecycle.POLICY_PATH
        policy_path.parent.mkdir(parents=True, exist_ok=True)
        policy_path.write_text(json.dumps(gate_fixtures.PhaseOneGateTests().policy()))
        def build_with_all_checks(root, nested_runner):
            results = session.gate.run_checks(root, nested_runner)
            self.assertEqual(len(results), 19)
            self.assertEqual(results, expected["checks"])
            return copy.deepcopy(expected)
        with mock.patch.object(session.gate, "build_report", side_effect=build_with_all_checks):
            for verb in ("generate", "check"):
                self.assertEqual(self.invoke(runner, "phase_one_gate.py", verb).returncode, 0)
        self.assertEqual(json.loads((self.root / session.gate.REPORT_PATH).read_text()), expected)
        self.assertEqual((self.root / session.gate.MARKDOWN_PATH).read_text(),
                         session.gate.render_markdown(expected))
        self.assertEqual(fallback.call_count, 36)
        self.assertEqual(runner.analysis.computations, 2)
        self.assertEqual(runner.analysis.reuses, 4)
        self.assertEqual([Path(call.args[0][1]).name for call in fallback.call_args_list],
                         [args[0] for _, args in session.gate.CHECKS if args[0] !=
                          "stereo_compatibility_baseline_report.py"] * 2)

    def test_failure_is_preserved_and_check_true_raises(self):
        runner = session.ValidationSessionRunner(self.root)
        self.invoke(runner, "stereo_compatibility_baseline_report.py", "generate")
        self.report_path.write_text("{}")
        result = self.invoke(runner, "stereo_compatibility_baseline_report.py", "check")
        self.assertNotEqual(result.returncode, 0)
        with self.assertRaises(subprocess.CalledProcessError):
            self.invoke(runner, "stereo_compatibility_baseline_report.py", "check", check=True)

    def test_unsupported_options_or_environment_use_real_subprocess(self):
        fallback = mock.Mock(return_value=subprocess.CompletedProcess([], 17))
        runner = session.ValidationSessionRunner(self.root, fallback)
        command = self.command("stereo_compatibility_baseline_report.py", "check")
        for kwargs in ({"timeout": 1}, {"env": {**os.environ, "PYTHONPATH": "other"}},
                       {"env": {**os.environ, "AUTOTECHNO_PERFORMANCE_BUILD_CONFIGURATION": "debug"}},
                       {"stdout": subprocess.DEVNULL}):
            self.assertEqual(runner(command, cwd=self.root, **kwargs).returncode, 17)
        self.assertEqual(fallback.call_count, 4)

    def test_aggregate_subprocesses_inherit_driver_environment(self):
        fallback = mock.Mock(return_value=subprocess.CompletedProcess([], 0, stdout="passed"))
        runner = session.ValidationSessionRunner(self.root, fallback)
        env = {**os.environ, "DEVELOPER_DIR": "/fixture/xcode", "CLANG_MODULE_CACHE_PATH": "/fixture/cache"}
        self.invoke(runner, "stereo_compatibility_baseline_report.py", "generate", env=env)
        def pass_all(root, output, nested_runner):
            session.gate.run_checks(root, nested_runner)
            return 0
        with mock.patch.object(session.gate, "run_generate", side_effect=pass_all):
            result = self.invoke(runner, "phase_one_gate.py", "generate", env=env)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(fallback.call_count, 18)
        for call in fallback.call_args_list:
            self.assertEqual(call.kwargs["env"], env)
        self.assertEqual(runner._environment_stack, [])

    def test_source_changed_before_session_construction_is_rejected(self):
        with mock.patch.object(session.stereo, "_IMPLEMENTATION_BYTES_AT_IMPORT", (b"stale",)):
            with self.assertRaisesRegex(session.stereo.StereoCompatibilityBaselineReportError,
                                        "differs from loaded source"):
                session.stereo.StereoAnalysisSession()
        with mock.patch.object(session, "_ADAPTER_BYTES_AT_IMPORT", (b"stale",)):
            with self.assertRaisesRegex(session.stereo.StereoCompatibilityBaselineReportError,
                                        "differs from loaded source"):
                session.ValidationSessionRunner(self.root)

    def test_text_log_redirection_and_bytes_capture(self):
        runner = session.ValidationSessionRunner(self.root)
        output = io.StringIO()
        result = runner(self.command("stereo_compatibility_baseline_report.py", "generate"),
                        cwd=self.root, stdout=output, stderr=subprocess.STDOUT)
        self.assertEqual(result.returncode, 0)
        self.assertIsNone(result.stdout)
        self.assertIn("generated", output.getvalue())
        result = runner(self.command("stereo_compatibility_baseline_report.py", "check"),
                        cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.assertIsInstance(result.stdout, bytes)


if __name__ == "__main__":
    unittest.main()
