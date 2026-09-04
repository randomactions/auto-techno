#!/usr/bin/env python3
"""Validate and render the compact deterministic Phase-1 baseline corpus."""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any, Mapping, Optional, Sequence, TextIO


SCHEMA = "autotechno-baseline-corpus.v1"
MASK_64 = (1 << 64) - 1
DOMAIN_KEY_HEX = "6175746f74656368"
INCREMENT_HEX = "9e3779b97f4a7c15"
CHECKPOINTS = (
    "establishment",
    "chapter-change",
    "contrast",
    "major-break",
    "release",
    "identity-return",
    "long-continuation",
)
PHRASE_KINDS = ("lock", "contrast", "majorBreak", "energyRelease", "identityReturn")
CONTINUATION_CLASSES = ("initial", "advanced", "long")
ROOT_KEYS = {
    "schema", "corpusVersion", "purpose", "selectionPolicy",
    "checkpointPolicy", "routes", "cases", "requiredCoverage", "scope",
}
SELECTION_KEYS = {
    "algorithm", "domainKeyHex", "incrementHex", "outputMapping",
    "selectionCount", "selectionOrder", "biasGuard",
}
CHECKPOINT_POLICY_KEYS = {"maximumPhrases", "selection", "advancement"}
ROUTE_KEYS = {
    "id", "sampleRate", "channelCount", "routeGeneration", "routeRecovery",
}
CASE_KEYS = {"id", "ordinal", "rootSeed", "checkpoint", "continuationClass"}
COVERAGE_KEYS = {
    "checkpoints", "phraseKinds", "continuationClasses", "sampleRates",
    "channelCounts",
}


