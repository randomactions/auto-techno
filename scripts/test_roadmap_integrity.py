#!/usr/bin/env python3
"""Unit tests for the autonomous roadmap integrity checker."""

from __future__ import annotations

import importlib.util
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("roadmap_integrity.py")
SPEC = importlib.util.spec_from_file_location("roadmap_integrity", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
integrity = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = integrity
SPEC.loader.exec_module(integrity)

DOCTOR_SPEC = importlib.util.spec_from_file_location(
    "local_artifact_doctor", MODULE_PATH.with_name("local_artifact_doctor.py")
)
assert DOCTOR_SPEC is not None and DOCTOR_SPEC.loader is not None
doctor = importlib.util.module_from_spec(DOCTOR_SPEC)
DOCTOR_SPEC.loader.exec_module(doctor)


class RoadmapIntegrityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write_plan("AT-0002")

    def write_plan(self, identifier: str) -> None:
        path = self.root / f"docs/local/roadmap-plans/{identifier}.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture plan\n", encoding="utf-8")

    def controller(self, active: str = "AT-0002", last: str = "AT-0001") -> str:
        return f"""## Control C — Machine-readable roadmap controller

```yaml
roadmap_schema: autotechno-evolution.v1
roadmap_status: active
roadmap_revision: 1
last_updated_utc: 2026-08-31
active_item: {active}
active_plan: docs/local/roadmap-plans/{active}.md
last_completed_item: {last}
selection_policy: lowest_order_eligible_item
maximum_concurrent_items: 1
discovery_inbox_open: 0
quality_claim: bounded-calibrated-no-general-professional-claim
local_only: true
```

"""

    def status_section(self) -> str:
        rows = "\n".join(
            f"| `{status}` | fixture |" for status in integrity.ALLOWED_STATUSES
        )
        return f"""## Control D — Status model and autonomous selection

| Status | Meaning |
|---|---|
{rows}

## Control E — One-item autonomous work cycle

fixture
"""

    def document(
        self,
        rows: list[tuple[str, str, str]],
        *,
        active: str = "AT-0002",
        last: str = "AT-0001",
    ) -> str:
        table_rows = "\n".join(
            f"| {identifier} | `{status}` | {dependencies} | outcome | evidence |"
            for identifier, status, dependencies in rows
        )
        return self.controller(active, last) + self.status_section() + table_rows + "\n"

    def valid_document(self) -> str:
        return self.document([
            ("AT-0001", "completed", "—"),
            ("AT-0002", "researching", "AT-0001"),
            ("AT-0003", "queued", "AT-0001"),
        ])

    def errors(self, text: str) -> list[str]:
        return integrity.validate_roadmap(text, self.root)

    def test_valid_roadmap_passes(self) -> None:
        self.assertEqual(self.errors(self.valid_document()), [])

    def test_duplicate_and_noncontiguous_ids_are_rejected(self) -> None:
        duplicate = self.valid_document() + (
            "| AT-0003 | `queued` | AT-0001 | duplicate | evidence |\n"
        )
        self.assertTrue(any("duplicate item ids" in error for error in self.errors(duplicate)))

        noncontiguous = self.valid_document().replace("AT-0003 | `queued`", "AT-0004 | `queued`")
        self.assertTrue(any("item ids must be contiguous" in error for error in self.errors(noncontiguous)))

    def test_invalid_status_is_rejected(self) -> None:
        text = self.valid_document().replace("`queued` | AT-0001 | outcome", "`done` | AT-0001 | outcome")
        self.assertTrue(any("invalid status" in error for error in self.errors(text)))

    def test_missing_dependency_is_rejected(self) -> None:
        text = self.valid_document().replace(
            "AT-0003 | `queued` | AT-0001", "AT-0003 | `queued` | AT-0099"
        )
        self.assertTrue(any("depends on missing item AT-0099" in error for error in self.errors(text)))

    def test_dependency_cycle_is_rejected(self) -> None:
        text = self.document([
            ("AT-0001", "completed", "AT-0002"),
            ("AT-0002", "researching", "AT-0001"),
            ("AT-0003", "queued", "AT-0001"),
        ])
        self.assertTrue(any("dependency cycle" in error for error in self.errors(text)))

    def test_multiple_active_items_are_rejected(self) -> None:
        text = self.valid_document().replace("AT-0003 | `queued`", "AT-0003 | `planning`")
        self.assertTrue(any("exactly one active item" in error for error in self.errors(text)))

    def test_controller_mismatch_and_missing_plan_are_rejected(self) -> None:
        self.write_plan("AT-0003")
        mismatch = self.document([
            ("AT-0001", "completed", "—"),
            ("AT-0002", "researching", "AT-0001"),
            ("AT-0003", "queued", "AT-0001"),
        ], active="AT-0003")
        self.assertTrue(any("does not match active row" in error for error in self.errors(mismatch)))

        (self.root / "docs/local/roadmap-plans/AT-0002.md").unlink()
        self.assertTrue(any("active_plan is missing" in error for error in self.errors(self.valid_document())))

    def test_active_item_requires_satisfied_dependencies(self) -> None:
        text = self.document([
            ("AT-0001", "completed", "—"),
            ("AT-0002", "researching", "AT-0003"),
            ("AT-0003", "queued", "AT-0001"),
        ])
        self.assertTrue(any("unsatisfied dependencies" in error for error in self.errors(text)))

    def test_lower_eligible_item_cannot_be_skipped(self) -> None:
        self.write_plan("AT-0003")
        text = self.document([
            ("AT-0001", "completed", "—"),
            ("AT-0002", "queued", "AT-0001"),
            ("AT-0003", "researching", "AT-0001"),
        ], active="AT-0003")
        self.assertTrue(any("skips lower eligible item AT-0002" in error for error in self.errors(text)))


    def no_change_document(self, receipt: bool = True) -> str:
        self.write_plan("AT-0003")
        document = self.document([
            ("AT-0001", "completed", "—"),
            ("AT-0002", "verified-no-change", "AT-0001"),
            ("AT-0003", "researching", "AT-0002"),
        ], active="AT-0003")
        if receipt:
            document = document.replace(
                "`verified-no-change` | AT-0001 | outcome | evidence",
                "`verified-no-change` | AT-0001 | outcome | "
                "[qualification](docs/local/result-records/AT-0002.json)",
            )
        return document

    def qualified_receipt(self) -> dict[str, object]:
        vocabulary = self.root / "docs/RESULT_STATUS_VOCABULARY.json"
        vocabulary.parent.mkdir(parents=True, exist_ok=True)
        vocabulary.write_bytes((MODULE_PATH.parents[1] / vocabulary.relative_to(self.root)).read_bytes())
        (self.root / ".gitignore").write_text("docs/local/\n", encoding="utf-8")
        def git(*args: str) -> str:
            return subprocess.check_output(
                ["git", "-c", "core.fsmonitor=false", "-C", str(self.root), *args],
                text=True, stderr=subprocess.DEVNULL,
            ).strip()
        git("init", "-q")
        git("add", ".gitignore", "docs/RESULT_STATUS_VOCABULARY.json")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-qm", "frozen fixture")
        record = integrity.results.new_record("AT-0002")
        record["revision"] = git("rev-parse", "HEAD")
        for gate in record["gates"]:
            if gate["id"] in ("implementation", "focused-local-verification",
                              "full-local-verification", "automated-quality-qualification"):
                gate.update(status="passed", evidence=["current measured outcome"], limitation="")
            else:
                gate.update(status="not-applicable", evidence=[], limitation="Outside this item's scope.")
        item = next(item for item in integrity.parse_items(self.no_change_document())[0]
                    if item.identifier == "AT-0002")
        record["gates"][1]["evidence"].append(
            "roadmap-scope-sha256:" + integrity.no_change_scope_fingerprint(item, self.root)
        )
        self.write_receipt(record)
        return record

    def write_receipt(self, record: dict[str, object], identifier: str = "AT-0002") -> None:
        gates = record["gates"]
        record["claim"]["missingGates"] = [
            gate["id"] for gate in gates
            if gate["id"] in integrity.results.RELEASE_REQUIRED_GATES and gate["status"] != "passed"
        ]
        path = self.root / f"docs/local/result-records/{identifier}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(record), encoding="utf-8")

    def test_opaque_no_change_evidence_cannot_satisfy_dependency(self) -> None:
        errors = self.errors(self.no_change_document(receipt=False))
        self.assertTrue(any("must link its result receipt" in error for error in errors))
        self.assertTrue(any("unsatisfied dependencies" in error for error in errors))

    def test_missing_receipt_cannot_satisfy_dependency(self) -> None:
        self.assertTrue(any("cannot read" in error for error in self.errors(self.no_change_document())))

    def test_valid_current_no_change_receipt_satisfies_dependency(self) -> None:
        self.qualified_receipt()
        self.assertEqual(self.errors(self.no_change_document()), [])

    def test_valid_no_change_receipt_also_passes_required_artifact_layout_gate(self) -> None:
        self.qualified_receipt()
        for directory in doctor.REQUIRED_DIRECTORIES:
            (self.root / doctor.LOCAL_ROOT / directory).mkdir(exist_ok=True)
        self.assertEqual(self.errors(self.no_change_document()), [])
        self.assertEqual(doctor.compare_to_repository(self.root), [])

    def test_incomplete_required_qualification_cannot_satisfy_dependency(self) -> None:
        record = self.qualified_receipt()
        for status in ("not-run", "unavailable", "failed", "blocked", "in-progress", "not-applicable"):
            with self.subTest(status=status):
                record["gates"][3].update(status=status, evidence=["bounded outcome"], limitation="Incomplete.")
                self.write_receipt(record)
                errors = self.errors(self.no_change_document())
                self.assertTrue(any("requires passed automated-quality-qualification" in e for e in errors))
                self.assertTrue(any("unsatisfied dependencies" in e for e in errors))

    def test_not_applicable_implementation_cannot_unlock_dependent(self) -> None:
        record = self.qualified_receipt()
        implementation = next(gate for gate in record["gates"] if gate["id"] == "implementation")
        implementation.update(status="not-applicable", evidence=[],
                              limitation="No implementation evidence is supplied.")
        self.write_receipt(record)
        errors = self.errors(self.no_change_document())
        self.assertTrue(any("requires passed implementation" in error for error in errors))
        self.assertTrue(any("AT-0003" in error and "unsatisfied dependencies" in error for error in errors))

    def test_explicit_release_only_exceptions_preserve_eligible_no_change(self) -> None:
        record = self.qualified_receipt()
        statuses = {gate["id"]: gate["status"] for gate in record["gates"]}
        self.assertEqual(statuses["implementation"], "passed")
        for identifier in ("published-exact-sha", "exact-head-ci", "release-app-launched",
                           "app-route-qa", "physical-output-soak"):
            self.assertEqual(statuses[identifier], "not-applicable")
        self.assertEqual(self.errors(self.no_change_document()), [])

    def test_unmet_other_applicable_gate_cannot_satisfy_dependency(self) -> None:
        record = self.qualified_receipt()
        for gate in record["gates"]:
            if gate["id"] not in integrity.results.RELEASE_REQUIRED_GATES:
                continue
            previous = dict(gate)
            with self.subTest(gate=gate["id"]):
                gate.update(status="blocked", evidence=[], limitation="Required gate remains blocked.")
                self.write_receipt(record)
                self.assertTrue(any("unmet applicable gate" in e for e in self.errors(self.no_change_document())))
            gate.update(previous)

    def test_wrong_subject_and_stale_revision_are_rejected(self) -> None:
        record = self.qualified_receipt()
        record["subject"] = "AT-0001"
        self.write_receipt(record)
        self.assertTrue(any("subject must match" in e for e in self.errors(self.no_change_document())))
        record["subject"] = "AT-0002"
        record["revision"] = "a" * 40
        self.write_receipt(record)
        self.assertTrue(any("current clean exact source" in e for e in self.errors(self.no_change_document())))
        record["revision"] = "working-tree"
        self.write_receipt(record)
        self.assertTrue(any("40-digit exact revision" in e for e in self.errors(self.no_change_document())))

    def test_dirty_or_untracked_source_is_not_current(self) -> None:
        self.qualified_receipt()
        vocabulary = self.root / "docs/RESULT_STATUS_VOCABULARY.json"
        original = vocabulary.read_bytes()
        vocabulary.write_bytes(original + b"\n")
        self.assertTrue(any("current clean exact source" in e for e in self.errors(self.no_change_document())))
        vocabulary.write_bytes(original)
        (self.root / "new-source.py").write_text("changed = True\n", encoding="utf-8")
        self.assertTrue(any("current clean exact source" in e for e in self.errors(self.no_change_document())))

    def test_malformed_record_and_vocabulary_fail_closed(self) -> None:
        self.qualified_receipt()
        receipt = self.root / "docs/local/result-records/AT-0002.json"
        for value in ("not JSON", "[]", '{"gates": null}'):
            with self.subTest(value=value):
                receipt.write_text(value, encoding="utf-8")
                self.assertTrue(self.errors(self.no_change_document()))
        self.qualified_receipt()
        vocabulary = self.root / "docs/RESULT_STATUS_VOCABULARY.json"
        value = json.loads(vocabulary.read_text())
        value["claim"]["requiredGates"] = None
        vocabulary.write_text(json.dumps(value), encoding="utf-8")
        self.assertTrue(any("malformed receipt or vocabulary" in e for e in self.errors(self.no_change_document())))

    def test_external_receipt_symlink_is_rejected(self) -> None:
        self.qualified_receipt()
        receipt = self.root / "docs/local/result-records/AT-0002.json"
        with tempfile.TemporaryDirectory() as other:
            external = Path(other) / "receipt.json"
            external.write_bytes(receipt.read_bytes())
            receipt.unlink()
            receipt.symlink_to(external)
            self.assertTrue(any("inside the repository" in e for e in self.errors(self.no_change_document())))

    def test_no_change_receipt_does_not_waive_lowest_eligible_selection(self) -> None:
        self.qualified_receipt()
        self.write_plan("AT-0004")
        document = self.no_change_document().replace("active_item: AT-0003", "active_item: AT-0004").replace(
            "active_plan: docs/local/roadmap-plans/AT-0003.md", "active_plan: docs/local/roadmap-plans/AT-0004.md"
        ).replace("AT-0003 | `researching`", "AT-0003 | `queued`")
        document += "| AT-0004 | `researching` | AT-0002 | outcome | evidence |\n"
        self.assertTrue(any("skips lower eligible item AT-0003" in e for e in self.errors(document)))

    def test_unqualified_no_change_does_not_make_queued_row_eligible(self) -> None:
        self.qualified_receipt()
        record = json.loads((self.root / "docs/local/result-records/AT-0002.json").read_text())
        record["gates"][3].update(status="not-run", evidence=[], limitation="Not qualified.")
        self.write_receipt(record)
        self.write_plan("AT-0004")
        document = self.no_change_document().replace("active_item: AT-0003", "active_item: AT-0004").replace(
            "active_plan: docs/local/roadmap-plans/AT-0003.md", "active_plan: docs/local/roadmap-plans/AT-0004.md"
        ).replace("AT-0003 | `researching`", "AT-0003 | `queued`")
        document += "| AT-0004 | `researching` | AT-0001 | outcome | evidence |\n"
        errors = self.errors(document)
        self.assertTrue(any("requires passed automated-quality-qualification" in e for e in errors))
        self.assertFalse(any("skips lower eligible" in e for e in errors))


    def test_changed_measured_requirement_invalidates_no_change_receipt(self) -> None:
        self.qualified_receipt()
        document = self.no_change_document()
        self.assertEqual(self.errors(document), [])
        changed = document.replace(
            "`verified-no-change` | AT-0001 | outcome |",
            "`verified-no-change` | AT-0001 | newly required outcome with no measured proof |",
        )
        self.assertTrue(any("acceptance plan scope" in e for e in self.errors(changed)))
        self.assertTrue(any("unsatisfied dependencies" in e for e in self.errors(changed)))

    def test_changed_acceptance_plan_invalidates_no_change_receipt(self) -> None:
        self.qualified_receipt()
        plan = self.root / "docs/local/roadmap-plans/AT-0002.md"
        plan.write_text("new acceptance requirement\n", encoding="utf-8")
        self.assertTrue(any("acceptance plan scope" in e for e in self.errors(self.no_change_document())))
        plan.unlink()
        self.assertTrue(any("cannot read no-change acceptance plan" in e for e in self.errors(self.no_change_document())))

    def test_changed_dependency_scope_invalidates_no_change_receipt(self) -> None:
        self.qualified_receipt()
        changed = self.no_change_document().replace(
            "`verified-no-change` | AT-0001 | outcome", "`verified-no-change` | — | outcome"
        )
        self.assertTrue(any("acceptance plan scope" in e for e in self.errors(changed)))

    def test_scope_marker_alone_is_not_measured_evidence(self) -> None:
        record = self.qualified_receipt()
        evidence = record["gates"][1]["evidence"]
        record["gates"][1]["evidence"] = [value for value in evidence if value.startswith("roadmap-scope-sha256:")]
        self.write_receipt(record)
        self.assertTrue(any("not measured verification evidence" in e for e in self.errors(self.no_change_document())))


    def bind_no_change_row(
        self, document: str, identifier: str, template: dict[str, object]
    ) -> str:
        self.write_plan(identifier)
        item = next(item for item in integrity.parse_items(document)[0] if item.identifier == identifier)
        record = copy.deepcopy(template)
        record["subject"] = identifier
        record["gates"][1]["evidence"] = [
            "current measured outcome",
            "roadmap-scope-sha256:" + integrity.no_change_scope_fingerprint(item, self.root),
        ]
        self.write_receipt(record, identifier)
        lines = document.splitlines()
        for index, line in enumerate(lines):
            if line.startswith(f"| {identifier} |"):
                lines[index] = line.replace("| evidence |", f"| [qualification](docs/local/result-records/{identifier}.json) |")
        return "\n".join(lines) + "\n"

    def test_current_receipt_cannot_waive_blocked_or_queued_prerequisite(self) -> None:
        template = self.qualified_receipt()
        self.write_plan("AT-0004")
        for status in ("blocked", "queued"):
            with self.subTest(status=status):
                document = self.document([
                    ("AT-0001", "completed", "—"),
                    ("AT-0002", status, "AT-0001"),
                    ("AT-0003", "verified-no-change", "AT-0002"),
                    ("AT-0004", "researching", "AT-0003"),
                ], active="AT-0004")
                document = self.bind_no_change_row(document, "AT-0003", template)
                errors = self.errors(document)
                self.assertTrue(any("AT-0003 verified-no-change has unsatisfied prerequisites: AT-0002" in e for e in errors))
                self.assertTrue(any("active item AT-0004 has unsatisfied dependencies: AT-0003" in e for e in errors))

    def test_valid_no_change_chain_satisfies_dependencies_in_any_id_order(self) -> None:
        template = self.qualified_receipt()
        self.write_plan("AT-0004")
        for dependencies in (("AT-0001", "AT-0002", "AT-0003"),
                             ("AT-0003", "AT-0001", "AT-0002")):
            with self.subTest(dependencies=dependencies):
                document = self.document([
                    ("AT-0001", "completed", "—"),
                    ("AT-0002", "verified-no-change", dependencies[0]),
                    ("AT-0003", "verified-no-change", dependencies[1]),
                    ("AT-0004", "researching", dependencies[2]),
                ], active="AT-0004")
                document = self.bind_no_change_row(document, "AT-0002", template)
                document = self.bind_no_change_row(document, "AT-0003", template)
                self.assertEqual(self.errors(document), [])

    def test_invalid_receipt_in_chain_cannot_unlock_descendants(self) -> None:
        template = self.qualified_receipt()
        self.write_plan("AT-0004")
        document = self.document([
            ("AT-0001", "completed", "—"),
            ("AT-0002", "verified-no-change", "AT-0001"),
            ("AT-0003", "verified-no-change", "AT-0002"),
            ("AT-0004", "researching", "AT-0003"),
        ], active="AT-0004")
        document = self.bind_no_change_row(document, "AT-0002", template)
        document = self.bind_no_change_row(document, "AT-0003", template)
        (self.root / "docs/local/result-records/AT-0002.json").unlink()
        errors = self.errors(document)
        self.assertTrue(any("AT-0002 verified-no-change: cannot read" in e for e in errors))
        self.assertTrue(any("AT-0003 verified-no-change has unsatisfied prerequisites" in e for e in errors))
        self.assertTrue(any("active item AT-0004 has unsatisfied dependencies" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
