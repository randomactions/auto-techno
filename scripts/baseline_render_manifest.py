#!/usr/bin/env python3
"""Verify local whole-mix baseline WAVs and their exact provenance manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import struct
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence, TextIO


SCHEMA = "autotechno-baseline-render-manifest.v1"
ROOT_KEYS = {
    "schema", "manifestVersion", "corpusSha256", "contractBaselineFingerprint",
    "sourceFingerprint", "gitHead", "engineVersion", "entries",
}
ENTRY_KEYS = {
    "id", "caseId", "routeId", "rootSeed", "checkpoint", "continuationClass",
    "phraseIndex", "startBar", "phraseKind", "stateFingerprint",
    "planFingerprint", "replayFingerprint", "policyVersion", "qualityOutcome",
    "sampleRate", "channelCount", "frameCount", "pcmSha256", "wavPath",
    "wavSha256",
}


class BaselineRenderManifestError(RuntimeError):
    """An actionable local baseline evidence failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def capture_namespace(namespace: Optional[str] = None) -> str:
    value = (
        namespace
        if namespace is not None
        else os.environ.get("AUTOTECHNO_CAPTURE_NAMESPACE", "v1")
    )
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", value):
        raise BaselineRenderManifestError("capture namespace must be lowercase letters, digits, and hyphens")
    return value


def manifest_path(root: Path, namespace: Optional[str] = None) -> Path:
    selected = capture_namespace(namespace)
    return root / f"docs/local/reports/baseline-corpus-{selected}/manifest.json"


def resolve_corpus_path(root: Path, corpus: Optional[str] = None) -> Path:
    relative = corpus or os.environ.get(
        "AUTOTECHNO_CAPTURE_CORPUS", "docs/BASELINE_CORPUS.json"
    )
    if relative != "docs/BASELINE_CORPUS.json" and not relative.startswith("docs/local/"):
        raise BaselineRenderManifestError(
            "capture corpus must be docs/BASELINE_CORPUS.json or a docs/local file"
        )
    if ".." in Path(relative).parts or Path(relative).is_absolute():
        raise BaselineRenderManifestError("capture corpus path cannot traverse directories")
    candidate = root / relative
    if candidate.is_symlink():
        raise BaselineRenderManifestError("capture corpus cannot be a symlink")
    try:
        resolved = candidate.resolve(strict=True)
        resolved.relative_to(root.resolve(strict=True))
    except (OSError, ValueError) as exc:
        raise BaselineRenderManifestError("capture corpus must resolve inside this repository") from exc
    if not resolved.is_file():
        raise BaselineRenderManifestError("capture corpus must be a regular file")
    return resolved


def audio_directory(root: Path, namespace: Optional[str] = None) -> Path:
    selected = capture_namespace(namespace)
    return root / f"docs/local/audio/baseline-corpus-{selected}"


def load_json(path: Path, label: str) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BaselineRenderManifestError(f"cannot read {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise BaselineRenderManifestError(f"{label} must contain one JSON object")
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_fingerprint(root: Path) -> str:
    """Reconstruct the existing BaselineRenderIntegrationTests byte identity.

    Git HEAD is capture provenance, not a substitute for source-byte identity:
    committing derived reports must not require another audio regeneration.
    """
    source_root = root / "Sources"
    if source_root.is_symlink() or not source_root.is_dir():
        raise BaselineRenderManifestError("source identity requires a real Sources directory")
    paths = [
        root / "Package.swift",
        root / "docs/BASELINE_CORPUS.json",
        root / "docs/ROADMAP_EXECUTION_BASELINE.json",
    ]

    def reject_walk_error(error: OSError) -> None:
        raise error

    for directory, directories, files in os.walk(source_root, onerror=reject_walk_error):
        for name in directories:
            if (Path(directory) / name).is_symlink():
                raise BaselineRenderManifestError("source identity cannot traverse a symlink")
        paths.extend(Path(directory) / name for name in files)
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda item: item.relative_to(root).as_posix()):
        if path.is_symlink() or not path.is_file():
            raise BaselineRenderManifestError("source identity requires regular non-symlink files")
        digest.update(path.relative_to(root).as_posix().encode("utf-8"))
        digest.update(b"\0")
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def is_hex(value: object, length: int) -> bool:
    return isinstance(value, str) and len(value) == length and all(
        character in "0123456789abcdef" for character in value
    )


