import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Versioned quality qualification foundation")
struct QualityQualificationFoundationTests {
    @Test("Canonical checkpoint mapping is ordered, multi-valued, and may be empty")
    func canonicalCheckpointMapping() {
        #expect(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: 0,
            phraseKind: .lock,
            chapterChanged: false
        ) == [.establishment])
        #expect(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: 16,
            phraseKind: .energyRelease,
            chapterChanged: true
        ) == [.chapterChange, .release, .longContinuation])
        #expect(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: 4,
            phraseKind: .identityReturn,
            chapterChanged: false
        ) == [.identityReturn])
        #expect(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: 5,
            phraseKind: .lock,
            chapterChanged: false
        ).isEmpty)
        #expect(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: -1,
            phraseKind: .contrast,
            chapterChanged: true
        ).isEmpty)
    }

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
        let rejectedWithoutReason = QualityDecision(
            policyVersion: "test-policy.v1",
            outcome: .rejected,
            reasonCodes: []
        )
        #expect(!missingQualifiedReason.hasOutcomeConsistentReasonCodes)
        #expect(!adjustedWithQualifiedReason.hasOutcomeConsistentReasonCodes)
        #expect(!rejectedWithoutReason.hasOutcomeConsistentReasonCodes)
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

    @Test("Professional Evidence v17 bank requires every journey checkpoint and unavailable policy")
    func professionalEvidenceReportBank() throws {
        let reports = try qualificationReports()

        let bank = try ProfessionalEvidenceReportBank(reports: Array(reports.reversed()))
        #expect(bank.schemaVersion == ProfessionalEvidenceReportBank.schemaVersion)
        #expect(bank.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion)
        #expect(bank.sourceReportCount ==
                CanonicalJourneyCheckpoint.allCases.count * 2)
        #expect(bank.sampleRates == [44_100, 48_000])
        for sampleRate in bank.sampleRates {
            #expect(bank.reports.filter { $0.sampleRate == sampleRate }
                .map(\.checkpoint) == CanonicalJourneyCheckpoint.allCases)
        }
        for report in bank.reports {
            #expect(report.liveMaster.controllerPolicyVersion ==
                    LiveFeedbackContract.controllerPolicyVersion)
            #expect(report.liveMaster.incomingStateFingerprint ==
                    report.selectedCandidateEvidence
                        .incomingLiveMasterStateFingerprint)
            #expect(report.liveMaster.outgoingStateFingerprint ==
                    report.selectedCandidateEvidence
                        .outgoingLiveMasterStateFingerprint)
            #expect(report.liveMaster.routeGeneration == report.routeGeneration)
            #expect(report.liveMaster.terminalScaleIsValid)
            #expect(report.liveMaster.routeAndBoundaryAreValid)
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

        let bankFrameCount = StreamingPerceptualEvidenceAnalyzer.fftFrameCount(
            sampleRate: 48_000
        )
        let evidence = UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(
                left: [Float](repeating: 0, count: bankFrameCount),
                right: [Float](repeating: 0, count: bankFrameCount),
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

    @Test("Calibration cache rejects swapped seed and unbounded banks")
    func calibrationCacheRejectsSwappedOrUnboundedBanks() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "auto-techno-calibration-cache-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: directory) }

        let cacheHarness = ProfessionalQualityCalibrationIntegrationTests()
        let sourceSeed: UInt64 = 7
        let targetSeed: UInt64 = 13
        let reports = try qualificationReports(rootSeed: sourceSeed)
        try cacheHarness.cache(
            reports: reports,
            seed: sourceSeed,
            directory: directory
        )
        let sourceURL = cacheHarness.cacheURL(
            seed: sourceSeed,
            directory: directory
        )
        let targetURL = cacheHarness.cacheURL(
            seed: targetSeed,
            directory: directory
        )
        let sourceData = try Data(contentsOf: sourceURL)
        let cachedSource = try cacheHarness.cachedTrajectory(
            seed: sourceSeed,
            directory: directory
        )
        let sourceTrajectory = try #require(cachedSource)

        try sourceData.write(to: targetURL, options: .atomic)
        var regenerated = false
        let regeneratedTrajectory = try cacheHarness.resolvedTrajectory(
            seed: targetSeed,
            cacheDirectory: directory
        ) {
            regenerated = true
            return try qualificationReports(rootSeed: targetSeed)
        }
        #expect(regenerated)
        #expect(regeneratedTrajectory != sourceTrajectory)
        #expect(try cacheHarness.cachedTrajectory(
            seed: targetSeed,
            directory: directory
        ) == regeneratedTrajectory)

        var forgedRoot = try #require(
            JSONSerialization.jsonObject(with: sourceData) as? [String: Any]
        )
        var identity = try #require(forgedRoot["identity"] as? [String: Any])
        identity["rootSeed"] = NSNumber(value: targetSeed)
        forgedRoot["identity"] = identity
        let forgedData = try cacheHarness.canonicalCacheJSON(forgedRoot)
        let forgedBank = try JSONDecoder().decode(
            ProfessionalQualityCalibrationIntegrationTests
                .CachedJourneyReportBank.self,
            from: forgedData
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        #expect(try encoder.encode(forgedBank) == forgedData)
        #expect(forgedBank.identity.rootSeed == targetSeed)
        try forgedData.write(to: targetURL, options: .atomic)
        #expect(try cacheHarness.cachedTrajectory(
            seed: targetSeed,
            directory: directory
        ) == nil)

        var oldSchema = forgedRoot
        oldSchema["schemaVersion"] = 1
        try cacheHarness.canonicalCacheJSON(oldSchema)
            .write(to: targetURL, options: .atomic)
        #expect(try cacheHarness.cachedTrajectory(
            seed: targetSeed,
            directory: directory
        ) == nil)

        var excessiveReports = forgedRoot
        var reportJSON = try #require(excessiveReports["reportJSON"] as? [Any])
        reportJSON.append(try #require(reportJSON.first))
        excessiveReports["reportJSON"] = reportJSON
        try cacheHarness.canonicalCacheJSON(excessiveReports)
            .write(to: targetURL, options: .atomic)
        #expect(try cacheHarness.cachedTrajectory(
            seed: targetSeed,
            directory: directory
        ) == nil)

        let oversized = Data(
            repeating: 0x20,
            count: ProfessionalQualityCalibrationIntegrationTests
                .CachedJourneyReportBank.maximumEncodedBytes + 1
        )
        try oversized.write(to: targetURL, options: .atomic)
        #expect(try cacheHarness.cachedTrajectory(
            seed: targetSeed,
            directory: directory
        ) == nil)
    }

    @Test("Professional observation projects active and explicit empty modal evidence")
    func professionalObservationProjectsModalPercussion() throws {
        let sampleRate = 48_000.0
        let frameCount = StreamingPerceptualEvidenceAnalyzer.fftFrameCount(
            sampleRate: sampleRate
        )
        let evidence = UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(
                left: [Float](repeating: 0, count: frameCount),
                right: [Float](repeating: 0, count: frameCount),
                sampleRate: sampleRate
            )
        )
        let activeFixture = reportFixture(
            evidence: evidence,
            sampleHash: "active-modal-observation",
            modalPercussion: [fixtureActiveModalBar(sampleRate: sampleRate)]
        )
        let active = try ProfessionalQualityObservation(
            candidate: activeFixture.vector,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: .establishment
        )
        let expectedLive = try ProfessionalQualityLiveMasterProvenance.home(
            candidate: activeFixture.vector
        )
        #expect(active.liveMaster == expectedLive)
        #expect(active[.modalPercussionActiveBarRatio] == 1)
        #expect(active[.modalPercussionEventCountMean] == 1)
        #expect(active[.modalPercussionPitchErrorCentsMaximum] == 0)
        #expect((active[.modalPercussionAttackToBodyDBMean] ?? 0) > 0)
        #expect((active[.modalPercussionTailToBodyDBMean] ?? 0) < 0)
        #expect(active[.modalPercussionSpectralCentroidMeanHz] == 620)
        #expect(active[.modalPercussionMaskingMaximumOverlap] == 0)
        #expect(active[.modalPercussionMaximumPoleRadius] == 0.998)

        let emptyFixture = reportFixture(
            evidence: evidence,
            sampleHash: "empty-modal-observation"
        )
        let empty = try ProfessionalQualityObservation(
            candidate: emptyFixture.vector,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: .establishment
        )
        for metric in [
            ProfessionalQualityMetric.modalPercussionActiveBarRatio,
            .modalPercussionEventCountMean,
            .modalPercussionPitchErrorCentsMaximum,
            .modalPercussionAttackToBodyDBMean,
            .modalPercussionTailToBodyDBMean,
            .modalPercussionSpectralCentroidMeanHz,
            .modalPercussionMaskingMaximumOverlap,
            .modalPercussionMaximumPoleRadius,
        ] {
            #expect(empty[metric] == 0)
        }
    }

    private typealias ReportFixture = (
        vector: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    )

    private func qualificationReports(
        rootSeed: UInt64? = nil
    ) throws -> [CanonicalJourneyQualificationReport] {
        var reports: [CanonicalJourneyQualificationReport] = []
        for sampleRate in ProfessionalQualityCalibrationProfile
            .requiredSampleRates {
            let frameCount = StreamingPerceptualEvidenceAnalyzer.fftFrameCount(
                sampleRate: sampleRate
            )
            let evidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                    left: [Float](repeating: 0, count: frameCount),
                    right: [Float](repeating: 0, count: frameCount),
                    sampleRate: sampleRate
                )
            )
            for checkpoint in CanonicalJourneyCheckpoint.allCases {
                let fixture = reportFixture(
                    evidence: evidence,
                    sampleHash:
                        "bank-\(Int(sampleRate))-\(checkpoint.rawValue)",
                    checkpoint: checkpoint
                )
                reports.append(try qualificationReport(
                    fixture: fixture,
                    checkpoint: checkpoint,
                    fixtureFingerprint: rootSeed.map {
                        "seed-\($0).fixture-\(Int(sampleRate))-" +
                            checkpoint.rawValue
                    } ?? "fixture-test"
                ))
            }
        }
        return reports
    }

    private func qualificationReport(
        fixture: ReportFixture,
        checkpoint: CanonicalJourneyCheckpoint? = nil,
        fixtureFingerprint: String = "fixture-test",
        policyVersion: String = QualityQualificationContract.uncalibratedPolicyVersion,
        routeFingerprint: String? = nil,
        decision: QualityDecision? = nil,
        outgoingState: QualityContinuationState? = nil,
        correctionRenderCount: Int = 0
    ) throws -> CanonicalJourneyQualificationReport {
        try CanonicalJourneyQualificationReport(
            engineVersion: fixture.transaction.engineVersion,
            policyVersion: policyVersion,
            fixtureFingerprint: fixtureFingerprint,
            continuationFingerprint: "continuation-test",
            checkpoint: checkpoint ?? .establishment,
            routeFingerprint: routeFingerprint ??
                fixture.vector.routeContinuation.routeFingerprint,
            routeGeneration: fixture.vector.routeContinuation.routeGeneration,
            selectedCandidateEvidence: fixture.vector,
            candidateEvaluation: fixture.transaction,
            sampleHash: fixture.vector.fullMix.sampleHash,
            decision: decision,
            outgoingState: outgoingState,
            usedHomeTimbreCorrection: fixture.transaction.selectedAttemptIndex.map {
                fixture.transaction.attempts[$0].forceHomeUpperTimbre
            } ?? false,
            correctionRenderCount: correctionRenderCount
        )
    }

    private func reportFixture(
        evidence: UpperTimbreEvidence,
        sampleHash: String,
        policyVersion: String = QualityQualificationContract.uncalibratedPolicyVersion,
        checkpoint: CanonicalJourneyCheckpoint = .establishment,
        modalPercussion: [AutonomousModalPercussionBarEvidence]? = nil
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
            boundsValid: true
        )
        let hardGates = AutonomousHardGateEvidence(
            symbolicValid: true,
            graphValid: true,
            audioSafetyValid: evidence.finite,
            fullMixFinite: evidence.finite,
            upperTimbreFinite: evidence.finite,
            blocksPresent: true,
            blockChannelsAligned: true,
            allSamplesFinite: evidence.finite,
            completeInputs: true
        )
        let perceptual = fixturePerceptualEvidence(
            frameCount: evidence.analyzedFrameCount,
            sampleRate: evidence.sampleRate,
            finite: evidence.finite
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
            analysisPeakWorkingByteCount:
                perceptual.peakWorkingByteCount + 1,
            perceptual: perceptual,
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
                AutonomousCandidateFingerprint.combinedController(
                    kickCorrectionDB:
                        AutomaticMixBalancer.homeKickCorrectionDB,
                    liveMasterHeadroom:
                        LiveMasterHeadroomContinuationState(),
                    proposalFingerprint: nil
                )
        )
        let liveBlockHash = ExactPCMFingerprint.stereo(
            left: [0.25],
            right: [-0.125]
        )
        let livePhraseHash = AutonomousCandidateEvaluationVector
            .liveMasterPhrasePCMFingerprint([liveBlockHash])
        let foundationRhythm = AutonomousFoundationRhythmBarEvidence(
            bar: 0,
            relation: .established,
            pairPhase: FoundationRhythmicRelationContract.pairPhase(
                absoluteBar: 0
            ),
            scoreBassEventCount: 0,
            scoreBassStepMask: 0,
            renderedBassEventCount: 0,
            renderedBassStepMask: 0,
            renderedFrameCount: Int((
                240.0 / AutonomousSessionDirector.bpm * evidence.sampleRate
            ).rounded()),
            renderedStartFrameFingerprint:
                AutonomousFoundationRhythmBarEvidence
                    .startFrameFingerprint([]),
            dryFoundationSampleHash: "0123456789abcdef",
            peak: 0,
            rms: 0,
            bassPluckAssigned: false,
            renderPassesMatch: true,
            bindingValid: true,
            finite: true
        )
        let kickMorphology = KickMorphologyResolver.articulation(
            sessionSeed: 1,
            absoluteBar: 0
        )
        let vector = AutonomousCandidateEvaluationVector(
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
            kickSyntax: [AutonomousKickSyntaxBarEvidence(
                bar: 0,
                role: .grounded,
                scoreKickEventCount: 1,
                scoreKickStepMask: 1,
                renderedKickEventCount: 1,
                renderedKickStepMask: 1,
                renderedFrameCount: Int((
                    240.0 / AutonomousSessionDirector.bpm * evidence.sampleRate
                ).rounded()),
                audibleGain: KickMixBalance.audibleGain * Double(Float(pow(
                    10,
                    AutomaticMixBalancer.homeKickCorrectionDB / 20
                ))),
                detectorPeak: 0.6,
                detectorRMS: 0.12,
                audiblePeak: 0.5,
                audibleRMS: 0.1,
                duckingEnvelopePeak: 0.4,
                detectorSampleHash: "0123456789abcdef",
                audibleSampleHash: "fedcba9876543210",
                detectorNonzeroSampleCount: 1_024,
                audibleNonzeroSampleCount: 1_024,
                sourceDynamics: AutonomousKickSourceDynamicsEvidence(
                    render: KickSourceDynamicsRenderEvidence(
                        version: KickSourceDynamicsContract.version,
                        antialiasOrder:
                            KickSourceDynamicsContract.antialiasOrder,
                        morphologyVersion: kickMorphology.version,
                        morphologyScoreHash:
                            KickSourceDynamicsContract.morphologyScoreHash(
                                kickMorphology
                            ),
                        morphologyFromHome:
                            kickMorphology.fromHome.rawValue,
                        morphologyToHome: kickMorphology.toHome.rawValue,
                        morphologyStartProgress:
                            kickMorphology.startProgress,
                        morphologyEndProgress: kickMorphology.endProgress,
                        fundamentalStartHz:
                            kickMorphology.start.fundamentalHz,
                        fundamentalEndHz: kickMorphology.end.fundamentalHz,
                        pitchDepthStartHz:
                            kickMorphology.start.pitchDepthHz,
                        pitchDepthEndHz: kickMorphology.end.pitchDepthHz,
                        bodyDecayStartPerSecond:
                            kickMorphology.start.bodyDecayPerSecond,
                        bodyDecayEndPerSecond:
                            kickMorphology.end.bodyDecayPerSecond,
                        clickLevelStart:
                            kickMorphology.start.noiseClickLevel,
                        clickLevelEnd: kickMorphology.end.noiseClickLevel,
                        bodyDriveStart: kickMorphology.start.bodyDrive,
                        bodyDriveEnd: kickMorphology.end.bodyDrive,
                        morphologyBound: true,
                        renderedEventCount: 1,
                        processedSampleCount: 2_560,
                        inputSampleHash: "1111111111111111",
                        outputSampleHash: "2222222222222222",
                        inputPeak: 0.6,
                        inputRMS: 0.12,
                        inputCrestFactor: 5,
                        outputPeak: 0.5,
                        outputRMS: 0.13,
                        outputCrestFactor: 0.5 / 0.13,
                        inputAttackRMS: 0.2,
                        outputAttackRMS: 0.18,
                        inputBodyRMS: 0.1,
                        outputBodyRMS: 0.11,
                        inputUpperMidEnergyRatio: 0.1,
                        outputUpperMidEnergyRatio: 0.12,
                        finite: true
                    )
                ),
                detectorToAudibleScaleMatches: true,
                renderPassesMatch: true,
                bindingValid: true
            )],
            foundationRhythm: [foundationRhythm],
            climaxArc: .inactive(releaseStartBar: 0),
            groovePulse: [AutonomousGroovePulseBarEvidence(
                bar: 0,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                events: []
            )],
            closedHat: [AutonomousClosedHatBarEvidence(
                bar: 0,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                events: []
            )],
            upperPercussionTail: [AutonomousUpperPercussionTailBarEvidence(
                bar: 0,
                focusRole: PerformanceRole.percussion.rawValue,
                intentionalPileup: false,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                renderPassesMatch: true,
                bindingValid: true,
                events: []
            )],
            modalPercussion: modalPercussion ?? [AutonomousModalPercussionBarEvidence(
                bar: 0,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                use: ModalPercussionUse.foundationCompanion.rawValue,
                incomingStateFingerprint: "1111111111111111",
                outgoingStateFingerprint: "1111111111111111",
                dryBarSampleHash: ExactPCMFingerprint.mono(
                    [Float](repeating: 0, count: Int((
                        240.0 / AutonomousSessionDirector.bpm *
                            evidence.sampleRate
                    ).rounded()))
                ),
                activeIncomingVoiceCount: 0,
                activeOutgoingVoiceCount: 0,
                continuationRendered: false,
                renderPassesMatch: true,
                foundationRoutingValid: true,
                events: []
            )],
            instruments: [AutonomousInstrumentBarEvidence(bar: 0, evidence: [])],
            percussionEchoTexture: [
                .neutral(bar: 0, sampleRate: evidence.sampleRate),
            ],
            phraseComposition: [.neutral(bar: 0)],
            pulseEchoDrive: [AutonomousPulseEchoDriveBarEvidence(
                bar: 0,
                bpm: AutonomousSessionDirector.bpm,
                delayFrameCount: Int((
                    60.0 / AutonomousSessionDirector.bpm * 0.75 * evidence.sampleRate
                ).rounded()),
                scoreEnabled: false,
                earliestPulseEchoOnsetStep: nil,
                driveEligible: false,
                machineTexture: 0.4,
                appliedAmount: 0,
                transitionFrameCount:
                    PulseEchoReturnDriveContract.transitionFrameCount(
                        sampleRate: evidence.sampleRate
                    ),
                renderedFrameCount: Int((
                    240.0 / AutonomousSessionDirector.bpm * evidence.sampleRate
                ).rounded()),
                currentSendRMS: 0,
                preDriveSampleHash: "0123456789abcdef",
                postDriveSampleHash: "0123456789abcdef",
                firstPreDriveSampleBitPattern: 0,
                firstPostDriveSampleBitPattern: 0,
                lastPreDriveSampleBitPattern: 0,
                lastPostDriveSampleBitPattern: 0,
                changedFrameIndex: -1,
                changedPreDriveSampleBitPattern: 0,
                preDrivePeak: 0,
                preDrivePeakFrameIndex: 0,
                postDrivePeak: 0,
                postDrivePeakFrameIndex: 0,
                postDrivePeakPreDriveSample: 0,
                postDrivePeakEffectiveAmount: 0,
                preDriveRMS: 0,
                postDriveRMS: 0,
                preDriveLowBandRMS: 0,
                postDriveLowBandRMS: 0,
                differenceRMS: 0,
                interlockChapter: .home,
                finite: true
            )],
            spatialFDN: [AutonomousSpatialFDNBarEvidence.neutral(
                bar: 0,
                sampleRate: evidence.sampleRate
            )],
            upperTiming: [AutonomousUpperTimingBarEvidence(
                bar: 0,
                chapter: .home,
                bpm: AutonomousSessionDirector.bpm,
                sampleRate: evidence.sampleRate,
                renderedFrameCount: Int((
                    240.0 / AutonomousSessionDirector.bpm * evidence.sampleRate
                ).rounded()),
                sourceScoreNoteCount: 0,
                sourceRenderEventCount: 0,
                anchorEventCount: 0,
                activeOffsetCount: 0,
                protectedRoleActiveOffsetCount: 0,
                minimumOffsetInSteps: 0,
                maximumOffsetInSteps: 0,
                maximumRoleSpreadInSteps: 0,
                anchorOffsetPatternFingerprint:
                    AutonomousUpperTimingBarEvidence.offsetPatternFingerprint([]),
                shadowMinimumOffsetInSteps: 0,
                shadowMaximumOffsetInSteps: 0,
                responseMinimumOffsetInSteps: 0,
                responseMaximumOffsetInSteps: 0,
                scoreFingerprint: "0123456789abcdef",
                renderFingerprint: "0123456789abcdef",
                appliedGateFingerprint: "89abcdef01234567",
                anchorSignal: AutonomousUpperTimingRoleSignalEvidence(
                    role: .anchor,
                    eventCount: 0,
                    sampleHash: "0000000000000000",
                    peak: 0,
                    rms: 0,
                    finite: true
                ),
                shadowSignal: AutonomousUpperTimingRoleSignalEvidence(
                    role: .shadow,
                    eventCount: 0,
                    sampleHash: "1111111111111111",
                    peak: 0,
                    rms: 0,
                    finite: true
                ),
                responseSignal: AutonomousUpperTimingRoleSignalEvidence(
                    role: .response,
                    eventCount: 0,
                    sampleHash: "2222222222222222",
                    peak: 0,
                    rms: 0,
                    finite: true
                ),
                bindingValid: true,
                finite: true
            )],
            graph: graph,
            routeContinuation: route,
            incomingLiveMasterRevision: 0,
            outgoingLiveMasterRevision: 0,
            incomingLiveMasterTrimDB: 0,
            incomingLiveMasterCleanWindowCount: 0,
            outgoingLiveMasterCleanWindowCount: 0,
            incomingLiveMasterStateFingerprint:
                LiveMasterHeadroomContinuationState().fingerprint,
            outgoingLiveMasterStateFingerprint:
                LiveMasterHeadroomContinuationState().fingerprint,
            liveObservationFingerprint: nil,
            liveProposalFingerprint: nil,
            liveProposalOutcome: .hold,
            requestedLiveMasterTrimDB: 0,
            appliedLiveMasterTrimDB: 0,
            liveMasterGain: 1,
            preLiveMasterPCMFingerprint: livePhraseHash,
            postLiveMasterPCMFingerprint: livePhraseHash,
            liveMasterScalingMatches: true,
            liveEarliestEligibleFutureSample: nil,
            liveAppliedFutureSample: nil,
            liveProposalBindingMatches: true,
            preGraphUpperTimbreEvidence: evidence,
            postGraphUpperTimbreEvidence: evidence
        )
        var attemptReasons: [QualityReasonCode] = []
        if !vector.isComplete { attemptReasons.append(.evidenceMissingV1) }
        if !vector.isFinite { attemptReasons.append(.evidenceNonFiniteV1) }
        if !vector.hardGatesPassed { attemptReasons.append(.hardGateFailedV1) }
        let attempt = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: attemptReasons,
            vector: vector
        )
        let transaction = AutonomousCandidateEvaluationTransaction(
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: policyVersion,
            evaluatorVersion: policyVersion ==
                QualityQualificationContract.uncalibratedPolicyVersion
                ? QualityQualificationContract.uncalibratedEvaluatorVersion
                : "evaluator-test",
            planFingerprint: planFingerprint,
            attempts: [attempt],
            selectedAttemptIndex: 0,
            correctionCount: 0
        )
        return (vector, transaction)
    }

    private func fixtureActiveModalBar(
        sampleRate: Double
    ) -> AutonomousModalPercussionBarEvidence {
        let frameCount = Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded())
        let event = AutonomousModalPercussionEventEvidence(
            scoreEventIndex: 0,
            step: 10,
            use: ModalPercussionUse.foundationCompanion.rawValue,
            modalIdentity: ModalIdentity.dorian.rawValue,
            modalDegree: 0,
            octave: 1,
            requestedFundamentalHz: 110,
            appliedFundamentalHz: 110,
            excitation: 0.72,
            damping: 0.6,
            brightness: 0.34,
            inharmonicity: 0.025,
            intensity: 0.58,
            modeCount: ModalPercussionVoice.modeCount,
            modeRatioFingerprint: "0123456789abcdef",
            minimumModeFrequencyHz: 110,
            maximumModeFrequencyHz: 509.3,
            maximumPoleRadius: 0.998,
            excitationFingerprint: "123456789abcdef0",
            drySampleHash: "23456789abcdef01",
            renderedFrameCount: frameCount,
            nonzeroSampleCount: 2_048,
            peak: 0.02,
            rms: 0.003,
            crestFactor: 20.0 / 3,
            attackRMS: 0.01,
            bodyRMS: 0.005,
            tailRMS: 0.002,
            tailToBodyDB: -7.958_800_173_440_752,
            spectralCentroidHz: 620,
            incomingVoiceStateFingerprint: "1111111111111111",
            outgoingVoiceStateFingerprint: "2222222222222222",
            finite: true,
            stable: true,
            capacityValid: true,
            scoreBindingValid: true,
            routeBindingValid: true
        )
        return AutonomousModalPercussionBarEvidence(
            bar: 0,
            sourceScoreEventCount: 1,
            sourceRenderEventCount: 1,
            use: ModalPercussionUse.foundationCompanion.rawValue,
            incomingStateFingerprint: "1111111111111111",
            outgoingStateFingerprint: "2222222222222222",
            dryBarSampleHash: "3456789abcdef012",
            activeIncomingVoiceCount: 0,
            activeOutgoingVoiceCount: 1,
            continuationRendered: false,
            renderPassesMatch: true,
            foundationRoutingValid: true,
            events: [event]
        )
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

    private func fixturePerceptualEvidence(
        frameCount: Int,
        sampleRate: Double,
        finite: Bool
    ) -> StreamingPerceptualEvidence {
        var samples = [Float](repeating: 0, count: frameCount)
        if !finite, !samples.isEmpty { samples[samples.count - 1] = .nan }
        guard let evidence = StreamingPerceptualEvidenceAnalyzer.analyze(
            left: samples,
            right: samples,
            sampleRate: sampleRate
        ) else {
            preconditionFailure("Non-cancellable perceptual fixture stopped")
        }
        return evidence
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
