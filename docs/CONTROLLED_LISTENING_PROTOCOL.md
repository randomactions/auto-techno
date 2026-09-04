# Controlled Listening Protocol

> Generated from `docs/CONTROLLED_LISTENING_PROTOCOL.json`; do not edit by hand.

This local protocol reduces identity, order, and level bias when a listener records
a comparative observation. It is only a hypothesis-discovery aid. It never ranks,
approves, qualifies, or promotes Auto Techno audio, and it never feeds the runtime.

## Bounded session package

A session has three local-only records: a listener-facing plan with opaque tokens,
a separately retained concealed key with exact source/PCM provenance, and a result
record. Keep the key hidden until observations are sealed. The script does not play
audio or alter the application.

| Bound | Value |
|---|---:|
| Trials | 2–32 |
| Repetitions of one pair | 2–4 |
| First-position streak | at most 2 |
| Session duration | at most 45 minutes |
| Observation note | at most 2000 characters |
| Proposed hypotheses | at most 8 |

Presentation order uses deterministic balanced SplitMix64 pair order. Determinism
makes the plan reproducible; it does not prove that a listener remained blind.

## Required method record

Record a pseudonymous listener ID, transducer type/model and connection, room or
location, output device and route, sample rate/channel count, level method,
reference and locked setting, familiarization, duration, breaks, interruptions,
actual presented order, audibility, preference/no-preference/not-assessable,
confidence, fatigue cue, and bounded notes. Do not claim calibrated headphone SPL.

Supported level methods: `calibrated-loudspeaker-spl`, `locked-device-setting`, `documented-relative-gain-match`.
A calibrated loudspeaker method records a finite 40–100 dB SPL value; other methods
record `null` for SPL and describe the repeatable locked setting or explicit gain
match. Applied audition gain is provenance, not canonical PCM.

## Observation and hypothesis boundary

`observed` means the bounded listening record exists. It does not mean passed.
Candidate identity may be revealed only after observations are recorded. A proposed
hypothesis must name the observation, a score/PCM/evidence checkpoint, a measurable
deficit, and a future automated comparison, with disposition
`proposed-not-authorized`. Only the roadmap discovery process may authorize work.

## Local workflow

```sh
python3 scripts/controlled_listening_protocol.py check
python3 scripts/controlled_listening_protocol.py plan \
  --request docs/local/reports/listening-sessions/<session>/request.json \
  --plan-output docs/local/reports/listening-sessions/<session>/plan.json \
  --key-output docs/local/reports/listening-sessions/<session>/concealed-key.json
python3 scripts/controlled_listening_protocol.py result-template \
  --plan docs/local/reports/listening-sessions/<session>/plan.json \
  --output docs/local/reports/listening-sessions/<session>/result.json
python3 scripts/controlled_listening_protocol.py seal-result \
  --plan docs/local/reports/listening-sessions/<session>/plan.json \
  --result docs/local/reports/listening-sessions/<session>/result.json
python3 scripts/controlled_listening_protocol.py validate-package \
  --plan docs/local/reports/listening-sessions/<session>/plan.json \
  --key docs/local/reports/listening-sessions/<session>/concealed-key.json \
  --result docs/local/reports/listening-sessions/<session>/result.json
```

All request, plan, key, result, audio, and listener records stay under ignored
`docs/local/`. Do not commit them. No real listening session is required by the
protocol-definition roadmap item.