def capture_revision_error(root: Path, revision: object) -> str | None:
    """Validate historical capture lineage; callers separately bind current bytes."""
    if not is_hex(revision, 40):
        return "capture Git revision must be a full lowercase commit ID"
    commands = (
        (["cat-file", "-e", str(revision) + "^{commit}"],
         "capture Git revision is not an available commit"),
        (["merge-base", "--is-ancestor", str(revision), "HEAD"],
         "capture Git revision is not an ancestor of current HEAD"),
    )
    for arguments, diagnostic in commands:
        try:
            result = subprocess.run(
                ["git", "--no-replace-objects", "-C", str(root), *arguments],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                check=False, timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired):
            return "cannot verify capture Git ancestry"
        if result.returncode != 0:
            return diagnostic
    return None


def exact_keys(value: Mapping[str, Any], expected: set[str], location: str) -> list[str]:
    if set(value) == expected:
        return []
    return [
        f"{location} fields must be exactly {sorted(expected)}; found {sorted(value)}"
    ]


def expected_entries(corpus: Mapping[str, Any]) -> dict[str, tuple[Mapping[str, Any], Mapping[str, Any]]]:
    return {
        f"{case['id']}--{route['id']}": (case, route)
        for case in corpus.get("cases", [])
        for route in corpus.get("routes", [])
        if isinstance(case, dict) and isinstance(route, dict)
    }


