import Foundation

public enum DramaticThesis: String, CaseIterable, Sendable {
    case slowAccumulation
    case falseReturn
    case pressureAndRelease
    case hypnoticLock
    case controlledErosion
}

public enum MusicalTransformation: String, CaseIterable, Sendable {
    case `repeat`, omit, rotate, displace, fragment, answer, extend, restore
}

public enum PerformanceRole: String, CaseIterable, Sendable {
    case foundation, percussion, motif, response, atmosphere, transition
}

public enum SignatureEvent: String, CaseIterable, Sendable {
    case displacedKickRecovery
    case delayedBassEntry
    case harmonicShadow
    case textureCollapse
    case alteredMotifAnswer
}

public struct RhythmCell: Equatable, Sendable {
    public let kickSteps: [Int]
    public let bassSteps: [Int]
    public let hatSteps: [Int]
    public let accentSteps: [Int]
    public let swingPercent: Double
}

public struct MotifCell: Equatable, Sendable {
    public let degrees: [Int]
    public let steps: [Int]
}

/// Stable musical identity for a scene. It is derived once, before rendering,
/// and deliberately contains no mutable DSP state.
public struct SceneDNA: Equatable, Sendable {
    public let sceneSeed: UInt64
    public let tonalCenter: Int
    public let modalDegrees: [Int]
    public let rhythm: RhythmCell
    public let motif: MotifCell
    public let characteristicSyncopations: [Int]
    public let foregroundPriority: [PerformanceRole]
    public let timbralFamily: Int

