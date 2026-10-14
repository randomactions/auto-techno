#!/usr/bin/env python3
"""Tests for the aggregate Phase-1 evidence gate."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
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


if __name__ == "__main__":
    unittest.main()
