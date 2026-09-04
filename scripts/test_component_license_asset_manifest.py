#!/usr/bin/env python3
"""Unit tests for the component licence and asset manifest gate."""

from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("component_license_asset_manifest.py")
SPEC = importlib.util.spec_from_file_location(
    "component_license_asset_manifest", MODULE_PATH
)
assert SPEC is not None and SPEC.loader is not None
inventory = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = inventory
SPEC.loader.exec_module(inventory)


class ComponentLicenseAssetManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write(
            "Package.swift",
            '// swift-tools-version: 6.0\n'
            'let dependency = .package(url: "https://example.test/swift-testing.git", exact: "1.0.0")\n'
            'let library = .linkedLibrary("gdi32")\n',
        )
        self.write(
            "Package.resolved",
            json.dumps({
                "version": 3,
                "pins": [{
                    "identity": "swift-testing",
                    "kind": "remoteSourceControl",
                    "location": "https://example.test/swift-testing.git",
                    "state": {"version": "1.0.0", "revision": "a" * 40},
                }],
            }),
        )
        self.write("Sources/App/main.swift", "import Foundation\n")
        self.write(
            ".github/workflows/test.yml",
            "steps:\n  - uses: actions/checkout@" + "c" * 40 + "\n",
        )
        self.write("LICENSE", "fixture licence\n")
        self.write(".gitignore", "docs/local/\n")
        self.manifest = self.fixture_manifest()
        self.write(
            "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json",
            json.dumps(self.manifest, indent=2) + "\n",
        )
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)

    def write(self, path: str, contents: str) -> None:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")

    def component(
        self,
        identifier: str,
        kind: str,
        bindings: list[str],
        anchors: list[str],
        *,
        source: str = "https://example.test/source",
        version: str = "1",
        revision: str = "revision",
    ) -> dict[str, object]:
        return {
            "id": identifier,
            "name": identifier,
            "kind": kind,
            "version": version,
            "revision": revision,
            "source": source,
            "license": "MIT",
            "licenseSource": "https://example.test/license",
            "notice": "none",
            "noticeSource": "https://example.test/notice",
            "role": "fixture",
            "distribution": "build-only" if kind != "project" else "repository-source",
            "provenanceClass": "GREEN-OPEN-SOURCE" if kind != "project" else "GREEN-ORIGINAL",
            "disposition": "retain-with-release-gate" if kind != "project" else "retain",
            "bindings": bindings,
            "sourceAnchors": anchors,
        }

    def fixture_manifest(self) -> dict[str, object]:
        components = [
            self.component(
                "action", "ci-action",
                ["ci-action:actions/checkout@" + "c" * 40],
                [".github/workflows/test.yml"],
                revision="c" * 40,
            ),
            self.component(
                "foundation", "platform-sdk", ["swift-import:Foundation"],
                ["Sources/App/main.swift"],
            ),
            self.component(
                "gdi", "platform-sdk", ["linked-library:gdi32"], ["Package.swift"],
            ),
            self.component("project", "project", [], ["LICENSE"]),
            self.component(
                "swift-testing", "package-direct", ["package:swift-testing"],
                ["Package.resolved", "Package.swift"],
                source="https://example.test/swift-testing.git",
                version="1.0.0",
                revision="a" * 40,
            ),
        ]
        licence_hash = hashlib.sha256(b"fixture licence\n").hexdigest()
        return {
            "schema": inventory.SCHEMA,
            "manifestVersion": 1,
            "accessDate": "2026-08-31",
            "scopePolicy": "fixture scope",
            "components": components,
            "assets": [{
                "path": "LICENSE",
                "kind": "project-licence",
                "sha256": licence_hash,
                "licenseComponent": "project",
                "origin": "fixture",
                "role": "licence",
                "distribution": "repository-source",
                "disposition": "retain",
                "sourceAnchors": ["LICENSE"],
            }],
            "localArtifactClasses": [{
                "id": "private-roadmap",
                "pathPattern": "docs/local/**",
                "ignoreRule": "docs/local/",
                "kinds": ["private research"],
                "role": "fixture",
                "licensePolicy": "local only",
                "disposition": "local-only-untracked",
            }],
            "reviewFindings": [],
        }

    def save_manifest(self) -> None:
        self.write(
            "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json",
            json.dumps(self.manifest, indent=2) + "\n",
        )

    def compare(self) -> list[str]:
        return inventory.compare_to_repository(
            self.manifest, self.root, inventory.tracked_paths(self.root)
        )

    def test_render_and_check_are_deterministic(self) -> None:
        first = io.StringIO()
        self.assertEqual(inventory.run_render(self.root, first), 0)
        rendered = inventory.report_path(self.root).read_bytes()
        self.assertEqual(inventory.run_render(self.root, io.StringIO()), 0)
        self.assertEqual(inventory.report_path(self.root).read_bytes(), rendered)
        output = io.StringIO()
        self.assertEqual(inventory.run_check(self.root, output), 0)
        self.assertIn("component manifest is current", output.getvalue())

    def test_missing_licence_field_is_rejected(self) -> None:
        self.manifest["components"][0]["license"] = ""  # type: ignore[index]
        self.assertTrue(any(".license must be" in error for error in inventory.validate_manifest(self.manifest)))

    def test_invalid_disposition_is_rejected(self) -> None:
        self.manifest["assets"][0]["disposition"] = "ship-it"  # type: ignore[index]
        self.assertTrue(any("disposition is unsupported" in error for error in inventory.validate_manifest(self.manifest)))

    def test_undeclared_import_binding_is_rejected(self) -> None:
        self.manifest["components"][1]["bindings"] = []  # type: ignore[index]
        self.assertTrue(any("undeclared dependency bindings" in error for error in self.compare()))

    def test_package_version_mismatch_is_rejected(self) -> None:
        self.manifest["components"][4]["version"] = "2.0.0"  # type: ignore[index]
        self.assertTrue(any("package:swift-testing version mismatch" in error for error in self.compare()))

    def test_mutable_ci_action_selector_is_rejected(self) -> None:
        self.write(
            ".github/workflows/test.yml",
            "steps:\n  - uses: actions/checkout@v4\n",
        )
        self.manifest["components"][0]["bindings"] = [  # type: ignore[index]
            "ci-action:actions/checkout@v4"
        ]
        self.manifest["components"][0]["revision"] = "v4"  # type: ignore[index]
        self.assertTrue(any("must use an exact 40-digit revision" in error for error in self.compare()))

    def test_undeclared_resolved_pin_is_rejected(self) -> None:
        resolved = json.loads((self.root / "Package.resolved").read_text(encoding="utf-8"))
        resolved["pins"].append({
            "identity": "swift-syntax",
            "kind": "remoteSourceControl",
            "location": "https://example.test/swift-syntax.git",
            "state": {"version": "1.0.0", "revision": "b" * 40},
        })
        self.write("Package.resolved", json.dumps(resolved))
        self.assertTrue(any("package component coverage mismatch" in error for error in self.compare()))

    def test_undeclared_resource_is_rejected(self) -> None:
        self.write("Sources/App/Resources/new.json", "{}\n")
        subprocess.run(
            ["git", "add", "Sources/App/Resources/new.json"], cwd=self.root, check=True
        )
        self.assertTrue(any("undeclared governed assets" in error for error in self.compare()))

    def test_asset_hash_mismatch_is_rejected(self) -> None:
        self.write("LICENSE", "mutated\n")
        self.assertTrue(any("governed asset hash mismatch" in error for error in self.compare()))

    def test_tracked_private_artifact_is_rejected(self) -> None:
        self.write("docs/local/note.md", "private\n")
        subprocess.run(
            ["git", "add", "-f", "docs/local/note.md"], cwd=self.root, check=True
        )
        self.assertTrue(any("forbidden local artifacts are tracked" in error for error in self.compare()))

    def test_missing_ignore_rule_is_rejected(self) -> None:
        self.write(".gitignore", "")
        self.assertTrue(any("ignore rule is missing" in error for error in self.compare()))

    def test_repository_windows_distribution_path_remains_isolated(self) -> None:
        repository_root = MODULE_PATH.parents[1]
        build_script = (repository_root / "scripts/build-windows.ps1").read_text(
            encoding="utf-8"
        )
        setup_script = (repository_root / "scripts/setup-windows-build.ps1").read_text(
            encoding="utf-8"
        )
        command_wrapper = (repository_root / "scripts/build-windows.cmd").read_text(
            encoding="utf-8"
        )
        workflow = (
            repository_root / ".github/workflows/windows-distribution.yml"
        ).read_text(encoding="utf-8")

        for forbidden in (
            "Copy-Item",
            "Compress-Archive",
            "GetSwiftRuntimeLibraryPaths",
            "VC\\Redist",
            "BUILD-MANIFEST",
            "CHECKSUMS",
            "ISCC",
        ):
            self.assertNotIn(forbidden, build_script)
        self.assertNotIn("JRSoftware.InnoSetup", setup_script)
        self.assertNotIn("-Installer", command_wrapper)
        self.assertNotIn("actions/upload-artifact", workflow)
        self.assertNotIn("JRSoftware.InnoSetup", workflow)
        self.assertNotIn("-Installer", workflow)

    def test_stale_generated_report_is_rejected(self) -> None:
        self.assertEqual(inventory.run_render(self.root, io.StringIO()), 0)
        self.write("docs/COMPONENT_LICENSE_ASSET_MANIFEST.md", "stale\n")
        output = io.StringIO()
        self.assertEqual(inventory.run_check(self.root, output), 1)
        self.assertIn("Markdown is stale", output.getvalue())


if __name__ == "__main__":
    unittest.main()
