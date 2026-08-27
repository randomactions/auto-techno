import Foundation

/// Stable versions for the calibrated single-primary quality contract.
package enum QualityQualificationContract {
    /// Version 22 binds app-owned scheduled live PCM, exact mixer-to-player
    /// clock mapping, live BS.1770 evidence, bounded terminal attenuation, and
    /// its atomic commit at an unscheduled future boundary. Quality schema 36
    /// binds score-owned phrase-slice texture and seed to deterministic
    /// micrograin geometry, exact PCM, and causal evaluator evidence.
    package static let schemaVersion = 36
    package static let reasonCodeVersion = 1
    package static let engineVersion = "autotechno-canonical-engine.v35"
    package static let uncalibratedEvaluatorVersion =
        "autotechno-candidate-evaluator.uncalibrated.v1"
    package static let maximumCorrectionRenders = 1
    package static let maximumRenderPasses = 2
    package static let maximumPhraseBars = 16
    package static let minimumSupportedSampleRate = 8_000.0
    package static let maximumSupportedSampleRate = 192_000.0
    /// The current emitted/audio-qualified topology is native stereo only.
    package static let requiredRouteChannelCount = 2
    package static let maximumRouteChannelCount = requiredRouteChannelCount
    package static let maskingObservationsPerBar = 12
    package static let stemRolesPerBar = 5
    package static let uncalibratedPolicyVersion = "autotechno-quality.uncalibrated.v1"
}

package enum CanonicalJourneyCheckpoint: String, CaseIterable, Codable, Equatable, Sendable {
    case establishment
    case chapterChange = "chapter-change"
    case contrast
    case majorBreak = "major-break"
    case release
    case identityReturn = "identity-return"
    case longContinuation = "long-continuation"

    /// Returns every calibrated structural checkpoint represented by one
    /// resolved candidate. A phrase may legitimately carry more than one
    /// checkpoint (for example, a late release at a chapter boundary), while
    /// an ordinary lock phrase may carry none. Keeping this semantic mapping
    /// in Core prevents report generation and detached DSP evaluation from
    /// inventing separate checkpoint rules.
    package static func applicable(
        phraseIndex: Int,
        phraseKind: AutonomousPhraseKind,
        chapterChanged: Bool
    ) -> [CanonicalJourneyCheckpoint] {
        guard phraseIndex >= 0 else { return [] }
        var represented = Set<CanonicalJourneyCheckpoint>()
        if phraseIndex == 0 { represented.insert(.establishment) }
        if chapterChanged { represented.insert(.chapterChange) }
        switch phraseKind {
        case .contrast: represented.insert(.contrast)
        case .majorBreak: represented.insert(.majorBreak)
        case .energyRelease: represented.insert(.release)
        case .identityReturn: represented.insert(.identityReturn)
        case .lock: break
        }
        if phraseIndex >= 16 { represented.insert(.longContinuation) }
        return allCases.filter(represented.contains)
    }

    /// Runtime terminal qualification uses one whole-phrase population. A
    /// structural phrase can still contribute several offline observations,
    /// but intersecting those separately calibrated populations at runtime can
    /// create an empty envelope. Prefer the most specific semantic owner.
    /// Chapter-change remains an offline relationship label because its
    /// calibrated observations may also belong to a structural phrase; an
    /// ordinary lock uses the broad continuation population at runtime.
    package static func primaryQualification(
        phraseIndex: Int,
        phraseKind: AutonomousPhraseKind,
        chapterChanged _: Bool
    ) -> CanonicalJourneyCheckpoint? {
        guard phraseIndex >= 0 else { return nil }
        if phraseIndex == 0 { return .establishment }
        switch phraseKind {
        case .contrast: return .contrast
        case .majorBreak: return .majorBreak
        case .energyRelease: return .release
        case .identityReturn: return .identityReturn
        case .lock: break
        }
        if phraseIndex >= 16 { return .longContinuation }
        return nil
    }
}

