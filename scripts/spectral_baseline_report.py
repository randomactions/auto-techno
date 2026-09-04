#!/usr/bin/env python3
"""Finalize and verify local whole/role spectral-shape baselines."""

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
import signal_baseline_report as signal  # noqa: E402


REPORT_SCHEMA = "autotechno-spectral-baseline-report.v1"
ANALYZER_VERSION = "autotechno-pcm-spectral-baseline-analyzer.v1"
EVIDENCE_SCHEMA = "autotechno-pcm-spectral-baseline.v1"
PAYLOAD_KEYS = {
    "schema", "reportVersion", "analyzerVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "policies", "inputs", "assets",
}
REPORT_KEYS = PAYLOAD_KEYS | {"reportFingerprint"}
POLICY_KEYS = {
    "bpm", "beatsPerBar", "segmentDurationSeconds", "segmentFrameRounding",
    "monoFold", "windowsPerSegment", "timelineCellPartition",
    "spectrumWindowSeconds", "spectrumWindowFunction",
    "spectrumWindowPlacement", "fftPadding", "bandEnergyModel",
    "bandEnergyUnit", "bandEnergyConservation",
    "activityMeanSquareThreshold", "subBandName", "minimumSubBandShare",
    "lowEndOccupancyDenominator", "shortSegmentPolicy", "decibelFloor",
}
INPUT_KEYS = signal.INPUT_KEYS
ASSET_KEYS = signal.ASSET_KEYS
EVIDENCE_KEYS = {
    "schema", "sampleRate", "sourceChannelCount", "frameCount",
    "segmentFrameCount", "windowsPerSegment", "spectrumFrameCount",
    "fftFrameCount", "bands", "summary", "segments",
}
BAND_KEYS = {"name", "lowerHz", "upperHz"}
SEGMENT_KEYS = {"startFrame", "frameCount", "summary", "windows"}
WINDOW_KEYS = {
    "index", "cellStartFrame", "cellFrameCount", "spectrumStartFrame",
    "spectrumFrameCount", "fftFrameCount", "sourceMeanSquare",
    "sourceRMSDBFS", "sourceActive", "spectrumActive",
    "spectralCentroidHz", "spectralBandwidthHz", "spectralRolloff85Hz",
    "spectralFlatness", "bandMeanSquares", "bandShares", "subBandShare",
    "lowEndOccupied",
}
SUMMARY_KEYS = {
    "frameCount", "windowCount", "activeSpectralWindowCount",
    "sourceActiveWindowCount", "lowEndOccupiedWindowCount",
    "lowEndOccupancy", "sourceMeanSquare", "sourceRMSDBFS",
    "spectralCentroidMeanHz", "spectralCentroidMinimumHz",
    "spectralCentroidMaximumHz", "spectralBandwidthMeanHz",
    "spectralRolloff85MeanHz", "spectralFlatnessMean",
    "subBandShareMean", "bandMeanSquares", "bandShares", "finite",
}
BANDS = (
    ("sub", 35.0, 120.0),
    ("low-mid", 120.0, 420.0),
    ("mid", 420.0, 2_400.0),
    ("high", 2_400.0, 10_000.0),
)
WINDOWS_PER_SEGMENT = 16
ACTIVE_MEAN_SQUARE_THRESHOLD = 1e-10
MINIMUM_SUB_BAND_SHARE = 0.10
DECIBEL_FLOOR = -120.0
DEFAULT_PAYLOAD = Path("docs/local/reports/spectral-baseline-v1/payload.json")
DEFAULT_REPORT = Path("docs/local/reports/spectral-baseline-v1/manifest.json")


