# Live Feedback Master-Headroom Design

**Status:** Approved architecture, controller policy, data flow, and validation
design. Implementation has not started.

**Date:** 2026-08-16

## Purpose

Close Auto Techno's first scheduled-output feedback loop without creating a
second engine, evaluator, renderer, runtime mode, or user control. The app will
observe only PCM produced by its own main mixer, reduce one bounded window to
standards-based loudness and true-peak evidence off the audio callback, and
propose an attenuation-only master-headroom correction for an unscheduled
future phrase. The existing calibrated primary evaluator remains the only
terminal judge of the changed candidate.

This work completes the final item in the accepted development order after
Professional Evidence, diverse calibration, the spatial FDN, the TPT/ADAA
nonlinear core, the single-primary cutover, and modal percussion. It does not
claim that physical-output soak or professional release quality has passed.

## Automated deficit

Detached preparation currently analyzes the exact immutable PCM that it
creates, but the runtime has no evidence that samples entering AVAudioEngine's
scheduled mixer path preserve that result. `TechnoEngine` schedules prepared
buffers and advances canonical continuation without any sample-indexed
observation of the app-owned mixer output. Route rebuilding, transport timing,
or future app-owned graph changes could therefore diverge from detached
evidence without producing a bounded future correction.

The first falsifiable deficit is:

> A complete active three-second window of app-owned scheduled output exceeds
> the calibrated checkpoint envelope for short-term loudness or Annex 2 true
> peak, but the canonical runtime cannot carry that observation into a bounded
> attenuation of an unscheduled future phrase.

The implementation must demonstrate the complete path from scheduled PCM to a
versioned observation, a reason-coded proposal, changed future PCM, fresh
primary-evaluator evidence, and an atomically committed continuation. A capture
path that cannot alter future PCM is incomplete.

## Canonical ownership

### Existing owner and state extended

- `AutonomousSessionDirector` remains the sole musical planner and continues to
  produce one canonical `AutonomousPhrasePlan` per phrase boundary.
- `AutonomousSessionState` gains only the committed, reduced live-feedback
  continuation required to reproduce future decisions. It never carries PCM,
  analyzer objects, AVFoundation types, or mutable callback state.
- `RenderState` gains the committed attenuation-only master-trim state applied
  during detached rendering.
- `PreparedAutonomousPhrase` binds the proposed live-feedback input, applied
  controller state, changed PCM, candidate evidence, primary verdict, and
  outgoing continuation in one commit product.
- `TechnoEngine` remains the owner of transport, route lifecycle, scheduling,
  the scheduled-range ledger, and successor preparation invalidation.

### Reusable engine capability added

One reusable scheduled-output evidence path:

```text
app-owned main-mixer PCM
  -> fixed C11-atomic SPSC packets
  -> bounded background three-second window
  -> BS.1770-5 / Annex 2 evidence
  -> calibrated attenuation proposal
  -> Core future-boundary validation
  -> same canonical successor rendered with terminal trim
  -> single primary evaluator
  -> atomic future continuation commit
```

Future signal-domain controllers may reuse the packet and observation boundary,
but they must share one coupled controller state when they touch the same role
or parameter. This design authorizes only master-headroom attenuation.

### Duplicate or special-case mechanism avoided

- No microphone, system-audio capture, output-device acoustic measurement, or
  external source.
- No second evaluator, permissive policy, comparison candidate, musical
  substitute, or alternate renderer.
- No callback FFT, loudness calculation, true-peak FIR, hashing, logging,
  scheduling decision, or state mutation.
- No reuse of the kick/foundation automatic fader. Full-mix evidence cannot
  truthfully infer role-local balance, and the master controller must not
  compete with that fader.
- No user-facing gain, target, profile, feedback, or engine selector.
- No reusable audio loop, captured sample asset, or new compositional source.

## Realtime packet handoff

### Internal target

Add one package-internal C target, `CAutoTechnoRealtime`, linked
only by the executable-side feedback transport. It owns the preallocated PCM
slots and C11 atomic producer/consumer sequences. It is not a package product
or a supported API.

The C boundary is deliberate. The callback-facing function must have a small,
auditable object file with no Swift ARC, copy-on-write storage, async runtime,
mutex, allocator, Objective-C, Foundation, AVFoundation, file, network, or
logging dependency.

### Fixed storage and work

- Native stereo only.
- Maximum 1,024 frames per callback packet.
- 256 packet slots.
- Two planar `Float` channels per slot.
- PCM capacity: `256 * 1,024 * 2 * 4 = 2,097,152` bytes, plus fixed numeric
  metadata and atomic counters.
