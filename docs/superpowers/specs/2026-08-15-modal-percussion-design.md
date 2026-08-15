# Modal Percussion Design

## Status

Approved conversational design for two ordered implementation stages:

1. replace and deepen the existing tuned-tom foundation companion;
2. add a separately admitted sparse modal-percussion role that can coexist with
   bass or rumble.

The stages share one score articulation contract and one original deterministic
modal-resonator capability. Each stage is implemented, qualified, published,
and made available in a launched exact app independently before work begins on
the next stage. Listening remains optional evidence and is not a promotion gate.

## Decision

Use two separately qualified vertical slices rather than one combined cutover or
two independent percussion mechanisms.

- Stage 1 replaces the current root-only `tunedTom` renderer in place. It keeps
  the existing Broken Suspension ownership, foundation routing, onset count, and
  ensemble timing while making pitch and material a real score-owned modal
  relationship.
- Stage 2 reuses the same articulation and DSP primitive for a new sparse
  percussion-role event. The canonical ensemble score admits that event; the
  renderer never invents it.
- No old tom renderer, compatibility selector, alternate engine, paired
  candidate, permissive policy, or musical fallback remains after either
  cutover.

This order makes the first change attributable: Stage 1 can prove that a better
foundation voice is safe and qualified before Stage 2 changes density and role
coexistence.

## Product invariant

Modal percussion remains part of the one-button autonomous performance:

- one `AutonomousSessionDirector`;
- one canonical resolved score;
- one detached `AutonomousPhraseRenderer`;
- one exact-engine calibrated primary evaluator;
- one immutable prepared-PCM commitment;
- no user-facing instrument, material, tuning, or role selector;
- no plug-in, sample library, external recording, cloud service, or additional
  executable;
- no planning, randomization, analysis, evidence reduction, logging, allocation,
  or musical decision in the audio callback.

The same engine, policy, initial state, accepted continuation, and route must
reproduce the same score, resonator state, PCM, evidence, and terminal decision.

## Current deficit

### Stage 1 checkpoint

The current `Tuned Percussive` foundation behavior is reached only when Broken
Suspension selects its tuned-tom companion at a structural marker. The score
admits at most two `tunedTom` events at existing characteristic syncopations.
The renderer then ignores their relationship to the modal vocabulary: every
event uses one scene-root frequency and the same 220 ms two-sine pitch-glide
function.

This is a measurable capability deficit rather than a taste adjective:

- the resolved event carries no explicit modal degree, register, material, or
  damping intention;
- multiple tuned-tom events in a bar do not form a modal relationship;
- the two-sine renderer has no dedicated event-local score-to-PCM record;
- the voice has no explicit tail-continuation fingerprint;
- the calibrated evaluator can observe aggregate foundation consequences but
  cannot attribute pitch, excitation, resonance, or decay to the tuned event.

The canonical establishment, contrast, major-break, release, and identity-return
journey bank is the baseline. Broken Suspension structural-marker bars that
naturally contain `Tuned Percussive` are the primary Stage 1 checkpoints.

### Stage 2 checkpoint

After Stage 1, modal resonance remains confined to a rare foundation
substitution. The score still has no independently admitted tonal-percussion
punctuation that can converse with a bass or rumble foundation.

The Stage 2 deficit is demonstrated by the complete absence of a
percussion-role modal-resonator event in canonical journeys. The target is not
more generic density: it is one sparse, score-motivated modal accent at a
structural gesture while the existing foundation remains authoritative.

## Shared Core contract

### Articulation

`AutoTechnoCore` owns one `ModalPercussionArticulation` for both stages. Each
record binds exactly one resolved ensemble event and contains:

- the score event index and normalized sixteenth step;
- semantic use: `foundationCompanion` or `sparsePercussion`;
- modal degree and octave/register chosen from the current `SceneDNA`;
- excitation, damping, and brightness in `0...1`, plus inharmonicity in
  `0...0.12`;
