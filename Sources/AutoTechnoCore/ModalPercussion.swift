import Foundation

package enum ModalPercussionUse: String, CaseIterable, Codable, Sendable {
    case foundationCompanion = "foundation-companion"
    case sparsePercussion = "sparse-percussion"
}

/// A score-owned physical material for the existing tuned-percussion voice.
/// The cases are perceptual destinations inside the canonical renderer, not
/// alternate instruments or a user-selectable sound bank.
package enum ModalPercussionMaterial: String, CaseIterable, Codable, Sendable {
    case stretchedMembrane = "stretched-membrane"
    case hollowWood = "hollow-wood"
    case bronzePlate = "bronze-plate"
    case ceramicShell = "ceramic-shell"

    package init(rhythmLanguage: LongHorizonRhythmLanguage) {
        self = switch rhythmLanguage {
        case .fourOnFloor: .stretchedMembrane
        case .brokenGrid: .hollowWood
        case .crossPulse: .bronzePlate
        case .negativeSpace: .ceramicShell
        }
    }
}

/// Score-owned physical intent for an existing modal-percussion event. The
/// record adds no onset; it binds one surviving ensemble event to a bounded
/// modal pitch and one coherent material frame for the canonical renderer.
package struct ModalPercussionArticulation: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let step: Int
    package let use: ModalPercussionUse
    package let modalIdentity: ModalIdentity
    package let modalDegree: Int
    package let octave: Int
    package let fundamentalHz: Double
    package let excitation: Double
    package let damping: Double
    package let brightness: Double
    package let inharmonicity: Double
    package let eventIntensity: Double
    package let seed: UInt64
    package let material: ModalPercussionMaterial
    package let coupling: Double

    /// Modal percussion is intentionally neither a conventional harmonic
    /// voice nor indefinite noise: the fundamental remains in the scene mode
    /// while the physical model may spread upper partials inharmonically.
    package var musicalPitchIdentity: MusicalPitchIdentity {
        .tunedInharmonic
    }

    package init(
        scoreEventIndex: Int,
        step: Int,
        use: ModalPercussionUse,
        modalIdentity: ModalIdentity,
        modalDegree: Int,
        octave: Int,
        fundamentalHz: Double,
        excitation: Double,
        damping: Double,
        brightness: Double,
        inharmonicity: Double,
        eventIntensity: Double,
        seed: UInt64,
        material: ModalPercussionMaterial = .stretchedMembrane,
        coupling: Double = 0.18
    ) {
        self.scoreEventIndex = max(0, scoreEventIndex)
        self.step = Self.normalizedStep(step)
        self.use = use
        self.modalIdentity = modalIdentity
        self.modalDegree = modalDegree
        self.octave = octave
        self.fundamentalHz = Self.finiteClamp(
            fundamentalHz,
            neutral: 96,
            range: 48...196
        )
        self.excitation = Self.finiteClamp(excitation, neutral: 0.5, range: 0...1)
        self.damping = Self.finiteClamp(damping, neutral: 0.5, range: 0...1)
        self.brightness = Self.finiteClamp(brightness, neutral: 0.5, range: 0...1)
        self.inharmonicity = Self.finiteClamp(
            inharmonicity,
            neutral: 0,
            range: 0...0.12
        )
        self.eventIntensity = Self.finiteClamp(
            eventIntensity,
            neutral: 0.5,
            range: 0...1
        )
        self.seed = seed
        self.material = material
        self.coupling = Self.finiteClamp(coupling, neutral: 0.18, range: 0...0.6)
    }

    private static func normalizedStep(_ value: Int) -> Int {
        ((value % 16) + 16) % 16
    }

    private static func finiteClamp(
        _ value: Double,
        neutral: Double,
        range: ClosedRange<Double>
    ) -> Double {
        let finite = value.isFinite ? value : neutral
        return min(range.upperBound, max(range.lowerBound, finite))
    }
}

