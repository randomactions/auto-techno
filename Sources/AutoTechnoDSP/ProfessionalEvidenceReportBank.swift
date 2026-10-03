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

/// Descriptive eligibility audit for the existing modal measurements. This
/// cannot fit a profile or turn unavailable support into a passing verdict.
/// A future calibrated contract must retain the excluded-event counts and
/// qualify its coverage before these means can replace the installed metrics.
package struct ProfessionalQualityModalWindowEvidence: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let sourceReportFingerprint: String
    package let sourceEventCount: Int
    package let attackBodyMeasuredEventCount: Int
    package let tailBodyMeasuredEventCount: Int
    package let attackBodyExcludedEventCount: Int
    package let tailBodyExcludedEventCount: Int
    package let attackToBodyDBMean: Double?
    package let tailToBodyDBMean: Double?
    package let attackBodySupport: ProfessionalQualityModalRatioSupport
    package let tailBodySupport: ProfessionalQualityModalRatioSupport

    package init(report: CanonicalJourneyQualificationReport) throws {
        guard report.evidenceScope == CanonicalJourneyQualificationReport.currentEvidenceScope else {
            throw ProfessionalEvidenceReportBankError.incompleteEvidence
        }
        try self.init(candidate: report.selectedCandidateEvidence,
                      checkpoint: report.checkpoint,
                      sourceReportFingerprint: report.evidenceFingerprint)
    }

    package init(candidate: AutonomousCandidateEvaluationVector,
                 checkpoint: CanonicalJourneyCheckpoint,
                 sourceReportFingerprint: String) throws {
        guard candidate.isComplete, candidate.isFinite,
              !sourceReportFingerprint.isEmpty else {
            throw ProfessionalEvidenceReportBankError.incompleteEvidence
        }
        let sampleRate = candidate.routeContinuation.sampleRate
        let events = candidate.modalPercussion.flatMap(\.events)
        var attacks = ProfessionalQualityModalRatioAccumulator()
        var tails = ProfessionalQualityModalRatioAccumulator()
        for event in events {
            guard let support = event.windowSupport,
                  support.isValid(sampleRate: sampleRate,
                                  frameCount: event.renderedFrameCount) else {
                throw ProfessionalEvidenceReportBankError.incompleteEvidence
            }
            attacks.append(value: support.attackToBodyDB(attackRMS: event.attackRMS,
                bodyRMS: event.bodyRMS, sampleRate: sampleRate),
                numerator: support.attack(sampleRate: sampleRate), body: support.body(sampleRate: sampleRate))
            tails.append(value: support.tailToBodyDB(tailRMS: event.tailRMS,
                bodyRMS: event.bodyRMS, sampleRate: sampleRate),
                numerator: support.tail(sampleRate: sampleRate), body: support.body(sampleRate: sampleRate))
        }
        schemaVersion = 2
        self.checkpoint = checkpoint
        self.sampleRate = sampleRate
        self.sourceReportFingerprint = sourceReportFingerprint
        sourceEventCount = events.count
        attackBodyMeasuredEventCount = attacks.values.count
        tailBodyMeasuredEventCount = tails.values.count
        attackBodyExcludedEventCount = events.count - attacks.values.count
        tailBodyExcludedEventCount = events.count - tails.values.count
        attackToBodyDBMean = attacks.mean
        tailToBodyDBMean = tails.mean
        attackBodySupport = attacks.support
        tailBodySupport = tails.support
    }

    package var isComplete: Bool {
        schemaVersion == 2 && sampleRate.isFinite &&
            sampleRate >= QualityQualificationContract.minimumSupportedSampleRate &&
            sampleRate <= QualityQualificationContract.maximumSupportedSampleRate &&
            !sourceReportFingerprint.isEmpty &&
            attackBodySupport.isComplete && tailBodySupport.isComplete &&
            sourceEventCount == attackBodySupport.sourceEventCount &&
            sourceEventCount == tailBodySupport.sourceEventCount &&
            attackBodyMeasuredEventCount == attackBodySupport.measuredEventCount &&
            tailBodyMeasuredEventCount == tailBodySupport.measuredEventCount &&
            attackBodyExcludedEventCount == sourceEventCount - attackBodyMeasuredEventCount &&
            tailBodyExcludedEventCount == sourceEventCount - tailBodyMeasuredEventCount &&
            Self.meanIsValid(attackToBodyDBMean, count: attackBodyMeasuredEventCount) &&
            Self.meanIsValid(tailToBodyDBMean, count: tailBodyMeasuredEventCount)
    }

    private static func meanIsValid(_ mean: Double?, count: Int) -> Bool {
        count == 0 ? mean == nil : mean.map { $0.isFinite && (-120...120).contains($0) } == true
    }
}

