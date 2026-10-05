#!/usr/bin/env python3
"""Validate Auto Techno's local autonomous roadmap and dependency graph."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Optional, Sequence, TextIO

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import result_status_vocabulary as results  # noqa: E402


ROADMAP_PATH = Path("docs/local/SYNTH_FX_DSP_RESEARCH_STUDY.md")
CONTROLLER_KEYS = (
    "roadmap_schema",
    "roadmap_status",
    "roadmap_revision",
    "last_updated_utc",
    "active_item",
    "active_plan",
    "last_completed_item",
    "selection_policy",
    "maximum_concurrent_items",
    "discovery_inbox_open",
    "quality_claim",
    "local_only",
)
ALLOWED_STATUSES = (
    "queued",
    "researching",
    "planning",
    "implementing",
    "qualifying",
    "completed",
    "verified-no-change",
    "blocked",
    "retired",
    "superseded",
)
ACTIVE_STATUSES = {"researching", "planning", "implementing", "qualifying"}
ITEM_ID_PATTERN = re.compile(r"AT-([0-9]{4})")


@dataclass(frozen=True)
class RoadmapItem:
    identifier: str
    status: str
    dependencies: tuple[str, ...]
    outcome: str
    evidence: str
    line: int


class RoadmapIntegrityError(RuntimeError):
    """An actionable roadmap parsing error."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _section(text: str, heading: str, next_heading: str) -> str:
    start_marker = f"## {heading}"
    end_marker = f"## {next_heading}"
    start = text.find(start_marker)
    if start < 0:
        raise RoadmapIntegrityError(f"missing section: {start_marker}")
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise RoadmapIntegrityError(f"missing section boundary: {end_marker}")
    return text[start:end]


def parse_controller(text: str) -> dict[str, str]:
    section = _section(
        text,
        "Control C — Machine-readable roadmap controller",
        "Control D — Status model and autonomous selection",
    )
    match = re.search(r"```yaml\n(.*?)\n```", section, flags=re.DOTALL)
    if match is None:
        raise RoadmapIntegrityError("Control C must contain one fenced yaml block")
    values: dict[str, str] = {}
    for line in match.group(1).splitlines():
        key, separator, value = line.partition(":")
        if not separator or not key.strip() or not value.strip():
            raise RoadmapIntegrityError(f"invalid Control C line: {line!r}")
        normalized_key = key.strip()
        if normalized_key in values:
            raise RoadmapIntegrityError(f"duplicate Control C key: {normalized_key}")
        values[normalized_key] = value.strip()
    return values


def parse_statuses(text: str) -> tuple[str, ...]:
    section = _section(
        text,
        "Control D — Status model and autonomous selection",
        "Control E — One-item autonomous work cycle",
    )
    return tuple(
        match.group(1)
        for match in re.finditer(r"^\| `([^`]+)` \|", section, flags=re.MULTILINE)
    )


def parse_items(text: str) -> tuple[list[RoadmapItem], list[str]]:
    items: list[RoadmapItem] = []
    errors: list[str] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line.startswith("| AT-"):
            continue
        columns = [column.strip() for column in line.split("|")[1:-1]]
        if len(columns) != 5:
            errors.append(
                f"line {line_number}: executable item row must have exactly five columns"
            )
            continue
        identifier, status_token, dependency_token, outcome, evidence = columns
        if ITEM_ID_PATTERN.fullmatch(identifier) is None:
            errors.append(f"line {line_number}: invalid item id {identifier!r}")
            continue
        status_match = re.fullmatch(r"`([^`]+)`", status_token)
        if status_match is None:
            errors.append(f"line {line_number}: status must be one backtick token")
            continue
        if dependency_token == "—":
            dependencies: tuple[str, ...] = ()
        else:
            dependencies = tuple(
                dependency.strip() for dependency in dependency_token.split(",")
            )
        items.append(RoadmapItem(
            identifier=identifier,
            status=status_match.group(1),
            dependencies=dependencies,
            outcome=outcome,
            evidence=evidence,
            line=line_number,
        ))
    return items, errors


