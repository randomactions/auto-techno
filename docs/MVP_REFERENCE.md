# MVP reference freeze

This is the fixed comparison baseline for v2 development. It is deliberately
not a quality target: it exists so that every DSP change can be compared at
the same seed, intent, BPM, sample rate, and treatment.

Configuration: seeds `42`, `48291`, `90909`; BPM `130`; drive `0.65`;
darkness `0.78`; hypnosis `0.74`; sample rate `44,100 Hz`; treatment
`polished`; one rendered bar; stereo output.

| Seed | Treatment | Peak | True peak | RMS | Crest | Stereo correlation | Deterministic hash |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 42 | polished | 0.5228103 | 0.5228103 | 0.079332106 | 6.5901475 | 0.99917144 | `6307ca4e7e7b91ee` |
| 42 | sketch | 0.49969336 | 0.49969336 | 0.07996924 | 6.2485695 | 1.0 | `d4e44efbc78dc55d` |
| 48291 | polished | 0.47511014 | 0.47511014 | 0.06815523 | 6.9710007 | 0.99912316 | `7284f39871e9f80d` |
| 48291 | sketch | 0.48809773 | 0.48809773 | 0.068374164 | 7.138628 | 1.0 | `c16ebb32e678cea1` |
| 90909 | polished | 0.46662635 | 0.46743155 | 0.06833036 | 6.828975 | 0.999212 | `d753b7042fb24db8` |
| 90909 | sketch | 0.4869039 | 0.4869039 | 0.06852905 | 7.1050735 | 1.0 | `6feb508732266d81` |

## Status

- Done: deterministic metrics and fixed-seed hashes.
- Done: finite-sample, peak, crest, stereo, and boundary tests.
- Not done: committed WAV reference renders. The current repository keeps the
  baseline compact; renders can be regenerated from the same configuration.
- Done: 4× cubic-interpolated true-peak estimate is recorded alongside sample
  peak.
- Not done: polished/sketch side-by-side artifacts. The development A/B
  treatment remains available while v2 is being evaluated.

Regenerate and verify with:

```sh
swift run AutoTechnoReference
swift test --filter MVPReferenceTests
```

The command writes the six stereo PCM16 one-bar MVP renders and six full
32-bar v2 renders to `docs/reference/`.
