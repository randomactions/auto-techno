import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing

@Suite("Upper timbre and primary quality integration", .serialized)
struct UpperTimbreIntegrationTests {
    @Test("Score-owned timbre changes only the declared upper path")
    func localizedVerticalSlicePCM() {
        guard let fixture = eligibleSingleBarFixture() else {
            Issue.record("Expected a deterministic two-note motif fixture")
            return
        }
        let home = renderSingleBar(
            plan: fixture.plan,
            resolved: replacingChapter(in: fixture.resolved, with: .home),
            state: fixture.state
        )
        let resonant = renderSingleBar(
            plan: fixture.plan,
            resolved: replacingChapter(in: fixture.resolved, with: .motion),
            state: fixture.state
        )
        let detuned = renderSingleBar(
            plan: fixture.plan,
            resolved: replacingChapter(in: fixture.resolved, with: .tone),
            state: fixture.state
        )

        let homeEventPositions = home.events.map { "\($0.voice.rawValue):\($0.step)" }
        #expect(homeEventPositions == resonant.events.map {
            "\($0.voice.rawValue):\($0.step)"
        })
        #expect(homeEventPositions == detuned.events.map {
            "\($0.voice.rawValue):\($0.step)"
        })
        #expect(home.protectedFoundationSampleHash == resonant.protectedFoundationSampleHash)
        #expect(home.protectedFoundationSampleHash == detuned.protectedFoundationSampleHash)
        #expect(home.percussionSampleHash == resonant.percussionSampleHash)
        #expect(home.percussionSampleHash == detuned.percussionSampleHash)
        #expect(home.protectedRhythmSampleHash == resonant.protectedRhythmSampleHash)
        #expect(home.protectedRhythmSampleHash == detuned.protectedRhythmSampleHash)
        #expect(home.resolvedUpperNotes.count == resonant.resolvedUpperNotes.count)
        #expect(home.resolvedUpperNotes.count == detuned.resolvedUpperNotes.count)
        #expect(home.resolvedUpperNotes.map(\.onsetStep) ==
                resonant.resolvedUpperNotes.map(\.onsetStep))
        #expect(home.resolvedUpperNotes.map(\.onsetStep) ==
                detuned.resolvedUpperNotes.map(\.onsetStep))
        let invariantProjection: (ResolvedUpperNote) -> String = {
            "\($0.role.rawValue):\($0.onsetStep):\($0.endFrequencyRatio):\($0.velocity)"
        }
        #expect(home.resolvedUpperNotes.map(invariantProjection) ==
                resonant.resolvedUpperNotes.map(invariantProjection))
        #expect(home.resolvedUpperNotes.map(invariantProjection) ==
                detuned.resolvedUpperNotes.map(invariantProjection))
        #expect(home.resolvedUpperNotes.allSatisfy { $0.timbreIntent == .home })
        #expect(resonant.resolvedUpperNotes.filter { $0.gate == .slide }.count == 1)
        #expect(resonant.resolvedUpperNotes.filter {
            $0.timbreIntent.kind == .resonantSequence
        }.allSatisfy { $0.role == .anchor })
        let moving = detuned.resolvedUpperNotes.filter {
            $0.timbreIntent.kind == .detunedMotion
        }
        #expect(!moving.isEmpty)
        #expect(moving.allSatisfy { $0.role == .shadow || $0.role == .response })
        #expect(home.left != resonant.left)
        #expect(home.left != detuned.left)
        #expect(home.graphInputRemainderTimbreEvidence.fingerprint !=
                resonant.graphInputRemainderTimbreEvidence.fingerprint)
        #expect(home.graphInputRemainderTimbreEvidence.fingerprint !=
                detuned.graphInputRemainderTimbreEvidence.fingerprint)
        assertRenderedTrajectoriesMatchScore(home)
        assertRenderedTrajectoriesMatchScore(resonant)
        assertRenderedTrajectoriesMatchScore(detuned)
        #expect(resonant.upperNoteRenderEvidence.filter {
            $0.requestedGate == .slide
        }.allSatisfy { $0.appliedGate == .slide && !$0.didRetrigger })
        let appliedAnchorRetriggers = resonant.upperNoteRenderEvidence.filter {
            $0.role == .anchor && $0.didRetrigger
        }.count
        #expect(
            resonant.graphInputRemainderTimbreEvidence.accentedOnsetCount +
                resonant.graphInputRemainderTimbreEvidence.unaccentedOnsetCount ==
                appliedAnchorRetriggers
        )
        for block in [home, resonant, detuned] {
            let anchorRetriggers = block.upperNoteRenderEvidence.filter {
                $0.role == .anchor && $0.didRetrigger
            }
            #expect(block.graphInputRemainderTimbreEvidence.velocityExpression.count ==
                    anchorRetriggers.count)
            #expect(block.postGraphRemainderTimbreEvidence.velocityExpression ==
                    block.graphInputRemainderTimbreEvidence.velocityExpression)
            #expect(zip(
                block.graphInputRemainderTimbreEvidence.velocityExpression,
                anchorRetriggers
            ).allSatisfy { expression, applied in
                expression.onsetFrame == applied.onsetFrame &&
                    expression.velocity == applied.appliedVelocity &&
                    expression.spectralEnvelopeScale ==
                        applied.velocitySpectralEnvelopeScale &&
                    expression.decayScale == applied.velocityDecayScale
            })
        }
    }

    @Test("Breath timing cascade reaches exact upper frames and compact role evidence")
    func upperTimingCascadeVerticalSlice() throws {
        let fixture = try #require(eligibleSingleBarFixture())
        let breath = replacingChapter(in: fixture.resolved, with: .breath)
        let alignedResolved = replacingAbsoluteBar(in: breath, with: 0)
        let spreadResolved = replacingAbsoluteBar(in: breath, with: 7)
        let aligned = renderSingleBar(
            plan: fixture.plan,
            resolved: alignedResolved,
            state: fixture.state
        )
        let spread = renderSingleBar(
            plan: fixture.plan,
            resolved: spreadResolved,
            state: fixture.state
        )

        #expect(!aligned.upperTimingRenderEvidence.events.isEmpty)
        #expect(aligned.upperTimingRenderEvidence.events.count ==
                aligned.upperNoteRenderEvidence.count)
        #expect(aligned.upperTimingRenderEvidence.events.allSatisfy {
            $0.requestedOffsetInSteps.bitPattern == 0
        })
        let alignedStepFrames = Double(aligned.left.count) / 16
        for event in aligned.upperTimingRenderEvidence.events {
            let legacyFrame = Int(
                (Double(event.baseOnsetStep) * alignedStepFrames).rounded()
            )
            #expect(event.expectedOnsetFrame == legacyFrame)
            #expect(event.appliedOnsetFrame == legacyFrame)
        }

        let spreadEvents = spread.upperTimingRenderEvidence.events
        let shifted = spreadEvents.filter { $0.requestedOffsetInSteps > 0 }
        #expect(!shifted.isEmpty)
        #expect(shifted.allSatisfy {
            $0.role == .shadow || $0.role == .response
        })
        #expect(spreadEvents.filter { $0.role == .anchor }.allSatisfy {
            $0.requestedOffsetInSteps.bitPattern == 0
        })
        #expect(spreadEvents.map(\.requestedOffsetInSteps).max() ?? 0 <=
                ResolvedUpperNote.maximumTimingOffsetInSteps)
        #expect((spreadEvents.map(\.requestedOffsetInSteps).max() ?? 0) -
                (spreadEvents.map(\.requestedOffsetInSteps).min() ?? 0) > 0)
        for event in spreadEvents {
            let actual = spread.upperNoteRenderEvidence.filter {
                $0.role == event.role &&
                    $0.onsetFrame == event.appliedOnsetFrame &&
                    $0.requestedGateEndFrame == event.requestedGateEndFrame &&
                    $0.appliedGateEndFrame == event.appliedGateEndFrame
            }
            #expect(actual.count == 1)
            #expect(event.expectedOnsetFrame == event.appliedOnsetFrame)
            #expect(event.appliedGateEndFrame >= event.appliedOnsetFrame)
            #expect(event.appliedGateEndFrame <= min(
                event.requestedGateEndFrame,
                spread.left.count
            ))
        }
        let shadowCount = spreadEvents.filter { $0.role == .shadow }.count
        let responseCount = spreadEvents.filter { $0.role == .response }.count
        #expect(spread.upperTimingRenderEvidence.shadowSignal.eventCount == shadowCount)
        #expect(spread.upperTimingRenderEvidence.responseSignal.eventCount == responseCount)
        #expect(spread.upperTimingRenderEvidence.shadowSignal.finite)
        #expect(spread.upperTimingRenderEvidence.responseSignal.finite)
        #expect(shadowCount == 0 ||
                (spread.upperTimingRenderEvidence.shadowSignal.peak > 0 &&
                    spread.upperTimingRenderEvidence.shadowSignal.rms > 0))
        #expect(responseCount == 0 ||
                (spread.upperTimingRenderEvidence.responseSignal.peak > 0 &&
                    spread.upperTimingRenderEvidence.responseSignal.rms > 0))
        #expect(aligned.protectedFoundationSampleHash ==
                spread.protectedFoundationSampleHash)
        #expect(aligned.percussionSampleHash == spread.percussionSampleHash)
        #expect(aligned.protectedRhythmSampleHash ==
                spread.protectedRhythmSampleHash)
        #expect(aligned.left != spread.left)
    }

    @Test("Score velocity reaches the anchor while protected rhythm stays exact")
    func scoreVelocityVerticalSlice() throws {
        guard let fixture = velocityIsolatedFixture() else {
            Issue.record("Expected a motif step isolated from protected rhythm")
            return
        }
        let home = replacingChapter(in: fixture.resolved, with: .home)
        let low = renderSingleBar(
            plan: fixture.plan,
            resolved: replacingAccent(in: home, step: fixture.step, value: 0),
            state: fixture.state
        )
        let high = renderSingleBar(
            plan: fixture.plan,
            resolved: replacingAccent(in: home, step: fixture.step, value: 1),
            state: fixture.state
        )
        let stepFrames = Double(low.left.count) / 16
        let onsetFrame = Int((Double(fixture.step) * stepFrames).rounded())
        let lowScore = try #require(low.resolvedUpperNotes.first {
            $0.role == .anchor && $0.onsetStep == fixture.step
        })
        let highScore = try #require(high.resolvedUpperNotes.first {
            $0.role == .anchor && $0.onsetStep == fixture.step
        })
        let lowApplied = try #require(low.upperNoteRenderEvidence.first {
            $0.role == .anchor && $0.onsetFrame == onsetFrame
        })
        let highApplied = try #require(high.upperNoteRenderEvidence.first {
            $0.role == .anchor && $0.onsetFrame == onsetFrame
        })

        #expect(low.resolvedUpperNotes.count == high.resolvedUpperNotes.count)
        #expect(zip(low.resolvedUpperNotes, high.resolvedUpperNotes).allSatisfy {
            lhs, rhs in
            lhs.role == rhs.role && lhs.onsetStep == rhs.onsetStep &&
                lhs.durationInSteps == rhs.durationInSteps &&
                lhs.startFrequencyRatio == rhs.startFrequencyRatio &&
                lhs.endFrequencyRatio == rhs.endFrequencyRatio &&
                lhs.gate == rhs.gate && lhs.timbreIntent == rhs.timbreIntent
        })
        #expect(highScore.velocity > lowScore.velocity)
        #expect(lowApplied.requestedVelocity == lowScore.velocity)
        #expect(lowApplied.appliedVelocity == lowScore.velocity)
        #expect(highApplied.requestedVelocity == highScore.velocity)
        #expect(highApplied.appliedVelocity == highScore.velocity)
        #expect(highApplied.velocitySpectralEnvelopeScale >
                lowApplied.velocitySpectralEnvelopeScale)
        #expect(highApplied.velocityDecayScale > lowApplied.velocityDecayScale)
        #expect(low.left[..<onsetFrame] == high.left[..<onsetFrame])
        #expect(low.left[onsetFrame...] != high.left[onsetFrame...])
        #expect(low.protectedFoundationSampleHash == high.protectedFoundationSampleHash)
        #expect(low.percussionSampleHash == high.percussionSampleHash)
        #expect(low.protectedRhythmSampleHash == high.protectedRhythmSampleHash)
        #expect(low.graphInputRemainderTimbreEvidence.fingerprint !=
                high.graphInputRemainderTimbreEvidence.fingerprint)
        assertRenderedTrajectoriesMatchScore(low)
        assertRenderedTrajectoriesMatchScore(high)
    }



    @Test("The calibrated primary evaluator atomically commits one plan")
    func calibratedPrimaryCommit() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let plan = director.plan(from: state)
        let evaluator = ProfessionalQualityPreparationEvaluator(
            sampleRate: 48_000,
            artifacts: artifacts
        )
        let prepared = AutonomousPhrasePreparer.prepare(
            plan: plan,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 48_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: evaluator
        )

        #expect(evaluator.availability == .available)
        #expect(prepared.plan == plan)
        #expect(prepared.candidateEvaluation.planFingerprint ==
                AutonomousCandidateFingerprint.plan(plan))
        #expect((1...QualityQualificationContract.maximumRenderPasses)
            .contains(prepared.candidateEvaluation.attempts.count))
        #expect(prepared.candidateEvaluation.selectedAttemptIndex ==
                prepared.candidateEvaluation.attempts.indices.last)
        #expect(prepared.candidateEvaluation.correctionCount ==
                prepared.correctionRenderCount)
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.qualityDecision.outcome == .qualified ||
                prepared.qualityDecision.outcome == .adjusted)
        #expect(prepared.commitEligible)
    }

    @Test("Unavailable routes retain evidence but cannot cross the commit gate")
    func unavailableRouteDoesNotCommit() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let plan = director.plan(from: state)
        let evaluator = ProfessionalQualityPreparationEvaluator(
            sampleRate: 8_000,
            artifacts: artifacts
        )
        let prepared = AutonomousPhrasePreparer.prepare(
            plan: plan,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: evaluator
        )

        #expect(evaluator.availability == .unsupportedSampleRate)
        #expect(prepared.candidateEvaluation.attempts.count == 1)
        #expect(prepared.candidateEvaluation.correctionCount == 0)
        #expect(prepared.qualityDecision.outcome == .qualificationUnavailable)
        #expect(prepared.qualityDecision.reasonCodes.contains(.evaluatorUnavailableV1))
        #expect(!prepared.commitEligible)
    }

    @Test("One bounded correction rerenders the same primary plan")
    func onePrimaryCorrection() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let plan = director.plan(from: state)
        let prepared = AutonomousPhrasePreparer.prepare(
            plan: plan,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: CorrectingPrimaryTestEvaluator()
        )

        #expect(prepared.plan == plan)
        #expect(prepared.candidateEvaluation.attempts.count == 2)
        #expect(prepared.candidateEvaluation.attempts[0].kind == .initialRender)
        #expect(!prepared.candidateEvaluation.attempts[0].forceHomeUpperTimbre)
        #expect(prepared.candidateEvaluation.attempts[1].kind == .correctionRender)
        #expect(prepared.candidateEvaluation.attempts[1].forceHomeUpperTimbre)
        #expect(prepared.candidateEvaluation.correctionCount == 1)
        #expect(prepared.usedHomeTimbreCorrection)
        #expect(prepared.qualityDecision.outcome == .adjusted)
        #expect(prepared.commitEligible)
    }
    private func eligibleSingleBarFixture() ->
        (state: AutonomousSessionState, plan: AutonomousPhrasePlan,
         resolved: ResolvedPerformanceBar)? {
        for seed in UInt64(1)...128 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let plan = director.plan(from: state)
            for resolved in plan.resolvedBars {
                let motion = SynthPerformancePlan(
                    scene: plan.scene,
                    dna: plan.dna,
                    kind: .contrast,
                    resolvedBars: [replacingChapter(in: resolved, with: .motion)]
                ).bars[0]
                let tone = SynthPerformancePlan(
                    scene: plan.scene,
                    dna: plan.dna,
                    kind: .contrast,
                    resolvedBars: [replacingChapter(in: resolved, with: .tone)]
                ).bars[0]
                if motion.upperNotes.filter({ $0.gate == .slide }).count == 1,
                   tone.upperNotes.contains(where: {
                       $0.timbreIntent.kind == .detunedMotion
                   }) {
                    return (state, plan, resolved)
                }
            }
        }
        return nil
    }

    private func velocityIsolatedFixture() ->
        (state: AutonomousSessionState, plan: AutonomousPhrasePlan,
         resolved: ResolvedPerformanceBar, step: Int)? {
        for seed in UInt64(1)...256 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let plan = director.plan(from: state)
            for resolved in plan.resolvedBars {
                let motifSteps = resolved.ensemble.events.filter {
                    $0.voice == .motif
                }.map(\.step)
                if let step = motifSteps.first(where: { candidate in
                    !resolved.ensemble.events.contains { event in
                        event.step == candidate &&
                            (event.voice.role == .foundation ||
                                event.voice.role == .percussion)
                    }
                }) {
                    return (state, plan, resolved, step)
                }
            }
        }
        return nil
    }

    private func replacingChapter(in resolved: ResolvedPerformanceBar,
                                  with chapter: InterlockChapter) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: resolved.ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: chapter,
            groovePulses: resolved.groovePulses,
            closedHatDecayArticulations: resolved.closedHatDecayArticulations,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
    }

    private func replacingAbsoluteBar(
        in resolved: ResolvedPerformanceBar,
        with absoluteBar: Int
    ) -> ResolvedPerformanceBar {
        let source = resolved.performance
        let performance = PerformanceBar(
            bar: absoluteBar,
            phrase: source.phrase,
            localBar: source.localBar,
            phraseLength: source.phraseLength,
            section: source.section,
            tension: source.tension,
            roles: source.roles,
            transformations: source.transformations,
            signatureEvent: source.signatureEvent,
            eventSeed: source.eventSeed,
            accentContour: source.accentContour
        )
        return ResolvedPerformanceBar(
            performance: performance,
            ensemble: resolved.ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            closedHatDecayArticulations: resolved.closedHatDecayArticulations,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
    }

    private func replacingAccent(in resolved: ResolvedPerformanceBar,
                                 step: Int, value: Double) -> ResolvedPerformanceBar {
        let source = resolved.performance
        var contour = source.accentContour
        contour[((step % contour.count) + contour.count) % contour.count] = value
        let performance = PerformanceBar(
            bar: source.bar,
            phrase: source.phrase,
            localBar: source.localBar,
            phraseLength: source.phraseLength,
            section: source.section,
            tension: source.tension,
            roles: source.roles,
            transformations: source.transformations,
            signatureEvent: source.signatureEvent,
            eventSeed: source.eventSeed,
            accentContour: contour
        )
        return ResolvedPerformanceBar(
            performance: performance,
            ensemble: resolved.ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            closedHatDecayArticulations: resolved.closedHatDecayArticulations,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
    }

    private func renderSingleBar(plan source: AutonomousPhrasePlan,
                                 resolved: ResolvedPerformanceBar,
                                 state: AutonomousSessionState,
                                 incomingRenderState: RenderState = RenderState()) -> RenderBlock {
        let plan = AutonomousPhrasePlan(
            phraseIndex: source.phraseIndex,
            startBar: resolved.performance.bar,
            barCount: 1,
            kind: .contrast,
            scene: source.scene,
            dna: source.dna,
            resolvedBars: [resolved],
            openedDebt: source.openedDebt,
            paidDebtIDs: source.paidDebtIDs,
            requestsTopologyMutation: false,
            interest: PhraseInterestEvaluator.evaluate(
                resolvedBars: [resolved],
                kind: .contrast,
                memory: state.memory,
                identityPreserved: true
            ),
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
        )
        var renderState = incomingRenderState
        var graphState = GeneratedDSPContinuationState()
        return AutonomousPhraseRenderer.render(
            plan: plan,
            graph: DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed),
            sampleRate: 8_000,
            state: &renderState,
            graphState: &graphState
        )[0]
    }

    private func assertRenderedTrajectoriesMatchScore(_ block: RenderBlock) {
        let stepFrames = Double(block.left.count) / 16
        #expect(block.upperNoteRenderEvidence.count == block.resolvedUpperNotes.count)
        for trajectory in block.upperNoteRenderEvidence {
            let candidates = block.resolvedUpperNotes.filter { note in
                note.role == trajectory.role &&
                    VoiceRenderer.upperNoteStartFrame(
                        note: note,
                        stepFrames: stepFrames,
                        frameCount: block.left.count
                    ) == trajectory.onsetFrame
            }
            #expect(candidates.count == 1)
            guard let note = candidates.first else { continue }
            let requestedEnd = trajectory.onsetFrame +
                VoiceRenderer.upperNoteDurationFrames(
                    note: note,
                    stepFrames: stepFrames
            )
            #expect(trajectory.requestedGateEndFrame == requestedEnd)
            #expect(trajectory.requestedGate == note.gate)
            #expect(trajectory.timbreIntent == note.timbreIntent)
            #expect(trajectory.requestedVelocity == note.velocity)
            #expect(trajectory.appliedVelocity == note.velocity)
            #expect(abs(trajectory.requestedStartFrequency -
                        block.synthWorld.rootFrequency * note.startFrequencyRatio) <
                    0.000_001)
            #expect(abs(trajectory.targetEndFrequency -
                        block.synthWorld.rootFrequency * note.endFrequencyRatio) <
                    0.000_001)
            #expect(trajectory.appliedStartFrequency.isFinite)
            #expect(trajectory.frequencyAtAppliedGateEnd.isFinite)
            #expect(trajectory.appliedStartFrequency > 0)
            #expect(trajectory.frequencyAtAppliedGateEnd > 0)
            #expect(trajectory.appliedGateEndFrame >= trajectory.onsetFrame)
            #expect(trajectory.appliedGateEndFrame <= block.left.count)
        }
    }
}
