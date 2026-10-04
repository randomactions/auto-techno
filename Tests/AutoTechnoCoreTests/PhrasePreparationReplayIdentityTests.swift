import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import Foundation
import Testing

@Suite("Phrase preparation replay identity")
struct PhrasePreparationReplayIdentityTests {
    @Test("Canonical session fingerprint binds seed and every accepted continuation family")
    func canonicalSessionFingerprint() {
        let first = AutonomousSessionState(rootSeed: 42)
        let replay = AutonomousSessionState(rootSeed: 42)
        let changedSeed = AutonomousSessionState(rootSeed: 43)
        let changedMemory = AutonomousSessionState(
            rootSeed: 42,
            memory: TemporalMusicalMemory(totalBars: 1)
        )
        let changedQuality = AutonomousSessionState(
            rootSeed: 42,
            quality: QualityContinuationState(revision: 1)
        )
        let changedLive = AutonomousSessionState(
            rootSeed: 42,
            liveMasterHeadroom: LiveMasterHeadroomContinuationState(
                revision: 1,
                committedTrimDB: -0.25,
                lastProposalFingerprint: "1111111111111111",
                lastObservationFingerprint: "2222222222222222",
                lastAcceptedSourcePhraseIndex: 0,
                earliestEligibleFutureSample: 192_000
            )
        )

        let fingerprint = AutonomousCandidateFingerprint.sessionState(first)
        #expect(fingerprint ==
                AutonomousCandidateFingerprint.sessionState(replay))
        #expect(fingerprint !=
                AutonomousCandidateFingerprint.sessionState(changedSeed))
        #expect(fingerprint !=
                AutonomousCandidateFingerprint.sessionState(changedMemory))
        #expect(fingerprint !=
                AutonomousCandidateFingerprint.sessionState(changedQuality))
        #expect(fingerprint !=
                AutonomousCandidateFingerprint.sessionState(changedLive))
    }

    @Test("Replay identity round trips and rejects every boundary-family mutation")
    func deterministicReplayIdentity() throws {
        let state = AutonomousSessionState(rootSeed: 42)
        let first = request(state: state)
        let replay = request(state: AutonomousSessionState(rootSeed: 42))
        let identity = first.replayIdentity

        #expect(identity.isComplete)
        #expect(identity.matches(first))
        #expect(identity == replay.replayIdentity)
        #expect(identity.fingerprint == replay.replayIdentity.fingerprint)
        #expect(try identity.deterministicJSON() ==
                replay.replayIdentity.deterministicJSON())
        let decoded = try JSONDecoder().decode(
            PhrasePreparationReplayIdentity.self,
            from: identity.deterministicJSON()
        )
        #expect(decoded == identity)
        #expect(decoded.matches(replay))

        var changedRenderState = RenderState()
        changedRenderState.barIndex = 1
        var changedGraphState = GeneratedDSPContinuationState()
        changedGraphState.graph = DSPGraphGenerator.safePlan(sessionSeed: 42)
        let longHorizon = try #require(LongHorizonFutureAdaptationState(
            startingState: state,
            policy: LongHorizonProfessionalPolicyArtifacts.load().policy
        ))
        let changedRequests: [PhrasePreparationRequest] = [
            request(state: AutonomousSessionState(rootSeed: 43)),
            request(
                state: AutonomousSessionState(
                    rootSeed: 42,
                    memory: TemporalMusicalMemory(totalBars: 1)
                )
            ),
            request(state: state, routeGeneration: 1),
            request(state: state, renderState: changedRenderState),
            request(state: state, graphState: changedGraphState),
            request(
                state: state,
                previousGraph: DSPGraphGenerator.safePlan(sessionSeed: 42)
            ),
            request(state: state, longHorizonState: longHorizon),
        ]
        for changedRequest in changedRequests {
            let changedIdentity = changedRequest.replayIdentity
            #expect(changedIdentity.isComplete)
            #expect(changedIdentity.fingerprint != identity.fingerprint)
            #expect(!identity.matches(changedRequest))
        }

        let invalidSampleBoundary = request(
            state: state,
            liveTargetStartSample: 256
        ).replayIdentity
        #expect(!invalidSampleBoundary.isComplete)
        #expect(invalidSampleBoundary.fingerprint != identity.fingerprint)

        var object = try #require(JSONSerialization.jsonObject(
            with: identity.deterministicJSON()
        ) as? [String: Any])
        var payload = try #require(object["payload"] as? [String: Any])
        payload["routeGeneration"] = 9
        object["payload"] = payload
        let attacked = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                PhrasePreparationReplayIdentity.self,
                from: attacked
            )
        }
    }

    @Test("A decoded exact boundary replays score PCM and outgoing continuation")
    func restoredBoundaryReplay() throws {
        let firstRequest = request(
            state: AutonomousSessionState(rootSeed: 48_291),
            sampleRate: 8_000
        )
        let restoredRequest = request(
            state: AutonomousSessionState(rootSeed: 48_291),
            sampleRate: 8_000
        )
        let decodedIdentity = try JSONDecoder().decode(
            PhrasePreparationReplayIdentity.self,
            from: firstRequest.replayIdentity.deterministicJSON()
        )
        #expect(decodedIdentity.matches(restoredRequest))

        let firstDirector = AutonomousSessionDirector(
            rootSeed: firstRequest.sourceState.rootSeed
        )
        let restoredDirector = AutonomousSessionDirector(
            rootSeed: restoredRequest.sourceState.rootSeed
        )
        let firstPlan = firstDirector.plan(from: firstRequest.sourceState)
        let restoredPlan = restoredDirector.plan(
            from: restoredRequest.sourceState
        )
        let firstGraph = DSPGraphGenerator.safePlan(
            sessionSeed: firstRequest.sourceState.rootSeed
        )
        let restoredGraph = DSPGraphGenerator.safePlan(
            sessionSeed: restoredRequest.sourceState.rootSeed
        )
        var firstRenderState = firstRequest.incomingRenderState
        var restoredRenderState = restoredRequest.incomingRenderState
        var firstGraphState = firstRequest.incomingGraphState
        var restoredGraphState = restoredRequest.incomingGraphState

        let firstBlocks = AutonomousPhraseRenderer.render(
            plan: firstPlan,
            graph: firstGraph,
            sampleRate: firstRequest.key.sampleRate,
            state: &firstRenderState,
            graphState: &firstGraphState
        )
        let restoredBlocks = AutonomousPhraseRenderer.render(
            plan: restoredPlan,
            graph: restoredGraph,
            sampleRate: restoredRequest.key.sampleRate,
            state: &restoredRenderState,
            graphState: &restoredGraphState
        )

        #expect(AutonomousCandidateFingerprint.plan(firstPlan) ==
                AutonomousCandidateFingerprint.plan(restoredPlan))
        #expect(firstBlocks.map(\.left) == restoredBlocks.map(\.left))
        #expect(firstBlocks.map(\.right) == restoredBlocks.map(\.right))
        #expect(AutonomousCandidateFingerprint.renderState(firstRenderState) ==
                AutonomousCandidateFingerprint.renderState(
                    restoredRenderState
                ))
        #expect(AutonomousCandidateFingerprint.generatedDSPState(
            firstGraphState
        ) == AutonomousCandidateFingerprint.generatedDSPState(
            restoredGraphState
        ))
    }

    private func request(
        state: AutonomousSessionState,
        sampleRate: Double = 48_000,
        routeGeneration: Int = 0,
        renderState: RenderState = RenderState(),
        graphState: GeneratedDSPContinuationState =
            GeneratedDSPContinuationState(),
        previousGraph: DSPGraphPlan? = nil,
        longHorizonState: LongHorizonFutureAdaptationState? = nil,
        liveTargetStartSample: Int64? = nil
    ) -> PhrasePreparationRequest {
        PhrasePreparationRequest(
            key: PhrasePreparationKey(
                sessionSeed: state.rootSeed,
                phraseIndex: state.phraseIndex,
                sampleRate: sampleRate,
                channelCount:
                    QualityQualificationContract.requiredRouteChannelCount,
                routeRecovery: false,
                qualityRevision: state.quality.revision,
                qualityPolicyVersion: state.quality.policyVersion,
                qualityControllerFingerprint:
                    state.quality.observedControllerStateFingerprint ??
                    state.quality.acceptedControllerStateFingerprint,
                routeGeneration: routeGeneration,
                incomingLiveMasterRevision:
                    state.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint:
                    state.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint: nil,
                liveEarliestEligibleFutureSample: nil,
                liveTargetStartSample: liveTargetStartSample
            ),
            sourceState: state,
            incomingLongHorizonState: longHorizonState,
            incomingRenderState: renderState,
            incomingGraphState: graphState,
            previousGraph: previousGraph,
            pendingLiveMasterBinding: nil
        )
    }
}

