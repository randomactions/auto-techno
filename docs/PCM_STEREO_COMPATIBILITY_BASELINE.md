# PCM Stereo Compatibility Baseline

## Status

Implemented as local-only, deterministic, descriptive evidence for roadmap item
AT-0023. This contract does not change production PCM, score resolution,
rendering, evaluation, adaptation, scheduling, transport, or UI.

The authoritative generated report remains ignored under:

```text
docs/local/reports/stereo-compatibility-baseline-v1/manifest.json
```

The committed files define the analyzer, independent reconstruction, schema,
and reproducible command. Generated WAVs, payloads, and manifests are evidence,
not product assets.

## Existing owners and boundary

`AudioQualityReport` remains the canonical owner of current accepted-programme
full-band and causal 140 Hz low-pass correlation. Its correlation uses its own
streaming report domain and continues to feed the current quality report.

`UpperTimbreEvidenceAnalyzer` remains the owner of bounded upper-mix width,
mono-loss, and correlation observations. Those facts retain upper-role mix-tap
and one-bar semantics.

`SpectrumMaskingAnalyzer` remains the owner of the established causal named
bands. AT-0023 extracts its coefficient/state implementation into
`MaskingBandFilter`; an exact parity fixture proves the existing masking-window
energies are unchanged.

`PCMStereoCompatibilityAnalyzer` owns only this detached whole/role corpus
view. Similar metric names do not make it a replacement for either runtime
owner.

## Exact input domain

The report consumes the two manifest-bound local domains created by AT-0016 and
AT-0017:

- fourteen exact stereo whole mixes;
- two hundred ten exact mono or stereo role, protected, reference, and
  residual signals, retaining each source WAV's native channel count.

Every record binds asset identity, source entry, signal role, classification,
PCM SHA-256, WAV path, source fingerprint, engine version, Git provenance,
roadmap contract fingerprint, and both input-manifest hashes. Unsupported
channel count, empty or unequal stereo channels, non-finite samples,
non-positive or non-integer sample rate, or invalid segment geometry fails
closed. Native mono is repeated as identical left and right solely for the
compatibility math, while `sourceChannelCount` remains `1`; this makes its
inherent mono safety explicit without pretending that the source WAV is
stereo. Native stereo retains its left/right channels and reports
`sourceChannelCount = 2`.

## Geometry and filter state

At fixed 130 BPM and four beats per bar, the segment length is:

```text
round(sampleRate * 240 / 130)
```

Every non-empty final partial segment is analyzed. The full-band domain uses
the exact source samples. The named bands reuse the causal one-pole-difference
bank:

| Domain | Lower cutoff | Upper cutoff |
| --- | ---: | ---: |
| `sub` | 35 Hz | 120 Hz |
| `low-mid` | 120 Hz | 420 Hz |
| `mid` | 420 Hz | 2,400 Hz |
| `high` | 2,400 Hz | 10,000 Hz |

Each cutoff coefficient is:

```text
a = 1 - exp(-2*pi*min(cutoff, 0.45*sampleRate)/sampleRate)
```

Filter state starts at exact zero at each segment boundary. Band signals are
adjacent one-pole-state differences. They overlap and are not a
power-complementary crossover, so their energies must not be summed or read as
conserved source energy. Asset summaries merge raw per-segment energy sums and
frame counts; they do not average ratios.

## Definitions

For each full or band-limited frame:

```text
mid  = (left + right) / 2
side = (left - right) / 2
```

For `N` frames, the report stores mean-square left, right, mid, and side
energy, plus mean left-right cross product. It derives:

```text
stereoMeanSquare = (leftMeanSquare + rightMeanSquare) / 2
correlation = crossMean / (sqrt(leftMeanSquare) * sqrt(rightMeanSquare))
monoRetentionRatio = midMeanSquare / stereoMeanSquare
monoLevelChangeDB = 10*log10(monoRetentionRatio)
sideEnergyShare = sideMeanSquare / (midMeanSquare + sideMeanSquare)
sideToMidRatio = sideMeanSquare / midMeanSquare
```

