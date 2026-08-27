import AVFoundation
import AutoTechnoCore
import AutoTechnoDSP
import AutoTechnoTransport
import Combine
import Foundation
import OSLog

private struct PreparedPhrase: Sendable {
    let request: PhrasePreparationRequest
    let prepared: PreparedAutonomousPhrase
    let outgoingLongHorizonState: LongHorizonFutureAdaptationState?
    let longHorizonDecision: LongHorizonTrajectoryDecision?
    let waveforms: [[Float]]
    let inspectorSnapshots: [LiveRenderSnapshot]
}

private struct PhrasePreparationResult: Sendable {
    let prepared: PreparedPhrase?
    let failure: NextPhraseFailure?

    static func success(_ prepared: PreparedPhrase) -> Self {
        Self(prepared: prepared, failure: nil)
    }

    static func failed(_ failure: NextPhraseFailure) -> Self {
        Self(prepared: nil, failure: failure)
    }
}

private struct ScheduledVisual {
    let startSample: AVAudioFramePosition
    let frameLength: AVAudioFramePosition
    let scenePosition: Int
    let bar: Int
    let section: SectionKind
    let waveform: [Float]
    let inspectorSnapshot: LiveRenderSnapshot
}

/// Preparation remains entirely outside the audio callback. It produces the
/// immutable inspector projection consumed by the macOS presentation layer;
/// planning, rendering, quality evaluation, and waveform preparation remain in
/// the shared platform-neutral transport owner.
private enum AppPerformancePreparer {
    static func prepare(request: PhrasePreparationRequest,
                        director: AutonomousSessionDirector,
                        artifacts: ProfessionalQualityPrimaryArtifacts?,
                        longHorizonArtifacts:
                            LongHorizonProfessionalPolicyArtifacts?)
        -> PhrasePreparationResult {
        let outcome = AutonomousPerformancePreparer.prepareDiagnosing(
            request: request,
            director: director,
            artifacts: artifacts,
            longHorizonArtifacts: longHorizonArtifacts
        )
        guard let shared = outcome.preparedPhrase else {
            let failure = outcome.failure ?? PhrasePreparationFailure(
                stage: "transaction",
                code: "unknown-failure"
            )
            return .failed(NextPhraseFailure(
                stage: failure.stage,
                code: failure.code,
                details: failure.details
            ))
        }
        let inspectorSnapshots = LiveRenderSnapshot.make(
            prepared: shared.prepared,
            sampleRate: request.key.sampleRate,
            channelCount: request.key.channelCount
        )
        guard inspectorSnapshots.count == shared.prepared.blocks.count else {
            return .failed(NextPhraseFailure(
                stage: "presentation",
                code: "snapshot-count",
                details: [
                    "blocks=\(shared.prepared.blocks.count)",
                    "snapshots=\(inspectorSnapshots.count)",
                ]
            ))
        }
        guard !Task.isCancelled else {
            return .failed(NextPhraseFailure(
                stage: "presentation",
                code: "cancelled"
            ))
        }
        return .success(PreparedPhrase(
            request: request,
            prepared: shared.prepared,
            outgoingLongHorizonState: shared.outgoingLongHorizonState,
            longHorizonDecision: shared.longHorizonDecision,
            waveforms: shared.waveforms,
            inspectorSnapshots: inspectorSnapshots
        ))
    }
}

