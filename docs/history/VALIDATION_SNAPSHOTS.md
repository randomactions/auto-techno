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

## Score-owned internal instrument palette — 2026-08-09

This candidate integrates the exact `8c11a9d` main-line CI hardening with one
canonical, score-owned palette: three internal synthesis architectures, ten
recognizable home patches, four bounded semantic automation coordinates, and a
typed compatibility matrix for the existing effect stages. It adds no plug-in,
sample library, alternate renderer, selectable profile, graph family, track
quota, or user-facing control. The existing director resolves every assignment;
the one renderer dispatches it; conservative fallback stays inside the same
catalog.

Detached candidate evidence now records each bar's exact assignments and the
deterministic hash, event count, peak, RMS, and finite state of the dry
architecture-local PCM. The candidate-vector schema advances to 5, the typed
fingerprint domain to v6, the canonical engine identity to v6, and the quality
contract to schema 6. The policy remains `uncalibrated.v1`, so instrument
evidence is descriptive and cannot promote or rank a candidate.

Final local validation used Xcode 26.6 build 17F113 and Apple Swift 6.3.3 with
serialized SwiftPM execution and isolated module caches:

- Core, evidence, palette, runtime, qualification, and DSP tests passed: 83/83
  in 69.301 seconds.
- Autonomous preparation preflight passed: 21/21 in 491.475 seconds.
- Protected-routing regressions passed: 7/7 in 60.148 seconds.
- Upper-timbre integration passed on the exact combined head: 16/16 in 145.163
  seconds, including the
  lifetime-bounded atomic and dual-rate prepared-transaction tests.
- The exact combined-head optimized `AutoTechno` product build passed in 42.37
  seconds using the
  populated offline SwiftPM scratch path. A separate empty scratch path first
  stopped at restricted DNS before compilation; it was not a source failure.

The new synth and evidence work remains off the real-time callback, and the
protected foundation and rhythm fingerprints remain bit-exact under the routing
regressions. No matched-loudness listening session, exact-build app playback,
physical route/interruption smoke, preparation-latency or peak-memory budget,
or 60-minute hardware-output soak was completed. Automated professional-quality
qualification therefore remains unavailable, and no release-readiness or
sound-quality promotion is claimed by this snapshot.

## Pulse-echo return-drive implementation candidate — 2026-08-09

The current source candidate implements one bounded relationship inside the
canonical renderer. Score-owned `machineTexture` may drive the existing shared,
filtered pulse-echo return after its undriven feedback state is advanced and
before wet recombination. The driven sample cannot re-enter feedback. The slice
adds no graph, plug-in chain, onset, event density, user control, reusable
resample buffer, sample library, retained transformed source, or callback work.

Each full bar now produces reduced same-pass evidence for the authorized send:
bar/BPM/delay/render geometry, score and drive eligibility, bounded source and
applied amount, current-send RMS, exact pre-drive and post-drive hashes,
pre/post peak, RMS, and low-band RMS, difference RMS, and finite status. The
candidate-vector contract binds it to matching instrument pulse-echo access and
requires exact pre/post identity for a neutral path. Quality-contract schema 7,
candidate-vector schema 6, and canonical engine identity
`autotechno-canonical-engine.v7` identify this implementation candidate.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with serial,
isolated SwiftPM caches on the exact source candidate rebased on instrument-
palette base `e1e9fe99de5a3a1500b9eecf7521e172e135affb`:

- upper-timbre integration: 17/17 passed in 136.833 seconds;
- core and evidence: 84/84 passed in 67.553 seconds;
- autonomous preparation preflight: 21/21 passed in 466.457 seconds;
- protected-routing regressions: 7/7 passed in 59.081 seconds;
- optimized `AutoTechno` product build: passed in 49.86 seconds;
- independent exact-diff static audit: no remaining concrete P0-P2 finding;
- `git diff --check`: clean.

The local matrix establishes structural, signal, continuation, provenance,
protected-routing, and build integrity for this candidate. No matched-loudness
listening, exact-build app playback, physical route/interruption smoke,
preparation-latency or peak-memory budget, or hardware-output soak was completed.
Policy remains `uncalibrated.v1`, automated quality qualification remains
unavailable, and this snapshot makes no professional-quality or release-
readiness promotion.

## Score-owned breath harmonic timing cascade — 2026-08-09

This source candidate extends the canonical resolved upper-note score with one
bounded onset-timing capability. On eligible nonconservative breath bars, the
anchor remains on the sixteenth grid while existing shadow and response notes
delay by one-half and all of a deterministic 16-bar aperture, respectively.
The aperture is exactly zero at macro bars 0 and 15, reaches its maximum at bars
7 and 8, and never exceeds 0.12 sixteenth steps. Identity, major-break,
conservative, force-home, ineligible-chapter, and missing-role paths remain
exactly neutral. Pitch, velocity, duration, density, transport, protected
rhythm, and the one-button surface are unchanged.

The same render pass retains bounded per-bar score, render, and applied-gate
fingerprints plus separate shadow and response signal evidence. Applied gate
ends come from the renderer, so normal same-role voice stealing and bar-end
truncation remain truthful rather than score-predicted. The typed streaming
fingerprints avoid temporary JSON encoders in the cooperative preparation stack.
The candidate-vector schema advances to 7, the quality contract to schema 8,
the typed plan-fingerprint domain to v4, and the canonical engine identity to
`autotechno-canonical-engine.v8`. Policy remains `uncalibrated.v1`; this evidence
does not rank or promote a candidate.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
serial SwiftPM execution, matched SDKs, isolated module caches, and the populated
offline dependency scratch path:

- upper-timbre integration: 18/18 passed in 144.915 seconds;
- core, evidence, runtime, qualification, planning, and DSP: 87/87 passed in
  70.379 seconds;
