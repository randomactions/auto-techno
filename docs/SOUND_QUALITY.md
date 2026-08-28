# Sound Quality Contract

## Status and purpose

Professional release-quality sound is Auto Techno's explicit iterative goal. It
is not a claim about the current build. This document defines how the engine will
measure progress, qualify revisions, and adapt its own future output without a
manual curation gate or third-party instrument dependency.

The current runtime already supplies deterministic planning, detached rendering,
role evidence (including exact-tap onset-local anchor-expression diagnostics),
signal-safety reports, masking analysis, one bounded automatic mix correction,
and a versioned candidate-evaluation transaction. The current implementation
candidate uses quality-contract schema 39, candidate-vector schema 35,
candidate-transaction schema 6, and canonical engine identity
`autotechno-canonical-engine.v38`. Its explicit modal, tuned-inharmonic,
deliberate-dissonance, and indefinite-pitch rules are defined in
[`PITCH_IDENTITY_CONTRACT.md`](PITCH_IDENTITY_CONTRACT.md). It preserves
complete symbolic, full-mix, masking, role-stem, score-owned kick-syntax,
event-local groove-pulse,
ordinary closed-hat, paid-debt climax-arc, score-owned instrument assignment,
score-owned modal-foundation articulation and same-pass resonator evidence,
architecture-local dry-
PCM, acid-operator, TPT/ADAA nonlinear-core, rising spectral-cluster,
response-owned upper harmonic-tail, indefinite-pitch periodicity and
frequency-independence, and tonal-envelope-expansion
evidence, score-owned gated and anticipatory
percussion-return texture,
score-owned dotted foundation rhythm, its pre-kick pocket, and exact dry Bass
Pluck consequence,
shared pulse-echo return-drive,
score-owned spatial-FDN configuration and exact stereo wet consequence,
score-bound phrase composition covering band-limited percussion/kick resampling
and score-seeded overlapping granular memory with exact grain-geometry evidence,
arpeggiation, four-voice pad PCM, score-owned harmonic disclosure and exact
arpeggiator pitch binding, score-owned pad rhythmic modulation, and quantified
voice-leading,
score-owned upper-role timing—including bounded foreground lead performance—graph, and
pre/post upper-timbre evidence
for each retained attempt, then binds the selected attempt to finalized commit
provenance. Instrument evidence
records bounded patch automation, compatible effect access, event count, exact
PCM identity, peak, RMS, and finiteness without retaining reconstructable
stems. Typed plan evidence also binds one phrase-scale performance character
and every bar's compatible foundation behavior, role set, and kick relationship.
This prevents independent style randomization from being mistaken for coherent
variation; it remains structural evidence rather than a calibrated musical-
quality verdict. Its
phrase-wide full-mix evidence uses ITU-R BS.1770-5 K-weighting, 400 ms blocks
with 75% overlap and two-stage gating, plus the Annex 2 four-phase FIR for
true-peak level. It now streams directly across immutable render blocks without
constructing phrase-sized channel, mono, energy-prefix, or spectrogram arrays.
Rate-derived Hann windows retain actual spectral centroid, bandwidth, flatness,
85% rolloff, positive flux, and RMS-trajectory movement. The vector records
window geometry, source/active counts, and a conservative analyzer working-memory
bound capped at 6 MiB; BS.1770 programme-energy storage is fixed to the product's
32-second phrase envelope. Block sizes and durations are derived from the route
rate. The
groove-pulse projection retains exact dry-sample identity plus bounded source
level, spectral position, and tail-to-attack consequence for each already
resolved pulse. Its score intensity can therefore distinguish the bounded
3-3-2 accent/ghost cell from the unchanged weak-pulse onsets without analyzing
the mixed percussion stem, adding density, or creating another onset. Closed-hat
records likewise bind every resolved ordinary-hat event to its neutral or
same-onset open-hat-companion decay role, exact dry-sample identity, and bounded
level, spectral, and tail consequence. They do not add events or promote a
plan before the calibrated evaluator reaches a terminal decision.

Upper-percussion-tail evidence covers every resolved clap, open-hat, and
metallic event after ensemble arbitration. The score chooses either exact
`naturalBody` or context-owned `foregroundClearance`; clearance is available
only when another role owns the foreground, the phrase is not an identity
return, and the bar does not intentionally pile roles together. The renderer
keeps the first 8 ms exact, then applies one state-free raised-cosine release to
a final multiplier of `0.25` after the existing voice has generated its
canonical sample. The record binds score and rendered event identity, full and
attack-window hashes, frame geometry, peak/RMS, attack/tail RMS,
tail-to-attack dB, difference RMS, finiteness, and protected/full pass equality.
Neutral events must remain bit-identical. Two calibrated observation dimensions
retain the clearance-event ratio and the mean rendered tail-to-attack dB, and a
dedicated adversarial case rejects a forged runaway clearance tail. This is a
bounded reuse of existing voices, not another percussion lane or effect chain.

