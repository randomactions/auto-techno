# Source 29: score-owned climax hang

## Source evidence

- Video: `https://www.youtube.com/watch?v=n3lvFEsf1O0`, *Two types of
  break for electronic music*, Underdog Electronic Music School, accessed
  2026-08-22.
- Transcript: YouTube automatic English captions retrieved with `yt-dlp`
  2026.07.04. The `en` and `en-orig` VTT files were byte-identical with
  SHA-256
  `6d676ac24c73bbecff40510296f1c82c08f18f051f64e77adcb665da7370bf82`.
- Page discussion: 50 top-ranked top-level comments and 12 replies across
  seven reply threads were sampled. Discussion independently supported energy
  contour as a useful model, reported that a sparse noise/snare/synth build was
  more effective than dozens of effects, and warned that literal break formulae
  become predictable or interrupt dance-floor continuity when overused.
- Audio demonstration: the original-English local extraction was decoded to
  48 kHz stereo PCM with SHA-256
  `0e5f5de0846e3dfd8072ad109539388e3ab07c20121fe9db95103856332c8bae`.
  Machine inspection of the demonstrated trilogy break found a roughly
  1.75-second low-energy interval before the recovery transient. This is
  descriptive source evidence, not human listening or promotion evidence.
- Relevant source claim: a large break can be understood as `fall -> rise ->
  hang -> recovery`; the hang is a short silence after the expected recovery
  point. The source explicitly warns against making this an obligatory formula.

The audio path required the established pinned temporary PO-token provider:
`Brainicism/bgutil-ytdlp-pot-provider` 1.3.2 at exact commit
`7511309af023b09788dc8f2efc96cc3671291e6c`. Captions, comments, page metadata,
audio, thumbnails, provider files, and analysis images remain local and
untracked.

## Falsifiable deficit

The canonical director already owns the rare fall, rise, and recovery:

- `majorBreak` removes foundation and reduces rhythmic density while opening a
  dramatic debt;
- the paid-debt `energyRelease` restores density and the existing
  `anticipationSwell` rises through the second kick-withheld bar;
- the unchanged structural recovery bar restores the grounded kick.

The missing consequence is a measurable hang between the swell and recovery.
The current anticipation return runs until step 16, and the final weak groove
pulse is scored at step 15, so energy continues to the bar boundary rather than
letting the expected recovery arrive late.

The hypothesis is falsified if the accepted final withheld bar already contains
an exact terminal full-mix silence before recovery. It is supported when one
bounded score articulation removes late onsets, closes the existing swell,
creates exact-zero terminal PCM, and leaves the next recovery bar and every
ineligible phrase unchanged.

## Causal shape decision

Extend the existing dramatic-debt climax arc, kick syntax, and percussion-return
relationship. Do not add a break engine, track, instrument, noise generator,
riser preset, effect bus, alternate candidate, transport clock, callback
controller, or user-facing mode.

The source's linear-break and fall/rise material already has canonical owners.
Adding another arrangement path would duplicate them. A dedicated white-noise
riser would also overfit an optional demonstration and contradict the stronger
sparse-build evidence. The reusable missing capability is a score-owned terminal
hold that any later renderer may realize more richly under the same climax-arc
contract.

## Score articulation

Add one Core-owned `ClimaxHangArticulation` only to the existing second
kick-withheld paid-debt release bar:

- phrase kind is `energyRelease`, paid debt has already authorized the canonical
  `grounded -> withheld -> withheld -> recovery` arc, character is Peak Drive
  or Acid Pressure, the gesture is steady, and macro position is 14;
- the hang begins at score step 12 and ends at step 16, exactly one beat or
  about 461.5 ms at fixed 130 BPM;
- the one-beat bound intentionally adapts the source's larger demonstration to
  an endless autonomous runtime and its anti-overuse warning;
- ensemble events at or after step 12 are removed before rendering; the final
  withheld groove-pulse mask becomes steps `3, 7, 11`, while the first withheld
  bar retains the established `3, 7, 11, 15` mask;
- the existing `anticipationSwell` remains the rise owner but closes exactly at
  the hang start rather than at the bar end;
- debt-free, non-release, non-syntax, first-withheld, recovery, correction-home,
  and conservative paths remain literal neutral.

