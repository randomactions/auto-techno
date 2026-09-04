#!/usr/bin/env python3
"""Validate and render the canonical musical/DSP parameter reachability audit."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence


SCHEMA = "autotechno-parameter-reachability-audit.v1"
ROOT_KEYS = {"schema", "auditVersion", "scopePolicy", "domains"}
DOMAIN_KEYS = {
    "id",
    "title",
    "classification",
    "owners",
    "consumerAnchors",
    "pcmEvidence",
    "signalEvidence",
    "futureDecision",
    "forbiddenAnchors",
    "limitations",
}
OWNER_KEYS = {"path", "type", "kind", "selection", "members"}
ANCHOR_KEYS = {"path", "fragment"}
EVIDENCE_KEYS = {"status", "path", "fragment"}
CLASSIFICATIONS = {
    "active-rendered",
    "active-structural",
    "active-dsp-contract",
    "quarantined-no-pcm",
}
OWNER_KINDS = {"enum-cases", "stored-properties"}
SELECTIONS = {"all", "explicit"}
PCM_STATUSES = {
    "direct-causal",
    "composed-causal",
    "structural-no-pcm",
    "quarantined-no-pcm",
}
SIGNAL_STATUSES = {
    "direct-evidence",
    "aggregate-evidence",
    "structural-provenance",
    "unavailable-quarantined",
}
DECISION_STATUSES = {
    "direct-adaptation",
    "available-to-bounded-evaluator",
    "fixed-contract-with-evidence",
    "structural-owner",
    "quarantined",
}


class ParameterReachabilityError(RuntimeError):
    """An actionable parameter-audit validation failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def manifest_path(root: Path) -> Path:
    return root / "docs/PARAMETER_REACHABILITY_AUDIT.json"


def report_path(root: Path) -> Path:
    return root / "docs/PARAMETER_REACHABILITY_AUDIT.md"


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
        raise ParameterReachabilityError(f"missing parameter audit: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ParameterReachabilityError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ParameterReachabilityError("parameter audit root must be an object")
    return value


def swift_without_comments_or_strings(contents: str) -> str:
    """Replace Swift comments/string contents while preserving braces and lines."""
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
            terminator = '"""' if multiline_string else '"'
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
        elif contents.startswith('"""', index):
            in_string = True
            multiline_string = True
            output.extend("   ")
            index += 3
        elif contents[index] == '"':
            in_string = True
            output.append(" ")
            index += 1
        else:
            output.append(contents[index])
            index += 1
    return "".join(output)


def declaration_body(contents: str, type_name: str, kind: str) -> str:
    sanitized = swift_without_comments_or_strings(contents)
    swift_kind = "enum" if kind == "enum-cases" else "struct"
    pattern = re.compile(
        rf"(?m)^\s*(?:(?:package|public|internal|private|fileprivate)\s+)?"
        rf"{swift_kind}\s+{re.escape(type_name)}\b[^{{]*{{"
    )
    matches = list(pattern.finditer(sanitized))
    if len(matches) != 1:
        raise ParameterReachabilityError(
            f"expected exactly one {swift_kind} {type_name}, found {len(matches)}"
        )
    opening = sanitized.find("{", matches[0].start())
    depth = 1
    index = opening + 1
    while index < len(sanitized) and depth:
        if sanitized[index] == "{":
            depth += 1
        elif sanitized[index] == "}":
            depth -= 1
        index += 1
    if depth:
        raise ParameterReachabilityError(f"unclosed declaration {type_name}")
    return sanitized[opening + 1 : index - 1]


def direct_lines(body: str) -> list[str]:
    result: list[str] = []
    depth = 0
    for line in body.splitlines():
        if depth == 0:
            result.append(line)
        depth += line.count("{") - line.count("}")
    return result


def declared_members(root: Path, owner: Mapping[str, Any]) -> list[str]:
    path = normalize_repo_path(owner.get("path"))
    type_name = owner.get("type")
    kind = owner.get("kind")
    if not isinstance(type_name, str) or not type_name:
        raise ParameterReachabilityError("owner type must be a non-empty string")
    if kind not in OWNER_KINDS:
        raise ParameterReachabilityError(f"unsupported owner kind {kind!r}")
    try:
        contents = (root / path).read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ParameterReachabilityError(f"missing owner source: {path}") from exc
    body = declaration_body(contents, type_name, kind)
    members: list[str] = []
    if kind == "enum-cases":
        for line in direct_lines(body):
            match = re.match(r"^\s*case\s+(.+)$", line)
            if not match:
                continue
            for item in match.group(1).split(","):
                name = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)", item)
                if name:
                    members.append(name.group(1))
    else:
        property_pattern = re.compile(
            r"^\s*(?:(?:package|public|internal|private|fileprivate|open)"
            r"(?:\(set\))?\s+)*"
            r"(?:(?:nonisolated|weak|unowned)\s+)*(let|var)\s+"
            r"([A-Za-z_][A-Za-z0-9_]*)\s*:"
        )
        for line in direct_lines(body):
            match = property_pattern.match(line)
            if match and "{" not in line[match.end() :]:
                members.append(match.group(2))
    if not members:
        raise ParameterReachabilityError(
            f"{path} {type_name} exposes no auditable {kind}"
        )
    if len(members) != len(set(members)):
        raise ParameterReachabilityError(f"duplicate parsed members in {path} {type_name}")
    return members


