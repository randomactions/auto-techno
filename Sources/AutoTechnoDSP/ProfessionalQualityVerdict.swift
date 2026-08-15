import AutoTechnoCore

/// Replayable checkpoint verdict shared by primary evaluation and holdout
/// qualification. Every failed metric remains explicit; dimensions never
/// compensate for one another through an aggregate score.
package struct ProfessionalQualityReportVerdict: Codable, Equatable, Sendable {
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let accepted: Bool
    package let reasons: [ProfessionalQualityRejection]
    package let failedMetrics: [ProfessionalQualityMetric]
}
