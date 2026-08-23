import AutoTechnoApp
import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Fresh autonomous session identity", .serialized)
struct AutonomousSessionIdentityTests {
    @MainActor
    @Test("Injected entropy selects the first session and shutdown rotates the boundary")
    func completeSessionBoundaryRotatesSeed() {
        var values: [UInt64] = [42, 90_909]
        let source = AutonomousSessionSeedSource {
            values.removeFirst()
        }
        let engine = TechnoEngine(sessionSeedSource: source)

        #expect(engine.currentSessionSeed == 42)
        engine.shutdown()
        #expect(engine.currentSessionSeed == 90_909)
    }

    @MainActor
    @Test("A repeated entropy draw is mixed away from the completed session")
    func repeatedEntropyCannotRepeatImmediateSession() {
        let source = AutonomousSessionSeedSource { 48_291 }

        let first = source.nextSeed()
        let second = source.nextSeed(excluding: first)

        #expect(first == 48_291)
        #expect(second != first)
        #expect(source.nextSeed(excluding: first) == second)
    }

    @Test("Preparation cache identity includes the exact session seed")
    func preparationKeySeparatesSessions() {
        let first = preparationKey(sessionSeed: 42)
        let replay = preparationKey(sessionSeed: 42)
        let fresh = preparationKey(sessionSeed: 90_909)

        #expect(first == replay)
        #expect(first != fresh)
        #expect(Set([first, replay, fresh]).count == 2)
    }

    @Test("Explicit seeds reproduce exactly while fresh seeds change score and PCM")
    func fixedSeedReplayAndFreshSeedDivergence() {
        let first = projection(seed: 42)
        let replay = projection(seed: 42)
        let fresh = projection(seed: 90_909)

        #expect(first == replay)
        #expect(first.planFingerprint != fresh.planFingerprint)
        #expect(first.stereoPCMHash != fresh.stereoPCMHash)
    }

    private func preparationKey(sessionSeed: UInt64) -> PhrasePreparationKey {
        PhrasePreparationKey(
            sessionSeed: sessionSeed,
            phraseIndex: 0,
            sampleRate: 48_000,
            channelCount: 2,
            routeRecovery: false,
            qualityRevision: 0,
            qualityPolicyVersion: "test-policy",
            qualityControllerFingerprint: nil,
            routeGeneration: 0,
            incomingLiveMasterRevision: 0,
            incomingLiveMasterStateFingerprint: "test-live-state",
            pendingLiveMasterProposalFingerprint: nil,
            liveEarliestEligibleFutureSample: nil,
            liveTargetStartSample: nil
        )
    }

    private func projection(seed: UInt64) -> SessionProjection {
        let director = AutonomousSessionDirector(rootSeed: seed)
        let plan = director.plan(from: director.initialState())
        let graph = DSPGraphGenerator.safePlan(sessionSeed: seed)
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &renderState,
            graphState: &graphState
        )
        var hash: UInt64 = 0xcbf29ce484222325
        for block in blocks {
            for sample in block.left {
                hash ^= UInt64(sample.bitPattern)
                hash &*= 0x100000001b3
            }
            for sample in block.right {
                hash ^= UInt64(sample.bitPattern)
                hash &*= 0x100000001b3
            }
        }
        return SessionProjection(
            planFingerprint: AutonomousCandidateFingerprint.plan(plan),
            stereoPCMHash: hash
        )
    }

    private struct SessionProjection: Equatable {
        let planFingerprint: String
        let stereoPCMHash: UInt64
    }
}
