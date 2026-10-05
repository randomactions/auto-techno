#!/usr/bin/env python3
"""Generate and validate Phase-1 baseline lifecycle and migration policy."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence


SCHEMA = "autotechno-baseline-lifecycle-policy.v1"
POLICY_VERSION = 1
ENVELOPE_SCHEMA = "autotechno-baseline-identity-envelope.v1"
ASSESSMENT_SCHEMA = "autotechno-baseline-lifecycle-assessment.v2"
VERIFICATION_SCHEMA = "autotechno-baseline-current-verification.v1"
VERIFICATION_KEYS = {
    "schema", "familyId", "originGitHead", "originSnapshotFingerprint",
    "originContractBaselineFingerprint", "originSourceFingerprint",
    "validationFingerprint", "currentGitHead", "currentSnapshotFingerprint",
    "currentContractBaselineFingerprint", "artifactSha256", "action",
    "currentCaptureContextFingerprint", "currentSourceFreezeFingerprint",
    "currentProbePath", "currentProbeSha256", "currentProbeDiagnosticSha256",
    "currentProbeInvocationFingerprint",
    "currentProbeActualArgumentsFingerprint",
    "qualification", "verificationFingerprint",
}
RETAINED_FAMILIES = {"whole-mix-render", "role-stem-capture"}
POLICY_PATH = Path("docs/BASELINE_LIFECYCLE_POLICY.json")
MARKDOWN_PATH = Path("docs/BASELINE_LIFECYCLE_POLICY.md")
BASELINE_PATH = Path("docs/ROADMAP_EXECUTION_BASELINE.json")
CORPUS_PATH = Path("docs/BASELINE_CORPUS.json")
HEX64 = re.compile(r"[0-9a-f]{64}")
NODE_ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
SCHEMA_ID = re.compile(r"autotechno-[a-z0-9-]+\.v[1-9][0-9]*")

ROOT_KEYS = {
    "schema", "policyVersion", "policyFingerprint", "states",
    "comparisonRules", "limits", "registeredMigrations", "nodes",
    "qualification",
}
COMPARISON_KEYS = {
    "identityEnvelopeSchema", "immutableComparisonDimensions",
    "explicitDifferenceDimensions", "schemaTransitionRule", "exactPCMRule",
}
LIMIT_KEYS = {
    "maximumNodes", "maximumDependenciesPerNode", "maximumFieldPathsPerNode",
    "maximumMigrations", "maximumCommandCharacters", "maximumTextCharacters",
}
QUALIFICATION_KEYS = {
    "runtimeInput", "promotionAuthorized", "validatorRequiredForCurrentClaim",
    "rawArtifactsTracked", "purpose",
}
NODE_KEYS = {
    "id", "label", "artifactPath", "artifactClass", "schema",
    "versionField", "version", "artifactFingerprintField",
    "contractFingerprintFields", "sourceFingerprintFields",
    "corpusFingerprintFields", "engineVersionFields",
    "buildConfigurationFields", "routeIdentityFields", "dependencies",
    "producerCommand", "validatorCommand", "changeTriggers", "comparisonMode",
}
MIGRATION_KEYS = {
    "familyId", "sourceSchema", "sourceVersion", "targetSchema",
    "targetVersion", "compatibility", "transformer", "postValidator",
}
ENVELOPE_KEYS = {
    "schema", "familyId", "artifactSchema", "artifactVersion",
    "artifactFingerprint", "contractBaselineFingerprint", "sourceFingerprint",
    "corpusSha256", "engineVersion", "buildConfiguration", "routeIdentity",
}
ASSESSMENT_KEYS = {
    "schema", "policyFingerprint", "contractBaselineFingerprint",
    "corpusSha256", "regenerationOrder", "nodes", "summary",
    "qualification", "assessmentFingerprint",
}

STATES = [
    "current-metadata",
    "comparable",
    "migration-required",
    "regeneration-required",
    "incompatible",
    "unavailable",
    "blocked-by-dependency",
]
IMMUTABLE_COMPARISON_DIMENSIONS = [
    "familyId",
    "artifactSchema",
    "artifactVersion",
    "corpusSha256",
    "engineVersion",
    "buildConfiguration",
    "routeIdentity",
]
EXPLICIT_DIFFERENCE_DIMENSIONS = [
    "artifactFingerprint",
    "contractBaselineFingerprint",
    "sourceFingerprint",
]
CHANGE_TRIGGERS = {
    "artifact-schema",
    "build-configuration",
    "contract-baseline",
    "corpus",
    "dependency",
    "engine-version",
    "route-identity",
    "source-fingerprint",
}
ARTIFACT_CLASSES = {"local-ignored", "tracked-derived"}
COMPARISON_MODES = {
    "metadata-only",
    "exact-pcm-owned-elsewhere",
    "descriptive-same-schema",
}
MIGRATION_COMPATIBILITY = {"lossless-additive", "breaking-rebaseline"}


def node(
    identifier: str,
    label: str,
    artifact_path: str,
    artifact_class: str,
    schema: str,
    version_field: str,
    artifact_fingerprint_field: str | None,
    dependencies: Sequence[str],
    producer_command: str,
    validator_command: str,
    *,
    contract_fields: Sequence[str] = ("contractBaselineFingerprint",),
    source_fields: Sequence[str] = ("sourceFingerprint",),
    corpus_fields: Sequence[str] = ("corpusSha256",),
    engine_fields: Sequence[str] = ("engineVersion",),
    build_fields: Sequence[str] = (),
    route_fields: Sequence[str] = (),
    comparison_mode: str = "descriptive-same-schema",
) -> dict[str, object]:
    return {
        "id": identifier,
        "label": label,
        "artifactPath": artifact_path,
        "artifactClass": artifact_class,
        "schema": schema,
        "versionField": version_field,
        "version": 1,
        "artifactFingerprintField": artifact_fingerprint_field,
        "contractFingerprintFields": list(contract_fields),
        "sourceFingerprintFields": list(source_fields),
        "corpusFingerprintFields": list(corpus_fields),
        "engineVersionFields": list(engine_fields),
        "buildConfigurationFields": list(build_fields),
        "routeIdentityFields": list(route_fields),
        "dependencies": list(dependencies),
        "producerCommand": producer_command,
        "validatorCommand": validator_command,
        "changeTriggers": sorted(CHANGE_TRIGGERS),
        "comparisonMode": comparison_mode,
    }


NODES = (
    node(
        "whole-mix-render", "Whole-mix render corpus",
        "docs/local/reports/baseline-corpus-v1/manifest.json", "local-ignored",
        "autotechno-baseline-render-manifest.v1", "manifestVersion", None, (),
        "AUTOTECHNO_RUN_BASELINE_RENDER=1 swift test -c release --filter BaselineRenderIntegrationTests",
        "python3 scripts/baseline_render_manifest.py check",
        comparison_mode="exact-pcm-owned-elsewhere",
    ),
    node(
        "long-horizon-session", "Four-hour score-only session baseline",
        "docs/local/reports/long-horizon-session-baseline-v1/report.json",
        "local-ignored", "autotechno-long-horizon-session-baseline-report.v1",
        "reportVersion", "reportFingerprint", (),
        "AUTOTECHNO_RUN_SESSION_TRAJECTORY_BASELINE=1 swift test -c release --filter LongHorizonSessionBaselineIntegrationTests && python3 scripts/session_trajectory_baseline_report.py",
        "python3 scripts/session_trajectory_baseline_report.py --check",
        build_fields=("buildConfiguration",), route_fields=("observationRoute",),
    ),
    node(
        "role-stem-capture", "Aligned role-stem capture",
        "docs/local/reports/baseline-stems-v1/manifest.json", "local-ignored",
        "autotechno-role-stem-manifest.v1", "manifestVersion", None,
        ("whole-mix-render",),
        "AUTOTECHNO_RUN_STEM_CAPTURE=1 swift test -c release --filter StemCaptureIntegrationTests",
        "python3 scripts/stem_capture_manifest.py check",
        comparison_mode="exact-pcm-owned-elsewhere",
    ),
    node(
        "performance-envelope", "Release and bounded live performance envelope",
        "docs/local/reports/performance-envelope-v1/report.json", "local-ignored",
        "autotechno-performance-envelope-report.v1", "reportVersion",
        "reportFingerprint", ("whole-mix-render",),
        "AUTOTECHNO_RUN_PERFORMANCE_ENVELOPE=1 AUTOTECHNO_PERFORMANCE_BUILD_CONFIGURATION=release swift test -c release --filter PerformanceEnvelopeIntegrationTests && python3 scripts/performance_envelope_report.py generate <trace-arguments>",
        "python3 scripts/performance_envelope_report.py check <trace-arguments>",
        corpus_fields=(), build_fields=("buildConfiguration",),
    ),
    node(
        "pcm-comparison-whole", "Whole-mix exact PCM comparison",
        "docs/local/reports/pcm-comparisons-v1/whole-mix-self.json",
        "local-ignored", "autotechno-pcm-comparison-report.v1",
        "reportVersion", "reportFingerprint", ("whole-mix-render",),
        "python3 scripts/pcm_comparison_report.py compare --baseline-manifest <whole-baseline> --candidate-manifest <whole-candidate> --output <report>",
        "python3 scripts/pcm_comparison_report.py check --report <report>",
        contract_fields=("baseline.contractBaselineFingerprint", "candidate.contractBaselineFingerprint"),
        source_fields=("baseline.sourceFingerprint", "candidate.sourceFingerprint"),
        corpus_fields=(), engine_fields=("baseline.engineVersion", "candidate.engineVersion"),
        route_fields=("baseline.domain", "candidate.domain"),
        comparison_mode="exact-pcm-owned-elsewhere",
    ),
    node(
        "pcm-comparison-role", "Role-stem exact PCM comparison",
        "docs/local/reports/pcm-comparisons-v1/role-stems-self.json",
        "local-ignored", "autotechno-pcm-comparison-report.v1",
        "reportVersion", "reportFingerprint", ("role-stem-capture",),
        "python3 scripts/pcm_comparison_report.py compare --baseline-manifest <role-baseline> --candidate-manifest <role-candidate> --output <report>",
        "python3 scripts/pcm_comparison_report.py check --report <report>",
        contract_fields=("baseline.contractBaselineFingerprint", "candidate.contractBaselineFingerprint"),
        source_fields=("baseline.sourceFingerprint", "candidate.sourceFingerprint"),
        corpus_fields=(), engine_fields=("baseline.engineVersion", "candidate.engineVersion"),
        route_fields=("baseline.domain", "candidate.domain"),
        comparison_mode="exact-pcm-owned-elsewhere",
    ),
    node(
        "signal-baseline", "Signal-integrity baseline",
        "docs/local/reports/signal-baseline-v1/manifest.json", "local-ignored",
        "autotechno-signal-baseline-report.v1", "reportVersion",
        "reportFingerprint", ("whole-mix-render", "role-stem-capture"),
        "python3 scripts/signal_baseline_report.py generate",
        "python3 scripts/signal_baseline_report.py check",
    ),
    node(
        "spectral-baseline", "Spectral-shape baseline",
        "docs/local/reports/spectral-baseline-v1/manifest.json", "local-ignored",
        "autotechno-spectral-baseline-report.v1", "reportVersion",
        "reportFingerprint", ("whole-mix-render", "role-stem-capture"),
        "python3 scripts/spectral_baseline_report.py generate",
        "python3 scripts/spectral_baseline_report.py check",
    ),
    node(
        "kick-foundation-collision", "Kick/foundation collision baseline",
        "docs/local/reports/kick-foundation-collision-v1/manifest.json",
        "local-ignored", "autotechno-kick-foundation-collision-report.v1",
        "reportVersion", "reportFingerprint",
        ("whole-mix-render", "role-stem-capture"),
        "python3 scripts/kick_foundation_collision_report.py generate",
        "python3 scripts/kick_foundation_collision_report.py check",
    ),
    node(
        "transient-envelope", "Transient and envelope baseline",
        "docs/local/reports/transient-envelope-baseline-v1/manifest.json",
        "local-ignored", "autotechno-transient-envelope-baseline-report.v1",
        "reportVersion", "reportFingerprint",
        ("whole-mix-render", "role-stem-capture"),
        "python3 scripts/transient_envelope_baseline_report.py generate",
        "python3 scripts/transient_envelope_baseline_report.py check",
    ),
    node(
        "stereo-compatibility", "Stereo compatibility baseline",
        "docs/local/reports/stereo-compatibility-baseline-v1/manifest.json",
        "local-ignored", "autotechno-stereo-compatibility-baseline-report.v1",
        "reportVersion", "reportFingerprint",
        ("whole-mix-render", "role-stem-capture"),
        "python3 scripts/stereo_compatibility_baseline_report.py generate",
        "python3 scripts/stereo_compatibility_baseline_report.py check",
    ),
    node(
        "rhythmic-baseline", "Whole-mix rhythmic baseline",
        "docs/local/reports/rhythmic-baseline-v1/manifest.json", "local-ignored",
        "autotechno-rhythmic-baseline-report.v1", "reportVersion",
        # The exporter reduces only whole PCM, but its shared input loader
        # first validates paired whole/stem source and capture provenance.
        "reportFingerprint", ("whole-mix-render", "role-stem-capture"),
        "python3 scripts/rhythmic_baseline_report.py generate",
        "python3 scripts/rhythmic_baseline_report.py check",
    ),
    node(
        "score-motif", "Accepted-score motif baseline",
        "docs/local/reports/score-motif-baseline-v1/manifest.json",
        "local-ignored", "autotechno-score-motif-baseline-report.v1",
        "reportVersion", "reportFingerprint", ("whole-mix-render",),
        "python3 scripts/score_motif_baseline_report.py generate",
        "python3 scripts/score_motif_baseline_report.py check",
    ),
    node(
        "section-boundary", "Section-boundary baseline",
        "docs/local/reports/section-boundary-baseline-v1/report.json",
        "local-ignored", "autotechno-section-boundary-baseline-report.v1",
        "reportVersion", "reportFingerprint", ("whole-mix-render",),
        "python3 scripts/section_boundary_baseline_report.py generate",
        "python3 scripts/section_boundary_baseline_report.py check",
    ),
    node(
        "deficit-register", "Evidence-ranked deficit register",
        "docs/DEFICIT_REGISTER.json", "tracked-derived",
        "autotechno-deficit-register.v1", "registerVersion",
        "registerFingerprint",
        (
            "kick-foundation-collision", "long-horizon-session",
            "performance-envelope", "rhythmic-baseline", "score-motif",
            "section-boundary", "signal-baseline", "spectral-baseline",
        ),
        "python3 scripts/deficit_register.py generate",
        "python3 scripts/deficit_register.py check",
        contract_fields=("generatedFrom.contractBaselineFingerprint",),
        source_fields=(), corpus_fields=("generatedFrom.corpusSha256",),
        engine_fields=("generatedFrom.engineVersion",),
        comparison_mode="metadata-only",
    ),
)


class BaselineLifecycleError(RuntimeError):
    """An actionable lifecycle-policy error."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=True, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")


