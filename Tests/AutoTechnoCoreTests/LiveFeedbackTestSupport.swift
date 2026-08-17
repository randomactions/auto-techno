import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation

enum LiveFeedbackTestSupport {
    static let profileFingerprint = "1111111111111111"
    static let fingerprintQualifiedPolicyVersion = [
        ProfessionalQualityPrimaryEvaluator.policyFamilyVersion,
        "profile-\(profileFingerprint)",
        "adversarial-2222222222222222",
        "holdout-3333333333333333",
    ].joined(separator: ".")

    static func analyze(
        signal: [Float],
        plan: AutonomousPhrasePlan,
        sampleRate: Double,
        routeGeneration: Int = 3,
        controllerRevision: Int = 4,
        playerSampleRange: Range<Int64>? = nil,
        qualityPolicyVersion: String = fingerprintQualifiedPolicyVersion,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> LiveOutputWindowEvidence? {
        let range = playerSampleRange ??
            (80_000..<Int64(80_000 + signal.count))
        return LiveOutputWindowAnalyzer.analyze(
            left: signal,
            right: signal,
            planIdentity: LiveOutputPlanSourceIdentity(plan: plan),
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            playerSampleRange: range,
            sampleRate: sampleRate,
            captureProvenance: captureProvenance(
                frameCount: signal.count
            ),
            qualityPolicyVersion: qualityPolicyVersion,
            cancellationRequested: cancellationRequested
        )
    }

    static func target(
        evidence: LiveOutputWindowEvidence,
        selectedLoudnessCheckpoint: CanonicalJourneyCheckpoint? = nil,
        selectedTruePeakCheckpoint: CanonicalJourneyCheckpoint? = nil,
        loudnessLowerLUFS: Double? = nil,
        loudnessUpperLUFS: Double? = nil,
        truePeakLowerDBTP: Double? = nil,
        truePeakUpperDBTP: Double? = nil,
        profileFingerprint: String = LiveFeedbackTestSupport.profileFingerprint
    ) -> LiveMasterHeadroomTarget? {
        guard let firstCheckpoint = evidence.applicableCheckpoints.first else {
            return nil
        }
        let resolvedLoudnessLower = loudnessLowerLUFS ??
            evidence.maximumShortTermLoudnessLUFS - 2
        let resolvedLoudnessUpper = loudnessUpperLUFS ??
            evidence.maximumShortTermLoudnessLUFS + 1
        let resolvedTruePeakLower = truePeakLowerDBTP ??
            evidence.truePeakDBTP - 2
        let resolvedTruePeakUpper = truePeakUpperDBTP ??
            evidence.truePeakDBTP + 1
        let candidate = LiveMasterHeadroomTarget(
            schemaVersion: LiveMasterHeadroomTarget.schemaVersion,
            sourceObservationFingerprint: evidence.fingerprint,
            phraseIndex: evidence.phraseIndex,
            planFingerprint: evidence.planFingerprint,
            routeGeneration: evidence.routeGeneration,
            controllerRevision: evidence.controllerRevision,
            playerSampleRange: evidence.playerSampleRange,
            sampleRate: evidence.sampleRate,
            applicableCheckpoints: evidence.applicableCheckpoints,
            selectedLoudnessCheckpoint:
                selectedLoudnessCheckpoint ?? firstCheckpoint,
            selectedTruePeakCheckpoint:
                selectedTruePeakCheckpoint ?? firstCheckpoint,
            analyzerVersion: evidence.analyzerVersion,
            engineVersion: evidence.engineVersion,
            evidenceVersion: evidence.evidenceVersion,
            qualityPolicyVersion: evidence.qualityPolicyVersion,
            evaluatorVersion: evidence.evaluatorVersion,
            controllerPolicyVersion: evidence.controllerPolicyVersion,
            profileVersion:
                ProfessionalQualityPrimaryEvaluator.requiredProfileVersion,
            profileFingerprint: profileFingerprint,
            loudnessLowerLUFS: resolvedLoudnessLower,
            loudnessUpperLUFS: resolvedLoudnessUpper,
            loudnessMidpointLUFS:
                (resolvedLoudnessLower + resolvedLoudnessUpper) / 2,
            truePeakLowerDBTP: resolvedTruePeakLower,
            truePeakUpperDBTP: resolvedTruePeakUpper,
            truePeakMidpointDBTP:
                (resolvedTruePeakLower + resolvedTruePeakUpper) / 2
        )
        return candidate.isStructurallyValid(sourceEvidence: evidence)
            ? candidate
            : nil
    }

    static func captureProvenance(
        frameCount: Int
    ) -> LiveOutputCaptureProvenance {
        let packetCount = (frameCount + 1_023) / 1_024
        let firstSequence: UInt64 = 500
        return LiveOutputCaptureProvenance(
            packetCount: packetCount,
            firstPacketSequence: firstSequence,
            lastPacketSequence:
                firstSequence + UInt64(packetCount - 1),
            droppedPacketDelta: 0,
            rejectedPacketDelta: 0,
            queueCapacity: 256,
            maximumPacketFrameCount: 1_024,
            queueStorageByteCount:
                LiveOutputCaptureProvenance.requiredQueueStorageByteCount,
            consumerScratchByteCount:
                LiveOutputCaptureProvenance.requiredConsumerScratchByteCount,
            activeWindowByteCount:
                frameCount * 2 * MemoryLayout<Float>.stride,
            workingMemoryByteCount:
                LiveOutputCaptureProvenance.requiredQueueStorageByteCount +
                LiveOutputCaptureProvenance.requiredConsumerScratchByteCount +
                frameCount * 2 * MemoryLayout<Float>.stride,
            coveredFrameCount: frameCount,
            sampleDiscontinuityCount: 0,
            gapFrameCount: 0,
            overlapFrameCount: 0
        )
    }

    private struct CalibratedFixtureEvaluator:
            AutonomousCandidateEvaluating {
        let policyVersion = LiveFeedbackTestSupport
            .fingerprintQualifiedPolicyVersion
        let evaluatorVersion = ProfessionalQualityPrimaryEvaluator
            .evaluatorVersionIdentifier

        func requestsHomeUpperTimbreCorrection(
            for candidate: AutonomousCandidateEvaluationVector
        ) -> Bool { false }

        func terminalVerdict(
            selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction
        ) -> AutonomousCandidatePolicyVerdict {
            AutonomousCandidatePolicyVerdict(
                outcome: .qualified,
                reasonCodes: [.candidateQualifiedV1]
            )
        }
    }

    private struct PreparedLiveStep {
        let sourceState: AutonomousSessionState
        let prepared: PreparedAutonomousPhrase
        let scheduledOccurrence:
            ProfessionalQualityLiveScheduledOccurrenceEvidence
    }

    static func renderLiveTransitionCandidates() throws ->
        ProfessionalQualityLiveCandidateChain {
        let sampleRate = 44_100.0
        let routeGeneration = 11
        // Development-corpus seed 42 yields a real renderer/controller chain
        // with a chapter change at attenuation and contrast at recovery. Both
        // attacked baselines are therefore covered by calibrated source PCM.
        let director = AutonomousSessionDirector(rootSeed: 42)
        let initial = director.initialState()
        let neverCancelled: @Sendable () -> Bool = { false }
        let initialPlan = director.plan(from: initial)
        guard let home = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: initialPlan,
            sessionSeed: initial.rootSeed,
            memory: initial.memory,
            sampleRate: sampleRate,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: initial.quality,
            routeGeneration: routeGeneration,
            evaluator: CalibratedFixtureEvaluator(),
            cancellationRequested: neverCancelled
        ) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let homeOccurrence = try scheduledOccurrence(
            prepared: home,
            playerStartSample: 80_000,
            routeGeneration: routeGeneration,
            occurrenceEpoch: 1,
            sampleRate: sampleRate
        )
        let attenuation = try renderLiveTransitionCandidate(
            from: PreparedLiveStep(
                sourceState: initial,
                prepared: home,
                scheduledOccurrence: homeOccurrence
            ),
            expectedOutcome: .attenuate,
            director: director,
            routeGeneration: routeGeneration,
            sampleRate: sampleRate
        )
        let cleanHold = try renderLiveTransitionCandidate(
            from: attenuation.step,
            expectedOutcome: .hold,
            director: director,
            routeGeneration: routeGeneration,
            sampleRate: sampleRate
        )
        let recovery = try renderLiveTransitionCandidate(
            from: cleanHold.step,
            expectedOutcome: .recover,
            director: director,
            routeGeneration: routeGeneration,
            sampleRate: sampleRate
        )
        return try ProfessionalQualityLiveCandidateChain(
            attenuationTransition: attenuation.transition,
            cleanHoldTransition: cleanHold.transition,
            recoveryTransition: recovery.transition
        )
    }

