# Autonomous Runtime Validation

Release status is reported as separate states: implemented, focused local
verification, full local verification, qualification artifacts, published exact
SHA, exact-head CI, release app launched, app/route QA, listening observation,
and physical-output soak. Passing one does not imply the others. Human
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
only when it satisfies every hard invariant, keeps every applicable calibrated
dimension within its independent bound, and introduces no guardrail regression
at protected checkpoints.

Sample hashes remain regression evidence, not a musical-quality score. An
intentional hash change requires a new exact-head qualification record; unchanged
hashes do not waive the other checks.

The canonical late field has its own deterministic DSP and integration gate.
Tests cover eight ordered odd route-derived delays, strictly sub-unity
delay-proportional gains, high-frequency damping bounds, diffuse and decaying
stereo impulse response, rate-normalized onset, continuation, route reset, and
non-finite containment. Full-render regressions bind score depth and effect state to
exact input/wet hashes while requiring unchanged kick and foundation
fingerprints. Candidate tamper tests require one bounded spatial-FDN record per
bar and reject invalid geometry, gain, hash, count, or score binding. These are
engineering and provenance results; they are not listening, route-recovery, or
physical-output-soak results.

Quality-contract schema 33, candidate-vector schema 31, candidate-transaction
schema 4, and canonical engine v32 provide the current transaction-level
evidence foundation. A complete record
contains the bounded symbolic, hard-gate, full-mix, per-bar masking, role-stem,
automatic-mix, score-owned kick-syntax, paid-debt climax-arc,
score-owned terminal climax-hang,
event-local groove-pulse, ordinary closed-hat, score-owned modal foundation,
score-owned dotted foundation rhythm and pre-kick pocket,
score-owned instrument and its acid/nonlinear-core/cluster/envelope consequence,
score-owned gated/anticipatory percussion-return texture,
shared pulse-echo return-drive, score-owned spatial-FDN, score-owned upper-role timing,
score-owned phrase slicing, arpeggiator geometry and exact score/render pitch
identity, polyphonic pad signal, harmonic-disclosure stage/function,
pad rhythmic-modulation consequence, and voice-leading continuation,
graph, and pre/post upper-timbre vector for every retained attempt. Groove-pulse
evidence must cover every bar
explicitly, bind each score event to one exact dry-sample
hash plus bounded level/spectral/tail consequence inside the single primary
evaluation. For the complete syncopated-lean cell, tests
must prove that the 3-3-2 intensity relationship changes only existing pulse
windows, retains the same event steps/count/timing/physical articulation, and
retains its one canonical grouping. The
closed-hat projection must cover every bar, match each surviving ordinary-hat
score event by stable event index, and prove that only a same-onset open-hat
companion changes the closed-hat tail. Neutral events must retain their sample
identity, with no onset, count, intensity, timing,
brightness, level, or companion-voice change. The instrument projection must
cover every bar, bind every audible assignment to
one catalog architecture, patch, musical use, bounded automation vector, and
compatible canonical effect set, and retain a deterministic hash plus finite
level evidence for the exact dry architecture-local PCM. Empty architecture
records, unsupported role/patch/effect combinations, truncated assignments,
out-of-range automation, or score/render ownership mismatches make the vector
incomplete. Acid-thread and acid-sequence assignments must additionally retain
one complete bounded Resonant Mono modulation record. It must match every acid
assignment and rendered event to its ordered-hollow or metallic-tension
relation, exact current ratio, requested/applied index bounds, deterministic
event and operator hashes, positive finite operator peak/RMS/crest, and bounded
low-band energy. A non-acid architecture may not carry that record; the
protected foundation must retain exact neutral operator evidence and PCM.
Every Resonant Mono architecture record must also retain one complete
`tpt-svf-adaa-tanh.v1` core record. Unique assignment/event counts and processed
samples must bind to the architecture; cutoff, Q, drive, and band-mix extrema
must remain inside route-rate bounds; and exact input/output hashes plus peak/RMS
must be finite and nonzero. The record is forbidden on other architectures.
Focused DSP tests compare its first-order ADAA tanh against point-sampled tanh,
compare TPT response across rates, sweep aggressive modulation across every
supported rate, and require exact chunk continuation.
Cross-rate tests must cover the minimum and maximum supported routes, exact-zero
event endpoints, deterministic replay, live canonical-session reachability,
and a complete selected primary transaction. Current numeric DSP values are a
versioned realization, not permanent musical targets. The transaction binds the
one plan fingerprint, engine/policy/evaluator versions, terminal attempt,
correction count, route
generation, incoming continuation, and the pre-decision outgoing render/DSP
state. Full-mix evidence must identify ITU-R BS.1770-5, retain physical-time
gating counts and phrase-wide integrated/momentary/short-term values, and derive
true peak from the Annex 2 polyphase FIR rather than sample or cubic peak. It
must stream without phrase-sized PCM, mono, energy-prefix, or spectrogram copies;
bind source frames to rate-derived FFT/hop geometry; retain centroid, bandwidth,
flatness, 85% rolloff, positive flux, RMS trajectory, and active-window counts;
and record a conservative peak analyzer-memory bound no greater than 6 MiB. Final
commit provenance must additionally bind the selected sample hash
and finalized quality continuation state; rejected attempts may not affect that
state.

