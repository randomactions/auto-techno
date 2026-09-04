#!/usr/bin/env python3
"""Unit tests for the aggregate phase-0 coherence gate."""

from __future__ import annotations

import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("phase_zero_gate.py")
SPEC = importlib.util.spec_from_file_location("phase_zero_gate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)


class PhaseZeroGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write_json(
            "docs/PARAMETER_REACHABILITY_AUDIT.json",
            {
                "schema": "autotechno-parameter-reachability-audit.v1",
                "auditVersion": 2,
                "domains": [{
                    "id": "active",
                    "classification": "active-rendered",
                    "owners": [{"members": ["amount"]}],
                    "consumerAnchors": [{"path": "source"}],
                    "pcmEvidence": {"status": "direct-causal"},
                    "signalEvidence": {"status": "direct-evidence"},
                    "futureDecision": {"status": "fixed-contract-with-evidence"},
                }],
            },
        )
        self.write_json(
            "docs/AUTHORITY_SURFACE_INVENTORY.json",
            {
                "schema": "autotechno-authority-surface-inventory.v1",
                "inventoryVersion": 1,
                "authorityGroups": [{
                    "id": "owner",
                    "surfaceComponent": "canonical",
                    "canonicalComponent": "canonical",
                    "convergenceAnchors": [{"path": "source"}],
                    "evidenceAnchors": [{"path": "test"}],
                }],
                "profileGroups": [],
                "effectPaths": [],
            },
        )
        self.write_json(
            "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json",
            {
                "schema": "autotechno-component-license-asset-manifest.v1",
                "manifestVersion": 1,
                "components": [{
                    "id": "project",
                    "provenanceClass": "GREEN-ORIGINAL",
                    "disposition": "retain",
                }],
                "reviewFindings": [{"id": "clear", "severity": "green"}],
            },
        )
        self.write("docs/local/roadmap-plans/AT-0002.md", "plan\n")
        self.write(
            "docs/local/SYNTH_FX_DSP_RESEARCH_STUDY.md",
            self.roadmap(),
        )

    def write(self, path: str, contents: str) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")

    def write_json(self, path: str, value: object) -> None:
        self.write(path, json.dumps(value, indent=2) + "\n")

    def roadmap(self) -> str:
        statuses = "\n".join(
            f"| `{status}` | fixture |" for status in gate.roadmap_integrity.ALLOWED_STATUSES
        )
        return f"""## Control C — Machine-readable roadmap controller

```yaml
roadmap_schema: autotechno-evolution.v1
roadmap_status: active
roadmap_revision: 1
last_updated_utc: 2026-08-31
active_item: AT-0002
active_plan: docs/local/roadmap-plans/AT-0002.md
last_completed_item: AT-0001
selection_policy: lowest_order_eligible_item
maximum_concurrent_items: 1
discovery_inbox_open: 0
quality_claim: bounded-calibrated-no-general-professional-claim
local_only: true
```

## Control D — Status model and autonomous selection

| Status | Meaning |
|---|---|
{statuses}

## Control E — One-item autonomous work cycle

| AT-0001 | `completed` | — | outcome | evidence |
| AT-0002 | `researching` | AT-0001 | outcome | evidence |
"""

    @staticmethod
    def passing_runner(*args: object, **kwargs: object) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args=[], returncode=0, stdout="passed\n")

    def test_generate_and_check_are_deterministic(self) -> None:
        self.assertEqual(gate.run_generate(self.root, io.StringIO(), self.passing_runner), 0)
        first_json = gate.report_json_path(self.root).read_bytes()
        first_markdown = gate.report_markdown_path(self.root).read_bytes()
        self.assertEqual(gate.run_generate(self.root, io.StringIO(), self.passing_runner), 0)
        self.assertEqual(gate.report_json_path(self.root).read_bytes(), first_json)
        self.assertEqual(gate.report_markdown_path(self.root).read_bytes(), first_markdown)
        self.assertEqual(gate.run_check(self.root, io.StringIO(), self.passing_runner), 0)

    def test_subordinate_command_failure_is_rejected(self) -> None:
        def failing_runner(*args: object, **kwargs: object) -> subprocess.CompletedProcess[str]:
            return subprocess.CompletedProcess(args=[], returncode=1, stdout="failed")

        with self.assertRaisesRegex(gate.PhaseZeroGateError, "subordinate check failed"):
            gate.build_report(self.root, failing_runner)

    def test_unowned_active_parameter_is_rejected(self) -> None:
        path = self.root / "docs/PARAMETER_REACHABILITY_AUDIT.json"
        value = json.loads(path.read_text(encoding="utf-8"))
        value["domains"][0]["owners"] = []
        self.write_json("docs/PARAMETER_REACHABILITY_AUDIT.json", value)
        with self.assertRaisesRegex(gate.PhaseZeroGateError, "active"):
            gate.analyze_authorities(self.root)

    def test_unresolved_duplicate_authority_is_rejected(self) -> None:
        path = self.root / "docs/AUTHORITY_SURFACE_INVENTORY.json"
        value = json.loads(path.read_text(encoding="utf-8"))
        value["authorityGroups"][0]["convergenceAnchors"] = []
        self.write_json("docs/AUTHORITY_SURFACE_INVENTORY.json", value)
        with self.assertRaisesRegex(gate.PhaseZeroGateError, "owner"):
            gate.analyze_authorities(self.root)

    def test_invalid_roadmap_dependency_is_rejected(self) -> None:
        path = self.root / "docs/local/SYNTH_FX_DSP_RESEARCH_STUDY.md"
        path.write_text(self.roadmap().replace("AT-0001 | outcome", "AT-0099 | outcome"), encoding="utf-8")
        with self.assertRaisesRegex(gate.PhaseZeroGateError, "missing item"):
            gate.analyze_authorities(self.root)

    def test_red_or_yellow_component_finding_is_rejected(self) -> None:
        path = self.root / "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json"
        value = json.loads(path.read_text(encoding="utf-8"))
        value["reviewFindings"][0]["severity"] = "yellow"
        self.write_json("docs/COMPONENT_LICENSE_ASSET_MANIFEST.json", value)
        with self.assertRaisesRegex(gate.PhaseZeroGateError, "clear"):
            gate.analyze_authorities(self.root)

    def test_stale_generated_report_is_rejected(self) -> None:
        self.assertEqual(gate.run_generate(self.root, io.StringIO(), self.passing_runner), 0)
        gate.report_markdown_path(self.root).write_text("stale\n", encoding="utf-8")
        output = io.StringIO()
        self.assertEqual(gate.run_check(self.root, output, self.passing_runner), 1)
        self.assertIn("generated Markdown is stale", output.getvalue())


if __name__ == "__main__":
    unittest.main()
