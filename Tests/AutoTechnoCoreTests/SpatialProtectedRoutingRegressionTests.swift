import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Spatial carrier and protected routing regressions")
struct SpatialProtectedRoutingRegressionTests {
    @Test("Terminal trim preserves protected-routing evidence before scaling")
    func protectedRoutingRemainsPreTrimEquivalent() throws {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let source = director.plan(from: director.initialState())
        let plan = replacing(
            source,
            resolvedBars: Array(source.resolvedBars.prefix(1))
        )
        let graph = DSPGraphGenerator.safePlan(sessionSeed: plan.dna.sceneSeed)
        var homeState = RenderState()
        var trimState = RenderState()
        trimState.liveMasterHeadroomState = LiveMasterHeadroomContinuationState(
            revision: 3,
            committedTrimDB: -1,
            consecutiveCleanWindows: 0,
            lastProposalFingerprint: "proposal-3",
            lastObservationFingerprint: "observation-3",
            lastAcceptedSourcePhraseIndex: 2,
            earliestEligibleFutureSample: 32_000
        )
        var homeGraphState = GeneratedDSPContinuationState()
        var trimGraphState = GeneratedDSPContinuationState()
        let home = try #require(AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &homeState,
            graphState: &homeGraphState
        ).first)
        let trimmed = try #require(AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &trimState,
            graphState: &trimGraphState
        ).first)

        #expect(home.protectedFoundationSampleHash ==
                trimmed.protectedFoundationSampleHash)
        #expect(home.protectedRhythmSampleHash ==
                trimmed.protectedRhythmSampleHash)
        #expect(home.kickMix == trimmed.kickMix)
        #expect(home.spatialFDNRenderEvidence == trimmed.spatialFDNRenderEvidence)
        #expect(home.graphInputRemainderTimbreEvidence ==
                trimmed.graphInputRemainderTimbreEvidence)
        #expect(home.postGraphRemainderTimbreEvidence ==
                trimmed.postGraphRemainderTimbreEvidence)
        #expect(trimmed.liveMasterTrimRenderEvidence.preTrimStereoSampleHash ==
                ExactPCMFingerprint.stereo(left: home.left, right: home.right))
        #expect(trimmed.liveMasterTrimRenderEvidence.exactScaleMatches)
    }

    @Test("The tuned tom uses only its resolved modal articulation")
    func tunedTomUsesOnlyTheResolvedModalArticulation() throws {
        let fixture = try #require(modalFoundationFixture())
        let source = fixture.resolved
        let canonical = renderBar(
            plan: fixture.plan,
            resolved: source,
            sampleRate: 8_000
        )
        let sourceArticulation = try #require(
            source.modalPercussionArticulations.first
        )
        let changedArticulation = ModalPercussionArticulation(
            scoreEventIndex: sourceArticulation.scoreEventIndex,
            step: sourceArticulation.step,
            use: sourceArticulation.use,
            modalIdentity: sourceArticulation.modalIdentity,
            modalDegree: sourceArticulation.modalDegree,
            octave: sourceArticulation.octave,
            fundamentalHz: min(196, sourceArticulation.fundamentalHz * 1.08),
            excitation: sourceArticulation.excitation,
            damping: sourceArticulation.damping,
            brightness: sourceArticulation.brightness,
            inharmonicity: sourceArticulation.inharmonicity,
            eventIntensity: sourceArticulation.eventIntensity,
            seed: sourceArticulation.seed
        )
        let changedArticulations = source.modalPercussionArticulations.map {
            $0.scoreEventIndex == sourceArticulation.scoreEventIndex
                ? changedArticulation : $0
        }
        let changed = renderBar(
            plan: fixture.plan,
            resolved: replacing(
                source,
                modalPercussionArticulations: changedArticulations
            ),
            sampleRate: 8_000
        )
        let unbound = renderBar(
            plan: fixture.plan,
            resolved: replacing(source, modalPercussionArticulations: []),
            sampleRate: 8_000
        )

        #expect(canonical.modalPercussionRenderEvidence.events.map(\.articulation) ==
                source.modalPercussionArticulations)
        #expect(changed.modalPercussionRenderEvidence.events.map(\.articulation) ==
                changedArticulations)
        #expect(canonical.modalPercussionRenderEvidence.dryBarSampleHash !=
                changed.modalPercussionRenderEvidence.dryBarSampleHash)
        #expect(unbound.modalPercussionRenderEvidence.events.isEmpty)
        #expect(unbound.modalPercussionRenderEvidence.dryBarRMS == 0)
    }

    @Test("Modal foundation evidence is bit-exact across full and protected passes")
    func modalFoundationFullAndProtectedPassesAreBitExact() throws {
        let fixture = try #require(modalFoundationFixture())
        let full = renderBar(
            plan: fixture.plan,
            resolved: fixture.resolved,
            sampleRate: 8_000,
            layer: .full
        )
        let protected = renderBar(
            plan: fixture.plan,
            resolved: fixture.resolved,
            sampleRate: 8_000,
            layer: .protectedRhythm
        )

        #expect(full.modalPercussionRenderEvidence ==
                protected.modalPercussionRenderEvidence)
        #expect(full.dryModalPercussionSampleHash ==
                protected.dryModalPercussionSampleHash)
        #expect(full.modalPercussionFoundationRoutingValid)
        #expect(protected.modalPercussionFoundationRoutingValid)
    }

    @Test("Modal foundation routes only to foundation")
    func modalFoundationRoutesToFoundationAndNotPercussionOrUpper() throws {
        let fixture = try #require(modalFoundationFixture())
        let inactiveResolved = replacing(
            fixture.resolved,
            modalPercussionArticulations: []
        )
        let active = renderBar(
            plan: fixture.plan,
            resolved: fixture.resolved,
            sampleRate: 8_000
        )
        let inactive = renderBar(
            plan: fixture.plan,
            resolved: inactiveResolved,
            sampleRate: 8_000
        )
        let activeFull = renderBar(
            plan: fixture.plan,
            resolved: fixture.resolved,
            sampleRate: 8_000,
            includeUpperNotes: true
        )
        let activeProtected = renderBar(
            plan: fixture.plan,
            resolved: fixture.resolved,
            sampleRate: 8_000,
            layer: .protectedRhythm,
            includeUpperNotes: true
        )
        let inactiveFull = renderBar(
            plan: fixture.plan,
            resolved: inactiveResolved,
            sampleRate: 8_000,
            includeUpperNotes: true
        )
        let inactiveProtected = renderBar(
            plan: fixture.plan,
            resolved: inactiveResolved,
            sampleRate: 8_000,
            layer: .protectedRhythm,
            includeUpperNotes: true
        )

        #expect(active.modalPercussionFoundationRoutingValid)
        #expect(active.dryModalPercussionSampleHash ==
                active.modalPercussionRenderEvidence.dryBarSampleHash)
        #expect(active.dryModalPercussionSampleHash !=
                inactive.dryModalPercussionSampleHash)
        #expect(active.dryFoundationSampleHash != inactive.dryFoundationSampleHash)
        #expect(active.dryPercussionSampleHash == inactive.dryPercussionSampleHash)
        #expect(active.upperNoteRenderEvidence == inactive.upperNoteRenderEvidence)
        #expect(active.upperTimingRenderEvidence == inactive.upperTimingRenderEvidence)
        #expect(graphRemainderHash(full: activeFull, protected: activeProtected) ==
                graphRemainderHash(
                    full: inactiveFull,
                    protected: inactiveProtected
                ))
    }

    @Test("Modal foundation leaves the kick detector unchanged")
    func modalFoundationLeavesKickDetectorUnchanged() throws {
        let fixture = try #require(modalFoundationFixture())
        let active = renderBar(
            plan: fixture.plan,
            resolved: fixture.resolved,
            sampleRate: 8_000
        )
        let inactive = renderBar(
            plan: fixture.plan,
            resolved: replacing(
                fixture.resolved,
                modalPercussionArticulations: []
            ),
            sampleRate: 8_000
        )

        #expect(fixture.resolved.ensemble.events.contains { $0.voice == .kick })
        #expect(active.kickMix == inactive.kickMix)
        #expect(active.dryPercussionSampleHash == inactive.dryPercussionSampleHash)
        #expect(active.dryFoundationSampleHash != inactive.dryFoundationSampleHash)
    }

    @Test("Upper home correction leaves modal score and dry PCM unchanged")
    func upperHomeCorrectionLeavesModalScoreAndDryPCMUnchanged() throws {
        let fixture = try #require(modalFoundationFixture())
        let plan = replacing(fixture.plan, resolvedBars: [fixture.resolved])
        let graph = DSPGraphGenerator.safePlan(sessionSeed: plan.dna.sceneSeed)
        var initialState = RenderState()
        var correctionState = RenderState()
        var initialGraphState = GeneratedDSPContinuationState()
        var correctionGraphState = GeneratedDSPContinuationState()
        let initial = try #require(AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &initialState,
            graphState: &initialGraphState,
            forceHomeUpperTimbre: false
        ).first)
        let correction = try #require(AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &correctionState,
            graphState: &correctionGraphState,
            forceHomeUpperTimbre: true
        ).first)

        #expect(initial.resolvedPerformance.modalPercussionArticulations ==
                correction.resolvedPerformance.modalPercussionArticulations)
        #expect(initial.modalPercussionRenderEvidence ==
                correction.modalPercussionRenderEvidence)
        #expect(initial.modalPercussionRenderPassesMatch)
        #expect(correction.modalPercussionRenderPassesMatch)
        #expect(initial.protectedFoundationSampleHash ==
                correction.protectedFoundationSampleHash)
    }

    @Test("A bar without an onset carries truthful continuation or neutral evidence")
    func barWithoutOnsetCarriesTruthfulContinuationOrNeutralEvidence() throws {
        let fixture = try #require(modalFoundationFixture())
        let source = fixture.resolved
        let noOnset = replacing(source, modalPercussionArticulations: [])
        let synthPlan = SynthPerformancePlan(
            scene: fixture.plan.scene,
            dna: fixture.plan.dna,
            kind: fixture.plan.kind,
            resolvedBars: [source],
            forceHomeUpperTimbre: true
        )
        let synthBar = synthPlan.bars[0]
        var state = RenderState()
        var workspace = RenderWorkspace()
        let active = VoiceRenderer.renderBar(
            scene: fixture.plan.scene,
            sampleRate: 8_000,
            state: &state,
            dna: fixture.plan.dna,
            resolved: source,
            synthWorld: synthPlan.world,
            synthPerformance: synthBar,
            workspace: &workspace,
            layer: .protectedRhythm
        )
        let successor = VoiceRenderer.renderBar(
            scene: fixture.plan.scene,
            sampleRate: 8_000,
            state: &state,
            dna: fixture.plan.dna,
            resolved: noOnset,
            synthWorld: synthPlan.world,
            synthPerformance: synthBar,
            workspace: &workspace,
            layer: .protectedRhythm
        )
        var neutralState = RenderState()
        let neutral = VoiceRenderer.renderBar(
            scene: fixture.plan.scene,
            sampleRate: 8_000,
            state: &neutralState,
            dna: fixture.plan.dna,
            resolved: noOnset,
            synthWorld: synthPlan.world,
            synthPerformance: synthBar,
            workspace: &workspace,
            layer: .protectedRhythm
        )

        #expect(successor.modalPercussionRenderEvidence.events.isEmpty)
        #expect(successor.modalPercussionRenderEvidence.incomingStateFingerprint ==
                active.modalPercussionRenderEvidence.outgoingStateFingerprint)
        #expect(successor.modalPercussionRenderEvidence.continuationRendered ==
                (successor.modalPercussionRenderEvidence.activeIncomingVoiceCount > 0))
        #expect(neutral.modalPercussionRenderEvidence.events.isEmpty)
        #expect(!neutral.modalPercussionRenderEvidence.continuationRendered)
        #expect(neutral.modalPercussionRenderEvidence.activeIncomingVoiceCount == 0)
        #expect(neutral.modalPercussionRenderEvidence.activeOutgoingVoiceCount == 0)
        #expect(neutral.modalPercussionRenderEvidence.dryBarRMS == 0)
    }

    @Test("Streaming mono fingerprints preserve exact PCM identity")
    func streamingMonoFingerprintMatchesArrayFingerprint() {
        let fixtures: [[Float]] = [
            [],
            [0],
            [-0.0, 0.0, .leastNonzeroMagnitude, -1.25, 3.5],
            [Float(bitPattern: 0x7fc0_1234), .infinity, -.infinity],
        ]

        for samples in fixtures {
            var streaming = ExactPCMFingerprint.MonoAccumulator(
                sampleCount: samples.count
            )
            for sample in samples {
                streaming.append(sample)
            }
            #expect(streaming.fingerprint == ExactPCMFingerprint.mono(samples))
        }
    }

    @Test("Neutral closed hats retain exact PCM and bounded evidence at supported routes")
    func closedHatEvidenceIsExactAcrossSampleRates() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let plan = director.plan(from: director.initialState())
        let source = try #require(plan.resolvedBars.first)
        let event = EnsembleResolvedEvent(
            voice: .percussion,
            step: 6,
            intensity: 0.73,
            relocated: false
        )
        let ensemble = EnsembleContext(
            focusRole: .percussion,
            events: [event],
            kickAnchors: [],
            intentionalPileup: false
        )
        let sampleRates: [Double] = [8_000, 44_100, 48_000, 96_000, 192_000]
        let brightness = plan.scene.character.percussionBrightness
        let accent = source.performance.accent(at: event.step) * event.intensity
        let level = (source.performance.section == .build ? 0.09 : 0.075) * accent

        for sampleRate in sampleRates {
            let neutral = replacing(
                source,
                ensemble: ensemble,
                groovePulses: [],
                closedHatDecayArticulations: [ClosedHatDecayArticulation(
                    scoreEventIndex: 0,
                    step: event.step,
                    role: .neutral
                )]
            )
            let companion = replacing(
                source,
                ensemble: ensemble,
                groovePulses: [],
                closedHatDecayArticulations: [ClosedHatDecayArticulation(
                    scoreEventIndex: 0,
                    step: event.step,
                    role: .openHatCompanion
                )]
            )
            let neutralRendered = renderBar(
                plan: plan,
                resolved: neutral,
                sampleRate: sampleRate
            )
            let companionRendered = renderBar(
                plan: plan,
                resolved: companion,
                sampleRate: sampleRate
            )
            let neutralEvidence = try #require(
                neutralRendered.closedHatRenderEvidence.first
            )
            let companionEvidence = try #require(
                companionRendered.closedHatRenderEvidence.first
            )
            let neutralDecay = 32 - brightness * 8
            let companionDecay = neutralDecay *
                ClosedHatVoiceContract.openHatCompanionDecayRateScale
            let expectedNeutral = legacyClosedHatSamples(
                sampleRate: sampleRate,
                level: level,
                brightness: brightness,
                decayRate: neutralDecay,
                seed: source.performance.eventSeed
            )
            let expectedCompanion = legacyClosedHatSamples(
                sampleRate: sampleRate,
                level: level,
                brightness: brightness,
                decayRate: companionDecay,
                seed: source.performance.eventSeed
            )

            #expect(neutralEvidence.role == .neutral)
            #expect(neutralEvidence.appliedDecayRate == neutralDecay)
            #expect(neutralEvidence.renderedFrameCount ==
                    ClosedHatVoiceContract.frameCount(sampleRate: sampleRate))
            #expect(neutralEvidence.sampleHash ==
                    ExactPCMFingerprint.mono(expectedNeutral))
            #expect(companionEvidence.sampleHash ==
                    ExactPCMFingerprint.mono(expectedCompanion))
            #expect(companionEvidence.renderedFrameCount ==
                    neutralEvidence.renderedFrameCount)
            #expect(companionEvidence.tailToAttackDB < neutralEvidence.tailToAttackDB)
            #expect(companionEvidence.sampleHash != neutralEvidence.sampleHash)
            for evidence in [neutralEvidence, companionEvidence] {
                #expect(ClosedHatVoiceContract.appliedParametersMatch(
                    level: evidence.appliedLevel,
                    decayRate: evidence.appliedDecayRate,
                    brightness: brightness,
                    reportedSection: source.performance.section,
                    scoreSection: source.performance.section,
                    combinedAccent: accent,
                    role: evidence.role
                ))
                #expect(!ClosedHatVoiceContract.appliedParametersMatch(
                    level: evidence.appliedLevel + 0.001,
                    decayRate: evidence.appliedDecayRate,
                    brightness: brightness,
                    reportedSection: source.performance.section,
                    scoreSection: source.performance.section,
                    combinedAccent: accent,
                    role: evidence.role
                ))
                #expect(!ClosedHatVoiceContract.appliedParametersMatch(
                    level: evidence.appliedLevel,
                    decayRate: evidence.appliedDecayRate + 1,
                    brightness: brightness,
                    reportedSection: source.performance.section,
                    scoreSection: source.performance.section,
                    combinedAccent: accent,
                    role: evidence.role
                ))
                #expect(!ClosedHatVoiceContract.appliedParametersMatch(
                    level: evidence.appliedLevel,
                    decayRate: evidence.appliedDecayRate,
                    brightness: brightness,
                    reportedSection: source.performance.section == .build
                        ? .groove : .build,
                    scoreSection: source.performance.section,
                    combinedAccent: accent,
                    role: evidence.role
                ))
                #expect(evidence.finite)
                #expect(evidence.scoreEventIndex == 0)
                #expect(evidence.step == event.step)
                #expect(evidence.eventIntensity == event.intensity)
                #expect(evidence.timingOffsetInSteps == 0)
                #expect(evidence.appliedLevel == level)
                #expect(evidence.sampleHash.count == 16)
                #expect(evidence.spectralCentroidHz.isFinite)
                #expect((0...(sampleRate / 2)).contains(
                    evidence.spectralCentroidHz
                ))
            }
        }
    }

    @Test("Closed-hat companion decay changes only its future dry sample")
    func closedHatCompanionPreservesUnrelatedRoutingAndRandomOrder() throws {
        let director = AutonomousSessionDirector(rootSeed: 90_909)
        let sourcePlan = director.plan(from: director.initialState())
        let source = try #require(sourcePlan.resolvedBars.first)
        let events = [
            EnsembleResolvedEvent(
                voice: .kick, step: 0, intensity: 0.90, relocated: false
            ),
            EnsembleResolvedEvent(
                voice: .clap, step: 2, intensity: 0.64, relocated: false
            ),
            EnsembleResolvedEvent(
                voice: .openHat, step: 4, intensity: 0.61, relocated: false
            ),
            EnsembleResolvedEvent(
                voice: .metallic, step: 6, intensity: 0.57, relocated: false
            ),
            EnsembleResolvedEvent(
                voice: .groovePulse, step: 8, intensity: 0.52, relocated: false
            ),
            EnsembleResolvedEvent(
                voice: .percussion, step: 12, intensity: 0.78, relocated: false
            ),
            EnsembleResolvedEvent(
                voice: .percussion, step: 14, intensity: 0.66, relocated: false
            ),
        ]
        let ensemble = EnsembleContext(
            focusRole: .percussion,
            events: events,
            kickAnchors: [0],
            intentionalPileup: false
        )
        let groovePulses = GroovePulseResolver.articulations(
            from: ensemble,
            absoluteBar: source.performance.bar,
            swingPercent: sourcePlan.dna.rhythm.swingPercent,
            percussionGear: source.percussionGear,
            eventSeed: source.performance.eventSeed
        )
        func resolved(role: ClosedHatDecayRole) -> ResolvedPerformanceBar {
            replacing(
                source,
                ensemble: ensemble,
                groovePulses: groovePulses,
                closedHatDecayArticulations: [
                    ClosedHatDecayArticulation(
                        scoreEventIndex: 5,
                        step: 12,
                        role: role
                    ),
                    ClosedHatDecayArticulation(
                        scoreEventIndex: 6,
                        step: 14,
                        role: .neutral
                    ),
                ]
            )
        }
        func render(_ role: ClosedHatDecayRole) throws -> RenderBlock {
            let plan = replacing(sourcePlan, resolvedBars: [resolved(role: role)])
            let graph = DSPGraphGenerator.safePlan(sessionSeed: plan.dna.sceneSeed)
            var renderState = RenderState()
            var graphState = GeneratedDSPContinuationState()
            return try #require(AutonomousPhraseRenderer.render(
                plan: plan,
                graph: graph,
                sampleRate: 8_000,
                state: &renderState,
                graphState: &graphState
            ).first)
        }

        let neutral = try render(.neutral)
        let companion = try render(.openHatCompanion)
        let neutralChanged = try #require(neutral.closedHatRenderEvidence.first {
            $0.scoreEventIndex == 5
        })
        let companionChanged = try #require(companion.closedHatRenderEvidence.first {
            $0.scoreEventIndex == 5
        })
        let neutralFollower = try #require(neutral.closedHatRenderEvidence.first {
            $0.scoreEventIndex == 6
        })
        let companionFollower = try #require(companion.closedHatRenderEvidence.first {
            $0.scoreEventIndex == 6
        })

        #expect(neutral.events == companion.events)
        #expect(neutralChanged.scoreEventIndex == companionChanged.scoreEventIndex)
        #expect(neutralChanged.step == companionChanged.step)
        #expect(neutralChanged.eventIntensity == companionChanged.eventIntensity)
        #expect(neutralChanged.timingOffsetInSteps ==
                companionChanged.timingOffsetInSteps)
        #expect(neutralChanged.relocated == companionChanged.relocated)
        #expect(neutralChanged.appliedLevel == companionChanged.appliedLevel)
        #expect(neutralChanged.renderedFrameCount ==
                companionChanged.renderedFrameCount)
        #expect(companionChanged.appliedDecayRate > neutralChanged.appliedDecayRate)
        #expect(companionChanged.tailToAttackDB < neutralChanged.tailToAttackDB)
        #expect(companionChanged.sampleHash != neutralChanged.sampleHash)

        // The later neutral hat consumes the next exact RNG segment. Its full
        // evidence identity proves that changing decay did not change draw count.
        #expect(neutralFollower == companionFollower)
        #expect(neutral.groovePulseRenderEvidence ==
                companion.groovePulseRenderEvidence)
        #expect(neutral.protectedFoundationSampleHash ==
                companion.protectedFoundationSampleHash)
        for voice in [EnsembleVoice.clap, .openHat, .metallic, .groovePulse] {
            #expect(neutral.events.contains { $0.voice.rawValue == voice.rawValue })
        }

        // Every unrelated stochastic percussion event precedes the changed
        // closed hat, so causal full-render PCM must be bit-identical up to its
        // score-owned onset. This covers their synthesis and downstream routing.
        let onsetFrame = Int((
            (Double(neutralChanged.step) + neutralChanged.timingOffsetInSteps) *
                Double(neutral.left.count) / 16
        ).rounded())
        #expect(Array(neutral.left[..<onsetFrame]) ==
                Array(companion.left[..<onsetFrame]))
        #expect(Array(neutral.right[..<onsetFrame]) ==
                Array(companion.right[..<onsetFrame]))
    }

    @Test("Groove-pulse evidence is bit-exact across full and protected layers")
    func groovePulseEvidenceMatchesProtectedRoute() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let sourcePlan = director.plan(from: director.initialState())
        let source = try #require(sourcePlan.resolvedBars.first {
            WeakSixteenthStage(absoluteBar: $0.performance.bar) == .syncopatedLean &&
                $0.arrangementGesture != .minimalize &&
                !$0.groovePulses.isEmpty
        })
        let authoredIntensityByStep: [Int: Double] = [
            1: 0.30, 3: 0.72, 5: 0.30, 7: 0.30,
            9: 0.72, 11: 0.30, 13: 0.30, 15: 0.72,
        ]
        #expect(source.groovePulses.allSatisfy {
            authoredIntensityByStep[$0.step] == $0.intensity
        })
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
        let percussionVoices: [EnsembleVoice] = [
            .percussion, .clap, .openHat, .metallic,
        ]
        let upperTailVoices: [EnsembleVoice] = [.clap, .openHat, .metallic]
        let fixtureCandidates: [(AutonomousPhrasePlan, ResolvedPerformanceBar)] =
            (UInt64(1)...128).compactMap { seed in
            let director = AutonomousSessionDirector(rootSeed: seed)
            let plan = director.plan(from: director.initialState())
            guard let resolved = plan.resolvedBars.first(where: { bar in
                bar.ensemble.events.contains {
                    upperTailVoices.contains($0.voice)
                }
            }) else { return nil }
            return (plan, resolved)
        }
        let fixture = try #require(fixtureCandidates.first)
        let sourcePlan = fixture.0
        let source = fixture.1
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
        #expect(!full.0.upperPercussionTailRenderEvidence.isEmpty)
        #expect(full.0.upperPercussionTailRenderEvidence ==
                protected.0.upperPercussionTailRenderEvidence)
        #expect(full.0.upperPercussionTailRenderEvidence.allSatisfy {
            $0.role == .naturalBody &&
                $0.baseSampleHash == $0.renderedSampleHash &&
                $0.differenceRMS == 0
        })
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
        let distantFDN = distantBlock.spatialFDNRenderEvidence
        let foregroundFDN = foregroundBlock.spatialFDNRenderEvidence
        let expectedFDN = FeedbackDelayNetworkConfiguration(
            scene: plan.scene,
            sampleRate: 8_000
        )
        #expect(distantFDN.finite)
        #expect(distantFDN.lineCount ==
                FeedbackDelayNetworkConfiguration.lineCount)
        #expect(distantFDN.delayFrameCounts == expectedFDN.delayFrameCounts)
        #expect(distantFDN.requestedRoomScale == expectedFDN.roomScale)
        #expect(distantFDN.roomScale == expectedFDN.roomScale)
        #expect(distantFDN.maximumFeedbackGain < 1)
        #expect(distantFDN.finalMaximumFeedbackGain ==
                distantFDN.maximumFeedbackGain)
        #expect(distantFDN.finalDampingCoefficient ==
                expectedFDN.dampingCoefficient)
        #expect(distantFDN.finalSynthSendGain == distantFDN.synthSendGain)
        #expect(distantFDN.finalPercussionSendGain ==
                distantFDN.percussionSendGain)
        #expect(distantFDN.finalWetGain == distantFDN.wetGain)
        #expect(distantFDN.spatialDepthPosition == .distant)
        #expect(distantFDN.carrierVoice == .transition)
        #expect(distantFDN.carrierStep == carrierStep)
        #expect(distantFDN.scoreReverbSend == 0.30)
        #expect(distantFDN.spatialSendRMS > 0)
        #expect(distantFDN.inputRMS > 0)
        #expect(distantFDN.wetRMS > 0)
        #expect(distantFDN.wetPeak > distantFDN.wetRMS)
        #expect(distantFDN.activeInputFrameCount > 0)
        #expect(distantFDN.activeWetFrameCount > 0)
        #expect(distantFDN.openingWindowFrameCount == 2_000)
        #expect(distantFDN.terminalWindowFrameCount == 2_000)
        #expect(distantFDN.openingWetRMS >= 0)
        #expect(distantFDN.terminalWetRMS >= 0)
        #expect(distantFDN.inputSampleHash.count == 16)
        #expect(distantFDN.wetLeftSampleHash.count == 16)
        #expect(distantFDN.wetRightSampleHash.count == 16)
        #expect(distantFDN.wetLeftSampleHash != distantFDN.wetRightSampleHash)
        #expect(foregroundFDN.spatialDepthPosition == .foreground)
        #expect(foregroundFDN.carrierVoice == nil)
        #expect(foregroundFDN.scoreReverbSend == 0)
        #expect(foregroundFDN.spatialSendRMS > 0)
        #expect(distantFDN.spatialSendRMS != foregroundFDN.spatialSendRMS)
        #expect(distantFDN.inputSampleHash != foregroundFDN.inputSampleHash)
        #expect(distantBlock.effects.contains {
            $0.kind == .spatialFDN && $0.active
        })
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
        let plan = director.plan(from: director.initialState())
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
                let plan = director.plan(from: state)
                if plan.kind == .majorBreak,
                   let index = plan.resolvedBars.firstIndex(where: {
                       $0.spatialContrast.depthPosition == .distant &&
                           $0.spatialContrast.carrierVoice == .transition
                   }) {
                    return (plan, index)
                }
                state.advancePlanning(using: plan)
            }
        }
        return nil
    }

    private func modalFoundationFixture() -> (
        plan: AutonomousPhrasePlan,
        resolved: ResolvedPerformanceBar
    )? {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for _ in 0..<128 {
            let plan = director.plan(from: state)
            if let resolved = plan.resolvedBars.first(where: {
                !$0.modalPercussionArticulations.isEmpty &&
                    $0.ensemble.events.contains { $0.voice == .kick }
            }) {
                return (plan, resolved)
            }
            state.advancePlanning(using: plan)
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

    private func renderBar(
        plan: AutonomousPhrasePlan,
        resolved: ResolvedPerformanceBar,
        sampleRate: Double,
        layer: RenderLayer = .full,
        includeUpperNotes: Bool = false
    ) -> RenderedBar {
        let synthPlan = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [resolved],
            forceHomeUpperTimbre: true
        )
        let planned = synthPlan.bars[0]
        let noUpperNotes = SynthPerformanceBar(
            bar: planned.bar,
            gesture: planned.gesture,
            mutationAmount: planned.mutationAmount,
            relationalSteps: planned.relationalSteps,
            upperNotes: []
        )
        var state = RenderState()
        var workspace = RenderWorkspace()
        return VoiceRenderer.renderBar(
            scene: plan.scene,
            sampleRate: sampleRate,
            state: &state,
            dna: plan.dna,
            resolved: resolved,
            synthWorld: synthPlan.world,
            synthPerformance: includeUpperNotes ? planned : noUpperNotes,
            workspace: &workspace,
            layer: layer
        )
    }

    private func graphRemainderHash(
        full: RenderedBar,
        protected: RenderedBar
    ) -> String {
        ExactPCMFingerprint.stereo(
            left: zip(
                full.graphRemainderReferenceLeftSamples,
                protected.graphRemainderReferenceLeftSamples
            ).map { $0.0 - $0.1 },
            right: zip(
                full.graphRemainderReferenceRightSamples,
                protected.graphRemainderReferenceRightSamples
            ).map { $0.0 - $0.1 }
        )
    }

    /// Reproduces the pre-source-10 ordinary hat expression exactly. Supplying
    /// the new bounded decay rate makes the same helper an independent oracle
    /// for the companion sample without depending on renderer evidence.
    private func legacyClosedHatSamples(
        sampleRate: Double,
        level: Double,
        brightness: Double,
        decayRate: Double,
        seed: UInt64
    ) -> [Float] {
        let frames = ClosedHatVoiceContract.frameCount(sampleRate: sampleRate)
        var samples = Array(repeating: Float.zero, count: frames)
        var state = 0.0
        var random = SeededGenerator(seed: seed)
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            let noise = random.unit() * 2 - 1
            state += (noise - state) * (0.25 + brightness * 0.25)
            samples[index] = Float(
                (noise - state * 0.7) * exp(-time * decayRate) * level
            )
        }
        return samples
    }

    private func replacing(
        _ resolved: ResolvedPerformanceBar,
        ensemble: EnsembleContext? = nil,
        spatialContrast: SpatialContrastArticulation? = nil,
        interlockChapter: InterlockChapter? = nil,
        groovePulses: [GroovePulseArticulation]? = nil,
        closedHatDecayArticulations: [ClosedHatDecayArticulation]? = nil,
        modalPercussionArticulations: [ModalPercussionArticulation]? = nil
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: ensemble ?? resolved.ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            performanceCharacter: resolved.performanceCharacter,
            foundationBehavior: resolved.foundationBehavior,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: interlockChapter ?? resolved.interlockChapter,
            groovePulses: groovePulses ?? resolved.groovePulses,
            closedHatDecayArticulations: closedHatDecayArticulations ??
                resolved.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                resolved.upperPercussionTailArticulations,
            modalPercussionArticulations: modalPercussionArticulations ??
                resolved.modalPercussionArticulations,
            spatialContrast: spatialContrast ?? resolved.spatialContrast,
            narrative: resolved.narrative,
            kickSyntaxRole: resolved.kickSyntaxRole,
            percussionEchoTexture: resolved.percussionEchoTexture,
            harmonicDisclosureRelationship:
                resolved.harmonicDisclosureRelationship,
            kickMorphology: resolved.kickMorphology
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
            interest: plan.interest,
            endingInterlockState: plan.endingInterlockState,
            endingSpatialContrastState: plan.endingSpatialContrastState,
            endingNarrativeState: plan.endingNarrativeState,
            harmonicContinuation: plan.incomingHarmonicContinuation
        )
    }
}
