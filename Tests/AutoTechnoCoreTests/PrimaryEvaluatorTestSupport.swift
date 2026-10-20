@testable import AutoTechnoDSP
import Foundation

/// Deterministic unit-test seam for renderer/evidence tests that are not
/// exercising the frozen professional profile itself.
struct AcceptingPrimaryTestEvaluator: AutonomousCandidateEvaluating {
    let policyVersion = "test-primary-calibrated.v1"
    let evaluatorVersion = "test-primary-accepting.v1"

    func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector
    ) -> Bool {
        false
    }

    func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .qualified,
            decisionBasis: .calibratedQuality,
            reasonCodes: [.candidateQualifiedV1]
        )
    }
}

struct CorrectingPrimaryTestEvaluator: AutonomousCandidateEvaluating {
    let policyVersion = "test-primary-calibrated.v1"
    let evaluatorVersion = "test-primary-correcting.v1"

    func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector
    ) -> Bool {
        true
    }

    func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: transaction.correctionCount == 1 ? .adjusted : .rejected,
            decisionBasis: .calibratedQuality,
            reasonCodes: transaction.correctionCount == 1
                ? [.candidateAdjustedV1] : [.guardrailRegressionV1]
        )
    }
}

/// Original v30 resource bytes are explicit attack fixtures, never the current
/// artifact target. Construction must fail under the continuous policy.
func historicalV30PrimaryArtifacts() throws -> ProfessionalQualityPrimaryArtifacts {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/AutoTechnoDSP/Resources")
    return try ProfessionalQualityPrimaryArtifacts(
        profileData: Data(contentsOf: directory.appendingPathComponent("professional-quality-primary-profile-v30.json")),
        adversarialSuiteData: Data(contentsOf: directory.appendingPathComponent("professional-quality-primary-adversarial-suite-v30.json")),
        holdoutQualificationData: Data(contentsOf: directory.appendingPathComponent("professional-quality-primary-holdout-v30.json")))
}
