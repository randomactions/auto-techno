# Auto Techno long-term roadmap

This roadmap takes Auto Techno from the current MVP toward a standalone,
procedural techno jukebox with a distinctive dark hypnotic sound and learned
taste.

## Current status

| Area | Status | Notes |
| --- | --- | --- |
| Shipped UI | One-button | Play/Pause is the only control. Tempo is fixed at 130 BPM; the waveform and position text are passive. |
| Shipped runtime | Original autonomous session | Adaptive bounded memory, variable phrases, ensemble arbitration, two-stage preflight, and validated generated upper-voice topology are the sole app path. |
| MVP renderer | Reference-only | Retained for reproducible offline comparison; removed from the app runtime. |
| Teach Taste | Reference-only | The local model and historical evidence remain available to offline tools; teaching and persistence are removed from the app. |
| v2 32-bar orchestration | Done | Deterministic sections, modulation lanes, events, and bus state. |
| v2 independent voices | Approved; refinement continues | Procedural kick, bass, hats, clap, tuned tom, metallic percussion, phase-continuous pad, evolving noise, synth, delay, texture rack, and bounded stereo motion are part of the approved v2 baseline. |
| Persistent v3 performance model | Reference-only | Retained for offline executables and regression comparison; removed from app-level selection and playback. |
| 96-bar performance compiler | Reference-only | Dramatic debt/payoff planning and the authored Shadow Pressure instrument remain reproducible offline comparison paths. |
| Generated DSP topology | Integrated | Repository-owned upper-voice processors are assembled into validated acyclic graphs with fixed low-end/master routing, one mutation per phrase, one-bar crossfades, and two-bar tails. |
| Alien Analog synth ecosystem | Implemented candidate; not promoted | Unified persistent voice topology, semantic synth gestures, 5-in-16/seven-step/three-step interlocks, timbre guards, and fixed-seed A/B/C evidence are complete. Objective audio checks pass, but the release preparation ratio is `2.37×` versus the required `1.10×`; listening is also pending. |
| v2 quality gate | Done | Approved 2026-07-13: v2 is preferred for its less-generic identity and fatter sound. |
| MVP reference artifacts | Done | Fixed-seed polished/sketch metrics, hashes, generator, and six stereo WAV renders are frozen. |

## Current gates

| Gate | State | Evidence / next action |
| --- | --- | --- |
| Approved v2 baseline | Passed | User-approved fixed-seed v2 direction; preserve as the comparison baseline. |
| Persistent v3 listening evidence | Still useful | The app runtime is simplified to this path; [V3_LISTENING_GATE.md](V3_LISTENING_GATE.md) remains the sound-quality comparison record. |
| Continuous jukebox long-play | Listening pending | Use the eight-scene artifact and transition table in [JUKEBOX_LISTENING_GATE.md](JUKEBOX_LISTENING_GATE.md). |
| V2 leap prototype | Listening pending | Compare current V3, dramatic planning with the legacy voice, and dramatic planning with the authored patch using [LEAP_LISTENING_GATE.md](LEAP_LISTENING_GATE.md). |
| Alien Analog V1 | Blocked from promotion | Use [ALIEN_SYNTH_LISTENING_GATE.md](ALIEN_SYNTH_LISTENING_GATE.md). All fixed-seed quality/timbre/structure checks pass; median release preparation is `1.92 s` versus `0.81 s` for A, so the strict `≤1.10×` performance gate fails at `2.37×`. |
| One-button window | Build passed; visual smoke pending | New minimum is 480×390 and the transport identifier is `transport-play-pause`. |
| Audio route recovery | Implemented; hardware soak pending | Current/next variable phrases rebuild at the new rate, stale tasks are rejected, mutation is suppressed during recovery, and the required 60-minute physical-device soak remains pending. |
| Deterministic/offline safety | Passed | All 108 Swift tests pass, including 1,000 graph sequences and fixed-seed 8 kHz plus representative 44.1/48 kHz renders. |

## Phase 0 — Freeze the MVP reference

Status: **Done**

