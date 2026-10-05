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

No semantic map impact: this change adds measurement evidence only; source, test, module, canonical state, runtime, validation, and contract ownership remain unchanged.
