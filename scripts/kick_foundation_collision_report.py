#!/usr/bin/env python3
"""Finalize and independently verify kick/foundation collision evidence."""

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


REPORT_SCHEMA = "autotechno-kick-foundation-collision-report.v1"
ANALYZER_VERSION = "autotechno-pcm-kick-foundation-collision-analyzer.v1"
EVIDENCE_SCHEMA = "autotechno-pcm-kick-foundation-collision.v1"
PAYLOAD_KEYS = {
    "schema", "reportVersion", "analyzerVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "policies", "inputs", "entries",
}
REPORT_KEYS = PAYLOAD_KEYS | {"reportFingerprint"}
POLICY_KEYS = {
    "bpm", "beatsPerBar", "scoreStepsPerBar", "eventWindowSteps",
    "eventWindowRounding", "windowsPerEvent",
    "activityMeanSquareThreshold", "lowBand", "lowBandOverlapThreshold",
    "bandEnergyModel", "durationModel", "eventSource", "confidence",
    "relativeEnergyUnit", "relativeEnergyInterpretation", "phasePolicy",
    "noKickPolicy",
}
ENTRY_KEYS = {
    "id", "caseId", "routeId", "rootSeed", "checkpoint",
    "continuationClass", "phraseIndex", "startBar", "phraseKind",
    "stateFingerprint", "planFingerprint", "replayFingerprint",
    "candidateEvaluationFingerprint", "sampleRate", "frameCount",
    "kickPcmSha256", "foundationPcmSha256", "barCount",
    "barsWithoutKick", "evidence",
}
EVIDENCE_KEYS = {
    "schema", "sampleRate", "frameCount", "kickSignal",
    "foundationSignal", "eventSource", "analysisWindow", "windowsPerEvent",
    "activityMeanSquareThreshold", "lowBand", "lowBandOverlapThreshold",
    "bandEnergyModel", "durationModel", "relativeEnergyUnit",
    "relativeEnergyInterpretation", "events", "finite",
}
EVENT_REQUIRED_KEYS = {
    "id", "bar", "step", "onsetFrame", "analysisEndFrame",
    "analysisFrameCount", "collisionClass", "responsibleSignals",
    "authoredFoundationRolesInBar", "pocketState",
    "pocketSilenceFrameCount", "kickActiveWindowCount",
    "foundationActiveWindowCount", "temporalOverlapWindowCount",
    "temporalOverlapFrameCount", "temporalOverlapSeconds",
    "longestTemporalOverlapFrameCount", "lowBandOverlapWindowCount",
    "lowBandOverlapFrameCount", "lowBandOverlapSeconds",
    "longestLowBandOverlapFrameCount", "maximumSubBandSimilarity",
    "durationResolutionMaximumFrames", "confidence", "windows", "finite",
}
EVENT_OPTIONAL_KEYS = {
    "firstTemporalOverlapFrame", "lastTemporalOverlapEndFrame",
    "firstLowBandOverlapFrame", "lastLowBandOverlapEndFrame",
    "kickOverFoundationDB",
}
WINDOW_KEYS = {
    "index", "startFrame", "frameCount", "kickMeanSquare",
    "foundationMeanSquare", "kickSubMeanSquare", "foundationSubMeanSquare",
    "kickActive", "foundationActive", "temporalOverlap",
    "subBandSimilarity", "lowBandOverlap",
}
BAND_KEYS = {"name", "lowerHz", "upperHz"}
SUPPORTED_SAMPLE_RATES = {44_100, 48_000}
WINDOW_COUNT = 16
ACTIVITY_THRESHOLD = 1e-10
OVERLAP_THRESHOLD = 0.38
CUTOFFS = (35.0, 120.0, 420.0, 2_400.0, 10_000.0)
BAND = {"name": "sub", "lowerHz": 35, "upperHz": 120}
EVENT_SOURCE = "accepted-resolved-score-and-selected-candidate"
ANALYSIS_WINDOW = "kick-onset-through-two-sixteenth-steps-bar-bounded"
BAND_MODEL = (
    "causal-one-pole-difference-non-power-complementary-reset-at-event-onset"
)
DURATION_MODEL = "sixteen-causal-cells-quantized-not-sample-exact"
CONFIDENCE = "exact-pcm-score-event-bound-causal-cell-quantized"
RELATIVE_UNIT = "kick-over-foundation-db-power-ratio"
RELATIVE_INTERPRETATION = "descriptive-not-calibrated-not-excessive"
DEFAULT_PAYLOAD = Path(
    "docs/local/reports/kick-foundation-collision-v1/payload.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/kick-foundation-collision-v1/manifest.json"
)