package enum QualityDecisionOutcome: String, Codable, Equatable, Sendable {
    case qualificationUnavailable = "qualification-unavailable"
    case qualified
    case rejected
    case adjusted
}

/// Ephemeral but replayable continuation for serial proposals after a terminal
/// calibrated rejection. It is distinct from accepted quality continuation:
/// rejected evidence never mutates the committed session state.
package struct AutonomousQualityRetryContinuation: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package static let maximumOrdinal = 8

    package let schemaVersion: Int
    package let targetPhraseIndex: Int?
    package let ordinal: Int
    package let exhausted: Bool

    package init(
        targetPhraseIndex: Int? = nil,
        ordinal: Int = 0,
        exhausted: Bool = false
    ) {
        schemaVersion = Self.schemaVersion
        self.targetPhraseIndex = targetPhraseIndex.map { max(0, $0) }
        self.ordinal = min(Self.maximumOrdinal, max(0, ordinal))
        self.exhausted = exhausted &&
            self.ordinal == Self.maximumOrdinal &&
            self.targetPhraseIndex != nil
    }

    package func ordinal(for targetPhraseIndex: Int) -> Int {
        self.targetPhraseIndex == targetPhraseIndex ? ordinal : 0
    }

    package func recordingCalibratedRejection(
        decision: QualityDecision,
        targetPhraseIndex: Int
    ) -> Self {
        guard targetPhraseIndex >= 0,
              decision.outcome == .rejected,
              decision.reasonCodes.contains(.guardrailRegressionV1),
              !decision.reasonCodes.contains(.hardGateFailedV1),
              !decision.reasonCodes.contains(.evidenceMissingV1),
              !decision.reasonCodes.contains(.evidenceNonFiniteV1) else {
            return self
        }
        let current = self.targetPhraseIndex == targetPhraseIndex ? ordinal : 0
        guard current < Self.maximumOrdinal else {
            return Self(
                targetPhraseIndex: targetPhraseIndex,
                ordinal: Self.maximumOrdinal,
                exhausted: true
            )
        }
        return Self(
            targetPhraseIndex: targetPhraseIndex,
            ordinal: current + 1
        )
    }

    package func isExhausted(for targetPhraseIndex: Int) -> Bool {
        self.targetPhraseIndex == targetPhraseIndex && exhausted
    }
}

/// Versioned, durable reason identifiers. Raw values are report wire values;
/// adding a materially different meaning requires a new suffixed case rather
/// than silently reinterpreting an existing one.
package enum QualityReasonCode: String, CaseIterable, Codable, Hashable, Sendable {
    case policyUncalibratedV1 = "quality.policy-uncalibrated.v1"
    case evidenceMissingV1 = "quality.evidence-missing.v1"
    case evidenceNonFiniteV1 = "quality.evidence-non-finite.v1"
    case evaluatorUnavailableV1 = "quality.evaluator-unavailable.v1"
    case hardGateFailedV1 = "quality.hard-gate-failed.v1"
    case guardrailRegressionV1 = "quality.guardrail-regression.v1"
    case candidateQualifiedV1 = "quality.candidate-qualified.v1"
    case candidateAdjustedV1 = "quality.candidate-adjusted.v1"
    case staleEvidenceV1 = "quality.stale-evidence.v1"
    case routeRecoveryV1 = "quality.route-recovery.v1"
    case acceptanceProvenanceMissingV1 = "quality.acceptance-provenance-missing.v1"
    case evidenceMismatchV1 = "quality.evidence-mismatch.v1"
}

