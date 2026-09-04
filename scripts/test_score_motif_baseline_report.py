#!/usr/bin/env python3
"""Tests for independent accepted-score motif baseline verification."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).with_name("score_motif_baseline_report.py")
SPEC = importlib.util.spec_from_file_location("score_motif_baseline_report", MODULE_PATH)
assert SPEC and SPEC.loader
report = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(report)


class ScoreMotifBaselineReportTests(unittest.TestCase):
    def note(
        self,
        onset: int,
        ratio: float,
        role: str = "anchor",
        duration: float = 1.0,
        end_ratio: float | None = None,
    ) -> dict[str, object]:
        return {
            "role": role,
            "onsetStep": onset,
            "timingOffsetInSteps": 0.0,
            "durationInSteps": duration,
            "startFrequencyRatio": ratio,
            "endFrequencyRatio": end_ratio if end_ratio is not None else ratio,
            "gate": "retrigger",
        }

    def source(self) -> dict[str, object]:
        first = [self.note(0, 1), self.note(4, 2 ** (3 / 12)), self.note(9, 2 ** (7 / 12))]
        second = copy.deepcopy(first)
        return {
            "phraseIndex": 0,
            "startBar": 0,
            "barCount": 2,
            "tonalCenter": 0,
            "bars": [
                {"absoluteBar": 0, "notes": first},
                {"absoluteBar": 1, "notes": second},
            ],
        }

    def test_reconstructs_exact_and_transposed_dimensions(self) -> None:
        exact = report.reconstruct(self.source())
        value = next(
            item for item in exact["comparisons"]
            if item["scope"] == "combined" and item["lagBars"] == 1
        )
        self.assertTrue(value["exactRecurrence"])
        self.assertTrue(value["intervalContourRecurrence"])
        self.assertEqual(value["noteMutationDistance"], 0)

        transposed = self.source()
        transposed["bars"][1]["notes"] = [
            self.note(0, 2),
            self.note(4, 2 * 2 ** (3 / 12)),
            self.note(9, 2 * 2 ** (7 / 12)),
        ]
        evidence = report.reconstruct(transposed)
        value = next(
            item for item in evidence["comparisons"]
            if item["scope"] == "combined" and item["lagBars"] == 1
        )
        self.assertFalse(value["exactRecurrence"])
        self.assertTrue(value["intervalContourRecurrence"])
        self.assertTrue(value["normalizedMotifRecurrence"])
        self.assertEqual(value["transpositionMilliSemitones"], 12_000)
        self.assertEqual(value["pitchClassMutationDistance"], 0)
        self.assertEqual(value["meanRegisterShiftMIDIMilliNotes"], 12_000)

    def test_rotation_role_exclusion_and_empty_states(self) -> None:
        source = self.source()
        source["bars"][0]["notes"].append(self.note(7, 1.5, role="atmosphere"))
        source["bars"][1]["notes"] = [
            self.note(2, 1), self.note(6, 2 ** (3 / 12)),
            self.note(11, 2 ** (7 / 12)),
        ]
        evidence = report.reconstruct(source)
        value = next(
            item for item in evidence["comparisons"]
            if item["scope"] == "combined" and item["lagBars"] == 1
        )
        self.assertEqual(value["bestReferenceForwardRotationSteps"], 2)
        self.assertEqual(value["rotationNormalizedOnsetMutationDistance"], 0)
        self.assertEqual(evidence["summary"]["excludedNoteCounts"][0], {
            "name": "atmosphere", "count": 1,
        })

        empty = self.source()
        for bar in empty["bars"]:
            bar["notes"] = []
        empty_evidence = report.reconstruct(empty)
        combined = next(
            item for item in empty_evidence["comparisons"]
            if item["scope"] == "combined"
        )
        self.assertEqual(
            combined["availability"], "unavailable-no-notes-in-either-bar"
        )
        self.assertIsNone(combined["exactRecurrence"])

    def fixture(self, root: Path) -> tuple[dict[str, object], Path, Path]:
        (root / "docs/local/reports/baseline-corpus-v1").mkdir(parents=True)
        corpus_path = root / "docs/BASELINE_CORPUS.json"
        corpus_path.write_text("{}\n", encoding="utf-8")
        snapshot_path = root / "docs/ROADMAP_EXECUTION_BASELINE.json"
        snapshot_path.write_text(json.dumps({"snapshotFingerprint": "snapshot"}))
        entry = {
            "id": "case--route", "caseId": "case", "routeId": "route",
            "rootSeed": 42, "checkpoint": "establishment",
            "continuationClass": "initial", "sampleRate": 48_000,
            "channelCount": 2, "phraseIndex": 0, "startBar": 0,
            "phraseKind": "lock", "planFingerprint": "plan",
            "stateFingerprint": "state", "replayFingerprint": "replay",
            "pcmSha256": "a" * 64,
        }
        manifest_path = root / "docs/local/reports/baseline-corpus-v1/manifest.json"
        manifest = {
            "sourceFingerprint": "source", "gitHead": "head",
            "engineVersion": "engine", "entries": [entry],
        }
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        source = self.source()
        evidence = report.reconstruct(source)
        asset = {
            "assetId": entry["id"], "caseId": entry["caseId"],
            "routeId": entry["routeId"], "rootSeed": entry["rootSeed"],
            "checkpoint": entry["checkpoint"],
            "continuationClass": entry["continuationClass"],
            "sampleRate": entry["sampleRate"], "channelCount": entry["channelCount"],
            "phraseIndex": entry["phraseIndex"], "startBar": entry["startBar"],
            "phraseKind": entry["phraseKind"],
            "planFingerprint": entry["planFingerprint"],
            "stateFingerprint": entry["stateFingerprint"],
            "replayFingerprint": entry["replayFingerprint"],
            "acceptedPCMSha256": entry["pcmSha256"],
            "input": source, "evidence": evidence,
        }
        payload = {
            "schema": report.REPORT_SCHEMA, "reportVersion": 1,
            "analyzerVersion": report.ANALYZER_VERSION,
            "scoreSchemaVersion": report.SCORE_SCHEMA,
            "corpusSha256": report.pcm.sha256(corpus_path),
            "wholeManifestSha256": report.pcm.sha256(manifest_path),
            "contractBaselineFingerprint": "snapshot",
            "sourceFingerprint": "source", "gitHead": "head",
            "engineVersion": "engine", "policies": report.expected_policy(),
            "assets": [asset],
        }
        payload_path = root / "payload.json"
        output_path = root / "manifest.json"
        payload_path.write_text(json.dumps(payload), encoding="utf-8")
        return payload, payload_path, output_path

    def test_generate_check_and_mutation_rejection(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload, payload_path, output_path = self.fixture(root)
            stream = io.StringIO()
            self.assertEqual(
                report.generate(payload_path, output_path, root, stream), 0,
                stream.getvalue(),
            )
            self.assertEqual(report.check(output_path, root, io.StringIO()), 0)

            mutated = copy.deepcopy(payload)
            mutated["assets"][0]["input"]["bars"][1]["notes"][0][
                "startFrequencyRatio"
            ] = 2.0
            mutated_path = root / "mutated.json"
            mutated_path.write_text(json.dumps(mutated), encoding="utf-8")
            stream = io.StringIO()
            self.assertEqual(
                report.generate(mutated_path, output_path, root, stream), 1
            )
            self.assertIn("evidence", stream.getvalue())

            wrong_plan = copy.deepcopy(payload)
            wrong_plan["assets"][0]["planFingerprint"] = "wrong"
            wrong_path = root / "wrong-plan.json"
            wrong_path.write_text(json.dumps(wrong_plan), encoding="utf-8")
            self.assertEqual(
                report.generate(wrong_path, output_path, root, io.StringIO()), 1
            )

    def test_malformed_inputs_fail_closed(self) -> None:
        source = self.source()
        source["bars"][0]["notes"][0]["role"] = "unknown"
        with self.assertRaises(report.ScoreMotifBaselineReportError):
            report.reconstruct(source)
        source = self.source()
        source["bars"][1]["absoluteBar"] = 3
        with self.assertRaises(report.ScoreMotifBaselineReportError):
            report.reconstruct(source)


if __name__ == "__main__":
    unittest.main()
