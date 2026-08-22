# Source 31: score-owned upper harmonic tail

## Source evidence

- Video: `https://www.youtube.com/watch?v=Fn7paYGwDCQ`, *Electrical zaps
  using Live's Wavetable*, Underdog Electronic Music School, accessed
  2026-08-22. The published title has been shortened here to the portable
  synthesis topic; no artist imitation is an implementation goal.
- Transcript: YouTube automatic English captions retrieved with `yt-dlp`
  2026.08.19. The `en` and `en-orig` VTT files were byte-identical with
  SHA-256
  `197265c30a66ba71c54bded4d2fc1cb3c22d769f9501952127d57ecc29f80f64`.
  The structured English JSON3 capture had SHA-256
  `03342dac0d28da6685f3099fbcab2d10a8904775e7d1d74bfe9a7367af71ac93`.
- Page discussion: 50 top-ranked top-level comments and 15 replies were
  sampled. Two technically specific threads independently highlighted the
  distinction between noise and the closely spaced upper harmonics of a low
  pitched waveform. One additional thread suggested distortion as another
  route to a crunchy top. This supports the harmonic-tail mechanism and
  bounded nonlinear colour, but the discussion did not converge across three
  independent reports on a portable pitch, cutoff, resonance, drive, motion,
  envelope, or mix value.
- Audio demonstration: direct unauthenticated extraction decoded to 48 kHz
  stereo PCM with duration 504.930 seconds and SHA-256
  `9c8ac167a011e1c214f2f3415506139dde4f11035c6124955e5e35bbcf63a139`.
  Machine-only 8,192-point spectral inspection found mean centroid/rolloff of
  about 5.0/8.9 kHz in the upper-bandpass demonstration, 5.1/9.0 kHz after
  drive, and 4.8/9.0 kHz in the cold-reverb demonstration. The latter region's
  approximate high-passed energy was 16.2% above 5 kHz and 7.2% above 8 kHz.
  Speech, interface sounds, and demonstration edits contaminate these windows,
  so the measurements are descriptive evidence only and establish no portable
  threshold.
- Relevant source claim: a very low harmonic source creates closely spaced
  partials in its upper range. Isolating and resonating that upper tail,
  applying bounded colour, moving the selected band without note retrigger,
  and retaining a high-passed spatial response creates an electrical texture
  that a broadband noise source would not reproduce in the same way.

The current yt-dlp installation and its local Deno runtime solved the page's
JavaScript challenge directly. No account, cookie, CAPTCHA, browser session, or
PO-token provider was used. Captions, comments, metadata, audio, thumbnail, and
machine inspection remain temporary and untracked.

## Falsifiable deficit

The canonical engine already has the correct owner and most of the routing:

- `InstrumentPalette` assigns every upper event to one score-owned patch,
  architecture, four-coordinate automation state, and bounded existing effects;
- the existing Spectral Texture architecture renders deterministic response,
  atmosphere, and transition material without samples or callback randomness;
- `alienNoise` owns ring-modulated response/atmosphere texture, `metalVeil`
  owns metallic response/atmosphere plus the transition-only adjacent cluster,
  and `dustCloud` owns diffuse atmosphere/transition material;
- drive, filtered reverb, masking, glue, and master already belong to the one
  canonical signal path, and architecture-local PCM/evidence already survive
  detached preparation.

The missing reusable capability is a dense harmonic source whose low
fundamental is deliberately absent from the audible result while its upper tail
is selected by a moving resonant band. None of the three existing Spectral
Texture homes generates a band-limited saw tail or binds its source spacing,
upper-band isolation, free-running motion, and nonlinear colour to same-pass
evidence.

The hypothesis is falsified if an existing patch already produces and proves
that causal combination. It is supported when a distinct response patch adds
measurable upper-tail energy and bounded center motion, suppresses its low
source, preserves deterministic continuation, and leaves every existing patch
bit identical.

## Causal shape decision

Add one recognizable patch, `voltageArc`, inside the existing
`spectralTexture` architecture. Do not add a track, instrument architecture,
voice role, effect stage, return, graph, engine, profile selector, sample,
noise recording, plug-in, callback controller, or user control.

Extending `alienNoise` would hide a different causal source beneath an existing
identity. Reusing `metalVeil` would conflate a response texture with its durable
transition-only close-cluster relation. A new architecture would duplicate the
same role, state, routing, continuation, and evidence contracts. A fourth patch
home is therefore the smallest truthful boundary: the director can select the
new character while the established Spectral Texture instrument and effect
chain remain singular.

`voltageArc` is eligible only for response use. The Broken Suspension response
becomes its canonical authored home; all other character/role mappings retain
their current assignments. This places the accent in a sparse, interrupted
context and prevents continuous upper-band occupation.

## Score relation and bounded renderer

Derive one durable `SpectralTextureHarmonicTailRelation` from the exact
`voltageArc` response assignment. The relation has no free numeric parameters
and survives replacement of the provisional oscillator/filter realization.

During detached preparation, the existing `SpectralTextureVoice` interprets
that relation as follows:

- octave-fold the score note into a fixed low-source register, retaining its
  pitch-class relationship while bounding the fundamental to a narrow
  approximately 28...56 Hz range;
- generate a deterministic polyBLEP saw so the dense harmonic source is not
  created by naive discontinuity aliasing;
- apply the already-authorized drive as bounded pre-filter colour for this
  patch, while existing patches retain their current post-filter behaviour;
- isolate the upper tail with one stable state-variable band-pass whose center
  and resonance are renderer-owned translations of the existing color and
  motion coordinates;
- keep center frequency within a physical upper band at 44.1/48 kHz and scale
  it safely below Nyquist at every supported route rate;
- move the center with one bounded, free-running low-depth LFO whose phase
  continues in the existing patch state and is not reset by note gates;
- reuse the existing response envelope, drive authorization, filtered-reverb
  send, masking guard, glue, master, and score level; no effect-chain copy is
  introduced;
- suppress the source fundamental and low tail through the band-pass rather
  than mixing a new bass layer into the foundation.

The current numeric fold range, polyBLEP, state-variable filter, center range,
resonance, drive curve, and LFO law are bounded renderer policy, not copied
preset values. Malformed rates or notes fail finite and silent. Preparing the
same score and continuation repeats exactly; continuing from accepted state
advances the harmonic and modulation phases normally.

## Same-pass evidence and policy

Add an isolated harmonic-tail tap only while upper-role evidence is requested,
parallel to the existing Spectral Texture architecture and cluster taps. Extend
the singular architecture record with one optional nested harmonic-tail proof:

- exact source-assignment and rendered-event counts, semantic relation, event
  fingerprint, isolated PCM hash, peak, RMS, crest factor, and finite flag;
- minimum/maximum applied folded fundamental, band center, resonance, drive,
  and LFO rate across the exact rendered events;
- low-band and upper-band energy ratios derived from the isolated dry tail;
- positive center excursion and event-to-assignment binding;
- absence of harmonic-tail evidence when no exact `voltageArc` response
  assignment exists.

Candidate completeness requires exact score-to-render binding, a bounded low
source, a center safely below Nyquist, positive isolated energy, low-band
suppression, positive upper-band energy, nonzero center movement, finite values,
and valid fingerprints. Missing, moved, wrong-role, disconnected, contaminated,
forged-hash, out-of-rate, nonfinite, or unowned evidence fails closed.

Add one Professional Evidence dimension,
`spectral-harmonic-tail-upper-band-energy-ratio-mean`. It measures the accepted
candidate's causal upper-tail consequence and is higher-only safer within the
calibrated corpus. A dedicated non-compensable disconnected-tail attack removes
the isolated consequence while preserving claimed score metadata. Advance
engine, quality, candidate, observation, evidence-bank, adversarial, holdout,
and primary-evaluator identities, then regenerate the exact single-primary
profile, adversarial suite, and disjoint holdout.

## TDD and validation

- Add failing Core tests first for the new patch capability, response-only
  validity, exact Broken Suspension ownership, unchanged other mappings,
  semantic relation, deterministic selection, and typed fingerprint sensitivity.
- Add failing DSP tests first at 8, 44.1, 48, 96, and 192 kHz for polyBLEP
  finiteness, folded-source bounds, safe center bounds, low-tail suppression,
  positive upper energy, positive motion, deterministic replay, continuation,
  existing-patch neutral identity, and existing cluster isolation.
- Extend prepared architecture and candidate tests for score-to-PCM binding,
  decoded bounds, wrong role/count/rate/hash/energy rejection, correction
  equality, cancellation, and retained-record limits.
- Add metric extraction, the non-compensable disconnected-tail scenario,
  regenerated exact artifacts, and disjoint holdout qualification.
- Run focused Core/DSP/prepared tests; candidate/live tampering; exact artifacts;
  calibration, policy, holdout, atomic commit, unsupported-rate, route,
  cancellation, correction, representative-rate, resource, continuation,
  Core/evidence, preparation, protected-routing, and repository-surface matrices
  serially.
- Audit the realtime-producer object, build the optimized app, inspect the clean
  diff and public text, refresh/rebase on main if required, push main and the
  source branch, and require exact-head GitHub Actions success.

## Maturation boundary

The durable idea is that a low periodic source can yield a dense, electrically
animated upper texture when the score selects only its harmonic tail. The v1
fold range, polyBLEP saw, state-variable band-pass, fixed response eligibility,
motion curve, resonance, drive law, and isolated energy proxy are replaceable
realization details.

A later serious renderer may replace them in place with oversampled oscillator
banks, minimum-phase anti-aliasing, zero-delay-feedback or higher-order
multimode filtering, nonlinear filter models, envelope-followed center motion,
multiband spatial diffusion, stereo decorrelation, or scene-conditioned
response placement only when the primary evaluator exposes a repeatable
motion, harshness, masking, translation, or narrative deficit. It must preserve
the score-owned patch/relation, response role, bounded continuation, exact home
states, same-pass causal evidence, one canonical renderer, and one primary
evaluator. It must supersede this realization rather than coexist as another
engine or generic zap effect.
