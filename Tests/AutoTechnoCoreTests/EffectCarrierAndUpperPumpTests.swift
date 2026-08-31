import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Long-horizon effect carrier and upper pump")
struct EffectCarrierAndUpperPumpTests {
    @Test("Carrier selection retries deterministically and persists until world handoff")
    func selectionAndPersistence() throws {
        let witness = try activeWitness(seed: 48_291)
        let retry = witness.director.plan(
            from: witness.state,
            qualityRetryOrdinal: 1
        )
        #expect(retry.effectCarrier.state == witness.plan.effectCarrier.state)

        var committed = witness.state
        committed.advancePlanning(using: witness.plan)
        let successor = witness.director.plan(from: committed)
        #expect(successor.materialWorld.worldID == witness.plan.materialWorld.worldID)
        #expect(successor.effectCarrier.state == witness.plan.effectCarrier.state)

        let encoded = try JSONEncoder().encode(committed.memory.longHorizon)
        let decoded = try JSONDecoder().decode(
            LongHorizonContinuationState.self,
            from: encoded
        )
        #expect(decoded == committed.memory.longHorizon)
        #expect(decoded.effectCarrierState == witness.plan.effectCarrier.state)
        #expect(decoded.fingerprint == committed.memory.longHorizon.fingerprint)
    }

    @Test("Carrier priority follows the material hierarchy and role doses are distinct")
    func hierarchyAndDose() throws {
        for seed in [UInt64(48_291), 77_777] {
            let witness = try activeWitness(seed: seed)
            let role = try #require(witness.plan.effectCarrier.state.role)
            let synth = SynthPerformancePlan(
                scene: witness.plan.scene,
                dna: witness.plan.dna,
                kind: witness.plan.kind,
                resolvedBars: witness.plan.resolvedBars,
                materialWorld: witness.plan.materialWorld,
                compositionBars: witness.plan.phraseComposition
            )
            let activeRoles = Set(synth.bars.flatMap(\.upperNotes).map(\.role))
            let expected = priority(witness.plan.materialWorld.axes.roles)
                .first(where: activeRoles.contains)
            #expect(role == expected)
            #expect(witness.plan.effectCarrier.dose(for: role) == 1)
            #expect(SynthRole.allCases.filter { $0 != role }.allSatisfy {
                witness.plan.effectCarrier.dose(for: $0) == 0.35
            })
        }
    }

    @Test("Pump uses final kick syntax and identity return is exact neutral")
    func scorePumpGeometry() throws {
        let witness = try activeWitness(seed: 48_291)
        for bar in witness.plan.resolvedBars {
            let actualKickSteps = Array(Set(bar.ensemble.events.filter {
                $0.voice == .kick
            }.map(\.step))).sorted()
            if actualKickSteps.isEmpty {
                #expect(bar.upperMusicalPump == .neutral)
            } else {
                #expect(bar.upperMusicalPump.kickAnchorSteps == actualKickSteps)
                #expect((0.22...0.32).contains(bar.upperMusicalPump.attenuation))
                #expect(bar.upperMusicalPump.attackInBeats == 1.0 / 64.0)
                #expect((0.375...0.5).contains(bar.upperMusicalPump.releaseInBeats))
            }
            #expect(UpperMusicalPumpResolver.articulation(
                resolved: bar,
                phraseKind: .identityReturn,
                carrier: witness.plan.effectCarrier
            ) == .neutral)
        }
    }

    @Test("Detached carrier reconstruction and pump preserve protected rhythm", arguments: [
        (UInt64(48_291), 44_100.0),
        (UInt64(77_777), 48_000.0),
    ])
    func detachedDSP(seed: UInt64, sampleRate: Double) throws {
        let witness = try activeWitness(seed: seed)
        let graph = DSPGraphGenerator.plan(
            sessionSeed: seed,
            phrase: witness.plan,
            memory: witness.state.memory,
            previous: nil
        )
        var renderState = RenderState()
        renderState.barIndex = witness.plan.startBar
        var graphState = GeneratedDSPContinuationState()
        let first = AutonomousPhraseRenderer.render(
            plan: witness.plan,
            graph: graph,
            sampleRate: sampleRate,
            state: &renderState,
            graphState: &graphState
        )
        var replayState = RenderState()
        replayState.barIndex = witness.plan.startBar
        var replayGraphState = GeneratedDSPContinuationState()
        let replay = AutonomousPhraseRenderer.render(
            plan: witness.plan,
            graph: graph,
            sampleRate: sampleRate,
            state: &replayState,
            graphState: &replayGraphState
        )

        #expect(first == replay)
        #expect(first.count == witness.plan.barCount)
        for block in first {
            let carrier = try #require(block.effectCarrierRenderEvidence)
            #expect(carrier.isComplete)
            #expect(carrier.maximumReconstructionError == 0)
            #expect(carrier.carrierDose == 1)
            #expect(carrier.nonCarrierDose == 0.35)
            #expect(block.kickRenderPassesMatch)
            #expect(block.foundationRhythmRenderPassesMatch)
            #expect(block.protectedRhythmSampleHash.count == 16)
            let pump = block.upperMusicalPumpRenderEvidence
            #expect(pump.isComplete)
            if block.resolvedPerformance.upperMusicalPump.active {
                #expect(pump.active)
                #expect((0.68...0.78).contains(pump.requestedMinimumGain))
                #expect(pump.measuredMinimumGain >= pump.requestedMinimumGain - 1e-9)
                #expect(pump.measuredMinimumGain <= pump.requestedMinimumGain + 0.001)
            }
        }
    }

    private struct Witness {
        let director: AutonomousSessionDirector
        let state: AutonomousSessionState
        let plan: AutonomousPhrasePlan
    }

    private func activeWitness(seed: UInt64) throws -> Witness {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        for _ in 0..<24 {
            let plan = director.plan(from: state)
            if plan.effectCarrier.active {
                return Witness(director: director, state: state, plan: plan)
            }
            state.advancePlanning(using: plan)
        }
        Issue.record("No active carrier found in bounded search")
        throw WitnessError.unavailable
    }

    private func priority(_ hierarchy: LongHorizonRoleHierarchy) -> [SynthRole] {
        switch hierarchy {
        case .protagonistLed:
            [.anchor, .response, .shadow, .transition, .atmosphere]
        case .atmosphereLed:
            [.atmosphere, .transition, .response, .shadow, .anchor]
        case .percussionLed:
            [.response, .transition, .shadow, .anchor, .atmosphere]
        case .foundationLed:
            [.shadow, .anchor, .response, .atmosphere, .transition]
        }
    }

    private enum WitnessError: Error { case unavailable }
}
