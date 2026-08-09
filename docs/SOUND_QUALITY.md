# Sound Quality Contract

## Status and purpose

Professional release-quality sound is Auto Techno's explicit iterative goal. It
is not a claim about the current build. This document defines how the engine will
measure progress, qualify revisions, and adapt its own future output without a
manual curation gate or third-party instrument dependency.

The current runtime already supplies deterministic planning, detached rendering,
role evidence, signal-safety reports, masking analysis, and one bounded automatic
mix correction. The broader quality policy and hybrid live-feedback loop below
are target architecture until their implementation and validation are recorded.

## Engine ownership

The shipped signal path owns its synthesis, effects, mixing, and mastering
behavior. Playback and release qualification require no VSTi, Audio Unit
instrument or effect, DAW, sample-library runtime, cloud model, network service,
or account.

Development may use legal reference recordings and external offline analyzers.
Reference audio, extracted stems, and generated comparison WAVs remain local and
untracked. The repository may contain only source metadata and aggregate target
profiles that cannot reconstruct the recordings.

## Quality is a vector

No single score may stand for “professional.” A decision preserves the individual
dimensions and the reason for every rejection, correction, or selection.

### Hard gates

- finite samples and bounded sample, true-peak, DC, and block-boundary behavior;
- stable low-frequency phase and mono compatibility;
- no invalid graph, runaway tail, discontinuity, or unbounded controller state;
- deterministic planning, rendering, evidence, and decisions for identical
  versioned inputs;
- bounded CPU, memory, preparation latency, candidate count, and correction count;
- uninterrupted sample-time playback and coherent route recovery.

A hard-gate failure cannot be offset by strength in another dimension.

### Translation and sound dimensions

- transient shape, punch, crest behavior, and absence of brittle or smeared
  attacks;
- low-end authority and a stable kick/foundation hierarchy;
- spectral occupancy, masking, harshness, mud, and useful separation among roles;
- integrated and short-term loudness, dynamic range, and headroom appropriate to
  each structural state;
- stereo depth, phase stability, mono translation, and restrained spatial tails;
- recognizable authored timbre without aliasing, accidental noise, or generic
  preset substitution.

### Musical dimensions

- pulse clarity, groove hierarchy, deliberate space, and controlled density;
- persistent identity across variation and internal strategy changes;
- motivated tension, contrast, release, subtraction, and return;
- useful repetition without stagnation and variation without random replacement;
- coherent long-range consequence across phrases, chapters, and route recovery.

Targets are section- and role-aware ranges, relationships, and obligations. They
are not whole-track averages that encourage the engine to flatten every moment
toward the same spectrum or loudness.

## Development qualification loop

1. Render the same private canonical journey bank before and after a change at
   representative sample rates and structural checkpoints.
2. Capture exact engine, quality-policy, fixture, continuation, route, and
   toolchain versions.
3. Compare hard gates, role evidence, full-mix evidence, trajectory evidence, and
   any applicable derived reference profile.
4. Emit a machine-readable report with reason-coded pass, reject, and adjust
   decisions. Match loudness for diagnostic comparisons where level would mask
   the changed dimension.
5. Reject any unexplained hard-gate failure, determinism change, disconnected
   parameter, metric regression, or preparation-budget breach.
6. Promote the engine and policy revision only when all required automated gates
   pass. Optional human feedback may open another measurable deficit; it cannot
   bypass or replace the automated decision.

## Runtime generate, evaluate, and adapt loop

The target loop is bounded and persistent:

1. The canonical director proposes a fixed number of complete plans from the
   current musical and quality state.
2. Detached preparation renders immutable audio and exact role evidence.
3. Hard gates reject unsafe or invalid output.
4. The quality policy evaluates the surviving multidimensional evidence.
5. A fixed number of bounded, deterministic corrections may be applied before a
   candidate is selected or the conservative fallback is used.
6. The chosen plan, reason-coded evidence, controller state, and policy version
   become continuation input for future preparation.
7. Final immutable blocks receive a second safety check before scheduling.

The evaluator may select internal instruments, graphs, or strategies through the
canonical score. It may not switch to another top-level engine or retain a
parallel runtime.

## Hybrid live feedback boundary

Live feedback observes only app-owned mixer PCM. It never enables a microphone,
records the room, identifies an output device acoustically, or sends audio to a
network or model service.

The audio callback may only copy a bounded sample window into a preallocated
single-producer/single-consumer handoff. It performs no allocation, locking, FFT,
analysis, logging, file or network I/O, model inference, or UI work. A bounded
background worker consumes fixed sample-indexed windows and publishes an
immutable evidence snapshot through a lock-free handoff.

Wall-clock timing does not define evidence. The window's sample positions,
sample rate, route state, engine version, and quality-policy version do. The same
captured PCM and versioned state must reproduce the same result in an offline
replay test.

An adjustment can affect only unscheduled future bars or phrases. It cannot
rewrite a playing buffer, mutate scheduled audio, or block the scheduler. If
analysis or preparation misses its deadline, the engine repeats coherent
prepared material and retains bounded state rather than degrading continuity.

## Stability and anti-gaming rules

- Keep hard constraints separate from optimization targets.
- Preserve the full evidence vector and reason codes; do not optimize an opaque
  aggregate alone.
- Bound every gain, parameter, derivative, slew, candidate count, and rerender
  count.
- Use deadbands, hysteresis, hold conditions, and recovery rates to prevent
  controller chatter, drift, and competing correctors.
- Test silence, breaks, missing roles, extreme but valid scenes, long runs, route
  changes, sample-rate changes, and delayed successors.
- Reject policies that improve a proxy by flattening dynamics, removing useful
  contrast, adding density, or sacrificing identity.
- Centralize coupled corrections so independent controllers cannot fight over the
  same evidence.

## Human and source evidence

Human listening, production lessons, interviews, and community commentary are
optional hypothesis sources. Record them separately from measurements and from
the policy decision. Translate a useful observation into a falsifiable deficit,
engine responsibility, measurable evidence, bounded action, and regression
scenario. Neither authority, popularity, nor preference promotes a revision.

Use `VIDEO_ANALYSIS_PROTOCOL.md` for video-derived hypotheses. Historical manual
verdicts remain preserved in `history/TASTE_EXPERIMENTS.md` but are not current
policy.

## Qualification states

Report these five states separately:

1. implementation complete;
2. structural and signal validation passed;
3. automated quality qualification passed for an exact engine and policy version;
4. app/runtime verification passed on the exact release build;
5. physical-output and recovery soak passed.

Passing one state never implies the next. Until all five pass, professional
release quality remains unverified.
