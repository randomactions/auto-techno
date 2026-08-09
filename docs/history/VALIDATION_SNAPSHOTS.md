# Validation Snapshots

> **Non-normative provenance notice:** The dated records below are preserved
> verbatim from the former runtime-validation appendix. They document historical
> fixtures, candidate states, local toolchains, and incomplete gates. They do not
> define the current product, quality targets, release contract, or implementation
> status. Use [`../AUTONOMOUS_RUNTIME_VALIDATION.md`](../AUTONOMOUS_RUNTIME_VALIDATION.md)
> for current requirements.

## Legacy engineering appendix — 2026-08-08 cleanup preservation record

The numeric fixtures below predate the all-in product contract. They remain an
engineering provenance record only; they are neither selectable product choices
nor current musical acceptance criteria.

The autonomous phrase path from pre-cleanup `f14c3a8` was rendered again from a
temporary checkout and compared with the cleaned working tree. Both used the
same local machine and warmed SwiftPM/module caches. The PCM output was
bit-identical, so matched-loudness gain is exactly `1.0` and no audible-difference
claim is involved.

| Legacy fixture | Rate | Sample hash | RMS | True peak | DC | Low correlation | Boundary | Baseline / cleaned prep |
| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 42 | 44,100 | `194cfd9b41526538` | 0.109890 | 0.428781 | 0.000495 | 0.999959 | 0.021120 | 56.58s / 56.55s |
| 48,291 | 44,100 | `04dcfcadcf870950` | 0.112622 | 0.454291 | 0.000570 | 0.999963 | 0.019802 | 41.68s / 41.52s |
| 90,909 | 48,000 | `f22539221aaf3155` | 0.111463 | 0.436864 | 0.000725 | 0.999972 | 0.047000 | 28.59s / 28.68s |

The paired baseline/cleaned WAV SHA-256 values were respectively
`e80c04f30ef18a5a8e0aaa16b96d59a16e9be8b774fe5761049e51dc56a745ac`,
`7fb53b14e017cc7bcbf4988608d2b0666625c944d6e9a019e04adf6052dfd41b`,
and `718e225c7065452c12a1a856e009bdda3b920cc9aea2285ffa2e03ad0dbe2f48`.
The cleanup-era compact 8 kHz hashes were `bca565a2c3a17f31`,
`d0e39cebdaed39d6`, and `f6486cd179cd9c6b`. They remain historical baselines;
the implementation candidate does not replace them before listening approval.

## Video-informed candidate status — 2026-08-08

The cleanup hashes above remain the immutable `942786a` baseline. The
groove-first implementation intentionally changes render math, so its tests
verify repeatability without declaring new canonical hashes. The current
candidate also replaces independent upper-voice clocks with a three-step driver
advancing a five-stage follower and bounded sixteen-bar chapters. Focused phase,
chapter, and resolved-audio tests pass with Xcode 26.6's matching Swift 6.3.3
compiler and SDK. The complete 31-test suite and optimized release build also
pass in that toolchain. Matched-loudness listening approval and the
physical-output soak remain separate gates until recorded.

## Kick hierarchy trim evidence — 2026-08-08

Before the fixed kick fader changed render math, the continuous canonical Play
journey was captured from the preserved all-in worktree at 8 kHz. The candidate
was then captured through the identical journey and continuation state. These
compact-rate measurements are engineering diagnostics, not promoted canonical
hashes and not a listening verdict. “Kick window” is the mono RMS inside 80 ms
of each resolved onset; “non-onset” is the remaining program and still contains
kick decay, so its ratio must not be interpreted as an isolated stem balance.

| Checkpoint | Bars | Pre-trim hash | Pre RMS | Pre peak | Pre kick window | Pre non-onset | Pre ratio dB |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| First macro | 0–15 | `d5579c7d1b6fd9f6` | 0.10292836 | 0.45808718 | 0.24171786 | 0.02373352 | 20.1589 |
| Contrast | 13–17 | `c6ca150043bb8e4e` | 0.10303850 | 0.45808718 | 0.24195199 | 0.02380673 | 20.1406 |
| Break | 100–111 | `9ac78e550515d537` | 0.08665728 | 0.42481762 | 0.20425887 | 0.01832034 | 20.9449 |
| Release | 84–99 | `a8f0c7dcd7de4922` | 0.10330837 | 0.49265024 | 0.24251953 | 0.02400307 | 20.0896 |
| Identity return | 118–127 | `ecf4cd5c4ff8c1b4` | 0.10298184 | 0.45418200 | 0.24183369 | 0.02374941 | 20.1573 |

