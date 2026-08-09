import AutoTechnoCore
import Foundation

package struct ProfessionalQualityReportVerdict: Codable, Equatable, Sendable {
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let accepted: Bool
    package let reasons: [ProfessionalQualityRejection]
    package let failedMetrics: [ProfessionalQualityMetric]
}

/// Machine-readable result for an exact engine bank under the frozen
/// development calibration. It does not activate runtime paired selection and
/// does not claim physical-output or release qualification.
package struct ProfessionalQualityDevelopmentQualification: Codable, Equatable,
        Sendable {
    package static let schemaVersion = 1

    package let schemaVersion: Int
    package let policyVersion: String
    package let evaluatorVersion: String
    package let calibrationSourceEngineVersion: String
    package let evaluatedEngineVersion: String
    package let profileFingerprint: String
    package let adversarialSuiteFingerprint: String
    package let sourceObservationCount: Int
    package let acceptedObservationCount: Int
    package let verdicts: [ProfessionalQualityReportVerdict]

    package var qualified: Bool {
        schemaVersion == Self.schemaVersion && sourceObservationCount > 0 &&
            acceptedObservationCount == sourceObservationCount &&
            verdicts.count == sourceObservationCount &&
            verdicts.allSatisfy(\.accepted)
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

/// Offline-only policy joining one frozen, non-reconstructable profile to the
/// adversarial identity that challenged it. The shipping preparer remains on
/// the uncalibrated evaluator until the later paired-selection roadmap stage.
package struct ProfessionalQualityDevelopmentPolicy: Sendable {
    package static let policyVersion =
        "autotechno-quality.development-calibrated.v1"
    package static let evaluatorVersion =
        "autotechno-professional-quality-evaluator.v1"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    ) throws {
        guard profile.isComplete, adversarialSuite.passed,
              !profile.fingerprint.isEmpty,
              adversarialSuite.profileFingerprint == profile.fingerprint,
              !adversarialSuite.fingerprint.isEmpty else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        self.profile = profile
        self.adversarialSuite = adversarialSuite
    }

    package var isAvailable: Bool {
        profile.isComplete && adversarialSuite.passed &&
            adversarialSuite.profileFingerprint == profile.fingerprint
    }

    package func evaluate(
        bank: ProfessionalEvidenceReportBank
    ) throws -> ProfessionalQualityDevelopmentQualification {
        guard bank.evidenceVersion == profile.evidenceVersion,
              bank.sampleRates == profile.sampleRates else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return try evaluate(
            observations: bank.reports.map(ProfessionalQualityObservation.init)
        )
    }

    package func evaluate(
        observations: [ProfessionalQualityObservation]
    ) throws -> ProfessionalQualityDevelopmentQualification {
        guard isAvailable,
              observations.count == profile.sampleRates.count *
                CanonicalJourneyCheckpoint.allCases.count,
              let evaluatedEngineVersion = observations.first?.engineVersion,
              !evaluatedEngineVersion.isEmpty,
              observations.allSatisfy({
                  $0.isComplete &&
                      $0.engineVersion == evaluatedEngineVersion &&
                      $0.evidenceVersion == profile.evidenceVersion
              }) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let identities = Set(observations.map {
            "\($0.sampleRate.bitPattern):\($0.checkpoint.rawValue)"
        })
        guard identities.count == observations.count,
              profile.sampleRates.allSatisfy({ sampleRate in
                  CanonicalJourneyCheckpoint.allCases.allSatisfy { checkpoint in
                      observations.contains {
                          $0.sampleRate == sampleRate &&
                              $0.checkpoint == checkpoint
                      }
                  }
              }) else {
            throw ProfessionalQualityCalibrationError
                .incompleteCheckpointCoverage
        }
        let checkpointOrder = Dictionary(uniqueKeysWithValues:
            CanonicalJourneyCheckpoint.allCases.enumerated().map { ($1, $0) }
        )
        let sorted = observations.sorted { left, right in
            if left.sampleRate != right.sampleRate {
                return left.sampleRate < right.sampleRate
            }
            return (checkpointOrder[left.checkpoint] ?? Int.max) <
                (checkpointOrder[right.checkpoint] ?? Int.max)
        }
        let verdicts = sorted.map { observation in
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                observation, against: profile
            )
            return ProfessionalQualityReportVerdict(
                checkpoint: observation.checkpoint,
                sampleRate: observation.sampleRate,
                accepted: verdict.accepted,
                reasons: verdict.reasons,
                failedMetrics: verdict.failedMetrics
            )
        }
        return ProfessionalQualityDevelopmentQualification(
            schemaVersion: ProfessionalQualityDevelopmentQualification
                .schemaVersion,
            policyVersion: Self.policyVersion,
            evaluatorVersion: Self.evaluatorVersion,
            calibrationSourceEngineVersion: profile.engineVersion,
            evaluatedEngineVersion: evaluatedEngineVersion,
            profileFingerprint: profile.fingerprint,
            adversarialSuiteFingerprint: adversarialSuite.fingerprint,
            sourceObservationCount: observations.count,
            acceptedObservationCount: verdicts.filter(\.accepted).count,
            verdicts: verdicts
        )
    }
}
