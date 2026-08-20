# Source 27: source-local kick dynamics

## Decision

Reuse the existing canonical kick instrument, kick-syntax score ownership,
detector/audible buses, automatic mix, linked master safety, first-order ADAA
primitive, and per-bar kick evidence. Do not add another drum track, kick
instrument, compressor bus, mastering chain, clipper plug-in, preset, or user
control. The source's durable idea is that one unruly source peak should not
consume the later mix's headroom before its body is audible. The precise missing
boundary is the existing kick's final body + sub + click sum: the body is
already locally saturated, but the complete source is not conditioned or
measured before it reaches the detector and audible buses.

## Vertical slice

- Add one `KickSourceDynamicsContract` inside `AutoTechnoDSP`. Every already
  resolved kick event passes its complete source sample through the existing
  first-order antiderivative-antialiased tanh primitive after body, sub, and
  click generation and before detector/audible routing. The fixed engineering
  curve uses drive `1.35` and output gain `0.88`; its per-event ADAA state resets
  at the event boundary. This is source conditioning, not another effect chain.
- The transform is odd, monotonic, finite, state-bounded, and capped at an
  absolute output below `0.88`. It gently raises lower-level body while rounding
  the complete source peak. Event onsets, pitch curve, envelopes, duration,
  count, score intensity, random draws, ducking detector ownership, automatic
  gain, protected routing, transport, and every non-kick voice remain exact.
- A streaming `KickSourceDynamicsRenderEvidence` reduces the concatenated
  event-local pre/post samples without retaining another PCM buffer. It records
  version/order, event and processed-sample counts, exact typed pre/post hashes,
  peak/RMS/crest, physical-time attack and body RMS, bounded upper-mid energy
  ratios, and finiteness. Analysis resets with each event and uses physical
  windows rather than route-specific frame constants.
- `KickMixEvidence` carries that record through both full and protected render
  passes. The existing per-bar `AutonomousKickSyntaxBarEvidence` retains a
  compact source-dynamics projection and binds it to score/render kick count,
  step mask, bar frames, detector/audible scaling, automatic mix, and exact
  pass equality. Withheld bars retain explicit zero/empty evidence; grounded and
  recovery bars require an active, changed, bounded source consequence.
- Professional observation adds conditioned kick crest, attack-to-body,
  upper-mid-presence, and crest-reduction dimensions. A non-compensable
  adversarial transient-spike case must fail the single primary profile. These
  metrics describe the source before the later master stage; they do not turn
  mastering into a candidate or control surface.

## Bounds and fallback

The capability is fixed engine behavior, not a phrase-varying musical choice.
It processes at most sixteen kick events per bar and at most the existing
`0.32` seconds per event. There is no lookahead buffer, extra PCM allocation,
cross-bar continuation, wall-clock state, background analysis, or realtime-
callback work. Rendering and reduction remain detached, and the callback still
receives immutable scheduled buffers.

A score with no kick remains exact zero. Invalid/non-finite evidence makes the
candidate incomplete; the renderer's finite guard and existing terminal safety
remain fail-closed. Home correction does not invent a bypassed legacy kick:
every accepted kick uses the one current engine, and engine/schema identities
advance with the PCM and wire-format change.

## Validation

- pure transfer tests for oddness, monotonicity, finite clamping, exact bounded
  state, signed-zero handling, and lower folded energy than a direct tanh at
  production rates;
- independent legacy-kick oracle versus the conditioned source at 8, 44.1, 48,
  96, and 192 kHz, proving identical event geometry and random sequence,
  changed PCM, lower crest/attack-to-body relation, retained body energy, and a
  finite nonzero upper-mid ratio;
- same-bar full/protected rendering proving unchanged score, count, masks,
  automatic gain, detector-to-audible scale, non-kick stems, effects, and
  continuation while exact source and kick hashes change as intended;
- explicit withheld zero evidence and positive grounded/recovery evidence;
- candidate JSON round-trip, fingerprint sensitivity, source/render/pass
  binding, and malformed count/hash/metric/version/antialias/zero-record
  rejection;
- calibrated source-dynamics dimensions, a non-compensable spike attack,
  regenerated primary artifacts and disjoint holdout, representative-rate and
  resource/cancellation gates, callback symbol audit, release build, and
  exact-head CI.

## Maturation boundary

The v1 curve and simple physical-window evidence are deliberately bounded. A
later serious kick pass may replace them in place with oversampling or
higher-order antialiasing, transient-aware upward/parallel dynamics, a
multiband source contour, or a richer physical kick model only after calibrated
crest, attack/body, upper-mid translation, alias, or master-work evidence
exposes a repeatable deficit. It must preserve the existing kick score, event
geometry, detector/audible ownership, protected center route, exact withheld
silence, and one primary evaluator. The replacement must supersede this source
conditioner rather than coexist with another kick track or dynamics chain.
