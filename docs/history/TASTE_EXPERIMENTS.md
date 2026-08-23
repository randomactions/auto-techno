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

## Source 18: release-boundary envelope expansion — 2026-08-12

Source ID `18` used YouTube video `JkPxjdfEYCc`, *An easy trick Bicep uses to
make their sounds more epic*, from Underdog Electronic Music School, published
2023-04-03 with a 3:47 duration. The clean-room capture used unauthenticated
`yt-dlp` with automatic English captions, metadata, and top-ranked comments:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source18-research.DISeAr -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=JkPxjdfEYCc'
```

No manual subtitle track was available. The automatic English `en` and
`en-orig` VTTs were byte-identical, each with SHA-256
`4068d226b8ce01e2306b7f6e634c666a421c6a92b86277fd4079d528cac73e97`.
The metadata and comment artifact had SHA-256
`32b797c9e0a2d0f34f8615459b1afacedf24daaba7945be2b714e3a4303bafcf`.
A temporary 48 kHz stereo PCM demonstration capture had SHA-256
`fce1466a22191111ac2771900263bc3b8d08a7f046c6208be12214c3a6946dc9`;
media, comments, captions, and inspection files remain untracked. The tutorial
window `0:35...1:15` measured `-25.4 LUFS` / `5.3 LU` / `-9.0 dBFS` peak, and
the later demonstration window `1:15...2:55` measured `-19.6 LUFS` / `10.9 LU`
/ `-4.7 dBFS` peak. Those inseparable narration/music values are contextual
provenance, not engine targets or proof of envelope quality.

The bounded caption paraphrase is: `0:40...1:12` starts from a small, snappy
pluck and asks how the same sound can become larger at a break; `1:12...1:36`
lists filter, decay, release, delay, and reverb as common ways to build tension;
and `1:37...1:56` demonstrates the distinct idea of raising sustain and using a
long release so the same short gesture becomes a washed-out tonal splash at the
climax. Literal maximum sustain, workstation/device settings, artist emulation,
and the source mix are not portable requirements.

The capture returned exactly 50 top-ranked top-level comments and two replies.
No three independent technical comments converged on a reusable numeric or DSP
prescription, so comments supplied no design target. Named devices, plug-ins,
personal names, praise, whole comment text, and artist-copying instructions were
excluded.

Repository reconciliation rejected another reverb, another synth, a new note,
a user-facing macro, and literal maximum sustain. The canonical score already
owns the energy-release marker and Tonal Motion patch family; the missing
capability was a durable semantic relation allowing one familiar short gesture
to occupy that boundary at a larger temporal scale. `SynthPerformancePlan`
therefore marks only the final eligible retriggered Tonal Motion anchor at the
existing displaced-kick recovery marker as `sustainedWash`. It changes no onset,
pitch, duration, velocity, gate, assignment, effect route, density, or transport.
Conservative fallback and home-timbre correction are exact neutral.

Renderer realization v1 maps the relation to a bounded `0.68` sustain target
and `3.2x` release scale, capped at `0.92` and `2.4` seconds. The semantic
relation persists in render continuation and typed plan/state fingerprints.
Detached rendering uses one pooled isolated envelope-expansion tap and retains
only event identity, base/applied envelope facts, exact hash, peak/RMS,
attack/tail metrics, nonzero count, binding, and finiteness. Candidate-vector
schema 13, quality-contract schema 14, canonical engine
`autotechno-canonical-engine.v14`, and typed plan domain v8 identify the score,
PCM, continuation, and wire-format change. Shipping selection remains
`uncalibrated.v1`; the new record can reject broken provenance but does not rank
or promote the effect.

The maturation boundary is recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The durable
concept is the same gesture expanding in temporal scale at a score-owned release
boundary. The exact sustain target, release multiplier, caps, and ADSR are
provisional. A serious later renderer may replace them with a high-resolution
MSEG or exponential envelope, envelope-aware dynamics, oversampled tail colour,
or controlled diffusion only when calibrated tail/body and masking evidence
demonstrates a deficit. It must replace rather than duplicate the current path,
preserve the score relation, fallback, continuation, and evidence, advance
versions, and pass automated qualification.

Final local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
matched SDKs, isolated module caches, serial SwiftPM, and the workflow's process
boundaries. The focused envelope score/DSP/evidence and exact-fingerprint
checks passed 5/5; the complete CI-selected matrix passed 173/173 (19 split
upper/transaction, 125 core/evidence, 22 preparation preflight, and 7 protected
routing); and a fresh optimized `AutoTechno` product build passed in 58.77
seconds. `git diff --check` was clean before publication.

The frozen professional profile and adversarial suite passed their normal
contract tests, but the opt-in 128-phrase two-rate calibration generator was
not run and no artifact was regenerated. No listening, exact-build app
playback, physical route/interruption smoke, representative latency/peak-memory
budget, hardware-output soak, or professional-quality promotion is claimed
here. Exact-head remote CI remains a separate publication gate.

## Source 19: foreground lead-performance timing — 2026-08-12

Source ID `19` used YouTube video `WZVd_JQMNfY`, *Bring your stale sounds to
life (in three steps)*, from Underdog Electronic Music School, published
2023-03-06 with an 8:18 duration. The clean-room capture used unauthenticated
`yt-dlp` with automatic English captions, metadata, top-ranked comments, and a
temporary audio extraction:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source19-research.KHkADu -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=WZVd_JQMNfY'
yt-dlp -f bestaudio -x --audio-format wav --audio-quality 0 --postprocessor-args 'ffmpeg:-ar 48000 -ac 2' -P /private/tmp/auto-techno-source19-research.KHkADu -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=WZVd_JQMNfY'
```

No manual subtitle track was available. The automatic English `en` and
`en-orig` VTTs were byte-identical, each with SHA-256
`2fe2c32ad068c8b0bf120a0adfc6a34a2fc85d68175997a3d19a07d71dbb24a7`.
The metadata/comment artifact had SHA-256
`bf53a49de11e16b0aa06f956e00d2f988289f2fa07d18b007b39eaea5415c49f`;
the temporary 48 kHz stereo PCM capture had SHA-256
`61848c94c524a915abe4c7020b33ab74c1b2d312ae3ad9632d540d088197eec9`.
All media, captions, comments, and inspection files remain untracked. The
capture returned exactly 50 top-ranked top-level comments and seven replies.
No three independent technical comments converged on a portable numeric timing
or DSP target, so community discussion supplied no coefficient.

The bounded caption paraphrase is: `0:25...2:24` contrasts the stable electronic
frame with recorded organic percussion; `2:24...5:08` recommends collaboration
and external feedback; `5:08...6:44` demonstrates a grid-based electronic
substructure complemented by one strongly played lead whose minor timing
inconsistencies carry intention, with partial quantization available when the
performance loses clarity; and `7:18...7:50` emphasizes intuition and jamming.
Literal recordings, user samples, collaborators, accounts, external reference
audio, and free-form human performance are outside the standalone autonomous
runtime and were not imported.

Repository reconciliation rejected another sequencer, random per-note jitter,
a background humanization LFO, recorded samples, another instrument, and timing
changes to drums or harmonic companions. The existing score and evidence already
own a 16-bar shadow/response harmonic cascade. The genuinely missing capability
was one mutually exclusive foreground relation: in a nonconservative melodic
lock during the home interlock chapter, the first retriggered anchor remains
exactly on-grid and later anchors alternate deterministic `0.018` and `0.036`
sixteenth-step delays. At 130 BPM these are about 2.1 ms and 4.2 ms. Note count,
base steps, pitch trajectory, gate duration, velocity, assignment, effects,
companions, drums, density, transport, and all protected-role offsets remain
unchanged. Conservative fallback and force-home correction are exact aligned.

The existing upper-timing transaction was extended rather than duplicated.
Its score/render/applied-gate fingerprints now also bind the timing relation and
performance character; an exact compact anchor-offset-pattern fingerprint
rejects arbitrary jitter; and the renderer supplies an isolated anchor dry hash,
peak, RMS, event count, and actual onset/gate outcome. Candidate-vector schema
14, quality-contract schema 15, canonical engine
`autotechno-canonical-engine.v15`, and typed plan domain v9 identify the score,
PCM, and wire-format change. Shipping selection remains `uncalibrated.v1`.

The maturation boundary is recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The durable
concept is a performed foreground line against an exact electronic frame. The
current two-tier rounded-frame delays are provisional. A serious later renderer
may replace them with fractional-delay scheduling and a higher-resolution
score-owned performance curve only after calibrated timing/attack evidence
exposes a repeatable deficit. That work must replace this realization, preserve
the relation, fallback, continuation, and evidence, and must not add free-running
jitter or another timing owner.

Focused validation before the final matrix proved natural canonical reachability,
an actual complete prepared primary transaction, exact offset replay, active-
versus-neutral anchor PCM change, companion/protected-rhythm identity, actual
scheduled frame/gate binding at representative rates, JSON round-trip, forged
pattern rejection, and unchanged uncalibrated selection evidence. Final matrix,
release-build, publication, and exact-head CI results are recorded separately
after completion; no listening, app/route smoke, hardware soak, or professional-
quality promotion is claimed by this source pass.

## Source 20: dramatic-debt climax provenance — 2026-08-12

Source ID `20` used YouTube video `dGGMbqe4QYQ`, *How to climax in electronic
music*, from Underdog Electronic Music School, published 2023-01-30 with a
10:31 duration. The clean-room capture used unauthenticated `yt-dlp` with
automatic English captions, metadata, top-ranked comments, and temporary audio:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source20-research.uYD2a8 -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=dGGMbqe4QYQ'
yt-dlp -f bestaudio -x --audio-format wav --audio-quality 0 --postprocessor-args 'ffmpeg:-ar 48000 -ac 2' -P /private/tmp/auto-techno-source20-research.uYD2a8 -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=dGGMbqe4QYQ'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`f1919b6a86400d7d18bf16e055f99ca51d6681543e357c98e0ec57195b524fac`.
The metadata/comment artifact had SHA-256
`a1dc24a5f0d58bcece7a702e154d2825f695afea2a6c8982b3952c55b31ad33c`;
the temporary 48 kHz stereo PCM capture had SHA-256
`6931dd63f42ce01f9c4707f3429b48cd25bbb42be41bf565102b5e510ca87028`.
All source media, captions, comments, and inspection files remain untracked.
The tool warned that its build was older than 90 days and lacked a JavaScript
runtime, but extraction succeeded.

