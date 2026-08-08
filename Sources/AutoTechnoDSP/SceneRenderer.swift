import AutoTechnoCore
import Foundation

public struct RenderedBar: Equatable, Sendable {
    public let sampleRate: Double
    public let samples: [Float]
    public let leftSamples: [Float]
    public let rightSamples: [Float]
    public let peak: Float
    public let rms: Float
    public let crestFactor: Float
    public let stereoCorrelation: Float
    public let masking: [MaskingDecision]

    public init(sampleRate: Double, samples: [Float]) {
        self.sampleRate = sampleRate
        self.samples = samples
        self.leftSamples = samples
        self.rightSamples = samples
        peak = samples.reduce(0) { max($0, abs($1)) }
        let energy = samples.reduce(0.0) { $0 + Double($1 * $1) }
        rms = Float(sqrt(energy / Double(max(1, samples.count))))
        crestFactor = rms > 0 ? peak / rms : 0
        stereoCorrelation = 1
        masking = []
    }

    public init(sampleRate: Double, samples: [Float], leftSamples: [Float], rightSamples: [Float], masking: [MaskingDecision] = []) {
        self.sampleRate = sampleRate
        self.samples = samples
        self.leftSamples = leftSamples
        self.rightSamples = rightSamples
        peak = zip(leftSamples, rightSamples).reduce(0) { result, pair in
            max(result, abs(pair.0), abs(pair.1))
        }
        let count = max(1, min(leftSamples.count, rightSamples.count))
        let leftEnergy = leftSamples.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        let rightEnergy = rightSamples.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        rms = Float(sqrt((leftEnergy + rightEnergy) / Double(count * 2)))
        crestFactor = rms > 0 ? peak / rms : 0
        let cross = zip(leftSamples.prefix(count), rightSamples.prefix(count)).reduce(0.0) { $0 + Double($1.0 * $1.1) }
        stereoCorrelation = Float(cross / sqrt(max(0.0000001, leftEnergy * rightEnergy)))
        self.masking = masking
    }
}

/// Mutable effect memory owned by the offline bar scheduler. It must never be
/// shared with or mutated from a real-time render callback.
public struct SceneRenderState: Sendable {
    fileprivate var atmosphereDelay: [Float] = []
    fileprivate var atmosphereWriteIndex = 0
    fileprivate var atmosphereSampleRate = 0.0
    fileprivate var tempoDelay: [Float] = []
    fileprivate var tempoDelayWriteIndex = 0
    fileprivate var tempoDelaySampleRate = 0.0
    fileprivate var synthPhase = 0.0
    fileprivate var synthDetunePhase = 0.0
    fileprivate var synthMotionPhase = 0.0

    public init() {}

    public var hasAtmosphereMemory: Bool { !atmosphereDelay.isEmpty }

    public mutating func reset() {
        atmosphereDelay.removeAll(keepingCapacity: true)
        atmosphereWriteIndex = 0
        atmosphereSampleRate = 0
        tempoDelay.removeAll(keepingCapacity: true)
        tempoDelayWriteIndex = 0
        tempoDelaySampleRate = 0
        synthPhase = 0
        synthDetunePhase = 0
        synthMotionPhase = 0
    }
}

public enum RenderTreatment: String, Equatable, Sendable {
    case polished
    case sketch
}

public enum SceneRenderer {
    public static func render(
        scene: TechnoScene,
        sampleRate: Double,
        transition: Bool = false,
        applyGroove: Bool = true,
        includeMotif: Bool = true,
        section: SectionKind = .groove,
        treatment: RenderTreatment = .polished
    ) -> RenderedBar {
        var state = SceneRenderState()
        return render(scene: scene, sampleRate: sampleRate, transition: transition,
                      applyGroove: applyGroove, includeMotif: includeMotif,
                      section: section, treatment: treatment, state: &state)
    }

