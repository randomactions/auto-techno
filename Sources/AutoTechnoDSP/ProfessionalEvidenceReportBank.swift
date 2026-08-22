import AutoTechnoCore
import Foundation

package enum ProfessionalEvidenceReportBankError: Error, Equatable, Sendable {
    case emptyBank
    case invalidBounds
    case duplicateReport
    case incompleteJourneyCoverage
    case inconsistentIdentity
    case incompleteEvidence
    case policyMustRemainUnavailable
}

package enum ProfessionalQualityPolicyAvailability: String, Codable, Sendable {
    case unavailablePendingCalibratedProfileAndAdversarialSuite =
        "unavailable-pending-calibrated-profile-and-adversarial-suite"
}

/// A deterministic, bounded bank containing every canonical journey checkpoint
/// for each route rate represented by the bank. Professional Evidence v14 is an
/// observation contract only: it has no constructor for a calibrated profile
/// or adversarial-suite identity, so it cannot claim policy availability.
package struct ProfessionalEvidenceReportBank: Encodable, Equatable, Sendable {
    package static let schemaVersion = 14
    package static let evidenceVersion = "autotechno-professional-evidence.v14"
    package static let maximumReports = 64
    package static let maximumEncodedBytes = 64 * 1_024 * 1_024

    package let schemaVersion: Int
    package let evidenceVersion: String
    package let policyAvailability: ProfessionalQualityPolicyAvailability
    package let calibrationProfileFingerprint: String?
    package let adversarialSuiteFingerprint: String?
    package let engineVersion: String
    package let policyVersion: String
    package let evaluatorVersion: String
    package let sourceReportCount: Int
    package let sampleRates: [Double]
    package let reports: [CanonicalJourneyQualificationReport]

    package init(reports sourceReports: [CanonicalJourneyQualificationReport]) throws {
        guard !sourceReports.isEmpty else {
            throw ProfessionalEvidenceReportBankError.emptyBank
        }
        guard sourceReports.count <= Self.maximumReports else {
            throw ProfessionalEvidenceReportBankError.invalidBounds
        }
        let checkpointOrder = Dictionary(uniqueKeysWithValues:
            CanonicalJourneyCheckpoint.allCases.enumerated().map { ($1, $0) }
        )
        let sortedReports = sourceReports.sorted { left, right in
            if left.sampleRate != right.sampleRate {
                return left.sampleRate < right.sampleRate
            }
            return (checkpointOrder[left.checkpoint] ?? Int.max) <
                (checkpointOrder[right.checkpoint] ?? Int.max)
        }
        let rates = Array(Set(sortedReports.map(\.sampleRate))).sorted()
        guard rates.allSatisfy({ rate in
            rate.isFinite &&
                rate >= QualityQualificationContract.minimumSupportedSampleRate &&
                rate <= QualityQualificationContract.maximumSupportedSampleRate
        }) else {
            throw ProfessionalEvidenceReportBankError.invalidBounds
        }
        let identities = Set(sortedReports.map {
            "\($0.sampleRate.bitPattern):\($0.checkpoint.rawValue)"
        })
        guard identities.count == sortedReports.count else {
            throw ProfessionalEvidenceReportBankError.duplicateReport
        }
        guard sortedReports.count == rates.count *
                CanonicalJourneyCheckpoint.allCases.count,
              rates.allSatisfy({ rate in
                  CanonicalJourneyCheckpoint.allCases.allSatisfy { checkpoint in
                      sortedReports.contains {
                          $0.sampleRate == rate && $0.checkpoint == checkpoint
                      }
                  }
              }) else {
            throw ProfessionalEvidenceReportBankError.incompleteJourneyCoverage
        }

        guard let first = sortedReports.first else {
            throw ProfessionalEvidenceReportBankError.emptyBank
        }
        guard sortedReports.allSatisfy({ report in
            report.engineVersion == first.engineVersion &&
                report.policyVersion == first.policyVersion &&
                report.candidateEvaluation.evaluatorVersion ==
                    first.candidateEvaluation.evaluatorVersion &&
                report.schemaVersion == QualityQualificationContract.schemaVersion &&
                report.evidenceScope ==
                    CanonicalJourneyQualificationReport.currentEvidenceScope
        }) else {
            throw ProfessionalEvidenceReportBankError.inconsistentIdentity
        }
        guard sortedReports.allSatisfy({ report in
            let vector = report.selectedCandidateEvidence
            guard let observation = try? ProfessionalQualityObservation(
                report: report
            ) else { return false }
            return vector.isComplete && vector.isFinite &&
                observation.isComplete &&
                observation.liveMaster.hardGatesPassed &&
                report.liveMaster == observation.liveMaster &&
                observation.liveMaster.routeGeneration ==
                    report.routeGeneration &&
                vector.fullMix.loudnessStandard ==
                    BS1770LoudnessMeasurement.standard &&
                vector.fullMix.truePeakStandard ==
                    BS1770AudioEvidence.truePeakStandard &&
                vector.fullMix.analyzedFrameCount > 0 &&
                vector.fullMix.momentaryBlockCount > 0 &&
                vector.fullMix.perceptual.isComplete &&
                vector.fullMix.perceptual.analyzedWindowCount > 0 &&
                vector.fullMix.perceptual.sourceFrameCount ==
                    vector.fullMix.analyzedFrameCount &&
                vector.fullMix.analysisPeakWorkingByteCount <=
                    AutonomousFullMixEvidence
                        .maximumAnalysisPeakWorkingByteCount &&
                vector.masking.count == vector.fullMix.sourceBarCount &&
                vector.masking.allSatisfy(\.isComplete) &&
                vector.stems.count == vector.fullMix.sourceBarCount &&
                vector.stems.allSatisfy(\.isComplete) &&
                vector.modalPercussion.count == vector.fullMix.sourceBarCount &&
                vector.modalPercussion.allSatisfy {
                    $0.isComplete(sampleRate:
                        vector.routeContinuation.sampleRate)
                }
        }) else {
            throw ProfessionalEvidenceReportBankError.incompleteEvidence
        }
        guard first.policyVersion ==
                QualityQualificationContract.uncalibratedPolicyVersion,
              first.candidateEvaluation.evaluatorVersion ==
                QualityQualificationContract.uncalibratedEvaluatorVersion,
              sortedReports.allSatisfy({ report in
                  report.decision.outcome == .qualificationUnavailable &&
                      report.reasonCodes.contains(.policyUncalibratedV1)
              }) else {
            throw ProfessionalEvidenceReportBankError.policyMustRemainUnavailable
        }

        schemaVersion = Self.schemaVersion
        evidenceVersion = Self.evidenceVersion
        policyAvailability =
            .unavailablePendingCalibratedProfileAndAdversarialSuite
        calibrationProfileFingerprint = nil
        adversarialSuiteFingerprint = nil
        engineVersion = first.engineVersion
        policyVersion = first.policyVersion
        evaluatorVersion = first.candidateEvaluation.evaluatorVersion
        sourceReportCount = sourceReports.count
        sampleRates = rates
        reports = sortedReports
    }

    package var policyActivationReady: Bool {
        calibrationProfileFingerprint?.isEmpty == false &&
            adversarialSuiteFingerprint?.isEmpty == false
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumEncodedBytes else {
            throw ProfessionalEvidenceReportBankError.invalidBounds
        }
        return data
    }
}
