# Modal Percussion Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing root-only `tunedTom` foundation renderer with one score-owned, deterministic six-mode modal resonator whose exact PCM, continuation, routing, and evidence are accepted only by the single calibrated primary evaluator.

**Architecture:** `AutoTechnoCore` resolves bounded modal-percussion articulations after ensemble arbitration without changing the existing tuned-tom event set. `AutoTechnoDSP` renders those articulations through one fixed-capacity continuation owner, reduces same-pass evidence into every candidate bar, and extends the current primary observation/profile rather than introducing another evaluator. The change remains entirely in detached preparation; the app callback continues to play immutable accepted PCM.

**Tech Stack:** Swift 6, Swift Package Manager, Swift Testing, deterministic JSON resources, Git/GitHub Actions, macOS SwiftUI executable.

---

## Fixed Stage 1 contract

The approved design is [2026-08-15-modal-percussion-design.md](../specs/2026-08-15-modal-percussion-design.md). This plan implements only its first stage.

- Canonical owner: `FoundationBehavior.tunedPercussive` and the already-arbitrated `EnsembleVoice.tunedTom` events.
- Reusable capability: one `ModalPercussionArticulation`, one `ModalPercussionResolver`, and one `ModalPercussionVoice` with a four-voice/six-mode continuation bank.
- Automated deficit: the current private `tom()` uses one root-only 220 ms two-sine glide and emits no event-local pitch, material, tail, route, or continuation evidence.
- Bounds: zero to two existing tuned-tom events per bar, fundamentals `48...196 Hz`, excitation/damping/brightness `0...1`, inharmonicity `0...0.12`, six stable modes, T60 `0.18...0.65 s`, applied modes below `0.9 * Nyquist`, and no voice stealing.
- Continuation: modal tails live in `RenderState`, are fingerprinted, copy with each attempt, discard with cancelled/stale attempts, and remain identical during the optional same-plan upper-home correction.
- Routing: mono dry modal PCM goes only to the existing foundation path and protected-rhythm pass; it never enters the percussion stem, upper graph remainder, or a new effect send.
- Consolidation: delete `VoiceRenderer.tom()` after the modal path is green. Do not keep a switch, compatibility renderer, alternate candidate, permissive policy, or older-profile path.

## Version allocation after final rebase

The plan was written on exact `origin/main` `9916c4d00ed51bfcfe4046b04ea04ad4c1902fc3`. Immediately before implementation, rebase onto the then-current safe `origin/main`. If those identities have not moved, Stage 1 owns this one coordinated advance:

| Identity | Current | Stage 1 |
|---|---:|---:|
| `QualityQualificationContract.schemaVersion` | 20 | 21 |
| canonical engine | v19 | v20 |
| candidate vector | 18 | 19 |
| typed plan fingerprint | v10 | v11 |
| typed render-state/render-DSP fingerprint | v3 | v4 |
| candidate continuation payload | v1 | v2 |
| candidate transaction | 2 | 3 |
| qualification report evidence scope | v4 | v5 |
| Professional Evidence bank | 4 | 5 |
| professional observation | 1 | 2 |
| diverse adversarial suite | 2 | 3 |
| primary evaluator/policy family | v1 | v2 |
| bundled profile/adversarial/holdout resource suffix | v1 | v2 |

If refreshed main already advanced one of these identities, allocate the next unused value exactly once and update this table before writing production code. Never preserve the old identity for changed PCM or evidence.

## Task 1: Establish the final safe implementation base

**Files:**

- Verify only: all files in the worktree
- Modify only if main moved: this plan's version-allocation table

- [ ] Fetch and inspect the exact remote safe point.

```bash
git fetch origin --prune
git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
git log --oneline --decorate -5 origin/main
```

Expected: the worktree contains only committed design/plan documentation; no source or resource edit is present.

- [ ] Rebase the documentation commits onto refreshed main.

```bash
git rebase origin/main
git status --short --branch
git diff --check origin/main...HEAD
```

Expected: clean rebase, clean worktree, no whitespace errors.

- [ ] Re-check active Auto Techno tasks before touching shared score, renderer, evaluator, resource, CI, or normative-doc files. Send the exact rebased SHA and intended touched-file list; do not proceed while another task owns those files.

- [ ] Run the focused current-runtime baseline from a fresh isolated build path.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-modal-stage1-baseline-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-modal-stage1-baseline-swiftpm \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-baseline \
  --filter '(CurrentRuntimeTests|AutonomousArchitectureTests|PrimaryEvaluatorReadinessTests)'
```

Expected: all selected baseline tests pass. A baseline failure is diagnosed before Stage 1 changes begin.

### Synchronization cadence

After Tasks 3, 5, 7, and 9, pause at the clean committed boundary and run:

```bash
git fetch origin --prune
git rev-parse HEAD
git rev-parse origin/main
git status --short --branch
```

If `origin/main` moved, exchange exact SHAs/touched-file lists with the other
Auto Techno task, rebase only after file ownership is safe, and rerun the
focused green command for the just-completed task. Any remote change to score,
renderer, evidence, evaluator, identity, or calibration inputs invalidates
previously generated Stage 1 artifacts and requires full regeneration in Task
8. This is the periodic-main synchronization promised for the implementation,
not a blind pull into an uncommitted worktree.

## Task 2: Resolve modal intent in the canonical score

**Files:**

- Create: `Sources/AutoTechnoCore/ModalPercussion.swift`
- Create: `Tests/AutoTechnoCoreTests/ModalPercussionPlanningTests.swift`
- Modify: `Sources/AutoTechnoCore/AutonomousSession.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift`

- [ ] Write failing planning tests first.

Add a serialized `ModalPercussionPlanningTests` suite with tests named
`preservesExistingFoundationEvents`, `deterministicBoundedModalRelations`,
`twoStrikesAreRelational`, `ineligibleBehaviorIsEmpty`, and
`malformedInputIsContained`.

The first test snapshots `ensemble.events` before resolution and proves equality afterward. The second asserts event-index ordering, use `.foundationCompanion`, event intensity equality, membership of every degree in `dna.modalDegrees`, `48...196 Hz`, all semantic bounds, and bit-exact equality on a repeated call. The third builds two tuned-tom events and proves different `modalDegree` values even when the motif supplies only one degree. The fourth checks bass, rumble, empty, and non-`tunedPercussive` inputs produce `[]`. The fifth constructs every non-finite/out-of-range scalar and asserts finite clamped fields.

- [ ] Run the red test.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-core \
  --filter ModalPercussionPlanningTests
```

