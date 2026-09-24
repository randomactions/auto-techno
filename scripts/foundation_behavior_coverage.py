#!/usr/bin/env python3
"""Verify score-derived foundation-behavior coverage bound to exact local audio."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Mapping, Optional, Sequence, TextIO

import baseline_render_manifest
import stem_capture_manifest


SCHEMA = "autotechno-foundation-behavior-coverage.v1"
BEHAVIORS = (
    "subPulse", "monotone", "point", "pump", "kickTail",
    "tunedPercussive", "absent",
)
ROOT_KEYS = {
    "schema", "manifestVersion", "corpusSha256", "wholeMixManifestSha256",
    "roleStemManifestSha256", "contractBaselineFingerprint",
    "sourceFingerprint", "gitHead", "engineVersion", "entries",
}
ENTRY_KEYS = {
    "id", "caseId", "routeId", "rootSeed", "checkpoint",
    "continuationClass", "phraseIndex", "startBar", "phraseKind",
    "stateFingerprint", "planFingerprint", "replayFingerprint",
    "policyVersion", "qualityOutcome", "sampleRate", "wholeMixPcmSha256",
    "resolvedBarCount", "foundationBehaviorBarCounts",
}


class CoverageError(RuntimeError):
    """An actionable score-coverage evidence failure."""


def coverage_path(root: Path, namespace: Optional[str] = None) -> Path:
    selected = stem_capture_manifest.capture_namespace(namespace)
    return root / f"docs/local/reports/baseline-stems-{selected}/foundation-behavior-coverage.json"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_coverage(
    coverage: Mapping[str, Any],
    whole: Mapping[str, Any],
    stems: Mapping[str, Any],
    *,
    corpus_sha256: str,
    whole_manifest_sha256: str,
    stems_manifest_sha256: str,
) -> list[str]:
    errors: list[str] = []
    if set(coverage) != ROOT_KEYS:
        errors.append("coverage manifest has an invalid root field set")
    if coverage.get("schema") != SCHEMA or coverage.get("manifestVersion") != 1:
        errors.append("coverage schema/version is unsupported")
    root_bindings = {
        "corpusSha256": corpus_sha256,
        "wholeMixManifestSha256": whole_manifest_sha256,
        "roleStemManifestSha256": stems_manifest_sha256,
    }
    for field, expected in root_bindings.items():
        if coverage.get(field) != expected:
            errors.append(f"{field} does not bind the exact source manifest")
    if coverage.get("corpusSha256") != whole.get("corpusSha256") or coverage.get("corpusSha256") != stems.get("corpusSha256"):
        errors.append("corpusSha256 differs across capture manifests")
    if stems.get("wholeMixManifestSha256") != whole_manifest_sha256:
        errors.append("role-stem manifest does not bind the exact whole-mix manifest")
    for field in (
        "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
        "engineVersion",
    ):
        if coverage.get(field) != whole.get(field) or coverage.get(field) != stems.get(field):
            errors.append(f"{field} differs across capture manifests")

    whole_entries = whole.get("entries")
    stem_entries = stems.get("entries")
    entries = coverage.get("entries")
    if not all(isinstance(value, list) for value in (whole_entries, stem_entries, entries)):
        return errors + ["all three manifests must contain entry arrays"]
    whole_by_id = {
        item["id"]: item for item in whole_entries
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    stems_by_id = {
        item["id"]: item for item in stem_entries
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    seen: set[str] = set()
    coverage_ids = [item.get("id") for item in entries if isinstance(item, dict)]
    if not all(isinstance(identifier, str) for identifier in coverage_ids):
        errors.append("coverage entries must have string ids")
    elif coverage_ids != sorted(coverage_ids):
        errors.append("coverage entries must be sorted by id")
    for index, item in enumerate(entries):
        where = f"entries[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{where} must be an object")
            continue
        if set(item) != ENTRY_KEYS:
            errors.append(f"{where} has an invalid field set")
        identifier = item.get("id")
        if not isinstance(identifier, str) or identifier in seen:
            errors.append(f"{where}.id must be unique text")
            continue
        seen.add(identifier)
        whole_entry = whole_by_id.get(identifier)
        stem_entry = stems_by_id.get(identifier)
        if whole_entry is None or stem_entry is None:
            errors.append(f"{where}.id is not paired across whole mix and stems")
            continue
        bindings = {
            "caseId": "caseId", "routeId": "routeId", "rootSeed": "rootSeed",
            "checkpoint": "checkpoint", "continuationClass": "continuationClass",
            "phraseIndex": "phraseIndex", "startBar": "startBar",
            "phraseKind": "phraseKind", "stateFingerprint": "stateFingerprint",
            "planFingerprint": "planFingerprint", "replayFingerprint": "replayFingerprint",
            "policyVersion": "policyVersion", "qualityOutcome": "qualityOutcome",
            "sampleRate": "sampleRate",
        }
        for field, source_field in bindings.items():
            if item.get(field) != whole_entry.get(source_field) or item.get(field) != stem_entry.get(source_field):
                errors.append(f"{where}.{field} differs from paired capture")
        pcm_hash = whole_entry.get("pcmSha256")
        if item.get("wholeMixPcmSha256") != pcm_hash or item.get("wholeMixPcmSha256") != stem_entry.get("wholeMixPcmSha256"):
            errors.append(f"{where}.wholeMixPcmSha256 differs from exact paired PCM")
        bar_count = item.get("resolvedBarCount")
        counts = item.get("foundationBehaviorBarCounts")
        if isinstance(bar_count, bool) or not isinstance(bar_count, int) or not 1 <= bar_count <= 16:
            errors.append(f"{where}.resolvedBarCount must be in 1...16")
        if not isinstance(counts, dict) or set(counts) != set(BEHAVIORS):
            errors.append(f"{where}.foundationBehaviorBarCounts must name all seven behaviors")
            continue
        valid_counts = True
        for behavior in BEHAVIORS:
            count = counts[behavior]
            if isinstance(count, bool) or not isinstance(count, int) or count < 0:
                errors.append(f"{where}.{behavior} count must be a non-negative integer")
                valid_counts = False
        if valid_counts and isinstance(bar_count, int) and sum(counts.values()) != bar_count:
            errors.append(f"{where} behavior counts do not sum to resolvedBarCount")
    expected_ids = set(whole_by_id)
    if seen != expected_ids or set(stems_by_id) != expected_ids:
        errors.append("coverage, whole-mix, and stem entry identities differ")
    return errors


def load_object(path: Path, label: str) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CoverageError(f"cannot read {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise CoverageError(f"{label} must be a JSON object")
    return value


def validate(
    root: Path,
    namespace: Optional[str] = None,
    corpus_relative_path: Optional[str] = None,
) -> list[str]:
    try:
        namespace = stem_capture_manifest.capture_namespace(namespace)
        selected_corpus = stem_capture_manifest.resolve_corpus_path(
            root, corpus_relative_path
        )
        whole_path = baseline_render_manifest.manifest_path(root, namespace)
        stems_path = stem_capture_manifest.manifest_path(root, namespace)
        coverage = load_object(coverage_path(root, namespace), "coverage manifest")
        whole = load_object(whole_path, "whole-mix manifest")
        stems = load_object(stems_path, "role-stem manifest")
        corpus_sha = sha256_bytes(selected_corpus.read_bytes())
        whole_bytes = whole_path.read_bytes()
        stems_bytes = stems_path.read_bytes()
    except (
        CoverageError,
        baseline_render_manifest.BaselineRenderManifestError,
        stem_capture_manifest.StemCaptureManifestError,
        OSError,
    ) as exc:
        return [str(exc)]
    errors = validate_coverage(
        coverage, whole, stems,
        corpus_sha256=corpus_sha,
        whole_manifest_sha256=sha256_bytes(whole_bytes),
        stems_manifest_sha256=sha256_bytes(stems_bytes),
    )
    if not errors:
        errors.extend("whole-mix: " + item for item in baseline_render_manifest.validate(root, namespace, corpus_relative_path))
        errors.extend("role-stems: " + item for item in stem_capture_manifest.validate(root, namespace, corpus_relative_path))
    return errors


def run_check(
    root: Path,
    output: TextIO = sys.stdout,
    namespace: Optional[str] = None,
    corpus_relative_path: Optional[str] = None,
) -> int:
    errors = validate(root, namespace, corpus_relative_path)
    if errors:
        print(f"foundation behavior coverage rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, 1):
            print(f"  {index}. {error}", file=output)
        return 1
    print("foundation behavior coverage is current and bound to exact whole-mix/stem manifests", file=output)
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check",))
    parser.add_argument("--namespace", help="select an isolated capture namespace (default: v1)")
    parser.add_argument("--corpus", help="relative canonical or docs/local corpus path")
    arguments = parser.parse_args(argv)
    if arguments.command == "check":
        return run_check(
            baseline_render_manifest.repository_root(),
            namespace=arguments.namespace,
            corpus_relative_path=arguments.corpus,
        )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
