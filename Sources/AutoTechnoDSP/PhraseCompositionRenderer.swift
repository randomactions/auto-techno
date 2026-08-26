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
    package let texture: AudioSliceTexture?
    package let textureSeedFingerprint: String
    package let grainCount: Int
    package let grainLengthFrames: Int
    package let grainHopFrames: Int
    package let grainSourcePositionHash: String
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
        texture: nil,
        textureSeedFingerprint: "",
        grainCount: 0,
        grainLengthFrames: 0,
        grainHopFrames: 0,
        grainSourcePositionHash: "",
        sourceSampleHash: "",
        outputSampleHash: "",
        outputRMS: 0,
        finite: true
    )
}

package enum AudioSliceRenderer {
    package static let edgeFadeSeconds = 0.004
    package static let granularLengthInSteps = 0.375
    package static let maximumGrainsPerTrigger = 48

    package static func textureSeedFingerprint(_ seed: UInt64) -> String {
        var sink = StreamingFNV1a()
        sink.domain("audio-slice-texture-seed.typed.v1")
        sink.uint64(seed)
        return fixedWidthFingerprintHex(sink.value)
    }

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
        var grainCount = 0
        var grainLengthFrames = 0
        var grainHopFrames = 0
        var grainPositionSink = StreamingFNV1a()
        if plan.texture == .granularMemory {
            grainPositionSink.domain("audio-slice-grain-positions.typed.v1")
            grainPositionSink.uint64(plan.textureSeed)
        }

        for (triggerIndex, trigger) in plan.triggers.enumerated() {
            let destination = Int((Double(trigger.onsetStep) * stepFrames).rounded())
            guard destination < output.count else { continue }
            let outputCount = max(
                1,
                Int((Double(sourceCount) / trigger.playbackRate).rounded())
            )
            let boundedCount = min(outputCount, output.count - destination)
            switch plan.texture {
            case .cut:
                for index in 0..<boundedCount {
                    let sourcePosition = min(
                        Double(sourceCount - 1),
                        Double(index) * trigger.playbackRate
                    )
                    let directedPosition = trigger.direction == .forward
                        ? sourcePosition : Double(sourceCount - 1) - sourcePosition
                    let interpolated = BandLimitedInterpolator.sample(
                        sourceWindow,
                        at: directedPosition,
                        playbackRate: trigger.playbackRate
                    )
                    let fadeIn = min(1, Double(index + 1) / Double(fadeFrames))
                    let fadeOut = min(1, Double(boundedCount - index) / Double(fadeFrames))
                    let window = min(fadeIn, fadeOut)
                    let sample = Float(interpolated * trigger.gain * window)
                    output[destination + index] += sample
                    finite = finite && sample.isFinite
                    renderedFrames += 1
                }
            case .granularMemory:
                let resolvedLength = min(
                    boundedCount,
                    sourceCount,
                    max(8, Int((stepFrames * granularLengthInSteps).rounded()))
                )
                guard resolvedLength >= 2 else { continue }
                let hop = max(1, resolvedLength / 2)
                grainLengthFrames = resolvedLength
                grainHopFrames = hop
                var grainOutputStart = 0
                var triggerGrainCount = 0
                while grainOutputStart < boundedCount &&
                        triggerGrainCount < maximumGrainsPerTrigger {
                    let grainFrames = min(
                        resolvedLength,
                        boundedCount - grainOutputStart
                    )
                    let sourceSpan = min(
                        sourceCount,
                        max(2, Int((Double(grainFrames) *
                            trigger.playbackRate).rounded(.up)))
                    )
                    let maximumSourceStart = max(0, sourceCount - sourceSpan)
                    let entropy = SceneDNA.derivedSeed(
                        scene: plan.textureSeed,
                        domain: UInt64(triggerIndex + 1),
                        index: triggerGrainCount
                    )
                    let grainSourceStart = maximumSourceStart == 0 ? 0 :
                        Int(entropy % UInt64(maximumSourceStart + 1))
                    grainPositionSink.int(triggerIndex)
                    grainPositionSink.int(triggerGrainCount)
                    grainPositionSink.int(grainSourceStart)
                    for grainIndex in 0..<grainFrames {
                        let localPosition = min(
                            Double(sourceSpan - 1),
                            Double(grainIndex) * trigger.playbackRate
                        )
                        let forwardPosition = min(
                            Double(sourceCount - 1),
                            Double(grainSourceStart) + localPosition
                        )
                        let directedPosition = trigger.direction == .forward
                            ? forwardPosition
                            : Double(sourceCount - 1) - forwardPosition
                        let interpolated = BandLimitedInterpolator.sample(
                            sourceWindow,
                            at: directedPosition,
                            playbackRate: trigger.playbackRate
                        )
                        let outputIndex = grainOutputStart + grainIndex
                        let fadeIn = min(
                            1,
                            Double(outputIndex + 1) / Double(fadeFrames)
                        )
                        let fadeOut = min(
                            1,
                            Double(boundedCount - outputIndex) /
                                Double(fadeFrames)
                        )
                        let phase = Double(grainIndex) + 0.5
                        let hann = pow(sin(.pi * phase /
                            Double(resolvedLength)), 2)
                        let sample = Float(
                            interpolated * trigger.gain * hann *
                                min(fadeIn, fadeOut)
                        )
                        output[destination + outputIndex] += sample
                        finite = finite && sample.isFinite
                    }
                    grainCount += 1
                    triggerGrainCount += 1
                    grainOutputStart += hop
                }
                if triggerGrainCount > 0 { renderedFrames += boundedCount }
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
            texture: plan.texture,
            textureSeedFingerprint: plan.texture == .granularMemory
                ? textureSeedFingerprint(plan.textureSeed) : "",
            grainCount: grainCount,
            grainLengthFrames: grainLengthFrames,
            grainHopFrames: grainHopFrames,
            grainSourcePositionHash: plan.texture == .granularMemory &&
                grainCount > 0 ? fixedWidthFingerprintHex(
                    grainPositionSink.value
                ) : "",
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
    package let rhythmicModulationRelation: PadRhythmicModulationRelation
    package let rhythmicModulationPhaseOffset: Int
    package let rhythmicModulationPatternFingerprint: String
    package let minimumFilterScale: Double
    package let maximumFilterScale: Double
    package let minimumSpatialSendScale: Double
    package let maximumSpatialSendScale: Double
    package let minimumAmplitudeGateGain: Double
    package let maximumAmplitudeGateGain: Double
    package let amplitudeGateTransitionFrameCount: Int
    package let amplitudeGateOpenFrameCount: Int
    package let amplitudeGateClosedFrameCount: Int
    package let preAmplitudeGateOutputSampleHash: String
    package let preAmplitudeGateSpatialSendSampleHash: String
    package let amplitudeGateDifferenceRMS: Double
    package let spatialAmplitudeGateDifferenceRMS: Double
    package let amplitudeGateClosedOutputRMS: Double
    package let amplitudeGateClosedSpatialSendRMS: Double
    package let filterModulationDifferenceRMS: Double
    package let spatialSendDifferenceRMS: Double
    package let spatialSendSampleHash: String
    package let spatialSendRMS: Double
    package let outputSampleHash: String
    package let outputRMS: Double
    package let outputPeak: Double
    package let finite: Bool

    package static let neutral = PolyphonicPadRenderEvidence(
        active: false,
        voiceCount: 0,
        renderedFrameCount: 0,
        requestedFrequencyRatios: [],
        rhythmicModulationRelation: .neutral,
        rhythmicModulationPhaseOffset: 0,
        rhythmicModulationPatternFingerprint: "",
        minimumFilterScale: 1,
        maximumFilterScale: 1,
        minimumSpatialSendScale: 1,
        maximumSpatialSendScale: 1,
        minimumAmplitudeGateGain: 1,
        maximumAmplitudeGateGain: 1,
        amplitudeGateTransitionFrameCount: 0,
        amplitudeGateOpenFrameCount: 0,
        amplitudeGateClosedFrameCount: 0,
        preAmplitudeGateOutputSampleHash: "",
        preAmplitudeGateSpatialSendSampleHash: "",
        amplitudeGateDifferenceRMS: 0,
        spatialAmplitudeGateDifferenceRMS: 0,
        amplitudeGateClosedOutputRMS: 0,
        amplitudeGateClosedSpatialSendRMS: 0,
        filterModulationDifferenceRMS: 0,
        spatialSendDifferenceRMS: 0,
        spatialSendSampleHash: "",
        spatialSendRMS: 0,
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
    static let amplitudeGateTransitionSeconds = 0.006

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
        let modulation = voicing.rhythmicModulation
        let patternFingerprint = PadRhythmicModulationFingerprint.make(modulation)
        let filterScales = (0..<PadRhythmicModulation.stepCount).map {
            modulation.filterScale(atStep: $0)
        }
        let spatialScales = (0..<PadRhythmicModulation.stepCount).map {
            modulation.spatialSendScale(atStep: $0)
        }
        let minimumFilterScale = filterScales.min() ?? 1
        let maximumFilterScale = filterScales.max() ?? 1
        let minimumSpatialSendScale = spatialScales.min() ?? 1
        let maximumSpatialSendScale = spatialScales.max() ?? 1
        let amplitudeGateTargets = (0..<PadRhythmicModulation.stepCount).map {
            modulation.amplitudeGateTarget(atStep: $0)
        }
        let minimumAmplitudeGateGain = amplitudeGateTargets.min() ?? 1
        let maximumAmplitudeGateGain = amplitudeGateTargets.max() ?? 1
        let amplitudeGateTransitionFrameCount = modulation.active
            ? max(2, Int((
                sampleRate * amplitudeGateTransitionSeconds
            ).rounded())) : 0
        var neutralLowPass = state.lowPass
        var filterDifferenceEnergy = 0.0
        var spatialDifferenceEnergy = 0.0
        var amplitudeGateDifferenceEnergy = 0.0
        var spatialAmplitudeGateDifferenceEnergy = 0.0
        var amplitudeGateClosedOutputEnergy = 0.0
        var amplitudeGateClosedSpatialSendEnergy = 0.0
        var amplitudeGateOpenFrameCount = 0
        var amplitudeGateClosedFrameCount = 0
        var spatialEnergy = 0.0
        var preGateOutputFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var preGateSpatialFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var spatialFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        let detune = [0.9974, 1.0011, 0.9987, 1.0026]
        let pans = [-0.38, -0.12, 0.14, 0.40]
        var energy = 0.0
        var peak = 0.0
        var finite = rootFrequency.isFinite && level.isFinite
        for index in 0..<frames {
            let relativeStep = min(
                PadRhythmicModulation.stepCount - 1,
                max(0, Int(Double(index) / stepFrames))
            )
            let localStep = min(
                PadRhythmicModulation.stepCount - 1,
                max(0, voicing.onsetStep + relativeStep)
            )
            let filterScale = modulation.filterScale(atStep: localStep)
            let spatialSendScale = modulation.spatialSendScale(atStep: localStep)
            let amplitudeGateTarget = modulation.amplitudeGateTarget(
                atStep: localStep
            )
            let amplitudeGateGain = modulation.active
                ? rhythmicAmplitudeGateGain(
                    frame: index,
                    step: relativeStep,
                    totalFrameCount: frames,
                    stepFrames: stepFrames,
                    transitionFrameCount: amplitudeGateTransitionFrameCount,
                    target: amplitudeGateTarget
                ) : 1
            if modulation.active {
                if amplitudeGateTarget == 1 {
                    amplitudeGateOpenFrameCount += 1
                } else {
                    amplitudeGateClosedFrameCount += 1
                }
            }
            let appliedCoefficient = modulation.active
                ? min(0.36, 1 - exp(
                    -2 * .pi * cutoff * filterScale / sampleRate
                ))
                : coefficient
            let attack = min(1, Double(index + 1) / Double(attackFrames))
            let release = min(1, Double(frames - index) / Double(releaseFrames))
            let boundaryEnvelope = min(attack, release)
            var mixed = 0.0
            var spatial = 0.0
            var neutralMixed = 0.0
            var neutralSpatial = 0.0
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
                    (source - state.lowPass[voiceIndex]) * appliedCoefficient
                if modulation.active {
                    neutralLowPass[voiceIndex] +=
                        (source - neutralLowPass[voiceIndex]) * coefficient
                }
                state.envelope[voiceIndex] +=
                    (boundaryEnvelope - state.envelope[voiceIndex]) * 0.006
                let voice = state.lowPass[voiceIndex] * state.envelope[voiceIndex] *
                    (0.82 + automation.motion * 0.18)
                mixed += voice * (0.25 - Double(voiceIndex) * 0.018)
                spatial += voice * pans[voiceIndex]
                if modulation.active {
                    let neutralVoice = neutralLowPass[voiceIndex] *
                        state.envelope[voiceIndex] *
                        (0.82 + automation.motion * 0.18)
                    neutralMixed += neutralVoice *
                        (0.25 - Double(voiceIndex) * 0.018)
                    neutralSpatial += neutralVoice * pans[voiceIndex]
                }
            }
            let driven = tanh(mixed * (1.08 + automation.shape * 0.32))
            let preGateSample = Float(driven * max(0, level))
            preGateOutputFingerprint.append(preGateSample)
            let sample = modulation.active
                ? Float(Double(preGateSample) * amplitudeGateGain)
                : preGateSample
            if modulation.active {
                let neutralDriven = tanh(
                    neutralMixed * (1.08 + automation.shape * 0.32)
                )
                let difference = Double(preGateSample) -
                    Double(Float(neutralDriven * max(0, level)))
                filterDifferenceEnergy += difference * difference
                let gateDifference = Double(sample) - Double(preGateSample)
                amplitudeGateDifferenceEnergy += gateDifference * gateDifference
            }
            let frame = start + index
            output[frame] += sample
            measurement[frame] += sample
            let neutralSpatialSend = (mixed * 0.72 + spatial * 0.12) *
                min(0.48, 0.16 + automation.space * 0.32) * max(0, level)
            let preGatePadSpatialSend = Float(
                neutralSpatialSend * spatialSendScale
            )
            preGateSpatialFingerprint.append(preGatePadSpatialSend)
            let padSpatialSend = modulation.active
                ? Float(Double(preGatePadSpatialSend) * amplitudeGateGain)
                : preGatePadSpatialSend
            spatialReverbSend[frame] += padSpatialSend
            spatialFingerprint.append(padSpatialSend)
            let spatialValue = Double(padSpatialSend)
            spatialEnergy += spatialValue * spatialValue
            let neutralReferenceSend = modulation.active
                ? (neutralMixed * 0.72 + neutralSpatial * 0.12) *
                    min(0.48, 0.16 + automation.space * 0.32) * max(0, level)
                : neutralSpatialSend
            let spatialDifference = Double(preGatePadSpatialSend) -
                Double(Float(neutralReferenceSend))
            spatialDifferenceEnergy += spatialDifference * spatialDifference
            if modulation.active {
                let gateDifference = spatialValue -
                    Double(preGatePadSpatialSend)
                spatialAmplitudeGateDifferenceEnergy +=
                    gateDifference * gateDifference
                if amplitudeGateTarget == 0 {
                    let outputValue = Double(sample)
                    amplitudeGateClosedOutputEnergy +=
                        outputValue * outputValue
                    amplitudeGateClosedSpatialSendEnergy +=
                        spatialValue * spatialValue
                }
            }
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
            rhythmicModulationRelation: modulation.relation,
            rhythmicModulationPhaseOffset: modulation.phaseOffset,
            rhythmicModulationPatternFingerprint: patternFingerprint,
            minimumFilterScale: minimumFilterScale,
            maximumFilterScale: maximumFilterScale,
            minimumSpatialSendScale: minimumSpatialSendScale,
            maximumSpatialSendScale: maximumSpatialSendScale,
            minimumAmplitudeGateGain: minimumAmplitudeGateGain,
            maximumAmplitudeGateGain: maximumAmplitudeGateGain,
            amplitudeGateTransitionFrameCount:
                amplitudeGateTransitionFrameCount,
            amplitudeGateOpenFrameCount: amplitudeGateOpenFrameCount,
            amplitudeGateClosedFrameCount: amplitudeGateClosedFrameCount,
            preAmplitudeGateOutputSampleHash:
                preGateOutputFingerprint.fingerprint,
            preAmplitudeGateSpatialSendSampleHash:
                preGateSpatialFingerprint.fingerprint,
            amplitudeGateDifferenceRMS: sqrt(
                amplitudeGateDifferenceEnergy / Double(max(1, frames))
            ),
            spatialAmplitudeGateDifferenceRMS: sqrt(
                spatialAmplitudeGateDifferenceEnergy /
                    Double(max(1, frames))
            ),
            amplitudeGateClosedOutputRMS: sqrt(
                amplitudeGateClosedOutputEnergy /
                    Double(max(1, amplitudeGateClosedFrameCount))
            ),
            amplitudeGateClosedSpatialSendRMS: sqrt(
                amplitudeGateClosedSpatialSendEnergy /
                    Double(max(1, amplitudeGateClosedFrameCount))
            ),
            filterModulationDifferenceRMS: sqrt(
                filterDifferenceEnergy / Double(max(1, frames))
            ),
            spatialSendDifferenceRMS: sqrt(
                spatialDifferenceEnergy / Double(max(1, frames))
            ),
            spatialSendSampleHash: spatialFingerprint.fingerprint,
            spatialSendRMS: sqrt(spatialEnergy / Double(max(1, frames))),
            outputSampleHash: ExactPCMFingerprint.mono(measurement),
            outputRMS: sqrt(energy / Double(max(1, frames))),
            outputPeak: peak,
            finite: finite && energy.isFinite && peak.isFinite &&
                amplitudeGateDifferenceEnergy.isFinite &&
                spatialAmplitudeGateDifferenceEnergy.isFinite &&
                amplitudeGateClosedOutputEnergy.isFinite &&
                amplitudeGateClosedSpatialSendEnergy.isFinite
        )
    }

    private static func rhythmicAmplitudeGateGain(
        frame: Int,
        step: Int,
        totalFrameCount: Int,
        stepFrames: Double,
        transitionFrameCount: Int,
        target: Double
    ) -> Double {
        guard target == 1,
              totalFrameCount > 0,
              stepFrames.isFinite,
              stepFrames > 0 else { return 0 }
        let stepStart = min(
            totalFrameCount,
            max(0, Int(ceil(Double(step) * stepFrames)))
        )
        let stepEnd = min(
            totalFrameCount,
            max(stepStart, Int(ceil(Double(step + 1) * stepFrames)))
        )
        let count = stepEnd - stepStart
        guard count > 1, frame >= stepStart, frame < stepEnd else { return 0 }
        let edgeCount = min(max(2, transitionFrameCount), max(2, count / 2))
        let offset = frame - stepStart
        let remaining = stepEnd - 1 - frame
        if offset < edgeCount {
            let progress = Double(offset) / Double(max(1, edgeCount - 1))
            return 0.5 - 0.5 * cos(.pi * progress)
        }
        if remaining < edgeCount {
            let progress = Double(remaining) / Double(max(1, edgeCount - 1))
            return 0.5 - 0.5 * cos(.pi * progress)
        }
        return 1
    }

    private static func wrap(_ phase: Double) -> Double {
        let result = phase.truncatingRemainder(dividingBy: 1)
        return result < 0 ? result + 1 : result
    }
}

enum PadRhythmicModulationFingerprint {
    static func make(_ modulation: PadRhythmicModulation) -> String {
        var samples: [Float] = []
        samples.reserveCapacity(PadRhythmicModulation.stepCount * 2)
        for step in 0..<PadRhythmicModulation.stepCount {
            samples.append(Float(modulation.filterScale(atStep: step)))
            samples.append(Float(modulation.spatialSendScale(atStep: step)))
            samples.append(Float(modulation.amplitudeGateTarget(atStep: step)))
        }
        return ExactPCMFingerprint.mono(samples)
    }
}
