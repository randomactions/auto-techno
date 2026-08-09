# Auto Techno

Auto Techno is a standalone macOS instrument that continuously performs one
canonical, indefinitely evolving dark, hypnotic techno set. Its interface has
one transport button for prepare, play, pause, and resume. Playback requires no
DAW, plug-in host, VSTi, Audio Unit instrument or effect, cloud model, or
account.

## Current runtime

- fixed 130 BPM and one private canonical identity;
- reproducible musical decisions for the same initial and continuation state;
- one resolved per-bar score shared by planning, audio, and telemetry;
- phrase-boundary continuation with temporal memory and bounded fallback;
- three score-selected internal synthesis architectures with bounded patch
  automation and exact score-to-PCM evidence;
- engine-owned synthesis, effects, mixing, and output safety;
- detached preparation followed by sample-time scheduling of immutable buffers;
- route recovery at the active hardware sample rate;
- no allocation, locks, logging, file or network I/O, or UI work on the audio
  callback.

`AutonomousSessionDirector` proposes complete phrases,
`AutonomousPhrasePreparer` validates a bounded choice, and
`AutonomousPhraseRenderer` produces the scheduled audio blocks. There is one
shipped runtime and no compatibility engine, render profile, selectable seed,
or comparison mode.

## Engine direction

The project goal is professional release-quality sound produced entirely by the
in-house engine. This is an iterative engineering target, not a claim about the
current output. Each musical change must strengthen the same autonomous
generate, render, evaluate, and adapt loop instead of introducing another
top-level mechanism.

The current runtime already performs detached safety and structural evaluation.
The roadmap extends that foundation into multidimensional automated quality
qualification and bounded feedback from app-owned output. Optional human
feedback may identify a deficit, but it is not a required curation or promotion
gate. Legal reference recordings and external analyzers may be used locally for
development; neither they nor third-party instruments or effects are runtime
dependencies.

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
swift build -c release --product AutoTechno
```

Current automated checks cover reproducible planning, continuation, generated
graphs, role routing, signal safety, and the single-product surface. Professional
quality is not established until every automated, app/runtime, and
physical-output gate in the validation contract passes for the exact release
revision.

## Product documents

- [`docs/PRODUCT.md`](docs/PRODUCT.md) — stable product and interaction contract
- [`docs/INSTRUMENT_PALETTE.md`](docs/INSTRUMENT_PALETTE.md) — internal synth, patch, role, automation, and effect matrix
- [`docs/SOUND_QUALITY.md`](docs/SOUND_QUALITY.md) — professional-sound and automated-quality contract
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — ordered engine-evolution outcomes
- [`docs/AUTONOMOUS_RUNTIME_PROVENANCE.md`](docs/AUTONOMOUS_RUNTIME_PROVENANCE.md) — runtime ownership and feedback flow
- [`docs/AUTONOMOUS_RUNTIME_VALIDATION.md`](docs/AUTONOMOUS_RUNTIME_VALIDATION.md) — current validation and release gates
- [`docs/VIDEO_ANALYSIS_PROTOCOL.md`](docs/VIDEO_ANALYSIS_PROTOCOL.md) — source-evidence protocol for video-derived hypotheses
- [`docs/history/TASTE_EXPERIMENTS.md`](docs/history/TASTE_EXPERIMENTS.md) — non-normative historical experiments
- [`docs/history/VALIDATION_SNAPSHOTS.md`](docs/history/VALIDATION_SNAPSHOTS.md) — non-normative historical validation records

## License

Auto Techno is available under the Apache License 2.0. See [LICENSE](LICENSE).