def _cycle_errors(items: Mapping[str, RoadmapItem]) -> list[str]:
    errors: list[str] = []
    state: dict[str, int] = {}
    stack: list[str] = []

    def visit(identifier: str) -> None:
        marker = state.get(identifier, 0)
        if marker == 2:
            return
        if marker == 1:
            index = stack.index(identifier)
            cycle = stack[index:] + [identifier]
            diagnostic = "dependency cycle: " + " -> ".join(cycle)
            if diagnostic not in errors:
                errors.append(diagnostic)
            return
        state[identifier] = 1
        stack.append(identifier)
        item = items[identifier]
        for dependency in item.dependencies:
            if dependency in items:
                visit(dependency)
        stack.pop()
        state[identifier] = 2

    for identifier in sorted(items):
        visit(identifier)
    return errors


def current_clean_revision(root: Path) -> Optional[str]:
    """No reuse authority exists for no-change receipts: require the clean exact source."""
    try:
        command = ["git", "-c", "core.fsmonitor=false", "-C", str(root)]
        revision = subprocess.check_output(
            command + ["rev-parse", "HEAD"], text=True,
            stderr=subprocess.DEVNULL, timeout=10,
        ).strip()
        dirty = subprocess.check_output(
            command + ["status", "--porcelain", "--untracked-files=normal"],
            text=True, stderr=subprocess.DEVNULL, timeout=10,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return None
    return revision if not dirty and re.fullmatch(r"[0-9a-f]{40}", revision) else None


def no_change_scope_fingerprint(item: RoadmapItem, root: Path) -> str:
    """Bind ignored acceptance scope as well as immutable tracked source."""
    plan = root / f"docs/local/roadmap-plans/{item.identifier}.md"
    if not plan.resolve().is_relative_to(root.resolve()):
        raise RoadmapIntegrityError("no-change acceptance plan must remain inside the repository")
    try:
        plan_digest = hashlib.sha256(plan.read_bytes()).hexdigest()
    except OSError as exc:
        raise RoadmapIntegrityError("cannot read no-change acceptance plan") from exc
    scope = {
        "item": item.identifier,
        "outcome": item.outcome,
        "dependencies": list(item.dependencies),
        "planSha256": plan_digest,
    }
    encoded = json.dumps(scope, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def no_change_receipt_errors(
    item: RoadmapItem, root: Path, revision: Optional[str]
) -> list[str]:
    """Validate complete current evidence before a no-change row satisfies a dependency."""
    path = f"docs/local/result-records/{item.identifier}.json"
    prefix = f"{item.identifier} verified-no-change"
    if re.search(r"\[[^\]\n]+\]\(" + re.escape(path) + r"\)", item.evidence) is None:
        return [f"{prefix} must link its result receipt {path}"]
    # Receipts are private, but neither a symlink nor a missing file may bind
    # another repository's qualification to this row.
    destination = root / path
    if not destination.resolve().is_relative_to(root.resolve()):
        return [f"{prefix} receipt must remain inside the repository"]
    try:
        record = results.load_json(destination)
        vocabulary = results.load_json(results.vocabulary_path(root))
    except results.ResultVocabularyError as exc:
        return [f"{prefix}: {exc}"]
    try:
        errors = results.validate_vocabulary(vocabulary)
        if not errors:
            errors.extend(results.validate_record(record, vocabulary))
    except (TypeError, ValueError):
        return [f"{prefix}: malformed receipt or vocabulary"]
    if errors:
        return [f"{prefix}: {error}" for error in errors]
    if record.get("subject") != item.identifier:
        errors.append("receipt subject must match the roadmap item")
    if revision is None or record.get("revision") != revision:
        errors.append("receipt must match the current clean exact source revision; stale reuse is unavailable")
    try:
        scope_marker = "roadmap-scope-sha256:" + no_change_scope_fingerprint(item, root)
    except RoadmapIntegrityError as exc:
        errors.append(str(exc))
    else:
        focused = next(gate for gate in record["gates"] if gate["id"] == "focused-local-verification")
        evidence = focused["evidence"]
        if scope_marker not in evidence:
            errors.append("receipt must bind the current outcome, dependencies and acceptance plan scope")
        if not any(not value.startswith("roadmap-scope-sha256:") for value in evidence):
            errors.append("receipt scope binding is not measured verification evidence")
    statuses = {
        gate.get("id"): gate.get("status")
        for gate in record.get("gates", [])
        if isinstance(gate, dict)
    } if isinstance(record.get("gates"), list) else {}
    for gate in ("implementation", "focused-local-verification", "full-local-verification",
                 "automated-quality-qualification"):
        if statuses.get(gate) != "passed":
            errors.append(f"receipt requires passed {gate}")
    for gate in results.RELEASE_REQUIRED_GATES:
        release_only = gate in (
            "published-exact-sha", "exact-head-ci", "release-app-launched",
            "app-route-qa", "physical-output-soak",
        )
        if statuses.get(gate) != "passed" and not (
                release_only and statuses.get(gate) == "not-applicable"):
            errors.append(f"receipt has an unmet applicable gate: {gate}")
    # Listening stays optional hypothesis evidence; it never authorizes completion.
    return [f"{prefix}: {error}" for error in errors]


def validate_roadmap(text: str, root: Path) -> list[str]:
    errors: list[str] = []
    try:
        controller = parse_controller(text)
    except RoadmapIntegrityError as exc:
        return [str(exc)]
    actual_controller_keys = tuple(controller)
    if actual_controller_keys != CONTROLLER_KEYS:
        errors.append(
            "Control C keys must be exactly and in order: "
            + ", ".join(CONTROLLER_KEYS)
        )

    try:
        statuses = parse_statuses(text)
    except RoadmapIntegrityError as exc:
        errors.append(str(exc))
        statuses = ()
    if statuses != ALLOWED_STATUSES:
        errors.append(
            "Control D statuses must be exactly and in order: "
            + ", ".join(ALLOWED_STATUSES)
        )

    items, parse_errors = parse_items(text)
    errors.extend(parse_errors)
    identifiers = [item.identifier for item in items]
    duplicates = sorted(
        identifier for identifier in set(identifiers) if identifiers.count(identifier) > 1
    )
    if duplicates:
        errors.append("duplicate item ids: " + ", ".join(duplicates))
    item_map = {item.identifier: item for item in items}
    if not items:
        errors.append("roadmap has no executable AT-xxxx items")
    else:
        maximum = max(int(identifier.removeprefix("AT-")) for identifier in item_map)
        expected = [f"AT-{number:04d}" for number in range(1, maximum + 1)]
        if sorted(item_map) != expected:
            missing = sorted(set(expected) - set(item_map))
            errors.append(
                "item ids must be contiguous from AT-0001; missing: "
                + (", ".join(missing) if missing else "none")
            )

    for item in items:
        if item.status not in ALLOWED_STATUSES:
            errors.append(
                f"line {item.line}: {item.identifier} has invalid status {item.status!r}"
            )
        if len(item.dependencies) != len(set(item.dependencies)):
            errors.append(f"{item.identifier} has duplicate dependencies")
        for dependency in item.dependencies:
            if ITEM_ID_PATTERN.fullmatch(dependency) is None:
                errors.append(f"{item.identifier} has invalid dependency token {dependency!r}")
            elif dependency == item.identifier:
                errors.append(f"{item.identifier} depends on itself")
            elif dependency not in item_map:
                errors.append(f"{item.identifier} depends on missing item {dependency}")
    errors.extend(_cycle_errors(item_map))

    satisfied = {item.identifier for item in items if item.status == "completed"}
    no_change_items = [item for item in items if item.status == "verified-no-change"]
    revision = current_clean_revision(root) if no_change_items else None
    qualified_no_change: dict[str, RoadmapItem] = {}
    for item in no_change_items:
        receipt_errors = no_change_receipt_errors(item, root, revision)
        errors.extend(receipt_errors)
        if not receipt_errors:
            qualified_no_change[item.identifier] = item
    # Resolve eligible chains to a fixed point: ID order need not be topological.
    # A current receipt cannot waive that row's own unfinished prerequisites.
    while qualified_no_change:
        eligible_no_change = [
            identifier for identifier, item in qualified_no_change.items()
            if all(dependency in satisfied for dependency in item.dependencies)
        ]
        if not eligible_no_change:
            for identifier, item in qualified_no_change.items():
                missing = [d for d in item.dependencies if d not in satisfied]
                errors.append(
                    f"{identifier} verified-no-change has unsatisfied prerequisites: "
                    + ", ".join(missing)
                )
            break
        for identifier in eligible_no_change:
            satisfied.add(identifier)
            del qualified_no_change[identifier]

    active_items = [item for item in items if item.status in ACTIVE_STATUSES]
    if len(active_items) != 1:
        errors.append(
            "roadmap must have exactly one active item; found: "
            + (", ".join(item.identifier for item in active_items) or "none")
        )

    if controller.get("roadmap_schema") != "autotechno-evolution.v1":
        errors.append("controller roadmap_schema must be autotechno-evolution.v1")
    if controller.get("roadmap_status") != "active":
        errors.append("controller roadmap_status must be active")
    try:
        if int(controller.get("roadmap_revision", "")) < 1:
            raise ValueError
    except ValueError:
        errors.append("controller roadmap_revision must be a positive integer")
    if re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", controller.get("last_updated_utc", "")) is None:
        errors.append("controller last_updated_utc must use YYYY-MM-DD")
    if controller.get("selection_policy") != "lowest_order_eligible_item":
        errors.append("controller selection_policy must be lowest_order_eligible_item")
    if controller.get("maximum_concurrent_items") != "1":
        errors.append("controller maximum_concurrent_items must be 1")
    try:
        if int(controller.get("discovery_inbox_open", "")) < 0:
            raise ValueError
    except ValueError:
        errors.append("controller discovery_inbox_open must be a nonnegative integer")
    if controller.get("quality_claim") != "bounded-calibrated-no-general-professional-claim":
        errors.append(
            "controller quality_claim must be bounded-calibrated-no-general-professional-claim"
        )
    if controller.get("local_only") != "true":
        errors.append("controller local_only must be true")

    active_identifier = controller.get("active_item", "")
    if len(active_items) == 1 and active_identifier != active_items[0].identifier:
        errors.append(
            f"controller active_item {active_identifier!r} does not match active row "
            f"{active_items[0].identifier}"
        )
    active_item = item_map.get(active_identifier)
    if active_item is None:
        errors.append(f"controller active_item does not exist: {active_identifier!r}")
    else:
        unsatisfied = [
            dependency
            for dependency in active_item.dependencies
            if item_map.get(dependency) is None
            or dependency not in satisfied
        ]
        if unsatisfied:
            errors.append(
                f"active item {active_identifier} has unsatisfied dependencies: "
                + ", ".join(unsatisfied)
            )

    expected_plan = f"docs/local/roadmap-plans/{active_identifier}.md"
    if controller.get("active_plan") != expected_plan:
        errors.append(f"controller active_plan must be {expected_plan}")
    elif not (root / expected_plan).is_file():
        errors.append(f"controller active_plan is missing: {expected_plan}")

    last_completed_identifier = controller.get("last_completed_item", "")
    last_completed = item_map.get(last_completed_identifier)
    if last_completed is None:
        errors.append(
            f"controller last_completed_item does not exist: {last_completed_identifier!r}"
        )
    elif last_completed.status != "completed":
        errors.append(
            f"controller last_completed_item must have completed status: {last_completed_identifier}"
        )

    eligible = sorted(
        item.identifier
        for item in items
        if item.status == "queued"
        and all(
            item_map.get(dependency) is not None
            and dependency in satisfied
            for dependency in item.dependencies
        )
    )
    if active_item is not None and eligible and eligible[0] < active_item.identifier:
        errors.append(
            f"active item {active_item.identifier} skips lower eligible item {eligible[0]}"
        )
    return errors


def run_check(root: Path, output: TextIO) -> int:
    path = root / ROADMAP_PATH
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"roadmap integrity: cannot read {ROADMAP_PATH}: {exc}", file=output)
        return 1
    errors = validate_roadmap(text, root)
    if errors:
        for error in errors:
            print(f"roadmap integrity: {error}", file=output)
        return 1
    items, _ = parse_items(text)
    active = next(item.identifier for item in items if item.status in ACTIVE_STATUSES)
    print(
        f"roadmap integrity is healthy: {len(items)} items, active {active}",
        file=output,
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check",), nargs="?", default="check")
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    build_parser().parse_args(argv)
    return run_check(repository_root(), sys.stdout)


if __name__ == "__main__":
    raise SystemExit(main())
