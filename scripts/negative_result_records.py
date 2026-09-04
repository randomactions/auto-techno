#!/usr/bin/env python3
"""Validate and render durable Auto Techno negative-result records."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence, TextIO


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import source_citation_records  # noqa: E402


SCHEMA_ID = "autotechno-negative-result-schema.v1"
RECORD_ID = "autotechno-negative-result-record.v1"
OUTCOME_CODES = (
    "falsified",
    "inconclusive",
    "invalid-experiment",
    "regressed-protected-behaviour",
    "no-measurable-benefit",
)
FAILURE_REASON_CODES = (
    "hypothesis-disconfirmed",
    "insufficient-evidence",
    "invalid-provenance",
    "guardrail-regression",
    "benefit-below-threshold",
    "resource-bound-exceeded",
)
DISPOSITIONS = ("retired", "superseded", "follow-up-proposed")
EVIDENCE_KINDS = (
    "measurement",
    "test",
    "render-comparison",
    "runtime-observation",
    "listening-observation",
    "source-analysis",
)
SCHEMA_KEYS = {
    "schema", "schemaVersion", "outcomeCodes", "failureReasonCodes",
    "dispositions", "evidenceKinds", "recordSchema",
}
RECORD_SCHEMA_KEYS = {
    "schema", "requiredRootFields", "requiredBaselineFields",
    "requiredInterventionFields", "requiredEvidenceFields",
    "requiredOutcomeFields", "requiredFollowUpFields", "localRecordPattern",
}
ROOT_FIELDS = (
    "schema", "itemId", "planPath", "citationRecordPath", "experimentId",
    "title", "createdDate", "concludedDate", "hypothesis", "canonicalOwner",
    "checkpoint", "baseline", "intervention", "bounds", "evidence", "outcome",
    "failureReason", "learnedConstraints", "reusableEvidence", "disposition",
    "replacementItem", "followUp",
)
BASELINE_FIELDS = ("description", "identity", "evidenceRefs")
INTERVENTION_FIELDS = ("description", "identity", "changedVariables")
EVIDENCE_FIELDS = ("id", "kind", "reference", "observation")
OUTCOME_FIELDS = ("code", "summary")
FOLLOW_UP_FIELDS = ("status", "proposedOutcome", "condition")


class NegativeResultError(RuntimeError):
    """An actionable negative-result schema or record error."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def schema_path(root: Path) -> Path:
    return root / "docs/NEGATIVE_RESULT_SCHEMA.json"


def report_path(root: Path) -> Path:
    return root / "docs/NEGATIVE_RESULT_SCHEMA.md"


def _exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str, errors: list[str]
) -> None:
    actual = set(value)
    if actual != expected:
        errors.append(
            f"{location} fields must be exactly {sorted(expected)}; "
            f"found {sorted(actual)}"
        )