    public static func render(
        scene: TechnoScene,
        sampleRate: Double,
        transition: Bool = false,
        applyGroove: Bool = true,
        includeMotif: Bool = true,
        section: SectionKind = .groove,
        treatment: RenderTreatment = .polished,
        state: inout SceneRenderState
    ) -> RenderedBar {
        let duration = 240 / scene.bpm
        let frameCount = max(1, Int((duration * sampleRate).rounded()))
        let stepFrames = Double(frameCount) / 16
        var output = [Float](repeating: 0, count: frameCount)
        var kickBus = [Float](repeating: 0, count: frameCount)
        var bassBus = [Float](repeating: 0, count: frameCount)
        var percussionBus = [Float](repeating: 0, count: frameCount)
        var synthBus = [Float](repeating: 0, count: frameCount)
        var noise = SeededGenerator(seed: scene.seed ^ 0xD5F09C3A1B27E841)
        var filteredNoise = 0.0

        // Section voice activity: breakdowns strip voices selectively rather
        // than uniformly lowering the whole mix. Claps and motif are muted,
        // hats and bass are thinned, kick stays but with slightly less weight.
        let sectionKickWeight: Double
        let sectionHatLevel: Double
        let sectionClapActive: Bool
        let sectionClapLevel: Double
        let sectionBassLevel: Double
        let sectionMotifActive: Bool
        let sectionMotifLevel: Double
        switch section {
        case .groove:
            sectionKickWeight = 1.0
            sectionHatLevel = 1.0
            sectionClapActive = true
            sectionClapLevel = 1.0
            sectionBassLevel = 1.0
            sectionMotifActive = true
            sectionMotifLevel = 1.0
        case .build:
            sectionKickWeight = 1.1
            sectionHatLevel = 1.12
            sectionClapActive = true
            sectionClapLevel = 1.08
            sectionBassLevel = 1.1
            sectionMotifActive = true
            sectionMotifLevel = 1.15
        case .breakdown:
            sectionKickWeight = 0.88
            sectionHatLevel = 0.5
            sectionClapActive = false
            sectionClapLevel = 0.0
            sectionBassLevel = 0.6
            sectionMotifActive = false
            sectionMotifLevel = 0.0
        case .returnSection:
            sectionKickWeight = 1.04
            sectionHatLevel = 1.06
            sectionClapActive = true
            sectionClapLevel = 1.0
            sectionBassLevel = 1.0
            sectionMotifActive = true
            sectionMotifLevel = 1.1
        }

        for event in scene.groove.events {
            let eventOffset = applyGroove ? event.offsetInStep : 0
            let start = Int(((Double(event.stepIndex) + eventOffset) * stepFrames).rounded())
            if event.kind == .kick {
                addKick(to: &kickBus, start: start, sampleRate: sampleRate,
                        seed: scene.seed, stepIndex: event.stepIndex,
                        weight: scene.character.kickWeight * sectionKickWeight,
                        aggression: scene.aggression)
            }
            if event.kind == .hat && (!transition || event.stepIndex >= 8) {
                addHat(
                    to: &percussionBus,
                    start: start,
                    sampleRate: sampleRate,
                    level: (0.075 + scene.drive * 0.025) * sectionHatLevel,
                    brightness: scene.character.percussionBrightness,
                    noise: &noise,
                    state: &filteredNoise,
                    chaosMod: scene.textureChaos
                )
            }
            if event.kind == .clap && sectionClapActive && (!transition || event.stepIndex >= 8) {
                addClap(
                    to: &percussionBus,
                    start: start,
                    sampleRate: sampleRate,
                    level: 0.105 * sectionClapLevel,
                    brightness: scene.character.percussionBrightness,
                    noise: &noise,
                    state: &filteredNoise,
                    chaosMod: scene.textureChaos
                )
            }
            if event.kind == .bass && !transition {
                addBass(
                    to: &bassBus,
                    start: start,
                    sampleRate: sampleRate,
                    duration: scene.character.bassDecay,
                    level: scene.character.bassLevel * sectionBassLevel,
                    frequency: bassFrequency(seed: scene.seed, stepIndex: event.stepIndex, darkness: scene.darkness),
                    darkness: scene.darkness,
                    aggression: scene.aggression,
                    synthPresence: scene.synthPresence
                )
            }
        }

        // Drum chaos: ghost notes — extra quiet hits on unused steps
        if scene.drumChaos > 0.01 && !transition {
            var ghostRng = SeededGenerator(seed: scene.seed ^ 0xCAFEB0B0)
            for index in 0..<16 {
                // At the top end chaos should create a recognizable phrase
                // mutation, while remaining quiet and seed-deterministic.
                let ghostChance = scene.drumChaos * 0.28
                guard ghostRng.chance(ghostChance) else { continue }
                let ghostStart = Int(((Double(index)) * stepFrames).rounded())
                let ghostKind = ghostRng.next() % 3
                if ghostKind == 0 {
                    addKick(to: &kickBus, start: ghostStart, sampleRate: sampleRate,
                            seed: scene.seed, stepIndex: index,
                            weight: scene.character.kickWeight * 0.12, aggression: scene.aggression)
                } else if ghostKind == 1 {
                    addHat(to: &percussionBus, start: ghostStart, sampleRate: sampleRate,
                           level: 0.025, brightness: scene.character.percussionBrightness * 0.5,
                           noise: &ghostRng, state: &filteredNoise)
                } else {
                    addClap(to: &percussionBus, start: ghostStart, sampleRate: sampleRate,
                            level: 0.035, brightness: 0.3 + scene.character.percussionBrightness * 0.3,
                            noise: &ghostRng, state: &filteredNoise)
                }
            }
        }

        let motifActive = includeMotif && sectionMotifActive
        let motifLevel = (0.042 + scene.drive * 0.018 + scene.synthPresence * 0.025) * sectionMotifLevel
        for event in motifActive ? scene.motif : [] {
            if transition && event.stepIndex < 8 { continue }
            let eventOffset = applyGroove ? event.offsetInStep : 0
            let start = Int(((Double(event.stepIndex) + eventOffset) * stepFrames).rounded())
            let freqJitter = scene.synthChaos * 0.04
            let jitteredFreq = event.frequency * (1.0 + (noise.unit() - 0.5) * freqJitter * 2)
            addMotif(
                to: &synthBus,
                start: start,
                sampleRate: sampleRate,
                duration: event.durationInSteps * stepFrames / sampleRate,
                frequency: jitteredFreq,
                level: motifLevel,
                darkness: scene.darkness,
                synthPresence: scene.synthPresence,
                phase: &state.synthPhase,
                detunePhase: &state.synthDetunePhase
            )
        }

        // Atmosphere: feedback-delay reverb tail, darkened by atmosphericDarkness
        if scene.atmosphere > 0.01 {
            let percussionSend = Float(scene.atmosphere * (0.06 + scene.darkness * 0.06))
            for index in synthBus.indices {
                synthBus[index] += percussionBus[index] * percussionSend
            }
            applyAtmosphere(to: &synthBus, sampleRate: sampleRate,
                           atmosphere: scene.atmosphere,
                           atmosphericDarkness: scene.atmosphericDarkness,
                           frameCount: frameCount,
                           state: &state)
        }

        if treatment == .polished && !synthBus.isEmpty {
            applyPhraseSynthMotion(
                to: &synthBus,
                sampleRate: sampleRate,
                darkness: scene.darkness,
                synthPresence: scene.synthPresence,
                motionPhase: &state.synthMotionPhase
            )
            applyTempoDelay(
                to: &synthBus,
                sampleRate: sampleRate,
                bpm: scene.bpm,
                hypnosis: scene.hypnosis,
                atmosphere: scene.atmosphere,
                state: &state
            )
            applyMachineTexture(
                to: &synthBus,
                sampleRate: sampleRate,
                bpm: scene.bpm,
                intensity: scene.machineTexture,
                seed: scene.seed,
                transition: transition
            )
        }

        if treatment == .polished {
            mixBuses(
                kick: kickBus,
                bass: bassBus,
                percussion: percussionBus,
                synth: synthBus,
                into: &output,
                sampleRate: sampleRate,
                darkness: scene.darkness
            )
        } else {
            for index in output.indices {
                output[index] = kickBus[index] + bassBus[index] + percussionBus[index] + synthBus[index]
            }
        }

        let fadeFrames = min(Int(sampleRate * 0.008), frameCount / 2)
        for index in 0..<frameCount {
            var gain = 1.0
            if index < fadeFrames { gain *= Double(index) / Double(max(1, fadeFrames)) }
            if index >= frameCount - fadeFrames { gain *= Double(frameCount - index - 1) / Double(max(1, fadeFrames)) }
            output[index] = softLimit(Float(Double(output[index]) * gain), aggression: scene.aggression)
        }
        if treatment == .polished {
            applyMasterChain(to: &output, sampleRate: sampleRate, darkness: scene.darkness, aggression: scene.aggression)
        } else {
            // The sketch reference bypasses the polished bus/master treatment,
            // so trim its reference level for a fair listening comparison.
            for index in output.indices {
                output[index] *= 0.88
            }
        }
        let stereo = treatment == .polished
            ? makeStereo(from: output, sampleRate: sampleRate, atmosphere: scene.atmosphere, atmosphericDarkness: scene.atmosphericDarkness, machineTexture: scene.machineTexture, seed: scene.seed)
            : (left: output, right: output)
        return RenderedBar(sampleRate: sampleRate, samples: output, leftSamples: stereo.left, rightSamples: stereo.right)
    }