@MainActor
package final class TechnoEngine: ObservableObject {
    enum PlaybackState: Equatable {
        case preparing
        case ready
        case playing
        case paused
        case recovering
        case unavailable
    }

    static let bpm = AutonomousSessionDirector.bpm
    private static let successorPreparationLogger = Logger(
        subsystem: "com.randomactions.AutoTechnoInspector",
        category: "successor-preparation"
    )

    @Published private(set) var playbackState: PlaybackState = .preparing
    @Published private(set) var waveform: [Float] = Array(repeating: 0.04, count: 64)
    @Published private(set) var playhead = 0.0
    @Published private(set) var playingTimeSeconds = 0
    @Published private(set) var sceneNumber = 1
    @Published private(set) var barWithinScene = 1
    @Published private(set) var currentSection: SectionKind = .groove
    @Published private(set) var liveRenderSnapshot: LiveRenderSnapshot = .waiting
    @Published private(set) var nextPhraseProgress: NextPhraseProgress = .waiting

    var isPlaying: Bool { playbackState == .playing }
    var transportEnabled: Bool {
        playbackState != .preparing && playbackState != .recovering
    }
    var newSetEnabled: Bool {
        !isShutDown && playbackState != .preparing
    }
    var transportTitle: String {
        switch playbackState {
        case .playing: "PAUSE"
        case .preparing: "PREPARING"
        case .recovering: "RECOVERING"
        case .unavailable: "RETRY"
        case .ready, .paused: "PLAY"
        }
    }
    var statusTitle: String {
        switch playbackState {
        case .preparing: "BUILDING THE PERFORMANCE"
        case .ready: "READY"
        case .playing: "LIVE"
        case .paused: "PAUSED"
        case .recovering: "RECOVERING AUDIO"
        case .unavailable: "AUDIO UNAVAILABLE"
        }
    }
    var positionText: String {
        "\(Int(Self.bpm)) BPM · PHRASE \(sceneNumber) · BAR \(barWithinScene)"
    }
    var playingTimeText: String {
        PlayingTimeFormatter.string(forWholeSeconds: playingTimeSeconds)
    }

    private let sessionSeedSource: AutonomousSessionSeedSource
    private var director: AutonomousSessionDirector
    private var sessionState: AutonomousSessionState
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var configurationObserver: NSObjectProtocol?
    private var recoveryTask: Task<Void, Never>?
    private var displayTimer: Timer?
    private var playingTimeClock = PlayingTimeClock()

    private var currentPhrase: PreparedPhrase?
    private let liveFeedbackPreparation = LiveFeedbackPreparationOwner<
        PhrasePreparationKey,
        PreparedPhrase,
        PhrasePreparationRequest
    >()
    private var preparationTask: Task<PhrasePreparationResult, Never>?
    private var preparationTaskSerial: UInt64 = 0
    private var activePreparationTaskSerial: UInt64?
    private var preparingKey: PhrasePreparationKey?
    private var activePreparationRequest: PhrasePreparationRequest?
    private var queuedPreparationRequest: PhrasePreparationRequest?
    private var preparationEpoch = AutonomousPreparationEpoch()
    private var qualityRetryContinuation =
        AutonomousQualityRetryContinuation()
    private var requestedPlaybackAfterPreparation = false
    /// Survives repeated configuration notifications while the prior detached
    /// task is cancelling, so the interrupted phrase remains the recovery
    /// source instead of being replaced by a stale successor request.
    private var routeRecoveryRequest: PhrasePreparationRequest?
    /// Loaded once outside detached preparation and never touched by the audio
    /// callback. A failed load leaves professional qualification unavailable.
    private let qualityArtifacts: ProfessionalQualityPrimaryArtifacts?
    /// Immutable Stage 6 policy identity. Mutable accumulation remains in
    /// detached preparation and is committed only with its exact phrase.
    private let longHorizonArtifacts: LongHorizonProfessionalPolicyArtifacts?
    private var longHorizonState: LongHorizonFutureAdaptationState?

    private var nextBlockIndex = 0
    private var nextScheduleSample: AVAudioFramePosition = 0
    private var currentBarFrames: AVAudioFramePosition = 1
    private var scheduledVisuals: [ScheduledVisual] = []
    private var activeVisualStart: AVAudioFramePosition = -1
    private var livePCMTransport: LivePCMTransport?
    private var liveFeedbackCoordinator: LiveFeedbackCoordinator?
    private var liveScheduledPhrases: [ScheduledPhraseRange: PreparedPhrase] = [:]
    private let liveFeedbackOrchestrator: LiveFeedbackEngineOrchestrator
    private let liveFeedbackCaptureLifecycle: LiveFeedbackCaptureLifecycle
    private var liveFeedbackRuntime: LiveFeedbackRuntimeCoordinator {
        liveFeedbackOrchestrator.runtime
    }
    private var liveScheduledLedger: ScheduledPhraseLedger {
        liveFeedbackOrchestrator.ledger
    }
    private var liveClockMap: MixerPlayerClockMap? {
        liveFeedbackOrchestrator.clockMap
    }
    private var pendingLiveMasterBinding: PendingLiveMasterHeadroomBinding?
    private var isShutDown = false
    private var lifecycleGeneration: UInt64 = 0

    package var currentSessionSeed: UInt64 { sessionState.rootSeed }

    package init(
        sessionSeedSource: AutonomousSessionSeedSource? = nil,
        liveFeedbackOrchestrator: LiveFeedbackEngineOrchestrator? = nil,
        liveFeedbackCaptureLifecycle: LiveFeedbackCaptureLifecycle? = nil
    ) {
        let sessionSeedSource = sessionSeedSource ??
            AutonomousSessionSeedSource()
        let director = AutonomousSessionDirector(
            rootSeed: sessionSeedSource.nextSeed()
        )
        qualityArtifacts = try? ProfessionalQualityPrimaryArtifacts.load()
        longHorizonArtifacts = try? LongHorizonProfessionalPolicyArtifacts.load()
        self.sessionSeedSource = sessionSeedSource
        self.director = director
        sessionState = director.initialState()
        self.liveFeedbackOrchestrator = liveFeedbackOrchestrator ??
            LiveFeedbackEngineOrchestrator(routeGeneration: 0)
        self.liveFeedbackCaptureLifecycle =
            liveFeedbackCaptureLifecycle ?? LiveFeedbackCaptureLifecycle()
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: nil)
        installConfigurationObserverIfNeeded()
    }

    private func installConfigurationObserverIfNeeded() {
        guard configurationObserver == nil else { return }
        let observerGeneration = lifecycleGeneration
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.lifecycleGeneration == observerGeneration else { return }
                self.handleAudioConfigurationChange()
            }
        }
    }

    func prepare() {
        if isShutDown {
            isShutDown = false
            installConfigurationObserverIfNeeded()
        }
        if routeRecoveryRequest != nil {
            handleAudioConfigurationChange()
            return
        }
        guard currentPhrase == nil else {
            if playbackState == .preparing { playbackState = .ready }
            return
        }
        audioEngine.prepare()
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        guard format.sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate,
              format.sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate,
              Int(format.channelCount) ==
                QualityQualificationContract.requiredRouteChannelCount else {
            playbackState = .unavailable
            return
        }
        ensureLivePCMTransport(format: format)
        playbackState = .preparing
        requestPreparation(PhrasePreparationRequest(
            key: PhrasePreparationKey(
                sessionSeed: sessionState.rootSeed,
                phraseIndex: sessionState.phraseIndex,
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount),
                routeRecovery: false,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value,
                incomingLiveMasterRevision:
                    sessionState.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint:
                    sessionState.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint: nil,
                liveEarliestEligibleFutureSample: nil,
                liveTargetStartSample: nil,
                qualityRetryOrdinal: qualityRetryOrdinal(
                    for: sessionState.phraseIndex
                )
            ),
            sourceState: sessionState,
            incomingLongHorizonState: longHorizonState,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            pendingLiveMasterBinding: nil
        ))
    }

    func togglePlayback() {
        guard !isShutDown else { return }
        switch playbackState {
        case .playing:
            pause()
        case .paused:
            resume()
        case .ready:
            startFreshPlayback()
        case .unavailable:
            if currentPhrase == nil {
                prepare()
            } else {
                startFreshPlayback()
            }
        case .preparing, .recovering:
            break
        }
    }

    /// Ends the complete performance identity, clears every accepted and
    /// in-flight continuation, and automatically starts the newly prepared
    /// performance. Teardown and planning remain on the main/detached paths;
    /// no work is added to the realtime callback.
    package func startNewSet() {
        guard !isShutDown else { return }
        shutdown()
        requestedPlaybackAfterPreparation = true
        prepare()
    }

    package func shutdown() {
        guard !isShutDown else { return }
        isShutDown = true
        lifecycleGeneration &+= 1
        requestedPlaybackAfterPreparation = false
        routeRecoveryRequest = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        preparationTask?.cancel()
        preparationTask = nil
        activePreparationTaskSerial = nil
        preparationEpoch.invalidate()
        preparingKey = nil
        queuedPreparationRequest = nil
        activePreparationRequest = nil
        liveFeedbackPreparation.resetSession()
        currentPhrase = nil
        longHorizonState = nil
        // View disappearance is a complete transport boundary. A later
        // appearance restarts one coherent session instead of pairing an
        // advanced musical memory with reset render/DSP continuation.
        let nextSeed = sessionSeedSource.nextSeed(excluding: director.rootSeed)
        director = AutonomousSessionDirector(rootSeed: nextSeed)
        sessionState = director.initialState()
        resetSchedule()
        resetPlayingTime()
        waveform = Array(repeating: 0.04, count: 64)
        liveRenderSnapshot = .waiting
        nextPhraseProgress = .waiting
        qualityRetryContinuation = AutonomousQualityRetryContinuation()
        sceneNumber = 1
        currentSection = .groove
        playbackState = .unavailable
        displayTimer?.invalidate()
        displayTimer = nil
        liveFeedbackOrchestrator.shutdown {
            self.quiesceAndStopLiveFeedbackCapture(
                mode: .stop
            )
        }
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
    }

    private func requestPreparation(_ request: PhrasePreparationRequest) {
        guard !isShutDown else { return }
        guard request.key.sessionSeed == request.sourceState.rootSeed,
              request.key.sessionSeed == sessionState.rootSeed else { return }
        if let prepared = liveFeedbackPreparation.removeCachedValue(
            forKey: request.key
        ) {
            if let failure = acceptPreparedPhrase(prepared) {
                markNextPhraseRejected(
                    for: request,
                    failure: failure,
                    qualityDecision: prepared.prepared.qualityDecision
                )
            }
            return
        }
        if preparingKey == request.key { return }
        guard preparationTask == nil else {
            queuedPreparationRequest = request
            markNextPhraseQueued(for: request)
            return
        }

        markNextPhrasePreparing(for: request)
        preparingKey = request.key
        activePreparationRequest = request
        let generation = preparationEpoch.value
        preparationTaskSerial &+= 1
        let taskSerial = preparationTaskSerial
        activePreparationTaskSerial = taskSerial
        let director = director
        let qualityArtifacts = qualityArtifacts
        let longHorizonArtifacts = longHorizonArtifacts
        let task = Task.detached(priority: .userInitiated) {
            AppPerformancePreparer.prepare(
                request: request,
                director: director,
                artifacts: qualityArtifacts,
                longHorizonArtifacts: longHorizonArtifacts
            )
        }
        preparationTask = task
        Task { @MainActor [weak self] in
            let result = await task.value
            guard let self else { return }
            guard self.activePreparationTaskSerial == taskSerial else { return }
            self.preparationTask = nil
            self.activePreparationTaskSerial = nil
            self.preparingKey = nil
            self.activePreparationRequest = nil
            if self.preparationEpoch.accepts(generation) {
                if let prepared = result.prepared {
                    if let failure = self.acceptPreparedPhrase(prepared) {
                        self.markNextPhraseRejected(
                            for: request,
                            failure: failure,
                            qualityDecision:
                                prepared.prepared.qualityDecision
                        )
                    }
                } else if self.queuedPreparationRequest == nil,
                          self.currentPhrase == nil {
                    self.playbackState = .unavailable
                    if let failure = result.failure {
                        self.markInitialPreparationRejected(
                            for: request,
                            failure: failure
                        )
                    }
                } else if let failure = result.failure {
                    self.markNextPhraseRejected(
                        for: request,
                        failure: failure
                    )
                }
            }
            if let queued = self.queuedPreparationRequest {
                self.queuedPreparationRequest = nil
                self.requestPreparation(queued)
            }
        }
    }

    /// Returns a bounded diagnostic only when the immutable candidate cannot
    /// cross the main-actor commit boundary.
    private func acceptPreparedPhrase(
        _ phrase: PreparedPhrase
    ) -> NextPhraseFailure? {
        guard !isShutDown else {
            return NextPhraseFailure(
                stage: "commit",
                code: "engine-shutdown"
            )
        }
        let identityFailures = [
            phrase.request.key.phraseIndex ==
                phrase.request.sourceState.phraseIndex
                ? nil : "request-phrase-index",
            phrase.request.key.sessionSeed ==
                phrase.request.sourceState.rootSeed
                ? nil : "request-source-root",
            phrase.request.key.sessionSeed == sessionState.rootSeed
                ? nil : "session-root",
            phrase.prepared.graph.sessionSeed ==
                phrase.request.key.sessionSeed
                ? nil : "graph-root",
            phrase.request.incomingLongHorizonState?.fingerprint ==
                longHorizonState?.fingerprint
                ? nil : "long-horizon-state",
        ].compactMap { $0 }
        guard identityFailures.isEmpty else {
            return NextPhraseFailure(
                stage: "commit",
                code: "identity-mismatch",
                details: identityFailures
            )
        }
        let liveMasterMatches =
            phrase.prepared.incomingLiveMasterHeadroomState ==
                phrase.request.sourceState.liveMasterHeadroom
        guard phrase.prepared.commitEligible, liveMasterMatches else {
            if let rejectedProposal = phrase.request
                .pendingLiveMasterBinding?.proposal.fingerprint,
               pendingLiveMasterBinding?.proposal.fingerprint ==
                rejectedProposal {
                let sourcePhraseIndex = phrase.request
                    .pendingLiveMasterBinding?.proposal.sourcePhraseIndex ?? -1
                if let sourceOccurrence = liveScheduledLedger.playing,
                   sourceOccurrence.phraseIndex == sourcePhraseIndex {
                    liveFeedbackOrchestrator.rejectCorrectedSuccessor(
                        sourceOccurrence: sourceOccurrence,
                        targetPhraseIndex: phrase.request.key.phraseIndex,
                        proposalFingerprint: rejectedProposal,
                        expireCorrectedSuccessor: {
                            self.expirePendingLiveFeedbackAtBoundary()
                        }
                    )
                }
            }
            if currentPhrase == nil { playbackState = .unavailable }
            var details = phrase.prepared.qualityDecision.reasonCodes.map {
                "quality=\($0.rawValue)"
            }
            details.append(contentsOf: phrase.prepared.qualityDiagnosticDetails)
            details.append(contentsOf: phrase.prepared.commitFailureDiagnostics)
            if !liveMasterMatches {
                details.append("live-master-state")
            }
            let code = switch phrase.prepared.qualityDecision.outcome {
            case .rejected: "quality-rejected"
            case .qualificationUnavailable: "quality-unavailable"
            case .qualified, .adjusted: "commit-provenance"
            }
            return NextPhraseFailure(
                stage: "commit",
                code: code,
                details: details
            )
        }
        guard currentPhrase == nil else {
            if phrase.request.sourceState.phraseIndex == sessionState.phraseIndex {
                liveFeedbackPreparation.insertCachedValue(
                    phrase,
                    forKey: phrase.request.key
                )
                if phrase.request.pendingLiveMasterBinding == nil,
                   let source = currentPhrase {
                    _ = liveFeedbackPreparation.rememberTargetReference(
                        sourcePlan: source.prepared.plan,
                        targetPlan: phrase.prepared.plan,
                        routeGeneration: phrase.request.key.routeGeneration,
                        sampleRate: phrase.request.key.sampleRate,
                        occurrenceEpoch:
                            liveFeedbackRuntime.occurrenceEpoch,
                        basePayload: phrase.request
                    )
                }
                trimPreparedCache()
                refreshLiveFeedbackContexts()
                markNextPhraseReady(for: phrase.request)
                return nil
            }
            return NextPhraseFailure(
                stage: "commit",
                code: "stale-source-state"
            )
        }
        guard phrase.request.sourceState.phraseIndex == sessionState.phraseIndex else {
            return NextPhraseFailure(
                stage: "commit",
                code: "stale-source-state"
            )
        }

        let advancedState = phrase.request.sourceState.advance(
            using: phrase.prepared.plan,
            quality: phrase.prepared.qualityContinuationState,
            liveMasterHeadroom:
                phrase.prepared.liveMasterHeadroomContinuationState,
            longHorizonDecision: phrase.longHorizonDecision
        )
        guard phrase.longHorizonDecision.map({
            advancedState.memory.longHorizon.lastTrajectoryDecision == $0
        }) ?? true else {
            return NextPhraseFailure(
                stage: "commit",
                code: "long-horizon-commit"
            )
        }
        let recoveredInitial = currentPhrase == nil &&
            nextPhraseProgress.isInitialTarget
            ? nextPhraseProgress.lastFailure.map {
                (
                    failure: $0,
                    attemptCount: nextPhraseProgress.attemptCount
                )
            } : nil
        currentPhrase = phrase
        let resumesRecoveredPlayback = phrase.request.key.routeRecovery
        if resumesRecoveredPlayback {
            routeRecoveryRequest = nil
        }
        sessionState = advancedState
        longHorizonState = phrase.outgoingLongHorizonState
        qualityRetryContinuation = AutonomousQualityRetryContinuation()
        if let recoveredInitial {
            Self.successorPreparationLogger.notice(
                "Initial recovered phrase=\(phrase.prepared.plan.phraseIndex + 1, privacy: .public) attempt=\(recoveredInitial.attemptCount, privacy: .public) retry-variant=\(phrase.request.key.qualityRetryOrdinal, privacy: .public) previous-stage=\(recoveredInitial.failure.stage, privacy: .public) previous-code=\(recoveredInitial.failure.code, privacy: .public)"
            )
        }
        liveFeedbackRuntime.retainRecentSources(
            currentPhraseIndex: sessionState.phraseIndex
        )
        nextBlockIndex = 0
        if let firstWaveform = phrase.waveforms.first {
            waveform = firstWaveform
        }
        if let firstInspectorSnapshot = phrase.inspectorSnapshots.first {
            liveRenderSnapshot = firstInspectorSnapshot
        }
        currentSection = phrase.prepared.blocks.first?.section ?? .groove
        playbackState = .ready
        requestSuccessor(after: phrase)
        if requestedPlaybackAfterPreparation {
            requestedPlaybackAfterPreparation = false
            startFreshPlayback(
                resetPlayingTime: !resumesRecoveredPlayback
            )
        }
        return nil
    }

    private func requestSuccessor(
        after phrase: PreparedPhrase,
        pendingBinding: PendingLiveMasterHeadroomBinding? = nil
    ) {
        let request = makeSuccessorRequest(
            after: phrase,
            pendingBinding: pendingBinding
        )
        if pendingBinding == nil,
           !liveFeedbackOrchestrator.allowsUntrimmedPreparation(
                sourcePhraseIndex: phrase.prepared.plan.phraseIndex,
                targetPhraseIndex: phrase.prepared.plan.phraseIndex + 1
           ) {
            // Initial hold quarantine retains the plan-owned target recipe
            // without submitting it. The boundary owner releases this same
            // canonical path after one coherent repeat.
            _ = liveFeedbackPreparation.rebindTargetPayload(
                sourcePlan: phrase.prepared.plan,
                routeGeneration: request.key.routeGeneration,
                sampleRate: request.key.sampleRate,
                occurrenceEpoch: liveFeedbackRuntime.occurrenceEpoch,
                basePayload: request
            )
            markNextPhraseHeld(for: request)
            return
        }
        requestPreparation(request)
    }

    private func makeSuccessorRequest(
        after phrase: PreparedPhrase,
        pendingBinding: PendingLiveMasterHeadroomBinding? = nil,
        liveTargetStartSample: Int64? = nil
    ) -> PhrasePreparationRequest {
        PhrasePreparationRequest(
            key: PhrasePreparationKey(
                sessionSeed: sessionState.rootSeed,
                phraseIndex: sessionState.phraseIndex,
                sampleRate: phrase.request.key.sampleRate,
                channelCount: phrase.request.key.channelCount,
                routeRecovery: false,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value,
                incomingLiveMasterRevision:
                    sessionState.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint:
                    sessionState.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint:
                    pendingBinding?.proposal.fingerprint,
                liveEarliestEligibleFutureSample:
                    pendingBinding?.proposal.earliestEligibleFutureSample,
                liveTargetStartSample: liveTargetStartSample,
                qualityRetryOrdinal: qualityRetryOrdinal(
                    for: sessionState.phraseIndex
                )
            ),
            sourceState: sessionState,
            incomingLongHorizonState: longHorizonState,
            incomingRenderState: phrase.prepared.endingRenderState,
            incomingGraphState: phrase.prepared.endingGraphState,
            previousGraph: phrase.prepared.graph,
            pendingLiveMasterBinding: pendingBinding
        )
    }

    private func nextPhraseNumber(
        for request: PhrasePreparationRequest
    ) -> Int? {
        guard currentPhrase != nil,
              !request.key.routeRecovery,
              request.key.sessionSeed == sessionState.rootSeed,
              request.key.phraseIndex == sessionState.phraseIndex else {
            return nil
        }
        return request.key.phraseIndex + 1
    }

    private func qualityRetryOrdinal(for phraseIndex: Int) -> Int {
        qualityRetryContinuation.ordinal(for: phraseIndex)
    }

    private func markNextPhraseHeld(for request: PhrasePreparationRequest) {
        guard let phraseNumber = nextPhraseNumber(for: request) else { return }
        nextPhraseProgress = nextPhraseProgress.holding(
            targetPhraseNumber: phraseNumber
        )
    }

    private func markNextPhraseQueued(for request: PhrasePreparationRequest) {
        guard let phraseNumber = nextPhraseNumber(for: request) else { return }
        nextPhraseProgress = nextPhraseProgress.queued(
            targetPhraseNumber: phraseNumber
        )
    }

    private func markNextPhrasePreparing(for request: PhrasePreparationRequest) {
        if let phraseNumber = initialPhraseNumber(for: request) {
            nextPhraseProgress = nextPhraseProgress.preparingInitial(
                targetPhraseNumber: phraseNumber
            )
            return
        }
        guard let phraseNumber = nextPhraseNumber(for: request) else { return }
        nextPhraseProgress = nextPhraseProgress.preparing(
            targetPhraseNumber: phraseNumber
        )
    }

    private func markNextPhraseReady(for request: PhrasePreparationRequest) {
        guard let phraseNumber = nextPhraseNumber(for: request) else { return }
        let recoveredFailure = nextPhraseProgress.targetPhraseNumber == phraseNumber
            ? nextPhraseProgress.lastFailure : nil
        nextPhraseProgress = nextPhraseProgress.ready(
            targetPhraseNumber: phraseNumber
        )
        if let recoveredFailure {
            Self.successorPreparationLogger.notice(
                "Successor recovered phrase=\(phraseNumber, privacy: .public) attempt=\(self.nextPhraseProgress.attemptCount, privacy: .public) repeats=\(self.nextPhraseProgress.repeatCount, privacy: .public) retry-variant=\(request.key.qualityRetryOrdinal, privacy: .public) previous-stage=\(recoveredFailure.stage, privacy: .public) previous-code=\(recoveredFailure.code, privacy: .public)"
            )
        }
    }

    private func markNextPhraseRejected(
        for request: PhrasePreparationRequest,
        failure: NextPhraseFailure,
        qualityDecision: QualityDecision? = nil
    ) {
        if initialPhraseNumber(for: request) != nil {
            markInitialPreparationRejected(
                for: request,
                failure: failure,
                qualityDecision: qualityDecision
            )
            return
        }
        guard let phraseNumber = nextPhraseNumber(for: request) else { return }
        if let qualityDecision {
            qualityRetryContinuation = qualityRetryContinuation
                .recordingCalibratedRejection(
                    decision: qualityDecision,
                    targetPhraseIndex: request.key.phraseIndex
                )
        }
        let retriesExhausted = qualityRetryContinuation.isExhausted(
            for: request.key.phraseIndex
        )
        let terminalQualityFailure = qualityDecision.map {
            $0.outcome == .qualificationUnavailable ||
                ($0.outcome == .rejected &&
                    !qualityRetryContinuation.isExhausted(
                        for: request.key.phraseIndex
                    ) &&
                    qualityRetryContinuation.ordinal(
                        for: request.key.phraseIndex
                    ) == request.key.qualityRetryOrdinal)
        } ?? false
        let preparationBlocked = retriesExhausted || terminalQualityFailure
        nextPhraseProgress = preparationBlocked
            ? nextPhraseProgress.blocked(
                targetPhraseNumber: phraseNumber,
                failure: failure
            )
            : nextPhraseProgress.rejected(
                targetPhraseNumber: phraseNumber,
                failure: failure
            )
        Self.successorPreparationLogger.error(
            "Successor failed phrase=\(phraseNumber, privacy: .public) attempt=\(self.nextPhraseProgress.attemptCount, privacy: .public) repeats=\(self.nextPhraseProgress.repeatCount, privacy: .public) retry-variant=\(request.key.qualityRetryOrdinal, privacy: .public) blocked=\(preparationBlocked, privacy: .public) exhausted=\(retriesExhausted, privacy: .public) stage=\(failure.stage, privacy: .public) code=\(failure.code, privacy: .public) details=\(failure.logDetails, privacy: .public)"
        )
    }

    private func initialPhraseNumber(
        for request: PhrasePreparationRequest
    ) -> Int? {
        guard currentPhrase == nil,
              !request.key.routeRecovery,
              request.key.sessionSeed == sessionState.rootSeed,
              request.key.phraseIndex == sessionState.phraseIndex else {
            return nil
        }
        return request.key.phraseIndex + 1
    }

    private func markInitialPreparationRejected(
        for request: PhrasePreparationRequest,
        failure: NextPhraseFailure,
        qualityDecision: QualityDecision? = nil
    ) {
        guard let phraseNumber = initialPhraseNumber(for: request) else { return }
        if let qualityDecision {
            qualityRetryContinuation = qualityRetryContinuation
                .recordingCalibratedRejection(
                    decision: qualityDecision,
                    targetPhraseIndex: request.key.phraseIndex
                )
        }
        let retriesExhausted = qualityRetryContinuation.isExhausted(
            for: request.key.phraseIndex
        )
        let retryOrdinal = qualityRetryContinuation.ordinal(
            for: request.key.phraseIndex
        )
        let canRetry = qualityDecision?.outcome == .rejected &&
            !retriesExhausted &&
            retryOrdinal > request.key.qualityRetryOrdinal
        nextPhraseProgress = canRetry
            ? nextPhraseProgress.rejectedInitial(
                targetPhraseNumber: phraseNumber,
                failure: failure
            )
            : nextPhraseProgress.blockedInitial(
                targetPhraseNumber: phraseNumber,
                failure: failure
            )
        Self.successorPreparationLogger.error(
            "Initial failed phrase=\(phraseNumber, privacy: .public) attempt=\(self.nextPhraseProgress.attemptCount, privacy: .public) retry-variant=\(request.key.qualityRetryOrdinal, privacy: .public) blocked=\(!canRetry, privacy: .public) exhausted=\(retriesExhausted, privacy: .public) stage=\(failure.stage, privacy: .public) code=\(failure.code, privacy: .public) details=\(failure.logDetails, privacy: .public)"
        )
        if canRetry { prepare() }
    }

    private func trimPreparedCache() {
        liveFeedbackPreparation.removeCached { key, _ in
            key.sessionSeed != sessionState.rootSeed ||
                key.phraseIndex != sessionState.phraseIndex ||
                key.routeRecovery
        }
    }

    private func startFreshPlayback(resetPlayingTime: Bool = true) {
        guard currentPhrase != nil else {
            requestedPlaybackAfterPreparation = true
            prepare()
            return
        }
        if resetPlayingTime {
            self.resetPlayingTime()
        }
        recoveryTask?.cancel()
        liveFeedbackOrchestrator.pause {
            self.quiesceAndStopLiveFeedbackCapture(
                mode: .stop
            )
        }
        guard resetLivePlaybackTimeline() else {
            playbackState = .unavailable
            return
        }
        resetSchedule()
        ensureLivePCMTransport(
            format: audioEngine.mainMixerNode.outputFormat(forBus: 0)
        )
        guard scheduleNextBar(first: true) else {
            if playbackState == .preparing || playbackState == .recovering {
                // A synchronous route mismatch was discovered while honoring
                // this explicit PLAY action. Resume once the replacement-route
                // phrase is ready even if the notification arrives later.
                requestedPlaybackAfterPreparation = true
            } else {
                playbackState = .unavailable
            }
            return
        }
        do {
            try audioEngine.start()
            player.play()
            playbackState = .playing
            startDisplayTimer()
        } catch {
            beginRecovery()
        }
    }

    private func pause() {
        guard playbackState == .playing else { return }
        updatePlayingTimeFromPlayerClock()
        displayTimer?.invalidate()
        displayTimer = nil
        liveFeedbackOrchestrator.pause {
            self.quiesceAndStopLiveFeedbackCapture(
                mode: .pause,
                preserveScheduledPhrases: true
            )
        }
        playbackState = .paused
    }

    private func resume() {
        guard playbackState == .paused else { return }
        liveFeedbackOrchestrator.resume(
            routeGeneration: preparationEpoch.value
        )
        ensureLivePCMTransport(
            format: audioEngine.mainMixerNode.outputFormat(forBus: 0)
        )
        do {
            try audioEngine.start()
            player.play()
            playbackState = .playing
            startDisplayTimer()
        } catch {
            beginRecovery()
        }
    }

    private func beginRecovery() {
        guard !isShutDown else { return }
        updatePlayingTimeFromPlayerClock()
        displayTimer?.invalidate()
        displayTimer = nil
        liveFeedbackOrchestrator.captureFailed {
            self.quiesceAndStopLiveFeedbackCapture(
                mode: .stop
            )
        }
        guard resetLivePlaybackTimeline() else {
            playbackState = .unavailable
            return
        }
        playbackState = .recovering
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for attempt in 1...3 {
                if attempt > 1 {
                    do { try await Task.sleep(for: .milliseconds(250 * attempt)) }
                    catch { return }
                }
                guard !Task.isCancelled, !self.isShutDown else { return }
                self.liveFeedbackOrchestrator.resume(
                    routeGeneration: self.preparationEpoch.value
                )
                self.resetSchedule()
                self.ensureLivePCMTransport(
                    format: self.audioEngine.mainMixerNode.outputFormat(forBus: 0)
                )
                guard self.scheduleNextBar(first: true) else { continue }
                do {
                    try self.audioEngine.start()
                    self.player.play()
                    self.playbackState = .playing
                    self.startDisplayTimer()
                    self.recoveryTask = nil
                    return
                } catch {
                    self.player.stop()
                    self.audioEngine.stop()
                }
            }
            self.recoveryTask = nil
            self.playbackState = .unavailable
        }
    }

    /// The player starts again at sample zero after a stop. Rotate a separate
    /// occurrence epoch so old high sample ranges cannot authenticate results
    /// against the new low timeline, while preserving the accepted-PCM hold.
    private func resetLivePlaybackTimeline() -> Bool {
        guard liveFeedbackOrchestrator.playbackTimelineReset(
            routeGeneration: preparationEpoch.value
        ) else { return false }
        playingTimeClock.preserveForTimelineReset()
        if let source = currentPhrase {
            _ = liveFeedbackPreparation.rebindTargetOccurrence(
                sourcePlan: source.prepared.plan,
                routeGeneration: preparationEpoch.value,
                occurrenceEpoch: liveFeedbackRuntime.occurrenceEpoch
            )
        }
        return true
    }

    private func handleAudioConfigurationChange() {
        guard !isShutDown else { return }
        updatePlayingTimeFromPlayerClock()
        let shouldResume = playbackState == .playing || playbackState == .recovering
        let rebuildingPhrase = currentPhrase
        let rebuildingRequest = rebuildingPhrase.map { phrase in
            var incomingRenderState = phrase.request.incomingRenderState
            incomingRenderState.automaticMixState =
                phrase.prepared.endingRenderState.automaticMixState
            incomingRenderState.liveMasterHeadroomState =
                phrase.prepared.liveMasterHeadroomContinuationState
            let source = phrase.request.sourceState
            let committedSource = AutonomousSessionState(
                rootSeed: source.rootSeed,
                phraseIndex: source.phraseIndex,
                intent: source.intent,
                memory: source.memory,
                quality: phrase.prepared.qualityContinuationState,
                liveMasterHeadroom:
                    phrase.prepared.liveMasterHeadroomContinuationState
            )
            return PhrasePreparationRequest(
                key: phrase.request.key,
                sourceState: committedSource,
                incomingLongHorizonState:
                    phrase.request.incomingLongHorizonState,
                incomingRenderState: incomingRenderState,
                incomingGraphState: phrase.request.incomingGraphState,
                previousGraph: phrase.prepared.graph,
                pendingLiveMasterBinding: nil
            )
        } ?? routeRecoveryRequest ?? activePreparationRequest
        if let rebuildingRequest {
            routeRecoveryRequest = rebuildingRequest
        }
        requestedPlaybackAfterPreparation =
            requestedPlaybackAfterPreparation || shouldResume
        recoveryTask?.cancel()
        recoveryTask = nil
        displayTimer?.invalidate()
        displayTimer = nil
        preparationTask?.cancel()
        preparationEpoch.invalidate()
        liveFeedbackPreparation.invalidateTargetPayloadForRouteChange()
        liveFeedbackOrchestrator.routeReset(
            routeGeneration: preparationEpoch.value,
            stopCapture: {
                self.quiesceAndStopLiveFeedbackCapture(
                    mode: .stop
                )
            }
        )
        liveFeedbackPreparation.removeAllCached(keepingCapacity: false)
        currentPhrase = nil
        liveRenderSnapshot = .waiting
        nextPhraseProgress = .waiting
        qualityRetryContinuation = AutonomousQualityRetryContinuation()
        queuedPreparationRequest = nil
        resetSchedule()
        playbackState = .preparing
        guard let rebuildingRequest else {
            routeRecoveryRequest = nil
            prepare()
            return
        }

        audioEngine.prepare()
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        guard format.sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate,
              format.sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate,
              Int(format.channelCount) ==
                QualityQualificationContract.requiredRouteChannelCount else {
            playbackState = .unavailable
            return
        }
        ensureLivePCMTransport(format: format)
        sessionState = rebuildingRequest.sourceState
        longHorizonState = rebuildingRequest.incomingLongHorizonState
        let recoveryRequest = PhrasePreparationRequest(
            key: PhrasePreparationKey(
                sessionSeed: sessionState.rootSeed,
                phraseIndex: sessionState.phraseIndex,
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount),
                routeRecovery: true,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value,
                incomingLiveMasterRevision:
                    sessionState.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint:
                    sessionState.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint: nil,
                liveEarliestEligibleFutureSample: nil,
                liveTargetStartSample: nil
            ),
            sourceState: sessionState,
            incomingLongHorizonState:
                rebuildingRequest.incomingLongHorizonState,
            incomingRenderState: rebuildingRequest.incomingRenderState,
            incomingGraphState: rebuildingRequest.incomingGraphState,
            previousGraph: rebuildingRequest.previousGraph,
            pendingLiveMasterBinding: nil
        )
        routeRecoveryRequest = recoveryRequest
        requestPreparation(recoveryRequest)
    }

    private func ensureLivePCMTransport(format: AVAudioFormat) {
        guard MixerPlayerClockMap.isSupported(sampleRate: format.sampleRate),
              format.commonFormat == .pcmFormatFloat32,
              !format.isInterleaved,
              format.channelCount == 2 else {
            liveFeedbackOrchestrator.captureFailed {
                self.quiesceAndStopLiveFeedbackCapture(
                    mode: .stop
                )
            }
            return
        }
        // Clock probes require a running engine. Queue creation, consumer
        // start, and tap installation are intentionally deferred until two
        // exact probes establish the map.
    }

    /// Producer removal always precedes consumer join and optional queue
    /// destruction. This method is never called from an audio callback.
    private func quiesceAndStopLiveFeedbackCapture(
        mode: LiveFeedbackEngineQuiescenceMode,
        preserveScheduledPhrases: Bool = false
    ) {
        liveFeedbackCaptureLifecycle.quiesceAndTearDown(
            mode: mode,
            quiescePlayer: { mode in
                switch mode {
                case .pause: self.player.pause()
                case .stop: self.player.stop()
                }
            },
            quiesceEngine: { mode in
                switch mode {
                case .pause: self.audioEngine.pause()
                case .stop: self.audioEngine.stop()
                }
            },
            removeTap: {
                self.livePCMTransport?.removeTap()
            },
            cancelAndJoinConsumer: {
                let proof = self.liveFeedbackCoordinator?.stopAndWait()
                self.liveFeedbackCoordinator = nil
                return proof
            },
            destroyQueue: { stopProof in
                if let stopProof {
                    _ = self.livePCMTransport?
                        .destroyQueueAfterConsumerStopped(proof: stopProof)
                } else {
                    _ = self.livePCMTransport?
                        .destroyQueueBeforeConsumerStarts()
                }
                self.livePCMTransport = nil
                if !preserveScheduledPhrases {
                    self.liveScheduledPhrases.removeAll(
                        keepingCapacity: false
                    )
                }
            }
        )
        expirePendingLiveFeedbackAtBoundary()
    }

    private func updateLiveClockAndWorker() {
        guard playbackState == .playing,
              let mixerTime = audioEngine.mainMixerNode.lastRenderTime,
              mixerTime.isSampleTimeValid,
              let playerTime = player.playerTime(forNodeTime: mixerTime),
              playerTime.isSampleTimeValid else { return }
        let probe = MixerPlayerClockProbe(
            mixerSample: Double(mixerTime.sampleTime),
            playerSample: Double(playerTime.sampleTime),
            mixerSampleRate: mixerTime.sampleRate,
            playerSampleRate: playerTime.sampleRate
        )
        let observation = liveFeedbackOrchestrator.observeClock(
            probe,
            startCapture: { map, identity, runtime in
                self.startLiveFeedbackCapture(
                    map: map,
                    identity: identity,
                    runtime: runtime
                )
            }
        )
        if observation == .recoveryRequired {
            beginRecovery()
            return
        }
        if case .captureStarted = observation {
            synchronizeLiveScheduledPhraseKeys()
            if let playing = liveScheduledLedger.playing {
                livePCMTransport?.setGeneration(
                    routeGeneration: playing.routeGeneration,
                    controllerRevision: playing.controllerRevision
                )
            }
            refreshLiveFeedbackContexts()
        }
    }

    private func synchronizeLiveScheduledPhraseKeys() {
        var additions: [(ScheduledPhraseRange, PreparedPhrase)] = []
        for range in liveScheduledLedger.retainedRanges
            where liveScheduledPhrases[range] == nil {
            if let phrase = liveScheduledPhrases.first(where: { old, _ in
                old.phraseIndex == range.phraseIndex &&
                    old.planFingerprint == range.planFingerprint &&
                    old.playerSampleRange == range.playerSampleRange &&
                    old.routeGeneration == range.routeGeneration
            })?.value {
                additions.append((range, phrase))
            }
        }
        for (range, phrase) in additions {
            liveScheduledPhrases[range] = phrase
        }
        liveScheduledPhrases = liveScheduledPhrases.filter {
            liveScheduledLedger.contains($0.key)
        }
    }

    private func startLiveFeedbackCapture(
        map: MixerPlayerClockMap,
        identity: LiveFeedbackWorkerIdentity,
        runtime: LiveFeedbackRuntimeCoordinator
    ) -> Bool {
        guard let transport = LivePCMTransport() else {
            return false
        }
        guard let coordinator = LiveFeedbackCoordinator(
                transport: transport,
                sampleRate: map.sampleRate,
                clockMap: map,
                identity: identity,
                artifacts: qualityArtifacts,
                resultHandler: { [weak self] result in
                    self?.handleLiveFeedbackResult(result)
                }
              ) else {
            _ = transport.destroyQueueBeforeConsumerStarts()
            return false
        }
        transport.setGeneration(
            routeGeneration: preparationEpoch.value,
            controllerRevision: sessionState.liveMasterHeadroom.revision
        )
        guard coordinator.start() else {
            _ = transport.destroyQueueBeforeConsumerStarts()
            return false
        }
        guard liveFeedbackCaptureLifecycle.startProducer(
            consumerDidStart: {
                runtime.consumerDidStart(identity: identity)
            },
            producerDidStart: {
                runtime.producerDidStart(identity: identity)
            },
            installTap: {
                transport.installTap(
                    on: self.audioEngine.mainMixerNode,
                    nativeStereoFormat: self.audioEngine.mainMixerNode
                        .outputFormat(forBus: 0)
                )
            }
        ) else {
            // Permission precedes installation, and installation cannot return
            // false after publishing a tap. No producer quiescence fence is
            // required on this pre-producer cleanup path.
            assert(!transport.tapIsInstalled)
            if let proof = coordinator.stopAndWait() {
                _ = transport.destroyQueueAfterConsumerStopped(proof: proof)
            }
            return false
        }
        livePCMTransport = transport
        liveFeedbackCoordinator = coordinator
        refreshLiveFeedbackContexts()
        return true
    }

    private func registerScheduledOccurrence(
        phrase: PreparedPhrase,
        startSample: Int64
    ) {
        var totalFrames: Int64 = 0
        for block in phrase.prepared.blocks {
            let next = totalFrames.addingReportingOverflow(
                Int64(min(block.left.count, block.right.count))
            )
            guard !next.overflow else { return }
            totalFrames = next.partialValue
        }
        let end = startSample.addingReportingOverflow(totalFrames)
        guard totalFrames > 0, !end.overflow else { return }
        let sourceIdentity = LiveOutputPlanSourceIdentity(
            plan: phrase.prepared.plan
        )
        let controllerState =
            phrase.prepared.liveMasterHeadroomContinuationState
        let draft = LiveFeedbackScheduledOccurrenceDraft(
            phraseIndex: phrase.prepared.plan.phraseIndex,
            planFingerprint: sourceIdentity.planFingerprint,
            playerSampleRange: startSample..<end.partialValue,
            sampleRate: phrase.request.key.sampleRate,
            routeGeneration: preparationEpoch.value,
            occurrenceEpoch: liveFeedbackRuntime.occurrenceEpoch,
            controllerRevision:
                controllerState.revision,
            qualityPolicyVersion:
                phrase.prepared.qualityContinuationState.policyVersion,
            evaluatorVersion: ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier,
            controllerPolicyVersion: LiveFeedbackContract
                .controllerPolicyVersion,
            controllerStateFingerprint:
                AutonomousCandidateFingerprint.combinedController(
                    kickCorrectionDB: phrase.prepared.endingRenderState
                        .automaticMixState.kickCorrectionDB,
                    liveMasterHeadroom: controllerState,
                    proposalFingerprint: nil
                ),
            appliedMasterTrimDB: controllerState.committedTrimDB,
            applicableCheckpoints: sourceIdentity.applicableCheckpoints
        )
        guard let range = liveFeedbackOrchestrator.stageOccurrence(draft) else {
            return
        }
        liveScheduledPhrases[range] = phrase
        liveScheduledPhrases = liveScheduledPhrases.filter {
            liveScheduledLedger.contains($0.key)
        }
        livePCMTransport?.setGeneration(
            routeGeneration: range.routeGeneration,
            controllerRevision: range.controllerRevision
        )
        refreshLiveFeedbackContexts()
    }

    private func promoteScheduledLiveRangeIfNeeded(playerSample: Int64) {
        guard let successor = liveScheduledLedger.scheduledSuccessor,
              playerSample >= successor.playerSampleRange.lowerBound else {
            return
        }
        liveFeedbackOrchestrator.promote(playerSample: playerSample)
        liveScheduledPhrases = liveScheduledPhrases.filter {
            liveScheduledLedger.contains($0.key)
        }
        livePCMTransport?.setGeneration(
            routeGeneration: successor.routeGeneration,
            controllerRevision: successor.controllerRevision
        )
        refreshLiveFeedbackContexts()
    }

    private func refreshLiveFeedbackContexts() {
        guard let coordinator = liveFeedbackCoordinator else { return }
        var contexts: [LiveFeedbackAnalysisContext] = []
        if let sourceRange = liveScheduledLedger.playing,
           liveScheduledLedger.scheduledSuccessor == nil,
           let source = liveScheduledPhrases[sourceRange],
           let context = liveFeedbackPreparation.analysisContext(
                sourceRange: sourceRange,
                sourcePlan: source.prepared.plan,
                incomingState:
                    source.prepared.liveMasterHeadroomContinuationState,
                controllerStateFingerprint:
                    AutonomousCandidateFingerprint.combinedController(
                        kickCorrectionDB: source.prepared.endingRenderState
                            .automaticMixState.kickCorrectionDB,
                        liveMasterHeadroom: source.prepared
                            .liveMasterHeadroomContinuationState,
                        proposalFingerprint: nil
                    ),
                qualityPolicyVersion:
                    source.prepared.qualityContinuationState.policyVersion
           ) {
            contexts.append(context)
        }
        coordinator.update(ledger: liveScheduledLedger, contexts: contexts)
    }

    private func handleLiveFeedbackResult(_ result: LiveFeedbackWorkerResult) {
        guard !isShutDown,
              playbackState == .playing,
              result.identity.routeGeneration == preparationEpoch.value,
              result.sourceRange.routeGeneration == preparationEpoch.value,
              let clockMap = liveClockMap,
              result.sourceRange.isStructurallyValid(clockMap: clockMap),
              liveScheduledLedger.isExactPlayingOccurrence(result.sourceRange),
              result.binding.proposal.sourcePhraseIndex ==
                result.sourceRange.phraseIndex,
              result.binding.proposal.sourcePlanFingerprint ==
                result.sourceRange.planFingerprint,
              result.binding.proposal.incomingRevision ==
                sessionState.liveMasterHeadroom.revision,
              result.binding.proposal.incomingStateFingerprint ==
                sessionState.liveMasterHeadroom.fingerprint else { return }
        let targetPhraseIndex = result.sourceRange.phraseIndex + 1
        guard let baseRequest = liveFeedbackPreparation.correctionPayload(
            sourceRange: result.sourceRange,
            eligibleTargetIdentity: result.binding.eligibleTarget.planIdentity
        ), liveFeedbackOrchestrator.authorize(
            identity: result.identity,
            sourceOccurrence: result.sourceRange,
            targetPhraseIndex: targetPhraseIndex,
            proposalFingerprint: result.binding.proposal.fingerprint
        ) == .invalidateUnscheduledSuccessor else { return }

        pendingLiveMasterBinding = result.binding
        let correctedKey = PhrasePreparationKey(
            sessionSeed: baseRequest.key.sessionSeed,
            phraseIndex: baseRequest.key.phraseIndex,
            sampleRate: baseRequest.key.sampleRate,
            channelCount: baseRequest.key.channelCount,
            routeRecovery: false,
            qualityRevision: baseRequest.key.qualityRevision,
            qualityPolicyVersion: baseRequest.key.qualityPolicyVersion,
            qualityControllerFingerprint:
                baseRequest.key.qualityControllerFingerprint,
            routeGeneration: baseRequest.key.routeGeneration,
            incomingLiveMasterRevision:
                baseRequest.key.incomingLiveMasterRevision,
            incomingLiveMasterStateFingerprint:
                baseRequest.key.incomingLiveMasterStateFingerprint,
            pendingLiveMasterProposalFingerprint:
                result.binding.proposal.fingerprint,
            liveEarliestEligibleFutureSample:
                result.binding.proposal.earliestEligibleFutureSample,
            liveTargetStartSample:
                result.sourceRange.playerSampleRange.upperBound,
            qualityRetryOrdinal: baseRequest.key.qualityRetryOrdinal
        )
        requestPreparation(PhrasePreparationRequest(
            key: correctedKey,
            sourceState: baseRequest.sourceState,
            incomingLongHorizonState:
                baseRequest.incomingLongHorizonState,
            incomingRenderState: baseRequest.incomingRenderState,
            incomingGraphState: baseRequest.incomingGraphState,
            previousGraph: baseRequest.previousGraph,
            pendingLiveMasterBinding: result.binding
        ))
    }

    private func expirePendingLiveFeedbackAtBoundary() {
        guard let proposalFingerprint = pendingLiveMasterBinding?
            .proposal.fingerprint else { return }
        liveFeedbackPreparation.removeCached { key, _ in
            key.pendingLiveMasterProposalFingerprint == proposalFingerprint
        }
        if activePreparationRequest?.key
            .pendingLiveMasterProposalFingerprint == proposalFingerprint {
            preparationTask?.cancel()
            preparationTask = nil
            activePreparationTaskSerial = nil
            preparingKey = nil
            activePreparationRequest = nil
        }
        if queuedPreparationRequest?.key
            .pendingLiveMasterProposalFingerprint == proposalFingerprint {
            queuedPreparationRequest = nil
        }
        pendingLiveMasterBinding = nil
    }

    /// Once a live-corrected target is accepted for its exact boundary, its
    /// stale preserve-course candidate may never reappear afterward.
    private func purgeUntrimmedSuccessor(targetPhraseIndex: Int) {
        liveFeedbackPreparation.removeCached { key, _ in
            key.phraseIndex == targetPhraseIndex &&
                key.pendingLiveMasterProposalFingerprint == nil
        }
        if activePreparationRequest?.key.phraseIndex == targetPhraseIndex,
           activePreparationRequest?.key
            .pendingLiveMasterProposalFingerprint == nil {
            preparationTask?.cancel()
            preparationTask = nil
            activePreparationTaskSerial = nil
            preparingKey = nil
            activePreparationRequest = nil
        }
        if queuedPreparationRequest?.key.phraseIndex == targetPhraseIndex,
           queuedPreparationRequest?.key
            .pendingLiveMasterProposalFingerprint == nil {
            queuedPreparationRequest = nil
        }
    }

    private func resetSchedule() {
        nextBlockIndex = 0
        nextScheduleSample = 0
        currentBarFrames = 1
        scheduledVisuals.removeAll(keepingCapacity: true)
        activeVisualStart = -1
        playhead = 0
        barWithinScene = 1
        liveFeedbackOrchestrator.resetSchedule()
        liveScheduledPhrases.removeAll(keepingCapacity: false)
        liveFeedbackCoordinator?.update(
            ledger: liveScheduledLedger,
            contexts: []
        )
    }

    @discardableResult
    private func scheduleNextBar(first: Bool) -> Bool {
        guard var phrase = currentPhrase else { return false }
        if nextBlockIndex >= phrase.prepared.blocks.count {
            let nextKey = PhrasePreparationKey(
                sessionSeed: sessionState.rootSeed,
                phraseIndex: sessionState.phraseIndex,
                sampleRate: phrase.request.key.sampleRate,
                channelCount: phrase.request.key.channelCount,
                routeRecovery: false,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value,
                incomingLiveMasterRevision:
                    sessionState.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint:
                    sessionState.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint:
                    pendingLiveMasterBinding?.proposal.fingerprint,
                liveEarliestEligibleFutureSample:
                    pendingLiveMasterBinding?.proposal
                        .earliestEligibleFutureSample,
                liveTargetStartSample:
                    pendingLiveMasterBinding == nil
                        ? nil
                        : Int64(nextScheduleSample),
                qualityRetryOrdinal: qualityRetryOrdinal(
                    for: sessionState.phraseIndex
                )
            )
            let sourcePhraseIndex = phrase.prepared.plan.phraseIndex
            let targetPhraseIndex = sourcePhraseIndex + 1
            let untrimmedPreparationAllowed = liveFeedbackOrchestrator
                .allowsUntrimmedPreparation(
                    sourcePhraseIndex: sourcePhraseIndex,
                    targetPhraseIndex: targetPhraseIndex
                )
            let cachedEntry = untrimmedPreparationAllowed ||
                nextKey.pendingLiveMasterProposalFingerprint != nil
                ? liveFeedbackPreparation.firstCached { key, _ in
                    key == nextKey
                }
                : nil
            let correctedBoundaryDecision = LiveCorrectedSuccessorBoundaryPolicy.decide(
                hasLiveProposal:
                    nextKey.pendingLiveMasterProposalFingerprint != nil,
                preparedTargetStartSample:
                    cachedEntry?.value.prepared.liveTargetStartSample,
                earliestEligibleFutureSample:
                    nextKey.liveEarliestEligibleFutureSample,
                actualStartSample: Int64(nextScheduleSample)
            )
            if correctedBoundaryDecision == .advance,
               nextKey.pendingLiveMasterProposalFingerprint != nil,
               !untrimmedPreparationAllowed {
                purgeUntrimmedSuccessor(targetPhraseIndex: targetPhraseIndex)
            }
            let cachedSuccessor = correctedBoundaryDecision == .advance
                ? liveFeedbackPreparation.removeCachedValue(forKey: nextKey)
                : nil
            let boundaryDecision = AutonomousPhraseBoundaryPolicy.decide(
                successorPrepared: cachedSuccessor != nil
            )
            var runtimeAllowsAdvance = false
            var runtimeRequiresRepeat = false
            if pendingLiveMasterBinding != nil || !untrimmedPreparationAllowed {
                liveFeedbackOrchestrator.performBoundary(
                    sourcePhraseIndex: sourcePhraseIndex,
                    targetPhraseIndex: targetPhraseIndex,
                    correctedSuccessorAvailable: cachedSuccessor != nil,
                    expireCorrectedSuccessor: {
                        self.expirePendingLiveFeedbackAtBoundary()
                    },
                    advanceCorrectedSuccessor: {
                        runtimeAllowsAdvance = true
                    },
                    repeatAcceptedPCM: {
                        runtimeRequiresRepeat = true
                    }
                )
            }
            if boundaryDecision == .advance &&
                (pendingLiveMasterBinding == nil &&
                    untrimmedPreparationAllowed || runtimeAllowsAdvance) {
                guard let next = cachedSuccessor,
                      next.request.incomingLongHorizonState?.fingerprint ==
                        longHorizonState?.fingerprint else { return false }
                let advancedState = next.request.sourceState.advance(
                    using: next.prepared.plan,
                    quality: next.prepared.qualityContinuationState,
                    liveMasterHeadroom:
                        next.prepared.liveMasterHeadroomContinuationState,
                    longHorizonDecision: next.longHorizonDecision
                )
                guard next.longHorizonDecision.map({
                    advancedState.memory.longHorizon.lastTrajectoryDecision == $0
                }) ?? true else { return false }
                currentPhrase = next
                phrase = next
                sessionState = advancedState
                longHorizonState = next.outgoingLongHorizonState
                qualityRetryContinuation =
                    AutonomousQualityRetryContinuation()
                liveFeedbackRuntime.retainRecentSources(
                    currentPhraseIndex: sessionState.phraseIndex
                )
                liveFeedbackPreparation.completeSourceAdvance(
                    sourcePhraseIndex: sourcePhraseIndex
                )
                liveFeedbackOrchestrator.completeSourceAdvance(
                    sourcePhraseIndex: sourcePhraseIndex,
                    targetPhraseIndex: targetPhraseIndex
                )
                if next.request.pendingLiveMasterBinding != nil {
                    pendingLiveMasterBinding = nil
                }
                nextBlockIndex = 0
                requestSuccessor(after: next)
            } else if boundaryDecision == .repeatCurrentWithFrozenTopology ||
                runtimeRequiresRepeat {
                // Never leave the player without a queued bar. Repeating the
                // coherent current phrase freezes topology and avoids any
                // rendering or blocking while the successor finishes.
                nextBlockIndex = 0
                nextPhraseProgress = nextPhraseProgress.repeated(
                    targetPhraseNumber: targetPhraseIndex + 1
                )
                if pendingLiveMasterBinding == nil,
                   nextPhraseProgress.stage != .blocked {
                    requestSuccessor(after: phrase)
                }
            } else {
                return false
            }
        }

        guard phrase.prepared.blocks.indices.contains(nextBlockIndex),
              phrase.waveforms.indices.contains(nextBlockIndex),
              phrase.inspectorSnapshots.indices.contains(nextBlockIndex) else {
            return false
        }
        let blockIndex = nextBlockIndex
        let block = phrase.prepared.blocks[blockIndex]
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        guard format.sampleRate == phrase.request.key.sampleRate,
              Int(format.channelCount) == phrase.request.key.channelCount else {
            handleAudioConfigurationChange()
            return false
        }
        guard format.sampleRate > 0, format.channelCount > 0,
              let buffer = makeBuffer(left: block.left, right: block.right, format: format) else { return false }

        let frameLength = AVAudioFramePosition(buffer.frameLength)
        let startSample: AVAudioFramePosition
        if first {
            startSample = 0
        } else {
            startSample = nextScheduleSample
        }
        if blockIndex == 0,
           phrase.request.pendingLiveMasterBinding != nil {
            guard let preparedStart = phrase.prepared.liveTargetStartSample,
                  preparedStart == startSample,
                  let earliest = phrase.request.key
                    .liveEarliestEligibleFutureSample,
                  startSample >= earliest else { return false }
        }
        if blockIndex == 0 {
            registerScheduledOccurrence(
                phrase: phrase,
                startSample: startSample
            )
        }
        if first {
            player.scheduleBuffer(buffer)
            nextScheduleSample = frameLength
            currentBarFrames = frameLength
        } else {
            player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: startSample, atRate: format.sampleRate))
            nextScheduleSample += frameLength
        }
        scheduledVisuals.append(ScheduledVisual(
            startSample: startSample,
            frameLength: frameLength,
            scenePosition: phrase.prepared.plan.phraseIndex,
            bar: block.performance.localBar,
            section: block.section,
            waveform: phrase.waveforms[blockIndex],
            inspectorSnapshot: phrase.inspectorSnapshots[blockIndex]
        ))
        nextBlockIndex += 1
        return true
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePlaybackState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func updatePlaybackState() {
        guard playbackState == .playing,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return }
        let sample = max(0, playerTime.sampleTime)
        updatePlayingTime(
            sampleTime: sample,
            sampleRate: playerTime.sampleRate
        )
        updateLiveClockAndWorker()
        guard playbackState == .playing else { return }
        promoteScheduledLiveRangeIfNeeded(playerSample: sample)

        if let visual = scheduledVisuals.last(where: { $0.startSample <= sample }) {
            if activeVisualStart != visual.startSample {
                activeVisualStart = visual.startSample
                waveform = visual.waveform
                sceneNumber = visual.scenePosition + 1
                barWithinScene = visual.bar + 1
                currentSection = visual.section
                liveRenderSnapshot = visual.inspectorSnapshot
            }
            playhead = min(1, max(0,
                Double(sample - visual.startSample) / Double(max(1, visual.frameLength))))
            currentBarFrames = visual.frameLength
        }

        if scheduledVisuals.count > 4 {
            scheduledVisuals.removeAll { $0.startSample + $0.frameLength < sample - currentBarFrames }
        }
        if nextScheduleSample - sample < currentBarFrames / 2 {
            _ = scheduleNextBar(first: false)
        }
    }

    private func updatePlayingTimeFromPlayerClock() {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return
        }
        updatePlayingTime(
            sampleTime: max(0, playerTime.sampleTime),
            sampleRate: playerTime.sampleRate
        )
    }

    private func updatePlayingTime(
        sampleTime: AVAudioFramePosition,
        sampleRate: Double
    ) {
        let observed = playingTimeClock.observe(
            sampleTime: sampleTime,
            sampleRate: sampleRate
        )
        if playingTimeSeconds != observed {
            playingTimeSeconds = observed
        }
    }

    private func resetPlayingTime() {
        playingTimeClock.reset()
        playingTimeSeconds = 0
    }

    private func makeBuffer(left: [Float], right: [Float],
                            format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = min(left.count, right.count)
        guard frameCount > 0 else { return nil }
        let frames = AVAudioFrameCount(frameCount)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            guard let destination = buffer.floatChannelData?[channel] else { continue }
            let sourceSamples = channel == 1 ? right : left
            sourceSamples.withUnsafeBufferPointer { source in
                guard let baseAddress = source.baseAddress else { return }
                destination.update(from: baseAddress, count: frameCount)
            }
        }
        return buffer
    }
}
