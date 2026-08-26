import AutoTechnoCore
import AutoTechnoDSP

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
        qualityRetryOrdinal: Int = 0
    ) {
        self.sessionSeed = sessionSeed
        self.phraseIndex = phraseIndex
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.routeRecovery = routeRecovery
        self.qualityRetryOrdinal = min(
            AutonomousSessionDirector.maximumQualityRetryOrdinal,
            max(0, qualityRetryOrdinal)
        )
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

package struct PhrasePreparationRequest: Sendable {
    package let key: PhrasePreparationKey
    package let sourceState: AutonomousSessionState
    package let incomingLongHorizonState: LongHorizonFutureAdaptationState?
    package let incomingRenderState: RenderState
    package let incomingGraphState: GeneratedDSPContinuationState
    package let previousGraph: DSPGraphPlan?
    package let pendingLiveMasterBinding: PendingLiveMasterHeadroomBinding?

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
        longHorizonArtifacts: LongHorizonProfessionalPolicyArtifacts?
    ) -> PreparedPerformancePhrase? {
        prepareDiagnosing(
            request: request,
            director: director,
            artifacts: artifacts,
            longHorizonArtifacts: longHorizonArtifacts
        ).preparedPhrase
    }

    package static func prepareDiagnosing(
        request: PhrasePreparationRequest,
        director: AutonomousSessionDirector,
        artifacts: ProfessionalQualityPrimaryArtifacts?,
        longHorizonArtifacts: LongHorizonProfessionalPolicyArtifacts?
    ) -> PerformancePreparationOutcome {
        let requestFailures = [
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
            qualityRetryOrdinal: request.key.routeRecovery
                ? 0 : request.key.qualityRetryOrdinal
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