Kick-syntax evidence must cover every full rendered bar and match the resolved
score role, kick count, and sixteen-step mask to the actual kick render pass.
Grounded and recovery bars require positive finite detector, audible, envelope,
and kick-stem evidence; recovery additionally requires step zero. Exactly two
adjacent withheld bars may occur only immediately before that recovery in a
paid, nonconservative energy-release phrase. They require empty score/render
kick sets, exact-zero detector/audible/kick-stem metrics, both nonzero counts
equal to zero, and
the canonical `[3, 7, 11, 15]` weak-pulse evidence plus motif context. Full and
protected render passes, detector-to-audible scaling, automatic-mix gain, and
all hashes must agree. Missing bars, forged roles, arbitrary kick deletion,
nonzero withheld signal, silent recovery, or a changed non-kick score make the
candidate incomplete; the primary evaluator cannot qualify incomplete evidence.

On the final withheld bar only, terminal-hang validation must additionally bind
macro position 14, the exact `[3, 7, 11]` pre-hang weak pulses, step-12/16 score
geometry, positive route-derived release and silence counts, an 8 ms release,
exact-zero silence peak/RMS/nonzero count, pre/post/silence hashes, and equality
between post-hang PCM and the pre-live-master buffer. The next recovery remains
positive at step zero. Tampered geometry, unexpected active evidence, signal in
the silence interval, continuation mismatch, or an earlier withheld-bar hang
must fail candidate completeness. Focused tests must cover 44.1 and 48 kHz and
prove bit-identical output for every neutral bar.

Kick-source evidence inside every kick-syntax record must bind every rendered
kick event and its bounded processed-sample count to exact pre/post hashes,
finite peak/RMS/crest, physical attack/body RMS, and 1--4 kHz energy ratios.
Focused rate tests must independently reconstruct the legacy body + sub + click
source at 8, 44.1, 48, 96, and 192 kHz; prove its input evidence is exact; prove
the fixed first-order ADAA conditioner changes active kick PCM while preserving
event geometry, protected/full agreement, and exact empty-withheld evidence;
and reject version, count, hash, scalar, or finiteness tampering. The calibrated
profile must independently bound conditioned crest, attack/body balance,
upper-mid energy, and crest reduction, with a transient-spike adversarial case.

Upper-percussion-tail evidence must cover every resolved clap, open-hat, and
metallic event with no duplicate or retargeted score index. Canonical replay
must derive `foregroundClearance` only when another role owns focus, the phrase
is not identity return, and the bar is not an intentional pileup. `naturalBody`
must preserve every sample bit-for-bit. Clearance must preserve the first 8 ms,
remain inside the bounded raised-cosine multiplier range, reduce the rendered
tail, change the full event hash, retain finite metrics, and match across full
and protected render passes. Candidate decoding must reject oversized bars,
wrong role/context, forged attack or tail facts, and missing render evidence.
The profile must independently bound clearance ratio and rendered tail-to-
attack mean, and its adversarial suite must reject a runaway clearance tail.

