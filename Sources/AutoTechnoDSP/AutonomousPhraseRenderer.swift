import AutoTechnoCore
import Foundation

package enum VoiceKind: String, CaseIterable, Sendable {
    case kick, bass, rumble, percussion, clap, openHat, tunedTom, metallic, groovePulse
    case synth, lead, pad, riser
}

package enum EffectKind: String, CaseIterable, Sendable {
    case busEQ, maskingGuard, saturation, phaser, chorus, comb, unsyncedEcho, pulseEcho
    case percussionEchoTexture, reverb, spatialFDN, glue, master
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
    /// Same-pass evidence for the complete kick source before later detector,
    /// mix, ducking, and terminal processing.
    package let sourceDynamics: KickSourceDynamicsRenderEvidence
    /// True only when every post-fader dry kick sample is the exact two-stage
    /// Float scaling of the detector sample used by sidechain ducking.
    package let detectorToAudibleScaleMatches: Bool
}

package struct StemReconstructionEvidence: Equatable, Sendable {
    package let dryCenterMaximumError: Float
    package let upperMaximumError: Float
}

/// Same-pass proof for the sole terminal live-feedback action. The pre-trim
/// fingerprint names the already recombined, output-safety-processed stereo
/// signal. The post-trim fingerprint names the immutable PCM emitted by the
/// render block. No role-local signal or dynamics state participates here.
package struct LiveMasterTrimRenderEvidence: Equatable, Sendable {
    package let requestedTrimDB: Double
    package let appliedTrimDB: Double
    package let appliedGain: Double
    package let preTrimStereoSampleHash: String
    package let postTrimStereoSampleHash: String
    package let preTrimNonzeroSampleCount: Int
    package let postTrimNonzeroSampleCount: Int
    package let exactScaleMatches: Bool

    package init(
        requestedTrimDB: Double,
        appliedTrimDB: Double,
        appliedGain: Double,
        preTrimStereoSampleHash: String,
        postTrimStereoSampleHash: String,
        preTrimNonzeroSampleCount: Int,
        postTrimNonzeroSampleCount: Int,
        exactScaleMatches: Bool
    ) {
        self.requestedTrimDB = requestedTrimDB
        self.appliedTrimDB = appliedTrimDB
        self.appliedGain = appliedGain
        self.preTrimStereoSampleHash = preTrimStereoSampleHash
        self.postTrimStereoSampleHash = postTrimStereoSampleHash
        self.preTrimNonzeroSampleCount = preTrimNonzeroSampleCount
        self.postTrimNonzeroSampleCount = postTrimNonzeroSampleCount
        self.exactScaleMatches = exactScaleMatches
    }
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
    package var liveMasterHeadroomState = LiveMasterHeadroomContinuationState()
    package var spatialFDNState = FeedbackDelayNetworkState()
    package var spatialSendHighPassState = 0.0
    package var spatialSendLowPassState = 0.0
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
    package var outputTransitionState: OutputTransitionContinuationState?

    package init() {}

    package mutating func reset() {
        self = RenderState()
    }
}

/// Reduced terminal signal facts retained across the canonical phrase
/// boundary. It contains no reconstructable window: only the final stereo
/// frame and scalar terminal levels needed to evaluate the next detached
/// render against the material it actually follows.
package struct OutputTransitionContinuationState: Equatable, Sendable {
    package static let outputWindowSeconds = 0.10

    package let sampleRate: Double
    package let terminalLeft: Float
    package let terminalRight: Float
    package let terminalOutputRMS: Double
    package let terminalSpatialWetRMS: Double
    package let authoredTerminalSilence: Bool

    package init(
        sampleRate: Double,
        terminalLeft: Float,
        terminalRight: Float,
        terminalOutputRMS: Double,
        terminalSpatialWetRMS: Double,
        authoredTerminalSilence: Bool
    ) {
        self.sampleRate = sampleRate
        self.terminalLeft = terminalLeft
        self.terminalRight = terminalRight
        self.terminalOutputRMS = terminalOutputRMS
        self.terminalSpatialWetRMS = terminalSpatialWetRMS
        self.authoredTerminalSilence = authoredTerminalSilence
    }

    package var isFiniteAndBounded: Bool {
        sampleRate.isFinite && sampleRate > 0 && terminalLeft.isFinite &&
            abs(terminalLeft) <= 1 && terminalRight.isFinite &&
            abs(terminalRight) <= 1 && terminalOutputRMS.isFinite &&
            terminalOutputRMS >= 0 && terminalSpatialWetRMS.isFinite &&
            terminalSpatialWetRMS >= 0
    }
}

