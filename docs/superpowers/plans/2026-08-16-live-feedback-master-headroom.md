# Live Feedback Master Headroom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first bounded live-feedback responsibility: measure app-owned main-mixer PCM, derive one calibrated attenuation-only master-headroom proposal, and commit it only through a future candidate accepted by the single primary evaluator.

**Architecture:** A fixed-capacity C11 SPSC queue is the only callback-facing component. App transport code maps mixer sample time to the canonical player schedule and assembles the first exact three-second window of a resolved phrase on a background worker. AutoTechnoDSP reuses the existing BS.1770-5 and Annex 2 implementation, converts the installed primary profile into a bounded headroom proposal, and applies any committed trim after terminal output safety during detached preparation. AutoTechnoCore owns only the reduced deterministic continuation and proposal contract. The proposal becomes durable only inside the existing atomic prepared-candidate commit; failure retains accepted PCM and never enables an alternate evaluator or renderer.

**Tech Stack:** Swift 6, C11 atomics, AVFoundation, Swift Package Manager, Swift Testing, deterministic JSON resources, Git/GitHub Actions, macOS SwiftUI executable.

---

## Fixed contract

The approved design is [2026-08-16-live-feedback-master-headroom-design.md](../specs/2026-08-16-live-feedback-master-headroom-design.md). This plan implements that design without extending its scope.

- Canonical owner: `TechnoEngine` owns app transport and scheduled ranges; `AutonomousSessionState` owns durable continuation; `AutonomousPhrasePreparer` owns candidate preparation; `AutonomousPhraseRenderer` owns terminal PCM; the installed `ProfessionalQualityProfile` remains the only calibration source; `ProfessionalQualityPreparationEvaluator` remains the only terminal judge.
- Reusable capability: one native-stereo fixed-capacity callback handoff, one exact scheduled-range/window assembler, one live BS.1770 evidence record, one attenuation-only headroom controller, and one future-boundary commit path.
- Automated deficit: the engine currently evaluates detached candidate PCM but cannot prove what app-owned PCM crossed the active main mixer, cannot relate that PCM to a resolved phrase, and cannot use such evidence to make one bounded future correction.
- Bounds: native stereo; 1,024 frames maximum per packet; 256 packets; one exact 3.0-second window; supported qualification rates 44.1 and 48 kHz; trim `-3...0 dB`; attack no faster than `-0.25 dB` per accepted phrase; recovery `+0.125 dB` only after two consecutive clean active windows; one feedback invalidation/regeneration maximum per source phrase.
- Continuation: callback packets and incomplete windows are ephemeral. Only a primary-evaluator-accepted future candidate advances live revision, committed trim, clean-window count, proposal fingerprint, observation fingerprint, and earliest eligible sample.
- Failure policy: missing, stale, incomplete, overrun, route-mismatched, non-finite, uncalibrated, unsupported, or clock-unmapped evidence holds the current committed trim. A rejected corrected candidate repeats accepted PCM; it does not render or schedule an uncorrected substitute.
- Consolidation: there is one primary evaluator, one renderer, one master trim, and one transport coordinator. No paired selection, legacy profile decoder, secondary loudness policy, callback analyzer, user-facing control, or alternate engine is added.

## Version allocation

The documentation commit was based on exact `origin/main` `9d5220b9ed0863a854ec59de267af2ca2d924d89`. After the final safe rebase, allocate the following coordinated cutover. If refreshed main has already claimed an identity, advance to the next unused identity exactly once and update this table before production edits.

| Identity | Current | Live feedback |
|---|---:|---:|
| `QualityQualificationContract.schemaVersion` | 21 | 22 |
| canonical engine | v20 | v21 |
| candidate vector | 19 | 20 |
| candidate transaction | 3 | 4 |
| qualification report evidence scope | v5 | v6 |
| Professional Evidence bank | 5 | 6 |
| professional observation/profile | v2 | v3 |
| primary policy/evaluator family | v2 | v3 |
| adversarial suite schema/family | 3 / v3 | 4 / v4 |
| holdout schema | 1 | 2 |
| live packet/observation/proposal/controller | absent | v1 |
| bundled profile/adversarial/holdout suffix | v2 | v3 |

Do not decode or ship the v2 profile family after v3 qualifies. Do not preserve v20 candidate identities for PCM whose terminal scaling or evidence has changed.

## Task 1: Establish the final safe implementation base

**Files:**

- Verify only: all files in the worktree
- Modify only if identities moved: this plan's version table

- [ ] Fetch the exact remote state and confirm the isolated branch is clean.

```bash
git fetch origin --prune
git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
git log --oneline --decorate -5 origin/main
```

Expected: only the committed design and plan are ahead of `origin/main`; no source, resource, or generated audio edit is present.

- [ ] Rebase the two documentation commits onto the current safe `origin/main` after coordinating file ownership with every active Auto Techno task.

```bash
git rebase origin/main
git status --short --branch
git diff --check origin/main...HEAD
```

Expected: clean rebase, clean worktree, no whitespace errors. Send the exact rebased SHA and intended touched-file set before source edits.

- [ ] Run the current-runtime baseline serially from fresh caches.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-live-v1-baseline-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-live-v1-baseline-swiftpm \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-baseline \
  --filter '(CurrentRuntimeTests|PrimaryEvaluatorReadinessTests|BS1770AudioEvidenceTests|AutonomousPreparationPreflightTests)'
```

Expected: all selected baseline tests pass. Diagnose a baseline failure before changing live-feedback code.

### Synchronization cadence

After Tasks 3, 6, 9, and 11, stop at a clean committed boundary and run:

```bash
git fetch origin --prune
git rev-parse HEAD
git rev-parse origin/main
git status --short --branch
```

If `origin/main` moved, exchange exact SHAs and touched-file lists, then rebase only at a safe ownership boundary. Rerun the focused green command for the completed task. Any remote change to scheduling, render state, candidate evidence, primary profile inputs, version identities, or resource generation invalidates generated v3 artifacts and requires complete regeneration in Task 11.

## Task 2: Add the fixed-capacity realtime handoff

**Files:**

- Create: `Sources/CAutoTechnoRealtime/include/CAutoTechnoRealtime.h`
- Create: `Sources/CAutoTechnoRealtime/CAutoTechnoRealtimePrivate.h`
- Create: `Sources/CAutoTechnoRealtime/CAutoTechnoRealtimeLifecycle.c`
- Create: `Sources/CAutoTechnoRealtime/CAutoTechnoRealtimeProducer.c`
- Create: `Sources/CAutoTechnoRealtime/CAutoTechnoRealtimeConsumer.c`
- Create: `Tests/AutoTechnoCoreTests/LivePCMQueueTests.swift`
- Modify: `Package.swift`

- [ ] Add the C target and test dependency, then write failing queue tests named `nativeStereoRoundTripIsOrdered`, `fullQueueDropsWithoutOverwritingUnreadPCM`, `oversizedPacketIsRejected`, `metadataChangesAreObservedAtPacketBoundary`, and `wraparoundPreservesSequence`.

```swift
.target(name: "CAutoTechnoRealtime"),
.executableTarget(
    name: "AutoTechnoApp",
    dependencies: ["AutoTechnoCore", "AutoTechnoDSP", "CAutoTechnoRealtime"]
)
```

The tests import `CAutoTechnoRealtime`, preallocate output arrays, write distinguishable left/right ramps, and assert packet metadata, drop/reject counters, FIFO order, and no mutation of unread slots.

- [ ] Run the red test.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-queue \
  --filter LivePCMQueueTests
```

