# Source 21 Upper-Percussion Tail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give existing clap, open-hat, and metallic-percussion events a bounded score-owned foreground-clearance tail role whose attack stays exact, whose shortened tail is audible and attributable, and whose result is accepted only by the calibrated single-primary evaluator.

**Architecture:** `AutonomousSessionDirector` resolves one post-arbitration articulation per eligible upper-percussion score event. `VoiceRenderer` applies a state-free tail multiplier inside the existing event loops and streams same-pass evidence without retaining event PCM. `AutonomousCandidateEvaluationVector` binds score, render, route geometry, and consequence; Professional Evidence adds two calibrated observation dimensions and regenerates the exact-engine profile, adversarial suite, and disjoint holdout artifacts.

**Tech Stack:** Swift 6.3, Swift Testing, deterministic offline DSP, typed FNV-1a fingerprints, exact PCM fingerprints, Professional Evidence v6 calibration pipeline, SwiftPM/Xcode serial validation, GitHub Actions split CI.

---

## Task 1: Lock the post-arbitration score policy with failing Core tests

**Files:**
- Create: `Tests/AutoTechnoCoreTests/UpperPercussionTailTests.swift`
- Create: `Sources/AutoTechnoCore/UpperPercussionTail.swift`
- Modify: `.github/workflows/swift.yml`

- [ ] **Step 1: Add the focused failing policy tests**

Add `@Suite("Upper percussion tail")` with fixtures using real `EnsembleContext`
events. Assert that the resolver:

```swift
#expect(articulations.map(\.scoreEventIndex) == [clapIndex, openHatIndex, metallicIndex])
#expect(articulations.allSatisfy { $0.role == .foregroundClearance })
#expect(UpperPercussionTailResolver.resolve(
    ensemble: percussionFocused,
    phraseKind: .contrast,
    conservative: false
).allSatisfy { $0.role == .naturalBody })
```

Cover supporting-focus reachability; exact natural-body resolution for
percussion focus, intentional pileup, conservative generation, and
`identityReturn`; noneligible voices; deterministic ordering; normalized steps;
and the four-record bound.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-source21-module-cache-core \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-source21-module-cache-core \
  xcrun swift test --disable-sandbox --no-parallel --jobs 1 --skip-update \
  --disable-experimental-prebuilts \
  --scratch-path /private/tmp/auto-techno-source21-build-core \
  --filter UpperPercussionTailTests
```

Expected: compile failure because the role, articulation, and resolver do not
exist.

- [ ] **Step 3: Add the minimal Core types and pure resolver**

Implement:

```swift
package enum UpperPercussionTailRole: String, CaseIterable, Sendable {
    case naturalBody
    case foregroundClearance
}

package struct UpperPercussionTailArticulation: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let voice: EnsembleVoice
    package let step: Int
    package let role: UpperPercussionTailRole
}
```

`UpperPercussionTailResolver.resolve` must enumerate the final arbitrated event
array, accept only `.clap`, `.openHat`, and `.metallic`, emit no more than four
records, normalize steps into `0...15`, and choose clearance only when all four
policy predicates from the design hold.

- [ ] **Step 4: Add the new suite to the core/evidence CI regex**

Append `|UpperPercussionTailTests` to the existing serial core/evidence test
filter. Do not move heavy integration suites or combine process boundaries.

- [ ] **Step 5: Rerun the focused test and verify GREEN**

Expected: all `UpperPercussionTailTests` pass.

- [ ] **Step 6: Commit the pure policy slice**

```bash
git add Sources/AutoTechnoCore/UpperPercussionTail.swift \
  Tests/AutoTechnoCoreTests/UpperPercussionTailTests.swift \
  .github/workflows/swift.yml
git commit -m "Add score-owned percussion tail policy"
```

## Task 2: Thread the score owner through planning and preflight

**Files:**
- Modify: `Sources/AutoTechnoCore/AutonomousSession.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift`
- Modify: `Sources/AutoTechnoDSP/GeneratedDSPGraph.swift`
- Modify: `Tests/AutoTechnoCoreTests/UpperPercussionTailTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift`
- Modify: test-only `ResolvedPerformanceBar` copy helpers found by `rg 'ResolvedPerformanceBar\(' Tests Sources`

- [ ] **Step 1: Add failing resolved-score and fingerprint tests**

Assert a director-produced bar carries exactly the resolver output, that copying
a bar preserves it, and that changing only one tail role changes
`AutonomousCandidateFingerprint.plan`. Add malformed-package cases for missing,
duplicate, retargeted, reordered, and noncanonical articulations; require
preflight rejection before rendering.

- [ ] **Step 2: Run the two focused suites and verify RED**

Run `UpperPercussionTailTests` and the exact named preflight/fingerprint tests
serially against the same scratch path.

- [ ] **Step 3: Add the field to `ResolvedPerformanceBar`**

Add:

```swift
package let upperPercussionTailArticulations: [UpperPercussionTailArticulation]