class BaselineCorpusError(RuntimeError):
    """An actionable corpus validation failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def manifest_path(root: Path) -> Path:
    return root / "docs/BASELINE_CORPUS.json"


def report_path(root: Path) -> Path:
    return root / "docs/BASELINE_CORPUS.md"


def load_manifest(path: Path) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BaselineCorpusError(f"cannot read corpus manifest: {exc}") from exc
    if not isinstance(value, dict):
        raise BaselineCorpusError("corpus manifest must contain one JSON object")
    return value


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    actual = set(value)
    if actual != expected:
        errors.append(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(actual)}"
        )


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def splitmix64_seed(ordinal: int) -> int:
    value = (
        int(DOMAIN_KEY_HEX, 16)
        + (ordinal + 1) * int(INCREMENT_HEX, 16)
    ) & MASK_64
    value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & MASK_64
    value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & MASK_64
    return (value ^ (value >> 31)) & MASK_64


def expected_case_id(ordinal: int, checkpoint: str) -> str:
    return f"ATBC-V1-{ordinal:03d}-{checkpoint.upper()}"


def expected_continuation(checkpoint: str) -> str:
    if checkpoint == "establishment":
        return "initial"
    if checkpoint == "long-continuation":
        return "long"
    return "advanced"


def validate_manifest(manifest: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    exact_keys(manifest, ROOT_KEYS, "manifest", errors)
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if manifest.get("corpusVersion") != 1:
        errors.append("corpusVersion must be 1")
    for field in ("purpose", "scope"):
        if not nonempty(manifest.get(field)):
            errors.append(f"{field} must be a non-empty string")

    selection = manifest.get("selectionPolicy")
    if not isinstance(selection, dict):
        errors.append("selectionPolicy must be an object")
        selection = {}
    exact_keys(selection, SELECTION_KEYS, "selectionPolicy", errors)
    expected_selection = {
        "algorithm": "splitmix64-domain-sequence.v1",
        "domainKeyHex": DOMAIN_KEY_HEX,
        "incrementHex": INCREMENT_HEX,
        "outputMapping": (
            "rootSeed=mix(domainKey+(ordinal+1)*increment modulo 2^64)"
        ),
        "selectionCount": len(CHECKPOINTS),
        "selectionOrder": "ordinal-ascending-before-any-render-or-listening",
    }
    for field, expected in expected_selection.items():
        if selection.get(field) != expected:
            errors.append(f"selectionPolicy.{field} must be {expected!r}")
    if not nonempty(selection.get("biasGuard")):
        errors.append("selectionPolicy.biasGuard must be a non-empty string")

    checkpoint_policy = manifest.get("checkpointPolicy")
    if not isinstance(checkpoint_policy, dict):
        errors.append("checkpointPolicy must be an object")
        checkpoint_policy = {}
    exact_keys(
        checkpoint_policy, CHECKPOINT_POLICY_KEYS, "checkpointPolicy", errors
    )
    if checkpoint_policy.get("maximumPhrases") != 128:
        errors.append("checkpointPolicy.maximumPhrases must be 128")
    if checkpoint_policy.get("selection") != "first-canonical-occurrence":
        errors.append("checkpointPolicy.selection must be first-canonical-occurrence")
    if checkpoint_policy.get("advancement") != (
        "AutonomousSessionDirector.plan then "
        "AutonomousSessionState.advancePlanning"
    ):
        errors.append("checkpointPolicy.advancement is not canonical")

    routes = manifest.get("routes")
    if not isinstance(routes, list):
        errors.append("routes must be an array")
        routes = []
    expected_routes = (
        ("native-stereo-44100", 44_100),
        ("native-stereo-48000", 48_000),
    )
    route_ids: set[str] = set()
    for index, route in enumerate(routes):
        location = f"routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(route, ROUTE_KEYS, location, errors)
        if index >= len(expected_routes):
            errors.append(f"{location} is an unsupported extra route")
            continue
        expected_id, expected_rate = expected_routes[index]
        if route.get("id") != expected_id:
            errors.append(f"{location}.id must be {expected_id}")
        if route.get("sampleRate") != expected_rate:
            errors.append(f"{location}.sampleRate must be {expected_rate}")
        if route.get("channelCount") != 2:
            errors.append(f"{location}.channelCount must be 2")
        if route.get("routeGeneration") != 0:
            errors.append(f"{location}.routeGeneration must be 0")
        if route.get("routeRecovery") is not False:
            errors.append(f"{location}.routeRecovery must be false")
        route_id = route.get("id")
        if isinstance(route_id, str) and route_id in route_ids:
            errors.append(f"duplicate route id {route_id}")
        elif isinstance(route_id, str):
            route_ids.add(route_id)
    if len(routes) != len(expected_routes):
        errors.append(f"routes must contain exactly {len(expected_routes)} entries")

    cases = manifest.get("cases")
    if not isinstance(cases, list):
        errors.append("cases must be an array")
        cases = []
    case_ids: set[str] = set()
    seeds: set[int] = set()
    for index, case in enumerate(cases):
        location = f"cases[{index}]"
        if not isinstance(case, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(case, CASE_KEYS, location, errors)
        if index >= len(CHECKPOINTS):
            errors.append(f"{location} is an unsupported extra case")
            continue
        checkpoint = CHECKPOINTS[index]
        if case.get("ordinal") != index:
            errors.append(f"{location}.ordinal must be {index}")
        if case.get("checkpoint") != checkpoint:
            errors.append(f"{location}.checkpoint must be {checkpoint}")
        expected_id = expected_case_id(index, checkpoint)
        if case.get("id") != expected_id:
            errors.append(f"{location}.id must be {expected_id}")
        expected_seed = splitmix64_seed(index)
        if case.get("rootSeed") != expected_seed:
            errors.append(
                f"{location}.rootSeed must be derived value {expected_seed}"
            )
        continuation = expected_continuation(checkpoint)
        if case.get("continuationClass") != continuation:
            errors.append(
                f"{location}.continuationClass must be {continuation}"
            )
        case_id = case.get("id")
        if isinstance(case_id, str) and case_id in case_ids:
            errors.append(f"duplicate case id {case_id}")
        elif isinstance(case_id, str):
            case_ids.add(case_id)
        seed = case.get("rootSeed")
        if isinstance(seed, int) and not isinstance(seed, bool) and seed in seeds:
            errors.append(f"duplicate root seed {seed}")
        elif isinstance(seed, int) and not isinstance(seed, bool):
            seeds.add(seed)
    if len(cases) != len(CHECKPOINTS):
        errors.append(f"cases must contain exactly {len(CHECKPOINTS)} entries")

    coverage = manifest.get("requiredCoverage")
    if not isinstance(coverage, dict):
        errors.append("requiredCoverage must be an object")
        coverage = {}
    exact_keys(coverage, COVERAGE_KEYS, "requiredCoverage", errors)
    expected_coverage = {
        "checkpoints": list(CHECKPOINTS),
        "phraseKinds": list(PHRASE_KINDS),
        "continuationClasses": list(CONTINUATION_CLASSES),
        "sampleRates": [44_100, 48_000],
        "channelCounts": [2],
    }
    for field, expected in expected_coverage.items():
        if coverage.get(field) != expected:
            errors.append(f"requiredCoverage.{field} must be exactly {expected}")
    return errors


def render_markdown(manifest: Mapping[str, Any]) -> str:
    selection = manifest["selectionPolicy"]
    policy = manifest["checkpointPolicy"]
    lines = [
        "<!-- GENERATED by scripts/baseline_corpus.py; edit the JSON source. -->",
        "# Deterministic Phase-1 baseline corpus",
        "",
        f"Schema: `{manifest['schema']}`  ",
        f"Corpus version: {manifest['corpusVersion']}",
        "",
        "## Purpose",
        "",
        str(manifest["purpose"]),
        "",
        "## Selection and bias control",
        "",
        f"- Algorithm: `{selection['algorithm']}`",
        f"- Domain key: `0x{selection['domainKeyHex']}`",
        f"- Increment: `0x{selection['incrementHex']}`",
        f"- Order: `{selection['selectionOrder']}`",
        f"- Checkpoint choice: `{policy['selection']}` within "
        f"{policy['maximumPhrases']} phrases",
        f"- Bias guard: {selection['biasGuard']}",
        "",
        "## Corpus cases",
        "",
        "| Stable ID | Ordinal | Root seed | Checkpoint | Continuation |",
        "|---|---:|---:|---|---|",
    ]
    for case in manifest["cases"]:
        lines.append(
            f"| `{case['id']}` | {case['ordinal']} | `{case['rootSeed']}` | "
            f"`{case['checkpoint']}` | `{case['continuationClass']}` |"
        )
    lines.extend([
        "",
        "## Route expansion",
        "",
        "| Stable route ID | Sample rate | Channels | Generation | Recovery |",
        "|---|---:|---:|---:|---|",
    ])
    for route in manifest["routes"]:
        lines.append(
            f"| `{route['id']}` | {route['sampleRate']} Hz | "
            f"{route['channelCount']} | {route['routeGeneration']} | "
            f"`{str(route['routeRecovery']).lower()}` |"
        )
    lines.extend([
        "",
        "Each musical case expands over both route rows, producing 14 planned "
        "baseline render identities without changing musical selection by route.",
        "",
        "## Required current-behaviour coverage",
        "",
    ])
    for field, values in manifest["requiredCoverage"].items():
        lines.append(f"- `{field}`: " + ", ".join(f"`{value}`" for value in values))
    lines.extend([
        "",
        "Swift tests advance the real director to the first declared checkpoint, "
        "verify initial/advanced/long continuation semantics, and require all five "
        "current phrase kinds across the selected states. The JSON deliberately "
        "contains no PCM, verdict, metric, rank, or listening-result field.",
        "",
        "## Scope",
        "",
        str(manifest["scope"]),
        "",
        "## Maintenance",
        "",
        "```bash",
        "python3 scripts/baseline_corpus.py check",
        "swift test --filter BaselineCorpusTests",
        "```",
        "",
    ])
    return "\n".join(lines)


def write_atomic(path: Path, contents: str) -> None:
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


def run_generate(root: Path, output: TextIO = sys.stdout) -> int:
    manifest = load_manifest(manifest_path(root))
    errors = validate_manifest(manifest)
    if errors:
        raise BaselineCorpusError("invalid corpus: " + "; ".join(errors))
    write_atomic(report_path(root), render_markdown(manifest))
    print("generated deterministic baseline corpus v1: 7 cases, 2 routes", file=output)
    return 0


def run_check(root: Path, output: TextIO = sys.stdout) -> int:
    try:
        manifest = load_manifest(manifest_path(root))
    except BaselineCorpusError as exc:
        print(f"baseline corpus: {exc}", file=output)
        return 1
    errors = validate_manifest(manifest)
    if not errors:
        expected = render_markdown(manifest)
        try:
            actual = report_path(root).read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(f"cannot read generated report: {exc}")
        else:
            if actual != expected:
                errors.append("generated Markdown is stale; run generate")
    if errors:
        print(f"baseline corpus rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, start=1):
            print(f"  {index}. {error}", file=output)
        return 1
    print("baseline corpus is current: v1, 7 cases, 2 routes, 14 identities", file=output)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("generate", "check"))
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = build_parser().parse_args(argv)
    root = repository_root()
    if arguments.command == "generate":
        return run_generate(root)
    return run_check(root)


if __name__ == "__main__":
    raise SystemExit(main())
