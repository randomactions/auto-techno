#!/usr/bin/env python3
"""Validate and render Auto Techno's dependency/licence/asset inventory."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence


SCHEMA = "autotechno-component-license-asset-manifest.v1"
ROOT_KEYS = {
    "schema", "manifestVersion", "accessDate", "scopePolicy", "components",
    "assets", "localArtifactClasses", "reviewFindings",
}
COMPONENT_KEYS = {
    "id", "name", "kind", "version", "revision", "source", "license",
    "licenseSource", "notice", "noticeSource", "role", "distribution",
    "provenanceClass", "disposition", "bindings", "sourceAnchors",
}
ASSET_KEYS = {
    "path", "kind", "sha256", "licenseComponent", "origin", "role",
    "distribution", "disposition", "sourceAnchors",
}
LOCAL_KEYS = {
    "id", "pathPattern", "ignoreRule", "kinds", "role", "licensePolicy",
    "disposition",
}
FINDING_KEYS = {
    "id", "severity", "component", "summary", "disposition", "followUp",
}
COMPONENT_KINDS = {
    "project", "package-direct", "package-transitive", "platform-sdk",
    "toolchain-runtime", "ci-action", "build-tool", "redistributable-runtime",
}
PROVENANCE_CLASSES = {
    "GREEN-ORIGINAL", "GREEN-OPEN-SOURCE", "GREEN-SYSTEM",
    "YELLOW-CONDITIONAL",
}
DISTRIBUTIONS = {
    "repository-source", "test-only", "build-only", "platform-provided",
    "shipped-runtime", "local-only",
}
DISPOSITIONS = {
    "retain", "retain-test-only", "retain-platform-only",
    "retain-with-release-gate", "local-only-untracked", "remediate-at-0008",
}
SEVERITIES = {"green", "yellow", "red"}
INTERNAL_MODULES = {
    "AutoTechnoApp", "AutoTechnoCore", "AutoTechnoDSP", "AutoTechnoTransport",
    "AutoTechnoWindowsPlatform", "CAutoTechnoRealtime",
}
GOVERNED_EXTENSIONS = {
    ".wav", ".aif", ".aiff", ".mp3", ".flac", ".ogg", ".m4a", ".mid",
    ".midi", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".pdf", ".bin",
    ".model", ".mlmodel", ".onnx", ".ttf", ".otf", ".woff", ".woff2",
    ".icns", ".ico",
}
DISCOVERED_BINDING_PREFIXES = (
    "package:", "swift-import:", "linked-library:", "ci-action:",
)


class ComponentManifestError(RuntimeError):
    """An actionable component-manifest validation failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def manifest_path(root: Path) -> Path:
    return root / "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json"


def report_path(root: Path) -> Path:
    return root / "docs/COMPONENT_LICENSE_ASSET_MANIFEST.md"


