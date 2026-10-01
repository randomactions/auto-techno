# Independent measurement fixture evidence

The modal-window, boundary-seam and PCM rhythmic analyzers pass 344 fixed construction cases at source `34b8fa78bd1b5334fa8d7213df7dfb4edcfa8c8f`. These labels verify measurement mechanics; they do not establish musical quality, groove, masking quality or audibility. No production metric, numerical bound, score, renderer or installed policy changes.

| Fixture | Cases | Independent oracle and uncertainty | Result |
| --- | ---: | --- | --- |
| Modal measurement windows | 256 | Enumerate each Float PCM sample by physical timestamp; count support independently of production window arithmetic. RMS tolerance is two Float epsilons times the event peak. | Maximum RMS error 2.5794488767161283e-08; missing, partial and complete support match; undefined silent-body ratios remain unavailable. |
| Supplied block seams | 56 | Authored sine and affine controls with known continuous/discontinuous labels; analytic derivative and Float bounds enclose adjacent-sample changes. | Maximum continuous delta 0.028363941237330437; minimum constructed-jump delta 0.09663605690002441, for these fixed controls only. |
| Rhythmic displacement | 32 | Authored onset indices, energy-matched impulse/packet controls and paired quantization bound of one frame. | Maximum inferred onset error zero frames; displacement stays within the fixed rounding bound. |

The protocol was frozen before measurement: SHA-256 `43868e4a61dffdb0a1daf01e871d6b1d77a86259d1c565e660e889e95289eae6`. The modal matrix includes native 44.1/48 kHz and held-out primitive rates 44.101/96 kHz; those extra rates do not qualify playback routes. Affine seams and packet onsets provide the preregistered held-out construction families. Each matrix has fixed inputs and finite case limits; repeated windows/rates are not independent random population samples and no statistical confidence interval is estimated.

Full Release validation passed 667 Core and 59 App tests, plus six XCTest checks with two existing retired-artifact skips. A focused replay reproduced all 344 per-case rows exactly. Existing masking pilots and counterexamples are preserved without new thresholds or relabeling.

The canonical owners remain `ModalPercussionVoice`/`ModalPercussionWindowSupport`, `AudioQualityReport.maximumBoundaryDelta` and `PCMRhythmicBaselineAnalyzer`. The tests extend their shared test-owned signal fixtures; they add no persistent state, continuation or future musical decision. Missing modal support still fails closed; installed observation v21, primary v30 and long-horizon v16 retain their existing bounds and fallback. Offline observation v22/profile v31 remain unqualified and unactivated.

The seam statistic remains an adjacent amplitude difference at supplied block joins; a one-block input has no supplied joins. These controls do not make it a derivative or an audibility classifier. Rhythmic production evidence remains inferred, rather than score-bound. Independent quality targets, preregistered morphology/timing coverage, fresh disjoint holdouts and exact primary/long-horizon qualification remain outstanding. The failed 40-development/6-holdout qualification and both frozen corpora remain preserved.

The complete 42-stage common-head refresh passes all 15 lifecycle families and 19 aggregate checks at snapshot 58. All 224 preserved whole/role/residual assets match exactly across 340,230,030 samples, with zero changed samples. Gate fingerprint: `11040db997fec4e91b4ed12884d229b9ceb80e9eadb3ecabd8f3c9944376cf0c`. All 272 tooling regressions pass. The failed partial refresh is retained locally as NEG-AT-0039-005; strict source report head equality remains unchanged. No new app/route listening, physical soak, live callback trace or hosted CI result is claimed.
