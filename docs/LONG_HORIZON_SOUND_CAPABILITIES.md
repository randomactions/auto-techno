# Long-Horizon Sound-Capability Register

## Purpose and current decision

This is the follow-up register for DSP, synthesis, patch-family, effect, and
effect-routing work that may be required by the long-horizon performance map.
It must be updated when a listed capability is implemented, qualified, replaced,
or rejected.

The 2026-08-23 video study does **not** justify immediately adding a synth,
preset pack, effect bus, or selectable chain. The dominant current deficit is
hour-scale musical state and evidence. Auto Techno already has enough internal
sound vocabulary to implement and test the first long-horizon controller:

- three engine-owned synthesis architectures and eleven recognizable patch
  homes;
- coordinated color, shape, motion, and space automation;
- six phrase-scale performance characters;
- protected kick/foundation routing and multiple percussion material roles;
- polyphonic pads, harmonic disclosure, arpeggiation, and phrase-local
  resampling;
- a shared nonlinear/filter core, chorus, comb, unsynced and pulse echo,
  filtered returns, generated graph processing, and an eight-line FDN;
- anticipation, gated answer, spectral cluster, sustained wash, climax absence,
  and structural recovery relations.

The immediate sound-related foundation is to measure how these capabilities are
used and recover over time. Phase 2 records fixed-domain semantic capability
recency and rare-operator reserve in the canonical continuation. Phase 3 now
exercises the existing palette through episode-aware phrase selection and still
exposes no repeatable missing sound capability. Only a trajectory or translation
deficit should trigger richer DSP. This prevents speculative variety from hiding
a weak director.

The controlling design is
[`LONG_HORIZON_PERFORMANCE_MAP.md`](LONG_HORIZON_PERFORMANCE_MAP.md). The stable
current patch/effect matrix remains
[`INSTRUMENT_PALETTE.md`](INSTRUMENT_PALETTE.md), and renderer-replacement rules
remain [`SOUND_CONCEPT_MATURITY.md`](SOUND_CONCEPT_MATURITY.md).

## Source-to-capability translation

| Source-derived need | Existing mechanism to exercise first | Expansion question |
| --- | --- | --- |
| Escalate through a small element rather than replace everything | role admission, percussion gear, character automation, spectral reveal, upper-tail role | Can the same recognizable source traverse enough attack/body/color states without audible coefficient cycling? |
| Make intensity meaningful through lower-energy context | subtraction, major break, absent/kick-tail foundation, protagonist contour, terminal absence | Does rendered recovery actually reduce density, loudness, brightness, wetness, and fatigue in the intended relationship? |
| Preserve headroom and reserve ideas | dramatic debt, payoff syntax, character recency, home correction | Do rare transition and character capabilities have tracked dose, cooldown, and reserved availability? |
| Use effects to create space, not on every transition | existing typed effect access, pulse echo, gated return, FDN, filter motion | Can the evaluator detect overuse and prove a wet effect has cleared before the next statement? |
| Reframe familiar material with occasional surprise | motif transformations, character reinterpretation, slicer, arpeggiator, spectral texture | Does a rare capability remain causally connected to identity and sufficiently absent before recall? |
| Sustain four-to-five-hour performance | deterministic continuation, bounded DSP state, current palette | Which sound family actually becomes perceptually exhausted after hierarchy and dose control are working? |

## Capability register

Status meanings:

- **foundation required** — needed to evaluate long-horizon sound use, but may
  not change PCM;
- **conditional maturation** — implement only after the named evidence exposes
  the deficit;
- **not justified** — the current source study does not supply a bounded need;
- **implemented / qualified / runtime-verified / soak-passed** — later states
  that must name the exact engine and policy revision.

### LH-SND-01 — multi-rate semantic modulation

**Status:** foundation required after the Core trajectory schema.

- **Canonical owner:** the existing score-owned `InstrumentAssignment` color,
  shape, motion, and space coordinates; each current architecture keeps its one
  renderer and continuation state.
- **Deficit trigger:** accepted multi-episode journeys show stationary or
  visibly stepped timbre despite planned slow evolution, or the same automation
  contour recurs at a short fixed period.
- **Reusable capability:** one bounded, sample-indexed control trajectory that
  can interpolate a score-owned coordinate across bars/phrases while retaining
  exact home and patch identity.
