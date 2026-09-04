#!/usr/bin/env python3
"""Finalize and independently verify local stereo compatibility baselines."""

from __future__ import annotations

from array import array
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


REPORT_SCHEMA = "autotechno-stereo-compatibility-baseline-report.v1"
ANALYZER_VERSION = "autotechno-pcm-stereo-compatibility-analyzer.v1"
EVIDENCE_SCHEMA = "autotechno-pcm-stereo-compatibility.v1"
DOMAINS = ("full", "sub", "low-mid", "mid", "high")
CUTOFFS = (35.0, 120.0, 420.0, 2_400.0, 10_000.0)
DECIBEL_FLOOR = -120.0
PAYLOAD_KEYS = {
    "schema", "reportVersion", "analyzerVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "policies", "inputs", "assets",
}
REPORT_KEYS = PAYLOAD_KEYS | {"reportFingerprint"}
POLICY_KEYS = {
    "bpm", "beatsPerBar", "segmentDurationSeconds",
    "segmentFrameRounding", "eligibleSourceChannelCounts",
    "monoSourceMapping", "domains",
    "midSideScaling", "monoFold", "correlationDenominator",
    "correlationClamp", "zeroAndActivityRule",
    "compatibilityClassification", "bandEnergyModel",
    "bandFilterCutoffsHz", "bandFilterReset", "bandEnergyConservation",
    "aggregation", "finalSegmentPolicy", "monoLevelUnit", "decibelFloor",
    "interpretation",
}
INPUT_KEYS = signal.INPUT_KEYS
ASSET_KEYS = signal.ASSET_KEYS
EVIDENCE_KEYS = {
    "schema", "sampleRate", "sourceChannelCount", "frameCount",
    "segmentFrameCount", "domains", "summary", "segments",
}
SEGMENT_KEYS = {"startFrame", "frameCount", "domains"}
DOMAIN_KEYS = {
    "name", "frameCount", "leftMeanSquare", "rightMeanSquare",
    "stereoMeanSquare", "crossMean", "midMeanSquare", "sideMeanSquare",
    "correlation", "monoRetentionRatio", "monoLevelChangeDB",
    "sideEnergyShare", "sideToMidRatio", "state", "finite",
}
DEFAULT_PAYLOAD = Path(
    "docs/local/reports/stereo-compatibility-baseline-v1/payload.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/stereo-compatibility-baseline-v1/manifest.json"
)


