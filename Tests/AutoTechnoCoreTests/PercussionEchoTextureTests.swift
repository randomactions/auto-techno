import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing

@Suite("Score-owned gated percussion texture")
struct PercussionEchoTextureTests {
    @Test("The director resolves one bounded contrast gesture and fallback stays neutral")
    func scoreOwnershipAndReachability() throws {
        let first = try #require(activePrimaryFixture())
        let second = try #require(activePrimaryFixture())
        #expect(first.candidates == second.candidates)
        #expect(first.state == second.state)

        let activeBars = first.candidates.primary.resolvedBars.filter {
            $0.percussionEchoTexture != nil
        }
        #expect(!activeBars.isEmpty)
        #expect(first.candidates.fallback.resolvedBars.allSatisfy {
            $0.percussionEchoTexture == nil
        })
        for resolved in first.candidates.primary.resolvedBars {
            let expected = PercussionEchoTextureResolver.articulation(
                ensemble: resolved.ensemble,
                kind: first.candidates.primary.kind,
                character: resolved.performanceCharacter,
                gesture: resolved.arrangementGesture,
                conservative: first.candidates.primary.conservative
            )
            #expect(resolved.percussionEchoTexture == expected)
            if let articulation = resolved.percussionEchoTexture {
                let source = try #require(
                    PercussionEchoTextureResolver.eligibleSourceEvents(
                        in: resolved.ensemble
                    ).first
                )
                #expect(resolved.performanceCharacter == .brokenSuspension)
                #expect(resolved.arrangementGesture == .gearShift)
                #expect(articulation.inputStep == source.step)
                #expect(articulation.outputStartStep == source.step + 4)
                #expect(articulation.outputEndStep == source.step + 8)
                #expect(articulation.outputEndStep < 16)
            }
        }

        let activeIndex = try #require(first.candidates.primary.resolvedBars.firstIndex {
            $0.percussionEchoTexture != nil
        })
        let activeBar = first.candidates.primary.resolvedBars[activeIndex]
        var neutralBars = first.candidates.primary.resolvedBars
        neutralBars[activeIndex] = replacingTexture(in: activeBar, with: nil)
        let neutralPlan = replacingBars(
            in: first.candidates.primary,
            with: neutralBars
        )
        #expect(AutonomousCandidateFingerprint.plan(first.candidates.primary) !=
                AutonomousCandidateFingerprint.plan(neutralPlan))
    }

    @Test("The later output gate changes only the protected percussion consequence")
    func protectedRendererDifferential() throws {
        let fixture = try #require(activePrimaryFixture())
        let plan = fixture.candidates.primary
        let index = try #require(plan.resolvedBars.firstIndex {
            $0.percussionEchoTexture != nil
        })
        let activeResolved = plan.resolvedBars[index]
        let neutralResolved = replacingTexture(in: activeResolved, with: nil)
        let activeSynth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [activeResolved],
            conservative: plan.conservative
        )
        let neutralSynth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [neutralResolved],
            conservative: plan.conservative
        )
        #expect(activeSynth.bars == neutralSynth.bars)

        var activeState = RenderState()
        activeState.barIndex = activeResolved.performance.bar
        var neutralState = activeState
        var activeWorkspace = RenderWorkspace()
        var neutralWorkspace = RenderWorkspace()
        let active = VoiceRenderer.renderBar(
            scene: plan.scene,
            sampleRate: 8_000,
            state: &activeState,
            dna: plan.dna,
            resolved: activeResolved,
            synthWorld: activeSynth.world,
            synthPerformance: activeSynth.bars[0],
            workspace: &activeWorkspace,
            layer: .protectedRhythm
        )
        let neutral = VoiceRenderer.renderBar(
            scene: plan.scene,
            sampleRate: 8_000,
            state: &neutralState,
            dna: plan.dna,
            resolved: neutralResolved,
            synthWorld: neutralSynth.world,
            synthPerformance: neutralSynth.bars[0],
            workspace: &neutralWorkspace,
            layer: .protectedRhythm
        )

        let evidence = active.percussionEchoTextureRenderEvidence
        #expect(evidence.active)
        #expect(evidence.inputPeak > 0)
        #expect(evidence.inputRMS > 0)
        #expect(evidence.returnPeak > 0)
        #expect(evidence.returnRMS > 0)
        #expect(evidence.returnNonzeroSampleCount > 0)
        #expect(evidence.outOfWindowNonzeroSampleCount == 0)
        #expect(evidence.firstOutputSampleBitPattern & 0x7fff_ffff == 0)
        #expect(evidence.lastOutputSampleBitPattern & 0x7fff_ffff == 0)
        #expect(!neutral.percussionEchoTextureRenderEvidence.active)
        #expect(active.dryPercussionSampleHash == neutral.dryPercussionSampleHash)
        #expect(active.dryFoundationSampleHash == neutral.dryFoundationSampleHash)
        #expect(active.kickMix == neutral.kickMix)
        #expect(active.groovePulseRenderEvidence == neutral.groovePulseRenderEvidence)
        #expect(active.closedHatRenderEvidence == neutral.closedHatRenderEvidence)
        #expect(active.leftSamples != neutral.leftSamples)
        #expect(active.rightSamples != neutral.rightSamples)

        let articulation = try #require(activeResolved.percussionEchoTexture)
        let outputStartPosition = Double(articulation.outputStartStep) *
            Double(active.leftSamples.count) / 16.0
        let outputStartFrame = Int(outputStartPosition.rounded())
        #expect(Array(active.leftSamples.prefix(outputStartFrame)) ==
                Array(neutral.leftSamples.prefix(outputStartFrame)))
        #expect(Array(active.rightSamples.prefix(outputStartFrame)) ==
                Array(neutral.rightSamples.prefix(outputStartFrame)))
    }

    @Test("Preparation rejects a forged input window before rendering")
    func forgedScoreRejected() throws {
        let fixture = try #require(activePrimaryFixture())
        let activeIndex = try #require(fixture.candidates.primary.resolvedBars.firstIndex {
            $0.percussionEchoTexture != nil
        })
        let activeBar = fixture.candidates.primary.resolvedBars[activeIndex]
        let articulation = try #require(activeBar.percussionEchoTexture)
        var forgedBars = fixture.candidates.primary.resolvedBars
        forgedBars[activeIndex] = replacingTexture(
            in: activeBar,
            with: PercussionEchoTextureArticulation(
                inputStep: articulation.inputStep + 1,
                outputStartStep: articulation.outputStartStep + 1,
                outputEndStep: articulation.outputEndStep + 1
            )
        )
        let forged = AutonomousPhraseCandidates(
            primary: replacingBars(
                in: fixture.candidates.primary,
                with: forgedBars
            ),
            alternate: fixture.candidates.alternate,
            fallback: fixture.candidates.fallback
        )
        var renderState = RenderState()
        renderState.barIndex = fixture.state.memory.totalBars
        let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: forged,
            sessionSeed: fixture.state.rootSeed,
            memory: fixture.state.memory,
            sampleRate: 8_000,
            incomingRenderState: renderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: fixture.state.quality,
            cancellationRequested: { false }
        )
        _ = renderState
        #expect(prepared == nil)
    }

    @Test("Prepared transaction retains the exact score to protected-return consequence")
    func preparedProductEvidence() throws {
        let fixture = try #require(activePrimaryFixture())
        let prepared = try #require(prepare(
            fixture.candidates,
            state: fixture.state
        ))

        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.candidateEvaluation.selectedSlot == .primary)
        #expect(prepared.selectedCandidateEvidence.slot == .primary)
        #expect(prepared.selectedCandidateEvidence.isComplete)
        #expect(!prepared.usedAlternate)
        #expect(!prepared.usedFallback)
        #expect(prepared.commitEligible)

        let evidence = prepared.selectedCandidateEvidence
        let selected = fixture.candidates.primary
        #expect(evidence.percussionEchoTexture.count == selected.resolvedBars.count)
        #expect(evidence.percussionEchoTexture.map(\.bar) ==
                selected.resolvedBars.map { $0.performance.bar })
        #expect(evidence.percussionEchoTexture.allSatisfy {
            $0.renderPassesMatch && $0.bindingValid && $0.finite
        })
        let active = evidence.percussionEchoTexture.filter(\.active)
        #expect(!active.isEmpty)
        #expect(active.allSatisfy {
            $0.inputPeak > 0 && $0.inputRMS > 0 &&
                $0.returnPeak > 0 && $0.returnRMS > 0 &&
                $0.inputNonzeroSampleCount > 0 &&
                $0.returnNonzeroSampleCount > 0 &&
                $0.outOfWindowNonzeroSampleCount == 0 &&
                $0.firstOutputSampleBitPattern & 0x7fff_ffff == 0 &&
                $0.lastOutputSampleBitPattern & 0x7fff_ffff == 0
        })
        #expect(prepared.blocks.contains { block in
            block.effects.contains {
                $0.kind == .gatedPercussionEcho && $0.active
            }
        })
    }

    private func activePrimaryFixture() -> (
        state: AutonomousSessionState,
        candidates: AutonomousPhraseCandidates
    )? {
        for seed in UInt64(1)...64 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<80 {
                let candidates = director.candidates(from: state)
                if candidates.primary.resolvedBars.contains(where: {
                    $0.percussionEchoTexture != nil
                }) {
                    return (state, candidates)
                }
                state.advance(using: candidates.primary)
            }
        }
        return nil
    }

    private func prepare(
        _ candidates: AutonomousPhraseCandidates,
        state: AutonomousSessionState
    ) -> PreparedAutonomousPhrase? {
        var renderState = RenderState()
        renderState.barIndex = state.memory.totalBars
        return AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: renderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            cancellationRequested: { false }
        )
    }

    private func replacingTexture(
        in source: ResolvedPerformanceBar,
        with articulation: PercussionEchoTextureArticulation?
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations: source.closedHatDecayArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: source.kickSyntaxRole,
            percussionEchoTexture: articulation
        )
    }

    private func replacingBars(
        in source: AutonomousPhrasePlan,
        with bars: [ResolvedPerformanceBar]
    ) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
            phraseIndex: source.phraseIndex,
            startBar: source.startBar,
            barCount: source.barCount,
            kind: source.kind,
            scene: source.scene,
            dna: source.dna,
            resolvedBars: bars,
            openedDebt: source.openedDebt,
            paidDebtIDs: source.paidDebtIDs,
            requestsTopologyMutation: source.requestsTopologyMutation,
            alternate: source.alternate,
            conservative: source.conservative,
            interest: source.interest,
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
        )
    }
}