def _nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _nonempty_string_list(
    value: object, location: str, errors: list[str]
) -> list[str]:
    if not isinstance(value, list) or not value or any(not _nonempty(item) for item in value):
        errors.append(f"{location} must be a non-empty array of non-empty strings")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{location} must not contain duplicates")
    return value


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise NegativeResultError(f"cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise NegativeResultError(f"{path} must contain one JSON object")
    return value


def validate_schema(schema: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    _exact_keys(schema, SCHEMA_KEYS, "schema", errors)
    if schema.get("schema") != SCHEMA_ID:
        errors.append(f"schema.schema must be {SCHEMA_ID}")
    if schema.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    expected_arrays = {
        "outcomeCodes": OUTCOME_CODES,
        "failureReasonCodes": FAILURE_REASON_CODES,
        "dispositions": DISPOSITIONS,
        "evidenceKinds": EVIDENCE_KINDS,
    }
    for field, expected in expected_arrays.items():
        if tuple(schema.get(field, [])) != expected:
            errors.append(f"{field} must be exactly {list(expected)}")
    record_schema = schema.get("recordSchema")
    if not isinstance(record_schema, dict):
        errors.append("recordSchema must be an object")
        return errors
    _exact_keys(record_schema, RECORD_SCHEMA_KEYS, "recordSchema", errors)
    if record_schema.get("schema") != RECORD_ID:
        errors.append(f"recordSchema.schema must be {RECORD_ID}")
    expected_fields = {
        "requiredRootFields": ROOT_FIELDS,
        "requiredBaselineFields": BASELINE_FIELDS,
        "requiredInterventionFields": INTERVENTION_FIELDS,
        "requiredEvidenceFields": EVIDENCE_FIELDS,
        "requiredOutcomeFields": OUTCOME_FIELDS,
        "requiredFollowUpFields": FOLLOW_UP_FIELDS,
    }
    for field, expected in expected_fields.items():
        if tuple(record_schema.get(field, [])) != expected:
            errors.append(f"recordSchema.{field} must be {list(expected)}")
    if record_schema.get("localRecordPattern") != (
        "docs/local/reports/negative-results/NEG-AT-xxxx-nnn.json"
    ):
        errors.append("recordSchema.localRecordPattern is not canonical")
    return errors


def _safe_reference(reference: str, root: Path) -> Optional[str]:
    prefix = next((prefix for prefix in ("repo:", "local:") if reference.startswith(prefix)), None)
    if prefix is None:
        return None
    value = reference.removeprefix(prefix)
    if "\\" in value:
        return None
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or "." in path.parts or ".." in path.parts:
        return None
    normalized = path.as_posix()
    if prefix == "local:" and not normalized.startswith("docs/local/"):
        return None
    destination = root / normalized
    if destination.is_symlink() or not destination.is_file():
        return None
    return normalized


def validate_record(
    record: Mapping[str, Any],
    schema: Mapping[str, Any],
    root: Path,
    record_path: Optional[Path] = None,
) -> list[str]:
    errors: list[str] = []
    _exact_keys(record, set(ROOT_FIELDS), "record", errors)
    if record.get("schema") != RECORD_ID:
        errors.append(f"record.schema must be {RECORD_ID}")
    item_id = record.get("itemId")
    if not isinstance(item_id, str) or re.fullmatch(r"AT-[0-9]{4}", item_id) is None:
        errors.append("record.itemId must use AT-xxxx")
        item_id = ""
    expected_plan = f"docs/local/roadmap-plans/{item_id}.md"
    if record.get("planPath") != expected_plan:
        errors.append(f"record.planPath must be {expected_plan}")
    elif not (root / expected_plan).is_file():
        errors.append(f"record plan is missing: {expected_plan}")
    expected_citations = f"docs/local/reports/source-citations/{item_id}.json"
    if record.get("citationRecordPath") != expected_citations:
        errors.append(f"record.citationRecordPath must be {expected_citations}")
    else:
        citation_path = root / expected_citations
        try:
            citation_schema = source_citation_records.load_json(
                source_citation_records.schema_path(root)
            )
            citation_record = source_citation_records.load_json(citation_path)
        except source_citation_records.SourceCitationError as exc:
            errors.append(f"citation record is unavailable: {exc}")
        else:
            citation_errors = source_citation_records.validate_record(
                citation_record, citation_schema, root, citation_path
            )
            errors.extend(f"citation: {error}" for error in citation_errors)

    experiment_id = record.get("experimentId")
    if not isinstance(experiment_id, str) or re.fullmatch(
        rf"NEG-{re.escape(item_id)}-[0-9]{{3}}", experiment_id
    ) is None:
        errors.append(f"record.experimentId must use NEG-{item_id}-nnn")
        experiment_id = ""
    if record_path is not None and record_path.name != f"{experiment_id}.json":
        errors.append(f"negative-result filename must be {experiment_id}.json")
    for field in ("title", "hypothesis", "canonicalOwner", "checkpoint"):
        if not _nonempty(record.get(field)):
            errors.append(f"record.{field} must be a non-empty string")
    try:
        created = date.fromisoformat(str(record.get("createdDate", "")))
        concluded = date.fromisoformat(str(record.get("concludedDate", "")))
        if concluded < created:
            errors.append("record.concludedDate must not precede createdDate")
    except ValueError:
        errors.append("record dates must use valid YYYY-MM-DD values")

    baseline = record.get("baseline")
    if not isinstance(baseline, dict):
        errors.append("record.baseline must be an object")
        baseline = {}
    else:
        _exact_keys(baseline, set(BASELINE_FIELDS), "record.baseline", errors)
    for field in ("description", "identity"):
        if not _nonempty(baseline.get(field)):
            errors.append(f"record.baseline.{field} must be a non-empty string")
    baseline_refs = _nonempty_string_list(
        baseline.get("evidenceRefs"), "record.baseline.evidenceRefs", errors
    )

    intervention = record.get("intervention")
    if not isinstance(intervention, dict):
        errors.append("record.intervention must be an object")
        intervention = {}
    else:
        _exact_keys(
            intervention, set(INTERVENTION_FIELDS), "record.intervention", errors
        )
    for field in ("description", "identity"):
        if not _nonempty(intervention.get(field)):
            errors.append(f"record.intervention.{field} must be a non-empty string")
    _nonempty_string_list(
        intervention.get("changedVariables"),
        "record.intervention.changedVariables",
        errors,
    )
    _nonempty_string_list(record.get("bounds"), "record.bounds", errors)

    evidence = record.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        errors.append("record.evidence must be a non-empty array")
        evidence = []
    evidence_ids: list[str] = []
    for index, entry in enumerate(evidence, start=1):
        location = f"record.evidence[{index - 1}]"
        if not isinstance(entry, dict):
            errors.append(f"{location} must be an object")
            continue
        _exact_keys(entry, set(EVIDENCE_FIELDS), location, errors)
        expected_id = f"EVD-{index:03d}"
        if entry.get("id") != expected_id:
            errors.append(f"{location}.id must be {expected_id}")
        evidence_ids.append(str(entry.get("id", "")))
        if entry.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{location}.kind is unsupported")
        reference = entry.get("reference")
        if not isinstance(reference, str) or _safe_reference(reference, root) is None:
            errors.append(
                f"{location}.reference must name an existing safe repo: or local: file"
            )
        if not _nonempty(entry.get("observation")):
            errors.append(f"{location}.observation must be a non-empty string")
    if len(evidence_ids) != len(set(evidence_ids)):
        errors.append("record evidence ids must be unique")
    unknown_baseline_refs = sorted(set(baseline_refs) - set(evidence_ids))
    if unknown_baseline_refs:
        errors.append(
            "record.baseline.evidenceRefs names unknown evidence: "
            + ", ".join(unknown_baseline_refs)
        )

    for field in ("outcome", "failureReason"):
        value = record.get(field)
        if not isinstance(value, dict):
            errors.append(f"record.{field} must be an object")
            continue
        _exact_keys(value, set(OUTCOME_FIELDS), f"record.{field}", errors)
        if not _nonempty(value.get("summary")):
            errors.append(f"record.{field}.summary must be a non-empty string")
    outcome = record.get("outcome", {})
    failure_reason = record.get("failureReason", {})
    outcome_code = outcome.get("code") if isinstance(outcome, dict) else None
    reason_code = (
        failure_reason.get("code") if isinstance(failure_reason, dict) else None
    )
    if outcome_code not in OUTCOME_CODES:
        errors.append("record.outcome.code is unsupported")
    if reason_code not in FAILURE_REASON_CODES:
        errors.append("record.failureReason.code is unsupported")
    _nonempty_string_list(
        record.get("learnedConstraints"), "record.learnedConstraints", errors
    )
    _nonempty_string_list(
        record.get("reusableEvidence"), "record.reusableEvidence", errors
    )

    disposition = record.get("disposition")
    if disposition not in DISPOSITIONS:
        errors.append("record.disposition is unsupported")
    replacement = record.get("replacementItem")
    if not isinstance(replacement, str):
        errors.append("record.replacementItem must be a string")
        replacement = ""
    follow_up = record.get("followUp")
    if not isinstance(follow_up, dict):
        errors.append("record.followUp must be an object")
        follow_up = {}
    else:
        _exact_keys(follow_up, set(FOLLOW_UP_FIELDS), "record.followUp", errors)
    follow_status = follow_up.get("status")
    proposed = follow_up.get("proposedOutcome")
    condition = follow_up.get("condition")
    if follow_status not in ("none", "proposed"):
        errors.append("record.followUp.status must be none or proposed")
    for field, value in (("proposedOutcome", proposed), ("condition", condition)):
        if not isinstance(value, str):
            errors.append(f"record.followUp.{field} must be a string")

    if disposition == "retired":
        if replacement or follow_status != "none" or proposed or condition:
            errors.append("retired disposition forbids replacement and follow-up")
    elif disposition == "superseded":
        if re.fullmatch(r"AT-[0-9]{4}", replacement) is None:
            errors.append("superseded disposition requires replacementItem AT-xxxx")
        if follow_status != "none" or proposed or condition:
            errors.append("superseded disposition forbids a proposed follow-up")
    elif disposition == "follow-up-proposed":
        if replacement:
            errors.append("follow-up-proposed disposition forbids replacementItem")
        if follow_status != "proposed" or not _nonempty(proposed) or not _nonempty(condition):
            errors.append(
                "follow-up-proposed disposition requires bounded proposedOutcome and condition"
            )
    if outcome_code == "inconclusive" and reason_code == "hypothesis-disconfirmed":
        errors.append("inconclusive outcome cannot claim hypothesis-disconfirmed")
    return errors


def new_template(item_id: str, ordinal: int = 1) -> dict[str, Any]:
    experiment_id = f"NEG-{item_id}-{ordinal:03d}"
    return {
        "schema": RECORD_ID,
        "itemId": item_id,
        "planPath": f"docs/local/roadmap-plans/{item_id}.md",
        "citationRecordPath": f"docs/local/reports/source-citations/{item_id}.json",
        "experimentId": experiment_id,
        "title": "",
        "createdDate": "",
        "concludedDate": "",
        "hypothesis": "",
        "canonicalOwner": "",
        "checkpoint": "",
        "baseline": {"description": "", "identity": "", "evidenceRefs": []},
        "intervention": {
            "description": "",
            "identity": "",
            "changedVariables": [],
        },
        "bounds": [],
        "evidence": [],
        "outcome": {"code": "", "summary": ""},
        "failureReason": {"code": "", "summary": ""},
        "learnedConstraints": [],
        "reusableEvidence": [],
        "disposition": "",
        "replacementItem": "",
        "followUp": {"status": "none", "proposedOutcome": "", "condition": ""},
    }


def render_report(schema: Mapping[str, Any]) -> str:
    lines = [
        "# Negative Result Schema",
        "",
        "> Generated from `docs/NEGATIVE_RESULT_SCHEMA.json`; do not edit by hand.",
        "",
        "A negative result preserves a falsifiable hypothesis, exact baseline and",
        "intervention, bounded evidence, reason-coded outcome, learned constraints,",
        "reusable evidence, and scheduling disposition. It never edits the roadmap",
        "or declares its own result.",
        "",
        "## Outcome and disposition vocabulary",
        "",
        "- Outcomes: " + ", ".join(f"`{value}`" for value in schema["outcomeCodes"]),
        "- Failure reasons: "
        + ", ".join(f"`{value}`" for value in schema["failureReasonCodes"]),
        "- Dispositions: "
        + ", ".join(f"`{value}`" for value in schema["dispositions"]),
        "- Evidence kinds: "
        + ", ".join(f"`{value}`" for value in schema["evidenceKinds"]),
        "",
        "Records live under `docs/local/reports/negative-results/` and bind the",
        "same item's plan and checked citation record. Evidence references must be",
        "existing safe `repo:path` or `local:docs/local/...` files.",
        "",
        "```sh",
        "python3 scripts/negative_result_records.py check",
        "python3 scripts/negative_result_records.py template AT-xxxx",
        "python3 scripts/negative_result_records.py validate-record path/to/NEG-AT-xxxx-nnn.json",
        "```",
        "",
    ]
    return "\n".join(lines)


def run_render(root: Path, output: TextIO) -> int:
    schema = load_json(schema_path(root))
    errors = validate_schema(schema)
    if errors:
        raise NegativeResultError("; ".join(errors))
    report_path(root).write_text(render_report(schema), encoding="utf-8")
    print("rendered negative result schema v1", file=output)
    return 0


def run_check(root: Path, output: TextIO) -> int:
    try:
        schema = load_json(schema_path(root))
    except NegativeResultError as exc:
        print(f"negative results: {exc}", file=output)
        return 1
    errors = validate_schema(schema)
    expected = render_report(schema) if not errors else ""
    try:
        actual = report_path(root).read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"cannot read generated Markdown: {exc}")
        actual = ""
    if expected and actual != expected:
        errors.append("generated Markdown is stale; run the render command")
    if errors:
        for error in errors:
            print(f"negative results: {error}", file=output)
        return 1
    print(
        f"negative result schema is current: v1, {len(OUTCOME_CODES)} outcomes, "
        f"{len(DISPOSITIONS)} dispositions",
        file=output,
    )
    return 0


def run_validate_record(root: Path, path: Path, output: TextIO) -> int:
    try:
        schema = load_json(schema_path(root))
        record = load_json(path)
    except NegativeResultError as exc:
        print(f"negative results: {exc}", file=output)
        return 1
    errors = validate_schema(schema) + validate_record(record, schema, root, path)
    if errors:
        for error in errors:
            print(f"negative results: {error}", file=output)
        return 1
    print(f"negative result record is valid: {record['experimentId']}", file=output)
    return 0


def run_template(item_id: str, output: TextIO) -> int:
    if re.fullmatch(r"AT-[0-9]{4}", item_id) is None:
        print("negative results: template item must use AT-xxxx", file=output)
        return 1
    print(json.dumps(new_template(item_id), indent=2), file=output)
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
            raise SystemExit("render does not accept an operand")
        return run_render(root, sys.stdout)
    if arguments.command == "check":
        if arguments.operand is not None:
            raise SystemExit("check does not accept an operand")
        return run_check(root, sys.stdout)
    if arguments.command == "template":
        if arguments.operand is None:
            raise SystemExit("template requires AT-xxxx")
        return run_template(arguments.operand, sys.stdout)
    if arguments.operand is None:
        raise SystemExit("validate-record requires a JSON path")
    return run_validate_record(root, Path(arguments.operand), sys.stdout)


if __name__ == "__main__":
    raise SystemExit(main())