The bounded caption paraphrase is: `0:33...2:28` distinguishes a small loop
ending from a committed turnaround that removes/adds material before restart;
`2:30...4:05` describes section-scale subtraction followed by a gradual energy
rise; `4:05...6:22` names fall, rise, and a short withheld-drop hang before the
return; `6:22...8:30` repeats that trajectory with a shorter second cycle; and
`8:30...9:52` warns that literal off-grid time insertion creates structural
complexity. The source's workstation operations, vocals, samples, exact effects,
and time-signature manipulation are not portable engine requirements.

The capture returned exactly 50 top-ranked top-level comments and seven replies.
No three independent technical comments converged on a portable target. One
comment suggested resetting the grid through a time-signature change after an
off-grid hang; that is a single workflow proposal and was rejected because the
product owns fixed sample-indexed transport. Another noted the difficulty of
returning from high to low energy; it remains a single dissent/deficit cue, not
a calibrated rule. Praise, jokes, gear discussion, names, and whole comments
were excluded.

Repository reconciliation found that the canonical director already owns the
durable musical behavior: contrast and major-break phrases open bounded dramatic
debts; energy release pays them; and the existing kick syntax expresses a
grounded setup, two withheld bars, and recovery without moving the grid. Adding
another break sequencer, another effect chain, a sample/vocal lane, or off-grid
transport would duplicate or violate those owners. The missing capability was
machine-readable long-form causality.

Candidate-vector schema 15 therefore adds one compact climax-arc record. It
fingerprints every exact incoming dramatic debt paid by a nonconservative
release, counts contrast and major-break sources separately, retains bounded
opening/due geometry, and cross-checks the existing four-bar kick consequence
when that score relation is present.
Debt-free, conservative, fallback, and non-release phrases remain exactly
inactive. Quality-contract schema 16 and canonical engine v16 identify the
wire-format change; score, PCM, transport, renderer, continuation, and shipping
selection remain unchanged and `uncalibrated.v1`.

The maturation boundary is recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The durable
concept is that a climax pays an earlier musical obligation. A serious later
renderer may replace the coarse phrase/debt and optional fixed recovery
realization with a calibrated multi-stage energy trajectory, higher-resolution
score envelopes, or role-aware payoff orchestration. It must preserve debt
ownership, future-boundary application, fallback, and causal evidence, and
replace rather than layer another climax mechanism.

Focused validation proved deterministic JSON/fingerprint round-trip, contrast
and major-break accounting, wrong-geometry and forged-debt rejection, unchanged
uncalibrated selection evidence, and a naturally prepared complete primary
energy-release transaction. The final local CI-selected matrix passed 174/174,
and the optimized `AutoTechno` product built successfully. Publication and exact-
head CI are recorded after completion. No listening, app/route smoke, latency or
peak-memory measurement, hardware soak, or professional-quality promotion is
claimed.

## Source 21: context-owned upper-percussion tail clearance — 2026-08-18

Source ID `21` used YouTube video `Sf97zdQMCv0`, *How to make sounds that
actually punch through the mix*, from Underdog Electronic Music School,
published 2023-02-06 with a 5:55 duration. The clean-room capture used
unauthenticated `yt-dlp` with automatic English captions, metadata, top-ranked
comments, and temporary audio:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source21-research.0wqJef -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=Sf97zdQMCv0'
yt-dlp -f bestaudio -x --audio-format wav --audio-quality 0 --postprocessor-args 'ffmpeg:-ar 48000 -ac 2' -P /private/tmp/auto-techno-source21-research.0wqJef -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=Sf97zdQMCv0'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`24bfa4be946d48965b122c71de4ac440b46bc8bd2a5ce80587b3209eb76309f3`.
The metadata/comment artifact had SHA-256
`5b5817c87d747b5aad223bfcd74f538fab36b3553d8db9bc58f55c017802a373`;
the temporary 48 kHz stereo PCM capture had SHA-256
`df2817d909dd0d433e54c9a9d998eb2f1e86a1870691254273ecc8fe20cfb3ea`.
All source media, captions, comments, and inspection files remain untracked.
The capture returned exactly 50 top-ranked top-level comments and four replies.
No three independent technical comments converged on a portable numeric tail,
envelope, or masking target, so community discussion supplied no coefficient.

The bounded caption paraphrase is: `0:00...1:00` contrasts unmanaged percussion
duration with a tightened loop; `1:01...1:11` explicitly treats the preferred
amount as stylistic rather than universal; `1:30...1:58` motivates shortening
tails when other material needs room while rejecting a rule that everything
must be short; `2:00...3:40` surveys workstation-specific ways to alter decay,
release, and ambience; and `3:49...5:33` demonstrates that a short transient can
sound plain alone yet function more clearly inside a mix. Literal workstation
controls, samples, named devices, tutorial numbers, and external plug-ins are
not portable engine requirements.

Repository reconciliation considered both reuse and expansion. A new
percussion lane, instrument, sample source, ambience return, or independent FX
chain would not better express this source: the claimed relationship concerns
the duration of already present clap, open-hat, and metallic events. The
canonical score already owns their admission, focus, and intentional pileup.
The selected capability therefore reuses those exact events and introduces one
post-arbitration semantic role, `naturalBody` or `foregroundClearance`.
Clearance is active only when another score role owns the foreground, the phrase
is not identity return, and the bar does not intentionally pile roles together.
No onset, event count, intensity, pitch, instrument, send, transport, or random
draw changes.

The detached renderer preserves the first 8 ms of each existing voice exactly,
then applies one state-free raised-cosine release ending at a multiplier of
`0.25`. Neutral is bit-identical and signed zero is preserved. Event-local
evidence binds score and render identity, frame geometry, full and attack hashes,
peak/RMS, attack and tail RMS, tail-to-attack dB, difference RMS, finiteness, and
protected/full pass equality. The compact candidate retains every bar and at
most four events per bar. The professional observation adds the clearance-event
ratio and mean rendered tail-to-attack dB; a dedicated adversarial case rejects
a forged runaway clearance tail. The change owns no continuation buffer and
adds no callback work.

The durable intention and maturation boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The first
raised-cosine realization is provisional. A serious later renderer may replace
it with material-aware MSEGs, coupled cymbal/body models, or envelope-aware
multiband or dynamic release after the calibrated primary evaluator exposes a
repeatable clearance or natural-body deficit. The replacement must preserve
the score role, neutral and attack behavior, event ownership, deterministic
evidence, and one canonical path; it must replace rather than layer another
tail controller.

Release-mode artifact generation then accepted all 392 development observations
from 28 complete journeys, rejected all 24 adversarial cases for their expected
non-compensable reasons, and accepted all 56 observations from four disjoint
holdout journeys with zero relationship failures. The resulting v4 profile,
adversarial, and holdout identities are `4f7a91a51691f923`,
`4c75434aa7d3866f`, and `97be23f446c25611`. The local process-isolated matrix
passed all 338 selected test executions, the callback-symbol audit found only
`memcpy`, and the optimized product built. This is automated implementation and
qualification evidence, not a listening result, app/route test, or hardware
soak.

## Source 22: protagonist spectral reveal — 2026-08-18

Source ID `22` used YouTube video `ByjKEl_uO9g`, *The Fred Again.. phenomenon
(5 lessons)*, from Underdog Electronic Music School, published 2023-01-23 with
a 16:14 duration. The clean-room capture used unauthenticated `yt-dlp` for
metadata, automatic English captions, top-ranked comments, and temporary audio:

```sh
yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source22-research.EMOAAV -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=ByjKEl_uO9g'
yt-dlp -f bestaudio -x --audio-format wav --audio-quality 0 --postprocessor-args 'ffmpeg:-ar 48000 -ac 2' -P /private/tmp/auto-techno-source22-research.EMOAAV -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=ByjKEl_uO9g'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`96e9778781ea6b46b07a7b981bc72778f3f0ec287c287b26089eac7c98e7d804`.
The metadata/comment artifact had SHA-256
`f436469a09d668a22a0849d984e5706e881b25dde680bfc834e8ff085d3fd20e`;
the temporary 48 kHz stereo PCM capture had SHA-256
`a4b0b10a47199996fb1ac228f7fbd862968641c4faf5c333f6c4f81b977befdb`.
Current YouTube media delivery required yt-dlp's official PO-token workflow
through a temporary localhost provider. The provider was stopped after the
capture, and all source media, captions, comments, token artifacts, and audio
inspection files remain untracked.

The bounded caption paraphrase is: `0:14...1:23` uses a sustained degree to
establish context; `1:23...3:11` lets a complex hook's rhythm arrive behind a
low-pass veil before disclosing its detail; `3:11...4:00` coordinates the hook
with kick motion; `4:00...6:58` uses weak pre-kick positions as rhythmic
pockets; `6:58...8:33` removes an established anchor before restoring the
frame; `8:33...10:18` values spontaneous human capture despite roughness; and
`10:18...15:29` uses four-note colour to make harmony less uniform. Source
samples, presets, workstation operations, creator identity, and tutorial
numbers are not engine requirements.

The capture returned exactly 50 top-ranked top-level comments and eleven
replies. Four independent top-level comments converged on intimacy or
spontaneity rather than capture polish. That supports the durable performance
hypothesis, but the standalone product has no microphone, imported vocal, or
account boundary. A synthetic lo-fi vocal lane would imitate the tutorial's
workflow without its cause. No comments established a portable filter,
sidechain, timing, or harmony coefficient.

Repository reconciliation considered both reuse and expansion. Existing
owners already cover the source's sidechain relationship, weak-pulse pockets,
kick withholding/recovery, modal four-note harmony, and atmospheric context.
A second drum pattern, sidechain, chord track, vocal source, or effect bus
would duplicate those owners. The missing capability was narrower: the
existing protagonist could gain presence, but its hidden-to-revealed filter
movement was not a score-owned relation shared by its two foreground synth
architectures.

Source 22 therefore adds `UpperSpectralRevealRelation` to existing anchor
notes. In naturally emerging lock or contrast bars, the current Resonant Mono
or Tonal Motion protagonist uses aperture `0.45 + 0.55 * presence^2` on its
existing cutoff. Supporting roles, notes, rhythm, velocity, patch, sends,
transport, density, random state, and effect topology are unchanged. Home
branches to the exact prior cutoff, and evaluator-owned correction resolves
the same eligible bar to literal home. No track, instrument, effect return,
continuation buffer, callback state, or UI control is added.

Same-pass architecture-local evidence retains independent score/render event
counts and fingerprints, active-event and aperture facts, actual cutoff
extrema, and the isolated anchor hash/peak/RMS. Candidate-vector schema 22
requires that record on each applicable existing protagonist architecture and
rejects decoded cutoff or binding forgery. The professional observation adds
an event-weighted active ratio and applied-cutoff ratio; a dedicated
adversarial case rejects a cutoff that escapes the calibrated reveal range.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). A later serious
renderer may replace the scalar aperture with a higher-order score trajectory,
multiband or formant-safe morph, or a better oversampled filter only after
calibrated legibility, masking, or artifact evidence exposes a repeatable
deficit. It must preserve the protagonist, exact home path, sends, role and
score ownership, and causal evidence, and replace rather than layer another
reveal chain. Focused validation proved natural reachability,
representative-rate cutoff bounds, exact home behavior, same-bar isolated
anchor PCM change, complete prepared evidence, decoded cutoff-forgery
rejection, and correction-owned eligibility retention. Release-mode artifact
generation then accepted all 392 development observations from 28 complete
journeys, rejected all 25 adversarial cases for their expected non-compensable
reasons, and accepted all 56 observations from four disjoint holdout journeys
with zero relationship failures. The resulting v5 profile, v6 adversarial,
and v4 holdout identities are `a4f10f84996591bb`, `533141d901ed71c6`, and
`de7f4ca2dc3c94dc`. The broader local matrix passed all 346 workflow-selected
test executions across 31 serial process boundaries; the realtime producer
symbol audit found only the allowed copy primitive and the optimized
`AutoTechno` product built. Publication and exact-head CI are recorded
separately after completion; no listening, app/route smoke, latency or
peak-memory measurement, or hardware soak is claimed by this source record.

## Source 23: percussion anticipation into an owned release — 2026-08-19

Source ID `23` used YouTube video `pQJm66oAsG4`, *The way out of the
8-bar loop*, from Underdog Electronic Music School, published 2022-10-17 with
a 7:52 duration. The clean-room capture used an isolated yt-dlp environment,
the official local PO-token provider required by current YouTube media
delivery, automatic English captions, metadata, top-ranked comments, and
temporary audio:

```sh
/private/tmp/yt-dlp-source23-venv/bin/python -m yt_dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source23-research.7tB6iQ -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=pQJm66oAsG4'
/private/tmp/yt-dlp-source23-venv/bin/python -m yt_dlp -f bestaudio -x --audio-format wav --audio-quality 0 --postprocessor-args 'ffmpeg:-ar 48000 -ac 2' -P /private/tmp/auto-techno-source23-research.7tB6iQ -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=pQJm66oAsG4'
```

The capture itself records yt-dlp `2026.03.17`; the tool was upgraded after
capture to `2026.07.04` for subsequent sources. No manual subtitle track was
available. Automatic `en` and `en-orig` VTTs were byte-identical with SHA-256
`fd6070ae1a994f7a5c5ca7ee5b666193318a397e9ca18028a6e6c3d5be523617`.
The metadata/comment artifact had SHA-256
`7095c8353e703ff5c47dd0e0efcef7b2acb52a09cc6fd1985cf015bb5878c45d`;
the temporary 48 kHz stereo PCM capture was 472.038458 seconds and had SHA-256
`3fa33ac2f492d1e4655a11c65d68dd0c4eebd679a00ba617a82ce32a50bdc1e8`.
The provider was stopped after capture, and all source media, captions,
comments, token material, and inspection images remain untracked.

The bounded caption paraphrase is: `0:32...1:58` starts from one stable loop,
duplicates its frame, removes low rhythm and bass through the middle, then
restores the full frame; `2:00...2:38` names tension and anticipation as the
reason the return feels consequential; `2:45...4:04` develops the release as a
memorable event rather than another repetition; and `4:10...6:56` builds a
reverse-reverb gesture by rendering a broad wet tail, reversing it, removing
the source transient, and letting the crescendo disappear at the arrival.
The optional band-pass demonstration supports evolving spectral occupancy, not
a portable cutoff, duration, send, or gain coefficient.

As a bounded audio-demo check, four consecutive 4-second windows from
`5:50...6:06` were high-pass inspected and measured approximately `-29.77`,
`-27.58`, `-24.06`, and `-24.92` dBFS RMS. The trajectory supports a broad
rise in upper-band energy before the arrival; it does not make the source's
filter, level, duration, or exact curve portable to the engine.

The capture returned exactly 50 top-ranked top-level comments and fourteen
replies. Six independent top-level comments converged on spreading core sounds,
preverb or reversed delay, melodic foreshadowing, a short silence, or a reverse
tail as ways to make an arrival feel prepared. That supports the general
anticipation relationship. It does not establish a numeric reverb, filter,
feedback, or level target, and workstation operations or external effect names
are not engine requirements.

Repository reconciliation considered both reuse and expansion. A new riser
track, instrument, reverb engine, captured sample, or effect bus would duplicate
current owners and weaken causality. `KickSyntaxResolver` already owns the
grounded, two-bar-withheld, recovery arc; `PercussionEchoTextureResolver` and
its protected renderer already own one bounded filtered percussion return. The
demonstration's literal bass mute is not copied: the canonical foundation
behavior remains independently score-owned, and overriding it here would couple
two musical owners without a measured foundation deficit. The
missing capability was therefore a second semantic relation on that same
return. On only the second withheld energy-release bar at macro position 14,
one already-resolved weak percussion event anchors a one-step input window on
the existing protected percussion stem; the detached renderer reverses that
bounded wet tail and applies a raised-cosine
crescendo ending at exact zero on the already-owned release boundary. It adds
no onset, track, instrument, bus, transport state, random draw, continuation
buffer, callback work, or UI control. The established contrast `gatedEcho`
branch remains the same canonical path and retains its prior PCM behavior.

Same-pass evidence binds the semantic relation, kick-syntax role, input/output
geometry, protected input and return hashes, peak/RMS, early/late RMS and rise
dB, nonzero counts, exact-zero endpoints, and protected/full render-pass
equality. Candidate-vector schema 23 retains one record for every bar and
rejects wrong relation, geometry, score/render binding, flat active swell, and
nonfinite or oversized decoded input. The professional observation adds active-
bar ratio and early-to-late rise dimensions; a dedicated adversarial case must
reject a flattened release-rise metric. Exact home and ineligible bars remain
neutral, and the feature owns no additional continuation.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The first
reverse-wet/raised-cosine realization is provisional. A serious later renderer
may replace it with transient-aware reverse convolution, fractional or
multitap stereo delay, denser diffusion, spectral shaping, or controlled
nonlinear colour only after calibrated buildup, masking, or artifact evidence
exposes a repeatable deficit. The replacement must preserve the existing
percussion owner, kick-syntax release boundary, exact neutral and gated paths,
determinism, and causal evidence; it must replace rather than layer another
buildup chain.

Release-mode artifact generation accepted all 392 development observations
from 28 complete journeys, rejected all 26 adversarial cases for their exact
expected non-compensable reasons, and accepted all 56 observations from four
disjoint holdout journeys with zero relationship failures. The resulting v6
profile, v7 adversarial suite, and v5 holdout identities are
`e5dd5c31a2f52e0c`, `3bcabc8fb4118913`, and `4eae3a36734c295b`.
Focused score, DSP, representative-rate, prepared-transaction, malformed-input,
fingerprint, broader regression, release-build, publication, and exact-head CI
validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated caches
and serial process boundaries. All 351 workflow-selected test executions passed
across 31 processes, including the callback queue, live analyzer/controller,
candidate and artifact tampering, calibrated primary, adversarial, disjoint
holdout, atomic commit, representative-rate, core/evidence, preparation
preflight, and protected-routing groups. The realtime producer undefined-symbol
audit found only the allowed copy primitive, and the optimized `AutoTechno`
product built. Publication and exact-head CI are recorded separately after
completion. No listening, app/route smoke, latency or peak-memory measurement,
hardware soak, or professional-quality promotion is claimed.

## Source 24: rhythmic modulation of an existing pad — 2026-08-19

Source ID `24` used YouTube video `ixwUbj01dtY`, *Create movement with rhythmic
modulation*, from Underdog Electronic Music School, published 2022-09-19 with
an 11:48 duration. The clean-room capture used unauthenticated yt-dlp
`2026.07.04` for metadata, automatic English captions, and top-ranked comments:

```sh
/opt/homebrew/bin/yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source24-research.uZy2nQ -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=ixwUbj01dtY'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`1f0818654121625b1ca3b6c026bf18653bc6f35b1d21e142aee42b6e9b89a773`.
The metadata/comment artifact had SHA-256
`12fd50da3ff04f59b89a92141ea490efe854e436e37f7321058d9700361c3812`.
The capture returned exactly 50 top-ranked top-level comments and nine replies;
one top-level item was a channel promotion, leaving 49 independent comments.
Current YouTube media delivery returned HTTP 403 for the advertised audio
formats even after the official temporary PO-token provider supplied a valid
token, so this source has no audio-demo measurement. No cookies, signed-in
session, account, or browser state was used. The provider was stopped and all
captions, comments, token material, and research files remain untracked.

The bounded caption paraphrase is: `0:00...1:12` starts from a static pad and
argues for timbre motion that supports drum energy without adding notes;
`1:12...2:28` introduces step-shaped parameter movement as a way to make one
held sound rhythmic; `2:28...5:22` demonstrates a custom 16-step relation built
from a repeating three-sixteenth cell and rejects an unsuitable distortion
mapping by listening; `5:58...8:38` coordinates filter gating with a separately
moving wet-effect amount to create ghosted rhythmic detail; and
`8:38...10:38` treats modular routing as the means, not the musical requirement.
No displayed depth, offset, cutoff, delay, mix, or distortion value is portable
to the engine.

The comment sample converged on static pads reducing energy and sixteenth-note
gating or rhythmic modulation restoring movement, with several arrangement
variations. It did not establish a numeric target or require a particular
workstation device. The durable hypothesis is therefore score-owned parameter
rhythm on an existing sustained role, not another pattern lane or plug-in
emulation.

