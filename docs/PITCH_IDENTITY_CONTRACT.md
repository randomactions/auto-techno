# Pitch Identity Contract

Auto Techno separates pitch-bearing material from indefinite-pitch texture in
the canonical score and renderer. “Atonal” is not used as a catch-all for a
wrong modal note: deliberately dissonant material remains explicitly pitched,
while indefinite-pitch material cannot follow the requested melodic frequency.

## Canonical identities

| Identity | Score contract | Renderer contract |
| --- | --- | --- |
| `modal-pitched` | Uses the scene tonal center and modal vocabulary | Requested pitch may control oscillators and filters |
| `tuned-inharmonic` | Retains a modal fundamental | Upper physical modes may be inharmonic within bounded material controls |
| `deliberate-dissonance` | Names a pitched tension relation and its resolution context | Requested pitch remains audible and evidence identifies the relation |
| `indefinite-pitch` | Carries timing, energy, timbre, and role but no audible note target | Requested start/end frequency must have zero influence on PCM |

`InstrumentAssignment` owns the identity for every internal instrument. Modal
percussion is always `tuned-inharmonic`. Alien Noise, Dust Cloud, and
non-transition Metal Veil are `indefinite-pitch`. The rising Metal Veil
transition is `deliberate-dissonance`; Voltage Arc and the tonal architectures
remain `modal-pitched`.

## Harmonic coordination

All tonal voices share the one `SceneDNA` modal frame. Pad functions are
diatonic seventh chords built by stacking modal thirds. Dorian and Aeolian
modal-color chords disclose their contrasting sixth; Phrygian discloses its
flat second. Every function must realize four distinct modal pitch classes, and
modal color must not collapse to the tonic voicing. Arpeggiation inherits the
realized pad pitch classes when a pad is present.

The protected foundation uses `FoundationPitchResolver`. It may select only a
mode member (with root/fifth/octave protection in Phrygian) and cannot add a
renderer-local chromatic semitone at high tension.

## Indefinite-pitch qualification

The current indefinite source is deterministic broadband noise shaped by
bounded, non-resonant color filtering. It does not read note frequency, does
not use a pitched resonator, and clears pitched filter memory when crossing a
pitch-identity boundary. A dedicated dry stem produces:

- exact PCM and event fingerprints;
- proof that applied start, target, and end frequencies are all neutral;
- assignment/event binding and finite peak/RMS/crest facts; and
- first-difference normalized periodicity over a bounded 50–2,000 Hz search.

Candidate completeness requires the frequency-influence proof and normalized
periodicity no greater than `0.35`. The deterministic DSP matrix covers Alien
Noise, Metal Veil, and Dust Cloud at 8, 44.1, 48, and 192 kHz, asserts bit-exact
PCM under two unrelated note requests, and rejects a modal sine control above
the bound. The deliberate Metal Veil cluster is tested separately to remain
pitch-dependent.

## Version and qualification state

This PCM-changing contract is canonical engine v38, quality-contract schema
39, candidate-vector schema 35, and candidate-transaction schema 6. The exact
primary-v19 and long-horizon-v6 artifacts bind it together with transition-tail
continuity; older engine-v36 artifacts remain historical and fail closed.
