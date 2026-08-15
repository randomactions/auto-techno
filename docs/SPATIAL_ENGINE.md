# Canonical Spatial Engine

## Outcome

Auto Techno now has one deterministic stereo late field inside the canonical
renderer. An eight-line feedback delay network (FDN) replaces the former
single 12–20 second mono feedback-delay realization. It does not add a second
renderer, a selectable reverb, a plug-in surface, or a user control.

The durable musical idea is unchanged: the resolved score may move one existing
upper carrier from foreground to distant space while protected rhythm remains
authoritative. The new renderer makes that request sound like a diffuse field
instead of one repeating mono echo and gives the autonomous quality path exact
evidence about the consequence.

## Ownership and flow

1. `AutonomousSessionDirector` and `SpatialContrastArticulation` continue to own
   the semantic depth position, carrier, step, send, and filter bounds.
2. `FeedbackDelayNetworkConfiguration` converts the existing `TechnoScene` into
   immutable room scale, RT60, high-frequency damping, synth/percussion send,
   and wet-gain parameters at the active route rate.
3. `VoiceRenderer` feeds the existing filtered spatial carrier, upper bus, and
   bounded percussion ambience into the FDN during detached preparation.
4. `FeedbackDelayNetworkState` continues the late field across bars and phrases.
   A route-geometry change resets it deterministically before rendering the new
   route.
5. `SpatialFDNRenderEvidence` streams hashes and reduced measurements from the
   exact input and stereo wet samples. Candidate-vector schema 18 binds one
   record to every rendered bar under quality-contract schema 20 and canonical
   engine v19.

No musical choice, analysis, file operation, allocation, or state mutation from
this path runs on the real-time audio callback. The app schedules the already
rendered immutable buffers exactly as before.

## DSP realization v1

The network has eight distinct odd-length delay lines. A normalized input sign
vector injects the mono send, and an orthogonal Householder matrix redistributes
the delayed energy. Two orthogonal normalized sign projections use all eight
lines as diffuse mid and side components; a constant-energy 0.866/0.5 matrix
produces the left and right returns. This retains every line in mono translation
while preserving bounded stereo width without line-subset rate sensitivity.
Orthogonal feedback prevents the matrix itself from adding energy. Each line
then applies delay-proportional loss derived from the requested RT60, so every
recursive gain remains strictly below unity, plus a one-pole high-frequency
damping filter. Scene mapping can approach the RT60 ceiling and a 0.24 wet
ceiling for atmospheric material, preserving phrase-scale continuity without
restoring the former sparse long echo. At the existing score-owned identity-
return boundary, the same field keeps its continuation memory but applies a
0.45 audible-return scale so home identity clears without an abrupt state reset
or a second reverb mode.

The implementation is intentionally bounded:

- room scale: `0.78...1.24`;
- RT60: `1.25...5.8` seconds;
- damping: at least 800 Hz and at most 45% of the route rate;
- eight line lengths: approximately 43–163 ms before room scaling, no line
  longer than 210 ms;
- synth send: `0...0.5`, percussion send: `0...0.16`, wet gain: `0...0.24`;
- flat continuation storage with exact offsets, lengths, write indices, and
  damping state included in deterministic fingerprints and preflight bounds.

The existing 13 ms early reflection, rhythmic upper delay, pulse echo, generated
graph diffusion, and score-gated percussion return keep their distinct musical
jobs. The FDN replaces only the old late mono feedback-delay buffer.

## Truthful evidence and containment

Each bar records route rate and frame count, all eight delay lengths, resolved
room/decay/damping and send values, score-owned depth/carrier/filter identity,
exact input/left-wet/right-wet hashes, RMS and peak, stereo correlation, active
sample counts, first wet frame, binding, and finiteness. Structural validation
rejects missing, duplicated, oversized, non-finite, unstable, wrongly bound, or
malformed records. Spatial evidence changes the primary transaction fingerprint.

The normal score uses foreground depth with no selective carrier send. That does
not disable scene-owned upper/percussion ambience or abruptly erase a valid
continuing tail; it removes only the optional distant-carrier articulation.
Invalid FDN configuration or non-finite input produces silence
from the late field, and route mismatch rebuilds zeroed bounded state. Kick and
foundation never enter the FDN and retain exact protected-role fingerprints.

## Qualification boundary

Unit and integration tests can establish configuration bounds, deterministic
impulse response, density, stereo decorrelation, rate-normalized onset,
continuation, route reset, score/effect/evidence binding, and exact protected
role identity. The calibrated primary evaluator may accept, correct, or reject
the resulting phrase. An app launch for listening is not a physical-output soak
or a professional-quality claim.

## Design sources

The implementation follows established FDN principles rather than copying a
third-party effect: distinct delay lengths, an energy-preserving mixing matrix,
delay-dependent decay, damping, and separate early/late structures. Useful
background is Signalsmith's [Let's Write a Reverb](https://signalsmith-audio.co.uk/writing/2021/lets-write-a-reverb/)
and the DAFx paper [The Role of Modal Excitation in Feedback Delay Networks](https://www.dafx.de/paper-archive/2021/proceedings/papers/DAFx20in21_paper_17.pdf).