Preserve seeds `42`, `48291`, and `90909` as the stable comparison set.
Record render metrics for MVP, polished, and sketch paths:

- peak and true-peak estimate;
- RMS/loudness;
- crest factor;
- stereo correlation;
- boundary continuity;
- deterministic hash.

The current frozen polished/sketch metrics, hashes, and generated WAV artifacts are recorded in
[docs/MVP_REFERENCE.md](MVP_REFERENCE.md); the metric implementation includes
the 4× true-peak estimate.

The MVP is a reference baseline, not the quality target.

Gate: reference renders and metrics are reproducible after a clean reset.

## Phase 1 — v2 procedural foundation

Status: **Done for the current scaffold; refinement continues in Phases 2–5**

Maintain a parallel pure-DSP engine with explicit state and interfaces:

- `V2RenderState`;
- `V2RenderBlock`;
- `V2VoiceEvent`;
- `V2BusState`;
- deterministic 32-bar arrangement;
- phrase modulation lanes;
- explicit voice and effect buses.

The v2 quality harness now reports complete-32-bar peak, RMS, DC offset,
stereo correlation, inter-bar boundary delta, finite-sample status, and a
deterministic sample hash for fixed-seed regression checks.
It now also reports a 4× cubic-interpolated true-peak estimate.
The report separately measures low-passed stereo correlation to guard the
mono-compatible kick/bass requirement.

The development A/B treatment now applies to v2 as well: polished uses the
full stateful texture rack, while sketch renders the same deterministic voices
without that rack. Both paths are tested for finite output and distinct hashes.

Integration hardening completed: procedural pre-rendering follows the active
output sample rate and rebuilds its blocks when the route rate changes. It
also listens for audio-engine configuration changes, clears queued render
state, and resumes through the normal scheduler when possible. Production
interruption telemetry and sustained route-switch testing remain outstanding.
Route recovery now retries a transient failed restart up to three times on the
main actor with bounded delays before reporting the route unavailable; no retry
or status work runs on the audio render callback.
The initial Play path uses the same recovery loop after a transient engine-start
failure, so a user does not need to press Play repeatedly to recover a route.

Responsiveness is now structural rather than debounce-based. The app prepares
the current and next immutable 32-bar Persistent V3 performances in a detached
worker, keeps only those two positions, and schedules one bar ahead by sample
time. Slider storms, target-scene churn, six-entry intent caches, BPM drift,
taste previews, and app-level engine switching no longer exist. If the next
scene is unexpectedly late, the scheduler repeats the coherent current scene
instead of blocking or leaving an audio gap.

The passive waveform is reduced to 64 RMS buckets during detached preparation.
Only its playhead is sampled on the main actor at 15 Hz; there is no FFT, audio
node tap, callback telemetry, or per-frame DSP analysis.

Gate: identical seed, intent, BPM, and engine version produce identical 32-bar
output with bounded headroom and safe stereo correlation.

## Phase 2 — Procedural voice identity

Status: **Approved; performance structure implemented; refinement continues**

Replace the v2 scaffolding with refined, phase-continuous voices:

- tuned kick with body, sub, pitch snap, transient, and harmonic saturation;
- modal bass with note contours, filter envelopes, and kick-aware ducking;
- metallic hats with band-limited oscillators and deterministic variation;
- clap/snare with body, noise, and room component;
- tuned toms, fills, cymbal textures, and sparse percussion;
- synth motif, response voice, and texture voice;
- evolving filtered noise/air bed with deterministic section-aware level;
- band-limited oscillator primitives and bounded filters.

The v2 motif now uses deterministic polyBLEP saw and pulse oscillators with a
phase-continuous detuned layer, replacing the earlier sine-only blend.

Build and return sections now also receive a sparse modal lead response, using
the same band-limited primitives and a persistent phase state.

Breakdown sections now retain a low-level harmonic drone, giving subtraction
sections a continuous identity instead of a hard empty hole. Build/return
sections also receive deterministic open-hat tails, and return phrases receive
a four-hit tuned-tom fill on their final bar when drum chaos is sufficient.
When the semantic polyrhythm value is elevated, build/return sections also
receive a sparse three-against-four metallic accent lane.
The final two bars of build phrases also receive a restrained upward riser.

