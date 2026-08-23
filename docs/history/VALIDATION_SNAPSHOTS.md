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

## Canonical scheduled-output feedback and v3 primary artifacts — 2026-08-17

The seventh architectural stage closes one bounded master-headroom loop on the
same canonical runtime. The main-mixer callback copies only app-owned native-
stereo PCM into a 256-slot C11 atomic queue with a 1,024-frame packet maximum.
An authenticated occurrence ledger and exact two-probe mixer/player clock map
allow a detached worker to assemble the first three seconds of a scheduled
phrase. The worker reuses the canonical BS.1770-5 and Annex 2 analyzers and the
installed profile; only the resulting reduced proposal crosses into future
preparation.

The controller is attenuation-only within `-3...0 dB`, attacks by no more than
`0.25 dB` per accepted phrase, and recovers by `0.125 dB` only after two complete
clean windows. One authenticated scheduled occurrence may invalidate one
unscheduled successor; repeating a phrase at a newer range is a distinct
occurrence. The proposal becomes durable only when fresh candidate evidence and
terminal trim proof pass the one primary evaluator and atomic commit.
Late evidence alone is ignored or deferred and cannot latch the hold. An
authorized correction that is missed, unavailable, or rejected does latch the
accepted-PCM hold; it does not request an untrimmed substitute. Route and
timeline resets preserve that hold and may latch an outstanding authorization.
A newer authenticated occurrence may propose recovery but does not itself clear
the hold; a successful corrected boundary, complete session reset, or shutdown
does.

Exact replay identity binds packet count, first/last packet sequence, counters,
ranges, and the other recorded capture-provenance fields. Alternate valid
packetization of identical contiguous PCM may preserve its PCM fingerprint,
BS.1770 measurements, and
numeric controller outcome, but it changes the evidence and proposal
fingerprints.

Artifact cutover commit `6ac044f4036c662009b67a2314d3b780ff97e448`
advanced the canonical engine to v21, quality contract to schema 22, candidate
vector to schema 20, candidate transaction to schema 4, Professional Evidence
to v6, profile to v3, adversarial suite to schema/family 4/v4, and holdout to
schema 2. The repository ships only these artifact identities:

- profile: `bf5c1ea3c61aef86`, JSON SHA-256
  `3cff443f74ebd5d2b84599492451b4005703a6255cc94fec4d5c8931d89d7106`;
- adversarial suite: `6301de3109373591`, JSON SHA-256
  `3cbaea77eb7552b5e21a0a886fefe331b67211f4bdcda0c013e23756e88970b8`;
- holdout qualification: `87283519c0c86cd4`, JSON SHA-256
  `28094391d31044d9954a547fb04a1e096a3b5533f997d8d2023826d9bab2efd5`.

The v3 profile accepted all 392 development observations from 28 complete
journeys at 44.1 and 48 kHz. The v4 suite retains 23 non-compensable cases and
two live baseline observations. The four source-disjoint holdout journeys
accepted 56/56 observations with zero relationship failures.

Evidence states at this snapshot boundary:

- implementation: complete;
- deterministic queue, analyzer, controller, candidate, scheduling, lifecycle,
  and primary-artifact validation: complete in focused local suites;
- exact-head full local matrix and release build: pending Task 13;
- publication and exact-head remote CI: pending Task 14;
- release app launch: pending Task 14;
- app transport and physical route/interruption QA: pending;
- listening observation: pending;
- 60-minute physical-output and recovery soak: pending.

The automated artifacts and replay do not establish physical-output behavior,
subjective professional quality, interruption recovery, or hardware stability.
Those remain separate release evidence.

## Source 21 upper-percussion tail clearance — 2026-08-18

Source 21 extends the existing clap, open-hat, and metallic events with one
post-arbitration score role: natural body or foreground clearance. A supporting
event keeps its first 8 ms exact, then follows a bounded state-free release to a
`0.25` terminal multiplier. Featured percussion, intentional pileups, and
identity return remain bit-exact neutral. The slice adds no track, sample source,
instrument, effect return, continuation buffer, callback work, or user control.

The score-to-render contract retains one compact record per bar and at most four
event records. It binds event identity, role, route/frame geometry, attack and
full hashes, peak/RMS, attack and tail RMS, tail-to-attack dB, difference RMS,
finiteness, and protected/full pass equality. Professional Evidence v7 adds the
clearance-event ratio and rendered tail-to-attack mean as non-compensable
metrics. A dedicated adversarial case rejects a runaway clearance tail.

