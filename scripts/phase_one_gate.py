#!/usr/bin/env python3
"""Generate and validate the fail-closed Auto Techno Phase-1 evidence gate."""

from __future__ import annotations

import argparse
import copy
import datetime
import io
import re
import hashlib
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Callable, Mapping, Optional, Sequence, TextIO


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import baseline_lifecycle_policy as lifecycle  # noqa: E402
import performance_envelope_report as performance  # noqa: E402


SCHEMA = "autotechno-phase-one-gate.v2"
GATE_VERSION = 2
REPORT_PATH = Path("docs/PHASE_ONE_GATE.json")
MARKDOWN_PATH = Path("docs/PHASE_ONE_GATE.md")
ASSESSMENT_PATH = Path(
    "docs/local/reports/baseline-lifecycle-v1/assessment.json"
)
WHOLE_PCM_PATH = Path(
    "docs/local/reports/pcm-comparisons-v1/whole-mix-self.json"
)
ROLE_PCM_PATH = Path(
    "docs/local/reports/pcm-comparisons-v1/role-stems-self.json"
)
DEFICIT_PATH = Path("docs/DEFICIT_REGISTER.json")

CHECKS = (
    ("phase-zero", ("phase_zero_gate.py", "check")),
    ("baseline-corpus", ("baseline_corpus.py", "check")),
    ("lifecycle-policy", ("baseline_lifecycle_policy.py", "validate")),
    ("lifecycle-current", (
        "baseline_lifecycle_policy.py", "assess", "--require-current",
        "--output", ASSESSMENT_PATH.as_posix(),
    )),
    ("whole-mix-manifest", ("baseline_render_manifest.py", "check")),
    ("role-stem-manifest", ("stem_capture_manifest.py", "check")),
    ("whole-pcm-comparison", (
        "pcm_comparison_report.py", "check", "--report", WHOLE_PCM_PATH.as_posix(),
    )),
    ("role-pcm-comparison", (
        "pcm_comparison_report.py", "check", "--report", ROLE_PCM_PATH.as_posix(),
    )),
    ("signal-baseline", ("signal_baseline_report.py", "check")),
    ("spectral-baseline", ("spectral_baseline_report.py", "check")),
    ("kick-foundation-collision", ("kick_foundation_collision_report.py", "check")),
    ("transient-envelope", ("transient_envelope_baseline_report.py", "check")),
    ("stereo-compatibility", ("stereo_compatibility_baseline_report.py", "check")),
    ("rhythmic-baseline", ("rhythmic_baseline_report.py", "check")),
    ("score-motif", ("score_motif_baseline_report.py", "check")),
    ("section-boundary", ("section_boundary_baseline_report.py", "check")),
    ("long-horizon-session", ("session_trajectory_baseline_report.py", "--check")),
    ("performance-envelope", ("performance_envelope_report.py", "check")),
    ("deficit-register", ("deficit_register.py", "check")),
)

ROOT_KEYS = {
    "schema", "gateVersion", "gateFingerprint", "status", "context",
    "regenerationOrder", "artifacts", "checks", "exactPCM",
    "deficitTraceability", "qualification", "limitations",
}
CONTEXT_KEYS = {
    "contractBaselineFingerprint", "lifecyclePolicyFingerprint",
    "corpusSha256", "sourceFingerprints", "engineVersions", "gitHeads",
    "buildConfiguration", "routeIds",
}
ARTIFACT_KEYS = {
    "id", "path", "fileSha256", "schema", "version",
    "artifactFingerprint", "contractBaselineFingerprint", "sourceFingerprint",
    "corpusSha256", "engineVersion", "nativeBuildConfiguration",
    "gateBuildConfiguration", "configurationBinding", "routeIdentity",
    "validator",
    "currentVerification",
}
CHECK_KEYS = {"id", "command", "status"}
PCM_KEYS = {
    "classification", "wholeAssets", "roleAssets", "wholeSamples",
    "roleSamples", "changedSamples", "wholeReportFingerprint",
    "roleReportFingerprint",
}
DEFICIT_KEYS = {
    "entries", "quarantinedObservations", "calibratedAuditoryDefects",
    "sourceCount", "traceableSourceCount", "registerFingerprint",
}
QUALIFICATION_KEYS = {
    "implementation", "deterministicValidation", "exactPCM",
    "performance", "appRouteAudition", "controlledListening",
    "windowsPerformance", "physicalSoak", "musicalQualityClaim",
    "releaseReadinessClaim", "promotionAuthorized", "runtimeInput",
}
Runner = Callable[..., subprocess.CompletedProcess[str]]


class PhaseOneGateError(RuntimeError):
    """An actionable subordinate or Phase-1 gate error."""


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


def file_sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PhaseOneGateError(f"missing {label}: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise PhaseOneGateError(f"cannot read {label} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PhaseOneGateError(f"{label} root must be an object: {path}")
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


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    if set(value) != expected:
        errors.append(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(value)}"
        )


def is_sha(value: object) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
    )


