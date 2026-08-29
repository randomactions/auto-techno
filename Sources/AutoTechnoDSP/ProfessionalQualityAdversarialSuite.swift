import AutoTechnoCore
import Foundation

package enum ProfessionalQualityAdversarialScenario: String, CaseIterable,
        Codable, Sendable {
    case hardGateCompensation = "hard-gate-compensation"
    case truePeakCompensation = "true-peak-compensation"
    case flattenedTrajectory = "flattened-trajectory"
    case spectralCollapse = "spectral-collapse"
    case maskingFlood = "masking-flood"
    case lowEndPhaseFailure = "low-end-phase-failure"
    case silentProxy = "silent-proxy"
    case foreignRate = "foreign-rate"
    case trajectoryFlattening = "trajectory-flattening"
    case rateDrift = "rate-drift"
    case modalDetuning = "modal-detuning"
    case modalRunawayTail = "modal-runaway-tail"
    case modalMaskingFlood = "modal-masking-flood"
    case modalRateDrift = "modal-rate-drift"
    case upperPercussionTailRegression =
        "upper-percussion-tail-regression"
    case upperSpectralRevealRunaway =
        "upper-spectral-reveal-runaway"
    case spectralHarmonicTailDisconnected =
        "spectral-harmonic-tail-disconnected"
    case percussionAnticipationSwellFlattened =
        "percussion-anticipation-swell-flattened"
    case padRhythmicModulationDisconnected =
        "pad-rhythmic-modulation-disconnected"
    case padRhythmicAmplitudeGateDisconnected =
        "pad-rhythmic-amplitude-gate-disconnected"
    case padHarmonicDisclosureOverpopulation =
        "pad-harmonic-disclosure-overpopulation"
    case foundationDottedRhythmOverpopulation =
        "foundation-dotted-rhythm-overpopulation"
    case foundationPreKickPocketContamination =
        "foundation-pre-kick-pocket-contamination"
    case climaxHangContamination = "climax-hang-contamination"
    case kickSourceTransientSpike = "kick-source-transient-spike"
    case forgedPreTerminalScaling = "forged-pre-terminal-scaling"
    case forgedPostTerminalScaling = "forged-post-terminal-scaling"
    case masterBoostAboveUnity = "master-boost-above-unity"
    case liveOverAttack = "live-over-attack"
    case liveEarlyRecovery = "live-early-recovery"
    case staleLiveRouteGeneration = "stale-live-route-generation"
    case liveEarlyBoundary = "live-early-boundary"
    case staleLiveControllerRevision = "stale-live-controller-revision"
    case unboundLiveProposalFingerprint =
        "unbound-live-proposal-fingerprint"
}

package struct ProfessionalQualityAdversarialCaseResult: Codable, Equatable,
        Sendable {
    package let scenario: ProfessionalQualityAdversarialScenario
    package let rejected: Bool
    package let expectedReasons: [ProfessionalQualityRejection]
    package let actualReasons: [ProfessionalQualityRejection]
    package let failedMetrics: [ProfessionalQualityMetric]

    package var passed: Bool {
        rejected && actualReasons == expectedReasons
    }
}

