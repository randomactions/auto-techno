# Negative Result Schema

> Generated from `docs/NEGATIVE_RESULT_SCHEMA.json`; do not edit by hand.

A negative result preserves a falsifiable hypothesis, exact baseline and
intervention, bounded evidence, reason-coded outcome, learned constraints,
reusable evidence, and scheduling disposition. It never edits the roadmap
or declares its own result.

## Outcome and disposition vocabulary

- Outcomes: `falsified`, `inconclusive`, `invalid-experiment`, `regressed-protected-behaviour`, `no-measurable-benefit`
- Failure reasons: `hypothesis-disconfirmed`, `insufficient-evidence`, `invalid-provenance`, `guardrail-regression`, `benefit-below-threshold`, `resource-bound-exceeded`
- Dispositions: `retired`, `superseded`, `follow-up-proposed`
- Evidence kinds: `measurement`, `test`, `render-comparison`, `runtime-observation`, `listening-observation`, `source-analysis`

Records live under `docs/local/reports/negative-results/` and bind the
same item's plan and checked citation record. Evidence references must be
existing safe `repo:path` or `local:docs/local/...` files.

```sh
python3 scripts/negative_result_records.py check
python3 scripts/negative_result_records.py template AT-xxxx
python3 scripts/negative_result_records.py validate-record path/to/NEG-AT-xxxx-nnn.json
```
