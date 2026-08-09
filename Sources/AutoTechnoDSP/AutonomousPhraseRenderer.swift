import AutoTechnoCore
import Foundation

package enum VoiceKind: String, CaseIterable, Sendable {
    case kick, bass, rumble, percussion, clap, openHat, tunedTom, metallic, groovePulse
    case synth, lead, pad, riser
}

package enum EffectKind: String, CaseIterable, Sendable {
    case busEQ, maskingGuard, saturation, phaser, chorus, comb, unsyncedEcho, pulseEcho
    case reverb, glue, master
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
    package let pulseClass: SixteenthPulseClass?
    package let timingOffsetInSteps: Double
    package let spatialDepthPosition: SpatialDepthPosition
    package let spatialReverbSend: Double
    package let narrativeDirection: NarrativeDirection?
    package let narrativePresence: Double?
    package let narrativeGainScale: Double?
    package let narrativeSpectralScale: Double?
    package let spectralAperture: Double?
    package let anchorSpectralScale: Double?
    package let complementarySpectralScale: Double?
    package let bandPassBlend: Double?
    package let motifSpectralMultiplier: Double?

    package init(voice: VoiceKind, bar: Int, step: Int, intensity: Double,
                 pulseClass: SixteenthPulseClass? = nil,
                 timingOffsetInSteps: Double = 0,
                 spatialDepthPosition: SpatialDepthPosition = .foreground,
                 spatialReverbSend: Double = 0,
                 narrativeDirection: NarrativeDirection? = nil,
                 narrativePresence: Double? = nil,
                 narrativeGainScale: Double? = nil,
                 narrativeSpectralScale: Double? = nil,
                 spectralAperture: Double? = nil,
                 anchorSpectralScale: Double? = nil,
                 complementarySpectralScale: Double? = nil,
                 bandPassBlend: Double? = nil,
                 motifSpectralMultiplier: Double? = nil) {
        self.voice = voice
        self.bar = bar
        self.step = step
        self.intensity = intensity
        self.pulseClass = pulseClass
        self.timingOffsetInSteps = timingOffsetInSteps
        self.spatialDepthPosition = spatialDepthPosition
        self.spatialReverbSend = min(1, max(0, spatialReverbSend))
        self.narrativeDirection = narrativeDirection
        self.narrativePresence = narrativePresence
        self.narrativeGainScale = narrativeGainScale
        self.narrativeSpectralScale = narrativeSpectralScale
        self.spectralAperture = spectralAperture
        self.anchorSpectralScale = anchorSpectralScale
        self.complementarySpectralScale = complementarySpectralScale
        self.bandPassBlend = bandPassBlend
        self.motifSpectralMultiplier = motifSpectralMultiplier
    }
}

