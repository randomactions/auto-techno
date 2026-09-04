#!/usr/bin/env python3
"""Verify aligned local role stems and their nonlinear residual contract."""

from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
import struct
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence, TextIO


SCHEMA = "autotechno-role-stem-manifest.v1"
TOLERANCE = 0.000_001
SIGNALS = {
    "kick": ("linear-role", 1),
    "foundation": ("linear-role", 1),
    "modal-foundation": ("protected-subrole", 1),
    "percussion": ("linear-role", 1),
    "upper-tonal": ("linear-role", 1),
    "atmosphere": ("linear-role", 1),
    "protected-foundation": ("protected-variant", 1),
    "dry-center-reference": ("reconstruction-reference", 1),
    "dry-upper-reference": ("reconstruction-reference", 1),
    "protected-rhythm": ("protected-variant", 2),
    "graph-input": ("processed-stage", 2),
    "processed-upper": ("processed-stage", 2),
    "pre-climax-mix": ("processed-stage", 2),
    "output-safety-residual": ("nonlinear-residual", 2),
    "terminal-processing-residual": ("nonlinear-residual", 2),
}
ROOT_KEYS = {
    "schema", "manifestVersion", "corpusSha256", "wholeMixManifestSha256",
    "contractBaselineFingerprint", "sourceFingerprint", "gitHead",
    "engineVersion", "nonlinearExceptions", "entries",
}
ENTRY_KEYS = {
    "id", "caseId", "routeId", "rootSeed", "checkpoint",
    "continuationClass", "phraseIndex", "startBar", "phraseKind",
    "stateFingerprint", "planFingerprint", "replayFingerprint",
    "policyVersion", "qualityOutcome", "sampleRate", "wholeMixChannelCount",
    "frameCount", "wholeMixPcmSha256", "reconstruction", "files",
}
FILE_KEYS = {
    "signal", "classification", "channelCount", "sampleRate", "frameCount",
    "pcmSha256", "wavPath", "wavSha256",
}
RECONSTRUCTION_KEYS = {
    "protectedFoundationMaximumError", "dryCenterMaximumError",
    "dryUpperMaximumError", "protectedPassMaximumError",
    "preClimaxMaximumError", "finalMixMaximumError", "tolerance",
}
EXCEPTION_REQUIRED_KEYS = {"id", "stage", "reason"}
EXCEPTION_OPTIONAL_KEYS = {"residualSignal"}