Repository reconciliation explicitly considered both reuse and expansion.
The canonical engine already owns a four-voice pad, minimal-motion harmonic
continuation, a pad low-pass path, a spatial-reverb send, bar time, and complete
phrase-composition evidence. A new pad instrument, sequencer, delay, FDN,
automation lane, or effect chain would duplicate those owners. Source 24 instead
adds one bounded `PadRhythmicModulation` value to the existing `PadVoicing`.
Naturally resolved major-break pads use the three-step relation only from macro
positions 8 through 14, so the latter half of the break gradually regains
rhythmic energy; minimalized and structural-marker gestures remain neutral.
Absolute bar modulo three owns phase, preserving the cell across phrase splits.

The detached renderer applies the relation only to the pad's existing low-pass
cutoff and existing spatial-reverb send. The v1 engineering scales are
`0.38 / 1.00 / 0.62` for filter movement and `0.72 / 0.85 / 1.28` for the send;
literal `1.0` remains bit-identical to the prior path. No note, pitch, chord,
gate, voice count, instrument, onset, transport, random draw, effect topology,
continuation buffer, callback work, or UI control is added.

Same-pass evidence binds the relation, absolute phase, exact 16-step pattern,
applied filter/send extrema, pad and send hashes/RMS, and streamed
active-versus-neutral difference RMS. Candidate validation replays the musical
context and rejects wrong section, gesture, macro position, phase, pattern,
flat consequence, nonfinite data, or render-pass mismatch. Professional
observation retains active-bar ratio plus mean filter-difference-to-pad and
spatial-difference-to-send levels in dB;
a dedicated non-compensable adversarial case rejects a disconnected filter
consequence.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The discrete
v1 projection is provisional. A later serious renderer may replace it with a
smoothed control-rate envelope, higher-order or nonlinear filter movement,
tempo-safe modulated diffusion, multiband send shaping, or a richer score-owned
modulation graph only after calibrated movement, masking, transition, or
artifact evidence exposes a repeatable deficit. The replacement must preserve
the existing pad owner, absolute-time phase, exact neutral path, deterministic
evidence, and one primary decision; it must replace rather than coexist with a
second modulation lane.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3. The complete
process-isolated workflow matrix passed 354/354 test executions, including the
five-rate active/neutral pad path, real prepared evidence, primary artifacts,
adversarial qualification, disjoint holdout, atomic commit, cancellation and
correction, Core/evidence, preparation preflight, and protected routing. A
post-review rebuild of the exact artifact/legacy group passed 13/13 after its
legacy-identity mutations were updated to the current schemas. The realtime
producer undefined-symbol audit found only the permitted copy primitive in both
local debug and release objects, and the optimized `AutoTechno` product built in
79.44 seconds. Publication and exact-head CI remain separate gates. No listening,
app/route/interruption QA, latency or peak-memory measurement, hardware-output
soak, or claim that the inaccessible source demonstration was heard is made.

## Source 25: dotted foundation rhythm — 2026-08-19

Source ID `25` used YouTube video `uVUjCXacvt0`, *Dotted basslines for deep
grooves*, from Underdog Electronic Music School, published 2022-09-12 with a
15:23 duration. The clean-room capture used unauthenticated yt-dlp `2026.07.04`
for metadata, automatic English captions, and top-ranked comments:

```sh
/opt/homebrew/bin/yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source25-research.vGWBQ3 -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=uVUjCXacvt0'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`56bf55e624c80afa39a67b844a34ad88bcd57092b4ee1fcabccdae247ed14170`.
The metadata/comment artifact had SHA-256
`2fbfbf8f49f5b6b5760d084e6dd74db00e4f1fc68745ead47c6419b79f16913f`.
The capture returned exactly 50 top-ranked top-level comments and ten replies;
one top-level item was a channel promotion, leaving 49 independent comments.
The advertised YouTube audio formats returned HTTP 403 during an unauthenticated
best-audio-to-WAV attempt, so this source has no audio-demo measurement. No
cookies, signed-in session, account, or browser state was used. Captions,
comments, metadata, and research files remain untracked.

The bounded caption paraphrase is: `0:00...0:42` introduces a dotted bass
relationship under an established four-to-the-floor frame; `0:42...1:36`
defines the durable timing relation as three sixteenth-note positions;
`2:02...3:12` separates that onset relationship from sound choice and favours
short, legible notes; `3:25...4:29` lets the relation cross the bar while
requiring a two-bar downbeat reset rather than a free-running clock;
`4:36...6:10` adds root and phrase-end harmonic variation without changing the
rhythmic identity; `6:21...7:35` treats swing and velocity as optional
articulation rather than prerequisites; `7:36...12:30` demonstrates several
possible sound realizations; and `12:30...13:35` keeps any spatial repeats out
of the sub range and distinct from the note cycle. No displayed oscillator,
filter, modulation, glide, unison, drive, delay, or mix setting is portable.

The comment sample converged on the dotted-eighth/three-sixteenth identity and
on filtering spatial repeats away from the low foundation. One isolated
layered-polymeter suggestion did not justify another bass track. The durable
hypothesis is therefore a bounded two-bar onset relationship on the existing
foundation, not a new instrument, sequencer, delay, reverb, or user-facing
mode.

Repository reconciliation explicitly considered both reuse and expansion.
The protected foundation route, Resonant Mono architecture, Bass Pluck patch,
score swing, TPT filter, ADAA nonlinear core, and private foundation evidence
already own the necessary sound and safety behavior. Source 25 adds one
`FoundationRhythmicRelation` to the canonical resolved score. Eligible
four-bar-aligned Lock pairs replace only their existing bass events with
complementary two-bar masks `0x8248` and `0x4824`, producing a continuous
three-sixteenth relation whose second bar restores the phrase boundary. Kick,
weak percussion, upper notes, transport, harmony, route topology, spatial
returns, continuation state, random draws, and the realtime callback are not
changed. Ineligible, incomplete, conservative, non-bass, non-foundation-focus,
omit, and occupied-step paths remain exact established behavior.

The existing Bass Pluck renders the relation dry and centered. Same-pass
evidence binds absolute bar and pair phase, score/render event counts and masks,
exact rendered start frames, dry foundation hash/peak/RMS, patch assignment,
full/protected pass equality, and candidate-plan identity. Candidate validation
requires either all-established bars or exact adjacent active pairs at the
canonical boundary. Professional observation retains active-bar prevalence and
mean active foundation crest factor; a non-compensable adversarial case rejects
impossible overpopulation. The primary evaluator remains the single canonical
decision owner.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The current
integer-grid onset projection is provisional. A later serious renderer may
replace it in place with sub-sample event scheduling, tempo-aware articulation,
more expressive score-owned pitch or envelope trajectories, improved Bass Pluck
synthesis, or carefully filtered spatial reinforcement only after calibrated
timing, masking, translation, repetition, or artifact evidence exposes a
repeatable deficit. The replacement must preserve the protected foundation
owner, two-bar phrase reset, exact neutral path, deterministic evidence, and one
primary decision; it must not coexist with a second bass sequencer or parallel
foundation track.

Validation and publication evidence is appended only after the exact source
snapshot passes its isolated local matrix and exact-head CI. No listening,
app/route/interruption QA, latency or peak-memory measurement, hardware-output
soak, or claim that the inaccessible source demonstration was heard is made.

## Source 26: progressive harmonic disclosure — 2026-08-20

Source ID `26` used YouTube video `ppYfaPp6YLM`, *How to hit people in the
feelings*, from Underdog Electronic Music School, published 2022-03-28 with a
7:48 duration. The clean-room capture used unauthenticated yt-dlp `2026.07.04`
for metadata, automatic English captions, and top-ranked comments:

```sh
/opt/homebrew/bin/yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source26-research.Nqz52f -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=ppYfaPp6YLM'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`f96cb415c3a734e8247b5442d767eda928065dc25966f025abc02321da464385`.
The metadata/comment artifact had SHA-256
`dca8c6bdae1a4979eb0b7a6ca9ba72c6cf9e6820ea187863cfb80624bc394f0b`.
The capture returned exactly 50 top-ranked top-level comments and 15 replies;
one top-level item was a channel promotion, leaving 49 independent comments.
Unauthenticated audio-to-WAV attempts resolved the public format list and tried
the advertised Opus stream, M4A stream, and combined MP4 stream, but YouTube
returned HTTP 403 for every media request, so this source has no audio-demo
measurement. No cookies, signed-in session, account, or browser state was used.
Captions, comments, metadata, and research files remain untracked.

The bounded caption paraphrase is: `0:00...0:32` proposes hiding a harmonic
progression and revealing it in progressively more informative stages;
`1:34...2:39` treats a multi-function chord backbone as shared harmonic context
without requiring every synth to play every chord tone; `4:27...5:28` keeps an
early tonic-stable introduction legible for mixing; `5:28...5:58` exposes a
two-state intermediate relation; `5:59...6:29` reveals the complete progression
for the emotional payoff; `6:30...6:51` permits bounded second-cycle variation;
and `6:51...7:10` contracts the harmonic information again when returning to a
beat-led section. The video's literal chord-number recipe is an example rather
than a portable harmonic target.

Two independent comments specifically connected the arrangement method to
escaping same-loop repetition and creating a journey, and one noted the value
of a stable introduction for DJ mixing. An isolated voicing comment suggested
spreading chord tones while avoiding spectral overlap, which the existing
four-voice minimal-motion pad already owns. Another isolated suggestion proposed
a separate second-cycle progression; it does not justify a parallel harmonic
identity. The sample did not contain three-comment technical convergence on a
numeric target, chord recipe, voicing, synth, or effect.

Repository reconciliation explicitly considered reuse and expansion. The
canonical engine already owns modal harmonic functions, one four-voice pad,
bounded inversions, minimal-motion voice leading, accepted harmonic
continuation, exact pad ratios, and same-pass pad PCM evidence. A new pad track,
instrument, chord sequencer, progression identity, or effect chain would
duplicate those owners. Source 26 instead adds one bounded disclosure stage to
the existing `PadVoicing`: first-half Lock pads retain tonic only, second-half
Lock pads expose a tonic/modal-colour relation, and Major Break pads reveal the
existing four-function vocabulary. The next Lock contracts to tonic again from
phrase geometry alone.

