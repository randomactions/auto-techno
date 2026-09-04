# Result Status Vocabulary

> Generated from `docs/RESULT_STATUS_VOCABULARY.json`; do not edit by hand.

This vocabulary keeps implementation, verification, automated qualification,
publication/CI, runtime, listening observation, and physical-output soak as
separate results. Passing one never implies another.

## States

| State | Evidence required | Limitation required | Meaning |
|---|---:|---:|---|
| `not-applicable` | no | yes | The gate is outside this item's scope; this never satisfies a release prerequisite. |
| `unavailable` | no | yes | A named prerequisite or evaluator does not exist or cannot currently run. |
| `not-run` | no | yes | The applicable gate was not performed for this exact revision. |
| `in-progress` | no | yes | The applicable gate started but has no terminal result. |
| `passed` | yes | no | The objective gate passed for the named exact revision and evidence. |
| `failed` | yes | yes | The objective gate ran and failed for the named exact revision. |
| `blocked` | no | yes | The gate cannot proceed because a concrete dependency or authority is missing. |
| `observed` | yes | no | A listening observation was recorded as hypothesis evidence, never as approval. |

## Gates

| Gate | Allowed states | Professional release requirement | Meaning |
|---|---|---|---|
| `implementation` — Implementation | `not-applicable`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | The bounded requested change exists in the intended canonical owner. |
| `focused-local-verification` — Focused local verification | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | Item-specific structural, signal, ownership, or tooling checks passed locally. |
| `full-local-verification` — Full local verification | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | The complete required local suite and release build passed for the exact revision. |
| `automated-quality-qualification` — Automated quality qualification | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | Exact engine/policy artifacts, hard gates, adversarial cases, and holdout qualification passed. |
| `published-exact-sha` — Published exact SHA | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | The reported exact commit is present on the intended remote branch. |
| `exact-head-ci` — Exact-head CI | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | Required remote CI passed against the same published exact commit. |
| `release-app-launched` — Release app launched | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | The exact release artifact launched with recorded binary identity and advancing playback state. |
| `app-route-qa` — App and route QA | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | Playback, transport, route, interruption, recovery, and applicable accessibility behavior passed on the exact release app. |
| `listening-observation` — Listening observation | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `blocked`, `observed` | `not-a-release-prerequisite` | Optional human observation may open a measurable hypothesis but cannot approve or override qualification. |
| `physical-output-soak` — Physical-output soak | `not-applicable`, `unavailable`, `not-run`, `in-progress`, `passed`, `failed`, `blocked` | `passed` | The required duration, output hardware, recovery scenarios, and stability observations passed. |

## Professional release claim

Verified only when every objective prerequisite passes for one exact published revision; listening is never an approval gate.

Required objective gates: `implementation`, `focused-local-verification`, `full-local-verification`, `automated-quality-qualification`, `published-exact-sha`, `exact-head-ci`, `release-app-launched`, `app-route-qa`, `physical-output-soak`.

Listening is deliberately excluded from the prerequisite list. `observed`
records optional human evidence; it cannot approve or override an automated
failure.

Validate a result record with:

```sh
python3 scripts/result_status_vocabulary.py validate-record path/to/result.json
```

Create a complete conservative skeleton without writing a file:

```sh
python3 scripts/result_status_vocabulary.py template AT-xxxx
```
