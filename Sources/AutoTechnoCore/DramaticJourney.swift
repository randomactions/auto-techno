import Foundation

/// A long-form dramatic phase. These are listener-scale musical situations,
/// not synonyms for individual DSP operations.
public enum DramaticPhase: String, CaseIterable, Sendable {
    case establish
    case firstPressure
    case falseReturn
    case deepeningLock
    case subtraction
    case finalPressure
    case earnedReturn
    case afterglow
}

public enum TensionDimension: String, CaseIterable, Sendable {
    case lowEndUncertainty
    case rhythmicExpectation
    case spectralPressure
    case harmonicInstability
    case density
    case spatialDistance
    case motifIncompletion
}

/// Independent musical sources of tension. The vector prevents the director
/// from treating every build as one generic "more" curve.
public struct TensionVector: Equatable, Sendable {
    public let lowEndUncertainty: Double
    public let rhythmicExpectation: Double
    public let spectralPressure: Double
    public let harmonicInstability: Double
    public let density: Double
    public let spatialDistance: Double
    public let motifIncompletion: Double

    public init(lowEndUncertainty: Double, rhythmicExpectation: Double,
                spectralPressure: Double, harmonicInstability: Double,
                density: Double, spatialDistance: Double,
                motifIncompletion: Double) {
        self.lowEndUncertainty = Self.clamp(lowEndUncertainty)
        self.rhythmicExpectation = Self.clamp(rhythmicExpectation)
        self.spectralPressure = Self.clamp(spectralPressure)
        self.harmonicInstability = Self.clamp(harmonicInstability)
        self.density = Self.clamp(density)
        self.spatialDistance = Self.clamp(spatialDistance)
        self.motifIncompletion = Self.clamp(motifIncompletion)
    }

    public subscript(_ dimension: TensionDimension) -> Double {
        switch dimension {
        case .lowEndUncertainty: lowEndUncertainty
        case .rhythmicExpectation: rhythmicExpectation
        case .spectralPressure: spectralPressure
        case .harmonicInstability: harmonicInstability
        case .density: density
        case .spatialDistance: spatialDistance
        case .motifIncompletion: motifIncompletion
        }
    }

