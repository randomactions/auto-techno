#!/usr/bin/env python3
"""Unit tests for the deterministic Phase-1 baseline corpus."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("baseline_corpus.py")
SPEC = importlib.util.spec_from_file_location("baseline_corpus", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
corpus = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = corpus
SPEC.loader.exec_module(corpus)


class BaselineCorpusTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source = MODULE_PATH.parents[1] / "docs/BASELINE_CORPUS.json"
        self.manifest = json.loads(source.read_text(encoding="utf-8"))
        self.write(self.manifest)

    def write(self, value: object) -> None:
        path = corpus.manifest_path(self.root)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return corpus.run_check(self.root, output), output.getvalue()

    def test_current_manifest_generates_and_checks_deterministically(self) -> None:
        first_output = io.StringIO()
        self.assertEqual(corpus.run_generate(self.root, first_output), 0)
        first = corpus.report_path(self.root).read_bytes()
        self.assertEqual(corpus.run_generate(self.root, io.StringIO()), 0)
        self.assertEqual(corpus.report_path(self.root).read_bytes(), first)
        result, diagnostic = self.check()
        self.assertEqual(result, 0, diagnostic)
        self.assertIn("14 identities", diagnostic)

    def test_seed_derivation_is_exact_and_tamper_evident(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["cases"][2]["rootSeed"] += 1
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("derived value", diagnostic)

    def test_case_ids_and_ordinals_are_stable(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["cases"][1]["id"] = "winner"
        manifest["cases"][3]["ordinal"] = 2
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("ATBC-V1-001-CHAPTER-CHANGE", diagnostic)
        self.assertIn("ordinal must be 3", diagnostic)

    def test_checkpoint_and_continuation_coverage_cannot_shrink(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["cases"][6]["checkpoint"] = "release"
        manifest["requiredCoverage"]["continuationClasses"] = ["initial", "advanced"]
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("long-continuation", diagnostic)
        self.assertIn("continuationClasses", diagnostic)

    def test_winner_or_metric_fields_are_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["cases"][0]["qualityRank"] = 1
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("qualityRank", diagnostic)

    def test_route_contract_is_exact(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["routes"][0]["sampleRate"] = 96_000
        manifest["routes"][1]["routeRecovery"] = True
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("44100", diagnostic)
        self.assertIn("routeRecovery must be false", diagnostic)

    def test_selection_algorithm_and_bound_are_fixed(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["selectionPolicy"]["algorithm"] = "manual"
        manifest["checkpointPolicy"]["maximumPhrases"] = 64
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("splitmix64-domain-sequence.v1", diagnostic)
        self.assertIn("must be 128", diagnostic)

    def test_stale_rendering_is_rejected(self) -> None:
        self.assertEqual(corpus.run_generate(self.root, io.StringIO()), 0)
        corpus.report_path(self.root).write_text("stale\n", encoding="utf-8")
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("generated Markdown is stale", diagnostic)


if __name__ == "__main__":
    unittest.main()
