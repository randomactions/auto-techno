#!/usr/bin/env python3
"""Unit tests for spectral-baseline report finalization and checking."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import io
import json
import math
import struct
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("spectral_baseline_report.py")
SPEC = importlib.util.spec_from_file_location("spectral_baseline_report", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
baseline = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = baseline
SPEC.loader.exec_module(baseline)


class SpectralBaselineReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write_json("docs/BASELINE_CORPUS.json", {"fixture": "v1"})
        self.write_json(
            "docs/ROADMAP_EXECUTION_BASELINE.json",
            {"snapshotFingerprint": "a" * 64},
        )
        frame_count = 48_000
        whole_samples = [0.2, 0.2] * frame_count
        stem_samples = [0.2] * frame_count
        whole_entry = self.write_asset(
            "audio/whole.wav", whole_samples, channels=2
        )
        whole_entry["id"] = "fixture--route"
        stem_file = self.write_asset(
            "audio/kick.wav", stem_samples, channels=1
        )
        stem_file.update({"signal": "kick", "classification": "linear-role"})
        self.whole_manifest = {
            "schema": baseline.pcm.WHOLE_SCHEMA,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "a" * 64,
            "entries": [whole_entry],
        }
        self.stem_manifest = {
            "schema": baseline.pcm.STEM_SCHEMA,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "a" * 64,
            "entries": [{"id": "fixture--route", "files": [stem_file]}],
        }
        self.write_json("reports/whole.json", self.whole_manifest)
        self.write_json("reports/stem.json", self.stem_manifest)
        self.payload = self.make_payload(frame_count)
        self.payload_path = self.root / "payload.json"
        self.report_path = self.root / "report.json"
        self.write_json("payload.json", self.payload)

    def write_json(self, path: str, value: object) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(value, indent=2) + "\n")

    def write_asset(
        self, path: str, samples: list[float], channels: int
    ) -> dict[str, object]:
        pcm = b"".join(struct.pack("<f", sample) for sample in samples)
        block_align = channels * 4
        wav = (
            b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt "
            + struct.pack(
                "<IHHIIHH", 16, 3, channels, 48_000,
                48_000 * block_align, block_align, 32,
            )
            + b"data" + struct.pack("<I", len(pcm)) + pcm
        )
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(wav)
        return {
            "sampleRate": 48_000,
            "channelCount": channels,
            "frameCount": len(samples) // channels,
            "pcmSha256": hashlib.sha256(pcm).hexdigest(),
            "wavPath": path,
            "wavSha256": hashlib.sha256(wav).hexdigest(),
        }

    def input_record(self, domain: str, path: str) -> dict[str, object]:
        manifest_path = self.root / path
        manifest = baseline.pcm.load_json(manifest_path, domain)
        _, artifacts = baseline.pcm.extract_artifacts(manifest, self.root, domain)
        cache: dict[Path, baseline.pcm.ScannedWav] = {}
        scans = {
            identifier: baseline.pcm.scan_artifact(artifact, cache)
            for identifier, artifact in artifacts.items()
        }
        return {
            "domain": domain,
            "manifestPath": path,
            "manifestSha256": baseline.pcm.sha256(manifest_path),
            "manifestSchema": manifest["schema"],
            "assetCount": len(artifacts),
            "pcmSetFingerprint": baseline.signal.pcm_set_fingerprint(
                artifacts, scans
            ),
        }

    def windows(self, frame_count: int) -> list[dict[str, object]]:
        spectrum_frames = baseline.analysis_frame_count(48_000)
        result: list[dict[str, object]] = []
        for index in range(16):
            start = (index * frame_count + 15) // 16
            end = ((index + 1) * frame_count + 15) // 16
            count = end - start
            spectrum_start = min(
                max(0, start + count // 2 - spectrum_frames // 2),
                frame_count - spectrum_frames,
            )
            result.append({
                "index": index,
                "cellStartFrame": start,
                "cellFrameCount": count,
                "spectrumStartFrame": spectrum_start,
                "spectrumFrameCount": spectrum_frames,
                "fftFrameCount": baseline.fft_frame_count(48_000),
                "sourceMeanSquare": 0.04,
                "sourceRMSDBFS": 20 * math.log10(0.2),
                "sourceActive": True,
                "spectrumActive": True,
                "spectralCentroidHz": 1_000.0,
                "spectralBandwidthHz": 100.0,
                "spectralRolloff85Hz": 1_050.0,
                "spectralFlatness": 0.01,
                "bandMeanSquares": [0.02, 0.01, 0.005, 0.005],
                "bandShares": [0.5, 0.25, 0.125, 0.125],
                "subBandShare": 0.5,
                "lowEndOccupied": True,
            })
        return result

    def evidence(self, frame_count: int) -> dict[str, object]:
        windows = self.windows(frame_count)
        return {
            "schema": baseline.EVIDENCE_SCHEMA,
            "sampleRate": 48_000,
            "sourceChannelCount": 1,
            "frameCount": frame_count,
            "segmentFrameCount": int(math.floor(48_000 * 240 / 130 + 0.5)),
            "windowsPerSegment": 16,
            "spectrumFrameCount": baseline.analysis_frame_count(48_000),
            "fftFrameCount": baseline.fft_frame_count(48_000),
            "bands": [
                {"name": name, "lowerHz": lower, "upperHz": upper}
                for name, lower, upper in baseline.BANDS
            ],
            "summary": baseline.summary_from_windows(windows),
            "segments": [{
                "startFrame": 0,
                "frameCount": frame_count,
                "summary": baseline.summary_from_windows(windows),
                "windows": windows,
            }],
        }

    def make_payload(self, frame_count: int) -> dict[str, object]:
        stem_evidence = self.evidence(frame_count)
        whole_evidence = self.evidence(frame_count)
        whole_evidence["sourceChannelCount"] = 2
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
            "policies": {
                "bpm": 130, "beatsPerBar": 4,
                "segmentDurationSeconds": 240 / 130,
                "segmentFrameRounding": "nearest-frame",
                "monoFold": "arithmetic-mean-of-source-channels",
                "windowsPerSegment": 16,
                "timelineCellPartition": "contiguous-equal-count-causal-cells",
                "spectrumWindowSeconds": 1 / 24,
                "spectrumWindowFunction": "symmetric-Hann",
                "spectrumWindowPlacement": "centered-in-causal-cell",
                "fftPadding": "next-power-of-two-zero-padding",
                "bandEnergyModel": "causal-one-pole-difference-non-power-complementary",
                "bandEnergyUnit": "mean-square-amplitude-squared",
                "bandEnergyConservation": "not-claimed",
                "activityMeanSquareThreshold": 1e-10,
                "subBandName": "sub", "minimumSubBandShare": 0.1,
                "lowEndOccupancyDenominator": "source-active-window-count",
                "shortSegmentPolicy": "unavailable-below-one-spectrum-window",
                "decibelFloor": -120,
            },
            "inputs": [
                self.input_record("whole-mix", "reports/whole.json"),
                self.input_record("role-stems", "reports/stem.json"),
            ],
            "assets": [
                {
                    "assetId": "fixture--route::kick",
                    "domain": "role-stems", "entryId": "fixture--route",
                    "signal": "kick", "classification": "linear-role",
                    "pcmSha256": self.stem_manifest["entries"][0]["files"][0]["pcmSha256"],
                    "wavPath": "audio/kick.wav", "evidence": stem_evidence,
                },
                {
                    "assetId": "fixture--route::whole-mix",
                    "domain": "whole-mix", "entryId": "fixture--route",
                    "signal": "whole-mix", "classification": "whole-mix",
                    "pcmSha256": self.whole_manifest["entries"][0]["pcmSha256"],
                    "wavPath": "audio/whole.wav", "evidence": whole_evidence,
                },
            ],
        }

    def generate(self) -> tuple[int, str]:
        output = io.StringIO()
        return baseline.generate(
            self.payload_path, self.report_path, self.root, output
        ), output.getvalue()

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return baseline.check(
            self.report_path, self.root, output
        ), output.getvalue()

    def test_complete_payload_generates_and_checks(self) -> None:
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("2 assets", diagnostic)
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("current", diagnostic)

    def test_window_coverage_or_geometry_mutation_fails(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["segments"][0]["windows"].pop()
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("cardinality", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["segments"][0]["windows"][2]["spectrumStartFrame"] += 1
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("geometry", diagnostic)

    def test_band_share_and_summary_mutation_fails(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["segments"][0]["windows"][0]["bandShares"][0] = 0.4
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("bandShares", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["summary"]["lowEndOccupancy"] = 0.5
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("does not aggregate", diagnostic)

    def test_report_fingerprint_and_manifest_drift_fail(self) -> None:
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        report = json.loads(self.report_path.read_text())
        report["assets"][0]["evidence"]["summary"]["spectralCentroidMeanHz"] += 1
        self.write_json("report.json", report)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)

        self.write_json("payload.json", self.payload)
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        self.whole_manifest["engineVersion"] = "engine-v2"
        self.write_json("reports/whole.json", self.whole_manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("hash is stale", diagnostic)


if __name__ == "__main__":
    unittest.main()
