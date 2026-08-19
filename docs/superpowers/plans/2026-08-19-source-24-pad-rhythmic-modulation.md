# Source 24: score-owned pad rhythmic modulation

## Decision

Reuse the existing four-voice pad and its existing spatial-reverb send. Do not
add a track, instrument, delay, LFO, sequencer, or effect bus. The source's
durable idea is that a held sound can regain rhythmic energy through coordinated
timbre and effect-send motion; the canonical pad already owns that sound and the
existing score already owns bar time.

## Vertical slice

- Core adds one `PadRhythmicModulation` value to `PadVoicing`.
- Only naturally resolved latter-half major-break pads use the three-step pulse;
  early, minimalized, structural-marker, ineligible, and identity paths remain
  exact neutral.
- Absolute bar modulo three owns phase, so phrase splitting and replay do not
  restart the cell.
- The renderer applies the score relation to the pad's existing low-pass cutoff
  and existing spatial-reverb send. It adds no feedback state and no callback
  work.
- Same-pass streaming evidence binds relation, phase, exact 16-step pattern,
  applied extrema, output/send hashes and RMS, and active-versus-neutral
  difference RMS without retaining another PCM buffer after preparation.
- Candidate validation rejects wrong context, phase, pattern, flat consequence,
  nonfinite values, or pass mismatch. Professional observation retains active
  bar ratio plus level-relative filter-difference-to-pad and
  spatial-difference-to-send means in dB; a dedicated adversarial case rejects
  a disconnected filter consequence.

## Bounds and fallback

The current engineering realization uses a three-sixteenth cell with filter
scales `0.38 / 1.00 / 0.62` and spatial-send scales
`0.72 / 0.85 / 1.28`. These are not tutorial settings or permanent product
definitions. Neutral is literal `1.0` on both paths and preserves the previous
PCM operation order exactly. All work remains in detached phrase preparation;
the real-time callback receives only immutable scheduled buffers.

## Validation

- natural reachability and exact phase continuation;
- exact neutral identity and active PCM consequence at 8, 44.1, 48, 96, and
  192 kHz;
- prepared score-to-render-to-candidate binding and JSON tamper rejection;
- calibrated observation metrics and disconnected-modulation adversarial case;
- deterministic fingerprints, version identities, artifact regeneration,
  process-isolated regression matrix, release build, and exact-head CI.

## Maturation boundary

A later serious DSP pass may replace this discrete scale projection with a
smoothed control-rate envelope, higher-order or nonlinear filter movement,
tempo-safe modulated diffusion, multiband send shaping, or a richer score-owned
modulation graph only when calibrated motion, masking, transition, or artifact
evidence exposes a repeatable deficit. It must keep the same pad owner, exact
neutral path, absolute-time phase, evidence, and bounded primary decision; the
v1 path is replaced rather than left beside another modulation lane.
