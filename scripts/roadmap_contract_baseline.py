#!/usr/bin/env python3
"""Generate and verify the contracts that bound autonomous roadmap execution.

The checked-in JSON snapshot is deliberately small and fail-closed. It covers
only the authoritative product, quality, provenance, package, repository, and
semantic-map inputs an agent must reconcile before selecting roadmap work.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence


SCHEMA = "autotechno-roadmap-contract-baseline.v1"
DIGEST_ALGORITHM = "sha256"
ROOT_KEYS = {
    "schema",
    "snapshotVersion",
    "digestAlgorithm",
    "snapshotFingerprint",
    "documents",
}
DOCUMENT_KEYS = {"role", "path", "byteCount", "sha256"}
AUTHORITATIVE_DOCUMENTS = (
    ("repository-guidance", "AGENTS.md"),
    ("package-manifest", "Package.swift"),
    ("product-contract", "docs/PRODUCT.md"),
    ("sound-quality-contract", "docs/SOUND_QUALITY.md"),
    ("runtime-provenance-contract", "docs/AUTONOMOUS_RUNTIME_PROVENANCE.md"),
    (
        "component-license-asset-manifest-source",
        "docs/COMPONENT_LICENSE_ASSET_MANIFEST.json",
    ),
    (
        "component-license-asset-manifest-rendering",
        "docs/COMPONENT_LICENSE_ASSET_MANIFEST.md",
    ),
    (
        "result-status-vocabulary-source",
        "docs/RESULT_STATUS_VOCABULARY.json",
    ),
    (
        "result-status-vocabulary-rendering",
        "docs/RESULT_STATUS_VOCABULARY.md",
    ),
    (
        "controlled-listening-protocol-source",
        "docs/CONTROLLED_LISTENING_PROTOCOL.json",
    ),
    (
        "controlled-listening-protocol-rendering",
        "docs/CONTROLLED_LISTENING_PROTOCOL.md",
    ),
    (
        "baseline-lifecycle-policy-source",
        "docs/BASELINE_LIFECYCLE_POLICY.json",
    ),
    (
        "baseline-lifecycle-policy-rendering",
        "docs/BASELINE_LIFECYCLE_POLICY.md",
    ),
    (
        "source-citation-schema-source",
        "docs/SOURCE_CITATION_SCHEMA.json",
    ),
    (
        "source-citation-schema-rendering",
        "docs/SOURCE_CITATION_SCHEMA.md",
    ),
    (
        "negative-result-schema-source",
        "docs/NEGATIVE_RESULT_SCHEMA.json",
    ),
    (
        "negative-result-schema-rendering",
        "docs/NEGATIVE_RESULT_SCHEMA.md",
    ),
    (
        "baseline-corpus-source",
        "docs/BASELINE_CORPUS.json",
    ),
    (
        "baseline-corpus-rendering",
        "docs/BASELINE_CORPUS.md",
    ),
    (
        "role-stem-capture-contract",
        "docs/ROLE_STEM_CAPTURE.md",
    ),
    (
        "pcm-comparison-report-contract",
        "docs/PCM_COMPARISON_REPORT.md",
    ),
    (
        "pcm-signal-baseline-contract",
        "docs/PCM_SIGNAL_BASELINE.md",
    ),
    (
        "pcm-spectral-baseline-contract",
        "docs/PCM_SPECTRAL_BASELINE.md",
    ),
    (
        "kick-foundation-collision-baseline-contract",
        "docs/KICK_FOUNDATION_COLLISION_BASELINE.md",
    ),
    (
        "pcm-transient-envelope-baseline-contract",
        "docs/PCM_TRANSIENT_ENVELOPE_BASELINE.md",
    ),
    (
        "pcm-section-boundary-baseline-contract",
        "docs/PCM_SECTION_BOUNDARY_BASELINE.md",
    ),
    ("semantic-codebase-map-source", "docs/codebase-map.json"),
    ("semantic-codebase-map-rendering", "docs/CODEBASE_MAP.md"),
)


class RoadmapContractBaselineError(RuntimeError):
    """An actionable baseline generation or validation failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def baseline_path(root: Path) -> Path:
    return root / "docs/ROADMAP_EXECUTION_BASELINE.json"


