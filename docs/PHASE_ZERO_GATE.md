# Phase-0 Coherence Gate

> Generated from current subordinate authorities by `scripts/phase_zero_gate.py`; do not edit by hand.

Status: **passed**

Phase 0 structural governance and provenance only; no app, route, listening, or physical-output qualification claim.

## Authority summary

| Authority | Schema/version | Surfaces | Unresolved | Artifact SHA-256 |
|---|---|---:|---:|---|
| `parameter-reachability` | `autotechno-parameter-reachability-audit.v1` v2 | 543 | 0 | `838fd0736e83579a43473dcaf63ff5c94d47785cc509ba95fcf79dbdcdaac238` |
| `authority-convergence` | `autotechno-authority-surface-inventory.v1` v1 | 44 | 0 | `53a4a70fc6737d19c8c19d2c1564e2e8274a5fb2883416fd22a00edd22d494d1` |
| `component-provenance` | `autotechno-component-license-asset-manifest.v1` v1 | 9 | 0 | `3b654a59fe6076afc372263b8ba05fb55756eef11272e72b5b301bf5134c3618` |
| `roadmap-integrity` | `autotechno-evolution.v1` v1 | 390 | 0 | `local-revision-bound-by-active-citation` |

## Subordinate checks

| Check | Command | Status |
|---|---|---|
| `contract-baseline` | `python3 scripts/roadmap_contract_baseline.py check` | `passed` |
| `parameter-reachability` | `python3 scripts/parameter_reachability_audit.py check` | `passed` |
| `authority-inventory` | `python3 scripts/authority_surface_inventory.py check` | `passed` |
| `component-provenance` | `python3 scripts/component_license_asset_manifest.py check` | `passed` |
| `roadmap-integrity` | `python3 scripts/roadmap_integrity.py check` | `passed` |
| `result-vocabulary` | `python3 scripts/result_status_vocabulary.py check` | `passed` |
| `source-citation-schema` | `python3 scripts/source_citation_records.py check` | `passed` |
| `active-source-citations` | `python3 scripts/source_citation_records.py check-active` | `passed` |
| `negative-result-schema` | `python3 scripts/negative_result_records.py check` | `passed` |
| `local-artifact-layout` | `python3 scripts/local_artifact_doctor.py check` | `passed` |

## Unresolved counts

- `unownedActiveParameters`: 0
- `unresolvedDuplicateAuthorities`: 0
- `invalidRoadmapInvariants`: 0
- `unresolvedComponentFindings`: 0
