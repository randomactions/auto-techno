#!/usr/bin/env python3
"""Unit tests for the semantic codebase map generator."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).with_name("codebase_map.py")
SPEC = importlib.util.spec_from_file_location("codebase_map", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
codebase_map = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = codebase_map
SPEC.loader.exec_module(codebase_map)


class SemanticMapFixture:
    def __init__(self, root: Path) -> None:
        self.root = root
        self._write("Sources/Core/Core.swift", "package struct Director {}\n")
        self._write("Sources/App/App.swift", "final class Host {}\n")
        self._write("Tests/CoreTests/CoreTests.swift", "struct CoreTests {}\n")
        self._write("docs/CONTRACT.md", "# Contract\n")
        self.targets = {
            "Core": codebase_map.PackageTarget("Core", "Sources/Core", (), "library"),
            "App": codebase_map.PackageTarget("App", "Sources/App", ("Core",), "executable"),
            "CoreTests": codebase_map.PackageTarget(
                "CoreTests", "Tests/CoreTests", ("Core",), "test"
            ),
        }
        self.symbols = codebase_map.lexical_symbols(
            root,
            [
                "Sources/Core/Core.swift",
                "Sources/App/App.swift",
                "Tests/CoreTests/CoreTests.swift",
            ],
        )
        self.manifest = {
            "schemaVersion": 2,
            "modulePolicies": [
                {
                    "target": "App",
                    "responsibility": "Host the prepared product.",
                    "allowedInternalDependencies": ["Core"],
                },
                {
                    "target": "Core",
                    "responsibility": "Own deterministic decisions.",
                    "allowedInternalDependencies": [],
                },
                {
                    "target": "CoreTests",
                    "responsibility": "Validate core behavior.",
                    "allowedInternalDependencies": ["Core"],
                },
            ],
            "components": [
                self._component(
                    "director",
                    "Director",
                    "Core",
                    "Sources/Core/Core.swift",
                    "Director",
                    ["Tests/CoreTests/CoreTests.swift"],
                    ["future-commit"],
                ),
                self._component(
                    "host",
                    "Host",
                    "App",
                    "Sources/App/App.swift",
                    "Host",
                    [],
                    [],
                    depends_on=["director"],
                ),
            ],
            "continuationStates": [
                {
                    "id": "director-state",
                    "name": "Director state",
                    "ownerComponent": "director",
                    "symbol": "Director",
                    "path": "Sources/Core/Core.swift",
                    "scope": "canonical-phrase",
                    "pcmRelationship": "Selects the future plan; owns no PCM.",
                }
            ],
            "transitions": [
                {
                    "id": "director-to-host",
                    "name": "Commit prepared state",
                    "fromComponent": "director",
                    "toComponent": "host",
                    "boundary": "future-commit",
                    "consumesState": ["director-state"],
                    "producesState": ["director-state"],
                    "artifact": "prepared state",
                    "pcmConsequence": "commits-immutable-pcm",
                    "failureBehavior": "Retain the last accepted state.",
                }
            ],
            "flows": [
                {
                    "id": "prepare-and-host",
                    "name": "Prepare and host",
                    "summary": "The director prepares state consumed by the host.",
                    "steps": [
                        {"component": "director", "artifact": "prepared state"},
                        {"component": "host", "artifact": "presented state"},
                    ],
                    "transitions": ["director-to-host"],
                    "contracts": ["docs/CONTRACT.md"],
                }
            ],
            "boundaries": [
                {
                    "id": "future-commit",
                    "name": "Future commit",
                    "ownerComponent": "director",
                    "executionContext": "Serial test context",
                    "allowedWork": "Commit validated future state.",
                    "forbiddenWork": "Mutate current immutable state.",
                    "failureBehavior": "Retain the last accepted state.",
                    "tests": ["Tests/CoreTests/CoreTests.swift"],
                }
            ],
        }

    def _write(self, path: str, contents: str) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")

    @staticmethod
    def _component(
        component_id: str,
        name: str,
        target: str,
        source_path: str,
        anchor: str,
        tests: list[str],
        boundaries: list[str],
        *,
        depends_on: list[str] | None = None,
    ) -> dict[str, object]:
        return {
            "id": component_id,
            "name": name,
            "responsibility": f"Own {name.lower()} behavior.",
            "targets": [target],
            "ownerAnchors": [{"symbol": anchor, "path": source_path}],
            "state": [f"{name} state"],
            "inputs": [f"{name} input"],
            "outputs": [f"{name} output"],
            "evidence": [f"{name} evidence"],
            "sourcePaths": [source_path],
            "testPaths": tests,
            "contracts": ["docs/CONTRACT.md"],
            "dependsOn": depends_on or [],
            "boundaries": boundaries,
        }

    def validate(self, manifest: dict[str, object] | None = None) -> list[str]:
        return codebase_map.validate_manifest(
            manifest or self.manifest,
            self.root,
            self.targets,
            self.symbols,
            check_guardrail_documents=False,
        )


class CodebaseMapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.fixture = SemanticMapFixture(Path(self.temporary.name))

    def assert_error_contains(self, manifest: dict[str, object], fragment: str) -> None:
        errors = self.fixture.validate(manifest)
        self.assertTrue(
            any(fragment in error for error in errors),
            f"expected diagnostic containing {fragment!r}; got {errors!r}",
        )

    def test_valid_fixture_and_deterministic_rendering(self) -> None:
        self.assertEqual(self.fixture.validate(), [])
        first = codebase_map.render_markdown(
            self.fixture.manifest, self.fixture.targets, self.fixture.symbols
        )
        second = codebase_map.render_markdown(
            self.fixture.manifest,
            dict(reversed(list(self.fixture.targets.items()))),
            set(reversed(sorted(self.fixture.symbols))),
        )
        self.assertEqual(first, second)
        self.assertNotIn(str(self.fixture.root), first)
        self.assertNotRegex(first, r"\b[0-9a-f]{40}\b")

    def test_unknown_field_and_unsupported_schema_fail(self) -> None:
        manifest = copy.deepcopy(self.fixture.manifest)
        manifest["unexpected"] = True
        manifest["schemaVersion"] = 99
        self.assert_error_contains(manifest, "unknown fields: unexpected")
        self.assert_error_contains(manifest, "schemaVersion must be 2")

    def test_path_normalization_rejects_absolute_parent_and_build_paths(self) -> None:
        for path in ["/tmp/file.swift", "Sources/../file.swift", ".build/file.swift"]:
            with self.subTest(path=path):
                with self.assertRaises(ValueError):
                    codebase_map.normalize_repo_path(path)
        self.assertEqual(
            codebase_map.normalize_repo_path("Sources/Core/Core.swift"),
            "Sources/Core/Core.swift",
        )

    def test_added_source_or_test_is_unmapped(self) -> None:
        self.fixture._write("Sources/Core/NewResource.bin", "fixture\n")
        self.fixture._write("Tests/CoreTests/NewTests.swift", "struct NewTests {}\n")
        errors = self.fixture.validate()
        self.assertIn("unmapped production file: Sources/Core/NewResource.bin", errors)
        self.assertIn("unmapped test file: Tests/CoreTests/NewTests.swift", errors)

    def test_moved_owner_anchor_fails_with_focused_diagnostic(self) -> None:
        manifest = copy.deepcopy(self.fixture.manifest)
        manifest["components"][0]["ownerAnchors"][0]["path"] = "Sources/App/App.swift"
        self.assert_error_contains(manifest, "path must be one of the component sourcePaths")
        self.assert_error_contains(manifest, "does not resolve declaration Director")

    def test_module_edge_change_fails_policy_validation(self) -> None:
        self.fixture.targets["App"] = codebase_map.PackageTarget(
            "App", "Sources/App", (), "executable"
        )
        self.assert_error_contains(self.fixture.manifest, "module policy for App")

    def test_invalid_component_flow_and_boundary_references_fail(self) -> None:
        manifest = copy.deepcopy(self.fixture.manifest)
        manifest["components"][1]["dependsOn"] = ["missing-component"]
        manifest["components"][1]["boundaries"] = ["missing-boundary"]
        manifest["flows"][0]["steps"][0]["component"] = "missing-component"
        manifest["boundaries"][0]["ownerComponent"] = "missing-component"
        self.assert_error_contains(manifest, "depends on unknown component missing-component")
        self.assert_error_contains(manifest, "references unknown boundary missing-boundary")
        self.assert_error_contains(manifest, "component references unknown component missing-component")
        self.assert_error_contains(manifest, "ownerComponent references unknown component")

    def test_continuation_and_transition_references_fail_closed(self) -> None:
        manifest = copy.deepcopy(self.fixture.manifest)
        manifest["continuationStates"][0]["symbol"] = "MissingState"
        manifest["transitions"][0]["consumesState"] = ["missing-state"]
        manifest["transitions"][0]["boundary"] = "missing-boundary"
        manifest["transitions"][0]["pcmConsequence"] = "sounds-better"
        self.assert_error_contains(manifest, "does not resolve declaration MissingState")
        self.assert_error_contains(manifest, "references unknown state missing-state")
        self.assert_error_contains(manifest, "references unknown boundary missing-boundary")
        self.assert_error_contains(manifest, "pcmConsequence must be one of")

    def test_flow_must_use_typed_transition_matching_adjacent_components(self) -> None:
        manifest = copy.deepcopy(self.fixture.manifest)
        manifest["transitions"][0]["toComponent"] = "director"
        self.assert_error_contains(manifest, "expected director -> host")

        manifest = copy.deepcopy(self.fixture.manifest)
        manifest["flows"][0]["transitions"] = []
        self.assert_error_contains(
            manifest, "must contain exactly one edge per adjacent step"
        )

    def test_unreferenced_continuation_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.fixture.manifest)
        extra = copy.deepcopy(manifest["continuationStates"][0])
        extra["id"] = "unreferenced-state"
        manifest["continuationStates"].append(extra)
        self.assert_error_contains(
            manifest, "continuation state unreferenced-state is not referenced"
        )

    def test_generate_and_check_are_idempotent_and_check_does_not_edit(self) -> None:
        docs = self.fixture.root / "docs"
        (docs / "codebase-map.json").write_text(
            json.dumps(self.fixture.manifest, indent=2) + "\n", encoding="utf-8"
        )
        real_validate_manifest = codebase_map.validate_manifest
        with mock.patch.object(codebase_map, "inspect_package", return_value=self.fixture.targets), mock.patch.object(
            codebase_map, "inspect_symbols", return_value=self.fixture.symbols
        ), mock.patch.object(
            codebase_map,
            "validate_manifest",
            side_effect=lambda manifest, root, targets, symbols: real_validate_manifest(
                manifest,
                root,
                targets,
                symbols,
                check_guardrail_documents=False,
            ),
        ):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(codebase_map.run("generate", self.fixture.root, None), 0)
                generated = (docs / "CODEBASE_MAP.md").read_bytes()
                self.assertEqual(codebase_map.run("check", self.fixture.root, None), 0)
                self.assertEqual(codebase_map.run("check", self.fixture.root, None), 0)
                self.assertEqual((docs / "CODEBASE_MAP.md").read_bytes(), generated)

                (docs / "CODEBASE_MAP.md").write_text("hand edit\n", encoding="utf-8")
                stale = (docs / "CODEBASE_MAP.md").read_bytes()
                self.assertEqual(codebase_map.run("check", self.fixture.root, None), 1)
                self.assertEqual((docs / "CODEBASE_MAP.md").read_bytes(), stale)
                self.assertEqual(codebase_map.run("generate", self.fixture.root, None), 0)
                self.assertEqual((docs / "CODEBASE_MAP.md").read_bytes(), generated)


if __name__ == "__main__":
    unittest.main()
