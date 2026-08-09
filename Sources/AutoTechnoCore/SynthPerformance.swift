import Foundation

/// Listener-scale movement of the authored synth world. The DSP layer derives
/// oscillator, filter, distortion, and delay values from this intention.
package enum SynthGesture: String, CaseIterable, Sendable {
    case reveal
    case interlock
    case corrode
    case suspend
    case release
}

package enum SynthRole: String, CaseIterable, Sendable {
    case anchor
    case shadow
    case atmosphere
    case response
    case transition
}

/// The one upper-voice characteristic allowed to come forward during a
/// sixteen-bar chapter. Chapters reinterpret the same instrument; they never
/// replace its pitch cell or timbral fingerprint.
package enum InterlockChapter: String, CaseIterable, Sendable {
    case home
    case breath
    case tone
    case motion
    case memory
}

package enum RelationalFollowerStage: Int, CaseIterable, Sendable {
    case anchor
    case inhale
    case open
    case spill
    case withdraw
}

/// A true daisy-chain phase: the three-step driver advances the five-stage
/// follower only when it wraps. The phase is intentionally reset by the
/// global sixteen-bar macro grid rather than by adaptive phrase boundaries.
package struct RelationalCyclePhase: Equatable, Sendable {
    package let macroStep: Int
    package let driverPhase: Int
    package let followerStage: RelationalFollowerStage

    package init(macroStep: Int) {
        let bounded = ((macroStep % 256) + 256) % 256
        self.macroStep = bounded
        driverPhase = bounded % 3
        followerStage = RelationalFollowerStage(rawValue: (bounded / 3) % 5) ?? .anchor
    }
}

/// Fully resolved, bounded performance scalars consumed by the authored upper
/// voice. They scale the stable motif fingerprint instead of selecting a new
/// instrument identity.
package struct RelationalArticulation: Equatable, Sendable {
    package let chapter: InterlockChapter
    package let phase: RelationalCyclePhase
    package let velocityScale: Double
    package let attackScale: Double
    package let decayScale: Double
    package let spectralScale: Double
    package let spectralAperture: Double
    package let anchorSpectralScale: Double
    package let complementarySpectralScale: Double
    package let bandPassBlend: Double
    package let glideTimeScale: Double
    package let pulseEchoSend: Double

    package init(chapter: InterlockChapter, phase: RelationalCyclePhase,
                 pulseEchoEligible: Bool,
                 spectralSculptureEnabled: Bool = true) {
        let stage = phase.followerStage.rawValue
        let driverVelocity = [1.00, 0.94, 0.86][phase.driverPhase]
        let followerVelocity = [1.00, 0.94, 1.04, 1.08, 0.84][stage]
        let followerSpectralScale = [1.00, 0.92, 1.06, 1.10, 0.88][stage]
        let toneSculptureActive = chapter == .tone && spectralSculptureEnabled
        let aperture: Double
        if toneSculptureActive, phase.macroStep != 0, phase.macroStep != 255 {
            let progress = Double(phase.macroStep) / 255
            let sine = sin(.pi * progress)
            aperture = sine * sine
        } else {
            aperture = 0
        }
        let anchorScale = toneSculptureActive
            ? 1 + (followerSpectralScale - 1) * aperture : 1
        let complementaryScale = toneSculptureActive
            ? 1 - (followerSpectralScale - 1) * aperture * 0.65 : 1

        self.chapter = chapter
        self.phase = phase
        velocityScale = driverVelocity * followerVelocity
        attackScale = chapter == .breath
            ? [1.00, 1.55, 0.88, 0.78, 1.12][stage] : 1
        decayScale = chapter == .breath
            ? [1.00, 0.90, 1.18, 1.32, 0.72][stage] : 1
        spectralScale = anchorScale
        spectralAperture = aperture
        anchorSpectralScale = anchorScale
        complementarySpectralScale = complementaryScale
        bandPassBlend = toneSculptureActive ? 0.15 * aperture : 0
        glideTimeScale = chapter == .motion
            ? [1.00, 1.10, 1.15, 1.35, 0.82][stage] : 1
        pulseEchoSend = chapter == .memory && pulseEchoEligible
            ? [0.0, 0.0, 0.10, 0.22, 0.0][stage] : 0
    }

    package static let neutral = RelationalArticulation(
        chapter: .home,
        phase: RelationalCyclePhase(macroStep: 0),
        pulseEchoEligible: false
    )
}

