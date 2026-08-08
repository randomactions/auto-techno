import AutoTechnoCore
import Foundation

public enum V2VoiceKind: String, CaseIterable, Sendable {
    case kick, bass, hats, clap, percussion, synth, lead, pad, sequencerAmbient, riser, texture
}

public enum V2EffectKind: String, CaseIterable, Sendable {
    case busEQ, maskingGuard, sidechain, textureRack, analogLadder, saturation
    case alienHarmonics, feedbackFilter, comb, unsyncedEcho
    case phaser, chorus, earlyReflection, delay, reverb, glue, master
}

public enum V2MasteringProfile: String, CaseIterable, Sendable {
    case clubPunch = "Club Punch"
    case headroomReference = "Headroom Reference"

    public var glueThreshold: Double { self == .clubPunch ? 0.42 : 0.52 }
    public var glueRatio: Double { self == .clubPunch ? 2.8 : 1.8 }
    public var makeupGain: Double { self == .clubPunch ? 1.015 : 0.96 }
    public var limiterDrive: Double { self == .clubPunch ? 1.12 : 0.92 }
    public var limiterCeiling: Double { self == .clubPunch ? 0.78 : 0.70 }
}

/// Development/reference variants for isolating effect families. The
/// product default is `full`; the other profiles are deliberately exposed
/// only through Under the Hood so technical DSP choices do not become primary
/// listener controls.
public enum V2EffectProfile: String, CaseIterable, Sendable {
    case full = "Full Texture"
    case motionOnly = "Motion Only"
    case dryReference = "Dry Reference"

    var textureRackEnabled: Bool { self == .full }
    var spatialEnabled: Bool { self != .dryReference }
    var nonlinearEnabled: Bool { self == .full }
}

public enum V2StemKind: String, CaseIterable, Sendable {
    case foundation, percussion, musicalVoices, atmosphere, returns
}

public enum V2PerformanceModel: String, CaseIterable, Sendable {
    case approvedV2
    case persistentV3
}

/// Offline/reference code may select the frozen baseline. The shipped app
/// always requests `alienAnalogV1` explicitly.
public enum SynthEngineProfile: String, CaseIterable, Sendable {
    case legacyReference
    case alienAnalogV1
}

public enum SynthRhythmProfile: String, CaseIterable, Sendable {
    case anchorOnly
    case interlocked
}

public enum DramaticInstrumentProfile: String, CaseIterable, Sendable {
    case legacyVoice = "Legacy voice"
    case authoredPatch = "Authored patch"
}

public struct V2EffectState: Equatable, Sendable {
    public let kind: V2EffectKind
    public let amount: Double
    public let active: Bool

    public init(kind: V2EffectKind, amount: Double, active: Bool = true) {
        self.kind = kind
        self.amount = min(1, max(0, amount))
        self.active = active
    }
}

public struct V2VoiceEvent: Equatable, Sendable {
    public let voice: V2VoiceKind
    public let bar: Int
    public let step: Int
    public let intensity: Double

    public init(voice: V2VoiceKind, bar: Int, step: Int, intensity: Double) {
        self.voice = voice
        self.bar = bar
        self.step = step
        self.intensity = intensity
    }
}

public struct V2ModulationState: Equatable, Sendable {
    public let phase: Double
    public let brightness: Double
    public let density: Double
    public let space: Double
    public let cutoff: Double
    public let resonance: Double
    public let bassArticulation: Double
    public let fillIntensity: Double

