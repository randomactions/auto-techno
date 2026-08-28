import AutoTechnoCore
import Foundation

/// Immutable, route-normalized parameters for the canonical late spatial tail.
/// The semantic room, decay, and damping requests are resolved before the
/// sample loop; the loop itself owns no musical decisions.
package struct FeedbackDelayNetworkConfiguration: Equatable, Sendable {
    package static let lineCount = 8
    package static let minimumRoomScale = 0.78
    package static let maximumRoomScale = 1.24
    package static let minimumDecayTimeSeconds = 1.25
    package static let maximumDecayTimeSeconds = 5.8
    package static let minimumDampingHz = 800.0
    package static let maximumDelaySeconds = 0.21

    package let sampleRate: Double
    package let roomScale: Double
    package let decayTimeSeconds: Double
    package let dampingHz: Double
    package let delayFrameCounts: [Int]
    package let feedbackGains: [Double]
    package let dampingCoefficient: Double
    package let synthSendGain: Double
    package let percussionSendGain: Double
    package let wetGain: Double

    package init(
        sampleRate: Double,
        roomScale: Double,
        decayTimeSeconds: Double,
        dampingHz: Double,
        synthSendGain: Double = 0.36,
        percussionSendGain: Double = 0.08,
        wetGain: Double = 0.10
    ) {
        let safeSampleRate = sampleRate.isFinite && sampleRate > 0
            ? sampleRate : 48_000
        let boundedRoomScale = roomScale.isFinite
            ? min(Self.maximumRoomScale, max(Self.minimumRoomScale, roomScale))
            : 1
        let boundedDecay = decayTimeSeconds.isFinite
            ? min(
                Self.maximumDecayTimeSeconds,
                max(Self.minimumDecayTimeSeconds, decayTimeSeconds)
            ) : Self.minimumDecayTimeSeconds
        let nyquistBound = safeSampleRate * 0.45
        let boundedDamping = dampingHz.isFinite
            ? min(nyquistBound, max(Self.minimumDampingHz, dampingHz))
            : min(nyquistBound, 3_200)
        // Distinct delays prevent a single repeating pitch from dominating
        // the tail. The odd frame count also avoids exact half-rate cycles.
        let baseDelaySeconds = [
            0.043, 0.053, 0.067, 0.079,
            0.097, 0.113, 0.137, 0.163,
        ]
        var previous = 1
        let delays = baseDelaySeconds.map { seconds -> Int in
            var frames = max(3, Int((seconds * boundedRoomScale * safeSampleRate).rounded()))
            if frames.isMultiple(of: 2) { frames += 1 }
            if frames <= previous { frames = previous + 2 }
            previous = frames
            return frames
        }

        self.sampleRate = safeSampleRate
        self.roomScale = boundedRoomScale
        self.decayTimeSeconds = boundedDecay
        self.dampingHz = boundedDamping
        delayFrameCounts = delays
        feedbackGains = delays.map { frames in
            // A signal loses 60 dB after the requested RT60. Applying the
            // line-specific loss after an orthogonal matrix keeps every loop
            // strictly below unity while making decay independent of delay.
            let delaySeconds = Double(frames) / safeSampleRate
            return pow(10, -3 * delaySeconds / boundedDecay)
        }
        dampingCoefficient = min(
            1,
            max(0, 1 - exp(-2 * .pi * boundedDamping / safeSampleRate))
        )
        self.synthSendGain = synthSendGain.isFinite
            ? min(0.5, max(0, synthSendGain)) : 0
        self.percussionSendGain = percussionSendGain.isFinite
            ? min(0.16, max(0, percussionSendGain)) : 0
        self.wetGain = wetGain.isFinite ? min(0.24, max(0, wetGain)) : 0
    }

    package init(
        scene: TechnoScene,
        sampleRate: Double,
        phraseKind: AutonomousPhraseKind = .lock
    ) {
        // Identity return is already the score-owned home/dry boundary for
        // selective spatial contrast. Keep the continuing FDN memory intact,
        // but lower its audible return at that future phrase boundary so the
        // restored identity is not blurred by the preceding macro's field.
        let returnScale = phraseKind == .identityReturn ? 0.45 : 1.0
        let ordinaryWetGain = min(
            0.24,
            scene.atmosphere * 0.30 + scene.drone * 0.42
        )
        self.init(
            sampleRate: sampleRate,
            roomScale: 0.84 + scene.atmosphere * 0.28 + scene.drone * 0.08,
            decayTimeSeconds: (1.45 + scene.hypnosis * 2.20 +
                scene.drone * 1.30 + scene.atmosphere * 0.60) * 1.75,
            dampingHz: 2_300 + (1 - scene.atmosphericDarkness) * 3_300,
            synthSendGain: 0.34 + scene.atmosphere * 0.06,
            percussionSendGain: scene.atmosphere * 0.08,
            wetGain: ordinaryWetGain * returnScale
        )
    }

    package var maximumFeedbackGain: Double {
        feedbackGains.max() ?? 0
    }

    /// Rebuilds only the delay geometry while retaining the current
    /// score-owned decay, damping, send, and wet targets. The active route
    /// keeps one geometry across ordinary musical boundaries so a scene change
    /// cannot erase the recursive field it inherited.
    package func retainingGeometry(roomScale: Double) -> Self {
        Self(
            sampleRate: sampleRate,
            roomScale: roomScale,
            decayTimeSeconds: decayTimeSeconds,
            dampingHz: dampingHz,
            synthSendGain: synthSendGain,
            percussionSendGain: percussionSendGain,
            wetGain: wetGain
        )
    }

    package var isBoundedAndStable: Bool {
        sampleRate.isFinite && sampleRate > 0 &&
            (Self.minimumRoomScale...Self.maximumRoomScale).contains(roomScale) &&
            (Self.minimumDecayTimeSeconds...Self.maximumDecayTimeSeconds)
                .contains(decayTimeSeconds) &&
            dampingHz.isFinite && dampingHz >= Self.minimumDampingHz &&
            dampingHz <= sampleRate * 0.45 &&
            delayFrameCounts.count == Self.lineCount &&
            feedbackGains.count == Self.lineCount &&
            zip(delayFrameCounts, feedbackGains).allSatisfy { frames, gain in
                frames >= 3 && frames <= Int(
                    sampleRate * Self.maximumDelaySeconds
                ) + 1 && gain.isFinite && gain > 0 && gain < 1
            } &&
            zip(delayFrameCounts, delayFrameCounts.dropFirst()).allSatisfy {
                $0 < $1
            } &&
            dampingCoefficient.isFinite &&
            (0...1).contains(dampingCoefficient) &&
            synthSendGain.isFinite && (0...0.5).contains(synthSendGain) &&
            percussionSendGain.isFinite &&
            (0...0.16).contains(percussionSendGain) &&
            wetGain.isFinite && (0...0.24).contains(wetGain)
    }
}

