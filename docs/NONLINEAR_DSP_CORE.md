# Nonlinear DSP Core

The nonlinear topology remains current under engine v40, whose exact artifacts
also bind the pitch and transition-tail contracts.

## Purpose and owner

Auto Techno has one shared bounded nonlinear-filter primitive for the Resonant
Mono architecture. `InstrumentAssignment` and its existing semantic `color`,
`motion`, `shape`, and compatible `drive` effect remain the canonical score
owners. `ResonantMonoState` owns continuation. The primitive does not choose a
patch, add an event, run a separate controller, or expose a user setting.

Engine identity `autotechno-canonical-engine.v40`, quality-contract schema 41,
candidate-vector schema 37, and candidate-transaction schema 8 identify the
current realization containing this unchanged core. The calibrated primary
evaluator consumes the record as one non-compensable part of its terminal
decision.

## Realization v1

`TPTAntialiasedNonlinearCore` processes the existing Resonant Mono source through:

1. first-order antiderivative antialiasing of the input `tanh` nonlinearity;
2. a two-integrator topology-preserving-transform state-variable filter;
3. the existing score-derived low-pass/band-pass colour blend; and
4. first-order antiderivative antialiasing of the output `tanh` nonlinearity.

The implementation replaces the architecture's former four cascaded
coefficient-based one-pole states and private rational saturator. It does not
silently rewrite the separate Alien Analog or generated-graph nonlinear paths;
those require their own measured deficit, replacement, evidence, and engine
revision.

The same first-order ADAA primitive is now also reused by the kick's one
source-local conditioner. That stage processes the complete existing body,
sub, and click sum before either kick bus; it is not part of the Resonant Mono
filter continuation and does not create a shared dynamics chain or a new
instrument. Its fixed transfer and separate evidence are described by the
kick-source contract in `SOUND_QUALITY.md`.

Applied bounds are deterministic and route-rate aware:

- cutoff: 20 Hz through 0.22 of the active sample rate;
- Q: 0.5 through 4.5;
- input and output drive: 1.0 through 3.2;
- band-pass blend: 0 through 0.45;
- antialias order: first order with one prior input sample per shaper.

Patch changes reset the filter and shaper memories at the existing Resonant Mono
patch boundary. Normal phrase continuation retains them. Non-finite input resets
the bounded core, emits zero for that sample, and marks the same-pass evidence
invalid.

## Truth boundary

Each Resonant Mono architecture record must contain one reduced core record that
binds:

- the exact unique assignment and event counts;
- processed sample count;
- applied cutoff, Q, input/output drive, and band-mix ranges;
- exact pre-core input and post-core output fingerprints;
- input/output peak and RMS;
- version, antialias order, finiteness, and score/render binding.

No reconstructable PCM or mutable DSP state enters candidate evidence. The core
record is required only for Resonant Mono and is forbidden on other
architectures. Candidate tampering with version, geometry, count, hash, bound,
or binding makes the attempt incomplete.

## Qualification boundary

Automated tests require materially lower folded energy than point-sampled
`tanh`, rate-normalized TPT response at 44.1–192 kHz, finite output under
aggressive modulation at every supported rate, exact chunk continuation, patch
reset, exact replay, and complete canonical score-to-PCM evidence. These are DSP,
provenance, and safety results; they are not a professional-quality or physical-
output claim.

The topology follows the trapezoidal-integrator SVF described in Cytomic's
[linear trapezoidal SVF note](https://www.cytomic.com/files/dsp/SvfLinearTrapOptimised.pdf)
and the broader topology-preserving treatment in Native Instruments'
[The Art of VA Filter Design](https://www.native-instruments.com/fileadmin/ni_media/downloads/pdf/VAFilterDesign_2.0.0a.pdf).
The first-order shaper follows the antiderivative-antialiasing method described
in the [DAFx-16 ADAA paper](https://www.dafx.de/paper-archive/2016/dafxpapers/20-DAFx-16_paper_41-PN.pdf).
