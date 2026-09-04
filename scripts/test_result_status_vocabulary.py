#!/usr/bin/env python3
"""Unit tests for the machine-readable result status vocabulary."""

from __future__ import annotations

import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("result_status_vocabulary.py")
SPEC = importlib.util.spec_from_file_location("result_status_vocabulary", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
vocabulary_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = vocabulary_module
SPEC.loader.exec_module(vocabulary_module)


class ResultStatusVocabularyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source = MODULE_PATH.parents[1] / "docs/RESULT_STATUS_VOCABULARY.json"
        self.vocabulary = json.loads(source.read_text(encoding="utf-8"))
        self.write_json("docs/RESULT_STATUS_VOCABULARY.json", self.vocabulary)

    def write_json(self, path: str, value: object) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    def complete_record(self) -> dict[str, object]:
        gates: list[dict[str, object]] = []
        for identifier in vocabulary_module.GATE_IDS:
            if identifier == "listening-observation":
                gates.append({
                    "id": identifier,
                    "status": "observed",
                    "evidence": ["bounded listening note"],
                    "limitation": "",
                })
            else:
                gates.append({
                    "id": identifier,
                    "status": "passed",
                    "evidence": [f"evidence for {identifier}"],
                    "limitation": "",
                })
        return {
            "schema": vocabulary_module.RECORD_SCHEMA,
            "subject": "AT-0010",
            "revision": "a" * 40,
            "summary": "All objective release gates passed for the exact revision.",
            "gates": gates,
            "claim": {
                "id": "professional-release-quality",
                "status": "verified",
                "missingGates": [],
            },
        }

    def incomplete_record(self) -> dict[str, object]:
        record = self.complete_record()
        gates = record["gates"]
        assert isinstance(gates, list)
        qualification = gates[3]
        assert isinstance(qualification, dict)
        qualification["status"] = "not-run"
        qualification["evidence"] = []
        qualification["limitation"] = "Automated qualification was not run."
        claim = record["claim"]
        assert isinstance(claim, dict)
        claim["status"] = "unverified"
        claim["missingGates"] = ["automated-quality-qualification"]
        record["summary"] = "Implementation evidence is bounded; release claim remains unverified."
        return record

    def validate(self, record: dict[str, object]) -> list[str]:
        return vocabulary_module.validate_record(record, self.vocabulary)

    def test_render_and_check_are_deterministic(self) -> None:
        first = io.StringIO()
        self.assertEqual(vocabulary_module.run_render(self.root, first), 0)
        rendered = vocabulary_module.report_path(self.root).read_bytes()
        self.assertEqual(vocabulary_module.run_render(self.root, io.StringIO()), 0)
        self.assertEqual(vocabulary_module.report_path(self.root).read_bytes(), rendered)
        output = io.StringIO()
        self.assertEqual(vocabulary_module.run_check(self.root, output), 0)
        self.assertIn("8 states, 10 gates", output.getvalue())

    def test_complete_verified_record_passes(self) -> None:
        self.assertEqual(self.validate(self.complete_record()), [])

    def test_generated_template_is_complete_and_conservative(self) -> None:
        record = vocabulary_module.new_record("AT-0010")
        self.assertEqual(self.validate(record), [])
        self.assertEqual(record["claim"]["status"], "unverified")
        self.assertEqual(
            record["claim"]["missingGates"],
            list(vocabulary_module.RELEASE_REQUIRED_GATES),
        )

    def test_incomplete_unverified_record_passes(self) -> None:
        self.assertEqual(self.validate(self.incomplete_record()), [])

    def test_missing_or_out_of_order_gate_is_rejected(self) -> None:
        missing = self.complete_record()
        missing["gates"] = missing["gates"][:-1]  # type: ignore[index]
        self.assertTrue(any("every gate once in order" in error for error in self.validate(missing)))

        reordered = self.complete_record()
        gates = reordered["gates"]
        assert isinstance(gates, list)
        gates[0], gates[1] = gates[1], gates[0]
        self.assertTrue(any("every gate once in order" in error for error in self.validate(reordered)))

    def test_unsupported_state_is_rejected(self) -> None:
        record = self.complete_record()
        record["gates"][0]["status"] = "successful"  # type: ignore[index]
        self.assertTrue(any("not allowed" in error for error in self.validate(record)))

    def test_positive_state_without_evidence_is_rejected(self) -> None:
        record = self.complete_record()
        record["gates"][0]["evidence"] = []  # type: ignore[index]
        self.assertTrue(any("status passed requires evidence" in error for error in self.validate(record)))

    def test_nonpositive_state_without_limitation_is_rejected(self) -> None:
        record = self.incomplete_record()
        record["gates"][3]["limitation"] = ""  # type: ignore[index]
        self.assertTrue(any("status not-run requires a limitation" in error for error in self.validate(record)))

    def test_listening_cannot_be_marked_passed(self) -> None:
        record = self.complete_record()
        record["gates"][8]["status"] = "passed"  # type: ignore[index]
        self.assertTrue(any("not allowed for listening-observation" in error for error in self.validate(record)))

    def test_premature_professional_release_claim_is_rejected(self) -> None:
        record = self.incomplete_record()
        record["claim"]["status"] = "verified"  # type: ignore[index]
        self.assertTrue(any("cannot be verified" in error for error in self.validate(record)))

    def test_ambiguous_professional_claim_is_rejected_without_gates(self) -> None:
        record = self.incomplete_record()
        record["summary"] = "Sounds professional."
        self.assertTrue(any("ambiguous claim phrase" in error for error in self.validate(record)))

    def test_verified_claim_requires_exact_revision(self) -> None:
        record = self.complete_record()
        record["revision"] = "working-tree"
        self.assertTrue(any("40-digit exact revision" in error for error in self.validate(record)))

    def test_stale_generated_report_is_rejected(self) -> None:
        self.assertEqual(vocabulary_module.run_render(self.root, io.StringIO()), 0)
        vocabulary_module.report_path(self.root).write_text("stale\n", encoding="utf-8")
        output = io.StringIO()
        self.assertEqual(vocabulary_module.run_check(self.root, output), 1)
        self.assertIn("generated Markdown is stale", output.getvalue())


if __name__ == "__main__":
    unittest.main()