- One producer: the main-mixer tap.
- One consumer: the background feedback worker.

The producer receives channel pointers, frame count, first mixer sample,
route-generation integer, and committed controller revision. The engine and
policy strings are immutable coordinator configuration and are attached off the
callback; the callback does not copy or inspect strings.

For a valid packet, the producer copies each channel once, writes numeric
metadata, and publishes the slot with release ordering. The consumer acquires a
published sequence, copies or analyzes it off the callback, and releases the
slot. If the ring is full, the producer increments one atomic drop counter and
returns immediately. If the frame count exceeds 1,024, the packet is rejected
rather than split into unbounded work. Audio playback is never rejected,
blocked, retried, or shortened by feedback.

### Callback prohibition

The tap callback may only:

1. validate two non-null channel pointers and a frame count no greater than
   1,024;
2. read the callback-provided sample position;
3. call the bounded C producer; and
4. return.

It performs no allocation, retainable object construction, locking, waiting,
analysis, hashing, logging, file or network I/O, model work, UI work, musical
decision, queue dispatch, continuation update, or route mutation.

## Scheduled-range provenance

Before the first sample of a phrase can play, `TechnoEngine` registers one
immutable scheduled-range record with a bounded feedback coordinator. The
record contains:

- route generation and exact sample rate;
- scheduled start and exclusive end sample;
- phrase index and plan fingerprint;
- all applicable canonical checkpoints, using `longContinuation` for an
  ordinary lock phrase with no named checkpoint;
- quality policy and evaluator identity;
- committed live-controller revision and fingerprint;
- applied master trim; and
- the earliest sample boundary at which a successor remains unscheduled.

The ledger retains at most the playing phrase, the scheduled successor, and two
recent phrases. It is transport provenance, not a second musical timeline. A
repeated accepted phrase receives a new scheduled sample range while retaining
the same immutable plan and controller identity.

### Mixer/player sample-domain mapping

`AVAudioPlayerNode` scheduling positions and `mainMixerNode` tap timestamps are
not assumed to share a node-local origin. For each route generation, the app
establishes one immutable mixer-to-player sample offset outside the callback by
converting the same `AVAudioTime` through `player.playerTime(forNodeTime:)`.
Only mappings with matching finite rates and an exact integral sample offset
are eligible. The scheduled ledger stores both the player-domain source range
and its mapped mixer-domain range.

The callback copies only the tap's mixer-domain `sampleTime`; it never queries
the player or performs a time conversion. The background coordinator converts
that numeric range through the frozen route mapping. If the mapping is absent,
changes after playback begins, is fractional, or disagrees with a later
same-route conversion, all affected windows are unavailable and controller
state holds. No leading silence scan, PCM correlation, host-time estimate, or
wall-clock offset may substitute for the explicit AVAudioTime mapping.

Packet sample positions, not callback arrival time or worker wake time, map PCM
to this ledger. Wall-clock time may wake a background poller but never selects,
orders, accepts, or rejects evidence.

## Background window analysis

### Window selection

For each source phrase, the coordinator designates the first exact three-second
window beginning at the phrase's scheduled start sample. At 44.1 and 48 kHz
this is respectively 132,300 or 144,000 frames. The current minimum four-bar
phrase at 130 BPM is longer than seven seconds, so the window fits completely
inside every canonical phrase.

Packets may be arbitrarily chunked, but their sample ranges must be contiguous
and cover the designated window exactly. A gap, overlap, overwritten packet,
mixed route generation, controller-revision mismatch, or incomplete source
range makes the window unavailable. The coordinator never pads, interpolates,
reorders, or estimates missing PCM.

The background worker drains a fixed maximum number of packets per wake and
uses preallocated stereo working storage for one window. A window is analyzed
at most once. Additional source-phrase windows may be retained as descriptive
diagnostics later, but they cannot trigger another controller transition in
this version.

### Evidence

`AutoTechnoDSP` factors the existing ITU-R BS.1770-5 K-weighting/rolling-energy
and Annex 2 four-phase FIR logic into a bounded live-window analyzer. Detached
phrase analysis and live-window analysis must share the same coefficients and
true-peak implementation rather than fork algorithms.

The immutable live observation records:

- live-evidence schema and analyzer version;
- engine, quality-policy, evaluator, and controller-policy versions;
- route generation, sample rate, source phrase index, and plan fingerprint;
- exact inclusive start and exclusive end samples;
- source packet count, frame count, gap/drop counters, and working-memory
  bounds;
- exact stereo PCM fingerprint;
- finite state and active-window state;
- BS.1770 integrated value for the fixed window, maximum momentary loudness,
  one three-second short-term loudness value, and their block counts;
