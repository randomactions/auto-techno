# PCM spectral baseline contract

## Purpose and authority

AT-0020 adds descriptive spectral-shape, causal multiband-energy, and sampled
low-end-occupancy evidence over the exact Phase-1 whole mixes and aligned role
signals. It does not add a runtime evaluator dimension, quality threshold,
automatic correction, renderer, profile, engine, user mode, or release claim.

`StreamingPerceptualEvidenceAnalyzer` remains the sole owner of the current
short-time Hann/FFT definitions for centroid, bandwidth, flatness, and 85%
rolloff. `SpectrumMaskingAnalyzer` remains the sole owner of the four causal
one-pole-difference energy bands. `PCMSpectralBaselineAnalyzer` composes those
owners during detached local analysis; it does not reimplement either model.

Generated payloads and finalized reports live under
`docs/local/reports/spectral-baseline-v1/` and remain ignored, reconstructable
local evidence. They are not runtime, calibration, distribution, or bundled
resources.

## Exact input and provenance

The report accepts only the current checked whole-mix and role-stem manifests.
It independently rechecks each WAV's RIFF/IEEE-Float32 geometry, file SHA-256,
PCM SHA-256, manifest identity, sorted PCM-set fingerprint, corpus fingerprint,
contract-baseline fingerprint, source fingerprint, Git head, and engine version.
The exact corpus contains 14 whole mixes and 210 aligned role/reference/residual
signals. Missing, duplicate, extra, stale, malformed, path-divergent, or
non-finite input fails closed.

Stereo whole mixes use the arithmetic mean `(left + right) / 2`, matching the
canonical perceptual analyzer. Mono role files pass through unchanged. This
report does not measure channel difference, phase, or width; AT-0023 owns those
questions.

## Timeline and FFT geometry

Each asset is divided into contiguous, non-overlapping fixed-130-BPM bars:

```text
bar seconds = 4 beats * 60 / 130
bar frames  = nearest integer(sample rate * 240 / 130)
```

Each bar has exactly 16 contiguous causal cells, matching the masking analyzer.
Integer division assigns every source frame to exactly one cell; cells can differ
by one frame. Causal filters run continuously across the complete bar, so their
state is not reset at cell boundaries.

One canonical spectral window is centered in each causal cell. Its duration is
`1/24` second, rounded to an even frame count, multiplied by a symmetric Hann
window, and zero-padded to the next power-of-two FFT size. Current rates use:

| Rate | Spectral frames | FFT frames |
|---:|---:|---:|
| 44,100 Hz | 1,838 | 2,048 |
| 48,000 Hz | 2,000 | 2,048 |

The centered window is clamped only to the bar edge. A final segment shorter
than one spectral window is unavailable rather than silently padded into a
different observation. The 16 windows are deterministic samples of a bar, not
a claim of continuous-time spectral coverage.

## Spectral-shape family

For every sampled window the canonical FFT owner reports:

- magnitude-weighted spectral centroid in hertz;
- magnitude-weighted spectral bandwidth in hertz;
- 85%-power rolloff in hertz;
- power geometric-mean/arithmetic-mean flatness in `[0, 1]`;
- whether the canonical owner classified the window as spectrally active.

DC is excluded from these shape statistics exactly as in current primary
evidence. A valid inactive window uses zero numeric sentinels plus
`spectrumActive: false`; it is distinct from unavailable or non-finite input.

## Causal multiband-energy family

The existing masking filters provide mean-square amplitude-squared evidence in
four named bands:

| Band | Lower edge | Upper edge |
|---|---:|---:|
| `sub` | 35 Hz | 120 Hz |
| `low-mid` | 120 Hz | 420 Hz |
| `mid` | 420 Hz | 2,400 Hz |
| `high` | 2,400 Hz | 10,000 Hz |

Each band is the difference between adjacent causal one-pole low-pass states.
These filters overlap and are not a power-complementary reconstruction bank.
The report therefore records each mean square and its share of the sum of the
four analyzed bands, but explicitly makes no energy-conservation or full-band
power claim. Source mean square and source RMS dBFS are retained independently.

## Low-end occupancy

A causal cell is source-active when its source mean square is greater than
`1e-10`, the existing masking activity threshold. It is low-end occupied only
when all three facts hold:

1. the source cell is active;
2. the `sub` mean square is greater than `1e-10`;
3. `sub` is at least `0.10` of the four analyzed-band mean-square sum.

Segment and asset occupancy divide occupied cells by source-active cells. Exact
silence has an explicit zero denominator, zero occupancy, and zero band energy.
The 10% relation is a fixed descriptive classifier proved for known low/high
fixtures. It is not an audibility boundary, desired tonal balance, or quality
policy limit.

## Aggregation and schema

Every asset stores each window inside its source bar, plus segment and asset
summaries. Source and band mean squares are frame-weighted across causal cells.
Spectral-shape means and extrema use only spectrally active sampled windows.
Mean sub share uses only source-active cells. Count, geometry, dB, band-share,
activity, occupancy, and aggregation equations are independently reconstructed
by the Python verifier.

The Swift evidence schema is `autotechno-pcm-spectral-baseline.v1`; the report
schema is `autotechno-spectral-baseline-report.v1`. The finalized report adds a
canonical SHA-256 over its complete payload. It can be regenerated only from
the exact current local PCM and versioned analyzer contract.

## Operation

Normal tests do not read or write the private corpus. Explicit local export is:

```bash
AUTOTECHNO_RUN_SPECTRAL_BASELINE=1 swift test -c release --no-parallel \
  --filter SpectralBaselineIntegrationTests
python3 scripts/spectral_baseline_report.py generate
python3 scripts/spectral_baseline_report.py check
```

CI runs the synthetic analyzer and verifier mutation banks while the corpus
export remains opt-in and local-only.

## Qualification boundary and limitations

Synthetic fixtures cover known-bin tones, two-tone mixtures, deterministic
noise, silence, DC, impulses at timeline boundaries, mono cancellation,
44.1/48 kHz geometry, exact reuse of both canonical owners, malformed geometry,
and non-finite input. Verifier mutations cover missing windows, shifted
geometry, inconsistent band shares, false aggregates, stale fingerprints, and
manifest drift.

The report samples 16 short-time windows per bar, uses provisional causal band
filters, and folds stereo to mono. It does not establish audibility, masking
severity, mix correction, continuous spectral occupancy, stereo translation,
professional quality, listening approval, app/route behavior, or physical-
output soak. Those remain separate roadmap and release gates.
