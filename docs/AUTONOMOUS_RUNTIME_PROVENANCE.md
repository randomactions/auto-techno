# Autonomous Runtime Provenance

This document identifies the single shipped path and the owner of each decision.

1. `AutonomousSessionDirector` owns fixed 130 BPM, the private canonical
   identity, temporal memory, candidate phrases, and successor selection.
2. Each `AutonomousPhrasePlan` carries a complete musical intention, Scene DNA,
   resolved performance bars, outgoing interlock state, and groove-interest
   evidence. A resolved bar is the sole source for both audible onsets and
   reported events.
3. `DSPGraphGenerator` produces the deterministic upper-voice topology and its
   bounded mutation from the prior graph.
4. `AutonomousPhrasePreparer` evaluates candidates, runs render and graph
   preflight, applies deterministic fallback when required, and returns immutable
   scheduled blocks plus continuation state.
5. `AutonomousPhraseRenderer` constructs the required synth world and synth
   performance. The synth planner resolves the three-step driver, five-stage
   follower, chapter articulation, and eligible pulse-echo send without changing
   onset positions. The renderer passes that score to the voice renderer,
   renders full and protected-foundation layers, and mirrors the exact dry
   samples into private kick, foundation, percussion, upper-tonal, and atmosphere
   stems. A bounded preparation-time fader resolves the kick/foundation hierarchy
   from those stems before masking analysis. The unchanged pre-fader kick remains
   the ducking detector. Only the upper-voice remainder enters the generated
   graph, after which the fixed output-safety stage recombines the performance.
6. `TechnoEngine` prepares away from the callback and schedules completed buffers
   by sample time. It derives its read-only waveform on a fixed decibel scale and
   owns transport, visual position, and route recovery, not musical composition.

The same private initial and incoming continuation states must reproduce the
same plan, graph, samples, and outgoing states. This determinism exists for
reproducibility and continuation safety; it is not a product choice. There are
no runtime profiles, selectable seeds, reference generators, optional
scene/synth inputs, or alternate executable entry points.