The exact Professional Evidence v7 artifact generation used 28 development
journeys and four source-disjoint holdout journeys at 44.1 and 48 kHz. It
accepted 392/392 development observations, rejected every one of 24 adversarial
cases for its expected reason, and accepted 56/56 holdout observations with zero
relationship failures. The shipping v4 artifact identities are:

- profile: `4f7a91a51691f923`, JSON SHA-256
  `2434ef7785fad081adc89871d1df15f5ce7aaf15679cb16a926e9fb92d926e82`;
- adversarial suite: `4c75434aa7d3866f`, JSON SHA-256
  `21f3679690998fb200da140f05cc3f3daeb05d556e965dde25f8bca64b0fe0e9`;
- holdout qualification: `97be23f446c25611`, JSON SHA-256
  `5cf85daf07a6b5eb53e6c99cada3509899d7ef81daf092d297cc71a3d1e27fbd`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
isolated caches and serial process boundaries. All 338 workflow-selected test
executions passed across 31 processes, including the callback queue, live
analyzer/controller, candidate and artifact tampering, calibrated primary,
holdout, atomic commit, representative-rate, core/evidence, preparation
preflight, and protected-routing groups. The realtime producer undefined-symbol
audit found only `memcpy`, the optimized `AutoTechno` product built, and
`git diff --check` was clean before publication.

This snapshot proves deterministic score/DSP/evidence behavior and offline
artifact qualification for quality-contract schema 23, candidate-vector schema
21, canonical engine v22, and primary evaluator v4. Publication and exact-head
remote CI remain separate gates. Listening observation, app/route and
interruption QA, latency/peak-memory measurement, and physical-output soak were
not performed and are not implied.

## Source 22 protagonist spectral reveal — 2026-08-19

Source 22 extends the existing anchor protagonist with one score-owned spectral
reveal relation. Naturally emerging lock or contrast bars apply aperture
`0.45 + 0.55 * presence^2` to the current Resonant Mono or Tonal Motion cutoff;
home, supporting roles, force-home correction, and ineligible bars remain exact
neutral. The slice adds no track, instrument, effect return, continuation
buffer, callback state, alternate evaluator, or user control.

The score-to-render contract retains independent score/render event counts and
fingerprints, active-event and aperture facts, actual cutoff extrema, and the
isolated anchor hash/peak/RMS. Candidate-vector schema 22 requires the record,
and Professional Evidence v8 adds event-weighted active and cutoff-ratio facts.
A dedicated adversarial case rejects an escaped cutoff relation.

Release-mode artifact generation accepted all 392 development observations
from 28 complete journeys, rejected all 25 adversarial cases for their expected
non-compensable reason, and accepted all 56 observations from four disjoint
holdout journeys with zero relationship failures. The shipping v5 artifact
identities are:

- profile: `a4f10f84996591bb`, JSON SHA-256
  `88e18dbd892bf1657f1fcc8c3f7c7ae1f2b36f3a32c48999d46dc101cec86866`;
- adversarial suite: `533141d901ed71c6`, JSON SHA-256
  `4e46f53c5566d146ae88029d974f6b663ded352db8cb5fd0530155e94db23574`;
- holdout qualification: `de7f4ca2dc3c94dc`, JSON SHA-256
  `6449aa9801848fd83c82faaaac67aa1e3f8189a319cabc22a9a84ee2b9f14113`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
isolated caches and serial process boundaries. All 346 workflow-selected test
executions passed across 31 processes, including focused protagonist reveal,
callback queue, live analyzer/controller, candidate and artifact tampering,
calibrated primary, adversarial, disjoint holdout, atomic commit,
representative-rate, core/evidence, preparation preflight, and protected-routing
groups. The realtime producer undefined-symbol audit found only the allowed
copy primitive, the optimized `AutoTechno` product built, and `git diff
--check` was clean before publication.

This snapshot proves deterministic score/DSP/evidence behavior and offline
artifact qualification for quality-contract schema 24, candidate-vector schema
22, canonical engine v23, and primary evaluator v5. Publication and exact-head
remote CI remain separate gates. Listening observation, app/route and
interruption QA, latency/peak-memory measurement, and physical-output soak were
not performed and are not implied.

## Source 23 percussion anticipation swell — 2026-08-19

Source 23 extends the existing percussion-echo texture with one score-owned
anticipation relation on the second kick-withheld energy-release bar. One
already-resolved weak-percussion event anchors a bounded one-step input window;
the detached renderer reverses that wet tail and shapes it toward the unchanged
kick-recovery boundary. The existing gated-echo path remains exact, and the
slice adds no track, onset, instrument, effect bus, continuation state, callback
work, or user control.

