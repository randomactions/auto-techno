# Auto Techno Performance Envelope

This checked report is a bounded performance observation, not a musical-quality, release-readiness, or physical-soak claim.

## Provenance

- Engine: `autotechno-canonical-engine.v48`
- Git head recorded by exporter: `4a433253af75b8bab39ffa60c739597b6f7a6666`
- Source fingerprint: `64d15dea5c3e9f9425b45ce6cc832c34dfe63aa1bfb5ab1be9ce27b5741b9b62`
- Build configuration: `release`
- Hardware: `MacBookPro18,3` / `Apple M1 Pro`
- OS: `Version 26.6.2 (Build 25G83)`
- Report fingerprint: `f58923a9e658a58d0432f53c13d83f6d030f855536b4ff4586ee95f50f6a07af`

## Detached preparation

All values are nanoseconds. Render/evaluate is measured by the existing phrase preparer; complete preparation is a separate replay through the canonical transport preparer. Exact PCM/evaluation identity must match between the two runs.

| Route | Cases | Trials | Horizon updates | Plan p95 | Render/evaluate p95 | Complete p95 | Worst prep/audio ratio | Minimum lookahead margin | Process high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `native-stereo-44100` | 1 | 3 | 3 | 819583 | 5441058875 | 5587079000 | 0.201756584 | 22105097871 | 244301824 |
| `native-stereo-48000` | 1 | 3 | 3 | 850375 | 5905113084 | 5957115416 | 0.215118990 | 21735072084 | 262258688 |

## Callback-shaped producer

This is an off-callback microbenchmark of the exact bounded C producer only. Queue drops/rejections are feedback-handoff facts, not device underruns.

| Frames | Trials | Operations/trial | Producer p50 ns | p95 ns | max ns | Drops | Rejections |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 128 | 9 | 128 | 34 | 43 | 43 | 0 | 0 |
| 256 | 9 | 128 | 55 | 78 | 78 | 0 | 0 |
| 512 | 9 | 128 | 103 | 109 | 109 | 0 | 0 |
| 1024 | 9 | 128 | 190 | 325 | 325 | 0 | 0 |

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