def fingerprint(value: Mapping[str, Any], excluded: str | None = None) -> str:
    payload = dict(value)
    if excluded is not None:
        payload.pop(excluded, None)
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def file_digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise BaselineLifecycleError(f"missing {label}: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise BaselineLifecycleError(f"cannot read {label} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise BaselineLifecycleError(f"{label} root must be an object: {path}")
    return value


def write_text_atomic(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(
        prefix=path.name + ".", suffix=".tmp", dir=path.parent, text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(contents)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def write_json_atomic(path: Path, value: Mapping[str, Any]) -> None:
    write_text_atomic(
        path, json.dumps(value, indent=2, ensure_ascii=True, sort_keys=True) + "\n"
    )


def build_policy() -> dict[str, object]:
    policy: dict[str, object] = {
        "schema": SCHEMA,
        "policyVersion": POLICY_VERSION,
        "states": STATES,
        "comparisonRules": {
            "identityEnvelopeSchema": ENVELOPE_SCHEMA,
            "immutableComparisonDimensions": IMMUTABLE_COMPARISON_DIMENSIONS,
            "explicitDifferenceDimensions": EXPLICIT_DIFFERENCE_DIMENSIONS,
            "schemaTransitionRule": "explicit-registered-migration-or-incompatible",
            "exactPCMRule": "metadata-never-substitutes-for-streaming-sample-comparison",
        },
        "limits": {
            "maximumNodes": 32,
            "maximumDependenciesPerNode": 16,
            "maximumFieldPathsPerNode": 8,
            "maximumMigrations": 32,
            "maximumCommandCharacters": 1000,
            "maximumTextCharacters": 500,
        },
        "registeredMigrations": [],
        "nodes": list(NODES),
        "qualification": {
            "runtimeInput": False,
            "promotionAuthorized": False,
            "validatorRequiredForCurrentClaim": True,
            "rawArtifactsTracked": False,
            "purpose": "offline-regeneration-order-compatibility-and-invalidation-only",
        },
    }
    policy["policyFingerprint"] = fingerprint(policy)
    return policy


def bounded_text(value: object, maximum: int = 500) -> bool:
    return isinstance(value, str) and bool(value.strip()) and len(value) <= maximum


def relative_path(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and "." not in path.parts and ".." not in path.parts


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    if set(value) != expected:
        errors.append(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(value)}"
        )


def string_list(
    value: object, location: str, errors: list[str], maximum: int
) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{location} must be an array")
        return []
    if len(value) > maximum:
        errors.append(f"{location} exceeds {maximum} items")
    result: list[str] = []
    for index, item in enumerate(value):
        if not bounded_text(item):
            errors.append(f"{location}[{index}] must be bounded non-empty text")
        else:
            result.append(item)
    return result


def validate_migrations(value: object, node_ids: set[str], errors: list[str]) -> None:
    if not isinstance(value, list):
        errors.append("registeredMigrations must be an array")
        return
    if len(value) > 32:
        errors.append("registeredMigrations exceeds 32 entries")
    identities: set[tuple[object, ...]] = set()
    for index, migration in enumerate(value):
        location = f"registeredMigrations[{index}]"
        if not isinstance(migration, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(migration, MIGRATION_KEYS, location, errors)
        family = migration.get("familyId")
        if family not in node_ids:
            errors.append(f"{location}.familyId must identify a policy node")
        for key in ("sourceSchema", "targetSchema"):
            field = migration.get(key)
            if not isinstance(field, str) or not SCHEMA_ID.fullmatch(field):
                errors.append(f"{location}.{key} must be a versioned schema ID")
        for key in ("sourceVersion", "targetVersion"):
            field = migration.get(key)
            if isinstance(field, bool) or not isinstance(field, int) or field < 1:
                errors.append(f"{location}.{key} must be a positive integer")
        compatibility = migration.get("compatibility")
        if compatibility not in MIGRATION_COMPATIBILITY:
            errors.append(f"{location}.compatibility is unsupported")
        for key in ("transformer", "postValidator"):
            if not bounded_text(migration.get(key), 1000):
                errors.append(f"{location}.{key} must be bounded non-empty text")
        identity = tuple(migration.get(key) for key in (
            "familyId", "sourceSchema", "sourceVersion",
            "targetSchema", "targetVersion",
        ))
        if identity in identities:
            errors.append(f"{location} duplicates a schema transition")
        identities.add(identity)


def topological_order(nodes: Sequence[Mapping[str, Any]]) -> list[str]:
    by_id = {str(item["id"]): item for item in nodes}
    remaining = {
        identifier: set(str(dep) for dep in item.get("dependencies", []))
        for identifier, item in by_id.items()
    }
    result: list[str] = []
    while remaining:
        ready = sorted(identifier for identifier, deps in remaining.items() if not deps)
        if not ready:
            cycle_nodes = ", ".join(sorted(remaining))
            raise BaselineLifecycleError(f"lifecycle dependency cycle: {cycle_nodes}")
        for identifier in ready:
            result.append(identifier)
            del remaining[identifier]
        for deps in remaining.values():
            deps.difference_update(ready)
    return result


def validate_policy(policy: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    exact_keys(policy, ROOT_KEYS, "policy", errors)
    if policy.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if policy.get("policyVersion") != POLICY_VERSION:
        errors.append(f"policyVersion must be {POLICY_VERSION}")
    if policy.get("states") != STATES:
        errors.append("states must be the exact ordered lifecycle vocabulary")
    comparison = policy.get("comparisonRules")
    if not isinstance(comparison, dict):
        errors.append("comparisonRules must be an object")
    else:
        exact_keys(comparison, COMPARISON_KEYS, "comparisonRules", errors)
        if comparison.get("identityEnvelopeSchema") != ENVELOPE_SCHEMA:
            errors.append("comparisonRules.identityEnvelopeSchema is unsupported")
        if comparison.get("immutableComparisonDimensions") != IMMUTABLE_COMPARISON_DIMENSIONS:
            errors.append("immutable comparison dimensions must remain exact and ordered")
        if comparison.get("explicitDifferenceDimensions") != EXPLICIT_DIFFERENCE_DIMENSIONS:
            errors.append("explicit difference dimensions must remain exact and ordered")
        if comparison.get("schemaTransitionRule") != "explicit-registered-migration-or-incompatible":
            errors.append("schema transition rule must fail closed")
        if comparison.get("exactPCMRule") != "metadata-never-substitutes-for-streaming-sample-comparison":
            errors.append("exact PCM rule must preserve streaming comparison authority")
    limits = policy.get("limits")
    if not isinstance(limits, dict):
        errors.append("limits must be an object")
    else:
        exact_keys(limits, LIMIT_KEYS, "limits", errors)
        expected_limits = build_policy()["limits"]
        if limits != expected_limits:
            errors.append("limits must match the bounded v1 policy")
    qualification = policy.get("qualification")
    if not isinstance(qualification, dict):
        errors.append("qualification must be an object")
    else:
        exact_keys(qualification, QUALIFICATION_KEYS, "qualification", errors)
        if qualification != build_policy()["qualification"]:
            errors.append("qualification must remain offline and non-promotional")

    nodes = policy.get("nodes")
    node_ids: set[str] = set()
    valid_nodes: list[Mapping[str, Any]] = []
    if not isinstance(nodes, list):
        errors.append("nodes must be an array")
        nodes = []
    if len(nodes) > 32:
        errors.append("nodes exceeds 32 entries")
    for index, current in enumerate(nodes):
        location = f"nodes[{index}]"
        if not isinstance(current, dict):
            errors.append(f"{location} must be an object")
            continue
        valid_nodes.append(current)
        exact_keys(current, NODE_KEYS, location, errors)
        identifier = current.get("id")
        if not isinstance(identifier, str) or not NODE_ID.fullmatch(identifier):
            errors.append(f"{location}.id must be a stable lowercase identifier")
        elif identifier in node_ids:
            errors.append(f"{location}.id is duplicated: {identifier}")
        else:
            node_ids.add(identifier)
        if not bounded_text(current.get("label")):
            errors.append(f"{location}.label must be bounded non-empty text")
        if not relative_path(current.get("artifactPath")):
            errors.append(f"{location}.artifactPath must be repository-relative")
        if current.get("artifactClass") not in ARTIFACT_CLASSES:
            errors.append(f"{location}.artifactClass is unsupported")
        schema = current.get("schema")
        if not isinstance(schema, str) or not SCHEMA_ID.fullmatch(schema):
            errors.append(f"{location}.schema must be a versioned Auto Techno schema")
        if not bounded_text(current.get("versionField")):
            errors.append(f"{location}.versionField must be a field path")
        version = current.get("version")
        if isinstance(version, bool) or not isinstance(version, int) or version < 1:
            errors.append(f"{location}.version must be a positive integer")
        artifact_field = current.get("artifactFingerprintField")
        if artifact_field is not None and not bounded_text(artifact_field):
            errors.append(f"{location}.artifactFingerprintField must be null or a field path")
        for key in (
            "contractFingerprintFields", "sourceFingerprintFields",
            "corpusFingerprintFields", "engineVersionFields",
            "buildConfigurationFields", "routeIdentityFields", "dependencies",
            "changeTriggers",
        ):
            values = string_list(current.get(key), f"{location}.{key}", errors, 16)
            if len(values) != len(set(values)):
                errors.append(f"{location}.{key} must not contain duplicates")
        if set(current.get("changeTriggers", [])) != CHANGE_TRIGGERS:
            errors.append(f"{location}.changeTriggers must declare every trigger")
        if current.get("comparisonMode") not in COMPARISON_MODES:
            errors.append(f"{location}.comparisonMode is unsupported")
        for key in ("producerCommand", "validatorCommand"):
            if not bounded_text(current.get(key), 1000):
                errors.append(f"{location}.{key} must be bounded non-empty text")

    expected_ids = {str(item["id"]) for item in NODES}
    if node_ids != expected_ids:
        errors.append(
            "nodes must cover the exact Phase-1 family set; "
            f"expected {sorted(expected_ids)}, found {sorted(node_ids)}"
        )
    for index, current in enumerate(valid_nodes):
        for dependency in current.get("dependencies", []):
            if dependency not in node_ids:
                errors.append(f"nodes[{index}] has unknown dependency: {dependency}")
            if dependency == current.get("id"):
                errors.append(f"nodes[{index}] cannot depend on itself")
    try:
        topological_order(valid_nodes)
    except (BaselineLifecycleError, KeyError, TypeError) as exc:
        errors.append(str(exc))

    validate_migrations(policy.get("registeredMigrations"), node_ids, errors)
    recorded = policy.get("policyFingerprint")
    if not isinstance(recorded, str) or not HEX64.fullmatch(recorded):
        errors.append("policyFingerprint must be 64 lowercase hexadecimal digits")
    elif recorded != fingerprint(policy, "policyFingerprint"):
        errors.append("policyFingerprint does not match policy contents")
    return sorted(set(errors))


def value_at_path(document: Mapping[str, Any], path: str) -> object:
    current: object = document
    for component in path.split("."):
        if not isinstance(current, Mapping) or component not in current:
            raise BaselineLifecycleError(f"missing metadata field: {path}")
        current = current[component]
    return current


def common_field(
    document: Mapping[str, Any], paths: Sequence[str], label: str
) -> str:
    if not paths:
        return "not-applicable"
    values = [value_at_path(document, path) for path in paths]
    if any(not isinstance(value, str) or not value for value in values):
        raise BaselineLifecycleError(f"{label} fields must be non-empty strings")
    if len(set(values)) != 1:
        raise BaselineLifecycleError(f"{label} fields disagree")
    return str(values[0])


def envelope_from_artifact(
    root: Path, current: Mapping[str, Any], document: Mapping[str, Any]
) -> dict[str, object]:
    artifact_path = root / str(current["artifactPath"])
    schema = value_at_path(document, "schema")
    version = value_at_path(document, str(current["versionField"]))
    fingerprint_field = current.get("artifactFingerprintField")
    artifact_fingerprint = (
        value_at_path(document, str(fingerprint_field))
        if fingerprint_field is not None
        else file_digest(artifact_path)
    )
    envelope: dict[str, object] = {
        "schema": ENVELOPE_SCHEMA,
        "familyId": current["id"],
        "artifactSchema": schema,
        "artifactVersion": version,
        "artifactFingerprint": artifact_fingerprint,
        "contractBaselineFingerprint": common_field(
            document, current["contractFingerprintFields"], "contract fingerprint"
        ),
        "sourceFingerprint": common_field(
            document, current["sourceFingerprintFields"], "source fingerprint"
        ),
        "corpusSha256": common_field(
            document, current["corpusFingerprintFields"], "corpus fingerprint"
        ),
        "engineVersion": common_field(
            document, current["engineVersionFields"], "engine version"
        ),
        "buildConfiguration": common_field(
            document, current["buildConfigurationFields"], "build configuration"
        ),
        "routeIdentity": common_field(
            document, current["routeIdentityFields"], "route identity"
        ),
    }
    envelope_errors = validate_envelope(envelope)
    if envelope_errors:
        raise BaselineLifecycleError("; ".join(envelope_errors))
    return envelope


def validate_envelope(envelope: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    exact_keys(envelope, ENVELOPE_KEYS, "envelope", errors)
    if envelope.get("schema") != ENVELOPE_SCHEMA:
        errors.append(f"envelope.schema must be {ENVELOPE_SCHEMA}")
    if not isinstance(envelope.get("familyId"), str) or not NODE_ID.fullmatch(str(envelope.get("familyId"))):
        errors.append("envelope.familyId must be a stable lowercase identifier")
    artifact_schema = envelope.get("artifactSchema")
    if not isinstance(artifact_schema, str) or not SCHEMA_ID.fullmatch(artifact_schema):
        errors.append("envelope.artifactSchema must be a versioned schema ID")
    version = envelope.get("artifactVersion")
    if isinstance(version, bool) or not isinstance(version, int) or version < 1:
        errors.append("envelope.artifactVersion must be a positive integer")
    artifact_fingerprint = envelope.get("artifactFingerprint")
    if not isinstance(artifact_fingerprint, str) or not HEX64.fullmatch(artifact_fingerprint):
        errors.append("envelope.artifactFingerprint must be a sha256")
    for key in ("contractBaselineFingerprint", "sourceFingerprint", "corpusSha256"):
        value = envelope.get(key)
        if value != "not-applicable" and (
            not isinstance(value, str) or not HEX64.fullmatch(value)
        ):
            errors.append(f"envelope.{key} must be a sha256 or not-applicable")
    for key in ("engineVersion", "buildConfiguration", "routeIdentity"):
        if not bounded_text(envelope.get(key)):
            errors.append(f"envelope.{key} must be bounded non-empty text")
    return sorted(set(errors))


def find_migration(
    policy: Mapping[str, Any], before: Mapping[str, Any], after: Mapping[str, Any]
) -> Mapping[str, Any] | None:
    for migration in policy.get("registeredMigrations", []):
        if not isinstance(migration, Mapping):
            continue
        if all((
            migration.get("familyId") == before.get("familyId"),
            migration.get("sourceSchema") == before.get("artifactSchema"),
            migration.get("sourceVersion") == before.get("artifactVersion"),
            migration.get("targetSchema") == after.get("artifactSchema"),
            migration.get("targetVersion") == after.get("artifactVersion"),
        )):
            return migration
    return None


def classify_pair(
    policy: Mapping[str, Any], before: Mapping[str, Any], after: Mapping[str, Any]
) -> dict[str, object]:
    errors = validate_envelope(before) + validate_envelope(after)
    if errors:
        raise BaselineLifecycleError("; ".join(sorted(set(errors))))
    if before["familyId"] != after["familyId"]:
        return {"state": "incompatible", "changedDimensions": ["familyId"],
                "reason": "different artifact families cannot be compared"}
    schema_changed = any(
        before[key] != after[key] for key in ("artifactSchema", "artifactVersion")
    )
    if schema_changed:
        migration = find_migration(policy, before, after)
        if migration is None:
            return {"state": "incompatible",
                    "changedDimensions": [key for key in ("artifactSchema", "artifactVersion") if before[key] != after[key]],
                    "reason": "schema transition has no registered migration"}
        if migration.get("compatibility") == "lossless-additive":
            return {"state": "migration-required",
                    "changedDimensions": [key for key in ("artifactSchema", "artifactVersion") if before[key] != after[key]],
                    "reason": "registered lossless migration and post-validation are required"}
        return {"state": "incompatible",
                "changedDimensions": [key for key in ("artifactSchema", "artifactVersion") if before[key] != after[key]],
                "reason": "registered breaking transition requires a new baseline"}
    incompatible = [
        key for key in (
            "corpusSha256", "engineVersion", "buildConfiguration", "routeIdentity"
        ) if before[key] != after[key]
    ]
    if incompatible:
        return {"state": "incompatible", "changedDimensions": incompatible,
                "reason": "one or more immutable comparison dimensions differ"}
    changed = [
        key for key in EXPLICIT_DIFFERENCE_DIMENSIONS if before[key] != after[key]
    ]
    if not changed:
        return {"state": "current-metadata", "changedDimensions": [],
                "reason": "identity envelopes are exact"}
    return {"state": "comparable", "changedDimensions": changed,
            "reason": "same schema and immutable context; differences remain explicit"}


def validate_current_verification(value: object, family: object,
    envelope: Mapping[str, Any], contract: object,
    artifact_sha: str | None = None) -> list[str]:
    """Check metadata structure only; live adapter execution remains mandatory."""
    errors: list[str] = []
    if not isinstance(value, dict):
        return ["current verification must be an object"]
    exact_keys(value, VERIFICATION_KEYS, "current verification", errors)
    if value.get("schema") != VERIFICATION_SCHEMA:
        errors.append("unsupported current verification schema")
    if not isinstance(family, str) or family not in RETAINED_FAMILIES or value.get("familyId") != family:
        errors.append("current verification has no registered family")
    for key in ("originGitHead", "currentGitHead"):
        if not isinstance(value.get(key), str) or not re.fullmatch("[0-9a-f]{40}", value[key]):
            errors.append(f"current verification {key} must be a commit identity")
    for key in ("originSnapshotFingerprint", "originContractBaselineFingerprint",
        "originSourceFingerprint", "validationFingerprint", "currentSnapshotFingerprint",
        "currentContractBaselineFingerprint", "artifactSha256", "verificationFingerprint",
        "currentCaptureContextFingerprint", "currentSourceFreezeFingerprint",
        "currentProbeSha256", "currentProbeDiagnosticSha256", "currentProbeInvocationFingerprint",
        "currentProbeActualArgumentsFingerprint"):
        if not isinstance(value.get(key), str) or not HEX64.fullmatch(value[key]):
            errors.append(f"current verification {key} must be a sha256")
    probe_path = value.get("currentProbePath")
    if not isinstance(probe_path, str) or not re.fullmatch(
        r"docs/local/reports/retained-capture-probe-[0-9a-f]{32}/probe\.json", probe_path):
        errors.append("current verification requires a registered local native probe path")
    if value.get("originContractBaselineFingerprint") != envelope.get("contractBaselineFingerprint") or value.get("originSourceFingerprint") != envelope.get("sourceFingerprint"):
        errors.append("current verification changed the original envelope")
    if value.get("currentContractBaselineFingerprint") != contract:
        errors.append("current verification execution contract is stale")
    if artifact_sha is not None and value.get("artifactSha256") != artifact_sha:
        errors.append("current verification belongs to different artifact bytes")
    if not isinstance(value.get("action"), str) or value["action"] not in {"dependencies-unchanged", "reanalysis-required", "revalidation-required"}:
        errors.append("current verification requires recapture or has unknown action")
    qualification = value.get("qualification")
    if not isinstance(qualification, dict) or set(qualification) != {
        "runtimeInput", "promotionAuthorized", "artifactCurrencyEstablished"} or any(
        flag is not False for flag in qualification.values()):
        errors.append("current verification cannot authorize qualification")
    if value.get("verificationFingerprint") != fingerprint(value, "verificationFingerprint"):
        errors.append("current verification fingerprint differs")
    return errors


def retained_current_verification(root: Path, directory: str, family: str,
    document: Mapping[str, Any], envelope: Mapping[str, Any], contract: str) -> dict[str, object]:
    # A caller-supplied success receipt never replaces this independent live path.
    import baseline_retained_capture as retained
    origin = retained.origin_for_validator(root, directory, family)
    if document != origin["manifests"][family] or document.get("gitHead") != origin["gitHead"]:
        raise BaselineLifecycleError("lifecycle artifact differs from verified original capture")
    node = next(n for n in NODES if n["id"] == family)
    value: dict[str, object] = {
        "schema": VERIFICATION_SCHEMA, "familyId": family,
        "originGitHead": origin["gitHead"],
        "originSnapshotFingerprint": origin["originSnapshotFingerprint"],
        "originContractBaselineFingerprint": origin["contractBaselineFingerprint"],
        "originSourceFingerprint": origin["sourceFingerprint"],
        "validationFingerprint": origin["validationFingerprint"],
        "currentGitHead": origin["currentGitHead"],
        "currentSnapshotFingerprint": origin["currentSnapshotFingerprint"],
        "currentContractBaselineFingerprint": origin["currentContractBaselineFingerprint"],
        "currentCaptureContextFingerprint": origin["currentCaptureContextFingerprint"],
        "currentSourceFreezeFingerprint": origin["currentSourceFreezeFingerprint"],
        "currentProbePath": origin["currentProbeVerification"]["probePath"],
        "currentProbeSha256": origin["currentProbeVerification"]["probeSha256"],
        "currentProbeDiagnosticSha256": origin["currentProbeVerification"]["diagnosticSha256"],
        "currentProbeInvocationFingerprint": origin["currentProbeVerification"]["invocationFingerprint"],
        "currentProbeActualArgumentsFingerprint": origin["currentProbeVerification"]["actualArgumentsFingerprint"],
        "artifactSha256": file_digest(root / str(node["artifactPath"])),
        "action": origin["action"],
        "qualification": dict(origin["qualification"]),
    }
    value["verificationFingerprint"] = fingerprint(value)
    errors = validate_current_verification(value, family, envelope, contract)
    if errors:
        raise BaselineLifecycleError("; ".join(errors))
    return value


def validate_verification_graph(nodes: Sequence[Mapping[str, Any]]) -> list[str]:
    """Preserve the registered capture pair's exact origin and current context."""
    by_id = {n.get("id"): n.get("currentVerification") for n in nodes
        if isinstance(n.get("id"), str)}
    child = by_id.get("role-stem-capture")
    if not isinstance(child, dict):
        return []
    parent = by_id.get("whole-mix-render")
    if not isinstance(parent, dict):
        return ["retained role capture requires registered current whole verification"]
    fields = ("originGitHead", "originSnapshotFingerprint",
        "originContractBaselineFingerprint", "originSourceFingerprint",
        "validationFingerprint", "currentGitHead", "currentSnapshotFingerprint",
        "currentContractBaselineFingerprint", "currentCaptureContextFingerprint",
        "currentSourceFreezeFingerprint", "currentProbeInvocationFingerprint",
        "currentProbeActualArgumentsFingerprint")
    if any(child.get(k) != parent.get(k) for k in fields):
        return ["retained whole/role verification mixes original or current contexts"]
    return []


def require_current_verification_bytes(root: Path, value: Mapping[str, Any]) -> None:
    """Recheck the actual metadata/probe after all cold gates, before reporting."""
    import baseline_dependency_contract as dependency
    import baseline_capture_transaction as transaction
    import baseline_producer_witness as producer
    try:
        before = producer.source_freeze(root)
        if dependency.digest(before) != value["currentSourceFreezeFingerprint"] or before["gitHead"] != value["currentGitHead"]:
            raise BaselineLifecycleError("source moved since registered current verification")
        path = transaction.local_path(root, str(value["currentProbePath"]))
        if producer.file_hash(path, dependency.MAX_METADATA_BYTES) != value["currentProbeSha256"] or producer.file_hash(
            path.with_name('native.log'), 16 * 1024 * 1024) != value["currentProbeDiagnosticSha256"]:
            raise BaselineLifecycleError("actual current probe or diagnostic bytes changed")
        probe = dependency.read_json(path)
        producer.validate_probe(root, probe, image=Path(probe["compiledImagePath"]),
            corpus_name=probe["captureCorpusPath"])
        if dependency.digest(probe["actualArguments"]) != value["currentProbeActualArgumentsFingerprint"]:
            raise BaselineLifecycleError("actual current probe invocation differs")
        producer.require_same_source(root, before)
    except (OSError, ValueError, RuntimeError, KeyError) as exc:
        raise BaselineLifecycleError("current verification bytes rejected: " + str(exc)) from exc


def assess(root: Path, policy: Mapping[str, Any]) -> dict[str, object]:
    baseline = load_json(root / BASELINE_PATH, "roadmap execution baseline")
    contract_fingerprint = baseline.get("snapshotFingerprint")
    if not isinstance(contract_fingerprint, str) or not HEX64.fullmatch(contract_fingerprint):
        raise BaselineLifecycleError("roadmap baseline snapshotFingerprint is invalid")
    corpus_sha = file_digest(root / CORPUS_PATH)
    nodes = policy["nodes"]
    by_id = {str(item["id"]): item for item in nodes}
    order = topological_order(nodes)
    results: list[dict[str, object]] = []
    state_by_id: dict[str, str] = {}
    for identifier in order:
        current = by_id[identifier]
        artifact_path = root / str(current["artifactPath"])
        result: dict[str, object] = {
            "id": identifier,
            "artifactPath": current["artifactPath"],
            "state": "unavailable",
            "reasons": [],
            "identityEnvelope": None,
            "currentVerification": None,
            "validatorRequired": current["validatorCommand"],
        }
        try:
            document = load_json(artifact_path, f"{identifier} artifact")
            envelope = envelope_from_artifact(root, current, document)
            result["identityEnvelope"] = envelope
            selector = os.environ.get("AUTOTECHNO_BASELINE_CAPTURE_PROOF")
            if selector is not None and identifier in RETAINED_FAMILIES:
                try:
                    result["currentVerification"] = retained_current_verification(
                        root, selector, identifier, document, envelope, contract_fingerprint)
                except (OSError, ValueError, RuntimeError) as exc:
                    raise BaselineLifecycleError("retained lifecycle proof rejected: " + str(exc)) from exc
            reasons: list[str] = []
            if envelope["artifactSchema"] != current["schema"] or envelope["artifactVersion"] != current["version"]:
                result["state"] = "incompatible"
                reasons.append("artifact schema/version differs from policy")
            elif envelope["contractBaselineFingerprint"] not in {
                contract_fingerprint, "not-applicable"
            } and result["currentVerification"] is None:
                result["state"] = "regeneration-required"
                reasons.append("contract baseline fingerprint is stale")
            elif envelope["corpusSha256"] not in {corpus_sha, "not-applicable"}:
                result["state"] = "regeneration-required"
                reasons.append("corpus fingerprint is stale")
            else:
                blocked = [
                    dependency for dependency in current["dependencies"]
                    if state_by_id.get(dependency) != "current-metadata"
                ]
                if blocked:
                    result["state"] = "blocked-by-dependency"
                    reasons.append("dependency is not current: " + ", ".join(blocked))
                else:
                    result["state"] = "current-metadata"
                    reasons.append("metadata is current; exact family validator remains required")
            result["reasons"] = reasons
        except BaselineLifecycleError as exc:
            result["reasons"] = [str(exc)]
        state_by_id[identifier] = str(result["state"])
        results.append(result)
    counts = {state: 0 for state in STATES}
    for result in results:
        counts[str(result["state"])] += 1
    assessment: dict[str, object] = {
        "schema": ASSESSMENT_SCHEMA,
        "policyFingerprint": policy["policyFingerprint"],
        "contractBaselineFingerprint": contract_fingerprint,
        "corpusSha256": corpus_sha,
        "regenerationOrder": order,
        "nodes": results,
        "summary": counts,
        "qualification": {
            "contentValidatorsExecuted": False,
            "runtimeInput": False,
            "promotionAuthorized": False,
            "claim": "metadata-lifecycle-only-not-artifact-content-validation",
        },
    }
    assessment["assessmentFingerprint"] = fingerprint(assessment)
    return assessment


def validate_assessment(assessment: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    exact_keys(assessment, ASSESSMENT_KEYS, "assessment", errors)
    if assessment.get("schema") != ASSESSMENT_SCHEMA:
        errors.append(f"assessment.schema must be {ASSESSMENT_SCHEMA}")
    for key in ("policyFingerprint", "contractBaselineFingerprint", "corpusSha256"):
        if not isinstance(assessment.get(key), str) or not HEX64.fullmatch(assessment[key]):
            errors.append(f"assessment {key} must be a sha256")
    recorded = assessment.get("assessmentFingerprint")
    if not isinstance(recorded, str) or not HEX64.fullmatch(recorded):
        errors.append("assessmentFingerprint must be a sha256")
    elif recorded != fingerprint(assessment, "assessmentFingerprint"):
        errors.append("assessmentFingerprint does not match assessment contents")
    nodes = assessment.get("nodes")
    if not isinstance(nodes, list):
        errors.append("assessment.nodes must be an array")
    else:
        ids = [item.get("id") for item in nodes if isinstance(item, dict)]
        order = topological_order(NODES)
        if ids != order or assessment.get("regenerationOrder") != order:
            errors.append("assessment nodes must follow the complete canonical regenerationOrder")
        by_id = {n["id"]: n for n in NODES}
        counts = {state: 0 for state in STATES}
        states_by_id: dict[str, str] = {}
        for item in nodes:
            if not isinstance(item, dict):
                errors.append("assessment node must be an object")
                continue
            exact_keys(item, {"id", "artifactPath", "state", "reasons",
                "identityEnvelope", "currentVerification", "validatorRequired"},
                "assessment node", errors)
            identifier = item.get("id")
            if not isinstance(identifier, str) or identifier not in by_id:
                errors.append("assessment node has unknown identity")
                continue
            node = by_id[identifier]
            if item.get("artifactPath") != node["artifactPath"] or item.get("validatorRequired") != node["validatorCommand"]:
                errors.append("assessment node path or required validator differs")
            state = item.get("state")
            if not isinstance(state, str) or state not in STATES:
                errors.append("assessment node has unknown state")
            else:
                counts[state] += 1
                if state == "current-metadata" and any(states_by_id.get(p) != "current-metadata" for p in node["dependencies"]):
                    errors.append("current assessment node has a noncurrent prerequisite")
                states_by_id[identifier] = state
            reasons = item.get("reasons")
            if not isinstance(reasons, list) or not reasons or any(not bounded_text(r, 4096) for r in reasons):
                errors.append("assessment node reasons must be bounded nonempty strings")
            envelope = item.get("identityEnvelope")
            if isinstance(envelope, dict):
                errors.extend(validate_envelope(envelope))
                if envelope.get("familyId") != identifier:
                    errors.append("assessment envelope belongs to another family")
            elif envelope is not None or state != "unavailable":
                errors.append("available assessment node requires an identity envelope")
            verification = item.get("currentVerification")
            if verification is not None:
                if not isinstance(envelope, dict):
                    errors.append("current verification requires an original envelope")
                else:
                    errors.extend(validate_current_verification(verification, identifier,
                        envelope, assessment.get("contractBaselineFingerprint")))
            if state == "current-metadata" and isinstance(envelope, dict) and verification is None:
                contract = envelope.get("contractBaselineFingerprint")
                if not isinstance(contract, str) or contract not in (
                    assessment.get("contractBaselineFingerprint"), "not-applicable"):
                    errors.append("stale original contract requires registered current verification")
            if state == "current-metadata" and isinstance(envelope, dict) and envelope.get("corpusSha256") not in (
                assessment.get("corpusSha256"), "not-applicable"):
                errors.append("current assessment node has stale corpus identity")
        if assessment.get("summary") != counts:
            errors.append("assessment summary differs from node states")
        errors.extend(validate_verification_graph([n for n in nodes if isinstance(n, dict)]))
    qualification = assessment.get("qualification")
    if qualification != {"contentValidatorsExecuted": False, "runtimeInput": False,
        "promotionAuthorized": False, "claim": "metadata-lifecycle-only-not-artifact-content-validation"} or any(
        qualification.get(k) is not False for k in ("contentValidatorsExecuted", "runtimeInput", "promotionAuthorized")):
        errors.append("assessment cannot authorize content validation or promotion")
    return sorted(set(errors))


def render_markdown(policy: Mapping[str, Any]) -> str:
    order = topological_order(policy["nodes"])
    by_id = {str(item["id"]): item for item in policy["nodes"]}
    lines = [
        "# Baseline lifecycle and schema-migration policy",
        "",
        "This generated policy defines the offline Phase-1 evidence regeneration",
        "graph. It does not validate audio by itself, authorize quality promotion,",
        "or replace any family-specific checker or exact PCM comparison.",
        "",
        f"- Policy schema: `{policy['schema']}`",
        f"- Policy fingerprint: `{policy['policyFingerprint']}`",
        f"- Artifact families: {len(policy['nodes'])}",
        f"- Registered schema migrations: {len(policy['registeredMigrations'])}",
        "- Raw artifacts tracked: no",
        "- Runtime or promotion input: no",
        "",
        "## Lifecycle states",
        "",
        "| State | Meaning |",
        "|---|---|",
        "| `current-metadata` | Schema, contract, corpus, and dependency metadata are current; the named family validator must still pass. |",
        "| `comparable` | Same schema and immutable context; every allowed identity difference remains explicit. |",
        "| `migration-required` | A registered lossless transition must run and pass its post-validator before comparison. |",
        "| `regeneration-required` | Current authority differs; regenerate rather than editing provenance. |",
        "| `incompatible` | No direct comparison is allowed; create a new baseline or registered transition. |",
        "| `unavailable` | Required local evidence is missing or unreadable. |",
        "| `blocked-by-dependency` | A prerequisite is not current. |",
        "",
        "## Deterministic regeneration order",
        "",
        "| # | Family | Artifact | Dependencies | Validator |",
        "|---:|---|---|---|---|",
    ]
    for index, identifier in enumerate(order, 1):
        current = by_id[identifier]
        dependencies = ", ".join(f"`{item}`" for item in current["dependencies"]) or "none"
        lines.append(
            f"| {index} | `{identifier}` | `{current['artifactPath']}` | "
            f"{dependencies} | `{current['validatorCommand']}` |"
        )
    lines.extend([
        "",
        "## Comparison and migration rules",
        "",
        "Direct comparison requires the same family, artifact schema/version, corpus,",
        "engine, build configuration, and route identity. Artifact, contract, and source",
        "fingerprint differences are retained as explicit differences. A schema change",
        "is never inferred compatible from its name: it requires an exact registered",
        "source/target rule, deterministic transformer, and post-validator. Breaking or",
        "unknown transitions are incompatible and require a new baseline.",
        "",
        "Metadata equivalence never substitutes for the streaming sample comparator.",
        "Cross-configuration results remain separate and cannot weaken exact gates.",
        "",
        "## Commands",
        "",
        "```sh",
        "python3 scripts/baseline_lifecycle_policy.py generate",
        "python3 scripts/baseline_lifecycle_policy.py validate",
        "python3 scripts/baseline_lifecycle_policy.py order",
        "python3 scripts/baseline_lifecycle_policy.py assess --output docs/local/reports/baseline-lifecycle-v1/assessment.json",
        "```",
        "",
        "`assess` checks bounded metadata and transitive currency only. Every listed",
        "family validator must pass before an artifact is called current.",
    ])
    return "\n".join(lines) + "\n"


def run_generate(root: Path) -> int:
    policy = build_policy()
    errors = validate_policy(policy)
    if errors:
        raise BaselineLifecycleError("; ".join(errors))
    write_json_atomic(root / POLICY_PATH, policy)
    write_text_atomic(root / MARKDOWN_PATH, render_markdown(policy))
    print(
        f"generated baseline lifecycle policy: {len(policy['nodes'])} families, "
        f"fingerprint {policy['policyFingerprint']}"
    )
    return 0


def run_validate(root: Path) -> int:
    policy = load_json(root / POLICY_PATH, "baseline lifecycle policy")
    errors = validate_policy(policy)
    if errors:
        raise BaselineLifecycleError("; ".join(errors))
    expected_markdown = render_markdown(policy)
    try:
        actual_markdown = (root / MARKDOWN_PATH).read_text(encoding="utf-8")
    except (FileNotFoundError, OSError) as exc:
        raise BaselineLifecycleError(f"cannot read generated Markdown: {exc}") from exc
    if actual_markdown != expected_markdown:
        raise BaselineLifecycleError("generated Markdown is stale; run generate")
    print(
        f"baseline lifecycle policy is valid: {len(policy['nodes'])} families, "
        f"{len(policy['registeredMigrations'])} registered migrations"
    )
    return 0


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("generate")
    subparsers.add_parser("validate")
    subparsers.add_parser("render")
    subparsers.add_parser("order")
    assess_parser = subparsers.add_parser("assess")
    assess_parser.add_argument("--output", type=Path)
    assess_parser.add_argument("--require-current", action="store_true")
    classify_parser = subparsers.add_parser("classify")
    classify_parser.add_argument("--before", type=Path, required=True)
    classify_parser.add_argument("--after", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    root = repository_root()
    try:
        if args.command == "generate":
            return run_generate(root)
        if args.command == "validate":
            return run_validate(root)
        policy = load_json(root / POLICY_PATH, "baseline lifecycle policy")
        errors = validate_policy(policy)
        if errors:
            raise BaselineLifecycleError("; ".join(errors))
        if args.command == "render":
            sys.stdout.write(render_markdown(policy))
            return 0
        if args.command == "order":
            sys.stdout.write("\n".join(topological_order(policy["nodes"])) + "\n")
            return 0
        if args.command == "classify":
            before = load_json(args.before, "before identity envelope")
            after = load_json(args.after, "after identity envelope")
            print(json.dumps(classify_pair(policy, before, after), sort_keys=True))
            return 0
        if args.command == "assess":
            assessment = assess(root, policy)
            assessment_errors = validate_assessment(assessment)
            if assessment_errors:
                raise BaselineLifecycleError("; ".join(assessment_errors))
            if args.output:
                output = args.output if args.output.is_absolute() else root / args.output
                write_json_atomic(output, assessment)
            counts = assessment["summary"]
            print(
                "baseline lifecycle assessment: "
                + ", ".join(f"{key}={counts[key]}" for key in STATES if counts[key])
            )
            if args.require_current and counts["current-metadata"] != len(policy["nodes"]):
                raise BaselineLifecycleError("not every lifecycle node has current metadata")
            return 0
        raise BaselineLifecycleError(f"unsupported command: {args.command}")
    except BaselineLifecycleError as exc:
        print(f"baseline lifecycle policy error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
