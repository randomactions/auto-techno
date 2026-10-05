#!/usr/bin/env python3
"""Bind a fresh, independently validated producer operation to frozen dependencies.

Only the coordinated driver supplies producer and validator actions. This module
never infers authority from an existing artifact or changes artifact schemas.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
from typing import Any, Callable

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import baseline_dependency_contract as dependency

SCHEMA = "autotechno-fresh-baseline-capture-binding.v1"
TRACKED_SCHEMA = "autotechno-tracked-derived-capture-binding.v1"
TRACKED_OUTPUTS = {"deficit-register": {
    "docs/DEFICIT_REGISTER.json", "docs/DEFICIT_REGISTER.md"}}
MAX_OUTPUT_FILES = 1024
MAX_OUTPUT_FILE_BYTES = 64 * 1024 * 1024
MAX_TOTAL_OUTPUT_BYTES = 4 * 1024 * 1024 * 1024
OUTPUT_FIELDS = {"path", "byteCount", "sha256"}
BINDING_KEYS = {"schema", "familyId", "originSnapshot", "producerInvocation",
                "validatorInvocation", "outputs", "upstreamBindings",
                "qualification", "bindingFingerprint"}
TRACKED_BINDING_KEYS = BINDING_KEYS | {"sourceOutputInputs"}


class CaptureTransactionError(RuntimeError):
    pass


def local_path(root: Path, name: str) -> Path:
    name = dependency.path_name(name)
    if not name.startswith("docs/local/"):
        raise CaptureTransactionError("fresh output must remain local")
    current = root
    for part in name.split("/"):
        current = current / part
        if current.is_symlink():
            raise CaptureTransactionError("fresh output cannot traverse a symlink")
    return current


def output_path(root: Path, name: str, family_id: str | None = None) -> Path:
    name = dependency.path_name(name)
    if name not in TRACKED_OUTPUTS.get(family_id, set()):
        return local_path(root, name)
    current = root
    for part in name.split("/"):
        current = current / part
        if current.is_symlink():
            raise CaptureTransactionError("tracked output cannot traverse a symlink")
    return current


def output_record(root: Path, name: str, family_id: str | None = None) -> dict[str, Any]:
    path = output_path(root, name, family_id)
    if not path.is_file():
        raise CaptureTransactionError("fresh output missing or not regular: " + name)
    count = path.stat().st_size
    limit = dependency.MAX_METADATA_BYTES if name in TRACKED_OUTPUTS.get(family_id, set()) else MAX_OUTPUT_FILE_BYTES
    if count > limit:
        raise CaptureTransactionError("fresh output exceeds byte bound")
    h = hashlib.sha256()
    observed = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            observed += len(chunk)
            if observed > limit:
                raise CaptureTransactionError("fresh output grew beyond byte bound")
            h.update(chunk)
    if observed != count:
        raise CaptureTransactionError("fresh output changed size while hashing")
    return {"path": name, "byteCount": count, "sha256": h.hexdigest()}


def required_output_paths(root: Path, family_id: str) -> set[str]:
    node = next(n for n in dependency.lifecycle.NODES if n["id"] == family_id)
    name = node["artifactPath"]
    path = output_path(root, name, family_id)
    if path.stat().st_size > dependency.MAX_METADATA_BYTES:
        raise CaptureTransactionError("fresh manifest exceeds metadata bound")
    document = dependency.read_json(path)
    if not isinstance(document, dict) or document.get("schema") != node["schema"] or type(document.get(node["versionField"])) is not int or document.get(node["versionField"]) != node["version"]:
        raise CaptureTransactionError("fresh manifest family/schema/version mismatch")
    result = {name}
    if family_id in {"whole-mix-render", "role-stem-capture"}:
        entries = document.get("entries")
        if not isinstance(entries, list) or not entries:
            raise CaptureTransactionError("fresh PCM capture has no entries")
        waves = []
        for entry in entries:
            if not isinstance(entry, dict):
                raise CaptureTransactionError("invalid fresh PCM entry")
            if family_id == "whole-mix-render":
                waves.append(entry.get("wavPath"))
            else:
                files = entry.get("files")
                if not isinstance(files, list) or not files:
                    raise CaptureTransactionError("fresh role capture has no files")
                for file in files:
                    if not isinstance(file, dict):
                        raise CaptureTransactionError("invalid fresh role file")
                    waves.append(file.get("wavPath"))
        for wave in waves:
            local_path(root, wave)
        if len(waves) != len(set(waves)):
            raise CaptureTransactionError("duplicate fresh PCM output")
        result.update(waves)
    return result


def invocation(value: object) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != {"argv", "environmentFingerprint", "compiledInputsFingerprint"}:
        raise CaptureTransactionError("producer/validator invocation requires complete versioned fields")
    argv = value["argv"]
    if not isinstance(argv, list) or not argv or len(argv) > 64:
        raise CaptureTransactionError("invocation requires bounded argument vector")
    if any(not isinstance(x, str) or not x or len(x) > 4096 or "\x00" in x for x in argv):
        raise CaptureTransactionError("invalid invocation argument")
    for key in ["environmentFingerprint", "compiledInputsFingerprint"]:
        if not isinstance(value[key], str) or not dependency.HEX.fullmatch(value[key]):
            raise CaptureTransactionError("invocation requires exact environment and compiled-input bindings")
    return json.loads(json.dumps(value))


def require_success(code: object, label: str) -> None:
    # A bool or an absent return value must never be mistaken for exit zero.
    if type(code) is not int or code != 0:
        raise CaptureTransactionError(label + " did not complete successfully")


def require_frozen_inputs(root: Path, before: dict[str, Any], outputs: set[str]) -> None:
    """Permit only registered derived output bytes to differ in a candidate.

    This does not edit or recapture the origin snapshot. HEAD, index, inventory,
    and every other committed byte must stay exact. Output slots may not also
    be declared producer/analyzer inputs.
    """
    if dependency.git(root, "rev-parse", "HEAD").decode().strip() != before["gitHead"]:
        raise CaptureTransactionError("tracked candidate HEAD changed")
    if dependency.git(root, "diff", "--cached", "--name-only", "-z"):
        raise CaptureTransactionError("tracked candidate index changed")
    if set(dependency.inventory(root)) != set(before["files"]):
        raise CaptureTransactionError("tracked candidate inventory changed")
    corpus_path = before["context"]["captureCorpusPath"]
    if hashlib.sha256(dependency.regular_bytes(root, corpus_path)).hexdigest() != before["context"]["captureCorpusSha256"]:
        raise CaptureTransactionError("tracked candidate private corpus changed")
    for entry in dependency.git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all").split(b"\0"):
        if entry and (entry[:3] != b" M " or entry[3:].decode() not in outputs):
            raise CaptureTransactionError("tracked candidate changed an undeclared input")
    for family in before["families"].values():
        if outputs & (set(family["producerInputs"]) | set(family["analyzerInputs"])):
            raise CaptureTransactionError("tracked output is also a frozen producer/analyzer input")
    for name, record in before["files"].items():
        data = dependency.regular_bytes(root, name)
        if name not in outputs and hashlib.sha256(data).hexdigest() != record["sha256"]:
            raise CaptureTransactionError("tracked candidate immutable input changed: " + name)
    for name in outputs:
        if name not in before["files"] or output_path(root, name, "deficit-register").stat().st_mode & 0o111:
            raise CaptureTransactionError("tracked output must retain a nonexecutable committed slot")


def record_fresh_capture(
    root: Path, family_id: str, context: dict[str, str], output_paths: list[str],
    producer_invocation: dict[str, Any], validator_invocation: dict[str, Any],
    producer: Callable[[], int], validator: Callable[[], int],
    *, upstream_bindings: list[dict[str, Any]] | None = None,
    candidate_root: Path | None = None,
) -> dict[str, Any]:
    """Run one producer and validator in the driver's existing serial order.

    Callbacks represent the actual invocations bound by the driver. This is not
    a signature over arbitrary actions or an authority bypass for exit receipts.
    The driver's immutable inputs and actual process/binary/environment records
    must be independently verified before a family validator adopts the binding.
    """
    nodes = {n["id"]: n for n in dependency.lifecycle.NODES}
    if family_id not in nodes:
        raise CaptureTransactionError("unknown baseline family")
    tracked = nodes[family_id]["artifactClass"] == "tracked-derived"
    if tracked and (family_id not in TRACKED_OUTPUTS or candidate_root is None):
        raise CaptureTransactionError("tracked derived capture requires an isolated candidate root")
    if not tracked and candidate_root is not None:
        raise CaptureTransactionError("local capture cannot select a tracked candidate root")
    target = candidate_root if tracked else root
    if tracked and (not isinstance(target, Path) or target.resolve() == root.resolve()
        or root.resolve() in target.resolve().parents or target.resolve() in root.resolve().parents):
        raise CaptureTransactionError("tracked candidate must be separate from the source root")
    if not isinstance(output_paths, list) or not output_paths or len(output_paths) > MAX_OUTPUT_FILES:
        raise CaptureTransactionError("fresh output coverage requires a bounded nonempty path list")
    if any(not isinstance(name, str) for name in output_paths):
        raise CaptureTransactionError("fresh output paths must be strings")
    if nodes[family_id]["artifactPath"] not in output_paths:
        raise CaptureTransactionError("canonical fresh manifest must be declared before production")
    if len(set(output_paths)) != len(output_paths):
        raise CaptureTransactionError("fresh output paths must be unique")
    if tracked and set(output_paths) != TRACKED_OUTPUTS[family_id]:
        raise CaptureTransactionError("tracked capture requires the exact registered JSON and Markdown outputs")
    producer_info, validator_info = invocation(producer_invocation), invocation(validator_invocation)
    before = dependency.capture(root, context)
    dependency.validate_snapshot(before, root)
    source_outputs = []
    if tracked:
        if dependency.capture(target, context) != before:
            raise CaptureTransactionError("tracked candidate source/context differs from frozen origin")
        require_frozen_inputs(target, before, set(output_paths))
        if any(output_path(root, n, family_id).samefile(output_path(target, n, family_id)) for n in output_paths):
            raise CaptureTransactionError("tracked candidate outputs alias original files")
        source_outputs = sorted((output_record(root, n, family_id) for n in output_paths), key=lambda x: x["path"])
    upstream_bindings = upstream_bindings or []
    parents = {}
    pool = {b["familyId"]: b for b in upstream_bindings}
    for binding in upstream_bindings:
        validate_binding(binding, root, bindings=pool)
        if tracked:
            validate_binding(binding, target, bindings=pool)
        name = binding["familyId"]
        if name in parents:
            raise CaptureTransactionError("duplicate upstream binding")
        if binding["originSnapshot"]["snapshotFingerprint"] != before["snapshotFingerprint"]:
            raise CaptureTransactionError("upstream capture has a different frozen source or context")
        parents[name] = binding["bindingFingerprint"]
    required = set()
    def ancestors(name):
        for parent in nodes[name]["dependencies"]:
            if parent not in required:
                required.add(parent)
                ancestors(parent)
    ancestors(family_id)
    if set(parents) != required:
        raise CaptureTransactionError("fresh capture must bind every exact upstream family")
    parents = {name: parents[name] for name in nodes[family_id]["dependencies"]}
    for name in output_paths:
        if not tracked and local_path(root, name).exists():
            raise CaptureTransactionError("cannot backfill or overwrite an existing capture: " + name)
    require_success(producer(), "producer")
    first = sorted((output_record(target, n, family_id if tracked else None) for n in output_paths), key=lambda x: x["path"])
    if not required_output_paths(target, family_id) <= set(output_paths):
        raise CaptureTransactionError("fresh output coverage omits manifest or PCM")
    if sum(x["byteCount"] for x in first) > MAX_TOTAL_OUTPUT_BYTES:
        raise CaptureTransactionError("fresh output set exceeds aggregate byte bound")
    require_success(validator(), "independent validator")
    second = sorted((output_record(target, n, family_id if tracked else None) for n in output_paths), key=lambda x: x["path"])
    if second != first:
        raise CaptureTransactionError("independent validation changed capture bytes")
    after = dependency.capture(root, context)
    if after != before:
        raise CaptureTransactionError("producer dependencies changed during capture or validation")
    if tracked:
        require_frozen_inputs(target, before, set(output_paths))
    for binding in upstream_bindings:
        validate_binding(binding, root, bindings=pool)
        if tracked:
            validate_binding(binding, target, bindings=pool)
    value = {"schema": TRACKED_SCHEMA if tracked else SCHEMA, "familyId": family_id,
        "originSnapshot": before, "producerInvocation": producer_info,
        "validatorInvocation": validator_info, "outputs": second,
        "upstreamBindings": parents, "qualification": dict(dependency.QUALIFICATION)}
    if tracked:
        value["sourceOutputInputs"] = source_outputs
    value["bindingFingerprint"] = dependency.digest(value)
    return value


def validate_binding(value: object, root: Path, *, bindings: dict[str, Any] | None = None,
                     active: set[str] | None = None) -> None:
    tracked = isinstance(value, dict) and value.get("schema") == TRACKED_SCHEMA
    if not isinstance(value, dict) or set(value) != (TRACKED_BINDING_KEYS if tracked else BINDING_KEYS) or value.get("schema") not in {SCHEMA, TRACKED_SCHEMA}:
        raise CaptureTransactionError("unsupported or incomplete fresh capture binding")
    if value["bindingFingerprint"] != dependency.digest({k: v for k, v in value.items() if k != "bindingFingerprint"}):
        raise CaptureTransactionError("fresh capture binding fingerprint mismatch")
    nodes = {n["id"]: n for n in dependency.lifecycle.NODES}
    if not isinstance(value["familyId"], str) or value["familyId"] not in nodes:
        raise CaptureTransactionError("unknown baseline family")
    if tracked != (nodes[value["familyId"]]["artifactClass"] == "tracked-derived"):
        raise CaptureTransactionError("capture schema does not match local/tracked artifact ownership")
    if value["qualification"] != dependency.QUALIFICATION or any(flag is not False for flag in value["qualification"].values()):
        raise CaptureTransactionError("fresh capture binding cannot establish qualification")
    dependency.validate_snapshot(value["originSnapshot"], root)
    if tracked:
        family_id = value["familyId"]
        allowed = TRACKED_OUTPUTS.get(family_id)
        inputs = value["sourceOutputInputs"]
        if allowed is None or not isinstance(inputs, list) or [x.get("path") for x in inputs if isinstance(x, dict)] != sorted(allowed):
            raise CaptureTransactionError("tracked capture origin output coverage differs")
        for item in inputs:
            if not isinstance(item, dict) or set(item) != OUTPUT_FIELDS:
                raise CaptureTransactionError("invalid tracked origin output record")
            data = dependency.git(root, "cat-file", "blob", value["originSnapshot"]["gitHead"] + ":" + item["path"])
            if len(data) > dependency.MAX_METADATA_BYTES or type(item["byteCount"]) is not int or item["byteCount"] != len(data) or item["sha256"] != hashlib.sha256(data).hexdigest():
                raise CaptureTransactionError("tracked origin output does not match original Git bytes")
        require_frozen_inputs(root, value["originSnapshot"], allowed)
    invocation(value["producerInvocation"])
    invocation(value["validatorInvocation"])
    parents = value["upstreamBindings"]
    if not isinstance(parents, dict) or set(parents) != set(nodes[value["familyId"]]["dependencies"]):
        raise CaptureTransactionError("upstream family coverage mismatch")
    if any(not isinstance(sha, str) or not dependency.HEX.fullmatch(sha) for sha in parents.values()):
        raise CaptureTransactionError("invalid upstream binding fingerprint")
    active = set() if active is None else set(active)
    if value["familyId"] in active:
        raise CaptureTransactionError("cyclic fresh capture bindings")
    active.add(value["familyId"])
    for name, sha in parents.items():
        if bindings is None or name not in bindings or bindings[name].get("bindingFingerprint") != sha:
            raise CaptureTransactionError("missing or changed exact upstream binding")
        parent = bindings[name]
        if parent.get("familyId") != name or parent.get("originSnapshot") != value["originSnapshot"]:
            raise CaptureTransactionError("upstream capture has a different frozen source or context")
        validate_binding(parent, root, bindings=bindings, active=active)
    outputs = value["outputs"]
    if not isinstance(outputs, list) or not outputs or len(outputs) > MAX_OUTPUT_FILES:
        raise CaptureTransactionError("fresh output coverage missing")
    names = []
    total = 0
    for output in outputs:
        if not isinstance(output, dict) or set(output) != OUTPUT_FIELDS:
            raise CaptureTransactionError("invalid fresh output binding")
        name = output["path"]
        if not isinstance(output["byteCount"], int) or isinstance(output["byteCount"], bool):
            raise CaptureTransactionError("invalid fresh output byte count")
        if output != output_record(root, name, value["familyId"] if tracked else None):
            raise CaptureTransactionError("fresh output hash/size mismatch: " + name)
        names.append(name)
        total += output["byteCount"]
    if not required_output_paths(root, value["familyId"]) <= set(names):
        raise CaptureTransactionError("fresh output coverage omits manifest or PCM")
    if tracked and set(names) != TRACKED_OUTPUTS[value["familyId"]]:
        raise CaptureTransactionError("tracked capture output coverage differs")
    if names != sorted(set(names)) or total > MAX_TOTAL_OUTPUT_BYTES:
        raise CaptureTransactionError("fresh output coverage/order/aggregate bound mismatch")


def replace_tracked_bytes(root: Path, name: str, data: bytes) -> None:
    path = output_path(root, name, "deficit-register")
    if name not in TRACKED_OUTPUTS["deficit-register"] or len(data) > dependency.MAX_METADATA_BYTES:
        raise CaptureTransactionError("unregistered or oversized tracked publication")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name + ".candidate-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def publish_tracked_capture(value: dict[str, Any], root: Path, candidate_root: Path,
    validator: Callable[[], int], *, bindings: dict[str, Any]) -> None:
    """Install only an independently validated tracked candidate.

    The driver owns serial publication. Failures preserve the candidate and
    restore the original registered outputs. Publication never commits source,
    changes an origin envelope, or grants currency/promotion authority.
    """
    if value.get("schema") != TRACKED_SCHEMA or root.resolve() == candidate_root.resolve():
        raise CaptureTransactionError("publication requires a separate tracked candidate")
    validate_binding(value, candidate_root, bindings=bindings)
    before = dependency.capture(root, value["originSnapshot"]["context"])
    if before != value["originSnapshot"]:
        raise CaptureTransactionError("publication source/context moved from frozen origin")
    for parent in bindings.values():
        validate_binding(parent, root, bindings=bindings)
    names = sorted(TRACKED_OUTPUTS[value["familyId"]])
    if [output_record(root, n, value["familyId"]) for n in names] != value["sourceOutputInputs"]:
        raise CaptureTransactionError("publication original tracked outputs changed")
    originals = {n: dependency.regular_bytes(root, n) for n in names}
    candidate = {n: dependency.regular_bytes(candidate_root, n) for n in names}
    try:
        for name in names:
            replace_tracked_bytes(root, name, candidate[name])
        require_success(validator(), "published tracked independent validator")
        validate_binding(value, root, bindings=bindings)
    except BaseException:
        for name in names:
            # A validator must not change outputs. Remove a substituted leaf
            # symlink without following it before restoring the registered slot.
            parent = output_path(root, name, "deficit-register").parent if not (root / name).is_symlink() else root / "docs"
            if parent.is_symlink() or not parent.is_dir():
                raise CaptureTransactionError("tracked publication parent changed; candidate preserved")
            leaf = parent / Path(name).name
            if leaf.is_symlink():
                leaf.unlink()
            replace_tracked_bytes(root, name, originals[name])
        raise
