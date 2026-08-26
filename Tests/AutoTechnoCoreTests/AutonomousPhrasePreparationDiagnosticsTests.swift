import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing

@Suite("Autonomous phrase preparation diagnostics")
struct AutonomousPhrasePreparationDiagnosticsTests {
    @Test("Input guard identifies the exact render boundary mismatch")
    func renderBoundaryMismatchIsReasonCoded() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let plan = director.plan(from: state)
        var renderState = RenderState()
        renderState.barIndex = plan.startBar + 1

        let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
            plan: plan,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: renderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: { false }
        )

        let failure = try #require(outcome.failure)
        #expect(failure.stage == .inputValidation)
        #expect(failure.code == .invalidInput)
        #expect(failure.details.contains("render-start-bar"))
        #expect(outcome.preparedPhrase == nil)
    }

    @Test("Cancellation is distinct from an invalid continuation")
    func cancellationIsReasonCoded() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let plan = director.plan(from: state)

        let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
            plan: plan,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: { true }
        )

        let failure = try #require(outcome.failure)
        #expect(failure.stage == .inputValidation)
        #expect(failure.code == .cancelled)
        #expect(failure.details.isEmpty)
    }

    @Test("Evaluator diagnostic context is bounded and deterministic")
    func evaluatorDiagnosticsAreBounded() {
        let verdict = AutonomousCandidatePolicyVerdict(
            outcome: .rejected,
            reasonCodes: [.guardrailRegressionV1],
            diagnosticDetails: (0..<32).map { "detail-\($0)" }
        )

        #expect(verdict.diagnosticDetails.count == 24)
        #expect(verdict.diagnosticDetails == (0..<24).map { "detail-\($0)" })
    }
}
