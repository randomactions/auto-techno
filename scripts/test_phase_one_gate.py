#!/usr/bin/env python3
"""Tests for the aggregate Phase-1 evidence gate."""

from __future__ import annotations

import copy
import importlib.util
import io
import subprocess
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("phase_one_gate.py")
SPEC = importlib.util.spec_from_file_location("phase_one_gate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)


class PhaseOneGateTests(unittest.TestCase):
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
        def passing(*args: object, **kwargs: object) -> subprocess.CompletedProcess[str]:
            return subprocess.CompletedProcess(args=[], returncode=0, stdout="passed")
        results = gate.run_checks(Path("/tmp/fixture"), passing)
        self.assertEqual(
            [item["id"] for item in results],
            [identifier for identifier, _ in gate.CHECKS],
        )

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
