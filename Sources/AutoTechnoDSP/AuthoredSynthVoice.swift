import AutoTechnoCore
import Foundation

struct AuthoredSynthNote: Equatable, Sendable {
    let startFrame: Int
    let durationFrames: Int
    let frequency: Double
    let velocity: Double
}

/// A persistent, authored mono instrument used only by the dramatic-journey
/// candidate. It renders from an immutable note list during preparation, never
/// from the live audio callback.
enum AuthoredSynthVoice {
    static func render(_ output: inout [Float], notes: [AuthoredSynthNote],
                       sampleRate: Double, level: Double, patch: InstrumentPatchDNA,
                       macros: PatchMacroState, state: inout V2RenderState) {
        guard !output.isEmpty, sampleRate > 0 else { return }
        let scheduled = notes
            .filter { $0.startFrame < output.count && $0.durationFrames > 0 && $0.frequency > 0 }
            .sorted { lhs, rhs in
                lhs.startFrame == rhs.startFrame ? lhs.frequency < rhs.frequency : lhs.startFrame < rhs.startFrame
            }
        guard !scheduled.isEmpty || state.authoredSynthEnvelope > 0.000_01 else { return }

        var nextNote = 0
        var noteStart = -1
        var noteEnd = -1
        var targetFrequency = state.authoredSynthFrequency
        var velocity = 0.0
        let detuneRatio = pow(2, patch.detuneCents / 1_200)
        let attackFrames = max(1, Int(patch.attackSeconds * sampleRate))
        let releaseCoefficient = exp(-1 / max(1, patch.releaseSeconds * (0.75 + macros.decay * 0.75) * sampleRate))
        let glideCoefficient = 1 - exp(-1 / max(1, patch.glideSeconds * sampleRate))
        let lfoRate = 0.045 + macros.motion * 0.11

        for frame in output.indices {
            var triggered = false
            while nextNote < scheduled.count && scheduled[nextNote].startFrame == frame {
                let note = scheduled[nextNote]
                noteStart = frame
                noteEnd = min(output.count, frame + note.durationFrames)
                targetFrequency = note.frequency
                velocity = min(1, max(0, note.velocity))
                triggered = true
                nextNote += 1
            }

            let gate = frame < noteEnd
            if gate {
                let age = max(0, frame - noteStart)
                let targetEnvelope: Double
                if age < attackFrames {
                    targetEnvelope = Double(age) / Double(attackFrames)
                } else {
                    let decayTime = Double(age - attackFrames) / sampleRate
                    let decaySeconds = patch.decaySeconds * (0.72 + macros.decay * 0.85)
                    targetEnvelope = patch.sustain + (1 - patch.sustain) * exp(-decayTime / max(0.01, decaySeconds))
                }
                if triggered {
                    state.authoredSynthEnvelope = min(state.authoredSynthEnvelope, 0.12)
                }
                state.authoredSynthEnvelope += (targetEnvelope - state.authoredSynthEnvelope) * 0.22
            } else {
                state.authoredSynthEnvelope *= releaseCoefficient
            }

            state.authoredSynthFrequency += (targetFrequency - state.authoredSynthFrequency) * glideCoefficient
            let frequency = max(24, min(sampleRate * 0.18, state.authoredSynthFrequency))
            let phaseIncrementA = frequency / sampleRate
            let phaseIncrementB = frequency * detuneRatio / sampleRate
            let phaseIncrementSub = frequency * 0.5 / sampleRate
            let phaseIncrementFifth = frequency * 1.498_307 / sampleRate
            state.authoredSynthPhaseA = wrap(state.authoredSynthPhaseA + phaseIncrementA)
            state.authoredSynthPhaseB = wrap(state.authoredSynthPhaseB + phaseIncrementB)
            state.authoredSynthPhaseSub = wrap(state.authoredSynthPhaseSub + phaseIncrementSub)
            state.authoredSynthPhaseFifth = wrap(state.authoredSynthPhaseFifth + phaseIncrementFifth)
            state.authoredSynthLFOPhase = wrap(state.authoredSynthLFOPhase + lfoRate / sampleRate)

            let slowMotion = sin(state.authoredSynthLFOPhase * 2 * .pi)
            let pulseWidth = min(0.68, max(0.24, 0.39 + slowMotion * (0.025 + macros.motion * 0.10)))
            let phaseModulation = sin(state.authoredSynthPhaseB * 2 * .pi) * macros.instability * 0.026
            let phaseA = wrap(state.authoredSynthPhaseA + phaseModulation)
            let sawA = bandLimitedSaw(phaseA, increment: phaseIncrementA)
            let sawB = bandLimitedSaw(state.authoredSynthPhaseB, increment: phaseIncrementB)
            let pulse = bandLimitedPulse(phaseA, increment: phaseIncrementA, width: pulseWidth)
            let sub = sin(state.authoredSynthPhaseSub * 2 * .pi)
            let fifth = sin(state.authoredSynthPhaseFifth * 2 * .pi + slowMotion * 0.08)
            let oscillator = sawA * patch.sawMix + sawB * patch.sawMix * 0.42 +
                pulse * patch.pulseMix + sub * patch.subMix + fifth * patch.fifthMix
            let bite = sin(phaseA * 4 * .pi) * macros.bite * 0.055
            let driven = tanh((oscillator + bite) * patch.drive * (1 + macros.bite * 0.75))

            let envelopeLift = state.authoredSynthEnvelope * (0.18 + macros.impact * 0.16)
            let movingCutoff = patch.baseCutoff + patch.cutoffRange *
                (0.08 + macros.pressure * 0.72 + envelopeLift) *
                (1 + slowMotion * macros.motion * 0.12)
            let cutoff = min(sampleRate * 0.18, max(55, movingCutoff))
            let coefficient = min(0.82, max(0.012, 2 * sin(.pi * cutoff / sampleRate)))
            let resonance = min(0.82, patch.baseResonance + macros.pressure * 0.22 + macros.instability * 0.16)
            let damping = max(0.28, 1.52 - resonance * 1.34)

            let high = driven - state.authoredSynthFilterLow - damping * state.authoredSynthFilterBand
            state.authoredSynthFilterBand += coefficient * high
            state.authoredSynthFilterLow += coefficient * state.authoredSynthFilterBand
            let stageOne = state.authoredSynthFilterLow + state.authoredSynthFilterBand * (0.06 + macros.bite * 0.10)

            let secondCoefficient = min(0.76, coefficient * (0.72 + macros.pressure * 0.16))
            let high2 = stageOne - state.authoredSynthFilterLow2 - (damping + 0.14) * state.authoredSynthFilterBand2
            state.authoredSynthFilterBand2 += secondCoefficient * high2
            state.authoredSynthFilterLow2 += secondCoefficient * state.authoredSynthFilterBand2

            let transientLift = triggered ? 1 + macros.impact * 0.28 : 1
            let amplitude = state.authoredSynthEnvelope * velocity * level * transientLift
            let sample = tanh((state.authoredSynthFilterLow2 + state.authoredSynthFilterBand2 * 0.055) *
                              (1.05 + macros.bite * 0.30)) * amplitude
            output[frame] += Float(sample)
        }
    }

    private static func wrap(_ phase: Double) -> Double {
        let wrapped = phase.truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }

    private static func bandLimitedSaw(_ phase: Double, increment: Double) -> Double {
        let naive = 2 * phase - 1
        return naive - polyBLEP(phase, increment: increment)
    }

    private static func bandLimitedPulse(_ phase: Double, increment: Double, width: Double) -> Double {
        let boundedWidth = min(0.8, max(0.2, width))
        let naive = phase < boundedWidth ? 1.0 : -1.0
        let first = polyBLEP(phase, increment: increment)
        let shifted = wrap(phase - boundedWidth)
        return naive + first - polyBLEP(shifted, increment: increment)
    }

    private static func polyBLEP(_ phase: Double, increment: Double) -> Double {
        let dt = min(0.5, max(0.000_000_1, increment))
        if phase < dt {
            let x = phase / dt
            return x + x - x * x - 1
        }
        if phase > 1 - dt {
            let x = (phase - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }
}
