#!/usr/bin/env python3
"""Unit tests for source-citation schema and active-plan records."""

from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("source_citation_records.py")
SPEC = importlib.util.spec_from_file_location("source_citation_records", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
citations = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = citations
SPEC.loader.exec_module(citations)


class SourceCitationRecordTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        schema_source = MODULE_PATH.parents[1] / "docs/SOURCE_CITATION_SCHEMA.json"
        self.schema = json.loads(schema_source.read_text(encoding="utf-8"))
        self.write_json("docs/SOURCE_CITATION_SCHEMA.json", self.schema)
        self.write("docs/PRODUCT.md", "fixture product\n")
        self.write("docs/local/roadmap-plans/AT-0012.md", "fixture plan\n")
        self.write(
            "docs/local/SYNTH_FX_DSP_RESEARCH_STUDY.md",
            """## Control C — Machine-readable roadmap controller

```yaml
roadmap_schema: autotechno-evolution.v1
roadmap_status: active
roadmap_revision: 13
last_updated_utc: 2026-08-31
active_item: AT-0012
active_plan: docs/local/roadmap-plans/AT-0012.md
last_completed_item: AT-0011
selection_policy: lowest_order_eligible_item
maximum_concurrent_items: 1
discovery_inbox_open: 0
quality_claim: bounded-calibrated-no-general-professional-claim
local_only: true
```

## Control D — Status model and autonomous selection
""",
        )
        self.record = self.valid_record()
        self.record_path = (
            self.root / "docs/local/reports/source-citations/AT-0012.json"
        )
        self.write_json(
            "docs/local/reports/source-citations/AT-0012.json", self.record
        )

    def write(self, path: str, contents: str) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")

    def write_json(self, path: str, value: object) -> None:
        self.write(path, json.dumps(value, indent=2) + "\n")

    def valid_record(self) -> dict[str, object]:
        digest = hashlib.sha256(b"fixture product\n").hexdigest()
        return {
            "schema": citations.RECORD_ID,
            "itemId": "AT-0012",
            "planPath": "docs/local/roadmap-plans/AT-0012.md",
            "sources": [
                {
                    "id": "SRC-AT-0012-001",
                    "url": "repo:docs/PRODUCT.md",
                    "title": "Product contract",
                    "publisher": "Auto Techno",
                    "revisionOrDate": f"sha256:{digest}",
                    "accessDate": "2026-08-31",
                    "depth": "A",
                    "licenceClass": "GREEN-ORIGINAL",
                    "use": "contract-authority",
                    "summary": "The product contract defines the standalone runtime boundary.",
                    "excerpt": "",
                }
            ],
        }

    def validate(self) -> list[str]:
        return citations.validate_record(
            self.record, self.schema, self.root, self.record_path
        )

    def test_render_and_check_are_deterministic(self) -> None:
        self.assertEqual(citations.run_render(self.root, io.StringIO()), 0)
        first = citations.report_path(self.root).read_bytes()
        self.assertEqual(citations.run_render(self.root, io.StringIO()), 0)
        self.assertEqual(citations.report_path(self.root).read_bytes(), first)
        output = io.StringIO()
        self.assertEqual(citations.run_check(self.root, output), 0)
        self.assertIn("5 depths, 5 licence classes", output.getvalue())

    def test_complete_record_and_active_preflight_pass(self) -> None:
        self.assertEqual(self.validate(), [])
        output = io.StringIO()
        self.assertEqual(citations.run_check_active(self.root, output), 0)
        self.assertIn("AT-0012, 1 sources", output.getvalue())

    def test_missing_field_is_rejected(self) -> None:
        del self.record["sources"][0]["publisher"]  # type: ignore[index]
        self.assertTrue(any("fields must be exactly" in error for error in self.validate()))

    def test_duplicate_source_url_is_rejected(self) -> None:
        duplicate = dict(self.record["sources"][0])  # type: ignore[index]
        duplicate["id"] = "SRC-AT-0012-002"
        self.record["sources"].append(duplicate)  # type: ignore[union-attr]
        self.assertTrue(any("URLs must be unique" in error for error in self.validate()))

    def test_invalid_url_date_depth_class_and_use_are_rejected(self) -> None:
        source = self.record["sources"][0]  # type: ignore[index]
        source["url"] = "http://example.test/source"
        source["accessDate"] = "yesterday"
        source["depth"] = "Z"
        source["licenceClass"] = "UNKNOWN"
        source["use"] = "copy-source"
        errors = self.validate()
        for expected in (
            "https URL or repo:path",
            "accessDate must use YYYY-MM-DD",
            "depth is unsupported",
            "licenceClass is unsupported",
            "use is unsupported",
        ):
            self.assertTrue(any(expected in error for error in errors), expected)

    def test_depth_x_and_study_only_classes_cannot_authorize_implementation(self) -> None:
        source = self.record["sources"][0]  # type: ignore[index]
        source["url"] = "https://example.test/source"
        source["revisionOrDate"] = "accessed version"
        source["depth"] = "X"
        source["licenceClass"] = "RED-STUDY-ONLY"
        source["use"] = "implementation-reference"
        errors = self.validate()
        self.assertTrue(any("depth X may be discovery-only" in error for error in errors))
        self.assertTrue(any("may not authorize" in error for error in errors))

    def test_excerpt_over_25_words_is_rejected(self) -> None:
        self.record["sources"][0]["excerpt"] = "word " * 26  # type: ignore[index]
        self.assertTrue(any("exceeds 25 words" in error for error in self.validate()))

    def test_missing_or_mutated_repository_source_is_rejected(self) -> None:
        (self.root / "docs/PRODUCT.md").write_text("changed\n", encoding="utf-8")
        self.assertTrue(any("must match repository sha256" in error for error in self.validate()))
        (self.root / "docs/PRODUCT.md").unlink()
        self.assertTrue(any("repository source is missing" in error for error in self.validate()))

    def test_item_plan_and_filename_mismatch_are_rejected(self) -> None:
        self.record["planPath"] = "docs/local/roadmap-plans/AT-9999.md"
        wrong_path = self.record_path.with_name("wrong.json")
        errors = citations.validate_record(
            self.record, self.schema, self.root, wrong_path
        )
        self.assertTrue(any("record.planPath must be" in error for error in errors))
        self.assertTrue(any("citation record filename must be" in error for error in errors))

    def test_local_roadmap_source_binds_explicit_revision(self) -> None:
        source = self.record["sources"][0]  # type: ignore[index]
        source["url"] = "repo:docs/local/SYNTH_FX_DSP_RESEARCH_STUDY.md"
        source["revisionOrDate"] = "roadmap-revision:12"
        self.assertTrue(any("must match the local roadmap-revision:13" in error for error in self.validate()))
        source["revisionOrDate"] = "roadmap-revision:13"
        self.assertEqual(self.validate(), [])

    def test_missing_active_record_is_rejected(self) -> None:
        self.record_path.unlink()
        output = io.StringIO()
        self.assertEqual(citations.run_check_active(self.root, output), 1)
        self.assertIn("cannot read", output.getvalue())


if __name__ == "__main__":
    unittest.main()