    // MARK: - Kick (v0.5: sub layer + pitch snap + noise transient)

    private static func addKick(to output: inout [Float], start: Int, sampleRate: Double,
                                seed: UInt64, stepIndex: Int, weight: Double, aggression: Double) {
        let maxFrames = min(Int(sampleRate * 0.25), output.count - start)
        guard maxFrames > 0 else { return }

        // Aggression crossfades between round body and sharp attack.
        let bodyBlend = 1.0 - aggression * 0.55
        let clickBlend = 0.10 + aggression * 0.30

        // Pitch envelope: starts high (~150 Hz), sweeps down to ~45 Hz.
        let pitchStart = 205.0
        let pitchEnd = 43.0
        let pitchDecay = 72.0  // fast, audible downward pitch snap

        var phase = 0.0
        var subPhase = 0.0  // sub oscillator, one octave below
        var transientRandom = SeededGenerator(seed: seed ^ UInt64(stepIndex + 1) ^ 0x9E3779B97F4A7C15)
        var previousNoise = 0.0

        for index in 0..<maxFrames {
            let time = Double(index) / sampleRate
            let t = time  // local time alias

            // Frequency sweeps from high to low with a fast exponential decay.
            let freq = pitchEnd + (pitchStart - pitchEnd) * exp(-t * pitchDecay)
            phase += 2 * Double.pi * freq / sampleRate
            subPhase += 2 * Double.pi * (freq * 0.5) / sampleRate  // sub: half frequency

            // Main body: sine with amplitude envelope.
            let bodyEnv = exp(-t * 24.0)
            let body = (sin(phase) + sin(phase * 2.01) * 0.065) * bodyEnv * bodyBlend

            // Sub layer: softer, deeper sine adds weight.
            let subEnv = exp(-t * 18.0)
            let sub = sin(subPhase) * subEnv * 0.42

            // Deterministic high-passed noise transient: more like a physical
            // beater than the previous sine-derived click.
            let noiseClick: Double
            if index < Int(sampleRate * 0.0035) {
                let noiseVal = transientRandom.unit() * 2.0 - 1.0
                let highPassedNoise = noiseVal - previousNoise * 0.92
                previousNoise = noiseVal
                noiseClick = highPassedNoise * (1.0 - time / 0.0035) * clickBlend * 0.70
            } else {
                noiseClick = 0
            }

            let sample = (body + sub) * weight * 0.76 + noiseClick * weight
            output[start + index] += Float(sample)
        }
    }

