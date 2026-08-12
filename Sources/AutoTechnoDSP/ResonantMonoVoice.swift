import AutoTechnoCore
import Foundation

/// Current bounded rendering parameters for the durable score-owned acid
/// relation. These values are deliberately renderer-owned: a later serious
/// DSP implementation may replace them while preserving the relation and its
/// evidence contract.
package struct ResonantMonoModulationTreatment: Equatable, Sendable {
    package let relation: ResonantMonoSpectralRelation
    package let modulatorRatio: Double
    package let requestedPeakIndex: Double
    package let operatorWeight: Double
}

/// Same-pass event fact produced by the exact resonant-mono render call. It is
/// reduced with the operator tap before the immutable RenderBlock is formed.
package struct ResonantMonoModulationEventRenderEvidence: Equatable, Sendable {
    package let relation: ResonantMonoSpectralRelation
    package let modulatorRatio: Double
    package let requestedPeakIndex: Double
    package let appliedPeakIndex: Double
    package let renderedFrameCount: Int
}

package enum ResonantMonoModulationContract {
    package static let highPassHz = 120.0
    package static let maximumLowBandEnergyRatio = 0.36
    package static let maximumRequestedPeakIndex = 2.10

    package static func treatment(
        for assignment: InstrumentAssignment
    ) -> ResonantMonoModulationTreatment? {
        guard let relation = assignment.resonantMonoSpectralRelation else {
            return nil
        }
        switch relation {
        case .orderedHollow:
            return ResonantMonoModulationTreatment(
                relation: relation,
                modulatorRatio: 2.0,
                requestedPeakIndex: min(
                    maximumRequestedPeakIndex,
                    0.45 + assignment.automation.color * 0.55 +
                        assignment.automation.motion * 0.25
                ),
                operatorWeight: 0.05
            )
        case .metallicTension:
            return ResonantMonoModulationTreatment(
                relation: relation,
                modulatorRatio: 1.414_213_562_373_095_1,
                requestedPeakIndex: min(
                    maximumRequestedPeakIndex,
                    0.65 + assignment.automation.color * 0.75 +
                        assignment.automation.motion * 0.65
                ),
                operatorWeight: 0.065
            )
        }
    }

    /// A conservative four-sideband budget limits the current non-oversampled
    /// operator before it can fold substantial energy across Nyquist.
    package static func maximumSafePeakIndex(
        modulatorRatio: Double,
        carrierHz: Double,
        sampleRate: Double
    ) -> Double {
        guard modulatorRatio > 0, carrierHz > 0, sampleRate > 0 else { return 0 }
        let sidebandBudget = sampleRate * 0.42 / carrierHz - 1
        return max(0, sidebandBudget / (modulatorRatio * 4))
    }
}

struct ResonantMonoState: Equatable, Sendable {
    var activePatch: InstrumentPatch?
    var phase = 0.0
    var subPhase = 0.0
    var filter1 = 0.0
    var filter2 = 0.0
    var filter3 = 0.0
    var filter4 = 0.0
    var dcInput = 0.0
    var dcOutput = 0.0
    var frequency = 55.0
    var envelope = 0.0

    mutating func prepare(patch: InstrumentPatch) {
        guard patch.architecture == .resonantMono else { return }
        if let activePatch, activePatch != patch {
            filter1 = 0
            filter2 = 0
            filter3 = 0
            filter4 = 0
            dcInput = 0
            dcOutput = 0
            envelope = 0
        }
        activePatch = patch
    }
}

/// A mono, accent- and slide-aware resonant instrument used by both the
/// protected foundation and eligible upper sequences. It runs only during
/// detached preparation; its bounded continuation lives in `RenderState`.
enum ResonantMonoVoice {
    static func renderFoundation(
        _ output: inout [Float],
        measurement: inout [Float],
        architectureMeasurement: inout [Float],
        pulseEchoSend: inout [Float],
        spatialReverbSend: inout [Float],
        start: Int,
        sampleRate: Double,
        level: Double,
        frequency: Double,
        assignment: InstrumentAssignment,
        velocity: Double,
        state: inout ResonantMonoState
    ) {
        guard assignment.architecture == .resonantMono,
              assignment.use == .foundationBass else { return }
        let duration = 0.16 + assignment.automation.shape * 0.18
        var noModulationMeasurement: [Float] = []
        _ = renderEvent(
            output: &output,
            roleMeasurement: &measurement,
            architectureMeasurement: &architectureMeasurement,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            start: start,
            durationFrames: max(1, Int((sampleRate * duration).rounded())),
            sampleRate: sampleRate,
            level: level,
            startFrequency: frequency,
            endFrequency: frequency,
            velocity: velocity,
            gate: .retrigger,
            assignment: assignment,
            state: &state,
            modulationMeasurement: &noModulationMeasurement
        )
    }

