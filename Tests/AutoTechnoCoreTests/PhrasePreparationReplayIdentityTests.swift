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