    // MARK: - Bass (v0.5: sub oscillator + filter envelope + saturation)

    private static func addBass(
        to output: inout [Float], start: Int, sampleRate: Double,
        duration: Double, level: Double, frequency: Double, darkness: Double, aggression: Double,
        synthPresence: Double
    ) {
        let frames = min(Int(sampleRate * duration), output.count - start)
        guard frames > 0 else { return }

        let fundamental = frequency

        // Sub oscillator blend: higher darkness/synthPresence = more sub weight.
        let subBlend = 0.2 + darkness * 0.25 + synthPresence * 0.15

        // Aggression adds square-wave component for bite.
        let squareBlend = aggression * 0.55

        // Filter envelope state: low-pass that opens briefly then closes.
        var lpState = 0.0
        let filterAttack = 0.012   // seconds for filter to open
        let filterDecay = 0.075    // seconds for filter to close
        let filterBase = 0.06 + (1.0 - darkness) * 0.10  // base cutoff
        let filterPeak = 0.48 + aggression * 0.24        // peak cutoff

        for index in 0..<frames {
            let time = Double(index) / sampleRate

            // Filter envelope: attack-decay
            let filterEnv: Double
            if time < filterAttack {
                filterEnv = time / filterAttack
            } else {
                filterEnv = exp(-(time - filterAttack) / filterDecay)
            }
            let filterCoeff = filterBase + (filterPeak - filterBase) * filterEnv

            // Amplitude envelope
            let ampAttack = min(1.0, time / 0.006)
            let ampDecay = exp(-time * (9.0 + (1.0 - darkness) * 5.0))
            let ampEnv = ampAttack * ampDecay

            // Oscillator
            let phase = 2 * Double.pi * fundamental * time
            let sine = sin(phase)
            let harmonic = sin(phase * 2.0) * (0.08 + (1.0 - darkness) * 0.12)
            let square = sin(phase) >= 0 ? 0.35 : -0.35
            let tone = sine + harmonic + square * squareBlend

            // Sub oscillator (half frequency)
            let subPhase = Double.pi * fundamental * time
            let sub = sin(subPhase) * subBlend

            // Apply filter (simple one-pole low-pass on tone + sub mix)
            let raw = tone + sub
            lpState += (raw - lpState) * filterCoeff

            // Saturation: tanh for warmth at higher aggression
            let saturationDrive = 1.05 + aggression * 0.38
            let saturated = tanh(lpState * saturationDrive)

            output[start + index] += Float(saturated * ampEnv * level)
        }
    }

    /// A restrained bass vocabulary: mostly root repetition with occasional
    /// minor/modal steps. The seed chooses the phrase rotation, while the
    /// step position keeps the result coherent and hypnotic rather than
    /// turning every hit into an unrelated random note.
    private static func bassFrequency(seed: UInt64, stepIndex: Int, darkness: Double) -> Double {
        let roots = darkness > 0.72 ? [43.65, 46.25] : [49.0, 51.91]
        let root = roots[Int((seed >> 5) % UInt64(roots.count))]
        let degrees = [0, 0, 3, 0, 5, 0, 3, 7]
        let rotation = Int((seed >> 11) % UInt64(degrees.count))
        let degree = degrees[(stepIndex / 2 + rotation) % degrees.count]
        return root * pow(2.0, Double(degree) / 12.0)
    }

    // MARK: - Hat (v0.5: metallic resonance via tuned bandpass)

    private static func addHat(
        to output: inout [Float], start: Int, sampleRate: Double,
        level: Double, brightness: Double, noise: inout SeededGenerator,
        state: inout Double, chaosMod: Double = 0.0
    ) {
        let frames = min(Int(sampleRate * 0.055), output.count - start)
        guard frames > 0 else { return }

        // Hat fundamental: 8–10 kHz, brightness shifts it up.
        let hatFreq = 8000.0 + brightness * 4000.0

        // Bandpass filter states (two-pole approximation via two one-poles)
        var bp1 = 0.0  // high-pass stage
        var bp2 = 0.0  // low-pass stage
        let resonance = 0.35 + brightness * 0.25
        let bw = hatFreq * 0.6  // bandwidth

        // Envelope
        let attack = 0.002
        let decay = 0.028 + (1.0 - brightness) * 0.012

        for index in 0..<frames {
            let time = Double(index) / sampleRate

            // Amplitude envelope
            let env: Double
            if time < attack {
                env = time / attack
            } else {
                env = exp(-(time - attack) / decay)
            }

            // Noise source with texture chaos modulating the noise filter
            let raw = noise.unit() * 2.0 - 1.0

            // Bandpass: high-pass then low-pass
            bp1 = raw - state
            state = raw
            let hpOut = bp1

            let lpCoeff = exp(-2.0 * Double.pi * (hatFreq + bw * 0.5) / sampleRate)
            bp2 += (hpOut - bp2) * (1.0 - lpCoeff) * (1.0 + resonance * 0.5)

            // Chaos modulation: subtly vary the resonance
            let chaosFactor = 1.0 + (sin(time * Double.pi * 120.0) * chaosMod * 0.4)
            let sample = bp2 * env * level * chaosFactor

            output[start + index] += Float(sample)
        }
    }

