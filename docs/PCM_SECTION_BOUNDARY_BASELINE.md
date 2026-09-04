# PCM Section-Boundary Baseline

## Purpose and authority

`PCMSectionBoundaryBaselineAnalyzer` is a detached, descriptive evidence layer
for exact local accepted PCM. It aligns score-declared phrase and interlock-
chapter boundaries with sample-indexed observations already owned by the signal,
spectral, stereo-compatibility, and rhythmic analyzers. It does not discover
sections from audio, rank transition quality, change a score, alter PCM, or feed
the evaluator, controller, renderer, continuation, scheduler, callback,
transport, or UI.

`AutonomousSessionDirector` and `AutonomousPhrasePlan` remain authoritative for
phrase identity, kind, start bar, and accepted resolved score. Resolved
`InterlockChapter` remains the chapter owner. `LongHorizonContinuation` remains
the owner of future transition/recovery intent. The analyzer only composes their
exact identities with existing PCM facts.

## Schemas and fixed versions

- evidence: `autotechno-pcm-section-boundary-baseline.v1`;
- analyzer: `autotechno-pcm-section-boundary-baseline-analyzer.v1`;
- local artifact: `autotechno-section-boundary-baseline-artifact.v1`;
- local manifest: `autotechno-section-boundary-baseline-manifest.v1`.

The fixed metric order is combined RMS dBFS, crest factor, sub/low-mid/mid/high
causal-band shares, full-band side-energy share, PCM-inferred onset count, and
rest occupancy. These values retain their native units and are never collapsed
into a scalar contrast or quality score. The causal bands are the established
overlapping one-pole differences and are not a power-complementary crossover.

## Bounded raw input

One input contains one focus phrase, its exact accepted predecessor when one
exists, and one exact accepted successor. It is limited to three contiguous
phrase indices and forty-eight complete bars. Each bar retains:

- phrase index/kind, absolute bar, phrase-local bar, and interlock chapter;
- exact start frame and frame count;
- the nine ordered per-bar metrics;
- sixteen exact cells with sample range, source RMS dBFS, four causal-band
  shares, and PCM-inferred onset count.

The PCM builder requires aligned finite mono/stereo samples, integer positive
sample rate, exact 130-BPM four-beat bar geometry, contiguous score/bar identity,
and complete bars. It delegates observations to
`PCMSignalIntegrityAnalyzer`, `PCMSpectralBaselineAnalyzer`,
`PCMStereoCompatibilityAnalyzer`, and `PCMRhythmicBaselineAnalyzer`. Invalid,
non-finite, discontinuous, oversized, or incomplete input returns no evidence.

## Boundary and window semantics

Boundaries are declared from score identity in this exact marker order:

1. session start when the absolute bar is zero;
2. phrase start when the phrase-local bar is zero;
3. phrase-kind change relative to the previous bar;
4. interlock-chapter change relative to the previous bar.

Coincident markers share one record. The focus slice includes boundaries whose
current bar belongs to the focus phrase and the outgoing boundary whose previous
bar belongs to it. Catalogue order never creates adjacency.

- reference: exactly two complete bars before the boundary;
- transition: the first post-boundary bar and its sixteen exact cells;
- post horizon: the transition bar plus seven following complete bars.

Missing reference or follow-through is explicit. A shorter available trajectory
may remain visible, but it never masquerades as a complete declared window.

## Contrast and recovery facts

For each metric, the two reference values define a closed minimum/maximum
envelope and arithmetic mean. Evidence retains the transition value, signed and
absolute delta from the reference mean, and all eight post values. Recovery facts
are distinct:

- first post bar whose distance to the reference mean decreases relative to the
  immediately preceding value;
- first post bar inside the closed reference envelope;
- first post bar beginning two consecutive bars inside that envelope.

Offsets are expressed in bars, frames, and seconds. Per-metric status is exactly
one of `sustained-observed`, `not-observed-within-horizon`,
`unavailable-missing-reference`, `unavailable-missing-post`, or
`unavailable-missing-metric`. Joint sustained recovery is available only when
all nine dimensions sustain residence. A silent/inactive spatial domain has an
explicit null and is not silently removed. These are reconstructable descriptive
facts, not perceptual recovery, salience, coherence, or artistic preference.

## Local exporter and independent check

The default-off integration exporter is enabled only by
`AUTOTECHNO_RUN_SECTION_BOUNDARY_BASELINE=1`. It walks the canonical accepted
preparation path, retains the immediate accepted predecessor, focus, and one
successor, and writes ignored local float32 WAV/artifact files under:

- `docs/local/audio/section-boundary-baseline-v1/`;
- `docs/local/reports/section-boundary-baseline-v1/`.

Every entry binds corpus/case/route, root/checkpoint, engine/analyzer/snapshot/
source/head identity, accepted state/plan/replay identities for every retained
phrase, exact context/target PCM hashes, target offset, score timeline, evidence
hash, and the exact whole-mix manifest. The focus PCM must be byte-identical to
its existing accepted whole-mix manifest entry.

`scripts/section_boundary_baseline_report.py` independently reads each WAV,
reconstructs the input observations and boundary/recovery result without decoding
Swift types, checks every artifact field and hash, and writes the canonical local
summary. Its mutation tests cover marker/order/index, geometry, score identity,
PCM/artifact hashes, metric values, nulls, recovery status, and aggregation.

## Qualification boundary

Completion proves bounded deterministic offline evidence and unchanged accepted
PCM. It does not prove that a transition is good, that a return is perceptually
complete, that any genre preference is calibrated, or that app playback, device
routes, listening, and physical soak passed. Those remain separate future gates.