Candidate evidence retains the score relation, kick-syntax role, input/output
geometry, hashes, early/late energy, rise, boundary zeros, and render-pass
agreement for every bar. Professional Evidence v9 adds anticipation activity
and rise metrics; its flattened-envelope adversarial case is non-compensable.
Release-mode artifact generation accepted 392/392 development observations
from 28 journeys, rejected all 26 adversarial cases for their exact expected
reasons, and accepted 56/56 observations from four disjoint holdout journeys
with zero relationship failures. The shipping v6 identities are:

- profile: `e5dd5c31a2f52e0c`, JSON SHA-256
  `47afbd7f3366429fa75da78d73c63c04cc69d050f97a48dab8e4dd644cd815a9`;
- adversarial suite: `3bcabc8fb4118913`, JSON SHA-256
  `fbcd70e1122c45a7ad15ad107260fe2cded46e3153d35e6f50ca5c00f11c0f09`;
- holdout qualification: `4eae3a36734c295b`, JSON SHA-256
  `6c4104f42f02e5358934c61234daa7ed2bbb0332c0c7dff6c64a572e3731048f`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. All 351 workflow-selected test executions
passed across 31 processes. The realtime producer undefined-symbol audit found
only the allowed copy primitive, the optimized `AutoTechno` product built, and
`git diff --check` was clean before publication.

This snapshot proves deterministic score/DSP/evidence behavior and offline
artifact qualification for quality-contract schema 25, candidate-vector schema
23, canonical engine v24, Professional Evidence v9, and primary evaluator v6.
The implementation was published at `7be05e02a1e7f2a4c0a5801370c9a3703ca9eb8f`;
the CI-only process-timeout correction was published at exact head
`e867be1a583886f4e87c5aa778d3083ad2f0e781`. GitHub Actions run
`32272747671` passed every process-isolated test and the release build in
1h52m57s. Listening observation, app/route and interruption QA,
latency/peak-memory measurement, and physical-output soak were not performed
and are not implied.

## Source 24 pad rhythmic modulation — 2026-08-19

Source 24 extends the existing four-voice pad with one score-owned
three-sixteenth rhythmic-modulation relation. Naturally resolved latter-half
major-break pads reuse their existing low-pass and spatial-reverb send; early,
minimalized, structural-marker, identity, and ineligible bars remain exact
neutral. Absolute bar time owns phase, so the cell does not restart when a
phrase is split. The slice adds no note, track, instrument, effect return,
continuation buffer, callback work, or user control.

Candidate evidence retains the exact relation, phase and 16-step pattern,
applied filter/send extrema, pad and send hashes/RMS, same-pass
active-versus-neutral difference RMS, score binding, finiteness, and render-pass
agreement. Professional Evidence v10 adds activity plus level-relative
filter-difference-to-pad and spatial-difference-to-send metrics in dB. Its
disconnected-filter adversarial case is non-compensable.

Release-mode artifact generation reused 32 cached complete journeys, accepted
392/392 development observations from 28 journeys, rejected all 27 adversarial
cases for their exact expected reasons, and accepted 56/56 observations from
four disjoint holdout journeys with zero relationship failures. The shipping v7
identities are:

- profile: `fba981b1743f1ec4`, JSON SHA-256
  `8030f1e7960ef33775a976f536ffcb7aa7842f774d2ec40655b4e96c44be32ee`;
- adversarial suite: `2876d8a016965bd0`, JSON SHA-256
  `165e9d98e98345b973474f40a16158fd804672ffc45808713b7d51139a0eaf01`;
- holdout qualification: `62e93183f2f604ee`, JSON SHA-256
  `246f1141aa27b4f6182bf62b076d60226249f2cb1144d8af275bbef1e8f4cef6`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
module caches and serial process boundaries. The complete workflow-equivalent
matrix passed 354/354 test executions across 31 processes. It covers natural
score reachability, exact neutral identity, 8/44.1/48/96/192 kHz PCM,
prepared-candidate binding and tamper rejection, the regenerated primary
artifacts, adversarial qualification, disjoint holdout, atomic commit,
representative-rate and cancellation/correction paths, Core/evidence,
preflight, and protected routing. After static review tightened the legacy-JSON
identity test, the rebuilt exact-artifact group passed 13/13 again. Both local
debug and release realtime-producer objects expose only the allowed copy
primitive, the optimized `AutoTechno` product built in 79.44 seconds, and
`git diff --check` remained clean.

Publication and exact-head remote CI remain separate pending gates. Listening
observation, app/route and interruption QA, latency/peak-memory measurement,
and physical-output soak have not been performed and are not implied.

## Source 25 dotted foundation rhythm — 2026-08-20

