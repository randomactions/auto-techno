import AutoTechnoCore
import AutoTechnoDSP
import AutoTechnoTransport
import AutoTechnoWindowsPlatform
import Dispatch
import Foundation

private enum WindowsPlaybackState: Int32 {
    case preparing = 0
    case ready = 1
    case playing = 2
    case paused = 3
    case recovering = 4
    case unavailable = 5
}

private struct WindowsScheduledVisual: Sendable {
    let startSample: UInt64
    let frameLength: UInt64
    let scenePosition: Int
    let bar: Int
    let waveform: [Float]
}

private struct WindowsRecoveryContext: Sendable {
    let sourceState: AutonomousSessionState
    let incomingLongHorizonState: LongHorizonFutureAdaptationState?
    let incomingRenderState: RenderState
    let incomingGraphState: GeneratedDSPContinuationState
    let previousGraph: DSPGraphPlan?
    let shouldResume: Bool
}

/// Windows owns only transport, lookahead submission, and read-only
/// presentation. Musical planning and PCM rendering remain in the same
/// AutoTechnoCore -> AutoTechnoDSP -> AutoTechnoTransport path as macOS.
private final class WindowsAutoTechnoController: @unchecked Sendable {
    private static let lookaheadBufferCount: UInt32 = 3

    private let stateQueue = DispatchQueue(label: "AutoTechno.Windows.Transport")
    private let preparationQueue = DispatchQueue(
        label: "AutoTechno.Windows.Preparation",
        qos: .userInitiated
    )
    private let director: AutonomousSessionDirector
    private let qualityArtifacts = try? ProfessionalQualityPrimaryArtifacts.load()
    private let longHorizonArtifacts =
        try? LongHorizonProfessionalPolicyArtifacts.load()

    // Every mutable property below is confined to stateQueue. Preparation uses
    // immutable Sendable request snapshots and returns on stateQueue.
    private var sessionState: AutonomousSessionState
    private var longHorizonState: LongHorizonFutureAdaptationState?
    private var sampleRate = 0.0
    private var playbackState = WindowsPlaybackState.preparing
    private var currentPhrase: PreparedPerformancePhrase?
    private var preparedCache: [
        PhrasePreparationKey: PreparedPerformancePhrase
    ] = [:]
    private var preparingKey: PhrasePreparationKey?
    private var queuedPreparationRequest: PhrasePreparationRequest?
    private var nextBlockIndex = 0
    private var nextScheduleSample: UInt64 = 0
    private var scheduledVisuals: [WindowsScheduledVisual] = []
    private var activeVisualStart: UInt64?
    private var routeGeneration = 0
    private var recoveryContext: WindowsRecoveryContext?
    private var requestedPlaybackAfterPreparation = false

    init() {
        var generator = SystemRandomNumberGenerator()
        let director = AutonomousSessionDirector(rootSeed: generator.next())
        self.director = director
        sessionState = director.initialState()
    }

    func audioDeviceStarted(sampleRate: UInt32) {
        stateQueue.async { [self] in
            guard sampleRate > 0 else {
                setPlaybackState(.unavailable)
                return
            }
            self.sampleRate = Double(sampleRate)
            if playbackState == .recovering {
                resumePreparationAfterRecovery()
                return
            }
            setPlaybackState(.preparing)
            requestPreparation(initialPreparationRequest())
        }
    }

    func togglePlayback() {
        stateQueue.async { [self] in
            switch playbackState {
            case .playing:
                if at_windows_audio_pause() != 0 {
                    setPlaybackState(.paused)
                } else {
                    beginRecovery(shouldResume: true)
                }
            case .paused:
                if at_windows_audio_resume() != 0 {
                    setPlaybackState(.playing)
                } else {
                    beginRecovery(shouldResume: true)
                }
            case .ready:
                startFreshPlayback()
            case .unavailable:
                beginRecovery(shouldResume: currentPhrase != nil)
            case .preparing, .recovering:
                break
            }
        }
    }

    func tick(playedFrames: UInt64) {
        stateQueue.async { [self] in
            guard playbackState == .playing else { return }
            queueLookahead()
            updatePresentation(playedFrames: playedFrames)
        }
    }

    private func initialPreparationRequest() -> PhrasePreparationRequest {
        PhrasePreparationRequest(
            key: preparationKey(
                phraseIndex: sessionState.phraseIndex,
                routeRecovery: false
            ),
            sourceState: sessionState,
            incomingLongHorizonState: longHorizonState,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            pendingLiveMasterBinding: nil
        )
    }

