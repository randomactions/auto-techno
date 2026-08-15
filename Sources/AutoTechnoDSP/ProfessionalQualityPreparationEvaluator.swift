import AutoTechnoCore

package enum ProfessionalQualityPreparationAvailability: String, Codable,
        Equatable, Sendable {
    case available
    case artifactsUnavailable = "artifacts-unavailable"
    case unsupportedSampleRate = "unsupported-sample-rate"
}

/// Preloaded, route-local quality evaluator for detached preparation. This type
/// performs no file I/O and creates no runtime mode: it either delegates to the
/// exact current-engine paired policy or preserves the existing uncalibrated
/// evaluator when immutable artifacts or calibrated route coverage are absent.
package struct ProfessionalQualityPreparationEvaluator:
        AutonomousCandidateEvaluating {
    package let availability: ProfessionalQualityPreparationAvailability
    package let policyVersion: String
    package let evaluatorVersion: String
    package let requiresPairedCandidates: Bool

    private let calibrated: ProfessionalQualityPairedCandidateEvaluator?

    package init(
        sampleRate: Double,
        artifacts: ProfessionalQualityPairedArtifacts?
    ) {
        if let artifacts {
            if sampleRate.isFinite,
               artifacts.profile.sampleRates.contains(sampleRate) {
                availability = .available
                calibrated = artifacts.evaluator
                policyVersion = artifacts.evaluator.policyVersion
                evaluatorVersion = artifacts.evaluator.evaluatorVersion
                requiresPairedCandidates = true
            } else {
                availability = .unsupportedSampleRate
                calibrated = nil
                policyVersion = QualityQualificationContract
                    .uncalibratedPolicyVersion
                evaluatorVersion = QualityQualificationContract
                    .uncalibratedEvaluatorVersion
                requiresPairedCandidates = false
            }
        } else {
            availability = .artifactsUnavailable
            calibrated = nil
            policyVersion = QualityQualificationContract
                .uncalibratedPolicyVersion
            evaluatorVersion = QualityQualificationContract
                .uncalibratedEvaluatorVersion
            requiresPairedCandidates = false
        }
    }

    package func requestsPairedComparison(
        after primary: AutonomousCandidateEvaluationVector
    ) -> Bool {
        calibrated?.requestsPairedComparison(after: primary) ?? false
    }

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        calibrated?.compare(primary: primary, alternate: alternate) ??
            .unavailable
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        if let calibrated {
            return calibrated.requestsHomeUpperTimbreCorrection(
                for: candidate,
                slot: slot
            )
        }
        return UncalibratedAutonomousCandidateEvaluator
            .requestsHomeUpperTimbreCorrection(for: candidate)
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        if let calibrated {
            return calibrated.terminalVerdict(
                selected: selected,
                transaction: transaction
            )
        }
        return UncalibratedAutonomousCandidateEvaluator().terminalVerdict(
            selected: selected,
            transaction: transaction
        )
    }
}
