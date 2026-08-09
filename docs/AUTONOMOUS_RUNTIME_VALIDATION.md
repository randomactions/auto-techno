# Autonomous Runtime Validation

Release status is reported as four separate states: implementation, automated
validation, listening approval, and hardware soak. Passing one does not imply the
others.

## Automated validation

Run with a matching macOS Swift compiler and SDK:

```bash
swift test
swift build -c release
```

The suite must cover:

- session determinism, temporal memory, debts, ensemble arbitration, and phrase selection;
- exact three-to-five phase sequencing, phrase-boundary continuity, sixteen-bar
  realignment, bounded chapter memory, and home returns;
- Scene DNA, synth planning, and semantic correlation;
- graph validity, topology transitions, tails, continuation replay, and route recovery;
- finite samples, peak/true-peak, DC, low-end correlation, boundary limits, and masking;
- exact role-stem reconstruction, bounded automatic balance, unchanged pre-fader
  ducking, and fixed-decibel waveform behavior;
- deterministic current-path hashes and the absence of retired package/runtime surfaces.

Capture preparation time and objective metrics for the canonical session at
representative sample rates. Preserve those records with the exact commit,
private fixture state, and toolchain identity. Fixture state exists only to make
engineering results reproducible; it is not selectable in the app.

## App smoke test

On a release build, verify:

- one accessible transport button;
- prepare, play, pause, and resume;
- sample-time bar scheduling and phrase-boundary continuation;
- late-successor repetition without silence or premature state advance;
- coherent recovery after switching between 44.1 and 48 kHz routes.

## Listening gate

If current-runtime sample hashes change, render the same canonical session before
and after, match loudness, and compare on the same physical output. Listen at the
first macro, first chapter change, contrast, break, release, and identity return.
Objective metrics bound safety but cannot approve musical quality. Record at
least one concrete audible observation and the resulting rule in
`TASTE_LEDGER.md`; otherwise treat the difference as a regression.

## Physical-output soak

Before claiming release readiness, run for at least 60 minutes on physical output.
During the run:

1. pause and resume repeatedly;
2. change output routes and sample rates;
3. trigger and recover from an interruption;
4. sleep and wake the Mac;
5. confirm continuous phrase progression, bounded output, and no clicks, gaps,
   runaway tails, crashes, or disabled transport.

Record hardware, OS, sample rates, exact commit, start/end times, interventions,
and observations. A missing soak is reported as unverified, never inferred from
unit tests.

## Legacy engineering appendix — 2026-08-08 cleanup preservation record

The numeric fixtures below predate the all-in product contract. They remain an
engineering provenance record only; they are neither selectable product choices
nor current musical acceptance criteria.

The autonomous phrase path from pre-cleanup `f14c3a8` was rendered again from a
temporary checkout and compared with the cleaned working tree. Both used the
same local machine and warmed SwiftPM/module caches. The PCM output was
bit-identical, so matched-loudness gain is exactly `1.0` and no audible-difference
claim is involved.

| Legacy fixture | Rate | Sample hash | RMS | True peak | DC | Low correlation | Boundary | Baseline / cleaned prep |
| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 42 | 44,100 | `194cfd9b41526538` | 0.109890 | 0.428781 | 0.000495 | 0.999959 | 0.021120 | 56.58s / 56.55s |
| 48,291 | 44,100 | `04dcfcadcf870950` | 0.112622 | 0.454291 | 0.000570 | 0.999963 | 0.019802 | 41.68s / 41.52s |
| 90,909 | 48,000 | `f22539221aaf3155` | 0.111463 | 0.436864 | 0.000725 | 0.999972 | 0.047000 | 28.59s / 28.68s |

