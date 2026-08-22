# Internal Instrument Palette

## What this is

Auto Techno has one autonomous runtime and one canonical resolved score. Inside
that runtime, the score may assign a musical job to one of three engine-owned
synthesis architectures and one of eleven recognizable home patches. A patch can
move through four bounded automation coordinates without losing its identity.

The VSTi analogy is useful for understanding the palette, but these are not
plug-ins, files, user presets, tracks, or independently running engines. They are
typed score decisions rendered by the same continuation-aware DSP path. The
director continues to vary which musical roles and events are present from bar
to bar, so density expands and contracts without inventing a literal track
count or a second arrangement system.

## Capability matrix

| Architecture | Patch | Eligible musical use | Compatible existing effect stages |
| --- | --- | --- | --- |
| Resonant Mono | Bass Pulse | Foundation bass | Drive, masking guard, glue, master |
| Resonant Mono | Bass Pluck | Foundation bass | Drive, masking guard, glue, master |
| Resonant Mono | Acid Thread | Motif, shadow, response | Drive, chorus, unsynced echo, pulse echo, filtered reverb, masking guard, glue, master |
| Resonant Mono | Acid Sequence | Motif, shadow, response | Drive, chorus, unsynced echo, pulse echo, filtered reverb, masking guard, glue, master |
| Tonal Motion | North Star | Motif, shadow, response | Chorus, comb, unsynced echo, pulse echo, filtered reverb, masking guard, glue, master |
| Tonal Motion | Dark Chord | Motif, shadow, response, atmosphere, transition | Chorus, comb, unsynced echo, pulse echo, filtered reverb, masking guard, glue, master |
| Tonal Motion | Glass Runner | Motif, shadow, response | Drive, chorus, comb, unsynced echo, pulse echo, filtered reverb, masking guard, glue, master |
| Spectral Texture | Alien Noise | Response, atmosphere | Drive, chorus, unsynced echo, filtered reverb, masking guard, glue, master |
| Spectral Texture | Metal Veil | Response, atmosphere, transition | Drive, chorus, unsynced echo, filtered reverb, masking guard, glue, master |
| Spectral Texture | Dust Cloud | Atmosphere, transition | Chorus, unsynced echo, filtered reverb, masking guard, glue, master |
| Spectral Texture | Voltage Arc | Response | Drive, chorus, unsynced echo, filtered reverb, masking guard, glue, master |

“Compatible” means the assignment is allowed to reach that stage in the
canonical graph. It does not create a separate graph per patch. Pulse echo is
also conditioned by the existing score-owned pulse-echo decision, so a listed
capability can remain dry when the current bar does not authorize that send.

Effect compatibility is a permission set, not an orderable plug-in chain. The
implemented pulse-echo return-drive slice reuses the canonical renderer's one
shared, filtered return. The score authorizes bounded drive only in a memory-
chapter bar with pulse echo enabled and at least one assigned instrument that
has pulse-echo access; conservative, forced-home, identity-return, major-break,
and otherwise ineligible paths remain neutral. The drive follows return
filtering and sits downstream of the unchanged delay feedback write, so the
driven sample cannot recirculate. It does not create a per-patch graph, retain
transformed PCM as a reusable source, or alter the once-rendered dry assignment.

## The three architectures

### Resonant Mono

A mono, slide- and accent-aware oscillator into an authored four-stage resonant
filter. It owns the protected bass foundation and can reinterpret eligible
motif, shadow, and response sequences. Bass assignments keep spatial automation
at zero and remain in the protected low-end route.

An eligible dotted foundation pair reuses the existing Bass Pluck home with
bounded color/shape/motion coordinates and literal zero space. The relationship
is selected in the resolved score; Resonant Mono receives ordinary scheduled
events and owns no independent rhythm clock.

### Tonal Motion

The continuing tonal voice: coupled oscillators, bounded detune and modulation,
envelopes, filter motion, comb memory, and unsynced echo. North Star, Dark
Chord, and Glass Runner are substantively different oscillator/envelope/filter
homes inside this one topology.

