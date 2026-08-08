import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Adaptive autonomous session")
struct AdaptiveAutonomousSessionTests {
    @Test("Fixed seeds replay the same variable phrases and bounded memories",
          arguments: [UInt64(42), 48_291, 90_909, 7, 77_777])
    func deterministicSession(seed: UInt64) {
        let first = sequence(seed: seed, phraseCount: 80)
        let second = sequence(seed: seed, phraseCount: 80)
        #expect(first.plans == second.plans)
        #expect(first.state == second.state)
        #expect(first.plans.allSatisfy { (4...16).contains($0.barCount) })
        #expect(first.plans.allSatisfy { $0.scene.bpm == 130 })
        #expect(first.plans.allSatisfy { $0.dna == first.state.identityDNA })
        #expect(first.state.memory.recentBars.count == 4)
        #expect(first.state.memory.currentPhrase.count <= 16)
        #expect(first.state.memory.previousPhrase.count <= 16)
        #expect(first.state.memory.dramaticArc.count <= 128)
        #expect(first.state.memory.sessionBars.count == 256)
        #expect(first.plans.contains { $0.kind == .contrast })
        #expect(first.plans.contains { $0.kind == .majorBreak })
        #expect(first.plans.contains { $0.kind == .energyRelease })
    }

    @Test("Structural promises remain bounded and releases pay every open debt",
          arguments: [UInt64(42), 48_291, 90_909])
    func dramaticPromises(seed: UInt64) {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        var contrastBars: [Int] = []
        var breakBars: [Int] = []
        var releaseBars: [Int] = []

        for _ in 0..<120 {
            let plan = director.candidates(from: state).primary
            if plan.kind != .lock { contrastBars.append(plan.startBar) }
            if plan.kind == .majorBreak { breakBars.append(plan.startBar) }
            if plan.kind == .energyRelease {
                releaseBars.append(plan.startBar)
                #expect(Set(plan.paidDebtIDs) == Set(state.memory.openDebts.map(\.id)))
            }
            state.advance(using: plan)
            if plan.kind == .energyRelease { #expect(state.memory.openDebts.isEmpty) }
        }

        #expect(intervals(contrastBars).allSatisfy { (4...39).contains($0) })
        #expect(intervals(breakBars).allSatisfy { (48...127).contains($0) })
        #expect(intervals(releaseBars).allSatisfy { (64...159).contains($0) })
        #expect(!breakBars.isEmpty)
        #expect(!releaseBars.isEmpty)
    }

    @Test("Ensemble arbitration protects anchors and caps unplanned competition")
    func ensembleArbitration() {
        let proposals = [
            EnsembleEventProposal(voice: .kick, requestedStep: 0, priority: 100,
                                  intensity: 1, essential: true),
            EnsembleEventProposal(voice: .bass, requestedStep: 0, alternateSteps: [1, 3],
                                  priority: 90, intensity: 0.8, essential: true),
            EnsembleEventProposal(voice: .motif, requestedStep: 0, alternateSteps: [1, 2],
                                  priority: 70, intensity: 0.6),
            EnsembleEventProposal(voice: .response, requestedStep: 0, alternateSteps: [2, 3],
                                  priority: 60, intensity: 0.5),
            EnsembleEventProposal(voice: .percussion, requestedStep: 0, alternateSteps: [2, 4],
                                  priority: 50, intensity: 0.5),
        ]
        let result = EnsembleArbiter.resolve(
            proposals: proposals, focusRole: .motif, intentionalPileup: false
        )
        let occupancy = Dictionary(grouping: result.events, by: \.step).mapValues(\.count)
        #expect(result.kickAnchors == [0])
        #expect(result.events.contains { $0.voice == .kick && $0.step == 0 && !$0.relocated })
        #expect(result.events.filter { $0.voice == .bass }.allSatisfy { $0.step != 0 })
        #expect(occupancy.values.allSatisfy { $0 <= 3 })
        #expect(result.events.contains { $0.relocated })
    }

    @Test("Stale preparation epochs and late phrase policy fail coherently")
    func runtimePolicies() {
        var epoch = AutonomousPreparationEpoch()
        let stale = epoch.value
        #expect(epoch.accepts(stale))
        epoch.invalidate()
        #expect(!epoch.accepts(stale))
        #expect(epoch.accepts(epoch.value))
        #expect(AutonomousPhraseBoundaryPolicy.decide(successorPrepared: true) == .advance)
        #expect(AutonomousPhraseBoundaryPolicy.decide(successorPrepared: false) ==
                .repeatCurrentWithFrozenTopology)
    }

