@testable import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Canonical feedback delay network")
struct FeedbackDelayNetworkTests {
    @Test("Identity return lowers only the audible field at a score boundary")
    func identityReturnScale() {
        let scene = TechnoScene(
            intent: MusicalIntent(values: [
                .atmosphere: 0.52,
                .atmosphericDarkness: 0.72,
                .hypnosis: 0.78,
                .drone: 0.34,
            ]),
            seed: 48_291,
            bpm: AutonomousSessionDirector.bpm
        )
        let ordinary = FeedbackDelayNetworkConfiguration(
            scene: scene,
            sampleRate: 48_000,
            phraseKind: .lock
        )
        let identityReturn = FeedbackDelayNetworkConfiguration(
            scene: scene,
            sampleRate: 48_000,
            phraseKind: .identityReturn
        )

        #expect(identityReturn.delayFrameCounts == ordinary.delayFrameCounts)
        #expect(identityReturn.feedbackGains == ordinary.feedbackGains)
        #expect(identityReturn.roomScale == ordinary.roomScale)
        #expect(identityReturn.decayTimeSeconds == ordinary.decayTimeSeconds)
        #expect(identityReturn.dampingHz == ordinary.dampingHz)
        #expect(identityReturn.synthSendGain == ordinary.synthSendGain)
        #expect(identityReturn.percussionSendGain == ordinary.percussionSendGain)
        #expect(identityReturn.wetGain == ordinary.wetGain * 0.45)
        #expect(ordinary.isBoundedAndStable)
        #expect(identityReturn.isBoundedAndStable)
    }

