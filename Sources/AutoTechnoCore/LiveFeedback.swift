import Foundation

package enum LiveFeedbackContract {
    package static let controllerPolicyVersion =
        "autotechno-live-master-headroom-controller.v1"
}

package enum LiveFeedbackProposalOutcome: String, Codable, Equatable, Sendable {
    case unavailable
    case hold
    case attenuate
    case recover
}

package enum LiveFeedbackReason: String, CaseIterable, Codable, Equatable, Sendable {
    case windowAccepted = "live.window-accepted.v1"
    case windowIncomplete = "live.window-incomplete.v1"
    case queueOverrun = "live.queue-overrun.v1"
    case routeMismatch = "live.route-mismatch.v1"
    case clockUnavailable = "live.clock-unavailable.v1"
    case evidenceNonFinite = "live.evidence-non-finite.v1"
    case profileUnavailable = "live.profile-unavailable.v1"
    case staleProposal = "live.stale-proposal.v1"
    case masterTrimSaturatedV1 = "live.master-trim-saturated.v1"

    fileprivate var preventsCommit: Bool {
        self != .windowAccepted && self != .masterTrimSaturatedV1
    }
}

/// Reduced, signal-free continuation for the single live master-headroom
/// controller. Pending observations never appear here: this value crosses a
/// phrase boundary only with the accepted prepared candidate.
package struct LiveMasterHeadroomContinuationState: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package let revision: Int
    package let committedTrimDB: Double
    package let consecutiveCleanWindows: Int
    package let lastProposalFingerprint: String?
    package let lastObservationFingerprint: String?
    package let lastAcceptedSourcePhraseIndex: Int?
    package let earliestEligibleFutureSample: Int64?

    package init(
        revision: Int = 0,
        committedTrimDB: Double = 0,
        consecutiveCleanWindows: Int = 0,
        lastProposalFingerprint: String? = nil,
        lastObservationFingerprint: String? = nil,
        lastAcceptedSourcePhraseIndex: Int? = nil,
        earliestEligibleFutureSample: Int64? = nil
    ) {
        self.revision = max(0, revision)
        self.committedTrimDB = committedTrimDB.isFinite
            ? min(0, max(-3, committedTrimDB))
            : 0
        self.consecutiveCleanWindows = min(2, max(0, consecutiveCleanWindows))
        self.lastProposalFingerprint = Self.nonempty(lastProposalFingerprint)
        self.lastObservationFingerprint = Self.nonempty(lastObservationFingerprint)
        self.lastAcceptedSourcePhraseIndex = lastAcceptedSourcePhraseIndex.map { max(0, $0) }
        self.earliestEligibleFutureSample = earliestEligibleFutureSample.map { max(0, $0) }
    }

    /// Stable provenance identity used to reject a proposal produced from a
    /// different committed controller revision.
    package var fingerprint: String {
        LiveFeedbackFingerprint.make([
            String(Self.schemaVersion),
            String(revision),
            String(committedTrimDB.bitPattern, radix: 16),
            String(consecutiveCleanWindows),
            lastProposalFingerprint ?? "<nil>",
            lastObservationFingerprint ?? "<nil>",
            lastAcceptedSourcePhraseIndex.map(String.init) ?? "<nil>",
            earliestEligibleFutureSample.map(String.init) ?? "<nil>",
        ])
    }

    /// Returns a new committed value only for one complete proposal produced
    /// from this exact incoming revision and a not-yet-accepted source phrase.
    /// Failure is an exact state hold.
    package func accepting(
        _ proposal: LiveMasterHeadroomProposal
    ) -> LiveMasterHeadroomContinuationState {
        let sourceIsNew = lastAcceptedSourcePhraseIndex.map {
            proposal.sourcePhraseIndex > $0
        } ?? true
        guard revision < Int.max,
              proposal.isStructurallyValid,
              proposal.outcome != .unavailable,
              !proposal.reasonCodes.contains(where: { $0.preventsCommit }),
              proposal.incomingRevision == revision,
              proposal.incomingStateFingerprint == fingerprint,
              proposal.fingerprint != lastProposalFingerprint,
              sourceIsNew else {
            return self
        }

        switch proposal.outcome {
        case .unavailable:
            return self
        case .hold:
            guard proposal.proposedTrimDB == committedTrimDB else { return self }
        case .attenuate:
            guard proposal.proposedTrimDB <= committedTrimDB else { return self }
        case .recover:
            guard proposal.proposedTrimDB >= committedTrimDB else { return self }
        }

        return LiveMasterHeadroomContinuationState(
            revision: revision + 1,
            committedTrimDB: proposal.proposedTrimDB,
            consecutiveCleanWindows: proposal.proposedCleanWindows,
            lastProposalFingerprint: proposal.fingerprint,
            lastObservationFingerprint: proposal.observationFingerprint,
            lastAcceptedSourcePhraseIndex: proposal.sourcePhraseIndex,
            earliestEligibleFutureSample: proposal.earliestEligibleFutureSample
        )
    }

    package func isImmediateSuccessor(
        of incoming: LiveMasterHeadroomContinuationState
    ) -> Bool {
        guard incoming.revision < Int.max,
              revision == incoming.revision + 1,
              let sourcePhraseIndex = lastAcceptedSourcePhraseIndex,
              let proposalFingerprint = lastProposalFingerprint,
              let observationFingerprint = lastObservationFingerprint,
              earliestEligibleFutureSample != nil,
              !proposalFingerprint.isEmpty,
              !observationFingerprint.isEmpty else {
            return false
        }
        return incoming.lastAcceptedSourcePhraseIndex.map {
            sourcePhraseIndex > $0
        } ?? true
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private static func optionalFingerprintIsCanonical(_ value: String?) -> Bool {
        value.map { nonempty($0) == $0 } ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case revision
        case committedTrimDB
        case consecutiveCleanWindows
        case lastProposalFingerprint
        case lastObservationFingerprint
        case lastAcceptedSourcePhraseIndex
        case earliestEligibleFutureSample
        case fingerprint
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let revision = try container.decode(Int.self, forKey: .revision)
        let trim = try container.decode(Double.self, forKey: .committedTrimDB)
        let cleanWindows = try container.decode(Int.self, forKey: .consecutiveCleanWindows)
        let proposalFingerprint = try container.decodeIfPresent(
            String.self,
            forKey: .lastProposalFingerprint
        )
        let observationFingerprint = try container.decodeIfPresent(
            String.self,
            forKey: .lastObservationFingerprint
        )
        let sourcePhraseIndex = try container.decodeIfPresent(
            Int.self,
            forKey: .lastAcceptedSourcePhraseIndex
        )
        let futureSample = try container.decodeIfPresent(
            Int64.self,
            forKey: .earliestEligibleFutureSample
        )
        let encodedFingerprint = try container.decode(String.self, forKey: .fingerprint)
        guard schemaVersion == Self.schemaVersion,
              revision >= 0,
              trim.isFinite,
              (-3...0).contains(trim),
              (0...2).contains(cleanWindows),
              sourcePhraseIndex.map({ $0 >= 0 }) ?? true,
              futureSample.map({ $0 >= 0 }) ?? true,
              Self.optionalFingerprintIsCanonical(proposalFingerprint),
              Self.optionalFingerprintIsCanonical(observationFingerprint) else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Invalid live master continuation wire values"
            )
        }
        let candidate = LiveMasterHeadroomContinuationState(
            revision: revision,
            committedTrimDB: trim,
            consecutiveCleanWindows: cleanWindows,
            lastProposalFingerprint: proposalFingerprint,
            lastObservationFingerprint: observationFingerprint,
            lastAcceptedSourcePhraseIndex: sourcePhraseIndex,
            earliestEligibleFutureSample: futureSample
        )
        guard candidate.fingerprint == encodedFingerprint else {
            throw DecodingError.dataCorruptedError(
                forKey: .fingerprint,
                in: container,
                debugDescription: "Live master continuation fingerprint mismatch"
            )
        }
        self = candidate
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(revision, forKey: .revision)
        try container.encode(committedTrimDB, forKey: .committedTrimDB)
        try container.encode(consecutiveCleanWindows, forKey: .consecutiveCleanWindows)
        try container.encodeIfPresent(lastProposalFingerprint, forKey: .lastProposalFingerprint)
        try container.encodeIfPresent(
            lastObservationFingerprint,
            forKey: .lastObservationFingerprint
        )
        try container.encodeIfPresent(
            lastAcceptedSourcePhraseIndex,
            forKey: .lastAcceptedSourcePhraseIndex
        )
        try container.encodeIfPresent(
            earliestEligibleFutureSample,
            forKey: .earliestEligibleFutureSample
        )
        try container.encode(fingerprint, forKey: .fingerprint)
    }
}

