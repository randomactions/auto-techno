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
        let previousControllerFingerprint =
            AutonomousCandidateFingerprint.automaticMixController(
                kickCorrectionDB: -1
            )
        let incomingQuality = QualityContinuationState().recording(
            decision: previouslyQualified,
            evidenceFingerprint: "previous-evidence",
            controllerStateFingerprint: previousControllerFingerprint
        )
        let neverCancelled: @Sendable () -> Bool = { false }
        let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: director.candidates(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: incomingQuality,
            routeRecovery: true,
            cancellationRequested: neverCancelled
        )
        let prepared = try #require(preparedResult)

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
            let anchorRetriggers = block.upperNoteRenderEvidence.filter {
                $0.role == .anchor && $0.didRetrigger
            }
            #expect(block.postGraphRemainderTimbreEvidence.velocityExpression.count ==
                    anchorRetriggers.count)
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
        var expressionIndex = 0
        var frameOffset = 0
        for block in prepared.blocks {
            for local in block.postGraphRemainderTimbreEvidence.velocityExpression {
                let phrase = prepared.upperTimbreEvidence.velocityExpression[expressionIndex]
                #expect(phrase.onsetFrame == frameOffset + local.onsetFrame)
                #expect(phrase.analyzedEndFrame == frameOffset + local.analyzedEndFrame)
                #expect(phrase.analyzedFrameCount == local.analyzedFrameCount)
                #expect(phrase.velocity == local.velocity)
                #expect(phrase.attackHighBandRatio == local.attackHighBandRatio)
                #expect(phrase.tailToAttackDB == local.tailToAttackDB)
                expressionIndex += 1
            }
            frameOffset += block.postGraphRemainderTimbreEvidence.analyzedFrameCount
        }
        #expect(expressionIndex == prepared.upperTimbreEvidence.velocityExpression.count)
        #expect(!prepared.upperTimbreEvidence.velocityExpression.isEmpty)
        #expect(prepared.upperTimbreEvidence.velocityExpression.contains {
            $0.complete
        })
        #expect(prepared.qualityDecision.outcome == .qualificationUnavailable)
        #expect(prepared.qualityDecision.reasonCodes.contains(.policyUncalibratedV1))
        #expect(prepared.qualityDecision.reasonCodes.contains(.routeRecoveryV1))
        #expect(!prepared.qualityDecision.reasonCodes.contains(.staleEvidenceV1))
        #expect(prepared.selectedCandidateEvidence.postGraphUpperTimbreEvidence ==
                aggregate)
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.candidateEvaluation.attempts.count == 1)
        #expect(prepared.qualityDecision.evidenceFingerprint ==
                prepared.candidateEvaluation.fingerprint)
        #expect(prepared.candidateEvaluationFingerprint ==
                prepared.candidateEvaluation.fingerprint)
        #expect(prepared.qualityContinuationState.revision == incomingQuality.revision + 1)
        #expect(prepared.qualityContinuationState.lastDecision == prepared.qualityDecision)
        #expect(prepared.qualityContinuationState.acceptedPolicyVersion ==
                "test-calibrated-policy.v1")
        #expect(prepared.qualityContinuationState.acceptedCandidateFingerprint ==
                "previous-candidate")
        #expect(prepared.qualityContinuationState.acceptedEvidenceFingerprint == "previous-evidence")
        #expect(prepared.qualityContinuationState.acceptedControllerStateFingerprint ==
                previousControllerFingerprint)
        let selectedControllerFingerprint = String(
            format: "automatic-mix.v1.%016llx",
            prepared.endingRenderState.automaticMixState.kickCorrectionDB.bitPattern
        )
        #expect(prepared.qualityContinuationState.observedCandidateFingerprint ==
                prepared.qualityDecision.candidateFingerprint)
        #expect(prepared.qualityContinuationState.observedEvidenceFingerprint ==
                prepared.candidateEvaluation.fingerprint)
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
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint:
                prepared.selectedCandidateEvidence.routeContinuation.routeFingerprint,
            routeGeneration:
                prepared.selectedCandidateEvidence.routeContinuation.routeGeneration
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
        let decoded = try CanonicalJourneyQualificationReport
            .decodeDeterministicJSON(firstJSON)
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
        #expect(AutonomousCandidateCorrectionPolicy.choose(
            selectedSlot: nil,
            primaryRepairable: false,
            alternateRepairable: true
        ) == .alternate)
        #expect(AutonomousCandidateCorrectionPolicy.choose(
            selectedSlot: nil,
            primaryRepairable: true,
            alternateRepairable: false
        ) == .primary)
        let playableDecision = QualityDecision(
            outcome: .qualificationUnavailable,
            reasonCodes: [.policyUncalibratedV1],
            candidateFingerprint: "candidate-playable",
            evidenceFingerprint: "evidence-playable"
        )
        let playableState = QualityContinuationState().recording(
            decision: playableDecision,
            evidenceFingerprint: "evidence-playable",
            controllerStateFingerprint: "controller-playable"
        )
        #expect(AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            decision: playableDecision,
            continuationState: playableState,
            candidateFingerprint: "candidate-playable",
            evidenceFingerprint: "evidence-playable",
            controllerStateFingerprint: "controller-playable"
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
            evidenceFingerprint: "evidence-unavailable",
            controllerStateFingerprint: "controller-unavailable"
        )
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            decision: calibratedUnavailable,
            continuationState: unavailableState,
            candidateFingerprint: "candidate-unavailable",
            evidenceFingerprint: "evidence-unavailable",
            controllerStateFingerprint: "controller-unavailable"
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
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: false,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "foreign-candidate",
            evidenceFingerprint: "foreign-evidence",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: false,
            evaluationHardGatesPassed: true,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "foreign-controller"
        ))
    }

    @Test("Paired evaluator selects one atomic alternate product and transaction")
    func pairedEvaluatorTransaction() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let candidates = director.candidates(from: state)
        let prepared = AutonomousPhrasePreparer.prepare(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            routeGeneration: 7,
            evaluator: PairedAlternateTestEvaluator()
        )
        let direct = AutonomousPhrasePreparer.prepare(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            routeGeneration: 7,
            evaluator: PairedAlternateTestEvaluator()
        )

        #expect(prepared.plan == candidates.alternate)
        #expect(prepared.blocks == direct.blocks)
        #expect(prepared.endingRenderState == direct.endingRenderState)
        #expect(prepared.endingGraphState == direct.endingGraphState)
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.candidateEvaluation.attempts.count == 2)
        #expect(Set(prepared.candidateEvaluation.attempts.map {
            $0.vector.routeContinuation.incomingContinuationFingerprint
        }).count == 1)
        #expect(prepared.candidateEvaluation.attempts.allSatisfy {
            $0.vector.planFingerprint ==
                prepared.candidateEvaluation.planFingerprints[$0.slot]
        })
        #expect(prepared.candidateEvaluation.selectedSlot == .alternate)
        #expect(prepared.candidateEvaluation.comparison == .alternate)
        #expect(prepared.selectedCandidateEvidence.slot == .alternate)
        #expect(prepared.selectedCandidateEvidence.routeContinuation.routeGeneration == 7)
        #expect(prepared.qualityDecision.outcome == .qualified)
        #expect(prepared.qualityDecision.evidenceFingerprint ==
                prepared.candidateEvaluation.fingerprint)
        #expect(prepared.qualityContinuationState.observedEvidenceFingerprint ==
                prepared.candidateEvaluation.fingerprint)
        #expect(prepared.commitProvenance.candidateEvaluationFingerprint ==
                prepared.qualityDecision.evidenceFingerprint)
        #expect(prepared.commitProvenance.outgoingRenderDSPFingerprint ==
                prepared.selectedCandidateEvidence.routeContinuation
                    .outgoingRenderDSPFingerprint)
        #expect(prepared.commitProvenance.isInternallyConsistent)
        #expect(prepared.commitEligible)
    }

    @Test("Cancellation after paired evidence prevents correction and fallback renders")
    func candidateBoundaryCancellation() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let source = director.candidates(from: state)
        let candidates = AutonomousPhraseCandidates(
            primary: shortenedCandidate(source.primary, interest: source.primary.interest),
            alternate: shortenedCandidate(
                source.alternate,
                interest: source.alternate.interest
            ),
            fallback: shortenedCandidate(source.fallback, interest: source.fallback.interest)
        )
        let gate = CandidateCancellationGate()
        let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: CancellationAfterComparisonEvaluator(gate: gate),
            cancellationRequested: { gate.check() }
        )

        #expect(prepared == nil)
        #expect(gate.comparisonCount == 1)
        #expect(gate.checkCount > 0)

        var fingerprintState = RenderState()
        fingerprintState.delayBuffer = [Float](repeating: 0.125, count: 8_192)
        let fingerprintProbe = CandidateCancellationProbe(cancelAtCheck: 5)
        let cancelledFingerprint = AutonomousTypedFingerprint.renderState(
            fingerprintState,
            cancellationRequested: { fingerprintProbe.check() }
        )
        #expect(cancelledFingerprint == nil)
        #expect(fingerprintProbe.checkCount == 5)

        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: candidates.primary,
            graph: DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed),
            sampleRate: 8_000,
            state: &renderState,
            graphState: &graphState
        )
        #expect(blocks.count == 2)
        #expect(blocks.reduce(0) { $0 + $1.left.count } > 16_384)
        // Checks 1...3 cover entry and the two block copies; check 5 is the
        // second chunk checkpoint inside the flattened left-channel scan.
        let analysisProbe = CandidateCancellationProbe(cancelAtCheck: 5)
        let cancelledReport = AudioQualityReport(
            blocks: blocks,
            sampleRate: 8_000,
            cancellationRequested: { analysisProbe.check() }
        )
        #expect(cancelledReport == nil)
        #expect(analysisProbe.checkCount == 5)

        var renderBudget = AutonomousRenderPassBudget()
        #expect((0..<QualityQualificationContract.maximumRenderPasses).allSatisfy { _ in
            renderBudget.claim()
        })
        let overBudgetClaim = renderBudget.claim()
        #expect(!overBudgetClaim)
    }

    @Test("Malformed route, score, graph, and continuation inputs stop before hashing")
    func boundedPreparationInputs() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let source = director.candidates(from: state)

        func prepare(
            _ candidates: AutonomousPhraseCandidates = source,
            sampleRate: Double = 8_000,
            routeChannelCount: Int = 2,
            renderState: RenderState = RenderState(),
            graphState: GeneratedDSPContinuationState = GeneratedDSPContinuationState(),
            previousGraph: DSPGraphPlan? = nil,
            qualityState: QualityContinuationState = QualityContinuationState(),
            routeRecovery: Bool = false
        ) -> (PreparedAutonomousPhrase?, Int) {
            let probe = CandidateCancellationProbe(cancelAtCheck: .max)
            let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                candidates: candidates,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: sampleRate,
                incomingRenderState: renderState,
                incomingGraphState: graphState,
                previousGraph: previousGraph,
                incomingQualityState: qualityState,
                routeRecovery: routeRecovery,
                routeChannelCount: routeChannelCount,
                cancellationRequested: { probe.check() }
            )
            return (prepared, probe.checkCount)
        }

        let shifted = AutonomousPhraseCandidates(
            primary: retimedCandidate(source.primary, startBar: 1),
            alternate: retimedCandidate(source.alternate, startBar: 1),
            fallback: retimedCandidate(source.fallback, startBar: 1)
        )
        let overlong = AutonomousPhraseCandidates(
            primary: retimedCandidate(source.primary, startBar: 0, barCount: 17),
            alternate: retimedCandidate(source.alternate, startBar: 0, barCount: 17),
            fallback: retimedCandidate(source.fallback, startBar: 0, barCount: 17)
        )
        func replacingResolvedBars(
            _ plan: AutonomousPhrasePlan,
            _ bars: [ResolvedPerformanceBar]
        ) -> AutonomousPhrasePlan {
            AutonomousPhrasePlan(
                phraseIndex: plan.phraseIndex,
                startBar: plan.startBar,
                barCount: plan.barCount,
                kind: plan.kind,
                scene: plan.scene,
                dna: plan.dna,
                resolvedBars: bars,
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
        func replacingGroovePulses(
            _ resolved: ResolvedPerformanceBar,
            _ pulses: [GroovePulseArticulation]
        ) -> ResolvedPerformanceBar {
            ResolvedPerformanceBar(
                performance: resolved.performance,
                ensemble: resolved.ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                foundationCompanion: resolved.foundationCompanion,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                interlockChapter: resolved.interlockChapter,
                groovePulses: pulses,
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }
        guard let pulseBarIndex = source.primary.resolvedBars.firstIndex(where: {
            !$0.groovePulses.isEmpty
        }) else {
            Issue.record("Expected a bounded-input groove-pulse fixture")
            return
        }
        let pulseBar = source.primary.resolvedBars[pulseBarIndex]
        var missingArticulationBars = source.primary.resolvedBars
        missingArticulationBars[pulseBarIndex] = replacingGroovePulses(pulseBar, [])
        let missingArticulation = AutonomousPhraseCandidates(
            primary: replacingResolvedBars(source.primary, missingArticulationBars),
            alternate: source.alternate,
            fallback: source.fallback
        )
        let sourcePulse = pulseBar.groovePulses[0]
        let mismatchedPulse = GroovePulseArticulation(
            step: sourcePulse.step,
            pulseClass: sourcePulse.pulseClass,
            stage: sourcePulse.stage,
            intensity: sourcePulse.intensity * 0.5,
            timingOffsetInSteps: sourcePulse.timingOffsetInSteps,
            strikeZone: sourcePulse.strikeZone,
            damping: sourcePulse.damping,
            timbreMicrovariation: sourcePulse.timbreMicrovariation
        )
        var mismatchedArticulationBars = source.primary.resolvedBars
        mismatchedArticulationBars[pulseBarIndex] = replacingGroovePulses(
            pulseBar,
            [mismatchedPulse] + Array(pulseBar.groovePulses.dropFirst())
        )
        let mismatchedArticulation = AutonomousPhraseCandidates(
            primary: replacingResolvedBars(source.primary, mismatchedArticulationBars),
            alternate: source.alternate,
            fallback: source.fallback
        )
        let maxBarSource = source.primary.resolvedBars[0]
        let maxBarPerformance = PerformanceBar(
            bar: Int.max,
            phrase: maxBarSource.performance.phrase,
            localBar: maxBarSource.performance.localBar,
            phraseLength: maxBarSource.performance.phraseLength,
            section: maxBarSource.performance.section,
            tension: maxBarSource.performance.tension,
            roles: maxBarSource.performance.roles,
            transformations: maxBarSource.performance.transformations,
            signatureEvent: maxBarSource.performance.signatureEvent,
            eventSeed: maxBarSource.performance.eventSeed,
            accentContour: maxBarSource.performance.accentContour
        )
        let maxBarResolved = ResolvedPerformanceBar(
            performance: maxBarPerformance,
            ensemble: maxBarSource.ensemble,
            arrangementGesture: maxBarSource.arrangementGesture,
            percussionGear: maxBarSource.percussionGear,
            foundationCompanion: maxBarSource.foundationCompanion,
            pulseEchoEnabled: maxBarSource.pulseEchoEnabled,
            interlockChapter: maxBarSource.interlockChapter,
            groovePulses: maxBarSource.groovePulses,
            spatialContrast: maxBarSource.spatialContrast,
            narrative: maxBarSource.narrative
        )
        var maxBarResolvedBars = source.primary.resolvedBars
        maxBarResolvedBars[0] = maxBarResolved
        let maxBarInput = AutonomousPhraseCandidates(
            primary: replacingResolvedBars(source.primary, maxBarResolvedBars),
            alternate: source.alternate,
            fallback: source.fallback
        )
        let fallbackPulseBarIndex = 0
        let fallbackPulseBar = source.fallback.resolvedBars[fallbackPulseBarIndex]
        let maximumAtOneStep = fallbackPulseBar.ensemble.intentionalPileup ? 6 : 3
        let fallbackOccupancy = Dictionary(
            grouping: fallbackPulseBar.ensemble.events,
            by: \.step
        )
        guard let fallbackPulseStep = (0..<16).first(where: {
            fallbackOccupancy[$0, default: []].count < maximumAtOneStep
        }) else {
            Issue.record("Expected capacity for a conservative groove-pulse fixture")
            return
        }
        let fallbackPulseIntensity = 0.20
        let nonNeutralFallbackPulse = GroovePulseArticulation(
            step: fallbackPulseStep,
            pulseClass: SixteenthPulseClass(step: fallbackPulseStep),
            stage: WeakSixteenthStage(absoluteBar: fallbackPulseBar.performance.bar),
            intensity: fallbackPulseIntensity,
            timingOffsetInSteps: 0,
            strikeZone: .edge,
            damping: 0.25,
            timbreMicrovariation: 0.04
        )
        let nonNeutralFallbackEnsemble = EnsembleContext(
            focusRole: fallbackPulseBar.ensemble.focusRole,
            events: fallbackPulseBar.ensemble.events + [EnsembleResolvedEvent(
                voice: .groovePulse,
                step: fallbackPulseStep,
                intensity: fallbackPulseIntensity,
                relocated: false
            )],
            kickAnchors: fallbackPulseBar.ensemble.kickAnchors,
            intentionalPileup: fallbackPulseBar.ensemble.intentionalPileup
        )
        let nonNeutralFallbackBar = ResolvedPerformanceBar(
            performance: fallbackPulseBar.performance,
            ensemble: nonNeutralFallbackEnsemble,
            arrangementGesture: fallbackPulseBar.arrangementGesture,
            percussionGear: fallbackPulseBar.percussionGear,
            foundationCompanion: fallbackPulseBar.foundationCompanion,
            pulseEchoEnabled: fallbackPulseBar.pulseEchoEnabled,
            interlockChapter: fallbackPulseBar.interlockChapter,
            groovePulses: [nonNeutralFallbackPulse],
            spatialContrast: fallbackPulseBar.spatialContrast,
            narrative: fallbackPulseBar.narrative
        )
        var nonNeutralFallbackBars = source.fallback.resolvedBars
        nonNeutralFallbackBars[fallbackPulseBarIndex] = nonNeutralFallbackBar
        let nonNeutralFallback = AutonomousPhraseCandidates(
            primary: source.primary,
            alternate: source.alternate,
            fallback: replacingResolvedBars(source.fallback, nonNeutralFallbackBars)
        )
        var oversizedState = RenderState()
        oversizedState.delayBuffer = [Float](repeating: 0, count: 96_002)
        var staleTimelineState = RenderState()
        staleTimelineState.barIndex = 1
        var forgedPristineControllerState = RenderState()
        forgedPristineControllerState.automaticMixState = AutomaticMixState(
            kickCorrectionDB: 0
        )
        let invalidGraph = DSPGraphPlan(
            sessionSeed: state.rootSeed,
            revision: 0,
            nodes: [],
            mutation: nil
        )
        var invalidGraphState = GeneratedDSPContinuationState()
        invalidGraphState.graph = invalidGraph
        let coherentGraph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var incoherentRecoveryState = GeneratedDSPContinuationState()
        incoherentRecoveryState.graph = coherentGraph
        let incoherentRecoveryTarget = DSPGraphPlan(
            sessionSeed: state.rootSeed,
            revision: coherentGraph.revision + 2,
            nodes: coherentGraph.nodes,
            mutation: nil,
            lowEndProtected: coherentGraph.lowEndProtected,
            protectedRouting: coherentGraph.protectedRouting
        )

        let cases = [
            prepare(shifted),
            prepare(overlong),
            prepare(missingArticulation),
            prepare(mismatchedArticulation),
            prepare(maxBarInput),
            prepare(nonNeutralFallback),
            prepare(sampleRate: 4_000),
            prepare(routeChannelCount: 1),
            prepare(renderState: staleTimelineState),
            prepare(renderState: forgedPristineControllerState),
            prepare(renderState: oversizedState),
            prepare(graphState: invalidGraphState, previousGraph: invalidGraph),
            prepare(
                graphState: incoherentRecoveryState,
                previousGraph: incoherentRecoveryTarget,
                routeRecovery: true
            ),
        ]
        #expect(cases.allSatisfy { result, checkCount in
            result == nil && checkCount == 1
        })
    }

    @Test("Conservative fallback replays the entire canonical groove-pulse cell")
    func conservativeFallbackGrooveCellIsCanonical() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let source = director.candidates(from: state)
        let barIndex = 8
        guard source.fallback.resolvedBars.indices.contains(barIndex) else {
            Issue.record("Expected a fallback long enough to hold the lean fixture")
            return
        }
        let sourceBar = source.fallback.resolvedBars[barIndex]
        let performance = PerformanceBar(
            bar: source.fallback.startBar + barIndex,
            phrase: source.fallback.phraseIndex,
            localBar: barIndex,
            phraseLength: source.fallback.barCount,
            section: sourceBar.performance.section,
            tension: sourceBar.performance.tension,
            roles: [.percussion],
            transformations: sourceBar.performance.transformations,
            signatureEvent: sourceBar.performance.signatureEvent,
            eventSeed: sourceBar.performance.eventSeed,
            accentContour: sourceBar.performance.accentContour
        )
        let ensemble = AutonomousSessionDirector.ensemblePlan(
            dna: source.fallback.dna,
            bar: performance,
            focus: .percussion,
            release: false,
            kind: source.fallback.kind,
            companion: .empty,
            gear: .anchor,
            gesture: .steady,
            conservative: true
        )
        let pulses = GroovePulseResolver.articulations(
            from: ensemble,
            absoluteBar: performance.bar,
            swingPercent: source.fallback.dna.rhythm.swingPercent,
            percussionGear: .anchor,
            eventSeed: performance.eventSeed,
            conservative: true
        )
        guard pulses.count == 8 else {
            Issue.record("Expected a complete conservative syncopated-lean cell")
            return
        }
        #expect(pulses.map(\.intensity) == [
            0.30, 0.72, 0.30, 0.72, 0.30, 0.72, 0.30, 0.72,
        ])
        let canonicalBar = ResolvedPerformanceBar(
            performance: performance,
            ensemble: ensemble,
            arrangementGesture: .steady,
            percussionGear: .anchor,
            foundationCompanion: .empty,
            pulseEchoEnabled: false,
            interlockChapter: sourceBar.interlockChapter,
            groovePulses: pulses,
            spatialContrast: sourceBar.spatialContrast,
            narrative: sourceBar.narrative
        )

        func replacingFallbackBar(
            _ bar: ResolvedPerformanceBar
        ) -> AutonomousPhraseCandidates {
            var bars = source.fallback.resolvedBars
            bars[barIndex] = bar
            let fallback = AutonomousPhrasePlan(
                phraseIndex: source.fallback.phraseIndex,
                startBar: source.fallback.startBar,
                barCount: source.fallback.barCount,
                kind: source.fallback.kind,
                scene: source.fallback.scene,
                dna: source.fallback.dna,
                resolvedBars: bars,
                openedDebt: source.fallback.openedDebt,
                paidDebtIDs: source.fallback.paidDebtIDs,
                requestsTopologyMutation: source.fallback.requestsTopologyMutation,
                alternate: source.fallback.alternate,
                conservative: source.fallback.conservative,
                interest: source.fallback.interest,
                endingInterlockState: source.fallback.endingInterlockState,
                endingSpatialContrastState: source.fallback.endingSpatialContrastState,
                endingNarrativeState: source.fallback.endingNarrativeState
            )
            return AutonomousPhraseCandidates(
                primary: source.primary,
                alternate: source.alternate,
                fallback: fallback
            )
        }
        func replacingGroove(
            events: [EnsembleResolvedEvent],
            pulses: [GroovePulseArticulation]
        ) -> AutonomousPhraseCandidates {
            let byStep = Dictionary(uniqueKeysWithValues: events.map {
                ($0.step, $0)
            })
            let resolvedEvents = ensemble.events.compactMap { event in
                event.voice == .groovePulse ? byStep[event.step] : event
            }
            return replacingFallbackBar(ResolvedPerformanceBar(
                performance: canonicalBar.performance,
                ensemble: EnsembleContext(
                    focusRole: ensemble.focusRole,
                    events: resolvedEvents,
                    kickAnchors: ensemble.kickAnchors,
                    intentionalPileup: ensemble.intentionalPileup
                ),
                arrangementGesture: canonicalBar.arrangementGesture,
                percussionGear: canonicalBar.percussionGear,
                foundationCompanion: canonicalBar.foundationCompanion,
                pulseEchoEnabled: canonicalBar.pulseEchoEnabled,
                interlockChapter: canonicalBar.interlockChapter,
                groovePulses: pulses,
                spatialContrast: canonicalBar.spatialContrast,
                narrative: canonicalBar.narrative
            ))
        }
        func prepare(
            _ candidates: AutonomousPhraseCandidates,
            cancelAtCheck: Int
        ) -> (PreparedAutonomousPhrase?, Int) {
            let probe = CandidateCancellationProbe(cancelAtCheck: cancelAtCheck)
            let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                candidates: candidates,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: RenderState(),
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                routeChannelCount: 2,
                cancellationRequested: { probe.check() }
            )
            return (prepared, probe.checkCount)
        }

        let canonical = prepare(
            replacingFallbackBar(canonicalBar),
            cancelAtCheck: 2
        )
        #expect(canonical.0 == nil && canonical.1 == 2)

        let grooveEvents = ensemble.events.filter { $0.voice == .groovePulse }
        let groupedIntensity = Dictionary(uniqueKeysWithValues:
            GroovePulseResolver.pattern(
                stage: .syncopatedLean,
                gesture: .steady,
                macroEnding: false,
                conservative: false
            )
        )
        let groupedEvents = grooveEvents.map { event in
            EnsembleResolvedEvent(
                voice: event.voice,
                step: event.step,
                intensity: groupedIntensity[event.step] ?? event.intensity,
                relocated: event.relocated
            )
        }
        let groupedPulses = pulses.map { pulse in
            GroovePulseArticulation(
                step: pulse.step,
                pulseClass: pulse.pulseClass,
                stage: pulse.stage,
                intensity: groupedIntensity[pulse.step] ?? pulse.intensity,
                timingOffsetInSteps: pulse.timingOffsetInSteps,
                strikeZone: pulse.strikeZone,
                damping: pulse.damping,
                timbreMicrovariation: pulse.timbreMicrovariation
            )
        }
        let deletedStep = pulses[0].step
        let timingSource = pulses[0]
        let forgedTiming = timingSource.timingOffsetInSteps == 0
            ? 0.01 : timingSource.timingOffsetInSteps / 2
        let timingPulses = pulses.map { pulse in
            guard pulse.step == timingSource.step else { return pulse }
            return GroovePulseArticulation(
                step: pulse.step,
                pulseClass: pulse.pulseClass,
                stage: pulse.stage,
                intensity: pulse.intensity,
                timingOffsetInSteps: forgedTiming,
                strikeZone: pulse.strikeZone,
                damping: pulse.damping,
                timbreMicrovariation: pulse.timbreMicrovariation
            )
        }
        let forged = [
            replacingGroove(events: groupedEvents, pulses: groupedPulses),
            replacingGroove(
                events: grooveEvents.filter { $0.step != deletedStep },
                pulses: pulses.filter { $0.step != deletedStep }
            ),
            replacingGroove(events: grooveEvents, pulses: timingPulses),
        ].map { prepare($0, cancelAtCheck: .max) }
        #expect(forged.allSatisfy { result, checkCount in
            result == nil && checkCount == 1
        })
    }

    @Test("Paired candidates are both evaluated before the single correction")
    func pairedCorrectionOrder() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let source = director.candidates(from: state)
        let candidates = AutonomousPhraseCandidates(
            primary: shortenedCandidate(source.primary, interest: source.primary.interest),
            alternate: shortenedCandidate(
                source.alternate,
                interest: source.alternate.interest
            ),
            fallback: shortenedCandidate(source.fallback, interest: source.fallback.interest)
        )
        let prepared = AutonomousPhrasePreparer.prepare(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: PairedPrimaryCorrectionTestEvaluator()
        )

        #expect(prepared.candidateEvaluation.attempts.map(\.kind) == [
            .initialRender, .initialRender, .correctionRender,
        ])
        #expect(prepared.candidateEvaluation.attempts.map(\.slot) == [
            .primary, .alternate, .primary,
        ])
        #expect(prepared.candidateEvaluation.selectedAttemptIndex == 2)
        #expect(prepared.candidateEvaluation.selectedSlot == .primary)
        #expect(prepared.correctionRenderCount == 1)
        #expect(!prepared.usedFallback)
        #expect(prepared.commitEligible)
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
        let expectedAlternateGraph = DSPGraphGenerator.plan(
            sessionSeed: state.rootSeed,
            phrase: alternate,
            memory: state.memory,
            previous: nil
        )
        var expectedAlternateRenderState = RenderState()
        var expectedAlternateGraphState = GeneratedDSPContinuationState()
        let expectedAlternateBlocks = AutonomousPhraseRenderer.render(
            plan: alternate,
            graph: expectedAlternateGraph,
            sampleRate: 8_000,
            state: &expectedAlternateRenderState,
            graphState: &expectedAlternateGraphState
        )
        #expect(alternateTransaction.plan == alternate)
        let alternateBlocksMatch = alternateTransaction.blocks == expectedAlternateBlocks
        let alternateRenderStateMatches = alternateTransaction.endingRenderState ==
            expectedAlternateRenderState
        let alternateGraphStateMatches = alternateTransaction.endingGraphState ==
            expectedAlternateGraphState
        #expect(alternateBlocksMatch)
        #expect(alternateRenderStateMatches)
        #expect(alternateGraphStateMatches)
        let alternateEvidence = alternateTransaction.selectedCandidateEvidence
        #expect(alternateEvidence.slot == .alternate)
        #expect(alternateTransaction.graph == expectedAlternateGraph)
        #expect(alternateEvidence.fullMix.sampleHash == PhraseAudioPreflight(
            blocks: expectedAlternateBlocks,
            sampleRate: 8_000
        ).quality.sampleHash)
        #expect(alternateTransaction.candidateEvaluation.attempts.count == 2)

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
        #expect(fallbackTransaction.selectedCandidateEvidence.postGraphUpperTimbreEvidence ==
                expectedFallbackEvidence)
        #expect(fallbackTransaction.qualityDecision.evidenceFingerprint ==
                fallbackTransaction.candidateEvaluation.fingerprint)
        #expect(fallbackTransaction.candidateEvaluation.attempts.count == 3)
        #expect(fallbackTransaction.candidateEvaluation.selectedSlot == .fallback)
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

    @Test("Equivalent 44.1 and 48 kHz transactions preserve intention and controller direction")
    func equivalentPreparedTransactionsAcrossRates() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let source = director.candidates(from: state)
        let candidates = AutonomousPhraseCandidates(
            primary: shortenedCandidate(source.primary, interest: source.primary.interest),
            alternate: shortenedCandidate(
                source.alternate,
                interest: source.alternate.interest
            ),
            fallback: shortenedCandidate(source.fallback, interest: source.fallback.interest)
        )
        func prepare(sampleRate: Double) -> PreparedAutonomousPhrase {
            AutonomousPhrasePreparer.prepare(
                candidates: candidates,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: sampleRate,
                incomingRenderState: RenderState(),
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil
            )
        }
        let rate44 = prepare(sampleRate: 44_100)
        let rate48 = prepare(sampleRate: 48_000)

        let full44 = rate44.selectedCandidateEvidence.fullMix
        let full48 = rate48.selectedCandidateEvidence.fullMix
        #expect(full44.loudnessStandard == BS1770LoudnessMeasurement.standard)
        #expect(full48.loudnessStandard == BS1770LoudnessMeasurement.standard)
        #expect(full44.truePeakStandard == BS1770AudioEvidence.truePeakStandard)
        #expect(full48.truePeakStandard == BS1770AudioEvidence.truePeakStandard)
        #expect(full44.analyzedFrameCount ==
                rate44.blocks.reduce(0) { $0 + min($1.left.count, $1.right.count) })
        #expect(full48.analyzedFrameCount ==
                rate48.blocks.reduce(0) { $0 + min($1.left.count, $1.right.count) })
        #expect(full44.momentaryBlockCount == full48.momentaryBlockCount)
        #expect(full44.shortTermBlockCount == full48.shortTermBlockCount)
        #expect(abs(full44.integratedLoudness - full48.integratedLoudness) < 0.5)
        #expect(abs(full44.truePeakDBTP - full48.truePeakDBTP) < 0.5)
        #expect(full44.bars.count == full48.bars.count)
        for (bar44, bar48) in zip(full44.bars, full48.bars) {
            #expect(bar44.bar == bar48.bar)
            #expect(abs(bar44.loudness - bar48.loudness) < 0.5)
        }

        #expect(rate44.plan == rate48.plan)
        #expect(rate44.candidateEvaluation.engineVersion ==
                rate48.candidateEvaluation.engineVersion)
        #expect(rate44.candidateEvaluation.policyVersion ==
                rate48.candidateEvaluation.policyVersion)
        #expect(rate44.candidateEvaluation.evaluatorVersion ==
                rate48.candidateEvaluation.evaluatorVersion)
        #expect(rate44.candidateEvaluation.planFingerprints ==
                rate48.candidateEvaluation.planFingerprints)
        #expect(rate44.candidateEvaluation.selectedAttemptIndex ==
                rate48.candidateEvaluation.selectedAttemptIndex)
        #expect(rate44.candidateEvaluation.selectedSlot ==
                rate48.candidateEvaluation.selectedSlot)
        #expect(rate44.candidateEvaluation.comparison ==
                rate48.candidateEvaluation.comparison)
        #expect(rate44.candidateEvaluation.correctionCount ==
                rate48.candidateEvaluation.correctionCount)
        #expect(rate44.candidateEvaluation.attempts.count ==
                rate48.candidateEvaluation.attempts.count)
        for (attempt44, attempt48) in zip(
            rate44.candidateEvaluation.attempts,
            rate48.candidateEvaluation.attempts
        ) {
            #expect(attempt44.kind == attempt48.kind)
            #expect(attempt44.slot == attempt48.slot)
            #expect(attempt44.forceSafeGraph == attempt48.forceSafeGraph)
            #expect(attempt44.forceHomeUpperTimbre ==
                    attempt48.forceHomeUpperTimbre)
            #expect(attempt44.reasonCodes == attempt48.reasonCodes)
            #expect(attempt44.vector.symbolic == attempt48.vector.symbolic)
            #expect(attempt44.vector.graph == attempt48.vector.graph)
            #expect(attempt44.vector.hardGates == attempt48.vector.hardGates)
            #expect(attempt44.vector.routeContinuation.channelCount ==
                    attempt48.vector.routeContinuation.channelCount)
            #expect(attempt44.vector.routeContinuation.incomingContinuationFingerprint ==
                    attempt48.vector.routeContinuation.incomingContinuationFingerprint)
            #expect(attempt44.vector.routeContinuation.incomingQualityStateFingerprint ==
                    attempt48.vector.routeContinuation.incomingQualityStateFingerprint)
            #expect(attempt44.vector.routeContinuation.incomingTopologyRevision ==
                    attempt48.vector.routeContinuation.incomingTopologyRevision)
            #expect(attempt44.vector.routeContinuation.previousGraphFingerprint ==
                    attempt48.vector.routeContinuation.previousGraphFingerprint)
        }
        #expect(rate44.qualityDecision.outcome == rate48.qualityDecision.outcome)
        #expect(rate44.qualityDecision.reasonCodes == rate48.qualityDecision.reasonCodes)
        #expect(rate44.usedAlternate == rate48.usedAlternate)
        #expect(rate44.usedFallback == rate48.usedFallback)
        #expect(rate44.usedHomeTimbreFallback == rate48.usedHomeTimbreFallback)
        #expect(rate44.commitEligible && rate48.commitEligible)

        func kickTrajectory(_ prepared: PreparedAutonomousPhrase) -> [Double] {
            prepared.selectedCandidateEvidence.automaticMix
                .sorted { $0.bar < $1.bar }
                .compactMap { evidence in
                    evidence.gains.first {
                        $0.role == MixRole.kick.rawValue
                    }?.gainDB
                }
        }
        for trajectory in [kickTrajectory(rate44), kickTrajectory(rate48)] {
            #expect(trajectory.count == candidates.primary.barCount)
            guard let first = trajectory.first else {
                Issue.record("Expected a bounded kick-controller trajectory")
                continue
            }
            #expect(first < AutomaticMixBalancer.homeKickCorrectionDB)
            #expect(trajectory.dropFirst().allSatisfy { $0 == first })
        }
        #expect(rate44.selectedCandidateEvidence.routeContinuation.sampleRate == 44_100)
        #expect(rate48.selectedCandidateEvidence.routeContinuation.sampleRate == 48_000)
        #expect(rate44.selectedCandidateEvidence.routeContinuation.routeFingerprint !=
                rate48.selectedCandidateEvidence.routeContinuation.routeFingerprint)
        #expect(rate44.audioPreflight.quality.sampleHash !=
                rate48.audioPreflight.quality.sampleHash)
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

    private func velocityIsolatedFixture() ->
        (state: AutonomousSessionState, plan: AutonomousPhrasePlan,
         resolved: ResolvedPerformanceBar, step: Int)? {
        for seed in UInt64(1)...256 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let plan = director.candidates(from: state).primary
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

    private func shortenedCandidate(
        _ source: AutonomousPhrasePlan,
        interest: PhraseInterestReport
    ) -> AutonomousPhrasePlan {
        let selected = Array(source.resolvedBars.prefix(2))
        let bars = selected.map { resolved in
            let performance = resolved.performance
            let shortenedPerformance = PerformanceBar(
                bar: performance.bar,
                phrase: performance.phrase,
                localBar: performance.localBar,
                phraseLength: selected.count,
                section: performance.section,
                tension: performance.tension,
                roles: performance.roles,
                transformations: performance.transformations,
                signatureEvent: performance.signatureEvent,
                eventSeed: performance.eventSeed,
                accentContour: performance.accentContour
            )
            return ResolvedPerformanceBar(
                performance: shortenedPerformance,
                ensemble: resolved.ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                foundationCompanion: resolved.foundationCompanion,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                interlockChapter: resolved.interlockChapter,
                groovePulses: resolved.groovePulses,
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }
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

    private func retimedCandidate(
        _ source: AutonomousPhrasePlan,
        startBar: Int,
        barCount: Int? = nil
    ) -> AutonomousPhrasePlan {
        let count = barCount ?? source.barCount
        let bars = (0..<count).map { index in
            let resolved = source.resolvedBars[index % source.resolvedBars.count]
            let performance = resolved.performance
            let retimedPerformance = PerformanceBar(
                bar: startBar + index,
                phrase: source.phraseIndex,
                localBar: index,
                phraseLength: count,
                section: performance.section,
                tension: performance.tension,
                roles: performance.roles,
                transformations: performance.transformations,
                signatureEvent: performance.signatureEvent,
                eventSeed: performance.eventSeed,
                accentContour: performance.accentContour
            )
            return ResolvedPerformanceBar(
                performance: retimedPerformance,
                ensemble: resolved.ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                foundationCompanion: resolved.foundationCompanion,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                interlockChapter: resolved.interlockChapter,
                groovePulses: resolved.groovePulses,
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }
        return AutonomousPhrasePlan(
            phraseIndex: source.phraseIndex,
            startBar: startBar,
            barCount: count,
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

package struct PairedAlternateTestEvaluator: AutonomousCandidateEvaluating {
    package let policyVersion = "test-calibrated-policy.v1"
    package let evaluatorVersion = "test-paired-alternate.v1"
    package let requiresPairedCandidates = true

    package init() {}

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        .alternate
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        false
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1]
        )
    }
}

package struct PairedPrimaryCorrectionTestEvaluator: AutonomousCandidateEvaluating {
    package let policyVersion = "test-calibrated-correction.v1"
    package let evaluatorVersion = "test-paired-primary-correction.v1"
    package let requiresPairedCandidates = true

    package init() {}

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        .primary
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        slot == .primary && !candidate.symbolic.conservative
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1]
        )
    }
}

