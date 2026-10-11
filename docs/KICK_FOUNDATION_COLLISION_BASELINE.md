# Kick/foundation collision baseline contract

## Purpose and authority

AT-0021 adds event-aligned, descriptive evidence for the exact accepted dry
kick and foundation role taps. It answers where those two signals are present,
where their activity coincides, where the existing causal sub-band model finds
similar energy, how long those sampled conditions persist, and whether the
canonical dotted-foundation articulation produced an exact pre-kick pocket.

This work does not add a runtime evaluator dimension, quality threshold,
automatic correction, renderer, score authority, continuation value, user
control, engine, profile, or release claim. `VoiceRenderer` remains the owner
of the post-fader audible kick, aggregate foundation tap, rendered kick onset,
and pocket consequence. The accepted resolved score and selected candidate
remain the event authority. `SpectrumMaskingAnalyzer` remains the sole owner of
the causal four-band energy model and its activity and overlap relations.

`PCMKickFoundationCollisionAnalyzer` composes those owners only during detached
local analysis. Generated payloads and reports live under
`docs/local/reports/kick-foundation-collision-v1/` and remain ignored,
reconstructable local evidence.

## Exact inputs and provenance

The exporter replays every `docs/BASELINE_CORPUS.json` checkpoint through the
same shared preparer, quality evaluator, bounded correction transaction, and
selected candidate used by the application. It retains no diagnostic stem PCM
from that replay. Instead, it requires the replay's session-state, plan, route,
checkpoint, quality, and replay identities to equal both current baseline
manifests, then reads the already captured `kick` and `foundation` WAVs.

The kick file is the exact post-fader audible dry kick. The foundation file is
the aligned aggregate bass, rumble, and foundation-companion contribution.
Both are mono, phrase-aligned, IEEE Float32 signals. The report binds the full
14-whole-mix/210-role-signal manifest set (224 assets total), both PCM-set
fingerprints, every WAV/PCM hash, the corpus, contract baseline, source
fingerprint, Git head, engine version, and the candidate-evaluation
fingerprint. A stale, missing, extra, duplicated, malformed, unaligned,
non-finite, or path-divergent input fails closed.

## Authoritative event binding

Only rendered kick events present in the accepted resolved score are eligible.
For every accepted bar, the exporter requires:

- the selected candidate's kick syntax to be complete and binding-valid;
- score and rendered kick counts and 16-step masks to agree;
- the selected foundation-rhythm evidence to be complete and binding-valid;
- the block, score bar, sample rate, and manifest geometry to agree.

The event onset is then reconstructed from the bound score step and exact
rendered bar size:

```text
bar frame count = nearest integer(sample rate * 240 / 130)
event onset      = bar start + nearest integer(step * bar frame count / 16)
```

This is the same zero-offset geometry used for rendered kicks. PCM peaks or
transient detectors never create, move, or name score events. A bar with no
eligible kick is valid and appears in `barsWithoutKick`; it does not acquire a
synthetic event.

`authoredFoundationRolesInBar` is score context limited to `bass`, `rumble`,
and `tunedTom`. It does not pretend that the aggregate foundation PCM can be
unmixed into those subroles. The only causally measured responsible signal
pair is therefore exactly `kick` and `foundation`.

## Event window and causal cells

Each event window begins at the exact kick onset and extends for two score
steps (one eighth note), bounded by the current bar:

```text
event end = min(bar end,
                kick onset + nearest integer(bar frame count / 8))
```

The canonical causal band analyzer divides that window into exactly 16
contiguous cells. Every frame belongs to one cell; cells may differ by one
frame. Filter state starts at zero at the event onset, then remains causal and
continuous across all 16 cells. Current event-window geometry is approximately
230.77 ms, with approximately 14.42 ms duration resolution. The report stores
the exact frame count of every cell, so the independent verifier reconstructs
rather than assumes the resolution.

