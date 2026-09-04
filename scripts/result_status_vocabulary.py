#!/usr/bin/env python3
"""Validate Auto Techno result records and render their status vocabulary."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Optional, Sequence, TextIO


VOCABULARY_SCHEMA = "autotechno-result-status-vocabulary.v1"
RECORD_SCHEMA = "autotechno-result-record.v1"
STATE_IDS = (
    "not-applicable",
    "unavailable",
    "not-run",
    "in-progress",
    "passed",
    "failed",
    "blocked",
    "observed",
)
GATE_IDS = (
    "implementation",
    "focused-local-verification",
    "full-local-verification",
    "automated-quality-qualification",
    "published-exact-sha",
    "exact-head-ci",
    "release-app-launched",
    "app-route-qa",
    "listening-observation",
    "physical-output-soak",
)
RELEASE_REQUIRED_GATES = tuple(
    gate for gate in GATE_IDS if gate != "listening-observation"
)
ROOT_KEYS = {"schema", "vocabularyVersion", "states", "gates", "claim", "recordSchema"}
STATE_KEYS = {"id", "meaning", "requiresEvidence", "requiresLimitation"}
GATE_KEYS = {"id", "label", "allowedStates", "releaseClaimRequiredState", "meaning"}
CLAIM_KEYS = {"id", "allowedStates", "requiredGates", "ambiguousPhrases", "meaning"}
RECORD_SCHEMA_KEYS = {
    "schema", "requiredRootFields", "requiredGateFields", "requiredClaimFields"
}
RECORD_ROOT_FIELDS = ("schema", "subject", "revision", "summary", "gates", "claim")
RECORD_GATE_FIELDS = ("id", "status", "evidence", "limitation")
RECORD_CLAIM_FIELDS = ("id", "status", "missingGates")


class ResultVocabularyError(RuntimeError):
    """An actionable vocabulary or result-record error."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def vocabulary_path(root: Path) -> Path:
    return root / "docs/RESULT_STATUS_VOCABULARY.json"


def report_path(root: Path) -> Path:
    return root / "docs/RESULT_STATUS_VOCABULARY.md"


def _exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    actual = set(value)
    if actual != expected:
        errors.append(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(actual)}"
        )


