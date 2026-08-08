import Foundation

// MARK: - Beat Shape Vocabulary

public enum BeatShapeBand: Int, CaseIterable, Sendable {
    case straight = 0    // 0.0–0.2: four-on-floor
    case garage = 1      // 0.2–0.4: garage shuffle
    case twoStep = 2     // 0.4–0.6: 2-step / broken garage
    case jungle = 3      // 0.6–0.8: jungle / breakbeat
    case fullBreak = 4   // 0.8–1.0: full breakbeat
}

public struct BeatShapePattern: Equatable, Sendable {
    public let kicks: [Int]   // step indices with kick hits
    public let claps: [Int]   // step indices with clap hits
}

public struct Step: Equatable, Sendable {
    public let kick: Bool
    public let hat: Bool
    public let clap: Bool
    public let bass: Bool

    public init(kick: Bool, hat: Bool, clap: Bool, bass: Bool) {
        self.kick = kick
        self.hat = hat
        self.clap = clap
        self.bass = bass
    }
}

public struct RenderCharacter: Equatable, Sendable {
    public let kickWeight: Double
    public let percussionBrightness: Double
    public let bassDecay: Double
    public let bassLevel: Double
}

public enum TimedEventKind: String, Equatable, Sendable {
    case kick
    case hat
    case clap
    case bass
}

/// A musical event positioned in a 16-step bar. `offsetInStep` is normalized
/// to one step: 0 is on-grid and positive values are delayed within the step.
public struct TimedEvent: Equatable, Sendable {
    public let stepIndex: Int
    public let kind: TimedEventKind
    public let offsetInStep: Double
    public let bar: Int

    public init(stepIndex: Int, kind: TimedEventKind, offsetInStep: Double = 0, bar: Int = 0) {
        self.stepIndex = stepIndex
        self.kind = kind
        self.offsetInStep = offsetInStep
        self.bar = bar
    }
}

public struct GrooveProfile: Equatable, Sendable {
    public let swingPercent: Double
    public let events: [TimedEvent]

    public init(swingPercent: Double, events: [TimedEvent]) {
        self.swingPercent = swingPercent
        self.events = events
    }
}

public enum MotifSourceIntent: String, Equatable, Sendable {
    case hypnosis = "Hypnosis"
    case drive = "Drive"
    case darkness = "Darkness"
}

public struct SynthEvent: Equatable, Sendable {
    public let stepIndex: Int
    public let offsetInStep: Double
    public let scaleDegree: Int
    public let frequency: Double
    public let durationInSteps: Double
    public let bar: Int
    public let sourceIntent: MotifSourceIntent

    public init(
        stepIndex: Int,
        offsetInStep: Double,
        scaleDegree: Int,
        frequency: Double,
        durationInSteps: Double,
        bar: Int = 0,
        sourceIntent: MotifSourceIntent
    ) {
        self.stepIndex = stepIndex
        self.offsetInStep = offsetInStep
        self.scaleDegree = scaleDegree
        self.frequency = frequency
        self.durationInSteps = durationInSteps
        self.bar = bar
        self.sourceIntent = sourceIntent
    }
}

public struct SequencerEvent: Equatable, Sendable {
    public let stepIndex: Int
    public let scaleDegree: Int
    public let frequency: Double
    public let durationInSteps: Double
    public let bar: Int
    public let kind: SequencerAmbientKind

    public init(stepIndex: Int, scaleDegree: Int, frequency: Double, durationInSteps: Double, bar: Int = 0, kind: SequencerAmbientKind) {
        self.stepIndex = stepIndex; self.scaleDegree = scaleDegree; self.frequency = frequency
        self.durationInSteps = durationInSteps; self.bar = bar; self.kind = kind
    }
}

