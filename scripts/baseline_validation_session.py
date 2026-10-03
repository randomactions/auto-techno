#!/usr/bin/env python3
"""Opt-in, process-local analysis reuse for an existing offline refresh driver.

Use one ValidationSessionRunner in place of subprocess.run for the lifetime of
one frozen driver. Unsupported invocations keep normal subprocess semantics.
No stage, subordinate validator, report comparison, or cold CLI is omitted.
"""
from __future__ import annotations

import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any, Callable, Sequence

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import phase_one_gate as gate  # noqa: E402
import stereo_compatibility_baseline_report as stereo  # noqa: E402


_ADAPTER_PATHS = (Path(__file__).resolve(), Path(gate.__file__).resolve())
_ADAPTER_BYTES_AT_IMPORT = tuple(path.read_bytes() for path in _ADAPTER_PATHS)


class ValidationSessionRunner:
    """Serial driver adapter; reuse belongs only to this live Python process."""

    def __init__(self, root: Path, runner: Callable[..., Any] = subprocess.run) -> None:
        if tuple(path.read_bytes() for path in _ADAPTER_PATHS) != _ADAPTER_BYTES_AT_IMPORT:
            raise stereo.StereoCompatibilityBaselineReportError(
                "validation adapter differs from loaded source"
            )
        self.root = root.resolve()
        self.runner = runner
        self.analysis = stereo.StereoAnalysisSession()
        self._environment_stack: list[dict[str, str] | None] = []
        self._adapter_files = (Path(__file__).resolve(), Path(gate.__file__).resolve())
        self._adapter_bytes = tuple(path.read_bytes() for path in self._adapter_files)

    def __call__(self, command: Sequence[str], **kwargs: Any) -> subprocess.CompletedProcess:
        # Intercept only the unmodified default script invocations used by the
        # refresh driver. Interpreter flags, alternate roots/options, timeouts,
        # environments and redirection configurations fall back to subprocess.
        kwargs = dict(kwargs)
        if "env" not in kwargs and self._environment_stack:
            kwargs["env"] = self._environment_stack[-1]
        supported = {"cwd", "env", "stdout", "stderr", "text", "check"}
        cwd = Path(kwargs.get("cwd", Path.cwd())).resolve()
        interpreter = shutil.which(str(command[0])) if command else None
        script = (cwd / command[1]).resolve() if len(command) == 3 else None
        env = kwargs.get("env")
        # Environment changes must keep their subprocess meaning. The common
        # Xcode/cache flags do not affect either Python validator; all other
        # changed variables are deliberately outside this adapter's scope.
        ignored = {"DEVELOPER_DIR", "CLANG_MODULE_CACHE_PATH", "SWIFTPM_MODULECACHE_OVERRIDE"}
        environment_matches = env is None or all(
            env.get(key) == os.environ.get(key)
            for key in (set(env) | set(os.environ)) - ignored
        )
        if (set(kwargs) - supported or cwd != self.root or len(command) != 3
                or interpreter is None
                or Path(interpreter).resolve() != Path(sys.executable).resolve()
                or not environment_matches
                or kwargs.get("stderr") != subprocess.STDOUT
                or kwargs.get("stdout") is None
                or (kwargs.get("stdout") != subprocess.PIPE
                    and not isinstance(kwargs.get("stdout"), io.TextIOBase))
                or command[2] not in {"generate", "check"}
                or script not in {
                    self.root / "scripts/stereo_compatibility_baseline_report.py",
                    self.root / "scripts/phase_one_gate.py",
                }):
            return self.runner(command, **kwargs)
        # The adapter must execute the very implementation named by the command.
        # Changed source is an error, not a reuse opportunity.
        module = stereo if script.name == "stereo_compatibility_baseline_report.py" else gate
        if script.read_bytes() != Path(module.__file__).read_bytes():
            return self.runner(command, **kwargs)
        if tuple(path.read_bytes() for path in self._adapter_files) != self._adapter_bytes:
            raise stereo.StereoCompatibilityBaselineReportError(
                "validation adapter changed during frozen session"
            )
        captured = io.StringIO()
        self._environment_stack.append(env)
        try:
            if module is stereo:
                if command[2] == "generate":
                    code = stereo.generate(self.root / stereo.DEFAULT_PAYLOAD,
                                           self.root / stereo.DEFAULT_REPORT,
                                           self.root, captured, self.analysis)
                else:
                    code = stereo.check(self.root / stereo.DEFAULT_REPORT,
                                        self.root, captured, self.analysis)
            elif command[2] == "generate":
                code = gate.run_generate(self.root, captured, self)
            else:
                code = gate.run_check(self.root, captured, self)
        except (OSError, ValueError, gate.PhaseOneGateError,
                stereo.StereoCompatibilityBaselineReportError) as exc:
            print(f"frozen validation session rejected: {exc}", file=captured)
            code = 1
        finally:
            self._environment_stack.pop()
        content = captured.getvalue()
        output = kwargs["stdout"]
        if output == subprocess.PIPE:
            value = content if kwargs.get("text", False) else content.encode("utf-8")
        else:
            # The existing driver opens text log handles. Binary handles and
            # other stream behaviors should use the ordinary subprocess path.
            output.write(content)
            value = None
        result = subprocess.CompletedProcess(command, code, stdout=value)
        if kwargs.get("check", False):
            result.check_returncode()
        return result