package enum ModalPercussionResolver {
    private static let foundationDomain: UInt64 = 0x4D4F44414C464E44
    private static let c1Hz = 32.703_195_662_574_83

    package static func foundationArticulations(
        ensemble: EnsembleContext,
        dna: SceneDNA,
        performance: PerformanceBar,
        character: PerformanceCharacter,
        gesture: ArrangementGesture,
        behavior: FoundationBehavior,
        rhythmLanguage: LongHorizonRhythmLanguage = .fourOnFloor,
        materialArchitecture: LongHorizonTimbralArchitecture = .hybrid
    ) -> [ModalPercussionArticulation] {
        guard behavior == .tunedPercussive,
              performance.roles.contains(.foundation),
              PerformanceCharacterContract.foundationIsCompatible(
                behavior,
                with: character
              ) else {
            return []
        }

        let events = ensemble.events.enumerated().filter {
            $0.element.voice == .tunedTom
        }.prefix(2)
        guard !events.isEmpty else { return [] }

        let macroPosition = normalizedStep(performance.bar)
        var degrees = dna.motif.degrees.map { requested in
            normalizedPitchClass(dna.nearestModalDegree(to: requested))
        }
        if degrees.isEmpty {
            degrees = [dna.modalDegrees.first ?? 0]
        }

        var firstDegree: Int?
        let physicalMaterial = ModalPercussionMaterial(
            rhythmLanguage: rhythmLanguage
        )
        return events.enumerated().map { ordinal, indexedEvent in
            var degree = degrees[ordinal % degrees.count]
            if ordinal == 1, degree == firstDegree {
                degree = nextDistinctDegree(
                    after: firstDegree ?? degree,
                    modalDegrees: dna.modalDegrees,
                    macroPosition: macroPosition
                )
            }
            if ordinal == 0 {
                firstDegree = degree
            }

            let pitch = foldedFoundationPitch(
                tonalCenter: dna.tonalCenter,
                modalDegree: degree
            )
            let scoreEventIndex = indexedEvent.offset
            let event = indexedEvent.element
            let seed = SceneDNA.derivedSeed(
                scene: dna.sceneSeed,
                domain: foundationDomain,
                index: performance.bar &* 16 &+ scoreEventIndex
            )
            let frame = materialFrame(
                seed: seed,
                character: character,
                gesture: gesture,
                macroPosition: macroPosition,
                eventIntensity: event.intensity
            )
            let coupling = materialCoupling(
                material: physicalMaterial,
                architecture: materialArchitecture,
                materialFrame: frame
            )

            return ModalPercussionArticulation(
                scoreEventIndex: scoreEventIndex,
                step: event.step,
                use: .foundationCompanion,
                modalIdentity: dna.modalIdentity,
                modalDegree: degree,
                octave: pitch.octave,
                fundamentalHz: pitch.frequency,
                excitation: 0.30 + frame * 0.60,
                damping: 0.85 - frame * 0.60,
                brightness: 0.18 + frame * 0.72,
                inharmonicity: 0.01 + frame * frame * 0.08,
                eventIntensity: event.intensity,
                seed: seed,
                material: physicalMaterial,
                coupling: coupling
            )
        }
    }

    private static func materialCoupling(
        material: ModalPercussionMaterial,
        architecture: LongHorizonTimbralArchitecture,
        materialFrame: Double
    ) -> Double {
        let materialBase: Double = switch material {
        case .stretchedMembrane: 0.14
        case .hollowWood: 0.26
        case .bronzePlate: 0.46
        case .ceramicShell: 0.34
        }
        let architectureOffset: Double = switch architecture {
        case .resonant: 0.05
        case .tonalMotion: -0.03
        case .spectral: 0.08
        case .hybrid: 0
        }
        return min(0.6, max(
            0,
            materialBase + architectureOffset + (materialFrame - 0.5) * 0.08
        ))
    }

    private static func materialFrame(
        seed: UInt64,
        character: PerformanceCharacter,
        gesture: ArrangementGesture,
        macroPosition: Int,
        eventIntensity: Double
    ) -> Double {
        let characterIndex = PerformanceCharacter.allCases.firstIndex(of: character) ?? 0
        let gestureIndex = ArrangementGesture.allCases.firstIndex(of: gesture) ?? 0
        let characterCoordinate = Double(characterIndex) /
            Double(max(1, PerformanceCharacter.allCases.count - 1))
        let gestureCoordinate = Double(gestureIndex) /
            Double(max(1, ArrangementGesture.allCases.count - 1))
        let macroCoordinate = Double(macroPosition) / 15
        let randomCoordinate = Double(seed >> 11) / 9_007_199_254_740_992
        let intensity = min(1, max(0, eventIntensity.isFinite ? eventIntensity : 0.5))
        return min(1, max(0,
            0.12 + characterCoordinate * 0.20 + gestureCoordinate * 0.16 +
                macroCoordinate * 0.18 + intensity * 0.24 + randomCoordinate * 0.10
        ))
    }

    private static func foldedFoundationPitch(
        tonalCenter: Int,
        modalDegree: Int
    ) -> (octave: Int, frequency: Double) {
        var octave = 1
        var frequency = c1Hz * pow(
            2,
            Double(tonalCenter + modalDegree + octave * 12) / 12
        )
        while frequency < 48 {
            octave += 1
            frequency *= 2
        }
        while frequency > 196 {
            octave -= 1
            frequency *= 0.5
        }
        return (octave, frequency)
    }

    private static func nextDistinctDegree(
        after degree: Int,
        modalDegrees: [Int],
        macroPosition: Int
    ) -> Int {
        guard modalDegrees.count > 1 else { return degree }
        let start = modalDegrees.firstIndex(of: degree) ?? 0
        let distance = 1 + macroPosition % (modalDegrees.count - 1)
        return modalDegrees[(start + distance) % modalDegrees.count]
    }

    private static func normalizedPitchClass(_ value: Int) -> Int {
        ((value % 12) + 12) % 12
    }

    private static func normalizedStep(_ value: Int) -> Int {
        ((value % 16) + 16) % 16
    }
}