public struct TechnoScene: Equatable, Sendable {
    public let seed: UInt64
    public let bpm: Double
    public let drive: Double
    public let darkness: Double
    public let hypnosis: Double
    public let beatShape: Double
    /// The semantic intention that produced this scene, if constructed via the mapper.
    /// Nil for scenes built from raw drive/darkness/hypnosis (legacy path).
    public let musicalIntent: MusicalIntent?
    // Derived render parameters from semantic controls
    public let aggression: Double
    public let machineTexture: Double
    public let drone: Double
    public let atmosphere: Double
    public let atmosphericDarkness: Double
    public let drumChaos: Double
    public let synthChaos: Double
    public let textureChaos: Double
    public let melodicity: Double
    public let synthPresence: Double
    public let noteActivity: Double
    public let syncopation: Double
    public let polyrhythm: Double
    public let steps: [Step]
    public let character: RenderCharacter
    public let groove: GrooveProfile
    public let motif: [SynthEvent]
    public let sequencer: [SequencerEvent]

    public static let bpmRange: ClosedRange<Double> = 118...142

    // MARK: - Beat Shape Vocabulary

    /// Paired kick+clap patterns organized by band. Each band has 6 variations.
    /// Kicks are step indices (0–15), claps are step indices (0–15).
    /// Step 0 always has a kick (downbeat anchor). 3–6 kicks per bar.
    /// Claps avoid kick steps to maintain rhythmic clarity.
    public static let beatShapeVocabulary: [BeatShapeBand: [BeatShapePattern]] = [
        .straight: [
            // Classic four-on-floor with clap on 2 and 4
            BeatShapePattern(kicks: [0, 4, 8, 12], claps: [4, 12]),
            BeatShapePattern(kicks: [0, 4, 8, 12], claps: [4, 10]),
            BeatShapePattern(kicks: [0, 4, 8, 12], claps: [4, 12, 14]),
            BeatShapePattern(kicks: [0, 4, 8, 12], claps: [4]),
            BeatShapePattern(kicks: [0, 4, 8, 12, 15], claps: [4, 12]),
            BeatShapePattern(kicks: [0, 4, 8, 12], claps: [4, 8, 12]),
        ],
        .garage: [
            // One kick displaced off quarter, clap shifts
            BeatShapePattern(kicks: [0, 5, 8, 12], claps: [4, 12]),
            BeatShapePattern(kicks: [0, 4, 10, 12], claps: [4, 14]),
            BeatShapePattern(kicks: [0, 3, 8, 12], claps: [4, 8]),
            BeatShapePattern(kicks: [0, 4, 8, 13], claps: [4, 12]),
            BeatShapePattern(kicks: [0, 4, 7, 12], claps: [4, 10]),
            BeatShapePattern(kicks: [0, 5, 8, 11], claps: [4, 14]),
        ],
        .twoStep: [
            // Two kicks displaced, garage/2-step feel
            BeatShapePattern(kicks: [0, 6, 10, 12], claps: [4, 14]),
            BeatShapePattern(kicks: [0, 3, 8, 13], claps: [6, 10]),
            BeatShapePattern(kicks: [0, 5, 8, 11], claps: [3, 10]),
            BeatShapePattern(kicks: [0, 6, 9, 12], claps: [5, 11]),
            BeatShapePattern(kicks: [0, 4, 10, 14], claps: [6, 13]),
            BeatShapePattern(kicks: [0, 5, 9, 13], claps: [4, 14]),
        ],
        .jungle: [
            // Scattered kicks, one quarter-note kick max besides step 0
            BeatShapePattern(kicks: [0, 6, 9, 15], claps: [5, 11]),
            BeatShapePattern(kicks: [0, 2, 10, 12, 15], claps: [6, 13]),
            BeatShapePattern(kicks: [0, 3, 6, 12, 14], claps: [4, 7]),
            BeatShapePattern(kicks: [0, 5, 9, 13, 15], claps: [6, 10]),
            BeatShapePattern(kicks: [0, 2, 7, 11, 14], claps: [5, 12]),
            BeatShapePattern(kicks: [0, 6, 10, 13, 15], claps: [4, 8]),
        ],
        .fullBreak: [
            // Maximum broken: zero quarter-note kicks except step 0
            BeatShapePattern(kicks: [0, 3, 6, 8, 11, 13], claps: [2, 5, 10, 14]),
            BeatShapePattern(kicks: [0, 2, 5, 9, 11, 14], claps: [3, 8, 13]),
            BeatShapePattern(kicks: [0, 3, 5, 7, 10, 14], claps: [1, 6, 11]),
            BeatShapePattern(kicks: [0, 2, 6, 9, 12, 15], claps: [4, 7, 13]),
            BeatShapePattern(kicks: [0, 3, 7, 10, 13, 15], claps: [2, 6, 11]),
            BeatShapePattern(kicks: [0, 2, 5, 8, 11, 14], claps: [3, 9, 13]),
        ],
    ]

