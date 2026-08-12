import AutoTechnoCore
import Foundation

package struct AudioSliceRenderEvidence: Equatable, Sendable {
    package let active: Bool
    package let sourceStartFrame: Int
    package let sourceFrameCount: Int
    package let triggerCount: Int
    package let renderedFrameCount: Int
    package let reverseTriggerCount: Int
    package let minimumPlaybackRate: Double
    package let maximumPlaybackRate: Double
    package let sourceKind: AudioSliceSourceKind?
    package let sourceSampleHash: String
    package let outputSampleHash: String
    package let outputRMS: Double
    package let finite: Bool

    package static let neutral = AudioSliceRenderEvidence(
        active: false,
        sourceStartFrame: -1,
        sourceFrameCount: 0,
        triggerCount: 0,
        renderedFrameCount: 0,
        reverseTriggerCount: 0,
        minimumPlaybackRate: 1,
        maximumPlaybackRate: 1,
        sourceKind: nil,
        sourceSampleHash: "",
        outputSampleHash: "",
        outputRMS: 0,
        finite: true
    )
}

package enum AudioSliceRenderer {
    package static let edgeFadeSeconds = 0.004

    package static func render(
        source: [Float],
        output: inout [Float],
        plan: AudioSlicePlan?,
        stepFrames: Double,
        sampleRate: Double
    ) -> AudioSliceRenderEvidence {
        guard let plan,
              !source.isEmpty,
              source.count == output.count,
              stepFrames.isFinite,
              stepFrames > 0,
              sampleRate.isFinite,
              sampleRate > 0 else {
            return .neutral
        }
        let sourceStart = min(
            source.count - 1,
            max(0, Int((Double(plan.sourceStartStep) * stepFrames).rounded()))
        )
        let requestedCount = max(
            2,
            Int((plan.sourceLengthInSteps * stepFrames).rounded())
        )
        let sourceCount = min(requestedCount, source.count - sourceStart)
        guard sourceCount >= 2 else { return .neutral }
        let sourceEnd = sourceStart + sourceCount
        let sourceWindow = Array(source[sourceStart..<sourceEnd])
        let fadeFrames = max(1, Int((sampleRate * edgeFadeSeconds).rounded()))
        var renderedFrames = 0
        var finite = sourceWindow.allSatisfy(\.isFinite)

        for trigger in plan.triggers {
            let destination = Int((Double(trigger.onsetStep) * stepFrames).rounded())
            guard destination < output.count else { continue }
            let outputCount = max(
                1,
                Int((Double(sourceCount) / trigger.playbackRate).rounded())
            )
            let boundedCount = min(outputCount, output.count - destination)
            for index in 0..<boundedCount {
                let sourcePosition = min(
                    Double(sourceCount - 1),
                    Double(index) * trigger.playbackRate
                )
                let directedPosition = trigger.direction == .forward
                    ? sourcePosition : Double(sourceCount - 1) - sourcePosition
                let lower = min(sourceCount - 1, max(0, Int(floor(directedPosition))))
                let upper = min(sourceCount - 1, lower + 1)
                let fraction = directedPosition - Double(lower)
                let interpolated = Double(sourceWindow[lower]) +
                    (Double(sourceWindow[upper]) - Double(sourceWindow[lower])) * fraction
                let fadeIn = min(1, Double(index + 1) / Double(fadeFrames))
                let fadeOut = min(1, Double(boundedCount - index) / Double(fadeFrames))
                let window = min(fadeIn, fadeOut)
                let sample = Float(interpolated * trigger.gain * window)
                output[destination + index] += sample
                finite = finite && sample.isFinite
                renderedFrames += 1
            }
        }
        let energy = output.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rates = plan.triggers.map(\.playbackRate)
        return AudioSliceRenderEvidence(
            active: renderedFrames > 0,
            sourceStartFrame: sourceStart,
            sourceFrameCount: sourceCount,
            triggerCount: plan.triggers.count,
            renderedFrameCount: renderedFrames,
            reverseTriggerCount: plan.triggers.filter {
                $0.direction == .reverse
            }.count,
            minimumPlaybackRate: rates.min() ?? 1,
            maximumPlaybackRate: rates.max() ?? 1,
            sourceKind: plan.sourceKind,
            sourceSampleHash: ExactPCMFingerprint.mono(sourceWindow),
            outputSampleHash: ExactPCMFingerprint.mono(output),
            outputRMS: sqrt(energy / Double(max(1, output.count))),
            finite: finite && energy.isFinite
        )
    }
}

package struct PolyphonicPadRenderEvidence: Equatable, Sendable {
    package let active: Bool
    package let voiceCount: Int
    package let renderedFrameCount: Int
    package let requestedFrequencyRatios: [Double]
    package let outputSampleHash: String
    package let outputRMS: Double
    package let outputPeak: Double
    package let finite: Bool

    package static let neutral = PolyphonicPadRenderEvidence(
        active: false,
        voiceCount: 0,
        renderedFrameCount: 0,
        requestedFrequencyRatios: [],
        outputSampleHash: "",
        outputRMS: 0,
        outputPeak: 0,
        finite: true
    )
}

