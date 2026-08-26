# AudioReakt Channel Audit

- **Access date:** 2026-08-25
- **Live inventory:** 362 videos
- **English captions:** 351 (350 automatic, 1 manual)
- **Caption unavailable:** 11
- **Hypothesis rows:** 23 kick/rumble rows and 21 snare/clap/rim rows
- **Source:** [AudioReakt videos](https://www.youtube.com/@audioreakt/videos)

## Method and limits

The authorized repository `yt-dlp` workflow captured the complete live flat
inventory, then metadata, descriptions, and English subtitle or automatic-
caption candidates for every upload. `scripts/analyze_youtube_transcripts.py`
selected manual English when present, otherwise the original automatic English
track, removed rolling-caption duplication, and emitted timestamped technical
excerpts. Raw captions, descriptions, metadata, and normalized transcripts
remain outside the repository under the local corpus directory.

Every one of the 362 channel rows was traversed in channel
order. For each of the 351 captioned videos, the
title, metadata, category distribution, and at least one representative
technical excerpt were reviewed. Repeated kick/rumble and snare/clap/rim claims
were then checked in deeper keyword context across the complete corpus. The
11 unavailable-caption rows are recorded
explicitly and no technical claim is inferred from their title or by listening.
Automatic-caption terminology is treated as navigation evidence, not authority.

The authorized capture used this bounded command shape, with the corpus outside
the repository:

```bash
yt-dlp --flat-playlist \
  --print '%(playlist_index)03d\t%(id)s\t%(duration)s\t%(title)s\thttps://www.youtube.com/watch?v=%(id)s' \
  'https://www.youtube.com/@audioreakt/videos'
yt-dlp --skip-download --write-subs --write-auto-subs \
  --sub-langs 'en.*,en' --sub-format vtt --write-info-json \
  --write-description --no-clean-info-json -P VIDEO_DIRECTORY \
  -o '%(id)s.%(ext)s' VIDEO_URL
```

The normalized index is reproducible after capture with:

```bash
python3 scripts/analyze_youtube_transcripts.py CORPUS_DIRECTORY \
  --source 'https://www.youtube.com/@audioreakt/videos' \
  --access-date 2026-08-25
```

Disposition codes:

- `H` — directly contributes to one of the two implemented, falsifiable sound
  hypotheses (`AR-DSP-01` or `AR-DSP-02`);
- `R` — reconciles to an existing canonical owner or to the standalone-product
  boundary, and therefore does not justify another engine, voice, effect lane,
  preset selector, or fixed arrangement template;
- `U` — no usable English caption, so no technical production claim is made.

The theme column shows the three strongest lexical categories in each normalized
caption. Counts below are matching cues; a cue may match multiple categories.

| Category | Matching cues |
|---|---:|
| Effects | 7,208 |
| Filter/Mod | 6,736 |
| Percussion | 4,901 |
| Arrangement | 2,778 |
| Kick | 2,473 |
| Tonal | 2,288 |
| Mix | 2,240 |
| Synthesis | 2,171 |
| Timbre | 1,503 |
| Rhythm | 1,389 |
| Space | 1,373 |
| Low-End | 1,090 |
| Sampling | 982 |
| Snare/Clap | 541 |
| Workflow | 343 |

## Channel-wide conclusions

Two repeated capability deficits survived reconciliation and produced original,
bounded implementations:

1. **AR-DSP-01 — score-owned kick morphology.** Kick tutorials repeatedly vary
   pitch-envelope depth/time, body and sub decay, harmonic body, drive, click,
   and noise transient. The prior source was fixed for the whole session. The
   canonical score now owns a continuous 128-bar morphology trajectory across
   four bounded homes; the existing kick renderer interpolates those parameters
   in physical time. Exact score hashing, source PCM, attack/body/upper-mid
   energy, crest consequence, and minute-three/minute-fifty route-rate tests
   make the change falsifiable. This is one kick source, not presets or another
   drum engine.
2. **AR-DSP-02 — contextual clap/snare/rim body.** Repeated snare and clap
   tutorials use noise plus pitched body, shorter rim-like attacks, gated tails,
   and contextual prominence. The already-arbitrated clap event now resolves a
   score-owned body: clap for identity/hypnotic material, a pitched membrane and
   filtered-wire snare for peak drive, or a damped shell rim for broken/ambient
   suspension. Hats and metallic events retain native bodies. Same-pass hashes
   and attack/body/tail evidence bind the decision to distinct deterministic PCM.

All other repeated families already have canonical causal owners:

- long-form automation, changes, subtraction, builds, breaks, releases, and
  recurrence map to the long-horizon director, effect sentences, narrative,
  performance characters, and future-boundary adaptation;
- acid, melodic/trancy lines, horns, stabs, pads, drones, FM, noise, saturation,
  ring/inharmonic motion, filter movement, and macro-like variation map to three
  synth architectures, eleven patch homes, semantic automation coordinates,
  harmonic disclosure, and the TPT/ADAA nonlinear core;
- hard/schranz/industrial and organic/ritual/afro-ethno suggestions map to
  performance-character selection, modal percussion, groove pulses, spectral
  texture, Voltage Arc, generated-graph drive/shifter treatment, and protected
  returns. They remain variable section vocabularies rather than fixed genres
  or selectable arrangements;
- rumble, delay, reverb, ducking, gated/reverse transitions, spatial depth,
  mixing, mastering, and translation map to typed returns, pulse echo, the
  eight-line FDN, automatic mix balance, BS.1770 evidence, and live headroom;
- Ableton racks, Serum presets, plug-ins, sample packs, Push hardware, DAW
  macros, reference imitation, and manual automation lanes are source-local
  teaching devices, never standalone runtime dependencies.

No comment capture was necessary: the caption corpus already supplied repeated
first-party technical explanations, while comments cannot authorize promotion
or substitute for deterministic deficit evidence.

## Per-video disposition

| # | Video | Caption | Result | Dominant themes | Canonical consequence |
|---:|---|---|:---:|---|---|
| 1 | [Scifi Techno Horn Sfx with Serum 2 (free preset)](https://www.youtube.com/watch?v=jQgy5V7Y7LY) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 2 | [How Sound Design can save your Mix](https://www.youtube.com/watch?v=XRzAjkeIjDM) | auto-en | R | effects, synthesis, filter/mod | generated graph / typed returns |
| 3 | [How to make Groovy Techno Chord](https://www.youtube.com/watch?v=djDz0mg80eg) | auto-en | R | tonal, arrangement, rhythm | tonal roles / harmonic disclosure |
| 4 | [Locked in The Studio S01E02 (Hypnotic Techno)](https://www.youtube.com/watch?v=zsmj7elux4s) | auto-en | R | effects, tonal, percussion | generated graph / typed returns |
| 5 | [Should you finish all tracks or not ?](https://www.youtube.com/watch?v=KhsFUDSxhpc) | auto-en | R | arrangement, filter/mod, low-end | director / performance grammar |
| 6 | [SERUM 2 FX Chain That Makes ANY Sound PRO ](https://www.youtube.com/watch?v=deeX7r6Vj1U) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 7 | [DFAM Techno Percs & Drums](https://www.youtube.com/watch?v=RVlCFJfGXd0) | auto-en | R | filter/mod, percussion, synthesis | semantic automation / TPT core |
| 8 | [I discovered a simple way to improve my Ambient Pad](https://www.youtube.com/watch?v=-HWabCcKQO0) | auto-en | R | filter/mod, tonal, timbre | semantic automation / TPT core |
| 9 | [Moog Sub37 :  3 tips to make it edgy](https://www.youtube.com/watch?v=oav3_7Mu1Gc) | auto-en | R | filter/mod, synthesis, arrangement | semantic automation / TPT core |
| 10 | [Locked In The Studio S01E01](https://www.youtube.com/watch?v=wwJBBwjMo5w) | auto-en | R | arrangement, percussion, tonal | director / performance grammar |
| 11 | [Sound Design Speedrun: 30 Sounds in 15 Minutes (free presets)](https://www.youtube.com/watch?v=qszcjHX59jQ) | auto-en | R | filter/mod, synthesis, tonal | semantic automation / TPT core |
| 12 | [From Weak to Pro sounds…(free rack)](https://www.youtube.com/watch?v=ZdSiMUxbPes) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 13 | [120 Serum 2 Techno Presets](https://www.youtube.com/watch?v=AScZQ8bga3g) | auto-en | R | tonal, timbre, percussion | tonal roles / harmonic disclosure |
| 14 | [Ableton Push 3: Sequencers Explained (Complete Tutorial)](https://www.youtube.com/watch?v=clYjBtUaBEA) | auto-en | R | rhythm, percussion, effects | resolved score / groove pulses |
| 15 | [How to Make Techno Stab (free preset)](https://www.youtube.com/watch?v=k0zAKQISAzs) | auto-en | R | effects, filter/mod, space | generated graph / typed returns |
| 16 | [15 Syntakt Workflow & Sound Design Tips](https://www.youtube.com/watch?v=CZl8ghpFGdg) | auto-en | R | filter/mod, percussion, effects | semantic automation / TPT core |
| 17 | [Another Beautiful Moog Sound (Nohr - You Remake)](https://www.youtube.com/watch?v=RrIkCqcbMQo) | auto-en | R | filter/mod, arrangement, effects | semantic automation / TPT core |
| 18 | [My #1 Techno VST Pick for 2026](https://www.youtube.com/watch?v=LLju58kBhxA) | auto-en | R | percussion, rhythm, kick | percussion grammar / modal voice |
| 19 | [I regret working with this company...](https://www.youtube.com/watch?v=t7yqm6Zk9Ck) | auto-en | R | effects, sampling, workflow | generated graph / typed returns |
| 20 | [How to Make Techno Stab (free preset)](https://www.youtube.com/watch?v=9XJ-XCFy-8E) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 21 | [Making Techno with Push 3 :  Breakdown (free project)](https://www.youtube.com/watch?v=59DLcrOIHu4) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 22 | [Making Techno with Push 3 Standalone](https://www.youtube.com/watch?v=95wUXnFN83E) | unavailable | U | - | no technical claim inferred |
| 23 | [3 Creatives Ways to use Ableton Meld](https://www.youtube.com/watch?v=PE5sWOG3-FQ) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 24 | [Hypnotic Techno Sfx (infinite sound generator) [free rack]](https://www.youtube.com/watch?v=OcgAm4ZuLkY) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 25 | [Paul Kalkbrenner Tribute Tutorial (free project)](https://www.youtube.com/watch?v=mlxXIcNjegk) | unavailable | U | - | no technical claim inferred |
| 26 | [The art of choosing the right tool](https://www.youtube.com/watch?v=yhAL7_OgstE) | auto-en | R | effects, percussion, arrangement | generated graph / typed returns |
| 27 | [How to Make Schranz Techno (free project)](https://www.youtube.com/watch?v=s1YXK4QdPR4) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 28 | [DFAM : Syncing, Sequencing & Sound Design Tips](https://www.youtube.com/watch?v=5HeoCwhiO0Y) | auto-en | R | kick, percussion, arrangement | kick + foundation owners |
| 29 | [How to Trancy Techno Synth (free preset)](https://www.youtube.com/watch?v=aOJu3HGqiFM) | auto-en | R | effects, filter/mod, space | generated graph / typed returns |
| 30 | [3 Creative Ways to Use Spectral Blur](https://www.youtube.com/watch?v=fuG0FmwdBa4) | auto-en | R | effects, low-end, kick | generated graph / typed returns |
| 31 | [How to use Ableton Limiter](https://www.youtube.com/watch?v=sSWoIpb6vxk) | auto-en | R | mix, effects, arrangement | mix evidence / headroom |
| 32 | [UDO Super 6 :  Pad from Scratch + tips (free preset)](https://www.youtube.com/watch?v=oKWr4rq-_Dw) | auto-en | R | synthesis, filter/mod, arrangement | three synth architectures |
| 33 | [How to Melodic Techno Keys (free preset)](https://www.youtube.com/watch?v=drXTMAW8npQ) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 34 | [Hypnotic Techno Jam w/ Syntakt, DFAM, Modular, SQ 1, UC4 & Ableton](https://www.youtube.com/watch?v=GIwCUd2jIYU) | auto-en | R | - | standalone-product boundary |
| 35 | [3 Creative ways to use Return track](https://www.youtube.com/watch?v=3-uivGmkeYY) | auto-en | R | effects, arrangement, sampling | generated graph / typed returns |
| 36 | [Techno Arrangement from Scratch (free template) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=Ylm3f4QlBX4) | auto-en | R | percussion, arrangement, tonal | percussion grammar / modal voice |
| 37 | [Full Hypnotic Techno track from Scratch (free project) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=5C2IekPMnaQ) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 38 | [UDO Super 6 : Underrated Classic Modern Synthesizer](https://www.youtube.com/watch?v=6FKXlyDYG2g) | auto-en | R | filter/mod, space, arrangement | semantic automation / TPT core |
| 39 | [How to Melodic Techno Bass (free preset)](https://www.youtube.com/watch?v=r1Oa_d4cZK4) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 40 | [How to Make Ambient techno Pad from scratch (free preset)](https://www.youtube.com/watch?v=mVNGeTxzl_I) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 41 | [LOUDNESS in Techno (without compression)](https://www.youtube.com/watch?v=MbgZrd3x9TQ) | auto-en | R | effects, space, mix | generated graph / typed returns |
| 42 | [116 Ableton Wavetable Techno Presets](https://www.youtube.com/watch?v=FwOyNG9S2Is) | auto-en | R | tonal, filter/mod, synthesis | tonal roles / harmonic disclosure |
| 43 | [ROAR = Techno Sound Generator](https://www.youtube.com/watch?v=RgojDu-nqyc) | auto-en | R | filter/mod, arrangement, effects | semantic automation / TPT core |
| 44 | [Complete guide to Techno Drums Pattern (Beginner to Pro) [+free project]](https://www.youtube.com/watch?v=_0dyDJcX9aY) | auto-en | H | percussion, rhythm, snare/clap | AR-DSP-02 clap/snare/rim body |
| 45 | [From Techno Sketch to Full track….](https://www.youtube.com/watch?v=AsyTi8G_kOQ) | auto-en | H | percussion, arrangement, snare/clap | AR-DSP-02 clap/snare/rim body |
| 46 | [Syntakt: Techno Track from Scratch](https://www.youtube.com/watch?v=kdhBNYwtYBk) | auto-en | R | filter/mod, percussion, effects | semantic automation / TPT core |
| 47 | [Don't use the same VST than everybody else...](https://www.youtube.com/watch?v=-E4KVlEknqo) | auto-en | R | arrangement, filter/mod, effects | director / performance grammar |
| 48 | [ROAR is pure MADNESS (+free preset)](https://www.youtube.com/watch?v=Ve4F0dd5AFU) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 49 | [Why I sold my Analog Rytm...](https://www.youtube.com/watch?v=VK6ug-qtYQQ) | auto-en | R | rhythm, synthesis, percussion | resolved score / groove pulses |
| 50 | [How to Make Techno Less Repetitive](https://www.youtube.com/watch?v=WJqEfM5OJSw) | auto-en | R | filter/mod, kick, percussion | semantic automation / TPT core |
| 51 | [Ableton Move thoughts...](https://www.youtube.com/watch?v=N50LE1upcPw) | auto-en | R | effects, percussion, sampling | generated graph / typed returns |
| 52 | [MASSIVE Techno Kick from scratch...(free preset)](https://www.youtube.com/watch?v=0CH7qHCF-yo) | auto-en | H | percussion, kick, effects | AR-DSP-01 kick morphology |
| 53 | [Why your techno rumble sucks...](https://www.youtube.com/watch?v=FEA5nx_UB0s) | auto-en | H | effects, kick, low-end | AR-DSP-01 kick morphology |
| 54 | [The begining of the end...](https://www.youtube.com/watch?v=aH2nOOvGhbU) | auto-en | R | - | standalone-product boundary |
| 55 | [How to make Hypnotic Techno Keys (free preset)](https://www.youtube.com/watch?v=95jwTb34Tkg) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 56 | [How to Make  Hypnotic Techno Synth (free preset) [Ableton techno Tutorial]](https://www.youtube.com/watch?v=__2N9Nb_GOk) | auto-en | R | filter/mod, effects, space | semantic automation / TPT core |
| 57 | [How to Make Hard Techno Part 2 (Arrangement, Mixing & Mastering) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=6o3ZlrpFzj0) | auto-en | H | percussion, tonal, arrangement | AR-DSP-02 clap/snare/rim body |
| 58 | [How to Make Hard Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=MxQStwjEscg) | auto-en | H | percussion, kick, effects | AR-DSP-02 clap/snare/rim body |
| 59 | [How to Make Noisy Techno Texture (free preset) [Ableton techno Tutorial]](https://www.youtube.com/watch?v=kn-cbSBCjYs) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 60 | [Full Techno Arrangement from Scratch (free template) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=z_6BcW2olJQ) | auto-en | H | percussion, arrangement, tonal | AR-DSP-02 clap/snare/rim body |
| 61 | [Full Peak Time Techno Track from Scratch (Free Template) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=ox3ds591Ezs) | auto-en | H | percussion, effects, filter/mod | AR-DSP-02 clap/snare/rim body |
| 62 | [How to Make Raw Hypnotic Techno Part 2 (Arrangement, Mixing & Mastering)  [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=JNMr0jxuWaM) | auto-en | R | percussion, effects, arrangement | percussion grammar / modal voice |
| 63 | [How to Make Raw Hypnotic Techno Part 1 (Sound Design / Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=qCJP2Y-8UKU) | auto-en | H | effects, percussion, filter/mod | AR-DSP-02 clap/snare/rim body |
| 64 | [Ambient Techno Jam (TT 303, DFAM, Push3 ,Tanzbar)](https://www.youtube.com/watch?v=oTq9LtIevdg) | unavailable | U | - | no technical claim inferred |
| 65 | [How to Make Ambient Techno Pad (Free Preset)](https://www.youtube.com/watch?v=wYE2hplPfyc) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 66 | [My Ableton Live 12 Template for 2024 (+workflow tips)](https://www.youtube.com/watch?v=b_oDKEZZAgE) | auto-en | R | mix, effects, rhythm | mix evidence / headroom |
| 67 | [How to make Hardgroove Techno Loops ''from scratch''](https://www.youtube.com/watch?v=xvtLy9KTyp4) | auto-en | R | percussion, sampling, effects | percussion grammar / modal voice |
| 68 | [How to Make Melodic House Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=8VaNePfcURI) | auto-en | H | percussion, effects, mix | AR-DSP-02 clap/snare/rim body |
| 69 | [How to Make Melodic House Part 1 (Sound Design & Composition)](https://www.youtube.com/watch?v=lb4bfPlUGvU) | auto-en | R | effects, percussion, mix | generated graph / typed returns |
| 70 | [5 Tips for Better Techno Groove (Hardgroove Techno Tutorials) [free project]](https://www.youtube.com/watch?v=dmMBMJk6rHE) | auto-en | R | percussion, rhythm, sampling | percussion grammar / modal voice |
| 71 | [How to Make FAT Techno Bass (Free Preset)](https://www.youtube.com/watch?v=cSE8eNOcUxg) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 72 | [How To Make Dub Techno Part 2 (Arrangement, Mixing & Mastering) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=L--Qkgu-z1A) | auto-en | R | percussion, effects, filter/mod | percussion grammar / modal voice |
| 73 | [How To Make Dub Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=QkbicL0yDfA) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 74 | [How to Make Techno FX  (and better transition too...) [free rack]](https://www.youtube.com/watch?v=g1Qxllss7vU) | auto-en | R | effects, mix, percussion | generated graph / typed returns |
| 75 | [Make Everything Industrial (Techno) [free rack]](https://www.youtube.com/watch?v=Ay7yMCbrScE) | auto-en | R | effects, filter/mod, tonal | generated graph / typed returns |
| 76 | [72 Ableton Drift Techno Presets](https://www.youtube.com/watch?v=6PKfTarRfaY) | auto-en | R | percussion, tonal, effects | percussion grammar / modal voice |
| 77 | [How to Make Peak Time Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=09F-dYDcQL0) | auto-en | R | tonal, arrangement, effects | tonal roles / harmonic disclosure |
| 78 | [How to Make Peak Time Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=viSnPF2jtYc) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 79 | [I use this everyday...](https://www.youtube.com/watch?v=JJ_hMEz4CcM) | auto-en | R | effects, arrangement, mix | generated graph / typed returns |
| 80 | [Building a Techno Live set in Ableton Session View...](https://www.youtube.com/watch?v=m4xP1JClFcY) | auto-en | R | effects, percussion, mix | generated graph / typed returns |
| 81 | [Industrial Techno Liveset w/ Push 3, Microfreak, DFAM & PC44](https://www.youtube.com/watch?v=KpJJ3HxMhm8) | auto-en | R | - | standalone-product boundary |
| 82 | [I had two weeks to build a Techno Live Set...](https://www.youtube.com/watch?v=p2bULk5aSrc) | auto-en | R | percussion, mix, arrangement | percussion grammar / modal voice |
| 83 | [How to make Industrial Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=XLNZV74w27E) | auto-en | R | percussion, effects, arrangement | percussion grammar / modal voice |
| 84 | [How to Make industrial Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=t4lW3nF73yQ) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 85 | [Best VST for Techno Kick](https://www.youtube.com/watch?v=4-ruuGZpgRU) | auto-en | H | percussion, kick, timbre | AR-DSP-01 kick morphology |
| 86 | [3 CRAZY Tools for Hypnotic Techno (+ free rack)](https://www.youtube.com/watch?v=iEaOnwbqQ2c) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 87 | [Techno Kick that SLAP (secret chain revealed + free)](https://www.youtube.com/watch?v=shQEM_NGSTI) | auto-en | H | percussion, kick, effects | AR-DSP-01 kick morphology |
| 88 | [Instant Pro Mastering Chain (Ableton Devices Only + Free Rack)](https://www.youtube.com/watch?v=6bDPAIFZn2w) | auto-en | R | mix, effects, space | mix evidence / headroom |
| 89 | [How to Make Raw Hypnotic Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=4goaH3i7iQY) | auto-en | R | percussion, filter/mod, arrangement | percussion grammar / modal voice |
| 90 | [How to Make Raw Hypnotic Techno Part 1 (Sound Design / Composition)](https://www.youtube.com/watch?v=s7apYc9zlFc) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 91 | [How to make a CRAZY TECHNO  Horn Synth (free preset)](https://www.youtube.com/watch?v=27yXJtRpn98) | auto-en | R | filter/mod, effects, space | semantic automation / TPT core |
| 92 | [Industrial/Rave Techno most Famous Synth (Free Rack) [How To]](https://www.youtube.com/watch?v=Xz3iZ0DqhYw) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 93 | [5 Advanced tips with Ableton Drift (+free rack)](https://www.youtube.com/watch?v=_Juzgw2HPQs) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 94 | [Hypnotic Techno Tom Bassline](https://www.youtube.com/watch?v=gtn_fzio6aM) | auto-en | R | percussion, kick, effects | percussion grammar / modal voice |
| 95 | [Ableton Push 3 Tutorial : Input & Output (CV, Midi, Usb)](https://www.youtube.com/watch?v=jmQAcmcEfUI) | auto-en | R | effects, rhythm, tonal | generated graph / typed returns |
| 96 | [Techno jam with Push 3 Standalone, Microfreak, DFAM & UC4](https://www.youtube.com/watch?v=sANUI1kGsGE) | auto-en | R | - | standalone-product boundary |
| 97 | [Microtonal Microfreak (Techno Tips)](https://www.youtube.com/watch?v=qBu2lzIK6p0) | auto-en | R | filter/mod, tonal, arrangement | semantic automation / TPT core |
| 98 | [3 Ableton Racks I use all the time...](https://www.youtube.com/watch?v=coKuqMFciVg) | auto-en | R | effects, space, filter/mod | generated graph / typed returns |
| 99 | [5 Techno Youtube channel you MUST follow...](https://www.youtube.com/watch?v=nFa-ISfi3Yw) | auto-en | R | arrangement, rhythm, sampling | director / performance grammar |
| 100 | [Learn Ableton Drift in 10 Minutes](https://www.youtube.com/watch?v=YsUOgSfN97U) | auto-en | R | filter/mod, synthesis, arrangement | semantic automation / TPT core |
| 101 | [How to Make Melodic Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=hvcETQdvWsg) | auto-en | R | effects, percussion, arrangement | generated graph / typed returns |
| 102 | [How to Make Melodic Techno Part 1 (Sound Design/Composition)](https://www.youtube.com/watch?v=Wl9iriHVLl0) | auto-en | H | effects, percussion, mix | AR-DSP-02 clap/snare/rim body |
| 103 | [Microfreak : 5 techno presets from scratch (free presets)](https://www.youtube.com/watch?v=SQvmeKWv0gE) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 104 | [From Session view to Arrangement view, my Ableton workflow...](https://www.youtube.com/watch?v=GGQAR3RFyCk) | auto-en | R | arrangement, filter/mod, percussion | director / performance grammar |
| 105 | [How to Make Techno Keys sound (free preset)](https://www.youtube.com/watch?v=rXfemyUrt3w) | auto-en | R | effects, space, filter/mod | generated graph / typed returns |
| 106 | [Ableton Presets I use all the time...(free presets)](https://www.youtube.com/watch?v=Ds5IanwvU6c) | auto-en | R | effects, filter/mod, space | generated graph / typed returns |
| 107 | [How to Make Groovy Techno Bassline](https://www.youtube.com/watch?v=svCkGIAG6Gc) | auto-en | R | percussion, kick, filter/mod | percussion grammar / modal voice |
| 108 | [Full Industrial Techno track from Scratch (free project) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=74tjKQxemJE) | auto-en | R | effects, percussion, kick | generated graph / typed returns |
| 109 | [How to Make Deep Hypnotic Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=hGUAMPcTN7U) | auto-en | R | filter/mod, effects, mix | semantic automation / TPT core |
| 110 | [How to Make Deep Hypnotic Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=2tMjA3paznk) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 111 | [This make EVERYTHING sound TECHNO...](https://www.youtube.com/watch?v=xzrp5xZliGE) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 112 | [How to Make POWERFUL Techno Stab (free preset)](https://www.youtube.com/watch?v=C3x8o9Krfc0) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 113 | [I use this device on EVERYTHING...](https://www.youtube.com/watch?v=ZDj41QZvjow) | auto-en | R | effects, percussion, mix | generated graph / typed returns |
| 114 | [How to Make Dub Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=PLEUbycKRJs) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 115 | [How to Make (Fast) Dub Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=yvDnJGM5DnQ) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 116 | [Next Level Lead Sfx like Anyma & Chris Avantgarde (Free Ableton Rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=psErBMRJo0M) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 117 | [Easy Beat Repeat effect for Techno Kick (free rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=4h_z2mNAvD0) | auto-en | H | effects, filter/mod, arrangement | AR-DSP-01 kick morphology |
| 118 | [How to Make Industrial Techno Groove (Free rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=wRhbl6N5BJs) | auto-en | R | effects, kick, low-end | generated graph / typed returns |
| 119 | [115 Ableton Wavetable Techno Presets](https://www.youtube.com/watch?v=TnEmufJRhF4) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 120 | [Techno Bass with DFAM (Patch from scratch) [Moog DFAM Techno Tutorial]](https://www.youtube.com/watch?v=BmVllR_dwNU) | auto-en | R | filter/mod, synthesis, rhythm | semantic automation / TPT core |
| 121 | [3 Game Changer Techno Sequencers](https://www.youtube.com/watch?v=0ZeQNhwTAd8) | auto-en | R | rhythm, tonal, arrangement | resolved score / groove pulses |
| 122 | [How to make Industrial Techno Synth (free rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=39KNJ-1tJMI) | auto-en | R | synthesis, filter/mod, effects | three synth architectures |
| 123 | [Techno Jam with DFAM, Push 2, Enner ,UC4 & Ableton](https://www.youtube.com/watch?v=u4FT7FKMprY) | unavailable | U | - | no technical claim inferred |
| 124 | [How to Make Peak Time Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=TdNE8oEb2Lk) | auto-en | R | tonal, effects, arrangement | tonal roles / harmonic disclosure |
| 125 | [How to make Peak Time Techno Part 1 (Sound Design & Composition) [ Ableton Techno Tutorial]](https://www.youtube.com/watch?v=S0DRqIEXW_4) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 126 | [No more Cheesy Techno Melodies… (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=m8C17MtbFHw) | auto-en | R | arrangement, rhythm, synthesis | director / performance grammar |
| 127 | [How to Make Industrial Techno part 2 (Arrangement, Mixing & Mastereing)](https://www.youtube.com/watch?v=T40u6ByjwWc) | auto-en | R | arrangement, percussion, effects | director / performance grammar |
| 128 | [How to Make industrial Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=lOhkJw1jlwg) | auto-en | R | effects, percussion, kick | generated graph / typed returns |
| 129 | [This is so good for Techno... [SOMA Enner Review]](https://www.youtube.com/watch?v=X2KlWQGjlsA) | auto-en | R | filter/mod, effects, space | semantic automation / TPT core |
| 130 | [How To Make Melodic Techno Lead (ARTBAT - It's Ours Lead Remake) [Free preset]](https://www.youtube.com/watch?v=dTWCL6IYhTg) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 131 | [How to Make FAT Techno Stab (free rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=NB2EnmQeRgY) | auto-en | R | effects, filter/mod, space | generated graph / typed returns |
| 132 | [More than a drum machine, 18 tips in 15 min {Analog Rytm Tutorial)](https://www.youtube.com/watch?v=Sa6L0SCWHGM) | auto-en | R | filter/mod, percussion, rhythm | semantic automation / TPT core |
| 133 | [I sampled this rare Drum Machine for you...](https://www.youtube.com/watch?v=X6DLZIGTT8M) | auto-en | R | percussion, kick, sampling | percussion grammar / modal voice |
| 134 | [How to Make Heavy Pounding Techno Groove (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=xuHSPaCHjvo) | auto-en | R | kick, effects, percussion | kick + foundation owners |
| 135 | [How to Make Melodic House Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=vhPuYg4de6g) | auto-en | R | effects, mix, percussion | generated graph / typed returns |
| 136 | [How to Make Melodic House Part 1 (Sound Design & Composition) [Ableton Tutorial]](https://www.youtube.com/watch?v=FC7HzZPANXM) | auto-en | R | effects, percussion, arrangement | generated graph / typed returns |
| 137 | [How to Make HUGE Peak Time Techno Synth (free preset) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=8eEf3oh7UYg) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 138 | [Most Used Melodic Techno Pattern (from scratch) [free preset]](https://www.youtube.com/watch?v=3vLDxgUJt8Q) | auto-en | R | low-end, rhythm, effects | protected kick/foundation route |
| 139 | [How to Make Raw Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=7r3Lmw39by0) | auto-en | R | effects, mix, arrangement | generated graph / typed returns |
| 140 | [How to Make Raw Techno Part 1 (Sound design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=KLmEUy5El4g) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 141 | [Psytrance Bassline for Techno (free project) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=Mix6rW9AHgE) | auto-en | R | effects, low-end, filter/mod | generated graph / typed returns |
| 142 | [Techno Jam Torso T-1, Moog DFAM, Roland TR6S & Modular](https://www.youtube.com/watch?v=REG1rzydrlY) | unavailable | U | - | no technical claim inferred |
| 143 | [I made a Ableton Rack's version of the Moog DFAM (free rack ) [Ableton Tutorial]](https://www.youtube.com/watch?v=3U54iMbu1M4) | auto-en | R | synthesis, filter/mod, effects | three synth architectures |
| 144 | [Techno Kick with DFAM](https://www.youtube.com/watch?v=v6f9kyE2oc4) | auto-en | H | filter/mod, kick, percussion | AR-DSP-01 kick morphology |
| 145 | [How to make Mordern Techno Pad (Free Preset) [Ableton Tutorial]](https://www.youtube.com/watch?v=5Bg3sRl77HA) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 146 | [5 Sound design tricks I overlooked for too long...](https://www.youtube.com/watch?v=amqLW7Vsy90) | auto-en | R | filter/mod, timbre, synthesis | semantic automation / TPT core |
| 147 | [How to Make Deep Hypnotic Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=cSJPeSSUNCE) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 148 | [How to Make Deep Hypnotic Techno Part 1 (Sound Design & Composition)](https://www.youtube.com/watch?v=lsr6-NzH4DI) | auto-en | R | effects, filter/mod, sampling | generated graph / typed returns |
| 149 | [How to Make Any Techno Synth Hypnotic (free rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=ML5wnf6UF3I) | auto-en | R | filter/mod, effects, timbre | semantic automation / TPT core |
| 150 | [Transform Basic 909 Kick into HUGE Kick (Free Rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=Qhamz130PEA) | auto-en | H | filter/mod, kick, percussion | AR-DSP-01 kick morphology |
| 151 | [How to Make Blasting Dub Techno Chord (Free Preset) [Ableton Tutorial]](https://www.youtube.com/watch?v=EWRpP5kdhDE) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 152 | [Ableton Shaper as Step Sequencer (Ableton Tutorial)](https://www.youtube.com/watch?v=onKv6lJSv_Q) | auto-en | R | filter/mod, rhythm, tonal | semantic automation / TPT core |
| 153 | [Torso T-1 : Another great Techno Sequencer](https://www.youtube.com/watch?v=ocbzfB1fPlk) | auto-en | R | rhythm, filter/mod, timbre | resolved score / groove pulses |
| 154 | [How to Make Hypnotic Techno Synth (free preset) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=v-mjY-Vlgv0) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 155 | [Techno Jam w/ Analog Rytm, Sub Harmonicon, Microfreak & Modular](https://www.youtube.com/watch?v=L06YBk9GcFs) | auto-en | R | - | standalone-product boundary |
| 156 | [How to Make Peak Time Techno (Filth On Acid) Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=dBGKlhO0l1A) | auto-en | R | effects, arrangement, mix | generated graph / typed returns |
| 157 | [How to Make Peak Time Techno (Filth On Acid) Part 1 [Sound Design & Composition]](https://www.youtube.com/watch?v=Gin-RpuA3Jk) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 158 | [How to Make Raw Techno Synth (Free Rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=-HsUgQWZBSo) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 159 | [116 Ableton Wavetable Techno Presets](https://www.youtube.com/watch?v=V6x0j-sX6Bs) | auto-en | R | filter/mod, timbre, tonal | semantic automation / TPT core |
| 160 | [Techno Jam Explanation (+Ableton Sync with Hardware)](https://www.youtube.com/watch?v=95QAKoFr7Mw) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 161 | [Techno Jam w/  Modular, DFAM, TR-6S, SQ-1, UC4 & Ableton #jamuary](https://www.youtube.com/watch?v=3f4ijW_pvzA) | auto-en | R | - | standalone-product boundary |
| 162 | [How to make Industrial Techno ([KRTM] style) Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=-Chf9t3oUII) | auto-en | R | effects, percussion, mix | generated graph / typed returns |
| 163 | [How to make Industrial Techno ([KRTM] style) Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=v0DAVyfQOsw) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 164 | [From techno jam to label released... Behind The Scene / Eternal Chase - Brut](https://www.youtube.com/watch?v=BZibuT1LVjM) | auto-en | R | filter/mod, effects, arrangement | semantic automation / TPT core |
| 165 | [How to Make Minimal Techno [Senso Sounds] Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=NfN2FGP_Yyw) | auto-en | R | effects, mix, filter/mod | generated graph / typed returns |
| 166 | [How to Make Minimal Techno [Senso Sounds] Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=pHNLrY90T30) | auto-en | H | effects, filter/mod, percussion | AR-DSP-02 clap/snare/rim body |
| 167 | [Why does nobody use this filter ? (Ableton Morph Filter Tutorial)](https://www.youtube.com/watch?v=Z4mMGSg6ebY) | manual-en | R | filter/mod, timbre, synthesis | semantic automation / TPT core |
| 168 | [Ableton Push 2 : Creating a Full Track from Scratch (Start to Finish)](https://www.youtube.com/watch?v=FWsjSa7TUSI) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 169 | [TR6S : This ruined everything…](https://www.youtube.com/watch?v=074iH1TW3_M) | auto-en | R | percussion, kick, rhythm | percussion grammar / modal voice |
| 170 | [Best VSTs for Techno? (Noise Engineering's VST Review & Tutorial) + free presets](https://www.youtube.com/watch?v=aCkc6PnNxFY) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 171 | [Ableton Multi Effect Rack for instant inspiration (free rack)](https://www.youtube.com/watch?v=gg5YJyh8N-Q) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 172 | [3 Melodic House & Techno presets from scratch with the Moog Subsequent 37 (Free Presets)](https://www.youtube.com/watch?v=Yy_D3sjL1fk) | auto-en | R | synthesis, filter/mod, arrangement | three synth architectures |
| 173 | [How to make Melodic Techno Part 2 (Arrangement, Mixing & Mastering) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=dVYtBbMZOxw) | auto-en | R | effects, mix, arrangement | generated graph / typed returns |
| 174 | [How to Make Melodic Techno Part 1(Sound Design/Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=ztFV1-3qq_Q) | auto-en | R | effects, filter/mod, arrangement | generated graph / typed returns |
| 175 | [10 Tips with the Moog Subharmonicon for Wicked Techno Melody](https://www.youtube.com/watch?v=PxWBbtEdU5w) | auto-en | R | rhythm, synthesis, filter/mod | resolved score / groove pulses |
| 176 | [How to write Dark Hypnotic Techno Melody (+ non-melodic hook tips) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=iHMSD88A4X0) | auto-en | R | arrangement, rhythm, filter/mod | director / performance grammar |
| 177 | [How to Make Techno Kick with the Analog Rytm ? (+free kick samples)](https://www.youtube.com/watch?v=CMufzVeZR1Y) | auto-en | H | kick, percussion, filter/mod | AR-DSP-01 kick morphology |
| 178 | [How to Make Techno like UMEK & Space 92 (free project) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=OHu7-yeVwlc) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 179 | [How To Make Raw Techno Part 2 ( Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=jwJu93GEiN4) | auto-en | R | percussion, filter/mod, effects | percussion grammar / modal voice |
| 180 | [How To Make Raw Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=YmkTCd7GNAA) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 181 | [This take your Push to the next level (Chord-O-Mat 3 Tutorial)](https://www.youtube.com/watch?v=q5tpCejDzFs) | auto-en | R | arrangement, tonal, rhythm | director / performance grammar |
| 182 | [The melodic house & techno lead that everyone use.. in one (free) Ableton rack](https://www.youtube.com/watch?v=nyos4ErUFaI) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 183 | [Ableton Live 11 : Spectral Time Tutorial & Techno tips (+ Free Presets)](https://www.youtube.com/watch?v=JoITRKDTm8Q) | auto-en | R | effects, arrangement, percussion | generated graph / typed returns |
| 184 | [How to sound different (and weird) [Free Ableton Rack]](https://www.youtube.com/watch?v=cz2Oo_NpeCs) | auto-en | R | effects, filter/mod, arrangement | generated graph / typed returns |
| 185 | [Techno jam with Moog DFAM, Subharmonicon & Mother-32](https://www.youtube.com/watch?v=LJDbvW-k_3c) | auto-en | R | - | standalone-product boundary |
| 186 | [Ableton Live 11 :  Spectral Resonator Tutorial (+ Free Presets)](https://www.youtube.com/watch?v=MPyxcvpOsss) | auto-en | R | synthesis, effects, arrangement | three synth architectures |
| 187 | [How to make Demons Techno ( Techno Farmer Discord Community )](https://www.youtube.com/watch?v=W6gliBiQlC8) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 188 | [How to Make Acid Techno Part 2 (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=vRbVL9-oZxo) | auto-en | R | arrangement, tonal, mix | director / performance grammar |
| 189 | [How to Make Acid Techno Part 1 (Sound Design & Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=wt9NDrEHHHY) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 190 | [117 Moog Subsequent 37 Presets (Progressive House & Melodic Techno)  [Bank Walkthrough]](https://www.youtube.com/watch?v=k5qERQPvhbc) | auto-en | R | effects, tonal, arrangement | generated graph / typed returns |
| 191 | [Moog Subsequent 37 : Not for Everyone  (1 year review)](https://www.youtube.com/watch?v=lYSzbVH8_y8) | auto-en | R | filter/mod, synthesis, arrangement | semantic automation / TPT core |
| 192 | [How I remixed Samuel L Session - Skull -  (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=oQkulzz6PJA) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 193 | [3 Sounds of Acid Techno (Free Rack  + Midi) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=AXbbOQQtP3g) | auto-en | R | filter/mod, effects, tonal | semantic automation / TPT core |
| 194 | [Full Techno Track with Microfreak Only (Noise Engineering Osc) [Arturia Microfreak Tutorial]](https://www.youtube.com/watch?v=ba9n_iVo_LQ) | auto-en | R | filter/mod, percussion, effects | semantic automation / TPT core |
| 195 | [Elektron Analog Rytm Mk2 Review : Ultimate Techno Drum Machine ?](https://www.youtube.com/watch?v=jzOT9EOnUAQ) | auto-en | H | percussion, kick, effects | AR-DSP-02 clap/snare/rim body |
| 196 | [Ableton Live 11 : Phaser Flanger (Free Presets) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=XZ7O1fCi7B4) | auto-en | R | filter/mod, effects, mix | semantic automation / TPT core |
| 197 | [How to Make Techno like Drumcode Part 2 (Arrangement, Mixing, Mastering) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=IioVB7QV2ew) | auto-en | R | tonal, effects, arrangement | tonal roles / harmonic disclosure |
| 198 | [How to Make Techno like Drumcode Part 1 (Sound Design, Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=CLDTVxkrgq4) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 199 | [How to Make Industrial Techno Synth (Free Rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=ULTSdXLQupw) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 200 | [5 Ableton Wavetable Secret Tips (Ableton Live Tutorial)](https://www.youtube.com/watch?v=I7uD4OgZJ78) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 201 | [Sub37 vs Diva vs Wavetable : Which one sounds the best ? Blind Test & Free presets](https://www.youtube.com/watch?v=cohKkfUfALY) | auto-en | R | filter/mod, synthesis, tonal | semantic automation / TPT core |
| 202 | [Ableton Live 11 : Hybrid Reverb Tutorial (+ free presets)](https://www.youtube.com/watch?v=W7KnX2Y3tAo) | auto-en | R | effects, low-end, filter/mod | generated graph / typed returns |
| 203 | [Moog Triforce Techno Jam (Moog DFAM, Moog Mother-32, Moog Subharmonicon) [Dawless Jam]](https://www.youtube.com/watch?v=C9HbkjnLrNE) | auto-en | R | - | standalone-product boundary |
| 204 | [Ableton Push 2 : Creating a Full Track from Scratch (Start to Finish)](https://www.youtube.com/watch?v=rPdYu8WZJVc) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 205 | [How to Make Raw Techno Kick (free rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=0dSnVp1bd1o) | auto-en | H | percussion, synthesis, kick | AR-DSP-01 kick morphology |
| 206 | [How to Make Berlin Techno Part 2 (Arrangement, Mixing & Mastering) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=JOWhWsUopgo) | auto-en | H | effects, percussion, mix | AR-DSP-02 clap/snare/rim body |
| 207 | [How to Make Berlin Techno Part 1 (Sound Design & Composition)](https://www.youtube.com/watch?v=FBj7_6OJxec) | auto-en | H | effects, filter/mod, percussion | AR-DSP-02 clap/snare/rim body |
| 208 | [Ableton Live 11 : Chorus Ensemble Tutorial (+15 Free Presets)](https://www.youtube.com/watch?v=DiDu9gcbYY4) | auto-en | R | filter/mod, space, effects | semantic automation / TPT core |
| 209 | [Jomox Mbase11 : still good after 10 years ? (Free Kick Samples)](https://www.youtube.com/watch?v=fweFafFK0_4) | auto-en | H | kick, percussion, effects | AR-DSP-01 kick morphology |
| 210 | [How to Make Techno like Alignment (Future Dancefloor Full track remake) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=XO1Tgc2g4PU) | auto-en | R | percussion, effects, mix | percussion grammar / modal voice |
| 211 | [Vermona Kick Lancet Review : is it worth it ? (+ free kick samples)](https://www.youtube.com/watch?v=Z9PtdirDWc0) | auto-en | H | kick, percussion, synthesis | AR-DSP-01 kick morphology |
| 212 | [Ableton Live 11 : This changes everything (first crazy FREE new rack)](https://www.youtube.com/watch?v=ElMcWEy2xLY) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 213 | [My Ableton Template for 2021 (+workflow tips) [FREE Template]](https://www.youtube.com/watch?v=FMBN5v7aWBA) | auto-en | R | mix, effects, percussion | mix evidence / headroom |
| 214 | [How to Make Dub Techno Part 2 (Arrangement, Mixing, Mastering)](https://www.youtube.com/watch?v=l6q7bB-wUMY) | auto-en | R | filter/mod, effects, mix | semantic automation / TPT core |
| 215 | [How to Make Dub Techno Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=0L5str-HthA) | auto-en | R | effects, filter/mod, tonal | generated graph / typed returns |
| 216 | [How To Make Techno Driving Noise Rhythm (free rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=roRaRx-3rr0) | auto-en | R | filter/mod, effects, rhythm | semantic automation / TPT core |
| 217 | [Elektron Analog Rytm Techno Jam 2 Explained (Scene & Perf Tips)](https://www.youtube.com/watch?v=pbdwdCR_IZ4) | auto-en | R | filter/mod, kick, percussion | semantic automation / TPT core |
| 218 | [Analog Rytm mk2 Only Techno Jam 2 #jamuary](https://www.youtube.com/watch?v=-3Xa0oP3JUA) | auto-en | R | - | standalone-product boundary |
| 219 | [How to Make Wicked Techno Synth Horn (Free Rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=m_mQtSWLElg) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 220 | [124 Ableton Wavetable Techno Presets](https://www.youtube.com/watch?v=ysvOYSGi-2M) | auto-en | R | filter/mod, timbre, effects | semantic automation / TPT core |
| 221 | [How to Make a Killer Drum Rack (Free Rack) [ Ableton Tutorial ]](https://www.youtube.com/watch?v=sqGZ-PgsUTo) | auto-en | R | effects, percussion, mix | generated graph / typed returns |
| 222 | [Elektron Analog Rytm Techno Jam Explained (+ Kick Rumble Tutorial)](https://www.youtube.com/watch?v=pdAWrHrv3Z8) | auto-en | H | effects, percussion, filter/mod | AR-DSP-01 kick morphology |
| 223 | [Analog Rytm mk2 Only First Techno Jam (Machine & Default Samples Only)](https://www.youtube.com/watch?v=HAqX2M0As1I) | auto-en | R | - | standalone-product boundary |
| 224 | [How to Make DubTechno Chord [Free Ableton Rack] (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=Bzl9Rfy1hAQ) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 225 | [How to Make Industrial Hard Techno Part 2 (Arrangement, Mixing, Mastering) [Ableton Techno tutorial]](https://www.youtube.com/watch?v=GD8Uo2MH8pA) | auto-en | R | effects, mix, filter/mod | generated graph / typed returns |
| 226 | [How to make Industrial Hard Techno Part 1 (Sound Design & Composition)](https://www.youtube.com/watch?v=HIdVSH2OIpc) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 227 | [How to Make Cosmic Techno Synth (The Yellow Heads & Space 92 - Planet X) [Free Project & Rack]](https://www.youtube.com/watch?v=r8bsxtj4rPQ) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 228 | [How I made my EP on Planet Rhythm + answer your questions (mindset when producing) [Ableton Techno]](https://www.youtube.com/watch?v=N5vsm6OIcjo) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 229 | [Arturia Microfreak : 5 Techno presets from scratch (Free Presets)](https://www.youtube.com/watch?v=etvFQMYbxzU) | auto-en | R | filter/mod, tonal, rhythm | semantic automation / TPT core |
| 230 | [How to Make Industrial Techno Groove (Free Project File & Rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=VrNUIki7790) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 231 | [Techno Jam w/ Eternal Chase (Ableton Push 2, Arturia Minibrute 2s, Beatstep, Faderfox PC44)](https://www.youtube.com/watch?v=6GZUPaQ-ayA) | unavailable | U | - | no technical claim inferred |
| 232 | [How to Make Melodic Techno Part 2 (Arrangement / Mixing & Mastering) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=cwZJOVAv-bE) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 233 | [How to Make Industrial Techno Trancy Lead (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=E0JiBi6wEww) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 234 | [Ableton Live 11 : What’s new ? (New Features & Devices Advanced Overview)](https://www.youtube.com/watch?v=WNgWlXROn-A) | auto-en | R | effects, filter/mod, timbre | generated graph / typed returns |
| 235 | [How to Make Melodic Techno Part 1 (Sound Design / Compositon) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=F2BF-jjphFI) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 236 | [How to Make Techno Bass (no rumble involved) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=2rr0_RDsa7c) | auto-en | H | synthesis, filter/mod, effects | AR-DSP-01 kick morphology |
| 237 | [Ableton Push 2 : Creating a Full Track from Scratch (Start to Finish)](https://www.youtube.com/watch?v=aoaQqqwyxdc) | auto-en | R | effects, percussion, arrangement | generated graph / typed returns |
| 238 | [How To Make Music like Ben Böhmer (Beyond Beliefs Track Remake) [Ableton Live Tutorial]](https://www.youtube.com/watch?v=7pS9ER1ArnQ) | auto-en | R | effects, filter/mod, sampling | generated graph / typed returns |
| 239 | [How to Make Industrial Techno Percussion (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=o3HyC6CYclQ) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 240 | [Arturia Minibrute 2s : 5 Techno Lead from Scratch (Planet Rhythm EP)](https://www.youtube.com/watch?v=5cNGq7-ulrM) | auto-en | R | filter/mod, synthesis, tonal | semantic automation / TPT core |
| 241 | [How to Make Techno Reverb Kick (Techno Rumble Kick Ableton) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=XWBU4NxPRwU) | auto-en | H | effects, filter/mod, low-end | AR-DSP-01 kick morphology |
| 242 | [How to Make Deep Techno like Hypnus Record and Affin Record PART 2 (Arrangement/Mixing/Mastering)](https://www.youtube.com/watch?v=Y6M5GjFacPE) | auto-en | R | filter/mod, tonal, arrangement | semantic automation / TPT core |
| 243 | [How to Make Deep Techno like Hypnus Record and Affin Record PART 1 (Sound Design & Composition)](https://www.youtube.com/watch?v=tqroGjwzdRg) | auto-en | R | effects, filter/mod, tonal | generated graph / typed returns |
| 244 | [How to Sync your Hardware with Ableton Live (with Usb, Midi & CV)](https://www.youtube.com/watch?v=-Cxc1PyOWjQ) | auto-en | R | effects, rhythm, tonal | generated graph / typed returns |
| 245 | [Korg Volca Modular Review & Tutorial (& patch from scratch)](https://www.youtube.com/watch?v=JD-e-gdR2cM) | auto-en | R | filter/mod, effects, tonal | semantic automation / TPT core |
| 246 | [How to Techno Arpeggios (in a different way) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=Sur8OhdFkG8) | auto-en | R | effects, rhythm, filter/mod | generated graph / typed returns |
| 247 | [Techno Live Performance (Ableton Push 2, Arturia Minibrute 2s, Beatstep, Faderfox PC44)](https://www.youtube.com/watch?v=kOJlZ_yjmTw) | unavailable | U | - | no technical claim inferred |
| 248 | [Arturia Microfreak : 30 Freaky Tips](https://www.youtube.com/watch?v=4J-BouLi3Oo) | auto-en | R | filter/mod, synthesis, arrangement | semantic automation / TPT core |
| 249 | [How To Make Peak Time Techno PART 2 (Arrangement, Mixing & Mastering) [Ableton Live Tutorial]](https://www.youtube.com/watch?v=KcIlpNWRRYA) | auto-en | H | arrangement, effects, percussion | AR-DSP-02 clap/snare/rim body |
| 250 | [How To Make Peak Time Techno PART 1 (Sound Design & Composition) [Ableton Live Tutorial]](https://www.youtube.com/watch?v=L5lR-VeYsqo) | auto-en | R | effects, percussion, arrangement | generated graph / typed returns |
| 251 | [I Created a unique Drum Machine with Ableton Collision ONLY ! (Free Presets)](https://www.youtube.com/watch?v=vAE9HF754Mw) | auto-en | R | percussion, effects, filter/mod | percussion grammar / modal voice |
| 252 | [Korg Volca Nubass Review & Tutorial (I love the sequencer)](https://www.youtube.com/watch?v=mz3wTG9PBfU) | auto-en | R | tonal, rhythm, filter/mod | tonal roles / harmonic disclosure |
| 253 | [How to Make Melodic Techno Like N'to [Free Template] (Sound Design/Chord Progression)](https://www.youtube.com/watch?v=LQxtbD3C5vo) | auto-en | R | arrangement, tonal, filter/mod | director / performance grammar |
| 254 | [How to Make Techno Ambient Drone Atmosphere (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=90VpsmIaPuk) | auto-en | R | synthesis, filter/mod, effects | three synth architectures |
| 255 | [Microphonic Soundbox : Weird Recording Ideas + Sampling in Ableton](https://www.youtube.com/watch?v=ahrojL-LmXc) | auto-en | R | sampling, percussion, effects | AudioSlicePlan / Spectral Texture |
| 256 | [135 Ableton Operator Techno Presets (+ Operator Secret Tips)](https://www.youtube.com/watch?v=NatWhvRLpy8) | auto-en | R | filter/mod, synthesis, tonal | semantic automation / TPT core |
| 257 | [How to Make Industrial Techno like Viper Diva (Full Track Remake) [Ableton Live Tutorial]](https://www.youtube.com/watch?v=g7FDz6mQ5rw) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 258 | [How to Make Dark Hypnotic Techno like Soma and Planet Rhythm (Arrangement, Mixing & Mastering)](https://www.youtube.com/watch?v=85iY11QxpJU) | auto-en | R | effects, mix, filter/mod | generated graph / typed returns |
| 259 | [How to Make Dark Hypnotic Techno like Soma and Planet Rhythm (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=rZnxiE7u7ns) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 260 | [How to Make Techno Synth like Hadone and Tim Tama (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=A_0GSDPk4i8) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 261 | [Acid Techno Track Breakdown (Ableton Techno tutorial)](https://www.youtube.com/watch?v=IlnnvsxvpZ0) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 262 | [How to Make Techno Kick Like Charlotte de Witte, UMEK and Joyhauser (Free Presets)](https://www.youtube.com/watch?v=IbeXMrvWAew) | auto-en | H | kick, percussion, effects | AR-DSP-01 kick morphology |
| 263 | [Acid Techno Live Performance - Push 2 / PC44 / Ableton Live 10](https://www.youtube.com/watch?v=PHXRcxLYPYw) | unavailable | U | - | no technical claim inferred |
| 264 | [How to Make Classic Techno Chord/Stab Synth (Free Preset) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=WlFFxGebffI) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 265 | [Arturia Minibrute 2S Tutorial and Review](https://www.youtube.com/watch?v=C809nsA9p4s) | auto-en | R | filter/mod, synthesis, rhythm | semantic automation / TPT core |
| 266 | [3 Game Changer Techno Sequencers (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=s2drgThbQgY) | auto-en | R | rhythm, tonal, filter/mod | resolved score / groove pulses |
| 267 | [Techno Sound Design Tips 16 (Ableton Wavetable)](https://www.youtube.com/watch?v=5PlbvI092jA) | auto-en | R | filter/mod, synthesis | semantic automation / TPT core |
| 268 | [How to Make Industrial Rave Techno (Arrangement,Mixing,Mastering)[Ableton Techno Tutorial]](https://www.youtube.com/watch?v=im0zDiMGZCY) | auto-en | H | tonal, percussion, mix | AR-DSP-02 clap/snare/rim body |
| 269 | [Techno Sound Design Tips 15 (Ableton Wavetable)](https://www.youtube.com/watch?v=58RtOtKqChU) | auto-en | R | tonal, effects, filter/mod | tonal roles / harmonic disclosure |
| 270 | [How to Make Industrial Rave Techno (Sound Design, Composition) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=W89s1-DJ_xA) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 271 | [How to Make Hypnotic Techno Bassline (free preset) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=AiaZHfMqN-8) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 272 | [Techno Sound Design Tips 14 (Ableton Wavetable)](https://www.youtube.com/watch?v=Pl1DyFIfNkE) | auto-en | R | filter/mod | semantic automation / TPT core |
| 273 | [How to Make Dark Techno Arp (Free Preset) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=hIMpNg-gRgs) | auto-en | R | effects, synthesis, timbre | generated graph / typed returns |
| 274 | [How to Make Industrial Techno Like Ghost In The Machine (Free Ableton Template)](https://www.youtube.com/watch?v=xyLY7kXKBOo) | auto-en | R | percussion, kick, effects | percussion grammar / modal voice |
| 275 | [How to Make Dark Techno Synth (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=DZAbdJcx0so) | auto-en | R | effects, filter/mod, arrangement | generated graph / typed returns |
| 276 | [Techno Sound Design Tips 13 (Ableton Wavetable)](https://www.youtube.com/watch?v=b3J4TnsA-gI) | auto-en | R | filter/mod, arrangement, effects | semantic automation / TPT core |
| 277 | [Ableton Push 2 : Best Controller Ever ? ( 3 years review + favourite tips)](https://www.youtube.com/watch?v=yLmzrDU_BpY) | auto-en | R | percussion, arrangement, effects | percussion grammar / modal voice |
| 278 | [Techno Sound Design Tips 12 (Ableton Wavetable)](https://www.youtube.com/watch?v=Ac8zz4w99pk) | auto-en | R | filter/mod, arrangement, timbre | semantic automation / TPT core |
| 279 | [How to Make Progressive Techno like Stil Vor Talent & Diynamic PART2(Arrangement, Mixing, Mastering)](https://www.youtube.com/watch?v=Itd7JGU5huM) | auto-en | H | mix, percussion, effects | AR-DSP-02 clap/snare/rim body |
| 280 | [How to Peak Time Techno Synth (free Preset + Rack) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=jpMlX_YCLAg) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 281 | [Techno Sound Design Tips 11 (Ableton Wavetable)](https://www.youtube.com/watch?v=stLOsfmJui0) | auto-en | R | filter/mod, tonal, arrangement | semantic automation / TPT core |
| 282 | [How to Make Dreamy Pad (Free Preset) / Ableton Techno Tutorial](https://www.youtube.com/watch?v=akzhxr8YfgQ) | auto-en | R | filter/mod, synthesis, tonal | semantic automation / TPT core |
| 283 | [How to Make Progressive Techno like Stil Vor Talent & Diynamic PART 1 (Sound Design)](https://www.youtube.com/watch?v=Hv28qoGtHS0) | auto-en | H | effects, percussion, filter/mod | AR-DSP-02 clap/snare/rim body |
| 284 | [How to Make Industrial Techno Scream Synth (Free Preset) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=8fIXV6j_uao) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 285 | [Techno Sound Design Tips 10 (Ableton Wavetable)](https://www.youtube.com/watch?v=imic277Wphs) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 286 | [How to Turn an 8 Bar Loop into a Full Techno Track (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=-3Ql_D3mT7Y) | auto-en | H | percussion, snare/clap, filter/mod | AR-DSP-02 clap/snare/rim body |
| 287 | [Techno Sound Design Tips 09 (Ableton Wavetable)](https://www.youtube.com/watch?v=3kHvhFRRK7w) | auto-en | R | effects, synthesis | generated graph / typed returns |
| 288 | [How to Make Techno in the Style of Odd Recordings (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=nFgDtY-zaJQ) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 289 | [How to Make Techno Kick From Scratch (+Free Samples) [Ableton Techno Tutorial]](https://www.youtube.com/watch?v=T2a7lTFjZxw) | auto-en | H | kick, percussion, effects | AR-DSP-01 kick morphology |
| 290 | [Techno Sound Design Tips 08 (Ableton Wavetable)](https://www.youtube.com/watch?v=noxevGYkV9M) | auto-en | R | effects, filter/mod, low-end | generated graph / typed returns |
| 291 | [5 SECRET WEAPONS (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=bqAI6TC6cNA) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 292 | [How to Plucky Brass Key (Free Preset) / Ableton Techno Tutorial](https://www.youtube.com/watch?v=b0grT_00bYw) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 293 | [How to Atmospheric Dub Techno Part 2 (Arrangement, Mixing, Mastering)](https://www.youtube.com/watch?v=tywb-Ny6Cb8) | auto-en | R | effects, arrangement, space | generated graph / typed returns |
| 294 | [How to get inspired quickly (Free Ableton Rack / Ableton Tutorial)](https://www.youtube.com/watch?v=lufIFsejzXk) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 295 | [Techno Sound Design Tips 07 (Ableton Wavetable)](https://www.youtube.com/watch?v=SpYeXi29M2w) | auto-en | R | synthesis, filter/mod, low-end | three synth architectures |
| 296 | [Techno Live Performance - Push 2 / Minibrute 2s / PC44 / Beatstep / Ableton Live 10](https://www.youtube.com/watch?v=3pXQhvDa9TI) | auto-en | R | - | standalone-product boundary |
| 297 | [Techno Sound DesignTips 06 (Ableton Wavetable)](https://www.youtube.com/watch?v=8h6YXOUwKjU) | auto-en | R | filter/mod, synthesis | semantic automation / TPT core |
| 298 | [How to Atmospheric Dub Techno Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=wRl_ESWbipI) | auto-en | H | effects, filter/mod, percussion | AR-DSP-02 clap/snare/rim body |
| 299 | [How to Punchy Techno Kick (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=guzmn4nhfg8) | auto-en | H | kick, percussion, effects | AR-DSP-01 kick morphology |
| 300 | [Techno Sound DesignTips 05  (Ableton Wavetable)](https://www.youtube.com/watch?v=fOcpzN4pnzA) | auto-en | R | filter/mod, space, arrangement | semantic automation / TPT core |
| 301 | [Rhack Series 04 - The Distortion Rhack (Ableton Tutorial)](https://www.youtube.com/watch?v=pRvCIOuI8FY) | auto-en | R | effects, mix, synthesis | generated graph / typed returns |
| 302 | [How to Drone Bass Sound (Free Preset) / Ableton Techno Tutorial](https://www.youtube.com/watch?v=wbIWWSxv1-8) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 303 | [How to Homemade Techno Mastering (Ableton Stock Plugin Only)](https://www.youtube.com/watch?v=C8cpYo3TVBE) | auto-en | R | mix, effects, kick | mix evidence / headroom |
| 304 | [What's wrong with me ?](https://www.youtube.com/watch?v=-9dvh8PU0Bo) | auto-en | R | effects, kick, filter/mod | generated graph / typed returns |
| 305 | [Techno Sound DesignTips 04  (Ableton Wavetable)](https://www.youtube.com/watch?v=msuOqMChgiA) | auto-en | R | filter/mod, effects, tonal | semantic automation / TPT core |
| 306 | [Techno Live Performance - Push 2 / Minibrute 2s / PC44 / Beatstep / Ableton Live 10 #JAMUARY](https://www.youtube.com/watch?v=GBWXfp0FRho) | unavailable | U | - | no technical claim inferred |
| 307 | [Techno Sound DesignTips 03  (Ableton Wavetable)](https://www.youtube.com/watch?v=k7IC-t2FvUM) | auto-en | R | filter/mod, timbre | semantic automation / TPT core |
| 308 | [How to Techno Synth Brass (Colyn - Resolve Lead inspiration) [ Ableton Techno Tutorial ]](https://www.youtube.com/watch?v=nCy__Jsieck) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 309 | [Techno Sound Design Tips 02 (Ableton Wavetable)](https://www.youtube.com/watch?v=AtR4CRDDtGg) | auto-en | R | filter/mod | semantic automation / TPT core |
| 310 | [Techno Sound Design Tips 01 (Ableton Wavetable)](https://www.youtube.com/watch?v=8tobNmxhQDg) | auto-en | R | synthesis | three synth architectures |
| 311 | [How to Make Techno Rumble with Toms (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=qK3WBPKOgJ4) | auto-en | H | effects, percussion, kick | AR-DSP-01 kick morphology |
| 312 | [How to Make Modern Techno Like Kraftek and Respekt style Part 2 (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=PTveth20jxY) | auto-en | R | percussion, arrangement, mix | percussion grammar / modal voice |
| 313 | [How to Make Modern Techno Like Kraftek and Respekt style Part 1 (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=d2nbwBtICsM) | auto-en | R | effects, percussion, kick | generated graph / typed returns |
| 314 | [How to make Melodic Techno Lead like Tale Of Us & Mathame (Ableton Techno Tutorial )](https://www.youtube.com/watch?v=LISEsY6ge7s) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 315 | [How to Dark Techno Ambience like SNTS (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=rEHc_IQPVOE) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 316 | [How to Make Industrial Techno like SNTS](https://www.youtube.com/watch?v=VatdNoEgDdI) | auto-en | R | effects, filter/mod, percussion | generated graph / typed returns |
| 317 | [How to Original and Creative Delay ( Reversed Dub Delay / Industrial Pitched)](https://www.youtube.com/watch?v=Rz13dvBOkCY) | auto-en | R | effects, filter/mod, sampling | generated graph / typed returns |
| 318 | [117 Ableton Wavetable Techno Presets](https://www.youtube.com/watch?v=HHz2sUzSssg) | auto-en | R | filter/mod, tonal, sampling | semantic automation / TPT core |
| 319 | [TECHNO LIVE PERFORMANCE (Eternal Chase - Le Bateau Ivre) on Push 2, Beatstep & PC44](https://www.youtube.com/watch?v=xNNXh51jfwc) | unavailable | U | - | no technical claim inferred |
| 320 | [How to Find the Perfect Techno Vocal Sample](https://www.youtube.com/watch?v=EN_7LAPtiis) | auto-en | R | space, sampling, effects | FDN / protected stereo route |
| 321 | [How to Make PoleGroup / A R T S  Deep Techno Part 2 (Arrangement, Mixing, Mastering)](https://www.youtube.com/watch?v=vnxTyHI1-BE) | auto-en | R | filter/mod, effects, mix | semantic automation / TPT core |
| 322 | [How to Make PoleGroup / A R T S  Deep Techno Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=xJUdEI28dVo) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 323 | [How to make your Techno Tom Fat and Punchy (+ pattern tips)](https://www.youtube.com/watch?v=zVMTxi7_-NY) | auto-en | R | percussion, filter/mod, effects | percussion grammar / modal voice |
| 324 | [How to Make Modern Techno Rave Synth  ( Ableton Techno Tutorial)](https://www.youtube.com/watch?v=62g9aS8-K1Y) | auto-en | R | filter/mod, tonal, effects | semantic automation / TPT core |
| 325 | [How to Make MORD/PERC TRAX Industrial Techno Part 2 (Arrangement, Mixing, Mastering)](https://www.youtube.com/watch?v=PsxaRoypy5s) | auto-en | R | mix, percussion, arrangement | mix evidence / headroom |
| 326 | [How to Ghost Notes Drums ( Ableton Tutorial )](https://www.youtube.com/watch?v=kZArxAwSocM) | auto-en | R | rhythm, percussion, timbre | resolved score / groove pulses |
| 327 | [How to Make MORD/PERC TRAX Industrial Techno Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=JKWzf22wNE0) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 328 | [How to Make Techno Plucky Pitched Synth (Ableton Techno Tutorial)](https://www.youtube.com/watch?v=C5K7hiP-yTo) | auto-en | R | synthesis, filter/mod, effects | three synth architectures |
| 329 | [How to " I Hate Models - Daydream" Inspiration Tutorial ( Synth Sound Design )](https://www.youtube.com/watch?v=XkySq7ts2KQ) | auto-en | R | filter/mod, effects, percussion | semantic automation / TPT core |
| 330 | [How to Make Dissonant Techno Synth / Sounds ( Ableton Techno Tutorial )](https://www.youtube.com/watch?v=rKtHYUWpRCI) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 331 | [FMT01 : Organizing Your Samples in Ableton [ FREE RACK ]](https://www.youtube.com/watch?v=BuPHTaG_4LE) | auto-en | H | percussion, sampling, effects | AR-DSP-02 clap/snare/rim body |
| 332 | [How to Rhythmic Techno Pad ( Ableton Tutorial / Quick Tip )](https://www.youtube.com/watch?v=pk6Ek_50Y4c) | auto-en | R | filter/mod, space, effects | semantic automation / TPT core |
| 333 | [How to Make INDUSTRIAL TECHNO Sound ? ( Ableton Techno Tutorial )](https://www.youtube.com/watch?v=7_RsPEu8WKo) | auto-en | R | effects, filter/mod, mix | generated graph / typed returns |
| 334 | [How To Make Afterlife Melodic Techno Part 2 (Arrangement, Mixing, Mastering)](https://www.youtube.com/watch?v=5tz0On1mfGs) | auto-en | R | arrangement, effects, tonal | director / performance grammar |
| 335 | [How To Make Afterlife Melodic Techno Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=4vU5PT01ddg) | auto-en | R | effects, arrangement, filter/mod | generated graph / typed returns |
| 336 | [How to Make Industrial Techno Kick (Free Rack) [ Ableton Techno Tutorial ]](https://www.youtube.com/watch?v=k3M1ho1OhDM) | auto-en | H | effects, percussion, kick | AR-DSP-01 kick morphology |
| 337 | [160 FREE WAVETABLES ! ( Plaits, PPG, ESQ-1, Serum, Waldorf...)](https://www.youtube.com/watch?v=u1lTWiWss2k) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 338 | [How to Make Industrial Techno Synth (Free Rack) [ Ableton Techno Tutorial ]](https://www.youtube.com/watch?v=drJWOjsGMpI) | auto-en | R | synthesis, filter/mod, effects | three synth architectures |
| 339 | [How to Make Techno Drum Groove / Pattern [ Ableton Techno Tutorial ]](https://www.youtube.com/watch?v=BzX9igDBONg) | auto-en | H | percussion, rhythm, kick | AR-DSP-02 clap/snare/rim body |
| 340 | [How To Make Drumcode Techno Part 2 (Arrangement, Mixing, Mastering)](https://www.youtube.com/watch?v=0uLnh_-tpmk) | auto-en | R | percussion, arrangement, mix | percussion grammar / modal voice |
| 341 | [How to Make Techno Perc Loop [ Ableton Techno Tutorial ]](https://www.youtube.com/watch?v=Q4ngQMtKtVY) | auto-en | R | filter/mod, effects, low-end | semantic automation / TPT core |
| 342 | [How To Make Drumcode Techno Part 1 (Sound Design, Composition)](https://www.youtube.com/watch?v=Ql31Jrkr3XM) | auto-en | R | effects, percussion, filter/mod | generated graph / typed returns |
| 343 | [How I made the Intro Synth Sound [ Techno / Ableton Tutorial ]](https://www.youtube.com/watch?v=8LGAfbls-pU) | auto-en | R | effects, filter/mod, synthesis | generated graph / typed returns |
| 344 | [How to make Stephan Bodzin Lead [ Ableton / Techno Tutorial ]](https://www.youtube.com/watch?v=HajZ6m2xQb8) | auto-en | R | synthesis, filter/mod, effects | three synth architectures |
| 345 | [How to Tale Of Us Astral Lead [ Ableton / Techno Tutorial ]](https://www.youtube.com/watch?v=zD3td3priLw) | auto-en | R | synthesis, filter/mod, effects | three synth architectures |
| 346 | [How to make your own Techno Kick Part 2 ( "Punchbox / Kick2" 's Ableton Stock Plugin Version )](https://www.youtube.com/watch?v=pmlqlxagoKI) | auto-en | H | kick, percussion, sampling | AR-DSP-01 kick morphology |
| 347 | [How to make your own Techno Kick Part 1 [ Techno / Ableton Tutorial ]](https://www.youtube.com/watch?v=zRsUMdhuroA) | auto-en | H | kick, percussion, synthesis | AR-DSP-01 kick morphology |
| 348 | [How to Make TECHNO BASSLINE form your Kick / Drums [ Ableton Tutorial / Techno ]](https://www.youtube.com/watch?v=l3GUEjpY8yE) | auto-en | H | percussion, low-end, effects | AR-DSP-01 kick morphology |
| 349 | [How to Create Your Own Hats Loops [ Ableton Tutorial / Techno TechHouse]](https://www.youtube.com/watch?v=J6_2ev2D9CA) | auto-en | R | rhythm, effects, timbre | resolved score / groove pulses |
| 350 | [All You Need Is Live - Dub Techno Final Session - Final Touch / Mixing](https://www.youtube.com/watch?v=BlrTnDgnpyY) | auto-en | R | percussion, effects, kick | percussion grammar / modal voice |
| 351 | [How to Make JOYHAUSER Techno Lead Style (Galaxy Phase / Kraftek) [Ableton / Techno Tutorial]](https://www.youtube.com/watch?v=vAFBc0JCrz0) | auto-en | R | effects, filter/mod, tonal | generated graph / typed returns |
| 352 | [How to Make Techno Ambient Pad [ Ableton Tutorial / Techno ]](https://www.youtube.com/watch?v=6ad77b_Zy-M) | auto-en | R | filter/mod, effects, tonal | semantic automation / TPT core |
| 353 | [How to make Dub Techno Chord/Fx (Deepchord, Basic Channel..)[ Ableton Tutorial  / Techno ]](https://www.youtube.com/watch?v=cLBu9RNaFDA) | auto-en | R | effects, filter/mod, arrangement | generated graph / typed returns |
| 354 | [How to Make Techno FM Chord ( Drumcode, Soma, Suara, Phobiq) [ Ableton Tutorial / Techno ]](https://www.youtube.com/watch?v=Jm6zD8XCAOU) | auto-en | R | synthesis, filter/mod, arrangement | three synth architectures |
| 355 | [How To Make Fx & Transitions [ Ableton Tutorial ]](https://www.youtube.com/watch?v=tLt30zxBUdg) | auto-en | R | effects, arrangement, percussion | generated graph / typed returns |
| 356 | [How to Write a TECHNO BASSLINE Part 1 ( Ableton Tutorial / Techno )](https://www.youtube.com/watch?v=NF0N4dRBDrs) | auto-en | R | rhythm, low-end, kick | resolved score / groove pulses |
| 357 | [How to make Enrico Sangiuliano Synth (Drumcode)   [Ableton Tutorial]](https://www.youtube.com/watch?v=Kq1zT_eHRU8) | auto-en | R | filter/mod, effects, synthesis | semantic automation / TPT core |
| 358 | [How to Perfectly Mix your Kick and Basseline (Ableton /Techno & Tech House )](https://www.youtube.com/watch?v=srYlP8SJaE8) | auto-en | H | percussion, kick, mix | AR-DSP-01 kick morphology |
| 359 | [How to make a Rolling Bassline ( Techno / Psytrance - Ableton Tutorial )](https://www.youtube.com/watch?v=sz3H42wHh-w) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 360 | [How to make  "Endless Smile" effect from Dada Life ( Ableton Tutorial / Build Up Effect )](https://www.youtube.com/watch?v=NanavEul_eM) | auto-en | R | effects, filter/mod | generated graph / typed returns |
| 361 | [How to make Techno Synth Horn ( Drumcode, Suara, Kraftek, Tronic, Soma, Phobiq...) [Ableton Tuto]](https://www.youtube.com/watch?v=PxQf9T_xgcQ) | auto-en | R | filter/mod, synthesis, effects | semantic automation / TPT core |
| 362 | [How to make Techno Reverb Kick   (Drumcode, Soma, Suara, Octopus...) [Ableton Tutorial]](https://www.youtube.com/watch?v=9y3szLs04RA) | unavailable | U | - | no technical claim inferred |