The tuned-percussive foundation now replaces the former root-only tom
realization in place. Core resolves up to two articulations from the exact
existing foundation events, modal DNA, character, gesture, and bar identity.
The detached renderer uses one six-mode resonator with four fixed continuation
slots; it does not allocate a voice array, choose pitch, or run a second drum
engine. Every bar records empty or active score/render coverage, articulation
and state fingerprints, exact dry PCM, protected/full pass equality, route
validity, requested and measured pitch, attack/body/tail ratios, spectral
centroid, masking, maximum pole radius, and finiteness. Eight corresponding
professional-quality dimensions are independently bounded. Dedicated
adversarial cases reject detuning, masking flood, rate drift, and runaway tail.

The existing acid-thread and acid-sequence patches now carry durable ordered-
hollow and metallic-tension spectral intentions. The current Resonant Mono
renderer realizes them with one bounded two-operator dark-to-bright-to-dark
aperture while protected-foundation and non-acid patches remain on the exact
neutral operator path. Same-pass evidence binds patch assignments and event
counts to ordered/metallic ratios, requested and applied index bounds, an exact
event fingerprint, the operator-tap hash, peak/RMS/crest, low-band energy ratio,
and finiteness. Those semantics and evidence ownership are the long-lived
contract; the present ratios, index mapping, anti-alias budget, high-pass
treatment, and operator blend are implementation v1. A future oversampled,
higher-order, or differently band-limited DSP may replace them only under a new
engine/schema identity while preserving deterministic score ownership, the home
correction, protected low end, and truthful consequence evidence.

Every Resonant Mono assignment now reaches one shared nonlinear-filter core.
First-order antiderivative-antialiased `tanh` shaping surrounds a
topology-preserving-transform state-variable filter; the existing patch and
semantic automation remain the score owner. Same-pass evidence binds exact
assignment/event/sample counts, applied cutoff/Q/drive/band-mix ranges, pre-core
and post-core fingerprints, signal levels, continuation, and finiteness. This
replaces the architecture's former four local coefficient one-poles and private
rational saturator. It does not claim that separate architecture or generated-
graph nonlinearities have been migrated.

Every existing kick event now passes its complete body, sub, and click sum
through one fixed first-order ADAA `tanh` conditioner before the canonical
detector and audible buses. Exact zero stays exact zero, the state resets at
each kick onset, and no score event, bus, track, instrument, send, master stage,
or user control is added. Per-bar evidence binds the exact event and processed-
sample counts, pre/post typed hashes, peak/RMS/crest, physical attack/body RMS,
1--4 kHz energy ratios, finiteness, score/render geometry, detector/audible
scaling, and protected/full equality. Four Professional Evidence dimensions
retain output crest, attack-to-body balance, upper-mid energy, and crest
reduction; the v15 adversarial suite retains a source-local transient spike.
The present fixed curve is a bounded realization, not a permanent kick target.

The existing Tonal Motion architecture also carries one durable
`sustainedWash` envelope relation. It is eligible only for the final retriggered
motif anchor at a nonconservative energy-release macro marker, and only when at
least one sixteenth remains for its consequence to become observable. The score
does not add a note or change pitch, duration, gate, velocity, instrument,
effects, or transport. Renderer realization v1 raises the same patch envelope
to a bounded `0.68` sustain target and multiplies its existing release by `3.2`,
with absolute caps of `0.92` sustain and `2.4` seconds. These numbers are an
engineering realization, not the musical concept.

Same-pass evidence retains one event fingerprint, base and applied sustain and
release values, an exact isolated dry-signal hash, peak/RMS, onset-local attack
RMS, final-tail RMS and ratio, nonzero count, binding, and finiteness. The
home-timbre correction is exact neutral and clears any inherited expanded
release before its first onset.
Future MSEG or exponential envelopes, oversampled tail colour, envelope-aware
dynamics, or diffusion must replace this path under a new engine/schema identity
and retain the same score relation, continuation, evidence, and bounded
correction. The record can reject broken provenance but does not alone promote
the device as professionally qualified.

The existing protagonist now also carries one durable spectral-reveal relation.
Only an anchor in a naturally emerging lock or contrast bar can be active. The
current realization multiplies that note's already requested Resonant Mono or
Tonal Motion cutoff by the bounded score aperture
`0.45 + 0.55 * presence^2`; exact home branches to the prior cutoff before
arithmetic. It changes no oscillator, envelope, note geometry, patch, send,
effect topology, or continuation owner.

Each applicable architecture record retains independent score/render event
counts and fingerprints, an event-weighted active count, active-aperture and
actual-cutoff extrema, and exact isolated-anchor hash/peak/RMS. Attempt
validation requires active evidence exactly for normal eligibility and exact
neutrality for evaluator-owned home correction. Professional observation binds
the active-event ratio and mean active-record cutoff ratio; a dedicated
adversarial case rejects a cutoff outside the exact-engine profile. This is a
measured reuse of the existing protagonist, not another synth or automation
lane. A later multiband, higher-order, formant-safe, or oversampled reveal must
replace this scalar realization in place and retain the same score, home, send,
and evidence contract.

