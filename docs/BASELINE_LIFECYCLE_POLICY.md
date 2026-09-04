# Baseline lifecycle and schema-migration policy

This generated policy defines the offline Phase-1 evidence regeneration
graph. It does not validate audio by itself, authorize quality promotion,
or replace any family-specific checker or exact PCM comparison.

- Policy schema: `autotechno-baseline-lifecycle-policy.v1`
- Policy fingerprint: `5adf87179c53df3bc1eb59bbec7a70e81a5dd01e65f81bbc55a0cc2c92d89606`
- Artifact families: 15
- Registered schema migrations: 0
- Raw artifacts tracked: no
- Runtime or promotion input: no

## Lifecycle states

| State | Meaning |
|---|---|
| `current-metadata` | Schema, contract, corpus, and dependency metadata are current; the named family validator must still pass. |
| `comparable` | Same schema and immutable context; every allowed identity difference remains explicit. |
| `migration-required` | A registered lossless transition must run and pass its post-validator before comparison. |
| `regeneration-required` | Current authority differs; regenerate rather than editing provenance. |
| `incompatible` | No direct comparison is allowed; create a new baseline or registered transition. |
| `unavailable` | Required local evidence is missing or unreadable. |
| `blocked-by-dependency` | A prerequisite is not current. |

## Deterministic regeneration order

| # | Family | Artifact | Dependencies | Validator |
|---:|---|---|---|---|
| 1 | `long-horizon-session` | `docs/local/reports/long-horizon-session-baseline-v1/report.json` | none | `python3 scripts/session_trajectory_baseline_report.py --check` |
| 2 | `whole-mix-render` | `docs/local/reports/baseline-corpus-v1/manifest.json` | none | `python3 scripts/baseline_render_manifest.py check` |
| 3 | `pcm-comparison-whole` | `docs/local/reports/pcm-comparisons-v1/whole-mix-self.json` | `whole-mix-render` | `python3 scripts/pcm_comparison_report.py check --report <report>` |
| 4 | `performance-envelope` | `docs/local/reports/performance-envelope-v1/report.json` | `whole-mix-render` | `python3 scripts/performance_envelope_report.py check <trace-arguments>` |
| 5 | `rhythmic-baseline` | `docs/local/reports/rhythmic-baseline-v1/manifest.json` | `whole-mix-render` | `python3 scripts/rhythmic_baseline_report.py check` |
| 6 | `role-stem-capture` | `docs/local/reports/baseline-stems-v1/manifest.json` | `whole-mix-render` | `python3 scripts/stem_capture_manifest.py check` |
| 7 | `score-motif` | `docs/local/reports/score-motif-baseline-v1/manifest.json` | `whole-mix-render` | `python3 scripts/score_motif_baseline_report.py check` |
| 8 | `section-boundary` | `docs/local/reports/section-boundary-baseline-v1/report.json` | `whole-mix-render` | `python3 scripts/section_boundary_baseline_report.py check` |
| 9 | `kick-foundation-collision` | `docs/local/reports/kick-foundation-collision-v1/manifest.json` | `whole-mix-render`, `role-stem-capture` | `python3 scripts/kick_foundation_collision_report.py check` |
| 10 | `pcm-comparison-role` | `docs/local/reports/pcm-comparisons-v1/role-stems-self.json` | `role-stem-capture` | `python3 scripts/pcm_comparison_report.py check --report <report>` |
| 11 | `signal-baseline` | `docs/local/reports/signal-baseline-v1/manifest.json` | `whole-mix-render`, `role-stem-capture` | `python3 scripts/signal_baseline_report.py check` |
| 12 | `spectral-baseline` | `docs/local/reports/spectral-baseline-v1/manifest.json` | `whole-mix-render`, `role-stem-capture` | `python3 scripts/spectral_baseline_report.py check` |
| 13 | `stereo-compatibility` | `docs/local/reports/stereo-compatibility-baseline-v1/manifest.json` | `whole-mix-render`, `role-stem-capture` | `python3 scripts/stereo_compatibility_baseline_report.py check` |
| 14 | `transient-envelope` | `docs/local/reports/transient-envelope-baseline-v1/manifest.json` | `whole-mix-render`, `role-stem-capture` | `python3 scripts/transient_envelope_baseline_report.py check` |
| 15 | `deficit-register` | `docs/DEFICIT_REGISTER.json` | `kick-foundation-collision`, `long-horizon-session`, `performance-envelope`, `rhythmic-baseline`, `score-motif`, `section-boundary`, `signal-baseline`, `spectral-baseline` | `python3 scripts/deficit_register.py check` |

## Comparison and migration rules

Direct comparison requires the same family, artifact schema/version, corpus,
engine, build configuration, and route identity. Artifact, contract, and source
fingerprint differences are retained as explicit differences. A schema change
is never inferred compatible from its name: it requires an exact registered
source/target rule, deterministic transformer, and post-validator. Breaking or
unknown transitions are incompatible and require a new baseline.

Metadata equivalence never substitutes for the streaming sample comparator.
Cross-configuration results remain separate and cannot weaken exact gates.

## Commands

```sh
python3 scripts/baseline_lifecycle_policy.py generate
python3 scripts/baseline_lifecycle_policy.py validate
python3 scripts/baseline_lifecycle_policy.py order
python3 scripts/baseline_lifecycle_policy.py assess --output docs/local/reports/baseline-lifecycle-v1/assessment.json
```

`assess` checks bounded metadata and transitive currency only. Every listed
family validator must pass before an artifact is called current.
