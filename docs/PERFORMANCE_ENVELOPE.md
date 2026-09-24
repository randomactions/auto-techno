# Auto Techno Performance Envelope

This checked report is a bounded performance observation, not a musical-quality, release-readiness, or physical-soak claim.

## Provenance

- Engine: `autotechno-canonical-engine.v48`
- Git head recorded by exporter: `2aa58736d8bc6c9247eb4dc5522209faeee434e5`
- Source fingerprint: `4a027774c4592665b40dc5852efe122c8993c137239ec68ce0a32825cf5d400b`
- Build configuration: `release`
- Hardware: `MacBookPro18,3` / `Apple M1 Pro`
- OS: `Version 26.6.2 (Build 25G83)`
- Report fingerprint: `cf2b847a54a6521c104b2931018ea215f6da4aa478818ee5dd5757ca00d3040c`

## Detached preparation

All values are nanoseconds. Render/evaluate is measured by the existing phrase preparer; complete preparation is a separate replay through the canonical transport preparer. Exact PCM/evaluation identity must match between the two runs.

| Route | Cases | Trials | Horizon updates | Plan p95 | Render/evaluate p95 | Complete p95 | Worst prep/audio ratio | Minimum lookahead margin | Process high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `native-stereo-44100` | 1 | 3 | 3 | 19011042 | 5619684375 | 5810754792 | 0.209833803 | 21881422079 | 209387520 |
| `native-stereo-48000` | 1 | 3 | 3 | 788375 | 6092011000 | 6267691250 | 0.226334277 | 21424496250 | 232603648 |

## Callback-shaped producer

This is an off-callback microbenchmark of the exact bounded C producer only. Queue drops/rejections are feedback-handoff facts, not device underruns.

| Frames | Trials | Operations/trial | Producer p50 ns | p95 ns | max ns | Drops | Rejections |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 128 | 9 | 128 | 34 | 36 | 36 | 0 | 0 |
| 256 | 9 | 128 | 53 | 65 | 65 | 0 | 0 |
| 512 | 9 | 128 | 96 | 142 | 142 | 0 | 0 |
| 1024 | 9 | 128 | 192 | 208 | 208 | 0 | 0 |

## Live macOS host evidence

Unavailable: `live-audio-system-trace-not-supplied`.

## Qualification boundary

- Status: `partial-live-evidence-unavailable`
- Reason: `offline-and-producer-observed-live-host-not-observed`
- No timing feeds score choice, rendering, evaluation, adaptation, scheduling, transport, or presentation.
- No timing or logging was added to the audio callback.
- Windows performance and long physical-output soak remain unavailable.

## Limitations

- Wall-clock timings vary and are not musical identity or adaptation input.
- Process high-water is cumulative for the isolated test process, not phase-exclusive allocation.
- The callback-shaped benchmark measures the exact producer outside a callback and is not live callback duration.
- An empty bounded trace point-of-interest set is not a long-soak no-underrun claim.
- Windows remains unavailable until measured on a native Windows host.