/// The bounded DSP-to-Core message. It contains identities, the reduced
/// controller transition, and no samples or analyzer-specific values.
package struct LiveMasterHeadroomProposal: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package static let unavailableTargetFingerprint =
        "live.target-unavailable.v1"
    package let controllerPolicyVersion: String
    package let targetFingerprint: String
    package let sourcePhraseIndex: Int
    package let sourcePlanFingerprint: String
    package let routeGeneration: Int
    package let playerSampleRange: Range<Int64>
    package let observationFingerprint: String?
    package let incomingRevision: Int
    package let incomingStateFingerprint: String
    package let outcome: LiveFeedbackProposalOutcome
    package let reasonCodes: [LiveFeedbackReason]
    package let proposedTrimDB: Double
    package let proposedCleanWindows: Int
    package let earliestEligibleFutureSample: Int64
    package let fingerprint: String

    package init(
        controllerPolicyVersion: String,
        targetFingerprint: String,
        sourcePhraseIndex: Int,
        sourcePlanFingerprint: String,
        routeGeneration: Int,
        playerSampleRange: Range<Int64>,
        observationFingerprint: String?,
        incomingRevision: Int,
        incomingStateFingerprint: String,
        outcome: LiveFeedbackProposalOutcome,
        reasonCodes: [LiveFeedbackReason],
        proposedTrimDB: Double,
        proposedCleanWindows: Int,
        earliestEligibleFutureSample: Int64
    ) {
        let canonicalSourcePhraseIndex = max(0, sourcePhraseIndex)
        let canonicalRouteGeneration = max(0, routeGeneration)
        let lowerBound = max(0, playerSampleRange.lowerBound)
        let upperBound = max(lowerBound, playerSampleRange.upperBound)
        let canonicalObservationFingerprint = Self.nonempty(observationFingerprint)
        let canonicalIncomingRevision = max(0, incomingRevision)
        var reasonsByRawValue: [String: LiveFeedbackReason] = [:]
        for reason in reasonCodes {
            reasonsByRawValue[reason.rawValue] = reason
        }
        let canonicalReasons = reasonsByRawValue.values.sorted {
            $0.rawValue < $1.rawValue
        }
        let canonicalTrim = proposedTrimDB.isFinite
            ? min(0, max(-3, proposedTrimDB))
            : proposedTrimDB
        let canonicalCleanWindows = min(2, max(0, proposedCleanWindows))
        let canonicalFutureSample = max(0, earliestEligibleFutureSample)

        self.controllerPolicyVersion = controllerPolicyVersion
        self.targetFingerprint = targetFingerprint
        self.sourcePhraseIndex = canonicalSourcePhraseIndex
        self.sourcePlanFingerprint = sourcePlanFingerprint
        self.routeGeneration = canonicalRouteGeneration
        self.playerSampleRange = lowerBound..<upperBound
        self.observationFingerprint = canonicalObservationFingerprint
        self.incomingRevision = canonicalIncomingRevision
        self.incomingStateFingerprint = incomingStateFingerprint
        self.outcome = outcome
        self.reasonCodes = canonicalReasons
        self.proposedTrimDB = canonicalTrim
        self.proposedCleanWindows = canonicalCleanWindows
        self.earliestEligibleFutureSample = canonicalFutureSample
        fingerprint = Self.computeFingerprint(
            controllerPolicyVersion: controllerPolicyVersion,
            targetFingerprint: targetFingerprint,
            sourcePhraseIndex: canonicalSourcePhraseIndex,
            sourcePlanFingerprint: sourcePlanFingerprint,
            routeGeneration: canonicalRouteGeneration,
            playerSampleRange: lowerBound..<upperBound,
            observationFingerprint: canonicalObservationFingerprint,
            incomingRevision: canonicalIncomingRevision,
            incomingStateFingerprint: incomingStateFingerprint,
            outcome: outcome,
            reasonCodes: canonicalReasons,
            proposedTrimDB: canonicalTrim,
            proposedCleanWindows: canonicalCleanWindows,
            earliestEligibleFutureSample: canonicalFutureSample
        )
    }

    package var isStructurallyValid: Bool {
        let targetPresent = Self.requiredFingerprintIsCanonical(targetFingerprint)
        let sourcePresent = Self.requiredFingerprintIsCanonical(sourcePlanFingerprint)
        let incomingPresent = Self.requiredFingerprintIsCanonical(incomingStateFingerprint)
        let canonicalReasons = reasonCodes.sorted { $0.rawValue < $1.rawValue }
        let reasonsAreUnique = Set(reasonCodes.map(\.rawValue)).count == reasonCodes.count
        let acceptedReasons: Bool
        switch outcome {
        case .unavailable:
            acceptedReasons = !reasonCodes.isEmpty &&
                !reasonCodes.contains(.windowAccepted) &&
                !reasonCodes.contains(.masterTrimSaturatedV1)
        case .hold:
            let ordinaryHold = reasonCodes == [.windowAccepted]
            let saturatedHold =
                reasonCodes == [.masterTrimSaturatedV1, .windowAccepted] &&
                proposedTrimDB == -3 && proposedCleanWindows == 0
            acceptedReasons = (ordinaryHold || saturatedHold) &&
                observationFingerprint != nil
        case .attenuate, .recover:
            acceptedReasons = reasonCodes == [.windowAccepted] &&
                observationFingerprint != nil
        }
        let computedFingerprint = Self.computeFingerprint(
            controllerPolicyVersion: controllerPolicyVersion,
            targetFingerprint: targetFingerprint,
            sourcePhraseIndex: sourcePhraseIndex,
            sourcePlanFingerprint: sourcePlanFingerprint,
            routeGeneration: routeGeneration,
            playerSampleRange: playerSampleRange,
            observationFingerprint: observationFingerprint,
            incomingRevision: incomingRevision,
            incomingStateFingerprint: incomingStateFingerprint,
            outcome: outcome,
            reasonCodes: reasonCodes,
            proposedTrimDB: proposedTrimDB,
            proposedCleanWindows: proposedCleanWindows,
            earliestEligibleFutureSample: earliestEligibleFutureSample
        )
        let targetMatchesOutcome = outcome == .unavailable ||
            targetFingerprint != Self.unavailableTargetFingerprint
        return controllerPolicyVersion ==
                LiveFeedbackContract.controllerPolicyVersion &&
            targetPresent && targetMatchesOutcome &&
            sourcePresent && incomingPresent &&
            playerSampleRange.lowerBound >= 0 &&
            !playerSampleRange.isEmpty &&
            earliestEligibleFutureSample > playerSampleRange.upperBound &&
            proposedTrimDB.isFinite &&
            (-3...0).contains(proposedTrimDB) &&
            (0...2).contains(proposedCleanWindows) &&
            reasonCodes == canonicalReasons && reasonsAreUnique && acceptedReasons &&
            fingerprint == computedFingerprint
    }

    private static func computeFingerprint(
        controllerPolicyVersion: String,
        targetFingerprint: String,
        sourcePhraseIndex: Int,
        sourcePlanFingerprint: String,
        routeGeneration: Int,
        playerSampleRange: Range<Int64>,
        observationFingerprint: String?,
        incomingRevision: Int,
        incomingStateFingerprint: String,
        outcome: LiveFeedbackProposalOutcome,
        reasonCodes: [LiveFeedbackReason],
        proposedTrimDB: Double,
        proposedCleanWindows: Int,
        earliestEligibleFutureSample: Int64
    ) -> String {
        var fields = [
            String(Self.schemaVersion),
            controllerPolicyVersion,
            targetFingerprint,
            String(sourcePhraseIndex),
            sourcePlanFingerprint,
            String(routeGeneration),
            String(playerSampleRange.lowerBound),
            String(playerSampleRange.upperBound),
            observationFingerprint ?? "<nil>",
            String(incomingRevision),
            incomingStateFingerprint,
            outcome.rawValue,
            String(reasonCodes.count),
        ]
        fields.append(contentsOf: reasonCodes.map(\.rawValue))
        fields.append(contentsOf: [
            String(proposedTrimDB.bitPattern, radix: 16),
            String(proposedCleanWindows),
            String(earliestEligibleFutureSample),
        ])
        return LiveFeedbackFingerprint.make(fields)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private static func requiredFingerprintIsCanonical(_ value: String) -> Bool {
        nonempty(value) == value
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case controllerPolicyVersion
        case targetFingerprint
        case sourcePhraseIndex
        case sourcePlanFingerprint
        case routeGeneration
        case playerSampleRangeLowerBound
        case playerSampleRangeUpperBound
        case observationFingerprint
        case incomingRevision
        case incomingStateFingerprint
        case outcome
        case reasonCodes
        case proposedTrimDB
        case proposedCleanWindows
        case earliestEligibleFutureSample
        case fingerprint
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let controllerPolicyVersion = try container.decode(
            String.self,
            forKey: .controllerPolicyVersion
        )
        let targetFingerprint = try container.decode(
            String.self,
            forKey: .targetFingerprint
        )
        let sourcePhraseIndex = try container.decode(Int.self, forKey: .sourcePhraseIndex)
        let sourcePlanFingerprint = try container.decode(
            String.self,
            forKey: .sourcePlanFingerprint
        )
        let routeGeneration = try container.decode(Int.self, forKey: .routeGeneration)
        let lowerBound = try container.decode(
            Int64.self,
            forKey: .playerSampleRangeLowerBound
        )
        let upperBound = try container.decode(
            Int64.self,
            forKey: .playerSampleRangeUpperBound
        )
        let observationFingerprint = try container.decodeIfPresent(
            String.self,
            forKey: .observationFingerprint
        )
        let incomingRevision = try container.decode(Int.self, forKey: .incomingRevision)
        let incomingStateFingerprint = try container.decode(
            String.self,
            forKey: .incomingStateFingerprint
        )
        let outcome = try container.decode(
            LiveFeedbackProposalOutcome.self,
            forKey: .outcome
        )
        let reasons = try container.decode([LiveFeedbackReason].self, forKey: .reasonCodes)
        let trim = try container.decode(Double.self, forKey: .proposedTrimDB)
        let cleanWindows = try container.decode(Int.self, forKey: .proposedCleanWindows)
        let futureSample = try container.decode(
            Int64.self,
            forKey: .earliestEligibleFutureSample
        )
        let encodedFingerprint = try container.decode(String.self, forKey: .fingerprint)
        let canonicalReasons = reasons.sorted { $0.rawValue < $1.rawValue }
        guard schemaVersion == Self.schemaVersion,
              controllerPolicyVersion ==
                LiveFeedbackContract.controllerPolicyVersion,
              Self.requiredFingerprintIsCanonical(targetFingerprint),
              sourcePhraseIndex >= 0,
              Self.requiredFingerprintIsCanonical(sourcePlanFingerprint),
              routeGeneration >= 0,
              lowerBound >= 0,
              upperBound > lowerBound,
              observationFingerprint.map({ Self.nonempty($0) == $0 }) ?? true,
              incomingRevision >= 0,
              Self.requiredFingerprintIsCanonical(incomingStateFingerprint),
              reasons == canonicalReasons,
              Set(reasons.map(\.rawValue)).count == reasons.count,
              trim.isFinite,
              (-3...0).contains(trim),
              (0...2).contains(cleanWindows),
              futureSample > upperBound else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Invalid live master proposal wire values"
            )
        }
        let candidate = LiveMasterHeadroomProposal(
            controllerPolicyVersion: controllerPolicyVersion,
            targetFingerprint: targetFingerprint,
            sourcePhraseIndex: sourcePhraseIndex,
            sourcePlanFingerprint: sourcePlanFingerprint,
            routeGeneration: routeGeneration,
            playerSampleRange: lowerBound..<upperBound,
            observationFingerprint: observationFingerprint,
            incomingRevision: incomingRevision,
            incomingStateFingerprint: incomingStateFingerprint,
            outcome: outcome,
            reasonCodes: reasons,
            proposedTrimDB: trim,
            proposedCleanWindows: cleanWindows,
            earliestEligibleFutureSample: futureSample
        )
        guard candidate.isStructurallyValid,
              candidate.fingerprint == encodedFingerprint else {
            throw DecodingError.dataCorruptedError(
                forKey: .fingerprint,
                in: container,
                debugDescription: "Live master proposal fingerprint mismatch"
            )
        }
        self = candidate
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(
            controllerPolicyVersion,
            forKey: .controllerPolicyVersion
        )
        try container.encode(targetFingerprint, forKey: .targetFingerprint)
        try container.encode(sourcePhraseIndex, forKey: .sourcePhraseIndex)
        try container.encode(sourcePlanFingerprint, forKey: .sourcePlanFingerprint)
        try container.encode(routeGeneration, forKey: .routeGeneration)
        try container.encode(playerSampleRange.lowerBound, forKey: .playerSampleRangeLowerBound)
        try container.encode(playerSampleRange.upperBound, forKey: .playerSampleRangeUpperBound)
        try container.encodeIfPresent(observationFingerprint, forKey: .observationFingerprint)
        try container.encode(incomingRevision, forKey: .incomingRevision)
        try container.encode(incomingStateFingerprint, forKey: .incomingStateFingerprint)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(reasonCodes, forKey: .reasonCodes)
        try container.encode(proposedTrimDB, forKey: .proposedTrimDB)
        try container.encode(proposedCleanWindows, forKey: .proposedCleanWindows)
        try container.encode(earliestEligibleFutureSample, forKey: .earliestEligibleFutureSample)
        try container.encode(fingerprint, forKey: .fingerprint)
    }
}

private enum LiveFeedbackFingerprint {
    static func make(_ fields: [String]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for field in fields {
            var byteCount = UInt64(field.utf8.count)
            for _ in 0..<MemoryLayout<UInt64>.size {
                hash ^= byteCount & 0xff
                hash &*= 1_099_511_628_211
                byteCount >>= 8
            }
            for byte in field.utf8 {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
        }
        let value = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - value.count) + value
    }
}