The articulation is immutable score data and enters the typed plan fingerprint.
It owns no cross-bar state. The existing recovery bar remains at the same sample
boundary with the same displaced kick, score, and renderer path.

## Renderer and continuation

Detached preparation applies a bounded terminal hold after the canonical graph
has rendered and before the existing live-master trim:

- a short physical-time raised-cosine release reaches exact zero at score step
  12;
- every stereo sample from step 12 through the end of the bar is exact zero;
- the neutral path returns the pre-feature arrays without an extra multiply;
- graph, voice, and effect continuation continue deterministically beneath the
  hold, so the next bar reuses the established continuation and no hidden reset
  is introduced;
- the existing live-master trim remains the final scalar, and exact zero remains
  zero for every legal trim state.

This is preparation-time PCM shaping only. It allocates no callback buffer,
adds no real-time branch, and changes no scheduler, route, app transport, or live
feedback decision.

## Same-pass evidence and policy

Extend the existing singular climax-arc evidence with a compact nested hang
record rather than adding another parallel evidence collection. Bind:

- score relation, bar, start/end steps, and removal of post-start onsets;
- route-derived release/silence frame geometry and exact recovery boundary;
- pre-hold and post-hold stereo fingerprints;
- positive pre-release RMS, exact-zero silence hash/peak/RMS, and zero nonzero
  sample count in the hang;
- post-hold fingerprint equality with the existing live-master pre-trim input;
- exact plan bar, paid-debt, second-withheld, anticipation-return, and recovery
  ownership.

Active climax recovery is complete only when this hang is active on the second
withheld bar. Debt releases without the canonical four-bar syntax retain the
neutral hang sentinel. Home-upper correction must replay the same hang and PCM;
malformed geometry, contamination, moved bars, missing onset suppression, or
detached evidence fails closed.

Add one Professional Evidence dimension,
`climax-hang-silence-rms-maximum`. It is upper-only safer and uses a near-zero
physical guard. A dedicated non-compensable contamination attack raises the
metric beyond the installed profile. Regenerate the exact primary profile,
adversarial suite, and disjoint holdout after advancing engine, quality,
candidate, observation, evidence-bank, adversarial, holdout, and primary
evaluator identities.

## TDD and validation

- Add failing Core tests for exact second-withheld eligibility, one-beat
  geometry, final groove-pulse/onset removal, deterministic replay, fingerprint
  sensitivity, and neutral debt-free/first-withheld/recovery paths.
- Add failing route-rate renderer tests at 8, 44.1, 48, 96, and 192 kHz for
  release geometry, exact terminal zero, finite output, positive preceding
  energy, neutral bit identity, and next-bar recovery.
- Add a prepared-product test proving the final withheld bar owns the hang,
  anticipation closes at step 12, the existing recovery kick remains unchanged,
  and full/protected/effect evidence remains attributable.
- Extend climax-arc candidate JSON, typed fingerprinting, decoded bounds,
  malformed/tamper rejection, cancellation, correction equality, and retained
  record limits.
- Add metric extraction, safer-bound behavior, the non-compensable contamination
  scenario, regenerated exact artifacts, and disjoint holdout qualification.
- Run focused tests; candidate/live tampering; exact artifacts; calibration,
  policy, holdout, atomic commit, unsupported-rate, route, cancellation,
  correction, representative-rate, resource, continuation, Core/evidence,
  preparation, protected-routing, and repository-surface matrices serially.
- Audit the realtime-producer object, build the optimized app, inspect the clean
  diff and public text, rebase on refreshed main if it moved, push main and the
  source branch, and require exact-head GitHub Actions success.

## Maturation boundary

The durable idea is a rare score-owned delay of an already-earned recovery: a
rise closes into a bounded absence, then the established recovery arrives. The
v1 one-beat duration, two-point terminal curve, and exact-zero proxy are
replaceable realization details.

A later serious renderer may replace them in place with role-selective
continuations, a retained vocal or tonal foreground over a silent rhythm canvas,
sample-accurate multistage energy envelopes, perceptual expectation evidence,
or a longer director-selected hold only after the primary evaluator exposes a
repeatable payoff deficit. It must preserve dramatic-debt ownership, rarity,
the exact neutral path, future-boundary application, deterministic continuation,
same-pass evidence, and one canonical evaluator. It must replace this v1
realization rather than coexist as another break mode.
