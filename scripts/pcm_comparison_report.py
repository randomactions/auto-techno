#!/usr/bin/env python3
"""Generate and verify deterministic whole-mix or role-stem PCM comparisons."""

from __future__ import annotations

import argparse
from array import array
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import sys
from typing import Any, Mapping, Optional, Sequence, TextIO


REPORT_SCHEMA = "autotechno-pcm-comparison-report.v1"
COMPARATOR_VERSION = "autotechno-pcm-comparator.v1"
WHOLE_SCHEMA = "autotechno-baseline-render-manifest.v1"
STEM_SCHEMA = "autotechno-role-stem-manifest.v1"
DEFAULT_ABSOLUTE_TOLERANCE = 0.000_001
DEFAULT_RMS_TOLERANCE = 0.000_000_1
READ_SIZE = 1024 * 1024


class PCMComparisonError(RuntimeError):
    """An actionable malformed-input or stale-report failure."""


@dataclass(frozen=True)
class Artifact:
    identifier: str
    entry_id: str
    signal: str
    path: Path
    sample_rate: int
    channel_count: int
    frame_count: int
    expected_pcm_sha256: str
    expected_wav_sha256: str


@dataclass(frozen=True)
class ScannedWav:
    sample_rate: int
    channel_count: int
    frame_count: int
    sample_count: int
    pcm_sha256: str
    wav_sha256: str


@dataclass(frozen=True)
class NumericComparison:
    report: Mapping[str, Any]
    squared_error_sum: float


class KahanSum:
    def __init__(self) -> None:
        self.total = 0.0
        self.compensation = 0.0

    def add(self, value: float) -> None:
        adjusted = value - self.compensation
        next_total = self.total + adjusted
        self.compensation = (next_total - self.total) - adjusted
        self.total = next_total


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(READ_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
        allow_nan=False,
    ).encode("utf-8")


def load_json(path: Path, label: str) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PCMComparisonError(f"cannot read {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise PCMComparisonError(f"{label} must contain one JSON object")
    return value


def is_sha256(value: object) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(
        character in "0123456789abcdef" for character in value
    )


def checked_nonnegative_float(value: object, label: str) -> float:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(float(value))
        or float(value) < 0.0
    ):
        raise PCMComparisonError(f"{label} must be a finite non-negative number")
    return float(value)


def normalized_relative_path(root: Path, path: Path, label: str) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError as exc:
        raise PCMComparisonError(f"{label} must be inside its declared root") from exc


def resolve_local_path(root: Path, value: object, label: str) -> Path:
    if not isinstance(value, str) or not value:
        raise PCMComparisonError(f"{label} must be a non-empty relative path")
    if "\\" in value:
        raise PCMComparisonError(f"{label} must use POSIX separators")
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or "." in path.parts or ".." in path.parts:
        raise PCMComparisonError(f"{label} must be a normalized relative path")
    resolved = root.joinpath(*path.parts).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise PCMComparisonError(f"{label} escapes its declared root") from exc
    return resolved


