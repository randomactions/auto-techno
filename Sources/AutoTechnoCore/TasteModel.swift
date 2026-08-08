import Foundation

public struct TastePreference: Codable, Equatable, Sendable {
    public var preferredValue: Double
    public var confidence: Double

    public init(preferredValue: Double, confidence: Double = 0) {
        self.preferredValue = preferredValue
        self.confidence = confidence
    }
}

/// Interpretable, local evidence about the listener's preferred semantic space.
public struct TasteProfile: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public let version: Int
    public private(set) var preferences: [MusicalControl: TastePreference]
    public private(set) var observations: [TasteObservation]

    public init(version: Int = currentVersion, preferences: [MusicalControl: TastePreference] = [:], observations: [TasteObservation] = []) {
        self.version = version
        self.preferences = preferences
        self.observations = observations
    }

    public var observationCount: Int {
        guard !preferences.isEmpty else { return 0 }
        // One selection contributes confidence to every semantic control.
        // Report the per-control average so the UI shows choices, not 17x
        // the number of choices.
        return Int((preferences.values.reduce(0) { $0 + $1.confidence } / Double(preferences.count)).rounded())
    }

    public func preference(for control: MusicalControl) -> TastePreference? {
        preferences[control]
    }

    public mutating func learn(from intent: MusicalIntent) {
        for control in MusicalControl.allCases {
            let value = intent[control]
            let old = preferences[control] ?? TastePreference(preferredValue: value)
            let nextConfidence = min(old.confidence + 1, 20)
            let learningRate = 1.0 / nextConfidence
            let nextValue = old.preferredValue + (value - old.preferredValue) * learningRate
            preferences[control] = TastePreference(preferredValue: nextValue, confidence: nextConfidence)
        }
    }

    public mutating func record(observation: TasteObservation) {
        observations.append(observation)
        if observations.count > 128 {
            observations.removeFirst(observations.count - 128)
        }
    }

    public mutating func reset() {
        preferences.removeAll()
        observations.removeAll()
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public init?(encoded data: Data) {
        if let decoded = try? JSONDecoder().decode(Self.self, from: data), decoded.version == Self.currentVersion {
            self = decoded
        } else if let legacy = try? JSONDecoder().decode(LegacyTasteProfile.self, from: data), legacy.version == 1 {
            self.init(preferences: legacy.preferences)
        } else {
            return nil
        }
    }
}

/// A durable comparison record. It intentionally stores semantic snapshots,
/// not rendered samples or DSP parameters, so teaching evidence stays small,
/// private, and useful for future preference rules.
public struct TasteObservation: Codable, Equatable, Sendable {
    public let sessionSeed: UInt64
    public let round: Int
    public let selectedIndex: Int
    public let candidateSeeds: [UInt64]
    public let candidateIntents: [[String: Double]]

    public init(sessionSeed: UInt64, round: Int, selectedIndex: Int, candidates: [TasteCandidate]) {
        self.sessionSeed = sessionSeed
        self.round = round
        self.selectedIndex = selectedIndex
        self.candidateSeeds = candidates.map(\.seed)
        self.candidateIntents = candidates.map { candidate in
            Dictionary(uniqueKeysWithValues: MusicalControl.allCases.map { ($0.rawValue, candidate.intent[$0]) })
        }
    }
}

private struct LegacyTasteProfile: Decodable {
    let version: Int
    let preferences: [MusicalControl: TastePreference]

    private enum CodingKeys: String, CodingKey {
        case version, preferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        if let object = try? container.decode([MusicalControl: TastePreference].self, forKey: .preferences) {
            preferences = object
            return
        }

        var pairs = try container.nestedUnkeyedContainer(forKey: .preferences)
        var decoded: [MusicalControl: TastePreference] = [:]
        while !pairs.isAtEnd {
            var pair = try pairs.nestedUnkeyedContainer()
            let control = try pair.decode(MusicalControl.self)
            let preference = try pair.decode(TastePreference.self)
            decoded[control] = preference
        }
        preferences = decoded
    }
}