/// Bounded long-form memory. Only the current chapter and the two chapters
/// before it are retained, so an indefinitely running session does not grow
/// state.
package struct InterlockEvolutionState: Equatable, Sendable {
    package private(set) var currentChapter: InterlockChapter
    package private(set) var previousChapters: [InterlockChapter]
    package private(set) var macroIndex: Int
    package private(set) var macrosSinceHome: Int

    package init(currentChapter: InterlockChapter = .home,
                 previousChapters: [InterlockChapter] = [],
                 macroIndex: Int = 0, macrosSinceHome: Int = 0) {
        self.currentChapter = currentChapter
        self.previousChapters = Array(previousChapters.suffix(2))
        self.macroIndex = max(0, macroIndex)
        self.macrosSinceHome = max(0, macrosSinceHome)
    }

    package func advancing(for kind: AutonomousPhraseKind,
                           entropy: UInt64) -> InterlockEvolutionState {
        let forceHome = kind == .identityReturn || macrosSinceHome >= 4
        let selected: InterlockChapter
        if forceHome {
            selected = .home
        } else {
            let preferred: [InterlockChapter]
            switch kind {
            case .lock: preferred = [.breath, .tone]
            case .contrast: preferred = [.tone, .motion]
            case .majorBreak: preferred = [.memory, .breath]
            case .energyRelease: preferred = [.motion, .breath]
            case .identityReturn: preferred = [.home]
            }
            let nonHome: [InterlockChapter] = [.breath, .tone, .motion, .memory]
            let recent = Set(previousChapters + [currentChapter])
            let unusedPreferred = preferred.filter { !recent.contains($0) }
            let unusedFallback = nonHome.filter { !recent.contains($0) }
            let choices = !unusedPreferred.isEmpty ? unusedPreferred
                : (!unusedFallback.isEmpty ? unusedFallback : nonHome)
            selected = choices[Int(entropy % UInt64(choices.count))]
        }
        return InterlockEvolutionState(
            currentChapter: selected,
            previousChapters: previousChapters + [currentChapter],
            macroIndex: macroIndex + 1,
            macrosSinceHome: selected == .home ? 0 : macrosSinceHome + 1
        )
    }
}

/// A seed-stable description of the dominant motif's audible identity. Phrase
/// transformations may move or fragment the motif without replacing this
/// envelope, modulation family, or spectral home.
package struct MotifTimbreFingerprint: Equatable, Sendable {
    package let envelopeFamily: Int
    package let modulationFamily: Int
    package let spectralRegion: Int

    package init(envelopeFamily: Int, modulationFamily: Int, spectralRegion: Int) {
        self.envelopeFamily = min(2, max(0, envelopeFamily))
        self.modulationFamily = min(2, max(0, modulationFamily))
        self.spectralRegion = min(2, max(0, spectralRegion))
    }
}

/// Stable musical identity shared by every synth role in a scene.
package struct SynthWorldDNA: Equatable, Sendable {
    package let sceneSeed: UInt64
    package let variation: Int
    package let rootFrequency: Double
    package let shadowInterval: Int
    package let responseInterval: Int
    package let motifFingerprint: MotifTimbreFingerprint

    package init(scene: TechnoScene, dna: SceneDNA) {
        sceneSeed = scene.seed
        variation = dna.timbralFamily
        rootFrequency = 65.41 * pow(2, Double(dna.tonalCenter) / 12)
        let shadowIntervals: [Int]
        let responseIntervals: [Int]
        switch dna.modalIdentity {
        case .phrygian:
            shadowIntervals = [1, 3, 7, 12]
            responseIntervals = [7, 12, 13, 15]
        case .aeolian:
            shadowIntervals = [3, 5, 7, 10]
            responseIntervals = [7, 10, 12, 15]
        case .dorian:
            shadowIntervals = [3, 5, 7, 9]
            responseIntervals = [7, 9, 12, 15]
        }
        shadowInterval = shadowIntervals[dna.timbralFamily % shadowIntervals.count]
        responseInterval = responseIntervals[dna.timbralFamily % responseIntervals.count]
        motifFingerprint = MotifTimbreFingerprint(
            envelopeFamily: Int(SceneDNA.derivedSeed(
                scene: scene.seed, domain: 0xE17E10, index: dna.timbralFamily
            ) % 3),
            modulationFamily: Int(SceneDNA.derivedSeed(
                scene: scene.seed, domain: 0xA40D, index: dna.timbralFamily
            ) % 3),
            spectralRegion: Int(SceneDNA.derivedSeed(
                scene: scene.seed, domain: 0x5EEC72A1, index: dna.timbralFamily
            ) % 3)
        )
    }
}

package struct SynthRoleEvent: Equatable, Sendable {
    package let role: SynthRole
    package let stepIndex: Int
    package let frequencyRatio: Double
    package let velocity: Double
    package let articulation: RelationalArticulation

    package init(role: SynthRole, stepIndex: Int, frequencyRatio: Double,
                velocity: Double, articulation: RelationalArticulation) {
        self.role = role
        self.stepIndex = min(15, max(0, stepIndex))
        self.frequencyRatio = max(0.125, min(8, frequencyRatio))
        self.velocity = max(0, min(1, velocity))
        self.articulation = articulation
    }
}

