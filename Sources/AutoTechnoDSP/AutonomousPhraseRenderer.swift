import AutoTechnoCore
import Foundation

package enum VoiceKind: String, CaseIterable, Sendable {
    case kick, bass, rumble, percussion, clap, openHat, tunedTom, metallic, groovePulse
    case synth, lead, pad, riser
}

package enum EffectKind: String, CaseIterable, Sendable {
    case busEQ, maskingGuard, saturation, phaser, chorus, comb, unsyncedEcho, pulseEcho
    case gatedPercussionEcho, reverb, spatialFDN, glue, master
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
/// audible values describe the post-fader kick contribution. The ducking
/// envelope peak remains an envelope metric and is not the detector peak.
package struct KickMixEvidence: Equatable, Sendable {
    package let renderedFrameCount: Int
    package let renderedKickEventCount: Int
    package let renderedKickStepMask: UInt16
    package let audibleGain: Double
    package let audiblePeak: Double
    package let audibleRMS: Double
    package let detectorPeak: Double
    package let detectorRMS: Double
    package let duckingEnvelopePeak: Double
    package let detectorSampleHash: String
    package let audibleSampleHash: String
    package let detectorNonzeroSampleCount: Int
    package let audibleNonzeroSampleCount: Int
    /// True only when every post-fader dry kick sample is the exact two-stage
    /// Float scaling of the detector sample used by sidechain ducking.
    package let detectorToAudibleScaleMatches: Bool
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
    package var spatialFDNState = FeedbackDelayNetworkState()
    package var modalPercussionState = ModalPercussionVoiceState()
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
    var polyphonicPadState = PolyphonicPadState()
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
    package let envelopeRelation: UpperEnvelopeRelation
    package let baseEnvelopeSustain: Double
    package let baseEnvelopeReleaseSeconds: Double
    package let appliedEnvelopeSustain: Double
    package let appliedEnvelopeReleaseSeconds: Double
    package let requestedVelocity: Double
    package let appliedVelocity: Double
    package let velocitySpectralEnvelopeScale: Double
    package let velocityDecayScale: Double
    package let instrument: InstrumentAssignment
    package let resonantMonoModulation:
        ResonantMonoModulationEventRenderEvidence?
    package let spectralTextureCluster:
        SpectralTextureClusterEventRenderEvidence?

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
        envelopeRelation: UpperEnvelopeRelation = .home,
        baseEnvelopeSustain: Double = 0,
        baseEnvelopeReleaseSeconds: Double = 0,
        appliedEnvelopeSustain: Double = 0,
        appliedEnvelopeReleaseSeconds: Double = 0,
        requestedVelocity: Double,
        appliedVelocity: Double,
        velocitySpectralEnvelopeScale: Double,
        velocityDecayScale: Double,
        instrument: InstrumentAssignment,
        resonantMonoModulation:
            ResonantMonoModulationEventRenderEvidence? = nil,
        spectralTextureCluster:
            SpectralTextureClusterEventRenderEvidence? = nil
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
        self.envelopeRelation = envelopeRelation
        self.baseEnvelopeSustain = baseEnvelopeSustain
        self.baseEnvelopeReleaseSeconds = baseEnvelopeReleaseSeconds
        self.appliedEnvelopeSustain = appliedEnvelopeSustain
        self.appliedEnvelopeReleaseSeconds = appliedEnvelopeReleaseSeconds
        self.requestedVelocity = requestedVelocity
        self.appliedVelocity = min(1, max(0, appliedVelocity))
        self.velocitySpectralEnvelopeScale = velocitySpectralEnvelopeScale
        self.velocityDecayScale = velocityDecayScale
        self.instrument = instrument
        self.resonantMonoModulation = resonantMonoModulation
        self.spectralTextureCluster = spectralTextureCluster
    }
}