Source 25 adds one score-owned, post-arbitration two-bar dotted foundation
relation to the existing Bass Pluck on the protected foundation lane. It
replaces only eligible bass onsets with complementary masks `0x8248` and
`0x4824`; it adds no track, instrument architecture, spatial return,
continuation state, callback work, or user control. Exact established behavior
remains the fallback.

Same-pass candidate evidence binds pair phase, score/render event counts and
occupied-step masks, exact rendered start frames, dry foundation hash/peak/RMS,
patch assignment, plan identity, and full/protected pass equality. Professional
Evidence v11 adds active-bar prevalence and mean active foundation crest factor;
the 28-case adversarial suite includes a non-compensable overpopulation attack.

Release-mode artifact generation accepted 392/392 development observations
from 28 journeys, rejected 28/28 adversarial cases for their exact expected
reasons, and accepted 56/56 observations from four disjoint holdout journeys
with zero relationship failures. The shipping v8 identities are:

- profile `8c7496b6aa65dc3f`, JSON SHA-256
  `b88b4efb556b452098c296a87043160961de9dfa163a4444d653cdfc8b82b178`;
- adversarial suite `c5da152a1423b07e`, JSON SHA-256
  `3b6a972d5a37e27b24a896934bf59bfe8e130f99fca8eb1055be168a333a0ae9`;
- holdout qualification `08902600240f622a`, JSON SHA-256
  `758835ec24529d79762d937f923c5d551f4ab5972326003ae8c1445282c2b921`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. A clean optimized rebuild preceded seven
selected groups: Source 25 6/6, exact artifacts/runtime 13/13, candidate evidence
27/27, runtime/calibration/quality 47/47, Core/evidence 122/122, preparation
preflight 24/24, and protected routing 14/14. These total 253 successful selected
executions with deliberate overlap between some groups. The optimized
`AutoTechno` product built in 77.96 seconds. The realtime producer
undefined-symbol audit exposed only the permitted `memcpy` primitive, and
`git diff --check` was clean.

This local snapshot proves the Source 25 score, PCM, evidence, regenerated
artifacts, holdout, adversarial, preparation, and realtime-producer contracts
for quality schema 27, candidate vector 25, canonical engine v26, and primary
evaluator v8. Publication and exact-head CI are still separate gates. Listening,
app/route/interruption QA, latency/peak-memory measurement, and hardware-output
soak were not performed and are not implied.

## Source 26 progressive harmonic disclosure — 2026-08-20

Source 26 extends the existing four-voice pad and its dependent arpeggiator
with one score-owned phrase-local disclosure stage. Lock phrases move from a
concealed tonic through a two-function preview, Major Break reveals the existing
four-function vocabulary, and later Lock material contracts again. It adds no
track, instrument, progression identity, effect chain, continuation buffer,
callback work, or user control; established and identity paths remain the exact
fallback.

Candidate-vector schema 26 retains exact local-bar/phrase-length geometry,
disclosure stage and function, pad consequence evidence, and equal typed score
and renderer arpeggiator-pitch fingerprints. Professional Evidence v12 adds
revealed-bar prevalence and distinct-function count, and the 29-case v10
adversarial suite includes one non-compensable impossible-overpopulation attack.
Quality-contract schema 28, canonical engine v27, primary evaluator/profile v9,
and the v8 disjoint holdout bind the change as one exact primary contract.

Release-mode artifact generation accepted 392/392 development observations
from 28 journeys, rejected 29/29 adversarial cases for their exact expected
reasons, and accepted 56/56 observations from four disjoint holdout journeys
with zero relationship failures. The shipping artifacts are:

- profile `94a506391e349fbb`, JSON SHA-256
  `baf022d8b34b58c043ac75ad59925144e82fb6da7dbd0f18176e18ff9580c96f`;
- adversarial suite `2a243887182f60ca`, JSON SHA-256
  `83b46a8002f2f9cfe3ec476cf7b22f10568b356674224671921722d2fff797be`;
- holdout qualification `0fcc5af37485633a`, JSON SHA-256
  `a94de1f67cdb535dba8de4776426ab5590e13a36933be99b76ef97282a3d1ae0`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
isolated caches and serial process boundaries. It passed the Source 26 causal
slice 3/3; current-runtime/repository surface 11/11; full professional
calibration 17/17; primary readiness 7/7; upper score 3/3; callback queue 7/7;
live analyzer/controller/trim 41/41; app live-feedback 32/32; candidate evidence
and tampering 28/28; atomic commit, unavailable-route, correction, rate,
continuation, and exact-fingerprint gates; modal Core/DSP 15/15; adaptive
session 25/25; Core/evidence 125/125; preparation preflight 24/24; and protected
routing 14/14. Both debug and release realtime-producer objects exposed only an
allowed copy primitive. The optimized `AutoTechno` product built in 71.40
seconds, and `git diff --check` remained clean.

