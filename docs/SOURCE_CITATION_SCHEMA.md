# Source Citation Schema

> Generated from `docs/SOURCE_CITATION_SCHEMA.json`; do not edit by hand.

Each active roadmap plan owns one ignored local citation record. Citation
placement records provenance and permitted research use; it never grants
dependency, copying, training, or redistribution permission.

## Evidence depth

| Grade | Meaning | Permitted use |
|---|---|---|
| `A` | Equations, pseudocode, public API contracts, schematics, or inspectable source. | Hypothesis or original prototype only after the licence and component audit. |
| `B` | Detailed signal flow, topology, parameter interaction, constraints, or engineering explanation. | Falsifiable design hypothesis, not an exact implementation claim. |
| `C` | Thorough user manual or module reference with behavioural detail. | Capability and regression scenarios. |
| `D` | Product description, marketing, tutorial, or preset-level explanation. | Discovery only; corroboration required. |
| `X` | Unverified, unavailable, gated, stale, or unclear provenance. | Discovery only; do not use until reverified. |

## Licence classes

| Class | Meaning |
|---|---|
| `GREEN-ORIGINAL` | Repository-owned work or independently documented public-domain mathematics. |
| `GREEN-PERMISSIVE` | Exact MIT, BSD, ISC, zlib, or Apache component after dependency, asset, attribution, notice, and patent review. |
| `YELLOW-REVIEW` | Custom, commercial, weak-copyleft, generated, or mixed source; study only pending explicit clearance. |
| `RED-STUDY-ONLY` | Incompatible copyleft, proprietary, decompiled, leaked, uncertain, or otherwise non-incorporable source. |
| `RED-ASSET` | Preset, sample, recording, impulse response, wavetable, firmware data, model weight, factory content, or transcript corpus. |

## Record contract

Records live at `docs/local/reports/source-citations/AT-xxxx.json` and
bind their exact `AT-xxxx` plan. Every source requires URL/locator, title,
publisher, revision/date, access date, depth, licence class, permitted use,
an original summary, and an optional excerpt of at most 25 words.

Repository sources use `repo:path` and exact `sha256:<digest>` revisions;
the mutable private roadmap uses its explicit `roadmap-revision:<n>`. Web
sources use HTTPS and are not fetched by validation.

```sh
python3 scripts/source_citation_records.py check
python3 scripts/source_citation_records.py validate-record path/to/AT-xxxx.json
python3 scripts/source_citation_records.py check-active
```
