import AVFoundation
import AutoTechnoCore
import AutoTechnoDSP
import Combine
import Foundation

private struct PhrasePreparationKey: Hashable, Sendable {
    let phraseIndex: Int
    /// Exact AVAudioFormat route rate. Rounding here would let nearby
    /// fractional hardware rates share provenance while playing at different
    /// speeds.
    let sampleRate: Double
    let channelCount: Int
    let routeRecovery: Bool
    let qualityRevision: Int
    let qualityPolicyVersion: String
    let qualityControllerFingerprint: String?
    let routeGeneration: Int
}

private struct PhrasePreparationRequest: Sendable {
    let key: PhrasePreparationKey
    let sourceState: AutonomousSessionState
    let incomingRenderState: RenderState
    let incomingGraphState: GeneratedDSPContinuationState
    let previousGraph: DSPGraphPlan?
}

private struct PreparedPhrase: Sendable {
    let request: PhrasePreparationRequest
    let prepared: PreparedAutonomousPhrase
    let waveforms: [[Float]]
}

private struct ScheduledVisual {
    let startSample: AVAudioFramePosition
    let frameLength: AVAudioFramePosition
    let scenePosition: Int
    let bar: Int
    let section: SectionKind
    let waveform: [Float]
}

/// Preparation remains entirely outside the audio callback. It produces the
/// immutable blocks and cheap waveform envelopes consumed by the scheduler.
private enum AutonomousPerformancePreparer {
    static func prepare(request: PhrasePreparationRequest,
                        director: AutonomousSessionDirector,
                        artifacts: ProfessionalQualityPrimaryArtifacts?)
        -> PreparedPhrase? {
        let plan = director.plan(from: request.sourceState)
        let evaluator = ProfessionalQualityPreparationEvaluator(
            sampleRate: request.key.sampleRate,
            artifacts: artifacts
        )
        guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
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
            evaluator: evaluator,
            cancellationRequested: { Task.isCancelled }
        ), !Task.isCancelled else { return nil }
        var waveforms: [[Float]] = []
        waveforms.reserveCapacity(prepared.blocks.count)
        for block in prepared.blocks {
            guard !Task.isCancelled else { return nil }
            waveforms.append(WaveformEnvelope.fixedDB(
                left: block.left,
                right: block.right
            ))
        }
        guard !Task.isCancelled else { return nil }
        return PreparedPhrase(request: request, prepared: prepared, waveforms: waveforms)
    }
}

@MainActor
final class TechnoEngine: ObservableObject {
    enum PlaybackState: Equatable {
        case preparing
        case ready
        case playing
        case paused
        case recovering
        case unavailable
    }

    static let bpm = AutonomousSessionDirector.bpm

    @Published private(set) var playbackState: PlaybackState = .preparing
    @Published private(set) var waveform: [Float] = Array(repeating: 0.04, count: 64)
    @Published private(set) var playhead = 0.0
    @Published private(set) var sceneNumber = 1
    @Published private(set) var barWithinScene = 1
    @Published private(set) var currentSection: SectionKind = .groove