public struct TasteCandidate: Equatable, Sendable {
    public let index: Int
    public let seed: UInt64
    public let intent: MusicalIntent
    public let scene: TechnoScene
    public let profileBias: Double

    public init(index: Int, seed: UInt64, intent: MusicalIntent, profileBias: Double) {
        self.index = index
        self.seed = seed
        self.intent = intent
        self.scene = TechnoScene(intent: intent, seed: seed)
        self.profileBias = profileBias
    }

    public var description: String {
        let energy = Int((intent[.groove] * 100).rounded())
        let darkness = Int((intent[.darkness] * 100).rounded())
        let space = Int((intent[.atmosphere] * 100).rounded())
        return "\(energy)% drive · \(darkness)% shadow · \(space)% space"
    }
}

public struct TasteSession: Equatable, Sendable {
    public static let candidateCount = 3
    public let sessionSeed: UInt64
    public let round: Int
    public let candidates: [TasteCandidate]

    public init(sessionSeed: UInt64, round: Int, profile: TasteProfile) {
        self.sessionSeed = sessionSeed
        self.round = round
        var generated: [TasteCandidate] = []
        for index in 0..<Self.candidateCount {
            let seed = sessionSeed &+ UInt64(round * 31 + index * 997 + 1)
            let random = MusicalIntent.random(seed: seed)
            let bias = min(0.65, 0.15 + profile.preferences.values.reduce(0) { $0 + $1.confidence } / 80)
            var values: [MusicalControl: Double] = [:]
            for (controlIndex, control) in MusicalControl.allCases.enumerated() {
                let randomValue = random[control]
                if let preference = profile.preference(for: control) {
                    let jitter = Self.deterministicJitter(seed: seed ^ UInt64(controlIndex * 17)) * (1 - bias) * 0.18
                    values[control] = min(max(randomValue * (1 - bias) + preference.preferredValue * bias + jitter, control.minimum), 1)
                } else {
                    values[control] = randomValue
                }
            }
            let intent = MusicalIntent(values: values).preservingCorrelations()
            generated.append(TasteCandidate(index: index, seed: seed, intent: intent, profileBias: bias))
        }
        candidates = generated
    }

    private static func deterministicJitter(seed: UInt64) -> Double {
        var generator = SeededGenerator(seed: seed)
        return generator.value(in: -1...1)
    }
}

public struct JukeboxScenePlan: Equatable, Sendable {
    public let index: Int
    public let seed: UInt64
    public let intent: MusicalIntent
    public let novelty: Double

    public init(index: Int, seed: UInt64, intent: MusicalIntent, novelty: Double) {
        self.index = index
        self.seed = seed
        self.intent = intent
        self.novelty = novelty
    }

    public var scene: TechnoScene { TechnoScene(intent: intent, seed: seed) }
}

/// Deterministic long-form scene planning around the local semantic taste
/// profile. Playback integration deliberately remains a separate concern.
public struct JukeboxPlan: Equatable, Sendable {
    public static let defaultSceneCount = 8
    public static let cycleStride: UInt64 = 0x9E3779B97F4A7C15
    public let sessionSeed: UInt64
    public let scenes: [JukeboxScenePlan]

    /// Creates a later long-play cycle without changing the profile-centered
    /// generation rules. Cycle zero is exactly the ordinary plan for the given
    /// session seed; later cycles derive stable, bounded novelty from it.
    public static func cycle(sessionSeed: UInt64, cycle: Int, profile: TasteProfile,
                             sceneCount: Int = JukeboxPlan.defaultSceneCount) -> JukeboxPlan {
        let normalizedCycle = UInt64(max(0, cycle))
        return JukeboxPlan(sessionSeed: sessionSeed &+ normalizedCycle &* cycleStride,
                           profile: profile, sceneCount: sceneCount)
    }