- **Evidence:** requested start/end/turning points, applied min/max/slew, exact
  affected assignment/events, dry pre/post fingerprints, neutral identity,
  route-rate normalization, and trajectory recurrence.
- **Bounds and fallback:** planning remains off callback; immutable envelopes
  are prepared for future audio; invalid or late trajectories use the existing
  per-assignment value and do not disturb continuation.
- **Duplicate avoided:** no free-running modulation engine, fourth automation
  lane, or renderer-side musical choice.
- **Supersedes if implemented:** the affected architecture's stepped scalar
  projection in place; it must not run beside it.

### LH-SND-02 — effect dose, cooldown, and recovery evidence

**Status:** foundation required; evidence-first, no new effect.

- **Canonical owner:** existing effect access, graph, pulse/unsynced echo,
  chorus, comb, filtered returns, gated/anticipatory return, and FDN evidence.
- **Deficit trigger:** none is required for the evidence foundation; the current
  evaluator cannot state whether an effect family has been active too often or
  whether its previous tail has cleared.
- **Reusable capability:** a reduced per-phrase capability-use vector containing
  eligibility, dry/wet consequence, occupancy, active duration, tail state,
  last-use bar, and recovery.
- **Evidence:** exact existing effect records aggregated by one versioned owner;
  false eligibility, disconnected wet claims, and an active tail reported as
  recovered are adversarial failures.
- **Bounds and fallback:** fixed-capacity recency counters and tail summaries;
  missing evidence prevents long-horizon qualification but does not add or
  mutate audio.
- **Duplicate avoided:** no parallel FX telemetry ledger with different effect
  meanings.

### LH-SND-03 — phrase-level effect sentence

**Status:** foundation required before effect DSP expansion.

- **Canonical owner:** existing motif, response, transition, percussion-return,
  pulse-echo, and structural-gesture relations.
- **Deficit trigger:** the current sound-concept register already identifies the
  absence of phrase-level call/response/turnaround evidence.
- **Reusable capability:** a semantic record that binds one initiating event,
  any delayed answer, structural turnaround, attention priority, and exact dry/
  wet consequence.
- **Evidence:** source/answer timing, role ownership, effect-state provenance,
  dry and wet hashes/RMS, tail clearance, masking, protected rhythm, and neutral
  phrases.
- **Bounds and fallback:** at most one owned sentence relation at a declared
  future boundary; incomplete causality stays with the existing independent
  effect permissions.
- **Duplicate avoided:** no effect-phrase sequencer or second return graph.

### LH-SND-04 — transition and payoff maturation

**Status:** conditional maturation.

- **Canonical owner:** dramatic debt, energy-release phrase, anticipation swell,
  spectral cluster, sustained wash, terminal hang, and unchanged kick recovery.
- **Deficit trigger:** calibrated long-horizon evidence repeatedly rejects
  payoff contrast, rise, boundary clarity, or post-payoff recovery while score,
  density, route, and safety evidence are valid.
- **Possible in-place directions:** higher-resolution MSEG contours,
  transient-aware reverse processing, bounded multitap diffusion, envelope-
  aware spectral motion, or more truthful silence/re-entry geometry.
- **Evidence:** debt/payoff provenance, early/late rise, exact recovery, wet/dry
  intelligibility, transition artifact checks, and no repeated fixed-period
  deployment.
- **Fallback:** retain the current qualified transition relation or exact neutral
  path; no generic riser, impact track, or selectable climax.
- **Supersedes:** the specifically failed provisional transition DSP rather than
  coexisting as another climax chain.

### LH-SND-05 — percussion material depth

**Status:** conditional maturation.

- **Canonical owner:** existing kick, groove-pulse, clap/hat/metallic roles,
  modal-percussion foundation, and their score-owned articulation.
- **Deficit trigger:** long-horizon role-local fingerprints and physical metrics
  show perceptually stationary attack/body/tail behavior, or calibrated
  translation repeatedly fails despite appropriate structural variation.
- **Possible in-place directions:** richer coupled resonators, strike-position
  excitation, material-aware envelopes, oversampled nonlinear transients, or
  role-aware excitation and damping.
- **Evidence:** event-local score binding, attack/body/tail relationships,
  centroid and band energy, alias/fold evidence, masking, continuation, exact
  protected/full equality, and capability recurrence.
