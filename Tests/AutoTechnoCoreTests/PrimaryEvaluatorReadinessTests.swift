import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing

@Suite("Single primary evaluator readiness", .serialized)
struct PrimaryEvaluatorReadinessTests {
    @Test("Modal evidence is non-compensable before the primary policy")
    func modalEvidencePrecedesPrimaryPolicy() {
        #expect(AutonomousCandidateEvaluationVector.schemaVersion == 20)
        #expect(AutonomousCandidateEvaluationTransaction.schemaVersion == 4)
        #expect(AutonomousPreparedCommitProvenance.schemaVersion == 2)
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 6)
        #expect(ProfessionalQualityObservation.schemaVersion == 3)
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 3)
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 4)
        #expect(ProfessionalQualityHoldoutQualification.schemaVersion == 2)
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v3")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v3")
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

    @Test("Bundled v3 artifacts activate only the exact schema-22 engine")
    func bundledV3ArtifactsAreReady() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        #expect(artifacts.profile.engineVersion ==
                QualityQualificationContract.engineVersion)
        #expect(artifacts.profile.schemaVersion == 3)
        #expect(artifacts.adversarialSuite.schemaVersion == 4)
        #expect(artifacts.holdoutQualification.schemaVersion == 2)
        for sampleRate in [44_100.0, 48_000.0] {
            #expect(ProfessionalQualityPreparationEvaluator(
                sampleRate: sampleRate,
                artifacts: artifacts
            ).availability == .available)
        }
    }

    @Test("An 8 kHz route with exact v3 artifacts is unsupported")
    func unsupported8KRouteStaysUnavailable() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        #expect(ProfessionalQualityPreparationEvaluator(
            sampleRate: 8_000,
            artifacts: artifacts
        ).availability == .unsupportedSampleRate)
    }

    @Test("A 12 kHz route with exact v3 artifacts is unsupported")
    func unsupported12KRouteStaysUnavailable() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        #expect(ProfessionalQualityPreparationEvaluator(
            sampleRate: 12_000,
            artifacts: artifacts
        ).availability == .unsupportedSampleRate)
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
