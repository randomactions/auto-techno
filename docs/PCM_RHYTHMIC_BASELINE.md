# PCM rhythmic baseline contract

## Purpose and authority

AT-0024 adds detached descriptive evidence for bar-local onset distribution,
inter-onset spacing, rhythmic rest, exact signal silence, microtiming, named
metrical displacement, adjacent strong-rest potential, and bounded bar-to-bar
relation across the exact accepted whole-mix corpus. It distinguishes exact
signal repetition, exact onset repetition, grid-equivalent timing or timbre
variation, a small onset mutation, a cyclic rotation, and unrelated churn
without collapsing them into one groove-quality score.

This item does not add a runtime evaluator dimension, preference threshold,
automatic correction, score event, renderer, continuation value, controller,
future decision, user control, engine, profile, or professional-quality claim.
The accepted resolved score remains the authority for authored events.
`PCMTransientEnvelopeAnalyzer` remains the authority for the reused
PCM-inferred onset family, and `PCMSignalIntegrityAnalyzer` remains the broader
owner of channel/asset signal integrity and silence. The rhythmic analyzer
composes those meanings but does not replace or silently strengthen them.

Generated payloads and reports live under
`docs/local/reports/rhythmic-baseline-v1/` and remain ignored,
reconstructable local evidence.

## Exact inputs and provenance

The report covers only the fourteen accepted stereo whole mixes in the current
AT-0016 manifest. AT-0024 depends on AT-0016, not on the optional role-capture
item, and therefore does not treat diagnostic role signals as additional
performance observations. Each asset retains its corpus identity, checkpoint,
continuation class, phrase index, absolute start bar, phrase kind, plan
fingerprint, exact PCM hash, and local WAV path.

The input must be a canonical mono or stereo 32-bit IEEE Float WAV with finite
PCM and exact manifest geometry. A missing, extra, duplicate, malformed,
non-finite, unsupported, hash-divergent, or path-divergent source fails closed.
The report binds the current corpus, execution-contract snapshot, source and
Git identities, engine version, manifest hash, PCM-set fingerprint, every
asset identity, and one canonical report fingerprint.

The independent Python verifier rereads every Float32 WAV and recomputes every
onset, grid cell, interval, silence count, metrical fact, comparison, aggregate,
and report fingerprint. It does not trust the Swift payload's reductions.

## Signal domain and onset provenance

The rhythmic report uses accepted whole-mix PCM only. Existing onset inference
uses the arithmetic source-channel mean:

```text
mono[frame] = arithmetic mean of every source channel at that frame
```

It then reuses the exact AT-0022 activity-rise/legacy-flux detector, merge
window, and event onset frames. The authority string remains:

```text
pcm-inferred-activity-rise-or-legacy-flux-not-score-bound
```

Arithmetic-fold cancellation is therefore possible and explicit. A stereo
fixture with equal and opposite nonzero channels produces no folded onsets but
does not become exact source silence. AT-0023 remains the owner of stereo
compatibility evidence.

The whole-mix manifest binds a plan fingerprint but does not retain individual
resolved score events. The report therefore records score binding as
`unavailable-whole-manifest-does-not-retain-score-events`. It never merges a
PCM-inferred event with a score claim. A later score-alignment item must export
the actual score/render event authority separately and retain both confidence
labels.

## Bar clock and final partial bar

Source frame zero is the manifest-bound phrase boundary and beat origin. The
fixed 130 BPM, four-beat bar has nearest-frame geometry:

```text
barFrames = nearestInteger(sampleRate * 240 / 130)
```

Bars cover the source contiguously. A final nonempty partial bar retains linear
facts—onsets, grid quantization, silence, rest, and within-bar consecutive
intervals—but cannot close a cyclic interval and is excluded from every
bar-to-bar comparison. It is not padded, extrapolated, or compared as a full
bar.

## Sixteenth grid and microtiming

Every onset is mapped to the nearest of seventeen physical grid lines from
bar start through the next bar boundary. Ties choose the earlier grid line.
The closing line maps cyclically to step zero while retaining its physical
target at `barFrames`:

```text
targetFrame(line) = nearestInteger(line * barFrames / 16), line in 0...16
gridStep = line modulo 16
offsetFrames = onsetFrameInBar - targetFrame(line)
offsetSteps = offsetFrames * 16 / barFrames
```

This keeps an onset just before the next downbeat close to cyclic step zero
with a small negative offset rather than forcing it far from step fifteen.
Each bar retains all onset records, the sixteen onset-count cells, occupied and
rest-cell counts, and mean/maximum absolute microtiming in fractions of one
sixteenth. Grid mutation and microtiming distance remain separate: two bars may
have identical grid counts while their exact onset frames differ.

## Rhythmic rest and exact signal silence

Rhythmic rest is the fraction of the sixteen grid cells with no inferred
onset:

```text
restOccupancy = emptyGridCellCount / 16
```

Exact signal silence is the fraction of source frames for which every source
channel has positive or negative digital zero:

```text
exactSilenceOccupancy = allChannelZeroFrameCount / sourceFrameCount
```

These facts intentionally diverge. A sustained tone after its first activity
rise can have full rhythmic rest and zero signal silence. Equal/opposite stereo
can have full folded-onset rest while remaining nonzero in both source
channels. A digitally silent bar has both values equal to one. None of these
states is detector failure or an automatic quality verdict.

