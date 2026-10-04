import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import Testing

@Suite("Single primary evaluator readiness", .serialized)
struct PrimaryEvaluatorReadinessTests {
    @Test("Modal evidence is non-compensable before the primary policy")
    func modalEvidencePrecedesPrimaryPolicy() {
        #expect(AutonomousCandidateEvaluationVector.schemaVersion == 43)
        #expect(AutonomousCandidateEvaluationTransaction.schemaVersion == 14)
        #expect(AutonomousPreparedCommitProvenance.schemaVersion == 3)
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 30)
        #expect(ProfessionalQualityObservation.schemaVersion == 21)
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 22)
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 22)
        #expect(ProfessionalQualityHoldoutQualification.schemaVersion == 20)
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v32")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v32")
        #expect(AutonomousCandidateCompletenessFailure.upperPercussionTailEvidence
            .rawValue == "upper-percussion-tail-evidence")
        #expect(AutonomousCandidateCompletenessFailure.modalPercussionEvidence
            .rawValue == "modal-percussion-evidence")
    }

    @Test("The maximum two-pass primary preparation fits the declared memory envelope")
    func representativeRateWorkingSetEnvelope() throws {
        #expect(QualityQualificationContract.maximumRenderPasses == 2)
        #expect(QualityQualificationContract.maximumCorrectionRenders == 1)

        for sampleRate in AutonomousPreparationResourceBudget.representativeSampleRates {
            let budget = try #require(AutonomousPreparationResourceBudget(
                sampleRate: sampleRate,
                barCount: QualityQualificationContract.maximumPhraseBars,
                renderPassCount: QualityQualificationContract.maximumRenderPasses
            ))
            #expect(budget.withinActivationBound)
            #expect(budget.peakWorkingByteCount <=
                    AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount)
        }
    }

    @Test("Historical bundled artifacts cannot activate any route under the current continuous policy")
    func bundledV30ArtifactsAreIneligible() {
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try historicalV30PrimaryArtifacts()
        }
        for sampleRate in [8_000.0, 12_000.0, 44_100.0, 48_000.0] {
            #expect(ProfessionalQualityPreparationEvaluator(
                sampleRate: sampleRate, artifacts: nil).availability == .artifactsUnavailable)
        }
    }

    @Test("Pending matching current resources cannot leave a partially ready production host")
    func pendingCurrentPairStaysUnavailable() {
        #expect(ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint == nil)
        #expect(ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint == nil)
        #expect(ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint == nil)
        #expect(LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion ==
            "autotechno-quality.primary-calibrated.v32.unqualified")
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try AutonomousPerformanceArtifactSet.load()
        }
    }

    @Test("Missing artifacts cannot activate the calibrated primary evaluator")
    func missingArtifactsStayUnavailable() {
        #expect(ProfessionalQualityPreparationEvaluator(
            sampleRate: 48_000,
            artifacts: nil
        ).availability == .artifactsUnavailable)
    }

    @Test("Cancellation before primary rendering produces no transaction")
    func primaryBoundaryCancellation() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: director.plan(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 48_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: { true }
        )
        #expect(prepared == nil)
    }

}
