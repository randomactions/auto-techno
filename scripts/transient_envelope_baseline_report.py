#!/usr/bin/env python3
"""Finalize and independently verify local transient/envelope baselines."""

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


REPORT_SCHEMA = "autotechno-transient-envelope-baseline-report.v1"
ANALYZER_VERSION = "autotechno-pcm-transient-envelope-analyzer.v1"
EVIDENCE_SCHEMA = "autotechno-pcm-transient-envelope.v1"
PAYLOAD_KEYS = {
    "schema", "reportVersion", "analyzerVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "policies", "inputs", "assets",
}
REPORT_KEYS = PAYLOAD_KEYS | {"reportFingerprint"}
POLICY_KEYS = {
    "bpm", "beatsPerBar", "segmentDurationSeconds", "segmentFrameRounding",
    "monoFold", "legacyDetectionThreshold", "legacyRefractorySeconds",
    "legacyReferenceSampleRate", "legacyReferenceEnvelopeCoefficient",
    "onsetAuthority", "activityRelativeToSourcePeak", "activityAbsoluteFloor",
    "envelopeAttack", "envelopeReleaseSeconds", "onsetMergeSeconds",
    "peakSearchSeconds", "eventWindowSeconds", "eventWindowBoundary",
    "attackLowerFraction", "attackUpperFraction", "attackShapeMetric",
    "decayActivityFraction", "decayLandmarkFraction",
    "decayOccupancyDenominator", "crestUnit", "segmentEventAttribution",
    "noEventPolicy", "interpretation",
}
INPUT_KEYS = signal.INPUT_KEYS
ASSET_KEYS = signal.ASSET_KEYS
EVIDENCE_KEYS = {
    "schema", "sampleRate", "sourceChannelCount", "frameCount",
    "segmentFrameCount", "activityGateAmplitude", "summary", "events",
    "segments",
}
SUMMARY_KEYS = {
    "frameCount", "durationSeconds", "legacyTransientCount",
    "legacyTransientDensityPerSecond", "shapeEventCount",
    "shapeEventDensityPerSecond", "crestFactor", "attackRiseSecondsMean",
    "attackMeanNormalizedEnvelopeMean", "decayOccupancyMean",
    "eventCrestFactorMean", "finite",
}
EVENT_KEYS = {
    "index", "onsetFrame", "onsetSource", "analysisEndFrame",
    "analysisEndSource", "peakFrame", "peakAmplitude", "attack10Frame",
    "attack90Frame", "attackRiseFrameCount", "attackRiseSeconds",
    "attackMeanNormalizedEnvelope", "decayFrameCount",
    "decayActiveFrameCount", "decayOccupancy", "decay10Frame", "rms",
    "crestFactor", "finite",
}
SEGMENT_KEYS = {"startFrame", "frameCount", "summary"}

LEGACY_THRESHOLD = 0.055
REFRACTORY_SECONDS = 0.035
REFERENCE_SAMPLE_RATE = 48_000.0
REFERENCE_ENVELOPE_COEFFICIENT = 0.08
ACTIVITY_RELATIVE_TO_PEAK = 0.04
ACTIVITY_ABSOLUTE_FLOOR = 0.000_01
RELEASE_SECONDS = 0.010
PEAK_SEARCH_SECONDS = 0.090
EVENT_WINDOW_SECONDS = 240.0 / 130.0 / 8.0
ATTACK_LOWER_FRACTION = 0.10
ATTACK_UPPER_FRACTION = 0.90
DECAY_ACTIVITY_FRACTION = 0.04
DECAY_LANDMARK_FRACTION = 0.10

DEFAULT_PAYLOAD = Path(
    "docs/local/reports/transient-envelope-baseline-v1/payload.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/transient-envelope-baseline-v1/manifest.json"
)


