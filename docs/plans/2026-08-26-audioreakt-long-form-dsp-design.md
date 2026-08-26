# AudioReakt Long-Form DSP Design

**Status:** implemented and verified locally; listening and hardware soak remain separate

## Objective

Use the complete current AudioReakt video corpus as bounded hypothesis input,
then expand the single canonical Auto Techno runtime only where repeated source
claims expose a measurable deficit. Preserve one director, one resolved score,
one renderer, deterministic continuation, the one-button UI, and standalone
operation.

The creative target is a session whose distant points are related but not
identical: minute three and minute fifty should not merely select different
events over a fixed drum source. Kick identity may slowly morph as if adjacent
DJ records were blended, while performance characters can make upper
percussion clap-led, snare-led, or rim-led without becoming a genre selector.

## Source evidence

The authorized 2026-08-25 capture contains 362 videos. English technical
captions are available for 351; 11 have no usable English caption. Every row and
at least one representative excerpt per captioned row were reviewed. Deeper
context searches across the corpus found two repeated portable families:

- kick pitch envelope, pitch depth, body/sub decay, harmonic body, drive,
  transient click/noise, layering, phase, and bounded continuous variation;
- clap/snare layering, pitched body plus noise/wire, shorter rim-like bodies,
  gated tails, rolls or emphasis, and context-dependent prominence.

Arrangement, acid, melodic/trancy, hard/schranz, industrial, organic/ritual,
space, effects, and mixing families reconcile to existing score, synth, effect,
and evidence owners. The full per-video disposition is in
`docs/history/AUDIOREAKT_CHANNEL_AUDIT.md`.

## Deficit AR-DSP-01: kick identity is session-static

### Existing owner

`ResolvedPerformanceBar` owns the canonical bar score and `VoiceRenderer.kick`
owns the one kick source. Before this change, that source used a fixed
scene-seed fundamental and fixed pitch/body/sub/click values for the entire
session. Long-horizon changes could alter kick syntax and mix relationship, but
not source identity.

### Reusable capability

`KickMorphologyResolver` adds one deterministic score trajectory:

- four bounded homes: `anchor`, `round`, `taut`, and `hammer`;
- one 128-bar segment, about 3.94 minutes at 130 BPM;
- adjacent segment homes cannot repeat;
- raised-cosine progress gives exact endpoint continuity;
- the score carries start/end values for fundamental, two pitch-envelope
  depths/rates, body/sub decay, second harmonic, body drive, sub level,
  noise/tonal click level, and click frequency;
- the renderer derives sample progress from score step plus physical time and
  interpolates those values inside the existing kick event loop.

The capability adds no kick voice, preset selector, buffer, render lane, or
free-running state.

### Evidence and qualification

`KickSourceDynamicsRenderEvidence` binds the exact morphology version, score
hash, homes, progress, representative parameter endpoints, and bound status to
the existing exact pre/post source hashes, attack/body/upper-mid energy, peaks,
RMS, and crest reduction. Candidate preparation rejects a render whose
morphology hash differs from the resolved score.

Tests use an independent sample oracle at 8, 44.1, 48, and 96 kHz; check 2,048
resolutions across four roots; and prove minute-three and minute-fifty source
PCM differ at every tested route rate.

### Bounds, continuation, fallback

The resolver accepts nonnegative absolute bars through segment 4,096 and uses
the legacy anchor outside that range. It owns no mutable continuation. A bar is
fully resolved before rendering; the callback path receives already-prepared
PCM exactly as before.

## Deficit AR-DSP-02: one fixed clap body limits section character

### Existing owner

The final `EnsembleContext` already arbitrates `.clap`, `.openHat`, and
`.metallic` events. `UpperPercussionTailArticulation` already owns the natural
versus foreground-clearance tail relationship for those exact events.

### Reusable capability

The articulation now also carries `UpperPercussionBody`:

- non-clap events use the literal `native` body;
- identity returns always use `clap` to preserve recurrence;
- `peakDrive` uses `snare`, combining an analytic 220-to-168 Hz membrane fall,
  a damped inharmonic overtone, filtered wire noise, and a short transient;
- `brokenSuspension` and `ambientDrift` use `rim`, a short damped shell/edge
  model;
- `hypnoticLock`, `acidPressure`, and `melodicGlow` retain the three-burst clap.

This is articulation of the existing score event. It does not create a snare
sequencer, event type, user control, alternative renderer, or fixed genre
section.

### Evidence and qualification

The selected body is part of the typed plan fingerprint and the same-pass
upper-percussion render evidence. Candidate validation requires clap events to
use `clap`, `snare`, or `rim`, requires hats/metallic events to remain `native`,
and binds the evidence body to the exact score event. Tests prove three distinct
deterministic PCM hashes, nonzero attack/body/tail evidence, natural-tail
identity, foreground-clearance causality, and protected subsystem isolation.

