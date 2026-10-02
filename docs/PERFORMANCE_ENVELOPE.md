# Auto Techno Performance Envelope

This checked report is a bounded performance observation, not a musical-quality, release-readiness, or physical-soak claim.

## Provenance

- Engine: `autotechno-canonical-engine.v48`
- Git head recorded by exporter: `53f0f3d47b0c0b4169168ea52b41b7ab2a87bdff`
- Source fingerprint: `8f5dfb0e63d50339ed0fb3a44809a7e270326aa5b7ca9db3460345dd13f49514`
- Build configuration: `release`
- Hardware: `MacBookPro18,3` / `Apple M1 Pro`
- OS: `Version 26.6.2 (Build 25G83)`
- Report fingerprint: `bdbed219f445685f33f44a0361a9feffe19acd7a7d0cf2ec9118c4d372a8a859`

## Detached preparation

All values are nanoseconds. Render/evaluate is measured by the existing phrase preparer; complete preparation is a separate replay through the canonical transport preparer. Exact PCM/evaluation identity must match between the two runs.

| Route | Cases | Trials | Horizon updates | Plan p95 | Render/evaluate p95 | Complete p95 | Worst prep/audio ratio | Minimum lookahead margin | Process high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `native-stereo-44100` | 1 | 3 | 3 | 811834 | 5398154708 | 5536190917 | 0.199918950 | 22155985954 | 243122176 |
| `native-stereo-48000` | 1 | 3 | 3 | 882667 | 5869635833 | 6050413375 | 0.218488098 | 21641774125 | 256802816 |

## Callback-shaped producer

This is an off-callback microbenchmark of the exact bounded C producer only. Queue drops/rejections are feedback-handoff facts, not device underruns.

| Frames | Trials | Operations/trial | Producer p50 ns | p95 ns | max ns | Drops | Rejections |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 128 | 9 | 128 | 34 | 36 | 36 | 0 | 0 |
| 256 | 9 | 128 | 52 | 59 | 59 | 0 | 0 |
| 512 | 9 | 128 | 91 | 93 | 93 | 0 | 0 |
| 1024 | 9 | 128 | 188 | 195 | 195 | 0 | 0 |

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