Expected: compile failure because `ModalPercussionArticulation` and `ModalPercussionResolver` do not exist.

- [ ] Add the Core types with these exact public-package shapes.

```swift
package enum ModalPercussionUse: String, CaseIterable, Codable, Sendable {
    case foundationCompanion = "foundation-companion"
    case sparsePercussion = "sparse-percussion"
}

package struct ModalPercussionArticulation: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let step: Int
    package let use: ModalPercussionUse
    package let modalIdentity: ModalIdentity
    package let modalDegree: Int
    package let octave: Int
    package let fundamentalHz: Double
    package let excitation: Double
    package let damping: Double
    package let brightness: Double
    package let inharmonicity: Double
    package let eventIntensity: Double
    package let seed: UInt64
}

package enum ModalPercussionResolver {
    package static func foundationArticulations(
        ensemble: EnsembleContext,
        dna: SceneDNA,
        performance: PerformanceBar,
        character: PerformanceCharacter,
        gesture: ArrangementGesture,
        behavior: FoundationBehavior
    ) -> [ModalPercussionArticulation]
}
```

Use one finite clamp helper that replaces non-finite input with a field-specific neutral value before clamping. Normalize steps with the repository's existing modulo-16 convention. Derive seed with `SceneDNA.derivedSeed` from `dna.sceneSeed`, a dedicated foundation modal-percussion domain, `performance.bar`, and `scoreEventIndex`.

Resolve degree order from `dna.motif.degrees` after mapping through `dna.nearestModalDegree(to:)`; when the second event would repeat the first, choose the next ordered member of `dna.modalDegrees` using the absolute bar's macro position. Compute the score-owned fundamental from equal-tempered semitone distance relative to C1, then octave-fold it into `48...196 Hz` without changing the modal pitch class.

Derive the four semantic material fields from the same character/gesture/macro/intensity frame, then clamp them in the initializer. Do not perform four unrelated random draws.

- [ ] Extend `ResolvedPerformanceBar` with the articulation list and lookup.

```swift
package let modalPercussionArticulations: [ModalPercussionArticulation]

package func modalPercussion(
    atEventIndex index: Int
) -> ModalPercussionArticulation? {
    modalPercussionArticulations.first { $0.scoreEventIndex == index }
}
```

Add `modalPercussionArticulations: [ModalPercussionArticulation] = []` to its initializer, sort by score event index, and pass the resolver output in `AutonomousSessionDirector.plan(from:)` immediately after ensemble arbitration. Every copy constructor that represents an existing resolved bar must preserve this list.

- [ ] Add architecture assertions that the director emits articulations only for surviving `.tunedTom` events and does not change the event steps, priorities, or maximum count.

- [ ] Run the green tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-core \
  --filter '(ModalPercussionPlanningTests|AutonomousArchitectureTests)'
```

Expected: all selected tests pass.

- [ ] Commit the Core slice.

```bash
git add Sources/AutoTechnoCore/ModalPercussion.swift \
  Sources/AutoTechnoCore/AutonomousSession.swift \
  Tests/AutoTechnoCoreTests/ModalPercussionPlanningTests.swift \
  Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift
git commit -m "Resolve foundation modal percussion intent"
```

## Task 3: Bind the score into preflight and typed fingerprints

**Files:**

- Modify: `Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift`
- Modify: `Sources/AutoTechnoDSP/GeneratedDSPGraph.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift`

- [ ] Write failing fingerprint and preflight tests.

Add tests named:

- `modalPercussionPlanFingerprintCoversEveryScoreField`
- `preflightRejectsMissingDuplicateReorderedAndForgedModalArticulations`
- `canonicalKickReplayPreservesModalArticulations`

For the fingerprint test, clone a valid plan once per articulation field and prove the plan fingerprint changes for event index, step, use, modal identity, degree, octave, fundamental, excitation, damping, brightness, inharmonicity, intensity, and seed. For preflight, mutate a bounded plan without changing its ensemble events and assert `candidateIsBounded` becomes false for each mismatch.

- [ ] Run the red tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-preflight \
  --filter '(modalPercussionPlanFingerprint|preflightRejectsMissingDuplicateReorderedAndForgedModalArticulations|canonicalKickReplayPreservesModalArticulations)'
```

Expected: new assertions fail because modal articulation is absent from typed encoding and preflight replay.

- [ ] Add a typed encoder for `ModalPercussionArticulation`, include the ordered list in `ResolvedPerformanceBar`, and advance the plan domain to `candidate-plan.typed.v11` (or the next unused post-rebase identity).

```swift
static func encode(
    _ value: ModalPercussionArticulation,
    into sink: inout StreamingFNV1a
) {
    sink.aggregate("ModalPercussionArticulation")
    sink.field("scoreEventIndex"); sink.int(value.scoreEventIndex)
    sink.field("step"); sink.int(value.step)
    sink.field("use"); sink.raw(value.use.rawValue)
    sink.field("modalIdentity"); sink.raw(value.modalIdentity.rawValue)
    sink.field("modalDegree"); sink.int(value.modalDegree)
    sink.field("octave"); sink.int(value.octave)
    sink.field("fundamentalHz"); sink.double(value.fundamentalHz)
    sink.field("excitation"); sink.double(value.excitation)
    sink.field("damping"); sink.double(value.damping)
    sink.field("brightness"); sink.double(value.brightness)
    sink.field("inharmonicity"); sink.double(value.inharmonicity)
    sink.field("eventIntensity"); sink.double(value.eventIntensity)
    sink.field("seed"); sink.uint64(value.seed)
}
```