package struct ModulationState: Equatable, Sendable {
    package let phase: Double
    package let brightness: Double
    package let density: Double
    package let space: Double
    package let upperTimbreIntent: UpperTimbreIntent
    package let resolvedUpperNoteCount: Int
    package let slideCount: Int

    package init(phase: Double, brightness: Double, density: Double, space: Double,
                upperTimbreIntent: UpperTimbreIntent,
                resolvedUpperNoteCount: Int, slideCount: Int) {
        self.phase = phase
        self.brightness = brightness
        self.density = density
        self.space = space
        self.upperTimbreIntent = upperTimbreIntent
        self.resolvedUpperNoteCount = max(0, resolvedUpperNoteCount)
        self.slideCount = max(0, slideCount)
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

/// Evidence from the two kick paths used during detached rendering. The
/// detector remains pre-fader so groove ducking does not move with mix level;
/// audible values describe the post-fader kick contribution.
package struct KickMixEvidence: Equatable, Sendable {
    package let audibleGain: Double
    package let audiblePeak: Float
    package let audibleRMS: Float
    package let detectorPeak: Float
    package let detectorRMS: Float
    package let duckingEnvelopePeak: Float
}

package struct StemReconstructionEvidence: Equatable, Sendable {
    package let dryCenterMaximumError: Float
    package let upperMaximumError: Float
}

/// Mutable DSP continuation owned by detached phrase preparation. The audio
/// player receives immutable buffers and never mutates this state.
package struct RenderState: Equatable, Sendable {
    package var barIndex = 0
    package var delayBuffer: [Float] = []
    package var delayWriteIndex = 0
    package var pulseEchoBuffer: [Float] = []
    package var pulseEchoWriteIndex = 0
    package var pulseEchoHighPassState = 0.0
    package var pulseEchoLowPassState = 0.0
    package var earlyReflectionBuffer: [Float] = []
    package var earlyReflectionWriteIndex = 0
    package var stereoPanPhase = 0.0
    package var chorusDelay: [Float] = []
    package var chorusWriteIndex = 0
    package var chorusPhase = 0.0
    package var masterEnvelope = 0.0
    package var lowBandEnvelope = 0.0
    package var highBandEnvelope = 0.0
    package var automaticMixState = AutomaticMixState()
    package var reverbBuffer: [Float] = []
    package var reverbWriteIndex = 0
    var resonantFoundationState = ResonantMonoState()
    var resonantAnchorState = ResonantMonoState()
    var resonantShadowState = ResonantMonoState()
    var resonantResponseState = ResonantMonoState()
    var alienAnchorState = AlienVoiceState()
    var alienShadowState = AlienVoiceState()
    var alienAtmosphereState = AlienVoiceState()
    var alienResponseState = AlienVoiceState()
    var alienTransitionState = AlienVoiceState()
    var spectralResponseState = SpectralTextureState()
    var spectralAtmosphereState = SpectralTextureState()
    var spectralTransitionState = SpectralTextureState()
    package var previousResonantAnchorEvidenceFrame: UpperTimbreStereoFrame?
    package var previousDetunedCompanionEvidenceFrame: UpperTimbreStereoFrame?
    package var previousGraphInputRemainderEvidenceFrame: UpperTimbreStereoFrame?
    package var previousPostGraphRemainderEvidenceFrame: UpperTimbreStereoFrame?

    package init() {}

    package mutating func reset() {
        self = RenderState()
    }
}

/// Renderer-owned observation of the trajectory actually applied to one
/// score note. Requested anchors remain in Core; continuation-dependent home
/// glide and the applied gate outcome are recorded here for the gate window.
/// Release, comb, all-pass, and echo tails deliberately are not mislabeled as
/// a per-note audible end because they may continue across later notes/bars.
package struct UpperNoteRenderEvidence: Equatable, Sendable {
    package let role: SynthRole
    package let onsetFrame: Int
    package let requestedGateEndFrame: Int
    package var appliedGateEndFrame: Int
    package let requestedStartFrequency: Double
    package let appliedStartFrequency: Double
    package let targetEndFrequency: Double
    package var frequencyAtAppliedGateEnd: Double
    package let requestedGate: UpperNoteGate
    package let appliedGate: UpperNoteGate
    package let didRetrigger: Bool
    package let timbreIntent: UpperTimbreIntent
    package let requestedVelocity: Double
    package let appliedVelocity: Double
    package let velocitySpectralEnvelopeScale: Double
    package let velocityDecayScale: Double
    package let instrument: InstrumentAssignment

    package init(
        role: SynthRole,
        onsetFrame: Int,
        requestedGateEndFrame: Int,
        appliedGateEndFrame: Int,
        requestedStartFrequency: Double,
        appliedStartFrequency: Double,
        targetEndFrequency: Double,
        frequencyAtAppliedGateEnd: Double,
        requestedGate: UpperNoteGate,
        appliedGate: UpperNoteGate,
        didRetrigger: Bool,
        timbreIntent: UpperTimbreIntent,
        requestedVelocity: Double,
        appliedVelocity: Double,
        velocitySpectralEnvelopeScale: Double,
        velocityDecayScale: Double,
        instrument: InstrumentAssignment
    ) {
        self.role = role
        self.onsetFrame = max(0, onsetFrame)
        self.requestedGateEndFrame = max(self.onsetFrame, requestedGateEndFrame)
        self.appliedGateEndFrame = max(self.onsetFrame, appliedGateEndFrame)
        self.requestedStartFrequency = requestedStartFrequency
        self.appliedStartFrequency = appliedStartFrequency
        self.targetEndFrequency = targetEndFrequency
        self.frequencyAtAppliedGateEnd = frequencyAtAppliedGateEnd
        self.requestedGate = requestedGate
        self.appliedGate = appliedGate
        self.didRetrigger = didRetrigger
        self.timbreIntent = timbreIntent
        self.requestedVelocity = requestedVelocity
        self.appliedVelocity = min(1, max(0, appliedVelocity))
        self.velocitySpectralEnvelopeScale = velocitySpectralEnvelopeScale
        self.velocityDecayScale = velocityDecayScale
        self.instrument = instrument
    }
}

/// Event-local evidence produced from the exact dry groove-pulse sample while
/// it is rendered. It binds score-owned physical articulation to its signal
/// consequence without analyzing the aggregate percussion stem or retaining
/// raw PCM beyond the bounded render call.
package struct GroovePulseRenderEvidence: Equatable, Sendable {
    package let step: Int
    package let pulseClass: SixteenthPulseClass
    package let stage: WeakSixteenthStage
    package let intensity: Double
    package let timingOffsetInSteps: Double
    package let strikeZone: GroovePulseStrikeZone
    package let damping: Double
    package let timbreMicrovariation: Double
    package let appliedHighPassHz: Double
    package let appliedLowPassHz: Double
    package let appliedClickHz: Double
    package let appliedEnvelopeDecay: Double
    package let appliedClickDecay: Double
    package let renderedFrameCount: Int
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let attackRMS: Double
    package let tailRMS: Double
    package let tailToAttackRatio: Double
    package let tailToAttackDB: Double
    package let lowBandEnergyRatio: Double
    package let midBandEnergyRatio: Double
    package let highBandEnergyRatio: Double
    package let spectralCentroidHz: Double
    package let finite: Bool
}

/// Same-pass evidence for the ordinary closed-hat sample generated from one
/// resolved ensemble event. The score owns the neutral/companion role; DSP
/// owns the exact decay rate and signal consequence. No raw event PCM survives
/// detached preparation.
package struct ClosedHatRenderEvidence: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let step: Int
    package let role: ClosedHatDecayRole
    package let eventIntensity: Double
    package let timingOffsetInSteps: Double
    package let relocated: Bool
    package let appliedLevel: Double
    package let appliedDecayRate: Double
    package let renderedFrameCount: Int
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let attackRMS: Double
    package let tailRMS: Double
    package let tailToAttackDB: Double
    package let spectralCentroidHz: Double
    package let finite: Bool

    package init(
        scoreEventIndex: Int,
        step: Int,
        role: ClosedHatDecayRole,
        eventIntensity: Double,
        timingOffsetInSteps: Double,
        relocated: Bool,
        appliedLevel: Double,
        appliedDecayRate: Double,
        renderedFrameCount: Int,
        sampleHash: String,
        peak: Double,
        rms: Double,
        attackRMS: Double,
        tailRMS: Double,
        tailToAttackDB: Double,
        spectralCentroidHz: Double,
        finite: Bool
    ) {
        self.scoreEventIndex = scoreEventIndex
        self.step = step
        self.role = role
        self.eventIntensity = eventIntensity
        self.timingOffsetInSteps = timingOffsetInSteps
        self.relocated = relocated
        self.appliedLevel = appliedLevel
        self.appliedDecayRate = appliedDecayRate
        self.renderedFrameCount = renderedFrameCount
        self.sampleHash = sampleHash
        self.peak = peak
        self.rms = rms
        self.attackRMS = attackRMS
        self.tailRMS = tailRMS
        self.tailToAttackDB = tailToAttackDB
        self.spectralCentroidHz = spectralCentroidHz
        self.finite = finite
    }
}

/// Bounded, architecture-local evidence from exact dry samples produced during
/// detached preparation. It proves that selected patches reached PCM without
/// retaining reconstructable audio in the scheduled block.
package struct InstrumentArchitectureRenderEvidence: Equatable, Sendable {
    package let architecture: InstrumentArchitecture
    package let assignments: [InstrumentAssignment]
    package let patches: [InstrumentPatch]
    package let uses: [InstrumentUse]
    package let effects: [InstrumentEffect]
    package let eventCount: Int
    package let sampleHash: String
    package let peak: Float
    package let rms: Float
    package let finite: Bool
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
    package let masking: [RoleMaskingObservation]
    package let kickMix: KickMixEvidence
    package let stemObservations: [MixRole: StemObservation]
    package let automaticMix: AutomaticMixPlan
    package let stemReconstruction: StemReconstructionEvidence
    /// Reduced fingerprints of the exact post-fader dry taps used by role
    /// analysis. No stem PCM leaves detached preparation.
    package let dryFoundationSampleHash: String
    package let dryPercussionSampleHash: String
    package let groovePulseRenderEvidence: [GroovePulseRenderEvidence]
    package let closedHatRenderEvidence: [ClosedHatRenderEvidence]
    package let instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence]
    package let upperNoteRenderEvidence: [UpperNoteRenderEvidence]
    /// Transient detached-preparation taps. They never cross into RenderBlock
    /// or the scheduler; only reduced evidence survives phrase preparation.
    package let resonantAnchorSamples: [Float]
    package let detunedCompanionSamples: [Float]

    package init(sampleRate: Double, samples: [Float], leftSamples: [Float],
                rightSamples: [Float], masking: [RoleMaskingObservation] = [],
                kickMix: KickMixEvidence,
                stemObservations: [MixRole: StemObservation],
                automaticMix: AutomaticMixPlan,
                stemReconstruction: StemReconstructionEvidence,
                dryFoundationSampleHash: String,
                dryPercussionSampleHash: String,
                groovePulseRenderEvidence: [GroovePulseRenderEvidence],
                closedHatRenderEvidence: [ClosedHatRenderEvidence] = [],
                instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence] = [],
                upperNoteRenderEvidence: [UpperNoteRenderEvidence],
                resonantAnchorSamples: [Float],
                detunedCompanionSamples: [Float]) {
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
        self.kickMix = kickMix
        self.stemObservations = stemObservations
        self.automaticMix = automaticMix
        self.stemReconstruction = stemReconstruction
        self.dryFoundationSampleHash = dryFoundationSampleHash
        self.dryPercussionSampleHash = dryPercussionSampleHash
        self.groovePulseRenderEvidence = groovePulseRenderEvidence.sorted { $0.step < $1.step }
        self.closedHatRenderEvidence = closedHatRenderEvidence.sorted {
            $0.scoreEventIndex < $1.scoreEventIndex
        }
        self.instrumentRenderEvidence = instrumentRenderEvidence.sorted {
            (InstrumentArchitecture.allCases.firstIndex(of: $0.architecture) ?? 0) <
                (InstrumentArchitecture.allCases.firstIndex(of: $1.architecture) ?? 0)
        }
        self.upperNoteRenderEvidence = upperNoteRenderEvidence
        self.resonantAnchorSamples = resonantAnchorSamples
        self.detunedCompanionSamples = detunedCompanionSamples
    }
}

