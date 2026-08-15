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

/// Exact-engine calibrated evaluator for the existing bounded preparation
/// transaction. Construction requires a complete adversarially challenged
/// profile produced by the current canonical engine. A historical development
/// profile can still diagnose later engines, but cannot silently become the
/// shipping selector.
package struct ProfessionalQualityPairedCandidateEvaluator:
        AutonomousCandidateEvaluating {
    package static let policyFamilyVersion =
        "autotechno-quality.paired-calibrated.v1"
    package static let evaluatorVersionIdentifier =
        "autotechno-candidate-evaluator.paired-calibrated.v1"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    package let policyVersion: String
    package let evaluatorVersion = Self.evaluatorVersionIdentifier
    package let requiresPairedCandidates = true

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    ) throws {
        _ = try ProfessionalQualityDevelopmentPolicy(
            profile: profile,
            adversarialSuite: adversarialSuite
        )
        guard profile.engineVersion == QualityQualificationContract.engineVersion,
              profile.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        self.profile = profile
        self.adversarialSuite = adversarialSuite
        policyVersion = [
            Self.policyFamilyVersion,
            "profile-\(profile.fingerprint)",
            "adversarial-\(adversarialSuite.fingerprint)",
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
        let checkpoints = CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        )
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

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        compare(
            primary: assessment(of: primary),
            alternate: assessment(of: alternate)
        )
    }

    package func compare(
        primary: [ProfessionalQualityObservation],
        alternate: [ProfessionalQualityObservation]
    ) -> AutonomousQualityComparison {
        compare(
            primary: assessment(of: primary),
            alternate: assessment(of: alternate)
        )
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        UncalibratedAutonomousCandidateEvaluator
            .requestsHomeUpperTimbreCorrection(for: candidate)
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        guard selected.hardGatesPassed else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                reasonCodes: [.hardGateFailedV1]
            )
        }
        // The conservative plan is a continuity/safety result, not an authored
        // candidate that may be relabeled as professionally qualified. Once its
        // hard gates pass, preserve that exact terminal outcome even when its
        // deliberately neutral identity lies outside the authored checkpoint
        // profile that rejected both candidates.
        if selected.slot == .fallback {
            return AutonomousCandidatePolicyVerdict(
                outcome: .conservativeFallback,
                reasonCodes: [.conservativeFallbackV1]
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
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1]
        )
    }

    private func compare(
        primary: ProfessionalQualityCandidateAssessment,
        alternate: ProfessionalQualityCandidateAssessment
    ) -> AutonomousQualityComparison {
        guard primary.availability == .available,
              alternate.availability == .available,
              primary.sampleRate == alternate.sampleRate,
              primary.checkpoints == alternate.checkpoints else {
            return .unavailable
        }
        switch (primary.accepted, alternate.accepted) {
        case (true, false): return .primary
        case (false, true): return .alternate
        case (true, true): return .tie
        case (false, false): return .fallback
        }
    }
}
