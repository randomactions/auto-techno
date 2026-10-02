import Foundation

/// Bounded integrity reduction shared by within-phrase and actual-successor
/// audits. It retains source records, never PCM or a musical decision.
package struct ModalPercussionObservationLedger {
    package private(set) var records: [String: ModalPercussionContinuousEventEvidence] = [:]
    package private(set) var lastBar: ModalPercussionContinuousBarEvidence?
    private var barCount = 0

    package init(bars: [ModalPercussionContinuousBarEvidence]) throws {
        guard !bars.isEmpty,
              bars.count <= AutonomousCandidateEvaluationVector.maximumBarCount else {
            throw ProfessionalEvidenceReportBankError.invalidBounds
        }
        for bar in bars { try append(bar) }
    }

    package mutating func append(_ bar: ModalPercussionContinuousBarEvidence) throws {
        guard barCount < AutonomousCandidateEvaluationVector.maximumBarCount + 1,
              bar.isValid, bar.droppedRecordCount == 0 else {
            throw ProfessionalEvidenceReportBankError.incompleteEvidence
        }
        if let previous = lastBar {
            guard previous.bar < Int.max, bar.bar == previous.bar + 1,
                  bar.sampleRate == previous.sampleRate,
                  bar.incomingStateFingerprint == previous.outgoingStateFingerprint else {
                throw ProfessionalEvidenceReportBankError.incompleteEvidence
            }
        }
        let observations = bar.completed + bar.pending
        if let previous = lastBar {
            let observed = Set(observations.map(\.identity))
            guard previous.pending.allSatisfy({ observed.contains($0.identity) }) else {
                throw ProfessionalEvidenceReportBankError.incompleteEvidence
            }
        }
        for record in observations {
            if let old = records[record.identity] {
                guard old.status == .pending,
                      record.observedFrameCount >= old.observedFrameCount,
                      record.lastObservedBar >= old.lastObservedBar,
                      record.startFrame == old.startFrame,
                      record.originFrameCount == old.originFrameCount,
                      record.sampleRate == old.sampleRate,
                      record.peak >= old.peak,
                      Self.unchangedCompletedWindow(oldCount: old.windowSupport.attackSampleCount,
                        newCount: record.windowSupport.attackSampleCount,
                        oldRMS: old.attackRMS, newRMS: record.attackRMS),
                      Self.unchangedCompletedWindow(oldCount: old.windowSupport.bodySampleCount,
                        newCount: record.windowSupport.bodySampleCount,
                        oldRMS: old.bodyRMS, newRMS: record.bodyRMS),
                      Self.unchangedCompletedWindow(oldCount: old.windowSupport.tailSampleCount,
                        newCount: record.windowSupport.tailSampleCount,
                        oldRMS: old.tailRMS, newRMS: record.tailRMS) else {
                    throw ProfessionalEvidenceReportBankError.incompleteEvidence
                }
            } else if lastBar != nil && record.originBar < bar.bar {
                throw ProfessionalEvidenceReportBankError.incompleteEvidence
            }
            records[record.identity] = record
        }
        let bound = (AutonomousCandidateEvaluationVector.maximumBarCount + 1) *
            (ModalPercussionMeasurementState.outputCapacity + ModalPercussionMeasurementState.pendingCapacity)
        guard records.count <= bound else { throw ProfessionalEvidenceReportBankError.invalidBounds }
        lastBar = bar
        barCount += 1
    }

    private static func unchangedCompletedWindow(oldCount: Int, newCount: Int,
                                                 oldRMS: Double, newRMS: Double) -> Bool {
        newCount >= oldCount && (newCount != oldCount || oldRMS.bitPattern == newRMS.bitPattern)
    }
}
