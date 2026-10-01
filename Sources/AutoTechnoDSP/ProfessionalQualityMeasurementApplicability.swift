import AutoTechnoCore
import Foundation

/// Applicability is not coverage: absent score material is not required, while
/// a required but unmeasured dimension prevents qualification.
package enum ProfessionalQualityMeasurementApplicability: String, Codable, Hashable, Sendable {
    case measured
    case notRequired = "not-required"
    case unavailable
}

package struct ProfessionalQualityModalRatioSupport: Codable, Equatable, Sendable {
    package let sourceEventCount: Int
    package let measuredEventCount: Int
    package let missingWindowEventCount: Int
    package let partialWindowEventCount: Int
    package let undefinedBodyEventCount: Int

    package var isComplete: Bool {
        let maximum = AutonomousCandidateEvaluationVector.maximumBarCount *
            AutonomousCandidateEvaluationVector.maximumModalPercussionEventsPerBar
        let counts = [measuredEventCount, missingWindowEventCount,
                      partialWindowEventCount, undefinedBodyEventCount]
        return (0...maximum).contains(sourceEventCount) &&
            counts.allSatisfy { (0...sourceEventCount).contains($0) } &&
            counts.reduce(0, +) == sourceEventCount
    }

    package var applicability: ProfessionalQualityMeasurementApplicability {
        guard isComplete else { return .unavailable }
        if sourceEventCount == 0 { return .notRequired }
        return measuredEventCount == sourceEventCount ? .measured : .unavailable
    }
}

package enum ProfessionalQualityMeasurementUnavailableReason: String, Codable, Sendable {
    case requiredWindowSupport = "required-window-support"
    case rateApplicabilityMismatch = "rate-applicability-mismatch"
}

package struct ProfessionalQualityUnavailableMeasurement: Codable, Equatable, Sendable {
    package let checkpoint: CanonicalJourneyCheckpoint
    package let metric: ProfessionalQualityMetric
    package let reason: ProfessionalQualityMeasurementUnavailableReason
}

/// One owner shared by extraction, fitting, local and relationship assessment.
/// v21 remains the installed legacy contract. v22 is unavailable for production
/// activation until its own independent fixtures and qualification pass.
package enum ProfessionalQualityMeasurementContract {
    package static let modalWindowObservationVersion =
        "autotechno-professional-quality-observation.v22"
    package static let modalWindowProfileVersion =
        "autotechno-professional-quality-profile.v31"
    package static let modalMetrics: [ProfessionalQualityMetric] = [
        .modalPercussionAttackToBodyDBMean, .modalPercussionTailToBodyDBMean,
    ]

    package static func unavailableMeasurements(
        in observations: [ProfessionalQualityObservation]
    ) -> [ProfessionalQualityUnavailableMeasurement] {
        var result: [ProfessionalQualityUnavailableMeasurement] = []
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            let sources = observations.filter { $0.checkpoint == checkpoint }
            for metric in modalMetrics {
                if sources.contains(where: {
                    $0.measurementApplicability(metric) == .unavailable
                }) {
                    result.append(.init(checkpoint: checkpoint, metric: metric,
                                        reason: .requiredWindowSupport))
                } else if sources.contains(where: { $0.modalWindowSupport != nil }),
                          Set(sources.map { $0.measurementApplicability(metric) })
                            .count > 1 {
                    result.append(.init(checkpoint: checkpoint, metric: metric,
                                        reason: .rateApplicabilityMismatch))
                }
            }
        }
        return result
    }

    package static func requireSupported(
        _ observations: [ProfessionalQualityObservation]
    ) throws {
        if let unavailable = unavailableMeasurements(in: observations).first {
            throw ProfessionalQualityCalibrationError.unavailableMeasurement(unavailable)
        }
    }
}
