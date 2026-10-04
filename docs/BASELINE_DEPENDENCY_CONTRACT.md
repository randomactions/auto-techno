# Baseline dependency-contract foundation

The existing baseline lifecycle owner has fifteen evidence families. Whole PCM,
role PCM, reports, source identity and full execution authority remain separate
obligations. A change to the semantic map updates the global execution snapshot;
today every family consequently loses current metadata. This foundation records
the dependencies needed to distinguish execution revalidation, analysis, and
capture without rewriting any original evidence envelope.

`scripts/baseline_dependency_contract.py` freezes one clean committed repository
and an explicit, versioned capture context. It records all repository paths and
hashes, the original Git commit, the complete execution-snapshot fingerprint,
and separate producer and analyzer bindings for all fifteen existing families.
Analysis dependencies include the recursive local Python import closure. Dynamic
or unknown imports conservatively include all Python tooling. The compiled
producer closure includes Package.swift, package lockfiles, all Sources/resources,
and every compiled test/helper. Session and performance retain their existing
broader tooling closure. Unknown paths or uncovered changed inputs require
recapture across the complete dependency graph.

The capture context requires exact engine, build configuration, compiler, SDK,
target, compiler flags, route, private initial-state and corpus identities, plus
the Python implementation identity. Context hashes must describe the actual
producer inputs. A caller cannot substitute the current version number for
historical state or infer a route from the machine running this assessment.

Every assessment independently reads the recorded origin's Git objects and
verifies the full inventory, exact file hashes, analyzer import closure, producer
coverage, family graph and recursively derived fingerprints. Missing Git objects,
dirty captures, incomplete legacy snapshots, omitted inputs, altered files,
unsupported schemas and symlinks refuse assessment. A self-consistent rewritten
JSON fingerprint cannot replace the recorded origin. Metadata and object reads
have explicit per-file, inventory and aggregate byte limits.

## Meaning of the result

- `recapture-required`: a producer/context/upstream dependency changed, or any
  dependency is unresolved.
- `reanalysis-required`: independently recompute the affected analysis from
  retained inputs; original capture identities remain unchanged.
- `revalidation-required`: rerun applicable execution and content validators.
- `dependencies-unchanged`: the declared dependencies agree. This conveys no
  artifact currency or quality qualification.

The full global execution snapshot must still validate before capture. Map bytes
and generated snapshot version/fingerprint are kept in execution authority rather
than folded into every producer identity. Constituent normative document bytes
remain producer-bound. Revalidating a map change cannot override a changed
product, sound-quality, corpus, lifecycle, or provenance contract.

## Integration boundary

This is a dependency assessment foundation, not an installed artifact migration.
Existing specialized validators, lifecycle assessments and all nineteen Phase-1
checks retain their current source/contract and content requirements. No existing
artifact gains current authority from this metadata. Every emitted snapshot and
assessment explicitly sets artifact currency, runtime input and promotion to false.

Before narrower currency becomes available, fresh versioned producer exports must
bind their actual capture, accepted PCM/evidence, private state and toolchain to
these domains. Swift producer and independent Python validator bindings must
agree exactly. Python import indexing alone does not establish all dynamic file,
resource, environment or external-process dependencies; those require actual
producer declarations and validated input accounting before adoption. Historical
captures lacking these bindings remain historical. A cohort-wide capture-commit
constraint must still be honored wherever a downstream owner requires it.

The adoption comparison must retain the original frozen corpus and show the same
complete downstream verdicts and sample-exact PCM as full regeneration. Required
holdouts, rejection rules, deterministic replay, memory/deadline and promotion
checks remain required. The other roadmap chat owns live musical producers and
qualification; integration belongs at a coordinated stable producer boundary.

## Use and verification

Supply a local JSON object containing every context field listed by
`CONTEXT_KEYS`; obtain values from the actual producer invocation. Do not fill
missing values with defaults. Freeze only a clean committed tree:

```sh
python3 scripts/baseline_dependency_contract.py capture --context docs/local/capture-context.json --output docs/local/reports/dependency-original.json
python3 scripts/baseline_dependency_contract.py assess --context docs/local/capture-context.json --baseline docs/local/reports/dependency-original.json --output docs/local/reports/dependency-current-assessment.json
python3 -m unittest scripts/test_baseline_dependency_contract.py
```

Outputs remain local, refuse overwrite, and contain no PCM or private state.
Integrity controls cover map-only execution drift, source/test/resource/package
changes, added/deleted inputs, shared and family-specific analysis, route/private
state/toolchain/Python changes, unknown and dynamic imports, stale contracts,
unsafe paths, incomplete/resealed/promotional snapshots and independent origin
verification. These controls validate assessment behavior; full artifact currency
and qualification remain unproved until producer integration is complete.
