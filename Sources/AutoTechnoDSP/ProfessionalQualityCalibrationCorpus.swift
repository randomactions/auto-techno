import AutoTechnoCore
import Foundation

/// One exact, complete canonical journey after its reports have been reduced to
/// non-reconstructable professional-quality observations. The fingerprint is
/// the source report-bank identity, not a user-visible seed or filename.
package struct ProfessionalQualityCalibrationTrajectory: Codable, Equatable,
        Sendable {
    package let sourceBankFingerprint: String
    package let observations: [ProfessionalQualityObservation]

    package init(
        sourceBankFingerprint: String,
        observations sourceObservations: [ProfessionalQualityObservation]
    ) throws {
        guard !sourceBankFingerprint.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let sorted = try Self.validatedAndSorted(sourceObservations)
        self.sourceBankFingerprint = sourceBankFingerprint
        observations = sorted
    }

    package init(bank: ProfessionalEvidenceReportBank) throws {
        try self.init(
            sourceBankFingerprint: Self.fingerprint(of: bank),
            observations: bank.reports.map(ProfessionalQualityObservation.init)
        )
    }

    package var engineVersion: String {
        observations.first?.engineVersion ?? ""
    }

    package var evidenceVersion: String {
        observations.first?.evidenceVersion ?? ""
    }

    package var sampleRates: [Double] {
        Array(Set(observations.map(\.sampleRate))).sorted()
    }

    package var isComplete: Bool {
        (try? Self.validatedAndSorted(observations)) == observations
    }

    private static func validatedAndSorted(
        _ observations: [ProfessionalQualityObservation]
    ) throws -> [ProfessionalQualityObservation] {
        guard let first = observations.first,
              observations.allSatisfy({
                  $0.isComplete &&
                      $0.engineVersion == first.engineVersion &&
                      $0.evidenceVersion == first.evidenceVersion
              }) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let rates = Array(Set(observations.map(\.sampleRate))).sorted()
        guard rates == ProfessionalQualityCalibrationProfile.requiredSampleRates,
              observations.count == rates.count *
                CanonicalJourneyCheckpoint.allCases.count else {
            throw ProfessionalQualityCalibrationError
                .incompleteRepresentativeRates
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
        let identities = Set(sorted.map {
            "\($0.sampleRate.bitPattern):\($0.checkpoint.rawValue)"
        })
        guard identities.count == sorted.count,
              rates.allSatisfy({ sampleRate in
                  CanonicalJourneyCheckpoint.allCases.allSatisfy { checkpoint in
                      sorted.contains {
                          $0.sampleRate == sampleRate &&
                              $0.checkpoint == checkpoint
                      }
                  }
              }) else {
            throw ProfessionalQualityCalibrationError
                .incompleteCheckpointCoverage
        }
        return sorted
    }

    private static func fingerprint(
        of bank: ProfessionalEvidenceReportBank
    ) throws -> String {
        let data = try bank.deterministicJSON()
        guard let string = String(data: data, encoding: .utf8) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        var sink = StreamingFNV1a()
        sink.domain("professional-quality-source-bank-json.v1")
        sink.string(string)
        return fixedWidthFingerprintHex(sink.value)
    }
}

/// A bounded collection of independently generated, complete canonical
/// journeys. Calibration and holdout corpora share this structure, but their
/// fingerprints and source-bank identities must remain disjoint.
package struct ProfessionalQualityCalibrationCorpus: Codable, Equatable,
        Sendable {
    package static let schemaVersion = 2
    package static let corpusVersion =
        "autotechno-professional-quality-corpus.v2"
    package static let maximumTrajectoryCount = 36

    package let schemaVersion: Int
    package let corpusVersion: String
    package let engineVersion: String
    package let evidenceVersion: String
    package let sampleRates: [Double]
    package let sourceTrajectoryCount: Int
    package let sourceObservationCount: Int
    package let trajectories: [ProfessionalQualityCalibrationTrajectory]

    package init(banks: [ProfessionalEvidenceReportBank]) throws {
        try self.init(trajectories: banks.map(
            ProfessionalQualityCalibrationTrajectory.init
        ))
    }

    package init(
        trajectories sourceTrajectories: [
            ProfessionalQualityCalibrationTrajectory
        ]
    ) throws {
        let sorted = sourceTrajectories.sorted {
            $0.sourceBankFingerprint < $1.sourceBankFingerprint
        }
        guard !sorted.isEmpty,
              sorted.count <= Self.maximumTrajectoryCount,
              Set(sorted.map(\.sourceBankFingerprint)).count == sorted.count,
              let first = sorted.first,
              first.isComplete,
              sorted.allSatisfy({
                  $0.isComplete &&
                      $0.engineVersion == first.engineVersion &&
                      $0.evidenceVersion == first.evidenceVersion &&
                      $0.sampleRates == first.sampleRates
              }) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        schemaVersion = Self.schemaVersion
        corpusVersion = Self.corpusVersion
        engineVersion = first.engineVersion
        evidenceVersion = first.evidenceVersion
        sampleRates = first.sampleRates
        sourceTrajectoryCount = sorted.count
        sourceObservationCount = sorted.reduce(0) {
            $0 + $1.observations.count
        }
        trajectories = sorted
    }

    package var observations: [ProfessionalQualityObservation] {
        trajectories.flatMap(\.observations)
    }

    package var sourceBankFingerprints: Set<String> {
        Set(trajectories.map(\.sourceBankFingerprint))
    }

    package var isComplete: Bool {
        schemaVersion == Self.schemaVersion &&
            corpusVersion == Self.corpusVersion &&
            !engineVersion.isEmpty &&
            evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion &&
            sampleRates == ProfessionalQualityCalibrationProfile
                .requiredSampleRates &&
            sourceTrajectoryCount == trajectories.count &&
            sourceTrajectoryCount > 0 &&
            sourceTrajectoryCount <= Self.maximumTrajectoryCount &&
            sourceObservationCount == observations.count &&
            Set(trajectories.map(\.sourceBankFingerprint)).count ==
                trajectories.count &&
            trajectories == trajectories.sorted {
                $0.sourceBankFingerprint < $1.sourceBankFingerprint
            } &&
            trajectories.allSatisfy {
                $0.isComplete && $0.engineVersion == engineVersion &&
                    $0.evidenceVersion == evidenceVersion &&
                    $0.sampleRates == sampleRates
            }
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    package var fingerprint: String {
        guard let data = try? deterministicJSON(),
              let string = String(data: data, encoding: .utf8) else { return "" }
        var sink = StreamingFNV1a()
        sink.domain("professional-quality-calibration-corpus-json.v1")
        sink.string(string)
        return fixedWidthFingerprintHex(sink.value)
    }
}
