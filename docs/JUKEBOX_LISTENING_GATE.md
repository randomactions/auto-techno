# Continuous jukebox listening gate

Status: **Objective checks passed for four- and eight-scene artifacts; subjective listening pending**

## Reference artifact

Generate the fixed reference with:

```sh
swift run AutoTechnoReference
```

Listen to [jukebox_seed48291_cycle0_4scenes.wav](reference/jukebox_seed48291_cycle0_4scenes.wav).
It contains four deterministic 32-bar scenes using the approved v2 Club Punch
profile. The accompanying [jukebox_translation_report.json](reference/jukebox_translation_report.json)
records the objective checks.

For the long-play gate, listen to
[jukebox_seed48291_cycle0_8scenes.wav](reference/jukebox_seed48291_cycle0_8scenes.wav).
It contains eight consecutive scenes (256 bars). The accompanying
[jukebox_long_play_translation_report.json](reference/jukebox_long_play_translation_report.json)
passes the same finite-output, true-peak, low-band stereo, and boundary checks.

## Listening procedure

1. Listen without manually changing controls for the full eight-scene render
   if time permits; the four-scene render is the shorter diagnostic pass.
2. Note the boundaries between scenes 1→2 through 7→8, especially the first
   scene after the breakdown and the cycle return in the app.
3. Check whether groove identity survives while texture, motif, and energy evolve.
4. Check for arbitrary resets, pile-ups, or loss of kick/bass authority.
5. Repeat with the app’s **CONTINUOUS** control enabled and listen for at least
   one additional cycle.

## Verdict table

| Transition/session | Continuity | Identity retained | Worth continuing | Concrete observation |
| --- | --- | --- | --- | --- |
| Scene 1 → 2 | pending | pending | pending | pending |
| Scene 2 → 3 | pending | pending | pending | pending |
| Scene 3 → 4 | pending | pending | pending | pending |
| Scene 4 → 5 | pending | pending | pending | pending |
| Scene 5 → 6 | pending | pending | pending | pending |
| Scene 6 → 7 | pending | pending | pending | pending |
| Scene 7 → 8 | pending | pending | pending | pending |
| Additional cycle | pending | pending | pending | pending |

Approval requires coherent, intentional evolution that remains worth leaving
on without manual loop hunting. Objective checks are necessary but do not
replace this verdict.