Upper-spectral-reveal evidence must be present on each applicable existing
Resonant Mono or Tonal Motion motif architecture and forbidden elsewhere.
Independent score/render counts must match and remain within the architecture
event count; independent fingerprints, the active-event count, active-aperture
extrema, actual cutoff extrema, and isolated-anchor hash/peak/RMS must all be
finite and bound. Active evidence requires normal emerging lock/contrast
eligibility and an aperture in `0.45..<1`; evaluator-owned home correction must
retain eligibility while resolving zero active events and literal aperture
sentinels of `1`. Same-bar A/B tests must hold notes, assignments, companions,
foundation, percussion, and protected routing fixed while changing only the
existing anchor cutoff path. Candidate decoding must reject cutoff, count,
fingerprint, role, or binding forgery. The exact-engine profile must separately
bound the event-weighted active ratio and applied-cutoff ratio, and its
adversarial suite must reject a cutoff outside that profile.

Modal-foundation evidence must cover every full rendered bar, including empty
bars and bars carrying only an inherited tail. Active events must map one-to-one
to the existing tuned-percussive foundation score indices, steps, intensities,
modal degrees, and bounded material articulation. Requested and measured pitch,
attack/body/tail ratios, centroid, maximum pole radius, exact dry hash, incoming
and outgoing voice-state fingerprints, full/protected pass equality, foundation
routing, masking, and finiteness must all agree. Four fixed voice slots are the
hard capacity; a fifth onset may not steal one. Focused tests require exact
continuation across a bar split, bounded late-bar missing-tail evidence, and
physical-time decay agreement at 44.1 and 48 kHz. The primary policy separately
rejects detuning, masking flood, representative-rate drift, and runaway tail.

Climax-arc evidence must remain inactive for debt-free and
non-release phrases. An active record must fingerprint the exact incoming debt
set paid by the release, distinguish contrast and major-break sources, retain
bounded open/due bars, and, when the existing kick recovery is present,
cross-check one grounded setup, two adjacent withheld bars, and its macro marker.
It may reject broken long-form provenance as one non-compensable input.

Percussion-return-texture evidence must cover every rendered bar. Active
records must bind the canonical eligible source-step mask and earliest admitted
step to the semantic relation, kick-syntax role, route-derived geometry, finite
source/return hashes and metrics, zero out-of-window samples, exact-zero output
endpoints, and identical full/protected render passes. `gatedEcho` requires the
exact one-step input window, four-step delayed output start, and four-step
output window. `anticipationSwell` is allowed only on the second withheld
energy-release bar at macro position 14; it uses the same one-step source,
spans the bounded remainder of that bar, retains positive early/late RMS with
late greater than early by at least 3 dB, and ends at literal zero on the
recovery boundary. Ineligible records must be exact neutral. Tests must hold the
resolved bar, synth plan, dry percussion hash, foundation, kick, groove-pulse,
and ordinary-hat evidence fixed while proving that only the existing return
changes. These tests establish the current realization, not a permanent
filter/delay/reversal recipe; future DSP upgrades must preserve both score
relations, the release boundary, and the evidence before requalification.

Pad rhythmic-modulation evidence must cover every rendered phrase-composition
bar. An active record is valid only for an existing pad in a non-minimalized,
non-marker breakdown bar of a major break at macro position 8 through 14. Its
phase must equal absolute bar modulo three, its exact 16-step filter/send pattern
must match the score, both same-pass difference RMS values must be positive, and
pad output plus spatial-send hashes/RMS must be finite and nonempty. Early,
ineligible, identity, and no-pad records remain exact neutral. Tests must prove
natural reachability, phrase-split phase continuity, exact neutral PCM identity,
active consequence at 8/44.1/48/96/192 kHz, prepared binding, decoded context,
phase, pattern and flat-consequence rejection, and non-compensable professional
observation failure when the filter consequence is disconnected.