| Checkpoint | Candidate hash | Candidate RMS | Candidate peak | Candidate kick window | Candidate non-onset | Candidate ratio dB |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| First macro | `e50fdd2d1d020804` | 0.09248096 | 0.43606511 | 0.21769339 | 0.02019814 | 20.6507 |
| Contrast | `537e1287e47e598a` | 0.09260683 | 0.43626565 | 0.21796369 | 0.02027883 | 20.6268 |
| Break | `5dfc9fb3e8874f8e` | 0.07499181 | 0.38633171 | 0.17691938 | 0.01548090 | 21.1596 |
| Release | `e044e41862f16e01` | 0.09297638 | 0.44529971 | 0.21879862 | 0.02043053 | 20.5953 |
| Identity return | `33b3a01381fff976` | 0.09255140 | 0.43501356 | 0.21785671 | 0.02019889 | 20.6569 |

The direct signal-path test is authoritative for the fader itself: post-fader
kick RMS is `1.5 ± 0.05 dB` below the pre-fader detector, the detector retains
the original regular and breakdown levels, the ducking envelope follows that
detector, masking consumes the post-fader peak, and reported kick onsets and
positions are unchanged. Matched-loudness listening and physical-output soak
remain pending. The optimized release executable also passed a native UI smoke:
the single accessible `transport-play-pause` control changed LIVE → PAUSED →
LIVE → PAUSED, its label changed PAUSE → PLAY → PAUSE → PLAY, and the displayed
phrase/bar position continued after resume. Route switching, interruption
recovery, and the hour-long physical-output soak were not covered by this smoke.

## Automatic kick/foundation evidence — 2026-08-09

The five dry measurement stems were first added at unity. Before the automatic
gain was enabled, the compact 8 kHz first-macro hash remained bit-identical at
`e50fdd2d1d020804`, proving that observation alone did not alter PCM. Tests also
reconstruct the dry center from kick + foundation + percussion and the dry upper
bus from upper-tonal + atmosphere with maximum sample error below `1e-6`.

The bounded governor then changed only the post-fader kick. In the canonical
first macro, mono rumble produced a raw active-level difference near `28.96 dB`;
the correction settled at approximately `-1.23 dB`, producing `27.73 dB` against
the authored `27.5 dB` target. The compact candidate metrics are:

| Stage | Hash | RMS | True peak |
| --- | --- | ---: | ---: |
| Fixed `-1.5 dB` kick baseline | `e50fdd2d1d020804` | 0.092480965 | 0.4360651 |
| Automatic hierarchy candidate | `35a6c0e5d4bb271c` | 0.083510700 | 0.4143651 |

Synthetic long-run coverage verifies the `-3...0 dB` bounds, maximum
`0.35 dB` step, deadband convergence without gain drift, and state hold during
breaks or invalid foundation observations. Companion fixtures reach the intended
active-level neighborhoods for bass (`16.5 dB`), mono rumble (`27.5 dB`), and
tuned tom (`22.5 dB`). The resolved kick event count and positions, pre-fader
detector, and detector-derived ducking remain unchanged; masking and level
metadata consume the final post-fader kick.

The display envelope is tested separately: equal input energy always produces
equal height and a 6 dB input difference remains visible because bars are no
longer normalized independently. These automated results do not constitute the
pending matched-loudness listening verdict or physical-output soak.

The complete 34-test suite and optimized release build pass locally with Xcode
26.6 / Apple Swift 6.3.3. A native release-bundle smoke also passed: the single
accessible `transport-play-pause` control moved READY → LIVE → PAUSED → LIVE →
PAUSED, phrase/bar position continued across resume, and the fixed-scale waveform
rendered while live. Route switching, interruption recovery, and the hour-long
physical-output soak were not exercised by this smoke.

## Weak-sixteenth groove reveal evidence — 2026-08-09

