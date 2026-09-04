#!/usr/bin/env python3
"""Validate and render Auto Techno source-citation records."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import date
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence, TextIO
from urllib.parse import urlparse


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import roadmap_integrity  # noqa: E402


SCHEMA_ID = "autotechno-source-citation-schema.v1"
RECORD_ID = "autotechno-source-citation-record.v1"
DEPTH_GRADES = ("A", "B", "C", "D", "X")
LICENCE_CLASSES = (
    "GREEN-ORIGINAL",
    "GREEN-PERMISSIVE",
    "YELLOW-REVIEW",
    "RED-STUDY-ONLY",
    "RED-ASSET",
)
SOURCE_USES = (
    "contract-authority",
    "behavioural-hypothesis",
    "implementation-reference",
    "licence-evidence",
    "discovery-only",
    "negative-evidence",
)
SCHEMA_KEYS = {
    "schema", "schemaVersion", "depthGrades", "licenceClasses", "sourceUses",
    "recordSchema", "excerptPolicy",
}
DEPTH_KEYS = {"id", "meaning", "permittedUse"}
LICENCE_KEYS = {"id", "meaning"}
RECORD_SCHEMA_KEYS = {
    "schema", "requiredRootFields", "requiredSourceFields", "localRecordPattern",
}
EXCERPT_POLICY_KEYS = {"maximumWords", "meaning"}
RECORD_ROOT_FIELDS = ("schema", "itemId", "planPath", "sources")
SOURCE_FIELDS = (
    "id", "url", "title", "publisher", "revisionOrDate", "accessDate",
    "depth", "licenceClass", "use", "summary", "excerpt",
)
STUDY_ONLY_CLASSES = {"YELLOW-REVIEW", "RED-STUDY-ONLY", "RED-ASSET"}
STUDY_ONLY_USES = {
    "behavioural-hypothesis", "licence-evidence", "discovery-only",
    "negative-evidence",
}


class SourceCitationError(RuntimeError):
    """An actionable citation-schema or record error."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def schema_path(root: Path) -> Path:
    return root / "docs/SOURCE_CITATION_SCHEMA.json"