    // MARK: - Clap (v0.5: multi-tap dispersion for thicker stereo-like clap)

    private static func addClap(
        to output: inout [Float], start: Int, sampleRate: Double,
        level: Double, brightness: Double, noise: inout SeededGenerator,
        state: inout Double, chaosMod: Double = 0.0
    ) {
        let frames = min(Int(sampleRate * 0.10), output.count - start)
        guard frames > 0 else { return }

        // Multi-tap delays (in samples) for clap dispersion
        let tap1 = Int(sampleRate * 0.006)   // 6ms
        let tap2 = Int(sampleRate * 0.011)   // 11ms
        let tap3 = Int(sampleRate * 0.017)   // 17ms
        let tap4 = Int(sampleRate * 0.024)   // 24ms

        // Pre-generate the noise burst into a small array for tap reads
        var noiseBurst = [Double](repeating: 0, count: max(tap4 + frames, frames))
        var lpState = 0.0
        let lpCoeff = 0.25 + brightness * 0.45  // filter coefficient for noise colour

        // Envelope
        let attack = 0.003
        let bodyDecay = 0.012
        let tailDecay = 0.05

        for index in 0..<frames {
            let time = Double(index) / sampleRate

            // Generate and filter noise into the burst buffer
            let rawNoise = noise.unit() * 2.0 - 1.0
            lpState += (rawNoise - lpState) * lpCoeff
            noiseBurst[index] = lpState

            // Amplitude envelope: sharp attack, quick body, slow tail
            let env: Double
            if time < attack {
                env = time / attack
            } else if time < (attack + bodyDecay) {
                let bodyTime = time - attack
                env = exp(-bodyTime / bodyDecay) * 0.7 + 0.3
            } else {
                let tailTime = time - attack - bodyDecay
                env = 0.3 * exp(-tailTime / tailDecay)
            }

            // Read taps (zero if index too small)
            let tap1Val = index >= tap1 ? noiseBurst[index - tap1] : 0
            let tap2Val = index >= tap2 ? noiseBurst[index - tap2] : 0
            let tap3Val = index >= tap3 ? noiseBurst[index - tap3] : 0
            let tap4Val = index >= tap4 ? noiseBurst[index - tap4] : 0

            // Mix direct noise with delayed taps
            let tapMix = noiseBurst[index] * 0.45
                + tap1Val * 0.28
                + tap2Val * 0.18
                + tap3Val * 0.12
                + tap4Val * 0.07

            // Mild bandpass resonance for metallic quality
            let reverbTail = (noiseBurst[index] + tap1Val * 0.5 + tap2Val * 0.5) * 0.12
            let chaosFactor = 1.0 + (sin(time * Double.pi * 80.0) * chaosMod * 0.3)

            let sample = (tapMix + reverbTail) * env * level * chaosFactor
            output[start + index] += Float(sample)
        }
    }

    // MARK: - Motif (v0.5: sawtooth + detune spread + filter envelope)