    @Test("Configuration is route-normalized, ordered, and strictly stable")
    func configurationBounds() {
        for sampleRate in [8_000.0, 44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            let configuration = FeedbackDelayNetworkConfiguration(
                sampleRate: sampleRate,
                roomScale: 100,
                decayTimeSeconds: 100,
                dampingHz: 100_000
            )
            #expect(configuration.isBoundedAndStable)
            #expect(configuration.roomScale ==
                    FeedbackDelayNetworkConfiguration.maximumRoomScale)
            #expect(configuration.decayTimeSeconds ==
                    FeedbackDelayNetworkConfiguration.maximumDecayTimeSeconds)
            #expect(configuration.delayFrameCounts.count == 8)
            #expect(zip(
                configuration.delayFrameCounts,
                configuration.delayFrameCounts.dropFirst()
            ).allSatisfy { $0 < $1 })
            #expect(configuration.delayFrameCounts.allSatisfy { !$0.isMultiple(of: 2) })
            #expect(configuration.maximumFeedbackGain > 0)
            #expect(configuration.maximumFeedbackGain < 1)

            var state = FeedbackDelayNetworkState()
            state.prepare(for: configuration)
            #expect(state.isPrepared)
            #expect(state.lineLengths == configuration.delayFrameCounts)
            #expect(state.storage.count ==
                    configuration.delayFrameCounts.reduce(0, +))
            #expect(state.storage.count <= Int(
                sampleRate * FeedbackDelayNetworkConfiguration.maximumDelaySeconds
            ) * FeedbackDelayNetworkConfiguration.lineCount + 8)
        }
    }

    @Test("Impulse response is deterministic, diffuse, stereo, and decaying")
    func impulseResponse() {
        let sampleRate = 8_000.0
        let configuration = FeedbackDelayNetworkConfiguration(
            sampleRate: sampleRate,
            roomScale: 1,
            decayTimeSeconds: 1.5,
            dampingHz: 2_600,
            wetGain: 1
        )
        let first = renderImpulse(
            configuration: configuration,
            frameCount: Int(sampleRate * 4)
        )
        let replay = renderImpulse(
            configuration: configuration,
            frameCount: Int(sampleRate * 4)
        )
        #expect(first.left == replay.left)
        #expect(first.right == replay.right)
        #expect(first.left.allSatisfy { $0.isFinite })
        #expect(first.right.allSatisfy { $0.isFinite })

        let firstWetFrame = firstActiveFrame(first)
        #expect(firstWetFrame == configuration.delayFrameCounts.min())
        let denseStart = Int(sampleRate * 0.55)
        let denseEnd = Int(sampleRate * 0.85)
        let denseActive = zip(
            first.left[denseStart..<denseEnd],
            first.right[denseStart..<denseEnd]
        ).filter { $0.bitPattern != 0 || $1.bitPattern != 0 }.count
        #expect(denseActive > (denseEnd - denseStart) * 3 / 4)

        let earlyEnergy = stereoEnergy(
            first,
            range: Int(sampleRate * 0.30)..<Int(sampleRate * 1.0)
        )
        let lateEnergy = stereoEnergy(
            first,
            range: Int(sampleRate * 3.0)..<Int(sampleRate * 3.7)
        )
        #expect(earlyEnergy > 0)
        #expect(lateEnergy > 0)
        #expect(lateEnergy < earlyEnergy * 0.12)

        let correlation = stereoCorrelation(first)
        #expect(abs(correlation) < 0.92)
        #expect(zip(first.left, first.right).reduce(0.0) {
            max($0, abs(Double($1.0)), abs(Double($1.1)))
        } < 1.5)
    }

    @Test("Delay geometry preserves physical onset across production rates")
    func rateNormalizedGeometry() {
        var onsetSeconds: [Double] = []
        for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
            let configuration = FeedbackDelayNetworkConfiguration(
                sampleRate: sampleRate,
                roomScale: 1.08,
                decayTimeSeconds: 2.8,
                dampingHz: 3_400
            )
            let render = renderImpulse(
                configuration: configuration,
                frameCount: Int(sampleRate * 0.25)
            )
            let onset = firstActiveFrame(render) ?? -1
            #expect(onset == configuration.delayFrameCounts.min())
            onsetSeconds.append(Double(onset) / sampleRate)
        }
        #expect((onsetSeconds.max() ?? 0) - (onsetSeconds.min() ?? 0) < 0.000_03)
    }

    @Test("Continuation holds, route geometry resets, and invalid input is neutral")
    func continuationAndFallback() {
        let firstConfiguration = FeedbackDelayNetworkConfiguration(
            sampleRate: 8_000,
            roomScale: 1,
            decayTimeSeconds: 2,
            dampingHz: 2_400
        )
        var state = FeedbackDelayNetworkState()
        var scratch: [Double] = []
        _ = FeedbackDelayNetwork.process(
            input: 1,
            configuration: firstConfiguration,
            state: &state,
            scratch: &scratch
        )
        for _ in 0...(firstConfiguration.delayFrameCounts.min() ?? 1) {
            _ = FeedbackDelayNetwork.process(
                input: 0,
                configuration: firstConfiguration,
                state: &state,
                scratch: &scratch
            )
        }
        #expect(state.storage.contains { $0 != 0 })
        let continuation = state
        var replayState = continuation
        var replayScratch = scratch
        let continued = FeedbackDelayNetwork.process(
            input: 0,
            configuration: firstConfiguration,
            state: &state,
            scratch: &scratch
        )
        let replayed = FeedbackDelayNetwork.process(
            input: 0,
            configuration: firstConfiguration,
            state: &replayState,
            scratch: &replayScratch
        )
        #expect(continued == replayed)
        #expect(state == replayState)

        let changedRoute = FeedbackDelayNetworkConfiguration(
            sampleRate: 48_000,
            roomScale: 1,
            decayTimeSeconds: 2,
            dampingHz: 2_400
        )
        let resetFrame = FeedbackDelayNetwork.process(
            input: 0,
            configuration: changedRoute,
            state: &state,
            scratch: &scratch
        )
        #expect(resetFrame == .silence)
        #expect(state.lineLengths == changedRoute.delayFrameCounts)
        #expect(state.storage.allSatisfy { $0 == 0 })

        let beforeInvalid = state
        let invalid = FeedbackDelayNetwork.process(
            input: .nan,
            configuration: changedRoute,
            state: &state,
            scratch: &scratch
        )
        #expect(invalid == .silence)
        #expect(state == beforeInvalid)
    }

    @Test("Musical changes retain geometry and slew the recursive field")
    func musicalBoundaryRetainsGeometryAndSlews() {
        let sampleRate = 8_000.0
        let first = FeedbackDelayNetworkConfiguration(
            sampleRate: sampleRate,
            roomScale: 0.82,
            decayTimeSeconds: 1.4,
            dampingHz: 1_500,
            synthSendGain: 0.2,
            percussionSendGain: 0.02,
            wetGain: 0.04
        )
        let requestedNext = FeedbackDelayNetworkConfiguration(
            sampleRate: sampleRate,
            roomScale: 1.22,
            decayTimeSeconds: 5.2,
            dampingHz: 3_500,
            synthSendGain: 0.48,
            percussionSendGain: 0.14,
            wetGain: 0.22
        )
        var state = FeedbackDelayNetworkState()
        var scratch: [Double] = []
        _ = FeedbackDelayNetwork.process(
            input: 1,
            configuration: first,
            state: &state,
            scratch: &scratch
        )
        for _ in 0...1_200 {
            _ = FeedbackDelayNetwork.process(
                input: 0,
                configuration: first,
                state: &state,
                scratch: &scratch
            )
        }
        #expect(state.storage.contains { $0 != 0 })
        let storageBeforeBoundary = state.storage
        let lineLengthsBeforeBoundary = state.lineLengths
        let oldWet = state.appliedWetGain
        let oldFeedback = state.appliedFeedbackGains

        let resolved = state.resolveConfiguration(for: requestedNext)
        #expect(resolved.geometryRetained)
        #expect(resolved.configuration.roomScale == first.roomScale)
        #expect(state.lineLengths == lineLengthsBeforeBoundary)
        #expect(state.storage == storageBeforeBoundary)
        let transitionFrames = state.beginParameterTransition(
            toward: resolved.configuration
        )
        #expect(transitionFrames == Int((
            sampleRate * FeedbackDelayNetworkState.parameterTransitionSeconds
        ).rounded()))
        #expect(state.appliedWetGain == oldWet)
        #expect(state.appliedFeedbackGains == oldFeedback)

        state.advanceParameterTransition()
        #expect(state.appliedWetGain > oldWet)
        #expect(state.appliedWetGain < resolved.configuration.wetGain)
        #expect(state.appliedFeedbackGains != oldFeedback)
        #expect(state.appliedFeedbackGains != resolved.configuration.feedbackGains)
        for _ in 1..<transitionFrames {
            state.advanceParameterTransition()
        }
        #expect(state.parameterTransitionRemainingFrames == 0)
        #expect(state.appliedFeedbackGains == resolved.configuration.feedbackGains)
        #expect(state.appliedDampingCoefficient ==
                resolved.configuration.dampingCoefficient)
        #expect(state.appliedSynthSendGain ==
                resolved.configuration.synthSendGain)
        #expect(state.appliedPercussionSendGain ==
                resolved.configuration.percussionSendGain)
        #expect(state.appliedWetGain == resolved.configuration.wetGain)
        #expect(state.lineLengths == lineLengthsBeforeBoundary)
        #expect(state.storage == storageBeforeBoundary)
        #expect(state.isPrepared)
    }

    @Test("Invalid continuation rebuilds the requested route and clears storage")
    func invalidContinuationFallsBackToFreshGeometry() {
        let sampleRate = 8_000.0
        let first = FeedbackDelayNetworkConfiguration(
            sampleRate: sampleRate,
            roomScale: 0.82,
            decayTimeSeconds: 2,
            dampingHz: 2_400
        )
        let requested = FeedbackDelayNetworkConfiguration(
            sampleRate: sampleRate,
            roomScale: 1.22,
            decayTimeSeconds: 3.8,
            dampingHz: 3_200,
            wetGain: 0.18
        )
        var state = FeedbackDelayNetworkState()
        state.prepare(for: first)
        state.storage[0] = 0.5
        state.dampingStates[0] = .nan
        #expect(!state.isPrepared)

        let resolved = state.resolveConfiguration(for: requested)

        #expect(!resolved.geometryRetained)
        #expect(resolved.configuration == requested)
        #expect(state.isPrepared)
        #expect(state.routeSampleRate == sampleRate)
        #expect(state.geometryRoomScale == requested.roomScale)
        #expect(state.lineLengths == requested.delayFrameCounts)
        #expect(state.storage.allSatisfy { $0 == 0 })
        #expect(state.dampingStates.allSatisfy { $0 == 0 })
        #expect(state.appliedWetGain == requested.wetGain)
    }

    private func renderImpulse(
        configuration: FeedbackDelayNetworkConfiguration,
        frameCount: Int
    ) -> (left: [Float], right: [Float]) {
        var state = FeedbackDelayNetworkState()
        var scratch: [Double] = []
        var left: [Float] = []
        var right: [Float] = []
        left.reserveCapacity(frameCount)
        right.reserveCapacity(frameCount)
        for frame in 0..<frameCount {
            let output = FeedbackDelayNetwork.process(
                input: frame == 0 ? 1 : 0,
                configuration: configuration,
                state: &state,
                scratch: &scratch
            )
            left.append(output.left)
            right.append(output.right)
        }
        return (left, right)
    }

    private func stereoEnergy(
        _ samples: (left: [Float], right: [Float]),
        range: Range<Int>
    ) -> Double {
        zip(samples.left[range], samples.right[range]).reduce(0) {
            $0 + Double($1.0 * $1.0 + $1.1 * $1.1)
        }
    }

    private func stereoCorrelation(
        _ samples: (left: [Float], right: [Float])
    ) -> Double {
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        var cross = 0.0
        for (left, right) in zip(samples.left, samples.right) {
            leftEnergy += Double(left * left)
            rightEnergy += Double(right * right)
            cross += Double(left * right)
        }
        return cross / sqrt(max(0.000_000_000_001, leftEnergy * rightEnergy))
    }

    private func firstActiveFrame(
        _ samples: (left: [Float], right: [Float])
    ) -> Int? {
        for index in 0..<min(samples.left.count, samples.right.count) {
            if samples.left[index].bitPattern != 0 ||
                samples.right[index].bitPattern != 0 {
                return index
            }
        }
        return nil
    }
}