Kick-syntax evidence retains one compact record for every bar. It binds the
resolved grounded/withheld/recovery role, score and rendered kick count/mask,
exact detector and audible hashes/nonzero counts, detector/audible peak and RMS,
ducking-envelope peak, automatic-mix gain, and role-local kick-stem evidence.
The only active relation is a paid nonconservative energy-release sequence of
grounded setup, two adjacent withheld bars, and step-zero recovery. Withheld
bars must be exactly silent in every kick projection while their existing
weak-pulse cell and motif remain positive; recovery must be positive. The
primary policy uses these facts without allowing one dimension to compensate
for broken provenance or a failed signal gate.

Climax-arc evidence retains one compact relation for the whole candidate. It
fingerprints every exact incoming dramatic-debt record paid by a nonconservative
energy release, counts contrast and major-break sources separately, retains
bounded opening and due-bar geometry, and, when kick recovery is present,
cross-checks the existing grounded, withheld, withheld, and recovery evidence.
Its nested terminal-hang record is active only on the final withheld bar at
macro position 14. It cross-binds the Core articulation, three pre-hang weak
pulses, anticipation-return boundary, route geometry, 8 ms release, full-mix
pre/post hashes, exact-zero one-beat silence, post-hang/pre-live-master identity,
and unchanged recovery. Established and evaluator-corrected paths remain exact
neutral. The 66th professional dimension,
`climax-hang-silence-rms-maximum`, is upper-only safer with a near-zero guard;
one non-compensable contamination attack prevents an unrelated strength from
hiding signal in the authored absence. This remains long-form causal evidence,
not a separate loudness or tension target.

Percussion-return-texture evidence also retains one compact record for every
bar. A `gatedEcho` record binds an eligible existing percussion event to one-
step input admission, a four-step delayed output start, a four-step output
window, exact protected-return hashes, finite peak/RMS, nonzero counts, exact-
zero window endpoints, and full/protected render-pass agreement. On only the
second kick-withheld release bar, `anticipationSwell` binds that same canonical
return owner to a reverse wet trajectory spanning the remaining bar, exact
release-boundary zero, early/late RMS, and at least 3 dB of measured rise. The
score adds no onset and the renderer retains no captured loop or cross-bar
state: ineligible bars are exact neutral, and all work remains detached from
the callback. Professional dimensions retain the active-bar ratio and mean
late-to-early rise, while a dedicated adversarial case rejects a flattened
release rise. The current feedback, filter corners, reversal, return level,
mono placement, and boundary curve are engineering realization v1, not the
durable musical concept. A later DSP maturation may replace them with transient-
aware reverse convolution, higher-order filtering, fractional or stereo delay,
denser diffusion, or controlled nonlinear colour only if the same answer-or-
anticipation semantics, release boundary, deterministic score, exact neutral
and gated behavior, and score-to-PCM evidence remain intact.

Phrase-slice resampling evidence remains on the existing phrase-composition
record. Its resolved source kind, source/output hashes, trigger/reverse counts,
rate extrema, finite RMS, binding, and protected/full pass equality are produced
by the same detached render that consumes the score. A deterministic spectral
A/B additionally guards the reusable interpolation primitive: the historical
linear 18 kHz/2x path produces a 12 kHz alias at amplitude `0.5`; the current
fixed-radius windowed-sinc path must reject that component by at least 40 dB
while retaining an in-band transposition, exact unity PCM, reverse replay, edge
fades, and neutral invalid-input fallback. These focused facts establish the
causal DSP repair but cannot replace the exact-engine development, adversarial,
holdout, route, cancellation, and resource gates.

The Mordio-derived `granular-memory` texture extends that same record with the
score-owned texture and seed fingerprint plus bounded grain count, length, hop,
and source-position hash. The candidate validator requires those fields only
for granular memory and rejects them on cut or inactive evidence. Identical
source/score/seed must replay identical PCM; changing only the seed must change
the source-position and output hashes; physical grain duration must remain
rate-stable; and the cut branch must remain byte-identical. This qualifies one
bounded texture distinction, not equivalence to a named product or listening
approval.

Pad rhythmic-modulation evidence extends the existing phrase-composition record;
it does not create another synth, sequencer, or effect return. A naturally
resolved latter-half major-break pad may carry one three-sixteenth relation whose
phase derives from absolute bar time. The detached renderer applies it to the
pad's existing low-pass cutoff and existing spatial-reverb send. The same
relation supplies a closed/open/closed amplitude target. One route-derived 6 ms
raised-cosine attack and release stays inside each open sixteenth, gates both
dry pad and its existing send, and leaves synth/filter/spatial continuation
advancing under exact closed-step zeros. Each active record retains the exact
relation, phase and 16-step pattern fingerprint, applied filter/send/gate
extrema, transition geometry, open/closed counts, pre/post dry and send hashes,
closed-step silence RMS, and streamed same-pass filter, spatial-scale, and
amplitude-gate difference RMS. Ineligible and identity paths are literal
neutral. Professional dimensions retain active-bar ratio plus level-relative
filter and spatial consequences in dB. The 67th professional dimension retains
the amplitude-gate consequence; independent adversarial
cases reject disconnected filter and amplitude-gate consequences. The discrete
v1 scale and amplitude mask are replaceable engineering realizations, not the
durable definition of rhythmic motion.

