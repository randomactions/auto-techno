# Hypnotic Channel Band-Limited Slicing Design

**Status:** Implemented and deterministically qualified locally on 2026-08-25;
listening, real app/route QA, latency observation, and physical-output soak
remain separate and unrun

**Canonical base:** `93ce7aa4a9fcf11a4b9b41f864c2cfabf7f99c78`

## Objective

Replace the canonical phrase slicer's linear sample lookup with one bounded,
deterministic band-limited interpolator. Keep the existing score-owned source,
trigger, rate, direction, gain, edge fade, continuation, and fallback contracts.
The change should make the current variable-rate and reverse gestures cleaner;
it must not add an imported sample dependency, granular side engine, selectable
preset, alternative renderer, track, bus, or user control.

## Research boundary

The clean-room pass used unauthenticated `yt-dlp` against the live Hypnotic
Techno Production videos page on 2026-08-25. The inventory contained 148
videos. Automatic English captions yielded usable text for 137; eleven
original-mix uploads had no usable technical transcript. Captions, descriptions,
metadata, comments, and generated audit intermediates remain local and
untracked. The durable repository record paraphrases the sources rather than
retaining transcript text.

Several independent videos revisit the same portable sound-design behavior:

- `f4tdX3LsKj0`, 3:13-4:24: short or looped grains, sample-position scan, and
  bounded grain-size movement turn existing rendered material into a moving
  percussive texture;
- `14XvqkwuyDo`, 6:11-9:39: transient slicing and a second transformation of
  the same source produce chops or an atmospheric supporting layer;
- `Uv_QrTAhJUk`, 1:22-4:17: grain size and file position move slowly enough to
  keep a texture alive, followed by existing filter movement;
- `kMtHD7g189k`, 1:03-2:31 and 8:13-8:17: bounded grain-size/position variation
  and resampling print an existing internal source and its effects;
- `866K0HzrCR4`, 1:08-1:52: grain length, spray, and downward rate/pitch motion
  create an organic secondary texture;
- `PDky7n7jD-o`, 1:59-5:51: source-position movement and bounded grain change
  keep a reused source from remaining static;
- `f5KCnx5_V60`, 3:21-3:48: a transformed texture can continue through the
  existing modulated filter path instead of requiring another effect chain.

Four hypothesis-driving videos yielded 21 top-level comments and 15 replies in
top sort. The sample contained isolated requests for time stretching and manual
filter automation, plus general granular-workflow interest. It did not contain
three independent materially matching technical observations, so no community
convergence is claimed and no comment supplies a DSP target.

The videos motivate only the transformation relationship. Their software,
samples, presets, settings, narration, audio, creator identity, and workstation
workflow do not enter the implementation or qualification policy.

## Reuse versus expansion

The current runtime already has the correct causal owner:
`PhraseCompositionResolver` selects phrase-local app-owned kick or percussion
PCM, up to six score-owned triggers, rates from 0.5 to 2, forward/reverse
direction, gain, and a future phrase boundary. `AudioSliceRenderer` consumes the
same resolved score during detached preparation and emits exact source/output
hashes, rate/direction counts, RMS, and finiteness.

A granular instrument, grain-delay return, external recording lane, or fixed
effect rack would duplicate that owner and introduce a second engine shape.
Likewise, source-position or grain-size parameters without a demonstrated
score-to-PCM-to-quality path would be hidden controls. The smallest truthful
expansion is therefore a reusable interpolation capability inside the existing
renderer. Existing score variation remains the creative operator.

## Measured deficit

Before implementation, a deterministic 48 kHz probe rendered an 18 kHz source
through the current supported 2x trigger. The intended 36 kHz result is above
Nyquist, but linear lookup folded it to a 12 kHz output component with measured
amplitude `0.5`, equal to the trigger gain. This is a direct, capability-local
aliasing failure, not a listening preference or source-derived threshold.

The implementation is disconfirmed if the same probe does not reduce the false
12 kHz component by at least 40 dB while a supported in-band tone retains its
expected pitch and useful amplitude. It must also preserve exact deterministic
replay, bounded edge fades, direction semantics, finite output, and neutral
fallback.

## DSP contract

Add one reusable, stateless windowed-sinc sample lookup in `AutoTechnoDSP`:

- a fixed 16-sample radius bounds work and storage;
- exact integer positions at unity or other rates return the source sample when
  no anti-alias filtering is required;
- downsampling uses a deterministic safety cutoff of `0.94 / playbackRate`
  relative to source Nyquist;
- unity and slower playback use the full normalized bandwidth;
- a symmetric Hann-windowed sinc kernel is normalized for bounded edge access;
- source indices clamp to the already-resolved slice window, and the existing
  4 ms trigger edge fade remains authoritative;
- non-finite or invalid render inputs continue to return neutral evidence.

`AudioSliceRenderer` replaces only its linear interpolation expression with
this lookup. Rate, direction, destination, source geometry, output length, gain,
and mixing remain unchanged. The renderer still produces signal evidence in
the same pass. Canonical engine identity and quality schema advance because PCM
changes; the candidate-vector shape need not change because existing evidence
already binds rate, direction, source PCM, output PCM, RMS, and finiteness.

## Ownership, continuation, fallback, and consolidation

1. **Canonical owner/state:** `PhraseCompositionResolver` and `AudioSlicePlan`
   remain the only decision owner; `AudioSliceRenderer` remains the only PCM
   owner.
2. **Reusable capability:** fixed-radius band-limited variable-rate sample
   lookup for both percussion- and kick-sourced canonical slices.
3. **Automated deficit/evidence:** the pre-change 0.5 alias amplitude, focused
   spectral rejection/retention tests, existing same-pass slice hashes/RMS, and
   exact-engine primary qualification.
4. **Bounds/continuation/future boundary/fallback:** existing 0.5-2 rate, six
   triggers, two-step source, edge fade, phrase-boundary score resolution, and
   neutral invalid/ineligible result are unchanged; the stateless kernel adds no
   continuation state.
5. **Duplicate avoided:** linear interpolation is replaced in place; no granular
   renderer, sample library, track, effect return, preset selector, or callback
   path is added.

## Realtime boundary

The slice renderer is reached only while preparing immutable PCM before
scheduling. The new kernel owns no lock, allocation that crosses into the
callback, file or network I/O, logging, UI work, mutable global state, or audio
route behavior. The app's render callback, lock-free handoff, buffer ownership,
and scheduled transport remain unchanged.

## Verification

1. Replace the baseline probe with an A/B regression that retains the historical
   linear result and proves at least 40 dB alias rejection from the new path.
2. Prove in-band pitch/amplitude retention, unity exactness, deterministic
   forward/reverse replay, supported-rate bounds, edge fades, finite output,
   neutral fallback, and source/output evidence.
3. Re-run phrase-composition resolution, integrated candidate evidence,
   architecture, current-runtime, and callback-symbol tests.
4. Advance the canonical engine and quality schema, then regenerate and replay
   the exact-engine development, adversarial, and disjoint-holdout artifacts;
   never relabel v14 evidence as qualification for changed PCM.
5. Run an optimized build and keep listening, app/route/interruption QA, latency
   observation, and physical-output soak as separate unclaimed stages.

## Final deterministic result

The 18 kHz-at-2x probe reduced the false 12 kHz alias from the retained linear
baseline amplitude `0.5` to `0.00007865537190809846`, approximately 76 dB of
rejection. The in-band 3 kHz-at-2x probe retained the expected 6 kHz result,
unity playback remained sample exact, and invalid inputs remained neutral.

Exact engine v33 / schema 34 qualification produced primary profile
`ff7af0095e7ba020`, adversarial suite `66173a58f449a0ca`, and holdout
`7f0b78b722d9df74`. All 28 development journeys and all 56 observations in four
disjoint holdout journeys passed with zero relationship failures. A separate
cached replay produced byte-identical JSON for all three artifacts.

Because the long-horizon policy binds the primary identities, it was regenerated
as resource family v2. Profile `064fa15feae8c659`, adversarial suite
`ae03b76dd06f5a95`, and holdout `caca721cda969d77` accepted four development
roots and two disjoint four-hour holdout roots at 44.1/48 kHz. Re-evaluation
from the saved reduced corpora reproduced all three files byte for byte.

The final post-test optimized product built in 88.54 seconds with SHA-256
`e29363ebe6021b1fb7b9ce485686956de0d133edc8d7340f4e9447e6a2e2dcb2`. The
workflow-equivalent realtime producer audit found only the allowed `memcpy`
undefined symbol.