Resonant Mono and Tonal Motion share one additional score meaning for existing
motif anchors: an emerging protagonist may disclose spectral detail through
that architecture's already owned filter. The relation is not a fifth
automation coordinate or a new patch. It is resolved per note from the
canonical narrative contour, exact home preserves the patch's prior cutoff,
and the existing downstream sends receive the same filtered voice. Spectral
Texture remains ineligible because it serves response, atmosphere, and
transition rather than the dominant motif.

### Spectral Texture

A deterministic ring-modulation and resonator source for alien responses,
metallic veils, dust-like atmosphere, and transitions. It uses no sample
library or random callback-time noise.

Voltage Arc adds a distinct response-only home inside this same architecture:
a low folded polyBLEP saw supplies closely spaced partials, a bounded driven TPT
band-pass isolates its upper harmonic tail, and one free-running low-depth LFO
moves that band without retriggering. Broken Suspension owns the authored
response assignment. The existing filtered-reverb send supplies its spatial
tail; no track, return, instrument architecture, or parallel renderer is added.

## Bounded automation

Every assignment carries the same four normalized coordinates. The score owns
their values; each architecture translates them into its own safe DSP bounds.

| Coordinate | Musical meaning | Examples of DSP consequence |
| --- | --- | --- |
| Color | Darker to brighter spectral center | Filter cutoff, oscillator or resonator color |
| Shape | Short/tight to sustained/soft articulation | Attack, decay, sustain, release, pulse width |
| Motion | Stable to animated behavior | Resonance, glide, detune, modulation, ring/resonator movement |
| Space | Dry/near to spacious/distant placement | Existing echo and filtered-reverb sends |

Coordinates clamp to `0...1`. Foundation bass always has `space = 0`. Patch
changes reset only the bounded state that would otherwise leak the previous
patch’s filter, envelope, or resonator identity; oscillator and continuation
behavior remain deterministic.

## Selection and density

The existing `SynthPerformancePlan` resolves assignments from the phrase kind,
performance character, foundation behavior, gesture, interlock chapter, scene
DNA, mutation amount, musical role, and pulse-echo eligibility. DSP consumes
those resolved assignments and never chooses a patch on its own. See
`PERFORMANCE_GRAMMAR.md` for the compatibility matrix that coordinates these
choices across a phrase.

The ensemble score still decides which roles and events exist. One architecture
may therefore serve several simultaneous musical jobs, while another can be
silent for a bar or phrase. This supplies the intended varying “instrument
count” through meaningful audible roles rather than a quota such as “always
create 5–10 tracks.” A future density rule should continue to operate through
the ensemble score and its existing space/overactivity evidence.

The evaluator's single permitted correction uses the catalog's stable Tonal
Motion homes for upper roles. It rerenders the same score and never switches
runtime, renderer, graph profile, or external instrument.

## Evidence and safety

Detached preparation records, for each audible architecture and bar:

- its exact resolved assignments, patches, uses, automation, and effect access;
- the number of rendered events;
- a deterministic hash of the exact dry architecture-local PCM;
- dry peak, RMS, and finite-sample status.

That bounded, machine-readable record enters candidate evidence; raw stem PCM
does not. Invalid architecture/use/patch/effect combinations, out-of-range
automation, malformed hashes, and non-finite evidence make the evidence
incomplete. These observations prove score-to-PCM truth for the calibrated
primary evaluator; they do not by themselves claim professional sound.

The shared return is intentionally recorded beside, rather than inside, the
architecture-local dry record. Each full bar retains bar/BPM/delay/render
geometry, score and drive eligibility, bounded `machineTexture` and applied
amount, current-send RMS, exact pre-drive and post-drive hashes, pre/post peak,
RMS, and low-band RMS, difference RMS, and finite status. Candidate-vector
schema 7 binds those observations to the matching instrument effect access and
requires exact pre/post identity on neutral paths. The exact-source local
structural, signal, protected-routing, and release-build matrix passed; neither
record alone qualifies professional sound.

All planning, assignment, rendering, and evidence reduction happen during
detached preparation. No new decision, allocation, analysis, logging, file or
network I/O, or UI work was added to the real-time audio callback.
