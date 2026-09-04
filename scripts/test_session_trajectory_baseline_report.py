#!/usr/bin/env python3
"""Mutation tests for the independent session-trajectory baseline verifier."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import session_trajectory_baseline_report as module  # noqa: E402


class SessionTrajectoryBaselineReportTests(unittest.TestCase):
    def bar(
        self,
        absolute_bar: int,
        tension: float = 0.5,
        activity: float = 0.5,
        repetition: float = 0.5,
        density: float = 0.5,
        signature: int | None = None,
        capabilities: list[str] | None = None,
    ) -> dict[str, object]:
        return {
            "absoluteBar": absolute_bar,
            "section": "groove",
            "interlockChapter": "home",
            "tension": tension,
            "activity": activity,
            "repetition": repetition,
            "density": density,
            "eventSignature": signature if signature is not None else absolute_bar + 1,
            "capabilities": capabilities or [],
        }

    def phrase(
        self,
        phrase_index: int,
        start_bar: int,
        tensions: list[float],
        kind: str = "lock",
        operator: str | None = None,
        reason: str = "conservative-fallback",
        signatures: list[int] | None = None,
        capabilities: list[list[str]] | None = None,
    ) -> dict[str, object]:
        return {
            "rootSeed": 9_001,
            "phraseIndex": phrase_index,
            "startBar": start_bar,
            "phraseKind": kind,
            "operatorKind": operator,
            "selectionReason": reason,
            "bars": [
                self.bar(
                    start_bar + index,
                    tension=value,
                    signature=signatures[index] if signatures else None,
                    capabilities=capabilities[index] if capabilities else None,
                )
                for index, value in enumerate(tensions)
            ],
        }

    def test_segments_shapes_recurrence_and_capability_runs_rebuild(self) -> None:
        signatures = [1, 1, 2, 2, 2, 1, 3, 3]
        capabilities = [
            ["groove-pulse", "pulse-echo"],
            ["groove-pulse", "pulse-echo"],
            ["groove-pulse", "pulse-echo"],
            ["groove-pulse", "pulse-echo"],
            ["groove-pulse", "pulse-echo"],
            ["groove-pulse"],
            ["groove-pulse", "pulse-echo"],
            ["groove-pulse", "pulse-echo"],
        ]
        phrase = self.phrase(
            0, 0, [0.5] * 8,
            signatures=signatures,
            capabilities=capabilities,
        )
        for index, bar in enumerate(phrase["bars"]):
            bar["activity"] = index / 8
            bar["repetition"] = 1 - index / 8
            bar["density"] = 0.1 if index % 2 == 0 else 0.9
        report = module.rebuild_report([phrase], "engine-test")
        segment = report["segments"][0]
        pulse_echo = next(
            item for item in report["capabilityExposure"]
            if item["capability"] == "pulse-echo"
        )
        self.assertEqual(segment["repeatedEventSignatureBarCount"], 5)
        self.assertEqual(segment["maximumEventSignatureRunBars"], 3)
        self.assertEqual(segment["activity"]["directionChangeCount"], 0)
        self.assertEqual(segment["density"]["directionChangeCount"], 6)
        self.assertEqual(pulse_echo["activeBarCount"], 7)
        self.assertEqual(pulse_echo["maximumRunBars"], 5)
        self.assertEqual(report["realizedSignalAvailability"], "unavailable")

    def test_payoff_spacing_recovery_and_unresolved_windows_rebuild(self) -> None:
        phrases = [
            self.phrase(
                0, 0, [0.8] * 4,
                kind="energyRelease", operator="payoff", reason="episode-operator",
            ),
            self.phrase(
                1, 4, [0.2] * 4,
                kind="majorBreak", operator="recover", reason="episode-operator",
            ),
            self.phrase(
                2, 8, [0.8] * 4,
                kind="energyRelease", operator="payoff", reason="episode-operator",
            ),
            self.phrase(
                3, 12, [0.8] * 4,
                kind="energyRelease", operator="payoff", reason="episode-operator",
            ),
        ]
        report = module.rebuild_report(phrases, "engine-test")
        self.assertEqual(report["payoffMarkerBars"], [0, 8, 12])
        self.assertEqual(report["recoveryMarkerBars"], [4])
        self.assertEqual(report["payoffSpacing"]["meanBars"], 6)
        self.assertEqual(report["payoffRecovery"][0]["latencyBars"], 4)
        self.assertEqual(
            [item["status"] for item in report["payoffRecovery"]],
            ["observed", "unresolved-within-horizon", "unresolved-within-horizon"],
        )

    def test_discontinuity_scalar_selection_capacity_and_order_fail_closed(self) -> None:
        base = [
            self.phrase(0, 0, [0.5]),
            self.phrase(1, 1, [0.5]),
        ]
        mutations = []
        skipped = copy.deepcopy(base); skipped[1]["phraseIndex"] = 2; mutations.append(skipped)
        bar_gap = copy.deepcopy(base); bar_gap[0]["bars"][0]["absoluteBar"] = 1; mutations.append(bar_gap)
        invalid = copy.deepcopy(base); invalid[0]["bars"][0]["tension"] = 1.1; mutations.append(invalid)
        selection = copy.deepcopy(base); selection[0]["operatorKind"] = "payoff"; mutations.append(selection)
        order = copy.deepcopy(base)
        order[0]["bars"][0]["capabilities"] = ["pulse-echo", "groove-pulse"]
        mutations.append(order)
        duplicate = copy.deepcopy(base)
        duplicate[0]["bars"][0]["capabilities"] = ["groove-pulse", "groove-pulse"]
        mutations.append(duplicate)
        for mutation in mutations:
            with self.assertRaises(module.SessionTrajectoryBaselineError):
                module.rebuild_report(mutation, "engine-test")
        excessive = [
            self.phrase(index, index * 16, [0.5] * 16)
            for index in range(513)
        ]
        with self.assertRaises(module.SessionTrajectoryBaselineError):
            module.rebuild_report(excessive, "engine-test")

    def test_report_and_fnv_fingerprints_bind_raw_mutations(self) -> None:
        phrases = [self.phrase(0, 0, [0.5, 0.6])]
        first = module.rebuild_report(phrases, "engine-test")
        replay = module.rebuild_report(copy.deepcopy(phrases), "engine-test")
        changed = copy.deepcopy(phrases)
        changed[0]["bars"][1]["density"] = 0.51
        mutation = module.rebuild_report(changed, "engine-test")
        self.assertEqual(first, replay)
        self.assertEqual(len(first["reportFingerprint"]), 16)
        self.assertNotEqual(first["reportFingerprint"], mutation["reportFingerprint"])

    def test_recursive_comparison_rejects_value_null_order_and_field_mutations(self) -> None:
        expected = {"markers": [0, 4], "value": 0.25, "nullable": None}
        module.compare(copy.deepcopy(expected), expected)
        mutations = []
        missing = copy.deepcopy(expected); missing.pop("nullable"); mutations.append(missing)
        value = copy.deepcopy(expected); value["value"] = 0.5; mutations.append(value)
        null = copy.deepcopy(expected); null["nullable"] = 0; mutations.append(null)
        order = copy.deepcopy(expected); order["markers"].reverse(); mutations.append(order)
        for mutation in mutations:
            with self.assertRaises(module.SessionTrajectoryBaselineError):
                module.compare(mutation, expected)

    def test_source_fingerprint_binds_selected_untracked_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Sources").mkdir()
            (root / "Tests").mkdir()
            (root / "Sources/a.swift").write_text("a\n", encoding="utf-8")
            (root / "Tests/b.swift").write_text("b\n", encoding="utf-8")
            listing = "Sources/a.swift\nTests/b.swift\n"
            with mock.patch.object(module, "git_output", return_value=listing):
                first = module.source_fingerprint(root)
                (root / "Tests/b.swift").write_text("changed\n", encoding="utf-8")
                second = module.source_fingerprint(root)
        self.assertNotEqual(first, second)

    def test_manifest_artifact_and_swift_report_are_independently_bound(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report_directory = root / (
                "docs/local/reports/long-horizon-session-baseline-v1"
            )
            report_directory.mkdir(parents=True)
            manifest_path = report_directory / "manifest.json"
            phrases = [self.phrase(0, 0, [0.5])]
            swift_report = module.rebuild_report(phrases, "engine-test")
            cases = []
            entries = []
            for ordinal in range(7):
                case_id = f"CASE-{ordinal}"
                cases.append({
                    "id": case_id,
                    "ordinal": ordinal,
                    "rootSeed": 9_001,
                    "checkpoint": "checkpoint",
                    "continuationClass": "advanced",
                })
                artifact = {
                    "schema": module.ARTIFACT_SCHEMA,
                    "artifactVersion": 1,
                    "caseId": case_id,
                    "ordinal": ordinal,
                    "rootSeed": 9_001,
                    "checkpoint": "checkpoint",
                    "continuationClass": "advanced",
                    "requestedHours": 4,
                    "requestedBars": 1,
                    "buildConfiguration": "debug",
                    "observationRoute": "score-only-canonical-planning",
                    "initialStateFingerprint": "initial",
                    "outgoingStateFingerprint": "outgoing",
                    "phrases": phrases,
                    "report": swift_report,
                }
                artifact_path = report_directory / f"{ordinal}.json"
                artifact_path.write_text(json.dumps(artifact), encoding="utf-8")
                entries.append({
                    "id": f"entry-{ordinal}",
                    "caseId": case_id,
                    "ordinal": ordinal,
                    "rootSeed": 9_001,
                    "checkpoint": "checkpoint",
                    "continuationClass": "advanced",
                    "initialStateFingerprint": "initial",
                    "outgoingStateFingerprint": "outgoing",
                    "startingPhraseIndex": 0,
                    "nextExpectedPhraseIndex": 1,
                    "startingBar": 0,
                    "nextExpectedBar": 1,
                    "observedPhraseCount": 1,
                    "observedBarCount": 1,
                    "segmentCount": 1,
                    "reportFingerprint": swift_report["reportFingerprint"],
                    "artifactPath": (
                        "docs/local/reports/long-horizon-session-baseline-v1/"
                        f"{ordinal}.json"
                    ),
                    "artifactSha256": hashlib.sha256(
                        artifact_path.read_bytes()
                    ).hexdigest(),
                })
            manifest = self.manifest(entries)
            manifest["requestedBars"] = 1
            corpus = {"cases": cases}
            with mock.patch.object(module, "validate_provenance", return_value=corpus):
                rebuilt = module.validate_manifest(manifest, root, manifest_path)
            self.assertEqual(len(rebuilt), 7)

            first_path = report_directory / "0.json"
            mutated = json.loads(first_path.read_text(encoding="utf-8"))
            mutated["report"]["segments"][0]["tension"]["mean"] = 0.4
            first_path.write_text(json.dumps(mutated), encoding="utf-8")
            manifest["entries"][0]["artifactSha256"] = hashlib.sha256(
                first_path.read_bytes()
            ).hexdigest()
            with mock.patch.object(module, "validate_provenance", return_value=corpus):
                with self.assertRaises(module.SessionTrajectoryBaselineError):
                    module.validate_manifest(manifest, root, manifest_path)

    def test_stored_report_fingerprint_binds_every_payload_field(self) -> None:
        payload = {
            "schema": module.REPORT_SCHEMA,
            "entryCount": 0,
            "summary": {"observedBarCount": 0},
        }
        report = {
            **payload,
            "reportFingerprint": hashlib.sha256(
                module.canonical_bytes(payload)
            ).hexdigest(),
        }
        module.validate_stored_report(copy.deepcopy(report), report)
        mutated = copy.deepcopy(report)
        mutated["summary"]["observedBarCount"] = 1
        with self.assertRaises(module.SessionTrajectoryBaselineError):
            module.validate_stored_report(mutated, mutated)

    def manifest(self, entries: list[dict[str, object]]) -> dict[str, object]:
        return {
            "schema": module.MANIFEST_SCHEMA,
            "manifestVersion": 1,
            "corpusSha256": "corpus",
            "contractBaselineFingerprint": "contract",
            "sourceFingerprint": "source",
            "gitHead": "head",
            "engineVersion": "engine-test",
            "analyzerSchemaVersion": 1,
            "analyzerSchemaIdentifier": module.ANALYZER_SCHEMA,
            "buildConfiguration": "debug",
            "observationRoute": "score-only-canonical-planning",
            "requestedHours": 4,
            "requestedBars": 7_800,
            "segmentBarCount": module.SEGMENT_BAR_COUNT,
            "maximumBarCount": module.MAXIMUM_BAR_COUNT,
            "maximumSegmentCount": module.MAXIMUM_SEGMENT_COUNT,
            "entries": entries,
        }


if __name__ == "__main__":
    unittest.main()
