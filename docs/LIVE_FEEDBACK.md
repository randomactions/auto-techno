# Canonical Live Feedback

Current engine v38 binds pitch identity, retained transition tails, and the
existing live-feedback path into one exact qualified artifact set.

## Status

Live master-headroom feedback is the seventh completed architectural stage of
Auto Techno's one generate-render-evaluate-adapt loop. It observes only PCM
owned by the app, proposes one bounded attenuation-only change for an
unscheduled future phrase, and commits that change only when the one calibrated
primary evaluator accepts the resulting canonical candidate.

This is an implementation and automated-qualification statement for canonical
engine `autotechno-canonical-engine.v38`, quality-contract schema 39,
candidate-vector schema 35, candidate-transaction schema 6, Professional
Evidence v20, professional profile v19, primary policy/evaluator v19, and live
controller policy v2. It is not evidence that a physical device, route change,
interruption, listening session, or 60-minute output soak passed.

## Ownership

- `AutonomousSessionDirector` remains the sole owner of musical identity,
  canonical plan, temporal memory, and future phrase decisions.
- `AutonomousSessionState` and `RenderState` retain only the committed,
  deterministic live-master continuation and terminal trim. They never retain
  callback buffers, analyzer objects, or AVFoundation state.
- `AutonomousPhrasePreparer` renders one canonical plan, carries an optional
  pending proposal through fresh complete evidence, and exposes a commit product
  only after the primary evaluator reaches its terminal verdict.
- `AutonomousPhraseRenderer` applies the committed attenuation exactly once,
  after output safety and protected-route recombination. It does not change role
  stems, ducking detectors, internal dynamics, or the kick/foundation fader.
- `TechnoEngine` owns transport, route generation, scheduled occurrences,
  mixer/player clock mapping, feedback lifecycle, future-preparation
  invalidation, and the accepted PCM hold.
- `LiveFeedbackRuntimeCoordinator` is the one transport coordinator.
  `LiveMasterHeadroomController` is the one full-mix feedback controller, and
  `ProfessionalQualityPrimaryEvaluator` is the only terminal quality judge.

There is no independent feedback acceptance path, additional renderer, musical
substitute, upward-normalization path, or user-facing quality control.

## Realtime callback boundary

The callback-facing `CAutoTechnoRealtime` handoff is one native-stereo C11
single-producer/single-consumer queue with 256 slots and at most 1,024 frames
per packet. Its planar PCM capacity is 2,097,152 bytes, plus fixed metadata and
atomic counters. The queue, packet scratch, and worker window storage are
allocated before the producer is enabled.

The main-mixer tap may only validate two channel pointers and the bounded frame
count, read the callback-provided mixer sample position, call the C producer,
and return. It may not allocate, retain a Swift object, lock, wait, dispatch a
task, analyze, hash, log, perform file or network I/O, access a microphone,
invoke UI code, or mutate musical, evaluator, controller, route, or scheduling
state. Invalid tap input returns before the C producer is called. A full C queue
increments its drop counter, while malformed input presented to the C producer
increments its reject counter. Each path returns immediately and playback
continues unchanged.

The detached serial consumer uses preallocated packet scratch and retains at
most one active PCM window. It performs all assembly, BS.1770 analysis,
fingerprinting, profile lookup, and proposal work off both the callback and the
main actor.

## Scheduled provenance and clock-map availability

Before a phrase can play, the app registers an immutable scheduled occurrence.
The bounded ledger retains the playing occurrence, its scheduled successor, and
two recent occurrences. Each record binds the route generation, exact sample
rate, player and mapped mixer sample ranges, phrase and plan identity,
applicable canonical checkpoints, quality-policy/evaluator identity, combined
controller identity and applied trim, earliest eligible future sample, and an
occurrence epoch.

Mixer and player sample origins are never assumed equal. Before the queue,
worker, or tap becomes active, two off-callback `AVAudioTime` conversions must
produce an exact integral mixer-to-player offset at one matching finite rate.
An absent, fractional, rate-mismatched, or drifting map makes the window
unavailable. No wall clock, silence search, waveform correlation, or estimated
offset substitutes for this mapping.

The occurrence epoch authenticates every scheduled occurrence and worker
result when a player sample timeline restarts. Pausing, resuming, recreating the
coordinator, changing routes, or shutting down rotates the applicable lifecycle
identity, so queued work from an earlier lifecycle cannot recreate preparation
or release a hold.

