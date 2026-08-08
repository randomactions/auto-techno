package enum IntentBranch: String, CaseIterable, Sendable {
    case motion
    case character
    case musicality
    case uncertainty
    case evolution
    case sequencerAmbient
}

package enum SequencerAmbientKind: String, CaseIterable, Codable, Sendable {
    case pulseNetwork = "Pulse network"
    case arpeggiatedMotif = "Arpeggiated motif"
    case texturalStepField = "Textural step field"
}

package enum MusicalControl: String, CaseIterable, Codable, Sendable {
    case groove
    case syncopation
    case beatShape
    case polyrhythm
    case darkness
    case atmosphere
    case atmosphericDarkness
    case hypnosis
    case aggression
    case machineTexture
    case drone
    case melodicity
    case synthPresence
    case noteActivity
    case overallChaos
    case drumChaos
    case synthChaos
    case textureChaos
    case paceOfChange
    case sequencerPresence
    case sequencerStyle
    case sequencerDensity
    case sequencerRegister
    case sequencerRepetition
    case sequencerDrift
    case sequencerDepth

    package var branch: IntentBranch {
        switch self {
        case .groove, .syncopation, .beatShape, .polyrhythm: .motion
        case .darkness, .atmosphere, .atmosphericDarkness, .hypnosis, .aggression, .machineTexture, .drone: .character
        case .melodicity, .synthPresence, .noteActivity: .musicality
        case .overallChaos, .drumChaos, .synthChaos, .textureChaos: .uncertainty
        case .paceOfChange: .evolution
        case .sequencerPresence, .sequencerStyle, .sequencerDensity, .sequencerRegister,
             .sequencerRepetition, .sequencerDrift, .sequencerDepth: .sequencerAmbient
        }
    }

    package var minimum: Double { self == .groove ? 0.05 : 0 }
}