Foundation-rhythm evidence must cover every full rendered bar. Active records
must occur as exact adjacent pairs at the canonical four-bar-aligned Lock
boundary, use complementary `0x8248` / `0x4824` score and render masks, retain
the exact route-derived start-frame fingerprint, identify Bass Pluck with zero
space, and carry positive finite dry foundation peak/RMS with identical full
and protected render passes. Incomplete, ineligible, conservative, missing,
occupied-step, or non-bass pairs must remain established. Tests must prove
natural reachability, non-bass score identity, two-bar geometry, active versus
established PCM at 8/44.1/48/96/192 kHz, exact prepared candidate binding,
decoded mask/hash/role tamper rejection, canonical preflight replay, and
non-compensable rejection of impossible professional active prevalence.

Each eligible dotted bar must additionally carry exactly one nested pre-kick-
pocket record for bass step 3 before kick 4 or bass step 11 before kick 12. The
record must bind the resolved score index and Bass Pluck assignment, prove that
the natural event would cross the kick, and satisfy
`eventStart < releaseStart < releaseEnd < kick <= renderedFrameCount` with
positive release and silence counts. The exact same-pass dry-foundation window
`[releaseEnd, kick)` must be finite with exact-zero peak and RMS and must match
between full and protected renders. Established, malformed, and ineligible
paths must retain one exact neutral sentinel. A home-upper correction must
replay the same score-derived pocket and protected foundation evidence exactly.
Tests must cover both
pair phases, 8/44.1/48/96/192 kHz route projection, monotone bounded release,
active-versus-neutral PCM, candidate JSON/fingerprint/tamper rejection, the
upper-only safer metric, and a non-compensable contamination attack.

An eligible Broken Suspension response must resolve exactly one Voltage Arc
assignment and one `drivenUpperBand` event record. Focused tests at
8/44.1/48/96/192 kHz must prove finite deterministic PCM, folded-source and
Nyquist-safe center bounds, positive free-running motion, low-band suppression,
positive upper energy, score/event/hash binding, candidate fingerprint
sensitivity, and complete prepared commit evidence. Removing the nested record,
moving it to another role, forging energy or route bounds, or disconnecting the
professional upper-band consequence must fail closed. Established Spectral
Texture patches must retain no harmonic-tail evidence and their existing signal
path must remain unchanged.

Pulse-echo return-drive evidence must cover every full rendered bar and bind the
bar, fixed BPM, route-derived three-sixteenth delay-frame count, rendered-frame
count, score eligibility, drive eligibility, bounded `machineTexture`, applied
amount, and matching instrument pulse-echo access. It must retain current-send
RMS, exact filtered pre-drive and wet post-drive sample hashes, pre/post peak,
RMS, and low-band RMS, difference RMS, and finite status. Neutral drive must
preserve hashes and all pre/post metrics exactly with zero difference RMS;
active drive must remain outside feedback, bind replayable changed-frame and
peak witnesses, and stay within the transfer's bounded low-level lift of at
most `3.2x` RMS plus its conservative physical peak cap.
Forced-home, identity-return, major-break, non-memory, and
ineligible paths must remain neutral. The implementation candidate contains
this record, and the exact-source local structural/signal tests plus release
build are recorded as passing in the validation snapshot.

Upper-role timing evidence must cover every full rendered bar. Active timing is
allowed only on a nonconservative, non-identity, non-major-break breath bar with
an anchor, a harmonic companion, and a nonzero absolute 16-bar aperture.
Protected roles must remain at exact zero; every shadow offset must equal half
the aperture and every response offset the full aperture, bounded to `0.12` of
one sixteenth step. Score and renderer tuples must agree on role, base onset,
requested offset, expected/applied onset, and requested gate end, while the
renderer-owned applied gate end remains bounded by onset, requested end, and bar
end. Present companion roles must retain finite nonzero dry evidence. Macro
endpoints, forced-home, identity-return, major-break, and otherwise ineligible
paths must remain exactly neutral.

