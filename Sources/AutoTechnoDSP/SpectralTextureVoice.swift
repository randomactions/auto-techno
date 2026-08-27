import AutoTechnoCore
import Foundation

/// Current renderer-owned realization of the durable close-cluster relation.
/// A later oversampled or physical model may replace these exact ratios and
/// weights after advancing the evidence and engine identities.
package struct SpectralTextureClusterTreatment: Equatable, Sendable {
    package let relation: SpectralTextureClusterRelation
    package let componentRatios: [Double]
}

package struct SpectralTextureClusterEventRenderEvidence: Equatable, Sendable {
    package let relation: SpectralTextureClusterRelation
    package let componentRatios: [Double]
    package let renderedFrameCount: Int
}

package enum SpectralTextureClusterContract {
    package static let adjacentSemitoneRatio = 1.059_463_094_359_295_3
    package static let maximumComponentRatio = 1.122_462_048_309_373

    package static func treatment(
        for assignment: InstrumentAssignment
    ) -> SpectralTextureClusterTreatment? {
        guard let relation = assignment.spectralTextureClusterRelation else {
            return nil
        }
        return SpectralTextureClusterTreatment(
            relation: relation,
            componentRatios: [
                1,
                adjacentSemitoneRatio,
                maximumComponentRatio,
            ]
        )
    }
}

package struct SpectralTextureHarmonicTailTreatment: Equatable, Sendable {
    package let relation: SpectralTextureHarmonicTailRelation
    package let startFoldedSourceFrequency: Double
    package let endFoldedSourceFrequency: Double
    package let baseBandCenterHz: Double
    package let centerExcursionHz: Double
    package let resonance: Double
    package let prefilterDrive: Double
    package let lfoRateHz: Double
}

package struct SpectralTextureHarmonicTailEventRenderEvidence: Equatable,
        Sendable {
    package let relation: SpectralTextureHarmonicTailRelation
    package let minimumFoldedSourceFrequency: Double
    package let maximumFoldedSourceFrequency: Double
    package let minimumBandCenterHz: Double
    package let maximumBandCenterHz: Double
    package let resonance: Double
    package let prefilterDrive: Double
    package let lfoRateHz: Double
    package let renderedFrameCount: Int
}

/// Bounded renderer policy for the response-only upper-harmonic-tail relation.
/// All frequencies scale below Nyquist at low evidence rates while retaining a
/// physical 6.5...11.5 kHz target range at normal playback rates.
package enum SpectralTextureHarmonicTailContract {
    package static let minimumSourceFrequency = 28.0
    package static let maximumSourceFrequency = 56.0
    package static let maximumBandCenterFraction = 0.36
    package static let minimumLowBandEnergyRatio = 0.0
    package static let maximumLowBandEnergyRatio = 0.12
    package static let minimumUpperBandEnergyRatio = 0.18

    package static func minimumBandCenterHz(sampleRate: Double) -> Double {
        min(6_500, sampleRate * 0.22)
    }

    package static func maximumBandCenterHz(sampleRate: Double) -> Double {
        min(11_500, sampleRate * maximumBandCenterFraction)
    }

    package static func foldedSourceFrequency(_ frequency: Double) -> Double? {
        guard frequency.isFinite, frequency > 0 else { return nil }
        var folded = frequency
        while folded > maximumSourceFrequency { folded *= 0.5 }
        while folded < minimumSourceFrequency { folded *= 2 }
        return min(maximumSourceFrequency, max(minimumSourceFrequency, folded))
    }

    package static func treatment(
        for assignment: InstrumentAssignment,
        startFrequency: Double,
        endFrequency: Double,
        sampleRate: Double
    ) -> SpectralTextureHarmonicTailTreatment? {
        guard let relation = assignment.spectralTextureHarmonicTailRelation,
              sampleRate.isFinite, sampleRate >= 8_000,
              let startFolded = foldedSourceFrequency(startFrequency),
              let endFolded = foldedSourceFrequency(endFrequency) else {
            return nil
        }
        let minimumCenter = minimumBandCenterHz(sampleRate: sampleRate)
        let maximumCenter = maximumBandCenterHz(sampleRate: sampleRate)
        guard maximumCenter > minimumCenter else { return nil }
        let range = maximumCenter - minimumCenter
        let requestedBase = minimumCenter + range *
            (0.24 + assignment.automation.color * 0.48)
        let requestedExcursion = min(
            range * 0.18,
            140 + assignment.automation.motion * 760
        )
        let baseCenter = min(
            maximumCenter - requestedExcursion,
            max(minimumCenter + requestedExcursion, requestedBase)
        )
        return SpectralTextureHarmonicTailTreatment(
            relation: relation,
            startFoldedSourceFrequency: startFolded,
            endFoldedSourceFrequency: endFolded,
            baseBandCenterHz: baseCenter,
            centerExcursionHz: requestedExcursion,
            resonance: 2.2 + assignment.automation.color * 4.2,
            prefilterDrive: assignment.effects.contains(.drive)
                ? 1.65 + assignment.automation.motion * 1.35 : 1,
            lfoRateHz: 2.4 + assignment.automation.motion * 3.6
        )
    }
}

