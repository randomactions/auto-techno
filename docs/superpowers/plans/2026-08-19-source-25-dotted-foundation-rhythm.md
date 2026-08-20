# Source 25: score-owned dotted foundation rhythm

## Decision

Reuse the existing protected foundation role, Resonant Mono architecture, Bass
Pluck patch, TPT/ADAA nonlinear core, score swing, and centered low-end route.
Do not add a bass track, instrument architecture, delay, reverb, sequencer, or
free-running clock. The source's durable idea is a two-bar three-sixteenth
foundation relation whose phase resets at a known score boundary; the current
engine is missing that onset syntax, not another way to generate bass tone.

## Vertical slice

- Core adds one `FoundationRhythmicRelation` to each resolved bar.
- A post-arbitration phrase resolver may replace only the existing bass events
  in a complete eligible two-bar Lock/Hypnotic Lock cell. Every non-bass event
  and its order remain exact.
- The underlying three-sixteenth phase begins on the pair downbeat. Existing
  four-on-floor kick anchors own coincident low-end positions, leaving exact
  complementary bass steps `3,6,9,15` then `2,5,11,14`.
- The active relation selects the existing Bass Pluck assignment; harmony,
  accent, score swing, filter/nonlinear topology, centered routing, and every
  other role remain under their existing owners.
- Same-pass evidence binds relation, pair phase, exact score/render masks and
  counts, actual start-frame geometry, dry foundation PCM hash/peak/RMS, and
  full/protected pass equality. The candidate record retains no PCM.

## Bounds and fallback

Admission requires both bars inside one immutable phrase, a canonical
four-on-floor kick, two naturally resolved monotone bass bars, exact steady
arrangement context, available ensemble capacity, and no omitted foundation.
Any failed precondition leaves the established score and PCM exact. The cell is
derived from absolute bar time and carries no continuation state. Rendering
remains detached; the real-time callback receives only immutable scheduled
buffers.

## Validation

- exact two-bar geometry, boundary reset, reachability, and phrase-split replay;
- non-bass score equality and exact neutral behavior;
- Bass Pluck selection plus active-versus-established foundation PCM change at
  8, 44.1, 48, 96, and 192 kHz;
- prepared score-to-render-to-candidate binding, full/protected equality, JSON
  bounds, and tamper rejection;
- calibrated observation/adversarial identity, version updates, artifact
  regeneration, isolated regression matrix, release build, and exact-head CI.

## Maturation boundary

A later serious DSP pass may replace the current Bass Pluck envelope and
oscillator/filter realization with a richer band-limited or physically informed
foundation voice, fractional scheduling, MSEG articulation, or a separately
qualified high-passed spatial treatment. It must preserve this two-bar score
relation, kick substitution, exact neutral path, protected low-end ownership,
and causal evidence, replacing the current realization rather than leaving a
second bass lane or parallel effect chain beside it.
