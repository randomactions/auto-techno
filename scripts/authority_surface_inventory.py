#!/usr/bin/env python3
"""Validate and render the canonical authority-surface collision inventory."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence


SCHEMA = "autotechno-authority-surface-inventory.v1"
AUTHORITY_SUFFIXES = (
    "Renderer", "Preparer", "Evaluator", "Director", "Resolver", "Policy",
    "Reducer", "Controller", "Qualifier", "Generator", "Engine",
    "Orchestrator", "Coordinator", "Balancer", "Analyzer", "Validator",
    "Processor", "Artifacts", "Preflight",
)
PROFILE_SUFFIXES = ("Profile", "Preset", "Mode", "Configuration")
TYPE_KINDS = {"struct", "class", "enum", "actor", "protocol"}
ROOT_KEYS = {
    "schema", "inventoryVersion", "scopePolicy", "authorityGroups",
    "profileGroups", "effectPaths",
}
GROUP_KEYS = {
    "id", "title", "category", "classification", "surfaceComponent",
    "canonicalComponent", "members", "convergenceAnchors", "evidenceAnchors",
    "pcmConsequence", "limitations",
}
MEMBER_KEYS = {"path", "symbol", "kind"}
ANCHOR_KEYS = {"path", "fragment"}
EFFECT_KEYS = {
    "id", "title", "classification", "canonicalComponent", "sourcePath",
    "entryAnchors", "convergenceAnchors", "evidenceAnchors", "pcmConsequence",
    "limitations",
}
CATEGORIES = {
    "decision", "preparation", "render", "effect", "evidence", "host",
    "utility", "profile",
}
CLASSIFICATIONS = {
    "canonical-owner", "owned-stage", "host-adapter", "offline-only",
    "deterministic-utility", "score-state", "dsp-configuration",
    "host-lifecycle", "installed-calibration-artifact",
    "qualification-support-artifact", "implementation-detail",
    "bounded-playback-state",
}
EFFECT_CLASSIFICATIONS = {
    "canonical-effect-owner", "owned-effect-stage",
    "bounded-qualified-branch", "non-pcm-projection",
}
PCM_CONSEQUENCES = {
    "none", "selects-score-only", "creates-future-pcm",
    "processes-future-pcm", "qualifies-without-changing-pcm",
    "changes-future-pcm-only", "commits-immutable-pcm",
    "schedules-immutable-pcm", "replays-qualified-pcm-without-canonical-advance",
    "projects-without-changing-pcm",
}


class AuthoritySurfaceInventoryError(RuntimeError):
    """An actionable authority-inventory validation failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def manifest_path(root: Path) -> Path:
    return root / "docs/AUTHORITY_SURFACE_INVENTORY.json"


def report_path(root: Path) -> Path:
    return root / "docs/AUTHORITY_SURFACE_INVENTORY.md"


def codebase_map_path(root: Path) -> Path:
    return root / "docs/codebase-map.json"


def normalize_repo_path(value: object) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError("must be a non-empty string")
    if "\\" in value:
        raise ValueError("must use forward slashes")
    path = PurePosixPath(value)
    if path.is_absolute() or "." in path.parts or ".." in path.parts:
        raise ValueError("must be repository-relative without '.' or '..'")
    return path.as_posix()