Spectral Texture harmonic-tail evidence applies only when the resolved
response assignment is Voltage Arc. It binds the response-owned
`drivenUpperBand` relation to folded-source and moving-center bounds, resonance,
prefilter drive, LFO rate, exact event and isolated-sample fingerprints, finite
peak/RMS/crest, low-band suppression, and positive upper-band energy. The 68th
professional dimension retains mean upper-band energy ratio as higher-only
safer; phrases without an eligible tail use the exact neutral sentinel. A
dedicated disconnected-tail attack lowers that causal consequence below the
calibrated envelope while leaving claimed score metadata intact. The current
polyBLEP saw, TPT band-pass, drive curve, and LFO are replaceable realization
details under the durable response patch/relation and one-renderer contract.

Foundation-rhythm evidence covers every rendered bar without creating a second
bass lane or effect chain. Eligible four-bar-aligned Lock pairs replace only
their existing bass events with complementary two-bar `0x8248` / `0x4824`
masks, preserving the kick, protected foundation route, score swing, and dry
center placement. Each record binds relation and pair phase, score/render event
counts and masks, exact applied start-frame fingerprint, dry foundation
hash/peak/RMS, Bass Pluck assignment, and full/protected pass equality.
Ineligible and incomplete pairs remain exact established behavior.
Professional dimensions retain active-bar prevalence and mean active crest
factor; a dedicated adversarial case rejects impossible prevalence. The
integer-grid masks and current Bass Pluck realization are replaceable DSP, not
the durable definition of cross-bar foundation timing.

Eligible dotted bars also retain one nested pre-kick-pocket record for the
existing Bass Pluck immediately before kick step 4 or 12. It binds the Core-
owned articulation, exact score event and route frames, natural event crossing,
bounded terminal release, and exact dry-foundation silence window. Candidate
completeness requires positive release and silence intervals, exact-zero peak
and RMS, finite state, and full/protected equality; established or ineligible
bars retain one canonical neutral sentinel. The 65th professional dimension,
`foundation-pre-kick-pocket-silence-rms-maximum`, is upper-only safer with a
near-zero guard. A dedicated contamination attack must fail independently.

Spatial-FDN evidence retains one compact record for every rendered bar. It
binds the existing score-owned depth/carrier/send/filter articulation and the
scene-derived eight-line configuration to exact input and stereo wet hashes,
level, correlation, activity, onset, continuation, parameter-slew, and
opening/terminal wet facts. Delay geometry is derived once for the active route
and retained across ordinary scene/phrase changes; every recursive line gain is
strictly below unity, and retained continuation is hard-bounded. Kick and foundation do
not enter this field; exact protected-route regression tests prove their PCM
identity. The record is required for structural completeness and changes the
transaction fingerprint. See [`SPATIAL_ENGINE.md`](SPATIAL_ENGINE.md) for the
signal and replacement contract.

Cross-phrase transition evidence retains no PCM window. It stores the
predecessor's last stereo frame plus reduced 100 ms output and 250 ms FDN-tail
facts in renderer continuation, then measures the successor's real opening.
Ordinary same-route preparation includes that seam in the existing `< 0.65`
sample-delta hard gate. If an audible inherited FDN field exists, candidate
qualification additionally requires retained delay geometry and nonzero
opening wet energy. Initial phrases, authored climax silence, and route recovery
remain explicit rather than being hidden behind a blanket master crossfade.
Tonal Motion patch boundaries separately retain comb/all-pass/echo memory while
their patch-owned coefficients crossfade for 500 ms.

