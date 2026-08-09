# Historical Taste Experiments

This file preserves the repository's pre-automation listening observations,
candidate rules, measurements, and pending verdicts. It is non-normative
provenance: current product policy lives in `../PRODUCT.md`, and current quality
policy lives in `../SOUND_QUALITY.md`. Historical requirements for manual
listening or promotion do not govern new work.

## Active direction

Auto Techno should feel dark, hypnotic, authored, and continuously performed. The
kick and bass remain stable physical anchors while upper voices create identity,
tension, mutation, and return. Repetition establishes memory; variation should
sound motivated by phrase structure rather than random replacement. The result
should feel like one machine with intent, not a shuffled library of loops.

Prefer changes that produce a materially audible performance leap: stronger
long-range consequence, recognizable synth character, relational rhythm, and
earned contrast. Avoid marginal control expansion, novelty for its own sake, and
technical polish that is inaudible at matched loudness.

## Rule for new entries

Every musical rule begins with a concrete observation in the form:

> At this moment, this element sounds or feels this way; it should instead do
> this perceptible thing.

Record the canonical-session checkpoint and time region, the smallest
reproducible rule changed, the matched-loudness comparison, and the keep/revert
verdict. Measurements may reject unsafe output but do not replace listening.

## Legacy engineering appendix — current-runtime cleanup, 2026-08-08

Observation: none. This cleanup intentionally does not retune the performance.
The surviving render equations and current autonomous planning path are retained.
Private fixtures 42, 48291, and 90909 produced bit-identical representative-rate
PCM before and after cleanup, so there is no audible difference to approve. These
values are historical engineering fixtures, not product choices or current
acceptance criteria. Any future hash change still requires investigation and the
listening gate. Physical-output smoke testing and soak remain separate pending
states.

## Video-informed groove-first candidate — 2026-08-08

Observation source: the supplied production lessons repeatedly
build authority from one coherent pulse, deliberate gaps, stable sound identity,
and infrequent structural contrast. Repository inspection also found that the
ensemble arbiter's events were reported as metadata while the renderer generated
a different onset pattern. This candidate should make the arbitrated groove
audible, reduce unmotivated mutation, and let sparse phrases remain valid.

Canonical listening checkpoints: first macro, first chapter change, contrast,
break, release, and identity return. The smallest reproducible rules are:
resolved-bar event ownership, sixteen-bar punctuation, topology mutation only
for contrast/break phrases, persistent foundation companions, optional low-cut
three-sixteenth echo, Phrygian identity for sufficiently dark scenes, and a
stable motif timbre fingerprint.

Matched-loudness comparison: pending. Physical listening has not been performed.
Verdict: implementation candidate only; do not promote new hashes or claim
musical approval until the canonical comparison is heard and recorded here.

## Video-informed interlocking evolution candidate — 2026-08-08