The main synth voice now adds bounded analog-inspired PWM and slow oscillator
drift. Pulse width follows semantic darkness and moves deterministically over
the phrase, giving the oscillator a less static old-synth character without
introducing uncontrolled modulation or aliasing.

The first real-sound vertical-slice pass deepens that voice with a bounded
resonant two-stage filter, deterministic phrase-scale cutoff motion, oscillator
interaction, and controlled saturation. Resonance is derived from semantic
synth chaos and hypnosis rather than exposed as a raw DSP control. This is an
audible foundation for plugin-like voice patches; fixed-seed safety and
determinism pass, while listening approval remains pending.

A semantic sequencer/ambient voice is now implemented as a first structured
intertwining layer. Pulse-network, arpeggiated-motif, and textural-step-field
variants are generated deterministically, remain locked to safe hat/kick
positions, and expose presence, density, register, repetition, drift, and
depth as listener-facing semantic controls. Core tests cover determinism,
variant identity, and drum-safe placement.
Pulse-network mode now uses a bounded acid-style oscillator/filter voice with
persistent phase and filter memory, giving that mode a distinct old-synth
identity while retaining the same safe event placement.

The renderer now derives a deterministic `SceneDNA` and `PerformancePlan`
before audio generation. Scene DNA preserves tonal center, modal vocabulary,
rhythm cells, motif identity, characteristic syncopations, and foreground
role priority. The performance plan gives each 32-bar scene a deterministic
dramatic thesis, asymmetric phrase lengths, bounded transformations, rare
phrase-bound signature events, and explicit role relationships. This makes
intertwining structure and musical memory inspectable without putting
composition decisions on the render callback.

The same score is available as a parallel **Persistent v3** performance model.
It preserves the approved v2 renderer as the default and changes only the
pre-rendered composition/event path: v3 uses Scene DNA, asymmetric phrase
transformations, relational bass choices, and persistent role memory. The app
offers this only as an Under the Hood A/B candidate, and the cache key includes
the model so switching cannot reuse the wrong immutable blocks. Deterministic
coverage confirms that v2 and v3 remain separate, finite, and audibly distinct;
v3 still requires fixed-seed listening approval before promotion.
The reference harness now also produces three Persistent v3 32-bar renders,
gain-matched copies against the corresponding v2 Club Punch RMS, and
`v3_translation_report.json`. All three objective entries pass finite-output,
true-peak, low-band stereo, boundary, and loudness-match checks. The listening
procedure and verdict table live in
[docs/V3_LISTENING_GATE.md](V3_LISTENING_GATE.md).
Regression coverage also verifies that a Persistent v3 render reproduces
exactly after a `V2RenderState` reset and remains finite and below the safety
ceiling.

Remaining refinement:

- full old-synth emulations and modeled analog behaviors;
- more detailed fill families;
- phase-continuous multi-voice state across complete phrases;
- complex intertwining structures between drums, bass, synths, and texture.

### Alien Analog V1 candidate

The old upper-voice functions now have a parallel replacement built from one
persistent `AlienAnalogVoice` topology with role-specific state. The score is
derived once from the scene seed and `SceneDNA`; establishment reveals the
anchor, builds corrode it, breakdowns preserve processed residue, and returns
restore a sharper attack. Cross-cycle interlocks are upper-voice-only and
relocate deterministically away from kick starts.

The app preparation call names `alienAnalogV1` and `interlocked` explicitly so
local candidate listening cannot silently fall back to the old engine. The
legacy texture/synth path is reachable only through offline reference profile
selection. Release promotion is not approved: all three fixed seeds pass
finite-sample, true-peak, DC, boundary, low-band mono, harmonic-complexity,
centroid-motion, clock-continuity, and drum-schedule checks, but the current
release median is `2.37×` A rather than the required `≤1.10×`. Absolute C
preparation remains below two seconds for a roughly 59-second scene, so the
lookahead deadline is met, but that does not waive the explicit ratio gate.

