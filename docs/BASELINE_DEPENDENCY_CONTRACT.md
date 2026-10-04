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

## Fresh operation binding

`scripts/baseline_capture_transaction.py` supplies the driver-owned transaction
primitive. The snapshot is now version2 because its producer closure must also
bind the transaction implementation. Version1 foundation snapshots require a
fresh freeze; no metadata-only upgrade is registered.

The driver supplies the actual producer and independent validator actions and
their exact argument vectors, environment fingerprints and compiled-input
fingerprints. The transaction requires a clean committed freeze, every exact
transitive upstream binding at that same source/context, and absent output paths
before invoking the producer. It refuses existing outputs instead of backfilling
metadata. The canonical family manifest and every declared whole/role WAV must
be covered by exact streaming file hashes. Source and output bytes are checked
after independent validation, and upstream captures are rechecked before return.
Failed operations retain their outputs without yielding a successful binding.
Historical artifact fields are never modified.

Reading a binding checks its original source objects/ancestry, immutable output
bytes, schema/coverage and full referenced upstream graph. Git object replacement
is disabled. Every context, snapshot and output retains its original identity.
A changed ancestor, missing WAV, resealed omission or altered parent refuses.

The library does not authenticate arbitrary callbacks or a claimed invocation
fingerprint. The adopting driver must prove those actions are the real registered
producer/checker commands and that process environment, compiled/loaded inputs,
private initial state and route match the recorded invocation. Independent family
validators must then validate the actual typed content and accepted PCM before
any scoped currency claim. A callback returning zero and metadata hashes alone
are insufficient. The transaction remains a non-authoritative foundation until
that coordinated integration and complete native parity comparison pass.

```sh
python3 -m unittest scripts/test_baseline_dependency_contract.py scripts/test_baseline_capture_transaction.py
```

The transaction controls use explicit synthetic producers to test ordering,
no-overwrite, failure retention, exact file coverage, committed and dirty source
changes, validator tampering, missing/altered parents and full dependency graph
bindings. They do not establish native capture or musical qualification.


The opt-in Swift whole/role exporters now observe actual initial session, render
and graph fingerprints, exact route/seed coverage, loaded test-image bytes,
process environment, and final typed manifest. Existing exporter schemas and
PCM behavior remain unchanged. Witness controls reject pre-existing output
directories, changed source/corpus/image, incomplete initialization coverage,
and existing receipt files. Receipt writes use exclusive creation; partial failed
receipts confer no authority.

`scripts/baseline_producer_witness.py` executes a new build in absent scratch
storage and a fresh native initialization probe. It binds actual build arguments,
compiler, SDK settings, target, capture corpus, routes, initialization ledger and
loaded image. Dependency snapshot v3 adds capture corpus path/hash, image hash
and environment fingerprint. Previous scope snapshots require a fresh freeze;
there is no relabel or upgrade path. Non-ASCII canonical input and unknown native
image layouts currently fail closed. The driver retains environment hashes only.

The probe does not render audio. Independent witness metadata controls and an
initialization probe are not whole/role capture parity, lifecycle currency,
capacity qualification, musical qualification or runtime promotion. Adoption in
existing family validators and complete native PCM/verdict comparison remain
required before dependency-scoped currency is enabled.
