@testable import AutoTechnoDSP

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
            reasonCodes: transaction.correctionCount == 1
                ? [.candidateAdjustedV1] : [.guardrailRegressionV1]
        )
    }
}