def _nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _string_list(value: object, location: str, errors: list[str]) -> list[str]:
    if not isinstance(value, list) or any(not _nonempty_string(item) for item in value):
        errors.append(f"{location} must be an array of non-empty strings")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{location} must not contain duplicates")
    return value


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ResultVocabularyError(f"cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ResultVocabularyError(f"{path} must contain one JSON object")
    return value


def validate_vocabulary(vocabulary: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    _exact_keys(vocabulary, ROOT_KEYS, "vocabulary", errors)
    if vocabulary.get("schema") != VOCABULARY_SCHEMA:
        errors.append(f"vocabulary.schema must be {VOCABULARY_SCHEMA}")
    if vocabulary.get("vocabularyVersion") != 1:
        errors.append("vocabularyVersion must be 1")

    states = vocabulary.get("states")
    if not isinstance(states, list):
        errors.append("states must be an array")
        states = []
    state_ids: list[str] = []
    state_map: dict[str, Mapping[str, Any]] = {}
    for index, state in enumerate(states):
        location = f"states[{index}]"
        if not isinstance(state, dict):
            errors.append(f"{location} must be an object")
            continue
        _exact_keys(state, STATE_KEYS, location, errors)
        identifier = state.get("id")
        if not _nonempty_string(identifier):
            errors.append(f"{location}.id must be a non-empty string")
            continue
        state_ids.append(identifier)
        state_map[identifier] = state
        if not _nonempty_string(state.get("meaning")):
            errors.append(f"{location}.meaning must be a non-empty string")
        for field in ("requiresEvidence", "requiresLimitation"):
            if not isinstance(state.get(field), bool):
                errors.append(f"{location}.{field} must be a boolean")
    if tuple(state_ids) != STATE_IDS:
        errors.append(f"states must use the canonical order {list(STATE_IDS)}")

    gates = vocabulary.get("gates")
    if not isinstance(gates, list):
        errors.append("gates must be an array")
        gates = []
    gate_ids: list[str] = []
    for index, gate in enumerate(gates):
        location = f"gates[{index}]"
        if not isinstance(gate, dict):
            errors.append(f"{location} must be an object")
            continue
        _exact_keys(gate, GATE_KEYS, location, errors)
        identifier = gate.get("id")
        if not _nonempty_string(identifier):
            errors.append(f"{location}.id must be a non-empty string")
            continue
        gate_ids.append(identifier)
        for field in ("label", "meaning"):
            if not _nonempty_string(gate.get(field)):
                errors.append(f"{location}.{field} must be a non-empty string")
        allowed = _string_list(gate.get("allowedStates"), f"{location}.allowedStates", errors)
        unknown = sorted(set(allowed) - set(STATE_IDS))
        if unknown:
            errors.append(f"{location}.allowedStates contains unknown states: {unknown}")
        required_state = gate.get("releaseClaimRequiredState")
        expected_required = (
            "not-a-release-prerequisite"
            if identifier == "listening-observation"
            else "passed"
        )
        if required_state != expected_required:
            errors.append(
                f"{location}.releaseClaimRequiredState must be {expected_required}"
            )
        if identifier == "listening-observation":
            if "observed" not in allowed or "passed" in allowed or "failed" in allowed:
                errors.append(
                    "listening-observation must allow observed and forbid passed/failed"
                )
        elif "observed" in allowed:
            errors.append(f"{location}.allowedStates may not contain observed")
    if tuple(gate_ids) != GATE_IDS:
        errors.append(f"gates must use the canonical order {list(GATE_IDS)}")

    claim = vocabulary.get("claim")
    if not isinstance(claim, dict):
        errors.append("claim must be an object")
    else:
        _exact_keys(claim, CLAIM_KEYS, "claim", errors)
        if claim.get("id") != "professional-release-quality":
            errors.append("claim.id must be professional-release-quality")
        if claim.get("allowedStates") != ["unverified", "verified"]:
            errors.append("claim.allowedStates must be ['unverified', 'verified']")
        if tuple(claim.get("requiredGates", [])) != RELEASE_REQUIRED_GATES:
            errors.append(
                f"claim.requiredGates must be {list(RELEASE_REQUIRED_GATES)}"
            )
        _string_list(claim.get("ambiguousPhrases"), "claim.ambiguousPhrases", errors)
        if not _nonempty_string(claim.get("meaning")):
            errors.append("claim.meaning must be a non-empty string")

    record_schema = vocabulary.get("recordSchema")
    if not isinstance(record_schema, dict):
        errors.append("recordSchema must be an object")
    else:
        _exact_keys(record_schema, RECORD_SCHEMA_KEYS, "recordSchema", errors)
        if record_schema.get("schema") != RECORD_SCHEMA:
            errors.append(f"recordSchema.schema must be {RECORD_SCHEMA}")
        expected_lists = {
            "requiredRootFields": RECORD_ROOT_FIELDS,
            "requiredGateFields": RECORD_GATE_FIELDS,
            "requiredClaimFields": RECORD_CLAIM_FIELDS,
        }
        for field, expected in expected_lists.items():
            if tuple(record_schema.get(field, [])) != expected:
                errors.append(f"recordSchema.{field} must be {list(expected)}")
    return errors


def validate_record(
    record: Mapping[str, Any], vocabulary: Mapping[str, Any]
) -> list[str]:
    errors: list[str] = []
    _exact_keys(record, set(RECORD_ROOT_FIELDS), "record", errors)
    if record.get("schema") != RECORD_SCHEMA:
        errors.append(f"record.schema must be {RECORD_SCHEMA}")
    for field in ("subject", "revision", "summary"):
        if not _nonempty_string(record.get(field)):
            errors.append(f"record.{field} must be a non-empty string")

    state_map = {
        state["id"]: state
        for state in vocabulary.get("states", [])
        if isinstance(state, dict) and isinstance(state.get("id"), str)
    }
    gate_map = {
        gate["id"]: gate
        for gate in vocabulary.get("gates", [])
        if isinstance(gate, dict) and isinstance(gate.get("id"), str)
    }
    gates = record.get("gates")
    if not isinstance(gates, list):
        errors.append("record.gates must be an array")
        gates = []
    record_gate_ids: list[str] = []
    statuses: dict[str, str] = {}
    for index, gate_result in enumerate(gates):
        location = f"record.gates[{index}]"
        if not isinstance(gate_result, dict):
            errors.append(f"{location} must be an object")
            continue
        _exact_keys(gate_result, set(RECORD_GATE_FIELDS), location, errors)
        identifier = gate_result.get("id")
        if not _nonempty_string(identifier):
            errors.append(f"{location}.id must be a non-empty string")
            continue
        record_gate_ids.append(identifier)
        status = gate_result.get("status")
        if not _nonempty_string(status):
            errors.append(f"{location}.status must be a non-empty string")
            continue
        statuses[identifier] = status
        gate_definition = gate_map.get(identifier)
        if gate_definition is None:
            errors.append(f"{location}.id is unknown: {identifier}")
        elif status not in gate_definition.get("allowedStates", []):
            errors.append(f"{location}.status {status!r} is not allowed for {identifier}")
        evidence = _string_list(
            gate_result.get("evidence"), f"{location}.evidence", errors
        )
        limitation = gate_result.get("limitation")
        if not isinstance(limitation, str):
            errors.append(f"{location}.limitation must be a string")
            limitation = ""
        state_definition = state_map.get(status)
        if state_definition is None:
            errors.append(f"{location}.status is unknown: {status}")
        else:
            if state_definition.get("requiresEvidence") and not evidence:
                errors.append(f"{location} status {status} requires evidence")
            if state_definition.get("requiresLimitation") and not limitation.strip():
                errors.append(f"{location} status {status} requires a limitation")
    if tuple(record_gate_ids) != GATE_IDS:
        errors.append(f"record.gates must use every gate once in order: {list(GATE_IDS)}")

    missing_gates = [
        identifier
        for identifier in RELEASE_REQUIRED_GATES
        if statuses.get(identifier) != "passed"
    ]
    claim = record.get("claim")
    claim_status: Optional[str] = None
    if not isinstance(claim, dict):
        errors.append("record.claim must be an object")
    else:
        _exact_keys(claim, set(RECORD_CLAIM_FIELDS), "record.claim", errors)
        if claim.get("id") != "professional-release-quality":
            errors.append("record.claim.id must be professional-release-quality")
        claim_status_value = claim.get("status")
        if claim_status_value not in ("unverified", "verified"):
            errors.append("record.claim.status must be unverified or verified")
        else:
            claim_status = claim_status_value
        recorded_missing = _string_list(
            claim.get("missingGates"), "record.claim.missingGates", errors
        )
        if recorded_missing != missing_gates:
            errors.append(
                "record.claim.missingGates must exactly list unmet objective gates: "
                f"{missing_gates}"
            )
        if claim_status == "verified":
            if missing_gates:
                errors.append(
                    "professional-release-quality cannot be verified while objective gates are unmet"
                )
            if not re.fullmatch(r"[0-9a-f]{40}", str(record.get("revision", ""))):
                errors.append(
                    "a verified professional-release-quality claim requires a 40-digit exact revision"
                )

    summary = str(record.get("summary", "")).lower()
    claim_definition = vocabulary.get("claim", {})
    if isinstance(claim_definition, dict) and claim_status != "verified":
        for phrase in claim_definition.get("ambiguousPhrases", []):
            if isinstance(phrase, str) and phrase.lower() in summary:
                errors.append(
                    f"record.summary uses ambiguous claim phrase {phrase!r} while professional-release-quality is unverified"
                )
    return errors


def new_record(subject: str) -> dict[str, Any]:
    gates: list[dict[str, Any]] = []
    for identifier in GATE_IDS:
        status = "in-progress" if identifier == "implementation" else "not-run"
        gates.append({
            "id": identifier,
            "status": status,
            "evidence": [],
            "limitation": "Implementation is in progress."
            if identifier == "implementation"
            else "This gate has not been run for the working tree.",
        })
    return {
        "schema": RECORD_SCHEMA,
        "subject": subject,
        "revision": "working-tree",
        "summary": "Result record initialized; objective release gates remain unverified.",
        "gates": gates,
        "claim": {
            "id": "professional-release-quality",
            "status": "unverified",
            "missingGates": list(RELEASE_REQUIRED_GATES),
        },
    }


def render_report(vocabulary: Mapping[str, Any]) -> str:
    lines = [
        "# Result Status Vocabulary",
        "",
        "> Generated from `docs/RESULT_STATUS_VOCABULARY.json`; do not edit by hand.",
        "",
        "This vocabulary keeps implementation, verification, automated qualification,",
        "publication/CI, runtime, listening observation, and physical-output soak as",
        "separate results. Passing one never implies another.",
        "",
        "## States",
        "",
        "| State | Evidence required | Limitation required | Meaning |",
        "|---|---:|---:|---|",
    ]
    for state in vocabulary["states"]:
        lines.append(
            f"| `{state['id']}` | {'yes' if state['requiresEvidence'] else 'no'} | "
            f"{'yes' if state['requiresLimitation'] else 'no'} | {state['meaning']} |"
        )
    lines.extend([
        "",
        "## Gates",
        "",
        "| Gate | Allowed states | Professional release requirement | Meaning |",
        "|---|---|---|---|",
    ])
    for gate in vocabulary["gates"]:
        allowed = ", ".join(f"`{state}`" for state in gate["allowedStates"])
        lines.append(
            f"| `{gate['id']}` — {gate['label']} | {allowed} | "
            f"`{gate['releaseClaimRequiredState']}` | {gate['meaning']} |"
        )
    claim = vocabulary["claim"]
    lines.extend([
        "",
        "## Professional release claim",
        "",
        claim["meaning"],
        "",
        "Required objective gates: "
        + ", ".join(f"`{gate}`" for gate in claim["requiredGates"])
        + ".",
        "",
        "Listening is deliberately excluded from the prerequisite list. `observed`",
        "records optional human evidence; it cannot approve or override an automated",
        "failure.",
        "",
        "Validate a result record with:",
        "",
        "```sh",
        "python3 scripts/result_status_vocabulary.py validate-record path/to/result.json",
        "```",
        "",
        "Create a complete conservative skeleton without writing a file:",
        "",
        "```sh",
        "python3 scripts/result_status_vocabulary.py template AT-xxxx",
        "```",
        "",
    ])
    return "\n".join(lines)


def run_render(root: Path, output: TextIO) -> int:
    vocabulary = load_json(vocabulary_path(root))
    errors = validate_vocabulary(vocabulary)
    if errors:
        raise ResultVocabularyError("; ".join(errors))
    report_path(root).write_text(render_report(vocabulary), encoding="utf-8")
    print("rendered result status vocabulary v1", file=output)
    return 0


def run_check(root: Path, output: TextIO) -> int:
    try:
        vocabulary = load_json(vocabulary_path(root))
    except ResultVocabularyError as exc:
        print(f"result vocabulary: {exc}", file=output)
        return 1
    errors = validate_vocabulary(vocabulary)
    expected = render_report(vocabulary) if not errors else ""
    try:
        actual = report_path(root).read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"cannot read generated Markdown: {exc}")
        actual = ""
    if expected and actual != expected:
        errors.append("generated Markdown is stale; run the render command")
    if errors:
        for error in errors:
            print(f"result vocabulary: {error}", file=output)
        return 1
    print(
        f"result status vocabulary is current: v1, {len(STATE_IDS)} states, "
        f"{len(GATE_IDS)} gates",
        file=output,
    )
    return 0


def run_validate_record(root: Path, path: Path, output: TextIO) -> int:
    try:
        vocabulary = load_json(vocabulary_path(root))
        record = load_json(path)
    except ResultVocabularyError as exc:
        print(f"result record: {exc}", file=output)
        return 1
    errors = validate_vocabulary(vocabulary) + validate_record(record, vocabulary)
    if errors:
        for error in errors:
            print(f"result record: {error}", file=output)
        return 1
    print(f"result record is valid: {record['subject']}", file=output)
    return 0


def run_template(subject: str, output: TextIO) -> int:
    if not re.fullmatch(r"AT-[0-9]{4}", subject):
        print("result record: template subject must use AT-xxxx", file=output)
        return 1
    print(json.dumps(new_record(subject), indent=2), file=output)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=("check", "render", "template", "validate-record")
    )
    parser.add_argument("operand", nargs="?")
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = build_parser().parse_args(argv)
    root = repository_root()
    if arguments.command == "render":
        if arguments.operand is not None:
            raise SystemExit("render does not accept a record path")
        return run_render(root, sys.stdout)
    if arguments.command == "check":
        if arguments.operand is not None:
            raise SystemExit("check does not accept a record path")
        return run_check(root, sys.stdout)
    if arguments.command == "template":
        if arguments.operand is None:
            raise SystemExit("template requires an AT-xxxx subject")
        return run_template(arguments.operand, sys.stdout)
    if arguments.operand is None:
        raise SystemExit("validate-record requires a JSON record path")
    return run_validate_record(root, Path(arguments.operand), sys.stdout)


if __name__ == "__main__":
    raise SystemExit(main())
