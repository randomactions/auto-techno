# Unified quality-loop boundaries

Use one persistent contract across composition, rendering, evaluation, and
adaptation:

```text
versioned state -> bounded candidates -> immutable renders -> hard gates
-> multidimensional evidence -> reason-coded decision -> future state
```

Keep the evidence vector interpretable. Separate signal safety, translation,
timbral identity, groove, and long-form trajectory; do not let one aggregate
score compensate for a hard failure or encourage flattened output.

Keep musical policy and signal policy distinct. `AutoTechnoCore` owns semantic
intent, canonical score, and future musical selection. `AutoTechnoDSP` may own a
stateless or stateful signal-domain guard when it measures and corrects the
detached render it produces. Before DSP evidence can change a future musical
decision, reduce it to a bounded, versioned observation that Core can consume
without depending on DSP types.

Version the engine, quality policy, private fixture/continuation state, route,
candidate set, derived reference profile, evidence, decision, and outgoing
controller state. Identical versioned inputs and app-owned PCM must reproduce the
same result.

Apply adaptations only at unscheduled sample-indexed boundaries. Bound candidate
and rerender counts, parameter ranges, slew, hysteresis, hold conditions, and
recovery. Reject stale or incomplete evidence without blocking playback. If work
misses its deadline, preserve coherent prepared material and deterministic state.
A correction confined to one detached render may remain stateless. Persist it
only when the intended behavior spans bars or phrases; then version its state and
define reset, hold, continuation, and fallback explicitly.

For hybrid feedback, copy only app-owned mixer PCM into a preallocated lock-free
handoff on the callback. Analyze fixed windows in bounded background work. Never
open a microphone, use wall-clock timing as evidence, or mutate current/scheduled
audio.

Legal reference recordings and external analyzers are development inputs only.
Keep audio local and untracked; commit only non-reconstructable derived profiles.
Human or source observations may propose a falsifiable deficit, but automated
qualification alone promotes an engine/policy revision.

Do not invent a threshold for an adjective such as brittle, muddy, weak, or busy.
First isolate which dry role, bus, graph stage, or output stage produces the
deficit. Calibrate a range from stable engine baselines or a documented derived
reference profile, protect the dimensions that must not change, and add a failure
case that would reject the proposed proxy. When the required harness or schema is
not implemented, record that qualification is unavailable rather than treating a
handwritten report as a passing policy.
