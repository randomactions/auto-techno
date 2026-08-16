import AutoTechnoCore
import Foundation
import Testing

@Suite("Live master headroom Core contract")
struct LiveFeedbackCoreTests {
    @Test("Continuation clamps attenuation-only state")
    func continuationClampsAttenuationOnly() throws {
        let overAttenuated = LiveMasterHeadroomContinuationState(
            revision: -4,
            committedTrimDB: -8,
            consecutiveCleanWindows: 9,
            lastProposalFingerprint: "proposal",
            lastObservationFingerprint: "observation",
            lastAcceptedSourcePhraseIndex: -9,
            earliestEligibleFutureSample: -200
        )
        #expect(overAttenuated.revision == 0)
        #expect(overAttenuated.committedTrimDB == -3)
        #expect(overAttenuated.consecutiveCleanWindows == 2)
        #expect(overAttenuated.lastAcceptedSourcePhraseIndex == 0)
        #expect(overAttenuated.earliestEligibleFutureSample == 0)

        let boosting = LiveMasterHeadroomContinuationState(
            committedTrimDB: 1.5,
            consecutiveCleanWindows: -1
        )
        #expect(boosting.committedTrimDB == 0)
        #expect(boosting.consecutiveCleanWindows == 0)
        #expect(LiveMasterHeadroomContinuationState().fingerprint ==
                LiveMasterHeadroomContinuationState().fingerprint)
        let encoded = try JSONEncoder().encode(overAttenuated)
        let decoded = try JSONDecoder().decode(
            LiveMasterHeadroomContinuationState.self,
            from: encoded
        )
        #expect(decoded == overAttenuated)
        #expect(decoded.fingerprint == overAttenuated.fingerprint)
    }

    @Test("Proposal canonicalizes positions and reason order")
    func proposalCanonicalizesReasons() {
        let proposal = makeProposal(
            sourcePhraseIndex: -2,
            routeGeneration: -3,
            playerSampleRange: -12..<128,
            reasonCodes: [.windowAccepted, .routeMismatch, .windowAccepted]
        )

        #expect(proposal.sourcePhraseIndex == 0)
        #expect(proposal.routeGeneration == 0)
        #expect(proposal.playerSampleRange == 0..<128)
        #expect(proposal.reasonCodes == [.routeMismatch, .windowAccepted])
        #expect(LiveMasterHeadroomContinuationState().accepting(proposal) ==
                LiveMasterHeadroomContinuationState())
    }

    @Test("Unavailable proposal cannot mutate committed trim")
    func unavailableProposalCannotMutateTrim() {
        let incoming = LiveMasterHeadroomContinuationState(
            revision: 4,
            committedTrimDB: -0.75,
            consecutiveCleanWindows: 1,
            lastProposalFingerprint: "previous-proposal",
            lastObservationFingerprint: "previous-observation",
            lastAcceptedSourcePhraseIndex: 1,
            earliestEligibleFutureSample: 40_000
        )
        let proposal = makeProposal(
            incoming: incoming,
            outcome: .unavailable,
            reasonCodes: [.windowIncomplete],
            proposedTrimDB: -2.5,
            proposedCleanWindows: 0
        )

        #expect(incoming.accepting(proposal) == incoming)
    }

    @Test("Accepted transition advances exactly once")
    func acceptedTransitionAdvancesOnce() {
        let incoming = LiveMasterHeadroomContinuationState(
            revision: 3,
            committedTrimDB: -0.5,
            consecutiveCleanWindows: 0
        )
        let proposal = makeProposal(
            incoming: incoming,
            outcome: .attenuate,
            reasonCodes: [.windowAccepted],
            proposedTrimDB: -0.75,
            proposedCleanWindows: 0
        )

        let accepted = incoming.accepting(proposal)
        #expect(accepted.revision == 4)
        #expect(accepted.committedTrimDB == -0.75)
        #expect(accepted.lastProposalFingerprint == proposal.fingerprint)
        #expect(accepted.lastObservationFingerprint == "observation")
        #expect(accepted.lastAcceptedSourcePhraseIndex == proposal.sourcePhraseIndex)
        #expect(accepted.earliestEligibleFutureSample == 2_000)
        #expect(accepted.accepting(proposal) == accepted)
    }

    @Test("A rebuilt proposal cannot reuse an accepted source phrase")
    func rebuiltProposalForSameSourcePhraseIsRejected() {
        let incoming = LiveMasterHeadroomContinuationState()
        let first = makeProposal(
            incoming: incoming,
            sourcePhraseIndex: 8,
            outcome: .attenuate,
            proposedTrimDB: -0.25
        )
        let accepted = incoming.accepting(first)
        let rebuilt = makeProposal(
            incoming: accepted,
            sourcePhraseIndex: 8,
            outcome: .attenuate,
            proposedTrimDB: -0.5
        )

        #expect(accepted.revision == 1)
        #expect(accepted.accepting(rebuilt) == accepted)
    }

    @Test("Maximum revision is terminal without overflow")
    func maximumRevisionCannotAdvance() throws {
        let incoming = LiveMasterHeadroomContinuationState(
            revision: .max,
            committedTrimDB: -0.5,
            consecutiveCleanWindows: 0,
            lastProposalFingerprint: "previous-proposal",
            lastObservationFingerprint: "previous-observation",
            lastAcceptedSourcePhraseIndex: 4,
            earliestEligibleFutureSample: 1_500
        )
        let proposal = makeProposal(
            incoming: incoming,
            sourcePhraseIndex: 5,
            incomingRevision: .max,
            outcome: .attenuate,
            proposedTrimDB: -0.75
        )

        #expect(proposal.incomingRevision == Int.max)
        #expect(incoming.accepting(proposal) == incoming)
        let decodedState = try JSONDecoder().decode(
            LiveMasterHeadroomContinuationState.self,
            from: JSONEncoder().encode(incoming)
        )
        let decodedProposal = try JSONDecoder().decode(
            LiveMasterHeadroomProposal.self,
            from: JSONEncoder().encode(proposal)
        )
        #expect(decodedState.revision == Int.max)
        #expect(decodedProposal.incomingRevision == Int.max)
        #expect(decodedState.accepting(decodedProposal) == decodedState)
    }

    @Test("Stale proposal is rejected without partial state")
    func staleProposalIsRejected() {
        let incoming = LiveMasterHeadroomContinuationState(
            revision: 5,
            committedTrimDB: -1,
            consecutiveCleanWindows: 1
        )
        let staleRevision = makeProposal(
            incomingRevision: 4,
            incomingStateFingerprint: incoming.fingerprint,
            outcome: .recover,
            reasonCodes: [.windowAccepted],
            proposedTrimDB: -0.875,
            proposedCleanWindows: 0
        )
        let staleFingerprint = makeProposal(
            incomingRevision: incoming.revision,
            incomingStateFingerprint: "different-state",
            outcome: .recover,
            reasonCodes: [.windowAccepted],
            proposedTrimDB: -0.875,
            proposedCleanWindows: 0
        )
        let reasonedStale = makeProposal(
            incoming: incoming,
            outcome: .hold,
            reasonCodes: [.staleProposal],
            proposedTrimDB: -1,
            proposedCleanWindows: 1
        )
        let nonFinite = makeProposal(
            incoming: incoming,
            outcome: .attenuate,
            reasonCodes: [.windowAccepted],
            proposedTrimDB: .nan,
            proposedCleanWindows: 0
        )

        #expect(incoming.accepting(staleRevision) == incoming)
        #expect(incoming.accepting(staleFingerprint) == incoming)
        #expect(incoming.accepting(reasonedStale) == incoming)
        #expect(incoming.accepting(nonFinite) == incoming)
    }

    @Test("Proposal fingerprint binds every semantic source identity")
    func proposalFingerprintBindsSemanticPayload() {
        let baseline = makeProposal()
        let replay = makeProposal()
        let changedSource = makeProposal(sourcePhraseIndex: 3)
        let changedRoute = makeProposal(routeGeneration: 4)
        let changedRange = makeProposal(playerSampleRange: 101..<1_101)

        #expect(baseline.fingerprint == replay.fingerprint)
        #expect(changedSource.fingerprint != baseline.fingerprint)
        #expect(changedRoute.fingerprint != baseline.fingerprint)
        #expect(changedRange.fingerprint != baseline.fingerprint)
    }

    @Test("Strict decoding rejects forged or noncanonical state")
    func strictStateDecodingRejectsMaliciousJSON() throws {
        let valid = LiveMasterHeadroomContinuationState(
            revision: 1,
            committedTrimDB: -0.25,
            consecutiveCleanWindows: 1,
            lastProposalFingerprint: "proposal",
            lastObservationFingerprint: "observation",
            lastAcceptedSourcePhraseIndex: 2,
            earliestEligibleFutureSample: 2_000
        )
        let baseline = try jsonObject(valid)
        for (key, value) in [
            ("schemaVersion", -1),
            ("revision", -1),
            ("committedTrimDB", 0.1),
            ("committedTrimDB", -3.1),
            ("consecutiveCleanWindows", 3),
            ("lastAcceptedSourcePhraseIndex", -1),
            ("earliestEligibleFutureSample", -1),
        ] {
            var forged = baseline
            forged[key] = value
            try expectDecodeFailure(
                LiveMasterHeadroomContinuationState.self,
                object: forged
            )
        }

        var nonFinite = baseline
        nonFinite["committedTrimDB"] = "NaN"
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        try expectDecodeFailure(
            LiveMasterHeadroomContinuationState.self,
            object: nonFinite,
            decoder: decoder
        )
    }

    @Test("Strict decoding rejects forged proposal payload and fingerprint")
    func strictProposalDecodingRejectsMaliciousJSON() throws {
        let proposal = makeProposal()
        let encoded = try JSONEncoder().encode(proposal)
        let decoded = try JSONDecoder().decode(
            LiveMasterHeadroomProposal.self,
            from: encoded
        )
        #expect(decoded == proposal)
        #expect(decoded.isStructurallyValid)
        let baseline = try jsonObject(proposal)
        let mutations: [(String, Any)] = [
            ("schemaVersion", 2),
            ("sourcePhraseIndex", -1),
            ("routeGeneration", -1),
            ("incomingRevision", -1),
            ("playerSampleRangeLowerBound", -1),
            ("playerSampleRangeUpperBound", 0),
            ("earliestEligibleFutureSample", -1),
            ("proposedTrimDB", 0.1),
            ("proposedTrimDB", -3.1),
            ("proposedCleanWindows", 3),
            ("reasonCodes", [
                LiveFeedbackReason.windowAccepted.rawValue,
                LiveFeedbackReason.windowAccepted.rawValue,
            ]),
            ("fingerprint", "forged"),
        ]
        for (key, value) in mutations {
            var forged = baseline
            forged[key] = value
            try expectDecodeFailure(LiveMasterHeadroomProposal.self, object: forged)
        }

        var nonFinite = baseline
        nonFinite["proposedTrimDB"] = "NaN"
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        try expectDecodeFailure(
            LiveMasterHeadroomProposal.self,
            object: nonFinite,
            decoder: decoder
        )
    }

    private func makeProposal(
        incoming: LiveMasterHeadroomContinuationState? = nil,
        sourcePhraseIndex: Int = 2,
        routeGeneration: Int = 3,
        playerSampleRange: Range<Int64> = 100..<1_100,
        incomingRevision: Int? = nil,
        incomingStateFingerprint: String? = nil,
        outcome: LiveFeedbackProposalOutcome = .hold,
        reasonCodes: [LiveFeedbackReason] = [.windowAccepted],
        proposedTrimDB: Double = -0.5,
        proposedCleanWindows: Int = 0
    ) -> LiveMasterHeadroomProposal {
        let state = incoming ?? LiveMasterHeadroomContinuationState()
        return LiveMasterHeadroomProposal(
            sourcePhraseIndex: sourcePhraseIndex,
            sourcePlanFingerprint: "plan",
            routeGeneration: routeGeneration,
            playerSampleRange: playerSampleRange,
            observationFingerprint: "observation",
            incomingRevision: incomingRevision ?? state.revision,
            incomingStateFingerprint: incomingStateFingerprint ?? state.fingerprint,
            outcome: outcome,
            reasonCodes: reasonCodes,
            proposedTrimDB: proposedTrimDB,
            proposedCleanWindows: proposedCleanWindows,
            earliestEligibleFutureSample: 2_000
        )
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
                as? [String: Any]
        )
    }

    private func expectDecodeFailure<T: Decodable>(
        _ type: T.Type,
        object: [String: Any],
        decoder: JSONDecoder = JSONDecoder()
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        do {
            _ = try decoder.decode(type, from: data)
            Issue.record("Expected strict decoding to reject forged \(T.self) JSON")
        } catch is DecodingError {
            // Expected strict wire-contract rejection.
        }
    }
}