    private static func addMotif(
        to output: inout [Float], start: Int, sampleRate: Double,
        duration: Double, frequency: Double, level: Double, darkness: Double,
        synthPresence: Double, phase: inout Double, detunePhase: inout Double
    ) {
        let frames = min(Int(sampleRate * duration), output.count - start)
        guard frames > 0 else { return }

        // Waveform blend: darkness → more filtered triangle, synthPresence → sawtooth edge
        let triangleWeight = 0.55 + darkness * 0.25
        let sawWeight = 0.12 + synthPresence * 0.28
        let pulseWeight = 1.0 - triangleWeight - sawWeight
        let pulseWidth = 0.38 + (1.0 - darkness) * 0.12

        // Slight detune for thickness
        let detuneCents = 5.0 + synthPresence * 8.0
        let detuneRatio = pow(2.0, detuneCents / 1200.0)
        let phaseIncrement = frequency / sampleRate
        let detuneIncrement = frequency * detuneRatio / sampleRate

        // Filter envelope
        var lpState = 0.0
        var lpDetune = 0.0
        let filterAttack = 0.015
        let filterDecay = 0.04
        let filterBase = 0.06 + (1.0 - darkness) * 0.10
        let filterPeak = 0.35 + synthPresence * 0.25

        for index in 0..<frames {
            let time = Double(index) / sampleRate

            // Filter envelope
            let filtEnv: Double
            if time < filterAttack {
                filtEnv = time / filterAttack
            } else {
                filtEnv = exp(-(time - filterAttack) / filterDecay)
            }
            let filtCoeff = filterBase + (filterPeak - filterBase) * filtEnv

            // Amplitude envelope
            let ampAttack = min(1.0, time / 0.010)
            let ampSustain = exp(-time * (0.6 + darkness * 0.8))
            let ampEnv = ampAttack * ampSustain

            // Normalized phase accumulators. The saw and pulse use PolyBLEP
            // correction so their discontinuities do not spray aliasing into
            // the upper spectrum.
            let phaseUnit = phase
            let detuneUnit = detunePhase

            // Triangle wave
            let rawTri = 2.0 * abs(phaseUnit - 0.5) * 2.0 - 1.0
            let triDetune = 2.0 * abs(detuneUnit - 0.5) * 2.0 - 1.0

            // Saw wave
            let rawSaw = 2.0 * phaseUnit - 1.0 - polyBLEP(phaseUnit, phaseIncrement)

            // Pulse wave
            var pulse = phaseUnit < pulseWidth ? 1.0 : -1.0
            pulse += polyBLEP(phaseUnit, phaseIncrement)
            let fallingPhase = (phaseUnit - pulseWidth + 1.0).truncatingRemainder(dividingBy: 1.0)
            pulse -= polyBLEP(fallingPhase, phaseIncrement)

            // Mix oscillators
            let raw = triangleWeight * (rawTri * 0.76 + triDetune * 0.24)
                    + sawWeight * rawSaw
                    + pulseWeight * pulse

            // Apply filter
            lpState += (raw - lpState) * filtCoeff
            lpDetune += (raw - lpDetune) * filtCoeff * 0.7

            // Slight stereo width by mixing filtered and detuned-filtered
            let mixed = lpState * 0.7 + lpDetune * 0.3

            output[start + index] += Float(mixed * ampEnv * level)
            phase = (phase + phaseIncrement).truncatingRemainder(dividingBy: 1.0)
            detunePhase = (detunePhase + detuneIncrement).truncatingRemainder(dividingBy: 1.0)
        }
    }

    private static func polyBLEP(_ phase: Double, _ increment: Double) -> Double {
        guard increment > 0, increment < 1 else { return 0 }
        if phase < increment {
            let normalized = phase / increment
            return normalized + normalized - normalized * normalized - 1.0
        }
        if phase > 1.0 - increment {
            let normalized = (phase - 1.0) / increment
            return normalized * normalized + normalized + normalized + 1.0
        }
        return 0
    }

    private static func softLimit(_ sample: Float, aggression: Double) -> Float {
        let driveScale = 1.15 + aggression * 0.8
        let ceiling = 0.82 - aggression * 0.18
        let scaled = Double(sample) * driveScale
        return Float(tanh(scaled) * ceiling)
    }

    private static func mixBuses(
        kick: [Float],
        bass: [Float],
        percussion: [Float],
        synth: [Float],
        into output: inout [Float],
        sampleRate: Double,
        darkness: Double
    ) {
        var kickEnvelope = 0.0
        let attack = exp(-1.0 / (sampleRate * 0.0015))
        let release = exp(-1.0 / (sampleRate * 0.085))
        for index in output.indices {
            let kickLevel = abs(Double(kick[index]))
            let coefficient = kickLevel > kickEnvelope ? attack : release
            kickEnvelope = kickEnvelope * coefficient + kickLevel * (1.0 - coefficient)

            // Keep the kick centered and create a small, deterministic pocket
            // for the bass instead of simply making the bass louder.
            let duck = 1.0 - min(0.18, kickEnvelope * 0.30)
            let low = Double(kick[index]) * 0.98 + Double(bass[index]) * duck
            let percussionGain = 0.96 + darkness * 0.02
            let synthGain = 0.96 - darkness * 0.02
            output[index] = Float(low + Double(percussion[index]) * percussionGain + Double(synth[index]) * synthGain)
        }
    }

    private static func applyPhraseSynthMotion(
        to bus: inout [Float],
        sampleRate: Double,
        darkness: Double,
        synthPresence: Double,
        motionPhase: inout Double
    ) {
        var lowState = 0.0
        var resonanceState = 0.0
        let sweep = 0.5 + 0.5 * sin(motionPhase)
        let cutoff = 650.0 + sweep * (1_200.0 + synthPresence * 1_000.0) + (1.0 - darkness) * 450.0
        let coefficient = 1.0 - exp(-2.0 * Double.pi * cutoff / sampleRate)
        let resonance = 0.08 + synthPresence * 0.10
        for index in bus.indices {
            let input = Double(bus[index])
            lowState += (input - lowState) * coefficient
            resonanceState += (lowState - resonanceState) * (coefficient * 0.42)
            let resonantBand = lowState - resonanceState
            bus[index] = Float(lowState + resonantBand * resonance)
        }
        motionPhase = (motionPhase + Double.pi / 4.0).truncatingRemainder(dividingBy: 2.0 * Double.pi)
    }

