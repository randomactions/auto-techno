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

The phrase-scale performance grammar coordinates that palette instead of
randomizing layers independently. Six internal characters bind compatible
foundation behavior, kick grammar, role-compatible patches, and automation
while the session DNA and narrative-owned role admission remain stable.
Character selection retains the last two
committed choices, applies only at a future phrase boundary, and returns to the
hypnotic home for identity return. See
`PERFORMANCE_GRAMMAR.md` for the human-readable compatibility matrix.

Every new internal parameter must have a demonstrated path through the resolved
score or renderer into PCM, measurable evidence, and a bounded influence on a
future decision. Parameters that do not reach that path are removed or connected
before the control surface expands.

The current weak-percussion path demonstrates that contract without becoming a
new instrument or mode. `PercussionGear` resolves bounded strike position,
damping, and seeded microvariation for the existing groove-pulse carrier; the
complete eight-pulse syncopated-lean state groups only those existing
intensities into one cyclic 3-3-2 accent/ghost relation. The same render produces
event-local dry-signal evidence. The primary evaluator judges that one canonical
realization; no legacy alternating candidate or permissive policy remains.

The ordinary closed-hat path uses the same contract. After ensemble arbitration,
an existing closed hat that shares its resolved onset with the existing open hat
receives one semantic companion role. The renderer shortens only that closed-hat
tail; onset, count, intensity, swing, brightness, level, and the open-hat render
remain unchanged. Same-pass event evidence binds the score event to its exact
dry-sample consequence.

The broader upper-percussion tail path also reuses existing score material.
After ensemble arbitration, every clap, open-hat, and metallic event receives
either its exact natural body or foreground-clearance semantics. Clearance is
chosen only when another role owns focus and the bar is neither an identity
return nor an intentional pileup. Rendering preserves the attack and shortens
only the existing tail; it does not add a track, source, send, or effect chain.
Same-pass event evidence and calibrated clearance/tail dimensions keep that
contextual decision attributable.

The tuned-percussive foundation path now resolves up to two bounded modal
articulations from the same bar, modal DNA, character, and existing foundation
events. One deterministic six-mode resonator renders those articulations into
the protected foundation route with four fixed continuation slots. It replaces
the former root-only foundation voice in place; there is no second percussion
engine or renderer-side pitch choice. Same-pass evidence binds score event,
requested and measured pitch, attack/body/tail relation, spectral centroid,
masking, pole stability, continuation, render-pass equality, and exact dry PCM.

The gated-percussion-texture path keeps the same ownership boundary. One
eligible existing percussion event opens a bounded score-owned input slice and
a later bounded return window; it does not create an onset, capture a reusable
loop, add cross-bar effect state, or expose a control. Same-pass protected-return
evidence binds the timing and PCM consequence. The musical gate relationship is
durable, while its current delay, filtering, feedback, gain, stereo placement,
and smoothing remain replaceable internal DSP details for future maturation.

The phrase-composition path adds four coordinated capabilities without adding a
second engine. In eligible broken or ambient major breaks, immutable trigger data resamples
an exact already-rendered percussion or kick window at bounded forward or reverse rates.
Eligible motif bars resolve a complete 8- or 16-step modal arpeggio in the score,
not from a free-running DSP clock. Atmosphere bars may render one four-voice pad
whose inversion is chosen against the last accepted voicing; that compact
harmonic state continues across phrase boundaries. One per-bar evidence record
binds those intentions to their exact slice and pad PCM, arpeggiator geometry,
and voice-leading movement. Identity-return paths remain exactly neutral.

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
Professional quality remains an unverified release goal until the shipping
policy and its operational gates pass. Professional Evidence v7 supplies
standards-based phrase loudness/true-peak evidence plus bounded physical-time spectral and trajectory
evidence, modal-foundation and live-controller consequence, explicit
analysis-memory provenance, and complete canonical-journey report-bank
validation. A non-reconstructable diverse profile, passing
adversarial suite, and disjoint holdout report now qualify complete 44.1/48 kHz
engine banks offline and install the same calibrated policy in detached runtime
preparation. One canonical plan is rendered, judged, and either committed or
rejected; the evaluator may request one same-plan home-timbre correction. Missing
artifacts and unsupported sample rates remain truthfully unavailable and cannot
commit. See `PRIMARY_EVALUATOR.md`.

The seventh completed architectural stage closes one scheduled-output
master-headroom loop. `TechnoEngine` maps app-owned main-mixer PCM to the exact
scheduled phrase occurrence; a fixed native-stereo C11 handoff copies bounded
packets; and detached work analyzes the first exact three-second window with the
same BS.1770-5 and Annex 2 implementation used by candidate evidence. The
installed profile supplies the targets. The single controller can attenuate
only `-3...0 dB`, attacks by at most `0.25 dB` per accepted phrase, and recovers
by `0.125 dB` only after two clean windows. Its pending proposal becomes durable
only when the single primary evaluator accepts fresh evidence for an
unscheduled future phrase. Late evidence alone is ignored or deferred when its
exact target is no longer unscheduled; it does not latch a repeat. Only an
already-authorized correction that is rejected, unavailable, or misses its
first eligible boundary enters the accepted-PCM hold and repeats accepted
immutable PCM. No failure can enable a substitute. See
[`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md).

## Hard constraints

- The same engine version, quality-policy version, initial state, continuation
  state, route state, and captured app-owned PCM reproduce the same decisions.
- Planning and quality-policy decisions remain outside the real-time callback.
- The callback performs no allocation, locking, analysis, logging, file or
  network I/O, or UI work.
- Live-output capture copies only app-owned PCM into a preallocated lock-free
  handoff; bounded analysis runs in background work.
- Adjustments apply only to immutable snapshots for unscheduled future audio.
- The single plan, at most one corrective pass, and analysis work remain
  explicitly bounded. Late analysis is ignored or deferred after its exact
  target is no longer unscheduled; only an already-authorized correction that
  fails its first eligible boundary can enter the accepted-PCM hold.
- Route changes rebuild at the active sample rate without silently changing the
  musical identity or corrupting adaptation state.
- Finite output, peak/DC/boundary limits, low-end compatibility, masking,
  controller stability, and preparation headroom remain release obligations.

## Product boundary

The package exposes only the `AutoTechno` executable. Core and DSP targets have
no supported external consumers or source-compatibility promise. Retired
reference engines, comparison executables, old scene APIs, render profiles, and
selectable performance models remain outside the product.