    /// Density contributes less than expectation and withheld foundation: a
    /// sparse breakdown can therefore be more tense than a busy groove.
    public var overall: Double {
        Self.clamp(
            lowEndUncertainty * 0.20 + rhythmicExpectation * 0.20 +
            spectralPressure * 0.17 + harmonicInstability * 0.12 +
            density * 0.08 + spatialDistance * 0.11 + motifIncompletion * 0.12
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

public enum DramaticDebtKind: String, CaseIterable, Sendable {
    case rhythmicSuspension
    case motifIncompletion
    case lowEndWithdrawal
    case spatialDistance
    case spectralPressure
}

public enum DramaticPayoffKind: String, CaseIterable, Sendable {
    case partialRhythmicReturn
    case foundationReturn
    case downbeatLock
    case dryImpact
    case pressureCollapse
    case motifResolution
}

/// A deterministic promise opened by the arrangement and paid later. IDs are
/// score-local integers so the same seed always produces identical evidence.
public struct DramaticDebt: Equatable, Sendable {
    public let id: Int
    public let kind: DramaticDebtKind
    public let openedAtBar: Int
    public let dueAtBar: Int
    public let magnitude: Double

    public init(id: Int, kind: DramaticDebtKind, openedAtBar: Int,
                dueAtBar: Int, magnitude: Double) {
        self.id = id
        self.kind = kind
        self.openedAtBar = openedAtBar
        self.dueAtBar = dueAtBar
        self.magnitude = min(1, max(0, magnitude))
    }

    public func isActive(at bar: Int) -> Bool {
        bar >= openedAtBar && bar < dueAtBar
    }
}

public struct DramaticPayoff: Equatable, Sendable {
    public let debtID: Int
    public let kind: DramaticPayoffKind
    public let bar: Int
    public let magnitude: Double

    public init(debtID: Int, kind: DramaticPayoffKind, bar: Int, magnitude: Double) {
        self.debtID = debtID
        self.kind = kind
        self.bar = bar
        self.magnitude = min(1, max(0, magnitude))
    }
}

/// One authored procedural instrument. Scene DNA selects a bounded variation,
/// while the topology and its musical purpose remain stable and inspectable.
public struct InstrumentPatchDNA: Equatable, Sendable {
    public enum Family: String, CaseIterable, Sendable {
        case shadowPressure
    }

    public let family: Family
    public let variation: Int
    public let sawMix: Double
    public let pulseMix: Double
    public let subMix: Double
    public let fifthMix: Double
    public let detuneCents: Double
    public let baseCutoff: Double
    public let cutoffRange: Double
    public let baseResonance: Double
    public let drive: Double
    public let attackSeconds: Double
    public let decaySeconds: Double
    public let sustain: Double
    public let releaseSeconds: Double
    public let glideSeconds: Double

    public init(scene: TechnoScene, dna: SceneDNA) {
        family = .shadowPressure
        variation = dna.timbralFamily
        let variants: [(Double, Double, Double, Double, Double)] = [
            (0.46, 0.28, 0.12, 0.04, 5.5),
            (0.34, 0.42, 0.14, 0.03, 7.0),
            (0.42, 0.22, 0.18, 0.08, 4.0),
            (0.31, 0.31, 0.16, 0.12, 8.5),
        ]
        let selected = variants[variation % variants.count]
        sawMix = selected.0
        pulseMix = selected.1
        subMix = selected.2
        fifthMix = selected.3
        detuneCents = selected.4
        baseCutoff = 150 + (1 - scene.darkness) * 190
        cutoffRange = 1_050 + scene.synthPresence * 1_450
        baseResonance = 0.18 + scene.hypnosis * 0.22
        drive = 1.25 + scene.aggression * 0.75
        attackSeconds = 0.008 + scene.atmosphere * 0.012
        decaySeconds = 0.18 + scene.hypnosis * 0.18
        sustain = 0.38 + scene.hypnosis * 0.20
        releaseSeconds = 0.08 + scene.atmosphere * 0.24
        glideSeconds = 0.010 + scene.hypnosis * 0.035
    }
}

/// Semantic movement of the authored instrument during one bar. These values
/// coordinate oscillator, filter, envelope and effect behavior in the DSP
/// layer; none is exposed as a raw primary control.
public struct PatchMacroState: Equatable, Sendable {
    public let pressure: Double
    public let motion: Double
    public let bite: Double
    public let decay: Double
    public let distance: Double
    public let instability: Double
    public let impact: Double

    public init(pressure: Double, motion: Double, bite: Double, decay: Double,
                distance: Double, instability: Double, impact: Double) {
        self.pressure = Self.clamp(pressure)
        self.motion = Self.clamp(motion)
        self.bite = Self.clamp(bite)
        self.decay = Self.clamp(decay)
        self.distance = Self.clamp(distance)
        self.instability = Self.clamp(instability)
        self.impact = Self.clamp(impact)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

public struct DramaticJourneyBar: Equatable, Sendable {
    public let bar: Int
    public let phase: DramaticPhase
    public let section: SectionKind
    public let tension: TensionVector
    public let activeDebts: [DramaticDebt]
    public let payoffs: [DramaticPayoff]
    public let roles: [PerformanceRole]
    public let transformations: [MusicalTransformation]
    public let eventSeed: UInt64
    public let accentContour: [Double]
    public let patchMacros: PatchMacroState

    public var payoffStrength: Double {
        payoffs.map(\.magnitude).max() ?? 0
    }

    public var lowEndPresence: Double {
        if payoffs.contains(where: { $0.kind == .foundationReturn }) { return 1 }
        return max(0.06, 1 - pow(tension.lowEndUncertainty, 1.15))
    }

    public var kickPresence: Double {
        if payoffs.contains(where: { $0.kind == .foundationReturn || $0.kind == .downbeatLock }) { return 1 }
        if phase == .finalPressure && bar >= 76 { return 0.16 }
        return max(0.48, 1 - tension.lowEndUncertainty * 0.42)
    }

    public var hasDryImpact: Bool {
        payoffs.contains { $0.kind == .dryImpact }
    }

    public func performanceBar() -> PerformanceBar {
        let signature: SignatureEvent? = payoffs.contains(where: { $0.kind == .motifResolution })
            ? .alteredMotifAnswer : nil
        return PerformanceBar(
            bar: bar,
            phrase: bar / 8,
            localBar: bar % 8,
            phraseLength: 8,
            section: section,
            tension: tension.overall,
            roles: roles,
            transformations: transformations,
            signatureEvent: signature,
            eventSeed: eventSeed,
            accentContour: accentContour
        )
    }
}

/// A 96-bar pressure-and-release proof. Planning is pure, deterministic and
/// performed before rendering; no score work belongs on an audio callback.
public struct DramaticJourneyPlan: Equatable, Sendable {
    public static let barCount = 96
    public let dna: SceneDNA
    public let patch: InstrumentPatchDNA
    public let debts: [DramaticDebt]
    public let payoffs: [DramaticPayoff]
    public let bars: [DramaticJourneyBar]

    public init(scene: TechnoScene) {
        let dna = SceneDNA(scene: scene)
        self.dna = dna
        patch = InstrumentPatchDNA(scene: scene, dna: dna)

        let seedMotion = Double(SceneDNA.derivedSeed(scene: scene.seed, domain: 0xDEB7, index: 0) % 1_001) / 1_000
        let majorScale = 0.94 + (seedMotion - 0.5) * 0.08
        let debtList = [
            DramaticDebt(id: 0, kind: .rhythmicSuspension, openedAtBar: 16, dueAtBar: 24, magnitude: 0.38),
            DramaticDebt(id: 1, kind: .motifIncompletion, openedAtBar: 32, dueAtBar: 84, magnitude: 0.68),
            DramaticDebt(id: 2, kind: .spatialDistance, openedAtBar: 48, dueAtBar: 80, magnitude: 0.74 * majorScale),
            DramaticDebt(id: 3, kind: .lowEndWithdrawal, openedAtBar: 52, dueAtBar: 80, magnitude: 0.90 * majorScale),
            DramaticDebt(id: 4, kind: .spectralPressure, openedAtBar: 64, dueAtBar: 80, magnitude: 0.88 * majorScale),
            DramaticDebt(id: 5, kind: .rhythmicSuspension, openedAtBar: 72, dueAtBar: 80, magnitude: 0.84 * majorScale),
        ]
        let payoffList = [
            DramaticPayoff(debtID: 0, kind: .partialRhythmicReturn, bar: 24, magnitude: 0.38),
            DramaticPayoff(debtID: 2, kind: .dryImpact, bar: 80, magnitude: 0.74 * majorScale),
            DramaticPayoff(debtID: 3, kind: .foundationReturn, bar: 80, magnitude: 0.90 * majorScale),
            DramaticPayoff(debtID: 4, kind: .pressureCollapse, bar: 80, magnitude: 0.88 * majorScale),
            DramaticPayoff(debtID: 5, kind: .downbeatLock, bar: 80, magnitude: 0.84 * majorScale),
            DramaticPayoff(debtID: 1, kind: .motifResolution, bar: 84, magnitude: 0.68),
        ]

        debts = debtList
        payoffs = payoffList
        bars = (0..<Self.barCount).map { bar in
            let phase = Self.phase(at: bar)
            let phaseProgress = Self.progress(in: phase, bar: bar)
            let tension = Self.tension(phase: phase, progress: phaseProgress, scene: scene)
            let currentPayoffs = payoffList.filter { $0.bar == bar }
            let activeDebts = debtList.filter { $0.isActive(at: bar) }
            let section = Self.section(phase: phase, bar: bar)
            let transformations = Self.transformations(phase: phase, bar: bar, seed: scene.seed)
            let roles = Self.roles(phase: phase, tension: tension, transformations: transformations)
            let impact = currentPayoffs.map(\.magnitude).max() ?? 0
            let macros = PatchMacroState(
                pressure: tension.spectralPressure * 0.58 + tension.rhythmicExpectation * 0.42,
                motion: min(1, scene.hypnosis * 0.58 + tension.density * 0.22 + tension.harmonicInstability * 0.20),
                bite: min(1, scene.aggression * 0.48 + tension.spectralPressure * 0.34 + impact * 0.30),
                decay: min(1, 0.34 + scene.hypnosis * 0.34 + (1 - tension.density) * 0.18),
                distance: currentPayoffs.contains(where: { $0.kind == .dryImpact }) ? 0.08 : tension.spatialDistance,
                instability: tension.harmonicInstability,
                impact: impact
            )
            return DramaticJourneyBar(
                bar: bar,
                phase: phase,
                section: section,
                tension: tension,
                activeDebts: activeDebts,
                payoffs: currentPayoffs,
                roles: roles,
                transformations: transformations,
                eventSeed: SceneDNA.derivedSeed(scene: scene.seed, domain: 0x96BA, index: bar),
                accentContour: Self.accentContour(dna: dna, bar: bar, tension: tension, impact: impact,
                                                  seed: scene.seed),
                patchMacros: macros
            )
        }
    }

    public var unpaidDebtIDs: [Int] {
        let paid = Set(payoffs.map(\.debtID))
        return debts.map(\.id).filter { !paid.contains($0) }
    }

    private static func phase(at bar: Int) -> DramaticPhase {
        switch bar {
        case 0..<16: .establish
        case 16..<24: .firstPressure
        case 24..<32: .falseReturn
        case 32..<48: .deepeningLock
        case 48..<64: .subtraction
        case 64..<80: .finalPressure
        case 80..<88: .earnedReturn
        default: .afterglow
        }
    }

    private static func progress(in phase: DramaticPhase, bar: Int) -> Double {
        let range: Range<Int>
        switch phase {
        case .establish: range = 0..<16
        case .firstPressure: range = 16..<24
        case .falseReturn: range = 24..<32
        case .deepeningLock: range = 32..<48
        case .subtraction: range = 48..<64
        case .finalPressure: range = 64..<80
        case .earnedReturn: range = 80..<88
        case .afterglow: range = 88..<96
        }
        return Double(bar - range.lowerBound) / Double(max(1, range.count - 1))
    }

    private static func tension(phase: DramaticPhase, progress p: Double,
                                scene: TechnoScene) -> TensionVector {
        let shadow = scene.darkness
        let hypnosis = scene.hypnosis
        switch phase {
        case .establish:
            return TensionVector(lowEndUncertainty: 0.06, rhythmicExpectation: 0.12 + p * 0.13,
                                 spectralPressure: 0.16 + p * 0.12, harmonicInstability: 0.08 + shadow * 0.08,
                                 density: 0.46 + p * 0.10, spatialDistance: 0.15 + hypnosis * 0.08,
                                 motifIncompletion: 0.08 + p * 0.08)
        case .firstPressure:
            return TensionVector(lowEndUncertainty: 0.12 + p * 0.12, rhythmicExpectation: 0.38 + p * 0.38,
                                 spectralPressure: 0.34 + p * 0.36, harmonicInstability: 0.18 + p * 0.20,
                                 density: 0.58 + p * 0.20, spatialDistance: 0.24 + p * 0.18,
                                 motifIncompletion: 0.20 + p * 0.20)
        case .falseReturn:
            return TensionVector(lowEndUncertainty: 0.16 + p * 0.08, rhythmicExpectation: 0.30 + p * 0.14,
                                 spectralPressure: 0.28 + p * 0.12, harmonicInstability: 0.16 + p * 0.10,
                                 density: 0.66 - p * 0.08, spatialDistance: 0.20 + p * 0.10,
                                 motifIncompletion: 0.30 + p * 0.18)
        case .deepeningLock:
            return TensionVector(lowEndUncertainty: 0.18 + p * 0.16, rhythmicExpectation: 0.34 + p * 0.20,
                                 spectralPressure: 0.30 + p * 0.24, harmonicInstability: 0.22 + p * 0.22,
                                 density: 0.54 + sin(p * .pi) * 0.14, spatialDistance: 0.30 + p * 0.18,
                                 motifIncompletion: 0.42 + p * 0.28)
        case .subtraction:
            return TensionVector(lowEndUncertainty: 0.38 + p * 0.44, rhythmicExpectation: 0.44 + p * 0.18,
                                 spectralPressure: 0.46 + p * 0.16, harmonicInstability: 0.38 + p * 0.18,
                                 density: 0.48 - p * 0.22, spatialDistance: 0.48 + p * 0.34,
                                 motifIncompletion: 0.66 + p * 0.18)
        case .finalPressure:
            return TensionVector(lowEndUncertainty: 0.72 + p * 0.24, rhythmicExpectation: 0.64 + p * 0.34,
                                 spectralPressure: 0.60 + p * 0.38, harmonicInstability: 0.48 + p * 0.26,
                                 density: 0.38 + p * 0.52, spatialDistance: 0.68 + p * 0.26,
                                 motifIncompletion: 0.78 + p * 0.18)
        case .earnedReturn:
            return TensionVector(lowEndUncertainty: 0.02 + p * 0.05, rhythmicExpectation: 0.10 + p * 0.10,
                                 spectralPressure: 0.20 + p * 0.10, harmonicInstability: 0.12 + p * 0.08,
                                 density: 0.76 - p * 0.06, spatialDistance: 0.12 + p * 0.10,
                                 motifIncompletion: p < 0.55 ? 0.28 : 0.06)
        case .afterglow:
            return TensionVector(lowEndUncertainty: 0.06, rhythmicExpectation: 0.18 + p * 0.08,
                                 spectralPressure: 0.25 + p * 0.08, harmonicInstability: 0.15 + shadow * 0.08,
                                 density: 0.66 - p * 0.08, spatialDistance: 0.20 + hypnosis * 0.08,
                                 motifIncompletion: 0.08 + p * 0.08)
        }
    }

    private static func section(phase: DramaticPhase, bar: Int) -> SectionKind {
        switch phase {
        case .establish, .deepeningLock: .groove
        case .firstPressure, .finalPressure: .build
        case .falseReturn, .earnedReturn, .afterglow: .returnSection
        case .subtraction: .breakdown
        }
    }

    private static func transformations(phase: DramaticPhase, bar: Int,
                                        seed: UInt64) -> [MusicalTransformation] {
        if bar == 24 { return [.answer] }
        if bar == 80 { return [.restore, .extend] }
        if bar == 84 { return [.answer] }
        switch phase {
        case .subtraction:
            return bar % 4 == 3 ? [.omit] : [.fragment]
        case .finalPressure:
            return bar % 4 == 3 ? [.displace, .extend] : [.`repeat`]
        case .deepeningLock:
            let roll = SceneDNA.derivedSeed(scene: seed, domain: 0x10C4, index: bar) % 4
            return roll == 0 ? [.rotate] : [.`repeat`]
        default:
            return [.`repeat`]
        }
    }

    private static func roles(phase: DramaticPhase, tension: TensionVector,
                              transformations: [MusicalTransformation]) -> [PerformanceRole] {
        var result: [PerformanceRole] = [.foundation]
        if phase != .subtraction && tension.density > 0.42 { result.append(.percussion) }
        if !transformations.contains(.omit) { result.append(.motif) }
        if phase == .firstPressure || phase == .falseReturn || phase == .earnedReturn { result.append(.response) }
        if tension.rhythmicExpectation > 0.72 && result.count < 4 { result.append(.transition) }
        if (phase == .subtraction || tension.spatialDistance > 0.46) && result.count < 4 { result.append(.atmosphere) }
        return Array(result.prefix(4))
    }

    private static func accentContour(dna: SceneDNA, bar: Int, tension: TensionVector,
                                      impact: Double, seed: UInt64) -> [Double] {
        (0..<16).map { step in
            let anchor = step.isMultiple(of: 4) ? 0.08 + impact * 0.12 : 0
            let syncopation = dna.characteristicSyncopations.contains(step) ? tension.rhythmicExpectation * 0.08 : 0
            let phraseLift = bar % 8 == 7 && step >= 12 ? tension.rhythmicExpectation * 0.10 : 0
            let jitterSeed = SceneDNA.derivedSeed(scene: seed, domain: 0xACC96, index: bar * 16 + step)
            let micro = (Double(jitterSeed % 1_001) / 1_000 - 0.5) * 0.035
            return min(1.24, max(0.76, 0.90 + anchor + syncopation + phraseLift + micro))
        }
    }
}
