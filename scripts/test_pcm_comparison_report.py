#!/usr/bin/env python3
"""Unit tests for deterministic tolerance-aware PCM comparison reports."""

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


MODULE_PATH = Path(__file__).with_name("pcm_comparison_report.py")
SPEC = importlib.util.spec_from_file_location("pcm_comparison_report", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
comparison = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = comparison
SPEC.loader.exec_module(comparison)


class PCMComparisonReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.baseline_root = root / "baseline"
        self.candidate_root = root / "candidate"
        self.baseline_manifest = self.write_whole_manifest(
            self.baseline_root, [0.0, 0.0, 0.0, 0.0]
        )
        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root, [0.0, 0.0, 0.0, 0.0]
        )

    @staticmethod
    def wav(rate: int, channels: int, samples: list[float]) -> tuple[bytes, bytes]:
        pcm = b"".join(struct.pack("<f", sample) for sample in samples)
        block_align = channels * 4
        header = (
            b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt "
            + struct.pack(
                "<IHHIIHH",
                16,
                3,
                channels,
                rate,
                rate * block_align,
                block_align,
                32,
            )
            + b"data" + struct.pack("<I", len(pcm))
        )
        return header + pcm, pcm

    def write_whole_manifest(
        self,
        root: Path,
        samples: list[float],
        *,
        channels: int = 2,
        identifier: str = "ATBC-V1-TEST--native-stereo-44100",
    ) -> Path:
        wav, pcm = self.wav(44_100, channels, samples)
        wav_path = root / "audio/tone.wav"
        wav_path.parent.mkdir(parents=True, exist_ok=True)
        wav_path.write_bytes(wav)
        manifest = {
            "schema": comparison.WHOLE_SCHEMA,
            "manifestVersion": 1,
            "sourceFingerprint": "a" * 64,
            "gitHead": "b" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "c" * 64,
            "entries": [{
                "id": identifier,
                "sampleRate": 44_100,
                "channelCount": channels,
                "frameCount": len(samples) // channels,
                "pcmSha256": hashlib.sha256(pcm).hexdigest(),
                "wavPath": "audio/tone.wav",
                "wavSha256": hashlib.sha256(wav).hexdigest(),
            }],
        }
        manifest_path = root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        return manifest_path

    def write_stem_manifest(
        self,
        root: Path,
        kick_samples: list[float],
        upper_samples: list[float],
    ) -> Path:
        files = []
        for signal, samples in (("kick", kick_samples), ("upper-tonal", upper_samples)):
            wav, pcm = self.wav(44_100, 1, samples)
            relative_path = f"audio/{signal}.wav"
            wav_path = root / relative_path
            wav_path.parent.mkdir(parents=True, exist_ok=True)
            wav_path.write_bytes(wav)
            files.append({
                "signal": signal,
                "sampleRate": 44_100,
                "channelCount": 1,
                "frameCount": len(samples),
                "pcmSha256": hashlib.sha256(pcm).hexdigest(),
                "wavPath": relative_path,
                "wavSha256": hashlib.sha256(wav).hexdigest(),
            })
        manifest = {
            "schema": comparison.STEM_SCHEMA,
            "manifestVersion": 1,
            "sourceFingerprint": "a" * 64,
            "gitHead": "b" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "c" * 64,
            "entries": [{
                "id": "ATBC-V1-TEST--native-stereo-44100",
                "files": files,
            }],
        }
        manifest_path = root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        return manifest_path

    def build(self, **kwargs: float) -> dict[str, object]:
        return comparison.build_report(
            self.baseline_manifest,
            self.candidate_manifest,
            self.baseline_root,
            self.candidate_root,
            **kwargs,
        )

    def test_exact_report_is_deterministic_and_self_verifying(self) -> None:
        first = self.build()
        second = self.build()
        self.assertEqual(first, second)
        self.assertEqual(first["classification"], "exact")
        self.assertEqual(first["summary"]["changedSampleCount"], 0)
        self.assertEqual(
            first["baseline"]["pcmSetFingerprint"],
            first["candidate"]["pcmSetFingerprint"],
        )
        report_path = Path(self.temporary.name) / "report.json"
        comparison.write_report(report_path, first)
        output = io.StringIO()
        result = comparison.run_check(
            report_path, self.baseline_root, self.candidate_root, output
        )
        self.assertEqual(result, 0, output.getvalue())
        self.assertIn("current: exact", output.getvalue())

    def test_one_sample_within_both_thresholds_is_bounded_and_located(self) -> None:
        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root, [0.0, 0.000_000_5, 0.0, 0.0]
        )
        report = self.build(absolute_tolerance=0.000_001, rms_tolerance=0.000_000_3)
        self.assertEqual(report["classification"], "bounded")
        asset = report["assets"][0]
        self.assertEqual(asset["changedSampleCount"], 1)
        self.assertEqual(asset["firstChangedFrame"], 0)
        self.assertEqual(asset["firstChangedChannel"], 1)
        self.assertLessEqual(asset["maximumAbsoluteError"], 0.000_001)
        self.assertLessEqual(asset["rmsError"], 0.000_000_3)

    def test_gain_and_offset_over_threshold_are_material(self) -> None:
        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root, [0.1, -0.1, 0.2, -0.2]
        )
        report = self.build()
        self.assertEqual(report["classification"], "material")
        self.assertEqual(report["summary"]["materialAssetCount"], 1)
        self.assertEqual(report["summary"]["changedSampleCount"], 4)
        self.assertGreater(report["summary"]["maximumAbsoluteError"], 0.1)

    def test_role_stem_domain_reports_each_signal_independently(self) -> None:
        self.baseline_manifest = self.write_stem_manifest(
            self.baseline_root, [0.0, 0.0], [0.25, -0.25]
        )
        self.candidate_manifest = self.write_stem_manifest(
            self.candidate_root, [0.0, 0.000_000_5], [0.25, -0.25]
        )
        report = self.build(absolute_tolerance=0.000_001, rms_tolerance=0.000_000_4)
        self.assertEqual(report["classification"], "bounded")
        self.assertEqual(report["summary"]["assetCountCompared"], 2)
        self.assertEqual(report["summary"]["exactAssetCount"], 1)
        self.assertEqual(report["summary"]["boundedAssetCount"], 1)
        classifications = {
            item["signal"]: item["classification"] for item in report["assets"]
        }
        self.assertEqual(classifications, {"kick": "bounded", "upper-tonal": "exact"})

    def test_channel_and_identity_drift_are_structurally_incompatible(self) -> None:
        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root, [0.0, 0.0], channels=1
        )
        report = self.build()
        self.assertEqual(report["classification"], "incompatible")
        self.assertEqual(report["summary"]["assetCountCompared"], 0)
        self.assertIn(
            "channel-count-mismatch",
            {issue["code"] for issue in report["structuralIssues"]},
        )

        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root,
            [0.0, 0.0, 0.0, 0.0],
            identifier="ATBC-V1-OTHER--native-stereo-44100",
        )
        report = self.build()
        self.assertEqual(report["classification"], "incompatible")
        self.assertEqual(
            {issue["code"] for issue in report["structuralIssues"]},
            {"missing-candidate-asset", "unexpected-candidate-asset"},
        )

    def test_nonfinite_and_truncated_wavs_are_rejected_before_classification(self) -> None:
        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root, [float("nan"), 0.0, 0.0, 0.0]
        )
        with self.assertRaisesRegex(comparison.PCMComparisonError, "non-finite"):
            self.build()

        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root, [0.0, 0.0, 0.0, 0.0]
        )
        manifest = json.loads(self.candidate_manifest.read_text())
        wav_path = self.candidate_root / manifest["entries"][0]["wavPath"]
        wav_path.write_bytes(wav_path.read_bytes()[:-4])
        manifest["entries"][0]["wavSha256"] = hashlib.sha256(
            wav_path.read_bytes()
        ).hexdigest()
        self.candidate_manifest.write_text(json.dumps(manifest, indent=2) + "\n")
        with self.assertRaisesRegex(comparison.PCMComparisonError, "RIFF size"):
            self.build()

    def test_hash_and_report_mutation_fail_closed(self) -> None:
        manifest = json.loads(self.candidate_manifest.read_text())
        manifest["entries"][0]["pcmSha256"] = "0" * 64
        self.candidate_manifest.write_text(json.dumps(manifest, indent=2) + "\n")
        with self.assertRaisesRegex(comparison.PCMComparisonError, "pcmSha256"):
            self.build()

        self.candidate_manifest = self.write_whole_manifest(
            self.candidate_root, [0.0, 0.0, 0.0, 0.0]
        )
        report = self.build()
        report_path = Path(self.temporary.name) / "report.json"
        mutated = copy.deepcopy(report)
        mutated["summary"]["changedSampleCount"] = 1
        comparison.write_report(report_path, mutated)
        output = io.StringIO()
        result = comparison.run_check(
            report_path, self.baseline_root, self.candidate_root, output
        )
        self.assertEqual(result, 1)
        self.assertIn("stale, mutated", output.getvalue())


if __name__ == "__main__":
    unittest.main()
