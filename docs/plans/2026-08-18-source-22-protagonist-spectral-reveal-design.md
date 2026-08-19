# Source 22 Protagonist Spectral Reveal Design

**Status:** Ready for implementation on 2026-08-18

**Video source:** `ByjKEl_uO9g`, *The Fred Again.. phenomenon (5 lessons)*,
Underdog Electronic Music School

**Canonical base:** `29e35380f151a8008f3d6db0cdec7ea3c43729d6`

## Objective

Let an emerging dominant motif disclose spectral detail as its already-resolved
narrative presence rises, without changing its notes, rhythm, velocity, patch,
effect access, supporting roles, transport, or density. The relation must reach
both current foreground-capable synth architectures, retain exact open-filter
home behavior, produce same-pass score-to-cutoff-to-PCM evidence, and remain
replaceable when the DSP matures.

This is an extension of the canonical narrative articulation, resolved upper
notes, and instrument filters. It is not a new track, synth, sidechain, effect
return, sequencer, runtime, or user-facing control.

## Research boundary

The clean-room pass used unauthenticated `yt-dlp` for metadata, automatic
English captions, and the protocol's top-ranked comments. Current YouTube media
delivery additionally required the official yt-dlp PO-token workflow through a
temporary localhost provider; the provider and all source media remained under
`/private/tmp` and were stopped after a 48 kHz stereo WAV was produced. No
manual English subtitle track was available. The `en` and `en-orig` VTT files
were byte-identical.

The durable caption claims are:

- `0:14...1:23`: a sustained scale degree can establish context and tension;
- `1:23...3:11`: a low-pass reveal lets the listener perceive a complex hook's
  rhythm before its full detail and makes the later opening feel earned;
- `3:11...4:00`: a periodic kick relationship can make drums and hook breathe
  together;
- `4:00...6:58`: weak pre-kick positions create rhythmic pockets;
- `6:58...8:33`: subtracting established anchors just before a loop return can
  make the restored frame feel surprising;
- `8:33...10:18`: deliberately rough human capture may preserve spontaneity;
- `10:18...15:29`: a four-note color can make a progression richer and less
  comfortable than uniform triads.

The capture returned exactly 50 top-ranked top-level comments and eleven
replies. Four independent top-level comments converged on preserving intimacy
or spontaneity rather than equating technical capture quality with musical
quality. That supports the source's human-performance claim, but the standalone
runtime has no microphone, vocal source, account, or imported recording. A
synthetic "lo-fi vocal" effect would imitate a workflow without its musical
cause, so it is not admitted here. No community sample established a portable
filter coefficient or timing target.

Audio measurements were descriptive only because every demonstration is mixed
with narration and uses unequal source windows. They are not calibration
targets. No source sample, preset, workstation operation, creator identity,
comment text, or tutorial number enters production architecture.

## Reuse versus expansion

The repository already has canonical owners for six of the seven durable ideas:

- `TechnoScene.drone`, atmosphere notes, and four-voice pad harmony own tonal
  context; the pad vocabulary already contains four-note modal extensions;
- kick-derived upper ducking owns the shared pulse relationship;
- weak-sixteenth groove pulses and their 3-3-2 accent cell own rhythmic pockets;
- score-owned kick syntax and phrase subtraction own anchor withholding and
  recovery;
- fixed standalone provenance deliberately excludes microphone or imported
  vocal capture;
- narrative gain and role admission already own protagonist emergence.

Adding parallel drum patterns, another sidechain, another chord track, a vocal
lane, or a new effect bus would duplicate or falsify those owners. The remaining
deficit is narrower: narrative presence currently moves motif gain and only a
small generic spectral multiplier, but it does not own a deep, typed
hidden-to-revealed filter aperture that both foreground synth architectures can
replay and evidence.

The selected design therefore extends the current note/filter path. A future
video may justify a genuinely new internal instrument or effect chain when the
canonical palette cannot express its durable cause; reuse is not the default.
The decision rule is the most truthful causal owner.

## Score contract

Add `UpperSpectralRevealRelation` with `home` and `emerging`, plus a bounded
`UpperSpectralRevealArticulation` on each `ResolvedUpperNote`.

`UpperSpectralRevealResolver` returns `emerging` only when all are true:

1. the note is the dominant `.anchor` role;
2. the resolved narrative direction is `.emerging`;
3. the phrase kind is `.lock` or `.contrast`;
4. the plan is not under home-timbre correction.

