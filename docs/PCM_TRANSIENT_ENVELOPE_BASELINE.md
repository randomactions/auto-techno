# PCM transient and envelope baseline contract

## Purpose and authority

AT-0022 adds detached, descriptive evidence for transient count, PCM-inferred
event timing, attack geometry, decay occupancy, and crest across the exact
whole-mix and role-signal corpus. It makes role-local changes inspectable
without interpreting a denser transient field, faster attack, shorter tail, or
higher crest as inherently better.

This work does not add a runtime evaluator dimension, quality threshold,
automatic correction, score event, renderer, continuation value, future
decision, user control, engine, profile, or release claim. The accepted
resolved score and `VoiceRenderer` remain the authority for authored and
rendered events. `MusicalQualityMetrics` remains the owner of the current
whole-mix transient-density meaning. `PCMSignalIntegrityAnalyzer` remains the
owner of exact channel and whole/bar level integrity. `StemObservationAnalyzer`
remains the owner of preparation-time role onset RMS, occupancy, and crest.

`PCMTransientDensityTracker` extracts only the existing transient detector's
reusable state and constants. `MusicalQualityMetrics` delegates to that tracker
without changing the sample fold, comparison order, threshold, refractory
geometry, envelope update, count, or density denominator.
`PCMTransientEnvelopeAnalyzer` composes that named legacy fact with a separate
PCM-inferred shape family during detached analysis. The two event meanings are
never silently equated.

Generated payloads and reports live under
`docs/local/reports/transient-envelope-baseline-v1/` and remain ignored,
reconstructable local evidence.

## Exact inputs and provenance

The exporter reads the current whole-mix and role-stem manifests produced by
AT-0016 and AT-0017. It requires their contract fingerprint, source
fingerprint, Git head, engine version, identities, asset sets, sample rates,
channel counts, frame counts, PCM hashes, WAV hashes, and paths to agree before
analysis. The current corpus contains 14 whole mixes and 210 aligned role,
reference, and residual signals, or 224 assets total.

Each source must be a canonical mono or stereo 32-bit IEEE Float WAV with
finite PCM and exact manifest geometry. A missing, extra, duplicate, stale,
malformed, non-finite, unaligned, unsupported, or path-divergent source fails
closed. Normal tests use synthetic arrays and temporary WAVs; they do not read
private corpus audio or write local reports.

The report binds both input manifests and their PCM-set fingerprints, the
corpus, contract baseline, source fingerprint, Git head, engine version, every
asset's PCM hash, and a canonical report fingerprint. The independent Python
verifier reads every bound WAV and recomputes every event, landmark, summary,
and segment from Float32 PCM rather than trusting Swift aggregation.

## Signal domain and stereo fold

Analysis uses one deterministic mono signal:

```text
mono[frame] = arithmetic mean of every source channel at that frame
```

This is the existing whole-mix transient detector's fold. It is not an
energy-preserving stereo downmix. Equal and opposite channels cancel exactly;
the fixture bank makes that consequence explicit. Per-channel and pooled
signal-integrity facts remain available in AT-0019 and must be used when stereo
phase cancellation would make arithmetic-fold evidence incomplete.

## Named legacy transient family

For each folded sample, the legacy detector compares the current rectified
magnitude to its previous smoothed envelope:

```text
detected = abs(sample) - previousEnvelope > 0.055
           and framesSincePreviousDetection >= floor(sampleRate * 0.035)

coefficient = 1 - (1 - 0.08) ^ (48000 / sampleRate)
previousEnvelope += (abs(sample) - previousEnvelope) * coefficient
```

The comparison happens before the envelope update, exactly as in
`MusicalQualityMetrics`. Density is the exact detected count divided by exact
source duration in seconds. Detection continues across input block and one-bar
segment boundaries. Segments merely attribute already detected frames; they do
not reset detector state.

The absolute `0.055` novelty threshold is amplitude-sensitive. It is retained
for compatibility, not promoted as a universal transient definition. A slowly
rising sound can validly have zero legacy detections while still producing one
PCM-inferred shape event.

## PCM-inferred shape-event family

Shape evidence uses a separate rectified peak/release envelope. Its attack is
instantaneous. When magnitude falls, its one-pole release is normalized to a
10 ms time constant:

```text
releaseCoefficient = 1 - exp(-1 / (sampleRate * 0.010))
```

The source activity gate reuses the preparation observation's relative and
absolute scale relationship:

```text
gate = min(sourcePeak, max(0.00001, sourcePeak * 0.04))
```

A candidate begins when that envelope rises from below the gate to at or above
it, or when the named legacy detector fires. Candidates separated by less than
nearest-frame 35 ms are merged at the earlier frame, preserving whether the
merged source was an activity rise, legacy flux, or both. This merge limits
multiple names for one onset; it does not claim perceptual event identity.

The report's onset authority is therefore exactly
`pcm-inferred-activity-rise-or-legacy-flux-not-score-bound`. These onsets never
create, move, validate, or name accepted score events. Later work that needs
authored event truth must bind the score/render evidence explicitly and retain
a different confidence label.