Before changing render math, the exact `9157658` baseline passed all 34 tests and
produced a 44.1 kHz canonical first-macro hash of `c0a8e56171793343` (RMS
`0.09027027`, true peak `0.40203717`, loudness estimate `-21.580105`, low-band
correlation `0.9999444`). The weak-sixteenth candidate produced hash
`8cae318d64ba05aa` (RMS `0.09027233`, true peak `0.4020319`, loudness estimate
`-21.579906`, low-band correlation `0.9999444`). Its resolved trace is empty for
bars 1–4, eight alternating weak positions for bars 5–11, only steps 7 and 15 on
bar 12, and trailing weak positions 3/7/11/15 for bars 13–16. Loudness-normalized
bars 1–4 are bit-identical before and after.

The expanded 39-test suite passes with Xcode 26.6 / Apple Swift 6.3.3, including
macro and phrase-boundary continuity, break exclusion, priority preservation,
weighted density, resolved metadata/PCM coupling, exact percussion-stem routing,
automatic-mix exclusion, mono carrier output, low-frequency rejection,
deterministic continuation, and representative 44.1/48 kHz safety renders. The
optimized release build also passes. A native smoke verified the single enabled
`transport-play-pause` accessibility control and LIVE → PAUSED → LIVE continuation
from phrase 1 into phrase 2; the temporary release instance was then paused and
closed.

Temporary 44.1 kHz matched-loudness pairs exist for skeleton, contour,
syncopated-lean, and pullback stages, plus the isolated carrier. Human listening
approval, route/interruption testing, and the physical-output soak remain pending.

## Video-derived autonomous timbre foundation — 2026-08-09

This snapshot describes the implementation published through merge commit
`5038b9f`, based on the validated `853a4dc` feature commit. It is an implementation
and local-validation record, not a professional-quality promotion. The matched
toolchain was Xcode 26.6 build 17F113 with Apple Swift 6.3.3.

The canonical score now owns resolved upper-note pitch, duration, velocity,
gate, slide destination, and bounded timbre intent. The existing Alien Analog
voice renders occasional resonant-sequence anchor articulation in eligible
motion chapters and existing two-oscillator detuned motion for eligible
tone-chapter shadow/response roles. Home, protected foundation, event density,
graph topology, clocks, and UI remain the fallback identity. Applied renderer
evidence distinguishes retriggers from legato slides, uncapped requested gate
duration from bar-capped application, and role-local resonant-anchor from
detuned-companion PCM.

The evidence/report foundation remains deliberately
`qualification-unavailable`. Versioned decisions, reason codes, observed and
accepted fingerprints, controller provenance, route generation, future sample
boundaries, one transaction-wide correction budget, and deterministic JSON are
present. Acceptance requires internally consistent outcome/reason codes and an
atomic candidate/evidence/controller snapshot. The test harness discovers all
canonical journey checkpoint plans from an exact starting continuation, but
only the establishment checkpoint is currently rendered into a qualification
report.

Final local validation used serialized SwiftPM builds:

- `swift test --disable-sandbox --jobs 1`: 77 tests passed in 200.854 seconds.
- `swift test --disable-sandbox --jobs 1 --filter UpperTimbre`: 18 tests passed
  in 14.677 seconds before the final broad run.
- `swift test --disable-sandbox --jobs 1 --filter QualityQualificationFoundationTests`:
  10 tests passed in 1.806 seconds before the final broad run.
- `swift build --disable-sandbox -c release --jobs 1`: optimized release build
  passed in 28.09 seconds.
- The final adversarial diff audit found no remaining P0/P1 blocker, and
  `git diff --check` passed.

The generated graph still receives the exact `full - foundation` remainder.
That remainder includes percussion and shared nonlinear-mix residual, so it is
not described as an upper-only stem. Resonant and detuned articulation metrics
use dedicated dry role-local taps instead. The pre-existing masking inputs still
alias synth/texture context, omit foundation from their kick/bass grouping, and
rerender percussion with advanced RNG; full-window masking attribution is
therefore explicitly deferred.

No calibrated quality guardrails, coupled tone relationship, standards-aligned
loudness/true-peak promotion, spectral correction controller, dynamics/final
output promotion, complete multi-checkpoint report bank, end-to-end corrective
fault injection, independent PCM pitch estimator, preparation latency/peak
memory budget, full-phrase 96/192 kHz preparation, exact-build app/route QA,
matched-loudness listening verdict, or 60-minute physical-output/recovery soak
was completed. Those remain required before any production-ready sound claim.

## Truthful role routing and descriptive masking evidence — 2026-08-09