- autonomous preparation preflight: 21/21 passed in 538.099 seconds;
- protected-routing regressions: 7/7 passed in 63.987 seconds;
- optimized `AutoTechno` product build: passed in 58.14 seconds;
- the formerly stack-sensitive atomic prepared-continuation regression passed
  independently in 16.387 seconds after the typed streaming fingerprint change.

The local matrix establishes deterministic score ownership, exact frame and
gate geometry, same-pass evidence binding, fallback and force-home neutrality,
continuation replay, protected-routing identity, cooperative-stack safety, and
optimized-build integrity. No matched-loudness listening, exact-build app
playback, physical route/interruption smoke, preparation-latency or peak-memory
budget, or hardware-output soak was completed. Automated professional-quality
qualification therefore remains unavailable, and this snapshot makes no
sound-quality or release-readiness promotion.

## Phrase-scale performance character grammar — 2026-08-09

This source candidate adds one score-owned conductor above the existing
instrument palette. Six deterministic phrase-scale characters coordinate the
existing narrative roles with bounded foundation behavior, kick grammar,
role-compatible patch assignment, and semantic automation. The character is
retained in two-entry continuation memory and may change only at a future phrase
boundary. Identity return and conservative fallback use Hypnotic Lock. The
pre-existing macro narrative remains the sole owner of supporting-role admission
and removal.

Seven foundation behaviors distinguish sparse Sub Pulse, repeating Monotone,
syncopated Point, post-kick Pump, Kick Tail, Tuned Percussive, and Absent
relationships. They resolve through the existing three synthesis architectures
and protected low-end route; no engine, renderer, graph, plug-in, user selector,
callback decision, sample capture, or resample buffer was added. Per-phrase
compatibility evidence binds the selected character and exact counts of
foundation-, role-, and rhythm-compatible bars. The typed plan-fingerprint
domain advances to v5 and the canonical engine identity to
`autotechno-canonical-engine.v9`; quality-contract schema 8 and candidate-vector
schema 7 remain current.

Final local validation used Xcode 26.6 (`17F113`) with matched SDKs, isolated
module caches, and serial SwiftPM execution on the source candidate rebased onto
source-12 commit `fb56950963b6639784dba0cd407edf607f3574ee`:

- the complete package matrix passed 137/137 tests in 837.801 seconds;
- the character-aware candidate provenance suite passed 13/13;
- the complete adaptive-session suite passed 23/23, including all six reachable
  characters and a deterministic 1,024-macro continuation journey;
- the canonical instrument-palette suite passed 7/7, including distinct finite
  PCM for Sub Pulse, Monotone, Point, and Pump;
- the exact spatial isolation, protected mono-rumble, conservative fallback,
  and 44.1/48 kHz transaction regressions passed independently after their
  fixtures preserved the explicit resolved character contract;
- hosted CI runs stopped with signal 10 at successively later prepared-product
  boundaries as the combined evidence payload grew; the lifetime-bounded
  workflow now preserves every assertion but starts a fresh test process at
  each heavy upper boundary while reusing one compiled build. On combined
  Professional Evidence v3 head `ffd8802`, all 19 upper tests passed locally
  across 14 processes without changing production source. The closed-hat
  fixture now also uses its explicit deterministic seed 1 and heap-boxes the
  large state/candidate payload in a non-inlined helper; its 8 kHz, 12 kHz, and
  tamper cases all passed with a deliberately reduced 2 MB process stack;
- the optimized `AutoTechno` product build passed in 94.95 seconds;
- `git diff --check` was clean before publication.

The local matrix establishes deterministic structural ownership,
score-to-render consequence, exact evidence/fingerprint binding, bounded
continuation, conservative fallback, protected routing, cross-rate controller
behavior, and optimized-build integrity. No matched-loudness listening,
exact-build app playback, physical route/interruption smoke, preparation-latency
or peak-memory budget, or hardware-output soak was completed. Policy remains
`uncalibrated.v1`, automated professional-quality qualification remains
unavailable, and this snapshot makes no sound-quality or release-readiness
promotion.

## Streaming Perceptual Evidence v3 — 2026-08-09

This source candidate replaces phrase-sized analysis copies and the prior
three-band centroid proxy with one bounded, rate-derived streaming evidence
path. The canonical report now carries deterministic FFT centroid and spread,
bandwidth, flatness, 85-percent rolloff, positive spectral flux, RMS-trajectory
change, BS.1770-5 loudness, and Annex 2 true peak. Loudness retains fixed
400-millisecond and 3-second rolling windows; the perceptual analyzer retains
one Hann window plus fixed FFT scratch. A 32-second programme envelope and a
6 MiB combined analysis-working-set ceiling fail closed instead of silently
growing with phrase duration.

Candidate-vector schema 8, quality-contract schema 9, Professional Evidence
bank schema 3, and canonical engine identity `autotechno-canonical-engine.v9`
identify the candidate. Non-finite evidence remains a structurally complete
rejected record, while hard gates and the report bank require finite evidence.
The immutable full-mix, perceptual, and complete prepared-product payloads use
bounded reference storage so the larger evidence record remains safe on Swift
cooperative worker stacks, including the older hosted Swift 6.1 compiler. Score
validation was split into non-inlined bounded helpers without changing its
accepted score language. Policy remains `uncalibrated.v1`.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs and isolated SwiftPM/module caches after rebasing onto the heavy-
product process-isolation base `e9f0a29`:

- exact-head full repository matrix: 146/146 passed in 329.982 seconds;
- exact-head upper-timbre integration after the route-rate test split: 19/19
  passed in 76.372 seconds;
- exact 8 kHz prepared product after immutable prepared-product boxing: 1/1
  passed in 2.840 seconds;
- pre-rebase focused candidate evaluation and qualification: 24/24 passed in
  3.295 seconds;
