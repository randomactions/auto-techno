#!/usr/bin/env python3
"""Finalize and independently verify local whole-mix rhythmic baselines."""

from __future__ import annotations

import argparse
from array import array
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
import signal_baseline_report as signal  # noqa: E402
import transient_envelope_baseline_report as transient  # noqa: E402


REPORT_SCHEMA = "autotechno-rhythmic-baseline-report.v1"
ANALYZER_VERSION = "autotechno-pcm-rhythmic-baseline-analyzer.v1"
EVIDENCE_SCHEMA = "autotechno-pcm-rhythmic-baseline.v1"
GRID_STEPS = 16
MAXIMUM_LAG = 4
PAYLOAD_KEYS = {
    "schema", "reportVersion", "analyzerVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "policies", "inputs", "assets",
}
REPORT_KEYS = PAYLOAD_KEYS | {"reportFingerprint"}
POLICY_KEYS = {
    "bpm", "beatsPerBar", "barDurationSeconds", "barFrameRounding",
    "beatOrigin", "eligibleSourceChannelCounts", "signalDomain", "monoFold",
    "onsetAnalyzerVersion", "onsetAuthority",
    "onsetActivityRelativeToSourcePeak", "onsetActivityAbsoluteFloor",
    "onsetEnvelopeReleaseSeconds", "onsetMergeSeconds", "scoreBindingStatus",
    "gridStepsPerBar", "gridQuantization", "microtimingUnit",
    "exactSilenceRule", "restDenominator", "interOnsetPolicy",
    "metricalDisplacementDefinition", "adjacentStrongRestDefinition",
    "maximumComparisonLagBars", "comparisonOrder",
    "mutationDistanceDefinition", "gridSimilarityDefinition",
    "rotationSearch", "comparisonAvailabilityPolicy", "finalPartialBarPolicy",
    "aggregation", "interpretation",
}
INPUT_KEYS = signal.INPUT_KEYS
ASSET_KEYS = {
    "assetId", "entryId", "checkpoint", "continuationClass", "phraseIndex",
    "startBar", "phraseKind", "planFingerprint", "pcmSha256", "wavPath",
    "evidence",
}
EVIDENCE_KEYS = {
    "schema", "sampleRate", "sourceChannelCount", "frameCount",
    "barFrameCount", "gridStepsPerBar", "maximumComparisonLagBars",
    "onsetAuthority", "scoreBindingStatus", "summary", "bars", "comparisons",
}
SUMMARY_KEYS = {
    "barCount", "completeBarCount", "partialBarCount", "exactSilentBarCount",
    "barsWithOnsets", "onsetCount", "comparisonCount",
    "unavailableComparisonCount", "exactPCMRepeatCount",
    "exactOnsetRepeatCount", "meanOnsetsPerCompleteBar", "meanRestOccupancy",
    "meanExactSilenceOccupancy", "meanMetricalDisplacement",
    "meanAdjacentStrongRestPotential", "meanGridMutationDistance",
    "meanBestRotationMutationDistance", "finite",
}
BAR_KEYS = {
    "index", "startFrame", "frameCount", "complete", "exactSilentFrameCount",
    "exactSilenceOccupancy", "onsetCount", "onsets", "gridOnsetCounts",
    "occupiedGridCellCount", "restGridCellCount", "restOccupancy",
    "linearInterOnsetFrameIntervals", "cyclicInterOnsetFrameIntervals",
    "cyclicIntervalStatus", "meanAbsoluteMicrotimingSteps",
    "maximumAbsoluteMicrotimingSteps", "metricalDisplacement",
    "adjacentStrongRestCount", "adjacentStrongRestPotential", "finite",
}
ONSET_KEYS = {
    "onsetFrame", "frameInBar", "onsetSource", "gridStep",
    "quantizedFrameInBar", "microtimingOffsetFrames",
    "microtimingOffsetSteps",
}
COMPARISON_KEYS = {
    "referenceBarIndex", "currentBarIndex", "lagBars", "availability",
    "exactPCMRepeat", "exactOnsetFrameRepeat", "gridMutationDistance",
    "gridSimilarity", "bestReferenceForwardRotationSteps",
    "bestRotationMutationDistance", "matchedMicrotimingDistanceSteps", "finite",
}
DEFAULT_PAYLOAD = Path(
    "docs/local/reports/rhythmic-baseline-v1/payload.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/rhythmic-baseline-v1/manifest.json"
)


