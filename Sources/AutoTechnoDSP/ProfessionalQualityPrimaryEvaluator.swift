import AutoTechnoCore

package enum ProfessionalQualityCandidateAssessmentAvailability: String,
        Codable, Equatable, Sendable {
    case available
    case noApplicableCheckpoint = "no-applicable-checkpoint"
    case unsupportedSampleRate = "unsupported-sample-rate"
    case invalidEvidence = "invalid-evidence"
}

/// Replayable per-candidate result under one exact calibrated profile. A
/// candidate can represent multiple structural checkpoints, and every
/// applicable checkpoint must pass independently. There is deliberately no
/// aggregate score or distance-to-center optimization.
package struct ProfessionalQualityCandidateAssessment: Codable, Equatable,
        Sendable {
    package let availability: ProfessionalQualityCandidateAssessmentAvailability
    package let sampleRate: Double?
    package let checkpoints: [CanonicalJourneyCheckpoint]
    package let verdicts: [ProfessionalQualityReportVerdict]

    package var accepted: Bool {
        availability == .available && !verdicts.isEmpty &&
            verdicts.allSatisfy(\.accepted)
    }

    fileprivate static func unavailable(
        _ availability: ProfessionalQualityCandidateAssessmentAvailability,
        sampleRate: Double? = nil,
        checkpoints: [CanonicalJourneyCheckpoint] = []
    ) -> Self {
        Self(
            availability: availability,
            sampleRate: sampleRate,
            checkpoints: checkpoints,
            verdicts: []
        )
    }
}

