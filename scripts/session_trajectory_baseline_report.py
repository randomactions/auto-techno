#!/usr/bin/env python3
"""Independently verify and summarize the four-hour score-only session baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import subprocess
import sys
from typing import Any, Mapping, Sequence

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import baseline_render_manifest as baseline_identity  # noqa: E402


MANIFEST_SCHEMA = "autotechno-long-horizon-session-baseline-manifest.v1"
ARTIFACT_SCHEMA = "autotechno-long-horizon-session-baseline-artifact.v1"
REPORT_SCHEMA = "autotechno-long-horizon-session-baseline-report.v1"
ANALYZER_SCHEMA = "autotechno-long-horizon-session-baseline.v1"
SEGMENT_BAR_COUNT = 32
MAXIMUM_BAR_COUNT = 8_192
MAXIMUM_SEGMENT_COUNT = 256
HIGH_TENSION_FLOOR = 0.8
RECOVERY_TENSION_CEILING = 0.4
PHRASE_KINDS = ("lock", "contrast", "majorBreak", "energyRelease", "identityReturn")
OPERATORS = ("maintain", "rise", "recover", "reframe", "payoff", "recall")
SECTIONS = ("groove", "build", "breakdown", "return")
CHAPTERS = ("home", "breath", "tone", "motion", "memory")
CAPABILITIES = (
    "groove-pulse",
    "closed-hat-companion",
    "upper-percussion-clearance",
    "modal-percussion",
    "spatial-distance",
    "pulse-echo",
    "dotted-foundation-rhythm",
    "kick-withholding",
    "kick-recovery",
    "climax-hang",
    "gated-percussion-echo",
    "anticipation-swell",
    "audio-slice",
    "arpeggiator",
    "pad-harmony",
    "harmonic-disclosure",
    "pad-rhythmic-modulation",
)
MANIFEST_KEYS = {
    "schema", "manifestVersion", "corpusSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "analyzerSchemaVersion", "analyzerSchemaIdentifier",
    "buildConfiguration", "observationRoute", "requestedHours",
    "requestedBars", "segmentBarCount", "maximumBarCount",
    "maximumSegmentCount", "entries",
}
ENTRY_KEYS = {
    "id", "caseId", "ordinal", "rootSeed", "checkpoint",
    "continuationClass", "initialStateFingerprint",
    "outgoingStateFingerprint", "startingPhraseIndex",
    "nextExpectedPhraseIndex", "startingBar", "nextExpectedBar",
    "observedPhraseCount", "observedBarCount", "segmentCount",
    "reportFingerprint", "artifactPath", "artifactSha256",
}
ARTIFACT_KEYS = {
    "schema", "artifactVersion", "caseId", "ordinal", "rootSeed",
    "checkpoint", "continuationClass", "requestedHours", "requestedBars",
    "buildConfiguration", "observationRoute", "initialStateFingerprint",
    "outgoingStateFingerprint", "phrases", "report",
}
PHRASE_KEYS = {
    "rootSeed", "phraseIndex", "startBar", "phraseKind", "operatorKind",
    "selectionReason", "bars",
}
BAR_KEYS = {
    "absoluteBar", "section", "interlockChapter", "tension", "activity",
    "repetition", "density", "eventSignature", "capabilities",
}
SWIFT_REPORT_KEYS = {
    "schemaVersion", "schemaIdentifier", "engineVersion",
    "qualificationStatus", "qualificationReason", "realizedSignalAvailability",
    "realizedSignalUnavailableReason", "rootSeed", "startingPhraseIndex",
    "startingBar", "nextExpectedPhraseIndex", "nextExpectedBar",
    "observedPhraseCount", "observedBarCount", "segmentBarCount",
    "maximumBarCount", "segments", "payoffMarkerBars",
    "recoveryMarkerBars", "payoffSpacing", "payoffRecovery",
    "capabilityExposure", "reportFingerprint",
}
DEFAULT_MANIFEST = Path(
    "docs/local/reports/long-horizon-session-baseline-v1/manifest.json"
)
DEFAULT_REPORT = Path(
    "docs/local/reports/long-horizon-session-baseline-v1/report.json"
)


class SessionTrajectoryBaselineError(RuntimeError):
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
        raise SessionTrajectoryBaselineError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SessionTrajectoryBaselineError(
            f"cannot read {label} at {path}: {exc}"
        ) from exc
    if not isinstance(value, dict):
        raise SessionTrajectoryBaselineError(f"{label} must be an object")
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
        raise SessionTrajectoryBaselineError(
            f"{location} has invalid fields: {'; '.join(details)}"
        )


def integer(value: object, location: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise SessionTrajectoryBaselineError(
            f"{location} must be an integer >= {minimum}"
        )
    return value


def number(value: object, location: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SessionTrajectoryBaselineError(f"{location} must be numeric")
    result = float(value)
    if not math.isfinite(result):
        raise SessionTrajectoryBaselineError(f"{location} must be finite")
    return result


def text(value: object, location: str) -> str:
    if not isinstance(value, str) or not value:
        raise SessionTrajectoryBaselineError(f"{location} must be nonempty text")
    return value


def sequence(value: object, location: str) -> list[Any]:
    if not isinstance(value, list):
        raise SessionTrajectoryBaselineError(f"{location} must be an array")
    return value


def safe_artifact_path(root: Path, value: object, location: str) -> Path:
    raw = text(value, location)
    path = PurePosixPath(raw)
    prefix = "docs/local/reports/long-horizon-session-baseline-v1/"
    if path.is_absolute() or "." in path.parts or ".." in path.parts:
        raise SessionTrajectoryBaselineError(f"{location} is not repository-relative")
    if not raw.startswith(prefix) or path.suffix != ".json":
        raise SessionTrajectoryBaselineError(f"{location} escapes the report directory")
    return root / path


def git_output(root: Path, arguments: list[str]) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), *arguments],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise SessionTrajectoryBaselineError(f"git {' '.join(arguments)} failed") from exc
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
            raise SessionTrajectoryBaselineError(
                f"cannot fingerprint source {relative}: {exc}"
            ) from exc
    return digest.hexdigest()


class FNV64:
    def __init__(self) -> None:
        self.value = 0xCBF29CE484222325

    def _bytes(self, values: bytes) -> None:
        for value in values:
            self.value ^= value
            self.value = (self.value * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF

    def string(self, value: str) -> None:
        self._bytes(value.encode("utf-8"))
        self._bytes(b"\xff")

    def uint64(self, value: int) -> None:
        self._bytes(struct.pack("<Q", value & 0xFFFFFFFFFFFFFFFF))

    def integer(self, value: int) -> None:
        self.uint64(value)

    def scalar(self, value: float) -> None:
        self._bytes(struct.pack("<d", value))

    @property
    def fingerprint(self) -> str:
        return f"{self.value:016x}"


def validate_selection(phrase: Mapping[str, Any], location: str) -> None:
    kind = phrase["phraseKind"]
    operator = phrase["operatorKind"]
    reason = phrase["selectionReason"]
    valid = False
    if reason == "conservative-fallback":
        valid = operator is None
    elif reason == "minimum-hold":
        valid = operator in OPERATORS
    elif reason == "reserved-payoff":
        valid = operator == "payoff" and kind == "lock"
    elif reason == "reserved-recall":
        valid = operator == "recall" and kind == "lock"
    elif reason == "payoff-debt-establishment":
        valid = operator == "payoff" and kind == "contrast"
    elif reason == "episode-operator":
        valid = {
            "maintain": ("lock",),
            "rise": ("contrast",),
            "recover": ("majorBreak",),
            "reframe": ("contrast", "majorBreak"),
            "payoff": ("energyRelease",),
            "recall": ("identityReturn",),
        }.get(operator, ()).__contains__(kind)
    if not valid:
        raise SessionTrajectoryBaselineError(f"{location} selection is inconsistent")


def validate_and_flatten(
    phrases_value: object,
) -> tuple[list[dict[str, Any]], int, int, int, int, int]:
    phrases = sequence(phrases_value, "artifact.phrases")
    if not phrases:
        raise SessionTrajectoryBaselineError("artifact.phrases must not be empty")
    first = phrases[0]
    if not isinstance(first, dict):
        raise SessionTrajectoryBaselineError("artifact.phrases[0] must be an object")
    exact_keys(first, PHRASE_KEYS, "artifact.phrases[0]")
    root_seed = integer(first["rootSeed"], "artifact.phrases[0].rootSeed")
    expected_phrase = integer(first["phraseIndex"], "artifact.phrases[0].phraseIndex")
    starting_phrase = expected_phrase
    expected_bar = integer(first["startBar"], "artifact.phrases[0].startBar")
    starting_bar = expected_bar
    contexts: list[dict[str, Any]] = []
    hasher = FNV64()
    hasher.string(ANALYZER_SCHEMA)
    hasher.uint64(root_seed)
    hasher.integer(starting_phrase)
    hasher.integer(starting_bar)

    for phrase_index, raw_phrase in enumerate(phrases):
        location = f"artifact.phrases[{phrase_index}]"
        if not isinstance(raw_phrase, dict):
            raise SessionTrajectoryBaselineError(f"{location} must be an object")
        exact_keys(raw_phrase, PHRASE_KEYS, location)
        if integer(raw_phrase["rootSeed"], f"{location}.rootSeed") != root_seed:
            raise SessionTrajectoryBaselineError(f"{location}.rootSeed is discontinuous")
        if integer(raw_phrase["phraseIndex"], f"{location}.phraseIndex") != expected_phrase:
            raise SessionTrajectoryBaselineError(f"{location}.phraseIndex is discontinuous")
        if integer(raw_phrase["startBar"], f"{location}.startBar") != expected_bar:
            raise SessionTrajectoryBaselineError(f"{location}.startBar is discontinuous")
        kind = text(raw_phrase["phraseKind"], f"{location}.phraseKind")
        if kind not in PHRASE_KINDS:
            raise SessionTrajectoryBaselineError(f"{location}.phraseKind is unknown")
        operator = raw_phrase["operatorKind"]
        if operator is not None and operator not in OPERATORS:
            raise SessionTrajectoryBaselineError(f"{location}.operatorKind is unknown")
        reason = text(raw_phrase["selectionReason"], f"{location}.selectionReason")
        validate_selection(raw_phrase, location)
        bars = sequence(raw_phrase["bars"], f"{location}.bars")
        if not 1 <= len(bars) <= 16:
            raise SessionTrajectoryBaselineError(f"{location}.bars must contain 1...16 bars")
        if len(contexts) + len(bars) > MAXIMUM_BAR_COUNT:
            raise SessionTrajectoryBaselineError("artifact exceeds maximum bar capacity")
        payoff = operator == "payoff" and reason == "episode-operator" and kind == "energyRelease"
        recovery = operator == "recover" and reason == "episode-operator" and kind == "majorBreak"
        hasher.string("phrase")
        hasher.integer(expected_phrase)
        hasher.integer(expected_bar)
        hasher.string(kind)
        hasher.string(operator if operator is not None else "none")
        hasher.string(reason)
        for local_bar, raw_bar in enumerate(bars):
            bar_location = f"{location}.bars[{local_bar}]"
            if not isinstance(raw_bar, dict):
                raise SessionTrajectoryBaselineError(f"{bar_location} must be an object")
            exact_keys(raw_bar, BAR_KEYS, bar_location)
            absolute_bar = integer(raw_bar["absoluteBar"], f"{bar_location}.absoluteBar")
            if absolute_bar != expected_bar + local_bar:
                raise SessionTrajectoryBaselineError(f"{bar_location} is discontinuous")
            section = text(raw_bar["section"], f"{bar_location}.section")
            chapter = text(raw_bar["interlockChapter"], f"{bar_location}.interlockChapter")
            if section not in SECTIONS or chapter not in CHAPTERS:
                raise SessionTrajectoryBaselineError(f"{bar_location} has unknown score labels")
            scalars = {
                name: number(raw_bar[name], f"{bar_location}.{name}")
                for name in ("tension", "activity", "repetition", "density")
            }
            if any(value < 0 or value > 1 for value in scalars.values()):
                raise SessionTrajectoryBaselineError(f"{bar_location} scalar escapes 0...1")
            signature = integer(raw_bar["eventSignature"], f"{bar_location}.eventSignature")
            capabilities = sequence(raw_bar["capabilities"], f"{bar_location}.capabilities")
            if capabilities != [item for item in CAPABILITIES if item in capabilities]:
                raise SessionTrajectoryBaselineError(f"{bar_location}.capabilities is noncanonical")
            if len(set(capabilities)) != len(capabilities):
                raise SessionTrajectoryBaselineError(f"{bar_location}.capabilities has duplicates")
            context = {
                **raw_bar,
                **scalars,
                "phraseIndex": expected_phrase,
                "phraseKind": kind,
                "operatorKind": operator,
                "payoffMarker": payoff and local_bar == 0,
                "recoveryMarker": recovery and local_bar == 0,
            }
            contexts.append(context)
            hasher.string("bar")
            hasher.integer(absolute_bar)
            hasher.string(section)
            hasher.string(chapter)
            for name in ("tension", "activity", "repetition", "density"):
                hasher.scalar(scalars[name])
            hasher.uint64(signature)
            hasher.integer(len(capabilities))
            for capability in capabilities:
                hasher.string(capability)
        expected_phrase += 1
        expected_bar += len(bars)
    return contexts, root_seed, starting_phrase, starting_bar, expected_phrase, expected_bar


def scalar_summary(values: Sequence[float]) -> dict[str, Any]:
    maximum_step = 0.0
    last_direction = 0
    direction_changes = 0
    total = 0.0
    for value in values:
        total += value
    for prior, current in zip(values, values[1:]):
        delta = current - prior
        maximum_step = max(maximum_step, abs(delta))
        direction = 1 if delta > 0 else (-1 if delta < 0 else 0)
        if direction:
            if last_direction and direction != last_direction:
                direction_changes += 1
            last_direction = direction
    return {
        "observationCount": len(values),
        "first": values[0],
        "last": values[-1],
        "minimum": min(values),
        "maximum": max(values),
        "mean": total / len(values),
        "maximumAbsoluteStep": maximum_step,
        "directionChangeCount": direction_changes,
    }


def maximum_run(flags: Sequence[bool]) -> int:
    current = maximum = 0
    for flag in flags:
        current = current + 1 if flag else 0
        maximum = max(maximum, current)
    return maximum


def maximum_equal_run(values: Sequence[int]) -> int:
    prior: int | None = None
    current = maximum = 0
    for value in values:
        current = current + 1 if value == prior else 1
        prior = value
        maximum = max(maximum, current)
    return maximum


def named_counts(order: Sequence[str], values: Sequence[str]) -> list[dict[str, Any]]:
    return [{"name": name, "barCount": values.count(name)} for name in order]


def capability_exposure(contexts: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    result = []
    for capability in CAPABILITIES:
        flags = [capability in context["capabilities"] for context in contexts]
        result.append({
            "capability": capability,
            "activeBarCount": sum(flags),
            "maximumRunBars": maximum_run(flags),
        })
    return result


def rebuild_segment(index: int, contexts: list[dict[str, Any]]) -> dict[str, Any]:
    tensions = [item["tension"] for item in contexts]
    signatures = [item["eventSignature"] for item in contexts]
    high = [value >= HIGH_TENSION_FLOOR for value in tensions]
    return {
        "segmentIndex": index,
        "startBar": contexts[0]["absoluteBar"],
        "endBarExclusive": contexts[-1]["absoluteBar"] + 1,
        "barCount": len(contexts),
        "complete": len(contexts) == SEGMENT_BAR_COUNT,
        "tension": scalar_summary(tensions),
        "activity": scalar_summary([item["activity"] for item in contexts]),
        "repetition": scalar_summary([item["repetition"] for item in contexts]),
        "density": scalar_summary([item["density"] for item in contexts]),
        "highTensionBarCount": sum(high),
        "recoveryTensionBarCount": sum(
            value <= RECOVERY_TENSION_CEILING for value in tensions
        ),
        "maximumHighTensionRunBars": maximum_run(high),
        "payoffMarkerBars": [
            item["absoluteBar"] for item in contexts if item["payoffMarker"]
        ],
        "recoveryMarkerBars": [
            item["absoluteBar"] for item in contexts if item["recoveryMarker"]
        ],
        "repeatedEventSignatureBarCount": len(signatures) - len(set(signatures)),
        "maximumEventSignatureRunBars": maximum_equal_run(signatures),
        "phraseKindBarCounts": named_counts(
            PHRASE_KINDS, [item["phraseKind"] for item in contexts]
        ),
        "operatorBarCounts": named_counts(
            OPERATORS,
            [item["operatorKind"] for item in contexts if item["operatorKind"]],
        ),
        "sectionBarCounts": named_counts(
            SECTIONS, [item["section"] for item in contexts]
        ),
        "interlockChapterBarCounts": named_counts(
            CHAPTERS, [item["interlockChapter"] for item in contexts]
        ),
        "capabilityExposure": capability_exposure(contexts),
    }


def payoff_recovery(payoffs: list[int], recoveries: list[int]) -> list[dict[str, Any]]:
    result = []
    for index, payoff in enumerate(payoffs):
        next_payoff = payoffs[index + 1] if index + 1 < len(payoffs) else None
        recovery = next((
            value for value in recoveries
            if value > payoff and (next_payoff is None or value < next_payoff)
        ), None)
        result.append({
            "payoffBar": payoff,
            "recoveryBar": recovery,
            "latencyBars": None if recovery is None else recovery - payoff,
            "status": "observed" if recovery is not None else "unresolved-within-horizon",
        })
    return result


def rebuild_report(phrases: object, engine_version: str) -> dict[str, Any]:
    contexts, root, start_phrase, start_bar, next_phrase, next_bar = \
        validate_and_flatten(phrases)
    segments = [
        rebuild_segment(index, contexts[offset:offset + SEGMENT_BAR_COUNT])
        for index, offset in enumerate(range(0, len(contexts), SEGMENT_BAR_COUNT))
    ]
    payoffs = [item["absoluteBar"] for item in contexts if item["payoffMarker"]]
    recoveries = [item["absoluteBar"] for item in contexts if item["recoveryMarker"]]
    intervals = [right - left for left, right in zip(payoffs, payoffs[1:])]
    hasher = FNV64()
    hasher.string(ANALYZER_SCHEMA)
    hasher.uint64(root)
    hasher.integer(start_phrase)
    hasher.integer(start_bar)
    for raw_phrase in phrases:
        hasher.string("phrase")
        hasher.integer(raw_phrase["phraseIndex"])
        hasher.integer(raw_phrase["startBar"])
        hasher.string(raw_phrase["phraseKind"])
        hasher.string(raw_phrase["operatorKind"] or "none")
        hasher.string(raw_phrase["selectionReason"])
        for bar in raw_phrase["bars"]:
            hasher.string("bar")
            hasher.integer(bar["absoluteBar"])
            hasher.string(bar["section"])
            hasher.string(bar["interlockChapter"])
            for name in ("tension", "activity", "repetition", "density"):
                hasher.scalar(float(bar[name]))
            hasher.uint64(bar["eventSignature"])
            hasher.integer(len(bar["capabilities"]))
            for capability in bar["capabilities"]:
                hasher.string(capability)
    return {
        "schemaVersion": 1,
        "schemaIdentifier": ANALYZER_SCHEMA,
        "engineVersion": engine_version,
        "qualificationStatus": "unavailable",
        "qualificationReason": "descriptive-score-only-no-quality-rank",
        "realizedSignalAvailability": "unavailable",
        "realizedSignalUnavailableReason": "score-only-no-continuous-pcm",
        "rootSeed": root,
        "startingPhraseIndex": start_phrase,
        "startingBar": start_bar,
        "nextExpectedPhraseIndex": next_phrase,
        "nextExpectedBar": next_bar,
        "observedPhraseCount": len(phrases),
        "observedBarCount": len(contexts),
        "segmentBarCount": SEGMENT_BAR_COUNT,
        "maximumBarCount": MAXIMUM_BAR_COUNT,
        "segments": segments,
        "payoffMarkerBars": payoffs,
        "recoveryMarkerBars": recoveries,
        "payoffSpacing": {
            "intervalCount": len(intervals),
            "minimumBars": min(intervals) if intervals else None,
            "maximumBars": max(intervals) if intervals else None,
            "meanBars": sum(intervals) / len(intervals) if intervals else None,
        },
        "payoffRecovery": payoff_recovery(payoffs, recoveries),
        "capabilityExposure": capability_exposure(contexts),
        "reportFingerprint": hasher.fingerprint,
    }


def compare(actual: object, expected: object, location: str = "value") -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            raise SessionTrajectoryBaselineError(f"{location} must be an object")
        exact_keys(actual, set(expected), location)
        for key, expected_value in expected.items():
            compare(actual[key], expected_value, f"{location}.{key}")
    elif isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise SessionTrajectoryBaselineError(f"{location} has wrong cardinality")
        for index, (actual_item, expected_item) in enumerate(zip(actual, expected)):
            compare(actual_item, expected_item, f"{location}[{index}]")
    elif isinstance(expected, float):
        if (
            isinstance(actual, bool)
            or not isinstance(actual, (int, float))
            or not math.isfinite(float(actual))
            or float(actual) != expected
        ):
            raise SessionTrajectoryBaselineError(
                f"{location} does not independently reconstruct"
            )
    elif actual != expected:
        raise SessionTrajectoryBaselineError(
            f"{location} does not independently reconstruct"
        )


def validate_provenance(manifest: dict[str, Any], root: Path) -> dict[str, Any]:
    exact_keys(manifest, MANIFEST_KEYS, "manifest")
    if manifest["schema"] != MANIFEST_SCHEMA or manifest["manifestVersion"] != 1:
        raise SessionTrajectoryBaselineError("unsupported manifest schema")
    if manifest["analyzerSchemaVersion"] != 1 or \
            manifest["analyzerSchemaIdentifier"] != ANALYZER_SCHEMA:
        raise SessionTrajectoryBaselineError("unsupported analyzer schema")
    if manifest["observationRoute"] != "score-only-canonical-planning":
        raise SessionTrajectoryBaselineError("manifest observation route is not score-only")
    for key, expected in (
        ("requestedHours", 4),
        ("requestedBars", 7_800),
        ("segmentBarCount", SEGMENT_BAR_COUNT),
        ("maximumBarCount", MAXIMUM_BAR_COUNT),
        ("maximumSegmentCount", MAXIMUM_SEGMENT_COUNT),
    ):
        if manifest[key] != expected:
            raise SessionTrajectoryBaselineError(f"manifest {key} is unsupported")
    if manifest["buildConfiguration"] not in {"debug", "release"}:
        raise SessionTrajectoryBaselineError("manifest build configuration is unknown")
    corpus_path = root / "docs/BASELINE_CORPUS.json"
    snapshot_path = root / "docs/ROADMAP_EXECUTION_BASELINE.json"
    corpus = load_json(corpus_path, "baseline corpus")
    snapshot = load_json(snapshot_path, "contract baseline")
    if manifest["corpusSha256"] != sha256_path(corpus_path):
        raise SessionTrajectoryBaselineError("manifest corpus fingerprint is stale")
    if manifest["contractBaselineFingerprint"] != snapshot.get("snapshotFingerprint"):
        raise SessionTrajectoryBaselineError("manifest contract baseline is stale")
    if manifest["sourceFingerprint"] != source_fingerprint(root):
        raise SessionTrajectoryBaselineError("manifest source fingerprint is stale")
    revision_error = baseline_identity.capture_revision_error(root, manifest["gitHead"])
    if revision_error:
        raise SessionTrajectoryBaselineError(revision_error)
    return corpus


def validate_manifest(
    manifest: dict[str, Any], root: Path, manifest_path: Path
) -> list[dict[str, Any]]:
    corpus = validate_provenance(manifest, root)
    cases = sequence(corpus.get("cases"), "baseline corpus cases")
    expected = {case["id"]: case for case in cases if isinstance(case, dict)}
    entries = sequence(manifest["entries"], "manifest.entries")
    if len(entries) != 7 or len(expected) != 7:
        raise SessionTrajectoryBaselineError("manifest must cover exactly seven cases")
    if [entry.get("ordinal") for entry in entries] != list(range(7)):
        raise SessionTrajectoryBaselineError("manifest ordinals must be canonical 0...6")
    rebuilt_entries: list[dict[str, Any]] = []
    for index, entry in enumerate(entries):
        location = f"manifest.entries[{index}]"
        if not isinstance(entry, dict):
            raise SessionTrajectoryBaselineError(f"{location} must be an object")
        exact_keys(entry, ENTRY_KEYS, location)
        fixture = expected.get(entry["caseId"])
        if fixture is None:
            raise SessionTrajectoryBaselineError(f"{location} has unknown caseId")
        for key in ("ordinal", "rootSeed", "checkpoint", "continuationClass"):
            if entry[key] != fixture[key]:
                raise SessionTrajectoryBaselineError(f"{location}.{key} differs from corpus")
        artifact_path = safe_artifact_path(root, entry["artifactPath"], f"{location}.artifactPath")
        if artifact_path.resolve() == manifest_path.resolve():
            raise SessionTrajectoryBaselineError(f"{location} points to the manifest")
        if sha256_path(artifact_path) != entry["artifactSha256"]:
            raise SessionTrajectoryBaselineError(f"{location} artifact hash is stale")
        artifact = load_json(artifact_path, f"artifact {entry['caseId']}")
        exact_keys(artifact, ARTIFACT_KEYS, f"artifact[{index}]")
        if artifact["schema"] != ARTIFACT_SCHEMA or artifact["artifactVersion"] != 1:
            raise SessionTrajectoryBaselineError(f"artifact[{index}] schema is unsupported")
        for key in (
            "caseId", "ordinal", "rootSeed", "checkpoint", "continuationClass",
            "initialStateFingerprint", "outgoingStateFingerprint",
        ):
            if artifact[key] != entry[key]:
                raise SessionTrajectoryBaselineError(f"artifact[{index}].{key} is inconsistent")
        for key in ("requestedHours", "requestedBars", "buildConfiguration", "observationRoute"):
            if artifact[key] != manifest[key]:
                raise SessionTrajectoryBaselineError(f"artifact[{index}].{key} is inconsistent")
        swift_report = artifact["report"]
        if not isinstance(swift_report, dict):
            raise SessionTrajectoryBaselineError(f"artifact[{index}].report must be an object")
        exact_keys(swift_report, SWIFT_REPORT_KEYS, f"artifact[{index}].report")
        rebuilt = rebuild_report(artifact["phrases"], manifest["engineVersion"])
        compare(swift_report, rebuilt, f"artifact[{index}].report")
        entry_bindings = {
            "startingPhraseIndex": rebuilt["startingPhraseIndex"],
            "nextExpectedPhraseIndex": rebuilt["nextExpectedPhraseIndex"],
            "startingBar": rebuilt["startingBar"],
            "nextExpectedBar": rebuilt["nextExpectedBar"],
            "observedPhraseCount": rebuilt["observedPhraseCount"],
            "observedBarCount": rebuilt["observedBarCount"],
            "segmentCount": len(rebuilt["segments"]),
            "reportFingerprint": rebuilt["reportFingerprint"],
        }
        for key, value in entry_bindings.items():
            if entry[key] != value:
                raise SessionTrajectoryBaselineError(f"{location}.{key} is inconsistent")
        if rebuilt["observedBarCount"] < manifest["requestedBars"]:
            raise SessionTrajectoryBaselineError(f"{location} is shorter than requested")
        rebuilt_entries.append({
            "id": entry["id"],
            "caseId": entry["caseId"],
            "ordinal": entry["ordinal"],
            "rootSeed": entry["rootSeed"],
            "checkpoint": entry["checkpoint"],
            "continuationClass": entry["continuationClass"],
            "observedPhraseCount": rebuilt["observedPhraseCount"],
            "observedBarCount": rebuilt["observedBarCount"],
            "segmentCount": len(rebuilt["segments"]),
            "payoffMarkerCount": len(rebuilt["payoffMarkerBars"]),
            "recoveryMarkerCount": len(rebuilt["recoveryMarkerBars"]),
            "unresolvedPayoffCount": sum(
                item["status"] == "unresolved-within-horizon"
                for item in rebuilt["payoffRecovery"]
            ),
            "reportFingerprint": rebuilt["reportFingerprint"],
            "artifactSha256": entry["artifactSha256"],
        })
    return rebuilt_entries


def build_report(
    manifest: dict[str, Any], root: Path, manifest_path: Path
) -> dict[str, Any]:
    entries = validate_manifest(manifest, root, manifest_path)
    payload = {
        "schema": REPORT_SCHEMA,
        "reportVersion": 1,
        "manifestSha256": sha256_path(manifest_path),
        "corpusSha256": manifest["corpusSha256"],
        "contractBaselineFingerprint": manifest["contractBaselineFingerprint"],
        "sourceFingerprint": manifest["sourceFingerprint"],
        "gitHead": manifest["gitHead"],
        "engineVersion": manifest["engineVersion"],
        "analyzerSchemaIdentifier": manifest["analyzerSchemaIdentifier"],
        "buildConfiguration": manifest["buildConfiguration"],
        "observationRoute": manifest["observationRoute"],
        "requestedHours": manifest["requestedHours"],
        "requestedBars": manifest["requestedBars"],
        "entryCount": len(entries),
        "summary": {
            "observedPhraseCount": sum(item["observedPhraseCount"] for item in entries),
            "observedBarCount": sum(item["observedBarCount"] for item in entries),
            "segmentCount": sum(item["segmentCount"] for item in entries),
            "payoffMarkerCount": sum(item["payoffMarkerCount"] for item in entries),
            "recoveryMarkerCount": sum(item["recoveryMarkerCount"] for item in entries),
            "unresolvedPayoffCount": sum(item["unresolvedPayoffCount"] for item in entries),
            "realizedSignalAvailability": "unavailable",
            "realizedSignalUnavailableReason": "score-only-no-continuous-pcm",
            "qualityQualification": "unavailable",
            "qualityQualificationReason": "descriptive-score-only-no-quality-rank",
        },
        "entries": entries,
    }
    return {**payload, "reportFingerprint": sha256_bytes(canonical_bytes(payload))}


def validate_stored_report(stored: dict[str, Any], expected: dict[str, Any]) -> None:
    compare(stored, expected, "stored report")
    payload = {key: value for key, value in stored.items() if key != "reportFingerprint"}
    if stored.get("reportFingerprint") != sha256_bytes(canonical_bytes(payload)):
        raise SessionTrajectoryBaselineError("stored report fingerprint is invalid")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args(argv)
    root = repository_root()
    manifest_path = arguments.manifest
    if not manifest_path.is_absolute():
        manifest_path = root / manifest_path
    output_path = arguments.output
    if not output_path.is_absolute():
        output_path = root / output_path
    try:
        manifest = load_json(manifest_path, "session baseline manifest")
        report = build_report(manifest, root, manifest_path)
        if arguments.check:
            validate_stored_report(load_json(output_path, "session baseline report"), report)
            print(
                "long-horizon session baseline is current: "
                f"{report['entryCount']} entries, "
                f"{report['summary']['observedBarCount']} bars"
            )
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(
                json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
                encoding="utf-8",
            )
            print(f"wrote {output_path}")
    except SessionTrajectoryBaselineError as exc:
        print(f"session trajectory baseline error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
