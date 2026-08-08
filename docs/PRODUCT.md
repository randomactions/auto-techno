# Product contract

Auto Techno is a standalone generative techno jukebox. It owns composition, arrangement, synthesis, effects, mixing, transitions, and playback. Its complete shipped control surface is one Play/Pause button. Tempo is fixed at 130 BPM. The engine—not the listener—must sustain a large musical space without exposing production work.

## Central invariant

Every engine decision is a musical intention, never a direct DSP mutation. The app must make both the destination and the journey musically coherent.

An autonomous director creates target scenes, compares each with what is currently sounding, and performs an appropriate path: subtle drift, element exchange, fill, breakdown and return, long morph, or an intentional crash and cut. Duration is a musical decision and may range from immediate to many minutes.

Play/Pause changes transport state only. It never regenerates, randomizes, or resets the musical plan. The invariant applies to autonomous evolution and any future external control.

## Language boundary

The primary UI does not ask the listener to describe or operate the music. It contains Play/Pause, passive transport context, and an inexpensive precomputed waveform.

Technical terminology and development switches belong in offline reference and diagnostic tooling, not the shipped window. Future monitoring may be added only when it is read-only, coalesced, and demonstrably cheap.

Diagnostic tooling should make internal behavior legible at several levels:

- voice activity and generated notes or triggers;
- oscillator, envelope, filter, modulation, distortion, delay, echo, reverb, and other effect parameters;
- mixer levels, panning, routing, headroom, loudness, and limiting activity;
- current value, target value, direction and rate of change;
- the musical intention and transition event responsible for a change;
- timing context such as step, bar, phrase, scene, and estimated transition completion.

Values must be sampled or precomputed away from the audio callback. The shipped waveform is derived once from immutable render blocks and only its playhead is updated at 15 Hz. Diagnostic tools may support search, grouping, and history, but technical values remain non-editable.

This is not merely renaming or hiding technical controls. One musical intention may coordinate rhythm generation, voice allocation, timbre, arrangement, spatial depth, dynamics, and transition behavior. Conversely, one DSP parameter may serve several intentions depending on context. Diagnostic evidence must expose that mapping when engineers need to inspect it.

## Internal musical-intention graph

The former control tree remains useful as a correlated internal vocabulary. It is not rendered as UI and is not owned by app presentation state. The autonomous director may coordinate or extend these dimensions without creating new controls.

```text
Music
├── Motion
│   ├── Groove (never zero)
│   ├── Syncopation
│   ├── Straight ↔ Broken
│   └── Polyrhythm
├── Character
│   ├── Shadow
│   ├── Space
│   │   └── Fog
│   ├── Hypnosis
│   └── Impact
├── Musicality
│   ├── Melodicity
│   ├── Synth presence
│   └── Note activity
├── Uncertainty
│   ├── Overall chaos
│   ├── Drum chaos
│   ├── Synth chaos
│   └── Space and texture chaos
├── Evolution
    ├── Overall pace of change
    └── Per-branch pace overrides
└── Sequencer ambient
    ├── Presence
    ├── Behavior (pulse network, arpeggiated motif, textural step field)
    ├── Density
    ├── Register
    ├── Repetition
    ├── Drift
    └── Depth
```

The tree is not fixed forever. New dimensions require documented, audible consequences and fixed-seed comparisons. Avoid synonyms that manipulate the same latent dimension.

## Internal intention semantics

Each internal musical dimension must define:

- its audible promise in listener language;
- its contextual mapping to composition, arrangement, and rendering decisions;
- safe and musically useful bounds;
- interactions with related dimensions;
- allowed transition strategies and timescales;
- fixed seeds or listening cases that demonstrate low, middle, and high values.

Values are destinations, not instantaneous assignments. A high internal value means “strongly pursue this quality while preserving the other invariants,” not “maximize every associated DSP parameter.”

Sequencer ambient is an optional drum-locked layer distinct from the sustained
drone. Its events are generated from safe kick/hat positions, vary at phrase
boundaries, and remain subordinate to the kick and bass. Its behavior is a
semantic choice between a repeating pulse network, an arpeggiated motif, and a
textural step field; these are not direct synthesis modes.

`Groove` has a non-zero floor. Low groove may be rigid, sparse, or severe, but it must remain intentional rather than rhythmically broken.

The v0.2 warehouse groove keeps kick anchors sample-grid locked and derives a bounded 50–56% swing for eligible hats and bass events. Timing offsets are deterministic from the scene seed and never cross a quarter-note boundary; this is an internal musical consequence of existing intentions, not a direct timing control.

The v0.3 melodic voice is a single sparse motif: one guaranteed note and an optional second note per bar, chosen from a narrow minor/modal vocabulary. It stays below the kick and bass in level, avoids kick starts, and is rendered as a derived scene event rather than an editable note or synthesis control.

The Alien Analog candidate treats every upper musical role as one instrument
ecosystem rather than a collection of recognizable synth, pad, lead, acid, and
drone functions. A seed-derived `SynthPerformancePlan` preserves the anchor
motif while coordinating reveal, interlock, corrosion, suspension, and release.
Its 5-in-16 shadow pattern, continuous seven-step accent clock, and three-step
echo gate never alter the kick, bass, primary-hat, or clap schedules.

The candidate renders through band-limited interacting oscillators, parallel
anchor/mutation paths, pre-emphasis and wavefolding, asymmetric saturation,
nonlinear feedback filtering, correlated drift, comb/all-pass coloration, and
an unsynchronised filtered echo. Only active nonlinear voice work is 2×
oversampled; mutation and echo paths are high-passed before the existing
ducking, masking, spatial, and master stages. The frozen 19-stage texture path
is reference-only and must not be reintroduced into the app alongside the new
chain. Promotion remains subject to the fixed-seed listening and release-time
performance gates in `ALIEN_SYNTH_LISTENING_GATE.md`.

## Scene and transition model

A scene contains semantic intentions plus deterministic musical decisions. DSP state is derived from it and is never the source of truth for the user experience.

```text
current scene + target intention + context
    → musical difference analysis
    → transition narrative
    → phrase-aware event plan
    → internal DSP and mixer
```

Autonomous evolution samples a valid target in semantic space. It must respect invariants and correlated constraints before transition planning begins. Randomizing each low-level value independently is forbidden.

## Safety is necessary, not sufficient

The engine prevents clipping, clicks, runaway feedback, unsafe resonance, accidental silence, uncontrolled masking, and arbitrary off-grid structural changes. Those checks prevent technical failure. Taste rules, phrase awareness, contrast, restraint, and learned comparisons are what make the result musical.