## Evidence window and calibrated target

For each eligible source occurrence, the worker assembles the first exact three-second window
beginning at the scheduled phrase start: 132,300 frames at
44.1 kHz or 144,000 frames at 48 kHz. Packet ranges must cover it contiguously
and exactly. A gap, overlap, sequence discontinuity, counter change, route or
controller mismatch, non-finite sample, incomplete onset coverage, or ledger
eviction makes the window unavailable; the worker never pads, interpolates,
reorders, or estimates samples.

The window reuses the canonical ITU-R BS.1770-5 K-weighting and gating code and
the Annex 2 four-phase FIR true-peak implementation. Evidence binds exact PCM,
source occurrence, sample range, route, engine, Professional Evidence v20,
policy/evaluator/controller versions, frame and packet counts, drop/reject
counters, analysis memory, integrated/momentary/short-term loudness, true peak,
and applicable checkpoints. Only maximum short-term loudness and maximum true
peak drive the controller; integrated loudness remains descriptive for the
fixed window.

The controller reads those two bounds from the exact installed profile v19.
When several checkpoints apply, each metric uses the strictest applicable upper
bound and the lower bound paired with that same checkpoint. An ordinary lock
phrase uses the calibrated `longContinuation` envelope. Unsupported rates,
missing artifacts, silence, inactive gating, or incomplete evidence produce a
reason-coded state hold.

## Attenuation and recovery bounds

Committed master trim is constrained to -3...0 dB and can never boost above the
authored home level.

- An observation above either calibrated upper bound requests at most a
  0.25 dB attenuation step for one accepted phrase.
- Values between the selected midpoint and upper bound hold the current trim.
- Two consecutive complete active observations at or below both selected
  midpoints permit one 0.125 dB recovery step toward 0 dB.
- Excess at -3 dB records saturation and holds. It does not authorize another
  parameter, a wider range, another policy, or a compensating boost.
- Missing, stale, invalid, late, silent, unsupported, or mismatched evidence
  leaves the committed revision, trim, and recovery count unchanged.

The headroom controller and the existing kick/foundation controller share one
combined controller fingerprint. They do not select between competing control
paths, and the full-mix controller never infers or modifies role-local balance.

## Pending, committed, and future-boundary state

A complete observation produces a reduced Core proposal, not a state mutation.
The proposal binds its source occurrence, observation, installed profile,
incoming live revision, proposed trim/recovery state, reason codes, and earliest
eligible future sample. It is pending until detached preparation renders the
same canonical successor with that proposal, recomputes complete candidate
evidence from the changed PCM, and the primary evaluator accepts that exact
candidate and controller fingerprint.

Only that atomic commit advances musical, render, quality, and live-master
continuation together. Cancelled, rejected, unavailable, tampered, or stale work
cannot leak controller state. The initial and optional same-plan home-timbre
correction attempts must carry the same proposal identity.

At most one feedback-driven invalidation per authenticated scheduled occurrence
is permitted. The complete `ScheduledPhraseRange`—including route, occurrence
epoch, mapped sample ranges, plan, policy, controller, and boundary—is the key;
repeating the same phrase at a newer authenticated occurrence can therefore
earn its own one transition when preserve-course recovery does not already own
that source-to-target relationship. An authorized transition can cancel only an
unscheduled corrected-successor preparation or cache entry. A previously
primary-qualified preserve-course successor may remain cached or finish its
detached preparation, but it is ineligible while the correction owns the
boundary. Playing and queued buffers are immutable. The proposal expires after
the first complete successor boundary for which it was eligible; it is not
rolled forward across multiple occurrences.

Late evidence alone does not latch the hold. Evidence is ignored or deferred
unless it authenticates the exact playing occurrence and a still-unscheduled
target. The deterministic accepted PCM hold is latched only after an authorized
correction becomes unavailable, is rejected, or misses its first eligible
boundary. Transport then repeats the already accepted immutable phrase with
frozen controller and topology. At the next matching phrase boundary the hold
repeats that accepted PCM once more and releases exactly one preserve-course
preparation under the already committed controller state. That successor still
must pass the canonical primary evaluator; the hold does not schedule an
unevaluated substitute. If preparation is still incomplete, transport continues
coherent repeats while the normal bounded preparation path remains active.

