import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

private struct ClosedHatRouteProjection {
    let routeFingerprint: String
    let sampleRate: Double
}

private final class ClosedHatCompanionFixtureBox {
    let state: AutonomousSessionState
    let candidates: AutonomousPhraseCandidates

    init(state: AutonomousSessionState, candidates: AutonomousPhraseCandidates) {
        self.state = state
        self.candidates = candidates
    }
}

private struct PreparedRateAttemptProjection: Equatable {
    let kind: AutonomousCandidateAttemptKind
    let slot: AutonomousCandidateSlot
    let forceSafeGraph: Bool
    let forceHomeUpperTimbre: Bool
    let reasonCodes: [QualityReasonCode]
    let symbolic: AutonomousSymbolicEvidence
    let graph: AutonomousGraphEvidence
    let hardGates: AutonomousHardGateEvidence
    let routeChannelCount: Int
    let incomingContinuationFingerprint: String
    let incomingQualityStateFingerprint: String
    let incomingTopologyRevision: Int
    let previousGraphFingerprint: String

    init(_ attempt: AutonomousCandidateAttempt) {
        kind = attempt.kind
        slot = attempt.slot
        forceSafeGraph = attempt.forceSafeGraph
        forceHomeUpperTimbre = attempt.forceHomeUpperTimbre
        reasonCodes = attempt.reasonCodes
        symbolic = attempt.vector.symbolic
        graph = attempt.vector.graph
        hardGates = attempt.vector.hardGates
        routeChannelCount = attempt.vector.routeContinuation.channelCount
        incomingContinuationFingerprint =
            attempt.vector.routeContinuation.incomingContinuationFingerprint
        incomingQualityStateFingerprint =
            attempt.vector.routeContinuation.incomingQualityStateFingerprint
        incomingTopologyRevision =
            attempt.vector.routeContinuation.incomingTopologyRevision
        previousGraphFingerprint =
            attempt.vector.routeContinuation.previousGraphFingerprint
    }
}

