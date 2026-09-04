#!/usr/bin/env python3
"""Tests for independent whole-mix rhythmic baseline verification."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import io
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("rhythmic_baseline_report.py")
SPEC = importlib.util.spec_from_file_location(
    "rhythmic_baseline_report", MODULE_PATH
)
assert SPEC is not None and SPEC.loader is not None
baseline = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = baseline
SPEC.loader.exec_module(baseline)


class RhythmicBaselineReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.sample_rate = 48_000
        self.bar_frames = baseline.transient.rounded_frames(
            self.sample_rate * 240.0 / 130.0
        )
        self.write_json("docs/BASELINE_CORPUS.json", {"fixture": "v1"})
        self.write_json(
            "docs/ROADMAP_EXECUTION_BASELINE.json",
            {"snapshotFingerprint": "a" * 64},
        )
        first = self.impulse_bar([0, 4, 8, 12])
        second = self.impulse_bar([0, 4, 8, 12, 14])
        third = self.impulse_bar([1, 2, 6, 11, 15])
        mono = first + second + third
        stereo = [value for sample in mono for value in (sample, sample)]
        whole = self.write_asset("audio/whole.wav", stereo, channels=2)
        whole.update({
            "id": "fixture--route",
            "caseId": "fixture",
            "routeId": "route",
            "rootSeed": 1,
            "checkpoint": "lock",
            "continuationClass": "initial",
            "phraseIndex": 0,
            "startBar": 0,
            "phraseKind": "lock",
            "stateFingerprint": "state",
            "planFingerprint": "plan",
            "replayFingerprint": "replay",
            "policyVersion": "policy",
            "qualityOutcome": "qualified",
        })
        self.manifest = {
            "schema": baseline.pcm.WHOLE_SCHEMA,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "a" * 64,
            "entries": [whole],
        }
        self.write_json("reports/whole.json", self.manifest)
        self.payload_path = self.root / "payload.json"
        self.report_path = self.root / "report.json"
        self.payload = self.make_payload()
        self.write_json("payload.json", self.payload)

    def impulse_bar(
        self,
        steps: list[int],
        amplitude: float = 0.8,
        offset_steps: float = 0.0,
    ) -> list[float]:
        result = [0.0] * self.bar_frames
        for step in steps:
            frame = baseline.transient.rounded_frames(
                (step + offset_steps) * self.bar_frames / 16.0
            )
            if 0 <= frame < len(result):
                result[frame] = amplitude
        return result

    def write_json(self, path: str, value: object) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    def write_asset(
        self, path: str, samples: list[float], channels: int
    ) -> dict[str, object]:
        pcm_bytes = b"".join(struct.pack("<f", sample) for sample in samples)
        block_align = channels * 4
        wav = (
            b"RIFF" + struct.pack("<I", 36 + len(pcm_bytes)) + b"WAVEfmt "
            + struct.pack(
                "<IHHIIHH", 16, 3, channels, self.sample_rate,
                self.sample_rate * block_align, block_align, 32,
            )
            + b"data" + struct.pack("<I", len(pcm_bytes)) + pcm_bytes
        )
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(wav)
        return {
            "sampleRate": self.sample_rate,
            "channelCount": channels,
            "frameCount": len(samples) // channels,
            "pcmSha256": hashlib.sha256(pcm_bytes).hexdigest(),
            "wavPath": path,
            "wavSha256": hashlib.sha256(wav).hexdigest(),
        }

    def input_record(self) -> dict[str, object]:
        path = self.root / "reports/whole.json"
        manifest = baseline.pcm.load_json(path, "whole-mix")
        _, artifacts = baseline.pcm.extract_artifacts(
            manifest, self.root, "whole-mix"
        )
        cache: dict[Path, baseline.pcm.ScannedWav] = {}
        scans = {
            identifier: baseline.pcm.scan_artifact(artifact, cache)
            for identifier, artifact in artifacts.items()
        }
        return {
            "domain": "whole-mix",
            "manifestPath": "reports/whole.json",
            "manifestSha256": baseline.pcm.sha256(path),
            "manifestSchema": manifest["schema"],
            "assetCount": len(artifacts),
            "pcmSetFingerprint": baseline.signal.pcm_set_fingerprint(
                artifacts, scans
            ),
        }

    def make_payload(self) -> dict[str, object]:
        entry = self.manifest["entries"][0]
        sample_rate, channels = baseline.transient.read_channels(
            self.root / str(entry["wavPath"])
        )
        return {
            "schema": baseline.REPORT_SCHEMA,
            "reportVersion": 1,
            "analyzerVersion": baseline.ANALYZER_VERSION,
            "corpusSha256": baseline.pcm.sha256(
                self.root / "docs/BASELINE_CORPUS.json"
            ),
            "contractBaselineFingerprint": "a" * 64,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "policies": baseline.expected_policy(),
            "inputs": [self.input_record()],
            "assets": [{
                "assetId": "fixture--route::whole-mix",
                "entryId": entry["id"],
                "checkpoint": entry["checkpoint"],
                "continuationClass": entry["continuationClass"],
                "phraseIndex": entry["phraseIndex"],
                "startBar": entry["startBar"],
                "phraseKind": entry["phraseKind"],
                "planFingerprint": entry["planFingerprint"],
                "pcmSha256": entry["pcmSha256"],
                "wavPath": entry["wavPath"],
                "evidence": baseline.analyze_pcm(channels, sample_rate),
            }],
        }

    def generate(self) -> tuple[int, str]:
        output = io.StringIO()
        result = baseline.generate(
            self.payload_path, self.report_path, self.root, output
        )
        return result, output.getvalue()

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        result = baseline.check(self.report_path, self.root, output)
        return result, output.getvalue()

    def test_complete_payload_generates_and_checks(self) -> None:
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("1 whole mixes", diagnostic)
        self.assertIn("3 bars", diagnostic)
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("independently recomputed", diagnostic)

    def test_mutated_bar_comparison_and_summary_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        comparison = mutated["assets"][0]["evidence"]["comparisons"][0]
        comparison["gridMutationDistance"] += 0.1
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("gridMutationDistance", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["summary"][
            "meanRestOccupancy"
        ] += 0.1
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("meanRestOccupancy", diagnostic)

    def test_policy_manifest_and_report_fingerprint_mutations_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["policies"]["scoreBindingStatus"] = "score-bound"
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("scoreBindingStatus", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["inputs"][0]["manifestSha256"] = "d" * 64
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("manifest hash", diagnostic)

        self.write_json("payload.json", self.payload)
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        report = json.loads(self.report_path.read_text(encoding="utf-8"))
        report["assets"][0]["phraseKind"] = "forged"
        self.write_json("report.json", report)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertTrue(
            "phraseKind" in diagnostic or "reportFingerprint" in diagnostic
        )

    def test_identity_mutation_churn_and_rotation_signs(self) -> None:
        identity = self.impulse_bar([0, 4, 8, 12])
        mutation = self.impulse_bar([0, 4, 8, 12, 14])
        churn = self.impulse_bar([1, 2, 6, 11, 15])
        rotated = self.impulse_bar([2, 6, 10, 14])
        evidence = baseline.analyze_pcm(
            [identity + identity + mutation + churn + rotated],
            self.sample_rate,
        )
        comparisons = {
            (item["referenceBarIndex"], item["currentBarIndex"]): item
            for item in evidence["comparisons"]
        }
        exact = comparisons[(0, 1)]
        one_event = comparisons[(1, 2)]
        unrelated = comparisons[(2, 3)]
        rotation = comparisons[(0, 4)]
        self.assertTrue(exact["exactPCMRepeat"])
        self.assertEqual(exact["gridMutationDistance"], 0.0)
        self.assertLess(
            one_event["gridMutationDistance"],
            unrelated["gridMutationDistance"],
        )
        self.assertEqual(rotation["bestReferenceForwardRotationSteps"], 2)
        self.assertEqual(rotation["bestRotationMutationDistance"], 0.0)

    def test_silence_sustain_phase_and_partial_behavior(self) -> None:
        silence = [0.0] * (self.bar_frames * 2)
        silent = baseline.analyze_pcm([silence], self.sample_rate)
        self.assertEqual(silent["bars"][0]["exactSilenceOccupancy"], 1.0)
        self.assertEqual(
            silent["comparisons"][0]["availability"],
            "unavailable-no-onsets-in-either-bar",
        )
        self.assertIsNone(silent["comparisons"][0]["gridMutationDistance"])

        sustain = [0.1] * (self.bar_frames * 3)
        sustained = baseline.analyze_pcm([sustain], self.sample_rate)
        self.assertEqual(sustained["bars"][1]["restOccupancy"], 1.0)
        self.assertEqual(sustained["bars"][1]["exactSilenceOccupancy"], 0.0)

        pulse = self.impulse_bar([0, 4, 8, 12])
        cancelled = baseline.analyze_pcm(
            [pulse, [-value for value in pulse]], self.sample_rate
        )
        self.assertEqual(cancelled["summary"]["onsetCount"], 0)
        self.assertLess(cancelled["bars"][0]["exactSilenceOccupancy"], 1.0)

        partial = baseline.analyze_pcm(
            [pulse + pulse[: self.bar_frames // 2]], self.sample_rate
        )
        self.assertEqual(partial["summary"]["partialBarCount"], 1)
        self.assertEqual(
            partial["bars"][1]["cyclicIntervalStatus"],
            "unavailable-partial-bar",
        )

    def test_microtiming_is_rate_normalized_and_grid_preserving(self) -> None:
        distances: list[float] = []
        for sample_rate in (44_100, 48_000):
            bar_frames = baseline.transient.rounded_frames(
                sample_rate * 240.0 / 130.0
            )
            def bar(offset: float) -> list[float]:
                result = [0.0] * bar_frames
                for step in (0, 4, 8, 12):
                    frame = baseline.transient.rounded_frames(
                        (step + offset) * bar_frames / 16.0
                    )
                    result[frame] = 0.8
                return result
            evidence = baseline.analyze_pcm(
                [bar(0.0) + bar(0.1)], sample_rate
            )
            value = evidence["comparisons"][0]
            self.assertEqual(value["gridMutationDistance"], 0.0)
            self.assertFalse(value["exactOnsetFrameRepeat"])
            distances.append(value["matchedMicrotimingDistanceSteps"])
        self.assertAlmostEqual(distances[0], 0.1, places=4)
        self.assertAlmostEqual(distances[1], 0.1, places=4)
        self.assertAlmostEqual(distances[0], distances[1], places=4)


if __name__ == "__main__":
    unittest.main()