/// Bounded same-pass scheduling tuple for one actually rendered upper note.
/// Core retains the score note; this record binds its semantic displacement to
/// the exact frame used by the canonical renderer.
package struct UpperTimingRenderEvent: Equatable, Sendable {
    package let role: SynthRole
    package let baseOnsetStep: Int
    package let requestedOffsetInSteps: Double
    package let expectedOnsetFrame: Int
    package let appliedOnsetFrame: Int
    package let requestedGateEndFrame: Int
    package let appliedGateEndFrame: Int

    package init(role: SynthRole, baseOnsetStep: Int,
                 requestedOffsetInSteps: Double,
                 expectedOnsetFrame: Int, appliedOnsetFrame: Int,
                 requestedGateEndFrame: Int, appliedGateEndFrame: Int) {
        self.role = role
        self.baseOnsetStep = baseOnsetStep
        self.requestedOffsetInSteps = requestedOffsetInSteps
        self.expectedOnsetFrame = expectedOnsetFrame
        self.appliedOnsetFrame = appliedOnsetFrame
        self.requestedGateEndFrame = requestedGateEndFrame
        self.appliedGateEndFrame = appliedGateEndFrame
    }
}

/// Reduced role-local consequence of an upper timing articulation. Raw tap PCM
/// remains inside detached rendering and only this exact fingerprint plus
/// bounded scalar evidence crosses into the immutable render block.
package struct UpperTimingRoleSignalEvidence: Equatable, Sendable {
    package let eventCount: Int
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let finite: Bool

    package static func analyze(eventCount: Int,
                                samples: [Float]) -> UpperTimingRoleSignalEvidence {
        var peak = 0.0
        var energy = 0.0
        var finite = true
        for sample in samples {
            let value = Double(sample)
            peak = max(peak, abs(value))
            energy += value * value
            finite = finite && sample.isFinite && peak.isFinite && energy.isFinite
        }
        let rms = sqrt(energy / Double(max(1, samples.count)))
        return UpperTimingRoleSignalEvidence(
            eventCount: max(0, eventCount),
            sampleHash: ExactPCMFingerprint.mono(samples),
            peak: peak,
            rms: rms,
            finite: finite && rms.isFinite
        )
    }
}