package struct RenderBlock: Equatable, Sendable {
    package let bar: Int
    package let section: SectionKind
    package let left: [Float]
    package let right: [Float]
    /// Resolved score-event projection used by structural telemetry. It can
    /// contain deliberately suppressed upper events; audible upper onsets and
    /// gates are described only by `upperNoteRenderEvidence`.
    package let events: [VoiceEvent]
    package let modulation: ModulationState
    package let busStates: [VoiceKind: BusState]
    package let peak: Float
    package let truePeakEstimate: Float
    package let rms: Float
    package let loudnessEstimate: Float
    package let stereoCorrelation: Float
    package let masking: [RoleMaskingObservation]
    package let effects: [EffectState]
    package let kickMix: KickMixEvidence
    package let stemObservations: [MixRole: StemObservation]
    package let automaticMix: AutomaticMixPlan
    package let stemReconstruction: StemReconstructionEvidence
    /// Bit-exact fingerprint of the post-fader dry kick/foundation tap. It
    /// excludes percussion, upper voices, shared effects, and nonlinear mix
    /// interactions.
    package let protectedFoundationSampleHash: String
    /// Bit-exact fingerprint of the dry percussion tap used for audible output,
    /// masking evidence, and the drum reverb send.
    package let percussionSampleHash: String
    /// Bit-exact fingerprint of the stereo protected-rhythm render recombined
    /// after the generated graph. It contains foundation and percussion while
    /// excluding newly scheduled upper voices.
    package let protectedRhythmSampleHash: String
    /// Same-pass, event-local evidence for every score-owned groove pulse.
    /// It is reduced into the bounded candidate transaction before scheduling.
    package let groovePulseRenderEvidence: [GroovePulseRenderEvidence]
    /// Same-pass reduced evidence for each ordinary closed-hat score event.
    package let closedHatRenderEvidence: [ClosedHatRenderEvidence]
    package let instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence]
    /// Exact score-owned upper notes used for this bar. The renderer no longer
    /// invents pitch, duration, velocity, or slide decisions after resolution.
    package var resolvedUpperNotes: [ResolvedUpperNote] {
        synthPerformance.upperNotes
    }
    package let upperNoteRenderEvidence: [UpperNoteRenderEvidence]
    /// The existing graph input is the full-render minus protected-rhythm
    /// remainder. It carries the newly scheduled upper path plus any shared
    /// continuation or nonlinear interaction; role-local articulation fields
    /// come only from the dedicated taps above.
    package let graphInputRemainderTimbreEvidence: UpperTimbreEvidence
    package let postGraphRemainderTimbreEvidence: UpperTimbreEvidence
    package let resolvedPerformance: ResolvedPerformanceBar
    package let performance: PerformanceBar
    package let sceneDNA: SceneDNA
    package let synthWorld: SynthWorldDNA
    package let synthPerformance: SynthPerformanceBar

    package init(bar: Int, section: SectionKind, left: [Float], right: [Float],
                events: [VoiceEvent], modulation: ModulationState,
                busStates: [VoiceKind: BusState], masking: [RoleMaskingObservation],
                effects: [EffectState], kickMix: KickMixEvidence,
                stemObservations: [MixRole: StemObservation],
                automaticMix: AutomaticMixPlan,
                stemReconstruction: StemReconstructionEvidence,
                protectedFoundationSampleHash: String,
                percussionSampleHash: String,
                protectedRhythmSampleHash: String,
                groovePulseRenderEvidence: [GroovePulseRenderEvidence],
                closedHatRenderEvidence: [ClosedHatRenderEvidence] = [],
                instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence] = [],
                upperNoteRenderEvidence: [UpperNoteRenderEvidence],
                graphInputRemainderTimbreEvidence: UpperTimbreEvidence,
                postGraphRemainderTimbreEvidence: UpperTimbreEvidence,
                resolvedPerformance: ResolvedPerformanceBar,
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
        self.kickMix = kickMix
        self.stemObservations = stemObservations
        self.automaticMix = automaticMix
        self.stemReconstruction = stemReconstruction
        self.protectedFoundationSampleHash = protectedFoundationSampleHash
        self.percussionSampleHash = percussionSampleHash
        self.protectedRhythmSampleHash = protectedRhythmSampleHash
        self.groovePulseRenderEvidence = groovePulseRenderEvidence.sorted { $0.step < $1.step }
        self.closedHatRenderEvidence = closedHatRenderEvidence.sorted {
            $0.scoreEventIndex < $1.scoreEventIndex
        }
        self.instrumentRenderEvidence = instrumentRenderEvidence.sorted {
            (InstrumentArchitecture.allCases.firstIndex(of: $0.architecture) ?? 0) <
                (InstrumentArchitecture.allCases.firstIndex(of: $1.architecture) ?? 0)
        }
        self.upperNoteRenderEvidence = upperNoteRenderEvidence
        self.graphInputRemainderTimbreEvidence = graphInputRemainderTimbreEvidence
        self.postGraphRemainderTimbreEvidence = postGraphRemainderTimbreEvidence
        self.resolvedPerformance = resolvedPerformance
        performance = resolvedPerformance.performance
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