Gate: **Passed for v2 adoption.** The listener approved v2 as the preferred
engine, specifically citing less-generic identity and a fatter sound. Seed
`42` is a more deconstructed variation and `90909` is a favored variation.
Further voice refinement remains future work, not a prerequisite for use.

## Phase 3 — Texture rack and spatial depth

Status: **In progress**

Develop the procedural effect network as musical texture, not decoration:

- wavefolding and saturation;
- resonant filtering;
- ring and amplitude modulation;
- bounded two-stage phaser coloration;
- tempo-synced delay;
- diffusion and feedback;
- chorus/spread;
- persistent dark reverb;
- separate drum and synth sends;
- deterministic bypass/A-B for each rack family.

Completed in this phase: persistent, deterministic autopan for upper voices;
kick and bass remain centered for mono-compatible low end. The movement is
currently a foundation, not a final spatial design. A bounded persistent
stereo chorus/decorrelation stage now widens the synth path without widening
the low end. The texture rack now also includes a persistent two-stage phaser.
A persistent, bounded dark-reverb memory now provides a separate
upper-voice space tail while remaining below the direct groove.
The rack also includes bounded asymmetric saturation and slow tape/console
memory for subtle hysteresis across repeated material.

The v2 renderer now has deterministic effect-family comparison profiles:
**Full Texture** (the unchanged product default), **Motion Only** (spatial
movement without the nonlinear texture rack), and **Dry Reference** (the
upper-space and texture families bypassed while core dynamics remain). The
profiles are part of the immutable render cache key and are selectable only
in Under the Hood, making future A/B work attributable to a specific effect
family rather than an opaque chain change. The effect-profile regression test
verifies distinct hashes, finite output, conservative true peaks, and the
expected bypass telemetry.

The enhanced drone slice adds a semantic sustained-presence intention. Its
phase-continuous hybrid bed moves from dark modal harmonics toward filtered
noise, feeding a bounded 12–20 second spatial memory that remains audible
across phrase boundaries while kick and bass stay dominant.
The polished rack now also includes a persistent four-stage analog-inspired
ladder coloration stage. Its cutoff follows semantic synth presence and
percussion brightness, while resonance is bounded and carried across bar
boundaries for a more lived-in old-synth response.
The upper path now has a separate 13 ms early-reflection memory before the
longer dark reverb, with bounded stereo asymmetry and no kick/bass feed.
Hats and claps now have a separate percussion send into that space; kick and
bass remain dry/centered.

Ambitious targets:

- true stereo panning effects with musical motion, not static left/right offsets;
- automated pan laws and depth placement by voice role;
- 15–30 stage chains whose order and intensity are deterministic but scene-aware;
- old-synth-inspired oscillator/filter/amp combinations built entirely in DSP;
- chorus, ensemble, flanger, phaser, comb, resonator, and granular-like echoes;
- feedback networks with bounded energy and phrase-aware send changes;
- evolving noise beds, industrial air, machine hum, and metallic resonances;
- independent dry, early-reflection, delay, and reverb paths.

Gate: effects create controlled movement and depth without masking the kick,
bass, or groove.

## Phase 4 — 32-bar musical form

Status: **Scaffold done; modulation refinement in progress**

Make the 32-bar render feel composed rather than looped:

```text
1–8    establish groove
9–16   increase motion and texture
17–24  subtract and create tension
25–32  return with meaningful variation
```

Add deterministic modulation for brightness, density, space, bass articulation,
synth activity, fills, and transition intensity.

Implemented in this phase: each rendered bar now carries bounded, deterministic
brightness, density, space, cutoff, resonance, bass-articulation, and fill
modulation state. The lanes combine 8-bar phrase arcs with a 32-bar arc and
are exposed in the v2 render blocks for future Under the Hood telemetry.
The lane application now mutates coordinated roles: density couples
percussion and note activity, while cutoff/resonance couple synth presence and
texture complexity.