    var isPlaying: Bool { playbackState == .playing }
    var transportEnabled: Bool {
        playbackState != .preparing && playbackState != .recovering
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

    private let director: AutonomousSessionDirector
    private var sessionState: AutonomousSessionState
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var configurationObserver: NSObjectProtocol?
    private var recoveryTask: Task<Void, Never>?
    private var displayTimer: Timer?

    private var currentPhrase: PreparedPhrase?
    private var preparedCache: [PhrasePreparationKey: PreparedPhrase] = [:]
    private var preparationTask: Task<PreparedPhrase?, Never>?
    private var preparationTaskSerial: UInt64 = 0
    private var activePreparationTaskSerial: UInt64?
    private var preparingKey: PhrasePreparationKey?
    private var activePreparationRequest: PhrasePreparationRequest?
    private var queuedPreparationRequest: PhrasePreparationRequest?
    private var preparationEpoch = AutonomousPreparationEpoch()
    private var requestedPlaybackAfterPreparation = false
    /// Survives repeated configuration notifications while the prior detached
    /// task is cancelling, so the interrupted phrase remains the recovery
    /// source instead of being replaced by a stale successor request.
    private var routeRecoveryRequest: PhrasePreparationRequest?
    /// Loaded once outside detached preparation and never touched by the audio
    /// callback. A failed load leaves professional qualification unavailable.
    private let qualityArtifacts: ProfessionalQualityPrimaryArtifacts?

    private var nextBlockIndex = 0
    private var nextScheduleSample: AVAudioFramePosition = 0
    private var currentBarFrames: AVAudioFramePosition = 1
    private var scheduledVisuals: [ScheduledVisual] = []
    private var activeVisualStart: AVAudioFramePosition = -1
    private var isShutDown = false
    private var lifecycleGeneration: UInt64 = 0

    init() {
        let director = AutonomousSessionDirector()
        qualityArtifacts = try? ProfessionalQualityPrimaryArtifacts.load()
        self.director = director
        sessionState = director.initialState()
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
        playbackState = .preparing
        requestPreparation(PhrasePreparationRequest(
            key: PhrasePreparationKey(
                phraseIndex: sessionState.phraseIndex,
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount),
                routeRecovery: false,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value
            ),
            sourceState: sessionState,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil
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

    func shutdown() {
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
        preparedCache.removeAll(keepingCapacity: false)
        currentPhrase = nil
        // View disappearance is a complete transport boundary. A later
        // appearance restarts one coherent session instead of pairing an
        // advanced musical memory with reset render/DSP continuation.
        sessionState = director.initialState()
        resetSchedule()
        sceneNumber = 1
        currentSection = .groove
        playbackState = .unavailable
        displayTimer?.invalidate()
        displayTimer = nil
        player.stop()
        audioEngine.stop()
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
    }

    private func requestPreparation(_ request: PhrasePreparationRequest) {
        guard !isShutDown else { return }
        if let prepared = preparedCache.removeValue(forKey: request.key) {
            acceptPreparedPhrase(prepared)
            return
        }
        if preparingKey == request.key { return }
        guard preparationTask == nil else {
            queuedPreparationRequest = request
            return
        }

        preparingKey = request.key
        activePreparationRequest = request
        let generation = preparationEpoch.value
        preparationTaskSerial &+= 1
        let taskSerial = preparationTaskSerial
        activePreparationTaskSerial = taskSerial
        let director = director
        let qualityArtifacts = qualityArtifacts
        let task = Task.detached(priority: .userInitiated) {
            AutonomousPerformancePreparer.prepare(
                request: request,
                director: director,
                artifacts: qualityArtifacts
            )
        }
        preparationTask = task
        Task { @MainActor [weak self] in
            let prepared = await task.value
            guard let self else { return }
            guard self.activePreparationTaskSerial == taskSerial else { return }
            self.preparationTask = nil
            self.activePreparationTaskSerial = nil
            self.preparingKey = nil
            self.activePreparationRequest = nil
            if self.preparationEpoch.accepts(generation) {
                if let prepared {
                    self.acceptPreparedPhrase(prepared)
                } else if self.queuedPreparationRequest == nil,
                          self.currentPhrase == nil {
                    self.playbackState = .unavailable
                }
            }
            if let queued = self.queuedPreparationRequest {
                self.queuedPreparationRequest = nil
                self.requestPreparation(queued)
            }
        }
    }

    private func acceptPreparedPhrase(_ phrase: PreparedPhrase) {
        guard !isShutDown else { return }
        guard phrase.request.key.phraseIndex == phrase.request.sourceState.phraseIndex else { return }
        guard phrase.prepared.commitEligible else {
            if currentPhrase == nil { playbackState = .unavailable }
            return
        }
        guard currentPhrase == nil else {
            if phrase.request.sourceState.phraseIndex == sessionState.phraseIndex {
                preparedCache[phrase.request.key] = phrase
                trimPreparedCache()
            }
            return
        }
        guard phrase.request.sourceState.phraseIndex == sessionState.phraseIndex else { return }

        currentPhrase = phrase
        if phrase.request.key.routeRecovery {
            routeRecoveryRequest = nil
        }
        sessionState = phrase.request.sourceState
        sessionState.advance(
            using: phrase.prepared.plan,
            quality: phrase.prepared.qualityContinuationState
        )
        nextBlockIndex = 0
        if let firstWaveform = phrase.waveforms.first {
            waveform = firstWaveform
        }
        currentSection = phrase.prepared.blocks.first?.section ?? .groove
        playbackState = .ready
        requestSuccessor(after: phrase)
        if requestedPlaybackAfterPreparation {
            requestedPlaybackAfterPreparation = false
            startFreshPlayback()
        }
    }

    private func requestSuccessor(after phrase: PreparedPhrase) {
        requestPreparation(PhrasePreparationRequest(
            key: PhrasePreparationKey(
                phraseIndex: sessionState.phraseIndex,
                sampleRate: phrase.request.key.sampleRate,
                channelCount: phrase.request.key.channelCount,
                routeRecovery: false,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value
            ),
            sourceState: sessionState,
            incomingRenderState: phrase.prepared.endingRenderState,
            incomingGraphState: phrase.prepared.endingGraphState,
            previousGraph: phrase.prepared.graph
        ))
    }

    private func trimPreparedCache() {
        preparedCache = preparedCache.filter { key, _ in
            key.phraseIndex == sessionState.phraseIndex && !key.routeRecovery
        }
    }

    private func startFreshPlayback() {
        guard currentPhrase != nil else {
            requestedPlaybackAfterPreparation = true
            prepare()
            return
        }
        recoveryTask?.cancel()
        player.stop()
        audioEngine.stop()
        resetSchedule()
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
        displayTimer?.invalidate()
        displayTimer = nil
        player.pause()
        audioEngine.pause()
        playbackState = .paused
    }

    private func resume() {
        guard playbackState == .paused else { return }
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
        displayTimer?.invalidate()
        displayTimer = nil
        player.stop()
        audioEngine.stop()
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
                self.resetSchedule()
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

    private func handleAudioConfigurationChange() {
        guard !isShutDown else { return }
        let shouldResume = playbackState == .playing || playbackState == .recovering
        let rebuildingPhrase = currentPhrase
        let rebuildingRequest = rebuildingPhrase.map { phrase in
            PhrasePreparationRequest(
                key: phrase.request.key,
                sourceState: phrase.request.sourceState,
                incomingRenderState: phrase.request.incomingRenderState,
                incomingGraphState: phrase.request.incomingGraphState,
                previousGraph: phrase.prepared.graph
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
        player.stop()
        audioEngine.stop()
        preparationTask?.cancel()
        preparationEpoch.invalidate()
        preparedCache.removeAll(keepingCapacity: false)
        currentPhrase = nil
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
        sessionState = rebuildingRequest.sourceState
        let recoveryRequest = PhrasePreparationRequest(
            key: PhrasePreparationKey(
                phraseIndex: sessionState.phraseIndex,
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount),
                routeRecovery: true,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value
            ),
            sourceState: sessionState,
            incomingRenderState: rebuildingRequest.incomingRenderState,
            incomingGraphState: rebuildingRequest.incomingGraphState,
            previousGraph: rebuildingRequest.previousGraph
        )
        routeRecoveryRequest = recoveryRequest
        requestPreparation(recoveryRequest)
    }

    private func resetSchedule() {
        nextBlockIndex = 0
        nextScheduleSample = 0
        currentBarFrames = 1
        scheduledVisuals.removeAll(keepingCapacity: true)
        activeVisualStart = -1
        playhead = 0
        barWithinScene = 1
    }

    @discardableResult
    private func scheduleNextBar(first: Bool) -> Bool {
        guard var phrase = currentPhrase else { return false }
        if nextBlockIndex >= phrase.prepared.blocks.count {
            let nextKey = PhrasePreparationKey(
                phraseIndex: sessionState.phraseIndex,
                sampleRate: phrase.request.key.sampleRate,
                channelCount: phrase.request.key.channelCount,
                routeRecovery: false,
                qualityRevision: sessionState.quality.revision,
                qualityPolicyVersion: sessionState.quality.policyVersion,
                qualityControllerFingerprint:
                    sessionState.quality.observedControllerStateFingerprint ??
                    sessionState.quality.acceptedControllerStateFingerprint,
                routeGeneration: preparationEpoch.value
            )
            let cachedSuccessor = preparedCache.removeValue(forKey: nextKey)
            switch AutonomousPhraseBoundaryPolicy.decide(successorPrepared: cachedSuccessor != nil) {
            case .advance:
                guard let next = cachedSuccessor else { return false }
                currentPhrase = next
                phrase = next
                sessionState = next.request.sourceState
                sessionState.advance(
                    using: next.prepared.plan,
                    quality: next.prepared.qualityContinuationState
                )
                nextBlockIndex = 0
                requestSuccessor(after: next)
            case .repeatCurrentWithFrozenTopology:
                // Never leave the player without a queued bar. Repeating the
                // coherent current phrase freezes topology and avoids any
                // rendering or blocking while the successor finishes.
                nextBlockIndex = 0
                requestSuccessor(after: phrase)
            }
        }

        guard phrase.prepared.blocks.indices.contains(nextBlockIndex),
              phrase.waveforms.indices.contains(nextBlockIndex) else { return false }
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
            player.scheduleBuffer(buffer)
            nextScheduleSample = frameLength
            currentBarFrames = frameLength
        } else {
            startSample = nextScheduleSample
            player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: startSample, atRate: format.sampleRate))
            nextScheduleSample += frameLength
        }
        scheduledVisuals.append(ScheduledVisual(
            startSample: startSample,
            frameLength: frameLength,
            scenePosition: phrase.prepared.plan.phraseIndex,
            bar: block.performance.localBar,
            section: block.section,
            waveform: phrase.waveforms[blockIndex]
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

        if let visual = scheduledVisuals.last(where: { $0.startSample <= sample }) {
            if activeVisualStart != visual.startSample {
                activeVisualStart = visual.startSample
                waveform = visual.waveform
                sceneNumber = visual.scenePosition + 1
                barWithinScene = visual.bar + 1
                currentSection = visual.section
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