- pre-rebase focused streaming perceptual and BS.1770 reference bank: 15/15
  passed in 7.832 seconds;
- formerly stack-sensitive atomic prepared continuation: passed independently
  in 16.360 seconds;
- exact-head optimized `AutoTechno` product build: passed in 45.43 seconds;
- optimized synthetic 8-second/96 kHz fixed-memory fixture and 4-second
  spectral/loudness/true-peak chunk-parity fixture: 0.050 seconds each;
- `git diff --check`: clean.

The local matrix establishes deterministic chunk parity, independent DFT and
BS.1770 reference agreement, physical-rate normalization, explicit
cancellation and non-finite behavior, duration-independent working memory,
cooperative-stack safety, candidate/report provenance, canonical-renderer
integration, and optimized-build integrity. The synthetic timings are not a
representative canonical-journey latency budget. No calibrated profile,
adversarial promotion suite, matched-loudness listening, exact-build app
playback, physical route/interruption smoke, representative journey peak-memory
or cancellation budget, or hardware-output soak was completed. Automated
professional-quality qualification therefore remains unavailable, and this
snapshot makes no sound-quality or release-readiness promotion.

## Score-owned kick-syntax ambiguity — 2026-08-09

This candidate is based on mainline Professional Evidence v3 commit
`6d9841ff58c0d28db6d9c8e23c1e289b447c5f98`. It adds one canonical
energy-release relationship: an established kick remains grounded on macro bar
12, is withheld without moving any other event on bars 13 and 14, and returns
unchanged at step zero on recovery bar 15. The resolver requires exact incoming
paid debt, canonical pullback weak pulses and motif context, compatible
performance-character/foundation behavior, and the existing recovery marker.
Fallback and every ineligible path remain grounded.

The renderer streams exact detector and post-fader kick hashes and metrics from
detached preparation. Candidate-vector schema 9 binds those observations to the
per-bar score/render count and step mask, kick stem, automatic gain, weak-pulse
and instrument evidence, full/protected pass parity, and the typed plan identity.
Quality-contract schema 10, canonical engine v10, and typed plan-fingerprint
domain v6 identify the score, PCM, and wire-format change. Policy remains
`uncalibrated.v1` and selection evidence is unchanged.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated module caches, serial SwiftPM, and the same process
boundaries as `.github/workflows/swift.yml`:

- core and evidence: 103/103 passed in 118.913 seconds;
- preparation preflight: 21/21 passed in 520.560 seconds;
- protected routing: 7/7 passed in 69.724 seconds;
- split upper/prepared-product filters: 19/19 passed across 14 fresh test
  processes, including both closed-hat route rates, tamper rejection, paired
  selection/correction, cancellation, rejection isolation, cross-rate intent,
  and phrase-boundary continuation;
- Source 13's dedicated score/preflight/prepared-product suite: 3/3 passed;
- exact fingerprint and performance-character focused regressions passed;
- optimized `AutoTechno` product build: passed in 58.19 seconds;
- repeated independent static audit: no remaining P0-P2;
- `git diff --check`: clean before publication.

The local matrix establishes deterministic score ownership, exact non-kick
preservation, audible omission/restoration, score-to-render evidence,
continuation, bounded work, conservative fallback, and protected-route safety.
It does not include matched-loudness listening, exact-build app playback,
physical route/interruption smoke, representative journey latency/peak-memory
measurement, or hardware-output soak. Automated professional-quality
qualification remains unavailable, so this snapshot makes no sound-quality or
release-readiness promotion.

## Frozen professional-quality development calibration — 2026-08-10

The complete canonical journey was rendered sequentially at 44.1 and 48 kHz
from root seed 48,291. All seven checkpoints at both rates produced complete
Professional Evidence v3 observations. The frozen aggregate profile fingerprint
is `c52545b5641e6cfb`; its ten-case adversarial-suite fingerprint is
`2340017ec6c59440`. All 14 baseline observations passed independent metric,
rate-consistency, and trajectory bounds with no relationship failures; all ten
hard-gate, level, spectral, masking, phase, silence, foreign-rate, trajectory,
and rate-drift attacks were rejected.

The representative run exposed one truthful evidence defect before calibration:
a sub-`1e-5` but non-silent upper-tonal stem in 44.1 kHz major break reported
nonzero RMS/peak with zero active RMS/occupancy because the activity threshold
exceeded its peak. The detached analyzer now caps its threshold at the observed
peak, preserving PCM while making the aggregate stem tuple internally
consistent. The explicit two-rate harness then passed in 2,954.363 seconds.

This establishes an offline development regression policy, not professional
release readiness. The shipping evaluator remains `uncalibrated.v1`, paired
selection remains disabled, and matched-loudness listening, exact-build app
playback, physical route/interruption smoke, representative latency/peak-memory
budgets, and hardware-output soak remain separate gates.

## Score-owned gated percussion texture — 2026-08-12

This candidate is based on frozen-development-calibration mainline commit
`621127928dbcafeff9343e954bb62e7726c7ce23`. It adds one score-owned relation to
the existing percussion role: an eligible early event admits one sixteenth of
dry percussion into a bar-local delay, while a later four-sixteenth output gate
reveals only the bounded return. The score adds no event, the renderer captures
no reusable loop, and no delay state crosses the bar. Conservative fallback and
every ineligible bar remain exact neutral.

Same-pass evidence binds every bar's canonical source-step mask, input/output
gate geometry, route-derived frame counts, exact source/return hashes, peak/RMS,
nonzero counts, exact-zero endpoints, and full/protected pass parity. Candidate-
vector schema 10, quality-contract schema 11, canonical engine v11, and typed
plan-fingerprint domain v7 identify the score, PCM, and wire-format change.
Shipping policy remains `uncalibrated.v1` and selection evidence is unchanged.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, serial SwiftPM, and the process boundaries in the workflow:

- core and evidence: 115/115 passed in 138.116 seconds;
- preparation preflight: 22/22 passed in 510.545 seconds;
- protected routing: 7/7 passed in 70.987 seconds;
- split upper/prepared-product filters: 19/19 passed across fresh processes;
- Source 14's dedicated score/render/preflight/prepared-product suite: 4/4
  passed;
- after static review hardened decoded step and mask totality, the focused
  compact-evidence regression passed 1/1 after a 33.62-second incremental build;
- the complete representative engine-v11 journey at 44.1 and 48 kHz produced
  14/14 accepted observations. The frozen engine-v10 development policy
  accepted that bank, the regenerated profile fingerprint was
  `6b197f480e0a48e7`, and all ten regenerated adversarial cases were rejected
  under suite fingerprint `2383c240556fa4c7`. The explicit run passed in
  3,037.339 seconds;
- the final optimized `AutoTechno` product build passed in 38.60 seconds;
- `git diff --check` was clean before publication.

The stable musical concept and provisional renderer are recorded separately.
Future DSP may replace interpolation, filter topology, feedback colour, stereo
placement, diffusion, and smoothing under a new version, but must preserve the
same score-owned gates, bounded tail, block-partition-independent replay,
neutral fallback, protected routing, and truthful evidence. This snapshot does
not include matched-loudness listening, exact-build app playback, physical
route/interruption smoke, representative latency/peak-memory measurement, or
hardware-output soak. It makes no shipping professional-quality or release-
readiness promotion.

## Score-owned Resonant Mono spectral relation — 2026-08-12

This source candidate is based on score-owned gated-percussion mainline commit
`6276c1514acf27c58e976fefb39ad5329b93f299`. It gives the existing Resonant
Mono acid patches one durable spectral relation: `acidThread` requests an
ordered-hollow operator relation and `acidSequence` requests metallic tension.
The renderer applies one bounded dark-to-bright-to-dark phase-modulation delta
inside the existing notes. It adds no sequencer, note, transport state, graph,
plug-in dependency, user control, or callback work; non-acid and protected
foundation assignments retain the exact zero-operator path.

Same-pass evidence binds every acid assignment and rendered event to its
relation, ratio, requested/applied peak index, event fingerprint, exact operator
hash, peak/RMS/crest, low-band ratio, and finite/binding facts. Candidate-vector
schema 11, quality-contract schema 12, and canonical engine v12 identify the
wire-format and PCM change. Typed plan-fingerprint domain v7 is unchanged
because the resolved score shape is unchanged. Shipping policy remains
`uncalibrated.v1` and selection evidence is unchanged.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated caches, serial SwiftPM, and workflow process boundaries:

- core and evidence, preparation preflight, protected routing, and split
  upper/prepared-product groups passed 166/166 tests;
- the focused physical operator contract passed at 8, 44.1, 48, and 192 kHz;
- the optimized `AutoTechno` product build passed;
- the first representative qualification rejected the stronger provisional
  `0.20`/`0.26` blend. All 14 new engine-v12 observations and all ten new
  adversarial cases were internally valid, but the frozen engine-v10 policy
  rejected establishment-to-long-continuation RMS-trajectory peak deltas of
  `-0.7283363585980993` at 44.1 kHz and `0.27771743820419914` at 48 kHz against
  its required `0.7080972110974386...6.921980443312073` interval;
- after reducing only the renderer-owned operator blend to `0.05`/`0.065`, the
  complete two-rate rerun accepted all 14 observations under the unchanged
  frozen policy. The regenerated engine-v12 profile fingerprint was
  `374bf5cdfe333f89`, all ten adversarial attacks were rejected under suite
  fingerprint `665feb5625ad608f`, and the exact test passed in 3,043.276 seconds;
- `git diff --check` was clean before publication.

The durable concept and provisional realization are deliberately separate.
Later serious DSP may replace the exact ratio table, index mapping, anti-alias
strategy, high-pass topology, wet blend, operator count, envelope, nonlinear
feedback, or stereo realization, but it must preserve the score-owned semantic
relation, neutral protected fallback, deterministic replay, truthful replacement
evidence, and explicit version advancement. This snapshot does not include
matched-loudness listening, exact-build app playback, physical route or
interruption smoke, representative latency/peak-memory measurement, or hardware
output soak. It makes no shipping professional-quality or release-readiness
promotion.

## Source 16 effect-sentence consolidation — 2026-08-12

Source 16 produced no PCM, schema, engine, plan-fingerprint, continuation, graph,
or policy change. Static reconciliation found that the single canonical runtime
already owns its durable call/response/turnaround idea through motif, response,
transition, narrative, echo, reverb, pulse-return, gated-return, and structural
gesture contracts. Adding another phrase state or effect chain would duplicate
those owners without a new objective deficit.

The repository instead adds `docs/SOUND_CONCEPT_MATURITY.md`, a concise register
that separates durable musical intentions from current replaceable DSP, names
the existing evidence/fallback boundary, and records the richer serious-DSP
direction that may later replace each implementation. `RepositorySurfaceTests`
requires the register's four-part contract and roadmap link so this maturation
boundary cannot disappear silently.

Validation for this documentation-and-contract slice used Xcode 26.6 (`17F113`)
and Apple Swift 6.3.3 with matched SDKs, the existing isolated Source 15 caches,
serial SwiftPM, and the workflow's core/evidence filter:

- the focused maturity-register contract passed 1/1;
- the complete core/evidence partition passed 119/119 in 152.176 seconds,
  including the canonical session, existing effect-return/gated-delay owners,
  candidate transactions, calibration fixtures, and repository surface;
