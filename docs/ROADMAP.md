# Roadmap

Auto Techno now has one current runtime and one executable product. Work should
strengthen that path rather than add alternative engines or comparison modes.

## Current baseline

- one-button autonomous macOS app;
- fixed 130 BPM and deterministic default seed;
- phrase candidates selected with temporal memory, interest scoring, ensemble
  arbitration, and dramatic-debt repair;
- required Scene DNA and synth plans;
- generated topology for upper voices with protected kick/bass foundation;
- detached preparation, sample-time scheduling, and route recovery;
- objective preflight for finite samples, peaks, DC, low-end correlation,
  boundaries, masking, and continuation.

## Next validation work

1. Restore a matching local Swift compiler/SDK or run exact-head macOS CI, then
   execute the complete test suite and release build.
2. Smoke-test one-button prepare/play/pause/resume, phrase-boundary continuation,
   late-successor repetition, and 44.1/48 kHz route recovery.
3. Capture fixed-seed 42, 48291, and 90909 metrics and matched-loudness renders
   whenever render math changes.
4. Complete the 60-minute physical-output soak with pause/resume, route changes,
   interruption, and sleep/wake before a release-ready claim.

## Product development

Musical improvements must begin with one concrete listening observation. Add the
smallest deterministic rule that addresses it, compare fixed seeds at matched
loudness, and keep it only when the intended perceptual result is confirmed.
Prefer meaningful performance structure and synth authorship over marginal DSP
controls. Keep all new control surfaces semantic and listener-facing.

## Non-goals

- restoring retired reference executables or 32/96-bar comparison paths;
- exposing internal Core or DSP libraries as supported products;
- adding configurable treatment, mastering, effect, stem, rhythm, synth-engine,
  or performance-model switches;
- moving planning or mutable preparation work onto the real-time callback;
- accepting sample changes from objective metrics alone.