class StemCaptureManifestError(RuntimeError):
    """An actionable local stem-evidence failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def manifest_path(root: Path) -> Path:
    return root / "docs/local/reports/baseline-stems-v1/manifest.json"


def whole_mix_manifest_path(root: Path) -> Path:
    return root / "docs/local/reports/baseline-corpus-v1/manifest.json"


def audio_directory(root: Path) -> Path:
    return root / "docs/local/audio/baseline-stems-v1"


def load_json(path: Path, label: str) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise StemCaptureManifestError(f"cannot read {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise StemCaptureManifestError(f"{label} must contain one JSON object")
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_hex(value: object, length: int) -> bool:
    return isinstance(value, str) and len(value) == length and all(
        character in "0123456789abcdef" for character in value
    )


def exact_keys(
    value: Mapping[str, Any], expected: set[str], location: str
) -> list[str]:
    if set(value) == expected:
        return []
    return [
        f"{location} fields must be exactly {sorted(expected)}; "
        f"found {sorted(value)}"
    ]


def expected_entries(
    corpus: Mapping[str, Any]
) -> dict[str, tuple[Mapping[str, Any], Mapping[str, Any]]]:
    return {
        f"{case['id']}--{route['id']}": (case, route)
        for case in corpus.get("cases", [])
        for route in corpus.get("routes", [])
        if isinstance(case, dict) and isinstance(route, dict)
    }


def parse_wav(path: Path) -> tuple[int, int, int, bytes, array[float]]:
    data = path.read_bytes()
    if len(data) < 44 or data[0:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("is not a canonical WAV")
    if data[12:16] != b"fmt " or struct.unpack_from("<I", data, 16)[0] != 16:
        raise ValueError("must use a 16-byte fmt chunk")
    audio_format, channels = struct.unpack_from("<HH", data, 20)
    sample_rate = struct.unpack_from("<I", data, 24)[0]
    byte_rate, block_align, bits = struct.unpack_from("<IHH", data, 28)
    if audio_format != 3 or channels not in {1, 2} or bits != 32:
        raise ValueError("must be mono/stereo 32-bit IEEE-float WAV")
    if block_align != channels * 4 or byte_rate != sample_rate * block_align:
        raise ValueError("has inconsistent byte geometry")
    if data[36:40] != b"data":
        raise ValueError("must place the data chunk after fmt")
    data_size = struct.unpack_from("<I", data, 40)[0]
    pcm = data[44:]
    if data_size != len(pcm) or len(pcm) % block_align:
        raise ValueError("has inconsistent PCM size")
    if struct.unpack_from("<I", data, 4)[0] != len(data) - 8:
        raise ValueError("has inconsistent RIFF size")
    samples = array("f")
    samples.frombytes(pcm)
    if sys.byteorder != "little":
        samples.byteswap()
    if any(not math.isfinite(value) for value in samples):
        raise ValueError("contains non-finite PCM")
    return sample_rate, channels, len(pcm) // block_align, pcm, samples


def deinterleave(samples: array[float], channels: int) -> tuple[Sequence[float], Sequence[float]]:
    if channels == 1:
        return samples, ()
    return samples[0::2], samples[1::2]


def float32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


def maximum_sum_error(
    target: Sequence[float], *parts: Sequence[float]
) -> float:
    def error(index: int) -> float:
        total = parts[0][index]
        for part in parts[1:]:
            total = float32(total + part[index])
        return abs(float32(target[index] - total))

    return max(
        (error(index) for index in range(len(target))),
        default=0.0,
    )


def maximum_dry_center_error(
    target: Sequence[float],
    protected_foundation: Sequence[float],
    percussion: Sequence[float],
    modal_foundation: Sequence[float],
) -> float:
    def error(index: int) -> float:
        with_percussion = float32(
            protected_foundation[index] + percussion[index]
        )
        reconstructed = float32(with_percussion - modal_foundation[index])
        return abs(float32(target[index] - reconstructed))

    return max((error(index) for index in range(len(target))), default=0.0)


def validate_reconstruction(
    entry: Mapping[str, Any],
    signals: Mapping[str, tuple[Sequence[float], Sequence[float]]],
    whole_left: Sequence[float],
    whole_right: Sequence[float],
    location: str,
) -> list[str]:
    errors: list[str] = []
    measured = {
        "protectedFoundationMaximumError": maximum_sum_error(
            signals["protected-foundation"][0],
            signals["kick"][0],
            signals["foundation"][0],
        ),
        "dryCenterMaximumError": maximum_dry_center_error(
            signals["dry-center-reference"][0],
            signals["protected-foundation"][0],
            signals["percussion"][0],
            signals["modal-foundation"][0],
        ),
        "dryUpperMaximumError": maximum_sum_error(
            signals["dry-upper-reference"][0],
            signals["upper-tonal"][0],
            signals["atmosphere"][0],
        ),
        "preClimaxMaximumError": max(
            maximum_sum_error(
                signals["pre-climax-mix"][0],
                signals["protected-rhythm"][0],
                signals["processed-upper"][0],
                signals["output-safety-residual"][0],
            ),
            maximum_sum_error(
                signals["pre-climax-mix"][1],
                signals["protected-rhythm"][1],
                signals["processed-upper"][1],
                signals["output-safety-residual"][1],
            ),
        ),
        "finalMixMaximumError": max(
            maximum_sum_error(
                whole_left,
                signals["pre-climax-mix"][0],
                signals["terminal-processing-residual"][0],
            ),
            maximum_sum_error(
                whole_right,
                signals["pre-climax-mix"][1],
                signals["terminal-processing-residual"][1],
            ),
        ),
    }
    reconstruction = entry.get("reconstruction")
    if not isinstance(reconstruction, dict):
        return [f"{location}.reconstruction must be an object"]
    errors += exact_keys(reconstruction, RECONSTRUCTION_KEYS, f"{location}.reconstruction")
    if reconstruction.get("tolerance") != TOLERANCE:
        errors.append(f"{location}.reconstruction.tolerance must be {TOLERANCE}")
    protected_pass = reconstruction.get("protectedPassMaximumError")
    if protected_pass != 0:
        errors.append(f"{location}.protectedPassMaximumError must be exactly zero")
    for field, value in measured.items():
        recorded = reconstruction.get(field)
        if not isinstance(recorded, (int, float)) or isinstance(recorded, bool):
            errors.append(f"{location}.reconstruction.{field} must be numeric")
            continue
        if abs(float(recorded) - value) > 1e-12:
            errors.append(
                f"{location}.reconstruction.{field} does not match WAV PCM"
            )
        if value >= TOLERANCE:
            errors.append(
                f"{location}.reconstruction.{field} exceeds {TOLERANCE}: {value}"
            )
    return errors


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    try:
        corpus = load_json(root / "docs/BASELINE_CORPUS.json", "corpus")
        baseline = load_json(
            root / "docs/ROADMAP_EXECUTION_BASELINE.json", "contract baseline"
        )
        whole = load_json(whole_mix_manifest_path(root), "whole-mix manifest")
        manifest = load_json(manifest_path(root), "stem manifest")
    except StemCaptureManifestError as exc:
        return [str(exc)]
    errors += exact_keys(manifest, ROOT_KEYS, "manifest")
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if manifest.get("manifestVersion") != 1:
        errors.append("manifestVersion must be 1")
    if manifest.get("corpusSha256") != sha256(root / "docs/BASELINE_CORPUS.json"):
        errors.append("corpusSha256 does not match the tracked corpus")
    if manifest.get("wholeMixManifestSha256") != sha256(
        whole_mix_manifest_path(root)
    ):
        errors.append("wholeMixManifestSha256 does not match the local manifest")
    if manifest.get("contractBaselineFingerprint") != baseline.get(
        "snapshotFingerprint"
    ):
        errors.append("contractBaselineFingerprint does not match current baseline")
    if manifest.get("sourceFingerprint") != whole.get("sourceFingerprint"):
        errors.append("sourceFingerprint must match the whole-mix render source")
    for field, length in (("sourceFingerprint", 64), ("gitHead", 40)):
        if not is_hex(manifest.get(field), length):
            errors.append(f"{field} must be {length} lowercase hexadecimal digits")
    if manifest.get("gitHead") != whole.get("gitHead"):
        errors.append("gitHead must match the whole-mix render manifest")
    if manifest.get("engineVersion") != whole.get("engineVersion"):
        errors.append("engineVersion must match the whole-mix render manifest")

    exceptions = manifest.get("nonlinearExceptions")
    if not isinstance(exceptions, list):
        errors.append("nonlinearExceptions must be an array")
        exceptions = []
    exception_ids: set[str] = set()
    residuals: set[str] = set()
    for index, exception in enumerate(exceptions):
        location = f"nonlinearExceptions[{index}]"
        if not isinstance(exception, dict):
            errors.append(f"{location} must be an object")
            continue
        if not EXCEPTION_REQUIRED_KEYS.issubset(exception) or not set(
            exception
        ).issubset(EXCEPTION_REQUIRED_KEYS | EXCEPTION_OPTIONAL_KEYS):
            errors.append(
                f"{location} fields must contain {sorted(EXCEPTION_REQUIRED_KEYS)} "
                f"and only optional {sorted(EXCEPTION_OPTIONAL_KEYS)}; "
                f"found {sorted(exception)}"
            )
        identifier = exception.get("id")
        if not isinstance(identifier, str) or not identifier:
            errors.append(f"{location}.id must be non-empty")
        elif identifier in exception_ids:
            errors.append(f"duplicate nonlinear exception {identifier}")
        else:
            exception_ids.add(identifier)
        for field in ("stage", "reason"):
            if not isinstance(exception.get(field), str) or not exception[field]:
                errors.append(f"{location}.{field} must be non-empty")
        residual = exception.get("residualSignal")
        if residual is not None:
            if residual not in SIGNALS or SIGNALS[residual][0] != "nonlinear-residual":
                errors.append(f"{location}.residualSignal is not a residual signal")
            else:
                residuals.add(residual)
    if exception_ids != {
        "voice-shared-processing", "modal-post-master-insertion",
        "outer-output-safety", "terminal-processing"
    }:
        errors.append("nonlinearExceptions must name the three governed stages")
    if residuals != {"output-safety-residual", "terminal-processing-residual"}:
        errors.append("both nonlinear residual signals must be classified")

    expected = expected_entries(corpus)
    whole_entries = {
        entry.get("id"): entry
        for entry in whole.get("entries", [])
        if isinstance(entry, dict) and isinstance(entry.get("id"), str)
    }
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
        whole_entry = whole_entries.get(identifier)
        if not isinstance(whole_entry, dict):
            errors.append(f"{location} has no whole-mix entry")
            continue
        bindings = {
            "caseId": case["id"], "routeId": route["id"],
            "rootSeed": case["rootSeed"], "checkpoint": case["checkpoint"],
            "continuationClass": case["continuationClass"],
            "sampleRate": route["sampleRate"],
            "wholeMixChannelCount": route["channelCount"],
            "phraseIndex": whole_entry.get("phraseIndex"),
            "startBar": whole_entry.get("startBar"),
            "phraseKind": whole_entry.get("phraseKind"),
            "stateFingerprint": whole_entry.get("stateFingerprint"),
            "planFingerprint": whole_entry.get("planFingerprint"),
            "replayFingerprint": whole_entry.get("replayFingerprint"),
            "policyVersion": whole_entry.get("policyVersion"),
            "qualityOutcome": whole_entry.get("qualityOutcome"),
            "frameCount": whole_entry.get("frameCount"),
            "wholeMixPcmSha256": whole_entry.get("pcmSha256"),
        }
        for field, wanted in bindings.items():
            if entry.get(field) != wanted:
                errors.append(f"{location}.{field} must be {wanted!r}")
        files = entry.get("files")
        if not isinstance(files, list):
            errors.append(f"{location}.files must be an array")
            continue
        seen_signals: set[str] = set()
        decoded: dict[str, tuple[Sequence[float], Sequence[float]]] = {}
        for file_index, stem in enumerate(files):
            file_location = f"{location}.files[{file_index}]"
            if not isinstance(stem, dict):
                errors.append(f"{file_location} must be an object")
                continue
            errors += exact_keys(stem, FILE_KEYS, file_location)
            signal = stem.get("signal")
            if signal not in SIGNALS:
                errors.append(f"{file_location}.signal is not governed: {signal}")
                continue
            if signal in seen_signals:
                errors.append(f"{location} duplicates signal {signal}")
            seen_signals.add(signal)
            classification, channels = SIGNALS[signal]
            for field, wanted in {
                "classification": classification,
                "channelCount": channels,
                "sampleRate": route["sampleRate"],
                "frameCount": entry.get("frameCount"),
            }.items():
                if stem.get(field) != wanted:
                    errors.append(f"{file_location}.{field} must be {wanted!r}")
            expected_path = (
                f"docs/local/audio/baseline-stems-v1/{identifier}--{signal}.wav"
            )
            if stem.get("wavPath") != expected_path:
                errors.append(f"{file_location}.wavPath must be {expected_path}")
                continue
            normalized = PurePosixPath(expected_path)
            wav = root.joinpath(*normalized.parts)
            referenced_wavs.add(expected_path)
            try:
                rate, actual_channels, frames, pcm, samples = parse_wav(wav)
            except (OSError, ValueError) as exc:
                errors.append(f"{file_location}.wavPath {exc}")
                continue
            if (rate, actual_channels, frames) != (
                stem.get("sampleRate"), stem.get("channelCount"), stem.get("frameCount")
            ):
                errors.append(f"{file_location} WAV geometry does not match")
            if hashlib.sha256(pcm).hexdigest() != stem.get("pcmSha256"):
                errors.append(f"{file_location}.pcmSha256 does not match WAV PCM")
            if sha256(wav) != stem.get("wavSha256"):
                errors.append(f"{file_location}.wavSha256 does not match the file")
            decoded[signal] = deinterleave(samples, actual_channels)
        if seen_signals != set(SIGNALS):
            errors.append(
                f"{location}.files must contain exactly {sorted(SIGNALS)}"
            )
        if set(decoded) == set(SIGNALS):
            whole_path = root.joinpath(*PurePosixPath(whole_entry["wavPath"]).parts)
            try:
                _, channels, frames, pcm, whole_samples = parse_wav(whole_path)
            except (OSError, ValueError) as exc:
                errors.append(f"{location} whole-mix WAV {exc}")
            else:
                if channels != 2 or frames != entry.get("frameCount"):
                    errors.append(f"{location} whole-mix geometry is not aligned")
                if hashlib.sha256(pcm).hexdigest() != entry.get(
                    "wholeMixPcmSha256"
                ):
                    errors.append(f"{location} whole-mix PCM hash does not match")
                whole_left, whole_right = deinterleave(whole_samples, channels)
                errors += validate_reconstruction(
                    entry, decoded, whole_left, whole_right, location
                )
    missing = sorted(set(expected) - seen)
    if missing:
        errors.append("manifest omits identities: " + ", ".join(missing))
    if len(entries) != len(expected):
        errors.append(f"entries must contain exactly {len(expected)} identities")
    actual_wavs = {
        path.relative_to(root).as_posix()
        for path in audio_directory(root).glob("*.wav")
    } if audio_directory(root).is_dir() else set()
    extras = sorted(actual_wavs - referenced_wavs)
    if extras:
        errors.append("audio directory has unreferenced WAVs: " + ", ".join(extras))
    return errors


def run_check(root: Path, output: TextIO = sys.stdout) -> int:
    errors = validate(root)
    if errors:
        print(f"role stems rejected with {len(errors)} issue(s):", file=output)
        for index, error in enumerate(errors, 1):
            print(f"  {index}. {error}", file=output)
        return 1
    print(
        "role stems are current: 14 identities x 15 aligned signals",
        file=output,
    )
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check",))
    arguments = parser.parse_args(argv)
    if arguments.command == "check":
        return run_check(repository_root())
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