- the optimized `AutoTechno` product build passed in 48.24 seconds;
- all new relative Markdown links resolved, no retained source/test/doc text
  contains the excluded personal creator name, and `git diff --check` passed.

Since no production source or PCM changes, the frozen professional-quality
profile was not regenerated. No listening, app/route validation, interruption
smoke, latency/peak-memory run, or hardware soak is claimed, and shipping
selection remains `uncalibrated.v1`.

## Rising adjacent-cluster transition — 2026-08-12

This candidate is based on source-16 concept-register mainline commit
`164f325c83eb7a5df2db5dde7b4d37c3b40a0b79`. It gives only the existing
Metal Veil transition one durable rising adjacent-cluster relation. The
existing transition onset, duration, trajectory, patch, effects, and density
remain score-owned; response and atmosphere uses stay on their legacy path and
the conservative Dark Chord transition remains neutral.

Detached rendering binds each eligible transition to exact component ratios,
applied upward-frequency geometry, event identity, and an isolated dry cluster
hash/peak/RMS/crest record. Candidate-vector schema 12, quality-contract schema
13, and canonical engine v13 identify the PCM and wire-format change. Typed
plan-fingerprint domain v7 remains unchanged because the resolved plan shape is
unchanged; shipping policy remains `uncalibrated.v1` and selection evidence is
unchanged.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated module caches, serial SwiftPM, and workflow process
boundaries:

- focused source-17 DSP/evidence/reachability and exact fingerprints: 4/4;
- core and evidence: 122/122 passed in 159.697 seconds;
- split upper/prepared-product filters: 19/19 passed across fresh processes;
- preparation preflight: 22/22 passed in 501.640 seconds;
- protected routing: 7/7 passed in 68.933 seconds;
- optimized `AutoTechno` product build: passed in 39.16 seconds;
- complete representative 44.1/48 kHz journey: 14/14 observations accepted
  under the unchanged frozen engine-v10 policy, regenerated engine-v13 profile
  fingerprint `2b884831d682f6d9`, and all ten adversarial attacks rejected under
  suite fingerprint `cc753a8f5161fbb3`; the explicit run passed in 2,957.112
  seconds;
- `git diff --check`: clean before publication.

The durable concept and provisional realization are recorded separately in
`docs/SOUND_CONCEPT_MATURITY.md`. This snapshot does not include matched-
loudness listening, exact-build app playback, physical route/interruption
smoke, representative latency/peak-memory measurement, or hardware-output
soak. It makes no shipping professional-quality or release-readiness promotion.

## Release-boundary tonal-envelope expansion — 2026-08-12

This candidate is based on the published rising-cluster mainline commit
`cad70e41e7662228108944ee7f02948daf78d807`. It gives only the final eligible
Tonal Motion anchor at the existing paid energy-release marker one durable
`sustainedWash` relation. The score retains the same onset, pitch, duration,
velocity, gate, assignment, effects, density, and transport; conservative
fallback and forced-home correction remain exact neutral.

Detached rendering applies a bounded provisional sustain/release realization
and retains exact score-to-schedule identity plus an isolated expansion-stem
hash, peak/RMS, attack/tail ratio, nonzero count, binding, and finiteness.
Candidate-vector schema 13, quality-contract schema 14, canonical engine v14,
and typed plan-fingerprint domain v8 identify the score, PCM, continuation, and
wire-format change. Shipping selection stays `uncalibrated.v1`.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated caches, serial execution, and the workflow's exact
process boundaries:

- focused score/DSP/evidence and exact-fingerprint checks: 5/5;
- split upper/prepared-product/transaction filters: 19/19;
- core and evidence: 125/125 passed in 161.471 seconds;
- preparation preflight: 22/22 passed in 499.981 seconds;
- protected routing: 7/7 passed in 67.896 seconds;
- complete CI-selected matrix: 173/173;
- fresh optimized `AutoTechno` product build: passed in 58.77 seconds;
- `git diff --check`: clean before publication.

The frozen development profile and ten-case adversarial contract passed their
normal tests, but the opt-in complete 128-phrase journey generator was not run
and no profile artifact was regenerated. The durable concept and provisional
DSP are separated in `docs/SOUND_CONCEPT_MATURITY.md`. This snapshot does not
claim matched-loudness listening, exact-build app playback, route/interruption
smoke, representative latency or peak memory, hardware soak, shipping
professional-quality qualification, or release readiness. Exact-head remote CI
remains a separate publication gate.

## Foreground lead-performance timing — 2026-08-12

Source 19 adds one explicit `leadPerformance` relation to the existing
score-owned upper-timing mechanism. Only a naturally eligible nonconservative
melodic lock can delay later retriggered anchors; the first anchor, all harmonic
companions, atmosphere/transition protection, drums, transport, pitch, gate
duration, velocity, assignment, and effects remain unchanged. Conservative and
force-home paths are exact aligned.

Candidate-vector schema 14, quality-contract schema 15, canonical engine v15,
and typed plan-fingerprint domain v9 bind the relation, character, exact anchor
offset-pattern fingerprint, actual onset/applied-gate outcomes, and isolated
anchor signal consequence. Shipping policy remains `uncalibrated.v1`.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated caches, serial execution, and the workflow's exact
process boundaries:

- focused score/DSP/evidence, natural prepared-product, and exact-fingerprint
  checks: 4/4;
- split upper/prepared-product/transaction filters: 19/19;
- core and evidence: 125/125 passed in 183.735 seconds;
- preparation preflight: 22/22 passed in 506.160 seconds;
- protected routing: 7/7 passed in 70.710 seconds;
- complete CI-selected matrix: 173/173;
- fresh optimized `AutoTechno` product build: passed in 61.82 seconds;
- `git diff --check`: clean before publication.