def parse_wav(path: Path) -> tuple[int, int, int, bytes]:
    data = path.read_bytes()
    if len(data) < 44 or data[0:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("is not a canonical WAV")
    if data[12:16] != b"fmt " or struct.unpack_from("<I", data, 16)[0] != 16:
        raise ValueError("must use a 16-byte fmt chunk")
    audio_format, channels = struct.unpack_from("<HH", data, 20)
    sample_rate = struct.unpack_from("<I", data, 24)[0]
    byte_rate, block_align, bits = struct.unpack_from("<IHH", data, 28)
    if audio_format != 3 or channels != 2 or bits != 32 or block_align != 8:
        raise ValueError("must be stereo 32-bit IEEE-float WAV")
    if byte_rate != sample_rate * block_align:
        raise ValueError("has inconsistent byte rate")
    if data[36:40] != b"data":
        raise ValueError("must place the data chunk after fmt")
    data_size = struct.unpack_from("<I", data, 40)[0]
    pcm = data[44:]
    if data_size != len(pcm) or len(pcm) % block_align:
        raise ValueError("has inconsistent PCM size")
    riff_size = struct.unpack_from("<I", data, 4)[0]
    if riff_size != len(data) - 8:
        raise ValueError("has inconsistent RIFF size")
    if any(not math.isfinite(value) for (value,) in struct.iter_unpack("<f", pcm)):
        raise ValueError("contains non-finite PCM")
    return sample_rate, channels, len(pcm) // block_align, pcm


def validate(
    root: Path,
    namespace: Optional[str] = None,
    corpus_relative_path: Optional[str] = None,
) -> list[str]:
    errors: list[str] = []
    try:
        namespace = capture_namespace(namespace)
        corpus_path = resolve_corpus_path(root, corpus_relative_path)
        corpus = load_json(corpus_path, "corpus")
        baseline = load_json(root / "docs/ROADMAP_EXECUTION_BASELINE.json", "contract baseline")
        manifest = load_json(manifest_path(root, namespace), "local render manifest")
    except BaselineRenderManifestError as exc:
        return [str(exc)]
    errors += exact_keys(manifest, ROOT_KEYS, "manifest")
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if manifest.get("manifestVersion") != 1:
        errors.append("manifestVersion must be 1")
    if manifest.get("corpusSha256") != sha256(corpus_path):
        errors.append("corpusSha256 does not match the tracked corpus or selected local corpus")
    if manifest.get("contractBaselineFingerprint") != baseline.get("snapshotFingerprint"):
        errors.append("contractBaselineFingerprint does not match the current baseline")
    for field, length in (("sourceFingerprint", 64), ("gitHead", 40)):
        if not is_hex(manifest.get(field), length):
            errors.append(f"{field} must be {length} lowercase hexadecimal digits")
    try:
        current_source_fingerprint = source_fingerprint(root)
        if manifest.get("sourceFingerprint") != current_source_fingerprint:
            errors.append("sourceFingerprint does not match the current source")
    except (OSError, BaselineRenderManifestError) as exc:
        errors.append(f"cannot verify current source identity: {exc}")
        current_source_fingerprint = None
    if corpus.get("schema") == "autotechno-at0039-foundation-cohort.v1":
        if corpus.get("sourceFingerprint") != current_source_fingerprint:
            errors.append("AT-0039 cohort sourceFingerprint does not match current source")
        if corpus.get("contractBaselineFingerprint") != baseline.get("snapshotFingerprint"):
            errors.append("AT-0039 cohort contract baseline does not match current baseline")
    if not isinstance(manifest.get("engineVersion"), str) or not manifest.get("engineVersion"):
        errors.append("engineVersion must be non-empty")

    expected = expected_entries(corpus)
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        errors.append("entries must be an array")
        entries = []
    seen: set[str] = set()
    referenced_wavs: set[str] = set()
    for index, entry in enumerate(entries):
        location = f"entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{location} must be an object")
            continue
        errors += exact_keys(entry, ENTRY_KEYS, location)
        identifier = entry.get("id")
        if not isinstance(identifier, str) or identifier not in expected:
            errors.append(f"{location}.id is not a corpus/route identity: {identifier}")
            continue
        if identifier in seen:
            errors.append(f"duplicate entry id {identifier}")
        seen.add(identifier)
        case, route = expected[identifier]
        bindings = {
            "caseId": case["id"], "routeId": route["id"],
            "rootSeed": case["rootSeed"], "checkpoint": case["checkpoint"],
            "continuationClass": case["continuationClass"],
            "sampleRate": route["sampleRate"], "channelCount": route["channelCount"],
        }
        for field, wanted in bindings.items():
            if entry.get(field) != wanted:
                errors.append(f"{location}.{field} must be {wanted!r}")
        for field in ("phraseIndex", "startBar", "frameCount"):
            value = entry.get(field)
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                errors.append(f"{location}.{field} must be a non-negative integer")
        for field in ("stateFingerprint", "planFingerprint", "replayFingerprint"):
            if not is_hex(entry.get(field), 16):
                errors.append(f"{location}.{field} must be a typed 16-digit fingerprint")
        for field in ("pcmSha256", "wavSha256"):
            if not is_hex(entry.get(field), 64):
                errors.append(f"{location}.{field} must be a SHA-256 digest")
        if entry.get("qualityOutcome") not in {"qualified", "adjusted"}:
            errors.append(f"{location}.qualityOutcome must be qualified or adjusted")
        if not isinstance(entry.get("policyVersion"), str) or not entry.get("policyVersion"):
            errors.append(f"{location}.policyVersion must be non-empty")
        expected_path = f"docs/local/audio/baseline-corpus-{namespace}/{identifier}.wav"
        if entry.get("wavPath") != expected_path:
            errors.append(f"{location}.wavPath must be {expected_path}")
            continue
        normalized = PurePosixPath(expected_path)
        wav = root.joinpath(*normalized.parts)
        referenced_wavs.add(expected_path)
        try:
            rate, channels, frames, pcm = parse_wav(wav)
        except (OSError, ValueError) as exc:
            errors.append(f"{location}.wavPath {exc}")
            continue
        if (rate, channels, frames) != (
            entry.get("sampleRate"), entry.get("channelCount"), entry.get("frameCount")
        ):
            errors.append(f"{location} WAV geometry does not match the manifest")
        if hashlib.sha256(pcm).hexdigest() != entry.get("pcmSha256"):
            errors.append(f"{location}.pcmSha256 does not match WAV PCM")
        if sha256(wav) != entry.get("wavSha256"):
            errors.append(f"{location}.wavSha256 does not match the file")
    missing = sorted(set(expected) - seen)
    if missing:
        errors.append("manifest omits identities: " + ", ".join(missing))
    if len(entries) != len(expected):
        errors.append(f"entries must contain exactly {len(expected)} identities")
    actual_wavs = {
        path.relative_to(root).as_posix()
        for path in audio_directory(root, namespace).glob("*.wav")
    } if audio_directory(root, namespace).is_dir() else set()
    extras = sorted(actual_wavs - referenced_wavs)
    if extras:
        errors.append("audio directory has unreferenced WAVs: " + ", ".join(extras))
    return errors


def run_check(
    root: Path,
    output: TextIO = sys.stdout,
    namespace: Optional[str] = None,
    corpus_relative_path: Optional[str] = None,
) -> int:
    errors = validate(root, namespace, corpus_relative_path)
    if errors:
        print(f"baseline renders rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, 1):
            print(f"  {index}. {error}", file=output)
        return 1
    print("baseline renders are current: 14 exact local WAV identities", file=output)
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check",))
    parser.add_argument("--namespace", help="select an isolated capture namespace (default: v1)")
    parser.add_argument("--corpus", help="relative canonical or docs/local corpus path")
    arguments = parser.parse_args(argv)
    if arguments.command == "check":
        return run_check(
            repository_root(),
            namespace=arguments.namespace,
            corpus_relative_path=arguments.corpus,
        )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