- **Fallback:** current deterministic voice and neutral articulation.
- **Supersedes:** the affected provisional voice or curve; never add a duplicate
  percussion lane or sample-library dependency.

### LH-SND-06 — longer harmonic and motif syntax

**Status:** conditional maturation.

- **Canonical owner:** session modal DNA, four-voice pad, accepted harmonic
  continuation, disclosure, arpeggiator, protagonist motif, and identity return.
- **Deficit trigger:** a calibrated trajectory identifies predictable function
  cycles, weak long-range recall, or a failed payoff after a valid absence,
  without timbre, density, or masking being the cause.
- **Possible in-place directions:** longer functional obligations, suspensions,
  passing tones, tension-aware inversion choice, chord-aware arpeggiator rests/
  ties, or an altered recall that resolves to the same modal identity.
- **Evidence:** function and voicing recurrence gaps, common-tone/movement
  continuity, motif fingerprint establishment and recall, exact score/render
  pitch, dissonance bounds, and neutral home behavior.
- **Fallback:** existing concealed/partial/revealed grammar and accepted voicing.
- **Duplicate avoided:** no second chord track, MIDI engine, or chromatic style
  selector.

### LH-SND-07 — evolving spatial scene

**Status:** conditional maturation.

- **Canonical owner:** the current score-owned spatial carrier, scene-derived
  eight-line FDN, early reflection, and protected low-end contract.
- **Deficit trigger:** long-duration evidence finds stationary wet color,
  insufficient depth differentiation, accumulated tail fatigue, or failed mono/
  rate translation under otherwise valid score use.
- **Possible in-place directions:** bounded delay modulation, multiband decay,
  higher-order damping, denser early/late coupling, or envelope-conditioned
  diffusion.
- **Evidence:** configuration trajectory, exact input/wet hashes, decay and
  damping ranges, stereo/mono translation, tail recovery, protected-role
  identity, and modulation artifact checks.
- **Fallback:** current FDN v1 state and exact route reset behavior.
- **Supersedes:** FDN v1 inside the same late-field owner; no second reverb,
  spatial profile, or per-patch room.

### LH-SND-08 — dynamics and effect-body maturation

**Status:** conditional maturation.

- **Canonical owner:** current kick conditioner, pulse-return drive, role mix,
  output safety, and live master-headroom controller.
- **Deficit trigger:** repeated calibrated failures in transient/body balance,
  effect-to-dry intelligibility, crest, headroom, or episode-relative dynamics
  after the semantic energy trajectory is correct.
- **Possible in-place directions:** transient-aware upward/parallel source or
  return dynamics, envelope-aware multiband contour, higher-order ADAA or
  bounded oversampling.
- **Evidence:** exact pre/post source or return hashes, attack/body and crest,
  loudness-matched comparison, folded energy, masking, headroom, controller
  stability, and unchanged neutral paths.
- **Fallback:** current qualified conditioner/return behavior and future-only
  live attenuation.
- **Duplicate avoided:** no generic master compressor, loudness-maximizing chain,
  or independent controllers fighting over the same role.

### LH-SND-09 — resampling quality and phrase-spanning source choice

**Status:** conditional maturation.

- **Canonical owner:** current phrase-composition score and phrase-local
  app-owned percussion resampler.
- **Deficit trigger:** calibrated alias, click, transient damage, or repetitive
  source-choice evidence at eligible breakdown checkpoints.
- **Possible in-place directions:** band-limited resampling, transient-aware
  boundaries, stereo-safe grains, or bounded phrase-spanning selection from
  non-reconstructable score/source fingerprints.
- **Evidence:** exact app-owned source provenance, source/output hashes, rate,
  trigger, boundary, alias, transient, and recurrence evidence.
- **Fallback:** current phrase-local source or exact neutral behavior when a
  valid source is absent.
- **Duplicate avoided:** no microphone, system capture, external file, sample
  library, unbounded PCM history, or granular side engine.

### LH-SND-10 — additional patch families

**Status:** not justified.

An additional patch home becomes eligible only if the trajectory evaluator can
show that the existing eleven homes cannot express a required role/register/
episode relationship after coordination and modulation are working. A new home
must document:

- recognizable identity and return behavior;
- eligible role, register, section, and performance character;
- bounded mutation and automation coordinates;
- compatible existing effect access;
- exact score-to-dry-PCM and effect consequence;
- recency/cooldown participation and evaluator dimensions;
- the previous special case it consolidates or the missing capability it adds.

