# Phase-0 Coherence Gate

> Generated from current subordinate authorities by `scripts/phase_zero_gate.py`; do not edit by hand.

Status: **passed**

Phase 0 structural governance and provenance only; no app, route, listening, or physical-output qualification claim.

## Authority summary

| Authority | Schema/version | Surfaces | Unresolved | Artifact SHA-256 |
|---|---|---:|---:|---|
| `parameter-reachability` | `autotechno-parameter-reachability-audit.v1` v3 | 544 | 0 | `7fbf6d9971f2cb62901e8c0503f39a6939415c785bd64fbdfbd578f44410f73f` |
| `authority-convergence` | `autotechno-authority-surface-inventory.v1` v3 | 46 | 0 | `b649918adfe9934f0a523d74bfbf33601a67097441bd546b475f4ece2fbc1f1f` |
| `component-provenance` | `autotechno-component-license-asset-manifest.v1` v5 | 11 | 0 | `54157534f2aa988cb8bd581ed638653ff18a41b8151472c8a3e0d42d138fa1bd` |
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
