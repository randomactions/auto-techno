# Component Licence and Asset Manifest

> Generated from `docs/COMPONENT_LICENSE_ASSET_MANIFEST.json`; do not edit by hand.

Schema: `autotechno-component-license-asset-manifest.v1`  
Manifest version: 1  
Source access date: 2026-08-31  

## Scope

Covers the repository licence, resolved SwiftPM graph, source-level platform imports and linked libraries, CI actions, active Windows build toolchains, explicit Windows distribution isolation, every tracked resource/licence/media/binary asset, and governed local-only research classes. The dormant project-owned Inno Setup template is not invoked by an active script or workflow and is not a build dependency. Ubiquitous host shell, Git, and operating-system utilities are out of scope unless the repository redistributes them or invokes a separately licensed package. Research citations are evidence, not dependencies or copied assets.

## Components

| Component | Kind | Version / revision | Licence and notice | Role / distribution | Provenance / disposition |
|---|---|---|---|---|---|
| `apple-platform-frameworks` — Apple macOS SDK and system frameworks | `platform-sdk` | `macOS 14 minimum; Xcode selected by build host` / `installation-specific` | Apple Xcode and SDK Agreement; system-framework use only; No Apple framework is copied into the repository or app bundle by project scripts | macOS UI, audio transport, observation, and platform services / `platform-provided` | `GREEN-SYSTEM` / `retain-platform-only` |
| `auto-techno-project` — Auto Techno source, documentation, and generated policy assets | `project` | `current checkout` / `Git revision recorded by each build artifact` | Apache-2.0; No project NOTICE file is currently present | canonical application, tests, documentation, and project-generated qualification resources / `repository-source` | `GREEN-ORIGINAL` / `retain` |
| `github-actions-checkout` — GitHub Actions checkout | `ci-action` | `v4-compatible exact workflow revision` / `11d5960a326750d5838078e36cf38b85af677262` | MIT; Build-only action; not shipped with Auto Techno | CI source checkout / `build-only` | `GREEN-OPEN-SOURCE` / `retain` |
| `microsoft-vc143-runtime` — Microsoft Visual C++ v14 build-host runtime | `platform-sdk` | `host-installed Windows build runtime` / `installation-specific; not redistributed` | Microsoft Visual C++ v14 Redistributable and Runtime terms; The active source-validation path does not copy or redistribute Visual C++ runtime files | Windows build, link, and validation-host runtime prerequisite / `platform-provided` | `GREEN-SYSTEM` / `retain-platform-only` |
| `python-standard-library` — Python 3 standard library | `build-tool` | `Python 3 host interpreter` / `unconstrained; local audit observed 3.14.7` | PSF-2.0; Offline tooling only; interpreter is not shipped | Repository validation, inventory generation, and audit tests / `build-only` | `GREEN-OPEN-SOURCE` / `retain-with-release-gate` |
| `swift-runtime-toolchain` — Swift toolchain, standard library, Foundation, and Dispatch | `toolchain-runtime` | `swift-tools 6.0; Windows CI 6.3.3; macOS runner selected` / `Windows 6.3.3 pinned; local audit observed swiftlang-6.3.3.1.3` | Apache-2.0 with Swift Runtime Library Exception; The active Windows scripts build and test only; no Swift, Foundation, or Dispatch DLL is copied or redistributed | Compiler and cross-platform standard/runtime libraries on build and validation hosts / `build-only` | `GREEN-OPEN-SOURCE` / `retain-with-release-gate` |
| `swift-syntax` — Swift Syntax | `package-transitive` | `600.0.1` / `0687f71944021d616d34d922343dcef086855920` | Apache-2.0 with Swift Runtime Library Exception; No NOTICE.txt exists at tag 600.0.1; test-only package | Transitive macro/compiler support for Swift Testing / `test-only` | `GREEN-OPEN-SOURCE` / `retain-test-only` |
| `swift-testing` — Swift Testing | `package-direct` | `0.12.0` / `c55848b2aa4b29a4df542b235dfdd792a6fbe341` | Apache-2.0 with Swift Runtime Library Exception; NOTICE.txt exists at 0.12.0; package is test-only and is not in the executable product | Test declarations and runner support / `test-only` | `GREEN-OPEN-SOURCE` / `retain-test-only` |
| `windows-system-sdk` — Windows SDK and system libraries | `platform-sdk` | `Windows 11 / host-selected Windows SDK` / `windows-2025 runner or local installed SDK` | Microsoft Windows SDK and operating-system terms; gdi32, user32, and winmm are linked system components and are not copied by packaging | Windows windowing, waveOut audio, C runtime headers, and system linkage / `platform-provided` | `GREEN-SYSTEM` / `retain-platform-only` |

