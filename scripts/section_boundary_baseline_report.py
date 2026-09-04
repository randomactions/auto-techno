#!/usr/bin/env python3
"""Independently reconstruct and verify local section-boundary evidence."""

from __future__ import annotations

from array import array
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import subprocess
import sys
from typing import Any, Mapping, Optional, Sequence


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import pcm_comparison_report as pcm  # noqa: E402
import rhythmic_baseline_report as rhythmic  # noqa: E402


EXPORT_SCHEMA = "autotechno-section-boundary-baseline-manifest.v1"
ARTIFACT_SCHEMA = "autotechno-section-boundary-baseline-artifact.v1"
EVIDENCE_SCHEMA = "autotechno-pcm-section-boundary-baseline.v1"
ANALYZER_VERSION = "autotechno-pcm-section-boundary-baseline-analyzer.v1"
REPORT_SCHEMA = "autotechno-section-boundary-baseline-report.v1"
REPORT_VERSION = 1
REFERENCE_BAR_COUNT = 2
POST_HORIZON_BAR_COUNT = 8
TRANSITION_CELL_COUNT = 16
MAXIMUM_PHRASE_COUNT = 3
MAXIMUM_BAR_COUNT = 48
CUTOFFS = (35.0, 120.0, 420.0, 2_400.0, 10_000.0)
METRIC_ORDER = (
    "combined-rms-dbfs",
    "crest-factor",
    "sub-band-share",
    "low-mid-band-share",
    "mid-band-share",
    "high-band-share",
    "full-band-side-energy-share",
    "onset-count",
    "rest-occupancy",
)
METRIC_UNITS = (
    "dBFS", "ratio", "share", "share", "share", "share", "share",
    "count", "share",
)
MARKER_ORDER = (
    "session-start",
    "phrase-start",
    "phrase-kind-change",
    "interlock-chapter-change",
)
RECOVERY_STATUSES = (
    "sustained-observed",
    "not-observed-within-horizon",
    "unavailable-missing-reference",
    "unavailable-missing-post",
    "unavailable-missing-metric",
)
EXPORT_KEYS = {
    "schema", "manifestVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "analyzerVersion", "wholeManifestSha256", "entries",
}
ENTRY_KEYS = {
    "id", "caseId", "routeId", "rootSeed", "checkpoint",
    "continuationClass", "sampleRate", "channelCount", "focusPhraseIndex",
    "contextPhraseIndices", "contextStartBar", "contextBarCount",
    "barFrameCount", "frameCount", "targetContextStartFrame",
    "targetFrameCount", "targetPCMSha256", "contextPCMSha256", "wavPath",
    "wavSha256", "evidencePath", "evidenceSha256", "boundaryCount",
}
ARTIFACT_KEYS = {
    "schema", "id", "caseId", "routeId", "rootSeed", "checkpoint",
    "continuationClass", "wholeManifestEntryId",
    "wholeManifestEntryPCMSha256", "targetContextStartFrame",
    "targetFrameCount", "phrases", "evidence",
}
PHRASE_KEYS = {
    "position", "phraseIndex", "startBar", "barCount", "phraseKind",
    "stateFingerprint", "planFingerprint", "replayFingerprint",
}
INPUT_KEYS = {
    "sampleRate", "sourceChannelCount", "barFrameCount",
    "focusPhraseIndex", "bars",
}
BAR_KEYS = {
    "timelineIndex", "startFrame", "frameCount", "score", "metrics",
    "transitionCells",
}
SCORE_KEYS = {
    "phraseIndex", "phraseKind", "absoluteBar", "barIndexInPhrase",
    "interlockChapter",
}
METRICS_KEYS = {
    "combinedRMSDBFS", "crestFactor", "bandShares", "sideEnergyShare",
    "onsetCount", "restOccupancy",
}
CELL_KEYS = {
    "index", "startFrame", "frameCount", "sourceRMSDBFS", "bandShares",
    "onsetCount",
}
EVIDENCE_KEYS = {
    "schema", "analyzerVersion", "referenceBarCount",
    "postHorizonBarCount", "transitionCellCount", "metricOrder", "input",
    "boundaries",
}
BOUNDARY_KEYS = {
    "index", "timelineBarIndex", "sampleFrame", "markers", "previousScore",
    "currentScore", "referenceBarIndices", "postBarIndices",
    "referenceComplete", "postHorizonComplete", "transitionCells", "metrics",
    "jointRecoveryStatus",
}
RECOVERY_KEYS = {
    "name", "unit", "referenceMinimum", "referenceMaximum", "referenceMean",
    "transitionValue", "signedTransitionDelta", "absoluteTransitionDelta",
    "postTrajectory", "firstTowardReference", "firstReferenceEnvelopeEntry",
    "firstSustainedReferenceEnvelopeResidence", "status",
}
TIMING_KEYS = {"barOffset", "frameOffset", "seconds"}
DEFAULT_EXPORT = Path(
    "docs/local/reports/section-boundary-baseline-v1/manifest.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/section-boundary-baseline-v1/report.json"
)