- the resolved event intensity;
- a deterministic articulation seed derived from scene identity, absolute bar,
  event index, and semantic domain.

Event intensity is clamped to `0...1`. Foundation fundamentals are folded into
`48...196 Hz`; sparse-percussion fundamentals are folded into `96...784 Hz`.
Every scalar is clamped by the Core initializer to its finite range.
No renderer parameter exists without one of these score meanings or a fixed
implementation constant inside the single resonator.

`ModalPercussionResolver` runs after ensemble arbitration. It may describe only
an event that survived into `ResolvedPerformanceBar.ensemble`; it cannot add,
move, or replace an event. It returns articulations ordered by score event index.
The resolved bar retains the bounded articulation list, and typed plan
fingerprinting includes every field.

### Pitch ownership

The resolver derives pitches from `SceneDNA.modalDegrees`, the continuing tonal
center, and the existing motif/harmonic context. DSP receives an already
resolved fundamental; it does not quantize, choose a scale, run an arpeggiator,
or consult a hidden clock.

Foundation-companion pitches are folded into a low, mono-safe register and use
the current motif degrees in deterministic event order. Root is always a legal
home. When two events survive, the second resolves to a distinct modal degree;
if the motif contains only one degree, absolute macro position selects the next
ordered degree from `SceneDNA.modalDegrees`. Non-root degrees are placed high
enough to avoid a low semitone collision with the kick. Sparse-percussion
pitches use the same modal source in a higher register and cannot claim a pitch
outside the scene vocabulary.

Pitch validation proves both the integer modal relation and the route-specific
applied frequency. A finite applied fundamental must remain below the
resonator's rate-derived ceiling.

## Stage 1: foundation replacement

### Canonical owner and bounds

Stage 1 extends `FoundationBehavior.tunedPercussive` and the existing
`EnsembleVoice.tunedTom` events. It does not add a new event, change a requested
step, alter ensemble priority, or change the maximum of two events in the bar.

Eligibility remains exactly the existing Broken Suspension structural-marker
relationship. Every other foundation behavior produces no foundation modal
articulation. Identity return remains on its existing Hypnotic Lock bass home.

The resolved articulation may vary pitch, excitation, damping, brightness, and
inharmonicity only inside the shared bounds. Those choices are coordinated from
the same phrase character, gesture, macro position, modal DNA, and event
intensity; they are not independent random rolls.

### Routing

The rendered signal replaces the old tuned-tom samples in the exact same
protected foundation route:

```text
resolved tunedTom event
  -> ModalPercussionArticulation(.foundationCompanion)
  -> shared ModalPercussionVoice
  -> dry foundation stem
  -> existing foundation masking and automatic-mix observation
  -> protected rhythm recombination
  -> existing glue and master safety
```

It does not enter the percussion stem or add a new FDN/effect send. Kick remains
the pre-fader ducking detector. Existing automatic mixing may observe the changed
foundation stem but gains no new controller or independently moving parameter.

The private `tom()` function is deleted when the replacement is green. There is
no retained root-only implementation and no runtime switch between old and new
PCM.

## Stage 2: sparse percussion role

### Canonical owner and admission

Stage 2 adds `EnsembleVoice.modalPercussion`, mapped to
`PerformanceRole.percussion`. It is proposed by the existing ensemble-planning
path and admitted or omitted by the existing arbiter. The renderer cannot create
the role when it is absent from the resolved score.

An event is eligible only when all of these score facts agree:

- the percussion role is active;
- the phrase is a contrast or energy release, including a Broken Suspension
  contrast with its rumble foundation;
- the foundation behavior is bass- or rumble-backed, never `tunedPercussive` or
  `absent`;
- the arrangement gesture is `gearShift` or `turnaround`;
- the absolute sixteen-bar position is the existing `gearShift` or `turnaround`
  slot, so the geometry itself permits no more than two sparse events per macro
  without adding a counter state;
- a characteristic syncopation can survive arbitration without displacing a
  kick or foundation event.