    static func renderUpper(
        _ output: inout [Float],
        measurement: inout [Float],
        architectureMeasurement: inout [Float],
        pulseEchoSend: inout [Float],
        spatialReverbSend: inout [Float],
        modulationMeasurement: inout [Float],
        noteRenderEvidence: inout [UpperNoteRenderEvidence],
        notes: [AlienVoiceNote],
        sampleRate: Double,
        level: Double,
        state: inout ResonantMonoState
    ) {
        let scheduled = notes.filter {
            $0.instrument.architecture == .resonantMono &&
                $0.startFrame < output.count && $0.durationFrames > 0
        }.sorted {
            $0.startFrame == $1.startFrame ? $0.frequency < $1.frequency :
                $0.startFrame < $1.startFrame
        }
        for note in scheduled {
            let hadCompatibleContinuation = state.activePatch == note.instrument.patch &&
                state.envelope > 0.000_001
            let appliedGate: UpperNoteGate = note.gate == .slide && hadCompatibleContinuation
                ? .slide : .retrigger
            let appliedStart = appliedGate == .slide ? state.frequency : note.frequency
            let result = renderEvent(
                output: &output,
                roleMeasurement: &measurement,
                architectureMeasurement: &architectureMeasurement,
                pulseEchoSend: &pulseEchoSend,
                spatialReverbSend: &spatialReverbSend,
                start: note.startFrame,
                durationFrames: note.durationFrames,
                sampleRate: sampleRate,
                level: level * note.dryScale,
                startFrequency: appliedStart,
                endFrequency: note.endFrequency,
                velocity: note.velocity,
                gate: appliedGate,
                assignment: note.instrument,
                state: &state,
                modulationMeasurement: &modulationMeasurement
            )
            let requestedEnd = note.startFrame.addingReportingOverflow(note.durationFrames)
            let requestedGateEnd = requestedEnd.overflow ? Int.max : requestedEnd.partialValue
            let appliedEnd = min(
                output.count,
                note.startFrame + result.renderedFrameCount
            )
            noteRenderEvidence.append(UpperNoteRenderEvidence(
                role: note.role,
                onsetFrame: note.startFrame,
                requestedGateEndFrame: requestedGateEnd,
                appliedGateEndFrame: appliedEnd,
                requestedStartFrequency: note.frequency,
                appliedStartFrequency: appliedStart,
                targetEndFrequency: note.endFrequency,
                frequencyAtAppliedGateEnd: state.frequency,
                requestedGate: note.gate,
                appliedGate: appliedGate,
                didRetrigger: appliedGate == .retrigger,
                timbreIntent: note.timbreIntent,
                requestedVelocity: note.velocity,
                appliedVelocity: min(1, max(0, note.velocity)),
                velocitySpectralEnvelopeScale: 0.72 + min(1, max(0, note.velocity)) * 0.72,
                velocityDecayScale: 0.86 + min(1, max(0, note.velocity)) * 0.22,
                instrument: note.instrument,
                resonantMonoModulation: result.modulation
            ))
        }
    }