private final class CandidateCancellationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var comparisons = 0
    private var checks = 0

    var comparisonCount: Int { lock.withLock { comparisons } }
    var checkCount: Int { lock.withLock { checks } }

    func cancelAfterComparison() {
        lock.withLock {
            comparisons += 1
            cancelled = true
        }
    }

    func check() -> Bool {
        lock.withLock {
            checks += 1
            return cancelled
        }
    }
}

package struct CancellationAfterComparisonEvaluator: AutonomousCandidateEvaluating {
    package let policyVersion = "test-cancel-after-comparison.v1"
    package let evaluatorVersion = "test-cancel-after-comparison.v1"
    package let requiresPairedCandidates = true
    private let gate: CandidateCancellationGate

    fileprivate init(gate: CandidateCancellationGate) {
        self.gate = gate
    }

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        gate.cancelAfterComparison()
        return .primary
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        slot == .primary && !candidate.symbolic.conservative
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1]
        )
    }
}

private final class CandidateCancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let cancelAtCheck: Int
    private var count = 0

    init(cancelAtCheck: Int) {
        self.cancelAtCheck = max(1, cancelAtCheck)
    }

    var checkCount: Int {
        lock.withLock { count }
    }

    func check() -> Bool {
        lock.withLock {
            count += 1
            return count >= cancelAtCheck
        }
    }
}
