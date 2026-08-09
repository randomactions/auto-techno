# Autonomous Runtime Provenance

This document identifies the single shipped path, the owner of each decision,
and the target contract for autonomous adaptation. It distinguishes current
implementation from required future behavior so architectural direction is not
mistaken for a completed feedback system.

## Current implementation

1. `AutonomousSessionDirector` owns fixed 130 BPM, the private canonical
   identity, temporal memory, candidate phrases, and successor selection.
2. Each `AutonomousPhrasePlan` carries a complete musical intention, Scene DNA,
   resolved performance bars, outgoing interlock, spatial-contrast, and
   protagonist-narrative state, plus groove-interest evidence. Supporting-role
   admission is resolved before ensemble arbitration. A resolved bar is the sole
   score source for requested onsets, pitches, durations, gates, and articulation.
   Renderer-owned trajectory evidence records the continuation-dependent applied
   start frequency and gate outcome without creating a second score.
3. `DSPGraphGenerator` produces the deterministic upper-voice topology and its
   bounded mutation from the prior graph.
4. `AutonomousPhrasePreparer` renders immutable attempts into one versioned
   candidate-evaluation transaction under quality-contract schema 6. Each
   attempt carries the complete bounded vector of symbolic, hard-gate, full-mix,
   per-bar masking, role-stem, automatic-mix, event-local groove-pulse,
   ordinary closed-hat, score-owned instrument, graph, and pre/post
   upper-timbre evidence.
   Instrument records bind each resolved architecture, patch, use, automation,
   and compatible effect set to exact architecture-local dry-PCM identity,
   peak, RMS, and event count. Closed-hat records bind every ordinary hat to
   its score-owned neutral or companion decay role and exact dry-sample
   consequence. Groove-pulse records bind the existing resolved onset to
   score-owned strike zone, damping, deterministic microvariation, exact
   dry-sample identity, and reduced envelope/spectral consequence. The
   transaction binds all three
   plan fingerprints, engine/policy/evaluator versions, attempt-local reasons,
   selection, comparison, and correction provenance. It permits at most the
   primary, alternate, and deterministic fallback plus one home-timbre
   correction, with four render passes total. All attempts begin from the same
   incoming state. Their evidence records the incoming continuation and the
   outgoing render-plus-generated-DSP state before the quality decision; outer
   commit provenance then binds the chosen transaction, selected sample hash,
   outgoing render/DSP state, and finalized quality continuation state.

   The shipping evaluator is uncalibrated and does not request paired rendering,
   so a healthy primary is rendered exactly once. Alternate and fallback remain
   bounded validity paths, not a general professional-quality ranking system.
   A calibrated paired comparator stays disabled pending streaming phrase
   analysis plus measured cancellation, preparation-latency, and peak-memory
   bounds. Cancellation is checked within each candidate at bounded bar-render
   and evidence boundaries; route changes cancel detached preparation and
   prevent stale route work from committing.
   This transaction does not feed observations into future composition.
   Offline phrase preflight now measures native stereo with ITU-R BS.1770-5
   K-weighting and two-stage 400 ms gating, and measures true peak with the
   published Annex 2 four-phase FIR. The candidate vector retains analyzed
   frame and gating-block counts, integrated/momentary/short-term loudness,
   loudness spread, and dBTP evidence. A deterministic Professional Evidence v2
   bank requires every named journey checkpoint for every included sample rate,
   plus complete exact-role masking and stem evidence. Its policy status is
   unconditionally unavailable pending a calibrated profile and adversarial
   suite; it cannot promote or correct audio.
5. `AutonomousPhraseRenderer` constructs the required synth world and synth
   performance. The synth planner resolves the three-step driver, five-stage
   follower, chapter articulation, internal architecture and patch, four bounded
   automation coordinates, tone-chapter spectral aperture, and eligible effect
   access without changing onset positions. Resonant Mono, Tonal Motion, and
   Spectral Texture remain specialized voices inside this one renderer; they
   are not alternative runtimes or user-selectable instruments. The voice
   renderer applies
   the resolved protagonist contour and may place one eligible existing event on
   a filtered send into the existing reverb; neither operation creates another
   onset or topology. The renderer also renders full and protected-rhythm
   layers and mirrors exact dry samples into private kick, foundation,
   percussion, upper-tonal, and atmosphere stems. A bounded preparation-time
   fader resolves only the kick/foundation hierarchy from those stems. This is
   the current adaptive controller; it is not a complete output-evaluation loop.
   Percussion is rendered once per layer, and the exact dry percussion tap feeds
   audible center output, the drum reverb send, and role evidence. The existing
   delicate groove-pulse voice remains under one `GroovePulseResolver` contract.
   `PercussionGear` selects center, middle, or edge contact plus bounded damping
   and seeded microvariation for its fixed 45 ms carrier. On a complete
   eight-pulse syncopated-lean bar, the resolver changes only the existing event
   intensities into a cyclic 3-3-2 accent/ghost relation; onset, count, timing,
   and every other voice remain unchanged. The conservative candidate preserves
   the prior alternating intensity cell and resolves every pulse to the
   bit-identical legacy middle/neutral contact. Same-pass event evidence is
   descriptive only; the uncalibrated evaluator does not rank it.
   Ordinary closed hats retain the existing 50 ms source and RNG order. When a
   resolved open hat shares the same onset, the score labels only that closed
   hat as its companion and the renderer increases its decay rate; every other
   hat remains neutral. The conservative score is fully neutral, and bounded
   same-pass evidence makes the event-local PCM consequence attributable.
6. The unchanged pre-fader kick remains the ducking detector. The generated
   graph receives the exact `full - protected-rhythm` remainder, and its output
   is recombined with the protected stereo rhythm route. The protected route
   contains kick, foundation, exact percussion, and inherited shared
   continuation, while excluding newly scheduled upper voices. The remainder
   may still contain upper roles plus shared continuation and nonlinear-mix
   interaction, so it remains named graph-input remainder rather than an
   upper-only stem. Dedicated dry anchor and shadow/response taps retain
   role-local articulation attribution. Masking evidence now compares exact
   post-fader foundation, dry percussion, and combined dry-upper taps over all
   sixteen bar windows. It is descriptive only: uncalibrated masking evidence
   applies no cut, while the existing authored envelope, kick-linked guard,
   ducking, glue, and output-safety stages remain active. Upper-timbre evidence
   schema 3 (quality-report contract schema 6) retains protected rhythm as its
   masking reference and adds bounded onset-local anchor-velocity observations
   from the exact dry anchor tap.
   Score-owned anchor velocity now projects into the authored filter-envelope
   lift (`0.40...1.60`) and in-gate decay (`0.80...1.20`) while every other role
   stays neutral for this response. Retriggers latch the response and legato
   slides inherit it, preserving persistent tails. The reduced evidence records
   applied scales, gain-normalized attack high-band ratio, and tail-to-attack
   ratio; incomplete windows remain explicit and the uncalibrated policy cannot
   promote them.
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
