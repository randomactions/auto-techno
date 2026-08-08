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
                interlockChapter: source.interlockChapter
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
                case .percussion, .clap, .openHat, .metallic: .percussion
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
            interlockChapter: sourceResolved.interlockChapter
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
            interlockChapter: source.interlockChapter
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
                interlockChapter: .memory
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
            endingInterlockState: plan.endingInterlockState
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
