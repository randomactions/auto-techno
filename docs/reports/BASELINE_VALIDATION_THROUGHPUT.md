# Matched stereo validation throughput

Three repeated checks saved **26.47 minutes** on the unchanged 224-asset accepted bank: 1632.990 seconds with independent cold recomputation and 44.609 seconds within one verified analysis session.

The experiment alternated cold subprocesses and one process-local `ValidationSessionRunner`, starting with one generate pair followed by three check pairs. Every stage passed. Input and source hashes, the original bank, and report bytes were checked before and after every stage.

| Pass | Cold seconds | Session seconds |
|---|---:|---:|
| Generate | 539.560 | 443.543 |
| Check 1 | 579.687 | 15.264 |
| Check 2 | 528.063 | 14.654 |
| Check 3 | 525.240 | 14.691 |

This measures the repeated stereo-validator work on one historical accepted bank. It does not measure an entire production-evidence refresh or establish a general roadmap or CI speed multiplier. It produces no new render, current producer currency, quality qualification, activation, or promotion.

The bank retains its original PCM source `5fe0c50db3c906b9132a07797febf19f843ec451` and contract fingerprint `10e3a47511428bd7492ea572556adfb5af23380aac5764d08d8ee5e02edb2208`. All eight reports have SHA-256 `b05fc92378bc0b345d6e20171970ebc57fb6987d63a59c6f8bddac4dacbd76fc`. PCM remains local and untracked.

The JSON record preserves the earlier benchmark unchanged and adds the matched experiment, stage timings, log hashes, frozen-input receipt hash, and analyzer source hashes. Session reuse remains bounded and process-local; changed or corrupted PCM, analyzer code, configuration, or context invalidate it. Required content checks and aggregate gates remain mandatory.

## Hosted CI observation

At 23:02:55 UTC on 2026-10-05, [GitHub Actions run 37378629887](https://github.com/randomactions/auto-techno/actions/runs/37378629887) for commit `62e8045d739d69f799b871818a82eb62d6f349f0` had four bank jobs on four distinct runners labelled `macos-15`. All four jobs overlapped from 22:22:45 to 22:53:23 UTC: **1,838 seconds (30 minutes 38 seconds)**. This interval includes job setup, builds and tests.

| Bank | Job ID | Runner ID | Started UTC | Status at observation |
|---|---:|---:|---|---|
| foundation | 111994610311 | 1000001136 | 22:22:45 | In progress |
| modal | 111994610290 | 1000001134 | 22:00:59 | In progress |
| primary | 111994610371 | 1000001135 | 22:12:07 | In progress |
| remaining | 111994610061 | 1000001133 | 21:51:58 | Success at 22:53:23 UTC |

The retained selected GitHub job-timing response has SHA-256 `1b33962c12f7aa18f3b7dcf9ebf0a3c304b823c75eb2a3a00bc04bab0d7d8e1d`. The timestamps and runner identities demonstrate actual hosted job concurrency. They do not establish four simultaneous test methods, terminal aggregate success, a matched serial-versus-parallel wall-time comparison, or an overall CI speed multiplier. Required aggregate success remains mandatory.

No semantic map impact: this change adds measurement evidence only; source, test, module, canonical state, runtime, validation, and contract ownership remain unchanged.
