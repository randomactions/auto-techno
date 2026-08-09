import AutoTechnoCore
import Foundation

struct SpectralTextureState: Equatable, Sendable {
    var activePatch: InstrumentPatch?
    var phaseA = 0.0
    var phaseB = 0.0
    var phaseC = 0.0
    var low = 0.0
    var band = 0.0
    var resonator = 0.0
    var previousResonator = 0.0
    var dcInput = 0.0
    var dcOutput = 0.0
    var frequency = 220.0

    mutating func prepare(patch: InstrumentPatch) {
        guard patch.architecture == .spectralTexture else { return }
        if let activePatch, activePatch != patch {
            low = 0
            band = 0
            resonator = 0
            previousResonator = 0
            dcInput = 0
            dcOutput = 0
        }
        activePatch = patch
    }
}

/// Noise, ring-modulation, and resonator material for responses, atmosphere,
/// and transitions. The source is fully engine-owned and deterministic; no
/// samples, plug-ins, or callback-time analysis participate.
enum SpectralTextureVoice {
    static func render(
        _ output: inout [Float],
        measurement: inout [Float],
        architectureMeasurement: inout [Float],
        pulseEchoSend: inout [Float],
        spatialReverbSend: inout [Float],
        noteRenderEvidence: inout [UpperNoteRenderEvidence],
        notes: [AlienVoiceNote],
        sampleRate: Double,
        level: Double,
        state: inout SpectralTextureState
    ) {
        guard sampleRate > 0,
              output.count == measurement.count,
              output.count == architectureMeasurement.count,
              output.count == pulseEchoSend.count,
              output.count == spatialReverbSend.count else { return }
        let scheduled = notes.filter {
            $0.instrument.architecture == .spectralTexture &&
                $0.startFrame < output.count && $0.durationFrames > 0
        }.sorted {
            $0.startFrame == $1.startFrame ? $0.frequency < $1.frequency :
                $0.startFrame < $1.startFrame
        }
        for note in scheduled {
            state.prepare(patch: note.instrument.patch)
            let frames = min(note.durationFrames, output.count - note.startFrame)
            guard frames > 0 else { continue }
            let automation = note.instrument.automation
            let velocity = min(1, max(0, note.velocity))
            let attackSeconds = 0.008 + automation.shape * 0.28
            let releaseSeconds = 0.08 + automation.shape * 1.12
            let attackFrames = max(1, Int((attackSeconds * sampleRate).rounded()))
            let targetFrequency = max(45, note.endFrequency)
            let requestedStart = max(45, note.frequency)
            state.frequency = requestedStart
            let glide = 1 - exp(-1 / max(1, sampleRate * (0.04 + automation.motion * 0.22)))
            let patchRatios: (Double, Double, Double) = switch note.instrument.patch {
            case .alienNoise: (1.71, 2.43, 3.19)
            case .metalVeil: (2.01, 3.97, 5.03)
            case .dustCloud: (0.51, 1.13, 1.91)
            case .bassPulse, .bassPluck, .acidThread, .acidSequence,
                 .northStar, .darkChord, .glassRunner:
                (1, 1.5, 2)
            }
            for index in 0..<frames {
                let progress = frames > 1 ? Double(index) / Double(frames - 1) : 1
                let desiredFrequency = requestedStart +
                    (targetFrequency - requestedStart) * progress
                state.frequency += (desiredFrequency - state.frequency) * glide
                let frequency = min(sampleRate * 0.12, state.frequency)
                state.phaseA = wrap(state.phaseA + frequency * patchRatios.0 / sampleRate)
                state.phaseB = wrap(state.phaseB + frequency * patchRatios.1 / sampleRate)
                state.phaseC = wrap(state.phaseC + frequency * patchRatios.2 / sampleRate)
                let a = fastSine(state.phaseA)
                let b = fastSine(state.phaseB)
                let c = fastSine(state.phaseC)
                let source: Double = switch note.instrument.patch {
                case .alienNoise:
                    a * b * 0.62 + b * c * 0.24 + a * 0.14
                case .metalVeil:
                    (a * b) * 0.50 + (b * c) * 0.34 + c * 0.16
                case .dustCloud:
                    a * 0.42 + a * b * 0.26 + b * c * 0.18 + c * 0.14
                case .bassPulse, .bassPluck, .acidThread, .acidSequence,
                     .northStar, .darkChord, .glassRunner:
                    a
                }
                let cutoff = min(
                    sampleRate * 0.16,
                    220 + automation.color * 4_800 +
                        fastSine(wrap(state.phaseC * 0.19)) * automation.motion * 720
                )
                let coefficient = min(
                    0.48,
                    max(0.002, 2 * .pi * cutoff / sampleRate)
                )
                state.low += (source - state.low) * coefficient
                let high = source - state.low
                state.band += (high - state.band) * min(0.42, coefficient * 0.62)
                let resonatorFrequency = min(
                    sampleRate * 0.14,
                    frequency * (2.0 + automation.color * 5.0)
                )
                let resonatorCoefficient = 2 * cos(2 * .pi * resonatorFrequency / sampleRate)
                let damping = 0.72 + automation.motion * 0.245
                let resonatorInput = state.band * (0.16 + automation.motion * 0.34)
                let resonated = resonatorInput + resonatorCoefficient * damping *
                    state.resonator - damping * damping * state.previousResonator
                state.previousResonator = state.resonator
                state.resonator = min(2, max(-2, resonated))
                let age = Double(index) / sampleRate
                let attack = min(1, Double(index) / Double(attackFrames))
                let release = exp(-max(0, age - attackSeconds) / releaseSeconds)
                let envelope = attack * release
                let colored = state.band * (0.74 - automation.motion * 0.20) +
                    state.resonator * (0.18 + automation.motion * 0.28)
                let driven = note.instrument.effects.contains(.drive)
                    ? saturate(colored * (1.08 + automation.motion * 0.82))
                    : colored
                let dcBlocked = driven - state.dcInput + 0.994 * state.dcOutput
                state.dcInput = driven
                state.dcOutput = dcBlocked
                let unscaled = Float(
                    saturate(dcBlocked) * envelope * velocity * max(0, level)
                )
                let sample = unscaled * Float(min(1, max(0, note.dryScale)))
                let frame = note.startFrame + index
                output[frame] += sample
                measurement[frame] += sample
                architectureMeasurement[frame] += sample
                if note.instrument.effects.contains(.pulseEcho) {
                    pulseEchoSend[frame] += unscaled * Float(0.06 + automation.space * 0.18)
                }
                if note.instrument.effects.contains(.filteredReverb) {
                    let send = max(note.spatialReverbSend, automation.space * 0.42)
                    spatialReverbSend[frame] += unscaled * Float(min(1, send))
                }
            }
            let requestedEnd = note.startFrame.addingReportingOverflow(note.durationFrames)
            let requestedGateEnd = requestedEnd.overflow ? Int.max : requestedEnd.partialValue
            noteRenderEvidence.append(UpperNoteRenderEvidence(
                role: note.role,
                onsetFrame: note.startFrame,
                requestedGateEndFrame: requestedGateEnd,
                appliedGateEndFrame: min(output.count, note.startFrame + frames),
                requestedStartFrequency: note.frequency,
                appliedStartFrequency: requestedStart,
                targetEndFrequency: targetFrequency,
                frequencyAtAppliedGateEnd: state.frequency,
                requestedGate: note.gate,
                appliedGate: .retrigger,
                didRetrigger: true,
                timbreIntent: note.timbreIntent,
                requestedVelocity: note.velocity,
                appliedVelocity: velocity,
                velocitySpectralEnvelopeScale: 0.82 + velocity * 0.36,
                velocityDecayScale: 0.90 + velocity * 0.18,
                instrument: note.instrument
            ))
        }
    }

    private static func saturate(_ value: Double) -> Double {
        value / (1 + abs(value) * 0.62)
    }

    private static func wrap(_ phase: Double) -> Double {
        let result = phase.truncatingRemainder(dividingBy: 1)
        return result < 0 ? result + 1 : result
    }

    private static func fastSine(_ phase: Double) -> Double {
        let x = phase * 2 - 1
        let first = -4 * x * (1 - abs(x))
        return first * (0.775 + 0.225 * abs(first))
    }
}