/// Fixed-capacity continuation for the canonical late spatial tail. Flat
/// storage avoids per-frame allocation and makes the total memory bound
/// explicit to preparation and candidate validation.
package struct FeedbackDelayNetworkState: Equatable, Sendable {
    /// A fixed physical-time slew prevents phrase-owned parameter changes from
    /// becoming a gain, damping, or decay step. It is preparation-time DSP;
    /// the app callback still receives only immutable completed PCM.
    package static let parameterTransitionSeconds = 0.12

    package var storage: [Float] = []
    package var lineOffsets: [Int] = []
    package var lineLengths: [Int] = []
    package var writeIndices: [Int] = []
    package var dampingStates: [Double] = []
    package var routeSampleRate = 0.0
    package var geometryRoomScale = 0.0
    package var appliedFeedbackGains: [Double] = []
    package var targetFeedbackGains: [Double] = []
    package var feedbackGainSteps: [Double] = []
    package var appliedDampingCoefficient = 0.0
    package var targetDampingCoefficient = 0.0
    package var dampingCoefficientStep = 0.0
    package var appliedSynthSendGain = 0.0
    package var targetSynthSendGain = 0.0
    package var synthSendGainStep = 0.0
    package var appliedPercussionSendGain = 0.0
    package var targetPercussionSendGain = 0.0
    package var percussionSendGainStep = 0.0
    package var appliedWetGain = 0.0
    package var targetWetGain = 0.0
    package var wetGainStep = 0.0
    package var parameterTransitionRemainingFrames = 0

    package init() {}

    package mutating func prepare(
        for configuration: FeedbackDelayNetworkConfiguration
    ) {
        _ = resolveConfiguration(for: configuration)
    }

    /// Resolves one active configuration. A valid prepared state at the same
    /// route rate retains its existing delay lengths; only a route-rate change
    /// or invalid/uninitialized state rebuilds zeroed storage.
    package mutating func resolveConfiguration(
        for requested: FeedbackDelayNetworkConfiguration
    ) -> (
        configuration: FeedbackDelayNetworkConfiguration,
        geometryRetained: Bool
    ) {
        guard requested.isBoundedAndStable else {
            self = FeedbackDelayNetworkState()
            return (requested, false)
        }
        let geometryRetained = isPrepared &&
            routeSampleRate == requested.sampleRate
        let activeRoomScale = geometryRetained
            ? geometryRoomScale : requested.roomScale
        let configuration = requested.retainingGeometry(
            roomScale: activeRoomScale
        )
        let lengths = configuration.delayFrameCounts
        let indicesValid = writeIndices.count == Self.lineCount &&
            zip(writeIndices, lengths).allSatisfy { index, length in
                (0..<length).contains(index)
            }
        let expectedStorageCount = lengths.reduce(0, +)
        guard geometryRetained,
              lineLengths == lengths,
              lineOffsets.count == Self.lineCount,
              dampingStates.count == Self.lineCount,
              storage.count == expectedStorageCount,
              indicesValid else {
            var offsets: [Int] = []
            offsets.reserveCapacity(Self.lineCount)
            var offset = 0
            for length in lengths {
                offsets.append(offset)
                offset += length
            }
            storage = [Float](repeating: 0, count: offset)
            lineOffsets = offsets
            lineLengths = lengths
            writeIndices = [Int](repeating: 0, count: Self.lineCount)
            dampingStates = [Double](repeating: 0, count: Self.lineCount)
            routeSampleRate = configuration.sampleRate
            geometryRoomScale = configuration.roomScale
            installParameters(configuration)
            return (configuration, false)
        }
        routeSampleRate = configuration.sampleRate
        geometryRoomScale = configuration.roomScale
        if appliedFeedbackGains.count != Self.lineCount ||
            targetFeedbackGains.count != Self.lineCount ||
            feedbackGainSteps.count != Self.lineCount {
            installParameters(configuration)
        }
        return (configuration, geometryRetained)
    }

    /// Starts one bounded linear transition from the exact currently applied
    /// parameters. Repeating the same target does not restart an in-flight
    /// slew, so block partitioning cannot prolong a boundary transition.
    @discardableResult
    package mutating func beginParameterTransition(
        toward configuration: FeedbackDelayNetworkConfiguration
    ) -> Int {
        guard configuration.isBoundedAndStable, isPrepared else { return 0 }
        if appliedFeedbackGains.count != Self.lineCount ||
            targetFeedbackGains.count != Self.lineCount ||
            feedbackGainSteps.count != Self.lineCount {
            installParameters(configuration)
            return 0
        }
        let targetAlreadyInstalled =
            targetFeedbackGains == configuration.feedbackGains &&
            targetDampingCoefficient == configuration.dampingCoefficient &&
            targetSynthSendGain == configuration.synthSendGain &&
            targetPercussionSendGain == configuration.percussionSendGain &&
            targetWetGain == configuration.wetGain
        guard !targetAlreadyInstalled else {
            return parameterTransitionRemainingFrames
        }
        let frames = max(1, Int((
            configuration.sampleRate * Self.parameterTransitionSeconds
        ).rounded()))
        targetFeedbackGains = configuration.feedbackGains
        feedbackGainSteps = zip(
            configuration.feedbackGains,
            appliedFeedbackGains
        ).map { target, current in
            (target - current) / Double(frames)
        }
        targetDampingCoefficient = configuration.dampingCoefficient
        dampingCoefficientStep = (
            targetDampingCoefficient - appliedDampingCoefficient
        ) / Double(frames)
        targetSynthSendGain = configuration.synthSendGain
        synthSendGainStep = (
            targetSynthSendGain - appliedSynthSendGain
        ) / Double(frames)
        targetPercussionSendGain = configuration.percussionSendGain
        percussionSendGainStep = (
            targetPercussionSendGain - appliedPercussionSendGain
        ) / Double(frames)
        targetWetGain = configuration.wetGain
        wetGainStep = (targetWetGain - appliedWetGain) / Double(frames)
        parameterTransitionRemainingFrames = frames
        return frames
    }

    package mutating func advanceParameterTransition() {
        guard parameterTransitionRemainingFrames > 0 else { return }
        if parameterTransitionRemainingFrames == 1 {
            appliedFeedbackGains = targetFeedbackGains
            appliedDampingCoefficient = targetDampingCoefficient
            appliedSynthSendGain = targetSynthSendGain
            appliedPercussionSendGain = targetPercussionSendGain
            appliedWetGain = targetWetGain
            feedbackGainSteps = [Double](repeating: 0, count: Self.lineCount)
            dampingCoefficientStep = 0
            synthSendGainStep = 0
            percussionSendGainStep = 0
            wetGainStep = 0
            parameterTransitionRemainingFrames = 0
            return
        }
        for line in 0..<Self.lineCount {
            appliedFeedbackGains[line] += feedbackGainSteps[line]
        }
        appliedDampingCoefficient += dampingCoefficientStep
        appliedSynthSendGain += synthSendGainStep
        appliedPercussionSendGain += percussionSendGainStep
        appliedWetGain += wetGainStep
        parameterTransitionRemainingFrames -= 1
    }

    private mutating func installParameters(
        _ configuration: FeedbackDelayNetworkConfiguration
    ) {
        appliedFeedbackGains = configuration.feedbackGains
        targetFeedbackGains = configuration.feedbackGains
        feedbackGainSteps = [Double](repeating: 0, count: Self.lineCount)
        appliedDampingCoefficient = configuration.dampingCoefficient
        targetDampingCoefficient = configuration.dampingCoefficient
        dampingCoefficientStep = 0
        appliedSynthSendGain = configuration.synthSendGain
        targetSynthSendGain = configuration.synthSendGain
        synthSendGainStep = 0
        appliedPercussionSendGain = configuration.percussionSendGain
        targetPercussionSendGain = configuration.percussionSendGain
        percussionSendGainStep = 0
        appliedWetGain = configuration.wetGain
        targetWetGain = configuration.wetGain
        wetGainStep = 0
        parameterTransitionRemainingFrames = 0
    }

    package var isPrepared: Bool {
        lineLengths.count == Self.lineCount &&
            lineOffsets.count == Self.lineCount &&
            writeIndices.count == Self.lineCount &&
            dampingStates.count == Self.lineCount &&
            dampingStates.allSatisfy(\.isFinite) &&
            routeSampleRate.isFinite && routeSampleRate > 0 &&
            geometryRoomScale.isFinite &&
            geometryRoomScale >=
                FeedbackDelayNetworkConfiguration.minimumRoomScale &&
            geometryRoomScale <=
                FeedbackDelayNetworkConfiguration.maximumRoomScale &&
            appliedFeedbackGains.count == Self.lineCount &&
            targetFeedbackGains.count == Self.lineCount &&
            feedbackGainSteps.count == Self.lineCount &&
            appliedFeedbackGains.allSatisfy { $0.isFinite && $0 > 0 && $0 < 1 } &&
            targetFeedbackGains.allSatisfy { $0.isFinite && $0 > 0 && $0 < 1 } &&
            feedbackGainSteps.allSatisfy {
                $0.isFinite && abs($0) <= 1
            } &&
            appliedDampingCoefficient.isFinite &&
            (0...1).contains(appliedDampingCoefficient) &&
            targetDampingCoefficient.isFinite &&
            (0...1).contains(targetDampingCoefficient) &&
            dampingCoefficientStep.isFinite &&
            abs(dampingCoefficientStep) <= 1 &&
            appliedSynthSendGain.isFinite &&
            (0...0.5).contains(appliedSynthSendGain) &&
            targetSynthSendGain.isFinite &&
            (0...0.5).contains(targetSynthSendGain) &&
            synthSendGainStep.isFinite && abs(synthSendGainStep) <= 0.5 &&
            appliedPercussionSendGain.isFinite &&
            (0...0.16).contains(appliedPercussionSendGain) &&
            targetPercussionSendGain.isFinite &&
            (0...0.16).contains(targetPercussionSendGain) &&
            percussionSendGainStep.isFinite &&
            abs(percussionSendGainStep) <= 0.16 &&
            appliedWetGain.isFinite && (0...0.24).contains(appliedWetGain) &&
            targetWetGain.isFinite && (0...0.24).contains(targetWetGain) &&
            wetGainStep.isFinite && abs(wetGainStep) <= 0.24 &&
            parameterTransitionRemainingFrames >= 0 &&
            parameterTransitionRemainingFrames <= Int((
                routeSampleRate * Self.parameterTransitionSeconds
            ).rounded()) + 1 &&
            zip(writeIndices, lineLengths).allSatisfy { index, length in
                length > 0 && (0..<length).contains(index)
            } &&
            zip(lineOffsets, lineLengths).allSatisfy { offset, length in
                offset >= 0 && length > 0 && offset <= storage.count - length
            }
    }

    private static var lineCount: Int {
        FeedbackDelayNetworkConfiguration.lineCount
    }
}