private struct PreparedRateProjection {
    let fullMix: AutonomousFullMixEvidence
    let plan: AutonomousPhrasePlan
    let engineVersion: String
    let policyVersion: String
    let evaluatorVersion: String
    let planFingerprints: AutonomousCandidatePlanFingerprints
    let selectedAttemptIndex: Int?
    let selectedSlot: AutonomousCandidateSlot?
    let comparison: AutonomousCandidateComparison
    let correctionCount: Int
    let attempts: [PreparedRateAttemptProjection]
    let qualityOutcome: QualityDecisionOutcome
    let qualityReasonCodes: [QualityReasonCode]
    let usedAlternate: Bool
    let usedFallback: Bool
    let usedHomeTimbreFallback: Bool
    let routeFingerprint: String
    let sampleHash: String
}

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

    @Test("Prepared phrase commits resolved notes, evidence, and quality state together")
    func atomicPreparedContinuation() throws {
        try assertAtomicPreparedContinuation()
    }

    @inline(never)
    private func assertAtomicPreparedContinuation() throws {
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
            selectedSlot: .primary,
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
            selectedSlot: .primary,
            decision: calibratedUnavailable,
            continuationState: unavailableState,
            candidateFingerprint: "candidate-unavailable",
            evidenceFingerprint: "evidence-unavailable",
            controllerStateFingerprint: "controller-unavailable"
        ))
        let calibratedFallback = QualityDecision(
            policyVersion: "test-calibrated-policy.v1",
            outcome: .conservativeFallback,
            reasonCodes: [.conservativeFallbackV1],
            candidateFingerprint: "candidate-fallback",
            evidenceFingerprint: "evidence-fallback"
        )
        let fallbackState = QualityContinuationState().recording(
            decision: calibratedFallback,
            evidenceFingerprint: "evidence-fallback",
            controllerStateFingerprint: "controller-fallback"
        )
        #expect(AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            selectedSlot: .fallback,
            decision: calibratedFallback,
            continuationState: fallbackState,
            candidateFingerprint: "candidate-fallback",
            evidenceFingerprint: "evidence-fallback",
            controllerStateFingerprint: "controller-fallback"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: false,
            selectedSlot: .fallback,
            decision: calibratedFallback,
            continuationState: fallbackState,
            candidateFingerprint: "candidate-fallback",
            evidenceFingerprint: "evidence-fallback",
            controllerStateFingerprint: "controller-fallback"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            selectedSlot: .primary,
            decision: calibratedFallback,
            continuationState: fallbackState,
            candidateFingerprint: "candidate-fallback",
            evidenceFingerprint: "evidence-fallback",
            controllerStateFingerprint: "controller-fallback"
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
            selectedSlot: .primary,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: false,
            selectedSlot: .primary,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            selectedSlot: .fallback,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            selectedSlot: nil,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            selectedSlot: .primary,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "foreign-candidate",
            evidenceFingerprint: "foreign-evidence",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: false,
            evaluationHardGatesPassed: true,
            selectedSlot: .primary,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "controller-qualified"
        ))
        #expect(!AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: true,
            evaluationHardGatesPassed: true,
            selectedSlot: .primary,
            decision: qualified,
            continuationState: qualifiedState,
            candidateFingerprint: "candidate-qualified",
            evidenceFingerprint: "evidence-qualified",
            controllerStateFingerprint: "foreign-controller"
        ))
    }

    @Test("Closed-hat decay articulation participates in typed plan identity")
    func closedHatDecayPlanFingerprint() throws {
        let fixture = try #require(closedHatCompanionFixture())
        let source = fixture.candidates.primary
        let barIndex = try #require(source.resolvedBars.firstIndex(where: { bar in
            bar.closedHatDecayArticulations.contains { $0.role == .openHatCompanion }
        }))
        let bar = source.resolvedBars[barIndex]
        let articulationIndex = try #require(
            bar.closedHatDecayArticulations.firstIndex {
                $0.role == .openHatCompanion
            }
        )
        let sourceArticulation = bar.closedHatDecayArticulations[articulationIndex]
        var changedArticulations = bar.closedHatDecayArticulations
        changedArticulations[articulationIndex] = ClosedHatDecayArticulation(
            scoreEventIndex: sourceArticulation.scoreEventIndex,
            step: sourceArticulation.step,
            role: .neutral
        )
        var changedBars = source.resolvedBars
        changedBars[barIndex] = barReplacingClosedHatDecayArticulations(
            in: bar,
            with: changedArticulations
        )
        let changed = planReplacingResolvedBars(in: source, with: changedBars)

        #expect(source != changed)
        #expect(AutonomousCandidateFingerprint.plan(source) !=
                AutonomousCandidateFingerprint.plan(changed))

        let forgedCandidates = AutonomousPhraseCandidates(
            primary: changed,
            alternate: fixture.candidates.alternate,
            fallback: fixture.candidates.fallback
        )
        let probe = CandidateCancellationProbe(cancelAtCheck: .max)
        let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: forgedCandidates,
            sessionSeed: fixture.state.rootSeed,
            memory: fixture.state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            routeChannelCount: 2,
            cancellationRequested: { probe.check() }
        )
        #expect(prepared == nil)
        #expect(probe.checkCount == 1)
    }

    @Test("Canonical closed/open-hat relation survives 8 kHz route preparation")
    func closedHatCompanion8KRoutePreparation() throws {
        let rate8 = try closedHatRouteProjection(
            sampleRate: 8_000,
            routeGeneration: 4
        )
        #expect(!rate8.routeFingerprint.isEmpty)
        #expect(rate8.sampleRate == 8_000)
    }

    @Test("Canonical closed/open-hat relation survives 12 kHz route preparation")
    func closedHatCompanion12KRoutePreparation() throws {
        let rate12 = try closedHatRouteProjection(
            sampleRate: 12_000,
            routeGeneration: 5
        )
        #expect(!rate12.routeFingerprint.isEmpty)
        #expect(rate12.sampleRate == 12_000)
    }

    @Test("Closed-hat renderer evidence tampering is rejected by vector reduction")
    func closedHatCompanionRenderEvidenceTampering() throws {
        try assertClosedHatRenderEvidenceTamperingIsRejected()
    }

    @Test("Pulse-echo same-pass binding tampering remains retainable and incomplete")
    func pulseEchoReturnBindingTampering() throws {
        try assertPulseEchoReturnBindingTamperingIsRejected()
    }

    @inline(never)
    private func closedHatRouteProjection(
        sampleRate: Double,
        routeGeneration: Int
    ) throws -> ClosedHatRouteProjection {
        let fixture = try #require(closedHatCompanionFixture())
        let state = fixture.state
        let candidates = fixture.candidates
        let expectedRelations = candidates.primary.resolvedBars.flatMap { bar in
            bar.closedHatDecayArticulations.filter {
                $0.role == .openHatCompanion
            }.map {
                "\(bar.performance.bar):\($0.scoreEventIndex):\($0.step):\($0.role.rawValue)"
            }
        }
        #expect(!expectedRelations.isEmpty)

        var incomingRenderState = RenderState()
        incomingRenderState.barIndex = state.memory.totalBars
        let preparedCandidate = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: sampleRate,
            incomingRenderState: incomingRenderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            routeRecovery: false,
            routeGeneration: routeGeneration,
            cancellationRequested: { false }
        )
        let prepared = try #require(preparedCandidate)
        #expect(prepared.plan == candidates.primary)
        #expect(prepared.candidateEvaluation.selectedSlot == .primary)
        #expect(prepared.candidateEvaluation.comparison == .unavailable)
        #expect(prepared.candidateEvaluation.attempts.count == 1)
        #expect(prepared.candidateEvaluation.planFingerprints ==
                AutonomousCandidatePlanFingerprints.make(candidates: candidates))
        #expect(prepared.qualityDecision.outcome == .qualificationUnavailable)
        #expect(prepared.qualityDecision.reasonCodes.contains(.policyUncalibratedV1))
        #expect(prepared.hardGatesPassed)
        #expect(prepared.commitEligible)
        #expect(prepared.selectedCandidateEvidence.routeContinuation.routeFingerprint ==
                AutonomousCandidateFingerprint.route(
                    sampleRate: sampleRate,
                    channelCount: 2,
                    generation: routeGeneration
                ))

        var renderedRelations: [String] = []
        for (resolved, block) in zip(candidates.primary.resolvedBars, prepared.blocks) {
            #expect(block.resolvedPerformance == resolved)
            #expect(block.closedHatRenderEvidence.count ==
                    resolved.closedHatDecayArticulations.count)
            for articulation in resolved.closedHatDecayArticulations where
                articulation.role == .openHatCompanion {
                let closedHat = try #require(
                    resolved.ensemble.events.indices.contains(
                        articulation.scoreEventIndex
                    ) ? resolved.ensemble.events[articulation.scoreEventIndex] : nil
                )
                #expect(closedHat.voice == .percussion)
                #expect(closedHat.step == articulation.step)
                #expect(resolved.ensemble.events.contains {
                    $0.voice == .openHat && $0.step == articulation.step
                })
                let evidence = try #require(block.closedHatRenderEvidence.first {
                    $0.scoreEventIndex == articulation.scoreEventIndex
                })
                #expect(evidence.step == articulation.step)
                #expect(evidence.role == .openHatCompanion)
                #expect(evidence.eventIntensity == closedHat.intensity)
                #expect(evidence.relocated == closedHat.relocated)
                #expect(evidence.appliedDecayRate == ClosedHatVoiceContract.decayRate(
                    brightness: candidates.primary.scene.character.percussionBrightness,
                    role: .openHatCompanion
                ))
                #expect(evidence.finite)
                renderedRelations.append(
                    "\(resolved.performance.bar):\(evidence.scoreEventIndex):" +
                        "\(evidence.step):\(evidence.role.rawValue)"
                )
            }
        }
        #expect(renderedRelations == expectedRelations)

        return ClosedHatRouteProjection(
            routeFingerprint: prepared.selectedCandidateEvidence
                .routeContinuation.routeFingerprint,
            sampleRate: prepared.selectedCandidateEvidence.routeContinuation.sampleRate
        )
    }

    @inline(never)
    private func assertClosedHatRenderEvidenceTamperingIsRejected() throws {
        let fixture = try #require(closedHatCompanionFixture())
        let state = fixture.state
        let candidates = fixture.candidates
        var incomingRenderState = RenderState()
        incomingRenderState.barIndex = state.memory.totalBars
        let preparedCandidate = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: incomingRenderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            routeRecovery: false,
            routeGeneration: 4,
            cancellationRequested: { false }
        )
        let prepared = try #require(preparedCandidate)
        let targetBlockIndex = try #require(prepared.blocks.firstIndex { block in
            block.closedHatRenderEvidence.contains {
                $0.role == .openHatCompanion
            }
        })
        let targetBlock = prepared.blocks[targetBlockIndex]
        let targetEvidenceIndex = try #require(
            targetBlock.closedHatRenderEvidence.firstIndex {
                $0.role == .openHatCompanion
            }
        )
        let sourceEvidence = targetBlock.closedHatRenderEvidence[targetEvidenceIndex]
        var forgedEvidence = targetBlock.closedHatRenderEvidence
        forgedEvidence[targetEvidenceIndex] = closedHatEvidence(
            replacing: sourceEvidence,
            appliedDecayRate: sourceEvidence.appliedDecayRate + 1
        )
        var forgedBlocks = prepared.blocks
        forgedBlocks[targetBlockIndex] = renderBlock(
            replacing: targetBlock,
            closedHatRenderEvidence: forgedEvidence
        )
        let route = prepared.selectedCandidateEvidence.routeContinuation
        let noCancellation: @Sendable () -> Bool = { false }
        let maybeForgedVector = AutonomousCandidateEvaluationVector.make(
            slot: prepared.selectedCandidateEvidence.slot,
            plan: prepared.plan,
            graph: prepared.graph,
            planFingerprint: prepared.selectedCandidateEvidence.planFingerprint,
            graphFingerprint: prepared.selectedCandidateEvidence.graphFingerprint,
            blocks: forgedBlocks,
            audioPreflight: prepared.audioPreflight,
            upperTimbreEvidence: prepared.upperTimbreEvidence,
            sampleRate: route.sampleRate,
            routeChannelCount: route.channelCount,
            routeGeneration: route.routeGeneration,
            routeFingerprint: route.routeFingerprint,
            incomingContinuationFingerprint: route.incomingContinuationFingerprint,
            incomingQualityStateFingerprint: route.incomingQualityStateFingerprint,
            incomingKickCorrectionDB: route.incomingKickCorrectionDB,
            incomingTopologyRevision: route.incomingTopologyRevision,
            previousGraphFingerprint: route.previousGraphFingerprint,
            routeRecovery: route.routeRecovery,
            outgoingRenderDSPFingerprint: route.outgoingRenderDSPFingerprint,
            controllerStateFingerprint: route.controllerStateFingerprint,
            incomingDramaticDebts: state.memory.openDebts,
            cancellationRequested: noCancellation
        )
        let forgedVector = try #require(maybeForgedVector)
        #expect(!forgedVector.isComplete)
        #expect(forgedVector.closedHat[targetBlockIndex].events.count ==
                targetBlock.closedHatRenderEvidence.count - 1)
    }

    @inline(never)
    private func assertPulseEchoReturnBindingTamperingIsRejected() throws {
        let fixture = try #require(closedHatCompanionFixture())
        let state = fixture.state
        var incomingRenderState = RenderState()
        incomingRenderState.barIndex = state.memory.totalBars
        let preparedCandidate = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: fixture.candidates,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: incomingRenderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            routeRecovery: false,
            routeGeneration: 4,
            cancellationRequested: { false }
        )
        let prepared = try #require(preparedCandidate)
        let targetBlock = try #require(prepared.blocks.first)
        let sourceEvidence = targetBlock.pulseEchoReturnDriveRenderEvidence
        let forgedTexture = sourceEvidence.machineTexture == 0 ? 0.5 : 0
        let forgedEvidence = pulseEchoEvidence(
            replacing: sourceEvidence,
            machineTexture: forgedTexture
        )
        var forgedBlocks = prepared.blocks
        forgedBlocks[0] = renderBlock(
            replacing: targetBlock,
            pulseEchoReturnDriveRenderEvidence: forgedEvidence
        )
        let route = prepared.selectedCandidateEvidence.routeContinuation
        let maybeForgedVector = AutonomousCandidateEvaluationVector.make(
            slot: prepared.selectedCandidateEvidence.slot,
            plan: prepared.plan,
            graph: prepared.graph,
            planFingerprint: prepared.selectedCandidateEvidence.planFingerprint,
            graphFingerprint: prepared.selectedCandidateEvidence.graphFingerprint,
            blocks: forgedBlocks,
            audioPreflight: prepared.audioPreflight,
            upperTimbreEvidence: prepared.upperTimbreEvidence,
            sampleRate: route.sampleRate,
            routeChannelCount: route.channelCount,
            routeGeneration: route.routeGeneration,
            routeFingerprint: route.routeFingerprint,
            incomingContinuationFingerprint: route.incomingContinuationFingerprint,
            incomingQualityStateFingerprint: route.incomingQualityStateFingerprint,
            incomingKickCorrectionDB: route.incomingKickCorrectionDB,
            incomingTopologyRevision: route.incomingTopologyRevision,
            previousGraphFingerprint: route.previousGraphFingerprint,
            routeRecovery: route.routeRecovery,
            outgoingRenderDSPFingerprint: route.outgoingRenderDSPFingerprint,
            controllerStateFingerprint: route.controllerStateFingerprint,
            incomingDramaticDebts: state.memory.openDebts,
            cancellationRequested: { false }
        )
        let forgedVector = try #require(maybeForgedVector)
        #expect(forgedVector.pulseEchoDrive.count == prepared.blocks.count)
        #expect(!forgedVector.pulseEchoDrive[0].bindingValid)
        #expect(!forgedVector.isComplete)
        #expect(forgedVector.recordIsStructurallyValid)

        let sourceAttempt = try #require(
            prepared.candidateEvaluation.attempts.first
        )
        let retained = AutonomousCandidateAttempt(
            kind: sourceAttempt.kind,
            forceSafeGraph: sourceAttempt.forceSafeGraph,
            forceHomeUpperTimbre: sourceAttempt.forceHomeUpperTimbre,
            reasonCodes: [.evidenceMissingV1, .hardGateFailedV1],
            vector: forgedVector
        )
        #expect(retained.isStructurallyComplete)
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
                endingNarrativeState: plan.endingNarrativeState,
                harmonicContinuation: plan.incomingHarmonicContinuation
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
                closedHatDecayArticulations: resolved.closedHatDecayArticulations,
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }
        guard let closedHatBarIndex = source.primary.resolvedBars.firstIndex(where: {
            !$0.closedHatDecayArticulations.isEmpty
        }) else {
            Issue.record("Expected a bounded-input closed-hat fixture")
            return
        }
        let closedHatBar = source.primary.resolvedBars[closedHatBarIndex]
        let sourceClosedHat = closedHatBar.closedHatDecayArticulations[0]
        let closedHatIndexes = Set(
            closedHatBar.closedHatDecayArticulations.map(\.scoreEventIndex)
        )
        guard let retargetIndex = closedHatBar.ensemble.events.indices.first(where: {
            !closedHatIndexes.contains($0) &&
                closedHatBar.ensemble.events[$0].voice != .percussion
        }) else {
            Issue.record("Expected a non-hat score event for retargeting")
            return
        }
        let retargetEvent = closedHatBar.ensemble.events[retargetIndex]

        func closedHatCandidates(
            _ articulations: [ClosedHatDecayArticulation],
            plan: AutonomousPhrasePlan
        ) -> AutonomousPhraseCandidates {
            let targetBarIndex = plan.conservative
                ? plan.resolvedBars.firstIndex {
                    !$0.closedHatDecayArticulations.isEmpty
                } ?? 0
                : closedHatBarIndex
            var bars = plan.resolvedBars
            bars[targetBarIndex] = barReplacingClosedHatDecayArticulations(
                in: bars[targetBarIndex],
                with: articulations
            )
            let changed = planReplacingResolvedBars(in: plan, with: bars)
            return AutonomousPhraseCandidates(
                primary: plan.conservative ? source.primary : changed,
                alternate: source.alternate,
                fallback: plan.conservative ? changed : source.fallback
            )
        }

        let missingClosedHat = closedHatCandidates(
            Array(closedHatBar.closedHatDecayArticulations.dropLast()),
            plan: source.primary
        )
        let duplicateClosedHat = closedHatCandidates(
            closedHatBar.closedHatDecayArticulations + [sourceClosedHat],
            plan: source.primary
        )
        var retargetedClosedHats = closedHatBar.closedHatDecayArticulations
        retargetedClosedHats[0] = ClosedHatDecayArticulation(
            scoreEventIndex: retargetIndex,
            step: retargetEvent.step,
            role: sourceClosedHat.role
        )
        let retargetedClosedHat = closedHatCandidates(
            retargetedClosedHats,
            plan: source.primary
        )

        guard let conservativeBarIndex = source.fallback.resolvedBars.firstIndex(where: {
            $0.ensemble.events.filter { $0.voice == .percussion }.count <
                AutonomousCandidateEvaluationVector.maximumClosedHatEventsPerBar
        }) else {
            Issue.record("Expected capacity for a conservative closed-hat fixture")
            return
        }
        let conservativeSourceBar = source.fallback.resolvedBars[conservativeBarIndex]
        let conservativeMaximumAtOneStep = conservativeSourceBar.ensemble.intentionalPileup
            ? 6 : 3
        let conservativeOccupancy = Dictionary(
            grouping: conservativeSourceBar.ensemble.events,
            by: \.step
        )
        guard let conservativeStep = (0..<16).first(where: {
            conservativeOccupancy[$0, default: []].count < conservativeMaximumAtOneStep
        }) else {
            Issue.record("Expected a free conservative closed-hat step")
            return
        }
        let conservativeEvents = (conservativeSourceBar.ensemble.events + [
            EnsembleResolvedEvent(
                voice: .percussion,
                step: conservativeStep,
                intensity: 0.48,
                relocated: false
            ),
        ]).sorted {
            if $0.step != $1.step { return $0.step < $1.step }
            return $0.voice.rawValue < $1.voice.rawValue
        }
        let conservativeEnsemble = EnsembleContext(
            focusRole: conservativeSourceBar.ensemble.focusRole,
            events: conservativeEvents,
            kickAnchors: conservativeSourceBar.ensemble.kickAnchors,
            intentionalPileup: conservativeSourceBar.ensemble.intentionalPileup
        )
        let conservativeBar = ResolvedPerformanceBar(
            performance: conservativeSourceBar.performance,
            ensemble: conservativeEnsemble,
            arrangementGesture: conservativeSourceBar.arrangementGesture,
            percussionGear: conservativeSourceBar.percussionGear,
            foundationCompanion: conservativeSourceBar.foundationCompanion,
            pulseEchoEnabled: conservativeSourceBar.pulseEchoEnabled,
            interlockChapter: conservativeSourceBar.interlockChapter,
            groovePulses: conservativeSourceBar.groovePulses,
            closedHatDecayArticulations: ClosedHatDecayResolver.articulations(
                from: conservativeEnsemble,
                conservative: true
            ),
            spatialContrast: conservativeSourceBar.spatialContrast,
            narrative: conservativeSourceBar.narrative
        )
        var neutralConservativeBars = source.fallback.resolvedBars
        neutralConservativeBars[conservativeBarIndex] = conservativeBar
        let neutralConservativePlan = planReplacingResolvedBars(
            in: source.fallback,
            with: neutralConservativeBars
        )
        guard let conservativeHat = conservativeBar.closedHatDecayArticulations.first else {
            Issue.record("Expected a resolved conservative closed-hat articulation")
            return
        }
        var nonNeutralConservativeHats = conservativeBar.closedHatDecayArticulations
        nonNeutralConservativeHats[0] = ClosedHatDecayArticulation(
            scoreEventIndex: conservativeHat.scoreEventIndex,
            step: conservativeHat.step,
            role: .openHatCompanion
        )
        let nonNeutralConservativeHat = closedHatCandidates(
            nonNeutralConservativeHats,
            plan: neutralConservativePlan
        )

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
            closedHatDecayArticulations: maxBarSource.closedHatDecayArticulations,
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
            closedHatDecayArticulations: fallbackPulseBar.closedHatDecayArticulations,
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

        func expectRejected(
            _ result: @autoclosure () -> (PreparedAutonomousPhrase?, Int)
        ) {
            let (prepared, checkCount) = result()
            #expect(prepared == nil)
            #expect(checkCount == 1)
        }
        expectRejected(prepare(shifted))
        expectRejected(prepare(overlong))
        expectRejected(prepare(missingClosedHat))
        expectRejected(prepare(duplicateClosedHat))
        expectRejected(prepare(retargetedClosedHat))
        expectRejected(prepare(nonNeutralConservativeHat))
        expectRejected(prepare(missingArticulation))
        expectRejected(prepare(mismatchedArticulation))
        expectRejected(prepare(maxBarInput))
        expectRejected(prepare(nonNeutralFallback))
        expectRejected(prepare(sampleRate: 4_000))
        expectRejected(prepare(routeChannelCount: 1))
        expectRejected(prepare(renderState: staleTimelineState))
        expectRejected(prepare(renderState: forgedPristineControllerState))
        expectRejected(prepare(renderState: oversizedState))
        expectRejected(prepare(
            graphState: invalidGraphState,
            previousGraph: invalidGraph
        ))
        expectRejected(prepare(
            graphState: incoherentRecoveryState,
            previousGraph: incoherentRecoveryTarget,
            routeRecovery: true
        ))
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
            performanceCharacter: .hypnoticLock,
            foundationBehavior: .absent,
            foundationCompanion: .empty,
            pulseEchoEnabled: false,
            interlockChapter: sourceBar.interlockChapter,
            groovePulses: pulses,
            closedHatDecayArticulations: ClosedHatDecayResolver.articulations(
                from: ensemble,
                conservative: true
            ),
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
                endingNarrativeState: source.fallback.endingNarrativeState,
                harmonicContinuation: source.fallback.incomingHarmonicContinuation
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
                performanceCharacter: canonicalBar.performanceCharacter,
                foundationBehavior: canonicalBar.foundationBehavior,
                foundationCompanion: canonicalBar.foundationCompanion,
                pulseEchoEnabled: canonicalBar.pulseEchoEnabled,
                interlockChapter: canonicalBar.interlockChapter,
                groovePulses: pulses,
                closedHatDecayArticulations: canonicalBar.closedHatDecayArticulations,
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
    func equivalentPreparedTransactionsAcrossRates() throws {
        let rate44 = try preparedRateProjection(sampleRate: 44_100)
        let rate48 = try preparedRateProjection(sampleRate: 48_000)

        let full44 = rate44.fullMix
        let full48 = rate48.fullMix
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
        #expect(rate44.engineVersion == rate48.engineVersion)
        #expect(rate44.policyVersion == rate48.policyVersion)
        #expect(rate44.evaluatorVersion == rate48.evaluatorVersion)
        #expect(rate44.planFingerprints == rate48.planFingerprints)
        #expect(rate44.selectedAttemptIndex == rate48.selectedAttemptIndex)
        #expect(rate44.selectedSlot == rate48.selectedSlot)
        #expect(rate44.comparison == rate48.comparison)
        #expect(rate44.correctionCount == rate48.correctionCount)
        #expect(rate44.attempts.count == rate48.attempts.count)
        #expect(rate44.attempts == rate48.attempts)
        #expect(rate44.qualityOutcome == rate48.qualityOutcome)
        #expect(rate44.qualityReasonCodes == rate48.qualityReasonCodes)
        #expect(rate44.usedAlternate == rate48.usedAlternate)
        #expect(rate44.usedFallback == rate48.usedFallback)
        #expect(rate44.usedHomeTimbreFallback == rate48.usedHomeTimbreFallback)
        #expect(rate44.routeFingerprint != rate48.routeFingerprint)
        #expect(rate44.sampleHash != rate48.sampleHash)
    }

    @inline(never)
    private func preparedRateProjection(
        sampleRate: Double
    ) throws -> PreparedRateProjection {
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
            sampleRate: sampleRate,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil
        )
        let fullMix = prepared.selectedCandidateEvidence.fullMix
        #expect(fullMix.loudnessStandard == BS1770LoudnessMeasurement.standard)
        #expect(fullMix.truePeakStandard == BS1770AudioEvidence.truePeakStandard)
        #expect(fullMix.analyzedFrameCount ==
                prepared.blocks.reduce(0) { $0 + min($1.left.count, $1.right.count) })
        #expect(prepared.commitEligible)

        let trajectory = prepared.selectedCandidateEvidence.automaticMix
            .sorted { $0.bar < $1.bar }
            .compactMap { evidence in
                evidence.gains.first {
                    $0.role == MixRole.kick.rawValue
                }?.gainDB
            }
        #expect(trajectory.count == candidates.primary.barCount)
        let first = try #require(trajectory.first)
        #expect(first < AutomaticMixBalancer.homeKickCorrectionDB)
        #expect(trajectory.allSatisfy {
            $0.isFinite && (AutomaticMixBalancer.minimumKickCorrectionDB...0).contains($0)
        })
        #expect(zip(trajectory, trajectory.dropFirst()).allSatisfy {
            abs($0.1 - $0.0) <= AutomaticMixBalancer.maximumStepDB + 0.000_000_1
        })
        #expect(prepared.selectedCandidateEvidence.routeContinuation.sampleRate == sampleRate)

        return PreparedRateProjection(
            fullMix: fullMix,
            plan: prepared.plan,
            engineVersion: prepared.candidateEvaluation.engineVersion,
            policyVersion: prepared.candidateEvaluation.policyVersion,
            evaluatorVersion: prepared.candidateEvaluation.evaluatorVersion,
            planFingerprints: prepared.candidateEvaluation.planFingerprints,
            selectedAttemptIndex: prepared.candidateEvaluation.selectedAttemptIndex,
            selectedSlot: prepared.candidateEvaluation.selectedSlot,
            comparison: prepared.candidateEvaluation.comparison,
            correctionCount: prepared.candidateEvaluation.correctionCount,
            attempts: prepared.candidateEvaluation.attempts.map(
                PreparedRateAttemptProjection.init
            ),
            qualityOutcome: prepared.qualityDecision.outcome,
            qualityReasonCodes: prepared.qualityDecision.reasonCodes,
            usedAlternate: prepared.usedAlternate,
            usedFallback: prepared.usedFallback,
            usedHomeTimbreFallback: prepared.usedHomeTimbreFallback,
            routeFingerprint: prepared.selectedCandidateEvidence
                .routeContinuation.routeFingerprint,
            sampleHash: prepared.audioPreflight.quality.sampleHash
        )
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

    private func closedHatCompanionFixture() -> ClosedHatCompanionFixtureBox? {
        for seed in 1...128 {
            if let fixture = closedHatCompanionFixture(seed: UInt64(seed)) {
                return fixture
            }
        }
        return nil
    }

    @inline(never)
    private func closedHatCompanionFixture(seed: UInt64) ->
        ClosedHatCompanionFixtureBox? {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        for _ in 0..<4 {
            let source = director.candidates(from: state)
            let candidates = AutonomousPhraseCandidates(
                primary: shortenedCandidate(
                    source.primary,
                    interest: source.primary.interest
                ),
                alternate: shortenedCandidate(
                    source.alternate,
                    interest: source.alternate.interest
                ),
                fallback: shortenedCandidate(
                    source.fallback,
                    interest: source.fallback.interest
                )
            )
            if source.primary.interest.valid,
               candidates.primary.resolvedBars.contains(where: { bar in
                   bar.closedHatDecayArticulations.contains {
                       $0.role == .openHatCompanion
                   }
               }) {
                return ClosedHatCompanionFixtureBox(
                    state: state,
                    candidates: candidates
                )
            }
            state.advance(using: source.primary)
        }
        return nil
    }

    private func planReplacingResolvedBars(
        in source: AutonomousPhrasePlan,
        with bars: [ResolvedPerformanceBar]
    ) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
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
            interest: source.interest,
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
        )
    }

    private func barReplacingClosedHatDecayArticulations(
        in resolved: ResolvedPerformanceBar,
        with articulations: [ClosedHatDecayArticulation]
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: resolved.ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            closedHatDecayArticulations: articulations,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
    }

    private func closedHatEvidence(
        replacing source: ClosedHatRenderEvidence,
        appliedDecayRate: Double
    ) -> ClosedHatRenderEvidence {
        ClosedHatRenderEvidence(
            scoreEventIndex: source.scoreEventIndex,
            step: source.step,
            role: source.role,
            eventIntensity: source.eventIntensity,
            timingOffsetInSteps: source.timingOffsetInSteps,
            relocated: source.relocated,
            appliedLevel: source.appliedLevel,
            appliedDecayRate: appliedDecayRate,
            renderedFrameCount: source.renderedFrameCount,
            sampleHash: source.sampleHash,
            peak: source.peak,
            rms: source.rms,
            attackRMS: source.attackRMS,
            tailRMS: source.tailRMS,
            tailToAttackDB: source.tailToAttackDB,
            spectralCentroidHz: source.spectralCentroidHz,
            finite: source.finite
        )
    }

    private func pulseEchoEvidence(
        replacing source: PulseEchoReturnDriveRenderEvidence,
        machineTexture: Double
    ) -> PulseEchoReturnDriveRenderEvidence {
        PulseEchoReturnDriveRenderEvidence(
            bar: source.bar,
            bpm: source.bpm,
            delayFrameCount: source.delayFrameCount,
            machineTexture: machineTexture,
            scoreEnabled: source.scoreEnabled,
            earliestPulseEchoOnsetStep:
                source.earliestPulseEchoOnsetStep,
            driveEligible: source.driveEligible,
            appliedAmount: source.appliedAmount,
            transitionFrameCount: source.transitionFrameCount,
            renderedFrameCount: source.renderedFrameCount,
            currentSendRMS: source.currentSendRMS,
            preDriveSampleHash: source.preDriveSampleHash,
            postDriveSampleHash: source.postDriveSampleHash,
            firstPreDriveSampleBitPattern:
                source.firstPreDriveSampleBitPattern,
            firstPostDriveSampleBitPattern:
                source.firstPostDriveSampleBitPattern,
            lastPreDriveSampleBitPattern:
                source.lastPreDriveSampleBitPattern,
            lastPostDriveSampleBitPattern:
                source.lastPostDriveSampleBitPattern,
            changedFrameIndex: source.changedFrameIndex,
            changedPreDriveSampleBitPattern:
                source.changedPreDriveSampleBitPattern,
            preDrivePeak: source.preDrivePeak,
            preDrivePeakFrameIndex: source.preDrivePeakFrameIndex,
            postDrivePeak: source.postDrivePeak,
            postDrivePeakFrameIndex: source.postDrivePeakFrameIndex,
            postDrivePeakPreDriveSample:
                source.postDrivePeakPreDriveSample,
            postDrivePeakEffectiveAmount:
                source.postDrivePeakEffectiveAmount,
            preDriveRMS: source.preDriveRMS,
            postDriveRMS: source.postDriveRMS,
            preDriveLowBandRMS: source.preDriveLowBandRMS,
            postDriveLowBandRMS: source.postDriveLowBandRMS,
            differenceRMS: source.differenceRMS,
            finite: source.finite
        )
    }

    private func renderBlock(
        replacing source: RenderBlock,
        closedHatRenderEvidence: [ClosedHatRenderEvidence]? = nil,
        pulseEchoReturnDriveRenderEvidence:
            PulseEchoReturnDriveRenderEvidence? = nil
    ) -> RenderBlock {
        RenderBlock(
            bar: source.bar,
            section: source.section,
            left: source.left,
            right: source.right,
            events: source.events,
            modulation: source.modulation,
            busStates: source.busStates,
            masking: source.masking,
            effects: source.effects,
            kickMix: source.kickMix,
            kickRenderPassesMatch: source.kickRenderPassesMatch,
            stemObservations: source.stemObservations,
            automaticMix: source.automaticMix,
            stemReconstruction: source.stemReconstruction,
            protectedFoundationSampleHash: source.protectedFoundationSampleHash,
            percussionSampleHash: source.percussionSampleHash,
            protectedRhythmSampleHash: source.protectedRhythmSampleHash,
            groovePulseRenderEvidence: source.groovePulseRenderEvidence,
            closedHatRenderEvidence:
                closedHatRenderEvidence ?? source.closedHatRenderEvidence,
            instrumentRenderEvidence: source.instrumentRenderEvidence,
            percussionEchoTextureRenderEvidence:
                source.percussionEchoTextureRenderEvidence,
            percussionEchoTextureRenderPassesMatch:
                source.percussionEchoTextureRenderPassesMatch,
            pulseEchoReturnDriveRenderEvidence:
                pulseEchoReturnDriveRenderEvidence ??
                    source.pulseEchoReturnDriveRenderEvidence,
            spatialFDNRenderEvidence: source.spatialFDNRenderEvidence,
            upperNoteRenderEvidence: source.upperNoteRenderEvidence,
            upperTimingRenderEvidence: source.upperTimingRenderEvidence,
            graphInputRemainderTimbreEvidence:
                source.graphInputRemainderTimbreEvidence,
            postGraphRemainderTimbreEvidence:
                source.postGraphRemainderTimbreEvidence,
            resolvedPerformance: source.resolvedPerformance,
            sceneDNA: source.sceneDNA,
            synthWorld: source.synthWorld,
            synthPerformance: source.synthPerformance
        )
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
                performanceCharacter: resolved.performanceCharacter,
                foundationBehavior: resolved.foundationBehavior,
                foundationCompanion: resolved.foundationCompanion,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                interlockChapter: resolved.interlockChapter,
                groovePulses: resolved.groovePulses,
                closedHatDecayArticulations: resolved.closedHatDecayArticulations,
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative,
                kickSyntaxRole: resolved.kickSyntaxRole
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
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
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
                closedHatDecayArticulations: resolved.closedHatDecayArticulations,
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
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
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
