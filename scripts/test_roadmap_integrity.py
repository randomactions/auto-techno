#!/usr/bin/env python3
"""Unit tests for the autonomous roadmap integrity checker."""

from __future__ import annotations

import importlib.util
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


if __name__ == "__main__":
    unittest.main()