Return phrases now add a sparse deterministic call-and-response layer: in the
final four bars, selected motif notes receive a restrained octave-plus-fifth
answer. The original motif remains present, so the return gains lift while
preserving identity and avoiding a new uncontrolled melody.

The sequencer ambient voice supplies a persistent secondary response layer
behind the main groove; it is intentionally sparse and can be kept distant
through its semantic depth control.

Each immutable v2 render block now retains the performance plan's dramatic
thesis alongside its phrase transformation and foreground roles. Under the
Hood can therefore explain a bar as a contribution to a deterministic
"hypnotic lock", "pressure and release", or other scene-level intention,
instead of exposing only isolated parameter values. A regression test verifies
that the thesis survives through all 32 blocks unchanged.

`MusicalIntent.mutated(seed:amount:)` now provides a deterministic,
correlation-preserving semantic mutation primitive for future phrase-aware
juke-box exploration.

Ambitious targets:

- complex but legible intertwining structures across multiple voice families;
- call-and-response between percussion, bass, leads, pads, and noise;
- long cutoff and resonance arcs over 8, 16, and 32 bars;
- richer phrase-aware randomizer policies over roles and arrangement context;
- evolving polyrhythms that remain danceable;
- transitions that preserve motif identity while changing energy and texture;
- controlled tension, subtraction, fake drops, returns, and peak-time variations.

Gate: the return feels earned, the middle creates contrast, and no section is a
random pile-up.

## V2 leap prototype — 96-bar performance compiler

Status: **Objective proof passed; subjective listening pending**

The first non-marginal prototype replaces a repeating 32-bar arc with a pure,
deterministic 96-bar score. `DramaticJourneyPlan` tracks independent tension
dimensions—low-end uncertainty, rhythmic expectation, spectral pressure,
harmonic instability, density, spatial distance, and motif incompletion—and
opens explicit musical debts that must be paid at a scheduled return.

The current proof contains a deliberately incomplete return at bar 24, a long
subtraction and pressure arc, a decisive foundation/downbeat/dry-impact return
at bar 80, and a later motif resolution at bar 84. The return restores the
withheld low end and kick authority while collapsing accumulated spectral and
spatial pressure; it is not implemented as a generic volume ramp.

The same score can render with either the existing motif voice or the authored
**Shadow Pressure** instrument. That instrument has persistent oscillator,
envelope, glide, modulation, and two-stage resonant-filter state. Its semantic
macro trajectory is compiled from the dramatic score and remains technical,
read-only state rather than a new primary control surface.

The prototype is offline-only. It pre-renders immutable blocks and adds no work
to the live audio callback or current app scheduler. Approved v2 and Persistent
v3 remain unchanged as A/B references until listening establishes that the
new direction is a genuine leap.

Fixed-seed objective validation passes for `42`, `48291`, and `90909`: all
scores cover 96 bars, every debt has a matching payoff, renders are finite and
deterministic, true peaks remain below the safety ceiling, low-end stereo stays
mono-compatible, and the decisive return is more than three times the RMS of
the preceding anticipation bar. The report is
[leap_translation_report.json](reference/leap_translation_report.json).

Gate: the matched A/B/C files in [LEAP_LISTENING_GATE.md](LEAP_LISTENING_GATE.md)
must make both the long-form payoff and the authored instrument clearly
preferable. Objective contrast alone does not authorize live integration.

## Phase 5 — Mix and mastering

Status: **Partial; dynamic mix, masking, glue, and telemetry implemented**

Build a real v2 mix graph:

- kick;
- bass;
- drums/percussion;
- synth;
- texture;
- delay;
- reverb;
- master.

Add bus EQ, gain staging, sidechain envelopes, bus saturation, glue compression,
stereo control, true-peak-safe limiting, and loudness telemetry.

Implemented in the current v2 mix: the kick/bass bus remains centered while the
upper synth/pad/delay bus receives a bounded high-pass and stronger kick-driven
ducking. This is the frequency-dependent sidechain foundation; final
translation validation and mastering-profile work remain outstanding.

