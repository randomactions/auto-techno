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
- one canonical, indefinitely evolving performance;
- phrase and bar position plus a lightweight waveform on a fixed decibel scale;
- offline operation with no account or cloud dependency.

## Musical runtime

`AutonomousSessionDirector` owns the private canonical identity, fixed tempo,
temporal memory, phrase candidates, continuation, and debt repair. Every
selected phrase contains a non-optional musical intention, Scene DNA, and
resolved performance bars that keep the arrangement gesture, foundation
companion, arbitrated ensemble events, and long-form chapter together. A global
sixteen-bar grid times structural punctuation without removing adaptive
four-to-sixteen-bar phrases.

Within that grid, a three-step upper-voice driver advances a five-stage follower.
The resulting fifteen-step relationship moves against the sixteen-step groove
without creating or relocating onsets. Bounded sixteen-bar chapters alter
velocity, breath, tone, motion, or sparse pulse-echo emphasis while the dominant
motif retains its fingerprint. Chapters return to `home` for identity returns
and at least once every four macros. The kick and the scene's main foundation
companion remain stable and outside this relational modulation.

The generated DSP graph applies only to the upper-voice remainder. A private
full/foundation rendering distinction protects the kick and its bass, mono
rumble, or tuned-tom companion without exposing a runtime mode. Sparse
three-sixteenth pulse echo is band-limited on the upper path. Phrase rendering
occurs before playback; the audio engine schedules immutable buffers at sample
time.

Detached rendering also measures five private role stems: kick, foundation,
percussion, upper tonal, and atmosphere. A bounded automatic fader uses the
actual kick/foundation relationship to trim the audible kick slowly toward the
authored hierarchy for the active companion. It never boosts the kick above its
authored level, does not learn during breaks or without a valid companion, and
does not alter the pre-fader detector that drives groove ducking. These stems and
measurements are evidence for the autonomous performance, not mixer controls.

## Hard constraints

- The same private initial and continuation state reproduces the same musical
  decisions and prepared audio.
- Planning remains in `AutoTechnoCore`; audio rendering remains in `AutoTechnoDSP`.
- The audio callback performs no allocation, locking, I/O, logging, or UI work.
- Route changes rebuild at the active sample rate and retain coherent continuation.
- Low-end protection, finite output, bounded peaks/DC/boundaries, and masking
  checks remain release obligations.
- Automatic balance runs only during detached preparation, has bounded gain and
  slew, and must report the same post-fader role audio used by the mix.
- No musical retuning is accepted without a concrete matched-loudness listening
  observation recorded in the taste ledger.

## Product boundary

The package exposes only the `AutoTechno` executable. Core and DSP targets have
no supported external consumers or source-compatibility promise. Retired
reference engines, comparison executables, old scene APIs, and render profiles
are intentionally outside the product.