This candidate is based on `5038b9f`. It replaces the ambiguous
kick/percussion/synth/texture masking inputs with exact post-fader foundation,
dry percussion, and combined dry-upper taps. Percussion is rendered once per
layer, and the same exact dry tap feeds center output, drum reverb, protected
rhythm, and masking evidence. The generated graph now receives
`full - protected-rhythm`; the exact protected stereo rhythm is recombined after
the graph. Stable fingerprints distinguish dry foundation, dry percussion, and
the complete protected-rhythm route.

The analyzer emits a fixed twelve-observation vector across all sixteen bar
windows. It reports exact-pair activity, overlap count, maximum overlap, and
the longest consecutive run. Its causal filters may retain state across
windows, but exact source-window energy gates persistence so a filter tail after
one active window cannot fabricate a second active window. Valid silence is a
complete zero vector; malformed or non-finite input remains unavailable.

Masking is descriptive only. No uncalibrated masking cut or candidate promotion
is applied. Existing authored envelope, kick-linked, ducking, glue, and output
safety behavior remains active. This slice deliberately removes the prior
automatic cuts that were driven by aliased or stochastic-rerendered inputs.

Post-review local validation used Xcode 26.6 build 17F113 and Apple Swift 6.3.3:

- The full suite passed: 78 tests in 209.800 seconds.
- The focused masking suite passed after the causal-tail regression fix.
- The optimized release build passed in 32.49 seconds using the matched full
  Xcode SDK, isolated module caches, and a populated offline SwiftPM scratch
  path.
- `git diff --check` passed.
- An independent final diff review found no P0-P2 issue and confirmed that the
  early single-window regression closes the causal-filter-tail false positive.

The initial plain build selected mismatched Command Line Tools and failed at
manifest/SDK setup before compilation; it was not a source failure. No
matched-loudness listening, physical-output smoke, route/interruption test, or
60-minute soak was performed for this candidate. Preparation latency and peak
memory also remain unmeasured. The policy stays `uncalibrated.v1`, and quality
qualification remains unavailable.

## Anchor velocity expression and role-local evidence — 2026-08-09

This candidate builds on the truthful protected-rhythm routing slice. The
existing resolved upper-note velocity now has one bounded, anchor-only DSP
projection: it scales only the Alien Analog voice's existing additive filter
envelope lift and in-gate decay. The response is latched on an actual anchor
retrigger, inherited by legato slides and an active tail, and reset after the
voice becomes silent. Other upper roles remain neutral. Pitch, score onsets,
gates, oscillator fingerprint, structural spectral sculpture, resonance,
drive, send levels and routing, generated-graph plan and topology, protected
rhythm, and the one-button runtime are unchanged; the changed anchor signal
still flows through its existing sends and generated graph.

The renderer trace records requested and applied velocity for every upper note.
For each anchor retrigger, the reduced exact-dry-tap evidence records applied
velocity, applied spectral and decay scales, gain-normalized attack high-band
ratio, and in-gate tail-to-attack level. The analyzer validates a fixed input
prefix, rejects malformed geometry and non-finite metadata, and rebases
bar-local event coordinates into exact phrase sample coordinates. It does not
perform a counterfactual rerender or add work to the real-time callback.

Final local validation used Xcode 26.6 build 17F113 and Apple Swift 6.3.3:

- The exact final full suite passed: 83 tests in 207.620 seconds.
- The optimized release build passed in 2.27 seconds using the matched full
  Xcode SDK, isolated module caches, and the populated offline SwiftPM scratch
  path.
- `git diff --check` passed on the final tree.
- Two independent final re-reviews found no remaining P0-P2 issue after the
  bounded-input, malformed-geometry, phrase-coordinate, and Core-to-DSP routing
  regressions were added.

The evidence and qualification schemas advance with the new observation shape,
but policy remains `uncalibrated.v1` and qualification remains unavailable. No
controller threshold or candidate promotion uses these metrics. Current score
velocities sit mostly above the response's neutral midpoint, and resonant
anchors already have other velocity-sensitive treatment; matched-loudness
listening is therefore still required to judge the combined musical magnitude.
No physical-output smoke, route/interruption test, preparation-latency or peak-
memory measurement, or 60-minute recovery soak was performed for this
candidate.

## Versioned candidate-evaluation transaction — 2026-08-09

