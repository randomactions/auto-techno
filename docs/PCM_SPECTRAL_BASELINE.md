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

## Algorithmic masking component benchmark

`SpectrumMaskingAnalyzerTests.algorithmicFaultBenchmark` exercises the existing
analyzer against a frozen 36-case mathematical matrix: three construction
families, both native rates, and six role relations. Sine is development;
triangle and asymmetric pulse are held-out construction families. No threshold
is fitted. These fixed cases are not random population samples and do not
justify confidence intervals about listeners or arbitrary music.

The test emits `autotechno-algorithmic-masking-component.v1` JSON with every
case, family/rate error summaries, explicit failures and unavailable dimensions.
Binary-power amplitude scaling has an exact band-energy-ratio oracle. A separate
test-only linear-sum calculation detects complete cancellation, and an explicit
required-role check distinguishes deletion from intentional absence. Identical
overlap values therefore do not imply identical signal consequences. The
linear-sum arithmetic bound is derived from Double precision and sample count;
it is not a musical tolerance. This diagnostic is not the nonlinear production
mix, a rendered score check, a perceptual model or a calibrated quality gate.

Existing frequency-holdout and collision counterexamples remain unchanged.
Run the ordinary suite with `swift test --no-parallel --filter
SpectrumMaskingAnalyzerTests`. A compiler-only component check is also possible
when XCTest/Testing modules are unavailable:

```sh
at0039_check_dir=$(mktemp -d)
cat > "$at0039_check_dir/Run.swift" <<'SWIFT'
import Foundation
@main struct Run {
    static func main() throws {
        let report = SpectrumMaskingAnalyzerTests.AlgorithmicMaskingBenchmark.run()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(report))
        FileHandle.standardOutput.write(Data([0x0A]))
        if !report.failures.isEmpty { exit(1) }
    }
}
SWIFT
swiftc -O -package-name AutoTechno -D AUTOTECHNO_MASKING_COMPONENT_CHECK \
  -module-cache-path "$at0039_check_dir/module-cache" \
  Sources/AutoTechnoDSP/SpectrumMaskingAnalyzer.swift \
  Tests/AutoTechnoCoreTests/SpectrumMaskingAnalyzerTests.swift \
  "$at0039_check_dir/Run.swift" -o "$at0039_check_dir/check"
"$at0039_check_dir/check" > "$at0039_check_dir/report.json"
```

The component flag excludes the Swift Testing declarations only. The benchmark
helper and production analyzer are the exact source files compiled by the test
target. Record compiler and input hashes beside results. A successful component
run does not assert that the ordinary suite, semantic map, whole package, score
fidelity, resource gates or runtime qualification passed. No production build
uses this flag, and no source or runtime parameter changes.

## Independent causal-filter response controls

`SpectrumMaskingAnalyzerTests.algorithmicFilterResponse` tests all four declared
bands at 44,100 and 48,000 Hz using 4,096-frame inputs of exactly representable
amplitude 1/4. A constant step is development; a single impulse and an alternating
sign sequence are held-out constructions. The definitions and error envelopes
are fixed before analyzer access, with no fit, search or output-based selection.
They test distinct finite-input responses of the declared linear filter, not
independent musical populations or general frequency-response calibration.

For a pole `q = exp(-2*pi*cutoff/sampleRate)` and zero initial state, the oracle
evaluates these finite geometric sums directly at frame `n`:

- step: `(1 - q^(n+1))/4`;
- impulse: `(1-q)*q^n/4`;
- alternating: `(1-q)*((-1)^n + q^(n+1))/(4*(1+q))`.

Each band's expected output is the upper-cutoff response minus the lower-cutoff
response. Integer powers use exponentiation by squaring, independently of the
production recurrence. The native-rate cutoff clamp is inactive. Both paths
use the platform exponential to construct the declared pole; this does not
independently qualify the math library. Expected window energies are integrated
from those analytic samples, with exact window boundaries fixed by the fixture.

Absolute error bounds use `gamma(k) = k*Double.ulpOfOne/(1-k*Double.ulpOfOne)`:
`k=32*(N+1)` for samples and `k=128*(N+1)` for window energies. These conservative
forward-error envelopes cover two contractive pole recurrences, coefficient
subtraction, finite-series evaluation, band subtraction and window accumulation
for bounded input magnitude 1/4. Integer-power error is bounded by its equivalent
multiplication tree of at most N operations. Division in the alternating formula
has denominator at least one; subtraction is assessed absolutely, including
near-zero tails. The energy envelope additionally covers squaring and averaging
samples whose band magnitude is at most 1/2. `ulpOfOne` is twice unit roundoff.
These are arithmetic bounds, not musical tolerances, and neither is fitted to
observed errors.

The `autotechno-masking-filter-response.v1` report contains 24 family/rate/band
rows with sample and window-energy MAE, RMSE, signed and maximum error, counts,
bounds and explicit failures. Missing/nonfinite results cannot pass; unavailable
summaries omit error values. Replays must be identical. Fixed constructions do
not justify population confidence intervals. Score realization, shared nonlinear
mix quality and perceptual masking remain separate requirements. Existing
frequency-holdout results and counterexamples remain unchanged.

The component command above can exercise the exact same helper by replacing
`AlgorithmicMaskingBenchmark` with `AlgorithmicFilterResponseBenchmark`; it still
does not execute the ordinary Swift Testing suite or qualify the whole runtime.
The existing test suite and analyzer retain their ownership, execution boundary,
state and dependency semantics; this addition has no semantic-map impact.
