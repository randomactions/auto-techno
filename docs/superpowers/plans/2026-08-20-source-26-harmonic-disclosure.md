# Source 26: score-owned harmonic disclosure

## Decision

Reuse the existing four-voice pad, modal harmonic functions, minimal-motion
voice leading, harmonic continuation, pad renderer, and phrase-composition
evidence. Do not add a second chord progression, pad track, instrument,
sequencer, or effect chain. The source's durable idea is to budget when the
canonical harmony becomes knowable across the arrangement; the current engine
is missing that disclosure syntax, not another source of tonal material.

## Vertical slice

- Core adds one `PadHarmonicDisclosureStage` to each existing `PadVoicing`.
- Eligible first-half Lock pads are `concealed` and retain only the tonic
  function. Second-half Lock pads are `partial` and expose a deterministic
  tonic/modal-colour relation across that half of the phrase. Major Break pads
  are `revealed` and traverse the existing tonic, modal-colour, subdominant,
  and return-pull functions once every four local bars.
- Other pad contexts remain `established` and use the exact prior harmonic
  function resolver. Identity Return remains composition-neutral. When the
  journey returns from a Major Break to Lock, the next phrase contracts to the
  concealed stage without adding continuation state.
- Only the pad's existing harmonic function, its four connected voices, and
  pitch ratios in the already pad-derived arpeggiator may change. Pad count,
  onset, duration, instrument, rhythmic modulation, spatial send, arpeggiator
  count/onsets/durations/velocities/direction/rate, non-composition score,
  route topology, transport, and random draws remain exact.
- The typed plan binds the stage. Existing same-pass pad ratios and PCM
  hash/RMS/peak remain the renderer consequence; compact candidate evidence
  additionally replays local phrase geometry, stage, allowed function, and an
  exact score-to-render arpeggiator pitch fingerprint.

## Bounds and neutral behavior

Phrase-local `localBar` and `phraseLength` own the aperture. The vocabulary is
fixed to one function while concealed, two while partial, and the existing four
while revealed. There is no wall-clock state, background modulation, extra
candidate, or new continuation buffer. Missing or ineligible pads remain exact
neutral, and the current home-correction path continues to remove composition
material before rendering. Rendering stays detached; the realtime callback
receives only immutable scheduled buffers.

## Validation

- exact concealed/partial/revealed geometry for every supported phrase length;
- natural journey reachability, contraction after a reveal, determinism, and
  phrase-split harmonic continuation;
- unchanged pad density, onset, duration, instrument, rhythmic modulation,
  spatial topology, arpeggiator rhythm/articulation, non-composition score, and
  protected rhythm, with every arpeggiator pitch still in the disclosed chord;
- same-bar active-versus-established rendering that isolates changed requested
  pad ratios, dependent arpeggiator pitch ratios, and tonal PCM while protected
  and non-composition paths remain exact;
- plan-fingerprint sensitivity, candidate JSON/bounds/tamper rejection, and
  exact pad-ratio and arpeggiator-pitch score-to-render binding;
- calibrated disclosure prevalence and distinct-function evidence, a
  non-compensable overpopulation attack, artifact regeneration, isolated
  regression matrix, release build, and exact-head CI.

## Maturation boundary

The v1 stage projection is intentionally coarse. A later serious harmony pass
may replace it in place with longer score-owned functional syntax, suspensions,
passing tones, tension-aware inversions, or a shared multi-role harmonic frame
only after calibrated predictability, tonal-tension, masking, or repetition
evidence exposes a repeatable deficit. It must preserve the existing pad owner,
four explicit voices, accepted harmonic continuation, deterministic disclosure
arc, exact neutral path, and one primary evaluator. It must replace rather than
coexist with another progression, pad lane, or harmonic engine.