Expected: compile failure because the C API is not defined.

- [ ] Define the public callback-safe API with an opaque queue and fixed metadata.

```c
#define AT_LIVE_PCM_MAX_FRAMES 1024u
#define AT_LIVE_PCM_CAPACITY 256u

typedef struct ATLivePCMQueue ATLivePCMQueue;

typedef struct {
    uint64_t packetSequence;
    int64_t firstMixerSample;
    uint32_t frameCount;
    uint32_t routeGeneration;
    uint32_t controllerRevision;
} ATLivePCMPacketMetadata;

ATLivePCMQueue *ATLivePCMQueueCreate(void);
void ATLivePCMQueueDestroy(ATLivePCMQueue *queue);
void ATLivePCMQueueSetGeneration(
    ATLivePCMQueue *queue,
    uint32_t routeGeneration,
    uint32_t controllerRevision
);
bool ATLivePCMQueueProduceNativeStereo(
    ATLivePCMQueue *queue,
    int64_t firstMixerSample,
    const float *left,
    const float *right,
    uint32_t frameCount
);
bool ATLivePCMQueueConsume(
    ATLivePCMQueue *queue,
    ATLivePCMPacketMetadata *metadata,
    float *left,
    float *right,
    uint32_t outputCapacity
);
uint64_t ATLivePCMQueueDroppedPacketCount(const ATLivePCMQueue *queue);
uint64_t ATLivePCMQueueRejectedPacketCount(const ATLivePCMQueue *queue);
```

- [ ] Put storage and lifecycle work outside the producer translation unit. The private struct contains 256 inline stereo slots, atomic read/write sequences, counters, route generation, and controller revision. Require lock-free 64-bit atomics at compile time.

```c
_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2,
               "live PCM sequence atomics must be lock-free");
```

`CAutoTechnoRealtimeLifecycle.c` owns `calloc`, zero initialization, and `free`. `CAutoTechnoRealtimeProducer.c` performs only validation, atomic loads/stores, bounded `memcpy`, metadata writes, and counter increments. Use relaxed loads for the producer-owned write sequence, acquire for the consumer-owned read sequence, and release when publishing a completed slot. The consumer uses the inverse acquire/release pairing. A full queue increments `droppedPacketCount` and returns false without overwriting unread PCM. Null channels, zero frames, and frames above 1,024 increment `rejectedPacketCount` and return false.

- [ ] Run queue tests and inspect the producer object for forbidden callback dependencies.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-queue \
  --filter LivePCMQueueTests
find /private/tmp/auto-techno-live-v1-queue -name 'CAutoTechnoRealtimeProducer.c.o' -print
nm -u "$(find /private/tmp/auto-techno-live-v1-queue -name 'CAutoTechnoRealtimeProducer.c.o' -print -quit)" \
  | rg 'calloc|free|malloc|mutex|dispatch|os_log|printf'
```

Expected: all queue tests pass; the final command has no matches. `memcpy` and compiler atomic intrinsics are allowed only when the target confirms lock-free atomics.

- [ ] Commit the isolated handoff.

```bash
git add Package.swift Sources/CAutoTechnoRealtime \
  Tests/AutoTechnoCoreTests/LivePCMQueueTests.swift
git commit -m "Add bounded realtime PCM handoff"
```

## Task 3: Define the reduced Core proposal and committed continuation

**Files:**

- Create: `Sources/AutoTechnoCore/LiveFeedback.swift`
- Create: `Tests/AutoTechnoCoreTests/LiveFeedbackCoreTests.swift`
- Modify: `Sources/AutoTechnoCore/AutonomousSession.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift`

- [ ] Write failing Core tests named `continuationClampsAttenuationOnly`, `proposalCanonicalizesReasons`, `unavailableProposalCannotMutateTrim`, `acceptedTransitionAdvancesOnce`, `staleProposalIsRejected`, and `sessionAdvanceCommitsLiveStateAtomicallyWithQuality`.

- [ ] Run the red tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-core \
  --filter '(LiveFeedbackCoreTests|AdaptiveAutonomousSessionTests)'
```

Expected: compile failure because the live-feedback Core contract is absent.

- [ ] Add versioned, signal-free Core values with these package shapes.

```swift
package enum LiveFeedbackProposalOutcome: String, Codable, Sendable {
    case unavailable
    case hold
    case attenuate
    case recover
}

package enum LiveFeedbackReason: String, CaseIterable, Codable, Sendable {
    case windowAccepted = "live.window-accepted.v1"
    case windowIncomplete = "live.window-incomplete.v1"
    case queueOverrun = "live.queue-overrun.v1"
    case routeMismatch = "live.route-mismatch.v1"
    case clockUnavailable = "live.clock-unavailable.v1"
    case evidenceNonFinite = "live.evidence-non-finite.v1"
    case profileUnavailable = "live.profile-unavailable.v1"
    case staleProposal = "live.stale-proposal.v1"
}

package struct LiveMasterHeadroomContinuationState: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package let revision: Int
    package let committedTrimDB: Double
    package let consecutiveCleanWindows: Int
    package let lastProposalFingerprint: String?
    package let lastObservationFingerprint: String?
    package let earliestEligibleFutureSample: Int64?
}

package struct LiveMasterHeadroomProposal: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package let sourcePhraseIndex: Int
    package let sourcePlanFingerprint: String
    package let routeGeneration: Int
    package let playerSampleRange: Range<Int64>
    package let observationFingerprint: String?
    package let incomingRevision: Int
    package let incomingStateFingerprint: String
    package let outcome: LiveFeedbackProposalOutcome
    package let reasonCodes: [LiveFeedbackReason]
    package let proposedTrimDB: Double
    package let proposedCleanWindows: Int
    package let earliestEligibleFutureSample: Int64
    package let fingerprint: String
}
```