class RhythmicBaselineReportError(RuntimeError):
    """An actionable schema, provenance, or independent-analysis failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> None:
    try:
        signal.exact_keys(value, expected, location)
    except signal.SignalBaselineReportError as exc:
        raise RhythmicBaselineReportError(str(exc)) from exc


def mean(values: Sequence[float]) -> Optional[float]:
    return sum(values) / len(values) if values else None


def quantize(frame_in_bar: int, bar_frames: int) -> tuple[int, int]:
    best_line = 0
    best_frame = 0
    best_distance = abs(frame_in_bar)
    for line in range(1, GRID_STEPS + 1):
        target = transient.rounded_frames(line * bar_frames / GRID_STEPS)
        distance = abs(frame_in_bar - target)
        if distance < best_distance:
            best_line, best_frame, best_distance = line, target, distance
    return best_line % GRID_STEPS, best_frame


def displacement_weight(step: int) -> float:
    if step % 4 == 0:
        return 0.0
    if step % 2 == 0:
        return 0.5
    return 1.0


def metrical_strength(step: int) -> int:
    if step % 4 == 0:
        return 3
    if step % 2 == 0:
        return 2
    return 1


def make_bar(
    index: int,
    start: int,
    count: int,
    bar_frames: int,
    channels: Sequence[Sequence[float]],
    events: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    complete = count == bar_frames
    onsets: list[dict[str, Any]] = []
    counts = [0] * GRID_STEPS
    for event in events:
        onset = int(event["onsetFrame"])
        frame_in_bar = onset - start
        grid_step, target = quantize(frame_in_bar, bar_frames)
        offset = frame_in_bar - target
        onsets.append({
            "onsetFrame": onset,
            "frameInBar": frame_in_bar,
            "onsetSource": event["onsetSource"],
            "gridStep": grid_step,
            "quantizedFrameInBar": target,
            "microtimingOffsetFrames": offset,
            "microtimingOffsetSteps": offset * GRID_STEPS / bar_frames,
        })
        counts[grid_step] += 1
    occupied = sum(value > 0 for value in counts)
    exact_silent = sum(
        all(channel[start + offset] == 0.0 for channel in channels)
        for offset in range(count)
    )
    frames = sorted(int(event["frameInBar"]) for event in onsets)
    linear = [right - left for left, right in zip(frames, frames[1:])]
    if not complete:
        cyclic_status, cyclic = "unavailable-partial-bar", []
    elif not frames:
        cyclic_status, cyclic = "unavailable-no-onsets", []
    elif len(frames) == 1:
        cyclic_status, cyclic = "available", [bar_frames]
    else:
        cyclic_status = "available"
        cyclic = linear + [bar_frames - frames[-1] + frames[0]]
    microtiming = [abs(float(event["microtimingOffsetSteps"]))
                   for event in onsets]
    displacement = [displacement_weight(int(event["gridStep"]))
                    for event in onsets]
    strong_rest = sum(
        counts[step] > 0
        and counts[(step + 1) % GRID_STEPS] == 0
        and metrical_strength((step + 1) % GRID_STEPS)
            > metrical_strength(step)
        for step in range(GRID_STEPS)
    )
    return {
        "index": index,
        "startFrame": start,
        "frameCount": count,
        "complete": complete,
        "exactSilentFrameCount": exact_silent,
        "exactSilenceOccupancy": exact_silent / count,
        "onsetCount": len(onsets),
        "onsets": onsets,
        "gridOnsetCounts": counts,
        "occupiedGridCellCount": occupied,
        "restGridCellCount": GRID_STEPS - occupied,
        "restOccupancy": (GRID_STEPS - occupied) / GRID_STEPS,
        "linearInterOnsetFrameIntervals": linear,
        "cyclicInterOnsetFrameIntervals": cyclic,
        "cyclicIntervalStatus": cyclic_status,
        "meanAbsoluteMicrotimingSteps": mean(microtiming),
        "maximumAbsoluteMicrotimingSteps": max(microtiming, default=None),
        "metricalDisplacement": mean(displacement),
        "adjacentStrongRestCount": strong_rest,
        "adjacentStrongRestPotential": (
            strong_rest / occupied if occupied else None
        ),
        "finite": True,
    }


def mutation_distance(first: Sequence[int], second: Sequence[int]) -> float:
    numerator = sum(abs(left - right) for left, right in zip(first, second))
    denominator = sum(first) + sum(second)
    return numerator / denominator if denominator else 0.0


def grid_similarity(first: Sequence[int], second: Sequence[int]) -> float:
    intersection = sum(min(left, right) for left, right in zip(first, second))
    union = sum(max(left, right) for left, right in zip(first, second))
    return intersection / union if union else 0.0


def exact_pcm_repeat(
    channel_bytes: Sequence[bytes],
    reference_start: int,
    current_start: int,
    frame_count: int,
) -> bool:
    reference_slice = slice(reference_start * 4, (reference_start + frame_count) * 4)
    current_slice = slice(current_start * 4, (current_start + frame_count) * 4)
    return all(
        data[reference_slice] == data[current_slice]
        for data in channel_bytes
    )


def matched_microtiming_distance(
    reference: Mapping[str, Any], current: Mapping[str, Any]
) -> Optional[float]:
    distances: list[float] = []
    for step in range(GRID_STEPS):
        first = sorted(
            float(event["microtimingOffsetSteps"])
            for event in reference["onsets"]
            if int(event["gridStep"]) == step
        )
        second = sorted(
            float(event["microtimingOffsetSteps"])
            for event in current["onsets"]
            if int(event["gridStep"]) == step
        )
        distances.extend(abs(left - right) for left, right in zip(first, second))
    return mean(distances)


def compare_bars(
    reference: Mapping[str, Any],
    current: Mapping[str, Any],
    channel_bytes: Sequence[bytes],
    bar_frames: int,
    lag: int,
) -> dict[str, Any]:
    exact_pcm = exact_pcm_repeat(
        channel_bytes,
        int(reference["startFrame"]),
        int(current["startFrame"]),
        bar_frames,
    )
    if not reference["onsets"] and not current["onsets"]:
        return {
            "referenceBarIndex": reference["index"],
            "currentBarIndex": current["index"],
            "lagBars": lag,
            "availability": "unavailable-no-onsets-in-either-bar",
            "exactPCMRepeat": exact_pcm,
            "exactOnsetFrameRepeat": None,
            "gridMutationDistance": None,
            "gridSimilarity": None,
            "bestReferenceForwardRotationSteps": None,
            "bestRotationMutationDistance": None,
            "matchedMicrotimingDistanceSteps": None,
            "finite": True,
        }
    first = list(reference["gridOnsetCounts"])
    second = list(current["gridOnsetCounts"])
    distance = mutation_distance(first, second)
    similarity = grid_similarity(first, second)
    best_shift = 0
    best_distance = math.inf
    for shift in range(GRID_STEPS):
        rotated = [0] * GRID_STEPS
        for step, value in enumerate(first):
            rotated[(step + shift) % GRID_STEPS] = value
        candidate = mutation_distance(rotated, second)
        if candidate < best_distance:
            best_shift, best_distance = shift, candidate
    microtiming = matched_microtiming_distance(reference, current)
    return {
        "referenceBarIndex": reference["index"],
        "currentBarIndex": current["index"],
        "lagBars": lag,
        "availability": "available",
        "exactPCMRepeat": exact_pcm,
        "exactOnsetFrameRepeat": (
            [event["frameInBar"] for event in reference["onsets"]]
            == [event["frameInBar"] for event in current["onsets"]]
        ),
        "gridMutationDistance": distance,
        "gridSimilarity": similarity,
        "bestReferenceForwardRotationSteps": best_shift,
        "bestRotationMutationDistance": best_distance,
        "matchedMicrotimingDistanceSteps": microtiming,
        "finite": all(math.isfinite(value) for value in (
            [distance, similarity, best_distance]
            + ([] if microtiming is None else [microtiming])
        )),
    }


def summarize(
    bars: Sequence[Mapping[str, Any]],
    comparisons: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    complete = [bar for bar in bars if bar["complete"]]
    available = [comparison for comparison in comparisons
                 if comparison["availability"] == "available"]
    displacement = [float(bar["metricalDisplacement"]) for bar in complete
                    if bar["metricalDisplacement"] is not None]
    strong_rest = [float(bar["adjacentStrongRestPotential"])
                   for bar in complete
                   if bar["adjacentStrongRestPotential"] is not None]
    mutation = [float(item["gridMutationDistance"]) for item in available]
    rotation = [float(item["bestRotationMutationDistance"])
                for item in available]
    values = [
        mean([float(bar["onsetCount"]) for bar in complete]),
        mean([float(bar["restOccupancy"]) for bar in complete]),
        mean([float(bar["exactSilenceOccupancy"]) for bar in complete]),
        mean(displacement), mean(strong_rest), mean(mutation), mean(rotation),
    ]
    return {
        "barCount": len(bars),
        "completeBarCount": len(complete),
        "partialBarCount": len(bars) - len(complete),
        "exactSilentBarCount": sum(
            bar["exactSilentFrameCount"] == bar["frameCount"] for bar in bars
        ),
        "barsWithOnsets": sum(int(bar["onsetCount"]) > 0 for bar in bars),
        "onsetCount": sum(int(bar["onsetCount"]) for bar in bars),
        "comparisonCount": len(comparisons),
        "unavailableComparisonCount": len(comparisons) - len(available),
        "exactPCMRepeatCount": sum(item["exactPCMRepeat"] for item in available),
        "exactOnsetRepeatCount": sum(
            item["exactOnsetFrameRepeat"] is True for item in available
        ),
        "meanOnsetsPerCompleteBar": values[0],
        "meanRestOccupancy": values[1],
        "meanExactSilenceOccupancy": values[2],
        "meanMetricalDisplacement": values[3],
        "meanAdjacentStrongRestPotential": values[4],
        "meanGridMutationDistance": values[5],
        "meanBestRotationMutationDistance": values[6],
        "finite": all(value is None or math.isfinite(value) for value in values),
    }


def analyze_pcm(
    channels: Sequence[Sequence[float]], sample_rate: int
) -> dict[str, Any]:
    bar_frames = transient.rounded_frames(sample_rate * 240.0 / 130.0)
    onset_evidence = transient.analyze_pcm(channels, sample_rate, bar_frames)
    events = list(onset_evidence["events"])
    bars: list[dict[str, Any]] = []
    start = 0
    frame_count = len(channels[0])
    while start < frame_count:
        count = min(bar_frames, frame_count - start)
        selected = [event for event in events
                    if start <= int(event["onsetFrame"]) < start + count]
        bars.append(make_bar(
            len(bars), start, count, bar_frames, channels, selected
        ))
        start += count
    channel_bytes = [
        channel.tobytes() if isinstance(channel, array)
        else array("f", channel).tobytes()
        for channel in channels
    ]
    comparisons: list[dict[str, Any]] = []
    for current_index, current in enumerate(bars):
        if not current["complete"]:
            continue
        maximum_lag = min(MAXIMUM_LAG, current_index)
        for lag in range(1, maximum_lag + 1):
            reference = bars[current_index - lag]
            if reference["complete"]:
                comparisons.append(compare_bars(
                    reference, current, channel_bytes, bar_frames, lag
                ))
    return {
        "schema": EVIDENCE_SCHEMA,
        "sampleRate": sample_rate,
        "sourceChannelCount": len(channels),
        "frameCount": frame_count,
        "barFrameCount": bar_frames,
        "gridStepsPerBar": GRID_STEPS,
        "maximumComparisonLagBars": MAXIMUM_LAG,
        "onsetAuthority": (
            "pcm-inferred-activity-rise-or-legacy-flux-not-score-bound"
        ),
        "scoreBindingStatus": (
            "unavailable-whole-manifest-does-not-retain-score-events"
        ),
        "summary": summarize(bars, comparisons),
        "bars": bars,
        "comparisons": comparisons,
    }


def compare_recomputed(actual: object, expected: object, location: str) -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            raise RhythmicBaselineReportError(f"{location} must be an object")
        exact_keys(actual, set(expected), location)
        for key, expected_value in expected.items():
            compare_recomputed(actual[key], expected_value, f"{location}.{key}")
    elif isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise RhythmicBaselineReportError(
                f"{location} has wrong cardinality"
            )
        for index, (actual_item, expected_item) in enumerate(zip(actual, expected)):
            compare_recomputed(
                actual_item, expected_item, f"{location}[{index}]"
            )
    elif isinstance(expected, float):
        if (
            isinstance(actual, bool)
            or not isinstance(actual, (int, float))
            or not math.isfinite(float(actual))
            or not transient.close(float(actual), expected, 2e-8)
        ):
            raise RhythmicBaselineReportError(
                f"{location} does not independently recompute"
            )
    elif actual != expected:
        raise RhythmicBaselineReportError(
            f"{location} does not independently recompute"
        )


def expected_policy() -> dict[str, object]:
    return {
        "bpm": 130.0,
        "beatsPerBar": 4,
        "barDurationSeconds": 240.0 / 130.0,
        "barFrameRounding": "nearest-frame",
        "beatOrigin": "source-frame-zero-manifest-phrase-boundary",
        "eligibleSourceChannelCounts": [1, 2],
        "signalDomain": "accepted-whole-mix-only",
        "monoFold": "arithmetic-mean-of-source-channels",
        "onsetAnalyzerVersion": transient.ANALYZER_VERSION,
        "onsetAuthority": (
            "pcm-inferred-activity-rise-or-legacy-flux-not-score-bound"
        ),
        "onsetActivityRelativeToSourcePeak": transient.ACTIVITY_RELATIVE_TO_PEAK,
        "onsetActivityAbsoluteFloor": transient.ACTIVITY_ABSOLUTE_FLOOR,
        "onsetEnvelopeReleaseSeconds": transient.RELEASE_SECONDS,
        "onsetMergeSeconds": transient.REFRACTORY_SECONDS,
        "scoreBindingStatus": (
            "unavailable-whole-manifest-does-not-retain-score-events"
        ),
        "gridStepsPerBar": GRID_STEPS,
        "gridQuantization": (
            "nearest-cyclic-sixteenth-ties-to-earlier-grid-line"
        ),
        "microtimingUnit": (
            "signed-fraction-of-one-sixteenth-relative-to-nearest-grid-line"
        ),
        "exactSilenceRule": (
            "all-source-channels-exact-positive-or-negative-digital-zero"
        ),
        "restDenominator": "sixteen-grid-cells-per-complete-or-partial-bar",
        "interOnsetPolicy": (
            "linear-within-every-bar-cyclic-only-for-complete-active-bars"
        ),
        "metricalDisplacementDefinition": (
            "quarter-zero-eighth-offbeat-one-half-sixteenth-offbeat-one"
        ),
        "adjacentStrongRestDefinition": (
            "occupied-cell-followed-by-empty-cell-of-greater-quarter-eighth-"
            "sixteenth-strength"
        ),
        "maximumComparisonLagBars": MAXIMUM_LAG,
        "comparisonOrder": "current-bar-ascending-then-lag-one-through-four",
        "mutationDistanceDefinition": (
            "l1-grid-count-difference-over-combined-onset-count"
        ),
        "gridSimilarityDefinition": (
            "sum-cellwise-minimum-over-sum-cellwise-maximum"
        ),
        "rotationSearch": (
            "all-sixteen-forward-reference-rotations-lowest-shift-wins-tie"
        ),
        "comparisonAvailabilityPolicy": (
            "two-no-onset-bars-unavailable-not-perfect-repetition"
        ),
        "finalPartialBarPolicy": (
            "describe-linear-facts-exclude-cyclic-and-lag-comparisons"
        ),
        "aggregation": (
            "arithmetic-mean-of-complete-bars-or-available-comparisons"
        ),
        "interpretation": (
            "descriptive-not-ranked-not-calibrated-no-groove-quality-score"
        ),
    }


def validate_evidence(
    value: object,
    channels: Sequence[Sequence[float]],
    sample_rate: int,
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise RhythmicBaselineReportError(f"{location} must be an object")
    exact_keys(value, EVIDENCE_KEYS, location)
    summary = value.get("summary")
    bars = value.get("bars")
    comparisons = value.get("comparisons")
    if isinstance(summary, dict):
        exact_keys(summary, SUMMARY_KEYS, f"{location}.summary")
    if isinstance(bars, list):
        for index, bar in enumerate(bars):
            if isinstance(bar, dict):
                exact_keys(bar, BAR_KEYS, f"{location}.bars[{index}]")
                onsets = bar.get("onsets")
                if isinstance(onsets, list):
                    for onset_index, onset in enumerate(onsets):
                        if isinstance(onset, dict):
                            exact_keys(
                                onset, ONSET_KEYS,
                                f"{location}.bars[{index}].onsets[{onset_index}]",
                            )
    if isinstance(comparisons, list):
        for index, comparison in enumerate(comparisons):
            if isinstance(comparison, dict):
                exact_keys(
                    comparison, COMPARISON_KEYS,
                    f"{location}.comparisons[{index}]",
                )
    compare_recomputed(value, analyze_pcm(channels, sample_rate), location)


def expected_assets(manifest: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        raise RhythmicBaselineReportError("whole manifest entries are invalid")
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
            raise RhythmicBaselineReportError(
                f"whole manifest entries[{index}] is invalid"
            )
        identifier = str(entry["id"]) + "::whole-mix"
        result[identifier] = {
            "assetId": identifier,
            "entryId": entry["id"],
            "checkpoint": entry["checkpoint"],
            "continuationClass": entry["continuationClass"],
            "phraseIndex": entry["phraseIndex"],
            "startBar": entry["startBar"],
            "phraseKind": entry["phraseKind"],
            "planFingerprint": entry["planFingerprint"],
            "pcmSha256": entry["pcmSha256"],
            "wavPath": entry["wavPath"],
            "sampleRate": entry["sampleRate"],
        }
    return result


def validate_asset(
    value: object,
    expected: Mapping[str, Any],
    root: Path,
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise RhythmicBaselineReportError(f"{location} must be an object")
    exact_keys(value, ASSET_KEYS, location)
    for key in ASSET_KEYS - {"evidence"}:
        if value.get(key) != expected.get(key):
            raise RhythmicBaselineReportError(
                f"{location}.{key} does not match its manifest"
            )
    path = pcm.resolve_local_path(root, value.get("wavPath"), f"{location}.wavPath")
    sample_rate, channels = transient.read_channels(path)
    if sample_rate != expected.get("sampleRate"):
        raise RhythmicBaselineReportError(
            f"{location} sample rate does not match its manifest"
        )
    validate_evidence(value.get("evidence"), channels, sample_rate,
                      f"{location}.evidence")


def validate(report: Mapping[str, Any], root: Path, require_fingerprint: bool) -> None:
    exact_keys(report, REPORT_KEYS if require_fingerprint else PAYLOAD_KEYS, "report")
    if report.get("schema") != REPORT_SCHEMA or report.get("reportVersion") != 1:
        raise RhythmicBaselineReportError("report schema/version is invalid")
    if report.get("analyzerVersion") != ANALYZER_VERSION:
        raise RhythmicBaselineReportError("analyzerVersion is invalid")
    if report.get("corpusSha256") != pcm.sha256(root / "docs/BASELINE_CORPUS.json"):
        raise RhythmicBaselineReportError("corpusSha256 is stale")
    baseline = pcm.load_json(
        root / "docs/ROADMAP_EXECUTION_BASELINE.json", "contract baseline"
    )
    if report.get("contractBaselineFingerprint") != baseline.get(
        "snapshotFingerprint"
    ):
        raise RhythmicBaselineReportError(
            "contractBaselineFingerprint is stale"
        )
    policies = report.get("policies")
    if not isinstance(policies, dict):
        raise RhythmicBaselineReportError("policies must be an object")
    exact_keys(policies, POLICY_KEYS, "policies")
    compare_recomputed(policies, expected_policy(), "policies")
    inputs = report.get("inputs")
    if (
        not isinstance(inputs, list)
        or len(inputs) != 1
        or not isinstance(inputs[0], dict)
        or inputs[0].get("domain") != "whole-mix"
    ):
        raise RhythmicBaselineReportError(
            "inputs must contain exactly the whole-mix manifest"
        )
    input_record = inputs[0]
    exact_keys(input_record, INPUT_KEYS, "inputs[0]")
    manifest_path = pcm.resolve_local_path(
        root, input_record.get("manifestPath"), "inputs[0].manifestPath"
    )
    manifest = pcm.load_json(manifest_path, "whole-mix manifest")
    if input_record.get("manifestSha256") != pcm.sha256(manifest_path):
        raise RhythmicBaselineReportError("inputs[0] manifest hash is stale")
    domain, artifacts = pcm.extract_artifacts(manifest, root, "whole-mix")
    if domain != "whole-mix" or input_record.get("manifestSchema") != manifest.get(
        "schema"
    ):
        raise RhythmicBaselineReportError("inputs[0] domain/schema mismatch")
    cache: dict[Path, pcm.ScannedWav] = {}
    scans = {
        identifier: pcm.scan_artifact(artifact, cache)
        for identifier, artifact in sorted(artifacts.items())
    }
    if (
        input_record.get("assetCount") != len(artifacts)
        or input_record.get("pcmSetFingerprint")
        != signal.pcm_set_fingerprint(artifacts, scans)
    ):
        raise RhythmicBaselineReportError("inputs[0] asset set is stale")
    if (
        report.get("sourceFingerprint") != manifest.get("sourceFingerprint")
        or report.get("gitHead") != manifest.get("gitHead")
        or report.get("engineVersion") != manifest.get("engineVersion")
    ):
        raise RhythmicBaselineReportError(
            "report provenance does not match its whole-mix input"
        )
    expected = expected_assets(manifest)
    assets = report.get("assets")
    if not isinstance(assets, list):
        raise RhythmicBaselineReportError("assets must be an array")
    identifiers = [item.get("assetId") for item in assets if isinstance(item, dict)]
    if identifiers != sorted(expected):
        raise RhythmicBaselineReportError(
            "assets must exactly cover the whole manifest in sorted identity order"
        )
    for index, asset in enumerate(assets):
        validate_asset(
            asset, expected[str(asset["assetId"])], root, f"assets[{index}]"
        )
    if require_fingerprint:
        fingerprint = report.get("reportFingerprint")
        if not pcm.is_sha256(fingerprint):
            raise RhythmicBaselineReportError(
                "reportFingerprint must be SHA-256"
            )
        payload = dict(report)
        del payload["reportFingerprint"]
        expected_fingerprint = hashlib.sha256(pcm.canonical_bytes(payload)).hexdigest()
        if fingerprint != expected_fingerprint:
            raise RhythmicBaselineReportError(
                "reportFingerprint is stale or mutated"
            )


def generate(
    payload_path: Path,
    output_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        payload = dict(pcm.load_json(payload_path, "rhythmic baseline payload"))
        validate(payload, root, require_fingerprint=False)
        payload["reportFingerprint"] = hashlib.sha256(
            pcm.canonical_bytes(payload)
        ).hexdigest()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n",
            encoding="utf-8",
        )
    except (
        OSError, ValueError, pcm.PCMComparisonError,
        signal.SignalBaselineReportError,
        transient.TransientEnvelopeBaselineReportError,
        RhythmicBaselineReportError,
    ) as exc:
        print(f"rhythmic baseline generation rejected: {exc}", file=output)
        return 1
    bar_count = sum(int(asset["evidence"]["summary"]["barCount"])
                    for asset in payload["assets"])
    onset_count = sum(int(asset["evidence"]["summary"]["onsetCount"])
                      for asset in payload["assets"])
    comparison_count = sum(
        int(asset["evidence"]["summary"]["comparisonCount"])
        for asset in payload["assets"]
    )
    print(
        f"generated rhythmic baseline: {len(payload['assets'])} whole mixes, "
        f"{bar_count} bars, {onset_count} PCM-inferred onsets, "
        f"{comparison_count} bounded comparisons, fingerprint "
        f"{payload['reportFingerprint']}",
        file=output,
    )
    return 0


def check(
    report_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        report = pcm.load_json(report_path, "rhythmic baseline")
        validate(report, root, require_fingerprint=True)
    except (
        OSError, ValueError, pcm.PCMComparisonError,
        signal.SignalBaselineReportError,
        transient.TransientEnvelopeBaselineReportError,
        RhythmicBaselineReportError,
    ) as exc:
        print(f"rhythmic baseline rejected: {exc}", file=output)
        return 1
    print(
        f"rhythmic baseline is current: {len(report['assets'])} whole-mix "
        "assets independently recomputed",
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
