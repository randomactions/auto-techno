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

    @Test("Bundled v2 artifacts cannot activate the schema-20 primary evaluator")
    func bundledV2ArtifactsStayUnavailable() {
        var rejected = false
        do {
            _ = try ProfessionalQualityPrimaryArtifacts.load()
        } catch {
            rejected = true
        }
        #expect(rejected)
    }

    @Test("An 8 kHz route without v3 artifacts remains unavailable")
    func unsupported8KRouteStaysUnavailable() {
        #expect(ProfessionalQualityPreparationEvaluator(
            sampleRate: 8_000,
            artifacts: nil
        ).availability == .artifactsUnavailable)
    }

    @Test("A 12 kHz route without v3 artifacts remains unavailable")
    func unsupported12KRouteStaysUnavailable() {
        #expect(ProfessionalQualityPreparationEvaluator(
            sampleRate: 12_000,
            artifacts: nil
        ).availability == .artifactsUnavailable)
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