- left, right, and maximum Annex 2 true peak in linear and dBTP forms; and
- the applicable checkpoint set and deterministic observation fingerprint.

Only short-term loudness and maximum true peak drive this controller. The
window's integrated loudness is retained as evidence and replay coverage, not
treated as a phrase-integrated programme value.

## Calibrated headroom proposal

### Existing profile remains authoritative

The live controller reads the exact profile already installed for the primary
evaluator. It does not load another profile or invent a descriptive threshold.
For every checkpoint represented by the source phrase, it obtains the upper
bounds for:

- `maximum-short-term-loudness-lufs`; and
- `true-peak-dbtp`.

If a phrase represents several checkpoints, the minimum applicable upper bound
is used for each metric because the terminal primary evaluator requires every
represented checkpoint to pass. Ordinary lock phrases use the calibrated
`longContinuation` envelope.

A window is active only when the BS.1770 absolute gate admits programme energy
and all required measurements are finite and complete. Silence and incomplete
measurements cannot trigger either attenuation or recovery.

### Controller transition

Let:

```text
excess = max(
  liveShortTermLUFS - calibratedShortTermUpperLUFS,
  liveTruePeakDBTP - calibratedTruePeakUpperDBTP,
  0
)
```

The committed controller range is `-3...0 dB` and never boosts above the
authored home level.

- If `excess > 0`, the desired trim is the current trim minus `excess`, clamped
  to `-3...0 dB`. One accepted phrase may move at most `0.25 dB` toward that
  target.
- For each metric, the checkpoint that supplied the strictest applicable upper
  bound also supplies its lower bound; the midpoint of that exact pair forms
  the recovery edge. Between midpoint and upper bound, the controller holds.
- Two consecutive complete active observations at or below both midpoints
  permit one `0.125 dB` recovery step toward 0 dB.
- An alternating high/low sequence cannot change direction without satisfying
  the two-window recovery condition.
- Continued excess at `-3 dB` records saturation and holds. Saturation does not
  authorize another parameter, a larger range, a boost elsewhere, a second
  evaluator, or a fallback render.

The fixed slew and range are controller-stability bounds. Their qualification
suite must prove convergence, no drift, and no limit cycle; passing tests, not
their presence in this document, authorizes the shipping policy.

### Reduced Core proposal

DSP reduces the signal evidence to a Core-owned proposal containing only:

- live-feedback schema and controller-policy version;
- source phrase, plan fingerprint, route generation, and exact sample range;
- observation fingerprint;
- prior controller revision and fingerprint;
- proposed trim, clean-window count, outcome, and reason codes;
- earliest eligible future sample; and
- proposal fingerprint.

Core validates canonical ordering, finite bounded trim, monotonic revisions,
one transition per source phrase, route identity, exact source range, and a
strictly future eligibility boundary. Core does not recompute loudness,
true-peak, profile envelopes, or DSP policy.

## Pending versus committed state

An accepted live observation does not directly mutate `AutonomousSessionState`
or `RenderState`. It creates one pending preparation input. This distinction is
required because asynchronous evidence has not yet been judged with the future
candidate it changes.

The phrase-preparation request and cache key bind:

- committed live-feedback revision and fingerprint;
- pending proposal fingerprint, if any;
- route generation and eligible future sample; and
- incoming render/quality continuation fingerprints.

The preparer validates the proposal, applies its trim to a copy of the incoming
render state, renders the same canonical plan, and produces fresh complete
candidate evidence. Rejected or cancelled work cannot mutate the committed
state. The pending proposal becomes committed only when the prepared phrase,
applied controller state, changed PCM, primary decision, and outgoing
continuation pass the existing atomic commit boundary.

If the corrected candidate is rejected, no uncorrected substitute is rendered
inside that transaction. Transport repeats already accepted immutable PCM. A
later source observation may propose another bounded transition from the last
committed controller state.

## DSP application and truthful evidence

`RenderState` carries the committed master trim and recovery state. The trim is
applied after the existing nonlinear output-safety function and after protected
foundation/remainder recombination. Because it is attenuation-only, it cannot
increase a sample or invalidate the existing terminal safety bound. It does not
change internal dynamics detectors, ducking, role stems, masking attribution,
or the kick/foundation fader.

Every rendered block and candidate vector records:

- requested and applied trim;
- incoming and outgoing live-controller revisions/fingerprints;
- pending proposal fingerprint and source observation fingerprint;
- eligible future boundary and route generation;
- pre-trim and post-trim exact PCM fingerprints;
- proof that post-trim samples equal the finite bounded gain of the terminal
  pre-trim samples; and
