# Auto Techno Product Contract

## Purpose

Auto Techno is a standalone desktop instrument for starting and sustaining one
coherent techno performance with one primary transport button. One secondary
New Set action declares a complete-performance boundary on the promoted app
surface. One compact monitoring mute and volume control changes only local
device output after canonical capture; it is not a musical or mix parameter.
macOS remains promoted; the native Windows x64 host is a buildable
release candidate until its feature-parity, app/runtime, and physical-output
gates pass. It is not a DAW, sequencer editor, plug-in host, preset browser,
engine selector, or collection of render experiments.

## Central invariant

Every autonomous decision expresses a musical intention. Its destination,
transition, and consequence in the continuing performance must remain coherent.
Long-form continuation develops causal four-to-eight-minute material worlds;
it does not simulate evolution by permuting a small fixed set of phrase roles.
Each child world preserves the performance root while making several audible,
score-bound structural and effect changes.
Pitch-bearing and indefinite-pitch consequences follow the explicit
[`PITCH_IDENTITY_CONTRACT.md`](PITCH_IDENTITY_CONTRACT.md); an out-of-mode note
must never be presented as atonal texture.

Play asks the instrument to continue its one performance. Pause and resume
preserve position, identity, and adaptation state. Technical evidence may be
shown read-only, but no compositional, synthesis, mixing, mastering, or quality
parameter belongs in the primary UI.
Monitoring attenuation is the sole exception because it changes only what the
listener hears from this process. It never changes rendered PCM, evidence,
qualification, continuation, adaptation, or performance identity.

A newly constructed complete performance receives one fresh opaque App-owned
root seed before planning begins. That seed remains fixed across preparation,
play, pause, resume, live correction, route recovery, and continuation so the
set develops coherently. A completed session boundary selects a new seed for
the next performance. The seed is neither displayed nor selectable; supplying
the same explicit seed in qualification still reproduces the same score and
PCM exactly.

New Set is the only user-requested identity boundary. It stops the current
player and engine, quiesces and destroys live-feedback ownership, cancels and
invalidates detached preparation, clears every cache and musical/quality/live/
long-horizon continuation, rotates the private root, resets read-only
presentation, and prepares a new performance. The new set begins automatically
when its first immutable phrase is ready. Pause and resume never take this path.

## Shipped experience

- one accessible primary play/pause transport button;
- one accessible secondary New Set action, available outside preparation;
- one accessible monitoring-only mute and volume control, defaulting to full
  output and remaining outside every musical and quality decision;
- explicit preparing, ready, live, paused, recovering, and unavailable states;
- fixed 130 BPM;
- one fresh private canonical identity per complete, indefinitely evolving
  performance;
- phrase and bar position plus lightweight read-only visualization;
- one optional read-only Render Info view for the current immutable bar's
  resolved score, synth assignments, semantic automation, graph, effects, mix,
  and already-computed render evidence, plus the next phrase's detached
  preparation state, attempt count, coherent-repeat count, and qualified-cache
  readiness; a failed attempt adds one concise stage/code, retryable calibrated
  rejection enters finite deterministic recovery waves without permanently
  blocking playback, and bounded exact guard or calibrated metric-value/bounds
  details remain in the local unified log. Missing policy, invalid provenance,
  route failure, and signal-safety failure still fail closed. Recovery never
  pauses playback or starts a new set; those remain explicit user actions;
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
engine-owned synthesis architectures and eleven score-selected home patches. The
same four bounded semantic automation coordinates move every patch, while the
existing ensemble score continues to own audible role density. See
`INSTRUMENT_PALETTE.md` for the human-readable role and effect matrix.
`SYNTH_TRACK_RENDERING_MATRIX.md` consolidates those assignments with the
track-equivalent voices, DSP topology, effect routing, numeric homes, and
change boundaries in one descriptive implementation map.

The phrase-scale performance grammar coordinates that palette instead of
randomizing layers independently. Six internal characters bind compatible
foundation behavior, kick grammar, role-compatible patches, and automation
while the session DNA and narrative-owned role admission remain stable.
Character selection retains the last two
committed choices, applies only at a future phrase boundary, and returns to the
hypnotic home for identity return. See
`PERFORMANCE_GRAMMAR.md` for the human-readable compatibility matrix.

Phrase-local sample transformation remains part of that same grammar. Ambient
Drift may resolve the existing slice owner as deterministic `granular-memory`:
overlapping bounded micrograins reinterpret only the current bar's already-
rendered kick or percussion window. Broken Suspension retains the exact whole-
window `cut` path. The score owns texture and seed; detached DSP owns rate-
scaled geometry and causal evidence. No recording, retained source PCM,
alternative sampler, preset choice, or callback work is introduced.

