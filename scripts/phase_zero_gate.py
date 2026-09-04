#!/usr/bin/env python3
"""Generate the fail-closed Auto Techno phase-0 coherence gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Mapping, Optional, Sequence, TextIO


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import roadmap_integrity  # noqa: E402


SCHEMA = "autotechno-phase-zero-gate.v1"
CHECKS = (
    ("contract-baseline", "roadmap_contract_baseline.py", "check"),
    ("parameter-reachability", "parameter_reachability_audit.py", "check"),
    ("authority-inventory", "authority_surface_inventory.py", "check"),
    ("component-provenance", "component_license_asset_manifest.py", "check"),
    ("roadmap-integrity", "roadmap_integrity.py", "check"),
    ("result-vocabulary", "result_status_vocabulary.py", "check"),
    ("source-citation-schema", "source_citation_records.py", "check"),
    ("active-source-citations", "source_citation_records.py", "check-active"),
    ("negative-result-schema", "negative_result_records.py", "check"),
    ("local-artifact-layout", "local_artifact_doctor.py", "check"),
)
Runner = Callable[..., subprocess.CompletedProcess[str]]


class PhaseZeroGateError(RuntimeError):
    """An actionable subordinate or phase-gate failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def report_json_path(root: Path) -> Path:
    return root / "docs/PHASE_ZERO_GATE.json"


