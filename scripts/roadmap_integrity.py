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


# Human-approved 2026-10-06 compatibility boundary: historical planning only.
# These hashes cannot establish current implementation, quality or release proof.
# Membership and bytes are fixed in reviewed source, never learned from statuses,
# last_completed_item, local receipts or a regeneratable inventory.
HISTORICAL_PLANNING_BINDINGS: tuple[tuple[str, str, str], ...] = (
    ('AT-0001',
     'c7d021fa55b3e35dd470d5df1a6fa9383fe5afb21eaca64f4cd3a2e338931d6c',
     'e10e7604d1dfc18b3d9810f988e829780987fb7d1178fc98aac26434e7e228f1'),
    ('AT-0002',
     '7bc656e4098147fb2b9aeb3ae89bb94d9b853ad2a3946e54899adaa87183287f',
     'cfe0c0d113993d0e2327c44b844cb8036c44c266aec266e64c52f07c0415e79f'),
    ('AT-0003',
     'cf2296451f53795168bfd8aecd4e9d61f26a5864cd2a63f2652e0a9dd4f68a51',
     '0d9b49866f7ebc888b95bfdbdea69752423c646ccb0f1029cac32bfa995bc7a3'),
    ('AT-0004',
     '6470b4e42b5801be6344b04c1cbe4b2f6c2b366eef3824fa8addfabdf9cf5aef',
     '3bcbbb776783e7bc4fcce65513e382ad6bed005fcc139080e22001214e5f96d0'),
    ('AT-0005',
     '766704d9b6168ad0fb987dc25869474dc82f7a324ca0a84f7fe58e6c5d3f59c8',
     '3a03df8904e18eda230e77efa2c6760987789eeb50eee2a2a26ddfad9dd5ec0e'),
    ('AT-0006',
     'ae4efef474c6c7999c88f5c85a4c843ab25d2d9bfebf316b1d364edb982a081d',
     '30a678459201f4f930e11298a2d74f67fccbe77412df32a25f0559fca7296361'),
    ('AT-0007',
     '2fb2681d87eafd03e92839fda0a472e2f367649ce89f0153b5dd41d79bf37b6f',
     '4f9eedd4189ef1e1a0225c713dd229e23de4031f3279511c2b90058cecfea663'),
    ('AT-0008',
     'bafbf6581461ecbf575642472727e8f5beebe3efd05016a68dcfdbddca6feb37',
     'ffd93903fa82c1de91c7b3a44d68a743730d6fc7a1cd5d99145a38fe45884b14'),
    ('AT-0009',
     'bb7b212c0071d2cf2c3f057aa0f809153ada1b91ea4a0bf871ec27faa4b3581b',
     'e4d3e60859fd7c67bcf1a03e98f203b8e4606bdf48125706e3d39e47ea1035e9'),
    ('AT-0010',
     '61de756c6778fed2b98825d853b3ae3b6130bfdc9df65d6d4f1dd88049b22b14',
     '6510738bec8ac52d3d68e11ed8d732de7d428b6e9ce46d868b395555047ec82a'),
    ('AT-0011',
     '5f93c1f88a481ab2cf22b8758daac8802f808b6533b50b8a04bc1b822ff1e386',
     '5a09ecfe3f7180440820ca05f6f56cf6d184bfef7f10bccef0fc9e6314beae95'),
    ('AT-0012',
     'c57b5c66a89ad72441b9f0fb8d4afdf7faae32490cd450aa45cfe0696e2e57d8',
     '715e2a3fb4f1c099c87631d2ec5310970bcc1f9d878327fb928c45ed35dcd8d9'),
    ('AT-0013',
     'dda47381619976df96e3ebf4ffb605cb7f65182c39ae606d3072edbbd98cccbe',
     'bd1a8c5a1b3f1c131c70a449b0dcab18e7904195c30ce19138aab37ee29a8372'),
    ('AT-0014',
     'd01e9b71f7da71d32bbaf19b9fd55befc9b0bd9c11f7b8e305e1573ae0bacd3a',
     'a03877454b5263210b71f6c7fd7d86f70478aa1b09258275351714e7aecb6083'),
    ('AT-0015',
     'd9365a3740f016b82635938d650476115546da9f9d10f3e1e114c5c490a6eeef',
     'add1a8be454750d3822bee7c8cec5ad1f70228d922b613bddc4b8aab5c321a84'),
    ('AT-0016',
     '1b6a50009b2fcd32b75ab6ff9a1066081ede13f4776856f21199d09274a12424',
     '40ffd3c10b2f443dd8cf45d3df0d4bae333df182a90e6a56e7087a943172519e'),
    ('AT-0017',
     'cbae3d0aa0db1d6e630b5418618c2660a72d4e3efad1432770397241e36ed883',
     '40d1d0cd8f14b2a9304fa17d1ff1de6404e0f3fa95af57fe280763f397eb7720'),
    ('AT-0018',
     'f6b691e58f1567008f43f7ce6fe6a0848b65f4d8f8fd2e72e1be557bce349d23',
     'd4b34f196afe0e457f961f3e50e202416bd5a30e01bd767d2d81ebc66cc97221'),
    ('AT-0019',
     'f72da4271d24b702365135b85892b093f8982b47c7347e8da550b2dee4fdbaab',
     'e0ab847da7ab9bba5ed909bc5dc327bc0dadb23cabcacb180376a40ce4a105cb'),
    ('AT-0020',
     'bcbe9de4e0a578b03611c91241b086b253f87a9a7196c94866c97734084644f5',
     'ba5ddea980feb9cff545b249cb94a5fb230750cee77f1b9de5aedb80325a8538'),
    ('AT-0021',
     'b3112a0416ae20e67e2b579dec2440646ad644f2acc3d3e0f83806c234940b4e',
     '553048fae379c2cc7a1df5156822e492afa37fa6dc197c42579922d4d1112fb5'),
    ('AT-0022',
     '5905537b1884f388be895c1967c66cf45f31e35eec16d86f904415c329d621f9',
     'c66b0d9b66da2dcb399f2f88fcddb767e3c8d15ca1f1767da1f532e54fde381c'),
    ('AT-0023',
     'e4f86d4d9e09d49d2b29a0ecc1a2bf0e0f4abfaa3e2e49dc0fab452a7d9a85a5',
     '391e621f228e1c4a5f5b309ac72c750c5a85bf9ba5f40171f3943fa86aecda21'),
    ('AT-0024',
     'ffdce85db888e16ab881349dced8bc7b7959581ca9e80e18e084582783be2156',
     'ddba2e83c5dd94c09a45c7d89e4c2f4eefcbfa56f3107b37e58211a12431fc2a'),
    ('AT-0025',
     'f3f35f73fe49f594471ee3561066ab04bf83dfd302d15eccba6b70ce79baeae9',
     '2389d2d94b8859de153506192551ee073d6775390edde8759dba078f156c4a4f'),
    ('AT-0026',
     '221bef1bfe3202cc5023281b781ec6de5787ced76535bf81edcd431a87490c68',
     '629e217f9f9a906cafe473d5b3b0d66a63bb7f57ada42b5527d4db874ea16fe5'),
    ('AT-0027',
     '10a5ace75e2931770db6f16a00656a5963ca714fceada64f832883891ffa089a',
     '3ed08d7a16ef32bbaf91ac84ea344e3a1b3478831acde2be09b3b61a3209ab68'),
    ('AT-0028',
     'e6be28ddfe8639c365244a5bbe9ada295fea8be49cb17ad2b1e7191d5ccc23cc',
     '075fd10c8355536e656c61fb98b66f4cd4cf4db5e1ba36552e190aa808af6c78'),
    ('AT-0029',
     'b5d1f418241e8af0bf58a21e4bada883ae33fa8561f6906c2b0ce18e209910a7',
     'fa30c09baeee1ea71bf0fe439c9d663ecc81a0308f0b7785bf148f15601615d8'),
    ('AT-0030',
     'c9b1d8dbf225bcbc690d7a6c925ed21581693bcaa3fae812104885a3ad2fa7f5',
     'b0b8db5c902de54acb08a5714d7d8c5d5fbc9b511e30cd8bf56ce6f1ff65f6a1'),
    ('AT-0031',
     '13f65086ede7d4d57df96b8a240f093e1aaef8d17c222b3de52f4055c189df42',
     '46f792a8fcb5df5dd6650c05ba4099f886e690ba5e06cbf004e57ecfb28922de'),
    ('AT-0032',
     'd16d81440e8fa5fb4177e620d8542f4323994884e67381e138a38ca9dc85d260',
     'f42330e337f0e7b2f4b5092d0270c5a063032178ac99b57ed46e2c776853d8f7'),
    ('AT-0033',
     '6012f6bae812c8f70f7a7b6e96fe3fb3b8bda5221e0140d5792c63d93289a3a0',
     '3e062a887de3fd068d7280bbffb787a4f726c5f62cb428e54286db01940274a7'),
    ('AT-0034',
     'aaf65197ac71337204b541aae6f083770c4d2309f75022622a6aaee157d8db4d',
     '5ca85b243b75c2b14317a6b324ad78e3aa37f0955fdecb7d3035baa0fc957b12'),
    ('AT-0035',
     'a2e4fbc0ef676682eaa2c5d917176216701b0c83ee5b0eb5e12753c9a15728b3',
     'cf8cb99ad974ddb9b12e3f1862dbeca3cc5ba81dd80513a20d068c38e38a73fb'),
    ('AT-0036',
     'c4b9826add1d9ebdbd9f39eba2aeb29309c27eaf915f9b15166d6cbafa8151e1',
     '6573804a9630067dbe93bfd51ebe7772db8d5d9b84a78105159f902ed3d45f41'),
    ('AT-0037',
     '674b2e0407eb4c9f2ae5abc32720f9094fffd07f7f0ec7cd96870acaf301a5d1',
     '61394ee01b030110200bcf55ef1c61eadefc383a168e5598a5357cda3953e4ed'),
    ('AT-0038',
     '148e286db187302d6802717d6c3500516b9afbb03749a9dc40f0e2cd33f25b6a',
     '8290194d7b303f4691825f3fb1a6d2a95ff3c2c2cec1e81d348e1a5d261a393f'),
)


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