The paired baseline/cleaned WAV SHA-256 values were respectively
`e80c04f30ef18a5a8e0aaa16b96d59a16e9be8b774fe5761049e51dc56a745ac`,
`7fb53b14e017cc7bcbf4988608d2b0666625c944d6e9a019e04adf6052dfd41b`,
and `718e225c7065452c12a1a856e009bdda3b920cc9aea2285ffa2e03ad0dbe2f48`.
The cleanup-era compact 8 kHz hashes were `bca565a2c3a17f31`,
`d0e39cebdaed39d6`, and `f6486cd179cd9c6b`. They remain historical baselines;
the implementation candidate does not replace them before listening approval.

## Oscar-informed candidate status — 2026-08-08

The cleanup hashes above remain the immutable `942786a` baseline. The
groove-first implementation intentionally changes render math, so its tests
verify repeatability without declaring new canonical hashes. The current
candidate also replaces independent upper-voice clocks with a three-step driver
advancing a five-stage follower and bounded sixteen-bar chapters. Focused phase,
chapter, and resolved-audio tests pass with Xcode 26.6's matching Swift 6.3.3
compiler and SDK. The complete 31-test suite and optimized release build also
pass in that toolchain. Matched-loudness listening approval and the
physical-output soak remain separate gates until recorded.

## Kick hierarchy trim evidence — 2026-08-08

Before the fixed kick fader changed render math, the continuous canonical Play
journey was captured from the preserved all-in worktree at 8 kHz. The candidate
was then captured through the identical journey and continuation state. These
compact-rate measurements are engineering diagnostics, not promoted canonical
hashes and not a listening verdict. “Kick window” is the mono RMS inside 80 ms
of each resolved onset; “non-onset” is the remaining program and still contains
kick decay, so its ratio must not be interpreted as an isolated stem balance.

| Checkpoint | Bars | Pre-trim hash | Pre RMS | Pre peak | Pre kick window | Pre non-onset | Pre ratio dB |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| First macro | 0–15 | `d5579c7d1b6fd9f6` | 0.10292836 | 0.45808718 | 0.24171786 | 0.02373352 | 20.1589 |
| Contrast | 13–17 | `c6ca150043bb8e4e` | 0.10303850 | 0.45808718 | 0.24195199 | 0.02380673 | 20.1406 |
| Break | 100–111 | `9ac78e550515d537` | 0.08665728 | 0.42481762 | 0.20425887 | 0.01832034 | 20.9449 |
| Release | 84–99 | `a8f0c7dcd7de4922` | 0.10330837 | 0.49265024 | 0.24251953 | 0.02400307 | 20.0896 |
| Identity return | 118–127 | `ecf4cd5c4ff8c1b4` | 0.10298184 | 0.45418200 | 0.24183369 | 0.02374941 | 20.1573 |

| Checkpoint | Candidate hash | Candidate RMS | Candidate peak | Candidate kick window | Candidate non-onset | Candidate ratio dB |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| First macro | `e50fdd2d1d020804` | 0.09248096 | 0.43606511 | 0.21769339 | 0.02019814 | 20.6507 |
| Contrast | `537e1287e47e598a` | 0.09260683 | 0.43626565 | 0.21796369 | 0.02027883 | 20.6268 |
| Break | `5dfc9fb3e8874f8e` | 0.07499181 | 0.38633171 | 0.17691938 | 0.01548090 | 21.1596 |
| Release | `e044e41862f16e01` | 0.09297638 | 0.44529971 | 0.21879862 | 0.02043053 | 20.5953 |
| Identity return | `33b3a01381fff976` | 0.09255140 | 0.43501356 | 0.21785671 | 0.02019889 | 20.6569 |

The direct signal-path test is authoritative for the fader itself: post-fader
kick RMS is `1.5 ± 0.05 dB` below the pre-fader detector, the detector retains
the original regular and breakdown levels, the ducking envelope follows that
detector, masking consumes the post-fader peak, and reported kick onsets and
positions are unchanged. Matched-loudness listening and physical-output soak
remain pending. The optimized release executable also passed a native UI smoke:
the single accessible `transport-play-pause` control changed LIVE → PAUSED →
LIVE → PAUSED, its label changed PAUSE → PLAY → PAUSE → PLAY, and the displayed
phrase/bar position continued after resume. Route switching, interruption
recovery, and the hour-long physical-output soak were not covered by this smoke.

