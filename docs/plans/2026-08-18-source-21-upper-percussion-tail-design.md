# Source 21 Upper-Percussion Tail Design

**Status:** Approved for implementation design on 2026-08-18

**Video source:** `Sf97zdQMCv0`, *How to make sounds that actually punch through the mix*, Underdog Electronic Music School

**Canonical base:** `5bab623324b0f09ca9832c994e5a4509efb0dd4a`

## Objective

Add one bounded, score-owned tail relationship for the existing clap, open-hat,
and metallic-percussion events so supporting upper percussion can leave deliberate
space for the current foreground without changing its onset, count, intensity,
timing, source, routing, or random sequence. Keep percussion-focused and
intentional-pileup bars on the exact existing body path. Bind the semantic choice
to its same-pass PCM consequence and qualify it through the one calibrated
primary evaluator.

This is an extension of the canonical resolved ensemble and detached renderer.
It is not a new drum engine, envelope sequencer, dynamics processor, runtime,
profile selector, or user control.

## Architecture choice

Three implementation shapes were considered against the video's durable idea:

1. **Extend the existing event envelopes and score.** This keeps the event that
   needs space, the semantic reason, the PCM consequence, and the evaluator
   evidence in one causal path. This is the selected design.
2. **Add a percussion-bus transient shaper or gate.** This could shorten mixed
   tails, but it would act after several events have been summed and would make
   attribution, attack preservation, and role-aware intent weaker. It would also
   compete with the existing protected percussion route and masking evidence.
3. **Add another track, percussion instrument, or effect chain.** The video does
   not describe a missing source or layer. Adding one would increase density and
   duplicate the existing clap, open-hat, and metallic voices instead of giving
   their current tails intentional context.

The first option supports the musical idea most directly. A future source may
justify a new internal voice or processor when the canonical palette cannot
produce the required behavior; reuse is not an end in itself. The decision rule
is causal fit with the durable idea, not a blanket preference against new DSP.

## Source evidence and translation

The clean-room research used unauthenticated `yt-dlp` to retrieve metadata,
automatic English captions, 50 top-ranked top-level comments with four replies,
and a temporary 48 kHz stereo audio copy. No manual English subtitle track was
available. The two automatic English VTTs were byte-identical.

The durable caption claims are:

- `0:35...1:59` contrasts unmanaged and deliberately shortened percussion tails,
  while warning that an isolated fuller or louder drum loop can conceal the
  space required by the complete arrangement;
- `2:00...4:04` separates a decay-owned one-shot contour from a sustained body
  whose perceived length also depends on release behavior;
- `4:04...5:04` makes note-gate length part of the envelope relationship rather
  than treating one release setting as universally correct;
- `5:21...5:40` restates the mix-level goal: intentional event length should let
  the whole arrangement breathe.

The bounded community sample did not produce three-comment convergence on a
portable numeric target. One technically substantive correction warned that
some ADSRs enter release when a zero-sustain note is released, so a maximum
release time can still create long tails or unnecessary work. Another comment
preferred changing between loose and controlled versions, and another suggested
a workstation-specific transient-envelope workflow. These are cautions or
workflow ideas, not engine requirements.

The temporary source demonstrations measured approximately `-18.4 LUFS / -7.1
dBFS` true peak for the first loop and `-19.2 LUFS / -6.8 dBFS` for the later
controlled example. Their unequal durations, source encoding, and surrounding
presentation prevent direct calibration. They only reinforce the video's own
warning that loudness and peak level cannot stand in for tail-space judgment.

No source coefficient, workstation operation, sample, preset, or presenter
identity becomes repository architecture. Low-confidence interpretation remains
under the gitignored `docs/reference/video-evidence/` boundary.

## Existing canonical ownership

`AutonomousSessionDirector` already resolves the one authoritative
`ResolvedPerformanceBar`. Its post-arbitration `EnsembleContext` owns event index,
voice, step, intensity, focus role, and whether pileup is intentional.

Existing specialized tail owners remain authoritative and are excluded from this
slice:

- kick and foundation envelopes preserve their protected low-end hierarchy;
- modal percussion preserves its score-owned damping and resonator continuation;
- groove pulse preserves its physical damping and event-local evidence;
- ordinary closed hat preserves its same-onset open-hat companion role;
- upper tonal sustained wash preserves its separate release-boundary meaning.

The missing capability is limited to `.clap`, `.openHat`, and `.metallic`. Their
current renderer envelopes are fixed implementation details with no resolved
semantic tail intention and no event-local pre/post consequence evidence. The
aggregate percussion stem and masking records can observe a changed mix but
cannot prove which event-length decision caused it.

## Score contract

Add `UpperPercussionTailRole` with two cases:

- `naturalBody`: preserve the exact current renderer path;
- `foregroundClearance`: retain the event's attack while reducing only its tail.

Add `UpperPercussionTailArticulation` containing:

- `scoreEventIndex`;
- `voice` (`clap`, `openHat`, or `metallic` only);
- normalized `step`;
- semantic `role`.

`UpperPercussionTailResolver` runs after ensemble arbitration and emits exactly
one articulation for every retained clap, open-hat, and metallic event, ordered
by score-event index and bounded to four records per bar. It resolves
`foregroundClearance` only when all of these are true:

1. the phrase is not `identityReturn`;
2. `ensemble.focusRole != .percussion`;
3. `ensemble.intentionalPileup == false`.

Every other valid event resolves `naturalBody`. Missing, duplicate, retargeted,
or noncanonical articulations fail preparation before rendering. The same exact
articulation array enters the typed plan fingerprint. Home-timbre correction
retains it because correction changes only the already-bounded upper-timbre
realization of the same plan.

The score relation is durable: supporting upper percussion makes room for the
foreground, while featured percussion and deliberate pileup retain body. The
current DSP curve described below is replaceable.

## Renderer contract

Refactor the existing clap, open-hat, and metallic render functions to produce
one event-local record while writing the same existing output and percussion
stem. Do not allocate a per-event PCM array or perform another render.

For `naturalBody`, every arithmetic operation that produces PCM remains on the
current path. The tail multiplier is literal `1`, so current samples and RNG
advancement remain bit-identical.

For `foregroundClearance`:

1. render the existing base sample with the existing oscillator/noise/envelope
   operations and RNG advancement;
2. preserve the first route-normalized 8 ms attack window with a literal
   multiplier of `1`;
3. over the remaining existing event window, apply a smooth monotonic multiplier
   from `1` to `0.25` using normalized event progress;
4. write only the multiplied sample to the audible and measurement paths.

The v1 end multiplier is a bounded engineering realization, not a source-derived
quality target. It introduces no hard truncation, new onset, cross-event state,
or boundary discontinuity. Existing event frame counts and random draws remain
unchanged. The multiplier is computed from route-derived integer frame geometry,
so 44.1, 48, 96, and 192 kHz behavior expresses the same physical-time relation.

The per-event renderer record retains only scalars and fingerprints:

- score event index, voice, step, role, intensity, and timing offset;
- rendered and attack frame counts plus applied final multiplier;
- exact base and rendered sample hashes;
- base/rendered peak and RMS;
- base/rendered attack RMS and tail RMS;
- base/rendered tail-to-attack dB;
- difference RMS;
- exact pre/post attack-prefix hash;
- finiteness.

Neutral evidence requires identical base/rendered hashes and metrics, equal
attack-prefix hashes, and zero difference RMS. Active evidence requires equal
attack-prefix hashes, changed whole-event hashes, nonzero difference RMS, a
lower rendered tail RMS and tail-to-attack relationship, finite values, and the
exact contract multiplier. Full and protected-rhythm renders must emit identical
records.

## Candidate and quality evidence

Add one bounded `AutonomousUpperPercussionTailBarEvidence` per rendered bar. It
contains bar identity, focus role, intentional-pileup state, score/render source
counts, render-pass agreement, and at most four reduced event records.

