# Evidence-ranked deficit register

> Generated from `docs/DEFICIT_REGISTER.json`; do not edit by hand.

This register orders bounded investigations. It is not an evaluator, a
musical-quality score, an implementation authorization, or a runtime input.
Current calibrated auditory defects: **0**.

## Ordering rule

Entries are ordered lexicographically by severity (descending), action class
(ascending), confidence (descending), nearest roadmap number (ascending), then
stable deficit ID. There is no weighted aggregate score. Prevalence is an
observed scoped fraction, never likelihood, importance, or severity.

## Open register

| Rank | ID | Kind | Severity | Confidence | Prevalence | Owner | Nearest items |
|---:|---|---|---|---|---:|---|---|
| 1 | `DEF-0001` | attribution-gap | moderate | high | 14/14 whole-mix-assets | PCMRhythmicBaselineAnalyzer | AT-0038, AT-0040 |
| 2 | `DEF-0002` | calibration-gap | moderate | high | 652/652 score-bound-kick-events | PCMKickFoundationCollisionAnalyzer | AT-0039 |
| 3 | `DEF-0003` | calibration-gap | moderate | high | 44544/44544 fixed-spectral-windows | PCMSpectralBaselineAnalyzer | AT-0041 |
| 4 | `DEF-0004` | calibration-gap | moderate | high | 1392/1392 available-score-motif-comparisons | ScoreMotifBaselineAnalyzer | AT-0044 |
| 5 | `DEF-0005` | calibration-gap | moderate | high | 34/34 score-declared-boundaries | PCMSectionBoundaryBaselineAnalyzer | AT-0045 |
| 6 | `DEF-0006` | coverage-gap | moderate | high | 7/7 four-hour-score-journeys | LongHorizonSessionBaselineAnalyzer | AT-0046, AT-0067 |
| 7 | `DEF-0007` | technical-risk | minor | high | 22330/340230030 decoded-channel-samples | PCMSignalIntegrityAnalyzer | AT-0036, AT-0060 |
| 8 | `DEF-0008` | coverage-gap | unassessed | high | 1/2 declared-host-classes | PerformanceEnvelopeIntegrationTests and performance_envelope_report.py | AT-0355, AT-0358 |
| 9 | `DEF-0009` | coverage-gap | unassessed | high | 1/1 declared-physical-soak-evidence-scopes | Performance envelope external trace | AT-0361 |

### DEF-0001 — Rendered rhythmic onsets are not bound to accepted score events

- **Observed scope:** 14/14 whole-mix-assets; current rhythmic baseline assets whose PCM-inferred onsets lack score-event binding.
- **Severity (moderate):** The gap blocks causal score-versus-render rhythm calibration but is not an audible-failure verdict.
- **Confidence (high):** Every current whole-mix rhythmic record explicitly declares score binding unavailable. Scope limit: Exact only for the 14 outcome-blind Phase-1 whole-mix assets.
- **Canonical owner:** AutonomousPhrasePlan and the accepted resolved score (`AutoTechnoDSP detached evidence`).
- **Evidence owner:** PCMRhythmicBaselineAnalyzer.
- **Nearest roadmap work:** `AT-0038` Add segment-, role-, band-, and horizon-local feature aggregation; `AT-0040` Calibrate transient, density, and fatigue evidence.
- **Source evidence:** `rhythmic` `dcb16f1b1af08a991afa75f3956780754846afa9ff54fb14fc0b76bc61356ac6` — 14/14 assets declare unavailable score binding.
- **Limits:** PCM onset inference can fold stereo cancellation and cannot identify authored score events. No groove preference or defect threshold exists yet.

### DEF-0002 — Kick/foundation collision classes have no calibrated quality interpretation

- **Observed scope:** 652/652 score-bound-kick-events; events with exact descriptive collision evidence but no safe/conflicted calibration.
- **Severity (moderate):** The gap prevents overlap observations from informing selection; overlap itself is not classified as bad sound.
- **Confidence (high):** All current events use the explicit descriptive-not-calibrated interpretation. Scope limit: The causal 35-120 Hz cells are non-power-complementary and event-local.
- **Canonical owner:** Accepted score events, VoiceRenderer role taps, and SpectrumMaskingAnalyzer (`AutoTechnoDSP detached evidence`).
- **Evidence owner:** PCMKickFoundationCollisionAnalyzer.
- **Nearest roadmap work:** `AT-0039` Calibrate kick/bass masking and groove metrics against independent fixtures.
- **Source evidence:** `kick-foundation-collision` `68120648bbb0de1cf62a8b3933a5e02dd2788de885ba7a1b9a7863c7f488f436` — 288/652 events are descriptively low-band-overlap; all lack calibrated severity.
- **Limits:** Overlap may be intentional, constructive, phase-dependent, or perceptually masked. Relative energy is explicitly descriptive and not an excessive-level verdict.

