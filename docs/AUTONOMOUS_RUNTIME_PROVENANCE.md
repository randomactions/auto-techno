# Autonomous Runtime Provenance

This document identifies the single shipped path, the owner of each decision,
and the target contract for autonomous adaptation. It distinguishes current
implementation from required future behavior so architectural direction is not
mistaken for a completed feedback system.

## Current implementation

1. `AutonomousSessionDirector` owns fixed 130 BPM, the private canonical
   identity, temporal memory, candidate phrases, and successor selection.
2. Each `AutonomousPhrasePlan` carries a complete musical intention, Scene DNA,
   resolved performance bars, outgoing interlock state, and groove-interest
   evidence. A resolved bar is the sole source for both audible onsets and
   reported events.
3. `DSPGraphGenerator` produces the deterministic upper-voice topology and its
   bounded mutation from the prior graph.
4. `AutonomousPhrasePreparer` renders the primary candidate, runs symbolic,
   graph, and audio-safety preflight, and uses the alternate or deterministic
   fallback only when required by the current validity policy. It does not yet
   perform general professional-quality ranking or feed rendered observations
   back into future composition.
5. `AutonomousPhraseRenderer` constructs the required synth world and synth
   performance. The synth planner resolves the three-step driver, five-stage
   follower, chapter articulation, and eligible pulse-echo send without changing
   onset positions. The renderer passes that score to the voice renderer,
   renders full and protected-foundation layers, and mirrors the exact dry
   samples into private kick, foundation, percussion, upper-tonal, and atmosphere
   stems. A bounded preparation-time fader resolves only the kick/foundation
   hierarchy from those stems. This is the current adaptive controller; it is
   not a complete output-evaluation loop.
6. The unchanged pre-fader kick remains the ducking detector. Only the
   upper-voice remainder enters the generated graph, after which the fixed
   output-safety stage recombines the performance.
7. `TechnoEngine` prepares away from the callback and schedules completed buffers
   by sample time. It derives its read-only waveform on a fixed decibel scale and
   owns transport, visual position, and route recovery, not musical composition.
   The current app does not copy callback PCM into a background quality analyzer
   or make live quality-driven continuation decisions.

## Target unified loop

All future musical development extends one persistent loop:

```text
persistent state
  -> generate a bounded set of semantic candidates
  -> render immutable future audio
  -> evaluate planned structure and app-owned PCM
  -> select a qualified candidate or deterministic fallback
  -> commit plan, render, graph, evaluator, and controller state
  -> adapt only a future sample-indexed boundary
```

This is one mechanism with specialized planners, voices, effects, analyzers, and
controllers. Chapters, synthesis strategies, topology changes, and additional
auto-controlled parameters are internal states of that mechanism, not alternate
engines or user-selectable profiles. A new implementation must state which
existing state and score it extends, which shared render path it uses, which
evidence evaluates it, and how it preserves continuation. If a genuinely new DSP
primitive is needed, it joins the canonical renderer and is selected by the same
score; it does not create a parallel runtime.

The evaluator owns hard safety qualification, professional-quality evidence, and
long-form comparison against the committed history. Controllers own bounded
corrections such as role balance. The session director consumes only qualified,
bounded observations and remains the sole owner of future musical decisions.
Independent controllers must not compete over the same role or parameter; coupled
decisions share one state, bounds, slew policy, and fallback.

## Hybrid feedback boundary

Detached preparation may analyze its rendered buffers directly. When validation
must reflect samples that entered the scheduled output path, the future runtime
may copy app-owned PCM from the audio callback into a fixed-capacity,
preallocated, single-writer lock-free exchange. The callback may only perform a
bounded memory copy and advance lock-free indices. It must never allocate, lock,
wait, analyze, log, perform file or network I/O, call UI code, or change musical
state. If the exchange is full, feedback is dropped and the callback continues.

A bounded background analyzer consumes complete sample-indexed windows. It never
opens a microphone, captures ambient or system audio, or analyzes content the app
does not own. Each observation names its source sample range, controller revision,
and earliest eligible future boundary. A decision may affect only an immutable
candidate that has not yet been scheduled, and it is applied at that declared
sample boundary. Late, incomplete, non-finite, stale, or mismatched observations
are ignored in favor of the deterministic hold or fallback path. No analysis may
rewrite the current buffer or a scheduled bar.

## Reproducibility and product boundary

The same private initial state and accepted, sample-indexed feedback state must
reproduce the same candidates, selection, graph, samples, controller evolution,
and outgoing continuation state. Evaluation inputs and fallback outcomes are part
of continuation provenance, not ambient hidden state. Route recovery must retain
or deterministically rebuild them at the active sample rate.

There are no runtime profiles, selectable seeds, reference generators, optional
scene/synth inputs, microphone inputs, or alternate executable entry points.
Historical measurements and retired experiments are evidence only; they do not
re-enter the product architecture.
