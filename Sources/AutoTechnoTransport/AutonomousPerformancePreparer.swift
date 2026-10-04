import AutoTechnoCore
import AutoTechnoDSP
import Foundation

/// Immutable identity for one detached preparation transaction. Platform
/// transports use the same key so stale work, route rebuilds, quality-state
/// changes, and live-master proposals fail closed before PCM enters an output
/// queue.
package struct PhrasePreparationKey: Hashable, Sendable {
    package let sessionSeed: UInt64
    package let phraseIndex: Int
    /// Exact route rate. Rounding here would let nearby fractional hardware
    /// rates share provenance while playing at different speeds.
    package let sampleRate: Double
    package let channelCount: Int
    package let routeRecovery: Bool
    package let qualityRetryOrdinal: Int
    package let qualityRecoveryContext: AutonomousQualityRecoveryContext
    package let qualityRevision: Int
    package let qualityPolicyVersion: String
    package let qualityControllerFingerprint: String?
    package let routeGeneration: Int
    package let incomingLiveMasterRevision: Int
    package let incomingLiveMasterStateFingerprint: String
    package let pendingLiveMasterProposalFingerprint: String?
    package let liveEarliestEligibleFutureSample: Int64?
    package let liveTargetStartSample: Int64?

    package init(
        sessionSeed: UInt64,
        phraseIndex: Int,
        sampleRate: Double,
        channelCount: Int,
        routeRecovery: Bool,
        qualityRevision: Int,
        qualityPolicyVersion: String,
        qualityControllerFingerprint: String?,
        routeGeneration: Int,
        incomingLiveMasterRevision: Int,
        incomingLiveMasterStateFingerprint: String,
        pendingLiveMasterProposalFingerprint: String?,
        liveEarliestEligibleFutureSample: Int64?,
        liveTargetStartSample: Int64?,
        qualityRetryOrdinal: Int = 0,
        qualityRecoveryContext: AutonomousQualityRecoveryContext? = nil
    ) {
        self.sessionSeed = sessionSeed
        self.phraseIndex = phraseIndex
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.routeRecovery = routeRecovery
        let resolvedRecoveryContext = qualityRecoveryContext ??
            AutonomousQualityRecoveryContext(ordinal: qualityRetryOrdinal)
        self.qualityRetryOrdinal = resolvedRecoveryContext.ordinal
        self.qualityRecoveryContext = resolvedRecoveryContext
        self.qualityRevision = qualityRevision
        self.qualityPolicyVersion = qualityPolicyVersion
        self.qualityControllerFingerprint = qualityControllerFingerprint
        self.routeGeneration = routeGeneration
        self.incomingLiveMasterRevision = incomingLiveMasterRevision
        self.incomingLiveMasterStateFingerprint =
            incomingLiveMasterStateFingerprint
        self.pendingLiveMasterProposalFingerprint =
            pendingLiveMasterProposalFingerprint
        self.liveEarliestEligibleFutureSample = liveEarliestEligibleFutureSample
        self.liveTargetStartSample = liveTargetStartSample
    }
}