/// Cross-phrase seam and surviving-tail evidence. A route reset or initial
/// phrase is explicitly non-comparable; ordinary continuation must preserve
/// active FDN geometry and produce nonzero opening wet energy when an audible
/// inherited tail exists. The level delta is descriptive until calibrated.
package struct CrossPhraseTransitionEvidence: Codable, Equatable, Sendable {
    package static let evidenceVersion = "cross-phrase-transition.v1"

    package let predecessorAvailable: Bool
    package let routeComparable: Bool
    package let authoredTerminalSilence: Bool
    package let predecessorLeftBitPattern: UInt32
    package let predecessorRightBitPattern: UInt32
    package let successorLeftBitPattern: UInt32
    package let successorRightBitPattern: UInt32
    package let maximumBoundaryDelta: Double
    package let predecessorTerminalOutputRMS: Double
    package let successorOpeningOutputRMS: Double
    package let incomingSpatialStorageRMS: Double
    package let predecessorTerminalSpatialWetRMS: Double
    package let successorOpeningSpatialWetRMS: Double
    package let spatialTailLevelChangeDB: Double
    package let spatialGeometryRetained: Bool
    package let spatialTailContinuationRequired: Bool
    package let spatialTailContinuationObserved: Bool
    package let finite: Bool

    package static let initial = CrossPhraseTransitionEvidence(
        predecessorAvailable: false,
        routeComparable: false,
        authoredTerminalSilence: false,
        predecessorLeftBitPattern: 0,
        predecessorRightBitPattern: 0,
        successorLeftBitPattern: 0,
        successorRightBitPattern: 0,
        maximumBoundaryDelta: 0,
        predecessorTerminalOutputRMS: 0,
        successorOpeningOutputRMS: 0,
        incomingSpatialStorageRMS: 0,
        predecessorTerminalSpatialWetRMS: 0,
        successorOpeningSpatialWetRMS: 0,
        spatialTailLevelChangeDB: 0,
        spatialGeometryRetained: false,
        spatialTailContinuationRequired: false,
        spatialTailContinuationObserved: true,
        finite: true
    )

    package var hardGateValid: Bool {
        isComplete && spatialTailContinuationObserved &&
            (!routeComparable || maximumBoundaryDelta < 0.65)
    }

    package var isComplete: Bool {
        guard finite, maximumBoundaryDelta >= 0,
              predecessorTerminalOutputRMS >= 0,
              successorOpeningOutputRMS >= 0,
              incomingSpatialStorageRMS >= 0,
              predecessorTerminalSpatialWetRMS >= 0,
              successorOpeningSpatialWetRMS >= 0 else {
            return false
        }
        let predecessorLeft = Float(bitPattern: predecessorLeftBitPattern)
        let predecessorRight = Float(bitPattern: predecessorRightBitPattern)
        let successorLeft = Float(bitPattern: successorLeftBitPattern)
        let successorRight = Float(bitPattern: successorRightBitPattern)
        guard predecessorLeft.isFinite, predecessorRight.isFinite,
              successorLeft.isFinite, successorRight.isFinite else {
            return false
        }
        if !predecessorAvailable {
            return !routeComparable && !spatialTailContinuationRequired &&
                spatialTailContinuationObserved &&
                predecessorLeftBitPattern == 0 &&
                predecessorRightBitPattern == 0 &&
                successorLeftBitPattern == 0 &&
                successorRightBitPattern == 0 &&
                maximumBoundaryDelta == 0 &&
                predecessorTerminalOutputRMS == 0 &&
                successorOpeningOutputRMS == 0 &&
                incomingSpatialStorageRMS == 0 &&
                predecessorTerminalSpatialWetRMS == 0 &&
                successorOpeningSpatialWetRMS == 0 &&
                spatialTailLevelChangeDB == 0 &&
                !spatialGeometryRetained
        }
        if !routeComparable {
            return maximumBoundaryDelta == 0 &&
                !spatialTailContinuationRequired &&
                spatialTailContinuationObserved &&
                spatialTailLevelChangeDB == 0
        }
        let expectedBoundaryDelta = max(
            abs(Double(successorLeft - predecessorLeft)),
            abs(Double(successorRight - predecessorRight))
        )
        let expectedTailRequired = !authoredTerminalSilence &&
            incomingSpatialStorageRMS > 0 &&
            predecessorTerminalSpatialWetRMS > 0
        let expectedTailObserved = !expectedTailRequired || (
            spatialGeometryRetained && successorOpeningSpatialWetRMS > 0
        )
        guard maximumBoundaryDelta == expectedBoundaryDelta,
              spatialTailContinuationRequired == expectedTailRequired,
              spatialTailContinuationObserved == expectedTailObserved else {
            return false
        }
        if expectedTailRequired {
            let expectedLevelChangeDB = successorOpeningSpatialWetRMS > 0
                ? 20 * log10(
                    successorOpeningSpatialWetRMS /
                        predecessorTerminalSpatialWetRMS
                ) : 0
            return !authoredTerminalSilence &&
                incomingSpatialStorageRMS > 0 &&
                predecessorTerminalSpatialWetRMS > 0 &&
                spatialGeometryRetained &&
                successorOpeningSpatialWetRMS > 0 &&
                spatialTailContinuationObserved &&
                spatialTailLevelChangeDB == expectedLevelChangeDB
        }
        return spatialTailContinuationObserved &&
            spatialTailLevelChangeDB == 0
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
    package let requestedEndFrequency: Double
    package let appliedStartFrequency: Double
    package let targetEndFrequency: Double
    package var frequencyAtAppliedGateEnd: Double
    package let requestedGate: UpperNoteGate
    package let appliedGate: UpperNoteGate
    package let didRetrigger: Bool
    package let timbreIntent: UpperTimbreIntent
    package let envelopeRelation: UpperEnvelopeRelation
    package let spectralReveal: UpperSpectralRevealArticulation
    package var minimumAppliedCutoffHz: Double
    package var maximumAppliedCutoffHz: Double
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
    package let spectralTextureHarmonicTail:
        SpectralTextureHarmonicTailEventRenderEvidence?

    package init(
        role: SynthRole,
        onsetFrame: Int,
        requestedGateEndFrame: Int,
        appliedGateEndFrame: Int,
        requestedStartFrequency: Double,
        appliedStartFrequency: Double,
        targetEndFrequency: Double,
        frequencyAtAppliedGateEnd: Double,
        requestedEndFrequency: Double? = nil,
        requestedGate: UpperNoteGate,
        appliedGate: UpperNoteGate,
        didRetrigger: Bool,
        timbreIntent: UpperTimbreIntent,
        envelopeRelation: UpperEnvelopeRelation = .home,
        spectralReveal: UpperSpectralRevealArticulation = .home,
        minimumAppliedCutoffHz: Double = 0,
        maximumAppliedCutoffHz: Double = 0,
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
            SpectralTextureClusterEventRenderEvidence? = nil,
        spectralTextureHarmonicTail:
            SpectralTextureHarmonicTailEventRenderEvidence? = nil
    ) {
        self.role = role
        self.onsetFrame = max(0, onsetFrame)
        self.requestedGateEndFrame = max(self.onsetFrame, requestedGateEndFrame)
        self.appliedGateEndFrame = max(self.onsetFrame, appliedGateEndFrame)
        self.requestedStartFrequency = requestedStartFrequency
        self.requestedEndFrequency = requestedEndFrequency ?? targetEndFrequency
        self.appliedStartFrequency = appliedStartFrequency
        self.targetEndFrequency = targetEndFrequency
        self.frequencyAtAppliedGateEnd = frequencyAtAppliedGateEnd
        self.requestedGate = requestedGate
        self.appliedGate = appliedGate
        self.didRetrigger = didRetrigger
        self.timbreIntent = timbreIntent
        self.envelopeRelation = envelopeRelation
        self.spectralReveal = spectralReveal
        self.minimumAppliedCutoffHz = minimumAppliedCutoffHz
        self.maximumAppliedCutoffHz = maximumAppliedCutoffHz
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
        self.spectralTextureHarmonicTail = spectralTextureHarmonicTail
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

/// Reduced same-pass proof that the response-only harmonic-tail relation
/// reached isolated dry PCM. No source or reconstructable samples survive
/// detached preparation.
package struct SpectralTextureHarmonicTailRenderEvidence: Equatable, Sendable {
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let relation: SpectralTextureHarmonicTailRelation
    package let minimumFoldedSourceFrequency: Double
    package let maximumFoldedSourceFrequency: Double
    package let minimumBandCenterHz: Double
    package let maximumBandCenterHz: Double
    package let minimumResonance: Double
    package let maximumResonance: Double
    package let minimumPrefilterDrive: Double
    package let maximumPrefilterDrive: Double
    package let minimumLFORateHz: Double
    package let maximumLFORateHz: Double
    package let lowBandEnergyRatio: Double
    package let upperBandEnergyRatio: Double
    package let eventFingerprint: String
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let bindingValid: Bool
    package let finite: Bool
}

/// Reduced same-pass proof that an indefinite-pitch assignment ignored the
/// requested melodic frequency and produced an isolated, non-periodic dry
/// signal. No raw source survives detached preparation.
package struct IndefinitePitchRenderEvidence: Equatable, Sendable {
    package let evidenceVersion: String
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let noteFrequencyInfluenceDisabled: Bool
    package let eventFingerprint: String
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let maximumNormalizedPeriodicity: Double
    package let analyzedSampleCount: Int
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

/// Same-pass proof that an existing protagonist architecture used the
/// score-owned narrative reveal. The source remains the existing anchor tap;
/// no additional PCM buffer or effect return survives detached preparation.
package struct UpperSpectralRevealRenderEvidence: Equatable, Sendable {
    package let eligible: Bool
    package let active: Bool
    package let sourceScoreEventCount: Int
    package let renderedEventCount: Int
    package let activeEventCount: Int
    package let minimumActiveAperture: Double
    package let maximumActiveAperture: Double
    package let minimumAppliedCutoffHz: Double
    package let maximumAppliedCutoffHz: Double
    package let scoreFingerprint: String
    package let renderFingerprint: String
    package let anchorSampleHash: String
    package let anchorPeak: Double
    package let anchorRMS: Double
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
    package let spectralTextureHarmonicTail:
        SpectralTextureHarmonicTailRenderEvidence?
    package let indefinitePitch: IndefinitePitchRenderEvidence?
    package let tonalEnvelopeExpansion:
        TonalEnvelopeExpansionRenderEvidence?
    package let upperSpectralReveal:
        UpperSpectralRevealRenderEvidence?

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
        spectralTextureHarmonicTail:
            SpectralTextureHarmonicTailRenderEvidence? = nil,
        indefinitePitch: IndefinitePitchRenderEvidence? = nil,
        tonalEnvelopeExpansion:
            TonalEnvelopeExpansionRenderEvidence? = nil,
        upperSpectralReveal:
            UpperSpectralRevealRenderEvidence? = nil
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
        self.spectralTextureHarmonicTail = spectralTextureHarmonicTail
        self.indefinitePitch = indefinitePitch
        self.tonalEnvelopeExpansion = tonalEnvelopeExpansion
        self.upperSpectralReveal = upperSpectralReveal
    }
}

/// Same-pass evidence for the bounded score-owned percussion input window and
/// its gated-echo or anticipation-swell return. Only reduced geometry, hashes,
/// and scalar signal facts survive detached preparation; no captured slice does.
package struct PercussionEchoTextureRenderEvidence: Equatable, Sendable {
    package let active: Bool
    package let relation: PercussionEchoTextureRelation?
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
    package let earlyOutputRMS: Double
    package let lateOutputRMS: Double
    package let lateToEarlyDB: Double
    package let inputNonzeroSampleCount: Int
    package let returnNonzeroSampleCount: Int
    package let outOfWindowNonzeroSampleCount: Int
    package let firstOutputSampleBitPattern: UInt32
    package let lastOutputSampleBitPattern: UInt32
    package let finite: Bool
}

package struct SpatialDustChannelRenderEvidence: Codable, Equatable, Sendable {
    package let sourceSampleHash: String
    package let returnSampleHash: String
    package let delayFrameCount: Int
    package let feedback: Double
    package let gain: Double
    package let pan: Double
    package let highPassHz: Double
    package let lowPassHz: Double
    package let sourceRMS: Double
    package let returnRMS: Double
    package let lowBandRMS: Double
    package let nonzeroSampleCount: Int
}

/// Reduced proof for the stereo extension of the existing percussion echo.
/// Both delay lines are bar-local and therefore clear exactly at every bar and
/// material-world handoff; only hashes and bounded signal facts survive.
package struct SpatialDustRenderEvidence: Codable, Equatable, Sendable {
    package let active: Bool
    package let worldID: UInt64
    package let cadencePhase: Int
    package let gapPhase: Int
    package let dominantSide: SpatialDustDominantSide?
    package let sourceStep: Int
    package let renderedFrameCount: Int
    package let transitionFrameCount: Int
    package let left: SpatialDustChannelRenderEvidence
    package let right: SpatialDustChannelRenderEvidence
    package let stereoCorrelation: Double
    package let lowBandEnergyRatio: Double
    package let outOfWindowNonzeroSampleCount: Int
    package let firstLeftSampleBitPattern: UInt32
    package let firstRightSampleBitPattern: UInt32
    package let lastLeftSampleBitPattern: UInt32
    package let lastRightSampleBitPattern: UInt32
    package let terminalCleared: Bool
    package let finite: Bool

    package static func neutral(frameCount: Int = 0) -> Self {
        let hash = ExactPCMFingerprint.mono(
            [Float](repeating: 0, count: max(0, frameCount))
        )
        let channel = SpatialDustChannelRenderEvidence(
            sourceSampleHash: ExactPCMFingerprint.mono([]),
            returnSampleHash: hash,
            delayFrameCount: 0,
            feedback: 0,
            gain: 0,
            pan: 0,
            highPassHz: 0,
            lowPassHz: 0,
            sourceRMS: 0,
            returnRMS: 0,
            lowBandRMS: 0,
            nonzeroSampleCount: 0
        )
        return Self(
            active: false,
            worldID: 0,
            cadencePhase: -1,
            gapPhase: -1,
            dominantSide: nil,
            sourceStep: -1,
            renderedFrameCount: max(0, frameCount),
            transitionFrameCount: 0,
            left: channel,
            right: channel,
            stereoCorrelation: 0,
            lowBandEnergyRatio: 0,
            outOfWindowNonzeroSampleCount: 0,
            firstLeftSampleBitPattern: 0,
            firstRightSampleBitPattern: 0,
            lastLeftSampleBitPattern: 0,
            lastRightSampleBitPattern: 0,
            terminalCleared: true,
            finite: true
        )
    }
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
    package static let evidenceVersion = "spatial-fdn.render.v2"

    package let bar: Int
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let lineCount: Int
    package let delayFrameCounts: [Int]
    package let requestedRoomScale: Double
    package let roomScale: Double
    package let decayTimeSeconds: Double
    package let dampingHz: Double
    package let maximumFeedbackGain: Double
    package let synthSendGain: Double
    package let percussionSendGain: Double
    package let wetGain: Double
    package let geometryRetained: Bool
    package let parameterTransitionFrameCount: Int
    package let initialMaximumFeedbackGain: Double
    package let finalMaximumFeedbackGain: Double
    package let initialDampingCoefficient: Double
    package let finalDampingCoefficient: Double
    package let initialSynthSendGain: Double
    package let finalSynthSendGain: Double
    package let initialPercussionSendGain: Double
    package let finalPercussionSendGain: Double
    package let initialWetGain: Double
    package let finalWetGain: Double
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
    package let openingWindowFrameCount: Int
    package let openingWetRMS: Double
    package let terminalWindowFrameCount: Int
    package let terminalWetRMS: Double
    package let finite: Bool

    package static let neutral = SpatialFDNRenderEvidence(
        bar: -1,
        sampleRate: 0,
        renderedFrameCount: 0,
        lineCount: 0,
        delayFrameCounts: [],
        requestedRoomScale: 0,
        roomScale: 0,
        decayTimeSeconds: 0,
        dampingHz: 0,
        maximumFeedbackGain: 0,
        synthSendGain: 0,
        percussionSendGain: 0,
        wetGain: 0,
        geometryRetained: false,
        parameterTransitionFrameCount: 0,
        initialMaximumFeedbackGain: 0,
        finalMaximumFeedbackGain: 0,
        initialDampingCoefficient: 0,
        finalDampingCoefficient: 0,
        initialSynthSendGain: 0,
        finalSynthSendGain: 0,
        initialPercussionSendGain: 0,
        finalPercussionSendGain: 0,
        initialWetGain: 0,
        finalWetGain: 0,
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
        openingWindowFrameCount: 0,
        openingWetRMS: 0,
        terminalWindowFrameCount: 0,
        terminalWetRMS: 0,
        finite: false
    )
}

/// Same-pass evidence from the exact existing foundation render calls. The
/// transient start-frame list is reduced into a compact binding during
/// detached preparation and never reaches scheduling or the callback.
package struct FoundationPreKickPocketRenderEvidence: Equatable, Sendable {
    package let relation: FoundationPreKickPocketRelation?
    package let scoreEventIndex: Int
    package let bassStep: Int
    package let kickStep: Int
    package let eventStartFrame: Int
    package let naturalEndFrame: Int
    package let releaseStartFrame: Int
    package let releaseEndFrame: Int
    package let kickFrame: Int
    package let releaseFrameCount: Int
    package let silenceFrameCount: Int
    package let silenceSampleHash: String
    package let silencePeak: Double
    package let silenceRMS: Double
    package let applied: Bool
    package let finite: Bool

    package static let neutral = FoundationPreKickPocketRenderEvidence(
        relation: nil,
        scoreEventIndex: -1,
        bassStep: -1,
        kickStep: -1,
        eventStartFrame: -1,
        naturalEndFrame: -1,
        releaseStartFrame: -1,
        releaseEndFrame: -1,
        kickFrame: -1,
        releaseFrameCount: 0,
        silenceFrameCount: 0,
        silenceSampleHash: "",
        silencePeak: 0,
        silenceRMS: 0,
        applied: false,
        finite: true
    )
}

package struct FoundationRhythmRenderEvidence: Equatable, Sendable {
    package let bar: Int
    package let relation: FoundationRhythmicRelation
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let renderedBassEventCount: Int
    package let renderedBassStepMask: UInt16
    package let renderedStartFrames: [Int]
    package let dryFoundationSampleHash: String
    package let peak: Double
    package let rms: Double
    package let preKickPocket: FoundationPreKickPocketRenderEvidence
    package let finite: Bool

    package static let neutral = FoundationRhythmRenderEvidence(
        bar: -1,
        relation: .established,
        sampleRate: 0,
        renderedFrameCount: 0,
        renderedBassEventCount: 0,
        renderedBassStepMask: 0,
        renderedStartFrames: [],
        dryFoundationSampleHash: "",
        peak: 0,
        rms: 0,
        preKickPocket: .neutral,
        finite: false
    )
}

/// Opt-in PCM retained only by detached diagnostic preparation. These arrays
/// expose the exact same-pass role taps that already feed render evidence;
/// normal preparation leaves this value absent and continues recycling the
/// workspace into immutable scheduled blocks.
package struct VoiceRoleStemCapture: Equatable, Sendable {
    package let dryCenterReference: [Float]
    package let dryUpperReference: [Float]
    package let kick: [Float]
    package let foundation: [Float]
    package let modalFoundation: [Float]
    package let percussion: [Float]
    package let upperTonal: [Float]
    package let atmosphere: [Float]
    package let protectedFoundation: [Float]
    package let sourceLeft: [Float]
    package let sourceRight: [Float]

    package var frameCount: Int {
        dryCenterReference.count
    }

    package var frameCountsAreAligned: Bool {
        [
            dryUpperReference.count,
            kick.count,
            foundation.count,
            modalFoundation.count,
            percussion.count,
            upperTonal.count,
            atmosphere.count,
            protectedFoundation.count,
            sourceLeft.count,
            sourceRight.count,
        ].allSatisfy { $0 == frameCount }
    }

    package var samplesAreFinite: Bool {
        [
            dryCenterReference,
            dryUpperReference,
            kick,
            foundation,
            modalFoundation,
            percussion,
            upperTonal,
            atmosphere,
            protectedFoundation,
            sourceLeft,
            sourceRight,
        ].allSatisfy { $0.allSatisfy(\.isFinite) }
    }
}

/// One bar of exact, aligned, offline-only role evidence. Shared and nonlinear
/// stages remain explicit instead of being mislabelled as additive stems:
/// `outputSafetyResidual` captures the bounded outer safety curve and
/// `terminalProcessingResidual` captures climax/live-master processing.
package struct AutonomousBarRoleStemCapture: Equatable, Sendable {
    package let bar: Int
    package let sampleRate: Double
    package let full: VoiceRoleStemCapture
    package let protectedRhythm: VoiceRoleStemCapture
    package let graphInputLeft: [Float]
    package let graphInputRight: [Float]
    package let processedUpperLeft: [Float]
    package let processedUpperRight: [Float]
    package let preClimaxMixLeft: [Float]
    package let preClimaxMixRight: [Float]
    package let outputSafetyResidualLeft: [Float]
    package let outputSafetyResidualRight: [Float]
    package let terminalProcessingResidualLeft: [Float]
    package let terminalProcessingResidualRight: [Float]

    package var frameCount: Int {
        full.frameCount
    }

    package var frameCountsAreAligned: Bool {
        full.frameCountsAreAligned &&
            protectedRhythm.frameCountsAreAligned &&
            protectedRhythm.frameCount == frameCount &&
            [
                graphInputLeft.count,
                graphInputRight.count,
                processedUpperLeft.count,
                processedUpperRight.count,
                preClimaxMixLeft.count,
                preClimaxMixRight.count,
                outputSafetyResidualLeft.count,
                outputSafetyResidualRight.count,
                terminalProcessingResidualLeft.count,
                terminalProcessingResidualRight.count,
            ].allSatisfy { $0 == frameCount }
    }

    package var samplesAreFinite: Bool {
        full.samplesAreFinite && protectedRhythm.samplesAreFinite &&
            [
                graphInputLeft,
                graphInputRight,
                processedUpperLeft,
                processedUpperRight,
                preClimaxMixLeft,
                preClimaxMixRight,
                outputSafetyResidualLeft,
                outputSafetyResidualRight,
                terminalProcessingResidualLeft,
                terminalProcessingResidualRight,
            ].allSatisfy { $0.allSatisfy(\.isFinite) }
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
    package let masking: [RoleMaskingObservation]
    package let kickMix: KickMixEvidence
    package let stemObservations: [MixRole: StemObservation]
    package let automaticMix: AutomaticMixPlan
    package let stemReconstruction: StemReconstructionEvidence
    /// Reduced fingerprints of the exact post-fader dry taps used by role
    /// analysis. No stem PCM leaves detached preparation.
    package let dryFoundationSampleHash: String
    package let foundationRhythmRenderEvidence: FoundationRhythmRenderEvidence
    package let dryPercussionSampleHash: String
    package let dryModalPercussionSampleHash: String
    package let modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence
    package let modalPercussionFoundationRoutingValid: Bool
    package let groovePulseRenderEvidence: [GroovePulseRenderEvidence]
    package let closedHatRenderEvidence: [ClosedHatRenderEvidence]
    package let upperPercussionTailRenderEvidence:
        [UpperPercussionTailRenderEvidence]
    package let sourceTerminalDeclickRenderEvidence:
        [SourceTerminalDeclickRenderEvidence]
    package let instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence]
    package let percussionEchoTextureRenderEvidence:
        PercussionEchoTextureRenderEvidence
    package let spatialDustRenderEvidence: SpatialDustRenderEvidence
    package let audioSliceRenderEvidence: AudioSliceRenderEvidence
    package let polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence
    package let pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence
    package let spatialFDNRenderEvidence: SpatialFDNRenderEvidence
    package let upperNoteRenderEvidence: [UpperNoteRenderEvidence]
    package let upperTimingRenderEvidence: UpperTimingRenderEvidence
    /// Transient detached-preparation taps. They never cross into RenderBlock
    /// or the scheduler; only reduced evidence survives phrase preparation.
    package let audibleKickSamples: [Float]
    package let upperPercussionSamples: [Float]
    package let graphRemainderReferenceLeftSamples: [Float]
    package let graphRemainderReferenceRightSamples: [Float]
    package let effectCarrierSamples: [Float]
    package let resonantAnchorSamples: [Float]
    package let detunedCompanionSamples: [Float]
    /// Present only for an explicitly requested detached diagnostic render.
    /// It is never copied into `RenderBlock` or any scheduler-facing state.
    package let diagnosticRoleStemCapture: VoiceRoleStemCapture?

    package init(sampleRate: Double, samples: [Float], leftSamples: [Float],
                rightSamples: [Float], masking: [RoleMaskingObservation] = [],
                kickMix: KickMixEvidence,
                stemObservations: [MixRole: StemObservation],
                automaticMix: AutomaticMixPlan,
                stemReconstruction: StemReconstructionEvidence,
                dryFoundationSampleHash: String,
                foundationRhythmRenderEvidence: FoundationRhythmRenderEvidence,
                dryPercussionSampleHash: String,
                dryModalPercussionSampleHash: String,
                modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence,
                modalPercussionFoundationRoutingValid: Bool,
                groovePulseRenderEvidence: [GroovePulseRenderEvidence],
                closedHatRenderEvidence: [ClosedHatRenderEvidence] = [],
                upperPercussionTailRenderEvidence:
                    [UpperPercussionTailRenderEvidence] = [],
                sourceTerminalDeclickRenderEvidence:
                    [SourceTerminalDeclickRenderEvidence] = [],
                instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence] = [],
                percussionEchoTextureRenderEvidence:
                    PercussionEchoTextureRenderEvidence,
                spatialDustRenderEvidence: SpatialDustRenderEvidence = .neutral(),
                audioSliceRenderEvidence: AudioSliceRenderEvidence = .neutral,
                polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence = .neutral,
                pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence,
                spatialFDNRenderEvidence: SpatialFDNRenderEvidence = .neutral,
                upperNoteRenderEvidence: [UpperNoteRenderEvidence],
                upperTimingRenderEvidence: UpperTimingRenderEvidence,
                audibleKickSamples: [Float],
                upperPercussionSamples: [Float],
                graphRemainderReferenceLeftSamples: [Float],
                graphRemainderReferenceRightSamples: [Float],
                effectCarrierSamples: [Float] = [],
                resonantAnchorSamples: [Float],
                detunedCompanionSamples: [Float],
                diagnosticRoleStemCapture: VoiceRoleStemCapture? = nil) {
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
        self.foundationRhythmRenderEvidence = foundationRhythmRenderEvidence
        self.dryPercussionSampleHash = dryPercussionSampleHash
        self.dryModalPercussionSampleHash = dryModalPercussionSampleHash
        self.modalPercussionRenderEvidence = modalPercussionRenderEvidence
        self.modalPercussionFoundationRoutingValid =
            modalPercussionFoundationRoutingValid
        self.groovePulseRenderEvidence = groovePulseRenderEvidence.sorted { $0.step < $1.step }
        self.closedHatRenderEvidence = closedHatRenderEvidence.sorted {
            $0.scoreEventIndex < $1.scoreEventIndex
        }
        self.upperPercussionTailRenderEvidence =
            upperPercussionTailRenderEvidence.sorted {
                $0.scoreEventIndex < $1.scoreEventIndex
            }
        self.sourceTerminalDeclickRenderEvidence =
            sourceTerminalDeclickRenderEvidence.sorted {
                $0.scoreEventIndex < $1.scoreEventIndex
            }
        self.instrumentRenderEvidence = instrumentRenderEvidence.sorted {
            (InstrumentArchitecture.allCases.firstIndex(of: $0.architecture) ?? 0) <
                (InstrumentArchitecture.allCases.firstIndex(of: $1.architecture) ?? 0)
        }
        self.percussionEchoTextureRenderEvidence =
            percussionEchoTextureRenderEvidence
        self.spatialDustRenderEvidence = spatialDustRenderEvidence
        self.audioSliceRenderEvidence = audioSliceRenderEvidence
        self.polyphonicPadRenderEvidence = polyphonicPadRenderEvidence
        self.pulseEchoReturnDriveRenderEvidence = pulseEchoReturnDriveRenderEvidence
        self.spatialFDNRenderEvidence = spatialFDNRenderEvidence
        self.upperNoteRenderEvidence = upperNoteRenderEvidence
        self.upperTimingRenderEvidence = upperTimingRenderEvidence
        self.audibleKickSamples = audibleKickSamples
        self.upperPercussionSamples = upperPercussionSamples
        self.graphRemainderReferenceLeftSamples =
            graphRemainderReferenceLeftSamples
        self.graphRemainderReferenceRightSamples =
            graphRemainderReferenceRightSamples
        self.effectCarrierSamples = effectCarrierSamples
        self.resonantAnchorSamples = resonantAnchorSamples
        self.detunedCompanionSamples = detunedCompanionSamples
        self.diagnosticRoleStemCapture = diagnosticRoleStemCapture
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
    package let foundationRhythmRenderEvidence: FoundationRhythmRenderEvidence
    package let foundationRhythmRenderPassesMatch: Bool
    /// Bit-exact fingerprint of the dry percussion tap used for audible output,
    /// masking evidence, and the drum reverb send.
    package let percussionSampleHash: String
    /// Bit-exact fingerprint of the stereo protected-rhythm render recombined
    /// after the generated graph. It contains foundation and percussion while
    /// excluding newly scheduled upper voices.
    package let protectedRhythmSampleHash: String
    /// Same-pass modal-foundation evidence from the protected render that is
    /// actually scheduled with the accepted block.
    package let dryModalPercussionSampleHash: String
    package let modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence
    package let modalPercussionRenderPassesMatch: Bool
    package let modalPercussionFoundationRoutingValid: Bool
    /// Same-pass, event-local evidence for every score-owned groove pulse.
    /// It is reduced into the bounded candidate transaction before scheduling.
    package let groovePulseRenderEvidence: [GroovePulseRenderEvidence]
    /// Same-pass reduced evidence for each ordinary closed-hat score event.
    package let closedHatRenderEvidence: [ClosedHatRenderEvidence]
    /// Same-pass base-versus-applied evidence for existing clap, open-hat, and
    /// metallic score events. No event PCM survives detached preparation.
    package let upperPercussionTailRenderEvidence:
        [UpperPercussionTailRenderEvidence]
    package let upperPercussionTailRenderPassesMatch: Bool
    /// Event-local hard-window release evidence. Intentional attack samples
    /// remain exact; only source endings reach zero before the implicit silence.
    package let sourceTerminalDeclickRenderEvidence:
        [SourceTerminalDeclickRenderEvidence]
    package let sourceTerminalDeclickRenderPassesMatch: Bool
    package let instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence]
    package let percussionEchoTextureRenderEvidence:
        PercussionEchoTextureRenderEvidence
    package let percussionEchoTextureRenderPassesMatch: Bool
    package let spatialDustRenderEvidence: SpatialDustRenderEvidence
    package let spatialDustRenderPassesMatch: Bool
    package let audioSliceRenderEvidence: AudioSliceRenderEvidence
    package let audioSliceRenderPassesMatch: Bool
    package let polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence
    package let pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence
    package let spatialFDNRenderEvidence: SpatialFDNRenderEvidence
    package let effectCarrierRenderEvidence: EffectCarrierRenderEvidence?
    package let upperMusicalPumpRenderEvidence: UpperMusicalPumpRenderEvidence
    /// Score-owned terminal absence applied after the canonical graph and
    /// before the existing live-master scalar.
    package let climaxHangRenderEvidence: ClimaxHangRenderEvidence
    /// Terminal-only attenuation proof. All role and protected-routing evidence
    /// above is measured before this gain is applied.
    package let liveMasterTrimRenderEvidence: LiveMasterTrimRenderEvidence
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
                foundationRhythmRenderEvidence: FoundationRhythmRenderEvidence = .neutral,
                foundationRhythmRenderPassesMatch: Bool = true,
                percussionSampleHash: String,
                protectedRhythmSampleHash: String,
                dryModalPercussionSampleHash: String,
                modalPercussionRenderEvidence: ModalPercussionBarRenderEvidence,
                modalPercussionRenderPassesMatch: Bool,
                modalPercussionFoundationRoutingValid: Bool,
                groovePulseRenderEvidence: [GroovePulseRenderEvidence],
                closedHatRenderEvidence: [ClosedHatRenderEvidence] = [],
                upperPercussionTailRenderEvidence:
                    [UpperPercussionTailRenderEvidence] = [],
                upperPercussionTailRenderPassesMatch: Bool = true,
                sourceTerminalDeclickRenderEvidence:
                    [SourceTerminalDeclickRenderEvidence] = [],
                sourceTerminalDeclickRenderPassesMatch: Bool = true,
                instrumentRenderEvidence: [InstrumentArchitectureRenderEvidence] = [],
                percussionEchoTextureRenderEvidence:
                    PercussionEchoTextureRenderEvidence,
                percussionEchoTextureRenderPassesMatch: Bool,
                spatialDustRenderEvidence: SpatialDustRenderEvidence = .neutral(),
                spatialDustRenderPassesMatch: Bool = true,
                audioSliceRenderEvidence: AudioSliceRenderEvidence = .neutral,
                audioSliceRenderPassesMatch: Bool = true,
                polyphonicPadRenderEvidence: PolyphonicPadRenderEvidence = .neutral,
                pulseEchoReturnDriveRenderEvidence: PulseEchoReturnDriveRenderEvidence,
                spatialFDNRenderEvidence: SpatialFDNRenderEvidence = .neutral,
                effectCarrierRenderEvidence: EffectCarrierRenderEvidence? = nil,
                upperMusicalPumpRenderEvidence: UpperMusicalPumpRenderEvidence = .neutral,
                climaxHangRenderEvidence: ClimaxHangRenderEvidence = .neutral,
                liveMasterTrimRenderEvidence: LiveMasterTrimRenderEvidence,
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
        self.foundationRhythmRenderEvidence = foundationRhythmRenderEvidence
        self.foundationRhythmRenderPassesMatch =
            foundationRhythmRenderPassesMatch
        self.percussionSampleHash = percussionSampleHash
        self.protectedRhythmSampleHash = protectedRhythmSampleHash
        self.dryModalPercussionSampleHash = dryModalPercussionSampleHash
        self.modalPercussionRenderEvidence = modalPercussionRenderEvidence
        self.modalPercussionRenderPassesMatch = modalPercussionRenderPassesMatch
        self.modalPercussionFoundationRoutingValid =
            modalPercussionFoundationRoutingValid
        self.groovePulseRenderEvidence = groovePulseRenderEvidence.sorted { $0.step < $1.step }
        self.closedHatRenderEvidence = closedHatRenderEvidence.sorted {
            $0.scoreEventIndex < $1.scoreEventIndex
        }
        self.upperPercussionTailRenderEvidence =
            upperPercussionTailRenderEvidence.sorted {
                $0.scoreEventIndex < $1.scoreEventIndex
            }
        self.upperPercussionTailRenderPassesMatch =
            upperPercussionTailRenderPassesMatch
        self.sourceTerminalDeclickRenderEvidence =
            sourceTerminalDeclickRenderEvidence.sorted {
                $0.scoreEventIndex < $1.scoreEventIndex
            }
        self.sourceTerminalDeclickRenderPassesMatch =
            sourceTerminalDeclickRenderPassesMatch
        self.instrumentRenderEvidence = instrumentRenderEvidence.sorted {
            (InstrumentArchitecture.allCases.firstIndex(of: $0.architecture) ?? 0) <
                (InstrumentArchitecture.allCases.firstIndex(of: $1.architecture) ?? 0)
        }
        self.percussionEchoTextureRenderEvidence =
            percussionEchoTextureRenderEvidence
        self.percussionEchoTextureRenderPassesMatch =
            percussionEchoTextureRenderPassesMatch
        self.spatialDustRenderEvidence = spatialDustRenderEvidence
        self.spatialDustRenderPassesMatch = spatialDustRenderPassesMatch
        self.audioSliceRenderEvidence = audioSliceRenderEvidence
        self.audioSliceRenderPassesMatch = audioSliceRenderPassesMatch
        self.polyphonicPadRenderEvidence = polyphonicPadRenderEvidence
        self.pulseEchoReturnDriveRenderEvidence = pulseEchoReturnDriveRenderEvidence
        self.spatialFDNRenderEvidence = spatialFDNRenderEvidence
        self.effectCarrierRenderEvidence = effectCarrierRenderEvidence
        self.upperMusicalPumpRenderEvidence = upperMusicalPumpRenderEvidence
        self.climaxHangRenderEvidence = climaxHangRenderEvidence
        self.liveMasterTrimRenderEvidence = liveMasterTrimRenderEvidence
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

    /// Detached-only PCM projection used to run the existing signal-safety
    /// analyzers over a bounded fallback render. Arrays retain copy-on-write
    /// storage; no callback or scheduler constructs this value.
    package func replacingPCM(left: [Float], right: [Float]) -> Self {
        Self(
            bar: bar,
            section: section,
            left: left,
            right: right,
            events: events,
            modulation: modulation,
            busStates: busStates,
            masking: masking,
            effects: effects,
            kickMix: kickMix,
            kickRenderPassesMatch: kickRenderPassesMatch,
            stemObservations: stemObservations,
            automaticMix: automaticMix,
            stemReconstruction: stemReconstruction,
            protectedFoundationSampleHash: protectedFoundationSampleHash,
            foundationRhythmRenderEvidence: foundationRhythmRenderEvidence,
            foundationRhythmRenderPassesMatch:
                foundationRhythmRenderPassesMatch,
            percussionSampleHash: percussionSampleHash,
            protectedRhythmSampleHash: protectedRhythmSampleHash,
            dryModalPercussionSampleHash: dryModalPercussionSampleHash,
            modalPercussionRenderEvidence: modalPercussionRenderEvidence,
            modalPercussionRenderPassesMatch:
                modalPercussionRenderPassesMatch,
            modalPercussionFoundationRoutingValid:
                modalPercussionFoundationRoutingValid,
            groovePulseRenderEvidence: groovePulseRenderEvidence,
            closedHatRenderEvidence: closedHatRenderEvidence,
            upperPercussionTailRenderEvidence:
                upperPercussionTailRenderEvidence,
            upperPercussionTailRenderPassesMatch:
                upperPercussionTailRenderPassesMatch,
            sourceTerminalDeclickRenderEvidence:
                sourceTerminalDeclickRenderEvidence,
            sourceTerminalDeclickRenderPassesMatch:
                sourceTerminalDeclickRenderPassesMatch,
            instrumentRenderEvidence: instrumentRenderEvidence,
            percussionEchoTextureRenderEvidence:
                percussionEchoTextureRenderEvidence,
            percussionEchoTextureRenderPassesMatch:
                percussionEchoTextureRenderPassesMatch,
            audioSliceRenderEvidence: audioSliceRenderEvidence,
            audioSliceRenderPassesMatch: audioSliceRenderPassesMatch,
            polyphonicPadRenderEvidence: polyphonicPadRenderEvidence,
            pulseEchoReturnDriveRenderEvidence:
                pulseEchoReturnDriveRenderEvidence,
            spatialFDNRenderEvidence: spatialFDNRenderEvidence,
            effectCarrierRenderEvidence: effectCarrierRenderEvidence,
            upperMusicalPumpRenderEvidence: upperMusicalPumpRenderEvidence,
            climaxHangRenderEvidence: climaxHangRenderEvidence,
            liveMasterTrimRenderEvidence: liveMasterTrimRenderEvidence,
            upperNoteRenderEvidence: upperNoteRenderEvidence,
            upperTimingRenderEvidence: upperTimingRenderEvidence,
            graphInputRemainderTimbreEvidence:
                graphInputRemainderTimbreEvidence,
            postGraphRemainderTimbreEvidence:
                postGraphRemainderTimbreEvidence,
            resolvedPerformance: resolvedPerformance,
            sceneDNA: sceneDNA,
            synthWorld: synthWorld,
            synthPerformance: synthPerformance
        )
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

    /// Exact detached-evidence digest for a known stereo zero window. This is
    /// used only during bounded candidate validation, never on the callback.
    static func stereoZero(sampleCount: Int) -> String {
        let zeros = [Float](repeating: 0, count: max(0, sampleCount))
        return hash([zeros, zeros])
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
    var transitionStem: [Float] = []
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
    var spectralTextureHarmonicTailStem: [Float] = []
    var spectralTextureIndefinitePitchStem: [Float] = []
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
            reset(&transitionStem, frameCount: frameCount)
        } else {
            transitionStem.removeAll(keepingCapacity: false)
        }
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
            reset(&spectralTextureHarmonicTailStem, frameCount: frameCount)
            reset(&spectralTextureIndefinitePitchStem, frameCount: frameCount)
        } else {
            spectralTextureClusterStem.removeAll(keepingCapacity: false)
            spectralTextureHarmonicTailStem.removeAll(keepingCapacity: false)
            spectralTextureIndefinitePitchStem.removeAll(keepingCapacity: false)
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
        renderProductIfNotCancelled(
            plan: plan,
            graph: graph,
            sampleRate: sampleRate,
            state: &state,
            graphState: &graphState,
            forceHomeUpperTimbre: forceHomeUpperTimbre,
            cancellationRequested: cancellationRequested
        )?.blocks
    }

    package static func renderProductIfNotCancelled(
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        sampleRate: Double,
        state: inout RenderState,
        graphState: inout GeneratedDSPContinuationState,
        forceHomeUpperTimbre: Bool = false,
        diagnosticRoleStemCapture: Bool = false,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> AutonomousPhraseRenderProduct? {
        guard !cancellationRequested() else { return nil }
        let synthPlan = SynthPerformancePlan(
            scene: plan.scene, dna: plan.dna, kind: plan.kind,
            resolvedBars: plan.resolvedBars,
            materialWorld: plan.materialWorld,
            forceHomeUpperTimbre: forceHomeUpperTimbre,
            compositionBars: plan.phraseComposition
        )
        var workspace = RenderWorkspace()
        var blocks: [RenderBlock] = []
        blocks.reserveCapacity(plan.barCount)
        var diagnosticRoleStemCaptures: [AutonomousBarRoleStemCapture] = []
        if diagnosticRoleStemCapture {
            diagnosticRoleStemCaptures.reserveCapacity(plan.barCount)
        }
        let framesPerBar = max(1, Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded()))
        var holdEvolutionAccumulators =
            RepeatHoldEvolutionPatternFamily.allCases.map {
                RepeatHoldEvolutionRenderAccumulator(
                    patternFamily: $0,
                    sampleRate: sampleRate,
                    totalFrameCount: framesPerBar * plan.barCount,
                    barCapacity: plan.barCount
                )
            }
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
                phraseKind: plan.kind,
                diagnosticRoleStemCapture: diagnosticRoleStemCapture
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
                effectCarrierRole: plan.effectCarrier.active
                    ? plan.effectCarrier.state.role : nil,
                phraseKind: plan.kind,
                diagnosticRoleStemCapture: diagnosticRoleStemCapture
            )
            guard !cancellationRequested() else { return nil }
            let events = resolved.ensemble.events.map { event in
                let pulse = event.voice == .groovePulse
                    ? resolved.groovePulse(at: event.step) : nil
                let appliedStep = synthPerformance.relocatedUpperStep(
                    for: event.voice,
                    sourceStep: event.step
                )
                let spatial = resolved.spatialContrast
                let isSpatialCarrier = spatial.depthPosition == .distant &&
                    spatial.carrierVoice == event.voice && spatial.carrierStep == appliedStep
                let isDominantMotif = event.voice == .motif
                let isRelationalUpperVoice = isDominantMotif || event.voice == .response
                let narrative = resolved.narrative
                let relational = synthPerformance.articulation(at: event.step)
                return VoiceEvent(
                    voice: voiceKind(event.voice),
                    bar: performance.bar,
                    step: pulse?.step ?? appliedStep,
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
            let graphFrameCount = min(graphInputLeft.count, graphInputRight.count)
            let requestedCarrier = (0..<graphFrameCount).map { index in
                rendered.effectCarrierSamples.indices.contains(index)
                    ? rendered.effectCarrierSamples[index] : 0
            }
            var carrierLeft = [Float](repeating: 0, count: graphFrameCount)
            var carrierRight = [Float](repeating: 0, count: graphFrameCount)
            var residualLeft = [Float](repeating: 0, count: graphFrameCount)
            var residualRight = [Float](repeating: 0, count: graphFrameCount)
            var maximumCarrierReconstructionError = 0.0
            for index in 0..<graphFrameCount {
                let leftSplit = exactCarrierSplit(
                    input: graphInputLeft[index],
                    requestedCarrier: plan.effectCarrier.active
                        ? requestedCarrier[index] : 0
                )
                let rightSplit = exactCarrierSplit(
                    input: graphInputRight[index],
                    requestedCarrier: plan.effectCarrier.active
                        ? requestedCarrier[index] : 0
                )
                carrierLeft[index] = leftSplit.carrier
                carrierRight[index] = rightSplit.carrier
                residualLeft[index] = leftSplit.residual
                residualRight[index] = rightSplit.residual
                maximumCarrierReconstructionError = max(
                    maximumCarrierReconstructionError,
                    Double(abs(
                        graphInputLeft[index] -
                            (leftSplit.carrier + leftSplit.residual)
                    )),
                    Double(abs(
                        graphInputRight[index] -
                            (rightSplit.carrier + rightSplit.residual)
                    ))
                )
            }
            let graphDoseInputLeft: [Float]
            let graphDoseInputRight: [Float]
            if plan.effectCarrier.active {
                graphDoseInputLeft = (0..<graphFrameCount).map {
                    carrierLeft[$0] + residualLeft[$0] *
                        Float(LongHorizonEffectCarrierSchema.nonCarrierDose)
                }
                graphDoseInputRight = (0..<graphFrameCount).map {
                    carrierRight[$0] + residualRight[$0] *
                        Float(LongHorizonEffectCarrierSchema.nonCarrierDose)
                }
            } else {
                graphDoseInputLeft = graphInputLeft
                graphDoseInputRight = graphInputRight
            }
            let generated = GeneratedDSPGraphRenderer.process(
                left: graphDoseInputLeft, right: graphDoseInputRight,
                sampleRate: sampleRate, plan: graph, state: &graphState
            )
            let postCarrierLeft: [Float]
            let postCarrierRight: [Float]
            if plan.effectCarrier.active {
                postCarrierLeft = (0..<graphFrameCount).map {
                    generated.0[$0] + residualLeft[$0] * 0.65
                }
                postCarrierRight = (0..<graphFrameCount).map {
                    generated.1[$0] + residualRight[$0] * 0.65
                }
            } else {
                postCarrierLeft = generated.0
                postCarrierRight = generated.1
            }
            let pumpedUpper = UpperMusicalPumpProcessor.apply(
                left: postCarrierLeft,
                right: postCarrierRight,
                articulation: resolved.upperMusicalPump,
                sampleRate: sampleRate,
                bpm: plan.scene.bpm
            )
            let effectCarrierRenderEvidence = EffectCarrierRenderEvidence(
                bar: performance.bar,
                articulation: plan.effectCarrier,
                synthPerformance: synthPerformance,
                carrierLeft: carrierLeft,
                carrierRight: carrierRight,
                residualLeft: residualLeft,
                residualRight: residualRight,
                graphInputLeft: graphInputLeft,
                graphInputRight: graphInputRight,
                graphDoseInputLeft: graphDoseInputLeft,
                graphDoseInputRight: graphDoseInputRight,
                graphOutputLeft: generated.0,
                graphOutputRight: generated.1,
                finalUpperLeft: pumpedUpper.left,
                finalUpperRight: pumpedUpper.right,
                maximumReconstructionError: maximumCarrierReconstructionError,
                bindingComplete: graphFrameCount > 0 &&
                    graphInputLeft.count == graphInputRight.count &&
                    generated.0.count == graphFrameCount &&
                    generated.1.count == graphFrameCount
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
                    left: pumpedUpper.left,
                    right: pumpedUpper.right,
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
            if let left = pumpedUpper.left.last,
               let right = pumpedUpper.right.last {
                state.previousPostGraphRemainderEvidenceFrame = UpperTimbreStereoFrame(
                    left: left, right: right
                )
            }
            let preLiveFeedbackLeft = zip(
                protectedRhythm.leftSamples,
                pumpedUpper.left
            ).map { outputSafety($0 + $1) }
            let preLiveFeedbackRight = zip(
                protectedRhythm.rightSamples,
                pumpedUpper.right
            ).map { outputSafety($0 + $1) }
            let climaxOutput = ClimaxHangRenderer.render(
                left: preLiveFeedbackLeft,
                right: preLiveFeedbackRight,
                articulation: resolved.climaxHang,
                sampleRate: sampleRate
            )
            let terminalOutput = applyLiveMasterTrim(
                left: climaxOutput.left,
                right: climaxOutput.right,
                state: state.liveMasterHeadroomState
            )
            let outputLeft = terminalOutput.left
            let outputRight = terminalOutput.right
            if diagnosticRoleStemCapture {
                guard let fullCapture = rendered.diagnosticRoleStemCapture,
                      let protectedCapture =
                        protectedRhythm.diagnosticRoleStemCapture,
                      fullCapture.frameCountsAreAligned,
                      protectedCapture.frameCountsAreAligned,
                      fullCapture.frameCount == protectedCapture.frameCount,
                      fullCapture.frameCount == graphFrameCount,
                      outputLeft.count == graphFrameCount,
                      outputRight.count == graphFrameCount else {
                    return nil
                }
                var outputSafetyResidualLeft = [Float](
                    repeating: 0,
                    count: graphFrameCount
                )
                var outputSafetyResidualRight = [Float](
                    repeating: 0,
                    count: graphFrameCount
                )
                var terminalProcessingResidualLeft = [Float](
                    repeating: 0,
                    count: graphFrameCount
                )
                var terminalProcessingResidualRight = [Float](
                    repeating: 0,
                    count: graphFrameCount
                )
                for frame in 0..<graphFrameCount {
                    let leftLinear = protectedRhythm.leftSamples[frame] +
                        pumpedUpper.left[frame]
                    let rightLinear = protectedRhythm.rightSamples[frame] +
                        pumpedUpper.right[frame]
                    outputSafetyResidualLeft[frame] =
                        preLiveFeedbackLeft[frame] - leftLinear
                    outputSafetyResidualRight[frame] =
                        preLiveFeedbackRight[frame] - rightLinear
                    terminalProcessingResidualLeft[frame] =
                        outputLeft[frame] - preLiveFeedbackLeft[frame]
                    terminalProcessingResidualRight[frame] =
                        outputRight[frame] - preLiveFeedbackRight[frame]
                }
                diagnosticRoleStemCaptures.append(
                    AutonomousBarRoleStemCapture(
                        bar: performance.bar,
                        sampleRate: sampleRate,
                        full: fullCapture,
                        protectedRhythm: protectedCapture,
                        graphInputLeft: graphInputLeft,
                        graphInputRight: graphInputRight,
                        processedUpperLeft: pumpedUpper.left,
                        processedUpperRight: pumpedUpper.right,
                        preClimaxMixLeft: preLiveFeedbackLeft,
                        preClimaxMixRight: preLiveFeedbackRight,
                        outputSafetyResidualLeft: outputSafetyResidualLeft,
                        outputSafetyResidualRight: outputSafetyResidualRight,
                        terminalProcessingResidualLeft:
                            terminalProcessingResidualLeft,
                        terminalProcessingResidualRight:
                            terminalProcessingResidualRight
                    )
                )
            }
            let protectedRhythmSampleHash = ExactPCMFingerprint.stereo(
                left: protectedRhythm.leftSamples,
                right: protectedRhythm.rightSamples
            )
            for accumulatorIndex in holdEvolutionAccumulators.indices {
                guard holdEvolutionAccumulators[accumulatorIndex].available
                else { continue }
                if let transformedMix = holdEvolutionAccumulators[
                    accumulatorIndex
                ].process(
                    input: RepeatHoldEvolutionTransformInput(
                        wholeMixLeft: preLiveFeedbackLeft,
                        wholeMixRight: preLiveFeedbackRight,
                        protectedRhythmLeft: protectedRhythm.leftSamples,
                        protectedRhythmRight: protectedRhythm.rightSamples,
                        melodicRemainderLeft: pumpedUpper.left,
                        melodicRemainderRight: pumpedUpper.right,
                        kick: protectedRhythm.audibleKickSamples,
                        upperPercussion:
                            protectedRhythm.upperPercussionSamples
                    ),
                    cancellationRequested: cancellationRequested
                ) {
                    let holdClimaxOutput = ClimaxHangRenderer.render(
                        left: transformedMix.left,
                        right: transformedMix.right,
                        articulation: resolved.climaxHang,
                        sampleRate: sampleRate
                    )
                    let holdTerminalOutput = applyLiveMasterTrim(
                        left: holdClimaxOutput.left,
                        right: holdClimaxOutput.right,
                        state: state.liveMasterHeadroomState
                    )
                    holdEvolutionAccumulators[accumulatorIndex].blocks.append(
                        RepeatHoldEvolutionRenderBlock(
                            bar: performance.bar,
                            left: holdTerminalOutput.left,
                            right: holdTerminalOutput.right,
                            protectedRhythmSampleHash:
                                protectedRhythmSampleHash,
                            inputRouting: .fullMixPreClimax,
                            sourceMixHighBandEnergy:
                                transformedMix.sourceHighBandEnergy,
                            transformedMixHighBandEnergy:
                                transformedMix.transformedHighBandEnergy,
                            wholeMixEvidenceFrameCount:
                                transformedMix.evidenceFrameCount,
                            looperCapturedFrameCount:
                                transformedMix
                                    .looperCapturedFrameCount,
                            looperReplayedFrameCount:
                                transformedMix
                                    .looperReplayedFrameCount,
                            looperExpectedReplayedFrameCount:
                                transformedMix
                                    .looperExpectedReplayedFrameCount,
                            looperBoundaryFrameCount:
                                transformedMix
                                    .looperBoundaryFrameCount,
                            looperExpectedBoundaryFrameCount:
                                transformedMix
                                    .looperExpectedBoundaryFrameCount,
                            looperSourceReuseExact:
                                transformedMix.looperSourceReuseExact,
                            looperShortestReplayFrameCount:
                                transformedMix
                                    .looperShortestReplayFrameCount
                        )
                    )
                } else {
                    holdEvolutionAccumulators[accumulatorIndex].available = false
                    holdEvolutionAccumulators[accumulatorIndex].blocks
                        .removeAll(keepingCapacity: false)
                }
            }
            guard !cancellationRequested() else { return nil }
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
                    kind: .percussionEchoTexture,
                    amount: PercussionEchoTextureVoice.returnGain,
                    active: protectedRhythm
                        .percussionEchoTextureRenderEvidence.active ||
                        protectedRhythm.spatialDustRenderEvidence.active
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
                foundationRhythmRenderEvidence:
                    protectedRhythm.foundationRhythmRenderEvidence,
                foundationRhythmRenderPassesMatch:
                    protectedRhythm.foundationRhythmRenderEvidence ==
                        rendered.foundationRhythmRenderEvidence,
                percussionSampleHash: protectedRhythm.dryPercussionSampleHash,
                protectedRhythmSampleHash: protectedRhythmSampleHash,
                dryModalPercussionSampleHash:
                    protectedRhythm.dryModalPercussionSampleHash,
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
                upperPercussionTailRenderEvidence:
                    protectedRhythm.upperPercussionTailRenderEvidence,
                upperPercussionTailRenderPassesMatch:
                    protectedRhythm.upperPercussionTailRenderEvidence ==
                        rendered.upperPercussionTailRenderEvidence,
                sourceTerminalDeclickRenderEvidence:
                    protectedRhythm.sourceTerminalDeclickRenderEvidence,
                sourceTerminalDeclickRenderPassesMatch:
                    protectedRhythm.sourceTerminalDeclickRenderEvidence ==
                        rendered.sourceTerminalDeclickRenderEvidence,
                instrumentRenderEvidence: rendered.instrumentRenderEvidence,
                percussionEchoTextureRenderEvidence:
                    protectedRhythm.percussionEchoTextureRenderEvidence,
                percussionEchoTextureRenderPassesMatch:
                    protectedRhythm.percussionEchoTextureRenderEvidence ==
                        rendered.percussionEchoTextureRenderEvidence,
                spatialDustRenderEvidence:
                    protectedRhythm.spatialDustRenderEvidence,
                spatialDustRenderPassesMatch:
                    protectedRhythm.spatialDustRenderEvidence ==
                        rendered.spatialDustRenderEvidence,
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
                effectCarrierRenderEvidence: effectCarrierRenderEvidence,
                upperMusicalPumpRenderEvidence: pumpedUpper.evidence,
                climaxHangRenderEvidence: climaxOutput.evidence,
                liveMasterTrimRenderEvidence: terminalOutput.evidence,
                upperNoteRenderEvidence: rendered.upperNoteRenderEvidence,
                upperTimingRenderEvidence: rendered.upperTimingRenderEvidence,
                graphInputRemainderTimbreEvidence: graphInputRemainderTimbreEvidence,
                postGraphRemainderTimbreEvidence: postGraphRemainderTimbreEvidence,
                resolvedPerformance: resolved,
                sceneDNA: plan.dna,
                synthWorld: synthPlan.world,
                synthPerformance: synthPerformance
            ))
            if let terminalLeft = outputLeft.last,
               let terminalRight = outputRight.last {
                state.outputTransitionState = OutputTransitionContinuationState(
                    sampleRate: sampleRate,
                    terminalLeft: terminalLeft,
                    terminalRight: terminalRight,
                    terminalOutputRMS: terminalRMS(
                        left: outputLeft,
                        right: outputRight,
                        sampleRate: sampleRate
                    ),
                    terminalSpatialWetRMS:
                        rendered.spatialFDNRenderEvidence.terminalWetRMS,
                    authoredTerminalSilence: climaxOutput.evidence.active
                )
            }
            state.barIndex = performance.bar + 1
        }
        guard !cancellationRequested() else { return nil }
        return AutonomousPhraseRenderProduct(
            blocks: blocks,
            repeatHoldEvolutionCandidates: holdEvolutionAccumulators.compactMap {
                guard $0.available, $0.blocks.count == plan.barCount else {
                    return nil
                }
                return RepeatHoldEvolutionRenderCandidate(
                    patternFamily: $0.patternFamily,
                    blocks: $0.blocks
                )
            },
            diagnosticRoleStemCaptures: diagnosticRoleStemCaptures
        )
    }

    /// Produces an exact Float-domain partition. Extremely rare rounding
    /// failures fall back to an all-residual split rather than admitting an
    /// unreconstructable carrier tap.
    private static func exactCarrierSplit(
        input: Float,
        requestedCarrier: Float
    ) -> (carrier: Float, residual: Float) {
        guard input.isFinite, requestedCarrier.isFinite else {
            return (0, input.isFinite ? input : 0)
        }
        var carrier = requestedCarrier
        var residual = input - carrier
        if carrier + residual != input {
            carrier = input - residual
        }
        if carrier + residual != input {
            carrier = 0
            residual = input
        }
        return (carrier, residual)
    }

    private static func outputSafety(_ input: Float) -> Float {
        Float(tanh(Double(input) * 1.04) / tanh(1.04) * 0.90)
    }

    private static func terminalRMS(
        left: [Float],
        right: [Float],
        sampleRate: Double
    ) -> Double {
        let count = min(left.count, right.count)
        guard count > 0, sampleRate.isFinite, sampleRate > 0 else { return 0 }
        let window = min(
            count,
            max(1, Int((
                sampleRate * OutputTransitionContinuationState.outputWindowSeconds
            ).rounded()))
        )
        let start = count - window
        var energy = 0.0
        for index in start..<count {
            let leftValue = Double(left[index])
            let rightValue = Double(right[index])
            energy += leftValue * leftValue + rightValue * rightValue
        }
        return sqrt(energy / Double(window * 2))
    }

    private static func applyLiveMasterTrim(
        left: [Float],
        right: [Float],
        state: LiveMasterHeadroomContinuationState
    ) -> (
        left: [Float],
        right: [Float],
        evidence: LiveMasterTrimRenderEvidence
    ) {
        let requestedTrimDB = state.committedTrimDB
        let appliedTrimDB = min(0, max(-3, requestedTrimDB))
        let appliedGain = pow(10.0, appliedTrimDB / 20.0)
        let outputLeft: [Float]
        let outputRight: [Float]
        if appliedTrimDB == 0 {
            // Preserve the pre-feature sample bit patterns at the home state.
            outputLeft = left
            outputRight = right
        } else {
            outputLeft = left.map { Float(Double($0) * appliedGain) }
            outputRight = right.map { Float(Double($0) * appliedGain) }
        }

        let exactScaleMatches = exactTerminalScaleMatches(
            preTrim: left,
            postTrim: outputLeft,
            gain: appliedGain,
            neutral: appliedTrimDB == 0
        ) && exactTerminalScaleMatches(
            preTrim: right,
            postTrim: outputRight,
            gain: appliedGain,
            neutral: appliedTrimDB == 0
        )
        let preTrimNonzeroSampleCount =
            left.reduce(0) { $0 + ($1 == 0 ? 0 : 1) } +
            right.reduce(0) { $0 + ($1 == 0 ? 0 : 1) }
        let postTrimNonzeroSampleCount =
            outputLeft.reduce(0) { $0 + ($1 == 0 ? 0 : 1) } +
            outputRight.reduce(0) { $0 + ($1 == 0 ? 0 : 1) }
        return (
            outputLeft,
            outputRight,
            LiveMasterTrimRenderEvidence(
                requestedTrimDB: requestedTrimDB,
                appliedTrimDB: appliedTrimDB,
                appliedGain: appliedGain,
                preTrimStereoSampleHash: ExactPCMFingerprint.stereo(
                    left: left,
                    right: right
                ),
                postTrimStereoSampleHash: ExactPCMFingerprint.stereo(
                    left: outputLeft,
                    right: outputRight
                ),
                preTrimNonzeroSampleCount: preTrimNonzeroSampleCount,
                postTrimNonzeroSampleCount: postTrimNonzeroSampleCount,
                exactScaleMatches: exactScaleMatches
            )
        )
    }

    private static func exactTerminalScaleMatches(
        preTrim: [Float],
        postTrim: [Float],
        gain: Double,
        neutral: Bool
    ) -> Bool {
        guard preTrim.count == postTrim.count else { return false }
        return zip(preTrim, postTrim).allSatisfy { source, output in
            guard source.isFinite, output.isFinite else { return false }
            if neutral {
                return source.bitPattern == output.bitPattern
            }
            return Float(Double(source) * gain).bitPattern == output.bitPattern
        }
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