Route and timeline resets preserve a latched hold and convert any outstanding
authorized correction into that hold before discarding its worker. A newer
authenticated occurrence cannot authorize another correction while recovery
owns the source-to-target transition. This quarantine prevents live feedback
from repeatedly replacing the preserve-course preparation. The hold clears only
when either the corrected successor or the preserve-course successor
successfully advances at its boundary, or when New Set performs a complete
session reset or shutdown ends the session.

## Route, transport, and shutdown lifecycle

- Pause disables producer eligibility, discards partial capture and pending
  feedback, joins the consumer, retains committed live state and any existing
  hold, and converts an outstanding authorized correction into the hold. Resume
  creates a fresh coordinator identity, queue, worker, exact clock map, and
  window.
- A player timeline restart advances the occurrence epoch while preserving any
  accepted PCM hold and latching an outstanding authorized correction,
  preventing old high sample ranges from authenticating on a new low timeline.
- Route change stops scheduling, removes the tap, cancels and joins the worker,
  preserves an existing hold or latches an outstanding authorized correction,
  discards the old queue, windows, and proposals, advances route generation,
  rebuilds accepted material at the new supported rate from committed state,
  establishes a fresh map, and only then enables a new consumer and producer.
- If clock-map establishment fails, the engine removes any tap and tears down
  both producer and consumer; it does not leave a live producer without a
  provenance-capable consumer.
- Shutdown removes the tap and producer eligibility before cancellation/join,
  then uses the transport-owned post-join destruction lease before freeing the
  queue. Repeated teardown and stale completions are idempotent.
- New Set deliberately reuses that complete shutdown ordering, clears the hold
  and every old occurrence/packet/proposal identity, rotates the musical root,
  then prepares and starts a new session. No old lifecycle result can
  authenticate against the fresh root or occurrence epoch.

Route recovery retains committed attenuation, musical identity, and any accepted
PCM hold. Packets, windows, proposals, and queued main-actor results from the
previous lifecycle are permanently ineligible. Only New Set's complete session
reset or shutdown clears a hold without a successfully advanced canonical
successor.

## Deterministic replay

An offline replay supplies the numeric packet stream, exact scheduled ledger
and map, occurrence epoch, route/engine/policy/evaluator/controller identities,
committed continuation, installed profile fingerprint, and target plan.
Exact identity replay requires identical packetization metadata, including
packet count and first/last packet sequence, counters, and sample ranges. Those
inputs plus identical accepted PCM and versioned state
reproduce the same evidence and proposal fingerprints, controller transition,
terminal candidate PCM, primary verdict, and outgoing continuation.

Different valid packetization metadata changes the evidence and proposal fingerprints.
When it still represents the same contiguous PCM, it may preserve the PCM
fingerprint, BS.1770 measurements, and numeric controller outcome. That is an
equivalence check across valid packetization, not an exact identity replay.

## Failure hold

Queue overrun, packet rejection, incomplete or non-finite capture, clock-map
failure, route or revision mismatch, stale lifecycle identity, unsupported
primary artifacts, expired eligibility, a duplicate occurrence invalidation,
preparation cancellation, missed boundary, primary rejection, and controller
saturation are all reason-coded off the callback. Every failure holds the last
committed controller state and preserves playing audio. Late or unauthenticated
evidence is ignored without latching an accepted PCM hold; only a failed already
authorized correction latches that transport hold. No failure starts an
additional evaluator, renderer, controller, or correction search. A latched
hold releases only the existing canonical primary-qualified preparation path at
the next matching boundary; live corrections remain quarantined until advance.

## Qualification boundaries

The bundled v18 profile, v15 adversarial suite, and v13 disjoint holdout are the only
shipping primary artifacts. Their automated qualification, queue tests,
callback-symbol audit, controller/candidate tamper tests, and deterministic
replay establish implementation and offline policy evidence for engine v36.

The following remain separate states and must be reported separately:

1. exact-source focused and full local verification;
2. automated primary qualification for the exact engine and artifact set;
3. exact release build and app launch;
4. real app transport, 44.1/48 kHz route, pause/resume, interruption, and
   recovery QA;
5. optional listening observations that may open a new measurable deficit; and
6. the 60-minute physical-output and recovery soak.

An offline replay, app launch, green CI run, short listening session, or virtual
route check does not prove the other states. Professional release quality and
physical-output behavior remain unverified until every applicable release gate
passes for the same exact revision.
