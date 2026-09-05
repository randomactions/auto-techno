# Auto Techno Performance Envelope

This checked report is a bounded performance observation, not a musical-quality, release-readiness, or physical-soak claim.

## Provenance

- Engine: `autotechno-canonical-engine.v48`
- Git head recorded by exporter: `3a5818ce42853abe77041add6ae3bb6650ec04af`
- Source fingerprint: `bdfea0e3a4f5ec905ec7137fa4df6e53ad901e7fddf79c616d1b3055f5cd15c8`
- Build configuration: `release`
- Hardware: `MacBookPro18,3` / `Apple M1 Pro`
- OS: `Version 26.6.2 (Build 25G83)`
- Report fingerprint: `966d6898f565f2f69f0392012f6a37c4b745b1d86adfb150be9a30cd436a68fc`

## Detached preparation

All values are nanoseconds. Render/evaluate is measured by the existing phrase preparer; complete preparation is a separate replay through the canonical transport preparer. Exact PCM/evaluation identity must match between the two runs.

| Route | Cases | Trials | Horizon updates | Plan p95 | Render/evaluate p95 | Complete p95 | Worst prep/audio ratio | Minimum lookahead margin | Process high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `native-stereo-44100` | 1 | 3 | 3 | 892167 | 6151119375 | 6328741250 | 0.228538958 | 21363435621 | 213811200 |
| `native-stereo-48000` | 1 | 3 | 3 | 2812125 | 8497464833 | 6631181416 | 0.239460368 | 21061006084 | 225034240 |

## Callback-shaped producer

This is an off-callback microbenchmark of the exact bounded C producer only. Queue drops/rejections are feedback-handoff facts, not device underruns.

| Frames | Trials | Operations/trial | Producer p50 ns | p95 ns | max ns | Drops | Rejections |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 128 | 9 | 128 | 34 | 43 | 43 | 0 | 0 |
| 256 | 9 | 128 | 53 | 75 | 75 | 0 | 0 |
| 512 | 9 | 128 | 97 | 103 | 103 | 0 | 0 |
| 1024 | 9 | 128 | 189 | 687 | 687 | 0 | 0 |

## Live macOS host evidence

- Route: 44100 Hz, 2 channels
- Callback cycles: 861
- Callback duration p50/p95/max: 63959 / 113292 / 153709 ns
- Minimum observed device frame count: 320
- Maximum callback/budget ratio: 0.021183021
- Non-normal callback cycles: 0
- Deadline/underrun evidence: `no-relevant-point-observed-in-bounded-trace` (0 relevant points)

## Qualification boundary

- Status: `descriptive-envelope-observed`
- Reason: `bounded-observation-complete-no-capacity-rank`
- No timing feeds score choice, rendering, evaluation, adaptation, scheduling, transport, or presentation.
- No timing or logging was added to the audio callback.
- Windows performance and long physical-output soak remain unavailable.

## Limitations

- Wall-clock timings vary and are not musical identity or adaptation input.
- Process high-water is cumulative for the isolated test process, not phase-exclusive allocation.
- The callback-shaped benchmark measures the exact producer outside a callback and is not live callback duration.
- An empty bounded trace point-of-interest set is not a long-soak no-underrun claim.
- Windows remains unavailable until measured on a native Windows host.
