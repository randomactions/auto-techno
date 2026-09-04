#!/usr/bin/env python3
"""Unit tests for kick/foundation collision report finalization."""

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


MODULE_PATH = Path(__file__).with_name("kick_foundation_collision_report.py")
SPEC = importlib.util.spec_from_file_location(
    "kick_foundation_collision_report", MODULE_PATH
)
assert SPEC is not None and SPEC.loader is not None
collision = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = collision
SPEC.loader.exec_module(collision)


class KickFoundationCollisionReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write_json("docs/BASELINE_CORPUS.json", {"fixture": "v1"})
        self.write_json(
            "docs/ROADMAP_EXECUTION_BASELINE.json",
            {"snapshotFingerprint": "a" * 64},
        )
        self.sample_rate = 44_100
        self.bar_frames = collision.nearest_frame(
            self.sample_rate * 240.0 / 130.0
        )
        self.onset = collision.nearest_frame(4 * self.bar_frames / 16.0)
        self.end = self.onset + collision.nearest_frame(self.bar_frames / 8.0)
        kick = [0.0] * self.bar_frames
        foundation = [0.0] * self.bar_frames
        for frame in range(self.onset, self.end):
            sample = 0.15 * math.sin(
                2 * math.pi * 60 * (frame - self.onset) / self.sample_rate
            )
            kick[frame] = sample
            foundation[frame] = sample
        whole = self.write_asset(
            "audio/whole.wav", [0.0, 0.0] * self.bar_frames, channels=2
        )
        kick_file = self.write_asset("audio/kick.wav", kick, channels=1)
        kick_file.update({"signal": "kick", "classification": "linear-role"})
        foundation_file = self.write_asset(
            "audio/foundation.wav", foundation, channels=1
        )
        foundation_file.update({
            "signal": "foundation", "classification": "linear-role",
        })
        identity = {
            "id": "fixture--route",
            "caseId": "fixture",
            "routeId": "route",
            "rootSeed": 7,
            "checkpoint": "establishment",
            "continuationClass": "initial",
            "phraseIndex": 0,
            "startBar": 0,
            "phraseKind": "lock",
            "stateFingerprint": "1" * 16,
            "planFingerprint": "2" * 16,
            "replayFingerprint": "3" * 16,
            "policyVersion": "policy-v1",
            "qualityOutcome": "qualified",
            "sampleRate": self.sample_rate,
            "frameCount": self.bar_frames,
        }
        self.whole_manifest = {
            "schema": collision.pcm.WHOLE_SCHEMA,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "a" * 64,
            "entries": [{**identity, "channelCount": 2, **whole}],
        }
        self.stem_manifest = {
            "schema": collision.pcm.STEM_SCHEMA,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "contractBaselineFingerprint": "a" * 64,
            "entries": [{
                **identity,
                "wholeMixChannelCount": 2,
                "wholeMixPcmSha256": whole["pcmSha256"],
                "files": [foundation_file, kick_file],
            }],
        }
        self.write_json("reports/whole.json", self.whole_manifest)
        self.write_json("reports/stem.json", self.stem_manifest)
        self.payload = self.make_payload(kick, foundation)
        self.payload_path = self.root / "payload.json"
        self.report_path = self.root / "report.json"
        self.write_json("payload.json", self.payload)

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
        manifest = collision.pcm.load_json(manifest_path, domain)
        _, artifacts = collision.pcm.extract_artifacts(manifest, self.root, domain)
        cache: dict[Path, collision.pcm.ScannedWav] = {}
        scans = {
            identifier: collision.pcm.scan_artifact(artifact, cache)
            for identifier, artifact in artifacts.items()
        }
        return {
            "domain": domain,
            "manifestPath": path,
            "manifestSha256": collision.pcm.sha256(manifest_path),
            "manifestSchema": manifest["schema"],
            "assetCount": len(artifacts),
            "pcmSetFingerprint": collision.signal.pcm_set_fingerprint(
                artifacts, scans
            ),
        }

    def make_payload(
        self, kick: list[float], foundation: list[float]
    ) -> dict[str, object]:
        kick_windows = collision.band_windows(
            kick[self.onset:self.end], self.sample_rate
        )
        foundation_windows = collision.band_windows(
            foundation[self.onset:self.end], self.sample_rate
        )
        windows: list[dict[str, object]] = []
        for index, (kick_item, foundation_item) in enumerate(zip(
            kick_windows, foundation_windows
        )):
            kick_ms = kick_item["sourceMeanSquare"]
            foundation_ms = foundation_item["sourceMeanSquare"]
            kick_sub = kick_item["bandMeanSquares"][0]
            foundation_sub = foundation_item["bandMeanSquares"][0]
            active = (
                kick_ms > collision.ACTIVITY_THRESHOLD
                and foundation_ms > collision.ACTIVITY_THRESHOLD
            )
            similarity = min(kick_sub, foundation_sub) / max(
                kick_sub, foundation_sub
            )
            low = active and similarity > collision.OVERLAP_THRESHOLD
            windows.append({
                "index": index,
                "startFrame": self.onset + kick_item["startFrame"],
                "frameCount": kick_item["frameCount"],
                "kickMeanSquare": kick_ms,
                "foundationMeanSquare": foundation_ms,
                "kickSubMeanSquare": kick_sub,
                "foundationSubMeanSquare": foundation_sub,
                "kickActive": True,
                "foundationActive": True,
                "temporalOverlap": True,
                "subBandSimilarity": similarity,
                "lowBandOverlap": low,
            })
        temporal_frames = sum(item["frameCount"] for item in windows)
        low_windows = [item for item in windows if item["lowBandOverlap"]]
        low_frames = sum(item["frameCount"] for item in low_windows)
        event = {
            "id": "fixture--route--bar-0-step-4",
            "bar": 0,
            "step": 4,
            "onsetFrame": self.onset,
            "analysisEndFrame": self.end,
            "analysisFrameCount": self.end - self.onset,
            "collisionClass": "low-band-overlap",
            "responsibleSignals": ["kick", "foundation"],
            "authoredFoundationRolesInBar": ["bass"],
            "pocketState": "not-authored",
            "pocketSilenceFrameCount": 0,
            "kickActiveWindowCount": 16,
            "foundationActiveWindowCount": 16,
            "temporalOverlapWindowCount": 16,
            "temporalOverlapFrameCount": temporal_frames,
            "temporalOverlapSeconds": temporal_frames / self.sample_rate,
            "longestTemporalOverlapFrameCount": temporal_frames,
            "lowBandOverlapWindowCount": len(low_windows),
            "lowBandOverlapFrameCount": low_frames,
            "lowBandOverlapSeconds": low_frames / self.sample_rate,
            "longestLowBandOverlapFrameCount": low_frames,
            "firstTemporalOverlapFrame": windows[0]["startFrame"],
            "lastTemporalOverlapEndFrame": self.end,
            "firstLowBandOverlapFrame": low_windows[0]["startFrame"],
            "lastLowBandOverlapEndFrame": self.end,
            "maximumSubBandSimilarity": max(
                item["subBandSimilarity"] for item in windows
            ),
            "kickOverFoundationDB": 0.0,
            "durationResolutionMaximumFrames": max(
                item["frameCount"] for item in windows
            ),
            "confidence": collision.CONFIDENCE,
            "windows": windows,
            "finite": True,
        }
        entry = self.whole_manifest["entries"][0]
        stem_files = {
            item["signal"]: item
            for item in self.stem_manifest["entries"][0]["files"]
        }
        return {
            "schema": collision.REPORT_SCHEMA,
            "reportVersion": 1,
            "analyzerVersion": collision.ANALYZER_VERSION,
            "corpusSha256": collision.pcm.sha256(
                self.root / "docs/BASELINE_CORPUS.json"
            ),
            "contractBaselineFingerprint": "a" * 64,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "policies": {
                "bpm": 130,
                "beatsPerBar": 4,
                "scoreStepsPerBar": 16,
                "eventWindowSteps": 2,
                "eventWindowRounding": "nearest-frame-bar-relative",
                "windowsPerEvent": 16,
                "activityMeanSquareThreshold": collision.ACTIVITY_THRESHOLD,
                "lowBand": collision.BAND,
                "lowBandOverlapThreshold": collision.OVERLAP_THRESHOLD,
                "bandEnergyModel": collision.BAND_MODEL,
                "durationModel": collision.DURATION_MODEL,
                "eventSource": collision.EVENT_SOURCE,
                "confidence": collision.CONFIDENCE,
                "relativeEnergyUnit": collision.RELATIVE_UNIT,
                "relativeEnergyInterpretation":
                    collision.RELATIVE_INTERPRETATION,
                "phasePolicy":
                    "per-role-energy-only-no-role-sum-cancellation-inference",
                "noKickPolicy":
                    "valid-entry-with-zero-eligible-events-and-explicit-bars",
            },
            "inputs": [
                self.input_record("whole-mix", "reports/whole.json"),
                self.input_record("role-stems", "reports/stem.json"),
            ],
            "entries": [{
                **{
                    key: entry[key] for key in (
                        "id", "caseId", "routeId", "rootSeed", "checkpoint",
                        "continuationClass", "phraseIndex", "startBar",
                        "phraseKind", "stateFingerprint", "planFingerprint",
                        "replayFingerprint", "sampleRate", "frameCount",
                    )
                },
                "candidateEvaluationFingerprint": "4" * 16,
                "kickPcmSha256": stem_files["kick"]["pcmSha256"],
                "foundationPcmSha256":
                    stem_files["foundation"]["pcmSha256"],
                "barCount": 1,
                "barsWithoutKick": [],
                "evidence": {
                    "schema": collision.EVIDENCE_SCHEMA,
                    "sampleRate": self.sample_rate,
                    "frameCount": self.bar_frames,
                    "kickSignal": "kick",
                    "foundationSignal": "foundation",
                    "eventSource": collision.EVENT_SOURCE,
                    "analysisWindow": collision.ANALYSIS_WINDOW,
                    "windowsPerEvent": 16,
                    "activityMeanSquareThreshold": collision.ACTIVITY_THRESHOLD,
                    "lowBand": collision.BAND,
                    "lowBandOverlapThreshold": collision.OVERLAP_THRESHOLD,
                    "bandEnergyModel": collision.BAND_MODEL,
                    "durationModel": collision.DURATION_MODEL,
                    "relativeEnergyUnit": collision.RELATIVE_UNIT,
                    "relativeEnergyInterpretation":
                        collision.RELATIVE_INTERPRETATION,
                    "events": [event],
                    "finite": True,
                },
            }],
        }

    def generate(self) -> tuple[int, str]:
        output = io.StringIO()
        return collision.generate(
            self.payload_path, self.report_path, self.root, output
        ), output.getvalue()

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return collision.check(self.report_path, self.root, output), output.getvalue()

    def write_payload(self, value: object) -> None:
        self.write_json("payload.json", value)

    def test_complete_payload_generates_and_checks(self) -> None:
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("1 events", diagnostic)
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("score-bound events", diagnostic)

    def test_window_energy_or_overlap_mutation_fails(self) -> None:
        mutated = copy.deepcopy(self.payload)
        event = mutated["entries"][0]["evidence"]["events"][0]
        event["windows"][0]["kickSubMeanSquare"] *= 2
        self.write_payload(mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("does not recompute", diagnostic)

        mutated = copy.deepcopy(self.payload)
        mutated["entries"][0]["evidence"]["events"][0][
            "collisionClass"
        ] = "separated"
        self.write_payload(mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("collisionClass", diagnostic)

    def test_duration_geometry_and_optional_mutations_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        event = mutated["entries"][0]["evidence"]["events"][0]
        event["temporalOverlapFrameCount"] -= 1
        self.write_payload(mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("aggregate", diagnostic)

        mutated = copy.deepcopy(self.payload)
        event = mutated["entries"][0]["evidence"]["events"][0]
        del event["kickOverFoundationDB"]
        self.write_payload(mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("kickOverFoundationDB", diagnostic)

    def test_event_identity_and_pocket_claim_mutations_fail(self) -> None:
        mutated = copy.deepcopy(self.payload)
        mutated["entries"][0]["evidence"]["events"][0]["onsetFrame"] += 1
        self.write_payload(mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("geometry", diagnostic)

        mutated = copy.deepcopy(self.payload)
        event = mutated["entries"][0]["evidence"]["events"][0]
        event["pocketState"] = "exact-silence"
        event["pocketSilenceFrameCount"] = 10
        # Place nonzero PCM immediately before onset so the exact claim fails.
        foundation_path = self.root / "audio/foundation.wav"
        data = bytearray(foundation_path.read_bytes())
        data[44 + (self.onset - 1) * 4:44 + self.onset * 4] = struct.pack(
            "<f", 0.1
        )
        foundation_path.write_bytes(data)
        self.write_payload(mutated)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertTrue(
            "pcmSha256" in diagnostic or "exact pocket" in diagnostic,
            diagnostic,
        )

    def test_manifest_and_fingerprint_drift_fail(self) -> None:
        result, diagnostic = self.generate()
        self.assertEqual(result, 0, diagnostic)
        report = json.loads(self.report_path.read_text())
        report["entries"][0]["candidateEvaluationFingerprint"] = "5" * 16
        self.write_json("report.json", report)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("reportFingerprint", diagnostic)

        self.write_json(
            "docs/ROADMAP_EXECUTION_BASELINE.json",
            {"snapshotFingerprint": "d" * 64},
        )
        self.write_payload(self.payload)
        result, diagnostic = self.generate()
        self.assertEqual(result, 1)
        self.assertIn("contractBaselineFingerprint", diagnostic)


if __name__ == "__main__":
    unittest.main()
