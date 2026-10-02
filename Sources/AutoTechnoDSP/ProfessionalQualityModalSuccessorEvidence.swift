import AutoTechnoCore
import Foundation

/// Descriptive receipt for the first actually rendered successor bar. The
/// original report and immutable prepared successor retain their own score
/// ownership and policy authority.
/// Decode requires the expected source report/prepared successor and canonical
/// bytes; there is no unchecked Decodable or memberwise construction path.
package struct ProfessionalQualityModalSuccessorEvidence: Encodable, Equatable, Sendable {
    package static let maximumEncodedBytes = 64 * 1_024
    package let schemaVersion: Int
    package let sourceIdentityFingerprint: String
    package let sourceReportFingerprint: String
    package let sourceCandidateFingerprint: String
    package let sourceOutgoingRenderDSPFingerprint: String
    package let successorIdentityFingerprint: String
    package let successorReportFingerprint: String
    package let successorCandidateFingerprint: String
    package let successorPlanFingerprint: String
    package let successorSampleHash: String
    package let routeFingerprint: String
    package let routeGeneration: Int
    package let sampleRate: Double
    package let successorIncomingRenderDSPFingerprint: String
    package let successorIncomingQualityFingerprint: String
    package let successorPreviousGraphFingerprint: String
    package let firstBar: ModalPercussionContinuousBarEvidence

    /// Ordinary immediate successors need no calibration checkpoint label.
    /// The private prepared-product initializer already binds the selected
    /// score, transaction, PCM and every continuation atomically.
    package init(source: CanonicalJourneyQualificationReport,
                 successor: PreparedAutonomousPhrase) throws {
        try self.init(source: source, next: successor.selectedCandidateEvidence,
            engineVersion: successor.candidateEvaluation.engineVersion,
            policyVersion: successor.candidateEvaluation.policyVersion,
            evaluatorVersion: successor.candidateEvaluation.evaluatorVersion,
            commit: successor.commitProvenance, incomingQuality: successor.incomingQualityState,
            sampleHash: successor.audioPreflight.quality.sampleHash,
            identity: AutonomousCandidateCanonicalJSON.fingerprint(PreparedIdentity(successor)),
            transactionFingerprint: successor.candidateEvaluationFingerprint)
    }

    private struct PreparedIdentity: Encodable {
        let scope = "actual-prepared-modal-successor.v1"
        let planFingerprint: String
        let transaction: AutonomousCandidateEvaluationTransaction
        let commit: AutonomousPreparedCommitProvenance
        let incomingQuality: QualityContinuationState
        let outgoingQuality: QualityContinuationState
        init(_ prepared: PreparedAutonomousPhrase) {
            planFingerprint = prepared.selectedCandidateEvidence.planFingerprint
            transaction = prepared.candidateEvaluation
            commit = prepared.commitProvenance
            incomingQuality = prepared.incomingQualityState
            outgoingQuality = prepared.qualityContinuationState
        }
    }

    private init(source: CanonicalJourneyQualificationReport,
                 next: AutonomousCandidateEvaluationVector,
                 engineVersion: String, policyVersion: String, evaluatorVersion: String,
                 commit: AutonomousPreparedCommitProvenance,
                 incomingQuality: QualityContinuationState, sampleHash: String,
                 identity: String, transactionFingerprint: String) throws {
        let origin = source.selectedCandidateEvidence
        let route = origin.routeContinuation
        let nextRoute = next.routeContinuation
        guard origin.isComplete, origin.isFinite, origin.hardGatesPassed,
              next.isComplete, next.isFinite, next.hardGatesPassed,
              source.engineVersion == engineVersion,
              source.policyVersion == policyVersion,
              source.candidateEvaluation.evaluatorVersion == evaluatorVersion,
              source.evidenceScope == CanonicalJourneyQualificationReport.currentEvidenceScope,
              source.commitProvenance.isInternallyConsistent,
              commit.isInternallyConsistent,
              source.sampleHash == origin.fullMix.sampleHash,
              sampleHash == next.fullMix.sampleHash,
              route.sampleRate == nextRoute.sampleRate,
              route.channelCount == nextRoute.channelCount,
              route.routeGeneration == nextRoute.routeGeneration,
              route.routeFingerprint == nextRoute.routeFingerprint,
              !nextRoute.routeRecovery,
              source.routeFingerprint == nextRoute.routeFingerprint,
              source.routeGeneration == nextRoute.routeGeneration,
              origin.symbolic.phraseIndex < Int.max,
              next.symbolic.phraseIndex == origin.symbolic.phraseIndex + 1,
              let incomingDSP = nextRoute.incomingRenderDSPFingerprint,
              incomingDSP == source.commitProvenance.outgoingRenderDSPFingerprint,
              nextRoute.incomingQualityStateFingerprint == source.commitProvenance.outgoingQualityStateFingerprint,
              source.outgoingState == incomingQuality,
              nextRoute.previousGraphFingerprint == origin.graphFingerprint,
              source.liveMaster.outgoingStateFingerprint == next.incomingLiveMasterStateFingerprint,
              let last = origin.modalPercussion.last?.continuousWindows,
              let first = next.modalPercussion.first?.continuousWindows,
              last.bar < Int.max, first.bar == last.bar + 1,
              last.outgoingStateFingerprint == first.incomingStateFingerprint,
              last.isValid, first.isValid,
              last.droppedRecordCount == 0, first.droppedRecordCount == 0 else {
            throw ProfessionalEvidenceReportBankError.inconsistentIdentity
        }
        // Each pending original is retained and completed by actual frames.
        // New successor events have their own ownership and never train this
        // original report's means.
        let pending = Dictionary(uniqueKeysWithValues: last.pending.map { ($0.identity, $0) })
        let originBars = Set(origin.modalPercussion.map(\.bar))
        let inherited = (first.completed + first.pending).filter { originBars.contains($0.originBar) }
        guard Set(inherited.map(\.identity)) == Set(pending.keys),
              inherited.allSatisfy({ record in
                  guard let previous = pending[record.identity] else { return false }
                  return record.status == .complete && record.lastObservedBar == first.bar &&
                      record.observedFrameCount > previous.observedFrameCount
              }) else { throw ProfessionalEvidenceReportBankError.incompleteEvidence }
        var ledger = try ModalPercussionObservationLedger(bars: origin.modalPercussion.map {
            guard let bar = $0.continuousWindows else {
                throw ProfessionalEvidenceReportBankError.incompleteEvidence
            }
            return bar
        })
        try ledger.append(first)
        schemaVersion = 1
        sourceIdentityFingerprint = Self.identity(source)
        sourceReportFingerprint = source.evidenceFingerprint
        sourceCandidateFingerprint = origin.fingerprint
        sourceOutgoingRenderDSPFingerprint = source.commitProvenance.outgoingRenderDSPFingerprint
        successorIdentityFingerprint = identity
        successorReportFingerprint = transactionFingerprint
        successorCandidateFingerprint = next.fingerprint
        successorPlanFingerprint = next.planFingerprint
        successorSampleHash = sampleHash
        routeFingerprint = route.routeFingerprint
        routeGeneration = route.routeGeneration
        sampleRate = route.sampleRate
        successorIncomingRenderDSPFingerprint = incomingDSP
        successorIncomingQualityFingerprint = nextRoute.incomingQualityStateFingerprint
        successorPreviousGraphFingerprint = nextRoute.previousGraphFingerprint
        firstBar = first
        _ = try deterministicJSON()
    }

    /// Full report identity also binds checkpoint/fixture labels. The existing
    /// transaction fingerprint alone does not distinguish those labels.
    package static func identity(_ report: CanonicalJourneyQualificationReport) -> String {
        AutonomousCandidateCanonicalJSON.fingerprint(report)
    }

    package var fingerprint: String { AutonomousCandidateCanonicalJSON.fingerprint(self) }

    package func matches(_ source: CanonicalJourneyQualificationReport) -> Bool {
        let vector = source.selectedCandidateEvidence
        return schemaVersion == 1 && sourceIdentityFingerprint == Self.identity(source) &&
            sourceReportFingerprint == source.evidenceFingerprint &&
            sourceCandidateFingerprint == vector.fingerprint &&
            sourceOutgoingRenderDSPFingerprint == source.commitProvenance.outgoingRenderDSPFingerprint &&
            sampleRate == source.sampleRate && routeFingerprint == source.routeFingerprint &&
            routeGeneration == source.routeGeneration &&
            successorIncomingRenderDSPFingerprint == sourceOutgoingRenderDSPFingerprint &&
            successorIncomingQualityFingerprint == source.commitProvenance.outgoingQualityStateFingerprint &&
            successorPreviousGraphFingerprint == vector.graphFingerprint &&
            firstBar.isValid && firstBar.droppedRecordCount == 0
    }

    package func deterministicJSON() throws -> Data {
        let data = try AutonomousCandidateCanonicalJSON.data(self)
        guard data.count <= Self.maximumEncodedBytes else {
            throw ProfessionalEvidenceReportBankError.invalidBounds
        }
        return data
    }

    package static func decodeValidated(_ data: Data,
        source: CanonicalJourneyQualificationReport,
        successor: PreparedAutonomousPhrase) throws -> Self {
        guard data.count <= maximumEncodedBytes else { throw ProfessionalEvidenceReportBankError.invalidBounds }
        let expected = try Self(source: source, successor: successor)
        guard try expected.deterministicJSON() == data else {
            throw ProfessionalEvidenceReportBankError.inconsistentIdentity
        }
        return expected
    }

}