The upper bus now also has a restrained dynamic high-band controller: its own
short energy envelope reduces harsh accumulation while preserving the transient
and leaving the master limiter as a safety stage rather than a tone shaper.

The v2 upper path now also has bounded dynamic low-mid EQ. A slow low-mid
detector reduces pad/lead/return buildup, with a short kick-linked mask during
transients. The detector only acts on the upper musical bus; the centered
sub/bass path remains unchanged for mono-compatible low-end translation.

The v2 master now adds persistent-envelope glue compression before the safety
saturator, with a bounded ratio and slower release so sustained density is
controlled without flattening every transient.

The mix now also has a linked two-band compressor before that master stage.
Center/low and upper energy use separate bounded envelopes but share their
gains across left and right, controlling accumulation without stereo pumping.

The sidechain detector now reads a dedicated kick bus rather than the mixed
center bus, so bass and percussion no longer trigger their own ducking.

The preparation path now also runs a deterministic four-band masking analysis
over the rendered role signals. It reports bounded, explainable cuts for
kick/bass, percussion, synth, and texture overlap; the upper-bus renderer uses
those decisions for low-mid and high-band protection, and Under the Hood shows
the strongest current decision. The analyzer is intentionally preparation-time
only and performs no realtime callback work. Under the Hood now reports the
actual ordered v2 chain, including the masking guard and 19-stage texture rack,
rather than a shortened generic effect label.
`V2EffectKind` now names the implemented stages directly, including masking
guard, texture rack, analog ladder, early reflection, glue, and master, so
future per-stage telemetry can build on the same vocabulary.
Each v2 render block now carries bounded per-stage activity values; Under the
Hood exposes the active effect amounts for the current block without placing
telemetry work on the audio callback.
Deterministic regression coverage verifies the full 13-stage telemetry list,
bounded activity values, and fixed-seed reproducibility.
Each v2 block also carries an RMS-derived loudness estimate for matched-level
comparison; it is explicitly labeled as an estimate rather than a LUFS meter.
`V2QualityReport` includes the same estimate and fixed-seed quality tests check
that it remains finite and within a conservative audible range.
The v2 master now has deterministic **Club Punch** and **Headroom Reference**
profiles. Club Punch is the product default; Headroom Reference is available
only Under the Hood for matched A/B listening and uses gentler glue and a lower
safety ceiling.
The translation harness evaluates both profiles across all fixed seeds and
treatments, so the reference artifact covers the complete mastering A/B set.
The isolated v2/procedural orchestration suite passes all 18 tests, including
reset reproducibility, fixed-seed 32-bar determinism, acid sequencer safety,
effect telemetry bounds, stereo motion, Persistent v3 separation and reset
determinism, offline stems, sample-rate-aware metrics, and both mastering and
effect profiles.
The reference harness now writes `v2_translation_report.json`, comparing each
fixed seed/treatment against the MVP at matched RMS and checking finite output,
true-peak headroom, low-band stereo correlation, and loudness agreement.
Each `v2_manifest.json` entry now also persists the offline musical-quality
measurements used by `V2QualityReport`: integrated loudness estimate, loudness
range, short-term maximum, crest factor, spectral centroid, low/mid/high energy
balance, and transient density. This keeps future A/B comparisons auditable
without rerunning analysis code against an opaque audio file.
The report now accepts the active route sample rate explicitly, so time-window
and transient metrics remain correct for non-44.1 kHz output routes; a
regression test covers the sample-rate distinction.

Offline v2 stem preparation now renders deterministic foundation, percussion,
musical-voice, atmosphere, and return stems through the same performance plan.
The quality report also carries offline-only perceptual measures: gated
integrated loudness estimate, loudness range, short-term maximum, crest factor,
spectral-energy balance, and transient density. These are preparation and QA
signals only; they are not calculated on the realtime callback.

Ambitious targets:

