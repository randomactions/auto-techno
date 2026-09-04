#!/usr/bin/env python3
"""Finalize and independently verify accepted-score motif baselines."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Mapping, Optional, Sequence, TextIO


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import pcm_comparison_report as pcm  # noqa: E402


REPORT_SCHEMA = "autotechno-score-motif-baseline-report.v1"
ANALYZER_VERSION = "autotechno-score-motif-baseline-analyzer.v1"
EVIDENCE_SCHEMA = "autotechno-score-motif-baseline.v1"
SCORE_SCHEMA = "autotechno-resolved-upper-score.v1"
ALL_ROLES = ["anchor", "shadow", "atmosphere", "response", "transition"]
ELIGIBLE_ROLES = ["anchor", "shadow", "response"]
SCOPES = ["combined", *ELIGIBLE_ROLES]
GATES = {"retrigger", "slide"}
MAXIMUM_BARS = 16
MAXIMUM_NOTES = 80
MAXIMUM_LAG = 4
DEFAULT_PAYLOAD = Path(
    "docs/local/reports/score-motif-baseline-v1/payload.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/score-motif-baseline-v1/manifest.json"
)


class ScoreMotifBaselineReportError(RuntimeError):
    """An actionable schema, provenance, or independent-analysis failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> None:
    actual = set(value)
    if actual != expected:
        raise ScoreMotifBaselineReportError(
            f"{location} keys differ: missing={sorted(expected - actual)} "
            f"extra={sorted(actual - expected)}"
        )


def mean(values: Sequence[float]) -> Optional[float]:
    return sum(values) / len(values) if values else None


def round_away(value: float) -> int:
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)


def positive_modulo(value: int, divisor: int) -> int:
    return value % divisor


