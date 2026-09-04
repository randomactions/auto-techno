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

    package init(
        request: PhrasePreparationRequest,
        prepared: PreparedAutonomousPhrase,
        outgoingLongHorizonState: LongHorizonFutureAdaptationState?,
        longHorizonDecision: LongHorizonTrajectoryDecision?,
        waveforms: [[Float]]
    ) {
        self.request = request
        self.prepared = prepared
        self.outgoingLongHorizonState = outgoingLongHorizonState
        self.longHorizonDecision = longHorizonDecision
        self.waveforms = waveforms
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
        let requestFailures = [
            request.replayIdentity.isComplete
                ? nil : "request-replay-identity",
            request.replayIdentity.matches(request)
                ? nil : "request-replay-mismatch",
            request.key.sessionSeed == request.sourceState.rootSeed
                ? nil : "request-source-root",
            director.rootSeed == request.sourceState.rootSeed
                ? nil : "director-source-root",
        ].compactMap { $0 }
        guard requestFailures.isEmpty else {
            return .failed(PhrasePreparationFailure(
                stage: "request-validation",
                code: "identity-mismatch",
                details: requestFailures
            ))
        }
        let plan = director.plan(
            from: request.sourceState,
            qualityRecoveryContext: request.key.routeRecovery
                ? .neutral : request.key.qualityRecoveryContext
        )
        let evaluator = ProfessionalQualityPreparationEvaluator(
            sampleRate: request.key.sampleRate,
            artifacts: artifacts
        )
        let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
            plan: plan,
            sessionSeed: request.sourceState.rootSeed,
            memory: request.sourceState.memory,
            sampleRate: request.key.sampleRate,
            incomingRenderState: request.incomingRenderState,
            incomingGraphState: request.incomingGraphState,
            previousGraph: request.previousGraph,
            incomingQualityState: request.sourceState.quality,
            routeRecovery: request.key.routeRecovery,
            routeChannelCount: request.key.channelCount,
            routeGeneration: request.key.routeGeneration,
            pendingLiveMasterBinding: request.pendingLiveMasterBinding,
            liveTargetStartSample: request.key.liveTargetStartSample,
            diagnosticRoleStemCapture: diagnosticRoleStemCapture,
            evaluator: evaluator,
            cancellationRequested: { Task.isCancelled }
        )
        guard case let .prepared(prepared) = outcome else {
            let failure = outcome.failure.map {
                PhrasePreparationFailure(
                    stage: $0.stage.rawValue,
                    code: $0.code.rawValue,
                    details: $0.details
                )
            } ?? PhrasePreparationFailure(
                stage: "transaction",
                code: "unknown-failure"
            )
            return .failed(failure)
        }
        guard !Task.isCancelled else {
            return .failed(PhrasePreparationFailure(
                stage: "transaction",
                code: "cancelled"
            ))
        }

        let incomingLongHorizon = request.incomingLongHorizonState ??
            longHorizonArtifacts.flatMap {
                LongHorizonFutureAdaptationState(
                    startingState: request.sourceState,
                    policy: $0.policy
                )
            }
        let longHorizonUpdate: LongHorizonFutureAdaptationUpdate? =
          if let incomingLongHorizon, let longHorizonArtifacts {
            incomingLongHorizon.observing(
                prepared: prepared,
                incomingState: request.sourceState,
                policy: longHorizonArtifacts.policy
            )
        } else {
            nil
        }

        var waveforms: [[Float]] = []
        waveforms.reserveCapacity(prepared.blocks.count)
        for block in prepared.blocks {
            guard !Task.isCancelled else {
                return .failed(PhrasePreparationFailure(
                    stage: "presentation",
                    code: "cancelled"
                ))
            }
            waveforms.append(WaveformEnvelope.fixedDB(
                left: block.left,
                right: block.right
            ))
        }
        guard !Task.isCancelled else {
            return .failed(PhrasePreparationFailure(
                stage: "presentation",
                code: "cancelled"
            ))
        }
        return .prepared(PreparedPerformancePhrase(
            request: request,
            prepared: prepared,
            outgoingLongHorizonState: longHorizonUpdate?.state,
            longHorizonDecision: longHorizonUpdate?.decision,
            waveforms: waveforms
        ))
    }
}
