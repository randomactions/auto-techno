#!/usr/bin/env python3
"""Bind a fresh, independently validated producer operation to frozen dependencies.

Only the coordinated driver supplies producer and validator actions. This module
never infers authority from an existing artifact or changes artifact schemas.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Callable

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import baseline_dependency_contract as dependency

SCHEMA = "autotechno-fresh-baseline-capture-binding.v1"
MAX_OUTPUT_FILES = 1024
MAX_OUTPUT_FILE_BYTES = 64 * 1024 * 1024
MAX_TOTAL_OUTPUT_BYTES = 4 * 1024 * 1024 * 1024
OUTPUT_FIELDS = {"path", "byteCount", "sha256"}
BINDING_KEYS = {"schema", "familyId", "originSnapshot", "producerInvocation",
                "validatorInvocation", "outputs", "upstreamBindings",
                "qualification", "bindingFingerprint"}


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


def output_record(root: Path, name: str) -> dict[str, Any]:
    path = local_path(root, name)
    if not path.is_file():
        raise CaptureTransactionError("fresh output missing or not regular: " + name)
    count = path.stat().st_size
    if count > MAX_OUTPUT_FILE_BYTES:
        raise CaptureTransactionError("fresh output exceeds byte bound")
    h = hashlib.sha256()
    observed = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            observed += len(chunk)
            if observed > MAX_OUTPUT_FILE_BYTES:
                raise CaptureTransactionError("fresh output grew beyond byte bound")
            h.update(chunk)
    if observed != count:
        raise CaptureTransactionError("fresh output changed size while hashing")
    return {"path": name, "byteCount": count, "sha256": h.hexdigest()}


def required_output_paths(root: Path, family_id: str) -> set[str]:
    node = next(n for n in dependency.lifecycle.NODES if n["id"] == family_id)
    name = node["artifactPath"]
    path = local_path(root, name)
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


def record_fresh_capture(
    root: Path, family_id: str, context: dict[str, str], output_paths: list[str],
    producer_invocation: dict[str, Any], validator_invocation: dict[str, Any],
    producer: Callable[[], int], validator: Callable[[], int],
    *, upstream_bindings: list[dict[str, Any]] | None = None,
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
    if not isinstance(output_paths, list) or not output_paths or len(output_paths) > MAX_OUTPUT_FILES:
        raise CaptureTransactionError("fresh output coverage requires a bounded nonempty path list")
    if any(not isinstance(name, str) for name in output_paths):
        raise CaptureTransactionError("fresh output paths must be strings")
    if nodes[family_id]["artifactPath"] not in output_paths:
        raise CaptureTransactionError("canonical fresh manifest must be declared before production")
    if len(set(output_paths)) != len(output_paths):
        raise CaptureTransactionError("fresh output paths must be unique")
    producer_info, validator_info = invocation(producer_invocation), invocation(validator_invocation)
    before = dependency.capture(root, context)
    dependency.validate_snapshot(before, root)
    upstream_bindings = upstream_bindings or []
    parents = {}
    pool = {b["familyId"]: b for b in upstream_bindings}
    for binding in upstream_bindings:
        validate_binding(binding, root, bindings=pool)
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
        if local_path(root, name).exists():
            raise CaptureTransactionError("cannot backfill or overwrite an existing capture: " + name)
    require_success(producer(), "producer")
    first = sorted((output_record(root, n) for n in output_paths), key=lambda x: x["path"])
    if not required_output_paths(root, family_id) <= set(output_paths):
        raise CaptureTransactionError("fresh output coverage omits manifest or PCM")
    if sum(x["byteCount"] for x in first) > MAX_TOTAL_OUTPUT_BYTES:
        raise CaptureTransactionError("fresh output set exceeds aggregate byte bound")
    require_success(validator(), "independent validator")
    second = sorted((output_record(root, n) for n in output_paths), key=lambda x: x["path"])
    if second != first:
        raise CaptureTransactionError("independent validation changed capture bytes")
    after = dependency.capture(root, context)
    if after != before:
        raise CaptureTransactionError("producer dependencies changed during capture or validation")
    for binding in upstream_bindings:
        validate_binding(binding, root, bindings=pool)
    value = {"schema": SCHEMA, "familyId": family_id,
        "originSnapshot": before, "producerInvocation": producer_info,
        "validatorInvocation": validator_info, "outputs": second,
        "upstreamBindings": parents, "qualification": dict(dependency.QUALIFICATION)}
    value["bindingFingerprint"] = dependency.digest(value)
    return value


def validate_binding(value: object, root: Path, *, bindings: dict[str, Any] | None = None,
                     active: set[str] | None = None) -> None:
    if not isinstance(value, dict) or set(value) != BINDING_KEYS or value.get("schema") != SCHEMA:
        raise CaptureTransactionError("unsupported or incomplete fresh capture binding")
    if value["bindingFingerprint"] != dependency.digest({k: v for k, v in value.items() if k != "bindingFingerprint"}):
        raise CaptureTransactionError("fresh capture binding fingerprint mismatch")
    nodes = {n["id"]: n for n in dependency.lifecycle.NODES}
    if value["familyId"] not in nodes:
        raise CaptureTransactionError("unknown baseline family")
    if value["qualification"] != dependency.QUALIFICATION:
        raise CaptureTransactionError("fresh capture binding cannot establish qualification")
    dependency.validate_snapshot(value["originSnapshot"], root)
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
        if output != output_record(root, name):
            raise CaptureTransactionError("fresh output hash/size mismatch: " + name)
        names.append(name)
        total += output["byteCount"]
    if not required_output_paths(root, value["familyId"]) <= set(names):
        raise CaptureTransactionError("fresh output coverage omits manifest or PCM")
    if names != sorted(set(names)) or total > MAX_TOTAL_OUTPUT_BYTES:
        raise CaptureTransactionError("fresh output coverage/order/aggregate bound mismatch")
