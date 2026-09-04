#!/usr/bin/env python3
"""Unit tests for local signal-baseline report finalization and checking."""

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


MODULE_PATH = Path(__file__).with_name("signal_baseline_report.py")
SPEC = importlib.util.spec_from_file_location("signal_baseline_report", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
baseline = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = baseline
SPEC.loader.exec_module(baseline)


class SignalBaselineReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write_json("docs/BASELINE_CORPUS.json", {"fixture": "v1"})
        self.write_json(
            "docs/ROADMAP_EXECUTION_BASELINE.json",
            {"snapshotFingerprint": "a" * 64},
        )
        whole_samples = [0.0, 0.0, 0.5, 0.5, 0.0, 0.0, -0.5, -0.5]
        stem_samples = [0.0, 0.25, 0.0, -0.25]
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
        self.payload = self.make_payload(
            whole_samples=whole_samples,
            stem_samples=stem_samples,
        )
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
                "<IHHIIHH", 16, 3, channels, 1, block_align, block_align, 32
            )
            + b"data" + struct.pack("<I", len(pcm)) + pcm
        )
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(wav)
        return {
            "sampleRate": 1,
            "channelCount": channels,
            "frameCount": len(samples) // channels,
            "pcmSha256": hashlib.sha256(pcm).hexdigest(),
            "wavPath": path,
            "wavSha256": hashlib.sha256(wav).hexdigest(),
        }

    @staticmethod
    def statistics(samples: list[float]) -> dict[str, object]:
        peak = max((abs(sample) for sample in samples), default=0.0)
        rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples)) \
            if samples else 0.0
        dc = sum(samples) / len(samples) if samples else 0.0
        return {
            "sampleCount": len(samples),
            "finiteSampleCount": len(samples),
            "nonfiniteSampleCount": 0,
            "samplePeak": peak,
            "samplePeakDBFS": baseline.decibels(peak),
            "truePeak": peak,
            "truePeakDBTP": baseline.decibels(peak),
            "rms": rms,
            "crestFactor": peak / rms if rms else 0.0,
            "dcOffset": dc,
            "clippedSampleCount": sum(abs(sample) >= 1 for sample in samples),
            "subnormalSampleCount": 0,
            "exactZeroSampleCount": sum(sample == 0 for sample in samples),
            "nearSilenceSampleCount": sum(
                abs(sample) <= 10 ** (-90 / 20) for sample in samples
            ),
        }

    def evidence(self, channels: list[list[float]]) -> dict[str, object]:
        frame_count = len(channels[0])
        segment_frames = 2

        def window(start: int, count: int) -> dict[str, object]:
            slices = [channel[start:start + count] for channel in channels]
            combined_samples = [sample for channel in slices for sample in channel]
            silent = [
                all(abs(channel[frame]) <= 10 ** (-90 / 20) for channel in slices)
                for frame in range(count)
            ]
            longest = current = 0
            for value in silent:
                current = current + 1 if value else 0
                longest = max(longest, current)
            return {
                "startFrame": start,
                "frameCount": count,
                "combined": self.statistics(combined_samples),
                "channels": [self.statistics(channel) for channel in slices],
                "nearSilentFrameCount": sum(silent),
                "longestNearSilentFrameRun": longest,
            }

        segments = [
            window(start, min(segment_frames, frame_count - start))
            for start in range(0, frame_count, segment_frames)
        ]
        combined_samples = [sample for channel in channels for sample in channel]
        silent = [
            all(abs(channel[frame]) <= 10 ** (-90 / 20) for channel in channels)
            for frame in range(frame_count)
        ]
        longest = current = 0
        for value in silent:
            current = current + 1 if value else 0
            longest = max(longest, current)
        return {
            "schema": baseline.EVIDENCE_SCHEMA,
            "sampleRate": 1,
            "channelCount": len(channels),
            "frameCount": frame_count,
            "segmentFrameCount": segment_frames,
            "combined": self.statistics(combined_samples),
            "channels": [self.statistics(channel) for channel in channels],
            "nearSilentFrameCount": sum(silent),
            "longestNearSilentFrameRun": longest,
            "segments": segments,
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
            "pcmSetFingerprint": baseline.pcm_set_fingerprint(artifacts, scans),
        }

    def make_payload(
        self,
        whole_samples: list[float],
        stem_samples: list[float],
    ) -> dict[str, object]:
        whole_channels = [whole_samples[0::2], whole_samples[1::2]]
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
                "bpm": 130,
                "beatsPerBar": 4,
                "segmentDurationSeconds": 240 / 130,
                "segmentFrameRounding": "nearest-frame",
                "clippingAmplitude": 1,
                "nearSilenceDBFS": -90,
                "nearSilenceAmplitude": 10 ** (-90 / 20),
                "float32MinimumNormal": 1.1754943508222875e-38,
                "decibelFloor": -120,
                "truePeakStandard": "ITU-R BS.1770-5 Annex 2",
                "truePeakOversamplingFactor": 4,
            },
            "inputs": [
                self.input_record("whole-mix", "reports/whole.json"),
                self.input_record("role-stems", "reports/stem.json"),
            ],
            "assets": [
                {
                    "assetId": "fixture--route::kick",
                    "domain": "role-stems",
                    "entryId": "fixture--route",
                    "signal": "kick",
                    "classification": "linear-role",
                    "pcmSha256": self.stem_manifest["entries"][0]["files"][0]["pcmSha256"],
                    "wavPath": "audio/kick.wav",
                    "evidence": self.evidence([stem_samples]),
                },
                {
                    "assetId": "fixture--route::whole-mix",
                    "domain": "whole-mix",
                    "entryId": "fixture--route",
                    "signal": "whole-mix",
                    "classification": "whole-mix",
                    "pcmSha256": self.whole_manifest["entries"][0]["pcmSha256"],
                    "wavPath": "audio/whole.wav",
                    "evidence": self.evidence(whole_channels),
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
        return baseline.check(self.report_path, self.root, output), output.getvalue()

    def test_complete_payload_generates_and_checks(self) -> None:
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("2 assets", diagnostic)
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("current", diagnostic)

    def test_asset_or_segment_coverage_mutation_fails(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["assets"].pop()
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("exactly cover", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["segments"][1]["startFrame"] = 3
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("not contiguous", diagnostic)

    def test_aggregate_metric_and_count_mutation_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["combined"]["rms"] *= 0.5
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("crestFactor", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["combined"][
            "nearSilenceSampleCount"
        ] += 1
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("aggregate", diagnostic)

    def test_manifest_and_report_fingerprint_drift_fail(self) -> None:
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        report = json.loads(self.report_path.read_text())
        report["reportFingerprint"] = "0" * 64
        self.report_path.write_text(json.dumps(report, indent=2) + "\n")
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("stale or mutated", diagnostic)

        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        manifest = copy.deepcopy(self.whole_manifest)
        manifest["engineVersion"] = "engine-v2"
        self.write_json("reports/whole.json", manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("manifest hash is stale", diagnostic)


if __name__ == "__main__":
    unittest.main()
