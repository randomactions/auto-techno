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

The registered `scripts/baseline_producer_capture_driver.py` operates only on
absent canonical whole/role output directories in its isolated checkout. It
executes real native producer subprocesses with an exact actual-image witness,
then the original standalone cold family validators, and records fresh upstream
transaction bindings. It separately renders witness-disabled reference banks in
a fresh namespace, runs the same cold validators, and compares every WAV byte
and typed state/replay/route/reconstruction fact. Only namespace paths and their
independently checked manifest-reference hashes are normalized. Foundation
behavior coverage and all frozen inputs are checked again before a receipt.
The driver and all three supporting modules are conservative producer inputs.

Release builds explicitly enable testable imports; native initialization probes
do not by themselves prove the Release build or capture. Driver diagnostics stay
in the isolated local scratch/output trees. Failure retains outputs and never
produces a successful validation receipt. This driver still establishes no
scoped lifecycle, aggregate, capacity or musical qualification authority.

Identity bytes use exact lexical key order, not locale-, case-insensitive or
numeric-aware JSON collation. The Swift producer identity uses a typed
JSONEncoder record with sorted keys, independently matched to Python canonical
bytes. A fixed mixed-case/numeric-suffix golden hash detects Foundation
JSONSerialization sorted-key drift. Informational witness/probe JSON may use
Foundation ordering; it is hashed as actual file bytes and parsed independently,
never substituted for the canonical producer identity.

## Independent completed-capture reading

`scripts/baseline_capture_scope.py` independently reads a completed registered
whole/role capture-and-parity operation. It verifies the original source objects,
build, probe, loaded image, private initialization, declarations, fresh complete
upstream bindings, successful registered native and cold commands, diagnostic
bytes, reference output coverage and exact WAV/typed/foundation parity again.
An active job, incomplete receipt, changed output or promotional flag refuses.
The returned source fingerprint is reconstructed from the original Git bytes,
including the original execution snapshot; neither artifacts nor provenance are
rewritten to the current source.

This reader is a prerequisite for later validator adoption. It does not establish
current dependency scope, skip content checks, change the lifecycle or aggregate
gates, or authorize currency, qualification or promotion. All fifteen lifecycle
families retain their existing rules until coordinated integration is validated.

```sh
python3 -m unittest discover -s scripts -p test_baseline_capture_scope.py
```

## Isolated retained whole/role validator integration

The whole/role validators can explicitly select a completed registered capture
with `AUTOTECHNO_BASELINE_CAPTURE_PROOF`. There is no implicit search or fallback
from a rejected proof. The original canonical namespace and corpus are required.
The retained adapter independently verifies completed native parity, derives the
original broad source identity from original Git bytes, assesses current exact
producer dependencies, and runs a new registered initialization probe against the
unchanged actual image. Compiler, SDK, target, private initialization, corpus and
semantic producer environment must match the original declared context. Missing,
unknown, changed or unavailable producer inputs require a new capture. The actual
probe file must equal the embedded probe, including after receipt resealing.

Accepted original envelopes remain unchanged. Every whole/role content, geometry,
route, replay, WAV hash, accepted PCM and reconstruction check still executes.
The fresh capture driver rejects an inherited retained-proof selector. Other
lifecycle families keep their existing provenance and cohort guards; this adapter
does not grant them whole/role authority. All fifteen families, nineteen
subordinate checks, both aggregate passes, holdouts, rejection and promotion
gates remain required. Coordinated downstream lifecycle/cohort/aggregate adoption
and map-only-versus-regeneration parity are still required before programme-wide
scoped currency can be claimed.

## Scoped lifecycle and aggregate consumer integration

Lifecycle assessment v2 and Phase-1 report v2 record original artifact envelopes
unchanged and keep registered whole/role current verification separate. Each
verification binds original Git/source/execution and completed native parity
receipt to current Git/snapshot/capture-context/source-freeze identities and a
fresh actual native probe, diagnostic and registered/actual invocation receipts.
Whole/role verification must share exactly the same original and current context.
An explicit rejected selector cannot fall back; unsupported families retain their
existing current-contract/source/content requirements.

All fifteen lifecycle families and nineteen ordered subordinate checks remain
mandatory. The aggregate rechecks current source and the actual probe, diagnostic,
loaded image and invocation bytes after cold checks. Generate and check each
execute fresh probes. Only their three event-receipt fields (probe path, file hash
and native diagnostic hash) and derived fingerprints may differ after independent
verification. Every semantic identity, original envelope and verdict remains exact;
check never rewrites saved artifacts or metadata.

This changes conservative COMMON inputs and requires a new clean original capture;
prior proof cannot be retagged. Legacy report schemas are not upgraded in place.
Native/component parity is not programme-wide adoption: actual shared-cohort and
complete fifteen-family/nineteen-check/two-aggregate parity against regeneration
remain required at the coordinated current engine boundary. Holdouts, rejection,
replay, routes, resources, memory/deadline and promotion gates remain unchanged.
