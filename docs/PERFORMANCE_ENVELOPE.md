# Auto Techno Performance Envelope

This checked report is a bounded performance observation, not a musical-quality, release-readiness, or physical-soak claim.

## Provenance

- Engine: `autotechno-canonical-engine.v48`
- Git head recorded by exporter: `c3bfeaf8b42029fb2ade0a4870210b6880e1bad5`
- Source fingerprint: `0d676fe1b9dfaf962d4fb8cea3dfa832411683ed14651d1ba874ad08ba9f58c0`
- Build configuration: `release`
- Hardware: `MacBookPro18,3` / `Apple M1 Pro`
- OS: `Version 26.6.2 (Build 25G83)`
- Report fingerprint: `3fcd65e5045757d9b7f9f8866a645b0f15a1b62932068e82087682a33e138082`

## Detached preparation

All values are nanoseconds. Render/evaluate is measured by the existing phrase preparer; complete preparation is a separate replay through the canonical transport preparer. Exact PCM/evaluation identity must match between the two runs.

| Route | Cases | Trials | Horizon updates | Plan p95 | Render/evaluate p95 | Complete p95 | Worst prep/audio ratio | Minimum lookahead margin | Process high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `native-stereo-44100` | 1 | 3 | 3 | 942166 | 6468816166 | 6340775250 | 0.228973521 | 21351401621 | 215842816 |
| `native-stereo-48000` | 1 | 3 | 3 | 814458 | 7626898167 | 7288555750 | 0.263198989 | 20403631750 | 226312192 |

## Callback-shaped producer

This is an off-callback microbenchmark of the exact bounded C producer only. Queue drops/rejections are feedback-handoff facts, not device underruns.

| Frames | Trials | Operations/trial | Producer p50 ns | p95 ns | max ns | Drops | Rejections |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 128 | 9 | 128 | 35 | 48 | 48 | 0 | 0 |
| 256 | 9 | 128 | 68 | 88 | 88 | 0 | 0 |
| 512 | 9 | 128 | 112 | 145 | 145 | 0 | 0 |
| 1024 | 9 | 128 | 194 | 247 | 247 | 0 | 0 |

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