Observation source: the supplied [production lesson](https://www.youtube.com/watch?v=UZ41F-uI8AQ)
suggests that a short sequencer can drive a longer follower so simple parts reveal
new relationships over time. Applied here as a hypothesis, not a listening
verdict: the upper voices use a three-step driver advancing a five-stage follower
against the sixteen-step groove. The cycle changes articulation only, never onset
count or position.

The smallest additional rule is a bounded sixteen-bar chapter memory. `home`
preserves the fingerprint, while `breath`, `tone`, `motion`, and `memory` emphasize
envelope, spectrum, resolved-pitch glide, or sparse band-limited pulse echo.
Identity returns force `home`, and no more than four macros may elapse without
it. Foundation voices remain stable and outside both the relational articulation
and upper-voice topology mutation.

Matched-loudness comparison: pending at the canonical checkpoints above. Keep
only if the performance feels progressively revealed rather than busier.
Verdict: pending listening approval.

## Video-informed kick hierarchy candidate — 2026-08-08

Observation: “kick is a little too loud.” The supplied Underdog
[mixing video](https://www.youtube.com/watch?v=QWgA5l2m2H0) treats level as the
first and strongest hierarchy decision before corrective EQ or compression. The
smallest reproducible rule is therefore a fixed `-1.5 dB` kick fader: regular
level `0.72 → 0.605804` and breakdown level `0.54 → 0.454353`.

The audible kick now feeds the mix, masking analysis, and kick level metadata
after that fader. The existing pre-fader kick continues to drive ducking, so the
pump, transient, decay, rhythm, companion levels, and processing topology do not
change. Automated evidence confirms `-1.5 dB` isolated kick energy, unchanged
resolved kick onsets, and a pre-fader ducking envelope independent of the new
audible level.

Matched-loudness comparison: pending. Listen eyes closed at the first macro,
contrast, break, release, and identity return. Keep only if the kick remains
authoritative while mono rumble and the surrounding groove are easier to hear,
without weakening releases. Verdict: pending; do not promote candidate hashes.

## Automatic kick/foundation hierarchy candidate — 2026-08-09

Observation: “the kick is still a little bit too much in your face,” and the app
waveform appears almost entirely kick. Inspection showed two separate causes:
the musical balance is still kick-forward, while the display independently
normalizes every bar and expands low values, making absolute level relationships
impossible to read.

The smallest reproducible audio rule is a private kick/foundation governor fed
by exact dry role stems. It starts with an additional `-1 dB` kick correction,
moves by no more than `0.35 dB` per prepared bar, stops inside a `0.35 dB`
deadband, never boosts above the authored post-fader kick, and is bounded to
`-3...0 dB`. Authored active-level targets are `16.5 dB` over bass, `27.5 dB`
over mono rumble, and `22.5 dB` over tuned tom. Breaks, empty companions, and
inaudible foundations hold the prior state. The pre-fader ducking detector,
foundation levels, onsets, arrangement, and topology remain unchanged.

Separately, the read-only waveform now maps RMS energy through one fixed
`-48...-6 dB` scale. This corrects the visual evidence without feeding UI state
back into the music. Adding the five measurement stems at unity preserved the
compact first-macro PCM exactly (`e50fdd2d1d020804`). Enabling the governor
changed that diagnostic render to `35a6c0e5d4bb271c`, with RMS `0.0835107` and
peak `0.4143651`; the canonical mono-rumble relationship settled at about
`27.73 dB`, inside the target deadband.

Matched-loudness comparison: pending. Keep only if the kick remains authoritative
but no longer crowds the rumble and surrounding groove. Expanding automatic gain
control to percussion or upper voices remains out of scope until this first
relationship is heard and accepted. Verdict: implementation candidate only; do
not promote hashes.

## Video-informed weak-sixteenth groove reveal candidate — 2026-08-09

Observation: the automatic kick/foundation change was not clearly audible in the
whole mix. Do not tune that mechanism further in this slice. The supplied
[groove lesson](https://www.youtube.com/watch?v=7lgyDq8N1J0) instead suggests a
more recognizable rhythmic hypothesis: downbeats, upbeats, and the two weak
sixteenth positions need an intentional hierarchy, and favoring the trailing
weak position should create a bodily side-to-side pull into the next beat.

The smallest reproducible rule adds one dark, mono-centred mid-percussion carrier
on the weak positions. A sixteen-bar macro reveals it in four stages: four bars
of the existing skeleton, four bars of `0.38/0.52` contour, four bars of
`0.30/0.72` trailing-side emphasis with a two-hit minimalisation, then four bars
of trailing-only pullback. The carrier is a 45 ms noise/click band-limited around
`550...3,200 Hz`, uses the existing shuffle, and counts as `0.20` of an ordinary
event in space/overactivity evidence. It remains below kick, foundation, and
motif arbitration priority, enters the percussion stem, and cannot affect the
automatic kick/foundation gain decision.

Exact baseline: commit `9157658`, Xcode 26.6 / Apple Swift 6.3.3, canonical first
macro at 44.1 kHz, sample hash `c0a8e56171793343`, RMS `0.09027027`, true peak
`0.40203717`, loudness estimate `-21.580105`, and low-band stereo correlation
`0.9999444`. The comparison artifacts remain temporary and outside the
repository. The candidate hash is `8cae318d64ba05aa`, with RMS `0.09027233`,
true peak `0.4020319`, loudness estimate `-21.579906`, and unchanged low-band
correlation `0.9999444`. Loudness-normalized bars 1–4 are bit-identical; only the
three reveal stages differ.

Matched-loudness comparison: pending across bars 1–4, 5–8, 9–12, and 13–16,
with a carrier-only diagnostic. Keep only if the reveal is obvious in one pass,
creates side-to-side motion, and does not merely sound like additional hats.
Verdict: implementation candidate only; listening approval remains pending.

## Multi-video curated narrative and spectral-depth study — 2026-08-09

Observation sources: Underdog's lessons on
[curated randomness](https://www.youtube.com/watch?v=e72pJqOGEbk),
[contrast](https://www.youtube.com/watch?v=tCpF60PppEI), and
[arrangement as story](https://www.youtube.com/watch?v=xY7vRHiSJSM);
AWAKEND's retrospective on
[producing 1,100 songs](https://www.youtube.com/watch?v=jQgITl0OYXQ);
Kangding Ray's
[quad-polymeter demonstration](https://www.youtube.com/watch?v=TAyHOFrXH2s);
and Voltage Labs' exploration and performance of
[hypnotic techno](https://www.youtube.com/watch?v=ri9lZVR_eRA&t=2232s).
All six transcripts available for this study were automatic captions.

Community evidence was sampled on 2026-08-09 using YouTube's top-ranked order.
The inspected top-level comment counts, in the source order above, were
`50/50/50/50/5/50`. Repeated technically useful reactions supported selection
over unbounded randomness, deliberate contrast, and arrangement that makes a
small amount of material feel consequential. These are community hypotheses,
not listening approval. The five accessible Kangding Ray comments contained no
meaningful collective technical evidence, so no consensus is inferred from
that source. Separate reply-thread counts were not retained for this initial
study and therefore cannot be cited as reply-thread evidence.

The combined candidate has three smallest reproducible ideas: place at most one
existing upper event behind the groove before a dry identity return; give the
dominant motif a continuous cross-phrase presence contour while admitting or
removing at most one supporting role at a structural boundary; and use the
existing three-to-five relationship to open and close complementary spectral
apertures during `tone` chapters without adding onsets or a new clock.

In the linked hypnotic-techno performance, stable bass and overall level
accompanied substantial upper-spectrum change. This is descriptive evidence
only. It is not a loudness, filter, or spectral target and must not calibrate the
engine automatically.

Canonical listening checkpoints: first macro, first chapter change, contrast,
break, release, identity return, and the beginning, middle, and end of the first
`tone` macro. Compare each of the three ideas independently at matched loudness.
Keep only changes that progressively reveal the same machine rather than making
it wetter, brighter, or busier. Verdict: pending; comments and measurements do
not promote candidate hashes.

## Video-derived resonant-sequence and detuned-motion study — 2026-08-09

Observation source: Underdog Electronic Music School's
[“The two first techno sounds you should learn”](https://www.youtube.com/watch?v=-N8RPZaH3_Y)
(uploaded 2025-05-19, accessed 2026-08-09). The study used automatic English
captions and timestamped visual inspection; it did not treat the creator's
perceptual adjectives as measured properties of Auto Techno output.

The transferable hypotheses are relationships, not genre presets. At
`1:26...7:21`, the lesson combines a monophonic saw or square source with a short
resonant filter contour, register, accents, and slides. At `7:21...15:24`, it
demonstrates same-pitch detuned oscillators creating phase motion, followed by
restrained filtering and optional spatial depth. A sample of 50 top-level
comments and six replies in YouTube's top-ranked order produced no three-comment
technical convergence. One useful but uncorroborated suggestion was to evolve a
short repeated sequence through bounded note-length and accent changes.

Applied hypothesis: express `resonantSequence` and `detunedMotion` as bounded
score-owned articulations of the existing authored upper voice. Resonant
sequence may affect only eligible dominant-motif material, with at most one
legato slide per bar and no added onset. Detuned motion may affect only eligible
shadow or response material and must preserve the protected foundation, phase
continuation, and existing stereo-stage ownership. Identity return, major break,
conservative fallback, missing evidence, and stale evidence return home.

Qualification status: unavailable until the versioned role- and section-aware
guardrails are calibrated. Deterministic structural and signal tests can prove
score-to-PCM ownership, bounds, continuation, and safety, but cannot by
themselves establish production-ready sound. Reference audio is not a runtime
dependency, and neither the video nor its comments promote an engine revision.

Evidence scope is deliberately explicit. Filter/accent/slide observations use
an anchor-only tap, and detune-motion observations use a shadow/response-only
tap before the shared mix path. Width, masking, spectrum, and boundary context
come from the existing GeneratedDSPGraph remainder (`full - foundation`), which
is not claimed to be upper-only: it may also contain percussion and shared
nonlinear residual. The older masking model's aliased synth/texture inputs,
foundation omission, and percussion diagnostic rerender remain deferred to an
independent masking-attribution slice; this timbre change does not reinterpret
those measurements as qualification evidence.

## Video-derived harmonic-cascade timing study — 2026-08-09

Observation source: Underdog Electronic Music School's
[“What are 'cascade arpeggios'?”](https://www.youtube.com/watch?v=P93n6ldccwU)
(uploaded 2023-12-12, accessed 2026-08-09). The bounded research pass used
`yt-dlp` metadata and the available automatic English `en` and `en-orig`
caption tracks; no manual English track was available. The two downloaded VTTs
were identical. No listening claim is made, and music-only demonstrations were
not treated as measured evidence.

At `0:34...1:08`, the automatic captions describe chord tones repeating at
slightly different rates, beginning together and gradually separating into a
loose cascade. At `1:09...1:29`, the lesson frames that relationship as a way
to reduce rigid grid alignment while feeding the notes to one synthesizer. At
`1:54...2:18`, it preserves a favored rhythmic relationship while repitching
the existing notes for another chord. Exact BPM values, the named effect, and
subjective reactions are source context, not Auto Techno targets.

Fifty top-ranked top-level comments were sampled through a dedicated `yt-dlp`
top-sort capture, plus six replies from three technically relevant threads with
no more than two replies per thread. More than three independent top-level
comments converged on phasing/minimalist timing relationships; the remaining
reactions were aesthetic, workflow-oriented, or non-actionable. One unrelated
reply thread returned incomplete data after bounded retries, so no inference is
made from missing replies. No usernames or verbatim comments are retained, and
the comment sample does not promote the candidate.

Applied hypothesis: extend existing resolved upper notes, not the transport, by
delaying only shadow and response attacks during eligible breath-chapter bars.
One absolute 16-bar align-spread-realign aperture reaches at most `0.12` of a
sixteenth step; shadow uses half depth and response full depth. Anchor and
protected roles remain aligned, and pitch, velocity, duration, gate intent,
density, instrument assignment, fallback, and continuation ownership remain
unchanged. Same-pass renderer timing tuples and separate role-local dry evidence
must falsify scheduling, aperture, or role-policy drift. The uncalibrated policy
cannot select or promote this evidence; automated structural, signal, and
runtime validation remains distinct from listening and physical-output soak.

## Video-derived kick-syntax ambiguity study — 2026-08-09

Observation source: Underdog Electronic Music School's
[“How to catch your audience off guard (in a good way)”](https://www.youtube.com/watch?v=j5JlAwOnEnI)
(uploaded 2023-12-04, duration `4:49`, accessed 2026-08-09). The bounded source
capture used `yt-dlp` `2026.03.17` without account, cookie, or authenticated
browser state:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source13-research -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=j5JlAwOnEnI'
```

No manual subtitle track was available. The downloaded automatic English `en`
and `en-orig` VTTs were byte-identical, each with SHA-256
`4fe1d3178d6e5e856d10201d573d2e88100bd59179ece1b4e415ff693ddbe3c4`.
The metadata and comment artifact had SHA-256
`462f722361c84b2dab84ca9b16393a77a36a473e5ca451ad356b50a614ba5b5d`.
Automatic-caption spellings around the background synth, label name, and a few
music-only transitions were uncertain and were not normalized into engine
claims. The final caption cue also extended slightly beyond the declared video
duration, so caption timing is chapter-level provenance rather than a
sample-accurate observation.

The bounded transcript paraphrase is: `0:00...0:38` introduces a climax gesture
that first encourages the wrong kick expectation and then restores impact;
`0:38...1:10` contrasts the source track's steady, atmospheric presentation with
a more direct percussion-led remix; `1:10...1:23` demonstrates its kick and
mid-percussion cell; `1:23...2:01` identifies upbeat and weak-sixteenth accents
whose interpretation becomes unstable when the kick reference is removed, with
an additional synth reinforcing that uncertainty; `2:01...2:48` demonstrates
the kickless break and the unchanged groove snapping back into focus when the
kick returns while upper material continues; `2:48...3:02` describes a
subjective trade from intimacy toward drive; `3:02...4:05` compares the device
to ambiguous musical grammar across familiar four-, eight-, and sixteen-bar
phrases; and `4:05...4:49` contains release context, promotion, and the outro.
Music-only demonstrations and claims of physical impact remain descriptive
source evidence, not measurements of Auto Techno.

The same command captured exactly 50 top-ranked top-level comments and seven
replies. Three technically relevant threads were inspected within the protocol's
reply limit; the remaining replies were promotional, aesthetic, or otherwise
non-actionable. At least five independent top-level reactions converged on the
limited perceptual relationship that an exposed weak-beat figure can obscure
beat one and that the returning full groove forces a surprising reorientation.
This clears the three-independent-comment threshold for community convergence,
but it does not establish an objective increase in impact or production quality.
One substantive thread suggested “metric” or “metronomic” rather than
“syntactic” ambiguity, but its reply is not an independent vote. Another proposed
actually moving the bar line and received a DJ-mixing caution; that is a distinct
technique, not corroboration. Likes, track recommendations, repeated replies,
and general praise were not counted as technical evidence. No usernames or
verbatim comment text are retained.

The durable claim is relational: a stable kick establishes the metrical frame;
temporarily withholding that existing anchor while preserving an already-owned
weak-position carrier can make the downbeat structurally ambiguous; restoring
the unchanged kick on its original grid can recontextualize the same material.
The literal production actions are rejected as engine requirements: do not move
the transport or bar line, relocate the kick, introduce a 3-3-2 clock, add an
unbounded “chaos” layer, create another percussion carrier, depend on a DAW, or
add a user-facing control. The source does not define a calibrated perceptual
target and cannot prove listener confusion automatically.

Implemented clean-room translation: the single resolved score now owns one
bounded `grounded -> withheld -> withheld -> recovery` relationship at an
eligible paid-debt energy-release boundary. The director first resolves the
canonical phrase, then withholds only the two existing kick subsets on macro
bars 13 and 14 while preserving the canonical pullback weak pulses, motif, and
every other score event. Macro bar 15 restores the unchanged step-zero recovery
kick. Conservative fallback, identity return, missing debt, early markers, and
incomplete prerequisites remain exactly grounded. Closed-hat event indices are
re-resolved after kick filtering; transport timing, density, instruments,
generated graph, continuation, and callback ownership are unchanged.

Preflight independently replays the session-owned performance character,
foundation behavior, paid-debt identity, baseline kick score, and the one
authorized syntax arc before typed hashing. Same-pass bounded evidence covers
every rendered bar: score/render kick counts and step masks, exact detector and
post-fader hashes, nonzero counts, peaks/RMS, kick-stem agreement, fader scaling,
and full/protected render-pass equality. Withheld bars require exact-zero kick
buffers and stems while their four weak pulses and motif remain positive;
recovery requires a rendered step-zero kick and positive signal. Candidate
vector schema 9, quality-contract schema 10, typed plan-fingerprint domain v6,
and canonical engine `autotechno-canonical-engine.v10` identify the change.
The selector and policy remain `uncalibrated.v1`, so this evidence cannot promote
or rank a candidate.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated module caches, serial SwiftPM, and the workflow's bounded
prepared-product process splits:

- all 150 unique workflow tests passed: core/evidence 103/103, preparation
  preflight 21/21, protected routing 7/7, and split upper/prepared-product
  coverage 19/19;
- the Source 13 suite passed 3/3, including a real prepared-product assertion
  that selects the primary and proves exact withheld hashes/stems, surviving
  weak pulses/motif, and positive step-zero recovery;
- exact versioned fingerprint and performance-character regressions passed;
- the previously synthetic closed/open-hat fixture now finds a naturally
  director-generated relation and binds its later-phrase continuation exactly;
- the optimized `AutoTechno` product build passed in 58.19 seconds;
- a repeated independent static audit found no remaining P0-P2, and
  `git diff --check` was clean before publication.

The matrix establishes deterministic score ownership, source-to-render
consequence, exact evidence/fingerprint binding, bounded continuation,
conservative fallback, protected routing, cross-rate behavior, and optimized
build integrity. No matched-loudness listening, exact-build app playback,
physical route/interruption smoke, representative preparation-latency or
peak-memory budget, or hardware-output soak was completed. Automated
professional-quality qualification therefore remains unavailable, and neither
the source nor this structural validation makes a sound-quality or
release-readiness promotion.
