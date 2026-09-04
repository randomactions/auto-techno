#!/usr/bin/env python3
"""Finalize and verify local whole/role PCM signal-integrity baselines."""

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


REPORT_SCHEMA = "autotechno-signal-baseline-report.v1"
ANALYZER_VERSION = "autotechno-pcm-signal-integrity.v1"
EVIDENCE_SCHEMA = "autotechno-pcm-signal-integrity.v1"
PAYLOAD_KEYS = {
    "schema", "reportVersion", "analyzerVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "policies", "inputs", "assets",
}
REPORT_KEYS = PAYLOAD_KEYS | {"reportFingerprint"}
POLICY_KEYS = {
    "bpm", "beatsPerBar", "segmentDurationSeconds", "segmentFrameRounding",
    "clippingAmplitude", "nearSilenceDBFS", "nearSilenceAmplitude",
    "float32MinimumNormal", "decibelFloor", "truePeakStandard",
    "truePeakOversamplingFactor",
}
INPUT_KEYS = {
    "domain", "manifestPath", "manifestSha256", "manifestSchema",
    "assetCount", "pcmSetFingerprint",
}
ASSET_KEYS = {
    "assetId", "domain", "entryId", "signal", "classification",
    "pcmSha256", "wavPath", "evidence",
}
EVIDENCE_KEYS = {
    "schema", "sampleRate", "channelCount", "frameCount",
    "segmentFrameCount", "combined", "channels", "nearSilentFrameCount",
    "longestNearSilentFrameRun", "segments",
}
WINDOW_KEYS = {
    "startFrame", "frameCount", "combined", "channels",
    "nearSilentFrameCount", "longestNearSilentFrameRun",
}
STATISTIC_KEYS = {
    "sampleCount", "finiteSampleCount", "nonfiniteSampleCount",
    "samplePeak", "samplePeakDBFS", "truePeak", "truePeakDBTP", "rms",
    "crestFactor", "dcOffset", "clippedSampleCount",
    "subnormalSampleCount", "exactZeroSampleCount", "nearSilenceSampleCount",
}
COUNT_KEYS = (
    "sampleCount", "finiteSampleCount", "nonfiniteSampleCount",
    "clippedSampleCount", "subnormalSampleCount", "exactZeroSampleCount",
    "nearSilenceSampleCount",
)
DEFAULT_PAYLOAD = Path("docs/local/reports/signal-baseline-v1/payload.json")
DEFAULT_REPORT = Path("docs/local/reports/signal-baseline-v1/manifest.json")