    private static func applyTempoDelay(
        to bus: inout [Float],
        sampleRate: Double,
        bpm: Double,
        hypnosis: Double,
        atmosphere: Double,
        state: inout SceneRenderState
    ) {
        let delaySeconds = (60.0 / bpm) * (hypnosis > 0.62 ? 0.5 : 0.25)
        let delayFrames = max(1, Int((delaySeconds * sampleRate).rounded()))
        if state.tempoDelaySampleRate != sampleRate || state.tempoDelay.count != delayFrames {
            state.tempoDelay = [Float](repeating: 0, count: delayFrames)
            state.tempoDelayWriteIndex = 0
            state.tempoDelaySampleRate = sampleRate
        }

        let feedback = 0.22 + hypnosis * 0.12
        let wet = 0.10 + atmosphere * 0.18
        for index in bus.indices {
            let writeIndex = state.tempoDelayWriteIndex
            let delayed = state.tempoDelay[writeIndex]
            let input = bus[index]
            state.tempoDelay[writeIndex] = input + delayed * Float(feedback)
            state.tempoDelayWriteIndex = (writeIndex + 1) % delayFrames
            bus[index] = input + delayed * Float(wet)
        }
    }

    /// Phrase-shaped upper-bus gestures. The kick and bass never enter this
    /// rack, preserving the warehouse anchor while the surface becomes more
    /// mechanical at stronger semantic settings.
    private static func applyMachineTexture(
        to bus: inout [Float], sampleRate: Double, bpm: Double,
        intensity: Double, seed: UInt64, transition: Bool
    ) {
        guard intensity > 0.01, !bus.isEmpty else { return }
        let amount = min(max(intensity, 0), 1)
        let stepFrames = max(1, Int((60.0 / bpm * sampleRate / 4.0).rounded()))
        let gateDepth = amount * 0.52
        let crushBits = max(5.0, 12.0 - amount * 6.0)
        let crushScale = pow(2.0, crushBits)
        let stutter = amount > 0.48 && ((seed ^ 0xA3C59AC3) & 1) == 1
        let stutterFrames = max(1, stepFrames / (amount > 0.72 ? 4 : 2))
        let splitMix = min(0.18, amount * 0.18)

        for index in bus.indices {
            let step = index / stepFrames
            let phase = index % stepFrames
            var value = Double(bus[index])

            // Synchronous cuts create a gate without changing the groove grid.
            if amount > 0.24 && ((step + Int(seed % 3)) % 8 == 6 || (transition && step % 4 == 3)) {
                let fade = phase < stepFrames / 8 ? Double(phase) / Double(max(1, stepFrames / 8)) : 0
                value *= 1.0 - gateDepth * (1.0 - fade)
            }

            // Repeat a short slice only at stronger settings; the source is
            // already in the current buffer, so no capture allocation occurs.
            if stutter && step >= 8 {
                let source = index - (phase % stutterFrames)
                value = value * (1.0 - amount * 0.42) + Double(bus[source]) * amount * 0.42
            }

            // Deterministic bit-depth reduction adds the crushed edge while
            // retaining a dry path and bounded output.
            if amount > 0.18 {
                let crushed = (value * crushScale).rounded() / crushScale
                value = value * (1.0 - amount * 0.38) + crushed * amount * 0.38
            }

            // A short, deterministic comb-like splitter accentuates the
            // machine texture without touching the low-frequency bus.
            if amount > 0.35 && index >= stepFrames {
                value += Double(bus[index - stepFrames]) * splitMix * (phase < stepFrames / 2 ? 1 : -1)
            }
            bus[index] = Float(max(-0.9, min(0.9, value)))
        }
    }

    /// Small, deterministic finishing stage. This is intentionally conservative:
    /// it improves translation and headroom without making the master louder
    /// enough to hide mix problems during taste comparisons.
    private static func applyMasterChain(
        to output: inout [Float],
        sampleRate: Double,
        darkness: Double,
        aggression: Double
    ) {
        guard !output.isEmpty else { return }

        // Remove subsonic drift and DC before the dynamics stage.
        var dcState = 0.0
        var highPassState = 0.0
        let dcCoeff = exp(-2.0 * Double.pi * 18.0 / sampleRate)
        let highPassCoeff = exp(-2.0 * Double.pi * 28.0 / sampleRate)
        for index in output.indices {
            let input = Double(output[index])
            dcState = input * (1.0 - dcCoeff) + dcState * dcCoeff
            let withoutDC = input - dcState
            highPassState = withoutDC * (1.0 - highPassCoeff) + highPassState * highPassCoeff
            output[index] = Float(withoutDC - highPassState)
        }

        // Gentle glue compression with a slower release so repeated kicks do
        // not cause audible per-sample pumping. Darker scenes get slightly
        // more low-level cohesion; aggression remains a bounded influence.
        var envelope = 0.0
        let attack = exp(-1.0 / (sampleRate * 0.004))
        let release = exp(-1.0 / (sampleRate * 0.090))
        let threshold = 0.34 - darkness * 0.035
        let ratio = 1.55 + aggression * 0.35
        let makeup = 1.015
        for index in output.indices {
            let magnitude = abs(Double(output[index]))
            let coefficient = magnitude > envelope ? attack : release
            envelope = envelope * coefficient + magnitude * (1.0 - coefficient)
            let over = max(0.0, envelope - threshold)
            let gainReduction = over > 0 ? 1.0 - (over - over / ratio) / max(envelope, 0.0001) : 1.0
            output[index] = Float(Double(output[index]) * gainReduction * makeup)
        }

        // A restrained high-frequency tilt keeps the current noise-based hats
        // from dominating after compression while retaining their attack.
        var tiltState = 0.0
        let tiltCoeff = 1.0 - exp(-2.0 * Double.pi * 5200.0 / sampleRate)
        let tiltAmount = 0.025 + darkness * 0.035
        for index in output.indices {
            let input = Double(output[index])
            tiltState += (input - tiltState) * tiltCoeff
            let highBand = input - tiltState
            output[index] = Float(input - highBand * tiltAmount)
        }
    }

