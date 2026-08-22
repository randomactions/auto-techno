# Source 30: score-owned pad amplitude gate

## Source evidence

- Video: `https://www.youtube.com/watch?v=DxyQNgNKUf8`, *The trance gate
  technique*, Underdog Electronic Music School, accessed 2026-08-22.
- Transcript: YouTube automatic English captions retrieved with `yt-dlp`
  2026.08.19. The `en` and `en-orig` VTT files were byte-identical with
  SHA-256
  `0fa8fc4f1ee49c4b24bfebb768ff9cd4cd1585e4c9926904ab7b0853bb4d28f1`.
  The structured English JSON3 capture had SHA-256
  `001a988bb693e413a8a14523bd78f3c84e03979ea21900426413a93507475fce`.
- Page discussion: 50 top-ranked top-level comments and 12 replies across six
  reply threads were sampled. One technically specific thread preferred a
  programmable note/hat trigger because it makes the rhythm independently
  controllable; another recalled manually writing channel-volume changes;
  several described applying the relationship to pads or voices, and one
  suggested delay after the chop. These support score-owned amplitude rhythm
  and a retained spatial response, not an audible trigger track or plug-in
  dependency.
- Audio demonstration: direct unauthenticated extraction decoded to 48 kHz
  stereo PCM with duration 547.392 seconds and SHA-256
  `56eb5ffbbb18b207fe5aa2f06d17c0c5d5916057193015c25e63b0707cae0f7e`.
  A 100 ms momentary-loudness trace spanned about 15.5 LU in the first gated
  synth demonstration, 26.7 LU while release was adjusted, and 36.7 LU in the
  gated voice demonstration. This supports strong repeated level contrast; it
  does not establish a portable threshold, timing, pattern, release, or level.
- Relevant source claim: a sustained, space-filling source can acquire rhythm
  when an independent trigger opens and closes its amplitude. A trigger every
  three sixteenths is presented as one useful starting point, and the release
  controls whether the result is snappy or connected. Reverb before or after
  the gate changes the texture and retained space.

The updated yt-dlp installation solved the current JavaScript challenge with
its local Deno runtime. No account, cookie, CAPTCHA, browser session, or PO-token
provider was used. Captions, comments, metadata, audio, thumbnail, and machine
inspection remain temporary and untracked.

## Falsifiable deficit

The canonical engine already has the correct musical source and rhythmic owner:

- `PadRhythmicModulation` is score-owned, phase-continuous across phrase
  boundaries, and active only on naturally resolved latter-half major-break
  pads;
- its `threeStepPulse` cell already moves the existing pad low-pass and spatial
  send without adding notes, tracks, instruments, or returns;
- `PolyphonicPadVoice` already advances bounded oscillator, filter, envelope,
  and spatial continuation during detached preparation;
- candidate and professional evidence already bind the three-step score,
  filter consequence, spatial consequence, neutral path, and calibrated
  activity.

The missing consequence is amplitude articulation. Current active bars remain
continuous in level: only filter colour and send amount pulse. The hypothesis
is falsified if the existing three-step pad already contains route-stable exact
closed windows with a causal dry-and-send amplitude difference. It is supported
when the same score relation creates bounded, click-safe open cells and exact
closed cells while the underlying pad and effect states continue, and every
neutral or ineligible bar remains bit identical.

## Causal shape decision

Mature the existing `PadRhythmicModulation.threeStepPulse` owner in place. Do
not add an inaudible trigger track, sidechain bus, generic gate effect, new pad,
sample, voice source, sequencer, alternate renderer, random draw, callback
controller, plug-in host, or user control.

The tutorial's trigger track is a workstation routing technique, not durable
musical state. The canonical score already carries the independent rhythm more
truthfully and deterministically. A second gating relation would duplicate that
owner. Source 30 therefore extends the established three-step relation with one
reusable amplitude consequence and preserves the filter/spatial choreography
introduced by Source 24.

## Score and gate geometry

Keep all existing eligibility and score identity:

- only a naturally resolved `majorBreak` pad in breakdown, macro positions
  8...14, with neither minimalize nor structural-marker gesture owns the active
  relation;
- absolute-bar phase continues the three-sixteenth cell across phrase and bar
  boundaries;
- cell index 1, already the maximum filter-opening stage, is the sole open
  sixteenth; indices 0 and 2 are exact closed targets;
- the established filter scales `[0.38, 1.0, 0.62]` and spatial-send scales
  `[0.72, 0.85, 1.28]` remain authored by the same relation;
- `PadRhythmicModulation` exposes the exact three-step amplitude target and its
  combined pattern fingerprint; no free scalar enters the score.

The one-open-in-three shape adapts the source's starting rhythm to the already
authored three-step pad cell. It is not a copied preset or user-selectable
pattern.