/// A deterministic, bounded bank containing every canonical journey checkpoint
/// for each route rate represented by the bank. Professional Evidence v29 is an
/// observation contract only: it has no constructor for a calibrated profile
/// or adversarial-suite identity, so it cannot claim policy availability.
package struct ProfessionalEvidenceReportBank: Encodable, Equatable, Sendable,
        AutonomousEvidenceCategorizedReport {
    package static let evidenceCategory: AutonomousEvidenceCategory = .descriptive
    package static let schemaVersion = 29
    package static let evidenceVersion = "autotechno-professional-evidence.v29"
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

    package func modalWindowFeatureReports() throws ->
        [ProfessionalQualityModalWindowEvidence] {
        try reports.map { try ProfessionalQualityModalWindowEvidence(report: $0) }
    }

    /// Same-pass event observations continue under the sole renderer owner.
    /// This descriptive geometry/body audit does not replace v21/v22 metrics,
    /// fit a profile or activate a policy.
    package func continuousModalWindowFeatureReports(
        successors: [ProfessionalQualityModalSuccessorEvidence] = []
    ) throws -> [ProfessionalQualityContinuousModalWindowEvidence] {
        let receipts = try modalSuccessorBindings(successors)
        return try reports.map { report in
            try .init(report: report,
                successor: receipts[ProfessionalQualityModalSuccessorEvidence.identity(report)])
        }
    }

    /// Explicit continuous observations share the same receipt ownership and
    /// bounds as the descriptive projection; neither grants policy authority.
    package func continuousModalObservations(
        successors: [ProfessionalQualityModalSuccessorEvidence] = []
    ) throws -> [ProfessionalQualityObservation] {
        let receipts = try modalSuccessorBindings(successors)
        return try reports.map { report in
            try .init(continuousReport: report,
                successor: receipts[ProfessionalQualityModalSuccessorEvidence.identity(report)])
        }
    }

    private func modalSuccessorBindings(
        _ successors: [ProfessionalQualityModalSuccessorEvidence]
    ) throws -> [String: ProfessionalQualityModalSuccessorEvidence] {
        guard successors.count <= Self.maximumReports else {
            throw ProfessionalEvidenceReportBankError.invalidBounds
        }
        let identities = Set(successors.map(\.sourceIdentityFingerprint))
        guard identities.count == successors.count else {
            throw ProfessionalEvidenceReportBankError.duplicateReport
        }
        let sourceIdentities = Set(reports.map(ProfessionalQualityModalSuccessorEvidence.identity))
        guard identities.isSubset(of: sourceIdentities) else {
            throw ProfessionalEvidenceReportBankError.inconsistentIdentity
        }
        let receipts = Dictionary(uniqueKeysWithValues: successors.map {
            ($0.sourceIdentityFingerprint, $0)
        })
        return receipts
    }

    package func windowSupportedObservations() throws -> [ProfessionalQualityObservation] {
        try reports.map { report in
            try ProfessionalQualityObservation(
                report: report, requiringModalWindowSupport: true
            )
        }
    }

    /// Projects a report-only bar-level view from the exact role evidence
    /// already retained in each candidate. This is descriptive analysis and
    /// does not alter the bundled calibrated profile or policy availability.
    package func kickFoundationLocalFeatureReports() throws ->
        [ProfessionalQualityKickFoundationLocalEvidence] {
        try reports.map { report in
            try ProfessionalQualityKickFoundationLocalEvidence(report: report)
        }
    }

    /// Projects the existing per-bar, role-pair, and band masking observations
    /// without adding a metric to the calibrated primary policy.
    package func maskingLocalFeatureReports() throws ->
        [ProfessionalQualityMaskingLocalEvidence] {
        try reports.map { report in
            try ProfessionalQualityMaskingLocalEvidence(report: report)
        }
    }

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