Resetting at the event onset intentionally makes this an event-local response,
not a claim about continuously warmed filter state. AT-0020 remains the owner
of whole-bar continuous causal-band baselines.

## Activity, temporal overlap, and low-band overlap

For each role and cell, source activity means source mean square is greater
than `1e-10`, reusing the masking owner's existing threshold. A temporal
overlap cell has both exact role signals active.

The current low band is the masking owner's causal `sub` band, 35–120 Hz. A
low-band pair is eligible only when both role sources and both sub-band mean
squares are active. Its similarity is:

```text
min(kick sub mean square, foundation sub mean square)
-----------------------------------------------------
max(kick sub mean square, foundation sub mean square)
```

A low-band overlap cell has similarity greater than `0.38`, reusing the
canonical masking relation. The causal one-pole-difference bands overlap and
are not power-complementary. Therefore this classifier is evidence about the
existing provisional model, not proof of perceptual masking, phase alignment,
energy conservation, or poor mix quality.

## Collision classes

Each event receives one mutually exclusive descriptive class:

| Class | Meaning in the event window |
|---|---|
| `mutual-silence` | Neither exact role tap is active |
| `kick-only` | Kick is active and foundation is not |
| `foundation-only` | Foundation is active and kick is not |
| `separated` | Both roles occur, but never in the same sampled cell |
| `temporal-overlap` | At least one sampled cell contains both roles, but no cell passes the low-band similarity relation |
| `low-band-overlap` | At least one sampled cell contains both roles and passes the low-band similarity relation |

These classes describe evidence availability and coincidence. They are not a
ranked severity scale. In particular, overlap may be musically intended and
one-sided or separated evidence is not automatically preferable.

## Duration, timing, and relative level

Temporal and low-band durations sum the exact frame counts of classified
cells. The report also retains window count, first and last sampled frame,
longest contiguous run, seconds, and the maximum possible cell duration. These
are cell-quantized durations, never mislabeled as sample-exact collision
boundaries.

When both signals are active in at least one temporal-overlap cell, relative
energy is:

```text
10 * log10(sum(kick mean square * cell frames)
            / sum(foundation mean square * cell frames))
```

Positive values mean more kick energy in the sampled paired cells. The field
is explicitly `descriptive-not-calibrated-not-excessive`; neither the existing
automatic-mix companion targets nor an arbitrary new limit converts it into a
quality failure.

## Exact pre-kick pocket

The dotted-foundation pocket is independent from post-onset collision class.
When the selected foundation-rhythm evidence binds a pocket to the same kick,
the exporter supplies its phrase-absolute release and kick frames, exact
silence count, zero peak/RMS, application status, and finite status. The
analyzer rejects any mismatch. The independent verifier then confirms that
every exact foundation sample immediately preceding the kick for that retained
count is zero.

An event may therefore have `pocketState: exact-silence` and still have
post-onset `low-band-overlap`; that is a truthful articulation rather than a
contradiction. Events without an authored pocket use `not-authored`, not a
failed or inferred pocket.

## Confidence and unavailable states

Complete events use confidence
`exact-pcm-score-event-bound-causal-cell-quantized`. This is a compact statement
of evidence provenance and resolution, not a probability or listening score.
It means exact manifest-bound PCM, a score/render-bound accepted kick event,
the canonical causal band model, and quantized duration are all present.

The analyzer fails closed with stable reasons for unsupported sample rate,
empty or unaligned signals, non-finite PCM, duplicate events, invalid event
geometry, invalid pocket binding, insufficient windows, or unavailable
canonical band evidence. Current corpus export treats any such result as a
failed report rather than silently omitting the affected entry.

## Operation

Normal tests do not read private corpus audio or write reports. Explicit local
export and independent finalization are:

```bash
AUTOTECHNO_RUN_KICK_FOUNDATION_COLLISION=1 \
  swift test -c release --jobs 1 --no-parallel \
  --filter KickFoundationCollisionIntegrationTests
python3 scripts/kick_foundation_collision_report.py generate
python3 scripts/kick_foundation_collision_report.py check
```