    private static func makeStereo(
        from mono: [Float],
        sampleRate: Double,
        atmosphere: Double,
        atmosphericDarkness: Double,
        machineTexture: Double,
        seed: UInt64
    ) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: mono.count)
        var right = [Float](repeating: 0, count: mono.count)
        var lowState = 0.0
        var leftEcho = 0.0
        var rightEcho = 0.0
        let lowCoeff = 1.0 - exp(-2.0 * Double.pi * 180.0 / sampleRate)
        let spread = min(0.38, 0.06 + atmosphere * 0.24 + machineTexture * 0.14)
        let delayFrames = max(1, Int(sampleRate * (0.00035 + Double(seed % 5) * 0.00004)))
        var delayed = [Float](repeating: 0, count: delayFrames)
        var writeIndex = 0
        let air = 0.015 + (1.0 - atmosphericDarkness) * 0.018

        for index in mono.indices {
            let input = Double(mono[index])
            lowState += (input - lowState) * lowCoeff
            let low = lowState
            let high = input - low
            let delayedSample = Double(delayed[writeIndex])
            delayed[writeIndex] = mono[index]
            writeIndex = (writeIndex + 1) % delayFrames

            // Low frequencies stay mono-compatible; upper material gets a
            // small, deterministic width and asymmetric early reflection.
            let leftHigh = high * (1.0 + spread) + delayedSample * spread * 0.35
            let rightHigh = high * (1.0 - spread) - delayedSample * spread * 0.28
            leftEcho += (leftHigh - leftEcho) * air
            rightEcho += (rightHigh - rightEcho) * air
            left[index] = Float(low + leftHigh + leftEcho * atmosphere * 0.18)
            right[index] = Float(low + rightHigh + rightEcho * atmosphere * 0.18)
        }
        return (left, right)
    }

    /// Feedback-delay-network reverb: applies short echoes with a low-pass
    /// filter for atmospheric darkness.
    private static func applyAtmosphere(
        to output: inout [Float],
        sampleRate: Double,
        atmosphere: Double,
        atmosphericDarkness: Double,
        frameCount: Int,
        state: inout SceneRenderState
    ) {
        // Space should become an audible destination, not a barely perceptible send.
        let reverbTime = 0.08 + atmosphere * 0.55
        let reverbFrames = min(Int(sampleRate * reverbTime), frameCount)
        guard reverbFrames > 0 else { return }

        let wetMix = atmosphere * 0.32
        let delay1 = Int(sampleRate * 0.032)
        let delay2 = Int(sampleRate * 0.057)
        let delay3 = Int(sampleRate * 0.079)

        let requiredDelayFrames = max(delay1, delay2, delay3) + frameCount
        if state.atmosphereSampleRate != sampleRate || state.atmosphereDelay.count < requiredDelayFrames {
            state.atmosphereDelay = [Float](repeating: 0, count: requiredDelayFrames)
            state.atmosphereWriteIndex = 0
            state.atmosphereSampleRate = sampleRate
        }
        let delayBufferCount = state.atmosphereDelay.count

        var lpState: Float = 0
        let lpCoeff = Float(0.08 + (1.0 - atmosphericDarkness) * 0.35)

        for index in 0..<frameCount {
            let dry = output[index]

            let writeIndex = state.atmosphereWriteIndex
            state.atmosphereDelay[writeIndex] = dry
            let tap1Index = (writeIndex - delay1 + delayBufferCount) % delayBufferCount
            let tap2Index = (writeIndex - delay2 + delayBufferCount) % delayBufferCount
            let tap3Index = (writeIndex - delay3 + delayBufferCount) % delayBufferCount
            let tap1 = state.atmosphereDelay[tap1Index]
            let tap2 = state.atmosphereDelay[tap2Index]
            let tap3 = state.atmosphereDelay[tap3Index]

            let wetRaw = (tap1 * 0.48 + tap2 * 0.30 + tap3 * 0.22) * 0.42

            lpState += (wetRaw - lpState) * lpCoeff
            let wet = lpState

            output[index] = dry + wet * Float(wetMix)
            state.atmosphereWriteIndex = (writeIndex + 1) % delayBufferCount
        }
    }
}
