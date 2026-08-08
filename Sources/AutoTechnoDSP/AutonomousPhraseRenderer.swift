import AutoTechnoCore
import Foundation

package enum VoiceKind: String, CaseIterable, Sendable {
    case kick, bass, percussion, synth, lead, pad, riser
}

package enum EffectKind: String, CaseIterable, Sendable {
    case busEQ, maskingGuard, saturation, phaser, chorus, comb, unsyncedEcho, reverb, glue, master
}

package struct EffectState: Equatable, Sendable {
    package let kind: EffectKind
    package let amount: Double
    package let active: Bool

    package init(kind: EffectKind, amount: Double, active: Bool = true) {
        self.kind = kind
        self.amount = min(1, max(0, amount))
        self.active = active
    }
}

package struct VoiceEvent: Equatable, Sendable {
    package let voice: VoiceKind
    package let bar: Int
    package let step: Int
    package let intensity: Double

    package init(voice: VoiceKind, bar: Int, step: Int, intensity: Double) {
        self.voice = voice
        self.bar = bar
        self.step = step
        self.intensity = intensity
    }
}

package struct ModulationState: Equatable, Sendable {
    package let phase: Double
    package let brightness: Double
    package let density: Double
    package let space: Double
    package let cutoff: Double
    package let resonance: Double
    package let bassArticulation: Double
    package let fillIntensity: Double

    package init(phase: Double, brightness: Double, density: Double, space: Double,
                cutoff: Double, resonance: Double, bassArticulation: Double, fillIntensity: Double) {
        self.phase = phase
        self.brightness = brightness
        self.density = density
        self.space = space
        self.cutoff = cutoff
        self.resonance = resonance
        self.bassArticulation = bassArticulation
        self.fillIntensity = fillIntensity
    }
}

package struct BusState: Equatable, Sendable {
    package var level: Double
    package var send: Double
    package var headroom: Double

    package init(level: Double = 0, send: Double = 0, headroom: Double = 1) {
        self.level = level
        self.send = send
        self.headroom = headroom
    }
}

/// Mutable DSP continuation owned by detached phrase preparation. The audio
/// player receives immutable buffers and never mutates this state.
package struct RenderState: Equatable, Sendable {
    package var barIndex = 0
    package var bassPhase = 0.0
    package var bassFilter = 0.0
    package var delayBuffer: [Float] = []
    package var delayWriteIndex = 0
    package var earlyReflectionBuffer: [Float] = []
    package var earlyReflectionWriteIndex = 0
    package var stereoPanPhase = 0.0
    package var chorusDelay: [Float] = []
    package var chorusWriteIndex = 0
    package var chorusPhase = 0.0
    package var masterEnvelope = 0.0
    package var lowBandEnvelope = 0.0
    package var highBandEnvelope = 0.0
    package var reverbBuffer: [Float] = []
    package var reverbWriteIndex = 0
    var alienAnchorState = AlienVoiceState()
    var alienShadowState = AlienVoiceState()
    var alienAtmosphereState = AlienVoiceState()
    var alienResponseState = AlienVoiceState()
    var alienTransitionState = AlienVoiceState()

    package init() {}

    package mutating func reset() {
        self = RenderState()
    }
}

package struct RenderedBar: Equatable, Sendable {
    package let sampleRate: Double
    package let samples: [Float]
    package let leftSamples: [Float]
    package let rightSamples: [Float]
    package let peak: Float
    package let rms: Float
    package let crestFactor: Float
    package let stereoCorrelation: Float
    package let masking: [MaskingDecision]

    package init(sampleRate: Double, samples: [Float], leftSamples: [Float],
                rightSamples: [Float], masking: [MaskingDecision] = []) {
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
        let cross = zip(leftSamples.prefix(count), rightSamples.prefix(count)).reduce(0.0) {
            $0 + Double($1.0 * $1.1)
        }
        stereoCorrelation = Float(cross / sqrt(max(0.0000001, leftEnergy * rightEnergy)))
        self.masking = masking
    }
}