Candidate construction matches score and renderer records one-to-one by event
index, voice, step, role, intensity, and timing. Structural validation replays
the score policy, rejects duplicate indices and unsupported voices, checks exact
route-derived frame geometry, and enforces neutral/active consequence rules.
Missing or nonfinite records remain reason-coded evidence failures rather than
being silently dropped.

The affected identities advance together:

- canonical engine v21 to v22;
- quality-contract schema 22 to 23;
- candidate-vector schema 20 to 21;
- typed candidate-plan fingerprint domain v11 to v12.

The candidate-transaction schema remains unchanged unless implementation proves
that its outer wire shape changes. Upper-timbre, live-feedback, commit, and
continuation schemas remain unchanged.

Professional Evidence advances only where the new calibrated dimensions change
its observation shape. Add two independently bounded primary-policy dimensions:

- clearance-active event ratio;
- clearance-event rendered tail-to-attack dB mean.

Their acceptable relationships come from newly rendered canonical development
journeys, not handwritten video thresholds. Regenerate the exact-engine profile,
adversarial suite, and disjoint holdout artifacts; advance their identities and
the report-bank/evidence identity where required. Every existing dimension
remains noncompensable.

Adversarial qualification includes missing evidence, unsupported voice,
role-policy forgery, duplicate/retargeted events, active no-op PCM, changed attack
prefix, tail growth, nonfinite metrics, wrong route geometry, and render-pass
disagreement.

## Bounds, continuation, correction, and realtime safety

- Maximum retained events: four per bar, sixteen bars per candidate.
- New work occurs only during existing detached score resolution, rendering,
  reduction, and evaluation.
- No state crosses a bar or phrase boundary.
- No new buffer, allocation, lock, wait, file/network access, logging, analysis,
  or control work reaches the audio callback.
- Renderer evidence streams hashes and scalar energy inside the existing bounded
  event loops.
- Route changes rebuild future immutable audio at the active sample rate and
  cancel stale preparation under the existing contract.
- Identity-return plans are exact neutral.
- Home-timbre correction retains the same percussion score and evidence policy.
- A rejected or unavailable primary decision cannot commit the new engine state.

## Test-driven verification

Write failing tests before each production change.

1. **Core policy:** post-arbitration one-to-one records, active supporting-role
   reachability, exact neutral featured/pileup/identity paths,
   deterministic replay, bounds, and typed-plan sensitivity.
2. **DSP oracle:** current neutral PCM hashes remain exact; active attack prefix
   remains exact while tail/hash/RMS change in the intended direction at 44.1,
   48, 96, and 192 kHz; RNG order and later-event PCM remain exact.
3. **Routing:** only affected upper-percussion event PCM changes; kick,
   foundation, modal percussion, groove pulse, closed hat, upper tonal,
   atmosphere, event geometry, and protected/full pass identity remain correct.
4. **Candidate contract:** JSON round trip, fingerprint sensitivity, exact
   source coverage, decoded oversize/duplicate/voice/role/frame/scalar forgery
   rejection, correction equality, and reason-coded retention.
5. **Primary evaluator:** regenerated development bank, independent adversarial
   failures, disjoint holdout qualification, representative-rate acceptance,
   unavailable artifact/rate rejection, and exact transaction/commit replay.
6. **Operational envelope:** cancellation, deterministic continuation,
   preparation working-memory/latency gates, release build, and the existing
   split CI matrix.

## Documentation and publication

Update the product, sound-quality, provenance, runtime-validation, roadmap, and
sound-concept maturity documents. Add a Source 21 research record to
`docs/history/TASTE_EXPERIMENTS.md` with the yt-dlp commands, automatic-caption
limitation, hashes, bounded paraphrase, comment methodology, repository
translation, and explicit nonclaims. Do not publish presenter names, usernames,
comment text, media, captions, or reconstructable audio.

Commit the design, implementation, regenerated non-reconstructable artifacts,
tests, and documentation on the isolated Source 21 branch. Validate locally,
obtain independent code review, rebase onto refreshed `origin/main`, rerun the
affected exact-head matrix, push the verified commit to remote main, and confirm
the exact remote SHA and GitHub Actions result before counting Source 21 as
processed.