    @discardableResult
    private static func renderEvent(
        output: inout [Float],
        roleMeasurement: inout [Float],
        architectureMeasurement: inout [Float],
        pulseEchoSend: inout [Float],
        spatialReverbSend: inout [Float],
        start: Int,
        durationFrames: Int,
        sampleRate: Double,
        level: Double,
        startFrequency: Double,
        endFrequency: Double,
        velocity: Double,
        gate: UpperNoteGate,
        assignment: InstrumentAssignment,
        state: inout ResonantMonoState,
        modulationMeasurement: inout [Float]
    ) -> (renderedFrameCount: Int,
          modulation: ResonantMonoModulationEventRenderEvidence?) {
        guard sampleRate > 0, start >= 0, start < output.count,
              roleMeasurement.count == output.count,
              architectureMeasurement.count == output.count,
              pulseEchoSend.count == output.count,
              spatialReverbSend.count == output.count,
              modulationMeasurement.isEmpty ||
                modulationMeasurement.count == output.count else { return (0, nil) }
        let frames = min(durationFrames, output.count - start)
        guard frames > 0 else { return (0, nil) }
        state.prepare(patch: assignment.patch)
        let automation = assignment.automation
        let boundedVelocity = min(1, max(0, velocity))
        let attackSeconds = 0.0015 + (1 - automation.shape) * 0.006
        let decaySeconds = 0.055 + (1 - automation.shape) * 0.31
        let attackFrames = max(1, Int((sampleRate * attackSeconds).rounded()))
        let drive = assignment.effects.contains(.drive)
            ? 1.18 + automation.motion * 1.12 : 1
        let resonance = min(0.88, 0.24 + automation.motion * 0.55)
        let baseCutoff = 72 + automation.color * 620
        let envelopeDepth = 180 + automation.color * 760 + automation.motion * 820
        let pulseWidth = 0.30 + automation.shape * 0.28
        let pulseWeight: Double = switch assignment.patch {
        case .bassPulse: 0.16
        case .bassPluck: 0.24
        case .acidThread: 0.36
        case .acidSequence: 0.45
        case .northStar, .darkChord, .glassRunner, .alienNoise, .metalVeil, .dustCloud: 0
        }
        let sawWeight = assignment.patch == .bassPulse ? 0.18 : 0.46
        let sineWeight = max(0.16, 1 - pulseWeight - sawWeight)
        let requestedStart = max(20, startFrequency)
        if gate == .retrigger {
            state.frequency = requestedStart
            state.envelope = min(state.envelope, 0.08)
        }
        let targetFrequency = max(20, endFrequency)
        let glideSeconds = 0.004 + automation.motion * 0.075
        let glideCoefficient = 1 - exp(-1 / max(1, sampleRate * glideSeconds))
        let modulationTreatment = ResonantMonoModulationContract.treatment(
            for: assignment
        )
        let highPassCoefficient = exp(
            -2 * .pi * ResonantMonoModulationContract.highPassHz / sampleRate
        )
        var modulatorPhase = 0.0
        var firstHighPassInput = 0.0
        var firstHighPassOutput = 0.0
        var secondHighPassInput = 0.0
        var secondHighPassOutput = 0.0
        var appliedPeakIndex = 0.0
        var renderedCount = 0
        for index in 0..<frames {
            let age = Double(index) / sampleRate
            let attack = min(1, Double(index) / Double(attackFrames))
            let decay = exp(-max(0, age - attackSeconds) / decaySeconds)
            let targetEnvelope = attack * decay
            state.envelope += (targetEnvelope - state.envelope) * 0.32
            let progress = frames > 1 ? Double(index) / Double(frames - 1) : 1
            let requestedFrequency = requestedStart +
                (targetFrequency - requestedStart) * progress
            state.frequency += (requestedFrequency - state.frequency) * glideCoefficient
            let frequency = min(sampleRate * 0.18, max(20, state.frequency))
            let increment = frequency / sampleRate
            state.phase = wrap(state.phase + increment)
            state.subPhase = wrap(state.subPhase + increment * 0.5)
            let saw = bandLimitedSaw(state.phase, increment: increment)
            let pulse = bandLimitedPulse(
                state.phase,
                increment: increment,
                width: pulseWidth
            )
            let legacySource = sin(2 * .pi * state.subPhase) * sineWeight +
                saw * sawWeight + pulse * pulseWeight
            let modulationDelta: Double
            if let treatment = modulationTreatment {
                modulatorPhase = wrap(
                    modulatorPhase + increment * treatment.modulatorRatio
                )
                let progress = frames > 1
                    ? Double(index) / Double(frames - 1) : 1
                let aperture = index == 0 || index == frames - 1
                    ? 0 : sin(.pi * progress)
                let safePeak = min(
                    treatment.requestedPeakIndex,
                    ResonantMonoModulationContract.maximumSafePeakIndex(
                        modulatorRatio: treatment.modulatorRatio,
                        carrierHz: frequency,
                        sampleRate: sampleRate
                    )
                )
                let appliedIndex = max(0, safePeak * aperture)
                appliedPeakIndex = max(appliedPeakIndex, appliedIndex)
                let phaseOffset = appliedIndex * sin(2 * .pi * modulatorPhase) /
                    (2 * .pi)
                let modulatedCarrier = sin(2 * .pi * wrap(state.phase + phaseOffset))
                let unmodulatedCarrier = sin(2 * .pi * state.phase)
                let rawDelta = modulatedCarrier - unmodulatedCarrier
                let firstHighPassed = rawDelta - firstHighPassInput +
                    highPassCoefficient * firstHighPassOutput
                firstHighPassInput = rawDelta
                firstHighPassOutput = firstHighPassed
                let secondHighPassed = firstHighPassed - secondHighPassInput +
                    highPassCoefficient * secondHighPassOutput
                secondHighPassInput = firstHighPassed
                secondHighPassOutput = secondHighPassed
                modulationDelta = secondHighPassed * aperture *
                    treatment.operatorWeight
                if !modulationMeasurement.isEmpty {
                    modulationMeasurement[start + index] += Float(modulationDelta)
                }
            } else {
                modulationDelta = 0
            }
            let source = legacySource + modulationDelta
            let accentLift = boundedVelocity * (0.42 + automation.motion * 0.42)
            let cutoff = min(
                sampleRate * 0.16,
                baseCutoff + state.envelope * envelopeDepth * (0.72 + accentLift)
            )
            let rawCoefficient = 2 * .pi * cutoff / sampleRate
            let coefficient = min(0.42, max(0.002, rawCoefficient / (1 + rawCoefficient)))
            let feedback = state.filter4 * resonance
            let driven = saturate((source - feedback) * drive)
            state.filter1 += (driven - state.filter1) * coefficient
            state.filter2 += (saturate(state.filter1 * 1.07) - state.filter2) * coefficient
            state.filter3 += (saturate(state.filter2 * 1.05) - state.filter3) * coefficient
            state.filter4 += (saturate(state.filter3 * 1.03) - state.filter4) * coefficient
            let body = state.filter3 * 0.70 + state.filter2 * 0.30
            let shaped = saturate(body * (1.05 + automation.motion * 0.42))
            let dcBlocked = shaped - state.dcInput + 0.995 * state.dcOutput
            state.dcInput = shaped
            state.dcOutput = dcBlocked
            let sample = Float(
                dcBlocked * state.envelope * boundedVelocity * max(0, level)
            )
            let frame = start + index
            output[frame] += sample
            roleMeasurement[frame] += sample
            architectureMeasurement[frame] += sample
            if assignment.effects.contains(.pulseEcho) {
                pulseEchoSend[frame] += sample * Float(0.08 + automation.space * 0.24)
            }
            if assignment.effects.contains(.filteredReverb) {
                spatialReverbSend[frame] += sample * Float(automation.space * 0.32)
            }
            renderedCount += 1
        }
        let modulationEvidence = modulationTreatment.map {
            ResonantMonoModulationEventRenderEvidence(
                relation: $0.relation,
                modulatorRatio: $0.modulatorRatio,
                requestedPeakIndex: $0.requestedPeakIndex,
                appliedPeakIndex: appliedPeakIndex,
                renderedFrameCount: renderedCount
            )
        }
        return (renderedCount, modulationEvidence)
    }

    private static func saturate(_ value: Double) -> Double {
        value / (1 + abs(value) * 0.56)
    }

    private static func wrap(_ phase: Double) -> Double {
        let result = phase.truncatingRemainder(dividingBy: 1)
        return result < 0 ? result + 1 : result
    }

    private static func bandLimitedSaw(_ phase: Double, increment: Double) -> Double {
        2 * phase - 1 - polyBLEP(phase, increment: increment)
    }

    private static func bandLimitedPulse(
        _ phase: Double,
        increment: Double,
        width: Double
    ) -> Double {
        let boundedWidth = min(0.8, max(0.2, width))
        let naive = phase < boundedWidth ? 1.0 : -1.0
        let first = polyBLEP(phase, increment: increment)
        let shifted = wrap(phase - boundedWidth)
        return naive + first - polyBLEP(shifted, increment: increment)
    }

    private static func polyBLEP(_ phase: Double, increment: Double) -> Double {
        let width = min(0.5, max(0.000_001, increment))
        if phase < width {
            let value = phase / width
            return value + value - value * value - 1
        }
        if phase > 1 - width {
            let value = (phase - 1) / width
            return value * value + value + value + 1
        }
        return 0
    }
}