This proves natural director reachability, a real complete prepared primary
transaction, same-bar active-versus-neutral causal locality, representative-
rate frame geometry, deterministic JSON round-trip, and forged-pattern
rejection. The first fresh release-build invocation could not resolve GitHub
inside the restricted sandbox; after explicitly authorized dependency access,
the pinned SwiftPM dependencies resolved and the release product built. No
listening, app/route smoke, latency/peak-memory measurement, hardware soak,
professional-quality promotion, or release-readiness claim is made. Exact-head
remote CI remains a separate publication gate.

## Dramatic-debt climax provenance — 2026-08-12

Source 20 adds one compact long-form causal record to the existing kick-syntax
transaction. It fingerprints the exact contrast or major-break debts paid by a
nonconservative energy release and cross-checks their grounded setup, two
withheld bars, and macro-marker recovery. It adds no score event, PCM, renderer,
transport, controller, or callback work; debt-free, conservative, fallback, and
non-release candidates remain inactive.

Candidate-vector schema 15, quality-contract schema 16, and canonical engine v16
identify the wire-format change. Focused tests passed for deterministic debt
fingerprints, source accounting, geometry/identity tamper rejection, unchanged
selection evidence, and a real complete prepared primary recovery transaction.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated caches, serial execution, and the workflow's exact
process boundaries:

- focused climax-arc contract and natural prepared-product checks: 2/2;
- split upper/prepared-product/transaction filters: 19/19;
- core and evidence: 126/126 passed in 181.859 seconds;
- preparation preflight: 22/22 passed in 502.048 seconds;
- protected routing: 7/7 passed in 69.592 seconds;
- complete CI-selected matrix: 174/174;
- optimized `AutoTechno` product build: passed in 51.72 seconds;
- `git diff --check`: clean before publication.

Shipping selection remains `uncalibrated.v1`; no listening, app/route smoke,
latency or peak-memory measurement, hardware soak, professional-quality
promotion, or release-readiness claim is made. Publication and exact-head
remote CI remain separate gates.

## Unified phrase composition — 2026-08-12

This candidate adds one score-owned phrase-composition layer to the existing
director, resolved score, synth plan, and detached renderer. It provides true
phrase-local resampling of exact app-owned percussion or kick PCM, complete
8/16-step modal arpeggiator score geometry, a fixed four-voice pad renderer, and
minimal-motion harmonic continuation across accepted phrase boundaries. Tone
chapters and structural release markers retain their established spectral and
sustained-wash ownership. Conservative, identity-return, and force-home paths
remain neutral. No renderer-side sequencer, sample library, cross-bar PCM cache,
new runtime, callback work, or user-facing control was added.

Candidate-vector schema 16, quality-contract schema 17, canonical engine v17,
typed plan-fingerprint domain v10, render-state domain v3, and render/DSP
continuation domain v3 bind the new plan, source kind, slice/pad PCM consequence,
arpeggiator geometry, and harmonic continuation. Shipping policy remains
`uncalibrated.v1`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with matched
SDKs, isolated caches, serial execution, and separate heavy test processes:

- unified phrase-composition score/DSP/reachability: 9/9;
- candidate provenance plus phrase composition: 27/27;
- core and evidence CI group: 135/135 passed in 194.812 seconds;
- upper integration: 19/19 passed in 150.765 seconds;
- preparation preflight: 22/22 passed in 515.225 seconds;
- protected routing: 7/7 passed in 73.420 seconds;
- fresh optimized `AutoTechno` product build: passed in 67.25 seconds;
- `git diff --check`: clean before publication.

The release linker emitted non-fatal missing module-cache debug-reference
warnings from the isolated SwiftPM build path; the product linked successfully.
This snapshot proves deterministic causal reachability and bounded engineering
contracts, not listening quality. No exact-build app/route smoke, physical-output
soak, calibrated quality promotion, or release-readiness claim is made.
Publication and exact-head remote CI remain separate gates.

## Canonical FDN spatial engine — 2026-08-13

This candidate replaces the canonical renderer's former single 12–20 second
mono late-delay buffer with one eight-line stereo feedback delay network. The
existing score remains the owner of spatial depth, carrier, send, filtering,
phrase boundary, and fallback. Scene intent resolves bounded room scale, RT60,
damping, synth/percussion sends, and wet gain before detached rendering. The
same continuing FDN state is retained across identity return while that
score-owned home boundary applies a 0.45 audible-return scale. Kick and
foundation remain outside the field; no alternate renderer, callback work,
plug-in surface, or user control was added.

Candidate-vector schema 17, quality-contract schema 18, and canonical engine
v18 bind one complete spatial-FDN record to every rendered bar. The record
retains route-derived delay geometry, strictly sub-unity feedback, score
identity, exact input/stereo-wet hashes, levels, correlation, activity, onset,
binding, and finiteness. Shipping selection remains `uncalibrated.v1`, and this
evidence remains selection-neutral.

The frozen engine-v10 profile was not changed or regenerated. A complete
44.1/48 kHz journey comparison accepted the same 8/14 observations as the
current-main baseline: establishment, chapter change, contrast, and identity
return at both rates. The new bank's self-profile was complete and qualified
(`b41f0fcd6cc5d252`), and its adversarial suite passed
(`08b4b3532a6f86da`). This is compatibility evidence against a deliberately old
frozen profile, not shipping quality promotion.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with matched
SDKs, isolated caches, serial execution, and the workflow's exact process
boundaries:

- focused FDN, candidate, quality, and protected-routing contracts: 42/42;
- complete two-rate frozen/self-profile/adversarial comparison: passed;
- core and evidence CI group: 141/141 passed;
- preparation preflight: 22/22 passed;
- protected routing: 7/7 passed;
- split upper/prepared-product/transaction gates: 19/19 passed;
- complete CI-selected matrix: 189/189;
- optimized `AutoTechno` product build: passed in 62.24 seconds;
- `git diff --check`: clean before publication.