Publication and exact-head CI remain separate pending gates. Listening,
app/route/interruption QA, latency/peak-memory measurement, and physical-output
soak were not performed and are not implied.

## Source 27 source-local kick dynamics — 2026-08-20

Source 27 extends the existing canonical kick at one instrument-local boundary:
the complete body + sub + click sum passes through a fixed first-order ADAA tanh
conditioner before the existing detector and audible buses. It adds no score
event, track, instrument, return, master processor, continuation buffer,
callback work, or user control. The exact unconditioned path remains documented
as the replacement baseline rather than running beside the new path.

Candidate-vector schema 27 retains event-local pre/post hashes, peak, RMS,
crest, physical-time attack/body RMS, upper-mid energy, score/render counts and
masks, exact withheld silence, detector/audible scaling, and full/protected pass
agreement. Professional Evidence v13 adds kick output crest, attack/body ratio,
upper-mid ratio, and crest reduction. The 30-case v11 adversarial suite includes
one non-compensable kick-source transient-spike attack. Quality-contract schema
29, canonical engine v28, and primary evaluator/profile v10 bind the change as
one exact installed contract.

Release-mode artifact generation accepted 392/392 development observations
from 28 journeys, rejected 30/30 adversarial cases for their exact expected
reasons, and accepted 56/56 observations from four disjoint holdout journeys
with zero relationship failures. A second generation from the same 32 cached
journeys was byte-identical. The shipping artifacts are:

- profile `6a16588407657191`, JSON SHA-256
  `2f228a4eb86fc61c0abaec6cbca9cab0e858498b4c1e03a59227c1db88b39c86`;
- adversarial suite `3a9e13af0380a49b`, JSON SHA-256
  `8314a2811e0e63ff77df3ab2db83edc30ed5bfac763db10427854636f61c67aa`;
- holdout qualification `c190edafab079602`, JSON SHA-256
  `6004226c7670aa3424bb59c1b7069c23937e113f2297f6fac9d499a3ec0ccf08`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. The selected matrix passed the source DSP
3/3; exact artifacts/runtime 13/13; candidate/live tampering 28/28;
adversarial qualification 2/2; calibrated policy 10/10; disjoint holdout 1/1;
Core/evidence 113/113; preparation preflight 24/24; protected routing 14/14;
instrument workflow partitions 12/12; and realtime queue 7/7. The two complete
artifact generations also passed, both debug and release realtime-producer
objects exposed only an allowed copy primitive, and the optimized `AutoTechno`
product built in 73.54 seconds. Some selected filters intentionally overlap;
these counts describe executions rather than distinct test declarations.

This local snapshot proves the Source 27 score-to-render evidence, source-DSP
causality, regenerated artifacts, holdout, adversarial, preparation, and
realtime-producer contracts. Publication and exact-head CI are separate pending
gates. Listening, app/route/interruption QA, latency/peak-memory measurement,
and physical-output soak were not performed and are not implied.

## Source 28 foundation pre-kick pocket — 2026-08-22

Source 28 extends the existing dotted Bass Pluck relation with one Core-owned
terminal-release articulation on the event immediately before kick 4 or 12.
The raised-cosine release begins `0.1875` score step before the kick, reaches
exact zero `0.0625` step before it, and leaves every onset, other role, protected
route, and neutral fallback unchanged. It adds no track, instrument, sidechain,
effect chain, continuation state, callback work, or user control.

Candidate-vector schema 28 retains the exact score event, natural event end,
release and kick geometry, dry-foundation silence hash/peak/RMS, Bass Pluck
assignment, and full/protected render agreement. Professional Evidence v14 adds
the upper-only-safer foundation pre-kick silence RMS maximum. The 31-case
adversarial suite includes one non-compensable contaminated-pocket attack.
Quality-contract schema 30, canonical engine v29, primary evaluator/profile
v11, adversarial schema 12, and holdout schema 10 bind the change as one exact
installed contract.

Release-mode artifact generation accepted 392/392 development observations
from 28 journeys, rejected 31/31 adversarial cases for their exact expected
reasons, and accepted 56/56 observations from four disjoint holdout journeys
with zero relationship failures. An independent second invocation against the
same 32 cached journeys produced byte-identical JSON. The shipping artifacts
are:

- profile `63b4173f9d08fdba`, JSON SHA-256
  `b65e15456e287461c2d8c9737c3da2689c60b84b750a0470a9edbe2f62321335`;
