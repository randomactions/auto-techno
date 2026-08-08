# 96-bar performance-compiler listening gate

Status: **Objective checks passed; subjective listening pending**

This gate tests two separate claims at matched overall RMS:

1. A 96-bar debt/payoff score is a meaningful leap over repeating the current
   32-bar Persistent V3 form.
2. The authored **Shadow Pressure** instrument is clearly preferable to the
   legacy motif voice inside that same score.

No candidate is integrated into live playback. The WAV files remain local and
ignored by Git; only the reproducible JSON report is versioned.

## Files

For each seed (`42`, `48291`, and `90909`):

- `A_current_v3_repeated_96bars` — the current Persistent V3 32-bar render
  repeated three times. This is the unchanged baseline.
- `B_dramatic_legacy_matched` — the new 96-bar score with the existing motif
  voice, matched to A. Compare A→B to judge the performance compiler alone.
- `C_dramatic_authored_matched` — the same score with the authored Shadow
  Pressure instrument, matched to A. Compare B→C to judge instrument quality.
- `B_voice_focus_bars64_87` — the legacy musical-voice stem for the final
  pressure and decisive-return arc.
- `C_voice_focus_bars64_87_matched` — the authored Shadow Pressure stem over
  the identical bars, RMS-matched to the focused B file. Use this pair to judge
  the instrument itself before deciding whether it works in the complete mix.

The complete files last approximately `2:57` at 130 BPM. The focused files
last approximately `0:44` and begin at bar 64 (`1:58` in the complete render).

## Dramatic landmarks

| Time | Bar | Intended event |
| --- | ---: | --- |
| `0:30` | 16 | First pressure begins |
| `0:44` | 24 | Intentionally incomplete return |
| `0:59` | 32 | Hypnotic lock deepens; motif debt remains open |
| `1:29` | 48 | Subtraction begins |
| `1:58` | 64 | Final pressure arc begins |
| `2:20` | 76 | Kick and foundation are strongly withheld |
| `2:28` | 80 | Decisive foundation/downbeat/dry-impact return |
| `2:35` | 84 | Motif debt resolves |
| `2:42` | 88 | Afterglow |

## Listening procedure

1. Start with seed `48291`. Listen to A once, then B without changing volume.
2. In A, note whether the returns at the repeated 32-bar boundaries feel like
   restarts. In B, focus on `0:44`, the arc from `1:29` to `2:28`, and whether
   the bar-80 return feels causally earned rather than merely louder.
3. Compare the two focused voice files. Judge whether C reads as one authored
   instrument with intentional motion, rather than oscillators receiving
   effects. Then compare the complete B and C files from `1:58–2:42` to test
   whether that advantage survives mix context.
4. Repeat the decisive sections and focused comparison for seeds `42` and
   `90909`. A leap must survive
   identity changes; one lucky seed is insufficient.
5. Listen once on headphones and once on speakers at the same comfortable
   playback level. Do not compensate for a candidate by turning it up.

## Verdict

| Seed | B beats A on form | Bar-80 return feels earned | C beats B on instrument | Concrete observation |
| ---: | --- | --- | --- | --- |
| 42 | pending | pending | pending | pending |
| 48291 | pending | pending | pending | pending |
| 90909 | pending | pending | pending | pending |

Promotion requires a clear preference for B over A on at least two seeds and a
clear preference for C over B on at least two seeds. If either comparison is
merely different or mildly improved, stop the leap work rather than integrating
it into the app.

Objective evidence is recorded in
[leap_translation_report.json](reference/leap_translation_report.json). It
confirms deterministic 96-bar coverage, complete debt/payoff closure, distinct
audio hashes, finite output, conservative true peaks, mono-compatible low end,
and a bar-80 return more than three times the RMS of bar 79. Those checks prove
that the intended contrast reaches audio; they cannot prove musical quality.