def report_path(root: Path) -> Path:
    return root / "docs/SOURCE_CITATION_SCHEMA.md"


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


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SourceCitationError(f"cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SourceCitationError(f"{path} must contain one JSON object")
    return value


def validate_schema(schema: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    _exact_keys(schema, SCHEMA_KEYS, "schema", errors)
    if schema.get("schema") != SCHEMA_ID:
        errors.append(f"schema.schema must be {SCHEMA_ID}")
    if schema.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")

    depths = schema.get("depthGrades")
    if not isinstance(depths, list):
        errors.append("depthGrades must be an array")
        depths = []
    depth_ids: list[str] = []
    for index, depth in enumerate(depths):
        location = f"depthGrades[{index}]"
        if not isinstance(depth, dict):
            errors.append(f"{location} must be an object")
            continue
        _exact_keys(depth, DEPTH_KEYS, location, errors)
        depth_ids.append(str(depth.get("id", "")))
        for field in DEPTH_KEYS:
            if not _nonempty_string(depth.get(field)):
                errors.append(f"{location}.{field} must be a non-empty string")
    if tuple(depth_ids) != DEPTH_GRADES:
        errors.append(f"depthGrades must be exactly {list(DEPTH_GRADES)}")

    classes = schema.get("licenceClasses")
    if not isinstance(classes, list):
        errors.append("licenceClasses must be an array")
        classes = []
    class_ids: list[str] = []
    for index, licence in enumerate(classes):
        location = f"licenceClasses[{index}]"
        if not isinstance(licence, dict):
            errors.append(f"{location} must be an object")
            continue
        _exact_keys(licence, LICENCE_KEYS, location, errors)
        class_ids.append(str(licence.get("id", "")))
        for field in LICENCE_KEYS:
            if not _nonempty_string(licence.get(field)):
                errors.append(f"{location}.{field} must be a non-empty string")
    if tuple(class_ids) != LICENCE_CLASSES:
        errors.append(f"licenceClasses must be exactly {list(LICENCE_CLASSES)}")
    if tuple(schema.get("sourceUses", [])) != SOURCE_USES:
        errors.append(f"sourceUses must be exactly {list(SOURCE_USES)}")

    record_schema = schema.get("recordSchema")
    if not isinstance(record_schema, dict):
        errors.append("recordSchema must be an object")
    else:
        _exact_keys(record_schema, RECORD_SCHEMA_KEYS, "recordSchema", errors)
        if record_schema.get("schema") != RECORD_ID:
            errors.append(f"recordSchema.schema must be {RECORD_ID}")
        if tuple(record_schema.get("requiredRootFields", [])) != RECORD_ROOT_FIELDS:
            errors.append(
                f"recordSchema.requiredRootFields must be {list(RECORD_ROOT_FIELDS)}"
            )
        if tuple(record_schema.get("requiredSourceFields", [])) != SOURCE_FIELDS:
            errors.append(
                f"recordSchema.requiredSourceFields must be {list(SOURCE_FIELDS)}"
            )
        if record_schema.get("localRecordPattern") != (
            "docs/local/reports/source-citations/AT-xxxx.json"
        ):
            errors.append("recordSchema.localRecordPattern is not canonical")

    excerpt = schema.get("excerptPolicy")
    if not isinstance(excerpt, dict):
        errors.append("excerptPolicy must be an object")
    else:
        _exact_keys(excerpt, EXCERPT_POLICY_KEYS, "excerptPolicy", errors)
        if excerpt.get("maximumWords") != 25:
            errors.append("excerptPolicy.maximumWords must be 25")
        if not _nonempty_string(excerpt.get("meaning")):
            errors.append("excerptPolicy.meaning must be a non-empty string")
    return errors


def _normalized_repository_path(value: str) -> Optional[str]:
    if "\\" in value:
        return None
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts or "." in path.parts or ".." in path.parts:
        return None
    return path.as_posix()


def _roadmap_revision(root: Path) -> Optional[str]:
    try:
        text = (root / roadmap_integrity.ROADMAP_PATH).read_text(encoding="utf-8")
        return roadmap_integrity.parse_controller(text).get("roadmap_revision")
    except (OSError, roadmap_integrity.RoadmapIntegrityError):
        return None


def validate_record(
    record: Mapping[str, Any],
    schema: Mapping[str, Any],
    root: Path,
    record_path: Optional[Path] = None,
) -> list[str]:
    errors: list[str] = []
    _exact_keys(record, set(RECORD_ROOT_FIELDS), "record", errors)
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
    if record_path is not None and record_path.name != f"{item_id}.json":
        errors.append(f"citation record filename must be {item_id}.json")

    maximum_excerpt_words = int(schema.get("excerptPolicy", {}).get("maximumWords", 25))
    sources = record.get("sources")
    if not isinstance(sources, list) or not sources:
        errors.append("record.sources must be a non-empty array")
        sources = []
    source_ids: list[str] = []
    urls: list[str] = []
    for index, source in enumerate(sources, start=1):
        location = f"record.sources[{index - 1}]"
        if not isinstance(source, dict):
            errors.append(f"{location} must be an object")
            continue
        _exact_keys(source, set(SOURCE_FIELDS), location, errors)
        expected_source_id = f"SRC-{item_id}-{index:03d}"
        if source.get("id") != expected_source_id:
            errors.append(f"{location}.id must be {expected_source_id}")
        source_ids.append(str(source.get("id", "")))
        for field in SOURCE_FIELDS:
            if field == "excerpt":
                if not isinstance(source.get(field), str):
                    errors.append(f"{location}.excerpt must be a string")
            elif not _nonempty_string(source.get(field)):
                errors.append(f"{location}.{field} must be a non-empty string")

        url = source.get("url")
        if isinstance(url, str):
            urls.append(url)
            if url.startswith("repo:"):
                repository_path = _normalized_repository_path(url.removeprefix("repo:"))
                if repository_path is None:
                    errors.append(f"{location}.url has an invalid repository path")
                else:
                    destination = root / repository_path
                    if destination.is_symlink() or not destination.is_file():
                        errors.append(f"{location}.url repository source is missing: {repository_path}")
                    elif repository_path == roadmap_integrity.ROADMAP_PATH.as_posix():
                        revision = _roadmap_revision(root)
                        expected = f"roadmap-revision:{revision}" if revision else None
                        if expected is None or source.get("revisionOrDate") != expected:
                            errors.append(
                                f"{location}.revisionOrDate must match the local {expected or 'roadmap revision'}"
                            )
                    else:
                        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
                        expected = f"sha256:{digest}"
                        if source.get("revisionOrDate") != expected:
                            errors.append(
                                f"{location}.revisionOrDate must match repository {expected}"
                            )
            else:
                parsed = urlparse(url)
                if parsed.scheme != "https" or not parsed.netloc:
                    errors.append(f"{location}.url must be an https URL or repo:path locator")

        try:
            date.fromisoformat(str(source.get("accessDate", "")))
        except ValueError:
            errors.append(f"{location}.accessDate must use YYYY-MM-DD")
        depth = source.get("depth")
        licence_class = source.get("licenceClass")
        source_use = source.get("use")
        if depth not in DEPTH_GRADES:
            errors.append(f"{location}.depth is unsupported")
        if licence_class not in LICENCE_CLASSES:
            errors.append(f"{location}.licenceClass is unsupported")
        if source_use not in SOURCE_USES:
            errors.append(f"{location}.use is unsupported")
        if depth in {"D", "X"} and source_use != "discovery-only":
            errors.append(f"{location} depth {depth} may be discovery-only")
        if licence_class in STUDY_ONLY_CLASSES and source_use not in STUDY_ONLY_USES:
            errors.append(
                f"{location} licence class {licence_class} may not authorize {source_use}"
            )
        if source_use == "contract-authority" and licence_class != "GREEN-ORIGINAL":
            errors.append(f"{location} contract-authority must be GREEN-ORIGINAL")
        excerpt = source.get("excerpt")
        if isinstance(excerpt, str) and len(excerpt.split()) > maximum_excerpt_words:
            errors.append(
                f"{location}.excerpt exceeds {maximum_excerpt_words} words"
            )
    if len(source_ids) != len(set(source_ids)):
        errors.append("record source ids must be unique")
    duplicate_urls = sorted(url for url in set(urls) if urls.count(url) > 1)
    if duplicate_urls:
        errors.append("record source URLs must be unique: " + ", ".join(duplicate_urls))
    return errors


def render_report(schema: Mapping[str, Any]) -> str:
    lines = [
        "# Source Citation Schema",
        "",
        "> Generated from `docs/SOURCE_CITATION_SCHEMA.json`; do not edit by hand.",
        "",
        "Each active roadmap plan owns one ignored local citation record. Citation",
        "placement records provenance and permitted research use; it never grants",
        "dependency, copying, training, or redistribution permission.",
        "",
        "## Evidence depth",
        "",
        "| Grade | Meaning | Permitted use |",
        "|---|---|---|",
    ]
    for depth in schema["depthGrades"]:
        lines.append(
            f"| `{depth['id']}` | {depth['meaning']} | {depth['permittedUse']} |"
        )
    lines.extend([
        "",
        "## Licence classes",
        "",
        "| Class | Meaning |",
        "|---|---|",
    ])
    for licence in schema["licenceClasses"]:
        lines.append(f"| `{licence['id']}` | {licence['meaning']} |")
    lines.extend([
        "",
        "## Record contract",
        "",
        "Records live at `docs/local/reports/source-citations/AT-xxxx.json` and",
        "bind their exact `AT-xxxx` plan. Every source requires URL/locator, title,",
        "publisher, revision/date, access date, depth, licence class, permitted use,",
        "an original summary, and an optional excerpt of at most 25 words.",
        "",
        "Repository sources use `repo:path` and exact `sha256:<digest>` revisions;",
        "the mutable private roadmap uses its explicit `roadmap-revision:<n>`. Web",
        "sources use HTTPS and are not fetched by validation.",
        "",
        "```sh",
        "python3 scripts/source_citation_records.py check",
        "python3 scripts/source_citation_records.py validate-record path/to/AT-xxxx.json",
        "python3 scripts/source_citation_records.py check-active",
        "```",
        "",
    ])
    return "\n".join(lines)


def run_render(root: Path, output: TextIO) -> int:
    schema = load_json(schema_path(root))
    errors = validate_schema(schema)
    if errors:
        raise SourceCitationError("; ".join(errors))
    report_path(root).write_text(render_report(schema), encoding="utf-8")
    print("rendered source citation schema v1", file=output)
    return 0


def run_check(root: Path, output: TextIO) -> int:
    try:
        schema = load_json(schema_path(root))
    except SourceCitationError as exc:
        print(f"source citations: {exc}", file=output)
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
            print(f"source citations: {error}", file=output)
        return 1
    print(
        f"source citation schema is current: v1, {len(DEPTH_GRADES)} depths, "
        f"{len(LICENCE_CLASSES)} licence classes",
        file=output,
    )
    return 0


def run_validate_record(root: Path, path: Path, output: TextIO) -> int:
    try:
        schema = load_json(schema_path(root))
        record = load_json(path)
    except SourceCitationError as exc:
        print(f"source citations: {exc}", file=output)
        return 1
    errors = validate_schema(schema) + validate_record(record, schema, root, path)
    if errors:
        for error in errors:
            print(f"source citations: {error}", file=output)
        return 1
    print(
        f"source citation record is valid: {record['itemId']}, "
        f"{len(record['sources'])} sources",
        file=output,
    )
    return 0


def run_check_active(root: Path, output: TextIO) -> int:
    try:
        roadmap_text = (root / roadmap_integrity.ROADMAP_PATH).read_text(encoding="utf-8")
        controller = roadmap_integrity.parse_controller(roadmap_text)
    except (OSError, roadmap_integrity.RoadmapIntegrityError) as exc:
        print(f"source citations: cannot read active roadmap controller: {exc}", file=output)
        return 1
    item_id = controller.get("active_item", "")
    path = root / f"docs/local/reports/source-citations/{item_id}.json"
    return run_validate_record(root, path, output)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=("check", "render", "validate-record", "check-active")
    )
    parser.add_argument("record", nargs="?", type=Path)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = build_parser().parse_args(argv)
    root = repository_root()
    if arguments.command == "render":
        if arguments.record is not None:
            raise SystemExit("render does not accept a record path")
        return run_render(root, sys.stdout)
    if arguments.command == "check":
        if arguments.record is not None:
            raise SystemExit("check does not accept a record path")
        return run_check(root, sys.stdout)
    if arguments.command == "check-active":
        if arguments.record is not None:
            raise SystemExit("check-active does not accept a record path")
        return run_check_active(root, sys.stdout)
    if arguments.record is None:
        raise SystemExit("validate-record requires a JSON record path")
    return run_validate_record(root, arguments.record, sys.stdout)


if __name__ == "__main__":
    raise SystemExit(main())