def is_relative_path(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and "." not in path.parts and ".." not in path.parts


def performance_trace_arguments(root: Path) -> tuple[str, ...]:
    """Select only the exact local trace already bound by the stored report.

    This verifies selection bytes, not performance qualification. The existing
    subordinate checker still reconstructs the complete report from those XML
    inputs and current raw/source/contract evidence before the gate can pass.
    """
    report = load_json(root / performance.DEFAULT_REPORT, "performance report")
    if (report.get("schema") != performance.REPORT_SCHEMA or
            report.get("reportFingerprint") != fingerprint(report, "reportFingerprint")):
        raise PhaseOneGateError("performance report schema/fingerprint is invalid")
    live = report.get("liveMacOS")
    if not isinstance(live, dict) or live.get("availability") != "observed":
        raise PhaseOneGateError("performance report requires an observed local trace")
    rate, channels, process = (live.get(name) for name in
                               ("sampleRate", "channelCount", "processName"))
    if (type(rate) is not int or rate not in performance.EXPECTED_SAMPLE_RATES or
            type(channels) is not int or channels != 2 or
            not isinstance(process, str) or not process.strip() or
            len(process) > 128 or "\0" in process):
        raise PhaseOneGateError("performance trace process/native route is invalid")
    inputs = live.get("inputs")
    if not isinstance(inputs, list) or len(inputs) != len(performance.TRACE_FILENAMES):
        raise PhaseOneGateError("performance trace requires every exact XML input")
    kinds: set[str] = set()
    directories: set[str] = set()
    for entry in inputs:
        if not isinstance(entry, dict) or set(entry) != {"kind", "path", "sha256"}:
            raise PhaseOneGateError("performance trace input fields are invalid")
        kind, relative = entry["kind"], entry["path"]
        if (not isinstance(kind, str) or kind not in performance.TRACE_FILENAMES or
                kind in kinds or not is_relative_path(relative) or
                not is_sha(entry["sha256"])):
            raise PhaseOneGateError("performance trace input identity/path is invalid")
        path = root / relative
        if (path.name != performance.TRACE_FILENAMES[kind] or
                not path.resolve().is_relative_to(root.resolve()) or
                any((root / parent).is_symlink() for parent in
                    (Path(relative), *Path(relative).parents)) or
                not path.is_file() or file_sha256(path) != entry["sha256"]):
            raise PhaseOneGateError("performance trace input bytes/path changed")
        kinds.add(kind)
        directories.add(Path(relative).parent.as_posix())
    if kinds != set(performance.TRACE_FILENAMES) or len(directories) != 1:
        raise PhaseOneGateError("performance trace inputs must share one exact directory")
    return ("--trace-directory", next(iter(directories)),
            "--trace-process", process, "--trace-sample-rate", str(rate),
            "--trace-channel-count", str(channels))


def check_command(root: Path, identifier: str, arguments: tuple[str, ...]) -> list[str]:
    if identifier == "performance-envelope":
        arguments += performance_trace_arguments(root)
    return [sys.executable, str(root / "scripts" / arguments[0]), *arguments[1:]]


def run_checks(root: Path, runner: Runner = subprocess.run) -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    for identifier, arguments in CHECKS:
        command = check_command(root, identifier, arguments)
        result = runner(
            command,
            cwd=root,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        if result.returncode != 0:
            diagnostic = (result.stdout or "").strip()
            raise PhaseOneGateError(
                f"subordinate check failed: {identifier}: "
                f"{diagnostic or 'no diagnostic'}"
            )
        display = ["python3", "scripts/" + arguments[0], *command[2:]]
        results.append({
            "id": identifier,
            "command": shlex.join(display),
            "status": "passed",
        })
    return results


def extract_git_heads(document: Mapping[str, Any]) -> list[str]:
    candidates: list[object] = [document.get("gitHead")]
    generated = document.get("generatedFrom")
    if isinstance(generated, Mapping):
        candidates.append(generated.get("gitHead"))
    for side in ("baseline", "candidate"):
        value = document.get(side)
        if isinstance(value, Mapping):
            candidates.append(value.get("gitHead"))
    return sorted({value for value in candidates if isinstance(value, str) and value})


def exact_pcm_summary(whole: Mapping[str, Any], role: Mapping[str, Any]) -> dict[str, object]:
    def values(document: Mapping[str, Any], expected: int, label: str) -> tuple[int, int, str]:
        if document.get("schema") != "autotechno-pcm-comparison-report.v1":
            raise PhaseOneGateError(f"{label} comparison schema is unsupported")
        summary = document.get("summary")
        if not isinstance(summary, Mapping):
            raise PhaseOneGateError(f"{label} comparison summary is missing")
        assets = summary.get("assetCountCompared")
        changed = summary.get("changedSampleCount")
        samples = summary.get("sampleCount")
        if document.get("classification") != "exact" or assets != expected or changed != 0:
            raise PhaseOneGateError(
                f"{label} comparison must be exact across {expected} assets"
            )
        if isinstance(samples, bool) or not isinstance(samples, int) or samples < 1:
            raise PhaseOneGateError(f"{label} comparison sample count is invalid")
        report_fingerprint = document.get("reportFingerprint")
        if not is_sha(report_fingerprint):
            raise PhaseOneGateError(f"{label} report fingerprint is invalid")
        return int(assets), int(samples), str(report_fingerprint)

    whole_assets, whole_samples, whole_fingerprint = values(whole, 14, "whole")
    role_assets, role_samples, role_fingerprint = values(role, 210, "role")
    return {
        "classification": "exact",
        "wholeAssets": whole_assets,
        "roleAssets": role_assets,
        "wholeSamples": whole_samples,
        "roleSamples": role_samples,
        "changedSamples": 0,
        "wholeReportFingerprint": whole_fingerprint,
        "roleReportFingerprint": role_fingerprint,
    }


def deficit_traceability(
    deficit: Mapping[str, Any], artifacts: Sequence[Mapping[str, Any]]
) -> dict[str, object]:
    generated = deficit.get("generatedFrom")
    if not isinstance(generated, Mapping):
        raise PhaseOneGateError("deficit register generatedFrom is missing")
    sources = generated.get("sources")
    if not isinstance(sources, list) or not sources:
        raise PhaseOneGateError("deficit register sources are missing")
    artifacts_by_path = {item.get("path"): item for item in artifacts}
    source_ids: set[str] = set()
    for index, source in enumerate(sources):
        if not isinstance(source, Mapping):
            raise PhaseOneGateError(f"deficit source {index} must be an object")
        source_id = source.get("id")
        path = source.get("path")
        if not isinstance(source_id, str) or source_id in source_ids:
            raise PhaseOneGateError("deficit source IDs must be unique strings")
        source_ids.add(source_id)
        artifact = artifacts_by_path.get(path)
        if artifact is None:
            raise PhaseOneGateError(f"deficit source is not a lifecycle artifact: {path}")
        if source.get("fileSha256") != artifact.get("fileSha256"):
            raise PhaseOneGateError(f"deficit source file hash is stale: {source_id}")
        if source.get("reportFingerprint") != artifact.get("artifactFingerprint"):
            raise PhaseOneGateError(f"deficit report fingerprint is stale: {source_id}")
    entries = deficit.get("entries")
    quarantine = deficit.get("quarantinedObservations")
    qualification = deficit.get("qualification")
    if not isinstance(entries, list) or not isinstance(quarantine, list):
        raise PhaseOneGateError("deficit entry or quarantine collection is invalid")
    if not isinstance(qualification, Mapping):
        raise PhaseOneGateError("deficit qualification is missing")
    for entry in entries:
        if not isinstance(entry, Mapping) or not isinstance(entry.get("evidence"), list):
            raise PhaseOneGateError("deficit entry evidence is invalid")
        for evidence in entry["evidence"]:
            if not isinstance(evidence, Mapping) or evidence.get("sourceId") not in source_ids:
                raise PhaseOneGateError("deficit entry has an untraceable source")
    register_fingerprint = deficit.get("registerFingerprint")
    if not is_sha(register_fingerprint):
        raise PhaseOneGateError("deficit register fingerprint is invalid")
    calibrated = qualification.get("calibratedAuditoryDefectCount")
    if calibrated != 0 or qualification.get("promotionAuthorized") is not False:
        raise PhaseOneGateError("deficit register overstates calibration or promotion")
    return {
        "entries": len(entries),
        "quarantinedObservations": len(quarantine),
        "calibratedAuditoryDefects": 0,
        "sourceCount": len(sources),
        "traceableSourceCount": len(sources),
        "registerFingerprint": register_fingerprint,
    }


def build_report(root: Path, runner: Runner = subprocess.run) -> dict[str, Any]:
    checks = run_checks(root, runner)
    policy = lifecycle.load_json(root / lifecycle.POLICY_PATH, "lifecycle policy")
    policy_errors = lifecycle.validate_policy(policy)
    if policy_errors:
        raise PhaseOneGateError("invalid lifecycle policy: " + "; ".join(policy_errors))
    assessment = lifecycle.load_json(root / ASSESSMENT_PATH, "lifecycle assessment")
    assessment_errors = lifecycle.validate_assessment(assessment)
    if assessment_errors:
        raise PhaseOneGateError("invalid lifecycle assessment: " + "; ".join(assessment_errors))
    if assessment.get("policyFingerprint") != policy.get("policyFingerprint"):
        raise PhaseOneGateError("lifecycle assessment policy fingerprint is stale")
    nodes = assessment.get("nodes")
    if not isinstance(nodes, list) or any(
        not isinstance(item, Mapping) or item.get("state") != "current-metadata"
        for item in nodes
    ):
        raise PhaseOneGateError("every lifecycle node must have current metadata")

    baseline = load_json(root / lifecycle.BASELINE_PATH, "roadmap baseline")
    contract_fingerprint = baseline.get("snapshotFingerprint")
    if assessment.get("contractBaselineFingerprint") != contract_fingerprint:
        raise PhaseOneGateError("lifecycle assessment contract fingerprint is stale")
    corpus_sha = file_sha256(root / lifecycle.CORPUS_PATH)
    if assessment.get("corpusSha256") != corpus_sha:
        raise PhaseOneGateError("lifecycle assessment corpus fingerprint is stale")
    corpus = load_json(root / lifecycle.CORPUS_PATH, "baseline corpus")
    routes = corpus.get("routes")
    if not isinstance(routes, list) or not routes:
        raise PhaseOneGateError("baseline corpus routes are missing")
    route_ids = sorted(
        route.get("id") for route in routes
        if isinstance(route, Mapping) and isinstance(route.get("id"), str)
    )
    if len(route_ids) != len(routes):
        raise PhaseOneGateError("baseline corpus route IDs are invalid")

    artifacts: list[dict[str, object]] = []
    source_fingerprints: set[str] = set()
    engine_versions: set[str] = set()
    git_heads: set[str] = set()
    for item in nodes:
        envelope = item.get("identityEnvelope")
        if not isinstance(envelope, Mapping):
            raise PhaseOneGateError(f"lifecycle node has no identity envelope: {item.get('id')}")
        node_id = item.get("id")
        path = item.get("artifactPath")
        if not isinstance(node_id, str) or not is_relative_path(path):
            raise PhaseOneGateError("lifecycle node identity/path is invalid")
        artifact_path = root / str(path)
        document = load_json(artifact_path, f"{node_id} artifact")
        verification = item.get("currentVerification")
        if isinstance(verification, Mapping):
            try:
                lifecycle.require_current_verification_bytes(root, verification)
            except lifecycle.BaselineLifecycleError as exc:
                raise PhaseOneGateError(str(exc)) from exc
        native_build = envelope.get("buildConfiguration")
        if native_build not in {"not-applicable", "release"}:
            raise PhaseOneGateError(
                f"{node_id} build configuration is not release: {native_build}"
            )
        source = envelope.get("sourceFingerprint")
        engine = envelope.get("engineVersion")
        if is_sha(source):
            source_fingerprints.add(str(source))
        if isinstance(engine, str) and engine != "not-applicable":
            engine_versions.add(engine)
        git_heads.update(extract_git_heads(document))
        artifacts.append({
            "id": node_id,
            "path": path,
            "fileSha256": file_sha256(artifact_path),
            "schema": envelope.get("artifactSchema"),
            "version": envelope.get("artifactVersion"),
            "artifactFingerprint": envelope.get("artifactFingerprint"),
            "contractBaselineFingerprint": envelope.get("contractBaselineFingerprint"),
            "sourceFingerprint": source,
            "corpusSha256": envelope.get("corpusSha256"),
            "engineVersion": engine,
            "nativeBuildConfiguration": native_build,
            "gateBuildConfiguration": "release",
            "configurationBinding": (
                "native-artifact-field"
                if native_build == "release"
                else "aggregate-release-regeneration-wrapper"
            ),
            "routeIdentity": envelope.get("routeIdentity"),
            "validator": item.get("validatorRequired"),
            "currentVerification": item.get("currentVerification"),
        })
    if not source_fingerprints or not engine_versions or not git_heads:
        raise PhaseOneGateError("source, engine, or Git provenance is unavailable")

    whole = load_json(root / WHOLE_PCM_PATH, "whole PCM comparison")
    role = load_json(root / ROLE_PCM_PATH, "role PCM comparison")
    exact_pcm = exact_pcm_summary(whole, role)
    deficit = load_json(root / DEFICIT_PATH, "deficit register")
    deficit_summary = deficit_traceability(deficit, artifacts)
    report: dict[str, Any] = {
        "schema": SCHEMA,
        "gateVersion": GATE_VERSION,
        "status": "passed",
        "context": {
            "contractBaselineFingerprint": contract_fingerprint,
            "lifecyclePolicyFingerprint": policy["policyFingerprint"],
            "corpusSha256": corpus_sha,
            "sourceFingerprints": sorted(source_fingerprints),
            "engineVersions": sorted(engine_versions),
            "gitHeads": sorted(git_heads),
            "buildConfiguration": "release",
            "routeIds": route_ids,
        },
        "regenerationOrder": assessment["regenerationOrder"],
        "artifacts": artifacts,
        "checks": checks,
        "exactPCM": exact_pcm,
        "deficitTraceability": deficit_summary,
        "qualification": {
            "implementation": "implemented",
            "deterministicValidation": "passed",
            "exactPCM": "passed",
            "performance": "bounded-macos-observed",
            "appRouteAudition": "not-run",
            "controlledListening": "not-conducted",
            "windowsPerformance": "unavailable",
            "physicalSoak": "unavailable",
            "musicalQualityClaim": False,
            "releaseReadinessClaim": False,
            "promotionAuthorized": False,
            "runtimeInput": False,
        },
        "limitations": [
            "Current metadata does not replace any family-specific content validator.",
            "Release configuration is natively recorded where supported and otherwise bound by this exact artifact-hash wrapper.",
            "Cross-configuration and floating-point differences are incompatible until explicitly captured and compared; they never weaken exact PCM gates.",
            "The live macOS trace is bounded and does not establish long physical soak or Windows performance.",
            "No app/route audition or controlled listening was conducted for this gate.",
            "Reproducible evidence is not a calibrated auditory-quality or release-readiness claim.",
        ],
    }
    report["gateFingerprint"] = fingerprint(report)
    errors = validate_report(report, policy)
    if errors:
        raise PhaseOneGateError("generated report is invalid: " + "; ".join(errors))
    return report


def validate_report(
    report: Mapping[str, Any], policy: Mapping[str, Any]
) -> list[str]:
    errors: list[str] = []
    exact_keys(report, ROOT_KEYS, "report", errors)
    if report.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if report.get("gateVersion") != GATE_VERSION:
        errors.append(f"gateVersion must be {GATE_VERSION}")
    if report.get("status") != "passed":
        errors.append("status must be passed")
    context = report.get("context")
    if not isinstance(context, dict):
        errors.append("context must be an object")
    else:
        exact_keys(context, CONTEXT_KEYS, "context", errors)
        for key in (
            "contractBaselineFingerprint", "lifecyclePolicyFingerprint",
            "corpusSha256",
        ):
            if not is_sha(context.get(key)):
                errors.append(f"context.{key} must be a sha256")
        if context.get("lifecyclePolicyFingerprint") != policy.get("policyFingerprint"):
            errors.append("context lifecycle policy fingerprint is stale")
        if context.get("buildConfiguration") != "release":
            errors.append("context.buildConfiguration must be release")
        for key in ("sourceFingerprints", "engineVersions", "gitHeads", "routeIds"):
            value = context.get(key)
            if (
                not isinstance(value, list)
                or not value
                or any(not isinstance(item, str) or not item for item in value)
                or value != sorted(set(item for item in value if isinstance(item, str)))
            ):
                errors.append(f"context.{key} must be a non-empty sorted unique array")
    expected_order = lifecycle.topological_order(policy.get("nodes", []))
    if report.get("regenerationOrder") != expected_order:
        errors.append("regenerationOrder must match the lifecycle policy")
    artifacts = report.get("artifacts")
    if not isinstance(artifacts, list):
        errors.append("artifacts must be an array")
        artifacts = []
    artifact_ids: list[object] = []
    for index, artifact in enumerate(artifacts):
        location = f"artifacts[{index}]"
        if not isinstance(artifact, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(artifact, ARTIFACT_KEYS, location, errors)
        verification = artifact.get("currentVerification")
        if verification is not None:
            errors.extend(lifecycle.validate_current_verification(verification,
                artifact.get("id"), artifact,
                context.get("contractBaselineFingerprint") if isinstance(context, dict) else None,
                artifact.get("fileSha256")))
            if isinstance(verification, dict) and isinstance(context, dict):
                for origin_key, context_key in (("originGitHead", "gitHeads"),
                    ("originSourceFingerprint", "sourceFingerprints")):
                    recorded = context.get(context_key)
                    if isinstance(recorded, list) and verification.get(origin_key) not in recorded:
                        errors.append("scoped artifact origin is omitted from aggregate context")
        elif isinstance(context, dict) and artifact.get("contractBaselineFingerprint") not in (
            context.get("contractBaselineFingerprint"), "not-applicable"):
            errors.append("stale aggregate artifact has no registered current verification")
        artifact_ids.append(artifact.get("id"))
        if not is_relative_path(artifact.get("path")):
            errors.append(f"{location}.path must be repository-relative")
        for key in ("fileSha256", "artifactFingerprint"):
            if not is_sha(artifact.get(key)):
                errors.append(f"{location}.{key} must be a sha256")
        for key in (
            "contractBaselineFingerprint", "sourceFingerprint", "corpusSha256"
        ):
            value = artifact.get(key)
            if value != "not-applicable" and not is_sha(value):
                errors.append(f"{location}.{key} must be sha256 or not-applicable")
        if artifact.get("gateBuildConfiguration") != "release":
            errors.append(f"{location}.gateBuildConfiguration must be release")
        if artifact.get("nativeBuildConfiguration") not in {"release", "not-applicable"}:
            errors.append(f"{location}.nativeBuildConfiguration is unsupported")
        if artifact.get("configurationBinding") not in {
            "native-artifact-field", "aggregate-release-regeneration-wrapper"
        }:
            errors.append(f"{location}.configurationBinding is unsupported")
        if not isinstance(artifact.get("validator"), str) or not artifact.get("validator"):
            errors.append(f"{location}.validator must be non-empty")
    if artifact_ids != expected_order:
        errors.append("artifacts must follow the exact lifecycle regeneration order")
    errors.extend(lifecycle.validate_verification_graph([a for a in artifacts if isinstance(a, dict)]))

    checks = report.get("checks")
    if not isinstance(checks, list):
        errors.append("checks must be an array")
        checks = []
    check_ids: list[object] = []
    for index, check in enumerate(checks):
        location = f"checks[{index}]"
        if not isinstance(check, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(check, CHECK_KEYS, location, errors)
        check_ids.append(check.get("id"))
        if check.get("status") != "passed":
            errors.append(f"{location}.status must be passed")
        if not isinstance(check.get("command"), str) or len(check.get("command", "")) > 1000:
            errors.append(f"{location}.command must be bounded text")
    if check_ids != [identifier for identifier, _ in CHECKS]:
        errors.append("checks must be the exact ordered subordinate inventory")

    exact_pcm = report.get("exactPCM")
    if not isinstance(exact_pcm, dict):
        errors.append("exactPCM must be an object")
    else:
        exact_keys(exact_pcm, PCM_KEYS, "exactPCM", errors)
        if (
            exact_pcm.get("classification") != "exact"
            or exact_pcm.get("wholeAssets") != 14
            or exact_pcm.get("roleAssets") != 210
            or exact_pcm.get("changedSamples") != 0
        ):
            errors.append("exactPCM must retain 14 whole and 210 role exact assets")
        for key in ("wholeSamples", "roleSamples"):
            value = exact_pcm.get(key)
            if isinstance(value, bool) or not isinstance(value, int) or value < 1:
                errors.append(f"exactPCM.{key} must be positive")
        for key in ("wholeReportFingerprint", "roleReportFingerprint"):
            if not is_sha(exact_pcm.get(key)):
                errors.append(f"exactPCM.{key} must be a sha256")

    deficit = report.get("deficitTraceability")
    if not isinstance(deficit, dict):
        errors.append("deficitTraceability must be an object")
    else:
        exact_keys(deficit, DEFICIT_KEYS, "deficitTraceability", errors)
        for key in ("entries", "quarantinedObservations", "sourceCount", "traceableSourceCount"):
            value = deficit.get(key)
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                errors.append(f"deficitTraceability.{key} must be non-negative")
        if deficit.get("sourceCount") != deficit.get("traceableSourceCount"):
            errors.append("every deficit source must be traceable")
        if deficit.get("calibratedAuditoryDefects") != 0:
            errors.append("calibrated auditory defect count must remain zero")
        if not is_sha(deficit.get("registerFingerprint")):
            errors.append("deficit register fingerprint must be a sha256")

    qualification = report.get("qualification")
    if not isinstance(qualification, dict):
        errors.append("qualification must be an object")
    else:
        exact_keys(qualification, QUALIFICATION_KEYS, "qualification", errors)
        expected = {
            "implementation": "implemented",
            "deterministicValidation": "passed",
            "exactPCM": "passed",
            "performance": "bounded-macos-observed",
            "appRouteAudition": "not-run",
            "controlledListening": "not-conducted",
            "windowsPerformance": "unavailable",
            "physicalSoak": "unavailable",
            "musicalQualityClaim": False,
            "releaseReadinessClaim": False,
            "promotionAuthorized": False,
            "runtimeInput": False,
        }
        if qualification != expected:
            errors.append("qualification must preserve exact bounded claims")
    limitations = report.get("limitations")
    if not isinstance(limitations, list) or not limitations or len(limitations) > 16:
        errors.append("limitations must be a bounded non-empty array")
    elif any(not isinstance(item, str) or not item or len(item) > 500 for item in limitations):
        errors.append("limitations entries must be bounded non-empty text")
    recorded = report.get("gateFingerprint")
    if not is_sha(recorded):
        errors.append("gateFingerprint must be a sha256")
    elif recorded != fingerprint(report, "gateFingerprint"):
        errors.append("gateFingerprint does not match report contents")
    return sorted(set(errors))


def render_markdown(report: Mapping[str, Any]) -> str:
    context = report["context"]
    pcm = report["exactPCM"]
    deficit = report["deficitTraceability"]
    qualification = report["qualification"]
    lines = [
        "# Phase-1 reproducible current-state evidence gate",
        "",
        "> Generated by `scripts/phase_one_gate.py`; do not edit by hand.",
        "",
        f"Status: **{report['status']}**",
        "",
        f"- Gate fingerprint: `{report['gateFingerprint']}`",
        f"- Contract baseline: `{context['contractBaselineFingerprint']}`",
        f"- Lifecycle policy: `{context['lifecyclePolicyFingerprint']}`",
        f"- Build configuration: `{context['buildConfiguration']}`",
        f"- Routes: {', '.join(f'`{item}`' for item in context['routeIds'])}",
        f"- Artifact families: {len(report['artifacts'])}",
        f"- Subordinate checks: {len(report['checks'])}",
        "",
        "## Exact PCM",
        "",
        f"Fourteen whole mixes and 210 role signals are `{pcm['classification']}` with "
        f"{pcm['changedSamples']} changed samples across "
        f"{pcm['wholeSamples'] + pcm['roleSamples']:,} compared samples.",
        "",
        "## Deficit traceability",
        "",
        f"{deficit['entries']} ranked entries and "
        f"{deficit['quarantinedObservations']} quarantined observations bind "
        f"{deficit['traceableSourceCount']}/{deficit['sourceCount']} current sources. "
        f"Calibrated auditory defects: {deficit['calibratedAuditoryDefects']}.",
        "",
        "## Artifact bindings",
        "",
        "Original artifact envelopes remain capture facts. Registered current",
        "verification is recorded separately; unsupported families retain the",
        "legacy current-contract requirement. Every content gate remains required.",
        "",
        "| # | Family | Schema | Configuration binding | Current verification | Validator |",
        "|---:|---|---|---|---|---|",
    ]
    for index, artifact in enumerate(report["artifacts"], 1):
        verification = artifact.get("currentVerification")
        basis = (verification['verificationFingerprint']
            if isinstance(verification, Mapping) else 'legacy-current-contract')
        lines.append(
            f"| {index} | `{artifact['id']}` | `{artifact['schema']}` | "
            f"`{artifact['configurationBinding']}` | `{basis}` | `{artifact['validator']}` |"
        )
    lines.extend([
        "",
        "## Qualification boundaries",
        "",
        "| Gate | Status |",
        "|---|---|",
        f"| Implementation | `{qualification['implementation']}` |",
        f"| Deterministic validation | `{qualification['deterministicValidation']}` |",
        f"| Exact PCM | `{qualification['exactPCM']}` |",
        f"| Performance | `{qualification['performance']}` |",
        f"| App/route audition | `{qualification['appRouteAudition']}` |",
        f"| Controlled listening | `{qualification['controlledListening']}` |",
        f"| Windows performance | `{qualification['windowsPerformance']}` |",
        f"| Physical soak | `{qualification['physicalSoak']}` |",
        "| Musical-quality claim | `false` |",
        "| Release-readiness claim | `false` |",
        "| Promotion/runtime authority | `false` |",
        "",
        "## Limitations",
        "",
    ])
    lines.extend(f"- {item}" for item in report["limitations"])
    return "\n".join(lines) + "\n"


def run_generate(root: Path, output: TextIO, runner: Runner = subprocess.run) -> int:
    report = build_report(root, runner)
    write_json_atomic(root / REPORT_PATH, report)
    write_text_atomic(root / MARKDOWN_PATH, render_markdown(report))
    print(
        f"phase-1 gate generated: passed, {len(report['artifacts'])} artifacts, "
        f"fingerprint {report['gateFingerprint']}",
        file=output,
    )
    return 0


def run_validate(root: Path, output: TextIO) -> int:
    policy = lifecycle.load_json(root / lifecycle.POLICY_PATH, "lifecycle policy")
    report = load_json(root / REPORT_PATH, "Phase-1 gate")
    errors = validate_report(report, policy)
    try:
        markdown = (root / MARKDOWN_PATH).read_text(encoding="utf-8")
    except (FileNotFoundError, OSError) as exc:
        errors.append(f"cannot read generated Markdown: {exc}")
        markdown = ""
    if markdown != render_markdown(report):
        errors.append("generated Markdown is stale")
    if errors:
        print("phase-1 gate invalid: " + "; ".join(sorted(set(errors))), file=output)
        return 1
    print(
        f"phase-1 gate structure is valid: {len(report['artifacts'])} artifacts, "
        f"fingerprint {report['gateFingerprint']}",
        file=output,
    )
    return 0


def same_verified_basis(before: Mapping[str, Any], after: Mapping[str, Any]) -> bool:
    """Compare only after strict structure and actual receipt-byte verification.

    Fresh registered probes have new local paths and process/log hashes. These
    are separate executed receipts for the same exact source/context, not changes
    to capture envelopes. No other identity or result dimension is normalized.
    """
    values = [copy.deepcopy(dict(v)) for v in (before, after)]
    for value in values:
        value.pop('gateFingerprint', None)
        for artifact in value['artifacts']:
            verification = artifact.get('currentVerification')
            if isinstance(verification, dict):
                for key in ('currentProbePath', 'currentProbeSha256',
                    'currentProbeDiagnosticSha256', 'verificationFingerprint'):
                    verification.pop(key)
    return values[0] == values[1]


def run_check(root: Path, output: TextIO, runner: Runner = subprocess.run) -> int:
    expected = build_report(root, runner)
    actual = load_json(root / REPORT_PATH, "Phase-1 gate")
    policy = lifecycle.load_json(root / lifecycle.POLICY_PATH, "lifecycle policy")
    errors = validate_report(actual, policy)
    if errors:
        raise PhaseOneGateError("stored Phase-1 gate is invalid: " + "; ".join(errors))
    for artifact in actual['artifacts']:
        verification = artifact.get('currentVerification')
        if isinstance(verification, Mapping):
            lifecycle.require_current_verification_bytes(root, verification)
    if not same_verified_basis(actual, expected):
        print("phase-1 gate is stale; run generate", file=output)
        return 1
    if (root / MARKDOWN_PATH).read_text(encoding="utf-8") != render_markdown(actual):
        print("phase-1 gate Markdown is stale; run generate", file=output)
        return 1
    print(
        f"phase-1 evidence gate is current: passed, {len(expected['artifacts'])} artifacts",
        file=output,
    )
    return 0


EXECUTION_SCHEMA = "autotechno-phase-one-original-execution.v1"
EXECUTION_SCOPE = 'Original canonical checker execution and direct source/report inputs only; raw capture closure and final item applicability require their separate authorities.'
MAX_EXECUTION_LOG = 32 * 1024 * 1024


def execution_source_cut(root: Path, source: str) -> dict[str, str]:
    """Independently compare actual regular tracked bytes to the exact Git tree."""
    def git(*args: str) -> bytes:
        return subprocess.check_output(["git", "-c", "core.fsmonitor=false", *args], cwd=root)
    if (not isinstance(source, str) or not re.fullmatch(r"[0-9a-f]{40}", source)
            or git("rev-parse", "HEAD").decode().strip() != source
            or git("status", "--porcelain", "--untracked-files=all").strip()):
        raise PhaseOneGateError("recorded execution requires a clean exact source")
    result = {}
    for entry in git("ls-tree", "-rz", source).split(b"\0"):
        if not entry:
            continue
        header, raw_name = entry.split(b"\t", 1)
        mode, kind, blob = header.decode().split()
        name = raw_name.decode(); path = root / name
        if (mode not in {"100644", "100755"} or kind != "blob"
                or not is_relative_path(name) or path.is_symlink()
                or not path.is_file() or not path.resolve().is_relative_to(root)):
            raise PhaseOneGateError("recorded source has a nonregular input: " + name)
        raw = path.read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        if actual != blob:
            raise PhaseOneGateError("actual tracked bytes differ from Git: " + name)
        result[name] = hashlib.sha256(raw).hexdigest()
    if not result or result.get("scripts/phase_one_gate.py") != file_sha256(Path(__file__)):
        raise PhaseOneGateError("recorded execution must use its exact tracked implementation")
    return result


def execution_evidence_paths() -> list[str]:
    return sorted({str(node["artifactPath"]) for node in lifecycle.build_policy()["nodes"]}
        | {str(REPORT_PATH), str(MARKDOWN_PATH), str(lifecycle.POLICY_PATH),
           str(lifecycle.BASELINE_PATH), str(lifecycle.CORPUS_PATH)})


def execution_evidence_cut(root: Path) -> dict[str, str | None]:
    values = {}
    for name in execution_evidence_paths():
        path = root / name
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise PhaseOneGateError("recorded evidence path escapes or is linked: " + name)
        values[name] = file_sha256(path) if path.is_file() else None
    return values


def run_recorded_check(root: Path, directory: Path, source: str, output: TextIO) -> int:
    """Record the existing nineteen checks once; never generate or promote a gate.

    Logs are original combined child stdout/stderr bytes, not reconstructed from
    a success flag. The existing lifecycle assessor may rewrite its derived local
    assessment, so retain its before/after bytes separately. Any other changed
    source/report input or incomplete command sequence refuses this execution.
    """
    root = root.resolve(); directory = directory.absolute()
    if len(CHECKS) != 19 or len({row[0] for row in CHECKS}) != 19:
        raise PhaseOneGateError("complete nineteen-check registry required")
    before = execution_source_cut(root, source)
    if (directory.exists() or directory.is_symlink() or not directory.parent.is_dir()
            or directory.resolve().is_relative_to(root)):
        raise PhaseOneGateError("fresh execution directory outside source required")
    selectors = {k: v for k, v in os.environ.items() if k.startswith("AUTOTECHNO_")}
    if set(selectors) - {"AUTOTECHNO_BASELINE_CAPTURE_PROOF"}:
        raise PhaseOneGateError("unregistered execution environment override")
    evidence = execution_evidence_cut(root)
    directory.mkdir()
    def preserve_assessment(suffix: str) -> str | None:
        path = root / ASSESSMENT_PATH
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise PhaseOneGateError("derived lifecycle assessment is linked or escaped")
        if not path.is_file():
            return None
        raw = path.read_bytes(); (directory / (suffix + "-lifecycle-assessment.json")).write_bytes(raw)
        return hashlib.sha256(raw).hexdigest()
    assessment_before = preserve_assessment("before")
    record: dict[str, Any] = {
        "schema": EXECUTION_SCHEMA, "source": source, "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "implementationSHA256": file_sha256(Path(__file__)), "python": sys.version,
        "pythonExecutable": str(Path(sys.executable).resolve()), "pythonExecutableSHA256": file_sha256(Path(sys.executable)),
        "environmentSelectors": selectors, "trackedInputs": before, "evidenceInputs": evidence,
        "derivedAssessmentBeforeSHA256": assessment_before, "checks": [],
        "status": "in-progress", "all19SubordinateChecksRecorded": False,
        "all19SubordinateExitCodesZero": False, "phaseOneGateCheckPassed": False,
        "scope": EXECUTION_SCOPE,
        "runtimeQualification": False, "automatedQualityQualification": False, "item39Complete": False,
    }
    record_path = directory / "original-execution.json"
    write_json_atomic(record_path, record)
    aggregate = io.StringIO(); failures = []; code = 1
    def recorded_runner(command: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        index = len(record["checks"])
        if index >= len(CHECKS):
            raise PhaseOneGateError("extra unregistered subordinate command")
        identifier, arguments = CHECKS[index]
        expected = check_command(root, identifier, arguments)
        if command != expected or kwargs != dict(cwd=root, check=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True):
            raise PhaseOneGateError("subordinate command or execution options differ")
        name = f"{index+1:02d}-{identifier}.log"; path = directory / name
        launch = {"id": identifier, "command": command, "log": name,
                  "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        record["checks"].append(launch); write_json_atomic(record_path, record)
        # Direct redirection retains original bytes without buffering a child
        # log in memory. Read only bounded completed output for legacy diagnosis.
        with path.open("xb") as handle:
            child = subprocess.run(command, cwd=root, check=False, stdout=handle, stderr=subprocess.STDOUT)
        launch.update(exitCode=child.returncode, logBytes=path.stat().st_size,
                      logSHA256=file_sha256(path), finishedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat())
        write_json_atomic(record_path, record)
        if not 0 < path.stat().st_size <= MAX_EXECUTION_LOG:
            raise PhaseOneGateError("original subordinate output is empty or exceeds its read bound")
        return subprocess.CompletedProcess(command, child.returncode, path.read_bytes().decode("utf-8"))
    try:
        code = run_check(root, aggregate, recorded_runner)
        if (type(code) is not int or code != 0 or len(record["checks"]) != len(CHECKS)
                or any(type(row.get("exitCode")) is not int or row["exitCode"] != 0 for row in record["checks"])):
            raise PhaseOneGateError("canonical gate or complete nineteen-command execution refused")
    except (PhaseOneGateError, lifecycle.BaselineLifecycleError, OSError, ValueError, subprocess.SubprocessError) as exc:
        failures.append(f"{type(exc).__name__}: {exc}"); code = 1
    try:
        record["derivedAssessmentAfterSHA256"] = preserve_assessment("after")
        if (execution_source_cut(root, source) != before or execution_evidence_cut(root) != evidence
                or file_sha256(Path(sys.executable)) != record["pythonExecutableSHA256"]):
            raise PhaseOneGateError("source or original evidence inputs changed during execution")
        record["inputsUnchanged"] = True
    except (PhaseOneGateError, OSError, subprocess.SubprocessError) as exc:
        record["inputsUnchanged"] = False; failures.append(f"{type(exc).__name__}: {exc}"); code = 1
    raw = aggregate.getvalue().encode(); (directory / "original-aggregate.log").write_bytes(raw)
    complete = len(record["checks"]) == 19 and all(
        type(row.get("exitCode")) is int and "logSHA256" in row for row in record["checks"])
    record.update(finishedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(), status="passed" if code == 0 else "refused",
                  exitCode=code, failures=failures, aggregateLogSHA256=hashlib.sha256(raw).hexdigest(),
                  all19SubordinateChecksRecorded=complete,
                  all19SubordinateExitCodesZero=complete and all(row["exitCode"] == 0 for row in record["checks"]),
                  phaseOneGateCheckPassed=code == 0)
    write_json_atomic(record_path, record)
    print("phase-1 original execution " + record["status"] + "; records: " + str(directory), file=output)
    return code


def audit_recorded_check(root: Path, directory: Path, source: str,
                         expected_record_sha256: str) -> dict[str, Any]:
    """Read a pinned original receipt without executing any subordinate command.

    This authenticates receipt/source/log integrity, not the domain claims in
    child output. The final item audit still needs independent product readers,
    original capture/probe provenance, applicability and all remaining gates.
    """
    root = root.resolve(); directory = directory.absolute()
    if (not isinstance(expected_record_sha256, str)
            or not re.fullmatch(r"[0-9a-f]{64}", expected_record_sha256)
            or directory.is_symlink() or not directory.is_dir()
            or directory.resolve().is_relative_to(root)):
        raise PhaseOneGateError("pinned original receipt directory outside source required")
    before = execution_source_cut(root, source)
    if len(CHECKS) != 19 or len({row[0] for row in CHECKS}) != 19:
        raise PhaseOneGateError("complete nineteen-check registry required")
    inputs: dict[str, str] = {}
    def read(name: str, limit: int) -> bytes:
        path = directory / name
        if (Path(name).name != name or path.is_symlink() or not path.is_file()
                or path.resolve().parent != directory.resolve()
                or not 0 < path.stat().st_size <= limit):
            raise PhaseOneGateError("invalid original receipt file: " + name)
        raw = path.read_bytes()
        if not 0 < len(raw) <= limit:
            raise PhaseOneGateError("original receipt file changed size: " + name)
        inputs[name] = hashlib.sha256(raw).hexdigest()
        return raw
    def need(value: bool, message: str) -> None:
        if not value:
            raise PhaseOneGateError("original execution receipt: " + message)
    def pairs(values: list[tuple[str, Any]]) -> dict[str, Any]:
        result = {}
        for key, value in values:
            need(key not in result, "duplicate JSON key")
            result[key] = value
        return result
    def nonfinite(value: str) -> None:
        raise PhaseOneGateError("nonfinite receipt JSON: " + value)
    raw = read("original-execution.json", 4 * 1024 * 1024)
    need(inputs["original-execution.json"] == expected_record_sha256, "pinned receipt hash differs")
    try:
        record = json.loads(raw, object_pairs_hook=pairs, parse_constant=nonfinite)
    except (ValueError, UnicodeError) as exc:
        raise PhaseOneGateError("invalid original receipt JSON") from exc
    expected_keys = {
        "schema", "source", "startedUTC", "finishedUTC", "implementationSHA256",
        "python", "pythonExecutable", "pythonExecutableSHA256", "environmentSelectors",
        "trackedInputs", "evidenceInputs", "derivedAssessmentBeforeSHA256",
        "derivedAssessmentAfterSHA256", "checks", "status", "exitCode", "failures",
        "all19SubordinateChecksRecorded", "all19SubordinateExitCodesZero",
        "phaseOneGateCheckPassed", "inputsUnchanged", "aggregateLogSHA256", "scope",
        "runtimeQualification", "automatedQualityQualification", "item39Complete",
    }
    need(type(record) is dict and set(record) == expected_keys, "closed complete receipt schema")
    need(record["schema"] == EXECUTION_SCHEMA and record["source"] == source,
         "exact schema and source")
    need(record["status"] == "passed" and type(record["exitCode"]) is int
         and record["exitCode"] == 0 and type(record["failures"]) is list
         and not record["failures"], "original aggregate did not report success")
    for key in ("all19SubordinateChecksRecorded", "all19SubordinateExitCodesZero",
                "phaseOneGateCheckPassed", "inputsUnchanged"):
        need(record[key] is True, "missing exact completed-record flag: " + key)
    for key in ("runtimeQualification", "automatedQualityQualification", "item39Complete"):
        need(record[key] is False, "receipt cannot promote qualification: " + key)
    need(record["scope"] == EXECUTION_SCOPE, "original scope differs")
    need(record["trackedInputs"] == before and record["implementationSHA256"]
         == before.get("scripts/phase_one_gate.py"), "current exact tracked source binding")
    evidence = execution_evidence_cut(root)
    need(record["evidenceInputs"] == evidence and all(
        isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value)
        for value in evidence.values()), "all direct original evidence bytes must exist unchanged")
    need(record["python"] == sys.version
         and record["pythonExecutable"] == str(Path(sys.executable).resolve())
         and record["pythonExecutableSHA256"] == file_sha256(Path(sys.executable)),
         "exact original Python runtime")
    selectors = record["environmentSelectors"]
    need(type(selectors) is dict and not set(selectors) - {"AUTOTECHNO_BASELINE_CAPTURE_PROOF"}
         and all(type(value) is str and 0 < len(value) <= 4096
                 for value in selectors.values()), "unregistered original environment selector")
    def timestamp(value: Any) -> datetime.datetime:
        need(type(value) is str and len(value) <= 64, "bounded original UTC timestamp")
        try:
            result = datetime.datetime.fromisoformat(value)
        except ValueError as exc:
            raise PhaseOneGateError("invalid original receipt timestamp") from exc
        need(result.tzinfo is not None and result.utcoffset() == datetime.timedelta(0),
             "UTC receipt timestamp required")
        return result
    started = timestamp(record["startedUTC"]); finished = timestamp(record["finishedUTC"])
    need(started <= finished, "original execution chronology")
    checks = record["checks"]
    need(type(checks) is list and len(checks) == 19, "all nineteen original command rows required")
    previous = started
    for index, ((identifier, arguments), row) in enumerate(zip(CHECKS, checks)):
        name = f"{index+1:02d}-{identifier}.log"
        need(type(row) is dict and set(row) == {
            "id", "command", "log", "startedUTC", "finishedUTC", "exitCode", "logBytes", "logSHA256"
        }, "closed original command row")
        need(row["id"] == identifier and row["command"] == check_command(root, identifier, arguments)
             and row["log"] == name, "original command/order/output path differs")
        need(type(row["exitCode"]) is int and row["exitCode"] == 0,
             "original subordinate did not exit zero")
        begin = timestamp(row["startedUTC"]); end = timestamp(row["finishedUTC"])
        need(previous <= begin <= end <= finished, "sequential original child chronology")
        previous = end
        output = read(name, MAX_EXECUTION_LOG)
        need(type(row["logBytes"]) is int and row["logBytes"] == len(output)
             and row["logSHA256"] == inputs[name], "original subordinate bytes differ")
        try:
            output.decode("utf-8")
        except UnicodeError as exc:
            raise PhaseOneGateError("original subordinate output is not UTF-8") from exc
    aggregate = read("original-aggregate.log", MAX_EXECUTION_LOG)
    need(record["aggregateLogSHA256"] == inputs["original-aggregate.log"], "original aggregate bytes differ")
    need(aggregate == (
        f"phase-1 evidence gate is current: passed, {len(lifecycle.NODES)} artifacts\n"
    ).encode(), "one exact canonical aggregate receipt, not arbitrary passed JSON")
    for suffix, field in [("before", "derivedAssessmentBeforeSHA256"),
                          ("after", "derivedAssessmentAfterSHA256")]:
        name = suffix + "-lifecycle-assessment.json"
        digest = record[field]
        if digest is None:
            need(suffix == "before" and not (directory / name).exists(),
                 "missing after assessment or unexpected before assessment")
        else:
            assessment = read(name, 4 * 1024 * 1024)
            need(digest == inputs[name], "original derived assessment bytes differ")
            if suffix == "after":
                current = root / ASSESSMENT_PATH
                need(not current.is_symlink() and current.is_file()
                     and current.resolve().is_relative_to(root)
                     and current.stat().st_size == len(assessment)
                     and assessment == current.read_bytes(),
                     "current derived assessment differs from original after bytes")
    need({path.name for path in directory.iterdir()} == set(inputs),
         "unregistered file/directory in original execution namespace")
    need(execution_source_cut(root, source) == before
         and execution_evidence_cut(root) == evidence
         and file_sha256(Path(sys.executable)) == record["pythonExecutableSHA256"]
         and all(file_sha256(directory / name) == digest for name, digest in inputs.items()),
         "original source/evidence/receipt changed during audit")
    return {
        "schema": "autotechno-phase-one-original-receipt-audit.v1", "source": source,
        "executionRecordSHA256": expected_record_sha256, "originalFiles": inputs,
        "originalCommandRecords": 19, "commandReceiptIntegrityVerified": True,
        "originalGateReportedPassed": True, "directSourceAndEvidenceBytesUnchanged": True,
        "subordinateCommandsExecutedByAudit": 0, "nativeProbesExecutedByAudit": 0,
        "externalRetainedCaptureProofAuthenticated": False,
        "subordinateProductContentsQualified": False, "phaseOneQualification": False,
        "runtimeQualification": False, "automatedQualityQualification": False,
        "item39Complete": False,
    }


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("generate", "check", "validate", "verify-execution"))
    parser.add_argument("--execution-directory", type=Path, help="Preserve original check execution outside the immutable source checkout")
    parser.add_argument("--source", help="Exact clean Git commit required with --execution-directory")
    parser.add_argument("--record-sha256", help="Independently pinned original-execution.json SHA256 for a read-only receipt audit")
    args = parser.parse_args(argv)
    if args.command == "verify-execution":
        if args.execution_directory is None or args.source is None or args.record_sha256 is None:
            parser.error("verify-execution requires --execution-directory, --source and --record-sha256")
    elif args.record_sha256 is not None or (
            (args.execution_directory is not None or args.source is not None) and (
                args.command != "check" or args.execution_directory is None or args.source is None)):
        parser.error("recording requires check, --execution-directory and --source; receipt hash is audit-only")
    return args


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    root = repository_root()
    try:
        if args.command == "verify-execution":
            result = audit_recorded_check(root, args.execution_directory, args.source, args.record_sha256)
            print(json.dumps(result, sort_keys=True))
            return 0
        if args.command == "generate":
            return run_generate(root, sys.stdout)
        if args.command == "check":
            if args.execution_directory is not None:
                return run_recorded_check(root, args.execution_directory, args.source, sys.stdout)
            return run_check(root, sys.stdout)
        return run_validate(root, sys.stdout)
    except (PhaseOneGateError, lifecycle.BaselineLifecycleError, OSError, subprocess.SubprocessError) as exc:
        print(f"phase-1 gate error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