def validate_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    unknown = sorted(set(value) - expected)
    missing = sorted(expected - set(value))
    if unknown:
        errors.append(f"{location} has unknown fields: {', '.join(unknown)}")
    if missing:
        errors.append(f"{location} is missing fields: {', '.join(missing)}")


def validate_anchor(
    root: Path,
    raw: object,
    location: str,
    errors: list[str],
    *,
    forbidden: bool = False,
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
    present = fragment in contents
    if forbidden and present:
        errors.append(f"{location} forbidden fragment is present in {path}: {fragment}")
    elif not forbidden and not present:
        errors.append(f"{location} fragment is missing from {path}: {fragment}")


def validate_evidence(
    root: Path,
    raw: object,
    location: str,
    allowed_statuses: set[str],
    errors: list[str],
) -> None:
    if not isinstance(raw, dict):
        errors.append(f"{location} must be an object")
        return
    validate_keys(raw, EVIDENCE_KEYS, location, errors)
    if raw.get("status") not in allowed_statuses:
        errors.append(f"{location}.status must be one of {sorted(allowed_statuses)}")
    validate_anchor(
        root,
        {"path": raw.get("path"), "fragment": raw.get("fragment")},
        location,
        errors,
    )


def validate_manifest(manifest: Mapping[str, Any], root: Path) -> list[str]:
    errors: list[str] = []
    validate_keys(manifest, ROOT_KEYS, "audit", errors)
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    version = manifest.get("auditVersion")
    if isinstance(version, bool) or not isinstance(version, int) or version < 1:
        errors.append("auditVersion must be a positive integer")
    if not isinstance(manifest.get("scopePolicy"), str) or not manifest.get("scopePolicy"):
        errors.append("scopePolicy must be a non-empty string")
    domains = manifest.get("domains")
    if not isinstance(domains, list):
        errors.append("domains must be an array")
        return errors

    domain_ids: set[str] = set()
    declarations: dict[tuple[str, str, str], list[tuple[str, Mapping[str, Any]]]] = {}
    for domain_index, domain in enumerate(domains):
        location = f"domains[{domain_index}]"
        if not isinstance(domain, dict):
            errors.append(f"{location} must be an object")
            continue
        validate_keys(domain, DOMAIN_KEYS, location, errors)
        domain_id = domain.get("id")
        if not isinstance(domain_id, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", domain_id):
            errors.append(f"{location}.id must be lowercase kebab-case")
        elif domain_id in domain_ids:
            errors.append(f"duplicate domain id {domain_id}")
        else:
            domain_ids.add(domain_id)
        if not isinstance(domain.get("title"), str) or not domain.get("title"):
            errors.append(f"{location}.title must be a non-empty string")
        if domain.get("classification") not in CLASSIFICATIONS:
            errors.append(f"{location}.classification must be one of {sorted(CLASSIFICATIONS)}")
        if not isinstance(domain.get("limitations"), str) or not domain.get("limitations"):
            errors.append(f"{location}.limitations must be a non-empty string")

        owners = domain.get("owners")
        if not isinstance(owners, list) or not owners:
            errors.append(f"{location}.owners must be a non-empty array")
            owners = []
        for owner_index, owner in enumerate(owners):
            owner_location = f"{location}.owners[{owner_index}]"
            if not isinstance(owner, dict):
                errors.append(f"{owner_location} must be an object")
                continue
            validate_keys(owner, OWNER_KEYS, owner_location, errors)
            try:
                path = normalize_repo_path(owner.get("path"))
            except ValueError as exc:
                errors.append(f"{owner_location}.path {exc}")
                continue
            type_name = owner.get("type")
            kind = owner.get("kind")
            selection = owner.get("selection")
            members = owner.get("members")
            if not isinstance(type_name, str) or not type_name:
                errors.append(f"{owner_location}.type must be a non-empty string")
                continue
            if kind not in OWNER_KINDS:
                errors.append(f"{owner_location}.kind must be one of {sorted(OWNER_KINDS)}")
                continue
            if selection not in SELECTIONS:
                errors.append(f"{owner_location}.selection must be one of {sorted(SELECTIONS)}")
            if not isinstance(members, list) or not members or not all(
                isinstance(member, str) and member for member in members
            ):
                errors.append(f"{owner_location}.members must be a non-empty string array")
                continue
            if len(members) != len(set(members)):
                errors.append(f"{owner_location}.members contains duplicates")
            declarations.setdefault((path, type_name, kind), []).append((owner_location, owner))

        anchors = domain.get("consumerAnchors")
        if not isinstance(anchors, list) or not anchors:
            errors.append(f"{location}.consumerAnchors must be a non-empty array")
            anchors = []
        for anchor_index, anchor in enumerate(anchors):
            validate_anchor(root, anchor, f"{location}.consumerAnchors[{anchor_index}]", errors)
        forbidden = domain.get("forbiddenAnchors")
        if not isinstance(forbidden, list):
            errors.append(f"{location}.forbiddenAnchors must be an array")
            forbidden = []
        for anchor_index, anchor in enumerate(forbidden):
            validate_anchor(
                root,
                anchor,
                f"{location}.forbiddenAnchors[{anchor_index}]",
                errors,
                forbidden=True,
            )
        validate_evidence(root, domain.get("pcmEvidence"), f"{location}.pcmEvidence", PCM_STATUSES, errors)
        validate_evidence(root, domain.get("signalEvidence"), f"{location}.signalEvidence", SIGNAL_STATUSES, errors)
        validate_evidence(root, domain.get("futureDecision"), f"{location}.futureDecision", DECISION_STATUSES, errors)

    for selector, partitions in declarations.items():
        path, type_name, kind = selector
        try:
            current = declared_members(root, partitions[0][1])
        except (ParameterReachabilityError, ValueError) as exc:
            errors.append(f"{path} {type_name}: {exc}")
            continue
        seen: dict[str, str] = {}
        for owner_location, owner in partitions:
            members = owner.get("members", [])
            if owner.get("selection") == "all" and len(partitions) != 1:
                errors.append(f"{owner_location}.selection all cannot partition a declaration")
            for member in members:
                if member in seen:
                    errors.append(
                        f"{owner_location}.members duplicates {member} from {seen[member]}"
                    )
                else:
                    seen[member] = owner_location
        missing = [member for member in current if member not in seen]
        stale = [member for member in seen if member not in current]
        if missing:
            errors.append(
                f"{path} {type_name} has unclassified current members: {', '.join(missing)}"
            )
        if stale:
            errors.append(
                f"{path} {type_name} audit names absent members: {', '.join(stale)}"
            )
        if len(partitions) == 1 and partitions[0][1].get("selection") == "all":
            recorded = partitions[0][1].get("members", [])
            if recorded != current:
                errors.append(
                    f"{path} {type_name} members are stale or reordered; run refresh"
                )
    return errors


def markdown_link(path: str) -> str:
    return f"[`{path}`](../{path})"


def render_markdown(manifest: Mapping[str, Any]) -> str:
    lines = [
        "<!-- GENERATED by scripts/parameter_reachability_audit.py; edit the JSON source. -->",
        "# Musical and DSP parameter reachability audit",
        "",
        f"Audit schema: `{manifest['schema']}`  ",
        f"Audit version: {manifest['auditVersion']}",
        "",
        "## Scope",
        "",
        str(manifest["scopePolicy"]),
        "",
        "This is a static, source-linked coverage record. A `composed-causal` row combines a checked score/consumer path with a family-level PCM test; it is not a claim that every scalar was independently swept. Quarantined rows are explicit negative findings and cannot be promoted without new score, PCM, evidence, and bounded-decision proof.",
        "",
        "## Summary",
        "",
        "| Domain | Classification | Members | PCM | Signal evidence | Future decision |",
        "| --- | --- | ---: | --- | --- | --- |",
    ]
    for domain in manifest["domains"]:
        count = sum(len(owner["members"]) for owner in domain["owners"])
        lines.append(
            f"| [`{domain['id']}`](#{domain['id']}) | `{domain['classification']}` | {count} | "
            f"`{domain['pcmEvidence']['status']}` | `{domain['signalEvidence']['status']}` | "
            f"`{domain['futureDecision']['status']}` |"
        )
    for domain in manifest["domains"]:
        lines.extend(
            [
                "",
                f"## {domain['title']}",
                f"<a id=\"{domain['id']}\"></a>",
                "",
                f"Classification: `{domain['classification']}`",
                "",
                "| Owner | Members |",
                "| --- | --- |",
            ]
        )
        for owner in domain["owners"]:
            members = ", ".join(f"`{member}`" for member in owner["members"])
            lines.append(
                f"| `{owner['type']}` in {markdown_link(owner['path'])} | {members} |"
            )
        lines.extend(["", "Consumer anchors:", ""])
        for anchor in domain["consumerAnchors"]:
            lines.append(f"- {markdown_link(anchor['path'])}: `{anchor['fragment']}`")
        for label, key in [
            ("PCM", "pcmEvidence"),
            ("Signal evidence", "signalEvidence"),
            ("Future decision", "futureDecision"),
        ]:
            evidence = domain[key]
            lines.extend(
                [
                    "",
                    f"{label}: `{evidence['status']}` — {markdown_link(evidence['path'])}: "
                    f"`{evidence['fragment']}`",
                ]
            )
        if domain["forbiddenAnchors"]:
            lines.extend(["", "Quarantine absence checks:", ""])
            for anchor in domain["forbiddenAnchors"]:
                lines.append(
                    f"- `{anchor['fragment']}` must remain absent from {markdown_link(anchor['path'])}."
                )
        lines.extend(["", f"Limitation: {domain['limitations']}"])
    lines.extend(
        [
            "",
            "## Maintenance",
            "",
            "```bash",
            "python3 scripts/parameter_reachability_audit.py check",
            "python3 scripts/parameter_reachability_audit.py refresh --audit-version <next-version>",
            "```",
            "",
            "`refresh` updates members only for unpartitioned owners whose selection is `all`; explicit partitions require deliberate classification. Any new declaration member therefore fails closed until it is either attached to a causal chain or quarantined with evidence.",
            "",
        ]
    )
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


def refreshed_manifest(manifest: Mapping[str, Any], root: Path, version: int) -> dict[str, Any]:
    if isinstance(version, bool) or version < 1:
        raise ParameterReachabilityError("audit version must be a positive integer")
    current = copy.deepcopy(dict(manifest))
    previous_version = current.get("auditVersion")
    if not isinstance(previous_version, int) or isinstance(previous_version, bool):
        raise ParameterReachabilityError("existing auditVersion must be an integer")
    for domain in current.get("domains", []):
        for owner in domain.get("owners", []):
            if owner.get("selection") == "all":
                owner["members"] = declared_members(root, owner)
    changed = current.get("domains") != manifest.get("domains")
    if changed and version <= previous_version:
        raise ParameterReachabilityError(
            f"audited declarations changed; increment --audit-version above {previous_version}"
        )
    if not changed and version != previous_version:
        raise ParameterReachabilityError(
            f"audited declarations are unchanged; retain audit version {previous_version}"
        )
    current["auditVersion"] = version
    return current


def run_check(root: Path, output: object = sys.stdout) -> int:
    manifest = load_manifest(manifest_path(root))
    errors = validate_manifest(manifest, root)
    if not errors:
        expected = render_markdown(manifest)
        try:
            actual = report_path(root).read_text(encoding="utf-8")
        except FileNotFoundError:
            errors.append("generated parameter audit report is missing")
        else:
            if actual != expected:
                errors.append("generated parameter audit report is stale; run refresh")
    if errors:
        print(f"parameter reachability audit rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, start=1):
            print(f"  {index}. {error}", file=output)
        return 1
    member_count = sum(
        len(owner["members"])
        for domain in manifest["domains"]
        for owner in domain["owners"]
    )
    print(
        f"parameter reachability audit is current: v{manifest['auditVersion']}, "
        f"{len(manifest['domains'])} domains, {member_count} classified members",
        file=output,
    )
    return 0


def run_refresh(root: Path, version: int, output: object = sys.stdout) -> int:
    source = load_manifest(manifest_path(root))
    manifest = refreshed_manifest(source, root, version)
    errors = validate_manifest(manifest, root)
    if errors:
        raise ParameterReachabilityError("refreshed audit is invalid: " + "; ".join(errors))
    write_atomic(
        manifest_path(root), json.dumps(manifest, indent=2, ensure_ascii=True) + "\n"
    )
    write_atomic(report_path(root), render_markdown(manifest))
    print(
        f"refreshed parameter reachability audit v{version}", file=output
    )
    return 0


def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    subparsers.add_parser("check")
    refresh = subparsers.add_parser("refresh")
    refresh.add_argument("--audit-version", type=int, required=True)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = parse_arguments(argv)
    try:
        if arguments.mode == "refresh":
            return run_refresh(repository_root(), arguments.audit_version)
        return run_check(repository_root())
    except (ParameterReachabilityError, ValueError) as exc:
        print(f"parameter reachability audit error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
