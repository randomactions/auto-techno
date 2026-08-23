# Auto Techno

Auto Techno is a standalone macOS instrument that continuously performs one
canonical, indefinitely evolving dark, hypnotic techno set. Its interface has
one transport button for prepare, play, pause, and resume. Playback requires no
DAW, plug-in host, VSTi, Audio Unit instrument or effect, cloud model, or
account.

## Current runtime

- fixed 130 BPM and one private canonical identity per complete performance;
- one fresh opaque App-owned session seed at each complete performance boundary,
  with reproducible musical decisions for the same explicit initial and
  continuation state;
- one resolved per-bar score shared by planning, audio, and telemetry;
- phrase-boundary continuation with temporal memory and accepted-PCM hold;
- three score-selected internal synthesis architectures with bounded patch
  automation and exact score-to-PCM evidence;
- one shared Resonant Mono TPT/ADAA nonlinear core with bounded semantic
  modulation, exact continuation, and same-pass input/output evidence;
- one fixed first-order ADAA source conditioner on the existing complete kick
  body, sub, and click sum, before the canonical detector/audible buses, with
  same-pass pre/post transient and spectrum evidence;
- one score-owned protagonist spectral reveal that reuses the existing
  Resonant Mono or Tonal Motion anchor filter, preserves exact home PCM, and
  retains independent score/render plus isolated-anchor evidence;
- six phrase-scale performance characters coordinating foundation, rhythm,
  role-compatible patches, and automation under one persistent identity;
- one score-owned phrase-composition layer with bounded true percussion
  resampling, 8–16-step modal arpeggiation, four-voice pads, progressive
  harmonic disclosure with exact arpeggiator pitch binding, and cross-bar
  minimal-motion voice-leading;
- one score-owned three-sixteenth pad rhythm that reuses the existing pad,
  filter, and spatial send, including a click-safe closed/open/closed amplitude
  projection with exact neutral and closed-step silence evidence;
- one score-owned six-mode modal-percussion foundation voice with bounded
  four-slot continuation, protected routing, and rate-normalized pitch,
  envelope, spectral, masking, and stability evidence;
- one bounded two-bar dotted foundation relation that reuses the protected
  Bass Pluck path, preserves the kick clock, and returns at the phrase boundary
  without adding another bass track, sequencer, or spatial return;
- one score-derived terminal release on the eligible dotted Bass Pluck event
  immediately before an owned kick, creating a bounded exact-zero dry-
  foundation pocket without a sidechain, EQ, new track, or callback control;
- one post-arbitration upper-percussion tail policy that reuses the existing
  clap, open-hat, and metallic voices, preserves their attack, and shortens
  their release only when another score role owns the foreground;
- one response-only Voltage Arc patch inside the existing Spectral Texture
  instrument that folds a low antialiased saw into a moving driven upper
  harmonic tail, with exact causal energy evidence and no added track or bus;
- one score-owned percussion-return relation that reuses the existing weak
  percussion as either a later gated answer or a bounded pre-release
  anticipation swell, without adding a track, instrument, or effect bus;
- one score-owned terminal climax hang that fades the final withheld bar into
  an exact one-beat absence while canonical DSP state advances underneath and
  the unchanged recovery remains on the next structural boundary;
- one score-owned eight-line stereo FDN late field with bounded decay, damping,
  continuation, protected low end, and exact per-bar consequence evidence;
- one scheduled-output live-feedback path that maps app-owned mixer PCM to the
  canonical phrase ledger, analyzes the first exact three-second window off the
  callback, and can commit only a bounded attenuation to unscheduled future PCM;
- engine-owned synthesis, effects, mixing, and output safety;
- detached preparation followed by sample-time scheduling of immutable buffers;
- route recovery at the active hardware sample rate;
- no allocation, locks, logging, file or network I/O, or UI work on the audio
  callback.

`AutonomousSessionDirector` proposes complete phrases,
`AutonomousPhrasePreparer` renders and judges that one bounded plan, and
`AutonomousPhraseRenderer` produces the scheduled audio blocks. There is one
shipped runtime and no compatibility engine, render profile, selectable seed,
or comparison mode.

## Engine direction