    /// Selects a beat-shape pattern for a given bar, deterministically varying
    /// within the band so consecutive bars feel like a drummer working the kit.
    public static func beatShapePattern(beatShape: Double, seed: UInt64, bar: Int) -> BeatShapePattern {
        let clamped = min(max(beatShape, 0), 1)
        let bandIndex = min(max(Int((clamped * 4).rounded()), 0), 4)
        guard let band = BeatShapeBand(rawValue: bandIndex),
              let patterns = beatShapeVocabulary[band],
              !patterns.isEmpty else {
            return BeatShapePattern(kicks: [0, 4, 8, 12], claps: [4, 12])
        }
        var random = SeededGenerator(seed: seed ^ UInt64(bar) ^ 0xB3A7D1F5E9C20486)
        let index = Int(random.next() % UInt64(patterns.count))
        return patterns[index]
    }

    /// Blends two patterns by probability when beatShape sits between bands.
    private static func blendedPattern(beatShape: Double, seed: UInt64, bar: Int) -> BeatShapePattern {
        let clamped = min(max(beatShape, 0), 1)
        let lowerBand = min(max(Int((clamped * 4).rounded(.down)), 0), 4)
        let upperBand = min(max(Int((clamped * 4).rounded(.up)), 0), 4)
        guard lowerBand != upperBand,
              let lower = BeatShapeBand(rawValue: lowerBand),
              let upper = BeatShapeBand(rawValue: upperBand),
              let lowerPatterns = beatShapeVocabulary[lower],
              let upperPatterns = beatShapeVocabulary[upper] else {
            return beatShapePattern(beatShape: beatShape, seed: seed, bar: bar)
        }
        let fraction = (clamped * 4) - Double(lowerBand)
        var random = SeededGenerator(seed: seed ^ UInt64(bar) ^ 0xE7D3B1A9F5C20486)
        if random.chance(fraction) {
            return upperPatterns[Int(random.next() % UInt64(upperPatterns.count))]
        } else {
            return lowerPatterns[Int(random.next() % UInt64(lowerPatterns.count))]
        }
    }

    private static func stepsFromPattern(_ pattern: BeatShapePattern, hatProbability: Double, bassCandidate: Bool, random: inout SeededGenerator, index: Int, bassMask: inout Int, motifKickMask: inout Int) -> Step {
        let isQuarter = index.isMultiple(of: 4)
        let offbeat = index % 4 == 2
        let kick = pattern.kicks.contains(index)
        let clap = pattern.claps.contains(index)
        let hat = offbeat || (!isQuarter && random.chance(hatProbability))
        // Bass: avoid steps with kick hits, prefer candidate steps
        let bassAvail = !kick && bassCandidate
        let bass = bassAvail && random.chance(bassMask > 0 ? 0.22 : 0.14)
        if bass { bassMask &+= 1 }
        if kick { motifKickMask |= (1 << index) }
        return Step(kick: kick, hat: hat, clap: clap, bass: bass)
    }

