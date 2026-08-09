import AutoTechnoCore
import Foundation

struct AlienVoiceNote: Equatable, Sendable {
    let startFrame: Int
    let durationFrames: Int
    let frequency: Double
    let endFrequency: Double
    let velocity: Double
    let role: SynthRole
    let articulation: RelationalArticulation
    let dryScale: Double
    let spatialReverbSend: Double
    let narrativeGainScale: Double
    let narrativeSpectralScale: Double
}

struct AlienVoiceState: Equatable, Sendable {
    var phaseA = 0.0
    var phaseB = 0.0
    var modPhase = 0.0
    var noisePhaseA = 0.0
    var noisePhaseB = 0.0
    var driftPhase = 0.0
    var drift = 0.0
    var frequency = 65.41
    var envelope = 0.0
    var previousSource = 0.0
    var filter1 = 0.0
    var filter2 = 0.0
    var filter3 = 0.0
    var filter4 = 0.0
    var mutationLow = 0.0
    var oversampleLow = 0.0
    var echoLow = 0.0
    var dcInput = 0.0
    var dcOutput = 0.0
    var tailLevel = 0.0
    var comb: [Float] = []
    var combIndex = 0
    var allPass: [Float] = []
    var allPassIndex = 0
    var echo: [Float] = []
    var echoIndex = 0

    mutating func prepare(sampleRate: Double, world: SynthWorldDNA, role: SynthRole) {
        let roleOffset = SynthRole.allCases.firstIndex(of: role) ?? 0
        let combSeconds = 0.0027 + Double((world.variation + roleOffset) % 5) * 0.00135
        let allPassSeconds = 0.0013 + Double((world.variation * 2 + roleOffset) % 4) * 0.00083
        let echoJitter = Double(SceneDNA.derivedSeed(
            scene: world.sceneSeed, domain: 0xEC40A11, index: roleOffset
        ) % 1_000) / 1_000
        let echoSeconds = 0.247 + echoJitter * 0.089
        let combFrames = max(8, Int((sampleRate * combSeconds).rounded()))
        let allPassFrames = max(5, Int((sampleRate * allPassSeconds).rounded()))
        let echoFrames = max(32, Int((sampleRate * echoSeconds).rounded()))
        if comb.count != combFrames {
            comb = [Float](repeating: 0, count: combFrames)
            combIndex = 0
        }
        if allPass.count != allPassFrames {
            allPass = [Float](repeating: 0, count: allPassFrames)
            allPassIndex = 0
        }
        if echo.count != echoFrames {
            echo = [Float](repeating: 0, count: echoFrames)
            echoIndex = 0
        }
    }

    mutating func reset() {
        self = AlienVoiceState()
    }
}

/// The bounded spectral coordinate shared by resolved event metadata and the
/// authored motif renderer. Keeping the composition here makes the exact
/// lower and upper limits directly verifiable without rendering audio.
package enum MotifSpectralSculpture {
    package static func combinedMultiplier(narrativeScale: Double,
                                           anchorScale: Double) -> Double {
        min(1.16, max(0.84, narrativeScale * anchorScale))
    }
}

