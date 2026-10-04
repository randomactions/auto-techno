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
        try self.init(source: SourceBinding(source), next: successor.selectedCandidateEvidence,
            engineVersion: successor.candidateEvaluation.engineVersion,
            policyVersion: successor.candidateEvaluation.policyVersion,
            evaluatorVersion: successor.candidateEvaluation.evaluatorVersion,
            commit: successor.commitProvenance, incomingQuality: successor.incomingQualityState,
            sampleHash: successor.audioPreflight.quality.sampleHash,
            identity: AutonomousCandidateCanonicalJSON.fingerprint(PreparedIdentity(successor)),
            transactionFingerprint: successor.candidateEvaluationFingerprint)
    }

    /// Runtime construction uses actual immutable preparation products, with
    /// no fixture label or invented canonical journey report.
    package init(sourcePrepared: PreparedAutonomousPhrase,
                 successor: PreparedAutonomousPhrase) throws {
        try self.init(source: SourceBinding(sourcePrepared), next: successor.selectedCandidateEvidence,
            engineVersion: successor.candidateEvaluation.engineVersion,
            policyVersion: successor.candidateEvaluation.policyVersion,
            evaluatorVersion: successor.candidateEvaluation.evaluatorVersion,
            commit: successor.commitProvenance, incomingQuality: successor.incomingQualityState,
            sampleHash: successor.audioPreflight.quality.sampleHash,
            identity: Self.identity(successor),
            transactionFingerprint: successor.candidateEvaluationFingerprint)
    }

    private struct SourceBinding {
        let selectedCandidateEvidence: AutonomousCandidateEvaluationVector
        let engineVersion: String
        let policyVersion: String
        let evaluatorVersion: String
        let commitProvenance: AutonomousPreparedCommitProvenance
        let sampleHash: String
        let outgoingState: QualityContinuationState
        let outgoingLiveMasterFingerprint: String
        let identityFingerprint: String
        let evidenceFingerprint: String
        let evidenceScopeIsCurrent: Bool
        var routeFingerprint: String { selectedCandidateEvidence.routeContinuation.routeFingerprint }
        var routeGeneration: Int { selectedCandidateEvidence.routeContinuation.routeGeneration }

        init(_ report: CanonicalJourneyQualificationReport) {
            selectedCandidateEvidence = report.selectedCandidateEvidence
            engineVersion = report.engineVersion; policyVersion = report.policyVersion
            evaluatorVersion = report.candidateEvaluation.evaluatorVersion
            commitProvenance = report.commitProvenance; sampleHash = report.sampleHash
            outgoingState = report.outgoingState
            outgoingLiveMasterFingerprint = report.liveMaster.outgoingStateFingerprint
            identityFingerprint = ProfessionalQualityModalSuccessorEvidence.identity(report)
            evidenceFingerprint = report.evidenceFingerprint
            evidenceScopeIsCurrent = report.evidenceScope == CanonicalJourneyQualificationReport.currentEvidenceScope
        }

        init(_ prepared: PreparedAutonomousPhrase) {
            selectedCandidateEvidence = prepared.selectedCandidateEvidence
            engineVersion = prepared.candidateEvaluation.engineVersion
            policyVersion = prepared.candidateEvaluation.policyVersion
            evaluatorVersion = prepared.candidateEvaluation.evaluatorVersion
            commitProvenance = prepared.commitProvenance
            sampleHash = prepared.audioPreflight.quality.sampleHash
            outgoingState = prepared.qualityContinuationState
            outgoingLiveMasterFingerprint = prepared.liveMasterHeadroomContinuationState.fingerprint
            identityFingerprint = ProfessionalQualityModalSuccessorEvidence.identity(prepared)
            evidenceFingerprint = prepared.candidateEvaluationFingerprint
            evidenceScopeIsCurrent = prepared.candidateEvaluation.isComplete
        }
    }

    private struct PreparedIdentity: Encodable {
        let scope: String
        let preparationReplayFingerprint: String?
        let planFingerprint: String
        let transaction: AutonomousCandidateEvaluationTransaction
        let commit: AutonomousPreparedCommitProvenance
        let incomingQuality: QualityContinuationState
        let outgoingQuality: QualityContinuationState
        // Omitted for the existing path: historical prepared identities retain
        // exact bytes. The proof itself is excluded to avoid a source-identity
        // cycle; its typed source binding is rechecked by commit admission.
        let preparedValidationRequired: Bool?
        init(_ prepared: PreparedAutonomousPhrase) {
            self.init(planFingerprint: prepared.selectedCandidateEvidence.planFingerprint,
                transaction: prepared.candidateEvaluation, commit: prepared.commitProvenance,
                incomingQuality: prepared.incomingQualityState, outgoingQuality: prepared.qualityContinuationState,
                preparedValidationRequired: prepared.preparedValidationRequired,
                preparationReplayFingerprint: prepared.preparationReplayFingerprint)
        }
        init(planFingerprint: String, transaction: AutonomousCandidateEvaluationTransaction,
            commit: AutonomousPreparedCommitProvenance, incomingQuality: QualityContinuationState,
            outgoingQuality: QualityContinuationState, preparedValidationRequired: Bool,
            preparationReplayFingerprint: String? = nil) {
            scope = preparationReplayFingerprint == nil ? "actual-prepared-modal-successor.v1" : "actual-prepared-modal-successor.v2"
            self.preparationReplayFingerprint = preparationReplayFingerprint
            self.planFingerprint = planFingerprint; self.transaction = transaction; self.commit = commit
            self.incomingQuality = incomingQuality; self.outgoingQuality = outgoingQuality
            self.preparedValidationRequired = preparedValidationRequired ? true : nil
        }
    }

    private init(source: SourceBinding,
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
              source.evaluatorVersion == evaluatorVersion,
              source.evidenceScopeIsCurrent,
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
              source.outgoingLiveMasterFingerprint == next.incomingLiveMasterStateFingerprint,
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
        sourceIdentityFingerprint = source.identityFingerprint
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

    package static func identity(_ prepared: PreparedAutonomousPhrase) -> String {
        prepared.preparedValidationSourceIdentityFingerprint ??
            AutonomousCandidateCanonicalJSON.fingerprint(PreparedIdentity(prepared))
    }

    /// Used only by private prepared-product construction, before commit
    /// admission. Hashing stays in detached preparation rather than scheduling.
    package static func preparedValidationIdentity(planFingerprint: String,
        transaction: AutonomousCandidateEvaluationTransaction,
        commit: AutonomousPreparedCommitProvenance, incomingQuality: QualityContinuationState,
        outgoingQuality: QualityContinuationState, preparationReplayFingerprint: String? = nil) -> String {
        AutonomousCandidateCanonicalJSON.fingerprint(PreparedIdentity(
            planFingerprint: planFingerprint, transaction: transaction, commit: commit,
            incomingQuality: incomingQuality, outgoingQuality: outgoingQuality,
            preparedValidationRequired: true, preparationReplayFingerprint: preparationReplayFingerprint))
    }

    package func matches(_ source: PreparedAutonomousPhrase) -> Bool {
        let binding = SourceBinding(source)
        let vector = binding.selectedCandidateEvidence
        return schemaVersion == 1 && sourceIdentityFingerprint == binding.identityFingerprint &&
            sourceReportFingerprint == binding.evidenceFingerprint &&
            sourceCandidateFingerprint == vector.fingerprint &&
            sourceOutgoingRenderDSPFingerprint == binding.commitProvenance.outgoingRenderDSPFingerprint &&
            sampleRate == vector.routeContinuation.sampleRate &&
            routeFingerprint == binding.routeFingerprint && routeGeneration == binding.routeGeneration &&
            successorIncomingRenderDSPFingerprint == sourceOutgoingRenderDSPFingerprint &&
            successorIncomingQualityFingerprint == binding.commitProvenance.outgoingQualityStateFingerprint &&
            successorPreviousGraphFingerprint == vector.graphFingerprint &&
            firstBar.isValid && firstBar.droppedRecordCount == 0
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

    /// Runtime receipts require both actual products, just as construction does.
    package static func decodeValidated(_ data: Data,
        sourcePrepared: PreparedAutonomousPhrase,
        successor: PreparedAutonomousPhrase) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw ProfessionalEvidenceReportBankError.invalidBounds
        }
        let expected = try Self(sourcePrepared: sourcePrepared, successor: successor)
        guard try expected.deterministicJSON() == data else {
            throw ProfessionalEvidenceReportBankError.inconsistentIdentity
        }
        return expected
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
