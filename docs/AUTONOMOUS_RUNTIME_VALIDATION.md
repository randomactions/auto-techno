# Autonomous Runtime Validation

Release status is reported as five separate states: implementation,
structural/signal validation, automated quality qualification, app/runtime
verification, and hardware soak. Passing one does not imply the others. Human
listening may propose a new measurable hypothesis or help diagnose a failure,
but it is not a qualification step and cannot override a failed automated
result.

This file is the evergreen release contract. Dated measurements and superseded
candidate records live in [`history/VALIDATION_SNAPSHOTS.md`](history/VALIDATION_SNAPSHOTS.md).

## Required build gate

Run with a matching macOS Swift compiler and SDK:

```bash
swift test
swift build -c release
```

Record the exact commit, toolchain, fixture/continuation state, sample rates, and
quality-contract revision. A result from another head or an unidentified state is
not release evidence.

## Automated quality qualification

The canonical session must qualify at named structural checkpoints, including
initial establishment, chapter change, contrast, break, release, identity return,
and long-run continuation. Qualification combines hard invariants with a
versioned, multi-dimensional professional-quality contract; no single movement,
loudness, novelty, or spectral metric may approve output by itself.

Hard invariants must cover:

- finite samples, peak and true-peak ceilings, DC, low-band mono compatibility,
  inter-buffer boundaries, bounded feedback energy, and masking protection;
- exact resolved-score-to-PCM event ownership, role-stem reconstruction, and
  agreement between analyzed post-controller stems and the audible mix;
- fixed low-end routing, unchanged detector provenance, graph validity,
  transition continuity, retiring tails, and output-safety ordering;
- absence of retired runtimes, selectable render profiles, microphone input, and
  unsupported executable surfaces.

Professional-quality evidence must cover the relationships the engine can act
on: role hierarchy, spectral balance, transient definition, dynamics and crest,
low-end stability, spatial coherence, density and intentional space, motif and
timbral identity, repetition versus variation, tension/payoff timing, and
long-form stagnation. Each dimension has a documented target or guardrail,
analysis window, normalization rule, and failure explanation. A candidate passes
only when it satisfies every hard invariant, clears the aggregate qualification
threshold, and introduces no guardrail regression at protected checkpoints.

Sample hashes remain regression evidence, not a musical-quality score. An
intentional hash change requires a new exact-head qualification record; unchanged
hashes do not waive the other checks.

## Determinism and sample-rate consistency

Tests must prove that the same initial state plus the same accepted,
sample-indexed feedback packets produces the same candidate set, selected plan,
graph, immutable PCM, evaluator/controller state, and outgoing continuation
state. Candidate order, ties, missing evidence, and fallback selection must be
deterministic.

Run equivalent journeys at 44.1 and 48 kHz and across a route change. Decisions
must be based on rate-normalized evidence and select the same musical intention,
candidate class, and controller direction unless a documented safety constraint
requires a rate-specific fallback. Rate changes may change sample counts and
PCM hashes; they must not silently change identity, dramatic obligations, or
accepted-feedback provenance. Rebuilding at the new rate must preserve coherent
continuation and reject stale work from the previous route.

## Bounded generation, evaluation, and adaptation

Candidate count, full renders, corrective rerenders, analysis windows, and total
work per future boundary must each have an explicit finite maximum. Tests must
exercise those maxima and prove that invalid or low-quality output cannot trigger
unbounded search. The runtime must always end in one of three states: a qualified
candidate, a deterministic conservative fallback, or a coherent repeat/hold of
the last qualified material.

Controller tests must cover:

- gain and parameter bounds, slew limits, deadbands, hysteresis, and coupled-role
  constraints;
- convergence from both sides of each target without drift after entering the
  accepted region;
- alternating and adversarial evidence without oscillation, escalating
  correction, or a repeating limit cycle;
- silent, sparse, invalid, clipped, non-finite, missing, late, and stale evidence;
- state hold, bounded recovery toward home, deterministic fallback, and clean
  reset only at an explicitly defined lifecycle boundary;
- no competition between separate controllers for the same parameter or role.

The selected candidate's evaluator and controller state must be committed
atomically with its plan, render state, graph state, and continuation state.
Rejected candidates must not leak their state. Cache keys and route-recovery
requests must distinguish every state or revision capable of changing selection
or PCM.

## Hybrid feedback and callback isolation

Feedback may analyze only PCM generated and owned by Auto Techno. It must never
open a microphone, request recording permission, capture ambient/system audio, or
depend on an external audio source.

Where scheduled-path feedback is used, callback work is limited to copying a
fixed maximum of PCM into a preallocated, single-writer lock-free exchange and
advancing lock-free indices. Tests and instrumentation must demonstrate no
allocation, lock, wait, analysis, logging, file/network I/O, UI work, or musical
decision on the callback. Full-capacity behavior drops the observation without
blocking or corrupting audio.

Background analysis must have fixed memory and work bounds. Every accepted
packet records the exact source sample range, route/sample-rate generation,
controller revision, and target future sample boundary. Partial, overwritten,
late, stale, or mismatched packets are rejected. Decisions may affect only audio
that has not been scheduled and may take effect only at their declared future
boundary. Tests must prove that current and already scheduled buffers remain
immutable and that a missed deadline follows the deterministic hold/fallback
path without a gap.

## Preparation budget

Measure detached preparation and background analysis for the minimum and maximum
phrase lengths, maximum candidate/rerender path, conservative fallback, and route
rebuild at representative 44.1 and 48 kHz devices. Record median, high-percentile,
and worst observed times plus peak working memory.

The declared budget must leave enough lookahead to schedule the future boundary
without callback work or silence. A late successor may repeat the current
qualified phrase with frozen topology, but repeated deadline misses, unbounded
queue growth, or analysis that starves preparation fail qualification. Cancellation
and stale-result rejection must release bounded background work promptly.

## App/runtime verification

On the exact release build, verify:

- one accessible transport button and coherent preparing, ready, live, paused,
  recovering, and unavailable states;
- prepare, play, pause, resume, and phrase-boundary continuation;
- sample-time scheduling, future-boundary controller application, and read-only
  waveform/position reporting;
- late-successor hold without silence, premature state advance, or state leakage;
- coherent 44.1/48 kHz route recovery with stale feedback and preparation rejected;
- no recording permission prompt, microphone device access, or external audio
  dependency.

## Physical-output soak

Before claiming release readiness, run for at least 60 minutes on physical output.
During the run:

1. pause and resume repeatedly;
2. change output routes and sample rates;
3. trigger and recover from an interruption;
4. sleep and wake the Mac;
5. exercise normal, maximum-candidate, fallback, and missed-analysis-deadline paths;
6. confirm continuous phrase progression, bounded controller state, stable CPU and
   memory, and no clicks, gaps, runaway tails, oscillating balance, crashes, or
   disabled transport.

Record hardware, OS, sample rates, exact commit, quality-contract revision,
start/end times, preparation and analysis timing, controller/fallback events,
interventions, and observations. A missing soak is reported as unverified, never
inferred from unit tests, builds, simulations, or prior snapshots.