/// Stable FNV-1a fingerprints over exact IEEE-754 sample bits. Channel count,
/// channel order, lengths, and separators participate so differently shaped
/// detached-preparation taps cannot alias merely by sharing a byte prefix.
enum ExactPCMFingerprint {
    /// Streaming form for bounded event-local evidence. The caller supplies
    /// the known sample count, so this produces the same mono digest as
    /// `mono(_:)` without retaining a second PCM array.
    struct MonoAccumulator {
        private var value: UInt64 = 0xcbf29ce484222325

        init(sampleCount: Int) {
            mix(1)
            mix(0x9e37_79b9)
            mix(UInt32(truncatingIfNeeded: sampleCount))
        }

        mutating func append(_ sample: Float) {
            mix(sample.bitPattern)
        }

        var fingerprint: String {
            fixedWidthFingerprintHex(value)
        }

        private mutating func mix(_ input: UInt32) {
            var bits = input
            for _ in 0..<4 {
                value ^= UInt64(bits & 0xff)
                value &*= 0x100000001b3
                bits >>= 8
            }
        }
    }

    static func mono(_ samples: [Float]) -> String {
        hash([samples])
    }

    static func stereo(left: [Float], right: [Float]) -> String {
        hash([left, right])
    }

    private static func hash(_ channels: [[Float]]) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        func mix(_ value: UInt32) {
            var bits = value
            for _ in 0..<4 {
                hash ^= UInt64(bits & 0xff)
                hash &*= 0x100000001b3
                bits >>= 8
            }
        }
        mix(UInt32(truncatingIfNeeded: channels.count))
        for (index, channel) in channels.enumerated() {
            mix(0x9e37_79b9 ^ UInt32(truncatingIfNeeded: index))
            mix(UInt32(truncatingIfNeeded: channel.count))
            for sample in channel { mix(sample.bitPattern) }
        }
        return fixedWidthFingerprintHex(hash)
    }
}

