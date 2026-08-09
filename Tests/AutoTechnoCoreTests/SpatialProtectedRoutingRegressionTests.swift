import AutoTechnoCore
import AutoTechnoDSP
import Testing

@Suite("Spatial carrier and protected routing regressions")
struct SpatialProtectedRoutingRegressionTests {
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

        let start = carrierStep * distantBlock.left.count / 16
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