- home-state neutrality proving 0 dB remains bit-identical to the pre-feature
  canonical output.

The controller state joins the existing combined controller fingerprint. Cache
keys, route recovery, prepared commit provenance, and deterministic continuation
must all distinguish any trim or feedback revision capable of changing PCM.

## Scheduling and future-boundary application

At most one feedback-driven successor invalidation and regeneration is allowed
per source phrase.

When a complete proposal arrives, `TechnoEngine` checks the sample ledger:

- If the target phrase has no scheduled samples and preparation headroom
  remains, it cancels only the stale unscheduled preparation/cache entry and
  prepares the same canonical successor with the pending proposal.
- If any target sample is already queued, the proposal cannot target that
  phrase. A still-current observation may name the following unscheduled phrase
  only when its declared eligibility and maximum-age rules allow it.
- If the observation is late, stale, mismatched, or preparation misses the
  boundary, the current accepted phrase repeats with frozen topology and
  controller state. Playback does not wait for feedback.

An observation expires after the first complete successor boundary for which it
was eligible. It is never silently rolled across multiple phrases. This keeps
latency and causal responsibility bounded.

## Route and lifecycle behavior

### Route recovery

On `AVAudioEngineConfigurationChange`, the engine:

1. stops scheduling and removes the old mixer tap while the engine is stopped;
2. cancels the old background worker;
3. discards all unpublished/partial packets and pending proposals;
4. increments the route generation;
5. rebuilds the accepted phrase at the new exact sample rate using only the
   committed controller state;
6. creates a fresh preallocated handoff and worker; and
7. installs a new tap before resumed playback.

Packets, windows, or proposals from the prior route generation are permanently
ineligible. Route recovery does not reset accepted attenuation or musical
identity. Unsupported sample rates remain truthfully unavailable under the
primary artifact contract.

### Pause, resume, and shutdown

- Pause retains committed controller state. Any partial window is discarded;
  resume begins a fresh designated range without treating the pause duration as
  audio evidence.
- Shutdown removes the tap before releasing handoff storage, cancels the
  worker, clears pending evidence, and resets the complete autonomous session
  through the existing lifecycle boundary.
- Repeated notification, cancellation, device loss, sleep/wake, and stale task
  completion must be idempotent and must not access freed packet memory.

## Failure policy

The following conditions hold the last committed controller state and cannot
block or change playing audio:

- ring full or producer packet rejected;
- partial, missing, overlapping, reordered, or overwritten packet sequence;
- mixed phrase, route, sample-rate, policy, plan, or controller identity;
- empty, silent, non-finite, or incomplete analysis;
- unsupported primary artifact/rate;
- stale or non-future target boundary;
- more than one proposal for a source phrase;
- successor already partly scheduled;
- preparation cancellation or missed deadline;
- primary evaluator rejection or unavailable verdict; and
- controller saturation.

Every rejection is reason-coded off the callback. Callback drops are counted in
fixed atomic integers and summarized only by the background worker.

## Deterministic replay

An offline replay fixture contains no microphone or device recording. It
provides:

- the exact numeric packet sequence and sample ranges;
- scheduled-range ledger;
- route, engine, policy, evaluator, and controller identities;
- committed session/render/quality continuation;
- primary profile fingerprint; and
- target canonical plan.

Replaying identical inputs must reproduce the same window PCM fingerprint,
measurements, observation/proposal fingerprints, controller transition,
candidate PCM, primary verdict, and outgoing continuation. Packet chunking may
vary while representing the same contiguous samples; evidence and decisions
must remain identical.

## Version and artifact cutover

The implementation is an exact-contract cutover, not a compatibility layer.
It advances at least:

- canonical engine v20 -> v21;
- quality-contract schema 21 -> 22;
- candidate-vector schema 19 -> 20;
- candidate-transaction schema 3 -> 4;
- Professional Evidence v5 -> v6;
- professional observation/profile v2 -> v3;
- calibrated primary policy/evaluator v2 -> v3;
- adversarial report schema 3 -> 4;
- holdout qualification schema 1 -> 2;
- live packet, observation, proposal, and controller policy v1.

Only the new v3 profile, adversarial report, and holdout resources ship. Old
resource filenames, decoders, compatibility branches, legacy schema acceptance,
and unused target code are removed when the exact new artifacts qualify. No old
live-feedback mechanism exists to preserve.

The development corpus remains the same 28 complete private canonical journeys
at 44.1 and 48 kHz, and the same four disjoint holdout journeys remain disjoint.
If the schema cannot project every new field for every existing checkpoint, the
implementation stops as unavailable rather than silently changing corpus
membership. All artifacts are regenerated because engine, evidence, controller,
and commit provenance identities change, even if the home-state PCM is
bit-identical.