enum RenderLayer {
    case full
    case protectedRhythm
}

struct RenderBuffers {
    var output: [Float] = []
    var kick: [Float] = []
    var kickDetector: [Float] = []
    var foundationStem: [Float] = []
    var percussionStem: [Float] = []
    var upperTonalStem: [Float] = []
    var atmosphereStem: [Float] = []
    var resonantAnchorStem: [Float] = []
    var detunedCompanionStem: [Float] = []
    var resonantMonoInstrumentStem: [Float] = []
    var tonalMotionInstrumentStem: [Float] = []
    var spectralTextureInstrumentStem: [Float] = []
    var maskingFoundation: [Float] = []
    var synth: [Float] = []
    var pulseEchoSend: [Float] = []
    var spatialReverbSend: [Float] = []

    mutating func reset(frameCount: Int, includeUpperRoleTaps: Bool) {
        reset(&output, frameCount: frameCount)
        reset(&kick, frameCount: frameCount)
        reset(&kickDetector, frameCount: frameCount)
        reset(&foundationStem, frameCount: frameCount)
        reset(&percussionStem, frameCount: frameCount)
        reset(&upperTonalStem, frameCount: frameCount)
        reset(&atmosphereStem, frameCount: frameCount)
        if includeUpperRoleTaps {
            reset(&resonantAnchorStem, frameCount: frameCount)
            reset(&detunedCompanionStem, frameCount: frameCount)
        } else {
            resonantAnchorStem.removeAll(keepingCapacity: false)
            detunedCompanionStem.removeAll(keepingCapacity: false)
        }
        reset(&resonantMonoInstrumentStem, frameCount: frameCount)
        reset(&tonalMotionInstrumentStem, frameCount: frameCount)
        reset(&spectralTextureInstrumentStem, frameCount: frameCount)
        reset(&maskingFoundation, frameCount: frameCount)
        reset(&synth, frameCount: frameCount)
        reset(&pulseEchoSend, frameCount: frameCount)
        reset(&spatialReverbSend, frameCount: frameCount)
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

    mutating func checkout(frameCount: Int, includeUpperRoleTaps: Bool) -> RenderBuffers {
        var checkedOut = RenderBuffers()
        swap(&checkedOut, &buffers)
        checkedOut.reset(
            frameCount: frameCount,
            includeUpperRoleTaps: includeUpperRoleTaps
        )
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
                              graphState: inout GeneratedDSPContinuationState,
                              forceHomeUpperTimbre: Bool = false) -> [RenderBlock] {
        guard let blocks = renderIfNotCancelled(
            plan: plan,
            graph: graph,
            sampleRate: sampleRate,
            state: &state,
            graphState: &graphState,
            forceHomeUpperTimbre: forceHomeUpperTimbre,
            cancellationRequested: { false }
        ) else {
            preconditionFailure("Non-cancellable phrase render stopped unexpectedly")
        }
        return blocks
    }

    /// Detached-preparation entry point. A cancelled partial render never
    /// escapes to scheduling; its caller owns disposable state copies.
    package static func renderIfNotCancelled(
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        sampleRate: Double,
        state: inout RenderState,
        graphState: inout GeneratedDSPContinuationState,
        forceHomeUpperTimbre: Bool = false,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> [RenderBlock]? {
        guard !cancellationRequested() else { return nil }
        let synthPlan = SynthPerformancePlan(
            scene: plan.scene, dna: plan.dna, kind: plan.kind,
            resolvedBars: plan.resolvedBars,
            conservative: plan.conservative,
            forceHomeUpperTimbre: forceHomeUpperTimbre
        )
        var workspace = RenderWorkspace()
        var blocks: [RenderBlock] = []
        blocks.reserveCapacity(plan.barCount)
        for index in plan.resolvedBars.indices {
            guard !cancellationRequested() else { return nil }
            let resolved = plan.resolvedBars[index]
            let performance = resolved.performance
            let synthPerformance = synthPlan.bars[index]
            let modulation = modulation(
                performance: performance,
                scene: plan.scene,
                synthPerformance: synthPerformance
            )
            var protectedRhythmState = state
            let protectedRhythm = VoiceRenderer.renderBar(
                scene: plan.scene,
                sampleRate: sampleRate,
                state: &protectedRhythmState,
                dna: plan.dna,
                resolved: resolved,
                synthWorld: synthPlan.world,
                synthPerformance: synthPerformance,
                workspace: &workspace,
                layer: .protectedRhythm
            )
            guard !cancellationRequested() else { return nil }
            let rendered = VoiceRenderer.renderBar(
                scene: plan.scene,
                sampleRate: sampleRate,
                state: &state,
                dna: plan.dna,
                resolved: resolved,
                synthWorld: synthPlan.world,
                synthPerformance: synthPerformance,
                workspace: &workspace,
                layer: .full
            )
            guard !cancellationRequested() else { return nil }
            let events = resolved.ensemble.events.map { event in
                let pulse = event.voice == .groovePulse
                    ? resolved.groovePulse(at: event.step) : nil
                let spatial = resolved.spatialContrast
                let isSpatialCarrier = spatial.depthPosition == .distant &&
                    spatial.carrierVoice == event.voice && spatial.carrierStep == event.step
                let isDominantMotif = event.voice == .motif
                let isRelationalUpperVoice = isDominantMotif || event.voice == .response
                let narrative = resolved.narrative
                let relational = synthPerformance.articulation(at: event.step)
                return VoiceEvent(
                    voice: voiceKind(event.voice),
                    bar: performance.bar,
                    step: pulse?.step ?? event.step,
                    intensity: pulse?.intensity ?? event.intensity,
                    pulseClass: pulse?.pulseClass,
                    timingOffsetInSteps: pulse?.timingOffsetInSteps ??
                        VoiceRenderer.timingOffsetInSteps(
                            for: event.voice, step: event.step, dna: plan.dna
                        ),
                    spatialDepthPosition: isSpatialCarrier ? .distant : .foreground,
                    spatialReverbSend: isSpatialCarrier ? spatial.reverbSend : 0,
                    narrativeDirection: isDominantMotif ? narrative.direction : nil,
                    narrativePresence: isDominantMotif
                        ? narrative.presence(atStep: event.step) : nil,
                    narrativeGainScale: isDominantMotif
                        ? narrative.motifGainScale(atStep: event.step) : nil,
                    narrativeSpectralScale: isDominantMotif
                        ? narrative.motifSpectralScale(atStep: event.step) : nil,
                    spectralAperture: isRelationalUpperVoice
                        ? relational.spectralAperture : nil,
                    anchorSpectralScale: isRelationalUpperVoice
                        ? relational.anchorSpectralScale : nil,
                    complementarySpectralScale: isRelationalUpperVoice
                        ? relational.complementarySpectralScale : nil,
                    bandPassBlend: isRelationalUpperVoice
                        ? relational.bandPassBlend : nil,
                    motifSpectralMultiplier: isDominantMotif
                        ? MotifSpectralSculpture.combinedMultiplier(
                            narrativeScale: narrative.motifSpectralScale(atStep: event.step),
                            anchorScale: relational.anchorSpectralScale
                        ) : nil
                )
            }
            let buses = busStates(rendered: rendered, scene: plan.scene, events: events)
            let graphInputLeft = zip(
                rendered.leftSamples,
                protectedRhythm.leftSamples
            ).map {
                $0.0 - $0.1
            }
            let graphInputRight = zip(
                rendered.rightSamples,
                protectedRhythm.rightSamples
            ).map {
                $0.0 - $0.1
            }
            let generated = GeneratedDSPGraphRenderer.process(
                left: graphInputLeft, right: graphInputRight,
                sampleRate: sampleRate, plan: graph, state: &graphState
            )
            guard !cancellationRequested() else { return nil }
            let stepFrames = Double(
                max(1, min(graphInputLeft.count, graphInputRight.count))
            ) / 16
            let notes = synthPerformance.upperNotes
            let anchorNotes = notes.filter { $0.role == .anchor }
            let anchorRetriggerEvidence = rendered.upperNoteRenderEvidence.filter {
                $0.role == .anchor && $0.didRetrigger
            }
            let anchorRetriggers = anchorNotes.compactMap { note -> (
                note: ResolvedUpperNote, onsetFrame: Int
            )? in
                let requestedOnsetFrame = Int(
                    (Double(note.onsetStep) * stepFrames).rounded()
                )
                guard let applied = anchorRetriggerEvidence.first(where: {
                    $0.onsetFrame == requestedOnsetFrame
                }) else { return nil }
                return (note, applied.onsetFrame)
            }
            let anchorAccents = anchorRetriggers.map {
                performance.accent(at: $0.note.onsetStep)
            }
            let minimumAccent = anchorAccents.min() ?? 0
            let maximumAccent = anchorAccents.max() ?? 0
            let accentMidpoint = (minimumAccent + maximumAccent) * 0.5
            let accentedOnsets = anchorRetriggers.filter {
                maximumAccent > minimumAccent &&
                    performance.accent(at: $0.note.onsetStep) > accentMidpoint
            }.map {
                $0.onsetFrame
            }
            let unaccentedOnsets = anchorRetriggers.filter {
                maximumAccent == minimumAccent ||
                    performance.accent(at: $0.note.onsetStep) <= accentMidpoint
            }.map {
                $0.onsetFrame
            }
            let slideWindows = rendered.upperNoteRenderEvidence.filter {
                $0.role == .anchor && $0.appliedGate == .slide
            }.map {
                UpperTimbreSlideWindow(
                    startFrame: $0.onsetFrame,
                    endFrame: $0.appliedGateEndFrame
                )
            }
            let velocityExpressionWindows = rendered.upperNoteRenderEvidence.filter {
                $0.role == .anchor && $0.didRetrigger
            }.map {
                UpperVelocityExpressionWindow(
                    onsetFrame: $0.onsetFrame,
                    endFrame: $0.appliedGateEndFrame,
                    velocity: $0.appliedVelocity,
                    appliedStartFrequency: $0.appliedStartFrequency,
                    spectralEnvelopeScale: $0.velocitySpectralEnvelopeScale,
                    decayScale: $0.velocityDecayScale
                )
            }
            let resonantEvidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                    left: rendered.resonantAnchorSamples,
                    right: rendered.resonantAnchorSamples,
                    sampleRate: sampleRate,
                    accentedOnsetFrames: accentedOnsets,
                    unaccentedOnsetFrames: unaccentedOnsets,
                    slideWindows: slideWindows,
                    detectedAttackFrames: detectedAttackFrames(
                        left: rendered.resonantAnchorSamples,
                        right: rendered.resonantAnchorSamples,
                        sampleRate: sampleRate
                    ),
                    velocityExpressionWindows: velocityExpressionWindows,
                    precedingFrame: state.previousResonantAnchorEvidenceFrame
                ))
            guard !cancellationRequested() else { return nil }
            let detunedEvidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                left: rendered.detunedCompanionSamples,
                right: rendered.detunedCompanionSamples,
                sampleRate: sampleRate,
                    precedingFrame: state.previousDetunedCompanionEvidenceFrame
            ))
            guard !cancellationRequested() else { return nil }
            let preGraphMixEvidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                left: graphInputLeft,
                right: graphInputRight,
                sampleRate: sampleRate,
                protectedReferenceMono: protectedRhythm.samples,
                    precedingFrame: state.previousGraphInputRemainderEvidenceFrame
            ))
            guard !cancellationRequested() else { return nil }
            let postGraphMixEvidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                left: generated.0,
                right: generated.1,
                sampleRate: sampleRate,
                protectedReferenceMono: protectedRhythm.samples,
                    precedingFrame: state.previousPostGraphRemainderEvidenceFrame
            ))
            guard !cancellationRequested() else { return nil }
            let graphInputRemainderTimbreEvidence = UpperTimbreEvidence.attributing(
                resonantAnchor: resonantEvidence,
                detunedCompanions: detunedEvidence,
                mix: preGraphMixEvidence
            )
            let postGraphRemainderTimbreEvidence = UpperTimbreEvidence.attributing(
                resonantAnchor: resonantEvidence,
                detunedCompanions: detunedEvidence,
                mix: postGraphMixEvidence
            )
            if let sample = rendered.resonantAnchorSamples.last {
                state.previousResonantAnchorEvidenceFrame = UpperTimbreStereoFrame(
                    left: sample, right: sample
                )
            }
            if let sample = rendered.detunedCompanionSamples.last {
                state.previousDetunedCompanionEvidenceFrame = UpperTimbreStereoFrame(
                    left: sample, right: sample
                )
            }
            if let left = graphInputLeft.last, let right = graphInputRight.last {
                state.previousGraphInputRemainderEvidenceFrame = UpperTimbreStereoFrame(
                    left: left, right: right
                )
            }
            if let left = generated.0.last, let right = generated.1.last {
                state.previousPostGraphRemainderEvidenceFrame = UpperTimbreStereoFrame(
                    left: left, right: right
                )
            }
            let outputLeft = zip(
                protectedRhythm.leftSamples,
                generated.0
            ).map { outputSafety($0 + $1) }
            let outputRight = zip(
                protectedRhythm.rightSamples,
                generated.1
            ).map { outputSafety($0 + $1) }
            let pulseEchoAmount = resolved.ensemble.events
                .filter { $0.voice == .motif || $0.voice == .response }
                .map { synthPerformance.articulation(at: $0.step).pulseEchoSend }
                .max() ?? 0
            let graphEffects = graph.nodes.map {
                EffectState(kind: effectKind($0.kind), amount: $0.amount, active: $0.mix > 0)
            } + (pulseEchoAmount > 0
                ? [EffectState(kind: .pulseEcho, amount: pulseEchoAmount)] : []) + [
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
                kickMix: rendered.kickMix,
                stemObservations: rendered.stemObservations,
                automaticMix: rendered.automaticMix,
                stemReconstruction: rendered.stemReconstruction,
                protectedFoundationSampleHash: protectedRhythm.dryFoundationSampleHash,
                percussionSampleHash: protectedRhythm.dryPercussionSampleHash,
                protectedRhythmSampleHash: ExactPCMFingerprint.stereo(
                    left: protectedRhythm.leftSamples,
                    right: protectedRhythm.rightSamples
                ),
                groovePulseRenderEvidence: rendered.groovePulseRenderEvidence,
                closedHatRenderEvidence: rendered.closedHatRenderEvidence,
                instrumentRenderEvidence: rendered.instrumentRenderEvidence,
                upperNoteRenderEvidence: rendered.upperNoteRenderEvidence,
                graphInputRemainderTimbreEvidence: graphInputRemainderTimbreEvidence,
                postGraphRemainderTimbreEvidence: postGraphRemainderTimbreEvidence,
                resolvedPerformance: resolved,
                sceneDNA: plan.dna,
                synthWorld: synthPlan.world,
                synthPerformance: synthPerformance
            ))
            state.barIndex = performance.bar + 1
        }
        return cancellationRequested() ? nil : blocks
    }

    private static func outputSafety(_ input: Float) -> Float {
        Float(tanh(Double(input) * 1.04) / tanh(1.04) * 0.90)
    }

    private static func modulation(performance: PerformanceBar, scene: TechnoScene,
                                   synthPerformance: SynthPerformanceBar) -> ModulationState {
        let progress = Double(performance.localBar) / Double(max(1, performance.phraseLength - 1))
        let phase = progress * 2 * Double.pi
        let activeTimbre = synthPerformance.upperNotes
            .map(\.timbreIntent)
            .filter { $0.kind != .home }
            .max { lhs, rhs in
                if lhs.amount == rhs.amount { return lhs.kind.rawValue > rhs.kind.rawValue }
                return lhs.amount < rhs.amount
            } ?? .home
        return ModulationState(
            phase: phase,
            brightness: min(1, (1 - scene.darkness) * 0.24 + performance.tension * 0.52),
            density: min(1, Double(performance.roles.count) / 4 * 0.62 + performance.tension * 0.20),
            space: min(1, scene.atmosphere * 0.68 + (performance.section == .breakdown ? 0.26 : 0)),
            upperTimbreIntent: activeTimbre,
            resolvedUpperNoteCount: synthPerformance.upperNotes.count,
            slideCount: synthPerformance.upperNotes.filter { $0.gate == .slide }.count
        )
    }

    /// Bounded PCM-derived attack detector for duplicate-onset evidence. It is
    /// intentionally simple and deterministic; calibrated policy may replace
    /// its thresholds only with a versioned analyzer revision.
    private static func detectedAttackFrames(left: [Float], right: [Float],
                                             sampleRate: Double) -> [Int] {
        let count = min(
            UpperTimbreEvidenceAnalyzer.maximumFrames,
            min(left.count, right.count)
        )
        guard count > 1, sampleRate.isFinite, sampleRate > 0 else { return [] }
        let coefficient = 1 - exp(-1 / max(1, sampleRate * 0.0035))
        let refractory = max(1, Int((sampleRate * 0.018).rounded()))
        let maximumAttacks = UpperTimbreEvidenceAnalyzer.maximumOnsets
        var envelope = 0.0
        var priorEnvelope = 0.0
        var lastAttack = -refractory
        var attacks: [Int] = []
        attacks.reserveCapacity(min(maximumAttacks, 32))
        for frame in 0..<count {
            let mono = abs((Double(left[frame]) + Double(right[frame])) * 0.5)
            envelope += (mono - envelope) * coefficient
            let rise = envelope - priorEnvelope
            if envelope > 0.0015, rise > 0.00012,
               frame - lastAttack >= refractory {
                attacks.append(frame)
                lastAttack = frame
                if attacks.count == maximumAttacks { break }
            }
            priorEnvelope = envelope
        }
        return attacks
    }

    private static func voiceKind(_ voice: EnsembleVoice) -> VoiceKind {
        switch voice {
        case .kick: .kick
        case .bass: .bass
        case .rumble: .rumble
        case .percussion: .percussion
        case .clap: .clap
        case .openHat: .openHat
        case .tunedTom: .tunedTom
        case .metallic: .metallic
        case .groovePulse: .groovePulse
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
            let role: MixRole
            switch voice {
            case .kick: role = .kick
            case .bass, .rumble, .tunedTom: role = .foundation
            case .percussion, .clap, .openHat, .metallic, .groovePulse:
                role = .percussion
            case .synth, .lead: role = .upperTonal
            case .pad, .riser: role = .atmosphere
            }
            return (voice, BusState(
                level: rendered.stemObservations[role]?.rms ?? 0,
                send: voice == .kick || voice == .bass || voice == .rumble || voice == .tunedTom
                    ? 0 : scene.atmosphere * 0.30,
                headroom: headroom
            ))
        })
    }
}