def fnv(values: Sequence[str]) -> str:
    value = 0xCBF29CE484222325
    for item in values:
        for byte in item.encode("utf-8"):
            value ^= byte
            value = (value * 0x00000100000001B3) & 0xFFFFFFFFFFFFFFFF
        value ^= 0xFF
        value = (value * 0x00000100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{value:016x}"


def mutation_distance(lhs: Sequence[Any], rhs: Sequence[Any]) -> float:
    denominator = max(len(lhs), len(rhs))
    if denominator == 0:
        return 0.0
    previous = list(range(len(rhs) + 1))
    for row, left in enumerate(lhs):
        current = [row + 1]
        for column, right in enumerate(rhs):
            current.append(min(
                current[column] + 1,
                previous[column + 1] + 1,
                previous[column] + (0 if left == right else 1),
            ))
        previous = current
    return previous[len(rhs)] / denominator


def note_key(token: Mapping[str, Any]) -> str:
    return (
        f"{token['role']}:{token['onsetMilliSteps']}:"
        f"{token['durationMilliSteps']}:{token['startMIDIMilliNote']}:"
        f"{token['endMIDIMilliNote']}:{token['gate']}"
    )


def interval_vector(tokens: Sequence[Mapping[str, Any]]) -> list[int]:
    return [
        int(tokens[index + 1]["endMIDIMilliNote"])
        - int(tokens[index]["endMIDIMilliNote"])
        for index in range(len(tokens) - 1)
    ]


def convert_note(
    note: Mapping[str, Any], source_index: int, tonal_center: int
) -> dict[str, Any]:
    role = note.get("role")
    gate = note.get("gate")
    if role not in ALL_ROLES:
        raise ScoreMotifBaselineReportError("input note has unsupported role")
    if gate not in GATES:
        raise ScoreMotifBaselineReportError("input note has unsupported gate")
    numeric = [
        note.get("timingOffsetInSteps"), note.get("durationInSteps"),
        note.get("startFrequencyRatio"), note.get("endFrequencyRatio"),
    ]
    if not all(isinstance(value, (int, float)) and math.isfinite(value)
               for value in numeric):
        raise ScoreMotifBaselineReportError("input note contains non-finite data")
    onset = note.get("onsetStep")
    timing, duration, start_ratio, end_ratio = map(float, numeric)
    if (
        not isinstance(onset, int) or not 0 <= onset < 16
        or not 0 <= timing <= 0.12
        or not 0.0625 <= duration <= 16
        or not 0.125 <= start_ratio <= 8
        or not 0.125 <= end_ratio <= 8
    ):
        raise ScoreMotifBaselineReportError("input note is outside canonical bounds")

    def midi_milli(ratio: float) -> int:
        relative = round_away(12 * math.log2(ratio) * 1_000)
        return (36 + tonal_center) * 1_000 + relative

    start = midi_milli(start_ratio)
    end = midi_milli(end_ratio)
    return {
        "ordinal": source_index,
        "role": role,
        "onsetMilliSteps": round_away((onset + timing) * 1_000),
        "durationMilliSteps": round_away(duration * 1_000),
        "startMIDIMilliNote": start,
        "endMIDIMilliNote": end,
        "startPitchClassMilliSemitones": positive_modulo(start, 12_000),
        "endPitchClassMilliSemitones": positive_modulo(end, 12_000),
        "gate": gate,
    }


def ordered(tokens: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    values = sorted(tokens, key=lambda token: (
        token["onsetMilliSteps"], ALL_ROLES.index(str(token["role"])),
        token["endMIDIMilliNote"], token["durationMilliSteps"],
        token["ordinal"],
    ))
    return [{**token, "ordinal": ordinal} for ordinal, token in enumerate(values)]


def bar_evidence(
    phrase_bar_index: int,
    absolute_bar: int,
    scope: str,
    source_tokens: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    values = ordered([
        token for token in source_tokens
        if token["role"] in ELIGIBLE_ROLES
        and (scope == "combined" or token["role"] == scope)
    ])
    registers = [int(token["endMIDIMilliNote"]) for token in values]
    intervals = interval_vector(values)
    normalized: list[str] = []
    if values:
        origin = int(values[0]["endMIDIMilliNote"])
        normalized = [
            f"{token['role']}:{token['onsetMilliSteps']}:"
            f"{token['durationMilliSteps']}:"
            f"{int(token['startMIDIMilliNote']) - origin}:"
            f"{int(token['endMIDIMilliNote']) - origin}:{token['gate']}"
            for token in values
        ]
    denominator = 16 * (len(ELIGIBLE_ROLES) if scope == "combined" else 1)
    return {
        "phraseBarIndex": phrase_bar_index,
        "absoluteBar": absolute_bar,
        "scope": scope,
        "active": bool(values),
        "noteCount": len(values),
        "density": len(values) / denominator,
        "minimumRegisterMIDIMilliNote": min(registers) if registers else None,
        "meanRegisterMIDIMilliNote": mean([float(value) for value in registers]),
        "maximumRegisterMIDIMilliNote": max(registers) if registers else None,
        "exactTokenFingerprint": fnv([note_key(value) for value in values])
        if values else None,
        "intervalContourFingerprint": fnv([str(value) for value in intervals])
        if intervals else None,
        "normalizedMotifFingerprint": fnv(normalized) if values else None,
        "tokens": values,
    }


def best_rotation(reference: Sequence[int], current: Sequence[int]) -> tuple[int, float]:
    best_shift, best_distance = 0, math.inf
    for shift in range(16):
        rotated = sorted((value + shift * 1_000) % 16_000 for value in reference)
        distance = mutation_distance(rotated, sorted(current))
        if distance < best_distance:
            best_shift, best_distance = shift, distance
    return best_shift, best_distance


def comparison(
    reference: Mapping[str, Any], current: Mapping[str, Any], lag: int
) -> dict[str, Any]:
    lhs = list(reference["tokens"])
    rhs = list(current["tokens"])
    if not lhs and not rhs:
        availability = "unavailable-no-notes-in-either-bar"
    elif not lhs:
        availability = "unavailable-no-notes-in-reference-bar"
    elif not rhs:
        availability = "unavailable-no-notes-in-current-bar"
    else:
        availability = "available"
    base = {
        "scope": current["scope"],
        "referencePhraseBarIndex": reference["phraseBarIndex"],
        "currentPhraseBarIndex": current["phraseBarIndex"],
        "lagBars": lag,
        "availability": availability,
    }
    optional_keys = [
        "exactRecurrence", "onsetRecurrence", "intervalContourRecurrence",
        "normalizedMotifRecurrence", "transpositionMilliSemitones",
        "noteMutationDistance", "onsetMutationDistance",
        "durationMutationDistance", "absolutePitchMutationDistance",
        "pitchClassMutationDistance", "intervalMutationDistance",
        "roleMutationDistance", "bestReferenceForwardRotationSteps",
        "rotationNormalizedOnsetMutationDistance", "noteCountDelta",
        "densityDelta", "meanRegisterShiftMIDIMilliNotes",
    ]
    if availability != "available":
        return {**base, **{key: None for key in optional_keys}}
    lhs_intervals, rhs_intervals = interval_vector(lhs), interval_vector(rhs)
    contour_available = bool(lhs_intervals) and bool(rhs_intervals)
    contour_match = lhs_intervals == rhs_intervals if contour_available else None
    transposition = (
        int(rhs[0]["endMIDIMilliNote"]) - int(lhs[0]["endMIDIMilliNote"])
        if len(lhs) == len(rhs) and contour_match is True else None
    )
    shift, rotation_distance = best_rotation(
        [int(token["onsetMilliSteps"]) for token in lhs],
        [int(token["onsetMilliSteps"]) for token in rhs],
    )
    return {
        **base,
        "exactRecurrence": [note_key(value) for value in lhs]
        == [note_key(value) for value in rhs],
        "onsetRecurrence": [value["onsetMilliSteps"] for value in lhs]
        == [value["onsetMilliSteps"] for value in rhs],
        "intervalContourRecurrence": contour_match,
        "normalizedMotifRecurrence": reference["normalizedMotifFingerprint"]
        == current["normalizedMotifFingerprint"],
        "transpositionMilliSemitones": transposition,
        "noteMutationDistance": mutation_distance(
            [note_key(value) for value in lhs], [note_key(value) for value in rhs]
        ),
        "onsetMutationDistance": mutation_distance(
            [value["onsetMilliSteps"] for value in lhs],
            [value["onsetMilliSteps"] for value in rhs],
        ),
        "durationMutationDistance": mutation_distance(
            [value["durationMilliSteps"] for value in lhs],
            [value["durationMilliSteps"] for value in rhs],
        ),
        "absolutePitchMutationDistance": mutation_distance(
            [(value["startMIDIMilliNote"], value["endMIDIMilliNote"]) for value in lhs],
            [(value["startMIDIMilliNote"], value["endMIDIMilliNote"]) for value in rhs],
        ),
        "pitchClassMutationDistance": mutation_distance(
            [(value["startPitchClassMilliSemitones"], value["endPitchClassMilliSemitones"])
             for value in lhs],
            [(value["startPitchClassMilliSemitones"], value["endPitchClassMilliSemitones"])
             for value in rhs],
        ),
        "intervalMutationDistance": mutation_distance(lhs_intervals, rhs_intervals)
        if contour_available else None,
        "roleMutationDistance": mutation_distance(
            [value["role"] for value in lhs], [value["role"] for value in rhs]
        ),
        "bestReferenceForwardRotationSteps": shift,
        "rotationNormalizedOnsetMutationDistance": rotation_distance,
        "noteCountDelta": len(rhs) - len(lhs),
        "densityDelta": float(current["density"]) - float(reference["density"]),
        "meanRegisterShiftMIDIMilliNotes":
            float(current["meanRegisterMIDIMilliNote"])
            - float(reference["meanRegisterMIDIMilliNote"]),
    }


def reconstruct(source: Mapping[str, Any]) -> dict[str, Any]:
    exact_keys(source, {"phraseIndex", "startBar", "barCount", "tonalCenter", "bars"},
               "input")
    phrase_index, start_bar = source.get("phraseIndex"), source.get("startBar")
    bar_count, tonal_center = source.get("barCount"), source.get("tonalCenter")
    bars_input = source.get("bars")
    if (
        not isinstance(phrase_index, int) or phrase_index < 0
        or not isinstance(start_bar, int) or start_bar < 0
        or not isinstance(bar_count, int) or not 0 < bar_count <= MAXIMUM_BARS
        or not isinstance(tonal_center, int) or not 0 <= tonal_center < 12
        or not isinstance(bars_input, list) or len(bars_input) != bar_count
    ):
        raise ScoreMotifBaselineReportError("input phrase bounds are invalid")
    converted: list[list[dict[str, Any]]] = []
    for index, bar in enumerate(bars_input):
        if not isinstance(bar, dict):
            raise ScoreMotifBaselineReportError("input bar must be an object")
        exact_keys(bar, {"absoluteBar", "notes"}, f"input.bars[{index}]")
        notes = bar.get("notes")
        if bar.get("absoluteBar") != start_bar + index:
            raise ScoreMotifBaselineReportError("input bars are discontinuous")
        if not isinstance(notes, list) or len(notes) > MAXIMUM_NOTES:
            raise ScoreMotifBaselineReportError("input bar note count is invalid")
        converted.append([])
        for note_index, note in enumerate(notes):
            if not isinstance(note, dict):
                raise ScoreMotifBaselineReportError("input note must be an object")
            exact_keys(note, {
                "role", "onsetStep", "timingOffsetInSteps", "durationInSteps",
                "startFrequencyRatio", "endFrequencyRatio", "gate",
            }, f"input.bars[{index}].notes[{note_index}]")
            converted[-1].append(convert_note(note, note_index, tonal_center))
    bars: list[dict[str, Any]] = []
    for index, source_tokens in enumerate(converted):
        for scope in SCOPES:
            bars.append(bar_evidence(
                index, int(bars_input[index]["absoluteBar"]), scope, source_tokens
            ))
    comparisons: list[dict[str, Any]] = []
    for current_index in range(bar_count):
        for scope in SCOPES:
            current = next(
                bar for bar in bars
                if bar["phraseBarIndex"] == current_index and bar["scope"] == scope
            )
            for lag in range(1, MAXIMUM_LAG + 1):
                if current_index < lag:
                    continue
                reference = next(
                    bar for bar in bars
                    if bar["phraseBarIndex"] == current_index - lag
                    and bar["scope"] == scope
                )
                comparisons.append(comparison(reference, current, lag))
    available = [value for value in comparisons if value["availability"] == "available"]
    register_shifts = [
        float(value["meanRegisterShiftMIDIMilliNotes"])
        for value in available
        if value["meanRegisterShiftMIDIMilliNotes"] is not None
    ]
    summary = {
        "barCount": bar_count,
        "eligibleNoteCount": sum(
            token["role"] in ELIGIBLE_ROLES for bar in converted for token in bar
        ),
        "excludedNoteCounts": [
            {"name": role, "count": sum(
                token["role"] == role for bar in converted for token in bar
            )}
            for role in ALL_ROLES if role not in ELIGIBLE_ROLES
        ],
        "availableComparisonCount": len(available),
        "exactRecurrenceCount": sum(value["exactRecurrence"] is True for value in available),
        "intervalContourRecurrenceCount": sum(
            value["intervalContourRecurrence"] is True for value in available
        ),
        "normalizedMotifRecurrenceCount": sum(
            value["normalizedMotifRecurrence"] is True for value in available
        ),
        "meanNoteMutationDistance": mean([
            float(value["noteMutationDistance"]) for value in available
            if value["noteMutationDistance"] is not None
        ]),
        "meanAbsoluteRegisterShiftSemitones": mean([
            abs(value) / 1_000 for value in register_shifts
        ]),
    }
    fingerprint_values = [
        EVIDENCE_SCHEMA, str(phrase_index), str(start_bar), str(bar_count),
        str(tonal_center),
    ]
    fingerprint_values += [
        f"{bar['phraseBarIndex']}:{bar['scope']}:"
        f"{bar['exactTokenFingerprint'] or 'inactive'}"
        for bar in bars
    ]
    fingerprint_values += [
        f"{value['currentPhraseBarIndex']}:{value['scope']}:{value['lagBars']}:"
        f"{value['availability']}:"
        f"{float(value['noteMutationDistance']) if value['noteMutationDistance'] is not None else -1.0}"
        for value in comparisons
    ]
    fingerprint_values.append(str(summary["eligibleNoteCount"]))
    return {
        "schema": EVIDENCE_SCHEMA,
        "analyzerVersion": ANALYZER_VERSION,
        "scoreSchemaVersion": SCORE_SCHEMA,
        "phraseIndex": phrase_index,
        "startBar": start_bar,
        "barCount": bar_count,
        "tonalCenter": tonal_center,
        "eligibleRoles": ELIGIBLE_ROLES,
        "scopeOrder": SCOPES,
        "bars": bars,
        "comparisons": comparisons,
        "summary": summary,
        "evidenceFingerprint": fnv(fingerprint_values),
    }


def compare_recomputed(actual: Any, expected: Any, location: str) -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            raise ScoreMotifBaselineReportError(f"{location} must be an object")
        exact_keys(actual, set(expected), location)
        for key in expected:
            compare_recomputed(actual[key], expected[key], f"{location}.{key}")
        return
    if isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise ScoreMotifBaselineReportError(f"{location} array differs")
        for index, value in enumerate(expected):
            compare_recomputed(actual[index], value, f"{location}[{index}]")
        return
    if isinstance(expected, float):
        if not isinstance(actual, (int, float)) or not math.isclose(
            float(actual), expected, rel_tol=1e-12, abs_tol=1e-12
        ):
            raise ScoreMotifBaselineReportError(f"{location} differs")
        return
    if actual != expected:
        raise ScoreMotifBaselineReportError(f"{location} differs")


def expected_policy() -> dict[str, Any]:
    return {
        "signalAuthority": "accepted-resolved-upper-score-not-pcm-inference",
        "eligibleRoles": ELIGIBLE_ROLES,
        "excludedRoles": ["atmosphere", "transition"],
        "scopeOrder": SCOPES,
        "tokenOrder": "onset-then-synth-role-order-then-end-pitch-duration-source-order",
        "duplicatePolicy": "retain-every-resolved-note-with-stable-ordinal",
        "pitchRepresentation":
            "midi-millinote-c2-root-plus-tonal-center-plus-rounded-log2-ratio",
        "onsetRepresentation":
            "rounded-millisteps-from-onset-step-plus-score-timing-offset",
        "durationRepresentation": "rounded-millisteps",
        "contourRepresentation": "ordered-signed-end-pitch-interval-vector",
        "densityDenominator":
            "sixteen-cells-per-role-or-forty-eight-combined-eligible-role-cells",
        "maximumComparisonLagBars": MAXIMUM_LAG,
        "mutationDistance":
            "levenshtein-edit-count-divided-by-longer-sequence-count",
        "rotationSearch":
            "all-sixteen-forward-reference-grid-step-rotations-lowest-shift-wins",
        "inactivePolicy":
            "absent-role-and-empty-motif-are-explicit-unavailable-comparisons",
        "aggregation": "arithmetic-mean-of-available-comparisons",
        "interpretation":
            "descriptive-not-ranked-not-calibrated-no-quality-or-future-decision",
    }


def validate(report: Mapping[str, Any], root: Path, require_fingerprint: bool) -> None:
    expected_top = {
        "schema", "reportVersion", "analyzerVersion", "scoreSchemaVersion",
        "corpusSha256", "wholeManifestSha256", "contractBaselineFingerprint",
        "sourceFingerprint", "gitHead", "engineVersion", "policies", "assets",
    }
    if require_fingerprint:
        expected_top.add("reportFingerprint")
    exact_keys(report, expected_top, "report")
    if report.get("schema") != REPORT_SCHEMA or report.get("reportVersion") != 1:
        raise ScoreMotifBaselineReportError("report schema/version is invalid")
    if report.get("analyzerVersion") != ANALYZER_VERSION:
        raise ScoreMotifBaselineReportError("analyzer version is invalid")
    if report.get("scoreSchemaVersion") != SCORE_SCHEMA:
        raise ScoreMotifBaselineReportError("score schema version is invalid")
    corpus_path = root / "docs/BASELINE_CORPUS.json"
    manifest_path = root / "docs/local/reports/baseline-corpus-v1/manifest.json"
    if report.get("corpusSha256") != pcm.sha256(corpus_path):
        raise ScoreMotifBaselineReportError("corpus hash is stale")
    if report.get("wholeManifestSha256") != pcm.sha256(manifest_path):
        raise ScoreMotifBaselineReportError("whole manifest hash is stale")
    baseline = pcm.load_json(
        root / "docs/ROADMAP_EXECUTION_BASELINE.json", "contract baseline"
    )
    if report.get("contractBaselineFingerprint") != baseline.get("snapshotFingerprint"):
        raise ScoreMotifBaselineReportError("contract baseline binding is stale")
    manifest = pcm.load_json(manifest_path, "whole manifest")
    for key in ("sourceFingerprint", "gitHead", "engineVersion"):
        if report.get(key) != manifest.get(key):
            raise ScoreMotifBaselineReportError(f"{key} differs from whole manifest")
    policies = report.get("policies")
    if not isinstance(policies, dict):
        raise ScoreMotifBaselineReportError("policies must be an object")
    compare_recomputed(policies, expected_policy(), "policies")
    expected_entries = {
        item["id"]: item for item in manifest.get("entries", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    assets = report.get("assets")
    if not isinstance(assets, list) or [item.get("assetId") for item in assets] != sorted(expected_entries):
        raise ScoreMotifBaselineReportError("assets do not exactly cover whole manifest")
    for index, asset in enumerate(assets):
        if not isinstance(asset, dict):
            raise ScoreMotifBaselineReportError("asset must be an object")
        exact_keys(asset, {
            "assetId", "caseId", "routeId", "rootSeed", "checkpoint",
            "continuationClass", "sampleRate", "channelCount", "phraseIndex",
            "startBar", "phraseKind", "planFingerprint", "stateFingerprint",
            "replayFingerprint", "acceptedPCMSha256", "input", "evidence",
        }, f"assets[{index}]")
        entry = expected_entries[str(asset["assetId"])]
        bindings = {
            "caseId": "caseId", "routeId": "routeId", "rootSeed": "rootSeed",
            "checkpoint": "checkpoint", "continuationClass": "continuationClass",
            "sampleRate": "sampleRate", "channelCount": "channelCount",
            "phraseIndex": "phraseIndex", "startBar": "startBar",
            "phraseKind": "phraseKind", "planFingerprint": "planFingerprint",
            "stateFingerprint": "stateFingerprint", "replayFingerprint": "replayFingerprint",
            "acceptedPCMSha256": "pcmSha256",
        }
        for asset_key, entry_key in bindings.items():
            if asset.get(asset_key) != entry.get(entry_key):
                raise ScoreMotifBaselineReportError(
                    f"assets[{index}].{asset_key} differs from whole manifest"
                )
        source = asset.get("input")
        evidence = asset.get("evidence")
        if not isinstance(source, dict) or not isinstance(evidence, dict):
            raise ScoreMotifBaselineReportError("asset input/evidence must be objects")
        if (
            source.get("phraseIndex") != asset.get("phraseIndex")
            or source.get("startBar") != asset.get("startBar")
        ):
            raise ScoreMotifBaselineReportError("asset score identity is inconsistent")
        compare_recomputed(evidence, reconstruct(source), f"assets[{index}].evidence")
    by_case: dict[str, list[Mapping[str, Any]]] = {}
    for asset in assets:
        by_case.setdefault(str(asset["caseId"]), []).append(asset)
    for case_id, paired in by_case.items():
        if len({item["planFingerprint"] for item in paired}) != 1:
            raise ScoreMotifBaselineReportError(f"{case_id} route plan mismatch")
        if len({item["evidence"]["evidenceFingerprint"] for item in paired}) != 1:
            raise ScoreMotifBaselineReportError(f"{case_id} route evidence mismatch")
        if any(item["input"] != paired[0]["input"] for item in paired[1:]):
            raise ScoreMotifBaselineReportError(f"{case_id} route score mismatch")
    if require_fingerprint:
        fingerprint = report.get("reportFingerprint")
        if not pcm.is_sha256(fingerprint):
            raise ScoreMotifBaselineReportError("report fingerprint is invalid")
        payload = dict(report)
        del payload["reportFingerprint"]
        expected = hashlib.sha256(pcm.canonical_bytes(payload)).hexdigest()
        if fingerprint != expected:
            raise ScoreMotifBaselineReportError("report fingerprint is stale")


def generate(
    payload_path: Path,
    output_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        payload = dict(pcm.load_json(payload_path, "score motif payload"))
        validate(payload, root, require_fingerprint=False)
        payload["reportFingerprint"] = hashlib.sha256(
            pcm.canonical_bytes(payload)
        ).hexdigest()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n",
            encoding="utf-8",
        )
    except (OSError, ValueError, pcm.PCMComparisonError,
            ScoreMotifBaselineReportError) as exc:
        print(f"score motif baseline generation rejected: {exc}", file=output)
        return 1
    bars = sum(int(asset["evidence"]["summary"]["barCount"])
               for asset in payload["assets"])
    notes = sum(int(asset["evidence"]["summary"]["eligibleNoteCount"])
                for asset in payload["assets"])
    comparisons = sum(int(asset["evidence"]["summary"]["availableComparisonCount"])
                      for asset in payload["assets"])
    print(
        f"generated score motif baseline: {len(payload['assets'])} accepted scores, "
        f"{bars} bars, {notes} eligible notes, {comparisons} available comparisons, "
        f"fingerprint {payload['reportFingerprint']}",
        file=output,
    )
    return 0


def check(report_path: Path, root: Path, output: TextIO = sys.stdout) -> int:
    try:
        report = pcm.load_json(report_path, "score motif baseline")
        validate(report, root, require_fingerprint=True)
    except (OSError, ValueError, pcm.PCMComparisonError,
            ScoreMotifBaselineReportError) as exc:
        print(f"score motif baseline rejected: {exc}", file=output)
        return 1
    print(
        f"score motif baseline is current: {len(report['assets'])} accepted "
        "scores independently reconstructed",
        file=output,
    )
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    generate_parser = subparsers.add_parser("generate")
    generate_parser.add_argument("--payload", type=Path, default=DEFAULT_PAYLOAD)
    generate_parser.add_argument("--output", type=Path, default=DEFAULT_REPORT)
    generate_parser.add_argument("--root", type=Path, default=repository_root())
    check_parser = subparsers.add_parser("check")
    check_parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    check_parser.add_argument("--root", type=Path, default=repository_root())
    arguments = parser.parse_args(argv)
    if arguments.command == "generate":
        return generate(arguments.payload, arguments.output, arguments.root)
    return check(arguments.report, arguments.root)


if __name__ == "__main__":
    raise SystemExit(main())
