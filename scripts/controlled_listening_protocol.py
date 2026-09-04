#!/usr/bin/env python3
"""Generate and validate local identity-blind listening-session records."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence, TextIO


PROTOCOL_SCHEMA = "autotechno-controlled-listening-protocol.v1"
REQUEST_SCHEMA = "autotechno-controlled-listening-request.v1"
PLAN_SCHEMA = "autotechno-controlled-listening-plan.v1"
KEY_SCHEMA = "autotechno-controlled-listening-key.v1"
RESULT_SCHEMA = "autotechno-controlled-listening-result.v1"
PURPOSE = "hypothesis-discovery-only"
MASK64 = (1 << 64) - 1
HEX64 = re.compile(r"^[0-9a-f]{64}$")
SESSION_ID = re.compile(r"^[a-z0-9][a-z0-9-]{2,63}$")
TOKEN = re.compile(r"^C-[0-9A-F]{12}$")
TRIAL_ID = re.compile(r"^T-[0-9A-F]{12}$")

PROTOCOL_ROOT_KEYS = {
    "schema", "protocolVersion", "purpose", "limits", "vocabularies",
    "schemas", "randomization", "qualificationBoundary",
}
PURPOSE_KEYS = {"id", "meaning", "promotionAuthorized", "runtimeInputAuthorized"}
LIMIT_KEYS = {
    "minimumTrials", "maximumTrials", "minimumRepetitions",
    "maximumRepetitions", "maximumOrderStreak", "maximumSessionMinutes",
    "maximumNoteCharacters", "maximumHypotheses", "maximumInterruptions",
    "maximumBreaks",
}
VOCABULARY_KEYS = {
    "attributes", "audibility", "confidence", "fatigue", "levelMethods",
    "resultStatuses", "revealStatuses", "transducerTypes",
}
SCHEMA_KEYS = {"request", "plan", "key", "result"}
RANDOMIZATION_KEYS = {
    "algorithm", "seedScope", "tokenDerivation",
    "requiresBalancedFirstPosition", "identityLabelsForbiddenInPlan",
}
BOUNDARY_KEYS = {"listeningGateState", "allowedRoadmapDisposition", "forbiddenClaims"}
REQUEST_KEYS = {
    "schema", "protocolVersion", "sessionId", "randomizationSeed", "attribute",
    "attributePrompt", "repetitions", "durationLimitMinutes", "conditionOne",
    "conditionTwo", "environment",
}
CONDITION_KEYS = {
    "sourceId", "manifestPath", "manifestSha256", "pcmSha256", "engineVersion",
    "buildConfiguration", "routeId", "sampleRate", "channelCount", "frameCount",
    "auditionPath", "auditionSha256", "appliedGainDB",
}
ENVIRONMENT_KEYS = {
    "listenerId", "transducerType", "transducerModel", "connection",
    "roomOrLocation", "outputDevice", "routeId", "sampleRate", "channelCount",
    "levelMethod", "levelReference", "lockedSetting", "calibratedSPLDB",
}
PLAN_KEYS = {
    "schema", "protocolVersion", "sessionId", "purpose", "protocolFingerprint",
    "planFingerprint", "attribute", "attributePrompt", "trialCount",
    "durationLimitMinutes", "environment", "familiarization", "conditionTokens",
    "trials",
}
FAMILIARIZATION_KEYS = {"required", "instruction"}
TRIAL_KEYS = {"id", "repetition", "presentedOrder"}
KEY_KEYS = {
    "schema", "protocolVersion", "sessionId", "planFingerprint", "keyFingerprint",
    "randomizationSeed", "mappings", "revealPolicy",
}
MAPPING_KEYS = {"token", "condition"}
REVEAL_POLICY_KEYS = {"keepSeparateUntilRecorded", "purpose"}
RESULT_KEYS = {
    "schema", "protocolVersion", "sessionId", "purpose", "planFingerprint",
    "resultFingerprint", "status", "method", "observations", "reveal",
    "hypotheses", "qualification", "limitation",
}
METHOD_KEYS = {
    "environment", "actualDurationMinutes", "familiarizationCompleted",
    "levelLocked", "breakAfterTrialIds", "interruptions",
}
OBSERVATION_KEYS = {
    "trialId", "presentedOrder", "completed", "audibility", "preferredToken",
    "confidence", "fatigueAfter", "note",
}
REVEAL_KEYS = {"status", "revealedAtUTC", "keyFingerprint"}
HYPOTHESIS_KEYS = {
    "id", "observationSummary", "checkpoint", "measurableDeficit",
    "automatedComparison", "roadmapDisposition",
}
QUALIFICATION_KEYS = {"boundary", "promotionAuthorized", "qualityRank"}

CANONICAL_VOCABULARIES = {
    "attributes": [
        "groove-coherence", "kick-foundation-separation", "transient-shape",
        "spectral-balance", "stereo-stability", "motif-legibility",
        "transition-clarity", "tension-release", "fatigue-cue", "other-declared",
    ],
    "audibility": ["not-audible", "uncertain", "audible"],
    "confidence": ["low", "medium", "high"],
    "fatigue": ["none", "mild", "stop"],
    "levelMethods": [
        "calibrated-loudspeaker-spl", "locked-device-setting",
        "documented-relative-gain-match",
    ],
    "resultStatuses": ["draft", "observed", "unavailable"],
    "revealStatuses": ["concealed", "revealed"],
    "transducerTypes": ["loudspeakers", "headphones"],
}


class ControlledListeningError(RuntimeError):
    """An actionable protocol or session-package error."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def protocol_path(root: Path) -> Path:
    return root / "docs/CONTROLLED_LISTENING_PROTOCOL.json"