Eligible Lock bars with an already admitted atmosphere role now receive the
same single four-voice pad capability used elsewhere; they do not admit a new
role or track. The disclosure changes that pad's function, connected voicing,
and pitch ratios in its dependent arpeggiator. Each bar still has at most one
pad with the existing onset, duration, instrument, rhythmic-modulation, and
spatial topology contract. Arpeggiator rhythm/articulation, every
non-composition role, protected rhythm, transport, random draws, and the
realtime callback remain unchanged. The stage is typed score data; compact
candidate evidence replays its phrase-local geometry, allowed function, and an
exact score-to-render arpeggiator pitch fingerprint while the established pad
ratio/hash/RMS/peak record remains the causal renderer consequence.
Professional evidence retains revealed-bar prevalence and distinct function
count, with a non-compensable attack against impossible overpopulation.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). This discrete
v1 disclosure projection is provisional. A later serious harmony pass may
replace it with longer functional syntax, suspensions, passing tones,
tension-aware inversions, or a shared multi-role harmonic frame only after
calibrated predictability, tonal-tension, masking, or repetition evidence
exposes a repeatable deficit. The replacement must preserve the existing pad,
four explicit voices, accepted continuation, deterministic disclosure arc,
exact neutral path, and one primary evaluator; it must not coexist with another
progression or pad lane.

Local validation evidence is appended only after the exact source snapshot
passes its isolated matrix; publication evidence remains gated on exact-head
CI. No listening, app/route/interruption QA, latency or peak-memory measurement,
hardware-output soak, or claim that the inaccessible source demonstration was
heard is made.

Release-mode qualification regenerated the v9 primary artifacts from 32
complete cached 44.1/48 kHz trajectories. The resulting profile accepted
392/392 development observations from 28 journeys, the v10 adversarial suite
rejected all 29 cases for their exact expected reasons, and the disjoint
four-journey v8 holdout accepted 56/56 observations with zero relationship
failures and zero source-bank overlap. The shipping identities are profile
`94a506391e349fbb`, adversarial suite `2a243887182f60ca`, and holdout
qualification `0fcc5af37485633a`.

The exact local source snapshot passed the focused disclosure PCM, score, and
evidence tests; complete current-runtime, calibration, primary-readiness,
candidate-tampering, live-feedback, correction, route, rate, continuation,
modal, adaptive-session, Core/evidence, preparation-preflight, and protected-
routing groups; the debug and release callback-producer symbol audits; and the
optimized `AutoTechno` product build. Publication and exact-head CI remain
separate pending gates. Listening, app/route/interruption QA, latency or peak-
memory measurement, and hardware-output soak were not performed and are not
implied.

## Source 27: source-local kick dynamics — 2026-08-20

Source ID `27` used YouTube video `2P_Opp4a6iY`, *Why your mixes sound thin and
weak (probably)*, from Underdog Electronic Music School, published 2022-03-14
with a 6:36 duration. The clean-room capture used unauthenticated yt-dlp
`2026.07.04` for metadata, automatic English captions, and top-ranked comments:

```sh
/opt/homebrew/bin/yt-dlp --skip-download --write-auto-subs --sub-langs 'en.*,en' --sub-format vtt --write-info-json --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source27-research.jBZ4jh -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=2P_Opp4a6iY'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`db4f62b114720306fe566903fa6b871e1a2e105c6b95488e5a648f2f1a6f4048`.
The metadata/comment artifact had SHA-256
`408ba1ed65a1c23cae16f1089027505770d6d513a77a0a63e5997f0059f1d00e`.
The capture returned exactly 50 top-ranked top-level comments and 15 replies;
one top-level item was a channel promotion, leaving 49 independent comments.
Unauthenticated audio attempts tried the advertised Opus stream, M4A stream,
and combined MP4 stream, but YouTube returned HTTP 403 for every media request,
so the two introductory sound demonstrations were not heard or measured. No
cookies, signed-in session, account, CAPTCHA, or browser state was used.
Captions, comments, metadata, and research files remain untracked.

The bounded caption paraphrase is: `0:00...1:12` uses a kick waveform to show
that a narrow transient can consume limiter headroom before the audible body is
reached; `1:17...2:40` contrasts equal peak readings with unequal perceived
loudness and connects the difference to spectral distribution and upper-mid
sensitivity; `2:42...4:35` argues that source creation, mixing, and terminal
mastering are related stages and that the last stage should make only small
corrections; `4:36...5:09` returns to the kick and recommends controlling it at
the source rather than asking the master limiter to remove a large spike;
`5:09...5:43` asks for sufficient, balanced upper-mid presence rather than a
globally muffled mix; and `5:43...5:56` describes terminal EQ/limiting as small
finishing moves. The video's displayed meters and spoken decibel examples are
illustrative, not portable numeric targets.

Independent comments converged on two durable points. Multiple experienced
mix/mastering comments agreed that terminal mastering cannot rescue poor source
or mix decisions. At least three independent comments separately described the
crest-factor trade-off: unmanaged spikes consume headroom, some transient must
remain for punch, and light source compression/limiting/saturation is more
effective than heavy terminal processing. A low-mid-headroom comment and an
upper-frequency-saturation comment were useful but did not establish a
three-comment numeric or spectral target. No comment convergence justifies a
new kick sample, drum layer, mastering preset, compressor bus, or brightness
control.

Repository reconciliation considered both reuse and expansion. The canonical
engine already owns one resolved kick, pre-fader detector and post-fader audible
buses, kick-syntax absence/recovery, automatic mix, protected center routing,
linked two-band glue, terminal safety, first-order ADAA, exact per-bar hashes,
and a single primary evaluator. The kick body is locally saturated, but its
final body + sub + click sum reaches those buses without one complete-source
conditioning or pre/post source evidence. Source 27 therefore adds one fixed,
state-bounded first-order ADAA conditioner at that exact instrument boundary.
It does not add a track, instrument, effect return, master chain, candidate,
continuation buffer, or user control.

The same-pass evidence streams the event-local pre/post source without
retaining PCM and binds version/order, score/render count and masks, exact
hashes, peak/RMS/crest, physical-time attack/body RMS, upper-mid energy, full/
protected equality, detector/audible scaling, and explicit withheld silence.
Professional observation retains source crest, attack/body, spectral-presence,
and crest-reduction dimensions; a non-compensable transient-spike attack keeps
the single primary contract causal. The later master remains safety and glue,
not the owner of this correction.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). The v1 fixed
curve may later be replaced in place with oversampling or higher-order
antialiasing, transient-aware upward/parallel dynamics, a multiband source
contour, or richer physical kick synthesis only when calibrated source crest,
attack/body, upper-mid translation, alias, or master-work evidence exposes a
repeatable deficit. The replacement must preserve kick score/event geometry,
detector/audible ownership, protected center routing, exact withheld silence,
and one primary evaluator; it must not coexist with another kick track or
dynamics chain.

Implementation, calibration, and local validation are complete. Release-mode
artifact generation accepted 392/392 development observations from 28
journeys, rejected all 30 adversarial cases for their exact expected reasons,
and accepted 56/56 observations from four disjoint holdout journeys with zero
relationship failures. Independent generation against the same 32 cached
journeys produced byte-identical artifacts. The installed primary artifacts
are profile `6a16588407657191`, adversarial suite `3a9e13af0380a49b`, and
holdout qualification `c190edafab079602`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. It covered the independent source-DSP
oracle; exact artifact/runtime identity; candidate reduction and tampering;
adversarial, calibrated-policy, and disjoint-holdout qualification; Core and
evidence; preparation preflight; protected routing; instrument-render
partitions; realtime queue behavior and producer-symbol audits; and an
optimized product build. The hosted workflow was also divided into bounded
instrument-suite processes after a prior accumulated-process signal 10, without
changing the test contracts.

Publication and exact-head CI remain separate pending gates. No listening,
app/route/interruption QA, latency or peak-memory measurement, physical-output
soak, or claim that the inaccessible source audio was heard is made.

## Source 28: foundation pre-kick pocket — 2026-08-22

Source ID `28` used YouTube video `RKw-d6A4GOc`, *Rookie mistakes in techno*,
from Underdog Electronic Music School, published 2022-02-07 with a 22:48
duration. The clean-room capture used unauthenticated yt-dlp `2026.07.04` for
metadata, description, automatic English captions, thumbnail, and top-ranked
comments:

```sh
/opt/homebrew/bin/yt-dlp --skip-download --write-auto-subs --sub-langs 'en,en-orig' --sub-format vtt --write-info-json --write-description --write-thumbnail --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source28-research.fjYFWU -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=RKw-d6A4GOc'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`1a578e244e3d1079d5204c6e18330901278f357c9dd5d8bf69a3642fbfffb329`.
The metadata/comment artifact had SHA-256
`886d805075e419a6a7c96776611379c60a83a9dba05ca02dc6f25414e69a0cae`.
The sample contained 50 top-ranked top-level comments and 11 replies across
four substantive threads. Direct unauthenticated best-audio retrieval returned
HTTP 403. The retry used the yt-dlp EJS provider release 1.3.2 at exact commit
`7511309af023b09788dc8f2efc96cc3671291e6c` through a temporary localhost
provider, selected the advertised `251-8` media format, and converted it to
48 kHz stereo WAV. The resulting 1367.808-second local audio file had SHA-256
`2928571094ab7542fc2c1039dd1078f48eaef517803edc0bccf02313ae84a902`.
The provider, media, captions, comments, thumbnail, and analysis images remain
temporary and untracked; no account, browser cookie, or CAPTCHA was used.

The bounded caption paraphrase is: the opening material distinguishes tonal
balance from level balance; the central arrangement examples ask every element
to support one shared groove and make emphasized versus de-emphasized beats
coherent; a later low-end example uses a short absence before the kick to make
its priority clear; and the filtering discussion warns that indiscriminate
high-pass filtering can remove needed body. Literal meter positions, plug-in
moves, and monitoring advice are examples rather than portable runtime targets.
Machine inspection of the relevant local demonstration found sustained low-band
occupancy around the demonstrated kick. This is descriptive source evidence,
not a human listening or promotion claim.

Independent discussion converged on groove and role priority. Multiple comments
valued the explanation that a strong global pulse depends on relationships
between emphasized and de-emphasized events. A separate technically specific
thread cautioned that routine high-pass filtering can thin sources and weaken
the intended balance. The discussion did not converge on a numeric EQ target,
reference spectrum, new instrument, sidechain setting, or master preset.
Monitoring-room recommendations describe a development environment and are not
standalone-product runtime requirements.