## Renderer and continuation

During detached preparation, extend `PolyphonicPadVoice` at its existing local
boundary:

- render and advance all four pad voices, filters, envelopes, and phase exactly
  as today;
- compute the existing filter-only and spatial-scale-only reference paths so
  their evidence keeps its prior meaning;
- apply one fixed physical-time raised-cosine attack and release inside every
  score-open sixteenth, reaching exact zero at both edges;
- multiply both the filtered dry pad and its existing spatial-send input by the
  same amplitude gate before either enters its current destination;
- write literal positive zero throughout closed target steps while underlying
  continuation advances, so the next opening resumes the sustained source
  rather than retriggering it;
- use route-derived frame geometry at every supported rate; degenerate or
  malformed input fails neutral and finite.

The transition duration is renderer policy, bounded well below one sixteenth,
and not a new score parameter. The neutral path executes the pre-Source-30
operations without another multiply and must remain bit exact. This adds no
real-time work and changes no app, route, scheduler, callback, or live-feedback
surface.

## Same-pass evidence and policy

Extend the existing `PolyphonicPadRenderEvidence` and singular phrase-
composition candidate record rather than adding a parallel gate collection.
Bind:

- score relation, absolute phase, combined filter/send/amplitude target
  fingerprint, and route-derived transition frames;
- exact minimum/maximum gate gain, open and closed frame counts, and literal
  zero in every closed dry and send frame;
- pre-gate and post-gate dry hashes, pre-gate and post-gate spatial-send hashes,
  dry and send gate-difference RMS, and finite bounds;
- preservation of the existing filter-only and spatial-scale-only difference
  measurements;
- equality across full and protected render passes, exact neutral identity,
  continuation replay, and home-correction replay.

Candidate completeness requires one exact score-derived gate, positive open
energy and gate-difference energy, nonempty exact closed windows, and zero
closed-window RMS. Missing, moved, disconnected, contaminated, forged-hash,
wrong-phase, wrong-route, or nonfinite evidence fails closed.

Add one Professional Evidence dimension,
`pad-rhythmic-amplitude-gate-difference-to-pad-db-mean`. It is a calibrated
two-sided consequence metric; a dedicated non-compensable disconnected-gate
attack moves it below the learned major-break range. Advance engine, quality,
candidate, observation, evidence-bank, adversarial, holdout, and primary
evaluator identities, then regenerate the exact profile, adversarial suite, and
disjoint holdout.

## TDD and validation

- Extend Core tests first for the exact `[closed, open, closed]` cell, absolute
  phase continuation, unchanged eligibility, bounded score values, and neutral
  paths.
- Extend pad DSP tests first for route-derived attack/release geometry at 8,
  44.1, 48, 96, and 192 kHz; exact closed dry/send samples; positive open
  energy; no boundary click; unchanged voice continuation; and neutral bit
  identity.
- Preserve independent filter-only and spatial-scale-only evidence tests, then
  add pre/post hashes, gate-difference RMS, closed counts/RMS, malformed-input,
  and pattern-fingerprint assertions.
- Extend prepared phrase-composition and candidate tests for score-to-PCM
  binding, decoded bounds, forged phase/hash/count/zero rejection, correction
  equality, cancellation, and retained-record limits.
- Add metric extraction, calibration floor/range, the non-compensable
  disconnected-gate scenario, exact regenerated artifacts, and disjoint
  holdout qualification.
- Run focused Core/DSP/prepared tests; candidate/live tampering; exact artifacts;
  calibration, policy, holdout, atomic commit, unsupported-rate, route,
  cancellation, correction, representative-rate, resource, continuation,
  Core/evidence, preparation, protected-routing, and repository-surface
  matrices serially.
- Audit the realtime-producer object, build the optimized app, inspect the clean
  diff and public text, refresh/rebase on main if required, push main and the
  source branch, and require exact-head GitHub Actions success.

## Maturation boundary

The durable idea is that one sustained tonal owner can recover rhythmic energy
through a separate score-owned amplitude pattern while its synthesis and space
continue underneath. Source 30's one-open-in-three mask, fixed raised-cosine
edges, and full-band linked dry/send projection are replaceable realization
details.

A later serious renderer may replace them in place with higher-resolution
control-rate envelopes, tempo-aware variable duty, transient-conditioned
attack/release, multiband or stereo-linked gating, envelope-aware nonlinear
colour, or a denser diffusion response only when calibrated motion, masking,
boundary, or translation evidence exposes a repeatable deficit. It must
preserve the existing pad and three-step score owner, absolute-time phase,
advancing continuation, exact neutral behavior, bounded score-to-PCM evidence,
and one primary evaluator. It must supersede this gate rather than coexist as a
second trigger lane or generic gate effect.