- advanced equalization with dynamic bands and semantic intent mapping;
- frequency-dependent sidechain, not only broadband level ducking;
- multiband compression used sparingly for glue and translation;
- transient shaping for kick, clap, hats, and percussion buses;
- analog-style console coloration, nonlinear filters, and bounded tape-like motion;
- mono-compatible sub and bass with controlled stereo upper harmonics;
- mastering profiles that preserve punch instead of simply increasing loudness;
- automated masking checks between kick, bass, synth, and noisy textures.

Gate: v2 translates across headphones and speakers at matched loudness and is
clearly preferred to MVP for the same seed. **Passed for the current v2
baseline on 2026-07-13.** The listener preferred v2 for its less-generic
identity and fatter sound. Further mix translation and mastering refinement
remain active development, not a blocker to v2 use.

Objective translation validation is now reproducible for all six fixed
seed/treatment combinations; the generated
[v2_translation_report.json](reference/v2_translation_report.json) records
`allPass: true`, true-peak headroom, low-band stereo correlation, and matched
loudness deltas. Remaining Phase 5 work is subjective mastering-profile
refinement and fresh listening approval after future mix changes.

The repeatable procedure and verdict table live in
[docs/V2_LISTENING_GATE.md](V2_LISTENING_GATE.md). The listening gate is
approved; future changes must preserve this baseline through matched-loudness
fixed-seed comparisons.

## Phase 6 — Jukebox intelligence

Status: **Continuous jukebox implemented; long-play listening gate pending**

Once one 32-bar track is convincing, expand the engine into a long-form jukebox:

- multi-scene playlist behavior;
- phrase-aware scene changes;
- candidate generation around taste profile;
- explicit winner/loser comparison evidence;
- preference learning over sound palettes and arrangement choices;
- explainable **Under the Hood** taste decisions;
- local persistence and reset/migration support.

Implemented foundation: `JukeboxPlan` deterministically creates a sequence of
semantic scene intents around the local taste profile, with bounded role-level
novelty and stable scene seeds. Playback scheduling is now integrated behind
the listener-facing **CONTINUOUS** control: v2 adopts the next planned scene
at a 32-bar boundary. The same state remains visible in Under the Hood for
inspection. Automatic evolution is off by default and is suspended during
Teach Taste.
When a plan completes, the scheduler derives a fresh plan seed from the last
scene and cycle number, so long playback does not loop the same eight scenes.
The new plan remains centered on the persisted taste profile and uses the same
bounded deterministic novelty rules. The cycle seed policy lives in
`AutoTechnoCore.JukeboxPlan.cycle`, with regression coverage for reproducible
same-cycle output and non-repeating adjacent cycles.
After each adoption, the immediate successor is prewarmed off the main actor,
so the next 32-bar boundary can consume an immutable cached render instead of
starting a full-form render synchronously.
Preparation-time long-play validation now checks four deterministic cycles of
the default eight-scene plan: 32 total scenes, globally unique scene seeds,
zero adjacent-cycle overlap, bounded novelty, and valid semantic
correlations. This validates the unattended plan graph separately from audio
rendering; the subjective listening gate still applies to the rendered result.
The reference harness now renders four consecutive Continuous scenes into
`jukebox_seed48291_cycle0_4scenes.wav` and writes
`jukebox_translation_report.json` with objective long-play continuity and
safety checks. The current artifact passes with four unique scenes, 128 bars,
finite output, true peak `0.400`, low-band correlation `0.9997`, and maximum
inter-scene boundary delta `0.140`.
It also renders an eight-scene, 256-bar listening artifact at
`jukebox_seed48291_cycle0_8scenes.wav` with its own
`jukebox_long_play_translation_report.json`. That longer artifact passes with
eight unique scenes, true peak `0.409`, low-band correlation `0.9997`, and
maximum boundary delta `0.140`.

Gate: the user can leave it playing and hear coherent evolution without manual
loop hunting.
Objective gate: **Passed** for the four-scene reference artifact. Subjective
gate remains pending until the listener confirms that scene changes feel
coherent, intentional, and worth leaving on for an extended session.
The procedure and verdict table are maintained in
[docs/JUKEBOX_LISTENING_GATE.md](JUKEBOX_LISTENING_GATE.md).

