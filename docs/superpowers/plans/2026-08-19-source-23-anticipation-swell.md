# Source 23 Anticipation Swell Implementation Plan

**Goal:** Complete the existing debt-owned break and kick-recovery story with
one bounded pre-release crescendo: an already-resolved weak percussion event
anchors a one-step window on the current protected percussion stem, whose wet
return is reversed and shaped toward the unchanged recovery boundary.

**Architecture:** `KickSyntaxResolver` remains the long-form owner. On the
second withheld bar immediately before recovery, the existing
`PercussionEchoTextureResolver` may resolve an `anticipationSwell` relation
from the first canonical weak-percussion source. `PercussionEchoTextureVoice`
keeps its current gated-echo mode bit-identical and adds one detached,
bar-local reverse-tail rendering mode. No track, onset, instrument, FDN,
transport clock, callback state, or user control is added. Same-pass reduced
evidence proves source binding, output geometry, rising energy, exact-zero
boundaries, finite samples, and protected-routing agreement.

## Tasks

- [x] Add failing Core tests for exact second-withheld-bar eligibility,
  deterministic replay, and neutral conservative/debt-free/non-syntax bars.
- [x] Add the typed return relation, resolve it only from the canonical
  kick-syntax arc, preserve the existing gated echo, and fingerprint plan v14.
- [x] Add failing DSP tests for literal gated-echo identity, reversed-tail
  geometry, rising late/early energy, boundary zeros, finite output, and
  8/44.1/48/96/192 kHz frame invariants.
- [x] Implement the bounded bar-local reverse-tail mode in the existing
  percussion-return renderer; keep all work in detached preparation.
- [x] Extend render and candidate evidence with relation, kick-syntax binding,
  early/late RMS, rise dB, hashes, pass equality, and decoded tamper bounds.
- [x] Add a real prepared-product test proving the final withheld bar changes
  only the existing percussion-return path and recovery remains unchanged.
- [x] Advance candidate schema 23, quality schema 25, engine v24, and exact
  fingerprint fixtures; update focused CI filters if a new suite is added.
- [x] Add calibrated anticipation activity/rise observations, a flat-envelope
  adversarial case, and regenerate the exact-engine profile, adversarial suite,
  and disjoint holdout artifacts.
- [x] Record sanitized yt-dlp provenance, transcript/comment/audio limitations,
  the owner/reuse decision, and the future higher-resolution replacement path.
- [x] Run focused tests, the split exact local matrix, callback-symbol audit,
  optimized release build, clean diff review, and a fresh static audit.
- [ ] Rebase on refreshed `origin/main`, rerun affected exact-head validation,
  commit, push to remote main, and confirm exact-head GitHub Actions before
  reporting Source 23 as 23/32.
