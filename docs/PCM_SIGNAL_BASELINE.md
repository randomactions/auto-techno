# PCM signal baseline contract

## Purpose and ownership

AT-0019 turns the exact Phase-1 whole mixes and aligned role signals into a
durable local baseline for level, signal-integrity, and silence investigation.
`PCMSignalIntegrityAnalyzer` is one reusable `AutoTechnoDSP` evidence capability.
It consumes already-owned PCM after detached preparation; it is not a renderer,
evaluator, quality profile, correction controller, runtime mode, or user control.

The analyzer reuses `BS1770AudioEvidence` for the canonical ITU-R BS.1770-5
Annex-2 four-phase FIR. It therefore reports the same true-peak definition as
candidate and live evidence rather than a second interpolation proxy. None of
the new evidence is consumed by the app, score, preparation transaction,
scheduler, route lifecycle, C handoff, or realtime callback.

## Input domain and segmentation

The opt-in local exporter requires both current ignored manifests:

- 14 stereo whole-mix assets from
  `docs/local/reports/baseline-corpus-v1/manifest.json`; and
- 210 mono/stereo role, reference, processed-stage, protected-variant, and
  residual assets from
  `docs/local/reports/baseline-stems-v1/manifest.json`.

Every manifest and WAV hash is rechecked before analysis. Assets are processed
one at a time and released before the next file. The report preserves the exact
manifest PCM identity, signal name, role classification, channel count, route
rate, and frame count.

One segment is one fixed-tempo bar:

\[
N_{segment} = round(f_s \times 4 \times 60 / 130)
\]

Segments are non-overlapping, start at frame zero, and remain contiguous. The
last segment may be shorter. At 44.1 kHz the segment is 81,415 frames; at 48 kHz
it is 88,615 frames. This physical/musical boundary is evidence-only and never
creates another clock or score owner.

## Metrics and units

For every complete asset, each channel, each bar segment, and each segment
channel, the analyzer records:

| Field | Definition |
|---|---|
| sample peak | maximum absolute decoded Float32 sample |
| sample peak dBFS | `20 log10(samplePeak)`, floored at `-120 dBFS` |
| true peak | canonical Annex-2 four-times-oversampled FIR peak, with sample peak retained as its lower bound |
| true peak dBTP | `20 log10(truePeak)`, floored at `-120 dBTP` |
| RMS | square root of mean squared decoded samples |
| crest factor | sample peak divided by RMS; exact zero for silence |
| DC offset | arithmetic mean of decoded samples |
| clipped samples | count whose absolute amplitude is at least `1.0` |
| subnormal samples | nonzero count below `Float.leastNormalMagnitude` (`1.1754943508222875e-38`) |
| non-finite samples | exact NaN or infinity count |
| exact-zero samples | positive or negative zero count |
| near-silence samples | count at or below `-90 dBFS` (`3.1622776601683795e-5`) |

The combined statistic is channel-sample weighted. It does not downmix, so a
stereo RMS is the square root of total channel energy divided by twice the frame
count, matching the current phrase-wide runtime convention. Combined peak and
true peak are the channel maxima. The report additionally counts frames where
every channel is finite and near-silent and retains the longest contiguous run.

A non-finite sample remains countable evidence, but the affected window's peak,
true-peak, RMS, crest, and DC fields become unavailable rather than encoding a
NaN in JSON or silently dropping the sample. Current governed manifests already
reject non-finite PCM; synthetic tests retain this behavior as a regression
contract.

## Report and fail-closed verification

The Swift exporter writes ignored
`docs/local/reports/signal-baseline-v1/payload.json`. The independent Python
finalizer verifies:

- current corpus, contract, source, Git, engine, manifest, WAV, and PCM identity;
- exact 14 + 210 asset coverage in stable order;
- policy constants and one-bar geometry at each route rate;
- contiguous segment and channel geometry;
- count, peak, RMS, DC, crest, dB, channel, and segment aggregation identities;
- finite baseline metrics and possible silence-run bounds; and
- exact PCM-set fingerprints for both input domains.

It then writes `autotechno-signal-baseline-report.v1` with a SHA-256 fingerprint
over canonical sorted compact JSON. `check` reopens current manifests and WAVs,
rebuilds every structural and aggregate invariant, and rejects stale or edited
reports. The verifier intentionally does not reimplement the Annex-2 FIR;
canonical true-peak ownership stays in one Swift implementation and is covered
by the existing standards fixtures plus AT-0019 analyzer fixtures.

## Commands

After a full-Xcode test build:

```sh
AUTOTECHNO_RUN_SIGNAL_BASELINE=1 swift test --no-parallel \
  --filter SignalBaselineIntegrationTests

python3 scripts/signal_baseline_report.py generate
python3 scripts/signal_baseline_report.py check
```

The payload, report, manifests, and WAVs remain local and ignored. They may be
used as inputs to later roadmap measurements and explicit before/after
comparisons. Mere presence, a clean current baseline, or an apparently favorable
aggregate is not an automated-quality, listening, app/route, soak, publication,
or professional-release result.