    private func sequence(seed: UInt64, phraseCount: Int)
        -> (plans: [AutonomousPhrasePlan], state: AutonomousSessionState) {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        var plans: [AutonomousPhrasePlan] = []
        for _ in 0..<phraseCount {
            let plan = director.candidates(from: state).primary
            plans.append(plan)
            state.advance(using: plan)
        }
        return (plans, state)
    }

    private func intervals(_ values: [Int]) -> [Int] {
        zip(values, values.dropFirst()).map { $1 - $0 }
    }
}

@Suite("Generated DSP topology")
struct GeneratedDSPTopologyTests {
    @Test("One thousand graph sequences stay valid, bounded, protected, and reconstructable")
    func graphProperties() {
        for rawSeed in 1...1_000 {
            let seed = UInt64(rawSeed)
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            let firstPhrase = director.candidates(from: state).primary
            let firstGraph = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: firstPhrase, memory: state.memory, previous: nil
            )
            state.advance(using: firstPhrase)
            let secondPhrase = director.candidates(from: state).primary
            let secondGraph = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: secondPhrase, memory: state.memory, previous: firstGraph
            )

            for graph in [firstGraph, secondGraph] {
                let validation = DSPGraphValidator.validate(graph)
                #expect(validation.valid)
                #expect(graph.lowEndProtected)
                #expect(graph.protectedRouting.valid)
                #expect(!graph.nodes.isEmpty)
                #expect(graph.nodes.count <= DSPGraphPlan.maximumNodeCount)
                #expect(graph.maximumDepth <= DSPGraphPlan.maximumSerialDepth)
                #expect(graph.branchCount <= DSPGraphPlan.maximumBranchCount)
                #expect((graph.mutation?.affectedNodeIDs.count ?? 0) <= 2)
            }

