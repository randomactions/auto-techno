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

## Video-derived gated percussion texture study — 2026-08-11

Observation source: Underdog Electronic Music School's
[“Two James Blake-ish drum techniques”](https://www.youtube.com/watch?v=wDlWkea0Q7Q)
(uploaded 2023-10-02, duration `12:18`, accessed 2026-08-11). The bounded source
capture used unauthenticated `yt-dlp` without account, cookies, or browser state:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source14-research -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=wDlWkea0Q7Q'
```

No manual subtitle track was available. The downloaded automatic English `en`
and `en-orig` VTTs were byte-identical, each with SHA-256
`acb7b325e62b1810cef1bb2c49c3337d4239e4a9bb60704e7693f7c37c545bbb`.
The metadata and comment artifact had SHA-256
`de9838747e9ecc06e4d468c65d5dc3e5c71a9347e222421e281bb9042067ce48`.
Representative frames and bounded waveform-only excerpts were inspected
locally to distinguish continuous from gated regions; the video, audio,
screenshots, comments, and transcripts remain temporary and untracked. No
subjective listening or production-quality claim is made.

The bounded transcript paraphrase is: `0:00...1:00` introduces two separate
ideas, one about groove as a relationship between timing and velocity and one
about an input-utility, delay, output-utility chain; `1:00...3:20` explains
auditioning a dense sixteenth-note grid before identifying the useful timing
and velocity relation; `3:20...6:48` applies that relation to sparse drum roles
and removes the audition grid; `7:32...8:45` introduces the utility-delay-
utility device, admits only selected slices into an otherwise overwhelming
delay, and opens the output only where the return should arrive;
`8:45...11:17` demonstrates input-only, ungated, and output-gated states; and
`11:17...12:18` recommends resampling the result and closes the lesson. Exact
plug-in controls, delay settings, swing percentages, source samples, and the
resampling workflow are tutorial context, not engine targets.

The capture returned 26 top-ranked top-level comments and five replies. Three
independent top-level comments converged on the subtractive/gated send-return
relationship around delay; three others independently corrected the historical
attribution of the drum-programming technique. The attribution correction is a
provenance caution, not a musical requirement. A numeric timing suggestion was
single-source and was rejected. Likes, praise, named tracks, product discussion,
and repeated replies were not counted as technical convergence. No usernames
or verbatim comment text are retained.

Repository reconciliation rejected the first half as a new mechanism: shared
weak-sixteenth timing, velocity, sparse admission, physical pulse articulation,
and 3-3-2 accent/ghost grouping already have canonical score and evidence
owners. It also rejected captured resampling, another upper-voice pulse echo,
a user-facing effect chain, and any dependency on the named workstation or
plug-ins. The genuinely uncovered relation was a bounded percussion source
slice whose delayed return becomes audible only inside a later score-owned
output window.

Implemented clean-room translation: after ensemble arbitration, an eligible
nonconservative contrast bar with the broken-suspension character and gear-shift
gesture selects its earliest existing percussion event at or before step seven.
That event opens a one-step input window. The renderer begins a protected
percussion return four steps later and closes it after four more steps. It adds
no event, changes no dry score, captures no reusable loop, and carries no
cross-bar delay state. Conservative fallback and all ineligible bars are exact
neutral. The combined dry-plus-return percussion tap enters existing role and
masking evidence, while the original dry hashes and reverb source remain
separately attributable.

Same-pass compact evidence covers every bar and binds the score context, eligible
source-step mask, input/output steps, route-derived frame geometry, exact source
and return hashes, finite peak/RMS, nonzero counts, zero out-of-window samples,
exact-zero return endpoints, and full/protected pass equality. Candidate-vector
schema 10, quality-contract schema 11, typed plan-fingerprint domain v7, and
canonical engine `autotechno-canonical-engine.v11` identify the change. Shipping
selection remains `uncalibrated.v1`; the frozen engine-v10 profile remains the
development comparison source rather than being relabelled for engine v11.

Future maturation is intentionally recorded rather than implied. The score
semantics are the durable concept: select an existing percussion slice, admit it
briefly, then reveal only a bounded later return. The current integer one-step
delay, `0.72` feedback, `0.42` return gain, 650 Hz high-pass, 4.2 kHz low-pass,
mono image, and 8 ms endpoint window are provisional implementation v1. A later
serious DSP revision may use fractional or multi-tap stereo delay, higher-order
or nonlinear filters, diffusion, controlled saturation, frequency-dependent
feedback, and perceptually calibrated gates, provided it preserves deterministic
score ownership, neutral fallback, protected routing, realtime safety, and
truthful score-to-PCM evidence under a new versioned contract. Any stateful
replacement must finish or fade its residual energy inside the same score-owned
return window, remain independent of render-buffer partitioning, and avoid
optimizing the physical evidence proxies before a calibrated policy owns that
decision.

Local validation proved the isolated score, protected-render differential,
forged-score rejection, compact evidence tamper rejection, and a real prepared
primary transaction at 8 kHz. The complete workflow matrix passed 163/163; the
optimized product build passed; and the complete 44.1/48 kHz engine-v11 journey
passed both the frozen engine-v10 development policy and a newly generated
ten-case adversarial suite. A post-review decoded-`Int.max` step and out-of-domain
step-mask regression also passed. Publication, remote exact-head CI, listening,
app/route validation, and hardware soak remain separate gates.

## Video-derived FM acid spectral-relation study — 2026-08-12

Observation source: Underdog Electronic Music School's
[“An intro to FM acid (like Daniel Avery & Kris Wadsworth)”](https://www.youtube.com/watch?v=uYVsS_X17bM)
(uploaded 2023-08-28, duration `11:52`, accessed 2026-08-12). The bounded
source capture used unauthenticated `yt-dlp` without an account, cookies, or
browser state:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source15-research -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=uYVsS_X17bM'
```

No manual subtitle track was available. The automatic English `en` and
`en-orig` VTTs were byte-identical, each with SHA-256
`cb5e5d874273c57638f677e53b9c4f28ecbceed0dba3cc2bbeff0e40ccb1c112`.
The metadata and comment artifact had SHA-256
`cb4afe734598916cd2ddd036662bd856170eb3007fdcd09f04116914f6c9955f`.
Bounded demonstration audio and local spectrograms were inspected only to
separate the envelope and ratio examples; media, images, comments, captions,
and derived inspection files remain temporary and untracked. Automatic-caption
wording and exact numeric claims remain uncertain, and no subjective listening
or production-quality claim is made.

The bounded transcript paraphrase is: `2:31...3:25` introduces a sine carrier
whose second oscillator increases partial density as modulation amount rises,
creating a dark-to-bright-to-dark spectral gesture without requiring a filter
move; `3:37...4:00` contrasts ordered frequency relationships with increasingly
metallic or dissonant off-ratio colour; `4:46...5:10` shapes that brightness
gesture with a pluck-like envelope; `5:31...6:42` applies the modulation envelope
to a two-oscillator acid voice and cautions against excessive brightness;
`7:02...8:00` compares hollow ordered and metallic off-ratio outcomes; and
`9:42...10:27` varies the existing note pattern while retaining the same sound
relationship. Exact workstation routing, device names, note patterns, and knob
positions are tutorial context, not engine requirements.

The capture returned exactly 50 top-ranked top-level comments and twelve
replies. The protocol's bounded reply fetch left one thread without its complete
reply context. There was no three-independent-comment convergence on an exact
ratio, modulation amount, envelope, or production target. One technically
relevant reaction cautioned that the result could accumulate low-frequency mud;
it is retained only as a risk hypothesis, not as a numeric rule. Praise, named
tracks and artists, device requests, and repeated replies were excluded. No
usernames or verbatim comment text are retained.

Repository reconciliation rejected a second sequencer, a new synth engine,
literal tutorial patch settings, a user-facing FM control, and any DAW or plug-in
dependency. The canonical palette already assigned `acidThread` and
`acidSequence` to Resonant Mono, but their renderer remained subtractive-only.
The missing reusable capability was therefore a score-owned spectral relation
inside that existing voice, with explicit evidence and exact neutral behavior
for the protected foundation.

Implemented clean-room translation: `acidThread` now expresses durable
`orderedHollow` intent and `acidSequence` expresses durable `metallicTension`
intent. The current renderer realizes those two semantics with one local
two-operator phase-modulation delta, respectively using an ordered `2:1` ratio
or an off-ratio square-root-of-two relationship. Existing bounded color and
motion automation derive the requested peak index. A literal-zero-endpoint sine
aperture opens and closes the index within each existing note, so no onset,
pitch, duration, density, transport, graph, continuation state, or user control
is added. A conservative four-sideband budget caps the applied index against
route rate and carrier frequency; two local 120 Hz high-pass stages constrain
the modulation delta before it joins the existing subtractive source. Non-acid
patches and both protected foundation patches take the exact zero-operator path.

Detached full rendering uses one pooled operator-measurement buffer and retains
only reduced evidence: acid assignment and event counts, ordered/metallic event
counts and ratios, requested/applied index extrema, a deterministic event
fingerprint, exact operator-tap hash, peak/RMS/crest, low-band energy ratio,
binding validity, and finiteness. Candidate-vector schema 11, quality-contract
schema 12, and canonical engine `autotechno-canonical-engine.v12` identify this
implementation. The typed plan-fingerprint domain remains v7 because the
resolved score shape did not change. Shipping selection remains
`uncalibrated.v1`; physical operator metrics can reject broken provenance but
cannot rank or promote the sound.

The future-maturation boundary is explicit. Durable concepts are the existing
patch ownership, ordered-hollow versus metallic-tension intention, bounded
dark-to-bright-to-dark gesture, neutral foundation fallback, deterministic
continuation, and same-pass evidence owner. Provisional implementation v1 is
the exact `2.0`/square-root-of-two ratio table, automation-to-index formula,
four-sideband cap, 120 Hz two-stage high-pass, `0.05`/`0.065` blend, and local
operator phase. A serious later DSP may introduce oversampling, higher-order or
multi-operator structures, improved anti-aliasing, richer envelopes, nonlinear
feedback, stereo-safe upper harmonics, or perceptually calibrated low-band and
crest bounds. It must preserve the durable score semantics and fallback, remain
off the real-time callback, emit truthful replacement evidence, and advance the
engine/schema identity before qualification.

Validation proved the ordered and metallic relations at 8, 44.1, 48, and
192 kHz; exact-zero event endpoints; finite, distinct PCM; neutral non-acid
operator taps; canonical-session reachability; deterministic render replay;
complete reduced bar evidence; compact JSON/fingerprint/tamper rejection; and
one real selected-primary prepared transaction. The complete 166-test local
workflow matrix and optimized release build passed. The first two-rate offline
qualification correctly rejected the provisional `0.20`/`0.26` blend because
the establishment-to-long-continuation RMS-trajectory peak delta fell outside
the frozen engine-v10 relationship at both rates. The renderer-owned blend was
reduced without changing the score semantics or requested operator relation.
The exact 44.1/48 kHz rerun then accepted all 14 observations under the frozen
profile, generated complete engine-v12 profile fingerprint
`374bf5cdfe333f89`, and rejected all ten adversarial cases under suite
fingerprint `665feb5625ad608f` in 3,043.276 seconds. Publication, exact-head CI,
listening, app/route validation, and hardware soak remain separate gates.

## Video-derived effect-sentence consolidation study — 2026-08-12

Observation source: Underdog Electronic Music School's
[“What are ‘techno phrases’?”](https://www.youtube.com/watch?v=mLhpTlGOmCE)
(uploaded 2023-05-01, duration `6:35`, accessed 2026-08-12). The bounded source
capture used unauthenticated `yt-dlp` without account, cookies, or browser state:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source16-research -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=mLhpTlGOmCE'
```

No manual subtitle track was available. The downloaded automatic English `en`
and `en-orig` VTTs were byte-identical, each with SHA-256
`6b043318c276c987e65beb27b0d7d8870be449447020593849b0d544bcea334f`.
The metadata and comment artifact had SHA-256
`b1cdac46ce897508ea748ec7b4819141645b84cc6991af39b3ab9f8dc79a9846`.
A temporary audio-only capture had SHA-256
`0c3c8195eab88b11f7150549a0602dec978eedd293c809d9eaf4e34bc9663728`;
bounded excerpts around the phrase demonstration and dynamics chapter were
inspected locally, and no media or reconstructable audio entered the repository.
The mixed tutorial audio measured `-19.0 LUFS` / `6.7 LU` / `-5.2 dBTP` over
`1:59...2:28` and `-20.1 LUFS` / `9.5 LU` / `-5.4 dBTP` over
`3:48...5:07`. Voice, music, edits, and demonstrations are inseparable in those
windows, so the measurements are contextual provenance rather than engine
targets or proof of an upward-compression benefit.

The bounded transcript paraphrase is: `0:10...1:08` proposes timbre and effects
as foreground speech when a note-changing melody would compete with a
drum-focused track; `1:08...1:52` describes a phrase as a call, delayed response,
and end turnaround across a short section; `1:59...2:27` demonstrates that
relationship; `2:30...3:42` says the source may be any sound and demonstrates
manually duplicating, processing, and selecting effect layers; `3:50...5:06`
uses upward compression to expose quiet effect body while retaining the louder
attack; and `5:06...5:50` returns to the speech analogy and the cost of diverting
attention from the drums. Literal workstation duplication, random effect
selection, presets, device settings, and manual curation are tutorial context,
not autonomous-engine requirements.

The capture returned exactly 50 top-ranked top-level comments and five replies.
Independent comments repeatedly supported the broader non-melodic framing:
sound as moving sculpture, phrase thinking without conventional melody, and
deeper conceptual understanding over another recipe. That is convergence on a
way of hearing, not on a DSP topology or number. One top-level comment named a
specific upward/downward dynamics device; it is single-source workflow advice
and was rejected. Praise, creator names, tracks, courses, gear requests, and
algorithm comments were excluded. No usernames or verbatim comment text are
retained.

Repository reconciliation produced a deliberate no-new-DSP result. The
canonical score already owns motif, response, and transition roles; narrative
presence and supporting-role admission already coordinate phrase speech;
unsynced echo, pulse echo, filtered long reverb, and the bounded gated
percussion return already supply delayed consequences; structural gestures own
turnaround and closure; and the pulse-echo return-drive already provides a
score-owned, evidenced low-level body lift outside feedback. Adding an
`EffectPhrase` state, another delay/compressor, random duplicated layers, or a
parallel effect renderer would split those owners without exposing a new
measurable deficit. Source 16 therefore consolidates the concept instead of
changing PCM, schemas, policy, graph, continuation, or callback work.

The durable concept is now indexed in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md): timbre and effects
may form a call/response/turnaround sentence while the drums retain attention
priority. The current implementation is explicitly provisional and distributed
across the existing canonical owners above. A later serious DSP revision may
add true upward or parallel dynamics, denser diffusion, spectral morphing, or a
shared-return orchestration only after phrase-level effect-body and role-causal
evidence expose a repeatable deficit. It must replace or consolidate current DSP,
preserve deterministic score ownership, protected rhythm, continuation, exact
fallback, and the one-runtime contract, and advance the relevant identities
before qualification.

The user-authorized Antigravity advisory could not run: the managed execution
environment rejected sending the design prompt to an external CLI because it
might expose private workspace context. The guard was respected without retry
or workaround. Local validation for this documentation-only consolidation is
recorded separately; no listening, app/route test, hardware soak, or
professional-quality promotion is implied.

## Video-derived rising cluster transition study — 2026-08-12

Observation source: Underdog Electronic Music School's
[“What's the opposite of harmony?”](https://www.youtube.com/watch?v=Rc4VBxUb97A)
(uploaded 2023-05-08, duration `4:17`, accessed 2026-08-12). The bounded source
capture used unauthenticated `yt-dlp` without an account, cookies, or browser
state:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source17-research -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=Rc4VBxUb97A'
```

No manual subtitle track was available. The automatic English `en` and
`en-orig` VTTs were byte-identical, each with SHA-256
`89ca02cc3dd6af08c0f04027d86552903ce660fd1615a86a620bd2768c653860`.
The metadata and comment artifact had SHA-256
`8227b847e82c81febe9c59aa9c0ffcc79516f43d67e570c5e21e184d4d00adf9`.
A temporary 48 kHz stereo PCM demonstration capture had SHA-256
`f21059671b1b2489b24ad082e1fb30240ed7880dff7f7302708189a427ae4de4`;
media, comments, captions, and local inspection files remain untracked. The
mixed voice/tutorial window measured `-19.3 LUFS` / `4.4 LU` / `-4.9 dBTP`
over `0:45...1:22`, and the later sound-design/continuous-rise window measured
`-22.7 LUFS` / `10.3 LU` / `-5.1 dBTP` over `2:36...3:25`. These inseparable
tutorial mixes are contextual provenance, not engine targets or proof of a
cluster's quality.

The bounded transcript paraphrase is: `0:00...0:45` rhetorically contrasts
stable mathematical pitch relationships with dissonance; `0:45...1:20`
demonstrates adjacent tones as one tension-producing cluster; `1:20...2:02`
extends that object over several bars and raises it as a group; `2:02...2:33`
shows one workstation-specific pitch-bend recipe; `2:36...3:12` transfers the
idea to string-like material and lengthens the phrase when a shorter loop feels
overexposed; and `3:12...3:24` mentions overlapping rising layers. Literal
device settings, random note copying, the named pitch-bend range, string
emulation, and an endless auditory illusion are context rather than autonomous
engine requirements.

The capture returned exactly 50 top-ranked top-level comments and eight replies.
Multiple independent technical suggestions converged only on the broader
principle of beginning from a stable relationship and gradually bending,
detuning, or spectrally warping components apart. They did not converge on one
interval, oscillator count, device, or numeric target. One correction noted
that dissonance remains a relationship inside harmony rather than a literal
opposite; the implementation therefore names a rising adjacent cluster and not
an “anti-harmony” mode. Named tracks, artists, devices, plug-ins, personal names,
praise, and whole comment text were excluded.

Repository reconciliation rejected another sequencer, random pitch selection,
a user-facing dissonance control, a separate string engine, and an infinite
Shepard process. The canonical score already owns a transition event and its
upward frequency trajectory, while the existing Metal Veil patch already owns
spectral-texture transition PCM. The missing reusable capability was a durable
close-cluster relation inside that assignment plus exact evidence that the
transition alone reached the intended signal.

Implemented clean-room translation: a Metal Veil assignment derives
`risingAdjacentCluster` only when its canonical use is `transition`. The existing
three spectral-texture phases then use one provisional root/one-semitone/
two-semitone component bank and the already resolved transition glide. Component
frequency remains below the existing `0.12 * sampleRate` ceiling. The existing
onset, duration, trajectory, filters, drive, spatial effects, score density,
continuation, and transport do not change. Metal Veil response and atmosphere
assignments remain on their bit-identical legacy path, and the conservative
transition remains the existing Dark Chord assignment with no cluster tap.

Detached full rendering adds one pooled isolated cluster buffer and retains only
reduced evidence: cluster assignment/event counts, durable relation, exact
component ratios, applied start/end-frequency range, event fingerprint, exact
dry-cluster hash, peak/RMS/crest, binding validity, and finiteness. Candidate-
vector schema 12, quality-contract schema 13, and canonical engine
`autotechno-canonical-engine.v13` identify the PCM and wire-format change. The
typed plan fingerprint stays at v7 because the resolved score shape is unchanged.
Shipping selection remains `uncalibrated.v1`; the new evidence can reject broken
provenance but does not rank or promote this timbre.

The maturation boundary is recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). Durable concepts
are transition ownership, one coherent rising close cluster, unchanged density,
neutral conservative fallback, deterministic continuation, and isolated
same-pass evidence. Provisional v1 details are the exact three ratios, weights,
phase bank, and current spectral-texture filtering. A serious later renderer may
replace them with oversampled or band-limited oscillators, microtonal spreading,
physical string/resonator models, controlled divergence/reconvergence, or
perceptually calibrated tension and harshness evidence. It must replace rather
than duplicate this path, preserve the durable score contract, advance affected
versions, and pass automated qualification.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated module caches, serial SwiftPM, and the process boundaries
from `.github/workflows/swift.yml`. The source-17 DSP, compact evidence, real
prepared reachability, and exact-fingerprint filters passed 4/4. The complete
core/evidence partition passed 122/122 in 159.697 seconds; split upper and
prepared-product filters passed 19/19; preparation preflight passed 22/22 in
501.640 seconds; protected routing passed 7/7 in 68.933 seconds; and the
optimized `AutoTechno` product build passed in 39.16 seconds. The full
representative 44.1/48 kHz journey then accepted all 14 observations under the
unchanged frozen engine-v10 development policy. The regenerated engine-v13
profile fingerprint was `2b884831d682f6d9`; all ten adversarial cases were
rejected under suite fingerprint `cc753a8f5161fbb3`; the explicit run passed in
2,957.112 seconds.

This validates deterministic development evidence, not subjective sound or
release readiness. No matched-loudness listening, exact-build app playback,
physical route/interruption smoke, representative latency/peak-memory budget,
or hardware-output soak was performed. Shipping selection remains
`uncalibrated.v1`, paired selection remains disabled, and no professional-
quality promotion is claimed.
