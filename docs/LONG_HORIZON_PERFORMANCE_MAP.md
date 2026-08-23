# Long-Horizon Performance Map

## Status and verdict

This is the source-grounded implementation map for keeping one Auto Techno
performance coherent and entertaining over hours. It is not a claim that the
current runtime is entertaining for hours, a new performance mode, or an
authorization to add unrelated DSP.

The current engine already continues deterministically for more than eight
hours without unbounded musical state. Phase 1 now supplies an offline,
Core-owned semantic trajectory report, but the shipped director does not yet
retain or consume hour-scale journey state and there is no calibrated evaluator
that can distinguish an earned long-form journey from a safe, finite repetition
of phrase-scale cycles.

The next priority is therefore **hierarchical journey continuation**, followed
by realized DSP trajectory evidence and calibration—not more presets. The
current three synthesis
architectures, eleven patch homes, six performance characters, resolved score,
phrase composition, spatial field, and transition vocabulary are sufficient to
exercise the first long-horizon controller. Sound-engine expansion should occur
only when that controller exposes a repeatable audible deficit. The separate
follow-up register is
[`LONG_HORIZON_SOUND_CAPABILITIES.md`](LONG_HORIZON_SOUND_CAPABILITIES.md).

## Product translation

DJ-set advice is useful here only after translation into Auto Techno's product
boundary:

- the app has no known set duration or scheduled ending;
- tempo stays at 130 BPM, so energy cannot be faked by a tempo climb;
- there is no crowd microphone, room capture, external track library, cloud
  model, or user-selected set shape;
- pause, resume, route recovery, and a missed preparation deadline continue the
  same identity and obligations;
- the director plans one bounded future phrase, not an hours-long immutable
  playlist;
- source observations motivate falsifiable engine hypotheses; only automated
  qualification can promote a revision.

The DJ's act of "reading the room" therefore becomes the engine reading its own
committed score and app-owned PCM trajectory. It must know what it has recently
asked for, what actually happened, how much contrast remains available, and
which promise should be paid next. It must not open a microphone or infer an
audience.

## Source capture

Sources were accessed on 2026-08-23. Metadata, descriptions, English captions,
and bounded comments were retrieved with the local `yt-dlp` workflow. Manual
captions were preferred where available. Automatic captions are treated as
uncertain source evidence, not authoritative transcripts.

