# Auto Techno Product Contract

## Purpose

Auto Techno is a standalone macOS instrument for starting and sustaining a
coherent techno performance with one button. It is not a DAW, sequencer editor,
plug-in, preset browser, or collection of render experiments.

## Central invariant

Every interaction expresses a musical intention. Both the destination and the
transition must be coherent.

The current product expresses that invariant through autonomous planning rather
than editable controls. Play asks the instrument to continue the performance;
pause and resume preserve its position and identity. Technical render state may
be shown read-only, but direct DSP parameters do not belong in the primary UI.

## Shipped experience

- one accessible transport button;
- explicit preparing, ready, live, paused, recovering, and unavailable states;
- fixed 130 BPM;
- deterministic default performance with seed `48291`;
- phrase and bar position plus a lightweight waveform;
- offline operation with no account or cloud dependency.

## Musical runtime

`AutonomousSessionDirector` owns the session seed, fixed tempo, temporal memory,
phrase candidates, continuation, and debt repair. Every selected phrase contains
a non-optional musical intention, Scene DNA, performance bars, and ensemble
context. The synth planner adds a non-optional synth world and per-bar synth
performance.

The generated DSP graph applies only to the upper-voice remainder. A private
full/foundation rendering distinction protects kick and bass without exposing a
runtime mode. Phrase rendering occurs before playback; the audio engine schedules
immutable buffers at sample time.

## Hard constraints

- Same seed and controls produce the same musical decisions.
- Planning remains in `AutoTechnoCore`; audio rendering remains in `AutoTechnoDSP`.
- The audio callback performs no allocation, locking, I/O, logging, or UI work.
- Route changes rebuild at the active sample rate and retain coherent continuation.
- Low-end protection, finite output, bounded peaks/DC/boundaries, and masking
  checks remain release obligations.
- No musical retuning is accepted without a concrete matched-loudness listening
  observation recorded in the taste ledger.

## Product boundary

The package exposes only the `AutoTechno` executable. Core and DSP targets have
no supported external consumers or source-compatibility promise. Retired
reference engines, comparison executables, old scene APIs, and render profiles
are intentionally outside the product.
