# Auto Techno

[![Swift CI](https://github.com/randomactions/auto-techno/actions/workflows/swift.yml/badge.svg)](https://github.com/randomactions/auto-techno/actions/workflows/swift.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

A native, standalone macOS instrument for deterministic generative techno. It owns composition, sequencing, synthesis, effects, long-form evolution, and playback; it does not require a DAW or plug-ins.

The shipped interaction is deliberately complete: **Play/Pause**. Tempo is fixed at 130 BPM. A deterministic autonomous director owns every musical destination and the route between scenes, leaving the listener focused on the performance rather than configuring it.

## First milestone

The current app contains a single autonomous performance path:

- deterministic scene succession and Persistent V3 phrase planning
- internal procedural drums, bass, musical voices, textures, effects, and mastering
- a local Alien Analog candidate that unifies motif, shadow, atmosphere, response, and transition roles behind one authored voice topology
- fixed 130 BPM with no editable musical or DSP controls
- detached pre-rendering, sample-time scheduled bars, and deterministic DSP tests
- one passive precomputed waveform; no FFT, audio tap, or UI work on the audio callback
- subtle deterministic warehouse swing on hats and bass; kicks remain grid-locked
- one Play/Pause button

This is deliberately a musical seed, not a prematurely broad workstation. The next product loop is: listen to fixed seeds `42`, `48291`, and `90909`, describe what feels right or wrong, encode one small taste rule, and compare again.

The v0.2 groove rule derives a restrained 50–56% swing from Drive, Hypnosis, and the seed. It delays eligible hats and bass notes within their step while leaving kicks and claps on the grid.

The v0.3 motif rule adds one or two deterministic notes per bar in a narrow dark scale. Hypnosis favors repetition, Drive may add a second note, and Shadow moves the register and timbre deeper. The motif is not directly edited; it remains a musical consequence of the existing intentions.

The v0.4 arrangement model gives the engine a multi-phrase form: eight phrases cycle through groove, build, breakdown, and return sections, with phrase lengths derived from the seed and pace of change. The transition director is now phrase-aware and can choose from all six transition narratives — subtle drift, element exchange, fill and turn, breakdown and return, long morph, and crash and cut — based on the distance between scenes and the position within a phrase. Section kinds modulate rendering intensity: breakdowns thin the arrangement, builds add energy, returns restore full density.

## Run

Requires macOS 14 or later and Swift 6. Full Xcode is recommended for app development.

```sh
git clone https://github.com/randomactions/auto-techno.git
cd auto-techno
swift run AutoTechno
swift test
```

Or launch it from any directory:

```sh
swift run --package-path /path/to/auto-techno AutoTechno
```

## Architecture

- `AutoTechnoCore`: deterministic music decisions with no UI or audio dependencies.
- `AutoTechnoApp`: the one-button SwiftUI surface and AVFoundation scheduler.
- `.agents/skills`: project-specific taste iteration and real-time audio workflows.
- `docs/PRODUCT.md`: the autonomous product and musical-intention contract.
- `docs/ROADMAP.md`: the living implementation plan, completion status, and ambitious long-term goals.
- `docs/TASTE_LEDGER.md` and `docs/MVP_REFERENCE.md`: learned taste evidence and fixed-seed comparison baselines.
- `docs/V2_LISTENING_GATE.md`: the fixed-seed v2 approval procedure and verdict table.
- `docs/JUKEBOX_LISTENING_GATE.md`: the Continuous four-scene long-play listening gate.
- `docs/V3_LISTENING_GATE.md`: the experimental Persistent v3 A/B listening gate.
- `docs/ALIEN_SYNTH_LISTENING_GATE.md`: the fixed-seed A/B/C instrument, interlock, and performance gate.

Former UI controls remain only as internal correlated musical dimensions. They are not app state and do not constrain future directors. Legacy engines, treatment switches, fixed-seed controls, and listening comparisons remain available through offline reference executables rather than the shipped interface.

## Direction

Near-term: deepen the autonomous director, long-form tension, and authored voice quality while keeping playback deterministic, smooth, and offline-capable. See the [living roadmap](docs/ROADMAP.md) for current status.

## Contributing and security

Human feedback and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Report vulnerabilities privately through [GitHub Security Advisories](https://github.com/randomactions/auto-techno/security/advisories/new), not in a public issue.

Auto Techno is licensed under the [Apache License 2.0](LICENSE).