Exact sample-identical and opposite-polarity identities report correlation
`+1` and `-1` respectively. Every other active stereo state uses the factored
correlation denominator, which prevents premature underflow for extremely
quiet bands. That quotient is clamped only for floating-point round-off to the
closed range `[-1, 1]`. Correlation is `null` if either channel has zero energy. Mono
retention, mono level change, and side measures are `null` when their
denominator is zero; the unbounded side-to-mid ratio is also `null` if it cannot
be represented as a finite `Double`.
Exact mono cancellation has a mono-retention ratio of zero and a declared
`-120 dB` display floor; this sentinel does not imply residual PCM at that
level.

The half-sum/half-difference scaling yields the testable identity:

```text
stereoMeanSquare = midMeanSquare + sideMeanSquare
```

All activity decisions use exact digital-zero energy. No epsilon, programme
loudness threshold, perceptual audibility floor, or professional-quality
calibration threshold is hidden in this baseline.

## Structural compatibility states

States are deliberately narrow proofs, not artistic quality rankings:

| State | Exact condition | Meaning |
| --- | --- | --- |
| `inactive` | both channel energies are zero | valid silence; compatibility ratios are unavailable |
| `safeExactMono` | both channels active and side energy is zero | sample-identical channels; arithmetic mono is guaranteed to preserve the signal |
| `unsafeExactCancellation` | both channels active and mid energy is zero | exact opposite polarity; arithmetic mono is guaranteed to cancel the signal |
| `oneSided` | exactly one channel has energy | correlation is undefined; the state is neither silence nor anti-phase |
| `mixed` | every other active stereo case | descriptive correlation/width/retention only; no safe/unsafe or good/bad judgment |

Intentional decorrelation, delays, panning, upper spatial material, and unequal
channel gains therefore remain `mixed`. Low side energy is not an artistic
optimum, and negative correlation alone is not classified as unsafe. Any later
thresholded translation policy requires a separate calibrated item and may not
reinterpret this structural state silently.

## Determinism and independent verification

The Swift exporter reads exact Float32 PCM and fixes channel order, integer
sample rate, bar geometry, accumulation order, filter version/state, optional
encoding, aggregation, and analyzer version. Optional metrics are emitted as
explicit JSON `null`, never omitted.

`scripts/stereo_compatibility_baseline_report.py` independently:

1. reopens every manifest-bound WAV;
2. reconstructs deinterleaved Float32 channels;
3. recomputes full and band filter samples;
4. recomputes every raw energy, ratio, state, segment, and asset summary;
5. validates input manifests, PCM-set fingerprints, provenance, policy fields,
   and exact asset coverage; and
6. adds and checks a canonical SHA-256 report fingerprint.

Mutation tests reject changed energies, ratios, nulls, classifications,
cutoffs, manifest hashes, and report fingerprints. Synthetic Swift and Python
fixtures cover silence, exact mono, exact anti-phase, one-sided, unequal gain,
delay, DC, deterministic noise, amplitude scaling, low/high band separation,
44.1/48 kHz behavior, malformed input, and final partial segments.

## Reproduction

The prerequisite whole and role manifests and WAVs must already be current.
Then run:

```sh
AUTOTECHNO_RUN_STEREO_COMPATIBILITY_BASELINE=1 \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter StereoCompatibilityBaselineIntegrationTests/export

python3 scripts/stereo_compatibility_baseline_report.py generate
python3 scripts/stereo_compatibility_baseline_report.py check
python3 -m unittest scripts/test_stereo_compatibility_baseline_report.py
```

Use an isolated Swift scratch path when another task may be building the shared
checkout.

## Interpretation limits and follow-ups

This item proves exact algebra and uniform corpus availability. It does not
measure frequency-dependent coherence, inter-channel time delay, binaural
localization, loudspeaker-room translation, perceptual spaciousness, or
professional preference. It supplies no automatic correction, evaluator
input, promotion threshold, or controller signal.

Mono listening, app/route QA, hardware output, and long-running playback soak
are not required for this numerical baseline and are not implied by a passing
report. They remain separate evidence if a later audible implementation uses
these observations.