### Bounds, continuation, fallback

All bodies are analytic, state-free, finite, and bounded to 160 ms; rim is
bounded to 80 ms. Unknown or omitted legacy clap construction resolves to clap,
while non-clap construction resolves to native. The score is rebuilt after any
ensemble arbitration, so removed or retargeted events cannot retain stale body
intent.

## Canonical data flow

```text
long-horizon state + phrase kind + performance character
  -> AutonomousSessionDirector
  -> ResolvedPerformanceBar
       kickMorphology
       upperPercussionTailArticulations.body
  -> VoiceRenderer existing kick/clap event loops
  -> exact PCM + same-pass scalar/hash evidence
  -> AutonomousCandidateEvaluationVector
  -> exact-engine primary evaluator
  -> accepted immutable phrase / bounded future decision
```

Core owns decisions, DSP owns rendering and evidence, and the App remains
transport/presentation only. Nothing new runs on the real-time callback.

## Qualification-discovered evidence repair

The first complete primary-calibration attempt failed closed at development
root `135791`, 44.1 kHz, release phrase 9. The automatic-mix completeness check
tried to reconstruct its pre-fader active-RMS measurement from the post-fader
active RMS. That statistic is not invertible: the analyzer's activity gate can
change sample membership after Float gain, and one bar differed by
0.0001798 dB despite a truthful controller trajectory.

`AutomaticMixPlan` and candidate evidence now retain the exact pre-fader kick
RMS and active RMS used by the controller. Completeness validates the measured
kick/foundation difference from that exact active RMS at a strict `1e-12` dB
bound, then independently binds the post-fader ungated RMS to the applied gain
within a `1e-6` relative Float-render bound. The controller policy, gain,
score, renderer output, and callback path are unchanged; only truthful detached
evidence was repaired. The exact failing root passes all seven checkpoints at
both 44.1 and 48 kHz, and the complete primary regeneration and replay pass.

The first long-horizon v3 generation then exposed a separate calibration-
sampler mismatch. The sampler stopped after two accepted transitions per
operator even when an optional metric, `mean-wet-to-dry-db`, was observable in
only one of them. The profile constructor correctly rejected that incomplete
per-metric evidence. The sampler now continues until every signal metric has at
least two usable transition measurements at both rates. Root `141421` therefore
retains three recover and three reframe transitions and passes without changing
the policy bounds.

The prior holdout root `112358` next exposed a legitimate brighter rise outside
the original four-root development envelope. It was promoted into a five-root
development corpus rather than widening bounds against the holdout. Fresh root
`173205` replaced it in the disjoint holdout and passed alongside `141421`.

## Identity and artifact cutover

Because both slices change score identity, PCM, and encoded causal evidence,
the cutover advances the canonical engine, quality contract, candidate vector,
Professional Evidence, primary evaluator/profile family, and long-horizon
policy family. The complete representative-rate primary profile, adversarial
suite, disjoint holdout, and long-horizon development/adversarial/holdout family
were regenerated from the exact implementation and replayed byte for byte. The
primary fingerprints are `710ec815fed989fb`, `45b2744234e137d8`, and
`b95f68a1a4771560`; the long-horizon v3 fingerprints are `3c6b7dfeaa63bd76`,
`a0a461a53be020fc`, and `e23e50e67b2dccf7`. No old artifact remains bundled.

## Explicit non-implementations

- no AudioReakt/Serum/Ableton preset names or parameter copies;
- no plug-in, DAW, Push, sample-pack, account, cloud, or reference-audio
  dependency;
- no user-facing style, genre, kick, snare, preset, or chain selector;
- no fixed minute-by-minute arrangement template;
- no duplicate acid, horn, trance, industrial, organic, hardgroove, delay,
  reverb, mastering, or automation engine where a canonical owner already
  exists;
- no comment popularity, title inference, or source listening as promotion
  evidence.

## Validation gates

1. Core trajectory, body policy, typed fingerprint, forgery, and fallback tests.
2. Exact DSP oracle and multi-rate consequence tests.
3. Candidate completeness, same-pass evidence, protected-route equality, and
   deterministic replay.
4. Fresh primary regeneration at 44.1/48 kHz, adversarial rejection, and
   source-disjoint holdout acceptance.
5. Fresh four-hour long-horizon regeneration for development and holdout roots.
6. Full serialized test suite, release build, exact release-artifact launch, and
   PID/path verification. Listening, hardware soak, and shipping remain
   separate unclaimed gates.

The final exact tree passes all 455 serialized release tests. The release app
artifact launches directly and remains independently verifiable by executable
path and PID. No listening verdict, route/interruption session, latency
observation, or physical-output soak is claimed by those automated gates.