            let replayFirst = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: firstPhrase,
                memory: director.initialState().memory, previous: nil
            )
            let replaySecond = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: secondPhrase, memory: state.memory,
                previous: replayFirst
            )
            #expect(firstGraph == replayFirst)
            #expect(secondGraph == replaySecond)
        }
    }

    @Test("Release and route recovery suppress topology mutation")
    func mutationSuppression() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var graph: DSPGraphPlan?
        var releasePlan: AutonomousPhrasePlan?
        for _ in 0..<40 {
            let plan = director.candidates(from: state).primary
            graph = DSPGraphGenerator.plan(
                sessionSeed: state.rootSeed, phrase: plan, memory: state.memory, previous: graph
            )
            if plan.kind == .energyRelease {
                releasePlan = plan
                break
            }
            state.advance(using: plan)
        }
        guard let releasePlan, let graph else {
            Issue.record("Expected an energy release within forty phrases")
            return
        }
        let releaseGraph = DSPGraphGenerator.plan(
            sessionSeed: state.rootSeed, phrase: releasePlan, memory: state.memory, previous: graph
        )
        let recoveryGraph = DSPGraphGenerator.plan(
            sessionSeed: state.rootSeed, phrase: releasePlan, memory: state.memory,
            previous: graph, routeRecovery: true
        )
        #expect(releaseGraph.mutation == nil)
        #expect(recoveryGraph.mutation == nil)
        #expect(releaseGraph.hasSameTopology(as: graph))
        #expect(recoveryGraph.hasSameTopology(as: graph))
    }

    @Test("Topology transitions crossfade for one bar and retire tails after two")
    func crossfadeAndTail() {
        let first = DSPGraphGenerator.safePlan(sessionSeed: 42)
        let second = DSPGraphPlan(
            sessionSeed: 42,
            revision: 1,
            nodes: [
                DSPGraphNode(id: 10, kind: .waveFold, branch: 0, order: 0,
                             amount: 0.72, mix: 0.54),
                DSPGraphNode(id: 11, kind: .echo, branch: 1, order: 0,
                             amount: 0.46, mix: 0.36, feedback: 0.42, delaySeconds: 0.08),
            ],
            mutation: DSPGraphMutation(kind: .replace, phraseIndex: 1, affectedNodeIDs: [10])
        )
        let input = (0..<2_048).map { Float(sin(Double($0) * 0.031) * 0.2) }
        var state = GeneratedDSPContinuationState()
        _ = GeneratedDSPGraphRenderer.process(
            left: input, right: input, sampleRate: 8_000, plan: first, state: &state
        )
        var oldOnlyState = state
        let oldOnly = GeneratedDSPGraphRenderer.process(
            left: input, right: input, sampleRate: 8_000, plan: first, state: &oldOnlyState
        )
        let crossfaded = GeneratedDSPGraphRenderer.process(
            left: input, right: input, sampleRate: 8_000, plan: second, state: &state
        )
        #expect(abs(crossfaded.0[0] - oldOnly.0[0]) < 0.000_01)
        #expect(state.retiringBarsRemaining == 1)
        let silence = [Float](repeating: 0, count: input.count)
        let tail = GeneratedDSPGraphRenderer.process(
            left: silence, right: silence, sampleRate: 8_000, plan: second, state: &state
        )
        #expect(tail.0.contains { abs($0) > 0.000_001 })
        #expect(state.retiringBarsRemaining == 0)
        #expect(state.retiringGraph == nil)
        #expect(tail.0.allSatisfy(\.isFinite) && tail.1.allSatisfy(\.isFinite))
    }
}