This candidate builds on `17984fd`. Quality-contract schema 3 now records one
bounded transaction across primary, alternate, conservative fallback, and the
single permitted home-timbre correction. Every retained attempt binds its
symbolic, hard-gate, full-mix, masking, stem, automatic-mix, graph, route,
incoming continuation, and pre/post upper-timbre evidence. Final commit
provenance separately binds the chosen transaction, selected sample hash,
outgoing render/DSP continuation, and finalized quality state. Typed streaming
fingerprints avoid materializing the large continuation buffers and check
cancellation at fixed chunks.

The shipping evaluator remains `uncalibrated.v1`: a healthy path renders the
primary exactly once, reports qualification unavailable, and performs no
general quality ranking. Test-only paired comparison proves the fixed attempt,
correction, selection, and fallback contracts without enabling that behavior in
the app. Route recovery carries exact stereo channel count, exact unrounded
sample rate, route generation, graph-transition ownership, and controller/
quality continuation. No analyzer, ranking, allocation, lock, logging, file or
network work was added to the audio callback.

Final local validation used Xcode 26.6 build 17F113 and Apple Swift 6.3.3:

- The exact final full suite passed: 98 tests in 227.953 seconds.
- The same-intention two-bar 44.1/48 kHz transaction regression passed in
  20.935 seconds. It preserved plan, selected slot, decision semantics, graph,
  attempt shape, and kick-controller direction while allowing route-dependent
  PCM hashes and exact measurements to differ.
- The corrected continuation-owner replay passed in 32.761 seconds, and the
  inner-scan cancellation regression passed in 4.910 seconds.
- The optimized release build passed in 42.49 seconds using the matched full
  Xcode SDK, isolated module caches, and the populated offline SwiftPM scratch
  path. A separate empty scratch path first attempted a dependency fetch and
  stopped at restricted DNS before compilation; it was not a source failure.
- `git diff --check` passed. Two independent final production audits found no
  remaining P0-P2 defect after the route, graph, continuation, decoder, and
  adversarial-provenance closures.

The transaction is evidence infrastructure, not professional-quality
promotion. Calibrated paired ranking remains disabled until phrase analysis is
streamed within measured bounds and cancellation latency, preparation latency,
and peak working memory are calibrated. Matched-loudness listening, physical-
output smoke, route/interruption hardware QA, and the 60-minute recovery soak
also remain pending.

## Score-owned groove-pulse physical articulation — 2026-08-09

This candidate builds on `7dc1008`. The existing weak-sixteenth groove-pulse
owner now resolves a bounded physical contact model in the canonical score:
relative strike zone, damping, and deterministic timbre microvariation. The
existing carrier projects only those three fields into its filter, click, noise,
and decay constants. At `middle / 0.5 / 0` the operation order and PCM remain
bit-exact with the prior renderer. The conservative candidate is required to use
that neutral point; onset, timing, intensity, event count, other voices, effects,
mixing, generated topology, and the one-button runtime are unchanged.

The exact rendering pass returns bounded per-event evidence, including the
requested articulation, dry-event sample hash, source level, spectral centroid,
and tail-to-attack relationship. The candidate vector retains a smaller versioned
record for every score bar, including explicit empty bars, and proves a one-to-one
match with the resolved groove-pulse events. This evidence changes provenance but
does not enter candidate selection or enable a calibrated policy. No extra render,
counterfactual signal, or real-time callback work was added.

Final local validation used Xcode 26.6 build 17F113 and Apple Swift 6.3.3:

- The exact final full suite passed: 102 tests in 213.157 seconds.
- Eight focused groove-pulse, protected-routing, preflight, and fingerprint
  regressions passed in 19.379 seconds, including the 192 kHz route bound and a
  synthetic non-neutral conservative fallback rejection.
- The optimized release build passed in 38.32 seconds using the matched full
  Xcode SDK, isolated module caches, and the populated offline SwiftPM scratch
  path.
- `git diff --check` passed. Independent final correctness and real-time/audio
  audits found no remaining P0-P2 defect in the production, evidence, tests, or
  normative documentation.

The quality-contract schema advances to 4, the candidate-vector schema to 2,
the typed plan-fingerprint domain to v2, and the canonical engine identity to
v2. Policy remains `uncalibrated.v1`, so qualification remains unavailable and
the new observations cannot promote a candidate. No matched-loudness listening,
physical-output smoke, route/interruption hardware test, preparation-latency or
peak-memory measurement, or 60-minute recovery soak was performed for this
candidate.