/// A reduced policy decision that can cross from DSP preparation into Core
/// continuation without carrying samples, analyzer types, or renderer state.
package struct QualityDecision: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let reasonCodeVersion: Int
    package let policyVersion: String
    package let outcome: QualityDecisionOutcome
    package let reasonCodes: [QualityReasonCode]
    package let candidateFingerprint: String?
    package let evidenceFingerprint: String?
    package let eligibleFutureSample: Int64?

    package init(
        policyVersion: String = QualityQualificationContract.uncalibratedPolicyVersion,
        outcome: QualityDecisionOutcome,
        reasonCodes: [QualityReasonCode],
        candidateFingerprint: String? = nil,
        evidenceFingerprint: String? = nil,
        eligibleFutureSample: Int64? = nil
    ) {
        schemaVersion = QualityQualificationContract.schemaVersion
        reasonCodeVersion = QualityQualificationContract.reasonCodeVersion
        let effectivePolicyVersion = policyVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty ? QualityQualificationContract.uncalibratedPolicyVersion : policyVersion
        self.policyVersion = effectivePolicyVersion
        let uncalibrated = effectivePolicyVersion ==
            QualityQualificationContract.uncalibratedPolicyVersion
        self.outcome = uncalibrated ? .qualificationUnavailable : outcome
        let truthfulReasons = uncalibrated
            ? reasonCodes.filter {
                $0 != .candidateQualifiedV1 && $0 != .candidateAdjustedV1
            } + [.policyUncalibratedV1]
            : reasonCodes
        self.reasonCodes = Array(Set(truthfulReasons)).sorted { $0.rawValue < $1.rawValue }
        self.candidateFingerprint = candidateFingerprint
        self.evidenceFingerprint = evidenceFingerprint
        self.eligibleFutureSample = eligibleFutureSample.map { max(0, $0) }
    }

    package static func qualificationUnavailable(
        policyVersion: String = QualityQualificationContract.uncalibratedPolicyVersion,
        candidateFingerprint: String? = nil,
        evidenceFingerprint: String? = nil,
        eligibleFutureSample: Int64? = nil
    ) -> QualityDecision {
        let effectivePolicyVersion = policyVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty ? QualityQualificationContract.uncalibratedPolicyVersion : policyVersion
        let reasons: [QualityReasonCode]
        if effectivePolicyVersion == QualityQualificationContract.uncalibratedPolicyVersion {
            reasons = [.policyUncalibratedV1]
        } else if evidenceFingerprint?.isEmpty == false {
            reasons = [.evaluatorUnavailableV1]
        } else {
            reasons = [.evidenceMissingV1]
        }
        return QualityDecision(
            policyVersion: effectivePolicyVersion,
            outcome: .qualificationUnavailable,
            reasonCodes: reasons,
            candidateFingerprint: candidateFingerprint,
            evidenceFingerprint: evidenceFingerprint,
            eligibleFutureSample: eligibleFutureSample
        )
    }

    package var isAcceptanceOutcome: Bool {
        outcome == .qualified || outcome == .adjusted
    }

    package var isStructurallyValid: Bool {
        let canonicalReasons = Array(Set(reasonCodes)).sorted {
            $0.rawValue < $1.rawValue
        }
        return schemaVersion == QualityQualificationContract.schemaVersion &&
            reasonCodeVersion == QualityQualificationContract.reasonCodeVersion &&
            !policyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            reasonCodes == canonicalReasons &&
            (eligibleFutureSample.map { $0 >= 0 } ?? true)
    }

    package var hasNonCompensableFailureReason: Bool {
        reasonCodes.contains(.hardGateFailedV1) ||
            reasonCodes.contains(.evidenceMissingV1) ||
            reasonCodes.contains(.evidenceNonFiniteV1) ||
            reasonCodes.contains(.evaluatorUnavailableV1) ||
            reasonCodes.contains(.guardrailRegressionV1) ||
            reasonCodes.contains(.staleEvidenceV1) ||
            reasonCodes.contains(.acceptanceProvenanceMissingV1) ||
            reasonCodes.contains(.evidenceMismatchV1)
    }

    /// Durable terminal reason codes must agree with the decision outcome.
    /// Transport continuity is deliberately not a quality-policy outcome.
    package var hasOutcomeConsistentReasonCodes: Bool {
        let qualified = reasonCodes.contains(.candidateQualifiedV1)
        let adjusted = reasonCodes.contains(.candidateAdjustedV1)
        let reportsUncalibrated = reasonCodes.contains(.policyUncalibratedV1)
        let isUncalibrated = policyVersion ==
            QualityQualificationContract.uncalibratedPolicyVersion
        guard !policyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              reportsUncalibrated == isUncalibrated,
              !isUncalibrated || outcome == .qualificationUnavailable else {
            return false
        }
        switch outcome {
        case .qualified:
            return qualified && !adjusted
        case .adjusted:
            return adjusted && !qualified
        case .rejected:
            return !qualified && !adjusted && hasNonCompensableFailureReason
        case .qualificationUnavailable:
            return !qualified && !adjusted && (
                reportsUncalibrated ||
                    reasonCodes.contains(.evaluatorUnavailableV1) ||
                    reasonCodes.contains(.evidenceMissingV1) ||
                    reasonCodes.contains(.evidenceNonFiniteV1)
            )
        }
    }
}

