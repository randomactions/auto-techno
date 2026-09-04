#!/usr/bin/env python3
"""Mutation tests for the independent section-boundary verifier."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import section_boundary_baseline_report as module  # noqa: E402


class SectionBoundaryBaselineReportTests(unittest.TestCase):
    def input(
        self,
        sample_rate: int = 48_000,
        total_bars: int = 22,
        focus: int = 1,
        rms: list[float] | None = None,
        side: float | None = 0.1,
    ) -> dict[str, object]:
        bar_frames = int(math.floor(sample_rate * 240 / 130 + 0.5))
        values = rms or [10.0] * total_bars
        bars: list[dict[str, object]] = []
        for index in range(total_bars):
            if index < 4:
                phrase, local, kind, chapter = 0, index, "lock", "home"
            elif index < 14:
                phrase, local, kind = 1, index - 4, "contrast"
                chapter = "home" if index < 8 else "motion"
            else:
                phrase, local, kind, chapter = (
                    2, index - 14, "identityReturn", "memory"
                )
            start = index * bar_frames
            cells = []
            for cell in range(16):
                cell_start = start + (cell * bar_frames + 15) // 16
                cell_end = start + ((cell + 1) * bar_frames + 15) // 16
                cells.append({
                    "index": cell,
                    "startFrame": cell_start,
                    "frameCount": cell_end - cell_start,
                    "sourceRMSDBFS": -18.0,
                    "bandShares": [0.25] * 4,
                    "onsetCount": 1 if cell % 4 == 0 else 0,
                })
            bars.append({
                "timelineIndex": index,
                "startFrame": start,
                "frameCount": bar_frames,
                "score": {
                    "phraseIndex": phrase,
                    "phraseKind": kind,
                    "absoluteBar": index,
                    "barIndexInPhrase": local,
                    "interlockChapter": chapter,
                },
                "metrics": {
                    "combinedRMSDBFS": values[index],
                    "crestFactor": 2.0,
                    "bandShares": [0.25] * 4,
                    "sideEnergyShare": side,
                    "onsetCount": 4,
                    "restOccupancy": 0.75,
                },
                "transitionCells": cells,
            })
        return {
            "sampleRate": sample_rate,
            "sourceChannelCount": 2,
            "barFrameCount": bar_frames,
            "focusPhraseIndex": focus,
            "bars": bars,
        }

    def test_markers_are_merged_in_fixed_order_and_focus_bounded(self) -> None:
        boundaries = module.rebuild_boundaries(self.input())
        self.assertEqual([item["timelineBarIndex"] for item in boundaries], [4, 8, 14])
        self.assertEqual(
            boundaries[0]["markers"], ["phrase-start", "phrase-kind-change"]
        )
        self.assertEqual(
            boundaries[2]["markers"],
            ["phrase-start", "phrase-kind-change", "interlock-chapter-change"],
        )

    def test_recovery_facts_are_independently_rebuilt(self) -> None:
        values = [10.0] * 22
        values[4:12] = [20, 18, 14, 10, 10, 10, 10, 10]
        metric = module.rebuild_boundaries(self.input(rms=values))[0]["metrics"][0]
        self.assertEqual(metric["signedTransitionDelta"], 10)
        self.assertEqual(metric["firstTowardReference"]["barOffset"], 1)
        self.assertEqual(metric["firstReferenceEnvelopeEntry"]["barOffset"], 3)
        self.assertEqual(
            metric["firstSustainedReferenceEnvelopeResidence"]["barOffset"], 3
        )
        self.assertEqual(metric["status"], "sustained-observed")

    def test_nonreturn_and_oscillation_do_not_claim_recovery(self) -> None:
        for post in (
            [20.0] * 8,
            [20.0, 10, 20, 10, 20, 10, 20, 10],
        ):
            values = [10.0] * 22
            values[4:12] = post
            metric = module.rebuild_boundaries(self.input(rms=values))[0]["metrics"][0]
            self.assertEqual(metric["status"], "not-observed-within-horizon")
            self.assertIsNone(metric["firstSustainedReferenceEnvelopeResidence"])

    def test_missing_reference_post_and_metric_fail_closed(self) -> None:
        session_start = module.rebuild_boundaries(self.input(focus=0))[0]
        self.assertEqual(
            session_start["jointRecoveryStatus"],
            "unavailable-missing-reference",
        )
        outgoing = module.rebuild_boundaries(self.input(total_bars=18))[-1]
        self.assertEqual(
            outgoing["jointRecoveryStatus"], "unavailable-missing-post"
        )
        missing_side = module.rebuild_boundaries(self.input(side=None))[0]
        self.assertEqual(
            missing_side["metrics"][6]["status"], "unavailable-missing-metric"
        )
        self.assertEqual(
            missing_side["jointRecoveryStatus"], "unavailable-missing-metric"
        )

    def test_rate_normalized_timing_is_reconstructable(self) -> None:
        at_44 = self.input(sample_rate=44_100)["barFrameCount"]
        at_48 = self.input(sample_rate=48_000)["barFrameCount"]
        self.assertEqual(at_44, 81_415)
        self.assertEqual(at_48, 88_615)
        self.assertLess(abs(at_44 / 44_100 - at_48 / 48_000), 0.00002)

    def test_discontinuous_score_and_mutated_cell_geometry_are_rejected(self) -> None:
        discontinuous = self.input()
        discontinuous["bars"][5]["score"]["absoluteBar"] += 1
        with self.assertRaises(module.SectionBoundaryBaselineReportError):
            module.validate_input(discontinuous)
        cell = self.input()
        cell["bars"][4]["transitionCells"][0]["startFrame"] += 1
        with self.assertRaises(module.SectionBoundaryBaselineReportError):
            module.validate_input(cell)

    def test_recursive_comparison_rejects_field_value_null_and_order_mutations(self) -> None:
        expected = {
            "markers": ["phrase-start", "phrase-kind-change"],
            "value": 0.25,
            "nullable": None,
        }
        module.compare(copy.deepcopy(expected), expected)
        mutations = []
        missing = copy.deepcopy(expected); missing.pop("nullable"); mutations.append(missing)
        numeric = copy.deepcopy(expected); numeric["value"] = 0.5; mutations.append(numeric)
        null = copy.deepcopy(expected); null["nullable"] = 0; mutations.append(null)
        order = copy.deepcopy(expected); order["markers"].reverse(); mutations.append(order)
        for mutation in mutations:
            with self.assertRaises(module.SectionBoundaryBaselineReportError):
                module.compare(mutation, expected)

    def test_report_fingerprint_binds_every_payload_field(self) -> None:
        payload = {
            "schema": module.REPORT_SCHEMA,
            "entries": [],
            "summary": {"boundaryCount": 0},
        }
        report = {
            **payload,
            "reportFingerprint": hashlib.sha256(
                module.canonical_bytes(payload)
            ).hexdigest(),
        }
        module.validate_report(report, report)
        mutated = json.loads(json.dumps(report))
        mutated["summary"]["boundaryCount"] = 1
        with self.assertRaises(module.SectionBoundaryBaselineReportError):
            module.validate_report(mutated, mutated)

    def test_report_hash_binds_the_selected_export_path(self) -> None:
        export = {
            "corpusSha256": "corpus",
            "contractBaselineFingerprint": "contract",
            "sourceFingerprint": "source",
            "gitHead": "head",
            "engineVersion": "engine",
            "wholeManifestSha256": "whole",
        }
        with tempfile.TemporaryDirectory() as directory:
            export_path = Path(directory) / "custom-export.json"
            export_path.write_bytes(b"custom export payload\n")
            with mock.patch.object(module, "validate_export", return_value=([], {})):
                report = module.build_report(export, Path(directory), export_path)
        self.assertEqual(
            report["exportManifestSha256"],
            hashlib.sha256(b"custom export payload\n").hexdigest(),
        )


if __name__ == "__main__":
    unittest.main()
