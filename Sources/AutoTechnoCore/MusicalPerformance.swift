import Foundation

package enum MusicalTransformation: String, CaseIterable, Sendable {
    case `repeat`, omit, rotate, displace, fragment, answer, extend, restore
}

package enum PerformanceRole: String, CaseIterable, Sendable {
    case foundation, percussion, motif, response, atmosphere, transition
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
    package let modalDegrees: [Int]
    package let rhythm: RhythmCell
    package let motif: MotifCell
    package let characteristicSyncopations: [Int]
    package let foregroundPriority: [PerformanceRole]
    package let timbralFamily: Int

    package init(scene: TechnoScene) {
        sceneSeed = scene.seed
        var random = SeededGenerator(seed: Self.derivedSeed(scene: scene.seed, domain: 0xD1A, index: 0))
        tonalCenter = [0, 2, 5, 7, 10][Int(random.next() % 5)]
        modalDegrees = scene.darkness > 0.58 ? [0, 2, 3, 5, 7, 8, 10] : [0, 2, 3, 5, 7, 9, 10]

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
        motif = MotifCell(degrees: sourceMotif.map(\.degree), steps: sourceMotif.map(\.step))
        characteristicSyncopations = Array(Set(bass + accents)).sorted()
        foregroundPriority = scene.melodicity > scene.drumChaos
            ? [.foundation, .motif, .percussion, .response, .atmosphere, .transition]
            : [.foundation, .percussion, .motif, .response, .atmosphere, .transition]
        timbralFamily = Int(random.next() % 4)
    }

    package static func derivedSeed(scene: UInt64, domain: UInt64, index: Int) -> UInt64 {
        var value = scene ^ (domain &* 0x9E3779B97F4A7C15) ^ UInt64(index &+ 1)
        value ^= value >> 30; value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27; value &*= 0x94D049BB133111EB
        return value ^ (value >> 31)
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