def normalize_repo_path(value: object) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError("must be a non-empty string")
    if "\\" in value:
        raise ValueError("must use forward slashes")
    path = PurePosixPath(value)
    if path.is_absolute() or "." in path.parts or ".." in path.parts:
        raise ValueError("must be repository-relative without '.' or '..'")
    return path.as_posix()


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ComponentManifestError(f"component manifest is missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ComponentManifestError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ComponentManifestError("component manifest root must be an object")
    return value


def _nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _validate_string_list(value: object, location: str, errors: list[str]) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{location} must be an array")
        return []
    result: list[str] = []
    for index, member in enumerate(value):
        if not _nonempty(member):
            errors.append(f"{location}[{index}] must be a non-empty string")
        else:
            result.append(member)
    if result != sorted(set(result)):
        errors.append(f"{location} must be unique and sorted")
    return result


def _validate_exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    unknown = sorted(set(value) - expected)
    missing = sorted(expected - set(value))
    if unknown:
        errors.append(f"{location} has unknown fields: {', '.join(unknown)}")
    if missing:
        errors.append(f"{location} is missing fields: {', '.join(missing)}")


def validate_manifest(manifest: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    _validate_exact_keys(manifest, ROOT_KEYS, "manifest", errors)
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    version = manifest.get("manifestVersion")
    if isinstance(version, bool) or not isinstance(version, int) or version < 1:
        errors.append("manifestVersion must be a positive integer")
    access_date = manifest.get("accessDate")
    if not isinstance(access_date, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", access_date):
        errors.append("accessDate must use YYYY-MM-DD")
    if not _nonempty(manifest.get("scopePolicy")):
        errors.append("scopePolicy must be a non-empty string")

    components = manifest.get("components")
    component_ids: list[str] = []
    component_map: dict[str, Mapping[str, Any]] = {}
    if not isinstance(components, list):
        errors.append("components must be an array")
        components = []
    for index, component in enumerate(components):
        location = f"components[{index}]"
        if not isinstance(component, dict):
            errors.append(f"{location} must be an object")
            continue
        _validate_exact_keys(component, COMPONENT_KEYS, location, errors)
        identifier = component.get("id")
        if not _nonempty(identifier):
            errors.append(f"{location}.id must be a non-empty string")
        else:
            component_ids.append(identifier)
            component_map[identifier] = component
        for key in COMPONENT_KEYS - {"bindings", "sourceAnchors"}:
            if not _nonempty(component.get(key)):
                errors.append(f"{location}.{key} must be a non-empty string")
        if component.get("kind") not in COMPONENT_KINDS:
            errors.append(f"{location}.kind is unsupported")
        if component.get("provenanceClass") not in PROVENANCE_CLASSES:
            errors.append(f"{location}.provenanceClass is unsupported")
        if component.get("distribution") not in DISTRIBUTIONS:
            errors.append(f"{location}.distribution is unsupported")
        if component.get("disposition") not in DISPOSITIONS:
            errors.append(f"{location}.disposition is unsupported")
        _validate_string_list(component.get("bindings"), f"{location}.bindings", errors)
        anchors = _validate_string_list(
            component.get("sourceAnchors"), f"{location}.sourceAnchors", errors
        )
        for anchor in anchors:
            try:
                normalize_repo_path(anchor)
            except ValueError as exc:
                errors.append(f"{location}.sourceAnchors {anchor!r} {exc}")
    if component_ids != sorted(component_ids) or len(component_ids) != len(set(component_ids)):
        errors.append("components must have unique ids in ascending order")

    assets = manifest.get("assets")
    asset_paths: list[str] = []
    if not isinstance(assets, list):
        errors.append("assets must be an array")
        assets = []
    for index, asset in enumerate(assets):
        location = f"assets[{index}]"
        if not isinstance(asset, dict):
            errors.append(f"{location} must be an object")
            continue
        _validate_exact_keys(asset, ASSET_KEYS, location, errors)
        for key in ASSET_KEYS - {"sourceAnchors"}:
            if not _nonempty(asset.get(key)):
                errors.append(f"{location}.{key} must be a non-empty string")
        try:
            path = normalize_repo_path(asset.get("path"))
            asset_paths.append(path)
        except ValueError as exc:
            errors.append(f"{location}.path {exc}")
        digest = asset.get("sha256")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            errors.append(f"{location}.sha256 must be 64 lowercase hexadecimal digits")
        if asset.get("licenseComponent") not in component_map:
            errors.append(f"{location}.licenseComponent must name a component id")
        if asset.get("distribution") not in DISTRIBUTIONS:
            errors.append(f"{location}.distribution is unsupported")
        if asset.get("disposition") not in DISPOSITIONS:
            errors.append(f"{location}.disposition is unsupported")
        _validate_string_list(asset.get("sourceAnchors"), f"{location}.sourceAnchors", errors)
    if asset_paths != sorted(asset_paths) or len(asset_paths) != len(set(asset_paths)):
        errors.append("assets must have unique paths in ascending order")

    local_classes = manifest.get("localArtifactClasses")
    local_ids: list[str] = []
    if not isinstance(local_classes, list):
        errors.append("localArtifactClasses must be an array")
        local_classes = []
    for index, artifact_class in enumerate(local_classes):
        location = f"localArtifactClasses[{index}]"
        if not isinstance(artifact_class, dict):
            errors.append(f"{location} must be an object")
            continue
        _validate_exact_keys(artifact_class, LOCAL_KEYS, location, errors)
        for key in LOCAL_KEYS - {"kinds"}:
            if not _nonempty(artifact_class.get(key)):
                errors.append(f"{location}.{key} must be a non-empty string")
        identifier = artifact_class.get("id")
        if _nonempty(identifier):
            local_ids.append(identifier)
        _validate_string_list(artifact_class.get("kinds"), f"{location}.kinds", errors)
        if artifact_class.get("disposition") != "local-only-untracked":
            errors.append(f"{location}.disposition must be local-only-untracked")
    if local_ids != sorted(local_ids) or len(local_ids) != len(set(local_ids)):
        errors.append("localArtifactClasses must have unique ids in ascending order")

    findings = manifest.get("reviewFindings")
    finding_ids: list[str] = []
    if not isinstance(findings, list):
        errors.append("reviewFindings must be an array")
        findings = []
    for index, finding in enumerate(findings):
        location = f"reviewFindings[{index}]"
        if not isinstance(finding, dict):
            errors.append(f"{location} must be an object")
            continue
        _validate_exact_keys(finding, FINDING_KEYS, location, errors)
        for key in FINDING_KEYS:
            if not _nonempty(finding.get(key)):
                errors.append(f"{location}.{key} must be a non-empty string")
        identifier = finding.get("id")
        if _nonempty(identifier):
            finding_ids.append(identifier)
        if finding.get("severity") not in SEVERITIES:
            errors.append(f"{location}.severity is unsupported")
        if finding.get("component") not in component_map:
            errors.append(f"{location}.component must name a component id")
    if finding_ids != sorted(finding_ids) or len(finding_ids) != len(set(finding_ids)):
        errors.append("reviewFindings must have unique ids in ascending order")
    return errors


def _identity(location: str) -> str:
    return location.rstrip("/").rsplit("/", 1)[-1].removesuffix(".git").lower()


def package_pins(root: Path) -> dict[str, dict[str, str]]:
    try:
        resolved = json.loads((root / "Package.resolved").read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        raise ComponentManifestError(f"cannot read Package.resolved: {exc}") from exc
    pins: dict[str, dict[str, str]] = {}
    for pin in resolved.get("pins", []):
        if not isinstance(pin, dict) or not isinstance(pin.get("state"), dict):
            raise ComponentManifestError("Package.resolved contains an invalid pin")
        identity = str(pin.get("identity", "")).lower()
        state = pin["state"]
        pins[identity] = {
            "source": str(pin.get("location", "")),
            "version": str(state.get("version", "")),
            "revision": str(state.get("revision", "")),
        }
    return pins


def direct_packages(root: Path) -> dict[str, dict[str, str]]:
    contents = (root / "Package.swift").read_text(encoding="utf-8")
    result: dict[str, dict[str, str]] = {}
    pattern = re.compile(
        r'\.package\(\s*url:\s*"([^"]+)"\s*,\s*exact:\s*"([^"]+)"\s*\)'
    )
    for source, version in pattern.findall(contents):
        result[_identity(source)] = {"source": source, "version": version}
    return result


def discovered_bindings(root: Path) -> set[str]:
    bindings: set[str] = set()
    for source in sorted((root / "Sources").rglob("*.swift")):
        for module in re.findall(r"(?m)^import\s+([A-Za-z_][A-Za-z0-9_]*)", source.read_text(encoding="utf-8")):
            if module not in INTERNAL_MODULES:
                bindings.add(f"swift-import:{module}")
    package_contents = (root / "Package.swift").read_text(encoding="utf-8")
    for library in re.findall(r'\.linkedLibrary\("([^"]+)"', package_contents):
        bindings.add(f"linked-library:{library}")
    for identity in package_pins(root):
        bindings.add(f"package:{identity}")
    workflow_root = root / ".github/workflows"
    if workflow_root.exists():
        for workflow in sorted(workflow_root.glob("*.yml")):
            for action in re.findall(r"(?m)^\s*-?\s*uses:\s*([^\s#]+)", workflow.read_text(encoding="utf-8")):
                bindings.add(f"ci-action:{action}")
    return bindings


def tracked_paths(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, check=False,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise ComponentManifestError(
            "git ls-files failed: " + result.stderr.decode("utf-8", errors="replace")
        )
    return sorted(
        item.decode("utf-8") for item in result.stdout.split(b"\0") if item
    )


def is_governed_asset(path: str) -> bool:
    pure = PurePosixPath(path)
    name = pure.name.upper()
    return (
        (len(pure.parts) >= 3 and pure.parts[0] == "Sources" and "Resources" in pure.parts)
        or name == "LICENSE" or name.startswith("LICENSE.")
        or name == "NOTICE" or name.startswith("NOTICE.")
        or name == "COPYING" or name.startswith("COPYING.")
        or pure.suffix.lower() in GOVERNED_EXTENSIONS
    )


def forbidden_local_artifact(path: str) -> bool:
    if path.startswith("docs/local/") or path.startswith("docs/reference/video-evidence/"):
        return True
    return path.startswith("docs/reference/") and PurePosixPath(path).suffix.lower() in {
        ".wav", ".aif", ".aiff", ".mp3", ".flac", ".ogg", ".m4a",
        ".mid", ".midi",
    }


def compare_to_repository(
    manifest: Mapping[str, Any], root: Path, known_tracked_paths: Optional[Sequence[str]] = None
) -> list[str]:
    errors: list[str] = []
    components = {
        component["id"]: component
        for component in manifest.get("components", [])
        if isinstance(component, dict) and isinstance(component.get("id"), str)
    }
    pins = package_pins(root)
    direct = direct_packages(root)
    package_components = {
        binding.removeprefix("package:"): component
        for component in components.values()
        for binding in component.get("bindings", [])
        if isinstance(binding, str) and binding.startswith("package:")
    }
    if set(package_components) != set(pins):
        errors.append(
            "package component coverage mismatch: expected "
            f"{sorted(pins)}, found {sorted(package_components)}"
        )
    for identity, pin in pins.items():
        component = package_components.get(identity)
        if component is None:
            continue
        for field in ("source", "version", "revision"):
            if component.get(field) != pin[field]:
                errors.append(
                    f"package:{identity} {field} mismatch: expected {pin[field]!r}, "
                    f"found {component.get(field)!r}"
                )
        expected_kind = "package-direct" if identity in direct else "package-transitive"
        if component.get("kind") != expected_kind:
            errors.append(f"package:{identity} kind must be {expected_kind}")
        if identity in direct:
            if direct[identity] != {"source": pin["source"], "version": pin["version"]}:
                errors.append(f"Package.swift and Package.resolved disagree for {identity}")

    declared_bindings = {
        binding
        for component in components.values()
        for binding in component.get("bindings", [])
        if isinstance(binding, str) and binding.startswith(DISCOVERED_BINDING_PREFIXES)
    }
    discovered = discovered_bindings(root)
    if declared_bindings != discovered:
        missing = sorted(discovered - declared_bindings)
        stale = sorted(declared_bindings - discovered)
        if missing:
            errors.append(f"undeclared dependency bindings: {', '.join(missing)}")
        if stale:
            errors.append(f"stale dependency bindings: {', '.join(stale)}")
    for binding in sorted(discovered):
        if not binding.startswith("ci-action:"):
            continue
        selector = binding.rsplit("@", 1)[-1]
        if not re.fullmatch(r"[0-9a-f]{40}", selector):
            errors.append(f"CI action must use an exact 40-digit revision: {binding}")
            continue
        owners = [
            component for component in components.values()
            if binding in component.get("bindings", [])
        ]
        if len(owners) == 1 and owners[0].get("revision") != selector:
            errors.append(
                f"CI action {binding} revision record must equal its workflow pin"
            )

    tracked = list(known_tracked_paths) if known_tracked_paths is not None else tracked_paths(root)
    forbidden = sorted(path for path in tracked if forbidden_local_artifact(path))
    if forbidden:
        errors.append(f"forbidden local artifacts are tracked: {', '.join(forbidden)}")
    governed = sorted(path for path in tracked if is_governed_asset(path))
    declared_assets = {
        asset.get("path"): asset
        for asset in manifest.get("assets", []) if isinstance(asset, dict)
    }
    if set(governed) != set(declared_assets):
        missing = sorted(set(governed) - set(declared_assets))
        stale = sorted(set(declared_assets) - set(governed))
        if missing:
            errors.append(f"undeclared governed assets: {', '.join(missing)}")
        if stale:
            errors.append(f"stale governed assets: {', '.join(stale)}")
    for path in governed:
        asset = declared_assets.get(path)
        if asset is None:
            continue
        destination = root / path
        if not destination.is_file():
            errors.append(f"governed asset is missing: {path}")
            continue
        actual = hashlib.sha256(destination.read_bytes()).hexdigest()
        if asset.get("sha256") != actual:
            errors.append(
                f"governed asset hash mismatch: {path} "
                f"(expected {asset.get('sha256')}, actual {actual})"
            )
    for component in components.values():
        for anchor in component.get("sourceAnchors", []):
            if isinstance(anchor, str) and not (root / anchor).is_file():
                errors.append(f"component {component['id']} source anchor is missing: {anchor}")
    for asset in declared_assets.values():
        for anchor in asset.get("sourceAnchors", []):
            if isinstance(anchor, str) and not (root / anchor).is_file():
                errors.append(f"asset {asset.get('path')} source anchor is missing: {anchor}")
    ignore_lines = {
        line.strip() for line in (root / ".gitignore").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    for artifact_class in manifest.get("localArtifactClasses", []):
        if isinstance(artifact_class, dict) and artifact_class.get("ignoreRule") not in ignore_lines:
            errors.append(
                f"local artifact class {artifact_class.get('id')} ignore rule is missing: "
                f"{artifact_class.get('ignoreRule')}"
            )
    return errors


def render_report(manifest: Mapping[str, Any]) -> str:
    lines = [
        "# Component Licence and Asset Manifest", "",
        "> Generated from `docs/COMPONENT_LICENSE_ASSET_MANIFEST.json`; do not edit by hand.", "",
        f"Schema: `{manifest['schema']}`  ",
        f"Manifest version: {manifest['manifestVersion']}  ",
        f"Source access date: {manifest['accessDate']}  ", "",
        "## Scope", "", str(manifest["scopePolicy"]), "",
        "## Components", "",
        "| Component | Kind | Version / revision | Licence and notice | Role / distribution | Provenance / disposition |",
        "|---|---|---|---|---|---|",
    ]
    for component in manifest["components"]:
        notice = component["notice"]
        lines.append(
            f"| `{component['id']}` — {component['name']} | `{component['kind']}` | "
            f"`{component['version']}` / `{component['revision']}` | "
            f"{component['license']}; {notice} | {component['role']} / "
            f"`{component['distribution']}` | `{component['provenanceClass']}` / "
            f"`{component['disposition']}` |"
        )
    lines.extend(["", "## Tracked governed assets", "", "| Path | Kind | Origin | Distribution / disposition | SHA-256 |", "|---|---|---|---|---|"])
    for asset in manifest["assets"]:
        lines.append(
            f"| `{asset['path']}` | {asset['kind']} | {asset['origin']} | "
            f"`{asset['distribution']}` / `{asset['disposition']}` | `{asset['sha256']}` |"
        )
    lines.extend(["", "## Local-only artifact classes", "", "| Class | Path pattern | Kinds | Policy / disposition |", "|---|---|---|---|"])
    for artifact_class in manifest["localArtifactClasses"]:
        lines.append(
            f"| `{artifact_class['id']}` | `{artifact_class['pathPattern']}` | "
            f"{', '.join(artifact_class['kinds'])} | {artifact_class['licensePolicy']} / "
            f"`{artifact_class['disposition']}` |"
        )
    lines.extend(["", "## Review findings", "", "| Severity | Finding | Component | Disposition / follow-up |", "|---|---|---|---|"])
    for finding in manifest["reviewFindings"]:
        lines.append(
            f"| `{finding['severity']}` | `{finding['id']}` — {finding['summary']} | "
            f"`{finding['component']}` | {finding['disposition']} / {finding['followUp']} |"
        )
    lines.extend(["", "## Source records", ""])
    for component in manifest["components"]:
        lines.extend([
            f"### {component['name']}", "",
            f"- Source: {component['source']}",
            f"- Licence: {component['licenseSource']}",
            f"- Notice: {component['noticeSource']}",
            f"- Repository anchors: {', '.join(f'`{path}`' for path in component['sourceAnchors'])}",
            f"- Bindings: {', '.join(f'`{binding}`' for binding in component['bindings']) or 'none'}",
            "",
        ])
    return "\n".join(lines).rstrip() + "\n"


def write_atomic(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=path.name + ".", suffix=".tmp", dir=path.parent, text=True
    )
    try:
        with open(descriptor, "w", encoding="utf-8") as handle:
            handle.write(contents)
        Path(temporary_name).replace(path)
    except BaseException:
        Path(temporary_name).unlink(missing_ok=True)
        raise


def run_render(root: Path, output: Any) -> int:
    manifest = load_manifest(manifest_path(root))
    errors = validate_manifest(manifest) + compare_to_repository(manifest, root)
    if errors:
        for error in errors:
            print(f"component manifest error: {error}", file=output)
        return 1
    write_atomic(report_path(root), render_report(manifest))
    print(
        f"rendered component manifest v{manifest['manifestVersion']}: "
        f"{len(manifest['components'])} components, {len(manifest['assets'])} assets, "
        f"{len(manifest['reviewFindings'])} findings",
        file=output,
    )
    return 0


def run_check(root: Path, output: Any) -> int:
    manifest = load_manifest(manifest_path(root))
    errors = validate_manifest(manifest) + compare_to_repository(manifest, root)
    expected_report = render_report(manifest) if not validate_manifest(manifest) else None
    if expected_report is not None:
        try:
            actual_report = report_path(root).read_text(encoding="utf-8")
        except FileNotFoundError:
            errors.append("generated component manifest Markdown is missing; run render")
        else:
            if actual_report != expected_report:
                errors.append("generated component manifest Markdown is stale; run render")
    if errors:
        for error in errors:
            print(f"component manifest error: {error}", file=output)
        return 1
    print(
        f"component manifest is current: v{manifest['manifestVersion']}, "
        f"{len(manifest['components'])} components, {len(manifest['assets'])} assets, "
        f"{len(manifest['reviewFindings'])} findings",
        file=output,
    )
    return 0


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("render", "check"))
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    root = repository_root()
    return run_render(root, sys.stdout) if args.command == "render" else run_check(root, sys.stdout)


if __name__ == "__main__":
    raise SystemExit(main())