class KickFoundationCollisionReportError(RuntimeError):
    """An actionable provenance, geometry, or evidence mismatch."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str
) -> None:
    if set(value) != expected:
        raise KickFoundationCollisionReportError(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(value)}"
        )


def event_keys(value: Mapping[str, Any], location: str) -> None:
    actual = set(value)
    if not EVENT_REQUIRED_KEYS.issubset(actual) or not actual.issubset(
        EVENT_REQUIRED_KEYS | EVENT_OPTIONAL_KEYS
    ):
        raise KickFoundationCollisionReportError(
            f"{location} has missing or unknown fields"
        )


def finite_number(value: object, location: str) -> float:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(float(value))
    ):
        raise KickFoundationCollisionReportError(
            f"{location} must be finite numeric"
        )
    return float(value)


def nonnegative_integer(value: object, location: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise KickFoundationCollisionReportError(
            f"{location} must be a non-negative integer"
        )
    return value


def close(actual: float, expected: float, tolerance: float = 1e-9) -> bool:
    return abs(actual - expected) <= tolerance * max(1.0, abs(expected))


def nearest_frame(value: float) -> int:
    return math.floor(value + 0.5)


def load_mono_samples(artifact: pcm.Artifact) -> list[float]:
    try:
        with artifact.path.open("rb") as handle:
            _, channels, frames, remaining, _ = pcm.read_wav_header(
                handle, artifact.path
            )
            if channels != 1:
                raise KickFoundationCollisionReportError(
                    f"{artifact.identifier} must be mono"
                )
            payload = handle.read(remaining)
    except OSError as exc:
        raise KickFoundationCollisionReportError(
            f"cannot read {artifact.identifier}: {exc}"
        ) from exc
    if len(payload) != remaining or remaining != frames * 4:
        raise KickFoundationCollisionReportError(
            f"{artifact.identifier} PCM length changed"
        )
    values = array("f")
    values.frombytes(payload)
    if sys.byteorder != "little":
        values.byteswap()
    result = [float(value) for value in values]
    if len(result) != frames or any(not math.isfinite(value) for value in result):
        raise KickFoundationCollisionReportError(
            f"{artifact.identifier} PCM is malformed"
        )
    return result


def band_windows(samples: Sequence[float], sample_rate: int) -> list[dict[str, Any]]:
    coefficients = [
        1.0 - math.exp(
            -2.0 * math.pi * min(cutoff, sample_rate * 0.45) / sample_rate
        )
        for cutoff in CUTOFFS
    ]
    states = [0.0] * len(CUTOFFS)
    source_sums = [0.0] * WINDOW_COUNT
    band_sums = [[0.0] * 4 for _ in range(WINDOW_COUNT)]
    counts = [0] * WINDOW_COUNT
    for frame, sample in enumerate(samples):
        for index, coefficient in enumerate(coefficients):
            states[index] += (sample - states[index]) * coefficient
        window = min(WINDOW_COUNT - 1, frame * WINDOW_COUNT // len(samples))
        counts[window] += 1
        source_sums[window] += sample * sample
        components = (
            states[1] - states[0],
            states[2] - states[1],
            states[3] - states[2],
            states[4] - states[3],
        )
        for band, component in enumerate(components):
            band_sums[window][band] += component * component
    result: list[dict[str, Any]] = []
    start = 0
    for index, count in enumerate(counts):
        divisor = max(1, count)
        result.append({
            "index": index,
            "startFrame": start,
            "frameCount": count,
            "sourceMeanSquare": source_sums[index] / divisor,
            "bandMeanSquares": [value / divisor for value in band_sums[index]],
        })
        start += count
    return result


def longest_run(windows: Sequence[Mapping[str, Any]], key: str) -> int:
    current = 0
    longest = 0
    for window in windows:
        if window[key]:
            current += int(window["frameCount"])
            longest = max(longest, current)
        else:
            current = 0
    return longest


def optional_expected(
    value: Mapping[str, Any], key: str, expected: Optional[float | int], location: str
) -> None:
    if expected is None:
        if key in value:
            raise KickFoundationCollisionReportError(
                f"{location}.{key} must be absent when unavailable"
            )
        return
    if key not in value:
        raise KickFoundationCollisionReportError(
            f"{location}.{key} is missing"
        )
    actual = value[key]
    if isinstance(expected, float):
        if not close(finite_number(actual, f"{location}.{key}"), expected, 1e-10):
            raise KickFoundationCollisionReportError(
                f"{location}.{key} does not recompute"
            )
    elif actual != expected:
        raise KickFoundationCollisionReportError(
            f"{location}.{key} does not recompute"
        )


def validate_event(
    value: object,
    entry: Mapping[str, Any],
    kick: Sequence[float],
    foundation: Sequence[float],
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise KickFoundationCollisionReportError(f"{location} must be an object")
    event_keys(value, location)
    bar = nonnegative_integer(value.get("bar"), f"{location}.bar")
    step = nonnegative_integer(value.get("step"), f"{location}.step")
    start_bar = int(entry["startBar"])
    bar_count = int(entry["barCount"])
    if not start_bar <= bar < start_bar + bar_count or step >= 16:
        raise KickFoundationCollisionReportError(
            f"{location} bar/step is outside the phrase"
        )
    identifier = f"{entry['id']}--bar-{bar}-step-{step}"
    if value.get("id") != identifier:
        raise KickFoundationCollisionReportError(f"{location}.id is not canonical")
    sample_rate = int(entry["sampleRate"])
    bar_frames = nearest_frame(sample_rate * 240.0 / 130.0)
    bar_start = (bar - start_bar) * bar_frames
    onset = bar_start + nearest_frame(step * bar_frames / 16.0)
    end = min(bar_start + bar_frames, onset + nearest_frame(bar_frames / 8.0))
    frame_count = end - onset
    if (
        value.get("onsetFrame") != onset
        or value.get("analysisEndFrame") != end
        or value.get("analysisFrameCount") != frame_count
        or frame_count < WINDOW_COUNT
    ):
        raise KickFoundationCollisionReportError(
            f"{location} event geometry does not recompute"
        )
    expected_kick = band_windows(kick[onset:end], sample_rate)
    expected_foundation = band_windows(foundation[onset:end], sample_rate)
    reported_windows = value.get("windows")
    if not isinstance(reported_windows, list) or len(reported_windows) != WINDOW_COUNT:
        raise KickFoundationCollisionReportError(
            f"{location}.windows must contain {WINDOW_COUNT} cells"
        )
    reconstructed: list[dict[str, Any]] = []
    for index, (reported, kick_window, foundation_window) in enumerate(zip(
        reported_windows, expected_kick, expected_foundation
    )):
        window_location = f"{location}.windows[{index}]"
        if not isinstance(reported, dict):
            raise KickFoundationCollisionReportError(
                f"{window_location} must be an object"
            )
        exact_keys(reported, WINDOW_KEYS, window_location)
        kick_ms = float(kick_window["sourceMeanSquare"])
        foundation_ms = float(foundation_window["sourceMeanSquare"])
        kick_sub = float(kick_window["bandMeanSquares"][0])
        foundation_sub = float(foundation_window["bandMeanSquares"][0])
        kick_active = kick_ms > ACTIVITY_THRESHOLD
        foundation_active = foundation_ms > ACTIVITY_THRESHOLD
        temporal = kick_active and foundation_active
        sub_pair = (
            temporal
            and kick_sub > ACTIVITY_THRESHOLD
            and foundation_sub > ACTIVITY_THRESHOLD
        )
        similarity = (
            min(kick_sub, foundation_sub) / max(kick_sub, foundation_sub)
            if sub_pair else 0.0
        )
        low = sub_pair and similarity > OVERLAP_THRESHOLD
        expected_fields = {
            "index": index,
            "startFrame": onset + int(kick_window["startFrame"]),
            "frameCount": int(kick_window["frameCount"]),
            "kickActive": kick_active,
            "foundationActive": foundation_active,
            "temporalOverlap": temporal,
            "lowBandOverlap": low,
        }
        for key, expected in expected_fields.items():
            if reported.get(key) != expected:
                raise KickFoundationCollisionReportError(
                    f"{window_location}.{key} does not recompute"
                )
        numeric_fields = {
            "kickMeanSquare": kick_ms,
            "foundationMeanSquare": foundation_ms,
            "kickSubMeanSquare": kick_sub,
            "foundationSubMeanSquare": foundation_sub,
            "subBandSimilarity": similarity,
        }
        for key, expected in numeric_fields.items():
            actual = finite_number(reported.get(key), f"{window_location}.{key}")
            if actual < 0 or not close(actual, expected, 1e-10):
                raise KickFoundationCollisionReportError(
                    f"{window_location}.{key} does not recompute"
                )
        reconstructed.append(dict(reported))

    kick_active_windows = [item for item in reconstructed if item["kickActive"]]
    foundation_active_windows = [
        item for item in reconstructed if item["foundationActive"]
    ]
    temporal = [item for item in reconstructed if item["temporalOverlap"]]
    low = [item for item in reconstructed if item["lowBandOverlap"]]
    if not kick_active_windows and not foundation_active_windows:
        collision_class = "mutual-silence"
    elif not foundation_active_windows:
        collision_class = "kick-only"
    elif not kick_active_windows:
        collision_class = "foundation-only"
    elif not temporal:
        collision_class = "separated"
    elif not low:
        collision_class = "temporal-overlap"
    else:
        collision_class = "low-band-overlap"
    if value.get("collisionClass") != collision_class:
        raise KickFoundationCollisionReportError(
            f"{location}.collisionClass does not recompute"
        )
    if value.get("responsibleSignals") != ["kick", "foundation"]:
        raise KickFoundationCollisionReportError(
            f"{location}.responsibleSignals is invalid"
        )
    roles = value.get("authoredFoundationRolesInBar")
    if (
        not isinstance(roles, list)
        or roles != sorted(set(roles))
        or any(role not in {"bass", "rumble", "tunedTom"} for role in roles)
    ):
        raise KickFoundationCollisionReportError(
            f"{location}.authoredFoundationRolesInBar is invalid"
        )
    count_expectations = {
        "kickActiveWindowCount": len(kick_active_windows),
        "foundationActiveWindowCount": len(foundation_active_windows),
        "temporalOverlapWindowCount": len(temporal),
        "temporalOverlapFrameCount": sum(item["frameCount"] for item in temporal),
        "longestTemporalOverlapFrameCount": longest_run(
            reconstructed, "temporalOverlap"
        ),
        "lowBandOverlapWindowCount": len(low),
        "lowBandOverlapFrameCount": sum(item["frameCount"] for item in low),
        "longestLowBandOverlapFrameCount": longest_run(
            reconstructed, "lowBandOverlap"
        ),
        "durationResolutionMaximumFrames": max(
            item["frameCount"] for item in reconstructed
        ),
    }
    for key, expected in count_expectations.items():
        if value.get(key) != expected:
            raise KickFoundationCollisionReportError(
                f"{location}.{key} does not aggregate its windows"
            )
    temporal_frames = count_expectations["temporalOverlapFrameCount"]
    low_frames = count_expectations["lowBandOverlapFrameCount"]
    duration_expectations = {
        "temporalOverlapSeconds": temporal_frames / sample_rate,
        "lowBandOverlapSeconds": low_frames / sample_rate,
        "maximumSubBandSimilarity": max(
            item["subBandSimilarity"] for item in reconstructed
        ),
    }
    for key, expected in duration_expectations.items():
        actual = finite_number(value.get(key), f"{location}.{key}")
        if not close(actual, expected, 1e-10):
            raise KickFoundationCollisionReportError(
                f"{location}.{key} does not aggregate its windows"
            )
    optional_expected(
        value, "firstTemporalOverlapFrame",
        temporal[0]["startFrame"] if temporal else None, location
    )
    optional_expected(
        value, "lastTemporalOverlapEndFrame",
        temporal[-1]["startFrame"] + temporal[-1]["frameCount"]
        if temporal else None, location
    )
    optional_expected(
        value, "firstLowBandOverlapFrame",
        low[0]["startFrame"] if low else None, location
    )
    optional_expected(
        value, "lastLowBandOverlapEndFrame",
        low[-1]["startFrame"] + low[-1]["frameCount"] if low else None,
        location,
    )
    kick_energy = sum(
        item["kickMeanSquare"] * item["frameCount"] for item in temporal
    )
    foundation_energy = sum(
        item["foundationMeanSquare"] * item["frameCount"] for item in temporal
    )
    relative = (
        10.0 * math.log10(kick_energy / foundation_energy)
        if kick_energy > 0 and foundation_energy > 0 else None
    )
    optional_expected(value, "kickOverFoundationDB", relative, location)
    pocket = value.get("pocketState")
    pocket_frames = nonnegative_integer(
        value.get("pocketSilenceFrameCount"),
        f"{location}.pocketSilenceFrameCount",
    )
    if pocket == "not-authored":
        if pocket_frames != 0:
            raise KickFoundationCollisionReportError(
                f"{location} non-authored pocket must have zero frames"
            )
    elif pocket == "exact-silence":
        if pocket_frames <= 0 or onset < pocket_frames:
            raise KickFoundationCollisionReportError(
                f"{location} exact pocket has invalid geometry"
            )
        if any(
            sample != 0.0
            for sample in foundation[onset - pocket_frames:onset]
        ):
            raise KickFoundationCollisionReportError(
                f"{location} exact pocket is not exact PCM silence"
            )
    else:
        raise KickFoundationCollisionReportError(
            f"{location}.pocketState is invalid"
        )
    if value.get("confidence") != CONFIDENCE or value.get("finite") is not True:
        raise KickFoundationCollisionReportError(
            f"{location} confidence/finite status is invalid"
        )


def validate_evidence(
    value: object,
    entry: Mapping[str, Any],
    kick: Sequence[float],
    foundation: Sequence[float],
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise KickFoundationCollisionReportError(f"{location} must be an object")
    exact_keys(value, EVIDENCE_KEYS, location)
    exact_values = {
        "schema": EVIDENCE_SCHEMA,
        "sampleRate": entry["sampleRate"],
        "frameCount": entry["frameCount"],
        "kickSignal": "kick",
        "foundationSignal": "foundation",
        "eventSource": EVENT_SOURCE,
        "analysisWindow": ANALYSIS_WINDOW,
        "windowsPerEvent": WINDOW_COUNT,
        "bandEnergyModel": BAND_MODEL,
        "durationModel": DURATION_MODEL,
        "relativeEnergyUnit": RELATIVE_UNIT,
        "relativeEnergyInterpretation": RELATIVE_INTERPRETATION,
        "finite": True,
    }
    for key, expected in exact_values.items():
        if value.get(key) != expected:
            raise KickFoundationCollisionReportError(
                f"{location}.{key} is invalid"
            )
    if not close(
        finite_number(
            value.get("activityMeanSquareThreshold"),
            f"{location}.activityMeanSquareThreshold",
        ),
        ACTIVITY_THRESHOLD,
        1e-12,
    ) or not close(
        finite_number(
            value.get("lowBandOverlapThreshold"),
            f"{location}.lowBandOverlapThreshold",
        ),
        OVERLAP_THRESHOLD,
        1e-12,
    ):
        raise KickFoundationCollisionReportError(
            f"{location} thresholds are stale"
        )
    low_band = value.get("lowBand")
    if not isinstance(low_band, dict):
        raise KickFoundationCollisionReportError(f"{location}.lowBand is invalid")
    exact_keys(low_band, BAND_KEYS, f"{location}.lowBand")
    if low_band != BAND:
        raise KickFoundationCollisionReportError(f"{location}.lowBand is stale")
    events = value.get("events")
    if not isinstance(events, list):
        raise KickFoundationCollisionReportError(f"{location}.events must be an array")
    identities = [item.get("id") for item in events if isinstance(item, dict)]
    order = [
        (item.get("onsetFrame"), item.get("id"))
        for item in events if isinstance(item, dict)
    ]
    if len(identities) != len(events) or len(set(identities)) != len(events):
        raise KickFoundationCollisionReportError(f"{location}.events are duplicated")
    if order != sorted(order):
        raise KickFoundationCollisionReportError(f"{location}.events are not sorted")
    for index, event in enumerate(events):
        validate_event(
            event, entry, kick, foundation, f"{location}.events[{index}]"
        )
    bars_with_events = {int(item["bar"]) for item in events}
    expected_empty = [
        bar for bar in range(
            int(entry["startBar"]),
            int(entry["startBar"]) + int(entry["barCount"]),
        ) if bar not in bars_with_events
    ]
    if entry.get("barsWithoutKick") != expected_empty:
        raise KickFoundationCollisionReportError(
            f"{location} does not reconcile barsWithoutKick"
        )


def validate_policies(value: object) -> None:
    if not isinstance(value, dict):
        raise KickFoundationCollisionReportError("policies must be an object")
    exact_keys(value, POLICY_KEYS, "policies")
    expected = {
        "bpm": 130,
        "beatsPerBar": 4,
        "scoreStepsPerBar": 16,
        "eventWindowSteps": 2,
        "eventWindowRounding": "nearest-frame-bar-relative",
        "windowsPerEvent": WINDOW_COUNT,
        "activityMeanSquareThreshold": ACTIVITY_THRESHOLD,
        "lowBand": BAND,
        "lowBandOverlapThreshold": OVERLAP_THRESHOLD,
        "bandEnergyModel": BAND_MODEL,
        "durationModel": DURATION_MODEL,
        "eventSource": EVENT_SOURCE,
        "confidence": CONFIDENCE,
        "relativeEnergyUnit": RELATIVE_UNIT,
        "relativeEnergyInterpretation": RELATIVE_INTERPRETATION,
        "phasePolicy": "per-role-energy-only-no-role-sum-cancellation-inference",
        "noKickPolicy": "valid-entry-with-zero-eligible-events-and-explicit-bars",
    }
    for key, expected_value in expected.items():
        actual = value.get(key)
        if isinstance(expected_value, float):
            if not close(finite_number(actual, f"policies.{key}"), expected_value):
                raise KickFoundationCollisionReportError(
                    f"policies.{key} is invalid"
                )
        elif actual != expected_value:
            raise KickFoundationCollisionReportError(f"policies.{key} is invalid")


def load_inputs(
    report: Mapping[str, Any], root: Path
) -> tuple[Mapping[str, Any], Mapping[str, Any], dict[str, pcm.Artifact]]:
    inputs = report.get("inputs")
    if (
        not isinstance(inputs, list)
        or len(inputs) != 2
        or [item.get("domain") for item in inputs if isinstance(item, dict)]
        != ["whole-mix", "role-stems"]
    ):
        raise KickFoundationCollisionReportError(
            "inputs must contain whole-mix then role-stems"
        )
    cache: dict[Path, pcm.ScannedWav] = {}
    manifests: dict[str, Mapping[str, Any]] = {}
    all_artifacts: dict[str, pcm.Artifact] = {}
    common: Optional[tuple[object, object, object]] = None
    for index, input_record in enumerate(inputs):
        location = f"inputs[{index}]"
        if not isinstance(input_record, dict):
            raise KickFoundationCollisionReportError(f"{location} is invalid")
        exact_keys(input_record, signal.INPUT_KEYS, location)
        domain = str(input_record["domain"])
        path = pcm.resolve_local_path(
            root, input_record.get("manifestPath"), f"{location}.manifestPath"
        )
        manifest = pcm.load_json(path, f"{domain} manifest")
        manifest_domain, artifacts = pcm.extract_artifacts(manifest, root, domain)
        scans = {
            identifier: pcm.scan_artifact(artifact, cache)
            for identifier, artifact in sorted(artifacts.items())
        }
        if manifest_domain != domain:
            raise KickFoundationCollisionReportError(
                f"{location} domain/schema mismatch"
            )
        if input_record.get("manifestSha256") != pcm.sha256(path):
            raise KickFoundationCollisionReportError(
                f"{location} manifest hash is stale"
            )
        if input_record.get("manifestSchema") != manifest.get("schema"):
            raise KickFoundationCollisionReportError(f"{location} schema is stale")
        if input_record.get("assetCount") != len(artifacts):
            raise KickFoundationCollisionReportError(
                f"{location} assetCount is stale"
            )
        if input_record.get("pcmSetFingerprint") != signal.pcm_set_fingerprint(
            artifacts, scans
        ):
            raise KickFoundationCollisionReportError(
                f"{location} PCM-set fingerprint is stale"
            )
        provenance = (
            manifest.get("sourceFingerprint"),
            manifest.get("gitHead"),
            manifest.get("engineVersion"),
        )
        if common is None:
            common = provenance
        elif common != provenance:
            raise KickFoundationCollisionReportError(
                "input manifest provenance does not agree"
            )
        manifests[domain] = manifest
        all_artifacts.update(artifacts)
    assert common is not None
    if (
        report.get("sourceFingerprint"),
        report.get("gitHead"),
        report.get("engineVersion"),
    ) != common:
        raise KickFoundationCollisionReportError(
            "report provenance does not match input manifests"
        )
    return manifests["whole-mix"], manifests["role-stems"], all_artifacts


def manifest_entries(manifest: Mapping[str, Any], label: str) -> dict[str, Mapping[str, Any]]:
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        raise KickFoundationCollisionReportError(f"{label}.entries is invalid")
    result: dict[str, Mapping[str, Any]] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
            raise KickFoundationCollisionReportError(f"{label} entry is invalid")
        identifier = str(entry["id"])
        if identifier in result:
            raise KickFoundationCollisionReportError(
                f"{label} duplicates {identifier}"
            )
        result[identifier] = entry
    return result


def validate_entry(
    value: object,
    whole: Mapping[str, Any],
    stems: Mapping[str, Any],
    artifacts: Mapping[str, pcm.Artifact],
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise KickFoundationCollisionReportError(f"{location} must be an object")
    exact_keys(value, ENTRY_KEYS, location)
    identity_keys = (
        "id", "caseId", "routeId", "rootSeed", "checkpoint",
        "continuationClass", "phraseIndex", "startBar", "phraseKind",
        "stateFingerprint", "planFingerprint", "replayFingerprint",
        "sampleRate", "frameCount",
    )
    for key in identity_keys:
        if value.get(key) != whole.get(key) or value.get(key) != stems.get(key):
            raise KickFoundationCollisionReportError(
                f"{location}.{key} does not match both manifests"
            )
    identifier = str(value["id"])
    kick_artifact = artifacts.get(identifier + "::kick")
    foundation_artifact = artifacts.get(identifier + "::foundation")
    if kick_artifact is None or foundation_artifact is None:
        raise KickFoundationCollisionReportError(
            f"{location} lacks exact kick/foundation artifacts"
        )
    if (
        value.get("kickPcmSha256") != kick_artifact.expected_pcm_sha256
        or value.get("foundationPcmSha256")
        != foundation_artifact.expected_pcm_sha256
    ):
        raise KickFoundationCollisionReportError(
            f"{location} PCM identities do not match the stem manifest"
        )
    for key in (
        "stateFingerprint", "planFingerprint", "replayFingerprint",
        "candidateEvaluationFingerprint",
    ):
        token = value.get(key)
        if (
            not isinstance(token, str)
            or len(token) != 16
            or any(character not in "0123456789abcdef" for character in token)
        ):
            raise KickFoundationCollisionReportError(
                f"{location}.{key} must be a 16-digit evidence fingerprint"
            )
    sample_rate = nonnegative_integer(value.get("sampleRate"), f"{location}.sampleRate")
    frame_count = nonnegative_integer(value.get("frameCount"), f"{location}.frameCount")
    bar_count = nonnegative_integer(value.get("barCount"), f"{location}.barCount")
    if sample_rate not in SUPPORTED_SAMPLE_RATES or bar_count <= 0:
        raise KickFoundationCollisionReportError(
            f"{location} sample rate/bar count is unsupported"
        )
    bar_frames = nearest_frame(sample_rate * 240.0 / 130.0)
    if frame_count != bar_count * bar_frames:
        raise KickFoundationCollisionReportError(
            f"{location}.frameCount is not an exact fixed-130-BPM phrase"
        )
    bars_without = value.get("barsWithoutKick")
    if (
        not isinstance(bars_without, list)
        or bars_without != sorted(set(bars_without))
        or any(not isinstance(item, int) for item in bars_without)
    ):
        raise KickFoundationCollisionReportError(
            f"{location}.barsWithoutKick is invalid"
        )
    kick = load_mono_samples(kick_artifact)
    foundation = load_mono_samples(foundation_artifact)
    if len(kick) != frame_count or len(foundation) != frame_count:
        raise KickFoundationCollisionReportError(
            f"{location} PCM length does not match entry"
        )
    validate_evidence(
        value.get("evidence"), value, kick, foundation, f"{location}.evidence"
    )


def validate(
    report: Mapping[str, Any], root: Path, require_fingerprint: bool
) -> None:
    exact_keys(report, REPORT_KEYS if require_fingerprint else PAYLOAD_KEYS, "report")
    if report.get("schema") != REPORT_SCHEMA or report.get("reportVersion") != 1:
        raise KickFoundationCollisionReportError("report schema/version is invalid")
    if report.get("analyzerVersion") != ANALYZER_VERSION:
        raise KickFoundationCollisionReportError("analyzerVersion is invalid")
    corpus_path = root / "docs/BASELINE_CORPUS.json"
    if report.get("corpusSha256") != pcm.sha256(corpus_path):
        raise KickFoundationCollisionReportError(
            "corpusSha256 does not match current corpus"
        )
    baseline = pcm.load_json(
        root / "docs/ROADMAP_EXECUTION_BASELINE.json", "contract baseline"
    )
    if report.get("contractBaselineFingerprint") != baseline.get(
        "snapshotFingerprint"
    ):
        raise KickFoundationCollisionReportError(
            "contractBaselineFingerprint does not match current baseline"
        )
    validate_policies(report.get("policies"))
    whole_manifest, stem_manifest, artifacts = load_inputs(report, root)
    whole_entries = manifest_entries(whole_manifest, "whole-mix")
    stem_entries = manifest_entries(stem_manifest, "role-stems")
    if set(whole_entries) != set(stem_entries):
        raise KickFoundationCollisionReportError(
            "whole and stem manifest entry identities differ"
        )
    entries = report.get("entries")
    if not isinstance(entries, list):
        raise KickFoundationCollisionReportError("entries must be an array")
    identifiers = [item.get("id") for item in entries if isinstance(item, dict)]
    if identifiers != sorted(whole_entries):
        raise KickFoundationCollisionReportError(
            "entries must exactly cover both manifests in sorted order"
        )
    for index, entry in enumerate(entries):
        identifier = str(entry["id"])
        validate_entry(
            entry,
            whole_entries[identifier],
            stem_entries[identifier],
            artifacts,
            f"entries[{index}]",
        )
    if require_fingerprint:
        fingerprint = report.get("reportFingerprint")
        if not pcm.is_sha256(fingerprint):
            raise KickFoundationCollisionReportError(
                "reportFingerprint must be SHA-256"
            )
        payload = dict(report)
        del payload["reportFingerprint"]
        expected = hashlib.sha256(pcm.canonical_bytes(payload)).hexdigest()
        if fingerprint != expected:
            raise KickFoundationCollisionReportError(
                "reportFingerprint is stale or mutated"
            )


def generate(
    payload_path: Path,
    output_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        payload = dict(pcm.load_json(payload_path, "collision payload"))
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
        KickFoundationCollisionReportError,
    ) as exc:
        print(f"collision report generation rejected: {exc}", file=output)
        return 1
    event_count = sum(len(entry["evidence"]["events"]) for entry in payload["entries"])
    print(
        f"generated kick/foundation collision report: {len(payload['entries'])} "
        f"entries, {event_count} events, fingerprint {payload['reportFingerprint']}",
        file=output,
    )
    return 0


def check(
    report_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        report = pcm.load_json(report_path, "collision report")
        validate(report, root, require_fingerprint=True)
    except (
        OSError, ValueError, pcm.PCMComparisonError,
        KickFoundationCollisionReportError,
    ) as exc:
        print(f"collision report rejected: {exc}", file=output)
        return 1
    event_count = sum(len(entry["evidence"]["events"]) for entry in report["entries"])
    print(
        f"kick/foundation collision report is current: {len(report['entries'])} "
        f"entries, {event_count} score-bound events",
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
