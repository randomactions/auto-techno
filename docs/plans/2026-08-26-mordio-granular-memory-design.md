# MORDIO granular-memory sound maturation

Date: 2026-08-26
Status: exact-engine and release validated; feature release published to `origin/main` as `9d0956a`

## Source and deficit

The complete MORDIO channel audit inventories 276 videos. Original-language
captions were available for 219; 57 are explicitly title/metadata-only. The
usable evidence contains 34 videos mentioning granular/resampling and two
additional looping/stutter-memory contexts, with independent examples spanning
Granulator, Solstice, Celestine, Tape Fiasco, Ableton Looper, Torso S-4,
SOMA Cosmos, Tardigrain, Robert Henke's granular instrument, feedback sampling,
and resampling workflows.

Those sources are not authority and do not imply that Auto Techno should clone
their products. Reconciliation exposed one repeatable internal deficit: the
canonical phrase-local `AudioSliceRenderer` could transpose and reverse one
whole source window, but could not reinterpret that same accepted bar-owned PCM
as overlapping micrograins. All other named synth, effect, chain, modulation,
and sequencing ideas map to existing owners or the standalone boundary.

## Existing canonical owner and extended state

`PhraseCompositionResolver` already owns whether a major-break bar receives an
`AudioSlicePlan`, its source window, source kind, and bounded triggers.
`AudioSliceRenderer` already owns detached preparation of the exact rendered
source window. `AutonomousPhraseCompositionBarEvidence` already binds the plan
to its renderer consequence and primary candidate. This change extends those
owners; it adds no engine, sampler lane, audio recorder, selector, preset
browser, or alternative score.

The score adds:

- `AudioSliceTexture.cut`, the exact established behavior;
- `AudioSliceTexture.granularMemory`, selected only for Ambient Drift;
- one deterministic `textureSeed`, fingerprinted with the resolved plan.

Broken Suspension remains `cut`, which is also the exact fallback for every
non-Ambient plan.

## Reusable engine capability

During detached bar preparation, `granularMemory` reads only the existing
source window. Each trigger uses a 0.375-step Hann-windowed grain, a 50% hop,
the existing band-limited interpolator, the established 4 ms outer edge fade,
and at most 48 grains. Source positions are deterministic functions of the
score seed, trigger ordinal, and grain ordinal. Grain duration scales with the
route sample rate and fixed 130 BPM step geometry, so its physical duration is
stable across supported rates.

The renderer exposes exact, causal evidence for texture, seed fingerprint,
grain count, grain length/hop frames, source-position hash, source PCM hash,
output PCM hash, RMS, finiteness, directions, and playback-rate bounds. The
candidate validator requires exact score/render binding and rejects neutral,
cut, or granular evidence that contains fields belonging to another state.

## Automated quality evidence

The focused executable tests establish the local causal witness:

- the original `cut` branch remains byte-for-byte exact;
- identical source/plan/seed replays identical PCM and evidence;
- changing only the seed changes the source-position hash and output PCM;
- grain physical duration agrees at 8 and 16 kHz within one 8 kHz frame;
- grain count, hop, hashes, RMS, finiteness, and maximum work are bounded;
- an integrated Ambient Drift plan selects and renders granular memory;
- an integrated Broken Suspension plan remains on exact cut fallback.

The release cut advances the quality schema, canonical engine, candidate
vector, professional evidence, primary profile/evaluator/artifacts, evidence
scope, and long-horizon policy artifacts. Development, adversarial, disjoint
holdout, byte-replay, the full serialized test suite, and the optimized build
all pass under those new exact identities. Publication remains a separate
repository action.

## Bounds, continuation, boundary application, and fallback

- Decision: pure Core resolution at the existing future bar boundary.
- Preparation: state-free DSP over the current bar's already-rendered source.
- Work: at most six triggers and 48 grains per trigger; no unbounded search.
- Memory: current source/output arrays only; no retained recording or cross-bar
  PCM.
- Continuation: only the resolved score seed persists through normal plan
  identity; no renderer-side mutable musical state exists.
- Fallback: all non-Ambient plans and any invalid render input use the exact
  existing cut/neutral contracts.
- Live path: no callback, queue, scheduler, route, or live-feedback code changes.

## Duplicate avoided

This consolidates the reusable micrograin behavior into the existing slicer.
It deliberately avoids branded emulations, a second granular synth, a looper
recorder, a hardware/VST dependency, fixed arrangement templates, source-local
special cases, and a second evaluator. Creative use remains director-owned:
Ambient Drift can turn its locally rendered kick or percussion memory into a
soft, seed-stable spatial texture while the same canonical score, graph,
continuation, correction, fallback, and primary quality loop remain in force.
