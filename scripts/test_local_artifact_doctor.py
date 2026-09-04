#!/usr/bin/env python3
"""Unit tests for the local-only artifact layout doctor."""

from __future__ import annotations

import importlib.util
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("local_artifact_doctor.py")
SPEC = importlib.util.spec_from_file_location("local_artifact_doctor", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
doctor = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = doctor
SPEC.loader.exec_module(doctor)


class LocalArtifactDoctorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / ".gitignore").write_text("docs/local/\n", encoding="utf-8")
        local_root = self.root / doctor.LOCAL_ROOT
        local_root.mkdir(parents=True)
        for directory in doctor.REQUIRED_DIRECTORIES:
            (local_root / directory).mkdir()
        (local_root / "README.md").write_text("fixture\n", encoding="utf-8")
        (local_root / "SYNTH_FX_DSP_RESEARCH_STUDY.md").write_text(
            "fixture\n", encoding="utf-8"
        )
        (local_root / "roadmap-plans/AT-0001.md").write_text(
            "fixture\n", encoding="utf-8"
        )
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "add", ".gitignore"], cwd=self.root, check=True)

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        return doctor.run_check(self.root, output), output.getvalue()

    def test_valid_layout_passes_deterministically(self) -> None:
        first = self.check()
        second = self.check()
        self.assertEqual(first, second)
        self.assertEqual(first[0], 0)
        self.assertIn("5 classes, 3 local files", first[1])

    def test_missing_blanket_ignore_is_rejected(self) -> None:
        (self.root / ".gitignore").write_text("", encoding="utf-8")
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("required ignore rule is missing: docs/local/", diagnostic)

    def test_tracked_local_artifact_is_rejected(self) -> None:
        subprocess.run(
            ["git", "add", "-f", "docs/local/roadmap-plans/AT-0001.md"],
            cwd=self.root,
            check=True,
        )
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn(
            "local-only artifacts are tracked: docs/local/roadmap-plans/AT-0001.md",
            diagnostic,
        )

    def test_unexpected_root_entry_is_rejected_in_sorted_order(self) -> None:
        (self.root / doctor.LOCAL_ROOT / "z.tmp").write_text("z\n", encoding="utf-8")
        (self.root / doctor.LOCAL_ROOT / "a.tmp").write_text("a\n", encoding="utf-8")
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("unexpected local artifact root entries: a.tmp, z.tmp", diagnostic)

    def test_missing_required_class_directory_is_rejected(self) -> None:
        (self.root / doctor.LOCAL_ROOT / "audio").rmdir()
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("required local artifact directory is missing: audio/", diagnostic)

    def test_symlink_is_rejected_without_following_it(self) -> None:
        outside = self.root / "outside.txt"
        outside.write_text("outside\n", encoding="utf-8")
        (self.root / doctor.LOCAL_ROOT / "reports/link.txt").symlink_to(outside)
        result, diagnostic = self.check()
        self.assertEqual(result, 1)
        self.assertIn("local artifact symlinks are forbidden: reports/link.txt", diagnostic)


if __name__ == "__main__":
    unittest.main()
