# Source 22 Protagonist Spectral Reveal Implementation Plan

**Goal:** Extend the existing narrative protagonist with one bounded filter
aperture that reveals the same hook's spectral detail through the current
Resonant Mono and Tonal Motion architectures, with exact home behavior and
calibrated primary-evaluator evidence.

**Architecture:** Core resolves a typed reveal relation on existing anchor
notes. Both current foreground synth renderers apply the relation to their own
canonical cutoff path and report actual cutoff extrema. VoiceRenderer reduces
the isolated anchor tap once per bar. The candidate transaction retains the
bounded score/render/PCM record and force-home correction resolves it to home.

## Tasks

- [x] Add failing Core tests for relation eligibility, aperture geometry,
  deterministic replay, and exact home correction.
- [x] Add the Core relation/articulation/resolver, thread it through
  `ResolvedUpperNote` and `SynthPerformanceBar`, and fingerprint it in plan v13.
- [x] Add failing pure DSP tests for cutoff mapping, literal home identity,
  finite rate bounds, and both synth architectures.
- [x] Thread the aperture through `AlienVoiceNote`; apply it in Resonant Mono
  and Tonal Motion; capture exact per-note cutoff extrema.
- [x] Add per-bar isolated-anchor render evidence and preserve it through
  `RenderedBar` and `RenderBlock` construction/copy helpers.
- [x] Add candidate-vector schema 22 records, every-bar completeness,
  structural bounds, reason coding, attempt eligibility, and correction rules.
- [x] Add JSON/fingerprint/tamper tests plus same-bar active-versus-home routing
  and representative-rate integration tests.
- [x] Advance quality schema 24 and engine v23, update exact fingerprint
  fixtures, and add the focused suites to the existing serial CI groups.
- [x] Add the sanitized Source 22 research record and update product,
  provenance, validation, roadmap, sound-quality, and maturity documentation.
- [x] Regenerate and requalify the exact-engine primary profile, adversarial
  suite, and disjoint holdout artifact if the observation identity changes.
- [x] Run focused tests, the split exact local matrix, callback-symbol audit,
  optimized build, clean diff review, and a second static audit.
- [ ] Rebase on refreshed `origin/main`, rerun affected exact-head validation,
  commit, push to remote main, and confirm exact-head GitHub Actions before
  reporting Source 22 as 22/32.
