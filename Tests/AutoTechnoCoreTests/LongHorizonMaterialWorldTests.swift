import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Long-horizon material worlds")
struct LongHorizonMaterialWorldTests {
    @Test("Worlds hold for four to eight minutes and retain causal lineage")
    func boundedWorldLineage() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var worlds: [LongHorizonMaterialWorldIntent] = []

        while state.memory.totalBars < 1_300 {
            let plan = director.plan(from: state)
            let world = state.memory.longHorizon.currentEpisode.materialWorld
            if worlds.last?.id != world.id { worlds.append(world) }
            state.advancePlanning(using: plan)
        }

        #expect(worlds.count >= 5)
        #expect(worlds.allSatisfy { $0.isValid })
        for index in worlds.indices.dropFirst() {
            let parent = worlds[index - 1]
            let child = worlds[index]
            #expect(child.parentID == parent.id)
            #expect(child.parentFingerprint == parent.fingerprint)
            #expect(child.parentAxes == parent.axes)
            #expect(child.generation == parent.generation + 1)
            #expect(child.axes.changedAxisCount(from: parent.axes) >= 4)
            #expect(child.axes.changedStructuralAxisCount(from: parent.axes) >= 2)
            #expect(child.axes.effect.distance(from: parent.axes.effect) >= 0.12)
            #expect(
                !worlds[max(0, index - 4)..<index]
                    .map(\.fingerprint).contains(child.fingerprint)
            )
        }

        let episodes = state.memory.longHorizon.recentEpisodes
        #expect(episodes.allSatisfy {
            $0.minimumHoldUntilBar - $0.startedAtBar == 8 * 16 &&
                $0.dueByBar - $0.startedAtBar == 16 * 16
        })
        let minimumSeconds = Double(8 * 16 * 4) / AutonomousSessionDirector.bpm * 60
        let maximumSeconds = Double(16 * 16 * 4) / AutonomousSessionDirector.bpm * 60
        #expect(minimumSeconds >= 230 && minimumSeconds <= 240)
        #expect(maximumSeconds >= 470 && maximumSeconds <= 475)
    }

    @Test("Bounded resolver preserves separation and recent exclusion across seeds")
    func boundedResolverContractsAcrossSeeds() {
        for rootSeed in UInt64(1)...UInt64(512) {
            var recent: [LongHorizonMaterialWorldIntent] = []
            var parent = LongHorizonMaterialWorldResolver.make(
                rootSeed: rootSeed,
                episodeID: 1,
                operatorKind: .maintain,
                parent: nil,
                recallSource: nil,
                recentFingerprints: []
            )
            recent.append(parent)
            for generation in 1...12 {
                let operatorKind = LongHorizonEpisodeOperator.allCases[
                    generation % LongHorizonEpisodeOperator.allCases.count
                ]
                let child = LongHorizonMaterialWorldResolver.make(
                    rootSeed: rootSeed,
                    episodeID: UInt64(generation + 1),
                    operatorKind: operatorKind,
                    parent: parent,
                    recallSource: recent.dropLast().last,
                    recentFingerprints: recent.map(\.fingerprint)
                )
                #expect(child.isValid)
                #expect(child.parentFingerprint == parent.fingerprint)
                #expect(child.axes.changedAxisCount(from: parent.axes) >= 4)
                #expect(child.axes.changedStructuralAxisCount(from: parent.axes) >= 2)
                #expect(child.axes.effect.distance(from: parent.axes.effect) >= 0.12)
                #expect(!recent.suffix(4).map(\.fingerprint).contains(child.fingerprint))
                recent.append(child)
                parent = child
            }
        }
    }

    @Test("Child worlds stage score handoffs and continuously converge their effect target")
    func materialHandoffDevelopsNaturally() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        let parent = state.memory.longHorizon.currentEpisode.materialWorld

        while state.memory.longHorizon.currentEpisode.materialWorld.id == parent.id {
            state.advancePlanning(using: director.plan(from: state))
        }

        let episode = state.memory.longHorizon.currentEpisode
        let opening = LongHorizonMaterialWorldPlan(
            episode: episode,
            startBar: episode.startedAtBar
        )
        let midpoint = LongHorizonMaterialWorldPlan(
            episode: episode,
            startBar: (episode.startedAtBar + episode.minimumHoldUntilBar) / 2
        )
        let settled = LongHorizonMaterialWorldPlan(
            episode: episode,
            startBar: episode.minimumHoldUntilBar
        )
        let target = episode.materialWorld.axes.effect

        #expect(opening.sourceAxes == parent.axes)
        #expect(opening.resolvedAxes == parent.axes)
        #expect(midpoint.resolvedAxes != opening.resolvedAxes)
        #expect(midpoint.resolvedAxes != settled.resolvedAxes)
        #expect(settled.resolvedAxes == episode.materialWorld.axes)
        #expect(
            target.distance(from: opening.resolvedAxes.effect) >
                target.distance(from: midpoint.resolvedAxes.effect)
        )
        #expect(target.distance(from: settled.resolvedAxes.effect) == 0)
    }

    @Test("Ten and twenty minutes occupy different score and effect worlds")
    func tenTwentyMinuteSeparation() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var graph: DSPGraphPlan?
        var snapshots: [Int: (AutonomousPhrasePlan, DSPGraphPlan)] = [:]

        while state.memory.totalBars < 700 {
            let plan = director.plan(from: state)
            let nextGraph = DSPGraphGenerator.plan(
                sessionSeed: state.rootSeed,
                phrase: plan,
                memory: state.memory,
                previous: graph
            )
            if let graph {
                let target = plan.materialWorld.resolvedAxes.effect
                #expect(
                    target.distance(from: nextGraph.realizedEffectWorld) <=
                        target.distance(from: graph.realizedEffectWorld) + 1e-12
                )
            }
            #expect(DSPGraphValidator.validate(nextGraph).valid)
            #expect((nextGraph.mutation?.affectedNodeIDs.count ?? 0) <= 1)
            #expect(nextGraph.lowEndProtected)
            #expect(nextGraph.protectedRouting.valid)
            for checkpoint in [325, 650]
                where plan.startBar <= checkpoint && checkpoint < plan.startBar + plan.barCount
            {
                snapshots[checkpoint] = (plan, nextGraph)
            }
            graph = nextGraph
            state.advancePlanning(using: plan)
        }

        let ten = try #require(snapshots[325])
        let twenty = try #require(snapshots[650])
        #expect(ten.0.materialWorld.worldFingerprint != twenty.0.materialWorld.worldFingerprint)
        #expect(
            ten.0.materialWorld.axes.changedAxisCount(
                from: twenty.0.materialWorld.axes
            ) >= 4
        )
        #expect(ten.0.dna.tonalCenter == twenty.0.dna.tonalCenter)
        #expect(ten.0.dna.modalIdentity == twenty.0.dna.modalIdentity)
        #expect(ten.0.scene.bpm == 130)
        #expect(twenty.0.scene.bpm == 130)
        #expect(ten.1.materialWorldFingerprint != twenty.1.materialWorldFingerprint)
        #expect(
            ten.1.effectWorldTarget.distance(from: twenty.1.effectWorldTarget) >= 0.12
        )
        #expect(ten.1.nodes != twenty.1.nodes)
        #expect(
            Set(ten.0.resolvedBars.map(\.percussionGear)) !=
                Set(twenty.0.resolvedBars.map(\.percussionGear)) ||
                Set(ten.0.resolvedBars.map(\.performanceCharacter)) !=
                Set(twenty.0.resolvedBars.map(\.performanceCharacter))
        )

        let recovered = DSPGraphGenerator.plan(
            sessionSeed: state.rootSeed,
            phrase: twenty.0,
            memory: state.memory,
            previous: twenty.1,
            routeRecovery: true
        )
        #expect(recovered == twenty.1)

        let metadataOnly = DSPGraphPlan(
            sessionSeed: twenty.1.sessionSeed,
            revision: twenty.1.revision,
            nodes: twenty.1.nodes,
            mutation: nil,
            lowEndProtected: twenty.1.lowEndProtected,
            protectedRouting: twenty.1.protectedRouting,
            materialWorldFingerprint: ten.0.materialWorld.worldFingerprint,
            effectWorldTarget: ten.0.materialWorld.resolvedAxes.effect
        )
        #expect(metadataOnly != twenty.1)
        #expect(metadataOnly.hasSameTopology(as: twenty.1))
    }

    @Test("Root seed replay reproduces every world and graph transition")
    func deterministicReplay() {
        #expect(sequence(seed: 77_777) == sequence(seed: 77_777))
        #expect(sequence(seed: 77_777) != sequence(seed: 77_778))
    }

    @Test("A qualified material deficit reframes only an unstarted future world")
    func materialDeficitReframesFutureBoundary() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var sourceState = director.initialState()
        var sourcePlan = director.plan(from: sourceState)
        var preview = sourceState.advance(
            using: sourcePlan,
            quality: sourceState.quality,
            liveMasterHeadroom: sourceState.liveMasterHeadroom
        )
        while preview.memory.longHorizon.currentEpisode.startedAtBar !=
            preview.memory.totalBars {
            sourceState = preview
            sourcePlan = director.plan(from: sourceState)
            preview = sourceState.advance(
                using: sourcePlan,
                quality: sourceState.quality,
                liveMasterHeadroom: sourceState.liveMasterHeadroom
            )
        }
        let selectedFutureWorld =
            preview.memory.longHorizon.currentEpisode.materialWorld
        let decision = LongHorizonTrajectoryDecision(
            rootSeed: sourceState.rootSeed,
            policyVersion: "test-material-policy.v1",
            evidenceSchema: "test-material-trajectory.v1",
            evidenceFingerprint: "0123456789abcdef",
            observedThroughPhraseIndex: sourcePlan.phraseIndex,
            observedThroughBar: sourcePlan.startBar + sourcePlan.barCount,
            action: .reframeMaterial,
            reasons: [.semanticPeriodicity, .effectFatigue]
        )
        let corrected = sourceState.advance(
            using: sourcePlan,
            quality: sourceState.quality,
            liveMasterHeadroom: sourceState.liveMasterHeadroom,
            longHorizonDecision: decision
        )
        let reframed = corrected.memory.longHorizon.currentEpisode
        let nextPlan = director.plan(from: corrected)

        #expect(sourcePlan.materialWorld.worldFingerprint !=
            selectedFutureWorld.fingerprint)
        #expect(reframed.operatorKind == .reframe)
        #expect(reframed.startedAtBar == corrected.memory.totalBars)
        #expect(reframed.materialWorld.parentFingerprint ==
            selectedFutureWorld.fingerprint)
        #expect(reframed.materialWorld.axes.changedAxisCount(
            from: selectedFutureWorld.axes
        ) >= 4)
        #expect(nextPlan.materialWorld.isConsistent(with: reframed))
        #expect(corrected.memory.longHorizon.lastTrajectoryDecision == decision)
    }

    private func sequence(seed: UInt64) -> [String] {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        var graph: DSPGraphPlan?
        var result: [String] = []
        while state.memory.totalBars < 700 {
            let plan = director.plan(from: state)
            graph = DSPGraphGenerator.plan(
                sessionSeed: seed,
                phrase: plan,
                memory: state.memory,
                previous: graph
            )
            result.append(
                plan.materialWorld.worldFingerprint + ":" +
                    (graph.map(AutonomousCandidateFingerprint.graph) ?? "none")
            )
            state.advancePlanning(using: plan)
        }
        return result
    }
}