All other notes are exact `home`. Active aperture is a semantic `0...1`-style
filter opening, engineering-bounded to `0.45...1`. It is derived from the same
step-interpolated narrative presence already used for protagonist gain:

`0.45 + 0.55 * presence^2`.

The squared contour keeps an initially obscured hook readable while allowing
detail to emerge faster near the narrative foreground. It changes no note or
assignment field. Home stores literal aperture `1` and must preserve current
PCM exactly. The relation and aperture enter typed plan fingerprinting.

`SynthPerformanceBar` retains pre-correction eligibility separately from the
applied note relation. A force-home correction therefore proves that the same
bar would normally reveal while resolving every note to exact home.

## DSP contract

Both existing foreground-capable architectures consume the same semantic
aperture:

- Resonant Mono applies it to the exact cutoff supplied to the shared TPT/ADAA
  nonlinear core;
- Tonal Motion applies it to the exact cutoff supplied to its existing
  four-stage filter.

`UpperSpectralRevealContract.appliedCutoff` is the one renderer-owned mapping.
It branches aperture `1` to the unchanged requested cutoff before multiplication;
active cutoffs are `requestedCutoff * aperture`, then constrained only by the
existing architecture and route bounds. Oscillators, envelopes, resonance,
drive, sends, note geometry, assignments, random state, and downstream effects
remain unchanged. Because sends consume the already-filtered voice, the same
hook identity reaches existing effects rather than creating a parallel wet path.

The filter states already live in the relevant voice continuation. No new
buffer, LFO, callback state, allocation, or bar-boundary switch is introduced.

## Evidence contract

Each rendered upper note records its requested relation/aperture and the actual
minimum/maximum cutoff values consumed by its renderer. One per-bar
`UpperSpectralRevealRenderEvidence` reduces the isolated dominant-anchor tap:

- eligibility and active state;
- independent score/render anchor counts and active-event count;
- active requested-aperture extrema;
- actual applied cutoff extrema;
- independent typed score and render fingerprints;
- exact isolated anchor PCM hash, peak, RMS, and finiteness;
- score/render/bounds binding.

The candidate vector retains one compact bar record for every rendered bar.
Active records require one or more matching active anchor events, equal score
and render counts, `0.45 <= active aperture < 1`, actual positive bounded cutoff
values, independent score/render identities, and a nonzero isolated signal.
Neutral records require zero active events and literal active-aperture sentinels
of `1`. Architectures without anchor events carry no reveal record. Attempt
validation requires active evidence exactly when normal eligibility is true and
home correction is false. Correction retains eligibility while resolving the
same architecture record to neutral.

The calibrated primary evaluator remains the only selection owner. Add
professional observation dimensions only if the compact implementation exposes
a stable attributable relationship that the current profile can qualify;
regenerate development, adversarial, and disjoint holdout artifacts from the
exact engine rather than inventing source thresholds.

## Version and safety boundary

The score, PCM, and candidate wire shape change together, so advance:

- canonical engine v22 to v23;
- quality-contract schema 23 to 24;
- candidate-vector schema 21 to 22;
- typed candidate-plan fingerprint domain v12 to v13.

Keep transaction, commit, live-feedback, upper-timbre, and continuation schemas
unchanged unless implementation changes their outer representation.

All new work stays in detached planning, rendering, evidence reduction, and
offline evaluation. Supported route rates, cancellation checks, bounded phrase
storage, one-button UI, immutable scheduled blocks, and the audio callback are
unchanged.

## Verification

1. Core tests prove natural reachability, exact aperture math, deterministic
   replay, note/assignment identity, ineligible paths, and force-home neutrality.
2. DSP tests prove literal home PCM identity and active cutoff/PCM/centroid
   movement for Resonant Mono and Tonal Motion at 44.1, 48, and 192 kHz.
3. Integration tests compare the same bar and continuation with only the reveal
   relation neutralized; kick, foundation, percussion, atmosphere, companions,
   note geometry, and protected rhythm stay exact.
4. Candidate tests cover JSON/fingerprint round trips, every-bar coverage,
   score/render binding, missing evidence, wrong role/aperture/cutoff/hash,
   nonfinite values, correction neutrality, and unchanged single-primary
   selection ownership.
5. Requalification runs the exact-engine profile, adversarial suite, disjoint
   holdouts, split CI matrix, callback-symbol audit, and optimized build.

No listening, app/route smoke, latency/working-memory result, hardware soak, or
professional release claim is implied by implementation alone.