Initial state is revision 0, trim 0 dB, zero clean windows, and nil provenance. Clamp trim to `-3...0`, clean count to `0...2`, phrase/revision/sample positions to nonnegative values, and sort unique reasons by raw value. A structurally invalid, unavailable, route-mismatched, stale, or non-finite proposal returns the unchanged incoming continuation.

- [ ] Extend `AutonomousSessionState` with `package let liveMasterHeadroom: LiveMasterHeadroomContinuationState`. Update its initializer, deterministic equality/codable behavior, and `advance` signature so quality and live state are supplied from the same accepted prepared product.

```swift
package func advance(
    using plan: AutonomousPhrasePlan,
    quality: QualityContinuationState,
    liveMasterHeadroom: LiveMasterHeadroomContinuationState
) -> AutonomousSessionState
```

Do not add a mutating observation API to session state. Pending observations and proposals do not cross this boundary.

- [ ] Run Core tests green and commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-core \
  --filter '(LiveFeedbackCoreTests|AdaptiveAutonomousSessionTests|CurrentRuntimeTests)'
git add Sources/AutoTechnoCore/LiveFeedback.swift \
  Sources/AutoTechnoCore/AutonomousSession.swift \
  Tests/AutoTechnoCoreTests/LiveFeedbackCoreTests.swift \
  Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift
git commit -m "Define live master continuation contract"
```

Expected: all selected tests pass and identical accepted inputs produce identical next-session state.

## Task 4: Assemble exact scheduled phrase windows off the callback

**Files:**

- Create: `Sources/AutoTechnoApp/LivePCMTransport.swift`
- Create: `Sources/AutoTechnoApp/LiveFeedbackCoordinator.swift`
- Create: `Tests/AutoTechnoAppTests/LiveFeedbackCoordinatorTests.swift`
- Modify: `Package.swift`

- [ ] Add `AutoTechnoAppTests` depending on `AutoTechnoApp`, `AutoTechnoCore`, `AutoTechnoDSP`, `CAutoTechnoRealtime`, and Swift Testing. Write failing tests named `mapsIntegralMixerOffsetIntoPlayerDomain`, `rejectsFractionalOrDriftingClockMap`, `assemblesFirstExactThreeSeconds`, `rejectsGapDuplicateAndGenerationChange`, `retainsPlayingSuccessorAndTwoRecentRanges`, and `doesNotEmitTwiceForOnePhrase`.

- [ ] Run the red App transport tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-app-transport \
  --filter LiveFeedbackCoordinatorTests
```

Expected: compile failure because transport and coordinator types do not exist.

- [ ] Implement pure scheduled-range and clock-map values before AVFoundation glue.

```swift
struct ScheduledPhraseRange: Equatable, Sendable {
    let phraseIndex: Int
    let planFingerprint: String
    let playerSampleRange: Range<Int64>
    let routeGeneration: Int
    let controllerRevision: Int
}

struct MixerPlayerClockMap: Equatable, Sendable {
    let sampleOffset: Int64
    let sampleRate: Double

    func playerSample(forMixerSample sample: Int64) -> Int64 {
        sample + sampleOffset
    }
}
```

Construct a clock map only when mixer and player rates are exactly equal, their sample-time difference is integral, and two off-callback probes return the same offset. The ledger keeps the playing phrase, scheduled successor, and two most recent phrases; older ranges are discarded deterministically.

- [ ] Implement `LivePhraseWindowAssembler` as worker-owned mutable state. It accepts consumed packets already copied out of C, maps packet samples into player domain, intersects them with the first `Int(sampleRate * 3.0)` frames of a ledger range, and copies only contiguous non-overlapping PCM. It emits exactly one immutable native-stereo window per phrase. Any sequence gap, overlap, queue-drop delta, rejected-packet delta, route-generation change, controller-revision mismatch, non-finite sample, or ledger eviction marks that window unavailable and prevents partial analysis.

```swift
struct LivePhrasePCMWindow: Equatable, Sendable {
    let phraseIndex: Int
    let planFingerprint: String
    let routeGeneration: Int
    let controllerRevision: Int
    let playerSampleRange: Range<Int64>
    let sampleRate: Double
    let left: [Float]
    let right: [Float]
}
```

Arrays allocate only on the detached consumer worker. The callback never constructs this value.

- [ ] Run transport tests green and commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-app-transport \
  --filter LiveFeedbackCoordinatorTests
git add Package.swift Sources/AutoTechnoApp/LivePCMTransport.swift \
  Sources/AutoTechnoApp/LiveFeedbackCoordinator.swift \
  Tests/AutoTechnoAppTests/LiveFeedbackCoordinatorTests.swift
git commit -m "Assemble scheduled live phrase windows"
```

Expected: all selected tests pass at both 44.1 and 48 kHz with exact frame counts 132,300 and 144,000.

## Task 5: Reuse BS.1770 and the installed profile for live evidence

**Files:**

- Create: `Sources/AutoTechnoDSP/LiveOutputWindowEvidence.swift`
- Create: `Tests/AutoTechnoCoreTests/LiveOutputWindowEvidenceTests.swift`
- Modify only if a shared bounded entry point is missing: `Sources/AutoTechnoDSP/BS1770AudioEvidence.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift`

- [ ] Write failing DSP tests named `threeSecondWindowMatchesExistingBS1770`, `annexTwoTruePeakMatchesChunkedAnalyzer`, `observationBindsRouteRangeAndPCM`, `nonFiniteOrWrongLengthIsUnavailable`, `strictestCheckpointUpperBoundWins`, and `ordinaryLockUsesLongContinuation`.

- [ ] Run the red evidence tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-evidence \
  --filter '(LiveOutputWindowEvidenceTests|BS1770AudioEvidenceTests)'
```

Expected: compile failure because live observation and target types are absent.

- [ ] Add the immutable evidence and calibrated target values.

```swift
package struct LiveOutputWindowEvidence: Equatable, Sendable {
    package static let schemaVersion = 1
    package let phraseIndex: Int
    package let planFingerprint: String
    package let routeGeneration: Int
    package let controllerRevision: Int
    package let playerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let frameCount: Int
    package let pcmFingerprint: String
    package let maximumShortTermLoudnessLUFS: Double
    package let truePeakDBTP: Double
    package let complete: Bool
    package let fingerprint: String
}

package struct LiveMasterHeadroomTarget: Equatable, Sendable {
    package let loudnessLowerLUFS: Double
    package let loudnessUpperLUFS: Double
    package let loudnessMidpointLUFS: Double
    package let truePeakLowerDBTP: Double
    package let truePeakUpperDBTP: Double
    package let truePeakMidpointDBTP: Double
    package let profileFingerprint: String
}
```