## Automatic kick/foundation evidence — 2026-08-09

The five dry measurement stems were first added at unity. Before the automatic
gain was enabled, the compact 8 kHz first-macro hash remained bit-identical at
`e50fdd2d1d020804`, proving that observation alone did not alter PCM. Tests also
reconstruct the dry center from kick + foundation + percussion and the dry upper
bus from upper-tonal + atmosphere with maximum sample error below `1e-6`.

The bounded governor then changed only the post-fader kick. In the canonical
first macro, mono rumble produced a raw active-level difference near `28.96 dB`;
the correction settled at approximately `-1.23 dB`, producing `27.73 dB` against
the authored `27.5 dB` target. The compact candidate metrics are:

| Stage | Hash | RMS | True peak |
| --- | --- | ---: | ---: |
| Fixed `-1.5 dB` kick baseline | `e50fdd2d1d020804` | 0.092480965 | 0.4360651 |
| Automatic hierarchy candidate | `35a6c0e5d4bb271c` | 0.083510700 | 0.4143651 |

Synthetic long-run coverage verifies the `-3...0 dB` bounds, maximum
`0.35 dB` step, deadband convergence without gain drift, and state hold during
breaks or invalid foundation observations. Companion fixtures reach the intended
active-level neighborhoods for bass (`16.5 dB`), mono rumble (`27.5 dB`), and
tuned tom (`22.5 dB`). The resolved kick event count and positions, pre-fader
detector, and detector-derived ducking remain unchanged; masking and level
metadata consume the final post-fader kick.

The display envelope is tested separately: equal input energy always produces
equal height and a 6 dB input difference remains visible because bars are no
longer normalized independently. These automated results do not constitute the
pending matched-loudness listening verdict or physical-output soak.

The complete 34-test suite and optimized release build pass locally with Xcode
26.6 / Apple Swift 6.3.3. A native release-bundle smoke also passed: the single
accessible `transport-play-pause` control moved READY → LIVE → PAUSED → LIVE →
PAUSED, phrase/bar position continued across resume, and the fixed-scale waveform
rendered while live. Route switching, interruption recovery, and the hour-long
physical-output soak were not exercised by this smoke.

## Weak-sixteenth groove reveal evidence — 2026-08-09

Before changing render math, the exact `9157658` baseline passed all 34 tests and
produced a 44.1 kHz canonical first-macro hash of `c0a8e56171793343` (RMS
`0.09027027`, true peak `0.40203717`, loudness estimate `-21.580105`, low-band
correlation `0.9999444`). The weak-sixteenth candidate produced hash
`8cae318d64ba05aa` (RMS `0.09027233`, true peak `0.4020319`, loudness estimate
`-21.579906`, low-band correlation `0.9999444`). Its resolved trace is empty for
bars 1–4, eight alternating weak positions for bars 5–11, only steps 7 and 15 on
bar 12, and trailing weak positions 3/7/11/15 for bars 13–16. Loudness-normalized
bars 1–4 are bit-identical before and after.

The expanded 39-test suite passes with Xcode 26.6 / Apple Swift 6.3.3, including
macro and phrase-boundary continuity, break exclusion, priority preservation,
weighted density, resolved metadata/PCM coupling, exact percussion-stem routing,
automatic-mix exclusion, mono carrier output, low-frequency rejection,
deterministic continuation, and representative 44.1/48 kHz safety renders. The
optimized release build also passes. A native smoke verified the single enabled
`transport-play-pause` accessibility control and LIVE → PAUSED → LIVE continuation
from phrase 1 into phrase 2; the temporary release instance was then paused and
closed.

Temporary 44.1 kHz matched-loudness pairs exist for skeleton, contour,
syncopated-lean, and pullback stages, plus the isolated carrier. Human listening
approval, route/interruption testing, and the physical-output soak remain pending.
