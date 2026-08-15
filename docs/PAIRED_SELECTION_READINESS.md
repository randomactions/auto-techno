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

## Exact-engine candidate policy

The repository now also carries a separate immutable paired-policy profile for
canonical engine v19 (`4b55055d1904ead8`), its passing ten-case adversarial
suite (`a34c3ba6acec9c2e`), and a qualified disjoint holdout report
(`c333586ce068d5af`). This does not replace or relabel the historical engine-v10
development profile. Loading the paired resources requires the exact current
engine and Professional Evidence v4 identities; a stale profile, incomplete
suite, failed holdout, source overlap, or fingerprint mismatch fails
construction.

The detached evaluator projects a complete candidate into the same 39-metric
vector used by the journey report bank for every Core-owned checkpoint that the
candidate represents. Each checkpoint is judged independently. There is no
aggregate score and no distance-to-profile optimization: one accepted candidate
wins, two accepted candidates deterministically retain the primary, two rejected
candidates request the existing conservative fallback, and missing, inapplicable,
or unsupported-rate evidence remains unavailable. Profile trajectory and
cross-rate relationships remain whole-bank development gates; they are not
misrepresented as facts available from one candidate.

The profile was generated from 28 complete canonical journeys at all seven
checkpoints and both 44.1 and 48 kHz (392 observations). Every calibration
journey passed its local and phrase/rate relationships, and all ten
non-compensable adversarial scenarios were rejected for their expected reasons.
Four separately generated replacement holdouts then passed 56/56 local verdicts
and zero relationship failures. Short-program EBU-style LRA stays descriptive
because its gated percentile population is unstable at small counts; integrated,
momentary, short-term, true-peak, hard-safety, spectral, masking, and the other
stable dimensions remain evaluative.

The paired evaluator is now version 3. After the primary evidence exists it
requests an alternate only when the phrase maps to a calibrated checkpoint at a
covered rate. `ProfessionalQualityPreparationEvaluator` is a preloaded,
route-local boundary: exact current artifacts at 44.1/48 kHz delegate to the
paired evaluator, while missing artifacts and unsupported rates retain the
existing uncalibrated identity and single-primary behavior. The wrapper performs
no bundle I/O. It is not installed by either app-facing preparation overload.

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

Normal CI runs `representativeRateWorkingSetEnvelope` plus the inexpensive
unsupported-route single-primary contract; the six expensive maximum-path
measurements remain opt-in so ordinary exact-head validation does not grow by
several minutes.

## Exact-policy operational evidence

The exact pinned evaluator was then replayed through three maximum 16-bar
transactions at each calibrated rate. Immutable artifacts loaded before the
timed region in 0.020 seconds. The transaction remained deterministic, the
hard-safe score-owned fallback crossed the atomic commit boundary only when the
selected slot was actually `.fallback`, and unsupported-rate replay stayed on
one uncalibrated primary. The exact path measured:

| Rate | Median | p95/worst | Result |
| --- | ---: | ---: | --- |
| 44.1 kHz | 9.545 s | 9.549 s | conservative fallback |
| 48 kHz | 10.385 s | 10.448 s | conservative fallback |

- post-comparison cancellation: 0.042...0.048 ms;
- maximum resident set size: 81,559,552 bytes (77.78 MiB);
- resident-set increase: 63,242,240 bytes;
- deterministic transaction fingerprints: `9dd25ed8f2d50514` at 44.1 kHz and
  `b4723625fa4bcb69` at 48 kHz.

The original single-journey artifact used by this historical probe failed
generalization. The unseen
representative primary missed establishment bounds for bar centroid span, bar
crest-factor span, maximum boundary delta, and phrase-wide RMS trajectory peak
at both rates. The alternate still missed maximum boundary delta and RMS
trajectory peak at both rates, plus spectral rolloff at 48 kHz. Because the
then-current profile was derived from one seed journey (`48291`), this was
evidence of insufficient generalization, not permission to widen individual
thresholds. The diverse replacement profile and holdouts above close that
offline quality blocker; the historical timings remain the latest exact-policy
operational measurement until the explicit activation build is replayed.

Run the exact check explicitly:

```sh
AUTOTECHNO_RUN_EXACT_PAIRED_POLICY=1 \
AUTOTECHNO_EXACT_PAIRED_ITERATIONS=3 \
swift test -c release --disable-sandbox --no-parallel \
  --filter exactEvaluatorOperationalEnvelope
```

Normal CI adds the inexpensive unsupported-route single-primary contract. The
six maximum exact-evaluator renders remain opt-in.

## Remaining activation proof

The immutable loader, preloaded route boundary, non-compensable comparator,
fallback result, exact transaction replay, unsupported-route fallback, diverse
profile, adversarial suite, disjoint holdout, and operational probe are
implemented behind the package seam. The first two former activation blockers
are closed offline. The app-facing preparation overload deliberately still
installs the uncalibrated evaluator.

Activation therefore remains one explicitly authorized change: install the
already-preloaded evaluator off the callback and repeat deterministic,
route-recovery, stale-work, app, physical-route, and sustained playback checks
on that exact build. Until then, the frozen development policy remains offline
evidence and professional runtime qualification remains unavailable.
