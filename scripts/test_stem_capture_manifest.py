#!/usr/bin/env python3
"""Unit tests for aligned local role-stem manifest verification."""

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


MODULE_PATH = Path(__file__).with_name("stem_capture_manifest.py")
SPEC = importlib.util.spec_from_file_location("stem_capture_manifest", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
stems = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = stems
SPEC.loader.exec_module(stems)


class StemCaptureManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source_root = MODULE_PATH.parents[1]
        corpus = json.loads((source_root / "docs/BASELINE_CORPUS.json").read_text())
        self.write_json("docs/BASELINE_CORPUS.json", corpus)
        self.write_json(
            "docs/ROADMAP_EXECUTION_BASELINE.json",
            {"snapshotFingerprint": "a" * 64},
        )
        whole_entries = []
        stem_entries = []
        for case in corpus["cases"]:
            for route in corpus["routes"]:
                identifier = f"{case['id']}--{route['id']}"
                whole_samples = [0.625, 0.625, -0.625, -0.625]
                whole_wav, whole_pcm = self.wav(
                    route["sampleRate"], 2, whole_samples
                )
                whole_path = (
                    f"docs/local/audio/baseline-corpus-v1/{identifier}.wav"
                )
                self.write_bytes(whole_path, whole_wav)
                whole_entry = {
                    "id": identifier,
                    "caseId": case["id"],
                    "routeId": route["id"],
                    "rootSeed": case["rootSeed"],
                    "checkpoint": case["checkpoint"],
                    "continuationClass": case["continuationClass"],
                    "phraseIndex": 1,
                    "startBar": 8,
                    "phraseKind": "lock",
                    "stateFingerprint": "1" * 16,
                    "planFingerprint": "2" * 16,
                    "replayFingerprint": "3" * 16,
                    "policyVersion": "policy-v1",
                    "qualityOutcome": "qualified",
                    "sampleRate": route["sampleRate"],
                    "channelCount": 2,
                    "frameCount": 2,
                    "pcmSha256": hashlib.sha256(whole_pcm).hexdigest(),
                    "wavPath": whole_path,
                    "wavSha256": hashlib.sha256(whole_wav).hexdigest(),
                }
                whole_entries.append(whole_entry)
                files = []
                for signal, (classification, channels) in stems.SIGNALS.items():
                    samples = self.samples(signal, channels)
                    wav, pcm = self.wav(route["sampleRate"], channels, samples)
                    wav_path = (
                        "docs/local/audio/baseline-stems-v1/"
                        f"{identifier}--{signal}.wav"
                    )
                    self.write_bytes(wav_path, wav)
                    files.append({
                        "signal": signal,
                        "classification": classification,
                        "channelCount": channels,
                        "sampleRate": route["sampleRate"],
                        "frameCount": 2,
                        "pcmSha256": hashlib.sha256(pcm).hexdigest(),
                        "wavPath": wav_path,
                        "wavSha256": hashlib.sha256(wav).hexdigest(),
                    })
                stem_entries.append({
                    "id": identifier,
                    "caseId": case["id"],
                    "routeId": route["id"],
                    "rootSeed": case["rootSeed"],
                    "checkpoint": case["checkpoint"],
                    "continuationClass": case["continuationClass"],
                    "phraseIndex": 1,
                    "startBar": 8,
                    "phraseKind": "lock",
                    "stateFingerprint": "1" * 16,
                    "planFingerprint": "2" * 16,
                    "replayFingerprint": "3" * 16,
                    "policyVersion": "policy-v1",
                    "qualityOutcome": "qualified",
                    "sampleRate": route["sampleRate"],
                    "wholeMixChannelCount": 2,
                    "frameCount": 2,
                    "wholeMixPcmSha256": whole_entry["pcmSha256"],
                    "reconstruction": {
                        "protectedFoundationMaximumError": 0.0,
                        "dryCenterMaximumError": 0.0,
                        "dryUpperMaximumError": 0.0,
                        "protectedPassMaximumError": 0.0,
                        "preClimaxMaximumError": 0.0,
                        "finalMixMaximumError": 0.0,
                        "tolerance": stems.TOLERANCE,
                    },
                    "files": sorted(files, key=lambda item: item["signal"]),
                })
        self.whole = {
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "entries": whole_entries,
        }
        self.write_json(
            "docs/local/reports/baseline-corpus-v1/manifest.json", self.whole
        )
        corpus_bytes = (self.root / "docs/BASELINE_CORPUS.json").read_bytes()
        whole_path = self.root / "docs/local/reports/baseline-corpus-v1/manifest.json"
        self.manifest = {
            "schema": stems.SCHEMA,
            "manifestVersion": 1,
            "corpusSha256": hashlib.sha256(corpus_bytes).hexdigest(),
            "wholeMixManifestSha256": hashlib.sha256(
                whole_path.read_bytes()
            ).hexdigest(),
            "contractBaselineFingerprint": "a" * 64,
            "sourceFingerprint": "b" * 64,
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "nonlinearExceptions": [
                {
                    "id": "voice-shared-processing",
                    "stage": "voice-renderer",
                    "reason": "shared",
                    "residualSignal": None,
                },
                {
                    "id": "modal-post-master-insertion",
                    "stage": "protected-modal-foundation",
                    "reason": "protected",
                    "residualSignal": None,
                },
                {
                    "id": "outer-output-safety",
                    "stage": "outer",
                    "reason": "nonlinear",
                    "residualSignal": "output-safety-residual",
                },
                {
                    "id": "terminal-processing",
                    "stage": "terminal",
                    "reason": "shared",
                    "residualSignal": "terminal-processing-residual",
                },
            ],
            "entries": sorted(stem_entries, key=lambda item: item["id"]),
        }
        self.write_manifest(self.manifest)

    @staticmethod
    def samples(signal: str, channels: int) -> list[float]:
        mono = {
            "kick": [0.125, -0.125],
            "foundation": [0.25, -0.25],
            "modal-foundation": [0.125, -0.125],
            "protected-foundation": [0.375, -0.375],
            "percussion": [0.125, -0.125],
            "dry-center-reference": [0.375, -0.375],
            "upper-tonal": [0.125, -0.125],
            "atmosphere": [0.125, -0.125],
            "dry-upper-reference": [0.25, -0.25],
        }
        if channels == 1:
            return mono[signal]
        stereo = {
            "protected-rhythm": [0.25, 0.25, -0.25, -0.25],
            "graph-input": [0.125, 0.125, -0.125, -0.125],
            "processed-upper": [0.125, 0.125, -0.125, -0.125],
            "pre-climax-mix": [0.5, 0.5, -0.5, -0.5],
            "output-safety-residual": [0.125, 0.125, -0.125, -0.125],
            "terminal-processing-residual": [0.125, 0.125, -0.125, -0.125],
        }
        return stereo[signal]

    def write_json(self, path: str, value: object) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(value, indent=2) + "\n")

    def write_bytes(self, path: str, value: bytes) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(value)

    def write_manifest(self, value: object) -> None:
        self.write_json(
            "docs/local/reports/baseline-stems-v1/manifest.json", value
        )

    @staticmethod
    def wav(rate: int, channels: int, samples: list[float]) -> tuple[bytes, bytes]:
        pcm = b"".join(struct.pack("<f", sample) for sample in samples)
        block_align = channels * 4
        header = (
            b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt "
            + struct.pack(
                "<IHHIIHH", 16, 3, channels, rate,
                rate * block_align, block_align, 32
            )
            + b"data" + struct.pack("<I", len(pcm))
        )
        return header + pcm, pcm

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return stems.run_check(self.root, output), output.getvalue()

    def test_complete_manifest_passes(self) -> None:
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("14 identities x 15", diagnostic)

    def test_missing_signal_and_extra_wav_fail(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["entries"][0]["files"].pop()
        self.write_manifest(manifest)
        wav, _ = self.wav(44_100, 1, [0.0])
        self.write_bytes("docs/local/audio/baseline-stems-v1/extra.wav", wav)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("must contain exactly", diagnostic)
        self.assertIn("unreferenced WAVs", diagnostic)

    def test_pcm_mutation_and_reconstruction_fail(self) -> None:
        entry = self.manifest["entries"][0]
        stem = next(item for item in entry["files"] if item["signal"] == "kick")
        path = self.root / stem["wavPath"]
        data = bytearray(path.read_bytes())
        data[-4:] = struct.pack("<f", 0.5)
        path.write_bytes(data)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("pcmSha256", diagnostic)
        self.assertIn("protectedFoundationMaximumError", diagnostic)

    def test_manifest_bindings_and_exception_taxonomy_fail(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["sourceFingerprint"] = "d" * 64
        manifest["nonlinearExceptions"][2]["residualSignal"] = "kick"
        self.write_manifest(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("sourceFingerprint", diagnostic)
        self.assertIn("not a residual signal", diagnostic)


if __name__ == "__main__":
    unittest.main()
