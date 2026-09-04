#!/usr/bin/env python3
"""Tests for independent stereo compatibility baseline verification."""

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


MODULE_PATH = Path(__file__).with_name("stereo_compatibility_baseline_report.py")
SPEC = importlib.util.spec_from_file_location(
    "stereo_compatibility_baseline_report", MODULE_PATH
)
assert SPEC is not None and SPEC.loader is not None
baseline = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = baseline
SPEC.loader.exec_module(baseline)


class StereoCompatibilityBaselineReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.sample_rate = 48_000
        self.write_json("docs/BASELINE_CORPUS.json", {"fixture": "v1"})
        self.write_json(
            "docs/ROADMAP_EXECUTION_BASELINE.json",
            {"snapshotFingerprint": "a" * 64},
        )
        mono = self.tone(211.0, frames=9_600)
        anti = [-value for value in mono]
        whole = self.write_asset("audio/whole.wav", mono, mono)
        whole["id"] = "fixture--route"
        stem = self.write_asset("audio/upper.wav", mono, anti)
        stem.update({"signal": "upper", "classification": "linear-role"})
        self.whole_manifest = {
            "schema": baseline.pcm.WHOLE_SCHEMA,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "a" * 64,
            "entries": [whole],
        }
        self.stem_manifest = {
            "schema": baseline.pcm.STEM_SCHEMA,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "a" * 64,
            "entries": [{"id": "fixture--route", "files": [stem]}],
        }
        self.write_json("reports/whole.json", self.whole_manifest)
        self.write_json("reports/stem.json", self.stem_manifest)
        self.payload_path = self.root / "payload.json"
        self.report_path = self.root / "report.json"
        self.payload = self.make_payload()
        self.write_json("payload.json", self.payload)

    def tone(
        self,
        frequency: float,
        frames: int,
        sample_rate: int = 48_000,
    ) -> list[float]:
        return [
            math.sin(2.0 * math.pi * frequency * frame / sample_rate) * 0.25
            for frame in range(frames)
        ]

    def write_json(self, path: str, value: object) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    def write_asset(
        self, path: str, left: list[float], right: list[float] | None
    ) -> dict[str, object]:
        channels = [left] if right is None else [left, right]
        interleaved = [
            channels[channel][frame]
            for frame in range(len(left))
            for channel in range(len(channels))
        ]
        pcm_bytes = b"".join(struct.pack("<f", sample) for sample in interleaved)
        block_align = 4 * len(channels)
        wav = (
            b"RIFF" + struct.pack("<I", 36 + len(pcm_bytes)) + b"WAVEfmt "
            + struct.pack(
                "<IHHIIHH", 16, 3, len(channels), self.sample_rate,
                self.sample_rate * block_align, block_align, 32,
            )
            + b"data" + struct.pack("<I", len(pcm_bytes)) + pcm_bytes
        )
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(wav)
        return {
            "sampleRate": self.sample_rate,
            "channelCount": len(channels),
            "frameCount": len(left),
            "pcmSha256": hashlib.sha256(pcm_bytes).hexdigest(),
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

    def asset_record(
        self,
        identifier: str,
        domain: str,
        signal_name: str,
        classification: str,
        fields: dict[str, object],
    ) -> dict[str, object]:
        sample_rate, channels = baseline.read_channels(
            self.root / str(fields["wavPath"])
        )
        segment_frames = baseline.rounded_frames(
            sample_rate * 240.0 / 130.0
        )
        return {
            "assetId": identifier,
            "domain": domain,
            "entryId": "fixture--route",
            "signal": signal_name,
            "classification": classification,
            "pcmSha256": fields["pcmSha256"],
            "wavPath": fields["wavPath"],
            "evidence": baseline.analyze_pcm(
                channels, sample_rate, segment_frames
            ),
        }

    def make_payload(self) -> dict[str, object]:
        whole = self.whole_manifest["entries"][0]
        stem = self.stem_manifest["entries"][0]["files"][0]
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
            "inputs": [
                self.input_record("whole-mix", "reports/whole.json"),
                self.input_record("role-stems", "reports/stem.json"),
            ],
            "assets": sorted([
                self.asset_record(
                    "fixture--route::whole-mix", "whole-mix", "whole-mix",
                    "whole-mix", whole,
                ),
                self.asset_record(
                    "fixture--route::upper", "role-stems", "upper",
                    "linear-role", stem,
                ),
            ], key=lambda item: str(item["assetId"])),
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
        self.assertIn("2 assets", diagnostic)
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("independently recomputed", diagnostic)

    def test_metric_state_and_null_mutations_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        domain = mutated["assets"][0]["evidence"]["summary"][0]
        domain["sideEnergyShare"] = 0.25
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("sideEnergyShare", diagnostic)

        mutated = copy.deepcopy(self.payload)
        domain = mutated["assets"][1]["evidence"]["summary"][0]
        domain["state"] = "mixed"
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("state", diagnostic)

        mutated = copy.deepcopy(self.payload)
        domain = mutated["assets"][0]["evidence"]["summary"][0]
        domain["sideToMidRatio"] = 0.0
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("sideToMidRatio", diagnostic)

    def test_policy_manifest_and_fingerprint_mutations_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["policies"]["bandFilterCutoffsHz"][1] = 121.0
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("bandFilterCutoffsHz", diagnostic)

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
        report["reportFingerprint"] = "e" * 64
        self.write_json("report.json", report)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("reportFingerprint", diagnostic)

    def test_independent_structural_states_and_energy_identity(self) -> None:
        source = self.tone(377.0, frames=4_800)
        silence = [0.0] * len(source)
        fixtures = {
            "safeExactMono": [source, source],
            "unsafeExactCancellation": [source, [-value for value in source]],
            "oneSided": [source, silence],
            "mixed": [source, [value * 0.5 for value in source]],
            "inactive": [silence, silence],
        }
        for state, channels in fixtures.items():
            evidence = baseline.analyze_pcm(
                channels, self.sample_rate, len(source)
            )
            full = evidence["summary"][0]
            self.assertEqual(full["state"], state)
            self.assertAlmostEqual(
                full["stereoMeanSquare"],
                full["midMeanSquare"] + full["sideMeanSquare"],
            )
        self.assertEqual(
            baseline.analyze_pcm(
                fixtures["safeExactMono"], self.sample_rate, len(source)
            )["summary"][0]["correlation"],
            1.0,
        )
        self.assertEqual(
            baseline.analyze_pcm(
                fixtures["unsafeExactCancellation"],
                self.sample_rate, len(source),
            )["summary"][0]["correlation"],
            -1.0,
        )

    def test_native_mono_matches_dual_mono_and_preserves_channel_count(self) -> None:
        source = self.tone(521.0, frames=4_800)
        native = baseline.analyze_pcm(
            [source], self.sample_rate, len(source)
        )
        dual = baseline.analyze_pcm(
            [source, source], self.sample_rate, len(source)
        )
        self.assertEqual(native["sourceChannelCount"], 1)
        self.assertEqual(dual["sourceChannelCount"], 2)
        self.assertEqual(native["summary"], dual["summary"])
        self.assertEqual(native["segments"], dual["segments"])

    def test_scale_rate_band_and_partial_segment_behavior(self) -> None:
        source = self.tone(70.0, frames=4_801)
        right = [value * 0.3 for value in source]
        original = baseline.analyze_pcm(
            [source, right], self.sample_rate, 2_400
        )
        scaled = baseline.analyze_pcm(
            [[value * 0.25 for value in source],
             [value * 0.25 for value in right]],
            self.sample_rate, 2_400,
        )
        self.assertEqual(
            [segment["frameCount"] for segment in original["segments"]],
            [2_400, 2_400, 1],
        )
        for first, second in zip(original["summary"], scaled["summary"]):
            self.assertAlmostEqual(
                first["monoRetentionRatio"], second["monoRetentionRatio"],
            )
            self.assertAlmostEqual(
                first["sideEnergyShare"], second["sideEnergyShare"],
            )
        self.assertGreater(
            original["summary"][1]["stereoMeanSquare"],
            original["summary"][4]["stereoMeanSquare"] * 20,
        )
        source44 = self.tone(211.0, frames=4_410, sample_rate=44_100)
        source48 = self.tone(211.0, frames=4_800, sample_rate=48_000)
        self.assertEqual(
            baseline.analyze_pcm(
                [source44, source44], 44_100, 2_205
            )["summary"][0]["state"],
            baseline.analyze_pcm(
                [source48, source48], 48_000, 2_400
            )["summary"][0]["state"],
        )


if __name__ == "__main__":
    unittest.main()
