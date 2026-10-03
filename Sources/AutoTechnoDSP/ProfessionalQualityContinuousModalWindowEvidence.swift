import AutoTechnoCore
import Foundation

/// Explicit descriptive contract for measurements with actual successor
/// support. The installed policy and the bar-local v22 audit remain unchanged.
package struct ProfessionalQualityContinuousModalWindowEvidence: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let sourceReportFingerprint: String
    package let sourceEventCount: Int
    package let successorEvidenceFingerprint: String?
    package let attackBodySupport: ProfessionalQualityModalRatioSupport
    package let tailBodySupport: ProfessionalQualityModalRatioSupport
    package let attackToBodyDBMean: Double?
    package let tailToBodyDBMean: Double?

    package init(report: CanonicalJourneyQualificationReport,
                 successor: ProfessionalQualityModalSuccessorEvidence? = nil) throws {
        guard report.evidenceScope == CanonicalJourneyQualificationReport.currentEvidenceScope,
              successor.map({ $0.matches(report) }) ?? true else {
            throw ProfessionalEvidenceReportBankError.inconsistentIdentity
        }
        try self.init(candidate: report.selectedCandidateEvidence, checkpoint: report.checkpoint,
            sourceReportFingerprint: report.evidenceFingerprint,
            successorBar: successor?.firstBar, successorFingerprint: successor?.fingerprint)
    }

    package init(candidate: AutonomousCandidateEvaluationVector,
                 checkpoint: CanonicalJourneyCheckpoint,
                 sourceReportFingerprint: String) throws {
        try self.init(candidate: candidate, checkpoint: checkpoint,
            sourceReportFingerprint: sourceReportFingerprint, successorBar: nil, successorFingerprint: nil)
    }

    private init(candidate: AutonomousCandidateEvaluationVector,
                 checkpoint: CanonicalJourneyCheckpoint,
                 sourceReportFingerprint: String,
                 successorBar: ModalPercussionContinuousBarEvidence?,
                 successorFingerprint: String?) throws {
        guard candidate.isComplete, candidate.isFinite, !sourceReportFingerprint.isEmpty else {
            throw ProfessionalEvidenceReportBankError.incompleteEvidence
        }
        let rate = candidate.routeContinuation.sampleRate
        let bars = try candidate.modalPercussion.map { bar in
            guard let continuity = bar.continuousWindows,
                  continuity.bar == bar.bar, continuity.sampleRate == rate else {
                throw ProfessionalEvidenceReportBankError.incompleteEvidence
            }
            return continuity
        }
        var ledger = try ModalPercussionObservationLedger(bars: bars)
        if let successorBar { try ledger.append(successorBar) }
        let latest = ledger.records
        var attacks = ProfessionalQualityModalRatioAccumulator()
        var tails = ProfessionalQualityModalRatioAccumulator()
        var count = 0
        for bar in candidate.modalPercussion {
            for event in bar.events {
                count += 1
                guard let identity = event.articulationFingerprint,
                      let originalSupport = event.windowSupport,
                      let record = latest["\(bar.bar):\(event.scoreEventIndex):\(identity)"],
                      record.sampleRate == rate,
                      record.startFrame == originalSupport.startFrame,
                      record.originFrameCount == event.renderedFrameCount else {
                    throw ProfessionalEvidenceReportBankError.incompleteEvidence
                }
                let support = record.windowSupport
                attacks.append(value: support.attackToBodyDB(attackRMS: record.attackRMS,
                    bodyRMS: record.bodyRMS, sampleRate: rate),
                    numerator: support.attack(sampleRate: rate), body: support.body(sampleRate: rate))
                tails.append(value: support.tailToBodyDB(tailRMS: record.tailRMS,
                    bodyRMS: record.bodyRMS, sampleRate: rate),
                    numerator: support.tail(sampleRate: rate), body: support.body(sampleRate: rate))
            }
        }
        // Reject unowned current-phrase records, including a retargeted index
        // that otherwise leaves the legitimate source event intact.
        let currentBars = Set(candidate.modalPercussion.map(\.bar))
        let expected = Set(candidate.modalPercussion.flatMap { bar in bar.events.map {
            "\(bar.bar):\($0.scoreEventIndex):\($0.articulationFingerprint ?? "")"
        } })
        guard Set(latest.values.filter { currentBars.contains($0.originBar) }.map(\.identity)) == expected else {
            throw ProfessionalEvidenceReportBankError.incompleteEvidence
        }
        schemaVersion = successorFingerprint == nil ? 1 : 2
        self.checkpoint = checkpoint; sampleRate = rate
        self.sourceReportFingerprint = sourceReportFingerprint; sourceEventCount = count
        successorEvidenceFingerprint = successorFingerprint
        attackBodySupport = attacks.support
        tailBodySupport = tails.support
        attackToBodyDBMean = attacks.mean
        tailToBodyDBMean = tails.mean
    }

    package var isComplete: Bool {
        ((schemaVersion == 1 && successorEvidenceFingerprint == nil) ||
         (schemaVersion == 2 && successorEvidenceFingerprint?.isEmpty == false)) &&
            !sourceReportFingerprint.isEmpty &&
            sampleRate.isFinite &&
            (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate).contains(sampleRate) &&
            sourceEventCount == attackBodySupport.sourceEventCount &&
            sourceEventCount == tailBodySupport.sourceEventCount &&
            attackBodySupport.isComplete && tailBodySupport.isComplete &&
            Self.validMean(attackToBodyDBMean, count: attackBodySupport.measuredEventCount) &&
            Self.validMean(tailToBodyDBMean, count: tailBodySupport.measuredEventCount)
    }

    private static func validMean(_ value: Double?, count: Int) -> Bool {
        count == 0 ? value == nil : value.map { $0.isFinite && (-120...120).contains($0) } == true
    }
}

/// Construction provenance for the continuous observation scope. The original
/// report and typed validated successor are required at construction/rebinding;
/// decoded descriptive means alone cannot confer fitting authority.
package struct ProfessionalQualityContinuousModalObservationSource: Encodable,
        Equatable, Sendable {
    package let sourceIdentityFingerprint: String
    package let projection: ProfessionalQualityContinuousModalWindowEvidence

    package init(report: CanonicalJourneyQualificationReport,
                 successor: ProfessionalQualityModalSuccessorEvidence? = nil) throws {
        sourceIdentityFingerprint = ProfessionalQualityModalSuccessorEvidence.identity(report)
        projection = try .init(report: report, successor: successor)
    }

    package var isComplete: Bool {
        !sourceIdentityFingerprint.isEmpty && projection.isComplete
    }
}