/// Deterministic, non-PCM serialization of every identity required to replay
/// one detached preparation boundary. Canonical state remains in its existing
/// Core and DSP owners; this record proves that a restored request contains the
/// exact same state, route, recovery context, and future sample coordinates.
package struct PhrasePreparationReplayIdentity:
        Codable, Equatable, Hashable, Sendable {
    package static let schemaVersion = 1

    private struct Payload: Codable, Equatable, Hashable, Sendable {
        let schemaVersion: Int
        let sessionSeed: UInt64
        let phraseIndex: Int
        let sourceStateFingerprint: String
        let incomingLongHorizonStateFingerprint: String?
        let incomingRenderStateFingerprint: String
        let incomingGraphStateFingerprint: String
        let previousGraphFingerprint: String?
        let sampleRate: Double
        let channelCount: Int
        let routeRecovery: Bool
        let routeGeneration: Int
        let routeFingerprint: String
        let qualityRetryWave: UInt64
        let qualityRetryOrdinal: Int
        let qualityPresentedRepeatBars: UInt64
        let qualityRecoveryIntent: AutonomousQualityRecoveryIntent
        let qualityRevision: Int
        let qualityPolicyVersion: String
        let qualityControllerFingerprint: String?
        let incomingLiveMasterRevision: Int
        let incomingLiveMasterStateFingerprint: String
        let pendingLiveMasterProposalFingerprint: String?
        let liveEarliestEligibleFutureSample: Int64?
        let liveTargetStartSample: Int64?
        let bindingsValid: Bool
    }

    private let payload: Payload
    package let fingerprint: String

    package var sessionSeed: UInt64 { payload.sessionSeed }
    package var phraseIndex: Int { payload.phraseIndex }
    package var sourceStateFingerprint: String {
        payload.sourceStateFingerprint
    }
    package var incomingLongHorizonStateFingerprint: String? {
        payload.incomingLongHorizonStateFingerprint
    }
    package var incomingRenderStateFingerprint: String {
        payload.incomingRenderStateFingerprint
    }
    package var incomingGraphStateFingerprint: String {
        payload.incomingGraphStateFingerprint
    }
    package var previousGraphFingerprint: String? {
        payload.previousGraphFingerprint
    }
    package var routeGeneration: Int { payload.routeGeneration }
    package var liveTargetStartSample: Int64? {
        payload.liveTargetStartSample
    }

    package init(
        key: PhrasePreparationKey,
        sourceState: AutonomousSessionState,
        incomingLongHorizonState: LongHorizonFutureAdaptationState?,
        incomingRenderState: RenderState,
        incomingGraphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        pendingLiveMasterBinding: PendingLiveMasterHeadroomBinding?
    ) {
        let expectedQualityControllerFingerprint =
            sourceState.quality.observedControllerStateFingerprint ??
            sourceState.quality.acceptedControllerStateFingerprint
        let proposal = pendingLiveMasterBinding?.proposal
        let bindingsValid = key.sessionSeed == sourceState.rootSeed &&
            key.phraseIndex == sourceState.phraseIndex &&
            key.qualityRetryOrdinal == key.qualityRecoveryContext.ordinal &&
            key.qualityRevision == sourceState.quality.revision &&
            key.qualityPolicyVersion == sourceState.quality.policyVersion &&
            key.qualityControllerFingerprint ==
                expectedQualityControllerFingerprint &&
            key.incomingLiveMasterRevision ==
                sourceState.liveMasterHeadroom.revision &&
            key.incomingLiveMasterStateFingerprint ==
                sourceState.liveMasterHeadroom.fingerprint &&
            key.pendingLiveMasterProposalFingerprint == proposal?.fingerprint &&
            key.liveEarliestEligibleFutureSample ==
                proposal?.earliestEligibleFutureSample &&
            (proposal == nil) == (key.liveTargetStartSample == nil) &&
            (proposal.map {
                $0.incomingRevision == key.incomingLiveMasterRevision &&
                    $0.incomingStateFingerprint ==
                        key.incomingLiveMasterStateFingerprint &&
                    $0.routeGeneration == key.routeGeneration
            } ?? true)
        payload = Payload(
            schemaVersion: Self.schemaVersion,
            sessionSeed: key.sessionSeed,
            phraseIndex: key.phraseIndex,
            sourceStateFingerprint:
                AutonomousCandidateFingerprint.sessionState(sourceState),
            incomingLongHorizonStateFingerprint:
                incomingLongHorizonState?.fingerprint,
            incomingRenderStateFingerprint:
                AutonomousCandidateFingerprint.renderState(
                    incomingRenderState
                ),
            incomingGraphStateFingerprint:
                AutonomousCandidateFingerprint.generatedDSPState(
                    incomingGraphState
                ),
            previousGraphFingerprint: previousGraph.map {
                AutonomousCandidateFingerprint.graph($0)
            },
            sampleRate: key.sampleRate,
            channelCount: key.channelCount,
            routeRecovery: key.routeRecovery,
            routeGeneration: key.routeGeneration,
            routeFingerprint: AutonomousCandidateFingerprint.route(
                sampleRate: key.sampleRate,
                channelCount: key.channelCount,
                generation: key.routeGeneration
            ),
            qualityRetryWave: key.qualityRecoveryContext.wave,
            qualityRetryOrdinal: key.qualityRecoveryContext.ordinal,
            qualityPresentedRepeatBars:
                key.qualityRecoveryContext.presentedRepeatBars,
            qualityRecoveryIntent: key.qualityRecoveryContext.intent,
            qualityRevision: key.qualityRevision,
            qualityPolicyVersion: key.qualityPolicyVersion,
            qualityControllerFingerprint:
                key.qualityControllerFingerprint,
            incomingLiveMasterRevision:
                key.incomingLiveMasterRevision,
            incomingLiveMasterStateFingerprint:
                key.incomingLiveMasterStateFingerprint,
            pendingLiveMasterProposalFingerprint:
                key.pendingLiveMasterProposalFingerprint,
            liveEarliestEligibleFutureSample:
                key.liveEarliestEligibleFutureSample,
            liveTargetStartSample: key.liveTargetStartSample,
            bindingsValid: bindingsValid
        )
        fingerprint = Self.fingerprint(payload)
    }

    package var isComplete: Bool {
        payload.schemaVersion == Self.schemaVersion &&
            payload.phraseIndex >= 0 &&
            payload.sampleRate.isFinite && payload.sampleRate > 0 &&
            payload.channelCount ==
                QualityQualificationContract.requiredRouteChannelCount &&
            payload.routeGeneration >= 0 &&
            payload.qualityRetryOrdinal >= 0 &&
            payload.qualityRevision >= 0 &&
            !payload.qualityPolicyVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty &&
            payload.incomingLiveMasterRevision >= 0 &&
            (payload.liveEarliestEligibleFutureSample.map { $0 >= 0 } ?? true) &&
            (payload.liveTargetStartSample.map { $0 > 0 } ?? true) &&
            Self.isFingerprint(payload.sourceStateFingerprint) &&
            Self.isOptionalFingerprint(
                payload.incomingLongHorizonStateFingerprint
            ) &&
            Self.isFingerprint(payload.incomingRenderStateFingerprint) &&
            Self.isFingerprint(payload.incomingGraphStateFingerprint) &&
            Self.isOptionalFingerprint(payload.previousGraphFingerprint) &&
            Self.isFingerprint(payload.routeFingerprint) &&
            Self.isOptionalFingerprint(
                payload.qualityControllerFingerprint
            ) &&
            Self.isFingerprint(
                payload.incomingLiveMasterStateFingerprint
            ) &&
            Self.isOptionalFingerprint(
                payload.pendingLiveMasterProposalFingerprint
            ) &&
            payload.bindingsValid &&
            fingerprint == Self.fingerprint(payload)
    }

    package func matches(_ request: PhrasePreparationRequest) -> Bool {
        self == Self(
            key: request.key,
            sourceState: request.sourceState,
            incomingLongHorizonState: request.incomingLongHorizonState,
            incomingRenderState: request.incomingRenderState,
            incomingGraphState: request.incomingGraphState,
            previousGraph: request.previousGraph,
            pendingLiveMasterBinding: request.pendingLiveMasterBinding
        )
    }

    package func deterministicJSON() throws -> Data {
        try Self.canonicalData(self)
    }

    private enum CodingKeys: String, CodingKey {
        case payload
        case fingerprint
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        payload = try container.decode(Payload.self, forKey: .payload)
        fingerprint = try container.decode(String.self, forKey: .fingerprint)
        guard isComplete else {
            throw DecodingError.dataCorruptedError(
                forKey: .fingerprint,
                in: container,
                debugDescription: "Preparation replay identity mismatch"
            )
        }
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(payload, forKey: .payload)
        try container.encode(fingerprint, forKey: .fingerprint)
    }

    private static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func fingerprint(_ payload: Payload) -> String {
        guard let data = try? canonicalData(payload) else { return "" }
        var value: UInt64 = 0xcbf29ce484222325
        for byte in data {
            value ^= UInt64(byte)
            value &*= 0x100000001b3
        }
        return String(format: "%016llx", value)
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }

    private static func isOptionalFingerprint(_ value: String?) -> Bool {
        value.map(isFingerprint) ?? true
    }
}