class SectionBoundaryBaselineReportError(RuntimeError):
    """An actionable schema, provenance, or reconstruction failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
        allow_nan=False,
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise SectionBoundaryBaselineReportError(
            f"cannot hash {path}: {exc}"
        ) from exc
    return digest.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SectionBoundaryBaselineReportError(
            f"cannot read {label} at {path}: {exc}"
        ) from exc
    if not isinstance(value, dict):
        raise SectionBoundaryBaselineReportError(f"{label} must be an object")
    return value


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> None:
    missing = sorted(expected - set(value))
    unknown = sorted(set(value) - expected)
    if missing or unknown:
        detail = []
        if missing:
            detail.append("missing " + ", ".join(missing))
        if unknown:
            detail.append("unknown " + ", ".join(unknown))
        raise SectionBoundaryBaselineReportError(
            f"{location} has invalid fields: {'; '.join(detail)}"
        )


def integer(value: object, location: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise SectionBoundaryBaselineReportError(
            f"{location} must be an integer >= {minimum}"
        )
    return value


def number(value: object, location: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SectionBoundaryBaselineReportError(f"{location} must be numeric")
    result = float(value)
    if not math.isfinite(result):
        raise SectionBoundaryBaselineReportError(f"{location} must be finite")
    return result


def text(value: object, location: str) -> str:
    if not isinstance(value, str) or not value:
        raise SectionBoundaryBaselineReportError(
            f"{location} must be a nonempty string"
        )
    return value


def safe_path(root: Path, value: object, prefix: str, location: str) -> Path:
    raw = text(value, location)
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts:
        raise SectionBoundaryBaselineReportError(
            f"{location} must be a safe repository-relative path"
        )
    if not raw.startswith(prefix):
        raise SectionBoundaryBaselineReportError(
            f"{location} must remain under {prefix}"
        )
    return root / path


def close(actual: float, expected: float, tolerance: float = 3e-8) -> bool:
    return abs(actual - expected) <= tolerance * max(1.0, abs(expected))


def compare(actual: object, expected: object, location: str = "value") -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            raise SectionBoundaryBaselineReportError(f"{location} must be an object")
        exact_keys(actual, set(expected), location)
        for key, expected_value in expected.items():
            compare(actual[key], expected_value, f"{location}.{key}")
    elif isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise SectionBoundaryBaselineReportError(
                f"{location} has wrong cardinality"
            )
        for index, (actual_item, expected_item) in enumerate(zip(actual, expected)):
            compare(actual_item, expected_item, f"{location}[{index}]")
    elif isinstance(expected, float):
        if (
            isinstance(actual, bool)
            or not isinstance(actual, (int, float))
            or not math.isfinite(float(actual))
            or not close(float(actual), expected)
        ):
            raise SectionBoundaryBaselineReportError(
                f"{location} does not independently reconstruct"
            )
    elif actual != expected:
        raise SectionBoundaryBaselineReportError(
            f"{location} does not independently reconstruct"
        )


def decibels(amplitude: float) -> float:
    return -120.0 if amplitude <= 0 else max(-120.0, 20 * math.log10(amplitude))


def read_wav(path: Path) -> tuple[int, int, int, bytes, list[array[float]]]:
    try:
        with path.open("rb") as handle:
            sample_rate, channel_count, frame_count, data_size, _ = (
                pcm.read_wav_header(handle, path)
            )
            payload = handle.read(data_size)
            values = pcm.float_array(payload)
    except (OSError, pcm.PCMComparisonError) as exc:
        raise SectionBoundaryBaselineReportError(
            f"cannot read exact context PCM from {path}: {exc}"
        ) from exc
    if len(values) != frame_count * channel_count:
        raise SectionBoundaryBaselineReportError(
            f"{path} PCM length changed while reading"
        )
    channels = [array("f") for _ in range(channel_count)]
    for channel in range(channel_count):
        channels[channel].extend(values[channel::channel_count])
    if any(not math.isfinite(float(sample)) for channel in channels for sample in channel):
        raise SectionBoundaryBaselineReportError(f"{path} contains non-finite PCM")
    return sample_rate, channel_count, frame_count, payload, channels


def band_and_cell_evidence(
    mono: Sequence[float], sample_rate: int, global_start: int
) -> tuple[list[float], list[dict[str, Any]]]:
    coefficients = [
        1.0 - math.exp(
            -2.0 * math.pi * min(cutoff, sample_rate * 0.45) / sample_rate
        )
        for cutoff in CUTOFFS
    ]
    states = [0.0] * len(CUTOFFS)
    counts = [0] * TRANSITION_CELL_COUNT
    source_sums = [0.0] * TRANSITION_CELL_COUNT
    band_sums = [[0.0] * 4 for _ in range(TRANSITION_CELL_COUNT)]
    for frame, sample_value in enumerate(mono):
        value = float(sample_value)
        for index, coefficient in enumerate(coefficients):
            states[index] += (value - states[index]) * coefficient
        bands = (
            states[1] - states[0],
            states[2] - states[1],
            states[3] - states[2],
            states[4] - states[3],
        )
        cell = min(
            TRANSITION_CELL_COUNT - 1,
            frame * TRANSITION_CELL_COUNT // len(mono),
        )
        counts[cell] += 1
        source_sums[cell] += value * value
        for band, band_value in enumerate(bands):
            band_sums[cell][band] += band_value * band_value
    cells: list[dict[str, Any]] = []
    total_band_sums = [0.0] * 4
    start = global_start
    for index in range(TRANSITION_CELL_COUNT):
        divisor = max(1, counts[index])
        means = [value / divisor for value in band_sums[index]]
        for band in range(4):
            total_band_sums[band] += band_sums[index][band]
        total = sum(means)
        shares = [value / total for value in means] if total > 0 else [0.0] * 4
        source_mean = source_sums[index] / divisor
        cells.append({
            "index": index,
            "startFrame": start,
            "frameCount": counts[index],
            "sourceRMSDBFS": decibels(math.sqrt(source_mean)),
            "bandShares": shares,
            "onsetCount": 0,
        })
        start += counts[index]
    total = sum(total_band_sums)
    shares = (
        [value / total for value in total_band_sums]
        if total > 0 else [0.0] * 4
    )
    return shares, cells


def reconstruct_input(
    channels: Sequence[Sequence[float]],
    sample_rate: int,
    score_bars: Sequence[Mapping[str, Any]],
    focus_phrase_index: int,
) -> dict[str, Any]:
    bar_frames = int(math.floor(sample_rate * 240.0 / 130.0 + 0.5))
    frame_count = len(channels[0])
    if (
        len(channels) not in (1, 2)
        or frame_count != len(score_bars) * bar_frames
        or not score_bars
        or len(score_bars) > MAXIMUM_BAR_COUNT
    ):
        raise SectionBoundaryBaselineReportError(
            "context PCM and score do not form bounded complete bars"
        )
    rhythm = rhythmic.analyze_pcm(channels, sample_rate)
    if len(rhythm["bars"]) != len(score_bars):
        raise SectionBoundaryBaselineReportError(
            "independent rhythmic analysis has wrong bar count"
        )
    right_channel = channels[1] if len(channels) == 2 else channels[0]
    bars: list[dict[str, Any]] = []
    for index, score in enumerate(score_bars):
        start = index * bar_frames
        end = start + bar_frames
        left = channels[0][start:end]
        right = right_channel[start:end]
        peak = 0.0
        square_sum = 0.0
        mid_sum = 0.0
        side_sum = 0.0
        mono = array("f")
        for left_value, right_value in zip(left, right):
            left_float = float(left_value)
            right_float = float(right_value)
            peak = max(peak, abs(left_float), abs(right_float))
            square_sum += left_float * left_float + right_float * right_float
            mid = (left_float + right_float) * 0.5
            side = (left_float - right_float) * 0.5
            mid_sum += mid * mid
            side_sum += side * side
            mono.append(mid)
        rms = math.sqrt(square_sum / (2 * bar_frames))
        band_shares, cells = band_and_cell_evidence(mono, sample_rate, start)
        rhythm_bar = rhythm["bars"][index]
        for cell, onset_count in zip(cells, rhythm_bar["gridOnsetCounts"]):
            cell["onsetCount"] = onset_count
        width_total = mid_sum + side_sum
        bars.append({
            "timelineIndex": index,
            "startFrame": start,
            "frameCount": bar_frames,
            "score": dict(score),
            "metrics": {
                "combinedRMSDBFS": decibels(rms),
                "crestFactor": peak / rms if rms > 0 else 0.0,
                "bandShares": band_shares,
                "sideEnergyShare": side_sum / width_total if width_total > 0 else None,
                "onsetCount": rhythm_bar["onsetCount"],
                "restOccupancy": rhythm_bar["restOccupancy"],
            },
            "transitionCells": cells,
        })
    result = {
        "sampleRate": sample_rate,
        "sourceChannelCount": len(channels),
        "barFrameCount": bar_frames,
        "focusPhraseIndex": focus_phrase_index,
        "bars": bars,
    }
    validate_input(result)
    return result


def validate_score(score: object, location: str) -> Mapping[str, Any]:
    if not isinstance(score, dict):
        raise SectionBoundaryBaselineReportError(f"{location} must be an object")
    exact_keys(score, SCORE_KEYS, location)
    integer(score.get("phraseIndex"), f"{location}.phraseIndex")
    text(score.get("phraseKind"), f"{location}.phraseKind")
    integer(score.get("absoluteBar"), f"{location}.absoluteBar")
    integer(score.get("barIndexInPhrase"), f"{location}.barIndexInPhrase")
    text(score.get("interlockChapter"), f"{location}.interlockChapter")
    return score


def validate_input(value: object) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise SectionBoundaryBaselineReportError("evidence.input must be an object")
    exact_keys(value, INPUT_KEYS, "evidence.input")
    sample_rate = integer(value.get("sampleRate"), "evidence.input.sampleRate", 1)
    channels = integer(
        value.get("sourceChannelCount"), "evidence.input.sourceChannelCount", 1
    )
    if channels not in (1, 2):
        raise SectionBoundaryBaselineReportError(
            "evidence.input.sourceChannelCount must be mono or stereo"
        )
    bar_frames = integer(
        value.get("barFrameCount"), "evidence.input.barFrameCount", 1
    )
    expected_bar_frames = int(math.floor(sample_rate * 240 / 130 + 0.5))
    if bar_frames != expected_bar_frames:
        raise SectionBoundaryBaselineReportError(
            "evidence.input.barFrameCount is not fixed-130-BPM geometry"
        )
    focus = integer(value.get("focusPhraseIndex"), "evidence.input.focusPhraseIndex")
    bars = value.get("bars")
    if not isinstance(bars, list) or not 1 <= len(bars) <= MAXIMUM_BAR_COUNT:
        raise SectionBoundaryBaselineReportError(
            "evidence.input.bars must be a bounded nonempty array"
        )
    phrases: set[int] = set()
    for index, bar in enumerate(bars):
        location = f"evidence.input.bars[{index}]"
        if not isinstance(bar, dict):
            raise SectionBoundaryBaselineReportError(f"{location} must be an object")
        exact_keys(bar, BAR_KEYS, location)
        if (
            bar.get("timelineIndex") != index
            or bar.get("startFrame") != index * bar_frames
            or bar.get("frameCount") != bar_frames
        ):
            raise SectionBoundaryBaselineReportError(
                f"{location} has invalid timeline geometry"
            )
        score = validate_score(bar.get("score"), f"{location}.score")
        phrases.add(int(score["phraseIndex"]))
        metrics = bar.get("metrics")
        if not isinstance(metrics, dict):
            raise SectionBoundaryBaselineReportError(
                f"{location}.metrics must be an object"
            )
        exact_keys(metrics, METRICS_KEYS, f"{location}.metrics")
        number(metrics.get("combinedRMSDBFS"), f"{location}.metrics.combinedRMSDBFS")
        if number(metrics.get("crestFactor"), f"{location}.metrics.crestFactor") < 0:
            raise SectionBoundaryBaselineReportError(f"{location}.crestFactor is negative")
        shares = metrics.get("bandShares")
        if not isinstance(shares, list) or len(shares) != 4 or any(
            not 0 <= number(item, f"{location}.bandShares") <= 1 for item in shares
        ):
            raise SectionBoundaryBaselineReportError(f"{location}.bandShares is invalid")
        side = metrics.get("sideEnergyShare")
        if side is not None and not 0 <= number(side, f"{location}.sideEnergyShare") <= 1:
            raise SectionBoundaryBaselineReportError(f"{location}.sideEnergyShare is invalid")
        integer(metrics.get("onsetCount"), f"{location}.onsetCount")
        if not 0 <= number(metrics.get("restOccupancy"), f"{location}.restOccupancy") <= 1:
            raise SectionBoundaryBaselineReportError(f"{location}.restOccupancy is invalid")
        cells = bar.get("transitionCells")
        if not isinstance(cells, list) or len(cells) != TRANSITION_CELL_COUNT:
            raise SectionBoundaryBaselineReportError(
                f"{location}.transitionCells must contain sixteen cells"
            )
        cell_end = index * bar_frames
        for cell_index, cell in enumerate(cells):
            cell_location = f"{location}.transitionCells[{cell_index}]"
            if not isinstance(cell, dict):
                raise SectionBoundaryBaselineReportError(
                    f"{cell_location} must be an object"
                )
            exact_keys(cell, CELL_KEYS, cell_location)
            if cell.get("index") != cell_index or cell.get("startFrame") != cell_end:
                raise SectionBoundaryBaselineReportError(
                    f"{cell_location} has invalid index/start"
                )
            cell_end += integer(cell.get("frameCount"), f"{cell_location}.frameCount", 1)
            number(cell.get("sourceRMSDBFS"), f"{cell_location}.sourceRMSDBFS")
            cell_shares = cell.get("bandShares")
            if not isinstance(cell_shares, list) or len(cell_shares) != 4:
                raise SectionBoundaryBaselineReportError(
                    f"{cell_location}.bandShares is invalid"
                )
            for item in cell_shares:
                if not 0 <= number(item, f"{cell_location}.bandShares") <= 1:
                    raise SectionBoundaryBaselineReportError(
                        f"{cell_location}.bandShares is invalid"
                    )
            integer(cell.get("onsetCount"), f"{cell_location}.onsetCount")
        if cell_end != (index + 1) * bar_frames:
            raise SectionBoundaryBaselineReportError(
                f"{location}.transitionCells do not partition the bar"
            )
        if index:
            previous = bars[index - 1]["score"]
            if score["absoluteBar"] != previous["absoluteBar"] + 1:
                raise SectionBoundaryBaselineReportError(
                    f"{location}.score absolute bar is discontinuous"
                )
            if score["phraseIndex"] == previous["phraseIndex"]:
                if (
                    score["barIndexInPhrase"] != previous["barIndexInPhrase"] + 1
                    or score["phraseKind"] != previous["phraseKind"]
                ):
                    raise SectionBoundaryBaselineReportError(
                        f"{location}.score phrase continuation is invalid"
                    )
            elif (
                score["phraseIndex"] != previous["phraseIndex"] + 1
                or score["barIndexInPhrase"] != 0
            ):
                raise SectionBoundaryBaselineReportError(
                    f"{location}.score phrase boundary is discontinuous"
                )
    ordered_phrases = sorted(phrases)
    if (
        len(ordered_phrases) > MAXIMUM_PHRASE_COUNT
        or ordered_phrases != list(range(ordered_phrases[0], ordered_phrases[-1] + 1))
        or focus not in phrases
    ):
        raise SectionBoundaryBaselineReportError(
            "evidence.input phrase context is invalid"
        )
    return value


def metric_value(metrics: Mapping[str, Any], index: int) -> Optional[float]:
    if index == 0:
        return float(metrics["combinedRMSDBFS"])
    if index == 1:
        return float(metrics["crestFactor"])
    if 2 <= index <= 5:
        return float(metrics["bandShares"][index - 2])
    if index == 6:
        value = metrics["sideEnergyShare"]
        return None if value is None else float(value)
    if index == 7:
        return float(metrics["onsetCount"])
    if index == 8:
        return float(metrics["restOccupancy"])
    raise AssertionError("metric index is out of range")


def timing(offset: int, value: Mapping[str, Any]) -> dict[str, Any]:
    frames = offset * int(value["barFrameCount"])
    return {
        "barOffset": offset,
        "frameOffset": frames,
        "seconds": frames / int(value["sampleRate"]),
    }


def rebuild_metric(
    metric_index: int,
    value: Mapping[str, Any],
    reference_indices: Sequence[int],
    post_indices: Sequence[int],
    reference_complete: bool,
    post_complete: bool,
) -> dict[str, Any]:
    bars = value["bars"]
    references = [metric_value(bars[index]["metrics"], metric_index)
                  for index in reference_indices]
    post = [metric_value(bars[index]["metrics"], metric_index)
            for index in post_indices]
    status = "not-observed-within-horizon"
    minimum = maximum = reference_mean = transition = None
    signed_delta = absolute_delta = None
    toward = entry = sustained = None
    if not reference_complete:
        status = "unavailable-missing-reference"
    elif not post_complete:
        status = "unavailable-missing-post"
    elif any(item is None for item in references + post):
        status = "unavailable-missing-metric"
    else:
        reference_values = [float(item) for item in references if item is not None]
        post_values = [float(item) for item in post if item is not None]
        minimum = min(reference_values)
        maximum = max(reference_values)
        reference_mean = sum(reference_values) / len(reference_values)
        transition = post_values[0]
        signed_delta = transition - reference_mean
        absolute_delta = abs(signed_delta)
        previous_distance = abs(reference_values[-1] - reference_mean)
        for offset, post_value in enumerate(post_values):
            distance = abs(post_value - reference_mean)
            if toward is None and distance < previous_distance:
                toward = timing(offset, value)
            previous_distance = distance
            if entry is None and minimum <= post_value <= maximum:
                entry = timing(offset, value)
            if (
                offset + 1 < len(post_values)
                and minimum <= post_value <= maximum
                and minimum <= post_values[offset + 1] <= maximum
            ):
                sustained = timing(offset, value)
                status = "sustained-observed"
                break
    if reference_complete and all(item is not None for item in references):
        available = [float(item) for item in references if item is not None]
        minimum = min(available)
        maximum = max(available)
        reference_mean = sum(available) / len(available)
    transition = post[0] if post else None
    if reference_mean is not None and transition is not None:
        signed_delta = float(transition) - reference_mean
        absolute_delta = abs(signed_delta)
    return {
        "name": METRIC_ORDER[metric_index],
        "unit": METRIC_UNITS[metric_index],
        "referenceMinimum": minimum,
        "referenceMaximum": maximum,
        "referenceMean": reference_mean,
        "transitionValue": transition,
        "signedTransitionDelta": signed_delta,
        "absoluteTransitionDelta": absolute_delta,
        "postTrajectory": post,
        "firstTowardReference": toward,
        "firstReferenceEnvelopeEntry": entry,
        "firstSustainedReferenceEnvelopeResidence": sustained,
        "status": status,
    }


def joint_status(metrics: Sequence[Mapping[str, Any]]) -> str:
    statuses = [item["status"] for item in metrics]
    if all(status == "sustained-observed" for status in statuses):
        return "sustained-observed"
    for unavailable in (
        "unavailable-missing-reference",
        "unavailable-missing-post",
        "unavailable-missing-metric",
    ):
        if unavailable in statuses:
            return unavailable
    return "not-observed-within-horizon"


def rebuild_boundaries(value: Mapping[str, Any]) -> list[dict[str, Any]]:
    validate_input(value)
    bars = value["bars"]
    focus = int(value["focusPhraseIndex"])
    boundaries: list[dict[str, Any]] = []
    for index, current in enumerate(bars):
        previous = bars[index - 1] if index else None
        markers: list[str] = []
        if current["score"]["absoluteBar"] == 0:
            markers.append("session-start")
        if current["score"]["barIndexInPhrase"] == 0:
            markers.append("phrase-start")
        if previous and previous["score"]["phraseKind"] != current["score"]["phraseKind"]:
            markers.append("phrase-kind-change")
        if previous and previous["score"]["interlockChapter"] != current["score"]["interlockChapter"]:
            markers.append("interlock-chapter-change")
        if not markers:
            continue
        if (
            current["score"]["phraseIndex"] != focus
            and (not previous or previous["score"]["phraseIndex"] != focus)
        ):
            continue
        reference_indices = list(range(max(0, index - REFERENCE_BAR_COUNT), index))
        post_indices = list(range(index, min(len(bars), index + POST_HORIZON_BAR_COUNT)))
        reference_complete = len(reference_indices) == REFERENCE_BAR_COUNT
        post_complete = len(post_indices) == POST_HORIZON_BAR_COUNT
        metrics = [
            rebuild_metric(
                metric_index,
                value,
                reference_indices,
                post_indices,
                reference_complete,
                post_complete,
            )
            for metric_index in range(len(METRIC_ORDER))
        ]
        boundaries.append({
            "index": len(boundaries),
            "timelineBarIndex": index,
            "sampleFrame": current["startFrame"],
            "markers": markers,
            "previousScore": previous["score"] if previous else None,
            "currentScore": current["score"],
            "referenceBarIndices": reference_indices,
            "postBarIndices": post_indices,
            "referenceComplete": reference_complete,
            "postHorizonComplete": post_complete,
            "transitionCells": current["transitionCells"],
            "metrics": metrics,
            "jointRecoveryStatus": joint_status(metrics),
        })
    return boundaries


def validate_phrases(
    phrases: object,
    score_bars: Sequence[Mapping[str, Any]],
    focus: int,
    whole: Mapping[str, Any],
    location: str,
) -> list[Mapping[str, Any]]:
    if not isinstance(phrases, list) or not 2 <= len(phrases) <= MAXIMUM_PHRASE_COUNT:
        raise SectionBoundaryBaselineReportError(
            f"{location} must contain two or three phrases"
        )
    result: list[Mapping[str, Any]] = []
    cursor = 0
    for index, phrase in enumerate(phrases):
        phrase_location = f"{location}[{index}]"
        if not isinstance(phrase, dict):
            raise SectionBoundaryBaselineReportError(
                f"{phrase_location} must be an object"
            )
        exact_keys(phrase, PHRASE_KEYS, phrase_location)
        phrase_index = integer(phrase.get("phraseIndex"), f"{phrase_location}.phraseIndex")
        start_bar = integer(phrase.get("startBar"), f"{phrase_location}.startBar")
        bar_count = integer(phrase.get("barCount"), f"{phrase_location}.barCount", 1)
        phrase_kind = text(phrase.get("phraseKind"), f"{phrase_location}.phraseKind")
        expected_position = (
            "lead-in" if phrase_index < focus
            else "focus" if phrase_index == focus
            else "follow-through"
        )
        if phrase.get("position") != expected_position:
            raise SectionBoundaryBaselineReportError(
                f"{phrase_location}.position is inconsistent"
            )
        for key in ("stateFingerprint", "planFingerprint", "replayFingerprint"):
            fingerprint = text(phrase.get(key), f"{phrase_location}.{key}")
            if len(fingerprint) != 16:
                raise SectionBoundaryBaselineReportError(
                    f"{phrase_location}.{key} must be a 16-hex digest"
                )
        selected = score_bars[cursor:cursor + bar_count]
        if len(selected) != bar_count or any(
            bar["phraseIndex"] != phrase_index
            or bar["phraseKind"] != phrase_kind
            or bar["absoluteBar"] != start_bar + offset
            or bar["barIndexInPhrase"] != offset
            for offset, bar in enumerate(selected)
        ):
            raise SectionBoundaryBaselineReportError(
                f"{phrase_location} does not bind its score bars"
            )
        cursor += bar_count
        result.append(phrase)
    if cursor != len(score_bars):
        raise SectionBoundaryBaselineReportError(
            f"{location} does not cover every score bar"
        )
    focus_phrases = [phrase for phrase in result if phrase["phraseIndex"] == focus]
    if len(focus_phrases) != 1:
        raise SectionBoundaryBaselineReportError(
            f"{location} must contain one focus phrase"
        )
    target = focus_phrases[0]
    for phrase_key, whole_key in (
        ("phraseIndex", "phraseIndex"),
        ("startBar", "startBar"),
        ("phraseKind", "phraseKind"),
        ("stateFingerprint", "stateFingerprint"),
        ("planFingerprint", "planFingerprint"),
        ("replayFingerprint", "replayFingerprint"),
    ):
        if target[phrase_key] != whole[whole_key]:
            raise SectionBoundaryBaselineReportError(
                f"{location} focus {phrase_key} differs from whole manifest"
            )
    return result


def source_fingerprint(root: Path) -> str:
    paths = ["Package.swift", "docs/BASELINE_CORPUS.json",
             "docs/ROADMAP_EXECUTION_BASELINE.json"]
    paths.extend(
        path.relative_to(root).as_posix()
        for path in (root / "Sources").rglob("*")
        if path.is_file()
    )
    digest = hashlib.sha256()
    for relative in sorted(paths):
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update((root / relative).read_bytes())
    return digest.hexdigest()


def git_head(root: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        raise SectionBoundaryBaselineReportError(
            "cannot resolve current Git HEAD: " + result.stderr.strip()
        )
    return result.stdout.strip()


def validate_export(
    export: Mapping[str, Any], root: Path
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    exact_keys(export, EXPORT_KEYS, "export")
    if export.get("schema") != EXPORT_SCHEMA or export.get("manifestVersion") != 1:
        raise SectionBoundaryBaselineReportError("export schema/version is invalid")
    if export.get("analyzerVersion") != ANALYZER_VERSION:
        raise SectionBoundaryBaselineReportError("export analyzer version is invalid")
    corpus_path = root / "docs/BASELINE_CORPUS.json"
    snapshot_path = root / "docs/ROADMAP_EXECUTION_BASELINE.json"
    whole_path = root / "docs/local/reports/baseline-corpus-v1/manifest.json"
    corpus = load_json(corpus_path, "baseline corpus")
    snapshot = load_json(snapshot_path, "contract snapshot")
    whole_manifest = load_json(whole_path, "whole-mix manifest")
    if export.get("corpusSha256") != sha256_path(corpus_path):
        raise SectionBoundaryBaselineReportError("export corpus hash is stale")
    if export.get("contractBaselineFingerprint") != snapshot.get("snapshotFingerprint"):
        raise SectionBoundaryBaselineReportError("export contract fingerprint is stale")
    if export.get("wholeManifestSha256") != sha256_path(whole_path):
        raise SectionBoundaryBaselineReportError("export whole manifest hash is stale")
    if export.get("sourceFingerprint") != source_fingerprint(root):
        raise SectionBoundaryBaselineReportError("export source fingerprint is stale")
    if export.get("gitHead") != git_head(root):
        raise SectionBoundaryBaselineReportError("export Git HEAD is stale")
    if export.get("engineVersion") != whole_manifest.get("engineVersion"):
        raise SectionBoundaryBaselineReportError("export engine version is inconsistent")
    cases = corpus.get("cases")
    routes = corpus.get("routes")
    if not isinstance(cases, list) or not isinstance(routes, list):
        raise SectionBoundaryBaselineReportError("baseline corpus cases/routes are invalid")
    expected = {
        f"{case['id']}--{route['id']}": (case, route)
        for case in cases for route in routes
    }
    whole_entries = whole_manifest.get("entries")
    if not isinstance(whole_entries, list):
        raise SectionBoundaryBaselineReportError("whole manifest entries are invalid")
    whole_by_id = {entry["id"]: entry for entry in whole_entries}
    entries = export.get("entries")
    if not isinstance(entries, list) or [entry.get("id") for entry in entries] != sorted(expected):
        raise SectionBoundaryBaselineReportError(
            "export entries do not exactly cover sorted corpus/route identities"
        )
    summaries: list[dict[str, Any]] = []
    aggregate = {
        "entryCount": 0,
        "contextPhraseCount": 0,
        "contextBarCount": 0,
        "contextFrameCount": 0,
        "boundaryCount": 0,
        "markerCounts": {marker: 0 for marker in MARKER_ORDER},
        "metricRecoveryStatusCounts": {status: 0 for status in RECOVERY_STATUSES},
        "jointRecoveryStatusCounts": {status: 0 for status in RECOVERY_STATUSES},
    }
    for entry_index, entry in enumerate(entries):
        location = f"export.entries[{entry_index}]"
        if not isinstance(entry, dict):
            raise SectionBoundaryBaselineReportError(f"{location} must be an object")
        exact_keys(entry, ENTRY_KEYS, location)
        identifier = text(entry.get("id"), f"{location}.id")
        case, route = expected[identifier]
        whole = whole_by_id.get(identifier)
        if not isinstance(whole, dict):
            raise SectionBoundaryBaselineReportError(
                f"{location} has no whole-manifest entry"
            )
        fixed_pairs = (
            ("caseId", case["id"]), ("routeId", route["id"]),
            ("rootSeed", case["rootSeed"]), ("checkpoint", case["checkpoint"]),
            ("continuationClass", case["continuationClass"]),
            ("sampleRate", route["sampleRate"]),
            ("channelCount", route["channelCount"]),
            ("targetPCMSha256", whole["pcmSha256"]),
            ("targetFrameCount", whole["frameCount"]),
        )
        for key, expected_value in fixed_pairs:
            if entry.get(key) != expected_value:
                raise SectionBoundaryBaselineReportError(
                    f"{location}.{key} is inconsistent"
                )
        wav_path = safe_path(
            root, entry.get("wavPath"),
            "docs/local/audio/section-boundary-baseline-v1/",
            f"{location}.wavPath",
        )
        evidence_path = safe_path(
            root, entry.get("evidencePath"),
            "docs/local/reports/section-boundary-baseline-v1/",
            f"{location}.evidencePath",
        )
        if sha256_path(wav_path) != entry.get("wavSha256"):
            raise SectionBoundaryBaselineReportError(f"{location} WAV hash is stale")
        if sha256_path(evidence_path) != entry.get("evidenceSha256"):
            raise SectionBoundaryBaselineReportError(f"{location} evidence hash is stale")
        sample_rate, channel_count, frame_count, payload, channels = read_wav(wav_path)
        if (
            sample_rate != entry.get("sampleRate")
            or channel_count != entry.get("channelCount")
            or frame_count != entry.get("frameCount")
            or sha256_bytes(payload) != entry.get("contextPCMSha256")
        ):
            raise SectionBoundaryBaselineReportError(
                f"{location} context PCM geometry/hash is inconsistent"
            )
        target_start = integer(
            entry.get("targetContextStartFrame"),
            f"{location}.targetContextStartFrame",
        )
        target_frames = integer(
            entry.get("targetFrameCount"), f"{location}.targetFrameCount", 1
        )
        byte_start = target_start * channel_count * 4
        byte_end = (target_start + target_frames) * channel_count * 4
        if byte_end > len(payload) or sha256_bytes(payload[byte_start:byte_end]) != entry.get("targetPCMSha256"):
            raise SectionBoundaryBaselineReportError(
                f"{location} target PCM slice differs from whole manifest"
            )
        artifact = load_json(evidence_path, f"{location} artifact")
        exact_keys(artifact, ARTIFACT_KEYS, f"{location}.artifact")
        if artifact.get("schema") != ARTIFACT_SCHEMA:
            raise SectionBoundaryBaselineReportError(f"{location} artifact schema is invalid")
        for key in (
            "id", "caseId", "routeId", "rootSeed", "checkpoint",
            "continuationClass", "targetContextStartFrame", "targetFrameCount",
        ):
            if artifact.get(key) != entry.get(key):
                raise SectionBoundaryBaselineReportError(
                    f"{location} artifact {key} is inconsistent"
                )
        if (
            artifact.get("wholeManifestEntryId") != identifier
            or artifact.get("wholeManifestEntryPCMSha256") != whole["pcmSha256"]
        ):
            raise SectionBoundaryBaselineReportError(
                f"{location} artifact whole-manifest binding is invalid"
            )
        evidence = artifact.get("evidence")
        if not isinstance(evidence, dict):
            raise SectionBoundaryBaselineReportError(f"{location}.evidence is invalid")
        exact_keys(evidence, EVIDENCE_KEYS, f"{location}.evidence")
        if (
            evidence.get("schema") != EVIDENCE_SCHEMA
            or evidence.get("analyzerVersion") != ANALYZER_VERSION
            or evidence.get("referenceBarCount") != REFERENCE_BAR_COUNT
            or evidence.get("postHorizonBarCount") != POST_HORIZON_BAR_COUNT
            or evidence.get("transitionCellCount") != TRANSITION_CELL_COUNT
            or evidence.get("metricOrder") != list(METRIC_ORDER)
        ):
            raise SectionBoundaryBaselineReportError(
                f"{location} evidence fixed policy is invalid"
            )
        swift_input = validate_input(evidence.get("input"))
        score_bars = [bar["score"] for bar in swift_input["bars"]]
        phrases = validate_phrases(
            artifact.get("phrases"), score_bars,
            int(entry["focusPhraseIndex"]), whole,
            f"{location}.artifact.phrases",
        )
        phrase_indices = [phrase["phraseIndex"] for phrase in phrases]
        if (
            entry.get("contextPhraseIndices") != phrase_indices
            or entry.get("contextStartBar") != phrases[0]["startBar"]
            or entry.get("contextBarCount") != len(score_bars)
            or entry.get("barFrameCount") != swift_input["barFrameCount"]
            or entry.get("focusPhraseIndex") != swift_input["focusPhraseIndex"]
        ):
            raise SectionBoundaryBaselineReportError(
                f"{location} context metadata is inconsistent"
            )
        reconstructed_input = reconstruct_input(
            channels, sample_rate, score_bars, int(entry["focusPhraseIndex"])
        )
        compare(swift_input, reconstructed_input, f"{location}.evidence.input")
        reconstructed_boundaries = rebuild_boundaries(reconstructed_input)
        compare(
            evidence.get("boundaries"), reconstructed_boundaries,
            f"{location}.evidence.boundaries",
        )
        if entry.get("boundaryCount") != len(reconstructed_boundaries):
            raise SectionBoundaryBaselineReportError(
                f"{location}.boundaryCount is inconsistent"
            )
        marker_counts = {marker: 0 for marker in MARKER_ORDER}
        joint_counts = {status: 0 for status in RECOVERY_STATUSES}
        metric_counts = {status: 0 for status in RECOVERY_STATUSES}
        for boundary in reconstructed_boundaries:
            for marker in boundary["markers"]:
                marker_counts[marker] += 1
                aggregate["markerCounts"][marker] += 1
            joint_counts[boundary["jointRecoveryStatus"]] += 1
            aggregate["jointRecoveryStatusCounts"][boundary["jointRecoveryStatus"]] += 1
            for metric in boundary["metrics"]:
                metric_counts[metric["status"]] += 1
                aggregate["metricRecoveryStatusCounts"][metric["status"]] += 1
        summary = {
            "id": identifier,
            "sampleRate": sample_rate,
            "focusPhraseIndex": entry["focusPhraseIndex"],
            "contextPhraseCount": len(phrases),
            "contextBarCount": len(score_bars),
            "contextFrameCount": frame_count,
            "boundaryCount": len(reconstructed_boundaries),
            "markerCounts": marker_counts,
            "metricRecoveryStatusCounts": metric_counts,
            "jointRecoveryStatusCounts": joint_counts,
            "contextPCMSha256": entry["contextPCMSha256"],
            "targetPCMSha256": entry["targetPCMSha256"],
            "evidenceSha256": entry["evidenceSha256"],
        }
        summaries.append(summary)
        aggregate["entryCount"] += 1
        aggregate["contextPhraseCount"] += len(phrases)
        aggregate["contextBarCount"] += len(score_bars)
        aggregate["contextFrameCount"] += frame_count
        aggregate["boundaryCount"] += len(reconstructed_boundaries)
    return summaries, aggregate


def build_report(
    export: Mapping[str, Any], root: Path, export_path: Path
) -> dict[str, Any]:
    entries, summary = validate_export(export, root)
    payload = {
        "schema": REPORT_SCHEMA,
        "reportVersion": REPORT_VERSION,
        "analyzerVersion": ANALYZER_VERSION,
        "corpusSha256": export["corpusSha256"],
        "contractBaselineFingerprint": export["contractBaselineFingerprint"],
        "sourceFingerprint": export["sourceFingerprint"],
        "gitHead": export["gitHead"],
        "engineVersion": export["engineVersion"],
        "wholeManifestSha256": export["wholeManifestSha256"],
        "exportManifestSha256": sha256_path(export_path),
        "policies": {
            "maximumPhraseCount": MAXIMUM_PHRASE_COUNT,
            "maximumBarCount": MAXIMUM_BAR_COUNT,
            "referenceBarCount": REFERENCE_BAR_COUNT,
            "transitionCellCount": TRANSITION_CELL_COUNT,
            "postHorizonBarCount": POST_HORIZON_BAR_COUNT,
            "metricOrder": list(METRIC_ORDER),
            "markerOrder": list(MARKER_ORDER),
            "recoveryDefinition":
                "two-bar-closed-envelope-two-consecutive-post-bars",
            "interpretation":
                "descriptive-offline-no-transition-quality-or-perceptual-rank",
        },
        "summary": summary,
        "entries": entries,
    }
    return {**payload, "reportFingerprint": sha256_bytes(canonical_bytes(payload))}


def validate_report(report: Mapping[str, Any], expected: Mapping[str, Any]) -> None:
    compare(report, expected, "report")
    payload = dict(report)
    fingerprint = payload.pop("reportFingerprint", None)
    if fingerprint != sha256_bytes(canonical_bytes(payload)):
        raise SectionBoundaryBaselineReportError("report fingerprint is invalid")


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True,
                   allow_nan=False) + "\n",
        encoding="utf-8",
    )


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("mode", choices=("generate", "check"))
    value.add_argument("--root", type=Path, default=repository_root())
    value.add_argument("--export", type=Path, default=DEFAULT_EXPORT)
    value.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    return value


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = parser().parse_args(argv)
    root = arguments.root.resolve()
    export_path = arguments.export
    if not export_path.is_absolute():
        export_path = root / export_path
    report_path = arguments.report
    if not report_path.is_absolute():
        report_path = root / report_path
    try:
        export = load_json(export_path, "section-boundary export manifest")
        expected = build_report(export, root, export_path)
        if arguments.mode == "generate":
            write_json(report_path, expected)
            print(
                "generated section-boundary report: "
                f"{expected['summary']['entryCount']} entries, "
                f"{expected['summary']['boundaryCount']} boundaries"
            )
        else:
            validate_report(
                load_json(report_path, "section-boundary report"), expected
            )
            print(
                "section-boundary report is current: "
                f"{expected['summary']['entryCount']} entries, "
                f"{expected['summary']['boundaryCount']} boundaries"
            )
    except SectionBoundaryBaselineReportError as exc:
        print(f"section-boundary baseline error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
