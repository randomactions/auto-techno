import Foundation

/// One immutable scene selected by the autonomous long-form director.
/// MusicalIntent remains an internal composition vocabulary, not a UI model.
public struct AutonomousPerformanceScene: Equatable, Sendable {
    public let position: Int
    public let cycle: Int
    public let sceneIndex: Int
    public let seed: UInt64
    public let scene: TechnoScene

    public init(position: Int, cycle: Int, sceneIndex: Int,
                seed: UInt64, scene: TechnoScene) {
        self.position = position
        self.cycle = cycle
        self.sceneIndex = sceneIndex
        self.seed = seed
        self.scene = scene
    }
}

/// The only shipped performance policy: deterministic, unattended scene
/// evolution at a fixed club tempo. Former UI controls no longer own musical
/// state; they survive only as internal correlated dimensions that the
/// director is free to evolve in future versions.
public struct AutonomousPerformanceDirector: Equatable, Sendable {
    public static let bpm = 130.0
    public static let rootSeed: UInt64 = 48_291
    public static let barsPerScene = 32

    public let rootSeed: UInt64

    public init(rootSeed: UInt64 = Self.rootSeed) {
        self.rootSeed = rootSeed
    }

    public func scene(at requestedPosition: Int) -> AutonomousPerformanceScene {
        let position = max(0, requestedPosition)
        let sceneCount = JukeboxPlan.defaultSceneCount
        let cycle = position / sceneCount
        let sceneIndex = position % sceneCount
        let profile = TasteProfile()
        let plan = JukeboxPlan.cycle(sessionSeed: rootSeed, cycle: cycle, profile: profile)
        let planned = plan.scenes[sceneIndex]
        let fixedTempoScene = TechnoScene(intent: planned.intent, seed: planned.seed, bpm: Self.bpm)
        return AutonomousPerformanceScene(
            position: position,
            cycle: cycle,
            sceneIndex: sceneIndex,
            seed: planned.seed,
            scene: fixedTempoScene
        )
    }
}
