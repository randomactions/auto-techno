import Foundation

package enum MusicalTransformation: String, CaseIterable, Sendable {
    case `repeat`, omit, rotate, displace, fragment, answer, extend, restore
}

package enum PerformanceRole: String, CaseIterable, Sendable {
    case foundation, percussion, motif, response, atmosphere, transition
}

package enum ModalIdentity: String, CaseIterable, Sendable {
    case dorian
    case aeolian
    case phrygian

    package var degrees: [Int] {
        switch self {
        case .dorian: [0, 2, 3, 5, 7, 9, 10]
        case .aeolian: [0, 2, 3, 5, 7, 8, 10]
        case .phrygian: [0, 1, 3, 5, 7, 8, 10]
        }
    }
}

/// Phrase-scale low-end identity. The kick is always independent and remains
/// the physical anchor even when its companion changes or drops out.
package enum FoundationCompanion: String, CaseIterable, Sendable {
    case bass
    case monoRumble
    case tunedTom
    case empty
}

package enum PercussionGear: String, CaseIterable, Sendable {
    case anchor
    case lift
    case contrast
    case turnaround
}

/// Musical punctuation on the global sixteen-bar grid. These are arrangement
/// intentions, not exposed effect parameters.
package enum ArrangementGesture: String, CaseIterable, Sendable {
    case steady
    case gearShift
    case turnaround
    case minimalize
    case structuralMarker
}

package enum SignatureEvent: String, CaseIterable, Sendable {
    case displacedKickRecovery
    case delayedBassEntry
    case harmonicShadow
    case textureCollapse
    case alteredMotifAnswer
}

package struct RhythmCell: Equatable, Sendable {
    package let kickSteps: [Int]
    package let bassSteps: [Int]
    package let hatSteps: [Int]
    package let accentSteps: [Int]
    package let swingPercent: Double
}

package struct MotifCell: Equatable, Sendable {
    package let degrees: [Int]
    package let steps: [Int]
}