package func upperPercussionTail(
    atEventIndex index: Int
) -> UpperPercussionTailArticulation? {
    upperPercussionTailArticulations.first { $0.scoreEventIndex == index }
}
```

The initializer default must derive from the final `ensemble`, current phrase
kind, and conservative state at the director call site rather than silently
guessing active policy. Pass the exact array through every production and test
copy constructor.

- [ ] **Step 4: Recompute after any post-pass event mutation**

Place resolution after ensemble arbitration and after score passes that can
remove or replace percussion events. When `KickSyntaxResolver` or another
post-pass reconstructs a bar, preserve unrelated arrays only when its ensemble
is unchanged; otherwise re-resolve against the reconstructed ensemble.

- [ ] **Step 5: Fingerprint the complete articulation array**

Bump the plan domain from `candidate-plan.typed.v11` to
`candidate-plan.typed.v12`. Encode count, score index, raw voice, normalized
step, and raw role in deterministic event-index order.

- [ ] **Step 6: Replay exact policy in bounded preflight**

After existing bar/count/geometry guards, regenerate the canonical tail array
from trusted plan fields and require exact equality. Keep the replay bounded to
16 bars times four records and check cancellation before phrase-wide replay.

- [ ] **Step 7: Rerun focused tests and commit**

```bash
git add Sources/AutoTechnoCore/AutonomousSession.swift \
  Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift \
  Sources/AutoTechnoDSP/GeneratedDSPGraph.swift \
  Tests/AutoTechnoCoreTests
git commit -m "Bind percussion tail policy to the canonical plan"
```

## Task 3: Specify and implement the state-free DSP contract

**Files:**
- Create: `Sources/AutoTechnoDSP/UpperPercussionTailDSP.swift`
- Create: `Tests/AutoTechnoCoreTests/UpperPercussionTailDSPTests.swift`
- Modify: `.github/workflows/swift.yml`

- [ ] **Step 1: Add failing pure-contract tests**

Test 44.1, 48, 96, and 192 kHz. Require:

```swift
#expect(contract.multiplier(frame: attackFrames - 1, ...) == 1)
#expect(contract.multiplier(frame: frameCount - 1, ...) == 0.25)
#expect(naturalBodySamples.elementsEqual(baseSamples))
```

Verify monotonic nonincrease after the attack, continuity at the attack/tail
join, literal neutral unity, signed-zero preservation, finite output, no
division by zero for one-frame tails, and exact physical-time attack geometry.

- [ ] **Step 2: Run and verify RED**

Use an isolated `source21-build-dsp` scratch and filter
`UpperPercussionTailDSPTests`.

- [ ] **Step 3: Implement the reusable contract**

Define route-normalized attack frames with `round(0.008 * sampleRate)`. For
clearance frames after the attack use a raised-cosine interpolation:

```swift
let progress = Double(frame - attackFrames) /
    Double(max(1, frameCount - attackFrames - 1))
let eased = 0.5 - 0.5 * cos(.pi * progress)
return Float(1.0 - 0.75 * eased)
```

Branch `naturalBody` to literal `1` before any transcendental math. Clamp only
validated integer geometry, not source-derived musical values.

- [ ] **Step 4: Run GREEN and commit**

```bash
git add Sources/AutoTechnoDSP/UpperPercussionTailDSP.swift \
  Tests/AutoTechnoCoreTests/UpperPercussionTailDSPTests.swift \
  .github/workflows/swift.yml
