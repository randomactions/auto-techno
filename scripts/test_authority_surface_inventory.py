#!/usr/bin/env python3
"""Unit tests for the authority-surface collision inventory gate."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("authority_surface_inventory.py")
SPEC = importlib.util.spec_from_file_location("authority_surface_inventory", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
inventory = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = inventory
SPEC.loader.exec_module(inventory)


class AuthoritySurfaceInventoryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "Sources/Fixture/Resources").mkdir(parents=True)
        (self.root / "Tests").mkdir()
        (self.root / "docs").mkdir()
        (self.root / "Sources/Fixture/Runtime.swift").write_text(
            """package struct CanonicalDirector {}
package enum ChildRenderer {}
package struct CalibrationProfile {}
enum Vocabulary {
    private static let hiddenPresets = [1]
}
func converge() {}
""",
            encoding="utf-8",
        )
        (self.root / "Sources/Fixture/Effect.swift").write_text(
            "enum EffectStage {}\nfunc process() {}\n",
            encoding="utf-8",
        )
        (self.root / "Sources/Fixture/Resources/current-profile.json").write_text(
            "{}\n", encoding="utf-8"
        )
        (self.root / "Tests/FixtureTests.swift").write_text(
            "func evidence() {}\n", encoding="utf-8"
        )
        map_manifest = {
            "components": [
                {
                    "id": "fixture",
                    "sourcePaths": [
                        "Sources/Fixture/Runtime.swift",
                        "Sources/Fixture/Resources/current-profile.json",
                    ],
                    "ownerAnchors": [{"symbol": "CanonicalDirector"}],
                },
                {
                    "id": "graph-effects-routing-and-mix",
                    "sourcePaths": ["Sources/Fixture/Effect.swift"],
                    "ownerAnchors": [],
                },
            ]
        }
        inventory.codebase_map_path(self.root).write_text(
            json.dumps(map_manifest), encoding="utf-8"
        )
        anchor = {"path": "Sources/Fixture/Runtime.swift", "fragment": "func converge()"}
        evidence = {"path": "Tests/FixtureTests.swift", "fragment": "func evidence()"}
        self.manifest = {
            "schema": inventory.SCHEMA,
            "inventoryVersion": 1,
            "scopePolicy": "Fixture scope.",
            "authorityGroups": [
                self.group(
                    "director", "canonical-owner", "fixture", "fixture",
                    [{"path": "Sources/Fixture/Runtime.swift", "symbol": "CanonicalDirector", "kind": "struct"}],
                    anchor, evidence,
                ),
                self.group(
                    "renderer", "owned-stage", "fixture", "fixture",
                    [{"path": "Sources/Fixture/Runtime.swift", "symbol": "ChildRenderer", "kind": "enum"}],
                    anchor, evidence,
                ),
            ],
            "profileGroups": [
                self.group(
                    "profiles", "installed-calibration-artifact", "fixture", "fixture",
                    [
                        {"path": "Sources/Fixture/Runtime.swift", "symbol": "CalibrationProfile", "kind": "struct"},
                        {"path": "Sources/Fixture/Runtime.swift", "symbol": "hiddenPresets", "kind": "static-value"},
                        {"path": "Sources/Fixture/Resources/current-profile.json", "symbol": "current-profile", "kind": "json-resource"},
                    ],
                    anchor, evidence, category="profile",
                )
            ],
            "effectPaths": [{
                "id": "effect", "title": "effect",
                "classification": "owned-effect-stage",
                "canonicalComponent": "graph-effects-routing-and-mix",
                "sourcePath": "Sources/Fixture/Effect.swift",
                "entryAnchors": [{"path": "Sources/Fixture/Effect.swift", "fragment": "func process()"}],
                "convergenceAnchors": [anchor], "evidenceAnchors": [evidence],
                "pcmConsequence": "processes-future-pcm",
                "limitations": "Fixture limitation.",
            }],
        }
        self.write(self.manifest)

    def group(
        self, group_id: str, classification: str, surface: str, canonical: str,
        members: list[dict[str, str]], anchor: dict[str, str], evidence: dict[str, str],
        *, category: str = "decision",
    ) -> dict[str, object]:
        return {
            "id": group_id, "title": group_id, "category": category,
            "classification": classification, "surfaceComponent": surface,
            "canonicalComponent": canonical, "members": members,
            "convergenceAnchors": [anchor], "evidenceAnchors": [evidence],
            "pcmConsequence": "none", "limitations": "Fixture limitation.",
        }

    def write(self, manifest: dict[str, object]) -> None:
        inventory.manifest_path(self.root).write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        inventory.report_path(self.root).write_text(
            inventory.render_markdown(manifest), encoding="utf-8"
        )

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return inventory.run_check(self.root, output), output.getvalue()

    def test_current_inventory_passes_and_is_deterministic(self) -> None:
        result, diagnostic = self.check()
        self.assertEqual(result, 0)
        self.assertIn("2 authority surfaces", diagnostic)
        self.assertEqual(
            inventory.render_markdown(self.manifest),
            inventory.render_markdown(copy.deepcopy(self.manifest)),
        )

    def test_new_authority_and_resource_fail_closed(self) -> None:
        runtime = self.root / "Sources/Fixture/Runtime.swift"
        runtime.write_text(
            runtime.read_text(encoding="utf-8")
            + "package enum HiddenEvaluator {}\n"
            + "enum Shadow {\n    static let shadowProfile = 1\n}\n",
            encoding="utf-8",
        )
        (self.root / "Sources/Fixture/Resources/hidden.json").write_text(
            "{}\n", encoding="utf-8"
        )
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("HiddenEvaluator", diagnostic)
        self.assertIn("shadowProfile", diagnostic)
        self.assertIn("hidden:json-resource", diagnostic)

    def test_stale_duplicate_and_wrong_component_members_fail(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        duplicate = copy.deepcopy(manifest["authorityGroups"][0]["members"][0])
        manifest["authorityGroups"][1]["members"].append(duplicate)
        manifest["authorityGroups"][1]["members"][0]["symbol"] = "MissingRenderer"
        manifest["authorityGroups"][1]["surfaceComponent"] = "graph-effects-routing-and-mix"
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("names absent surfaces", diagnostic)
        self.assertIn("not owned by component", diagnostic)

    def test_effect_component_path_coverage_fails_closed(self) -> None:
        second = self.root / "Sources/Fixture/SecondEffect.swift"
        second.write_text("func effectTwo() {}\n", encoding="utf-8")
        map_manifest = json.loads(
            inventory.codebase_map_path(self.root).read_text(encoding="utf-8")
        )
        map_manifest["components"][1]["sourcePaths"].append(
            "Sources/Fixture/SecondEffect.swift"
        )
        inventory.codebase_map_path(self.root).write_text(
            json.dumps(map_manifest), encoding="utf-8"
        )
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("effectPaths omits graph component paths", diagnostic)

    def test_missing_anchor_and_stale_report_fail(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["authorityGroups"][0]["convergenceAnchors"][0]["fragment"] = "missing()"
        self.write(manifest)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("fragment is missing", diagnostic)

        self.write(self.manifest)
        inventory.report_path(self.root).write_text("stale\n", encoding="utf-8")
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("report is stale", diagnostic)


if __name__ == "__main__":
    unittest.main()
