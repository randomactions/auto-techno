# Repository guidance

Keep Auto Techno standalone. Playback and release validation must not require a
DAW, plug-in host, VSTi, Audio Unit instrument or effect, cloud model, account,
or external reference recording.

Read `docs/PRODUCT.md`, `docs/SOUND_QUALITY.md`, and
`docs/AUTONOMOUS_RUNTIME_PROVENANCE.md` before changing musical state,
randomization, synthesis, effects, mixing, mastering, evaluation, transitions,
or audio architecture. Preserve the central invariant: every autonomous
decision, its transition, and its consequence express one coherent musical
intention.

There is one current runtime and one canonical resolved score. All new work must
converge on one persistent generate-render-evaluate-adapt loop through unified
vertical slices; general professional-quality ranking and callback feedback
remain target architecture until implemented and validated. An internal
instrument or DSP strategy may vary only under the same director, score,
continuation, evidence, and fallback contract; never add an alternative engine,
renderer, profile, or user-facing selector.

For every musical implementation, identify in the change and its tests:

1. the existing canonical owner and state being extended;
2. the reusable engine capability being added;
3. the automated quality deficit and evidence that evaluate it;
4. its bounds, continuation, future-boundary application, and fallback;
5. the duplicate or special-case mechanism it consolidates or avoids.

Do not add an internal parameter unless its tested path reaches the resolved
score or renderer, changes PCM as intended, produces truthful evidence, and can
inform a bounded future decision. Keep decisions in `AutoTechnoCore`, rendering
and signal evidence in `AutoTechnoDSP`, and transport/presentation in
`AutoTechnoApp`.

Quality promotion is deterministic and automated. Human feedback, videos, and
reference tracks may motivate a measurable hypothesis, but they are optional
inputs and never approval gates. Reference audio and generated WAVs remain local
and untracked; only non-reconstructable derived profiles may be committed.

Any implementation of quality state or live feedback must preserve
reproducibility for identical engine/policy versions, initial and continuation
state, route state, and accepted sample-indexed app-owned PCM. Planning,
analysis, model inference, mutable preparation, and musical decisions stay off
the real-time callback. Future callback feedback is limited to a bounded copy
into a preallocated lock-free handoff; it never allocates, locks, waits,
analyzes, logs, performs file/network I/O, accesses a microphone, or invokes UI
work.

Keep the primary UI one-button and read-only beyond transport. Use
`.agents/skills/evolve-autonomous-sound` for musical, sound-quality, evaluator,
or controller changes and `.agents/skills/protect-realtime-audio` whenever the
render, scheduling, buffer, or live-feedback path changes.

## Semantic codebase map

Read `docs/CODEBASE_MAP.md` before architectural work. It is a navigation map of
implemented code, not a roadmap or replacement for the normative contracts.
`docs/codebase-map.json` is its only hand-edited source; never edit the generated
Markdown directly. Refresh and validate it with:

```sh
python3 scripts/codebase_map.py generate
python3 scripts/codebase_map.py check
```

Update the manifest in the same change whenever work adds, removes, moves, or
reassigns any of the following:

- source, test, header, resource, or module-dependency ownership;
- a canonical owner or persistent/continuation state;
- score, rendering, evidence, evaluation, feedback, or adaptation flow;
- realtime, detached, actor/thread, route-recovery, fallback, or future-boundary
  behavior; or
- contract or test ownership.

A change may leave the map untouched only when all of those navigation semantics
remain stable; record a concise no-map-impact rationale in the pull request.
Always run `python3 scripts/codebase_map.py check` before completing repository
work. If the map conflicts with current code, `Package.swift`, or a canonical
contract, those sources are authoritative and the map must be repaired in the
same change.