The analyzer accepts only exact 3.0-second native-stereo windows at 44.1 or 48 kHz. Call the existing `BS1770LoudnessMeasurement` and `BS1770AudioEvidence.stereoTruePeak`; do not copy coefficients, gates, oversampling filters, or true-peak logic. Bind the PCM fingerprint, route generation, phrase/plan identity, controller revision, exact sample range, sample rate, and both measured values into the typed fingerprint.

- [ ] Resolve profile bounds by `CanonicalJourneyCheckpoint.applicable`. For no explicit checkpoint, use `.longContinuation`. For multiple checkpoints, choose the smallest upper bound independently for `.maximumShortTermLoudnessLUFS` and `.truePeakDBTP`, then keep that same selected bound's lower value and midpoint. Return unavailable when the installed profile fingerprint/version/engine/rate does not match exactly.

- [ ] Run evidence tests green and commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-evidence \
  --filter '(LiveOutputWindowEvidenceTests|BS1770AudioEvidenceTests|StreamingPerceptualEvidenceTests)'
git add Sources/AutoTechnoDSP/LiveOutputWindowEvidence.swift \
  Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift \
  Tests/AutoTechnoCoreTests/LiveOutputWindowEvidenceTests.swift
git add -u Sources/AutoTechnoDSP/BS1770AudioEvidence.swift
git commit -m "Measure calibrated live output windows"
```

Expected: exact equality with the existing fixed/chunked BS.1770 evidence within existing test tolerances; no second loudness implementation appears in the repository.

## Task 6: Implement the bounded attenuation-only controller

**Files:**

- Create: `Sources/AutoTechnoDSP/LiveMasterHeadroomController.swift`
- Create: `Tests/AutoTechnoCoreTests/LiveMasterHeadroomControllerTests.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift`

- [ ] Write failing tests named `takesMaximumOfLoudnessAndTruePeakExcess`, `attackIsAtMostQuarterDB`, `neverBoostsAboveUnity`, `saturatesAtMinusThreeDB`, `deadbandHolds`, `twoCleanWindowsRecoverOneEighthDB`, `oneCleanWindowDoesNotRecover`, `unavailableEvidenceHolds`, `routeAndRevisionMismatchHold`, and `deterministicReplayIsBitExact`.

- [ ] Run the red controller tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-controller \
  --filter LiveMasterHeadroomControllerTests
```

Expected: compile failure because `LiveMasterHeadroomController` is absent.

- [ ] Add the controller with exact constants and one pure transition function.

```swift
package enum LiveMasterHeadroomController {
    package static let version = "autotechno-live-master-headroom.v1"
    package static let minimumTrimDB = -3.0
    package static let maximumTrimDB = 0.0
    package static let attackStepDB = 0.25
    package static let recoveryStepDB = 0.125
    package static let cleanWindowsForRecovery = 2

    package static func propose(
        evidence: LiveOutputWindowEvidence?,
        target: LiveMasterHeadroomTarget?,
        incoming: LiveMasterHeadroomContinuationState,
        earliestEligibleFutureSample: Int64
    ) -> LiveMasterHeadroomProposal
}
```

Compute:

```swift
let excessDB = max(
    evidence.maximumShortTermLoudnessLUFS - target.loudnessUpperLUFS,
    evidence.truePeakDBTP - target.truePeakUpperDBTP,
    0
)
```

When `excessDB > 0`, subtract `min(0.25, excessDB)` and reset clean windows. When both metrics are below their selected midpoints, increment the bounded clean count; on the second consecutive clean window, add 0.125 dB toward zero and reset the count. Hold in the band between midpoint and upper bound. Hold at `-3 dB` saturation. Missing or invalid evidence/target emits `.unavailable` with unchanged trim and clean count. Fingerprint all source identities, exact target bounds, input state, outcome, reasons, and output values.

- [ ] Run controller and replay tests green, then commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-controller \
  --filter '(LiveMasterHeadroomControllerTests|LiveFeedbackCoreTests)'
git add Sources/AutoTechnoDSP/LiveMasterHeadroomController.swift \
  Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift \
  Tests/AutoTechnoCoreTests/LiveMasterHeadroomControllerTests.swift
git commit -m "Resolve bounded live headroom proposals"
```

Expected: all selected tests pass and replaying the same evidence/target/incoming state produces identical encoded proposal bytes and fingerprint.

## Task 7: Apply committed trim only at the terminal renderer boundary

**Files:**

- Modify: `Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift`
- Create: `Tests/AutoTechnoCoreTests/LiveMasterTrimRenderingTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/SpatialProtectedRoutingRegressionTests.swift`

- [ ] Write failing renderer tests named `zeroTrimPreservesExactPCM`, `minusTrimScalesTerminalStereoOnly`, `trimDoesNotChangeRoleStemEvidence`, `trimDoesNotChangeInternalDynamics`, `trimPersistsAcrossBars`, `trimIsFingerprintBound`, and `protectedRoutingRemainsPreTrimEquivalent`.

- [ ] Run the red renderer tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-render \
  --filter '(LiveMasterTrimRenderingTests|SpatialProtectedRoutingRegressionTests)'
```

Expected: compile failure because `RenderState` has no live master continuation or terminal scaling evidence.

- [ ] Add `package var liveMasterHeadroomState = LiveMasterHeadroomContinuationState()` to `RenderState`. Encode it in both normal and cancellation-aware typed render-state fingerprint paths.

- [ ] Apply the gain exactly once after the existing `outputSafety` result and after full/protected recombination.

```swift
let preLiveFeedbackLeft = outputSafety(recombinedLeft)
let preLiveFeedbackRight = outputSafety(recombinedRight)
let liveMasterGain = pow(10, state.liveMasterHeadroomState.committedTrimDB / 20)
let outputLeft = Float(Double(preLiveFeedbackLeft) * liveMasterGain)
let outputRight = Float(Double(preLiveFeedbackRight) * liveMasterGain)
```

Do not change kick/foundation faders, role stems, ducking detector, spatial sends, glue state, master envelope, or output-safety coefficients. At zero trim, preserve bit-exact existing PCM. At negative trim, prove every finite terminal sample equals the exact Float result of one multiplication by the recorded gain.

