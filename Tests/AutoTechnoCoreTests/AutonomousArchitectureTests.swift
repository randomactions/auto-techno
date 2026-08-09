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

    @Test("Structural phrases resolve on the macro grid and topology changes stay exceptional",
          arguments: [UInt64(42), 48_291, 90_909])
    func macroGrammarAndTopologyRestraint(seed: UInt64) {
        let result = sequence(seed: seed, phraseCount: 100)
        for plan in result.plans {
            let structural = plan.kind == .majorBreak || plan.kind == .energyRelease ||
                plan.kind == .identityReturn
            if structural {
                #expect(plan.resolvedBars.contains {
                    $0.arrangementGesture == .structuralMarker &&
                        ($0.performance.bar + 1).isMultiple(of: 16) &&
                        $0.performance.signatureEvent != nil
                })
            }
            #expect(plan.resolvedBars.allSatisfy { resolved in
                let expected: PercussionGear = switch (resolved.performance.bar % 16) / 4 {
                case 0: .anchor
                case 1: .lift
                case 2: .contrast
                default: .turnaround
                }
                return resolved.percussionGear == expected
            })
            #expect(!plan.requestsTopologyMutation ||
                    (plan.kind == .contrast || plan.kind == .majorBreak))
        }
    }

    @Test("Weak-sixteenth classes and macro reveal use the authored hierarchy")
    func weakSixteenthVocabularyAndPatterns() {
        #expect((0..<4).map(SixteenthPulseClass.init(step:)) == [
            .downbeat, .leadingWeak, .upbeat, .trailingWeak,
        ])
        #expect((0..<16).map(WeakSixteenthStage.init(absoluteBar:)) ==
                Array(repeating: .skeleton, count: 4) +
                Array(repeating: .contour, count: 4) +
                Array(repeating: .syncopatedLean, count: 4) +
                Array(repeating: .pullback, count: 4))

        let contour = GroovePulseResolver.pattern(
            stage: .contour, gesture: .steady, macroEnding: false
        )
        #expect(contour.map(\.0) == [1, 3, 5, 7, 9, 11, 13, 15])
        #expect(contour.map(\.1) == [0.38, 0.52, 0.38, 0.52, 0.38, 0.52, 0.38, 0.52])
        let lean = GroovePulseResolver.pattern(
            stage: .syncopatedLean, gesture: .steady, macroEnding: false
        )
        #expect(lean.map(\.0) == contour.map(\.0))
        #expect(lean.map(\.1) == [0.30, 0.72, 0.30, 0.72, 0.30, 0.72, 0.30, 0.72])
        let minimal = GroovePulseResolver.pattern(
            stage: .syncopatedLean, gesture: .minimalize, macroEnding: false
        )
        #expect(minimal.map(\.0) == [7, 15])
        #expect(minimal.map(\.1) == [0.42, 0.42])
        let pullback = GroovePulseResolver.pattern(
            stage: .pullback, gesture: .turnaround, macroEnding: true
        )
        #expect(pullback.map(\.0) == [3, 7, 11, 15])
        #expect(pullback.map(\.1) == [0.50, 0.50, 0.50, 0.72])
        #expect(GroovePulseResolver.pattern(
            stage: .pullback, gesture: .structuralMarker,
            macroEnding: true, majorBreak: true
        ).isEmpty)
    }

    @Test("Weak-sixteenth reveal follows the macro grid across phrase boundaries and breaks")
    func weakSixteenthMacroContinuity() {
        let result = sequence(seed: AutonomousSessionDirector.defaultSeed, phraseCount: 100)
        let plans = result.plans
        let firstMacro = plans.flatMap(\.resolvedBars)
            .filter { $0.performance.bar < 16 }
            .sorted { $0.performance.bar < $1.performance.bar }
        #expect(firstMacro.count == 16)
        for resolved in firstMacro {
            let expected = GroovePulseResolver.pattern(
                stage: WeakSixteenthStage(absoluteBar: resolved.performance.bar),
                gesture: resolved.arrangementGesture,
                macroEnding: (resolved.performance.bar + 1).isMultiple(of: 16)
            )
            #expect(resolved.groovePulses.map(\.step) == expected.map(\.0))
            #expect(resolved.groovePulses.map(\.intensity) == expected.map(\.1))
            #expect(resolved.groovePulses.allSatisfy {
                $0.stage == WeakSixteenthStage(absoluteBar: resolved.performance.bar) &&
                    ($0.pulseClass == .leadingWeak || $0.pulseClass == .trailingWeak) &&
                    $0.timingOffsetInSteps <= 0.12
            })
            let resolvedEvents = resolved.ensemble.events
                .filter { $0.voice == .groovePulse }
            #expect(resolvedEvents.map(\.step) == resolved.groovePulses.map(\.step))
            #expect(resolvedEvents.map(\.intensity) == resolved.groovePulses.map(\.intensity))
        }
        #expect(firstMacro[0...3].allSatisfy { $0.groovePulses.isEmpty })
        #expect(firstMacro[16 - 1].groovePulses.last?.intensity == 0.72)

        let midMacroBoundary = zip(plans, plans.dropFirst()).first { previous, next in
            previous.startBar + previous.barCount == next.startBar &&
                !next.startBar.isMultiple(of: 16)
        }
        guard let (_, next) = midMacroBoundary, let first = next.resolvedBars.first else {
            Issue.record("Expected an adaptive phrase boundary inside a macro")
            return
        }
        #expect(first.groovePulses.allSatisfy {
            $0.stage == WeakSixteenthStage(absoluteBar: first.performance.bar)
        })
        #expect(plans.filter { $0.kind == .majorBreak }.allSatisfy { plan in
            plan.resolvedBars.allSatisfy { $0.groovePulses.isEmpty }
        })
        #expect(plans.flatMap(\.resolvedBars).filter {
            !$0.performance.roles.contains(.percussion)
        }.allSatisfy { $0.groovePulses.isEmpty })
    }

    @Test("Ghost pulses contribute one fifth of an ordinary activity event")
    func groovePulseActivityWeight() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let plan = director.candidates(from: state).primary
        guard let resolved = plan.resolvedBars.first(where: { !$0.groovePulses.isEmpty }) else {
            Issue.record("Expected a groove-pulse bar in the first phrase")
            return
        }
        let weightedEvents = resolved.ensemble.events.filter {
            $0.voice == .kick || $0.voice == .groovePulse
        }
        let weighted = ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: EnsembleContext(
                focusRole: resolved.ensemble.focusRole,
                events: weightedEvents,
                kickAnchors: resolved.ensemble.kickAnchors,
                intentionalPileup: resolved.ensemble.intentionalPileup
            ),
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
        let ordinaryEvents = weightedEvents.map { event in
            event.voice == .groovePulse
                ? EnsembleResolvedEvent(
                    voice: .percussion, step: event.step,
                    intensity: event.intensity, relocated: event.relocated
                )
                : event
        }
        let ordinary = ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: EnsembleContext(
                focusRole: resolved.ensemble.focusRole,
                events: ordinaryEvents,
                kickAnchors: resolved.ensemble.kickAnchors,
                intentionalPileup: resolved.ensemble.intentionalPileup
            ),
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
        let weightedReport = PhraseInterestEvaluator.evaluate(
            resolvedBars: [weighted], kind: plan.kind,
            memory: state.memory, identityPreserved: true
        )
        let ordinaryReport = PhraseInterestEvaluator.evaluate(
            resolvedBars: [ordinary], kind: plan.kind,
            memory: state.memory, identityPreserved: true
        )
        #expect(weightedReport.intentionalSpace > ordinaryReport.intentionalSpace)
        #expect(weightedReport.overactivityPenalty <= ordinaryReport.overactivityPenalty)
        #expect(weightedReport.weakPositionCoverage == 1)
        #expect(weightedReport.trailingSideRelationship == 1)
    }

    @Test("The three-step driver advances the five-stage follower and resets only on the macro grid")
    func relationalCyclePhases() {
        let phases = (0..<15).map(RelationalCyclePhase.init(macroStep:))
        #expect(phases.map(\.driverPhase) == [0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2])
        #expect(phases.map(\.followerStage) == [
            .anchor, .anchor, .anchor,
            .inhale, .inhale, .inhale,
            .open, .open, .open,
            .spill, .spill, .spill,
            .withdraw, .withdraw, .withdraw,
        ])
        #expect(RelationalCyclePhase(macroStep: 255).followerStage == .anchor)
        #expect(RelationalCyclePhase(macroStep: 256) == RelationalCyclePhase(macroStep: 0))
    }

    @Test("Relational chapters stay macro-bound, preserve onsets, and continue across phrases")
    func relationalChaptersFollowResolvedBars() {
        let result = sequence(seed: AutonomousSessionDirector.defaultSeed, phraseCount: 160)
        let bars = result.plans.flatMap(\.resolvedBars)
        let grouped = Dictionary(grouping: bars) { $0.performance.bar / 16 }
        #expect(grouped.values.allSatisfy { Set($0.map(\.interlockChapter)).count == 1 })
        #expect(bars.first?.interlockChapter == .home)
        #expect(Optional(result.state.memory.interlockEvolution) ==
                result.plans.last?.endingInterlockState)

        for plan in result.plans {
            let synth = SynthPerformancePlan(
                scene: plan.scene, dna: plan.dna, resolvedBars: plan.resolvedBars
            )
            #expect(synth.bars.count == plan.resolvedBars.count)
            for (resolved, synthBar) in zip(plan.resolvedBars, synth.bars) {
                let motifSteps = resolved.ensemble.events
                    .filter { $0.voice == .motif }.map(\.step).sorted()
                #expect(synthBar.interlockEvents.map(\.stepIndex).sorted() == motifSteps)
                let expectedStart = RelationalCyclePhase(
                    macroStep: (resolved.performance.bar % 16) * 16
                )
                #expect(synthBar.articulation(at: 0).phase == expectedStart)
            }
        }

        let macroChapters = grouped.keys.sorted().compactMap {
            grouped[$0]?.first?.interlockChapter
        }
        var macrosWithoutHome = 0
        for (previous, current) in zip(macroChapters, macroChapters.dropFirst()) {
            if current == .home {
                macrosWithoutHome = 0
            } else {
                macrosWithoutHome += 1
                #expect(current != previous)
            }
            #expect(macrosWithoutHome <= 4)
        }
    }

    @Test("Bounded interlock state evolves deterministically for more than eight hours")
    func indefiniteInterlockEvolution() {
        func journey() -> [InterlockEvolutionState] {
            var state = InterlockEvolutionState()
            var states: [InterlockEvolutionState] = [state]
            let kinds: [AutonomousPhraseKind] = [
                .lock, .contrast, .lock, .majorBreak, .energyRelease, .lock, .identityReturn,
            ]
            for macro in 1...1_024 {
                let kind = kinds[macro % kinds.count]
                let entropy = SceneDNA.derivedSeed(
                    scene: AutonomousSessionDirector.defaultSeed,
                    domain: 0x1A7E2C10,
                    index: macro
                )
                let previous = state
                state = state.advancing(for: kind, entropy: entropy)
                #expect(state.previousChapters.count <= 2)
                #expect(state.macrosSinceHome <= 4)
                if state.currentChapter != .home {
                    #expect(state.currentChapter != previous.currentChapter)
                }
                states.append(state)
            }
            return states
        }

        let first = journey()
        #expect(first == journey())
        #expect(first.last?.macroIndex == 1_024)
        #expect(Set(first.map(\.currentChapter)) == Set(InterlockChapter.allCases))
    }

    @Test("Foundation identity returns after bounded contrast and breaks")
    func foundationCompanionContinuity() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var sawContrastDeparture = false
        var sawBreakSpace = false
        for _ in 0..<100 {
            let candidates = director.candidates(from: state)
            let plan = candidates.primary
            if plan.kind == .contrast {
                sawContrastDeparture = sawContrastDeparture || candidates.alternate.resolvedBars.contains {
                    $0.foundationCompanion != state.identityDNA.foundationCompanion
                }
            }
            if plan.kind == .majorBreak {
                sawBreakSpace = sawBreakSpace || plan.resolvedBars.contains {
                    $0.foundationCompanion == .empty
                }
            }
            if plan.kind == .lock || plan.kind == .energyRelease || plan.kind == .identityReturn {
                #expect(plan.resolvedBars.allSatisfy {
                    $0.foundationCompanion == state.identityDNA.foundationCompanion
                })
            }
            state.advance(using: plan)
        }
        #expect(sawContrastDeparture)
        #expect(sawBreakSpace)
    }

    @Test("Dark scenes can establish Phrygian identity without changing it between phrases")
    func phrygianIdentityAndMotifFingerprint() {
        let intent = MusicalIntent(values: [.darkness: 1, .atmosphericDarkness: 0.7])
        var matched: (AutonomousSessionDirector, AutonomousSessionState)?
        for seed in UInt64(1)...256 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = AutonomousSessionState(rootSeed: seed, intent: intent)
            if state.identityDNA.modalIdentity == .phrygian {
                matched = (director, state)
                break
            }
        }
        guard let (director, initialState) = matched else {
            Issue.record("Expected a deterministic dark seed to select Phrygian identity")
            return
        }
        #expect(initialState.identityDNA.modalDegrees == [0, 1, 3, 5, 7, 8, 10])
        #expect(initialState.identityDNA.motif.degrees.allSatisfy {
            [0, 1, 3, 5, 7, 8, 10, 12].contains($0)
        })
        var state = initialState
        var fingerprints: [MotifTimbreFingerprint] = []
        for _ in 0..<20 {
            let plan = director.candidates(from: state).primary
            let world = SynthWorldDNA(scene: plan.scene, dna: plan.dna)
            #expect([1, 3, 7, 12].contains(world.shadowInterval))
            fingerprints.append(world.motifFingerprint)
            for resolved in plan.resolvedBars {
                let motif = VoiceRenderer.transformedMotif(
                    dna: plan.dna,
                    performance: resolved.performance,
                    events: resolved.ensemble.events.filter { $0.voice == .motif }
                )
                #expect(motif.allSatisfy { event in
                    let pitchClass = ((event.scaleDegree % 12) + 12) % 12
                    return [0, 1, 3, 5, 7, 8, 10].contains(pitchClass)
                })
            }
            state.advance(using: plan)
        }
        let fingerprint = fingerprints.first
        #expect(fingerprints.dropFirst().allSatisfy { Optional($0) == fingerprint })
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

        let groove = GroovePulseResolver.proposals(
            absoluteBar: 8, percussionActive: true,
            majorBreak: false, gesture: .steady
        )
        let withoutPulses = EnsembleArbiter.resolve(
            proposals: proposals, focusRole: .motif, intentionalPileup: false
        )
        let withPulses = EnsembleArbiter.resolve(
            proposals: proposals + groove, focusRole: .motif, intentionalPileup: false
        )
        #expect(withPulses.events.filter { $0.voice != .groovePulse } == withoutPulses.events)
        let withPulseOccupancy = Dictionary(grouping: withPulses.events, by: \.step)
            .mapValues(\.count)
        #expect(withPulseOccupancy.values.allSatisfy { $0 <= 3 })
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
    @Test("Sparse intent, health, ties, and dual failure follow the bounded selection policy")
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
        #expect(AutonomousCandidateSelector.choose(primary: stagnant, alternate: alternate) == .primary)
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
        #expect(first.audioPreflight.quality.sampleHash == second.audioPreflight.quality.sampleHash)
    }

    @Test("Kick fader trims only the audible and masking path")
    func kickMixHierarchy() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let sourcePlan = director.candidates(from: state).primary
        guard let source = sourcePlan.resolvedBars.first(where: { resolved in
            resolved.ensemble.events.contains { $0.voice == .kick }
        }) else {
            Issue.record("Expected a resolved kick event")
            return
        }

        func replacingSection(_ section: SectionKind) -> ResolvedPerformanceBar {
            let performance = source.performance
            return ResolvedPerformanceBar(
                performance: PerformanceBar(
                    bar: performance.bar,
                    phrase: performance.phrase,
                    localBar: performance.localBar,
                    phraseLength: performance.phraseLength,
                    section: section,
                    tension: performance.tension,
                    roles: performance.roles,
                    transformations: performance.transformations,
                    signatureEvent: performance.signatureEvent,
                    eventSeed: performance.eventSeed,
                    accentContour: performance.accentContour
                ),
                ensemble: source.ensemble,
                arrangementGesture: source.arrangementGesture,
                percussionGear: source.percussionGear,
                foundationCompanion: source.foundationCompanion,
                pulseEchoEnabled: source.pulseEchoEnabled,
                interlockChapter: source.interlockChapter,
                groovePulses: source.groovePulses,
                spatialContrast: source.spatialContrast,
                narrative: source.narrative
            )
        }

        func render(_ resolved: ResolvedPerformanceBar) -> RenderBlock {
            let plan = replacingResolvedBars(
                in: sourcePlan, with: [resolved], memory: state.memory
            )
            var renderState = RenderState()
            var graphState = GeneratedDSPContinuationState()
            return AutonomousPhraseRenderer.render(
                plan: plan,
                graph: DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed),
                sampleRate: 8_000,
                state: &renderState,
                graphState: &graphState
            )[0]
        }

        let regular = render(replacingSection(.groove))
        let breakdown = render(replacingSection(.breakdown))
        #expect(abs(KickMixBalance.audibleLevel(for: .groove) - 0.605_804) < 0.000_001)
        #expect(abs(KickMixBalance.audibleLevel(for: .breakdown) - 0.454_353) < 0.000_001)

        for block in [regular, breakdown] {
            let mix = block.kickMix
            #expect(mix.detectorRMS > 0)
            let measuredTrim = 20 * log10(Double(mix.audibleRMS / mix.detectorRMS))
            let automaticTrim = block.automaticMix.gainsDB[.kick] ?? 0
            let expectedTrim = KickMixBalance.attenuationDB + automaticTrim
            #expect(abs(measuredTrim - expectedTrim) <= 0.05)
            #expect(abs(Double(mix.audiblePeak / mix.detectorPeak) -
                        KickMixBalance.audibleGain * block.automaticMix.gain(for: .kick)) < 0.000_001)
            #expect(abs(mix.audibleGain -
                        KickMixBalance.audibleGain * block.automaticMix.gain(for: .kick)) < 0.000_001)
            #expect(automaticTrim <= AutomaticMixBalancer.homeKickCorrectionDB)
            #expect(automaticTrim >= AutomaticMixBalancer.minimumKickCorrectionDB)
            #expect(abs(mix.duckingEnvelopePeak - mix.detectorPeak) < 0.000_001)
            #expect(mix.maskingInputPeak == mix.audiblePeak)
            #expect(abs((block.busStates[.kick]?.level ?? -1) -
                        Double(mix.audibleRMS)) < 0.000_001)
            let renderedKickSteps = block.events.filter { $0.voice == .kick }.map(\.step)
            let resolvedKickSteps = block.resolvedPerformance.ensemble.events
                .filter { $0.voice == .kick }.map(\.step)
            #expect(renderedKickSteps == resolvedKickSteps)
        }

        let regularUnitRMS = Double(regular.kickMix.detectorRMS) /
            KickMixBalance.regularDetectorLevel
        let breakdownUnitRMS = Double(breakdown.kickMix.detectorRMS) /
            KickMixBalance.breakdownDetectorLevel
        #expect(abs(regularUnitRMS - breakdownUnitRMS) < 0.000_001)
    }

    @Test("Role stems reconstruct the dry buses and report actual levels")
    func roleStemTruth() {
        let prepared = prepare(seed: 42, sampleRate: 8_000)
        for block in prepared.blocks {
            #expect(block.stemReconstruction.dryCenterMaximumError < 0.000_001)
            #expect(block.stemReconstruction.upperMaximumError < 0.000_001)
            #expect(Set(block.stemObservations.keys) == Set(MixRole.allCases))
            #expect(abs((block.stemObservations[.kick]?.rms ?? -1) -
                        Double(block.kickMix.audibleRMS)) < 0.000_001)
            for role in MixRole.allCases where role != .kick {
                #expect(block.automaticMix.gainsDB[role] == 0)
                #expect(block.automaticMix.gain(for: role) == 1)
            }
            for observation in block.stemObservations.values {
                #expect(observation.rms.isFinite)
                #expect(observation.activeRMS.isFinite)
                #expect(observation.onsetRMS.isFinite)
                #expect(observation.peak.isFinite)
                #expect(observation.occupancy >= 0 && observation.occupancy <= 1)
                #expect(observation.bandEnergy.values.allSatisfy { $0.isFinite && $0 >= 0 })
            }
            for event in block.events {
                let role: MixRole = switch event.voice {
                case .kick: .kick
                case .bass, .rumble, .tunedTom: .foundation
                case .percussion, .clap, .openHat, .metallic, .groovePulse: .percussion
                case .synth, .lead: .upperTonal
                case .pad, .riser: .atmosphere
                }
                #expect(abs((block.busStates[event.voice]?.level ?? -1) -
                            (block.stemObservations[role]?.rms ?? -2)) < 0.000_001)
            }
        }
    }

    @Test("Automatic mix trims excessive kick hierarchy without gain drift")
    func automaticMixBounds() {
        func observation(activeRMS: Double, occupancy: Double = 0.5) -> StemObservation {
            StemObservation(
                rms: activeRMS * 0.6,
                activeRMS: activeRMS,
                onsetRMS: activeRMS,
                peak: activeRMS * 1.4,
                crestFactor: 2.3,
                occupancy: occupancy,
                bandEnergy: Dictionary(
                    uniqueKeysWithValues: MixBand.allCases.map { ($0, activeRMS * activeRMS) }
                )
            )
        }
        let excessive: [MixRole: StemObservation] = [
            .kick: observation(activeRMS: 0.30),
            .foundation: observation(activeRMS: 0.01),
        ]
        var state = AutomaticMixState()
        let first = AutomaticMixBalancer.resolve(
            observations: excessive,
            companion: .monoRumble,
            section: .groove,
            state: &state
        )
        #expect(first.gainsDB[.kick] == -1.35)
        #expect(first.measuredKickOverFoundationDB != nil)
        #expect(first.targetKickOverFoundationDB == 27.5)

        let beforeBreak = state
        let breakPlan = AutomaticMixBalancer.resolve(
            observations: excessive,
            companion: .monoRumble,
            section: .breakdown,
            state: &state
        )
        #expect(state == beforeBreak)
        #expect(breakPlan.gainsDB[.kick] == beforeBreak.kickCorrectionDB)

        for _ in 0..<1_024 {
            _ = AutomaticMixBalancer.resolve(
                observations: excessive,
                companion: .monoRumble,
                section: .groove,
                state: &state
            )
            #expect(state.kickCorrectionDB >= AutomaticMixBalancer.minimumKickCorrectionDB)
            #expect(state.kickCorrectionDB <= 0)
            #expect(state.kickCorrectionDB.isFinite)
        }
        let measuredDifference = first.measuredKickOverFoundationDB ?? 0
        let targetDifference = first.targetKickOverFoundationDB ?? 0
        #expect(abs(measuredDifference + state.kickCorrectionDB - targetDifference) <=
                AutomaticMixBalancer.deadbandDB)
        let settledCorrection = state.kickCorrectionDB
        for _ in 0..<1_024 {
            _ = AutomaticMixBalancer.resolve(
                observations: excessive,
                companion: .monoRumble,
                section: .groove,
                state: &state
            )
        }
        #expect(state.kickCorrectionDB == settledCorrection)

        let silentFoundation: [MixRole: StemObservation] = [
            .kick: observation(activeRMS: 0.30),
            .foundation: .silent,
        ]
        let held = state
        _ = AutomaticMixBalancer.resolve(
            observations: silentFoundation,
            companion: .empty,
            section: .groove,
            state: &state
        )
        #expect(state == held)
    }

    @Test("Waveform display retains absolute level relationships")
    func waveformUsesFixedDecibelScale() {
        let loud = [Float](repeating: 0.10, count: 640)
        let quiet = [Float](repeating: 0.05, count: 640)
        let loudEnvelope = WaveformEnvelope.fixedDB(left: loud, right: loud, buckets: 10)
        let quietEnvelope = WaveformEnvelope.fixedDB(left: quiet, right: quiet, buckets: 10)
        #expect(loudEnvelope.count == 10)
        #expect(quietEnvelope.count == 10)
        #expect(zip(loudEnvelope, quietEnvelope).allSatisfy { $0.0 > $0.1 })
        #expect(loudEnvelope == WaveformEnvelope.fixedDB(left: loud, right: loud, buckets: 10))
        let silence = [Float](repeating: 0, count: 640)
        #expect(WaveformEnvelope.fixedDB(left: silence, right: silence, buckets: 10)
            .allSatisfy { $0 == 0.04 })
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
        var renderA = RenderState(), renderB = RenderState()
        var stateA = GeneratedDSPContinuationState(), stateB = GeneratedDSPContinuationState()
        let blocksA = AutonomousPhraseRenderer.render(
            plan: phrase, graph: graphA, sampleRate: 8_000,
            state: &renderA, graphState: &stateA
        )
        let blocksB = AutonomousPhraseRenderer.render(
            plan: phrase, graph: graphB, sampleRate: 8_000,
            state: &renderB, graphState: &stateB
        )
        #expect(AudioQualityReport(blocks: blocksA, sampleRate: 8_000).sampleHash !=
                AudioQualityReport(blocks: blocksB, sampleRate: 8_000).sampleHash)
    }

    @Test("Resolved ensemble events are the audible and reported source of truth")
    func resolvedEventChangesPCMAndMetadata() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let original = director.candidates(from: state).primary
        guard let barIndex = original.resolvedBars.firstIndex(where: { resolved in
            resolved.ensemble.events.contains { $0.voice != .kick }
        }), let target = original.resolvedBars[barIndex].ensemble.events.first(where: {
            $0.voice != .kick
        }) else {
            Issue.record("Expected a non-kick resolved event")
            return
        }
        let sourceResolved = original.resolvedBars[barIndex]
        var events = sourceResolved.ensemble.events
        events.remove(at: events.firstIndex(of: target)!)
        let changedContext = EnsembleContext(
            focusRole: sourceResolved.ensemble.focusRole,
            events: events,
            kickAnchors: sourceResolved.ensemble.kickAnchors,
            intentionalPileup: sourceResolved.ensemble.intentionalPileup
        )
        let changedResolved = ResolvedPerformanceBar(
            performance: sourceResolved.performance,
            ensemble: changedContext,
            arrangementGesture: sourceResolved.arrangementGesture,
            percussionGear: sourceResolved.percussionGear,
            foundationCompanion: sourceResolved.foundationCompanion,
            pulseEchoEnabled: sourceResolved.pulseEchoEnabled,
            interlockChapter: sourceResolved.interlockChapter,
            groovePulses: sourceResolved.groovePulses,
            spatialContrast: sourceResolved.spatialContrast,
            narrative: sourceResolved.narrative
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )

        #expect(originalBlocks[barIndex].events.count == sourceResolved.ensemble.events.count)
        #expect(changedBlocks[barIndex].events.count == changedContext.events.count)
        #expect(originalBlocks[barIndex].events != changedBlocks[barIndex].events)
        let barFrames = originalBlocks[barIndex].left.count
        let start = min(barFrames - 1, target.step * barFrames / 16)
        let end = min(barFrames, start + max(32, barFrames / 16))
        let windowDelta = zip(
            originalBlocks[barIndex].left[start..<end],
            changedBlocks[barIndex].left[start..<end]
        ).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        #expect(windowDelta > 0.000_1)
    }

    @Test("Changing a relational stage changes its metadata and corresponding PCM window")
    func relationalStageChangesPCMAndMetadata() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let original = director.candidates(from: state).primary
        guard let barIndex = original.resolvedBars.firstIndex(where: { resolved in
            resolved.ensemble.events.contains { $0.voice == .motif }
        }), let event = original.resolvedBars[barIndex].ensemble.events.first(where: {
            $0.voice == .motif
        }) else {
            Issue.record("Expected a resolved motif event")
            return
        }

        let source = original.resolvedBars[barIndex]
        let sourcePhase = RelationalCyclePhase(
            macroStep: (source.performance.bar % 16) * 16 + event.step
        )
        guard let barOffset = (1...15).first(where: { offset in
            RelationalCyclePhase(
                macroStep: ((source.performance.bar + offset) % 16) * 16 + event.step
            ).followerStage != sourcePhase.followerStage
        }) else {
            Issue.record("Expected a distinct follower stage in the macro")
            return
        }
        let performance = source.performance
        let shiftedPerformance = PerformanceBar(
            bar: performance.bar + barOffset,
            phrase: performance.phrase,
            localBar: performance.localBar,
            phraseLength: performance.phraseLength,
            section: performance.section,
            tension: performance.tension,
            roles: performance.roles,
            transformations: performance.transformations,
            signatureEvent: performance.signatureEvent,
            eventSeed: performance.eventSeed,
            accentContour: performance.accentContour
        )
        let changedResolved = ResolvedPerformanceBar(
            performance: shiftedPerformance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )

        let originalBlock = originalBlocks[barIndex]
        let changedBlock = changedBlocks[barIndex]
        let originalArticulation = originalBlock.synthPerformance.articulation(at: event.step)
        let changedArticulation = changedBlock.synthPerformance.articulation(at: event.step)
        #expect(originalBlock.events.count == changedBlock.events.count)
        #expect(zip(originalBlock.events, changedBlock.events).allSatisfy { original, changed in
            original.voice == changed.voice && original.step == changed.step &&
                original.intensity == changed.intensity
        })
        #expect(originalArticulation != changedArticulation)
        #expect(originalArticulation.phase.followerStage !=
                changedArticulation.phase.followerStage)
        #expect(originalArticulation.chapter == changedArticulation.chapter)
        let start = event.step * originalBlock.left.count / 16
        let end = min(originalBlock.left.count, start + max(32, originalBlock.left.count / 8))
        let delta = zip(
            originalBlock.left[start..<end], changedBlock.left[start..<end]
        ).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        #expect(delta > 0.000_1)
    }

    @Test("Resolved groove pulse drives metadata, PCM, percussion stem, and no mix decision")
    func groovePulseResolvedRendering() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let original = director.candidates(from: state).primary
        guard let barIndex = original.resolvedBars.firstIndex(where: {
            !$0.groovePulses.isEmpty
        }), let target = original.resolvedBars[barIndex].groovePulses.last else {
            Issue.record("Expected a resolved groove pulse")
            return
        }
        let source = original.resolvedBars[barIndex]
        let changedPulse = GroovePulseArticulation(
            step: target.step,
            pulseClass: target.pulseClass,
            stage: target.stage,
            intensity: target.intensity * 0.5,
            timingOffsetInSteps: target.timingOffsetInSteps
        )
        let changedPulses = source.groovePulses.map {
            $0.step == target.step ? changedPulse : $0
        }
        let changedResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: changedPulses,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )
        let originalBlock = originalBlocks[barIndex]
        let changedBlock = changedBlocks[barIndex]
        let originalEvent = originalBlock.events.first {
            $0.voice == .groovePulse && $0.step == target.step
        }
        let changedEvent = changedBlock.events.first {
            $0.voice == .groovePulse && $0.step == target.step
        }
        #expect(originalEvent?.pulseClass == target.pulseClass)
        #expect(originalEvent?.timingOffsetInSteps == target.timingOffsetInSteps)
        #expect(originalEvent?.intensity == target.intensity)
        #expect(changedEvent?.intensity == changedPulse.intensity)
        #expect(originalBlock.events.filter {
            !($0.voice == .groovePulse && $0.step == target.step)
        } == changedBlock.events.filter {
            !($0.voice == .groovePulse && $0.step == target.step)
        })
        let start = Int((Double(target.step) + target.timingOffsetInSteps) *
                        Double(originalBlock.left.count) / 16.0)
        let end = min(originalBlock.left.count, start + Int(8_000 * 0.12))
        let windowDelta = zip(
            originalBlock.left[start..<end], changedBlock.left[start..<end]
        ).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        #expect(windowDelta > 0.000_1)
        #expect(originalBlock.automaticMix == changedBlock.automaticMix)
        #expect(originalBlock.stemObservations[.kick] == changedBlock.stemObservations[.kick])
        #expect(originalBlock.stemObservations[.foundation] ==
                changedBlock.stemObservations[.foundation])
        #expect(originalBlock.stemObservations[.percussion] !=
                changedBlock.stemObservations[.percussion])
        #expect(originalBlock.busStates[.groovePulse]?.level ==
                originalBlock.stemObservations[.percussion]?.rms)
    }

    @Test("Selective depth resolves once per macro and continues deterministically")
    func selectiveSpatialDepthResolution() {
        func journey() -> [SpatialContrastArticulation] {
            let director = AutonomousSessionDirector()
            var state = director.initialState()
            var articulations: [SpatialContrastArticulation] = []
            var carriersPerMacro: [Int: Int] = [:]
            var previousCarrier: EnsembleVoice?
            var sawContrastCarrier = false
            var sawBreakCarrier = false

            for _ in 0..<80 {
                let plan = director.candidates(from: state).primary
                for resolved in plan.resolvedBars {
                    let spatial = resolved.spatialContrast
                    articulations.append(spatial)
                    if plan.kind == .energyRelease || plan.kind == .identityReturn {
                        #expect(spatial == .foreground)
                    }
                    guard spatial.depthPosition == .distant else { continue }
                    let macro = resolved.performance.bar / 16
                    carriersPerMacro[macro, default: 0] += 1
                    #expect(carriersPerMacro[macro] == 1)
                    #expect(spatial.dryScale == 0.72)
                    #expect(spatial.highPassHz == 300)
                    #expect(spatial.lowPassHz == 4_200)
                    #expect(spatial.carrierVoice != .kick)
                    #expect(spatial.carrierVoice != .bass)
                    #expect(spatial.carrierVoice != .percussion)
                    #expect(spatial.carrierVoice != .groovePulse)
                    #expect(resolved.ensemble.events.contains { spatial.applies(to: $0) })

                    if plan.kind == .contrast {
                        sawContrastCarrier = true
                        #expect(spatial.reverbSend == 0.22)
                        #expect(spatial.carrierVoice == .response ||
                                spatial.carrierVoice == .transition)
                    } else if plan.kind == .majorBreak {
                        sawBreakCarrier = true
                        #expect(spatial.reverbSend == 0.30)
                        #expect(spatial.carrierVoice == .transition ||
                                spatial.carrierVoice == .atmosphere)
                    } else {
                        Issue.record("Unexpected spatial carrier outside contrast or break")
                    }

                    if let previousCarrier {
                        let hasAlternative = resolved.ensemble.events.contains {
                            $0.voice != previousCarrier &&
                                ((plan.kind == .contrast &&
                                  ($0.voice == .response || $0.voice == .transition)) ||
                                 (plan.kind == .majorBreak &&
                                  ($0.voice == .transition || $0.voice == .atmosphere)))
                        }
                        if hasAlternative { #expect(spatial.carrierVoice != previousCarrier) }
                    }
                    previousCarrier = spatial.carrierVoice
                }
                state.advance(using: plan)
            }
            #expect(sawContrastCarrier)
            #expect(sawBreakCarrier)
            #expect(carriersPerMacro.values.allSatisfy { $0 == 1 })
            return articulations
        }

        let first = journey()
        #expect(first == journey())
    }

    @Test("Resolved spatial carrier drives matching metadata and its PCM window")
    func selectiveSpatialDepthRendering() {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var matched: (AutonomousSessionState, AutonomousPhrasePlan, Int)?
        for _ in 0..<80 where matched == nil {
            let plan = director.candidates(from: state).primary
            if let barIndex = plan.resolvedBars.firstIndex(where: {
                $0.spatialContrast.depthPosition == .distant
            }) {
                matched = (state, plan, barIndex)
            } else {
                state.advance(using: plan)
            }
        }
        guard let (sourceState, original, barIndex) = matched else {
            Issue.record("Expected a deterministic selective spatial carrier")
            return
        }

        let source = original.resolvedBars[barIndex]
        guard let carrierStep = source.spatialContrast.carrierStep else {
            Issue.record("Expected the distant carrier to retain its resolved step")
            return
        }
        let dryResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            spatialContrast: .foreground,
            narrative: source.narrative
        )
        var dryBars = original.resolvedBars
        dryBars[barIndex] = dryResolved
        let dry = replacingResolvedBars(in: original, with: dryBars, memory: sourceState.memory)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: sourceState.rootSeed)
        var distantRender = RenderState(), dryRender = RenderState()
        var distantGraph = GeneratedDSPContinuationState()
        var dryGraph = GeneratedDSPContinuationState()
        let distantBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &distantRender, graphState: &distantGraph
        )
        let dryBlocks = AutonomousPhraseRenderer.render(
            plan: dry, graph: graph, sampleRate: 8_000,
            state: &dryRender, graphState: &dryGraph
        )

        #expect(Array(distantBlocks[..<barIndex]) == Array(dryBlocks[..<barIndex]))
        let distantBlock = distantBlocks[barIndex]
        let dryBlock = dryBlocks[barIndex]
        let distantEvent = distantBlock.events.first {
            $0.step == carrierStep && $0.spatialDepthPosition == .distant
        }
        #expect(distantEvent?.spatialReverbSend == source.spatialContrast.reverbSend)
        #expect(dryBlock.events.allSatisfy {
            $0.spatialDepthPosition == .foreground && $0.spatialReverbSend == 0
        })
        #expect(zip(distantBlock.events, dryBlock.events).allSatisfy { distant, foreground in
            distant.voice == foreground.voice && distant.step == foreground.step &&
                distant.intensity == foreground.intensity
        })
        #expect(distantBlock.automaticMix == dryBlock.automaticMix)
        #expect(distantBlock.stemObservations[.kick] == dryBlock.stemObservations[.kick])
        #expect(distantBlock.stemObservations[.foundation] ==
                dryBlock.stemObservations[.foundation])

        let start = carrierStep * distantBlock.left.count / 16
        #expect(Array(distantBlock.left[..<start]) == Array(dryBlock.left[..<start]))
        let delta = zip(distantBlock.left[start...], dryBlock.left[start...]).reduce(0.0) {
            $0 + abs(Double($1.0 - $1.1))
        }
        #expect(delta > 0.000_1)
    }

    @Test("Narrative presence and support evolve continuously at structural boundaries")
    func narrativeEvolutionAndSupportGating() {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var previousPresence = 0.50
        var previousContext: (roles: [PerformanceRole], gesture: ArrangementGesture,
                              direction: NarrativeDirection, kind: AutonomousPhraseKind)?
        var observedKinds = Set<AutonomousPhraseKind>()
        var sawSupportAdmission = false
        var sawSupportRemoval = false

        for _ in 0..<80 {
            let plan = director.candidates(from: state).primary
            observedKinds.insert(plan.kind)
            #expect(abs((plan.resolvedBars.first?.narrative.presenceStart ?? -1) -
                        previousPresence) < 0.000_000_1)

            for resolved in plan.resolvedBars {
                let narrative = resolved.narrative
                #expect((0...1).contains(narrative.presenceStart))
                #expect((0...1).contains(narrative.presenceEnd))
                #expect(resolved.performance.roles.contains(.foundation))
                if plan.kind != .majorBreak {
                    #expect(resolved.performance.roles.contains(.motif))
                } else {
                    #expect(narrative.activeSupportingRoles == [.atmosphere])
                    #expect(!resolved.performance.roles.contains(.percussion))
                    #expect(!resolved.performance.roles.contains(.response))
                }
                #expect(narrative.activeSupportingRoles.count <= 3)

                if let previousContext,
                   previousContext.roles != narrative.activeSupportingRoles {
                    let previousSet = Set(previousContext.roles)
                    let currentSet = Set(narrative.activeSupportingRoles)
                    let changedCount = previousSet.symmetricDifference(currentSet).count
                    let breakReset = plan.kind == .majorBreak &&
                        resolved.performance.localBar == 0
                    if !breakReset {
                        #expect(changedCount == 1)
                        #expect(resolved.performance.bar.isMultiple(of: 4))
                    }
                    if currentSet.count > previousSet.count {
                        sawSupportAdmission = true
                        #expect(previousContext.gesture != .minimalize)
                        #expect(previousContext.direction == .emerging ||
                                previousContext.kind == .contrast ||
                                previousContext.kind == .energyRelease ||
                                plan.kind == .majorBreak)
                    } else if currentSet.count < previousSet.count, !breakReset {
                        sawSupportRemoval = true
                        #expect(previousContext.direction == .receding)
                        #expect(previousContext.gesture == .turnaround)
                    }
                }

                previousPresence = narrative.presenceEnd
                previousContext = (
                    narrative.activeSupportingRoles,
                    resolved.arrangementGesture,
                    narrative.direction,
                    plan.kind
                )
            }

            let expectedTarget: Double = switch plan.kind {
            case .lock: 0.56
            case .contrast: 0.76
            case .majorBreak: 0.20
            case .identityReturn: 0.58
            case .energyRelease: 0.60
            }
            if plan.kind == .energyRelease {
                let peak = plan.resolvedBars.first {
                    ($0.performance.bar + 1).isMultiple(of: 16)
                }
                #expect(abs((peak?.narrative.presenceEnd ?? -1) - 0.90) < 0.000_000_1)
                if plan.resolvedBars.last?.performance.bar == peak?.performance.bar {
                    #expect(plan.endingNarrativeState.releaseSettlementPending)
                } else {
                    #expect(abs((plan.resolvedBars.last?.narrative.presenceEnd ?? -1) - 0.60) <
                            0.000_000_1)
                    #expect(!plan.endingNarrativeState.releaseSettlementPending)
                }
            } else {
                #expect(abs((plan.resolvedBars.last?.narrative.presenceEnd ?? -1) -
                            expectedTarget) < 0.000_000_1)
            }
            if plan.kind == .identityReturn,
               let finalBar = plan.resolvedBars.last?.performance.bar,
               (finalBar + 1).isMultiple(of: 16) {
                #expect(plan.endingNarrativeState.activeSupportingRoles.contains(.percussion))
            }
            #expect(abs(plan.endingNarrativeState.protagonistPresence - previousPresence) <
                    0.000_000_1)
            state.advance(using: plan)
        }

        #expect(observedKinds == Set(AutonomousPhraseKind.allCases))
        #expect(sawSupportAdmission)
        #expect(sawSupportRemoval)
    }

    @Test("Resolved narrative articulation drives motif metadata and PCM only")
    func narrativeRenderingTruth() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let original = director.candidates(from: state).primary
        guard let barIndex = original.resolvedBars.firstIndex(where: { resolved in
            resolved.ensemble.events.contains { $0.voice == .motif }
        }), let motif = original.resolvedBars[barIndex].ensemble.events
            .filter({ $0.voice == .motif }).min(by: { $0.step < $1.step }) else {
            Issue.record("Expected a resolved dominant motif")
            return
        }
        let source = original.resolvedBars[barIndex]
        let changedNarrative = NarrativeArticulation(
            presenceStart: 0.90,
            presenceEnd: 0.90,
            activeSupportingRoles: source.narrative.activeSupportingRoles
        )
        let changedResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            spatialContrast: source.spatialContrast,
            narrative: changedNarrative
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )

        #expect(Array(originalBlocks[..<barIndex]) == Array(changedBlocks[..<barIndex]))
        let originalBlock = originalBlocks[barIndex]
        let changedBlock = changedBlocks[barIndex]
        let originalEvent = originalBlock.events.first {
            $0.step == motif.step && $0.narrativePresence != nil
        }
        let changedEvent = changedBlock.events.first {
            $0.step == motif.step && $0.narrativePresence != nil
        }
        #expect(originalEvent?.narrativePresence == source.narrative.presence(atStep: motif.step))
        #expect(changedEvent?.narrativeDirection == .holding)
        #expect(changedEvent?.narrativePresence == 0.90)
        #expect(changedEvent?.narrativeGainScale ==
                changedNarrative.motifGainScale(atStep: motif.step))
        #expect(changedEvent?.narrativeSpectralScale ==
                changedNarrative.motifSpectralScale(atStep: motif.step))
        #expect(zip(originalBlock.events, changedBlock.events).allSatisfy { original, changed in
            original.voice == changed.voice && original.step == changed.step &&
                original.intensity == changed.intensity
        })
        #expect(changedBlock.events.filter { $0.narrativePresence != nil }.allSatisfy {
            $0.voice == .synth
        })
        #expect(originalBlock.synthWorld.motifFingerprint ==
                changedBlock.synthWorld.motifFingerprint)
        #expect(originalBlock.automaticMix == changedBlock.automaticMix)
        #expect(originalBlock.stemObservations[.kick] == changedBlock.stemObservations[.kick])
        #expect(originalBlock.stemObservations[.foundation] ==
                changedBlock.stemObservations[.foundation])
        #expect(originalBlock.stemObservations[.percussion] ==
                changedBlock.stemObservations[.percussion])
        #expect(originalBlock.stemObservations[.upperTonal] !=
                changedBlock.stemObservations[.upperTonal])

        let start = motif.step * originalBlock.left.count / 16
        #expect(Array(originalBlock.left[..<start]) == Array(changedBlock.left[..<start]))
        let delta = zip(originalBlock.left[start...], changedBlock.left[start...]).reduce(0.0) {
            $0 + abs(Double($1.0 - $1.1))
        }
        #expect(delta > 0.000_1)
    }

    @Test("Groove pulse carrier is deterministic, mono, short, and low-cut")
    func groovePulseCarrierSignal() {
        let sampleRate = 44_100.0
        let start = 97
        let count = Int(sampleRate * 0.09)
        func render(intensity: Double) -> [Float] {
            var output = [Float](repeating: 0, count: count)
            var measurement = [Float](repeating: 0, count: count)
            GroovePulseVoice.render(
                &output, measurement: &measurement,
                start: start, sampleRate: sampleRate,
                intensity: intensity, seed: 48_291
            )
            #expect(output == measurement)
            return output
        }
        let left = render(intensity: 0.72)
        let right = render(intensity: 0.72)
        let quieter = render(intensity: 0.36)
        #expect(left == right)
        #expect(left != quieter)
        #expect(left[..<start].allSatisfy { $0 == 0 })
        let expectedEnd = start + Int(sampleRate * GroovePulseVoice.durationSeconds)
        #expect(left[expectedEnd...].allSatisfy { $0 == 0 })
        #expect(left.contains { abs($0) > 0.000_001 })
        let delta = zip(left, quieter).map { Double($0.0 - $0.1) }
        #expect(delta[..<start].allSatisfy { $0 == 0 })
        #expect(delta[expectedEnd...].allSatisfy { $0 == 0 })

        var low = 0.0
        let coefficient = 1 - exp(-2 * Double.pi * 300 / sampleRate)
        var lowEnergy = 0.0
        var totalEnergy = 0.0
        for sample in left {
            let value = Double(sample)
            low += (value - low) * coefficient
            lowEnergy += low * low
            totalEnergy += value * value
        }
        #expect(lowEnergy / max(totalEnergy, 0.000_000_1) < 0.12)
        #expect(GroovePulseVoice.baseLevel == 0.045)
        #expect(GroovePulseVoice.highPassFrequency == 550)
        #expect(GroovePulseVoice.lowPassFrequency == 3_200)
    }

    @Test("Rumble remains a protected mono-compatible foundation companion")
    func monoRumbleProtection() {
        var matched: (UInt64, AutonomousPhrasePlan)?
        for seed in UInt64(1)...256 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let plan = director.candidates(from: state).primary
            if plan.resolvedBars.contains(where: { $0.foundationCompanion == .monoRumble }) {
                matched = (seed, plan)
                break
            }
        }
        guard let (seed, plan) = matched else {
            Issue.record("Expected a deterministic rumble identity")
            return
        }
        let graph = DSPGraphGenerator.safePlan(sessionSeed: seed)
        var render = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan, graph: graph, sampleRate: 8_000,
            state: &render, graphState: &graphState
        )
        let report = AudioQualityReport(blocks: blocks, sampleRate: 8_000)
        #expect(blocks.flatMap(\.events).contains { $0.voice == .rumble })
        #expect(report.lowStereoCorrelation > 0.98)
    }

    @Test("Three-sixteenth pulse echo is sparse, audible, and low-cut")
    func pulseEchoSignalBehavior() {
        var matched: (AutonomousSessionState, AutonomousPhrasePlan, Int, EnsembleResolvedEvent)?
        for fixture in UInt64(1)...64 where matched == nil {
            let director = AutonomousSessionDirector(rootSeed: fixture)
            var state = director.initialState()
            for _ in 0..<40 where matched == nil {
                let plan = director.candidates(from: state).primary
                #expect(plan.resolvedBars.filter(\.pulseEchoEnabled).allSatisfy {
                    $0.foundationCompanion != .monoRumble &&
                        ($0.arrangementGesture == .gearShift ||
                         $0.arrangementGesture == .turnaround)
                })
                for (barIndex, resolved) in plan.resolvedBars.enumerated() {
                    guard resolved.foundationCompanion != .monoRumble else { continue }
                    if let event = resolved.ensemble.events.first(where: { event in
                        guard event.voice == .motif || event.voice == .response else { return false }
                        let macroStep = (resolved.performance.bar % 16) * 16 + event.step
                        let stage = RelationalCyclePhase(macroStep: macroStep).followerStage
                        return stage == .open || stage == .spill
                    }) {
                        matched = (state, plan, barIndex, event)
                        break
                    }
                }
                if matched == nil { state.advance(using: plan) }
            }
        }
        guard let (sourceState, sourcePlan, barIndex, event) = matched else {
            Issue.record("Expected a relationally echoable upper-voice event")
            return
        }

        func replacingEcho(in resolved: ResolvedPerformanceBar, enabled: Bool,
                           companion: FoundationCompanion? = nil) -> ResolvedPerformanceBar {
            ResolvedPerformanceBar(
                performance: resolved.performance,
                ensemble: resolved.ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                foundationCompanion: companion ?? resolved.foundationCompanion,
                pulseEchoEnabled: enabled,
                interlockChapter: .memory,
                groovePulses: resolved.groovePulses,
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }
        let sourceBar = sourcePlan.resolvedBars[barIndex]
        var wetBars = sourcePlan.resolvedBars
        var dryBars = sourcePlan.resolvedBars
        wetBars[barIndex] = replacingEcho(in: sourceBar, enabled: true)
        dryBars[barIndex] = replacingEcho(in: sourceBar, enabled: false)
        let protected = replacingEcho(in: sourceBar, enabled: true, companion: .monoRumble)
        #expect(!protected.pulseEchoEnabled)

        let wetPlan = replacingResolvedBars(
            in: sourcePlan, with: wetBars, memory: sourceState.memory
        )
        let dryPlan = replacingResolvedBars(
            in: sourcePlan, with: dryBars, memory: sourceState.memory
        )
        let graph = DSPGraphGenerator.safePlan(sessionSeed: sourceState.rootSeed)
        var wetRender = RenderState(), dryRender = RenderState()
        var wetGraph = GeneratedDSPContinuationState(), dryGraph = GeneratedDSPContinuationState()
        let wet = AutonomousPhraseRenderer.render(
            plan: wetPlan, graph: graph, sampleRate: 8_000,
            state: &wetRender, graphState: &wetGraph
        )
        let dry = AutonomousPhraseRenderer.render(
            plan: dryPlan, graph: graph, sampleRate: 8_000,
            state: &dryRender, graphState: &dryGraph
        )
        let wetArticulation = wet[barIndex].synthPerformance.articulation(at: event.step)
        let dryArticulation = dry[barIndex].synthPerformance.articulation(at: event.step)
        #expect(wetArticulation.pulseEchoSend > 0)
        #expect(dryArticulation.pulseEchoSend == 0)
        #expect(wet[barIndex].events == dry[barIndex].events)
        #expect(wet[barIndex].effects.contains { $0.kind == .pulseEcho && $0.active })
        #expect(!dry[barIndex].effects.contains { $0.kind == .pulseEcho && $0.active })
        let difference = zip(wet.flatMap(\.left), dry.flatMap(\.left)).map {
            Double($0.0 - $0.1)
        }
        let totalEnergy = difference.reduce(0.0) { $0 + $1 * $1 }
        var low = 0.0
        let coefficient = 1 - exp(-2 * Double.pi * 120 / 8_000)
        var lowEnergy = 0.0
        for sample in difference {
            low += (sample - low) * coefficient
            lowEnergy += low * low
        }
        #expect(totalEnergy > 0.000_000_1)
        #expect(lowEnergy / max(totalEnergy, 0.000_000_1) < 0.45)
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

    private func replacingResolvedBars(in plan: AutonomousPhrasePlan,
                                       with resolvedBars: [ResolvedPerformanceBar],
                                       memory: TemporalMusicalMemory) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            barCount: resolvedBars.count,
            kind: plan.kind,
            scene: plan.scene,
            dna: plan.dna,
            resolvedBars: resolvedBars,
            openedDebt: plan.openedDebt,
            paidDebtIDs: plan.paidDebtIDs,
            requestsTopologyMutation: plan.requestsTopologyMutation,
            alternate: plan.alternate,
            conservative: plan.conservative,
            interest: PhraseInterestEvaluator.evaluate(
                resolvedBars: resolvedBars,
                kind: plan.kind,
                memory: memory,
                identityPreserved: plan.scene.seed == plan.dna.sceneSeed
            ),
            endingInterlockState: plan.endingInterlockState,
            endingSpatialContrastState: plan.endingSpatialContrastState,
            endingNarrativeState: plan.endingNarrativeState
        )
    }

    private func prepare(state: AutonomousSessionState, sampleRate: Double,
                         renderState: RenderState = RenderState(),
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