The proposal contains one requested onset and no renderer-side alternates. If
the existing arbiter cannot admit it without violating higher-priority kick,
foundation, narrative, or density constraints, the event is omitted. DSP does
not relocate it, invent a replacement, or fall back to another percussion
carrier.

At most one sparse modal-percussion event exists in an eligible bar and at most
two exist in one sixteen-bar macro. It may coexist with bass or mono rumble. It
may not coexist with the tuned-percussion foundation in the same bar.

### Routing

The Stage 2 articulation selects `.sparsePercussion` and reaches the same
`ModalPercussionVoice`. Its dry output enters the existing percussion stem, the
existing percussion-role reconstruction/masking path, and existing percussion
ambience. It does not add a new return, bus, graph, or effect chain.

The new role remains distinct from existing capabilities:

- `GroovePulseResolver` still owns weak-sixteenth carrier onsets and physical
  strike/damping grouping;
- hats, clap, open hat, and metallic percussion keep their existing owners;
- gated percussion still delays an existing admitted source through its
  score-owned window;
- phrase-local slicing still resamples exact app-owned kick/percussion PCM in a
  major break;
- arpeggiation and pads still own their complete modal note and harmony geometry;
- modal percussion schedules no sequence and captures no reusable PCM.

## Shared DSP capability

### Module boundary

`AutoTechnoDSP` adds a focused `ModalPercussionVoice.swift`. `VoiceRenderer`
maps resolved events to the module and routes its returned dry samples and
evidence; it does not contain a second resonator implementation.

The voice is an original deterministic physical-model-inspired resonator:

- one at-most-2 ms band-limited excitation containing a smooth impulse and a
  seeded, zero-mean noise component;
- a fixed six-mode resonator bank whose fundamental comes from the score;
- strictly stable rate-derived pole radii below one;
- mode frequencies clamped below `0.9 * Nyquist`;
- energy-normalized mode weights controlled by score brightness and
  inharmonicity intentions;
- per-mode decay controlled by score damping, with the audible T60 bounded to
  `0.18...0.65` seconds for foundation use and `0.08...0.42` seconds for sparse
  percussion;
- no private nonlinear output-colour stage in the initial realization; the
  existing downstream glue and master-safety owners remain unchanged;
- mono dry output so the existing foundation and percussion placement owners
  remain authoritative.

The exact mode ratios, excitation duration, and weight curve are replaceable
renderer details. The durable contract is a modal pitch exciting one bounded
decaying resonant object with score-owned material movement.

### Continuation and capacity

`RenderState` owns one fixed-capacity `ModalPercussionVoiceState`. It contains a
fixed four-voice bank with six fixed resonator states per voice plus bounded age
and activity metadata. No per-event heap object, dynamic voice array, lock, or
callback state is introduced.

The score limits and maximum decay are chosen so four voices are sufficient for
all legal cross-bar overlap. Plan validation proves that bound before rendering.
The renderer never steals a voice and never substitutes the old tom. A capacity
violation makes evidence incomplete and the primary decision reject; signal
safety may silence non-finite samples but cannot authorize a different musical
result.

Tails continue across rendered bars through the same `RenderState` used by the
canonical renderer. Route-rate changes rebuild coefficient geometry
deterministically. Attempt-local home-timbre correction starts from the same
incoming render state and must leave modal-percussion score and dry PCM
unchanged; the correction remains an upper-timbre correction only.

## Evidence contract

### Event evidence

Every resolved modal-percussion event emits one compact same-pass record:

- bar, score event index, voice, step, and semantic use;
- modal identity, degree, octave, requested fundamental, and applied frequency;
- excitation, damping, brightness, inharmonicity, and intensity;
- mode count, ordered mode-ratio fingerprint, minimum/maximum applied frequency,
  and maximum pole radius;
- excitation fingerprint and exact isolated dry-sample hash;
- rendered frame and nonzero-sample counts;
- peak, RMS, crest factor, attack RMS, body RMS, tail RMS, tail-to-body dB, and
  spectral centroid;
