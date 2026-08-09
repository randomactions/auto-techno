import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Upper timbre score, PCM evidence, and quality continuation")
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
    }

    @Test("Prepared phrase commits resolved notes, evidence, and quality state together")
    func atomicPreparedContinuation() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let previouslyQualified = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1],
            candidateFingerprint: "previous-candidate",
            evidenceFingerprint: "previous-evidence"
        )
        let incomingQuality = QualityContinuationState().recording(
            decision: previouslyQualified,
            evidenceFingerprint: "previous-evidence",
            controllerStateFingerprint: "previous-controller"
        )
        let prepared = AutonomousPhrasePreparer.prepare(
            candidates: director.candidates(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: incomingQuality,
            routeRecovery: true
        )

        #expect(!prepared.blocks.isEmpty)
        #expect(prepared.blocks.flatMap(\.resolvedUpperNotes).allSatisfy {
            $0.timbreIntent == .home && $0.gate == .retrigger
        })
        for block in prepared.blocks {
            #expect(block.masking.count == 12)
            #expect(block.resolvedUpperNotes == block.synthPerformance.upperNotes)
            #expect(block.modulation.resolvedUpperNoteCount == block.resolvedUpperNotes.count)
            #expect(block.modulation.slideCount == block.resolvedUpperNotes.filter {
                $0.gate == .slide
            }.count)
            #expect(block.graphInputRemainderTimbreEvidence.finite)
            #expect(block.postGraphRemainderTimbreEvidence.finite)
            let activeIntents = block.resolvedUpperNotes.map(\.timbreIntent).filter {
                $0.kind != .home
            }
            if activeIntents.isEmpty {
                #expect(block.modulation.upperTimbreIntent == .home)
            } else {
                #expect(activeIntents.contains(block.modulation.upperTimbreIntent))
            }
        }
        let aggregate = UpperTimbreEvidence.aggregating(
            prepared.blocks.map(\.postGraphRemainderTimbreEvidence)
        )
        #expect(prepared.upperTimbreEvidence == aggregate)
        #expect(prepared.qualityDecision.outcome == .qualificationUnavailable)
        #expect(prepared.qualityDecision.reasonCodes.contains(.policyUncalibratedV1))
        #expect(prepared.qualityDecision.reasonCodes.contains(.staleEvidenceV1))
        #expect(prepared.qualityDecision.evidenceFingerprint == aggregate.fingerprint)
        #expect(prepared.qualityContinuationState.revision == incomingQuality.revision + 1)
        #expect(prepared.qualityContinuationState.lastDecision == prepared.qualityDecision)
        #expect(prepared.qualityContinuationState.acceptedPolicyVersion ==
                "test-calibrated-policy.v1")
        #expect(prepared.qualityContinuationState.acceptedCandidateFingerprint ==
                "previous-candidate")
        #expect(prepared.qualityContinuationState.acceptedEvidenceFingerprint == "previous-evidence")
        #expect(prepared.qualityContinuationState.acceptedControllerStateFingerprint ==
                "previous-controller")
        let selectedControllerFingerprint = String(
            format: "automatic-mix.v1.%016llx",
            prepared.endingRenderState.automaticMixState.kickCorrectionDB.bitPattern
        )
        #expect(prepared.qualityContinuationState.observedCandidateFingerprint ==
                prepared.qualityDecision.candidateFingerprint)
        #expect(prepared.qualityContinuationState.observedEvidenceFingerprint ==
                aggregate.fingerprint)
        #expect(prepared.qualityContinuationState.observedControllerStateFingerprint ==
                selectedControllerFingerprint)
        #expect(prepared.correctionRenderCount == 0)
        #expect(prepared.usedHomeTimbreFallback)
        #expect(prepared.correctionRenderCount <=
                QualityQualificationContract.maximumCorrectionRenders)
        #expect(prepared.hardGatesPassed)
        #expect(prepared.commitEligible)
        #expect(!PhraseAudioPreflight(blocks: [], sampleRate: 48_000).safetyValid)

        var advanced = state
        advanced.advance(
            using: prepared.plan,
            quality: prepared.qualityContinuationState
        )
        #expect(advanced.quality == prepared.qualityContinuationState)
        #expect(advanced.phraseIndex == prepared.plan.phraseIndex + 1)

        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: "autonomous-runtime.v1",
            routeFingerprint: "offline-route-8000",
            routeGeneration: 1
        )
        var exactJourneyStart = state
        exactJourneyStart.quality = incomingQuality
        let planCheckpoints = harness.planCheckpoints(
            director: director,
            startingState: exactJourneyStart
        )
        #expect(CanonicalJourneyCheckpoint.allCases.allSatisfy { checkpoint in
            planCheckpoints.contains { $0.checkpoint == checkpoint }
        })
        let establishment = try #require(planCheckpoints.first {
            $0.checkpoint == .establishment
        })
        #expect(establishment.phraseIndex == prepared.plan.phraseIndex)
        #expect(establishment.startBar == prepared.plan.startBar)
        #expect(establishment.phraseKind == prepared.plan.kind)
        #expect(establishment.qualityRevision == incomingQuality.revision)
        #expect(establishment.continuationFingerprint.hasSuffix(
            "quality-r\(incomingQuality.revision)"
        ))
        let report = try harness.report(
            checkpoint: establishment.checkpoint,
            prepared: prepared,
            fixtureFingerprint: establishment.fixtureFingerprint,
            continuationFingerprint: establishment.continuationFingerprint
        )
        #expect(report.checkpoint == .establishment)
        let firstJSON = try report.deterministicJSON()
        let secondJSON = try report.deterministicJSON()
        let decoded = try JSONDecoder().decode(
            CanonicalJourneyQualificationReport.self,
            from: firstJSON
        )
        #expect(firstJSON == secondJSON)
        #expect(decoded == report)
        #expect(report.usedAlternate == prepared.usedAlternate)
        #expect(report.usedFallback == prepared.usedFallback)
        #expect(report.usedHomeTimbreFallback == prepared.usedHomeTimbreFallback)
        #expect(report.correctionRenderCount == prepared.correctionRenderCount)
    }

    @Test("Hard gates, unavailable policy, alternate order, and exact ties are deterministic")
    func boundedCandidateSelection() {
        let valid = AutonomousCandidateEvidence(
            symbolicValid: true,
            safetyValid: true,
            interesting: true,
            combinedScore: 0.5
        )
        let unsafe = AutonomousCandidateEvidence(
            symbolicValid: true,
            safetyValid: false,
            interesting: true,
            combinedScore: 1
        )

        #expect(AutonomousCandidateSelector.choose(
            primary: valid, alternate: valid, qualityComparison: .unavailable
        ) == .primary)
        #expect(AutonomousCandidateSelector.choose(
            primary: valid, alternate: valid, qualityComparison: .tie
        ) == .primary)
        #expect(AutonomousCandidateSelector.choose(
            primary: valid, alternate: valid, qualityComparison: .alternate
        ) == .alternate)
        #expect(AutonomousCandidateSelector.choose(
            primary: unsafe, alternate: valid, qualityComparison: .primary
        ) == .alternate)
        #expect(AutonomousCandidateSelector.choose(
            primary: unsafe, alternate: unsafe, qualityComparison: .alternate
        ) == .fallback)
        #expect(QualityQualificationContract.maximumCorrectionRenders == 1)
        var sharedCorrectionBudget = AutonomousCorrectionBudget()
        let primaryCorrectionClaim = sharedCorrectionBudget.claim()
        let alternateCorrectionClaim = sharedCorrectionBudget.claim()
        let fallbackCorrectionClaim = sharedCorrectionBudget.claim()
        #expect(primaryCorrectionClaim)
        #expect(!alternateCorrectionClaim)
        #expect(!fallbackCorrectionClaim)
        #expect(sharedCorrectionBudget.used == 1)
        let playableDecision = QualityDecision(
            outcome: .qualificationUnavailable,
            reasonCodes: [.policyUncalibratedV1],
            candidateFingerprint: "candidate-playable",
            evidenceFingerprint: "evidence-playable"
        )
        let playableState = QualityContinuationState().recording(
            decision: playableDecision,
            evidenceFingerprint: "evidence-playable"
        )
        #expect(AutonomousCommitPolicy.isEligible(
            hardGatesPassed: true,
            decision: playableDecision,
            continuationState: playableState,
            candidateFingerprint: "candidate-playable",
            evidenceFingerprint: "evidence-playable"
        ))
        let calibratedUnavailable = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualificationUnavailable,
            reasonCodes: [.evaluatorUnavailableV1],
            candidateFingerprint: "candidate-unavailable",
            evidenceFingerprint: "evidence-unavailable"
        )
        let unavailableState = QualityContinuationState().recording(
            decision: calibratedUnavailable,
            evidenceFingerprint: "evidence-unavailable"
        )
        #expect(!AutonomousCommitPolicy.isEligible(
            hardGatesPassed: true,
            decision: calibratedUnavailable,
            continuationState: unavailableState,
            candidateFingerprint: "candidate-unavailable",
            evidenceFingerprint: "evidence-unavailable"
        ))
        let qualified = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1],
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified"
        )
        let qualifiedState = QualityContinuationState().recording(
            decision: qualified,
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        )
        #expect(AutonomousCommitPolicy.isEligible(
            hardGatesPassed: true,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            hardGatesPassed: true,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "foreign-candidate",
            evidenceFingerprint: "foreign-evidence"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            hardGatesPassed: false,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified"
        ))
    }

    @Test("Rejected candidate renders leak no state into alternate or fallback")
    func rejectedCandidateIsolation() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let source = director.candidates(from: state)
        let invalidInterest = PhraseInterestReport(
            pulseClarity: 0,
            intentionalSpace: 0,
            responseClosure: 0,
            structuralTimeliness: 0,
            identityContinuity: 0,
            weakPositionCoverage: 0,
            trailingSideRelationship: 0,
            overactivityPenalty: 1,
            overdueDebtCount: 1
        )
        let primary = shortenedCandidate(source.primary, interest: invalidInterest)
        let alternate = shortenedCandidate(source.alternate, interest: source.alternate.interest)
        let invalidAlternate = shortenedCandidate(source.alternate, interest: invalidInterest)
        let fallback = shortenedCandidate(source.fallback, interest: source.fallback.interest)
        guard alternate.interest.valid, fallback.interest.valid else {
            Issue.record("Expected valid deterministic alternate and fallback fixtures")
            return
        }

        let alternateTransaction = prepareCandidates(
            AutonomousPhraseCandidates(
                primary: primary,
                alternate: alternate,
                fallback: fallback
            ),
            state: state
        )
        let alternateDirect = prepareCandidates(
            AutonomousPhraseCandidates(
                primary: alternate,
                alternate: alternate,
                fallback: fallback
            ),
            state: state
        )
        #expect(alternateTransaction.plan == alternate)
        let alternateBlocksMatch = alternateTransaction.blocks == alternateDirect.blocks
        let alternateRenderStateMatches = alternateTransaction.endingRenderState ==
            alternateDirect.endingRenderState
        let alternateGraphStateMatches = alternateTransaction.endingGraphState ==
            alternateDirect.endingGraphState
        #expect(alternateBlocksMatch)
        #expect(alternateRenderStateMatches)
        #expect(alternateGraphStateMatches)
        #expect(alternateTransaction.qualityDecision == alternateDirect.qualityDecision)
        #expect(alternateTransaction.qualityContinuationState ==
                alternateDirect.qualityContinuationState)

        let fallbackTransaction = prepareCandidates(
            AutonomousPhraseCandidates(
                primary: primary,
                alternate: invalidAlternate,
                fallback: fallback
            ),
            state: state
        )
        let expectedFallbackGraph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var expectedFallbackRenderState = RenderState()
        var expectedFallbackGraphState = GeneratedDSPContinuationState()
        let expectedFallbackBlocks = AutonomousPhraseRenderer.render(
            plan: fallback,
            graph: expectedFallbackGraph,
            sampleRate: 8_000,
            state: &expectedFallbackRenderState,
            graphState: &expectedFallbackGraphState
        )
        #expect(fallbackTransaction.plan == fallback)
        #expect(fallbackTransaction.graph == expectedFallbackGraph)
        let fallbackBlocksMatch = fallbackTransaction.blocks == expectedFallbackBlocks
        let fallbackRenderStateMatches = fallbackTransaction.endingRenderState ==
            expectedFallbackRenderState
        let fallbackGraphStateMatches = fallbackTransaction.endingGraphState ==
            expectedFallbackGraphState
        #expect(fallbackBlocksMatch)
        #expect(fallbackRenderStateMatches)
        #expect(fallbackGraphStateMatches)
        let expectedFallbackEvidence = UpperTimbreEvidence.aggregating(
            expectedFallbackBlocks.map(\.postGraphRemainderTimbreEvidence)
        )
        #expect(fallbackTransaction.qualityDecision.evidenceFingerprint ==
                expectedFallbackEvidence.fingerprint)
        #expect(fallbackTransaction.qualityDecision.candidateFingerprint ==
                PhraseAudioPreflight(
                    blocks: expectedFallbackBlocks,
                    sampleRate: 8_000
                ).quality.sampleHash)
        #expect(fallbackTransaction.usedFallback)
        #expect(fallbackTransaction.blocks.flatMap(\.resolvedUpperNotes).allSatisfy {
            $0.timbreIntent == .home && $0.gate == .retrigger
        })
    }

    @Test("Rate-normalized fixtures preserve evidence direction and unavailable decision")
    func representativeRateIntent() {
        func evidence(sampleRate: Double) -> UpperTimbreEvidence {
            let count = Int(sampleRate * 0.5)
            let signal: [Float] = (0..<count).map { frame in
                let time = Double(frame) / sampleRate
                let motion = 0.70 + 0.22 * sin(2 * Double.pi * 3 * time)
                return Float(sin(2 * Double.pi * 220 * time) * motion * 0.4)
            }
            return UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
                left: signal,
                right: signal,
                sampleRate: sampleRate
            ))
        }

        let evidence44 = evidence(sampleRate: 44_100)
        let evidence48 = evidence(sampleRate: 48_000)
        #expect(evidence44.finite && evidence48.finite)
        #expect(evidence44.detuneMotionDepth > 0.15)
        #expect(evidence48.detuneMotionDepth > 0.15)
        #expect(abs(evidence44.detuneMotionDepth - evidence48.detuneMotionDepth) < 0.03)
        #expect(abs(evidence44.detuneMotionPeriodSeconds -
                    evidence48.detuneMotionPeriodSeconds) < 0.03)

        let decision44 = QualityDecision.qualificationUnavailable(
            evidenceFingerprint: evidence44.fingerprint
        )
        let decision48 = QualityDecision.qualificationUnavailable(
            evidenceFingerprint: evidence48.fingerprint
        )
        #expect(decision44.outcome == decision48.outcome)
        #expect(decision44.reasonCodes == decision48.reasonCodes)
    }

    @Test("Incoming render continuation makes phrase-seam evidence deterministic")
    func phraseBoundaryEvidence() {
        guard let fixture = eligibleSingleBarFixture() else {
            Issue.record("Expected a deterministic upper-voice fixture")
            return
        }
        var incoming = RenderState()
        incoming.previousGraphInputRemainderEvidenceFrame = UpperTimbreStereoFrame(
            left: 0.9, right: -0.9
        )
        incoming.previousPostGraphRemainderEvidenceFrame = UpperTimbreStereoFrame(
            left: -0.8, right: 0.8
        )
        let resolved = replacingChapter(in: fixture.resolved, with: .home)
        let first = renderSingleBar(
            plan: fixture.plan,
            resolved: resolved,
            state: fixture.state,
            incomingRenderState: incoming
        )
        let replay = renderSingleBar(
            plan: fixture.plan,
            resolved: resolved,
            state: fixture.state,
            incomingRenderState: incoming
        )

        #expect(first == replay)
        #expect(first.graphInputRemainderTimbreEvidence.maximumBoundaryDelta > 0.70)
        #expect(first.postGraphRemainderTimbreEvidence.maximumBoundaryDelta > 0.65)
    }

    private func eligibleSingleBarFixture() ->
        (state: AutonomousSessionState, plan: AutonomousPhrasePlan,
         resolved: ResolvedPerformanceBar)? {
        for seed in UInt64(1)...128 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let plan = director.candidates(from: state).primary
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

    private func shortenedCandidate(
        _ source: AutonomousPhrasePlan,
        interest: PhraseInterestReport
    ) -> AutonomousPhrasePlan {
        let bars = Array(source.resolvedBars.prefix(2))
        return AutonomousPhrasePlan(
            phraseIndex: source.phraseIndex,
            startBar: source.startBar,
            barCount: bars.count,
            kind: source.kind,
            scene: source.scene,
            dna: source.dna,
            resolvedBars: bars,
            openedDebt: source.openedDebt,
            paidDebtIDs: source.paidDebtIDs,
            requestsTopologyMutation: source.requestsTopologyMutation,
            alternate: source.alternate,
            conservative: source.conservative,
            interest: interest,
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState
        )
    }

    private func prepareCandidates(
        _ candidates: AutonomousPhraseCandidates,
        state: AutonomousSessionState
    ) -> PreparedAutonomousPhrase {
        AutonomousPhrasePreparer.prepare(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil
        )
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
            alternate: false,
            conservative: false,
            interest: PhraseInterestEvaluator.evaluate(
                resolvedBars: [resolved],
                kind: .contrast,
                memory: state.memory,
                identityPreserved: true
            ),
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState
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
                    Int((Double(note.onsetStep) * stepFrames).rounded()) ==
                        trajectory.onsetFrame
            }
            #expect(candidates.count == 1)
            guard let note = candidates.first else { continue }
            let requestedEnd = trajectory.onsetFrame + max(
                1,
                Int((note.durationInSteps * stepFrames).rounded())
            )
            #expect(trajectory.requestedGateEndFrame == requestedEnd)
            #expect(trajectory.requestedGate == note.gate)
            #expect(trajectory.timbreIntent == note.timbreIntent)
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