class StereoCompatibilityBaselineReportError(RuntimeError):
    """An actionable schema, provenance, or independent-analysis failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def rounded_frames(value: float) -> int:
    return int(math.floor(value + 0.5))


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> None:
    try:
        signal.exact_keys(value, expected, location)
    except signal.SignalBaselineReportError as exc:
        raise StereoCompatibilityBaselineReportError(str(exc)) from exc


def close(actual: float, expected: float, tolerance: float = 2e-8) -> bool:
    return abs(actual - expected) <= tolerance * max(1.0, abs(expected))


def read_channels(path: Path) -> tuple[int, list[array[float]]]:
    try:
        with path.open("rb") as handle:
            sample_rate, channel_count, frame_count, data_size, _ = (
                pcm.read_wav_header(handle, path)
            )
            values = pcm.float_array(handle.read(data_size))
    except (OSError, pcm.PCMComparisonError) as exc:
        raise StereoCompatibilityBaselineReportError(
            f"cannot read exact PCM from {path}: {exc}"
        ) from exc
    if len(values) != frame_count * channel_count:
        raise StereoCompatibilityBaselineReportError(
            f"{path} PCM length changed while reading"
        )
    channels = [array("f") for _ in range(channel_count)]
    for channel in range(channel_count):
        channels[channel].extend(values[channel::channel_count])
    return sample_rate, channels


def empty_accumulator() -> list[float]:
    # frame count, left, right, cross, mid, side raw energy sums
    return [0.0] * 6


def add(accumulator: list[float], left: float, right: float) -> None:
    mid = (left + right) * 0.5
    side = (left - right) * 0.5
    accumulator[0] += 1.0
    accumulator[1] += left * left
    accumulator[2] += right * right
    accumulator[3] += left * right
    accumulator[4] += mid * mid
    accumulator[5] += side * side


def merge(destination: list[float], source: Sequence[float]) -> None:
    for index, value in enumerate(source):
        destination[index] += value


def domain_evidence(name: str, accumulator: Sequence[float]) -> dict[str, Any]:
    frames = int(accumulator[0])
    divisor = max(1, frames)
    left = accumulator[1] / divisor
    right = accumulator[2] / divisor
    stereo = (left + right) * 0.5
    cross = accumulator[3] / divisor
    mid = accumulator[4] / divisor
    side = accumulator[5] / divisor
    if left == 0.0 and right == 0.0:
        state = "inactive"
    elif left == 0.0 or right == 0.0:
        state = "oneSided"
    elif side == 0.0:
        state = "safeExactMono"
    elif mid == 0.0:
        state = "unsafeExactCancellation"
    else:
        state = "mixed"
    correlation = None
    if left > 0.0 and right > 0.0:
        if state == "safeExactMono":
            correlation = 1.0
        elif state == "unsafeExactCancellation":
            correlation = -1.0
        else:
            correlation = max(
                -1.0, min(1.0, cross / (math.sqrt(left) * math.sqrt(right)))
            )
    retention = mid / stereo if stereo > 0.0 else None
    mono_db = None
    if retention is not None:
        mono_db = (max(DECIBEL_FLOOR, 10.0 * math.log10(retention))
                   if retention > 0.0 else DECIBEL_FLOOR)
    total = mid + side
    side_share = side / total if total > 0.0 else None
    side_to_mid = side / mid if mid > 0.0 else None
    if side_to_mid is not None and not math.isfinite(side_to_mid):
        side_to_mid = None
    values = [left, right, stereo, cross, mid, side]
    values.extend(value for value in (
        correlation, retention, mono_db, side_share, side_to_mid
    ) if value is not None)
    return {
        "name": name,
        "frameCount": frames,
        "leftMeanSquare": left,
        "rightMeanSquare": right,
        "stereoMeanSquare": stereo,
        "crossMean": cross,
        "midMeanSquare": mid,
        "sideMeanSquare": side,
        "correlation": correlation,
        "monoRetentionRatio": retention,
        "monoLevelChangeDB": mono_db,
        "sideEnergyShare": side_share,
        "sideToMidRatio": side_to_mid,
        "state": state,
        "finite": all(math.isfinite(value) for value in values),
    }


def analyze_pcm(
    channels: Sequence[Sequence[float]],
    sample_rate: int,
    segment_frame_count: int,
) -> dict[str, Any]:
    if (len(channels) not in (1, 2) or not channels[0]
            or any(len(channel) != len(channels[0]) for channel in channels)
            or sample_rate <= 0 or segment_frame_count <= 0):
        raise StereoCompatibilityBaselineReportError(
            "independent analyzer requires aligned nonempty mono or stereo PCM"
        )
    frame_count = len(channels[0])
    right_channel = channels[1] if len(channels) == 2 else channels[0]
    summaries = [empty_accumulator() for _ in DOMAINS]
    segments: list[dict[str, Any]] = []
    start = 0
    while start < frame_count:
        count = min(segment_frame_count, frame_count - start)
        coefficients = [
            1.0 - math.exp(
                -2.0 * math.pi * min(cutoff, sample_rate * 0.45)
                / sample_rate
            )
            for cutoff in CUTOFFS
        ]
        left_states = [0.0] * len(CUTOFFS)
        right_states = [0.0] * len(CUTOFFS)
        accumulators = [empty_accumulator() for _ in DOMAINS]
        for frame in range(start, start + count):
            left = float(channels[0][frame])
            right = float(right_channel[frame])
            if not math.isfinite(left) or not math.isfinite(right):
                raise StereoCompatibilityBaselineReportError(
                    "independent analyzer received non-finite PCM"
                )
            add(accumulators[0], left, right)
            for index, coefficient in enumerate(coefficients):
                left_states[index] += (
                    left - left_states[index]
                ) * coefficient
                right_states[index] += (
                    right - right_states[index]
                ) * coefficient
            left_bands = (
                left_states[1] - left_states[0],
                left_states[2] - left_states[1],
                left_states[3] - left_states[2],
                left_states[4] - left_states[3],
            )
            right_bands = (
                right_states[1] - right_states[0],
                right_states[2] - right_states[1],
                right_states[3] - right_states[2],
                right_states[4] - right_states[3],
            )
            for index, (left_band, right_band) in enumerate(
                zip(left_bands, right_bands), start=1
            ):
                add(accumulators[index], left_band, right_band)
        for destination, source in zip(summaries, accumulators):
            merge(destination, source)
        segments.append({
            "startFrame": start,
            "frameCount": count,
            "domains": [
                domain_evidence(name, accumulator)
                for name, accumulator in zip(DOMAINS, accumulators)
            ],
        })
        start += count
    return {
        "schema": EVIDENCE_SCHEMA,
        "sampleRate": sample_rate,
        "sourceChannelCount": len(channels),
        "frameCount": frame_count,
        "segmentFrameCount": segment_frame_count,
        "domains": list(DOMAINS),
        "summary": [
            domain_evidence(name, accumulator)
            for name, accumulator in zip(DOMAINS, summaries)
        ],
        "segments": segments,
    }


def compare_recomputed(actual: object, expected: object, location: str) -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            raise StereoCompatibilityBaselineReportError(
                f"{location} must be an object"
            )
        exact_keys(actual, set(expected), location)
        for key in expected:
            compare_recomputed(actual[key], expected[key], f"{location}.{key}")
    elif isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise StereoCompatibilityBaselineReportError(
                f"{location} has wrong cardinality"
            )
        for index, (actual_item, expected_item) in enumerate(zip(actual, expected)):
            compare_recomputed(actual_item, expected_item, f"{location}[{index}]")
    elif isinstance(expected, float):
        if (isinstance(actual, bool) or not isinstance(actual, (int, float))
                or not math.isfinite(float(actual))
                or not close(float(actual), expected)):
            raise StereoCompatibilityBaselineReportError(
                f"{location} does not independently recompute"
            )
    elif actual != expected:
        raise StereoCompatibilityBaselineReportError(
            f"{location} does not independently recompute"
        )


def expected_policy() -> dict[str, object]:
    return {
        "bpm": 130.0,
        "beatsPerBar": 4,
        "segmentDurationSeconds": 240.0 / 130.0,
        "segmentFrameRounding": "nearest-frame",
        "eligibleSourceChannelCounts": [1, 2],
        "monoSourceMapping": "repeat-source-channel-as-left-and-right",
        "domains": list(DOMAINS),
        "midSideScaling": "half-sum-half-difference",
        "monoFold": "arithmetic-mean-of-two-source-channels",
        "correlationDenominator": (
            "exact-identities-else-sqrt-left-energy-times-sqrt-right-energy"
        ),
        "correlationClamp": "closed-minus-one-to-one",
        "zeroAndActivityRule": "exact-digital-zero-no-epsilon",
        "compatibilityClassification": (
            "exact-digital-identities-only-mixed-unranked"
        ),
        "bandEnergyModel": (
            "causal-one-pole-difference-non-power-complementary"
        ),
        "bandFilterCutoffsHz": list(CUTOFFS),
        "bandFilterReset": "reset-at-each-segment-boundary",
        "bandEnergyConservation": "not-claimed",
        "aggregation": "frame-weighted-raw-energy-sums",
        "finalSegmentPolicy": "analyze-nonempty-partial-segment",
        "monoLevelUnit": "ten-log10-mid-over-stereo-mean-square",
        "decibelFloor": DECIBEL_FLOOR,
        "interpretation": "descriptive-structural-not-artistic-ranking",
    }


def validate_evidence(
    value: object,
    channels: Sequence[Sequence[float]],
    sample_rate: int,
    segment_frames: int,
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise StereoCompatibilityBaselineReportError(f"{location} must be an object")
    exact_keys(value, EVIDENCE_KEYS, location)
    summary = value.get("summary")
    if isinstance(summary, list):
        for index, domain in enumerate(summary):
            if isinstance(domain, dict):
                exact_keys(domain, DOMAIN_KEYS, f"{location}.summary[{index}]")
    segments = value.get("segments")
    if isinstance(segments, list):
        for index, segment in enumerate(segments):
            if isinstance(segment, dict):
                exact_keys(segment, SEGMENT_KEYS, f"{location}.segments[{index}]")
                domains = segment.get("domains")
                if isinstance(domains, list):
                    for domain_index, domain in enumerate(domains):
                        if isinstance(domain, dict):
                            exact_keys(
                                domain, DOMAIN_KEYS,
                                f"{location}.segments[{index}].domains[{domain_index}]",
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
        raise StereoCompatibilityBaselineReportError(f"{location} must be an object")
    exact_keys(value, ASSET_KEYS, location)
    for key in (
        "assetId", "domain", "entryId", "signal", "classification",
        "pcmSha256", "wavPath",
    ):
        if value.get(key) != expected.get(key):
            raise StereoCompatibilityBaselineReportError(
                f"{location}.{key} does not match its manifest"
            )
    path = pcm.resolve_local_path(root, value.get("wavPath"), f"{location}.wavPath")
    sample_rate, channels = read_channels(path)
    if sample_rate != expected.get("sampleRate") or len(channels) not in (1, 2):
        raise StereoCompatibilityBaselineReportError(
            f"{location} must remain exact manifest-bound mono or stereo PCM"
        )
    segment_frames = rounded_frames(sample_rate * 240.0 / 130.0)
    validate_evidence(
        value.get("evidence"), channels, sample_rate, segment_frames,
        f"{location}.evidence",
    )


def validate(report: Mapping[str, Any], root: Path, require_fingerprint: bool) -> None:
    exact_keys(report, REPORT_KEYS if require_fingerprint else PAYLOAD_KEYS, "report")
    if report.get("schema") != REPORT_SCHEMA or report.get("reportVersion") != 1:
        raise StereoCompatibilityBaselineReportError("report schema/version is invalid")
    if report.get("analyzerVersion") != ANALYZER_VERSION:
        raise StereoCompatibilityBaselineReportError("analyzer version is stale")
    policies = report.get("policies")
    if not isinstance(policies, dict):
        raise StereoCompatibilityBaselineReportError("policies must be an object")
    exact_keys(policies, POLICY_KEYS, "policies")
    compare_recomputed(policies, expected_policy(), "policies")
    corpus_path = root / "docs/BASELINE_CORPUS.json"
    if report.get("corpusSha256") != pcm.sha256(corpus_path):
        raise StereoCompatibilityBaselineReportError("corpus hash is stale")
    snapshot = pcm.load_json(
        root / "docs/ROADMAP_EXECUTION_BASELINE.json", "roadmap snapshot"
    )
    if report.get("contractBaselineFingerprint") != snapshot.get(
        "snapshotFingerprint"
    ):
        raise StereoCompatibilityBaselineReportError(
            "contract baseline fingerprint is stale"
        )
    inputs = report.get("inputs")
    if (not isinstance(inputs, list)
            or [item.get("domain") for item in inputs if isinstance(item, dict)]
            != ["whole-mix", "role-stems"]):
        raise StereoCompatibilityBaselineReportError(
            "inputs must contain whole-mix then role-stems"
        )
    cache: dict[Path, pcm.ScannedWav] = {}
    expected_assets: dict[str, dict[str, Any]] = {}
    common_provenance: Optional[tuple[object, object, object]] = None
    for index, input_record in enumerate(inputs):
        if not isinstance(input_record, dict):
            raise StereoCompatibilityBaselineReportError(
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
            raise StereoCompatibilityBaselineReportError(
                f"inputs[{index}] manifest hash is stale"
            )
        manifest_domain, artifacts = pcm.extract_artifacts(manifest, root, domain)
        if (manifest_domain != domain
                or input_record.get("manifestSchema") != manifest.get("schema")):
            raise StereoCompatibilityBaselineReportError(
                f"inputs[{index}] domain/schema mismatch"
            )
        scans = {
            identifier: pcm.scan_artifact(artifact, cache)
            for identifier, artifact in sorted(artifacts.items())
        }
        if (input_record.get("assetCount") != len(artifacts)
                or input_record.get("pcmSetFingerprint")
                != signal.pcm_set_fingerprint(artifacts, scans)):
            raise StereoCompatibilityBaselineReportError(
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
            raise StereoCompatibilityBaselineReportError(
                "input provenance does not agree"
            )
    if common_provenance is None or (
        report.get("sourceFingerprint"), report.get("gitHead"),
        report.get("engineVersion"),
    ) != common_provenance:
        raise StereoCompatibilityBaselineReportError(
            "report provenance does not match its inputs"
        )
    assets = report.get("assets")
    if not isinstance(assets, list):
        raise StereoCompatibilityBaselineReportError("assets must be an array")
    identifiers = [
        item.get("assetId") for item in assets if isinstance(item, dict)
    ]
    if identifiers != sorted(expected_assets):
        raise StereoCompatibilityBaselineReportError(
            "assets must exactly cover both manifests in sorted identity order"
        )
    for index, asset in enumerate(assets):
        identifier = str(asset["assetId"])
        expected_asset = dict(expected_assets[identifier])
        expected_asset["assetId"] = identifier
        validate_asset(asset, expected_asset, root, f"assets[{index}]")
    if require_fingerprint:
        fingerprint = report.get("reportFingerprint")
        if not pcm.is_sha256(fingerprint):
            raise StereoCompatibilityBaselineReportError(
                "reportFingerprint must be SHA-256"
            )
        payload = dict(report)
        del payload["reportFingerprint"]
        expected_fingerprint = hashlib.sha256(
            pcm.canonical_bytes(payload)
        ).hexdigest()
        if fingerprint != expected_fingerprint:
            raise StereoCompatibilityBaselineReportError(
                "reportFingerprint is stale or mutated"
            )


def generate(
    payload_path: Path,
    output_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        payload = dict(pcm.load_json(payload_path, "stereo compatibility payload"))
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
        StereoCompatibilityBaselineReportError,
    ) as exc:
        print(f"stereo compatibility generation rejected: {exc}", file=output)
        return 1
    state_counts: dict[str, int] = {}
    for asset in payload["assets"]:
        state = str(asset["evidence"]["summary"][0]["state"])
        state_counts[state] = state_counts.get(state, 0) + 1
    print(
        f"generated stereo compatibility baseline: {len(payload['assets'])} "
        f"assets, full-band states {json.dumps(state_counts, sort_keys=True)}, "
        f"fingerprint {payload['reportFingerprint']}",
        file=output,
    )
    return 0


def check(
    report_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        report = pcm.load_json(report_path, "stereo compatibility baseline")
        validate(report, root, require_fingerprint=True)
    except (
        OSError, ValueError, pcm.PCMComparisonError,
        signal.SignalBaselineReportError,
        StereoCompatibilityBaselineReportError,
    ) as exc:
        print(f"stereo compatibility baseline rejected: {exc}", file=output)
        return 1
    print(
        f"stereo compatibility baseline is current: {len(report['assets'])} "
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