package struct PhrasePreparationRequest: Sendable {
    package let key: PhrasePreparationKey
    package let sourceState: AutonomousSessionState
    package let incomingLongHorizonState: LongHorizonFutureAdaptationState?
    package let incomingRenderState: RenderState
    package let incomingGraphState: GeneratedDSPContinuationState
    package let previousGraph: DSPGraphPlan?
    package let pendingLiveMasterBinding: PendingLiveMasterHeadroomBinding?
    package let replayIdentity: PhrasePreparationReplayIdentity

    package init(
        key: PhrasePreparationKey,
        sourceState: AutonomousSessionState,
        incomingLongHorizonState: LongHorizonFutureAdaptationState?,
        incomingRenderState: RenderState,
        incomingGraphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        pendingLiveMasterBinding: PendingLiveMasterHeadroomBinding?
    ) {
        self.key = key
        self.sourceState = sourceState
        self.incomingLongHorizonState = incomingLongHorizonState
        self.incomingRenderState = incomingRenderState
        self.incomingGraphState = incomingGraphState
        self.previousGraph = previousGraph
        self.pendingLiveMasterBinding = pendingLiveMasterBinding
        replayIdentity = PhrasePreparationReplayIdentity(
            key: key,
            sourceState: sourceState,
            incomingLongHorizonState: incomingLongHorizonState,
            incomingRenderState: incomingRenderState,
            incomingGraphState: incomingGraphState,
            previousGraph: previousGraph,
            pendingLiveMasterBinding: pendingLiveMasterBinding
        )
    }
}