/// One authored instrument topology shared by every upper musical role. It is
/// rendered during detached preparation and never executes on AVAudioEngine's
/// audio callback.
enum AlienAnalogVoice {
    static func render(_ output: inout [Float], measurement: inout [Float],
                       pulseEchoSend: inout [Float],
                       spatialReverbSend: inout [Float],
                       notes: [AlienVoiceNote],
                       sampleRate: Double, level: Double,
                       world: SynthWorldDNA, bar: SynthPerformanceBar,
                       role: SynthRole, state: inout AlienVoiceState) {
        guard !output.isEmpty, sampleRate > 0 else { return }
        guard pulseEchoSend.count == output.count else { return }
        guard spatialReverbSend.count == output.count else { return }
        guard measurement.count == output.count else { return }
        state.prepare(sampleRate: sampleRate, world: world, role: role)
        let scheduled = notes
            .filter { $0.startFrame < output.count && $0.durationFrames > 0 && $0.frequency > 0 }
            .sorted { lhs, rhs in
                lhs.startFrame == rhs.startFrame ? lhs.frequency < rhs.frequency : lhs.startFrame < rhs.startFrame
            }
        if scheduled.isEmpty && state.envelope < 0.000_001 && state.tailLevel < 0.000_001 {
            return
        }

        var nextNote = 0
        var noteStart = -1
        var noteEnd = -1
        var startFrequency = state.frequency
        var targetFrequency = state.frequency
        var velocity = 0.0
        var articulation = RelationalArticulation.neutral
        var dryScale = 1.0
        var spatialSendLevel = 0.0
        var narrativeGainScale = 1.0
        var narrativeSpectralScale = 1.0
        let roleMutation = mutationScale(for: role)
        let mutation = min(1, bar.mutationAmount * roleMutation)
        let fingerprint = world.motifFingerprint
        let baseAttackSeconds = attack(for: role, gesture: bar.gesture, fingerprint: fingerprint)
        let baseDecaySeconds = decay(for: role, gesture: bar.gesture, fingerprint: fingerprint)
        let sustain = sustain(for: role, gesture: bar.gesture, fingerprint: fingerprint)
        let releaseSeconds = release(for: role, gesture: bar.gesture, fingerprint: fingerprint)
        var attackFrames = max(1, Int(baseAttackSeconds * sampleRate))
        var decaySeconds = baseDecaySeconds
        let releaseCoefficient = exp(-1 / max(1, releaseSeconds * sampleRate))
        var glideCoefficient = 1 - exp(-1 / max(1, sampleRate * (0.012 + mutation * 0.030)))
        let oversampledRate = sampleRate * 2
        let roleIndex = Double(SynthRole.allCases.firstIndex(of: role) ?? 0)
        let driftRate = 0.031 + roleIndex * 0.007 + Double(world.variation) * 0.003

        for frame in output.indices {
            var triggered = false
            while nextNote < scheduled.count && scheduled[nextNote].startFrame == frame {
                let note = scheduled[nextNote]
                noteStart = frame
                noteEnd = min(output.count, frame + note.durationFrames)
                startFrequency = max(20, state.frequency)
                targetFrequency = note.endFrequency
                velocity = min(1, max(0, note.velocity))
                articulation = note.articulation
                dryScale = min(1, max(0, note.dryScale))
                spatialSendLevel = min(1, max(0, note.spatialReverbSend))
                narrativeGainScale = max(0, note.narrativeGainScale)
                narrativeSpectralScale = max(0.01, note.narrativeSpectralScale)
                attackFrames = max(1, Int(
                    baseAttackSeconds * articulation.attackScale * sampleRate
                ))
                decaySeconds = baseDecaySeconds * articulation.decayScale
                let glideSeconds = (0.012 + mutation * 0.030) * articulation.glideTimeScale
                glideCoefficient = 1 - exp(-1 / max(1, sampleRate * glideSeconds))
                triggered = true
                nextNote += 1
            }

            let gate = frame < noteEnd
            if gate {
                let age = max(0, frame - noteStart)
                let attackProgress = min(1, Double(age) / Double(attackFrames))
                let shapedAttack = attackProgress * attackProgress * (3 - 2 * attackProgress)
                let decayTime = max(0, Double(age - attackFrames)) / sampleRate
                let decayEnvelope = sustain + (1 - sustain) * exp(-decayTime / max(0.02, decaySeconds))
                let targetEnvelope = age < attackFrames ? shapedAttack : decayEnvelope
                if triggered && role != .atmosphere {
                    state.envelope = min(state.envelope, 0.14)
                }
                state.envelope += (targetEnvelope - state.envelope) * 0.24
            } else {
                state.envelope *= releaseCoefficient
            }

            let noteProgress: Double
            if noteStart >= 0 && noteEnd > noteStart {
                noteProgress = min(1, max(0, Double(frame - noteStart) / Double(noteEnd - noteStart)))
            } else {
                noteProgress = 1
            }
            let desiredFrequency = startFrequency + (targetFrequency - startFrequency) * noteProgress
            state.frequency += (desiredFrequency - state.frequency) * glideCoefficient

            let activeNonlinearVoice = gate || state.envelope > 0.000_01
            var dryVoice = 0.0
            if activeNonlinearVoice {
                var oversampleSum = 0.0
                for _ in 0..<2 {
                state.driftPhase = wrap(state.driftPhase + driftRate / oversampledRate)
                let driftTarget = fastSine(state.driftPhase) * 0.72 +
                    fastSine(wrap(state.driftPhase * 0.371 + roleIndex / (2 * .pi))) * 0.28
                state.drift += (driftTarget - state.drift) * 0.00018
                let driftCents = state.drift * (2.4 + mutation * 3.8)
                let frequency = min(oversampledRate * 0.16,
                                    max(20, state.frequency * (1 + driftCents * 0.000_577_622)))
                let motifDetune = [0.004, 0.007, 0.011][fingerprint.modulationFamily]
                let ratio = (role == .anchor ? 1 + motifDetune : 1.006) +
                    Double(world.variation) * 0.0017 + roleIndex * 0.0009
                let incrementA = frequency / oversampledRate
                let incrementB = frequency * ratio / oversampledRate
                let motifModulation = [1.19, 1.37, 1.61][fingerprint.modulationFamily]
                let modRatio = role == .anchor
                    ? motifModulation : 1.37 + Double(world.variation) * 0.071
                let modIncrement = frequency * modRatio / oversampledRate
                state.phaseA = wrap(state.phaseA + incrementA)
                state.phaseB = wrap(state.phaseB + incrementB)
                state.modPhase = wrap(state.modPhase + modIncrement)
                state.noisePhaseA = wrap(state.noisePhaseA + (6_113 + roleIndex * 173) / oversampledRate)
                state.noisePhaseB = wrap(state.noisePhaseB + (2_719 + Double(world.variation) * 211) / oversampledRate)

                let modulator = fastSine(state.modPhase)
                let phaseMod = modulator * (0.012 + mutation * 0.115) *
                    (role == .anchor ? 0.72 : 1)
                let phaseA = wrap(state.phaseA + phaseMod)
                let pulseWidth = min(0.72, max(0.22,
                    0.34 + fastSine(wrap(state.driftPhase * 0.43)) * (0.035 + mutation * 0.10)))
                let sawA = bandLimitedSaw(phaseA, increment: incrementA)
                let sawB = bandLimitedSaw(state.phaseB, increment: incrementB)
                let pulse = bandLimitedPulse(phaseA, increment: incrementA, width: pulseWidth)
                let noise = fastSine(wrap(state.noisePhaseA + state.modPhase * 0.059)) *
                    fastSine(wrap(state.noisePhaseB + state.phaseB * 0.037))
                let source = sawA * 0.43 + sawB * 0.24 + pulse * 0.24 + noise * 0.09

                let anchor = fastSaturate((source + sawA * sawB * 0.14) * (1.18 + mutation * 0.30))
                let emphasized = source + (source - state.previousSource) * (0.18 + mutation * 0.34)
                state.previousSource = source
                let folded = waveFold(emphasized * (1.18 + mutation * 2.15))
                let ringCarrier = fastSine(wrap(
                    state.phaseB * (1.5 + roleIndex * 0.083) + state.modPhase * 0.31
                ))
                var altered = folded * (1 - mutation * 0.18) + folded * ringCarrier * (0.16 + mutation * 0.56)
                altered += altered * altered * (0.08 + mutation * 0.20)

                let envelopeLift = state.envelope * 0.20
                let articulationSpectralScale: Double
                switch role {
                case .anchor:
                    articulationSpectralScale = MotifSpectralSculpture.combinedMultiplier(
                        narrativeScale: narrativeSpectralScale,
                        anchorScale: articulation.anchorSpectralScale
                    )
                case .shadow, .response:
                    articulationSpectralScale = articulation.complementarySpectralScale
                case .atmosphere, .transition:
                    articulationSpectralScale = 1
                }
                let spectralScale = role == .anchor
                    ? [0.72, 1.0, 1.28][fingerprint.spectralRegion] *
                        articulationSpectralScale
                    : articulationSpectralScale
                let baseCutoff = (170 + Double(world.variation) * 55 + roleIndex * 48) * spectralScale
                let cutoff = min(oversampledRate * 0.18,
                                 baseCutoff + (1 - mutation) * 1_280 + envelopeLift * 1_850 +
                                 modulator * mutation * 310)
                let rawCoefficient = 2 * .pi * cutoff / oversampledRate
                let coefficient = min(0.46, max(0.004,
                    rawCoefficient / (1 + rawCoefficient * 0.5)))
                let resonance = min(0.76, 0.22 + mutation * 0.38)
                let feedbackInput = fastSaturate(altered * (1.35 + mutation * 1.45) - state.filter4 * resonance)
                state.filter1 += (fastSaturate(feedbackInput) - state.filter1) * coefficient
                state.filter2 += (fastSaturate(state.filter1 * 1.08) - state.filter2) * coefficient
                state.filter3 += (fastSaturate(state.filter2 * 1.06) - state.filter3) * coefficient
                state.filter4 += (fastSaturate(state.filter3 * 1.04) - state.filter4) * coefficient

                let anchorBody = state.filter2 * 0.72 + anchor * 0.18
                state.mutationLow += (state.filter4 - state.mutationLow) * 0.013
                let mutationHigh = state.filter4 - state.mutationLow
                let blend = min(0.94, 0.24 + mutation * 0.70)
                let unsculptedVoice = anchorBody * (1 - blend) + mutationHigh * blend
                let bandPassVoice = state.filter2 - state.filter4
                let eligibleForSpectralSculpture = role == .anchor ||
                    role == .shadow || role == .response
                let bandPassBlend = eligibleForSpectralSculpture
                    ? min(0.15, max(0, articulation.bandPassBlend)) : 0
                let voice = unsculptedVoice * (1 - bandPassBlend) +
                    bandPassVoice * bandPassBlend
                state.oversampleLow += (voice - state.oversampleLow) * 0.58
                    oversampleSum += state.oversampleLow
                }

                let amplitude = state.envelope * velocity * level *
                    (role == .anchor ? narrativeGainScale : 1)
                dryVoice = oversampleSum * 0.5 * amplitude
            } else {
                state.filter1 *= 0.94
                state.filter2 *= 0.94
                state.filter3 *= 0.94
                state.filter4 *= 0.94
                state.oversampleLow *= 0.72
            }
            let combRead = Double(state.comb[state.combIndex])
            let combFeedback = min(0.58, 0.16 + mutation * 0.34)
            state.comb[state.combIndex] = Float(dryVoice + combRead * combFeedback)
            state.combIndex = (state.combIndex + 1) % state.comb.count
            let combVoice = dryVoice + combRead * (0.12 + mutation * 0.38)

            let allPassRead = Double(state.allPass[state.allPassIndex])
            let allPassGain = min(0.68, 0.34 + mutation * 0.24)
            let allPassVoice = allPassRead - combVoice * allPassGain
            state.allPass[state.allPassIndex] = Float(combVoice + allPassVoice * allPassGain)
            state.allPassIndex = (state.allPassIndex + 1) % state.allPass.count
            let coloredVoice = combVoice * 0.78 + allPassVoice * 0.22

            if gate, articulation.pulseEchoSend > 0 {
                pulseEchoSend[frame] += Float(coloredVoice * articulation.pulseEchoSend)
            }

            let echoRead = Double(state.echo[state.echoIndex])
            state.echoLow += (echoRead - state.echoLow) * (0.08 + (1 - mutation) * 0.05)
            let filteredEcho = state.echoLow
            let echoSend = bar.gesture == .suspend ? 0.26 + mutation * 0.34 : 0.035
            let echoFeedback = min(0.69, 0.31 + mutation * 0.31)
            state.echo[state.echoIndex] = Float(coloredVoice * echoSend + filteredEcho * echoFeedback)
            state.echoIndex = (state.echoIndex + 1) % state.echo.count

            let withMemory = coloredVoice + filteredEcho * (0.14 + mutation * 0.28)
            let dcBlocked = withMemory - state.dcInput + 0.995 * state.dcOutput
            state.dcInput = withMemory
            state.dcOutput = dcBlocked
            state.tailLevel = max(abs(dcBlocked), state.tailLevel * 0.9995)
            let unscaledSample = Float(fastSaturate(dcBlocked * 1.08))
            let renderedSample = unscaledSample * Float(dryScale)
            output[frame] += renderedSample
            measurement[frame] += renderedSample
            spatialReverbSend[frame] += unscaledSample * Float(spatialSendLevel)
        }
    }

