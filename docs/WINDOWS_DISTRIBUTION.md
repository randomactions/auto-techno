# Windows Source Validation and Distribution Isolation

## Status

Auto Techno has one native Windows x64 host around the existing canonical Swift
engine. It does not add another director, score, renderer, seed, profile, or
quality policy. The Windows host remains source-buildable and testable, but it is
not a promoted Windows release.

Automated ZIP and installer creation is intentionally isolated. The previous
packaging path copied every Swift/Foundation DLL reported by the toolchain and
every DLL from the newest installed VC143 runtime directory without an exact
per-file licence/notice and Microsoft REDIST proof. A build, hash, or successful
installer did not establish redistribution permission. Current scripts therefore
stop after test/build validation and produce no portable archive or installer.

This preserves the product contract: Windows remains a source-buildable
candidate while unproven third-party runtime files cannot enter a distribution.
The dormant project-owned Inno Setup definition under `packaging/windows/` is not
invoked by any script or workflow and conveys no permission to redistribute
runtime DLLs.

## One-click local source validation

Use a 64-bit Windows 11 machine. The first command installs the official Windows
SDK/C++ tools and exact Swift 6.3.3 toolchain:

```text
scripts\setup-windows-build.cmd
```

Close that terminal, open a fresh terminal so the toolchain path is current,
then run:

```text
scripts\build-windows.cmd
```

The build command performs these gates in order:

1. run the complete Swift test suite on Windows;
2. build the host-selected `AutoTechno.exe` release product under
   `.build-windows`;
3. confirm that the native executable exists;
4. report explicitly that no distribution was produced.

For build-only iteration after an already-passed test run:

```powershell
.\scripts\build-windows.ps1 -SkipTests
```

`-SkipTests` is never a release gate. It is only a local iteration shortcut.
Build products remain ignored and are not portable: they may depend on the
installed Swift and Microsoft runtime environment.

## GitHub source validation

The manual `Windows Source Validation` workflow uses an exact GitHub Action
revision and exact Swift 6.3.3 selector. It runs the same test/build script and
does not upload an executable, ZIP, installer, or runtime DLL.

The workflow becomes usable only after its source revision is published. A local
workflow file or successful macOS check is not native Windows evidence, and a
native Windows build is not distribution, app/route, listening, or soak evidence.

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

## Future distribution re-entry gate

The checked [component licence and asset manifest](COMPONENT_LICENSE_ASSET_MANIFEST.md)
is the compliance owner. ZIP/installer work may return only through a new roadmap
slice that proves all of the following before copying a non-project file:

1. the exact Swift and Microsoft runtime files required by `AutoTechno.exe` are
   selected without directory-wide copying;
2. every file has exact origin, version, SHA-256, licence/notice source, and
   redistribution eligibility in a generated machine-readable record;
3. the installed Microsoft REDIST list is present and every selected VC runtime
   file is permitted by it;
4. every Swift/Foundation or other toolchain runtime file is covered by the
   exact release licence and any applicable notice or third-party terms;
5. packaging tools and CI actions are pinned to reviewed immutable revisions;
6. the staged set fails closed on a missing, extra, duplicate, changed, or
   unlicensed file.

No user choice, environment flag, or permissive warning may bypass this gate.

## Windows release gates

Report these states separately:

1. shared implementation and macOS source compilation;
2. native Windows x64 compilation and complete Swift tests;
3. exact file-level distribution provenance and licence qualification;
4. portable/installer construction and clean-machine launch without a developer
   toolchain;
5. exact-build playback, pause/resume, lookahead, accessibility, and device
   failure/recovery checks at 48 and 44.1 kHz;
6. New Set, Render Info, and scheduled-output live-feedback parity, or a reviewed
   exact canonical fallback contract that does not create a second runtime;
7. at least 60 minutes of Windows physical-output soak including sleep/wake,
   device switching, close during playback, CPU/memory stability, and absence of
   gaps, clicks, or runaway output.

Passing source validation does not imply distribution, runtime, listening, or
hardware-soak qualification.
