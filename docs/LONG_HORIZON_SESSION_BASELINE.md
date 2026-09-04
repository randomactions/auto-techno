# Long-Horizon Session Baseline

## Purpose

The long-horizon session baseline is a detached, score-only observatory for
continuous canonical planning journeys. It describes how authored session facts
develop across four hours without ranking the music, inferring listener response,
or influencing the runtime.

The canonical owners remain `AutonomousSessionDirector`,
`AutonomousPhrasePlan`, `AutonomousSessionState`, and
`LongHorizonContinuationState`. The baseline consumes their resolved output. It
does not select phrases, change continuation, render PCM, evaluate candidates,
adapt future decisions, schedule audio, or expose a user control.

## Fixed contract

`LongHorizonSessionBaselineAnalyzer` accepts contiguous
`LongHorizonSessionBaselinePhraseInput` values with these bounds:

- at most 16 bars per phrase;
- at most 8,192 bars per observation;
- fixed 32-bar segments;
- at most 256 segments;
- one root seed and exact phrase/bar continuity;
- canonical enum and capability ordering;
- finite authored tension, activity, repetition, and density values in `0...1`.

The report retains, without combining them into an opaque score:

- tension, activity, repetition, and density range, mean, largest step, and
  direction-change count per segment;
- high-tension and recovery-tension bar counts using the existing descriptive
  semantic thresholds;
- event-signature repeat counts and maximum identical runs;
- phrase-kind, long-horizon operator, section, and interlock-chapter bar counts;
- active-bar and maximum-run evidence for every established semantic capability;
- explicit payoff markers only for fulfilled `.payoff` / `.energyRelease`
  episode-operator phrases;
- explicit recovery markers only for fulfilled `.recover` / `.majorBreak`
  episode-operator phrases;
- payoff spacing and recovery latency, including explicit `null` fields and an
  `unresolved-within-horizon` status when no qualifying recovery occurs before
  the next payoff or the observation boundary.

These payoff and recovery records are score-declared structural proxies. They
must not be renamed perceptual peaks, releases, audience response, or perceived
fatigue.

## Signal and qualification boundary

The v1 observatory deliberately contains no continuous PCM. Every report states:

```text
realizedSignalAvailability: unavailable
realizedSignalUnavailableReason: score-only-no-continuous-pcm
qualificationStatus: unavailable
qualificationReason: descriptive-score-only-no-quality-rank
```

Sparse calibration checkpoints are not interpolated into a false continuous
signal curve. Therefore same-loudness/different-structure, loud non-payoff,
silence, effect-with/without-signal-change, and sample-rate comparisons cannot
produce signal conclusions in v1. Their truthful outcome is unavailable, not a
zero, pass, or fatigue verdict. Existing PCM, effect-dose, semantic-trajectory,
and calibrated professional-policy owners remain authoritative for their own
narrower evidence.

## Determinism and failure behavior

The analyzer uses a fixed aggregation order and a stable typed FNV-1a
fingerprint over every raw phrase and bar field. It fails closed for empty,
discontinuous, cross-root, oversized, non-finite, out-of-range, inconsistent,
or noncanonically ordered input. It returns no partial report.

Raw export encodes absent operator and unresolved spacing/recovery values as
explicit JSON `null`. Missing keys and explicit unresolved values are therefore
distinct and independently mutation-testable.

The local manifest binds:

- the seven-case corpus SHA-256;
- the contract-baseline fingerprint;
- the selected tracked and untracked source/test/script fingerprint;
- Git head and engine version;
- debug or release build configuration;
- the score-only observation route;
- analyzer schema, capacities, requested horizon, session-state fingerprints,
  artifact SHA-256 values, and per-journey report fingerprints.

Build configuration is evidence, not a selector. An export from one
configuration must be checked against that same configuration-bound manifest;
cross-configuration identity is not assumed.

## Local export and independent verification

The exporter is default-off and writes only ignored local evidence:

```sh
AUTOTECHNO_RUN_SESSION_TRAJECTORY_BASELINE=1 \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --filter LongHorizonSessionBaselineIntegrationTests

python3 scripts/session_trajectory_baseline_report.py
python3 scripts/session_trajectory_baseline_report.py --check
python3 -m unittest scripts/test_session_trajectory_baseline_report.py
```

The export lives under
`docs/local/reports/long-horizon-session-baseline-v1/`. Seven per-seed artifacts
retain the exact raw phrase/bar inputs and the Swift report. The Python checker
does not trust that report: it validates provenance and geometry, reconstructs
every segment, marker, spacing/recovery record, count, run, scalar summary, and
typed fingerprint from raw input, then compares the complete result.

## Current neutral baseline

The first v1 capture used the seven fixed `BASELINE_CORPUS.json` roots and four
hours of canonical planning per root. It retained 5,106 phrases, 54,651 bars,
1,710 segments, 75 explicit payoff markers, 68 explicit recovery markers, and
10 payoff markers unresolved at the observation horizon. These are descriptive
corpus facts only. They establish neither target ranges nor quality thresholds.

## Licensing and repository policy

The implementation and evidence schema are repository-authored
`GREEN-ORIGINAL`. No third-party DSP code, presets, samples, stems, plug-ins,
transcripts, or reference recordings participate. Raw artifacts remain local and
untracked; only the analyzer, tests, verifier, and this reproducible contract are
repository material.

## Runtime and real-time safety

All capture and analysis occur in opt-in tests or an offline Python process.
There is no render callback, live scheduler, audio buffer, graph mutation,
transport, route recovery, UI, or physical-output change. The unchanged
canonical runtime is the fallback whenever evidence is unavailable.
