import Foundation

/// Phrase-local reuse of app-owned, already-rendered percussion PCM. Source
/// geometry and trigger intent are resolved in Core; DSP owns interpolation,
/// boundary windows, and signal evidence during detached preparation.
package enum AudioSliceDirection: String, CaseIterable, Sendable {
    case forward
    case reverse
}

package enum AudioSliceSourceKind: String, CaseIterable, Sendable {
    case percussion
    case kick
}

/// The score-owned interpretation of one already-rendered source window.
/// `cut` preserves the established whole-window resampler. `granularMemory`
/// reuses that same window as overlapping deterministic micrograins; it is not
/// a second sampler, retained recording, or renderer-side musical choice.
package enum AudioSliceTexture: String, CaseIterable, Sendable {
    case cut
    case granularMemory = "granular-memory"
}

package struct AudioSliceTrigger: Equatable, Sendable {
    package let onsetStep: Int
    package let playbackRate: Double
    package let direction: AudioSliceDirection
    package let gain: Double

    package init(onsetStep: Int, playbackRate: Double,
                 direction: AudioSliceDirection, gain: Double) {
        self.onsetStep = min(15, max(0, onsetStep))
        self.playbackRate = min(2, max(0.5, playbackRate.isFinite ? playbackRate : 1))
        self.direction = direction
        self.gain = min(0.72, max(0, gain.isFinite ? gain : 0))
    }
}

package struct AudioSlicePlan: Equatable, Sendable {
    package static let maximumTriggerCount = 6

    package let sourceStartStep: Int
    package let sourceLengthInSteps: Double
    package let sourceKind: AudioSliceSourceKind
    package let texture: AudioSliceTexture
    package let textureSeed: UInt64
    package let triggers: [AudioSliceTrigger]

    package init(sourceStartStep: Int, sourceLengthInSteps: Double,
                 sourceKind: AudioSliceSourceKind = .percussion,
                 texture: AudioSliceTexture = .cut,
                 textureSeed: UInt64 = 0,
                 triggers: [AudioSliceTrigger]) {
        self.sourceStartStep = min(15, max(0, sourceStartStep))
        self.sourceLengthInSteps = min(
            2,
            max(0.25, sourceLengthInSteps.isFinite ? sourceLengthInSteps : 1)
        )
        self.sourceKind = sourceKind
        self.texture = texture
        self.textureSeed = texture == .granularMemory ? textureSeed : 0
        self.triggers = Array(triggers.prefix(Self.maximumTriggerCount)).sorted {
            if $0.onsetStep != $1.onsetStep { return $0.onsetStep < $1.onsetStep }
            if $0.direction != $1.direction { return $0.direction == .forward }
            return $0.playbackRate < $1.playbackRate
        }
    }
}

package enum ArpeggiatorDirection: String, CaseIterable, Sendable {
    case ascending
    case descending
    case pendulum
    case rotated
}

package struct ArpeggiatorStep: Equatable, Sendable {
    package let onsetStep: Int
    package let durationInSteps: Double
    package let frequencyRatio: Double
    package let velocity: Double
    package let octave: Int

    package init(onsetStep: Int, durationInSteps: Double,
                 frequencyRatio: Double, velocity: Double, octave: Int) {
        self.onsetStep = min(15, max(0, onsetStep))
        self.durationInSteps = min(2, max(0.25, durationInSteps))
        self.frequencyRatio = min(8, max(0.125, frequencyRatio))
        self.velocity = min(1, max(0, velocity))
        self.octave = min(2, max(0, octave))
    }
}

/// A complete bar-scale arpeggiator result. It is not a renderer-side clock:
/// every onset, pitch, duration, octave, and accent is immutable score data.
package struct ArpeggiatorPlan: Equatable, Sendable {
    package static let maximumStepCount = 16

    package let direction: ArpeggiatorDirection
    package let rateInSteps: Int
    package let octaveSpan: Int
    package let rotation: Int
    package let steps: [ArpeggiatorStep]

    package init(direction: ArpeggiatorDirection, rateInSteps: Int,
                 octaveSpan: Int, rotation: Int, steps: [ArpeggiatorStep]) {
        self.direction = direction
        self.rateInSteps = min(4, max(1, rateInSteps))
        self.octaveSpan = min(2, max(1, octaveSpan))
        self.rotation = min(15, max(0, rotation))
        self.steps = Array(steps.prefix(Self.maximumStepCount)).sorted {
            $0.onsetStep < $1.onsetStep
        }
    }
}