    public init(sessionSeed: UInt64, profile: TasteProfile, sceneCount: Int = JukeboxPlan.defaultSceneCount) {
        self.sessionSeed = sessionSeed
        let count = max(1, sceneCount)
        var baseValues: [MusicalControl: Double] = [:]
        for control in MusicalControl.allCases {
            baseValues[control] = profile.preference(for: control)?.preferredValue ?? MusicalIntent()[control]
        }
        let base = MusicalIntent(values: baseValues).preservingCorrelations()
        scenes = (0..<count).map { index in
            let seed = sessionSeed &+ UInt64(index * 1_009 + 17)
            let novelty = min(0.28, 0.08 + Double(index % 4) * 0.045)
            let intent = MusicalIntent.mutated(base, seed: seed, amount: novelty).preservingCorrelations()
            return JukeboxScenePlan(index: index, seed: seed, intent: intent, novelty: novelty)
        }
    }
}

public struct JukeboxPlanReport: Equatable, Sendable {
    public let sceneCount: Int
    public let uniqueSeedCount: Int
    public let maximumNovelty: Double
    public let meanTasteDistance: Double
    public let valid: Bool

    public init(plan: JukeboxPlan, profile: TasteProfile) {
        sceneCount = plan.scenes.count
        uniqueSeedCount = Set(plan.scenes.map(\.seed)).count
        maximumNovelty = plan.scenes.map(\.novelty).max() ?? 0
        let defaults = MusicalIntent()
        let distances = plan.scenes.map { scene in
            MusicalControl.allCases.reduce(0.0) { total, control in
                let preferred = profile.preference(for: control)?.preferredValue ?? defaults[control]
                return total + abs(scene.intent[control] - preferred)
            } / Double(MusicalControl.allCases.count)
        }
        meanTasteDistance = distances.reduce(0, +) / Double(max(1, distances.count))
        let sceneValuesValid = plan.scenes.allSatisfy { scene in
            let intent = scene.intent
            let bounds = MusicalControl.allCases.allSatisfy { ( $0.minimum...1 ).contains(intent[$0]) }
            let correlations = intent[.atmosphere] <= intent[.darkness] + 0.25 &&
                intent[.aggression] <= max(0.15, 0.85 - intent[.atmosphere] * 0.5)
            return bounds && correlations && scene.novelty <= 0.28
        }
        valid = sceneCount > 0 && uniqueSeedCount == sceneCount && sceneValuesValid
    }
}

/// Preparation-time validation for a longer unattended jukebox session. It
/// checks the plan graph without rendering audio, so it can be used to reject
/// a bad evolution schedule before any blocks are queued.
public struct JukeboxLongPlayReport: Equatable, Sendable {
    public let cycleCount: Int
    public let scenesPerCycle: Int
    public let totalSceneCount: Int
    public let uniqueSeedCount: Int
    public let maximumNovelty: Double
    public let adjacentCycleOverlap: Int
    public let valid: Bool

    public init(sessionSeed: UInt64, cycles: Int, profile: TasteProfile,
                sceneCount: Int = JukeboxPlan.defaultSceneCount) {
        let normalizedCycles = max(1, cycles)
        let normalizedSceneCount = max(1, sceneCount)
        cycleCount = normalizedCycles
        scenesPerCycle = normalizedSceneCount
        let plans = (0..<normalizedCycles).map {
            JukeboxPlan.cycle(sessionSeed: sessionSeed, cycle: $0,
                              profile: profile, sceneCount: normalizedSceneCount)
        }
        let allScenes = plans.flatMap(\.scenes)
        totalSceneCount = allScenes.count
        uniqueSeedCount = Set(allScenes.map(\.seed)).count
        maximumNovelty = allScenes.map(\.novelty).max() ?? 0
        adjacentCycleOverlap = zip(plans, plans.dropFirst()).reduce(0) { total, pair in
            total + Set(pair.0.scenes.map(\.seed)).intersection(Set(pair.1.scenes.map(\.seed))).count
        }
        let plansValid = plans.allSatisfy { JukeboxPlanReport(plan: $0, profile: profile).valid }
        valid = plansValid && totalSceneCount > 0 && uniqueSeedCount == totalSceneCount
            && adjacentCycleOverlap == 0 && maximumNovelty <= 0.28
    }
}
