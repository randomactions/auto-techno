# Sound Concept Maturity

This register separates Auto Techno's durable musical language from the current
DSP used to express it. The semantic owner, continuation, fallback, and evidence
contract should survive a renderer rewrite; numeric coefficients and local DSP
topology may change when a later engine revision can prove a better consequence.

The detailed observation and source trail lives in
[`history/TASTE_EXPERIMENTS.md`](history/TASTE_EXPERIMENTS.md). Current product
and qualification policy remain authoritative in [`PRODUCT.md`](PRODUCT.md) and
[`SOUND_QUALITY.md`](SOUND_QUALITY.md). This file is an engineering map, not a
claim that the present sound is mature or professionally qualified.

## Maturity contract

Every sound concept has four separately reviewable parts:

1. **Durable intention** — the musical relationship the director and resolved
   score own.
2. **Current realization** — the versioned DSP that presently changes PCM.
3. **Truth boundary** — same-pass evidence, continuation, bounds, and exact
   conservative fallback.
4. **Maturation path** — richer DSP that may replace the realization after a
   measured deficit and a versioned qualification pass.

A mature rewrite must not silently reinterpret the intention. It must keep one
canonical director/score/renderer path, remain deterministic and off the
real-time callback, preserve protected roles and exact neutral fallback, replace
rather than duplicate the old DSP, emit truthful consequence evidence, advance
the affected engine/schema identities, and pass the current qualification and
runtime-safety gates.

## Current concept register

| Durable intention | Current realization | Truth boundary | Later serious DSP direction |
| --- | --- | --- | --- |
| Weak-position percussion should reveal groove without becoming a second clock. | One bounded weak-sixteenth vocabulary, physical strike/decay articulation, and 3-3-2 accent/ghost grouping on existing onsets. | Event-local score-to-dry-PCM hashes, physical metrics, bounded density, and neutral conservative carrier. | Better drum physical models, oversampled nonlinear transients, role-aware excitation, and perceptually calibrated attack/body/tail relationships. |
| Ordinary upper percussion should breathe around an open-hat companion without changing the groove. | A post-arbitration semantic closed-hat decay role shortens only the matching existing tail. | Exact event pairing, dry hash and envelope evidence; conservative decay is bit-identical neutral. | Continuous or material-aware decay models, richer cymbal resonators, and calibrated cross-role masking while preserving onset and role ownership. |
| Repetition should develop through coordinated upper-role relationships rather than random replacement. | Interlock chapters, a 3-by-5 relational cycle, narrative presence, and bounded role admission reinterpret one stable score identity. | Typed plan identity, role-local upper evidence, bounded continuation, identity-return home state, and conservative fallback. | More expressive modulation networks, smooth multi-rate control, richer long-memory gestures, and calibrated phrase-coherence evidence without adding another sequencer. |
| Shadow and response attacks may spread and reconverge while the anchor and protected rhythm remain fixed. | A score-owned 16-bar aperture delays shadow by half depth and response by full depth. | Exact score/render/applied-gate fingerprints, role-local hashes, literal endpoint zero, and force-home neutrality. | Fractional-delay scheduling, higher-resolution expressive timing, and perceptual phase-spread limits with the same role policy. |
| A delayed effect return may gain body without feeding a driven signal back into its own memory. | The existing filtered pulse-echo return receives bounded, state-free nonlinear low-level lift outside feedback. | Pre/post hashes and metrics, exact transition/changed-sample witnesses, timely-onset eligibility, raw tail continuation, and neutral endpoints. | True upward or parallel dynamics, oversampled colour, multiband or envelope-aware body recovery, stereo-safe diffusion, and calibrated effect-to-dry intelligibility. |
| A percussion source slice may expose only a later authored return window. | One selected existing percussion event feeds a fixed filtered delay whose output is admitted inside a later score-owned gate. | Protected-path input/return hashes, window geometry, nonzero counts, exact-zero endpoints, pass equality, and no captured loop. | Fractional or multitap stereo delay, improved filtering/diffusion, controlled nonlinear colour, and artifact-free gate smoothing within the same input/output semantics. |
| Temporarily removing an established kick can make the same weak-pulse context metrically ambiguous; restoring it should reframe the groove. | A paid-debt energy-release arc owns `grounded -> withheld -> withheld -> recovery` and restores the unchanged step-zero kick. | Exact kick score/render masks and hashes, zero withheld stems, surviving weak-pulse/motif evidence, positive recovery, and grounded fallback. | Perceptually calibrated ambiguity/recovery evidence, richer but still score-owned anchor syntax, and translation-aware low-end recovery without moving transport or bar lines. |
| Resonant Mono should distinguish ordered hollow colour from metallic tension as one patch family. | Acid Thread and Acid Sequence use bounded two-operator phase-modulation relations with an in-note dark-bright-dark aperture. | Exact relation/event fingerprints, operator-tap hashes and metrics, sideband/rate bounds, and zero operator path for non-acid and protected foundation. | Oversampling, better anti-aliasing, more operators or feedback, richer envelopes, stereo-safe upper harmonics, and calibrated low-band/crest bounds. |
| A rising close cluster should build harmonic tension as one transition object without adding melody or density. | The existing Metal Veil transition interprets its existing three oscillator phases as adjacent semitone components while following the already resolved upward trajectory. | Transition-only assignment semantics, exact component ratios and upward frequency facts, an isolated dry cluster hash/metrics, unchanged non-transition texture, and conservative Dark Chord fallback. | Oversampled or band-limited oscillator banks, microtonal/spectral spreading, physical string or resonator models, controlled divergence/reconvergence, and perceptually calibrated tension/harshness evidence. |
| One familiar short tonal gesture may occupy a release boundary at a larger temporal scale without becoming another layer. | The last eligible Tonal Motion anchor at the canonical energy-release marker raises the same note's bounded sustain target and release time through `sustainedWash`; no onset, pitch, gate, instrument, effect route, or density changes. | The typed note relation and attempt eligibility bind an exact active event, base/applied sustain and release, an isolated dry hash, attack/tail metrics, continuation state, and exact conservative or force-home neutrality. | Replace the provisional ADSR projection with a higher-resolution MSEG or exponential envelope, envelope-aware dynamics, oversampled tail colour, or controlled diffusion only after calibrated tail/body and masking evidence identifies a deficit. |
| Timbre and effects can speak as a sentence—call, delayed response, and turnaround—while drums retain attention priority. | The existing motif/response/transition roles, narrative contour, unsynced and pulse echo, long filtered reverb, gated percussion return, and structural gestures already compose this relationship; Source 16 adds no parallel effect-phrase engine. | Current role, effect-state, pulse-return, gated-return, masking, stem, protected-rhythm, transaction, and continuation evidence remain the owners. Shipping selection stays uncalibrated. | Add phrase-level effect-body and call/response/turnaround evidence first; only then consider envelope-aware upward dynamics, denser diffusion, spectral morphing, or shared-return orchestration. Preserve the drums' attention budget and consolidate the existing paths rather than layering another phrase system. |

## Revisit triggers

A concept is ready for another DSP level only when at least one exact canonical
checkpoint exposes a repeatable deficit that existing evidence cannot resolve,
and the proposed replacement can be evaluated without subjective constants from
the motivating video. Typical triggers include aliasing or artifact evidence,
weak role attribution, poor translation across supported rates, implausible
envelope geometry, insufficient phrase consequence, or a calibrated relational
profile failure.

Human listening, videos, and comments may identify the hypothesis. They do not
select an implementation or promote it. The replacement must still pass
deterministic automated qualification, exact-head CI, app/route checks, and the
separate physical-output soak required for its release claim.