- [ ] In `candidateIsBounded`, recompute the canonical Stage 1 articulation from the exact plan DNA, ensemble, bar, character, gesture, and behavior. Require equality, at most two records, unique ordered event indices, `.foundationCompanion`, matching tuned-tom event index/step/intensity, modal membership, semantic bounds, and finite fundamentals.

- [ ] In `canonicalKickSyntaxBars(for:)`, regenerate modal articulations after the replayed ensemble and pass them into the rebuilt resolved bar. In copy sites that are not replaying musical intent, preserve the source list.

- [ ] Run the green tests and the complete preflight suite.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-preflight \
  --filter '(AutonomousCandidateEvaluationTests|AutonomousPreparationPreflightTests)'
```

Expected: all selected tests pass.

- [ ] Commit the binding slice.

```bash
git add Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift \
  Sources/AutoTechnoDSP/GeneratedDSPGraph.swift \
  Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift \
  Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift
git commit -m "Bind modal percussion score provenance"
```

## Task 4: Implement the shared six-mode resonator and continuation

**Files:**

- Create: `Sources/AutoTechnoDSP/ModalPercussionVoice.swift`
- Create: `Tests/AutoTechnoCoreTests/ModalPercussionDSPTests.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift`

- [ ] Write the DSP tests before implementation.

Add a serialized `ModalPercussionDSPTests` suite with these tests:

- `sixModesAreStableAndBelowTheRouteCeiling`
- `fundamentalPitchMatchesTheResolvedScore`
- `excitationIsDeterministicAndExactlyZeroMean`
- `differentModalIntentChangesPCM`
- `physicalDecayMatchesAt44100And48000`
- `barContinuationMatchesOneContinuousRender`
- `fourVoiceCapacityIsExactAndFifthVoiceDoesNotSteal`
- `aggressiveFiniteArticulationRemainsFinite`
- `routeRebuildIsDeterministic`

Use the same score articulation at 44.1 and 48 kHz. Measure pitch from zero crossings or a bounded autocorrelation window and require less than 15 cents error. Compare T60/attack/body/tail in seconds, not frame counts. Split one render exactly at a bar boundary and require bit-exact concatenated PCM and identical outgoing state to an unsplit render. Fill all four slots with overlapping legal events, then prove the fifth returns `capacityValid == false`, emits no replacement onset, and leaves the four active slot identities unchanged.

- [ ] Run the red test.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-dsp \
  --filter ModalPercussionDSPTests
```

Expected: compile failure because `ModalPercussionVoice` and its continuation types do not exist.

- [ ] Add fixed-shape continuation types; do not use an unbounded voice array.

```swift
package struct ModalPercussionModeState: Equatable, Sendable {
    package var frequencyHz = 0.0
    package var poleRadius = 0.0
    package var coefficient = 0.0
    package var weight = 0.0
    package var y1 = 0.0
    package var y2 = 0.0
}

package struct ModalPercussionVoiceSlotState: Equatable, Sendable {
    package var active = false
    package var articulationSeed: UInt64 = 0
    package var ageFrames = 0
    package var remainingFrames = 0
    package var mode0 = ModalPercussionModeState()
    package var mode1 = ModalPercussionModeState()
    package var mode2 = ModalPercussionModeState()
    package var mode3 = ModalPercussionModeState()
    package var mode4 = ModalPercussionModeState()
    package var mode5 = ModalPercussionModeState()
}

package struct ModalPercussionVoiceState: Equatable, Sendable {
    package var sampleRate = 0.0
    package var slot0 = ModalPercussionVoiceSlotState()
    package var slot1 = ModalPercussionVoiceSlotState()
    package var slot2 = ModalPercussionVoiceSlotState()
    package var slot3 = ModalPercussionVoiceSlotState()
}
```

Add `package var modalPercussionState = ModalPercussionVoiceState()` to `RenderState`, include it in `reset()`, the non-cancellable typed encoder, and the cancellable typed encoder. Advance render-state and render-DSP domains to v4 and the candidate-continuation payload to v2.

- [ ] Implement the detached bar API and evidence types in `ModalPercussionVoice.swift`.

```swift
package struct ScheduledModalPercussionEvent: Equatable, Sendable {
    package let articulation: ModalPercussionArticulation
    package let startFrame: Int
    package let level: Double
}

package struct ModalPercussionRenderEventEvidence: Equatable, Sendable {
    package let articulation: ModalPercussionArticulation
    package let requestedFundamentalHz: Double
    package let appliedFundamentalHz: Double
    package let modeCount: Int
    package let modeRatioFingerprint: String
    package let minimumModeFrequencyHz: Double
    package let maximumModeFrequencyHz: Double
    package let maximumPoleRadius: Double
    package let excitationFingerprint: String
    package let drySampleHash: String
    package let renderedFrameCount: Int
    package let nonzeroSampleCount: Int
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let attackRMS: Double
    package let bodyRMS: Double
    package let tailRMS: Double
    package let tailToBodyDB: Double
    package let spectralCentroidHz: Double
    package let incomingVoiceStateFingerprint: String
    package let outgoingVoiceStateFingerprint: String
    package let finite: Bool
    package let stable: Bool
    package let capacityValid: Bool
    package let routeBindingValid: Bool
}

package struct ModalPercussionBarRenderEvidence: Equatable, Sendable {
    package let bar: Int
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let incomingStateFingerprint: String
    package let outgoingStateFingerprint: String
    package let dryBarSampleHash: String
    package let dryBarPeak: Double
    package let dryBarRMS: Double
    package let activeIncomingVoiceCount: Int
    package let activeOutgoingVoiceCount: Int
    package let continuationRendered: Bool
    package let events: [ModalPercussionRenderEventEvidence]
    package let finite: Bool
}

package enum ModalPercussionVoice {
    package static let modeCount = 6
    package static let voiceCapacity = 4
    package static let maximumExcitationSeconds = 0.002

    package static func renderBar(
        into dryOutput: inout [Float],
        bar: Int,
        sampleRate: Double,
        events: [ScheduledModalPercussionEvent],
        state: inout ModalPercussionVoiceState
    ) -> ModalPercussionBarRenderEvidence
}
```