package struct PreparedPerformancePhrase: Sendable {
    package let request: PhrasePreparationRequest
    package let prepared: PreparedAutonomousPhrase
    package let outgoingLongHorizonState: LongHorizonFutureAdaptationState?
    package let longHorizonDecision: LongHorizonTrajectoryDecision?
    package let waveforms: [[Float]]
    /// Flat ordered continuation ownership. Child entries contain no nested
    /// list; their exact DSP proof still retains the measured immediate child.
    package let retainedContinuations: [PreparedPerformancePhrase]
    package let preparationChainResourceBudget: AutonomousPreparationChainResourceBudget?

    package var requiresQualifiedContinuation: Bool {
        prepared.preparedValidation?.requiresQualifiedSuccessor == true
    }

    /// Bounded immutable ownership checks on the transport owner, never the
    /// render callback. Physical demand cannot fall back to a replacement or
    /// repeat; every link must retain the exact child measured by its proof.
    package var continuationOwnershipIsValid: Bool {
        let nodes = [self] + retainedContinuations
        for (index, node) in nodes.enumerated() {
            guard node.prepared.commitEligible else { return false }
            if node.prepared.preparedValidationRequired {
                guard node.request.replayIdentity.isComplete,
                    node.prepared.preparationReplayFingerprint == node.request.replayIdentity.fingerprint
                else { return false }
            }
            if index > 0 && !node.retainedContinuations.isEmpty { return false }
            if node.requiresQualifiedContinuation {
                guard index + 1 < nodes.count else { return false }
                let child = nodes[index + 1]
                let advanced = node.request.sourceState.advance(using: node.prepared.plan,
                    quality: node.prepared.qualityContinuationState,
                    liveMasterHeadroom: node.prepared.liveMasterHeadroomContinuationState,
                    longHorizonDecision: node.longHorizonDecision)
                guard node.prepared.preparedValidation?.qualifiedSuccessor === child.prepared,
                    child.request.sourceState == advanced,
                    child.request.incomingLongHorizonState?.fingerprint == node.outgoingLongHorizonState?.fingerprint,
                    child.prepared.preparationReplayFingerprint == child.request.replayIdentity.fingerprint,
                    child.request.key.sampleRate == node.request.key.sampleRate,
                    child.request.key.channelCount == node.request.key.channelCount,
                    child.request.key.routeGeneration == node.request.key.routeGeneration,
                    !child.request.key.routeRecovery,
                    child.request.key.qualityRecoveryContext == .neutral,
                    child.request.pendingLiveMasterBinding == nil,
                    child.request.key.pendingLiveMasterProposalFingerprint == nil,
                    child.request.key.liveTargetStartSample == nil
                else { return false }
            } else if index != nodes.count - 1 { return false }
        }
        return true
    }

    /// Nil means the naturally complete leaf may use ordinary preparation and
    /// coherent-repeat policy. Failure means stop/rebuild; it never authorizes
    /// repeating an incomplete source or substituting an independently rendered
    /// child. Remaining children keep flat ownership after each promotion.
    package func continuationAtBoundary(
        sessionState: AutonomousSessionState,
        longHorizonState: LongHorizonFutureAdaptationState?,
        sampleRate: Double, channelCount: Int, routeGeneration: Int,
        actualStartSample: Int64
    ) -> Result<Self?, PhrasePreparationFailure> {
        func refuse(_ code: String) -> Result<Self?, PhrasePreparationFailure> {
            .failure(.init(stage: "continuation-boundary", code: code))
        }
        guard continuationOwnershipIsValid else { return refuse("ownership-mismatch") }
        guard sampleRate == request.key.sampleRate, channelCount == request.key.channelCount,
            routeGeneration == request.key.routeGeneration, actualStartSample >= 0
        else { return refuse("route-mismatch") }
        guard requiresQualifiedContinuation else { return .success(nil) }
        guard let child = retainedContinuations.first,
            child.request.sourceState == sessionState,
            child.request.incomingLongHorizonState?.fingerprint == longHorizonState?.fingerprint
        else { return refuse("state-mismatch") }
        if let sourceStart = prepared.liveTargetStartSample {
            guard let frames = Int64(exactly: prepared.audioPreflight.quality.analyzedFrameCount), frames > 0
            else { return refuse("sample-boundary") }
            let end = sourceStart.addingReportingOverflow(frames)
            guard !end.overflow, end.partialValue == actualStartSample
            else { return refuse("sample-boundary") }
        }
        return .success(Self(request: child.request, prepared: child.prepared,
            outgoingLongHorizonState: child.outgoingLongHorizonState,
            longHorizonDecision: child.longHorizonDecision, waveforms: child.waveforms,
            retainedContinuations: Array(retainedContinuations.dropFirst()),
            preparationChainResourceBudget: preparationChainResourceBudget))
    }

    package init(
        request: PhrasePreparationRequest,
        prepared: PreparedAutonomousPhrase,
        outgoingLongHorizonState: LongHorizonFutureAdaptationState?,
        longHorizonDecision: LongHorizonTrajectoryDecision?,
        waveforms: [[Float]],
        retainedContinuations: [PreparedPerformancePhrase] = [],
        preparationChainResourceBudget: AutonomousPreparationChainResourceBudget? = nil
    ) {
        self.request = request
        self.prepared = prepared
        self.outgoingLongHorizonState = outgoingLongHorizonState
        self.longHorizonDecision = longHorizonDecision
        self.waveforms = waveforms
        self.retainedContinuations = retainedContinuations
        self.preparationChainResourceBudget = preparationChainResourceBudget
    }
}