The shipping evaluator is the exact-engine calibrated primary policy. It renders
one primary plan on the healthy path and may request one same-plan home-timbre
correction. Missing artifacts and unsupported routes must report qualification
unavailable and may not commit.
The Professional Evidence v17 bank must contain every canonical checkpoint for
every included rate and complete exact-role masking/stem evidence. The exact
engine-v32 primary evaluator v14 and pinned profile v14/adversarial/holdout
identities must load and replay through the app path. The profile must cover at
least 24 complete development trajectories; the current profile covers 28.
Holdouts must be source-disjoint, contain at
least four complete journeys, accept every checkpoint/rate observation, and
produce no trajectory or rate-consistency failure. Short-program EBU-style LRA
must remain descriptive; stable BS.1770 loudness and true-peak dimensions remain
evaluative. RMS-trajectory peak remains locally and within-rate evaluative, but
its overlapping-window maximum is excluded from cross-rate relationships;
RMS-trajectory mean is the stable cross-rate dimension. Runtime commit tests
must use that exact profile identity.

## Determinism and sample-rate consistency

Tests must prove that the same initial state plus the same accepted,
sample-indexed feedback packets produces the same plan and terminal decision,
graph, immutable PCM, evaluator/controller state, and outgoing continuation
state. Missing evidence and correction decisions must be deterministic.

Run equivalent journeys at 44.1 and 48 kHz and across a route change. Decisions
must be based on rate-normalized evidence and retain the same musical intention
and controller direction unless a documented safety constraint forces
qualification unavailable. Rate changes may change sample counts and
PCM hashes; they must not silently change identity, dramatic obligations, or
accepted-feedback provenance. Rebuilding at the new rate must preserve coherent
continuation and reject stale work from the previous route.

## Bounded generation, evaluation, and adaptation

Plan count, full renders, corrective rerenders, analysis windows, and total
work per future boundary must each have an explicit finite maximum. Tests must
exercise those maxima and prove that invalid or low-quality output cannot trigger
unbounded search. The runtime must always end in one of three states: a qualified
initial render, an adjusted same-plan render, or no commit with a coherent
repeat/hold of the last qualified material.

The current transaction permits one initial render, one home-timbre correction,
and two render passes total. Cancellation is checked before and after bounded
bar-render and evidence phases as well as between attempts. Route changes cancel detached
preparation, advance the route generation, and reject stale results before they
can commit.

Controller tests must cover:

- gain and parameter bounds, slew limits, deadbands, hysteresis, and coupled-role
  constraints;
- convergence from both sides of each target without drift after entering the
  accepted region;
- alternating and adversarial evidence without oscillation, escalating
  correction, or a repeating limit cycle;
- silent, sparse, invalid, clipped, non-finite, missing, late, and stale evidence;
- state hold, bounded recovery toward home, unavailable/rejected decisions, and clean
  reset only at an explicitly defined lifecycle boundary;
- no competition between separate controllers for the same parameter or role.

The accepted plan's evaluator and controller state must be committed
atomically with its plan, render state, graph state, and continuation state.
Rejected attempts must not leak their state. Cache keys and route-recovery
requests must distinguish every state or revision capable of changing selection
or PCM.

## Scheduled-output feedback and callback isolation