    private static func renderLiveTransitionCandidate(
        from source: PreparedLiveStep,
        expectedOutcome: LiveFeedbackProposalOutcome,
        director: AutonomousSessionDirector,
        routeGeneration: Int,
        sampleRate: Double
    ) throws -> (
        step: PreparedLiveStep,
        transition: ProfessionalQualityLiveCandidateTransitionEvidence
    ) {
        let incomingLive = source.prepared
            .liveMasterHeadroomContinuationState
        let targetState = source.sourceState.advance(
            using: source.prepared.plan,
            quality: source.prepared.qualityContinuationState,
            liveMasterHeadroom: incomingLive
        )
        guard targetState.phraseIndex == source.sourceState.phraseIndex + 1 else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let targetPlan = director.plan(from: targetState)
        guard let frameCount = LiveOutputWindowAnalyzer.frameCount(
            sampleRate: sampleRate
        ) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let left = Array(
            source.prepared.blocks.flatMap(\.left).prefix(frameCount)
        )
        let right = Array(
            source.prepared.blocks.flatMap(\.right).prefix(frameCount)
        )
        let playerRange = source.scheduledOccurrence.capturePlayerSampleRange
        guard let evidence = LiveOutputWindowAnalyzer.analyze(
            left: left,
            right: right,
            planIdentity: LiveOutputPlanSourceIdentity(
                plan: source.prepared.plan
            ),
            routeGeneration: routeGeneration,
            controllerRevision: incomingLive.revision,
            playerSampleRange: playerRange,
            sampleRate: sampleRate,
            captureProvenance: captureProvenance(frameCount: frameCount),
            qualityPolicyVersion: fingerprintQualifiedPolicyVersion
        ) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let target: LiveMasterHeadroomTarget?
        switch expectedOutcome {
        case .unavailable:
            throw ProfessionalQualityCalibrationError.profileMismatch
        case .attenuate:
            target = Self.target(
                evidence: evidence,
                loudnessUpperLUFS:
                    evidence.maximumShortTermLoudnessLUFS - 1,
                truePeakUpperDBTP: evidence.truePeakDBTP - 1
            )
        case .hold:
            target = Self.target(
                evidence: evidence,
                loudnessLowerLUFS:
                    evidence.maximumShortTermLoudnessLUFS - 1,
                loudnessUpperLUFS:
                    evidence.maximumShortTermLoudnessLUFS + 1,
                truePeakLowerDBTP: evidence.truePeakDBTP - 1,
                truePeakUpperDBTP: evidence.truePeakDBTP + 1
            )
        case .recover:
            target = Self.target(
                evidence: evidence,
                loudnessLowerLUFS:
                    evidence.maximumShortTermLoudnessLUFS - 1,
                loudnessUpperLUFS:
                    evidence.maximumShortTermLoudnessLUFS + 3,
                truePeakLowerDBTP: evidence.truePeakDBTP - 1,
                truePeakUpperDBTP: evidence.truePeakDBTP + 3
            )
        }
        guard let target else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let earliest = source.scheduledOccurrence
            .earliestEligibleFutureSample
        let proposal = LiveMasterHeadroomController.propose(
            evidence: evidence,
            target: target,
            incoming: incomingLive,
            earliestEligibleFutureSample: earliest
        )
        guard proposal.outcome == expectedOutcome else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let binding = PendingLiveMasterHeadroomBinding(
            sourceIdentity: LiveOutputPlanSourceIdentity(
                plan: source.prepared.plan
            ),
            evidence: evidence,
            target: target,
            proposal: proposal,
            eligibleTarget: LiveMasterHeadroomEligibleTarget(
                plan: targetPlan,
                routeGeneration: routeGeneration,
                sampleRate: sampleRate,
                earliestEligibleFutureSample: earliest,
                qualityPolicyVersion: evidence.qualityPolicyVersion,
                evaluatorVersion: evidence.evaluatorVersion,
                controllerPolicyVersion: evidence.controllerPolicyVersion
            )
        )
        guard binding.isStructurallyValid(
            targetPlan: targetPlan,
            incoming: incomingLive
        ), let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: targetPlan,
            sessionSeed: targetState.rootSeed,
            memory: targetState.memory,
            sampleRate: sampleRate,
            incomingRenderState: source.prepared.endingRenderState,
            incomingGraphState: source.prepared.endingGraphState,
            previousGraph: source.prepared.graph,
            incomingQualityState: targetState.quality,
            routeGeneration: routeGeneration,
            pendingLiveMasterBinding: binding,
            liveTargetStartSample: earliest,
            evaluator: CalibratedFixtureEvaluator(),
            cancellationRequested: { false }
        ), prepared.selectedCandidateEvidence.isComplete else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let targetOccurrence = try scheduledOccurrence(
            prepared: prepared,
            playerStartSample: earliest,
            routeGeneration: routeGeneration,
            occurrenceEpoch: source.scheduledOccurrence.occurrenceEpoch,
            sampleRate: sampleRate
        )
        let transition = try ProfessionalQualityLiveCandidateTransitionEvidence(
            sourceOccurrence: source.scheduledOccurrence,
            captureEvidence: evidence,
            targetOccurrence: targetOccurrence,
            candidate: prepared.selectedCandidateEvidence
        )
        return (
            PreparedLiveStep(
                sourceState: targetState,
                prepared: prepared,
                scheduledOccurrence: targetOccurrence
            ),
            transition
        )
    }

    private static func scheduledOccurrence(
        prepared: PreparedAutonomousPhrase,
        playerStartSample: Int64,
        routeGeneration: Int,
        occurrenceEpoch: UInt64,
        sampleRate: Double
    ) throws -> ProfessionalQualityLiveScheduledOccurrenceEvidence {
        var frameCount: Int64 = 0
        for block in prepared.blocks {
            let frames = Int64(min(block.left.count, block.right.count))
            let next = frameCount.addingReportingOverflow(frames)
            guard frames > 0, !next.overflow else {
                throw ProfessionalQualityCalibrationError.profileMismatch
            }
            frameCount = next.partialValue
        }
        let playerEnd = playerStartSample.addingReportingOverflow(frameCount)
        guard playerStartSample >= 0, !playerEnd.overflow,
              let captureFrameCount = LiveOutputWindowAnalyzer.frameCount(
                sampleRate: sampleRate
              ) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let captureEnd = playerStartSample.addingReportingOverflow(
            Int64(captureFrameCount)
        )
        guard !captureEnd.overflow,
              captureEnd.partialValue <= playerEnd.partialValue else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let identity = LiveOutputPlanSourceIdentity(plan: prepared.plan)
        let liveState = prepared.liveMasterHeadroomContinuationState
        return ProfessionalQualityLiveScheduledOccurrenceEvidence(
            phraseIndex: prepared.plan.phraseIndex,
            planFingerprint: identity.planFingerprint,
            playerSampleRange: playerStartSample..<playerEnd.partialValue,
            capturePlayerSampleRange:
                playerStartSample..<captureEnd.partialValue,
            sampleRate: sampleRate,
            routeGeneration: routeGeneration,
            occurrenceEpoch: occurrenceEpoch,
            controllerRevision: liveState.revision,
            qualityPolicyVersion:
                prepared.qualityContinuationState.policyVersion,
            evaluatorVersion: ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier,
            controllerPolicyVersion: LiveFeedbackContract
                .controllerPolicyVersion,
            controllerStateFingerprint: prepared.selectedCandidateEvidence
                .routeContinuation.controllerStateFingerprint,
            appliedMasterTrimDB: liveState.committedTrimDB,
            applicableCheckpoints: identity.applicableCheckpoints,
            earliestEligibleFutureSample: playerEnd.partialValue
        )
    }
}