    private static func mutationScale(for role: SynthRole) -> Double {
        switch role {
        case .anchor: return 0.82
        case .shadow: return 1.0
        case .atmosphere: return 0.92
        case .response: return 0.88
        case .transition: return 1.0
        }
    }

    private static func attack(for role: SynthRole, gesture: SynthGesture,
                               fingerprint: MotifTimbreFingerprint) -> Double {
        if role == .anchor { return [0.004, 0.010, 0.022][fingerprint.envelopeFamily] }
        if role == .atmosphere { return gesture == .suspend ? 0.38 : 0.18 }
        if role == .transition { return 0.09 }
        return gesture == .release ? 0.004 : 0.009
    }

    private static func decay(for role: SynthRole, gesture: SynthGesture,
                              fingerprint: MotifTimbreFingerprint) -> Double {
        if role == .anchor { return [0.11, 0.22, 0.38][fingerprint.envelopeFamily] }
        if role == .atmosphere { return 1.8 }
        return gesture == .corrode ? 0.12 : 0.22
    }

    private static func sustain(for role: SynthRole, gesture: SynthGesture,
                                fingerprint: MotifTimbreFingerprint) -> Double {
        if role == .anchor { return [0.16, 0.24, 0.36][fingerprint.envelopeFamily] }
        if role == .atmosphere { return 0.72 }
        if role == .transition { return 0.56 }
        return gesture == .release ? 0.34 : 0.22
    }