def normalize_repo_path(value: object) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError("path must be a non-empty string")
    if "\\" in value:
        raise ValueError("path must use forward slashes")
    path = PurePosixPath(value)
    if path.is_absolute() or "." in path.parts or ".." in path.parts:
        raise ValueError("path must be repository-relative without '.' or '..'")
    return path.as_posix()


def document_record(root: Path, role: str, path: str) -> dict[str, object]:
    try:
        contents = (root / path).read_bytes()
    except FileNotFoundError as exc:
        raise RoadmapContractBaselineError(
            f"authoritative contract is missing: {path}"
        ) from exc
    return {
        "role": role,
        "path": path,
        "byteCount": len(contents),
        "sha256": hashlib.sha256(contents).hexdigest(),
    }


def snapshot_fingerprint(documents: Sequence[Mapping[str, object]]) -> str:
    canonical = json.dumps(
        list(documents),
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def capture(root: Path, snapshot_version: int) -> dict[str, object]:
    if isinstance(snapshot_version, bool) or snapshot_version < 1:
        raise RoadmapContractBaselineError("snapshot version must be a positive integer")
    documents = [
        document_record(root, role, path)
        for role, path in AUTHORITATIVE_DOCUMENTS
    ]
    return {
        "schema": SCHEMA,
        "snapshotVersion": snapshot_version,
        "digestAlgorithm": DIGEST_ALGORITHM,
        "snapshotFingerprint": snapshot_fingerprint(documents),
        "documents": documents,
    }


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RoadmapContractBaselineError(
            "roadmap execution baseline is missing; run "
            "python3 scripts/roadmap_contract_baseline.py generate --snapshot-version 1"
        ) from exc
    except json.JSONDecodeError as exc:
        raise RoadmapContractBaselineError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RoadmapContractBaselineError("baseline root must be a JSON object")
    return value


def validate_manifest(
    manifest: Mapping[str, Any], *, require_authoritative_set: bool = True
) -> list[str]:
    errors: list[str] = []
    unknown_root = sorted(set(manifest) - ROOT_KEYS)
    missing_root = sorted(ROOT_KEYS - set(manifest))
    if unknown_root:
        errors.append(f"baseline has unknown fields: {', '.join(unknown_root)}")
    if missing_root:
        errors.append(f"baseline is missing fields: {', '.join(missing_root)}")
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if manifest.get("digestAlgorithm") != DIGEST_ALGORITHM:
        errors.append(f"digestAlgorithm must be {DIGEST_ALGORITHM}")
    version = manifest.get("snapshotVersion")
    if isinstance(version, bool) or not isinstance(version, int) or version < 1:
        errors.append("snapshotVersion must be a positive integer")

    documents = manifest.get("documents")
    if not isinstance(documents, list):
        errors.append("documents must be an array")
        return errors

    expected = list(AUTHORITATIVE_DOCUMENTS)
    actual: list[tuple[object, object]] = []
    normalized_documents: list[Mapping[str, object]] = []
    for index, document in enumerate(documents):
        prefix = f"documents[{index}]"
        if not isinstance(document, dict):
            errors.append(f"{prefix} must be an object")
            continue
        normalized_documents.append(document)
        unknown = sorted(set(document) - DOCUMENT_KEYS)
        missing = sorted(DOCUMENT_KEYS - set(document))
        if unknown:
            errors.append(f"{prefix} has unknown fields: {', '.join(unknown)}")
        if missing:
            errors.append(f"{prefix} is missing fields: {', '.join(missing)}")
        role = document.get("role")
        path = document.get("path")
        actual.append((role, path))
        if not isinstance(role, str) or not role:
            errors.append(f"{prefix}.role must be a non-empty string")
        try:
            normalize_repo_path(path)
        except ValueError as exc:
            errors.append(f"{prefix}.path {exc}")
        byte_count = document.get("byteCount")
        if (
            isinstance(byte_count, bool)
            or not isinstance(byte_count, int)
            or byte_count < 0
        ):
            errors.append(f"{prefix}.byteCount must be a non-negative integer")
        digest = document.get("sha256")
        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(character not in "0123456789abcdef" for character in digest)
        ):
            errors.append(f"{prefix}.sha256 must be 64 lowercase hexadecimal digits")

    if require_authoritative_set and actual != expected:
        expected_text = ", ".join(path for _, path in expected)
        actual_text = ", ".join(
            path if isinstance(path, str) else repr(path) for _, path in actual
        )
        errors.append(
            "documents must name the exact authoritative set in canonical order; "
            f"expected [{expected_text}], found [{actual_text}]"
        )

    fingerprint = manifest.get("snapshotFingerprint")
    if (
        not isinstance(fingerprint, str)
        or len(fingerprint) != 64
        or any(character not in "0123456789abcdef" for character in fingerprint)
    ):
        errors.append("snapshotFingerprint must be 64 lowercase hexadecimal digits")
    elif len(normalized_documents) == len(documents):
        calculated = snapshot_fingerprint(normalized_documents)
        if fingerprint != calculated:
            errors.append(
                "snapshotFingerprint does not match the canonical document records"
            )
    return errors