class SignalBaselineReportError(RuntimeError):
    """An actionable report-schema, provenance, or aggregation failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str
) -> None:
    if set(value) != expected:
        raise SignalBaselineReportError(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(value)}"
        )


def finite_number(value: object, location: str) -> float:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(float(value))
    ):
        raise SignalBaselineReportError(f"{location} must be finite numeric")
    return float(value)


def nonnegative_integer(value: object, location: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise SignalBaselineReportError(
            f"{location} must be a non-negative integer"
        )
    return value


def close(actual: float, expected: float, tolerance: float = 1e-9) -> bool:
    return abs(actual - expected) <= tolerance * max(1.0, abs(expected))


def decibels(amplitude: float) -> float:
    return -120.0 if amplitude <= 0 else max(-120.0, 20 * math.log10(amplitude))


def validate_statistics(value: object, location: str) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise SignalBaselineReportError(f"{location} must be an object")
    exact_keys(value, STATISTIC_KEYS, location)
    for key in COUNT_KEYS:
        nonnegative_integer(value.get(key), f"{location}.{key}")
    sample_count = int(value["sampleCount"])
    if value["finiteSampleCount"] + value["nonfiniteSampleCount"] != sample_count:
        raise SignalBaselineReportError(
            f"{location} finite/non-finite counts do not sum to sampleCount"
        )
    if value["nonfiniteSampleCount"] != 0:
        raise SignalBaselineReportError(
            f"{location} local baseline must contain no non-finite samples"
        )
    for key in (
        "clippedSampleCount", "subnormalSampleCount", "exactZeroSampleCount",
        "nearSilenceSampleCount",
    ):
        if value[key] > sample_count:
            raise SignalBaselineReportError(f"{location}.{key} exceeds sampleCount")
    peak = finite_number(value.get("samplePeak"), f"{location}.samplePeak")
    peak_db = finite_number(
        value.get("samplePeakDBFS"), f"{location}.samplePeakDBFS"
    )
    true_peak = finite_number(value.get("truePeak"), f"{location}.truePeak")
    true_peak_db = finite_number(
        value.get("truePeakDBTP"), f"{location}.truePeakDBTP"
    )
    rms = finite_number(value.get("rms"), f"{location}.rms")
    crest = finite_number(value.get("crestFactor"), f"{location}.crestFactor")
    dc = finite_number(value.get("dcOffset"), f"{location}.dcOffset")
    if peak < 0 or true_peak < peak - 1e-12 or rms < 0 or crest < 0:
        raise SignalBaselineReportError(f"{location} has impossible level metrics")
    if abs(dc) > rms + 1e-9:
        raise SignalBaselineReportError(f"{location}.dcOffset exceeds RMS")
    if not close(peak_db, decibels(peak), 1e-10):
        raise SignalBaselineReportError(f"{location}.samplePeakDBFS is inconsistent")
    if not close(true_peak_db, decibels(true_peak), 1e-10):
        raise SignalBaselineReportError(f"{location}.truePeakDBTP is inconsistent")
    expected_crest = peak / rms if rms > 0 else 0.0
    if not close(crest, expected_crest, 1e-10):
        raise SignalBaselineReportError(f"{location}.crestFactor is inconsistent")
    return value


def validate_aggregate(
    parent: Mapping[str, Any],
    children: Sequence[Mapping[str, Any]],
    location: str,
) -> None:
    for key in COUNT_KEYS:
        if parent[key] != sum(child[key] for child in children):
            raise SignalBaselineReportError(
                f"{location}.{key} does not aggregate its children"
            )
    if not children:
        return
    if not close(
        float(parent["samplePeak"]),
        max(float(child["samplePeak"]) for child in children),
        1e-12,
    ):
        raise SignalBaselineReportError(
            f"{location}.samplePeak does not aggregate its children"
        )
    sample_count = int(parent["sampleCount"])
    energy = sum(
        float(child["rms"]) ** 2 * int(child["sampleCount"])
        for child in children
    )
    expected_rms = math.sqrt(energy / sample_count) if sample_count else 0.0
    if not close(float(parent["rms"]), expected_rms, 1e-9):
        raise SignalBaselineReportError(
            f"{location}.rms does not aggregate its children"
        )
    summed = sum(
        float(child["dcOffset"]) * int(child["sampleCount"])
        for child in children
    )
    expected_dc = summed / sample_count if sample_count else 0.0
    if not close(float(parent["dcOffset"]), expected_dc, 1e-9):
        raise SignalBaselineReportError(
            f"{location}.dcOffset does not aggregate its children"
        )


def expected_assets(
    manifest: Mapping[str, Any], domain: str
) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        raise SignalBaselineReportError(f"{domain} manifest entries must be an array")
    if domain == "whole-mix":
        for entry in entries:
            if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
                raise SignalBaselineReportError("whole-mix manifest entry is invalid")
            identifier = f"{entry['id']}::whole-mix"
            result[identifier] = {
                "domain": domain,
                "entryId": entry["id"],
                "signal": "whole-mix",
                "classification": "whole-mix",
                "sampleRate": entry.get("sampleRate"),
                "channelCount": entry.get("channelCount"),
                "frameCount": entry.get("frameCount"),
                "pcmSha256": entry.get("pcmSha256"),
                "wavPath": entry.get("wavPath"),
            }
    else:
        for entry in entries:
            if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
                raise SignalBaselineReportError("role-stem manifest entry is invalid")
            files = entry.get("files")
            if not isinstance(files, list):
                raise SignalBaselineReportError("role-stem files must be an array")
            for file in files:
                if not isinstance(file, dict) or not isinstance(file.get("signal"), str):
                    raise SignalBaselineReportError("role-stem file is invalid")
                identifier = f"{entry['id']}::{file['signal']}"
                result[identifier] = {
                    "domain": domain,
                    "entryId": entry["id"],
                    "signal": file["signal"],
                    "classification": file.get("classification"),
                    "sampleRate": file.get("sampleRate"),
                    "channelCount": file.get("channelCount"),
                    "frameCount": file.get("frameCount"),
                    "pcmSha256": file.get("pcmSha256"),
                    "wavPath": file.get("wavPath"),
                }
    return result


def pcm_set_fingerprint(
    artifacts: Mapping[str, pcm.Artifact], scans: Mapping[str, pcm.ScannedWav]
) -> str:
    digest = hashlib.sha256()
    for identifier in sorted(artifacts):
        digest.update(identifier.encode("utf-8"))
        digest.update(b"\0")
        digest.update(scans[identifier].pcm_sha256.encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def validate_window(
    value: object,
    location: str,
    channel_count: int,
    expected_start: int,
    expected_frames: int,
) -> tuple[Mapping[str, Any], list[Mapping[str, Any]]]:
    if not isinstance(value, dict):
        raise SignalBaselineReportError(f"{location} must be an object")
    exact_keys(value, WINDOW_KEYS, location)
    if value.get("startFrame") != expected_start:
        raise SignalBaselineReportError(f"{location}.startFrame is not contiguous")
    if value.get("frameCount") != expected_frames:
        raise SignalBaselineReportError(f"{location}.frameCount is incorrect")
    combined = validate_statistics(value.get("combined"), f"{location}.combined")
    channels = value.get("channels")
    if not isinstance(channels, list) or len(channels) != channel_count:
        raise SignalBaselineReportError(f"{location}.channels has wrong cardinality")
    channel_stats = [
        validate_statistics(item, f"{location}.channels[{index}]")
        for index, item in enumerate(channels)
    ]
    if any(item["sampleCount"] != expected_frames for item in channel_stats):
        raise SignalBaselineReportError(f"{location} channel sampleCount is incorrect")
    if combined["sampleCount"] != expected_frames * channel_count:
        raise SignalBaselineReportError(f"{location}.combined.sampleCount is incorrect")
    validate_aggregate(combined, channel_stats, f"{location}.combined")
    near_count = nonnegative_integer(
        value.get("nearSilentFrameCount"), f"{location}.nearSilentFrameCount"
    )
    longest = nonnegative_integer(
        value.get("longestNearSilentFrameRun"),
        f"{location}.longestNearSilentFrameRun",
    )
    if near_count > expected_frames or longest > near_count:
        raise SignalBaselineReportError(f"{location} has impossible silence runs")
    return combined, channel_stats


def validate_asset(
    value: object,
    expected: Mapping[str, Any],
    location: str,
) -> None:
    if not isinstance(value, dict):
        raise SignalBaselineReportError(f"{location} must be an object")
    exact_keys(value, ASSET_KEYS, location)
    for key in (
        "domain", "entryId", "signal", "classification", "pcmSha256", "wavPath"
    ):
        if value.get(key) != expected.get(key):
            raise SignalBaselineReportError(f"{location}.{key} does not match manifest")
    evidence = value.get("evidence")
    if not isinstance(evidence, dict):
        raise SignalBaselineReportError(f"{location}.evidence must be an object")
    exact_keys(evidence, EVIDENCE_KEYS, f"{location}.evidence")
    if evidence.get("schema") != EVIDENCE_SCHEMA:
        raise SignalBaselineReportError(f"{location}.evidence.schema is invalid")
    sample_rate = expected["sampleRate"]
    channel_count = expected["channelCount"]
    frame_count = expected["frameCount"]
    if evidence.get("sampleRate") != sample_rate:
        raise SignalBaselineReportError(f"{location}.evidence.sampleRate is invalid")
    if evidence.get("channelCount") != channel_count:
        raise SignalBaselineReportError(f"{location}.evidence.channelCount is invalid")
    if evidence.get("frameCount") != frame_count:
        raise SignalBaselineReportError(f"{location}.evidence.frameCount is invalid")
    segment_frames = int(round(float(sample_rate) * 240.0 / 130.0))
    if evidence.get("segmentFrameCount") != segment_frames:
        raise SignalBaselineReportError(
            f"{location}.evidence.segmentFrameCount is not one 130-BPM bar"
        )
    combined = validate_statistics(
        evidence.get("combined"), f"{location}.evidence.combined"
    )
    channels = evidence.get("channels")
    if not isinstance(channels, list) or len(channels) != channel_count:
        raise SignalBaselineReportError(f"{location}.evidence.channels is invalid")
    channel_stats = [
        validate_statistics(item, f"{location}.evidence.channels[{index}]")
        for index, item in enumerate(channels)
    ]
    if any(item["sampleCount"] != frame_count for item in channel_stats):
        raise SignalBaselineReportError(f"{location} channel sampleCount is invalid")
    if combined["sampleCount"] != frame_count * channel_count:
        raise SignalBaselineReportError(f"{location} combined sampleCount is invalid")
    validate_aggregate(combined, channel_stats, f"{location}.evidence.combined")
    segments = evidence.get("segments")
    if not isinstance(segments, list):
        raise SignalBaselineReportError(f"{location}.evidence.segments must be an array")
    expected_segment_count = (
        (frame_count + segment_frames - 1) // segment_frames if frame_count else 0
    )
    if len(segments) != expected_segment_count:
        raise SignalBaselineReportError(f"{location} has wrong segment count")
    segment_combined: list[Mapping[str, Any]] = []
    segment_channels: list[list[Mapping[str, Any]]] = [
        [] for _ in range(channel_count)
    ]
    near_silent_sum = 0
    maximum_segment_run = 0
    start = 0
    for index, segment in enumerate(segments):
        count = min(segment_frames, frame_count - start)
        combined_item, channel_items = validate_window(
            segment,
            f"{location}.evidence.segments[{index}]",
            channel_count,
            start,
            count,
        )
        segment_combined.append(combined_item)
        for channel_index, item in enumerate(channel_items):
            segment_channels[channel_index].append(item)
        near_silent_sum += int(segment["nearSilentFrameCount"])
        maximum_segment_run = max(
            maximum_segment_run, int(segment["longestNearSilentFrameRun"])
        )
        start += count
    validate_aggregate(combined, segment_combined, f"{location}.evidence.combined")
    for index, item in enumerate(channel_stats):
        validate_aggregate(
            item,
            segment_channels[index],
            f"{location}.evidence.channels[{index}]",
        )
    near_count = nonnegative_integer(
        evidence.get("nearSilentFrameCount"),
        f"{location}.evidence.nearSilentFrameCount",
    )
    longest = nonnegative_integer(
        evidence.get("longestNearSilentFrameRun"),
        f"{location}.evidence.longestNearSilentFrameRun",
    )
    if near_count != near_silent_sum:
        raise SignalBaselineReportError(
            f"{location}.evidence.nearSilentFrameCount does not aggregate segments"
        )
    if longest < maximum_segment_run or longest > near_count:
        raise SignalBaselineReportError(
            f"{location}.evidence.longestNearSilentFrameRun is impossible"
        )


def validate(
    report: Mapping[str, Any],
    root: Path,
    require_fingerprint: bool,
) -> None:
    exact_keys(report, REPORT_KEYS if require_fingerprint else PAYLOAD_KEYS, "report")
    if report.get("schema") != REPORT_SCHEMA or report.get("reportVersion") != 1:
        raise SignalBaselineReportError("report schema/version is invalid")
    if report.get("analyzerVersion") != ANALYZER_VERSION:
        raise SignalBaselineReportError("analyzerVersion is invalid")
    corpus_path = root / "docs/BASELINE_CORPUS.json"
    baseline_path = root / "docs/ROADMAP_EXECUTION_BASELINE.json"
    if report.get("corpusSha256") != pcm.sha256(corpus_path):
        raise SignalBaselineReportError("corpusSha256 does not match current corpus")
    baseline = pcm.load_json(baseline_path, "contract baseline")
    if report.get("contractBaselineFingerprint") != baseline.get(
        "snapshotFingerprint"
    ):
        raise SignalBaselineReportError(
            "contractBaselineFingerprint does not match current baseline"
        )
    policies = report.get("policies")
    if not isinstance(policies, dict):
        raise SignalBaselineReportError("policies must be an object")
    exact_keys(policies, POLICY_KEYS, "policies")
    expected_policies = {
        "bpm": 130,
        "beatsPerBar": 4,
        "segmentDurationSeconds": 240.0 / 130.0,
        "segmentFrameRounding": "nearest-frame",
        "clippingAmplitude": 1,
        "nearSilenceDBFS": -90,
        "nearSilenceAmplitude": 10 ** (-90.0 / 20.0),
        "float32MinimumNormal": 1.1754943508222875e-38,
        "decibelFloor": -120,
        "truePeakStandard": "ITU-R BS.1770-5 Annex 2",
        "truePeakOversamplingFactor": 4,
    }
    for key, expected in expected_policies.items():
        actual = policies.get(key)
        if isinstance(expected, float):
            if not isinstance(actual, (int, float)) or not close(
                float(actual), expected, 1e-12
            ):
                raise SignalBaselineReportError(f"policies.{key} is invalid")
        elif actual != expected:
            raise SignalBaselineReportError(f"policies.{key} is invalid")

    inputs = report.get("inputs")
    if not isinstance(inputs, list) or [item.get("domain") for item in inputs if isinstance(item, dict)] != [
        "whole-mix", "role-stems"
    ]:
        raise SignalBaselineReportError(
            "inputs must contain whole-mix then role-stems"
        )
    cache: dict[Path, pcm.ScannedWav] = {}
    expected: dict[str, dict[str, Any]] = {}
    common_source: Optional[str] = None
    common_git: Optional[str] = None
    common_engine: Optional[str] = None
    for index, input_record in enumerate(inputs):
        if not isinstance(input_record, dict):
            raise SignalBaselineReportError(f"inputs[{index}] must be an object")
        exact_keys(input_record, INPUT_KEYS, f"inputs[{index}]")
        domain = str(input_record["domain"])
        manifest_path = pcm.resolve_local_path(
            root, input_record.get("manifestPath"), f"inputs[{index}].manifestPath"
        )
        manifest = pcm.load_json(manifest_path, f"{domain} manifest")
        if input_record.get("manifestSha256") != pcm.sha256(manifest_path):
            raise SignalBaselineReportError(f"inputs[{index}] manifest hash is stale")
        manifest_domain, artifacts = pcm.extract_artifacts(manifest, root, domain)
        if manifest_domain != domain:
            raise SignalBaselineReportError(f"inputs[{index}] domain/schema mismatch")
        if input_record.get("manifestSchema") != manifest.get("schema"):
            raise SignalBaselineReportError(f"inputs[{index}] schema is stale")
        scans = {
            identifier: pcm.scan_artifact(artifact, cache)
            for identifier, artifact in sorted(artifacts.items())
        }
        if input_record.get("assetCount") != len(artifacts):
            raise SignalBaselineReportError(f"inputs[{index}] assetCount is stale")
        if input_record.get("pcmSetFingerprint") != pcm_set_fingerprint(
            artifacts, scans
        ):
            raise SignalBaselineReportError(
                f"inputs[{index}] pcmSetFingerprint is stale"
            )
        expected.update(expected_assets(manifest, domain))
        source = manifest.get("sourceFingerprint")
        git_head = manifest.get("gitHead")
        engine = manifest.get("engineVersion")
        if index == 0:
            common_source = source
            common_git = git_head
            common_engine = engine
        elif (source, git_head, engine) != (
            common_source, common_git, common_engine
        ):
            raise SignalBaselineReportError("input provenance does not agree")
    if report.get("sourceFingerprint") != common_source:
        raise SignalBaselineReportError("sourceFingerprint does not match inputs")
    if report.get("gitHead") != common_git:
        raise SignalBaselineReportError("gitHead does not match inputs")
    if report.get("engineVersion") != common_engine:
        raise SignalBaselineReportError("engineVersion does not match inputs")

    assets = report.get("assets")
    if not isinstance(assets, list):
        raise SignalBaselineReportError("assets must be an array")
    identifiers = [item.get("assetId") for item in assets if isinstance(item, dict)]
    if identifiers != sorted(expected):
        raise SignalBaselineReportError(
            "assets must exactly cover both manifests in sorted identity order"
        )
    for index, asset in enumerate(assets):
        identifier = str(asset["assetId"])
        validate_asset(asset, expected[identifier], f"assets[{index}]")
    if require_fingerprint:
        fingerprint = report.get("reportFingerprint")
        if not pcm.is_sha256(fingerprint):
            raise SignalBaselineReportError("reportFingerprint must be SHA-256")
        payload = dict(report)
        del payload["reportFingerprint"]
        expected_fingerprint = hashlib.sha256(pcm.canonical_bytes(payload)).hexdigest()
        if fingerprint != expected_fingerprint:
            raise SignalBaselineReportError("reportFingerprint is stale or mutated")


def generate(
    payload_path: Path,
    output_path: Path,
    root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        payload = dict(pcm.load_json(payload_path, "signal baseline payload"))
        validate(payload, root, require_fingerprint=False)
        payload["reportFingerprint"] = hashlib.sha256(
            pcm.canonical_bytes(payload)
        ).hexdigest()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n",
            encoding="utf-8",
        )
    except (OSError, ValueError, pcm.PCMComparisonError, SignalBaselineReportError) as exc:
        print(f"signal baseline generation rejected: {exc}", file=output)
        return 1
    print(
        f"generated signal baseline: {len(payload['assets'])} assets, "
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
        report = pcm.load_json(report_path, "signal baseline report")
        validate(report, root, require_fingerprint=True)
    except (OSError, ValueError, pcm.PCMComparisonError, SignalBaselineReportError) as exc:
        print(f"signal baseline report rejected: {exc}", file=output)
        return 1
    print(
        f"signal baseline is current: {len(report['assets'])} whole/role assets",
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
