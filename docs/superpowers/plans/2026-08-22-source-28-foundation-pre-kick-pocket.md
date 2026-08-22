# Source 28: foundation pre-kick pocket

## Source evidence

- Video: `https://www.youtube.com/watch?v=RKw-d6A4GOc`, *Rookie mistakes
  in techno*, Underdog Electronic Music School, accessed 2026-08-22.
- Transcript: YouTube automatic English captions retrieved with `yt-dlp`
  2026.07.04. The `en` and `en-orig` VTT files were byte-identical with
  SHA-256
  `1a578e244e3d1079d5204c6e18330901278f357c9dd5d8bf69a3642fbfffb329`.
- Page discussion: 50 top-ranked top-level comments and 11 replies across four
  substantive threads were sampled. Discussion independently emphasized
  coherent groove and role priority; a concrete caution opposed indiscriminate
  high-pass filtering that thins sources.
- Audio demonstration: the local 48 kHz stereo extraction had SHA-256
  `2928571094ab7542fc2c1039dd1078f48eaef517803edc0bccf02313ae84a902`.
  Machine inspection of the demonstrated weak-kick passage found sustained
  low-band occupancy around the kick. This is descriptive source evidence, not
  human listening or promotion evidence.
- Relevant source claim: a short absence immediately before a kick can make the
  kick's low-end priority perceptible. The source also frames tonal balance and
  filtering as contextual rather than universal targets.

Temporary captions, comments, audio, thumbnails, and analysis images remain
local and untracked.

## Falsifiable deficit

At the canonical protected-foundation render checkpoint, the existing
`dottedThreeSixteenth` Bass Pluck event one sixteenth before an already-owned
kick can sustain through that kick. At 130 BPM its current maximum nominal body
is about `0.3112` seconds while one sixteenth step is about `0.1154` seconds.
The score therefore expresses a complementary onset relationship but the dry
foundation PCM can erase the intended pre-kick pocket.

The hypothesis is falsified if same-pass dry-foundation evidence shows that
every eligible pre-kick interval is already silent without changing the current
renderer. It is supported when the baseline event crosses the kick and one
bounded score-derived terminal release creates a finite, exact-zero interval
before the kick while preserving all score onsets and every non-foundation
role.

## Causal shape decision

Extend the existing dotted-foundation relationship. Do not add a bass track,
kick track, synth, sidechain compressor, EQ, master filter, effect bus,
sequencer clock, selectable mode, or callback controller.

The canonical owner is `FoundationRhythmicRelation.dottedThreeSixteenth` and
its exact two-bar bass/kick masks. The existing Resonant Mono Bass Pluck,
protected route, dry center placement, TPT/ADAA core, score swing, and primary
evaluator remain authoritative. A new mechanism would duplicate the already
resolved foundation/kick relationship. A global high-pass or master tonal
target would also contradict the source's explicit contextual-filtering
caution and duplicate existing role-local masking and spectral evidence.

## Score-derived articulation

Add one Core-owned `FoundationPreKickPocketArticulation` derived from an exact
resolved bar after dotted-rhythm resolution:

- eligibility requires the existing dotted relation, hypnotic-lock character,
  monotone Bass Pluck foundation, grounded kick syntax, foundation admission,
  and an in-bar bass event exactly one step before an existing kick;
- phase zero resolves bass step 3 before kick step 4;
- phase one resolves bass step 11 before kick step 12;
- at most one articulation is admitted per bar; no cross-bar pocket is inferred
  in v1;
- established, ineligible, identity-return, and conservative fallback paths
  remain literal neutral; a home-upper correction preserves the same resolved
  foundation score and must replay the pocket and its evidence exactly.

The v1 renderer starts a state-free raised-cosine release `0.1875` step before
the kick and reaches exact zero `0.0625` step before the kick. At fixed 130 BPM
that retains a body under maximum dotted-event swing and creates about `7.2 ms`
of exact dry-foundation silence. Route-derived frames, not wall-clock timers,
own the geometry.

## Renderer and continuation

`VoiceRenderer` resolves the articulation before the existing bass loop and
passes optional terminal-release geometry into
`ResonantMonoVoice.renderFoundation`. The active event applies the multiplier
to the same sample before output, dry-foundation, architecture, and send taps;
it truncates only that event at the release end. Literal neutral executes the
previous render path without an additional multiply.

The curve is state-free and bounded by one existing event per eligible bar. It
adds no buffer, oscillator, random draw, persistent continuation, scheduling
work, or real-time callback operation. Existing Resonant Mono continuation is
left at exact zero after the truncated event. Route change behavior remains the
existing detached rerender and deterministic state reset.

## Evidence and policy

Extend each foundation-rhythm bar record with one compact nested pre-kick
pocket record. It binds:

- relation, score event index, bass step, kick step, and route geometry;
- natural event end, release start/end, kick frame, and positive release and
  silence frame counts;
- exact dry-foundation hash, peak, and RMS of `[releaseEnd, kickFrame)`;
- score/render assignment binding, finiteness, and full/protected equality.

Active evidence is complete only when the natural event would cross the kick,
`eventStart < releaseStart < releaseEnd < kick`, the silence window is nonempty,
and its same-pass dry-foundation peak and RMS are exact zero. Neutral evidence
uses a canonical empty sentinel. The record enters candidate JSON, typed
fingerprints, malformed-evidence tests, and engine/schema identities.

Add one Professional Evidence dimension,
`foundation-pre-kick-pocket-silence-rms-maximum`. It is an upper-only safer
metric with a near-zero physical guard instead of a broad perceptual tolerance.
A dedicated adversarial contamination scenario raises this metric above the
installed profile and must fail non-compensably. Regenerate the primary
profile, adversarial suite, and disjoint holdout under the new exact engine.

## Validation

- Core resolver tests for both pair phases, exact event/kick ownership,
  ineligible neutrality, and one-record bound.
- DSP tests at 8, 44.1, 48, 96, and 192 kHz for route-derived geometry,
  raised-cosine monotonicity, exact-zero pocket, finiteness, and changed
  foundation PCM versus a test-only neutral render.
- Same-bar regression proving unchanged score masks, non-foundation stems,
  pass equality, event count, instrument assignment, effects, and continuation.
- Initial-versus-home-upper-correction regression proving identical pocket
  geometry, dry-foundation PCM, and protected evidence for the unchanged score.
- Candidate JSON round-trip, fingerprint sensitivity, malformed geometry/hash/
  signal rejection, and exact established sentinel coverage.
- Primary metric extraction, safer-bound behavior, adversarial rejection,
  regenerated artifacts, representative-rate/cancellation/resource gates,
  callback symbol audit, release build, and exact-head CI.

## Maturation boundary

The durable idea is score-owned low-end priority through attributable silence
before an already-owned kick. The v1 two-point raised-cosine geometry and exact
zero proxy are replaceable engineering details. A later serious renderer may
replace them in place with envelope-phase-aware note shortening,
transient-conditioned ducking, fractional-step articulation, or a richer
foundation model only after calibrated masking, low-end hierarchy, or transient
evidence exposes a repeatable deficit. It must retain the same canonical score
owner, exact neutral ineligible path, protected route, deterministic
continuation, causal evidence, and single primary evaluator.
