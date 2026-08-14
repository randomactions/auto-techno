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

The canonical late field has its own deterministic DSP and integration gate.
Tests cover eight ordered odd route-derived delays, strictly sub-unity
delay-proportional gains, high-frequency damping bounds, diffuse and decaying
stereo impulse response, rate-normalized onset, continuation, route reset, and
non-finite fallback. Full-render regressions bind score depth and effect state to
exact input/wet hashes while requiring unchanged kick and foundation
fingerprints. Candidate tamper tests require one bounded spatial-FDN record per
bar and reject invalid geometry, gain, hash, count, or score binding. These are
engineering and provenance results; they are not listening, route-recovery, or
physical-output-soak results.

Quality-contract schema 19, candidate-vector schema 18, and canonical engine v19
provide the current transaction-level evidence foundation. A complete record
contains the bounded symbolic, hard-gate, full-mix, per-bar masking, role-stem,
automatic-mix, score-owned kick-syntax, paid-debt climax-arc,
event-local groove-pulse, ordinary
closed-hat, score-owned instrument and its acid/nonlinear-core/cluster/envelope consequence,
score-owned gated percussion texture,
shared pulse-echo return-drive, score-owned spatial-FDN, score-owned upper-role timing,
score-owned phrase slicing, arpeggiator geometry, polyphonic pad signal, and
voice-leading continuation,
graph, and pre/post upper-timbre vector for every retained attempt. Groove-pulse
evidence must cover every bar
explicitly, bind each score event to one exact dry-sample
hash plus bounded level/spectral/tail consequence, and leave selection unchanged
while the evaluator is uncalibrated. For the complete syncopated-lean cell, tests
must prove that the 3-3-2 intensity relationship changes only existing pulse
windows, retains the same event steps/count/timing/physical articulation, and
returns to the prior alternating cell in the conservative candidate. The
closed-hat projection must cover every bar, match each surviving ordinary-hat
score event by stable event index, and prove that only a same-onset open-hat
companion changes the closed-hat tail. Neutral and conservative events must
retain the legacy sample identity, with no onset, count, intensity, timing,
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
versioned realization, not permanent musical targets. The transaction binds all
candidate-plan fingerprints, the
engine/policy/evaluator versions, the selected attempt, correction count, route
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
candidate incomplete; none of this evidence changes uncalibrated selection.

Climax-arc evidence must remain inactive for debt-free, conservative, and
non-release phrases. An active record must fingerprint the exact incoming debt
set paid by the release, distinguish contrast and major-break sources, retain
bounded open/due bars, and, when the existing kick recovery is present,
cross-check one grounded setup, two adjacent withheld bars, and its macro marker.
It may reject broken long-form
provenance but may not rank the phrase while shipping policy is uncalibrated.

Gated-percussion-texture evidence must cover every rendered bar. Active records
must bind the canonical eligible source-step mask and earliest admitted step to
the exact one-step input window, four-step delayed output start, four-step
output window, route-derived frame geometry, finite source/return hashes and
metrics, zero out-of-window samples, exact-zero output endpoints, and identical
full/protected render passes. Ineligible and conservative records must be exact
neutral. Tests must hold the resolved bar, synth plan, dry percussion hash,
foundation, kick, groove-pulse, and ordinary-hat evidence fixed while proving
the return changes protected PCM only after its requested output gate. These
tests establish the current realization, not a permanent filter/delay recipe;
future DSP upgrades must preserve the score contract and requalify the
evidence.

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
Conservative, forced-home, identity-return, major-break, non-memory, and
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
endpoints, conservative, forced-home, identity-return, major-break, and otherwise
ineligible paths must remain exactly neutral, and uncalibrated selection must
remain unchanged.

This schema is evidence infrastructure, not a passing shipping professional-
quality policy. The shipping evaluator is uncalibrated, renders one primary
candidate on the healthy path, and must continue to report qualification
unavailable. The frozen offline development policy must load pinned profile and
adversarial-suite identities and accept all fourteen representative
checkpoint/rate observations with no relationship failures.
The Professional Evidence v3 bank must contain every canonical checkpoint for
every included rate and complete exact-role masking/stem evidence. Its own policy
availability remains false by design. Calibrated paired ranking remains disabled
until representative canonical-journey cancellation, latency, and peak-working-
memory budgets pass.

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

The current transaction permits at most three distinct candidate renders
(primary, alternate, and fallback), one home-timbre correction, and four render
passes total. Cancellation is checked before and after bounded bar-render and
evidence phases as well as between candidates. Route changes cancel detached
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
- state hold, bounded recovery toward home, deterministic fallback, and clean
  reset only at an explicitly defined lifecycle boundary;
- no competition between separate controllers for the same parameter or role.

The selected candidate's evaluator and controller state must be committed
atomically with its plan, render state, graph state, and continuation state.
Rejected candidates must not leak their state. Cache keys and route-recovery
requests must distinguish every state or revision capable of changing selection
or PCM.

## Hybrid feedback and callback isolation

Upper-timbre evidence schema 3 plus pulse-echo, upper-role timing, phrase-
composition, spatial-FDN, and nonlinear-core evidence carried by quality-contract
schema 19 change detached
preparation only. They add
no callback capture, analysis, or live-feedback work; the requirements below
remain gates
for a future hybrid-feedback implementation.

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

Before enabling calibrated paired ranking, establish bounded streaming phrase
analysis and measure cancellation latency, preparation latency, and peak working
memory across the full four-pass limit. A test-only comparator does not satisfy
this release gate.

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
