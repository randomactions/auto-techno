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
- Scene DNA, synth planning, and semantic correlation;
- graph validity, topology transitions, tails, continuation replay, and route recovery;
- finite samples, peak/true-peak, DC, low-end correlation, boundary limits, and masking;
- deterministic current-path hashes and the absence of retired package/runtime surfaces.

For seeds `42`, `48291`, and `90909`, capture preparation time and objective
metrics at representative sample rates. Preserve those records with the exact
commit and toolchain identity.

## App smoke test

On a release build, verify:

- one accessible transport button;
- prepare, play, pause, and resume;
- sample-time bar scheduling and phrase-boundary continuation;
- late-successor repetition without silence or premature state advance;
- coherent recovery after switching between 44.1 and 48 kHz routes.

## Listening gate

If current-runtime sample hashes change, render the fixed seeds before and after,
match loudness, and compare on the same physical output. Objective metrics bound
safety but cannot approve musical quality. Record at least one concrete audible
observation and the resulting rule in `TASTE_LEDGER.md`; otherwise treat the
difference as a regression.

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

## 2026-08-08 cleanup preservation record

The autonomous phrase path from pre-cleanup `f14c3a8` was rendered again from a
temporary checkout and compared with the cleaned working tree. Both used the
same local machine and warmed SwiftPM/module caches. The PCM output was
bit-identical, so matched-loudness gain is exactly `1.0` and no audible-difference
claim is involved.

| Seed | Rate | Sample hash | RMS | True peak | DC | Low correlation | Boundary | Baseline / cleaned prep |
| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 42 | 44,100 | `194cfd9b41526538` | 0.109890 | 0.428781 | 0.000495 | 0.999959 | 0.021120 | 56.58s / 56.55s |
| 48,291 | 44,100 | `04dcfcadcf870950` | 0.112622 | 0.454291 | 0.000570 | 0.999963 | 0.019802 | 41.68s / 41.52s |
| 90,909 | 48,000 | `f22539221aaf3155` | 0.111463 | 0.436864 | 0.000725 | 0.999972 | 0.047000 | 28.59s / 28.68s |

The paired baseline/cleaned WAV SHA-256 values were respectively
`e80c04f30ef18a5a8e0aaa16b96d59a16e9be8b774fe5761049e51dc56a745ac`,
`7fb53b14e017cc7bcbf4988608d2b0666625c944d6e9a019e04adf6052dfd41b`,
and `718e225c7065452c12a1a856e009bdda3b920cc9aea2285ffa2e03ad0dbe2f48`.
Compact 8 kHz hashes for the same three seeds are retained as automated
regressions in `AutonomousArchitectureTests`.
