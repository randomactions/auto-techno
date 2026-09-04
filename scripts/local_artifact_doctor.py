#!/usr/bin/env python3
"""Fail-closed checks for Auto Techno's private local artifact layout."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional, Sequence, TextIO


LOCAL_ROOT = Path("docs/local")
REQUIRED_IGNORE_RULE = "docs/local/"
REQUIRED_DIRECTORIES = (
    "audio",
    "profiles",
    "reports",
    "roadmap-plans",
    "transcripts",
)
ALLOWED_ROOT_FILES = (
    "README.md",
    "SYNTH_FX_DSP_RESEARCH_STUDY.md",
)


class LocalArtifactDoctorError(RuntimeError):
    """An actionable local-artifact repository inspection failure."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _git_output(root: Path, arguments: Sequence[str]) -> bytes:
    result = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        diagnostic = result.stderr.decode("utf-8", errors="replace").strip()
        raise LocalArtifactDoctorError(
            f"git {' '.join(arguments)} failed: {diagnostic or 'unknown error'}"
        )
    return result.stdout


def tracked_local_paths(root: Path) -> list[str]:
    output = _git_output(root, ("ls-files", "-z", "--", LOCAL_ROOT.as_posix()))
    return sorted(
        item.decode("utf-8") for item in output.split(b"\0") if item
    )


def _local_entries(local_root: Path) -> tuple[list[str], list[str]]:
    paths: list[str] = []
    symlinks: list[str] = []
    for directory, directory_names, file_names in os.walk(
        local_root, topdown=True, followlinks=False
    ):
        directory_path = Path(directory)
        for name in sorted((*directory_names, *file_names)):
            path = directory_path / name
            relative = path.relative_to(local_root).as_posix()
            paths.append(relative)
            if path.is_symlink():
                symlinks.append(relative)
    return sorted(paths), sorted(symlinks)


def compare_to_repository(root: Path) -> list[str]:
    errors: list[str] = []
    local_root = root / LOCAL_ROOT
    if not local_root.exists():
        return [f"local artifact root is missing: {LOCAL_ROOT.as_posix()}"]
    if local_root.is_symlink() or not local_root.is_dir():
        return [f"local artifact root must be a real directory: {LOCAL_ROOT.as_posix()}"]

    ignore_path = root / ".gitignore"
    try:
        ignore_lines = {
            line.strip()
            for line in ignore_path.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
    except OSError as exc:
        errors.append(f"cannot read .gitignore: {exc}")
        ignore_lines = set()
    if REQUIRED_IGNORE_RULE not in ignore_lines:
        errors.append(f"required ignore rule is missing: {REQUIRED_IGNORE_RULE}")

    for directory in REQUIRED_DIRECTORIES:
        path = local_root / directory
        if not path.exists():
            errors.append(f"required local artifact directory is missing: {directory}/")
        elif path.is_symlink() or not path.is_dir():
            errors.append(f"local artifact class must be a real directory: {directory}/")

    root_entry_names = sorted(path.name for path in local_root.iterdir())
    allowed_root_names = set(REQUIRED_DIRECTORIES) | set(ALLOWED_ROOT_FILES)
    unexpected = sorted(set(root_entry_names) - allowed_root_names)
    if unexpected:
        errors.append("unexpected local artifact root entries: " + ", ".join(unexpected))

    _, symlinks = _local_entries(local_root)
    if symlinks:
        errors.append("local artifact symlinks are forbidden: " + ", ".join(symlinks))

    try:
        tracked = tracked_local_paths(root)
    except LocalArtifactDoctorError as exc:
        errors.append(str(exc))
    else:
        if tracked:
            errors.append("local-only artifacts are tracked: " + ", ".join(tracked))
    return errors


def run_check(root: Path, output: TextIO) -> int:
    errors = compare_to_repository(root)
    if errors:
        for error in errors:
            print(f"local artifact doctor: {error}", file=output)
        return 1
    paths, _ = _local_entries(root / LOCAL_ROOT)
    file_count = sum(
        1 for relative in paths if (root / LOCAL_ROOT / relative).is_file()
    )
    print(
        "local artifact layout is healthy: "
        f"{len(REQUIRED_DIRECTORIES)} classes, {file_count} local files",
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