## Inter-onset intervals

Every bar retains positive or zero linear frame distances between consecutive
inferred onsets. A complete active bar additionally closes the cycle from its
last onset through the bar boundary to its first onset. One onset therefore has
one cyclic interval equal to the full bar; two or more cyclic intervals sum to
the exact bar-frame count.

A complete bar without onsets records
`unavailable-no-onsets`; a partial bar records `unavailable-partial-bar`.
Neither fabricates a full-bar interval.

## Named metrical evidence

The report exposes two simple, reconstructable proxies rather than claiming a
perceptual syncopation measurement.

`metricalDisplacement` assigns each inferred onset the following weight and
reports the event mean:

| Sixteenth position | Weight |
|---|---:|
| Quarter-note grid (`0, 4, 8, 12`) | `0` |
| Eighth offbeat (`2, 6, 10, 14`) | `0.5` |
| Odd sixteenth (`1, 3, 5, 7, 9, 11, 13, 15`) | `1` |

`adjacentStrongRestPotential` assigns strength `3` to quarter-note cells, `2`
to eighth offbeats, and `1` to odd sixteenths. It counts an occupied cell when
the immediately following cyclic cell is empty and metrically stronger, then
divides by occupied grid cells. This is a named one-cell strong-rest proxy. It
does not model note duration, perceptual grouping, accent, meter induction, or
a listener's judgment of syncopation.

Bars without inferred onsets encode both metrical values as explicit `null`.

## Bounded bar comparisons

Every complete bar compares with at most the four preceding complete bars.
Order is deterministic: current bar ascending, then lag one through four.
No unbounded history or all-pairs corpus comparison exists.

Each comparison retains these independent facts:

- `exactPCMRepeat`: every source-channel Float32 bit pattern matches across the
  two bar windows;
- `exactOnsetFrameRepeat`: the ordered onset-frame offsets match;
- `gridMutationDistance`: cell-count L1 difference divided by the combined
  onset count;
- `gridSimilarity`: cellwise count minima divided by cellwise maxima;
- `bestReferenceForwardRotationSteps`: the lowest of all sixteen forward
  reference rotations producing the minimum mutation distance;
- `bestRotationMutationDistance`: that minimum distance;
- `matchedMicrotimingDistanceSteps`: mean absolute offset difference for
  sorted onset pairs that occupy the same grid cell.

The mutation distance lies in `0...1`. Identity has distance zero. Adding one
event to a four-event pattern yields `1 / 9`; disjoint equal-count patterns
yield one. A cyclic rotation can have a positive direct distance and zero best-
rotation distance. Level or event-body changes may make `exactPCMRepeat` false
while exact onset and grid facts remain unchanged. These relations distinguish
known fixtures without declaring any distance desirable.

If neither bar has an inferred onset, the rhythmic comparison is
`unavailable-no-onsets-in-either-bar`. Exact PCM equality remains recorded as a
signal diagnostic, but onset identity, grid distance, similarity, rotation,
and microtiming encode as explicit `null`. Two silent or sustained no-onset bars
are therefore not called perfect rhythmic repetition by default. If only one
bar has onsets, the comparison is available with mutation distance one and no
matched-microtiming value.

## Aggregation

Asset summaries retain bar/partial/silence/onset/comparison counts, exact PCM
and onset-repeat counts among available comparisons, and arithmetic means over
complete bars or available comparisons. Null per-bar metrical values do not
enter their means. Unavailable comparisons do not enter rhythmic distance or
repeat counts. Raw bars and comparisons remain present so every aggregate can
be independently reconstructed.

Aggregation is descriptive. It is not weighted by loudness, checkpoint,
duration beyond the complete-bar rule, role importance, or a learned model.

## Operation

Normal verification runs the synthetic Swift fixture bank and independent
Python mutation bank. Exact corpus export and finalization are opt-in and
local-only:

```bash
AUTOTECHNO_RUN_RHYTHMIC_BASELINE=1 \
  swift test -c release --jobs 1 --no-parallel \
  --filter RhythmicBaselineIntegrationTests
python3 scripts/rhythmic_baseline_report.py generate
python3 scripts/rhythmic_baseline_report.py check
```

The exporter requires the current AT-0016 manifest. When the source or
execution-contract fingerprint changes, the upstream whole-mix manifest must
be regenerated and its PCM relationship to the prior exact corpus proved
before this report can be finalized.

## Qualification boundary and limitations

Swift fixtures cover exact loop identity, one-event mutation, unrelated churn,
cyclic rotation, level/event-body variation, exact silence, sustained activity,
phase cancellation, metrical displacement, adjacent strong-rest potential,
microtiming, 44.1/48 kHz normalization, cyclic intervals, final partial bars,
explicit-null serialization, and malformed input. Python independently
reconstructs the complete evidence and rejects policy, manifest, metadata,
bar, comparison, aggregate, and report-fingerprint mutations.

This baseline does not determine groove quality, preferred repetition,
acceptable variation, perceptual syncopation, humanization, swing correctness,
motif identity, section contrast, tension, fatigue, role importance, score
agreement, professional quality, listening approval, app/route behavior, or
physical-output soak. It changes no rendered sample, accepted score, runtime
evaluation, continuation, fallback, or future-boundary decision. Any later
calibrated relation must enter the one evaluator/controller only through its
own roadmap item and independent qualification.
