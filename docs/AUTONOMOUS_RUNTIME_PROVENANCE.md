# Autonomous Runtime Provenance

This document identifies the single shipped path and the owner of each decision.

1. `AutonomousSessionDirector` owns fixed 130 BPM, default seed `48291`, session
   identity, temporal memory, candidate phrases, and successor selection.
2. Each `AutonomousPhrasePlan` carries a complete musical intention, Scene DNA,
   performance bars, ensemble decisions, and phrase-interest evidence.
3. `DSPGraphGenerator` produces the deterministic upper-voice topology and its
   bounded mutation from the prior graph.
4. `AutonomousPhrasePreparer` evaluates candidates, runs render and graph
   preflight, applies deterministic fallback when required, and returns immutable
   scheduled blocks plus continuation state.
5. `AutonomousPhraseRenderer` constructs the required synth world and synth
   performance, renders full and protected-foundation layers, processes only the
   upper-voice remainder through the generated graph, and recombines them through
   the fixed output-safety stage.
6. `TechnoEngine` prepares away from the callback and schedules completed buffers
   by sample time. It owns transport, visual position, and route recovery, not
   musical composition.

The same root seed and incoming continuation states must reproduce the same plan,
graph, samples, and outgoing states. There are no runtime profiles, reference
generators, optional scene/synth inputs, or alternate executable entry points.
