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
        #expect(QualityContinuationState().isStructurallyValid)
        let forgedPristineHistory = QualityContinuationState(
            acceptedPolicyVersion: "test-policy.v1",
            acceptedCandidateFingerprint: "candidate-before-revision-zero",
            acceptedEvidenceFingerprint: "evidence-before-revision-zero",
            acceptedControllerStateFingerprint: "controller-before-revision-zero",
            earliestEligibleFutureSample: 4_096
        )
        #expect(!forgedPristineHistory.isStructurallyValid)
        let forgedPristineObservation = QualityContinuationState(
            observedControllerStateFingerprint: "controller-before-revision-one"
        )
        #expect(!forgedPristineObservation.isStructurallyValid)

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
            protectedReferenceMono: tone
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

    @Test("Professional Evidence v2 bank requires every journey checkpoint and unavailable policy")
    func professionalEvidenceReportBank() throws {
        var reports: [CanonicalJourneyQualificationReport] = []
        for sampleRate in [44_100.0, 48_000.0] {
            let evidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                    left: [Float](repeating: 0, count: 64),
                    right: [Float](repeating: 0, count: 64),
                    sampleRate: sampleRate
                )
            )
            for checkpoint in CanonicalJourneyCheckpoint.allCases {
                let fixture = reportFixture(
                    evidence: evidence,
                    sampleHash: "bank-\(Int(sampleRate))-\(checkpoint.rawValue)",
                    checkpoint: checkpoint
                )
                reports.append(try qualificationReport(
                    fixture: fixture,
                    checkpoint: checkpoint
                ))
            }
        }

        let bank = try ProfessionalEvidenceReportBank(reports: Array(reports.reversed()))
        #expect(bank.schemaVersion == 2)
        #expect(bank.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion)
        #expect(bank.sourceReportCount ==
                CanonicalJourneyCheckpoint.allCases.count * 2)
        #expect(bank.sampleRates == [44_100, 48_000])
        for sampleRate in bank.sampleRates {
            #expect(bank.reports.filter { $0.sampleRate == sampleRate }
                .map(\.checkpoint) == CanonicalJourneyCheckpoint.allCases)
        }
        #expect(bank.policyAvailability ==
                .unavailablePendingCalibratedProfileAndAdversarialSuite)
        #expect(bank.calibrationProfileFingerprint == nil)
        #expect(bank.adversarialSuiteFingerprint == nil)
        #expect(!bank.policyActivationReady)
        #expect(try bank.deterministicJSON() == bank.deterministicJSON())
        #expect(try ProfessionalEvidenceReportBank(reports: reports) == bank)

        #expect(throws: ProfessionalEvidenceReportBankError
            .incompleteJourneyCoverage) {
            try ProfessionalEvidenceReportBank(reports: Array(reports.dropLast()))
        }
        #expect(throws: ProfessionalEvidenceReportBankError.duplicateReport) {
            try ProfessionalEvidenceReportBank(reports: reports + [reports[0]])
        }

        let evidence = UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(
                left: [Float](repeating: 0, count: 64),
                right: [Float](repeating: 0, count: 64),
                sampleRate: 48_000
            )
        )
        var calibratedReports: [CanonicalJourneyQualificationReport] = []
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            let fixture = reportFixture(
                evidence: evidence,
                sampleHash: "calibrated-bank-\(checkpoint.rawValue)",
                policyVersion: "test-calibrated-policy.v1",
                checkpoint: checkpoint
            )
            let decision = QualityDecision.qualificationUnavailable(
                policyVersion: "test-calibrated-policy.v1",
                candidateFingerprint: fixture.vector.fullMix.sampleHash,
                evidenceFingerprint: fixture.transaction.fingerprint
            )
            let outgoing = QualityContinuationState().recording(
                decision: decision,
                evidenceFingerprint: fixture.transaction.fingerprint,
                controllerStateFingerprint:
                    fixture.vector.routeContinuation.controllerStateFingerprint
            )
            calibratedReports.append(try qualificationReport(
                fixture: fixture,
                checkpoint: checkpoint,
                policyVersion: "test-calibrated-policy.v1",
                decision: decision,
                outgoingState: outgoing
            ))
        }
        #expect(throws: ProfessionalEvidenceReportBankError
            .policyMustRemainUnavailable) {
            try ProfessionalEvidenceReportBank(reports: calibratedReports)
        }
    }

    @Test("Candidate transaction reports serialize and reject contradictory provenance")
    func boundedAndSerializable() throws {
        var left = [Float](
            repeating: 0,
            count: UpperTimbreEvidenceAnalyzer.maximumFrames + 1_000
        )
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

        let unavailable = reportFixture(evidence: evidence, sampleHash: "sample-test")
        #expect(unavailable.vector.recordIsStructurallyValid)
        #expect(unavailable.vector.isComplete)
        #expect(!unavailable.vector.isFinite)
        #expect(unavailable.transaction.isComplete)
        #expect(unavailable.transaction.selectedAttemptIndex == 2)
        #expect(unavailable.transaction.attempts[2].vector == unavailable.vector)
        #expect(unavailable.transaction.engineVersion == "engine-test")
        let report = try qualificationReport(fixture: unavailable)
        let first = try report.deterministicJSON()
        let second = try report.deterministicJSON()
        #expect(first == second)
        #expect(try CanonicalJourneyQualificationReport
            .decodeDeterministicJSON(first) == report)
        var noncanonicalBytes = Data(" ".utf8)
        noncanonicalBytes.append(first)
        #expect(throws: CanonicalJourneyQualificationReportError
            .candidateEvaluationMismatch) {
            try CanonicalJourneyQualificationReport
                .decodeDeterministicJSON(noncanonicalBytes)
        }
        let reportJSON = try #require(String(data: first, encoding: .utf8))
        let tamperedScope = Data(reportJSON.replacingOccurrences(
            of: CanonicalJourneyQualificationReport.currentEvidenceScope,
            with: "tampered-evidence-scope.v1"
        ).utf8)
        #expect(throws: CanonicalJourneyQualificationReportError
            .candidateEvaluationMismatch) {
            try CanonicalJourneyQualificationReport
                .decodeDeterministicJSON(tamperedScope)
        }
        #expect(report.decision.outcome == .qualificationUnavailable)
        #expect(report.reasonCodes.contains(.policyUncalibratedV1))
        #expect(report.reasonCodes.contains(.evidenceNonFiniteV1))
        #expect(report.reasonCodes.contains(.hardGateFailedV1))
        #expect(report.evidenceFingerprint == unavailable.transaction.fingerprint)
        #expect(report.selectedCandidateEvidenceFingerprint ==
                unavailable.vector.fingerprint)
        #expect(report.evidence == evidence)
        #expect(report.evidenceScope ==
                CanonicalJourneyQualificationReport.currentEvidenceScope)

        let finiteEvidence = UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(
                left: [Float](repeating: 0, count: 64),
                right: [Float](repeating: 0, count: 64),
                sampleRate: 48_000
            )
        )
        let calibrated = reportFixture(
            evidence: finiteEvidence,
            sampleHash: "candidate-evaluator-unavailable",
            policyVersion: "test-calibrated-policy.v1"
        )
        let evaluatorUnavailable = QualityDecision.qualificationUnavailable(
            policyVersion: "test-calibrated-policy.v1",
            candidateFingerprint: calibrated.vector.fullMix.sampleHash,
            evidenceFingerprint: calibrated.transaction.fingerprint
        )
        let evaluatorUnavailableState = QualityContinuationState().recording(
            decision: evaluatorUnavailable,
            evidenceFingerprint: calibrated.transaction.fingerprint,
            controllerStateFingerprint:
                calibrated.vector.routeContinuation.controllerStateFingerprint
        )
        let calibratedReport = try qualificationReport(
            fixture: calibrated,
            policyVersion: "test-calibrated-policy.v1",
            decision: evaluatorUnavailable,
            outgoingState: evaluatorUnavailableState
        )
        #expect(calibratedReport.reasonCodes.contains(.evaluatorUnavailableV1))
        #expect(!calibratedReport.reasonCodes.contains(.evidenceMissingV1))

        let falseMissingEvidence = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualificationUnavailable,
            reasonCodes: [.evidenceMissingV1],
            candidateFingerprint: calibrated.vector.fullMix.sampleHash,
            evidenceFingerprint: calibrated.transaction.fingerprint
        )
        let falseMissingState = QualityContinuationState().recording(
            decision: falseMissingEvidence,
            evidenceFingerprint: calibrated.transaction.fingerprint,
            controllerStateFingerprint:
                calibrated.vector.routeContinuation.controllerStateFingerprint
        )
        #expect(throws: CanonicalJourneyQualificationReportError.reasonCodeMismatch) {
            try qualificationReport(
                fixture: calibrated,
                policyVersion: "test-calibrated-policy.v1",
                decision: falseMissingEvidence,
                outgoingState: falseMissingState
            )
        }

        #expect(throws: CanonicalJourneyQualificationReportError.missingCalibratedDecision) {
            try qualificationReport(
                fixture: calibrated,
                policyVersion: "test-calibrated-policy.v1"
            )
        }

        let unavailableReasons = [
            QualityReasonCode.policyUncalibratedV1,
            .conservativeFallbackV1,
        ] + unavailable.transaction.attempts[2].reasonCodes
        let candidateMismatch = QualityDecision(
            outcome: .qualificationUnavailable,
            reasonCodes: unavailableReasons,
            candidateFingerprint: "different-candidate",
            evidenceFingerprint: unavailable.transaction.fingerprint
        )
        let candidateMismatchState = QualityContinuationState().recording(
            decision: candidateMismatch,
            evidenceFingerprint: unavailable.transaction.fingerprint,
            controllerStateFingerprint:
                unavailable.vector.routeContinuation.controllerStateFingerprint
        )
        #expect(throws: CanonicalJourneyQualificationReportError.candidateFingerprintMismatch) {
            try qualificationReport(
                fixture: unavailable,
                decision: candidateMismatch,
                outgoingState: candidateMismatchState
            )
        }

        let finiteUnavailable = reportFixture(
            evidence: finiteEvidence,
            sampleHash: "candidate-observed"
        )
        let observedDecision = QualityDecision.qualificationUnavailable(
            candidateFingerprint: finiteUnavailable.vector.fullMix.sampleHash,
            evidenceFingerprint: finiteUnavailable.transaction.fingerprint
        )
        let extraReasonDecision = QualityDecision(
            outcome: .qualificationUnavailable,
            reasonCodes: [.policyUncalibratedV1, .evidenceMismatchV1],
            candidateFingerprint: finiteUnavailable.vector.fullMix.sampleHash,
            evidenceFingerprint: finiteUnavailable.transaction.fingerprint
        )
        let extraReasonState = QualityContinuationState().recording(
            decision: extraReasonDecision,
            evidenceFingerprint: finiteUnavailable.transaction.fingerprint,
            controllerStateFingerprint:
                finiteUnavailable.vector.routeContinuation.controllerStateFingerprint
        )
        #expect(throws: CanonicalJourneyQualificationReportError.reasonCodeMismatch) {
            try qualificationReport(
                fixture: finiteUnavailable,
                decision: extraReasonDecision,
                outgoingState: extraReasonState
            )
        }
        let inconsistentObservation = QualityContinuationState(
            lastDecision: observedDecision,
            observedCandidateFingerprint: "different-candidate",
            observedEvidenceFingerprint: "different-evidence"
        )
        #expect(throws: CanonicalJourneyQualificationReportError.schemaMismatch) {
            try qualificationReport(
                fixture: finiteUnavailable,
                decision: observedDecision,
                outgoingState: inconsistentObservation
            )
        }

        let foreignControllerState = QualityContinuationState().recording(
            decision: observedDecision,
            evidenceFingerprint: finiteUnavailable.transaction.fingerprint,
            controllerStateFingerprint: "foreign-controller"
        )
        #expect(throws: CanonicalJourneyQualificationReportError
            .outgoingObservationMismatch) {
            try qualificationReport(
                fixture: finiteUnavailable,
                decision: observedDecision,
                outgoingState: foreignControllerState
            )
        }

        let mismatchedDecision = QualityDecision(
            outcome: .qualificationUnavailable,
            reasonCodes: unavailableReasons,
            candidateFingerprint: unavailable.vector.fullMix.sampleHash,
            evidenceFingerprint: "not-the-transaction"
        )
        let mismatchedState = QualityContinuationState().recording(
            decision: mismatchedDecision,
            evidenceFingerprint: "not-the-transaction",
            controllerStateFingerprint:
                unavailable.vector.routeContinuation.controllerStateFingerprint
        )
        #expect(throws: CanonicalJourneyQualificationReportError.evidenceFingerprintMismatch) {
            try qualificationReport(
                fixture: unavailable,
                decision: mismatchedDecision,
                outgoingState: mismatchedState
            )
        }

        let contradictoryQualification = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1, .hardGateFailedV1],
            candidateFingerprint: calibrated.vector.fullMix.sampleHash,
            evidenceFingerprint: calibrated.transaction.fingerprint
        )
        let contradictoryOutgoing = QualityContinuationState(
            revision: 1,
            lastDecision: contradictoryQualification,
            acceptedPolicyVersion: "test-calibrated-policy.v1",
            acceptedCandidateFingerprint: calibrated.vector.fullMix.sampleHash,
            acceptedEvidenceFingerprint: calibrated.transaction.fingerprint,
            acceptedControllerStateFingerprint: "controller",
            observedCandidateFingerprint: calibrated.vector.fullMix.sampleHash,
            observedEvidenceFingerprint: calibrated.transaction.fingerprint,
            observedControllerStateFingerprint: "controller"
        )
        #expect(throws: CanonicalJourneyQualificationReportError.reasonCodeMismatch) {
            try qualificationReport(
                fixture: calibrated,
                policyVersion: "test-calibrated-policy.v1",
                decision: contradictoryQualification,
                outgoingState: contradictoryOutgoing
            )
        }

        let emptyEvidence = UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(left: [], right: [], sampleRate: 48_000)
        )
        let empty = reportFixture(
            evidence: emptyEvidence,
            sampleHash: "candidate-empty",
            policyVersion: "test-calibrated-policy.v1"
        )
        let impossibleEmptyQualification = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1, .evidenceMissingV1, .hardGateFailedV1],
            candidateFingerprint: empty.vector.fullMix.sampleHash,
            evidenceFingerprint: empty.transaction.fingerprint
        )
        #expect(throws: CanonicalJourneyQualificationReportError.reasonCodeMismatch) {
            try qualificationReport(
                fixture: empty,
                policyVersion: "test-calibrated-policy.v1",
                decision: impossibleEmptyQualification
            )
        }

        let unreasonedDecision = QualityDecision(
            outcome: .qualificationUnavailable,
            reasonCodes: [],
            candidateFingerprint: unavailable.vector.fullMix.sampleHash,
            evidenceFingerprint: unavailable.transaction.fingerprint
        )
        #expect(throws: CanonicalJourneyQualificationReportError.reasonCodeMismatch) {
            try qualificationReport(fixture: unavailable, decision: unreasonedDecision)
        }

        #expect(throws: CanonicalJourneyQualificationReportError.invalidBounds) {
            try qualificationReport(
                fixture: unavailable,
                correctionRenderCount:
                    QualityQualificationContract.maximumCorrectionRenders + 1
            )
        }
        #expect(throws: CanonicalJourneyQualificationReportError.routeMismatch) {
            try qualificationReport(
                fixture: unavailable,
                routeFingerprint: "different-route"
            )
        }
    }

    private typealias ReportFixture = (
        vector: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    )

    private func qualificationReport(
        fixture: ReportFixture,
        checkpoint: CanonicalJourneyCheckpoint? = nil,
        policyVersion: String = QualityQualificationContract.uncalibratedPolicyVersion,
        routeFingerprint: String? = nil,
        decision: QualityDecision? = nil,
        outgoingState: QualityContinuationState? = nil,
        correctionRenderCount: Int = 0
    ) throws -> CanonicalJourneyQualificationReport {
        try CanonicalJourneyQualificationReport(
            engineVersion: fixture.transaction.engineVersion,
            policyVersion: policyVersion,
            fixtureFingerprint: "fixture-test",
            continuationFingerprint: "continuation-test",
            checkpoint: checkpoint ?? (
                fixture.vector.slot == .fallback ? .identityReturn : .establishment
            ),
            routeFingerprint: routeFingerprint ??
                fixture.vector.routeContinuation.routeFingerprint,
            routeGeneration: fixture.vector.routeContinuation.routeGeneration,
            selectedCandidateEvidence: fixture.vector,
            candidateEvaluation: fixture.transaction,
            sampleHash: fixture.vector.fullMix.sampleHash,
            decision: decision,
            outgoingState: outgoingState,
            usedAlternate: fixture.transaction.selectedSlot == .alternate,
            usedFallback: fixture.transaction.selectedSlot == .fallback,
            usedHomeTimbreFallback: fixture.transaction.selectedAttemptIndex.map {
                fixture.transaction.attempts[$0].forceHomeUpperTimbre
            } ?? false,
            correctionRenderCount: correctionRenderCount
        )
    }

    private func reportFixture(
        evidence: UpperTimbreEvidence,
        sampleHash: String,
        policyVersion: String = QualityQualificationContract.uncalibratedPolicyVersion,
        checkpoint: CanonicalJourneyCheckpoint = .establishment
    ) -> ReportFixture {
        let planFingerprint = "plan-primary-\(checkpoint.rawValue)"
        let graphFingerprint = "graph-primary"
        let phraseIndex = checkpoint == .longContinuation ? 16 :
            (checkpoint == .establishment ? 0 : 1)
        let phraseKind: AutonomousPhraseKind
        switch checkpoint {
        case .contrast: phraseKind = .contrast
        case .majorBreak: phraseKind = .majorBreak
        case .release: phraseKind = .energyRelease
        case .identityReturn: phraseKind = .identityReturn
        case .establishment, .chapterChange, .longContinuation:
            phraseKind = .lock
        }
        let interest = PhraseInterestReport(
            pulseClarity: 0.8,
            intentionalSpace: 0.7,
            responseClosure: 0.6,
            structuralTimeliness: 0.9,
            identityContinuity: 1,
            weakPositionCoverage: 0.5,
            trailingSideRelationship: 0.4,
            overactivityPenalty: 0.1,
            overdueDebtCount: 0
        )
        let symbolic = AutonomousSymbolicEvidence(
            planFingerprint: planFingerprint,
            phraseIndex: phraseIndex,
            startBar: 0,
            declaredBarCount: 1,
            resolvedBarCount: 1,
            phraseKind: phraseKind.rawValue,
            pulseClarity: 0.8,
            intentionalSpace: 0.7,
            responseClosure: 0.6,
            structuralTimeliness: 0.9,
            identityContinuity: 1,
            weakPositionCoverage: 0.5,
            trailingSideRelationship: 0.4,
            overactivityPenalty: 0.1,
            overdueDebtCount: 0,
            interestScore: interest.score,
            interestValid: interest.valid,
            chapterChanged: checkpoint == .chapterChange,
            alternate: false,
            conservative: false,
            boundsValid: true
        )
        let hardGates = AutonomousHardGateEvidence(
            symbolicValid: true,
            graphValid: true,
            audioSafetyValid: evidence.finite,
            fullMixFinite: true,
            upperTimbreFinite: evidence.finite,
            blocksPresent: true,
            blockChannelsAligned: true,
            allSamplesFinite: true,
            completeInputs: true
        )
        let fullMix = AutonomousFullMixEvidence(
            sourceBarCount: 1,
            analyzedFrameCount: evidence.analyzedFrameCount,
            sampleHash: sampleHash,
            peak: 0.5,
            truePeakEstimate: 0.55,
            rms: 0.2,
            loudnessEstimate: -0.691 + 20 * log10(0.2),
            maximumMomentaryLoudness: -0.691 + 20 * log10(0.2),
            maximumShortTermLoudness: -0.691 + 20 * log10(0.2),
            loudnessRange: 0,
            momentaryBlockCount: 1,
            absoluteGatedBlockCount: 1,
            relativeGatedBlockCount: 1,
            shortTermBlockCount: 0,
            dcOffset: 0,
            stereoCorrelation: 1,
            lowStereoCorrelation: evidence.finite ? 1 : 0.9,
            maximumBoundaryDelta: 0.01,
            movementScore: 0,
            bars: [AutonomousBarFullMixEvidence(
                bar: 0,
                loudness: -14,
                spectralCentroid: 800,
                transientDensity: 1.5,
                crestFactor: 5,
                finite: true
            )]
        )
        let masking = validReportMaskingObservations
        let stems = MixRole.allCases.map { role in
            AutonomousRoleStemEvidence(
                role: role.rawValue,
                rms: 0.1,
                activeRMS: 0.2,
                onsetRMS: 0.3,
                peak: 0.5,
                crestFactor: 5,
                occupancy: 0.25,
                bands: MixBand.allCases.map {
                    AutonomousStemBandEvidence(band: $0.rawValue, energy: 0.1)
                }
            )
        }
        let graph = AutonomousGraphEvidence(
            graphFingerprint: graphFingerprint,
            revision: 0,
            nodeCount: 4,
            branchCount: 2,
            maximumDepth: 2,
            lowEndProtected: true,
            protectedRoutingValid: true,
            validationValid: true,
            sourceViolationCount: 0,
            violations: [],
            mutationKind: nil,
            mutatedNodeCount: 0
        )
        let route = AutonomousRouteContinuationEvidence(
            sampleRate: evidence.sampleRate,
            routeGeneration: 2,
            routeFingerprint: AutonomousCandidateFingerprint.route(
                sampleRate: evidence.sampleRate,
                generation: 2
            ),
            incomingContinuationFingerprint: "incoming",
            incomingQualityStateFingerprint:
                AutonomousCandidateFingerprint.qualityState(
                    QualityContinuationState()
                ),
            incomingKickCorrectionDB: AutomaticMixBalancer.homeKickCorrectionDB,
            incomingTopologyRevision: 0,
            previousGraphFingerprint: "none",
            routeRecovery: false,
            outgoingRenderDSPFingerprint: "outgoing-render-dsp",
            controllerStateFingerprint:
                AutonomousCandidateFingerprint.automaticMixController(
                    kickCorrectionDB: AutomaticMixBalancer.homeKickCorrectionDB
                )
        )
        let vector = AutonomousCandidateEvaluationVector(
            slot: .primary,
            planFingerprint: planFingerprint,
            graphFingerprint: graphFingerprint,
            symbolic: symbolic,
            hardGates: hardGates,
            fullMix: fullMix,
            masking: [AutonomousMaskingBarEvidence(
                bar: 0,
                sourceObservationCount: 12,
                observations: masking
            )],
            stems: [AutonomousStemBarEvidence(
                bar: 0,
                sourceRoleCount: 5,
                roles: stems
            )],
            automaticMix: [AutonomousAutomaticMixEvidence(
                bar: 0,
                section: SectionKind.breakdown.rawValue,
                foundationCompanion: FoundationCompanion.bass.rawValue,
                gains: MixRole.allCases.map {
                    AutonomousRoleGainEvidence(
                        role: $0.rawValue,
                        gainDB: $0 == .kick
                            ? AutomaticMixBalancer.homeKickCorrectionDB : 0
                    )
                },
                measuredKickOverFoundationDB: nil,
                targetKickOverFoundationDB: nil
            )],
            groovePulse: [AutonomousGroovePulseBarEvidence(
                bar: 0,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                events: []
            )],
            graph: graph,
            routeContinuation: route,
            preGraphUpperTimbreEvidence: evidence,
            postGraphUpperTimbreEvidence: evidence
        )
        func remappedVector(
            _ source: AutonomousCandidateEvaluationVector,
            slot: AutonomousCandidateSlot,
            planFingerprint: String,
            phraseKind: AutonomousPhraseKind,
            alternate: Bool,
            conservative: Bool
        ) -> AutonomousCandidateEvaluationVector {
            let sourceSymbolic = source.symbolic
            let remappedSymbolic = AutonomousSymbolicEvidence(
                planFingerprint: planFingerprint,
                phraseIndex: sourceSymbolic.phraseIndex,
                startBar: sourceSymbolic.startBar,
                declaredBarCount: sourceSymbolic.declaredBarCount,
                resolvedBarCount: sourceSymbolic.resolvedBarCount,
                phraseKind: phraseKind.rawValue,
                pulseClarity: sourceSymbolic.pulseClarity,
                intentionalSpace: sourceSymbolic.intentionalSpace,
                responseClosure: sourceSymbolic.responseClosure,
                structuralTimeliness: sourceSymbolic.structuralTimeliness,
                identityContinuity: sourceSymbolic.identityContinuity,
                weakPositionCoverage: sourceSymbolic.weakPositionCoverage,
                trailingSideRelationship: sourceSymbolic.trailingSideRelationship,
                overactivityPenalty: sourceSymbolic.overactivityPenalty,
                overdueDebtCount: sourceSymbolic.overdueDebtCount,
                interestScore: sourceSymbolic.interestScore,
                interestValid: sourceSymbolic.interestValid,
                chapterChanged: sourceSymbolic.chapterChanged,
                alternate: alternate,
                conservative: conservative,
                boundsValid: sourceSymbolic.boundsValid
            )
            return AutonomousCandidateEvaluationVector(
                slot: slot,
                planFingerprint: planFingerprint,
                graphFingerprint: source.graphFingerprint,
                symbolic: remappedSymbolic,
                hardGates: source.hardGates,
                fullMix: source.fullMix,
                masking: source.masking,
                stems: source.stems,
                automaticMix: source.automaticMix,
                groovePulse: source.groovePulse,
                graph: source.graph,
                routeContinuation: source.routeContinuation,
                preGraphUpperTimbreEvidence: source.preGraphUpperTimbreEvidence,
                postGraphUpperTimbreEvidence: source.postGraphUpperTimbreEvidence
            )
        }
        func attemptReasons(for candidate: AutonomousCandidateEvaluationVector)
            -> [QualityReasonCode] {
            var reasons: [QualityReasonCode] = []
            if !candidate.isComplete { reasons.append(.evidenceMissingV1) }
            if !candidate.isFinite { reasons.append(.evidenceNonFiniteV1) }
            if !candidate.hardGatesPassed { reasons.append(.hardGateFailedV1) }
            return reasons
        }
        let primaryAttempt = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: attemptReasons(for: vector),
            vector: vector
        )
        let plans = AutonomousCandidatePlanFingerprints(
            primary: planFingerprint,
            alternate: "plan-alternate",
            fallback: "plan-fallback"
        )
        let attempts: [AutonomousCandidateAttempt]
        let selectedVector: AutonomousCandidateEvaluationVector
        let selectedAttemptIndex: Int
        let selectedSlot: AutonomousCandidateSlot
        if vector.selectionEvidence.safetyValid {
            attempts = [primaryAttempt]
            selectedVector = vector
            selectedAttemptIndex = 0
            selectedSlot = .primary
        } else {
            let alternate = remappedVector(
                vector,
                slot: .alternate,
                planFingerprint: plans.alternate,
                phraseKind: .lock,
                alternate: true,
                conservative: false
            )
            let fallback = remappedVector(
                vector,
                slot: .fallback,
                planFingerprint: plans.fallback,
                phraseKind: .identityReturn,
                alternate: false,
                conservative: true
            )
            attempts = [
                primaryAttempt,
                AutonomousCandidateAttempt(
                    kind: .initialRender,
                    reasonCodes: attemptReasons(for: alternate),
                    vector: alternate
                ),
                AutonomousCandidateAttempt(
                    kind: .initialRender,
                    forceSafeGraph: true,
                    reasonCodes: attemptReasons(for: fallback),
                    vector: fallback
                ),
            ]
            selectedVector = fallback
            selectedAttemptIndex = 2
            selectedSlot = .fallback
        }
        let transaction = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine-test",
            policyVersion: policyVersion,
            evaluatorVersion: policyVersion ==
                QualityQualificationContract.uncalibratedPolicyVersion
                ? QualityQualificationContract.uncalibratedEvaluatorVersion
                : "evaluator-test",
            planFingerprints: plans,
            attempts: attempts,
            selectedAttemptIndex: selectedAttemptIndex,
            selectedSlot: selectedSlot,
            comparison: .unavailable,
            correctionCount: 0
        )
        return (selectedVector, transaction)
    }

    private var validReportMaskingObservations:
        [AutonomousMaskingObservationEvidence] {
        let bands: [(String, Double, Double)] = [
            ("sub", 35, 120),
            ("low-mid", 120, 420),
            ("mid", 420, 2_400),
            ("high", 2_400, 10_000),
        ]
        let pairs: [(MaskingRole, MaskingRole)] = [
            (.foundation, .percussion),
            (.foundation, .upper),
            (.percussion, .upper),
        ]
        return pairs.flatMap { first, second in
            bands.map { name, lower, upper in
                AutonomousMaskingObservationEvidence(
                    bandName: name,
                    lowerHz: lower,
                    upperHz: upper,
                    firstRole: first.rawValue,
                    secondRole: second.rawValue,
                    analyzedWindowCount: SpectrumMaskingAnalyzer.analyzedWindowCount,
                    activePairWindowCount: 0,
                    overlapWindowCount: 0,
                    longestOverlapRun: 0,
                    maximumOverlap: 0
                )
            }
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