def report_markdown_path(root: Path) -> Path:
    return root / "docs/PHASE_ZERO_GATE.md"


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PhaseZeroGateError(f"cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PhaseZeroGateError(f"{path} must contain one JSON object")
    return value


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_checks(root: Path, runner: Runner = subprocess.run) -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    for identifier, script, command in CHECKS:
        result = runner(
            [sys.executable, str(root / "scripts" / script), command],
            cwd=root,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        if result.returncode != 0:
            diagnostic = (result.stdout or "").strip()
            raise PhaseZeroGateError(
                f"subordinate check failed: {identifier}: {diagnostic or 'no diagnostic'}"
            )
        results.append({
            "id": identifier,
            "command": f"python3 scripts/{script} {command}",
            "status": "passed",
        })
    return results


def analyze_authorities(root: Path) -> tuple[list[dict[str, Any]], dict[str, int]]:
    reach_path = root / "docs/PARAMETER_REACHABILITY_AUDIT.json"
    authority_path = root / "docs/AUTHORITY_SURFACE_INVENTORY.json"
    component_path = root / "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json"
    roadmap_path = root / roadmap_integrity.ROADMAP_PATH
    reach = load_json(reach_path)
    authority = load_json(authority_path)
    component = load_json(component_path)
    try:
        roadmap_text = roadmap_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise PhaseZeroGateError(f"cannot read {roadmap_path}: {exc}") from exc

    total_members = 0
    unowned_active: list[str] = []
    for domain in reach.get("domains", []):
        if not isinstance(domain, dict):
            continue
        members = [
            member
            for owner in domain.get("owners", [])
            if isinstance(owner, dict)
            for member in owner.get("members", [])
        ]
        total_members += len(members)
        classification = domain.get("classification")
        if isinstance(classification, str) and classification.startswith("active-"):
            pcm = domain.get("pcmEvidence", {})
            signal = domain.get("signalEvidence", {})
            future = domain.get("futureDecision", {})
            if (
                not domain.get("owners")
                or not domain.get("consumerAnchors")
                or not isinstance(pcm, dict)
                or pcm.get("status") in {None, "quarantined-no-pcm"}
                or not isinstance(signal, dict)
                or signal.get("status") in {None, "unavailable-quarantined"}
                or not isinstance(future, dict)
                or future.get("status") in {None, "quarantined"}
            ):
                unowned_active.append(str(domain.get("id", "<unknown>")))

    authority_groups = [
        group
        for key in ("authorityGroups", "profileGroups")
        for group in authority.get(key, [])
        if isinstance(group, dict)
    ]
    effect_paths = [
        path for path in authority.get("effectPaths", []) if isinstance(path, dict)
    ]
    unresolved_authority = [
        str(group.get("id", "<unknown>"))
        for group in authority_groups
        if not group.get("canonicalComponent")
        or not group.get("convergenceAnchors")
        or not group.get("evidenceAnchors")
    ]
    unresolved_authority.extend(
        str(path.get("id", "<unknown>"))
        for path in effect_paths
        if not path.get("canonicalComponent")
        or not path.get("convergenceAnchors")
        or not path.get("evidenceAnchors")
    )

    component_findings = [
        finding
        for finding in component.get("reviewFindings", [])
        if isinstance(finding, dict)
    ]
    unresolved_components = [
        str(finding.get("id", "<unknown>"))
        for finding in component_findings
        if finding.get("severity") in {"yellow", "red"}
    ]
    unresolved_components.extend(
        str(entry.get("id", "<unknown>"))
        for entry in component.get("components", [])
        if isinstance(entry, dict)
        and (
            not str(entry.get("provenanceClass", "")).startswith("GREEN-")
            or entry.get("disposition") == "remediate-at-0008"
        )
    )

    roadmap_errors = roadmap_integrity.validate_roadmap(roadmap_text, root)
    roadmap_items, _ = roadmap_integrity.parse_items(roadmap_text)
    unresolved_counts = {
        "unownedActiveParameters": len(unowned_active),
        "unresolvedDuplicateAuthorities": len(unresolved_authority),
        "invalidRoadmapInvariants": len(roadmap_errors),
        "unresolvedComponentFindings": len(unresolved_components),
    }
    unresolved_details = (
        unowned_active + unresolved_authority + roadmap_errors + unresolved_components
    )
    if unresolved_details:
        raise PhaseZeroGateError(
            "unresolved phase-0 findings: " + "; ".join(unresolved_details)
        )

    authorities = [
        {
            "id": "parameter-reachability",
            "artifact": "docs/PARAMETER_REACHABILITY_AUDIT.json",
            "schema": str(reach.get("schema")),
            "version": int(reach.get("auditVersion", 0)),
            "sha256": file_sha256(reach_path),
            "surfaceCount": total_members,
            "unresolvedCount": 0,
        },
        {
            "id": "authority-convergence",
            "artifact": "docs/AUTHORITY_SURFACE_INVENTORY.json",
            "schema": str(authority.get("schema")),
            "version": int(authority.get("inventoryVersion", 0)),
            "sha256": file_sha256(authority_path),
            "surfaceCount": len(authority_groups) + len(effect_paths),
            "unresolvedCount": 0,
        },
        {
            "id": "component-provenance",
            "artifact": "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json",
            "schema": str(component.get("schema")),
            "version": int(component.get("manifestVersion", 0)),
            "sha256": file_sha256(component_path),
            "surfaceCount": len(component.get("components", [])),
            "unresolvedCount": 0,
        },
        {
            "id": "roadmap-integrity",
            "artifact": roadmap_integrity.ROADMAP_PATH.as_posix(),
            "schema": "autotechno-evolution.v1",
            "version": 1,
            "sha256": "local-revision-bound-by-active-citation",
            "surfaceCount": len(roadmap_items),
            "unresolvedCount": 0,
        },
    ]
    return authorities, unresolved_counts


def build_report(root: Path, runner: Runner = subprocess.run) -> dict[str, Any]:
    checks = run_checks(root, runner)
    authorities, unresolved = analyze_authorities(root)
    return {
        "schema": SCHEMA,
        "gateVersion": 1,
        "status": "passed",
        "authorities": authorities,
        "checks": checks,
        "unresolved": unresolved,
        "scope": "Phase 0 structural governance and provenance only; no app, route, listening, or physical-output qualification claim.",
    }


def render_markdown(report: Mapping[str, Any]) -> str:
    lines = [
        "# Phase-0 Coherence Gate",
        "",
        "> Generated from current subordinate authorities by `scripts/phase_zero_gate.py`; do not edit by hand.",
        "",
        f"Status: **{report['status']}**",
        "",
        report["scope"],
        "",
        "## Authority summary",
        "",
        "| Authority | Schema/version | Surfaces | Unresolved | Artifact SHA-256 |",
        "|---|---|---:|---:|---|",
    ]
    for authority in report["authorities"]:
        lines.append(
            f"| `{authority['id']}` | `{authority['schema']}` v{authority['version']} | "
            f"{authority['surfaceCount']} | {authority['unresolvedCount']} | "
            f"`{authority['sha256']}` |"
        )
    lines.extend([
        "",
        "## Subordinate checks",
        "",
        "| Check | Command | Status |",
        "|---|---|---|",
    ])
    for check in report["checks"]:
        lines.append(
            f"| `{check['id']}` | `{check['command']}` | `{check['status']}` |"
        )
    lines.extend(["", "## Unresolved counts", ""])
    for key, value in report["unresolved"].items():
        lines.append(f"- `{key}`: {value}")
    lines.append("")
    return "\n".join(lines)


def canonical_json(report: Mapping[str, Any]) -> str:
    return json.dumps(report, indent=2) + "\n"


def run_generate(
    root: Path, output: TextIO, runner: Runner = subprocess.run
) -> int:
    report = build_report(root, runner)
    report_json_path(root).write_text(canonical_json(report), encoding="utf-8")
    report_markdown_path(root).write_text(render_markdown(report), encoding="utf-8")
    print("generated phase-0 coherence gate v1: passed", file=output)
    return 0


def run_check(root: Path, output: TextIO, runner: Runner = subprocess.run) -> int:
    try:
        report = build_report(root, runner)
    except PhaseZeroGateError as exc:
        print(f"phase-0 gate: {exc}", file=output)
        return 1
    expected_json = canonical_json(report)
    expected_markdown = render_markdown(report)
    try:
        actual_json = report_json_path(root).read_text(encoding="utf-8")
        actual_markdown = report_markdown_path(root).read_text(encoding="utf-8")
    except OSError as exc:
        print(f"phase-0 gate: cannot read generated report: {exc}", file=output)
        return 1
    errors: list[str] = []
    if actual_json != expected_json:
        errors.append("generated JSON is stale")
    if actual_markdown != expected_markdown:
        errors.append("generated Markdown is stale")
    if errors:
        for error in errors:
            print(f"phase-0 gate: {error}; run generate", file=output)
        return 1
    print("phase-0 coherence gate is current: passed, 0 unresolved findings", file=output)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("generate", "check"))
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = build_parser().parse_args(argv)
    root = repository_root()
    if arguments.command == "generate":
        return run_generate(root, sys.stdout)
    return run_check(root, sys.stdout)


if __name__ == "__main__":
    raise SystemExit(main())
