# Auto Techno

Auto Techno is a standalone macOS instrument that continuously performs a
canonical, indefinitely evolving dark, hypnotic techno set. The shipped
interface has one transport button: prepare, play, pause, and resume. It needs
no DAW, plug-in host, cloud service, model, or account.

## Runtime contract

- fixed 130 BPM;
- reproducible musical decisions for the same private initial and continuation state;
- phrase-boundary continuation with temporal memory, a global sixteen-bar
  arrangement grid, and dramatic-debt repair;
- a three-step upper-voice driver chained to a five-stage follower, with
  bounded sixteen-bar chapters for long-form evolution;
- one resolved per-bar score shared by audio and telemetry;
- generated upper-voice DSP graphs while kick and its bass, rumble, or tuned-tom
  companion keep a protected route;
- preparation-time role stems and a bounded automatic kick/foundation fader;
- a read-only waveform on one fixed decibel scale rather than per-bar normalization;
- detached preparation followed by sample-time scheduling of immutable buffers;
- route recovery at the active hardware sample rate;
- no allocation, locks, logging, file/network I/O, or UI work on the audio callback.

`AutonomousSessionDirector` owns the tempo and private canonical identity. It
proposes complete autonomous phrases, `AutonomousPhrasePreparer` selects and
validates one, and `AutonomousPhraseRenderer` produces the scheduled audio
blocks. Scene DNA, resolved performance bars, synth world, and synth
performance are required inputs; there is no compatibility or reference-render
mode.

## Package

The Swift package exposes one product:

```text
AutoTechno (executable)
```

`AutoTechnoCore` and `AutoTechnoDSP` are package-internal implementation targets.

## Build and test

Use a macOS Swift toolchain whose compiler and SDK Swift interfaces match:

```bash
swift test
swift build -c release
```

Automated checks cover reproducible session planning, temporal memory, debts,
ensemble arbitration, generated-graph validity and continuation, sample safety,
masking, and the single-product repository surface. Audible changes additionally
require a matched-loudness comparison of the canonical performance at named
structural checkpoints. Release readiness
also requires the physical-output soak described in
[`docs/AUTONOMOUS_RUNTIME_VALIDATION.md`](docs/AUTONOMOUS_RUNTIME_VALIDATION.md).

## Product documents

- [`docs/PRODUCT.md`](docs/PRODUCT.md) — product and interaction contract
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — current forward work
- [`docs/AUTONOMOUS_RUNTIME_PROVENANCE.md`](docs/AUTONOMOUS_RUNTIME_PROVENANCE.md) — runtime ownership and data flow
- [`docs/AUTONOMOUS_RUNTIME_VALIDATION.md`](docs/AUTONOMOUS_RUNTIME_VALIDATION.md) — validation and release gates
- [`docs/TASTE_LEDGER.md`](docs/TASTE_LEDGER.md) — distilled active taste direction

## License

Auto Techno is available under the MIT License. See [LICENSE](LICENSE).