## Event window and boundary state

Each shape event begins at its inferred onset. Its analysis end is the earliest
of:

- the next inferred event onset;
- one eighth note at fixed 130 BPM, or `240 / 130 / 8` seconds;
- the exact source end.

Every event records which boundary won as `next-event`, `fixed-window`, or
`source-end`. The fixed window is nearest-frame sample-rate normalized. A
source-end event is boundary-truncated evidence, not silently extrapolated
decay.

The peak search ends at the event boundary or nearest-frame 90 ms after onset,
whichever occurs first. This reuses the duration of the existing preparation
onset observation while measuring a different, explicitly event-local fact.
The earliest maximum envelope sample is the peak landmark.

## Attack landmarks and shape

The event records the first envelope frame at or above 10% and 90% of its local
peak. Attack rise frames and seconds are the distance between those landmarks.
An impulse therefore has a valid zero-frame rise; it is not unavailable.

Attack shape is the arithmetic mean of peak-normalized envelope values from
the 10% through 90% landmarks, inclusive:

```text
sum(envelope[attack10 ... attack90] / eventPeak)
-------------------------------------------------
             included landmark frame count
```

This dimensionless statistic preserves a testable curve relation: a concave-up
attack has a lower value than a linear attack with the same duration, while a
concave-down attack has a higher value. It is not a timbre label, perceptual
sharpness score, or quality rank. Attack time and normalized shape remain
separate so neither substitutes for the other.

## Decay occupancy and landmark

Decay begins at the selected event peak and ends immediately before the event
boundary. Its activity gate is:

```text
max(0.00001, eventPeak * 0.04)
```

Decay occupancy is the number of decay frames at or above that gate divided by
the exact peak-through-end frame count. The first frame at or below 10% of peak
is retained as an optional decay landmark. A fixed or source boundary can occur
before that landmark, in which case the value is `null`; it is never fabricated.

Synthetic short and long decays prove the expected occupancy and landmark sign.
The metric includes the defined 10 ms release follower and fixed event window,
so it describes this evidence geometry rather than an unconstrained acoustic
decay time.

## Crest

Asset, segment, and event crest use the linear arithmetic-fold relationship:

```text
crest = sample peak / RMS
```

Silence uses the finite sentinel `0`. Event crest uses the exact inferred event
window. Asset and segment crest describe the same folded signal at their
respective scopes. AT-0019 remains the source for channel-specific, pooled,
sample-peak, true-peak, clipping, DC, subnormal, exact-zero, and near-silence
facts. This report does not relabel its arithmetic-fold crest as those broader
integrity measures.

## One-bar segments and aggregation

Segments use nearest-frame `sampleRate * 240 / 130`, the current fixed-130-BPM
one-bar geometry. They cover the source contiguously, including a final partial
segment. A legacy detection or shape event belongs to the segment containing
its onset frame. Event attack, decay, and crest remain measured over their full
bounded event window even if that window crosses a segment boundary.

Asset and segment summaries retain duration, both event counts and densities,
folded crest, and the arithmetic mean of each shape value. When no shape event
is present, the count and density are zero while attack, decay, and event-crest
aggregates are `null`. Silence and an inactive role are valid measured states,
not errors.

Role comparison happens through the report's exact `signal` and
`classification` identities. It does not collapse the dry audible source,
source stage, protected send, return, residual, reference, or whole mix into an
unlabeled average.

## Operation

Normal CI runs the synthetic Swift fixture bank and Python independent-verifier
mutation bank. Exact corpus export and finalization are opt-in and local-only:

```bash
AUTOTECHNO_RUN_TRANSIENT_ENVELOPE_BASELINE=1 \
  swift test -c release --jobs 1 --no-parallel \
  --filter TransientEnvelopeBaselineIntegrationTests
python3 scripts/transient_envelope_baseline_report.py generate
python3 scripts/transient_envelope_baseline_report.py check
```

The exporter requires current AT-0016/17 manifests. If a source or contract
fingerprint changes, those upstream artifacts must be regenerated and proved
exact before AT-0022 can be finalized.

## Qualification boundary and limitations

Swift synthetic fixtures cover legacy-detector equality, isolated and repeated
impulses, slowly rising activity without legacy flux, fast and slow linear
attacks, concave-up and concave-down attacks, short and long decays, amplitude
scaling, steady signal, silence, stereo alignment and cancellation, 44.1/48 kHz
geometry, segmentation, source-end truncation, malformed geometry, unsupported
channel counts, and non-finite input. Python independently proves the attack
curve and decay signs, amplitude/sample-rate/phase behavior, report generation,
current checking, and rejection of event, summary, policy, manifest, and
fingerprint mutations.

This baseline does not determine perceptual punch, desired density, preferred
envelope, role importance, masking, phase compatibility, mix quality,
professional quality, automatic transient shaping, compression policy,
listening approval, app/route behavior, or physical-output soak. It changes no
rendered sample, accepted score, runtime evaluation, continuation, fallback, or
future-boundary decision. A later calibrated relationship may enter the single
evaluator/controller only through its own bounded roadmap item and independent
qualification.