def load_json(path: Path, description: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AuthoritySurfaceInventoryError(f"missing {description}: {path}") from exc
    except json.JSONDecodeError as exc:
        raise AuthoritySurfaceInventoryError(
            f"invalid JSON in {description} {path}: {exc}"
        ) from exc
    if not isinstance(value, dict):
        raise AuthoritySurfaceInventoryError(f"{description} root must be an object")
    return value


def swift_without_comments_or_strings(contents: str) -> str:
    output: list[str] = []
    index = 0
    block_depth = 0
    in_line_comment = False
    in_string = False
    multiline_string = False
    while index < len(contents):
        if in_line_comment:
            if contents[index] == "\n":
                in_line_comment = False
                output.append("\n")
            else:
                output.append(" ")
            index += 1
            continue
        if block_depth:
            if contents.startswith("/*", index):
                block_depth += 1
                output.extend("  ")
                index += 2
            elif contents.startswith("*/", index):
                block_depth -= 1
                output.extend("  ")
                index += 2
            else:
                output.append("\n" if contents[index] == "\n" else " ")
                index += 1
            continue
        if in_string:
            terminator = '\"\"\"' if multiline_string else '\"'
            if contents.startswith(terminator, index):
                output.extend(" " * len(terminator))
                index += len(terminator)
                in_string = False
                multiline_string = False
            elif not multiline_string and contents[index] == "\\" and index + 1 < len(contents):
                output.extend("  ")
                index += 2
            else:
                output.append("\n" if contents[index] == "\n" else " ")
                index += 1
            continue
        if contents.startswith("//", index):
            in_line_comment = True
            output.extend("  ")
            index += 2
        elif contents.startswith("/*", index):
            block_depth = 1
            output.extend("  ")
            index += 2
        elif contents.startswith('\"\"\"', index):
            in_string = True
            multiline_string = True
            output.extend("   ")
            index += 3
        elif contents[index] == '\"':
            in_string = True
            output.append(" ")
            index += 1
        else:
            output.append(contents[index])
            index += 1
    return "".join(output)


TYPE_PATTERN = re.compile(
    r"(?m)^[ \t]*"
    r"(?:(?:@[A-Za-z_][A-Za-z0-9_.]*(?:\([^\n)]*\))?[ \t]+))*"
    r"(?:(?:package|public|internal|private|fileprivate|open|final|indirect|"
    r"nonisolated|noncopyable)[ \t]+)*"
    r"(struct|class|enum|actor|protocol)[ \t]+"
    r"([A-Za-z_][A-Za-z0-9_]*)\b"
)
STATIC_PROFILE_VALUE_PATTERN = re.compile(
    r"(?mi)^[ \t]*"
    r"(?:(?:package|public|internal|private|fileprivate|open)[ \t]+)*"
    r"(?:static|class)[ \t]+(?:let|var)[ \t]+"
    r"([A-Za-z_][A-Za-z0-9_]*)\b"
)


def discover_types(root: Path, suffixes: tuple[str, ...]) -> list[dict[str, str]]:
    sources = root / "Sources"
    discovered: list[dict[str, str]] = []
    for path in sorted(sources.rglob("*.swift")):
        relative = path.relative_to(root).as_posix()
        sanitized = swift_without_comments_or_strings(path.read_text(encoding="utf-8"))
        for match in TYPE_PATTERN.finditer(sanitized):
            kind, symbol = match.groups()
            if symbol.endswith(suffixes):
                discovered.append({"path": relative, "symbol": symbol, "kind": kind})
    return sorted(discovered, key=lambda item: (item["path"], item["symbol"], item["kind"]))


def discover_authority_surfaces(root: Path) -> list[dict[str, str]]:
    return discover_types(root, AUTHORITY_SUFFIXES)


def discover_profile_surfaces(root: Path) -> list[dict[str, str]]:
    discovered = discover_types(root, PROFILE_SUFFIXES)
    resource_root = root / "Sources"
    for path in sorted(resource_root.rglob("*.swift")):
        relative = path.relative_to(root).as_posix()
        sanitized = swift_without_comments_or_strings(path.read_text(encoding="utf-8"))
        for match in STATIC_PROFILE_VALUE_PATTERN.finditer(sanitized):
            if not any(word in match.group(1).lower() for word in ("profile", "preset")):
                continue
            discovered.append({
                "path": relative,
                "symbol": match.group(1),
                "kind": "static-value",
            })
    for path in sorted(resource_root.rglob("*.json")):
        discovered.append({
            "path": path.relative_to(root).as_posix(),
            "symbol": path.stem,
            "kind": "json-resource",
        })
    return sorted(discovered, key=lambda item: (item["path"], item["symbol"], item["kind"]))


def validate_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    unknown = sorted(set(value) - expected)
    missing = sorted(expected - set(value))
    if unknown:
        errors.append(f"{location} has unknown fields: {', '.join(unknown)}")
    if missing:
        errors.append(f"{location} is missing fields: {', '.join(missing)}")


def validate_id(value: object, location: str, errors: list[str]) -> Optional[str]:
    if not isinstance(value, str) or not re.fullmatch(
        r"[a-z0-9]+(?:-[a-z0-9]+)*", value
    ):
        errors.append(f"{location} must be lowercase kebab-case")
        return None
    return value


def validate_anchor(
    root: Path, raw: object, location: str, errors: list[str]
) -> None:
    if not isinstance(raw, dict):
        errors.append(f"{location} must be an object")
        return
    validate_keys(raw, ANCHOR_KEYS, location, errors)
    try:
        path = normalize_repo_path(raw.get("path"))
    except ValueError as exc:
        errors.append(f"{location}.path {exc}")
        return
    fragment = raw.get("fragment")
    if not isinstance(fragment, str) or not fragment:
        errors.append(f"{location}.fragment must be a non-empty string")
        return
    try:
        contents = (root / path).read_text(encoding="utf-8")
    except FileNotFoundError:
        errors.append(f"{location}.path is missing: {path}")
        return
    if fragment not in contents:
        errors.append(f"{location}.fragment is missing from {path}: {fragment}")


def component_index(
    root: Path, errors: list[str]
) -> dict[str, Mapping[str, Any]]:
    try:
        codebase_map = load_json(codebase_map_path(root), "semantic codebase map")
    except AuthoritySurfaceInventoryError as exc:
        errors.append(str(exc))
        return {}
    components = codebase_map.get("components")
    if not isinstance(components, list):
        errors.append("semantic codebase map components must be an array")
        return {}
    return {
        component["id"]: component
        for component in components
        if isinstance(component, dict) and isinstance(component.get("id"), str)
    }


def member_key(member: Mapping[str, object]) -> tuple[object, object, object]:
    return member.get("path"), member.get("symbol"), member.get("kind")


def validate_group_collection(
    root: Path,
    raw_groups: object,
    location: str,
    discovered: list[dict[str, str]],
    components: Mapping[str, Mapping[str, Any]],
    errors: list[str],
) -> None:
    if not isinstance(raw_groups, list) or not raw_groups:
        errors.append(f"{location} must be a non-empty array")
        return
    ids: set[str] = set()
    recorded: dict[tuple[object, object, object], str] = {}
    for group_index, group in enumerate(raw_groups):
        group_location = f"{location}[{group_index}]"
        if not isinstance(group, dict):
            errors.append(f"{group_location} must be an object")
            continue
        validate_keys(group, GROUP_KEYS, group_location, errors)
        group_id = validate_id(group.get("id"), f"{group_location}.id", errors)
        if group_id is not None:
            if group_id in ids:
                errors.append(f"duplicate {location} id {group_id}")
            ids.add(group_id)
        for field in ["title", "limitations"]:
            if not isinstance(group.get(field), str) or not group.get(field):
                errors.append(f"{group_location}.{field} must be a non-empty string")
        if group.get("category") not in CATEGORIES:
            errors.append(f"{group_location}.category must be one of {sorted(CATEGORIES)}")
        if group.get("classification") not in CLASSIFICATIONS:
            errors.append(
                f"{group_location}.classification must be one of {sorted(CLASSIFICATIONS)}"
            )
        if group.get("pcmConsequence") not in PCM_CONSEQUENCES:
            errors.append(
                f"{group_location}.pcmConsequence must be one of {sorted(PCM_CONSEQUENCES)}"
            )
        surface_component = group.get("surfaceComponent")
        canonical_component = group.get("canonicalComponent")
        if surface_component not in components:
            errors.append(f"{group_location}.surfaceComponent is unknown: {surface_component}")
        if canonical_component not in components:
            errors.append(f"{group_location}.canonicalComponent is unknown: {canonical_component}")
        members = group.get("members")
        if not isinstance(members, list) or not members:
            errors.append(f"{group_location}.members must be a non-empty array")
            members = []
        for member_index, member in enumerate(members):
            member_location = f"{group_location}.members[{member_index}]"
            if not isinstance(member, dict):
                errors.append(f"{member_location} must be an object")
                continue
            validate_keys(member, MEMBER_KEYS, member_location, errors)
            try:
                path = normalize_repo_path(member.get("path"))
            except ValueError as exc:
                errors.append(f"{member_location}.path {exc}")
                continue
            symbol = member.get("symbol")
            kind = member.get("kind")
            if not isinstance(symbol, str) or not symbol:
                errors.append(f"{member_location}.symbol must be a non-empty string")
            if kind not in TYPE_KINDS | {"json-resource", "static-value"}:
                errors.append(f"{member_location}.kind is unsupported: {kind}")
            key = (path, symbol, kind)
            if key in recorded:
                errors.append(f"{member_location} duplicates member from {recorded[key]}")
            else:
                recorded[key] = member_location
            component = components.get(surface_component)
            if component is not None and path not in component.get("sourcePaths", []):
                errors.append(
                    f"{member_location}.path is not owned by component {surface_component}"
                )
        for anchors_field in ["convergenceAnchors", "evidenceAnchors"]:
            anchors = group.get(anchors_field)
            if not isinstance(anchors, list) or not anchors:
                errors.append(f"{group_location}.{anchors_field} must be a non-empty array")
                continue
            for anchor_index, anchor in enumerate(anchors):
                validate_anchor(
                    root, anchor,
                    f"{group_location}.{anchors_field}[{anchor_index}]", errors
                )
        if group.get("classification") == "canonical-owner":
            component = components.get(canonical_component)
            owner_symbols = {
                anchor.get("symbol")
                for anchor in component.get("ownerAnchors", [])
                if isinstance(anchor, dict)
            } if component is not None else set()
            for member in members:
                if isinstance(member, dict) and member.get("symbol") not in owner_symbols:
                    errors.append(
                        f"{group_location} canonical-owner member {member.get('symbol')} "
                        f"is not an owner anchor of {canonical_component}"
                    )
    current = {member_key(item) for item in discovered}
    recorded_keys = set(recorded)
    missing = sorted(current - recorded_keys)
    stale = sorted(recorded_keys - current)
    if missing:
        errors.append(
            f"{location} has unclassified current surfaces: "
            + ", ".join(f"{path}:{symbol}:{kind}" for path, symbol, kind in missing)
        )
    if stale:
        errors.append(
            f"{location} names absent surfaces: "
            + ", ".join(f"{path}:{symbol}:{kind}" for path, symbol, kind in stale)
        )


def validate_effect_paths(
    root: Path,
    raw_paths: object,
    components: Mapping[str, Mapping[str, Any]],
    errors: list[str],
) -> None:
    if not isinstance(raw_paths, list) or not raw_paths:
        errors.append("effectPaths must be a non-empty array")
        return
    graph_component = components.get("graph-effects-routing-and-mix")
    expected_paths = set(graph_component.get("sourcePaths", [])) if graph_component else set()
    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    for index, effect in enumerate(raw_paths):
        location = f"effectPaths[{index}]"
        if not isinstance(effect, dict):
            errors.append(f"{location} must be an object")
            continue
        validate_keys(effect, EFFECT_KEYS, location, errors)
        effect_id = validate_id(effect.get("id"), f"{location}.id", errors)
        if effect_id is not None:
            if effect_id in seen_ids:
                errors.append(f"duplicate effect path id {effect_id}")
            seen_ids.add(effect_id)
        if effect.get("classification") not in EFFECT_CLASSIFICATIONS:
            errors.append(
                f"{location}.classification must be one of {sorted(EFFECT_CLASSIFICATIONS)}"
            )
        if effect.get("pcmConsequence") not in PCM_CONSEQUENCES:
            errors.append(f"{location}.pcmConsequence is unsupported")
        canonical_component = effect.get("canonicalComponent")
        if canonical_component not in components:
            errors.append(f"{location}.canonicalComponent is unknown: {canonical_component}")
        try:
            path = normalize_repo_path(effect.get("sourcePath"))
        except ValueError as exc:
            errors.append(f"{location}.sourcePath {exc}")
            continue
        if path in seen_paths:
            errors.append(f"{location}.sourcePath duplicates {path}")
        seen_paths.add(path)
        if path not in expected_paths:
            errors.append(f"{location}.sourcePath is not owned by graph-effects-routing-and-mix")
        for field in ["title", "limitations"]:
            if not isinstance(effect.get(field), str) or not effect.get(field):
                errors.append(f"{location}.{field} must be a non-empty string")
        for anchors_field in ["entryAnchors", "convergenceAnchors", "evidenceAnchors"]:
            anchors = effect.get(anchors_field)
            if not isinstance(anchors, list) or not anchors:
                errors.append(f"{location}.{anchors_field} must be a non-empty array")
                continue
            for anchor_index, anchor in enumerate(anchors):
                validate_anchor(
                    root, anchor, f"{location}.{anchors_field}[{anchor_index}]", errors
                )
    missing = sorted(expected_paths - seen_paths)
    stale = sorted(seen_paths - expected_paths)
    if missing:
        errors.append("effectPaths omits graph component paths: " + ", ".join(missing))
    if stale:
        errors.append("effectPaths includes non-graph paths: " + ", ".join(stale))


def validate_manifest(manifest: Mapping[str, Any], root: Path) -> list[str]:
    errors: list[str] = []
    validate_keys(manifest, ROOT_KEYS, "inventory", errors)
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    version = manifest.get("inventoryVersion")
    if isinstance(version, bool) or not isinstance(version, int) or version < 1:
        errors.append("inventoryVersion must be a positive integer")
    if not isinstance(manifest.get("scopePolicy"), str) or not manifest.get("scopePolicy"):
        errors.append("scopePolicy must be a non-empty string")
    components = component_index(root, errors)
    validate_group_collection(
        root, manifest.get("authorityGroups"), "authorityGroups",
        discover_authority_surfaces(root), components, errors
    )
    validate_group_collection(
        root, manifest.get("profileGroups"), "profileGroups",
        discover_profile_surfaces(root), components, errors
    )
    validate_effect_paths(root, manifest.get("effectPaths"), components, errors)
    return errors


def markdown_link(path: str) -> str:
    return f"[`{path}`](../{path})"


def render_group_table(lines: list[str], groups: Sequence[Mapping[str, Any]]) -> None:
    lines.extend([
        "| Group | Category | Classification | Surface → canonical owner | Members | PCM consequence |",
        "| --- | --- | --- | --- | ---: | --- |",
    ])
    for group in groups:
        lines.append(
            f"| [`{group['id']}`](#{group['id']}) | `{group['category']}` | "
            f"`{group['classification']}` | `{group['surfaceComponent']}` → "
            f"`{group['canonicalComponent']}` | {len(group['members'])} | "
            f"`{group['pcmConsequence']}` |"
        )


def render_group_details(lines: list[str], groups: Sequence[Mapping[str, Any]]) -> None:
    for group in groups:
        lines.extend([
            "", f"## {group['title']}", f"<a id=\"{group['id']}\"></a>", "",
            f"Classification: `{group['classification']}`  ",
            f"Owner convergence: `{group['surfaceComponent']}` → `{group['canonicalComponent']}`  ",
            f"PCM consequence: `{group['pcmConsequence']}`", "", "Members:", "",
        ])
        for member in group["members"]:
            lines.append(
                f"- `{member['kind']} {member['symbol']}` in {markdown_link(member['path'])}"
            )
        lines.extend(["", "Convergence anchors:", ""])
        for anchor in group["convergenceAnchors"]:
            lines.append(f"- {markdown_link(anchor['path'])}: `{anchor['fragment']}`")
        lines.extend(["", "Evidence anchors:", ""])
        for anchor in group["evidenceAnchors"]:
            lines.append(f"- {markdown_link(anchor['path'])}: `{anchor['fragment']}`")
        lines.extend(["", f"Limitation: {group['limitations']}"])


def render_markdown(manifest: Mapping[str, Any]) -> str:
    authority_count = sum(len(group["members"]) for group in manifest["authorityGroups"])
    profile_count = sum(len(group["members"]) for group in manifest["profileGroups"])
    lines = [
        "<!-- GENERATED by scripts/authority_surface_inventory.py; edit the JSON source. -->",
        "# Canonical authority and hidden-path inventory", "",
        f"Inventory schema: `{manifest['schema']}`  ",
        f"Inventory version: {manifest['inventoryVersion']}", "", "## Scope", "",
        str(manifest["scopePolicy"]), "",
        f"The checked inventory currently classifies {authority_count} authority-shaped Swift types, "
        f"{profile_count} profile/mode/configuration/resource surfaces, and "
        f"{len(manifest['effectPaths'])} graph-component paths. Similar names are candidates for "
        "collision analysis, not proof of duplicate runtime authority.", "",
        "## Authority summary", "",
    ]
    render_group_table(lines, manifest["authorityGroups"])
    lines.extend(["", "## Profile and packaged-resource summary", ""])
    render_group_table(lines, manifest["profileGroups"])
    lines.extend([
        "", "## Effect-path summary", "",
        "| Path | Classification | Canonical owner | PCM consequence |",
        "| --- | --- | --- | --- |",
    ])
    for effect in manifest["effectPaths"]:
        lines.append(
            f"| [`{effect['id']}`](#{effect['id']}) — {markdown_link(effect['sourcePath'])} | "
            f"`{effect['classification']}` | `{effect['canonicalComponent']}` | "
            f"`{effect['pcmConsequence']}` |"
        )
    render_group_details(lines, manifest["authorityGroups"])
    render_group_details(lines, manifest["profileGroups"])
    for effect in manifest["effectPaths"]:
        lines.extend([
            "", f"## {effect['title']}", f"<a id=\"{effect['id']}\"></a>", "",
            f"Source: {markdown_link(effect['sourcePath'])}  ",
            f"Classification: `{effect['classification']}`  ",
            f"Canonical owner: `{effect['canonicalComponent']}`  ",
            f"PCM consequence: `{effect['pcmConsequence']}`", "", "Entry anchors:", "",
        ])
        for anchor in effect["entryAnchors"]:
            lines.append(f"- {markdown_link(anchor['path'])}: `{anchor['fragment']}`")
        lines.extend(["", "Convergence anchors:", ""])
        for anchor in effect["convergenceAnchors"]:
            lines.append(f"- {markdown_link(anchor['path'])}: `{anchor['fragment']}`")
        lines.extend(["", "Evidence anchors:", ""])
        for anchor in effect["evidenceAnchors"]:
            lines.append(f"- {markdown_link(anchor['path'])}: `{anchor['fragment']}`")
        lines.extend(["", f"Limitation: {effect['limitations']}"])
    lines.extend([
        "", "## Maintenance", "", "```bash",
        "python3 scripts/authority_surface_inventory.py check", "```", "",
        "Any newly discovered authority-shaped type, profile-shaped type, bundled JSON resource, "
        "or semantic-map graph path fails closed until deliberately classified. Runtime behavior "
        "remains authoritative over this offline navigation artifact.", "",
    ])
    return "\n".join(lines)


def write_atomic(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=path.name + ".", suffix=".tmp", dir=path.parent, text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(contents)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def run_generate(root: Path, output: object = sys.stdout) -> int:
    manifest = load_json(manifest_path(root), "authority inventory")
    errors = validate_manifest(manifest, root)
    if errors:
        raise AuthoritySurfaceInventoryError(
            "inventory is invalid: " + "; ".join(errors)
        )
    write_atomic(report_path(root), render_markdown(manifest))
    print(f"generated authority inventory v{manifest['inventoryVersion']}", file=output)
    return 0


def run_check(root: Path, output: object = sys.stdout) -> int:
    manifest = load_json(manifest_path(root), "authority inventory")
    errors = validate_manifest(manifest, root)
    if not errors:
        expected = render_markdown(manifest)
        try:
            actual = report_path(root).read_text(encoding="utf-8")
        except FileNotFoundError:
            errors.append("generated authority inventory report is missing")
        else:
            if actual != expected:
                errors.append("generated authority inventory report is stale; run generate")
    if errors:
        print(f"authority inventory rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, start=1):
            print(f"  {index}. {error}", file=output)
        return 1
    authority_count = sum(
        len(group["members"]) for group in manifest["authorityGroups"]
    )
    profile_count = sum(len(group["members"]) for group in manifest["profileGroups"])
    print(
        f"authority inventory is current: v{manifest['inventoryVersion']}, "
        f"{authority_count} authority surfaces, {profile_count} profile/resource surfaces, "
        f"{len(manifest['effectPaths'])} effect paths",
        file=output,
    )
    return 0


def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["check", "generate"])
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = parse_arguments(argv)
    try:
        if arguments.mode == "generate":
            return run_generate(repository_root())
        return run_check(repository_root())
    except (AuthoritySurfaceInventoryError, ValueError) as exc:
        print(f"authority inventory error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