    public init(phase: Double, brightness: Double, density: Double, space: Double,
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

public struct V2BusState: Equatable, Sendable {
    public var level: Double
    public var send: Double
    public var headroom: Double

    public init(level: Double = 0, send: Double = 0, headroom: Double = 1) {
        self.level = level
        self.send = send
        self.headroom = headroom
    }
}

public struct V2RenderState: Sendable {
    public var barIndex: Int = 0
    public var synthPhase = 0.0
    public var authoredSynthPhaseA = 0.0
    public var authoredSynthPhaseB = 0.0
    public var authoredSynthPhaseSub = 0.0
    public var authoredSynthPhaseFifth = 0.0
    public var authoredSynthLFOPhase = 0.0
    public var authoredSynthFilterLow = 0.0
    public var authoredSynthFilterBand = 0.0
    public var authoredSynthFilterLow2 = 0.0
    public var authoredSynthFilterBand2 = 0.0
    public var authoredSynthEnvelope = 0.0
    public var authoredSynthFrequency = 65.41
    public var sequencerPhase = 0.0
    public var acidPhase = 0.0
    public var acidFilter = 0.0
    public var bassPhase = 0.0
    public var bassFilter = 0.0
    public var modulationPhase = 0.0
    public var busStates: [V2VoiceKind: V2BusState] = [:]
    public var delayBuffer: [Float] = []
    public var delayWriteIndex = 0
    public var earlyReflectionBuffer: [Float] = []
    public var earlyReflectionWriteIndex = 0
    public var textureDelay: [Float] = []
    public var textureWriteIndex = 0
    public var texturePhase = 0.0
    public var stereoPanPhase = 0.0
    public var chorusDelay: [Float] = []
    public var chorusWriteIndex = 0
    public var chorusPhase = 0.0
    public var padPhase = 0.0
    public var noiseFilter = 0.0
    public var leadPhase = 0.0
    public var dronePhase = 0.0
    public var droneNoise = 0.0
    public var riserPhase = 0.0
    public var phaserStateA = 0.0
    public var phaserStateB = 0.0
    public var textureLadder1 = 0.0
    public var textureLadder2 = 0.0
    public var textureLadder3 = 0.0
    public var textureLadder4 = 0.0
    public var masterEnvelope = 0.0
    public var lowBandEnvelope = 0.0
    public var highBandEnvelope = 0.0
    public var tapeMemory = 0.0
    public var reverbBuffer: [Float] = []
    public var reverbWriteIndex = 0
    var alienAnchorState = AlienVoiceState()
    var alienShadowState = AlienVoiceState()
    var alienAtmosphereState = AlienVoiceState()
    var alienResponseState = AlienVoiceState()
    var alienTransitionState = AlienVoiceState()

    public init() {}

    public mutating func reset() {
        barIndex = 0
        synthPhase = 0
        authoredSynthPhaseA = 0
        authoredSynthPhaseB = 0
        authoredSynthPhaseSub = 0
        authoredSynthPhaseFifth = 0
        authoredSynthLFOPhase = 0
        authoredSynthFilterLow = 0
        authoredSynthFilterBand = 0
        authoredSynthFilterLow2 = 0
        authoredSynthFilterBand2 = 0
        authoredSynthEnvelope = 0
        authoredSynthFrequency = 65.41
        sequencerPhase = 0
        acidPhase = 0
        acidFilter = 0
        bassPhase = 0
        bassFilter = 0
        modulationPhase = 0
        busStates.removeAll()
        delayBuffer.removeAll(keepingCapacity: true)
        delayWriteIndex = 0
        earlyReflectionBuffer.removeAll(keepingCapacity: true)
        earlyReflectionWriteIndex = 0
        textureDelay.removeAll(keepingCapacity: true)
        textureWriteIndex = 0
        texturePhase = 0
        stereoPanPhase = 0
        chorusDelay.removeAll(keepingCapacity: true)
        chorusWriteIndex = 0
        chorusPhase = 0
        padPhase = 0
        noiseFilter = 0
        leadPhase = 0
        dronePhase = 0
        droneNoise = 0
        riserPhase = 0
        phaserStateA = 0
        phaserStateB = 0
        textureLadder1 = 0
        textureLadder2 = 0
        textureLadder3 = 0
        textureLadder4 = 0
        masterEnvelope = 0
        lowBandEnvelope = 0
        highBandEnvelope = 0
        tapeMemory = 0
        reverbBuffer.removeAll(keepingCapacity: true)
        reverbWriteIndex = 0
        alienAnchorState.reset()
        alienShadowState.reset()
        alienAtmosphereState.reset()
        alienResponseState.reset()
        alienTransitionState.reset()
    }
}

public struct V2RenderBlock: Equatable, Sendable {
    public let bar: Int
    public let section: SectionKind
    public let left: [Float]
    public let right: [Float]
    public let events: [V2VoiceEvent]
    public let modulation: V2ModulationState
    public let busStates: [V2VoiceKind: V2BusState]
    public let peak: Float
    public let truePeakEstimate: Float
    public let rms: Float
    /// An RMS-derived comparison estimate, not a standards-compliant LUFS meter.
    public let loudnessEstimate: Float
    public let stereoCorrelation: Float
    public let masking: [MaskingDecision]
    public let effects: [V2EffectState]
    public let performance: PerformanceBar?
    public let dramaticThesis: DramaticThesis?
    public let sceneDNA: SceneDNA?
    public let dramaticJourney: DramaticJourneyBar?
    public let instrumentPatch: InstrumentPatchDNA?
    public let synthEngine: SynthEngineProfile
    public let synthWorld: SynthWorldDNA?
    public let synthPerformance: SynthPerformanceBar?

    public init(bar: Int, section: SectionKind, left: [Float], right: [Float], events: [V2VoiceEvent], modulation: V2ModulationState,
                busStates: [V2VoiceKind: V2BusState], masking: [MaskingDecision] = [], effects: [V2EffectState] = [],
                performance: PerformanceBar? = nil, dramaticThesis: DramaticThesis? = nil,
                sceneDNA: SceneDNA? = nil, dramaticJourney: DramaticJourneyBar? = nil,
                instrumentPatch: InstrumentPatchDNA? = nil,
                synthEngine: SynthEngineProfile = .legacyReference,
                synthWorld: SynthWorldDNA? = nil,
                synthPerformance: SynthPerformanceBar? = nil) {
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
        self.dramaticThesis = dramaticThesis
        self.sceneDNA = sceneDNA
        self.dramaticJourney = dramaticJourney
        self.instrumentPatch = instrumentPatch
        self.synthEngine = synthEngine
        self.synthWorld = synthWorld
        self.synthPerformance = synthPerformance
        peak = zip(left, right).reduce(0) { max($0, abs($1.0), abs($1.1)) }
        truePeakEstimate = max(Self.cubicPeak(left), Self.cubicPeak(right))
        let count = max(1, min(left.count, right.count))
        let leftEnergy = left.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        let rightEnergy = right.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        rms = Float(sqrt((leftEnergy + rightEnergy) / Double(count * 2)))
        loudnessEstimate = Float(-0.691 + 20.0 * log10(max(Double(rms), 0.000000001)))
        let cross = zip(left.prefix(count), right.prefix(count)).reduce(0.0) { $0 + Double($1.0 * $1.1) }
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
                let t = Double(subdivision) / 4.0
                let value = 0.5 * ((2 * p1) + (-p0 + p2) * t +
                    (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                    (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
                result = max(result, abs(Float(value)))
            }
        }
        return result
    }
}

public struct V2Arrangement: Equatable, Sendable {
    public static let barCount = 32
    public let sections: [SectionKind]

    public init(seed: UInt64) {
        var random = SeededGenerator(seed: seed ^ 0xD1B54A32D192ED03)
        sections = (0..<Self.barCount).map { bar in
            switch bar {
            case 0..<8: .groove
            case 8..<16: .build
            case 16..<24: .breakdown
            default: bar == 24 ? .returnSection : (random.chance(0.18) ? .build : .returnSection)
            }
        }
    }

    public func section(at bar: Int) -> SectionKind {
        sections[((bar % sections.count) + sections.count) % sections.count]
    }
}

struct V2RenderBuffers {
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

struct V2RenderWorkspace {
    var buffers = V2RenderBuffers()

    mutating func checkout(frameCount: Int) -> V2RenderBuffers {
        var checkedOut = V2RenderBuffers()
        swap(&checkedOut, &buffers)
        checkedOut.reset(frameCount: frameCount)
        return checkedOut
    }

    mutating func recycle(_ returned: inout V2RenderBuffers) {
        swap(&buffers, &returned)
    }
}

/// Parallel v2 orchestration layer. It renders explicit procedural voices and
/// stateful effect memory behind a 32-bar contract, without changing the app
/// scheduler or semantic scene model.
public enum V2ProceduralEngine {
    /// Read-only product telemetry for Under the Hood. This mirrors the
    /// actual polished signal order and deliberately contains no mutable DSP
    /// state or render-time work.
    public static let effectStageSummary =
        "Alien harmonics → feedback filter → comb → unsynced echo → masking guard → sidechain → chorus → dark reverb → glue → safe master"

    public static func render32Bars(
        scene: TechnoScene,
        sampleRate: Double,
        state: inout V2RenderState,
        treatment: RenderTreatment = .polished,
        mastering: V2MasteringProfile = .clubPunch,
        effects: V2EffectProfile = .full,
        isolatedStem: V2StemKind? = nil,
        performanceModel: V2PerformanceModel = .approvedV2,
        synthEngine: SynthEngineProfile = .legacyReference,
        synthRhythm: SynthRhythmProfile = .anchorOnly
    ) -> [V2RenderBlock] {
        let performancePlan = PerformancePlan(scene: scene)
        let synthPlan = SynthPerformancePlan(
            scene: scene,
            performance: performancePlan,
            includeInterlocks: synthRhythm == .interlocked
        )
        let legacyArrangement = V2Arrangement(seed: scene.seed)
        var blocks: [V2RenderBlock] = []
        blocks.reserveCapacity(V2Arrangement.barCount)
        var workspace = V2RenderWorkspace()

        for bar in 0..<V2Arrangement.barCount {
            let performance = performanceModel == .persistentV3 ? performancePlan.bars[bar] : nil
            let section = performance?.section ?? legacyArrangement.section(at: bar)
            let lane = modulationLane(bar: bar, scene: scene)
            let barScene = modulatedScene(scene, bar: bar, lane: lane, preserveIdentity: performance != nil)
            let rendered = V2VoiceRenderer.renderBar(scene: barScene, section: section, sampleRate: sampleRate,
                                                     state: &state, treatment: treatment, mastering: mastering,
                                                     effects: effects, dna: performance == nil ? nil : performancePlan.dna,
                                                     performance: performance,
                                                     synthEngine: synthEngine,
                                                     synthWorld: synthPlan.world,
                                                     synthPerformance: synthPlan.bars[bar],
                                                     workspace: &workspace,
                                                     isolatedStem: isolatedStem)
            let renderedEvents = performance.map {
                events(for: bar, scene: barScene, section: section, dna: performancePlan.dna, performance: $0)
            } ?? legacyEvents(for: bar, scene: barScene, section: section)
            let buses = busStates(for: rendered, scene: barScene, events: renderedEvents)
            let masking = rendered.masking
            let effectStates = effectStates(scene: barScene, lane: lane, masking: masking,
                                            treatment: treatment, profile: effects,
                                            synthEngine: synthEngine)
            blocks.append(V2RenderBlock(bar: bar, section: section, left: rendered.leftSamples, right: rendered.rightSamples,
                                        events: renderedEvents, modulation: lane.snapshot, busStates: buses, masking: masking,
                                        effects: effectStates, performance: performance,
                                        dramaticThesis: performance == nil ? nil : performancePlan.thesis,
                                        sceneDNA: performance == nil ? nil : performancePlan.dna,
                                        synthEngine: synthEngine,
                                        synthWorld: synthEngine == .alienAnalogV1 ? synthPlan.world : nil,
                                        synthPerformance: synthEngine == .alienAnalogV1 ? synthPlan.bars[bar] : nil))
            state.barIndex = bar + 1
            state.modulationPhase = lane.phase
            state.busStates = buses
        }
        return blocks
    }

    public static func renderPersistent32Bars(scene: TechnoScene, sampleRate: Double, state: inout V2RenderState,
                                              treatment: RenderTreatment = .polished,
                                              mastering: V2MasteringProfile = .clubPunch,
                                              effects: V2EffectProfile = .full,
                                              synthEngine: SynthEngineProfile = .alienAnalogV1,
                                              synthRhythm: SynthRhythmProfile = .interlocked) -> [V2RenderBlock] {
        render32Bars(scene: scene, sampleRate: sampleRate, state: &state, treatment: treatment,
                     mastering: mastering, effects: effects, performanceModel: .persistentV3,
                     synthEngine: synthEngine, synthRhythm: synthRhythm)
    }

    /// Offline-only 96-bar proof for the dramatic debt/payoff architecture.
    /// The score and all arrays are prepared away from the audio callback; the
    /// live app keeps using its existing immutable 32-bar scheduling path.
    public static func renderDramaticJourney96Bars(
        scene: TechnoScene,
        sampleRate: Double,
        state: inout V2RenderState,
        treatment: RenderTreatment = .polished,
        mastering: V2MasteringProfile = .clubPunch,
        effects: V2EffectProfile = .full,
        instrument: DramaticInstrumentProfile = .authoredPatch,
        isolatedStem: V2StemKind? = nil
    ) -> [V2RenderBlock] {
        let plan = DramaticJourneyPlan(scene: scene)
        var blocks: [V2RenderBlock] = []
        blocks.reserveCapacity(DramaticJourneyPlan.barCount)
        var workspace = V2RenderWorkspace()

        for journey in plan.bars {
            let performance = journey.performanceBar()
            let lane = dramaticModulationLane(journey: journey, scene: scene)
            let barScene = dramaticScene(scene, journey: journey, lane: lane)
            let rendered = V2VoiceRenderer.renderBar(
                scene: barScene,
                section: journey.section,
                sampleRate: sampleRate,
                state: &state,
                treatment: treatment,
                mastering: mastering,
                effects: effects,
                dna: plan.dna,
                performance: performance,
                journey: journey,
                patch: instrument == .authoredPatch ? plan.patch : nil,
                synthEngine: .legacyReference,
                workspace: &workspace,
                isolatedStem: isolatedStem
            )
            let renderedEvents = events(for: journey.bar, scene: barScene, section: journey.section,
                                        dna: plan.dna, performance: performance, journey: journey)
            let buses = busStates(for: rendered, scene: barScene, events: renderedEvents)
            let masking = rendered.masking
            let renderedEffects = effectStates(scene: barScene, lane: lane, masking: masking,
                                               treatment: treatment, profile: effects,
                                               synthEngine: .legacyReference)
            blocks.append(V2RenderBlock(
                bar: journey.bar,
                section: journey.section,
                left: rendered.leftSamples,
                right: rendered.rightSamples,
                events: renderedEvents,
                modulation: lane.snapshot,
                busStates: buses,
                masking: masking,
                effects: renderedEffects,
                performance: performance,
                dramaticThesis: .pressureAndRelease,
                sceneDNA: plan.dna,
                dramaticJourney: journey,
                instrumentPatch: instrument == .authoredPatch ? plan.patch : nil
            ))
            state.barIndex = journey.bar + 1
            state.modulationPhase = lane.phase
            state.busStates = buses
        }
        return blocks
    }

    /// Offline-only stem preparation. Each stem is deterministically rerendered
    /// through the same immutable score; this never runs on the audio callback.
    public static func renderStems32Bars(scene: TechnoScene, sampleRate: Double,
                                         treatment: RenderTreatment = .polished,
                                         mastering: V2MasteringProfile = .headroomReference,
                                         effects: V2EffectProfile = .full,
                                         synthEngine: SynthEngineProfile = .alienAnalogV1,
                                         synthRhythm: SynthRhythmProfile = .interlocked) -> [V2StemKind: [V2RenderBlock]] {
        Dictionary(uniqueKeysWithValues: V2StemKind.allCases.map { stem in
            var state = V2RenderState()
            return (stem, render32Bars(scene: scene, sampleRate: sampleRate, state: &state,
                                       treatment: treatment, mastering: mastering, effects: effects,
                                       isolatedStem: stem, performanceModel: .persistentV3,
                                       synthEngine: synthEngine, synthRhythm: synthRhythm))
        })
    }

    private static func effectStates(scene: TechnoScene, lane: ModulationLane,
                                     masking: [MaskingDecision], treatment: RenderTreatment,
                                     profile: V2EffectProfile,
                                     synthEngine: SynthEngineProfile) -> [V2EffectState] {
        let strongestMask = masking.map(\.cut).max() ?? 0
        if synthEngine == .alienAnalogV1 {
            return [
                V2EffectState(kind: .busEQ, amount: 0.72),
                V2EffectState(kind: .maskingGuard, amount: strongestMask, active: strongestMask > 0),
                V2EffectState(kind: .sidechain, amount: min(1, 0.25 + scene.aggression * 0.55)),
                V2EffectState(kind: .alienHarmonics, amount: min(1, 0.42 + scene.synthChaos * 0.48)),
                V2EffectState(kind: .feedbackFilter, amount: min(1, 0.36 + scene.hypnosis * 0.46)),
                V2EffectState(kind: .comb, amount: min(1, 0.24 + scene.textureChaos * 0.48)),
                V2EffectState(kind: .unsyncedEcho, amount: min(1, 0.22 + scene.hypnosis * 0.42)),
                V2EffectState(kind: .chorus, amount: min(1, 0.10 + scene.atmosphere * 0.52), active: treatment == .polished && profile.spatialEnabled),
                V2EffectState(kind: .earlyReflection, amount: min(1, 0.08 + scene.atmosphere * 0.42), active: treatment == .polished && profile.spatialEnabled),
                V2EffectState(kind: .delay, amount: min(1, 0.16 + lane.space * 0.52), active: profile.spatialEnabled),
                V2EffectState(kind: .reverb, amount: min(1, lane.space * 0.62), active: treatment == .polished && profile.spatialEnabled),
                V2EffectState(kind: .glue, amount: min(1, 0.20 + lane.density * 0.42)),
                V2EffectState(kind: .master, amount: 0.88)
            ]
        }
        return [
            V2EffectState(kind: .busEQ, amount: 0.72),
            V2EffectState(kind: .maskingGuard, amount: strongestMask, active: strongestMask > 0),
            V2EffectState(kind: .sidechain, amount: min(1, 0.25 + scene.aggression * 0.55)),
            V2EffectState(kind: .textureRack, amount: treatment == .polished && profile.textureRackEnabled ? 1 : 0, active: treatment == .polished && profile.textureRackEnabled),
            V2EffectState(kind: .analogLadder, amount: min(1, 0.18 + scene.synthPresence * 0.52), active: treatment == .polished && profile.nonlinearEnabled),
            V2EffectState(kind: .saturation, amount: min(1, 0.16 + scene.aggression * 0.58), active: profile.nonlinearEnabled),
            V2EffectState(kind: .phaser, amount: min(1, 0.12 + scene.textureChaos * 0.46), active: treatment == .polished && profile.textureRackEnabled),
            V2EffectState(kind: .chorus, amount: min(1, 0.10 + scene.atmosphere * 0.52), active: treatment == .polished && profile.spatialEnabled),
            V2EffectState(kind: .earlyReflection, amount: min(1, 0.08 + scene.atmosphere * 0.42), active: treatment == .polished && profile.spatialEnabled),
            V2EffectState(kind: .delay, amount: min(1, 0.16 + lane.space * 0.52), active: profile.spatialEnabled),
            V2EffectState(kind: .reverb, amount: min(1, lane.space * 0.62), active: treatment == .polished && profile.spatialEnabled),
            V2EffectState(kind: .glue, amount: min(1, 0.20 + lane.density * 0.42)),
            V2EffectState(kind: .master, amount: 0.88)
        ]
    }

    private struct ModulationLane {
        let phase: Double
        let brightness: Double
        let density: Double
        let space: Double
        let cutoff: Double
        let resonance: Double
        let bassArticulation: Double
        let fillIntensity: Double
        var snapshot: V2ModulationState {
            V2ModulationState(phase: phase, brightness: brightness, density: density, space: space,
                              cutoff: cutoff, resonance: resonance, bassArticulation: bassArticulation,
                              fillIntensity: fillIntensity)
        }
    }

    private static func modulationLane(bar: Int, scene: TechnoScene) -> ModulationLane {
        let phase = Double(bar % 16) / 16.0 * 2.0 * Double.pi
        let movement = 0.5 + 0.5 * sin(phase)
        let longArc = 0.5 + 0.5 * sin(Double(bar % 32) / 32.0 * 2.0 * Double.pi - Double.pi / 2)
        let phraseArc = 0.5 + 0.5 * sin(Double(bar % 8) / 8.0 * 2.0 * Double.pi)
        return ModulationLane(
            phase: phase,
            brightness: min(1, scene.darkness * 0.35 + movement * 0.25),
            density: min(1, scene.noteActivity * 0.45 + movement * 0.25),
            space: min(1, scene.atmosphere * (0.7 + movement * 0.3)),
            cutoff: min(1, 0.18 + scene.synthPresence * 0.42 + longArc * 0.28),
            resonance: min(1, 0.10 + scene.synthChaos * 0.22 + phraseArc * 0.16),
            bassArticulation: min(1, 0.22 + scene.aggression * 0.38 + (1 - longArc) * 0.18),
            fillIntensity: min(1, scene.drumChaos * 0.35 + phraseArc * 0.22 + (bar >= 24 ? 0.12 : 0))
        )
    }

    private static func dramaticModulationLane(journey: DramaticJourneyBar,
                                               scene: TechnoScene) -> ModulationLane {
        let tension = journey.tension
        let phase = Double(journey.bar) / Double(DramaticJourneyPlan.barCount) * 2 * Double.pi
        return ModulationLane(
            phase: phase,
            brightness: min(1, 0.10 + (1 - scene.darkness) * 0.18 + tension.spectralPressure * 0.62),
            density: tension.density,
            space: journey.patchMacros.distance,
            cutoff: min(1, 0.10 + tension.spectralPressure * 0.76),
            resonance: min(1, 0.10 + tension.harmonicInstability * 0.62 + tension.rhythmicExpectation * 0.12),
            bassArticulation: min(1, 0.20 + journey.lowEndPresence * 0.42 + journey.payoffStrength * 0.34),
            fillIntensity: min(1, tension.rhythmicExpectation * 0.72 + journey.payoffStrength * 0.18)
        )
    }

    private static func modulatedScene(_ scene: TechnoScene, bar: Int, lane: ModulationLane,
                                       preserveIdentity: Bool) -> TechnoScene {
        let intent = scene.musicalIntent ?? MusicalIntent()
        var values: [MusicalControl: Double] = [:]
        for control in MusicalControl.allCases { values[control] = intent[control] }
        values[.atmosphere] = lane.space
        values[.synthPresence] = min(1, intent[.synthPresence] + lane.brightness * 0.12)
        values[.noteActivity] = min(1, intent[.noteActivity] + lane.density * 0.10)
        // Mutate roles together: density changes the percussion and note
        // system as one musical decision; cutoff/resonance changes the synth
        // and texture family together instead of producing isolated knobs.
        values[.drumChaos] = min(1, intent[.drumChaos] + lane.density * 0.08 + lane.fillIntensity * 0.10)
        values[.noteActivity] = min(1, values[.noteActivity]! + lane.fillIntensity * 0.05)
        values[.synthPresence] = min(1, values[.synthPresence]! + lane.cutoff * 0.04)
        values[.textureChaos] = min(1, intent[.textureChaos] + (bar >= 16 ? 0.04 : 0) + lane.resonance * 0.08)
        values[.darkness] = min(1, max(0, intent[.darkness] + (0.5 - lane.cutoff) * 0.16))
        values[.synthChaos] = min(1, intent[.synthChaos] + lane.resonance * 0.08)
        values[.aggression] = min(1, intent[.aggression] + lane.bassArticulation * 0.06)
        // The seed remains stable across the scene. Variation comes from the
        // immutable performance plan, not from silently regenerating identity.
        return TechnoScene(intent: MusicalIntent(values: values),
                           seed: preserveIdentity ? scene.seed : scene.seed &+ UInt64(bar), bpm: scene.bpm)
    }

    private static func dramaticScene(_ scene: TechnoScene, journey: DramaticJourneyBar,
                                      lane: ModulationLane) -> TechnoScene {
        let intent = scene.musicalIntent ?? MusicalIntent()
        var values = Dictionary(uniqueKeysWithValues: MusicalControl.allCases.map { ($0, intent[$0]) })
        values[.atmosphere] = min(1, intent[.atmosphere] * 0.46 + journey.patchMacros.distance * 0.54)
        values[.noteActivity] = min(1, intent[.noteActivity] * 0.72 + journey.tension.density * 0.28)
        values[.synthPresence] = min(1, intent[.synthPresence] * 0.72 + lane.cutoff * 0.18 + journey.tension.density * 0.10)
        values[.drumChaos] = min(1, intent[.drumChaos] * 0.68 + journey.tension.rhythmicExpectation * 0.24)
        values[.textureChaos] = min(1, intent[.textureChaos] * 0.62 + journey.tension.spatialDistance * 0.20 + journey.tension.harmonicInstability * 0.18)
        values[.synthChaos] = min(1, intent[.synthChaos] * 0.58 + journey.tension.harmonicInstability * 0.42)
        values[.aggression] = min(1, intent[.aggression] * 0.72 + journey.patchMacros.bite * 0.20 + journey.patchMacros.impact * 0.12)
        values[.darkness] = min(1, max(0, intent[.darkness] + journey.tension.spatialDistance * 0.08 - journey.tension.spectralPressure * 0.06))
        return TechnoScene(intent: MusicalIntent(values: values).preservingCorrelations(),
                           seed: scene.seed, bpm: scene.bpm)
    }

    private static func legacyEvents(for bar: Int, scene: TechnoScene, section: SectionKind) -> [V2VoiceEvent] {
        var result = scene.steps.enumerated().flatMap { index, step -> [V2VoiceEvent] in
            var events: [V2VoiceEvent] = []
            if step.kick { events.append(V2VoiceEvent(voice: .kick, bar: bar, step: index, intensity: 1)) }
            if step.bass { events.append(V2VoiceEvent(voice: .bass, bar: bar, step: index, intensity: 0.8)) }
            if section != .breakdown && step.hat { events.append(V2VoiceEvent(voice: .hats, bar: bar, step: index, intensity: 0.5)) }
            if section != .breakdown && step.clap { events.append(V2VoiceEvent(voice: .clap, bar: bar, step: index, intensity: 0.5)) }
            return events
        }
        if section != .breakdown {
            result += scene.motif.map { V2VoiceEvent(voice: .synth, bar: bar, step: $0.stepIndex, intensity: scene.synthPresence) }
        }
        return result
    }

    private static func events(for bar: Int, scene: TechnoScene, section: SectionKind,
                               dna: SceneDNA, performance: PerformanceBar,
                               journey: DramaticJourneyBar? = nil) -> [V2VoiceEvent] {
        var events = dna.rhythm.kickSteps.map { V2VoiceEvent(voice: .kick, bar: bar, step: $0, intensity: 1) }
        if section != .breakdown && performance.roles.contains(.foundation) &&
            (journey?.lowEndPresence ?? 1) > 0.08 {
            events += dna.rhythm.bassSteps.map { V2VoiceEvent(voice: .bass, bar: bar, step: $0, intensity: 0.8) }
        }
        if section != .breakdown {
            events += dna.rhythm.hatSteps.map { V2VoiceEvent(voice: .hats, bar: bar, step: $0, intensity: 0.5) }
            if section == .build || section == .returnSection {
                events.append(V2VoiceEvent(voice: .hats, bar: bar, step: section == .build ? 6 : 14, intensity: 0.3))
            }
        }
        if section == .build || section == .returnSection {
            events.append(V2VoiceEvent(voice: .texture, bar: bar, step: 15, intensity: 0.35))
        }
        if section != .breakdown, let motif = scene.motif.first {
            events.append(V2VoiceEvent(voice: .synth, bar: bar, step: motif.stepIndex, intensity: scene.synthPresence))
        }
        if let event = scene.sequencer.first, scene.musicalIntent?[.sequencerPresence] ?? 0 > 0.04 {
            events.append(V2VoiceEvent(voice: .sequencerAmbient, bar: bar, step: event.stepIndex, intensity: scene.musicalIntent?[.sequencerPresence] ?? 0))
        }
        if section != .breakdown && scene.atmosphere > 0.2 {
            events.append(V2VoiceEvent(voice: .pad, bar: bar, step: 0, intensity: scene.atmosphere * 0.25))
        }
        if section == .breakdown && scene.atmosphere > 0.25 {
            events.append(V2VoiceEvent(voice: .texture, bar: bar, step: 0, intensity: scene.atmosphere * 0.18))
        }
        if (section == .build || section == .returnSection) && scene.melodicity > 0.22 {
            events.append(V2VoiceEvent(voice: .lead, bar: bar, step: section == .build ? 6 : 14, intensity: scene.melodicity * 0.25))
        }
        if section != .breakdown && (scene.drumChaos > 0.18 || section == .build || section == .returnSection) {
            events.append(V2VoiceEvent(voice: .percussion, bar: bar, step: 10 + Int((scene.seed ^ UInt64(bar * 17)) % 5), intensity: 0.25))
        }
        if section == .returnSection && bar % 8 == 7 && scene.drumChaos > 0.16 {
            events += (12..<16).map { V2VoiceEvent(voice: .percussion, bar: bar, step: $0, intensity: 0.22) }
        }
        if section == .build && bar % 8 >= 6 {
            events.append(V2VoiceEvent(voice: .riser, bar: bar, step: 0, intensity: 0.18))
        }
        if (section == .build || section == .returnSection) && scene.polyrhythm > 0.2 {
            events.append(V2VoiceEvent(voice: .percussion, bar: bar, step: (bar * 3 + 5) % 16, intensity: scene.polyrhythm * 0.18))
        }
        if section != .breakdown && laneFill(scene: scene, bar: bar) > 0.28 {
            events.append(V2VoiceEvent(voice: .percussion, bar: bar, step: 15, intensity: 0.18))
        }
        if performance.signatureEvent != nil {
            events.append(V2VoiceEvent(voice: .texture, bar: bar, step: 15, intensity: 0.22 + performance.tension * 0.12))
        }
        return events
    }

    private static func laneFill(scene: TechnoScene, bar: Int) -> Double {
        let phraseArc = 0.5 + 0.5 * sin(Double(bar % 8) / 8.0 * 2.0 * Double.pi)
        return min(1, scene.drumChaos * 0.35 + phraseArc * 0.22 + (bar >= 24 ? 0.12 : 0))
    }

    private static func busStates(for rendered: RenderedBar, scene: TechnoScene, events: [V2VoiceEvent]) -> [V2VoiceKind: V2BusState] {
        let headroom = max(0, 1 - Double(rendered.peak))
        let has = Set(events.map(\.voice))
        var result: [V2VoiceKind: V2BusState] = [:]
        for voice in V2VoiceKind.allCases where has.contains(voice) {
            let roleLevel: Double
            switch voice {
            case .kick: roleLevel = 1.0
            case .bass: roleLevel = scene.character.bassLevel
            case .hats, .clap, .percussion: roleLevel = scene.character.percussionBrightness
            case .synth, .lead: roleLevel = scene.synthPresence
            case .pad, .sequencerAmbient, .riser, .texture: roleLevel = scene.atmosphere
            }
            let send = voice == .pad || voice == .lead || voice == .riser || voice == .texture ? scene.atmosphere : 0
            result[voice] = V2BusState(level: Double(rendered.rms) * roleLevel, send: send, headroom: headroom)
        }
        return result
    }

    private static func maskingDecisions(for rendered: RenderedBar, buses: [V2VoiceKind: V2BusState], events: [V2VoiceEvent]) -> [MaskingDecision] {
        let active = Set(events.map(\.voice))
        let source = rendered.leftSamples
        let scale: (V2VoiceKind) -> Float = { voice in
            guard active.contains(voice) else { return 0 }
            return Float(buses[voice]?.level ?? 0.01)
        }
        let signals: [MaskingRole: [Float]] = [
            .kickBass: source.map { $0 * max(scale(.kick), scale(.bass)) },
            .percussion: source.map { $0 * max(scale(.hats), scale(.percussion)) },
            .synth: source.map { $0 * max(scale(.synth), max(scale(.lead), scale(.pad))) },
            .texture: source.map { $0 * max(scale(.texture), scale(.riser)) }
        ]
        return SpectrumMaskingAnalyzer.analyze(signals: signals, sampleRate: rendered.sampleRate)
    }
}
