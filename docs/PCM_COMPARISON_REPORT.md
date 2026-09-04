# PCM comparison report contract

## Purpose and boundary

`scripts/pcm_comparison_report.py` compares two valid local whole-mix manifests
or two valid local role-stem manifests without rendering audio. It converts an
otherwise opaque SHA-256 change into deterministic, sample-indexed evidence:

- exact byte identity;
- finite numeric drift inside both declared tolerances;
- finite signal change outside either tolerance; or
- structural incompatibility that makes numeric comparison unsound.

This is an offline evidence contract. It does not replace the runtime's typed
fingerprints, choose a candidate, change quality state, set a professional-
quality threshold, or enter the app, transport, scheduler, C handoff, callback,
or distribution. Reports and compared WAVs remain ignored under `docs/local`.

## Accepted inputs

The comparator accepts one of two existing manifest schemas:

| Domain | Manifest schema | Asset identity |
|---|---|---|
| Whole mix | `autotechno-baseline-render-manifest.v1` | `<entry-id>::whole-mix` |
| Role signal | `autotechno-role-stem-manifest.v1` | `<entry-id>::<signal>` |

Both inputs must use the same domain before any numeric result can be promoted
above `incompatible`. Every manifest path must remain within its explicitly
declared root. Each referenced file must be a canonical 44-byte-header mono or
stereo 32-bit little-endian IEEE-float WAV. The comparator independently checks
sample rate, channel count, frame count, PCM SHA-256, whole-file SHA-256, RIFF
geometry, payload length, and finiteness. Missing, stale, malformed, path-
escaping, truncated, or non-finite evidence is rejected before classification
and produces no report.

The roots are command inputs rather than report fields. This keeps local
absolute usernames and checkout paths out of evidence while allowing the same
relative manifest to be verified in a different checkout.

## Exact and bounded measurements

Samples are decoded in manifest channel order. For baseline sample \(b_i\) and
candidate sample \(c_i\):

\[
e_i = |c_i - b_i|
\]

\[
e_{max} = \max_i e_i
\]

\[
e_{rms} = \sqrt{\frac{1}{N}\sum_i e_i^2}
\]

The sum of squares is accumulated deterministically and reports use the exact
decoded Float32 values. `changedSampleCount` uses raw Float32 bit identity, so
different encodings such as positive and negative zero are not called exact
even when their numeric error is zero. `firstChangedFrame` and
`firstChangedChannel` locate the first changed raw sample in interleaved order.

Default tolerances are deliberately measurement-scale rather than artistic:

| Threshold | Default | Meaning |
|---|---:|---|
| `absoluteSampleError` | `1e-6` | No individual decoded sample may differ by more |
| `rmsError` | `1e-7` | The asset-wide error energy must remain below this value |

Changing either threshold changes the report fingerprint. A bounded result is
not evidence that a change is inaudible, desirable, qualified, or safe; it says
only that both declared numeric bounds hold.

## Classification

Classification is deterministic and ordered:

1. `incompatible` — manifest domains, asset sets, sample rates, channel counts,
   or frame counts differ. Compatible intersections may still be reported, but
   the root result remains incompatible.
2. `material` — structures are compatible and at least one asset exceeds its
   absolute or RMS tolerance.
3. `bounded` — structures are compatible, at least one raw sample changes, and
   every asset remains within both tolerances.
4. `exact` — structures are compatible and every compared PCM payload has the
   same SHA-256 identity.

The terms are evidence vocabulary, not musical verdicts. In particular,
`material` means numerically outside the requested bounds and does not mean
better or worse.

## Fingerprints and report shape

The report schema is `autotechno-pcm-comparison-report.v1`. Each input records:

- relative manifest path and manifest SHA-256;
- manifest schema and comparison domain;
- source, Git, engine, and contract-baseline provenance when present;
- asset count; and
- `pcmSetFingerprint`, the SHA-256 of sorted asset identity plus verified PCM
  SHA-256 pairs with explicit separators.

Each comparable asset records geometry, exact baseline/candidate PCM hashes,
classification, sample/change counts, first changed frame/channel, maximum
absolute error, and RMS error. The summary is sample-weighted across comparable
assets and retains exact, bounded, and material asset counts. Structural issues
use reason-coded entries rather than prose-only failure.

`reportFingerprint` is SHA-256 over canonical sorted compact JSON before the
fingerprint field is inserted. `check` rebuilds the entire report from current
WAVs, manifests, and recorded tolerances; an added, missing, reordered, rounded,
or edited value fails closed.

## Commands

Whole-mix comparison:

```sh
python3 scripts/pcm_comparison_report.py compare \
  --baseline-manifest docs/local/reports/baseline-corpus-v1/manifest.json \
  --candidate-manifest docs/local/reports/baseline-corpus-v1/manifest.json \
  --output docs/local/reports/pcm-comparisons-v1/whole-mix-self.json
```

Role-signal comparison:

```sh
python3 scripts/pcm_comparison_report.py compare \
  --baseline-manifest docs/local/reports/baseline-stems-v1/manifest.json \
  --candidate-manifest docs/local/reports/baseline-stems-v1/manifest.json \
  --output docs/local/reports/pcm-comparisons-v1/role-stems-self.json
```

Revalidation:

```sh
python3 scripts/pcm_comparison_report.py check \
  --report docs/local/reports/pcm-comparisons-v1/whole-mix-self.json
```

Synthetic tests own exact, one-sample bounded, gain/offset material, role-local,
channel/identity incompatibility, NaN, truncation, stale-hash, and report-
mutation cases. A future production change must compare an explicitly named
candidate manifest against the preserved baseline rather than relabel a self-
comparison as change evidence.
