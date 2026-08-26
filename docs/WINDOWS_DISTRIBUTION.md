# Windows Distribution

## Status

Auto Techno has one native Windows x64 host around the existing canonical
Swift engine. It does not add another director, score, renderer, seed, profile,
or quality policy. The Windows host is implemented and locally source-checked,
but it is not a promoted Windows release until an exact native build completes
the Windows app/runtime and physical-output gates below.

The current candidate intentionally remains below promotion: it does not yet
claim macOS parity for New Set, Render Info, or the scheduled-output live
feedback coordinator. It uses the same preparation owner with no pending live
correction. Producing an installer must not be reported as closing those runtime
gaps.

## One-click local build

Use a 64-bit Windows 11 machine. The first command is a one-time setup and may
take a while because it installs the official Windows SDK/C++ tools, Swift 6.3.3,
and Inno Setup:

```text
scripts\setup-windows-build.cmd
```

Close that terminal after setup, open a fresh terminal so the toolchain PATH is
current, and double-click or run:

```text
scripts\build-windows.cmd
```

The build command performs these gates in order:

1. run the complete Swift test suite on Windows;
2. build the host-selected `AutoTechno.exe` release product;
3. copy the runtime DLLs reported by the installed Swift toolchain and the
   app-local x64 MSVC redistributable runtime;
4. write `BUILD-MANIFEST.json` and per-file `CHECKSUMS.txt`;
5. create a portable ZIP;
6. create `AutoTechno-Windows-x64-Setup.exe` and its SHA-256 file.

Outputs are written under `dist\windows`. Build output remains local and
untracked.

For a portable ZIP without the installer step:

```powershell
.\scripts\build-windows.ps1
```

For packaging iteration after an already-passed test run:

```powershell
.\scripts\build-windows.ps1 -Installer -SkipTests
```

`-SkipTests` is never a release gate; it is only an iteration shortcut.

## One-click GitHub build

The `Windows Distribution` workflow is manual. In GitHub Actions, select that
workflow, choose the exact branch or tag, and use **Run workflow**. It installs
the pinned Swift toolchain, runs the same build script, and uploads the ZIP,
installer, and installer checksum as one 14-day artifact.

The workflow becomes usable only after its source revision is published. A
local workflow file or successful macOS check is not remote Windows evidence.

## Runtime architecture

```text
AutonomousSessionDirector
  -> shared AutoTechnoTransport detached preparation
  -> canonical AutoTechnoDSP immutable stereo bars
  -> Windows scheduling queue (three prepared bars)
  -> waveOut device queue
```

The Windows completion callback does not render audio. It marks one completed
buffer and advances fixed atomic counters. A serialized transport queue reclaims
completed buffers, prepares successors on a separate queue, and submits only
immutable future bars. If successor preparation is late, the existing
`repeatCurrentWithFrozenTopology` policy keeps coherent prepared audio queued.

The Win32 interface exposes one native, keyboard-focusable Play/Pause button,
status, phrase/bar position, and a read-only waveform. It requires no DAW,
plug-in, cloud service, account, microphone, or external audio file.

## Distribution contents

Windows does not provide the Swift runtime as part of the operating system. The
installed application therefore contains `AutoTechno.exe` plus the official
Swift runtime/Foundation DLLs selected by the build toolchain and Microsoft's
app-local x64 C++ runtime. The Inno Setup file is a single downloadable
installer; it expands those required files into the user's local application
directory.

The current installer is unsigned. Windows SmartScreen may warn until a trusted
code-signing certificate and release-signing workflow are explicitly added.

## Windows release gates

Report these states separately:

1. shared implementation and macOS source compilation;
2. native Windows x64 compilation and complete Swift tests;
3. installer and clean-machine launch without a developer toolchain;
4. exact-build playback, pause/resume, lookahead, accessibility, and device
   failure/recovery checks at 48 and 44.1 kHz;
5. New Set, Render Info, and scheduled-output live-feedback parity, or a reviewed
   exact canonical fallback contract that does not create a second runtime;
6. at least 60 minutes of Windows physical-output soak including sleep/wake,
   device switching, close during playback, CPU/memory stability, and absence of
   gaps, clicks, or runaway output.

Passing a build or producing an installer does not imply runtime or hardware-soak
qualification.