git commit -m "Add bounded percussion tail DSP contract"
```

## Task 4: Apply the contract in the existing renderer loops

**Files:**
- Modify: `Sources/AutoTechnoDSP/VoiceRenderer.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousArchitectureTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/SpatialProtectedRoutingRegressionTests.swift`
- Modify: test `RenderBlock` and `RenderedBar` builders found by `rg 'RenderBlock\(|RenderedBar\(' Tests`

- [ ] **Step 1: Add failing active-versus-neutral renderer tests**

Render one identical resolved bar twice, changing only the semantic tail role.
Assert equal event count, onset, step, intensity, timing, frame count, and first
8 ms PCM/hash; require changed event/full percussion hash, lower tail RMS and
tail-to-attack dB, nonzero difference RMS, and exact equality for kick,
foundation, modal percussion, groove pulse, closed hat, upper tonal, atmosphere,
and later unaffected event RNG output.

- [ ] **Step 2: Add a reduced renderer-evidence type**

`UpperPercussionTailRenderEvidence` retains the fields specified in the design.
Provide streaming accumulators for base, rendered, attack-prefix, whole-event,
energy, peak, tail energy, and difference energy. Do not allocate event sample
arrays.

- [ ] **Step 3: Refactor clap/open-hat/metallic rendering**

Look up the articulation by score event index. Preserve the current base sample
expression and RNG order. Apply the multiplier only after the base sample is
computed, then write the rendered sample to existing buses. Neutral must avoid
new floating-point operations on the audible sample.

- [ ] **Step 4: Propagate evidence and pass equality**

Add sorted `[UpperPercussionTailRenderEvidence]` to `RenderedBar` and
`RenderBlock`, plus a boolean proving exact full/protected pass equality. Copy
the field through all builders. Do not retain base or rendered PCM outside the
event loop.

- [ ] **Step 5: Run focused renderer and protected-routing tests**

Run the new DSP suite, the named A/B architecture test, and the protected
routing suite serially. Verify natural-body golden hashes stay unchanged.

- [ ] **Step 6: Commit**

```bash
git add Sources/AutoTechnoDSP/VoiceRenderer.swift \
  Sources/AutoTechnoDSP/AutonomousPhraseRenderer.swift \
  Tests/AutoTechnoCoreTests
git commit -m "Render score-owned percussion tail clearance"
```

## Task 5: Bind score, renderer, and candidate evidence

**Files:**
- Modify: `Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift`
- Modify: `Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/UpperTimbreIntegrationTests.swift`

- [ ] **Step 1: Add failing compact-evidence tests**

Add a valid bar/event fixture and assert JSON key shape, round trip,
fingerprint sensitivity, `selectionEvidence` inclusion only through the current
professional observation path, and exact correction equality. Add decoded
forgeries for five events, seventeen bars, duplicate index, unsupported voice,
wrong role/policy, route geometry, multiplier, base/render attack hash, no-op
active hash, tail growth, nonfinite scalar, and pass mismatch.

- [ ] **Step 2: Add compact candidate records**

Create `AutonomousUpperPercussionTailEventEvidence` and
`AutonomousUpperPercussionTailBarEvidence`. Maximums are four events per bar and
sixteen bars. Store no PCM and no redundant workstation/source labels.

- [ ] **Step 3: Reduce same-pass evidence with exact one-to-one matching**

In `AutonomousCandidateEvaluationVector.make`, bind bar, focus role, pileup,
source counts, score index, voice, step, role, intensity, timing, frame geometry,
contract multiplier, hashes, metrics, and pass equality. Preserve a mismatched
record as reason-coded incomplete evidence; do not silently synthesize success.

- [ ] **Step 4: Extend completeness, finiteness, bounds, structural retention, and correction replay**

Require all bars to have a record, exact chronological identity, exact policy
replay, and exact neutral/active consequence. Add the new field to the shallow
reference-backed validation phases so the cooperative test stack does not grow
through nested large-value copies.

- [ ] **Step 5: Prove a real prepared product end to end**

Prepare a reachable nonconservative supporting-focus phrase. Assert the selected
single primary plan is commit-eligible and every live compact event matches the
actual resolved score/render evidence. Add a conservative/identity neutral
prepared product and a render-evidence tamper rejection.

- [ ] **Step 6: Run focused suites and commit**

```bash
git add Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift \
  Tests/AutoTechnoCoreTests/AutonomousCandidateEvaluationTests.swift \
  Tests/AutoTechnoCoreTests/QualityQualificationFoundationTests.swift \
  Tests/AutoTechnoCoreTests/UpperTimbreIntegrationTests.swift