Repository reconciliation considered both reuse and expansion. The canonical
engine already owns one kick clock, one protected Resonant Mono foundation,
exact complementary dotted masks, Bass Pluck, score swing, TPT/ADAA processing,
role-local masking/spectral evidence, and one primary evaluator. The dotted
Bass Pluck one sixteenth before kick 4 or 12 has a nominal body long enough to
cross the kick, so its PCM can erase the score's intended low-end pocket. A new
track, instrument, sidechain compressor, EQ, effect bus, controller, or master
target would duplicate those owners and contradict the source's contextual-
filtering caution. Source 28 therefore extends the existing dotted relation
with one Core-owned terminal-release articulation for that exact event.

The v1 release begins `0.1875` score step before the kick and reaches exact zero
`0.0625` step before it, leaving a positive route-derived dry-foundation
silence interval while preserving the onset mask, kick, every other role, and
the protected path. The curve is state-free and executes only during detached
rendering; it adds no random draw, buffer, persistent continuation, scheduler,
or callback work. Same-pass evidence binds the exact score event, natural end,
release/kick geometry, silence hash/peak/RMS, Bass Pluck assignment, and full/
protected equality. One upper-only safer professional metric and one
non-compensable contamination attack prevent unrelated strengths from hiding a
filled pocket.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). A later serious
renderer may replace the v1 two-point curve and exact-zero proxy in place with
envelope-phase-aware note shortening, transient-conditioned ducking,
fractional-step articulation, or a richer foundation model only after
calibrated masking, low-end hierarchy, or transient evidence exposes a
repeatable deficit. It must preserve the dotted score owner, exact neutral
fallback, protected route, deterministic continuation, causal evidence, and one
primary evaluator; it must not coexist with another bass or sidechain path.

Implementation, calibration, and local validation are complete. Release-mode
artifact generation accepted 392/392 development observations from 28
journeys, rejected all 31 adversarial cases for their exact expected reasons,
and accepted 56/56 observations from four disjoint holdout journeys with zero
relationship failures. A second invocation against the same 32 cached journeys
produced byte-identical artifacts. The installed primary artifacts are profile
`63b4173f9d08fdba`, adversarial suite `8fb2813d62791ba5`, and holdout
qualification `411b1fdd09995453`.

Local validation used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with isolated
caches and serial process boundaries. It covered the same-event active-versus-
neutral PCM oracle and exact correction replay; fresh bundled-artifact identity;
candidate reduction and tampering; adversarial, calibrated-policy, and disjoint-
holdout qualification; atomic commit, unavailable-route, cancellation,
correction, rejected-attempt, representative-rate, resource, and continuation
gates; the 117-test Core/evidence bank; 24 preparation-preflight tests; 14
protected-routing regressions; realtime producer-symbol audit; and an optimized
product build.

Publication and exact-head CI remain separate pending gates. No listening,
app/route/interruption QA, latency or peak-memory measurement, physical-output
soak, or claim that the source demonstration was heard by a person is made.

## Source 29: terminal climax hang — 2026-08-22

Source ID `29` used YouTube video `n3lvFEsf1O0`, *Two types of break for
electronic music*, from Underdog Electronic Music School, published 2021-05-31
with an 11:48 duration. The clean-room capture used unauthenticated yt-dlp
`2026.07.04` for metadata, description, automatic English captions, thumbnail,
and top-ranked comments:

```sh
/opt/homebrew/bin/yt-dlp --skip-download --write-auto-subs --sub-langs 'en,en-orig' --sub-format vtt --write-info-json --write-description --write-thumbnail --write-comments --no-clean-info-json --extractor-args 'youtube:comment_sort=top;max_comments=65,50,15,3,2' -P /private/tmp/auto-techno-source29-research.2zwH8P -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=n3lvFEsf1O0'
```

No manual subtitle track was available. Automatic `en` and `en-orig` VTTs
were byte-identical with SHA-256
`6d676ac24c73bbecff40510296f1c82c08f18f051f64e77adcb665da7370bf82`.
The metadata/comment artifact had SHA-256
`d57644090e0f44907f37f193bfa4dfcbc12ecaf94d5e4fb7b74a1c493d14d74b`.
The sample contained 50 top-ranked top-level comments and 12 replies across
seven substantive threads. Direct unauthenticated audio retrieval used the
yt-dlp EJS provider release 1.3.2 at exact commit
`7511309af023b09788dc8f2efc96cc3671291e6c` through a temporary localhost
provider and converted the result to 48 kHz stereo WAV. The resulting
708.480-second local audio file had SHA-256
`0e5f5de0846e3dfd8072ad109539388e3ab07c20121fe9db95103856332c8bae`.
The provider, media, captions, comments, thumbnail, and waveform images remain
temporary and untracked; no account, browser cookie, or CAPTCHA was used.

The bounded caption paraphrase is: a direct break reduces energy and then
returns it, while a larger three-part form separates a fall, a rise, and a
short hang before recovery. The hang is described as a perceptible absence or
nearly empty canvas after the rise, with the following return receiving the
structural emphasis. The closing warning is that this is vocabulary rather
than a formula to repeat indiscriminately. Literal track references, plug-in
moves, genre examples, and suggested multi-bar durations are examples rather
than portable runtime requirements. Machine waveform inspection of the local
linear and three-part demonstration windows found the expected reduced-energy
middle region followed by a renewed transient pattern; it did not establish a
universal silence duration or loudness target. This is source inspection, not
a human listening or promotion claim.

Independent discussion strongly valued the explicit energy-curve explanation
and the distinction between tension and release. One technically relevant
thread reported that using fewer existing musical parts made the three-part
shape more effective than stacking many effects. Another warned that treating
the shape as a fixed formula creates predictable arrangements. The discussion
therefore supports a rare score-owned relationship and bounded absence, not a
new riser library, impact track, break preset, or mandatory phrase template.

Repository reconciliation found that the canonical engine already owns the
source's fall and rise through dramatic debt, nonconservative energy release,
two kick-withheld bars, the existing percussion anticipation swell, and the
unchanged step-zero recovery. Adding another track, instrument, effect chain,
break sequencer, alternate renderer, or user control would duplicate those
owners. The missing capability was the hang itself: an explicit terminal
absence between the already-owned rise and recovery. Source 29 therefore
extends the existing climax arc rather than introducing another mechanism.

On only the final withheld energy-release bar at macro position 14, Core owns
one `terminalRecoveryDelay` articulation from score step 12 through 16. The
existing weak-pulse carrier is bounded to steps `[3, 7, 11]`, the existing
anticipation return ends at step 12, and detached rendering applies one 8 ms
raised-cosine full-mix release immediately before the boundary. The final beat
is exact zero, but voice, generated-graph, effect, and continuation state keep
advancing underneath; the next bar therefore restores the established recovery
without a reset or hidden tail discontinuity. All ineligible and evaluator-home
paths remain bit-identical neutral.

Same-pass evidence binds the exact score relation, macro position, weak-pulse
geometry, route-derived release and silence frames, pre/post/silence hashes,
release input RMS, exact-zero peak/RMS/nonzero count, post-hang/pre-live-master
identity, and recovery. Professional Evidence v15 adds one upper-only-safer
silence-RMS dimension, and adversarial suite v13 adds one non-compensable
contamination attack. Quality-contract schema 31, candidate-vector schema 29,
canonical engine v30, and primary evaluator/profile v12 bind the change as one
installed contract.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). A later serious
renderer may replace the v1 output projection in place with role-aware decay
choreography, transient-conditioned muting, tail-safe spectral evacuation, or a
higher-resolution tension/recovery envelope only after calibrated transition,
boundary, or payoff evidence exposes a repeatable deficit. It must preserve the
paid-debt kick owner, exact terminal absence, advancing continuation, unchanged
recovery, deterministic score/evidence, neutral fallback, and one primary
evaluator; it must not coexist with another break, silence, riser, impact, or
climax mechanism.

Release-mode artifact generation accepted 392/392 development observations
from 28 journeys, rejected all 32 adversarial cases for their exact expected
reasons, and accepted 56/56 observations from four disjoint holdout journeys
with zero relationship failures. A second invocation against the same 32
cached journeys produced byte-identical artifacts. The installed primary
artifacts are profile `7bb19b3a5572bb39`, adversarial suite
`81f1cb944e9de091`, and holdout qualification `b9274bf9c29d2858`.

Full local verification used Xcode 26.6 (`17F113`) and Apple Swift 6.3.3 with
isolated caches and serial process boundaries. All 375 workflow-selected test
executions passed across 38 processes, including upper score, callback queue,
live analyzer/controller, App coordination, candidate and artifact tampering,
calibrated primary, adversarial, disjoint holdout, atomic commit, correction,
unsupported and representative rates, continuation, instrument workflow,
Core/evidence 121/121, preparation preflight 24/24, and protected routing
14/14. A separate release-mode Source 29 focus passed 21/21, both debug and
release realtime-producer objects exposed only an allowed copy primitive, and
the optimized `AutoTechno` product built in 79.02 seconds. `git diff --check`
was clean before publication.

Hosted run `32586400063` subsequently passed Core/evidence 121/121 and the
isolated upper-percussion-tail DSP suite, then exposed a signal-10 harness
failure as Swift Testing entered a preflight test that prepares four complete
canonical transactions. The same contract now runs on XCTest's normal thread;
the filtered upper-tail command passed 6/6 locally after that harness-only
change. No musical source, rendered PCM, evidence schema, or evaluator policy
changed, and exact-head CI remains the publication gate.

Publication and exact-head CI remain separate pending gates. No listening,
app/route/interruption QA, latency or peak-memory measurement, physical-output
soak, or claim that the source demonstration was heard by a person is made.

## Source 30: score-owned pad amplitude gate — 2026-08-22

Source 30 analyzed Underdog Electronic Music School's *The trance gate
technique* (`DxyQNgNKUf8`). `yt-dlp` 2026.08.19 retrieved byte-identical
automatic-English VTT captions with SHA-256
`0fa8fc4f1ee49c4b24bfebb768ff9cd4cd1585e4c9926904ab7b0853bb4d28f1`,
structured JSON3 captions with SHA-256
`001a988bb693e413a8a14523bd78f3c84e03979ea21900426413a93507475fce`,
50 top-level comments plus 12 replies, and direct audio. The decoded 48 kHz
stereo WAV was 547.392 seconds with SHA-256
`56eb5ffbbb18b207fe5aa2f06d17c0c5d5916057193015c25e63b0707cae0f7e`.
The local Deno JavaScript runtime solved extraction without an account, cookie,
browser session, CAPTCHA, or token provider. All reconstructable source media
and discussion captures remain temporary and untracked.