package enum PadHarmonicFunction: String, CaseIterable, Sendable {
    case tonic
    case modalColor
    case subdominant
    case returnPull
}

/// How much of the existing harmonic vocabulary one bar is allowed to reveal.
/// This is phrase geometry, not a second progression or renderer-side state.
package enum PadHarmonicDisclosureStage: String, CaseIterable, Sendable {
    case established
    case concealed
    case partial
    case revealed
}

/// Bar-resolved rhythmic motion for one already-sustained pad. The relation is
/// semantic score data rather than a renderer-local LFO: absolute-bar phase
/// continues the three-sixteenth cell across phrase boundaries, while neutral
/// bars execute the legacy pad path exactly.
package enum PadRhythmicModulationRelation: String, CaseIterable, Sendable {
    case neutral
    case threeStepPulse = "three-step-pulse"
}

package struct PadRhythmicModulation: Equatable, Sendable {
    package static let cellLength = 3
    package static let stepCount = 16

    package let relation: PadRhythmicModulationRelation
    package let phaseOffset: Int

    package init(
        relation: PadRhythmicModulationRelation,
        phaseOffset: Int = 0
    ) {
        self.relation = relation
        self.phaseOffset = relation == .neutral
            ? 0 : min(Self.cellLength - 1, max(0, phaseOffset))
    }

    package static let neutral = PadRhythmicModulation(relation: .neutral)

    package var active: Bool { relation != .neutral }

    /// A deliberately asymmetric three-step cell. The filter opening supplies
    /// the audible rhythmic articulation while the later spatial-send lift
    /// creates a bounded response from the existing spatial return.
    package func filterScale(atStep step: Int) -> Double {
        guard active else { return 1 }
        switch cellIndex(atStep: step) {
        case 0: return 0.38
        case 1: return 1
        default: return 0.62
        }
    }

    package func spatialSendScale(atStep step: Int) -> Double {
        guard active else { return 1 }
        switch cellIndex(atStep: step) {
        case 0: return 0.72
        case 1: return 0.85
        default: return 1.28
        }
    }

    /// The sustained pad opens for the same cell stage that owns the maximum
    /// filter aperture. Renderer-owned edge shaping makes this target click
    /// safe; the score owns only the exact closed/open relationship.
    package func amplitudeGateTarget(atStep step: Int) -> Double {
        guard active else { return 1 }
        return cellIndex(atStep: step) == 1 ? 1 : 0
    }

    private func cellIndex(atStep step: Int) -> Int {
        let boundedStep = min(Self.stepCount - 1, max(0, step))
        return (boundedStep + phaseOffset) % Self.cellLength
    }
}

package struct PadVoice: Equatable, Sendable {
    package let modalDegree: Int
    package let semitone: Int
    package let frequencyRatio: Double

    package init(modalDegree: Int, semitone: Int) {
        self.modalDegree = modalDegree
        self.semitone = min(36, max(-24, semitone))
        frequencyRatio = pow(2, Double(self.semitone) / 12)
    }
}