The release linker emitted non-fatal missing module-cache debug-reference
warnings from the reused isolated SwiftPM build path; the optimized product
linked successfully. This snapshot proves deterministic DSP bounds, truthful
score-to-PCM evidence, protected low-end identity, rate compatibility, and
offline qualification behavior. Exact-build app playback, listening/taste,
route/interruption recovery, representative preparation latency and peak
memory, and physical-output soak remain separate gates. Publication and
exact-head remote CI remain separate gates.

## Bounded paired-selection readiness — 2026-08-15

This candidate adds a deterministic numeric-storage budget and an opt-in
optimized operational probe around the existing detached candidate transaction.
It adds no score, renderer, PCM, runtime evaluator, callback work, profile,
selector, or alternate engine. Shipping selection remains
`uncalibrated.v1`: the healthy app still renders one primary candidate and
reports professional qualification unavailable.

Three optimized maximum-size iterations per representative rate rendered both
the healthy primary/alternate path and the full primary/alternate/correction/
fallback path. Healthy worst latency was 6.372 seconds at 44.1 kHz and 6.873
seconds at 48 kHz. Four-pass worst latency was 12.247/13.357 seconds,
post-comparison cancellation was 0.014...0.032 ms, maximum RSS was 80,461,824
bytes, and the conservative numeric-storage estimate was 113,161,984 bytes
under a 128 MiB ceiling. This proves the generic transaction envelope only; it
does not install or qualify the exact shipping comparator.

Validation also reproduced a pre-existing `e979529` debug-test stack overflow
in the score-owned kick preflight. The crash report placed the failure in the
upper-timing evidence constructor on Swift Testing's cooperative worker. A
semantics-preserving decomposition retained the same score/render fingerprints,
gate facts, role counts, finite checks, and spatial-FDN bindings while reducing
the single-bar upper-timing constructor's debug stack frame from 581,632 bytes
to 5,168 bytes. The exact formerly crashing suite then passed 3/3.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with matched
SDKs, isolated caches, serial execution, and separate heavy test processes:

- paired transaction/cancellation/correction/rate/readiness filters: 7/7;
- core and evidence CI group: 146/146 passed in 233.710 seconds;
- preparation preflight: 22/22 passed in 634.023 seconds;
- protected routing: 7/7 passed in 97.973 seconds;
- optimized operational probe: passed at both representative rates;
- optimized `AutoTechno` product build: passed in 67.58 seconds;
- `git diff --check`: clean before publication.

This snapshot records operational readiness and deterministic engineering
contracts, not professional sound quality or runtime promotion. Exact shipping-
evaluator replay, exact-build app playback, physical route/interruption smoke,
sustained hardware soak, publication, and exact-head remote CI remain separate
gates.

## Exact-engine paired candidate policy — 2026-08-15

This candidate adds the dormant exact-engine judge required by the preceding
bounded transaction. It centralizes canonical checkpoint ownership in Core,
projects each complete candidate into the same 39-metric Professional Evidence
v3 observation, preserves independent verdicts for candidates representing more
than one checkpoint, and records an explicit conservative-fallback comparison
when neither authored candidate passes. The selector and transaction validator
now preserve and replay that result instead of flattening it to unavailable.

The immutable paired resources identify canonical engine v19, profile
`ffc8be201e9b8564`, and adversarial suite `556508db468b3a64`. The optimized
calibration source contained 14 observations: seven checkpoints at both 44.1
and 48 kHz. It self-qualified 14/14 and the suite rejected all 10 adversarial
cases for their expected non-compensable reason. The retained engine-v10 profile
accepted only 8/14 v19 observations, confirming it remains a historical
compatibility artifact rather than a silent shipping selector.

The app-facing overload remains `uncalibrated.v1`, so this candidate adds no
render pass, callback work, selection change, or PCM change. Current-profile
loading and fast policy tests are part of normal CI; full artifact generation
remains opt-in. Local serial validation on Xcode 26.6 and Apple Swift 6.3.3
passed the 151-test core/evidence group in 229.771 seconds, 22/22 preparation
preflight tests in 629.048 seconds, 7/7 protected-routing tests in 98.107
seconds, the final 42-test candidate/calibration/quality set in 5.208 seconds,
and the optimized `AutoTechno` product build in 41.10 seconds.

Publication, exact-head CI, exact-build app launch, explicit
shipping activation, exact-evaluator resource probing, route/interruption smoke,
listening, and hardware soak remain separate gates.

## Exact paired-evaluator operational envelope — 2026-08-15

This candidate adds a preloaded, route-local wrapper around the dormant v19
paired evaluator. It requests a pair only after primary evidence maps to an
applicable calibrated checkpoint. Missing artifacts and unsupported rates retain
the uncalibrated evaluator identity and single-primary behavior. A calibrated
conservative fallback may cross the atomic commit boundary only when hard gates
pass and the transaction actually selected the score-owned fallback slot. The
app-facing overload remains uncalibrated, so this candidate changes no shipping
selection, PCM, callback work, UI, or runtime mode.

An opt-in release probe loaded immutable artifacts before timing and replayed
three exact maximum 16-bar transactions at 44.1 and 48 kHz. Worst latency was
9.549/10.448 seconds, post-comparison cancellation was 0.042...0.048 ms,
maximum RSS was 81,559,552 bytes, and every transaction was complete,
deterministic, and commit-eligible through its hard-safe fallback. The
unsupported-rate test rendered only one primary and retained uncalibrated
provenance.