## Test-first validation

Every production behavior begins with a focused failing test and an observed
expected failure.

### Realtime handoff

- exact packet order, metadata, wraparound, and release/acquire visibility;
- full-capacity drop without producer wait or consumer corruption;
- rejected oversized/malformed packets without partial publication;
- concurrent producer/consumer stress with deterministic accounting;
- repeated construction/teardown and route-generation replacement;
- sustained optimized callback simulation at 64, 128, 256, 512, and 1,024
  frames; and
- object-symbol inspection proving the callback C object has no unresolved
  allocator, mutex, logging, file, network, Objective-C, or Swift-runtime
  references.

### Analyzer and replay

- exact 997 Hz BS.1770 reference behavior and Annex 2 inter-sample peak;
- 44.1/48 kHz physical-time equivalence;
- identical result for different packet chunking;
- exact first-three-second phrase window selection;
- exact AVAudioTime mixer/player sample-domain mapping and rejection of absent,
  fractional, drifting, or cross-route mappings;
- silence, non-finite data, gaps, overlaps, discontinuity, cancellation, and
  bounded working-memory accounting; and
- complete offline packet-to-outgoing-continuation replay.

### Controller stability

- attack from both home and partially attenuated states;
- no boost, `-3...0 dB` clamp, `0.25 dB` attack slew, and `0.125 dB` recovery
  slew;
- deadband hold and two-window recovery hysteresis;
- alternating high/low evidence without chatter or limit cycle;
- convergence without drift after entering the accepted envelope;
- silent, sparse, invalid, stale, late, route-mismatched, and saturated cases;
- one transition and one regeneration maximum per source phrase; and
- no mutation of kick/foundation automatic-mix state.

### Canonical preparation and scheduling

- 0 dB home state is bit-identical to the exact v20-base render before version
  advancement;
- nonzero trim changes intended full-mix PCM and leaves score, role stems,
  internal dynamics, and protected routing unchanged;
- fingerprints change for every controller/proposal/boundary field;
- pending state cannot leak from cancelled, rejected, or unavailable work;
- playing and already queued buffers remain immutable;
- prepared cache keys distinguish committed and pending feedback state;
- missed successor repeats accepted PCM without silence or premature state
  advance; and
- route recovery retains committed state while rejecting all stale packets and
  proposals.

### Primary qualification

- the primary evaluator remains the only terminal verdict;
- every v6 report includes live-controller home/proposal provenance;
- development profile covers every checkpoint at 44.1 and 48 kHz;
- adversarial attacks reject forged source range, forged trim, stale route,
  packet-gap concealment, short-term-loudness compensation, true-peak
  compensation, controller drift, and saturation gaming;
- disjoint holdout passes every local, rate, trajectory, and controller
  relationship gate; and
- old resource/schema identities fail to load.

### Completion gates

Report separately:

1. implementation complete;
2. structural, deterministic, realtime-safety, and signal validation passed;
3. regenerated automated primary qualification passed;
4. exact release app transport/route verification passed;
5. exact-head remote CI passed; and
6. physical-output and recovery soak passed.

An app launch or green unit test does not imply the physical-output soak. A
normal calibrated run may remain at the neutral 0 dB home state; adversarial
fixtures must prove the audible correction path even when the shipped journey
does not require attenuation during a short listening session.

## Documentation changes

The implementation updates and cross-links:

- `README.md`;
- `docs/PRODUCT.md`;
- `docs/SOUND_QUALITY.md`;
- `docs/AUTONOMOUS_RUNTIME_PROVENANCE.md`;
- `docs/AUTONOMOUS_RUNTIME_VALIDATION.md`;
- `docs/PRIMARY_EVALUATOR.md`;
- `docs/ROADMAP.md`;
- `docs/SOUND_CONCEPT_MATURITY.md`; and
- `docs/history/VALIDATION_SNAPSHOTS.md` only after exact validation exists.

Normative documents must stop saying hybrid live feedback is unimplemented once
the exact implementation and automated gates pass. They must continue to state
physical-output soak truthfully until it is performed.

## Out of scope

- upward normalization or loudness boosting;
- compressor, limiter, kick, foundation, EQ, stereo, spatial, or timbral
  feedback control;
- feedback-driven musical density, orchestration, role, note, or graph changes;
- microphone, ambient, system-output, or third-party audio analysis;
- user-facing controls or technical diagnostics beyond existing read-only UI;
- storing live PCM on disk or in continuation;
- more than one controller transition or successor regeneration per source
  phrase; and
- claiming physical device behavior from offline or virtual-route tests.
