# Kick/foundation collision baseline contract

## Purpose and authority

AT-0021 adds event-aligned, descriptive evidence for the exact accepted dry
kick and foundation role taps. It answers where those two signals are present,
where their activity coincides, where the existing causal sub-band model finds
similar energy, how long those sampled conditions persist, and whether the
canonical dotted-foundation articulation produced an exact pre-kick pocket.

This work does not add a runtime evaluator dimension, quality threshold,
automatic correction, renderer, score authority, continuation value, user
control, engine, profile, or release claim. `VoiceRenderer` remains the owner
of the post-fader audible kick, aggregate foundation tap, rendered kick onset,
and pocket consequence. The accepted resolved score and selected candidate
remain the event authority. `SpectrumMaskingAnalyzer` remains the sole owner of
the causal four-band energy model and its activity and overlap relations.

`PCMKickFoundationCollisionAnalyzer` composes those owners only during detached
local analysis. Generated payloads and reports live under
`docs/local/reports/kick-foundation-collision-v1/` and remain ignored,
reconstructable local evidence.

## Exact inputs and provenance

The exporter replays every `docs/BASELINE_CORPUS.json` checkpoint through the
same shared preparer, quality evaluator, bounded correction transaction, and
selected candidate used by the application. It retains no diagnostic stem PCM
from that replay. Instead, it requires the replay's session-state, plan, route,
checkpoint, quality, and replay identities to equal both current baseline
manifests, then reads the already captured `kick` and `foundation` WAVs.

The kick file is the exact post-fader audible dry kick. The foundation file is
the aligned aggregate bass, rumble, and foundation-companion contribution.
Both are mono, phrase-aligned, IEEE Float32 signals. The report binds the full
14-whole-mix/210-role-signal manifest set (224 assets total), both PCM-set
fingerprints, every WAV/PCM hash, the corpus, contract baseline, source
fingerprint, Git head, engine version, and the candidate-evaluation
fingerprint. A stale, missing, extra, duplicated, malformed, unaligned,
non-finite, or path-divergent input fails closed.

## Authoritative event binding

Only rendered kick events present in the accepted resolved score are eligible.
For every accepted bar, the exporter requires:

- the selected candidate's kick syntax to be complete and binding-valid;
- score and rendered kick counts and 16-step masks to agree;
- the selected foundation-rhythm evidence to be complete and binding-valid;
- the block, score bar, sample rate, and manifest geometry to agree.

The event onset is then reconstructed from the bound score step and exact
rendered bar size:

```text
bar frame count = nearest integer(sample rate * 240 / 130)
event onset      = bar start + nearest integer(step * bar frame count / 16)
```

This is the same zero-offset geometry used for rendered kicks. PCM peaks or
transient detectors never create, move, or name score events. A bar with no
eligible kick is valid and appears in `barsWithoutKick`; it does not acquire a
synthetic event.

`authoredFoundationRolesInBar` is score context limited to `bass`, `rumble`,
and `tunedTom`. It does not pretend that the aggregate foundation PCM can be
unmixed into those subroles. The only causally measured responsible signal
pair is therefore exactly `kick` and `foundation`.

## Event window and causal cells

Each event window begins at the exact kick onset and extends for two score
steps (one eighth note), bounded by the current bar:

```text
event end = min(bar end,
                kick onset + nearest integer(bar frame count / 8))
```

The canonical causal band analyzer divides that window into exactly 16
contiguous cells. Every frame belongs to one cell; cells may differ by one
frame. Filter state starts at zero at the event onset, then remains causal and
continuous across all 16 cells. Current event-window geometry is approximately
230.77 ms, with approximately 14.42 ms duration resolution. The report stores
the exact frame count of every cell, so the independent verifier reconstructs
rather than assumes the resolution.

Resetting at the event onset intentionally makes this an event-local response,
not a claim about continuously warmed filter state. AT-0020 remains the owner
of whole-bar continuous causal-band baselines.

## Activity, temporal overlap, and low-band overlap

For each role and cell, source activity means source mean square is greater
than `1e-10`, reusing the masking owner's existing threshold. A temporal
overlap cell has both exact role signals active.

The current low band is the masking owner's causal `sub` band, 35–120 Hz. A
low-band pair is eligible only when both role sources and both sub-band mean
squares are active. Its similarity is:

```text
min(kick sub mean square, foundation sub mean square)
-----------------------------------------------------
max(kick sub mean square, foundation sub mean square)
```