/// A detached tentative successor request. Its source PCM stays private and
/// neither this seal nor its request authorizes scheduling or state advancement.
/// Only the canonical builder below can bind a preview to exact caller inputs.
package struct ProspectivePerformanceContinuation: Sendable {
    package let request: PhrasePreparationRequest
    package let sourceIdentityFingerprint: String
    /// Known only when the source has an app-owned live target boundary. Nil
    /// does not claim an absolute player position for an ordinary source.
    package let knownSuccessorStartSample: Int64?
    private let sourceRequestFingerprint: String
    private let incomingLongHorizonState: LongHorizonFutureAdaptationState?
    private let projection: LongHorizonProspectiveAdaptation?

    fileprivate init(request: PhrasePreparationRequest,
        source: AutonomousCandidatePreparedPreview, sourceRequest: PhrasePreparationRequest,
        knownSuccessorStartSample: Int64?,
        incomingLongHorizonState: LongHorizonFutureAdaptationState?,
        projection: LongHorizonProspectiveAdaptation?) {
        self.request = request
        sourceIdentityFingerprint = source.sourceIdentityFingerprint
        sourceRequestFingerprint = sourceRequest.replayIdentity.fingerprint
        self.knownSuccessorStartSample = knownSuccessorStartSample
        self.incomingLongHorizonState = incomingLongHorizonState
        self.projection = projection
    }

    /// Releases only request ownership after exact source admission. The
    /// successor still needs its own qualified product and transport handoff.
    package func admittedRequest(for prepared: PreparedAutonomousPhrase,
        sourceRequest: PhrasePreparationRequest,
        longHorizonPolicy: LongHorizonProfessionalPolicy?) -> PhrasePreparationRequest? {
        guard prepared.commitEligible,
            ProfessionalQualityModalSuccessorEvidence.identity(prepared) == sourceIdentityFingerprint,
            sourceRequest.replayIdentity.isComplete,
            sourceRequest.replayIdentity.matches(sourceRequest),
            sourceRequest.replayIdentity.fingerprint == sourceRequestFingerprint,
            request.replayIdentity.isComplete, request.replayIdentity.matches(request)
        else { return nil }
        if let projection {
            guard let incomingLongHorizonState, let longHorizonPolicy,
                let update = projection.admittedUpdate(for: prepared,
                    incomingState: sourceRequest.sourceState,
                    incomingAdaptation: incomingLongHorizonState, policy: longHorizonPolicy),
                update.state.fingerprint == request.incomingLongHorizonState?.fingerprint
            else { return nil }
        } else if incomingLongHorizonState != nil ||
                    sourceRequest.incomingLongHorizonState != nil || longHorizonPolicy != nil {
            return nil
        }
        return request
    }
}

/// Bounded, non-PCM reason metadata shared by every platform transport.
package struct PhrasePreparationFailure: Error, Equatable, Sendable {
    package let stage: String
    package let code: String
    package let details: [String]

    package init(stage: String, code: String, details: [String] = []) {
        self.stage = stage
        self.code = code
        var seen: Set<String> = []
        self.details = details.filter { seen.insert($0).inserted }
            .prefix(24)
            .map { $0 }
    }
}

package enum PerformancePreparationOutcome: Sendable {
    case prepared(PreparedPerformancePhrase)
    case failed(PhrasePreparationFailure)

    package var preparedPhrase: PreparedPerformancePhrase? {
        guard case let .prepared(prepared) = self else { return nil }
        return prepared
    }

    package var failure: PhrasePreparationFailure? {
        guard case let .failed(failure) = self else { return nil }
        return failure
    }
}