The portable idea is independent amplitude rhythm applied to a sustained
space-filling source, with release controlling whether cells feel separated or
connected and effect placement determining how much space survives. Machine
inspection supported strong repeated level contrast but did not establish a
portable timing, threshold, pattern, release, or loudness target. Discussion
supported independently controllable rhythm and a retained spatial response;
it did not justify an audible trigger track, plug-in, or sidechain dependency.
This is source inspection, not a human listening or promotion claim.

Repository reconciliation selected the existing score-owned
`PadRhythmicModulation.threeStepPulse` rather than a new instrument, track,
sequencer, bus, or generic gate. Eligible latter-half major-break pads now use
the same absolute-time three-sixteenth relation for filter, existing spatial
send, and a closed/open/closed amplitude target. One route-derived 6 ms
raised-cosine edge stays inside the open sixteenth. Closed dry and send samples
are exact zero while all pad, filter, envelope, and spatial continuation keeps
advancing; neutral, home-correction, and ineligible paths preserve the prior
identity.

An initial disjoint-holdout pilot rejected the implementation because the
maximum of overlapping RMS-trajectory windows moved from `47.7546` to
`57.1160` dB across 44.1/48 kHz for seed `161803` at `majorBreak`, exceeding
the learned `7.6891` dB relationship bound. Changing the gate edge and lowering
the analyzer floor did not remove the drift, while the corresponding mean was
stable near `4.886`/`4.883` dB. Widening the bound from the seen holdout was
rejected. The policy instead retains the peak as a strict local and within-rate
trajectory dimension and uses the mean for cross-rate consistency; dedicated
causal evidence continues to require exact closed-step silence. Because that
pilot informed policy semantics, its holdout corpus was discarded and replaced
with four previously unseen seeds.

The replacement holdouts have source fingerprints `67231f6b675b5a6b`,
`9310a28010b2983a`, `98da9a98dd956daa`, and `0028f9f35214fa00` with no overlap
against the 28-journey calibration corpus. Release-mode generation accepted
392/392 development observations, rejected all 33 adversarial cases for their
exact expected reasons, and accepted 56/56 holdout observations with zero
relationship failures. A second generation from the complete cache produced
byte-identical profile, adversarial, and holdout resources. The installed
fingerprints are `e1fdcbe7241f9f50`, `8973cc31505dfb7c`, and
`b52070f9cb2231b4`.

All 376 workflow-selected local test executions ultimately passed across
serial process boundaries, including 83/83 Core/evidence tests, 38/38 upper
tests split into six fresh processes, 24/24 preparation preflight tests, and
14/14 protected-routing tests. Candidate tampering first exposed one stale
quality-state golden after the version advance; its 27 functional cases had
passed, and the exact corrected identity then passed 1/1. Both debug and release
realtime-producer objects imported only an allowed copy primitive, and the
optimized app built in 95.33 seconds. Publication, exact-head CI, listening,
app/route QA, and physical-output soak remain separate gates.

The durable intention and in-place replacement rule live in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). Higher-resolution
control envelopes, tempo-aware duty, transient-conditioned edges, multiband or
stereo-linked gating, nonlinear colour, and denser diffusion remain future
directions only when calibrated motion, masking, transition, or translation
evidence exposes a repeatable deficit. A mature rewrite must preserve the same
pad and three-step score owner, absolute phase, advancing continuation, exact
neutral behavior, causal evidence, and single primary evaluator; it supersedes
this projection rather than adding another trigger lane or gate effect.

## Source 31: response-owned upper harmonic tail — 2026-08-22

Source 31 analyzed Underdog Electronic Music School's published electrical-zap
Wavetable tutorial (`Fn7paYGwDCQ`). `yt-dlp` 2026.08.19 retrieved byte-identical
automatic-English VTT captions with SHA-256
`197265c30a66ba71c54bded4d2fc1cb3c22d769f9501952127d57ecc29f80f64`,
structured JSON3 captions with SHA-256
`03342dac0d28da6685f3099fbcab2d10a8904775e7d1d74bfe9a7367af71ac93`,
50 top-level comments plus 15 replies, and direct audio. The decoded 48 kHz
stereo WAV was 504.930 seconds with SHA-256
`9c8ac167a011e1c214f2f3415506139dde4f11035c6124955e5e35bbcf63a139`.
The local Deno JavaScript runtime solved extraction without an account, cookie,
browser session, CAPTCHA, or token provider. Reconstructable captions,
discussion, metadata, images, and source audio remain temporary and untracked.

The portable idea is that a low periodic source has closely spaced upper
partials that can become an electrical response when a driven resonant band
isolates only that tail and moves independently of note retrigger. Two technical
discussion threads independently reinforced the low-source/upper-harmonic
distinction, while one suggested nonlinear colour. Machine-only 8,192-point
inspection found approximate centroid/rolloff pairs of 5.0/8.9 kHz in the
band-pass demonstration, 5.1/9.0 kHz after colour, and 4.8/9.0 kHz in the cold
spatial example; its approximate energy was 16.2% above 5 kHz and 7.2% above
8 kHz. Speech, edits, and interface sounds contaminate those windows, so they
establish no copied cutoff, resonance, drive, modulation, or mix threshold.
This is source inspection, not human listening or artist imitation.

Repository reconciliation selected one new recognizable patch inside the
existing Spectral Texture instrument rather than another track, architecture,
effect chain, or renderer. Broken Suspension now owns the response-only Voltage
Arc assignment and durable `drivenUpperBand` relation. Its current realization
octave-folds the resolved note into a bounded low polyBLEP saw, applies bounded
prefilter colour, isolates the upper tail with a moving TPT state-variable
band-pass, keeps harmonic/filter/LFO continuation in the existing voice state,
and reuses the established response envelope and filtered-reverb send.

Same-pass evidence binds exact assignment/event counts, relation, folded-source
and center extrema, resonance, drive, LFO rate, isolated event/sample hashes,
peak/RMS/crest, low-band suppression, upper-band energy, and finiteness.
Candidate completeness fails closed for missing, misplaced, forged, out-of-
route, low-contaminated, or upper-disconnected evidence. Professional Evidence
v17 adds a higher-only-safer mean upper-band ratio and adversarial suite v15
adds one non-compensable disconnected-tail attack. The exact engine v32/profile
v14/holdout v13 regeneration accepted 392/392 development observations, all
34 adversarial cases rejected for their exact expected reasons, and 56/56
disjoint holdout observations with zero relationship failures. A cache-backed
repeat produced byte-identical artifacts: profile `9ad691f87acdcbaf`
(SHA-256 `2fe61c2a5fbb1062665bd9e54f2acb6ceafd1822e67812215ea4f6519cd8d772`),
adversarial suite `df4ec48aa47cfb3a`
(SHA-256 `716baeed0e320d7f70df0fe520a22d7815972a3fafb899f5b3559e98890079da`),
and holdout qualification `f0df34e6e76af2a5`
(SHA-256 `1a624459854c28ac9332aef15ed41eeead752492d187030a29395f9eb695fe72`).
The full serial validation matrix is recorded separately when complete.

The durable intention and explicit maturation boundary live in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). Oversampled
oscillator banks, higher-order antialiasing, nonlinear filter models,
envelope-followed motion, multiband diffusion, and stereo decorrelation are
future in-place replacements only after the primary evaluator exposes a
repeatable motion, harshness, masking, translation, or narrative deficit. A
mature rewrite must preserve the response-owned patch/relation, deterministic
continuation, exact causal evidence, one canonical renderer, and one primary
evaluator; it must supersede this v1 realization rather than coexist as a
generic zap effect.

## Source 32: fresh autonomous session identity — 2026-08-23

Source 32 analyzed Underdog Electronic Music School's *3 approaches to
subliminal modulation* (`KOVs5AarmUw`). `yt-dlp` 2026.08.19 retrieved
byte-identical automatic-English VTT captions with SHA-256
`07158c17072f329945e23779e2173cfdee1962b3ae537b7b2107b996939fe0fa`,
structured JSON3 captions with SHA-256
`2171cf2fbeaa6d8a09926681e02e5363254ec0b63fd4f3044fe88cf38efee646`,
39 top-level comments plus 10 replies, and direct audio. The decoded 48 kHz
stereo WAV was 749.877 seconds with SHA-256
`a0fbb03fb07b28e9b5bfe2f932a8c3c381fb90b26dc0fb364526689d46101901`.
The local Deno JavaScript runtime solved extraction without an account, cookie,
browser session, CAPTCHA, or token provider. Reconstructable captions,
discussion, metadata, images, and audio remain temporary and untracked.

The portable concepts are subtle event-property alternation, filter motion
longer than a short loop, and a restrained moving effect shadow beside a dry
signal. Machine-only spectral windows described variation in the pitch/release
and wet-shadow demonstrations, but speech, interface sounds, compression, and
edits prevent those measurements from establishing a portable rate, amount,
pitch, filter, effect, or mix target. One technically relevant comment warned
that excessive subliminal modulation can become incoherent or chaotic. This is
source inspection, not human listening.

Repository reconciliation found all three in-session idea families already
owned by the canonical engine: score-derived percussion/groove-pulse
microvariation, multi-bar relational filter and harmonic movement, and existing
dry-plus-echo/chorus/FDN paths. Another hat alternator, filter lane, effect
return, instrument, track, or renderer would duplicate those mechanisms. The
observable missing capability was instead at the complete-performance
boundary: `TechnoEngine` constructed the default director seed `48_291` at
every launch, reproducing the exact first score and PCM.

The App now selects one opaque system-entropy seed before detached preparation
and installs the corresponding sole director. Pause, resume, live correction,
timeline reset, route recovery, score continuation, renderer state, and the
primary evaluator remain deterministic under that seed. Complete shutdown
selects the next identity; an immediate repeated entropy value is mixed away.
Every preparation key binds the exact seed, and acceptance cross-checks key,
source state, current session, and graph identity so stale cached or detached
work cannot cross sessions. No entropy read, parameter, allocation, lock,
decision, or branch was added to the realtime callback, and no score/DSP/evidence
schema or primary artifact changed for a fixed seed.

