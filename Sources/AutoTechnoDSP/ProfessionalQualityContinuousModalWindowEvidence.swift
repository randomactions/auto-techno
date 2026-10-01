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
    package let attackBodySupport: ProfessionalQualityModalRatioSupport
    package let tailBodySupport: ProfessionalQualityModalRatioSupport
    package let attackToBodyDBMean: Double?
    package let tailToBodyDBMean: Double?

    package init(candidate: AutonomousCandidateEvaluationVector,
                 checkpoint: CanonicalJourneyCheckpoint,
                 sourceReportFingerprint: String) throws {
        guard candidate.isComplete, candidate.isFinite, !sourceReportFingerprint.isEmpty else {
            throw ProfessionalEvidenceReportBankError.incompleteEvidence
        }
        let rate = candidate.routeContinuation.sampleRate
        var latest: [String: ModalPercussionContinuousEventEvidence] = [:]
        var previous: ModalPercussionContinuousBarEvidence?
        for bar in candidate.modalPercussion {
            guard let continuity = bar.continuousWindows,
                  continuity.isValid, continuity.bar == bar.bar,
                  continuity.sampleRate == rate, continuity.droppedRecordCount == 0,
                  previous.map({ $0.outgoingStateFingerprint == continuity.incomingStateFingerprint }) ?? true else {
                throw ProfessionalEvidenceReportBankError.incompleteEvidence
            }
            for record in continuity.completed + continuity.pending {
                if let old = latest[record.identity] {
                    guard old.status == .pending,
                          record.observedFrameCount >= old.observedFrameCount,
                          record.lastObservedBar >= old.lastObservedBar,
                          record.startFrame == old.startFrame,
                          record.originFrameCount == old.originFrameCount,
                          record.sampleRate == old.sampleRate else {
                        throw ProfessionalEvidenceReportBankError.incompleteEvidence
                    }
                }
                latest[record.identity] = record
            }
            previous = continuity
        }
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
        schemaVersion = 1
        self.checkpoint = checkpoint; sampleRate = rate
        self.sourceReportFingerprint = sourceReportFingerprint; sourceEventCount = count
        attackBodySupport = attacks.support
        tailBodySupport = tails.support
        attackToBodyDBMean = attacks.mean
        tailToBodyDBMean = tails.mean
    }

    package var isComplete: Bool {
        schemaVersion == 1 && !sourceReportFingerprint.isEmpty &&
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