/// Persistent, bounded policy provenance for future unscheduled decisions.
/// Observed fingerprints describe the selected prepared phrase even while the
/// policy is unavailable. Accepted fingerprints remain an atomic snapshot of
/// the last qualified/adjusted phrase. Signal-domain owners stay in DSP.
package struct QualityContinuationState: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let revision: Int
    package let policyVersion: String
    package let lastDecision: QualityDecision
    package let acceptedPolicyVersion: String?
    package let acceptedCandidateFingerprint: String?
    package let acceptedEvidenceFingerprint: String?
    package let acceptedControllerStateFingerprint: String?
    package let earliestEligibleFutureSample: Int64?
    package let observedCandidateFingerprint: String?
    package let observedEvidenceFingerprint: String?
    package let observedControllerStateFingerprint: String?

    package init(
        revision: Int = 0,
        lastDecision: QualityDecision = .qualificationUnavailable(),
        acceptedPolicyVersion: String? = nil,
        acceptedCandidateFingerprint: String? = nil,
        acceptedEvidenceFingerprint: String? = nil,
        acceptedControllerStateFingerprint: String? = nil,
        earliestEligibleFutureSample: Int64? = nil,
        observedCandidateFingerprint: String? = nil,
        observedEvidenceFingerprint: String? = nil,
        observedControllerStateFingerprint: String? = nil
    ) {
        schemaVersion = QualityQualificationContract.schemaVersion
        self.revision = max(0, revision)
        policyVersion = lastDecision.policyVersion
        self.lastDecision = lastDecision
        self.acceptedPolicyVersion = acceptedPolicyVersion
        self.acceptedCandidateFingerprint = acceptedCandidateFingerprint
        self.acceptedEvidenceFingerprint = acceptedEvidenceFingerprint
        self.acceptedControllerStateFingerprint = acceptedControllerStateFingerprint
        self.earliestEligibleFutureSample = earliestEligibleFutureSample.map { max(0, $0) }
        self.observedCandidateFingerprint = observedCandidateFingerprint
        self.observedEvidenceFingerprint = observedEvidenceFingerprint
        self.observedControllerStateFingerprint = observedControllerStateFingerprint
    }

    package func recording(
        decision: QualityDecision,
        evidenceFingerprint: String?,
        controllerStateFingerprint: String? = nil,
        earliestEligibleFutureSample: Int64? = nil
    ) -> QualityContinuationState {
        let requestsAcceptance = decision.isAcceptanceOutcome
        let candidatePresent = !(decision.candidateFingerprint?.isEmpty ?? true)
        let decisionEvidencePresent = !(decision.evidenceFingerprint?.isEmpty ?? true)
        let observedEvidencePresent = !(evidenceFingerprint?.isEmpty ?? true)
        let controllerPresent = !(controllerStateFingerprint?.isEmpty ?? true)
        let evidenceMatches = decision.evidenceFingerprint != nil &&
            evidenceFingerprint == decision.evidenceFingerprint
        let hardFailureReasoned = decision.hasNonCompensableFailureReason
        let outcomeReasonsMatch = decision.hasOutcomeConsistentReasonCodes
        let completeAcceptance = requestsAcceptance && candidatePresent &&
            decisionEvidencePresent && observedEvidencePresent &&
            controllerPresent && evidenceMatches &&
            !hardFailureReasoned && outcomeReasonsMatch
        let effectiveDecision: QualityDecision
        if !outcomeReasonsMatch {
            let reasons = decision.reasonCodes.filter {
                $0 != .candidateQualifiedV1 &&
                    $0 != .candidateAdjustedV1
            } + [.hardGateFailedV1]
            effectiveDecision = QualityDecision(
                policyVersion: decision.policyVersion,
                outcome: .rejected,
                reasonCodes: reasons,
                candidateFingerprint: decision.candidateFingerprint,
                evidenceFingerprint: evidenceFingerprint,
                eligibleFutureSample: decision.eligibleFutureSample
            )
        } else if requestsAcceptance && !completeAcceptance {
            var reasons = decision.reasonCodes.filter {
                $0 != .candidateQualifiedV1 && $0 != .candidateAdjustedV1
            } + [.hardGateFailedV1]
            if !candidatePresent || !decisionEvidencePresent ||
                !observedEvidencePresent || !controllerPresent {
                reasons.append(.acceptanceProvenanceMissingV1)
            }
            if decisionEvidencePresent && !(evidenceFingerprint?.isEmpty ?? true) &&
                !evidenceMatches {
                reasons.append(.evidenceMismatchV1)
            }
            effectiveDecision = QualityDecision(
                policyVersion: decision.policyVersion,
                outcome: .rejected,
                reasonCodes: reasons,
                candidateFingerprint: decision.candidateFingerprint,
                evidenceFingerprint: evidenceFingerprint ?? decision.evidenceFingerprint,
                eligibleFutureSample: decision.eligibleFutureSample
            )
        } else {
            effectiveDecision = decision
        }
        let acceptsEvidence = effectiveDecision.isAcceptanceOutcome
        let nextEvidence = acceptsEvidence
            ? (evidenceFingerprint ?? acceptedEvidenceFingerprint)
            : acceptedEvidenceFingerprint
        let nextAcceptedPolicy = acceptsEvidence
            ? effectiveDecision.policyVersion
            : acceptedPolicyVersion
        let nextCandidate = acceptsEvidence
            ? (effectiveDecision.candidateFingerprint ?? acceptedCandidateFingerprint)
            : acceptedCandidateFingerprint
        let nextController = acceptsEvidence
            ? (controllerStateFingerprint ?? self.acceptedControllerStateFingerprint)
            : self.acceptedControllerStateFingerprint
        let acceptedBoundaryCandidates = [
            self.earliestEligibleFutureSample,
            effectiveDecision.eligibleFutureSample,
            earliestEligibleFutureSample,
        ].compactMap { $0 }
        // Every value is a minimum future boundary. Combining them with max
        // prevents an accepted observation from moving an existing or declared
        // sample-index safety boundary backwards.
        let nextBoundary = acceptsEvidence
            ? acceptedBoundaryCandidates.max()
            : self.earliestEligibleFutureSample
        return QualityContinuationState(
            revision: revision == Int.max ? Int.max : revision + 1,
            lastDecision: effectiveDecision,
            acceptedPolicyVersion: nextAcceptedPolicy,
            acceptedCandidateFingerprint: nextCandidate,
            acceptedEvidenceFingerprint: nextEvidence,
            acceptedControllerStateFingerprint: nextController,
            earliestEligibleFutureSample: nextBoundary,
            observedCandidateFingerprint: effectiveDecision.candidateFingerprint,
            observedEvidenceFingerprint: evidenceFingerprint,
            observedControllerStateFingerprint: controllerStateFingerprint
        )
    }

    package var acceptanceProvenanceComplete: Bool {
        guard isStructurallyValid else { return false }
        let accepts = lastDecision.isAcceptanceOutcome
        guard accepts else { return true }
        guard lastDecision.hasOutcomeConsistentReasonCodes,
              !lastDecision.hasNonCompensableFailureReason,
              !lastDecision.policyVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              let acceptedPolicyVersion,
              !acceptedPolicyVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty else { return false }
        guard let candidate = lastDecision.candidateFingerprint, !candidate.isEmpty,
              let evidence = lastDecision.evidenceFingerprint, !evidence.isEmpty,
              let observedControllerStateFingerprint,
              !observedControllerStateFingerprint.isEmpty else {
            return false
        }
        if let declaredBoundary = lastDecision.eligibleFutureSample {
            guard let retainedBoundary = earliestEligibleFutureSample,
                  retainedBoundary >= declaredBoundary else {
                return false
            }
        }
        return acceptedPolicyVersion == lastDecision.policyVersion &&
            acceptedCandidateFingerprint == candidate &&
            acceptedEvidenceFingerprint == evidence &&
            acceptedControllerStateFingerprint == observedControllerStateFingerprint &&
            observedCandidateFingerprint == candidate &&
            observedEvidenceFingerprint == evidence
    }

    package var isStructurallyValid: Bool {
        let acceptedSnapshot = [
            acceptedPolicyVersion,
            acceptedCandidateFingerprint,
            acceptedEvidenceFingerprint,
            acceptedControllerStateFingerprint,
        ]
        let acceptedValueCount = acceptedSnapshot.compactMap { $0 }.count
        let acceptedSnapshotIsAtomic = acceptedValueCount == 0 ||
            acceptedValueCount == acceptedSnapshot.count
        let acceptingDecisionHasSnapshot = !lastDecision.isAcceptanceOutcome ||
            acceptedValueCount == acceptedSnapshot.count
        let acceptedPolicyIsCalibrated = acceptedPolicyVersion.map {
            $0 != QualityQualificationContract.uncalibratedPolicyVersion
        } ?? true
        let acceptedBoundaryHasOwner = earliestEligibleFutureSample == nil ||
            acceptedValueCount == acceptedSnapshot.count
        let revisionZeroHasNoAcceptedHistory = revision != 0 ||
            (acceptedValueCount == 0 && earliestEligibleFutureSample == nil)
        let revisionZeroHasNoObservedHistory = revision != 0 ||
            (observedCandidateFingerprint == nil &&
                observedEvidenceFingerprint == nil &&
                observedControllerStateFingerprint == nil)
        let optionalFingerprints = [
            acceptedPolicyVersion,
            acceptedCandidateFingerprint,
            acceptedEvidenceFingerprint,
            acceptedControllerStateFingerprint,
            observedCandidateFingerprint,
            observedEvidenceFingerprint,
            observedControllerStateFingerprint,
        ]
        let observedCandidateMatches = observedCandidateFingerprint ==
            lastDecision.candidateFingerprint
        let evidenceMayBeMissing = lastDecision.reasonCodes.contains(
            .acceptanceProvenanceMissingV1
        ) || lastDecision.reasonCodes.contains(.evidenceMissingV1)
        let observedEvidenceMatches: Bool
        if observedEvidenceFingerprint == lastDecision.evidenceFingerprint {
            observedEvidenceMatches = true
        } else {
            observedEvidenceMatches = observedEvidenceFingerprint == nil &&
                lastDecision.evidenceFingerprint != nil && evidenceMayBeMissing
        }
        return schemaVersion == QualityQualificationContract.schemaVersion &&
            revision >= 0 && policyVersion == lastDecision.policyVersion &&
            lastDecision.isStructurallyValid &&
            lastDecision.hasOutcomeConsistentReasonCodes &&
            acceptedSnapshotIsAtomic && acceptedPolicyIsCalibrated &&
            acceptingDecisionHasSnapshot && acceptedBoundaryHasOwner &&
            revisionZeroHasNoAcceptedHistory && revisionZeroHasNoObservedHistory &&
            observedCandidateMatches && observedEvidenceMatches &&
            (earliestEligibleFutureSample.map { $0 >= 0 } ?? true) &&
            optionalFingerprints.allSatisfy {
                $0.map {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                } ?? true
            }
    }
}
