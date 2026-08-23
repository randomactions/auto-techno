# Source 32: fresh autonomous session identity

## Source evidence

- Video: `https://www.youtube.com/watch?v=KOVs5AarmUw`, *3 approaches to
  subliminal modulation*, Underdog Electronic Music School, accessed
  2026-08-23.
- Transcript: YouTube automatic English captions retrieved with `yt-dlp`
  2026.08.19. The `en` and `en-orig` VTT files were byte-identical with
  SHA-256
  `07158c17072f329945e23779e2173cfdee1962b3ae537b7b2107b996939fe0fa`.
  The structured English JSON3 capture had SHA-256
  `2171cf2fbeaa6d8a09926681e02e5363254ec0b63fd4f3044fe88cf38efee646`.
- Page discussion: 39 top-level comments and 10 replies were retained in the
  metadata capture, whose SHA-256 was
  `8999bb1e00fe88bd440a5c92a1c62f81afb1b22a8ac1650d0ff5b65abcb5b257`.
  One technically relevant comment warned that stacking subliminal movement
  without restraint can make a loop incoherent or chaotic. The discussion did
  not converge across three independent reports on a portable amount, rate,
  pitch interval, filter frequency, effect choice, or mix value.
- Audio demonstration: direct unauthenticated extraction decoded to 48 kHz
  stereo PCM with duration 749.877 seconds and SHA-256
  `a0fbb03fb07b28e9b5bfe2f932a8c3c381fb90b26dc0fb364526689d46101901`.
  Machine-only 8,192-point inspection found broad spectral movement in the
  alternating-release and alternating-pitch demonstrations, a comparatively
  steady bright filter excerpt, and larger variation in the wet-shadow
  excerpts. Speech, interface sounds, compression, and edit boundaries
  contaminate all of those windows, so the measurements are descriptive only
  and establish no implementation threshold.

The current yt-dlp installation and local Deno runtime solved extraction
directly. No account, cookie, CAPTCHA, browser session, or token provider was
used. Captions, comments, metadata, audio, and machine inspection remain
temporary and untracked.

## Portable concepts and repository reconciliation

The source presents three ways to prevent an exact short loop from feeling
frozen:

1. alternate tiny event properties such as pitch and release;
2. move a filter slowly over a period longer than one bar; and
3. retain a dry signal while a subtly moving effect shadow runs in parallel.

The canonical engine already owns all three intra-session idea families:

- score-resolved percussion and groove-pulse events carry deterministic
  seed-derived microvariation and continuation rather than callback randomness;
- relational filter, pad, spectral, and long-form score state already moves
  across bars and phrases;
- score-owned percussion echo/FDN and synth chorus/spatial sends already create
  dry-plus-moving-shadow relationships through the one canonical graph.

Adding another track, closed-hat alternator, filter lane, modulation bus,
chorus, reverb, effect chain, renderer, or user control would duplicate those
owners and risk the incoherence identified in the discussion. The low-confidence
alternative is recorded locally in the ignored source-evidence notebook rather
than shipped.

## Falsifiable deficit

The App currently constructs `AutonomousSessionDirector()` with its default
root seed `48_291` on every process launch. That makes the first resolved score,
graph, fingerprints, and PCM repeat exactly across launches. This directly
contradicts the product promise that a new autonomous performance is creative,
even though variation within one deterministic session is already coherent.

The missing reusable capability is therefore fresh app-owned session identity,
not another sound layer. The hypothesis is falsified if two independent App
sessions already receive different root seeds and produce different first-plan
and PCM identities. It is supported when an injected fixed seed replays exactly,
two fresh session seeds diverge, and pause, recovery, and continuation retain
one accepted seed.

## Ownership, bounds, continuation, and fallback

Add one `@MainActor` App-layer seed source. Its production path draws one
`UInt64` from `SystemRandomNumberGenerator` before detached preparation starts.
It is injectable for deterministic App tests. A repeated draw is rotated by a
fixed nonzero mixing step so a completed session boundary cannot silently reuse
the immediately previous identity.

`TechnoEngine` owns the current director and replaces it only at a complete
session boundary:

- process/view creation receives one fresh seed before the first plan;
- pause/resume, playback-timeline reset, live correction, route change, and
  route recovery retain the current seed and continuation;
- complete shutdown invalidates detached preparation, cached targets, live
  feedback, and transport state, then installs the next fresh director for a
  later appearance;
- an explicit fixed injected source remains exactly reproducible;
- entropy failure has no throwing or blocking path: a repeated value is mixed
  deterministically away from the excluded prior value.

The selected seed becomes normal `AutonomousSessionState.rootSeed` provenance;
Core remains the canonical score owner. No entropy is read by the audio
callback, renderer, evaluator, or continuation logic. No cloud service,
account, persisted identifier, selector, or second engine is introduced.

## Preparation-cache isolation

Bind `PhrasePreparationKey` to `sessionSeed`. Every initial, successor,
corrected, and route-recovery request carries the exact source-state seed.
Prepared acceptance requires the key, request state, current session, and
prepared plan to agree on that identity. Cache trimming removes entries from
other sessions. A stale detached result or cached successor from the previous
session therefore cannot cross the reset boundary even if phrase index, route,
quality revision, and controller fingerprints coincide.

The neutral fallback is the same canonical deterministic engine under the
selected seed. Unsupported routes still fail closed. This slice changes no
score schema, DSP graph schema, evaluator policy, primary artifacts, rendered
semantics for a fixed seed, or realtime producer object.

## TDD and validation

- Add failing App tests first for an injectable seed sequence, fresh initial
  identity, rotation after complete shutdown, repeated-source collision
  avoidance, fixed-seed first-plan/PCM replay, distinct-seed first-plan/PCM
  divergence, and continuity across non-terminal transport actions.
- Add request/cache contract tests or a narrow package-visible probe proving
  the root seed participates in preparation identity and stale-session results
  fail closed.
- Implement the App-only source and mutable director, then bind all request
  keys and acceptance paths to the current seed.
- Run the new App suite plus existing App live-feedback coordination,
  deterministic architecture/session tests, preparation preflight, protected
  routing, repository-surface checks, and the optimized product serially with
  isolated build/cache paths.
- Verify that fixed-seed prepared transactions and representative PCM remain
  byte-identical, distinct seeds differ, no callback source changed, and the
  release realtime-producer object retains only its allowed copy primitive.
- Inspect the diff, commit the implementation, refresh/rebase if main moves,
  push both the source branch and main, require exact-head GitHub Actions
  success, and launch that exact release app.

## Maturation boundary

The durable idea is that creativity begins with a fresh performance identity
while coherence comes from deterministic evolution after that boundary. The v1
system entropy source, one-`UInt64` identity, collision mixer, and view-lifetime
boundary are replaceable implementation details.

A later serious system may replace them in place with a cryptographic session
identifier, persisted opt-in replay tokens, a richer style prior, calibrated
novelty memory across sessions, or evaluator-owned repetition evidence only
after repeatable diversity, collision, provenance, or creative-range deficits
are measured. It must preserve explicit-seed reproducibility, score ownership,
future-boundary application, cache isolation, callback silence, one canonical
renderer, and one primary evaluator. It must supersede this seed source rather
than add a second random engine, alternate performance mode, or user-facing
randomness control.
