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
continuation memory. Primary and alternate candidates may therefore propose
different coherent interpretations without independently randomizing layers.
Identity return and conservative fallback resolve to Hypnotic Lock.

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
| Tuned Percussive | Up to two characteristic tuned-tom onsets | No independently scheduled bass note |
| Absent | Kick remains the physical anchor without a companion | No independently scheduled bass note |

Foundation events continue to avoid kick collisions. Foundation assignments
remain centered with zero spatial automation and stay inside the protected
low-end route. The conservative candidate uses the legacy companion and event
resolution exactly, even though its evidence names the equivalent behavior.

## Selection and continuation

Phrase kind bounds the available character set:

- lock: Hypnotic Lock or Melodic Glow;
- contrast: Acid Pressure, Broken Suspension, or Melodic Glow;
- major break: Broken Suspension or Ambient Drift;
- energy release: Peak Drive or Acid Pressure;
- identity return and conservative fallback: Hypnotic Lock.

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

The candidate vector separately retains complete per-bar kick-syntax evidence.
It requires exact score/render kick masks, exact-zero detector, audible, and stem
signal during both withheld bars, positive step-zero recovery evidence, and the
unchanged weak-pulse carrier. This evidence remains a hard provenance boundary;
the uncalibrated policy does not rank or promote the syntax.

The existing instrument evidence then records the exact resolved patch,
automation, effect access, architecture-local dry-PCM hash, event count, peak,
RMS, and finite state. Tests establish that Sub Pulse, Monotone, Point, and Pump
produce distinct deterministic Resonant Mono PCM. These are structural and
score-to-PCM facts, not a professional-sound qualification; the shipping policy
remains uncalibrated.

## Deliberate remaining boundaries

This slice does not capture or resample output, create a sample library, or add
MIDI. A future slice renderer may provide score-owned, phrase-local generated
audio fragments only after its source ownership, memory bound, callback safety,
and exact PCM evidence are specified.

This slice also does not claim rich polyphonic ambient pads, continuous
sparse-to-arpeggiated density travel, or a complete harmonic voice-leading
grammar. Dark Chord, Dust Cloud, existing motif transformations, and the
character conductor provide compatible destinations for those future vertical
slices without pretending they are already implemented.