class SpectralBaselineReportError(RuntimeError):
    """An actionable spectral schema, provenance, or aggregation failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> None:
    try:
        signal.exact_keys(value, expected, location)
    except signal.SignalBaselineReportError as exc:
        raise SpectralBaselineReportError(str(exc)) from exc


def finite_number(value: object, location: str) -> float:
    try:
        return signal.finite_number(value, location)
    except signal.SignalBaselineReportError as exc:
        raise SpectralBaselineReportError(str(exc)) from exc


def nonnegative_integer(value: object, location: str) -> int:
    try:
        return signal.nonnegative_integer(value, location)
    except signal.SignalBaselineReportError as exc:
        raise SpectralBaselineReportError(str(exc)) from exc


def close(actual: float, expected: float, tolerance: float = 1e-9) -> bool:
    return signal.close(actual, expected, tolerance)


def decibels(amplitude: float) -> float:
    return DECIBEL_FLOOR if amplitude <= 0 else max(
        DECIBEL_FLOOR, 20 * math.log10(amplitude)
    )


def analysis_frame_count(sample_rate: int) -> int:
    target = max(2, int(math.floor(sample_rate / 24.0 + 0.5)))
    return target if target % 2 == 0 else target + 1


def fft_frame_count(sample_rate: int) -> int:
    target = analysis_frame_count(sample_rate)
    selected = 1
    while selected <= target // 2:
        selected *= 2
    if selected < target:
        selected *= 2
    return min(8_192, max(512, selected))


def numeric_vector(
    value: object,
    location: str,
    count: int,
    upper: Optional[float] = None,
) -> list[float]:
    if not isinstance(value, list) or len(value) != count:
        raise SpectralBaselineReportError(
            f"{location} must contain exactly {count} values"
        )
    result = [finite_number(item, f"{location}[{index}]") for index, item in enumerate(value)]
    if any(item < 0 or (upper is not None and item > upper + 1e-9) for item in result):
        raise SpectralBaselineReportError(f"{location} contains an out-of-range value")
    return result


def validate_window(
    value: object,
    location: str,
    sample_rate: int,
    segment_frames: int,
    index: int,
) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise SpectralBaselineReportError(f"{location} must be an object")
    exact_keys(value, WINDOW_KEYS, location)
    if value.get("index") != index:
        raise SpectralBaselineReportError(f"{location}.index is invalid")
    expected_start = (index * segment_frames + WINDOWS_PER_SEGMENT - 1) // WINDOWS_PER_SEGMENT
    expected_end = (
        ((index + 1) * segment_frames + WINDOWS_PER_SEGMENT - 1)
        // WINDOWS_PER_SEGMENT
    )
    expected_count = expected_end - expected_start
    if value.get("cellStartFrame") != expected_start or value.get(
        "cellFrameCount"
    ) != expected_count:
        raise SpectralBaselineReportError(f"{location} causal-cell geometry is invalid")
    spectrum_frames = analysis_frame_count(sample_rate)
    expected_spectrum_start = min(
        max(0, expected_start + expected_count // 2 - spectrum_frames // 2),
        segment_frames - spectrum_frames,
    )
    if (
        value.get("spectrumStartFrame") != expected_spectrum_start
        or value.get("spectrumFrameCount") != spectrum_frames
        or value.get("fftFrameCount") != fft_frame_count(sample_rate)
    ):
        raise SpectralBaselineReportError(f"{location} FFT-window geometry is invalid")
    source_mean_square = finite_number(
        value.get("sourceMeanSquare"), f"{location}.sourceMeanSquare"
    )
    if source_mean_square < 0:
        raise SpectralBaselineReportError(f"{location}.sourceMeanSquare is negative")
    source_rms_db = finite_number(
        value.get("sourceRMSDBFS"), f"{location}.sourceRMSDBFS"
    )
    if not close(source_rms_db, decibels(math.sqrt(source_mean_square)), 1e-10):
        raise SpectralBaselineReportError(f"{location}.sourceRMSDBFS is inconsistent")
    source_active = value.get("sourceActive")
    spectrum_active = value.get("spectrumActive")
    low_end = value.get("lowEndOccupied")
    if not all(isinstance(item, bool) for item in (source_active, spectrum_active, low_end)):
        raise SpectralBaselineReportError(f"{location} activity fields must be Boolean")
    if source_active != (source_mean_square > ACTIVE_MEAN_SQUARE_THRESHOLD):
        raise SpectralBaselineReportError(f"{location}.sourceActive is inconsistent")
    nyquist = sample_rate / 2.0
    centroid = finite_number(value.get("spectralCentroidHz"), f"{location}.spectralCentroidHz")
    bandwidth = finite_number(value.get("spectralBandwidthHz"), f"{location}.spectralBandwidthHz")
    rolloff = finite_number(value.get("spectralRolloff85Hz"), f"{location}.spectralRolloff85Hz")
    flatness = finite_number(value.get("spectralFlatness"), f"{location}.spectralFlatness")
    if not (0 <= centroid <= nyquist and 0 <= bandwidth <= nyquist and 0 <= rolloff <= nyquist):
        raise SpectralBaselineReportError(f"{location} spectral frequencies are out of range")
    if not 0 <= flatness <= 1 + 1e-9:
        raise SpectralBaselineReportError(f"{location}.spectralFlatness is out of range")
    if not spectrum_active and any((centroid, bandwidth, rolloff, flatness)):
        raise SpectralBaselineReportError(f"{location} inactive spectrum must use zero sentinels")
    means = numeric_vector(value.get("bandMeanSquares"), f"{location}.bandMeanSquares", len(BANDS))
    shares = numeric_vector(value.get("bandShares"), f"{location}.bandShares", len(BANDS), 1.0)
    total = sum(means)
    expected_shares = [item / total for item in means] if total > 0 else [0.0] * len(BANDS)
    if any(not close(actual, expected, 1e-10) for actual, expected in zip(shares, expected_shares)):
        raise SpectralBaselineReportError(f"{location}.bandShares are inconsistent")
    sub_share = finite_number(value.get("subBandShare"), f"{location}.subBandShare")
    if not close(sub_share, shares[0], 1e-10):
        raise SpectralBaselineReportError(f"{location}.subBandShare is inconsistent")
    expected_low = bool(source_active) and means[0] > ACTIVE_MEAN_SQUARE_THRESHOLD and sub_share >= MINIMUM_SUB_BAND_SHARE
    if low_end != expected_low:
        raise SpectralBaselineReportError(f"{location}.lowEndOccupied is inconsistent")
    return value


def summary_from_windows(windows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    frame_count = sum(int(window["cellFrameCount"]) for window in windows)
    frame_divisor = max(1, frame_count)
    active_spectrum = [window for window in windows if window["spectrumActive"]]
    active_source = [window for window in windows if window["sourceActive"]]
    band_means = [
        sum(
            float(window["bandMeanSquares"][band]) * int(window["cellFrameCount"])
            for window in windows
        ) / frame_divisor
        for band in range(len(BANDS))
    ]
    band_total = sum(band_means)
    band_shares = [item / band_total for item in band_means] if band_total > 0 else [0.0] * len(BANDS)
    source_mean_square = sum(
        float(window["sourceMeanSquare"]) * int(window["cellFrameCount"])
        for window in windows
    ) / frame_divisor
    centroids = [float(window["spectralCentroidHz"]) for window in active_spectrum]
    spectral_divisor = max(1, len(active_spectrum))
    source_divisor = max(1, len(active_source))
    low_count = sum(bool(window["lowEndOccupied"]) for window in windows)
    return {
        "frameCount": frame_count,
        "windowCount": len(windows),
        "activeSpectralWindowCount": len(active_spectrum),
        "sourceActiveWindowCount": len(active_source),
        "lowEndOccupiedWindowCount": low_count,
        "lowEndOccupancy": low_count / len(active_source) if active_source else 0.0,
        "sourceMeanSquare": source_mean_square,
        "sourceRMSDBFS": decibels(math.sqrt(source_mean_square)),
        "spectralCentroidMeanHz": sum(centroids) / spectral_divisor,
        "spectralCentroidMinimumHz": min(centroids, default=0.0),
        "spectralCentroidMaximumHz": max(centroids, default=0.0),
        "spectralBandwidthMeanHz": sum(float(window["spectralBandwidthHz"]) for window in active_spectrum) / spectral_divisor,
        "spectralRolloff85MeanHz": sum(float(window["spectralRolloff85Hz"]) for window in active_spectrum) / spectral_divisor,
        "spectralFlatnessMean": sum(float(window["spectralFlatness"]) for window in active_spectrum) / spectral_divisor,
        "subBandShareMean": sum(float(window["subBandShare"]) for window in active_source) / source_divisor,
        "bandMeanSquares": band_means,
        "bandShares": band_shares,
        "finite": True,
    }


def validate_summary(
    value: object,
    windows: Sequence[Mapping[str, Any]],
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise SpectralBaselineReportError(f"{location} must be an object")
    exact_keys(value, SUMMARY_KEYS, location)
    expected = summary_from_windows(windows)
    if value.get("finite") is not True:
        raise SpectralBaselineReportError(f"{location}.finite must be true")
    for key in (
        "frameCount", "windowCount", "activeSpectralWindowCount",
        "sourceActiveWindowCount", "lowEndOccupiedWindowCount",
    ):
        nonnegative_integer(value.get(key), f"{location}.{key}")
        if value[key] != expected[key]:
            raise SpectralBaselineReportError(f"{location}.{key} does not aggregate windows")
    for key in (
        "lowEndOccupancy", "sourceMeanSquare", "sourceRMSDBFS",
        "spectralCentroidMeanHz", "spectralCentroidMinimumHz",
        "spectralCentroidMaximumHz", "spectralBandwidthMeanHz",
        "spectralRolloff85MeanHz", "spectralFlatnessMean", "subBandShareMean",
    ):
        actual = finite_number(value.get(key), f"{location}.{key}")
        if not close(actual, float(expected[key]), 1e-9):
            raise SpectralBaselineReportError(f"{location}.{key} does not aggregate windows")
    for key in ("bandMeanSquares", "bandShares"):
        actual = numeric_vector(value.get(key), f"{location}.{key}", len(BANDS))
        if any(not close(item, expected_item, 1e-9) for item, expected_item in zip(actual, expected[key])):
            raise SpectralBaselineReportError(f"{location}.{key} does not aggregate windows")


def validate_asset(value: object, expected: Mapping[str, Any], location: str) -> None:
    if not isinstance(value, dict):
        raise SpectralBaselineReportError(f"{location} must be an object")
    exact_keys(value, ASSET_KEYS, location)
    for key in ("domain", "entryId", "signal", "classification", "pcmSha256", "wavPath"):
        if value.get(key) != expected.get(key):
            raise SpectralBaselineReportError(f"{location}.{key} does not match manifest")
    evidence = value.get("evidence")
    if not isinstance(evidence, dict):
        raise SpectralBaselineReportError(f"{location}.evidence must be an object")
    exact_keys(evidence, EVIDENCE_KEYS, f"{location}.evidence")
    sample_rate = int(expected["sampleRate"])
    frame_count = int(expected["frameCount"])
    channel_count = int(expected["channelCount"])
    segment_frames = int(math.floor(sample_rate * 240.0 / 130.0 + 0.5))
    if (
        evidence.get("schema") != EVIDENCE_SCHEMA
        or evidence.get("sampleRate") != sample_rate
        or evidence.get("sourceChannelCount") != channel_count
        or evidence.get("frameCount") != frame_count
        or evidence.get("segmentFrameCount") != segment_frames
        or evidence.get("windowsPerSegment") != WINDOWS_PER_SEGMENT
        or evidence.get("spectrumFrameCount") != analysis_frame_count(sample_rate)
        or evidence.get("fftFrameCount") != fft_frame_count(sample_rate)
    ):
        raise SpectralBaselineReportError(f"{location}.evidence geometry is invalid")
    bands = evidence.get("bands")
    if not isinstance(bands, list) or len(bands) != len(BANDS):
        raise SpectralBaselineReportError(f"{location}.evidence.bands is invalid")
    for index, (band, expected_band) in enumerate(zip(bands, BANDS)):
        if not isinstance(band, dict):
            raise SpectralBaselineReportError(f"{location}.evidence.bands[{index}] is invalid")
        exact_keys(band, BAND_KEYS, f"{location}.evidence.bands[{index}]")
        if band.get("name") != expected_band[0] or not close(float(band.get("lowerHz", -1)), expected_band[1]) or not close(float(band.get("upperHz", -1)), expected_band[2]):
            raise SpectralBaselineReportError(f"{location}.evidence.bands[{index}] is stale")
    segments = evidence.get("segments")
    expected_segment_count = (frame_count + segment_frames - 1) // segment_frames
    if not isinstance(segments, list) or len(segments) != expected_segment_count:
        raise SpectralBaselineReportError(f"{location}.evidence.segments has wrong coverage")
    all_windows: list[Mapping[str, Any]] = []
    start = 0
    for segment_index, segment in enumerate(segments):
        segment_location = f"{location}.evidence.segments[{segment_index}]"
        if not isinstance(segment, dict):
            raise SpectralBaselineReportError(f"{segment_location} must be an object")
        exact_keys(segment, SEGMENT_KEYS, segment_location)
        count = min(segment_frames, frame_count - start)
        if count < analysis_frame_count(sample_rate):
            raise SpectralBaselineReportError(f"{segment_location} is shorter than one spectrum window")
        if segment.get("startFrame") != start or segment.get("frameCount") != count:
            raise SpectralBaselineReportError(f"{segment_location} is not contiguous")
        windows = segment.get("windows")
        if not isinstance(windows, list) or len(windows) != WINDOWS_PER_SEGMENT:
            raise SpectralBaselineReportError(f"{segment_location}.windows has wrong cardinality")
        checked = [
            validate_window(window, f"{segment_location}.windows[{index}]", sample_rate, count, index)
            for index, window in enumerate(windows)
        ]
        validate_summary(segment.get("summary"), checked, f"{segment_location}.summary")
        all_windows.extend(checked)
        start += count
    validate_summary(evidence.get("summary"), all_windows, f"{location}.evidence.summary")


def validate(report: Mapping[str, Any], root: Path, require_fingerprint: bool) -> None:
    exact_keys(report, REPORT_KEYS if require_fingerprint else PAYLOAD_KEYS, "report")
    if report.get("schema") != REPORT_SCHEMA or report.get("reportVersion") != 1:
        raise SpectralBaselineReportError("report schema/version is invalid")
    if report.get("analyzerVersion") != ANALYZER_VERSION:
        raise SpectralBaselineReportError("analyzerVersion is invalid")
    if report.get("corpusSha256") != pcm.sha256(root / "docs/BASELINE_CORPUS.json"):
        raise SpectralBaselineReportError("corpusSha256 does not match current corpus")
    baseline = pcm.load_json(root / "docs/ROADMAP_EXECUTION_BASELINE.json", "contract baseline")
    if report.get("contractBaselineFingerprint") != baseline.get("snapshotFingerprint"):
        raise SpectralBaselineReportError("contractBaselineFingerprint does not match current baseline")
    policies = report.get("policies")
    if not isinstance(policies, dict):
        raise SpectralBaselineReportError("policies must be an object")
    exact_keys(policies, POLICY_KEYS, "policies")
    expected_policies: dict[str, object] = {
        "bpm": 130, "beatsPerBar": 4,
        "segmentDurationSeconds": 240.0 / 130.0,
        "segmentFrameRounding": "nearest-frame",
        "monoFold": "arithmetic-mean-of-source-channels",
        "windowsPerSegment": WINDOWS_PER_SEGMENT,
        "timelineCellPartition": "contiguous-equal-count-causal-cells",
        "spectrumWindowSeconds": 1.0 / 24.0,
        "spectrumWindowFunction": "symmetric-Hann",
        "spectrumWindowPlacement": "centered-in-causal-cell",
        "fftPadding": "next-power-of-two-zero-padding",
        "bandEnergyModel": "causal-one-pole-difference-non-power-complementary",
        "bandEnergyUnit": "mean-square-amplitude-squared",
        "bandEnergyConservation": "not-claimed",
        "activityMeanSquareThreshold": ACTIVE_MEAN_SQUARE_THRESHOLD,
        "subBandName": "sub", "minimumSubBandShare": MINIMUM_SUB_BAND_SHARE,
        "lowEndOccupancyDenominator": "source-active-window-count",
        "shortSegmentPolicy": "unavailable-below-one-spectrum-window",
        "decibelFloor": DECIBEL_FLOOR,
    }
    for key, expected_value in expected_policies.items():
        actual = policies.get(key)
        if isinstance(expected_value, float):
            if not isinstance(actual, (int, float)) or not close(float(actual), expected_value, 1e-12):
                raise SpectralBaselineReportError(f"policies.{key} is invalid")
        elif actual != expected_value:
            raise SpectralBaselineReportError(f"policies.{key} is invalid")

    inputs = report.get("inputs")
    if not isinstance(inputs, list) or [item.get("domain") for item in inputs if isinstance(item, dict)] != ["whole-mix", "role-stems"]:
        raise SpectralBaselineReportError("inputs must contain whole-mix then role-stems")
    cache: dict[Path, pcm.ScannedWav] = {}
    expected_assets: dict[str, dict[str, Any]] = {}
    common_provenance: Optional[tuple[object, object, object]] = None
    for index, input_record in enumerate(inputs):
        if not isinstance(input_record, dict):
            raise SpectralBaselineReportError(f"inputs[{index}] must be an object")
        exact_keys(input_record, INPUT_KEYS, f"inputs[{index}]")
        domain = str(input_record["domain"])
        manifest_path = pcm.resolve_local_path(root, input_record.get("manifestPath"), f"inputs[{index}].manifestPath")
        manifest = pcm.load_json(manifest_path, f"{domain} manifest")
        if input_record.get("manifestSha256") != pcm.sha256(manifest_path):
            raise SpectralBaselineReportError(f"inputs[{index}] manifest hash is stale")
        manifest_domain, artifacts = pcm.extract_artifacts(manifest, root, domain)
        if manifest_domain != domain or input_record.get("manifestSchema") != manifest.get("schema"):
            raise SpectralBaselineReportError(f"inputs[{index}] domain/schema mismatch")
        scans = {identifier: pcm.scan_artifact(artifact, cache) for identifier, artifact in sorted(artifacts.items())}
        if input_record.get("assetCount") != len(artifacts) or input_record.get("pcmSetFingerprint") != signal.pcm_set_fingerprint(artifacts, scans):
            raise SpectralBaselineReportError(f"inputs[{index}] asset set is stale")
        expected_assets.update(signal.expected_assets(manifest, domain))
        provenance = (manifest.get("sourceFingerprint"), manifest.get("gitHead"), manifest.get("engineVersion"))
        if common_provenance is None:
            common_provenance = provenance
        elif provenance != common_provenance:
            raise SpectralBaselineReportError("input provenance does not agree")
    assert common_provenance is not None
    if (report.get("sourceFingerprint"), report.get("gitHead"), report.get("engineVersion")) != common_provenance:
        raise SpectralBaselineReportError("report provenance does not match inputs")
    assets = report.get("assets")
    if not isinstance(assets, list):
        raise SpectralBaselineReportError("assets must be an array")
    identifiers = [item.get("assetId") for item in assets if isinstance(item, dict)]
    if identifiers != sorted(expected_assets):
        raise SpectralBaselineReportError("assets must exactly cover both manifests in sorted identity order")
    for index, asset in enumerate(assets):
        validate_asset(asset, expected_assets[str(asset["assetId"])], f"assets[{index}]")
    if require_fingerprint:
        fingerprint = report.get("reportFingerprint")
        if not pcm.is_sha256(fingerprint):
            raise SpectralBaselineReportError("reportFingerprint must be SHA-256")
        payload = dict(report)
        del payload["reportFingerprint"]
        expected_fingerprint = hashlib.sha256(pcm.canonical_bytes(payload)).hexdigest()
        if fingerprint != expected_fingerprint:
            raise SpectralBaselineReportError("reportFingerprint is stale or mutated")


def generate(payload_path: Path, output_path: Path, root: Path, output: TextIO = sys.stdout) -> int:
    try:
        payload = dict(pcm.load_json(payload_path, "spectral baseline payload"))
        validate(payload, root, require_fingerprint=False)
        payload["reportFingerprint"] = hashlib.sha256(pcm.canonical_bytes(payload)).hexdigest()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    except (OSError, ValueError, pcm.PCMComparisonError, signal.SignalBaselineReportError, SpectralBaselineReportError) as exc:
        print(f"spectral baseline generation rejected: {exc}", file=output)
        return 1
    print(f"generated spectral baseline: {len(payload['assets'])} assets, fingerprint {payload['reportFingerprint']}", file=output)
    return 0


def check(report_path: Path, root: Path, output: TextIO = sys.stdout) -> int:
    try:
        report = pcm.load_json(report_path, "spectral baseline report")
        validate(report, root, require_fingerprint=True)
    except (OSError, ValueError, pcm.PCMComparisonError, signal.SignalBaselineReportError, SpectralBaselineReportError) as exc:
        print(f"spectral baseline report rejected: {exc}", file=output)
        return 1
    print(f"spectral baseline is current: {len(report['assets'])} whole/role assets", file=output)
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