struct PolyphonicPadState: Equatable, Sendable {
    var phases = [Double](repeating: 0, count: PadVoicing.voiceCount)
    var lowPass = [Double](repeating: 0, count: PadVoicing.voiceCount)
    var envelope = [Double](repeating: 0, count: PadVoicing.voiceCount)

    mutating func reset() {
        self = PolyphonicPadState()
    }
}

/// A fixed four-voice tonal pad. All storage and voice count are bounded, and
/// it runs only during detached phrase preparation.
enum PolyphonicPadVoice {
    static func render(
        _ output: inout [Float],
        measurement: inout [Float],
        spatialReverbSend: inout [Float],
        voicing: PadVoicing?,
        rootFrequency: Double,
        sampleRate: Double,
        stepFrames: Double,
        level: Double,
        state: inout PolyphonicPadState
    ) -> PolyphonicPadRenderEvidence {
        guard let voicing,
              voicing.voices.count == PadVoicing.voiceCount,
              !output.isEmpty,
              output.count == measurement.count,
              output.count == spatialReverbSend.count,
              sampleRate.isFinite,
              sampleRate > 0 else {
            return .neutral
        }
        if state.phases.count != PadVoicing.voiceCount ||
            state.lowPass.count != PadVoicing.voiceCount ||
            state.envelope.count != PadVoicing.voiceCount {
            state.reset()
        }
        let start = min(
            output.count - 1,
            max(0, Int((Double(voicing.onsetStep) * stepFrames).rounded()))
        )
        let frames = min(
            output.count - start,
            max(1, Int((voicing.durationInSteps * stepFrames).rounded()))
        )
        let attackFrames = max(1, Int((sampleRate * 0.42).rounded()))
        let releaseFrames = max(1, Int((sampleRate * 0.65).rounded()))
        let automation = voicing.instrument.automation
        let cutoff = min(
            sampleRate * 0.16,
            520 + automation.color * 2_800
        )
        let coefficient = min(0.36, 1 - exp(-2 * .pi * cutoff / sampleRate))
        let detune = [0.9974, 1.0011, 0.9987, 1.0026]
        let pans = [-0.38, -0.12, 0.14, 0.40]
        var energy = 0.0
        var peak = 0.0
        var finite = rootFrequency.isFinite && level.isFinite
        for index in 0..<frames {
            let attack = min(1, Double(index + 1) / Double(attackFrames))
            let release = min(1, Double(frames - index) / Double(releaseFrames))
            let boundaryEnvelope = min(attack, release)
            var mixed = 0.0
            var spatial = 0.0
            for voiceIndex in 0..<PadVoicing.voiceCount {
                let frequency = min(
                    sampleRate * 0.18,
                    max(28, rootFrequency *
                        voicing.voices[voiceIndex].frequencyRatio * detune[voiceIndex])
                )
                state.phases[voiceIndex] = wrap(
                    state.phases[voiceIndex] + frequency / sampleRate
                )
                let phase = state.phases[voiceIndex]
                let triangle = 4 * abs(phase - 0.5) - 1
                let sine = sin(2 * .pi * phase)
                let source = triangle * 0.52 + sine * 0.48
                state.lowPass[voiceIndex] +=
                    (source - state.lowPass[voiceIndex]) * coefficient
                state.envelope[voiceIndex] +=
                    (boundaryEnvelope - state.envelope[voiceIndex]) * 0.006
                let voice = state.lowPass[voiceIndex] * state.envelope[voiceIndex] *
                    (0.82 + automation.motion * 0.18)
                mixed += voice * (0.25 - Double(voiceIndex) * 0.018)
                spatial += voice * pans[voiceIndex]
            }
            let driven = tanh(mixed * (1.08 + automation.shape * 0.32))
            let sample = Float(driven * max(0, level))
            let frame = start + index
            output[frame] += sample
            measurement[frame] += sample
            spatialReverbSend[frame] += Float(
                (mixed * 0.72 + spatial * 0.12) *
                    min(0.48, 0.16 + automation.space * 0.32) * max(0, level)
            )
            let value = Double(sample)
            energy += value * value
            peak = max(peak, abs(value))
            finite = finite && sample.isFinite &&
                spatialReverbSend[frame].isFinite
        }
        return PolyphonicPadRenderEvidence(
            active: frames > 0,
            voiceCount: voicing.voices.count,
            renderedFrameCount: frames,
            requestedFrequencyRatios: voicing.voices.map(\.frequencyRatio),
            outputSampleHash: ExactPCMFingerprint.mono(measurement),
            outputRMS: sqrt(energy / Double(max(1, frames))),
            outputPeak: peak,
            finite: finite && energy.isFinite && peak.isFinite
        )
    }

    private static func wrap(_ phase: Double) -> Double {
        let result = phase.truncatingRemainder(dividingBy: 1)
        return result < 0 ? result + 1 : result
    }
}
