#!/usr/bin/env python3
"""Unit tests for exact score-derived foundation-behavior coverage manifests."""

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import foundation_behavior_coverage as coverage


class FoundationBehaviorCoverageTests(unittest.TestCase):
    def setUp(self) -> None:
        common = {
            "caseId": "case-1", "routeId": "native-stereo-48000",
            "rootSeed": 42, "checkpoint": "establishment",
            "continuationClass": "initial", "phraseIndex": 0,
            "startBar": 0, "phraseKind": "lock",
            "stateFingerprint": "1" * 16, "planFingerprint": "2" * 16,
            "replayFingerprint": "3" * 16, "policyVersion": "policy-v1",
            "qualityOutcome": "qualified", "sampleRate": 48_000,
        }
        whole_entry = {"id": "case-1--native-stereo-48000", **common,
                       "pcmSha256": "a" * 64}
        stem_entry = {"id": "case-1--native-stereo-48000", **common,
                      "wholeMixPcmSha256": "a" * 64}
        counts = {behavior: 0 for behavior in coverage.BEHAVIORS}
        counts["monotone"] = 4
        coverage_entry = {
            "id": "case-1--native-stereo-48000", **common,
            "wholeMixPcmSha256": "a" * 64, "resolvedBarCount": 4,
            "foundationBehaviorBarCounts": counts,
        }
        self.whole = {
            "corpusSha256": "e" * 64,
            "contractBaselineFingerprint": "b" * 64,
            "sourceFingerprint": "c" * 64, "gitHead": "d" * 40,
            "engineVersion": "engine-v1", "entries": [whole_entry],
        }
        self.stems = {
            "corpusSha256": "e" * 64,
            "wholeMixManifestSha256": "f" * 64,
            "contractBaselineFingerprint": "b" * 64,
            "sourceFingerprint": "c" * 64, "gitHead": "d" * 40,
            "engineVersion": "engine-v1", "entries": [stem_entry],
        }
        self.coverage = {
            "schema": coverage.SCHEMA, "manifestVersion": 1,
            "corpusSha256": "e" * 64, "wholeMixManifestSha256": "f" * 64,
            "roleStemManifestSha256": "0" * 64,
            "contractBaselineFingerprint": "b" * 64,
            "sourceFingerprint": "c" * 64, "gitHead": "d" * 40,
            "engineVersion": "engine-v1", "entries": [coverage_entry],
        }

    def check(self) -> list[str]:
        return coverage.validate_coverage(
            self.coverage, self.whole, self.stems,
            corpus_sha256="e" * 64,
            whole_manifest_sha256="f" * 64,
            stems_manifest_sha256="0" * 64,
        )

    def test_complete_exactly_bound_behavior_counts_pass(self) -> None:
        self.assertEqual(self.check(), [])

    def test_all_behavior_keys_and_resolved_bar_total_are_required(self) -> None:
        mutated = copy.deepcopy(self.coverage)
        counts = mutated["entries"][0]["foundationBehaviorBarCounts"]
        del counts["absent"]
        self.coverage = mutated
        self.assertTrue(any("all seven behaviors" in item for item in self.check()))

        counts["absent"] = 0
        counts["point"] = 1
        self.assertTrue(any("do not sum" in item for item in self.check()))

    def test_whole_mix_pcm_and_stem_manifest_hash_are_bound(self) -> None:
        self.coverage["entries"][0]["wholeMixPcmSha256"] = "9" * 64
        self.coverage["roleStemManifestSha256"] = "9" * 64
        errors = self.check()
        self.assertTrue(any("exact paired PCM" in item for item in errors))
        self.assertTrue(any("roleStemManifestSha256" in item for item in errors))

    def test_capture_identity_and_provenance_cannot_drift(self) -> None:
        self.coverage["entries"][0]["planFingerprint"] = "9" * 16
        self.coverage["sourceFingerprint"] = "9" * 64
        errors = self.check()
        self.assertTrue(any("planFingerprint differs" in item for item in errors))
        self.assertTrue(any("sourceFingerprint differs" in item for item in errors))

    def test_stem_manifest_must_bind_the_exact_whole_mix_manifest(self) -> None:
        self.stems["wholeMixManifestSha256"] = "9" * 64
        self.assertTrue(any("exact whole-mix manifest" in item for item in self.check()))

    def test_coverage_namespace_isolated_from_phase_one_artifacts(self) -> None:
        self.assertEqual(
            coverage.coverage_path(Path("/tmp/fixture"), "at0039-v1"),
            Path("/tmp/fixture/docs/local/reports/baseline-stems-at0039-v1/foundation-behavior-coverage.json"),
        )


if __name__ == "__main__":
    unittest.main()