/// The non-reconstructable scheduling projection used by calibration mirrors
/// the App's `ScheduledPhraseRange`: one full accepted occurrence owns the
/// three-second capture at its onset and its upper bound is the sole eligible
/// start of the corrected successor.
package struct ProfessionalQualityLiveScheduledOccurrenceEvidence: Equatable,
        Sendable {
    package let phraseIndex: Int
    package let planFingerprint: String
    package let playerSampleRange: Range<Int64>
    package let capturePlayerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let routeGeneration: Int
    package let occurrenceEpoch: UInt64
    package let controllerRevision: Int
    package let qualityPolicyVersion: String
    package let evaluatorVersion: String
    package let controllerPolicyVersion: String
    package let controllerStateFingerprint: String
    package let appliedMasterTrimDB: Double
    package let applicableCheckpoints: [CanonicalJourneyCheckpoint]
    package let earliestEligibleFutureSample: Int64

    package init(
        phraseIndex: Int,
        planFingerprint: String,
        playerSampleRange: Range<Int64>,
        capturePlayerSampleRange: Range<Int64>,
        sampleRate: Double,
        routeGeneration: Int,
        occurrenceEpoch: UInt64,
        controllerRevision: Int,
        qualityPolicyVersion: String,
        evaluatorVersion: String,
        controllerPolicyVersion: String,
        controllerStateFingerprint: String,
        appliedMasterTrimDB: Double,
        applicableCheckpoints: [CanonicalJourneyCheckpoint],
        earliestEligibleFutureSample: Int64
    ) {
        self.phraseIndex = phraseIndex
        self.planFingerprint = planFingerprint
        self.playerSampleRange = playerSampleRange
        self.capturePlayerSampleRange = capturePlayerSampleRange
        self.sampleRate = sampleRate
        self.routeGeneration = routeGeneration
        self.occurrenceEpoch = occurrenceEpoch
        self.controllerRevision = controllerRevision
        self.qualityPolicyVersion = qualityPolicyVersion
        self.evaluatorVersion = evaluatorVersion
        self.controllerPolicyVersion = controllerPolicyVersion
        self.controllerStateFingerprint = controllerStateFingerprint
        self.appliedMasterTrimDB = appliedMasterTrimDB
        self.applicableCheckpoints = applicableCheckpoints
        self.earliestEligibleFutureSample = earliestEligibleFutureSample
    }

    package var isComplete: Bool {
        let occurrenceFrames = playerSampleRange.upperBound
            .subtractingReportingOverflow(playerSampleRange.lowerBound)
        let captureFrames = capturePlayerSampleRange.upperBound
            .subtractingReportingOverflow(capturePlayerSampleRange.lowerBound)
        guard !occurrenceFrames.overflow, !captureFrames.overflow,
              let requiredCaptureFrames = LiveOutputWindowAnalyzer.frameCount(
                sampleRate: sampleRate
              ) else { return false }
        return phraseIndex >= 0 && isFingerprint(planFingerprint) &&
            playerSampleRange.lowerBound >= 0 &&
            occurrenceFrames.partialValue >= Int64(requiredCaptureFrames) &&
            capturePlayerSampleRange.lowerBound ==
                playerSampleRange.lowerBound &&
            captureFrames.partialValue == Int64(requiredCaptureFrames) &&
            capturePlayerSampleRange.upperBound <=
                playerSampleRange.upperBound &&
            sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate &&
            sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate &&
            routeGeneration >= 0 && controllerRevision >= 0 &&
            LiveOutputWindowAnalyzer.isCurrentQualityPolicyVersion(
                qualityPolicyVersion
            ) &&
            evaluatorVersion == ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier &&
            controllerPolicyVersion ==
                LiveFeedbackContract.controllerPolicyVersion &&
            isFingerprint(controllerStateFingerprint) &&
            appliedMasterTrimDB.isFinite &&
            (-3...0).contains(appliedMasterTrimDB) &&
            !applicableCheckpoints.isEmpty &&
            Set(applicableCheckpoints).count == applicableCheckpoints.count &&
            earliestEligibleFutureSample == playerSampleRange.upperBound
    }

    private func isFingerprint(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

fileprivate final class ProfessionalQualityLiveCandidateStorage:
        Sendable {
    let value: AutonomousCandidateEvaluationVector

    init(_ value: AutonomousCandidateEvaluationVector) {
        self.value = value
    }
}

package struct ProfessionalQualityLiveCandidateTransitionEvidence: Equatable,
        Sendable {
    package let sourceOccurrence:
        ProfessionalQualityLiveScheduledOccurrenceEvidence
    package let captureEvidence: LiveOutputWindowEvidence
    package let targetOccurrence:
        ProfessionalQualityLiveScheduledOccurrenceEvidence
    fileprivate let candidateStorage: ProfessionalQualityLiveCandidateStorage

    package var candidate: AutonomousCandidateEvaluationVector {
        candidateStorage.value
    }

    package init(
        sourceOccurrence:
            ProfessionalQualityLiveScheduledOccurrenceEvidence,
        captureEvidence: LiveOutputWindowEvidence,
        targetOccurrence:
            ProfessionalQualityLiveScheduledOccurrenceEvidence,
        candidate: AutonomousCandidateEvaluationVector
    ) throws {
        self.sourceOccurrence = sourceOccurrence
        self.captureEvidence = captureEvidence
        self.targetOccurrence = targetOccurrence
        candidateStorage = ProfessionalQualityLiveCandidateStorage(candidate)
        guard isCausal else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
    }

    package var isCausal: Bool {
        guard sourceOccurrence.isComplete, targetOccurrence.isComplete,
              captureEvidence.isStructurallyValid,
              candidateStorage.value.isComplete,
              candidateStorage.value.isFinite,
              sourceOccurrence.phraseIndex < Int.max,
              let candidateKind = AutonomousPhraseKind(
                rawValue: candidateStorage.value.symbolic.phraseKind
              ) else { return false }
        let primaryTargetCheckpoint = CanonicalJourneyCheckpoint
            .primaryQualification(
                phraseIndex: candidateStorage.value.symbolic.phraseIndex,
                phraseKind: candidateKind,
                chapterChanged: candidateStorage.value.symbolic.chapterChanged
            )
        let expectedTargetCheckpoints = [
            primaryTargetCheckpoint ?? .longContinuation,
        ]
        let expectedSourceControllerFingerprint = AutonomousCandidateFingerprint
            .combinedController(
                kickCorrectionDB: candidateStorage.value.routeContinuation
                    .incomingKickCorrectionDB,
                liveMasterStateFingerprint: candidateStorage.value
                    .incomingLiveMasterStateFingerprint,
                proposalFingerprint: nil
            )
        guard captureEvidence.phraseIndex == sourceOccurrence.phraseIndex,
              captureEvidence.planFingerprint ==
                sourceOccurrence.planFingerprint,
              captureEvidence.playerSampleRange ==
                sourceOccurrence.capturePlayerSampleRange,
              captureEvidence.sampleRate == sourceOccurrence.sampleRate,
              captureEvidence.routeGeneration ==
                sourceOccurrence.routeGeneration,
              captureEvidence.controllerRevision ==
                sourceOccurrence.controllerRevision else { return false }
        guard captureEvidence.qualityPolicyVersion ==
                sourceOccurrence.qualityPolicyVersion,
              captureEvidence.evaluatorVersion ==
                sourceOccurrence.evaluatorVersion,
              captureEvidence.controllerPolicyVersion ==
                sourceOccurrence.controllerPolicyVersion,
              captureEvidence.applicableCheckpoints ==
                sourceOccurrence.applicableCheckpoints,
              sourceOccurrence.controllerStateFingerprint ==
                expectedSourceControllerFingerprint,
              candidateStorage.value.liveObservationFingerprint ==
                captureEvidence.fingerprint else { return false }
        guard targetOccurrence.phraseIndex ==
                sourceOccurrence.phraseIndex + 1,
              targetOccurrence.phraseIndex ==
                candidateStorage.value.symbolic.phraseIndex,
              targetOccurrence.planFingerprint ==
                candidateStorage.value.planFingerprint,
              targetOccurrence.applicableCheckpoints ==
                expectedTargetCheckpoints,
              targetOccurrence.playerSampleRange.lowerBound ==
                sourceOccurrence.playerSampleRange.upperBound,
              targetOccurrence.playerSampleRange.lowerBound ==
                sourceOccurrence.earliestEligibleFutureSample else {
            return false
        }
        guard candidateStorage.value.liveEarliestEligibleFutureSample ==
                sourceOccurrence.earliestEligibleFutureSample,
              candidateStorage.value.liveAppliedFutureSample ==
                targetOccurrence.playerSampleRange.lowerBound,
              sourceOccurrence.controllerRevision ==
                candidateStorage.value.incomingLiveMasterRevision,
              targetOccurrence.controllerRevision ==
                candidateStorage.value.outgoingLiveMasterRevision,
              sourceOccurrence.appliedMasterTrimDB ==
                candidateStorage.value.incomingLiveMasterTrimDB,
              targetOccurrence.appliedMasterTrimDB ==
                candidateStorage.value.appliedLiveMasterTrimDB else {
            return false
        }
        guard targetOccurrence.controllerStateFingerprint ==
                candidateStorage.value.routeContinuation
                    .controllerStateFingerprint,
              sourceOccurrence.sampleRate == targetOccurrence.sampleRate,
              sourceOccurrence.sampleRate ==
                candidateStorage.value.routeContinuation.sampleRate,
              sourceOccurrence.routeGeneration ==
                targetOccurrence.routeGeneration,
              sourceOccurrence.routeGeneration ==
                candidateStorage.value.routeContinuation.routeGeneration,
              sourceOccurrence.occurrenceEpoch ==
                targetOccurrence.occurrenceEpoch else { return false }
        return sourceOccurrence.qualityPolicyVersion ==
                targetOccurrence.qualityPolicyVersion &&
            sourceOccurrence.evaluatorVersion ==
                targetOccurrence.evaluatorVersion &&
            sourceOccurrence.controllerPolicyVersion ==
                targetOccurrence.controllerPolicyVersion
    }

    package static func == (
        lhs: ProfessionalQualityLiveCandidateTransitionEvidence,
        rhs: ProfessionalQualityLiveCandidateTransitionEvidence
    ) -> Bool {
        lhs.sourceOccurrence == rhs.sourceOccurrence &&
            lhs.captureEvidence == rhs.captureEvidence &&
            lhs.targetOccurrence == rhs.targetOccurrence &&
            lhs.candidateStorage.value == rhs.candidateStorage.value
    }
}

package struct ProfessionalQualityLiveCandidateChain: Equatable, Sendable {
    package let attenuationTransition:
        ProfessionalQualityLiveCandidateTransitionEvidence
    package let cleanHoldTransition:
        ProfessionalQualityLiveCandidateTransitionEvidence
    package let recoveryTransition:
        ProfessionalQualityLiveCandidateTransitionEvidence

    package var attenuation: AutonomousCandidateEvaluationVector {
        attenuationTransition.candidate
    }
    package var cleanHold: AutonomousCandidateEvaluationVector {
        cleanHoldTransition.candidate
    }
    package var recovery: AutonomousCandidateEvaluationVector {
        recoveryTransition.candidate
    }

    package init(
        attenuationTransition:
            ProfessionalQualityLiveCandidateTransitionEvidence,
        cleanHoldTransition:
            ProfessionalQualityLiveCandidateTransitionEvidence,
        recoveryTransition:
            ProfessionalQualityLiveCandidateTransitionEvidence
    ) throws {
        self.attenuationTransition = attenuationTransition
        self.cleanHoldTransition = cleanHoldTransition
        self.recoveryTransition = recoveryTransition
        guard isCausal else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
    }

    package var isCausal: Bool {
        guard attenuationTransition.isCausal,
              cleanHoldTransition.isCausal,
              recoveryTransition.isCausal,
              attenuationTransition.targetOccurrence ==
                cleanHoldTransition.sourceOccurrence,
              cleanHoldTransition.targetOccurrence ==
                recoveryTransition.sourceOccurrence else { return false }
        guard attenuationTransition.candidateStorage.value.isComplete,
              attenuationTransition.candidateStorage.value.isFinite,
              attenuationTransition.candidateStorage.value
                .liveAppliedFutureSample != nil,
              attenuationTransition.candidateStorage.value
                .liveProposalFingerprint != nil,
              attenuationTransition.candidateStorage.value
                .liveProposalOutcome ==
                .attenuate,
              attenuationTransition.candidateStorage.value
                .outgoingLiveMasterCleanWindowCount == 0
        else { return false }
        guard cleanHoldTransition.candidateStorage.value.isComplete,
              cleanHoldTransition.candidateStorage.value.isFinite,
              cleanHoldTransition.candidateStorage.value
                .liveAppliedFutureSample != nil,
              cleanHoldTransition.candidateStorage.value
                .liveProposalFingerprint != nil,
              cleanHoldTransition.candidateStorage.value
                .liveProposalOutcome == .hold,
              cleanHoldTransition.candidateStorage.value
                .incomingLiveMasterCleanWindowCount == 0,
              cleanHoldTransition.candidateStorage.value
                .outgoingLiveMasterCleanWindowCount == 1,
              attenuationTransition.candidateStorage.value
                .outgoingLiveMasterStateFingerprint ==
                cleanHoldTransition.candidateStorage.value
                    .incomingLiveMasterStateFingerprint,
              attenuationTransition.candidateStorage.value
                .outgoingLiveMasterRevision ==
                cleanHoldTransition.candidateStorage.value
                    .incomingLiveMasterRevision,
              cleanHoldTransition.candidateStorage.value
                .incomingLiveMasterTrimDB ==
                attenuationTransition.candidateStorage.value
                    .appliedLiveMasterTrimDB else {
            return false
        }
        guard recoveryTransition.candidateStorage.value.isComplete,
              recoveryTransition.candidateStorage.value.isFinite,
              recoveryTransition.candidateStorage.value
                .liveAppliedFutureSample != nil,
              recoveryTransition.candidateStorage.value
                .liveProposalFingerprint != nil,
              recoveryTransition.candidateStorage.value
                .liveProposalOutcome == .recover,
              recoveryTransition.candidateStorage.value
                .incomingLiveMasterCleanWindowCount == 1,
              recoveryTransition.candidateStorage.value
                .outgoingLiveMasterCleanWindowCount == 0,
              cleanHoldTransition.candidateStorage.value
                .outgoingLiveMasterStateFingerprint ==
                recoveryTransition.candidateStorage.value
                    .incomingLiveMasterStateFingerprint,
              cleanHoldTransition.candidateStorage.value
                .outgoingLiveMasterRevision ==
                recoveryTransition.candidateStorage.value
                    .incomingLiveMasterRevision,
              recoveryTransition.candidateStorage.value
                .incomingLiveMasterTrimDB ==
                cleanHoldTransition.candidateStorage.value
                    .appliedLiveMasterTrimDB else {
            return false
        }
        guard attenuationTransition.candidateStorage.value.symbolic
                .phraseIndex < Int.max,
              cleanHoldTransition.candidateStorage.value.symbolic.phraseIndex <
                Int.max else {
            return false
        }
        return attenuationTransition.candidateStorage.value.symbolic
                .phraseIndex + 1 ==
                cleanHoldTransition.candidateStorage.value.symbolic
                    .phraseIndex &&
            cleanHoldTransition.candidateStorage.value.symbolic.phraseIndex +
                1 == recoveryTransition.candidateStorage.value.symbolic
                    .phraseIndex
    }
}

/// A deterministic attack on the calibrated policy surface. The suite stores
/// only reason-coded outcomes, not the source observations or reconstructable
/// evidence. Every scenario must be rejected independently.
package struct ProfessionalQualityAdversarialSuiteReport: Codable, Equatable,
        Sendable {
    package static let schemaVersion = 17
    package static let suiteVersion =
        "autotechno-professional-quality-adversarial.v17"

    package let schemaVersion: Int
    package let suiteVersion: String
    package let profileFingerprint: String
    package let sourceObservationCount: Int
    package let baselineAcceptanceCount: Int
    package let liveBaselineAcceptanceCount: Int
    package let liveBaselineObservationFingerprints: [String]
    package let cases: [ProfessionalQualityAdversarialCaseResult]

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        sourceObservations: [ProfessionalQualityObservation],
        liveCandidateChain: ProfessionalQualityLiveCandidateChain
    ) throws {
        let expectedSourceObservationCount = profile.checkpoints.first
            .map { $0.sourceObservationCount *
                CanonicalJourneyCheckpoint.allCases.count } ?? 0
        guard profile.isComplete, !profile.fingerprint.isEmpty,
              sourceObservations.count == expectedSourceObservationCount,
              sourceObservations.allSatisfy({
                  ProfessionalQualityProfileEvaluator.evaluate(
                      $0, against: profile
                  ).accepted
              }) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        guard let baseline = sourceObservations.first(where: {
            $0.sampleRate == 48_000 && $0.checkpoint == .establishment
        }) else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }

        var generated: [ProfessionalQualityAdversarialCaseResult] = []
        func append(
            _ scenario: ProfessionalQualityAdversarialScenario,
            observation: ProfessionalQualityObservation,
            expected: [ProfessionalQualityRejection]
        ) {
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                observation, against: profile
            )
            generated.append(ProfessionalQualityAdversarialCaseResult(
                scenario: scenario,
                rejected: !verdict.accepted,
                expectedReasons: expected.sorted { $0.rawValue < $1.rawValue },
                actualReasons: verdict.reasons,
                failedMetrics: verdict.failedMetrics
            ))
        }
        func outside(
            _ metric: ProfessionalQualityMetric,
            preferLower: Bool
        ) throws -> Double {
            guard let localBounds = profile[baseline.checkpoint]?[metric] else {
                throw ProfessionalQualityCalibrationError.invalidMetricSet
            }
            let localDistance = max(
                1e-9,
                abs(localBounds.upper - localBounds.lower) * 0.1
            )
            let localOutside = preferLower
                ? localBounds.lower - localDistance
                : localBounds.upper + localDistance
            guard let bounds = profile.effectiveBounds(
                for: metric,
                at: baseline.checkpoint,
                observedValue: localOutside
            ) else {
                throw ProfessionalQualityCalibrationError.invalidMetricSet
            }
            let distance = max(1e-9, abs(bounds.upper - bounds.lower) * 0.1)
            return preferLower ? bounds.lower - distance : bounds.upper + distance
        }
        func identityCopy(
            sampleRate: Double = baseline.sampleRate,
            hardGatesPassed: Bool = true,
            metrics: [ProfessionalQualityMetricValue]? = nil
        ) throws -> ProfessionalQualityObservation {
            try ProfessionalQualityObservation(
                engineVersion: baseline.engineVersion,
                evidenceVersion: baseline.evidenceVersion,
                checkpoint: baseline.checkpoint,
                sampleRate: sampleRate,
                hardGatesPassed: hardGatesPassed,
                liveMaster: baseline.liveMaster,
                metrics: metrics ?? baseline.metrics
            )
        }

        append(
            .hardGateCompensation,
            observation: try identityCopy(hardGatesPassed: false),
            expected: [.hardGateFailure]
        )
        append(
            .truePeakCompensation,
            observation: try baseline.replacing(
                .truePeakDBTP,
                with: outside(.truePeakDBTP, preferLower: false)
            ),
            expected: [.metricOutOfRange]
        )
        func acceptedObservation(
            candidate: AutonomousCandidateEvaluationVector
        ) throws -> ProfessionalQualityObservation {
            guard let kind = AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ) else {
                throw ProfessionalQualityCalibrationError.profileMismatch
            }
            let checkpoints = CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: kind,
                chapterChanged: candidate.symbolic.chapterChanged
            )
            for checkpoint in checkpoints {
                let observation = try ProfessionalQualityObservation(
                    candidate: candidate,
                    engineVersion: baseline.engineVersion,
                    checkpoint: checkpoint
                )
                if ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                ).accepted {
                    return observation
                }
            }
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let attenuationObservation = try acceptedObservation(
            candidate: liveCandidateChain.attenuation
        )
        let recoveryObservation = try acceptedObservation(
            candidate: liveCandidateChain.recovery
        )
        let validLiveAttack = attenuationObservation.liveMaster
        let validLiveRecovery = recoveryObservation.liveMaster
        guard validLiveAttack.proposalOutcome == .attenuate,
              validLiveRecovery.proposalOutcome == .recover else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let acceptedLiveBaselines = [
            attenuationObservation,
            recoveryObservation,
        ]
        guard acceptedLiveBaselines.allSatisfy({ observation in
            ProfessionalQualityProfileEvaluator.evaluate(
                observation, against: profile
            ).accepted
        }) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        append(
            .forgedPreTerminalScaling,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.forgedPreTerminalScaling)
            ),
            expected: [.liveTerminalScalingFailure]
        )
        append(
            .forgedPostTerminalScaling,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.forgedPostTerminalScaling)
            ),
            expected: [.liveTerminalScalingFailure]
        )
        append(
            .masterBoostAboveUnity,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.boostAboveUnity)
            ),
            // A gain above unity necessarily breaks exact terminal scaling.
            expected: [.liveBoostRejected, .liveTerminalScalingFailure]
        )
        append(
            .liveOverAttack,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.overAttack)
            ),
            // Changing only applied trim necessarily also breaks requested
            // trim/gain equality while proving the transition slew gate.
            expected: [
                .liveTerminalScalingFailure,
                .liveTransitionOutOfBounds,
            ]
        )
        append(
            .liveEarlyRecovery,
            observation: try recoveryObservation.replacingLiveMaster(
                validLiveRecovery.attacked(.earlyRecovery)
            ),
            expected: [.liveEarlyRecovery]
        )
        append(
            .staleLiveRouteGeneration,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.staleRouteGeneration)
            ),
            expected: [.liveRouteBoundaryFailure]
        )
        append(
            .liveEarlyBoundary,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.earlyBoundary)
            ),
            expected: [.liveRouteBoundaryFailure]
        )
        append(
            .staleLiveControllerRevision,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.staleControllerRevision)
            ),
            expected: [.liveControllerMismatch]
        )
        append(
            .unboundLiveProposalFingerprint,
            observation: try attenuationObservation.replacingLiveMaster(
                validLiveAttack.attacked(.unboundProposalFingerprint)
            ),
            expected: [.liveProposalMismatch]
        )

        let trajectoryCheckpoint = try Self.checkpointWithLargestLowerBound(
            metric: .movementScore,
            profile: profile
        )
        let trajectoryBaseline = try Self.baseline(
            checkpoint: trajectoryCheckpoint,
            observations: sourceObservations
        )
        guard let trajectoryBounds = profile[trajectoryCheckpoint]?[.movementScore],
              trajectoryBounds.lower > 0 else {
            throw ProfessionalQualityCalibrationError.invalidBounds
        }
        append(
            .flattenedTrajectory,
            observation: try trajectoryBaseline.replacing(
                .movementScore,
                with: trajectoryBounds.lower - max(1e-9,
                    trajectoryBounds.lower * 0.1)
            ),
            expected: [.metricOutOfRange]
        )

        append(
            .spectralCollapse,
            observation: try baseline.replacing(
                .spectralCentroidMeanHz,
                with: outside(.spectralCentroidMeanHz, preferLower: true)
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .maskingFlood,
            observation: try baseline.replacing(
                .maskingMaximumOverlap,
                with: outside(.maskingMaximumOverlap, preferLower: false)
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .lowEndPhaseFailure,
            observation: try baseline.replacing(
                .lowStereoCorrelation,
                with: outside(.lowStereoCorrelation, preferLower: true)
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .modalDetuning,
            observation: try baseline.replacing(
                .modalPercussionPitchErrorCentsMaximum,
                with: outside(
                    .modalPercussionPitchErrorCentsMaximum,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .modalRunawayTail,
            observation: try baseline.replacing(
                .modalPercussionTailToBodyDBMean,
                with: outside(
                    .modalPercussionTailToBodyDBMean,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .modalMaskingFlood,
            observation: try baseline.replacing(
                .modalPercussionMaskingMaximumOverlap,
                with: outside(
                    .modalPercussionMaskingMaximumOverlap,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .upperPercussionTailRegression,
            observation: try baseline.replacing(
                .upperPercussionTailRenderedTailToAttackDBMean,
                with: outside(
                    .upperPercussionTailRenderedTailToAttackDBMean,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .upperSpectralRevealRunaway,
            observation: try baseline.replacing(
                .upperSpectralRevealAppliedCutoffRatioMean,
                with: outside(
                    .upperSpectralRevealAppliedCutoffRatioMean,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        let harmonicTailCheckpoint = try Self.checkpointWithLargestLowerBound(
            metric: .spectralHarmonicTailUpperBandEnergyRatioMean,
            profile: profile
        )
        let harmonicTailBaseline = try Self.baseline(
            checkpoint: harmonicTailCheckpoint,
            observations: sourceObservations
        )
        guard let harmonicTailBounds = profile[harmonicTailCheckpoint]?[
            .spectralHarmonicTailUpperBandEnergyRatioMean
        ], harmonicTailBounds.lower > 0 else {
            throw ProfessionalQualityCalibrationError.invalidBounds
        }
        append(
            .spectralHarmonicTailDisconnected,
            observation: try harmonicTailBaseline.replacing(
                .spectralHarmonicTailUpperBandEnergyRatioMean,
                with: max(
                    0,
                    harmonicTailBounds.lower - max(
                        1e-9,
                        harmonicTailBounds.lower * 0.5
                    )
                )
            ),
            expected: [.metricOutOfRange]
        )
        let releaseBaseline = try Self.baseline(
            checkpoint: .release,
            observations: sourceObservations
        )
        append(
            .climaxHangContamination,
            observation: try releaseBaseline.replacing(
                .climaxHangSilenceRMSMaximum,
                with: outside(
                    .climaxHangSilenceRMSMaximum,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        guard let anticipationBounds = profile[.release]?[
            .percussionAnticipationSwellLateToEarlyDBMean
        ] else {
            throw ProfessionalQualityCalibrationError.invalidMetricSet
        }
        append(
            .percussionAnticipationSwellFlattened,
            observation: try releaseBaseline.replacing(
                .percussionAnticipationSwellLateToEarlyDBMean,
                with: anticipationBounds.lower - max(
                    1e-9,
                    abs(anticipationBounds.upper - anticipationBounds.lower) *
                        0.1
                )
            ),
            expected: [.metricOutOfRange]
        )
        let majorBreakBaseline = try Self.baseline(
            checkpoint: .majorBreak,
            observations: sourceObservations
        )
        guard let padRhythmBounds = profile[.majorBreak]?[
            .padRhythmicFilterDifferenceToPadDBMean
        ], padRhythmBounds.lower > -120 else {
            throw ProfessionalQualityCalibrationError.invalidMetricSet
        }
        append(
            .padRhythmicModulationDisconnected,
            observation: try majorBreakBaseline.replacing(
                .padRhythmicFilterDifferenceToPadDBMean,
                with: max(-120, padRhythmBounds.lower - max(
                    1,
                    abs(padRhythmBounds.upper - padRhythmBounds.lower) * 0.1
                ))
            ),
            expected: [.metricOutOfRange]
        )
        guard let padAmplitudeGateBounds = profile[.majorBreak]?[
            .padRhythmicAmplitudeGateDifferenceToPadDBMean
        ], padAmplitudeGateBounds.lower > -120 else {
            throw ProfessionalQualityCalibrationError.invalidMetricSet
        }
        append(
            .padRhythmicAmplitudeGateDisconnected,
            observation: try majorBreakBaseline.replacing(
                .padRhythmicAmplitudeGateDifferenceToPadDBMean,
                with: max(-120, padAmplitudeGateBounds.lower - max(
                    1,
                    abs(
                        padAmplitudeGateBounds.upper -
                            padAmplitudeGateBounds.lower
                    ) * 0.1
                ))
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .padHarmonicDisclosureOverpopulation,
            observation: try majorBreakBaseline.replacing(
                .padHarmonicDisclosureDistinctFunctionCount,
                with: Double(PadHarmonicFunction.allCases.count + 1)
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .foundationDottedRhythmOverpopulation,
            observation: try baseline.replacing(
                .foundationDottedRhythmActiveBarRatio,
                with: outside(
                    .foundationDottedRhythmActiveBarRatio,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .foundationPreKickPocketContamination,
            observation: try baseline.replacing(
                .foundationPreKickPocketSilenceRMSMaximum,
                with: outside(
                    .foundationPreKickPocketSilenceRMSMaximum,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )
        append(
            .kickSourceTransientSpike,
            observation: try baseline.replacing(
                .kickSourceOutputCrestFactorDBMean,
                with: outside(
                    .kickSourceOutputCrestFactorDBMean,
                    preferLower: false
                )
            ),
            expected: [.metricOutOfRange]
        )

        var silenceMetrics = baseline.metrics
        let silentValues: [ProfessionalQualityMetric: Double] = [
            .integratedLoudnessLUFS: -120,
            .maximumMomentaryLoudnessLUFS: -120,
            .maximumShortTermLoudnessLUFS: -120,
            .activeWindowRatio: 0,
            .movementScore: 0,
            .spectralCentroidMeanHz: 0,
            .spectralCentroidSpreadHz: 0,
            .spectralBandwidthMeanHz: 0,
            .spectralRolloff85MeanHz: 0,
            .positiveSpectralFluxMean: 0,
            .positiveSpectralFluxPeak: 0,
            .rmsTrajectoryDeltaMeanDB: 0,
            .rmsTrajectoryDeltaPeakDB: 0,
        ]
        silenceMetrics = silenceMetrics.map { value in
            silentValues[value.metric].map {
                ProfessionalQualityMetricValue(metric: value.metric, value: $0)
            } ?? value
        }
        append(
            .silentProxy,
            observation: try identityCopy(metrics: silenceMetrics),
            expected: [.metricOutOfRange]
        )
        append(
            .foreignRate,
            observation: try identityCopy(sampleRate: 96_000),
            expected: [.profileMismatch]
        )
        let trajectoryAttack = try Self.trajectoryAttack(
            profile: profile,
            observations: sourceObservations
        )
        let trajectoryFailures = ProfessionalQualityRelationshipEvaluator
            .evaluate(observations: trajectoryAttack, against: profile)
            .filter { $0.kind == .trajectory }
        generated.append(ProfessionalQualityAdversarialCaseResult(
            scenario: .trajectoryFlattening,
            rejected: !trajectoryFailures.isEmpty,
            expectedReasons: [.trajectoryRelationshipFailed],
            actualReasons: trajectoryFailures.isEmpty
                ? [] : [.trajectoryRelationshipFailed],
            failedMetrics: Array(Set(trajectoryFailures.map(\.metric)))
                .sorted { $0.rawValue < $1.rawValue }
        ))

        let rateAttack = try Self.rateAttack(
            profile: profile,
            observations: sourceObservations
        )
        let rateFailures = ProfessionalQualityRelationshipEvaluator
            .evaluate(observations: rateAttack, against: profile)
            .filter { $0.kind == .rateConsistency }
        generated.append(ProfessionalQualityAdversarialCaseResult(
            scenario: .rateDrift,
            rejected: !rateFailures.isEmpty,
            expectedReasons: [.rateConsistencyFailed],
            actualReasons: rateFailures.isEmpty ? [] : [.rateConsistencyFailed],
            failedMetrics: Array(Set(rateFailures.map(\.metric)))
                .sorted { $0.rawValue < $1.rawValue }
        ))

        let modalRateAttack = try Self.rateAttack(
            metric: .modalPercussionSpectralCentroidMeanHz,
            profile: profile,
            observations: sourceObservations
        )
        let modalRateFailures = ProfessionalQualityRelationshipEvaluator
            .evaluate(observations: modalRateAttack, against: profile)
            .filter {
                $0.kind == .rateConsistency &&
                    $0.metric == .modalPercussionSpectralCentroidMeanHz
            }
        generated.append(ProfessionalQualityAdversarialCaseResult(
            scenario: .modalRateDrift,
            rejected: !modalRateFailures.isEmpty,
            expectedReasons: [.rateConsistencyFailed],
            actualReasons: modalRateFailures.isEmpty
                ? [] : [.rateConsistencyFailed],
            failedMetrics: [.modalPercussionSpectralCentroidMeanHz]
        ))

        schemaVersion = Self.schemaVersion
        suiteVersion = Self.suiteVersion
        profileFingerprint = profile.fingerprint
        sourceObservationCount = sourceObservations.count
        baselineAcceptanceCount = sourceObservations.count
        liveBaselineAcceptanceCount = acceptedLiveBaselines.count
        liveBaselineObservationFingerprints = try acceptedLiveBaselines.map {
            guard let json = String(
                data: try $0.deterministicJSON(),
                encoding: .utf8
            ) else {
                throw ProfessionalQualityCalibrationError.profileMismatch
            }
            var sink = StreamingFNV1a()
            sink.domain("professional-quality-live-baseline.v1")
            sink.string(json)
            return fixedWidthFingerprintHex(sink.value)
        }
        cases = generated.sorted { $0.scenario.rawValue < $1.scenario.rawValue }
    }

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        sourceCorpus: ProfessionalQualityCalibrationCorpus,
        liveCandidateChain: ProfessionalQualityLiveCandidateChain
    ) throws {
        guard profile.usesDiverseCalibration,
              sourceCorpus.isComplete,
              sourceCorpus.sourceTrajectoryCount ==
                profile.sourceTrajectoryCount,
              sourceCorpus.fingerprint == profile.sourceBankFingerprint,
              sourceCorpus.trajectories.allSatisfy({ trajectory in
                  ProfessionalQualityRelationshipEvaluator.evaluate(
                      observations: trajectory.observations,
                      against: profile
                  ).isEmpty
              }) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        try self.init(
            profile: profile,
            sourceObservations: sourceCorpus.observations,
            liveCandidateChain: liveCandidateChain
        )
    }

    package var passed: Bool {
        return schemaVersion == Self.schemaVersion &&
            suiteVersion == Self.suiteVersion &&
            !profileFingerprint.isEmpty && sourceObservationCount > 0 &&
            baselineAcceptanceCount == sourceObservationCount &&
            liveBaselineAcceptanceCount == 2 &&
            liveBaselineObservationFingerprints.count == 2 &&
            Set(liveBaselineObservationFingerprints).count == 2 &&
            liveBaselineObservationFingerprints.allSatisfy { !$0.isEmpty } &&
            cases.count == ProfessionalQualityAdversarialScenario.allCases.count &&
            cases.map(\.scenario) == ProfessionalQualityAdversarialScenario
                .allCases.sorted { $0.rawValue < $1.rawValue } &&
            cases.allSatisfy(\.passed)
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    package static func decodeDeterministicJSON(
        _ data: Data
    ) throws -> ProfessionalQualityAdversarialSuiteReport {
        let decoded = try JSONDecoder().decode(
            ProfessionalQualityAdversarialSuiteReport.self,
            from: data
        )
        guard decoded.passed,
              try decoded.deterministicJSON() == data else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return decoded
    }

    package var fingerprint: String {
        guard let data = try? deterministicJSON(),
              let string = String(data: data, encoding: .utf8) else { return "" }
        var sink = StreamingFNV1a()
        sink.domain("professional-quality-adversarial-suite-json.v4")
        sink.string(string)
        return fixedWidthFingerprintHex(sink.value)
    }

    private static func checkpointWithLargestLowerBound(
        metric: ProfessionalQualityMetric,
        profile: ProfessionalQualityCalibrationProfile
    ) throws -> CanonicalJourneyCheckpoint {
        guard let result = profile.checkpoints.compactMap({ checkpoint in
            checkpoint[metric].map { (checkpoint.checkpoint, $0.lower) }
        }).max(by: { $0.1 < $1.1 }) else {
            throw ProfessionalQualityCalibrationError.invalidMetricSet
        }
        return result.0
    }

    private static func baseline(
        checkpoint: CanonicalJourneyCheckpoint,
        observations: [ProfessionalQualityObservation]
    ) throws -> ProfessionalQualityObservation {
        guard let observation = observations.first(where: {
            $0.checkpoint == checkpoint && $0.sampleRate == 48_000
        }) else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }
        return observation
    }

    private static func trajectoryAttack(
        profile: ProfessionalQualityCalibrationProfile,
        observations: [ProfessionalQualityObservation]
    ) throws -> [ProfessionalQualityObservation] {
        for relation in profile.trajectories {
            let pair = relation.trajectory.checkpoints
            guard let fromIndex = observations.firstIndex(where: {
                $0.sampleRate == 48_000 && $0.checkpoint == pair.from
            }), let toIndex = observations.firstIndex(where: {
                $0.sampleRate == 48_000 && $0.checkpoint == pair.to
            }), let fromBounds = profile[pair.from]?[relation.metric],
                  let toBounds = profile[pair.to]?[relation.metric] else {
                continue
            }
            let candidatePairs = [
                (fromBounds.lower, toBounds.upper),
                (fromBounds.upper, toBounds.lower),
            ]
            for (fromValue, toValue) in candidatePairs {
                var mutated = observations
                mutated[fromIndex] = try mutated[fromIndex].replacing(
                    relation.metric, with: fromValue
                )
                mutated[toIndex] = try mutated[toIndex].replacing(
                    relation.metric, with: toValue
                )
                let locallyAccepted = [fromIndex, toIndex].allSatisfy {
                    ProfessionalQualityProfileEvaluator.evaluate(
                        mutated[$0], against: profile
                    ).accepted
                }
                let relationshipFailed = ProfessionalQualityRelationshipEvaluator
                    .evaluate(observations: mutated, against: profile)
                    .contains {
                        $0.kind == .trajectory &&
                            $0.trajectory == relation.trajectory &&
                            $0.metric == relation.metric
                    }
                if locallyAccepted && relationshipFailed { return mutated }
            }
        }
        throw ProfessionalQualityCalibrationError.invalidBounds
    }

    private static func rateAttack(
        profile: ProfessionalQualityCalibrationProfile,
        observations: [ProfessionalQualityObservation]
    ) throws -> [ProfessionalQualityObservation] {
        for rateBound in profile.rateConsistency {
            guard let lowIndex = observations.firstIndex(where: {
                $0.sampleRate == profile.sampleRates[0] &&
                    $0.checkpoint == rateBound.checkpoint
            }), let highIndex = observations.firstIndex(where: {
                $0.sampleRate == profile.sampleRates[1] &&
                    $0.checkpoint == rateBound.checkpoint
            }), let metricBounds = profile[rateBound.checkpoint]?[rateBound.metric]
            else { continue }
            var mutated = observations
            mutated[lowIndex] = try mutated[lowIndex].replacing(
                rateBound.metric, with: metricBounds.lower
            )
            mutated[highIndex] = try mutated[highIndex].replacing(
                rateBound.metric, with: metricBounds.upper
            )
            let locallyAccepted = [lowIndex, highIndex].allSatisfy {
                ProfessionalQualityProfileEvaluator.evaluate(
                    mutated[$0], against: profile
                ).accepted
            }
            let relationshipFailed = ProfessionalQualityRelationshipEvaluator
                .evaluate(observations: mutated, against: profile)
                .contains {
                    $0.kind == .rateConsistency &&
                        $0.checkpoint == rateBound.checkpoint &&
                        $0.metric == rateBound.metric
                }
            if locallyAccepted && relationshipFailed { return mutated }
        }
        throw ProfessionalQualityCalibrationError.invalidBounds
    }

    private static func rateAttack(
        metric: ProfessionalQualityMetric,
        profile: ProfessionalQualityCalibrationProfile,
        observations: [ProfessionalQualityObservation]
    ) throws -> [ProfessionalQualityObservation] {
        for rateBound in profile.rateConsistency where
                rateBound.metric == metric {
            guard let lowIndex = observations.firstIndex(where: {
                $0.sampleRate == profile.sampleRates[0] &&
                    $0.checkpoint == rateBound.checkpoint
            }), let highIndex = observations.firstIndex(where: {
                $0.sampleRate == profile.sampleRates[1] &&
                    $0.checkpoint == rateBound.checkpoint
            }), let metricBounds = profile[rateBound.checkpoint]?[metric]
            else { continue }
            var mutated = observations
            mutated[lowIndex] = try mutated[lowIndex].replacing(
                metric, with: metricBounds.lower
            )
            mutated[highIndex] = try mutated[highIndex].replacing(
                metric, with: metricBounds.upper
            )
            let locallyAccepted = [lowIndex, highIndex].allSatisfy {
                ProfessionalQualityProfileEvaluator.evaluate(
                    mutated[$0], against: profile
                ).accepted
            }
            let relationshipFailed = ProfessionalQualityRelationshipEvaluator
                .evaluate(observations: mutated, against: profile)
                .contains {
                    $0.kind == .rateConsistency &&
                        $0.checkpoint == rateBound.checkpoint &&
                        $0.metric == metric
                }
            if locallyAccepted && relationshipFailed { return mutated }
        }
        throw ProfessionalQualityCalibrationError.invalidBounds
    }
}