CI runs the synthetic Swift fixture bank and Python verifier mutation bank.
Corpus export remains opt-in and local-only.

## Qualification boundary and limitations

Synthetic fixtures cover exact low-frequency overlap, temporal overlap without
sub-band similarity, separated tails, kick-only, foundation-only, mutual
silence, exact pockets, phase inversion, 44.1/48 kHz geometry, malformed
events, non-finite PCM, and fail-closed provenance. Python mutations cover band
energy, class, duration, optional evidence, event geometry, pocket, manifest,
contract, and report-fingerprint drift.

This baseline does not determine perceptual masking, phase compatibility,
constructive versus destructive summation, desired kick/bass relationship,
professional quality, automatic EQ, dynamic sidechain policy, listening
approval, app/route behavior, or physical-output soak. It changes no production
PCM and has no continuation or future-boundary effect. Later calibration may
promote a bounded relationship only through the existing single evaluator and
controller contract.


## Native score-to-kick fault controls

`KickSourceDynamicsTests.algorithmicScoreRenderFaults` is a bounded component
benchmark for the algorithmic calibration path. It uses fixed roots1/42 for
construction development and6011/7011 as held-out roots. Before any render, each
root selects the first initial-plan grounded bar containing a downbeat kick.
A missing eligible bar fails the fixture; no replacement seed is selected from
an audio or measurement outcome. These roots are not independent musical
construction families and do not establish population-level uncertainty.

At44100 and48000 Hz the existing `VoiceRenderer.renderBar` renders the same
bar in its ordinary full and protected-rhythm layers. Six frozen recipes cover
unchanged score, deleted kicks, one-step shifted kicks, wrong-voice substitution,
zero kick intensity and intentional absence. A copied bar preserves all fields
except the declared event changes and, for intentional absence only, the kick
role/anchor removal. The identity copy is required to equal the original bar.
No alternative renderer, production fault hook or callback work is introduced.

The existing `AutonomousKickSyntaxBarEvidence.isComplete` predicate is evaluated
with score count/mask from the original intended events and evidence from the
actual changed render. Intentional absence supplies its explicitly changed
withheld intention instead. The test verifies the fault-specific consequence
(count/mask or zero audible samples), a changed detector hash, matching full and
protected kick evidence and finite rendered output. This avoids counting an
unrelated failure as proof that the intended fault was detected.

The emitted `autotechno-score-kick-fault-component.v1` JSON has48 rows, including
reference plan identity, root split, native rate, role, score/render counts and
masks, actual PCM hashes and expected/observed completeness. A passing execution
requires16 positive controls and32 rejected fault controls, with no unexplained
mismatches. The report's presence alone is not a pass; inspect test exit and
assertion results at the exact source.

This tests the existing bar-level kick binding contract. It does not construct
an accepted preparation transaction, establish foundation-companion fidelity,
prove that a decoded metadata record is authoritative, or qualify nonlinear
full-mix musical quality. Whole-transaction provenance, complete qualification
and physical/resource gates remain separate. Existing corpus export and its
historical reports are unchanged.

Run with `swift test --no-parallel --filter
KickSourceDynamicsTests/algorithmicScoreRenderFaults`. Hosted CI runs the complete
existing kick-source suite early in its remaining bank, after the same test
build. Its command and serial execution are unchanged; it is moved, not duplicated.

## Closed-form source-energy benchmark

`PCMKickFoundationCollisionAnalyzerTests.algorithmicSourceEnergy` extends the
existing collision evidence owner with a test-only measurement oracle. It leaves
production state, rendering, continuation, future-boundary decisions, thresholds
and fallback unchanged. The reusable guarantee is that source-energy evidence
preserves known PCM energy and temporal activity under declared gain, truncation
and absence controls. It does not add a competing analyzer or runtime parameter.

