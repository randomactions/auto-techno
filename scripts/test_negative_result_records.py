#!/usr/bin/env python3
"""Unit tests for durable negative-result records."""

from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("negative_result_records.py")
SPEC = importlib.util.spec_from_file_location("negative_result_records", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
negative = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = negative
SPEC.loader.exec_module(negative)


class NegativeResultRecordTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        repository = MODULE_PATH.parents[1]
        self.schema = json.loads(
            (repository / "docs/NEGATIVE_RESULT_SCHEMA.json").read_text(encoding="utf-8")
        )
        citation_schema = json.loads(
            (repository / "docs/SOURCE_CITATION_SCHEMA.json").read_text(encoding="utf-8")
        )
        self.write_json("docs/NEGATIVE_RESULT_SCHEMA.json", self.schema)
        self.write_json("docs/SOURCE_CITATION_SCHEMA.json", citation_schema)
        self.write("docs/PRODUCT.md", "fixture product\n")
        self.write("docs/local/roadmap-plans/AT-0013.md", "fixture plan\n")
        self.write("docs/local/reports/negative-fixture.txt", "measured no benefit\n")
        digest = hashlib.sha256(b"fixture product\n").hexdigest()
        self.write_json(
            "docs/local/reports/source-citations/AT-0013.json",
            {
                "schema": negative.source_citation_records.RECORD_ID,
                "itemId": "AT-0013",
                "planPath": "docs/local/roadmap-plans/AT-0013.md",
                "sources": [{
                    "id": "SRC-AT-0013-001",
                    "url": "repo:docs/PRODUCT.md",
                    "title": "Product",
                    "publisher": "Auto Techno",
                    "revisionOrDate": f"sha256:{digest}",
                    "accessDate": "2026-08-31",
                    "depth": "A",
                    "licenceClass": "GREEN-ORIGINAL",
                    "use": "contract-authority",
                    "summary": "Fixture source.",
                    "excerpt": "",
                }],
            },
        )
        self.record = self.valid_record()
        self.record_path = self.root / (
            "docs/local/reports/negative-results/NEG-AT-0013-001.json"
        )

    def write(self, path: str, contents: str) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")

    def write_json(self, path: str, value: object) -> None:
        self.write(path, json.dumps(value, indent=2) + "\n")

    def valid_record(self) -> dict[str, object]:
        return {
            "schema": negative.RECORD_ID,
            "itemId": "AT-0013",
            "planPath": "docs/local/roadmap-plans/AT-0013.md",
            "citationRecordPath": "docs/local/reports/source-citations/AT-0013.json",
            "experimentId": "NEG-AT-0013-001",
            "title": "Synthetic bounded experiment",
            "createdDate": "2026-08-30",
            "concludedDate": "2026-08-31",
            "hypothesis": "The bounded intervention will improve the named metric.",
            "canonicalOwner": "FixtureOwner",
            "checkpoint": "fixture-checkpoint",
            "baseline": {
                "description": "Measured original behavior.",
                "identity": "baseline-v1",
                "evidenceRefs": ["EVD-001"],
            },
            "intervention": {
                "description": "Changed one bounded variable.",
                "identity": "candidate-v1",
                "changedVariables": ["fixtureAmount: 0.0 -> 0.1"],
            },
            "bounds": ["fixtureAmount remains in 0...0.1"],
            "evidence": [
                {
                    "id": "EVD-001",
                    "kind": "measurement",
                    "reference": "local:docs/local/reports/negative-fixture.txt",
                    "observation": "The measured benefit stayed below threshold.",
                }
            ],
            "outcome": {
                "code": "no-measurable-benefit",
                "summary": "The intervention did not clear the preregistered threshold.",
            },
            "failureReason": {
                "code": "benefit-below-threshold",
                "summary": "The observed delta was too small to justify complexity.",
            },
            "learnedConstraints": [
                "Do not add this variable without a larger independent deficit."
            ],
            "reusableEvidence": [
                "The baseline and candidate remain finite under the same fixture."
            ],
            "disposition": "retired",
            "replacementItem": "",
            "followUp": {
                "status": "none",
                "proposedOutcome": "",
                "condition": "",
            },
        }

    def validate(self) -> list[str]:
        return negative.validate_record(
            self.record, self.schema, self.root, self.record_path
        )

    def test_render_check_and_template_are_deterministic(self) -> None:
        self.assertEqual(negative.run_render(self.root, io.StringIO()), 0)
        first = negative.report_path(self.root).read_bytes()
        self.assertEqual(negative.run_render(self.root, io.StringIO()), 0)
        self.assertEqual(negative.report_path(self.root).read_bytes(), first)
        self.assertEqual(negative.run_check(self.root, io.StringIO()), 0)
        template = negative.new_template("AT-0013")
        self.assertEqual(template["experimentId"], "NEG-AT-0013-001")
        self.assertEqual(self.validate(), [])
        self.assertTrue(negative.validate_record(template, self.schema, self.root))

    def test_complete_retired_record_passes(self) -> None:
        self.assertEqual(self.validate(), [])

    def test_missing_evidence_and_constraints_are_rejected(self) -> None:
        del self.record["title"]
        self.record["evidence"] = []
        self.record["learnedConstraints"] = []
        errors = self.validate()
        self.assertTrue(any("fields must be exactly" in error for error in errors))
        self.assertTrue(any("evidence must be a non-empty" in error for error in errors))
        self.assertTrue(any("learnedConstraints must be" in error for error in errors))

    def test_unsafe_or_absent_evidence_path_is_rejected(self) -> None:
        self.record["evidence"][0]["reference"] = "local:../../secret"  # type: ignore[index]
        self.assertTrue(any("existing safe" in error for error in self.validate()))
        self.record["evidence"][0]["reference"] = "repo:docs/missing.txt"  # type: ignore[index]
        self.assertTrue(any("existing safe" in error for error in self.validate()))

    def test_invalid_ids_dates_and_enums_are_rejected(self) -> None:
        self.record["experimentId"] = "experiment-one"
        self.record["createdDate"] = "2026-99-99"
        self.record["outcome"]["code"] = "bad"  # type: ignore[index]
        self.record["failureReason"]["code"] = "bad"  # type: ignore[index]
        self.record["disposition"] = "bad"
        self.record["evidence"][0]["kind"] = "bad"  # type: ignore[index]
        errors = self.validate()
        for expected in (
            "experimentId must use",
            "dates must use valid",
            "outcome.code is unsupported",
            "failureReason.code is unsupported",
            "disposition is unsupported",
            "kind is unsupported",
        ):
            self.assertTrue(any(expected in error for error in errors), expected)

    def test_item_plan_citation_and_filename_bindings_are_enforced(self) -> None:
        self.record["planPath"] = "docs/local/roadmap-plans/AT-9999.md"
        self.record["citationRecordPath"] = "docs/local/reports/source-citations/AT-9999.json"
        errors = negative.validate_record(
            self.record, self.schema, self.root, self.record_path.with_name("wrong.json")
        )
        self.assertTrue(any("planPath must be" in error for error in errors))
        self.assertTrue(any("citationRecordPath must be" in error for error in errors))
        self.assertTrue(any("filename must be" in error for error in errors))

    def test_retired_disposition_forbids_follow_up(self) -> None:
        self.record["followUp"] = {
            "status": "proposed",
            "proposedOutcome": "Try again.",
            "condition": "Whenever convenient.",
        }
        self.assertTrue(any("retired disposition forbids" in error for error in self.validate()))

    def test_superseded_and_follow_up_dispositions_require_exact_fields(self) -> None:
        self.record["disposition"] = "superseded"
        self.assertTrue(any("requires replacementItem" in error for error in self.validate()))
        self.record["replacementItem"] = "AT-0100"
        self.assertEqual(self.validate(), [])

        self.record["disposition"] = "follow-up-proposed"
        self.record["replacementItem"] = ""
        self.assertTrue(any("requires bounded" in error for error in self.validate()))
        self.record["followUp"] = {
            "status": "proposed",
            "proposedOutcome": "Measure a narrower causal relationship.",
            "condition": "Only after two independent fixtures expose the same deficit.",
        }
        self.assertEqual(self.validate(), [])

    def test_inconclusive_cannot_claim_disconfirmation(self) -> None:
        self.record["outcome"]["code"] = "inconclusive"  # type: ignore[index]
        self.record["failureReason"]["code"] = "hypothesis-disconfirmed"  # type: ignore[index]
        self.assertTrue(any("inconclusive outcome cannot" in error for error in self.validate()))

    def test_stale_generated_report_is_rejected(self) -> None:
        self.assertEqual(negative.run_render(self.root, io.StringIO()), 0)
        negative.report_path(self.root).write_text("stale\n", encoding="utf-8")
        output = io.StringIO()
        self.assertEqual(negative.run_check(self.root, output), 1)
        self.assertIn("generated Markdown is stale", output.getvalue())


if __name__ == "__main__":
    unittest.main()