- incoming and outgoing voice-state fingerprints;
- finite, stable, capacity-valid, score-binding, and route-binding facts.

Raw excitation or output PCM is not retained in candidate evidence.

### Bar and phrase evidence

Every rendered bar carries one ordered modal-percussion record, including an
explicit neutral record when no event is resolved. Full and protected render
passes must agree on score geometry, articulation, dry hash, metrics, and
continuation. Stage 1 evidence binds active events to the foundation stem; Stage
2 evidence binds them to the percussion stem.

The candidate vector requires complete bar coverage and rejects:

- a missing, duplicate, reordered, or unbound event;
- a non-modal pitch or rate-invalid applied frequency;
- an out-of-range semantic parameter, mode count, pole radius, or voice count;
- a non-finite or malformed fingerprint/metric;
- a score/render event mismatch;
- a foundation event routed as percussion or a sparse event routed as
  foundation;
- disagreement between full and protected passes;
- a changed modal-percussion consequence during the upper home correction;
- Stage 2 coexistence with `tunedPercussive`, or density beyond its bar/macro
  limits.

The single primary policy receives the record as a non-compensable provenance
and safety boundary. Aggregate professional observations add calibrated
attack/body/tail, pitch-accuracy, modal-percussion masking, and rate-relationship
dimensions at applicable checkpoints. A centered metric cannot compensate for
broken score binding, unstable resonance, incorrect routing, or excess density.

## Primary evaluator and qualification

Each stage is a distinct exact-engine revision. At the final rebase before a
stage begins, it advances the then-current canonical engine, quality-contract,
candidate-vector, typed-fingerprint, continuation, profile, adversarial-suite,
and holdout identities exactly once. Stage 2 advances them again; it never
reuses Stage 1 artifacts after changing score admission or PCM.

For each stage:

1. regenerate the complete 44.1/48 kHz development corpus from the exact engine;
2. require every canonical checkpoint and complete modal-percussion evidence;
3. calibrate independent primary-policy dimensions without averaging failures;
4. add adversarial cases for detuning, unstable poles/runaway tail, extra onset,
   wrong stem, forged event binding, broken continuation, route-rate mismatch,
   and non-finite output;
5. add the Stage 2-specific over-density and forbidden tuned-foundation
   coexistence attacks when Stage 2 exists;
6. qualify a disjoint replacement-journey holdout at both supported rates;
7. prove exact operational replay and unsupported-route unavailability;
8. install only the new exact artifacts in the app bundle and remove the prior
   stage's resources.

Until those artifacts pass, policy availability is false and no newly prepared
phrase may commit. There is no permissive or older-profile runtime path.

## Failure and recovery behavior

- Malformed score articulation fails preparation validation before PCM is
  eligible to commit.
- Non-finite input or resonator state is contained locally, marked invalid in
  evidence, and rejected by the primary evaluator. It does not choose another
  voice.
- Unsupported sample rates or missing exact artifacts report qualification
  unavailable and cannot commit.
- Cancellation or route epoch change discards the attempt and its outgoing
  modal state; stale work cannot publish or schedule.
- A missed successor deadline repeats already accepted immutable PCM under the
  existing transport hold. This is continuity of accepted material, not a
  musical fallback or alternate evaluator.
- Pause/resume retains the already accepted sample-time schedule and versioned
  render continuation. A route rebuild deterministically reconstructs legal
  coefficient geometry at the active supported rate.

## Realtime boundary

All score resolution, articulation derivation, resonator rendering, evidence
measurement, primary evaluation, and artifact access remain in detached
preparation. The app callback continues to schedule and play immutable prepared
PCM.

Stage 1 and Stage 2 add no callback function, callback buffer, lock, allocation,
analysis, parameter lookup, random generator, logging, file/network access, or UI
work. Live feedback remains the next separate programme item and cannot be
smuggled into modal percussion.

