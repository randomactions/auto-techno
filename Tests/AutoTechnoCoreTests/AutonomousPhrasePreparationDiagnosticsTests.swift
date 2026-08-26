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

    @Test("An ordinary successor can use the calibrated continuation envelope")
    func ordinarySuccessorCanCreateLongContinuationObservation() throws {
        let selectedSeed = (UInt64(1)...UInt64(512)).first { seed in
            let candidateDirector = AutonomousSessionDirector(rootSeed: seed)
            let candidateInitial = candidateDirector.initialState()
            let initialPlan = candidateDirector.plan(from: candidateInitial)
            let candidateSuccessor = candidateInitial.advance(
                using: initialPlan,
                quality: candidateInitial.quality,
                liveMasterHeadroom: candidateInitial.liveMasterHeadroom
            )
            let plan = candidateDirector.plan(from: candidateSuccessor)
            let identity = LiveOutputPlanSourceIdentity(plan: plan)
            return CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: identity.chapterChanged
            ).isEmpty
        }
        let director = AutonomousSessionDirector(
            rootSeed: try #require(selectedSeed)
        )
        let initialState = director.initialState()
        let neverCancelled: @Sendable () -> Bool = { false }
        let initialResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: director.plan(from: initialState),
            sessionSeed: initialState.rootSeed,
            memory: initialState.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: initialState.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: neverCancelled
        )
        let initial = try #require(initialResult)
        let successorState = initialState.advance(
            using: initial.plan,
            quality: initial.qualityContinuationState,
            liveMasterHeadroom: initial.liveMasterHeadroomContinuationState
        )
        let successorResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: director.plan(from: successorState),
            sessionSeed: successorState.rootSeed,
            memory: successorState.memory,
            sampleRate: 8_000,
            incomingRenderState: initial.endingRenderState,
            incomingGraphState: initial.endingGraphState,
            previousGraph: initial.graph,
            incomingQualityState: successorState.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: neverCancelled
        )
        let successor = try #require(successorResult)
        let vector = successor.selectedCandidateEvidence
        let phraseKind = try #require(
            AutonomousPhraseKind(rawValue: vector.symbolic.phraseKind)
        )
        #expect(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: vector.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: vector.symbolic.chapterChanged
        ).isEmpty)

        let observation = try ProfessionalQualityObservation(
            candidate: vector,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: .longContinuation
        )
        #expect(observation.checkpoint ==
                CanonicalJourneyCheckpoint.longContinuation)
        #expect(observation.isComplete)
    }
}