- adversarial suite `8fb2813d62791ba5`, JSON SHA-256
  `1dac45b96e6fa6fcaeee60d3d7b78a9be591e8531920c2858c350701a08549ce`;
- holdout qualification `411b1fdd09995453`, JSON SHA-256
  `852044c5cdd117f848fbea207a9e357fb7984a91e26241701e2bd61515e2cef2`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. Source 28 passed 11/11 causal and
correction tests; the fresh-bundle v11-only check passed after discarding one
reused-bundle run that still contained copied v10 resources; the candidate/live
tamper matrix passed its 27 unaffected cases and the intentionally updated
quality-state fingerprint passed 1/1 after exact-golden correction; adversarial
qualification passed 2/2; calibrated policy 10/10; disjoint holdout 1/1; atomic
commit 1/1; unsupported 8 and 12 kHz gates 1/1 each; unavailable-route commit
1/1; cancellation 1/1; correction order 2/2; rejected-attempt isolation 1/1;
representative-rate evidence 1/1; prepared device rates 1/1; resource envelope
2/2; continuation replay 1/1; Core/evidence 117/117; preparation preflight
24/24; and protected routing 14/14. The debug realtime-producer object exposed
only the allowed `memcpy_chk` copy primitive, and the optimized `AutoTechno`
product built in 73.76 seconds. `git diff --check` was clean before publication.

This local snapshot proves deterministic score-to-render causality, exact
neutral/correction behavior, regenerated primary artifacts, adversarial and
disjoint-holdout qualification, preparation, and realtime-producer safety.
Publication and exact-head CI are separate pending gates. Listening,
app/route/interruption QA, latency/peak-memory measurement, and physical-output
soak were not performed and are not implied.

## Source 29 terminal climax hang — 2026-08-22

Source 29 extends the existing paid-debt energy-release climax at one terminal
score boundary. Only the final kick-withheld bar at macro position 14 owns a
`terminalRecoveryDelay`: existing weak pulses stop after steps `[3, 7, 11]`,
the existing anticipation return ends at step 12, and one 8 ms raised-cosine
full-mix release reaches exact zero for steps 12--16. Canonical voice, graph,
effect, and continuation state advances underneath, so the already-owned
step-zero recovery remains unchanged. The slice adds no track, instrument,
effect chain, break sequencer, persistent state, callback work, or user control.

Candidate-vector schema 29 binds the score relation, macro and kick-syntax
owners, weak-pulse geometry, route-derived release/silence frames,
pre/post/silence hashes, release input RMS, exact-zero peak/RMS/nonzero count,
post-hang/pre-live-master identity, and recovery. Professional Evidence v15
adds an upper-only-safer hang-silence RMS maximum. The 32-case v13 adversarial
suite includes one non-compensable hang-contamination attack. Quality-contract
schema 31, canonical engine v30, and primary evaluator/profile v12 bind the
change as one exact installed contract.

Release-mode artifact generation accepted 392/392 development observations
from 28 journeys, rejected 32/32 adversarial cases for their exact expected
reasons, and accepted 56/56 observations from four disjoint holdout journeys
with zero relationship failures. A second invocation against the same 32
cached journeys produced byte-identical JSON. The shipping artifacts are:

- profile `7bb19b3a5572bb39`, JSON SHA-256
  `f9e2981ebac800c3682722b1c70bd735b7a1dfe6e519416df5bcd30f485a55a5`;
- adversarial suite `81f1cb944e9de091`, JSON SHA-256
  `bbf2b1c13099b6db20e7440fe673bb1787415d9a7f5628a4b583e45d8ef3b502`;
- holdout qualification `b9274bf9c29d2858`, JSON SHA-256
  `5d5628ec5fd4692c863e1eff3b0875f2d3de9511618462bb98bd84abcf55d84d`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. The release-mode Source 29 focus passed
21/21. The CI-equivalent matrix passed all 375 selected test executions across
38 processes: upper score 3/3; callback queue 7/7; live analyzer/controller
41/41; App coordination 32/32; candidate/live tampering 28/28; exact artifacts
13/13; deterministic profile/adversarial 2/2; calibrated policy 10/10;
disjoint holdout 1/1; atomic commit 1/1; correction/evidence overlap 4/4;
unsupported-rate and focused tamper gates 6/6; transaction/rate/resource/
continuation gates 12/12; modal Core/DSP 15/15; adaptive session 25/25;
instrument workflow partitions 12/12; kick source 3/3; prepared percussion
echo 1/1; Core/evidence 121/121; preparation preflight 24/24; and protected
routing 14/14. Both debug and release realtime-producer objects exposed only an
allowed copy primitive. The optimized `AutoTechno` product built in 79.02
seconds, and `git diff --check` remained clean.

