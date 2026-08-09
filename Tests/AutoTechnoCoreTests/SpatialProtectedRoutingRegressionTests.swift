import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing

@Suite("Spatial carrier and protected routing regressions")
struct SpatialProtectedRoutingRegressionTests {
    @Test("Groove-pulse evidence is bit-exact across full and protected layers")
    func groovePulseEvidenceMatchesProtectedRoute() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let sourcePlan = director.candidates(from: director.initialState()).primary
        let source = try #require(sourcePlan.resolvedBars.first {
            WeakSixteenthStage(absoluteBar: $0.performance.bar) == .syncopatedLean &&
                $0.arrangementGesture != .minimalize &&
                $0.groovePulses.count == 8
        })
        #expect(source.groovePulses.map(\.intensity) == [
            0.30, 0.72, 0.30, 0.30, 0.72, 0.30, 0.30, 0.72,
        ])
        let pulseEvents = source.ensemble.events.filter { $0.voice == .groovePulse }
        let isolated = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: EnsembleContext(
                focusRole: .percussion,
                events: pulseEvents,
                kickAnchors: [],
                intentionalPileup: false
            ),
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: .empty,
            pulseEchoEnabled: false,
            interlockChapter: .home,
            groovePulses: source.groovePulses,
            spatialContrast: .foreground,
            narrative: source.narrative
        )
        let synthPlan = SynthPerformancePlan(
            scene: sourcePlan.scene,
            dna: sourcePlan.dna,
            kind: sourcePlan.kind,
            resolvedBars: [isolated],
            conservative: sourcePlan.conservative,
            forceHomeUpperTimbre: true
        )
        let plannedSynth = synthPlan.bars[0]
        let noUpperNotes = SynthPerformanceBar(
            bar: plannedSynth.bar,
            gesture: plannedSynth.gesture,
            mutationAmount: plannedSynth.mutationAmount,
            relationalSteps: plannedSynth.relationalSteps,
            upperNotes: []
        )

        func render(_ layer: RenderLayer) -> RenderedBar {
            var state = RenderState()
            var workspace = RenderWorkspace()
            return VoiceRenderer.renderBar(
                scene: sourcePlan.scene,
                sampleRate: 48_000,
                state: &state,
                dna: sourcePlan.dna,
                resolved: isolated,
                synthWorld: synthPlan.world,
                synthPerformance: noUpperNotes,
                workspace: &workspace,
                layer: layer
            )
        }

        let full = render(.full)
        let protected = render(.protectedRhythm)
        #expect(!full.groovePulseRenderEvidence.isEmpty)
        #expect(full.groovePulseRenderEvidence == protected.groovePulseRenderEvidence)
        #expect(full.dryPercussionSampleHash == protected.dryPercussionSampleHash)
        #expect(full.leftSamples == protected.leftSamples)
        #expect(full.rightSamples == protected.rightSamples)
    }

    @Test("Stochastic percussion is one bit-exact protected-rhythm performance")
    func stochasticPercussionProtectedRouteIsBitExact() throws {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let sourcePlan = director.candidates(from: director.initialState()).primary
        let percussionVoices: [EnsembleVoice] = [
            .percussion, .clap, .openHat, .metallic,
        ]
        let source = try #require(sourcePlan.resolvedBars.first { resolved in
            resolved.ensemble.events.contains { percussionVoices.contains($0.voice) }
        })
        let isolatedEvents = source.ensemble.events.filter {
            percussionVoices.contains($0.voice)
        }
        let isolated = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: EnsembleContext(
                focusRole: .percussion,
                events: isolatedEvents,
                kickAnchors: [],
                intentionalPileup: false
            ),
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: false,
            interlockChapter: .home,
            groovePulses: [],
            spatialContrast: .foreground,
            narrative: source.narrative
        )
        let synthPlan = SynthPerformancePlan(
            scene: sourcePlan.scene,
            dna: sourcePlan.dna,
            kind: sourcePlan.kind,
            resolvedBars: [isolated],
            conservative: true,
            forceHomeUpperTimbre: true
        )
        let plannedSynth = synthPlan.bars[0]
        let noUpperNotes = SynthPerformanceBar(
            bar: plannedSynth.bar,
            gesture: plannedSynth.gesture,
            mutationAmount: plannedSynth.mutationAmount,
            relationalSteps: plannedSynth.relationalSteps,
            upperNotes: []
        )

        func render(_ layer: RenderLayer) -> (RenderedBar, RenderState) {
            var state = RenderState()
            var workspace = RenderWorkspace()
            let rendered = VoiceRenderer.renderBar(
                scene: sourcePlan.scene,
                sampleRate: 8_000,
                state: &state,
                dna: sourcePlan.dna,
                resolved: isolated,
                synthWorld: synthPlan.world,
                synthPerformance: noUpperNotes,
                workspace: &workspace,
                layer: layer
            )
            return (rendered, state)
        }

        let full = render(.full)
        let protected = render(.protectedRhythm)
        let replay = render(.full)
        #expect((full.0.stemObservations[.percussion]?.rms ?? 0) > 0)
        #expect(full.0.leftSamples == protected.0.leftSamples)
        #expect(full.0.rightSamples == protected.0.rightSamples)
        #expect(zip(full.0.leftSamples, protected.0.leftSamples).allSatisfy {
            ($0 - $1).bitPattern == Float.zero.bitPattern
        })
        #expect(zip(full.0.rightSamples, protected.0.rightSamples).allSatisfy {
            ($0 - $1).bitPattern == Float.zero.bitPattern
        })
        #expect(full.0.dryFoundationSampleHash == protected.0.dryFoundationSampleHash)
        #expect(full.0.dryPercussionSampleHash == protected.0.dryPercussionSampleHash)
        #expect(full.0.masking.count == 12)
        #expect(protected.0.masking.isEmpty)
        #expect(full.0 == replay.0)
        #expect(full.1 == replay.1)
    }

    @Test("A suspended major-break transition carrier drives truthful metadata and PCM")
    func suspendedTransitionCarrierRenders() {
        guard let (plan, barIndex) = transitionCarrierFixture() else {
            Issue.record("Expected a deterministic major-break transition carrier")
            return
        }
        let source = plan.resolvedBars[barIndex]
        guard let carrierStep = source.spatialContrast.carrierStep else {
            Issue.record("Expected the transition carrier to retain its step")
            return
        }
        #expect(plan.kind == .majorBreak)
        #expect(source.performance.section == .breakdown)
        #expect(source.spatialContrast.carrierVoice == .transition)

        var foregroundBars = plan.resolvedBars
        foregroundBars[barIndex] = replacing(
            source,
            spatialContrast: .foreground
        )
        let foregroundPlan = replacing(plan, resolvedBars: foregroundBars)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: plan.dna.sceneSeed)
        var distantState = RenderState()
        var foregroundState = RenderState()
        var distantGraphState = GeneratedDSPContinuationState()
        var foregroundGraphState = GeneratedDSPContinuationState()
        let distant = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &distantState,
            graphState: &distantGraphState
        )
        let foreground = AutonomousPhraseRenderer.render(
            plan: foregroundPlan,
            graph: graph,
            sampleRate: 8_000,
            state: &foregroundState,
            graphState: &foregroundGraphState
        )

        let distantBlock = distant[barIndex]
        let foregroundBlock = foreground[barIndex]
        let distantEvent = distantBlock.events.first {
            $0.voice == .riser && $0.step == carrierStep
        }
        let foregroundEvent = foregroundBlock.events.first {
            $0.voice == .riser && $0.step == carrierStep
        }
        #expect(distantEvent?.spatialDepthPosition == .distant)
        #expect(distantEvent?.spatialReverbSend == 0.30)
        #expect(foregroundEvent?.spatialDepthPosition == .foreground)
        #expect(foregroundEvent?.spatialReverbSend == 0)
        let distantCarrierFrame = Int((
            Double(carrierStep) * Double(distantBlock.left.count) / 16
        ).rounded())
        let foregroundCarrierFrame = Int((
            Double(carrierStep) * Double(foregroundBlock.left.count) / 16
        ).rounded())
        #expect(distantBlock.upperNoteRenderEvidence.contains {
            $0.role == .transition && $0.onsetFrame == distantCarrierFrame
        })
        #expect(!foregroundBlock.upperNoteRenderEvidence.contains {
            $0.role == .transition && $0.onsetFrame == foregroundCarrierFrame
        })

        let start = distantCarrierFrame
        #expect(Array(distantBlock.left[..<start]) == Array(foregroundBlock.left[..<start]))
        let pcmDelta = zip(
            distantBlock.left[start...],
            foregroundBlock.left[start...]
        ).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        #expect(pcmDelta > 0.000_1)
        #expect(distant.map(\.protectedFoundationSampleHash) ==
                foreground.map(\.protectedFoundationSampleHash))
    }

    @Test("Spatial and tone articulation preserve exact foundation sample fingerprints")
    func articulationPreservesFoundationSamples() {
        let director = AutonomousSessionDirector()
        let plan = director.candidates(from: director.initialState()).primary
        guard let (barIndex, motif) = toneCandidate(in: plan) else {
            Issue.record("Expected a motif event suitable for tone sculpture")
            return
        }
        let source = plan.resolvedBars[barIndex]
        var toneBars = plan.resolvedBars
        var neutralBars = plan.resolvedBars
        toneBars[barIndex] = replacing(source, interlockChapter: .tone)
        neutralBars[barIndex] = replacing(source, interlockChapter: .home)
        let tonePlan = replacing(plan, resolvedBars: toneBars)
        let neutralPlan = replacing(plan, resolvedBars: neutralBars)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: plan.dna.sceneSeed)
        var toneState = RenderState()
        var neutralState = RenderState()
        var toneGraphState = GeneratedDSPContinuationState()
        var neutralGraphState = GeneratedDSPContinuationState()
        let tone = AutonomousPhraseRenderer.render(
            plan: tonePlan,
            graph: graph,
            sampleRate: 8_000,
            state: &toneState,
            graphState: &toneGraphState
        )
        let neutral = AutonomousPhraseRenderer.render(
            plan: neutralPlan,
            graph: graph,
            sampleRate: 8_000,
            state: &neutralState,
            graphState: &neutralGraphState
        )

        let toneEvent = tone[barIndex].events.first {
            $0.voice == .synth && $0.step == motif.step
        }
        let neutralEvent = neutral[barIndex].events.first {
            $0.voice == .synth && $0.step == motif.step
        }
        #expect((toneEvent?.spectralAperture ?? 0) > 0)
        #expect((toneEvent?.bandPassBlend ?? 0) > 0)
        #expect(neutralEvent?.spectralAperture == 0)
        #expect(neutralEvent?.bandPassBlend == 0)
        #expect(tone[barIndex].left != neutral[barIndex].left)
        #expect(tone.map(\.protectedFoundationSampleHash) ==
                neutral.map(\.protectedFoundationSampleHash))
    }

    private func transitionCarrierFixture() -> (AutonomousPhrasePlan, Int)? {
        let seeds = [
            AutonomousSessionDirector.defaultSeed,
            42,
            90_909,
        ] + Array(UInt64(1)...UInt64(32))
        for seed in seeds {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<160 {
                let plan = director.candidates(from: state).primary
                if plan.kind == .majorBreak,
                   let index = plan.resolvedBars.firstIndex(where: {
                       $0.spatialContrast.depthPosition == .distant &&
                           $0.spatialContrast.carrierVoice == .transition
                   }) {
                    return (plan, index)
                }
                state.advance(using: plan)
            }
        }
        return nil
    }

    private func toneCandidate(in plan: AutonomousPhrasePlan)
        -> (Int, EnsembleResolvedEvent)? {
        for (index, resolved) in plan.resolvedBars.enumerated().reversed() {
            for motif in resolved.ensemble.events where motif.voice == .motif {
                let macroStep = (resolved.performance.bar % 16) * 16 + motif.step
                let articulation = RelationalArticulation(
                    chapter: .tone,
                    phase: RelationalCyclePhase(macroStep: macroStep),
                    pulseEchoEligible: false
                )
                if articulation.spectralAperture > 0.05,
                   articulation.bandPassBlend > 0,
                   abs(articulation.anchorSpectralScale - 1) > 0.001 {
                    return (index, motif)
                }
            }
        }
        return nil
    }

    private func replacing(
        _ resolved: ResolvedPerformanceBar,
        spatialContrast: SpatialContrastArticulation? = nil,
        interlockChapter: InterlockChapter? = nil
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: resolved.ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: interlockChapter ?? resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            spatialContrast: spatialContrast ?? resolved.spatialContrast,
            narrative: resolved.narrative
        )
    }

    private func replacing(
        _ plan: AutonomousPhrasePlan,
        resolvedBars: [ResolvedPerformanceBar]
    ) -> AutonomousPhrasePlan {
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
            interest: plan.interest,
            endingInterlockState: plan.endingInterlockState,
            endingSpatialContrastState: plan.endingSpatialContrastState,
            endingNarrativeState: plan.endingNarrativeState
        )
    }
}
