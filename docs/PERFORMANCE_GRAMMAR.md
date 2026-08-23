# Performance Character Grammar

## What this is

Auto Techno coordinates phrase-scale musical behavior above its internal
instrument palette. A performance character is not a genre preset, a selectable
mode, or a second arrangement engine. It is one score-owned interpretation of
the continuing session identity: tonal center, modal vocabulary, motif
fingerprint, kick voice, swing, and timbral family remain stable while the
existing narrative-owned roles are interpreted through coordinated rhythm,
foundation behavior, patches, and bounded automation.

The canonical `AutonomousSessionDirector` selects one character for a complete
future phrase. It excludes the two most recent characters when another
compatible choice is available, then records the selected character in bounded
continuation memory. The director proposes one coherent interpretation without
independently randomizing layers. Identity return resolves to Hypnotic Lock.

## Character matrix

| Character | Structural use | Foundation behaviors | Coordinated foreground | Rhythmic consequence |
| --- | --- | --- | --- | --- |
| Hypnotic Lock | Lock and identity return | Sub Pulse, Monotone | Stable motif with restrained support | Session-identity kick cell |
| Acid Pressure | Contrast or release | Monotone, Point | Acid Sequence protagonist, Acid Thread shadow, bounded response | Stable four-on-floor pressure |
| Peak Drive | Energy release | Point, Pump | Bright single hook applied to the narrative's admitted foreground | Quarter-note kick authority, bounded turnaround pickup |
| Broken Suspension | Contrast or major break | Kick Tail, Tuned Percussive | Existing admitted roles use broken percussion and dust/metal interpretations | Existing two-step/jungle vocabulary, thinned inside major breaks |
| Ambient Drift | Major break | Absent, Kick Tail | The existing break atmosphere and transition use Dust Cloud interpretations | Sparse downbeat, with a bounded structural return marker |
| Melodic Glow | Lock or contrast | Sub Pulse, Point | North Star melody, Dark Chord shadow/atmosphere, bounded response | Session-identity kick cell beneath the tonal protagonist |

Energy release has one narrow score-owned exception to the otherwise per-bar
kick requirement. When an open dramatic debt, the canonical pullback weak-pulse
cell, motif context, foundation focus, and macro marker all agree, the director
may keep a grounded setup, withhold only kick events and anchors for the next
two bars, then restore the unchanged step-zero kick as recovery. The phrase
character, foundation behavior, every non-kick event, transport grid, and
continuation stay unchanged. No other kickless bar is character-compatible.

The matrix is a compatibility contract. The score does not independently roll
an acid patch, busy rhythm, dense pad, and peak foundation. A candidate is
structurally invalid if any bar changes character mid-phrase, selects an
incompatible foundation, admits a competing role, or fails to produce the
characteristic kick relationship. Supporting-role admission and removal remain
owned by the existing macro-bound narrative evolution; changing character
cannot bypass that continuity contract.

## Foundation vocabulary

| Behavior | Score consequence | Existing patch consequence |
| --- | --- | --- |
| Sub Pulse | One sparse identity-derived bass onset | Bass Pulse, dark and sustained |
| Monotone | Up to two repeating identity-derived bass onsets | Bass Pulse, restrained spectral motion |
| Point | Up to three characteristic syncopations | Bass Pluck, short and brighter |
| Pump | Post-kick bass onsets, bounded to four per bar | Bass Pulse, longer contour and stronger motion |
| Kick Tail | Mono rumble follows the resolved kick cell | No independently scheduled bass note |
| Tuned Percussive | Up to two existing foundation onsets with score-owned modal pitch and bounded material articulation | Six-mode modal resonator in the protected foundation route; no independently scheduled bass note |
| Absent | Kick remains the physical anchor without a companion | No independently scheduled bass note |

Foundation events continue to avoid kick collisions. Foundation assignments
remain centered with zero spatial automation and stay inside the protected
low-end route.

