import AutoTechnoCore
import Foundation

struct AlienVoiceNote: Equatable, Sendable {
    let startFrame: Int
    let durationFrames: Int
    let frequency: Double
    let endFrequency: Double
    let velocity: Double
    let gate: UpperNoteGate
    let timbreIntent: UpperTimbreIntent
    let envelopeRelation: UpperEnvelopeRelation
    let spectralReveal: UpperSpectralRevealArticulation
    let instrument: InstrumentAssignment
    let role: SynthRole
    let articulation: RelationalArticulation
    let dryScale: Double
    let spatialReverbSend: Double
    let narrativeGainScale: Double
    let narrativeSpectralScale: Double

    init(startFrame: Int, durationFrames: Int, frequency: Double,
         endFrequency: Double, velocity: Double, gate: UpperNoteGate,
         timbreIntent: UpperTimbreIntent,
         envelopeRelation: UpperEnvelopeRelation = .home,
         spectralReveal: UpperSpectralRevealArticulation = .home,
         instrument: InstrumentAssignment, role: SynthRole,
         articulation: RelationalArticulation, dryScale: Double,
         spatialReverbSend: Double, narrativeGainScale: Double,
         narrativeSpectralScale: Double) {
        self.startFrame = startFrame
        self.durationFrames = durationFrames
        self.frequency = frequency
        self.endFrequency = endFrequency
        self.velocity = velocity
        self.gate = gate
        self.timbreIntent = timbreIntent
        self.envelopeRelation = envelopeRelation
        self.spectralReveal = spectralReveal
        self.instrument = instrument
        self.role = role
        self.articulation = articulation
        self.dryScale = dryScale
        self.spatialReverbSend = spatialReverbSend
        self.narrativeGainScale = narrativeGainScale
        self.narrativeSpectralScale = narrativeSpectralScale
    }
}

struct AlienVoiceState: Equatable, Sendable {
    var activeInstrument: InstrumentAssignment?
    var phaseA = 0.0
    var phaseB = 0.0
    var modPhase = 0.0
    var noisePhaseA = 0.0
    var noisePhaseB = 0.0
    var driftPhase = 0.0
    var drift = 0.0
    var frequency = 65.41
    var envelope = 0.0
    var filterEnvelope = 0.0
    var timbreIntent = UpperTimbreIntent.home
    var timbreVelocity = 0.0
    var timbreTreatment = AlienTimbreTreatment.neutral
    var velocityResponse = AlienVelocityResponse.neutral
    var envelopeRelation = UpperEnvelopeRelation.home
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

