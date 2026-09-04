#!/usr/bin/env python3
"""Validate Auto Techno's local autonomous roadmap and dependency graph."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Optional, Sequence, TextIO


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
DEPENDENCY_SATISFIED_STATUSES = {"completed", "verified-no-change"}
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
            or item_map[dependency].status not in DEPENDENCY_SATISFIED_STATUSES
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
            and item_map[dependency].status in DEPENDENCY_SATISFIED_STATUSES
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