/// Transient per-bar render evidence for score-owned upper timing. Candidate
/// evaluation reduces the bounded event tuples into compact fingerprints; no
/// event collection or role PCM reaches scheduling beyond this RenderBlock.
package struct UpperTimingRenderEvidence: Equatable, Sendable {
    package static let maximumEventCount = 64

    package let bar: Int
    package let chapter: InterlockChapter
    package let relation: UpperTimingRelation
    package let performanceCharacter: PerformanceCharacter
    package let bpm: Double
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let events: [UpperTimingRenderEvent]
    package let anchorSignal: UpperTimingRoleSignalEvidence
    package let shadowSignal: UpperTimingRoleSignalEvidence
    package let responseSignal: UpperTimingRoleSignalEvidence

    package init(bar: Int, chapter: InterlockChapter,
                 relation: UpperTimingRelation,
                 performanceCharacter: PerformanceCharacter,
                 bpm: Double,
                 sampleRate: Double, renderedFrameCount: Int,
                 events: [UpperTimingRenderEvent],
                 anchorSignal: UpperTimingRoleSignalEvidence,
                 shadowSignal: UpperTimingRoleSignalEvidence,
                 responseSignal: UpperTimingRoleSignalEvidence) {
        self.bar = bar
        self.chapter = chapter
        self.relation = relation
        self.performanceCharacter = performanceCharacter
        self.bpm = bpm
        self.sampleRate = sampleRate
        self.renderedFrameCount = max(0, renderedFrameCount)
        self.events = Array(events.sorted { lhs, rhs in
            if lhs.baseOnsetStep != rhs.baseOnsetStep {
                return lhs.baseOnsetStep < rhs.baseOnsetStep
            }
            let lhsRole = SynthRole.allCases.firstIndex(of: lhs.role) ?? 0
            let rhsRole = SynthRole.allCases.firstIndex(of: rhs.role) ?? 0
            if lhsRole != rhsRole { return lhsRole < rhsRole }
            if lhs.requestedOffsetInSteps != rhs.requestedOffsetInSteps {
                return lhs.requestedOffsetInSteps < rhs.requestedOffsetInSteps
            }
            if lhs.expectedOnsetFrame != rhs.expectedOnsetFrame {
                return lhs.expectedOnsetFrame < rhs.expectedOnsetFrame
            }
            if lhs.appliedOnsetFrame != rhs.appliedOnsetFrame {
                return lhs.appliedOnsetFrame < rhs.appliedOnsetFrame
            }
            if lhs.requestedGateEndFrame != rhs.requestedGateEndFrame {
                return lhs.requestedGateEndFrame < rhs.requestedGateEndFrame
            }
            return lhs.appliedGateEndFrame < rhs.appliedGateEndFrame
        }.prefix(Self.maximumEventCount))
        self.anchorSignal = anchorSignal
        self.shadowSignal = shadowSignal
        self.responseSignal = responseSignal
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
package struct ResonantMonoModulationRenderEvidence: Equatable, Sendable {
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let orderedEventCount: Int
    package let metallicEventCount: Int
    package let orderedModulatorRatio: Double
    package let metallicModulatorRatio: Double
    package let maximumRequestedPeakIndex: Double
    package let minimumAppliedPeakIndex: Double
    package let maximumAppliedPeakIndex: Double
    package let eventFingerprint: String
    package let operatorSampleHash: String
    package let operatorPeak: Double
    package let operatorRMS: Double
    package let operatorCrestFactor: Double
    package let lowBandEnergyRatio: Double
    package let bindingValid: Bool
    package let finite: Bool
}

/// Reduced same-pass proof that the score-owned transition relation reached an
/// isolated dry cluster signal. No reconstructable samples survive detached
/// preparation.
package struct SpectralTextureClusterRenderEvidence: Equatable, Sendable {
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let relation: SpectralTextureClusterRelation
    package let adjacentRatio: Double
    package let maximumComponentRatio: Double
    package let minimumStartFrequency: Double
    package let maximumAppliedEndFrequency: Double
    package let eventFingerprint: String
    package let clusterSampleHash: String
    package let clusterPeak: Double
    package let clusterRMS: Double
    package let clusterCrestFactor: Double
    package let bindingValid: Bool
    package let finite: Bool
}

/// Reduced same-pass proof that one score-owned Tonal Motion note used the
/// sustained-wash envelope relation. Only scalar envelope facts and an
/// isolated signal fingerprint survive detached preparation.
package struct TonalEnvelopeExpansionRenderEvidence: Equatable, Sendable {
    package let eligible: Bool
    package let active: Bool
    package let eventCount: Int
    package let relation: UpperEnvelopeRelation
    package let baseSustain: Double
    package let baseReleaseSeconds: Double
    package let appliedSustain: Double
    package let appliedReleaseSeconds: Double
    package let eventFingerprint: String
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let attackRMS: Double
    package let tailRMS: Double
    package let tailToAttackDB: Double
    package let nonzeroSampleCount: Int
    package let bindingValid: Bool
    package let finite: Bool
}

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
    package let nonlinearCore:
        TPTAntialiasedNonlinearCoreRenderEvidence?
    package let resonantMonoModulation:
        ResonantMonoModulationRenderEvidence?
    package let spectralTextureCluster:
        SpectralTextureClusterRenderEvidence?
    package let tonalEnvelopeExpansion:
        TonalEnvelopeExpansionRenderEvidence?

    package init(
        architecture: InstrumentArchitecture,
        assignments: [InstrumentAssignment],
        patches: [InstrumentPatch],
        uses: [InstrumentUse],
        effects: [InstrumentEffect],
        eventCount: Int,
        sampleHash: String,
        peak: Float,
        rms: Float,
        finite: Bool,
        nonlinearCore:
            TPTAntialiasedNonlinearCoreRenderEvidence? = nil,
        resonantMonoModulation:
            ResonantMonoModulationRenderEvidence? = nil,
        spectralTextureCluster:
            SpectralTextureClusterRenderEvidence? = nil,
        tonalEnvelopeExpansion:
            TonalEnvelopeExpansionRenderEvidence? = nil
    ) {
        self.architecture = architecture
        self.assignments = assignments
        self.patches = patches
        self.uses = uses
        self.effects = effects
        self.eventCount = eventCount
        self.sampleHash = sampleHash
        self.peak = peak
        self.rms = rms
        self.finite = finite
        self.nonlinearCore = nonlinearCore
        self.resonantMonoModulation = resonantMonoModulation
        self.spectralTextureCluster = spectralTextureCluster
        self.tonalEnvelopeExpansion = tonalEnvelopeExpansion
    }
}

/// Same-pass evidence for the bounded score-owned percussion input gate,
/// delayed return, and later output gate. Only reduced geometry, hashes, and
/// scalar signal facts survive detached preparation; no captured slice does.
package struct PercussionEchoTextureRenderEvidence: Equatable, Sendable {
    package let active: Bool
    package let bpm: Double
    package let sampleRate: Double
    package let inputStep: Int
    package let outputStartStep: Int
    package let outputEndStep: Int
    package let renderedFrameCount: Int
    package let inputWindowFrameCount: Int
    package let outputWindowFrameCount: Int
    package let delayFrameCount: Int
    package let transitionFrameCount: Int
    package let inputSampleHash: String
    package let returnSampleHash: String
    package let inputPeak: Double
    package let inputRMS: Double
    package let returnPeak: Double
    package let returnRMS: Double
    package let inputNonzeroSampleCount: Int
    package let returnNonzeroSampleCount: Int
    package let outOfWindowNonzeroSampleCount: Int
    package let firstOutputSampleBitPattern: UInt32
    package let lastOutputSampleBitPattern: UInt32
    package let finite: Bool
}

/// Same-pass reduced evidence for the existing pulse-echo return before and
/// after the bounded texture drive. The delay line and its feedback remain
/// outside this processor. Its undriven tail remains canonical continuation;
/// no additional pre/post-drive diagnostic PCM survives detached preparation.
/// Boundary geometry and the exact post-peak input/amount witness make the
/// variable pointwise result replayable without retaining a PCM side channel.
package struct PulseEchoReturnDriveRenderEvidence: Equatable, Sendable {
    package let bar: Int
    package let bpm: Double
    package let delayFrameCount: Int
    package let machineTexture: Double
    package let scoreEnabled: Bool
    package let earliestPulseEchoOnsetStep: Int?
    package let driveEligible: Bool
    package let appliedAmount: Double
    package let transitionFrameCount: Int
    package let renderedFrameCount: Int
    package let currentSendRMS: Double
    package let preDriveSampleHash: String
    package let postDriveSampleHash: String
    package let firstPreDriveSampleBitPattern: UInt32
    package let firstPostDriveSampleBitPattern: UInt32
    package let lastPreDriveSampleBitPattern: UInt32
    package let lastPostDriveSampleBitPattern: UInt32
    package let changedFrameIndex: Int
    package let changedPreDriveSampleBitPattern: UInt32
    package let preDrivePeak: Double
    package let preDrivePeakFrameIndex: Int
    package let postDrivePeak: Double
    package let postDrivePeakFrameIndex: Int
    package let postDrivePeakPreDriveSample: Double
    package let postDrivePeakEffectiveAmount: Double
    package let preDriveRMS: Double
    package let postDriveRMS: Double
    package let preDriveLowBandRMS: Double
    package let postDriveLowBandRMS: Double
    package let differenceRMS: Double
    package let finite: Bool
}

/// Same-pass reduced evidence for the canonical eight-line late spatial tail.
/// It binds the score-owned selective send and scene-derived configuration to
/// exact FDN input/wet PCM without retaining another audio buffer.
package struct SpatialFDNRenderEvidence: Equatable, Sendable {
    package static let evidenceVersion = "spatial-fdn.render.v1"

    package let bar: Int
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let lineCount: Int
    package let delayFrameCounts: [Int]
    package let roomScale: Double
    package let decayTimeSeconds: Double
    package let dampingHz: Double
    package let maximumFeedbackGain: Double
    package let synthSendGain: Double
    package let percussionSendGain: Double
    package let wetGain: Double
    package let spatialDepthPosition: SpatialDepthPosition
    package let carrierVoice: EnsembleVoice?
    package let carrierStep: Int?
    package let scoreReverbSend: Double
    package let scoreHighPassHz: Double
    package let scoreLowPassHz: Double
    package let inputSampleHash: String
    package let wetLeftSampleHash: String
    package let wetRightSampleHash: String
    package let inputRMS: Double
    package let spatialSendRMS: Double
    package let wetPeak: Double
    package let wetRMS: Double
    package let wetStereoCorrelation: Double
    package let activeInputFrameCount: Int
    package let activeWetFrameCount: Int
    package let firstWetFrameIndex: Int
    package let finite: Bool

    package static let neutral = SpatialFDNRenderEvidence(
        bar: -1,
        sampleRate: 0,
        renderedFrameCount: 0,
        lineCount: 0,
        delayFrameCounts: [],
        roomScale: 0,
        decayTimeSeconds: 0,
        dampingHz: 0,
        maximumFeedbackGain: 0,
        synthSendGain: 0,
        percussionSendGain: 0,
        wetGain: 0,
        spatialDepthPosition: .foreground,
        carrierVoice: nil,
        carrierStep: nil,
        scoreReverbSend: 0,
        scoreHighPassHz: 0,
        scoreLowPassHz: 0,
        inputSampleHash: "",
        wetLeftSampleHash: "",
        wetRightSampleHash: "",
        inputRMS: 0,
        spatialSendRMS: 0,
        wetPeak: 0,
        wetRMS: 0,
        wetStereoCorrelation: 0,
        activeInputFrameCount: 0,
        activeWetFrameCount: 0,
        firstWetFrameIndex: -1,
        finite: false
    )
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
    package let dryModalPercussionSampleHash: String
    package let modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence
    package let modalPercussionFoundationRoutingValid: Bool
    package let groovePulseRenderEvidence: [GroovePulseRenderEvidence]
    package let closedHatRenderEvidence: [ClosedHatRenderEvidence]
    package let instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence]
    package let percussionEchoTextureRenderEvidence:
        PercussionEchoTextureRenderEvidence
    package let audioSliceRenderEvidence: AudioSliceRenderEvidence
    package let polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence
    package let pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence
    package let spatialFDNRenderEvidence: SpatialFDNRenderEvidence
    package let upperNoteRenderEvidence: [UpperNoteRenderEvidence]
    package let upperTimingRenderEvidence: UpperTimingRenderEvidence
    /// Transient detached-preparation taps. They never cross into RenderBlock
    /// or the scheduler; only reduced evidence survives phrase preparation.
    package let graphRemainderReferenceLeftSamples: [Float]
    package let graphRemainderReferenceRightSamples: [Float]
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
                dryModalPercussionSampleHash: String,
                modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence,
                modalPercussionFoundationRoutingValid: Bool,
                groovePulseRenderEvidence: [GroovePulseRenderEvidence],
                closedHatRenderEvidence: [ClosedHatRenderEvidence] = [],
                instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence] = [],
                percussionEchoTextureRenderEvidence:
                    PercussionEchoTextureRenderEvidence,
                audioSliceRenderEvidence: AudioSliceRenderEvidence = .neutral,
                polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence = .neutral,
                pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence,
                spatialFDNRenderEvidence: SpatialFDNRenderEvidence = .neutral,
                upperNoteRenderEvidence: [UpperNoteRenderEvidence],
                upperTimingRenderEvidence: UpperTimingRenderEvidence,
                graphRemainderReferenceLeftSamples: [Float],
                graphRemainderReferenceRightSamples: [Float],
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
        self.dryModalPercussionSampleHash = dryModalPercussionSampleHash
        self.modalPercussionRenderEvidence = modalPercussionRenderEvidence
        self.modalPercussionFoundationRoutingValid =
            modalPercussionFoundationRoutingValid
        self.groovePulseRenderEvidence = groovePulseRenderEvidence.sorted { $0.step < $1.step }
        self.closedHatRenderEvidence = closedHatRenderEvidence.sorted {
            $0.scoreEventIndex < $1.scoreEventIndex
        }
        self.instrumentRenderEvidence = instrumentRenderEvidence.sorted {
            (InstrumentArchitecture.allCases.firstIndex(of: $0.architecture) ?? 0) <
                (InstrumentArchitecture.allCases.firstIndex(of: $1.architecture) ?? 0)
        }
        self.percussionEchoTextureRenderEvidence =
            percussionEchoTextureRenderEvidence
        self.audioSliceRenderEvidence = audioSliceRenderEvidence
        self.polyphonicPadRenderEvidence = polyphonicPadRenderEvidence
        self.pulseEchoReturnDriveRenderEvidence = pulseEchoReturnDriveRenderEvidence
        self.spatialFDNRenderEvidence = spatialFDNRenderEvidence
        self.upperNoteRenderEvidence = upperNoteRenderEvidence
        self.upperTimingRenderEvidence = upperTimingRenderEvidence
        self.graphRemainderReferenceLeftSamples =
            graphRemainderReferenceLeftSamples
        self.graphRemainderReferenceRightSamples =
            graphRemainderReferenceRightSamples
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
    /// Evidence from the protected-rhythm pass that is actually scheduled.
    package let kickMix: KickMixEvidence
    /// Exact full-evidence equality proves the full and scheduled detached
    /// render passes observed the same kick invocation and resulting buses.
    package let kickRenderPassesMatch: Bool
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
    /// Same-pass modal-foundation evidence from the protected render that is
    /// actually scheduled with the accepted block.
    package let modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence
    package let modalPercussionRenderPassesMatch: Bool
    package let modalPercussionFoundationRoutingValid: Bool
    /// Same-pass, event-local evidence for every score-owned groove pulse.
    /// It is reduced into the bounded candidate transaction before scheduling.
    package let groovePulseRenderEvidence: [GroovePulseRenderEvidence]
    /// Same-pass reduced evidence for each ordinary closed-hat score event.
    package let closedHatRenderEvidence: [ClosedHatRenderEvidence]
    package let instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence]
    package let percussionEchoTextureRenderEvidence:
        PercussionEchoTextureRenderEvidence
    package let percussionEchoTextureRenderPassesMatch: Bool
    package let audioSliceRenderEvidence: AudioSliceRenderEvidence
    package let audioSliceRenderPassesMatch: Bool
    package let polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence
    package let pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence
    package let spatialFDNRenderEvidence: SpatialFDNRenderEvidence
    /// Exact score-owned upper notes used for this bar. The renderer no longer
    /// invents pitch, duration, velocity, or slide decisions after resolution.
    package var resolvedUpperNotes: [ResolvedUpperNote] {
        synthPerformance.upperNotes
    }
    package let upperNoteRenderEvidence: [UpperNoteRenderEvidence]
    package let upperTimingRenderEvidence: UpperTimingRenderEvidence
    /// The graph input is the full-render minus protected-rhythm remainder
    /// from exact references that exclude the identical modal-foundation
    /// contribution. It carries the newly scheduled upper path plus other
    /// shared continuation/nonlinear interaction; role-local articulation
    /// fields come only from the dedicated taps above.
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
                kickRenderPassesMatch: Bool,
                stemObservations: [MixRole: StemObservation],
                automaticMix: AutomaticMixPlan,
                stemReconstruction: StemReconstructionEvidence,
                protectedFoundationSampleHash: String,
                percussionSampleHash: String,
                protectedRhythmSampleHash: String,
                modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence,
                modalPercussionRenderPassesMatch: Bool,
                modalPercussionFoundationRoutingValid: Bool,
                groovePulseRenderEvidence: [GroovePulseRenderEvidence],
                closedHatRenderEvidence: [ClosedHatRenderEvidence] = [],
                instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence] = [],
                percussionEchoTextureRenderEvidence:
                    PercussionEchoTextureRenderEvidence,
                percussionEchoTextureRenderPassesMatch: Bool,
                audioSliceRenderEvidence: AudioSliceRenderEvidence = .neutral,
                audioSliceRenderPassesMatch: Bool = true,
                polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence = .neutral,
                pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence,
                spatialFDNRenderEvidence: SpatialFDNRenderEvidence = .neutral,
                upperNoteRenderEvidence: [UpperNoteRenderEvidence],
                upperTimingRenderEvidence: UpperTimingRenderEvidence,
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
        self.kickRenderPassesMatch = kickRenderPassesMatch
        self.stemObservations = stemObservations
        self.automaticMix = automaticMix
        self.stemReconstruction = stemReconstruction
        self.protectedFoundationSampleHash = protectedFoundationSampleHash
        self.percussionSampleHash = percussionSampleHash
        self.protectedRhythmSampleHash = protectedRhythmSampleHash
        self.modalPercussionRenderEvidence = modalPercussionRenderEvidence
        self.modalPercussionRenderPassesMatch = modalPercussionRenderPassesMatch
        self.modalPercussionFoundationRoutingValid =
            modalPercussionFoundationRoutingValid
        self.groovePulseRenderEvidence = groovePulseRenderEvidence.sorted { $0.step < $1.step }
        self.closedHatRenderEvidence = closedHatRenderEvidence.sorted {
            $0.scoreEventIndex < $1.scoreEventIndex
        }
        self.instrumentRenderEvidence = instrumentRenderEvidence.sorted {
            (InstrumentArchitecture.allCases.firstIndex(of: $0.architecture) ?? 0) <
                (InstrumentArchitecture.allCases.firstIndex(of: $1.architecture) ?? 0)
        }
        self.percussionEchoTextureRenderEvidence =
            percussionEchoTextureRenderEvidence
        self.percussionEchoTextureRenderPassesMatch =
            percussionEchoTextureRenderPassesMatch
        self.audioSliceRenderEvidence = audioSliceRenderEvidence
        self.audioSliceRenderPassesMatch = audioSliceRenderPassesMatch
        self.polyphonicPadRenderEvidence = polyphonicPadRenderEvidence
        self.pulseEchoReturnDriveRenderEvidence = pulseEchoReturnDriveRenderEvidence
        self.spatialFDNRenderEvidence = spatialFDNRenderEvidence
        self.upperNoteRenderEvidence = upperNoteRenderEvidence
        self.upperTimingRenderEvidence = upperTimingRenderEvidence
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
    var modalPercussionStem: [Float] = []
    var percussionStem: [Float] = []
    var percussionTextureStem: [Float] = []
    var upperTonalStem: [Float] = []
    var atmosphereStem: [Float] = []
    var resonantAnchorStem: [Float] = []
    var detunedCompanionStem: [Float] = []
    var shadowTimingStem: [Float] = []
    var responseTimingStem: [Float] = []
    var resonantMonoInstrumentStem: [Float] = []
    var resonantMonoModulationStem: [Float] = []
    var tonalMotionInstrumentStem: [Float] = []
    var tonalEnvelopeExpansionStem: [Float] = []
    var spectralTextureInstrumentStem: [Float] = []
    var spectralTextureClusterStem: [Float] = []
    var maskingFoundation: [Float] = []
    var synth: [Float] = []
    var pulseEchoSend: [Float] = []
    var spatialReverbSend: [Float] = []

    mutating func reset(frameCount: Int, includeUpperRoleTaps: Bool) {
        reset(&output, frameCount: frameCount)
        reset(&kick, frameCount: frameCount)
        reset(&kickDetector, frameCount: frameCount)
        reset(&foundationStem, frameCount: frameCount)
        reset(&modalPercussionStem, frameCount: frameCount)
        reset(&percussionStem, frameCount: frameCount)
        reset(&percussionTextureStem, frameCount: frameCount)
        reset(&upperTonalStem, frameCount: frameCount)
        reset(&atmosphereStem, frameCount: frameCount)
        if includeUpperRoleTaps {
            reset(&resonantAnchorStem, frameCount: frameCount)
            reset(&detunedCompanionStem, frameCount: frameCount)
            reset(&shadowTimingStem, frameCount: frameCount)
            reset(&responseTimingStem, frameCount: frameCount)
            reset(&resonantMonoModulationStem, frameCount: frameCount)
        } else {
            resonantAnchorStem.removeAll(keepingCapacity: false)
            detunedCompanionStem.removeAll(keepingCapacity: false)
            shadowTimingStem.removeAll(keepingCapacity: false)
            responseTimingStem.removeAll(keepingCapacity: false)
            resonantMonoModulationStem.removeAll(keepingCapacity: false)
        }
        reset(&resonantMonoInstrumentStem, frameCount: frameCount)
        reset(&tonalMotionInstrumentStem, frameCount: frameCount)
        if includeUpperRoleTaps {
            reset(&tonalEnvelopeExpansionStem, frameCount: frameCount)
        } else {
            tonalEnvelopeExpansionStem.removeAll(keepingCapacity: false)
        }
        reset(&spectralTextureInstrumentStem, frameCount: frameCount)
        if includeUpperRoleTaps {
            reset(&spectralTextureClusterStem, frameCount: frameCount)
        } else {
            spectralTextureClusterStem.removeAll(keepingCapacity: false)
        }
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
            forceHomeUpperTimbre: forceHomeUpperTimbre,
            compositionBars: plan.phraseComposition
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
                layer: .protectedRhythm,
                phraseKind: plan.kind
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
                layer: .full,
                phraseKind: plan.kind
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
                rendered.graphRemainderReferenceLeftSamples,
                protectedRhythm.graphRemainderReferenceLeftSamples
            ).map {
                $0.0 - $0.1
            }
            let graphInputRight = zip(
                rendered.graphRemainderReferenceRightSamples,
                protectedRhythm.graphRemainderReferenceRightSamples
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
                let requestedOnsetFrame = VoiceRenderer.upperNoteStartFrame(
                    note: note,
                    stepFrames: stepFrames,
                    frameCount: min(graphInputLeft.count, graphInputRight.count)
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
            let relationalPulseEchoAmount = resolved.ensemble.events
                .filter { $0.voice == .motif || $0.voice == .response }
                .map { synthPerformance.articulation(at: $0.step).pulseEchoSend }
                .max() ?? 0
            let pulseEchoReturnEvidence = rendered.pulseEchoReturnDriveRenderEvidence
            let pulseEchoAmount = max(
                relationalPulseEchoAmount,
                pulseEchoReturnEvidence.appliedAmount
            )
            let pulseEchoActive = pulseEchoReturnEvidence.currentSendRMS > 0 ||
                pulseEchoReturnEvidence.postDriveRMS > 0
            let spatialFDNEvidence = rendered.spatialFDNRenderEvidence
            let graphEffects = graph.nodes.map {
                EffectState(kind: effectKind($0.kind), amount: $0.amount, active: $0.mix > 0)
            } + [
                EffectState(
                    kind: .gatedPercussionEcho,
                    amount: PercussionEchoTextureVoice.returnGain,
                    active: protectedRhythm
                        .percussionEchoTextureRenderEvidence.active
                ),
                EffectState(
                    kind: .pulseEcho,
                    amount: pulseEchoAmount,
                    active: pulseEchoActive
                ),
                EffectState(
                    kind: .spatialFDN,
                    amount: spatialFDNEvidence.wetGain,
                    active: spatialFDNEvidence.activeWetFrameCount > 0
                ),
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
                kickMix: protectedRhythm.kickMix,
                kickRenderPassesMatch: protectedRhythm.kickMix == rendered.kickMix,
                stemObservations: rendered.stemObservations,
                automaticMix: rendered.automaticMix,
                stemReconstruction: rendered.stemReconstruction,
                protectedFoundationSampleHash: protectedRhythm.dryFoundationSampleHash,
                percussionSampleHash: protectedRhythm.dryPercussionSampleHash,
                protectedRhythmSampleHash: ExactPCMFingerprint.stereo(
                    left: protectedRhythm.leftSamples,
                    right: protectedRhythm.rightSamples
                ),
                modalPercussionRenderEvidence:
                    protectedRhythm.modalPercussionRenderEvidence,
                modalPercussionRenderPassesMatch:
                    protectedRhythm.modalPercussionRenderEvidence ==
                        rendered.modalPercussionRenderEvidence,
                modalPercussionFoundationRoutingValid:
                    protectedRhythm.modalPercussionFoundationRoutingValid &&
                        rendered.modalPercussionFoundationRoutingValid,
                groovePulseRenderEvidence: rendered.groovePulseRenderEvidence,
                closedHatRenderEvidence: rendered.closedHatRenderEvidence,
                instrumentRenderEvidence: rendered.instrumentRenderEvidence,
                percussionEchoTextureRenderEvidence:
                    protectedRhythm.percussionEchoTextureRenderEvidence,
                percussionEchoTextureRenderPassesMatch:
                    protectedRhythm.percussionEchoTextureRenderEvidence ==
                        rendered.percussionEchoTextureRenderEvidence,
                audioSliceRenderEvidence:
                    protectedRhythm.audioSliceRenderEvidence,
                audioSliceRenderPassesMatch:
                    protectedRhythm.audioSliceRenderEvidence ==
                        rendered.audioSliceRenderEvidence,
                polyphonicPadRenderEvidence:
                    rendered.polyphonicPadRenderEvidence,
                pulseEchoReturnDriveRenderEvidence:
                    rendered.pulseEchoReturnDriveRenderEvidence,
                spatialFDNRenderEvidence:
                    rendered.spatialFDNRenderEvidence,
                upperNoteRenderEvidence: rendered.upperNoteRenderEvidence,
                upperTimingRenderEvidence: rendered.upperTimingRenderEvidence,
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