Long-horizon effect evidence follows the same product boundary. A future phrase
may annotate at most one effect sentence that is already present in its resolved
score: either a gated percussion call/answer or an anticipation turnaround.
Detached DSP reduction measures current graph, echo, percussion-return, FDN,
effect-access, and masking consequence as bounded hashes and scalars. It adds no
control, mode, event, send, bus, chain, graph node, or PCM retention, and it does
not yet qualify hours-long entertainment.

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

That same articulation now gives the already-arbitrated clap event a bounded
contextual body. Hypnotic and identity material keeps the established
three-burst clap; peak-drive material uses a pitched membrane plus filtered
wire-noise snare; broken or ambient suspension uses a short damped rim. Hats and
metallic events remain native. The body is part of the resolved score, typed
identity, exact PCM evidence, and primary transaction. It adds no event type,
track, sequencer, preset, user control, or realtime state.

The existing kick source similarly receives score-owned long-horizon material
rather than a second kick or preset bank. The current episode and presentation
clock move one recognizable source among balanced, relaxed, ghost-soft, and
rare resonant-accent states. Maintain, rise, and recall hold balanced; reframe
morphs to and holds relaxed; payoff morphs to a resonant body accent; recovery
morphs to relaxed for 32 bars, holds that midpoint for 32 bars, then morphs to
and holds ghost-soft. Each handoff uses a 32-bar raised cosine. The complete
body + sub + click sum receives the score-owned presence scale before source
dynamics, detector, ducking, and audible routing, while balanced retains the
prior source PCM exactly. Accepted-PCM repeats age presentation progress without
fabricating score evidence, and the protected kick route stays canonical.

Bounded percussion windows end through one shared source-local terminal
contract rather than a master de-clicker. Kick and rumble use 4 ms releases;
clap, open hat, and metallic percussion use 2 ms. The first 8 ms—including the
kick's intentional click—is bit-preserved, while the final source frame is
exact zero before silence. Event-local evidence proves score binding, protected
attack identity, changed release PCM, and terminal continuity at both production
rates. This detached, state-free repair adds no user control, score choice,
continuation, output smoothing, or realtime callback work.

The protagonist spectral-reveal path follows the same reuse-or-expand rule.
When an existing anchor is already narratively emerging in a lock or contrast
phrase, the score may veil and disclose that exact Resonant Mono or Tonal
Motion voice through its existing filter. It changes no note, role, patch,
effect access, send, density, transport, or random draw, and exact home
correction returns to the previous cutoff path. A new lead track, synth, or
filter bus would duplicate the protagonist rather than strengthen its arrival.
Independent score/render identities, actual cutoff facts, and isolated-anchor
PCM evidence keep the relation attributable and replaceable.

The response-owned harmonic-tail path adds one recognizable home only because
the three established Spectral Texture patches do not generate a low periodic
source and isolate its dense upper partials. Broken Suspension selects Voltage
Arc for an existing response role; the existing Spectral Texture state,
envelope, filtered-reverb send, routing, and evidence transaction remain the
owners. The new patch therefore adds a reusable audible capability without a
track, architecture, effect return, renderer, or user-facing choice.

The tuned-percussive foundation path now resolves up to two bounded modal
articulations from the same bar, modal DNA, character, and existing foundation
events. One deterministic six-mode resonator renders those articulations into
the protected foundation route with four fixed continuation slots. It replaces
the former root-only foundation voice in place; there is no second percussion
engine or renderer-side pitch choice. Same-pass evidence binds score event,
requested and measured pitch, attack/body/tail relation, spectral centroid,
masking, pole stability, continuation, render-pass equality, and exact dry PCM.

Eligible Lock pairs may also reinterpret only their existing bass onsets as one
bounded dotted three-sixteenth relationship across two bars. The established
protected foundation route, Bass Pluck patch, dry center placement, kick clock,
and score swing remain authoritative. This is a resolved-score relationship,
not a second bass track, independent sequencer, spatial return, or user mode.

When the dotted score places an existing Bass Pluck one sixteenth before an
already-owned kick, the same resolved relationship now shortens only that event
with a bounded terminal release and leaves an exact dry-foundation pocket before
the kick. The score owns the event, release geometry, and kick boundary; no
sidechain detector, global filter, extra bus, track, controller, or callback
decision is introduced.

