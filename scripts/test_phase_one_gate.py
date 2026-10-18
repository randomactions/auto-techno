#!/usr/bin/env python3
"""Tests for the aggregate Phase-1 evidence gate."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("phase_one_gate.py")
SPEC = importlib.util.spec_from_file_location("phase_one_gate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)


class PhaseOneGateTests(unittest.TestCase):
    def trace_fixture(self, root: Path, rate: int = 48000) -> dict[str, object]:
        directory = Path("docs/local/reports/performance-envelope-v1/current native trace")
        (root / directory).mkdir(parents=True)
        inputs = []
        for kind, name in gate.performance.TRACE_FILENAMES.items():
            path = root / directory / name
            path.write_text("<trace>" + kind + "</trace>")
            inputs.append({"kind": kind, "path": (directory / name).as_posix(),
                           "sha256": gate.file_sha256(path)})
        report = {"schema": gate.performance.REPORT_SCHEMA, "liveMacOS": {
            "availability": "observed", "sampleRate": rate, "channelCount": 2,
            "processName": "Auto Techno Fixture", "inputs": inputs,
        }}
        self.write_trace_report(root, report)
        return report

    def write_trace_report(self, root: Path, report: dict[str, object]) -> None:
        report["reportFingerprint"] = gate.fingerprint(report, "reportFingerprint")
        (root / gate.performance.DEFAULT_REPORT).write_text(json.dumps(report))

    def policy(self) -> dict[str, object]:
        return copy.deepcopy(gate.lifecycle.build_policy())

    def report(self) -> dict[str, object]:
        policy = self.policy()
        order = gate.lifecycle.topological_order(policy["nodes"])
        by_id = {node["id"]: node for node in policy["nodes"]}
        artifacts = []
        for identifier in order:
            node = by_id[identifier]
            artifacts.append({
                "id": identifier,
                "path": node["artifactPath"],
                "fileSha256": "1" * 64,
                "schema": node["schema"],
                "version": node["version"],
                "artifactFingerprint": "2" * 64,
                "contractBaselineFingerprint": "3" * 64,
                "sourceFingerprint": "4" * 64,
                "corpusSha256": "5" * 64,
                "engineVersion": "autotechno-canonical-engine.v48",
                "nativeBuildConfiguration": "not-applicable",
                "gateBuildConfiguration": "release",
                "configurationBinding": "aggregate-release-regeneration-wrapper",
                "routeIdentity": "not-applicable",
                "validator": node["validatorCommand"],
                "currentVerification": None,
            })
        checks = [{
            "id": identifier,
            "command": "python3 scripts/" + arguments[0] + " " + " ".join(arguments[1:]),
            "status": "passed",
        } for identifier, arguments in gate.CHECKS]
        value: dict[str, object] = {
            "schema": gate.SCHEMA,
            "gateVersion": gate.GATE_VERSION,
            "status": "passed",
            "context": {
                "contractBaselineFingerprint": "3" * 64,
                "lifecyclePolicyFingerprint": policy["policyFingerprint"],
                "corpusSha256": "5" * 64,
                "sourceFingerprints": ["4" * 64],
                "engineVersions": ["autotechno-canonical-engine.v48"],
                "gitHeads": ["a" * 40],
                "buildConfiguration": "release",
                "routeIds": ["native-stereo-44100", "native-stereo-48000"],
            },
            "regenerationOrder": order,
            "artifacts": artifacts,
            "checks": checks,
            "exactPCM": {
                "classification": "exact",
                "wholeAssets": 14,
                "roleAssets": 210,
                "wholeSamples": 29_585_220,
                "roleSamples": 310_644_810,
                "changedSamples": 0,
                "wholeReportFingerprint": "6" * 64,
                "roleReportFingerprint": "7" * 64,
            },
            "deficitTraceability": {
                "entries": 9,
                "quarantinedObservations": 6,
                "calibratedAuditoryDefects": 0,
                "sourceCount": 8,
                "traceableSourceCount": 8,
                "registerFingerprint": "8" * 64,
            },
            "qualification": {
                "implementation": "implemented",
                "deterministicValidation": "passed",
                "exactPCM": "passed",
                "performance": "bounded-macos-observed",
                "appRouteAudition": "not-run",
                "controlledListening": "not-conducted",
                "windowsPerformance": "unavailable",
                "physicalSoak": "unavailable",
                "musicalQualityClaim": False,
                "releaseReadinessClaim": False,
                "promotionAuthorized": False,
                "runtimeInput": False,
            },
            "limitations": ["bounded fixture"],
        }
        value["gateFingerprint"] = gate.fingerprint(value)
        return value

    def reseal(self, report: dict[str, object]) -> None:
        report["gateFingerprint"] = gate.fingerprint(report, "gateFingerprint")

    def test_subordinate_inventory_covers_every_lifecycle_validator(self) -> None:
        policy = self.policy()
        commands = "\n".join(" ".join(args) for _, args in gate.CHECKS)
        for node in policy["nodes"]:
            validator_script = str(node["validatorCommand"]).split()[1]
            self.assertIn(Path(validator_script).name, commands)
        self.assertEqual(len(gate.CHECKS), 19)

    def test_subordinate_failure_is_fail_closed(self) -> None:
        def failing(*args: object, **kwargs: object) -> subprocess.CompletedProcess[str]:
            return subprocess.CompletedProcess(args=[], returncode=1, stdout="failed")
        with self.assertRaisesRegex(gate.PhaseOneGateError, "phase-zero"):
            gate.run_checks(Path("/tmp/fixture"), failing)

    def test_passing_subordinate_results_are_ordered(self) -> None:
        commands = []
        def passing(*args: object, **kwargs: object) -> subprocess.CompletedProcess[str]:
            commands.append(args[0])
            return subprocess.CompletedProcess(args=[], returncode=0, stdout="passed")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.trace_fixture(root)
            results = gate.run_checks(root, passing)
        performance = commands[-2]
        self.assertEqual(performance[2:], ["check", "--trace-directory",
            "docs/local/reports/performance-envelope-v1/current native trace",
            "--trace-process", "Auto Techno Fixture", "--trace-sample-rate", "48000",
            "--trace-channel-count", "2"])
        self.assertNotIn("20260904", results[-2]["command"])
        self.assertEqual(
            [item["id"] for item in results],
            [identifier for identifier, _ in gate.CHECKS],
        )

    def test_trace_selection_accepts_both_native_rates(self) -> None:
        for rate in (44100, 48000):
            with self.subTest(rate=rate), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                self.trace_fixture(root, rate)
                arguments = gate.performance_trace_arguments(root)
                self.assertEqual(arguments[-3:], (str(rate), "--trace-channel-count", "2"))

    def test_changed_trace_bytes_refuse_before_performance_execution(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = self.trace_fixture(root)
            (root / report["liveMacOS"]["inputs"][0]["path"]).write_text("changed")
            executed = []
            def passing(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
                executed.append(command)
                return subprocess.CompletedProcess(command, 0, "passed")
            with self.assertRaisesRegex(gate.PhaseOneGateError, "bytes/path changed"):
                gate.run_checks(root, passing)
            self.assertFalse(any(Path(command[1]).name == "performance_envelope_report.py"
                                 for command in executed))

    def test_selected_trace_still_requires_independent_subordinate_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.trace_fixture(root)
            def rejecting(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
                reject = Path(command[1]).name == "performance_envelope_report.py"
                return subprocess.CompletedProcess(command, int(reject), "invalid current raw evidence")
            with self.assertRaisesRegex(gate.PhaseOneGateError, "performance-envelope.*invalid current raw"):
                gate.run_checks(root, rejecting)

    def test_trace_missing_duplicate_and_mixed_directory_inputs_refuse(self) -> None:
        for mutation in ("missing", "duplicate", "mixed-directory"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                report = self.trace_fixture(root)
                inputs = report["liveMacOS"]["inputs"]
                if mutation == "missing":
                    inputs.pop()
                elif mutation == "duplicate":
                    inputs[1] = copy.deepcopy(inputs[0])
                else:
                    original = root / inputs[0]["path"]
                    moved = original.parent.parent / original.name
                    original.rename(moved)
                    inputs[0]["path"] = moved.relative_to(root).as_posix()
                self.write_trace_report(root, report)
                with self.assertRaises(gate.PhaseOneGateError):
                    gate.performance_trace_arguments(root)

    def test_trace_paths_cannot_escape_or_follow_symlinks(self) -> None:
        for mutation in ("absolute", "traversal", "file-symlink", "directory-symlink"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                report = self.trace_fixture(root)
                entry = report["liveMacOS"]["inputs"][0]
                original = root / entry["path"]
                if mutation == "absolute":
                    entry["path"] = str(original)
                elif mutation == "traversal":
                    entry["path"] = "../" + entry["path"]
                elif mutation == "file-symlink":
                    target = original.with_suffix(".saved")
                    original.rename(target)
                    original.symlink_to(target)
                else:
                    directory = original.parent
                    target = directory.with_name("saved trace")
                    directory.rename(target)
                    directory.symlink_to(target, target_is_directory=True)
                self.write_trace_report(root, report)
                with self.assertRaises(gate.PhaseOneGateError):
                    gate.performance_trace_arguments(root)

    def test_unobserved_or_invalid_trace_context_refuses(self) -> None:
        for key, value in (("availability", "unavailable"), ("sampleRate", True),
                           ("sampleRate", 8000), ("channelCount", True),
                           ("channelCount", 1), ("processName", ""),
                           ("processName", "x\0y")):
            with self.subTest(key=key, value=value), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                report = self.trace_fixture(root)
                report["liveMacOS"][key] = value
                self.write_trace_report(root, report)
                with self.assertRaises(gate.PhaseOneGateError):
                    gate.performance_trace_arguments(root)

    def test_unsealed_trace_context_refuses(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = self.trace_fixture(root)
            report["liveMacOS"]["sampleRate"] = 44100
            (root / gate.performance.DEFAULT_REPORT).write_text(json.dumps(report))
            with self.assertRaisesRegex(gate.PhaseOneGateError, "fingerprint"):
                gate.performance_trace_arguments(root)

    def test_valid_report_passes(self) -> None:
        report = self.report()
        self.assertEqual(gate.validate_report(report, self.policy()), [])

    def test_report_fingerprint_detects_mutation(self) -> None:
        report = self.report()
        report["limitations"].append("mutation")
        self.assertTrue(any("gateFingerprint" in item for item in gate.validate_report(report, self.policy())))

    def test_artifact_order_and_duplicate_are_rejected(self) -> None:
        report = self.report()
        report["artifacts"][0], report["artifacts"][1] = report["artifacts"][1], report["artifacts"][0]
        self.reseal(report)
        self.assertTrue(any("regeneration order" in item for item in gate.validate_report(report, self.policy())))

    def test_nonrelease_configuration_is_rejected(self) -> None:
        report = self.report()
        report["artifacts"][0]["gateBuildConfiguration"] = "debug"
        self.reseal(report)
        self.assertTrue(any("gateBuildConfiguration" in item for item in gate.validate_report(report, self.policy())))

    def test_nonexact_pcm_is_rejected(self) -> None:
        report = self.report()
        report["exactPCM"]["classification"] = "bounded"
        report["exactPCM"]["changedSamples"] = 1
        self.reseal(report)
        self.assertTrue(any("14 whole" in item for item in gate.validate_report(report, self.policy())))

    def test_untraceable_deficit_sources_are_rejected(self) -> None:
        report = self.report()
        report["deficitTraceability"]["traceableSourceCount"] = 7
        self.reseal(report)
        self.assertTrue(any("traceable" in item for item in gate.validate_report(report, self.policy())))

    def test_quality_or_promotion_claim_is_rejected(self) -> None:
        for key in ("musicalQualityClaim", "releaseReadinessClaim", "promotionAuthorized", "runtimeInput"):
            report = self.report()
            report["qualification"][key] = True
            self.reseal(report)
            self.assertTrue(any("bounded claims" in item for item in gate.validate_report(report, self.policy())), key)

    def test_check_inventory_cannot_be_omitted(self) -> None:
        report = self.report()
        report["checks"].pop()
        self.reseal(report)
        self.assertTrue(any("subordinate inventory" in item for item in gate.validate_report(report, self.policy())))

    def test_markdown_is_deterministic_and_preserves_boundaries(self) -> None:
        report = self.report()
        first = gate.render_markdown(report)
        self.assertEqual(first, gate.render_markdown(report))
        self.assertIn("Musical-quality claim | `false`", first)
        self.assertIn("Windows performance | `unavailable`", first)

    def test_malformed_root_fails_closed(self) -> None:
        with self.assertRaises(gate.PhaseOneGateError):
            gate.load_json(Path("/definitely/missing.json"), "fixture")
        report = self.report()
        report["context"]["routeIds"] = [{"unhashable": True}]
        self.reseal(report)
        self.assertTrue(gate.validate_report(report, self.policy()))


class PhaseOneOriginalExecutionTests(unittest.TestCase):
    trace_fixture = PhaseOneGateTests.trace_fixture
    write_trace_report = PhaseOneGateTests.write_trace_report
    """Real temporary Git/child execution; synthetic evidence is never qualification."""
    def fixture(self, bad_child=None, invalid_utf8=False):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        base = Path(temporary.name); root = base / "source"; root.mkdir()
        (root / "scripts").mkdir(); (root / ".gitignore").write_text("docs/local/\n")
        (root / "scripts/phase_one_gate.py").write_bytes(MODULE_PATH.read_bytes())
        for _, args in gate.CHECKS:
            path = root / "scripts" / args[0]
            body = "import sys\nsys.stdout.buffer.write(b'original child bytes\\r\\n')\n"
            if path.name == bad_child:
                body = "import sys\nsys.stdout.buffer.write(b'actual failed child\\r\\n')\nsys.exit(7)\n"
            if invalid_utf8 and path.name == gate.CHECKS[0][1][0]:
                body = "import sys\nsys.stdout.buffer.write(bytes([255]))\n"
            path.write_text(body)
        for name in gate.execution_evidence_paths():
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('{"synthetic":true}\n')
        self.trace_fixture(root)
        self.git(root, "init", "--quiet", "--initial-branch=codex/phase-one-execution-tests")
        self.git(root, "add", "."); self.commit(root)
        return root, base / "execution", self.git(root, "rev-parse", "HEAD").strip()

    @staticmethod
    def git(root, *args):
        return subprocess.check_output(["git", "-c", "core.fsmonitor=false", "-C", str(root), *args], text=True)

    def commit(self, root):
        self.git(root, "-c", "user.name=Fixture", "-c", "user.email=fixture@invalid", "commit", "--quiet", "-am", "synthetic software fixture")

    @staticmethod
    def synthetic_aggregate(root, output, runner):
        gate.run_checks(root, runner)
        print("synthetic aggregate only, no Phase-1 qualification", file=output)
        return 0

    def execute(self, root, directory, source, aggregate=None):
        with mock.patch.object(gate, "run_check", aggregate or self.synthetic_aggregate):
            return gate.run_recorded_check(root, directory, source, io.StringIO())

    def test_original_bytes_all_commands_and_nonpromotion_boundary(self):
        root, directory, source = self.fixture()
        self.assertEqual(self.execute(root, directory, source), 0)
        record = json.loads((directory / "original-execution.json").read_text())
        self.assertEqual([x["id"] for x in record["checks"]], [x[0] for x in gate.CHECKS])
        self.assertTrue(record["all19SubordinateChecksRecorded"])
        self.assertEqual(len(record["checks"]), 19)
        for row in record["checks"]:
            self.assertEqual((directory / row["log"]).read_bytes(), b"original child bytes\r\n")
            self.assertEqual(row["logSHA256"], gate.file_sha256(directory / row["log"]))
        for field in ("runtimeQualification", "automatedQualityQualification", "item39Complete"):
            self.assertIs(record[field], False)
        with self.assertRaises(gate.PhaseOneGateError):
            self.execute(root, directory, source)

    def test_failed_child_keeps_original_and_stops_without_retry(self):
        root, directory, source = self.fixture(bad_child=gate.CHECKS[1][1][0])
        self.assertEqual(self.execute(root, directory, source), 1)
        record = json.loads((directory / "original-execution.json").read_text())
        self.assertEqual(record["status"], "refused"); self.assertEqual(len(record["checks"]), 2)
        self.assertEqual(record["checks"][-1]["exitCode"], 7)
        self.assertEqual((directory / record["checks"][-1]["log"]).read_bytes(), b"actual failed child\r\n")
        self.assertFalse(record["all19SubordinateChecksRecorded"])

    def test_success_flag_without_child_execution_cannot_qualify(self):
        root, directory, source = self.fixture()
        self.assertEqual(self.execute(root, directory, source, lambda *_: 0), 1)
        record = json.loads((directory / "original-execution.json").read_text())
        self.assertFalse(record["all19SubordinateChecksRecorded"])
        self.assertEqual(record["checks"], [])

    def test_wrong_or_dirty_source_refuses_before_creating_outputs(self):
        root, directory, source = self.fixture()
        for target in ("0" * 40, True):
            with self.assertRaises(gate.PhaseOneGateError):
                self.execute(root, directory, target)
            self.assertFalse(directory.exists())
        (root / "scripts" / gate.CHECKS[0][1][0]).write_text("changed")
        with self.assertRaises(gate.PhaseOneGateError):
            self.execute(root, directory, source)
        self.assertFalse(directory.exists())

    def test_git_clean_cache_cannot_hide_different_tracked_bytes(self):
        root, directory, source = self.fixture()
        name = "scripts/" + gate.CHECKS[0][1][0]
        self.git(root, "update-index", "--assume-unchanged", name)
        (root / name).write_text("different actual tracked bytes")
        self.assertEqual(self.git(root, "status", "--porcelain").strip(), "")
        with self.assertRaisesRegex(gate.PhaseOneGateError, "actual tracked bytes"):
            self.execute(root, directory, source)
        self.assertFalse(directory.exists())

    def test_source_or_evidence_mutation_refuses_after_actual_children(self):
        for name in ("scripts/" + gate.CHECKS[0][1][0], str(gate.WHOLE_PCM_PATH)):
            with self.subTest(name=name):
                root, directory, source = self.fixture()
                def changed(root, output, runner):
                    self.synthetic_aggregate(root, output, runner)
                    (root / name).write_text("changed during check")
                    return 0
                self.assertEqual(self.execute(root, directory, source, changed), 1)
                record = json.loads((directory / "original-execution.json").read_text())
                self.assertFalse(record["inputsUnchanged"])
                self.assertTrue(record["all19SubordinateChecksRecorded"])
                self.assertFalse(record["phaseOneGateCheckPassed"])

    def test_unregistered_command_never_executes(self):
        root, directory, source = self.fixture()
        def extra(root, output, runner):
            command = gate.check_command(root, *gate.CHECKS[0]) + ["--skip-validation"]
            runner(command, cwd=root, check=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            return 0
        self.assertEqual(self.execute(root, directory, source, extra), 1)
        record = json.loads((directory / "original-execution.json").read_text())
        self.assertEqual(record["checks"], []); self.assertEqual(list(directory.glob("01-*.log")), [])

    def test_derived_assessment_before_and_after_are_both_preserved(self):
        root, directory, source = self.fixture()
        path = root / gate.ASSESSMENT_PATH; path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"original assessment")
        def changed(root, output, runner):
            self.synthetic_aggregate(root, output, runner)
            path.write_bytes(b"fresh derived assessment")
            return 0
        self.assertEqual(self.execute(root, directory, source, changed), 0)
        self.assertEqual((directory / "before-lifecycle-assessment.json").read_bytes(), b"original assessment")
        self.assertEqual((directory / "after-lifecycle-assessment.json").read_bytes(), b"fresh derived assessment")

    def test_non_utf8_original_output_is_preserved_and_refused(self):
        root, directory, source = self.fixture(invalid_utf8=True)
        self.assertEqual(self.execute(root, directory, source), 1)
        record = json.loads((directory / "original-execution.json").read_text())
        self.assertEqual((directory / record["checks"][0]["log"]).read_bytes(), bytes([255]))
        self.assertFalse(record["all19SubordinateChecksRecorded"])

    def test_all_children_pass_cannot_hide_aggregate_refusal(self):
        root, directory, source = self.fixture()
        def refused(root, output, runner):
            self.synthetic_aggregate(root, output, runner)
            return 1
        self.assertEqual(self.execute(root, directory, source, refused), 1)
        record = json.loads((directory / "original-execution.json").read_text())
        self.assertTrue(record["all19SubordinateChecksRecorded"])
        self.assertTrue(record["all19SubordinateExitCodesZero"])
        self.assertFalse(record["phaseOneGateCheckPassed"])

    def test_reduced_registry_and_oversized_output_cannot_pass(self):
        root, directory, source = self.fixture()
        with mock.patch.object(gate, "CHECKS", gate.CHECKS[:-1]):
            with self.assertRaises(gate.PhaseOneGateError):
                self.execute(root, directory, source)
        self.assertFalse(directory.exists())
        with mock.patch.object(gate, "MAX_EXECUTION_LOG", 5):
            self.assertEqual(self.execute(root, directory, source), 1)
        record = json.loads((directory / "original-execution.json").read_text())
        self.assertEqual((directory / record["checks"][0]["log"]).read_bytes(), b"original child bytes\r\n")
        self.assertFalse(record["phaseOneGateCheckPassed"])

    def test_recording_requires_explicit_check_source_and_external_output(self):
        for arguments in (["generate", "--source", "a" * 40], ["check", "--source", "a" * 40],
                          ["validate", "--execution-directory", "/unused"]):
            with self.assertRaises(SystemExit), mock.patch("sys.stderr", io.StringIO()):
                gate.parse_args(arguments)
        root, _, source = self.fixture()
        with self.assertRaises(gate.PhaseOneGateError):
            self.execute(root, root / "invalid-output", source)
        with mock.patch.dict(os.environ, {"AUTOTECHNO_SKIP_VALIDATION": "1"}):
            with self.assertRaises(gate.PhaseOneGateError):
                self.execute(root, root.parent / "unregistered-output", source)


if __name__ == "__main__":
    unittest.main()
