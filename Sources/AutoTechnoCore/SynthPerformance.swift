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

/// Stable musical identity shared by every synth role in a scene.
package struct SynthWorldDNA: Equatable, Sendable {
    package let sceneSeed: UInt64
    package let variation: Int
    package let rootFrequency: Double
    package let shadowInterval: Int
    package let responseInterval: Int
    package let shadowRotation: Int
    package let echoRotation: Int

    package init(scene: TechnoScene, dna: SceneDNA) {
        sceneSeed = scene.seed
        variation = dna.timbralFamily
        rootFrequency = 65.41 * pow(2, Double(dna.tonalCenter) / 12)
        let shadowIntervals = [3, 5, 7, 10]
        let responseIntervals = [7, 10, 12, 15]
        shadowInterval = shadowIntervals[dna.timbralFamily % shadowIntervals.count]
        responseInterval = responseIntervals[dna.timbralFamily % responseIntervals.count]
        shadowRotation = Int(SceneDNA.derivedSeed(scene: scene.seed, domain: 0xA11E, index: 0) % 16)
        echoRotation = Int(SceneDNA.derivedSeed(scene: scene.seed, domain: 0xEC40, index: 0) % 3)
    }
}

package struct SynthRoleEvent: Equatable, Sendable {
    package let role: SynthRole
    package let stepIndex: Int
    package let frequencyRatio: Double
    package let velocity: Double
    package let sevenStepAccent: Bool
    package let echoGate: Bool

    package init(role: SynthRole, stepIndex: Int, frequencyRatio: Double,
                velocity: Double, sevenStepAccent: Bool, echoGate: Bool) {
        self.role = role
        self.stepIndex = min(15, max(0, stepIndex))
        self.frequencyRatio = max(0.125, min(8, frequencyRatio))
        self.velocity = max(0, min(1, velocity))
        self.sevenStepAccent = sevenStepAccent
        self.echoGate = echoGate
    }
}

package struct SynthPerformanceBar: Equatable, Sendable {
    package let bar: Int
    package let gesture: SynthGesture
    package let mutationAmount: Double
    package let sevenStepPhase: Int
    package let echoGatePhase: Int
    package let interlockEvents: [SynthRoleEvent]

    package init(bar: Int, gesture: SynthGesture, mutationAmount: Double,
                sevenStepPhase: Int, echoGatePhase: Int,
                interlockEvents: [SynthRoleEvent]) {
        self.bar = bar
        self.gesture = gesture
        self.mutationAmount = min(1, max(0, mutationAmount))
        self.sevenStepPhase = ((sevenStepPhase % 7) + 7) % 7
        self.echoGatePhase = ((echoGatePhase % 3) + 3) % 3
        self.interlockEvents = interlockEvents
    }
}

/// A deterministic upper-voice score. Its clocks deliberately continue across
/// bar boundaries; kick, bass, hats, and clap are not part of this plan.
package struct SynthPerformancePlan: Equatable, Sendable {
    package let world: SynthWorldDNA
    package let bars: [SynthPerformanceBar]

    package init(scene: TechnoScene, dna: SceneDNA, bars performanceBars: [PerformanceBar]) {
        let synthWorld = SynthWorldDNA(scene: scene, dna: dna)
        let synthBars = performanceBars.map { performanceBar in
            let gesture = SynthPerformancePlan.gesture(for: performanceBar)
            let mutation = SynthPerformancePlan.mutation(for: gesture, tension: performanceBar.tension)
            let globalStart = performanceBar.bar * 16
            let sevenPhase = globalStart % 7
            let echoPhase = (globalStart + synthWorld.echoRotation) % 3
            let events = gesture != .suspend
                ? SynthPerformancePlan.interlockEvents(
                    bar: performanceBar.bar,
                    gesture: gesture,
                    world: synthWorld,
                    kickSteps: Set(dna.rhythm.kickSteps)
                )
                : []
            return SynthPerformanceBar(
                bar: performanceBar.bar,
                gesture: gesture,
                mutationAmount: mutation,
                sevenStepPhase: sevenPhase,
                echoGatePhase: echoPhase,
                interlockEvents: events
            )
        }
        world = synthWorld
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

    private static func interlockEvents(bar: Int, gesture: SynthGesture,
                                        world: SynthWorldDNA,
                                        kickSteps: Set<Int>) -> [SynthRoleEvent] {
        let rawSteps = (0..<16).filter { index in
            ((index * 5 + world.shadowRotation) % 16) < 5
        }
        var used: Set<Int> = []
        return rawSteps.enumerated().map { eventIndex, rawStep in
            let step = relocate(rawStep, avoiding: kickSteps, used: &used)
            let globalStep = bar * 16 + step
            let sevenAccent = (globalStep + world.shadowRotation) % 7 == 0
            let echoGate = (globalStep + world.echoRotation) % 3 == 0
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
                velocity: min(0.72, gestureLevel + (sevenAccent ? 0.12 : 0)),
                sevenStepAccent: sevenAccent,
                echoGate: echoGate
            )
        }.sorted { $0.stepIndex < $1.stepIndex }
    }

    private static func relocate(_ requested: Int, avoiding kickSteps: Set<Int>,
                                 used: inout Set<Int>) -> Int {
        for offset in 0..<16 {
            let candidate = (requested + offset) % 16
            if !kickSteps.contains(candidate) && !used.contains(candidate) {
                used.insert(candidate)
                return candidate
            }
        }
        return requested
    }
}
