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
        // Boundary serialization uses the shared qualified mechanical fixture,
        // independent of obsolete installed production artifacts.
        let artifacts = try qualifiedArtifacts()
        let policy = try LongHorizonProfessionalPolicy(profile: artifacts.profile,
            adversarial: artifacts.adversarial, holdout: artifacts.holdout)
        let longHorizon = try #require(LongHorizonFutureAdaptationState(
            startingState: state, policy: policy
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
        try proveCanonicalPreparedSuccessorContext(includeLiveProposal: false)
    }

    @Test("Combined live/long-horizon successor proof requires sealed current primary identity",
        .enabled(if: ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint != nil &&
            ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint != nil &&
            ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint != nil))
    @MainActor
    func canonicalPreparedLiveSuccessorContext() throws {
        try proveCanonicalPreparedSuccessorContext(includeLiveProposal: true)
    }

    @MainActor
    private func proveCanonicalPreparedSuccessorContext(includeLiveProposal: Bool) throws {
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
        // Pending production seals cannot supply a current live policy. The
        // mechanical context proof above and independent live child-inheritance
        // controls remain available; this combined proof needs real seals.
        if includeLiveProposal {
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
            let profileFingerprint = try #require(ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint)
            let target = try #require(LiveFeedbackTestSupport.target(evidence: evidence,
                loudnessUpperLUFS: evidence.maximumShortTermLoudnessLUFS - 1,
                truePeakUpperDBTP: evidence.truePeakDBTP - 1,
                profileFingerprint: profileFingerprint))
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
        }
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
            "liveProposalAppliedOnce": includeLiveProposal, "knownLiveBoundaryPreserved": includeLiveProposal,
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

