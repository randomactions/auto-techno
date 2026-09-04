#!/usr/bin/env python3
"""Unit tests for the roadmap contract baseline gate."""

from __future__ import annotations

import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).with_name("roadmap_contract_baseline.py")
SPEC = importlib.util.spec_from_file_location("roadmap_contract_baseline", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
baseline = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = baseline
SPEC.loader.exec_module(baseline)


class RoadmapContractBaselineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for role, path in baseline.AUTHORITATIVE_DOCUMENTS:
            destination = self.root / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(f"{role}: fixture\n", encoding="utf-8")

    def generate(self, version: int = 1) -> str:
        output = io.StringIO()
        self.assertEqual(baseline.run_generate(self.root, version, output), 0)
        return output.getvalue()

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        result = baseline.run_check(self.root, output)
        return result, output.getvalue()

    def test_generate_and_check_are_deterministic(self) -> None:
        self.assertIn("snapshot v1", self.generate())
        first = baseline.baseline_path(self.root).read_bytes()
        self.assertIn("snapshot v1", self.generate())
        self.assertEqual(baseline.baseline_path(self.root).read_bytes(), first)
        result, diagnostic = self.check()
        self.assertEqual(result, 0)
        self.assertIn("roadmap contract baseline is compatible", diagnostic)

    def test_content_drift_names_exact_file_and_rejects_execution(self) -> None:
        self.generate()
        product = self.root / "docs/PRODUCT.md"
        product.write_text("changed product contract\n", encoding="utf-8")
        manifest_before = baseline.baseline_path(self.root).read_bytes()

        result, diagnostic = self.check()

        self.assertEqual(result, 1)
        self.assertIn("contract drift: docs/PRODUCT.md", diagnostic)
        self.assertIn("rejected execution", diagnostic)
        self.assertEqual(baseline.baseline_path(self.root).read_bytes(), manifest_before)

    def test_missing_contract_names_exact_file_and_rejects_execution(self) -> None:
        self.generate()
        (self.root / "Package.swift").unlink()

        result, diagnostic = self.check()

        self.assertEqual(result, 1)
        self.assertIn("contract drift: Package.swift is missing", diagnostic)

    def test_changed_contract_requires_snapshot_version_increment(self) -> None:
        self.generate()
        (self.root / "AGENTS.md").write_text("new repository guidance\n", encoding="utf-8")
        with self.assertRaisesRegex(
            baseline.RoadmapContractBaselineError,
            "increment --snapshot-version above 1",
        ):
            baseline.run_generate(self.root, 1, io.StringIO())
        self.assertEqual(baseline.run_generate(self.root, 2, io.StringIO()), 0)
        manifest = json.loads(
            baseline.baseline_path(self.root).read_text(encoding="utf-8")
        )
        self.assertEqual(manifest["snapshotVersion"], 2)
        self.assertEqual(self.check()[0], 0)

    def test_manifest_cannot_drop_or_reorder_authoritative_files(self) -> None:
        self.generate()
        path = baseline.baseline_path(self.root)
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["documents"] = list(reversed(manifest["documents"]))[1:]
        manifest["snapshotFingerprint"] = baseline.snapshot_fingerprint(
            manifest["documents"]
        )
        path.write_text(json.dumps(manifest), encoding="utf-8")

        result, diagnostic = self.check()

        self.assertEqual(result, 1)
        self.assertIn("exact authoritative set in canonical order", diagnostic)
        self.assertIn("docs/PRODUCT.md", diagnostic)

    def test_authoritative_set_expansion_requires_versioned_migration(self) -> None:
        self.generate()
        added = self.root / "docs/NEW_CONTRACT.md"
        added.write_text("new contract\n", encoding="utf-8")
        expanded = baseline.AUTHORITATIVE_DOCUMENTS + (
            ("new-contract", "docs/NEW_CONTRACT.md"),
        )
        with mock.patch.object(baseline, "AUTHORITATIVE_DOCUMENTS", expanded):
            with self.assertRaisesRegex(
                baseline.RoadmapContractBaselineError,
                "increment --snapshot-version above 1",
            ):
                baseline.run_generate(self.root, 1, io.StringIO())
            self.assertEqual(
                baseline.run_generate(self.root, 2, io.StringIO()), 0
            )
            self.assertEqual(self.check()[0], 0)


if __name__ == "__main__":
    unittest.main()
