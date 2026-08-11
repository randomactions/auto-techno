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
candidate uses quality-contract schema 11, candidate-vector schema 10, and
canonical engine identity `autotechno-canonical-engine.v11`. It preserves
complete symbolic, full-mix, masking, role-stem, score-owned kick-syntax,
event-local groove-pulse,
ordinary closed-hat, score-owned instrument assignment, architecture-local dry-
PCM, score-owned gated percussion texture, shared pulse-echo return-drive,
score-owned upper-role timing, graph, and
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
candidate while the evaluator is uncalibrated.

Kick-syntax evidence retains one compact record for every bar. It binds the
resolved grounded/withheld/recovery role, score and rendered kick count/mask,
exact detector and audible hashes/nonzero counts, detector/audible peak and RMS,
ducking-envelope peak, automatic-mix gain, and role-local kick-stem evidence.
The only active relation is a paid nonconservative energy-release sequence of
grounded setup, two adjacent withheld bars, and step-zero recovery. Withheld
bars must be exactly silent in every kick projection while their existing
weak-pulse cell and motif remain positive; recovery must be positive. The
policy remains uncalibrated, so these facts can reject broken provenance but
cannot promote the musical device.

Gated-percussion-texture evidence also retains one compact record for every
bar. An active record binds an eligible existing percussion event to one-step
input admission, a four-step delayed output start, a four-step output window,
exact protected-return hashes, finite peak/RMS, nonzero counts, exact-zero
window endpoints, and full/protected render-pass agreement. The score adds no
onset and the renderer retains no captured loop: conservative and ineligible
bars are exact neutral, and delay/filter work remains detached from the
callback. The current feedback, filter corners, return level, mono placement,
and boundary window are engineering realization v1, not the durable musical
concept. A later DSP maturation may replace them with higher-order filtering,
fractional or stereo delay, controlled nonlinear colour, and perceptually
calibrated bounds only if the same input/output-gate semantics, fallback,
deterministic score, and score-to-PCM evidence remain intact.

`ProfessionalEvidenceReportBank` accepts a bank only when every canonical
journey checkpoint is present for every included rate and every report carries
complete phrase, role-masking, and role-stem evidence. The shipping evaluator
remains deliberately uncalibrated: a healthy preparation renders the primary
once, and neither the transaction nor the report bank constitutes runtime
professional-quality qualification. The separate frozen development contract
now loads the engine-v10 source profile `c52545b5641e6cfb` and passing
adversarial suite `2340017ec6c59440`. It evaluates complete representative-rate engine banks
without PCM, stems, or event lists and rejects every dimension and relationship
independently. Calibrated paired ranking and the hybrid live-feedback loop below
remain target architecture until their implementation and validation are
recorded.

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

- finite samples and bounded sample, true-peak, DC, and block-boundary behavior;
- stable low-frequency phase and mono compatibility;
- no invalid graph, runaway tail, discontinuity, or unbounded controller state;
- deterministic planning, rendering, evidence, and decisions for identical
  versioned inputs;
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
- coherent long-range consequence across phrases, chapters, and route recovery.

Targets are section- and role-aware ranges, relationships, and obligations. They
are not whole-track averages that encourage the engine to flatten every moment
toward the same spectrum or loudness.

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
Candidate-vector schema 7 binds that record to the matching instrument effect
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
validation snapshot passed. Its evidence remains descriptive under
`uncalibrated.v1`; it cannot select or promote a candidate and does not qualify
professional sound.

### Upper-role timing evidence

The implemented harmonic-timing slice delays only existing shadow and response
notes during eligible breath-chapter bars. `ResolvedUpperNote` owns the positive
displacement in sixteenth-note steps. The anchor, atmosphere, transition,
conservative, forced-home, identity-return, major-break, and sixteen-bar macro
endpoint paths remain exact zero. Between exact alignment at macro bars 0 and
15, the deterministic aperture rises and falls on absolute bar position; shadow
uses half depth, response uses full depth, and the full displacement is capped
at `0.12` of one sixteenth. Note count, base step, pitch, velocity, instrument,
requested duration, gate, and every protected-rhythm event remain unchanged.

Candidate-vector schema 7 retains one compact record per full rendered bar. It
binds route-derived frame geometry, score and actual renderer onset facts,
requested gate end, bounded renderer-owned applied gate end, causal role counts,
exact protected/role offset relationships, and separate shadow/response dry
hashes with finite peak and RMS. A normal eligible attempt must contain the
displacement; forced-home and every ineligible path must be neutral. This
evidence remains descriptive under `uncalibrated.v1`, does not enter
`selectionEvidence`, and adds no audio-callback work or persistent timing state.

## Development qualification loop

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

1. The canonical director proposes a fixed number of complete plans from the
   current musical and quality state.
2. Detached preparation renders immutable audio and exact role evidence.
3. Hard gates reject unsafe or invalid output.
4. The quality policy evaluates the surviving multidimensional evidence.
5. A fixed number of bounded, deterministic corrections may be applied before a
   candidate is selected or the conservative fallback is used.
6. The chosen plan, reason-coded evidence, controller state, and policy version
   become continuation input for future preparation.
7. Final immutable blocks receive a second safety check before scheduling.

The evaluator may select internal instruments, graphs, or strategies through the
canonical score. It may not switch to another top-level engine or retain a
parallel runtime.

Under quality-contract schema 11, candidate-vector schema 10, and canonical engine
v11, the versioned transaction implements the bounded evidence and atomic commit
foundation for this loop. It can retain at most the primary, alternate, and
conservative-fallback candidates, plus one
home-timbre correction, with no more than four render passes total. Every attempt
starts from the same incoming state. The transaction records the incoming
continuation fingerprint and each attempt's outgoing render-plus-generated-DSP
fingerprint before a quality decision exists; outer commit provenance then binds
the chosen transaction, sample hash, render/DSP state, and finalized quality
continuation state. Rejected attempts remain attempt-local.

The production evaluator does not request a paired comparison, so the healthy
path performs one primary render and reports qualification unavailable.
Phrase analysis now streams within an explicit working-memory envelope, with
independent DFT, chunk-parity, representative-rate, cancellation, and optimized
fixture evidence. Calibrated paired ranking stays disabled until representative
canonical-journey candidate cancellation, latency, and peak-memory budgets pass
under the frozen profile and adversarial suite. Preparation
checks cancellation at bounded
bar-render and evidence-phase boundaries as well as between candidates; the
streaming preflight and continuation fingerprints also check within their long
array scans. A route change cancels stale detached work. This foundation adds no
audio-callback analysis or feedback work.

## Hybrid live feedback boundary

Live feedback observes only app-owned mixer PCM. It never enables a microphone,
records the room, identifies an output device acoustically, or sends audio to a
network or model service.

The audio callback may only copy a bounded sample window into a preallocated
single-producer/single-consumer handoff. It performs no allocation, locking, FFT,
analysis, logging, file or network I/O, model inference, or UI work. A bounded
background worker consumes fixed sample-indexed windows and publishes an
immutable evidence snapshot through a lock-free handoff.

Wall-clock timing does not define evidence. The window's sample positions,
sample rate, route state, engine version, and quality-policy version do. The same
captured PCM and versioned state must reproduce the same result in an offline
replay test.

An adjustment can affect only unscheduled future bars or phrases. It cannot
rewrite a playing buffer, mutate scheduled audio, or block the scheduler. If
analysis or preparation misses its deadline, the engine repeats coherent
prepared material and retains bounded state rather than degrading continuity.

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
