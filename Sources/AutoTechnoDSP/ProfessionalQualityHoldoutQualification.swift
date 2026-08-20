import AutoTechnoCore
import Foundation

package struct ProfessionalQualityHoldoutTrajectoryResult: Codable, Equatable,
        Sendable {
    package let sourceBankFingerprint: String
    package let sourceObservationCount: Int
    package let acceptedObservationCount: Int
    package let verdicts: [ProfessionalQualityReportVerdict]
    package let relationshipFailures: [ProfessionalQualityRelationshipFailure]

    package var qualified: Bool {
        !sourceBankFingerprint.isEmpty && sourceObservationCount > 0 &&
            acceptedObservationCount == sourceObservationCount &&
            verdicts.count == sourceObservationCount &&
            verdicts.allSatisfy(\.accepted) &&
            relationshipFailures.isEmpty
    }
}

/// Frozen evidence that the calibrated envelope generalized to complete,
/// deterministic canonical journeys that were not used to derive it. This is
/// still offline evidence: it makes no listening, hardware, or shipping claim.
package struct ProfessionalQualityHoldoutQualification: Codable, Equatable,
        Sendable {
    package static let schemaVersion = 9
    package static let qualificationVersion =
        "autotechno-professional-quality-holdout.v9"
    package static let evaluatorVersion =
        "autotechno-professional-quality-holdout-evaluator.v9"
    package static let minimumHoldoutTrajectoryCount = 4

    package let schemaVersion: Int
    package let qualificationVersion: String
    package let evaluatorVersion: String
    package let engineVersion: String
    package let evidenceVersion: String
    package let profileFingerprint: String
    package let adversarialSuiteFingerprint: String
    package let calibrationCorpusFingerprint: String
    package let holdoutCorpusFingerprint: String
    package let calibrationTrajectoryCount: Int
    package let holdoutTrajectoryCount: Int
    package let overlappingSourceBankCount: Int
    package let sourceObservationCount: Int
    package let acceptedObservationCount: Int
    package let trajectories: [ProfessionalQualityHoldoutTrajectoryResult]

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        adversarialSuite: ProfessionalQualityAdversarialSuiteReport,
        calibrationCorpus: ProfessionalQualityCalibrationCorpus,
        holdoutCorpus: ProfessionalQualityCalibrationCorpus
    ) throws {
        let overlap = calibrationCorpus.sourceBankFingerprints.intersection(
            holdoutCorpus.sourceBankFingerprints
        )
        guard profile.usesDiverseCalibration,
              adversarialSuite.schemaVersion ==
                ProfessionalQualityAdversarialSuiteReport.schemaVersion,
              adversarialSuite.suiteVersion ==
                ProfessionalQualityAdversarialSuiteReport.suiteVersion,
              adversarialSuite.passed,
              adversarialSuite.profileFingerprint == profile.fingerprint,
              calibrationCorpus.isComplete,
              holdoutCorpus.isComplete,
              calibrationCorpus.fingerprint == profile.sourceBankFingerprint,
              calibrationCorpus.sourceTrajectoryCount ==
                profile.sourceTrajectoryCount,
              holdoutCorpus.sourceTrajectoryCount >=
                Self.minimumHoldoutTrajectoryCount,
              calibrationCorpus.engineVersion == profile.engineVersion,
              holdoutCorpus.engineVersion == profile.engineVersion,
              calibrationCorpus.evidenceVersion == profile.evidenceVersion,
              holdoutCorpus.evidenceVersion == profile.evidenceVersion,
              overlap.isEmpty else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }

        let checkpointOrder = Dictionary(uniqueKeysWithValues:
            CanonicalJourneyCheckpoint.allCases.enumerated().map { ($1, $0) }
        )
        let results = holdoutCorpus.trajectories.map { trajectory in
            let verdicts = trajectory.observations.map { observation in
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                )
                return ProfessionalQualityReportVerdict(
                    checkpoint: observation.checkpoint,
                    sampleRate: observation.sampleRate,
                    accepted: verdict.accepted,
                    reasons: verdict.reasons,
                    failedMetrics: verdict.failedMetrics
                )
            }.sorted { left, right in
                if left.sampleRate != right.sampleRate {
                    return left.sampleRate < right.sampleRate
                }
                return (checkpointOrder[left.checkpoint] ?? Int.max) <
                    (checkpointOrder[right.checkpoint] ?? Int.max)
            }
            return ProfessionalQualityHoldoutTrajectoryResult(
                sourceBankFingerprint: trajectory.sourceBankFingerprint,
                sourceObservationCount: trajectory.observations.count,
                acceptedObservationCount: verdicts.filter(\.accepted).count,
                verdicts: verdicts,
                relationshipFailures: ProfessionalQualityRelationshipEvaluator
                    .evaluate(
                        observations: trajectory.observations,
                        against: profile
                    )
            )
        }.sorted { $0.sourceBankFingerprint < $1.sourceBankFingerprint }

        schemaVersion = Self.schemaVersion
        qualificationVersion = Self.qualificationVersion
        evaluatorVersion = Self.evaluatorVersion
        engineVersion = profile.engineVersion
        evidenceVersion = profile.evidenceVersion
        profileFingerprint = profile.fingerprint
        adversarialSuiteFingerprint = adversarialSuite.fingerprint
        calibrationCorpusFingerprint = calibrationCorpus.fingerprint
        holdoutCorpusFingerprint = holdoutCorpus.fingerprint
        calibrationTrajectoryCount = calibrationCorpus.sourceTrajectoryCount
        holdoutTrajectoryCount = holdoutCorpus.sourceTrajectoryCount
        overlappingSourceBankCount = overlap.count
        sourceObservationCount = results.reduce(0) {
            $0 + $1.sourceObservationCount
        }
        acceptedObservationCount = results.reduce(0) {
            $0 + $1.acceptedObservationCount
        }
        trajectories = results
    }

    package var qualified: Bool {
        schemaVersion == Self.schemaVersion &&
            qualificationVersion == Self.qualificationVersion &&
            evaluatorVersion == Self.evaluatorVersion &&
            !engineVersion.isEmpty &&
            evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion &&
            !profileFingerprint.isEmpty &&
            !adversarialSuiteFingerprint.isEmpty &&
            !calibrationCorpusFingerprint.isEmpty &&
            !holdoutCorpusFingerprint.isEmpty &&
            calibrationCorpusFingerprint != holdoutCorpusFingerprint &&
            calibrationTrajectoryCount >=
                ProfessionalQualityCalibrationProfile
                    .minimumCalibrationTrajectoryCount &&
            holdoutTrajectoryCount >= Self.minimumHoldoutTrajectoryCount &&
            overlappingSourceBankCount == 0 &&
            trajectories.count == holdoutTrajectoryCount &&
            trajectories == trajectories.sorted {
                $0.sourceBankFingerprint < $1.sourceBankFingerprint
            } &&
            Set(trajectories.map(\.sourceBankFingerprint)).count ==
                trajectories.count &&
            sourceObservationCount == trajectories.reduce(0) {
                $0 + $1.sourceObservationCount
            } &&
            acceptedObservationCount == sourceObservationCount &&
            trajectories.allSatisfy(\.qualified)
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    package static func decodeDeterministicJSON(
        _ data: Data
    ) throws -> ProfessionalQualityHoldoutQualification {
        let decoded = try JSONDecoder().decode(
            ProfessionalQualityHoldoutQualification.self,
            from: data
        )
        guard decoded.qualified,
              try decoded.deterministicJSON() == data else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return decoded
    }

    package var fingerprint: String {
        guard let data = try? deterministicJSON(),
              let string = String(data: data, encoding: .utf8) else { return "" }
        var sink = StreamingFNV1a()
        sink.domain("professional-quality-holdout-qualification-json.v2")
        sink.string(string)
        return fixedWidthFingerprintHex(sink.value)
    }
}
