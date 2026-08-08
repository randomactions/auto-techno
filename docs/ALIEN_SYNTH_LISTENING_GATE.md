# Alien Analog V1 listening gate

Status: **Objective sound checks passed; performance and listening gates failed/pending**

This comparison isolates two claims at matched RMS:

1. B should beat A because the upper voices read as one authored, moving
   instrument rather than recognizable primitive oscillators.
2. C should beat B because cross-cycle interlocks increase hypnosis and
   syncopation without weakening the drum foundation.

The WAV files are local and ignored by Git. The reproducible report is
[alien_synth_translation_report.json](reference/alien_synth_translation_report.json).

## Files

For each seed (`42`, `48291`, and `90909`):

- `alien_seed…_A_current_persistent_v3.wav` — frozen legacy synth path and
  existing rhythm.
- `alien_seed…_B_voice_existing_rhythm_matched.wav` — Alien Analog V1 with
  the same rhythm, RMS-matched to A.
- `alien_seed…_C_interlocked_matched.wav` — the same Alien Analog instrument
  plus the 5-in-16 shadow, seven-step accent, and three-step echo clocks,
  RMS-matched to A.
- matching `A/B/C_voice_focus` files — upper-voice stems for judging identity
  without drums and bass masking the comparison.

Each complete render is approximately `0:59` at the fixed 130 BPM.

## Listening procedure

1. Start with seed `48291`. Compare A→B in the voice-focus files, then in the
   complete mix. Listen for harmonically moving weight, a coherent instrument
   identity, and the absence of an obvious sine/saw/pulse foreground.
2. Compare B→C in the complete mix. Listen for a slow cross-bar pull rather
   than extra notes, and verify that kick authority and the core groove do not
   feel reduced.
3. Repeat for seeds `42` and `90909` on headphones and speakers without
   compensating volume.

## Verdict

| Seed | B beats A on identity/movement/weight | C beats B on hypnosis/syncopation | Drums remain authoritative | Concrete observation |
| ---: | --- | --- | --- | --- |
| 42 | pending | pending | pending | pending |
| 48291 | pending | pending | pending | pending |
| 90909 | pending | pending | pending | pending |

Promotion requires B>A on at least two seeds and C>B on at least two seeds.
A merely different result is a failure, not permission to stack more effects.

## Automated evidence

All three seeds currently pass:

- distinct A/B/C hashes and deterministic reset coverage;
- byte-identical kick, bass, primary-hat, and clap event schedules;
- continuous seven-step and three-step clock phases;
- five kick-safe shadow events in every non-suspended bar;
- finite output, true peak below `0.95`, DC below `0.001`, boundary delta below
  `0.3`, and low-band correlation above `0.94`;
- at least three significant non-fundamental partials and at least `40 Hz` of
  pressure-state centroid evolution.

The release performance gate fails. Median A preparation is `0.81 s`; median C
is `1.92 s`, or `2.37×` A against the required `≤1.10×`. C still prepares a
roughly 59-second scene well before scheduling needs it, but the stricter gate
remains binding. Until both performance and listening pass, Alien Analog V1 is
a local candidate, not an approved release engine.
