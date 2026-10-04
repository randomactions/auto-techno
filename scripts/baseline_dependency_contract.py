#!/usr/bin/env python3
"""Freeze and compare explicit baseline dependency domains; never qualify artifacts.

This is the producer-contract foundation. Existing lifecycle and family validators
remain authoritative until fresh producer bindings and independent checks adopt it.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
from typing import Any

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import baseline_lifecycle_policy as lifecycle
import roadmap_contract_baseline as contracts

SCHEMA = "autotechno-baseline-dependency-snapshot.v1"
ASSESSMENT_SCHEMA = "autotechno-baseline-dependency-assessment.v1"
HEX = re.compile(r"[0-9a-f]{64}")
MAX_FILES = 4096
MAX_FILE_BYTES = 64 * 1024 * 1024
MAX_METADATA_BYTES = 8 * 1024 * 1024
MAX_TOTAL_BYTES = 128 * 1024 * 1024
CONTEXT_KEYS = {
    "engineVersion", "buildConfiguration", "swiftCompilerIdentity", "sdkIdentity",
    "targetTriple", "compilerFlagsFingerprint", "routeIdentityFingerprint",
    "initialStateFingerprint", "corpusSha256", "pythonIdentity",
}
CONTEXT_HASHES = {k for k in CONTEXT_KEYS if k.endswith("Fingerprint") or k == "corpusSha256"}
NAVIGATION = {"docs/codebase-map.json", "docs/CODEBASE_MAP.md", "scripts/codebase_map.py"}
EXECUTION = {p for _, p in contracts.AUTHORITATIVE_DOCUMENTS} | {
    "docs/ROADMAP_EXECUTION_BASELINE.json"
}
COMMON = {"AGENTS.md", "LICENSE", "docs/BASELINE_DEPENDENCY_CONTRACT.md", "docs/BASELINE_LIFECYCLE_POLICY.json",
          "scripts/baseline_dependency_contract.py", "scripts/baseline_lifecycle_policy.py"}
# Every compiled test file remains conservatively capture-bound. Narrowing that
# closure requires producer proof; neither names nor unchanged PCM confer reuse.
PRODUCERS = {"whole-mix-render", "role-stem-capture", "long-horizon-session",
             "performance-envelope", "score-motif", "section-boundary", "rhythmic-baseline"}
ANALYZERS = {
    n["id"]: n["validatorCommand"].split("scripts/")[1].split()[0]
    for n in lifecycle.NODES
}
ROOT_KEYS = {"schema", "gitHead", "context", "executionFingerprint", "files",
             "families", "unknownPaths", "snapshotFingerprint", "qualification"}
QUALIFICATION = {"runtimeInput": False, "promotionAuthorized": False,
                 "artifactCurrencyEstablished": False}


class DependencyContractError(RuntimeError):
    pass


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("utf-8")


def digest(value: object) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def path_name(value: object) -> str:
    if not isinstance(value, str) or not value or "\\" in value or any(ord(c) < 32 for c in value):
        raise DependencyContractError("invalid repository path")
    p = PurePosixPath(value)
    if p.is_absolute() or any(x in {"", ".", ".."} for x in value.split("/")):
        raise DependencyContractError("noncanonical repository path")
    return value


def regular_bytes(root: Path, name: str) -> bytes:
    name = path_name(name)
    candidate = root
    for part in PurePosixPath(name).parts:
        candidate = candidate / part
        if candidate.is_symlink():
            raise DependencyContractError("dependency cannot traverse a symlink: " + name)
    if not candidate.is_file():
        raise DependencyContractError("dependency missing or not regular: " + name)
    if candidate.stat().st_size > MAX_FILE_BYTES:
        raise DependencyContractError("dependency exceeds byte bound: " + name)
    with candidate.open("rb") as stream:
        data = stream.read(MAX_FILE_BYTES + 1)
    if len(data) > MAX_FILE_BYTES:
        raise DependencyContractError("dependency exceeds byte bound: " + name)
    return data


def git(root: Path, *args: str) -> bytes:
    try:
        return subprocess.check_output(["git", "-c", "core.fsmonitor=false", *args],
                                       cwd=root, stderr=subprocess.PIPE)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise DependencyContractError("git inventory unavailable") from exc


def inventory(root: Path) -> list[str]:
    raw = git(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    try:
        names = sorted(set(x.decode("utf-8") for x in raw.split(b"\x00") if x))
    except UnicodeDecodeError as exc:
        raise DependencyContractError("non-UTF8 dependency path") from exc
    if len(names) > MAX_FILES:
        raise DependencyContractError("dependency inventory exceeds bound")
    return [path_name(n) for n in names]


def validate_context(context: object) -> None:
    if not isinstance(context, dict) or set(context) != CONTEXT_KEYS:
        raise DependencyContractError("capture context requires exactly all versioned fields")
    for key, value in context.items():
        if not isinstance(value, str) or not value or len(value) > 1024:
            raise DependencyContractError("invalid capture context: " + key)
        if key in CONTEXT_HASHES and not HEX.fullmatch(value):
            raise DependencyContractError("invalid context digest: " + key)


def analysis_closure(root: Path, entry: str, names: set[str], reader=None) -> tuple[set[str], bool]:
    """Static local import closure. Dynamic/unknown imports widen to all tooling."""
    pending = ["scripts/" + entry]
    result: set[str] = set()
    uncertain = False
    stdlib = getattr(sys, "stdlib_module_names", frozenset())
    while pending:
        name = pending.pop()
        if name in result:
            continue
        if name not in names:
            raise DependencyContractError("analyzer dependency missing: " + name)
        result.add(name)
        try:
            tree = ast.parse(reader(name) if reader else regular_bytes(root, name), filename=name)
        except (SyntaxError, ValueError) as exc:
            raise DependencyContractError("analyzer cannot be indexed: " + name) from exc
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id in {"__import__", "exec", "eval"}:
                    uncertain = True
            if isinstance(node, ast.Import):
                modules = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom):
                if node.level or node.module is None:
                    uncertain = True
                    continue
                modules = [node.module]
            else:
                continue
            for module in modules:
                first = module.split(".")[0]
                local = "scripts/" + first + ".py"
                if local in names:
                    pending.append(local)
                elif first not in stdlib:
                    uncertain = True
                if first in {"importlib", "runpy"}:
                    uncertain = True
    if uncertain:
        result.update(n for n in names if n.startswith("scripts/") and n.endswith(".py"))
    return result, uncertain


def classification(name: str) -> str:
    if name in NAVIGATION or name.startswith((".github/", ".agents/", ".codex/")) or name in {"README.md", ".gitignore", ".gitattributes", "CODE_OF_CONDUCT.md", "CONTRIBUTING.md", "SECURITY.md"}:
        return "execution"
    if name in COMMON or name in EXECUTION or name.startswith("docs/"):
        return "contract"
    if name in {"Package.swift", "Package.resolved"} or name.startswith(("Sources/", "Tests/", "packaging/")) or (name.startswith("scripts/") and not name.endswith(".py")):
        return "compiled"
    if name.startswith("scripts/") and name.endswith(".py"):
        return "tooling"
    return "unknown"


def capture(root: Path, context: dict[str, str]) -> dict[str, Any]:
    validate_context(context)
    if git(root, "status", "--porcelain", "--untracked-files=all").strip():
        raise DependencyContractError("dependency snapshot requires a clean committed source")
    names = inventory(root)
    name_set = set(names)
    required = COMMON | EXECUTION | {"Package.swift", "docs/BASELINE_CORPUS.json"}
    if missing := sorted(required - name_set):
        raise DependencyContractError("required dependencies absent: " + ", ".join(missing))
    baseline = json.loads(regular_bytes(root, "docs/ROADMAP_EXECUTION_BASELINE.json"))
    errors = contracts.validate_manifest(baseline)
    if errors:
        raise DependencyContractError("invalid execution snapshot: " + "; ".join(errors))
    for record in baseline["documents"]:
        data = regular_bytes(root, record["path"])
        if len(data) != record["byteCount"] or hashlib.sha256(data).hexdigest() != record["sha256"]:
            raise DependencyContractError("execution snapshot stale: " + record["path"])
    corpus = hashlib.sha256(regular_bytes(root, "docs/BASELINE_CORPUS.json")).hexdigest()
    if context["corpusSha256"] != corpus:
        raise DependencyContractError("context corpus hash does not match live bytes")
    if sum((root / n).stat().st_size for n in names) > MAX_TOTAL_BYTES:
        raise DependencyContractError("dependency inventory exceeds total byte bound")
    records = {n: {"sha256": hashlib.sha256(regular_bytes(root, n)).hexdigest(),
                   "classification": classification(n)} for n in names}
    # The full snapshot remains execution authority. Capture identity instead binds
    # every constituent contract except navigation bytes and generated snapshot.
    normative = (EXECUTION - NAVIGATION - {"docs/ROADMAP_EXECUTION_BASELINE.json"}) | COMMON
    compiled = {n for n in names if classification(n) == "compiled"}
    unknown = sorted(n for n in names if classification(n) == "unknown")
    families: dict[str, Any] = {}
    nodes = {n["id"]: n for n in lifecycle.NODES}
    for identifier in lifecycle.topological_order(list(lifecycle.NODES)):
        analysis, uncertain = analysis_closure(root, ANALYZERS[identifier], name_set)
        producer = normative | (compiled if identifier in PRODUCERS else set())
        # Historical broad producers include all scripts. Until their source
        # contract is changed, session/performance remain conservatively broad.
        if identifier in {"long-horizon-session", "performance-envelope"}:
            producer |= {n for n in names if classification(n) == "tooling"}
        upstream = nodes[identifier]["dependencies"]
        producer_context = {k: v for k, v in context.items() if k != "pythonIdentity"}
        producers = {n: records[n]["sha256"] for n in sorted(producer)}
        analyzers = {n: records[n]["sha256"] for n in sorted(analysis | COMMON)}
        families[identifier] = {
            "producerInputs": producers, "analyzerInputs": analyzers,
            "producerFingerprint": digest({"files": producers, "context": producer_context,
                "upstream": {n: families[n]["producerFingerprint"] for n in upstream}}),
            "analysisFingerprint": digest({"files": analyzers, "pythonIdentity": context["pythonIdentity"],
                "upstream": {n: families[n]["analysisFingerprint"] for n in upstream}}),
            "dependencies": list(upstream), "conservativeToolingClosure": uncertain,
        }
    value = {"schema": SCHEMA, "gitHead": git(root, "rev-parse", "HEAD").decode().strip(),
        "context": dict(context), "executionFingerprint": baseline["snapshotFingerprint"],
        "files": records, "families": families, "unknownPaths": unknown,
        "qualification": dict(QUALIFICATION)}
    value["snapshotFingerprint"] = digest(value)
    # Detect additions/deletions and byte changes during this freeze. This does
    # not replace the driver's source freeze through the eventual capture.
    if git(root, "rev-parse", "HEAD").decode().strip() != value["gitHead"] or git(root, "status", "--porcelain", "--untracked-files=all").strip() or inventory(root) != names or any(hashlib.sha256(regular_bytes(root, n)).hexdigest() !=
                                     records[n]["sha256"] for n in names):
        raise DependencyContractError("dependencies changed during snapshot capture")
    return value


def committed_files(root: Path, head: str) -> dict[str, bytes]:
    records = git(root, "ls-tree", "-r", "-l", "-z", head).split(b"\x00")
    identities = []
    total = 0
    for record in records:
        if not record:
            continue
        identity, name = record.split(b"\t", 1)
        mode, kind, sha, count = identity.split()
        if mode not in {b"100644", b"100755"} or kind != b"blob":
            raise DependencyContractError("dependency origin contains a nonregular entry")
        count = int(count)
        total += count
        if count > MAX_FILE_BYTES or total > MAX_TOTAL_BYTES:
            raise DependencyContractError("dependency origin exceeds byte bound")
        identities.append((path_name(name.decode("utf-8")), sha))
    if len(identities) > MAX_FILES:
        raise DependencyContractError("dependency origin inventory exceeds bound")
    try:
        process = subprocess.run(["git", "cat-file", "--batch"], cwd=root,
            input=b"".join(sha + b"\n" for _, sha in identities),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise DependencyContractError("dependency origin objects unavailable") from exc
    data, offset, result = process.stdout, 0, {}
    for name, sha in identities:
        end = data.find(b"\n", offset)
        header = data[offset:end].split()
        if len(header) != 3 or header[0] != sha or header[1] != b"blob":
            raise DependencyContractError("invalid dependency origin object")
        count = int(header[2])
        if count > MAX_FILE_BYTES:
            raise DependencyContractError("dependency origin object exceeds bound")
        start = end + 1
        result[name] = data[start:start + count]
        if len(result[name]) != count or data[start + count:start + count + 1] != b"\n":
            raise DependencyContractError("truncated dependency origin object")
        offset = start + count + 1
    return result


def validate_snapshot(value: object, root: Path | None = None) -> None:
    if not isinstance(value, dict) or set(value) != ROOT_KEYS or value.get("schema") != SCHEMA:
        raise DependencyContractError("unsupported or incomplete dependency snapshot")
    payload = {k: v for k, v in value.items() if k != "snapshotFingerprint"}
    if value["snapshotFingerprint"] != digest(payload):
        raise DependencyContractError("dependency snapshot fingerprint mismatch")
    if value["qualification"] != QUALIFICATION:
        raise DependencyContractError("dependency snapshot cannot claim qualification")
    validate_context(value["context"])
    if not isinstance(value["gitHead"], str) or not re.fullmatch(r"[0-9a-f]{40}", value["gitHead"]):
        raise DependencyContractError("invalid capture origin")
    if not isinstance(value["executionFingerprint"], str) or not HEX.fullmatch(value["executionFingerprint"]):
        raise DependencyContractError("invalid execution fingerprint")
    root = root or Path(__file__).resolve().parents[1]
    originals = committed_files(root, value["gitHead"])
    expected = {n["id"]: n for n in lifecycle.NODES}
    if not isinstance(value["families"], dict) or set(value["families"]) != set(expected):
        raise DependencyContractError("dependency snapshot must cover every family")
    if not isinstance(value["files"], dict) or len(value["files"]) > MAX_FILES:
        raise DependencyContractError("invalid file inventory")
    if set(originals) != set(value["files"]):
        raise DependencyContractError("origin dependency inventory mismatch")
    for name, record in value["files"].items():
        path_name(name)
        if not isinstance(record, dict) or set(record) != {"sha256", "classification"}:
            raise DependencyContractError("invalid dependency record")
        if not isinstance(record["sha256"], str) or not HEX.fullmatch(record["sha256"]):
            raise DependencyContractError("invalid dependency hash")
        if record["sha256"] != hashlib.sha256(originals[name]).hexdigest():
            raise DependencyContractError("origin dependency bytes mismatch")
        if record["classification"] != classification(name):
            raise DependencyContractError("invalid dependency classification")
    unknown = sorted(n for n in value["files"] if classification(n) == "unknown")
    if value["unknownPaths"] != unknown:
        raise DependencyContractError("unknown dependency coverage mismatch")
    required = COMMON | EXECUTION | {"Package.swift", "docs/BASELINE_CORPUS.json"}
    if required - set(value["files"]):
        raise DependencyContractError("required inventory coverage missing")
    origin_baseline = json.loads(originals["docs/ROADMAP_EXECUTION_BASELINE.json"])
    if contracts.validate_manifest(origin_baseline) or value["executionFingerprint"] != origin_baseline["snapshotFingerprint"]:
        raise DependencyContractError("origin execution binding mismatch")
    for record in origin_baseline["documents"]:
        data = originals.get(record["path"])
        if data is None or len(data) != record["byteCount"] or hashlib.sha256(data).hexdigest() != record["sha256"]:
            raise DependencyContractError("origin execution snapshot is stale")
    if value["context"]["corpusSha256"] != hashlib.sha256(originals["docs/BASELINE_CORPUS.json"]).hexdigest():
        raise DependencyContractError("origin corpus context mismatch")
    for name in lifecycle.topological_order(list(lifecycle.NODES)):
        family = value["families"][name]
        if not isinstance(family, dict) or set(family) != {"producerInputs", "analyzerInputs",
                "producerFingerprint", "analysisFingerprint", "dependencies", "conservativeToolingClosure"}:
            raise DependencyContractError("invalid family dependency binding")
        if family["dependencies"] != expected[name]["dependencies"]:
            raise DependencyContractError("family graph mismatch")
        if not isinstance(family["conservativeToolingClosure"], bool):
            raise DependencyContractError("invalid conservative closure flag")
        for field in ["producerInputs", "analyzerInputs"]:
            if not isinstance(family[field], dict) or not family[field]:
                raise DependencyContractError("missing family dependency inputs")
            for path, sha in family[field].items():
                if path not in value["files"] or sha != value["files"][path]["sha256"]:
                    raise DependencyContractError("family dependency hash mismatch")
        for field in ["producerFingerprint", "analysisFingerprint"]:
            if not isinstance(family[field], str) or not HEX.fullmatch(family[field]):
                raise DependencyContractError("invalid family fingerprint")
        normative = (EXECUTION - NAVIGATION - {"docs/ROADMAP_EXECUTION_BASELINE.json"}) | COMMON
        producer_set = normative | ({n for n in value["files"] if classification(n) == "compiled"}
                                     if name in PRODUCERS else set())
        if name in {"long-horizon-session", "performance-envelope"}:
            producer_set |= {n for n in value["files"] if classification(n) == "tooling"}
        if set(family["producerInputs"]) != producer_set or not COMMON <= set(family["analyzerInputs"]):
            raise DependencyContractError("producer or analyzer coverage mismatch")
        entry = "scripts/" + ANALYZERS[name]
        if entry not in family["analyzerInputs"]:
            raise DependencyContractError("analyzer entry absent")
        closure, uncertain = analysis_closure(root, ANALYZERS[name], set(originals), originals.__getitem__)
        if set(family["analyzerInputs"]) != closure | COMMON or family["conservativeToolingClosure"] != uncertain:
            raise DependencyContractError("origin analyzer closure mismatch")
        if family["conservativeToolingClosure"] and not {n for n in value["files"]
                if n.startswith("scripts/") and n.endswith(".py")} <= set(family["analyzerInputs"]):
            raise DependencyContractError("uncertain analyzer closure was narrowed")
        upstream = family["dependencies"]
        producer_context = {k: v for k, v in value["context"].items() if k != "pythonIdentity"}
        expected_producer = digest({"files": family["producerInputs"], "context": producer_context,
            "upstream": {n: value["families"][n]["producerFingerprint"] for n in upstream}})
        expected_analysis = digest({"files": family["analyzerInputs"],
            "pythonIdentity": value["context"]["pythonIdentity"],
            "upstream": {n: value["families"][n]["analysisFingerprint"] for n in upstream}})
        if family["producerFingerprint"] != expected_producer or family["analysisFingerprint"] != expected_analysis:
            raise DependencyContractError("family dependency fingerprint mismatch")


def assess(before: dict[str, Any], after: dict[str, Any], root: Path | None = None) -> dict[str, Any]:
    validate_snapshot(before, root)
    validate_snapshot(after, root)
    changed = sorted(n for n in set(before["files"]) | set(after["files"])
                     if before["files"].get(n) != after["files"].get(n))
    unknown = sorted(set(before["unknownPaths"]) | set(after["unknownPaths"]))
    # Unassigned added/deleted documents cannot be silently classified harmless.
    accounted = set(EXECUTION) | NAVIGATION | COMMON
    for snapshot in [before, after]:
        for family in snapshot["families"].values():
            accounted.update(family["producerInputs"])
            accounted.update(family["analyzerInputs"])
    uncovered = [n for n in changed if n not in accounted and classification(n) != "execution"]
    unknown = sorted(set(unknown) | set(uncovered))
    results = {}
    for name in lifecycle.topological_order(list(lifecycle.NODES)):
        old, new = before["families"][name], after["families"][name]
        producer_changed = old["producerFingerprint"] != new["producerFingerprint"]
        analyzer_changed = old["analysisFingerprint"] != new["analysisFingerprint"]
        state = "dependencies-unchanged"
        if unknown or producer_changed:
            state = "recapture-required"
        elif analyzer_changed:
            state = "reanalysis-required"
        elif before["executionFingerprint"] != after["executionFingerprint"] or changed:
            state = "revalidation-required"
        if any(results[n]["action"] == "recapture-required" for n in new["dependencies"]):
            state = "recapture-required"
        elif state != "recapture-required" and any(results[n]["action"] == "reanalysis-required"
                                                    for n in new["dependencies"]):
            state = "reanalysis-required"
        results[name] = {"action": state, "producerChanged": producer_changed,
                         "analyzerChanged": analyzer_changed}
    result = {"schema": ASSESSMENT_SCHEMA,
        "baselineSnapshotFingerprint": before["snapshotFingerprint"],
        "currentSnapshotFingerprint": after["snapshotFingerprint"],
        "changedPaths": changed, "unresolvedPaths": unknown,
        "families": results, "qualification": dict(QUALIFICATION),
        "legacyArtifacts": "full-current-source-validation-still-required"}
    result["assessmentFingerprint"] = digest(result)
    return result


def read_json(path: Path) -> Any:
    if path.stat().st_size > MAX_METADATA_BYTES:
        raise DependencyContractError("metadata exceeds byte bound")
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        value = {}
        for key, item in items:
            if key in value:
                raise DependencyContractError("duplicate metadata key: " + key)
            value[key] = item
        return value
    return json.loads(path.read_text(), object_pairs_hook=pairs)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["capture", "assess"])
    parser.add_argument("--context", required=True, type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        root = Path(__file__).resolve().parents[1]
        current = capture(root, read_json(args.context))
        if args.command == "assess":
            if args.baseline is None:
                raise DependencyContractError("assessment requires an original snapshot")
            result = assess(read_json(args.baseline), current)
        else:
            result = current
        relative = args.output.resolve().relative_to(root.resolve())
        if not relative.as_posix().startswith("docs/local/"):
            raise DependencyContractError("dependency metadata output must remain local")
        if args.output.exists():
            raise DependencyContractError("refusing to overwrite dependency history")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x") as stream:
            stream.write(json.dumps(result, indent=2, sort_keys=True) + "\n")
        print("Dependency metadata written; artifact qualification remains unavailable.")
        return 0
    except (DependencyContractError, OSError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
