# Autonomous runtime validation

## Automated acceptance

Status: **passed 2026-08-08**. The complete Swift Testing run passed all 108
tests in 507.383 seconds, and the production configuration linked the app and
all three offline reference executables successfully.

`AutonomousArchitectureTests.swift` covers:

- deterministic session replay for seeds `42`, `48291`, `90909`, `7`, and
  `77777`;
- four adaptive history horizons, actual phrase boundaries, variable 4-16 bar
  phrases, structural ages, debt opening, and release payment;
- ensemble kick protection, complementary relocation, and foreground caps;
- 1,000 deterministic graph sequences with node, depth, branch, feedback,
  mutation, low-end, and reconstruction invariants;
- release/recovery mutation suppression, one-bar equal-power topology
  transitions, and two-bar retiring tails;
- synthetic primary/alternate/tie/fallback selection evidence;
- deterministic phrase audio, continuation-state replay, different-topology
  hash distinction, and finite/bounded 8 kHz, 44.1 kHz, and 48 kHz renders;
- stale preparation rejection and coherent late-successor repetition policy.

The app retains one accessible `transport-play-pause` button. Pause and resume
do not recreate the director or session state. Route changes invalidate stale
preparation, rebuild the current phrase at the active sample rate, freeze graph
mutation during recovery, and then rebuild the successor from continuation
state. All planning, graph generation, rendering, quality analysis, allocation,
and waveform work occurs in detached preparation; the player consumes immutable
buffers with sample-time scheduling.

## Hardware soak

The 60-minute release-build soak is a hardware validation step and must not be
inferred from unit tests. Record a dated result here after completing all of the
following on a real output route:

- continuous playback for 60 minutes;
- repeated pause/resume;
- output-device changes between 44.1 and 48 kHz routes;
- interruption and recovery;
- sleep and wake;
- no glitch, runaway level, stale phrase acceptance, crash, or unbounded memory
  growth.

Status: **pending physical-device run**.