package struct MusicalIntent: Equatable, Sendable {
    private var storage: [MusicalControl: Double]

    package init(values: [MusicalControl: Double] = [:]) {
        storage = [:]
        for control in MusicalControl.allCases {
            self[control] = values[control] ?? MusicalIntent.defaultValue(for: control)
        }
    }

    package subscript(control: MusicalControl) -> Double {
        get { storage[control] ?? MusicalIntent.defaultValue(for: control) }
        set { storage[control] = min(max(newValue, control.minimum), 1) }
    }

    /// Returns the same semantic values with the generator's cross-control
    /// correlations restored. This is used after profile blending, where
    /// independent preference movement could otherwise create invalid role
    /// relationships.
    package func preservingCorrelations() -> MusicalIntent {
        var values = storage
        let darkness = self[.darkness]
        let atmosphere = min(self[.atmosphere], darkness + 0.25, 0.85)
        values[.atmosphere] = atmosphere
        values[.atmosphericDarkness] = min(self[.atmosphericDarkness], darkness + 0.2, 0.7)
        values[.aggression] = min(self[.aggression], max(0.15, 0.85 - atmosphere * 0.5))
        let overallChaos = self[.overallChaos]
        values[.drumChaos] = min(self[.drumChaos], overallChaos + 0.2)
        values[.synthChaos] = min(self[.synthChaos], overallChaos + 0.2)
        values[.textureChaos] = min(self[.textureChaos], overallChaos + 0.25)
        return MusicalIntent(values: values)
    }

    private static func defaultValue(for control: MusicalControl) -> Double {
        switch control {
        case .groove: 0.7
        case .beatShape: 0.15
        case .darkness, .hypnosis: 0.65
        case .machineTexture: 0.08
        case .drone: 0.28
        case .sequencerPresence: 0.0
        case .sequencerStyle: 0.0
        case .sequencerDensity: 0.32
        case .sequencerRegister: 0.35
        case .sequencerRepetition: 0.72
        case .sequencerDrift: 0.25
        case .sequencerDepth: 0.35
        case .overallChaos, .drumChaos, .synthChaos, .textureChaos: 0.15
        case .paceOfChange: 0.25
        default: 0.4
        }
    }

    /// Creates a random semantic intent with correlation constraints.
    /// - Parameter seed: Deterministic seed for reproducibility.
    /// - Returns: A `MusicalIntent` with all 17 controls sampled within
    ///   musically valid ranges, respecting cross-control invariants.
    package static func random(seed: UInt64) -> MusicalIntent {
        var random = SeededGenerator(seed: seed ^ 0xC5012F7A3E9B648D)
        var values: [MusicalControl: Double] = [:]

        // Motion branch
        let groove = random.value(in: 0.3...0.9)
        let syncopation = random.value(in: 0.0...0.75)
        let beatShape = random.value(in: 0.0...0.7)  // leans straight, full breakbeat rarer
        let polyrhythm = random.value(in: 0.0...0.5)

        // Character branch — correlated
        let baseDarkness = random.value(in: 0.3...0.88)
        // Atmosphere and darkness positively correlate
        let atmosphere = random.value(in: 0.05...min(0.85, baseDarkness + 0.25))
        let atmosphericDarkness = random.value(in: 0.0...min(0.7, baseDarkness + 0.2))
        let hypnosis = random.value(in: 0.3...0.85)
        // Aggression inversely correlates with atmosphere (harsh vs spacious)
        let aggression = random.value(in: 0.05...max(0.15, 0.85 - atmosphere * 0.5))
        let machineTexture = random.value(in: 0.0...0.55)
        let drone = random.value(in: 0.05...0.82)
        let sequencerPresence = random.value(in: 0.0...0.55)
        let sequencerStyle = Double(random.next() % 3) / 2.0
        let sequencerDensity = random.value(in: 0.12...0.58)
        let sequencerRegister = random.value(in: 0.15...0.75)
        let sequencerRepetition = random.value(in: 0.45...0.95)
        let sequencerDrift = random.value(in: 0.05...0.55)
        let sequencerDepth = random.value(in: 0.1...0.7)

        // Musicality branch
        let melodicity = random.value(in: 0.1...0.7)
        let synthPresence = random.value(in: 0.05...0.65)
        let noteActivity = random.value(in: 0.05...0.6)

        // Uncertainty branch — overall chaos amplifies individual chaos
        let overallChaos = random.value(in: 0.02...0.55)
        let drumChaos = min(1.0, random.value(in: 0.0...0.5) + overallChaos * 0.2)
        let synthChaos = min(1.0, random.value(in: 0.0...0.45) + overallChaos * 0.2)
        let textureChaos = min(1.0, random.value(in: 0.0...0.4) + overallChaos * 0.25)

        // Evolution branch
        let paceOfChange = random.value(in: 0.05...0.7)

        values[.groove] = groove
        values[.syncopation] = syncopation
        values[.beatShape] = beatShape
        values[.polyrhythm] = polyrhythm
        values[.darkness] = baseDarkness
        values[.atmosphere] = atmosphere
        values[.atmosphericDarkness] = atmosphericDarkness
        values[.hypnosis] = hypnosis
        values[.aggression] = aggression
        values[.machineTexture] = machineTexture
        values[.drone] = drone
        values[.sequencerPresence] = sequencerPresence
        values[.sequencerStyle] = sequencerStyle
        values[.sequencerDensity] = sequencerDensity
        values[.sequencerRegister] = sequencerRegister
        values[.sequencerRepetition] = sequencerRepetition
        values[.sequencerDrift] = sequencerDrift
        values[.sequencerDepth] = sequencerDepth
        values[.melodicity] = melodicity
        values[.synthPresence] = synthPresence
        values[.noteActivity] = noteActivity
        values[.overallChaos] = overallChaos
        values[.drumChaos] = drumChaos
        values[.synthChaos] = synthChaos
        values[.textureChaos] = textureChaos
        values[.paceOfChange] = paceOfChange

        return MusicalIntent(values: values)
    }

    /// Mutates coordinated semantic roles around an existing intent. This is
    /// intentionally not a raw-parameter randomizer: related controls share a
    /// bounded drift and the same cross-control correlations as `random(seed:)`
    /// are restored before the result is returned.
    package static func mutated(_ base: MusicalIntent, seed: UInt64, amount: Double = 0.14) -> MusicalIntent {
        var random = SeededGenerator(seed: seed ^ 0x6A09E667F3BCC909)
        let drift = min(max(amount, 0), 0.35)
        func role(_ controls: [MusicalControl], _ shared: Double) -> [MusicalControl: Double] {
            Dictionary(uniqueKeysWithValues: controls.map { control in
                (control, min(max(base[control] + shared + (random.value(in: -drift...drift) * 0.35), control.minimum), 1))
            })
        }

        var values: [MusicalControl: Double] = [:]
        values.merge(role([.groove, .syncopation, .beatShape, .polyrhythm], random.value(in: -drift...drift))) { _, new in new }
        values.merge(role([.darkness, .atmosphere, .atmosphericDarkness, .hypnosis, .machineTexture, .drone], random.value(in: -drift...drift))) { _, new in new }
        values.merge(role([.melodicity, .synthPresence, .noteActivity], random.value(in: -drift...drift))) { _, new in new }
        values.merge(role([.overallChaos, .drumChaos, .synthChaos, .textureChaos], random.value(in: -drift...drift))) { _, new in new }
        values[.aggression] = min(max(base[.aggression] + random.value(in: -drift...drift), 0), 1)
        values[.paceOfChange] = min(max(base[.paceOfChange] + random.value(in: -drift...drift), 0), 1)

        values[.atmosphere] = min(values[.atmosphere]!, values[.darkness]! + 0.25, 1)
        values[.atmosphericDarkness] = min(values[.atmosphericDarkness]!, values[.darkness]! + 0.2, 0.7)
        values[.aggression] = min(values[.aggression]!, max(0.15, 0.85 - values[.atmosphere]! * 0.5))
        values[.drumChaos] = min(1, values[.drumChaos]!, values[.overallChaos]! + 0.2)
        values[.synthChaos] = min(1, values[.synthChaos]!, values[.overallChaos]! + 0.2)
        values[.textureChaos] = min(1, values[.textureChaos]!, values[.overallChaos]! + 0.25)
        return MusicalIntent(values: values)
    }
}