## Tracked governed assets

| Path | Kind | Origin | Distribution / disposition | SHA-256 |
|---|---|---|---|---|
| `LICENSE` | project-licence | Apache Software Foundation licence text selected for this project | `shipped-runtime` / `retain` | `5c9817c129b98e7bb966bca028c43c19107102ef8e03fe799bffb4354f4ef015` |
| `Sources/AutoTechnoDSP/Resources/long-horizon-adversarial-suite-v16.json` | project-generated-qualification-resource | Deterministically generated from repository-owned long-horizon corpus and policy code | `shipped-runtime` / `retain` | `b2842647918232c09be3c637f410f8c15aa498a062503eb0d028a3e9d3ededdd` |
| `Sources/AutoTechnoDSP/Resources/long-horizon-holdout-v16.json` | project-generated-qualification-resource | Deterministically generated from repository-owned long-horizon corpus and policy code | `shipped-runtime` / `retain` | `e99d32c72ae5c750ecd3f7f86f5540e0963445b1f4e37db3189f18508a130f6e` |
| `Sources/AutoTechnoDSP/Resources/long-horizon-professional-profile-v16.json` | project-generated-calibration-resource | Deterministically generated from repository-owned long-horizon corpus and policy code | `shipped-runtime` / `retain` | `6d321f36e269ae667b0962a9a90639e69a3aaaf53dc6854b8c98e7be4cbfbd69` |
| `Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v29.json` | project-generated-qualification-resource | Deterministically generated from repository-owned primary corpus, renderer, and evaluator code | `shipped-runtime` / `retain` | `a8ba14971024e9d5e2d806920ba073bc1d7f0eec46bb9fbf30efde43a23d1329` |
| `Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v29.json` | project-generated-qualification-resource | Deterministically generated from repository-owned primary corpus, renderer, and evaluator code | `shipped-runtime` / `retain` | `c7fa7b1ef1363e588dfc5527a1b39acddde1989a9cb36c56a6bd3a2ba0c87c06` |
| `Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v29.json` | project-generated-calibration-resource | Deterministically generated from repository-owned primary corpus, renderer, and evaluator code | `shipped-runtime` / `retain` | `77e797d34d51d7a63f7e04097404d19d4248da98c9bfe6c3c6e44961caf39110` |

## Local-only artifact classes

| Class | Path pattern | Kinds | Policy / disposition |
|---|---|---|---|
| `build-output-macos` | `.build/**` | compiled objects, dependency checkouts, test products | Never treat cached dependency content as project-owned or publish it from the repository / `local-only-untracked` |
| `build-output-windows` | `.build-windows/**` | compiled objects, dependency checkouts, test products | Never treat cached dependency content as project-owned or publish it from the repository / `local-only-untracked` |
| `distribution-output` | `dist/**` | installer, portable archive, redistributed runtime DLLs | Active scripts do not create or upload distribution products. Any future distribution remains blocked until exact bundled component licences, notices, versions, and REDIST eligibility pass. / `local-only-untracked` |
| `private-local-artifacts` | `docs/local/**` | audio and listening evidence, implementation plans, local profiles, private research, reports, roadmap controller, transcripts and source-derived notes | Keep every class untracked and outside runtime dependencies; do not publish or infer reuse/redistribution permission from local placement / `local-only-untracked` |
| `reference-audio` | `docs/reference/*.wav` | generated renders, licensed or private references, listening fixtures | Never copy, bundle, publish, or make runtime/release validation depend on reference audio / `local-only-untracked` |
| `video-evidence` | `docs/reference/video-evidence/**` | sanitized excerpts, transcripts, video-derived notes | Retain only locally under the research-use protocol; do not redistribute source media or transcripts / `local-only-untracked` |

## Review findings

| Severity | Finding | Component | Disposition / follow-up |
|---|---|---|---|
| `green` | `ci-action-revision-pinned` — Every active GitHub Action binding uses an exact 40-digit revision recorded by this manifest | `github-actions-checkout` | Retain the exact pin and fail manifest validation if a mutable selector is introduced / No AT-0008 follow-up; future action upgrades require an explicit reviewed revision change |
| `green` | `windows-installer-tool-isolated` — Active Windows scripts and workflows neither install nor invoke Inno Setup; the project-owned installer template is dormant | `auto-techno-project` | Keep installer generation outside the executable build path until the documented distribution re-entry gate is satisfied / Future distribution work must review and pin its installer tool before activating the dormant template |
| `green` | `windows-msvc-distribution-isolated` — The active Windows path no longer copies a Visual C++ runtime directory or creates a distributable artifact | `microsoft-vc143-runtime` | Treat the runtime as validation-host infrastructure only / Future distribution work must prove exact per-file REDIST eligibility, versions, licences, and notices |
| `green` | `windows-swift-distribution-isolated` — The active Windows path builds and tests in place without copying Swift, Foundation, or Dispatch DLLs into a distributable artifact | `swift-runtime-toolchain` | Retain Swift as a pinned Windows build toolchain and keep runtime distribution isolated / Future distribution work must enumerate every runtime file and stage exact version-matched licence and notice evidence |