git commit -m "Bind percussion tail evidence to primary evaluation"
```

## Task 6: Advance exact engine and wire identities

**Files:**
- Modify: `Sources/AutoTechnoCore/QualityQualification.swift`
- Modify: `Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift`
- Modify: version assertions and exact fingerprint tests under `Tests/AutoTechnoCoreTests`

- [ ] **Step 1: Add failing identity assertions**

Assert quality schema 23, vector schema 21, engine v22, and plan domain v12.
Leave transaction schema 4, upper-timbre schema 3, live-feedback schema, commit,
and continuation identities unchanged.

- [ ] **Step 2: Update production constants**

Change only identities whose decoded shape or canonical PCM changed.

- [ ] **Step 3: Run exact fingerprint tests and capture actual failures**

Run `AutonomousCandidateEvaluationTests.exactStateFingerprints`. Replace golden
values only with values emitted by the exact implementation; never calculate or
guess them manually.

- [ ] **Step 4: Rerun and commit**

```bash
git add Sources/AutoTechnoCore/QualityQualification.swift \
  Sources/AutoTechnoDSP/AutonomousCandidateEvaluation.swift \
  Tests/AutoTechnoCoreTests
git commit -m "Advance percussion tail engine identities"
```

## Task 7: Add calibrated professional dimensions and adversarial cases

**Files:**
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityCalibration.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityAdversarialSuite.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalEvidenceReportBank.swift`
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift`
- Modify: `Tests/AutoTechnoCoreTests/BS1770AudioEvidenceTests.swift`

- [ ] **Step 1: Add failing observation and policy tests**

Add `clearance-active-event-ratio` and
`clearance-rendered-tail-to-attack-db-mean`. Require bounded finite values,
deterministic cross-rate observations, inclusion in every current profile
dimension, and noncompensable rejection for missing/out-of-range dimensions.

- [ ] **Step 2: Derive the observations from compact candidate evidence**

The ratio denominator is the number of eligible upper-percussion events. The
tail metric averages only active clearance events and must carry an explicit
unavailable/zero-active representation consistent with current optional metric
semantics. Do not reuse video LUFS or peak measurements as thresholds.

- [ ] **Step 3: Advance affected Professional Evidence identities**

Advance observation/profile/report-bank/adversarial/holdout/evaluator identities
once exact Codable shapes are known. Keep unrelated live feedback and runtime
schemas unchanged.

- [ ] **Step 4: Add adversarial mutations**

Mutate clearance ratio, tail relation, role binding, missing evidence, and
cross-rate drift independently. Every mutation must fail for the named reason
while the unmodified canonical bank remains accepted.

- [ ] **Step 5: Run focused calibration tests and commit code/tests**

```bash
git add Sources/AutoTechnoDSP/ProfessionalQualityCalibration.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityAdversarialSuite.swift \
  Sources/AutoTechnoDSP/ProfessionalEvidenceReportBank.swift \
  Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift \
  Tests/AutoTechnoCoreTests
git commit -m "Qualify upper-percussion tail clearance"
```

## Task 8: Regenerate exact-engine profile, adversarial, and holdout artifacts

**Files:**
- Replace: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v3.json` with the next versioned resource
- Replace: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-adversarial-suite-v3.json` with the next versioned resource
- Replace: `Sources/AutoTechnoDSP/Resources/professional-quality-primary-holdout-v3.json` with the next versioned resource
- Modify: `Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift`
- Modify: artifact assertions under `Tests/AutoTechnoCoreTests`

- [ ] **Step 1: Run the opt-in 28-journey development calibration serially**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  AUTOTECHNO_RUN_PROFILE_CALIBRATION=1 \
  AUTOTECHNO_CALIBRATION_RESOURCE_DIRECTORY=/private/tmp/auto-techno-source21-calibration-output \
  AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY=/private/tmp/auto-techno-source21-calibration-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/auto-techno-source21-module-cache-calibration \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/auto-techno-source21-module-cache-calibration \
  xcrun swift test --disable-sandbox --no-parallel --jobs 1 --skip-update \
  --disable-experimental-prebuilts \
  --scratch-path /private/tmp/auto-techno-source21-build-calibration \
  --filter ProfessionalQualityCalibrationIntegrationTests.generateRepresentativeProfile
```

- [ ] **Step 2: Inspect generated identities and atomically place versioned resources**

Use `jq -S` and `shasum -a 256` for inspection. Move only the three generated
JSON artifacts into the package resources using `apply_patch`/approved file
operations; delete superseded versions only after production references use the
new names.

- [ ] **Step 3: Run adversarial and disjoint four-journey holdout qualification**