One bounded Lock-only relationship may reinterpret an already present bass pair
as complementary two-bar dotted masks. It changes no kick, harmony, non-bass
event, transport, or effect route; incomplete and occupied-step pairs remain on
their established behavior. The second mask restores the phrase boundary, so
the relation is canonical score data rather than a free-running sequencer.

Inside each eligible dotted bar, the score additionally identifies the single
existing Bass Pluck exactly one step before kick step 4 or 12. It owns a
terminal release from `kick - 0.1875 step` to exact zero at
`kick - 0.0625 step`, leaving a positive dry-foundation pocket while retaining
the unchanged onset mask. Established and malformed relations remain literal
neutral; no second bass lane, sidechain, or renderer-owned musical choice is
created.

## Selection and continuation

Phrase kind bounds the available character set:

- lock: Hypnotic Lock or Melodic Glow;
- contrast: Acid Pressure, Broken Suspension, or Melodic Glow;
- major break: Broken Suspension or Ambient Drift;
- energy release: Peak Drive or Acid Pressure;
- identity return: Hypnotic Lock.

Within that set, deterministic seed material and the last two committed
characters select the next interpretation. The choice happens during detached
future preparation. No composition, randomization, allocation, analysis, or
character switching occurs in the real-time callback.

## Evidence and qualification boundary

Every phrase retains a `PerformanceCharacterEvidence` record containing the
selected character, total bar count, and exact counts of bars with compatible
foundation, role, and rhythm consequences. The plan fingerprint binds the
record and every per-bar character/behavior value. Candidate validation rejects
an incoherent record.

The primary vector separately retains complete per-bar kick-syntax evidence.
It requires exact score/render kick masks, exact-zero detector, audible, and stem
signal during both withheld bars, positive step-zero recovery evidence, and the
unchanged weak-pulse carrier. This evidence remains a hard provenance boundary
inside the calibrated policy.

The final withheld energy-release bar at macro position 14 may additionally
own one `terminalRecoveryDelay` climax hang. Its weak-pulse carrier ends at step
11, the already rendered full mix receives one route-rate 8 ms raised-cosine
release immediately before step 12, and steps 12 through 16 are exact silence.
Voice, graph, effect, and continuation state still advance underneath that
output projection, so the established step-zero recovery on the next bar is
unchanged. The relation adds no onset, lane, instrument, effect return, clock,
random draw, or persistent state; every other bar is literal neutral.

Foundation-rhythm evidence separately binds relation and pair phase, exact
score/render bass masks and start frames, Bass Pluck assignment, dry foundation
hash/peak/RMS, and full/protected pass equality. The professional vector retains
bounded active prevalence and crest factor; these remain non-compensable
evidence rather than a new style selector.

The nested pre-kick-pocket record binds the exact score event, bass/kick steps,
natural event end, route-derived release and kick frames, and same-pass dry-
foundation hash/peak/RMS for the exact-zero interval. Candidate completeness
requires the natural event to cross the kick, positive release and silence
windows, exact full/protected equality, and literal neutral evidence everywhere
the score is ineligible.

The existing instrument evidence then records the exact resolved patch,
automation, effect access, architecture-local dry-PCM hash, event count, peak,
RMS, and finite state. Tests establish that Sub Pulse, Monotone, Point, and Pump
produce distinct deterministic Resonant Mono PCM. These are structural and
score-to-PCM facts, not by themselves a professional-sound qualification.

## Phrase composition layer

The canonical synth plan now derives one bounded composition record for every
resolved bar. It does not admit roles or choose an independent style; it
interprets only material already authorized by the phrase character, narrative,
section, modal DNA, and ensemble score.