def historical_planning_matches(item: RoadmapItem, raw_row: str, root: Path) -> bool:
    """Admit only unchanged approved history, without current qualification authority."""
    binding = next((row[1:] for row in HISTORICAL_PLANNING_BINDINGS
                    if row[0] == item.identifier), None)
    if item.status != "completed" or binding is None:
        return False
    if hashlib.sha256(raw_row.encode("utf-8")).hexdigest() != binding[0]:
        return False
    relative = Path(f"docs/local/roadmap-plans/{item.identifier}.md")
    plan = root / relative
    # Even an internal symlink cannot silently substitute an accepted plan.
    if any((root / parent).is_symlink() for parent in (relative, *relative.parents)):
        return False
    if not plan.resolve().is_relative_to(root.resolve()):
        return False
    try:
        return hashlib.sha256(plan.read_bytes()).hexdigest() == binding[1]
    except OSError:
        return False


def current_clean_revision(root: Path) -> Optional[str]:
    """No reuse authority exists for current completion receipts: require the clean exact source."""
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


def completion_scope_fingerprint(item: RoadmapItem, root: Path) -> str:
    """Bind ignored acceptance scope as well as immutable tracked source."""
    plan = root / f"docs/local/roadmap-plans/{item.identifier}.md"
    if not plan.resolve().is_relative_to(root.resolve()):
        raise RoadmapIntegrityError("completion acceptance plan must remain inside the repository")
    try:
        plan_digest = hashlib.sha256(plan.read_bytes()).hexdigest()
    except OSError as exc:
        raise RoadmapIntegrityError("cannot read completion acceptance plan") from exc
    scope = {
        "item": item.identifier,
        "outcome": item.outcome,
        "dependencies": list(item.dependencies),
        "planSha256": plan_digest,
    }
    encoded = json.dumps(scope, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def completion_receipt_errors(
    item: RoadmapItem, root: Path, revision: Optional[str]
) -> list[str]:
    """Validate current objective evidence before a completed or no-change row unlocks work."""
    path = f"docs/local/result-records/{item.identifier}.json"
    prefix = f"{item.identifier} {item.status}"
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
        scope_marker = "roadmap-scope-sha256:" + completion_scope_fingerprint(item, root)
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
    if not errors:
        # The vocabulary validates reporting, not measured item outcomes. There
        # is no installed authoritative verifier for all four required objective
        # gates. Phase-1 has bounded baseline claims; logs, generic JSON and
        # scope hashes cannot supply missing implementation/quality authority.
        # Preserve this state until a separately implemented and validated
        # item-specific verifier can authenticate the complete acceptance matrix.
        errors.append("authoritative item-specific machine qualification is unavailable; "
                      f"{item.status} cannot satisfy a dependency")
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

    completion_items = [item for item in items
                        if item.status in ("completed", "verified-no-change")]
    lines = text.splitlines()
    historical = {item.identifier for item in completion_items
                  if historical_planning_matches(item, lines[item.line - 1], root)}
    current_items = [item for item in completion_items if item.identifier not in historical]
    revision = current_clean_revision(root) if current_items else None
    qualified_completions = {item.identifier: item for item in completion_items
                             if item.identifier in historical}
    for item in current_items:
        receipt_errors = completion_receipt_errors(item, root, revision)
        errors.extend(receipt_errors)
        if not receipt_errors:
            qualified_completions[item.identifier] = item
    # History supplies planning prerequisites only. Both history and any future
    # machine-qualified completion must satisfy their own dependency chains.
    satisfied: set[str] = set()
    while qualified_completions:
        eligible_completions = [
            identifier for identifier, item in qualified_completions.items()
            if all(dependency in satisfied for dependency in item.dependencies)
        ]
        if not eligible_completions:
            break
        for identifier in eligible_completions:
            satisfied.add(identifier)
            del qualified_completions[identifier]

    # Refusal of evidence does not hide unfinished prerequisites.
    for item in completion_items:
        if item.identifier not in satisfied:
            missing = [d for d in item.dependencies if d not in satisfied]
            if missing:
                errors.append(f"{item.identifier} {item.status} has unsatisfied prerequisites: "
                              + ", ".join(missing))

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

    elif last_completed_identifier not in satisfied:
        errors.append(f"controller last_completed_item has no admitted completion: "
                      f"{last_completed_identifier}")

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
