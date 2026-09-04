#!/usr/bin/env python3
"""Unit tests for the parameter reachability audit gate."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("parameter_reachability_audit.py")
SPEC = importlib.util.spec_from_file_location("parameter_reachability_audit", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
audit = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = audit
SPEC.loader.exec_module(audit)


class ParameterReachabilityAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "Sources").mkdir()
        (self.root / "Tests").mkdir()
        (self.root / "docs").mkdir()
        (self.root / "Sources/Fixture.swift").write_text(
            """package enum Control: String {
    case active
    case dormant
}

package struct Parameters {
    package let amount: Double
    package let mode: Int
    package private(set) var bounded: Int
    package var computed: Bool { amount > 0 }
}

func consume() { _ = Control.active }
""",
            encoding="utf-8",
        )
        (self.root / "Tests/FixtureTests.swift").write_text(
            "func causalPCM() {}\nfunc evidencePath() {}\nfunc futureDecision() {}\n",
            encoding="utf-8",
        )
        self.manifest = {
            "schema": audit.SCHEMA,
            "auditVersion": 1,
            "scopePolicy": "Fixture policy.",
            "domains": [
                self.domain(
                    "active-control",
                    [{
                        "path": "Sources/Fixture.swift",
                        "type": "Control",
                        "kind": "enum-cases",
                        "selection": "explicit",
                        "members": ["active"],
                    }],
                ),
                self.domain(
                    "dormant-control",
                    [{
                        "path": "Sources/Fixture.swift",
                        "type": "Control",
                        "kind": "enum-cases",
                        "selection": "explicit",
                        "members": ["dormant"],
                    }],
                    classification="quarantined-no-pcm",
                    forbidden=[{
                        "path": "Sources/Fixture.swift",
                        "fragment": "renderDormant()",
                    }],
                ),
                self.domain(
                    "parameters",
                    [{
                        "path": "Sources/Fixture.swift",
                        "type": "Parameters",
                        "kind": "stored-properties",
                        "selection": "all",
                        "members": ["amount", "mode", "bounded"],
                    }],
                ),
            ],
        }
        self.write(self.manifest)

    def domain(
        self,
        domain_id: str,
        owners: list[dict[str, object]],
        *,
        classification: str = "active-rendered",
        forbidden: list[dict[str, str]] | None = None,
    ) -> dict[str, object]:
        return {
            "id": domain_id,
            "title": domain_id,
            "classification": classification,
            "owners": owners,
            "consumerAnchors": [{
                "path": "Sources/Fixture.swift",
                "fragment": "func consume()",
            }],
            "pcmEvidence": {
                "status": "quarantined-no-pcm" if classification == "quarantined-no-pcm" else "direct-causal",
                "path": "Tests/FixtureTests.swift",
                "fragment": "func causalPCM()",
            },
            "signalEvidence": {
                "status": "unavailable-quarantined" if classification == "quarantined-no-pcm" else "direct-evidence",
                "path": "Tests/FixtureTests.swift",
                "fragment": "func evidencePath()",
            },
            "futureDecision": {
                "status": "quarantined" if classification == "quarantined-no-pcm" else "direct-adaptation",
                "path": "Tests/FixtureTests.swift",
                "fragment": "func futureDecision()",
            },
            "forbiddenAnchors": forbidden or [],
            "limitations": "Fixture limitation.",
        }

    def write(self, manifest: dict[str, object]) -> None:
        audit.manifest_path(self.root).write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        audit.report_path(self.root).write_text(
            audit.render_markdown(manifest), encoding="utf-8"
        )

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return audit.run_check(self.root, output), output.getvalue()

    def test_current_partitioned_audit_passes_and_is_deterministic(self) -> None:
        result, diagnostic = self.check()
        self.assertEqual(result, 0)
        self.assertIn("5 classified members", diagnostic)
        first = audit.render_markdown(self.manifest)
        self.assertEqual(first, audit.render_markdown(copy.deepcopy(self.manifest)))

    def test_new_member_fails_closed_until_classified(self) -> None:
        path = self.root / "Sources/Fixture.swift"
        path.write_text(
            path.read_text(encoding="utf-8").replace(
                "    case dormant\n", "    case dormant\n    case newControl\n"
            ),
            encoding="utf-8",
        )
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("unclassified current members: newControl", diagnostic)

    def test_stale_all_selection_and_report_are_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["domains"][2]["owners"][0]["members"] = ["mode", "amount"]
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("members are stale or reordered", diagnostic)

        self.write(self.manifest)
        audit.report_path(self.root).write_text("stale\n", encoding="utf-8")
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("generated parameter audit report is stale", diagnostic)

    def test_missing_required_and_present_forbidden_anchors_fail(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["domains"][0]["consumerAnchors"][0]["fragment"] = "missing()"
        manifest["domains"][1]["forbiddenAnchors"][0]["fragment"] = "func consume()"
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("fragment is missing", diagnostic)
        self.assertIn("forbidden fragment is present", diagnostic)

    def test_refresh_requires_version_change_only_for_declaration_drift(self) -> None:
        with self.assertRaisesRegex(
            audit.ParameterReachabilityError, "retain audit version 1"
        ):
            audit.refreshed_manifest(self.manifest, self.root, 2)
        path = self.root / "Sources/Fixture.swift"
        path.write_text(
            path.read_text(encoding="utf-8").replace(
                "    package let mode: Int\n",
                "    package let mode: Int\n    package let depth: Double\n",
            ),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(
            audit.ParameterReachabilityError, "increment --audit-version above 1"
        ):
            audit.refreshed_manifest(self.manifest, self.root, 1)
        refreshed = audit.refreshed_manifest(self.manifest, self.root, 2)
        self.assertEqual(
            refreshed["domains"][2]["owners"][0]["members"],
            ["amount", "mode", "depth", "bounded"],
        )


if __name__ == "__main__":
    unittest.main()
