# Phase-0 Coherence Gate

> Generated from current subordinate authorities by `scripts/phase_zero_gate.py`; do not edit by hand.

Status: **passed**

Phase 0 structural governance and provenance only; no app, route, listening, or physical-output qualification claim.

## Authority summary

| Authority | Schema/version | Surfaces | Unresolved | Artifact SHA-256 |
|---|---|---:|---:|---|
| `parameter-reachability` | `autotechno-parameter-reachability-audit.v1` v2 | 543 | 0 | `838fd0736e83579a43473dcaf63ff5c94d47785cc509ba95fcf79dbdcdaac238` |
| `authority-convergence` | `autotechno-authority-surface-inventory.v1` v1 | 44 | 0 | `7a4be307fe204395f9c693a57e9c3f95bf8c5e17522edd54e2d206fd5d73756b` |
| `component-provenance` | `autotechno-component-license-asset-manifest.v1` v1 | 9 | 0 | `30b2ff92b9c8bbb41371f8199a4a65dc3241a014bb6696b60f81b457c07f9f14` |
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