Run the focused calibration/artifact/holdout suites. Require zero source-bank
overlap, all expected adversarial rejections, and all canonical holdout verdicts
accepted at 44.1 and 48 kHz.

- [ ] **Step 4: Update artifact fingerprints from generated bytes and commit**

```bash
git add Sources/AutoTechnoDSP/Resources \
  Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift \
  Tests/AutoTechnoCoreTests
git commit -m "Regenerate Source 21 quality artifacts"
```

## Task 9: Record source provenance, maturity, and runtime claims

**Files:**
- Modify: `docs/history/TASTE_EXPERIMENTS.md`
- Modify: `docs/SOUND_CONCEPT_MATURITY.md`
- Modify: `docs/SOUND_QUALITY.md`
- Modify: `docs/AUTONOMOUS_RUNTIME_PROVENANCE.md`
- Modify: `docs/AUTONOMOUS_RUNTIME_VALIDATION.md`
- Modify: `docs/ROADMAP.md`
- Modify: `README.md`
- Modify: `docs/VIDEO_ANALYSIS_PROTOCOL.md`
- Create gitignored: `docs/reference/video-evidence/source-21-upper-percussion-tail.md`

- [ ] **Step 1: Add the sanitized source record**

Record video ID/title/channel, 2026-08-18 access date, automatic-caption status,
exact yt-dlp command shape, 50 top-ranked comments plus four replies, caption and
metadata hashes, paraphrased timestamp claims, temporary-audio limitations, and
the absence of three-comment portable convergence. Do not include usernames,
whole comments, presenter identity, temporary absolute paths, or source PCM.

- [ ] **Step 2: Record the reusable concept maturity**

Distinguish the durable score relation (supporting percussion leaves foreground
space) from the replaceable v1 raised-cosine/0.25 DSP realization. Name the
future maturation path: program-dependent decay/release models, per-instrument
physical envelopes, and evaluator-calibrated contextual tails without changing
the score contract.

- [ ] **Step 3: Update schema, quality, provenance, and validation docs**

State exact current identities, evidence fields, bounds, pass equality, detached
execution, no callback work, calibrated metrics, and validation performed. Do
not claim listening, app/route QA, hardware soak, or latency/peak-memory results
that were not run.

- [ ] **Step 4: Verify public privacy and placeholder hygiene**

```bash
rg -ni "oscar|TODO|TBD|placeholder|fill this in" README.md docs Sources Tests
git check-ignore -v docs/reference/video-evidence/source-21-upper-percussion-tail.md
git diff --check
```

- [ ] **Step 5: Commit documentation**

```bash
git add README.md docs ':!docs/reference/video-evidence'
git commit -m "Document Source 21 percussion tail evidence"
```

## Task 10: Final verification, review, rebase, publication, and exact-head CI

**Files:**
- Verify all Source 21 changes
- Modify only defects found by verification or review

- [ ] **Step 1: Run the split serial local matrix**

Run, in separate processes with `--no-parallel --jobs 1`:

1. new Core/DSP/evidence tests;
2. core/evidence CI regex;
3. preparation preflight;
4. protected routing;
5. upper integration slices;
6. calibration/profile/adversarial/holdout suites;
7. release build.

Record exact counts, durations, Xcode/Swift identity, scratch paths, and any
unrun validation boundary.

- [ ] **Step 2: Run a bounded independent advisory review**

If the repository's approved Antigravity wrapper is available, provide it only
a sanitized diff/context bundle and request P0-P2 DSP, realtime, evidence, and
test findings. Do not send source captions, comments, credentials, or local
paths. Fix verified findings test-first and rerun affected suites.

- [ ] **Step 3: Refresh main and prove the publication base**

```bash
git fetch origin
git rebase origin/main
git status --short --branch
git diff --check origin/main
```

If rebase changes production files, rerun every affected split plus release.

- [ ] **Step 4: Push the verified Source 21 commit chain to main**

```bash
git push origin HEAD:main
git ls-remote origin refs/heads/main
```

Require the returned remote SHA to equal local `HEAD`.

- [ ] **Step 5: Monitor exact-head GitHub Actions to success**

Verify every split test and release-build step is green for the pushed SHA. Do
not count the video as complete while CI is pending or red.

- [ ] **Step 6: Report and pause**

Report exact SHA, touched files, local matrix, CI run, source provenance,
concept-record location, and boundaries not claimed. Advance progress from
20/32 to 21/32 (65.6%) only after exact-head CI succeeds, then pause the video
loop as requested.
