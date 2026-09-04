#!/usr/bin/env python3
"""Unit tests for local baseline-render evidence verification."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import io
import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("baseline_render_manifest.py")
SPEC = importlib.util.spec_from_file_location("baseline_render_manifest", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
renders = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = renders
SPEC.loader.exec_module(renders)


class BaselineRenderManifestTests(unittest.TestCase):
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
        self.write_bytes("Package.swift", b"// package fixture\n")
        self.write_bytes("Sources/Fixture/Voice.swift", b"// source fixture\n")
        self.write_bytes("Sources/Fixture/Resources/profile.bin", b"\x00\x80\xff")
        entries = []
        for case in corpus["cases"]:
            for route in corpus["routes"]:
                identifier = f"{case['id']}--{route['id']}"
                wav_path = f"docs/local/audio/baseline-corpus-v1/{identifier}.wav"
                wav, pcm = self.wav(route["sampleRate"], [0.0, 0.25, -0.25, 0.0])
                self.write_bytes(wav_path, wav)
                entries.append({
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
                    "pcmSha256": hashlib.sha256(pcm).hexdigest(),
                    "wavPath": wav_path,
                    "wavSha256": hashlib.sha256(wav).hexdigest(),
                })
        corpus_bytes = (self.root / "docs/BASELINE_CORPUS.json").read_bytes()
        self.manifest = {
            "schema": renders.SCHEMA,
            "manifestVersion": 1,
            "corpusSha256": hashlib.sha256(corpus_bytes).hexdigest(),
            "contractBaselineFingerprint": "a" * 64,
            "sourceFingerprint": self.expected_source_fingerprint(),
            "gitHead": "c" * 40,
            "engineVersion": "engine-v1",
            "entries": entries,
        }
        self.write_manifest(self.manifest)

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
            "docs/local/reports/baseline-corpus-v1/manifest.json", value
        )

    def expected_source_fingerprint(self) -> str:
        # Explicit fixture paths independently pin the exporter's sorted
        # path + NUL + bytes format, including non-Swift source resources.
        paths = [
            "Package.swift",
            "Sources/Fixture/Resources/profile.bin",
            "Sources/Fixture/Voice.swift",
            "docs/BASELINE_CORPUS.json",
            "docs/ROADMAP_EXECUTION_BASELINE.json",
        ]
        return hashlib.sha256(b"".join(
            path.encode("utf-8") + b"\0" + (self.root / path).read_bytes()
            for path in paths
        )).hexdigest()

    @staticmethod
    def wav(rate: int, samples: list[float]) -> tuple[bytes, bytes]:
        pcm = b"".join(struct.pack("<f", sample) for sample in samples)
        header = (
            b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt "
            + struct.pack("<IHHIIHH", 16, 3, 2, rate, rate * 8, 8, 32)
            + b"data" + struct.pack("<I", len(pcm))
        )
        return header + pcm, pcm

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return renders.run_check(self.root, output), output.getvalue()

    def test_complete_manifest_passes(self) -> None:
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("14 exact", diagnostic)

    def test_missing_and_duplicate_identities_fail(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["entries"][-1] = copy.deepcopy(manifest["entries"][0])
        self.write_manifest(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("duplicate entry id", diagnostic)
        self.assertIn("omits identities", diagnostic)

    def test_wav_and_pcm_hash_mutation_fails(self) -> None:
        entry = self.manifest["entries"][0]
        path = self.root / entry["wavPath"]
        data = bytearray(path.read_bytes())
        data[-1] ^= 1
        path.write_bytes(data)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("pcmSha256", diagnostic)
        self.assertIn("wavSha256", diagnostic)

    def test_nonfinite_pcm_fails(self) -> None:
        entry = self.manifest["entries"][0]
        wav, _ = self.wav(entry["sampleRate"], [float("nan"), 0.0])
        path = self.root / entry["wavPath"]
        path.write_bytes(wav)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("non-finite PCM", diagnostic)

    def test_path_escape_and_extra_wav_fail(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["entries"][0]["wavPath"] = "../escape.wav"
        self.write_manifest(manifest)
        self.write_bytes(
            "docs/local/audio/baseline-corpus-v1/extra.wav",
            self.wav(44_100, [0.0, 0.0])[0],
        )
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("wavPath must be", diagnostic)
        self.assertIn("unreferenced WAVs", diagnostic)

    def test_corpus_and_contract_binding_fail_on_drift(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["corpusSha256"] = "0" * 64
        manifest["contractBaselineFingerprint"] = "1" * 64
        self.write_manifest(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("tracked corpus", diagnostic)
        self.assertIn("current baseline", diagnostic)

    def test_well_formed_but_wrong_source_fingerprint_fails(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["sourceFingerprint"] = "0" * 64
        self.write_manifest(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("sourceFingerprint does not match the current source", diagnostic)

    def test_source_fingerprint_matches_existing_exporter_format(self) -> None:
        self.assertEqual(renders.source_fingerprint(self.root), self.expected_source_fingerprint())

    def test_source_and_package_byte_changes_fail(self) -> None:
        for relative in ("Package.swift", "Sources/Fixture/Voice.swift",
                         "Sources/Fixture/Resources/profile.bin"):
            with self.subTest(path=relative):
                path = self.root / relative
                previous = path.read_bytes()
                try:
                    path.write_bytes(previous + b"changed")
                    result, diagnostic = self.check()
                    self.assertEqual(result, 1)
                    self.assertIn("current source", diagnostic)
                finally:
                    path.write_bytes(previous)

    def test_source_file_addition_removal_and_rename_fail(self) -> None:
        path = self.root / "Sources/Fixture/Voice.swift"
        previous = path.read_bytes()
        extra = self.root / "Sources/Fixture/Extra.swift"
        extra.write_bytes(previous)
        self.assertEqual(self.check()[0], 1)
        extra.unlink()
        path.unlink()
        self.assertEqual(self.check()[0], 1)
        path.write_bytes(previous)
        path.rename(extra)
        self.assertEqual(self.check()[0], 1)

    def test_missing_package_and_symlinked_source_fail_closed(self) -> None:
        package = self.root / "Package.swift"
        previous = package.read_bytes()
        package.unlink()
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("cannot verify current source identity", diagnostic)
        package.write_bytes(previous)
        link = self.root / "Sources/Fixture/link"
        link.symlink_to(self.root / "Sources/Fixture/Voice.swift")
        self.assertEqual(self.check()[0], 1)
        link.unlink()
        link.symlink_to(self.root / "Sources/Fixture", target_is_directory=True)
        self.assertEqual(self.check()[0], 1)

    def test_derived_reports_and_recorded_git_head_do_not_change_source_identity(self) -> None:
        self.write_bytes("docs/PHASE_ONE_GATE.json", b"derived report")
        self.manifest["gitHead"] = "d" * 40
        self.write_manifest(self.manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)

    def test_capture_revision_requires_an_available_ancestor_commit(self) -> None:
        def git(*arguments: str) -> str:
            return subprocess.run(
                ["git", "-C", str(self.root), "-c", "user.name=Fixture",
                 "-c", "user.email=fixture@example.invalid", "-c",
                 "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                 *arguments], check=True, capture_output=True, text=True,
            ).stdout.strip()
        git("init", "-q", "--object-format=sha1")
        git("commit", "--allow-empty", "-qm", "capture anchor")
        captured = git("rev-parse", "HEAD")
        self.assertIsNone(renders.capture_revision_error(self.root, captured))
        self.write_bytes("docs/result.md", b"derived report\n")
        git("add", "docs/result.md")
        git("commit", "-qm", "publish report")
        self.assertIsNone(renders.capture_revision_error(self.root, captured))
        unrelated = git("commit-tree", git("rev-parse", "HEAD^{tree}"),
                        "-m", "unrelated history")
        future = git("commit-tree", git("rev-parse", "HEAD^{tree}"),
                     "-p", "HEAD", "-m", "unaccepted future commit")
        for revision in (unrelated, future):
            self.assertIn("not an ancestor", renders.capture_revision_error(self.root, revision))
        blob = git("rev-parse", "HEAD:docs/result.md")
        for revision in ("0" * 40, blob):
            self.assertIn("not an available commit", renders.capture_revision_error(self.root, revision))
        for revision in (None, "HEAD", "--help", "A" * 40):
            self.assertIn("full lowercase commit ID", renders.capture_revision_error(self.root, revision))


if __name__ == "__main__":
    unittest.main()