def report_path(root: Path) -> Path:
    return root / "docs/CONTROLLED_LISTENING_PROTOCOL.md"


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ControlledListeningError(f"cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ControlledListeningError(f"{path} must contain one JSON object")
    return value


def canonical_bytes(value: Mapping[str, Any]) -> bytes:
    return json.dumps(
        value, ensure_ascii=True, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")


def fingerprint(value: Mapping[str, Any], excluded: str | None = None) -> str:
    payload = dict(value)
    if excluded is not None:
        payload.pop(excluded, None)
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def file_digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def write_json_atomic(path: Path, value: Mapping[str, Any]) -> None:
    rendered = json.dumps(value, indent=2, ensure_ascii=True, sort_keys=True) + "\n"
    write_text_atomic(path, rendered)


def write_text_atomic(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(
        prefix=path.name + ".", suffix=".tmp", dir=path.parent, text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(contents)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    if set(value) != expected:
        errors.append(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(value)}"
        )


def nonempty(value: object, maximum: int = 500) -> bool:
    return isinstance(value, str) and bool(value.strip()) and len(value) <= maximum


def finite_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def string_array(
    value: object, location: str, errors: list[str], maximum_count: int,
    maximum_length: int = 500,
) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{location} must be an array")
        return []
    if len(value) > maximum_count:
        errors.append(f"{location} exceeds the maximum count {maximum_count}")
    result: list[str] = []
    for index, item in enumerate(value):
        if not nonempty(item, maximum_length):
            errors.append(f"{location}[{index}] must be a bounded non-empty string")
        else:
            result.append(item)
    if len(result) != len(set(result)):
        errors.append(f"{location} must not contain duplicates")
    return result


def validate_protocol(protocol: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    exact_keys(protocol, PROTOCOL_ROOT_KEYS, "protocol", errors)
    if protocol.get("schema") != PROTOCOL_SCHEMA:
        errors.append(f"protocol.schema must be {PROTOCOL_SCHEMA}")
    if protocol.get("protocolVersion") != 1:
        errors.append("protocol.protocolVersion must be 1")

    purpose = protocol.get("purpose")
    if not isinstance(purpose, dict):
        errors.append("protocol.purpose must be an object")
    else:
        exact_keys(purpose, PURPOSE_KEYS, "protocol.purpose", errors)
        if purpose.get("id") != PURPOSE:
            errors.append(f"protocol.purpose.id must be {PURPOSE}")
        if not nonempty(purpose.get("meaning"), 1000):
            errors.append("protocol.purpose.meaning must be bounded text")
        if purpose.get("promotionAuthorized") is not False:
            errors.append("protocol may not authorize promotion")
        if purpose.get("runtimeInputAuthorized") is not False:
            errors.append("protocol may not authorize runtime input")

    limits = protocol.get("limits")
    expected_limits = {
        "minimumTrials": 2, "maximumTrials": 32, "minimumRepetitions": 2,
        "maximumRepetitions": 4, "maximumOrderStreak": 2,
        "maximumSessionMinutes": 45, "maximumNoteCharacters": 2000,
        "maximumHypotheses": 8, "maximumInterruptions": 16, "maximumBreaks": 8,
    }
    if not isinstance(limits, dict):
        errors.append("protocol.limits must be an object")
    else:
        exact_keys(limits, LIMIT_KEYS, "protocol.limits", errors)
        if limits != expected_limits:
            errors.append(f"protocol.limits must be {expected_limits}")

    vocabularies = protocol.get("vocabularies")
    if not isinstance(vocabularies, dict):
        errors.append("protocol.vocabularies must be an object")
    else:
        exact_keys(vocabularies, VOCABULARY_KEYS, "protocol.vocabularies", errors)
        for name, expected in CANONICAL_VOCABULARIES.items():
            if vocabularies.get(name) != expected:
                errors.append(f"protocol.vocabularies.{name} must be {expected}")

    schemas = protocol.get("schemas")
    expected_schemas = {
        "request": REQUEST_SCHEMA, "plan": PLAN_SCHEMA,
        "key": KEY_SCHEMA, "result": RESULT_SCHEMA,
    }
    if not isinstance(schemas, dict):
        errors.append("protocol.schemas must be an object")
    else:
        exact_keys(schemas, SCHEMA_KEYS, "protocol.schemas", errors)
        if schemas != expected_schemas:
            errors.append(f"protocol.schemas must be {expected_schemas}")

    randomization = protocol.get("randomization")
    if not isinstance(randomization, dict):
        errors.append("protocol.randomization must be an object")
    else:
        exact_keys(randomization, RANDOMIZATION_KEYS, "protocol.randomization", errors)
        expected_randomization = {
            "algorithm": "splitmix64-balanced-pair-order.v1",
            "seedScope": "one-local-session",
            "tokenDerivation": "sha256-session-seed-condition.v1",
            "requiresBalancedFirstPosition": True,
            "identityLabelsForbiddenInPlan": True,
        }
        if randomization != expected_randomization:
            errors.append("protocol.randomization is not the canonical v1 contract")

    boundary = protocol.get("qualificationBoundary")
    if not isinstance(boundary, dict):
        errors.append("protocol.qualificationBoundary must be an object")
    else:
        exact_keys(boundary, BOUNDARY_KEYS, "protocol.qualificationBoundary", errors)
        if boundary.get("listeningGateState") != "observed":
            errors.append("listening gate state must remain observed")
        if boundary.get("allowedRoadmapDisposition") != "proposed-not-authorized":
            errors.append("roadmap disposition must remain proposed-not-authorized")
        claims = string_array(
            boundary.get("forbiddenClaims"),
            "protocol.qualificationBoundary.forbiddenClaims", errors, 16, 100,
        )
        if len(claims) < 5:
            errors.append("protocol must retain the five canonical forbidden claims")
    return errors


def normalize_repo_path(value: object, location: str, errors: list[str]) -> str | None:
    if not nonempty(value, 500) or not isinstance(value, str) or "\\" in value:
        errors.append(f"{location} must be a bounded repository-relative path")
        return None
    path = PurePosixPath(value)
    if path.is_absolute() or "." in path.parts or ".." in path.parts:
        errors.append(f"{location} must be repository-relative without traversal")
        return None
    return path.as_posix()


def validate_environment(
    value: object, protocol: Mapping[str, Any], location: str
) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{location} must be an object"]
    exact_keys(value, ENVIRONMENT_KEYS, location, errors)
    for field in (
        "listenerId", "transducerModel", "connection", "roomOrLocation",
        "outputDevice", "routeId", "levelReference", "lockedSetting",
    ):
        if not nonempty(value.get(field), 500):
            errors.append(f"{location}.{field} must be bounded non-empty text")
    vocab = protocol.get("vocabularies", {})
    if value.get("transducerType") not in vocab.get("transducerTypes", []):
        errors.append(f"{location}.transducerType is unsupported")
    if value.get("levelMethod") not in vocab.get("levelMethods", []):
        errors.append(f"{location}.levelMethod is unsupported")
    for field in ("sampleRate", "channelCount"):
        number = value.get(field)
        if isinstance(number, bool) or not isinstance(number, int) or number <= 0:
            errors.append(f"{location}.{field} must be a positive integer")
    spl = value.get("calibratedSPLDB")
    if value.get("levelMethod") == "calibrated-loudspeaker-spl":
        if value.get("transducerType") != "loudspeakers":
            errors.append("calibrated loudspeaker SPL requires loudspeakers")
        if not finite_number(spl) or not 40 <= float(spl) <= 100:
            errors.append(f"{location}.calibratedSPLDB must be 40...100")
    elif spl is not None:
        errors.append(
            f"{location}.calibratedSPLDB must be null without calibrated loudspeaker SPL"
        )
    return errors


def validate_condition(
    value: object, root: Path, location: str, verify_files: bool = True
) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{location} must be an object"]
    exact_keys(value, CONDITION_KEYS, location, errors)
    for field in ("sourceId", "engineVersion", "buildConfiguration", "routeId"):
        if not nonempty(value.get(field), 500):
            errors.append(f"{location}.{field} must be bounded non-empty text")
    for field in ("manifestSha256", "pcmSha256", "auditionSha256"):
        if not isinstance(value.get(field), str) or not HEX64.fullmatch(value[field]):
            errors.append(f"{location}.{field} must be lowercase SHA-256")
    for field in ("sampleRate", "channelCount", "frameCount"):
        number = value.get(field)
        if isinstance(number, bool) or not isinstance(number, int) or number <= 0:
            errors.append(f"{location}.{field} must be a positive integer")
    gain = value.get("appliedGainDB")
    if not finite_number(gain) or not -24 <= float(gain) <= 24:
        errors.append(f"{location}.appliedGainDB must be finite within -24...24")
    manifest = normalize_repo_path(value.get("manifestPath"), f"{location}.manifestPath", errors)
    audition = normalize_repo_path(value.get("auditionPath"), f"{location}.auditionPath", errors)
    if audition is not None and not audition.startswith("docs/local/audio/"):
        errors.append(f"{location}.auditionPath must stay under docs/local/audio")
    if verify_files:
        for field, relative, digest_field in (
            ("manifestPath", manifest, "manifestSha256"),
            ("auditionPath", audition, "auditionSha256"),
        ):
            if relative is None:
                continue
            path = root / relative
            if not path.is_file():
                errors.append(f"{location}.{field} does not exist: {relative}")
            elif HEX64.fullmatch(str(value.get(digest_field, "")) or ""):
                if file_digest(path) != value[digest_field]:
                    errors.append(f"{location}.{digest_field} does not match {relative}")
    return errors


def validate_request(
    request: Mapping[str, Any], protocol: Mapping[str, Any], root: Path,
    verify_files: bool = True,
) -> list[str]:
    errors: list[str] = []
    exact_keys(request, REQUEST_KEYS, "request", errors)
    if request.get("schema") != REQUEST_SCHEMA:
        errors.append(f"request.schema must be {REQUEST_SCHEMA}")
    if request.get("protocolVersion") != 1:
        errors.append("request.protocolVersion must be 1")
    if not isinstance(request.get("sessionId"), str) or not SESSION_ID.fullmatch(request["sessionId"]):
        errors.append("request.sessionId must be 3...64 lowercase letters, digits, or hyphens")
    seed = request.get("randomizationSeed")
    if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed <= MASK64:
        errors.append("request.randomizationSeed must be UInt64")
    vocab = protocol.get("vocabularies", {})
    if request.get("attribute") not in vocab.get("attributes", []):
        errors.append("request.attribute is unsupported")
    if not nonempty(request.get("attributePrompt"), 500):
        errors.append("request.attributePrompt must be bounded non-empty text")
    limits = protocol.get("limits", {})
    repetitions = request.get("repetitions")
    if (
        isinstance(repetitions, bool) or not isinstance(repetitions, int)
        or not limits.get("minimumRepetitions", 2) <= repetitions <= limits.get("maximumRepetitions", 4)
    ):
        errors.append("request.repetitions is outside protocol bounds")
    duration = request.get("durationLimitMinutes")
    if (
        isinstance(duration, bool) or not isinstance(duration, int)
        or not 1 <= duration <= limits.get("maximumSessionMinutes", 45)
    ):
        errors.append("request.durationLimitMinutes is outside protocol bounds")
    first = request.get("conditionOne")
    second = request.get("conditionTwo")
    errors.extend(validate_condition(first, root, "request.conditionOne", verify_files))
    errors.extend(validate_condition(second, root, "request.conditionTwo", verify_files))
    errors.extend(validate_environment(request.get("environment"), protocol, "request.environment"))
    if isinstance(first, dict) and isinstance(second, dict):
        if first.get("pcmSha256") == second.get("pcmSha256"):
            errors.append("request conditions must not have identical PCM identities")
        for field in ("routeId", "sampleRate", "channelCount", "frameCount"):
            if first.get(field) != second.get(field):
                errors.append(f"request conditions must match {field}")
        environment = request.get("environment")
        if isinstance(environment, dict):
            for field in ("routeId", "sampleRate", "channelCount"):
                if environment.get(field) != first.get(field):
                    errors.append(f"request.environment.{field} must match conditions")
    return errors


class SplitMix64:
    def __init__(self, seed: int) -> None:
        self.state = seed & MASK64

    def next(self) -> int:
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK64
        value = self.state
        value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & MASK64
        value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & MASK64
        return (value ^ (value >> 31)) & MASK64


def opaque_id(prefix: str, *parts: object) -> str:
    material = "\x00".join(str(part) for part in parts).encode("utf-8")
    return prefix + hashlib.sha256(material).hexdigest()[:12].upper()


def shuffled_first_positions(repetitions: int, rng: SplitMix64) -> list[int]:
    values = [0, 1] * (repetitions // 2)
    if repetitions % 2:
        values.append(rng.next() & 1)
    for index in range(len(values) - 1, 0, -1):
        other = rng.next() % (index + 1)
        values[index], values[other] = values[other], values[index]
    return values


def create_plan_and_key(
    request: Mapping[str, Any], protocol: Mapping[str, Any]
) -> tuple[dict[str, Any], dict[str, Any]]:
    seed = int(request["randomizationSeed"])
    session = str(request["sessionId"])
    first = request["conditionOne"]
    second = request["conditionTwo"]
    assert isinstance(first, dict) and isinstance(second, dict)
    first_token = opaque_id(
        "C-", session, seed, 0, first["sourceId"], first["pcmSha256"]
    )
    second_token = opaque_id(
        "C-", session, seed, 1, second["sourceId"], second["pcmSha256"]
    )
    rng = SplitMix64(seed)
    positions = shuffled_first_positions(int(request["repetitions"]), rng)
    trials: list[dict[str, Any]] = []
    for repetition, first_position in enumerate(positions, start=1):
        order = (
            [first_token, second_token]
            if first_position == 0 else [second_token, first_token]
        )
        trials.append({
            "id": opaque_id("T-", session, seed, repetition, *order),
            "repetition": repetition,
            "presentedOrder": order,
        })
    plan: dict[str, Any] = {
        "schema": PLAN_SCHEMA,
        "protocolVersion": 1,
        "sessionId": session,
        "purpose": PURPOSE,
        "protocolFingerprint": fingerprint(protocol),
        "planFingerprint": "",
        "attribute": request["attribute"],
        "attributePrompt": request["attributePrompt"],
        "trialCount": len(trials),
        "durationLimitMinutes": request["durationLimitMinutes"],
        "environment": request["environment"],
        "familiarization": {
            "required": True,
            "instruction": "Audition both opaque conditions before recording the first trial; do not reveal the key.",
        },
        "conditionTokens": sorted([first_token, second_token]),
        "trials": trials,
    }
    plan["planFingerprint"] = fingerprint(plan, "planFingerprint")
    key: dict[str, Any] = {
        "schema": KEY_SCHEMA,
        "protocolVersion": 1,
        "sessionId": session,
        "planFingerprint": plan["planFingerprint"],
        "keyFingerprint": "",
        "randomizationSeed": seed,
        "mappings": [
            {"token": first_token, "condition": first},
            {"token": second_token, "condition": second},
        ],
        "revealPolicy": {
            "keepSeparateUntilRecorded": True,
            "purpose": PURPOSE,
        },
    }
    key["keyFingerprint"] = fingerprint(key, "keyFingerprint")
    return plan, key


def max_streak(values: Sequence[str]) -> int:
    maximum = 0
    current = 0
    prior: str | None = None
    for value in values:
        if value == prior:
            current += 1
        else:
            prior = value
            current = 1
        maximum = max(maximum, current)
    return maximum


def validate_plan(plan: Mapping[str, Any], protocol: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    exact_keys(plan, PLAN_KEYS, "plan", errors)
    if plan.get("schema") != PLAN_SCHEMA:
        errors.append(f"plan.schema must be {PLAN_SCHEMA}")
    if plan.get("protocolVersion") != 1:
        errors.append("plan.protocolVersion must be 1")
    if not isinstance(plan.get("sessionId"), str) or not SESSION_ID.fullmatch(plan["sessionId"]):
        errors.append("plan.sessionId is invalid")
    if plan.get("purpose") != PURPOSE:
        errors.append(f"plan.purpose must be {PURPOSE}")
    if plan.get("protocolFingerprint") != fingerprint(protocol):
        errors.append("plan.protocolFingerprint is stale")
    if plan.get("planFingerprint") != fingerprint(plan, "planFingerprint"):
        errors.append("plan.planFingerprint does not match content")
    vocab = protocol.get("vocabularies", {})
    if plan.get("attribute") not in vocab.get("attributes", []):
        errors.append("plan.attribute is unsupported")
    if not nonempty(plan.get("attributePrompt"), 500):
        errors.append("plan.attributePrompt must be bounded non-empty text")
    limits = protocol.get("limits", {})
    trial_count = plan.get("trialCount")
    if (
        isinstance(trial_count, bool) or not isinstance(trial_count, int)
        or not limits.get("minimumTrials", 2) <= trial_count <= limits.get("maximumTrials", 32)
    ):
        errors.append("plan.trialCount is outside protocol bounds")
    duration = plan.get("durationLimitMinutes")
    if (
        isinstance(duration, bool) or not isinstance(duration, int)
        or not 1 <= duration <= limits.get("maximumSessionMinutes", 45)
    ):
        errors.append("plan.durationLimitMinutes is outside protocol bounds")
    errors.extend(validate_environment(plan.get("environment"), protocol, "plan.environment"))
    familiarization = plan.get("familiarization")
    if not isinstance(familiarization, dict):
        errors.append("plan.familiarization must be an object")
    else:
        exact_keys(familiarization, FAMILIARIZATION_KEYS, "plan.familiarization", errors)
        if familiarization.get("required") is not True:
            errors.append("plan familiarization must be required")
        if not nonempty(familiarization.get("instruction"), 500):
            errors.append("plan familiarization instruction must be bounded text")
    tokens = plan.get("conditionTokens")
    if (
        not isinstance(tokens, list) or len(tokens) != 2
        or len(set(str(item) for item in tokens)) != 2
        or any(not isinstance(item, str) or not TOKEN.fullmatch(item) for item in tokens)
    ):
        errors.append("plan.conditionTokens must contain two unique opaque tokens")
        tokens = []
    trials = plan.get("trials")
    if not isinstance(trials, list):
        errors.append("plan.trials must be an array")
        trials = []
    if isinstance(trial_count, int) and len(trials) != trial_count:
        errors.append("plan.trialCount must equal len(plan.trials)")
    ids: list[str] = []
    first_positions: list[str] = []
    repetitions: list[int] = []
    for index, trial in enumerate(trials):
        location = f"plan.trials[{index}]"
        if not isinstance(trial, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(trial, TRIAL_KEYS, location, errors)
        identifier = trial.get("id")
        if not isinstance(identifier, str) or not TRIAL_ID.fullmatch(identifier):
            errors.append(f"{location}.id must be an opaque trial token")
        else:
            ids.append(identifier)
        repetition = trial.get("repetition")
        if isinstance(repetition, bool) or not isinstance(repetition, int) or repetition < 1:
            errors.append(f"{location}.repetition must be positive")
        else:
            repetitions.append(repetition)
        order = trial.get("presentedOrder")
        if (
            not isinstance(order, list) or len(order) != 2
            or any(not isinstance(item, str) for item in order)
            or set(order) != set(tokens)
        ):
            errors.append(f"{location}.presentedOrder must contain both tokens once")
        else:
            first_positions.append(order[0])
    if len(ids) != len(set(ids)):
        errors.append("plan trial IDs must be unique")
    if repetitions != list(range(1, len(trials) + 1)):
        errors.append("plan repetitions must be contiguous and ordered")
    if tokens and first_positions:
        counts = [first_positions.count(token) for token in tokens]
        if abs(counts[0] - counts[1]) > 1:
            errors.append("plan first positions must be balanced")
        if max_streak(first_positions) > limits.get("maximumOrderStreak", 2):
            errors.append("plan first-position streak exceeds the protocol bound")
    return errors


def validate_key(
    key: Mapping[str, Any], protocol: Mapping[str, Any], root: Path,
    verify_files: bool = True,
) -> list[str]:
    errors: list[str] = []
    exact_keys(key, KEY_KEYS, "key", errors)
    if key.get("schema") != KEY_SCHEMA:
        errors.append(f"key.schema must be {KEY_SCHEMA}")
    if key.get("protocolVersion") != 1:
        errors.append("key.protocolVersion must be 1")
    if not isinstance(key.get("sessionId"), str) or not SESSION_ID.fullmatch(key["sessionId"]):
        errors.append("key.sessionId is invalid")
    if not isinstance(key.get("planFingerprint"), str) or not HEX64.fullmatch(key["planFingerprint"]):
        errors.append("key.planFingerprint must be SHA-256")
    if key.get("keyFingerprint") != fingerprint(key, "keyFingerprint"):
        errors.append("key.keyFingerprint does not match content")
    seed = key.get("randomizationSeed")
    if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed <= MASK64:
        errors.append("key.randomizationSeed must be UInt64")
    mappings = key.get("mappings")
    if not isinstance(mappings, list) or len(mappings) != 2:
        errors.append("key.mappings must contain two entries")
        mappings = []
    tokens: list[str] = []
    for index, mapping in enumerate(mappings):
        location = f"key.mappings[{index}]"
        if not isinstance(mapping, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(mapping, MAPPING_KEYS, location, errors)
        token = mapping.get("token")
        if not isinstance(token, str) or not TOKEN.fullmatch(token):
            errors.append(f"{location}.token must be opaque")
        else:
            tokens.append(token)
        errors.extend(validate_condition(mapping.get("condition"), root, f"{location}.condition", verify_files))
    if len(tokens) != len(set(tokens)):
        errors.append("key mapping tokens must be unique")
    reveal = key.get("revealPolicy")
    if not isinstance(reveal, dict):
        errors.append("key.revealPolicy must be an object")
    else:
        exact_keys(reveal, REVEAL_POLICY_KEYS, "key.revealPolicy", errors)
        if reveal.get("keepSeparateUntilRecorded") is not True:
            errors.append("key must remain separate until observations are recorded")
        if reveal.get("purpose") != PURPOSE:
            errors.append(f"key.revealPolicy.purpose must be {PURPOSE}")
    return errors


def new_result(plan: Mapping[str, Any]) -> dict[str, Any]:
    observations = [
        {
            "trialId": trial["id"],
            "presentedOrder": list(trial["presentedOrder"]),
            "completed": False,
            "audibility": "uncertain",
            "preferredToken": "not-assessable",
            "confidence": "low",
            "fatigueAfter": "none",
            "note": "",
        }
        for trial in plan["trials"]
    ]
    result: dict[str, Any] = {
        "schema": RESULT_SCHEMA,
        "protocolVersion": 1,
        "sessionId": plan["sessionId"],
        "purpose": PURPOSE,
        "planFingerprint": plan["planFingerprint"],
        "resultFingerprint": "",
        "status": "draft",
        "method": {
            "environment": plan["environment"],
            "actualDurationMinutes": None,
            "familiarizationCompleted": False,
            "levelLocked": False,
            "breakAfterTrialIds": [],
            "interruptions": [],
        },
        "observations": observations,
        "reveal": {
            "status": "concealed",
            "revealedAtUTC": None,
            "keyFingerprint": None,
        },
        "hypotheses": [],
        "qualification": {
            "boundary": PURPOSE,
            "promotionAuthorized": False,
            "qualityRank": None,
        },
        "limitation": "Listening has not been performed.",
    }
    result["resultFingerprint"] = fingerprint(result, "resultFingerprint")
    return result


def validate_result(
    result: Mapping[str, Any], plan: Mapping[str, Any], protocol: Mapping[str, Any],
    verify_fingerprint: bool = True,
) -> list[str]:
    errors: list[str] = []
    exact_keys(result, RESULT_KEYS, "result", errors)
    if result.get("schema") != RESULT_SCHEMA:
        errors.append(f"result.schema must be {RESULT_SCHEMA}")
    if result.get("protocolVersion") != 1:
        errors.append("result.protocolVersion must be 1")
    if result.get("sessionId") != plan.get("sessionId"):
        errors.append("result.sessionId must match plan")
    if result.get("purpose") != PURPOSE:
        errors.append(f"result.purpose must be {PURPOSE}")
    if result.get("planFingerprint") != plan.get("planFingerprint"):
        errors.append("result.planFingerprint must match plan")
    if verify_fingerprint and result.get("resultFingerprint") != fingerprint(result, "resultFingerprint"):
        errors.append("result.resultFingerprint does not match content")
    vocab = protocol.get("vocabularies", {})
    status = result.get("status")
    if status not in vocab.get("resultStatuses", []):
        errors.append("result.status is unsupported")
    method = result.get("method")
    if not isinstance(method, dict):
        errors.append("result.method must be an object")
        method = {}
    else:
        exact_keys(method, METHOD_KEYS, "result.method", errors)
        errors.extend(validate_environment(method.get("environment"), protocol, "result.method.environment"))
        if method.get("environment") != plan.get("environment"):
            errors.append("result environment must match the listener-facing plan")
        duration = method.get("actualDurationMinutes")
        if status == "draft":
            if duration is not None:
                errors.append("draft result duration must be null")
        else:
            duration_limit = plan.get("durationLimitMinutes")
            if (
                not finite_number(duration) or not finite_number(duration_limit)
                or not 0 < float(duration) <= float(duration_limit)
            ):
                errors.append("terminal result duration must be positive and within the plan limit")
        for field in ("familiarizationCompleted", "levelLocked"):
            if not isinstance(method.get(field), bool):
                errors.append(f"result.method.{field} must be boolean")
        breaks = string_array(
            method.get("breakAfterTrialIds"), "result.method.breakAfterTrialIds",
            errors, protocol.get("limits", {}).get("maximumBreaks", 8), 32,
        )
        trial_ids = [trial.get("id") for trial in plan.get("trials", []) if isinstance(trial, dict)]
        if any(item not in trial_ids for item in breaks):
            errors.append("result breaks must reference plan trials")
        string_array(
            method.get("interruptions"), "result.method.interruptions", errors,
            protocol.get("limits", {}).get("maximumInterruptions", 16), 500,
        )
    observations = result.get("observations")
    if not isinstance(observations, list):
        errors.append("result.observations must be an array")
        observations = []
    trials = plan.get("trials", []) if isinstance(plan.get("trials"), list) else []
    if len(observations) != len(trials):
        errors.append("result must contain one observation per plan trial")
    raw_tokens = plan.get("conditionTokens")
    tokens = {
        item for item in raw_tokens if isinstance(item, str)
    } if isinstance(raw_tokens, list) else set()
    for index, observation in enumerate(observations):
        location = f"result.observations[{index}]"
        if not isinstance(observation, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(observation, OBSERVATION_KEYS, location, errors)
        if index < len(trials) and isinstance(trials[index], dict):
            if observation.get("trialId") != trials[index].get("id"):
                errors.append(f"{location}.trialId must match plan order")
            if observation.get("presentedOrder") != trials[index].get("presentedOrder"):
                errors.append(f"{location}.presentedOrder must match plan")
        if not isinstance(observation.get("completed"), bool):
            errors.append(f"{location}.completed must be boolean")
        if observation.get("audibility") not in vocab.get("audibility", []):
            errors.append(f"{location}.audibility is unsupported")
        if observation.get("confidence") not in vocab.get("confidence", []):
            errors.append(f"{location}.confidence is unsupported")
        if observation.get("fatigueAfter") not in vocab.get("fatigue", []):
            errors.append(f"{location}.fatigueAfter is unsupported")
        preferred = observation.get("preferredToken")
        if preferred not in tokens | {"no-preference", "not-assessable"}:
            errors.append(f"{location}.preferredToken is unsupported")
        note = observation.get("note")
        maximum_note = protocol.get("limits", {}).get("maximumNoteCharacters", 2000)
        if not isinstance(note, str) or len(note) > maximum_note:
            errors.append(f"{location}.note exceeds protocol bounds")
    reveal = result.get("reveal")
    if not isinstance(reveal, dict):
        errors.append("result.reveal must be an object")
        reveal = {}
    else:
        exact_keys(reveal, REVEAL_KEYS, "result.reveal", errors)
        reveal_status = reveal.get("status")
        if reveal_status not in vocab.get("revealStatuses", []):
            errors.append("result.reveal.status is unsupported")
        if reveal_status == "concealed":
            if reveal.get("revealedAtUTC") is not None or reveal.get("keyFingerprint") is not None:
                errors.append("concealed result may not contain reveal identity")
        elif reveal_status == "revealed":
            if not nonempty(reveal.get("revealedAtUTC"), 64):
                errors.append("revealed result requires revealedAtUTC")
            if not isinstance(reveal.get("keyFingerprint"), str) or not HEX64.fullmatch(reveal["keyFingerprint"]):
                errors.append("revealed result requires keyFingerprint")
    hypotheses = result.get("hypotheses")
    if not isinstance(hypotheses, list):
        errors.append("result.hypotheses must be an array")
        hypotheses = []
    maximum_hypotheses = protocol.get("limits", {}).get("maximumHypotheses", 8)
    if len(hypotheses) > maximum_hypotheses:
        errors.append("result.hypotheses exceeds protocol bounds")
    hypothesis_ids: list[str] = []
    for index, hypothesis in enumerate(hypotheses):
        location = f"result.hypotheses[{index}]"
        if not isinstance(hypothesis, dict):
            errors.append(f"{location} must be an object")
            continue
        exact_keys(hypothesis, HYPOTHESIS_KEYS, location, errors)
        for field in (
            "id", "observationSummary", "checkpoint", "measurableDeficit",
            "automatedComparison",
        ):
            if not nonempty(hypothesis.get(field), 1000):
                errors.append(f"{location}.{field} must be bounded non-empty text")
        if isinstance(hypothesis.get("id"), str):
            hypothesis_ids.append(hypothesis["id"])
        if hypothesis.get("roadmapDisposition") != "proposed-not-authorized":
            errors.append(f"{location}.roadmapDisposition must be proposed-not-authorized")
    if len(hypothesis_ids) != len(set(hypothesis_ids)):
        errors.append("result hypothesis IDs must be unique")
    if hypotheses and reveal.get("status") != "revealed":
        errors.append("hypotheses require the key to be revealed after observation")
    qualification = result.get("qualification")
    if not isinstance(qualification, dict):
        errors.append("result.qualification must be an object")
    else:
        exact_keys(qualification, QUALIFICATION_KEYS, "result.qualification", errors)
        if qualification != {
            "boundary": PURPOSE, "promotionAuthorized": False, "qualityRank": None,
        }:
            errors.append("result qualification boundary may not rank or promote audio")
    limitation = result.get("limitation")
    if not isinstance(limitation, str) or len(limitation) > 2000:
        errors.append("result.limitation must be bounded text")
    if status in ("draft", "unavailable") and not nonempty(limitation, 2000):
        errors.append(f"{status} result requires a limitation")
    if status == "observed":
        if not method.get("familiarizationCompleted") or not method.get("levelLocked"):
            errors.append("observed result requires familiarization and locked level")
        if any(not item.get("completed") for item in observations if isinstance(item, dict)):
            errors.append("observed result requires every trial to be completed")
    if status == "unavailable":
        if hypotheses:
            errors.append("unavailable result may not propose hypotheses")
        if any(item.get("completed") for item in observations if isinstance(item, dict)):
            errors.append("unavailable result may not contain completed trials")
    claims = protocol.get("qualificationBoundary", {}).get("forbiddenClaims", [])
    text = json.dumps(result, ensure_ascii=True).lower()
    for claim in claims:
        if str(claim).lower() in text:
            errors.append(f"result contains forbidden promotion claim: {claim}")
    return errors


def validate_package(
    plan: Mapping[str, Any], key: Mapping[str, Any], result: Mapping[str, Any],
    protocol: Mapping[str, Any], root: Path, verify_files: bool = True,
) -> list[str]:
    errors = validate_plan(plan, protocol)
    errors.extend(validate_key(key, protocol, root, verify_files))
    errors.extend(validate_result(result, plan, protocol))
    if key.get("sessionId") != plan.get("sessionId"):
        errors.append("key.sessionId must match plan")
    if key.get("planFingerprint") != plan.get("planFingerprint"):
        errors.append("key.planFingerprint must match plan")
    mappings = key.get("mappings", [])
    mapping_tokens = {
        item.get("token") for item in mappings
        if isinstance(item, dict) and isinstance(item.get("token"), str)
    }
    raw_plan_tokens = plan.get("conditionTokens")
    plan_tokens = {
        item for item in raw_plan_tokens if isinstance(item, str)
    } if isinstance(raw_plan_tokens, list) else set()
    if mapping_tokens != plan_tokens:
        errors.append("key mappings must cover exactly the plan condition tokens")
    reveal = result.get("reveal")
    if isinstance(reveal, dict) and reveal.get("status") == "revealed":
        if reveal.get("keyFingerprint") != key.get("keyFingerprint"):
            errors.append("revealed result keyFingerprint must match key")
    plan_text = json.dumps(plan, ensure_ascii=True, sort_keys=True)
    for mapping in mappings:
        if not isinstance(mapping, dict) or not isinstance(mapping.get("condition"), dict):
            continue
        condition = mapping["condition"]
        for field in (
            "sourceId", "manifestPath", "manifestSha256", "pcmSha256",
            "engineVersion", "buildConfiguration", "auditionPath", "auditionSha256",
        ):
            sensitive = condition.get(field)
            if isinstance(sensitive, str) and sensitive and sensitive in plan_text:
                errors.append(f"listener-facing plan leaks condition {field}")
    return errors


def render_markdown(protocol: Mapping[str, Any]) -> str:
    limits = protocol["limits"]
    vocab = protocol["vocabularies"]
    return f"""# Controlled Listening Protocol

> Generated from `docs/CONTROLLED_LISTENING_PROTOCOL.json`; do not edit by hand.

This local protocol reduces identity, order, and level bias when a listener records
a comparative observation. It is only a hypothesis-discovery aid. It never ranks,
approves, qualifies, or promotes Auto Techno audio, and it never feeds the runtime.

## Bounded session package

A session has three local-only records: a listener-facing plan with opaque tokens,
a separately retained concealed key with exact source/PCM provenance, and a result
record. Keep the key hidden until observations are sealed. The script does not play
audio or alter the application.

| Bound | Value |
|---|---:|
| Trials | {limits['minimumTrials']}–{limits['maximumTrials']} |
| Repetitions of one pair | {limits['minimumRepetitions']}–{limits['maximumRepetitions']} |
| First-position streak | at most {limits['maximumOrderStreak']} |
| Session duration | at most {limits['maximumSessionMinutes']} minutes |
| Observation note | at most {limits['maximumNoteCharacters']} characters |
| Proposed hypotheses | at most {limits['maximumHypotheses']} |

Presentation order uses deterministic balanced SplitMix64 pair order. Determinism
makes the plan reproducible; it does not prove that a listener remained blind.

## Required method record

Record a pseudonymous listener ID, transducer type/model and connection, room or
location, output device and route, sample rate/channel count, level method,
reference and locked setting, familiarization, duration, breaks, interruptions,
actual presented order, audibility, preference/no-preference/not-assessable,
confidence, fatigue cue, and bounded notes. Do not claim calibrated headphone SPL.

Supported level methods: {', '.join(f'`{item}`' for item in vocab['levelMethods'])}.
A calibrated loudspeaker method records a finite 40–100 dB SPL value; other methods
record `null` for SPL and describe the repeatable locked setting or explicit gain
match. Applied audition gain is provenance, not canonical PCM.

## Observation and hypothesis boundary

`observed` means the bounded listening record exists. It does not mean passed.
Candidate identity may be revealed only after observations are recorded. A proposed
hypothesis must name the observation, a score/PCM/evidence checkpoint, a measurable
deficit, and a future automated comparison, with disposition
`proposed-not-authorized`. Only the roadmap discovery process may authorize work.

## Local workflow

```sh
python3 scripts/controlled_listening_protocol.py check
python3 scripts/controlled_listening_protocol.py plan \\
  --request docs/local/reports/listening-sessions/<session>/request.json \\
  --plan-output docs/local/reports/listening-sessions/<session>/plan.json \\
  --key-output docs/local/reports/listening-sessions/<session>/concealed-key.json
python3 scripts/controlled_listening_protocol.py result-template \\
  --plan docs/local/reports/listening-sessions/<session>/plan.json \\
  --output docs/local/reports/listening-sessions/<session>/result.json
python3 scripts/controlled_listening_protocol.py seal-result \\
  --plan docs/local/reports/listening-sessions/<session>/plan.json \\
  --result docs/local/reports/listening-sessions/<session>/result.json
python3 scripts/controlled_listening_protocol.py validate-package \\
  --plan docs/local/reports/listening-sessions/<session>/plan.json \\
  --key docs/local/reports/listening-sessions/<session>/concealed-key.json \\
  --result docs/local/reports/listening-sessions/<session>/result.json
```

All request, plan, key, result, audio, and listener records stay under ignored
`docs/local/`. Do not commit them. No real listening session is required by the
protocol-definition roadmap item.
"""


def load_checked_protocol(root: Path) -> dict[str, Any]:
    protocol = load_json(protocol_path(root))
    errors = validate_protocol(protocol)
    if errors:
        raise ControlledListeningError("invalid protocol: " + "; ".join(errors))
    return protocol


def run_render(root: Path, output: TextIO = sys.stdout) -> int:
    protocol = load_checked_protocol(root)
    write_text_atomic(report_path(root), render_markdown(protocol))
    print("generated docs/CONTROLLED_LISTENING_PROTOCOL.md", file=output)
    return 0


def run_check(root: Path, output: TextIO = sys.stdout) -> int:
    try:
        protocol = load_json(protocol_path(root))
    except ControlledListeningError as exc:
        print(f"controlled listening protocol error: {exc}", file=output)
        return 1
    errors = validate_protocol(protocol)
    expected = render_markdown(protocol) if not errors else None
    try:
        actual = report_path(root).read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"cannot read generated Markdown: {exc}")
        actual = None
    if expected is not None and actual != expected:
        errors.append("generated Markdown is stale; run render")
    if errors:
        print(f"controlled listening protocol rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, start=1):
            print(f"  {index}. {error}", file=output)
        return 1
    print(
        "controlled listening protocol is current: v1, "
        f"{len(protocol['vocabularies']['attributes'])} attributes, "
        f"{protocol['limits']['maximumTrials']} trial maximum",
        file=output,
    )
    return 0


def local_session_output(root: Path, value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = root / path
    resolved = path.resolve()
    allowed = (root / "docs/local/reports/listening-sessions").resolve()
    if resolved == allowed or allowed not in resolved.parents:
        raise ControlledListeningError(
            "session outputs must stay under docs/local/reports/listening-sessions"
        )
    return resolved


def print_errors(label: str, errors: Sequence[str], output: TextIO) -> int:
    if not errors:
        print(f"{label} is valid", file=output)
        return 0
    print(f"{label} rejected with {len(errors)} issue(s):", file=output)
    for index, error in enumerate(errors, start=1):
        print(f"  {index}. {error}", file=output)
    return 1


def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    subparsers.add_parser("render")
    subparsers.add_parser("check")
    plan = subparsers.add_parser("plan")
    plan.add_argument("--request", required=True)
    plan.add_argument("--plan-output", required=True)
    plan.add_argument("--key-output", required=True)
    result = subparsers.add_parser("result-template")
    result.add_argument("--plan", required=True)
    result.add_argument("--output", required=True)
    seal = subparsers.add_parser("seal-result")
    seal.add_argument("--plan", required=True)
    seal.add_argument("--result", required=True)
    validate = subparsers.add_parser("validate-package")
    validate.add_argument("--plan", required=True)
    validate.add_argument("--key", required=True)
    validate.add_argument("--result", required=True)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = parse_arguments(argv)
    root = repository_root()
    try:
        if arguments.mode == "render":
            return run_render(root)
        if arguments.mode == "check":
            return run_check(root)
        protocol = load_checked_protocol(root)
        if arguments.mode == "plan":
            request_path = local_session_output(root, arguments.request)
            plan_path = local_session_output(root, arguments.plan_output)
            key_path = local_session_output(root, arguments.key_output)
            if len({request_path, plan_path, key_path}) != 3:
                raise ControlledListeningError("request, plan, and key paths must differ")
            request = load_json(request_path)
            errors = validate_request(request, protocol, root)
            if errors:
                return print_errors("listening request", errors, sys.stdout)
            plan, key = create_plan_and_key(request, protocol)
            write_json_atomic(plan_path, plan)
            write_json_atomic(key_path, key)
            print(f"generated concealed listening plan: {len(plan['trials'])} trials")
            return 0
        if arguments.mode == "result-template":
            plan_path = local_session_output(root, arguments.plan)
            output_path = local_session_output(root, arguments.output)
            if plan_path == output_path:
                raise ControlledListeningError("plan and result paths must differ")
            plan = load_json(plan_path)
            errors = validate_plan(plan, protocol)
            if errors:
                return print_errors("listening plan", errors, sys.stdout)
            write_json_atomic(output_path, new_result(plan))
            print(f"generated conservative result template: {output_path.relative_to(root)}")
            return 0
        if arguments.mode == "seal-result":
            plan_path = local_session_output(root, arguments.plan)
            result_path = local_session_output(root, arguments.result)
            plan = load_json(plan_path)
            result = load_json(result_path)
            errors = validate_plan(plan, protocol)
            errors.extend(validate_result(result, plan, protocol, verify_fingerprint=False))
            if errors:
                return print_errors("listening result", errors, sys.stdout)
            result["resultFingerprint"] = fingerprint(result, "resultFingerprint")
            write_json_atomic(result_path, result)
            print(f"sealed listening result: {result['resultFingerprint']}")
            return 0
        plan = load_json(local_session_output(root, arguments.plan))
        key = load_json(local_session_output(root, arguments.key))
        result = load_json(local_session_output(root, arguments.result))
        return print_errors(
            "controlled listening package",
            validate_package(plan, key, result, protocol, root),
            sys.stdout,
        )
    except ControlledListeningError as exc:
        print(f"controlled listening protocol error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
