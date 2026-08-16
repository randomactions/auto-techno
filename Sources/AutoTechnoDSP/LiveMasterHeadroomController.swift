import AutoTechnoCore
import Foundation

/// Pure background-only transition from one exact app-owned live observation
/// to one bounded Core proposal. It never mutates the committed continuation;
/// the primary candidate transaction remains the only commit boundary.
package enum LiveMasterHeadroomController {
    package static let version = LiveFeedbackContract.controllerPolicyVersion
    package static let minimumTrimDB = -3.0
    package static let maximumTrimDB = 0.0
    package static let attackStepDB = 0.25
    package static let recoveryStepDB = 0.125
    package static let cleanWindowsForRecovery = 2

    package static func propose(
        evidence: LiveOutputWindowEvidence?,
        target: LiveMasterHeadroomTarget?,
        incoming: LiveMasterHeadroomContinuationState,
        earliestEligibleFutureSample: Int64
    ) -> LiveMasterHeadroomProposal {
        guard let evidence else {
            return unavailable(
                evidence: nil,
                target: target,
                incoming: incoming,
                reason: .windowIncomplete,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }
        guard let target else {
            return unavailable(
                evidence: evidence,
                target: nil,
                incoming: incoming,
                reason: .profileUnavailable,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }
        guard evidence.isStructurallyValid else {
            return unavailable(
                evidence: evidence,
                target: target,
                incoming: incoming,
                reason: .evidenceNonFinite,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }
        guard target.isStructurallyValid(sourceEvidence: evidence) else {
            return unavailable(
                evidence: evidence,
                target: target,
                incoming: incoming,
                reason: sourcePairingMatches(evidence: evidence, target: target)
                    ? .profileUnavailable
                    : .routeMismatch,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }
        guard evidence.controllerPolicyVersion == version,
              target.controllerPolicyVersion == version,
              evidence.controllerRevision == incoming.revision,
              incoming.revision < Int.max,
              sourcePhraseIsNew(evidence.phraseIndex, incoming: incoming),
              earliestEligibleFutureSample >= 0,
              earliestEligibleFutureSample >
                evidence.playerSampleRange.upperBound else {
            return unavailable(
                evidence: evidence,
                target: target,
                incoming: incoming,
                reason: .staleProposal,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }
        guard evidence.complete, evidence.isActiveProgram else {
            return unavailable(
                evidence: evidence,
                target: target,
                incoming: incoming,
                reason: .windowIncomplete,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }

        let loudnessExcess = evidence.maximumShortTermLoudnessLUFS -
            target.loudnessUpperLUFS
        let truePeakExcess = evidence.truePeakDBTP - target.truePeakUpperDBTP
        let excessDB = max(loudnessExcess, truePeakExcess, 0)
        guard excessDB.isFinite else {
            return unavailable(
                evidence: evidence,
                target: target,
                incoming: incoming,
                reason: .evidenceNonFinite,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }

        if excessDB > 0 {
            let step = min(attackStepDB, excessDB)
            let proposedTrimDB = max(
                minimumTrimDB,
                incoming.committedTrimDB - step
            )
            return accepted(
                evidence: evidence,
                target: target,
                incoming: incoming,
                outcome: proposedTrimDB < incoming.committedTrimDB
                    ? .attenuate
                    : .hold,
                reasonCodes: proposedTrimDB < incoming.committedTrimDB
                    ? [.windowAccepted]
                    : [.windowAccepted, .masterTrimSaturatedV1],
                proposedTrimDB: proposedTrimDB,
                proposedCleanWindows: 0,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }

        let belowBothMidpoints =
            evidence.maximumShortTermLoudnessLUFS <=
                target.loudnessMidpointLUFS &&
            evidence.truePeakDBTP <= target.truePeakMidpointDBTP
        guard belowBothMidpoints else {
            return accepted(
                evidence: evidence,
                target: target,
                incoming: incoming,
                outcome: .hold,
                reasonCodes: [.windowAccepted],
                proposedTrimDB: incoming.committedTrimDB,
                proposedCleanWindows: 0,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }

        guard incoming.committedTrimDB < maximumTrimDB else {
            return accepted(
                evidence: evidence,
                target: target,
                incoming: incoming,
                outcome: .hold,
                reasonCodes: [.windowAccepted],
                proposedTrimDB: maximumTrimDB,
                proposedCleanWindows: 0,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }
        let increment = incoming.consecutiveCleanWindows
            .addingReportingOverflow(1)
        let cleanWindows = increment.overflow
            ? cleanWindowsForRecovery
            : min(cleanWindowsForRecovery, increment.partialValue)
        guard cleanWindows >= cleanWindowsForRecovery else {
            return accepted(
                evidence: evidence,
                target: target,
                incoming: incoming,
                outcome: .hold,
                reasonCodes: [.windowAccepted],
                proposedTrimDB: incoming.committedTrimDB,
                proposedCleanWindows: cleanWindows,
                earliestEligibleFutureSample: earliestEligibleFutureSample
            )
        }

        return accepted(
            evidence: evidence,
            target: target,
            incoming: incoming,
            outcome: .recover,
            reasonCodes: [.windowAccepted],
            proposedTrimDB: min(
                maximumTrimDB,
                incoming.committedTrimDB + recoveryStepDB
            ),
            proposedCleanWindows: 0,
            earliestEligibleFutureSample: earliestEligibleFutureSample
        )
    }

    private static func accepted(
        evidence: LiveOutputWindowEvidence,
        target: LiveMasterHeadroomTarget,
        incoming: LiveMasterHeadroomContinuationState,
        outcome: LiveFeedbackProposalOutcome,
        reasonCodes: [LiveFeedbackReason],
        proposedTrimDB: Double,
        proposedCleanWindows: Int,
        earliestEligibleFutureSample: Int64
    ) -> LiveMasterHeadroomProposal {
        LiveMasterHeadroomProposal(
            controllerPolicyVersion: version,
            targetFingerprint: target.fingerprint,
            sourcePhraseIndex: evidence.phraseIndex,
            sourcePlanFingerprint: evidence.planFingerprint,
            routeGeneration: evidence.routeGeneration,
            playerSampleRange: evidence.playerSampleRange,
            observationFingerprint: evidence.fingerprint,
            incomingRevision: incoming.revision,
            incomingStateFingerprint: incoming.fingerprint,
            outcome: outcome,
            reasonCodes: reasonCodes,
            proposedTrimDB: proposedTrimDB,
            proposedCleanWindows: proposedCleanWindows,
            earliestEligibleFutureSample: earliestEligibleFutureSample
        )
    }

    private static func unavailable(
        evidence: LiveOutputWindowEvidence?,
        target: LiveMasterHeadroomTarget?,
        incoming: LiveMasterHeadroomContinuationState,
        reason: LiveFeedbackReason,
        earliestEligibleFutureSample: Int64
    ) -> LiveMasterHeadroomProposal {
        let sourcePhraseIndex = evidence?.phraseIndex ?? target?.phraseIndex ?? 0
        let sourcePlanFingerprint = evidence?.planFingerprint ??
            target?.planFingerprint ?? "<unavailable>"
        let routeGeneration = evidence?.routeGeneration ??
            target?.routeGeneration ?? 0
        let playerSampleRange = evidence?.playerSampleRange ??
            target?.playerSampleRange ?? 0..<1
        return LiveMasterHeadroomProposal(
            controllerPolicyVersion: version,
            targetFingerprint: target?.fingerprint ??
                LiveMasterHeadroomProposal.unavailableTargetFingerprint,
            sourcePhraseIndex: sourcePhraseIndex,
            sourcePlanFingerprint: sourcePlanFingerprint,
            routeGeneration: routeGeneration,
            playerSampleRange: playerSampleRange,
            observationFingerprint: evidence?.fingerprint,
            incomingRevision: incoming.revision,
            incomingStateFingerprint: incoming.fingerprint,
            outcome: .unavailable,
            reasonCodes: [reason],
            proposedTrimDB: incoming.committedTrimDB,
            proposedCleanWindows: incoming.consecutiveCleanWindows,
            earliestEligibleFutureSample: earliestEligibleFutureSample
        )
    }

    private static func sourcePhraseIsNew(
        _ sourcePhraseIndex: Int,
        incoming: LiveMasterHeadroomContinuationState
    ) -> Bool {
        incoming.lastAcceptedSourcePhraseIndex.map {
            sourcePhraseIndex > $0
        } ?? true
    }

    private static func sourcePairingMatches(
        evidence: LiveOutputWindowEvidence,
        target: LiveMasterHeadroomTarget
    ) -> Bool {
        target.sourceObservationFingerprint == evidence.fingerprint &&
            target.phraseIndex == evidence.phraseIndex &&
            target.planFingerprint == evidence.planFingerprint &&
            target.routeGeneration == evidence.routeGeneration &&
            target.controllerRevision == evidence.controllerRevision &&
            target.playerSampleRange == evidence.playerSampleRange &&
            target.sampleRate == evidence.sampleRate &&
            target.applicableCheckpoints == evidence.applicableCheckpoints
    }
}
