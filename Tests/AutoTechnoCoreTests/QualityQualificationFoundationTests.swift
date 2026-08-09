import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Versioned quality qualification foundation")
struct QualityQualificationFoundationTests {
    @Test("Core decisions and continuation round-trip deterministically")
    func coreRoundTrip() throws {
        #expect(QualityQualificationContract.maximumCorrectionRenders == 1)

        let unavailable = QualityDecision.qualificationUnavailable(
            candidateFingerprint: "candidate-a",
            evidenceFingerprint: "evidence-a",
            eligibleFutureSample: 8_192
        )
        let initial = QualityContinuationState(lastDecision: unavailable)
        let encoded = try deterministicJSON(initial)
        let encodedAgain = try deterministicJSON(initial)
        let decoded = try JSONDecoder().decode(QualityContinuationState.self, from: encoded)
        #expect(encoded == encodedAgain)
        #expect(decoded == initial)

        let qualified = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1, .candidateQualifiedV1],
            candidateFingerprint: "candidate-b",
            evidenceFingerprint: "evidence-b",
            eligibleFutureSample: 16_384
        )
        let accepted = initial.recording(
            decision: qualified,
            evidenceFingerprint: "evidence-b",
            controllerStateFingerprint: "controller-a"
        )
        #expect(accepted.revision == 1)
        #expect(accepted.acceptedPolicyVersion == "test-policy.v1")
        #expect(accepted.acceptedCandidateFingerprint == "candidate-b")
        #expect(accepted.acceptedEvidenceFingerprint == "evidence-b")
        #expect(accepted.acceptedControllerStateFingerprint == "controller-a")
        #expect(accepted.earliestEligibleFutureSample == 16_384)
        #expect(accepted.observedCandidateFingerprint == "candidate-b")
        #expect(accepted.observedEvidenceFingerprint == "evidence-b")
        #expect(accepted.observedControllerStateFingerprint == "controller-a")
        #expect(accepted.acceptanceProvenanceComplete)
        #expect(!QualityContinuationState(
            lastDecision: qualified
        ).acceptanceProvenanceComplete)
        let explicitEarlierBoundary = initial.recording(
            decision: qualified,
            evidenceFingerprint: "evidence-b",
            controllerStateFingerprint: "controller-a",
            earliestEligibleFutureSample: 8_192
        )
        #expect(explicitEarlierBoundary.earliestEligibleFutureSample == 16_384)

        let rejected = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .rejected,
            reasonCodes: [.hardGateFailedV1],
            candidateFingerprint: "candidate-rejected",
            evidenceFingerprint: "rejected-evidence"
        )
        let held = accepted.recording(
            decision: rejected,
            evidenceFingerprint: "rejected-evidence",
            controllerStateFingerprint: "rejected-controller",
            earliestEligibleFutureSample: 32_768
        )
        #expect(held.revision == 2)
        #expect(held.acceptedPolicyVersion == "test-policy.v1")
        #expect(held.acceptedCandidateFingerprint == "candidate-b")
        #expect(held.acceptedEvidenceFingerprint == "evidence-b")
        #expect(held.acceptedControllerStateFingerprint == "controller-a")
        #expect(held.earliestEligibleFutureSample == 16_384)
        #expect(held.observedCandidateFingerprint == "candidate-rejected")
        #expect(held.observedEvidenceFingerprint == "rejected-evidence")
        #expect(held.observedControllerStateFingerprint == "rejected-controller")

        let missingAcceptanceIdentity = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1]
        )
        let rejectedMissingIdentity = accepted.recording(
            decision: missingAcceptanceIdentity,
            evidenceFingerprint: nil,
            controllerStateFingerprint: nil
        )
        #expect(rejectedMissingIdentity.lastDecision.outcome == .rejected)
        #expect(rejectedMissingIdentity.lastDecision.reasonCodes.contains(
            .acceptanceProvenanceMissingV1
        ))
        #expect(!rejectedMissingIdentity.lastDecision.reasonCodes.contains(
            .candidateQualifiedV1
        ))
        #expect(rejectedMissingIdentity.acceptedCandidateFingerprint == "candidate-b")
        #expect(rejectedMissingIdentity.acceptedEvidenceFingerprint == "evidence-b")
        #expect(rejectedMissingIdentity.acceptedControllerStateFingerprint == "controller-a")

        let mismatchedAcceptance = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1],
            candidateFingerprint: "candidate-c",
            evidenceFingerprint: "evidence-c"
        )
        let rejectedMismatch = accepted.recording(
            decision: mismatchedAcceptance,
            evidenceFingerprint: "different-evidence",
            controllerStateFingerprint: "controller-c"
        )
        #expect(rejectedMismatch.lastDecision.outcome == .rejected)
        #expect(rejectedMismatch.lastDecision.reasonCodes.contains(.evidenceMismatchV1))
        #expect(rejectedMismatch.acceptedPolicyVersion == accepted.acceptedPolicyVersion)
        #expect(rejectedMismatch.acceptedCandidateFingerprint ==
                accepted.acceptedCandidateFingerprint)
        #expect(rejectedMismatch.acceptedEvidenceFingerprint ==
                accepted.acceptedEvidenceFingerprint)
        #expect(rejectedMismatch.acceptedControllerStateFingerprint ==
                accepted.acceptedControllerStateFingerprint)

        let rejectedMissingObservedEvidence = accepted.recording(
            decision: mismatchedAcceptance,
            evidenceFingerprint: nil,
            controllerStateFingerprint: "controller-c"
        )
        #expect(rejectedMissingObservedEvidence.lastDecision.outcome == .rejected)
        #expect(rejectedMissingObservedEvidence.lastDecision.reasonCodes.contains(
            .acceptanceProvenanceMissingV1
        ))
        #expect(rejectedMissingObservedEvidence.observedEvidenceFingerprint == nil)
        #expect(!rejectedMissingObservedEvidence.lastDecision.reasonCodes.contains(
            .evidenceMismatchV1
        ))

        let staleQualification = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1, .staleEvidenceV1],
            candidateFingerprint: "candidate-stale",
            evidenceFingerprint: "evidence-stale"
        )
        let rejectedStale = accepted.recording(
            decision: staleQualification,
            evidenceFingerprint: "evidence-stale",
            controllerStateFingerprint: "controller-stale"
        )
        #expect(rejectedStale.lastDecision.outcome == .rejected)
        #expect(rejectedStale.lastDecision.reasonCodes.contains(.staleEvidenceV1))
        #expect(rejectedStale.lastDecision.reasonCodes.contains(.hardGateFailedV1))
        #expect(!rejectedStale.lastDecision.reasonCodes.contains(
            .acceptanceProvenanceMissingV1
        ))

        let emptyPolicyQualification = QualityDecision(
            policyVersion: "  \n",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1],
            candidateFingerprint: "candidate-empty-policy",
            evidenceFingerprint: "evidence-empty-policy"
        )
        #expect(emptyPolicyQualification.policyVersion ==
                QualityQualificationContract.uncalibratedPolicyVersion)
        #expect(emptyPolicyQualification.outcome == .qualificationUnavailable)
        #expect(emptyPolicyQualification.reasonCodes.contains(.policyUncalibratedV1))
        #expect(emptyPolicyQualification.hasOutcomeConsistentReasonCodes)

        let missingQualifiedReason = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .qualified,
            reasonCodes: [],
            candidateFingerprint: "candidate-no-reason",
            evidenceFingerprint: "evidence-no-reason"
        )
        let adjustedWithQualifiedReason = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .adjusted,
            reasonCodes: [.candidateQualifiedV1],
            candidateFingerprint: "candidate-wrong-reason",
            evidenceFingerprint: "evidence-wrong-reason"
        )
        let fallbackWithoutReason = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .conservativeFallback,
            reasonCodes: [.hardGateFailedV1]
        )
        let holdWithoutReason = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .deterministicHold,
            reasonCodes: []
        )
        #expect(!missingQualifiedReason.hasOutcomeConsistentReasonCodes)
        #expect(!adjustedWithQualifiedReason.hasOutcomeConsistentReasonCodes)
        #expect(!fallbackWithoutReason.hasOutcomeConsistentReasonCodes)
        #expect(!holdWithoutReason.hasOutcomeConsistentReasonCodes)
        let rejectedInconsistentReasons = accepted.recording(
            decision: adjustedWithQualifiedReason,
            evidenceFingerprint: "evidence-wrong-reason",
            controllerStateFingerprint: "controller-wrong-reason"
        )
        #expect(rejectedInconsistentReasons.lastDecision.outcome == .rejected)
        #expect(rejectedInconsistentReasons.lastDecision.reasonCodes.contains(
            .hardGateFailedV1
        ))
        #expect(!rejectedInconsistentReasons.lastDecision.reasonCodes.contains(
            .candidateQualifiedV1
        ))

        let calibratedUnavailableWithEvidence = QualityDecision.qualificationUnavailable(
            policyVersion: "test-policy.v1",
            candidateFingerprint: "candidate-evaluator-unavailable",
            evidenceFingerprint: "evidence-present"
        )
        #expect(calibratedUnavailableWithEvidence.reasonCodes.contains(
            .evaluatorUnavailableV1
        ))
        #expect(!calibratedUnavailableWithEvidence.reasonCodes.contains(
            .evidenceMissingV1
        ))

        let impossibleUncalibratedQualification = QualityDecision(
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1],
            evidenceFingerprint: "evidence-c"
        )
        #expect(impossibleUncalibratedQualification.outcome == .qualificationUnavailable)
        #expect(impossibleUncalibratedQualification.reasonCodes.contains(.policyUncalibratedV1))
        #expect(!impossibleUncalibratedQualification.reasonCodes.contains(.candidateQualifiedV1))
    }

    @Test("Silence and a centered sine produce finite deterministic evidence")
    func silenceAndSine() {
        let silence = [Float](repeating: 0, count: 2_048)
        let silentInput = UpperTimbreAnalysisInput(
            left: silence,
            right: silence,
            sampleRate: 8_000
        )
        let firstSilence = UpperTimbreEvidenceAnalyzer.analyze(silentInput)
        let secondSilence = UpperTimbreEvidenceAnalyzer.analyze(silentInput)
        #expect(firstSilence == secondSilence)
        #expect(firstSilence.fingerprint == secondSilence.fingerprint)
        #expect(firstSilence.finite)
        #expect(firstSilence.rms == 0)
        #expect(firstSilence.crestFactor == 0)
        #expect(firstSilence.highBandEnergyRatio == 0)
        #expect(firstSilence.aliasBandEnergyRatio == 0)
        #expect(firstSilence.detuneMotionDepth == 0)
        #expect(firstSilence.detuneMotionPeriodSeconds == 0)
        #expect(firstSilence.stereoCorrelation == 1)

        let tone = sine(frequency: 440, sampleRate: 8_000, seconds: 0.5)
        let evidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: tone,
            right: tone,
            sampleRate: 8_000,
            protectedMono: tone
        ))
        #expect(evidence.finite)
        #expect(evidence.rms > 0)
        #expect(abs(evidence.crestFactor - sqrt(2)) < 0.05)
        #expect(evidence.stereoWidthRatio == 0)
        #expect(abs(evidence.monoLossDB) < 0.000_001)
        #expect(evidence.stereoCorrelation > 0.999)
        #expect(evidence.maskingOverlap > 0.99)
    }

    @Test("Noise exposes more high and alias-band energy than a low sine")
    func noiseSpectrum() {
        let tone = sine(frequency: 220, sampleRate: 8_000, seconds: 0.5)
        let noise = deterministicNoise(count: tone.count)
        let toneEvidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: tone, right: tone, sampleRate: 8_000
        ))
        let noiseEvidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: noise, right: noise, sampleRate: 8_000
        ))
        #expect(noiseEvidence.highBandEnergyRatio > toneEvidence.highBandEnergyRatio + 0.20)
        #expect(noiseEvidence.aliasBandEnergyRatio > toneEvidence.aliasBandEnergyRatio + 0.10)
        #expect(noiseEvidence.crestFactor > 1)
    }

    @Test("Impulse, DC, clipping, and near-Nyquist fixtures remain distinguishable")
    func pathologicalSignalFixtures() {
        let sampleRate = 8_000.0
        var impulse = [Float](repeating: 0, count: 2_048)
        impulse[1_024] = 1
        let dc = [Float](repeating: 0.25, count: impulse.count)
        let sineWave = sine(frequency: 440, sampleRate: sampleRate, seconds: 0.256)
        let clipped = sineWave.map { min(0.22, max(-0.22, $0)) }
        let nearNyquist = sine(frequency: 3_600, sampleRate: sampleRate, seconds: 0.256)

        func analyze(_ signal: [Float]) -> UpperTimbreEvidence {
            UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
                left: signal,
                right: signal,
                sampleRate: sampleRate
            ))
        }

        let impulseEvidence = analyze(impulse)
        let dcEvidence = analyze(dc)
        let sineEvidence = analyze(sineWave)
        let clippedEvidence = analyze(clipped)
        let aliasEvidence = analyze(nearNyquist)

        #expect(impulseEvidence.finite)
        #expect(impulseEvidence.crestFactor > 20)
        #expect(dcEvidence.finite)
        #expect(abs(dcEvidence.rms - 0.25) < 0.000_001)
        #expect(abs(dcEvidence.crestFactor - 1) < 0.000_001)
        #expect(dcEvidence.highBandEnergyRatio < 0.001)
        #expect(clippedEvidence.finite)
        #expect(clippedEvidence.crestFactor < sineEvidence.crestFactor)
        #expect(clippedEvidence.highBandEnergyRatio > sineEvidence.highBandEnergyRatio)
        #expect(aliasEvidence.aliasBandEnergyRatio > 0.90)
    }

    @Test("Opposite-polarity stereo reports width and mono loss")
    func phaseCancellation() {
        let left = sine(frequency: 330, sampleRate: 8_000, seconds: 0.5)
        let right = left.map { -$0 }
        let evidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: left,
            right: right,
            sampleRate: 8_000
        ))
        #expect(evidence.finite)
        #expect(evidence.stereoCorrelation < -0.999)
        #expect(evidence.stereoWidthRatio == 120)
        #expect(evidence.monoLossDB <= -100)
    }

    @Test("Accent and slide inputs remain explicit and detect duplicate attacks")
    func accentAndSlideInputs() {
        let sampleRate = 8_000.0
        var signal = [Float](repeating: 0, count: 1_600)
        for index in 100..<180 {
            signal[index] += Float(exp(-Double(index - 100) / 18.0))
        }
        for index in 600..<680 {
            signal[index] += Float(exp(-Double(index - 600) / 18.0) * 0.25)
        }
        var phase = 0.0
        for index in 1_000..<1_400 {
            let progress = Double(index - 1_000) / 400
            let frequency = 180 + progress * 120
            phase += 2 * Double.pi * frequency / sampleRate
            signal[index] += Float(sin(phase) * 0.10)
        }
        let evidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: signal,
            right: signal,
            sampleRate: sampleRate,
            accentedOnsetFrames: [100],
            unaccentedOnsetFrames: [600],
            slideWindows: [UpperTimbreSlideWindow(startFrame: 1_000, endFrame: 1_400)],
            detectedAttackFrames: [1_000, 1_120, 1_500],
            precedingFrame: UpperTimbreStereoFrame(left: 0.5, right: 0.5),
            followingFrame: UpperTimbreStereoFrame(left: -0.25, right: -0.25)
        ))
        #expect(evidence.accentedOnsetCount == 1)
        #expect(evidence.unaccentedOnsetCount == 1)
        #expect(evidence.accentContrastDB > 8)
        #expect(evidence.slideWindowCount == 1)
        #expect(evidence.duplicateAttackCount == 1)
        #expect(evidence.slideMaximumDelta > 0)
        #expect(abs(evidence.maximumBoundaryDelta - 0.5) < 0.000_001)
    }

    @Test("Amplitude modulation exposes bounded detune-motion depth and period")
    func detuneMotion() {
        let sampleRate = 8_000.0
        let count = Int(sampleRate * 2)
        let signal: [Float] = (0..<count).map { index in
            let time = Double(index) / sampleRate
            let amplitude = 0.65 + 0.30 * sin(2 * Double.pi * 4 * time)
            return Float(sin(2 * Double.pi * 220 * time) * amplitude)
        }
        let evidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: signal,
            right: signal,
            sampleRate: sampleRate
        ))
        #expect(evidence.detuneMotionDepth > 0.30)
        #expect((0.20...0.30).contains(evidence.detuneMotionPeriodSeconds))
    }

    @Test("Phrase aggregation is weighted, count-preserving, and hard-bounded")
    func boundedAggregation() {
        let sampleRate = 8_000.0
        var short = sine(frequency: 220, sampleRate: sampleRate, seconds: 0.1)
        let long = sine(frequency: 220, sampleRate: sampleRate, seconds: 0.2).map { $0 * 0.5 }
        for index in 10..<40 { short[index] += 0.5 }
        let shortEvidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: short,
            right: short,
            sampleRate: sampleRate,
            accentedOnsetFrames: [10],
            unaccentedOnsetFrames: [400],
            slideWindows: [UpperTimbreSlideWindow(startFrame: 500, endFrame: 700)],
            detectedAttackFrames: [500, 600],
            precedingFrame: UpperTimbreStereoFrame(left: 0.5, right: 0.5)
        ))
        let longEvidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: long,
            right: long,
            sampleRate: sampleRate,
            accentedOnsetFrames: [10, 20],
            unaccentedOnsetFrames: [800],
            slideWindows: [UpperTimbreSlideWindow(startFrame: 900, endFrame: 1_200)],
            detectedAttackFrames: [900, 1_000]
        ))
        let aggregate = UpperTimbreEvidence.aggregating([shortEvidence, longEvidence])
        let totalFrames = shortEvidence.analyzedFrameCount + longEvidence.analyzedFrameCount
        let expectedRMS = (
            shortEvidence.rms * Double(shortEvidence.analyzedFrameCount) +
                longEvidence.rms * Double(longEvidence.analyzedFrameCount)
        ) / Double(totalFrames)
        #expect(aggregate.finite)
        #expect(aggregate.analyzedFrameCount == totalFrames)
        #expect(abs(aggregate.rms - expectedRMS) < 0.000_000_001)
        #expect(aggregate.accentedOnsetCount == 3)
        #expect(aggregate.unaccentedOnsetCount == 2)
        #expect(aggregate.slideWindowCount == 2)
        #expect(aggregate.duplicateAttackCount == 2)
        #expect(aggregate.slideMaximumDelta == max(
            shortEvidence.slideMaximumDelta,
            longEvidence.slideMaximumDelta
        ))
        #expect(aggregate.maximumBoundaryDelta == max(
            shortEvidence.maximumBoundaryDelta,
            longEvidence.maximumBoundaryDelta
        ))

        let overBound = UpperTimbreEvidence.aggregating(Array(
            repeating: shortEvidence,
            count: UpperTimbreEvidenceAnalyzer.maximumEvidenceWindows + 1
        ))
        #expect(!overBound.finite)
        #expect(overBound.analyzedFrameCount ==
                shortEvidence.analyzedFrameCount * UpperTimbreEvidenceAnalyzer.maximumEvidenceWindows)
        #expect(!UpperTimbreEvidence.aggregating([]).finite)
    }

    @Test("Canonical bar evidence remains complete through 192 kHz")
    func productionRateWindowCompleteness() {
        for sampleRate in [44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            let frameCount = Int((240 / 130 * sampleRate).rounded())
            let silence = [Float](repeating: 0, count: frameCount)
            let evidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                    left: silence,
                    right: silence,
                    sampleRate: sampleRate,
                    precedingFrame: UpperTimbreStereoFrame(left: 0, right: 0)
                )
            )
            #expect(evidence.finite)
            #expect(evidence.analyzedFrameCount == frameCount)
            #expect(evidence.sampleRate == sampleRate)
        }
    }

    @Test("Analyzer bounds input, sanitizes non-finite samples, and reports unavailable JSON")
    func boundedAndSerializable() throws {
        var left = [Float](repeating: 0, count: UpperTimbreEvidenceAnalyzer.maximumFrames + 1_000)
        let right = left
        left[0] = .nan
        left[1] = .infinity
        let evidence = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: left,
            right: right,
            sampleRate: 48_000
        ))
        #expect(evidence.analyzedFrameCount == UpperTimbreEvidenceAnalyzer.maximumFrames)
        #expect(!evidence.finite)
        #expect(allScalarsAreFinite(evidence))

        let report = try CanonicalJourneyQualificationReport(
            engineVersion: "engine-test",
            fixtureFingerprint: "fixture-test",
            continuationFingerprint: "continuation-test",
            checkpoint: .chapterChange,
            routeFingerprint: "route-test",
            routeGeneration: 2,
            evidence: evidence,
            sampleHash: "sample-test"
        )
        let first = try report.deterministicJSON()
        let second = try report.deterministicJSON()
        #expect(first == second)
        #expect(report.decision.outcome == .qualificationUnavailable)
        #expect(report.reasonCodes.contains(.policyUncalibratedV1))
        #expect(report.reasonCodes.contains(.evidenceNonFiniteV1))
        #expect(report.reasonCodes.contains(.hardGateFailedV1))
        #expect(report.evidenceFingerprint == evidence.fingerprint)
        let decoded = try JSONDecoder().decode(
            CanonicalJourneyQualificationReport.self,
            from: first
        )
        #expect(decoded == report)
        #expect(report.evidenceScope ==
                CanonicalJourneyQualificationReport.currentEvidenceScope)

        let finiteEvidence = UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(
                left: [Float](repeating: 0, count: 64),
                right: [Float](repeating: 0, count: 64),
                sampleRate: 48_000
            )
        )
        let normalizedEmptyPolicyDecision = QualityDecision(
            policyVersion: "",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1],
            candidateFingerprint: "sample-empty-policy",
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                policyVersion: "",
                fixtureFingerprint: "fixture-empty-policy",
                continuationFingerprint: "continuation-empty-policy",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "sample-empty-policy",
                decision: normalizedEmptyPolicyDecision
            )
            Issue.record("Expected an empty policy identity to be rejected")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .emptyIdentity)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let evaluatorUnavailable = QualityDecision.qualificationUnavailable(
            policyVersion: "test-calibrated-policy.v1",
            candidateFingerprint: "candidate-evaluator-unavailable",
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        let evaluatorUnavailableState = QualityContinuationState().recording(
            decision: evaluatorUnavailable,
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        do {
            let report = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                policyVersion: "test-calibrated-policy.v1",
                fixtureFingerprint: "fixture-evaluator-unavailable",
                continuationFingerprint: "continuation-evaluator-unavailable",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "candidate-evaluator-unavailable",
                decision: evaluatorUnavailable,
                outgoingState: evaluatorUnavailableState
            )
            #expect(report.reasonCodes.contains(.evaluatorUnavailableV1))
            #expect(!report.reasonCodes.contains(.evidenceMissingV1))
        } catch {
            Issue.record("Expected finite evidence with an unavailable evaluator: \(error)")
        }

        let falseMissingEvidence = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualificationUnavailable,
            reasonCodes: [.evidenceMissingV1],
            candidateFingerprint: "candidate-false-missing",
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        let falseMissingState = QualityContinuationState().recording(
            decision: falseMissingEvidence,
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                policyVersion: "test-calibrated-policy.v1",
                fixtureFingerprint: "fixture-false-missing",
                continuationFingerprint: "continuation-false-missing",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "candidate-false-missing",
                decision: falseMissingEvidence,
                outgoingState: falseMissingState
            )
            Issue.record("Expected a false evidence-missing reason to be rejected")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .reasonCodeMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                policyVersion: "test-calibrated-policy.v1",
                fixtureFingerprint: "fixture-calibrated",
                continuationFingerprint: "continuation-calibrated",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "sample-calibrated"
            )
            Issue.record("Expected a calibrated report to require an evaluator decision")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .missingCalibratedDecision)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let candidateMismatchDecision = QualityDecision.qualificationUnavailable(
            candidateFingerprint: "candidate-a",
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        let candidateMismatchOutgoing = QualityContinuationState().recording(
            decision: candidateMismatchDecision,
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                fixtureFingerprint: "fixture-candidate-mismatch",
                continuationFingerprint: "continuation-candidate-mismatch",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "candidate-b",
                decision: candidateMismatchDecision,
                outgoingState: candidateMismatchOutgoing
            )
            Issue.record("Expected decision and sample candidate fingerprints to match")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .candidateFingerprintMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let observedDecision = QualityDecision.qualificationUnavailable(
            candidateFingerprint: "candidate-observed",
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        let inconsistentObservation = QualityContinuationState(
            lastDecision: observedDecision,
            observedCandidateFingerprint: "different-candidate",
            observedEvidenceFingerprint: "different-evidence"
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                fixtureFingerprint: "fixture-observed",
                continuationFingerprint: "continuation-observed",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "candidate-observed",
                decision: observedDecision,
                outgoingState: inconsistentObservation
            )
            Issue.record("Expected outgoing observed identity to match the report")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .outgoingObservationMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let mismatchedDecision = QualityDecision.qualificationUnavailable(
            evidenceFingerprint: "not-the-report-evidence"
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                fixtureFingerprint: "fixture-test",
                continuationFingerprint: "continuation-test",
                checkpoint: .chapterChange,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: evidence,
                sampleHash: "sample-test",
                decision: mismatchedDecision
            )
            Issue.record("Expected an evidence-fingerprint mismatch")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .evidenceFingerprintMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let contradictoryQualification = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1, .hardGateFailedV1],
            candidateFingerprint: "candidate-contradictory",
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        let contradictoryOutgoing = QualityContinuationState(
            lastDecision: contradictoryQualification,
            acceptedPolicyVersion: "test-calibrated-policy.v1",
            acceptedCandidateFingerprint: "candidate-contradictory",
            acceptedEvidenceFingerprint: finiteEvidence.fingerprint,
            acceptedControllerStateFingerprint: "controller-contradictory",
            observedCandidateFingerprint: "candidate-contradictory",
            observedEvidenceFingerprint: finiteEvidence.fingerprint,
            observedControllerStateFingerprint: "controller-contradictory"
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                policyVersion: "test-calibrated-policy.v1",
                fixtureFingerprint: "fixture-contradictory",
                continuationFingerprint: "continuation-contradictory",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "candidate-contradictory",
                decision: contradictoryQualification,
                outgoingState: contradictoryOutgoing
            )
            Issue.record("Expected a hard-gate reason to reject a qualified outcome")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .reasonCodeMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let contradictoryRejection = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .rejected,
            reasonCodes: [.candidateQualifiedV1],
            candidateFingerprint: "candidate-rejected-positive",
            evidenceFingerprint: finiteEvidence.fingerprint
        )
        let contradictoryRejectionState = QualityContinuationState(
            lastDecision: contradictoryRejection,
            observedCandidateFingerprint: "candidate-rejected-positive",
            observedEvidenceFingerprint: finiteEvidence.fingerprint
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                policyVersion: "test-calibrated-policy.v1",
                fixtureFingerprint: "fixture-rejected-positive",
                continuationFingerprint: "continuation-rejected-positive",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: finiteEvidence,
                sampleHash: "candidate-rejected-positive",
                decision: contradictoryRejection,
                outgoingState: contradictoryRejectionState
            )
            Issue.record("Expected rejected and qualified reason codes to conflict")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .reasonCodeMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let emptyEvidence = UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(
                left: [],
                right: [],
                sampleRate: 48_000
            )
        )
        let impossibleEmptyQualification = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1, .evidenceMissingV1, .hardGateFailedV1],
            candidateFingerprint: "candidate-empty",
            evidenceFingerprint: emptyEvidence.fingerprint
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                policyVersion: "test-calibrated-policy.v1",
                fixtureFingerprint: "fixture-empty",
                continuationFingerprint: "continuation-empty",
                checkpoint: .establishment,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: emptyEvidence,
                sampleHash: "candidate-empty",
                decision: impossibleEmptyQualification
            )
            Issue.record("Expected empty evidence to reject a qualified outcome")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .reasonCodeMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        let unreasonedDecision = QualityDecision(
            outcome: .qualificationUnavailable,
            reasonCodes: [],
            candidateFingerprint: "sample-test",
            evidenceFingerprint: evidence.fingerprint
        )
        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                fixtureFingerprint: "fixture-test",
                continuationFingerprint: "continuation-test",
                checkpoint: .chapterChange,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: evidence,
                sampleHash: "sample-test",
                decision: unreasonedDecision
            )
            Issue.record("Expected non-finite evidence to require reason codes")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .reasonCodeMismatch)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }

        do {
            _ = try CanonicalJourneyQualificationReport(
                engineVersion: "engine-test",
                fixtureFingerprint: "fixture-test",
                continuationFingerprint: "continuation-test",
                checkpoint: .chapterChange,
                routeFingerprint: "route-test",
                routeGeneration: 2,
                evidence: evidence,
                sampleHash: "sample-test",
                correctionRenderCount:
                    QualityQualificationContract.maximumCorrectionRenders + 1
            )
            Issue.record("Expected an out-of-bounds correction count")
        } catch let error as CanonicalJourneyQualificationReportError {
            #expect(error == .invalidBounds)
        } catch {
            Issue.record("Unexpected report validation error: \(error)")
        }
    }

    private func sine(frequency: Double, sampleRate: Double, seconds: Double) -> [Float] {
        (0..<Int(sampleRate * seconds)).map { index in
            Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate) * 0.5)
        }
    }

    private func deterministicNoise(count: Int) -> [Float] {
        var state: UInt64 = 0xD1CE_BA5E
        return (0..<count).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let normalized = Double((state >> 32) & 0xffff_ffff) / Double(UInt32.max)
            return Float((normalized * 2 - 1) * 0.5)
        }
    }

    private func deterministicJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private func allScalarsAreFinite(_ evidence: UpperTimbreEvidence) -> Bool {
        [
            evidence.sampleRate,
            evidence.rms,
            evidence.crestFactor,
            evidence.filterContourRise,
            evidence.filterContourDecay,
            evidence.accentContrastDB,
            evidence.slideMaximumDelta,
            evidence.detuneMotionDepth,
            evidence.detuneMotionPeriodSeconds,
            evidence.highBandEnergyRatio,
            evidence.aliasBandEnergyRatio,
            evidence.stereoWidthRatio,
            evidence.monoLossDB,
            evidence.stereoCorrelation,
            evidence.maskingOverlap,
            evidence.maximumBoundaryDelta,
        ].allSatisfy(\.isFinite)
    }
}