- [ ] Add renderer evidence containing requested trim, applied trim/gain, pre/post stereo fingerprints, pre/post nonzero counts, and exact scaling match. Bind it into render block and candidate evidence; do not expose a UI parameter.

- [ ] Run renderer regressions green and commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-render \
  --filter '(LiveMasterTrimRenderingTests|SpatialProtectedRoutingRegressionTests|rendererContinuationReplay|typedFingerprint)'
git add Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift \
  Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift \
  Tests/AutoTechnoCoreTests/LiveMasterTrimRenderingTests.swift \
  Tests/AutoTechnoCoreTests/SpatialProtectedRoutingRegressionTests.swift
git commit -m "Apply live trim at terminal output"
```

Expected: all selected tests pass; role/stem evidence is unchanged while only emitted stereo PCM is attenuated.

## Task 8: Bind proposals into candidate evidence and atomic commit

**Files:**

- Modify: `Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift`
- Modify: `Sources/AutoTechnoDSP/GeneratedDSPGraph.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift`
- Modify: `Sources/AutoTechnoCore/QualityQualification.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift`

- [ ] Write failing candidate tests named `pendingProposalDoesNotMutateIncomingState`, `acceptedCandidateCommitsProposalAtomically`, `rejectedCandidateLeavesLiveContinuationUnchanged`, `proposalMustMatchRoutePlanRevisionAndBoundary`, `candidateBindsPreAndPostTrimPCM`, `combinedControllerFingerprintBindsKickAndMaster`, and `onePrimaryCorrectionCannotRewriteLiveProposal`.

- [ ] Run the red candidate tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-candidate \
  --filter '(AutonomousCandidateEvaluationTests|AutonomousPreparationPreflightTests|QualityQualificationFoundationTests)'
```

Expected: failures showing the proposal, controller state, and terminal scaling are not yet bound into the candidate transaction.

- [ ] Extend candidate/preparation input with `pendingLiveMasterProposal: LiveMasterHeadroomProposal?`. Validate source phrase/plan fingerprint, route generation, incoming live revision/fingerprint, future unscheduled boundary, and controller version before copying the proposed continuation into a render attempt. Invalid/unavailable proposals render with the committed incoming trim and record a truthful hold reason.

- [ ] Extend every candidate vector with live fields:

```swift
package let incomingLiveMasterRevision: Int
package let outgoingLiveMasterRevision: Int
package let incomingLiveMasterStateFingerprint: String
package let outgoingLiveMasterStateFingerprint: String
package let liveObservationFingerprint: String?
package let liveProposalFingerprint: String?
package let liveProposalOutcome: LiveFeedbackProposalOutcome
package let requestedLiveMasterTrimDB: Double
package let appliedLiveMasterTrimDB: Double
package let liveMasterGain: Double
package let preLiveMasterPCMFingerprint: String
package let postLiveMasterPCMFingerprint: String
package let liveMasterScalingMatches: Bool
package let liveEarliestEligibleFutureSample: Int64?
```

Require exact pre/post hash consistency, finite bounds, one-step revision advance only for an available proposal, and exact scaling proof. Create one combined controller fingerprint from the existing kick controller evidence plus live master state/proposal; never choose between controllers.

- [ ] Extend `PreparedAutonomousPhrase` and `AutonomousCandidateEvaluationTransaction` so the selected outgoing live state is carried beside the selected quality state. The final commit calls `AutonomousSessionState.advance(using:quality:liveMasterHeadroom:)` only after the primary evaluator accepts the same candidate fingerprint/evidence fingerprint/controller fingerprint. A rejected or unavailable candidate produces no session advance.

- [ ] Preserve the existing single correction render. Both initial and same-plan correction attempts receive the same validated live proposal. Reject evidence if the correction changes proposal identity, requested trim, or source observation.

- [ ] Run candidate tests green and commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-candidate \
  --filter '(AutonomousCandidateEvaluationTests|AutonomousPreparationPreflightTests|QualityQualificationFoundationTests|calibratedPrimaryCommit|onePrimaryCorrection)'
git add Sources/AutoTechnoCore/QualityQualification.swift \
  Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift \
  Sources/AutoTechnoDSP/GeneratedDSPGraph.swift \
  Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift \
  Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift \
  Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift \
  Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift
git commit -m "Commit live feedback through primary evaluation"
```

Expected: all selected tests pass; there is no independent live-feedback acceptance path.

## Task 9: Connect the tap, worker, and future scheduling boundary

**Files:**

- Modify: `Sources/AutoTechnoApp/LivePCMTransport.swift`
- Modify: `Sources/AutoTechnoApp/LiveFeedbackCoordinator.swift`
- Modify: `Sources/AutoTechnoApp/TechnoEngine.swift`
- Modify: `Tests/AutoTechnoAppTests/LiveFeedbackCoordinatorTests.swift`
- Create: `Tests/AutoTechnoAppTests/TechnoEngineLiveFeedbackTests.swift`

- [ ] Write failing integration tests named `tapPublishesOnlyNativeStereoPackets`, `windowProposalInvalidatesOnlyUnscheduledSuccessor`, `oneSourcePhraseInvalidatesAtMostOnce`, `alreadyScheduledSuccessorDefersProposal`, `rejectedCorrectedCandidateRetainsAcceptedPCM`, `pauseDiscardsPartialWindow`, `routeChangeDiscardsPendingAndKeepsCommittedTrim`, and `shutdownRemovesTapBeforeQueueDestruction`.

- [ ] Run the red App integration tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-app \
  --filter '(LiveFeedbackCoordinatorTests|TechnoEngineLiveFeedbackTests)'
```

Expected: compile/test failures because `TechnoEngine` does not install or consume the realtime handoff.

- [ ] Add a `LivePCMTransport` owner that creates/destroys the C queue off callback, requests a 1,024-frame main-mixer tap, and exposes one callback closure whose body is limited to guards, `AVAudioTime.sampleTime`, channel pointers, frame count, and `ATLivePCMQueueProduceNativeStereo`. Set route generation/controller revision through C atomics from the main actor before packets for a new generation can be accepted.

```swift
mainMixer.installTap(
    onBus: 0,
    bufferSize: AVAudioFrameCount(AT_LIVE_PCM_MAX_FRAMES),
    format: nativeStereoFormat
) { [queue] buffer, time in
    guard let channels = buffer.floatChannelData,
          buffer.format.channelCount == 2,
          time.isSampleTimeValid else { return }
    _ = ATLivePCMQueueProduceNativeStereo(
        queue, time.sampleTime, channels[0], channels[1], buffer.frameLength
    )
}
```