The percussion-return path keeps the same ownership boundary. One eligible
existing percussion event opens a bounded score-owned input slice. A contrast
bar admits its filtered tail inside a later gate; the final withheld bar before
an already-owned kick recovery may instead reverse that same wet tail into a
deterministic crescendo that reaches exact zero at the release boundary. It
does not create an onset, capture a reusable loop, add cross-bar effect state,
or expose a control. Same-pass protected-return evidence binds the semantic
relation, timing, PCM, and early-to-late energy consequence. The musical
answer-or-anticipation relationship is durable, while its current delay,
filtering, feedback, reversal, gain, stereo placement, and smoothing remain
replaceable internal DSP details for future maturation.

The phrase-composition path adds four coordinated capabilities without adding a
second engine. In eligible broken or ambient major breaks, immutable trigger
data resamples an exact already-rendered percussion or kick window at bounded
forward or reverse rates. The current renderer uses one fixed-radius
Hann-windowed sinc lookup: unity-rate integer positions remain exact, while
faster playback applies a deterministic anti-alias cutoff before rate
conversion. The score, source window, rate, direction, gain, edge fade, and
neutral fallback remain unchanged; no granular side engine or imported sample
path exists.
Eligible motif bars resolve a complete 8- or 16-step modal arpeggio in the score,
not from a free-running DSP clock. Atmosphere bars may render one four-voice pad
whose inversion is chosen against the last accepted voicing; that compact
harmonic state continues across phrase boundaries. The same pad now owns a
phrase-local disclosure stage: Lock conceals the progression behind tonic,
previews tonic/modal colour in its second half, and Major Break reveals the
existing four-function vocabulary before a later Lock contracts again. Its
dependent arpeggiator remains on the same onsets while following the disclosed
chord. One per-bar evidence record binds those intentions to their exact slice
and pad PCM, arpeggiator geometry and rendered pitch fingerprint, disclosure
stage/function, and voice-leading movement. In the latter half of an eligible
major break, that same pad may reuse its existing low-pass and spatial send under
one score-owned three-sixteenth modulation relation, including a click-safe
amplitude pattern that leaves underlying continuation advancing; it adds no
note, instrument, sequencer, or effect bus. Identity-return paths remain exactly
neutral.

The continuing session now projects one bound episode-energy target into these
same score owners before each future phrase is authored. Foundation authority,
role density, percussion activity, protagonist presence, harmonic disclosure,
timbral motion, spatial distance, and transition expectation remain separate
relationships rather than one intensity slider. The projection selects only
existing compatible characters, foundation behaviors, roles, percussion gears,
transformations, harmonic functions, spatial carriers, and transition
eligibility. Invalid context and protected payoff/recall reserve use the exact
all-hold path. This is internal autonomous behavior: it adds no duration,
energy, style, synth, preset, or effect control to the transport-only UI.

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
Long-form continuation follows the same rule. Canonical session memory now owns
one bounded, versioned renewable arc/episode context that observes accepted
plans; it is not a new user mode, playlist, or engine. The one existing director
now consumes it only for an unscheduled future phrase and records whether the
choice fulfilled an operator, respected a minimum hold, protected a rare event,
established payoff debt, or used the conservative fallback. The same future
plan records how the exact episode vector was projected through existing score
owners, with protected rare events and invalid context held neutral. A
completely new performance root starts it from an empty hierarchy, while pause,
resume, and ordinary continuation preserve the accepted identity and
obligations.

Long-horizon Phase 7 now closes the first bounded future-adaptation path. During
detached preparation, the accepted prepared successor contributes reduced
semantic, signal, operator, and effect evidence at the active route rate. Only a
complete observation can produce an exact reason-coded preserve/recover
decision, and recover can affect only an eligible unscheduled successor through
the one existing director and major-break vocabulary. The App commits that
decision with the musical, quality, and live continuation as one immutable
transaction. Missing, late, stale, short, malformed, wrong-root, wrong-rate, or
recovery-ineligible evidence preserves the accepted episode. Route recovery
rolls observation state back to the interrupted phrase's incoming boundary so
it cannot count or spend the same event twice. This adds no user control,
alternate engine, renderer, graph, audio buffer, microphone input, or callback
analysis.

Long-horizon Phase 8 applies the evidence gate before sound expansion. The
AudioReakt study crossed that gate only for a fixed session-long kick source and
a fixed clap body, with repeated caption evidence plus direct deterministic
probes. Other requested styles and techniques reconcile to current owners and
remain insufficient permission to add another synth, patch, effect, or chain.
Future sound maturation must still replace only a repeatedly failed provisional
DSP in place after independent-root, two-rate causal evidence.

