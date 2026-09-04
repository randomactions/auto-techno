#!/usr/bin/env python3
"""Tests for independent transient/envelope baseline verification."""

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


MODULE_PATH = Path(__file__).with_name("transient_envelope_baseline_report.py")
SPEC = importlib.util.spec_from_file_location(
    "transient_envelope_baseline_report", MODULE_PATH
)
assert SPEC is not None and SPEC.loader is not None
baseline = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = baseline
SPEC.loader.exec_module(baseline)


class TransientEnvelopeBaselineReportTests(unittest.TestCase):
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
        mono = self.envelope(0.020, 0.080, lambda value: value)
        stereo = [value for sample in mono for value in (sample, sample)]
        whole = self.write_asset("audio/whole.wav", stereo, channels=2)
        whole["id"] = "fixture--route"
        stem = self.write_asset("audio/kick.wav", mono, channels=1)
        stem.update({"signal": "kick", "classification": "linear-role"})
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

    def envelope(
        self,
        attack_seconds: float,
        decay_seconds: float,
        curve: object,
        sample_rate: int = 48_000,
    ) -> list[float]:
        silence = round(sample_rate * 0.020)
        attack = max(2, round(sample_rate * attack_seconds))
        decay = max(2, round(sample_rate * decay_seconds))
        result = [0.0] * (silence + attack + decay + sample_rate // 4)
        assert callable(curve)
        for index in range(attack):
            progress = index / (attack - 1)
            result[silence + index] = float(curve(progress))
        for index in range(decay):
            result[silence + attack + index] = 1.0 - index / (decay - 1)
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
                    "fixture--route::kick", "role-stems", "kick",
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

    def test_event_geometry_and_summary_mutations_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["events"][0]["attack90Frame"] += 1
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("attack90Frame", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["assets"][0]["evidence"]["summary"]["crestFactor"] += 0.1
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("crestFactor", diagnostic)

    def test_policy_manifest_and_fingerprint_mutations_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["policies"]["onsetAuthority"] = "score-bound"
        self.write_json("payload.json", mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("onsetAuthority", diagnostic)

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
        report["assets"][0]["evidence"]["summary"]["shapeEventCount"] += 1
        self.write_json("report.json", report)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertTrue(
            "shapeEventCount" in diagnostic or "reportFingerprint" in diagnostic
        )

    def test_independent_synthetic_signs(self) -> None:
        linear = baseline.analyze_pcm(
            [self.envelope(0.050, 0.060, lambda value: value)],
            self.sample_rate, self.sample_rate,
        )
        concave_up = baseline.analyze_pcm(
            [self.envelope(0.050, 0.060, lambda value: value * value)],
            self.sample_rate, self.sample_rate,
        )
        concave_down = baseline.analyze_pcm(
            [self.envelope(0.050, 0.060, math.sqrt)],
            self.sample_rate, self.sample_rate,
        )
        short = baseline.analyze_pcm(
            [self.envelope(0.002, 0.025, lambda value: value)],
            self.sample_rate, self.sample_rate,
        )
        long = baseline.analyze_pcm(
            [self.envelope(0.002, 0.180, lambda value: value)],
            self.sample_rate, self.sample_rate,
        )
        linear_event = linear["events"][0]
        self.assertLess(
            concave_up["events"][0]["attackMeanNormalizedEnvelope"],
            linear_event["attackMeanNormalizedEnvelope"],
        )
        self.assertLess(
            linear_event["attackMeanNormalizedEnvelope"],
            concave_down["events"][0]["attackMeanNormalizedEnvelope"],
        )
        self.assertLess(
            short["events"][0]["decayOccupancy"],
            long["events"][0]["decayOccupancy"],
        )

    def test_amplitude_sample_rate_and_phase_behavior(self) -> None:
        source = self.envelope(0.035, 0.090, lambda value: value * value)
        scaled = [value * 0.25 for value in source]
        loud = baseline.analyze_pcm([source], self.sample_rate, self.sample_rate)
        quiet = baseline.analyze_pcm([scaled], self.sample_rate, self.sample_rate)
        self.assertEqual(
            loud["events"][0]["attackRiseFrameCount"],
            quiet["events"][0]["attackRiseFrameCount"],
        )
        self.assertAlmostEqual(
            loud["events"][0]["decayOccupancy"],
            quiet["events"][0]["decayOccupancy"],
        )
        cancelled = baseline.analyze_pcm(
            [source, [-value for value in source]],
            self.sample_rate, self.sample_rate,
        )
        self.assertEqual(cancelled["events"], [])
        self.assertEqual(cancelled["summary"]["crestFactor"], 0.0)

        source44 = self.envelope(
            0.040, 0.100, lambda value: value, sample_rate=44_100
        )
        source48 = self.envelope(
            0.040, 0.100, lambda value: value, sample_rate=48_000
        )
        evidence44 = baseline.analyze_pcm([source44], 44_100, 44_100)
        evidence48 = baseline.analyze_pcm([source48], 48_000, 48_000)
        self.assertAlmostEqual(
            evidence44["events"][0]["attackRiseSeconds"],
            evidence48["events"][0]["attackRiseSeconds"],
            delta=0.0001,
        )


if __name__ == "__main__":
    unittest.main()