### DEF-0003 — Spectral shape and occupancy observations are uncalibrated

- **Observed scope:** 44544/44544 fixed-spectral-windows; current windows with descriptive shape/occupancy evidence and no artistic threshold.
- **Severity (moderate):** The gap blocks trustworthy harshness, dullness, and spectral-crowding decisions without asserting those defects exist.
- **Confidence (high):** The current spectral contract explicitly describes features without preference thresholds. Scope limit: Band filters overlap and are not power-complementary; silence and role taps are included.
- **Canonical owner:** SpectrumMaskingAnalyzer causal bands and spectral-shape evidence (`AutoTechnoDSP detached evidence`).
- **Evidence owner:** PCMSpectralBaselineAnalyzer.
- **Nearest roadmap work:** `AT-0041` Calibrate timbral motion, harshness, dullness, and spectral-crowding evidence.
- **Source evidence:** `spectral` `863002d5dd5c1b7f1c04fa4a03016bd13c3bb7a422ab25a51f3e42372048c1ed` — 44544 source-bound windows expose descriptive spectral features only.
- **Limits:** No reference-free spectral distribution is inherently good or bad for underground techno. Current role and whole-mix windows are correlated observations, not independent trials.

### DEF-0004 — Symbolic motif recurrence has no salience or coherent-variation calibration

- **Observed scope:** 1392/1392 available-score-motif-comparisons; comparisons with separate symbolic dimensions but no perceptual salience ranking.
- **Severity (moderate):** The gap blocks distinguishing purposeful identity/variation from over-repetition or churn in policy.
- **Confidence (high):** Every comparison is exact accepted-score evidence and the contract explicitly denies PCM salience. Scope limit: Only eligible upper roles within each accepted phrase are compared.
- **Canonical owner:** AutonomousPhrasePlan and resolved upper-note score (`AutoTechnoCore score evidence`).
- **Evidence owner:** ScoreMotifBaselineAnalyzer.
- **Nearest roadmap work:** `AT-0044` Calibrate motif identity, variation, phrase grammar, and arrangement contrast evidence.
- **Source evidence:** `score-motif` `ecd70d76d3a6639a54d57d7740ea4aef2393ee2f500f70c0fd6f56a81eb46145` — 1392 available symbolic comparisons have no calibrated salience or preference interpretation.
- **Limits:** The report does not infer whether a scored motif is audible after synthesis and mixing. Route duplicates share score evidence and are not independent musical cases.

### DEF-0005 — Section contrast and recovery states lack transition-quality calibration

- **Observed scope:** 34/34 score-declared-boundaries; boundaries with descriptive per-dimension evidence and no coherent-transition threshold.
- **Severity (moderate):** The gap blocks classification of abrupt, unresolved, or coherent transitions without calling absence of joint recovery a defect.
- **Confidence (high):** All boundary and recovery statuses are independently reconstructed from exact score-aligned PCM contexts. Scope limit: Contexts contain at most three phrases and cannot establish long-horizon consequence.
- **Canonical owner:** AutonomousSessionDirector, accepted phrase boundaries, and exact context PCM (`AutoTechnoDSP detached evidence`).
- **Evidence owner:** PCMSectionBoundaryBaselineAnalyzer.
- **Nearest roadmap work:** `AT-0045` Calibrate transition preparation, consequence, and recovery evidence.
- **Source evidence:** `section-boundary` `84990b5f911040d1264c569e27f4bbd4e19fe18dfc3d957cea63f1a929d80c27` — 34 boundaries include 26 joint recoveries not observed in horizon and 8 unavailable, all descriptively.
- **Limits:** Joint return across every metric may be neither necessary nor desirable. Missing pre/post context is evidence unavailability, not failed recovery.

### DEF-0006 — Four-hour trajectories lack continuous realized-PCM evidence

