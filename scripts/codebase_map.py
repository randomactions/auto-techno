#!/usr/bin/env python3
"""Generate and validate Auto Techno's semantic codebase map.

The curated JSON manifest is the only hand-edited map artifact. This tool joins
that semantic ownership data with SwiftPM's package description and normalized
compiler/source symbol indexes, then renders the checked-in Markdown map.
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple
from urllib.parse import unquote, urlparse


SCHEMA_VERSION = 1
ROOT_KEYS = {"schemaVersion", "modulePolicies", "components", "flows", "boundaries"}
MODULE_KEYS = {"target", "responsibility", "allowedInternalDependencies"}
COMPONENT_KEYS = {
    "id",
    "name",
    "responsibility",
    "targets",
    "ownerAnchors",
    "state",
    "inputs",
    "outputs",
    "evidence",
    "sourcePaths",
    "testPaths",
    "contracts",
    "dependsOn",
    "boundaries",
}
ANCHOR_KEYS = {"symbol", "path"}
FLOW_KEYS = {"id", "name", "summary", "steps", "contracts"}
FLOW_STEP_KEYS = {"component", "artifact"}
BOUNDARY_KEYS = {
    "id",
    "name",
    "ownerComponent",
    "executionContext",
    "allowedWork",
    "forbiddenWork",
    "failureBehavior",
    "tests",
}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]*$")
SWIFT_DECLARATION = re.compile(
    r"^(?:(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^\n]*\))?)\s+)*"
    r"(?:(?:package|public|internal|private|fileprivate|open|final|indirect|"
    r"nonisolated|distributed)\s+)*"
    r"(actor|class|struct|enum|protocol|typealias|func)\s+"
    r"(`?[A-Za-z_][A-Za-z0-9_]*`?)",
    re.MULTILINE,
)
C_TYPE_DECLARATION = re.compile(
    r"^(?:typedef\s+)?(struct|enum)\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)
C_FUNCTION_DECLARATION = re.compile(
    r"^(?:(?:static|inline|extern)\s+)*"
    r"(?:[A-Za-z_][A-Za-z0-9_]*[\s\*]+)+"
    r"(?:CALLBACK\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.MULTILINE,
)
SWIFT_KIND_NAMES = {
    "actor": "Actor",
    "class": "Class",
    "struct": "Structure",
    "enum": "Enumeration",
    "protocol": "Protocol",
    "typealias": "Type Alias",
    "func": "Function",
}


class CodebaseMapError(RuntimeError):
    """An actionable map generation or validation failure."""


@dataclass(frozen=True, order=True)
class StableSymbol:
    path: str
    name: str
    kind: str


@dataclass(frozen=True)
class PackageTarget:
    name: str
    path: str
    dependencies: Tuple[str, ...]
    kind: str


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def normalize_repo_path(value: str) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError("path must be a non-empty string")
    if "\\" in value:
        raise ValueError("path must use forward slashes")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        raise ValueError("path must be repository-relative without '.' or '..'")
    normalized = path.as_posix()
    if normalized == "." or normalized.startswith(".build/") or "/.build/" in normalized:
        raise ValueError("path must not refer to generated build output")
    return normalized


def relative_to_root(path: Path, root: Path) -> Optional[str]:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return None


def load_manifest(path: Path) -> Dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise CodebaseMapError(f"missing semantic manifest: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CodebaseMapError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise CodebaseMapError("semantic manifest root must be a JSON object")
    return value


def run_swift_command(root: Path, args: Sequence[str]) -> str:
    command = ["swift", "package", "--disable-sandbox", *args]
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        raise CodebaseMapError(f"unable to run {' '.join(command)}: {exc}") from exc
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no diagnostic output"
        raise CodebaseMapError(
            "Swift package inspection failed. Use a matching Xcode compiler and SDK "
            "(for example, set DEVELOPER_DIR to the full Xcode developer directory), "
            "then retry.\n"
            f"command: {' '.join(command)}\n{detail}"
        )
    return result.stdout


def package_arguments(build_path: Optional[Path]) -> List[str]:
    if build_path is None:
        return []
    return ["--build-path", str(build_path.resolve())]


def ensure_test_modules_are_built(root: Path, build_path: Optional[Path]) -> None:
    """Build test modules so SwiftPM can extract its synthetic package-test graph."""
    command = [
        "swift",
        "build",
        "--disable-sandbox",
        *package_arguments(build_path),
        "--build-tests",
    ]
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        raise CodebaseMapError(f"unable to run {' '.join(command)}: {exc}") from exc
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no diagnostic output"
        raise CodebaseMapError(
            "Swift test-module preparation failed. Use a matching Xcode compiler and SDK "
            "(for example, set DEVELOPER_DIR to the full Xcode developer directory), "
            "then retry.\n"
            f"command: {' '.join(command)}\n{detail}"
        )


def inspect_package(root: Path, build_path: Optional[Path]) -> Dict[str, PackageTarget]:
    output = run_swift_command(
        root,
        [*package_arguments(build_path), "describe", "--type", "json"],
    )
    try:
        description = json.loads(output)
    except json.JSONDecodeError as exc:
        raise CodebaseMapError(f"swift package describe returned invalid JSON: {exc}") from exc
    raw_targets = description.get("targets")
    if not isinstance(raw_targets, list):
        raise CodebaseMapError("swift package describe omitted its targets array")
    names = {
        item.get("name")
        for item in raw_targets
        if isinstance(item, dict) and isinstance(item.get("name"), str)
    }
    targets: Dict[str, PackageTarget] = {}
    for item in raw_targets:
        if not isinstance(item, dict) or not isinstance(item.get("name"), str):
            continue
        name = item["name"]
        raw_path = item.get("path")
        if not isinstance(raw_path, str):
            raise CodebaseMapError(f"SwiftPM target {name} has no source path")
        candidate = Path(raw_path)
        if candidate.is_absolute():
            path = relative_to_root(candidate, root)
            if path is None:
                raise CodebaseMapError(f"SwiftPM target {name} is outside the repository: {raw_path}")
        else:
            path = normalize_repo_path(raw_path)
        dependencies = tuple(
            sorted(
                dependency
                for dependency in item.get("target_dependencies", [])
                if isinstance(dependency, str) and dependency in names
            )
        )
        targets[name] = PackageTarget(
            name=name,
            path=path,
            dependencies=dependencies,
            kind=str(item.get("type", "unknown")),
        )
    if not targets:
        raise CodebaseMapError("SwiftPM package inspection found no targets")
    return targets


def discover_repository_files(root: Path, directory: str) -> List[str]:
    base = root / directory
    if not base.is_dir():
        return []
    return sorted(
        path.relative_to(root).as_posix()
        for path in base.rglob("*")
        if path.is_file()
    )


def lexical_symbols(root: Path, paths: Iterable[str]) -> Set[StableSymbol]:
    symbols: Set[StableSymbol] = set()
    for path in sorted(set(paths)):
        file_path = root / path
        if not file_path.is_file() or file_path.suffix.lower() not in {".swift", ".c", ".h"}:
            continue
        contents = file_path.read_text(encoding="utf-8")
        if file_path.suffix.lower() == ".swift":
            for match in SWIFT_DECLARATION.finditer(contents):
                kind, name = match.groups()
                symbols.add(StableSymbol(path, name.strip("`"), SWIFT_KIND_NAMES[kind]))
        else:
            for match in C_TYPE_DECLARATION.finditer(contents):
                kind, name = match.groups()
                symbols.add(
                    StableSymbol(path, name, "Structure" if kind == "struct" else "Enumeration")
                )
            for match in C_FUNCTION_DECLARATION.finditer(contents):
                symbols.add(StableSymbol(path, match.group(1), "Function"))
    return symbols


def symbol_graph_directory(output: str, root: Path, build_path: Optional[Path]) -> Path:
    matches = re.findall(r"^Files written to (.+)$", output, flags=re.MULTILINE)
    if matches:
        candidate = Path(matches[-1].strip())
        return candidate if candidate.is_absolute() else root / candidate
    search_root = build_path.resolve() if build_path is not None else root / ".build"
    candidates = sorted(
        directory
        for directory in search_root.rglob("symbolgraph")
        if directory.is_dir() and any(directory.glob("*.symbols.json"))
    )
    if not candidates:
        raise CodebaseMapError("swift package dump-symbol-graph reported no symbol graph directory")
    return candidates[-1]


def inspect_symbols(
    root: Path,
    build_path: Optional[Path],
    targets: Mapping[str, PackageTarget],
    tracked_paths: Iterable[str],
) -> Set[StableSymbol]:
    ensure_test_modules_are_built(root, build_path)
    output = run_swift_command(
        root,
        [
            *package_arguments(build_path),
            "dump-symbol-graph",
            "--minimum-access-level",
            "internal",
            "--skip-synthesized-members",
        ],
    )
    graph_directory = symbol_graph_directory(output, root, build_path)
    symbols = lexical_symbols(root, tracked_paths)
    target_names = set(targets)
    for graph_path in sorted(graph_directory.glob("*.symbols.json")):
        try:
            graph = json.loads(graph_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise CodebaseMapError(f"invalid symbol graph {graph_path}: {exc}") from exc
        module = graph.get("module", {}).get("name")
        if module not in target_names:
            continue
        for raw_symbol in graph.get("symbols", []):
            if not isinstance(raw_symbol, dict):
                continue
            components = raw_symbol.get("pathComponents")
            if not isinstance(components, list) or len(components) != 1:
                continue
            location = raw_symbol.get("location")
            uri = location.get("uri") if isinstance(location, dict) else None
            if not isinstance(uri, str):
                continue
            parsed = urlparse(uri)
            if parsed.scheme != "file":
                continue
            relative_path = relative_to_root(Path(unquote(parsed.path)), root)
            if relative_path is None:
                continue
            title = raw_symbol.get("names", {}).get("title")
            kind = raw_symbol.get("kind", {}).get("displayName")
            if isinstance(title, str) and isinstance(kind, str):
                symbols.add(StableSymbol(relative_path, title, kind))
    return symbols


def target_for_path(path: str, targets: Mapping[str, PackageTarget]) -> Optional[str]:
    matches = [
        target.name
        for target in targets.values()
        if path == target.path or path.startswith(target.path.rstrip("/") + "/")
    ]
    if not matches:
        return None
    return max(matches, key=lambda name: len(targets[name].path))


def validate_keys(value: Mapping[str, Any], allowed: Set[str], location: str, errors: List[str]) -> None:
    unknown = sorted(set(value) - allowed)
    missing = sorted(allowed - set(value))
    if unknown:
        errors.append(f"{location} has unknown fields: {', '.join(unknown)}")
    if missing:
        errors.append(f"{location} is missing fields: {', '.join(missing)}")


def validate_string_list(value: Any, location: str, errors: List[str]) -> List[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
        errors.append(f"{location} must be an array of non-empty strings")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{location} contains duplicate values")
    return list(value)


def validate_id(value: Any, location: str, errors: List[str]) -> Optional[str]:
    if not isinstance(value, str) or not ID_PATTERN.fullmatch(value):
        errors.append(f"{location} must match {ID_PATTERN.pattern}")
        return None
    return value


def validate_manifest(
    manifest: Mapping[str, Any],
    root: Path,
    targets: Mapping[str, PackageTarget],
    symbols: Set[StableSymbol],
    *,
    check_guardrail_documents: bool = True,
) -> List[str]:
    errors: List[str] = []
    validate_keys(manifest, ROOT_KEYS, "manifest", errors)
    if manifest.get("schemaVersion") != SCHEMA_VERSION:
        errors.append(
            f"manifest.schemaVersion must be {SCHEMA_VERSION}, got {manifest.get('schemaVersion')!r}"
        )

    raw_modules = manifest.get("modulePolicies")
    if not isinstance(raw_modules, list):
        errors.append("manifest.modulePolicies must be an array")
        raw_modules = []
    module_policies: Dict[str, Mapping[str, Any]] = {}
    for index, raw_module in enumerate(raw_modules):
        location = f"modulePolicies[{index}]"
        if not isinstance(raw_module, dict):
            errors.append(f"{location} must be an object")
            continue
        validate_keys(raw_module, MODULE_KEYS, location, errors)
        target = raw_module.get("target")
        if not isinstance(target, str) or not target:
            errors.append(f"{location}.target must be a non-empty string")
            continue
        if target in module_policies:
            errors.append(f"duplicate module policy for {target}")
        module_policies[target] = raw_module
        if not isinstance(raw_module.get("responsibility"), str) or not raw_module.get("responsibility"):
            errors.append(f"{location}.responsibility must be a non-empty string")
        validate_string_list(
            raw_module.get("allowedInternalDependencies"),
            f"{location}.allowedInternalDependencies",
            errors,
        )

    for target_name, target in targets.items():
        policy = module_policies.get(target_name)
        if policy is None:
            errors.append(f"SwiftPM target {target_name} has no module policy")
            continue
        allowed = policy.get("allowedInternalDependencies")
        if isinstance(allowed, list):
            allowed_set = {item for item in allowed if isinstance(item, str)}
            if allowed_set != set(target.dependencies):
                errors.append(
                    f"module policy for {target_name} has dependencies {sorted(allowed_set)}, "
                    f"but SwiftPM declares {list(target.dependencies)}"
                )
    for target_name in sorted(set(module_policies) - set(targets)):
        errors.append(f"module policy {target_name} does not resolve to a SwiftPM target")

    raw_components = manifest.get("components")
    if not isinstance(raw_components, list):
        errors.append("manifest.components must be an array")
        raw_components = []
    components: Dict[str, Mapping[str, Any]] = {}
    source_owners: Dict[str, List[str]] = {}
    test_owners: Dict[str, List[str]] = {}
    for index, raw_component in enumerate(raw_components):
        location = f"components[{index}]"
        if not isinstance(raw_component, dict):
            errors.append(f"{location} must be an object")
            continue
        validate_keys(raw_component, COMPONENT_KEYS, location, errors)
        component_id = validate_id(raw_component.get("id"), f"{location}.id", errors)
        if component_id is None:
            component_id = f"invalid-component-{index}"
        elif component_id in components:
            errors.append(f"duplicate component id {component_id}")
        components[component_id] = raw_component
        for field in ["name", "responsibility"]:
            if not isinstance(raw_component.get(field), str) or not raw_component.get(field):
                errors.append(f"{location}.{field} must be a non-empty string")
        component_targets = validate_string_list(
            raw_component.get("targets"), f"{location}.targets", errors
        )
        if not component_targets:
            errors.append(f"{location}.targets must contain at least one SwiftPM target")
        for component_target in component_targets:
            if component_target not in targets:
                errors.append(
                    f"{location}.targets entry {component_target} does not resolve to a SwiftPM target"
                )
        for field in [
            "state",
            "inputs",
            "outputs",
            "evidence",
            "sourcePaths",
            "testPaths",
            "contracts",
            "dependsOn",
            "boundaries",
        ]:
            validate_string_list(raw_component.get(field), f"{location}.{field}", errors)

        source_paths = raw_component.get("sourcePaths")
        if isinstance(source_paths, list):
            for raw_path in source_paths:
                if not isinstance(raw_path, str):
                    continue
                try:
                    path = normalize_repo_path(raw_path)
                except ValueError as exc:
                    errors.append(f"{location}.sourcePaths contains invalid path {raw_path!r}: {exc}")
                    continue
                source_owners.setdefault(path, []).append(component_id)
                if not path.startswith("Sources/"):
                    errors.append(f"{location}.sourcePaths entry is outside Sources/: {path}")
                if not (root / path).is_file():
                    errors.append(f"{location}.sourcePaths entry does not exist: {path}")
                actual_target = target_for_path(path, targets)
                if actual_target not in component_targets:
                    errors.append(
                        f"{location} assigns {path} to {component_targets}, but SwiftPM owns it in {actual_target}"
                    )

        test_paths = raw_component.get("testPaths")
        if isinstance(test_paths, list):
            for raw_path in test_paths:
                if not isinstance(raw_path, str):
                    continue
                try:
                    path = normalize_repo_path(raw_path)
                except ValueError as exc:
                    errors.append(f"{location}.testPaths contains invalid path {raw_path!r}: {exc}")
                    continue
                test_owners.setdefault(path, []).append(component_id)
                if not path.startswith("Tests/"):
                    errors.append(f"{location}.testPaths entry is outside Tests/: {path}")
                if not (root / path).is_file():
                    errors.append(f"{location}.testPaths entry does not exist: {path}")

        contracts = raw_component.get("contracts")
        if isinstance(contracts, list):
            for raw_path in contracts:
                if not isinstance(raw_path, str):
                    continue
                try:
                    path = normalize_repo_path(raw_path)
                except ValueError as exc:
                    errors.append(f"{location}.contracts contains invalid path {raw_path!r}: {exc}")
                    continue
                if not (path.startswith("docs/") or path == "README.md"):
                    errors.append(f"{location}.contracts entry is not an active contract path: {path}")
                if not (root / path).is_file():
                    errors.append(f"{location}.contracts entry does not exist: {path}")

        raw_anchors = raw_component.get("ownerAnchors")
        if not isinstance(raw_anchors, list) or not raw_anchors:
            errors.append(f"{location}.ownerAnchors must be a non-empty array")
        else:
            for anchor_index, raw_anchor in enumerate(raw_anchors):
                anchor_location = f"{location}.ownerAnchors[{anchor_index}]"
                if not isinstance(raw_anchor, dict):
                    errors.append(f"{anchor_location} must be an object")
                    continue
                validate_keys(raw_anchor, ANCHOR_KEYS, anchor_location, errors)
                symbol = raw_anchor.get("symbol")
                raw_path = raw_anchor.get("path")
                if not isinstance(symbol, str) or not symbol:
                    errors.append(f"{anchor_location}.symbol must be a non-empty string")
                    continue
                if not isinstance(raw_path, str):
                    errors.append(f"{anchor_location}.path must be a non-empty string")
                    continue
                try:
                    path = normalize_repo_path(raw_path)
                except ValueError as exc:
                    errors.append(f"{anchor_location}.path is invalid: {exc}")
                    continue
                if isinstance(source_paths, list) and path not in source_paths:
                    errors.append(f"{anchor_location}.path must be one of the component sourcePaths")
                if not any(item.path == path and item.name == symbol for item in symbols):
                    errors.append(f"{anchor_location} does not resolve declaration {symbol} in {path}")

    production_files = discover_repository_files(root, "Sources")
    test_files = discover_repository_files(root, "Tests")
    for path in production_files:
        owners = source_owners.get(path, [])
        if not owners:
            errors.append(f"unmapped production file: {path}")
        elif len(owners) > 1:
            errors.append(f"production file has multiple primary owners {owners}: {path}")
    for path in sorted(set(source_owners) - set(production_files)):
        errors.append(f"manifest source path is not a tracked production file: {path}")
    for path in test_files:
        if not test_owners.get(path):
            errors.append(f"unmapped test file: {path}")
    for path in sorted(set(test_owners) - set(test_files)):
        errors.append(f"manifest test path is not a tracked test file: {path}")

    raw_boundaries = manifest.get("boundaries")
    if not isinstance(raw_boundaries, list):
        errors.append("manifest.boundaries must be an array")
        raw_boundaries = []
    boundaries: Dict[str, Mapping[str, Any]] = {}
    for index, raw_boundary in enumerate(raw_boundaries):
        location = f"boundaries[{index}]"
        if not isinstance(raw_boundary, dict):
            errors.append(f"{location} must be an object")
            continue
        validate_keys(raw_boundary, BOUNDARY_KEYS, location, errors)
        boundary_id = validate_id(raw_boundary.get("id"), f"{location}.id", errors)
        if boundary_id is None:
            continue
        if boundary_id in boundaries:
            errors.append(f"duplicate boundary id {boundary_id}")
        boundaries[boundary_id] = raw_boundary
        for field in [
            "name",
            "ownerComponent",
            "executionContext",
            "allowedWork",
            "forbiddenWork",
            "failureBehavior",
        ]:
            if not isinstance(raw_boundary.get(field), str) or not raw_boundary.get(field):
                errors.append(f"{location}.{field} must be a non-empty string")
        validate_string_list(raw_boundary.get("tests"), f"{location}.tests", errors)
        owner = raw_boundary.get("ownerComponent")
        if isinstance(owner, str) and owner not in components:
            errors.append(f"{location}.ownerComponent references unknown component {owner}")
        tests = raw_boundary.get("tests")
        if isinstance(tests, list):
            for raw_path in tests:
                if not isinstance(raw_path, str):
                    continue
                try:
                    path = normalize_repo_path(raw_path)
                except ValueError as exc:
                    errors.append(f"{location}.tests contains invalid path {raw_path!r}: {exc}")
                    continue
                if path not in test_files:
                    errors.append(f"{location}.tests references unknown test file {path}")

    for component_id, component in components.items():
        for dependency in component.get("dependsOn", []):
            if dependency not in components:
                errors.append(f"component {component_id} depends on unknown component {dependency}")
            elif dependency == component_id:
                errors.append(f"component {component_id} cannot depend on itself")
        for boundary in component.get("boundaries", []):
            if boundary not in boundaries:
                errors.append(f"component {component_id} references unknown boundary {boundary}")

    raw_flows = manifest.get("flows")
    if not isinstance(raw_flows, list):
        errors.append("manifest.flows must be an array")
        raw_flows = []
    flow_ids: Set[str] = set()
    for index, raw_flow in enumerate(raw_flows):
        location = f"flows[{index}]"
        if not isinstance(raw_flow, dict):
            errors.append(f"{location} must be an object")
            continue
        validate_keys(raw_flow, FLOW_KEYS, location, errors)
        flow_id = validate_id(raw_flow.get("id"), f"{location}.id", errors)
        if flow_id is not None:
            if flow_id in flow_ids:
                errors.append(f"duplicate flow id {flow_id}")
            flow_ids.add(flow_id)
        for field in ["name", "summary"]:
            if not isinstance(raw_flow.get(field), str) or not raw_flow.get(field):
                errors.append(f"{location}.{field} must be a non-empty string")
        validate_string_list(raw_flow.get("contracts"), f"{location}.contracts", errors)
        for raw_contract in raw_flow.get("contracts", []):
            if not isinstance(raw_contract, str):
                continue
            try:
                contract = normalize_repo_path(raw_contract)
            except ValueError as exc:
                errors.append(f"{location}.contracts contains invalid path {raw_contract!r}: {exc}")
                continue
            if not (contract.startswith("docs/") or contract == "README.md"):
                errors.append(f"{location}.contracts entry is not an active contract path: {contract}")
            if not (root / contract).is_file():
                errors.append(f"{location}.contracts references missing file {contract}")
        steps = raw_flow.get("steps")
        if not isinstance(steps, list) or len(steps) < 2:
            errors.append(f"{location}.steps must contain at least two steps")
            continue
        for step_index, raw_step in enumerate(steps):
            step_location = f"{location}.steps[{step_index}]"
            if not isinstance(raw_step, dict):
                errors.append(f"{step_location} must be an object")
                continue
            validate_keys(raw_step, FLOW_STEP_KEYS, step_location, errors)
            component = raw_step.get("component")
            artifact = raw_step.get("artifact")
            if component not in components:
                errors.append(f"{step_location}.component references unknown component {component}")
            if not isinstance(artifact, str) or not artifact:
                errors.append(f"{step_location}.artifact must be a non-empty string")

    if check_guardrail_documents:
        required_fragments = {
            "README.md": ["docs/CODEBASE_MAP.md"],
            "AGENTS.md": [
                "docs/CODEBASE_MAP.md",
                "scripts/codebase_map.py generate",
                "scripts/codebase_map.py check",
            ],
            "CONTRIBUTING.md": ["scripts/codebase_map.py check", "Semantic codebase map"],
            ".github/PULL_REQUEST_TEMPLATE.md": ["## Semantic map impact"],
        }
        for path, fragments in required_fragments.items():
            document = root / path
            if not document.is_file():
                errors.append(f"guardrail document is missing: {path}")
                continue
            contents = document.read_text(encoding="utf-8")
            for fragment in fragments:
                if fragment not in contents:
                    errors.append(f"guardrail document {path} omits {fragment!r}")
    return errors


def markdown_link(path: str) -> str:
    target = path[len("docs/") :] if path.startswith("docs/") else "../" + path
    return f"[`{path}`]({target})"


def markdown_list(values: Sequence[str]) -> str:
    return "<br>".join(f"`{value}`" for value in values) if values else "—"


def escape_table(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def mermaid_id(value: str) -> str:
    return "n_" + re.sub(r"[^A-Za-z0-9_]", "_", value)


def symbols_by_path(symbols: Iterable[StableSymbol]) -> Dict[str, List[StableSymbol]]:
    grouped: Dict[str, List[StableSymbol]] = {}
    for symbol in sorted(symbols, key=lambda item: (item.path, item.name, item.kind)):
        grouped.setdefault(symbol.path, []).append(symbol)
    return grouped


def render_markdown(
    manifest: Mapping[str, Any],
    targets: Mapping[str, PackageTarget],
    symbols: Iterable[StableSymbol],
) -> str:
    components = list(manifest["components"])
    component_by_id = {component["id"]: component for component in components}
    grouped_symbols = symbols_by_path(symbols)
    lines: List[str] = [
        "<!-- GENERATED by scripts/codebase_map.py; edit docs/codebase-map.json, not this file. -->",
        "# Semantic Codebase Map",
        "",
        "> This map describes the current implemented repository only. Future architecture remains in the roadmap and normative contracts. If this map conflicts with code, `Package.swift`, or a canonical contract, repair the manifest and regenerate the map in the same change.",
        "",
        "## Use and refresh",
        "",
        "Start with the component or flow matching the change, then follow its owner anchors, source files, contracts, boundaries, and tests.",
        "",
        "```bash",
        "python3 scripts/codebase_map.py generate",
        "python3 scripts/codebase_map.py check",
        "```",
        "",
        "The commands build test modules before SwiftPM symbol extraction and require a matching Swift compiler and SDK. Pass `--build-path` to reuse an existing test build. Generated output contains no timestamps, commit hashes, absolute paths, line numbers, or mangled symbol identifiers.",
        "",
        "## SwiftPM module graph",
        "",
        "```mermaid",
        "flowchart LR",
    ]
    for target_name in sorted(targets):
        target = targets[target_name]
        lines.append(f'  {mermaid_id(target_name)}["{target_name}"]')
    for target_name in sorted(targets):
        for dependency in targets[target_name].dependencies:
            lines.append(
                f"  {mermaid_id(dependency)} --> {mermaid_id(target_name)}"
            )
    lines.extend(["```", "", "| Target | Responsibility | Internal dependencies |", "| --- | --- | --- |"])
    policy_by_target = {
        policy["target"]: policy for policy in manifest["modulePolicies"]
    }
    for target_name in sorted(targets):
        policy = policy_by_target[target_name]
        lines.append(
            "| "
            + " | ".join(
                [
                    f"`{target_name}`",
                    escape_table(policy["responsibility"]),
                    markdown_list(list(targets[target_name].dependencies)),
                ]
            )
            + " |"
        )

    lines.extend(["", "## Canonical runtime flows", ""])
    for flow in manifest["flows"]:
        lines.extend([f"### {flow['name']}", "", flow["summary"], "", "```mermaid", "flowchart LR"])
        for index, step in enumerate(flow["steps"]):
            component = component_by_id[step["component"]]
            lines.append(
                f'  {mermaid_id(flow["id"] + str(index))}["{component["name"]}"]'
            )
        for index in range(len(flow["steps"]) - 1):
            artifact = flow["steps"][index]["artifact"].replace('"', "'")
            lines.append(
                f"  {mermaid_id(flow['id'] + str(index))} -- \"{artifact}\" --> "
                f"{mermaid_id(flow['id'] + str(index + 1))}"
            )
        lines.extend(["```", "", "Contracts: " + ", ".join(markdown_link(path) for path in flow["contracts"]), ""])

    lines.extend(
        [
            "## Component ownership index",
            "",
            "| Component | Targets | Canonical owner anchors | Responsibility |",
            "| --- | --- | --- | --- |",
        ]
    )
    for component in components:
        anchors = "<br>".join(
            f"`{anchor['symbol']}` in {markdown_link(anchor['path'])}"
            for anchor in component["ownerAnchors"]
        )
        lines.append(
            "| "
            + " | ".join(
                [
                    f"[`{component['id']}`](#{component['id']})",
                    markdown_list(component["targets"]),
                    anchors,
                    escape_table(component["responsibility"]),
                ]
            )
            + " |"
        )

    lines.extend(
        [
            "",
            "## Realtime and future-boundary guardrails",
            "",
            "| Boundary | Owner | Execution context | Allowed work | Forbidden work | Failure behavior |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
    )
    for boundary in manifest["boundaries"]:
        owner = component_by_id[boundary["ownerComponent"]]["name"]
        lines.append(
            "| "
            + " | ".join(
                escape_table(value)
                for value in [
                    boundary["name"],
                    owner,
                    boundary["executionContext"],
                    boundary["allowedWork"],
                    boundary["forbiddenWork"],
                    boundary["failureBehavior"],
                ]
            )
            + " |"
        )

    lines.extend(["", "## Component details", ""])
    for component in components:
        lines.extend(
            [
                f"<a id=\"{component['id']}\"></a>",
                f"### {component['name']}",
                "",
                component["responsibility"],
                "",
                "- Targets: " + markdown_list(component["targets"]),
                "- Owner anchors: "
                + ", ".join(
                    f"`{anchor['symbol']}` in {markdown_link(anchor['path'])}"
                    for anchor in component["ownerAnchors"]
                ),
                "- Persistent or continuation state: " + markdown_list(component["state"]),
                "- Inputs: " + markdown_list(component["inputs"]),
                "- Outputs: " + markdown_list(component["outputs"]),
                "- Evidence: " + markdown_list(component["evidence"]),
                "- Depends on: "
                + (
                    ", ".join(f"`{item}`" for item in component["dependsOn"])
                    if component["dependsOn"]
                    else "—"
                ),
                "- Boundaries: "
                + (
                    ", ".join(f"`{item}`" for item in component["boundaries"])
                    if component["boundaries"]
                    else "—"
                ),
                "- Contracts: " + ", ".join(markdown_link(path) for path in component["contracts"]),
                "",
                "Sources and stable top-level declarations:",
                "",
            ]
        )
        for path in sorted(component["sourcePaths"]):
            declarations = grouped_symbols.get(path, [])
            declaration_text = (
                ", ".join(f"`{item.name}` ({item.kind})" for item in declarations)
                if declarations
                else "no top-level declaration indexed"
            )
            lines.append(f"- {markdown_link(path)} — {declaration_text}")
        lines.extend(["", "Tests:", ""])
        for path in sorted(component["testPaths"]):
            lines.append(f"- {markdown_link(path)}")
        lines.append("")

    source_owner = {
        path: component
        for component in components
        for path in component["sourcePaths"]
    }
    lines.extend(
        [
            "## Source and stable-symbol index",
            "",
            "| Source or resource | SwiftPM target | Primary component | Stable top-level declarations |",
            "| --- | --- | --- | --- |",
        ]
    )
    for path in sorted(source_owner):
        component = source_owner[path]
        declarations = grouped_symbols.get(path, [])
        declaration_text = (
            "<br>".join(f"`{item.name}` ({item.kind})" for item in declarations)
            if declarations
            else "—"
        )
        target = next(
            target_name
            for target_name in component["targets"]
            if path == targets[target_name].path
            or path.startswith(targets[target_name].path.rstrip("/") + "/")
        )
        lines.append(
            "| "
            + " | ".join(
                [
                    markdown_link(path),
                    f"`{target}`",
                    f"[`{component['id']}`](#{component['id']})",
                    declaration_text,
                ]
            )
            + " |"
        )

    component_contracts: Dict[str, List[str]] = {}
    flow_contracts: Dict[str, List[str]] = {}
    for component in components:
        for path in component["contracts"]:
            component_contracts.setdefault(path, []).append(component["id"])
    for flow in manifest["flows"]:
        for path in flow["contracts"]:
            flow_contracts.setdefault(path, []).append(flow["id"])
    lines.extend(
        [
            "",
            "## Contract index",
            "",
            "| Contract | Components | Flows |",
            "| --- | --- | --- |",
        ]
    )
    for path in sorted(set(component_contracts) | set(flow_contracts)):
        lines.append(
            "| "
            + " | ".join(
                [
                    markdown_link(path),
                    markdown_list(sorted(component_contracts.get(path, []))),
                    markdown_list(sorted(flow_contracts.get(path, []))),
                ]
            )
            + " |"
        )

    test_components: Dict[str, List[str]] = {}
    test_boundaries: Dict[str, List[str]] = {}
    for component in components:
        for path in component["testPaths"]:
            test_components.setdefault(path, []).append(component["id"])
    for boundary in manifest["boundaries"]:
        for path in boundary["tests"]:
            test_boundaries.setdefault(path, []).append(boundary["id"])
    lines.extend(
        [
            "",
            "## Test and stable-symbol index",
            "",
            "| Test source | Components | Boundaries | Stable top-level declarations |",
            "| --- | --- | --- | --- |",
        ]
    )
    for path in sorted(test_components):
        declarations = grouped_symbols.get(path, [])
        declaration_text = (
            "<br>".join(f"`{item.name}` ({item.kind})" for item in declarations)
            if declarations
            else "—"
        )
        lines.append(
            "| "
            + " | ".join(
                [
                    markdown_link(path),
                    markdown_list(sorted(test_components[path])),
                    markdown_list(sorted(test_boundaries.get(path, []))),
                    declaration_text,
                ]
            )
            + " |"
        )

    lines.extend(
        [
            "## Update triggers",
            "",
            "Update `docs/codebase-map.json` and regenerate this file when a change adds, removes, moves, or reassigns source/test/resource files, module dependencies, canonical owners or persistent state, runtime flows, evidence/evaluation/feedback/adaptation paths, realtime or future-boundary behavior, route recovery/fallback behavior, contracts, or test ownership.",
            "",
            "For an existing-symbol change that preserves all navigation semantics, leave the map unchanged and record the no-impact rationale in the pull request.",
            "",
        ]
    )
    return "\n".join(lines)


def print_validation_errors(errors: Sequence[str]) -> None:
    print(f"semantic codebase map validation failed with {len(errors)} issue(s):", file=sys.stderr)
    for index, error in enumerate(errors, start=1):
        print(f"  {index}. {error}", file=sys.stderr)


def write_atomic(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=path.name + ".",
        suffix=".tmp",
        dir=path.parent,
        text=True,
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(contents)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def run(mode: str, root: Path, build_path: Optional[Path]) -> int:
    manifest_path = root / "docs/codebase-map.json"
    output_path = root / "docs/CODEBASE_MAP.md"
    manifest = load_manifest(manifest_path)
    targets = inspect_package(root, build_path)
    tracked_paths = discover_repository_files(root, "Sources") + discover_repository_files(root, "Tests")
    symbols = inspect_symbols(root, build_path, targets, tracked_paths)
    errors = validate_manifest(manifest, root, targets, symbols)
    if errors:
        print_validation_errors(errors)
        return 1
    rendered = render_markdown(manifest, targets, symbols)
    if mode == "generate":
        write_atomic(output_path, rendered)
        print(f"generated {output_path.relative_to(root)}")
        return 0
    try:
        existing = output_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(
            "generated map is missing; run python3 scripts/codebase_map.py generate",
            file=sys.stderr,
        )
        return 1
    if existing != rendered:
        diff = list(
            difflib.unified_diff(
                existing.splitlines(),
                rendered.splitlines(),
                fromfile="docs/CODEBASE_MAP.md (checked in)",
                tofile="docs/CODEBASE_MAP.md (expected)",
                lineterm="",
            )
        )
        print("generated semantic codebase map is stale or hand-edited:", file=sys.stderr)
        for line in diff[:240]:
            print(line, file=sys.stderr)
        if len(diff) > 240:
            print(f"... diff truncated ({len(diff) - 240} more lines)", file=sys.stderr)
        print("run python3 scripts/codebase_map.py generate", file=sys.stderr)
        return 1
    print("semantic codebase map is current")
    return 0


def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    for mode in ["generate", "check"]:
        subparser = subparsers.add_parser(mode)
        subparser.add_argument(
            "--build-path",
            type=Path,
            help="SwiftPM build path to reuse for package inspection and symbol graphs",
        )
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = parse_arguments(argv)
    try:
        return run(arguments.mode, repository_root(), arguments.build_path)
    except CodebaseMapError as exc:
        print(f"semantic codebase map error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