Use an at-most-2 ms `sin(pi * phase)^2` impulse plus a seeded noise buffer whose arithmetic mean is subtracted before excitation. Use these ordered base ratios: `[1.0, 1.47, 2.09, 2.77, 3.62, 4.63]`; apply bounded inharmonicity as `ratio * (1 + inharmonicity * index * index / 25)`. Clamp every applied mode below `0.9 * Nyquist`. Normalize six brightness-shaped weights by their Euclidean norm.

For each mode, derive `r = pow(0.001, 1 / (T60 * sampleRate))`, require `0 < r < 1`, and use the stable recurrence `y = excitation * weight + 2 * r * cos(omega) * y1 - r * r * y2`. Scale the summed modal output by `sqrt(max(0, 1 - r * r))`, score level, and event intensity. T60 interpolates from `0.18` to `0.65` seconds using score damping. Do not apply `tanh` or another private colour stage.

Use exact IEEE-754/FNV fingerprints already owned by the DSP module. Derive attack/body/tail windows in physical seconds and stream metrics without retaining event PCM after `renderBar` returns.

- [ ] Run DSP green tests plus typed continuation tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-dsp \
  --filter '(ModalPercussionDSPTests|typedFingerprint|rendererContinuationReplay)'
```

Expected: all selected tests pass; no non-finite sample, pole radius of one or more, or capacity substitution is accepted.

- [ ] Commit the shared DSP capability.

```bash
git add Sources/AutoTechnoDSP/ModalPercussionVoice.swift \
  Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift \
  Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift \
  Tests/AutoTechnoCoreTests/ModalPercussionDSPTests.swift
git commit -m "Add bounded modal percussion resonator"
```

## Task 5: Replace `tom()` in the canonical protected foundation route

**Files:**

- Modify: `Sources/AutoTechnoDSP/VoiceRenderer.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift`
- Modify: `Tests/AutoTechnoCoreTests/SpatialProtectedRoutingRegressionTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/ModalPercussionDSPTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift`

- [ ] Write failing integration/routing tests first.

Add tests named:

- `tunedTomUsesOnlyTheResolvedModalArticulation`
- `modalFoundationFullAndProtectedPassesAreBitExact`
- `modalFoundationRoutesToFoundationAndNotPercussionOrUpper`
- `modalFoundationLeavesKickDetectorUnchanged`
- `upperHomeCorrectionLeavesModalScoreAndDryPCMUnchanged`
- `barWithoutOnsetCarriesTruthfulContinuationOrNeutralEvidence`

Construct a Stage 1 bar with the existing tuned-tom ensemble event and its canonical articulation. Prove the full and protected `ModalPercussionBarRenderEvidence` values match exactly, the dedicated modal stem reconstructs only the foundation addition, the percussion hash remains the exact zero/unchanged hash, and the graph-input upper remainder is unchanged by enabling/disabling only the tuned-tom event. Compare kick detector hash/RMS/peak before and after the modal replacement. Render normal and `forceHomeUpperTimbre: true` attempts from the same incoming state and prove identical modal score fields, dry hashes, event metrics, and outgoing modal continuation.

- [ ] Run the red integration tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-routing \
  --filter '(tunedTomUsesOnlyTheResolvedModalArticulation|modalFoundation|upperHomeCorrectionLeavesModal|barWithoutOnsetCarries)'
```

Expected: failures show `VoiceRenderer` still calls the private root-only `tom()` and carries no modal evidence.

- [ ] Add a reusable `modalPercussionStem` buffer to `RenderBuffers`/`RenderWorkspace`. In `VoiceRenderer.renderBar`, collect scheduled events from `resolved.modalPercussionArticulations`; require each record to bind the enumerated `.tunedTom` event and compute start frame from the existing event step. Do not change that step or its timing offset.

- [ ] Replace the `.tunedTom` switch body with schedule collection, call `ModalPercussionVoice.renderBar` once per bar, then add the returned dry buffer sample-for-sample to `output` and `foundationStem`. Never add it to `percussionStem`, `percussionTextureStem`, `synthBus`, a new send, or the generated graph input.

- [ ] Thread `ModalPercussionBarRenderEvidence` through `RenderedBar` and `RenderBlock`, including `modalPercussionRenderPassesMatch`. Sort event evidence by score event index and include an explicit empty event list plus state/dry-bar facts on no-onset bars.

- [ ] Delete `private static func tom(...)` as soon as the new tests pass. Do not retain its two-sine glide elsewhere.

- [ ] Update all explicit `RenderBlock` constructions in tests to preserve the new evidence fields.

- [ ] Run routing and runtime green tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-routing \
  --filter '(ModalPercussionDSPTests|SpatialProtectedRoutingRegressionTests|CurrentRuntimeTests|UpperTimbreIntegrationTests)'
```

Expected: all selected tests pass; modal evidence matches across passes and upper correction while the old renderer is absent.

- [ ] Commit the canonical renderer cutover.

```bash
git add Sources/AutoTechnoDSP/VoiceRenderer.swift \
  Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift \
  Tests/AutoTechnoCoreTests/SpatialProtectedRoutingRegressionTests.swift \
  Tests/AutoTechnoCoreTests/ModalPercussionDSPTests.swift \
  Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift
git commit -m "Replace tuned tom with modal foundation voice"
```

## Task 6: Make modal evidence mandatory in every candidate

**Files:**

- Modify: `Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/PrimaryEvaluatorReadinessTests.swift`

- [ ] Write failing candidate coverage and tamper tests.

Add tests named:

- `modalPercussionEvidenceContract`
- `modalPercussionEvidenceCoversEmptyAndActiveBars`
- `modalPercussionRejectsDetuningUnstablePoleExtraOnsetAndWrongStem`
- `modalPercussionRejectsForgedBindingContinuationRouteAndNonFiniteEvidence`
- `modalPercussionCorrectionMustMatchInitial`

For each tamper, decode a known-valid vector, replace only the attacked field, and assert `.modalPercussionEvidence` appears in `completenessFailures`, `isComplete == false`, or `isFinite == false` as appropriate. Cover missing, duplicate, reordered event index; requested/applied pitch mismatch; mode count other than six; pole radius outside `(0, 1)`; a fifth voice; extra score/render count; use other than foundation; false pass equality; altered incoming/outgoing state fingerprint; unsupported route binding; malformed hash; and NaN metric.

- [ ] Run the red tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-candidate \
  --filter '(modalPercussionEvidence|modalPercussionRejects|modalPercussionCorrection)'
```

Expected: new assertions fail because schema 18 has no modal evidence family.

- [ ] Add `.modalPercussionEvidence = "modal-percussion-evidence"` to `AutonomousCandidateCompletenessFailure` and add these bounded Codable projections:

```swift
package struct AutonomousModalPercussionEventEvidence:
        Codable, Equatable, Sendable {
    package let scoreEventIndex: Int
    package let step: Int
    package let use: String
    package let modalIdentity: String
    package let modalDegree: Int
    package let octave: Int
    package let requestedFundamentalHz: Double
    package let appliedFundamentalHz: Double
    package let excitation: Double
    package let damping: Double
    package let brightness: Double
    package let inharmonicity: Double
    package let intensity: Double
    package let modeCount: Int
    package let modeRatioFingerprint: String
    package let minimumModeFrequencyHz: Double
    package let maximumModeFrequencyHz: Double
    package let maximumPoleRadius: Double
    package let excitationFingerprint: String
    package let drySampleHash: String
    package let renderedFrameCount: Int
    package let nonzeroSampleCount: Int
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let attackRMS: Double
    package let bodyRMS: Double
    package let tailRMS: Double
    package let tailToBodyDB: Double
    package let spectralCentroidHz: Double
    package let incomingVoiceStateFingerprint: String
    package let outgoingVoiceStateFingerprint: String
    package let finite: Bool
    package let stable: Bool
    package let capacityValid: Bool
    package let scoreBindingValid: Bool
    package let routeBindingValid: Bool
}

package struct AutonomousModalPercussionBarEvidence:
        Codable, Equatable, Sendable {
    package let bar: Int
    package let sourceScoreEventCount: Int
    package let sourceRenderEventCount: Int
    package let use: String
    package let incomingStateFingerprint: String
    package let outgoingStateFingerprint: String
    package let dryBarSampleHash: String
    package let activeIncomingVoiceCount: Int
    package let activeOutgoingVoiceCount: Int
    package let continuationRendered: Bool
    package let renderPassesMatch: Bool
    package let foundationRoutingValid: Bool
    package let events: [AutonomousModalPercussionEventEvidence]
}
```

Copy all fields enumerated by the approved evidence contract: score index/step/use, modal identity/degree/octave, requested/applied frequency, semantic material, intensity, six-mode fingerprint/range/pole, excitation/dry hashes, frame/nonzero counts, peak/RMS/crest/attack/body/tail/tail-to-body/centroid, event state fingerprints, finite/stable/capacity/score/route binding, plus bar state/dry/routing/pass facts.

- [ ] Advance `AutonomousCandidateEvaluationVector.schemaVersion` to 19 (or the next post-rebase value), add `sourceModalPercussionBarCount` and `modalPercussion`, construct one bar record for every block, and include the family in source-count, finite, completeness, bar-order, and record-validity checks.

The binding constructor must independently recompute the canonical score articulation and verify:

```text
plan bar == block resolved bar
score tunedTom indices == articulation indices == rendered indices
score step/intensity/use/modal fields == rendered event fields
requested fundamental == score fundamental
applied fundamental is finite and rate-legal
mode count == 6 and all poles are stable
full pass evidence == protected pass evidence
Stage 1 routing is foundation=true, percussion=false
bar state chain equals previous bar outgoing state
first incoming state equals route attempt's incoming modal state
```

- [ ] In `AutonomousCandidateEvaluationTransactionValidator.correctionMatchesInitial`, require exact equality of the complete modal-percussion bar evidence between initial and upper-home correction. Advance transaction schema to 3.

- [ ] Run candidate and readiness green tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-candidate \
  --filter '(AutonomousCandidateEvaluationTests|PrimaryEvaluatorReadinessTests)'
```

Expected: all selected tests pass, including every modal tamper rejection.

- [ ] Commit the candidate evidence slice.

```bash
git add Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift \
  Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift \
  Tests/AutoTechnoCoreTests/PrimaryEvaluatorReadinessTests.swift
git commit -m "Require modal percussion candidate evidence"
```

## Task 7: Extend the single primary observation and adversarial policy

**Files:**

- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityCalibration.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityAdversarialSuite.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalEvidenceReportBank.swift`
- Modify: `Sources/AutoTechnoDSP/UpperTimbreEvidence.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift`

- [ ] Write failing professional-observation tests first.

Add tests proving:

- active modal events project into non-zero attack/body/tail and pitch metrics;
- empty checkpoints produce explicit zero activity without inventing an event;
- a detuned event, runaway tail, excess masking, and representative-rate drift each fail a non-compensable metric or relationship;
- structurally forged score/stem/state facts fail candidate completeness before profile evaluation;
- missing exact artifacts and 8/12 kHz routes remain qualification-unavailable and cannot commit.

- [ ] Run the red tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-policy \
  --filter '(ProfessionalQualityCalibrationTests|QualityQualificationFoundationTests|PrimaryEvaluatorReadinessTests)'
```

Expected: metric-set failures because the professional observation does not yet contain modal dimensions.

- [ ] Add these primary metrics; the existing profile machinery automatically calibrates both checkpoint bounds and 44.1/48 kHz relationship bounds for every participating metric.

```swift
case modalPercussionActiveBarRatio = "modal-percussion-active-bar-ratio"
case modalPercussionEventCountMean = "modal-percussion-event-count-mean"
case modalPercussionPitchErrorCentsMaximum =
    "modal-percussion-pitch-error-cents-maximum"
case modalPercussionAttackToBodyDBMean =
    "modal-percussion-attack-to-body-db-mean"
case modalPercussionTailToBodyDBMean =
    "modal-percussion-tail-to-body-db-mean"
case modalPercussionSpectralCentroidMeanHz =
    "modal-percussion-spectral-centroid-mean-hz"
case modalPercussionMaskingMaximumOverlap =
    "modal-percussion-masking-maximum-overlap"
case modalPercussionMaximumPoleRadius =
    "modal-percussion-maximum-pole-radius"
```

Define semantic domains explicitly: ratios/overlap/pole `0...1`, event count `0...2`, pitch error `0...1200 cents`, attack/tail relationships `-120...120 dB`, centroid `0...maximumSupportedSampleRate/2`. Mark pitch error, masking, and maximum pole as accepting safer values below calibration; do not make activity/count compensable with unrelated loudness or spectral strength.

Project metrics only from complete `vector.modalPercussion`. Use zero for activity/count/centroid/masking on a checkpoint with no event, `0` pitch error only when no event, and compute active-event means otherwise. Compute cents as `abs(1200 * log2(applied/requested))`. Use `20 * log10(max(rms, 1e-12) / max(bodyRMS, 1e-12))` for attack/body and tail/body.

For `modalPercussionMaskingMaximumOverlap`, select only masking bars whose
matching modal record has an active event or incoming modal tail, then select
only observations where `firstRole == foundation`. Take the maximum of the
foundation/percussion and foundation/upper observations in those bars. This
keeps the metric attributed to the Stage 1 foundation consequence instead of
relabeling unrelated percussion/upper overlap as modal masking.

- [ ] Advance observation schema/version to v2, Professional Evidence bank/evidence version to v5, and report scope to `primary-structural-bs1770-signal-role-upper-modal-commit.v5`. Require complete modal bar coverage in the report bank.

- [ ] Advance the primary policy/evaluator family to v2. Keep exactly one `ProfessionalQualityPreparationEvaluator`, one `ProfessionalQualityPrimaryEvaluator`, and one optional same-plan upper-home correction. Do not add a modal-only evaluator or an aggregate score.

- [ ] Extend `ProfessionalQualityAdversarialScenario` and suite version v3 with deterministic metric attacks:

```swift
case modalDetuning = "modal-detuning"
case modalRunawayTail = "modal-runaway-tail"
case modalMaskingFlood = "modal-masking-flood"
case modalRateDrift = "modal-rate-drift"
```

Use `outside(_:preferLower:)` for detuning, tail/body, and masking; build the rate attack by changing the modal centroid or tail/body metric at one supported rate beyond the calibrated rate-consistency bound. Keep candidate-level extra-onset, wrong-stem, forged-binding, broken-continuation, route mismatch, and non-finite attacks in the tamper suite from Task 6 because those must be rejected before a reduced observation can exist.

- [ ] Run the policy green tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-policy \
  --filter '(ProfessionalQualityCalibrationTests|QualityQualificationFoundationTests|PrimaryEvaluatorReadinessTests|AutonomousCandidateEvaluationTests)'
```

Expected: all focused structural and policy tests pass with one primary evaluator.

- [ ] Commit the policy schema before regenerating resources.

```bash
git add Sources/AutoTechnoDSP/ProfessionalQualityCalibration.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityAdversarialSuite.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift \
  Sources/AutoTechnoDSP/ProfessionalEvidenceReportBank.swift \
  Sources/AutoTechnoDSP/UpperTimbreEvidence.swift \
  Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationTests.swift \
  Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift \
  Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift
git commit -m "Extend primary policy for modal percussion"
```

## Task 8: Advance exact engine identities and regenerate qualification artifacts

**Files:**

- Modify: `Sources/AutoTechnoCore/QualityQualification.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift`
- Delete: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v1.json`
- Delete: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v1.json`
- Delete: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v1.json`
- Create: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v2.json`
- Create: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v2.json`
- Create: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v2.json`
- Modify: `Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift`
- Modify: `.github/workflows/swift.yml`

- [ ] Add failing identity/readiness tests for schema 21, engine v20, candidate 19, observation v2, evidence v5, evaluator v2, suite v3, report scope v5, continuation v2, transaction 3, and resource suffix v2. Assert the v1 resource files are absent from the final repository and bundle.

- [ ] Advance `QualityQualificationContract.schemaVersion` to 21 and engine to `autotechno-canonical-engine.v20`. Update comments to state that v20 binds score-owned modal foundation articulation, the six-mode stable resonator, continuation, routing, and primary metrics.

- [ ] Change `ProfessionalQualityPrimaryArtifacts` resource names to v2. Leave fingerprint constants temporarily invalid so the runtime truthfully reports unavailable until regeneration finishes.