    private func preparationKey(
        phraseIndex: Int,
        routeRecovery: Bool
    ) -> PhrasePreparationKey {
        PhrasePreparationKey(
            sessionSeed: sessionState.rootSeed,
            phraseIndex: phraseIndex,
            sampleRate: sampleRate,
            channelCount: QualityQualificationContract.requiredRouteChannelCount,
            routeRecovery: routeRecovery,
            qualityRevision: sessionState.quality.revision,
            qualityPolicyVersion: sessionState.quality.policyVersion,
            qualityControllerFingerprint:
                sessionState.quality.observedControllerStateFingerprint ??
                sessionState.quality.acceptedControllerStateFingerprint,
            routeGeneration: routeGeneration,
            incomingLiveMasterRevision:
                sessionState.liveMasterHeadroom.revision,
            incomingLiveMasterStateFingerprint:
                sessionState.liveMasterHeadroom.fingerprint,
            pendingLiveMasterProposalFingerprint: nil,
            liveEarliestEligibleFutureSample: nil,
            liveTargetStartSample: nil
        )
    }

    private func requestPreparation(_ request: PhrasePreparationRequest) {
        if preparingKey == request.key {
            return
        }
        guard preparingKey == nil else {
            queuedPreparationRequest = request
            return
        }

        preparingKey = request.key
        let director = director
        let qualityArtifacts = qualityArtifacts
        let longHorizonArtifacts = longHorizonArtifacts
        preparationQueue.async { [weak self] in
            let result = AutonomousPerformancePreparer.prepare(
                request: request,
                director: director,
                artifacts: qualityArtifacts,
                longHorizonArtifacts: longHorizonArtifacts
            )
            self?.stateQueue.async { [weak self] in
                guard let self else { return }
                guard self.preparingKey == request.key else { return }
                self.preparingKey = nil
                if let result {
                    self.acceptPreparedPhrase(result)
                } else if self.currentPhrase == nil {
                    self.setPlaybackState(.unavailable)
                }
                if let queued = self.queuedPreparationRequest {
                    self.queuedPreparationRequest = nil
                    self.requestPreparation(queued)
                }
            }
        }
    }

    private func acceptPreparedPhrase(_ phrase: PreparedPerformancePhrase) {
        guard phrase.request.key.routeGeneration == routeGeneration,
              phrase.request.key.phraseIndex == phrase.request.sourceState.phraseIndex,
              phrase.request.key.sessionSeed == phrase.request.sourceState.rootSeed,
              phrase.request.key.sessionSeed == sessionState.rootSeed,
              phrase.prepared.graph.sessionSeed == phrase.request.key.sessionSeed,
              phrase.request.incomingLongHorizonState?.fingerprint ==
                longHorizonState?.fingerprint,
              phrase.prepared.commitEligible,
              phrase.prepared.incomingLiveMasterHeadroomState ==
                phrase.request.sourceState.liveMasterHeadroom else {
            if currentPhrase == nil {
                setPlaybackState(.unavailable)
            }
            return
        }

        guard currentPhrase == nil else {
            if phrase.request.sourceState.phraseIndex == sessionState.phraseIndex {
                preparedCache[phrase.request.key] = phrase
                trimPreparedCache()
            }
            return
        }
        guard phrase.request.sourceState.phraseIndex == sessionState.phraseIndex else {
            return
        }

        currentPhrase = phrase
        sessionState = phrase.request.sourceState.advance(
            using: phrase.prepared.plan,
            quality: phrase.prepared.qualityContinuationState,
            liveMasterHeadroom:
                phrase.prepared.liveMasterHeadroomContinuationState,
            longHorizonDecision: phrase.longHorizonDecision
        )
        longHorizonState = phrase.outgoingLongHorizonState
        nextBlockIndex = 0
        if let waveform = phrase.waveforms.first {
            setWaveform(waveform)
        }
        setPlaybackState(.ready)
        requestSuccessor(after: phrase)
        if requestedPlaybackAfterPreparation {
            requestedPlaybackAfterPreparation = false
            startFreshPlayback()
        }
    }

    private func requestSuccessor(after phrase: PreparedPerformancePhrase) {
        requestPreparation(PhrasePreparationRequest(
            key: preparationKey(
                phraseIndex: sessionState.phraseIndex,
                routeRecovery: false
            ),
            sourceState: sessionState,
            incomingLongHorizonState: longHorizonState,
            incomingRenderState: phrase.prepared.endingRenderState,
            incomingGraphState: phrase.prepared.endingGraphState,
            previousGraph: phrase.prepared.graph,
            pendingLiveMasterBinding: nil
        ))
    }