Hosted run `32586400063` then passed the 121-test Core/evidence group and the
isolated upper-percussion-tail DSP suite before exiting with signal 10 as Swift
Testing began the tail preflight test. That unchanged contract prepares four
complete canonical transactions and is now executed on XCTest's normal thread
instead of a bounded cooperative-task stack. The exact filtered command passed
6/6 locally after the harness-only move; production sources, PCM, evidence, and
policy are unchanged. Exact-head CI remains required for closure.

This local snapshot proves the Source 29 score-to-render consequence, exact
terminal silence, neutral and malformed-input behavior, regenerated primary
artifacts, adversarial and disjoint-holdout qualification, future-boundary
preparation, and realtime-producer safety. Publication and exact-head CI are
separate pending gates. Listening, app/route/interruption QA, latency or
peak-memory measurement, and physical-output soak were not performed and are
not implied.

## Source 30 pad amplitude gate calibration — 2026-08-22

Candidate-vector schema 30 binds the existing three-step pad relation to
route-derived amplitude-transition geometry, open/closed counts, exact closed
dry/send silence, pre/post hashes, same-pass difference RMS, existing
filter/spatial consequences, and full/protected equality. Professional Evidence
v16 and the 67-metric primary vector add the level-relative amplitude-gate
consequence; adversarial suite v14 adds the non-compensable disconnected-gate
case. Quality-contract schema 32, canonical engine v31, profile v13, and holdout
v12 bind the slice as one exact installed contract.

The first disjoint pilot correctly failed one cross-rate relationship:
seed `161803`, `majorBreak`, RMS-trajectory peak `47.7545970362` at 44.1 kHz
versus `57.1159838385` at 48 kHz, delta `9.3613868022` above bound
`7.6890716369`. Focused edge/floor diagnostics showed that an overlapping-window
maximum was sample-grid sensitive while its mean stayed stable. The peak remains
locally and within-rate evaluative; only the mean participates in cross-rate
relationships. The pilot corpus was not reused as proof.

Four replacement unseen holdouts accepted 56/56 observations with zero local,
trajectory, or rate-consistency failures and zero source overlap. The 28
development journeys accepted 392/392 observations; all 33 adversarial cases
rejected for their exact expected reasons. A second cache-backed invocation
produced byte-identical artifacts:

- profile `e1fdcbe7241f9f50`, JSON SHA-256
  `7b1072efacffec30cf4023e2c1d0f131578635f138fd2b09019a9fa96ab79081`;
- adversarial suite `8973cc31505dfb7c`, JSON SHA-256
  `b8e2a9e23a4e885b17353e9067a142e1566910377c9186d5aa2bcbd54dbfdf08`;
- holdout qualification `b52070f9cb2231b4`, JSON SHA-256
  `258696445ba1516ffedb33340786842a7898835c9516500d9af320dea7d04850`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. The workflow-selected filters passed all
376 test executions: upper score 3/3; realtime queue 7/7; live analyzer/
controller 41/41; App coordination 32/32; candidate/live tampering 28/28
(27 unaffected cases plus the corrected exact quality-state golden 1/1); exact
artifacts 13/13; deterministic profile/adversarial 2/2; calibrated policy
11/11; disjoint holdout 1/1; atomic commit 1/1; lightweight primary/evidence
4/4; unsupported routes 2/2; focused evidence tampering 4/4; transaction/rate/
resource/continuation gates 12/12; modal Core/DSP 15/15; adaptive session 25/25;
instrument partitions 12/12; kick source 3/3; prepared percussion echo 1/1;
Core/evidence 83/83; six isolated upper suites 38/38; preparation preflight
24/24; and protected routing 14/14. The debug and release realtime-producer
objects exposed only an allowed copy primitive. The optimized `AutoTechno`
product built in 95.33 seconds (97.51 seconds wall).

This snapshot proves score-to-render causality, exact closed-step silence,
neutral/correction/continuation behavior, artifact generation, adversarial
rejection, disjoint unseen-holdout qualification, byte determinism, preparation,
protected routing, and realtime-producer safety. Publication and exact-head CI
are separate gates. Listening, app/route/interruption QA, physical-output soak,
and a professional-quality claim are not implied.

## Source 31 response-owned upper harmonic tail — 2026-08-23

