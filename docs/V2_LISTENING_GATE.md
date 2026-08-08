# v2 listening gate

Status: **Approved — v2 is the preferred engine**

This gate approved v2 as the default engine on 2026-07-13. The MVP remains a
reference path and remains selectable under **Under the Hood**.

## Fixed comparison set

Use the same semantic intent, BPM `130`, and sample rate for both engines:

- seed `42` — transient and low-end authority;
- seed `48291` — learned dark/hypnotic center;
- seed `90909` — variation and stereo behavior.

Compare at matched perceived loudness. Do not decide from peak level alone.
Offline files are available in `docs/reference/` after running
`swift run AutoTechnoReference`; names beginning with `v2_` contain the full
32-bar procedural renders. `v2_manifest.json` records their objective metrics
and hashes. Files ending in `_matched_to_mvp.wav` are the recommended
loudness-matched listening pair.

## Listening procedure

1. Stop playback and reset the scene.
2. Under **Under the Hood → Listening Seeds**, choose `42`, `48291`, or `90909`.
3. Listen to the MVP reference for at least 32 bars.
4. Toggle **Procedural Engine** and listen to the same seed for at least 32 bars.
5. Match loudness before judging tone or preference.
6. Check the groove, kick/bass relationship, section contrast, stereo motion,
   texture depth, and whether the return feels earned.
7. Repeat for all three seeds and record one concrete observation per seed.

## Objective checks

The automated suite covers:

- deterministic 32-bar output;
- finite samples and bounded peak/true peak;
- DC offset;
- full-band and low-band stereo correlation;
- inter-bar boundary continuity;
- deterministic sample hashes;
- reset reproducibility;
- polished/sketch treatment distinction.

Run the focused checks with:

```sh
swift test --filter V2ProceduralEngineTests
swift test --filter MVPReferenceTests
```

## Verdict

Record the result here after listening; do not mark v2 approved from automated
metrics alone.

| Seed | Groove authority | 32-bar form | Texture/depth | MVP or v2 | Concrete observation |
| ---: | --- | --- | --- | --- | --- |
| 42 | pending | pending | pending | v2 | v2 is clearly preferred overall; this seed feels more deconstructed. |
| 48291 | pending | pending | v2 | v2 is preferred overall; detailed seed-specific notes remain optional follow-up. |
| 90909 | pending | pending | pending | v2 | v2 is one of the preferred seeds; detailed notes still pending. |

Approval recorded on 2026-07-13: the listener clearly preferred v2 for its
less-generic identity and fatter sound. Seed `42` was described as more
deconstructed and seed `90909` was a favorite. The remaining table fields are
useful refinement notes, not a blocker to v2 becoming the default.