Do not capture `TechnoEngine`, a Swift actor, a logger, a task, or mutable Swift collection in this closure.

- [ ] Add one detached serial consumer worker that drains into preallocated 1,024-frame arrays, updates the worker-owned assembler, runs DSP analysis/proposal only after a complete window, and sends only the reduced proposal back to `@MainActor`. Do not run analyzer work on the callback or main actor.

- [ ] Extend `PhrasePreparationKey` with incoming live revision/state fingerprint, pending proposal fingerprint, and eligible future sample. Extend `PhrasePreparationRequest` with the immutable pending proposal. A changed accepted proposal cancels and removes only a cached successor whose first sample is still unscheduled, then prepares once from the same source state with that proposal. Track `feedbackInvalidatedSourcePhrases: Set<Int>` on the main actor and refuse a second invalidation for the same source phrase.

- [ ] Register every scheduled phrase range in player sample time. Establish the mixer/player map off callback with `player.playerTime(forNodeTime:)` only after both clocks are valid. Probe it twice; absent, fractional, rate-mismatched, or drifting offsets make evidence unavailable. Never infer equality between mixer and player timelines.

- [ ] Route lifecycle:

  - Pause: stop accepting packets, cancel/drain worker generation, discard partial window, retain committed trim.
  - Resume: establish a fresh exact clock map and fresh window eligibility.
  - Route change: while stopped, remove tap, cancel worker, discard queue/pending proposal/partial window, increment generation, rebuild queue/tap/map, retain only committed live continuation.
  - Shutdown: remove tap, stop producer eligibility, join/cancel consumer, then destroy queue.

- [ ] Make transport continuity explicit. If a corrected successor is unavailable or rejected at its scheduling boundary, repeat the currently accepted immutable buffer/topology through the existing hold path. Do not prepare an untrimmed fallback candidate.

- [ ] Run App integration tests and callback symbol checks green, then commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-app \
  --filter '(LiveFeedbackCoordinatorTests|TechnoEngineLiveFeedbackTests|CurrentRuntimeTests)'
nm -u "$(find /private/tmp/auto-techno-live-v1-app -name 'CAutoTechnoRealtimeProducer.c.o' -print -quit)" \
  | rg 'calloc|free|malloc|mutex|dispatch|os_log|printf'
git add Sources/AutoTechnoApp/LivePCMTransport.swift \
  Sources/AutoTechnoApp/LiveFeedbackCoordinator.swift \
  Sources/AutoTechnoApp/TechnoEngine.swift \
  Tests/AutoTechnoAppTests
git commit -m "Connect live evidence to future preparation"
```

Expected: tests pass; forbidden-symbol scan has no matches; every correction applies only to future unscheduled PCM.

## Task 10: Extend the single primary evidence and adversarial contract

**Files:**

- Modify: `Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalEvidenceReportBank.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityCalibration.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityAdversarialSuite.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityHoldoutQualification.swift`
- Modify: `Sources/AutoTechnoDSP/UpperTimbreEvidence.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/PrimaryEvaluatorReadinessTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift`

- [ ] Write failing policy tests proving that every report/observation binds live controller schema/version, incoming/outgoing state, proposal, exact terminal scaling evidence, and supported route generation. Add adversarial scenarios for forged pre/post scaling, boost above unity, over-attack, early recovery, stale route generation, stale controller revision, and unbound proposal fingerprint.

- [ ] Run the red policy tests.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-policy \
  --filter '(ProfessionalQualityCalibrationTests|PrimaryEvaluatorReadinessTests|QualityQualificationFoundationTests|AutonomousCandidateEvaluationTests)'
```

Expected: policy tests fail because current v2 artifacts and v5 evidence do not cover live-feedback provenance.

- [ ] Advance the evidence models, without adding a second score. `ProfessionalQualityObservation` includes live proposal outcome, trim delta, terminal scaling validity, revision delta, and route/boundary validity as hard gates/provenance fields. Existing short-term loudness and true peak remain the calibrated metrics; do not create duplicate metric names for live PCM.

- [ ] Make the primary evaluator reject any candidate that boosts, exceeds one-step attack/recovery, commits without a matching observation/proposal, changes proposal between correction passes, violates terminal scaling, or applies before `earliestEligibleFutureSample`. Missing live evidence is a truthful hold and does not make a route unavailable by itself; missing exact primary artifacts still makes qualification unavailable.

- [ ] Remove all legacy schema/profile decoding branches while advancing:

  - Professional Evidence v5 to v6;
  - observation/profile v2 to v3;
  - primary policy/evaluator v2 to v3;
  - adversarial schema/family 3/v3 to 4/v4;
  - holdout schema 1 to 2;
  - candidate vector 19 to 20;
  - candidate transaction 3 to 4.

Any initializer used only to decode v1/v2 artifacts is deleted. Current structs accept only the new exact schema. Tests assert old JSON is rejected rather than migrated.

- [ ] Run policy tests green and commit the schema before resource generation.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-policy \
  --filter '(ProfessionalQualityCalibrationTests|PrimaryEvaluatorReadinessTests|QualityQualificationFoundationTests|AutonomousCandidateEvaluationTests)'
git add Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift \
  Sources/AutoTechnoDSP/ProfessionalEvidenceReportBank.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityCalibration.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityAdversarialSuite.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityHoldoutQualification.swift \
  Sources/AutoTechnoDSP/UpperTimbreEvidence.swift \
  Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationTests.swift \
  Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift \
  Tests/AutoTechnoCoreTests/PrimaryEvaluatorReadinessTests.swift \
  Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift
git commit -m "Extend primary evidence for live headroom"
```

Expected: focused tests pass using constructed in-memory v3 fixtures; bundled policy remains unavailable until Task 11 creates exact artifacts.

## Task 11: Advance engine identity and regenerate exact primary artifacts

**Files:**

- Modify: `Sources/AutoTechnoCore/QualityQualification.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift`
- Delete: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v2.json`
- Delete: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v2.json`
- Delete: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v2.json`
- Create: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v3.json`
- Create: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v3.json`
- Create: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v3.json`
- Modify: `Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift`
- Modify: `.github/workflows/swift.yml`

- [ ] Add failing identity/readiness tests for quality schema 22, engine v21, candidate 20, transaction 4, report/evidence v6, observation/profile v3, evaluator/policy v3, adversarial 4/v4, holdout 2, and resource suffix v3. Assert all v2 resources and legacy decoder symbols are absent.

- [ ] Advance `QualityQualificationContract` to schema 22 and `autotechno-canonical-engine.v21`. State that v21 binds app-owned scheduled live PCM, exact clock mapping, live BS.1770 evidence, bounded terminal attenuation, and atomic future-boundary commit.

- [ ] Point `ProfessionalQualityPrimaryArtifacts` only to the v3 filenames and leave its expected fingerprints invalid until the regenerated files exist. Confirm runtime readiness reports unavailable during this interval.

- [ ] Generate the same complete 28-development-journey corpus and four disjoint holdout journeys at 44.1 and 48 kHz in release mode.

```bash
AUTOTECHNO_RUN_PROFILE_CALIBRATION=1 \
AUTOTECHNO_CALIBRATION_RESOURCE_DIRECTORY=/private/tmp/auto-techno-live-v1-resources \
AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY=/private/tmp/auto-techno-live-v1-calibration-cache \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-live-v1-calibration-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-live-v1-calibration-swiftpm \
xcrun swift test -c release --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-calibration-build \
  --filter generateRepresentativeProfile