    public init(scene: TechnoScene) {
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

    public static func derivedSeed(scene: UInt64, domain: UInt64, index: Int) -> UInt64 {
        var value = scene ^ (domain &* 0x9E3779B97F4A7C15) ^ UInt64(index &+ 1)
        value ^= value >> 30; value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27; value &*= 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

public struct PerformancePhrase: Equatable, Sendable {
    public let index: Int
    public let startBar: Int
    public let barCount: Int
    public let section: SectionKind
    public let tensionStart: Double
    public let tensionEnd: Double
}

public struct PerformanceBar: Equatable, Sendable {
    public let bar: Int
    public let phrase: Int
    public let localBar: Int
    public let phraseLength: Int
    public let section: SectionKind
    public let tension: Double
    public let roles: [PerformanceRole]
    public let transformations: [MusicalTransformation]
    public let signatureEvent: SignatureEvent?
    public let eventSeed: UInt64
    /// Sixteen deterministic musical emphasis values. They describe phrasing,
    /// not gain knobs, and are consumed by several voices together.
    public let accentContour: [Double]

    public init(bar: Int, phrase: Int, localBar: Int, phraseLength: Int,
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

    public func accent(at step: Int) -> Double {
        accentContour[((step % accentContour.count) + accentContour.count) % accentContour.count]
    }
}

/// Immutable phrase-aware score consumed by the offline renderer.
public struct PerformancePlan: Equatable, Sendable {
    public static let barCount = 32
    public let dna: SceneDNA
    public let thesis: DramaticThesis
    public let phrases: [PerformancePhrase]
    public let bars: [PerformanceBar]

    public init(scene: TechnoScene) {
        let dna = SceneDNA(scene: scene)
        self.dna = dna
        thesis = DramaticThesis.allCases[Int(SceneDNA.derivedSeed(scene: scene.seed, domain: 0x7E515, index: 0) % UInt64(DramaticThesis.allCases.count))]

        let phraseLengths = Self.phraseLengths(seed: scene.seed, pace: scene.musicalIntent?[.paceOfChange] ?? 0.25)
        var phraseList: [PerformancePhrase] = []
        var cursor = 0
        for (index, length) in phraseLengths.enumerated() {
            let progress = Double(cursor) / Double(Self.barCount)
            let section = Self.section(thesis: thesis, phrase: index, progress: progress, final: cursor + length == Self.barCount)
            let tension = Self.tension(thesis: thesis, progress: progress)
            let end = Self.tension(thesis: thesis, progress: Double(cursor + length - 1) / Double(Self.barCount - 1))
            phraseList.append(PerformancePhrase(index: index, startBar: cursor, barCount: length, section: section,
                                                tensionStart: tension, tensionEnd: end))
            cursor += length
        }
        phrases = phraseList

        var barList: [PerformanceBar] = []
        for phrase in phraseList {
            for localBar in 0..<phrase.barCount {
                let bar = phrase.startBar + localBar
                let amount = phrase.barCount == 1 ? 1 : Double(localBar) / Double(phrase.barCount - 1)
                let tension = phrase.tensionStart + (phrase.tensionEnd - phrase.tensionStart) * amount
                let transformations = Self.transformations(phrase: phrase, localBar: localBar, thesis: thesis, seed: scene.seed)
                let signature = Self.signatureEvent(bar: bar, phrase: phrase, localBar: localBar, thesis: thesis, seed: scene.seed)
                let roles = Self.roles(dna: dna, section: phrase.section, tension: tension, transformations: transformations)
                let contour = Self.accentContour(dna: dna, phrase: phrase, localBar: localBar, tension: tension,
                                                 seed: scene.seed)
                barList.append(PerformanceBar(bar: bar, phrase: phrase.index, localBar: localBar,
                                              phraseLength: phrase.barCount, section: phrase.section, tension: tension,
                                              roles: roles, transformations: transformations, signatureEvent: signature,
                                              eventSeed: SceneDNA.derivedSeed(scene: scene.seed, domain: UInt64(phrase.index + 1), index: localBar),
                                              accentContour: contour))
            }
        }
        bars = barList
    }

    private static func phraseLengths(seed: UInt64, pace: Double) -> [Int] {
        var random = SeededGenerator(seed: SceneDNA.derivedSeed(scene: seed, domain: 0xF4A5E, index: 0))
        let palette = pace > 0.55 ? [4, 5, 6, 7] : [5, 6, 7, 8]
        var result: [Int] = []
        var remaining = barCount
        while remaining > 0 {
            if remaining <= 8 { result.append(remaining); break }
            let selected = palette[Int(random.next() % UInt64(palette.count))]
            result.append(min(selected, remaining - 4))
            remaining -= result.last!
        }
        return result
    }

    private static func section(thesis: DramaticThesis, phrase: Int, progress: Double, final: Bool) -> SectionKind {
        if final { return .returnSection }
        switch thesis {
        case .slowAccumulation: return progress < 0.42 ? .groove : (progress < 0.72 ? .build : .breakdown)
        case .falseReturn: return phrase == 0 ? .groove : (phrase == 2 ? .returnSection : (progress < 0.72 ? .build : .breakdown))
        case .pressureAndRelease: return progress < 0.28 ? .groove : (progress < 0.62 ? .build : .breakdown)
        case .hypnoticLock: return progress < 0.55 ? .groove : (progress < 0.78 ? .breakdown : .build)
        case .controlledErosion: return progress < 0.35 ? .groove : (progress < 0.76 ? .breakdown : .build)
        }
    }

    private static func tension(thesis: DramaticThesis, progress: Double) -> Double {
        let p = min(1, max(0, progress))
        switch thesis {
        case .slowAccumulation: return 0.24 + p * 0.62
        case .falseReturn: return min(0.92, 0.30 + p * 0.48 + (p > 0.42 && p < 0.62 ? -0.22 : 0))
        case .pressureAndRelease: return p < 0.64 ? 0.28 + p * 0.92 : 0.82 - (p - 0.64) * 1.25
        case .hypnoticLock: return 0.42 + sin(p * .pi * 4) * 0.08 + p * 0.16
        case .controlledErosion: return 0.72 - p * 0.40 + (p > 0.78 ? (p - 0.78) * 1.6 : 0)
        }
    }

    private static func transformations(phrase: PerformancePhrase, localBar: Int, thesis: DramaticThesis, seed: UInt64) -> [MusicalTransformation] {
        if localBar == 0 && phrase.index > 0 { return phrase.section == .returnSection ? [.restore] : [.`repeat`] }
        if localBar == phrase.barCount - 1 { return phrase.section == .breakdown ? [.fragment] : [.extend] }
        let roll = SceneDNA.derivedSeed(scene: seed, domain: UInt64(phrase.index + 0x71), index: localBar) % 100
        if roll < 58 { return [.`repeat`] }
        if roll < 72 { return [.omit] }
        if roll < 84 { return [.rotate] }
        if roll < 93 { return [.displace] }
        return thesis == .falseReturn ? [.answer] : [.fragment]
    }

    private static func signatureEvent(bar: Int, phrase: PerformancePhrase, localBar: Int, thesis: DramaticThesis, seed: UInt64) -> SignatureEvent? {
        guard localBar == phrase.barCount - 1, phrase.index > 0 else { return nil }
        let roll = SceneDNA.derivedSeed(scene: seed, domain: 0x519A, index: bar) % 100
        guard roll < 24 else { return nil }
        let thesisIndex = DramaticThesis.allCases.firstIndex(of: thesis) ?? 0
        return SignatureEvent.allCases[Int((roll + UInt64(thesisIndex)) % UInt64(SignatureEvent.allCases.count))]
    }

    private static func roles(dna: SceneDNA, section: SectionKind, tension: Double,
                              transformations: [MusicalTransformation]) -> [PerformanceRole] {
        var eligible: Set<PerformanceRole> = [.foundation]
        if section != .breakdown { eligible.insert(.percussion) }
        if section != .breakdown || transformations.contains(.fragment) { eligible.insert(.motif) }
        if section == .build || section == .returnSection { eligible.insert(.response) }
        if section == .breakdown || tension > 0.55 { eligible.insert(.atmosphere) }
        if tension > 0.76 { eligible.insert(.transition) }

        var selected: [PerformanceRole] = [.foundation]
        if section == .breakdown { selected.append(.atmosphere) }
        if tension > 0.76 { selected.append(.transition) }
        for role in dna.foregroundPriority where eligible.contains(role) && !selected.contains(role) && selected.count < 4 {
            selected.append(role)
        }
        return selected
    }

    private static func accentContour(dna: SceneDNA, phrase: PerformancePhrase, localBar: Int,
                                      tension: Double, seed: UInt64) -> [Double] {
        (0..<16).map { step in
            let quarter = step.isMultiple(of: 4) ? 0.10 : 0
            let offbeat = step % 4 == 2 ? 0.055 : 0
            let signature = dna.rhythm.accentSteps.contains(step) ? 0.09 : 0
            let phraseLift = localBar == phrase.barCount - 1 && step >= 12 ? tension * 0.10 : 0
            let jitterSeed = SceneDNA.derivedSeed(scene: seed, domain: UInt64(phrase.index + 0xACC), index: localBar * 16 + step)
            let micro = (Double(jitterSeed % 1_001) / 1_000 - 0.5) * 0.055
            return min(1.18, max(0.78, 0.90 + quarter + offbeat + signature + phraseLift + micro))
        }
    }
}