@Suite("Autonomous preparation preflight")
struct AutonomousPreparationPreflightTests {
    @Test("Stagnation, health, ties, and dual failure follow the bounded selection policy")
    func selectionPolicy() {
        let healthy = AutonomousCandidateEvidence(
            symbolicValid: true, safetyValid: true, interesting: true, combinedScore: 0.60
        )
        let stagnant = AutonomousCandidateEvidence(
            symbolicValid: true, safetyValid: true, interesting: false, combinedScore: 0.42
        )
        let alternate = AutonomousCandidateEvidence(
            symbolicValid: true, safetyValid: true, interesting: true, combinedScore: 0.72
        )
        let unsafe = AutonomousCandidateEvidence(
            symbolicValid: true, safetyValid: false, interesting: false, combinedScore: 0.90
        )
        #expect(AutonomousCandidateSelector.choose(primary: healthy, alternate: alternate) == .primary)
        #expect(AutonomousCandidateSelector.choose(primary: stagnant, alternate: alternate) == .alternate)
        #expect(AutonomousCandidateSelector.choose(primary: stagnant, alternate: AutonomousCandidateEvidence(
            symbolicValid: true, safetyValid: true, interesting: true, combinedScore: stagnant.combinedScore
        )) == .primary)
        #expect(AutonomousCandidateSelector.choose(primary: unsafe, alternate: unsafe) == .fallback)
    }

    @Test("Fixed-seed phrase audio is deterministic and satisfies safety limits",
          arguments: [UInt64(42), 48_291, 90_909])
    func fixedSeedAudio(seed: UInt64) {
        let first = prepare(seed: seed, sampleRate: 8_000)
        let second = prepare(seed: seed, sampleRate: 8_000)
        #expect(first.plan == second.plan)
        #expect(first.graph == second.graph)
        #expect(first.blocks == second.blocks)
        #expect(first.endingGraphState == second.endingGraphState)
        #expect(first.audioPreflight == second.audioPreflight)
        #expect(first.audioPreflight.safetyValid)
        #expect(first.audioPreflight.quality.finite)
        #expect(first.audioPreflight.quality.truePeakEstimate <= 0.95)
        #expect(abs(first.audioPreflight.quality.dcOffset) < 0.05)
        #expect(first.audioPreflight.quality.lowStereoCorrelation > 0.94)
        #expect(first.audioPreflight.quality.maxBoundaryDelta < 0.65)
    }

    @Test("Continuation state reproduces successor phrases exactly")
    func continuationReplay() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var sessionA = director.initialState()
        var sessionB = director.initialState()
        let firstA = prepare(state: sessionA, sampleRate: 8_000)
        let firstB = prepare(state: sessionB, sampleRate: 8_000)
        sessionA.advance(using: firstA.plan)
        sessionB.advance(using: firstB.plan)
        let nextA = prepare(
            state: sessionA, sampleRate: 8_000,
            renderState: firstA.endingRenderState,
            graphState: firstA.endingGraphState,
            previousGraph: firstA.graph
        )
        let nextB = prepare(
            state: sessionB, sampleRate: 8_000,
            renderState: firstB.endingRenderState,
            graphState: firstB.endingGraphState,
            previousGraph: firstB.graph
        )
        #expect(nextA.plan == nextB.plan)
        #expect(nextA.graph == nextB.graph)
        #expect(nextA.blocks == nextB.blocks)
        #expect(nextA.endingGraphState == nextB.endingGraphState)
    }

    @Test("Different valid topology plans produce audibly distinct sample hashes")
    func topologyDistinction() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let phrase = director.candidates(from: state).primary
        let graphA = DSPGraphGenerator.safePlan(sessionSeed: 42)
        let graphB = DSPGraphPlan(
            sessionSeed: 42, revision: 1,
            nodes: [DSPGraphNode(id: 20, kind: .waveFold, branch: 0, order: 0,
                                amount: 0.88, mix: 0.72)],
            mutation: DSPGraphMutation(kind: .replace, phraseIndex: 0, affectedNodeIDs: [20])
        )
        var renderA = V2RenderState(), renderB = V2RenderState()
        var stateA = GeneratedDSPContinuationState(), stateB = GeneratedDSPContinuationState()
        let blocksA = V2ProceduralEngine.renderAutonomousPhrase(
            plan: phrase, graph: graphA, sampleRate: 8_000,
            state: &renderA, graphState: &stateA
        )
        let blocksB = V2ProceduralEngine.renderAutonomousPhrase(
            plan: phrase, graph: graphB, sampleRate: 8_000,
            state: &renderB, graphState: &stateB
        )
        #expect(V2QualityReport(blocks: blocksA, sampleRate: 8_000).sampleHash !=
                V2QualityReport(blocks: blocksB, sampleRate: 8_000).sampleHash)
    }

    @Test("Representative 44.1 and 48 kHz renders remain finite and bounded")
    func deviceSampleRates() {
        for (seed, sampleRate) in [(UInt64(42), 44_100.0), (UInt64(90_909), 48_000.0)] {
            let prepared = prepare(seed: seed, sampleRate: sampleRate)
            let report = prepared.audioPreflight.quality
            #expect(report.finite)
            #expect(report.truePeakEstimate <= 0.95)
            #expect(abs(report.dcOffset) < 0.05)
            #expect(report.lowStereoCorrelation > 0.94)
            #expect(report.maxBoundaryDelta < 0.65)
        }
    }

    private func prepare(seed: UInt64, sampleRate: Double) -> PreparedAutonomousPhrase {
        let director = AutonomousSessionDirector(rootSeed: seed)
        return prepare(state: director.initialState(), sampleRate: sampleRate)
    }

    private func prepare(state: AutonomousSessionState, sampleRate: Double,
                         renderState: V2RenderState = V2RenderState(),
                         graphState: GeneratedDSPContinuationState = GeneratedDSPContinuationState(),
                         previousGraph: DSPGraphPlan? = nil) -> PreparedAutonomousPhrase {
        let director = AutonomousSessionDirector(rootSeed: state.rootSeed)
        return AutonomousPhrasePreparer.prepare(
            candidates: director.candidates(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: sampleRate,
            incomingRenderState: renderState,
            incomingGraphState: graphState,
            previousGraph: previousGraph
        )
    }
}