A static preset file, randomized coefficient collection, or new user selector
does not satisfy this requirement.

### LH-SND-11 — another synthesis architecture

**Status:** not justified.

The source study identifies pacing and consequence deficits, not a synthesis
class that Resonant Mono, Tonal Motion, and Spectral Texture cannot express. A
fourth architecture may be proposed only after a calibrated missing-capability
report survives attempts to mature an existing architecture. It would still be
selected by the same score, rendered by the same canonical renderer, and judged
by the same primary evaluator. It may not become an alternative engine.

### LH-SND-12 — fixed or selectable FX chains

**Status:** rejected by product architecture.

Effect compatibility remains a typed permission set and score-owned musical
relationship, not an orderable preset chain. Long-horizon work may orchestrate
the existing shared stages or replace one failed stage in place. It must not add
per-character chain presets, random chains, user selection, DAW-style routing,
or a second graph.

## Implementation order

1. Preserve the implemented Phase 1 semantic schema, Phase 2 canonical
   hierarchy, and Phase 3 one-director operator selection.
2. Coordinate the existing score vocabulary, then add the compatible DSP-owned
   realized-trajectory schema without letting Core depend on DSP.
3. Add effect-dose/recovery and phrase-sentence evidence, initially using the
   current palette, effects, graph, and neutral paths.
4. Calibrate development, adversarial, and disjoint holdout journeys.
5. Select the smallest exact capability whose evidence repeatedly fails.
6. Replace its provisional DSP in one vertical slice and update this register
   before and after implementation.
7. Report structural/signal validation, automated quality qualification,
   app/runtime verification, and physical-output soak separately.

## Update log

| Date | Change | Implementation state | Qualification state |
| --- | --- | --- | --- |
| 2026-08-23 | Completed Phase 3 episode operator selection. The one existing director maps exact bound maintain/rise/recover/reframe/payoff/recall context onto the existing phrase vocabulary, protects minimum holds and rare-event reserve, and establishes dramatic debt before a debtless payoff. Four-hour evidence fulfills all operators with seven payoffs in seven arcs and seven bounded recoveries. No synth, preset, patch, DSP primitive, effect, bus, graph, chain, renderer, or callback was added. | Production Core phrase selection and resulting existing score/PCM choices changed; current sound palette and signal path unchanged | Long-horizon qualification remains unavailable; realized signal trajectory, listening, app/route QA, and soak unrun |
| 2026-08-23 | Completed Phase 2 hierarchical continuation after a second caption pass emphasized branching cooldowns, variable turnover rate, second-wave reserve, sparse-versus-dense headroom, identity recall, and reframing. The canonical Core memory now records bounded semantic capability recency and rare-operator reserve, but does not yet select music or expose a missing sound capability. No synth, patch, DSP primitive, effect, bus, graph, or chain was added or changed. | Production Core continuation state; phrase plan, resolved score, renderer, DSP, graph, App, and PCM unchanged | Encoded unavailable: no calibrated long-horizon policy; realized signal evidence, listening, app/route QA, and soak unrun |
| 2026-08-23 | Completed Phase 1 Core semantic trajectory schema and offline harness. Fixed-capacity capability recurrence now describes use/fatigue across canonical and adversarial journeys, but no realized DSP trajectory or repeatable palette deficit exists yet. No synth, patch, DSP primitive, effect, bus, or chain was added. | Production Core evidence schema plus test-only canonical harness; score, renderer, graph, App, and PCM unchanged | Encoded unavailable: no calibrated long-horizon policy; listening and signal qualification unrun |
| 2026-08-23 | Completed Phase 0 with a frozen versioned four-hour Core planning snapshot, canonical JSON, and separate plan/bar fingerprints. It exposed no sound-capability deficit and authorized no DSP, synth, patch, effect, bus, or chain change. | Test-only descriptive evidence; no score, renderer, or PCM change | Encoded unavailable: no calibrated long-horizon policy |
| 2026-08-23 | Created from the seven-source long-horizon study and current engine audit. Identified evidence-first effect/modulation foundations and conditional maturation paths; selected no new synth, patch, effect, or chain. | Documentation and test-only four-hour planning baseline | Long-horizon qualification unavailable; no PCM change |