A low-band overlap cell has similarity greater than `0.38`, reusing the
canonical masking relation. The causal one-pole-difference bands overlap and
are not power-complementary. Therefore this classifier is evidence about the
existing provisional model, not proof of perceptual masking, phase alignment,
energy conservation, or poor mix quality.

## Collision classes

Each event receives one mutually exclusive descriptive class:

| Class | Meaning in the event window |
|---|---|
| `mutual-silence` | Neither exact role tap is active |
| `kick-only` | Kick is active and foundation is not |
| `foundation-only` | Foundation is active and kick is not |
| `separated` | Both roles occur, but never in the same sampled cell |
| `temporal-overlap` | At least one sampled cell contains both roles, but no cell passes the low-band similarity relation |
| `low-band-overlap` | At least one sampled cell contains both roles and passes the low-band similarity relation |

These classes describe evidence availability and coincidence. They are not a
ranked severity scale. In particular, overlap may be musically intended and
one-sided or separated evidence is not automatically preferable.

## Duration, timing, and relative level

Temporal and low-band durations sum the exact frame counts of classified
cells. The report also retains window count, first and last sampled frame,
longest contiguous run, seconds, and the maximum possible cell duration. These
are cell-quantized durations, never mislabeled as sample-exact collision
boundaries.

When both signals are active in at least one temporal-overlap cell, relative
energy is:

```text
10 * log10(sum(kick mean square * cell frames)
            / sum(foundation mean square * cell frames))
```

Positive values mean more kick energy in the sampled paired cells. The field
is explicitly `descriptive-not-calibrated-not-excessive`; neither the existing
automatic-mix companion targets nor an arbitrary new limit converts it into a
quality failure.

## Exact pre-kick pocket

The dotted-foundation pocket is independent from post-onset collision class.
When the selected foundation-rhythm evidence binds a pocket to the same kick,
the exporter supplies its phrase-absolute release and kick frames, exact
silence count, zero peak/RMS, application status, and finite status. The
analyzer rejects any mismatch. The independent verifier then confirms that
every exact foundation sample immediately preceding the kick for that retained
count is zero.

An event may therefore have `pocketState: exact-silence` and still have
post-onset `low-band-overlap`; that is a truthful articulation rather than a
contradiction. Events without an authored pocket use `not-authored`, not a
failed or inferred pocket.

## Confidence and unavailable states

Complete events use confidence
`exact-pcm-score-event-bound-causal-cell-quantized`. This is a compact statement
of evidence provenance and resolution, not a probability or listening score.
It means exact manifest-bound PCM, a score/render-bound accepted kick event,
the canonical causal band model, and quantized duration are all present.

The analyzer fails closed with stable reasons for unsupported sample rate,
empty or unaligned signals, non-finite PCM, duplicate events, invalid event
geometry, invalid pocket binding, insufficient windows, or unavailable
canonical band evidence. Current corpus export treats any such result as a
failed report rather than silently omitting the affected entry.

## Operation

Normal tests do not read private corpus audio or write reports. Explicit local
export and independent finalization are:

```bash
AUTOTECHNO_RUN_KICK_FOUNDATION_COLLISION=1 \
  swift test -c release --jobs 1 --no-parallel \
  --filter KickFoundationCollisionIntegrationTests
python3 scripts/kick_foundation_collision_report.py generate
python3 scripts/kick_foundation_collision_report.py check
```

CI runs the synthetic Swift fixture bank and Python verifier mutation bank.
Corpus export remains opt-in and local-only.

## Qualification boundary and limitations

Synthetic fixtures cover exact low-frequency overlap, temporal overlap without
sub-band similarity, separated tails, kick-only, foundation-only, mutual
silence, exact pockets, phase inversion, 44.1/48 kHz geometry, malformed
events, non-finite PCM, and fail-closed provenance. Python mutations cover band
energy, class, duration, optional evidence, event geometry, pocket, manifest,
contract, and report-fingerprint drift.

This baseline does not determine perceptual masking, phase compatibility,
constructive versus destructive summation, desired kick/bass relationship,
professional quality, automatic EQ, dynamic sidechain policy, listening
approval, app/route behavior, or physical-output soak. It changes no production
PCM and has no continuation or future-boundary effect. Later calibration may
promote a bounded relationship only through the existing single evaluator and
controller contract.
