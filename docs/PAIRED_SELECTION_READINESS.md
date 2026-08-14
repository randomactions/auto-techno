# Bounded Paired-Selection Readiness

## Status

This document records the operational foundation required before calibrated
paired selection can become the shipping policy. It does **not** activate
runtime ranking. The app still installs
`autotechno-candidate-evaluator.uncalibrated.v1`, renders one hard-valid primary
on the healthy path, and reports qualification unavailable.

The existing `AutonomousPhrasePreparer` remains the sole transaction owner. It
starts every attempt from the same incoming render, graph, quality, route, and
musical continuation; retains only reduced evidence for rejected attempts; and
atomically commits the selected immutable product. The readiness work adds no
renderer, score, runtime profile, user selector, callback work, or PCM change.

## Activation envelope

The preparation contract is bounded by existing engine constants and the new
`AutonomousPreparationResourceBudget` estimate:

| Property | Bound |
| --- | ---: |
| Authored candidates | 3 |
| Compared candidates | 2 |
| Correction renders | 1 |
| Total render passes | 4 |
| Phrase length | 1...16 bars |
| Calibrated representative rates | 44,100 and 48,000 Hz |
| Streaming analyzer storage | 6 MiB |
| Conservative numeric working storage | 128 MiB |
| Healthy paired lookahead | 7.385 s, one four-bar phrase |
| Full failure-path lookahead | 14.769 s, one phrase plus one frozen-topology hold |
| Post-comparison cancellation | less than 100 ms |

The numeric-storage estimate covers four conservatively live stereo phrase
products, every bounded variable-length render/graph continuation owner, a
64-mono-channel per-bar scratch allowance, streaming analysis, and reduced
evidence. It is intentionally more conservative than observed process RSS; RSS
is still measured independently because object/runtime overhead is not modeled
as numeric sample storage.

## Optimized representative-rate evidence

The exact-source release probe ran three maximum-size iterations at each rate.
Each healthy iteration rendered one 16-bar primary and alternate. Each failure
iteration rendered a 16-bar primary, alternate, home-timbre correction, and
conservative fallback. The source candidates were real director output; the
probe changed only their hard-valid interest result to force the already-bounded
four-pass path.

| Rate | Healthy median | Healthy p95/worst | Four-pass median | Four-pass p95/worst |
| --- | ---: | ---: | ---: | ---: |
| 44.1 kHz | 6.292 s | 6.372 s | 12.237 s | 12.247 s |
| 48 kHz | 6.866 s | 6.873 s | 13.354 s | 13.357 s |

- post-comparison cancellation: 0.014...0.032 ms;
- maximum resident set size: 80,461,824 bytes (76.73 MiB);
- resident-set increase during the isolated probe: 65,781,760 bytes;
- conservative 48 kHz numeric-storage estimate: 113,161,984 bytes
  (107.92 MiB).

Healthy paired preparation therefore fits the first successor window at both
rates. The maximum correction/fallback path fits one existing coherent
frozen-topology repeat and cannot consume a second. Cancellation is observed at
the next bounded candidate boundary without rendering correction or fallback.

Run the full probe only as an explicit optimized operational check:

```sh
AUTOTECHNO_RUN_PAIRED_BUDGET=1 \
AUTOTECHNO_PAIRED_BUDGET_ITERATIONS=3 \
swift test -c release --disable-sandbox --no-parallel \
  --filter operationalEnvelope
```

Normal CI runs only `representativeRateWorkingSetEnvelope`; the six expensive
maximum-path measurements remain opt-in so ordinary exact-head validation does
not grow by several minutes.

## Remaining activation proof

The current probe deliberately uses the package evaluator seam to exercise the
real render/correction/fallback transaction. It cannot by itself qualify the
shipping policy. Activation still requires all of the following in one change:

1. load the pinned profile and adversarial identity before detached preparation,
   with no bundle I/O, decoding, allocation, or analysis on the callback;
2. evaluate every applicable canonical checkpoint as a non-compensable vector,
   choose only a qualified primary/alternate, and preserve the conservative
   fallback when both fail;
3. persist the exact calibrated policy/evaluator identities and reason-coded
   transaction outcome, then replay that known policy during validation;
4. retain uncalibrated, single-primary playback at unsupported route rates or
   when the frozen artifacts are unavailable;
5. rerun this optimized probe through the exact shipping evaluator and repeat
   deterministic, route-recovery, stale-work, app, and sustained playback checks.

Until those proofs pass, the frozen development policy remains offline evidence
and professional runtime qualification remains unavailable.
