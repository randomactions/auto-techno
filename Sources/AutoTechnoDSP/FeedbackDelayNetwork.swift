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
    package var storage: [Float] = []
    package var lineOffsets: [Int] = []
    package var lineLengths: [Int] = []
    package var writeIndices: [Int] = []
    package var dampingStates: [Double] = []

    package init() {}

    package mutating func prepare(
        for configuration: FeedbackDelayNetworkConfiguration
    ) {
        guard configuration.isBoundedAndStable else {
            self = FeedbackDelayNetworkState()
            return
        }
        let lengths = configuration.delayFrameCounts
        let indicesValid = writeIndices.count == Self.lineCount &&
            zip(writeIndices, lengths).allSatisfy { index, length in
                (0..<length).contains(index)
            }
        let expectedStorageCount = lengths.reduce(0, +)
        guard lineLengths == lengths,
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
            return
        }
    }

    package var isPrepared: Bool {
        lineLengths.count == Self.lineCount &&
            lineOffsets.count == Self.lineCount &&
            writeIndices.count == Self.lineCount &&
            dampingStates.count == Self.lineCount &&
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
        if state.lineLengths != configuration.delayFrameCounts ||
            !state.isPrepared {
            state.prepare(for: configuration)
        }
        guard state.isPrepared else { return .silence }
        if scratch.count != FeedbackDelayNetworkConfiguration.lineCount {
            scratch = [Double](
                repeating: 0,
                count: FeedbackDelayNetworkConfiguration.lineCount
            )
        }

        return processPrepared(
            input: input,
            configuration: configuration,
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
                configuration.dampingCoefficient
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
                mixed * configuration.feedbackGains[line]
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