| Capability | Eligible context | Score and PCM consequence |
| --- | --- | --- |
| True audio slicing | Broken Suspension or Ambient Drift inside a major-break breakdown with an existing early percussion or kick event | Captures 0.25–2 steps from that bar's exact app-owned dry percussion/kick PCM and schedules at most six forward/reverse triggers at 0.5–2x with boundary fades. No library or cross-session sample storage exists. |
| Full arpeggiator | Melodic Glow, Acid Pressure, or Peak Drive with an admitted motif outside major breaks, structural markers, and Tone chapters | Replaces sparse anchor notes with 8 or 16 fully resolved notes. Direction, 1/16 or 1/8 rate, octave span, rotation, pitch, duration, and velocity are score-owned. DSP has no free-running sequencer clock; the existing sustained-wash release marker keeps its single long anchor and Tone chapters retain their complementary spectral relation. |
| Polyphonic pads | Admitted atmosphere during Ambient Drift, Melodic Glow, major breaks, or a Breath chapter | Adds one simultaneous four-voice modal chord through a fixed-state pad voice with bounded filter, drive, spatial send, and exact dry-PCM evidence. Existing atmosphere events remain intact. |
| Harmonic disclosure | Existing eligible pad material, plus Lock bars that already admit the atmosphere role | A lock phrase realizes the atmosphere with the canonical single pad, conceals the arc as tonic, partially exposes tonic and modal color in its latter half, and a major break reveals the established four-function cycle. Pad and arpeggiator share the same disclosed function; no new role, track, note clock, or instrument is introduced. |
| Voice-leading | Every eligible pad transition | Chooses among inversions/octaves by total movement, leap penalty, common tones, register spread, and selected contrary outer motion. Each bar records common tones, total semitone movement, maximum leap, and harmonic function. |

Arpeggiator pitches and pad voices share the session's modal vocabulary and
disclosed harmonic function. This is the cohesion mechanism: rhythmic note
density and sustained harmony cannot independently choose incompatible pitch
collections. The phrase-local disclosure stage determines whether the existing
arc is concealed, partially exposed, or fully revealed, while the sixteen-bar
macro position selects direction and turnaround behavior deterministically
across adaptive phrase boundaries.

The slicer is true resampling, but deliberately phrase-local: it reads only PCM
rendered and owned by Auto Techno for the current bar, using a percussion event
when present and the resolved kick as the bounded break source otherwise. It
never captures a microphone, system audio, external file, or scheduled output,
and it retains no source buffer in continuation. Rendering occurs during
detached preparation; the callback still schedules immutable completed buffers
only.

Identity return, force-home correction, missing source material, and ineligible
role/character combinations resolve every new feature to exact neutral.
Candidate schema 30 binds per-bar score geometry to source and
output hashes, trigger/rate counts, pad frequency ratios and PCM, arpeggiator
counts and exact score/render pitches, harmonic-disclosure stage/function,
voice-leading bounds, and the existing pad rhythm's filter, send, and
closed/open/closed amplitude consequences. The gate uses route-derived
raised-cosine edges while oscillator/filter/envelope/spatial state advances; it
adds no trigger track or callback work. This is causal structural evidence
rather than a professional-quality claim by itself.

Deliberate remaining boundaries are cross-bar/sample-library slicing, granular
time stretching, arbitrary MIDI import/export, more than four simultaneous pad
voices, chromatic reharmonization outside the identity mode, and calibrated
ranking of harmonic or resampling quality.

Phrase character and composition do not by themselves qualify an hour-scale
journey. The hierarchy, compact continuation, trajectory evidence, adversarial
cases, and ordered integration path are defined in
[`LONG_HORIZON_PERFORMANCE_MAP.md`](LONG_HORIZON_PERFORMANCE_MAP.md); conditional
renderer maturation is tracked separately in
[`LONG_HORIZON_SOUND_CAPABILITIES.md`](LONG_HORIZON_SOUND_CAPABILITIES.md).
The implemented Phase 1 Core schema observes this grammar through a bounded
offline accumulator. Phase 2 adds one compact renewable arc/episode context to
canonical `TemporalMusicalMemory`, including recency, reserve, landmarks, and
obligations. Phase 3 is the explicit consumption boundary: the same director
maps its six operators onto the existing five phrase kinds with one versioned
selection reason and one conservative fallback. It adds no character, phrase
kind, score lane, planner, parallel candidate, or quality verdict.
