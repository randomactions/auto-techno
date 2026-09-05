# Auto Techno Performance Envelope

This checked report is a bounded performance observation, not a musical-quality, release-readiness, or physical-soak claim.

## Provenance

- Engine: `autotechno-canonical-engine.v48`
- Git head recorded by exporter: `ac768b64fe1807d58ab794ea416d47396ab64844`
- Source fingerprint: `5be218a1dc64ef1645ef20f5a1f0d09af9349ca2ef3f4742fc95affc687cdfb1`
- Build configuration: `release`
- Hardware: `MacBookPro18,3` / `Apple M1 Pro`
- OS: `Version 26.6.2 (Build 25G83)`
- Report fingerprint: `6f8ccfab04cf5b0906a7374a330ff800e3f08c5e319e2ef8a0e0826fcf3b5872`

## Detached preparation

All values are nanoseconds. Render/evaluate is measured by the existing phrase preparer; complete preparation is a separate replay through the canonical transport preparer. Exact PCM/evaluation identity must match between the two runs.

| Route | Cases | Trials | Horizon updates | Plan p95 | Render/evaluate p95 | Complete p95 | Worst prep/audio ratio | Minimum lookahead margin | Process high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `native-stereo-44100` | 1 | 3 | 3 | 777166 | 5450638583 | 5514457125 | 0.199134115 | 22177719746 | 215564288 |
| `native-stereo-48000` | 1 | 3 | 3 | 777542 | 5911637792 | 6062063500 | 0.218908799 | 21630124000 | 229588992 |

## Callback-shaped producer

This is an off-callback microbenchmark of the exact bounded C producer only. Queue drops/rejections are feedback-handoff facts, not device underruns.

| Frames | Trials | Operations/trial | Producer p50 ns | p95 ns | max ns | Drops | Rejections |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 128 | 9 | 128 | 62 | 186 | 186 | 0 | 0 |
| 256 | 9 | 128 | 51 | 71 | 71 | 0 | 0 |
| 512 | 9 | 128 | 90 | 95 | 95 | 0 | 0 |
| 1024 | 9 | 128 | 180 | 182 | 182 | 0 | 0 |

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