/// Bounded pitch-salience probe for exact dry indefinite-pitch PCM. Analysis
/// runs only during detached preparation. First-difference pre-emphasis keeps
/// broad spectral color from being mistaken for a periodic fundamental.
package enum IndefinitePitchContract {
    package static let evidenceVersion = "indefinite-pitch.render.v1"
    package static let analysisRate = 6_000.0
    package static let minimumAnalyzedFrequency = 50.0
    package static let maximumAnalyzedFrequency = 2_000.0
    package static let maximumAnalyzedSampleCount = 4_096
    package static let maximumNormalizedPeriodicity = 0.35

    package static func normalizedPeriodicity(
        samples: [Float],
        sampleRate: Double
    ) -> (maximum: Double, analyzedSampleCount: Int) {
        guard sampleRate.isFinite, sampleRate > 0,
              let first = samples.firstIndex(where: { $0 != 0 }),
              let last = samples.lastIndex(where: { $0 != 0 }),
              last > first else { return (0, 0) }
        let stride = max(1, Int((sampleRate / analysisRate).rounded()))
        let effectiveRate = sampleRate / Double(stride)
        var emphasized: [Double] = []
        emphasized.reserveCapacity(maximumAnalyzedSampleCount)
        var prior = Double(samples[first])
        var index = first + stride
        while index <= last && emphasized.count < maximumAnalyzedSampleCount {
            let value = Double(samples[index])
            emphasized.append(value - prior)
            prior = value
            index += stride
        }
        guard emphasized.count >= 128 else {
            return (0, emphasized.count)
        }
        let mean = emphasized.reduce(0, +) / Double(emphasized.count)
        for index in emphasized.indices { emphasized[index] -= mean }
        let minimumLag = max(
            2,
            Int((effectiveRate / maximumAnalyzedFrequency).rounded())
        )
        let maximumLag = min(
            emphasized.count / 3,
            Int((effectiveRate / minimumAnalyzedFrequency).rounded())
        )
        guard maximumLag >= minimumLag else {
            return (0, emphasized.count)
        }
        var maximum = 0.0
        for lag in minimumLag...maximumLag {
            var cross = 0.0
            var leadingEnergy = 0.0
            var trailingEnergy = 0.0
            for index in lag..<emphasized.count {
                let leading = emphasized[index]
                let trailing = emphasized[index - lag]
                cross += leading * trailing
                leadingEnergy += leading * leading
                trailingEnergy += trailing * trailing
            }
            let denominator = sqrt(leadingEnergy * trailingEnergy)
            if denominator > 1e-18 {
                maximum = max(maximum, cross / denominator)
            }
        }
        return (min(1, max(0, maximum)), emphasized.count)
    }
}