Professional quality remains an unverified release goal until the shipping
policy and its operational gates pass. Professional Evidence v24 supplies
standards-based phrase loudness/true-peak evidence plus bounded physical-time spectral and trajectory
evidence, modal-foundation, pre-kick foundation-pocket, terminal climax-hang,
material-world/effect-target lineage, and live-controller consequence, explicit
analysis-memory provenance, and complete canonical-journey report-bank
validation. A non-reconstructable diverse profile, passing
adversarial suite, and disjoint holdout report now qualify complete 44.1/48 kHz
engine banks offline and install the same calibrated policy in detached runtime
preparation. One canonical plan is rendered, judged, and either committed or
rejected; the evaluator may request one same-plan home-timbre correction. Missing
artifacts and unsupported sample rates remain truthfully unavailable and cannot
commit. See `PRIMARY_EVALUATOR.md`.

The seventh completed architectural stage closes one scheduled-output
master-headroom loop. `TechnoEngine` maps app-owned canonical-capture-mixer PCM to the exact
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
immutable PCM. The next matching boundary releases a preserve-course successor
under the committed controller state while later correction results remain
quarantined; that successor must still pass primary qualification before it can
advance the canonical score. No failure can enable an unevaluated substitute. See
[`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md).

The canonical-capture mixer is upstream of the main output mixer. Live feedback
and its clock map observe the former; the user-facing monitoring mute/volume
changes only the latter's output gain on the main actor. Monitoring state is not
scheduled, hashed, persisted into a set, or admitted to a controller, and it
survives New Set only as a host-local listening preference.

Prolonged ordinary successor preparation has one versioned, bounded presentation
fallback: `autotechno-repeat-hold-evolution.v4`. The first coherent repeat stays
bit-exact. From the second repeat, Core rotates a fixed sentence of five
independently qualified DJ-deck chains. Every chain intersects a bold whole-mix
control-rate-smoothed low-pass gesture with a grid-locked memory on a different source: a one-bar
whole-mix carousel, a half-bar protected-rhythm switchback, a quarter-bar melodic
ratchet, a percussion cascade from one eighth through one sixteenth to one
thirty-second, and a kick punch-cut alternating one sixteenth and one
thirty-second. The filter therefore moves the kick with the complete deck while
the loop can simultaneously work on a narrower source. Kick and upper-percussion
taps exist only during detached rendering and never enter canonical blocks or
the scheduler.

Every family starts and ends at exact dry phrase samples, uses an at-most `0.98`
loop blend with an `8 ms`-bounded smooth crossfade, passes the existing finite,
true-peak, DC, low-stereo, and boundary limits, and cannot raise phrase RMS by
more than `0.25 dB`. Each chain proves a real whole-mix high-band reduction, a
complete bounded capture, the exact scheduled replay count, dry loop boundaries,
the shortest intended grid slice, exact source reuse, and full-mix pre-climax
routing. Failure removes only that family from the rotation; if none qualify,
transport keeps the exact accepted PCM. The variants never change primary
candidate selection, score or DSP continuation, do not participate in canonical
live-feedback attribution, and yield to a qualified successor at the next phrase
boundary. All filtering, capture, target intersection, and qualification are
phrase-scoped detached preparation; they add no callback work, user control,
second clock, or alternate engine.

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
  fails its first eligible boundary can enter the accepted-PCM hold. That hold
  cannot suppress canonical successor preparation indefinitely: the next
  matching boundary releases preserve-course preparation and blocks correction
  re-entry until score advance.
- Route changes rebuild at the active sample rate without silently changing the
  musical identity or corrupting adaptation state.
- Finite output, peak/DC/boundary limits, low-end compatibility, masking,
  controller stability, and preparation headroom remain release obligations.

## Product boundary

The package exposes only the host-selected `AutoTechno` executable. macOS and
Windows hosts share the same package-internal preparation, core, and DSP targets;
they are presentation/output adapters around one score and renderer, not separate
products. The Windows candidate is not promoted until it also proves the current
session-boundary, read-only inspection, scheduled-output feedback, route, and soak
contracts rather than silently defining a reduced second runtime. Core, DSP, and
transport targets have no supported external consumers or source-compatibility
promise. Retired reference engines, comparison executables, old scene APIs,
render profiles, and selectable performance models remain outside the product.
