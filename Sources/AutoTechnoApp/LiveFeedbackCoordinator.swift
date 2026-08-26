import AutoTechnoCore
import AutoTechnoDSP
import CAutoTechnoRealtime
import Dispatch
import Foundation

/// Immutable transport provenance for one scheduled occurrence of an accepted
/// phrase. Repeating the same plan uses a new player sample range and therefore
/// remains a distinct ledger record.
package struct ScheduledPhraseRange: Equatable, Hashable, Sendable {
    package let phraseIndex: Int
    package let planFingerprint: String
    package let playerSampleRange: Range<Int64>
    package let mixerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let routeGeneration: Int
    package let occurrenceEpoch: UInt64
    package let controllerRevision: Int
    package let qualityPolicyVersion: String
    package let evaluatorVersion: String
    package let controllerPolicyVersion: String
    package let controllerStateFingerprint: String
    package let appliedMasterTrimDB: Double
    package let applicableCheckpoints: [CanonicalJourneyCheckpoint]
    package let earliestEligibleFutureSample: Int64

    package init(
        phraseIndex: Int,
        planFingerprint: String,
        playerSampleRange: Range<Int64>,
        mixerSampleRange: Range<Int64>,
        sampleRate: Double,
        routeGeneration: Int,
        occurrenceEpoch: UInt64 = 0,
        controllerRevision: Int,
        qualityPolicyVersion: String,
        evaluatorVersion: String,
        controllerPolicyVersion: String,
        controllerStateFingerprint: String,
        appliedMasterTrimDB: Double,
        applicableCheckpoints: [CanonicalJourneyCheckpoint],
        earliestEligibleFutureSample: Int64
    ) {
        self.phraseIndex = phraseIndex
        self.planFingerprint = planFingerprint
        self.playerSampleRange = playerSampleRange
        self.mixerSampleRange = mixerSampleRange
        self.sampleRate = sampleRate
        self.routeGeneration = routeGeneration
        self.occurrenceEpoch = occurrenceEpoch
        self.controllerRevision = controllerRevision
        self.qualityPolicyVersion = qualityPolicyVersion
        self.evaluatorVersion = evaluatorVersion
        self.controllerPolicyVersion = controllerPolicyVersion
        self.controllerStateFingerprint = controllerStateFingerprint
        self.appliedMasterTrimDB = appliedMasterTrimDB
        self.applicableCheckpoints = applicableCheckpoints
        self.earliestEligibleFutureSample = earliestEligibleFutureSample
    }

    package init(
        copying source: ScheduledPhraseRange,
        mixerSampleRange: Range<Int64>? = nil,
        evaluatorVersion: String? = nil,
        appliedMasterTrimDB: Double? = nil
    ) {
        self.init(
            phraseIndex: source.phraseIndex,
            planFingerprint: source.planFingerprint,
            playerSampleRange: source.playerSampleRange,
            mixerSampleRange: mixerSampleRange ?? source.mixerSampleRange,
            sampleRate: source.sampleRate,
            routeGeneration: source.routeGeneration,
            occurrenceEpoch: source.occurrenceEpoch,
            controllerRevision: source.controllerRevision,
            qualityPolicyVersion: source.qualityPolicyVersion,
            evaluatorVersion: evaluatorVersion ?? source.evaluatorVersion,
            controllerPolicyVersion: source.controllerPolicyVersion,
            controllerStateFingerprint: source.controllerStateFingerprint,
            appliedMasterTrimDB:
                appliedMasterTrimDB ?? source.appliedMasterTrimDB,
            applicableCheckpoints: source.applicableCheckpoints,
            earliestEligibleFutureSample:
                source.earliestEligibleFutureSample
        )
    }

    package func isStructurallyValid(
        clockMap: MixerPlayerClockMap
    ) -> Bool {
        guard phraseIndex >= 0,
              !planFingerprint.isEmpty,
              playerSampleRange.lowerBound >= 0,
              !playerSampleRange.isEmpty,
              !mixerSampleRange.isEmpty,
              sampleRate == clockMap.sampleRate,
              routeGeneration >= 0,
              controllerRevision >= 0,
              !qualityPolicyVersion.isEmpty,
              evaluatorVersion == ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier,
              controllerPolicyVersion == LiveFeedbackContract
                .controllerPolicyVersion,
              canonicalFingerprint(controllerStateFingerprint),
              appliedMasterTrimDB.isFinite,
              appliedMasterTrimDB >= -3,
              appliedMasterTrimDB <= 0,
              !applicableCheckpoints.isEmpty,
              Set(applicableCheckpoints).count == applicableCheckpoints.count,
              earliestEligibleFutureSample ==
                playerSampleRange.upperBound,
              let expectedMixerLower = clockMap.checkedMixerSample(
                forPlayerSample: playerSampleRange.lowerBound
              ),
              let expectedMixerUpper = clockMap.checkedMixerSample(
                forPlayerSample: playerSampleRange.upperBound
              ) else { return false }
        return mixerSampleRange == expectedMixerLower..<expectedMixerUpper
    }

    private func canonicalFingerprint(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Bounded transport ledger: current playback, its one scheduled successor,
/// and the two most recent occurrences. It is sample provenance, not another
/// musical timeline.
package struct ScheduledPhraseLedger: Equatable, Sendable {
    package private(set) var playing: ScheduledPhraseRange?
    package private(set) var scheduledSuccessor: ScheduledPhraseRange?
    private var recent0: ScheduledPhraseRange?
    private var recent1: ScheduledPhraseRange?

    package init() {}

    package var retainedRanges: [ScheduledPhraseRange] {
        var result: [ScheduledPhraseRange] = []
        result.reserveCapacity(4)
        forEachRetained { result.append($0) }
        return result
    }

    package var recent: [ScheduledPhraseRange] {
        [recent0, recent1].compactMap { $0 }
    }

    package mutating func setPlaying(_ range: ScheduledPhraseRange?) {
        guard playing != range else {
            if scheduledSuccessor == range { scheduledSuccessor = nil }
            return
        }
        if let previous = playing {
            if recent0 != previous {
                recent1 = recent0
                recent0 = previous
            }
        }
        if let range {
            if recent0 == range {
                recent0 = recent1
                recent1 = nil
            } else if recent1 == range {
                recent1 = nil
            }
        }
        playing = range
        scheduledSuccessor = nil
    }

    package mutating func setScheduledSuccessor(_ range: ScheduledPhraseRange?) {
        guard range != playing else {
            scheduledSuccessor = nil
            return
        }
        scheduledSuccessor = range
        if let range {
            if recent0 == range {
                recent0 = recent1
                recent1 = nil
            } else if recent1 == range {
                recent1 = nil
            }
        }
    }

    package func contains(_ range: ScheduledPhraseRange) -> Bool {
        playing == range || scheduledSuccessor == range ||
            recent0 == range || recent1 == range
    }

    package func isExactPlayingOccurrence(
        _ range: ScheduledPhraseRange
    ) -> Bool {
        playing == range
    }

    package func hasScheduledOrPlayingOccurrence(
        phraseIndex: Int,
        excluding source: ScheduledPhraseRange
    ) -> Bool {
        (playing.map { $0 != source && $0.phraseIndex == phraseIndex } ?? false) ||
            (scheduledSuccessor.map {
                $0 != source && $0.phraseIndex == phraseIndex
            } ?? false)
    }

    fileprivate func forEachRetained(
        _ body: (ScheduledPhraseRange) -> Void
    ) {
        if let playing { body(playing) }
        if let scheduledSuccessor { body(scheduledSuccessor) }
        if let recent0 { body(recent0) }
        if let recent1 { body(recent1) }
    }

    fileprivate func firstWindowRange(
        overlapping sampleRange: Range<Int64>,
        frameCount: Int64
    ) -> ScheduledPhraseRange? {
        var match: ScheduledPhraseRange?
        forEachRetained { range in
            guard match == nil else { return }
            let end = range.playerSampleRange.lowerBound
                .addingReportingOverflow(frameCount)
            guard !end.overflow else { return }
            let window = range.playerSampleRange.lowerBound..<end.partialValue
            if window.overlaps(sampleRange) { match = range }
        }
        return match
    }
}

package enum LiveFeedbackFutureBoundaryDecision: Equatable, Sendable {
    case invalidateUnscheduledSuccessor
    case deferAlreadyScheduledSuccessor
    case duplicateSourcePhrase
    case invalidPhraseRelationship
}

package struct LiveFeedbackWorkerIdentity: Equatable, Hashable, Sendable {
    package let lifecycleToken: UInt64
    package let coordinatorID: UInt64
    package let routeGeneration: Int
    package let occurrenceEpoch: UInt64

    package init(
        lifecycleToken: UInt64,
        coordinatorID: UInt64,
        routeGeneration: Int,
        occurrenceEpoch: UInt64 = 0
    ) {
        self.lifecycleToken = lifecycleToken
        self.coordinatorID = coordinatorID
        self.routeGeneration = routeGeneration
        self.occurrenceEpoch = occurrenceEpoch
    }
}

/// Only a real coordinator can mint consumer ownership and joined proof. The
/// explicit initializers are file-private so another package caller cannot
/// bind or destroy queue storage around a worker it does not own.
package struct LivePCMConsumerStartPermit: Sendable {
    package let identity: LiveFeedbackWorkerIdentity
    fileprivate init(identity: LiveFeedbackWorkerIdentity) {
        self.identity = identity
    }
}

package struct LivePCMConsumerStopProof: Equatable, Sendable {
    package let identity: LiveFeedbackWorkerIdentity
    package let token: UUID
    fileprivate init(lease: LivePCMConsumerLease) {
        identity = lease.identity
        token = lease.token
    }
}

package enum LiveFeedbackCaptureOwnership: Equatable, Sendable {
    case inactive
    case queueReady
    case consumerRunning
    case producerEnabled
}

package struct AcceptedPCMHold: Equatable, Sendable {
    package let sourceOccurrence: ScheduledPhraseRange
    package let targetPhraseIndex: Int
    package let proposalFingerprint: String
    package var preserveCoursePreparationReleased: Bool

    package init(
        sourceOccurrence: ScheduledPhraseRange,
        targetPhraseIndex: Int,
        proposalFingerprint: String,
        preserveCoursePreparationReleased: Bool = false
    ) {
        self.sourceOccurrence = sourceOccurrence
        self.targetPhraseIndex = targetPhraseIndex
        self.proposalFingerprint = proposalFingerprint
        self.preserveCoursePreparationReleased =
            preserveCoursePreparationReleased
    }

    package var sourcePhraseIndex: Int { sourceOccurrence.phraseIndex }
}

package enum LiveCorrectedSuccessorBoundaryDecision: Equatable, Sendable {
    case advance
    case repeatAfterExpiringProposal
}

/// Pure admission check for the App-owned target sample. The scheduler calls
/// this before it removes a cached candidate or advances any musical state.
package enum LiveCorrectedSuccessorBoundaryPolicy {
    package static func decide(
        hasLiveProposal: Bool,
        preparedTargetStartSample: Int64?,
        earliestEligibleFutureSample: Int64?,
        actualStartSample: Int64
    ) -> LiveCorrectedSuccessorBoundaryDecision {
        guard hasLiveProposal else { return .advance }
        guard actualStartSample > 0,
              let preparedTargetStartSample,
              let earliestEligibleFutureSample,
              preparedTargetStartSample == actualStartSample,
              actualStartSample >= earliestEligibleFutureSample else {
            return .repeatAfterExpiringProposal
        }
        return .advance
    }
}

private struct AuthorizedLiveFeedbackCorrection: Equatable, Sendable {
    let sourceOccurrence: ScheduledPhraseRange
    let targetPhraseIndex: Int
    let proposalFingerprint: String

    var sourcePhraseIndex: Int { sourceOccurrence.phraseIndex }
}

/// Main-actor owner of live-feedback lifecycle identity, capture ownership,
/// future-only invalidation, and accepted-PCM hold. `TechnoEngine` calls these
/// executable methods around its real queue/cache/preparation operations.
@MainActor
package final class LiveFeedbackRuntimeCoordinator {
    package static let maximumRetainedInvalidatedSources = 4
    package private(set) var routeGeneration: Int
    package private(set) var occurrenceEpoch: UInt64
    package private(set) var lifecycleToken: UInt64 = 0
    package private(set) var activeIdentity: LiveFeedbackWorkerIdentity?
    package private(set) var captureOwnership: LiveFeedbackCaptureOwnership =
        .inactive
    package private(set) var acceptedPCMHold: AcceptedPCMHold?
    package private(set) var invalidatedSourceOccurrences:
        Set<ScheduledPhraseRange> = []

    private var nextCoordinatorID: UInt64 = 0
    private var authorizedCorrection: AuthorizedLiveFeedbackCorrection?

    package init(
        routeGeneration: Int,
        occurrenceEpoch: UInt64 = 0
    ) {
        self.routeGeneration = max(0, routeGeneration)
        self.occurrenceEpoch = occurrenceEpoch
    }

    package func resume(routeGeneration: Int) {
        advanceLifecycleToken()
        self.routeGeneration = max(0, routeGeneration)
        activeIdentity = nil
        captureOwnership = .inactive
    }

    package func recreateCoordinator(
        routeGeneration: Int
    ) -> LiveFeedbackWorkerIdentity {
        advanceLifecycleToken()
        self.routeGeneration = max(0, routeGeneration)
        precondition(nextCoordinatorID < .max,
                     "live feedback coordinator identity exhausted")
        nextCoordinatorID += 1
        let identity = LiveFeedbackWorkerIdentity(
            lifecycleToken: lifecycleToken,
            coordinatorID: nextCoordinatorID,
            routeGeneration: self.routeGeneration,
            occurrenceEpoch: occurrenceEpoch
        )
        activeIdentity = identity
        captureOwnership = .queueReady
        return identity
    }

    @discardableResult
    package func consumerDidStart(
        identity: LiveFeedbackWorkerIdentity
    ) -> Bool {
        guard identity == activeIdentity,
              captureOwnership == .queueReady else { return false }
        captureOwnership = .consumerRunning
        return true
    }

    @discardableResult
    package func producerDidStart(
        identity: LiveFeedbackWorkerIdentity
    ) -> Bool {
        guard identity == activeIdentity,
              captureOwnership == .consumerRunning else { return false }
        captureOwnership = .producerEnabled
        return true
    }

    package func pause() {
        if let correction = authorizedCorrection {
            acceptedPCMHold = AcceptedPCMHold(
                sourceOccurrence: correction.sourceOccurrence,
                targetPhraseIndex: correction.targetPhraseIndex,
                proposalFingerprint: correction.proposalFingerprint
            )
        }
        authorizedCorrection = nil
        invalidateActiveWorker()
    }

    package func clockMapFailed() {
        if let correction = authorizedCorrection {
            acceptedPCMHold = AcceptedPCMHold(
                sourceOccurrence: correction.sourceOccurrence,
                targetPhraseIndex: correction.targetPhraseIndex,
                proposalFingerprint: correction.proposalFingerprint
            )
        }
        authorizedCorrection = nil
        invalidateActiveWorker()
    }

    /// Authenticates a reset of the player's sample timeline independently of
    /// route and preparation generations. Accepted PCM remains held, while all
    /// worker results and scheduled occurrences from the old timeline expire.
    @discardableResult
    package func resetPlaybackTimeline(routeGeneration: Int) -> Bool {
        if let correction = authorizedCorrection {
            acceptedPCMHold = AcceptedPCMHold(
                sourceOccurrence: correction.sourceOccurrence,
                targetPhraseIndex: correction.targetPhraseIndex,
                proposalFingerprint: correction.proposalFingerprint
            )
        }
        authorizedCorrection = nil
        invalidateActiveWorker()
        self.routeGeneration = max(0, routeGeneration)
        guard occurrenceEpoch < .max else { return false }
        occurrenceEpoch += 1
        return true
    }

    package func routeReset(routeGeneration: Int) {
        invalidateActiveWorker()
        self.routeGeneration = max(0, routeGeneration)
        if let correction = authorizedCorrection {
            acceptedPCMHold = AcceptedPCMHold(
                sourceOccurrence: correction.sourceOccurrence,
                targetPhraseIndex: correction.targetPhraseIndex,
                proposalFingerprint: correction.proposalFingerprint
            )
        }
        authorizedCorrection = nil
        invalidatedSourceOccurrences.removeAll(keepingCapacity: true)
    }

    package func sessionReset(routeGeneration: Int) {
        invalidateActiveWorker()
        self.routeGeneration = max(0, routeGeneration)
        acceptedPCMHold = nil
        authorizedCorrection = nil
        invalidatedSourceOccurrences.removeAll(keepingCapacity: true)
    }

    package func shutdown() {
        invalidateActiveWorker()
        acceptedPCMHold = nil
        authorizedCorrection = nil
        invalidatedSourceOccurrences.removeAll(keepingCapacity: false)
    }

    package func authorizeCorrection(
        identity: LiveFeedbackWorkerIdentity,
        sourceOccurrence: ScheduledPhraseRange,
        targetPhraseIndex: Int,
        proposalFingerprint: String,
        sourceIsExactPlayingOccurrence: Bool,
        targetHasScheduledSamples: Bool
    ) -> LiveFeedbackFutureBoundaryDecision {
        guard identity == activeIdentity,
              captureOwnership == .producerEnabled,
              identity.routeGeneration == routeGeneration,
              identity.occurrenceEpoch == occurrenceEpoch,
              sourceIsExactPlayingOccurrence,
              sourceOccurrence.routeGeneration == routeGeneration,
              sourceOccurrence.occurrenceEpoch == occurrenceEpoch,
              sourceOccurrence.sampleRate.isFinite,
              !sourceOccurrence.playerSampleRange.isEmpty,
              !sourceOccurrence.planFingerprint.isEmpty,
              sourceOccurrence.phraseIndex >= 0,
              sourceOccurrence.phraseIndex < Int.max,
              targetPhraseIndex == sourceOccurrence.phraseIndex + 1,
              !proposalFingerprint.isEmpty else {
            return .invalidPhraseRelationship
        }
        guard !targetHasScheduledSamples else {
            return .deferAlreadyScheduledSuccessor
        }

        // Once an authorized correction fails, preserve-course recovery owns
        // this source-to-target transition. Re-admitting a correction for a
        // repeated occurrence could continuously replace that recovery and
        // strand the transport on one phrase.
        guard acceptedPCMHold == nil else {
            return .duplicateSourcePhrase
        }
        guard invalidatedSourceOccurrences.insert(sourceOccurrence).inserted else {
            return .duplicateSourcePhrase
        }
        trimInvalidatedSourcesIfNeeded()
        authorizedCorrection = AuthorizedLiveFeedbackCorrection(
            sourceOccurrence: sourceOccurrence,
            targetPhraseIndex: targetPhraseIndex,
            proposalFingerprint: proposalFingerprint
        )
        return .invalidateUnscheduledSuccessor
    }

    package func rejectCorrectedSuccessor(
        sourceOccurrence: ScheduledPhraseRange,
        targetPhraseIndex: Int,
        proposalFingerprint: String,
        expireCorrectedSuccessor: () -> Void
    ) {
        guard authorizedCorrection == AuthorizedLiveFeedbackCorrection(
            sourceOccurrence: sourceOccurrence,
            targetPhraseIndex: targetPhraseIndex,
            proposalFingerprint: proposalFingerprint
        ) else { return }
        expireCorrectedSuccessor()
        authorizedCorrection = nil
        acceptedPCMHold = AcceptedPCMHold(
            sourceOccurrence: sourceOccurrence,
            targetPhraseIndex: targetPhraseIndex,
            proposalFingerprint: proposalFingerprint
        )
    }

    package func performBoundary(
        sourcePhraseIndex: Int,
        targetPhraseIndex: Int,
        correctedSuccessorAvailable: Bool,
        expireCorrectedSuccessor: () -> Void,
        advanceCorrectedSuccessor: () -> Void,
        repeatAcceptedPCM: () -> Void,
        requestUntrimmedSuccessor: () -> Void
    ) {
        let relationshipMatches = targetPhraseIndex == sourcePhraseIndex + 1
        if relationshipMatches,
           let correction = authorizedCorrection,
           correction.sourcePhraseIndex == sourcePhraseIndex,
           correction.targetPhraseIndex == targetPhraseIndex {
            if correctedSuccessorAvailable {
                authorizedCorrection = nil
                acceptedPCMHold = nil
                advanceCorrectedSuccessor()
            } else {
                expireCorrectedSuccessor()
                authorizedCorrection = nil
                acceptedPCMHold = AcceptedPCMHold(
                    sourceOccurrence: correction.sourceOccurrence,
                    targetPhraseIndex: targetPhraseIndex,
                    proposalFingerprint: correction.proposalFingerprint
                )
                repeatAcceptedPCM()
            }
            return
        }
        if relationshipMatches,
           var hold = acceptedPCMHold,
           hold.sourcePhraseIndex == sourcePhraseIndex,
           hold.targetPhraseIndex == targetPhraseIndex {
            repeatAcceptedPCM()
            if !hold.preserveCoursePreparationReleased {
                hold.preserveCoursePreparationReleased = true
                acceptedPCMHold = hold
                requestUntrimmedSuccessor()
            }
            return
        }
        repeatAcceptedPCM()
        requestUntrimmedSuccessor()
    }

    package func allowsUntrimmedPreparation(
        sourcePhraseIndex: Int,
        targetPhraseIndex: Int
    ) -> Bool {
        !(acceptedPCMHold?.sourcePhraseIndex == sourcePhraseIndex &&
            acceptedPCMHold?.targetPhraseIndex == targetPhraseIndex &&
            acceptedPCMHold?.preserveCoursePreparationReleased == false) &&
            !(authorizedCorrection?.sourcePhraseIndex == sourcePhraseIndex &&
                authorizedCorrection?.targetPhraseIndex == targetPhraseIndex)
    }

    /// Clears recovery ownership only after the canonical session actually
    /// advances to the primary-qualified target. Preparing a candidate alone
    /// is never sufficient to release the hold.
    package func completeSourceAdvance(
        sourcePhraseIndex: Int,
        targetPhraseIndex: Int
    ) {
        guard targetPhraseIndex == sourcePhraseIndex + 1 else { return }
        if acceptedPCMHold?.sourcePhraseIndex == sourcePhraseIndex,
           acceptedPCMHold?.targetPhraseIndex == targetPhraseIndex {
            acceptedPCMHold = nil
        }
        if authorizedCorrection?.sourcePhraseIndex == sourcePhraseIndex,
           authorizedCorrection?.targetPhraseIndex == targetPhraseIndex {
            authorizedCorrection = nil
        }
    }

    package func retainRecentSources(currentPhraseIndex: Int) {
        let lowerBound = max(0, currentPhraseIndex - 2)
        invalidatedSourceOccurrences = invalidatedSourceOccurrences.filter {
            $0.phraseIndex >= lowerBound &&
                $0.phraseIndex <= currentPhraseIndex
        }
    }

    private func invalidateActiveWorker() {
        advanceLifecycleToken()
        activeIdentity = nil
        captureOwnership = .inactive
    }

    private func advanceLifecycleToken() {
        precondition(lifecycleToken < .max, "live feedback lifecycle exhausted")
        lifecycleToken += 1
    }

    private func trimInvalidatedSourcesIfNeeded() {
        while invalidatedSourceOccurrences.count >
                Self.maximumRetainedInvalidatedSources,
              let oldest = invalidatedSourceOccurrences.min(by: {
                if $0.routeGeneration != $1.routeGeneration {
                    return $0.routeGeneration < $1.routeGeneration
                }
                if $0.occurrenceEpoch != $1.occurrenceEpoch {
                    return $0.occurrenceEpoch < $1.occurrenceEpoch
                }
                return $0.playerSampleRange.lowerBound <
                    $1.playerSampleRange.lowerBound
              }) {
            invalidatedSourceOccurrences.remove(oldest)
        }
    }
}

package struct LiveFeedbackScheduledOccurrenceDraft: Equatable, Sendable {
    package let phraseIndex: Int
    package let planFingerprint: String
    package let playerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let routeGeneration: Int
    package let occurrenceEpoch: UInt64
    package let controllerRevision: Int
    package let qualityPolicyVersion: String
    package let evaluatorVersion: String
    package let controllerPolicyVersion: String
    package let controllerStateFingerprint: String
    package let appliedMasterTrimDB: Double
    package let applicableCheckpoints: [CanonicalJourneyCheckpoint]

    package init(
        phraseIndex: Int,
        planFingerprint: String,
        playerSampleRange: Range<Int64>,
        sampleRate: Double,
        routeGeneration: Int,
        occurrenceEpoch: UInt64 = 0,
        controllerRevision: Int,
        qualityPolicyVersion: String,
        evaluatorVersion: String,
        controllerPolicyVersion: String,
        controllerStateFingerprint: String,
        appliedMasterTrimDB: Double,
        applicableCheckpoints: [CanonicalJourneyCheckpoint]
    ) {
        self.phraseIndex = phraseIndex
        self.planFingerprint = planFingerprint
        self.playerSampleRange = playerSampleRange
        self.sampleRate = sampleRate
        self.routeGeneration = routeGeneration
        self.occurrenceEpoch = occurrenceEpoch
        self.controllerRevision = controllerRevision
        self.qualityPolicyVersion = qualityPolicyVersion
        self.evaluatorVersion = evaluatorVersion
        self.controllerPolicyVersion = controllerPolicyVersion
        self.controllerStateFingerprint = controllerStateFingerprint
        self.appliedMasterTrimDB = appliedMasterTrimDB
        self.applicableCheckpoints = applicableCheckpoints
    }

    package init(copying range: ScheduledPhraseRange) {
        self.init(
            phraseIndex: range.phraseIndex,
            planFingerprint: range.planFingerprint,
            playerSampleRange: range.playerSampleRange,
            sampleRate: range.sampleRate,
            routeGeneration: range.routeGeneration,
            occurrenceEpoch: range.occurrenceEpoch,
            controllerRevision: range.controllerRevision,
            qualityPolicyVersion: range.qualityPolicyVersion,
            evaluatorVersion: range.evaluatorVersion,
            controllerPolicyVersion: range.controllerPolicyVersion,
            controllerStateFingerprint: range.controllerStateFingerprint,
            appliedMasterTrimDB: range.appliedMasterTrimDB,
            applicableCheckpoints: range.applicableCheckpoints
        )
    }

    package func materialize(
        clockMap: MixerPlayerClockMap
    ) -> ScheduledPhraseRange? {
        guard sampleRate == clockMap.sampleRate,
              let mixerStart = clockMap.checkedMixerSample(
                forPlayerSample: playerSampleRange.lowerBound
              ), let mixerEnd = clockMap.checkedMixerSample(
                forPlayerSample: playerSampleRange.upperBound
              ) else { return nil }
        let range = ScheduledPhraseRange(
            phraseIndex: phraseIndex,
            planFingerprint: planFingerprint,
            playerSampleRange: playerSampleRange,
            mixerSampleRange: mixerStart..<mixerEnd,
            sampleRate: sampleRate,
            routeGeneration: routeGeneration,
            occurrenceEpoch: occurrenceEpoch,
            controllerRevision: controllerRevision,
            qualityPolicyVersion: qualityPolicyVersion,
            evaluatorVersion: evaluatorVersion,
            controllerPolicyVersion: controllerPolicyVersion,
            controllerStateFingerprint: controllerStateFingerprint,
            appliedMasterTrimDB: appliedMasterTrimDB,
            applicableCheckpoints: applicableCheckpoints,
            earliestEligibleFutureSample: playerSampleRange.upperBound
        )
        return range.isStructurallyValid(clockMap: clockMap) ? range : nil
    }
}

package enum LiveFeedbackClockObservation: Equatable, Sendable {
    case awaitingStableMap
    case captureStarted(MixerPlayerClockMap, LiveFeedbackWorkerIdentity)
    case stableMap
    case recoveryRequired
    case unavailable
}

package enum LiveFeedbackEngineQuiescenceMode: Equatable, Sendable {
    case pause
    case stop
}

/// The one production ordering gate shared by `TechnoEngine` startup and
/// teardown. Producer permission is committed before tap installation, so a
/// failed permission transition can never leave an installed callback. During
/// teardown, the player and engine are synchronously quiesced before the tap is
/// removed, the consumer is joined, or its queue storage is destroyed.
@MainActor
package final class LiveFeedbackCaptureLifecycle {
    package init() {}

    package func startProducer(
        consumerDidStart: () -> Bool,
        producerDidStart: () -> Bool,
        installTap: () -> Bool
    ) -> Bool {
        guard consumerDidStart(), producerDidStart() else { return false }
        return installTap()
    }

    package func quiesceAndTearDown<JoinProof>(
        mode: LiveFeedbackEngineQuiescenceMode,
        quiescePlayer: (LiveFeedbackEngineQuiescenceMode) -> Void,
        quiesceEngine: (LiveFeedbackEngineQuiescenceMode) -> Void,
        removeTap: () -> Void,
        cancelAndJoinConsumer: () -> JoinProof?,
        destroyQueue: (JoinProof?) -> Void
    ) {
        quiescePlayer(mode)
        quiesceEngine(mode)
        removeTap()
        let proof = cancelAndJoinConsumer()
        destroyQueue(proof)
    }
}

/// Production orchestration state used directly by `TechnoEngine`. It owns
/// the probe gate, exact scheduled-occurrence ledger, runtime lifecycle, and
/// future-only authorization. AV objects remain injected by the engine so the
/// same transitions can be tested without starting hardware.
@MainActor
package final class LiveFeedbackEngineOrchestrator {
    package let runtime: LiveFeedbackRuntimeCoordinator
    package private(set) var ledger = ScheduledPhraseLedger()
    package private(set) var clockMap: MixerPlayerClockMap?
    package private(set) var clockUnavailable = false

    private var firstProbe: MixerPlayerClockProbe?
    private var pendingOccurrence: LiveFeedbackScheduledOccurrenceDraft?
    private var resumeOccurrence: LiveFeedbackScheduledOccurrenceDraft?
    private var minimumFreshPlayerSample: Int64?

    package init(
        routeGeneration: Int,
        occurrenceEpoch: UInt64 = 0
    ) {
        runtime = LiveFeedbackRuntimeCoordinator(
            routeGeneration: routeGeneration,
            occurrenceEpoch: occurrenceEpoch
        )
    }

    package func observeClock(
        _ probe: MixerPlayerClockProbe,
        startCapture: (
            MixerPlayerClockMap,
            LiveFeedbackWorkerIdentity,
            LiveFeedbackRuntimeCoordinator
        ) -> Bool
    ) -> LiveFeedbackClockObservation {
        guard !clockUnavailable else { return .unavailable }
        if let clockMap {
            guard let firstProbe,
                  MixerPlayerClockMap.stable(
                    first: firstProbe,
                    second: probe
                  ) == clockMap else {
                failClockMap()
                return .recoveryRequired
            }
            return .stableMap
        }
        guard let firstProbe else {
            self.firstProbe = probe
            return .awaitingStableMap
        }
        guard let map = MixerPlayerClockMap.stable(
            first: firstProbe,
            second: probe
        ) else {
            failClockMap()
            return .unavailable
        }
        guard probe.playerSample.isFinite,
              probe.playerSample >= 0,
              probe.playerSample < Double(Int64.max) else {
            failClockMap()
            return .unavailable
        }
        let identity = runtime.recreateCoordinator(
            routeGeneration: runtime.routeGeneration
        )
        guard startCapture(map, identity, runtime) else {
            failClockMap()
            return .unavailable
        }
        clockMap = map
        minimumFreshPlayerSample = Int64(probe.playerSample.rounded(.up))
        materializePendingOccurrenceIfFresh()
        return .captureStarted(map, identity)
    }

    @discardableResult
    package func stageOccurrence(
        _ draft: LiveFeedbackScheduledOccurrenceDraft
    ) -> ScheduledPhraseRange? {
        guard let clockMap else {
            pendingOccurrence = draft
            return nil
        }
        guard draft.routeGeneration == runtime.routeGeneration,
              draft.occurrenceEpoch == runtime.occurrenceEpoch,
              draft.playerSampleRange.lowerBound >=
                (minimumFreshPlayerSample ?? Int64.min),
              let range = draft.materialize(clockMap: clockMap) else {
            return nil
        }
        install(range)
        return range
    }

    package func promote(playerSample: Int64) {
        guard let successor = ledger.scheduledSuccessor,
              playerSample >= successor.playerSampleRange.lowerBound else {
            return
        }
        ledger.setPlaying(successor)
    }

    package func resetSchedule() {
        ledger = ScheduledPhraseLedger()
        pendingOccurrence = nil
    }

    package func pause(stopCapture: () -> Void) {
        resumeOccurrence = ledger.scheduledSuccessor.map {
            LiveFeedbackScheduledOccurrenceDraft(copying: $0)
        }
        runtime.pause()
        stopCapture()
        clearCaptureState()
        resetSchedule()
    }

    package func resume(routeGeneration: Int) {
        runtime.resume(routeGeneration: routeGeneration)
        clearCaptureState()
        ledger = ScheduledPhraseLedger()
        pendingOccurrence = resumeOccurrence
        resumeOccurrence = nil
    }

    /// Rotates the authenticated occurrence epoch after the player sample
    /// timeline is reset. It deliberately preserves accepted-PCM hold state.
    @discardableResult
    package func playbackTimelineReset(routeGeneration: Int) -> Bool {
        guard runtime.resetPlaybackTimeline(
            routeGeneration: routeGeneration
        ) else {
            clockUnavailable = true
            clearCaptureState(keepUnavailable: true)
            resumeOccurrence = nil
            resetSchedule()
            return false
        }
        clearCaptureState()
        resumeOccurrence = nil
        resetSchedule()
        return true
    }

    package func routeReset(
        routeGeneration: Int,
        stopCapture: () -> Void
    ) {
        stopCapture()
        runtime.routeReset(routeGeneration: routeGeneration)
        clearCaptureState()
        resumeOccurrence = nil
        resetSchedule()
    }

    package func shutdown(stopCapture: () -> Void) {
        stopCapture()
        runtime.shutdown()
        clearCaptureState()
        resumeOccurrence = nil
        resetSchedule()
    }

    package func captureFailed(stopCapture: () -> Void) {
        stopCapture()
        failClockMap()
    }

    package func authorize(
        identity: LiveFeedbackWorkerIdentity,
        sourceOccurrence: ScheduledPhraseRange,
        targetPhraseIndex: Int,
        proposalFingerprint: String
    ) -> LiveFeedbackFutureBoundaryDecision {
        runtime.authorizeCorrection(
            identity: identity,
            sourceOccurrence: sourceOccurrence,
            targetPhraseIndex: targetPhraseIndex,
            proposalFingerprint: proposalFingerprint,
            sourceIsExactPlayingOccurrence:
                ledger.isExactPlayingOccurrence(sourceOccurrence),
            targetHasScheduledSamples:
                ledger.hasScheduledOrPlayingOccurrence(
                    phraseIndex: targetPhraseIndex,
                    excluding: sourceOccurrence
                )
        )
    }

    package func rejectCorrectedSuccessor(
        sourceOccurrence: ScheduledPhraseRange,
        targetPhraseIndex: Int,
        proposalFingerprint: String,
        expireCorrectedSuccessor: () -> Void
    ) {
        runtime.rejectCorrectedSuccessor(
            sourceOccurrence: sourceOccurrence,
            targetPhraseIndex: targetPhraseIndex,
            proposalFingerprint: proposalFingerprint,
            expireCorrectedSuccessor: expireCorrectedSuccessor
        )
    }

    package func allowsUntrimmedPreparation(
        sourcePhraseIndex: Int,
        targetPhraseIndex: Int
    ) -> Bool {
        runtime.allowsUntrimmedPreparation(
            sourcePhraseIndex: sourcePhraseIndex,
            targetPhraseIndex: targetPhraseIndex
        )
    }

    package func completeSourceAdvance(
        sourcePhraseIndex: Int,
        targetPhraseIndex: Int
    ) {
        runtime.completeSourceAdvance(
            sourcePhraseIndex: sourcePhraseIndex,
            targetPhraseIndex: targetPhraseIndex
        )
    }

    package func performBoundary(
        sourcePhraseIndex: Int,
        targetPhraseIndex: Int,
        correctedSuccessorAvailable: Bool,
        expireCorrectedSuccessor: () -> Void,
        advanceCorrectedSuccessor: () -> Void,
        repeatAcceptedPCM: () -> Void
    ) {
        runtime.performBoundary(
            sourcePhraseIndex: sourcePhraseIndex,
            targetPhraseIndex: targetPhraseIndex,
            correctedSuccessorAvailable: correctedSuccessorAvailable,
            expireCorrectedSuccessor: expireCorrectedSuccessor,
            advanceCorrectedSuccessor: advanceCorrectedSuccessor,
            repeatAcceptedPCM: repeatAcceptedPCM,
            requestUntrimmedSuccessor: {}
        )
    }

    private func install(_ range: ScheduledPhraseRange) {
        if ledger.playing == nil {
            ledger.setPlaying(range)
        } else {
            ledger.setScheduledSuccessor(range)
        }
    }

    private func materializePendingOccurrenceIfFresh() {
        guard let pendingOccurrence else { return }
        self.pendingOccurrence = nil
        _ = stageOccurrence(pendingOccurrence)
    }

    private func failClockMap() {
        runtime.clockMapFailed()
        clockUnavailable = true
        clearCaptureState(keepUnavailable: true)
        resetSchedule()
    }

    private func clearCaptureState(keepUnavailable: Bool = false) {
        firstProbe = nil
        clockMap = nil
        minimumFreshPlayerSample = nil
        if !keepUnavailable { clockUnavailable = false }
    }
}

package protocol LiveFeedbackResultDelivering: Sendable {
    func enqueue(
        identity: LiveFeedbackWorkerIdentity,
        handler: @escaping @MainActor @Sendable
            (LiveFeedbackWorkerIdentity) -> Void
    )
}

package struct LiveFeedbackResultDelivery: LiveFeedbackResultDelivering {
    package init() {}

    package func enqueue(
        identity: LiveFeedbackWorkerIdentity,
        handler: @escaping @MainActor @Sendable
            (LiveFeedbackWorkerIdentity) -> Void
    ) {
        Task { @MainActor in handler(identity) }
    }
}

/// Injectable buffering seam used to prove that an already-enqueued main-
/// actor result cannot cross a lifecycle-token boundary.
package final class BufferedLiveFeedbackResultDelivery:
        LiveFeedbackResultDelivering, @unchecked Sendable {
    private typealias Pending = (
        LiveFeedbackWorkerIdentity,
        @MainActor @Sendable (LiveFeedbackWorkerIdentity) -> Void
    )
    private let lock = NSLock()
    private var pending: [Pending] = []

    package init() {}

    package func enqueue(
        identity: LiveFeedbackWorkerIdentity,
        handler: @escaping @MainActor @Sendable
            (LiveFeedbackWorkerIdentity) -> Void
    ) {
        lock.lock()
        pending.append((identity, handler))
        lock.unlock()
    }

    @MainActor
    package func flush() async {
        let work = lock.withLock {
            let work = pending
            pending.removeAll(keepingCapacity: false)
            return work
        }
        await Task.yield()
        for (identity, handler) in work { handler(identity) }
    }
}

/// Exactly-sized native-stereo storage. Both channel allocations are complete
/// before the consumer can start; their capacity never grows and their byte
/// count is therefore an allocation bound rather than a logical element sum.
package final class LiveFixedStereoPCMStorage: @unchecked Sendable {
    package let frameCapacity: Int
    private let leftPointer: UnsafeMutablePointer<Float>
    private let rightPointer: UnsafeMutablePointer<Float>

    package init?(frameCapacity: Int) {
        guard frameCapacity > 0 else { return nil }
        self.frameCapacity = frameCapacity
        leftPointer = .allocate(capacity: frameCapacity)
        rightPointer = .allocate(capacity: frameCapacity)
        leftPointer.initialize(repeating: 0, count: frameCapacity)
        rightPointer.initialize(repeating: 0, count: frameCapacity)
    }

    deinit {
        leftPointer.deinitialize(count: frameCapacity)
        rightPointer.deinitialize(count: frameCapacity)
        leftPointer.deallocate()
        rightPointer.deallocate()
    }

    package var allocatedByteCount: Int {
        frameCapacity * 2 * MemoryLayout<Float>.stride
    }

    fileprivate func copy(
        left: UnsafeBufferPointer<Float>,
        right: UnsafeBufferPointer<Float>,
        sourceRange: Range<Int>,
        destinationOffset: Int
    ) -> Bool {
        guard sourceRange.lowerBound >= 0,
              sourceRange.upperBound <= left.count,
              sourceRange.upperBound <= right.count,
              destinationOffset >= 0,
              destinationOffset + sourceRange.count <= frameCapacity else {
            return false
        }
        leftPointer.advanced(by: destinationOffset).update(
            from: left.baseAddress!.advanced(by: sourceRange.lowerBound),
            count: sourceRange.count
        )
        rightPointer.advanced(by: destinationOffset).update(
            from: right.baseAddress!.advanced(by: sourceRange.lowerBound),
            count: sourceRange.count
        )
        return true
    }

    package func withUnsafeStereo<R>(
        frameCount: Int,
        _ body: (UnsafeBufferPointer<Float>, UnsafeBufferPointer<Float>) -> R
    ) -> R? {
        guard frameCount >= 0, frameCount <= frameCapacity else { return nil }
        return body(
            UnsafeBufferPointer(start: leftPointer, count: frameCount),
            UnsafeBufferPointer(start: rightPointer, count: frameCount)
        )
    }

    fileprivate func withUnsafeMutableStereo<R>(
        _ body: (
            UnsafeMutableBufferPointer<Float>,
            UnsafeMutableBufferPointer<Float>
        ) -> R
    ) -> R {
        body(
            UnsafeMutableBufferPointer(start: leftPointer, count: frameCapacity),
            UnsafeMutableBufferPointer(start: rightPointer, count: frameCapacity)
        )
    }

    package func channelCopy(leftChannel: Bool, frameCount: Int) -> [Float] {
        guard frameCount >= 0, frameCount <= frameCapacity else { return [] }
        let pointer = leftChannel ? leftPointer : rightPointer
        return Array(UnsafeBufferPointer(start: pointer, count: frameCount))
    }
}

package struct LivePhrasePCMWindow: Equatable, Sendable {
    package let phraseIndex: Int
    package let planFingerprint: String
    package let routeGeneration: Int
    package let controllerRevision: Int
    package let playerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let captureProvenance: LiveOutputCaptureProvenance
    fileprivate let storage: LiveFixedStereoPCMStorage

    /// Test/diagnostic copies only. Production analysis borrows the fixed
    /// storage directly through `withUnsafeStereo`.
    package var left: [Float] {
        storage.channelCopy(leftChannel: true, frameCount: captureProvenance.coveredFrameCount)
    }
    package var right: [Float] {
        storage.channelCopy(leftChannel: false, frameCount: captureProvenance.coveredFrameCount)
    }

    package func withUnsafeStereo<R>(
        _ body: (UnsafeBufferPointer<Float>, UnsafeBufferPointer<Float>) -> R
    ) -> R? {
        storage.withUnsafeStereo(
            frameCount: captureProvenance.coveredFrameCount,
            body
        )
    }

    package static func == (
        lhs: LivePhrasePCMWindow,
        rhs: LivePhrasePCMWindow
    ) -> Bool {
        lhs.phraseIndex == rhs.phraseIndex &&
            lhs.planFingerprint == rhs.planFingerprint &&
            lhs.routeGeneration == rhs.routeGeneration &&
            lhs.controllerRevision == rhs.controllerRevision &&
            lhs.playerSampleRange == rhs.playerSampleRange &&
            lhs.sampleRate == rhs.sampleRate &&
            lhs.captureProvenance == rhs.captureProvenance &&
            lhs.storage === rhs.storage
    }
}

package enum LivePhraseWindowUnavailabilityReason: String, Equatable, Sendable {
    case invalidSourceRange
    case invalidPacket
    case packetSequenceDiscontinuity
    case sampleGap
    case sampleOverlap
    case queueDropDelta
    case rejectedPacketDelta
    case routeGenerationMismatch
    case controllerRevisionMismatch
    case nonFiniteSample
    case ledgerEviction
    case staleScheduledOccurrence
}

/// Mutable state owned by the detached packet consumer. It copies only the
/// first exact three seconds of one retained phrase at a time and emits one
/// immutable native-stereo value. No state or array in this type is reachable
/// from the real-time producer.
package struct LivePhraseWindowAssembler: Sendable {
    private struct BorrowedPacket {
        let packetSequence: UInt64
        let firstMixerSample: Int64
        let routeGeneration: Int
        let controllerRevision: Int
        let counters: LivePCMQueueCounterSnapshot
        let left: UnsafeBufferPointer<Float>
        let right: UnsafeBufferPointer<Float>
    }

    private struct Assembly: Sendable {
        let range: ScheduledPhraseRange
        let windowRange: Range<Int64>
        var writtenFrameCount: Int
        var packetCount: Int
        let firstPacketSequence: UInt64
        var lastPacketSequence: UInt64
        let initialCounters: LivePCMQueueCounterSnapshot
        var finalCounters: LivePCMQueueCounterSnapshot

        var nextExpectedPlayerSample: Int64 {
            windowRange.lowerBound + Int64(writtenFrameCount)
        }
    }

    package let sampleRate: Double
    package let clockMap: MixerPlayerClockMap
    package let windowFrameCount: Int

    private var counters: LivePCMQueueCounterSnapshot
    private var lastPacketSequence: UInt64?
    private var knownLedger = ScheduledPhraseLedger()
    private var assembly: Assembly?
    private let windowStorage: LiveFixedStereoPCMStorage
    private var emitted0: ScheduledPhraseRange?
    private var emitted1: ScheduledPhraseRange?
    private var emitted2: ScheduledPhraseRange?
    private var emitted3: ScheduledPhraseRange?
    private var unavailable0: (ScheduledPhraseRange, LivePhraseWindowUnavailabilityReason)?
    private var unavailable1: (ScheduledPhraseRange, LivePhraseWindowUnavailabilityReason)?
    private var unavailable2: (ScheduledPhraseRange, LivePhraseWindowUnavailabilityReason)?
    private var unavailable3: (ScheduledPhraseRange, LivePhraseWindowUnavailabilityReason)?
    package private(set) var lastUnavailabilityReason: LivePhraseWindowUnavailabilityReason?
    package private(set) var retirementRouteGeneration: Int?
    package private(set) var retiredThroughPlayerSample: Int64?

    package init?(
        sampleRate: Double,
        clockMap: MixerPlayerClockMap,
        initialCounters: LivePCMQueueCounterSnapshot
    ) {
        guard sampleRate == clockMap.sampleRate else { return nil }
        let windowFrameCount: Int
        switch sampleRate {
        case 44_100:
            windowFrameCount = 132_300
        case 48_000:
            windowFrameCount = 144_000
        default:
            return nil
        }
        self.sampleRate = sampleRate
        self.clockMap = clockMap
        self.windowFrameCount = windowFrameCount
        self.counters = initialCounters
        guard let storage = LiveFixedStereoPCMStorage(
            frameCapacity: windowFrameCount
        ) else { return nil }
        windowStorage = storage
    }

    package mutating func reconcile(with ledger: ScheduledPhraseLedger) {
        var newestGeneration: Int?
        ledger.forEachRetained { range in
            newestGeneration = max(newestGeneration ?? Int.min, range.routeGeneration)
        }
        if let newestGeneration {
            if retirementRouteGeneration.map({ newestGeneration > $0 }) ?? true {
                retirementRouteGeneration = newestGeneration
                retiredThroughPlayerSample = nil
            }
        }

        knownLedger.forEachRetained { evicted in
            guard !ledger.contains(evicted) else { return }
            if hasEmitted(evicted) || unavailability(for: evicted) != nil {
                advanceRetirementProof(with: evicted)
            }
            reject(evicted, reason: .ledgerEviction)
        }
        knownLedger = ledger

        if let active = assembly,
           isStale(active.range) || !ledger.contains(active.range) {
            reject(
                active.range,
                reason: isStale(active.range)
                    ? .staleScheduledOccurrence
                    : .ledgerEviction
            )
        }
        discardEmittedRanges(notIn: ledger)
        discardUnavailableRanges(notIn: ledger)
    }

    package mutating func consume(
        _ packet: ConsumedLivePCMPacket,
        ledger: ScheduledPhraseLedger
    ) -> LivePhrasePCMWindow? {
        // Offline replay/test convenience. Production reconciles only on the
        // worker control update and uses the metadata/pointer overload below.
        reconcile(with: ledger)
        return packet.left.withUnsafeBufferPointer { left in
            packet.right.withUnsafeBufferPointer { right in
                consume(BorrowedPacket(
                    packetSequence: packet.packetSequence,
                    firstMixerSample: packet.firstMixerSample,
                    routeGeneration: packet.routeGeneration,
                    controllerRevision: packet.controllerRevision,
                    counters: packet.counters,
                    left: left,
                    right: right
                ), ledger: ledger)
            }
        }
    }

    /// Production consumer entry point. Scratch storage is borrowed only for
    /// this synchronous call; the assembler copies intersecting samples into
    /// its single reserved window and never retains these pointers.
    package mutating func consume(
        metadata: ATLivePCMPacketMetadata,
        counters: LivePCMQueueCounterSnapshot,
        left: UnsafeBufferPointer<Float>,
        right: UnsafeBufferPointer<Float>,
        ledger: ScheduledPhraseLedger
    ) -> LivePhrasePCMWindow? {
        let frameCount = Int(metadata.frameCount)
        guard frameCount > 0,
              frameCount <= left.count,
              frameCount <= right.count else { return nil }
        return consume(BorrowedPacket(
            packetSequence: metadata.packetSequence,
            firstMixerSample: metadata.firstMixerSample,
            routeGeneration: Int(metadata.routeGeneration),
            controllerRevision: Int(metadata.controllerRevision),
            counters: counters,
            left: UnsafeBufferPointer(rebasing: left[..<frameCount]),
            right: UnsafeBufferPointer(rebasing: right[..<frameCount])
        ), ledger: ledger)
    }

    package mutating func consume(
        metadata: ATLivePCMPacketMetadata,
        counters: LivePCMQueueCounterSnapshot,
        left: inout [Float],
        right: inout [Float],
        ledger: ScheduledPhraseLedger
    ) -> LivePhrasePCMWindow? {
        left.withUnsafeBufferPointer { leftBuffer in
            right.withUnsafeBufferPointer { rightBuffer in
                consume(
                    metadata: metadata,
                    counters: counters,
                    left: leftBuffer,
                    right: rightBuffer,
                    ledger: ledger
                )
            }
        }
    }

    private mutating func consume(
        _ packet: BorrowedPacket,
        ledger: ScheduledPhraseLedger
    ) -> LivePhrasePCMWindow? {
        let priorSequence = lastPacketSequence
        lastPacketSequence = packet.packetSequence
        let sequenceDiscontinuity: Bool
        if let priorSequence {
            let expected = priorSequence.addingReportingOverflow(1)
            sequenceDiscontinuity = expected.overflow || packet.packetSequence != expected.partialValue
        } else {
            sequenceDiscontinuity = false
        }

        let priorCounters = counters
        counters = packet.counters

        guard windowFrameCount > 0,
              sampleRate == clockMap.sampleRate,
              !packet.left.isEmpty,
              packet.left.count == packet.right.count,
              packet.left.count <= 1_024,
              let playerStart = clockMap.checkedPlayerSample(
                forMixerSample: packet.firstMixerSample
              ) else {
            rejectActive(reason: .invalidPacket)
            return nil
        }
        let end = playerStart.addingReportingOverflow(Int64(packet.left.count))
        guard !end.overflow else {
            rejectActive(reason: .invalidPacket)
            return nil
        }
        let packetRange = playerStart..<end.partialValue

        var target = assembly?.range
        if let active = assembly,
           !active.windowRange.overlaps(packetRange) {
            if packetRange.lowerBound >= active.nextExpectedPlayerSample {
                reject(active.range, reason: .sampleGap)
            } else {
                reject(active.range, reason: .sampleOverlap)
            }
            target = nil
        }
        if target == nil {
            target = ledger.firstWindowRange(
                overlapping: packetRange,
                frameCount: Int64(windowFrameCount)
            )
        }
        guard let target else { return nil }
        if isStale(target) {
            reject(target, reason: .staleScheduledOccurrence)
            return nil
        }
        guard !hasEmitted(target),
              unavailability(for: target) == nil else {
            return nil
        }

        var beganAssemblyAtPhraseOnset = false
        if assembly == nil {
            let sourceLength = target.playerSampleRange.upperBound
                .subtractingReportingOverflow(target.playerSampleRange.lowerBound)
            guard !sourceLength.overflow,
                  sourceLength.partialValue >= Int64(windowFrameCount) else {
                reject(target, reason: .invalidSourceRange)
                return nil
            }
            let windowRange = target.playerSampleRange.lowerBound..<(target.playerSampleRange.lowerBound + Int64(windowFrameCount))
            beganAssemblyAtPhraseOnset = packetRange.lowerBound <= windowRange.lowerBound &&
                packetRange.upperBound > windowRange.lowerBound
            assembly = Assembly(
                range: target,
                windowRange: windowRange,
                writtenFrameCount: 0,
                packetCount: 0,
                firstPacketSequence: packet.packetSequence,
                lastPacketSequence: packet.packetSequence,
                initialCounters: packet.counters,
                finalCounters: packet.counters
            )
        }

        guard let active = assembly,
              active.range == target else {
            return nil
        }
        if !beganAssemblyAtPhraseOnset && sequenceDiscontinuity {
            reject(target, reason: .packetSequenceDiscontinuity)
            return nil
        }
        if !beganAssemblyAtPhraseOnset &&
            packet.counters.droppedPackets != priorCounters.droppedPackets {
            reject(target, reason: .queueDropDelta)
            return nil
        }
        if !beganAssemblyAtPhraseOnset &&
            packet.counters.rejectedPackets != priorCounters.rejectedPackets {
            reject(target, reason: .rejectedPacketDelta)
            return nil
        }
        guard packet.routeGeneration == target.routeGeneration else {
            reject(target, reason: .routeGenerationMismatch)
            return nil
        }
        guard packet.controllerRevision == target.controllerRevision else {
            reject(target, reason: .controllerRevisionMismatch)
            return nil
        }

        let intersection = packetRange.clamped(to: active.windowRange)
        guard !intersection.isEmpty else { return nil }
        if intersection.lowerBound > active.nextExpectedPlayerSample {
            reject(target, reason: .sampleGap)
            return nil
        }
        if intersection.lowerBound < active.nextExpectedPlayerSample {
            reject(target, reason: .sampleOverlap)
            return nil
        }

        let packetOffset = Int(intersection.lowerBound - packetRange.lowerBound)
        let copyCount = Int(intersection.upperBound - intersection.lowerBound)
        let copyRange = packetOffset..<(packetOffset + copyCount)
        guard copyRange.lowerBound >= 0,
              copyRange.upperBound <= packet.left.count else {
            reject(target, reason: .invalidPacket)
            return nil
        }
        for index in copyRange {
            guard packet.left[index].isFinite, packet.right[index].isFinite else {
                reject(target, reason: .nonFiniteSample)
                return nil
            }
        }

        guard windowStorage.copy(
            left: packet.left,
            right: packet.right,
            sourceRange: copyRange,
            destinationOffset: active.writtenFrameCount
        ) else {
            reject(target, reason: .invalidPacket)
            return nil
        }
        assembly?.writtenFrameCount += copyCount
        assembly?.packetCount += 1
        assembly?.lastPacketSequence = packet.packetSequence
        assembly?.finalCounters = packet.counters
        guard let completed = assembly,
              completed.writtenFrameCount == windowFrameCount else {
            return nil
        }

        let window = LivePhrasePCMWindow(
            phraseIndex: target.phraseIndex,
            planFingerprint: target.planFingerprint,
            routeGeneration: target.routeGeneration,
            controllerRevision: target.controllerRevision,
            playerSampleRange: completed.windowRange,
            sampleRate: sampleRate,
            captureProvenance: LiveOutputCaptureProvenance(
                packetCount: completed.packetCount,
                firstPacketSequence: completed.firstPacketSequence,
                lastPacketSequence: completed.lastPacketSequence,
                droppedPacketDelta: completed.finalCounters.droppedPackets -
                    completed.initialCounters.droppedPackets,
                rejectedPacketDelta:
                    completed.finalCounters.rejectedPackets -
                    completed.initialCounters.rejectedPackets,
                queueCapacity: LivePCMTransport.queueCapacity,
                maximumPacketFrameCount:
                    LivePCMTransport.maximumPacketFrameCount,
                queueStorageByteCount:
                    LivePCMTransport.queueStorageByteCount,
                consumerScratchByteCount:
                    LivePCMTransport.maximumPacketFrameCount * 2 *
                    MemoryLayout<Float>.stride,
                activeWindowByteCount: windowFrameCount * 2 *
                    MemoryLayout<Float>.stride,
                workingMemoryByteCount:
                    LivePCMTransport.queueStorageByteCount +
                    LivePCMTransport.maximumPacketFrameCount * 2 *
                    MemoryLayout<Float>.stride +
                    windowFrameCount * 2 * MemoryLayout<Float>.stride,
                coveredFrameCount: windowFrameCount,
                sampleDiscontinuityCount: 0,
                gapFrameCount: 0,
                overlapFrameCount: 0
            ),
            storage: windowStorage
        )
        insertEmitted(target)
        assembly = nil
        return window
    }

    package func hasEmitted(_ range: ScheduledPhraseRange) -> Bool {
        emitted0 == range || emitted1 == range ||
            emitted2 == range || emitted3 == range
    }

    package func unavailability(
        for range: ScheduledPhraseRange
    ) -> LivePhraseWindowUnavailabilityReason? {
        if unavailable0?.0 == range { return unavailable0?.1 }
        if unavailable1?.0 == range { return unavailable1?.1 }
        if unavailable2?.0 == range { return unavailable2?.1 }
        if unavailable3?.0 == range { return unavailable3?.1 }
        return nil
    }

    package var trackedEmissionCount: Int {
        (emitted0 == nil ? 0 : 1) +
            (emitted1 == nil ? 0 : 1) +
            (emitted2 == nil ? 0 : 1) +
            (emitted3 == nil ? 0 : 1)
    }

    package var trackedUnavailabilityCount: Int {
        (unavailable0 == nil ? 0 : 1) +
            (unavailable1 == nil ? 0 : 1) +
            (unavailable2 == nil ? 0 : 1) +
            (unavailable3 == nil ? 0 : 1)
    }

    package var bookkeepingIdentityCount: Int {
        trackedEmissionCount + trackedUnavailabilityCount
    }

    package var fixedPCMStorageByteCount: Int {
        windowStorage.allocatedByteCount
    }

    private func isStale(_ range: ScheduledPhraseRange) -> Bool {
        guard let retirementRouteGeneration else { return false }
        if range.routeGeneration < retirementRouteGeneration { return true }
        if range.routeGeneration > retirementRouteGeneration { return false }
        guard let retiredThroughPlayerSample else { return false }
        return range.playerSampleRange.lowerBound <= retiredThroughPlayerSample
    }

    private mutating func advanceRetirementProof(with range: ScheduledPhraseRange) {
        guard range.routeGeneration == retirementRouteGeneration else { return }
        let finalRetiredSample = range.playerSampleRange.isEmpty
            ? range.playerSampleRange.lowerBound
            : range.playerSampleRange.upperBound - 1
        retiredThroughPlayerSample = max(
            retiredThroughPlayerSample ?? Int64.min,
            finalRetiredSample
        )
    }

    private mutating func rejectActive(reason: LivePhraseWindowUnavailabilityReason) {
        guard let active = assembly else { return }
        reject(active.range, reason: reason)
    }

    private mutating func reject(
        _ range: ScheduledPhraseRange,
        reason: LivePhraseWindowUnavailabilityReason
    ) {
        guard !hasEmitted(range) else { return }
        lastUnavailabilityReason = reason
        insertUnavailable(range, reason: reason)
        if assembly?.range == range {
            assembly = nil
        }
    }

    private mutating func insertUnavailable(
        _ range: ScheduledPhraseRange,
        reason: LivePhraseWindowUnavailabilityReason
    ) {
        guard unavailability(for: range) == nil else { return }
        if unavailable0 == nil { unavailable0 = (range, reason); return }
        if unavailable1 == nil { unavailable1 = (range, reason); return }
        if unavailable2 == nil { unavailable2 = (range, reason); return }
        if unavailable3 == nil { unavailable3 = (range, reason); return }
        unavailable0 = unavailable1
        unavailable1 = unavailable2
        unavailable2 = unavailable3
        unavailable3 = (range, reason)
    }

    private mutating func insertEmitted(_ range: ScheduledPhraseRange) {
        guard !hasEmitted(range) else { return }
        if emitted0 == nil { emitted0 = range; return }
        if emitted1 == nil { emitted1 = range; return }
        if emitted2 == nil { emitted2 = range; return }
        if emitted3 == nil { emitted3 = range; return }
        emitted0 = emitted1
        emitted1 = emitted2
        emitted2 = emitted3
        emitted3 = range
    }

    private mutating func discardEmittedRanges(
        notIn ledger: ScheduledPhraseLedger
    ) {
        if let emitted0, !ledger.contains(emitted0) { self.emitted0 = nil }
        if let emitted1, !ledger.contains(emitted1) { self.emitted1 = nil }
        if let emitted2, !ledger.contains(emitted2) { self.emitted2 = nil }
        if let emitted3, !ledger.contains(emitted3) { self.emitted3 = nil }
    }

    private mutating func discardUnavailableRanges(
        notIn ledger: ScheduledPhraseLedger
    ) {
        if let slot = unavailable0, !ledger.contains(slot.0) { unavailable0 = nil }
        if let slot = unavailable1, !ledger.contains(slot.0) { unavailable1 = nil }
        if let slot = unavailable2, !ledger.contains(slot.0) { unavailable2 = nil }
        if let slot = unavailable3, !ledger.contains(slot.0) { unavailable3 = nil }
    }
}

/// Immutable worker input supplied after both the playing source range and its
/// still-unscheduled canonical successor are known.
package struct LiveFeedbackAnalysisContext: Sendable {
    package let sourceRange: ScheduledPhraseRange
    package let sourceIdentity: LiveOutputPlanSourceIdentity
    package let targetPlan: AutonomousPhrasePlan
    package let incomingState: LiveMasterHeadroomContinuationState
    package let controllerStateFingerprint: String
    package let earliestEligibleFutureSample: Int64
    package let qualityPolicyVersion: String

    package init(
        sourceRange: ScheduledPhraseRange,
        sourcePlan: AutonomousPhrasePlan,
        targetPlan: AutonomousPhrasePlan,
        incomingState: LiveMasterHeadroomContinuationState,
        controllerStateFingerprint: String,
        earliestEligibleFutureSample: Int64,
        qualityPolicyVersion: String
    ) {
        self.sourceRange = sourceRange
        sourceIdentity = LiveOutputPlanSourceIdentity(plan: sourcePlan)
        self.targetPlan = targetPlan
        self.incomingState = incomingState
        self.controllerStateFingerprint = controllerStateFingerprint
        self.earliestEligibleFutureSample = earliestEligibleFutureSample
        self.qualityPolicyVersion = qualityPolicyVersion
    }

    package var isStructurallyValid: Bool {
        sourceIdentity.phraseIndex == sourceRange.phraseIndex &&
            sourceIdentity.planFingerprint == sourceRange.planFingerprint &&
            sourceIdentity.applicableCheckpoints ==
                sourceRange.applicableCheckpoints &&
            sourceRange.controllerRevision == incomingState.revision &&
            sourceRange.appliedMasterTrimDB == incomingState.committedTrimDB &&
            sourceRange.controllerStateFingerprint ==
                controllerStateFingerprint &&
            sourceRange.qualityPolicyVersion == qualityPolicyVersion &&
            sourceRange.evaluatorVersion ==
                ProfessionalQualityPrimaryEvaluator
                    .evaluatorVersionIdentifier &&
            sourceRange.controllerPolicyVersion ==
                LiveFeedbackContract.controllerPolicyVersion &&
            targetPlan.phraseIndex == sourceRange.phraseIndex + 1 &&
            earliestEligibleFutureSample ==
                sourceRange.earliestEligibleFutureSample
    }
}

/// Main-actor preparation state shared by the real engine and deterministic
/// tests. The cache contains renderable candidates; the target reference does
/// not. Retaining the latter through an accepted-PCM hold preserves only the
/// canonical target plan and a recipe for a future corrected preparation. It
/// never makes an untrimmed candidate eligible for scheduling.
@MainActor
package final class LiveFeedbackPreparationOwner<
    Key: Hashable,
    CachedValue,
    BasePayload
> {
    private struct TargetReference {
        let sourceIdentity: LiveOutputPlanSourceIdentity
        let targetPlan: AutonomousPhrasePlan
        var routeGeneration: Int?
        var occurrenceEpoch: UInt64?
        var sampleRate: Double?
        var basePayload: BasePayload?
    }

    private var cache: [Key: CachedValue] = [:]
    private var targetReference: TargetReference?

    package init() {}

    package var cachedCount: Int { cache.count }
    package var hasTargetReference: Bool { targetReference != nil }
    package var hasCurrentTargetPayload: Bool {
        targetReference?.basePayload != nil
    }

    package func removeCachedValue(forKey key: Key) -> CachedValue? {
        cache.removeValue(forKey: key)
    }

    package func insertCachedValue(_ value: CachedValue, forKey key: Key) {
        cache[key] = value
    }

    package func firstCached(
        where predicate: (Key, CachedValue) -> Bool
    ) -> (key: Key, value: CachedValue)? {
        cache.first(where: predicate)
    }

    package func removeCached(
        where shouldRemove: (Key, CachedValue) -> Bool
    ) {
        cache = cache.filter { !shouldRemove($0.key, $0.value) }
    }

    package func removeAllCached(keepingCapacity: Bool) {
        cache.removeAll(keepingCapacity: keepingCapacity)
    }

    @discardableResult
    package func rememberTargetReference(
        sourcePlan: AutonomousPhrasePlan,
        targetPlan: AutonomousPhrasePlan,
        routeGeneration: Int,
        sampleRate: Double,
        occurrenceEpoch: UInt64 = 0,
        basePayload: BasePayload
    ) -> Bool {
        let sourceIdentity = LiveOutputPlanSourceIdentity(plan: sourcePlan)
        let targetIdentity = LiveOutputPlanSourceIdentity(plan: targetPlan)
        guard sourcePlan.phraseIndex < Int.max,
              targetPlan.phraseIndex == sourcePlan.phraseIndex + 1,
              targetIdentity.phraseIndex == sourceIdentity.phraseIndex + 1,
              routeGeneration >= 0,
              MixerPlayerClockMap.isSupported(sampleRate: sampleRate) else {
            return false
        }
        targetReference = TargetReference(
            sourceIdentity: sourceIdentity,
            targetPlan: targetPlan,
            routeGeneration: routeGeneration,
            occurrenceEpoch: occurrenceEpoch,
            sampleRate: sampleRate,
            basePayload: basePayload
        )
        return true
    }

    /// Rebinds only the non-rendered preparation recipe after recovery or a
    /// route rebuild. A hold remains latched and no cache entry is created.
    @discardableResult
    package func rebindTargetPayload(
        sourcePlan: AutonomousPhrasePlan,
        routeGeneration: Int,
        sampleRate: Double,
        occurrenceEpoch: UInt64 = 0,
        basePayload: BasePayload
    ) -> Bool {
        guard var reference = targetReference,
              reference.sourceIdentity ==
                LiveOutputPlanSourceIdentity(plan: sourcePlan),
              routeGeneration >= 0,
              MixerPlayerClockMap.isSupported(sampleRate: sampleRate) else {
            return false
        }
        reference.routeGeneration = routeGeneration
        reference.occurrenceEpoch = occurrenceEpoch
        reference.sampleRate = sampleRate
        reference.basePayload = basePayload
        targetReference = reference
        return true
    }

    /// Re-authenticates an existing plan-owned recipe after the player resets
    /// its sample timeline. This does not create a cache entry or submit an
    /// untrimmed preparation while accepted PCM is held.
    @discardableResult
    package func rebindTargetOccurrence(
        sourcePlan: AutonomousPhrasePlan,
        routeGeneration: Int,
        occurrenceEpoch: UInt64
    ) -> Bool {
        guard var reference = targetReference,
              reference.sourceIdentity ==
                LiveOutputPlanSourceIdentity(plan: sourcePlan),
              reference.routeGeneration == routeGeneration,
              reference.basePayload != nil else { return false }
        reference.occurrenceEpoch = occurrenceEpoch
        targetReference = reference
        return true
    }

    package func invalidateTargetPayloadForRouteChange() {
        guard var reference = targetReference else { return }
        reference.routeGeneration = nil
        reference.occurrenceEpoch = nil
        reference.sampleRate = nil
        reference.basePayload = nil
        targetReference = reference
    }

    package func analysisContext(
        sourceRange: ScheduledPhraseRange,
        sourcePlan: AutonomousPhrasePlan,
        incomingState: LiveMasterHeadroomContinuationState,
        controllerStateFingerprint: String,
        qualityPolicyVersion: String
    ) -> LiveFeedbackAnalysisContext? {
        guard let reference = targetReference,
              reference.basePayload != nil,
              reference.routeGeneration == sourceRange.routeGeneration,
              reference.occurrenceEpoch == sourceRange.occurrenceEpoch,
              reference.sampleRate == sourceRange.sampleRate,
              reference.sourceIdentity ==
                LiveOutputPlanSourceIdentity(plan: sourcePlan),
              reference.sourceIdentity.phraseIndex == sourceRange.phraseIndex,
              reference.sourceIdentity.planFingerprint ==
                sourceRange.planFingerprint,
              reference.sourceIdentity.applicableCheckpoints ==
                sourceRange.applicableCheckpoints else { return nil }
        let context = LiveFeedbackAnalysisContext(
            sourceRange: sourceRange,
            sourcePlan: sourcePlan,
            targetPlan: reference.targetPlan,
            incomingState: incomingState,
            controllerStateFingerprint: controllerStateFingerprint,
            earliestEligibleFutureSample:
                sourceRange.earliestEligibleFutureSample,
            qualityPolicyVersion: qualityPolicyVersion
        )
        return context.isStructurallyValid ? context : nil
    }

    package func correctionPayload(
        sourceRange: ScheduledPhraseRange,
        eligibleTargetIdentity: LiveOutputPlanSourceIdentity
    ) -> BasePayload? {
        guard let reference = targetReference,
              reference.routeGeneration == sourceRange.routeGeneration,
              reference.occurrenceEpoch == sourceRange.occurrenceEpoch,
              reference.sampleRate == sourceRange.sampleRate,
              reference.sourceIdentity.phraseIndex == sourceRange.phraseIndex,
              reference.sourceIdentity.planFingerprint ==
                sourceRange.planFingerprint,
              LiveOutputPlanSourceIdentity(plan: reference.targetPlan) ==
                eligibleTargetIdentity else { return nil }
        return reference.basePayload
    }

    package func completeSourceAdvance(sourcePhraseIndex: Int) {
        guard targetReference?.sourceIdentity.phraseIndex ==
                sourcePhraseIndex else { return }
        targetReference = nil
    }

    package func resetSession() {
        cache.removeAll(keepingCapacity: false)
        targetReference = nil
    }
}

package struct LiveFeedbackWorkerResult: Sendable {
    package let identity: LiveFeedbackWorkerIdentity
    package let sourceRange: ScheduledPhraseRange
    package let binding: PendingLiveMasterHeadroomBinding
}

package final class LiveFeedbackCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    package init() {}

    package var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    package func cancel() {
        lock.withLock { cancelled = true }
    }
}

/// One serial, non-realtime consumer. Its queue owns packet scratch arrays,
/// window assembly, BS.1770 analysis, profile target resolution, and proposal
/// construction. No PCM or analyzer object is delivered to the main actor.
package final class LiveFeedbackCoordinator: @unchecked Sendable {
    package static let maximumPacketsPerDrain = 32
    package static let maximumRetainedPCMWindows = 1

    private let transport: LivePCMTransport
    private let sampleRate: Double
    private let clockMap: MixerPlayerClockMap
    private let identity: LiveFeedbackWorkerIdentity
    private let artifacts: ProfessionalQualityPrimaryArtifacts?
    private let resultDelivery: any LiveFeedbackResultDelivering
    private let cancellation = LiveFeedbackCancellationToken()
    private let analysisStartHook:
        (@Sendable (LiveFeedbackCancellationToken) -> Void)?
    private let resultHandler:
        @MainActor @Sendable (LiveFeedbackWorkerResult) -> Void
    private let workerQueue = DispatchQueue(
        label: "com.autotechno.live-feedback.consumer",
        qos: .utility
    )

    // Every value below is workerQueue-owned.
    private var timer: DispatchSourceTimer?
    private var assembler: LivePhraseWindowAssembler?
    private var ledger = ScheduledPhraseLedger()
    private var context: LiveFeedbackAnalysisContext?
    private var pendingWindow:
        (ScheduledPhraseRange, LivePhrasePCMWindow)?
    private let scratchStorage: LiveFixedStereoPCMStorage
    private var consumerLease: LivePCMConsumerLease?
    private var running = false

    package init?(
        transport: LivePCMTransport,
        sampleRate: Double,
        clockMap: MixerPlayerClockMap,
        identity: LiveFeedbackWorkerIdentity,
        artifacts: ProfessionalQualityPrimaryArtifacts?,
        resultDelivery: any LiveFeedbackResultDelivering =
            LiveFeedbackResultDelivery(),
        analysisStartHook:
            (@Sendable (LiveFeedbackCancellationToken) -> Void)? = nil,
        resultHandler: @escaping @MainActor @Sendable
            (LiveFeedbackWorkerResult) -> Void
    ) {
        guard sampleRate == clockMap.sampleRate,
              let assembler = LivePhraseWindowAssembler(
                sampleRate: sampleRate,
                clockMap: clockMap,
                initialCounters: transport.counters
              ), let scratchStorage = LiveFixedStereoPCMStorage(
                frameCapacity: LivePCMTransport.maximumPacketFrameCount
              ) else { return nil }
        self.transport = transport
        self.sampleRate = sampleRate
        self.clockMap = clockMap
        self.identity = identity
        self.artifacts = artifacts
        self.resultDelivery = resultDelivery
        self.analysisStartHook = analysisStartHook
        self.resultHandler = resultHandler
        self.assembler = assembler
        self.scratchStorage = scratchStorage
    }

    @discardableResult
    package func start() -> Bool {
        guard let lease = transport.bindConsumer(
            permit: LivePCMConsumerStartPermit(identity: identity)
        ) else { return false }
        consumerLease = lease
        return workerQueue.sync {
            guard !running else { return false }
            running = true
            let timer = DispatchSource.makeTimerSource(queue: workerQueue)
            timer.schedule(
                deadline: .now(),
                repeating: .milliseconds(5),
                leeway: .milliseconds(1)
            )
            timer.setEventHandler { [weak self] in
                self?.drainBoundedPackets()
            }
            self.timer = timer
            timer.resume()
            return true
        }
    }

    package func update(
        ledger: ScheduledPhraseLedger,
        contexts: [LiveFeedbackAnalysisContext]
    ) {
        workerQueue.async { [weak self] in
            guard let self, self.running else { return }
            self.ledger = ledger
            self.context = contexts.first {
                $0.isStructurallyValid &&
                    $0.sourceRange.isStructurallyValid(
                        clockMap: self.clockMap
                    )
            }
            self.assembler?.reconcile(with: ledger)
            if let pendingWindow = self.pendingWindow,
               !ledger.contains(pendingWindow.0) {
                self.pendingWindow = nil
            }
            self.analyzePendingWindowsIfPossible()
        }
    }

    /// Joins the serial worker. The producer tap must already have been removed.
    package func stopAndWait() -> LivePCMConsumerStopProof? {
        cancellation.cancel()
        let stopped = workerQueue.sync {
            guard running else { return false }
            running = false
            timer?.setEventHandler {}
            timer?.cancel()
            timer = nil
            // The producer has already been removed. Boundedly consume every
            // retained slot so pause can reuse the allocation without treating
            // pre-pause PCM as a new designated window.
            var metadata = ATLivePCMPacketMetadata()
            for _ in 0..<LivePCMTransport.queueCapacity {
                let consumed = scratchStorage.withUnsafeMutableStereo {
                    transport.consume(
                        metadata: &metadata,
                        left: $0,
                        right: $1
                    )
                }
                guard consumed else { break }
            }
            assembler = nil
            context = nil
            pendingWindow = nil
            ledger = ScheduledPhraseLedger()
            return true
        }
        guard stopped, let consumerLease else { return nil }
        self.consumerLease = nil
        return LivePCMConsumerStopProof(lease: consumerLease)
    }

    /// Executes the injected hook on the production serial worker and token.
    package func enqueueAnalysisHookForTesting() {
        workerQueue.async { [weak self] in
            guard let self, self.running else { return }
            self.analysisStartHook?(self.cancellation)
        }
    }

    private func drainBoundedPackets() {
        guard running else { return }
        var metadata = ATLivePCMPacketMetadata()
        for _ in 0..<Self.maximumPacketsPerDrain {
            let consumed = scratchStorage.withUnsafeMutableStereo {
                transport.consume(
                    metadata: &metadata,
                    left: $0,
                    right: $1
                )
            }
            guard consumed else { break }
            let frameCount = Int(metadata.frameCount)
            guard frameCount > 0,
                  frameCount <= LivePCMTransport.maximumPacketFrameCount else {
                continue
            }
            // A complete window waiting for context consumes the one-window
            // PCM budget. Continue draining the bounded queue, but never begin
            // a second assembly until that immutable window is analyzed or
            // deterministically discarded.
            guard pendingWindow == nil else { continue }
            let window = scratchStorage.withUnsafeMutableStereo {
                assembler?.consume(
                    metadata: metadata,
                    counters: transport.counters,
                    left: UnsafeBufferPointer($0),
                    right: UnsafeBufferPointer($1),
                    ledger: ledger
                )
            }
            if let window,
               let range = matchingRange(for: window) {
                // One exact source window is the complete v1 analysis budget.
                pendingWindow = (range, window)
            }
        }
        analyzePendingWindowsIfPossible()
    }

    private func matchingRange(
        for window: LivePhrasePCMWindow
    ) -> ScheduledPhraseRange? {
        var match: ScheduledPhraseRange?
        ledger.forEachRetained {
            guard match == nil,
            $0.phraseIndex == window.phraseIndex &&
                $0.planFingerprint == window.planFingerprint &&
                $0.routeGeneration == window.routeGeneration &&
                $0.controllerRevision == window.controllerRevision &&
                $0.playerSampleRange.lowerBound ==
                    window.playerSampleRange.lowerBound else { return }
            match = $0
        }
        return match
    }

    private func analyzePendingWindowsIfPossible() {
        guard running else { return }
        guard let pendingWindow,
              let context,
              pendingWindow.0 == context.sourceRange else { return }
        self.pendingWindow = nil
        analyze(window: pendingWindow.1, context: context)
    }

    private func analyze(
        window: LivePhrasePCMWindow,
        context: LiveFeedbackAnalysisContext
    ) {
        analysisStartHook?(cancellation)
        guard running, !cancellation.isCancelled,
              context.isStructurallyValid,
              context.sourceRange.routeGeneration == window.routeGeneration,
              context.sourceRange.controllerRevision ==
                window.controllerRevision,
              context.sourceRange.playerSampleRange.lowerBound ==
                window.playerSampleRange.lowerBound,
              let artifacts else { return }
        let analyzed = window.withUnsafeStereo { left, right in
            LiveOutputWindowAnalyzer.analyze(
                left: left,
                right: right,
                planIdentity: context.sourceIdentity,
                routeGeneration: window.routeGeneration,
                controllerRevision: window.controllerRevision,
                playerSampleRange: window.playerSampleRange,
                sampleRate: sampleRate,
                captureProvenance: window.captureProvenance,
                artifacts: artifacts,
                qualityPolicyVersion: context.qualityPolicyVersion,
                cancellationRequested: { [cancellation] in
                    cancellation.isCancelled
                }
            )
        }
        guard let evidence = analyzed ?? nil,
              let target = LiveOutputWindowAnalyzer.target(
                evidence: evidence,
                artifacts: artifacts
              ) else { return }

        let proposal = LiveMasterHeadroomController.propose(
            evidence: evidence,
            target: target,
            incoming: context.incomingState,
            earliestEligibleFutureSample:
                context.earliestEligibleFutureSample
        )
        guard proposal.outcome != .unavailable else { return }
        let eligibleTarget = LiveMasterHeadroomEligibleTarget(
            plan: context.targetPlan,
            routeGeneration: window.routeGeneration,
            sampleRate: sampleRate,
            earliestEligibleFutureSample:
                context.earliestEligibleFutureSample,
            qualityPolicyVersion: evidence.qualityPolicyVersion,
            evaluatorVersion: evidence.evaluatorVersion,
            controllerPolicyVersion: evidence.controllerPolicyVersion
        )
        let binding = PendingLiveMasterHeadroomBinding(
            sourceIdentity: context.sourceIdentity,
            evidence: evidence,
            target: target,
            proposal: proposal,
            eligibleTarget: eligibleTarget
        )
        guard binding.isStructurallyValid(
            targetPlan: context.targetPlan,
            incoming: context.incomingState
        ) else { return }
        let result = LiveFeedbackWorkerResult(
            identity: identity,
            sourceRange: context.sourceRange,
            binding: binding
        )
        guard !cancellation.isCancelled else { return }
        resultDelivery.enqueue(identity: identity) {
            [resultHandler, result] deliveredIdentity in
            guard deliveredIdentity == result.identity else { return }
            resultHandler(result)
        }
    }
}