def checked_integer(value: object, label: str, minimum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise PCMComparisonError(f"{label} must be an integer >= {minimum}")
    return value


def artifact_from_fields(
    root: Path,
    entry_id: object,
    signal: object,
    fields: Mapping[str, Any],
    location: str,
) -> Artifact:
    if not isinstance(entry_id, str) or not entry_id:
        raise PCMComparisonError(f"{location}.id must be non-empty")
    if not isinstance(signal, str) or not signal:
        raise PCMComparisonError(f"{location}.signal must be non-empty")
    sample_rate = checked_integer(fields.get("sampleRate"), f"{location}.sampleRate", 1)
    channel_count = checked_integer(
        fields.get("channelCount"), f"{location}.channelCount", 1
    )
    if channel_count not in {1, 2}:
        raise PCMComparisonError(f"{location}.channelCount must be 1 or 2")
    frame_count = checked_integer(fields.get("frameCount"), f"{location}.frameCount", 0)
    pcm_sha = fields.get("pcmSha256")
    wav_sha = fields.get("wavSha256")
    if not is_sha256(pcm_sha):
        raise PCMComparisonError(f"{location}.pcmSha256 must be a SHA-256 digest")
    if not is_sha256(wav_sha):
        raise PCMComparisonError(f"{location}.wavSha256 must be a SHA-256 digest")
    return Artifact(
        identifier=f"{entry_id}::{signal}",
        entry_id=entry_id,
        signal=signal,
        path=resolve_local_path(root, fields.get("wavPath"), f"{location}.wavPath"),
        sample_rate=sample_rate,
        channel_count=channel_count,
        frame_count=frame_count,
        expected_pcm_sha256=str(pcm_sha),
        expected_wav_sha256=str(wav_sha),
    )


def extract_artifacts(
    manifest: Mapping[str, Any], root: Path, label: str
) -> tuple[str, dict[str, Artifact]]:
    schema = manifest.get("schema")
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        raise PCMComparisonError(f"{label}.entries must be an array")
    artifacts: dict[str, Artifact] = {}
    if schema == WHOLE_SCHEMA:
        domain = "whole-mix"
        for index, entry in enumerate(entries):
            location = f"{label}.entries[{index}]"
            if not isinstance(entry, dict):
                raise PCMComparisonError(f"{location} must be an object")
            artifact = artifact_from_fields(
                root, entry.get("id"), "whole-mix", entry, location
            )
            if artifact.identifier in artifacts:
                raise PCMComparisonError(f"{label} duplicates {artifact.identifier}")
            artifacts[artifact.identifier] = artifact
    elif schema == STEM_SCHEMA:
        domain = "role-stems"
        for entry_index, entry in enumerate(entries):
            location = f"{label}.entries[{entry_index}]"
            if not isinstance(entry, dict):
                raise PCMComparisonError(f"{location} must be an object")
            files = entry.get("files")
            if not isinstance(files, list):
                raise PCMComparisonError(f"{location}.files must be an array")
            for file_index, item in enumerate(files):
                file_location = f"{location}.files[{file_index}]"
                if not isinstance(item, dict):
                    raise PCMComparisonError(f"{file_location} must be an object")
                artifact = artifact_from_fields(
                    root, entry.get("id"), item.get("signal"), item, file_location
                )
                if artifact.identifier in artifacts:
                    raise PCMComparisonError(
                        f"{label} duplicates {artifact.identifier}"
                    )
                artifacts[artifact.identifier] = artifact
    else:
        raise PCMComparisonError(
            f"{label}.schema must be {WHOLE_SCHEMA} or {STEM_SCHEMA}"
        )
    if not artifacts:
        raise PCMComparisonError(f"{label} contains no PCM artifacts")
    return domain, artifacts


def read_wav_header(handle: Any, path: Path) -> tuple[int, int, int, int, bytes]:
    header = handle.read(44)
    if len(header) != 44 or header[0:4] != b"RIFF" or header[8:12] != b"WAVE":
        raise PCMComparisonError(f"{path} is not a canonical WAV")
    if header[12:16] != b"fmt " or struct.unpack_from("<I", header, 16)[0] != 16:
        raise PCMComparisonError(f"{path} must use a 16-byte fmt chunk")
    audio_format, channels = struct.unpack_from("<HH", header, 20)
    sample_rate = struct.unpack_from("<I", header, 24)[0]
    byte_rate, block_align, bits = struct.unpack_from("<IHH", header, 28)
    if audio_format != 3 or channels not in {1, 2} or bits != 32:
        raise PCMComparisonError(
            f"{path} must be mono/stereo 32-bit IEEE-float WAV"
        )
    if block_align != channels * 4 or byte_rate != sample_rate * block_align:
        raise PCMComparisonError(f"{path} has inconsistent byte geometry")
    if header[36:40] != b"data":
        raise PCMComparisonError(f"{path} must place data immediately after fmt")
    data_size = struct.unpack_from("<I", header, 40)[0]
    if data_size % block_align:
        raise PCMComparisonError(f"{path} has a partial PCM frame")
    try:
        file_size = path.stat().st_size
    except OSError as exc:
        raise PCMComparisonError(f"cannot stat WAV {path}: {exc}") from exc
    if struct.unpack_from("<I", header, 4)[0] != file_size - 8:
        raise PCMComparisonError(f"{path} has inconsistent RIFF size")
    if data_size != file_size - 44:
        raise PCMComparisonError(f"{path} has inconsistent PCM size")
    return sample_rate, channels, data_size // block_align, data_size, header


def float_array(chunk: bytes) -> array[float]:
    values = array("f")
    values.frombytes(chunk)
    if sys.byteorder != "little":
        values.byteswap()
    return values


def uint32_array(chunk: bytes) -> array[int]:
    values = array("I")
    values.frombytes(chunk)
    if sys.byteorder != "little":
        values.byteswap()
    return values


def scan_artifact(
    artifact: Artifact, cache: dict[Path, ScannedWav]
) -> ScannedWav:
    cached = cache.get(artifact.path)
    if cached is not None:
        scanned = cached
    else:
        wav_digest = hashlib.sha256()
        pcm_digest = hashlib.sha256()
        try:
            with artifact.path.open("rb") as handle:
                sample_rate, channels, frames, remaining, header = read_wav_header(
                    handle, artifact.path
                )
                wav_digest.update(header)
                while remaining:
                    chunk = handle.read(min(READ_SIZE, remaining))
                    if not chunk:
                        raise PCMComparisonError(
                            f"{artifact.path} ended before its declared PCM payload"
                        )
                    remaining -= len(chunk)
                    wav_digest.update(chunk)
                    pcm_digest.update(chunk)
                    if any(not math.isfinite(value) for value in float_array(chunk)):
                        raise PCMComparisonError(
                            f"{artifact.path} contains non-finite PCM"
                        )
        except OSError as exc:
            raise PCMComparisonError(f"cannot read WAV {artifact.path}: {exc}") from exc
        scanned = ScannedWav(
            sample_rate=sample_rate,
            channel_count=channels,
            frame_count=frames,
            sample_count=frames * channels,
            pcm_sha256=pcm_digest.hexdigest(),
            wav_sha256=wav_digest.hexdigest(),
        )
        cache[artifact.path] = scanned
    actual_geometry = (
        scanned.sample_rate,
        scanned.channel_count,
        scanned.frame_count,
    )
    expected_geometry = (
        artifact.sample_rate,
        artifact.channel_count,
        artifact.frame_count,
    )
    if actual_geometry != expected_geometry:
        raise PCMComparisonError(
            f"{artifact.identifier} WAV geometry {actual_geometry} does not match "
            f"manifest {expected_geometry}"
        )
    if scanned.pcm_sha256 != artifact.expected_pcm_sha256:
        raise PCMComparisonError(
            f"{artifact.identifier} pcmSha256 does not match its WAV"
        )
    if scanned.wav_sha256 != artifact.expected_wav_sha256:
        raise PCMComparisonError(
            f"{artifact.identifier} wavSha256 does not match its file"
        )
    return scanned


def compare_artifacts(
    baseline: Artifact,
    candidate: Artifact,
    baseline_scan: ScannedWav,
    candidate_scan: ScannedWav,
    absolute_tolerance: float,
    rms_tolerance: float,
) -> NumericComparison:
    sample_count = baseline_scan.sample_count
    if baseline_scan.pcm_sha256 == candidate_scan.pcm_sha256:
        report = {
            "assetId": baseline.identifier,
            "entryId": baseline.entry_id,
            "signal": baseline.signal,
            "classification": "exact",
            "sampleRate": baseline.sample_rate,
            "channelCount": baseline.channel_count,
            "frameCount": baseline.frame_count,
            "sampleCount": sample_count,
            "changedSampleCount": 0,
            "firstChangedFrame": None,
            "firstChangedChannel": None,
            "maximumAbsoluteError": 0.0,
            "rmsError": 0.0,
            "baselinePcmSha256": baseline_scan.pcm_sha256,
            "candidatePcmSha256": candidate_scan.pcm_sha256,
        }
        return NumericComparison(report=report, squared_error_sum=0.0)

    changed = 0
    first_changed_sample: Optional[int] = None
    maximum_error = 0.0
    squared = KahanSum()
    sample_offset = 0
    try:
        with baseline.path.open("rb") as baseline_handle, candidate.path.open(
            "rb"
        ) as candidate_handle:
            read_wav_header(baseline_handle, baseline.path)
            read_wav_header(candidate_handle, candidate.path)
            remaining = sample_count * 4
            while remaining:
                size = min(READ_SIZE, remaining)
                baseline_chunk = baseline_handle.read(size)
                candidate_chunk = candidate_handle.read(size)
                if len(baseline_chunk) != size or len(candidate_chunk) != size:
                    raise PCMComparisonError("PCM changed while comparison was running")
                remaining -= size
                chunk_samples = size // 4
                if baseline_chunk == candidate_chunk:
                    sample_offset += chunk_samples
                    continue
                baseline_bits = uint32_array(baseline_chunk)
                candidate_bits = uint32_array(candidate_chunk)
                baseline_values = float_array(baseline_chunk)
                candidate_values = float_array(candidate_chunk)
                for index, (base_bits, cand_bits, base, cand) in enumerate(
                    zip(
                        baseline_bits,
                        candidate_bits,
                        baseline_values,
                        candidate_values,
                    )
                ):
                    if base_bits != cand_bits:
                        changed += 1
                        if first_changed_sample is None:
                            first_changed_sample = sample_offset + index
                    error = abs(float(cand) - float(base))
                    maximum_error = max(maximum_error, error)
                    squared.add(error * error)
                sample_offset += chunk_samples
    except OSError as exc:
        raise PCMComparisonError(f"cannot compare WAV payloads: {exc}") from exc
    rms_error = math.sqrt(squared.total / sample_count) if sample_count else 0.0
    classification = (
        "bounded"
        if maximum_error <= absolute_tolerance and rms_error <= rms_tolerance
        else "material"
    )
    report = {
        "assetId": baseline.identifier,
        "entryId": baseline.entry_id,
        "signal": baseline.signal,
        "classification": classification,
        "sampleRate": baseline.sample_rate,
        "channelCount": baseline.channel_count,
        "frameCount": baseline.frame_count,
        "sampleCount": sample_count,
        "changedSampleCount": changed,
        "firstChangedFrame": (
            first_changed_sample // baseline.channel_count
            if first_changed_sample is not None
            else None
        ),
        "firstChangedChannel": (
            first_changed_sample % baseline.channel_count
            if first_changed_sample is not None
            else None
        ),
        "maximumAbsoluteError": maximum_error,
        "rmsError": rms_error,
        "baselinePcmSha256": baseline_scan.pcm_sha256,
        "candidatePcmSha256": candidate_scan.pcm_sha256,
    }
    return NumericComparison(report=report, squared_error_sum=squared.total)


def structural_issues(
    baseline_domain: str,
    candidate_domain: str,
    baseline: Mapping[str, Artifact],
    candidate: Mapping[str, Artifact],
) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    if baseline_domain != candidate_domain:
        issues.append({
            "code": "manifest-domain-mismatch",
            "assetId": None,
            "baseline": baseline_domain,
            "candidate": candidate_domain,
        })
    for identifier in sorted(set(baseline) - set(candidate)):
        issues.append({
            "code": "missing-candidate-asset",
            "assetId": identifier,
            "baseline": "present",
            "candidate": "missing",
        })
    for identifier in sorted(set(candidate) - set(baseline)):
        issues.append({
            "code": "unexpected-candidate-asset",
            "assetId": identifier,
            "baseline": "missing",
            "candidate": "present",
        })
    for identifier in sorted(set(baseline) & set(candidate)):
        base = baseline[identifier]
        cand = candidate[identifier]
        for code, base_value, candidate_value in (
            ("sample-rate-mismatch", base.sample_rate, cand.sample_rate),
            ("channel-count-mismatch", base.channel_count, cand.channel_count),
            ("frame-count-mismatch", base.frame_count, cand.frame_count),
        ):
            if base_value != candidate_value:
                issues.append({
                    "code": code,
                    "assetId": identifier,
                    "baseline": base_value,
                    "candidate": candidate_value,
                })
    return issues


def pcm_set_fingerprint(
    artifacts: Mapping[str, Artifact], scans: Mapping[str, ScannedWav]
) -> str:
    digest = hashlib.sha256()
    for identifier in sorted(artifacts):
        digest.update(identifier.encode("utf-8"))
        digest.update(b"\0")
        digest.update(scans[identifier].pcm_sha256.encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def input_report(
    manifest: Mapping[str, Any],
    manifest_path: Path,
    root: Path,
    domain: str,
    artifacts: Mapping[str, Artifact],
    scans: Mapping[str, ScannedWav],
) -> dict[str, Any]:
    return {
        "manifestPath": normalized_relative_path(root, manifest_path, "manifest"),
        "manifestSha256": sha256(manifest_path),
        "manifestSchema": manifest.get("schema"),
        "domain": domain,
        "sourceFingerprint": manifest.get("sourceFingerprint"),
        "gitHead": manifest.get("gitHead"),
        "engineVersion": manifest.get("engineVersion"),
        "contractBaselineFingerprint": manifest.get("contractBaselineFingerprint"),
        "assetCount": len(artifacts),
        "pcmSetFingerprint": pcm_set_fingerprint(artifacts, scans),
    }


def build_report(
    baseline_manifest_path: Path,
    candidate_manifest_path: Path,
    baseline_root: Path,
    candidate_root: Path,
    absolute_tolerance: float = DEFAULT_ABSOLUTE_TOLERANCE,
    rms_tolerance: float = DEFAULT_RMS_TOLERANCE,
) -> dict[str, Any]:
    absolute_tolerance = checked_nonnegative_float(
        absolute_tolerance, "absolute tolerance"
    )
    rms_tolerance = checked_nonnegative_float(rms_tolerance, "RMS tolerance")
    baseline_root = baseline_root.resolve()
    candidate_root = candidate_root.resolve()
    baseline_manifest_path = baseline_manifest_path.resolve()
    candidate_manifest_path = candidate_manifest_path.resolve()
    normalized_relative_path(baseline_root, baseline_manifest_path, "baseline manifest")
    normalized_relative_path(candidate_root, candidate_manifest_path, "candidate manifest")
    baseline_manifest = load_json(baseline_manifest_path, "baseline manifest")
    candidate_manifest = load_json(candidate_manifest_path, "candidate manifest")
    baseline_domain, baseline_artifacts = extract_artifacts(
        baseline_manifest, baseline_root, "baseline"
    )
    candidate_domain, candidate_artifacts = extract_artifacts(
        candidate_manifest, candidate_root, "candidate"
    )

    cache: dict[Path, ScannedWav] = {}
    baseline_scans = {
        identifier: scan_artifact(artifact, cache)
        for identifier, artifact in sorted(baseline_artifacts.items())
    }
    candidate_scans = {
        identifier: scan_artifact(artifact, cache)
        for identifier, artifact in sorted(candidate_artifacts.items())
    }
    issues = structural_issues(
        baseline_domain,
        candidate_domain,
        baseline_artifacts,
        candidate_artifacts,
    )
    incompatible_assets = {
        issue["assetId"]
        for issue in issues
        if issue["assetId"] is not None
        and issue["code"].endswith("-mismatch")
    }
    comparisons: list[NumericComparison] = []
    if baseline_domain == candidate_domain:
        for identifier in sorted(set(baseline_artifacts) & set(candidate_artifacts)):
            if identifier in incompatible_assets:
                continue
            comparisons.append(compare_artifacts(
                baseline_artifacts[identifier],
                candidate_artifacts[identifier],
                baseline_scans[identifier],
                candidate_scans[identifier],
                absolute_tolerance,
                rms_tolerance,
            ))
    asset_reports = [dict(comparison.report) for comparison in comparisons]
    exact_count = sum(item["classification"] == "exact" for item in asset_reports)
    bounded_count = sum(item["classification"] == "bounded" for item in asset_reports)
    material_count = sum(item["classification"] == "material" for item in asset_reports)
    sample_count = sum(item["sampleCount"] for item in asset_reports)
    changed_count = sum(item["changedSampleCount"] for item in asset_reports)
    squared_total = math.fsum(
        comparison.squared_error_sum for comparison in comparisons
    )
    maximum_error = max(
        (item["maximumAbsoluteError"] for item in asset_reports), default=0.0
    )
    aggregate_rms = math.sqrt(squared_total / sample_count) if sample_count else 0.0
    if issues:
        classification = "incompatible"
    elif material_count:
        classification = "material"
    elif bounded_count:
        classification = "bounded"
    else:
        classification = "exact"
    report: dict[str, Any] = {
        "schema": REPORT_SCHEMA,
        "reportVersion": 1,
        "comparatorVersion": COMPARATOR_VERSION,
        "thresholds": {
            "absoluteSampleError": absolute_tolerance,
            "rmsError": rms_tolerance,
        },
        "baseline": input_report(
            baseline_manifest,
            baseline_manifest_path,
            baseline_root,
            baseline_domain,
            baseline_artifacts,
            baseline_scans,
        ),
        "candidate": input_report(
            candidate_manifest,
            candidate_manifest_path,
            candidate_root,
            candidate_domain,
            candidate_artifacts,
            candidate_scans,
        ),
        "classification": classification,
        "structuralIssues": issues,
        "summary": {
            "assetCountCompared": len(asset_reports),
            "exactAssetCount": exact_count,
            "boundedAssetCount": bounded_count,
            "materialAssetCount": material_count,
            "sampleCount": sample_count,
            "changedSampleCount": changed_count,
            "maximumAbsoluteError": maximum_error,
            "rmsError": aggregate_rms,
        },
        "assets": asset_reports,
    }
    report["reportFingerprint"] = hashlib.sha256(canonical_bytes(report)).hexdigest()
    return report


def write_report(path: Path, report: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def run_compare(
    baseline_manifest: Path,
    candidate_manifest: Path,
    baseline_root: Path,
    candidate_root: Path,
    output_path: Path,
    absolute_tolerance: float,
    rms_tolerance: float,
    output: TextIO = sys.stdout,
) -> int:
    try:
        report = build_report(
            baseline_manifest,
            candidate_manifest,
            baseline_root,
            candidate_root,
            absolute_tolerance,
            rms_tolerance,
        )
        write_report(output_path, report)
    except (OSError, PCMComparisonError, ValueError) as exc:
        print(f"PCM comparison rejected: {exc}", file=output)
        return 1
    print(
        f"PCM comparison {report['classification']}: "
        f"{report['summary']['assetCountCompared']} assets, "
        f"{report['summary']['changedSampleCount']} changed samples; "
        f"wrote {output_path}",
        file=output,
    )
    return 0


def run_check(
    report_path: Path,
    baseline_root: Path,
    candidate_root: Path,
    output: TextIO = sys.stdout,
) -> int:
    try:
        actual = load_json(report_path, "comparison report")
        if actual.get("schema") != REPORT_SCHEMA:
            raise PCMComparisonError(f"report schema must be {REPORT_SCHEMA}")
        thresholds = actual.get("thresholds")
        baseline = actual.get("baseline")
        candidate = actual.get("candidate")
        if not isinstance(thresholds, dict):
            raise PCMComparisonError("report.thresholds must be an object")
        if not isinstance(baseline, dict) or not isinstance(candidate, dict):
            raise PCMComparisonError("report inputs must be objects")
        baseline_manifest = resolve_local_path(
            baseline_root.resolve(), baseline.get("manifestPath"),
            "report.baseline.manifestPath"
        )
        candidate_manifest = resolve_local_path(
            candidate_root.resolve(), candidate.get("manifestPath"),
            "report.candidate.manifestPath"
        )
        expected = build_report(
            baseline_manifest,
            candidate_manifest,
            baseline_root,
            candidate_root,
            checked_nonnegative_float(
                thresholds.get("absoluteSampleError"),
                "report.thresholds.absoluteSampleError",
            ),
            checked_nonnegative_float(
                thresholds.get("rmsError"), "report.thresholds.rmsError"
            ),
        )
        if actual != expected:
            raise PCMComparisonError(
                "report is stale, mutated, or not canonical for its current inputs"
            )
    except (OSError, PCMComparisonError, ValueError) as exc:
        print(f"PCM comparison report rejected: {exc}", file=output)
        return 1
    print(
        f"PCM comparison report is current: {actual['classification']}, "
        f"{actual['summary']['assetCountCompared']} assets",
        file=output,
    )
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    compare = subparsers.add_parser("compare")
    compare.add_argument("--baseline-manifest", type=Path, required=True)
    compare.add_argument("--candidate-manifest", type=Path, required=True)
    compare.add_argument("--baseline-root", type=Path, default=repository_root())
    compare.add_argument("--candidate-root", type=Path, default=repository_root())
    compare.add_argument("--output", type=Path, required=True)
    compare.add_argument(
        "--absolute-tolerance", type=float, default=DEFAULT_ABSOLUTE_TOLERANCE
    )
    compare.add_argument("--rms-tolerance", type=float, default=DEFAULT_RMS_TOLERANCE)
    check = subparsers.add_parser("check")
    check.add_argument("--report", type=Path, required=True)
    check.add_argument("--baseline-root", type=Path, default=repository_root())
    check.add_argument("--candidate-root", type=Path, default=repository_root())
    arguments = parser.parse_args(argv)
    if arguments.command == "compare":
        return run_compare(
            arguments.baseline_manifest,
            arguments.candidate_manifest,
            arguments.baseline_root,
            arguments.candidate_root,
            arguments.output,
            arguments.absolute_tolerance,
            arguments.rms_tolerance,
        )
    return run_check(
        arguments.report,
        arguments.baseline_root,
        arguments.candidate_root,
    )


if __name__ == "__main__":
    raise SystemExit(main())
