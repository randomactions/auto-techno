#!/usr/bin/env python3
"""Generate and validate Auto Techno's evidence-ranked deficit register."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Mapping, Optional, Sequence, TextIO


SCHEMA = "autotechno-deficit-register.v1"
REGISTER_VERSION = 1
REGISTER_PATH = Path("docs/DEFICIT_REGISTER.json")
MARKDOWN_PATH = Path("docs/DEFICIT_REGISTER.md")
BASELINE_PATH = Path("docs/ROADMAP_EXECUTION_BASELINE.json")
CORPUS_PATH = Path("docs/BASELINE_CORPUS.json")
ROADMAP_PATH = Path("docs/local/SYNTH_FX_DSP_RESEARCH_STUDY.md")
HEX64 = re.compile(r"[0-9a-f]{64}")
HEX40_OR_64 = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})")
DEFICIT_ID = re.compile(r"DEF-[0-9]{4}")
OBSERVATION_ID = re.compile(r"OBS-[0-9]{4}")
ROADMAP_ID = re.compile(r"AT-[0-9]{4}")

SOURCE_SPECS = (
    (
        "signal-integrity",
        Path("docs/local/reports/signal-baseline-v1/manifest.json"),
        "autotechno-signal-baseline-report.v1",
    ),
    (
        "spectral",
        Path("docs/local/reports/spectral-baseline-v1/manifest.json"),
        "autotechno-spectral-baseline-report.v1",
    ),
    (
        "kick-foundation-collision",
        Path("docs/local/reports/kick-foundation-collision-v1/manifest.json"),
        "autotechno-kick-foundation-collision-report.v1",
    ),
    (
        "rhythmic",
        Path("docs/local/reports/rhythmic-baseline-v1/manifest.json"),
        "autotechno-rhythmic-baseline-report.v1",
    ),
    (
        "score-motif",
        Path("docs/local/reports/score-motif-baseline-v1/manifest.json"),
        "autotechno-score-motif-baseline-report.v1",
    ),
    (
        "section-boundary",
        Path("docs/local/reports/section-boundary-baseline-v1/report.json"),
        "autotechno-section-boundary-baseline-report.v1",
    ),
    (
        "long-horizon",
        Path("docs/local/reports/long-horizon-session-baseline-v1/report.json"),
        "autotechno-long-horizon-session-baseline-report.v1",
    ),
    (
        "performance-envelope",
        Path("docs/local/reports/performance-envelope-v1/report.json"),
        "autotechno-performance-envelope-report.v1",
    ),
)

ROOT_KEYS = {
    "schema", "registerVersion", "registerFingerprint", "generatedFrom",
    "rankingPolicy", "entries", "quarantinedObservations", "qualification",
}
GENERATED_KEYS = {
    "contractBaselineFingerprint", "corpusSha256", "engineVersion", "gitHead",
    "sources",
}
SOURCE_KEYS = {
    "id", "path", "schema", "fileSha256", "reportFingerprint",
    "sourceFingerprint",
}
RANKING_KEYS = {
    "purpose", "comparator", "actionClasses", "severityLevels",
    "confidenceLevels", "aggregateScore", "prevalenceMeaning",
}
ENTRY_KEYS = {
    "id", "title", "deficitKind", "status", "actionClass", "prevalence",
    "severity", "confidence", "owner", "evidence", "nearestRoadmapItems",
    "limitations", "disposition", "qualityClaim", "promotionAuthorized",
}
ACTION_KEYS = {"id", "ordinal"}
PREVALENCE_KEYS = {
    "kind", "numerator", "denominator", "unit", "ratio", "scope",
    "affectedCaseIds", "affectedRouteIds", "affectedAssetIds",
}
SEVERITY_KEYS = {"level", "ordinal", "impactDomain", "basis"}
CONFIDENCE_KEYS = {"level", "ordinal", "basis", "scopeLimit"}
OWNER_KEYS = {"layer", "canonicalOwner", "evidenceOwner"}
EVIDENCE_KEYS = {"sourceId", "reportFingerprint", "observation"}
ROADMAP_LINK_KEYS = {"id", "outcome"}
OBSERVATION_KEYS = {
    "id", "title", "sourceId", "observation", "reasonNotDeficit",
}
QUALIFICATION_KEYS = {
    "status", "calibratedAuditoryDefectCount", "runtimeInput",
    "promotionAuthorized", "limitations",
}

ACTION_CLASSES = {
    "technical-risk": 0,
    "decision-blocking-evidence-gap": 1,
    "deferred-coverage-gap": 2,
}
SEVERITY_LEVELS = {
    "unassessed": 0,
    "minor": 1,
    "moderate": 2,
    "major": 3,
    "hard-failure": 4,
}
CONFIDENCE_LEVELS = {
    "unavailable": 0,
    "low": 1,
    "moderate": 2,
    "high": 3,
}
DEFICIT_KINDS = {
    "technical-risk", "calibration-gap", "attribution-gap", "coverage-gap",
}
DISPOSITION = "ranked-evidence-only-not-authorized"
COMPARATOR = [
    "severity.ordinal descending",
    "actionClass.ordinal ascending",
    "confidence.ordinal descending",
    "lowest nearestRoadmapItems numeric ID ascending",
    "id ascending",
]


class DeficitRegisterError(RuntimeError):
    """A fail-closed register generation or validation error."""


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
        raise DeficitRegisterError(f"missing {label}: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise DeficitRegisterError(f"cannot read {label} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise DeficitRegisterError(f"{label} root must be an object: {path}")
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
        path,
        json.dumps(value, indent=2, ensure_ascii=True, sort_keys=True) + "\n",
    )


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    if set(value) != expected:
        errors.append(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(value)}"
        )


def bounded_text(value: object, maximum: int = 1000) -> bool:
    return isinstance(value, str) and bool(value.strip()) and len(value) <= maximum


def string_list(
    value: object, location: str, errors: list[str], maximum_count: int,
    pattern: re.Pattern[str] | None = None,
) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{location} must be an array")
        return []
    if len(value) > maximum_count:
        errors.append(f"{location} exceeds {maximum_count} items")
    result: list[str] = []
    for index, item in enumerate(value):
        if not bounded_text(item, 500):
            errors.append(f"{location}[{index}] must be bounded non-empty text")
        elif pattern is not None and pattern.fullmatch(item) is None:
            errors.append(f"{location}[{index}] has an invalid identifier")
        else:
            result.append(item)
    if len(result) != len(set(result)):
        errors.append(f"{location} must not contain duplicates")
    return result


def report_fingerprint_valid(report: Mapping[str, Any]) -> bool:
    given = report.get("reportFingerprint")
    return isinstance(given, str) and HEX64.fullmatch(given) is not None and (
        given == fingerprint(report, "reportFingerprint")
    )


def load_current_sources(
    root: Path,
) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    baseline = load_json(root / BASELINE_PATH, "contract baseline")
    baseline_fingerprint = baseline.get("snapshotFingerprint")
    if not isinstance(baseline_fingerprint, str) or HEX64.fullmatch(baseline_fingerprint) is None:
        raise DeficitRegisterError("contract baseline has no valid snapshotFingerprint")
    # The baseline fingerprint intentionally covers only its ordered document array.
    calculated = hashlib.sha256(canonical_bytes(baseline.get("documents", []))).hexdigest()
    if baseline_fingerprint != calculated:
        raise DeficitRegisterError("contract baseline snapshotFingerprint is invalid")
    corpus_sha256 = file_digest(root / CORPUS_PATH)
    reports: dict[str, dict[str, Any]] = {}
    source_records: list[dict[str, Any]] = []
    engine_versions: set[str] = set()
    git_heads: set[str] = set()
    for source_id, relative_path, expected_schema in SOURCE_SPECS:
        path = root / relative_path
        report = load_json(path, f"{source_id} report")
        if report.get("schema") != expected_schema:
            raise DeficitRegisterError(
                f"{source_id} schema must be {expected_schema}"
            )
        if not report_fingerprint_valid(report):
            raise DeficitRegisterError(f"{source_id} reportFingerprint is invalid")
        if report.get("contractBaselineFingerprint") != baseline_fingerprint:
            raise DeficitRegisterError(
                f"{source_id} report uses a stale contract baseline"
            )
        if "corpusSha256" in report and report.get("corpusSha256") != corpus_sha256:
            raise DeficitRegisterError(f"{source_id} report uses a stale corpus")
        engine_version = report.get("engineVersion")
        git_head = report.get("gitHead")
        source_fingerprint = report.get("sourceFingerprint")
        if not bounded_text(engine_version, 200):
            raise DeficitRegisterError(f"{source_id} has no engineVersion")
        if not isinstance(git_head, str) or HEX40_OR_64.fullmatch(git_head) is None:
            raise DeficitRegisterError(f"{source_id} has no exact gitHead")
        if not isinstance(source_fingerprint, str) or HEX64.fullmatch(source_fingerprint) is None:
            raise DeficitRegisterError(f"{source_id} has no sourceFingerprint")
        engine_versions.add(engine_version)
        git_heads.add(git_head)
        reports[source_id] = report
        source_records.append({
            "id": source_id,
            "path": relative_path.as_posix(),
            "schema": expected_schema,
            "fileSha256": file_digest(path),
            "reportFingerprint": report["reportFingerprint"],
            "sourceFingerprint": source_fingerprint,
        })
    if len(engine_versions) != 1:
        raise DeficitRegisterError("source reports disagree on engineVersion")
    if len(git_heads) != 1:
        raise DeficitRegisterError("source reports disagree on gitHead")
    generated_from = {
        "contractBaselineFingerprint": baseline_fingerprint,
        "corpusSha256": corpus_sha256,
        "engineVersion": next(iter(engine_versions)),
        "gitHead": next(iter(git_heads)),
        "sources": source_records,
    }
    return reports, generated_from


def case_id_from_asset_id(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    candidate = value.split("::", 1)[0].split("--native-stereo-", 1)[0]
    return candidate if candidate.startswith("ATBC-V1-") else None


def route_id_from_asset_id(value: object) -> str | None:
    if not isinstance(value, str) or "--native-stereo-" not in value:
        return None
    return "native-stereo-" + value.split("--native-stereo-", 1)[1].split("::", 1)[0]


def sorted_unique(values: Sequence[object]) -> list[str]:
    return sorted({value for value in values if isinstance(value, str) and value})


def prevalence(
    numerator: int, denominator: int, unit: str, scope: str,
    *, case_ids: Sequence[object] = (), route_ids: Sequence[object] = (),
    asset_ids: Sequence[object] = (), kind: str = "affected-units-in-bounded-corpus",
) -> dict[str, Any]:
    if denominator <= 0 or numerator < 0 or numerator > denominator:
        raise DeficitRegisterError(
            f"invalid prevalence {numerator}/{denominator} {unit}"
        )
    return {
        "kind": kind,
        "numerator": numerator,
        "denominator": denominator,
        "unit": unit,
        "ratio": round(numerator / denominator, 9),
        "scope": scope,
        "affectedCaseIds": sorted_unique(case_ids),
        "affectedRouteIds": sorted_unique(route_ids),
        "affectedAssetIds": sorted_unique(asset_ids),
    }


def severity(level: str, impact_domain: str, basis: str) -> dict[str, Any]:
    return {
        "level": level,
        "ordinal": SEVERITY_LEVELS[level],
        "impactDomain": impact_domain,
        "basis": basis,
    }


def confidence(level: str, basis: str, scope_limit: str) -> dict[str, Any]:
    return {
        "level": level,
        "ordinal": CONFIDENCE_LEVELS[level],
        "basis": basis,
        "scopeLimit": scope_limit,
    }


def action_class(identifier: str) -> dict[str, Any]:
    return {"id": identifier, "ordinal": ACTION_CLASSES[identifier]}


def source_evidence(
    reports: Mapping[str, Mapping[str, Any]], source_id: str, observation: str
) -> dict[str, Any]:
    return {
        "sourceId": source_id,
        "reportFingerprint": reports[source_id]["reportFingerprint"],
        "observation": observation,
    }


def owner(layer: str, canonical: str, evidence_owner: str) -> dict[str, str]:
    return {
        "layer": layer,
        "canonicalOwner": canonical,
        "evidenceOwner": evidence_owner,
    }


def roadmap_link(identifier: str, outcome: str) -> dict[str, str]:
    return {"id": identifier, "outcome": outcome}


def make_entry(
    identifier: str, title: str, deficit_kind: str, action: str,
    prevalence_value: Mapping[str, Any], severity_value: Mapping[str, Any],
    confidence_value: Mapping[str, Any], owner_value: Mapping[str, Any],
    evidence: Sequence[Mapping[str, Any]], roadmap_items: Sequence[Mapping[str, str]],
    limitations: Sequence[str],
) -> dict[str, Any]:
    return {
        "id": identifier,
        "title": title,
        "deficitKind": deficit_kind,
        "status": "open",
        "actionClass": dict(action_class(action)),
        "prevalence": dict(prevalence_value),
        "severity": dict(severity_value),
        "confidence": dict(confidence_value),
        "owner": dict(owner_value),
        "evidence": [dict(item) for item in evidence],
        "nearestRoadmapItems": [dict(item) for item in roadmap_items],
        "limitations": list(limitations),
        "disposition": DISPOSITION,
        "qualityClaim": False,
        "promotionAuthorized": False,
    }


def priority_key(entry: Mapping[str, Any]) -> tuple[int, int, int, int, str]:
    nearest = entry.get("nearestRoadmapItems", [])
    ordinals = [
        int(item["id"].split("-")[1])
        for item in nearest
        if isinstance(item, dict) and isinstance(item.get("id"), str)
        and ROADMAP_ID.fullmatch(item["id"])
    ]
    return (
        -int(entry["severity"]["ordinal"]),
        int(entry["actionClass"]["ordinal"]),
        -int(entry["confidence"]["ordinal"]),
        min(ordinals) if ordinals else 9999,
        str(entry["id"]),
    )


def build_entries(
    reports: Mapping[str, Mapping[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    entries: list[dict[str, Any]] = []
    quarantined: list[dict[str, str]] = []

    rhythmic_assets = reports["rhythmic"].get("assets", [])
    missing_score_binding = [
        item for item in rhythmic_assets
        if isinstance(item, dict)
        and isinstance(item.get("evidence"), dict)
        and str(item["evidence"].get("scoreBindingStatus", "")).startswith("unavailable")
    ]
    if missing_score_binding:
        entries.append(make_entry(
            "DEF-0001",
            "Rendered rhythmic onsets are not bound to accepted score events",
            "attribution-gap",
            "decision-blocking-evidence-gap",
            prevalence(
                len(missing_score_binding), len(rhythmic_assets), "whole-mix-assets",
                "current rhythmic baseline assets whose PCM-inferred onsets lack score-event binding",
                case_ids=[case_id_from_asset_id(item.get("assetId")) for item in missing_score_binding],
                route_ids=[route_id_from_asset_id(item.get("assetId")) for item in missing_score_binding],
                asset_ids=[item.get("assetId") for item in missing_score_binding],
            ),
            severity(
                "moderate", "evidence-attribution",
                "The gap blocks causal score-versus-render rhythm calibration but is not an audible-failure verdict.",
            ),
            confidence(
                "high",
                "Every current whole-mix rhythmic record explicitly declares score binding unavailable.",
                "Exact only for the 14 outcome-blind Phase-1 whole-mix assets.",
            ),
            owner(
                "AutoTechnoDSP detached evidence",
                "AutonomousPhrasePlan and the accepted resolved score",
                "PCMRhythmicBaselineAnalyzer",
            ),
            [source_evidence(
                reports, "rhythmic",
                f"{len(missing_score_binding)}/{len(rhythmic_assets)} assets declare unavailable score binding.",
            )],
            [
                roadmap_link("AT-0038", "Add segment-, role-, band-, and horizon-local feature aggregation"),
                roadmap_link("AT-0040", "Calibrate transient, density, and fatigue evidence"),
            ],
            [
                "PCM onset inference can fold stereo cancellation and cannot identify authored score events.",
                "No groove preference or defect threshold exists yet.",
            ],
        ))

    collision_entries = reports["kick-foundation-collision"].get("entries", [])
    collision_events: list[Mapping[str, Any]] = []
    collision_case_ids: list[object] = []
    collision_route_ids: list[object] = []
    low_overlap_count = 0
    for item in collision_entries:
        if not isinstance(item, dict) or not isinstance(item.get("evidence"), dict):
            continue
        events = item["evidence"].get("events", [])
        if not isinstance(events, list):
            continue
        collision_events.extend(event for event in events if isinstance(event, dict))
        collision_case_ids.append(item.get("caseId"))
        collision_route_ids.append(item.get("routeId"))
        low_overlap_count += sum(
            event.get("collisionClass") == "low-band-overlap"
            for event in events if isinstance(event, dict)
        )
    if collision_events:
        entries.append(make_entry(
            "DEF-0002",
            "Kick/foundation collision classes have no calibrated quality interpretation",
            "calibration-gap",
            "decision-blocking-evidence-gap",
            prevalence(
                len(collision_events), len(collision_events), "score-bound-kick-events",
                "events with exact descriptive collision evidence but no safe/conflicted calibration",
                case_ids=collision_case_ids,
                route_ids=collision_route_ids,
            ),
            severity(
                "moderate", "evaluator-calibration",
                "The gap prevents overlap observations from informing selection; overlap itself is not classified as bad sound.",
            ),
            confidence(
                "high",
                "All current events use the explicit descriptive-not-calibrated interpretation.",
                "The causal 35-120 Hz cells are non-power-complementary and event-local.",
            ),
            owner(
                "AutoTechnoDSP detached evidence",
                "Accepted score events, VoiceRenderer role taps, and SpectrumMaskingAnalyzer",
                "PCMKickFoundationCollisionAnalyzer",
            ),
            [source_evidence(
                reports, "kick-foundation-collision",
                f"{low_overlap_count}/{len(collision_events)} events are descriptively low-band-overlap; all lack calibrated severity.",
            )],
            [roadmap_link("AT-0039", "Calibrate kick/bass masking and groove metrics against independent fixtures")],
            [
                "Overlap may be intentional, constructive, phase-dependent, or perceptually masked.",
                "Relative energy is explicitly descriptive and not an excessive-level verdict.",
            ],
        ))
        quarantined.append({
            "id": "OBS-0001",
            "title": "Low-band overlap event count",
            "sourceId": "kick-foundation-collision",
            "observation": f"{low_overlap_count}/{len(collision_events)} exact score-bound kick events are classified low-band-overlap.",
            "reasonNotDeficit": "The canonical report explicitly supplies no perceptual, phase, or artistic severity calibration.",
        })

    spectral_assets = reports["spectral"].get("assets", [])
    spectral_windows = sum(
        int(item.get("evidence", {}).get("summary", {}).get("windowCount", 0))
        for item in spectral_assets if isinstance(item, dict)
        and isinstance(item.get("evidence"), dict)
        and isinstance(item["evidence"].get("summary"), dict)
    )
    if spectral_windows:
        entries.append(make_entry(
            "DEF-0003",
            "Spectral shape and occupancy observations are uncalibrated",
            "calibration-gap",
            "decision-blocking-evidence-gap",
            prevalence(
                spectral_windows, spectral_windows, "fixed-spectral-windows",
                "current windows with descriptive shape/occupancy evidence and no artistic threshold",
                case_ids=[case_id_from_asset_id(item.get("assetId")) for item in spectral_assets if isinstance(item, dict)],
                route_ids=[route_id_from_asset_id(item.get("assetId")) for item in spectral_assets if isinstance(item, dict)],
            ),
            severity(
                "moderate", "evaluator-calibration",
                "The gap blocks trustworthy harshness, dullness, and spectral-crowding decisions without asserting those defects exist.",
            ),
            confidence(
                "high",
                "The current spectral contract explicitly describes features without preference thresholds.",
                "Band filters overlap and are not power-complementary; silence and role taps are included.",
            ),
            owner(
                "AutoTechnoDSP detached evidence",
                "SpectrumMaskingAnalyzer causal bands and spectral-shape evidence",
                "PCMSpectralBaselineAnalyzer",
            ),
            [source_evidence(
                reports, "spectral",
                f"{spectral_windows} source-bound windows expose descriptive spectral features only.",
            )],
            [roadmap_link("AT-0041", "Calibrate timbral motion, harshness, dullness, and spectral-crowding evidence")],
            [
                "No reference-free spectral distribution is inherently good or bad for underground techno.",
                "Current role and whole-mix windows are correlated observations, not independent trials.",
            ],
        ))
        quarantined.append({
            "id": "OBS-0002",
            "title": "Spectral distributions and low-end occupancy",
            "sourceId": "spectral",
            "observation": f"{spectral_windows} windows retain centroid, rolloff, flatness, band, and low-end occupancy facts.",
            "reasonNotDeficit": "No calibrated musical or perceptual target exists for these descriptive values.",
        })

    motif_assets = reports["score-motif"].get("assets", [])
    motif_comparisons = sum(
        int(item.get("evidence", {}).get("summary", {}).get("availableComparisonCount", 0))
        for item in motif_assets if isinstance(item, dict)
        and isinstance(item.get("evidence"), dict)
        and isinstance(item["evidence"].get("summary"), dict)
    )
    if motif_comparisons:
        entries.append(make_entry(
            "DEF-0004",
            "Symbolic motif recurrence has no salience or coherent-variation calibration",
            "calibration-gap",
            "decision-blocking-evidence-gap",
            prevalence(
                motif_comparisons, motif_comparisons, "available-score-motif-comparisons",
                "comparisons with separate symbolic dimensions but no perceptual salience ranking",
                case_ids=[item.get("caseId") for item in motif_assets if isinstance(item, dict)],
                route_ids=[item.get("routeId") for item in motif_assets if isinstance(item, dict)],
            ),
            severity(
                "moderate", "evaluator-calibration",
                "The gap blocks distinguishing purposeful identity/variation from over-repetition or churn in policy.",
            ),
            confidence(
                "high",
                "Every comparison is exact accepted-score evidence and the contract explicitly denies PCM salience.",
                "Only eligible upper roles within each accepted phrase are compared.",
            ),
            owner(
                "AutoTechnoCore score evidence",
                "AutonomousPhrasePlan and resolved upper-note score",
                "ScoreMotifBaselineAnalyzer",
            ),
            [source_evidence(
                reports, "score-motif",
                f"{motif_comparisons} available symbolic comparisons have no calibrated salience or preference interpretation.",
            )],
            [roadmap_link("AT-0044", "Calibrate motif identity, variation, phrase grammar, and arrangement contrast evidence")],
            [
                "The report does not infer whether a scored motif is audible after synthesis and mixing.",
                "Route duplicates share score evidence and are not independent musical cases.",
            ],
        ))
        quarantined.append({
            "id": "OBS-0003",
            "title": "Motif recurrence and mutation counts",
            "sourceId": "score-motif",
            "observation": f"{motif_comparisons} available comparisons separate exact, contour, normalized, timing, pitch, register, density, and role relations.",
            "reasonNotDeficit": "No calibrated salience, coherent-development, or over-repetition boundary exists.",
        })

    section = reports["section-boundary"]
    section_summary = section.get("summary", {})
    boundary_count = int(section_summary.get("boundaryCount", 0)) if isinstance(section_summary, dict) else 0
    recovery_counts = section_summary.get("jointRecoveryStatusCounts", {}) if isinstance(section_summary, dict) else {}
    not_observed = int(recovery_counts.get("not-observed-within-horizon", 0)) if isinstance(recovery_counts, dict) else 0
    unavailable_recovery = sum(
        int(value) for key, value in recovery_counts.items()
        if isinstance(key, str) and key.startswith("unavailable-") and isinstance(value, int)
    ) if isinstance(recovery_counts, dict) else 0
    if boundary_count:
        entries.append(make_entry(
            "DEF-0005",
            "Section contrast and recovery states lack transition-quality calibration",
            "calibration-gap",
            "decision-blocking-evidence-gap",
            prevalence(
                boundary_count, boundary_count, "score-declared-boundaries",
                "boundaries with descriptive per-dimension evidence and no coherent-transition threshold",
                asset_ids=[item.get("id") for item in section.get("entries", []) if isinstance(item, dict)],
            ),
            severity(
                "moderate", "evaluator-calibration",
                "The gap blocks classification of abrupt, unresolved, or coherent transitions without calling absence of joint recovery a defect.",
            ),
            confidence(
                "high",
                "All boundary and recovery statuses are independently reconstructed from exact score-aligned PCM contexts.",
                "Contexts contain at most three phrases and cannot establish long-horizon consequence.",
            ),
            owner(
                "AutoTechnoDSP detached evidence",
                "AutonomousSessionDirector, accepted phrase boundaries, and exact context PCM",
                "PCMSectionBoundaryBaselineAnalyzer",
            ),
            [source_evidence(
                reports, "section-boundary",
                f"{boundary_count} boundaries include {not_observed} joint recoveries not observed in horizon and {unavailable_recovery} unavailable, all descriptively.",
            )],
            [roadmap_link("AT-0045", "Calibrate transition preparation, consequence, and recovery evidence")],
            [
                "Joint return across every metric may be neither necessary nor desirable.",
                "Missing pre/post context is evidence unavailability, not failed recovery.",
            ],
        ))
        quarantined.append({
            "id": "OBS-0004",
            "title": "Joint section recovery status",
            "sourceId": "section-boundary",
            "observation": f"{not_observed}/{boundary_count} boundaries do not show joint recovery within the bounded context; {unavailable_recovery} are unavailable.",
            "reasonNotDeficit": "The report has no calibrated requirement for every dimension to return jointly within three phrases.",
        })

    long_horizon = reports["long-horizon"]
    long_summary = long_horizon.get("summary", {})
    long_entries = long_horizon.get("entries", [])
    realized_unavailable = (
        isinstance(long_summary, dict)
        and long_summary.get("realizedSignalAvailability") == "unavailable"
    )
    if realized_unavailable and long_entries:
        entries.append(make_entry(
            "DEF-0006",
            "Four-hour trajectories lack continuous realized-PCM evidence",
            "coverage-gap",
            "decision-blocking-evidence-gap",
            prevalence(
                len(long_entries), len(long_entries), "four-hour-score-journeys",
                "current journeys observed through score planning without continuous realized signal",
                case_ids=[item.get("caseId") for item in long_entries if isinstance(item, dict)],
            ),
            severity(
                "moderate", "long-horizon-evidence",
                "The gap blocks calibration of realized arc, exposure, and fatigue proxies over set length.",
            ),
            confidence(
                "high",
                "The report explicitly marks realized signal and quality qualification unavailable for every journey.",
                "Score-only planning is exact but cannot establish continuous audio behavior or listener fatigue.",
            ),
            owner(
                "AutoTechnoCore detached session evidence",
                "AutonomousSessionDirector and LongHorizonContinuationState",
                "LongHorizonSessionBaselineAnalyzer",
            ),
            [source_evidence(
                reports, "long-horizon",
                f"{len(long_entries)}/{len(long_entries)} four-hour journeys have no continuous realized-PCM observation.",
            )],
            [
                roadmap_link("AT-0046", "Calibrate long-horizon arc, peak scarcity, return, reset, and landing evidence"),
                roadmap_link("AT-0067", "Build deterministic long-run scheduling and resource-soak harnesses"),
            ],
            [
                "The existing score-only trajectory is not a continuous audio render.",
                "Listener fatigue and perceived peak authority remain unknown.",
            ],
        ))
        payoff_count = int(long_summary.get("payoffMarkerCount", 0))
        unresolved = int(long_summary.get("unresolvedPayoffCount", 0))
        quarantined.append({
            "id": "OBS-0005",
            "title": "Unresolved score-declared payoffs",
            "sourceId": "long-horizon",
            "observation": f"{unresolved}/{payoff_count} score-declared payoff markers have no later recovery marker within the observed horizon.",
            "reasonNotDeficit": "End-of-horizon state and intended long consequences are not calibrated as perceptual failure.",
        })

    signal_assets = reports["signal-integrity"].get("assets", [])
    total_samples = 0
    subnormal_samples = 0
    affected_signal_assets: list[Mapping[str, Any]] = []
    for item in signal_assets:
        if not isinstance(item, dict) or not isinstance(item.get("evidence"), dict):
            continue
        combined = item["evidence"].get("combined", {})
        if not isinstance(combined, dict):
            continue
        total_samples += int(combined.get("sampleCount", 0))
        count = int(combined.get("subnormalSampleCount", 0))
        subnormal_samples += count
        if count:
            affected_signal_assets.append(item)
    if subnormal_samples:
        entries.append(make_entry(
            "DEF-0007",
            "Subnormal Float32 samples remain visible in role/reference evidence",
            "technical-risk",
            "technical-risk",
            prevalence(
                subnormal_samples, total_samples, "decoded-channel-samples",
                f"{len(affected_signal_assets)} affected assets within the exact whole/role signal baseline",
                case_ids=[case_id_from_asset_id(item.get("assetId")) for item in affected_signal_assets],
                route_ids=[route_id_from_asset_id(item.get("assetId")) for item in affected_signal_assets],
                asset_ids=[item.get("assetId") for item in affected_signal_assets],
            ),
            severity(
                "minor", "signal-integrity-and-performance-risk",
                "Subnormals are a real numeric condition, but no whole-mix fault or callback anomaly is currently observed.",
            ),
            confidence(
                "high",
                "Counts are exact decoded Float32 facts with zero non-finite and clipping samples in the same corpus.",
                "Affected diagnostic/reference assets are correlated and do not prove audible output or CPU harm.",
            ),
            owner(
                "AutoTechnoDSP rendering and signal evidence",
                "VoiceRenderer role and processed-stage signal paths",
                "PCMSignalIntegrityAnalyzer",
            ),
            [source_evidence(
                reports, "signal-integrity",
                f"{subnormal_samples}/{total_samples} samples across {len(affected_signal_assets)}/{len(signal_assets)} assets are subnormal.",
            )],
            [
                roadmap_link("AT-0036", "Separate hard safety gates from descriptive features, musical heuristics, and calibrated quality vectors"),
                roadmap_link("AT-0060", "Preallocate and bound the canonical DSP graph and per-session resources"),
            ],
            [
                "The exact same signal may appear in a role and reconstruction reference, so counts are not independent events.",
                "No denormal-specific callback slowdown or audible defect has been measured.",
            ],
        ))

    performance = reports["performance-envelope"]
    coverage = performance.get("coverage", {})
    host_classes = coverage.get("hostClasses", []) if isinstance(coverage, dict) else []
    unavailable_hosts = [
        item for item in host_classes
        if isinstance(item, dict) and item.get("status") == "unavailable"
    ]
    if unavailable_hosts:
        entries.append(make_entry(
            "DEF-0008",
            "Native host and corpus performance coverage is incomplete",
            "coverage-gap",
            "deferred-coverage-gap",
            prevalence(
                len(unavailable_hosts), len(host_classes), "declared-host-classes",
                "host classes without native bounded performance observation",
                kind="missing-evidence-scopes-in-declared-matrix",
            ),
            severity(
                "unassessed", "platform-performance-coverage",
                "No consequence can be assigned until the unavailable native host is measured.",
            ),
            confidence(
                "high",
                "The envelope explicitly records Windows unavailable and one of seven corpus cases timed on macOS.",
                "Observed macOS timing cannot be transferred to Windows or unmeasured musical geometries.",
            ),
            owner(
                "AutoTechnoApp host transport and detached evidence",
                "Supported host route lifecycle and AutonomousPerformancePreparer",
                "PerformanceEnvelopeIntegrationTests and performance_envelope_report.py",
            ),
            [source_evidence(
                reports, "performance-envelope",
                f"{len(unavailable_hosts)}/{len(host_classes)} declared host classes are unavailable; one largest-frame corpus case is timed.",
            )],
            [
                roadmap_link("AT-0355", "Qualify supported sample rates, buffer sizes, channel layouts, and route changes"),
                roadmap_link("AT-0358", "Bound CPU, memory, battery/thermal pressure, disk use, and preparation lead time"),
            ],
            [
                "The current macOS values are one-machine descriptive observations, not capacity thresholds.",
                "Windows remains a source-buildable candidate rather than a promoted binary.",
            ],
        ))
    qualification = performance.get("qualification", {})
    if isinstance(qualification, dict) and qualification.get("physicalSoakClaim") is False:
        entries.append(make_entry(
            "DEF-0009",
            "Long physical-output soak evidence is unavailable",
            "coverage-gap",
            "deferred-coverage-gap",
            prevalence(
                1, 1, "declared-physical-soak-evidence-scopes",
                "required long physical-output soak scope currently missing",
                kind="missing-evidence-scopes-in-declared-matrix",
            ),
            severity(
                "unassessed", "physical-runtime-reliability",
                "A bounded external trace cannot establish the consequence or likelihood of long-run route faults.",
            ),
            confidence(
                "high",
                "The performance qualification explicitly denies a physical-soak claim.",
                "The retained Audio System Trace covers about ten seconds on one 44.1 kHz stereo route.",
            ),
            owner(
                "AutoTechnoApp route lifecycle",
                "TechnoEngine scheduling, interruption, and device-route state",
                "Performance envelope external trace",
            ),
            [source_evidence(
                reports, "performance-envelope",
                "Physical soak is explicitly unclaimed despite a bounded trace with no relevant observed point of interest.",
            )],
            [roadmap_link("AT-0361", "Run multi-hour foreground/background, sleep/wake, interruption, and route-churn soak")],
            [
                "Missing soak evidence is not evidence that an underrun or route failure occurred.",
                "No background, sleep/wake, route-churn, or thermal-duration matrix was run.",
            ],
        ))
        live = performance.get("liveMacOS", {})
        callback_count = live.get("callbackCycleCount", 0) if isinstance(live, dict) else 0
        quarantined.append({
            "id": "OBS-0006",
            "title": "Bounded live callback trace",
            "sourceId": "performance-envelope",
            "observation": f"{callback_count} callback cycles were observed without a relevant point of interest in the retained trace window.",
            "reasonNotDeficit": "An empty short trace is neither a long-soak pass nor evidence of an unobserved fault.",
        })

    entries.sort(key=priority_key)
    quarantined.sort(key=lambda item: item["id"])
    return entries, quarantined


def ranking_policy() -> dict[str, Any]:
    return {
        "purpose": "Deterministic implementation triage without musical-quality scoring or authorization.",
        "comparator": COMPARATOR,
        "actionClasses": [
            {"id": identifier, "ordinal": ordinal}
            for identifier, ordinal in ACTION_CLASSES.items()
        ],
        "severityLevels": [
            {"id": identifier, "ordinal": ordinal}
            for identifier, ordinal in SEVERITY_LEVELS.items()
        ],
        "confidenceLevels": [
            {"id": identifier, "ordinal": ordinal}
            for identifier, ordinal in CONFIDENCE_LEVELS.items()
        ],
        "aggregateScore": None,
        "prevalenceMeaning": "Observed scoped fraction, never probability, importance, severity, or population frequency.",
    }


def build_register(
    reports: Mapping[str, Mapping[str, Any]], generated_from: Mapping[str, Any]
) -> dict[str, Any]:
    entries, quarantined = build_entries(reports)
    register: dict[str, Any] = {
        "schema": SCHEMA,
        "registerVersion": REGISTER_VERSION,
        "registerFingerprint": "",
        "generatedFrom": dict(generated_from),
        "rankingPolicy": ranking_policy(),
        "entries": entries,
        "quarantinedObservations": quarantined,
        "qualification": {
            "status": "evidence-ranked-register-only",
            "calibratedAuditoryDefectCount": 0,
            "runtimeInput": False,
            "promotionAuthorized": False,
            "limitations": [
                "Severity describes bounded technical or evidence consequence, not artistic dislike.",
                "No current entry is a calibrated auditory-quality defect.",
                "The register orders investigation only; the roadmap controller retains authorization.",
            ],
        },
    }
    register["registerFingerprint"] = fingerprint(register, "registerFingerprint")
    return register


def parse_roadmap_items(path: Path) -> dict[str, dict[str, str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise DeficitRegisterError(f"cannot read roadmap: {exc}") from exc
    result: dict[str, dict[str, str]] = {}
    pattern = re.compile(
        r"^\| (AT-[0-9]{4}) \| `([^`]+)` \| [^|]* \| ([^|]+?) \|",
        re.MULTILINE,
    )
    for match in pattern.finditer(text):
        result[match.group(1)] = {
            "status": match.group(2),
            "outcome": match.group(3).strip(),
        }
    if len(result) != 390:
        raise DeficitRegisterError(
            f"roadmap must contain 390 executable items, found {len(result)}"
        )
    return result


def validate_register(
    register: Mapping[str, Any], roadmap_items: Mapping[str, Mapping[str, str]] | None = None,
) -> list[str]:
    errors: list[str] = []
    exact_keys(register, ROOT_KEYS, "register", errors)
    if register.get("schema") != SCHEMA:
        errors.append(f"register.schema must be {SCHEMA}")
    if register.get("registerVersion") != REGISTER_VERSION:
        errors.append("register.registerVersion must be 1")
    if register.get("registerFingerprint") != fingerprint(register, "registerFingerprint"):
        errors.append("register.registerFingerprint does not match content")

    generated = register.get("generatedFrom")
    source_ids: set[str] = set()
    source_fingerprints: dict[str, str] = {}
    if not isinstance(generated, dict):
        errors.append("register.generatedFrom must be an object")
    else:
        exact_keys(generated, GENERATED_KEYS, "register.generatedFrom", errors)
        for field in ("contractBaselineFingerprint", "corpusSha256"):
            if not isinstance(generated.get(field), str) or HEX64.fullmatch(generated[field]) is None:
                errors.append(f"register.generatedFrom.{field} must be SHA-256")
        if not bounded_text(generated.get("engineVersion"), 200):
            errors.append("register.generatedFrom.engineVersion must be bounded text")
        if not isinstance(generated.get("gitHead"), str) or HEX40_OR_64.fullmatch(generated["gitHead"]) is None:
            errors.append("register.generatedFrom.gitHead must be an exact Git object ID")
        sources = generated.get("sources")
        if not isinstance(sources, list) or len(sources) != len(SOURCE_SPECS):
            errors.append(f"register must bind exactly {len(SOURCE_SPECS)} sources")
            sources = []
        expected_source_ids = [item[0] for item in SOURCE_SPECS]
        for index, source in enumerate(sources):
            location = f"register.generatedFrom.sources[{index}]"
            if not isinstance(source, dict):
                errors.append(f"{location} must be an object")
                continue
            exact_keys(source, SOURCE_KEYS, location, errors)
            identifier = source.get("id")
            if not bounded_text(identifier, 100):
                errors.append(f"{location}.id must be bounded text")
            else:
                source_ids.add(identifier)
            if index < len(expected_source_ids) and identifier != expected_source_ids[index]:
                errors.append(f"{location}.id is out of canonical order")
            for field in ("fileSha256", "reportFingerprint", "sourceFingerprint"):
                value = source.get(field)
                if not isinstance(value, str) or HEX64.fullmatch(value) is None:
                    errors.append(f"{location}.{field} must be SHA-256")
            if isinstance(identifier, str) and isinstance(source.get("reportFingerprint"), str):
                source_fingerprints[identifier] = source["reportFingerprint"]
            if index < len(SOURCE_SPECS):
                _, expected_path, expected_schema = SOURCE_SPECS[index]
                if source.get("path") != expected_path.as_posix():
                    errors.append(f"{location}.path is not canonical")
                if source.get("schema") != expected_schema:
                    errors.append(f"{location}.schema is not canonical")

    ranking = register.get("rankingPolicy")
    if not isinstance(ranking, dict):
        errors.append("register.rankingPolicy must be an object")
    else:
        exact_keys(ranking, RANKING_KEYS, "register.rankingPolicy", errors)
        if ranking.get("comparator") != COMPARATOR:
            errors.append("register ranking comparator is not canonical")
        if ranking.get("aggregateScore") is not None:
            errors.append("register may not contain an aggregate score")
        if ranking.get("actionClasses") != [
            {"id": key, "ordinal": value} for key, value in ACTION_CLASSES.items()
        ]:
            errors.append("register action classes are not canonical")
        if ranking.get("severityLevels") != [
            {"id": key, "ordinal": value} for key, value in SEVERITY_LEVELS.items()
        ]:
            errors.append("register severity levels are not canonical")
        if ranking.get("confidenceLevels") != [
            {"id": key, "ordinal": value} for key, value in CONFIDENCE_LEVELS.items()
        ]:
            errors.append("register confidence levels are not canonical")

    entries = register.get("entries")
    if not isinstance(entries, list) or not 1 <= len(entries) <= 32:
        errors.append("register.entries must contain 1-32 entries")
        entries = []
    identifiers: list[str] = []
    valid_entries: list[Mapping[str, Any]] = []
    for index, entry in enumerate(entries):
        location = f"register.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{location} must be an object")
            continue
        valid_entries.append(entry)
        exact_keys(entry, ENTRY_KEYS, location, errors)
        identifier = entry.get("id")
        if not isinstance(identifier, str) or DEFICIT_ID.fullmatch(identifier) is None:
            errors.append(f"{location}.id is invalid")
        else:
            identifiers.append(identifier)
        if not bounded_text(entry.get("title"), 300):
            errors.append(f"{location}.title must be bounded text")
        if not isinstance(entry.get("deficitKind"), str) or entry.get("deficitKind") not in DEFICIT_KINDS:
            errors.append(f"{location}.deficitKind is unsupported")
        if entry.get("status") != "open":
            errors.append(f"{location}.status must be open")
        action = entry.get("actionClass")
        if not isinstance(action, dict):
            errors.append(f"{location}.actionClass must be an object")
        else:
            exact_keys(action, ACTION_KEYS, f"{location}.actionClass", errors)
            action_id = action.get("id")
            if not isinstance(action_id, str) or action_id not in ACTION_CLASSES or ACTION_CLASSES.get(action_id) != action.get("ordinal"):
                errors.append(f"{location}.actionClass is not canonical")
        prevalence_value = entry.get("prevalence")
        if not isinstance(prevalence_value, dict):
            errors.append(f"{location}.prevalence must be an object")
        else:
            exact_keys(prevalence_value, PREVALENCE_KEYS, f"{location}.prevalence", errors)
            numerator = prevalence_value.get("numerator")
            denominator = prevalence_value.get("denominator")
            if (
                isinstance(numerator, bool) or not isinstance(numerator, int)
                or isinstance(denominator, bool) or not isinstance(denominator, int)
                or denominator <= 0 or numerator < 0 or numerator > denominator
            ):
                errors.append(f"{location}.prevalence fraction is invalid")
            elif prevalence_value.get("ratio") != round(numerator / denominator, 9):
                errors.append(f"{location}.prevalence.ratio does not match fraction")
            for field, maximum, pattern in (
                ("affectedCaseIds", 64, None),
                ("affectedRouteIds", 8, None),
                ("affectedAssetIds", 32, None),
            ):
                values = string_list(
                    prevalence_value.get(field), f"{location}.prevalence.{field}",
                    errors, maximum, pattern,
                )
                if values != sorted(values):
                    errors.append(f"{location}.prevalence.{field} must be sorted")
            for field in ("kind", "unit", "scope"):
                if not bounded_text(prevalence_value.get(field), 1000):
                    errors.append(f"{location}.prevalence.{field} must be bounded text")
        severity_value = entry.get("severity")
        if not isinstance(severity_value, dict):
            errors.append(f"{location}.severity must be an object")
        else:
            exact_keys(severity_value, SEVERITY_KEYS, f"{location}.severity", errors)
            level = severity_value.get("level")
            if not isinstance(level, str) or level not in SEVERITY_LEVELS or severity_value.get("ordinal") != SEVERITY_LEVELS.get(level):
                errors.append(f"{location}.severity is not canonical")
            for field in ("impactDomain", "basis"):
                if not bounded_text(severity_value.get(field), 1000):
                    errors.append(f"{location}.severity.{field} must be bounded text")
        confidence_value = entry.get("confidence")
        if not isinstance(confidence_value, dict):
            errors.append(f"{location}.confidence must be an object")
        else:
            exact_keys(confidence_value, CONFIDENCE_KEYS, f"{location}.confidence", errors)
            level = confidence_value.get("level")
            if not isinstance(level, str) or level not in CONFIDENCE_LEVELS or confidence_value.get("ordinal") != CONFIDENCE_LEVELS.get(level):
                errors.append(f"{location}.confidence is not canonical")
            for field in ("basis", "scopeLimit"):
                if not bounded_text(confidence_value.get(field), 1000):
                    errors.append(f"{location}.confidence.{field} must be bounded text")
        owner_value = entry.get("owner")
        if not isinstance(owner_value, dict):
            errors.append(f"{location}.owner must be an object")
        else:
            exact_keys(owner_value, OWNER_KEYS, f"{location}.owner", errors)
            for field in OWNER_KEYS:
                if not bounded_text(owner_value.get(field), 500):
                    errors.append(f"{location}.owner.{field} must be bounded text")
        evidence = entry.get("evidence")
        if not isinstance(evidence, list) or not 1 <= len(evidence) <= 4:
            errors.append(f"{location}.evidence must contain 1-4 references")
            evidence = []
        for evidence_index, reference in enumerate(evidence):
            reference_location = f"{location}.evidence[{evidence_index}]"
            if not isinstance(reference, dict):
                errors.append(f"{reference_location} must be an object")
                continue
            exact_keys(reference, EVIDENCE_KEYS, reference_location, errors)
            source_id = reference.get("sourceId")
            if not isinstance(source_id, str) or source_id not in source_ids:
                errors.append(f"{reference_location}.sourceId is unknown")
            expected_fingerprint = (
                source_fingerprints.get(source_id)
                if isinstance(source_id, str) else None
            )
            if reference.get("reportFingerprint") != expected_fingerprint:
                errors.append(f"{reference_location}.reportFingerprint is stale")
            if not bounded_text(reference.get("observation"), 1000):
                errors.append(f"{reference_location}.observation must be bounded text")
        links = entry.get("nearestRoadmapItems")
        if not isinstance(links, list) or not 1 <= len(links) <= 4:
            errors.append(f"{location}.nearestRoadmapItems must contain 1-4 links")
            links = []
        link_ids: list[str] = []
        for link_index, link in enumerate(links):
            link_location = f"{location}.nearestRoadmapItems[{link_index}]"
            if not isinstance(link, dict):
                errors.append(f"{link_location} must be an object")
                continue
            exact_keys(link, ROADMAP_LINK_KEYS, link_location, errors)
            item_id = link.get("id")
            if not isinstance(item_id, str) or ROADMAP_ID.fullmatch(item_id) is None:
                errors.append(f"{link_location}.id is invalid")
            else:
                link_ids.append(item_id)
                if roadmap_items is not None:
                    roadmap = roadmap_items.get(item_id)
                    if roadmap is None:
                        errors.append(f"{link_location}.id is absent from roadmap")
                    else:
                        if roadmap.get("status") not in {"queued", "researching", "implementing", "qualifying"}:
                            errors.append(f"{link_location}.id is not open roadmap work")
                        if link.get("outcome") != roadmap.get("outcome"):
                            errors.append(f"{link_location}.outcome is stale")
            if not bounded_text(link.get("outcome"), 500):
                errors.append(f"{link_location}.outcome must be bounded text")
        if len(link_ids) != len(set(link_ids)):
            errors.append(f"{location}.nearestRoadmapItems must not contain duplicates")
        string_list(entry.get("limitations"), f"{location}.limitations", errors, 8)
        if entry.get("disposition") != DISPOSITION:
            errors.append(f"{location}.disposition is not conservative")
        if entry.get("qualityClaim") is not False or entry.get("promotionAuthorized") is not False:
            errors.append(f"{location} may not claim quality or promotion")
    if len(identifiers) != len(set(identifiers)):
        errors.append("register deficit IDs must be unique")
    if valid_entries:
        try:
            ordered_entries = sorted(valid_entries, key=priority_key)
        except (KeyError, TypeError, ValueError):
            errors.append("register entries cannot be ranked from their declared fields")
        else:
            if list(valid_entries) != ordered_entries:
                errors.append("register entries are not in deterministic priority order")

    quarantined = register.get("quarantinedObservations")
    if not isinstance(quarantined, list) or len(quarantined) > 32:
        errors.append("register.quarantinedObservations must contain at most 32 entries")
        quarantined = []
    observation_ids: list[str] = []
    for index, observation in enumerate(quarantined):
        location = f"register.quarantinedObservations[{index}]"
        if not isinstance(observation, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(observation, OBSERVATION_KEYS, location, errors)
        identifier = observation.get("id")
        if not isinstance(identifier, str) or OBSERVATION_ID.fullmatch(identifier) is None:
            errors.append(f"{location}.id is invalid")
        else:
            observation_ids.append(identifier)
        if not isinstance(observation.get("sourceId"), str) or observation.get("sourceId") not in source_ids:
            errors.append(f"{location}.sourceId is unknown")
        for field in ("title", "observation", "reasonNotDeficit"):
            if not bounded_text(observation.get(field), 1000):
                errors.append(f"{location}.{field} must be bounded text")
    if len(observation_ids) != len(set(observation_ids)):
        errors.append("quarantined observation IDs must be unique")
    if observation_ids != sorted(observation_ids):
        errors.append("quarantined observations must be ID-sorted")

    qualification = register.get("qualification")
    if not isinstance(qualification, dict):
        errors.append("register.qualification must be an object")
    else:
        exact_keys(qualification, QUALIFICATION_KEYS, "register.qualification", errors)
        if qualification.get("status") != "evidence-ranked-register-only":
            errors.append("register qualification status is unsupported")
        if qualification.get("calibratedAuditoryDefectCount") != 0:
            errors.append("current register may not claim a calibrated auditory defect")
        if qualification.get("runtimeInput") is not False:
            errors.append("register may not be a runtime input")
        if qualification.get("promotionAuthorized") is not False:
            errors.append("register may not authorize promotion")
        string_list(qualification.get("limitations"), "register.qualification.limitations", errors, 8)
    return errors


def render_markdown(register: Mapping[str, Any]) -> str:
    lines = [
        "# Evidence-ranked deficit register",
        "",
        "> Generated from `docs/DEFICIT_REGISTER.json`; do not edit by hand.",
        "",
        "This register orders bounded investigations. It is not an evaluator, a",
        "musical-quality score, an implementation authorization, or a runtime input.",
        "Current calibrated auditory defects: **0**.",
        "",
        "## Ordering rule",
        "",
        "Entries are ordered lexicographically by severity (descending), action class",
        "(ascending), confidence (descending), nearest roadmap number (ascending), then",
        "stable deficit ID. There is no weighted aggregate score. Prevalence is an",
        "observed scoped fraction, never likelihood, importance, or severity.",
        "",
        "## Open register",
        "",
        "| Rank | ID | Kind | Severity | Confidence | Prevalence | Owner | Nearest items |",
        "|---:|---|---|---|---|---:|---|---|",
    ]
    for rank, entry in enumerate(register["entries"], start=1):
        prevalence_value = entry["prevalence"]
        links = ", ".join(item["id"] for item in entry["nearestRoadmapItems"])
        lines.append(
            f"| {rank} | `{entry['id']}` | {entry['deficitKind']} | "
            f"{entry['severity']['level']} | {entry['confidence']['level']} | "
            f"{prevalence_value['numerator']}/{prevalence_value['denominator']} "
            f"{prevalence_value['unit']} | {entry['owner']['evidenceOwner']} | {links} |"
        )
    for entry in register["entries"]:
        lines.extend([
            "",
            f"### {entry['id']} — {entry['title']}",
            "",
            f"- **Observed scope:** {entry['prevalence']['numerator']}/"
            f"{entry['prevalence']['denominator']} {entry['prevalence']['unit']}; "
            f"{entry['prevalence']['scope']}.",
            f"- **Severity ({entry['severity']['level']}):** {entry['severity']['basis']}",
            f"- **Confidence ({entry['confidence']['level']}):** {entry['confidence']['basis']} "
            f"Scope limit: {entry['confidence']['scopeLimit']}",
            f"- **Canonical owner:** {entry['owner']['canonicalOwner']} "
            f"(`{entry['owner']['layer']}`).",
            f"- **Evidence owner:** {entry['owner']['evidenceOwner']}.",
            "- **Nearest roadmap work:** " + "; ".join(
                f"`{item['id']}` {item['outcome']}"
                for item in entry["nearestRoadmapItems"]
            ) + ".",
            "- **Source evidence:** " + "; ".join(
                f"`{item['sourceId']}` `{item['reportFingerprint']}` — {item['observation']}"
                for item in entry["evidence"]
            ),
            "- **Limits:** " + " ".join(entry["limitations"]),
        ])
    lines.extend([
        "",
        "## Quarantined observations",
        "",
        "These facts remain visible but are not called sound defects.",
        "",
    ])
    for observation in register["quarantinedObservations"]:
        lines.extend([
            f"- **{observation['id']} — {observation['title']}:** "
            f"{observation['observation']} {observation['reasonNotDeficit']}",
        ])
    lines.extend([
        "",
        "## Bound source reports",
        "",
        "| Source | Local path | Report fingerprint | Source fingerprint |",
        "|---|---|---|---|",
    ])
    for source in register["generatedFrom"]["sources"]:
        lines.append(
            f"| `{source['id']}` | `{source['path']}` | "
            f"`{source['reportFingerprint']}` | `{source['sourceFingerprint']}` |"
        )
    lines.extend([
        "",
        "## Qualification boundary",
        "",
        "- No entry is a calibrated auditory-quality defect.",
        "- The register cannot activate roadmap work, select a candidate, alter PCM, or",
        "  authorize quality promotion.",
        "- Missing hardware, listening, or soak evidence is not a failed observation.",
        "- Re-run the generator after any bound report, corpus, engine, source, Git, or",
        "  contract-snapshot change.",
        "",
    ])
    return "\n".join(lines)


def current_register(root: Path) -> dict[str, Any]:
    reports, generated_from = load_current_sources(root)
    return build_register(reports, generated_from)


def run_generate(root: Path, output: TextIO = sys.stdout) -> int:
    register = current_register(root)
    roadmap_items = parse_roadmap_items(root / ROADMAP_PATH)
    errors = validate_register(register, roadmap_items)
    if errors:
        raise DeficitRegisterError("generated register is invalid: " + "; ".join(errors))
    write_json_atomic(root / REGISTER_PATH, register)
    write_text_atomic(root / MARKDOWN_PATH, render_markdown(register))
    print(
        f"generated deficit register: {len(register['entries'])} open entries, "
        f"{len(register['quarantinedObservations'])} quarantined observations, "
        "0 calibrated auditory defects",
        file=output,
    )
    return 0


def run_validate(root: Path, output: TextIO = sys.stdout) -> int:
    register = load_json(root / REGISTER_PATH, "deficit register")
    errors = validate_register(register)
    if errors:
        print(f"deficit register rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, start=1):
            print(f"  {index}. {error}", file=output)
        return 1
    print(
        f"deficit register structure is valid: {len(register['entries'])} entries; "
        f"fingerprint {register['registerFingerprint']}",
        file=output,
    )
    return 0


def run_render(root: Path, output: TextIO = sys.stdout) -> int:
    register = load_json(root / REGISTER_PATH, "deficit register")
    errors = validate_register(register)
    if errors:
        raise DeficitRegisterError("cannot render invalid register: " + "; ".join(errors))
    write_text_atomic(root / MARKDOWN_PATH, render_markdown(register))
    print("generated docs/DEFICIT_REGISTER.md", file=output)
    return 0


def run_check(root: Path, output: TextIO = sys.stdout) -> int:
    expected = current_register(root)
    actual = load_json(root / REGISTER_PATH, "deficit register")
    roadmap_items = parse_roadmap_items(root / ROADMAP_PATH)
    errors = validate_register(actual, roadmap_items)
    if actual != expected:
        errors.append("deficit register is stale; run generate")
    try:
        markdown = (root / MARKDOWN_PATH).read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"cannot read generated Markdown: {exc}")
        markdown = None
    if markdown != render_markdown(actual):
        errors.append("deficit register Markdown is stale; run generate")
    if errors:
        print(f"deficit register rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, start=1):
            print(f"  {index}. {error}", file=output)
        return 1
    print(
        f"deficit register current: {len(actual['entries'])} entries, "
        f"{len(actual['quarantinedObservations'])} quarantined observations, "
        f"fingerprint {actual['registerFingerprint']}",
        file=output,
    )
    return 0


def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("generate", "check", "validate", "render"))
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_arguments(argv)
    root = repository_root()
    try:
        if args.command == "generate":
            return run_generate(root)
        if args.command == "check":
            return run_check(root)
        if args.command == "validate":
            return run_validate(root)
        return run_render(root)
    except DeficitRegisterError as exc:
        print(f"deficit register failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