/// One truly simultaneous pad chord. Voice-leading facts are retained beside
/// the voicing so later policy can detect excessive movement without carrying
/// renderer state or PCM into Core.
package struct PadVoicing: Equatable, Sendable {
    package static let voiceCount = 4

    package let function: PadHarmonicFunction
    package let harmonicDisclosureStage: PadHarmonicDisclosureStage
    package let onsetStep: Int
    package let durationInSteps: Double
    package let voices: [PadVoice]
    package let commonToneCount: Int
    package let totalMovementInSemitones: Int
    package let maximumLeapInSemitones: Int
    package let contraryOuterMotion: Bool
    package let instrument: InstrumentAssignment
    package let rhythmicModulation: PadRhythmicModulation

    package init(function: PadHarmonicFunction,
                 harmonicDisclosureStage: PadHarmonicDisclosureStage = .established,
                 onsetStep: Int,
                 durationInSteps: Double, voices: [PadVoice],
                 previousVoices: [PadVoice],
                 instrument: InstrumentAssignment,
                 rhythmicModulation: PadRhythmicModulation = .neutral) {
        self.function = function
        self.harmonicDisclosureStage = harmonicDisclosureStage
        self.onsetStep = min(15, max(0, onsetStep))
        self.durationInSteps = min(
            ResolvedUpperNote.maximumDurationInSteps,
            max(1, durationInSteps)
        )
        self.voices = Array(voices.prefix(Self.voiceCount))
        let pairs = Array(zip(previousVoices, self.voices))
        commonToneCount = pairs.filter {
            (($0.0.semitone - $0.1.semitone) % 12 + 12) % 12 == 0
        }.count
        let movements = pairs.map { abs($0.0.semitone - $0.1.semitone) }
        totalMovementInSemitones = movements.reduce(0, +)
        maximumLeapInSemitones = movements.max() ?? 0
        if let previousLow = previousVoices.first?.semitone,
           let previousHigh = previousVoices.last?.semitone,
           let currentLow = self.voices.first?.semitone,
           let currentHigh = self.voices.last?.semitone {
            let lowMotion = currentLow - previousLow
            let highMotion = currentHigh - previousHigh
            contraryOuterMotion = lowMotion != 0 && highMotion != 0 &&
                (lowMotion < 0) != (highMotion < 0)
        } else {
            contraryOuterMotion = false
        }
        self.instrument = instrument.isValid
            ? instrument : InstrumentPalette.safeUpper(role: .atmosphere)
        self.rhythmicModulation = rhythmicModulation
    }
}

package struct PhraseCompositionBar: Equatable, Sendable {
    package let bar: Int
    package let audioSlice: AudioSlicePlan?
    package let arpeggiator: ArpeggiatorPlan?
    package let padVoicing: PadVoicing?

    package init(bar: Int, audioSlice: AudioSlicePlan?,
                 arpeggiator: ArpeggiatorPlan?, padVoicing: PadVoicing?) {
        self.bar = bar
        self.audioSlice = audioSlice
        self.arpeggiator = arpeggiator
        self.padVoicing = padVoicing
    }

    package static func neutral(bar: Int) -> PhraseCompositionBar {
        PhraseCompositionBar(
            bar: bar,
            audioSlice: nil,
            arpeggiator: nil,
            padVoicing: nil
        )
    }
}

/// The only harmonic state that crosses a phrase boundary. It contains score
/// data, never oscillator/filter state, so candidate planning remains pure and
/// deterministic while the next phrase can lead from the chord actually
/// accepted at the previous boundary.
package struct HarmonicContinuationState: Equatable, Sendable {
    package let voices: [PadVoice]

    package init(voices: [PadVoice] = []) {
        self.voices = voices.count == PadVoicing.voiceCount ? voices : []
    }
}

