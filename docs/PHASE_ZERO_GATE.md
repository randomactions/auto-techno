# Phase-0 Coherence Gate

> Generated from current subordinate authorities by `scripts/phase_zero_gate.py`; do not edit by hand.

Status: **passed**

Phase 0 structural governance and provenance only; no app, route, listening, or physical-output qualification claim.

## Authority summary

| Authority | Schema/version | Surfaces | Unresolved | Artifact SHA-256 |
|---|---|---:|---:|---|
| `parameter-reachability` | `autotechno-parameter-reachability-audit.v1` v2 | 543 | 0 | `838fd0736e83579a43473dcaf63ff5c94d47785cc509ba95fcf79dbdcdaac238` |
| `authority-convergence` | `autotechno-authority-surface-inventory.v1` v2 | 46 | 0 | `326742d7d5605ba1495a0673352e7786312f02a0077d1de0d0dc4e3056285554` |
| `component-provenance` | `autotechno-component-license-asset-manifest.v1` v4 | 11 | 0 | `d17957f858401aeb31e425237d2dc23a2c0bec53bab5578d04da8cb0d0d65a30` |
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
