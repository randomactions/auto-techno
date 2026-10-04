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
            var expected = AutonomousPreparationChainResourceBudget()
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

    private static func sourceRequest(rate: Double) -> PhrasePreparationRequest {
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
        let policyVersion = "autotechno-quality.iterative-mechanical.v1"
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