struct SpectralTextureState: Equatable, Sendable {
    var activePatch: InstrumentPatch?
    var activePitchIdentity: MusicalPitchIdentity?
    var phaseA = 0.0
    var phaseB = 0.0
    var phaseC = 0.0
    var low = 0.0
    var band = 0.0
    var resonator = 0.0
    var previousResonator = 0.0
    var harmonicPhase = 0.0
    var harmonicLFOPhase = 0.0
    var harmonicBandIntegrator = 0.0
    var harmonicLowIntegrator = 0.0
    var dcInput = 0.0
    var dcOutput = 0.0
    var frequency = 220.0
    var noiseCursor: UInt64 = 0

    mutating func prepare(assignment: InstrumentAssignment) {
        let patch = assignment.patch
        let pitchIdentity = assignment.musicalPitchIdentity
        guard patch.architecture == .spectralTexture else { return }
        if activePatch != nil &&
            (activePatch != patch || activePitchIdentity != pitchIdentity) {
            low = 0
            band = 0
            resonator = 0
            previousResonator = 0
            harmonicBandIntegrator = 0
            harmonicLowIntegrator = 0
            dcInput = 0
            dcOutput = 0
        }
        activePatch = patch
        activePitchIdentity = pitchIdentity
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
        indefinitePitchMeasurement: inout [Float],
        clusterMeasurement: inout [Float],
        harmonicTailMeasurement: inout [Float],
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
              indefinitePitchMeasurement.isEmpty ||
                output.count == indefinitePitchMeasurement.count,
              clusterMeasurement.isEmpty ||
                output.count == clusterMeasurement.count,
              harmonicTailMeasurement.isEmpty ||
                output.count == harmonicTailMeasurement.count,
              output.count == pulseEchoSend.count,
              output.count == spatialReverbSend.count else { return }
        let scheduled = notes.filter {
            $0.instrument.architecture == .spectralTexture &&
                $0.startFrame < output.count && $0.durationFrames > 0
        }.sorted {
            if $0.startFrame != $1.startFrame {
                return $0.startFrame < $1.startFrame
            }
            let lhsRole = SynthRole.allCases.firstIndex(of: $0.role) ?? 0
            let rhsRole = SynthRole.allCases.firstIndex(of: $1.role) ?? 0
            if lhsRole != rhsRole { return lhsRole < rhsRole }
            return (InstrumentPatch.allCases.firstIndex(
                of: $0.instrument.patch
            ) ?? 0) < (InstrumentPatch.allCases.firstIndex(
                of: $1.instrument.patch
            ) ?? 0)
        }
        for note in scheduled {
            state.prepare(assignment: note.instrument)
            let frames = min(note.durationFrames, output.count - note.startFrame)
            guard frames > 0 else { continue }
            let automation = note.instrument.automation
            let velocity = min(1, max(0, note.velocity))
            let attackSeconds = 0.008 + automation.shape * 0.28
            let releaseSeconds = 0.08 + automation.shape * 1.12
            let attackFrames = max(1, Int((attackSeconds * sampleRate).rounded()))
            let indefinitePitch = note.instrument.musicalPitchIdentity ==
                .indefinitePitch
            let targetFrequency = indefinitePitch ? 0 : max(45, note.endFrequency)
            let requestedStart = indefinitePitch ? 0 : max(45, note.frequency)
            if !indefinitePitch { state.frequency = requestedStart }
            let glide = 1 - exp(-1 / max(1, sampleRate * (0.04 + automation.motion * 0.22)))
            let clusterTreatment = SpectralTextureClusterContract.treatment(
                for: note.instrument
            )
            let harmonicTailTreatment =
                SpectralTextureHarmonicTailContract.treatment(
                    for: note.instrument,
                    startFrequency: requestedStart,
                    endFrequency: targetFrequency,
                    sampleRate: sampleRate
                )
            let maximumRatio = clusterTreatment == nil ? 1 :
                SpectralTextureClusterContract.maximumComponentRatio
            var minimumFoldedSourceFrequency = Double.infinity
            var maximumFoldedSourceFrequency = 0.0
            var minimumBandCenterHz = Double.infinity
            var maximumBandCenterHz = 0.0
            var appliedFrequencyAtEnd = indefinitePitch ? 0 : min(
                sampleRate * 0.12 / maximumRatio, requestedStart
            )
            let patchRatios: (Double, Double, Double)
            if let ratios = clusterTreatment?.componentRatios,
               ratios.count == 3 {
                patchRatios = (ratios[0], ratios[1], ratios[2])
            } else {
                patchRatios = switch note.instrument.patch {
                case .alienNoise: (1.71, 2.43, 3.19)
                case .metalVeil: (2.01, 3.97, 5.03)
                case .dustCloud: (0.51, 1.13, 1.91)
                case .voltageArc: (1, 1, 1)
                case .bassPulse, .bassPluck, .acidThread, .acidSequence,
                     .northStar, .darkChord, .glassRunner:
                    (1, 1.5, 2)
                }
            }
            for index in 0..<frames {
                let progress = frames > 1 ? Double(index) / Double(frames - 1) : 1
                let frequency: Double
                if indefinitePitch {
                    frequency = 0
                } else {
                    let desiredFrequency = requestedStart +
                        (targetFrequency - requestedStart) * progress
                    state.frequency += (desiredFrequency - state.frequency) * glide
                    frequency = min(
                        sampleRate * 0.12 / maximumRatio,
                        state.frequency
                    )
                    appliedFrequencyAtEnd = frequency
                }
                let colored: Double
                if indefinitePitch {
                    let salt = noiseSalt(for: note.instrument.patch)
                    let a = deterministicNoise(
                        index: state.noiseCursor,
                        salt: salt
                    )
                    let b = deterministicNoise(
                        index: state.noiseCursor &+ 0x9E37_79B9,
                        salt: salt ^ 0xD1B5_4A32_D192_ED03
                    )
                    let c = deterministicNoise(
                        index: state.noiseCursor &+ 0x85EB_CA6B,
                        salt: salt ^ 0x94D0_49BB_1331_11EB
                    )
                    state.noiseCursor &+= 1
                    let source = switch note.instrument.patch {
                    case .alienNoise:
                        a * 0.64 + (b * c) * 0.36
                    case .metalVeil:
                        (a - b) * 0.44 + (b * c) * 0.28
                    case .dustCloud:
                        a * 0.48 + b * 0.22 + (a * c) * 0.30
                    case .voltageArc, .bassPulse, .bassPluck, .acidThread,
                         .acidSequence, .northStar, .darkChord, .glassRunner:
                        a
                    }
                    let cutoff = min(
                        sampleRate * 0.34,
                        1_200 + automation.color * 8_800
                    )
                    let coefficient = min(
                        0.72,
                        max(0.02, 1 - exp(-2 * .pi * cutoff / sampleRate))
                    )
                    state.low += (source - state.low) * coefficient
                    let high = source - state.low
                    state.band += (high - state.band) *
                        min(0.64, coefficient * 0.74)
                    colored = high * (0.62 - automation.motion * 0.16) +
                        state.band * (0.38 + automation.motion * 0.16)
                } else if let harmonicTailTreatment {
                    let sourceFrequency =
                        harmonicTailTreatment.startFoldedSourceFrequency +
                        (harmonicTailTreatment.endFoldedSourceFrequency -
                            harmonicTailTreatment.startFoldedSourceFrequency) * progress
                    minimumFoldedSourceFrequency = min(
                        minimumFoldedSourceFrequency,
                        sourceFrequency
                    )
                    maximumFoldedSourceFrequency = max(
                        maximumFoldedSourceFrequency,
                        sourceFrequency
                    )
                    let phaseStep = sourceFrequency / sampleRate
                    state.harmonicPhase = wrap(state.harmonicPhase + phaseStep)
                    let saw = state.harmonicPhase * 2 - 1 -
                        polyBLEP(phase: state.harmonicPhase, phaseStep: phaseStep)
                    let drivenSource = saturate(
                        saw * harmonicTailTreatment.prefilterDrive
                    )
                    state.harmonicLFOPhase = wrap(
                        state.harmonicLFOPhase +
                            harmonicTailTreatment.lfoRateHz / sampleRate
                    )
                    let center = harmonicTailTreatment.baseBandCenterHz +
                        fastSine(state.harmonicLFOPhase) *
                            harmonicTailTreatment.centerExcursionHz
                    minimumBandCenterHz = min(minimumBandCenterHz, center)
                    maximumBandCenterHz = max(maximumBandCenterHz, center)

                    // Topology-preserving-transform state-variable band-pass.
                    // The two integrators live in the existing patch state, so
                    // note gates never reset filter or modulation continuation.
                    let g = tan(.pi * center / sampleRate)
                    let damping = 1 / harmonicTailTreatment.resonance
                    let a1 = 1 / (1 + g * (g + damping))
                    let a2 = g * a1
                    let a3 = g * a2
                    let v3 = drivenSource - state.harmonicLowIntegrator
                    let band = a1 * state.harmonicBandIntegrator + a2 * v3
                    let low = state.harmonicLowIntegrator +
                        a2 * state.harmonicBandIntegrator + a3 * v3
                    state.harmonicBandIntegrator =
                        2 * band - state.harmonicBandIntegrator
                    state.harmonicLowIntegrator =
                        2 * low - state.harmonicLowIntegrator
                    colored = band * (0.92 + automation.color * 0.36)
                } else {
                    state.phaseA = wrap(
                        state.phaseA + frequency * patchRatios.0 / sampleRate
                    )
                    state.phaseB = wrap(
                        state.phaseB + frequency * patchRatios.1 / sampleRate
                    )
                    state.phaseC = wrap(
                        state.phaseC + frequency * patchRatios.2 / sampleRate
                    )
                    let a = fastSine(state.phaseA)
                    let b = fastSine(state.phaseB)
                    let c = fastSine(state.phaseC)
                    let source: Double
                    if clusterTreatment != nil {
                        source = a * 0.38 + b * 0.34 + c * 0.28
                    } else {
                        source = switch note.instrument.patch {
                        case .alienNoise:
                            a * b * 0.62 + b * c * 0.24 + a * 0.14
                        case .metalVeil:
                            (a * b) * 0.50 + (b * c) * 0.34 + c * 0.16
                        case .dustCloud:
                            a * 0.42 + a * b * 0.26 + b * c * 0.18 + c * 0.14
                        case .voltageArc:
                            0
                        case .bassPulse, .bassPluck, .acidThread, .acidSequence,
                             .northStar, .darkChord, .glassRunner:
                            a
                        }
                    }
                    let cutoff = min(
                        sampleRate * 0.16,
                        220 + automation.color * 4_800 +
                            fastSine(wrap(state.phaseC * 0.19)) *
                                automation.motion * 720
                    )
                    let coefficient = min(
                        0.48,
                        max(0.002, 2 * .pi * cutoff / sampleRate)
                    )
                    state.low += (source - state.low) * coefficient
                    let high = source - state.low
                    state.band += (high - state.band) *
                        min(0.42, coefficient * 0.62)
                    let resonatorFrequency = min(
                        sampleRate * 0.14,
                        frequency * (2.0 + automation.color * 5.0)
                    )
                    let resonatorCoefficient = 2 * cos(
                        2 * .pi * resonatorFrequency / sampleRate
                    )
                    let damping = 0.72 + automation.motion * 0.245
                    let resonatorInput = state.band *
                        (0.16 + automation.motion * 0.34)
                    let resonated = resonatorInput + resonatorCoefficient * damping *
                        state.resonator - damping * damping * state.previousResonator
                    state.previousResonator = state.resonator
                    state.resonator = min(2, max(-2, resonated))
                    colored = state.band * (0.74 - automation.motion * 0.20) +
                        state.resonator * (0.18 + automation.motion * 0.28)
                }
                let age = Double(index) / sampleRate
                let attack = min(1, Double(index) / Double(attackFrames))
                let release = exp(-max(0, age - attackSeconds) / releaseSeconds)
                let envelope = attack * release
                let driven = harmonicTailTreatment != nil
                    ? saturate(colored * 1.18)
                    : note.instrument.effects.contains(.drive)
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
                if indefinitePitch && !indefinitePitchMeasurement.isEmpty {
                    indefinitePitchMeasurement[frame] += sample
                }
                if clusterTreatment != nil && !clusterMeasurement.isEmpty {
                    clusterMeasurement[frame] += sample
                }
                if harmonicTailTreatment != nil &&
                    !harmonicTailMeasurement.isEmpty {
                    harmonicTailMeasurement[frame] += sample
                }
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
                frequencyAtAppliedGateEnd: appliedFrequencyAtEnd,
                requestedEndFrequency: note.endFrequency,
                requestedGate: note.gate,
                appliedGate: .retrigger,
                didRetrigger: true,
                timbreIntent: note.timbreIntent,
                spectralReveal: note.spectralReveal,
                requestedVelocity: note.velocity,
                appliedVelocity: velocity,
                velocitySpectralEnvelopeScale: 0.82 + velocity * 0.36,
                velocityDecayScale: 0.90 + velocity * 0.18,
                instrument: note.instrument,
                spectralTextureCluster: clusterTreatment.map {
                    SpectralTextureClusterEventRenderEvidence(
                        relation: $0.relation,
                        componentRatios: $0.componentRatios,
                        renderedFrameCount: frames
                    )
                },
                spectralTextureHarmonicTail: harmonicTailTreatment.map {
                    SpectralTextureHarmonicTailEventRenderEvidence(
                        relation: $0.relation,
                        minimumFoldedSourceFrequency:
                            minimumFoldedSourceFrequency,
                        maximumFoldedSourceFrequency:
                            maximumFoldedSourceFrequency,
                        minimumBandCenterHz: minimumBandCenterHz,
                        maximumBandCenterHz: maximumBandCenterHz,
                        resonance: $0.resonance,
                        prefilterDrive: $0.prefilterDrive,
                        lfoRateHz: $0.lfoRateHz,
                        renderedFrameCount: frames
                    )
                }
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

    private static func polyBLEP(phase: Double, phaseStep: Double) -> Double {
        guard phaseStep > 0, phaseStep < 1 else { return 0 }
        if phase < phaseStep {
            let x = phase / phaseStep
            return x + x - x * x - 1
        }
        if phase > 1 - phaseStep {
            let x = (phase - 1) / phaseStep
            return x * x + x + x + 1
        }
        return 0
    }

    private static func noiseSalt(for patch: InstrumentPatch) -> UInt64 {
        switch patch {
        case .alienNoise: 0xA11E_4E01_5EED_0001
        case .metalVeil: 0x4D45_5441_4C00_0002
        case .dustCloud: 0xD057_C10D_5EED_0003
        case .voltageArc: 0x7017_A6E0_0000_0004
        case .bassPulse, .bassPluck, .acidThread, .acidSequence,
             .northStar, .darkChord, .glassRunner:
            0x5EED_0000_0000_0005
        }
    }

    private static func deterministicNoise(index: UInt64, salt: UInt64) -> Double {
        var value = index &+ salt &+ 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        let unit = Double(value >> 11) / 9_007_199_254_740_992
        return unit * 2 - 1
    }
}