@Suite("Iterative canonical successor preparation", .serialized)
struct IterativeSuccessorPreparationTests {
    @Test("Aggregate reservations keep the existing ceiling and refuse before another render")
    func aggregateResourceReservations() throws {
        for rate in [8_000.0, 44_100.0, 48_000.0] {
            var budget = AutonomousPreparationChainResourceBudget()
            var expectedPeak = 0
            var expectedRetained = 0
            let single = try #require(AutonomousPreparationResourceBudget(sampleRate: rate,
                barCount: 4, renderPassCount: 2))
            let selected = try #require(AutonomousPreparationResourceBudget(sampleRate: rate,
                barCount: 4, renderPassCount: 1))
            while let next = budget.reserving(sampleRate: rate, barCount: 4) {
                expectedPeak = max(expectedPeak, expectedRetained + single.peakWorkingByteCount)
                #expect(next.reservedPeakWorkingByteCount == expectedPeak)
                #expect(next.sourceCount == budget.sourceCount + 1)
                #expect(next.maximumRenderPassCount == 2 * next.sourceCount)
                #expect(next.reservedPeakWorkingByteCount <=
                    AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount)
                let retained = try #require(next.retainingCompletedSource(sampleRate: rate, barCount: 4,
                    requiresQualifiedSuccessor: true))
                expectedRetained += selected.phraseFrameCount * 2 * MemoryLayout<Float>.stride +
                    selected.continuationPCMByteCount + selected.reducedEvidenceByteCount
                #expect(retained.retainedNumericByteCount == expectedRetained)
                #expect(retained.retainingCompletedSource(sampleRate: rate, barCount: 4,
                    requiresQualifiedSuccessor: true) == nil)
                budget = retained
            }
            #expect(budget.sourceCount > 1)
            #expect(expectedRetained + single.peakWorkingByteCount >
                AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount)
            #expect(budget.reserving(sampleRate: rate, barCount: 4) == nil)
        }
        let empty = AutonomousPreparationChainResourceBudget()
        #expect(empty.reserving(sampleRate: .nan, barCount: 4) == nil)
        #expect(empty.reserving(sampleRate: 48_000, barCount: 17) == nil)
        let normal = try #require(empty.reserving(sampleRate: 8_000, barCount: 4))
        let diagnostic = try #require(empty.reserving(sampleRate: 8_000, barCount: 4,
            diagnosticRoleStemCapture: true))
        let single = try #require(AutonomousPreparationResourceBudget(sampleRate: 8_000,
            barCount: 4, renderPassCount: 2))
        #expect(diagnostic.reservedPeakWorkingByteCount - normal.reservedPeakWorkingByteCount ==
            single.phraseFrameCount * 32 * MemoryLayout<Float>.stride * 2)
    }

    @Test("Root allocated continuation remains reserved exactly once across passes and suspended sources")
    func incomingCapacityReservation() throws {
        let incoming = 3 * 1_024 * 1_024
        var budget = try #require(AutonomousPreparationChainResourceBudget(
            incomingContinuationNumericByteCount: incoming))
        var empty = AutonomousPreparationChainResourceBudget()
        #expect(budget.sourceCount == 0 && budget.maximumRenderPassCount == 0)
        for _ in 0..<3 {
            budget = try #require(budget.reserving(sampleRate: 8_000, barCount: 4, renderPassCount: 2))
            empty = try #require(empty.reserving(sampleRate: 8_000, barCount: 4, renderPassCount: 2))
            #expect(budget.reservedPeakWorkingByteCount - empty.reservedPeakWorkingByteCount == incoming)
            #expect(budget.retainedNumericByteCount - empty.retainedNumericByteCount == incoming)
            #expect(budget.retainedIncomingContinuationNumericByteCount == incoming)
            budget = try #require(budget.retainingCompletedSource(sampleRate: 8_000, barCount: 4,
                requiresQualifiedSuccessor: true))
            empty = try #require(empty.retainingCompletedSource(sampleRate: 8_000, barCount: 4,
                requiresQualifiedSuccessor: true))
        }
        let ceiling = AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount
        #expect(AutonomousPreparationChainResourceBudget(incomingContinuationNumericByteCount: -1) == nil)
        #expect(AutonomousPreparationChainResourceBudget(incomingContinuationNumericByteCount: Int.max) == nil)
        let occupied = try #require(AutonomousPreparationChainResourceBudget(
            incomingContinuationNumericByteCount: ceiling))
        #expect(occupied.reserving(sampleRate: 8_000, barCount: 4, renderPassCount: 1) == nil)
        #expect(AutonomousPreparationChainResourceBudget.version == "autotechno-preparation-chain-resource.v2")
    }

    @Test("Unused incoming capacity refuses before PCM, observation or evaluator creation")
    func oversizedIncomingCapacityRefuses() async throws {
        let original = Self.sourceRequest(rate: 48_000)
        var render = original.incomingRenderState
        render.delayBuffer.reserveCapacity(AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount /
            MemoryLayout<Float>.stride + 1)
        #expect(render.delayBuffer.isEmpty)
        let request = PhrasePreparationRequest(key: original.key, sourceState: original.sourceState,
            incomingLongHorizonState: original.incomingLongHorizonState,
            incomingRenderState: render, incomingGraphState: original.incomingGraphState,
            previousGraph: original.previousGraph, pendingLiveMasterBinding: original.pendingLiveMasterBinding)
        #expect(request.replayIdentity == original.replayIdentity)
        let countValue = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
            renderState: render, generatedDSPState: request.incomingGraphState,
            cancellationRequested: { false })
        let count = try #require(countValue)
        #expect(count > AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount)
        let control = Control()
        let probe = PreparationWorkingStorageProbe()
        let result = await Task.detached {
            AutonomousPerformancePreparer.prepareChainDiagnosing(request: request,
                director: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed),
                longHorizonPolicy: nil, workingStorageProbe: probe,
                makeEvaluator: { input in
                    control.terminal(input.key.phraseIndex)
                    return Evaluator(request: input, control: control)
                }, cancellationRequested: { false })
        }.value
        #expect(result.preparedPhrase == nil && result.failure?.stage == "successor-chain")
        #expect(result.failure?.code == "resource-bound")
        #expect(result.failure?.details.contains("scope=incoming-continuation") == true)
        #expect(control.terminals.isEmpty && probe.observationCount == 0)
        #expect(render.delayBuffer.isEmpty && request.replayIdentity == original.replayIdentity)
    }

    @Test("Charged unused root capacity preserves native PCM, proof, continuation and child ownership")
    func chargedIncomingCapacityPreservesNativeProducts() async throws {
        for rate in [44_100.0, 48_000.0] {
            let original = Self.sourceRequest(rate: rate)
            var render = original.incomingRenderState
            render.delayBuffer.reserveCapacity(16_384)
            let request = PhrasePreparationRequest(key: original.key, sourceState: original.sourceState,
                incomingLongHorizonState: original.incomingLongHorizonState,
                incomingRenderState: render, incomingGraphState: original.incomingGraphState,
                previousGraph: original.previousGraph, pendingLiveMasterBinding: original.pendingLiveMasterBinding)
            #expect(request.replayIdentity == original.replayIdentity)
            func prepare(_ input: PhrasePreparationRequest) async -> PerformancePreparationOutcome {
                await Task.detached {
                    AutonomousPerformancePreparer.prepareChainDiagnosing(request: input,
                        director: AutonomousSessionDirector(rootSeed: input.sourceState.rootSeed),
                        longHorizonPolicy: nil, makeEvaluator: { Evaluator(request: $0, control: Control()) },
                        cancellationRequested: { false })
                }.value
            }
            let ordinaryOutcome = await prepare(original)
            let ordinary = try #require(ordinaryOutcome.preparedPhrase)
            let chargedOutcome = await prepare(request)
            let charged = try #require(chargedOutcome.preparedPhrase)
            let referenceNodes = [ordinary] + ordinary.retainedContinuations
            let actualNodes = [charged] + charged.retainedContinuations
            #expect(actualNodes.count == referenceNodes.count && actualNodes.count > 1)
            #expect(actualNodes.allSatisfy { $0.prepared.commitEligible && $0.continuationOwnershipIsValid })
            for (actual, reference) in zip(actualNodes, referenceNodes) {
                #expect(actual.prepared.blocks == reference.prepared.blocks)
                #expect(actual.prepared.repeatHoldEvolutions == reference.prepared.repeatHoldEvolutions)
                #expect(actual.prepared.candidateEvaluationFingerprint == reference.prepared.candidateEvaluationFingerprint)
                #expect(actual.prepared.preparationReplayFingerprint == reference.prepared.preparationReplayFingerprint)
                #expect(actual.prepared.endingRenderState == reference.prepared.endingRenderState)
                #expect(actual.prepared.endingGraphState == reference.prepared.endingGraphState)
                #expect(actual.request.replayIdentity == reference.request.replayIdentity)
            }
            let expectedIncomingValue = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
                renderState: render, generatedDSPState: request.incomingGraphState,
                cancellationRequested: { false })
            let expectedIncoming = try #require(expectedIncomingValue)
            let ordinaryBudget = try #require(ordinary.preparationChainResourceBudget)
            let chargedBudget = try #require(charged.preparationChainResourceBudget)
            let delta = expectedIncoming - ordinaryBudget.retainedIncomingContinuationNumericByteCount
            #expect(delta == render.delayBuffer.capacity * MemoryLayout<Float>.stride)
            #expect(chargedBudget.retainedIncomingContinuationNumericByteCount == expectedIncoming)
            #expect(chargedBudget.reservedPeakWorkingByteCount - ordinaryBudget.reservedPeakWorkingByteCount == delta)
            #expect(chargedBudget.retainedNumericByteCount - ordinaryBudget.retainedNumericByteCount == delta)
            #expect(chargedBudget.sourceCount == ordinaryBudget.sourceCount)
            #expect(chargedBudget.maximumRenderPassCount == ordinaryBudget.maximumRenderPassCount)
            let exact = actualNodes.count == referenceNodes.count && zip(actualNodes, referenceNodes).allSatisfy { actual, reference in
                actual.prepared.blocks == reference.prepared.blocks &&
                actual.prepared.repeatHoldEvolutions == reference.prepared.repeatHoldEvolutions &&
                actual.prepared.candidateEvaluationFingerprint == reference.prepared.candidateEvaluationFingerprint &&
                actual.prepared.preparationReplayFingerprint == reference.prepared.preparationReplayFingerprint &&
                actual.prepared.endingRenderState == reference.prepared.endingRenderState &&
                actual.prepared.endingGraphState == reference.prepared.endingGraphState &&
                actual.request.replayIdentity == reference.request.replayIdentity &&
                actual.prepared.commitEligible && actual.continuationOwnershipIsValid
            }
            let report: [String: Any] = ["schema": "autotechno-incoming-storage-control.v1",
                "sampleRate": rate, "sources": actualNodes.count,
                "rootAllocatedContinuationChargeBytes": expectedIncoming,
                "unusedRootCapacityBytes": render.delayBuffer.capacity * MemoryLayout<Float>.stride,
                "peakReservationDeltaBytes": chargedBudget.reservedPeakWorkingByteCount - ordinaryBudget.reservedPeakWorkingByteCount,
                "retainedReservationDeltaBytes": chargedBudget.retainedNumericByteCount - ordinaryBudget.retainedNumericByteCount,
                "exactProductsProofStateReplayAndOwnership": exact,
                "sourceIdentities": actualNodes.map { $0.prepared.preparedValidationSourceIdentityFingerprint ?? "none" },
                "completeWorkingSetQualification": false, "runtimeActivation": false]
            print("AUTOTECHNO_INCOMING_STORAGE_CONTROL " + String(decoding:
                try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        }
    }

    @Test("Retained numeric storage shares the canonical typed inventory and counts buffer capacity")
    func typedRetainedStorageInventory() throws {
        let base = RenderState()
        let graph = GeneratedDSPContinuationState()
        let beforeCount = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
            renderState: base, generatedDSPState: graph, cancellationRequested: { false })
        let before = try #require(beforeCount)
        let fingerprint = AutonomousTypedFingerprint.renderDSPContinuation(renderState: base, generatedDSPState: graph)
        var buffer = [Float](); buffer.reserveCapacity(4_096); buffer.append(contentsOf: repeatElement(0, count: 1_024))
        var changed = base; changed.delayBuffer = buffer
        let afterCount = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
            renderState: changed, generatedDSPState: graph, cancellationRequested: { false })
        let after = try #require(afterCount)
        #expect(after - before == (buffer.capacity - base.delayBuffer.capacity) * MemoryLayout<Float>.stride)
        #expect(after >= buffer.capacity * MemoryLayout<Float>.stride)
        #expect(AutonomousTypedFingerprint.renderDSPContinuation(renderState: base, generatedDSPState: graph) == fingerprint)
        let cancelledCount = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(renderState: changed,
            generatedDSPState: graph, cancellationRequested: { true })
        #expect(cancelledCount == nil)
        var overflow = StreamingFNV1a(countingStorageOnly: true)
        overflow.floatStorage(capacity: Int.max)
        #expect(overflow.storageOverflow)
        let budget = try #require(AutonomousPreparationChainResourceBudget().reserving(sampleRate: 8_000, barCount: 4))
        #expect(budget.retainingCompletedSource(sampleRate: 8_000, barCount: 4,
            requiresQualifiedSuccessor: true, retainedContinuationNumericByteCount: -1) == nil)
        #expect(budget.retainingCompletedSource(sampleRate: 8_000, barCount: 4,
            requiresQualifiedSuccessor: true, retainedContinuationNumericByteCount: Int.max) == nil)
    }

    @Test("Pending validation retains exact PCM and diagnostic capture without playable authority")
    @MainActor
    func deferredFinalizerParity() throws {
        let request = Self.sourceRequest(rate: 8_000)
        let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
        let plan = director.plan(from: request.sourceState)
        let evaluator = Evaluator(request: request, control: Control(mode: .dropProof))
        let awaiting = Self.render(request, plan: plan, evaluator: evaluator, deferred: true, capture: true)
        guard case let .awaitingPreparedValidation(pending) = awaiting else {
            Issue.record("Canonical finalizer did not suspend"); return
        }
        #expect(awaiting.preparedPhrase == nil)
        #expect(pending.preview.hasProspectiveAcceptanceBinding)
        let before = pending.preview.sourceIdentityFingerprint
        let resumed = try #require(pending.resolving(nil, cancellationRequested: { false }).preparedPhrase)
        let ordinary = try #require(Self.render(request, plan: plan, evaluator: evaluator,
            deferred: false, capture: true).preparedPhrase)
        #expect(!resumed.commitEligible && !ordinary.commitEligible)
        #expect(resumed.blocks == ordinary.blocks)
        #expect(resumed.candidateEvaluationFingerprint == ordinary.candidateEvaluationFingerprint)
        #expect(resumed.qualityContinuationState == ordinary.qualityContinuationState)
        #expect(ProfessionalQualityModalSuccessorEvidence.identity(resumed) ==
            ProfessionalQualityModalSuccessorEvidence.identity(ordinary))
        #expect(resumed.diagnosticRoleStemCaptures == ordinary.diagnosticRoleStemCaptures)
        #expect(resumed.diagnosticRoleStemCaptures.count == plan.barCount)
        #expect(resumed.diagnosticRoleStemCaptures.allSatisfy { $0.frameCountsAreAligned })
        #expect(resumed.repeatHoldEvolutionEvidence == ordinary.repeatHoldEvolutionEvidence)
        #expect(resumed.repeatHoldEvolutions.isEmpty) // exact measured child is mandatory
        #expect(pending.preview.sourceIdentityFingerprint == before)
        let cancelled = pending.resolving(nil, cancellationRequested: { true })
        #expect(cancelled.failure?.code == .cancelled && cancelled.preparedPhrase == nil)
    }

    @Test("Actual three-rate chains render iteratively on the detached preparation thread")
    func actualIterativeChain() async throws {
        var rows: [[String: Any]] = []
        for rate in [8_000.0, 44_100.0, 48_000.0] {
            let request = Self.sourceRequest(rate: rate)
            let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
            let original = AutonomousCandidateFingerprint.sessionState(request.sourceState)
            let control = Control()
            let outcome = await Task.detached {
                AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
                    longHorizonPolicy: nil,
                    makeEvaluator: { Evaluator(request: $0, control: control) },
                    cancellationRequested: { control.cancelled })
            }.value
            let result = try #require(outcome.preparedPhrase,
                "Chain failed at \(rate): \(String(describing: outcome.failure))")
            let nodes = [result] + result.retainedContinuations
            #expect(nodes.count > 1)
            #expect(nodes.allSatisfy { $0.prepared.commitEligible })
            #expect(result.retainedContinuations.allSatisfy { $0.retainedContinuations.isEmpty })
            let resource = try #require(result.preparationChainResourceBudget)
            #expect(resource.sourceCount == nodes.count)
            #expect(control.terminals == nodes.map { $0.request.key.phraseIndex })
            let incomingCountValue = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
                renderState: request.incomingRenderState, generatedDSPState: request.incomingGraphState,
                cancellationRequested: { false })
            let incomingCount = try #require(incomingCountValue)
            var expected = try #require(AutonomousPreparationChainResourceBudget(
                incomingContinuationNumericByteCount: incomingCount))
            #expect(resource.retainedIncomingContinuationNumericByteCount == incomingCount)
            for (index, node) in nodes.enumerated() {
                expected = try #require(expected.reserving(sampleRate: rate, barCount: node.prepared.plan.barCount,
                    renderPassCount: node.prepared.correctionRenderCount + 1))
                let storageCount = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
                    renderState: node.prepared.endingRenderState,
                    generatedDSPState: node.prepared.endingGraphState, cancellationRequested: { false })
                let storage = try #require(storageCount)
                expected = try #require(expected.retainingCompletedSource(sampleRate: rate,
                    barCount: node.prepared.plan.barCount,
                    requiresQualifiedSuccessor: node.prepared.preparedValidation?.requiresQualifiedSuccessor == true,
                    retainedContinuationNumericByteCount: storage))
                #expect(node.prepared.preparationReplayFingerprint == node.request.replayIdentity.fingerprint)
                #expect(node.prepared.preparedValidation?.hasRequiredMeasurements == true)
                #expect(node.prepared.preparedValidation?.hasQualifiedContinuation == true)
                if index + 1 < nodes.count {
                    let child = nodes[index + 1]
                    let next = node.request.sourceState.advance(using: node.prepared.plan,
                        quality: node.prepared.qualityContinuationState,
                        liveMasterHeadroom: node.prepared.liveMasterHeadroomContinuationState)
                    #expect(AutonomousCandidateFingerprint.sessionState(next) ==
                        AutonomousCandidateFingerprint.sessionState(child.request.sourceState))
                    #expect(director.plan(from: next) == child.prepared.plan)
                    #expect(node.prepared.preparedValidation?.qualifiedSuccessor === child.prepared)
                    #expect(node.prepared.repeatHoldEvolutions.isEmpty)
                } else {
                    #expect(node.prepared.preparedValidation?.requiresQualifiedSuccessor == false)
                    #expect(node.prepared.preparedValidation?.qualifiedSuccessor == nil)
                }
            }
            #expect(expected == resource)
            var consumed = result
            var boundarySample: Int64 = 0
            for expectedChild in nodes.dropFirst() {
                #expect(consumed.requiresQualifiedContinuation && consumed.continuationOwnershipIsValid)
                let advanced = consumed.request.sourceState.advance(using: consumed.prepared.plan,
                    quality: consumed.prepared.qualityContinuationState,
                    liveMasterHeadroom: consumed.prepared.liveMasterHeadroomContinuationState,
                    longHorizonDecision: consumed.longHorizonDecision)
                boundarySample += Int64(consumed.prepared.audioPreflight.quality.analyzedFrameCount)
                let child = try #require(try consumed.continuationAtBoundary(sessionState: advanced,
                    longHorizonState: consumed.outgoingLongHorizonState, sampleRate: rate,
                    channelCount: 2, routeGeneration: 7, actualStartSample: boundarySample).get())
                #expect(child.prepared === expectedChild.prepared)
                #expect(child.request.replayIdentity == expectedChild.request.replayIdentity)
                #expect(child.waveforms == expectedChild.waveforms)
                #expect(child.prepared.blocks == expectedChild.prepared.blocks)
                #expect(child.continuationOwnershipIsValid)
                #expect(child.preparationChainResourceBudget == resource)
                consumed = child
            }
            #expect(!consumed.requiresQualifiedContinuation && consumed.retainedContinuations.isEmpty)
            let leafBoundary = try consumed.continuationAtBoundary(sessionState: consumed.request.sourceState,
                longHorizonState: consumed.outgoingLongHorizonState, sampleRate: rate,
                channelCount: 2, routeGeneration: 7, actualStartSample: boundarySample).get()
            #expect(leafBoundary == nil)
            let leaf = try #require(nodes.last)
            let ordinaryLeaf = try #require(Self.render(leaf.request, plan: leaf.prepared.plan,
                evaluator: Evaluator(request: leaf.request, control: Control()), deferred: false).preparedPhrase)
            #expect(ordinaryLeaf.blocks == leaf.prepared.blocks)
            #expect(ordinaryLeaf.repeatHoldEvolutions == leaf.prepared.repeatHoldEvolutions)
            #expect(AutonomousCandidateFingerprint.sessionState(request.sourceState) == original)
            rows.append(["sampleRate": rate, "sources": nodes.count,
                "barCounts": nodes.map { $0.prepared.plan.barCount },
                "sourceIdentities": nodes.map { ProfessionalQualityModalSuccessorEvidence.identity($0.prepared) },
                "sampleHashes": nodes.map { $0.prepared.audioPreflight.quality.sampleHash },
                "reservedPeakWorkingBytes": resource.reservedPeakWorkingByteCount,
                "maximumRenderPasses": resource.maximumRenderPassCount,
                "allCommitEligible": true, "qualifiedImmediateChildrenRetained": true])
        }
        let wire: [String: Any] = ["fixture": "iterative-canonical-successor-chain.v1", "rows": rows,
            "detachedThread": true, "qualification": "mechanical-only-not-installed",
            "runtimeActivation": false, "resourceSoakQualified": false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: wire, options: [.sortedKeys]), as: UTF8.self))
    }

    @Test("Protected continuation refuses missing ownership, stale state and routes without replacing its child")
    func protectedBoundaryRefusal() async throws {
        let request = Self.sourceRequest(rate: 8_000)
        let control = Control()
        let result = await Task.detached {
            AutonomousPerformancePreparer.prepareChainDiagnosing(request: request,
                director: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed), longHorizonPolicy: nil,
                makeEvaluator: { Evaluator(request: $0, control: control) }, cancellationRequested: { false })
        }.value
        let root = try #require(result.preparedPhrase)
        let child = try #require(root.retainedContinuations.first)
        #expect(root.continuationOwnershipIsValid)
        let advanced = request.sourceState.advance(using: root.prepared.plan,
            quality: root.prepared.qualityContinuationState,
            liveMasterHeadroom: root.prepared.liveMasterHeadroomContinuationState)
        let artifacts = try qualifiedArtifacts()
        let policy = try LongHorizonProfessionalPolicy(profile: artifacts.profile,
            adversarial: artifacts.adversarial, holdout: artifacts.holdout)
        let foreignLong = try #require(LongHorizonFutureAdaptationState(startingState: advanced, policy: policy))
        for (state, horizon, rate, channels, generation, expected) in [
            (request.sourceState, nil, 8_000.0, 2, 7, "state-mismatch"),
            (advanced, foreignLong, 8_000.0, 2, 7, "state-mismatch"),
            (advanced, nil, 8_001.0, 2, 7, "route-mismatch"),
            (advanced, nil, 8_000.0, 1, 7, "route-mismatch"),
            (advanced, nil, 8_000.0, 2, 8, "route-mismatch"),
        ] {
            let outcome = root.continuationAtBoundary(sessionState: state,
                longHorizonState: horizon, sampleRate: rate, channelCount: channels,
                routeGeneration: generation, actualStartSample: 1_000_000)
            guard case let .failure(failure) = outcome else {
                Issue.record("Foreign continuation boundary was admitted"); continue
            }
            #expect(failure.code == expected)
        }
        let stripped = PreparedPerformancePhrase(request: root.request, prepared: root.prepared,
            outgoingLongHorizonState: root.outgoingLongHorizonState, longHorizonDecision: root.longHorizonDecision,
            waveforms: root.waveforms)
        #expect(!stripped.continuationOwnershipIsValid && stripped.requiresQualifiedContinuation)
        let malformed = PreparedPerformancePhrase(request: root.request, prepared: root.prepared,
            outgoingLongHorizonState: root.outgoingLongHorizonState, longHorizonDecision: root.longHorizonDecision,
            waveforms: root.waveforms, retainedContinuations: [root])
        #expect(!malformed.continuationOwnershipIsValid)
        let first = try #require(try root.continuationAtBoundary(sessionState: advanced,
            longHorizonState: nil, sampleRate: 8_000, channelCount: 2, routeGeneration: 7,
            actualStartSample: 1_000_000).get())
        let second = try #require(try root.continuationAtBoundary(sessionState: advanced,
            longHorizonState: nil, sampleRate: 8_000, channelCount: 2, routeGeneration: 7,
            actualStartSample: 1_000_000).get())
        #expect(first.prepared === child.prepared && second.prepared === child.prepared)
        #expect(root.retainedContinuations.first?.prepared === child.prepared)
        #expect(control.terminals == [21, 22]) // no transport rendering or substitute
        print("{\"fixture\":\"protected-continuation-boundary.v1\",\"missingOwnershipRefused\":true,\"staleCoreLongAndRouteRefused\":true,\"exactChildRetained\":true,\"repeatCannotReplaceChild\":true,\"runtimeActivation\":false}")
    }

    @Test("Applied live source protects its exact child at the known future sample boundary")
    func protectedAppliedLiveBoundary() async throws {
        let base = Self.sourceRequest(rate: 48_000)
        let director = AutonomousSessionDirector(rootSeed: base.sourceState.rootSeed)
        var previous = director.initialState()
        for _ in 0..<20 { previous.advancePlanning(using: director.plan(from: previous)) }
        let previousPlan = director.plan(from: previous)
        let frames = try #require(LiveOutputWindowAnalyzer.frameCount(sampleRate: 48_000))
        let signal = (0..<frames).map { Float(0.2 * sin(2 * Double.pi * 997 * Double($0) / 48_000)) }
        let analyzed = LiveFeedbackTestSupport.analyze(signal: signal, plan: previousPlan,
            sampleRate: 48_000, routeGeneration: 7, controllerRevision: base.sourceState.liveMasterHeadroom.revision,
            qualityPolicyVersion: LiveFeedbackTestSupport.fingerprintQualifiedPolicyVersion)
        let evidence = try #require(analyzed)
        let target = try #require(LiveFeedbackTestSupport.target(evidence: evidence,
            loudnessUpperLUFS: evidence.maximumShortTermLoudnessLUFS - 1,
            truePeakUpperDBTP: evidence.truePeakDBTP - 1,
            profileFingerprint: LiveFeedbackTestSupport.profileFingerprint))
        let start = evidence.playerSampleRange.upperBound + 10_000
        let proposal = LiveMasterHeadroomController.propose(evidence: evidence, target: target,
            incoming: base.sourceState.liveMasterHeadroom, earliestEligibleFutureSample: start)
        #expect(proposal.outcome == .attenuate)
        let binding = PendingLiveMasterHeadroomBinding(sourceIdentity: LiveOutputPlanSourceIdentity(plan: previousPlan),
            evidence: evidence, target: target, proposal: proposal,
            eligibleTarget: LiveMasterHeadroomEligibleTarget(plan: director.plan(from: base.sourceState),
                routeGeneration: 7, sampleRate: 48_000, earliestEligibleFutureSample: start,
                qualityPolicyVersion: evidence.qualityPolicyVersion, evaluatorVersion: evidence.evaluatorVersion,
                controllerPolicyVersion: evidence.controllerPolicyVersion))
        let key = PhrasePreparationKey(sessionSeed: base.key.sessionSeed, phraseIndex: base.key.phraseIndex,
            sampleRate: 48_000, channelCount: 2, routeRecovery: false,
            qualityRevision: base.key.qualityRevision, qualityPolicyVersion: base.key.qualityPolicyVersion,
            qualityControllerFingerprint: base.key.qualityControllerFingerprint, routeGeneration: 7,
            incomingLiveMasterRevision: base.key.incomingLiveMasterRevision,
            incomingLiveMasterStateFingerprint: base.key.incomingLiveMasterStateFingerprint,
            pendingLiveMasterProposalFingerprint: proposal.fingerprint,
            liveEarliestEligibleFutureSample: start, liveTargetStartSample: start)
        let request = PhrasePreparationRequest(key: key, sourceState: base.sourceState,
            incomingLongHorizonState: nil, incomingRenderState: base.incomingRenderState,
            incomingGraphState: base.incomingGraphState, previousGraph: base.previousGraph,
            pendingLiveMasterBinding: binding)
        let control = Control()
        let result = await Task.detached {
            AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
                longHorizonPolicy: nil, makeEvaluator: { Evaluator(request: $0, control: control,
                    policyVersion: LiveFeedbackTestSupport.fingerprintQualifiedPolicyVersion) },
                cancellationRequested: { false })
        }.value
        let root = try #require(result.preparedPhrase)
        #expect(root.continuationOwnershipIsValid && root.requiresQualifiedContinuation)
        #expect(root.prepared.liveMasterHeadroomContinuationState.committedTrimDB == -0.25)
        let advanced = request.sourceState.advance(using: root.prepared.plan,
            quality: root.prepared.qualityContinuationState,
            liveMasterHeadroom: root.prepared.liveMasterHeadroomContinuationState)
        let end = start + Int64(root.prepared.audioPreflight.quality.analyzedFrameCount)
        for actual in [end - 1, end + 1, 0] {
            guard case let .failure(failure) = root.continuationAtBoundary(sessionState: advanced,
                longHorizonState: nil, sampleRate: 48_000, channelCount: 2, routeGeneration: 7,
                actualStartSample: actual) else { Issue.record("Shifted live boundary admitted"); continue }
            #expect(failure.code == "sample-boundary")
        }
        let child = try #require(try root.continuationAtBoundary(sessionState: advanced,
            longHorizonState: nil, sampleRate: 48_000, channelCount: 2, routeGeneration: 7,
            actualStartSample: end).get())
        #expect(child.prepared === root.prepared.preparedValidation?.qualifiedSuccessor)
        #expect(child.request.pendingLiveMasterBinding == nil && child.prepared.liveTargetStartSample == nil)
        #expect(child.prepared.incomingLiveMasterHeadroomState == root.prepared.liveMasterHeadroomContinuationState)
        #expect(child.prepared.liveMasterHeadroomContinuationState == root.prepared.liveMasterHeadroomContinuationState)
    }

    @Test("Rejected or missing child proof and cancellation discard the entire tentative chain")
    func childRefusalAndCancellation() async throws {
        let request = Self.sourceRequest(rate: 8_000)
        let original = AutonomousCandidateFingerprint.sessionState(request.sourceState)
        for mode in [Control.Mode.rejectChild, .dropChildProof, .cancelOnValidation] {
            let control = Control(mode: mode)
            let outcome = await Task.detached {
                AutonomousPerformancePreparer.prepareChainDiagnosing(request: request,
                    director: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed),
                    longHorizonPolicy: nil, makeEvaluator: { Evaluator(request: $0, control: control) },
                    cancellationRequested: { control.cancelled })
            }.value
            #expect(outcome.preparedPhrase == nil)
            #expect(outcome.failure?.code == (mode == .cancelOnValidation ? "cancelled" : "successor-rejected"))
            #expect(control.terminals.count > 1)
            #expect(AutonomousCandidateFingerprint.sessionState(request.sourceState) == original)
        }
        let control = Control()
        let large = Self.sourceRequest(rate: 192_000)
        let outcome = AutonomousPerformancePreparer.prepareChainDiagnosing(request: large,
            director: AutonomousSessionDirector(rootSeed: large.sourceState.rootSeed), longHorizonPolicy: nil,
            makeEvaluator: { Evaluator(request: $0, control: control) }, cancellationRequested: { false })
        #expect(outcome.preparedPhrase == nil && outcome.failure?.code == "resource-bound")
        #expect(control.terminals.isEmpty)
    }

    @Test("A corrective render cannot allocate before the aggregate owner grants its second pass")
    @MainActor
    func correctionReservationPrecedesPCM() throws {
        let request = Self.sourceRequest(rate: 8_000)
        let plan = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed).plan(from: request.sourceState)
        let control = Control(mode: .forceCorrection)
        let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(plan: plan,
            sessionSeed: request.sourceState.rootSeed, memory: request.sourceState.memory,
            sampleRate: request.key.sampleRate, incomingRenderState: request.incomingRenderState,
            incomingGraphState: request.incomingGraphState, previousGraph: request.previousGraph,
            incomingQualityState: request.sourceState.quality, routeGeneration: request.key.routeGeneration,
            evaluator: Evaluator(request: request, control: control), deferPreparedValidation: true,
            renderPassReservation: { count in control.reserve(count) }, cancellationRequested: { false })
        #expect(outcome.preparedPhrase == nil)
        #expect(outcome.failure?.code == .renderBudgetUnavailable)
        #expect(control.claims == [1, 2])
        #expect(control.terminals.isEmpty)
        #expect(request.sourceState.quality.revision == 0)
    }

    @Test("A measured root rejection preserves canonical recovery without releasing child ownership")
    func rootRejectionPreservesRecovery() async throws {
        let request = Self.sourceRequest(rate: 8_000)
        let control = Control(mode: .rejectRoot)
        let outcome = await Task.detached {
            AutonomousPerformancePreparer.prepareChainDiagnosing(request: request,
                director: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed),
                longHorizonPolicy: nil, makeEvaluator: { Evaluator(request: $0, control: control) },
                cancellationRequested: { false })
        }.value
        let root = try #require(outcome.preparedPhrase)
        #expect(!root.prepared.commitEligible)
        #expect(root.prepared.qualityDecision.outcome == .rejected)
        #expect(root.prepared.qualityDecision.reasonCodes.contains(.guardrailRegressionV1))
        #expect(root.prepared.qualityContinuationState.acceptedEvidenceFingerprint ==
            request.sourceState.quality.acceptedEvidenceFingerprint)
        #expect(root.retainedContinuations.isEmpty)
        #expect(control.terminals.count > 1)
        #expect(root.prepared.preparedValidation?.hasRequiredMeasurements == true)
    }


    private struct StreamedChainControl: Equatable, Codable {
        let sampleHashes: [String]
        let transactionHashes: [String]
        let sourceIdentities: [String?]
        let outgoingRender: [String]
        let outgoingGraph: [String]
        let quality: [QualityContinuationState]
        let blockFingerprints: [[String]]
        let holdFingerprints: [[[String]]]
    }

    private static func reducedControl(_ result: PreparedPerformancePhrase) -> StreamedChainControl {
        let sources = ([result] + result.retainedContinuations).map(\.prepared)
        return StreamedChainControl(sampleHashes: sources.map { $0.selectedCandidateEvidence.fullMix.sampleHash },
            transactionHashes: sources.map(\.candidateEvaluationFingerprint),
            sourceIdentities: sources.map(\.preparedValidationSourceIdentityFingerprint),
            outgoingRender: sources.map { AutonomousCandidateFingerprint.renderState($0.endingRenderState) },
            outgoingGraph: sources.map { AutonomousCandidateFingerprint.generatedDSPState($0.endingGraphState) },
            quality: sources.map(\.qualityContinuationState),
            blockFingerprints: sources.map { $0.blocks.map { ExactPCMFingerprint.stereo(left: $0.left, right: $0.right) } },
            holdFingerprints: sources.map { $0.repeatHoldEvolutions.map { $0.blocks.map {
                ExactPCMFingerprint.stereo(left: $0.left, right: $0.right)
            } } })
    }

    private static func captureParent() throws -> URL {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(
            "autotechno-selected-stream-test-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        return parent
    }

    private struct NativeChainReference: Sendable {
        let products: StreamedChainControl?
        let reservation: AutonomousPreparationChainResourceBudget?
        let stage: String?
        let code: String?
        let details: [String]?
        let terminals: [Int]
    }

    // Shared by the observed test and its ordinary-only process control. Only
    // reduced evidence survives the worker; no probe, capture or PCM is retained.
    private static func nativeChainReference(request: PhrasePreparationRequest,
        director: AutonomousSessionDirector, mode: Control.Mode) async -> NativeChainReference {
        await Task.detached {
            let control = Control(mode: mode)
            let outcome = AutonomousPerformancePreparer.prepareChainDiagnosing(
                request: request, director: director, longHorizonPolicy: nil,
                makeEvaluator: { Evaluator(request: $0, control: control) }, cancellationRequested: { false })
            return NativeChainReference(products: outcome.preparedPhrase.map(Self.reducedControl),
                reservation: outcome.preparedPhrase?.preparationChainResourceBudget,
                stage: outcome.failure?.stage, code: outcome.failure?.code,
                details: outcome.failure?.details, terminals: control.terminals)
        }.value
    }

    private static func printNativeReference(_ reference: NativeChainReference,
        rate: Double, correction: Bool) throws {
        var reservation: [String: Int] = [:]
        if let budget = reference.reservation {
            reservation = ["reservedPeakWorkingByteCount": budget.reservedPeakWorkingByteCount,
                "retainedNumericByteCount": budget.retainedNumericByteCount,
                "retainedIncomingContinuationNumericByteCount": budget.retainedIncomingContinuationNumericByteCount,
                "sourceCount": budget.sourceCount, "maximumRenderPassCount": budget.maximumRenderPassCount]
        }
        let report: [String: Any] = ["schema": "autotechno-native-chain-reference.v1",
            "sampleRate": rate, "selectedCorrection": correction,
            "products": try JSONSerialization.jsonObject(with: JSONEncoder().encode(reference.products), options: [.fragmentsAllowed]),
            "publicReservationFields": reservation, "terminals": reference.terminals,
            "failureStage": reference.stage ?? "none", "failureCode": reference.code ?? "none",
            "failureDetails": reference.details ?? [], "qualification": "mechanical-only-not-installed",
            "completeWorkingSetQualification": false, "nativeSelectedStreamCaptureCapacityQualified": false]
        print("AUTOTECHNO_NATIVE_CHAIN_REFERENCE " + String(decoding:
            try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }

    @Test("Ordinary native chain control retains no storage observer or full snapshot report")
    func nativeChainOrdinaryProcessControl() async throws {
        for rate in [44_100.0, 48_000.0] {
            for mode in [Control.Mode.accept, .forceCorrection] {
                let request = Self.sourceRequest(rate: rate)
                let original = AutonomousCandidateFingerprint.sessionState(request.sourceState)
                let reference = await Self.nativeChainReference(request: request,
                    director: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed), mode: mode)
                #expect(AutonomousCandidateFingerprint.sessionState(request.sourceState) == original)
                if mode == .accept {
                    let products = try #require(reference.products)
                    let reservation = try #require(reference.reservation)
                    #expect(products.sampleHashes.count == 2 && products.sourceIdentities.allSatisfy { $0 != nil })
                    #expect(reservation.sourceCount == 2 && reference.stage == nil && reference.code == nil)
                } else {
                    #expect(reference.products == nil && reference.reservation == nil)
                    #expect(reference.stage == "successor-chain" && reference.code == "resource-bound")
                }
                try Self.printNativeReference(reference, rate: rate, correction: mode == .forceCorrection)
            }
        }
    }

    @Test("Native chain observations preserve exact admission and bounded corrective refusal")
    func nativeChainStorageObservations() async throws {
        for rate in [44_100.0, 48_000.0] {
            for mode in [Control.Mode.accept, .forceCorrection] {
                let request = Self.sourceRequest(rate: rate)
                let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
                let original = AutonomousCandidateFingerprint.sessionState(request.sourceState)
                let processMemoryBefore = try DiagnosticRoleStemStreamingTests.nativeProcessMemoryObservation()
                let reference = await Self.nativeChainReference(request: request,
                    director: director, mode: mode)
                // Only reduced evidence crosses into the observed call; the
                // ordinary arrays and continuation leave scope beforehand.
                let probe = PreparationWorkingStorageProbe(), control = Control(mode: mode)
                let outcome = await Task.detached {
                    AutonomousPerformancePreparer.prepareChainDiagnosing(
                        request: request, director: director, longHorizonPolicy: nil, workingStorageProbe: probe,
                        makeEvaluator: { Evaluator(request: $0, control: control) }, cancellationRequested: { false })
                }.value
                let exact = outcome.preparedPhrase.map(Self.reducedControl) == reference.products &&
                    outcome.preparedPhrase?.preparationChainResourceBudget == reference.reservation &&
                    outcome.failure?.stage == reference.stage && outcome.failure?.code == reference.code &&
                    outcome.failure?.details == reference.details && control.terminals == reference.terminals &&
                    AutonomousCandidateFingerprint.sessionState(request.sourceState) == original
                #expect(exact)
                try Self.printNativeReference(reference, rate: rate, correction: mode == .forceCorrection)
                #expect(probe.valid && probe.observationCount > 0 && probe.snapshots.allSatisfy { $0.valid })
                try DiagnosticRoleStemStreamingTests.checkAnalyzerStorage(probe,
                    prefix: "chain.render.analysis", sampleRate: rate)
                #expect(probe.snapshots.filter { $0.phase.hasPrefix("chain.render.analysis.") }.allSatisfy {
                    $0.ownerRecords.contains { $0.owner.hasPrefix("attempt.analysis-product.primary") && $0.capacityBytes > 0 }
                })
                var sourceIdentities: [String] = []
                if mode == .accept {
                    let result = try #require(outcome.preparedPhrase)
                    try Self.checkChainStorage(probe, correction: false)
                    let sources = [result] + result.retainedContinuations
                    #expect(sources.count == 2 && result.prepared.preparedValidation?.qualifiedSuccessor === sources[1].prepared)
                    #expect(sources.allSatisfy { $0.prepared.commitEligible && $0.prepared.diagnosticRoleStemCaptures.isEmpty })
                    sourceIdentities = sources.map { $0.prepared.preparedValidationSourceIdentityFingerprint ?? "none" }
                } else {
                    #expect(outcome.preparedPhrase == nil)
                    #expect(outcome.failure?.stage == "successor-chain" && outcome.failure?.code == "resource-bound")
                    #expect(probe.snapshots.contains { $0.phase == "chain.before-correction" })
                    #expect(probe.snapshots.contains { $0.phase == "chain.corrective-overlap" &&
                        $0.observedPhase?.hasPrefix("chain.render.") == true && $0.ownerRecords.contains {
                        $0.owner.hasPrefix("attempt.incoming")
                    } && !$0.ownerRecords.contains {
                        $0.owner.hasPrefix("attempt.retained-initial.primary") ||
                            $0.owner.hasPrefix("attempt.retained-initial.continuation")
                    } })
                    let released = try #require(probe.snapshots.first { $0.phase == "chain.superseded-release" })
                    #expect(!released.ownerRecords.contains { $0.owner.hasPrefix("attempt.retained-initial") })
                    #expect(!probe.snapshots.contains { $0.phase == "chain.reduced" })
                }
                let report: [String: Any] = ["schema": "autotechno-chain-storage-control.v2",
                    "sampleRate": rate, "sources": sourceIdentities.count, "admitted": outcome.preparedPhrase != nil,
                    "processMemoryBefore": processMemoryBefore,
                    "processMemoryAfter": try DiagnosticRoleStemStreamingTests.nativeProcessMemoryObservation(),
                    "processMemoryAvailable": !processMemoryBefore.isEmpty,
                    "allocatorScope": "currently-registered-all-malloc-zone-high-water-sum-not-phase-exclusive",
                    "allocatorExcludes": ["destroyed-zones", "non-malloc-virtual-memory"],
                    "allocatorCompleteNumericAttribution": false,
                    "selectedCorrection": mode == .forceCorrection, "observations": probe.observationCount,
                    "phaseObservationCounts": probe.phaseObservationCounts,
                    "snapshots": try JSONSerialization.jsonObject(with: JSONEncoder().encode(probe.snapshots)),
                    "exactOutcomeProductsStateAndReservation": exact,
                    "failureStage": outcome.failure?.stage ?? "none", "failureCode": outcome.failure?.code ?? "none",
                    "failureDetails": outcome.failure?.details ?? [],
                    "actualQualifiedChildIdentity": sourceIdentities.last ?? "none", "sourceIdentities": sourceIdentities,
                    "qualification": "mechanical-only-not-installed", "samePassRoleCapture": false,
                    "completeWorkingSetQualification": false, "nativeSelectedStreamCaptureCapacityQualified": false,
                    "instrumentationMayExtendObservedLifetimes": true]
                print("AUTOTECHNO_CHAIN_STORAGE_CONTROL " + String(decoding:
                    try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
            }
        }
    }

    private static func checkChainStorage(_ probe: PreparationWorkingStorageProbe, correction: Bool) throws {
        #expect(probe.valid && probe.observationCount > 0)
        #expect(probe.snapshots.allSatisfy { $0.valid && $0.typedMetadataHeadroomBytes > 0 })
        let phases = Set(probe.snapshots.map(\.phase))
        for name in ["chain.incoming", "chain.selected", "chain.suspended", "chain.reduced",
            "chain.render.analysis-input", "chain.render.bar-delivery", "chain.render.full-voice.product",
            "chain.render.generated-graph.current.node-return"] {
            #expect(phases.contains(name))
        }
        #expect(phases.contains("chain.before-correction") == correction)
        let incoming = try #require(probe.snapshots.first { $0.phase == "chain.incoming" })
        #expect(incoming.ownerRecords.contains { $0.owner.hasPrefix("chain.parent.0.primary") && $0.capacityBytes > 0 })
        let suspended = try #require(probe.snapshots.first { $0.phase == "chain.suspended" })
        #expect(suspended.ownerRecords.contains { $0.owner.hasPrefix("chain.frame.0.primary") && $0.capacityBytes > 0 })
        #expect(suspended.ownerRecords.contains { $0.owner.hasPrefix("chain.frame.1.primary") && $0.capacityBytes > 0 })
        let reduced = try #require(probe.snapshots.first { $0.phase == "chain.reduced" })
        #expect(reduced.ownerRecords.contains { $0.owner.hasPrefix("chain.reduced.0.primary") && $0.capacityBytes > 0 && $0.aliasOf != nil })
        if correction {
            let before = try #require(probe.snapshots.first { $0.phase == "chain.before-correction" })
            #expect(before.ownerRecords.contains { $0.owner.hasPrefix("attempt.retained-initial.primary") && $0.capacityBytes > 0 })
            #expect(!before.ownerRecords.contains { $0.owner.hasPrefix("attempt.retained-initial.hold") || $0.owner.hasPrefix("attempt.retained-initial.capture") })
            let released = try #require(probe.snapshots.first { $0.phase == "chain.superseded-release" })
            #expect(!released.ownerRecords.contains { $0.owner.hasPrefix("attempt.retained-initial") })
            #expect(probe.snapshots.contains { snapshot in snapshot.phase == "chain.corrective-overlap" &&
                snapshot.observedPhase?.hasPrefix("chain.render.") == true &&
                snapshot.ownerRecords.contains { $0.owner.hasPrefix("attempt.incoming") } &&
                !snapshot.ownerRecords.contains { $0.owner.hasPrefix("attempt.retained-initial.primary") ||
                    $0.owner.hasPrefix("attempt.retained-initial.continuation") } })
        }
    }

    @Test("Selected initial and corrected drafts bind exact root-child objects and unchanged products")
    func selectedStreamedChain() async throws {
        for mode in [Control.Mode.accept, .forceCorrection] {
            let request = Self.sourceRequest(rate: 8_000)
            let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
            let original = AutonomousCandidateFingerprint.sessionState(request.sourceState)
            let reference: StreamedChainControl = try await Task.detached {
                let control = Control(mode: mode)
                let result = try #require(AutonomousPerformancePreparer.prepareChainDiagnosing(
                    request: request, director: director, longHorizonPolicy: nil,
                    makeEvaluator: { Evaluator(request: $0, control: control) },
                    cancellationRequested: { false }).preparedPhrase)
                return Self.reducedControl(result)
            }.value
            // The ordinary reference retains only reduced identities. Its PCM
            // and continuation arrays leave scope before the streamed prepare.
            let parent = try Self.captureParent(); defer { try? FileManager.default.removeItem(at: parent) }
            let session = DiagnosticRoleStemCaptureSession(parentDirectory: parent)
            let control = Control(mode: mode)
            let probe = PreparationWorkingStorageProbe()
            let outcome = await Task.detached {
                AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
                    longHorizonPolicy: nil, diagnosticRoleStemSession: session, workingStorageProbe: probe,
                    makeEvaluator: { Evaluator(request: $0, control: control) },
                    cancellationRequested: { false })
            }.value
            let result = try #require(outcome.preparedPhrase, "Streamed chain: \(String(describing: outcome.failure))")
            let sources = ([result] + result.retainedContinuations).map(\.prepared)
            #expect(sources.count == 2 && session.isSealed)
            try Self.checkChainStorage(probe, correction: mode == .forceCorrection)
            #expect(Self.reducedControl(result) == reference)
            #expect(sources.allSatisfy { $0.diagnosticRoleStemCaptures.isEmpty && $0.commitEligible })
            #expect(session.bindings.count == sources.count)
            #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).count == sources.count)
            #expect(session.discardedSupersededDraftCount == (mode == .forceCorrection ? sources.count : 0))
            #expect(sources[0].preparedValidation?.qualifiedSuccessor === sources[1])
            for (index, binding) in session.bindings.enumerated() {
                let source = sources[index]
                #expect(binding.sourceIdentityFingerprint == source.preparedValidationSourceIdentityFingerprint)
                #expect(binding.transactionFingerprint == source.candidateEvaluationFingerprint)
                #expect(binding.candidateFingerprint == source.selectedCandidateEvidence.fullMix.sampleHash)
                #expect(binding.planFingerprint == AutonomousCandidateFingerprint.plan(source.plan))
                #expect(binding.replayFingerprint == source.preparationReplayFingerprint)
                #expect(binding.graphFingerprint == AutonomousCandidateFingerprint.graph(source.graph))
                #expect(binding.routeFingerprint == source.selectedCandidateEvidence.routeContinuation.routeFingerprint)
                #expect(binding.endingRenderStateFingerprint == reference.outgoingRender[index])
                #expect(binding.endingGraphStateFingerprint == reference.outgoingGraph[index])
                #expect(binding.selectedAttemptKind == (mode == .forceCorrection ? .correctionRender : .initialRender))
                #expect(binding.forceHomeUpperTimbre == (mode == .forceCorrection))
                #expect(binding.qualifiedChildIdentityFingerprint == (index == 0 ? sources[1].preparedValidationSourceIdentityFingerprint : nil))
                #expect(binding.draft.records.count == source.blocks.count)
                for (ordinal, record) in binding.draft.records.enumerated() {
                    #expect(record.channelFingerprints.count == 32)
                    #expect(record.outputFingerprint == ExactPCMFingerprint.stereo(
                        left: source.blocks[ordinal].left, right: source.blocks[ordinal].right))
                    // Every channel is readable/hash-checked on the selected
                    // actual pass, including silent protected and residual taps.
                    for channel in DiagnosticRoleStemChannel.allCases {
                        #expect(try binding.draft.readChannel(barIndex: ordinal, channel: channel).count == record.frameCount)
                    }
                }
            }
            let before = control.terminals
            let reused = AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
                longHorizonPolicy: nil, diagnosticRoleStemSession: session,
                makeEvaluator: { Evaluator(request: $0, control: control) }, cancellationRequested: { false })
            #expect(reused.failure?.code == "diagnostic-session-unavailable")
            #expect(control.terminals == before && session.bindings.count == 2 && session.isSealed)
            #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).count == 2)
            #expect(AutonomousCandidateFingerprint.sessionState(request.sourceState) == original)
            let report: [String: Any] = ["schema": "autotechno-selected-stream-control.v1",
                "sampleRate": request.key.sampleRate, "sources": sources.count,
                "selectedCorrection": mode == .forceCorrection,
                "discardedSupersededDraftCount": session.discardedSupersededDraftCount,
                "exactProductsAndState": Self.reducedControl(result) == reference,
                "sourceIdentities": session.bindings.map(\.sourceIdentityFingerprint),
                "transactionFingerprints": session.bindings.map(\.transactionFingerprint),
                "qualifiedChildIdentity": session.bindings.first?.qualifiedChildIdentityFingerprint ?? "none",
                "qualification": "mechanical-only-not-installed", "nativeCaptureCapacityQualified": false]
            print("AUTOTECHNO_SELECTED_STREAM_CONTROL " + String(decoding:
                try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        }
    }

    @Test("Rejected unavailable and cancelled chains discard every private capture")
    func rejectedStreamedChains() async throws {
        let request = Self.sourceRequest(rate: 8_000)
        let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
        for mode in [Control.Mode.dropProof, .rejectChild, .dropChildProof, .cancelOnValidation, .rejectRoot] {
            let parent = try Self.captureParent(); defer { try? FileManager.default.removeItem(at: parent) }
            let marker = parent.appendingPathComponent("unrelated-marker")
            try Data([42]).write(to: marker)
            let session = DiagnosticRoleStemCaptureSession(parentDirectory: parent)
            let control = Control(mode: mode)
            let outcome = await Task.detached {
                AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
                    longHorizonPolicy: nil, diagnosticRoleStemSession: session,
                    makeEvaluator: { Evaluator(request: $0, control: control) },
                    cancellationRequested: { control.cancelled })
            }.value
            #expect(outcome.preparedPhrase?.prepared.commitEligible != true)
            #expect(!session.isSealed && session.bindings.isEmpty)
            #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path) == ["unrelated-marker"])
            #expect(try Data(contentsOf: marker) == Data([42]))
        }
    }

    @Test("Native full-capture reservations refuse streaming before any attempted file or PCM")
    func nativeStreamResourceRefusal() throws {
        for rate in [44_100.0, 48_000.0] {
            let request = Self.sourceRequest(rate: rate)
            let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
            let parent = try Self.captureParent(); defer { try? FileManager.default.removeItem(at: parent) }
            let session = DiagnosticRoleStemCaptureSession(parentDirectory: parent)
            let control = Control()
            let result = AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
                longHorizonPolicy: nil, diagnosticRoleStemSession: session,
                makeEvaluator: { Evaluator(request: $0, control: control) }, cancellationRequested: { false })
            #expect(result.failure?.code == "resource-bound")
            #expect(control.terminals.isEmpty && session.bindings.isEmpty && !session.isSealed)
            #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
            #expect(AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount == 128 * 1_024 * 1_024)
        }
    }

    @Test("Sealed diagnostic drafts outlive session metadata without retaining scheduled ownership")
    func sealedStreamFileLifetime() async throws {
        let parent = try Self.captureParent(); defer { try? FileManager.default.removeItem(at: parent) }
        let bindings: [DiagnosticRoleStemSelectedBinding] = try await Task.detached {
            let request = Self.sourceRequest(rate: 8_000)
            let director = AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed)
            let session = DiagnosticRoleStemCaptureSession(parentDirectory: parent)
            let control = Control()
            let outcome = AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
                longHorizonPolicy: nil, diagnosticRoleStemSession: session,
                makeEvaluator: { Evaluator(request: $0, control: control) }, cancellationRequested: { false })
            let prepared = try #require(outcome.preparedPhrase)
            #expect(prepared.prepared.commitEligible)
            #expect(session.isSealed)
            return session.bindings
        }.value
        #expect(bindings.count == 2)
        for binding in bindings {
            #expect(FileManager.default.fileExists(atPath: binding.draft.directory.path))
            #expect(try binding.draft.readChannel(barIndex: 0, channel: .fullKick).count > 0)
        }
    }

    static func sourceRequest(rate: Double) -> PhrasePreparationRequest {
        let director = AutonomousSessionDirector(rootSeed: 48_300)
        var state = director.initialState()
        for _ in 0..<21 { state.advancePlanning(using: director.plan(from: state)) }
        var render = RenderState(); render.barIndex = state.memory.totalBars
        let key = PhrasePreparationKey(sessionSeed: state.rootSeed, phraseIndex: state.phraseIndex,
            sampleRate: rate, channelCount: 2, routeRecovery: false,
            qualityRevision: state.quality.revision, qualityPolicyVersion: state.quality.policyVersion,
            qualityControllerFingerprint: state.quality.observedControllerStateFingerprint ?? state.quality.acceptedControllerStateFingerprint,
            routeGeneration: 7, incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
            incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
            pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil, liveTargetStartSample: nil)
        return PhrasePreparationRequest(key: key, sourceState: state, incomingLongHorizonState: nil,
            incomingRenderState: render, incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil, pendingLiveMasterBinding: nil)
    }

    private static func render(_ request: PhrasePreparationRequest, plan: AutonomousPhrasePlan,
        evaluator: Evaluator, deferred: Bool, capture: Bool = false) -> AutonomousPhrasePreparationOutcome {
        AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(plan: plan,
            sessionSeed: request.sourceState.rootSeed, memory: request.sourceState.memory,
            sampleRate: request.key.sampleRate, incomingRenderState: request.incomingRenderState,
            incomingGraphState: request.incomingGraphState, previousGraph: request.previousGraph,
            incomingQualityState: request.sourceState.quality, routeGeneration: request.key.routeGeneration,
            diagnosticRoleStemCapture: capture, evaluator: evaluator,
            deferPreparedValidation: deferred, cancellationRequested: { false })
    }

    private final class Control: @unchecked Sendable {
        enum Mode: Sendable { case accept, dropProof, rejectRoot, rejectChild, dropChildProof, cancelOnValidation, forceCorrection }
        let mode: Mode
        private let lock = NSLock()
        private var sourcePhrases: [Int] = []
        private var cancellation = false
        private var renderClaims: [Int] = []
        init(mode: Mode = .accept) { self.mode = mode }
        var terminals: [Int] { lock.lock(); defer { lock.unlock() }; return sourcePhrases }
        var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancellation }
        func terminal(_ phrase: Int) { lock.lock(); defer { lock.unlock() }; sourcePhrases.append(phrase) }
        func cancel() { lock.lock(); defer { lock.unlock() }; cancellation = true }
        var claims: [Int] { lock.lock(); defer { lock.unlock() }; return renderClaims }
        func reserve(_ count: Int) -> Bool { lock.lock(); defer { lock.unlock() }; renderClaims.append(count); return count == 1 }
    }

    private struct Evaluator: AutonomousCandidateEvaluating {
        let request: PhrasePreparationRequest
        let control: Control
        let policyVersion: String
        init(request: PhrasePreparationRequest, control: Control,
            policyVersion: String = "autotechno-quality.iterative-mechanical.v1") {
            self.request = request; self.control = control; self.policyVersion = policyVersion
        }
        let evaluatorVersion = ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier
        var preparationReplayFingerprint: String? { request.replayIdentity.fingerprint }
        var requiresPreparedValidation: Bool { true }
        func requestsHomeUpperTimbreCorrection(for candidate: AutonomousCandidateEvaluationVector) -> Bool { control.mode == .forceCorrection }
        func terminalVerdict(selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction) -> AutonomousCandidatePolicyVerdict {
            control.terminal(request.key.phraseIndex)
            return .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview) -> AutonomousCandidatePreparedValidation? {
            preparedValidation(for: preview, successor: nil)
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview,
            successor: PreparedAutonomousPhrase?) -> AutonomousCandidatePreparedValidation? {
            if control.mode == .cancelOnValidation { control.cancel() }
            if control.mode == .dropProof || (control.mode == .dropChildProof && request.key.phraseIndex > 21) { return nil }
            return try? preview.assessingContinuous(successor: successor) { _ in
                if (control.mode == .rejectChild && request.key.phraseIndex > 21) ||
                    (control.mode == .rejectRoot && request.key.phraseIndex == 21) {
                    return .init(outcome: .rejected, decisionBasis: .calibratedQuality,
                        reasonCodes: [.guardrailRegressionV1], diagnosticDetails: ["mechanical-child-rejection"])
                }
                return .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
            }
        }
    }
}