```

Expected: 392 accepted development observations, all live and existing adversarial cases rejected for their declared reason, four source-disjoint holdout journeys accepted at both supported rates, zero relationship failures, and three non-empty fingerprints. Do not weaken bounds, remove failed journeys, or relabel attacks to force qualification; correct only a demonstrated engine/evidence defect and regenerate the whole bank.

- [ ] Copy only the deterministic v3 JSON outputs, update the three expected fingerprint constants, and delete v2 resources.

```bash
cp /private/tmp/auto-techno-live-v1-resources/professional-quality-primary-profile-v3.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v3.json
cp /private/tmp/auto-techno-live-v1-resources/professional-quality-primary-adversarial-suite-v3.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v3.json
cp /private/tmp/auto-techno-live-v1-resources/professional-quality-primary-holdout-v3.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v3.json
git rm Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v2.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v2.json \
  Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v2.json
```

- [ ] Repeat generation from different clean caches and compare hashes.

```bash
AUTOTECHNO_RUN_PROFILE_CALIBRATION=1 \
AUTOTECHNO_CALIBRATION_RESOURCE_DIRECTORY=/private/tmp/auto-techno-live-v1-resources-repeat \
AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY=/private/tmp/auto-techno-live-v1-calibration-cache-repeat \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-live-v1-calibration-clang-repeat \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-live-v1-calibration-swiftpm-repeat \
xcrun swift test -c release --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-calibration-build-repeat \
  --filter generateRepresentativeProfile