Broken Suspension now assigns one response-only Voltage Arc patch inside the
existing Spectral Texture architecture. The canonical renderer folds the
resolved note into a bounded low polyBLEP source, drives and isolates its upper
harmonic tail through the shared TPT state-variable core, advances one
free-running modulation phase, and reuses the existing response envelope and
filtered-reverb path. Candidate-vector schema 31 binds exact assignment,
relation, source/filter/modulation bounds, isolated stem hashes and signal
measurements, protected routing, and continuation. Professional Evidence v17
adds the higher-only-safer upper-band ratio; adversarial suite v15 adds the
non-compensable disconnected-tail case. Quality-contract schema 33 and
canonical engine v32 bind the complete consequence.

The 28 development journeys accepted 392/392 observations. All 34 adversarial
cases rejected for their exact expected reasons. Four disjoint holdout journeys
accepted 56/56 observations with zero local, trajectory, or rate-consistency
failures and zero source overlap. A cache-backed second invocation reproduced
all three artifacts byte for byte:

- profile `9ad691f87acdcbaf`, JSON SHA-256
  `2fe61c2a5fbb1062665bd9e54f2acb6ceafd1822e67812215ea4f6519cd8d772`;
- adversarial suite `df4ec48aa47cfb3a`, JSON SHA-256
  `716baeed0e320d7f70df0fe520a22d7815972a3fafb899f5b3559e98890079da`;
- holdout qualification `f0df34e6e76af2a5`, JSON SHA-256
  `1a624459854c28ac9332aef15ed41eeead752492d187030a29395f9eb695fe72`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. The release workflow matrix passed all
379 selected test executions across 45 SwiftPM partitions plus four direct
XCTest prepared-product cases: upper score 3/3; realtime queue 7/7; live
analyzer/controller 41/41; App coordination 32/32; candidate/live tampering
29/29; exact artifacts 13/13; deterministic profile/adversarial 2/2; calibrated
policy 11/11; disjoint holdout 1/1; atomic commit 1/1; lightweight contracts
4/4; unsupported routes and focused tamper gates 6/6; transaction/rate/resource/
continuation gates 12/12; modal Core/DSP 15/15; adaptive session 25/25;
instrument workflow partitions 15/15; kick source 3/3; prepared percussion echo
1/1; Core/evidence 83/83; six isolated upper suites 37/37; preparation preflight
24/24; and protected routing 14/14. The clean current-runtime/repository suite
also passed 11/11. The release realtime-producer object imported only `memcpy`.
The optimized `AutoTechno` product built in 84.42 seconds, and
`git diff --check` remained clean.

This snapshot proves deterministic score-to-render causality, bounded and
finite upper-tail synthesis, continuation and route ownership, exact causal
evidence, malformed/tampered-evidence rejection, regenerated primary artifacts,
adversarial and unseen-holdout qualification, byte determinism, preparation,
protected routing, and realtime-producer safety. Publication and exact-head CI
are separate gates. Listening, app/route/interruption QA, latency or peak-memory
measurement, physical-output soak, and a professional-quality claim are not
implied.

## Source 32 fresh autonomous session identity — 2026-08-23

The App now selects one opaque root seed before detached preparation and
installs it as the sole director identity for a complete performance. Complete
shutdown selects the next identity; pause/resume, live correction, timeline
reset, route recovery, and continuation retain the accepted seed. Every
preparation key binds that seed, and prepared acceptance cross-checks key,
source state, active session, and generated graph. Fixed-seed score/render
semantics and all Core/DSP/evaluator/artifact identities remain unchanged.

TDD first produced the expected compile failures for the absent seed source,
injected engine boundary, session-seed accessor, and seed-bearing preparation
key. Local validation then passed 110 distinct selected contracts across four
serial groups:

- App session-identity and live-feedback coordination: 36/36 in 48.661 seconds;
- current runtime, adaptive session, and repository surface: 36/36 in 101.316
  seconds;
- autonomous preparation preflight: 24/24 in 721.544 seconds;
- protected-routing regressions: 14/14 in 122.688 seconds.

The dedicated session suite proved immediate collision avoidance, shutdown
rotation, seed-bound cache inequality, exact explicit-seed plan/PCM replay, and
distinct-seed plan/PCM divergence. The optimized `AutoTechno` product built in
97.53 seconds with SHA-256
`dbad5410df65607bd578a445d2053c6d0abdc6de263def2ad98d9290367e0fb7`.
After normative prose finalization, the five repository-surface contracts
reran 5/5 green, for 115 total local test executions including that deliberate
repeat.
The release realtime-producer object imported only `_memcpy`; no Core, DSP,
renderer, graph, evaluator, artifact, or callback source changed.

This snapshot proves the bounded App session boundary, deterministic replay,
preparation isolation, canonical transaction compatibility, protected routing,
and realtime-producer safety. Publication and exact-head CI are separate gates.
No listening, app/route/interruption QA, physical-output soak, or professional-
quality claim is implied.