    mutating func prepare(sampleRate: Double, world: SynthWorldDNA, role: SynthRole,
                          instrument: InstrumentAssignment) {
        if let activeInstrument, activeInstrument.patch != instrument.patch {
            envelope = 0
            filterEnvelope = 0
            timbreIntent = .home
            timbreVelocity = 0
            timbreTreatment = .neutral
            velocityResponse = .neutral
            envelopeRelation = .home
            filter1 = 0
            filter2 = 0
            filter3 = 0
            filter4 = 0
            mutationLow = 0
            oversampleLow = 0
            previousSource = 0
            echoLow = 0
            dcInput = 0
            dcOutput = 0
            tailLevel = 0
            for index in comb.indices { comb[index] = 0 }
            combIndex = 0
            for index in allPass.indices { allPass[index] = 0 }
            allPassIndex = 0
            for index in echo.indices { echo[index] = 0 }
            echoIndex = 0
        }
        activeInstrument = instrument
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

/// A bounded DSP projection of the score-owned timbre request. It reuses the
/// authored oscillator and filter topology; it does not select another voice
/// or add an effect path.
struct AlienTimbreTreatment: Equatable, Sendable {
    let amplitudeScale: Double
    let filterEnvelopeDepth: Double
    let filterEnvelopeDecaySeconds: Double
    let driveScale: Double
    let resonanceLift: Double
    let detuneRatioLift: Double

    static let neutral = AlienTimbreTreatment(
        amplitudeScale: 1,
        filterEnvelopeDepth: 0,
        filterEnvelopeDecaySeconds: 0.08,
        driveScale: 1,
        resonanceLift: 0,
        detuneRatioLift: 0
    )

    static func resolve(intent: UpperTimbreIntent, velocity: Double,
                        role: SynthRole) -> AlienTimbreTreatment {
        let amount = min(1, max(0, intent.amount))
        let accent = min(1, max(0, velocity))
        guard amount > 0 else { return .neutral }
        switch intent.kind {
        case .resonantSequence where role == .anchor:
            return AlienTimbreTreatment(
                amplitudeScale: min(1.14, 1 + amount * (0.04 + accent * 0.10)),
                filterEnvelopeDepth: amount * (480 + accent * 720),
                filterEnvelopeDecaySeconds: 0.055 + (1 - accent) * 0.055,
                driveScale: 1 + amount * (0.08 + accent * 0.18),
                resonanceLift: amount * (0.035 + accent * 0.075),
                detuneRatioLift: 0
            )
        case .detunedMotion where role == .shadow || role == .response:
            return AlienTimbreTreatment(
                amplitudeScale: 1,
                filterEnvelopeDepth: 0,
                filterEnvelopeDecaySeconds: 0.08,
                driveScale: 1,
                resonanceLift: 0,
                detuneRatioLift: amount * (0.002 + accent * 0.004)
            )
        case .home, .resonantSequence, .detunedMotion:
            return .neutral
        }
    }

    func interpolated(toward target: AlienTimbreTreatment,
                      amount: Double) -> AlienTimbreTreatment {
        let amount = min(1, max(0, amount))
        func value(_ current: Double, _ destination: Double) -> Double {
            current + (destination - current) * amount
        }
        let result = AlienTimbreTreatment(
            amplitudeScale: value(amplitudeScale, target.amplitudeScale),
            filterEnvelopeDepth: value(filterEnvelopeDepth, target.filterEnvelopeDepth),
            filterEnvelopeDecaySeconds: value(
                filterEnvelopeDecaySeconds,
                target.filterEnvelopeDecaySeconds
            ),
            driveScale: value(driveScale, target.driveScale),
            resonanceLift: value(resonanceLift, target.resonanceLift),
            detuneRatioLift: value(detuneRatioLift, target.detuneRatioLift)
        )
        let maximumDelta = [
            abs(result.amplitudeScale - target.amplitudeScale),
            abs(result.filterEnvelopeDepth - target.filterEnvelopeDepth),
            abs(result.filterEnvelopeDecaySeconds - target.filterEnvelopeDecaySeconds),
            abs(result.driveScale - target.driveScale),
            abs(result.resonanceLift - target.resonanceLift),
            abs(result.detuneRatioLift - target.detuneRatioLift),
        ].max() ?? 0
        return maximumDelta < 0.000_000_001 ? target : result
    }
}

/// A bounded projection of the score-owned note velocity into the authored
/// anchor envelope. Velocity already controls level; this response lets the
/// same performance accent also open the existing filter-envelope lift and
/// relax the existing decay without adding another score parameter or voice.
struct AlienVelocityResponse: Equatable, Sendable {
    let spectralEnvelopeScale: Double
    let decayScale: Double

    static let neutral = AlienVelocityResponse(
        spectralEnvelopeScale: 1,
        decayScale: 1
    )

    static func resolve(velocity: Double, role: SynthRole) -> AlienVelocityResponse {
        guard role == .anchor else { return .neutral }
        let velocity = min(1, max(0, velocity))
        return AlienVelocityResponse(
            spectralEnvelopeScale: min(1.60, max(0.40, 0.40 + velocity * 1.20)),
            decayScale: min(1.20, max(0.80, 0.80 + velocity * 0.40))
        )
    }
}

/// Replaceable v1 projection of the durable sustained-wash relation. Home is
/// a literal pass-through so existing patch envelopes remain bit-identical.
package enum TonalEnvelopeExpansionContract {
    package static let targetSustain = 0.68
    package static let maximumSustain = 0.92
    package static let releaseScale = 3.2
    package static let maximumReleaseSeconds = 2.4

    package static func resolve(
        baseSustain: Double,
        baseReleaseSeconds: Double,
        relation: UpperEnvelopeRelation
    ) -> (sustain: Double, releaseSeconds: Double) {
        guard relation == .sustainedWash else {
            return (baseSustain, baseReleaseSeconds)
        }
        return (
            min(maximumSustain, max(baseSustain, targetSustain)),
            min(
                maximumReleaseSeconds,
                max(baseReleaseSeconds, baseReleaseSeconds * releaseScale)
            )
        )
    }
}

/// Patch-family projection for the tonal-motion topology. The shared semantic
/// automation coordinates remain score-owned; this type only translates them
/// into bounded oscillator, envelope, filter, and memory behavior.
private struct TonalPatchTreatment {
    let attackScale: Double
    let decayScale: Double
    let sustainScale: Double
    let releaseScale: Double
    let detuneScale: Double
    let modulationScale: Double
    let cutoffScale: Double
    let driveScale: Double
    let combScale: Double
    let echoScale: Double
    let sawAWeight: Double
    let sawBWeight: Double
    let pulseWeight: Double
    let noiseWeight: Double

    static func resolve(_ assignment: InstrumentAssignment) -> TonalPatchTreatment {
        let automation = assignment.automation
        let patchShape: (Double, Double, Double, Double, Double, Double, Double,
                         Double, Double, Double, Double, Double, Double, Double)
        switch assignment.patch {
        case .northStar:
            patchShape = (1.0, 1.0, 1.0, 1.0, 0.90, 0.90, 1.04,
                          1.0, 0.86, 0.78, 0.45, 0.25, 0.22, 0.08)
        case .darkChord:
            patchShape = (1.65, 1.72, 1.22, 1.70, 0.72, 0.62, 0.72,
                          0.92, 1.05, 1.18, 0.50, 0.30, 0.12, 0.08)
        case .glassRunner:
            patchShape = (0.62, 0.68, 0.72, 0.58, 1.28, 1.42, 1.30,
                          1.14, 1.24, 0.72, 0.34, 0.22, 0.34, 0.10)
        case .bassPulse, .bassPluck, .acidThread, .acidSequence,
             .alienNoise, .metalVeil, .dustCloud, .voltageArc:
            patchShape = (1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.43, 0.24, 0.24, 0.09)
        }
        return TonalPatchTreatment(
            attackScale: patchShape.0 * (1.22 - automation.shape * 0.44),
            decayScale: patchShape.1 * (0.72 + automation.shape * 0.62),
            sustainScale: patchShape.2,
            releaseScale: patchShape.3 * (0.70 + automation.shape * 0.68),
            detuneScale: patchShape.4 * (0.76 + automation.motion * 0.48),
            modulationScale: patchShape.5 * (0.62 + automation.motion * 0.76),
            cutoffScale: patchShape.6 * (0.70 + automation.color * 0.62),
            driveScale: patchShape.7 * (assignment.effects.contains(.drive)
                ? 1.04 + automation.motion * 0.34 : 1),
            combScale: assignment.effects.contains(.comb) ? patchShape.8 : 0,
            echoScale: assignment.effects.contains(.unsyncedEcho) ? patchShape.9 : 0,
            sawAWeight: patchShape.10,
            sawBWeight: patchShape.11,
            pulseWeight: patchShape.12,
            noiseWeight: patchShape.13
        )
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
                       noteRenderEvidence: inout [UpperNoteRenderEvidence],
                       notes: [AlienVoiceNote],
                       sampleRate: Double, level: Double,
                       world: SynthWorldDNA, bar: SynthPerformanceBar,
                       role: SynthRole, state: inout AlienVoiceState) {
        var architectureMeasurement = [Float](repeating: 0, count: output.count)
        var envelopeExpansionMeasurement = [Float](repeating: 0, count: output.count)
        render(
            &output,
            measurement: &measurement,
            architectureMeasurement: &architectureMeasurement,
            envelopeExpansionMeasurement: &envelopeExpansionMeasurement,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: notes,
            sampleRate: sampleRate,
            level: level,
            world: world,
            bar: bar,
            role: role,
            state: &state
        )
    }

    static func render(_ output: inout [Float], measurement: inout [Float],
                       architectureMeasurement: inout [Float],
                       pulseEchoSend: inout [Float],
                       spatialReverbSend: inout [Float],
                       noteRenderEvidence: inout [UpperNoteRenderEvidence],
                       notes: [AlienVoiceNote],
                       sampleRate: Double, level: Double,
                       world: SynthWorldDNA, bar: SynthPerformanceBar,
                       role: SynthRole, state: inout AlienVoiceState) {
        var envelopeExpansionMeasurement = [Float](repeating: 0, count: output.count)
        render(
            &output,
            measurement: &measurement,
            architectureMeasurement: &architectureMeasurement,
            envelopeExpansionMeasurement: &envelopeExpansionMeasurement,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: notes,
            sampleRate: sampleRate,
            level: level,
            world: world,
            bar: bar,
            role: role,
            state: &state
        )
    }

    static func render(_ output: inout [Float], measurement: inout [Float],
                       architectureMeasurement: inout [Float],
                       envelopeExpansionMeasurement: inout [Float],
                       pulseEchoSend: inout [Float],
                       spatialReverbSend: inout [Float],
                       noteRenderEvidence: inout [UpperNoteRenderEvidence],
                       notes: [AlienVoiceNote],
                       sampleRate: Double, level: Double,
                       world: SynthWorldDNA, bar: SynthPerformanceBar,
                       role: SynthRole, state: inout AlienVoiceState) {
        guard !output.isEmpty, sampleRate > 0 else { return }
        guard pulseEchoSend.count == output.count else { return }
        guard spatialReverbSend.count == output.count else { return }
        guard measurement.count == output.count else { return }
        guard architectureMeasurement.count == output.count else { return }
        guard envelopeExpansionMeasurement.count == output.count else { return }
        let scheduled = notes
            .filter {
                $0.instrument.architecture == .tonalMotion &&
                    $0.startFrame < output.count && $0.durationFrames > 0 && $0.frequency > 0
            }
            .sorted { lhs, rhs in
                lhs.startFrame == rhs.startFrame ? lhs.frequency < rhs.frequency : lhs.startFrame < rhs.startFrame
            }
        let assignment = scheduled.first?.instrument ?? state.activeInstrument ??
            InstrumentPalette.safeUpper(role: role)
        state.prepare(
            sampleRate: sampleRate,
            world: world,
            role: role,
            instrument: assignment
        )
        if !scheduled.contains(where: { note in
            AlienTimbreTreatment.resolve(
                intent: note.timbreIntent,
                velocity: note.velocity,
                role: role
            ) != .neutral
        }) {
            // Returning home neutralizes prior chapter treatment immediately,
            // even when this role's next onset is late or absent. Oscillator
            // and delay phases remain untouched.
            state.timbreIntent = .home
            state.timbreVelocity = 0
        }
        if scheduled.isEmpty && state.envelope < 0.000_001 && state.tailLevel < 0.000_001 &&
            state.timbreTreatment == .neutral {
            state.velocityResponse = .neutral
            return
        }

        var nextNote = 0
        var noteStart = -1
        var noteEnd = -1
        var startFrequency = state.frequency
        var targetFrequency = state.frequency
        var velocity = 0.0
        var legatoGate = false
        var articulation = RelationalArticulation.neutral
        var velocityResponse = state.velocityResponse
        var dryScale = 1.0
        var spatialSendLevel = 0.0
        var narrativeGainScale = 1.0
        var narrativeSpectralScale = 1.0
        var spectralReveal = UpperSpectralRevealArticulation.home
        var targetTimbreTreatment = scheduled.contains(where: { note in
            AlienTimbreTreatment.resolve(
                intent: note.timbreIntent,
                velocity: note.velocity,
                role: role
            ) != .neutral
        }) ? state.timbreTreatment : .neutral
        var activeEvidenceIndex: Int?
        let roleMutation = mutationScale(for: role)
        let patchTreatment = TonalPatchTreatment.resolve(assignment)
        let mutation = min(
            1,
            bar.mutationAmount * roleMutation * 0.62 +
                assignment.automation.motion * 0.38
        )
        let fingerprint = world.motifFingerprint
        let baseAttackSeconds = attack(
            for: role, gesture: bar.gesture, fingerprint: fingerprint
        ) * patchTreatment.attackScale
        let baseDecaySeconds = decay(
            for: role, gesture: bar.gesture, fingerprint: fingerprint
        ) * patchTreatment.decayScale
        let baseSustain = min(0.92, sustain(
            for: role, gesture: bar.gesture, fingerprint: fingerprint
        ) * patchTreatment.sustainScale)
        let baseReleaseSeconds = release(
            for: role, gesture: bar.gesture, fingerprint: fingerprint
        ) * patchTreatment.releaseScale
        if bar.forceHomeUpperTimbre ||
            (bar.tonalEnvelopeExpansionEligible &&
             !scheduled.contains(where: { $0.envelopeRelation == .sustainedWash })) {
            // An attempt-local home correction must not inherit the active
            // relation from incoming state before its first corrected onset.
            state.envelopeRelation = .home
        }
        var envelopeTreatment = TonalEnvelopeExpansionContract.resolve(
            baseSustain: baseSustain,
            baseReleaseSeconds: baseReleaseSeconds,
            relation: state.envelopeRelation
        )
        var attackFrames = max(1, Int(baseAttackSeconds * sampleRate))
        var decaySeconds = baseDecaySeconds
        var releaseCoefficient = exp(-1 / max(
            1, envelopeTreatment.releaseSeconds * sampleRate
        ))
        var glideCoefficient = 1 - exp(-1 / max(1, sampleRate * (0.012 + mutation * 0.030)))
        var filterEnvelopeDecay = exp(-1 / max(
            1,
            sampleRate * state.timbreTreatment.filterEnvelopeDecaySeconds
        ))
        let oversampledRate = sampleRate * 2
        let treatmentSmoothing = 1 - exp(-1 / max(1, sampleRate * 0.012))
        let roleIndex = Double(SynthRole.allCases.firstIndex(of: role) ?? 0)
        let driftRate = 0.031 + roleIndex * 0.007 + Double(world.variation) * 0.003

        for frame in output.indices {
            if frame == noteEnd, let evidenceIndex = activeEvidenceIndex {
                noteRenderEvidence[evidenceIndex].appliedGateEndFrame = frame
                noteRenderEvidence[evidenceIndex].frequencyAtAppliedGateEnd = state.frequency
                activeEvidenceIndex = nil
            }
            var retriggered = false
            while nextNote < scheduled.count && scheduled[nextNote].startFrame == frame {
                let note = scheduled[nextNote]
                if let evidenceIndex = activeEvidenceIndex {
                    noteRenderEvidence[evidenceIndex].appliedGateEndFrame = frame
                    noteRenderEvidence[evidenceIndex].frequencyAtAppliedGateEnd = state.frequency
                    activeEvidenceIndex = nil
                }
                noteStart = frame
                let (uncappedRequestedEnd, requestedEndOverflowed) =
                    frame.addingReportingOverflow(note.durationFrames)
                let requestedGateEnd = requestedEndOverflowed
                    ? Int.max
                    : uncappedRequestedEnd
                noteEnd = min(output.count, requestedGateEnd)
                velocity = min(1, max(0, note.velocity))
                let requestedVelocityResponse = AlienVelocityResponse.resolve(
                    velocity: velocity,
                    role: role
                )
                state.timbreIntent = note.timbreIntent
                state.timbreVelocity = velocity
                state.envelopeRelation = note.envelopeRelation
                envelopeTreatment = TonalEnvelopeExpansionContract.resolve(
                    baseSustain: baseSustain,
                    baseReleaseSeconds: baseReleaseSeconds,
                    relation: note.envelopeRelation
                )
                releaseCoefficient = exp(-1 / max(
                    1, envelopeTreatment.releaseSeconds * sampleRate
                ))
                targetTimbreTreatment = AlienTimbreTreatment.resolve(
                    intent: note.timbreIntent,
                    velocity: velocity,
                    role: role
                )
                let requestedSlide = note.gate == .slide
                legatoGate = requestedSlide && state.envelope > 0.000_001
                if !legatoGate {
                    state.velocityResponse = requestedVelocityResponse
                }
                velocityResponse = state.velocityResponse
                if legatoGate {
                    startFrequency = max(20, state.frequency)
                } else if note.timbreIntent.kind != .resonantSequence {
                    // Home and detuned-motion notes share the existing pitch
                    // trajectory. Detuned motion may change only oscillator
                    // beating; it must not smuggle in a retrigger pitch jump.
                    startFrequency = max(20, state.frequency)
                    retriggered = true
                } else {
                    startFrequency = max(20, note.frequency)
                    state.frequency = startFrequency
                    retriggered = true
                }
                targetFrequency = max(20, note.endFrequency)
                filterEnvelopeDecay = exp(-1 / max(
                    1,
                    sampleRate * targetTimbreTreatment.filterEnvelopeDecaySeconds
                ))
                if !legatoGate {
                    state.filterEnvelope = note.timbreIntent.kind == .resonantSequence ? 1 : 0
                }
                if targetTimbreTreatment != .neutral {
                    state.timbreTreatment = targetTimbreTreatment
                }
                noteRenderEvidence.append(UpperNoteRenderEvidence(
                    role: role,
                    onsetFrame: frame,
                    requestedGateEndFrame: requestedGateEnd,
                    appliedGateEndFrame: noteEnd,
                    requestedStartFrequency: note.frequency,
                    appliedStartFrequency: startFrequency,
                    targetEndFrequency: targetFrequency,
                    frequencyAtAppliedGateEnd: startFrequency,
                    requestedGate: note.gate,
                    appliedGate: legatoGate ? .slide : .retrigger,
                    didRetrigger: !legatoGate,
                    timbreIntent: note.timbreIntent,
                    envelopeRelation: note.envelopeRelation,
                    spectralReveal: note.spectralReveal,
                    minimumAppliedCutoffHz: 0,
                    maximumAppliedCutoffHz: 0,
                    baseEnvelopeSustain: baseSustain,
                    baseEnvelopeReleaseSeconds: baseReleaseSeconds,
                    appliedEnvelopeSustain: envelopeTreatment.sustain,
                    appliedEnvelopeReleaseSeconds:
                        envelopeTreatment.releaseSeconds,
                    requestedVelocity: note.velocity,
                    appliedVelocity: velocity,
                    velocitySpectralEnvelopeScale: velocityResponse.spectralEnvelopeScale,
                    velocityDecayScale: velocityResponse.decayScale,
                    instrument: note.instrument
                ))
                activeEvidenceIndex = noteRenderEvidence.count - 1
                articulation = note.articulation
                dryScale = min(1, max(0, note.dryScale))
                spatialSendLevel = min(1, max(0, note.spatialReverbSend))
                narrativeGainScale = max(0, note.narrativeGainScale)
                narrativeSpectralScale = max(0.01, note.narrativeSpectralScale)
                spectralReveal = note.spectralReveal
                attackFrames = max(1, Int(
                    baseAttackSeconds * articulation.attackScale * sampleRate
                ))
                decaySeconds = baseDecaySeconds * articulation.decayScale *
                    velocityResponse.decayScale
                let glideSeconds = (0.012 + mutation * 0.030) * articulation.glideTimeScale
                glideCoefficient = 1 - exp(-1 / max(1, sampleRate * glideSeconds))
                nextNote += 1
            }

            state.timbreTreatment = state.timbreTreatment.interpolated(
                toward: targetTimbreTreatment,
                amount: treatmentSmoothing
            )
            let timbreTreatment = state.timbreTreatment

            let gate = frame < noteEnd
            if gate {
                if retriggered && role != .atmosphere {
                    state.envelope = min(state.envelope, 0.14)
                }
                if legatoGate {
                    let decayCoefficient = 1 - exp(-1 / max(1, decaySeconds * sampleRate))
                    state.envelope += (envelopeTreatment.sustain - state.envelope) *
                        decayCoefficient
                } else {
                    let age = max(0, frame - noteStart)
                    let attackProgress = min(1, Double(age) / Double(attackFrames))
                    let shapedAttack = attackProgress * attackProgress * (3 - 2 * attackProgress)
                    let decayTime = max(0, Double(age - attackFrames)) / sampleRate
                    let decayEnvelope = envelopeTreatment.sustain +
                        (1 - envelopeTreatment.sustain) *
                        exp(-decayTime / max(0.02, decaySeconds))
                    let targetEnvelope = age < attackFrames ? shapedAttack : decayEnvelope
                    state.envelope += (targetEnvelope - state.envelope) * 0.24
                }
            } else {
                state.envelope *= releaseCoefficient
            }
            state.filterEnvelope *= filterEnvelopeDecay

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
                let ratio = (role == .anchor
                    ? 1 + motifDetune * patchTreatment.detuneScale
                    : 1 + 0.006 * patchTreatment.detuneScale) +
                    Double(world.variation) * 0.0017 + roleIndex * 0.0009 +
                    timbreTreatment.detuneRatioLift
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
                    (role == .anchor ? 0.72 : 1) * patchTreatment.modulationScale
                let phaseA = wrap(state.phaseA + phaseMod)
                let pulseWidth = min(0.72, max(0.22,
                    0.34 + fastSine(wrap(state.driftPhase * 0.43)) * (0.035 + mutation * 0.10)))
                let sawA = bandLimitedSaw(phaseA, increment: incrementA)
                let sawB = bandLimitedSaw(state.phaseB, increment: incrementB)
                let pulse = bandLimitedPulse(phaseA, increment: incrementA, width: pulseWidth)
                let noise = fastSine(wrap(state.noisePhaseA + state.modPhase * 0.059)) *
                    fastSine(wrap(state.noisePhaseB + state.phaseB * 0.037))
                let source = sawA * patchTreatment.sawAWeight +
                    sawB * patchTreatment.sawBWeight +
                    pulse * patchTreatment.pulseWeight +
                    noise * patchTreatment.noiseWeight

                let anchor = fastSaturate((source + sawA * sawB * 0.14) * (1.18 + mutation * 0.30))
                let emphasized = source + (source - state.previousSource) * (0.18 + mutation * 0.34)
                state.previousSource = source
                let folded = waveFold(
                    emphasized * (1.18 + mutation * 2.15) *
                        timbreTreatment.driveScale * patchTreatment.driveScale
                )
                let ringCarrier = fastSine(wrap(
                    state.phaseB * (1.5 + roleIndex * 0.083) + state.modPhase * 0.31
                ))
                var altered = folded * (1 - mutation * 0.18) + folded * ringCarrier * (0.16 + mutation * 0.56)
                altered += altered * altered * (0.08 + mutation * 0.20)

                let envelopeLift = state.envelope * 0.20 *
                    velocityResponse.spectralEnvelopeScale
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
                let baseCutoff = (170 + Double(world.variation) * 55 + roleIndex * 48) *
                    spectralScale * patchTreatment.cutoffScale
                let requestedCutoff = min(
                    oversampledRate * 0.18,
                    baseCutoff + (1 - mutation) * 1_280 + envelopeLift * 1_850 +
                        state.filterEnvelope * timbreTreatment.filterEnvelopeDepth +
                        modulator * mutation * 310
                )
                let cutoff = UpperSpectralRevealContract.appliedCutoffHz(
                    requestedCutoffHz: requestedCutoff,
                    articulation: spectralReveal,
                    sampleRate: oversampledRate,
                    maximumCutoffFraction: 0.18
                )
                if let evidenceIndex = activeEvidenceIndex {
                    let currentMinimum = noteRenderEvidence[evidenceIndex]
                        .minimumAppliedCutoffHz
                    noteRenderEvidence[evidenceIndex].minimumAppliedCutoffHz =
                        currentMinimum == 0 ? cutoff : min(currentMinimum, cutoff)
                    noteRenderEvidence[evidenceIndex].maximumAppliedCutoffHz = max(
                        noteRenderEvidence[evidenceIndex].maximumAppliedCutoffHz,
                        cutoff
                    )
                }
                let rawCoefficient = 2 * .pi * cutoff / oversampledRate
                let coefficient = min(0.46, max(0.004,
                    rawCoefficient / (1 + rawCoefficient * 0.5)))
                let resonance = min(
                    0.84,
                    0.22 + mutation * 0.38 + timbreTreatment.resonanceLift
                )
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
                    (role == .anchor ? narrativeGainScale : 1) *
                    timbreTreatment.amplitudeScale
                dryVoice = oversampleSum * 0.5 * amplitude
            } else {
                state.filter1 *= 0.94
                state.filter2 *= 0.94
                state.filter3 *= 0.94
                state.filter4 *= 0.94
                state.oversampleLow *= 0.72
            }
            let combRead = Double(state.comb[state.combIndex])
            let combFeedback = min(
                0.58,
                (0.16 + mutation * 0.34) * patchTreatment.combScale
            )
            state.comb[state.combIndex] = Float(dryVoice + combRead * combFeedback)
            state.combIndex = (state.combIndex + 1) % state.comb.count
            let combVoice = dryVoice + combRead *
                (0.12 + mutation * 0.38) * patchTreatment.combScale

            let allPassRead = Double(state.allPass[state.allPassIndex])
            let allPassGain = min(0.68, 0.34 + mutation * 0.24)
            let allPassVoice = allPassRead - combVoice * allPassGain
            state.allPass[state.allPassIndex] = Float(combVoice + allPassVoice * allPassGain)
            state.allPassIndex = (state.allPassIndex + 1) % state.allPass.count
            let coloredVoice = combVoice * 0.78 + allPassVoice * 0.22

            if gate, assignment.effects.contains(.pulseEcho) {
                let send = max(
                    articulation.pulseEchoSend,
                    assignment.automation.space * 0.10
                )
                pulseEchoSend[frame] += Float(coloredVoice * min(0.32, send))
            }

            let echoRead = Double(state.echo[state.echoIndex])
            state.echoLow += (echoRead - state.echoLow) * (0.08 + (1 - mutation) * 0.05)
            let filteredEcho = state.echoLow
            let echoSend = (bar.gesture == .suspend
                ? 0.26 + mutation * 0.34 : 0.035) * patchTreatment.echoScale
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
            architectureMeasurement[frame] += renderedSample
            if state.envelopeRelation == .sustainedWash {
                envelopeExpansionMeasurement[frame] += renderedSample
            }
            if assignment.effects.contains(.filteredReverb) {
                let send = max(
                    spatialSendLevel,
                    assignment.automation.space * 0.28
                )
                spatialReverbSend[frame] += unscaledSample * Float(min(1, send))
            }
        }
        if let evidenceIndex = activeEvidenceIndex {
            noteRenderEvidence[evidenceIndex].appliedGateEndFrame = output.count
            noteRenderEvidence[evidenceIndex].frequencyAtAppliedGateEnd = state.frequency
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