`ProfessionalEvidenceReportBank` v20 accepts a bank only when every canonical
journey checkpoint is present for every included rate and every report carries
complete phrase, role-masking, and role-stem evidence. The app installs the
exact-engine primary evaluator v19 from the v19 profile, v16 adversarial suite,
and v14 disjoint holdout. It judges every
applicable checkpoint independently and never averages dimensions. The profile
derives from 28 complete 44.1/48 kHz journeys; four replacement holdout journeys
passed 56/56 local verdicts and every phrase/rate relationship.
EBU-style short-program loudness range stays descriptive because its gated
percentile can change discontinuously when one short-term block crosses the
gate. Integrated, momentary, short-term, and true-peak evidence remain policy
dimensions. The seventh architectural stage now carries exact scheduled-output
provenance, live-controller home/proposal evidence, and terminal pre/post trim
proof through the same primary transaction. The transaction remains bounded to
one initial render plus one optional same-plan correction, and its streaming
analyzers retain fixed working-memory ceilings. See
[`PRIMARY_EVALUATOR.md`](PRIMARY_EVALUATOR.md) and
[`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md).

The separate Phase 1 long-horizon evidence foundation is Core-owned schema
`autotechno-long-horizon-semantic.v1`. Its streaming accumulator records bounded
semantic occupancy, recurrence, tension/activity/repetition/density movement,
1...64-bar periodicity, capability dose, identity return, and dramatic-debt
lifecycles across committed canonical plans. It stores no PCM and imports no DSP
type. The offline canonical-journey harness exercises four- and eight-hour
trajectories plus malformed and adversarial synthetic journeys, but the report
has no pass/reject field and always declares qualification unavailable with
reason `no-calibrated-long-horizon-policy`.

Phase 2 separately embeds current `autotechno-long-horizon-continuation.v2` in canonical
`TemporalMusicalMemory`. It records committed arc/episode context, fixed-domain
capability recency, semantic energy start/target coordinates, identity
landmarks, reserve, and payoff/recovery/recall obligations. It is bounded,
schema-safe, deterministic, and transactionally preserves the accepted episode
on malformed input. Phase 3 lets the existing director consume only exact bound
context and records `autotechno-long-horizon-selection.v1` provenance on the one
plan. That choice reaches the existing resolved score and renderer through the
selected phrase kind; no parallel plan, correction, renderer, or quality policy
was added. Phase 4 adds
`autotechno-long-horizon-energy-coordination.v1` to that same plan and projects
the exact episode target through existing character, foundation, role,
percussion, narrative, harmonic, timbral, spatial, and transition owners. The
all-hold path is frozen exactly; active paths are phrase-boundary only and bound
protagonist slew, percussion-tier movement, role count, and spatial-carrier use.
It introduces no DSP primitive, effect implementation, graph stage, renderer,
or callback work.

Phase 5 adds two still-unqualified evidence foundations. Core schema
`autotechno-long-horizon-effect-sentence.v1` names at most one gated
call/response or anticipation turnaround already present in the resolved score.
DSP schema `autotechno-long-horizon-effect-dose.v1` reduces the accepted graph,
pulse echo, percussion return, FDN, instrument effect access, and masking records
into per-bar and fixed-capacity session evidence for eligibility, wet occupancy,
tail-only activity, true recovery, active/inactive runs, last use,
return-to-source level, and the last sixteen realized sentences. It stores no
PCM and changes no audio. Invalid causality or discontinuity makes the report
unavailable without partially changing accepted counters. The report continues
to declare `no-calibrated-long-horizon-policy`; no current primary-policy bound
or quality verdict consumes it.

Phase 6A adds DSP-owned schema
`autotechno-long-horizon-signal-trajectory.v1`. It derives one exact signal-only
phrase observation from the accepted prepared product and binds the plan,
candidate-evidence, and PCM fingerprints to per-bar and phrase-wide loudness,
true peak, crest, spectrum, transients, masking, wet/dry, stereo, and movement
dimensions. The semantic coordination target remains a separate field. A
fixed-capacity checkpoint accumulator records explicit omitted phrase/bar gaps,
per-operator transition deltas, episode summaries, metric ranges, and only the
most recent 32 phrases/transitions and 16 episodes. It never retains PCM or
changes candidate choice, score, audio, or callback work. Invalid rate, order,
episode re-entry, evidence consistency, or overflow makes the report unavailable
without partially mutating accepted summaries.

Phase 6B calibrates independent non-compensable semantic, per-operator signal,
and effect-family dimensions across five exact four-hour development journeys
at 44.1/48 kHz. The immutable artifact set rejects ten independent adversarial
attacks and accepts two disjoint holdout roots. It retains only reduced
irreversible evidence and binds the exact engine-v38/primary-v19 identity.

Phase 7 consumes that policy only during detached preparation. A fixed-capacity
active-rate observation requires at least 7,200 bars, twelve signal observations,
two transitions per operator/rate, and a 256-bar decision interval. Each hard
failure remains reason-coded and non-compensable. Core may apply one `recover`
decision only to an eligible unscheduled successor through continuation v2;
qualified, short, stale, malformed, wrong-root, wrong-rate, and ineligible
evidence preserves the accepted continuation. The prepared transaction commits
musical, primary-quality, live-master, and long-horizon state together. Route
recovery reuses the interrupted phrase's incoming observation so evidence is
not double-counted. No PCM enters the observation, and no analysis or decision
runs in the realtime callback. See
[`LONG_HORIZON_PERFORMANCE_MAP.md`](LONG_HORIZON_PERFORMANCE_MAP.md).

Phase 8 applies the separate sound-maturation gate to those exact artifacts.
The accepted development and holdout journeys expose no repeated
capability-local sound failure, while every named adversarial attack remains
rejected. Root `135791` is excluded because its bounded checkpoint search
supplies too few representative payoff transitions; that is an observability
shortfall, not evidence of failed PCM. No synth, patch, DSP primitive, effect,
bus, chain, renderer, policy, or runtime state changes in Phase 8. A later
promotion requires repeated independent-root failures at both representative
rates with valid score, phrase-quality, route, and unrelated-family evidence.

## Engine ownership

The shipped signal path owns its synthesis, effects, mixing, and mastering
behavior. Playback and release qualification require no VSTi, Audio Unit
instrument or effect, DAW, sample-library runtime, cloud model, network service,
or account.

Development may use legal reference recordings and external offline analyzers.
Reference audio, extracted stems, and generated comparison WAVs remain local and
untracked. The repository may contain only source metadata and aggregate target
profiles that cannot reconstruct the recordings.

## Quality is a vector

No single score may stand for “professional.” A decision preserves the individual
dimensions and the reason for every rejection, correction, or selection.

### Hard gates

- finite samples and bounded sample, true-peak, DC, internal block-boundary,
  and predecessor-to-successor seam behavior;
- stable low-frequency phase and mono compatibility;
- no invalid graph, runaway tail, discontinuity, or unbounded controller state;
- deterministic planning, rendering, evidence, and decisions for identical
  versioned inputs;
- fresh App-owned identity at a complete session boundary, including the
  explicit New Set action, followed by exact deterministic replay for the
  selected seed and strict preparation/cache/feedback isolation from every
  prior seed;
- bounded CPU, memory, preparation latency, candidate count, and correction count;
- uninterrupted sample-time playback and coherent route recovery.

A hard-gate failure cannot be offset by strength in another dimension.

### Translation and sound dimensions

- transient shape, punch, crest behavior, and absence of brittle or smeared
  attacks;
- low-end authority and a stable kick/foundation hierarchy;
- spectral occupancy, masking, harshness, mud, and useful separation among roles;
- integrated and short-term loudness, dynamic range, and headroom appropriate to
  each structural state;
- stereo depth, phase stability, mono translation, and restrained spatial tails;
- recognizable authored timbre without aliasing, accidental noise, or generic
  preset substitution.

### Musical dimensions

- pulse clarity, groove hierarchy, deliberate space, and controlled density;
- score/render agreement for accent/ghost grouping without onset proliferation;
- persistent identity across variation and internal strategy changes;
- motivated tension, contrast, release, subtraction, and return;
- useful repetition without stagnation and variation without random replacement;
- distinct complete sessions without unbounded in-session randomness: entropy
  chooses only the root identity before planning, while the canonical score and
  continuation own every subsequent variation;
- coherent long-range consequence across phrases, chapters, and route recovery.

Targets are section- and role-aware ranges, relationships, and obligations. They
are not whole-track averages that encourage the engine to flatten every moment
toward the same spectrum or loudness.

### Long-form kick and upper-percussion body evidence

The resolved score now binds one kick-morphology record to every bar. The
record carries bounded source homes, continuous segment progress, and exact
start/end values for pitch fall, fundamental, body/sub decay, harmonic body,
drive, and click. Same-pass source evidence hashes that score record and the
actual pre/post-conditioned kick PCM while retaining physical attack/body and
upper-mid consequence. A morphology mismatch, discontinuity, non-finite value,
out-of-range home, or forged render binding makes candidate-vector schema 35
incomplete. Minute-three/minute-fifty checks are causal sound tests, not an
arrangement heuristic.

The existing upper-percussion record now also carries the selected physical
body. Clap events must resolve to clap, snare, or rim; open-hat and metallic
events must remain native. Exact base/rendered hashes, attack/full/tail RMS,
tail-to-attack relation, and difference RMS prove both the body consequence and
any later foreground-clearance envelope. No body label can pass without the
matching score event and PCM.

### Pulse-echo return-drive evidence

The implemented return-drive slice may change only the existing shared,
180 Hz-high-passed and 3.2 kHz-low-passed pulse-echo return. The score clamps
`machineTexture` to `0...1` and applies at most `0.55` only in the memory chapter
when pulse echo is score-enabled, an assigned instrument has pulse-echo access,
and the candidate is neither conservative, forced home, identity return, nor a
major break. Every other case resolves to exact neutral drive.

Each full rendered bar now retains same-pass bar, BPM, delay-frame, and
rendered-frame geometry; score and drive eligibility; bounded source texture and
applied amount; current-send RMS; exact filtered pre-drive and wet post-drive
sample hashes; pre/post peak, RMS, and low-band RMS; difference RMS; and finite
status. It also retains exact first/last sample bit patterns, the pre-drive peak
frame, the exact input/amount witness at the post-drive peak, and a replayable
changed-frame witness together with that frame's exact input bits.
Candidate-vector schema 35 binds that record to the matching instrument effect
access, score bar, phrase kind, route rate, three-sixteenth delay geometry, and
sample-rate-normalized boundary transition. Neutral drive requires the no-change
sentinel, identical pre/post hashes and metrics, and zero difference RMS. Positive
drive requires a replayable bit-pattern change plus changed hashes and nonzero
difference RMS. Active drive is outside the feedback write. Its driven saturation
may lift low-level return detail, so replayed peak witnesses, a conservative
physical peak cap, and the transfer's at-most `3.2x` low-level RMS gain replace the
former attenuation-only bound.

The implementation preserves dry upper-source identity, score events, protected
rhythm, persistent patch and phrase identity, and the identity-return score by
leaving the send source and feedback write unchanged. The exact-source local
structural, signal, protected-routing, and release-build matrix recorded in the
validation snapshot passed. Its evidence is one input to the calibrated primary
policy and does not alone qualify professional sound.

### Upper-role timing evidence

The implemented harmonic-timing slice delays only existing shadow and response
notes during eligible breath-chapter bars. `ResolvedUpperNote` owns the positive
displacement in sixteenth-note steps. The anchor, atmosphere, transition,
forced-home, identity-return, major-break, and sixteen-bar macro
endpoint paths remain exact zero. Between exact alignment at macro bars 0 and
15, the deterministic aperture rises and falls on absolute bar position; shadow
uses half depth, response uses full depth, and the full displacement is capped
at `0.12` of one sixteenth. Note count, base step, pitch, velocity, instrument,
requested duration, gate, and every protected-rhythm event remain unchanged.

Candidate-vector schema 35 retains one compact record per full rendered bar. It
binds route-derived frame geometry, score and actual renderer onset facts,
requested gate end, bounded renderer-owned applied gate end, causal role counts,
exact protected/role offset relationships, and separate shadow/response dry
hashes with finite peak and RMS. A normal eligible attempt must contain the
displacement; forced-home and every ineligible path must be neutral. This
evidence adds no audio-callback work or persistent timing state.

## Development qualification loop

The exact-engine primary evaluator is preloaded at app construction and created
per covered 44.1/48 kHz route. Missing artifacts and unsupported rates are
truthfully unavailable and cannot commit. The initial single-journey profile
failed unseen phrases, and the first two holdout cohorts exposed
masking/transient/crest and short-program LRA semantics instead of being silently
absorbed as proof. The final 28-journey profile, adversarial suite, and four
disjoint holdouts pass offline and are the same artifacts used by runtime
preparation.

1. Render the same private canonical journey bank before and after a change at
   representative sample rates and structural checkpoints.
2. Capture exact engine, quality-policy, fixture, continuation, route, and
   toolchain versions.
3. Compare hard gates, role evidence, full-mix evidence, trajectory evidence, and
   any applicable derived reference profile.
4. Emit a machine-readable report with reason-coded pass, reject, and adjust
   decisions. Match loudness for diagnostic comparisons where level would mask
   the changed dimension.
5. Reject any unexplained hard-gate failure, determinism change, disconnected
   parameter, metric regression, or preparation-budget breach.
6. Promote the engine and policy revision only when all required automated gates
   pass. Optional human feedback may open another measurable deficit; it cannot
   bypass or replace the automated decision.

## Runtime generate, evaluate, and adapt loop

The target loop is bounded and persistent:

1. The canonical director proposes one complete plan from the current musical
   and quality state.
2. Detached preparation renders immutable audio and exact role evidence.
   Calibrated rejection of the first phrase uses the same bounded serial
   variants as successor preparation; unavailable or exhausted evidence blocks.
3. Hard gates reject unsafe or invalid output.
4. The quality policy evaluates the surviving multidimensional evidence.
   Runtime selects one calibrated whole-phrase checkpoint. Every phrase from
   index 16 uses the long-continuation population; an earlier ordinary lock
   also uses it even at a chapter boundary;
   compound offline labels are not intersected into an uncalibrated population.
   Optional modal metrics reuse qualified active bounds when a checkpoint's
   development evidence contains only the exact inactive sentinel.
   Kick-over-foundation balance is judged only when the paired active-bar ratio
   proves that at least one audible comparison exists; an absent comparison is
   neutral rather than a fabricated 0 dB balance.
   Optional upper spectral reveal records use neutral activation evidence only
   when the score has no eligible reveal events; eligible but inactive rendering
   remains a rejection, while the activation ratio is one-sided higher-is-safer.
5. The evaluator may request one deterministic home-timbre correction of that
   same plan; otherwise it reaches a terminal verdict after the first pass.
6. A calibrated guardrail rejection, or a hard-gate rejection proved to contain
   only invalid symbolic phrase interest, may inform one later, serial director
   proposal after a coherent accepted-PCM repeat. The rejected plan and PCM
   never commit. The bounded retry ordinal preserves identity, debt, and
   long-horizon ownership; it preserves structural intent whenever the
   canonical four-bar minimum still fits before the earliest open-debt
   deadline, capping only the retry length at that deadline. If no four-bar
   same-kind phrase can remain eligible, the later retry uses the one
   conservative energy-release fallback. Ordinal zero stays the original
   canonical plan, and no proposals coexist or compete.
   Its score-side vocabulary alternates bounded kick attack/body pressure around
   the continuous committed morphology trajectory, so this calibrated source
   metric changes in both directions before eight rejected variants stop in an
   explicit blocked state. Missing or non-finite evidence, unavailable policy,
   graph or signal-safety failure, route/provenance failure, and exhausted
   variants remain terminal.
7. The committed plan, reason-coded evidence, controller state, and policy version
   become continuation input for future preparation.
8. Final immutable blocks receive a second safety check before scheduling.

The evaluator may select internal instruments, graphs, or strategies through the
canonical score. It may not switch to another top-level engine or retain a
parallel runtime.

Under quality-contract schema 39, candidate-vector schema 35,
candidate-transaction schema 6, and canonical engine v38, the versioned
transaction implements the bounded evidence and atomic commit foundation for
this loop. It retains one initial attempt and at most one
same-plan home-timbre correction, with no more than two render passes total.
Every attempt starts from the same incoming state. The transaction records the incoming
continuation fingerprint and each attempt's outgoing render-plus-generated-DSP
fingerprint before a quality decision exists; outer commit provenance then binds
the chosen transaction, sample hash, render/DSP state, and finalized quality
continuation state. Rejected attempts remain attempt-local.

The production evaluator judges the primary plan directly; qualified or adjusted
decisions may commit, while rejected or unavailable decisions may not.
Only a reason-coded calibrated guardrail rejection or an isolated symbolic-interest
hard-gate rejection can advance the later serial retry ordinal. Unavailable
evaluation, every other hard-gate failure, invalid provenance, and commit
mismatch repeat accepted PCM without changing the proposal.
Phrase analysis now streams within an explicit working-memory envelope, with
independent DFT, chunk-parity, representative-rate, cancellation, and optimized
fixture evidence. The diverse profile, adversarial suite, and holdout
qualification are the one primary policy's versioned artifacts.
Preparation
checks cancellation at bounded
bar-render and evidence-phase boundaries as well as between candidates; the
streaming preflight and continuation fingerprints also check within their long
array scans. A route change cancels stale detached work. Scheduled-output
capture is limited to the fixed copy described below; every analysis, decision,
and future preparation remains detached.

## Canonical live feedback boundary

Live feedback observes only app-owned mixer PCM. It never enables a microphone,
records the room, identifies an output device acoustically, or sends audio to a
network or model service.

The audio callback only copies native-stereo packets of at most 1,024 frames into
a preallocated 256-slot C11 single-producer/single-consumer handoff. It performs
no allocation, locking, FFT, analysis, logging, file or network I/O, model
inference, or UI work. A bounded background worker consumes the first exact
three-second sample-indexed phrase window and publishes an immutable evidence
snapshot.

Wall-clock timing does not define evidence. The window's sample positions,
sample rate, route state, engine version, and quality-policy version do. The same
captured PCM and versioned state must reproduce the same result in an offline
replay test.

The one controller derives short-term-loudness and Annex 2 true-peak targets from
the installed profile. It is attenuation-only within `-3...0 dB`, moves down by
at most `0.25 dB` per accepted phrase, and recovers by `0.125 dB` only after two
complete clean observations. The proposal is pending until the primary
evaluator accepts fresh complete candidate evidence for an unscheduled future
phrase. It cannot rewrite a playing buffer, mutate scheduled audio, or block the
scheduler. Late evidence alone is ignored or deferred when its exact target is
no longer unscheduled; it does not latch a repeat. Only an already-authorized
correction that is rejected, unavailable, or misses its first eligible boundary
enters the accepted-PCM hold and repeats accepted immutable PCM. At the next
matching boundary, recovery releases a preserve-course successor under the
committed controller state; it remains subject to the same primary qualification
and further live corrections are quarantined until the score advances. See
[`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md) for clock mapping, occurrence epochs,
invalidation, hold, lifecycle, and replay details.

