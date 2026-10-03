# Process-local baseline validation reuse

The existing independent Python stereo analyzer remains the authority for stereo
report verification. An opt-in `StereoAnalysisSession` retains only results it
computes itself, in memory, during one serial frozen validation driver. It never
loads a cache, receipt or prior exit status from disk. Standalone `generate` and
`check` commands retain cold independent recomputation.

Every invocation still checks the report schema, policy, corpus, contract,
manifest bytes, asset coverage and provenance; scans the live WAVs; checks the
exact PCM read for analysis against the manifest's PCM hash; and compares every
reported metric, segment, null, state and fingerprint. Reuse is keyed by exact
channel bytes, rate, segment geometry, the frozen report/input context and the
Python interpreter and implementation bytes. A changed context or implementation
refuses the session, including a module changed after import but before session
construction. A changed report's claimed evidence cannot replace cached
expected values. Identical PCM may share arithmetic, while each asset retains its
own full provenance validation and evidence comparison.

The cache retains at most 256 results and 128 MiB of recursively measured Python
objects. If either bound is reached, that input is recomputed. No raw PCM is
retained between calls, and cache results returned to callers are copies.
All state disappears with the driver process. This is detached offline tooling;
no score, renderer, runtime profile, callback, scheduling or promotion rule changes.

## Adoption in an existing refresh driver

Keep the existing source/input freeze, stage ordering, environment, logs,
failure handling and publication guards. Create one runner before the stages:

```python
import sys
sys.path.insert(0, str(ROOT / "scripts"))
from baseline_validation_session import ValidationSessionRunner
validation_runner = ValidationSessionRunner(ROOT)
```

Replace only the driver's subprocess call:

```python
result = validation_runner(
    argv, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT
)
```

The adapter recognizes only default `generate`/`check` invocations of the current
Python stereo report and Phase-1 gate scripts, with the same interpreter and
root. It invokes both aggregate passes and all 19 subordinate checks in their
original order. Stereo checks use the same live session; other checks keep their
normal subprocesses and inherit the driver environment exactly. Custom arguments, interpreters, environments or unsupported
subprocess options use the ordinary subprocess path. Normal Xcode/cache-path
variables are harmless for these Python commands and preserve the adapter path.
The driver remains responsible for its existing immutable source/input boundary.

A standalone check in a new Python process remains the cold audit path. Adoption
belongs at a new frozen checkpoint after the published commit is incorporated,
never inside an active run. This change conveys no evidence currency across
revisions and no new musical-quality, runtime, listening, route or soak claim.

## Verification

`python3 -m unittest discover -s scripts -p 'test_baseline_validation_session.py'`
checks byte-exact cold/reuse reports, fresh-session recomputation, resealed metric
mutations, cardinality/field mutations, altered live PCM and read-race rejection,
context/loaded-implementation invalidation, environment inheritance, memory bounds, immutable cached results,
complete aggregate dispatch, failure propagation and subprocess fallback.


## Measured accepted-bank result

The [derived benchmark receipt](reports/BASELINE_VALIDATION_THROUGHPUT.json)
binds the unchanged 224-asset bank to its original accepted PCM source
`5fe0c50` and contract snapshot 67. The isolated cold pass takes 618.199 seconds.
The final session generation takes 461.237 seconds; its three repeat checks take
15.104, 18.871 and 19.524 seconds. All report bytes match the cold reference,
SHA-256 `b05fc92378bc0b345d6e20171970ebc57fb6987d63a59c6f8bddac4dacbd76fc`.
There are 188 independent computations and 708 exact-input reuses across the
896 per-asset validations; retained result objects occupy 10,428,192 bytes.

The cold reference precedes adapter-only environment propagation and loaded-source
integrity refinements. The thirteen cold validation functions remain AST-exact to
the final source, and the final session uses the exact tooling bytes recorded in
the receipt. All 290 Python tooling tests, including sixteen integrity controls,
pass. The branch map, snapshot 68, Phase-0 zero-findings, roadmap and active
citation checks pass. These timings describe this accepted bank under concurrent
local work; they do not establish an end-to-end roadmap speed multiplier.

The bank retains its original capture identity. This branch's new map snapshot
has no completed Phase-1 currency refresh; adoption requires a newly reconciled
combined snapshot and the original full gate sequence. No capture or qualification
is retagged, and no musical or physical-output claim is added.