Three frozen constructions use integer samples divided by1024: bipolar square
(development), bipolar ramp and sparse bipolar pulse (held-out construction
families). Square magnitude is64; the32-frame ramp is `frame % 32 - 16`; the
97-frame pulse has values64,-64 at offsets0,1 and zero elsewhere. The oracle
uses periodic prefix sums and the polynomial sum of squares, independently of
the production per-sample energy accumulator and band filters. Ramp energy per
period is2736 integer-square units. No feature output selects a fixture, family,
split, or pass threshold.

Six recipes at each native rate give36 rows: intentional overlap, half amplitude,
double amplitude, unauthorized truncation at half the analysis support, deleted
required companion, and intentional absence. All576 causal windows retain exact
expected and observed source means, independently calculated geometry, temporal
activity counts and the declared companion requirement. Loss and gain controls
must change energy in the prescribed direction; a missing required companion
must be distinguished from intentional absence. This required-role witness is
test-only and does not assert a score-to-foundation render binding.

Each sample, square and accumulated square is exactly representable in Double:
integer magnitudes are at most128 after gain, powers-of-two denominators are
exact, and the accumulated numerator is far below2^53. Oracle and accumulator
perform the same final division by the independently determined cell length.
Therefore per-window source means require exact equality, with no fitted
numerical or perceptual tolerance. Six family/rate summaries report MAE, RMSE
and signed error across both roles. Windows, rates and recipes are paired
measurements, not independent population samples; these three fixed
constructions do not support a population confidence interval.

The emitted `autotechno-collision-source-energy.v1` report keeps unavailable
perceptual harm, band-filter calibration, score-to-foundation binding, nonlinear
full-mix quality and population uncertainty explicit. Historical constructed
signal pilots and their counterexamples remain unchanged. This benchmark
supports measurement fidelity only; it cannot qualify musical preference or
replace the remaining native, provenance, resource or physical-output gates.

Run the Swift Testing case with `swift test --no-parallel --filter
PCMKickFoundationCollisionAnalyzerTests.algorithmicSourceEnergy`. Hosted CI also
runs it explicitly in the remaining bank after compilation, retaining the full
existing collision suite in the foundation bank. For a component-only check,
compile `SpectrumMaskingAnalyzer.swift`, `PCMKickFoundationCollisionAnalyzer.swift`
and the existing test file together with `-package-name AutoTechno
-D AUTOTECHNO_COLLISION_COMPONENT_CHECK`. A small executable entry point calls
`PCMKickFoundationCollisionAnalyzerTests.AlgorithmicSourceEnergyBenchmark.run()`,
encodes the report and exits nonzero if `failures` is nonempty. That mode compiles
the exact production analyzers and shared helper; it excludes Swift Testing
wrappers and does not establish a package-test or semantic-map pass.


## Native foundation bass fault construction benchmark

`FoundationRhythmicRelationTests.algorithmicFoundationBassFaults` extends the
existing foundation-rhythm evidence owner through the canonical `VoiceRenderer`.
It freezes root1 as development and root6011 as held-out-root before rendering.
For each root, select the first score bar of each of `subPulse`, `monotone`,
`point`, `pump` and `absent` within128 planned phrases. Only established rhythm,
no delayed-bass-entry signature and no rumble/tuned-tom events are eligible.
Audible selections require declared positive-intensity bass events; the absent
selection requires none. Missing selection fails; roots are never substituted.

At44.1 and48kHz, render unaltered, deleted-bass, one-step cyclic onset shift,
wrong-voice and zero-intensity recipes against the original score. The absent
control uses its unchanged naturally absent score. Deletion and voice changes
remove rendered bass support; onset shifts retain event count while violating
original sample starts; zero intensity must produce measured silence. Expected
starts use the score's existing timing-offset contract, not observed PCM peaks.
This checks score binding, not an independent calibration of that offset formula.
Every case compares actual full and protected-rhythm pass evidence. Positive
cases also replay the canonical full pass exactly. Fresh zero continuation and
one bar bound every render; no callback or production state changes.