package struct RenderBlock: Equatable, Sendable {
    package let bar: Int
    package let section: SectionKind
    package let left: [Float]
    package let right: [Float]
    package let events: [VoiceEvent]
    package let modulation: ModulationState
    package let busStates: [VoiceKind: BusState]
    package let peak: Float
    package let truePeakEstimate: Float
    package let rms: Float
    package let loudnessEstimate: Float
    package let stereoCorrelation: Float
    package let masking: [MaskingDecision]
    package let effects: [EffectState]
    package let performance: PerformanceBar
    package let sceneDNA: SceneDNA
    package let synthWorld: SynthWorldDNA
    package let synthPerformance: SynthPerformanceBar

    package init(bar: Int, section: SectionKind, left: [Float], right: [Float],
                events: [VoiceEvent], modulation: ModulationState,
                busStates: [VoiceKind: BusState], masking: [MaskingDecision],
                effects: [EffectState], performance: PerformanceBar,
                sceneDNA: SceneDNA, synthWorld: SynthWorldDNA,
                synthPerformance: SynthPerformanceBar) {
        self.bar = bar
        self.section = section
        self.left = left
        self.right = right
        self.events = events
        self.modulation = modulation
        self.busStates = busStates
        self.masking = masking
        self.effects = effects
        self.performance = performance
        self.sceneDNA = sceneDNA
        self.synthWorld = synthWorld
        self.synthPerformance = synthPerformance
        peak = zip(left, right).reduce(0) { max($0, abs($1.0), abs($1.1)) }
        truePeakEstimate = max(Self.cubicPeak(left), Self.cubicPeak(right))
        let count = max(1, min(left.count, right.count))
        let leftEnergy = left.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        let rightEnergy = right.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        rms = Float(sqrt((leftEnergy + rightEnergy) / Double(count * 2)))
        loudnessEstimate = Float(-0.691 + 20 * log10(max(Double(rms), 0.000000001)))
        let cross = zip(left.prefix(count), right.prefix(count)).reduce(0.0) {
            $0 + Double($1.0 * $1.1)
        }
        stereoCorrelation = Float(cross / sqrt(max(0.0000001, leftEnergy * rightEnergy)))
    }

    private static func cubicPeak(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return abs(samples.first ?? 0) }
        var result = samples.reduce(0) { max($0, abs($1)) }
        for index in 0..<(samples.count - 1) {
            let p0 = Double(samples[max(0, index - 1)])
            let p1 = Double(samples[index])
            let p2 = Double(samples[index + 1])
            let p3 = Double(samples[min(samples.count - 1, index + 2)])
            for subdivision in 1..<4 {
                let t = Double(subdivision) / 4
                let value = 0.5 * ((2 * p1) + (-p0 + p2) * t +
                    (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                    (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
                result = max(result, abs(Float(value)))
            }
        }
        return result
    }
}

enum RenderLayer {
    case full
    case foundation
}

struct RenderBuffers {
    var output: [Float] = []
    var kick: [Float] = []
    var percussion: [Float] = []
    var synth: [Float] = []

    mutating func reset(frameCount: Int) {
        reset(&output, frameCount: frameCount)
        reset(&kick, frameCount: frameCount)
        reset(&percussion, frameCount: frameCount)
        reset(&synth, frameCount: frameCount)
    }

    private func reset(_ buffer: inout [Float], frameCount: Int) {
        if buffer.count != frameCount {
            buffer = [Float](repeating: 0, count: frameCount)
        } else {
            for index in buffer.indices { buffer[index] = 0 }
        }
    }
}

struct RenderWorkspace {
    var buffers = RenderBuffers()

    mutating func checkout(frameCount: Int) -> RenderBuffers {
        var checkedOut = RenderBuffers()
        swap(&checkedOut, &buffers)
        checkedOut.reset(frameCount: frameCount)
        return checkedOut
    }

    mutating func recycle(_ returned: inout RenderBuffers) {
        swap(&buffers, &returned)
    }
}

/// The sole phrase renderer used by the shipped product. It runs during
/// detached preparation and returns immutable blocks to the audio scheduler.
package enum AutonomousPhraseRenderer {
    package static func render(plan: AutonomousPhrasePlan, graph: DSPGraphPlan,
                              sampleRate: Double, state: inout RenderState,
                              graphState: inout GeneratedDSPContinuationState) -> [RenderBlock] {
        let synthPlan = SynthPerformancePlan(scene: plan.scene, dna: plan.dna, bars: plan.bars)
        var workspace = RenderWorkspace()
        var blocks: [RenderBlock] = []
        blocks.reserveCapacity(plan.barCount)

        for index in plan.bars.indices {
            let performance = plan.bars[index]
            let synthPerformance = synthPlan.bars[index]
            let ensemble = plan.ensemble[index]
            let modulation = modulation(performance: performance, scene: plan.scene)
            var foundationState = state
            let foundation = VoiceRenderer.renderBar(
                scene: plan.scene,
                sampleRate: sampleRate,
                state: &foundationState,
                dna: plan.dna,
                performance: performance,
                synthWorld: synthPlan.world,
                synthPerformance: synthPerformance,
                workspace: &workspace,
                layer: .foundation
            )
            let rendered = VoiceRenderer.renderBar(
                scene: plan.scene,
                sampleRate: sampleRate,
                state: &state,
                dna: plan.dna,
                performance: performance,
                synthWorld: synthPlan.world,
                synthPerformance: synthPerformance,
                workspace: &workspace,
                layer: .full
            )
            let events = ensemble.events.map {
                VoiceEvent(voice: voiceKind($0.voice), bar: performance.bar,
                           step: $0.step, intensity: $0.intensity)
            }
            let buses = busStates(rendered: rendered, scene: plan.scene, events: events)
            let upperLeft = zip(rendered.leftSamples, foundation.leftSamples).map { $0.0 - $0.1 }
            let upperRight = zip(rendered.rightSamples, foundation.rightSamples).map { $0.0 - $0.1 }
            let generated = GeneratedDSPGraphRenderer.process(
                left: upperLeft, right: upperRight,
                sampleRate: sampleRate, plan: graph, state: &graphState
            )
            let outputLeft = zip(foundation.leftSamples, generated.0).map { outputSafety($0 + $1) }
            let outputRight = zip(foundation.rightSamples, generated.1).map { outputSafety($0 + $1) }
            let graphEffects = graph.nodes.map {
                EffectState(kind: effectKind($0.kind), amount: $0.amount, active: $0.mix > 0)
            } + [
                EffectState(kind: .maskingGuard, amount: 1),
                EffectState(kind: .glue, amount: 1),
                EffectState(kind: .master, amount: 1),
            ]
            blocks.append(RenderBlock(
                bar: performance.bar,
                section: performance.section,
                left: outputLeft,
                right: outputRight,
                events: events,
                modulation: modulation,
                busStates: buses,
                masking: rendered.masking,
                effects: graphEffects,
                performance: performance,
                sceneDNA: plan.dna,
                synthWorld: synthPlan.world,
                synthPerformance: synthPerformance
            ))
            state.barIndex = performance.bar + 1
        }
        return blocks
    }

    private static func outputSafety(_ input: Float) -> Float {
        Float(tanh(Double(input) * 1.04) / tanh(1.04) * 0.90)
    }

    private static func modulation(performance: PerformanceBar, scene: TechnoScene) -> ModulationState {
        let progress = Double(performance.localBar) / Double(max(1, performance.phraseLength - 1))
        let phase = progress * 2 * Double.pi
        let motion = 0.5 + 0.5 * sin(phase)
        return ModulationState(
            phase: phase,
            brightness: min(1, (1 - scene.darkness) * 0.24 + performance.tension * 0.52),
            density: min(1, Double(performance.roles.count) / 4 * 0.62 + performance.tension * 0.20),
            space: min(1, scene.atmosphere * 0.68 + (performance.section == .breakdown ? 0.26 : 0)),
            cutoff: min(1, 0.16 + performance.tension * 0.68),
            resonance: min(1, 0.10 + scene.hypnosis * 0.36 + motion * 0.18),
            bassArticulation: min(1, 0.24 + scene.aggression * 0.42 + performance.tension * 0.18),
            fillIntensity: min(1, scene.drumChaos * 0.38 + progress * 0.32)
        )
    }

    private static func voiceKind(_ voice: EnsembleVoice) -> VoiceKind {
        switch voice {
        case .kick: .kick
        case .bass: .bass
        case .percussion: .percussion
        case .motif: .synth
        case .response: .lead
        case .atmosphere: .pad
        case .transition: .riser
        }
    }

    private static func effectKind(_ kind: DSPGraphNodeKind) -> EffectKind {
        switch kind {
        case .toneGuard: .busEQ
        case .saturation, .waveFold: .saturation
        case .phaser: .phaser
        case .chorus, .stereoMotion: .chorus
        case .comb, .resonator: .comb
        case .echo: .unsyncedEcho
        case .diffusion: .reverb
        }
    }

    private static func busStates(rendered: RenderedBar, scene: TechnoScene,
                                  events: [VoiceEvent]) -> [VoiceKind: BusState] {
        let headroom = max(0, 1 - Double(rendered.peak))
        return Dictionary(uniqueKeysWithValues: Set(events.map(\.voice)).map { voice in
            let level: Double
            switch voice {
            case .kick: level = 1
            case .bass: level = scene.character.bassLevel
            case .percussion: level = scene.character.percussionBrightness
            case .synth, .lead: level = scene.synthPresence
            case .pad, .riser: level = scene.atmosphere
            }
            return (voice, BusState(
                level: Double(rendered.rms) * level,
                send: voice == .kick || voice == .bass ? 0 : scene.atmosphere * 0.30,
                headroom: headroom
            ))
        })
    }
}