| Source | Caption evidence | Relevant source observation | Comment sample |
| --- | --- | --- | --- |
| [Dr. Rubinstein: Building energy](https://www.youtube.com/watch?v=I7LwQV9T7gg), Resident Advisor, 2:43 | Automatic English; 0:02-0:30 plus the music demonstration | Energy can escalate through a small relational change: a simpler element yields to a harder, more complex one. The whole texture need not be replaced. | 50 top-level comments; one technically relevant thread noted that pitch motion during a blend can create tension. One reply thread was incompletely retrieved. |
| [How To Plan A DJ Set - 10 Ways](https://www.youtube.com/watch?v=hjkTkb-_7mQ), Crossfader, 13:31 | Manual English | 4:49-7:55 covers harmonic/tempo organization; 9:22-10:45 distinguishes sparse material that can accept another layer from already dense material; 11:57-12:33 warns against effects on every transition. | 50 top-level comments. Repeated technical themes were section-based planning, energy/vibe classification, flexibility, and continuous observation. |
| [Planning a DJ set - My secret method](https://www.youtube.com/watch?v=3bS8lso9eis), James Hype, 8:22 | No transcript track; description, metadata, and comments only | The description identifies detailed preparation for a short main-stage set. Comments repeatedly distinguish tightly planned short performances from longer adaptive sets, and value rare unexpected material because it is not overused. | 50 top-level comments; one technically substantive loop/readiness thread was inspected. Direct spoken claims are not attributed because captions were unavailable. |
| [The Secret to Building DJ Sets That Make Sense](https://www.youtube.com/watch?v=c0MXfZMy2jc), DJ Mentor, 12:05 | Automatic English | 0:23-3:38 treats a set as a larger story with warm-up, groove, peaks, release, and return; 4:37-5:39 makes the shape context-dependent and uses filters, echo, reverb, and looping to create space; 5:42-7:50 maps intro, groove, peak, and reset; 10:35-11:57 warns against early peaks, unrelated changes, and spending every strong idea at once. | 22 top-level comments. Specific dissent corrected the idea that BPM alone represents energy and argued for adaptive rather than fixed track order. |
| [How To Structure Your DJ Set The RIGHT Way](https://www.youtube.com/watch?v=B31PnFJ-Xdc), Karl Thomas, 7:59 | Automatic English | 0:42-1:13 frames pacing as avoiding both burnout and failure to build; 1:34-5:06 offers rising, roller-coaster, and peak-with-breathers shapes; 5:10-7:05 reserves headroom and deliberate breathers over a long performance. | 13 top-level comments; most were praise, with support for roller-coaster/workout pacing and not spending peak material immediately. |
| [How to Set Structure for Four or Five Hour Gigs](https://www.youtube.com/watch?v=u17CILIYGEg), Valoramous, 5:49 | Automatic English | 0:22-1:16 combines expected context with crowd responsiveness; 1:10-4:58 divides four-to-five hours into long warm-up, peak, and cooldown intervals, varies the rate of change, and preserves reserve material for a second wave. | All 5 available top-level comments. They reinforce that long sets are a marathon and that timeline structure reduces planning overload. |
| [How Pro DJs Keep The Dance Floor Full ALL NIGHT](https://www.youtube.com/watch?v=b2JvzT2sYhg), Chris M, 7:16 | Automatic English | 0:01-0:43 argues that constant intensity erases impact; 1:15-3:14 makes energy shape contextual; 3:15-4:34 defines maintenance, rise, cooldown, and rare shock transitions; 4:36-6:15 separates transition consequence from content selection and recommends energy classification. | 50 top-level comments. Repeated technical themes were deliberate high/low alternation, energy/style classification, headroom for successors, and crowd-responsive adaptation. |

The bounded sample inspected 240 top-level comments. Five technically
substantive threads were inspected with no more than three replies each.
Usernames and full comments are not retained in repository documentation.
Three independent community observations converged on each of these points:

- plan a direction or set of sections, but retain the ability to adapt;
- classify material by felt energy and function rather than BPM alone;
- high-intensity material needs lower-intensity context and headroom;
- rare, prepared surprises are more effective than constant novelty.

Community convergence remains context, not proof. The James Hype source has no
caption transcript, and none of the source demonstrations was used as a
listening or professional-quality verdict.

## Falsifiable current deficit

**Canonical checkpoint:** the accepted continuation immediately before
`AutonomousSessionDirector.plan(from:)` proposes the next unscheduled phrase.

**Deficit hypothesis:** current continuation lacks a compact, versioned
hour-scale account of energy shape, perceptual recurrence, capability use,
recovery, and reserved contrast. As a result, two four-hour journeys can both be
finite, deterministic, structurally valid, and primary-accepted while one is a
repetitive short-cycle treadmill and the other has motivated long-range
development.

**Evidence that should expose it:** the implemented
`LongHorizonSemanticTrajectoryReport` retains bounded semantic occupancy,
recurrence, scalar movement, dwell, periodicity, debt, capability-use, and
identity-return dimensions. A later DSP-owned report must add compatible
sample-indexed realized trajectories. The future evaluator must keep these
dimensions separate rather than reduce them to one opaque engagement score.

**Disconfirmation:** the hypothesis is false if the unchanged current engine,
across a diverse versioned journey bank and adversarial long-run cases, passes a
calibrated trajectory policy that rejects periodic cycling, permanent peak,
random replacement, drift, starvation, and effect fatigue while preserving
identity and hard gates.

That policy and calibration do not exist today, so long-horizon entertainment
qualification is **unavailable**, not failed or passed.

## Current runtime baseline

### What is already strong

- `AutonomousSessionDirector` owns one identity, five phrase kinds, temporal
  memory, dramatic debt, narrative presence, interlock chapters, and future
  phrase selection.
- Phrases contain 4-16 bars and structural phrases reach the next 16-bar
  boundary.
- Six performance characters coordinate roles, foundation, rhythm, patches,
  and automation; the last two characters are avoided when alternatives exist.
- Contrast and major-break phrases open dramatic debt; energy release can pay
  it with explicit score and PCM consequences.
- The test suite plans 1,024 16-bar macros—more than eight hours at 130 BPM—and
  proves bounded deterministic chapter/narrative continuation.
- The primary evaluator judges every phrase, including a generic
  `longContinuation` checkpoint after phrase 16.
- Existing score-owned sound capabilities already include subtraction, kick
  withholding and recovery, harmonic disclosure, sliced percussion,
  arpeggiation, polyphonic pads, spectral reveal, anticipation swell, terminal
  absence, pulse echo, and a continuing FDN late field.

### What the present clocks actually cover

At 130 BPM, one four-beat bar lasts about 1.846 seconds and a 16-bar macro lasts
about 29.5 seconds.

| Current state or rule | Effective horizon | Limitation for hours |
| --- | --- | --- |
| `recentBars` | 4 bars, about 7.4 seconds | Local continuity only. |
| `currentPhrase` / `previousPhrase` | At most 16 bars each, about 29.5 seconds | Phrase comparison only. |
| `dramaticArc` | At most 128 bars, about 3:56 | Cannot remember an earlier act or hour-scale payoff. |
| `sessionBars` | At most 256 bars, about 7:53 | Raw bar history expires well before an hour. |
| recent performance characters | 2 phrases | Prevents immediate repetition, not long-cycle fatigue. |
| arrangement gesture and percussion gear | fixed 16-bar phase | The same 4/8/12/16-bar geometry can become perceptually periodic. |
| contrast target | 8-24 bars, about 0:15-0:44 | Short-cycle contrast, not an act-level decision. |
| major-break target | 48-96 bars, about 1:29-2:57 | Frequent reset vocabulary without a higher-level scarcity budget. |
| energy-release target | 64-128 bars, about 1:58-3:56 | Payoffs are phrase-aware but not episode-aware. |
| interlock home obligation | within 4 macros, about 1:58 | Strong identity safety, but too short to establish hour-scale recall. |
| `longContinuation` evaluator checkpoint | any phrase index at or above 16 | A per-phrase envelope, not a cross-phrase trajectory policy. |

### Implemented descriptive four-hour probe

`LongHorizonPlanningBaselineProbe` now plans the exact fixed-seed runtime for
7,800 bars, or four hours at 130 BPM, twice through the real director and
continuation. Its test-only `long-horizon-planning-baseline.v1` report emits
canonical JSON and is frozen against the current engine rather than comparing
only two newly generated runs. Separate fingerprints bind the complete phrase/
debt sequence (`b6642428b9d0fc3e`) and bar-level semantic evidence
(`ce2054dc1adc6b36`). A planning change therefore requires an explicit baseline
review and schema/fixture update; two equally changed runs cannot silently pass.

The frozen snapshot contains 710 phrases and all five phrase kinds and six
performance characters. It reports 572 distinct existing event signatures, a
maximum of seven simultaneous open debts, 764 bars at the descriptive
`tension >= 0.8` observation, and 410 bars at `tension <= 0.4`. Maximum observed
memory counts were `[4, 16, 16, 109, 256]` for recent bars, current phrase,
previous phrase, dramatic arc, and session bars; final counts were
`[4, 4, 6, 56, 256]`.

Those counts prove reproducibility and coverage only. The tension cutoffs are
descriptive test observations, not calibrated entertainment targets; signature
count is not perceptual novelty; and all character names appearing does not
prove that their recurrence was well timed. The report encodes
`qualificationStatus: unavailable` and
`qualificationReason: no-calibrated-long-horizon-policy`; Phase 0 has no pass,
reject, or engagement score.

### Implemented Phase 1 semantic trajectory

`AutoTechnoCore` now owns schema
`autotechno-long-horizon-semantic.v1` and the streaming
`LongHorizonSemanticTrajectoryAccumulator`. The accumulator accepts the real
canonical plan plus its exact incoming continuation, validates seed, phrase,
bar, score, composition, scalar, and debt continuity, and emits a `Codable`
machine-readable report. A malformed observation makes the report unavailable
with a reason code and cannot partially apply that observation.

The report preserves interpretable dimensions rather than a verdict:

- phrase, character, section, role, foundation, gesture, percussion, kick,
  interlock, transformation, signature-event, and harmonic occupancy;
- fixed-domain activation, run, and inactive-gap evidence for phrase kinds,
  characters, gestures, transformations, signature events, harmonic functions,
  and the existing score/render capability vocabulary;
- tension, activity, repetition, and density range, mean, maximum step, and
  direction changes, plus descriptive high/recovery dwell;
- exact semantic, event-signature, and tension-band comparisons at lags 1...64;
- one 64-slot least-recently-used event-signature recurrence ledger;
- sixteen rolling non-reconstructable home landmarks with matched/unmatched
  identity-return and matched-absence evidence;
- a transactional sixteen-slot dramatic-debt ledger with source, payoff age,
  instant payoff, overdue, and outstanding evidence; and
- declared storage capacities, starting/next phrase and bar boundaries, and an
  exact trajectory fingerprint.

The existing canonical-journey test harness streams the real director and
continuation through this accumulator without rendering or feeding the report
back into planning. The frozen four-hour seed-48,291 journey retains 7,800 bars
and 710 phrases with trajectory fingerprint `1bee65e3170b3f59`; its complete
sorted JSON fingerprints to `2e41bc115c3d0514`. The report observes 137 exact
home-signature recalls and 553 unmatched identity-return bars, 318 opened and
314 paid dramatic debts, and event-signature recurrence without retaining all
7,800 bars. These are descriptive facts, not good/bad thresholds.

An eight-hour request completes its final canonical phrase at 15,611 bars while
the recent semantic ring, periodicity lags, event-signature ledger, identity
landmarks, and debt ledger remain capped at 64, 64, 64, 16, and 16 entries.
Synthetic journeys prove that the schema exposes an exact sixteen-bar cycle,
128 bars of uninterrupted high tension and one continuously active capability,
failed versus exact home recall, zero-age debt payoff, and fail-closed debt
capacity overflow. No policy consumes those observations yet, so every valid
report still declares qualification unavailable with reason
`no-calibrated-long-horizon-policy`.

## Required musical model

### One hierarchy, not another engine

The current phrase kinds remain the canonical vocabulary. A new compact
`LongHorizonContinuationState` should give them episode context rather than
creating another director:

```text
session identity and accepted continuation
  -> renewable arc intention and outstanding obligations
  -> episode operator and reserved contrast
  -> existing phrase kind and performance character
  -> existing resolved score and renderer
  -> semantic + PCM trajectory evidence
  -> reason-coded update for an unscheduled future phrase
```

Candidate planning timescales, to be calibrated rather than treated as quality
thresholds, are:

| Scale | Existing or proposed extent | Responsibility |
| --- | --- | --- |
| Event / step | existing 16-step bar | Groove, articulation, onset consequence. |
| Bar | existing 4 beats | Local role, density, timbre, and transition state. |
| Phrase | existing 4-16 bars | One coherent intention and immutable prepared product. |
| Macro | existing 16 bars | Gesture resolution, interlock chapter, and local return. |
| Episode | proposed bounded 8-32 macros, roughly 4-16 minutes | Maintain, rise, recover, reframe, or pay one larger obligation. |
| Arc | proposed bounded 3-6 episodes | Establish a home, depart, transform, recover, and recall without assuming a final ending. |
| Continuing session | renewable arcs | Indefinite performance with compact summaries, no unbounded history and no predetermined close. |

An episode may end early when its obligation is satisfied, but may not drift
forever. An arc does not imply an outro: after a credible return, the director
renews context and begins another departure from the same identity.

### Energy is a vector

Because BPM is fixed, an episode operator must coordinate existing semantic
dimensions rather than introduce a fake tempo lane or one opaque intensity
score:

- foundation authority and kick continuity;
- admitted-role density and deliberate absence;
- weak-pulse and upper-percussion activity;
- protagonist presence and motif recognizability;
- harmonic disclosure and tonal stability;
- spectral aperture and timbral motion;
- dry/near versus diffuse/distant placement;
- transition expectation, payoff, and post-payoff recovery;
- realized loudness, crest, transient, spectrum, masking, stereo, and effect-
  return evidence from the detached render.

The semantic target and realized PCM must remain separate. A structurally
declared cooldown that renders equally loud, bright, dense, and wet is an
evidence mismatch, not a successful cooldown.

### Episode operators

The source evidence maps cleanly to bounded operators around the current phrase
kinds:

| Operator | Current vocabulary reused | Required long-range consequence |
| --- | --- | --- |
| Maintain | lock, hypnotic/melodic character, stable interlock | Sustain a productive band without accumulating density, wetness, or novelty. |
| Rise | contrast, progressive narrative presence, disclosure, spectral aperture | Increase selected vector dimensions while retaining headroom and opening a payable obligation. |
| Recover | major break, subtraction, absent/kick-tail foundation, atmosphere | Provide audible breath and clear accumulated effect/role load without losing identity. |
| Reframe | contrast or major break with a different protagonist/character relation | Change the interpretation of known material, not replace it with an unrelated identity. |
| Payoff | energy release, paid debt, kick syntax, anticipation/hang/recovery | Spend previously established contrast once, then require recovery rather than remaining at peak. |
| Recall | identity return, Hypnotic Lock, motif/home timbre | Bring back a recognisable earlier relation after enough absence to carry memory. |

The rare "shock" described by the sources belongs inside a reason-coded payoff
or reframe. It is not a random genre jump, new engine, or periodic drop.

### Compact continuation

Raw hour-scale bars are unnecessary and would be unbounded. The continuation
should retain fixed-capacity summaries:

- current arc and episode identity, operator, start bar, minimum hold, maximum
  due boundary, and completion reason;
- an energy-vector start, target relationship, realized range, slope, peak
  dwell, and recovery debt;
- motif, harmony, character, instrument-capability, transition, and effect-use
  recency with bounded counts and last-use bars;
- unresolved long-range obligations and the exact earlier event they promise to
  answer;
- a small set of identity landmarks eligible for later recall, represented by
  non-reconstructable score fingerprints rather than audio;
- the last accepted trajectory-evidence version and reason-coded decision.

Pause and route recovery preserve this value. A complete new performance resets
it with the new root identity. Late, missing, malformed, or version-mismatched
evidence keeps the current coherent episode and uses the existing accepted-
audio fallback; it cannot improvise a new arc.

## Required trajectory evidence

### Core-owned semantic report

For every committed phrase, aggregate bounded windows without retaining all
bars:

- phrase-kind, character, section, role, foundation, gesture, and transformation
  occupancy;
- recurrence gaps and run lengths for characters, event signatures, harmonic
  functions, motif relations, transitions, and sound capabilities;
- episode operator dwell, direction changes, reserved contrast, and recovery
  debt;
- dramatic-debt age, source, payoff, and overdue state;
- identity-landmark establishment, absence, recall, and altered consequence;
- planned energy-vector start/end, slope, peak dwell, and contrast relative to
  the preceding stable region;
- exact incoming/outgoing continuation and earliest eligible future boundary.

### DSP-owned realized report

Reduce existing per-phrase signal evidence into compatible trajectory windows:

- integrated, momentary, and short-term loudness relationships by episode
  operator, never one whole-session loudness target;
- crest, transient density, low/mid/high energy, centroid, masking, stereo,
  low-end correlation, and headroom trajectories;
- role-local activity and dry-PCM fingerprints sufficient to detect unintended
  stasis or disconnected semantic changes;
- FDN, echo, chorus, comb, drive, filtering, gated-return, and transition wet-
  consequence occupancy and recovery;
- discontinuity, tail, silence, and route-change witnesses across episode
  boundaries.

Core consumes only a reduced, versioned observation. It must not depend on DSP
types or store PCM.

### Adversarial journeys

The first policy must reject, without compensation:

- permanent or nearly permanent peak;
- a fixed sawtooth that repeats the same rise/drop every 16 bars;
- strict alternation that maximizes character count while sounding predictable;
- repeated breakdowns or identity returns that erase forward motion;
- a rare gesture scheduled periodically until it stops being surprising;
- effect wetness, tail, or spectral brightness that ratchets upward across arcs;
- monotonically decreasing energy that never rebuilds;
- unresolved or instantly paid dramatic obligations;
- semantic rise/recovery labels whose rendered PCM moves in the opposite
  direction;
- route recovery that resets arc memory or replays a payoff as if it were new;
- late preparation that mutates current/scheduled audio or loses fallback
  coherence.

No dimension may compensate for a hard gate, identity break, unbounded state,
or causality mismatch.

## Ordered implementation slices

Each slice extends the one canonical owner and leaves a reusable capability.

| Stage | Canonical owner and state | Reusable capability | Automated deficit/evidence | Boundary, continuation, and fallback | Duplicate avoided |
| --- | --- | --- | --- | --- | --- |
| 0. Descriptive baseline — complete locally | Test-only `LongHorizonPlanningBaselineProbe` using `AutonomousSessionDirector` and real continuation | Frozen, versioned four-hour planning snapshot with canonical JSON and separate plan/bar fingerprints | Exact engine-v32 kind/character/tension/signature/debt/memory coverage; encoded qualification unavailability and no engagement verdict | Pure planning; fixture drift requires explicit review; no PCM, runtime selection, or production state change | No second planner, synthetic fixture engine, or unfrozen same-run-only comparison |
| 1. Trajectory schema and offline harness — complete locally | `AutoTechnoCore` schema `autotechno-long-horizon-semantic.v1` plus existing canonical journey harness | Fixed-capacity semantic trajectory accumulator and machine-readable report | Real four/eight-hour evidence plus adversarial periodicity, peak dwell, capability fatigue, recall, and debt cases; qualification remains unavailable | Offline only; malformed input is unavailable without partial mutation; no runtime selection change | No opaque engagement score, handwritten pass, second planner, DSP type, or PCM retention |
| 2. Hierarchical continuation | `TemporalMusicalMemory` extended with one compact long-horizon value | Renewable arc/episode intention, capability recency, reserve, and obligations | Demonstrate different episode context from identical local phrase history and exact replay from identical complete state | Applies only before an unscheduled phrase; bounded due/hold; preserve current episode on failure | No second director, playlist, or user mode |
| 3. Episode operator selection | `AutonomousSessionDirector.nextKind` and `makePlan` consume the new context | Maintain/rise/recover/reframe/payoff/recall policy mapped to existing phrase kinds | Planned vector must show motivated contrast, scarce peaks, recovery, and timely debt closure | Candidate count remains one; fallback is current conservative kind/home behavior | No alternative arrangement engine or random style switch |
| 4. Score-owned energy coordination | Existing resolved roles, character, narrative, foundation, disclosure, and transformations | One coordinated semantic energy target rather than independent layer rolls | Every target coordinate reaches score/renderer or is removed; provenance and exact neutral paths required | Bounded slew and changes only at phrase/macro boundaries | No extra density track or disconnected energy scalar |
| 5. Effect/capability dose orchestration | Existing instrument effect access, graph, FDN, pulse echo, returns, and transition relations | Recency, cooldown, and sentence-level call/response/turnaround orchestration | Wet occupancy, effect-to-dry intelligibility, tail recovery, and repeated-capability evidence | No new bus initially; force-home and recovery keep existing exact neutral behavior | No orderable plug-in chains or generic FX sequencer |
| 6. Calibrated long-horizon policy | Primary evaluator and versioned professional evidence | Non-compensable cross-phrase and cross-episode decision dimensions | Diverse development journeys, disjoint holdout journeys, and adversarial long runs | A failed trajectory cannot be corrected by rewriting scheduled audio; repeat accepted material or keep current episode | No parallel permissive evaluator |
| 7. Bounded future adaptation | Atomic selected commit across musical, quality, render, graph, and live state | Reason-coded trajectory update for the next eligible phrase | Exact replay of plan, evidence, decision, and continuation; stability under missed deadlines and route changes | One bounded correction path at most unless the primary contract is deliberately revised and recalibrated | No independent long-form controller fighting the director |
| 8. Targeted sound maturation | Existing Core intention and affected DSP owner | Only the capability demonstrated missing by Stage 6 evidence | See the separate sound-capability register | Replace provisional DSP in place; exact neutral and protected paths remain | No preset pack, alternative renderer, or speculative chain expansion |

## Validation matrix

Planning-only tests can run for full durations. PCM qualification should render
representative checkpoints and transitions rather than allocate an entire
eight-hour waveform in memory.

| Horizon | Required evidence |
| --- | --- |
| 30 minutes | Exact plan/continuation replay, every operator's local causality, debt lifecycle, no immediate capability cycling. |
| 2 hours | Multiple renewable episodes, at least one established/departed/recalled identity landmark, bounded peak/recovery behavior, effect-dose recovery. |
| 4 hours | Diverse seed bank, complete semantic trajectory report, representative detached renders at all episode boundaries, no state growth. |
| 8+ hours | Planning and accumulator stability, counter/epoch safety, route/pause continuation replay, adversarial periodicity and drift attacks. |
| Exact release build | Primary evaluator availability, preparation headroom, app scheduling, route/interruption QA, and accepted-audio fallback. |
| Physical output | Separate long hardware soak with route recovery and no underruns; this remains distinct from musical qualification. |

## Completion boundary

Long-horizon work is complete only when all of these are reported separately:

1. the hierarchy and trajectory schemas are implemented;
2. structural, deterministic, resource, and signal validation pass;
3. an exact engine/policy revision passes calibrated long-horizon development,
   adversarial, and disjoint holdout journeys;
4. the exact app build passes extended playback and route/interruption QA;
5. physical-output soak passes;
6. any sound-capability expansion has replaced its prior mechanism in place and
   updated both this map and
   [`LONG_HORIZON_SOUND_CAPABILITIES.md`](LONG_HORIZON_SOUND_CAPABILITIES.md).

Human listening may identify the next deficit. It cannot replace any of these
states or promote the engine by itself.