/// Stable musical identity for a scene. It is derived once, before rendering,
/// and deliberately contains no mutable DSP state.
package struct SceneDNA: Equatable, Sendable {
    package let sceneSeed: UInt64
    package let tonalCenter: Int
    package let modalIdentity: ModalIdentity
    package let modalDegrees: [Int]
    package let rhythm: RhythmCell
    package let motif: MotifCell
    package let characteristicSyncopations: [Int]
    package let foregroundPriority: [PerformanceRole]
    package let timbralFamily: Int
    package let foundationCompanion: FoundationCompanion

    package init(scene: TechnoScene) {
        sceneSeed = scene.seed
        var random = SeededGenerator(seed: Self.derivedSeed(scene: scene.seed, domain: 0xD1A, index: 0))
        tonalCenter = [0, 2, 5, 7, 10][Int(random.next() % 5)]
        let selectedModalIdentity: ModalIdentity
        if scene.darkness >= 0.70,
           Self.derivedSeed(scene: scene.seed, domain: 0xF2A61A, index: 0).isMultiple(of: 3) {
            selectedModalIdentity = .phrygian
        } else if scene.darkness > 0.58 {
            selectedModalIdentity = .aeolian
        } else {
            selectedModalIdentity = .dorian
        }
        let selectedModalDegrees = selectedModalIdentity.degrees
        modalIdentity = selectedModalIdentity
        modalDegrees = selectedModalDegrees

        let kicks = scene.steps.indices.filter { scene.steps[$0].kick }
        let hats = scene.steps.indices.filter { scene.steps[$0].hat }
        let candidates = (0..<16).filter { !kicks.contains($0) && ($0 % 4 == 2 || $0 % 4 == 3) }
        let bassCount = max(1, min(3, 1 + Int((scene.noteActivity * 2).rounded())))
        let bass = Array(candidates.sorted { lhs, rhs in
            Self.derivedSeed(scene: scene.seed, domain: 0xBA55, index: lhs) <
                Self.derivedSeed(scene: scene.seed, domain: 0xBA55, index: rhs)
        }.prefix(bassCount)).sorted()
        let accents = Array(hats.filter { $0 % 4 != 2 }.prefix(2))
        rhythm = RhythmCell(kickSteps: kicks, bassSteps: bass, hatSteps: hats, accentSteps: accents,
                            swingPercent: scene.groove.swingPercent)

        let sourceMotif = scene.motif.isEmpty
            ? [(step: 6, degree: 0)]
            : scene.motif.map { (step: $0.stepIndex, degree: $0.scaleDegree) }
        let motifDegrees = sourceMotif.map { source in
            Self.nearestModalDegree(to: source.degree, degrees: selectedModalDegrees)
        }
        motif = MotifCell(degrees: motifDegrees, steps: sourceMotif.map(\.step))
        characteristicSyncopations = Array(Set(bass + accents)).sorted()
        foregroundPriority = scene.melodicity > scene.drumChaos
            ? [.foundation, .motif, .percussion, .response, .atmosphere, .transition]
            : [.foundation, .percussion, .motif, .response, .atmosphere, .transition]
        timbralFamily = Int(random.next() % 4)
        let companions: [FoundationCompanion] = [.bass, .bass, .monoRumble, .tunedTom]
        let companionSeed = Self.derivedSeed(scene: scene.seed, domain: 0xF0A1DA710, index: 0)
        foundationCompanion = companions[Int(companionSeed % UInt64(companions.count))]
    }

    package static func derivedSeed(scene: UInt64, domain: UInt64, index: Int) -> UInt64 {
        var value = scene ^ (domain &* 0x9E3779B97F4A7C15) ^ UInt64(index &+ 1)
        value ^= value >> 30; value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27; value &*= 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    /// Resolves a requested upper-voice movement to the nearest pitch in the
    /// scene's stable modal vocabulary, including adjacent octaves.
    package func nearestModalDegree(to requested: Int) -> Int {
        Self.nearestModalDegree(to: requested, degrees: modalDegrees)
    }

    private static func nearestModalDegree(to requested: Int, degrees: [Int]) -> Int {
        let palette = (-1...3).flatMap { octave in
            degrees.map { $0 + octave * 12 }
        }
        return palette.min { lhs, rhs in
            let leftDistance = abs(lhs - requested)
            let rightDistance = abs(rhs - requested)
            return leftDistance == rightDistance ? lhs < rhs : leftDistance < rightDistance
        } ?? 0
    }
}

package struct PerformanceBar: Equatable, Sendable {
    package let bar: Int
    package let phrase: Int
    package let localBar: Int
    package let phraseLength: Int
    package let section: SectionKind
    package let tension: Double
    package let roles: [PerformanceRole]
    package let transformations: [MusicalTransformation]
    package let signatureEvent: SignatureEvent?
    package let eventSeed: UInt64
    /// Sixteen deterministic musical emphasis values. They describe phrasing,
    /// not gain knobs, and are consumed by several voices together.
    package let accentContour: [Double]

    package init(bar: Int, phrase: Int, localBar: Int, phraseLength: Int,
                section: SectionKind, tension: Double, roles: [PerformanceRole],
                transformations: [MusicalTransformation], signatureEvent: SignatureEvent?,
                eventSeed: UInt64, accentContour: [Double]) {
        self.bar = bar
        self.phrase = phrase
        self.localBar = localBar
        self.phraseLength = phraseLength
        self.section = section
        self.tension = min(1, max(0, tension))
        self.roles = roles
        self.transformations = transformations
        self.signatureEvent = signatureEvent
        self.eventSeed = eventSeed
        self.accentContour = accentContour
    }

    package func accent(at step: Int) -> Double {
        accentContour[((step % accentContour.count) + accentContour.count) % accentContour.count]
    }
}