Upper-timbre evidence schema 3 plus pulse-echo, upper-role timing, phrase-
composition, spatial-FDN, nonlinear-core, and foundation-pocket evidence carried
by quality-contract schema 33 change detached preparation only. The implemented master-headroom path
is the sole scheduled-output feedback responsibility and does not move those
feature analyzers or decisions onto the callback. See
[`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md).

Feedback may analyze only PCM generated and owned by Auto Techno. It must never
open a microphone, request recording permission, capture ambient/system audio, or
depend on an external audio source.

Scheduled-path callback work is limited to pointer/frame validation, reading the
mixer sample time, and copying at most 1,024 native-stereo frames into one of 256
preallocated C11 atomic queue slots. Invalid tap input must return before the C
producer; malformed input passed directly to the C API must increment its reject
counter. Tests and object-symbol inspection must
demonstrate no allocation, lock, wait, dispatch, analysis, hashing, logging,
file/network I/O, UI work, or musical decision on the callback. Full-capacity
behavior drops the observation without blocking or corrupting audio.

Background analysis must have fixed memory and work bounds. Every accepted
packet records the exact source sample range, route/sample-rate generation, and
controller revision. The scheduled occurrence additionally binds its occurrence
epoch, plan, policy/evaluator/controller identities, mapped player/mixer range,
and target future boundary. Two exact off-callback clock probes must agree before
the consumer and producer become eligible. Partial, overwritten, late, stale,
non-finite, lifecycle-mismatched, or unmapped packets are rejected. Exact replay
identity must bind packet count and first/last packet sequence, counters, ranges,
and the other recorded capture-provenance fields. Alternate valid packetization
may preserve PCM identity, BS.1770 measurements, and numeric controller outcome,
but must change evidence and proposal fingerprints.

The worker assembles the first exact three-second window and reuses the canonical
BS.1770-5 and Annex 2 implementation. The installed profile supplies independent
short-term-loudness and true-peak bounds. Controller tests must prove the
`-3...0 dB` range, no boost, maximum `0.25 dB` attack, `0.125 dB` recovery only
after two clean windows, deadband hold, saturation hold, and deterministic
replay. One authenticated scheduled occurrence may invalidate one unscheduled
successor; repeating the same phrase at a newer authenticated occurrence is a
new bounded opportunity. Pending state may commit only with the primary-
accepted candidate. Current and scheduled buffers remain immutable.

Late evidence alone must be ignored or deferred and may not latch the accepted
PCM hold. Only an authorized correction that is rejected, unavailable, or misses
its first boundary latches that hold. Route and timeline resets must preserve an
existing hold and latch an outstanding authorized correction. A newer
authenticated occurrence may authorize recovery but cannot itself clear the
hold; only a successful corrected boundary, complete session reset, or shutdown
does so. The hold repeats accepted PCM without silence or an untrimmed
substitute.

## Preparation budget

Measure detached preparation and background analysis for the minimum and maximum
phrase lengths, maximum two-pass path, and route
rebuild at representative 44.1 and 48 kHz devices. Record median, high-percentile,
and worst observed times plus peak working memory.

The exact-engine v13 artifact loader, route-local primary evaluator, unavailable-rate
gate, one-correction transaction order, and reason-coded replay require
deterministic tests at 44.1 and 48 kHz. The deterministic numeric-storage estimate
must remain below the declared 128 MiB ceiling. The profile derives from 28
complete journeys and passes the 34-case v15 adversarial suite plus four disjoint
holdouts at both rates. See [`PRIMARY_EVALUATOR.md`](PRIMARY_EVALUATOR.md) and
[`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md).

The declared budget must leave enough lookahead to schedule the future boundary
without callback work or silence. A late successor may repeat the current
qualified phrase with frozen topology, but repeated deadline misses, unbounded
queue growth, or analysis that starves preparation fail qualification. Cancellation
and stale-result rejection must release bounded background work promptly.

## App/runtime verification

On the exact release build, verify:

- one accessible primary transport button, one secondary New Set action, and
  coherent preparing, ready, live, paused, recovering, and unavailable states;
- prepare, play, pause, resume, and phrase-boundary continuation;
- New Set from ready, live, paused, recovering, and unavailable states: exact
  producer-before-consumer teardown, stale-work invalidation, fresh root,
  empty continuation/cache, zero playing time, and automatic start only after a
  commit-eligible first phrase;
- sample-time scheduling, future-boundary controller application, and read-only
  waveform/position reporting;
- authorized-correction hold after a late successor without silence, premature
  state advance, or state leakage;
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
5. exercise normal, one-correction, rejection, unavailable, and missed-analysis-deadline paths;
6. confirm continuous phrase progression, bounded controller state, stable CPU and
   memory, and no clicks, gaps, runaway tails, oscillating balance, crashes, or
   disabled transport.

Record hardware, OS, sample rates, exact commit, quality-contract revision,
start/end times, preparation and analysis timing, controller/correction events,
interventions, and observations. A missing soak is reported as unverified, never
inferred from unit tests, builds, simulations, or prior snapshots.