    private func trimPreparedCache() {
        preparedCache = preparedCache.filter { key, _ in
            key.phraseIndex == sessionState.phraseIndex && !key.routeRecovery
        }
    }

    private func startFreshPlayback() {
        resetSchedule()
        queueLookahead()
        guard at_windows_audio_queued_buffer_count() > 0,
              at_windows_audio_start() != 0 else {
            beginRecovery(shouldResume: true)
            return
        }
        setPlaybackState(.playing)
    }

    private func queueLookahead() {
        while at_windows_audio_queued_buffer_count() < Self.lookaheadBufferCount {
            guard queueNextBar() else {
                if playbackState != .recovering,
                   at_windows_audio_queued_buffer_count() == 0 {
                    setPlaybackState(.unavailable)
                }
                return
            }
        }
    }

    @discardableResult
    private func queueNextBar() -> Bool {
        guard var phrase = currentPhrase else { return false }
        if nextBlockIndex >= phrase.prepared.blocks.count {
            let nextKey = preparationKey(
                phraseIndex: sessionState.phraseIndex,
                routeRecovery: false
            )
            let cachedSuccessor = preparedCache.removeValue(forKey: nextKey)
            switch AutonomousPhraseBoundaryPolicy.decide(
                successorPrepared: cachedSuccessor != nil
            ) {
            case .advance:
                guard let next = cachedSuccessor else { return false }
                currentPhrase = next
                phrase = next
                sessionState = next.request.sourceState.advance(
                    using: next.prepared.plan,
                    quality: next.prepared.qualityContinuationState,
                    liveMasterHeadroom:
                        next.prepared.liveMasterHeadroomContinuationState,
                    longHorizonDecision: next.longHorizonDecision
                )
                longHorizonState = next.outgoingLongHorizonState
                nextBlockIndex = 0
                requestSuccessor(after: next)
            case .repeatCurrentWithFrozenTopology:
                // Keep the device fed with already-qualified immutable audio;
                // do not prepare, block, or mutate topology in an audio callback.
                nextBlockIndex = 0
                requestSuccessor(after: phrase)
            }
        }

        guard phrase.prepared.blocks.indices.contains(nextBlockIndex),
              phrase.waveforms.indices.contains(nextBlockIndex) else {
            return false
        }
        let blockIndex = nextBlockIndex
        let block = phrase.prepared.blocks[blockIndex]
        let frameCount = min(block.left.count, block.right.count)
        guard frameCount > 0, frameCount <= Int(UInt32.max) else { return false }

        let submitted = block.left.withUnsafeBufferPointer { left in
            block.right.withUnsafeBufferPointer { right in
                at_windows_audio_submit(
                    left.baseAddress,
                    right.baseAddress,
                    UInt32(frameCount)
                )
            }
        }
        guard submitted != 0 else {
            _ = at_windows_audio_pause()
            beginRecovery(shouldResume: true)
            return false
        }

        let frames = UInt64(frameCount)
        scheduledVisuals.append(WindowsScheduledVisual(
            startSample: nextScheduleSample,
            frameLength: frames,
            scenePosition: phrase.prepared.plan.phraseIndex,
            bar: block.performance.localBar,
            waveform: phrase.waveforms[blockIndex]
        ))
        nextScheduleSample += frames
        nextBlockIndex += 1
        return true
    }

    private func updatePresentation(playedFrames: UInt64) {
        guard let visual = scheduledVisuals.last(where: {
            $0.startSample <= playedFrames
        }) else {
            return
        }

        if activeVisualStart != visual.startSample {
            activeVisualStart = visual.startSample
            setWaveform(visual.waveform)
            at_windows_ui_set_position(
                Int32(clamping: visual.scenePosition + 1),
                Int32(clamping: visual.bar + 1),
                Int32(clamping: Int(AutonomousSessionDirector.bpm))
            )
        }
        let elapsed = playedFrames >= visual.startSample
            ? playedFrames - visual.startSample
            : 0
        at_windows_ui_set_playhead(
            min(1, max(0, Double(elapsed) / Double(max(1, visual.frameLength))))
        )

        if scheduledVisuals.count > 8 {
            scheduledVisuals.removeAll {
                $0.startSample + $0.frameLength < playedFrames
            }
        }
    }

    private func setPlaybackState(_ state: WindowsPlaybackState) {
        playbackState = state
        at_windows_ui_set_state(state.rawValue)
    }

