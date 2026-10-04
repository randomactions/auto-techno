import AutoTechnoCore
import Foundation

/// Applicability is not coverage: absent score material is not required, while
/// a required but unmeasured dimension prevents qualification.
package enum ProfessionalQualityMeasurementApplicability: String, Codable, Hashable, Sendable {
    case measured
    case notRequired = "not-required"
    case unavailable
}

/// Bounded score/render event population for the existing upper-tail projection.
/// A natural-body zero remains a measured clearance ratio; an empty score does not.
package struct ProfessionalQualityUpperPercussionTailSupport: Codable, Equatable, Sendable {
    package let sourceEventCount: Int
    package let foregroundClearanceEventCount: Int

    package init(sourceEventCount: Int, foregroundClearanceEventCount: Int) {
        self.sourceEventCount = sourceEventCount
        self.foregroundClearanceEventCount = foregroundClearanceEventCount
    }

    package var isComplete: Bool {
        let maximum = AutonomousCandidateEvaluationVector.maximumBarCount *
            AutonomousCandidateEvaluationVector.maximumUpperPercussionTailEventsPerBar
        return (0...maximum).contains(sourceEventCount) &&
            (0...sourceEventCount).contains(foregroundClearanceEventCount)
    }
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

/// One version decision for the retained runtime and both explicit offline
/// measurement scopes. Scope selection never grants activation authority.
package enum ProfessionalQualityMeasurementScope: String, Sendable {
    case legacy
    case barLocalModalWindow = "bar-local-modal-window"
    case continuousModalWindow = "continuous-modal-window"

    package var observationSchema: Int {
        switch self {
        case .legacy: 21
        case .barLocalModalWindow: 22
        case .continuousModalWindow: 23
        }
    }

    package var observationVersion: String {
        switch self {
        case .legacy: "autotechno-professional-quality-observation.v21"
        case .barLocalModalWindow: "autotechno-professional-quality-observation.v22"
        case .continuousModalWindow: "autotechno-professional-quality-observation.v23"
        }
    }

    package var profileSchema: Int {
        switch self {
        case .legacy: 22
        case .barLocalModalWindow: 23
        case .continuousModalWindow: 25
        }
    }
    package var profileVersion: String {
        switch self {
        case .legacy: "autotechno-professional-quality-profile.v30"
        case .barLocalModalWindow: "autotechno-professional-quality-profile.v31"
        case .continuousModalWindow: "autotechno-professional-quality-profile.v33"
        }
    }

    package var requiresModalWindowSupport: Bool { self != .legacy }

    package static func observation(
        schema: Int, version: String
    ) -> Self? {
        [Self.legacy, .barLocalModalWindow, .continuousModalWindow].first {
            $0.observationSchema == schema && $0.observationVersion == version
        }
    }

    package static func profile(
        schema: Int, version: String, observationVersion: String
    ) -> Self? {
        [Self.legacy, .barLocalModalWindow, .continuousModalWindow].first {
            $0.profileSchema == schema && $0.profileVersion == version &&
                $0.observationVersion == observationVersion
        }
    }
}

/// One owner shared by extraction, fitting, local and relationship assessment.
/// v21 remains the installed legacy contract. v22 is unavailable for production
/// activation until its own independent fixtures and qualification pass.
package enum ProfessionalQualityMeasurementContract {
    package static let modalWindowObservationVersion =
        ProfessionalQualityMeasurementScope.barLocalModalWindow.observationVersion
    package static let modalWindowProfileVersion =
        ProfessionalQualityMeasurementScope.barLocalModalWindow.profileVersion
    package static let continuousModalObservationVersion =
        ProfessionalQualityMeasurementScope.continuousModalWindow.observationVersion
    package static let continuousModalProfileVersion =
        ProfessionalQualityMeasurementScope.continuousModalWindow.profileVersion
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
                } else if sources.contains(where: { $0.measurementScope?.requiresModalWindowSupport == true }),
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

/// Shared count/mean owner for bar-local and continuous descriptive projections.
/// Complete geometry and positive body remain distinct requirements.
struct ProfessionalQualityModalRatioAccumulator {
    var values: [Double] = []
    var sourceCount = 0
    var missingCount = 0, partialCount = 0, undefinedCount = 0

    mutating func append(value: Double?, numerator: ModalPercussionWindowSupport.Availability,
                         body: ModalPercussionWindowSupport.Availability) {
        sourceCount += 1
        if let value { values.append(value) }
        else if numerator == .missing || body == .missing { missingCount += 1 }
        else if numerator == .partial || body == .partial { partialCount += 1 }
        else { undefinedCount += 1 }
    }

    var support: ProfessionalQualityModalRatioSupport {
        .init(sourceEventCount: sourceCount, measuredEventCount: values.count,
              missingWindowEventCount: missingCount, partialWindowEventCount: partialCount,
              undefinedBodyEventCount: undefinedCount)
    }
    var mean: Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
}