class TransientEnvelopeBaselineReportError(RuntimeError):
    """An actionable schema, provenance, or independent-analysis failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def rounded_frames(value: float) -> int:
    return int(math.floor(value + 0.5))


def close(actual: float, expected: float, tolerance: float = 1e-9) -> bool:
    return abs(actual - expected) <= tolerance * max(1.0, abs(expected))


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> None:
    try:
        signal.exact_keys(value, expected, location)
    except signal.SignalBaselineReportError as exc:
        raise TransientEnvelopeBaselineReportError(str(exc)) from exc


def fold_to_mono(channels: Sequence[Sequence[float]]) -> list[float]:
    divisor = float(len(channels))
    return [sum(channel[frame] / divisor for channel in channels)
            for frame in range(len(channels[0]))]


def legacy_frames(mono: Sequence[float], sample_rate: int) -> list[int]:
    refractory = max(1, int(sample_rate * REFRACTORY_SECONDS))
    coefficient = 1.0 - math.pow(
        1.0 - REFERENCE_ENVELOPE_COEFFICIENT,
        REFERENCE_SAMPLE_RATE / sample_rate,
    )
    previous_envelope = 0.0
    last_transient = -refractory
    result: list[int] = []
    for frame, sample in enumerate(mono):
        magnitude = abs(sample)
        if (magnitude - previous_envelope > LEGACY_THRESHOLD
                and frame - last_transient >= refractory):
            result.append(frame)
            last_transient = frame
        previous_envelope += (
            magnitude - previous_envelope
        ) * coefficient
    return result


def activity_envelope(mono: Sequence[float], sample_rate: int) -> list[float]:
    release = 1.0 - math.exp(-1.0 / (sample_rate * RELEASE_SECONDS))
    state = 0.0
    result: list[float] = []
    for sample in mono:
        magnitude = abs(sample)
        if magnitude >= state:
            state = magnitude
        else:
            state += (magnitude - state) * release
        result.append(state)
    return result


def onset_candidates(
    envelope: Sequence[float],
    activity_gate: float,
    detected_frames: Sequence[int],
    sample_rate: int,
) -> list[tuple[int, bool, bool]]:
    if activity_gate <= 0.0:
        return []
    legacy = set(detected_frames)
    raw: list[tuple[int, bool, bool]] = []
    active = False
    for frame, value in enumerate(envelope):
        now_active = value >= activity_gate
        rise = now_active and not active
        flux = frame in legacy
        if rise or flux:
            raw.append((frame, rise, flux))
        active = now_active
    merge_frames = max(1, rounded_frames(sample_rate * REFRACTORY_SECONDS))
    merged: list[tuple[int, bool, bool]] = []
    for candidate in raw:
        if merged and candidate[0] - merged[-1][0] < merge_frames:
            previous = merged[-1]
            merged[-1] = (
                previous[0], previous[1] or candidate[1],
                previous[2] or candidate[2],
            )
        else:
            merged.append(candidate)
    return merged


def crest(samples: Sequence[float]) -> float:
    peak = max((abs(value) for value in samples), default=0.0)
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    return peak / rms if rms > 0.0 else 0.0


def make_events(
    candidates: Sequence[tuple[int, bool, bool]],
    mono: Sequence[float],
    envelope: Sequence[float],
    sample_rate: int,
) -> list[dict[str, Any]]:
    fixed_window = max(1, rounded_frames(sample_rate * EVENT_WINDOW_SECONDS))
    peak_search = max(1, rounded_frames(sample_rate * PEAK_SEARCH_SECONDS))
    events: list[dict[str, Any]] = []
    for index, (onset, activity_rise, legacy_flux) in enumerate(candidates):
        fixed_end = min(len(mono), onset + fixed_window)
        next_onset = candidates[index + 1][0] if index + 1 < len(candidates) else None
        if next_onset is not None and next_onset < fixed_end:
            end, end_source = next_onset, "next-event"
        elif fixed_end < len(mono):
            end, end_source = fixed_end, "fixed-window"
        else:
            end, end_source = len(mono), "source-end"
        if onset >= end:
            raise TransientEnvelopeBaselineReportError(
                "independent analyzer produced an empty event"
            )
        search_end = min(end, onset + peak_search)
        peak_frame = max(
            range(onset, search_end), key=lambda frame: envelope[frame]
        )
        peak = envelope[peak_frame]
        lower, upper = peak * ATTACK_LOWER_FRACTION, peak * ATTACK_UPPER_FRACTION
        attack10 = next(
            (frame for frame in range(onset, peak_frame + 1)
             if envelope[frame] >= lower),
            onset,
        )
        attack90 = next(
            (frame for frame in range(attack10, peak_frame + 1)
             if envelope[frame] >= upper),
            peak_frame,
        )
        attack_values = envelope[attack10:attack90 + 1]
        attack_mean = sum(attack_values) / (len(attack_values) * peak)
        decay_gate = max(ACTIVITY_ABSOLUTE_FLOOR, peak * DECAY_ACTIVITY_FRACTION)
        decay_values = envelope[peak_frame:end]
        decay_active = sum(value >= decay_gate for value in decay_values)
        decay10 = next(
            (frame for frame in range(peak_frame, end)
             if envelope[frame] <= peak * DECAY_LANDMARK_FRACTION),
            None,
        )
        event_samples = mono[onset:end]
        event_rms = math.sqrt(
            sum(value * value for value in event_samples) / len(event_samples)
        )
        event_peak = max(abs(value) for value in event_samples)
        event_crest = event_peak / event_rms if event_rms > 0.0 else 0.0
        if activity_rise and legacy_flux:
            onset_source = "pcm-activity-rise-and-legacy-flux"
        elif activity_rise:
            onset_source = "pcm-activity-rise"
        elif legacy_flux:
            onset_source = "legacy-flux"
        else:
            raise TransientEnvelopeBaselineReportError(
                "independent analyzer produced an unowned onset"
            )
        events.append({
            "index": index,
            "onsetFrame": onset,
            "onsetSource": onset_source,
            "analysisEndFrame": end,
            "analysisEndSource": end_source,
            "peakFrame": peak_frame,
            "peakAmplitude": peak,
            "attack10Frame": attack10,
            "attack90Frame": attack90,
            "attackRiseFrameCount": attack90 - attack10,
            "attackRiseSeconds": (attack90 - attack10) / sample_rate,
            "attackMeanNormalizedEnvelope": attack_mean,
            "decayFrameCount": len(decay_values),
            "decayActiveFrameCount": decay_active,
            "decayOccupancy": decay_active / len(decay_values),
            "decay10Frame": decay10,
            "rms": event_rms,
            "crestFactor": event_crest,
            "finite": True,
        })
    return events


def summarize(
    samples: Sequence[float],
    legacy_count: int,
    events: Sequence[Mapping[str, Any]],
    sample_rate: int,
) -> dict[str, Any]:
    duration = len(samples) / sample_rate
    count = len(events)
    divisor = float(count) if count else 1.0
    return {
        "frameCount": len(samples),
        "durationSeconds": duration,
        "legacyTransientCount": legacy_count,
        "legacyTransientDensityPerSecond": legacy_count / duration,
        "shapeEventCount": count,
        "shapeEventDensityPerSecond": count / duration,
        "crestFactor": crest(samples),
        "attackRiseSecondsMean": (
            sum(float(event["attackRiseSeconds"]) for event in events) / divisor
            if events else None
        ),
        "attackMeanNormalizedEnvelopeMean": (
            sum(float(event["attackMeanNormalizedEnvelope"])
                for event in events) / divisor if events else None
        ),
        "decayOccupancyMean": (
            sum(float(event["decayOccupancy"]) for event in events) / divisor
            if events else None
        ),
        "eventCrestFactorMean": (
            sum(float(event["crestFactor"]) for event in events) / divisor
            if events else None
        ),
        "finite": True,
    }


def analyze_pcm(
    channels: Sequence[Sequence[float]],
    sample_rate: int,
    segment_frame_count: int,
) -> dict[str, Any]:
    mono = fold_to_mono(channels)
    source_peak = max((abs(value) for value in mono), default=0.0)
    gate = min(
        source_peak,
        max(ACTIVITY_ABSOLUTE_FLOOR,
            source_peak * ACTIVITY_RELATIVE_TO_PEAK),
    )
    envelope = activity_envelope(mono, sample_rate)
    detected = legacy_frames(mono, sample_rate)
    candidates = onset_candidates(envelope, gate, detected, sample_rate)
    events = make_events(candidates, mono, envelope, sample_rate)
    segments: list[dict[str, Any]] = []
    start = 0
    while start < len(mono):
        end = min(len(mono), start + segment_frame_count)
        segment_events = [event for event in events
                          if start <= int(event["onsetFrame"]) < end]
        segment_legacy = sum(start <= frame < end for frame in detected)
        segments.append({
            "startFrame": start,
            "frameCount": end - start,
            "summary": summarize(
                mono[start:end], segment_legacy, segment_events, sample_rate
            ),
        })
        start = end
    return {
        "schema": EVIDENCE_SCHEMA,
        "sampleRate": sample_rate,
        "sourceChannelCount": len(channels),
        "frameCount": len(mono),
        "segmentFrameCount": segment_frame_count,
        "activityGateAmplitude": gate,
        "summary": summarize(mono, len(detected), events, sample_rate),
        "events": events,
        "segments": segments,
    }


def read_channels(path: Path) -> tuple[int, list[array[float]]]:
    try:
        with path.open("rb") as handle:
            sample_rate, channel_count, frame_count, data_size, _ = (
                pcm.read_wav_header(handle, path)
            )
            values = pcm.float_array(handle.read(data_size))
    except (OSError, pcm.PCMComparisonError) as exc:
        raise TransientEnvelopeBaselineReportError(
            f"cannot read exact PCM from {path}: {exc}"
        ) from exc
    if len(values) != frame_count * channel_count:
        raise TransientEnvelopeBaselineReportError(
            f"{path} PCM length changed while reading"
        )
    channels = [array("f") for _ in range(channel_count)]
    for channel in range(channel_count):
        channels[channel].extend(values[channel::channel_count])
    return sample_rate, channels


def compare_recomputed(actual: object, expected: object, location: str) -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            raise TransientEnvelopeBaselineReportError(
                f"{location} must be an object"
            )
        exact_keys(actual, set(expected), location)
        for key in expected:
            compare_recomputed(actual[key], expected[key], f"{location}.{key}")
    elif isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise TransientEnvelopeBaselineReportError(
                f"{location} has wrong cardinality"
            )
        for index, (actual_item, expected_item) in enumerate(zip(actual, expected)):
            compare_recomputed(
                actual_item, expected_item, f"{location}[{index}]"
            )
    elif isinstance(expected, float):
        if (isinstance(actual, bool)
                or not isinstance(actual, (int, float))
                or not math.isfinite(float(actual))
                or not close(float(actual), expected, 2e-8)):
            raise TransientEnvelopeBaselineReportError(
                f"{location} does not independently recompute"
            )
    elif actual != expected:
        raise TransientEnvelopeBaselineReportError(
            f"{location} does not independently recompute"
        )


def validate_evidence(
    value: object,
    channels: Sequence[Sequence[float]],
    sample_rate: int,
    segment_frames: int,
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise TransientEnvelopeBaselineReportError(f"{location} must be an object")
    exact_keys(value, EVIDENCE_KEYS, location)
    summary = value.get("summary")
    events = value.get("events")
    segments = value.get("segments")
    if isinstance(summary, dict):
        exact_keys(summary, SUMMARY_KEYS, f"{location}.summary")
    if isinstance(events, list):
        for index, event in enumerate(events):
            if isinstance(event, dict):
                exact_keys(event, EVENT_KEYS, f"{location}.events[{index}]")
    if isinstance(segments, list):
        for index, segment in enumerate(segments):
            if isinstance(segment, dict):
                exact_keys(segment, SEGMENT_KEYS, f"{location}.segments[{index}]")
                if isinstance(segment.get("summary"), dict):
                    exact_keys(
                        segment["summary"], SUMMARY_KEYS,
                        f"{location}.segments[{index}].summary",
                    )
    expected = analyze_pcm(channels, sample_rate, segment_frames)
    compare_recomputed(value, expected, location)


def validate_asset(
    value: object,
    expected: Mapping[str, Any],
    root: Path,
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise TransientEnvelopeBaselineReportError(f"{location} must be an object")
    exact_keys(value, ASSET_KEYS, location)
    for key in (
        "assetId", "domain", "entryId", "signal", "classification",
        "pcmSha256", "wavPath",
    ):
        if value.get(key) != expected.get(key):
            raise TransientEnvelopeBaselineReportError(
                f"{location}.{key} does not match its manifest"
            )
    path = pcm.resolve_local_path(root, value.get("wavPath"), f"{location}.wavPath")
    sample_rate, channels = read_channels(path)
    if sample_rate != expected.get("sampleRate"):
        raise TransientEnvelopeBaselineReportError(
            f"{location} sample rate does not match its manifest"
        )
    segment_frames = rounded_frames(sample_rate * 240.0 / 130.0)
    validate_evidence(
        value.get("evidence"), channels, sample_rate, segment_frames,
        f"{location}.evidence",
    )


def expected_policy() -> dict[str, object]:
    return {
        "bpm": 130.0,
        "beatsPerBar": 4,
        "segmentDurationSeconds": 240.0 / 130.0,
        "segmentFrameRounding": "nearest-frame",
        "monoFold": "arithmetic-mean-of-source-channels",
        "legacyDetectionThreshold": LEGACY_THRESHOLD,
        "legacyRefractorySeconds": REFRACTORY_SECONDS,
        "legacyReferenceSampleRate": REFERENCE_SAMPLE_RATE,
        "legacyReferenceEnvelopeCoefficient": REFERENCE_ENVELOPE_COEFFICIENT,
        "onsetAuthority": "pcm-inferred-activity-rise-or-legacy-flux-not-score-bound",
        "activityRelativeToSourcePeak": ACTIVITY_RELATIVE_TO_PEAK,
        "activityAbsoluteFloor": ACTIVITY_ABSOLUTE_FLOOR,
        "envelopeAttack": "instantaneous-rectified-peak",
        "envelopeReleaseSeconds": RELEASE_SECONDS,
        "onsetMergeSeconds": REFRACTORY_SECONDS,
        "peakSearchSeconds": PEAK_SEARCH_SECONDS,
        "eventWindowSeconds": EVENT_WINDOW_SECONDS,
        "eventWindowBoundary": "earliest-of-next-onset-fixed-window-source-end",
        "attackLowerFraction": ATTACK_LOWER_FRACTION,
        "attackUpperFraction": ATTACK_UPPER_FRACTION,
        "attackShapeMetric": (
            "mean-peak-normalized-envelope-between-landmarks-inclusive"
        ),
        "decayActivityFraction": DECAY_ACTIVITY_FRACTION,
        "decayLandmarkFraction": DECAY_LANDMARK_FRACTION,
        "decayOccupancyDenominator": "peak-through-analysis-end-frame-count",
        "crestUnit": "linear-peak-over-rms-arithmetic-fold",
        "segmentEventAttribution": "onset-frame-in-segment",
        "noEventPolicy": "valid-zero-count-null-shape-aggregates",
        "interpretation": "descriptive-not-ranked-not-calibrated",
    }


def validate(report: Mapping[str, Any], root: Path, require_fingerprint: bool) -> None:
    exact_keys(report, REPORT_KEYS if require_fingerprint else PAYLOAD_KEYS, "report")
    if report.get("schema") != REPORT_SCHEMA or report.get("reportVersion") != 1:
        raise TransientEnvelopeBaselineReportError("report schema/version is invalid")
    if report.get("analyzerVersion") != ANALYZER_VERSION:
        raise TransientEnvelopeBaselineReportError("analyzerVersion is invalid")
    if report.get("corpusSha256") != pcm.sha256(root / "docs/BASELINE_CORPUS.json"):
        raise TransientEnvelopeBaselineReportError("corpusSha256 is stale")
    baseline = pcm.load_json(
        root / "docs/ROADMAP_EXECUTION_BASELINE.json", "contract baseline"
    )
    if report.get("contractBaselineFingerprint") != baseline.get(
        "snapshotFingerprint"
    ):
        raise TransientEnvelopeBaselineReportError(
            "contractBaselineFingerprint is stale"
        )
    policies = report.get("policies")
    if not isinstance(policies, dict):
        raise TransientEnvelopeBaselineReportError("policies must be an object")
    exact_keys(policies, POLICY_KEYS, "policies")
    compare_recomputed(policies, expected_policy(), "policies")

    inputs = report.get("inputs")
    if (not isinstance(inputs, list)
            or [item.get("domain") for item in inputs if isinstance(item, dict)]
            != ["whole-mix", "role-stems"]):
        raise TransientEnvelopeBaselineReportError(
            "inputs must contain whole-mix then role-stems"
        )
    cache: dict[Path, pcm.ScannedWav] = {}
    expected_assets: dict[str, dict[str, Any]] = {}
    common_provenance: Optional[tuple[object, object, object]] = None
    for index, input_record in enumerate(inputs):
        if not isinstance(input_record, dict):
            raise TransientEnvelopeBaselineReportError(
                f"inputs[{index}] must be an object"
            )
        exact_keys(input_record, INPUT_KEYS, f"inputs[{index}]")
        domain = str(input_record["domain"])
        manifest_path = pcm.resolve_local_path(
            root, input_record.get("manifestPath"),
            f"inputs[{index}].manifestPath",
        )
        manifest = pcm.load_json(manifest_path, f"{domain} manifest")
        if input_record.get("manifestSha256") != pcm.sha256(manifest_path):
            raise TransientEnvelopeBaselineReportError(
                f"inputs[{index}] manifest hash is stale"
            )
        manifest_domain, artifacts = pcm.extract_artifacts(manifest, root, domain)
        if (manifest_domain != domain
                or input_record.get("manifestSchema") != manifest.get("schema")):
            raise TransientEnvelopeBaselineReportError(
                f"inputs[{index}] domain/schema mismatch"
            )
        scans = {
            identifier: pcm.scan_artifact(artifact, cache)
            for identifier, artifact in sorted(artifacts.items())
        }
        if (input_record.get("assetCount") != len(artifacts)
                or input_record.get("pcmSetFingerprint")
                != signal.pcm_set_fingerprint(artifacts, scans)):
            raise TransientEnvelopeBaselineReportError(
                f"inputs[{index}] asset set is stale"
            )
        expected_assets.update(signal.expected_assets(manifest, domain))
        provenance = (
            manifest.get("sourceFingerprint"), manifest.get("gitHead"),
            manifest.get("engineVersion"),
        )
        if common_provenance is None:
            common_provenance = provenance
        elif provenance != common_provenance:
            raise TransientEnvelopeBaselineReportError(
                "input provenance does not agree"
            )
    if common_provenance is None:
        raise TransientEnvelopeBaselineReportError("input provenance is missing")
    if (
        report.get("sourceFingerprint"), report.get("gitHead"),
        report.get("engineVersion"),
    ) != common_provenance:
        raise TransientEnvelopeBaselineReportError(
            "report provenance does not match its inputs"
        )
    assets = report.get("assets")
    if not isinstance(assets, list):
        raise TransientEnvelopeBaselineReportError("assets must be an array")
    identifiers = [
        item.get("assetId") for item in assets if isinstance(item, dict)
    ]
    if identifiers != sorted(expected_assets):
        raise TransientEnvelopeBaselineReportError(
            "assets must exactly cover both manifests in sorted identity order"
        )
    for index, asset in enumerate(assets):
        identifier = str(asset["assetId"])
        expected_asset = dict(expected_assets[identifier])
        expected_asset["assetId"] = identifier
        validate_asset(
            asset, expected_asset, root,
            f"assets[{index}]",
        )
    if require_fingerprint:
        fingerprint = report.get("reportFingerprint")
        if not pcm.is_sha256(fingerprint):
            raise TransientEnvelopeBaselineReportError(
                "reportFingerprint must be SHA-256"
            )
        payload = dict(report)
        del payload["reportFingerprint"]
        expected_fingerprint = hashlib.sha256(
            pcm.canonical_bytes(payload)
        ).hexdigest()
        if fingerprint != expected_fingerprint:
            raise TransientEnvelopeBaselineReportError(
                "reportFingerprint is stale or mutated"
            )


def generate(
    payload_path: Path,
    output_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        payload = dict(pcm.load_json(payload_path, "transient envelope payload"))
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
        TransientEnvelopeBaselineReportError,
    ) as exc:
        print(f"transient envelope generation rejected: {exc}", file=output)
        return 1
    event_count = sum(
        int(asset["evidence"]["summary"]["shapeEventCount"])
        for asset in payload["assets"]
    )
    print(
        f"generated transient envelope baseline: {len(payload['assets'])} assets, "
        f"{event_count} PCM-inferred events, fingerprint "
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
        report = pcm.load_json(report_path, "transient envelope baseline")
        validate(report, root, require_fingerprint=True)
    except (
        OSError, ValueError, pcm.PCMComparisonError,
        signal.SignalBaselineReportError,
        TransientEnvelopeBaselineReportError,
    ) as exc:
        print(f"transient envelope baseline rejected: {exc}", file=output)
        return 1
    print(
        f"transient envelope baseline is current: {len(report['assets'])} "
        "whole/role assets independently recomputed",
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
