# Single Primary Evaluator

## Runtime contract

Auto Techno proposes one canonical `AutonomousPhrasePlan` at each phrase
boundary. Detached preparation renders that plan once, reduces its complete
symbolic and signal evidence, and asks one exact-engine calibrated evaluator for
the terminal verdict. There is no second plan, comparator, musical substitute,
selector, or permissive shipping evaluator.

The evaluator may request one bounded home-upper-timbre correction. That second
pass rerenders the same plan from the same incoming render, graph, route, and
quality continuation. The transaction therefore contains either:

- one `initialRender`; or
- one `initialRender` followed by one `correctionRender` with
  `forceHomeUpperTimbre == true`.

The final attempt is the selected attempt. A transaction with another order,
another plan fingerprint, more than two passes, or more than one correction is
invalid.

## Qualification

`ProfessionalQualityPrimaryArtifacts` loads only the non-reconstructable
engine-v21 profile v3 `bf5c1ea3c61aef86`, adversarial suite v4
`6301de3109373591`, and disjoint holdout qualification v2
`87283519c0c86cd4`. The profile derives from 28 complete
44.1/48 kHz journeys; four disjoint holdout journeys passed every local and
relationship gate.

Every applicable journey checkpoint is judged independently across the
versioned professional-quality vector. Dimensions never compensate for one
another. An ordinary lock phrase without a named checkpoint uses the calibrated
`longContinuation` envelope so every primary phrase receives a judgment.
The vector now includes eight modal-foundation dimensions: active-bar ratio,
event density, pitch error, attack/body and tail/body relationships, spectral
centroid, masking overlap, and maximum pole radius. Four dedicated attacks prove
detuning, masking flood, rate drift, and runaway tail cannot be compensated by
other strengths.

The app preloads artifacts away from the audio callback and creates a route-local
evaluator for detached preparation. Missing artifacts and rates outside 44.1 or
48 kHz are truthfully `qualificationUnavailable`; they cannot commit audio.

## Commit and transport boundary

Only `qualified` or `adjusted` decisions with complete hard gates, exact plan and
transaction identity, matching combined controller state, and complete incoming/
outgoing continuation provenance may commit. A pending live-master proposal
must bind the exact source observation, future boundary, route, controller
revision, and terminal pre/post trim evidence in both attempts. Rejected or
unavailable work is retained as diagnostic evidence but cannot become playback.

When preparation is late, cancelled, rejected, or unavailable, sample-time
transport may repeat the already accepted immutable PCM with its frozen topology.
That is a callback-continuity hold, not a new musical decision or a second engine.
The audio callback still performs no planning, evaluation, allocation, locking,
waiting, logging, file/network I/O, or UI work.

## Evidence and validation boundaries

The judge consumes the same canonical phrase evidence: score and performance
identity, graph and route provenance, BS.1770-5 loudness and Annex 2 true peak,
physical-time spectral/trajectory evidence, masking and role stems, and every
score-owned renderer consequence. Offline calibration, runtime commit readiness,
listening, route/interruption QA, and physical hardware soak remain distinct
claims.

The scheduled-output controller cannot commit independently of this evaluator.
See [`LIVE_FEEDBACK.md`](LIVE_FEEDBACK.md) for its capture, proposal, lifecycle,
accepted-PCM hold, and physical-QA boundaries.