/// Unified bounded planner for the four composition capabilities. It derives
/// every bar from the canonical score and advances only the accepted, bounded
/// harmonic continuation supplied by the session owner.
package enum PhraseCompositionResolver {
    package static func resolve(
        scene: TechnoScene,
        dna: SceneDNA,
        kind: AutonomousPhraseKind,
        resolvedBars: [ResolvedPerformanceBar],
        harmonicContinuation: HarmonicContinuationState = HarmonicContinuationState()
    ) -> [PhraseCompositionBar] {
        let identityDisclosureIsCoordinated = kind == .identityReturn &&
            resolvedBars.contains {
                $0.harmonicDisclosureRelationship == .home ||
                    $0.harmonicDisclosureRelationship == .change
            }
        guard kind != .identityReturn || identityDisclosureIsCoordinated else {
            return resolvedBars.map { .neutral(bar: $0.performance.bar) }
        }

        var previousVoices = harmonicContinuation.voices
        return resolvedBars.map { resolved in
            let bar = resolved.performance.bar
            let pad = padVoicing(
                scene: scene,
                dna: dna,
                kind: kind,
                resolved: resolved,
                previousVoices: previousVoices
            )
            if let pad { previousVoices = pad.voices }
            return PhraseCompositionBar(
                bar: bar,
                audioSlice: audioSlicePlan(
                    resolved: resolved,
                    kind: kind
                ),
                arpeggiator: arpeggiatorPlan(
                    scene: scene,
                    dna: dna,
                    kind: kind,
                    resolved: resolved,
                    padVoicing: pad
                ),
                padVoicing: pad
            )
        }
    }

    private static func audioSlicePlan(
        resolved: ResolvedPerformanceBar,
        kind: AutonomousPhraseKind
    ) -> AudioSlicePlan? {
        guard kind == .majorBreak,
              resolved.performanceCharacter == .brokenSuspension ||
                resolved.performanceCharacter == .ambientDrift,
              resolved.performance.section == .breakdown,
              resolved.percussionEchoTexture == nil else {
            return nil
        }
        let percussionSource = PercussionEchoTextureResolver.eligibleSourceEvents(
            in: resolved.ensemble
        ).first
        let kickSource = resolved.ensemble.events
            .filter { $0.voice == .kick && $0.step <= 7 }
            .sorted { $0.step < $1.step }
            .first
        guard let source = percussionSource ?? kickSource else { return nil }
        let sourceKind: AudioSliceSourceKind = percussionSource == nil ? .kick : .percussion
        let localBar = resolved.performance.localBar
        let patterns: [[(Int, Double, AudioSliceDirection, Double)]] = [
            [(8, 1, .forward, 0.34), (10, 1.5, .forward, 0.29),
             (12, 0.75, .reverse, 0.27), (15, 2, .forward, 0.23)],
            [(7, 0.75, .forward, 0.30), (9, 1, .reverse, 0.28),
             (11, 1.5, .forward, 0.25), (14, 1, .reverse, 0.22)],
            [(8, 1.5, .reverse, 0.31), (11, 1, .forward, 0.27),
             (13, 2, .forward, 0.22)],
        ]
        let pattern = patterns[localBar % patterns.count]
        let triggers = pattern.compactMap { onset, rate, direction, gain in
            onset > source.step ? AudioSliceTrigger(
                onsetStep: onset,
                playbackRate: rate,
                direction: direction,
                gain: gain
            ) : nil
        }
        guard !triggers.isEmpty else { return nil }
        return AudioSlicePlan(
            sourceStartStep: source.step,
            sourceLengthInSteps: localBar.isMultiple(of: 2) ? 1 : 0.5,
            sourceKind: sourceKind,
            texture: resolved.performanceCharacter == .ambientDrift
                ? .granularMemory : .cut,
            textureSeed: SceneDNA.derivedSeed(
                scene: resolved.performance.eventSeed,
                domain: 0xA0D1_05E,
                index: resolved.performance.bar
            ),
            triggers: triggers
        )
    }

    private static func arpeggiatorPlan(
        scene: TechnoScene,
        dna: SceneDNA,
        kind: AutonomousPhraseKind,
        resolved: ResolvedPerformanceBar,
        padVoicing: PadVoicing?
    ) -> ArpeggiatorPlan? {
        let character = resolved.performanceCharacter
        let eligibleCharacter = character == .melodicGlow ||
            character == .acidPressure || character == .peakDrive
        guard eligibleCharacter,
              kind != .majorBreak,
              resolved.arrangementGesture != .structuralMarker,
              resolved.interlockChapter != .tone,
              resolved.performance.roles.contains(.motif),
              resolved.ensemble.events.contains(where: { $0.voice == .motif }) else {
            return nil
        }
        let macro = positiveModulo(resolved.performance.bar, 16)
        let rate = character == .melodicGlow && scene.noteActivity > 0.42 ? 1 : 2
        let octaveSpan = character == .peakDrive || scene.melodicity > 0.52 ? 2 : 1
        let direction: ArpeggiatorDirection = switch character {
        case .melodicGlow: macro < 8 ? .pendulum : .rotated
        case .acidPressure: .ascending
        case .peakDrive: .descending
        case .hypnoticLock, .brokenSuspension, .ambientDrift: .ascending
        }
        let rotation = Int(SceneDNA.derivedSeed(
            scene: resolved.performance.eventSeed,
            domain: 0xA2E6_610,
            index: resolved.performance.bar
        ) % 4)
        let pitchClasses: [Int]
        if let padVoicing {
            pitchClasses = padVoicing.voices.map(\.semitone)
        } else {
            pitchClasses = dna.motif.degrees.map(dna.nearestModalDegree)
        }
        let unique = Array(Set(pitchClasses)).sorted()
        guard !unique.isEmpty else { return nil }
        let cycle = arpeggioCycle(
            pitches: unique,
            direction: direction,
            octaveSpan: octaveSpan,
            rotation: rotation
        )
        let onsetSteps = Array(stride(from: 0, to: 16, by: rate))
        let steps = onsetSteps.enumerated().map { index, onset in
            let semitone = cycle[index % cycle.count]
            let accent = resolved.performance.accent(at: onset)
            return ArpeggiatorStep(
                onsetStep: onset,
                durationInSteps: Double(rate) * (character == .acidPressure ? 0.72 : 0.84),
                frequencyRatio: pow(2, Double(semitone) / 12),
                velocity: min(0.86, 0.48 + accent * 0.26 + (index.isMultiple(of: 4) ? 0.07 : 0)),
                octave: max(0, semitone / 12)
            )
        }
        return ArpeggiatorPlan(
            direction: direction,
            rateInSteps: rate,
            octaveSpan: octaveSpan,
            rotation: rotation,
            steps: steps
        )
    }

    private static func arpeggioCycle(
        pitches: [Int],
        direction: ArpeggiatorDirection,
        octaveSpan: Int,
        rotation: Int
    ) -> [Int] {
        var expanded: [Int] = []
        for octave in 0..<octaveSpan {
            expanded.append(contentsOf: pitches.map { $0 + octave * 12 })
        }
        expanded = Array(Set(expanded)).sorted()
        guard !expanded.isEmpty else { return [0] }
        switch direction {
        case .ascending:
            return expanded
        case .descending:
            return expanded.reversed()
        case .pendulum:
            return expanded.count < 3
                ? expanded
                : expanded + expanded.dropFirst().dropLast().reversed()
        case .rotated:
            let offset = rotation % expanded.count
            return Array(expanded[offset...]) + Array(expanded[..<offset])
        }
    }

    private static func padVoicing(
        scene: TechnoScene,
        dna: SceneDNA,
        kind: AutonomousPhraseKind,
        resolved: ResolvedPerformanceBar,
        previousVoices: [PadVoice]
    ) -> PadVoicing? {
        let character = resolved.performanceCharacter
        let eligible = resolved.performance.roles.contains(.atmosphere) && (
            character == .ambientDrift || character == .melodicGlow ||
                kind == .lock || kind == .majorBreak ||
                kind == .energyRelease || resolved.interlockChapter == .breath ||
                resolved.harmonicDisclosureRelationship == .raise ||
                resolved.harmonicDisclosureRelationship == .change ||
                resolved.harmonicDisclosureRelationship == .home
        )
        guard eligible else { return nil }
        let bar = resolved.performance.bar
        let disclosureStage = harmonicDisclosureStage(
            kind: kind,
            localBar: resolved.performance.localBar,
            phraseLength: resolved.performance.phraseLength
        )
        let current = disclosedHarmonicFunction(
            established: harmonicFunction(
                character: character,
                absoluteBar: bar
            ),
            kind: kind,
            localBar: resolved.performance.localBar,
            phraseLength: resolved.performance.phraseLength
        )
        let voices = canonicalVoicing(
            dna: dna,
            function: current,
            previous: previousVoices,
            preferContraryMotion: positiveModulo(bar, 4) == 3
        )
        let assignment = InstrumentPalette.resolveUpper(
            role: .atmosphere,
            world: SynthWorldDNA(scene: scene, dna: dna),
            kind: kind,
            gesture: resolved.performance.section == .breakdown ? .suspend : .interlock,
            chapter: resolved.interlockChapter,
            mutationAmount: 0.36 + resolved.performance.tension * 0.24,
            forceHome: false,
            pulseEchoEnabled: false,
            performanceCharacter: character
        )
        return PadVoicing(
            function: current,
            harmonicDisclosureStage: disclosureStage,
            onsetStep: 0,
            durationInSteps: 16,
            voices: voices,
            previousVoices: previousVoices,
            instrument: assignment.patch.architecture == .tonalMotion
                ? assignment
                : InstrumentPalette.safeUpper(role: .atmosphere),
            rhythmicModulation: padRhythmicModulation(
                kind: kind,
                resolved: resolved
            )
        )
    }

    package static func harmonicDisclosureStage(
        kind: AutonomousPhraseKind,
        localBar: Int,
        phraseLength: Int
    ) -> PadHarmonicDisclosureStage {
        guard phraseLength > 0,
              localBar >= 0,
              localBar < phraseLength else { return .established }
        switch kind {
        case .lock:
            return localBar < phraseLength / 2 ? .concealed : .partial
        case .majorBreak:
            return .revealed
        case .contrast, .energyRelease, .identityReturn:
            return .established
        }
    }

    package static func disclosedHarmonicFunction(
        established: PadHarmonicFunction,
        kind: AutonomousPhraseKind,
        localBar: Int,
        phraseLength: Int
    ) -> PadHarmonicFunction {
        switch harmonicDisclosureStage(
            kind: kind,
            localBar: localBar,
            phraseLength: phraseLength
        ) {
        case .concealed:
            return .tonic
        case .partial:
            let start = phraseLength / 2
            let length = phraseLength - start
            let index = localBar - start
            return index * 2 < length ? .tonic : .modalColor
        case .revealed:
            return [
                .tonic, .modalColor, .subdominant, .returnPull,
            ][localBar % 4]
        case .established:
            return established
        }
    }

    private static func padRhythmicModulation(
        kind: AutonomousPhraseKind,
        resolved: ResolvedPerformanceBar
    ) -> PadRhythmicModulation {
        let absoluteBar = resolved.performance.bar
        let macroPosition = positiveModulo(absoluteBar, 16)
        let supportsRhythmicInfrastructure =
            kind == .majorBreak &&
            resolved.performance.section == .breakdown &&
            (8...14).contains(macroPosition) &&
            resolved.arrangementGesture != .minimalize &&
            resolved.arrangementGesture != .structuralMarker
        guard supportsRhythmicInfrastructure else { return .neutral }
        let remainder = absoluteBar % PadRhythmicModulation.cellLength
        let phase = remainder >= 0
            ? remainder : remainder + PadRhythmicModulation.cellLength
        return PadRhythmicModulation(
            relation: .threeStepPulse,
            phaseOffset: phase
        )
    }

    private static func harmonicFunction(
        character: PerformanceCharacter,
        absoluteBar: Int
    ) -> PadHarmonicFunction {
        let phase = positiveModulo(absoluteBar, 8)
        switch character {
        case .ambientDrift:
            return [.tonic, .tonic, .modalColor, .modalColor,
                    .subdominant, .subdominant, .returnPull, .tonic][phase]
        case .melodicGlow:
            return [.tonic, .modalColor, .subdominant, .modalColor,
                    .tonic, .subdominant, .returnPull, .tonic][phase]
        case .hypnoticLock, .acidPressure, .peakDrive, .brokenSuspension:
            return [.tonic, .tonic, .modalColor, .tonic,
                    .subdominant, .tonic, .returnPull, .tonic][phase]
        }
    }

    package static func canonicalChordDegrees(
        modalIdentity: ModalIdentity,
        function: PadHarmonicFunction
    ) -> [Int] {
        let modalDegrees = modalIdentity.degrees
        let rootIndex: Int = switch function {
        case .tonic: 0
        case .modalColor:
            // Dorian/Aeolian disclose their contrasting sixth; Phrygian
            // discloses its defining flat second. Stacking modal thirds keeps
            // every chord inside one frame without snapping two functions to
            // the same realized pitch-class set.
            modalIdentity == .phrygian ? 1 : 5
        case .subdominant: 3
        case .returnPull: 6
        }
        return stride(from: 0, through: 6, by: 2).map { offset in
            let scaleIndex = rootIndex + offset
            let octave = scaleIndex / modalDegrees.count
            return modalDegrees[scaleIndex % modalDegrees.count] + octave * 12
        }
    }

    private static func canonicalVoicing(
        dna: SceneDNA,
        function: PadHarmonicFunction,
        previous: [PadVoice]?,
        preferContraryMotion: Bool
    ) -> [PadVoice] {
        let chordDegrees = canonicalChordDegrees(
            modalIdentity: dna.modalIdentity,
            function: function
        )
        let candidates = voicingCandidates(degrees: chordDegrees)
        guard let previous, previous.count == PadVoicing.voiceCount else {
            return candidates.min(by: { voicingSpreadCost($0) < voicingSpreadCost($1) }) ?? []
        }
        return candidates.min { lhs, rhs in
            voiceLeadingCost(
                candidate: lhs,
                previous: previous,
                preferContraryMotion: preferContraryMotion
            ) < voiceLeadingCost(
                candidate: rhs,
                previous: previous,
                preferContraryMotion: preferContraryMotion
            )
        } ?? []
    }

    private static func voicingCandidates(degrees: [Int]) -> [[PadVoice]] {
        var candidates: [[PadVoice]] = []
        for inversion in 0..<PadVoicing.voiceCount {
            let rotated = Array(degrees[inversion...]) + Array(degrees[..<inversion])
            for baseOctave in 0...1 {
                var semitones: [Int] = []
                for (index, degree) in rotated.enumerated() {
                    var semitone = degree + baseOctave * 12
                    if index > 0 {
                        while semitone <= semitones[index - 1] { semitone += 12 }
                    }
                    semitones.append(semitone)
                }
                guard let first = semitones.first, let last = semitones.last,
                      first >= -12, last <= 36, last - first <= 24 else { continue }
                candidates.append(zip(rotated, semitones).map {
                    PadVoice(modalDegree: $0.0, semitone: $0.1)
                })
            }
        }
        return candidates
    }

    private static func voicingSpreadCost(_ voices: [PadVoice]) -> Int {
        guard let low = voices.first?.semitone,
              let high = voices.last?.semitone else { return Int.max }
        return abs(low) * 2 + abs(high - 19) + max(0, high - low - 19) * 3
    }

    private static func voiceLeadingCost(
        candidate: [PadVoice],
        previous: [PadVoice],
        preferContraryMotion: Bool
    ) -> Int {
        guard candidate.count == previous.count else { return Int.max }
        let movement = zip(candidate, previous).map {
            abs($0.0.semitone - $0.1.semitone)
        }
        let leapPenalty = movement.reduce(0) { $0 + max(0, $1 - 5) * 4 }
        let commonTones = zip(candidate, previous).filter {
            positiveModulo($0.0.semitone - $0.1.semitone, 12) == 0
        }.count
        let lowMotion = candidate[0].semitone - previous[0].semitone
        let highMotion = candidate[3].semitone - previous[3].semitone
        let contrary = lowMotion != 0 && highMotion != 0 &&
            (lowMotion < 0) != (highMotion < 0)
        let contraryPenalty = preferContraryMotion && !contrary ? 5 : 0
        return movement.reduce(0, +) + leapPenalty - commonTones * 3 +
            contraryPenalty + voicingSpreadCost(candidate) / 5
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