@Suite("Canonical prospective successor request", .serialized)
struct ProspectiveSuccessorRequestTests {
    @Test("Actual successor PCM uses the exact sealed canonical request at all fixed rates")
    @MainActor
    func canonicalPreparedSuccessorContext() throws {
        let artifacts = try qualifiedArtifacts(sampleRates: [8_000, 44_100, 48_000])
        let policy = try LongHorizonProfessionalPolicy(profile: artifacts.profile,
            adversarial: artifacts.adversarial, holdout: artifacts.holdout)
        let director = AutonomousSessionDirector(rootSeed: 48_300)
        var state = director.initialState()
        for _ in 0..<21 { state.advancePlanning(using: director.plan(from: state)) }
        let stateFingerprint = AutonomousCandidateFingerprint.sessionState(state)
        let incoming = try #require(LongHorizonFutureAdaptationState(startingState: state, policy: policy))
        var rows: [[String: Any]] = []
        for rate in [8_000.0, 44_100.0, 48_000.0] {
            let request = Self.request(state: state, rate: rate, horizon: incoming)
            let control = ContextControl()
            let source = try #require(Self.prepare(request,
                evaluator: ContextEvaluator(request: request, policy: policy, control: control)))
            #expect(source.commitEligible)
            #expect(source.preparationReplayFingerprint == request.replayIdentity.fingerprint)
            let seal = try #require(control.snapshot.seal)
            let admitted = try #require(seal.admittedRequest(for: source,
                sourceRequest: request, longHorizonPolicy: policy))
            let observed = try #require(incoming.observing(prepared: source, incomingState: state, policy: policy))
            let next = state.advance(using: source.plan, quality: source.qualityContinuationState,
                liveMasterHeadroom: source.liveMasterHeadroomContinuationState, longHorizonDecision: observed.decision)
            #expect(admitted.replayIdentity.isComplete && admitted.replayIdentity.matches(admitted))
            #expect(AutonomousCandidateFingerprint.sessionState(admitted.sourceState) ==
                AutonomousCandidateFingerprint.sessionState(next))
            #expect(admitted.incomingLongHorizonState?.fingerprint == observed.state.fingerprint)
            let successor = try #require(source.preparedValidation?.qualifiedSuccessor)
            #expect(successor.commitEligible && successor.plan == director.plan(from: next))
            #expect(successor.preparationReplayFingerprint == admitted.replayIdentity.fingerprint)
            #expect(successor.incomingQualityState == next.quality)
            #expect(successor.incomingLiveMasterHeadroomState == next.liveMasterHeadroom)
            #expect(successor.selectedCandidateEvidence.routeContinuation.routeGeneration == request.key.routeGeneration)
            #expect(successor.selectedCandidateEvidence.routeContinuation.incomingRenderDSPFingerprint ==
                source.commitProvenance.outgoingRenderDSPFingerprint)
            #expect(admitted.pendingLiveMasterBinding == nil && admitted.key.liveTargetStartSample == nil)
            #expect(seal.knownSuccessorStartSample == nil)
            #expect(control.snapshot.refused.count == 6)
            #expect(seal.admittedRequest(for: source,
                sourceRequest: Self.request(state: state, rate: rate, horizon: incoming, generation: 8),
                longHorizonPolicy: policy) == nil)
            #expect(seal.admittedRequest(for: source, sourceRequest: request, longHorizonPolicy: nil) == nil)
            rows.append(["sampleRate": rate, "sourceIdentity": seal.sourceIdentityFingerprint,
                "requestFingerprint": admitted.replayIdentity.fingerprint,
                "successorSampleHash": successor.audioPreflight.quality.sampleHash,
                "canonicalStateAndPlanMatch": true, "sourceCommitEligible": source.commitEligible,
                "refusedBeforeSuccessorPCM": control.snapshot.refused])
        }
        // A genuinely applied proposal belongs only to the source. The
        // actual successor inherits its committed live state without applying
        // the same proposal a second time, and keeps the known sample boundary.
        var previousState = director.initialState()
        for _ in 0..<20 { previousState.advancePlanning(using: director.plan(from: previousState)) }
        let previousPlan = director.plan(from: previousState)
        let liveRate = 48_000.0
        let frameCount = try #require(LiveOutputWindowAnalyzer.frameCount(sampleRate: liveRate))
        let signal = (0..<frameCount).map { Float(0.2 * sin(2 * Double.pi * 997 * Double($0) / liveRate)) }
        let evidence = try #require(LiveFeedbackTestSupport.analyze(signal: signal,
            plan: previousPlan, sampleRate: liveRate, routeGeneration: 7,
            controllerRevision: state.liveMasterHeadroom.revision,
            qualityPolicyVersion: policy.profile.primaryPolicyVersion))
        let target = try #require(LiveFeedbackTestSupport.target(evidence: evidence,
            loudnessUpperLUFS: evidence.maximumShortTermLoudnessLUFS - 1,
            truePeakUpperDBTP: evidence.truePeakDBTP - 1,
            profileFingerprint: ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint))
        let start = evidence.playerSampleRange.upperBound + 10_000
        let proposal = LiveMasterHeadroomController.propose(evidence: evidence, target: target,
            incoming: state.liveMasterHeadroom, earliestEligibleFutureSample: start)
        #expect(proposal.outcome == .attenuate)
        let binding = PendingLiveMasterHeadroomBinding(
            sourceIdentity: LiveOutputPlanSourceIdentity(plan: previousPlan), evidence: evidence,
            target: target, proposal: proposal,
            eligibleTarget: LiveMasterHeadroomEligibleTarget(plan: director.plan(from: state),
                routeGeneration: 7, sampleRate: liveRate, earliestEligibleFutureSample: start,
                qualityPolicyVersion: evidence.qualityPolicyVersion, evaluatorVersion: evidence.evaluatorVersion,
                controllerPolicyVersion: evidence.controllerPolicyVersion))
        let liveRequest = Self.request(state: state, rate: liveRate, horizon: incoming,
            binding: binding, targetStart: start)
        let liveControl = ContextControl()
        let liveSource = try #require(Self.prepare(liveRequest,
            evaluator: ContextEvaluator(request: liveRequest, policy: policy, control: liveControl)))
        #expect(liveSource.commitEligible && liveSource.liveMasterHeadroomContinuationState.committedTrimDB == -0.25)
        let liveSeal = try #require(liveControl.snapshot.seal)
        let liveNext = try #require(liveSeal.admittedRequest(for: liveSource,
            sourceRequest: liveRequest, longHorizonPolicy: policy))
        let liveSuccessor = try #require(liveSource.preparedValidation?.qualifiedSuccessor)
        #expect(liveSuccessor.commitEligible)
        #expect(liveNext.sourceState.liveMasterHeadroom == liveSource.liveMasterHeadroomContinuationState)
        #expect(liveSuccessor.incomingLiveMasterHeadroomState == liveSource.liveMasterHeadroomContinuationState)
        #expect(liveSuccessor.liveMasterHeadroomContinuationState == liveSource.liveMasterHeadroomContinuationState)
        #expect(liveNext.pendingLiveMasterBinding == nil && liveSuccessor.liveTargetStartSample == nil)
        #expect(liveSeal.knownSuccessorStartSample == start + Int64(liveSource.audioPreflight.quality.analyzedFrameCount))
        #expect(AutonomousCandidateFingerprint.sessionState(state) == stateFingerprint)
        let request = Self.request(state: state, rate: 8_000, horizon: incoming)
        let deniedControl = ContextControl()
        let denied = try #require(Self.prepare(request, evaluator: ContextEvaluator(
            request: request, policy: policy, control: deniedControl, dropProof: true)))
        #expect(!denied.commitEligible)
        let unboundControl = ContextControl()
        let unbound = try #require(Self.prepare(request, evaluator: ContextEvaluator(
            request: request, policy: policy, control: unboundControl, bindReplayOrigin: false)))
        #expect(!unbound.commitEligible && unboundControl.snapshot.seal == nil)
        #expect(deniedControl.snapshot.seal?.admittedRequest(for: denied,
            sourceRequest: request, longHorizonPolicy: policy) == nil)
        print(String(decoding: try JSONSerialization.data(withJSONObject: [
            "fixture": "canonical-prospective-successor-request.v1", "rows": rows,
            "unadmittedSourceRefused": true, "unboundReplayOriginRefused": true, "incomingStateUnchanged": true,
            "liveProposalAppliedOnce": true, "knownLiveBoundaryPreserved": true,
            "qualification": "mechanical-only-not-installed", "runtimeActivation": false
        ], options: [.sortedKeys]), as: UTF8.self))
    }

    private static func request(state: AutonomousSessionState, rate: Double,
        horizon: LongHorizonFutureAdaptationState?, generation: Int = 7,
        render: RenderState? = nil, graph: DSPGraphPlan? = nil,
        binding: PendingLiveMasterHeadroomBinding? = nil, targetStart: Int64? = nil) -> PhrasePreparationRequest {
        var input = RenderState(); input.barIndex = state.memory.totalBars
        let key = PhrasePreparationKey(sessionSeed: state.rootSeed, phraseIndex: state.phraseIndex,
            sampleRate: rate, channelCount: 2, routeRecovery: false,
            qualityRevision: state.quality.revision, qualityPolicyVersion: state.quality.policyVersion,
            qualityControllerFingerprint: state.quality.observedControllerStateFingerprint ?? state.quality.acceptedControllerStateFingerprint,
            routeGeneration: generation, incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
            incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
            pendingLiveMasterProposalFingerprint: binding?.proposal.fingerprint,
            liveEarliestEligibleFutureSample: binding?.proposal.earliestEligibleFutureSample, liveTargetStartSample: targetStart)
        return PhrasePreparationRequest(key: key, sourceState: state, incomingLongHorizonState: horizon,
            incomingRenderState: render ?? input, incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: graph, pendingLiveMasterBinding: binding)
    }

    private static func prepare(_ request: PhrasePreparationRequest,
        evaluator: ContextEvaluator) -> PreparedAutonomousPhrase? {
        prepareProduct(request, evaluator: evaluator)
    }

    private static func prepareProduct<E: AutonomousCandidateEvaluating>(
        _ request: PhrasePreparationRequest, evaluator: E) -> PreparedAutonomousPhrase? {
        AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed).plan(from: request.sourceState),
            sessionSeed: request.sourceState.rootSeed, memory: request.sourceState.memory,
            sampleRate: request.key.sampleRate, incomingRenderState: request.incomingRenderState,
            incomingGraphState: request.incomingGraphState, previousGraph: request.previousGraph,
            incomingQualityState: request.sourceState.quality, routeGeneration: request.key.routeGeneration,
            pendingLiveMasterBinding: request.pendingLiveMasterBinding, liveTargetStartSample: request.key.liveTargetStartSample,
            evaluator: evaluator, cancellationRequested: { false })
    }

    private final class ContextControl: @unchecked Sendable {
        struct Snapshot {
            var seal: ProspectivePerformanceContinuation?
            var refused: [String: String] = [:]
        }
        private let lock = NSLock()
        private var value = Snapshot()
        var snapshot: Snapshot { lock.lock(); defer { lock.unlock() }; return value }
        func update(_ change: (inout Snapshot) -> Void) {
            lock.lock(); defer { lock.unlock() }; change(&value)
        }
    }

    private struct ContextEvaluator: AutonomousCandidateEvaluating {
        let request: PhrasePreparationRequest
        let policy: LongHorizonProfessionalPolicy
        let control: ContextControl
        var dropProof = false
        var bindReplayOrigin = true
        var preparationReplayFingerprint: String? { bindReplayOrigin ? request.replayIdentity.fingerprint : nil }
        var policyVersion: String { policy.profile.primaryPolicyVersion }
        let evaluatorVersion = ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier
        var requiresPreparedValidation: Bool { true }
        func requestsHomeUpperTimbreCorrection(for candidate: AutonomousCandidateEvaluationVector) -> Bool { false }
        func terminalVerdict(selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction) -> AutonomousCandidatePolicyVerdict {
            .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview) -> AutonomousCandidatePreparedValidation? {
            let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
            var changedRender = request.incomingRenderState; changedRender.barIndex += 1
            let mutations: [(String, PhrasePreparationRequest, LongHorizonProfessionalPolicy?, Bool)] = [
                ("rate", Self.changed(request, rate: request.key.sampleRate == 8_000 ? 44_100 : 8_000), policy, false),
                ("generation", Self.changed(request, generation: request.key.routeGeneration + 1), policy, false),
                ("render", Self.changed(request, render: changedRender), policy, false),
                ("previous-graph", Self.changed(request, graph: DSPGraphGenerator.safePlan(sessionSeed: request.sourceState.rootSeed)), policy, false),
                ("missing-long-policy", request, nil, false),
                ("cancelled", request, policy, true)
            ]
            for (name, mutated, candidatePolicy, cancelled) in mutations {
                if case let .failure(failure) = AutonomousPerformancePreparer.prospectiveContinuation(
                    for: preview, request: mutated, director: director,
                    longHorizonPolicy: candidatePolicy, cancellationRequested: { cancelled }) {
                    control.update { $0.refused[name] = failure.code }
                }
            }
            guard case let .success(seal) = AutonomousPerformancePreparer.prospectiveContinuation(
                for: preview, request: request, director: director, longHorizonPolicy: policy,
                cancellationRequested: { false }) else { return nil }
            control.update { $0.seal = seal }
            if dropProof { return nil }
            guard let successor = ProspectiveSuccessorRequestTests.prepareProduct(seal.request,
                evaluator: LeafEvaluator(policyVersion: policyVersion, evaluatorVersion: evaluatorVersion,
                    preparationReplayFingerprint: seal.request.replayIdentity.fingerprint)) else { return nil }
            return try? preview.assessingContinuous(successor: successor) { _ in
                .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
            }
        }
        private static func changed(_ request: PhrasePreparationRequest, rate: Double? = nil,
            generation: Int? = nil, render: RenderState? = nil, graph: DSPGraphPlan? = nil) -> PhrasePreparationRequest {
            ProspectiveSuccessorRequestTests.request(state: request.sourceState, rate: rate ?? request.key.sampleRate,
                horizon: request.incomingLongHorizonState, generation: generation ?? request.key.routeGeneration,
                render: render ?? request.incomingRenderState, graph: graph ?? request.previousGraph)
        }
    }

    private struct LeafEvaluator: AutonomousCandidateEvaluating {
        let policyVersion: String; let evaluatorVersion: String
        let preparationReplayFingerprint: String?
        var requiresPreparedValidation: Bool { true }
        func requestsHomeUpperTimbreCorrection(for candidate: AutonomousCandidateEvaluationVector) -> Bool { false }
        func terminalVerdict(selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction) -> AutonomousCandidatePolicyVerdict {
            .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview) -> AutonomousCandidatePreparedValidation? {
            try? preview.assessingContinuous { _ in
                .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
            }
        }
    }
}
