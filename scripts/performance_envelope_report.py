#!/usr/bin/env python3
"""Verify and summarize the local release performance envelope."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import subprocess
import sys
from typing import Any, Iterable, Mapping, Optional, Sequence
import xml.etree.ElementTree as ET


RAW_SCHEMA = "autotechno-performance-envelope-observations.v1"
REPORT_SCHEMA = "autotechno-performance-envelope-report.v1"
CORPUS_SCHEMA = "autotechno-baseline-corpus.v1"
DEFAULT_RAW = Path(
    "docs/local/reports/performance-envelope-v1/raw-observations.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/performance-envelope-v1/report.json"
)
DEFAULT_MARKDOWN = Path("docs/PERFORMANCE_ENVELOPE.md")
TRACE_FILENAMES = {
    "toc": "live-toc.xml",
    "clientCycles": "live-audio-hal-client-io-cycle.xml",
    "deviceCycles": "live-audio-hal-io-cycle.xml",
    "clientPoints": "live-audio-hal-client-poi.xml",
    "devicePoints": "live-audio-hal-poi.xml",
}
MAXIMUM_PREPARATION_BYTES = 128 * 1_024 * 1_024
EXPECTED_SAMPLE_RATES = (44_100, 48_000)
EXPECTED_FRAME_COUNTS = (128, 256, 512, 1_024)
MEASUREMENT_CASE_ID = "ATBC-V1-002-CONTRAST"
TIMING_FIELDS = (
    "planningNanoseconds",
    "renderEvaluationNanoseconds",
    "longHorizonNanoseconds",
    "presentationNanoseconds",
    "completePreparationNanoseconds",
)
RAW_KEYS = {
    "schema", "observationVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "buildConfiguration", "clock", "memory", "machine",
    "trialPolicy", "preparationObservations", "producerObservations",
}
PREPARATION_KEYS = {
    "id", "caseId", "routeId", "rootSeed", "checkpoint",
    "continuationClass", "trialIndex", "phraseIndex", "startBar",
    "barCount", "frameCount", "sampleRate", "channelCount",
    "renderPassCount", "planningNanoseconds",
    "renderEvaluationNanoseconds", "longHorizonNanoseconds",
    "longHorizonUpdateAvailable",
    "presentationNanoseconds", "completePreparationNanoseconds",
    "audioDurationNanoseconds", "calculatedPeakWorkingBytes",
    "calculatedMaximumPeakWorkingBytes", "processHighWaterBytesBefore",
    "processHighWaterBytesAfter", "planFingerprint", "replayFingerprint",
    "directSampleHash", "completeSampleHash", "directEvaluationFingerprint",
    "completeEvaluationFingerprint", "exactIdentityMatch",
}
PRODUCER_KEYS = {
    "id", "frameCount", "trialIndex", "operationCount",
    "batchNanoseconds", "droppedPacketDelta", "rejectedPacketDelta",
    "exactRoundTrip",
}


class PerformanceEnvelopeError(RuntimeError):
    """An actionable raw-observation, trace, or report failure."""


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
        raise PerformanceEnvelopeError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PerformanceEnvelopeError(f"cannot read {label} at {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PerformanceEnvelopeError(f"{label} must be an object")
    return value


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> None:
    missing = sorted(expected - set(value))
    unknown = sorted(set(value) - expected)
    if missing or unknown:
        details = []
        if missing:
            details.append("missing " + ", ".join(missing))
        if unknown:
            details.append("unknown " + ", ".join(unknown))
        raise PerformanceEnvelopeError(
            f"{location} has invalid fields: {'; '.join(details)}"
        )


def sequence(value: object, location: str) -> list[Any]:
    if not isinstance(value, list):
        raise PerformanceEnvelopeError(f"{location} must be an array")
    return value


def mapping(value: object, location: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise PerformanceEnvelopeError(f"{location} must be an object")
    return value


def text(value: object, location: str) -> str:
    if not isinstance(value, str) or not value:
        raise PerformanceEnvelopeError(f"{location} must be nonempty text")
    return value


def integer(value: object, location: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise PerformanceEnvelopeError(
            f"{location} must be an integer >= {minimum}"
        )
    return value


def boolean(value: object, location: str) -> bool:
    if not isinstance(value, bool):
        raise PerformanceEnvelopeError(f"{location} must be boolean")
    return value


def git_output(root: Path, arguments: list[str]) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), *arguments],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise PerformanceEnvelopeError(f"git {' '.join(arguments)} failed") from exc
    return result.stdout


def source_fingerprint(root: Path) -> str:
    paths = sorted(filter(None, git_output(root, [
        "ls-files", "--cached", "--others", "--exclude-standard", "--",
        "Package.swift", "Sources", "Tests", "scripts",
        "docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json",
    ]).splitlines()))
    digest = hashlib.sha256()
    for relative in paths:
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        try:
            digest.update((root / relative).read_bytes())
        except OSError as exc:
            raise PerformanceEnvelopeError(
                f"cannot fingerprint source {relative}: {exc}"
            ) from exc
    return digest.hexdigest()


def nearest_rank(values: Iterable[int], quantile: float) -> int:
    ordered = sorted(values)
    if not ordered:
        raise PerformanceEnvelopeError("cannot aggregate an empty timing family")
    index = max(0, math.ceil(quantile * len(ordered)) - 1)
    return ordered[index]


def timing_summary(values: Iterable[int]) -> dict[str, int]:
    ordered = sorted(values)
    return {
        "minimum": ordered[0],
        "p50": nearest_rank(ordered, 0.50),
        "p95": nearest_rank(ordered, 0.95),
        "maximum": ordered[-1],
    }


def relative_path(root: Path, path: Path) -> str:
    try:
        relative = path.resolve().relative_to(root.resolve())
    except ValueError as exc:
        raise PerformanceEnvelopeError(f"artifact escapes repository: {path}") from exc
    pure = PurePosixPath(relative.as_posix())
    if "." in pure.parts or ".." in pure.parts:
        raise PerformanceEnvelopeError(f"artifact path is not normalized: {path}")
    return pure.as_posix()


def validate_machine(value: object) -> dict[str, Any]:
    machine = mapping(value, "raw.machine")
    exact_keys(machine, {
        "operatingSystem", "operatingSystemVersion", "hardwareModel",
        "processor", "activeProcessorCount", "physicalMemoryBytes",
        "lowPowerModeEnabled", "thermalState",
    }, "raw.machine")
    for field in (
        "operatingSystem", "operatingSystemVersion", "hardwareModel",
        "processor", "thermalState",
    ):
        text(machine[field], f"raw.machine.{field}")
    if machine["operatingSystem"] != "macOS":
        raise PerformanceEnvelopeError("raw.machine.operatingSystem must be macOS")
    integer(machine["activeProcessorCount"], "raw.machine.activeProcessorCount", 1)
    integer(machine["physicalMemoryBytes"], "raw.machine.physicalMemoryBytes", 1)
    boolean(machine["lowPowerModeEnabled"], "raw.machine.lowPowerModeEnabled")
    return machine


def validate_raw(
    raw: Mapping[str, Any], corpus: Mapping[str, Any], root: Path
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    exact_keys(raw, RAW_KEYS, "raw")
    if raw.get("schema") != RAW_SCHEMA or raw.get("observationVersion") != 1:
        raise PerformanceEnvelopeError("raw schema/version is not v1")
    if raw.get("buildConfiguration") != "release":
        raise PerformanceEnvelopeError("performance observations must be release-build")
    for field in (
        "corpusSha256", "contractBaselineFingerprint", "sourceFingerprint",
        "gitHead", "engineVersion",
    ):
        text(raw.get(field), f"raw.{field}")

    corpus_path = root / "docs/BASELINE_CORPUS.json"
    if raw["corpusSha256"] != sha256_path(corpus_path):
        raise PerformanceEnvelopeError("raw corpus fingerprint is stale")
    baseline = load_json(
        root / "docs/ROADMAP_EXECUTION_BASELINE.json", "roadmap baseline"
    )
    if raw["contractBaselineFingerprint"] != baseline.get("snapshotFingerprint"):
        raise PerformanceEnvelopeError("raw contract-baseline fingerprint is stale")
    if raw["sourceFingerprint"] != source_fingerprint(root):
        raise PerformanceEnvelopeError("raw source fingerprint is stale")

    clock = mapping(raw.get("clock"), "raw.clock")
    exact_keys(clock, {"kind", "unit", "samplingLocation"}, "raw.clock")
    if clock != {
        "kind": "dispatch-uptime-monotonic",
        "unit": "nanoseconds",
        "samplingLocation": "detached-test-process",
    }:
        raise PerformanceEnvelopeError("raw clock identity is not canonical")
    memory = mapping(raw.get("memory"), "raw.memory")
    exact_keys(memory, {"kind", "unit", "scope", "attribution"}, "raw.memory")
    if memory != {
        "kind": "getrusage-ru_maxrss",
        "unit": "bytes",
        "scope": "whole-test-process-high-water",
        "attribution": "monotonic-process-bound-not-phase-exclusive",
    }:
        raise PerformanceEnvelopeError("raw memory identity is not canonical")
    machine = validate_machine(raw.get("machine"))

    policy = mapping(raw.get("trialPolicy"), "raw.trialPolicy")
    exact_keys(policy, {
        "preparationWarmupCount", "preparationTimedTrialCount",
        "producerWarmupBatchCount", "producerTimedTrialCount",
        "producerOperationsPerBatch", "producerFrameCounts",
        "measurementCaseId", "selectionRule", "ordering",
    }, "raw.trialPolicy")
    expected_policy = {
        "preparationWarmupCount": 1,
        "preparationTimedTrialCount": 3,
        "producerWarmupBatchCount": 2,
        "producerTimedTrialCount": 9,
        "producerOperationsPerBatch": 128,
        "producerFrameCounts": list(EXPECTED_FRAME_COUNTS),
        "measurementCaseId": MEASUREMENT_CASE_ID,
        "selectionRule": "largest-existing-baseline-frame-count",
        "ordering": "case-route-trial-ascending",
    }
    if policy != expected_policy:
        raise PerformanceEnvelopeError("raw trial policy is not canonical")

    cases = sequence(corpus.get("cases"), "corpus.cases")
    routes = sequence(corpus.get("routes"), "corpus.routes")
    case_by_id = {
        text(mapping(case, "corpus.case").get("id"), "corpus.case.id"): case
        for case in cases
    }
    route_by_id = {
        text(mapping(route, "corpus.route").get("id"), "corpus.route.id"): route
        for route in routes
    }
    if tuple(sorted(route["sampleRate"] for route in routes)) != EXPECTED_SAMPLE_RATES:
        raise PerformanceEnvelopeError("corpus route rates are not 44.1/48 kHz")

    preparation_values = sequence(
        raw.get("preparationObservations"), "raw.preparationObservations"
    )
    preparation: list[dict[str, Any]] = []
    seen_preparation: set[tuple[str, str, int]] = set()
    prior_high_water = 0
    for index, item in enumerate(preparation_values):
        location = f"raw.preparationObservations[{index}]"
        observation = mapping(item, location)
        exact_keys(observation, PREPARATION_KEYS, location)
        case_id = text(observation.get("caseId"), location + ".caseId")
        route_id = text(observation.get("routeId"), location + ".routeId")
        if case_id not in case_by_id or route_id not in route_by_id:
            raise PerformanceEnvelopeError(f"{location} is outside the corpus")
        fixture = case_by_id[case_id]
        route = route_by_id[route_id]
        trial = integer(observation.get("trialIndex"), location + ".trialIndex")
        key = (case_id, route_id, trial)
        if key in seen_preparation:
            raise PerformanceEnvelopeError(f"duplicate preparation observation {key}")
        seen_preparation.add(key)
        expected_id = f"{case_id}--{route_id}--trial-{trial}"
        if observation.get("id") != expected_id:
            raise PerformanceEnvelopeError(f"{location}.id must be {expected_id}")
        for field in ("rootSeed", "checkpoint", "continuationClass"):
            if observation.get(field) != fixture.get(field):
                raise PerformanceEnvelopeError(f"{location}.{field} mismatches corpus")
        for field in ("sampleRate", "channelCount"):
            if observation.get(field) != route.get(field):
                raise PerformanceEnvelopeError(f"{location}.{field} mismatches route")
        sample_rate = integer(observation["sampleRate"], location + ".sampleRate", 1)
        bar_count = integer(observation.get("barCount"), location + ".barCount", 1)
        frame_count = integer(observation.get("frameCount"), location + ".frameCount", 1)
        frames_per_bar = round(240.0 / 130.0 * sample_rate)
        if frame_count != bar_count * frames_per_bar:
            raise PerformanceEnvelopeError(f"{location}.frameCount is inconsistent")
        expected_audio_ns = round(frame_count / sample_rate * 1_000_000_000)
        if observation.get("audioDurationNanoseconds") != expected_audio_ns:
            raise PerformanceEnvelopeError(
                f"{location}.audioDurationNanoseconds is inconsistent"
            )
        for field in TIMING_FIELDS:
            integer(observation.get(field), location + "." + field, 1)
        boolean(
            observation.get("longHorizonUpdateAvailable"),
            location + ".longHorizonUpdateAvailable",
        )
        render_passes = integer(
            observation.get("renderPassCount"), location + ".renderPassCount", 1
        )
        if render_passes > 2:
            raise PerformanceEnvelopeError(f"{location}.renderPassCount exceeds two")
        calculated = integer(
            observation.get("calculatedPeakWorkingBytes"),
            location + ".calculatedPeakWorkingBytes", 1,
        )
        maximum = integer(
            observation.get("calculatedMaximumPeakWorkingBytes"),
            location + ".calculatedMaximumPeakWorkingBytes", 1,
        )
        if calculated > maximum or maximum > MAXIMUM_PREPARATION_BYTES:
            raise PerformanceEnvelopeError(f"{location} exceeds calculated memory bound")
        before = integer(
            observation.get("processHighWaterBytesBefore"),
            location + ".processHighWaterBytesBefore", 1,
        )
        after = integer(
            observation.get("processHighWaterBytesAfter"),
            location + ".processHighWaterBytesAfter", 1,
        )
        if after < before or before < prior_high_water:
            raise PerformanceEnvelopeError(f"{location} high-water is non-monotonic")
        if after > machine["physicalMemoryBytes"]:
            raise PerformanceEnvelopeError(f"{location} high-water exceeds physical memory")
        prior_high_water = after
        if not boolean(
            observation.get("exactIdentityMatch"), location + ".exactIdentityMatch"
        ):
            raise PerformanceEnvelopeError(f"{location} changed canonical identity")
        identity_pairs = (
            ("directSampleHash", "completeSampleHash"),
            ("directEvaluationFingerprint", "completeEvaluationFingerprint"),
        )
        for left, right in identity_pairs:
            if text(observation.get(left), location + "." + left) != text(
                observation.get(right), location + "." + right
            ):
                raise PerformanceEnvelopeError(f"{location} identity pair differs")
        for field in ("planFingerprint", "replayFingerprint"):
            text(observation.get(field), location + "." + field)
        preparation.append(observation)

    expected_preparation = {
        (case_id, route_id, trial)
        for case_id in (MEASUREMENT_CASE_ID,)
        for route_id in route_by_id
        for trial in range(3)
    }
    if seen_preparation != expected_preparation:
        raise PerformanceEnvelopeError(
            "preparation observations do not cover the selected 1x2x3 matrix"
        )

    producer_values = sequence(
        raw.get("producerObservations"), "raw.producerObservations"
    )
    producer: list[dict[str, Any]] = []
    seen_producer: set[tuple[int, int]] = set()
    for index, item in enumerate(producer_values):
        location = f"raw.producerObservations[{index}]"
        observation = mapping(item, location)
        exact_keys(observation, PRODUCER_KEYS, location)
        frame_count = integer(observation.get("frameCount"), location + ".frameCount", 1)
        trial = integer(observation.get("trialIndex"), location + ".trialIndex")
        key = (frame_count, trial)
        if key in seen_producer:
            raise PerformanceEnvelopeError(f"duplicate producer observation {key}")
        seen_producer.add(key)
        if observation.get("id") != f"native-stereo-{frame_count}--trial-{trial}":
            raise PerformanceEnvelopeError(f"{location}.id is not canonical")
        if observation.get("operationCount") != 128:
            raise PerformanceEnvelopeError(f"{location}.operationCount must be 128")
        integer(observation.get("batchNanoseconds"), location + ".batchNanoseconds", 1)
        if observation.get("droppedPacketDelta") != 0 or \
                observation.get("rejectedPacketDelta") != 0:
            raise PerformanceEnvelopeError(f"{location} observed queue loss/rejection")
        if not boolean(observation.get("exactRoundTrip"), location + ".exactRoundTrip"):
            raise PerformanceEnvelopeError(f"{location} failed exact round trip")
        producer.append(observation)
    expected_producer = {
        (frame_count, trial)
        for frame_count in EXPECTED_FRAME_COUNTS
        for trial in range(9)
    }
    if seen_producer != expected_producer:
        raise PerformanceEnvelopeError("producer observations do not cover 4x9")
    return preparation, producer


class XctraceTable:
    def __init__(self, path: Path) -> None:
        try:
            self.root = ET.parse(path).getroot()
        except (OSError, ET.ParseError) as exc:
            raise PerformanceEnvelopeError(f"cannot parse xctrace export {path}: {exc}") from exc
        schema = self.root.find(".//schema")
        if schema is None or not schema.get("name"):
            raise PerformanceEnvelopeError(f"xctrace export has no schema: {path}")
        self.schema = str(schema.get("name"))
        self.rows = self.root.findall(".//row")
        self.identities: dict[str, ET.Element] = {}
        for element in self.root.iter():
            identity = element.get("id")
            if identity:
                self.identities[identity] = element

    def element(self, row: ET.Element, tag: str) -> Optional[ET.Element]:
        element = row.find(tag)
        seen: set[str] = set()
        while element is not None and element.get("ref"):
            reference = str(element.get("ref"))
            if reference in seen:
                raise PerformanceEnvelopeError("cyclic xctrace reference")
            seen.add(reference)
            element = self.identities.get(reference)
        return element

    def integer(self, row: ET.Element, tag: str) -> Optional[int]:
        element = self.element(row, tag)
        if element is None or element.text is None:
            return None
        try:
            return int(element.text)
        except ValueError as exc:
            raise PerformanceEnvelopeError(
                f"xctrace {self.schema}.{tag} is not integer"
            ) from exc

    def formatted(self, row: ET.Element, tag: str) -> Optional[str]:
        element = self.element(row, tag)
        if element is None:
            return None
        return element.get("fmt") or element.text


def point_records(table: XctraceTable) -> list[dict[str, str]]:
    records = []
    for row in table.rows:
        records.append({
            "timestamp": table.formatted(row, "event-time") or "unavailable",
            "description": table.formatted(row, "narrative") or "unavailable",
            "concept": table.formatted(row, "event-concept") or "unavailable",
            "detail": table.formatted(row, "detail") or "unavailable",
        })
    return records


def trace_evidence(
    root: Path,
    trace_directory: Optional[Path],
    process_name: str,
    sample_rate: Optional[int],
    channel_count: Optional[int],
) -> dict[str, Any]:
    if trace_directory is None:
        return {
            "availability": "unavailable",
            "reason": "live-audio-system-trace-not-supplied",
            "measurementBoundary": "external-no-callback-instrumentation",
            "processName": process_name,
            "sampleRate": sample_rate,
            "channelCount": channel_count,
            "inputs": [],
        }
    if sample_rate not in EXPECTED_SAMPLE_RATES or channel_count != 2:
        raise PerformanceEnvelopeError(
            "live trace requires an exact 44.1/48 kHz native-stereo route"
        )
    paths = {name: trace_directory / filename for name, filename in TRACE_FILENAMES.items()}
    for name, path in paths.items():
        if not path.is_file():
            raise PerformanceEnvelopeError(f"live trace {name} export is missing: {path}")
    client = XctraceTable(paths["clientCycles"])
    device = XctraceTable(paths["deviceCycles"])
    client_points = XctraceTable(paths["clientPoints"])
    device_points = XctraceTable(paths["devicePoints"])
    expected_schemas = {
        client.schema: "audio-hal-client-io-cycle",
        device.schema: "audio-hal-io-cycle",
        client_points.schema: "audio-hal-client-poi",
        device_points.schema: "audio-hal-poi",
    }
    if any(actual != expected for actual, expected in expected_schemas.items()):
        raise PerformanceEnvelopeError("live xctrace export schema mismatch")

    callback_rows = []
    for row in client.rows:
        process = client.formatted(row, "process") or ""
        if process == process_name or process.startswith(process_name + " ("):
            callback_rows.append(row)
    callback_durations = [
        value for value in (client.integer(row, "duration") for row in callback_rows)
        if value is not None and value > 0
    ]
    if len(callback_durations) < 2:
        raise PerformanceEnvelopeError(
            f"live trace has fewer than two callback cycles for {process_name}"
        )
    callback_starts = [
        value for value in (client.integer(row, "start-time") for row in callback_rows)
        if value is not None
    ]
    callback_concepts = [
        client.formatted(row, "event-concept") or "unavailable"
        for row in callback_rows
    ]
    non_normal_callbacks = sum(value != "Normal" for value in callback_concepts)
    trace_duration = max(callback_starts) - min(callback_starts) if callback_starts else 0

    device_records: dict[str, dict[str, Any]] = {}
    for row in device.rows:
        frame_count = device.integer(row, "uint32")
        duration = device.integer(row, "duration")
        thread = device.formatted(row, "thread") or "unavailable"
        concept = device.formatted(row, "event-concept") or "unavailable"
        if frame_count is None or duration is None:
            continue
        record = device_records.setdefault(thread, {
            "thread": thread,
            "cycleCount": 0,
            "frameCounts": set(),
            "durations": [],
            "nonNormalCycleCount": 0,
        })
        record["cycleCount"] += 1
        record["frameCounts"].add(frame_count)
        record["durations"].append(duration)
        record["nonNormalCycleCount"] += concept != "Normal"
    devices = []
    for record in sorted(device_records.values(), key=lambda item: item["thread"]):
        devices.append({
            "thread": record["thread"],
            "cycleCount": record["cycleCount"],
            "frameCounts": sorted(record["frameCounts"]),
            "cycleDurationNanoseconds": timing_summary(record["durations"]),
            "nonNormalCycleCount": record["nonNormalCycleCount"],
        })
    if not devices:
        raise PerformanceEnvelopeError("live trace has no device I/O cycles")

    client_point_records = point_records(client_points)
    device_point_records = point_records(device_points)
    points = client_point_records + device_point_records
    relevant_tokens = (
        "underrun", "overload", "missed", "late", "discontinuity",
        "safety violation", "deadline",
    )
    relevant = [
        point for point in points
        if any(
            token in " ".join(point.values()).lower()
            for token in relevant_tokens
        )
    ]
    minimum_frame_count = min(
        frame_count for record in devices for frame_count in record["frameCounts"]
    )
    callback_budget_ns = round(minimum_frame_count / sample_rate * 1_000_000_000)
    callback_maximum = max(callback_durations)
    inputs = [{
        "kind": name,
        "path": relative_path(root, path),
        "sha256": sha256_path(path),
    } for name, path in sorted(paths.items())]
    return {
        "availability": "observed",
        "reason": "bounded-audio-system-trace",
        "measurementBoundary": "external-no-callback-instrumentation",
        "processName": process_name,
        "sampleRate": sample_rate,
        "channelCount": channel_count,
        "traceDurationNanoseconds": trace_duration,
        "callbackCycleCount": len(callback_durations),
        "callbackDurationNanoseconds": timing_summary(callback_durations),
        "minimumObservedFrameCount": minimum_frame_count,
        "minimumFrameCallbackBudgetNanoseconds": callback_budget_ns,
        "maximumCallbackToBudgetRatio": round(
            callback_maximum / callback_budget_ns, 9
        ),
        "nonNormalCallbackCycleCount": non_normal_callbacks,
        "devices": devices,
        "clientPointOfInterestCount": len(client_point_records),
        "devicePointOfInterestCount": len(device_point_records),
        "relevantDeadlinePointCount": len(relevant),
        "underrunEvidence": (
            "relevant-point-observed" if relevant
            else "no-relevant-point-observed-in-bounded-trace"
        ),
        "pointsOfInterest": points[:64],
        "inputs": inputs,
    }


def preparation_summaries(
    observations: Sequence[Mapping[str, Any]], routes: Sequence[Mapping[str, Any]]
) -> list[dict[str, Any]]:
    summaries = []
    for route in sorted(routes, key=lambda item: item["id"]):
        selected = [item for item in observations if item["routeId"] == route["id"]]
        audio_ratios = [
            item["completePreparationNanoseconds"] /
            item["audioDurationNanoseconds"]
            for item in selected
        ]
        lookahead_margins = [
            item["audioDurationNanoseconds"] -
            item["completePreparationNanoseconds"]
            for item in selected
        ]
        timings = {
            field: timing_summary(item[field] for item in selected)
            for field in TIMING_FIELDS
        }
        summaries.append({
            "routeId": route["id"],
            "sampleRate": route["sampleRate"],
            "channelCount": route["channelCount"],
            "caseCount": len({item["caseId"] for item in selected}),
            "trialCount": len(selected),
            "timings": timings,
            "completePreparationToAudioRatio": {
                "minimum": round(min(audio_ratios), 9),
                "p50": round(nearest_rank(
                    [round(value * 1_000_000_000) for value in audio_ratios], 0.50
                ) / 1_000_000_000, 9),
                "p95": round(nearest_rank(
                    [round(value * 1_000_000_000) for value in audio_ratios], 0.95
                ) / 1_000_000_000, 9),
                "maximum": round(max(audio_ratios), 9),
            },
            "minimumSuccessorLookaheadMarginNanoseconds": min(lookahead_margins),
            "processHighWaterBytesMaximum": max(
                item["processHighWaterBytesAfter"] for item in selected
            ),
            "calculatedPeakWorkingBytesMaximum": max(
                item["calculatedMaximumPeakWorkingBytes"] for item in selected
            ),
            "exactIdentityMatchCount": sum(
                bool(item["exactIdentityMatch"]) for item in selected
            ),
            "longHorizonUpdateAvailableCount": sum(
                bool(item["longHorizonUpdateAvailable"]) for item in selected
            ),
        })
    return summaries


def producer_summaries(
    observations: Sequence[Mapping[str, Any]]
) -> list[dict[str, Any]]:
    summaries = []
    for frame_count in EXPECTED_FRAME_COUNTS:
        selected = [item for item in observations if item["frameCount"] == frame_count]
        per_operation = [
            round(item["batchNanoseconds"] / item["operationCount"])
            for item in selected
        ]
        summaries.append({
            "frameCount": frame_count,
            "trialCount": len(selected),
            "operationsPerTrial": selected[0]["operationCount"],
            "producerNanosecondsPerOperation": timing_summary(per_operation),
            "droppedPacketDelta": sum(
                item["droppedPacketDelta"] for item in selected
            ),
            "rejectedPacketDelta": sum(
                item["rejectedPacketDelta"] for item in selected
            ),
            "exactRoundTripCount": sum(
                bool(item["exactRoundTrip"]) for item in selected
            ),
        })
    return summaries


def validate_measurement_selection(
    root: Path, routes: Sequence[Mapping[str, Any]]
) -> dict[str, str]:
    path = root / "docs/local/reports/baseline-corpus-v1/manifest.json"
    manifest = load_json(path, "baseline render manifest")
    entries = sequence(manifest.get("entries"), "baseline manifest.entries")
    for route in routes:
        selected = [
            mapping(item, "baseline manifest entry") for item in entries
            if isinstance(item, dict) and item.get("routeId") == route["id"]
        ]
        if not selected:
            raise PerformanceEnvelopeError(
                f"baseline manifest has no entries for {route['id']}"
            )
        maximum = max(
            integer(item.get("frameCount"), "baseline entry.frameCount", 1)
            for item in selected
        )
        maximum_cases = sorted(
            text(item.get("caseId"), "baseline entry.caseId")
            for item in selected if item.get("frameCount") == maximum
        )
        if maximum_cases != [MEASUREMENT_CASE_ID]:
            raise PerformanceEnvelopeError(
                f"measurement case is no longer the unique largest frame count for {route['id']}"
            )
    return {
        "kind": "baseline-render-selection-authority",
        "path": relative_path(root, path),
        "sha256": sha256_path(path),
    }


def build_report(
    root: Path,
    raw_path: Path,
    trace_directory: Optional[Path],
    trace_process: str,
    trace_sample_rate: Optional[int],
    trace_channel_count: Optional[int],
) -> dict[str, Any]:
    raw = load_json(raw_path, "raw performance observations")
    corpus = load_json(root / "docs/BASELINE_CORPUS.json", "baseline corpus")
    if corpus.get("schema") != CORPUS_SCHEMA:
        raise PerformanceEnvelopeError("baseline corpus schema is not v1")
    preparation, producer = validate_raw(raw, corpus, root)
    routes = sequence(corpus.get("routes"), "corpus.routes")
    selection_input = validate_measurement_selection(root, routes)
    live = trace_evidence(
        root,
        trace_directory,
        trace_process,
        trace_sample_rate,
        trace_channel_count,
    )
    live_observed = live["availability"] == "observed"
    body: dict[str, Any] = {
        "schema": REPORT_SCHEMA,
        "reportVersion": 1,
        "engineVersion": raw["engineVersion"],
        "gitHead": raw["gitHead"],
        "sourceFingerprint": raw["sourceFingerprint"],
        "contractBaselineFingerprint": raw["contractBaselineFingerprint"],
        "buildConfiguration": raw["buildConfiguration"],
        "machine": raw["machine"],
        "clock": raw["clock"],
        "memory": raw["memory"],
        "inputs": [{
            "kind": "raw-observations",
            "path": relative_path(root, raw_path),
            "sha256": sha256_path(raw_path),
        }, selection_input],
        "coverage": {
            "corpusCaseCount": len(sequence(corpus["cases"], "corpus.cases")),
            "measuredCorpusCaseCount": len({
                item["caseId"] for item in preparation
            }),
            "measurementCaseId": MEASUREMENT_CASE_ID,
            "measurementCaseSelection": "largest-existing-baseline-frame-count",
            "preparationRouteCount": len(routes),
            "preparationTrialCount": len(preparation),
            "producerFrameCounts": list(EXPECTED_FRAME_COUNTS),
            "producerTrialCount": len(producer),
            "hostClasses": [
                {
                    "host": "macOS",
                    "status": "observed" if live_observed else "unavailable",
                    "reason": live["reason"],
                },
                {
                    "host": "Windows",
                    "status": "unavailable",
                    "reason": "native-windows-performance-run-not-supplied",
                },
            ],
        },
        "preparation": preparation_summaries(preparation, routes),
        "callbackShapedProducer": {
            "measurementBoundary": "off-callback-exact-c-producer-operation",
            "includesConsumerCost": False,
            "queueLossMeaning": "feedback-handoff-only-not-device-underrun",
            "summaries": producer_summaries(producer),
        },
        "liveMacOS": live,
        "liveFeedbackQueueCounters": {
            "availability": "unavailable",
            "reason": "not-exported-by-external-audio-system-trace",
            "meaning": "feedback-handoff-loss-not-output-underrun",
        },
        "callbackSafety": {
            "instrumentationInCallback": False,
            "timingSource": "external-xctrace-audio-system-trace",
            "producerSourceSha256": sha256_path(
                root / "Sources/CAutoTechnoRealtime/CAutoTechnoRealtimeProducer.c"
            ),
            "transportSourceSha256": sha256_path(
                root / "Sources/AutoTechnoApp/LivePCMTransport.swift"
            ),
        },
        "qualification": {
            "status": (
                "descriptive-envelope-observed" if live_observed
                else "partial-live-evidence-unavailable"
            ),
            "reason": (
                "bounded-observation-complete-no-capacity-rank" if live_observed
                else "offline-and-producer-observed-live-host-not-observed"
            ),
            "musicalQualityClaim": False,
            "releaseReadinessClaim": False,
            "physicalSoakClaim": False,
        },
        "limitations": [
            "Wall-clock timings vary and are not musical identity or adaptation input.",
            "Process high-water is cumulative for the isolated test process, not phase-exclusive allocation.",
            "The callback-shaped benchmark measures the exact producer outside a callback and is not live callback duration.",
            "An empty bounded trace point-of-interest set is not a long-soak no-underrun claim.",
            "Windows remains unavailable until measured on a native Windows host.",
        ],
    }
    body["inputs"].extend(live.get("inputs", []))
    body["reportFingerprint"] = sha256_bytes(canonical_bytes(body))
    return body


def render_markdown(report: Mapping[str, Any]) -> str:
    lines = [
        "# Auto Techno Performance Envelope",
        "",
        "This checked report is a bounded performance observation, not a musical-quality, release-readiness, or physical-soak claim.",
        "",
        "## Provenance",
        "",
        f"- Engine: `{report['engineVersion']}`",
        f"- Git head recorded by exporter: `{report['gitHead']}`",
        f"- Source fingerprint: `{report['sourceFingerprint']}`",
        f"- Build configuration: `{report['buildConfiguration']}`",
        f"- Hardware: `{report['machine']['hardwareModel']}` / `{report['machine']['processor']}`",
        f"- OS: `{report['machine']['operatingSystemVersion']}`",
        f"- Report fingerprint: `{report['reportFingerprint']}`",
        "",
        "## Detached preparation",
        "",
        "All values are nanoseconds. Render/evaluate is measured by the existing phrase preparer; complete preparation is a separate replay through the canonical transport preparer. Exact PCM/evaluation identity must match between the two runs.",
        "",
        "| Route | Cases | Trials | Horizon updates | Plan p95 | Render/evaluate p95 | Complete p95 | Worst prep/audio ratio | Minimum lookahead margin | Process high-water |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for item in report["preparation"]:
        timings = item["timings"]
        lines.append(
            f"| `{item['routeId']}` | {item['caseCount']} | {item['trialCount']} | "
            f"{item['longHorizonUpdateAvailableCount']} | "
            f"{timings['planningNanoseconds']['p95']} | "
            f"{timings['renderEvaluationNanoseconds']['p95']} | "
            f"{timings['completePreparationNanoseconds']['p95']} | "
            f"{item['completePreparationToAudioRatio']['maximum']:.9f} | "
            f"{item['minimumSuccessorLookaheadMarginNanoseconds']} | "
            f"{item['processHighWaterBytesMaximum']} |"
        )
    lines += [
        "",
        "## Callback-shaped producer",
        "",
        "This is an off-callback microbenchmark of the exact bounded C producer only. Queue drops/rejections are feedback-handoff facts, not device underruns.",
        "",
        "| Frames | Trials | Operations/trial | Producer p50 ns | p95 ns | max ns | Drops | Rejections |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for item in report["callbackShapedProducer"]["summaries"]:
        timing = item["producerNanosecondsPerOperation"]
        lines.append(
            f"| {item['frameCount']} | {item['trialCount']} | "
            f"{item['operationsPerTrial']} | {timing['p50']} | {timing['p95']} | "
            f"{timing['maximum']} | {item['droppedPacketDelta']} | "
            f"{item['rejectedPacketDelta']} |"
        )
    live = report["liveMacOS"]
    lines += ["", "## Live macOS host evidence", ""]
    if live["availability"] == "observed":
        callback = live["callbackDurationNanoseconds"]
        lines += [
            f"- Route: {live['sampleRate']} Hz, {live['channelCount']} channels",
            f"- Callback cycles: {live['callbackCycleCount']}",
            f"- Callback duration p50/p95/max: {callback['p50']} / {callback['p95']} / {callback['maximum']} ns",
            f"- Minimum observed device frame count: {live['minimumObservedFrameCount']}",
            f"- Maximum callback/budget ratio: {live['maximumCallbackToBudgetRatio']:.9f}",
            f"- Non-normal callback cycles: {live['nonNormalCallbackCycleCount']}",
            f"- Deadline/underrun evidence: `{live['underrunEvidence']}` ({live['relevantDeadlinePointCount']} relevant points)",
        ]
    else:
        lines.append(f"Unavailable: `{live['reason']}`.")
    lines += [
        "",
        "## Qualification boundary",
        "",
        f"- Status: `{report['qualification']['status']}`",
        f"- Reason: `{report['qualification']['reason']}`",
        "- No timing feeds score choice, rendering, evaluation, adaptation, scheduling, transport, or presentation.",
        "- No timing or logging was added to the audio callback.",
        "- Windows performance and long physical-output soak remain unavailable.",
        "",
        "## Limitations",
        "",
    ]
    lines.extend(f"- {item}" for item in report["limitations"])
    return "\n".join(lines) + "\n"


def write_report(path: Path, report: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(report, indent=2, sort_keys=True, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )


def command_generate(args: argparse.Namespace) -> None:
    root = repository_root()
    raw = root / args.raw
    trace = (root / args.trace_directory) if args.trace_directory else None
    report = build_report(
        root,
        raw,
        trace,
        args.trace_process,
        args.trace_sample_rate,
        args.trace_channel_count,
    )
    report_path = root / args.output
    markdown_path = root / args.markdown
    write_report(report_path, report)
    markdown_path.write_text(render_markdown(report), encoding="utf-8")
    print(
        f"performance envelope: {report['qualification']['status']}; "
        f"{report['coverage']['preparationTrialCount']} preparation trials; "
        f"{report['coverage']['producerTrialCount']} producer trials; "
        f"live={report['liveMacOS']['availability']}"
    )


def command_check(args: argparse.Namespace) -> None:
    root = repository_root()
    raw = root / args.raw
    trace = (root / args.trace_directory) if args.trace_directory else None
    expected = build_report(
        root,
        raw,
        trace,
        args.trace_process,
        args.trace_sample_rate,
        args.trace_channel_count,
    )
    actual = load_json(root / args.output, "performance report")
    if actual != expected:
        raise PerformanceEnvelopeError(
            "performance report is stale; rerun generate with the same trace arguments"
        )
    markdown = (root / args.markdown).read_text(encoding="utf-8")
    if markdown != render_markdown(expected):
        raise PerformanceEnvelopeError("performance Markdown is stale")
    print(
        f"performance envelope current: {expected['qualification']['status']}; "
        f"fingerprint {expected['reportFingerprint']}"
    )


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)
    for command in ("generate", "check"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--raw", type=Path, default=DEFAULT_RAW)
        subparser.add_argument("--output", type=Path, default=DEFAULT_REPORT)
        subparser.add_argument("--markdown", type=Path, default=DEFAULT_MARKDOWN)
        subparser.add_argument("--trace-directory", type=Path)
        subparser.add_argument("--trace-process", default="AutoTechno")
        subparser.add_argument("--trace-sample-rate", type=int)
        subparser.add_argument("--trace-channel-count", type=int)
    return result


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "generate":
            command_generate(args)
        else:
            command_check(args)
    except (OSError, PerformanceEnvelopeError) as exc:
        print(f"performance envelope failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