    private static func release(for role: SynthRole, gesture: SynthGesture,
                                fingerprint: MotifTimbreFingerprint) -> Double {
        if role == .anchor { return [0.08, 0.16, 0.28][fingerprint.envelopeFamily] }
        if role == .atmosphere { return gesture == .suspend ? 1.6 : 0.72 }
        if role == .transition { return 0.44 }
        return 0.10 + (gesture == .corrode ? 0.16 : 0.06)
    }

    private static func waveFold(_ value: Double) -> Double {
        var wrapped = (value + 1).truncatingRemainder(dividingBy: 4)
        if wrapped < 0 { wrapped += 4 }
        return wrapped < 2 ? wrapped - 1 : 3 - wrapped
    }

    /// Phase-domain sine approximation. Its small residual harmonics are
    /// musically useful here and avoid transcendental work in the 2x loop.
    private static func fastSine(_ phase: Double) -> Double {
        let x = phase * 2 - 1
        let first = -4 * x * (1 - abs(x))
        return first * (0.775 + 0.225 * abs(first))
    }

    private static func fastSaturate(_ value: Double) -> Double {
        let shaped = value / (1 + abs(value) * 0.45)
        return min(1.2, max(-1.2, shaped))
    }

    private static func wrap(_ phase: Double) -> Double {
        let result = phase.truncatingRemainder(dividingBy: 1)
        return result < 0 ? result + 1 : result
    }

    private static func bandLimitedSaw(_ phase: Double, increment: Double) -> Double {
        2 * phase - 1 - polyBLEP(phase, increment: increment)
    }

    private static func bandLimitedPulse(_ phase: Double, increment: Double, width: Double) -> Double {
        let boundedWidth = min(0.8, max(0.2, width))
        let naive = phase < boundedWidth ? 1.0 : -1.0
        let shifted = wrap(phase - boundedWidth)
        return naive + polyBLEP(phase, increment: increment) - polyBLEP(shifted, increment: increment)
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
