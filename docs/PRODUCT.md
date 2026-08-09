# Auto Techno Product Contract

## Purpose

Auto Techno is a standalone macOS instrument for starting and sustaining one
coherent techno performance with one button. It is not a DAW, sequencer editor,
plug-in host, preset browser, engine selector, or collection of render
experiments.

## Central invariant

Every autonomous decision expresses a musical intention. Its destination,
transition, and consequence in the continuing performance must remain coherent.

Play asks the instrument to continue its one performance. Pause and resume
preserve position, identity, and adaptation state. Technical evidence may be
shown read-only, but no compositional, synthesis, mixing, mastering, or quality
parameter belongs in the primary UI.

## Shipped experience

- one accessible transport button;
- explicit preparing, ready, live, paused, recovering, and unavailable states;
- fixed 130 BPM;
- one private canonical identity and indefinitely evolving performance;
- phrase and bar position plus lightweight read-only visualization;
- offline operation with no account or cloud dependency.

## One autonomous mechanism

`AutonomousSessionDirector` owns musical identity, intent, temporal memory,
phrase proposals, continuation, and long-range obligations. A selected phrase
contains the canonical resolved score consumed by synthesis, effects, mixing,
telemetry, and future quality evaluation. `AutoTechnoCore` owns decisions;
`AutoTechnoDSP` owns rendering and signal evidence; `AutoTechnoApp` owns
transport, preparation, scheduling, and read-only presentation.

Future work extends this mechanism through shared state, evidence, and bounded
adaptation. Specialized instruments and DSP strategies may vary internally when
the canonical director selects them at an explicit musical boundary. They do not
become alternative runtimes, independent performance models, or user-facing
switches.

The current internal instrument palette implements that boundary with three
engine-owned synthesis architectures and ten score-selected home patches. The
same four bounded semantic automation coordinates move every patch, while the
existing ensemble score continues to own audible role density. See
`INSTRUMENT_PALETTE.md` for the human-readable role and effect matrix.

Every new internal parameter must have a demonstrated path through the resolved
score or renderer into PCM, measurable evidence, and a bounded influence on a
future decision. Parameters that do not reach that path are removed or connected
before the control surface expands.

The current weak-percussion path demonstrates that contract without becoming a
new instrument or mode. `PercussionGear` resolves bounded strike position,
damping, and seeded microvariation for the existing groove-pulse carrier; the
complete eight-pulse syncopated-lean state groups only those existing
intensities into one cyclic 3-3-2 accent/ghost relation. The same render produces
event-local dry-signal evidence, while the conservative candidate preserves the
prior alternating intensity cell and exact neutral carrier. These observations
are retained for a future calibrated policy but do not affect selection while
the shipping evaluator remains uncalibrated.

The ordinary closed-hat path uses the same contract. After ensemble arbitration,
an existing closed hat that shares its resolved onset with the existing open hat
receives one semantic companion role. The renderer shortens only that closed-hat
tail; onset, count, intensity, swing, brightness, level, and the open-hat render
remain unchanged. Same-pass event evidence binds the score event to its exact
dry-sample consequence, and the conservative candidate keeps the legacy neutral
decay exactly.

## Professional-sound objective

The long-term goal is professional release-quality sound produced by engine-owned
synthesis, effects, mixing, and mastering. This objective is pursued iteratively;
it does not describe the current build merely because structural or safety tests
pass.

Playback and release validation must not require a VSTi, Audio Unit instrument or
effect, DAW, sample-library runtime, cloud model, or account. Legal reference
recordings and external analyzers may inform local development, but only derived,
non-reconstructable quality profiles may enter the repository. See
`SOUND_QUALITY.md` for the qualification contract.

## Automated quality and adaptation

The target architecture is one bounded generate, render, evaluate, and adapt
loop. It combines hard signal-safety limits with multidimensional evidence about
mix translation, timbral identity, groove, and long-form behavior. Decisions are
reason-coded and update only persistent state for unscheduled future bars or
phrases.

Quality qualification is automated. A human observation may identify an
additional deficit or motivate a policy revision, but listening is optional and
never the mechanism that selects runtime output or promotes an engine revision.
Until the automated policy exists and passes, professional quality remains an
unverified goal. Professional Evidence v2 supplies standards-based phrase
loudness/true-peak evidence and complete canonical-journey report-bank
validation, but policy truthfully remains unavailable until a calibrated
profile and passing adversarial suite are versioned.

## Hard constraints

- The same engine version, quality-policy version, initial state, continuation
  state, route state, and captured app-owned PCM reproduce the same decisions.
- Planning and quality-policy decisions remain outside the real-time callback.
- The callback performs no allocation, locking, analysis, logging, file or
  network I/O, or UI work.
- Any future live-output capture only copies app-owned PCM into a preallocated
  lock-free handoff; bounded analysis runs in background work.
- Adjustments apply only to immutable snapshots for unscheduled future audio.
- Candidate count, corrective passes, and analysis work remain explicitly
  bounded; missed deadlines preserve coherent prepared playback.
- Route changes rebuild at the active sample rate without silently changing the
  musical identity or corrupting adaptation state.
- Finite output, peak/DC/boundary limits, low-end compatibility, masking,
  controller stability, and preparation headroom remain release obligations.

## Product boundary

The package exposes only the `AutoTechno` executable. Core and DSP targets have
no supported external consumers or source-compatibility promise. Retired
reference engines, comparison executables, old scene APIs, render profiles, and
selectable performance models remain outside the product.
