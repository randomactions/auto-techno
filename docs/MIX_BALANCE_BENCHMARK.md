# Deterministic mix-balance benchmark

The engine-v36 measurements below remain historical benchmark evidence. Current
engine v38 has complete primary-v19 and long-horizon-v6 qualification artifacts.

Auto Techno uses two complementary measurement families. Whole-program
loudness, true peak, loudness range, and momentary/short-term behavior follow
[ITU-R BS.1770-5](https://www.itu.int/rec/R-REC-BS.1770-5-202311-I) and the
[EBU loudness workflow](https://tech.ebu.ch/loudness/). Those measurements
protect output level and dynamics; they do not define a universal musical
balance between kick, bass, percussion, tonal material, and atmosphere.

Role balance is therefore measured from the renderer's existing post-fader dry
stems. Every rendered bar records active RMS, onset RMS, peak, crest factor,
occupancy, and five broad energy bands for `kick`, `foundation`, `percussion`,
`upperTonal`, and `atmosphere`. The benchmark compares like-for-like exact
engine journeys at both supported rates. No microphone, reference recording,
DAW, plug-in, UI state, or callback analysis participates.

Run the machine-readable benchmark over a complete calibration cache:

```sh
scripts/analyze_mix_balance_cache.sh /path/to/calibration-cache
```

The JSON output identifies the engine and quality schema, reports distributions
for all five roles, and includes a ten-pair active-level relation matrix for
bars where both roles clear the renderer's presence gates. It separately
evaluates the authored kick/foundation controller. A positive
`residualKickExcessDB` means the post-fader kick remains above the
companion-specific target after automatic correction.

## Engine-v35 deficit and bounded v36 correction

The exact 28-journey development plus four-journey holdout bank contained 4,078
eligible kick/foundation measurements. Under the former `-3 dB` lower bound:

- 3,408 measurements reached the attenuation limit;
- 3,401 of those remained more than the `0.35 dB` deadband above target;
- median residual kick excess was `4.02 dB`, with a `3.96 dB` mean;
- the fifth percentile of required correction was `-10.02 dB`.

This is a repeatable controller-capacity deficit, consistent with the listening
observation that the kick has been too loud. The in-place v2 correction keeps
the existing companion targets and attenuation-only behavior, starts at
`-2 dB`, moves by at most `0.35 dB` per prepared bar, and extends the lower bound
to `-8 dB`. That lower bound covers `74.69%` of measured demand, versus the old
`-3 dB` limit that left virtually every saturated measurement unresolved. It
also prevents small sample-rate measurement drift from pushing very quiet
transient-presence decisions onto opposite sides of a deep attenuation floor.
The finite bound does not let a very quiet foundation drive unbounded
attenuation or force the initial state to the corpus median before a bar has
been measured. Breakdowns, empty companions, and inaudible foundations still
hold the prior continuation state.

This change does not add automatic faders for the other four roles. Their
measurements are retained by the benchmark so future level changes can start
from a repeatable multi-role deficit rather than a one-off knob choice.

The unchanged 28-development/four-holdout bank accepted engine v36 at both
44.1 and 48 kHz. Across the same 4,078 eligible controller measurements:

- median residual kick excess fell from `+4.02 dB` to `+0.13 dB`;
- mean residual kick excess fell from `+3.96 dB` to `+0.81 dB`;
- minimum-bound observations fell from 3,408 at `-3 dB` to 405 at `-8 dB`;
- unresolved minimum-bound observations fell from 3,401 to 271;
- the median active kick/foundation stem relation fell from `+21.13 dB` to
  `+16.88 dB`, close to the authored `+16.5 dB` bass-companion target.

All 56 disjoint holdout checkpoints passed, with no trajectory relationship
failure. The adversarial suite also passed. These are offline qualification
results, not listening approval or a claim that every bar should have the same
role balance.

The mix-controller result remains installed in canonical engine v38 / quality
schema 39. Its current primary-v19 profile, adversarial-suite, and holdout
fingerprints are recorded by the exact artifact loader.
Long-horizon identities are pinned separately because later renderer changes
can require regeneration without changing this measured controller deficit.

Controlled listening remains a separate validation stage. EBU Tech 3343
recommends a consistent reference monitoring level and also notes that
objective loudness measurements cannot fully settle listener preference; the
benchmark establishes reproducibility and bounds, not a claim that the mix is
subjectively finished.
