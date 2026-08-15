import AutoTechnoCore

package enum ProfessionalQualityPreparationAvailability: String, Codable,
        Equatable, Sendable {
    case available
    case artifactsUnavailable = "artifacts-unavailable"
    case unsupportedSampleRate = "unsupported-sample-rate"
}

/// Preloaded, route-local quality evaluator for detached preparation. This type
/// performs no file I/O and creates no runtime mode. Missing artifacts or
/// unsupported routes remain truthfully unavailable; they never install a
/// permissive evaluator.
package struct ProfessionalQualityPreparationEvaluator:
        AutonomousCandidateEvaluating {
    package let availability: ProfessionalQualityPreparationAvailability
    package let policyVersion: String
    package let evaluatorVersion: String
    private let calibrated: ProfessionalQualityPrimaryEvaluator?

    package init(
        sampleRate: Double,
        artifacts: ProfessionalQualityPrimaryArtifacts?
    ) {
        if let artifacts {
            if sampleRate.isFinite,
               artifacts.profile.sampleRates.contains(sampleRate) {
                availability = .available
                calibrated = artifacts.evaluator
                policyVersion = artifacts.evaluator.policyVersion
                evaluatorVersion = artifacts.evaluator.evaluatorVersion
            } else {
                availability = .unsupportedSampleRate
                calibrated = nil
                policyVersion = QualityQualificationContract
                    .uncalibratedPolicyVersion
                evaluatorVersion = QualityQualificationContract
                    .uncalibratedEvaluatorVersion
            }
        } else {
            availability = .artifactsUnavailable
            calibrated = nil
            policyVersion = QualityQualificationContract
                .uncalibratedPolicyVersion
            evaluatorVersion = QualityQualificationContract
                .uncalibratedEvaluatorVersion
        }
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector
    ) -> Bool {
        if let calibrated {
            return calibrated.requestsHomeUpperTimbreCorrection(for: candidate)
        }
        return false
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
        return AutonomousCandidatePolicyVerdict(
            outcome: .qualificationUnavailable,
            reasonCodes: [.evaluatorUnavailableV1]
        )
    }
}