## TDD and verification

Implementation follows red-green-refactor for every behavior. A production
change is written only after its focused test has failed for the expected missing
behavior.

### Stage 1 required evidence

- Core tests prove existing tuned-tom onsets and count are unchanged, every
  articulation is modal/bounded/deterministic, and ineligible paths are empty.
- DSP tests prove pitch accuracy, stable six-mode decay, excitation determinism,
  physical-time rate consistency, exact chunk/bar continuation, capacity bounds,
  finite aggressive articulation, and distinct PCM for distinct modal intent.
- Routing tests prove exact foundation ownership, mono compatibility, full and
  protected equality, unchanged kick detector, and no percussion/upper leakage.
- Candidate tests prove complete/tamper-resistant evidence and unchanged modal
  PCM across the upper home correction.
- Repository-surface tests prove the old `tom()` implementation and retired
  candidate/fallback terminology are absent from active code and normative docs.
- The regenerated profile, adversarial suite, disjoint holdout, full serial test
  suite, optimized release build, exact-head CI, launched app, app/route checks,
  listening, and physical-output soak are reported as separate states.

### Stage 2 required evidence

- Core tests prove reachability with both bass and rumble, exact absence with
  tuned/empty foundation, no identity-return or major-break admission, one-event
  bar and two-event macro limits, and deterministic omission on collision.
- Renderer tests prove reuse of the exact Stage 1 DSP primitive, percussion-stem
  ownership, full/protected equality, deterministic continuation, and no changes
  to slicer, arpeggiator, pad, groove-pulse, hat, or gated-return owners.
- Candidate tests prove score/PCM/routing binding and reject forged coexistence,
  over-density, role, degree, state, or route facts.
- Corpus tests prove natural canonical journeys reach sparse modal percussion
  with both permitted foundation families without making it omnipresent.
- Stage 2 receives its own regenerated primary artifacts and repeats the same
  release, CI, app, listening, route, and soak separation.

## Documentation cleanup

Stage 1 updates the active product, sound-quality, runtime-provenance,
performance-grammar, maturity, validation, roadmap, and README surfaces. It
removes active descriptions of conservative/nonconservative candidates,
conservative scores, alternate candidates, development/frozen policies, and
fallback phrases that no longer exist after the single-primary cutover.

Historical validation and taste records may retain those words only as dated
history. Active documentation must describe one plan, one primary evaluator,
one optional same-plan upper correction, explicit rejection/unavailability, and
accepted-PCM transport hold.

Stage 2 adds the sparse-role compatibility and evidence contract to the same
documents without presenting it as a user-facing instrument or track.

## Implementation and publication sequence

The shared design has two dependent implementation plans and branches:

1. rebase Stage 1 from the latest exact `origin/main` safe point;
2. implement Stage 1 through TDD, regenerate artifacts, validate, publish, wait
   for exact-head CI, and launch the exact release app;
3. merge or otherwise establish the Stage 1 exact SHA as the next safe main
   point;
4. create Stage 2 from refreshed main at that SHA;
5. implement and qualify Stage 2 through the same gates;
6. only after Stage 2 exact-head CI and app verification begin the separate Live
   Feedback design cycle.

Before each implementation or publication phase, refresh other active Auto
Techno tasks, exchange exact SHAs and touched-file lists, and avoid concurrent
edits to score, renderer, evaluator, schema, calibration resources, shared tests,
or normative sound/runtime documentation.

## Explicit non-goals

- no user control, MIDI input, patch browser, or material selector;
- no drum sampler, external corpus, captured loop, granular engine, or alternate
  sequencer;
- no second percussion renderer or stage-specific DSP fork;
- no polyphonic melodic instrument disguised as percussion;
- no new mastering controller or callback-time adaptive filter;
- no paired selection, fallback candidate, legacy policy, or compatibility
  profile;
- no claim of professional release quality from structural tests alone;
- no Live Feedback implementation inside either modal-percussion stage.