The operational envelope passed, but the quality activation gate failed. At
both rates the unseen primary missed establishment bounds for bar centroid span,
bar crest-factor span, maximum boundary delta, and phrase-wide RMS trajectory
peak. The alternate missed maximum boundary delta and RMS trajectory peak at
both rates, plus spectral rolloff at 48 kHz. The current profile comes from one
seed journey (`48291`); the result is recorded as insufficient generalization,
not addressed by silently widening its individual metric bounds. Diverse
canonical calibration journeys and independent holdouts remain required before
any explicitly authorized shipping activation.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and the workflow's serial process boundaries:

- exact optimized evaluator envelope: 1/1 in 73.493 seconds;
- workflow upper/transaction/rate/readiness partitions: 21/21;
- core and evidence matrix: 153/153 in 233.104 seconds;
- preparation preflight: 22/22 in 628.449 seconds;
- protected routing: 7/7 in 97.829 seconds;
- optimized `AutoTechno` product build: passed in 60.14 seconds;
- `git diff --check`: clean before publication.

Publication, exact-head remote CI, exact-build app launch, listening,
route/interruption smoke, and hardware soak remained separate gates.

## Diverse professional-quality profile and holdout — 2026-08-15

This candidate replaces the retired single-journey engine-v19 paired resources
with Professional Evidence v4 artifacts derived from 28 complete canonical
journeys at every checkpoint and both 44.1 and 48 kHz. Profile
`4b55055d1904ead8` self-accepted all 392 calibration observations and every
phrase/rate relationship. Adversarial suite `a34c3ba6acec9c2e` rejected all ten
attacks for their expected non-compensable reason. Source-disjoint holdout
qualification `c333586ce068d5af` accepted 56/56 observations from four complete
replacement journeys with zero relationship failures.

The holdout process failed closed twice before producing those resources. The
first 24-journey profile accepted every local holdout observation but found four
relationship failures: one masking trajectory and three rate-sensitive
transient/crest relationships. Those journeys became development evidence; a
new untouched cohort then exposed one release phrase whose short-term gated
loudness-range percentile differed by 12.16 LU across rates while integrated,
momentary, and short-term maxima stayed aligned. The source analyzer already
documented EBU-style LRA as descriptive for this use. The evaluator now honors
that contract: LRA remains recorded but does not act as a local, trajectory, or
rate gate. Discrete transient density also carries its exact one-event-per-bar
resolution at fixed 130 BPM. No failed holdout was relabeled as passing proof.

Streaming spectral evidence now uses a physical-duration analysis window at
each route rate and zero-pads to the next radix-two FFT, instead of letting FFT
rounding change the analyzed duration. The transient envelope coefficient is
normalized from its 48 kHz physical time constant. Safety-oriented peak, DC,
boundary, and masking bounds accept improvements below calibration while still
rejecting regressions. These changes affect detached evidence and offline
qualification only; they add no callback work and do not change PCM.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and the workflow's serial process boundaries:

- frozen artifact, corpus, adversarial, and holdout contracts: 14/14;
- explicit optimized 28-development/4-holdout generation: passed;
- split upper/route/transaction/rate/readiness partitions: 21/21;
- core and evidence matrix: 158/158 in 243.294 seconds;
- preparation preflight: 22/22 in 638.052 seconds;
- protected routing: 7/7 in 97.712 seconds;
- complete CI-selected matrix: 208/208;
- clean optimized `AutoTechno` product build: passed in 75.29 seconds;
- `git diff --check`: clean before publication.

The report bank still reports policy unavailable and the app-facing overload
still installs `uncalibrated.v1`, rendering one healthy primary. This snapshot
proves offline artifact generalization and deterministic engineering contracts,
not shipping activation, listening quality, app/route smoke, interruption
recovery, or sustained hardware soak. Publication, exact-head remote CI, and
exact-build app launch remain separate gates.

## Modal percussion Stage 1 qualification artifacts — 2026-08-16

The canonical tuned-percussive foundation now resolves score-owned modal pitch
and bounded material articulation into one deterministic six-mode resonator with
four fixed continuation slots. It replaces the root-only foundation realization
in place. Candidate schema 19 and Professional Evidence v5 require complete
empty/active bar coverage, exact score/event and state binding, dry PCM identity,
protected/full pass equality, route validity, pitch, attack/body/tail,
spectral-centroid, masking, pole-stability, and representative-rate evidence.
Quality-contract schema 21 and canonical engine v20 feed those facts into the
single non-compensable primary policy.

Qualification artifacts were regenerated twice from separate empty trajectory
caches over 28 development and 4 disjoint holdout journeys at 44.1 and 48 kHz.
Both runs accepted 392/392 development observations, rejected all fourteen
adversarial attacks for their expected reason, and accepted 56/56 holdout
observations with zero relationship failures. Both runs produced the same
semantic identities:

- profile: `33592f06e3c86a77`;
- adversarial suite: `15ae673a07bc6cd0`;
- holdout qualification: `dbe3ba28fa1a1956`.

The corresponding JSON SHA-256 values were byte-identical across both runs:

- profile: `ebe98a7dda4f6f575158e5ad1f45f741d350992421024f75220856d0c3480879`;
- adversarial suite: `cdad2414faac9f579dbf4809592d297aaae2c217606761a57c027b5b7479290f`;
- holdout qualification: `87fae59b0805979b63c331b41f0d5a472dd6a258c631ab02e6a609ca27066c02`.

Evidence states at this snapshot boundary:

- implemented: complete;
- focused local verification: complete, including 28/28 artifact readiness;
- full local verification: pending;
- qualification artifacts: complete and byte-reproducible;
- published exact SHA: pending;
- exact-head CI: pending;
- release app launched: pending;
- app/route QA: pending;
- listening observation: pending;
- physical-output soak: pending.

Artifact qualification does not prove app launch, hardware-route recovery,
subjective listening quality, or physical-output stability. Those remain
separate evidence states.