The project goal is professional release-quality sound produced entirely by the
in-house engine. This is an iterative engineering target, not a claim about the
current output. Each musical change must strengthen the same autonomous
generate, render, evaluate, and adapt loop instead of introducing another
top-level mechanism.

The current runtime performs detached safety and structural evaluation, installs
one calibrated multidimensional primary evaluator, and closes one bounded
master-headroom loop from app-owned scheduled PCM to an unscheduled future
phrase. The callback performs only a fixed copy into a preallocated C11 atomic
handoff; analysis, profile lookup, decisions, preparation, and commit remain off
the callback. See [`docs/LIVE_FEEDBACK.md`](docs/LIVE_FEEDBACK.md) for ownership,
failure-hold, lifecycle, and qualification boundaries. Optional human feedback
may identify a deficit, but it is not a required curation or promotion gate.
Legal reference recordings and external analyzers may be used locally for
development; neither they nor third-party instruments or effects are runtime
dependencies.

The long-horizon foundation now includes an offline, fixed-capacity Core
semantic-trajectory report and one compact renewable arc/episode continuation
inside canonical session memory. The one existing director now consumes the
exact bound episode at an unscheduled phrase boundary, maps it onto the existing
phrase vocabulary, records versioned selection provenance, and projects the
episode's eight-coordinate energy target through existing score owners with an
exact all-hold fallback. The report is still not consumed by the shipped
evaluator; effect-dose/sentence evidence, realized trajectory qualification,
and calibrated long-horizon adaptation remain unavailable.

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
- [`docs/PERFORMANCE_GRAMMAR.md`](docs/PERFORMANCE_GRAMMAR.md) — phrase character, foundation behavior, compatibility, and evidence matrix
- [`docs/LONG_HORIZON_PERFORMANCE_MAP.md`](docs/LONG_HORIZON_PERFORMANCE_MAP.md) — source-grounded hour-scale trajectory, state, evidence, and implementation map
- [`docs/LONG_HORIZON_SOUND_CAPABILITIES.md`](docs/LONG_HORIZON_SOUND_CAPABILITIES.md) — follow-up DSP, synth, patch-family, and effect maturation register
- [`docs/SPATIAL_ENGINE.md`](docs/SPATIAL_ENGINE.md) — canonical FDN ownership, bounds, continuation, evidence, and qualification boundary
- [`docs/NONLINEAR_DSP_CORE.md`](docs/NONLINEAR_DSP_CORE.md) — canonical TPT/ADAA ownership, bounds, evidence, and qualification boundary
- [`docs/SOUND_QUALITY.md`](docs/SOUND_QUALITY.md) — professional-sound and automated-quality contract
- [`docs/PRIMARY_EVALUATOR.md`](docs/PRIMARY_EVALUATOR.md) — calibrated single-plan runtime judgment and commit boundary
- [`docs/LIVE_FEEDBACK.md`](docs/LIVE_FEEDBACK.md) — scheduled-output evidence, bounded master-headroom control, and lifecycle contract
- [`docs/SOUND_CONCEPT_MATURITY.md`](docs/SOUND_CONCEPT_MATURITY.md) — durable musical concepts and the richer DSP that may replace their current realization
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — ordered engine-evolution outcomes
- [`docs/AUTONOMOUS_RUNTIME_PROVENANCE.md`](docs/AUTONOMOUS_RUNTIME_PROVENANCE.md) — runtime ownership and feedback flow
- [`docs/AUTONOMOUS_RUNTIME_VALIDATION.md`](docs/AUTONOMOUS_RUNTIME_VALIDATION.md) — current validation and release gates
- [`docs/VIDEO_ANALYSIS_PROTOCOL.md`](docs/VIDEO_ANALYSIS_PROTOCOL.md) — source-evidence protocol for video-derived hypotheses
- [`docs/history/TASTE_EXPERIMENTS.md`](docs/history/TASTE_EXPERIMENTS.md) — non-normative historical experiments
- [`docs/history/VALIDATION_SNAPSHOTS.md`](docs/history/VALIDATION_SNAPSHOTS.md) — non-normative historical validation records

## License

Auto Techno is available under the Apache License 2.0. See [LICENSE](LICENSE).