## Source records

### Apple macOS SDK and system frameworks

- Source: https://developer.apple.com/xcode/
- Licence: Xcode installation Resources/en.lproj/License.pdf and https://www.apple.com/legal/sla/docs/xcode.pdf
- Notice: Package.swift and Sources/AutoTechnoApp imports
- Repository anchors: `Package.swift`, `Sources/AutoTechnoApp/AutoTechnoApp.swift`, `Sources/AutoTechnoApp/LivePCMTransport.swift`, `Sources/AutoTechnoApp/TechnoEngine.swift`
- Bindings: `swift-import:AVFoundation`, `swift-import:AppKit`, `swift-import:Combine`, `swift-import:OSLog`, `swift-import:SwiftUI`

### Auto Techno source, documentation, and generated policy assets

- Source: local repository
- Licence: LICENSE
- Notice: repository root licence/notice scan on 2026-08-31
- Repository anchors: `LICENSE`, `README.md`
- Bindings: none

### GitHub Actions checkout

- Source: https://github.com/actions/checkout
- Licence: https://github.com/actions/checkout/blob/11d5960a326750d5838078e36cf38b85af677262/LICENSE
- Notice: https://github.com/actions/checkout/tree/11d5960a326750d5838078e36cf38b85af677262
- Repository anchors: `.github/workflows/swift.yml`, `.github/workflows/windows-distribution.yml`
- Bindings: `ci-action:actions/checkout@11d5960a326750d5838078e36cf38b85af677262`

### Microsoft Visual C++ v14 build-host runtime

- Source: Visual Studio installation VC/Redist/MSVC
- Licence: https://visualstudio.microsoft.com/license-terms/
- Notice: https://learn.microsoft.com/en-us/cpp/windows/determining-which-dlls-to-redistribute
- Repository anchors: `docs/WINDOWS_DISTRIBUTION.md`, `scripts/build-windows.ps1`
- Bindings: `build-host:msvc-runtime`

### Python 3 standard library

- Source: https://www.python.org/
- Licence: https://docs.python.org/3/license.html
- Notice: scripts/*.py shebang and imports
- Repository anchors: `scripts/codebase_map.py`, `scripts/roadmap_contract_baseline.py`
- Bindings: `tooling:python3`

### Swift toolchain, standard library, Foundation, and Dispatch

- Source: https://www.swift.org/install/
- Licence: https://github.com/swiftlang/swift/blob/swift-6.3.3-RELEASE/LICENSE.txt
- Notice: https://github.com/swiftlang/swift/tree/swift-6.3.3-RELEASE
- Repository anchors: `.github/workflows/windows-distribution.yml`, `Package.swift`, `docs/WINDOWS_DISTRIBUTION.md`, `scripts/build-windows.ps1`
- Bindings: `build-host:swift-runtime`, `swift-import:Dispatch`, `swift-import:Foundation`

### Swift Syntax

- Source: https://github.com/swiftlang/swift-syntax.git
- Licence: https://github.com/swiftlang/swift-syntax/blob/600.0.1/LICENSE.txt
- Notice: https://github.com/swiftlang/swift-syntax/tree/600.0.1
- Repository anchors: `Package.resolved`
- Bindings: `package:swift-syntax`

### Swift Testing

- Source: https://github.com/swiftlang/swift-testing.git
- Licence: https://github.com/swiftlang/swift-testing/blob/0.12.0/LICENSE.txt
- Notice: https://github.com/swiftlang/swift-testing/blob/0.12.0/NOTICE.txt
- Repository anchors: `Package.resolved`, `Package.swift`
- Bindings: `package:swift-testing`

### Windows SDK and system libraries

- Source: https://learn.microsoft.com/en-us/windows/apps/windows-sdk/
- Licence: Installed Windows SDK licence terms and https://visualstudio.microsoft.com/license-terms/
- Notice: Package.swift and Sources/AutoTechnoWindowsPlatform/AutoTechnoWindowsPlatform.c
- Repository anchors: `Package.swift`, `Sources/AutoTechnoWindowsPlatform/AutoTechnoWindowsPlatform.c`
- Bindings: `linked-library:gdi32`, `linked-library:user32`, `linked-library:winmm`