- **Observed scope:** 7/7 four-hour-score-journeys; current journeys observed through score planning without continuous realized signal.
- **Severity (moderate):** The gap blocks calibration of realized arc, exposure, and fatigue proxies over set length.
- **Confidence (high):** The report explicitly marks realized signal and quality qualification unavailable for every journey. Scope limit: Score-only planning is exact but cannot establish continuous audio behavior or listener fatigue.
- **Canonical owner:** AutonomousSessionDirector and LongHorizonContinuationState (`AutoTechnoCore detached session evidence`).
- **Evidence owner:** LongHorizonSessionBaselineAnalyzer.
- **Nearest roadmap work:** `AT-0046` Calibrate long-horizon arc, peak scarcity, return, reset, and landing evidence; `AT-0067` Build deterministic long-run scheduling and resource-soak harnesses.
- **Source evidence:** `long-horizon` `f80ca7d977b375b2f67ee0a3012a564923ee37e9098d0f2744c812415a15984c` — 7/7 four-hour journeys have no continuous realized-PCM observation.
- **Limits:** The existing score-only trajectory is not a continuous audio render. Listener fatigue and perceived peak authority remain unknown.

### DEF-0007 — Subnormal Float32 samples remain visible in role/reference evidence

- **Observed scope:** 22330/340230030 decoded-channel-samples; 6 affected assets within the exact whole/role signal baseline.
- **Severity (minor):** Subnormals are a real numeric condition, but no whole-mix fault or callback anomaly is currently observed.
- **Confidence (high):** Counts are exact decoded Float32 facts with zero non-finite and clipping samples in the same corpus. Scope limit: Affected diagnostic/reference assets are correlated and do not prove audible output or CPU harm.
- **Canonical owner:** VoiceRenderer role and processed-stage signal paths (`AutoTechnoDSP rendering and signal evidence`).
- **Evidence owner:** PCMSignalIntegrityAnalyzer.
- **Nearest roadmap work:** `AT-0036` Separate hard safety gates from descriptive features, musical heuristics, and calibrated quality vectors; `AT-0060` Preallocate and bound the canonical DSP graph and per-session resources.
- **Source evidence:** `signal-integrity` `d9bdbd157791e7ce73f95682501b350e286821a655ae9682509120516762158d` — 22330/340230030 samples across 6/224 assets are subnormal.
- **Limits:** The exact same signal may appear in a role and reconstruction reference, so counts are not independent events. No denormal-specific callback slowdown or audible defect has been measured.

### DEF-0008 — Native host and corpus performance coverage is incomplete

- **Observed scope:** 1/2 declared-host-classes; host classes without native bounded performance observation.
- **Severity (unassessed):** No consequence can be assigned until the unavailable native host is measured.
- **Confidence (high):** The envelope explicitly records Windows unavailable and one of seven corpus cases timed on macOS. Scope limit: Observed macOS timing cannot be transferred to Windows or unmeasured musical geometries.
- **Canonical owner:** Supported host route lifecycle and AutonomousPerformancePreparer (`AutoTechnoApp host transport and detached evidence`).
- **Evidence owner:** PerformanceEnvelopeIntegrationTests and performance_envelope_report.py.
- **Nearest roadmap work:** `AT-0355` Qualify supported sample rates, buffer sizes, channel layouts, and route changes; `AT-0358` Bound CPU, memory, battery/thermal pressure, disk use, and preparation lead time.
- **Source evidence:** `performance-envelope` `34d8b67346ab7b27c3e777fcf1a39948c824121ec0a8043d09306659e493647c` — 1/2 declared host classes are unavailable; one largest-frame corpus case is timed.
- **Limits:** The current macOS values are one-machine descriptive observations, not capacity thresholds. Windows remains a source-buildable candidate rather than a promoted binary.

### DEF-0009 — Long physical-output soak evidence is unavailable

- **Observed scope:** 1/1 declared-physical-soak-evidence-scopes; required long physical-output soak scope currently missing.
- **Severity (unassessed):** A bounded external trace cannot establish the consequence or likelihood of long-run route faults.
- **Confidence (high):** The performance qualification explicitly denies a physical-soak claim. Scope limit: The retained Audio System Trace covers about ten seconds on one 44.1 kHz stereo route.
- **Canonical owner:** TechnoEngine scheduling, interruption, and device-route state (`AutoTechnoApp route lifecycle`).
- **Evidence owner:** Performance envelope external trace.
- **Nearest roadmap work:** `AT-0361` Run multi-hour foreground/background, sleep/wake, interruption, and route-churn soak.
- **Source evidence:** `performance-envelope` `34d8b67346ab7b27c3e777fcf1a39948c824121ec0a8043d09306659e493647c` — Physical soak is explicitly unclaimed despite a bounded trace with no relevant observed point of interest.
- **Limits:** Missing soak evidence is not evidence that an underrun or route failure occurred. No background, sleep/wake, route-churn, or thermal-duration matrix was run.