/// Exact-engine calibrated evaluator for the bounded primary preparation
/// transaction. Construction requires a complete adversarially challenged
/// profile and qualified holdout produced by the current canonical engine.
package struct ProfessionalQualityPrimaryEvaluator:
        AutonomousCandidateEvaluating {
    package static let policyFamilyVersion =
        "autotechno-quality.primary-calibrated.v5"
    package static let evaluatorVersionIdentifier =
        "autotechno-candidate-evaluator.primary-calibrated.v5"
    package static let requiredProfileVersion =
        "autotechno-professional-quality-profile.v5"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    package let holdoutQualification: ProfessionalQualityHoldoutQualification
    package let policyVersion: String
    package let evaluatorVersion = Self.evaluatorVersionIdentifier

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        adversarialSuite: ProfessionalQualityAdversarialSuiteReport,
        holdoutQualification: ProfessionalQualityHoldoutQualification
    ) throws {
        guard profile.isComplete,
              profile.usesDiverseCalibration,
              profile.profileVersion == Self.requiredProfileVersion,
              adversarialSuite.passed,
              !profile.fingerprint.isEmpty,
              adversarialSuite.profileFingerprint == profile.fingerprint,
              !adversarialSuite.fingerprint.isEmpty,
              adversarialSuite.schemaVersion ==
                ProfessionalQualityAdversarialSuiteReport.schemaVersion,
              holdoutQualification.qualified,
              holdoutQualification.engineVersion == profile.engineVersion,
              holdoutQualification.profileFingerprint == profile.fingerprint,
              holdoutQualification.adversarialSuiteFingerprint ==
                adversarialSuite.fingerprint,
              holdoutQualification.calibrationCorpusFingerprint ==
                profile.sourceBankFingerprint,
              profile.engineVersion == QualityQualificationContract.engineVersion,
              profile.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        self.profile = profile
        self.adversarialSuite = adversarialSuite
        self.holdoutQualification = holdoutQualification
        policyVersion = [
            Self.policyFamilyVersion,
            "profile-\(profile.fingerprint)",
            "adversarial-\(adversarialSuite.fingerprint)",
            "holdout-\(holdoutQualification.fingerprint)",
        ].joined(separator: ".")
    }

    package func assessment(
        of candidate: AutonomousCandidateEvaluationVector
    ) -> ProfessionalQualityCandidateAssessment {
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ) else {
            return .unavailable(.invalidEvidence)
        }
        let applicableCheckpoints = CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        )
        // Ordinary lock phrases use the continuation envelope. It is derived
        // from the same engine's later steady-state journey observations and
        // gives every primary phrase a calibrated, non-aggregate judgment.
        let checkpoints = applicableCheckpoints.isEmpty
            ? [.longContinuation] : applicableCheckpoints
        let sampleRate = candidate.routeContinuation.sampleRate
        guard !checkpoints.isEmpty else {
            return .unavailable(
                .noApplicableCheckpoint,
                sampleRate: sampleRate
            )
        }
        guard profile.sampleRates.contains(sampleRate) else {
            return .unavailable(
                .unsupportedSampleRate,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        do {
            let observations = try checkpoints.map {
                try ProfessionalQualityObservation(
                    candidate: candidate,
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: $0
                )
            }
            return assessment(of: observations)
        } catch {
            return .unavailable(
                .invalidEvidence,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
    }

    /// Reduced-observation seam used by deterministic policy and adversarial
    /// tests. All observations must describe one candidate at one route rate.
    package func assessment(
        of observations: [ProfessionalQualityObservation]
    ) -> ProfessionalQualityCandidateAssessment {
        let checkpoints = CanonicalJourneyCheckpoint.allCases.filter {
            checkpoint in observations.contains { $0.checkpoint == checkpoint }
        }
        guard let sampleRate = observations.first?.sampleRate else {
            return .unavailable(.noApplicableCheckpoint)
        }
        guard profile.sampleRates.contains(sampleRate) else {
            return .unavailable(
                .unsupportedSampleRate,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        let identities = Set(observations.map(\.checkpoint))
        guard !checkpoints.isEmpty,
              identities.count == observations.count,
              checkpoints.count == observations.count,
              observations.allSatisfy({
                  $0.isComplete &&
                      $0.engineVersion ==
                        QualityQualificationContract.engineVersion &&
                      $0.evidenceVersion == profile.evidenceVersion &&
                      $0.sampleRate == sampleRate
              }) else {
            return .unavailable(
                .invalidEvidence,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        let verdicts = checkpoints.compactMap { checkpoint in
            observations.first { $0.checkpoint == checkpoint }.map {
                observation in
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                )
                return ProfessionalQualityReportVerdict(
                    checkpoint: checkpoint,
                    sampleRate: sampleRate,
                    accepted: verdict.accepted,
                    reasons: verdict.reasons,
                    failedMetrics: verdict.failedMetrics
                )
            }
        }
        guard verdicts.count == observations.count else {
            return .unavailable(
                .invalidEvidence,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        return ProfessionalQualityCandidateAssessment(
            availability: .available,
            sampleRate: sampleRate,
            checkpoints: checkpoints,
            verdicts: verdicts
        )
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector
    ) -> Bool {
        candidate.hardGates.symbolicValid &&
            candidate.hardGates.graphValid &&
            candidate.hardGates.audioSafetyValid &&
            candidate.hardGates.fullMixFinite &&
            candidate.hardGates.blocksPresent &&
            candidate.hardGates.blockChannelsAligned &&
            candidate.hardGates.allSamplesFinite &&
            candidate.hardGates.completeInputs &&
            !candidate.postGraphUpperTimbreEvidence.finite
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        guard transaction.isComplete,
              transaction.engineVersion == profile.engineVersion,
              transaction.policyVersion == policyVersion,
              transaction.evaluatorVersion == evaluatorVersion,
              transaction.planFingerprint == selected.planFingerprint,
              transaction.selectedAttemptIndex.map({
                  transaction.attempts[$0].vector == selected
              }) == true,
              transaction.liveProposalFingerprint ==
                selected.liveProposalFingerprint else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                reasonCodes: [.guardrailRegressionV1]
            )
        }
        guard selected.hardGatesPassed else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                reasonCodes: [.hardGateFailedV1]
            )
        }
        let result = assessment(of: selected)
        guard result.availability == .available else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .qualificationUnavailable,
                reasonCodes: [.evaluatorUnavailableV1]
            )
        }
        guard result.accepted else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                reasonCodes: [.guardrailRegressionV1]
            )
        }
        return AutonomousCandidatePolicyVerdict(
            outcome: transaction.correctionCount == 0 ? .qualified : .adjusted,
            reasonCodes: transaction.correctionCount == 0
                ? [.candidateQualifiedV1] : [.candidateAdjustedV1]
        )
    }
}