/// The single platform-neutral preparation path. It never executes on an audio
/// callback: it plans, renders immutable future audio, applies the installed
/// deterministic quality policy, and derives cheap read-only waveform
/// envelopes.
package enum AutonomousPerformancePreparer {
    /// Derives the only canonical future request from actual private source
    /// facts. The caller must bound successor work separately before rendering.
    package static func prospectiveContinuation(
        for preview: AutonomousCandidatePreparedPreview,
        request: PhrasePreparationRequest,
        director: AutonomousSessionDirector,
        longHorizonPolicy: LongHorizonProfessionalPolicy?,
        cancellationRequested: @Sendable () -> Bool
    ) -> Result<ProspectivePerformanceContinuation, PhrasePreparationFailure> {
        func fail(_ code: String) -> Result<ProspectivePerformanceContinuation, PhrasePreparationFailure> {
            .failure(PhrasePreparationFailure(stage: "successor-context", code: code))
        }
        guard !cancellationRequested() else { return fail("cancelled") }
        guard preview.hasProspectiveAcceptanceBinding,
            request.replayIdentity.isComplete, request.replayIdentity.matches(request),
            preview.preparationReplayFingerprint == request.replayIdentity.fingerprint,
            director.rootSeed == request.sourceState.rootSeed,
            request.incomingRenderState.liveMasterHeadroomState == request.sourceState.liveMasterHeadroom
        else { return fail("request-mismatch") }
        let expectedPlan = director.plan(from: request.sourceState,
            qualityRecoveryContext: request.key.routeRecovery ? .neutral : request.key.qualityRecoveryContext)
        let route = preview.selectedCandidateEvidence.routeContinuation
        let previousGraphFingerprint = request.previousGraph.map(AutonomousCandidateFingerprint.graph) ?? "none"
        guard preview.plan == expectedPlan,
            route.sampleRate == request.key.sampleRate,
            route.channelCount == request.key.channelCount,
            route.routeGeneration == request.key.routeGeneration,
            route.routeRecovery == request.key.routeRecovery,
            preview.liveTargetStartSample == request.key.liveTargetStartSample,
            preview.selectedCandidateEvidence.liveProposalFingerprint == request.key.pendingLiveMasterProposalFingerprint,
            let expectedInput = AutonomousCandidateContinuationFingerprint.make(
                renderState: request.incomingRenderState, generatedDSPState: request.incomingGraphState,
                qualityState: request.sourceState.quality,
                topologyRevision: request.sourceState.memory.topologyRevision,
                previousGraphFingerprint: previousGraphFingerprint,
                routeRecovery: request.key.routeRecovery,
                cancellationRequested: cancellationRequested),
            route.incomingContinuationFingerprint == expectedInput.combined
        else { return fail(cancellationRequested() ? "cancelled" : "source-mismatch") }
        guard !cancellationRequested() else { return fail("cancelled") }
        let incomingLongHorizon: LongHorizonFutureAdaptationState?
        let projection: LongHorizonProspectiveAdaptation?
        if let longHorizonPolicy {
            guard longHorizonPolicy.profile.primaryPolicyVersion == preview.transaction.policyVersion,
                let incoming = request.incomingLongHorizonState ?? LongHorizonFutureAdaptationState(
                    startingState: request.sourceState, policy: longHorizonPolicy),
                let projected = incoming.projecting(preview: preview,
                    incomingState: request.sourceState, policy: longHorizonPolicy)
            else { return fail("long-horizon-mismatch") }
            incomingLongHorizon = incoming; projection = projected
        } else {
            guard request.incomingLongHorizonState == nil else { return fail("long-horizon-unavailable") }
            incomingLongHorizon = nil; projection = nil
        }
        let knownStart: Int64?
        if let start = preview.liveTargetStartSample {
            let frames = preview.audioPreflight.quality.analyzedFrameCount
            guard frames > 0, let frameCount = Int64(exactly: frames) else { return fail("sample-boundary") }
            let end = start.addingReportingOverflow(frameCount)
            guard !end.overflow, end.partialValue > start else { return fail("sample-boundary") }
            knownStart = end.partialValue
        } else { knownStart = nil }
        let next = request.sourceState.advance(using: preview.plan,
            quality: preview.prospectiveQualityState, liveMasterHeadroom: preview.prospectiveLiveMasterState,
            longHorizonDecision: projection?.decision)
        let key = PhrasePreparationKey(sessionSeed: next.rootSeed, phraseIndex: next.phraseIndex,
            sampleRate: request.key.sampleRate, channelCount: request.key.channelCount,
            routeRecovery: false, qualityRevision: next.quality.revision,
            qualityPolicyVersion: next.quality.policyVersion,
            qualityControllerFingerprint: next.quality.observedControllerStateFingerprint ?? next.quality.acceptedControllerStateFingerprint,
            routeGeneration: request.key.routeGeneration,
            incomingLiveMasterRevision: next.liveMasterHeadroom.revision,
            incomingLiveMasterStateFingerprint: next.liveMasterHeadroom.fingerprint,
            pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil,
            liveTargetStartSample: nil)
        let successor = PhrasePreparationRequest(key: key, sourceState: next,
            incomingLongHorizonState: projection?.projectedState,
            incomingRenderState: preview.endingRenderState, incomingGraphState: preview.endingGraphState,
            previousGraph: preview.graph, pendingLiveMasterBinding: nil)
        guard successor.replayIdentity.isComplete, successor.replayIdentity.matches(successor),
            !cancellationRequested() else { return fail(cancellationRequested() ? "cancelled" : "successor-unavailable") }
        return .success(ProspectivePerformanceContinuation(request: successor, source: preview,
            sourceRequest: request, knownSuccessorStartSample: knownStart,
            incomingLongHorizonState: incomingLongHorizon, projection: projection))
    }

    package static func prepare(
        request: PhrasePreparationRequest,
        director: AutonomousSessionDirector,
        artifacts: ProfessionalQualityPrimaryArtifacts?,
        longHorizonArtifacts: LongHorizonProfessionalPolicyArtifacts?,
        diagnosticRoleStemCapture: Bool = false
    ) -> PreparedPerformancePhrase? {
        prepareDiagnosing(
            request: request,
            director: director,
            artifacts: artifacts,
            longHorizonArtifacts: longHorizonArtifacts,
            diagnosticRoleStemCapture: diagnosticRoleStemCapture
        ).preparedPhrase
    }

    package static func prepareDiagnosing(
        request: PhrasePreparationRequest,
        director: AutonomousSessionDirector,
        artifacts: ProfessionalQualityPrimaryArtifacts?,
        longHorizonArtifacts: LongHorizonProfessionalPolicyArtifacts?,
        diagnosticRoleStemCapture: Bool = false
    ) -> PerformancePreparationOutcome {
        prepareChainDiagnosing(request: request, director: director,
            longHorizonPolicy: longHorizonArtifacts?.policy,
            diagnosticRoleStemCapture: diagnosticRoleStemCapture,
            makeEvaluator: { request in
                ProfessionalQualityPreparationEvaluator(sampleRate: request.key.sampleRate,
                    artifacts: artifacts, preparationReplayFingerprint: request.replayIdentity.fingerprint)
            }, cancellationRequested: { Task.isCancelled })
    }

    private struct PendingFrame: Sendable {
        let request: PhrasePreparationRequest
        let pending: AutonomousPendingPreparedValidation
        let continuation: ProspectivePerformanceContinuation?
    }

    /// Single-writer synchronous reservation, confined to one render call.
    /// It is never used by callbacks or shared concurrently between tasks.
    private final class RenderReservation: @unchecked Sendable {
        let incoming: AutonomousPreparationChainResourceBudget
        let sampleRate: Double
        let bars: Int
        let capture: Bool
        private(set) var value: AutonomousPreparationChainResourceBudget
        private(set) var refused = false
        init(incoming: AutonomousPreparationChainResourceBudget, sampleRate: Double, bars: Int, capture: Bool) {
            self.incoming = incoming; self.sampleRate = sampleRate; self.bars = bars; self.capture = capture
            value = incoming
        }
        func claim(_ count: Int) -> Bool {
            guard let next = incoming.reserving(sampleRate: sampleRate, barCount: bars,
                renderPassCount: count, diagnosticRoleStemCapture: capture) else { refused = true; return false }
            value = next
            return true
        }
    }

    /// One iterative transaction used by the installed route evaluator and
    /// deterministic evaluator controls. No child bypasses its own validation.
    /// Neither pending source nor a partially reduced chain can escape.
    package static func prepareChainDiagnosing<E: AutonomousCandidateEvaluating>(
        request: PhrasePreparationRequest, director: AutonomousSessionDirector,
        longHorizonPolicy: LongHorizonProfessionalPolicy?,
        diagnosticRoleStemCapture: Bool = false,
        makeEvaluator: @Sendable (PhrasePreparationRequest) -> E,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> PerformancePreparationOutcome {
        func fail(_ code: String, _ details: [String] = []) -> PerformancePreparationOutcome {
            .failed(PhrasePreparationFailure(stage: "successor-chain", code: code, details: details))
        }
        var current = request
        var frames: [PendingFrame] = []
        var resource = AutonomousPreparationChainResourceBudget()
        while true {
            guard !cancellationRequested() else { return fail("cancelled") }
            let requestFailures = [
                current.replayIdentity.isComplete ? nil : "request-replay-identity",
                current.replayIdentity.matches(current) ? nil : "request-replay-mismatch",
                current.key.sessionSeed == current.sourceState.rootSeed ? nil : "request-source-root",
                director.rootSeed == current.sourceState.rootSeed ? nil : "director-source-root",
            ].compactMap { $0 }
            guard requestFailures.isEmpty else {
                return .failed(PhrasePreparationFailure(stage: "request-validation",
                    code: "identity-mismatch", details: requestFailures))
            }
            let plan = director.plan(from: current.sourceState,
                qualityRecoveryContext: current.key.routeRecovery ? .neutral : current.key.qualityRecoveryContext)
            let evaluator = makeEvaluator(current)
            let capture = frames.isEmpty && diagnosticRoleStemCapture
            let reservation = RenderReservation(incoming: resource, sampleRate: current.key.sampleRate,
                bars: plan.barCount, capture: capture)
            if evaluator.requiresPreparedValidation && !reservation.claim(1) {
                return fail("resource-bound", ["sources=\(resource.sourceCount)",
                    "reserved-bytes=\(resource.reservedPeakWorkingByteCount)", "next-bars=\(plan.barCount)"])
            }
            let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
                plan: plan, sessionSeed: current.sourceState.rootSeed, memory: current.sourceState.memory,
                sampleRate: current.key.sampleRate, incomingRenderState: current.incomingRenderState,
                incomingGraphState: current.incomingGraphState, previousGraph: current.previousGraph,
                incomingQualityState: current.sourceState.quality, routeRecovery: current.key.routeRecovery,
                routeChannelCount: current.key.channelCount, routeGeneration: current.key.routeGeneration,
                pendingLiveMasterBinding: current.pendingLiveMasterBinding,
                liveTargetStartSample: current.key.liveTargetStartSample,
                diagnosticRoleStemCapture: capture, evaluator: evaluator,
                deferPreparedValidation: true,
                renderPassReservation: { count in
                    !evaluator.requiresPreparedValidation || reservation.claim(count)
                }, cancellationRequested: cancellationRequested)
            guard !cancellationRequested() else { return fail("cancelled") }
            guard !reservation.refused else { return fail("resource-bound") }
            resource = reservation.value
            guard case let .awaitingPreparedValidation(pending) = outcome else {
                if let failure = outcome.failure {
                    return .failed(PhrasePreparationFailure(stage: failure.stage.rawValue,
                        code: failure.code.rawValue, details: failure.details))
                }
                guard let prepared = outcome.preparedPhrase, frames.isEmpty else {
                    return fail("successor-unavailable")
                }
                return packagePerformance(request: current, prepared: prepared,
                    longHorizonPolicy: longHorizonPolicy, cancellationRequested: cancellationRequested)
            }
            guard pending.preview.preparationReplayFingerprint == current.replayIdentity.fingerprint,
                pending.preview.hasProspectiveAcceptanceBinding else { return fail("source-mismatch") }
            let needsChild: Bool
            do { needsChild = try pending.preview.requiresQualifiedSuccessorSupport() }
            catch { return fail("physical-support-unavailable") }
            guard let numericStorage = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
                renderState: pending.preview.endingRenderState,
                generatedDSPState: pending.preview.endingGraphState,
                cancellationRequested: cancellationRequested),
                let retained = resource.retainingCompletedSource(sampleRate: current.key.sampleRate,
                    barCount: plan.barCount, requiresQualifiedSuccessor: needsChild,
                    diagnosticRoleStemCapture: capture,
                    retainedContinuationNumericByteCount: numericStorage)
            else { return fail(cancellationRequested() ? "cancelled" : "resource-retention-mismatch") }
            resource = retained
            if needsChild {
                let continuation: ProspectivePerformanceContinuation
                switch prospectiveContinuation(for: pending.preview, request: current,
                    director: director, longHorizonPolicy: longHorizonPolicy,
                    cancellationRequested: cancellationRequested) {
                case let .success(value): continuation = value
                case let .failure(failure): return .failed(failure)
                }
                frames.append(PendingFrame(request: current, pending: pending, continuation: continuation))
                current = continuation.request
            } else {
                frames.append(PendingFrame(request: current, pending: pending, continuation: nil))
                break
            }
        }
        var successor: PreparedAutonomousPhrase?
        var reduced: [PreparedPerformancePhrase] = []
        reduced.reserveCapacity(frames.count)
        for frame in frames.reversed() {
            guard !cancellationRequested() else { return fail("cancelled") }
            let proof = makeEvaluator(frame.request).preparedValidation(for: frame.pending.preview,
                successor: successor)
            let outcome = frame.pending.resolving(proof, cancellationRequested: cancellationRequested)
            guard !cancellationRequested() else { return fail("cancelled") }
            if let failure = outcome.failure {
                return .failed(PhrasePreparationFailure(stage: failure.stage.rawValue,
                    code: failure.code.rawValue, details: failure.details))
            }
            guard let prepared = outcome.preparedPhrase else { return fail("validation-unavailable") }
            guard prepared.commitEligible else {
                // Preserve the ordinary root rejection for existing recovery,
                // including a source measured with a child. A rejected child
                // cannot produce any root or retained transport continuation.
                if frame.request.replayIdentity.fingerprint == request.replayIdentity.fingerprint {
                    return packagePerformance(request: frame.request, prepared: prepared,
                        longHorizonPolicy: longHorizonPolicy, cancellationRequested: cancellationRequested)
                }
                return fail("successor-rejected", ["phrase=\(frame.request.key.phraseIndex)"] +
                    prepared.qualityDiagnosticDetails)
            }
            if let continuation = frame.continuation {
                guard let childRequest = continuation.admittedRequest(for: prepared,
                    sourceRequest: frame.request, longHorizonPolicy: longHorizonPolicy),
                    let child = reduced.last,
                    childRequest.replayIdentity.fingerprint == child.request.replayIdentity.fingerprint,
                    prepared.preparedValidation?.qualifiedSuccessor === child.prepared
                else { return fail("continuation-mismatch") }
            }
            let packed = packagePerformance(request: frame.request, prepared: prepared,
                longHorizonPolicy: longHorizonPolicy, cancellationRequested: cancellationRequested)
            guard let node = packed.preparedPhrase else { return packed }
            reduced.append(node)
            successor = prepared
        }
        guard let root = reduced.popLast(), !cancellationRequested() else { return fail("cancelled") }
        return .prepared(PreparedPerformancePhrase(request: root.request, prepared: root.prepared,
            outgoingLongHorizonState: root.outgoingLongHorizonState,
            longHorizonDecision: root.longHorizonDecision, waveforms: root.waveforms,
            retainedContinuations: Array(reduced.reversed()), preparationChainResourceBudget: resource))
    }

    private static func packagePerformance(
        request: PhrasePreparationRequest, prepared: PreparedAutonomousPhrase,
        longHorizonPolicy: LongHorizonProfessionalPolicy?,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> PerformancePreparationOutcome {
        let incomingLongHorizon = request.incomingLongHorizonState ?? longHorizonPolicy.flatMap {
            LongHorizonFutureAdaptationState(startingState: request.sourceState, policy: $0)
        }
        let longHorizonUpdate: LongHorizonFutureAdaptationUpdate?
        if let incomingLongHorizon, let longHorizonPolicy {
            longHorizonUpdate = incomingLongHorizon.observing(prepared: prepared,
                incomingState: request.sourceState, policy: longHorizonPolicy)
            guard !prepared.commitEligible || longHorizonUpdate != nil else {
                return .failed(PhrasePreparationFailure(stage: "successor-chain", code: "long-horizon-unavailable"))
            }
        } else {
            guard request.incomingLongHorizonState == nil || !prepared.commitEligible else {
                return .failed(PhrasePreparationFailure(stage: "successor-chain", code: "long-horizon-unavailable"))
            }
            longHorizonUpdate = nil
        }
        var waveforms: [[Float]] = []
        waveforms.reserveCapacity(prepared.blocks.count)
        for block in prepared.blocks {
            guard !cancellationRequested() else {
                return .failed(PhrasePreparationFailure(stage: "presentation", code: "cancelled"))
            }
            waveforms.append(WaveformEnvelope.fixedDB(left: block.left, right: block.right))
        }
        guard !cancellationRequested() else {
            return .failed(PhrasePreparationFailure(stage: "presentation", code: "cancelled"))
        }
        return .prepared(PreparedPerformancePhrase(request: request, prepared: prepared,
            outgoingLongHorizonState: longHorizonUpdate?.state,
            longHorizonDecision: longHorizonUpdate?.decision, waveforms: waveforms))
    }
}