## Quarantined observations

These facts remain visible but are not called sound defects.

- **OBS-0001 — Low-band overlap event count:** 288/652 exact score-bound kick events are classified low-band-overlap. The canonical report explicitly supplies no perceptual, phase, or artistic severity calibration.
- **OBS-0002 — Spectral distributions and low-end occupancy:** 44544 windows retain centroid, rolloff, flatness, band, and low-end occupancy facts. No calibrated musical or perceptual target exists for these descriptive values.
- **OBS-0003 — Motif recurrence and mutation counts:** 1392 available comparisons separate exact, contour, normalized, timing, pitch, register, density, and role relations. No calibrated salience, coherent-development, or over-repetition boundary exists.
- **OBS-0004 — Joint section recovery status:** 26/34 boundaries do not show joint recovery within the bounded context; 8 are unavailable. The report has no calibrated requirement for every dimension to return jointly within three phrases.
- **OBS-0005 — Unresolved score-declared payoffs:** 10/75 score-declared payoff markers have no later recovery marker within the observed horizon. End-of-horizon state and intended long consequences are not calibrated as perceptual failure.
- **OBS-0006 — Bounded live callback trace:** 861 callback cycles were observed without a relevant point of interest in the retained trace window. An empty short trace is neither a long-soak pass nor evidence of an unobserved fault.

## Bound source reports

| Source | Local path | Report fingerprint | Source fingerprint |
|---|---|---|---|
| `signal-integrity` | `docs/local/reports/signal-baseline-v1/manifest.json` | `d9bdbd157791e7ce73f95682501b350e286821a655ae9682509120516762158d` | `e45303fb780ec2eda35b0be1b5bae354de1343ce1dd146d03ae7fdeeece4a17f` |
| `spectral` | `docs/local/reports/spectral-baseline-v1/manifest.json` | `863002d5dd5c1b7f1c04fa4a03016bd13c3bb7a422ab25a51f3e42372048c1ed` | `e45303fb780ec2eda35b0be1b5bae354de1343ce1dd146d03ae7fdeeece4a17f` |
| `kick-foundation-collision` | `docs/local/reports/kick-foundation-collision-v1/manifest.json` | `68120648bbb0de1cf62a8b3933a5e02dd2788de885ba7a1b9a7863c7f488f436` | `e45303fb780ec2eda35b0be1b5bae354de1343ce1dd146d03ae7fdeeece4a17f` |
| `rhythmic` | `docs/local/reports/rhythmic-baseline-v1/manifest.json` | `dcb16f1b1af08a991afa75f3956780754846afa9ff54fb14fc0b76bc61356ac6` | `e45303fb780ec2eda35b0be1b5bae354de1343ce1dd146d03ae7fdeeece4a17f` |
| `score-motif` | `docs/local/reports/score-motif-baseline-v1/manifest.json` | `ecd70d76d3a6639a54d57d7740ea4aef2393ee2f500f70c0fd6f56a81eb46145` | `e45303fb780ec2eda35b0be1b5bae354de1343ce1dd146d03ae7fdeeece4a17f` |
| `section-boundary` | `docs/local/reports/section-boundary-baseline-v1/report.json` | `84990b5f911040d1264c569e27f4bbd4e19fe18dfc3d957cea63f1a929d80c27` | `e45303fb780ec2eda35b0be1b5bae354de1343ce1dd146d03ae7fdeeece4a17f` |
| `long-horizon` | `docs/local/reports/long-horizon-session-baseline-v1/report.json` | `f80ca7d977b375b2f67ee0a3012a564923ee37e9098d0f2744c812415a15984c` | `b1bf19dbf877b737cc6b0baae9524440297667eeb4226c900ded0cd727f1c8d6` |
| `performance-envelope` | `docs/local/reports/performance-envelope-v1/report.json` | `34d8b67346ab7b27c3e777fcf1a39948c824121ec0a8043d09306659e493647c` | `b1bf19dbf877b737cc6b0baae9524440297667eeb4226c900ded0cd727f1c8d6` |

## Qualification boundary

- No entry is a calibrated auditory-quality defect.
- The register cannot activate roadmap work, select a candidate, alter PCM, or
  authorize quality promotion.
- Missing hardware, listening, or soak evidence is not a failed observation.
- Re-run the generator after any bound report, corpus, engine, source, Git, or
  contract-snapshot change.