- [ ] Run the complete optimized 28-development/4-holdout generator with isolated caches and an explicit output directory.

```bash
AUTOTECHNO_RUN_PROFILE_CALIBRATION=1 \
AUTOTECHNO_CALIBRATION_RESOURCE_DIRECTORY=/private/tmp/auto-techno-modal-stage1-resources \
AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY=/private/tmp/auto-techno-modal-stage1-calibration-cache \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-modal-stage1-calibration-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-modal-stage1-calibration-swiftpm \
xcrun swift test -c release --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-calibration-build \
  --filter generateRepresentativeProfile
```

Expected: 392 accepted calibration observations, all Stage 1 adversarial cases rejected for their expected reason, four source-disjoint holdout journeys accepted at both supported rates, zero relationship failures, and three printed non-empty fingerprints. A failing holdout is not relabeled or bypassed; adjust only bounded engine/evidence defects, rerun focused tests, and regenerate the entire exact bank.

- [ ] Copy the three generated v2 JSON files into `Sources/AutoTechnoDSP/Resources`, update the three expected fingerprints, and remove the three v1 resources. Use `apply_patch` for small source edits; a direct `cp` is permitted only for the generated deterministic JSON artifacts.

```bash
cp /private/tmp/auto-techno-modal-stage1-resources/professional-quality-primary-profile-v2.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v2.json
cp /private/tmp/auto-techno-modal-stage1-resources/professional-quality-primary-adversarial-suite-v2.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v2.json
cp /private/tmp/auto-techno-modal-stage1-resources/professional-quality-primary-holdout-v2.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v2.json
git rm Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v1.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v1.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v1.json
```

- [ ] Prove deterministic regeneration from clean caches by running the generator a second time into `/private/tmp/auto-techno-modal-stage1-resources-repeat` and comparing SHA-256 hashes.

```bash
shasum -a 256 /private/tmp/auto-techno-modal-stage1-resources/*.json
shasum -a 256 /private/tmp/auto-techno-modal-stage1-resources-repeat/*.json
```

Expected: each corresponding pair is identical.

- [ ] Add `ModalPercussionPlanningTests` and `ModalPercussionDSPTests` to the core/evidence CI filter, and add explicit CI steps for modal evidence tampering, representative-rate equivalence, unsupported-route unavailability, and modal correction equality. Keep CI serial and within the existing prepared-product process boundaries.

- [ ] Run readiness and resource tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-artifacts \
  --filter '(CurrentRuntimeTests|ProfessionalQualityCalibrationTests|ProfessionalQualityCalibrationIntegrationTests|PrimaryEvaluatorReadinessTests)'
```

Expected: all selected tests pass and exact v2 artifacts load as available only at 44.1/48 kHz.

- [ ] Commit identities, resources, and CI together.

```bash
git add .github/workflows/swift.yml \
  Sources/AutoTechnoCore/QualityQualification.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift \
  Sources/AutoTechnoDSP/Resources \
  Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift \
  Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift
git commit -m "Qualify modal percussion primary artifacts"
```

## Task 9: Remove stale active terminology and document the one path

**Files:**

- Modify: `README.md`
- Modify: `docs/PRODUCT.md`
- Modify: `docs/SOUND_QUALITY.md`
- Modify: `docs/AUTONOMOUS_RUNTIME_PROVENANCE.md`
- Modify: `docs/AUTONOMOUS_RUNTIME_VALIDATION.md`
- Modify: `docs/PERFORMANCE_GRAMMAR.md`
- Modify: `docs/SOUND_CONCEPT_MATURITY.md`
- Modify: `docs/PRIMARY_EVALUATOR.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/history/VALIDATION_SNAPSHOTS.md`
- Modify: `Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift`

- [ ] Add a failing repository-surface test that scans active Swift source plus README and non-history normative docs. Require the absence of the private `tom(` declaration and these retired active phrases/tokens:

```text
conservative candidate
nonconservative candidate
conservative score
alternate candidate
fallback phrase
development policy
frozen policy
ProfessionalQualityPairedCandidateEvaluator
ProfessionalQualityDevelopmentPolicy
ProfessionalQualityFrozenArtifacts
usedAlternate
usedFallback
```

Exclude `docs/history/**` and the approved design/plan records from the prose scan. Historical validation may retain dated terminology.

- [ ] Run the red surface test and capture every active hit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-docs \
  --filter RepositorySurfaceTests
```

Expected: failure lists the remaining stale active files.

- [ ] Update every normative surface to describe one score, one modal foundation consequence, one primary evaluator, one optional same-plan upper correction, explicit rejection/unavailability, and the accepted-PCM transport hold. Record the new engine/schema/resource fingerprints and separate these evidence states:

```text
implemented
focused local verification
full local verification
qualification artifacts
published exact SHA
exact-head CI
release app launched
app/route QA
listening observation
physical-output soak
```

Do not call listening or app launch a policy qualification gate. Add a dated Stage 1 entry to `docs/history/VALIDATION_SNAPSHOTS.md` only after the corresponding evidence exists.

- [ ] Run the green surface test and an independent grep audit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-docs \
  --filter RepositorySurfaceTests
rg -n -i 'conservative candidate|nonconservative candidate|conservative score|alternate candidate|fallback phrase|development policy|frozen policy|usedAlternate|usedFallback|private static func tom' \
  Sources README.md docs \
  -g '!docs/history/**' \
  -g '!docs/superpowers/specs/**' \
  -g '!docs/superpowers/plans/**'
```

Expected: test passes and `rg` exits 1 with no active hits.

- [ ] Commit documentation and repository cleanup.

```bash
git add README.md docs Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift
git commit -m "Document the modal primary path"
```

## Task 10: Rebase on the latest main and run full local qualification

**Files:**

- Potential conflict resolution only: files already modified by Tasks 2-9

- [ ] Fetch and compare before the expensive serial gate.

```bash
git fetch origin --prune
git rev-parse HEAD
git rev-parse origin/main
git status --short --branch
```

- [ ] If main moved, coordinate ownership, rebase, preserve both validated feature sets, and rerun the generator if any score, renderer, evidence, evaluator, version, or resource input changed.

```bash
git rebase origin/main
git diff --check origin/main...HEAD
```

- [ ] Run the entire test suite serially from a clean isolated build path.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-modal-stage1-full-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-modal-stage1-full-swiftpm \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-modal-stage1-full
```

Expected: every test passes. Report the exact pass count and elapsed time from this run; do not reuse the pre-change 186-test baseline.

- [ ] Run the optimized release build independently.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-modal-stage1-release-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-modal-stage1-release-swiftpm \
xcrun swift build -c release --disable-sandbox \
  --build-path /private/tmp/auto-techno-modal-stage1-release \
  --product AutoTechno
```

Expected: `Build complete!` and an executable at `/private/tmp/auto-techno-modal-stage1-release/arm64-apple-macosx/release/AutoTechno` on Apple Silicon.

- [ ] Run repository and Git hygiene checks.

```bash
git diff --check origin/main...HEAD
git status --short
git log --oneline --decorate origin/main..HEAD
git diff --stat origin/main...HEAD
```

Expected: no uncommitted file, no whitespace error, and only the bounded Stage 1 commits/files.

## Task 11: Publish the exact branch/main head and wait for exact-head CI

**Files:** none unless conflict resolution or CI exposes a real defect.

- [ ] Send the final pre-publication exact SHA and touched-file list to the coordinating Auto Techno task. Confirm machine-quiet ownership before any expensive rerun or publication.

- [ ] Push the feature branch.

```bash
git push --set-upstream origin codex/modal-percussion-v1
```

- [ ] Refresh `origin/main` again. If it moved, rebase and repeat Task 10. Only after exact local verification, publish the verified head to main as authorized by the approved publication sequence.

```bash
git fetch origin --prune
git rev-parse origin/main
git rev-parse HEAD
git push origin HEAD:main
```

Expected: remote `main` advances exactly to the verified Stage 1 SHA without a force push.

- [ ] Prove local, branch, and remote main equality.

```bash
git fetch origin --prune
git rev-parse HEAD
git rev-parse origin/codex/modal-percussion-v1
git rev-parse origin/main
git status --short --branch
```

Expected: all three SHAs match and the worktree is clean.

- [ ] Inspect the GitHub Actions run for that exact SHA and wait for completion. A newer successful run does not prove this SHA.

```bash
MODAL_STAGE1_CI_RUN_ID="$(gh run list --workflow "Swift CI" \
  --commit "$(git rev-parse HEAD)" --limit 1 \
  --json databaseId --jq '.[0].databaseId')"
test -n "$MODAL_STAGE1_CI_RUN_ID"
gh run watch "$MODAL_STAGE1_CI_RUN_ID" --exit-status
gh run view "$MODAL_STAGE1_CI_RUN_ID" \
  --json headSha,status,conclusion,url,jobs
```

Expected: `headSha` equals local/remote main, conclusion `success`, and every modal, core/evidence, preflight, protected-routing, and release-build job step passes.

## Task 12: Launch the exact release app for listening

**Files:** none in the repository.

- [ ] Stop only an older `AutoTechno` instance after identifying its PID and executable path; never kill unrelated Swift build/test processes.

```bash
ps -axo pid=,command= | rg '/AutoTechno($| )'
```

- [ ] Launch the exact release executable built from the published SHA.

```bash
open /private/tmp/auto-techno-modal-stage1-release/arm64-apple-macosx/release/AutoTechno
```

- [ ] Verify the running process and keep it open for the user.

```bash
ps -axo pid=,etime=,command= | rg '/private/tmp/auto-techno-modal-stage1-release/.*/AutoTechno($| )'
```

Expected: one running PID whose executable path is the exact release build from the published SHA.

- [ ] Report the exact SHA, CI URL, running PID/path, touched-file list, test count, artifact fingerprints, and the separate status of app/route QA, listening, and physical-output soak. Do not claim that launch alone proves route QA, listening quality, or hardware soak.

## Final plan self-review

- [ ] Trace every approved Stage 1 requirement to at least one task and one test: existing onset preservation, modal pitch ownership, material bounds, six-mode stable DSP, four-voice continuation, exact protected routing, full/protected equality, complete candidate evidence, same-plan correction invariance, one primary evaluator, new exact artifacts, unsupported-route unavailability, old-renderer removal, active-doc cleanup, serial validation, publication, CI, and app launch.

- [ ] Scan the plan for placeholder language.

```bash
rg -n '[T]BD|[T]ODO|[F]IXME|implement [l]ater|similar [t]o|and [s]o on|etc[.]' \
  docs/superpowers/plans/2026-08-15-modal-percussion-stage-1.md
```

Expected: no hits.

- [ ] Cross-check every named type and current file path.

```bash
rg -n 'ResolvedPerformanceBar|RenderState|RenderBlock|AutonomousCandidateEvaluationVector|ProfessionalQualityObservation|ProfessionalQualityPrimaryArtifacts' \
  Sources/AutoTechnoCore Sources/AutoTechnoDSP
rg -n 'struct AutonomousPreparationPreflightTests' \
  Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift
test -f Tests/AutoTechnoCoreTests/SpatialProtectedRoutingRegressionTests.swift
```

Expected: all current integration owners and test files exist; newly named modal types are created only by the tasks that introduce them.

- [ ] Confirm Stage 2 and Live Feedback are absent from production tasks. Stage 1 may reserve the shared `ModalPercussionUse.sparsePercussion` semantic case, but it does not add a sparse ensemble voice, sparse score admission, sparse rendering/routing, callback feedback, or a user control.