App integration completed so far: the Under the Hood inspector now reports the
voices present in the current v2 block, the procedural effect path, and the
active render sample rate. Current v2 modulation targets are also shown there,
including cutoff, resonance, space, bass articulation, and fill intensity. v2
scene changes now adopt at 32-bar phrase boundaries (or eight-bar teaching
preview boundaries) and rebuild the deterministic render form. Each v2 block
now also carries per-voice bus level, send, and headroom telemetry; the
inspector exposes a compact current-block bus summary.
Continuous playback telemetry now includes the current plan cycle and next
scene position, making long-play evolution observable without exposing DSP
controls.
The inspector also shows the current block's interpolated true-peak estimate.
The inspector also reports a deterministic `JukeboxPlanReport`: unique scene
seeds, bounded novelty/correlation validity, and mean distance from the
learned semantic center.
It now also reports the four-cycle `JukeboxLongPlayReport`, including total
scene count and adjacent-cycle repeat safety, so the unattended plan graph is
visible directly in Under the Hood rather than only in offline artifacts.
Switching between the approved v2 and Persistent v3 model is now phrase-safe:
the requested model is prewarmed off the main actor, adopted only at the next
32-bar boundary when its immutable blocks are ready, and never stops the
currently playing buffer mid-phrase.
When playback is stopped, the active block selection is invalidated as soon as
the model changes, preventing the next Play action from reusing blocks from
the previous model while retaining the bounded render cache for later lookup.
Stopping while a phrase-boundary switch is pending resolves that request as
the selected model before the next start, so Stop/Play cannot resurrect an
ambiguous intermediate state.

Taste candidate generation now repairs cross-control correlations after
profile blending, preserving valid semantic role relationships while keeping
the learned bias.

Teaching selections now persist versioned comparison evidence alongside the
semantic profile: session seed, round, selected candidate index, all candidate
seeds, and semantic intent snapshots. Evidence is capped to the most recent
128 rounds, survives profile round-trips, and transparently migrates the
previous version-1 profile format. Reset clears both learned preferences and
comparison history. The Under the Hood inspector now reports both the number
of learned selections and the number of retained comparisons. Regression
coverage also verifies invalid data fails safely and version-1 profiles migrate
to the current representation without losing preferences, including Swift's
legacy unkeyed enum-dictionary encoding.

## Ambitious end-state goals

These are deliberately beyond the first 32-bar milestone and should be tackled
only after the v2 sound has a convincing identity:

- procedural emulations of selected classic synth behaviors, without relying on
  external plug-ins;
- pads, leads, drones, metallic voices, subharmonic textures, and evolving noise
  instruments;
- long effect chains with per-stage telemetry, deterministic bypass, and safe
  feedback limits;
- stereo panning, autopan, Haas/early-reflection depth, mid/side movement, and
  mono compatibility;
- cutoff, resonance, envelope, and modulation chains that evolve over whole
  arrangements;
- a semantic randomizer that creates surprising but valid signal paths;
- layered, intertwining arrangements where each voice has a role and memory;
- advanced equalization, dynamic masking prevention, sidechain networks, bus
  compression, saturation, and mastering translation;
- local taste learning over voices, effect chains, arrangements, transitions,
  and reject/choose evidence;
- a semi-automated jukebox that can play for hours while preserving identity,
  contrast, restraint, and musical continuity.

## Working rules

- Pure procedural DSP; no bundled samples or cloud models.
- One audible idea per iteration.
- Fixed seeds and matched-loudness A/B comparisons after every major phase.
- Ship one autonomous Persistent V3 path; retain older renderers only in
  development/reference executables and tests.
- Play/Pause is the only shipped control. Tempo remains fixed at 130 BPM.
- The macOS window remains manually resizable with a 480×390 minimum.
- The transport carries the stable `transport-play-pause` accessibility
  identifier. No removed control identifier may reappear in the shipped view.
- No real-time callback allocation, locking, I/O, logging, or UI work.