    private func beginRecovery(shouldResume: Bool) {
        guard playbackState != .recovering else { return }
        let rebuildingPhrase = currentPhrase
        let rebuildingRequest = rebuildingPhrase?.request
        if let rebuildingRequest {
            recoveryContext = WindowsRecoveryContext(
                sourceState: rebuildingRequest.sourceState,
                incomingLongHorizonState:
                    rebuildingRequest.incomingLongHorizonState,
                incomingRenderState: rebuildingRequest.incomingRenderState,
                incomingGraphState: rebuildingRequest.incomingGraphState,
                previousGraph:
                    rebuildingPhrase?.prepared.graph ?? rebuildingRequest.previousGraph,
                shouldResume: shouldResume
            )
        } else if let existingRecovery = recoveryContext {
            recoveryContext = WindowsRecoveryContext(
                sourceState: existingRecovery.sourceState,
                incomingLongHorizonState:
                    existingRecovery.incomingLongHorizonState,
                incomingRenderState: existingRecovery.incomingRenderState,
                incomingGraphState: existingRecovery.incomingGraphState,
                previousGraph: existingRecovery.previousGraph,
                shouldResume: existingRecovery.shouldResume || shouldResume
            )
        }
        requestedPlaybackAfterPreparation = shouldResume
        routeGeneration += 1
        preparingKey = nil
        queuedPreparationRequest = nil
        preparedCache.removeAll(keepingCapacity: false)
        currentPhrase = nil
        resetSchedule()
        setPlaybackState(.recovering)
        at_windows_audio_request_recovery()
    }

    private func resumePreparationAfterRecovery() {
        resetSchedule()
        guard let recoveryContext else {
            requestedPlaybackAfterPreparation = false
            sessionState = director.initialState()
            longHorizonState = nil
            setPlaybackState(.preparing)
            requestPreparation(initialPreparationRequest())
            return
        }
        self.recoveryContext = nil
        requestedPlaybackAfterPreparation = recoveryContext.shouldResume
        sessionState = recoveryContext.sourceState
        longHorizonState = recoveryContext.incomingLongHorizonState
        setPlaybackState(.preparing)
        requestPreparation(PhrasePreparationRequest(
            key: preparationKey(
                phraseIndex: sessionState.phraseIndex,
                routeRecovery: true
            ),
            sourceState: sessionState,
            incomingLongHorizonState: longHorizonState,
            incomingRenderState: recoveryContext.incomingRenderState,
            incomingGraphState: recoveryContext.incomingGraphState,
            previousGraph: recoveryContext.previousGraph,
            pendingLiveMasterBinding: nil
        ))
    }

    private func resetSchedule() {
        nextBlockIndex = 0
        nextScheduleSample = 0
        scheduledVisuals.removeAll(keepingCapacity: true)
        activeVisualStart = nil
        at_windows_ui_set_playhead(0)
    }

    private func setWaveform(_ waveform: [Float]) {
        waveform.withUnsafeBufferPointer { samples in
            guard let baseAddress = samples.baseAddress else { return }
            at_windows_ui_set_waveform(baseAddress, UInt32(clamping: samples.count))
        }
    }
}

private let startedCallback: @convention(c) (
    UnsafeMutableRawPointer?, UInt32
) -> Void = { context, sampleRate in
    guard let context else { return }
    Unmanaged<WindowsAutoTechnoController>
        .fromOpaque(context)
        .takeUnretainedValue()
        .audioDeviceStarted(sampleRate: sampleRate)
}

private let transportCallback: @convention(c) (
    UnsafeMutableRawPointer?
) -> Void = { context in
    guard let context else { return }
    Unmanaged<WindowsAutoTechnoController>
        .fromOpaque(context)
        .takeUnretainedValue()
        .togglePlayback()
}

private let tickCallback: @convention(c) (
    UnsafeMutableRawPointer?, UInt64
) -> Void = { context, playedFrames in
    guard let context else { return }
    Unmanaged<WindowsAutoTechnoController>
        .fromOpaque(context)
        .takeUnretainedValue()
        .tick(playedFrames: playedFrames)
}

@main
private struct AutoTechnoWindowsMain {
    static func main() {
        let controller = WindowsAutoTechnoController()
        let retainedController = Unmanaged.passRetained(controller)
        defer { retainedController.release() }
        _ = at_windows_run(
            retainedController.toOpaque(),
            startedCallback,
            transportCallback,
            tickCallback
        )
    }
}