The durable intention and replacement boundary are recorded in
[`../SOUND_CONCEPT_MATURITY.md`](../SOUND_CONCEPT_MATURITY.md). A later serious
system may replace the scalar entropy source with stronger provenance, opt-in
replay tokens, cross-session novelty memory, or calibrated repetition evidence
only after a measured collision or creative-range deficit. It must preserve
explicit-seed reproducibility, within-session coherence, cache isolation,
future-boundary application, callback silence, and the one canonical engine.

TDD first failed because the seed source, injected engine boundary, and
seed-bearing preparation identity did not exist. The completed focused App
matrix passed 36/36, including fixed-seed score/PCM replay and distinct-seed
score/PCM divergence. The deterministic runtime/repository group passed 36/36,
canonical preparation preflight passed 24/24, and protected routing passed
14/14. The optimized product built in 97.53 seconds; its release realtime-
producer object imported only `_memcpy`. The exact release executable before
commit had SHA-256
`dbad5410df65607bd578a445d2053c6d0abdc6de263def2ad98d9290367e0fb7`.
After the normative prose was finalized, the repository-surface suite reran
5/5 green.
Publication and exact-head CI remain separate gates. No listening,
app/route/interruption QA, physical-output soak, or professional-quality claim
is implied.

## Long-horizon performance study: seven DJ-set sources — 2026-08-23

This study used the repository's bounded `yt-dlp` workflow to inspect seven
videos about set construction and sustaining a dance floor: Resident Advisor's
*The Art Of DJing: Dr. Rubinstein — Building energy* (`I7LwQV9T7gg`),
Crossfader's *How To Plan A DJ Set — (10 Ways To Do It)* (`hjkTkb-_7mQ`),
James Hype's *Planning a DJ set — My secret method* (`3bS8lso9eis`), DJ
Mentor's *The Secret to Building DJ Sets That Make Sense* (`c0MXfZMy2jc`),
Karl Thomas's *How To Structure Your DJ Set The RIGHT Way* (`B31PnFJ-Xdc`),
Valoramous's *DJ Tutorial 58 | How to Set Structure for Four or Five Hour
Gigs* (`u17CILIYGEg`), and Chris M's *How Pro DJs Keep The Dance Floor Full
ALL NIGHT* (`b2JvzT2sYhg`). Six sources had manual or automatic English
captions; the James Hype source exposed no transcript track, so its use was
limited to metadata, description, and bounded discussion rather than inferred
spoken claims. Temporary captions, metadata, and comments remain untracked.

The bounded discussion sample contained 240 top-level comments across the
seven sources. Five technically substantive threads were inspected with at
most three replies each. Independent discussion converged on four portable
ideas: plan sections while retaining adaptation, classify material by felt
energy and function rather than BPM alone, preserve headroom so peaks remain
perceptible, and prefer rare prepared surprise over continuous novelty. These
comments were treated as hypothesis support, not authority or taste approval.

The videos collectively describe long performance as nested contrast rather
than a monotonic climb: maintain, rise, recover, reframe, pay off, and recall
at different timescales. Small relational changes can move energy without
replacing the whole texture; sparse passages can accept more layering or
effect motion than already dense passages; sustained intensity needs breathers;
and the strongest material should not be spent early or continuously. Because
Auto Techno is fixed at 130 BPM and cannot read a crowd or microphone, the
portable translation is a semantic energy vector plus feedback from its own
committed score and app-owned PCM, never tempo escalation or external sensing.

Repository reconciliation found that the canonical runtime already plans and
renders indefinitely with bounded continuation, but its explicit dramatic and
session memories cover only minutes. Existing eight-hour tests prove bounded,
deterministic evolution, not that energy, recurrence, contrast reserve, or
capability dose remain entertaining. The falsifiable deficit is therefore the
absence, before `AutonomousSessionDirector.plan(from:)`, of one compact,
versioned hour-scale trajectory that can account for those qualities and bind
them to future decisions and realized evidence.

A new descriptive four-hour probe ran the current fixed seed twice for 7,800
bars and produced exact replay equality. It planned 710 phrases across all five
phrase kinds and all six performance characters, with 572 distinct event
signatures, 764 high-tension bars, 410 recovery-tension bars, at most seven open
transition debts, and bounded final memory counts `[4, 4, 6, 56, 256]`. These
figures establish a reproducible baseline only; no thresholds were learned
from them, and they do not qualify peak scarcity, recurrence timing, arc shape,
or four-hour entertainment.

The durable implementation and validation map is recorded in
[`../LONG_HORIZON_PERFORMANCE_MAP.md`](../LONG_HORIZON_PERFORMANCE_MAP.md).
The separate, updateable synth/DSP/patch/effect register is
[`../LONG_HORIZON_SOUND_CAPABILITIES.md`](../LONG_HORIZON_SOUND_CAPABILITIES.md).
The current evidence does not justify another synth architecture, preset pack,
effect bus, fixed chain, alternate renderer, or user-facing selector. The next
capability boundary is the compact trajectory schema and descriptive harness;
sound expansion becomes eligible only when semantic or realized evidence
exposes a repeatable deficit the existing palette cannot express.

This study changed documentation and added a Core-only baseline test; it made
no score, renderer, PCM, effect, patch, or realtime-callback change. Focused
structural validation passed 1/1. Long-horizon automated quality qualification,
listening, app/route QA, release build validation, and hardware soak remain
unavailable or unrun and are not implied by the study.

### Phase 0 implementation addendum — 2026-08-23

The preliminary same-run probe was tightened into the test-only
`LongHorizonPlanningBaselineProbe`. Schema
`long-horizon-planning-baseline.v1` now emits sorted canonical JSON, binds the
current `autotechno-canonical-engine.v32`, and freezes the exact four-hour
snapshot. Phrase/debt order fingerprints to `b6642428b9d0fc3e`; the complete
bar-level semantic stream fingerprints to `ce2054dc1adc6b36`. Maximum observed
memory counts were `[4, 16, 16, 109, 256]`, while the final counts remained
`[4, 4, 6, 56, 256]`.

This closes only the descriptive Phase 0 boundary. The report itself declares
`qualificationStatus` as `unavailable` with reason
`no-calibrated-long-horizon-policy`. A later score or planning revision must
review and deliberately advance the baseline instead of passing by comparing
two equally changed fresh runs. No metric in this report is a learned quality
range, no DSP or PCM changed, and no sound-capability expansion became eligible.

### Phase 1 semantic-trajectory addendum — 2026-08-23

Phase 1 converts the map's first evidence requirement into production
`AutoTechnoCore` schema `autotechno-long-horizon-semantic.v1` without connecting
it to runtime selection. `LongHorizonSemanticTrajectoryAccumulator` streams one
canonical plan at a time and retains only fixed-domain counters plus capped
recurrence, periodicity, event-signature, identity-landmark, and dramatic-debt
state. The machine-readable report keeps semantic dimensions separate and has
no opaque engagement score, pass, rejection, adjustment, or future-plan request.

The existing test-only canonical-journey harness now drives the real director
and continuation through that accumulator. The frozen four-hour seed-48,291
trajectory covers 7,800 bars and 710 phrases, fingerprints the semantic stream
to `1bee65e3170b3f59`, and fingerprints the complete sorted report JSON to
`2e41bc115c3d0514`. It describes 4,054 repeated event-signature observations,
137 exact home-signature recall bars versus 553 unmatched identity-return bars,
and 318 opened versus 314 paid dramatic debts. These observations are not
learned target ranges or listening verdicts.

An eight-hour request finishes its final phrase at 15,611 bars while retained
semantic tokens, lag states, event signatures, identity landmarks, and debts
stay within `[64, 64, 64, 16, 16]`. Synthetic inputs establish visibility of an
exact 16-bar cycle, a 128-bar high-tension dwell, 128-bar continuous capability
use, failed/exact recall, instant debt payoff, and debt-capacity overflow.
Malformed seed, scalar, continuity, or debt inputs produce an unavailable report
without partially committing the rejected phrase.

This implements the reusable evidence surface only. It makes no score,
continuation, director, renderer, DSP, graph, PCM, App, scheduler, route, or
callback change. The report still declares long-horizon qualification
unavailable. The evidence did not expose a missing synthesis or effect
capability, so the sound-capability register records no synth, patch, DSP,
effect, bus, chain, or selector expansion.

### Phase 2 hierarchy and variability addendum — 2026-08-23

A second pass over the available captions focused on variability rather than a
single canonical set shape. It treats maintenance, rise, cooldown, shock, and
second-wave language as reusable functions, not a fixed order; cooldown is a
branch point; material turnover can accelerate or slow by context; scarce shock
requires prior absence; reserve should survive for another wave; familiar
identity can be recalled or reframed instead of replaced; and sparse passages
have more additive headroom than already dense ones. These remain bounded
hypotheses to test against accepted score and PCM consequence, not copied DJ
rules or listening approval.

The implementation adds `autotechno-long-horizon-continuation.v1` to canonical
`TemporalMusicalMemory`. Variable 8-32-macro episodes form renewable 3-6-episode
arcs around maintain, rise, recover, reframe, payoff, and recall context. The
state records fixed-domain recency, rare-operator reserve, identity landmarks,
and payoff/recovery/recall obligations. It observes committed plans
transactionally and remains separate from phrase selection until Stage 3.

The frozen seed-48,291 four-hour hierarchy completes 31 episodes through arc 5,
with final-state/sequence fingerprints `a3385980ebf276fd` and
`54ef88de604a159b`. The eight-hour hierarchy completes 63 episodes through arc
14 and fingerprints to `0f85834770dc03c5` / `76e157416ec6b8f5`. Fixed retained
capacities, exact replay, fresh-root variation, schema-safe decoding,
transactional malformed-input preservation, and complete-performance reset all
pass. Identical local memory with different episode context still yields the
same next plan, explicitly preserving the Stage 2 boundary.

This context-only slice found no evidence that the existing synthesis,
instrument homes, effects, or graph cannot express the next controller stage.
It therefore adds no synth, preset, patch, DSP primitive, effect, bus, chain,
renderer, or realtime-callback work. Long-horizon quality remains unavailable
pending director consumption, realized signal evidence, and calibrated policy.