    public init(seed: UInt64, bpm: Double = 130, drive: Double, darkness: Double, hypnosis: Double,
                beatShape: Double = 0.0,
                aggression: Double = 0.0,
                machineTexture: Double = 0.0,
                drone: Double = 0.0,
                atmosphere: Double = 0.0,
                atmosphericDarkness: Double = 0.0,
                drumChaos: Double = 0.0,
                synthChaos: Double = 0.0,
                textureChaos: Double = 0.0,
                melodicity: Double = 0.0,
                synthPresence: Double = 0.0,
                noteActivity: Double = 0.0,
                syncopation: Double = 0.0,
                polyrhythm: Double = 0.0,
                sequencerPresence: Double = 0.0, sequencerStyle: Double = 0.0,
                sequencerDensity: Double = 0.0, sequencerRegister: Double = 0.0,
                sequencerRepetition: Double = 0.0, sequencerDrift: Double = 0.0,
                sequencerDepth: Double = 0.0,
                musicalIntent: MusicalIntent? = nil) {
        let clampedDrive = Self.clamp(drive)
        let clampedDarkness = Self.clamp(darkness)
        let clampedHypnosis = Self.clamp(hypnosis)
        let clampedBeatShape = Self.clamp(beatShape)
        self.seed = seed
        self.drive = clampedDrive
        self.darkness = clampedDarkness
        self.hypnosis = clampedHypnosis
        self.beatShape = clampedBeatShape
        self.musicalIntent = musicalIntent
        self.aggression = Self.clamp(aggression)
        self.machineTexture = Self.clamp(machineTexture)
        self.drone = Self.clamp(drone)
        self.atmosphere = Self.clamp(atmosphere)
        self.atmosphericDarkness = Self.clamp(atmosphericDarkness)
        self.drumChaos = Self.clamp(drumChaos)
        self.synthChaos = Self.clamp(synthChaos)
        self.textureChaos = Self.clamp(textureChaos)
        self.melodicity = Self.clamp(melodicity)
        self.synthPresence = Self.clamp(synthPresence)
        self.noteActivity = Self.clamp(noteActivity)
        self.syncopation = Self.clamp(syncopation)
        self.polyrhythm = Self.clamp(polyrhythm)
        let presence = Self.clamp(sequencerPresence)
        let styleValue = Self.clamp(sequencerStyle)
        let kind: SequencerAmbientKind = styleValue < 0.34 ? .pulseNetwork : (styleValue < 0.67 ? .arpeggiatedMotif : .texturalStepField)
        self.bpm = min(max(bpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)

        var random = SeededGenerator(seed: seed)
        let clampedSyncopation = Self.clamp(syncopation)
        let extraHatChance = 0.03 + clampedDrive * 0.13 * (1 - clampedHypnosis * 0.55) + clampedSyncopation * 0.15
        let bassChance = 0.12 + clampedHypnosis * 0.18
        let pattern = Self.blendedPattern(beatShape: clampedBeatShape, seed: seed, bar: 0)
        var bassCount = 0
        var kickMask = 0
        // Syncopation expands bass candidate steps to include weaker 16th positions
        let weakBassSteps = [1, 2, 5, 7, 9, 11, 13]  // syncopated bass positions
        // Polyrhythm: triplet-approximating steps (3-against-4 feel)
        let tripletSteps = [3, 8, 13]  // ~16th-note triplet positions relative to 4/4
        let clampedPolyrhythm = Self.clamp(polyrhythm)
        steps = (0..<16).map { index in
            let isQuarter = index.isMultiple(of: 4)
            let offbeat = index % 4 == 2
            let kick = pattern.kicks.contains(index)
            let clap = pattern.claps.contains(index)
            let hat = offbeat || (!isQuarter && random.chance(extraHatChance))
            let strongBassCandidate = !isQuarter && [3, 6, 10, 14, 15].contains(index)
            let weakBassCandidate = weakBassSteps.contains(index)
            let tripletCandidate = tripletSteps.contains(index)
            // High syncopation enables bass on weak 16th positions
            let bassCandidate = strongBassCandidate
                || (weakBassCandidate && clampedSyncopation > 0.4 && random.chance(clampedSyncopation * 0.55))
                || (tripletCandidate && clampedPolyrhythm > 0.4 && random.chance(clampedPolyrhythm * 0.45))
            let bassAvail = !kick && bassCandidate
            let bass = bassAvail && random.chance(bassCandidate ? bassChance : 0.05)
            if bass { bassCount += 1 }
            if kick { kickMask |= (1 << index) }
            return Step(kick: kick, hat: hat, clap: clap, bass: bass)
        }
        character = RenderCharacter(
            kickWeight: 0.55 + clampedDrive * 0.22,
            percussionBrightness: 0.18 + (1 - clampedDarkness) * 0.55,
            bassDecay: 0.10 + clampedHypnosis * 0.16,
            bassLevel: 0.12 + clampedDrive * 0.12
        )

        var grooveRandom = SeededGenerator(seed: seed ^ 0x6A09E667F3BCC909)
        let seedVariation = (grooveRandom.unit() - 0.5) * 0.006
        let swingPercent = min(max(0.50 + clampedHypnosis * 0.04 + clampedDrive * 0.02 + seedVariation, 0.50), 0.56)
        let offset = (swingPercent - 0.50) * 2
        var events: [TimedEvent] = []
        for (index, step) in steps.enumerated() {
            if step.kick { events.append(TimedEvent(stepIndex: index, kind: .kick)) }
            if step.hat {
                events.append(TimedEvent(stepIndex: index, kind: .hat, offsetInStep: Self.eligibleSwingOffset(index, kind: .hat, offset: offset)))
            }
            if step.clap { events.append(TimedEvent(stepIndex: index, kind: .clap)) }
            if step.bass {
                events.append(TimedEvent(stepIndex: index, kind: .bass, offsetInStep: Self.eligibleSwingOffset(index, kind: .bass, offset: offset)))
            }
        }
        let grooveProfile = GrooveProfile(swingPercent: swingPercent, events: events)
        groove = grooveProfile

        var motifRandom = SeededGenerator(seed: seed ^ 0xBB67AE8584CAA73B)
        let clampedMelodicity = Self.clamp(melodicity)
        let clampedNoteActivity = Self.clamp(noteActivity)
        // melodicity expands scale vocabulary: pentatonic → chromatic
        let meloBlend = clampedMelodicity * 0.55
        let chromaNotes: [Int] = [0, 2, 5, 7, 10]  // approximate chromatic counterpart
        let penta: [Int] = [0, 3, 5, 7, 10]
        let scale: [Int] = (0..<5).map { i in
            let pDeg = Double(penta[i])
            let cDeg = Double(chromaNotes[i])
            return Int((pDeg * (1.0 - meloBlend) + cDeg * meloBlend).rounded())
        }
        var safeSteps: [Int] = []
        for index in [2, 6, 10, 14] where !steps[index].bass {
            safeSteps.append(index)
        }
        let availableSteps = safeSteps.isEmpty ? [2, 6, 10, 14] : safeSteps
        let firstStep = availableSteps[Int(motifRandom.next() % UInt64(availableSteps.count))]
        let firstDegree = scale[Int(motifRandom.next() % UInt64(scale.count))]
        let root = clampedDarkness > 0.68 ? 110.0 : 220.0
        let firstIntent: MotifSourceIntent = clampedHypnosis >= clampedDrive ? .hypnosis : .drive
        var motifEvents = [Self.makeSynthEvent(
            stepIndex: firstStep,
            degree: firstDegree,
            root: root,
            groove: grooveProfile,
            source: firstIntent,
            duration: 0.72
        )]
        // noteActivity: probability of extra motif notes per bar
        // Hypnosis keeps the motif present and recognizable; activity and drive
        // decide whether it develops into a second phrase note.
        if motifRandom.chance(0.18 + clampedDrive * 0.40 + clampedNoteActivity * 0.4 + clampedHypnosis * 0.12) {
            let secondStep = availableSteps.first { $0 != firstStep && abs($0 - firstStep) >= 4 } ?? ((firstStep + 8) % 16)
            let secondDegree = scale[Int(motifRandom.next() % UInt64(scale.count))]
            motifEvents.append(Self.makeSynthEvent(
                stepIndex: secondStep,
                degree: secondDegree,
                root: root,
                groove: grooveProfile,
                source: .drive,
                duration: 0.58
            ))
        }
        motif = motifEvents

        var sequenceRandom = SeededGenerator(seed: seed ^ 0x9E3779B97F4A7C15)
        let density = Self.clamp(sequencerDensity)
        let repetition = Self.clamp(sequencerRepetition)
        let drift = Self.clamp(sequencerDrift)
        let register = Self.clamp(sequencerRegister)
        let count = presence < 0.04 ? 0 : max(1, Int((1.0 + density * 5.0).rounded()))
        let allowed = steps.enumerated().compactMap { index, step in (step.hat || (step.kick && repetition > 0.72)) && !step.bass ? index : nil }
        let positions = allowed.isEmpty ? [2, 6, 10, 14] : allowed
        let sequencerScale = [0, 3, 5, 7, 10]
        sequencer = (0..<count).map { index in
            let position = positions[Int(sequenceRandom.next() % UInt64(positions.count))]
            let degree = sequencerScale[Int(sequenceRandom.next() % UInt64(sequencerScale.count))] + (drift > 0.45 && sequenceRandom.chance(drift) ? 12 : 0)
            let root = 82.41 * pow(2.0, register * 12.0 / 12.0)
            let duration = kind == .texturalStepField ? 0.35 + repetition * 0.5 : 0.5 + repetition * 1.5
            return SequencerEvent(stepIndex: position, scaleDegree: degree, frequency: root * pow(2, Double(degree) / 12), durationInSteps: duration, kind: kind)
        }
    }

    /// Creates a scene from a full `MusicalIntent` via the semantic mapper.
    public init(intent: MusicalIntent, seed: UInt64) {
        let mapped = MusicalIntentMapper.map(intent: intent, seed: seed)
        self.init(
            seed: seed,
            bpm: mapped.bpm,
            drive: mapped.drive,
            darkness: mapped.darkness,
            hypnosis: mapped.hypnosis,
            beatShape: mapped.beatShape,
            aggression: mapped.aggression,
            machineTexture: mapped.machineTexture,
            drone: mapped.drone,
            atmosphere: mapped.atmosphere,
            atmosphericDarkness: mapped.atmosphericDarkness,
            drumChaos: mapped.drumChaos,
            synthChaos: mapped.synthChaos,
            textureChaos: mapped.textureChaos,
            melodicity: mapped.melodicity,
            synthPresence: mapped.synthPresence,
            noteActivity: mapped.noteActivity,
            syncopation: mapped.syncopation,
            polyrhythm: mapped.polyrhythm,
            sequencerPresence: mapped.sequencerPresence, sequencerStyle: mapped.sequencerStyle,
            sequencerDensity: mapped.sequencerDensity, sequencerRegister: mapped.sequencerRegister,
            sequencerRepetition: mapped.sequencerRepetition, sequencerDrift: mapped.sequencerDrift,
            sequencerDepth: mapped.sequencerDepth,
            musicalIntent: intent
        )
    }

    /// Creates a semantically mapped scene while preserving a tempo selected
    /// by the playback contract rather than the latent musical-intent mapper.
    public init(intent: MusicalIntent, seed: UInt64, bpm: Double) {
        let mapped = MusicalIntentMapper.map(intent: intent, seed: seed)
        self.init(
            seed: seed,
            bpm: bpm,
            drive: mapped.drive,
            darkness: mapped.darkness,
            hypnosis: mapped.hypnosis,
            beatShape: mapped.beatShape,
            aggression: mapped.aggression,
            machineTexture: mapped.machineTexture,
            drone: mapped.drone,
            atmosphere: mapped.atmosphere,
            atmosphericDarkness: mapped.atmosphericDarkness,
            drumChaos: mapped.drumChaos,
            synthChaos: mapped.synthChaos,
            textureChaos: mapped.textureChaos,
            melodicity: mapped.melodicity,
            synthPresence: mapped.synthPresence,
            noteActivity: mapped.noteActivity,
            syncopation: mapped.syncopation,
            polyrhythm: mapped.polyrhythm,
            sequencerPresence: mapped.sequencerPresence, sequencerStyle: mapped.sequencerStyle,
            sequencerDensity: mapped.sequencerDensity, sequencerRegister: mapped.sequencerRegister,
            sequencerRepetition: mapped.sequencerRepetition, sequencerDrift: mapped.sequencerDrift,
            sequencerDepth: mapped.sequencerDepth,
            musicalIntent: intent
        )
    }

    public static func surprise(seed: UInt64, bpm: Double = 130) -> TechnoScene {
        var random = SeededGenerator(seed: seed ^ 0xA1707EC4)
        let hypnosis = random.value(in: 0.55...0.88)
        let darkness = random.value(in: 0.58...0.9)
        let drive = random.value(in: 0.42...0.82)
        return TechnoScene(seed: seed, bpm: bpm, drive: drive, darkness: darkness, hypnosis: hypnosis)
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private static func eligibleSwingOffset(_ stepIndex: Int, kind: TimedEventKind, offset: Double) -> Double {
        switch kind {
        case .hat:
            return stepIndex.isMultiple(of: 2) && stepIndex % 4 != 2 ? 0 : offset
        case .bass:
            return stepIndex.isMultiple(of: 2) ? 0 : offset
        case .kick, .clap:
            return 0
        }
    }

    private static func makeSynthEvent(
        stepIndex: Int,
        degree: Int,
        root: Double,
        groove: GrooveProfile,
        source: MotifSourceIntent,
        duration: Double
    ) -> SynthEvent {
        let offset = groove.events.first {
            $0.stepIndex == stepIndex && $0.kind == .hat
        }?.offsetInStep ?? 0
        return SynthEvent(
            stepIndex: stepIndex,
            offsetInStep: offset,
            scaleDegree: degree,
            frequency: root * pow(2, Double(degree) / 12),
            durationInSteps: duration,
            sourceIntent: source
        )
    }
}

// MARK: - Arrangement

public enum SectionKind: String, Equatable, Sendable, CaseIterable {
    case groove
    case build
    case breakdown
    case returnSection = "return"

    public var displayName: String {
        switch self {
        case .groove: "Groove"
        case .build: "Build"
        case .breakdown: "Breakdown"
        case .returnSection: "Return"
        }
    }
}

public struct Phrase: Equatable, Sendable {
    public let index: Int
    public let section: SectionKind
    public let barCount: Int
    public let startBar: Int

    public init(index: Int, section: SectionKind, barCount: Int, startBar: Int) {
        self.index = index
        self.section = section
        self.barCount = barCount
        self.startBar = startBar
    }
}

public struct ArrangementPlan: Equatable, Sendable {
    public let phrases: [Phrase]
    public var totalBars: Int { phrases.reduce(0) { $0 + $1.barCount } }

    public init(seed: UInt64, paceOfChange: Double) {
        let clampedPace = min(max(paceOfChange, 0), 1)
        var random = SeededGenerator(seed: seed ^ 0x4C5FDF6E8B7A2C91)
        let baseLength = 4 + Int((1 - clampedPace) * 4)
        let cycle: [SectionKind] = [.groove, .build, .breakdown, .returnSection]
        let phraseCount = 8
        var built: [Phrase] = []
        var bar = 0
        for index in 0..<phraseCount {
            let section = cycle[index % cycle.count]
            let variation = Int(random.next() % 3) - 1
            let length = max(4, min(8, baseLength + variation))
            built.append(Phrase(index: index, section: section, barCount: length, startBar: bar))
            bar += length
        }
        phrases = built
    }

    public func phrase(atBar bar: Int) -> Phrase? {
        guard !phrases.isEmpty else { return nil }
        let wrapped = ((bar % totalBars) + totalBars) % totalBars
        return phrases.first { wrapped >= $0.startBar && wrapped < $0.startBar + $0.barCount }
    }

    public func section(atBar bar: Int) -> SectionKind {
        phrase(atBar: bar)?.section ?? .groove
    }

    public func barInPhrase(atBar bar: Int) -> Int {
        guard let phrase = phrase(atBar: bar) else { return 0 }
        return ((bar % totalBars) + totalBars) % totalBars - phrase.startBar
    }

    public func barsToPhraseEnd(atBar bar: Int) -> Int {
        guard let phrase = phrase(atBar: bar) else { return 0 }
        return phrase.barCount - barInPhrase(atBar: bar) - 1
    }
}

public struct PhraseContext: Equatable, Sendable {
    public let barsToPhraseEnd: Int
    public let currentSection: SectionKind

    public init(barsToPhraseEnd: Int, currentSection: SectionKind) {
        self.barsToPhraseEnd = barsToPhraseEnd
        self.currentSection = currentSection
    }
}

public enum TransitionReason: String, Equatable, Sendable {
    case drive = "Drive"
    case darkness = "Darkness"
    case hypnosis = "Hypnosis"
    case surprise = "Surprise me"
    case intent = "Intent"  // Small adjustments from slider tweaks — use subtle drift
}

public struct TransitionPlan: Equatable, Sendable {
    public let narrative: TransitionNarrative
    public let transitionBars: Int
    public let reason: TransitionReason

    /// Original non-phrase-aware planner. Kept for compatibility and tests.
    public init(current: TechnoScene, target: TechnoScene, reason: TransitionReason) {
        self.init(current: current, target: target, reason: reason, phrase: nil)
    }

    /// Per-control weights for semantic distance computation.
    private static let semanticWeights: [MusicalControl: Double] = [
        .groove: 1.0, .syncopation: 0.8, .beatShape: 1.2, .polyrhythm: 0.6,
        .darkness: 1.0, .atmosphere: 0.7, .atmosphericDarkness: 0.5, .hypnosis: 1.0, .aggression: 1.1, .drone: 0.9,
        .melodicity: 0.7, .synthPresence: 0.6, .noteActivity: 0.5,
        .overallChaos: 0.4, .drumChaos: 0.4, .synthChaos: 0.4, .textureChaos: 0.3,
        .paceOfChange: 0.9,
        .sequencerPresence: 1.0, .sequencerStyle: 0.8, .sequencerDensity: 0.7,
        .sequencerRegister: 0.4, .sequencerRepetition: 0.7, .sequencerDrift: 0.6,
        .sequencerDepth: 0.5,
    ]

    /// Computes the distance between two scenes. Uses full 17D semantic distance
    /// when both scenes carry a `MusicalIntent`; falls back to 3D drive/darkness/hypnosis.
    private static func distance(between current: TechnoScene, and target: TechnoScene) -> Double {
        guard let currentIntent = current.musicalIntent,
              let targetIntent = target.musicalIntent else {
            return abs(current.drive - target.drive)
                + abs(current.darkness - target.darkness)
                + abs(current.hypnosis - target.hypnosis)
        }
        var total = 0.0
        for control in MusicalControl.allCases {
            let weight = semanticWeights[control] ?? 1.0
            total += abs(currentIntent[control] - targetIntent[control]) * weight
        }
        // Normalize to roughly the same scale as the old 3D distance (max ~3.0)
        return total / max(1.0, Double(MusicalControl.allCases.count)) * 3.0
    }

    /// Phrase-aware planner. When `phrase` is provided, the director aligns
    /// transitions to phrase boundaries and may choose longer narratives.
    public init(
        current: TechnoScene,
        target: TechnoScene,
        reason: TransitionReason,
        phrase: PhraseContext?
    ) {
        self.reason = reason
        let distance = Self.distance(between: current, and: target)

        // Without phrase context, preserve the original binary behavior.
        guard let phrase else {
            if reason == .surprise || distance > 0.75 {
                narrative = .elementExchange
                transitionBars = 1
            } else {
                narrative = .subtleDrift
                transitionBars = 0
            }
            return
        }

        let atPhraseEnd = phrase.barsToPhraseEnd == 0
        let nearPhraseEnd = phrase.barsToPhraseEnd <= 1

        // Crash and cut: only for surprise at a phrase boundary with a large jump.
        if reason == .surprise && distance > 0.9 && atPhraseEnd {
            narrative = .crashAndCut
            transitionBars = 1
            return
        }

        // Breakdown and return: large shifts at a phrase boundary get a two-bar
        // breakdown-then-return journey.
        if distance > 0.75 && atPhraseEnd {
            narrative = .breakdownAndReturn
            transitionBars = 2
            return
        }

        // Fill and turn: medium shifts near a phrase boundary use a one-bar fill.
        if distance > 0.45 && nearPhraseEnd {
            narrative = .fillAndTurn
            transitionBars = 1
            return
        }

        // Long morph: medium shifts mid-phrase morph over the remaining bars.
        if distance > 0.45 && phrase.barsToPhraseEnd >= 2 {
            narrative = .longMorph
            transitionBars = min(phrase.barsToPhraseEnd, 4)
            return
        }

        // Element exchange: surprise or large jump without phrase alignment.
        if reason == .surprise || distance > 0.75 {
            narrative = .elementExchange
            transitionBars = 1
            return
        }

        // Subtle drift: small changes, next bar.
        narrative = .subtleDrift
        transitionBars = 0
    }
}

// Compatibility wrapper for early callers and focused pattern tests.
public struct TechnoPattern: Equatable, Sendable {
    public let steps: [Step]

    public init(seed: UInt64, energy: Double, mutation: Double) {
        steps = TechnoScene(
            seed: seed,
            drive: energy,
            darkness: 0.7,
            hypnosis: 1 - min(max(mutation, 0), 1) * 0.35
        ).steps
    }
}