def compare_to_repository(
    manifest: Mapping[str, Any], root: Path
) -> list[str]:
    documents = manifest.get("documents")
    if not isinstance(documents, list):
        return []
    errors: list[str] = []
    for document in documents:
        if not isinstance(document, dict) or not isinstance(document.get("path"), str):
            continue
        path = document["path"]
        try:
            current = document_record(root, str(document.get("role", "")), path)
        except RoadmapContractBaselineError:
            errors.append(f"contract drift: {path} is missing")
            continue
        expected_count = document.get("byteCount")
        expected_digest = document.get("sha256")
        if current["byteCount"] != expected_count or current["sha256"] != expected_digest:
            errors.append(
                f"contract drift: {path} "
                f"(expected bytes={expected_count} sha256={expected_digest}; "
                f"actual bytes={current['byteCount']} sha256={current['sha256']})"
            )
    return errors


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


def run_check(root: Path, output: object = sys.stdout) -> int:
    manifest = load_manifest(baseline_path(root))
    errors = validate_manifest(manifest)
    if not errors:
        errors.extend(compare_to_repository(manifest, root))
    if errors:
        print(
            f"roadmap contract baseline rejected execution with {len(errors)} issue(s):",
            file=output,
        )
        for index, error in enumerate(errors, start=1):
            print(f"  {index}. {error}", file=output)
        return 1
    print(
        "roadmap contract baseline is compatible: "
        f"snapshot v{manifest['snapshotVersion']} "
        f"({manifest['snapshotFingerprint']})",
        file=output,
    )
    return 0


def run_generate(
    root: Path, snapshot_version: int, output: object = sys.stdout
) -> int:
    destination = baseline_path(root)
    generated = capture(root, snapshot_version)
    if destination.exists():
        existing = load_manifest(destination)
        # A deliberate authoritative-set expansion makes the previous snapshot
        # incompatible with `check`, but it must still be structurally valid so
        # an explicitly incremented snapshot can migrate it without deleting or
        # hand-editing the protected file first.
        errors = validate_manifest(existing, require_authoritative_set=False)
        if errors:
            raise RoadmapContractBaselineError(
                "existing baseline is invalid and will not be overwritten: "
                + "; ".join(errors)
            )
        existing_version = existing["snapshotVersion"]
        content_changed = existing["documents"] != generated["documents"]
        if content_changed and snapshot_version <= existing_version:
            raise RoadmapContractBaselineError(
                "authoritative contract content changed; increment --snapshot-version "
                f"above {existing_version} before replacing the baseline"
            )
        if not content_changed and snapshot_version != existing_version:
            raise RoadmapContractBaselineError(
                "authoritative contract content is unchanged; retain snapshot version "
                f"{existing_version}"
            )
    rendered = json.dumps(generated, indent=2, ensure_ascii=True) + "\n"
    write_atomic(destination, rendered)
    print(
        f"generated {destination.relative_to(root)} snapshot v{snapshot_version}",
        file=output,
    )
    return 0


def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    generate = subparsers.add_parser("generate")
    generate.add_argument("--snapshot-version", type=int, required=True)
    subparsers.add_parser("check")
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = parse_arguments(argv)
    try:
        if arguments.mode == "generate":
            return run_generate(
                repository_root(), arguments.snapshot_version, output=sys.stdout
            )
        return run_check(repository_root(), output=sys.stdout)
    except RoadmapContractBaselineError as exc:
        print(f"roadmap contract baseline error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