package struct FeedbackDelayNetworkFrame: Equatable, Sendable {
    package let left: Float
    package let right: Float

    package static let silence = FeedbackDelayNetworkFrame(left: 0, right: 0)
}

/// Eight-line late reverberation core. The Householder matrix is orthogonal:
/// it redistributes energy without amplifying it, while delay-proportional
/// gains and damping provide the only recursive loss.
package enum FeedbackDelayNetwork {
    private static let normalization = 1 / sqrt(8.0)
    private static let injectionSigns = [
        1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0,
    ]
    private static let midProjectionSigns = [
        1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0,
    ]
    private static let sideProjectionSigns = [
        1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0,
    ]
    private static let midProjectionGain = sqrt(0.75)
    private static let sideProjectionGain = 0.5

    package static func process(
        input: Float,
        configuration: FeedbackDelayNetworkConfiguration,
        state: inout FeedbackDelayNetworkState,
        scratch: inout [Double]
    ) -> FeedbackDelayNetworkFrame {
        guard input.isFinite, configuration.isBoundedAndStable else {
            return .silence
        }
        let resolved = state.resolveConfiguration(for: configuration)
        let activeConfiguration = resolved.configuration
        state.beginParameterTransition(toward: activeConfiguration)
        guard state.isPrepared else { return .silence }
        if scratch.count != FeedbackDelayNetworkConfiguration.lineCount {
            scratch = [Double](
                repeating: 0,
                count: FeedbackDelayNetworkConfiguration.lineCount
            )
        }

        state.advanceParameterTransition()
        return processPrepared(
            input: input,
            configuration: activeConfiguration,
            state: &state,
            scratch: &scratch
        )
    }

    /// Fast sample path for a configuration and state already validated at the
    /// detached render boundary. Keeping array geometry checks out of this
    /// loop is part of the preparation-time budget; the app callback still
    /// receives only the completed immutable buffer.
    package static func processPrepared(
        input: Float,
        configuration: FeedbackDelayNetworkConfiguration,
        state: inout FeedbackDelayNetworkState,
        scratch: inout [Double]
    ) -> FeedbackDelayNetworkFrame {
        guard input.isFinite else { return .silence }

        var sum = 0.0
        var mid = 0.0
        var side = 0.0
        for line in 0..<FeedbackDelayNetworkConfiguration.lineCount {
            let storageIndex = state.lineOffsets[line] + state.writeIndices[line]
            let delayed = Double(state.storage[storageIndex])
            let damped = state.dampingStates[line] +
                (delayed - state.dampingStates[line]) *
                state.appliedDampingCoefficient
            state.dampingStates[line] = damped
            scratch[line] = damped
            sum += damped
            mid += damped * midProjectionSigns[line]
            side += damped * sideProjectionSigns[line]
        }

        // H(x) = x - (2/N) * sum(x), with N = 8. This is a
        // Householder reflection, so ||H(x)|| == ||x||.
        let common = 0.25 * sum
        let injected = Double(input) * normalization
        for line in 0..<FeedbackDelayNetworkConfiguration.lineCount {
            let mixed = scratch[line] - common
            let write = injected * injectionSigns[line] +
                mixed * state.appliedFeedbackGains[line]
            let storageIndex = state.lineOffsets[line] + state.writeIndices[line]
            state.storage[storageIndex] = write.isFinite ? Float(write) : 0
            let next = state.writeIndices[line] + 1
            state.writeIndices[line] = next == state.lineLengths[line] ? 0 : next
        }

        // Orthogonal mid/side projections use all eight lines. Each channel
        // remains unit-energy, the diffuse mid survives mono summing, and the
        // opposed side preserves width without line-subset rate sensitivity.
        let projectedLeft = (
            mid * midProjectionGain + side * sideProjectionGain
        ) * normalization
        let projectedRight = (
            mid * midProjectionGain - side * sideProjectionGain
        ) * normalization
        guard projectedLeft.isFinite, projectedRight.isFinite else {
            return .silence
        }
        return FeedbackDelayNetworkFrame(
            left: Float(projectedLeft),
            right: Float(projectedRight)
        )
    }
}