## Stability and anti-gaming rules

- Keep hard constraints separate from optimization targets.
- Preserve the full evidence vector and reason codes; do not optimize an opaque
  aggregate alone.
- Bound every gain, parameter, derivative, slew, candidate count, and rerender
  count.
- Use deadbands, hysteresis, hold conditions, and recovery rates to prevent
  controller chatter, drift, and competing correctors.
- Test silence, breaks, missing roles, extreme but valid scenes, long runs, route
  changes, sample-rate changes, and delayed successors.
- Reject policies that improve a proxy by flattening dynamics, removing useful
  contrast, adding density, or sacrificing identity.
- Centralize coupled corrections so independent controllers cannot fight over the
  same evidence.

## Human and source evidence

Human listening, production lessons, interviews, and community commentary are
optional hypothesis sources. Record them separately from measurements and from
the policy decision. Translate a useful observation into a falsifiable deficit,
engine responsibility, measurable evidence, bounded action, and regression
scenario. Neither authority, popularity, nor preference promotes a revision.

Use `VIDEO_ANALYSIS_PROTOCOL.md` for video-derived hypotheses. Historical manual
verdicts remain preserved in `history/TASTE_EXPERIMENTS.md` but are not current
policy.

## Qualification states

Report these five states separately:

1. implementation complete;
2. structural and signal validation passed;
3. automated quality qualification passed for an exact engine and policy version;
4. app/runtime verification passed on the exact release build;
5. physical-output and recovery soak passed.

Passing one state never implies the next. Until all five pass, professional
release quality remains unverified.