shasum -a 256 /private/tmp/auto-techno-live-v1-resources/*.json
shasum -a 256 /private/tmp/auto-techno-live-v1-resources-repeat/*.json
```

Expected: corresponding JSON hashes are identical.

- [ ] Extend CI with separate serial steps for queue/callback safety, live analyzer/controller, App coordination, live candidate tampering, unsupported-route unavailability, primary artifacts, existing core/evidence, preflight, protected routing, and release build. Reuse `--skip-build` only within the current prepared-product memory boundaries; do not combine all render-heavy suites into one process.

- [ ] Run exact resource/readiness tests and commit identities, resources, and CI together.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-artifacts \
  --filter '(CurrentRuntimeTests|ProfessionalQualityCalibrationTests|ProfessionalQualityCalibrationIntegrationTests|PrimaryEvaluatorReadinessTests|RepositorySurfaceTests)'
git add .github/workflows/swift.yml Sources/AutoTechnoCore/QualityQualification.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift \
  Sources/AutoTechnoDSP/Resources \
  Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift \
  Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift
git commit -m "Qualify live headroom primary artifacts"
```

Expected: exact v3 artifacts load only for supported 44.1/48 kHz native-stereo routes; missing files, old files, 8 kHz, and 12 kHz remain truthfully unavailable.

## Task 12: Remove stale mechanisms and document the one path

**Files:**

- Modify: `README.md`
- Modify: `docs/PRODUCT.md`
- Modify: `docs/SOUND_QUALITY.md`
- Modify: `docs/AUTONOMOUS_RUNTIME_PROVENANCE.md`
- Modify: `docs/AUTONOMOUS_RUNTIME_VALIDATION.md`
- Modify: `docs/ROADMAP.md`
- Create: `docs/LIVE_FEEDBACK.md`
- Modify: `docs/history/VALIDATION_SNAPSHOTS.md`
- Modify: `Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift`

- [ ] Write failing repository-surface assertions that active documentation and source contain one canonical evaluator/controller path and no paired-selection, alternate evaluator, legacy profile, callback analyzer, master-boost, or user-selectable feedback language. Historical documents may describe past states only when clearly marked historical and not linked as current architecture.

- [ ] Run the red repository check.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-docs \
  --filter RepositorySurfaceTests
```

Expected: failures identify stale current-path wording or missing live-feedback documentation.

- [ ] Document the exact ownership and lifecycle in `docs/LIVE_FEEDBACK.md`: callback queue limits; forbidden callback work; scheduled-range ledger; exact clock-map availability; first-three-second window; BS.1770/profile target; attenuation/recovery bounds; pending-versus-committed state; one invalidation; route/pause/shutdown; deterministic replay; failure hold; qualification and physical QA separation.

- [ ] Update the five normative product/runtime/quality/validation/roadmap documents to describe live feedback as the seventh completed architectural stage but not as physical-output qualification. State that offline replay, app launch, route QA, listening, and hardware soak remain distinct evidence.

- [ ] Remove stale comments, test fixtures, and active-doc references that preserve legacy v2 decoding or imply paired/secondary selection. Task 10 owns source decoder removal. Do not rewrite immutable Git history.

- [ ] Run documentation checks green and commit.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-docs \
  --filter RepositorySurfaceTests
rg -n 'paired selection|alternate evaluator|secondary evaluator|profile-v2|adversarial-suite-v2|holdout-v2' \
  README.md docs Sources Tests .github Package.swift
git add README.md docs/PRODUCT.md docs/SOUND_QUALITY.md \
  docs/AUTONOMOUS_RUNTIME_PROVENANCE.md \
  docs/AUTONOMOUS_RUNTIME_VALIDATION.md docs/ROADMAP.md \
  docs/LIVE_FEEDBACK.md docs/history/VALIDATION_SNAPSHOTS.md \
  Tests/AutoTechnoCoreTests/CurrentRuntimeTests.swift
git commit -m "Document canonical live feedback path"
```

Expected: repository tests pass; remaining search hits, if any, are explicitly historical test assertions proving absence from current surfaces.

## Task 13: Run serial local qualification and realtime audits

**Files:** none unless a failure demonstrates a defect.

- [ ] Confirm the branch is clean and capture its exact candidate SHA.

```bash
git status --short --branch
git diff --check origin/main...HEAD
git rev-parse HEAD
```

- [ ] Run callback queue, symbol, and App lifecycle validation first.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-live-v1-final-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-live-v1-final-swiftpm \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-final \
  --filter '(LivePCMQueueTests|LiveFeedbackCoordinatorTests|TechnoEngineLiveFeedbackTests)'
nm -u "$(find /private/tmp/auto-techno-live-v1-final -name 'CAutoTechnoRealtimeProducer.c.o' -print -quit)" \
  | rg 'calloc|free|malloc|mutex|dispatch|os_log|printf'
```

Expected: all tests pass and symbol search has no matches.

- [ ] Run live evidence/controller/render/candidate suites serially.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-final \
  --filter '(LiveFeedbackCoreTests|LiveOutputWindowEvidenceTests|LiveMasterHeadroomControllerTests|LiveMasterTrimRenderingTests|AutonomousCandidateEvaluationTests|BS1770AudioEvidenceTests)'
```

- [ ] Run primary calibration/readiness, preparation, protected routing, and the existing architecture suites in the same serial process partitions as CI.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-final \
  --filter '(CurrentRuntimeTests|ProfessionalQualityCalibrationTests|ProfessionalQualityCalibrationIntegrationTests|PrimaryEvaluatorReadinessTests|QualityQualificationFoundationTests|StreamingPerceptualEvidenceTests)'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-final \
  --filter AutonomousPreparationPreflightTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-final \
  --filter SpatialProtectedRoutingRegressionTests
```

- [ ] Run the remaining full suite serially and build the release executable from the same exact SHA.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --disable-sandbox --no-parallel \
  --build-path /private/tmp/auto-techno-live-v1-full
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift build -c release --disable-sandbox \
  --build-path /private/tmp/auto-techno-live-v1-release \
  --product AutoTechno
```

Expected: every test passes and release build succeeds. Record exact test counts, artifact fingerprints, queue memory size, and build SHA. A launch is not route QA, listening evidence, or hardware soak.

- [ ] Perform a final callback audit of every tap closure and C producer call site. Confirm no allocation, lock, wait, actor hop, task creation, log, file/network I/O, microphone access, UI work, analyzer call, or mutable planning state is reachable from the callback.

## Task 14: Reconcile, publish, prove exact-head CI, and launch

**Files:** none unless reconciliation exposes a conflict requiring a verified fix.

- [ ] Fetch `origin/main` at the clean validation boundary and coordinate with active tasks. If main moved, rebase, resolve semantically, regenerate v3 artifacts when any identity/calibration input changed, and rerun Task 13.

```bash
git fetch origin --prune
git rev-parse HEAD
git rev-parse origin/main
git status --short --branch
```

- [ ] Push the verified feature branch without force, then publish the exact verified head to `main` as already authorized for this implementation sequence.

```bash
git push -u origin codex/live-feedback-v1
git push origin HEAD:main
git fetch origin --prune
git rev-parse HEAD
git rev-parse origin/codex/live-feedback-v1
git rev-parse origin/main
```

Expected: all three SHAs are identical and the worktree is clean.

- [ ] Find and wait for the GitHub Actions run whose `headSha` is that exact SHA.

```bash
LIVE_FEEDBACK_CI_RUN_ID="$(gh run list --workflow 'Swift CI' \
  --commit "$(git rev-parse HEAD)" --limit 1 \
  --json databaseId --jq '.[0].databaseId')"
test -n "$LIVE_FEEDBACK_CI_RUN_ID"
gh run watch "$LIVE_FEEDBACK_CI_RUN_ID" --exit-status
gh run view "$LIVE_FEEDBACK_CI_RUN_ID" --json headSha,status,conclusion,url,jobs
```

Expected: `headSha` equals local/branch/main; conclusion is `success`; callback, App transport, live evidence/controller, primary, preflight, protected routing, and release steps all pass.

- [ ] Build a fresh release app at the published exact SHA, identify any older AutoTechno process by exact path, stop only that process, and launch the new executable.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift build -c release --disable-sandbox \
  --build-path /private/tmp/auto-techno-live-v1-published-release \
  --product AutoTechno
ps -axo pid=,command= | rg '/AutoTechno($| )'
open /private/tmp/auto-techno-live-v1-published-release/arm64-apple-macosx/release/AutoTechno
ps -axo pid=,etime=,command= \
  | rg '/private/tmp/auto-techno-live-v1-published-release/.*/AutoTechno($| )'
```

Expected: one running PID from the exact published release path. Keep it open for user listening.

- [ ] Report exact SHA, CI URL, touched-file list, test counts, v3 artifact fingerprints, queue bounds, running PID/path, and separate statuses for offline qualification, launch, app/route QA, listening, and physical-output soak. Send the exact safe handoff SHA/touched-file list to the paused Auto Techno task.

## Final plan self-review

- [ ] Trace every approved design requirement to at least one task and one named test: fixed C queue, callback prohibitions, native stereo bounds, exact mixer/player clock mapping, scheduled ledger retention, exact three-second window, existing BS.1770 reuse, strictest profile bounds, attack/recovery/deadband/saturation, no boost, pending-versus-committed state, terminal-only trim, truthful pre/post evidence, one invalidation, rejected-candidate hold, route/pause/shutdown lifecycle, deterministic replay, exact version cutover, legacy removal, complete regenerated corpus/adversarial/holdout bank, serial CI, publication, and app launch.

- [ ] Scan this plan for placeholder language.

```bash
rg -n '[T]BD|[T]ODO|[F]IXME|implement [l]ater|similar [t]o|and [s]o on|etc[.]' \
  docs/superpowers/plans/2026-08-16-live-feedback-master-headroom.md
```

Expected: no hits.

- [ ] Cross-check every named current type and source path before execution.

```bash
rg -n 'AutonomousSessionState|QualityContinuationState|RenderState|PhrasePreparationKey|PreparedAutonomousPhrase|AutonomousCandidateEvaluationVector|AutonomousCandidateEvaluationTransaction|ProfessionalQualityProfile|ProfessionalQualityPrimaryArtifacts|BS1770LoudnessMeasurement' \
  Sources Tests Package.swift
```

Expected: every current integration owner exists. Every new type is introduced by a prior plan task before its first green command.

- [ ] Confirm repository state after committing this plan.

```bash
git status --short --branch
git diff --check origin/main...HEAD
git log --oneline --decorate -4
```

Expected: clean plan branch, two documentation commits ahead of the safe base, and no implementation edit before the execution-method decision.