The emitted `autotechno-foundation-bass-fault-component.v1` report expects84
rows:20 positive controls and64 mandatory fault rejections. Each row retains
source-plan identity, behavior, root split, rate, original/rendered counts, masks
and sample starts, dry-foundation PCM hash, peak/RMS and evidence completeness.
The held-out unit is root, not windows, rates, repeats or a renamed signal family.
No population confidence interval or generalization claim follows from two roots.

`kickTail` and `tunedPercussive` remain explicit unavailable behavior cells: the
bass-event ledger cannot establish rumble or modal event fidelity. Dotted
authorized release, unauthorized truncation, full prepared-transaction binding,
nonlinear full-mix and perceptual quality also remain unavailable in this
component benchmark. Existing dotted/pocket tests and all quality promotion
gates remain required. This adds fault coverage without another renderer,
metric, parameter, policy or quality threshold. Native execution is required
before recording a passing matrix.

## Native rumble and modal companion fault benchmark

`FoundationRhythmicRelationTests.algorithmicFoundationCompanionFaults` extends
that same test owner to the two foundation behaviors that the bass-event ledger
cannot assess. Roots1 (development) and6011 (held-out-root), both native rates,
and five recipes are frozen before PCM inspection. For each behavior, select
the first score bar within128 planned phrases with positive corresponding
rumble or tuned-tom events, no other bass/rumble/tuned-tom voice, and all companion
steps in0...14. Modal articulations must match the original event indexes,
steps and intensities. Missing coverage fails without replacement roots.

Forty rows cover unaltered, deleted-companion, one-step onset shift, wrong-voice
and zero-intensity controls:8 positive bindings and32 required rejections. The
modal zero-intensity fault changes both the ensemble event and its authoritative
modal articulation. The shift changes both records coherently without wrapping;
all other articulation fields remain unchanged. Evidence is compared with the
original score, never with a relabelled fault score.

Each case invokes the existing `VoiceRenderer.renderBar` with its existing
same-pass diagnostic role capture in full and protected-rhythm modes. Fresh
zero render state and one bar bound every call. Each test-local projection retains
one bar of sample bit patterns for exact pass/replay comparison. Only reduced
hashes, event facts, first-nonzero index and energy statistics enter the report;
PCM is never saved or committed.
Rumble uses the existing terminal-event ledger and completeness predicate;
modal uses exact articulation identities, native start-frame support, finite
stable event evidence and the existing protected-foundation routing flag.
Actual captured PCM must match across passes; positive cases replay exactly.
Silencing faults must produce exact zero peak/RMS and no nonzero sample, while
all faults must change the source PCM hash.

Rumble and tuned-tom onsets are unswung. The relative first-nonzero displacement
under the one-step fault must equal the difference between independently rounded
score starts, using `round(step * round(rate * 240 / 130) / 16)`. This is an exact
relative onset relation, not a fitted audio-onset tolerance. Absolute per-event
rumble starts are unavailable because its terminal ledger has no such field;
modal starts retain their existing explicit sample support. Native-rate variants,
recipes and repeats are paired observations of two fixed roots, not independent
population samples or a newly fitted classifier.

The emitted `autotechno-foundation-companion-fault-component.v1` report keeps
continuing modal-tail support, unauthorized truncation, dotted authorized release,
full prepared-transaction binding, nonlinear full-mix quality, perceptual quality
and population intervals unavailable. It complements the established-bass
benchmark; it does not turn its historical unavailable cells into retrospective
passes. All required runtime, resource and physical-output gates remain separate.

This test-only extension adds no runtime parameter, renderer, continuation,
future decision, fallback or production threshold. It reuses the canonical
voice/evidence owners and existing capture path. Native execution must verify
the frozen matrix before any passing component result is recorded.