package struct SynthPerformanceBar: Equatable, Sendable {
    package let bar: Int
    package let gesture: SynthGesture
    package let mutationAmount: Double
    package let relationalSteps: [RelationalArticulation]
    package let interlockEvents: [SynthRoleEvent]

    package init(bar: Int, gesture: SynthGesture, mutationAmount: Double,
                relationalSteps: [RelationalArticulation],
                interlockEvents: [SynthRoleEvent]) {
        self.bar = bar
        self.gesture = gesture
        self.mutationAmount = min(1, max(0, mutationAmount))
        self.relationalSteps = relationalSteps.count == 16
            ? relationalSteps : Array(repeating: .neutral, count: 16)
        self.interlockEvents = interlockEvents
    }

    package func articulation(at step: Int) -> RelationalArticulation {
        relationalSteps[((step % 16) + 16) % 16]
    }
}

/// A deterministic upper-voice score. Its relational phase continues across
/// phrase and bar boundaries, then deliberately realigns on the global macro
/// grid. Foundation and percussion voices are not part of this plan.
package struct SynthPerformancePlan: Equatable, Sendable {
    package let world: SynthWorldDNA
    package let kind: AutonomousPhraseKind
    package let bars: [SynthPerformanceBar]

    package init(scene: TechnoScene, dna: SceneDNA, kind: AutonomousPhraseKind,
                 resolvedBars: [ResolvedPerformanceBar]) {
        let synthWorld = SynthWorldDNA(scene: scene, dna: dna)
        let synthBars = resolvedBars.map { resolved in
            let performanceBar = resolved.performance
            let gesture = SynthPerformancePlan.gesture(for: performanceBar)
            let mutation = SynthPerformancePlan.mutation(for: gesture, tension: performanceBar.tension)
            let macroBar = ((performanceBar.bar % 16) + 16) % 16
            let hasRelationalUpperMaterial = resolved.ensemble.events.contains {
                $0.voice == .motif || $0.voice == .response
            }
            let spectralSculptureEnabled = kind != .identityReturn &&
                kind != .majorBreak && hasRelationalUpperMaterial
            let relationalSteps = (0..<16).map { step in
                RelationalArticulation(
                    chapter: resolved.interlockChapter,
                    phase: RelationalCyclePhase(macroStep: macroBar * 16 + step),
                    pulseEchoEligible: resolved.pulseEchoEnabled,
                    spectralSculptureEnabled: spectralSculptureEnabled
                )
            }
            let events = gesture != .suspend
                ? SynthPerformancePlan.interlockEvents(
                    gesture: gesture,
                    world: synthWorld,
                    resolvedEvents: resolved.ensemble.events.filter { $0.voice == .motif },
                    relationalSteps: relationalSteps
                )
                : []
            return SynthPerformanceBar(
                bar: performanceBar.bar,
                gesture: gesture,
                mutationAmount: mutation,
                relationalSteps: relationalSteps,
                interlockEvents: events
            )
        }
        world = synthWorld
        self.kind = kind
        bars = synthBars
    }

    private static func gesture(for bar: PerformanceBar) -> SynthGesture {
        switch bar.section {
        case .groove:
            return bar.phrase == 0 && bar.localBar < max(2, bar.phraseLength / 2)
                ? .reveal : .interlock
        case .build: return .corrode
        case .breakdown: return .suspend
        case .returnSection: return .release
        }
    }

    private static func mutation(for gesture: SynthGesture, tension: Double) -> Double {
        switch gesture {
        case .reveal: return 0.20 + tension * 0.12
        case .interlock: return 0.34 + tension * 0.18
        case .corrode: return 0.66 + tension * 0.28
        case .suspend: return 0.78 + tension * 0.16
        case .release: return 0.28 + tension * 0.12
        }
    }

    private static func interlockEvents(gesture: SynthGesture, world: SynthWorldDNA,
                                        resolvedEvents: [EnsembleResolvedEvent],
                                        relationalSteps: [RelationalArticulation]) -> [SynthRoleEvent] {
        resolvedEvents.enumerated().map { eventIndex, resolved in
            let step = resolved.step
            let octave = eventIndex.isMultiple(of: 3) ? 0.5 : 1.0
            let interval = pow(2, Double(world.shadowInterval) / 12)
            let gestureLevel: Double
            switch gesture {
            case .reveal: gestureLevel = 0.34
            case .interlock: gestureLevel = 0.46
            case .corrode: gestureLevel = 0.58
            case .release: gestureLevel = 0.38
            case .suspend: gestureLevel = 0
            }
            return SynthRoleEvent(
                role: .shadow,
                stepIndex: step,
                frequencyRatio: interval * octave,
                velocity: min(0.72, gestureLevel * max(0.35, resolved.intensity)),
                articulation: relationalSteps[step]
            )
        }.sorted { $0.stepIndex < $1.stepIndex }
    }
}
