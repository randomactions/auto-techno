import Foundation

/// The small set of authored synthesis topologies owned by the canonical
/// renderer. These are internal capabilities, never selectable runtimes.
package enum InstrumentArchitecture: String, CaseIterable, Sendable {
    case resonantMono
    case tonalMotion
    case spectralTexture
}

/// Musical jobs that may receive an instrument assignment. The names follow
/// the canonical score rather than DAW track terminology.
package enum InstrumentUse: String, CaseIterable, Sendable {
    case foundationBass
    case motif
    case shadow
    case response
    case atmosphere
    case transition

    package init(role: SynthRole) {
        switch role {
        case .anchor: self = .motif
        case .shadow: self = .shadow
        case .response: self = .response
        case .atmosphere: self = .atmosphere
        case .transition: self = .transition
        }
    }
}

/// Recognizable home states inside an authored architecture. A patch is not a
/// fixed parameter snapshot: `InstrumentAutomation` moves it inside its tested
/// identity bounds.
package enum InstrumentPatch: String, CaseIterable, Sendable {
    case bassPulse
    case bassPluck
    case acidThread
    case acidSequence
    case northStar
    case darkChord
    case glassRunner
    case alienNoise
    case metalVeil
    case dustCloud

    package var architecture: InstrumentArchitecture {
        switch self {
        case .bassPulse, .bassPluck, .acidThread, .acidSequence:
            .resonantMono
        case .northStar, .darkChord, .glassRunner:
            .tonalMotion
        case .alienNoise, .metalVeil, .dustCloud:
            .spectralTexture
        }
    }
}

/// Effect stages an assignment is allowed to reach in the existing canonical
/// signal path. The list describes routing truth, not a second graph planner.
package enum InstrumentEffect: String, CaseIterable, Sendable {
    case drive
    case chorus
    case comb
    case unsyncedEcho
    case pulseEcho
    case filteredReverb
    case maskingGuard
    case glue
    case master
}

/// Four semantic, bounded automation coordinates shared by every architecture.
/// Each renderer translates them into its own cutoff/noise color, envelope,
/// modulation, and send behavior.
package struct InstrumentAutomation: Equatable, Sendable {
    package let color: Double
    package let shape: Double
    package let motion: Double
    package let space: Double

    package init(color: Double, shape: Double, motion: Double, space: Double) {
        self.color = min(1, max(0, color))
        self.shape = min(1, max(0, shape))
        self.motion = min(1, max(0, motion))
        self.space = min(1, max(0, space))
    }

    package static let neutral = InstrumentAutomation(
        color: 0.5,
        shape: 0.5,
        motion: 0.5,
        space: 0
    )
}

package struct InstrumentCapability: Equatable, Sendable {
    package let patch: InstrumentPatch
    package let eligibleUses: [InstrumentUse]
    package let compatibleEffects: [InstrumentEffect]

    package init(patch: InstrumentPatch, eligibleUses: [InstrumentUse],
                 compatibleEffects: [InstrumentEffect]) {
        self.patch = patch
        self.eligibleUses = Self.orderedUnique(eligibleUses)
        self.compatibleEffects = Self.orderedUnique(compatibleEffects)
    }

    package func supports(_ use: InstrumentUse) -> Bool {
        eligibleUses.contains(use)
    }

    private static func orderedUnique<T: CaseIterable & RawRepresentable & Hashable>(
        _ values: [T]
    ) -> [T] where T.RawValue == String {
        let requested = Set(values)
        return T.allCases.filter(requested.contains)
    }
}

/// One score-owned selection, including the only four coordinates the renderer
/// may automate and the exact existing effect stages it is allowed to reach.
package struct InstrumentAssignment: Equatable, Sendable {
    package let use: InstrumentUse
    package let architecture: InstrumentArchitecture
    package let patch: InstrumentPatch
    package let automation: InstrumentAutomation
    package let effects: [InstrumentEffect]

    package init(use: InstrumentUse, patch: InstrumentPatch,
                 automation: InstrumentAutomation,
                 effects: [InstrumentEffect]) {
        self.use = use
        architecture = patch.architecture
        self.patch = patch
        self.automation = automation
        let requested = Set(effects)
        self.effects = InstrumentEffect.allCases.filter(requested.contains)
    }

    package var isValid: Bool {
        guard let capability = InstrumentPalette.capability(for: patch),
              architecture == patch.architecture,
              capability.supports(use),
              Set(effects).isSubset(of: Set(capability.compatibleEffects)) else {
            return false
        }
        return use != .foundationBass || automation.space == 0
    }
}

/// Canonical capability and selection policy. It converts scene/phrase intent
/// into a bounded assignment before detached rendering; DSP never chooses a
/// patch or invents automation.
package enum InstrumentPalette {
    package static let capabilities: [InstrumentCapability] = [
        InstrumentCapability(
            patch: .bassPulse,
            eligibleUses: [.foundationBass],
            compatibleEffects: [.drive, .maskingGuard, .glue, .master]
        ),
        InstrumentCapability(
            patch: .bassPluck,
            eligibleUses: [.foundationBass],
            compatibleEffects: [.drive, .maskingGuard, .glue, .master]
        ),
        InstrumentCapability(
            patch: .acidThread,
            eligibleUses: [.motif, .shadow, .response],
            compatibleEffects: upperEffects(core: [.drive], pulseEcho: true)
        ),
        InstrumentCapability(
            patch: .acidSequence,
            eligibleUses: [.motif, .shadow, .response],
            compatibleEffects: upperEffects(core: [.drive], pulseEcho: true)
        ),
        InstrumentCapability(
            patch: .northStar,
            eligibleUses: [.motif, .shadow, .response],
            compatibleEffects: upperEffects(core: [.comb], pulseEcho: true)
        ),
        InstrumentCapability(
            patch: .darkChord,
            eligibleUses: [.motif, .shadow, .response, .atmosphere, .transition],
            compatibleEffects: upperEffects(core: [.comb], pulseEcho: true)
        ),
        InstrumentCapability(
            patch: .glassRunner,
            eligibleUses: [.motif, .shadow, .response],
            compatibleEffects: upperEffects(core: [.drive, .comb], pulseEcho: true)
        ),
        InstrumentCapability(
            patch: .alienNoise,
            eligibleUses: [.response, .atmosphere],
            compatibleEffects: upperEffects(core: [.drive], pulseEcho: false)
        ),
        InstrumentCapability(
            patch: .metalVeil,
            eligibleUses: [.response, .atmosphere, .transition],
            compatibleEffects: upperEffects(core: [.drive], pulseEcho: false)
        ),
        InstrumentCapability(
            patch: .dustCloud,
            eligibleUses: [.atmosphere, .transition],
            compatibleEffects: upperEffects(core: [], pulseEcho: false)
        ),
    ]

    package static func capability(for patch: InstrumentPatch) -> InstrumentCapability? {
        capabilities.first { $0.patch == patch }
    }

    package static func safeFoundation() -> InstrumentAssignment {
        assignment(
            use: .foundationBass,
            patch: .bassPulse,
            automation: InstrumentAutomation(color: 0.28, shape: 0.52, motion: 0.18, space: 0),
            pulseEchoEnabled: false
        )
    }

    package static func safeUpper(role: SynthRole) -> InstrumentAssignment {
        let use = InstrumentUse(role: role)
        let patch: InstrumentPatch = switch role {
        case .anchor, .response: .northStar
        case .shadow: .glassRunner
        case .atmosphere, .transition: .darkChord
        }
        return assignment(
            use: use,
            patch: patch,
            automation: InstrumentAutomation(color: 0.46, shape: 0.52, motion: 0.28, space: 0.18),
            pulseEchoEnabled: false
        )
    }

    package static func resolveFoundation(
        world: SynthWorldDNA,
        kind: AutonomousPhraseKind,
        gesture: SynthGesture,
        mutationAmount: Double,
        foundationBehavior: FoundationBehavior? = nil,
        conservative: Bool
    ) -> InstrumentAssignment {
        guard !conservative else { return safeFoundation() }
        if let foundationBehavior {
            let patch: InstrumentPatch
            let automation: InstrumentAutomation
            switch foundationBehavior {
            case .subPulse:
                patch = .bassPulse
                automation = InstrumentAutomation(
                    color: 0.16 + mutationAmount * 0.12,
                    shape: 0.70,
                    motion: 0.10 + mutationAmount * 0.10,
                    space: 0
                )
            case .monotone:
                patch = .bassPulse
                automation = InstrumentAutomation(
                    color: 0.22 + mutationAmount * 0.18,
                    shape: 0.54,
                    motion: 0.18 + mutationAmount * 0.18,
                    space: 0
                )
            case .point:
                patch = .bassPluck
                automation = InstrumentAutomation(
                    color: 0.44 + mutationAmount * 0.22,
                    shape: 0.84,
                    motion: 0.24 + mutationAmount * 0.16,
                    space: 0
                )
            case .pump:
                patch = .bassPulse
                automation = InstrumentAutomation(
                    color: 0.30 + mutationAmount * 0.18,
                    shape: 0.76,
                    motion: 0.30 + mutationAmount * 0.16,
                    space: 0
                )
            case .kickTail, .tunedPercussive, .absent:
                return safeFoundation()
            }
            return assignment(
                use: .foundationBass,
                patch: patch,
                automation: automation,
                pulseEchoEnabled: false
            )
        }
        let energetic = kind == .contrast || kind == .energyRelease
        let patch: InstrumentPatch = energetic && (world.variation + gestureIndex(gesture)).isMultiple(of: 2)
            ? .bassPluck : .bassPulse
        let motion = min(1, mutationAmount * (patch == .bassPluck ? 0.58 : 0.38))
        return assignment(
            use: .foundationBass,
            patch: patch,
            automation: InstrumentAutomation(
                color: 0.20 + mutationAmount * (patch == .bassPluck ? 0.42 : 0.28),
                shape: patch == .bassPluck ? 0.76 : 0.48,
                motion: motion,
                space: 0
            ),
            pulseEchoEnabled: false
        )
    }

    package static func resolveUpper(
        role: SynthRole,
        world: SynthWorldDNA,
        kind: AutonomousPhraseKind,
        gesture: SynthGesture,
        chapter: InterlockChapter,
        mutationAmount: Double,
        conservative: Bool,
        pulseEchoEnabled: Bool,
        performanceCharacter: PerformanceCharacter = .hypnoticLock
    ) -> InstrumentAssignment {
        guard !conservative else { return safeUpper(role: role) }
        let patch: InstrumentPatch
        switch (performanceCharacter, role) {
        case (.acidPressure, .anchor):
            patch = .acidSequence
        case (.acidPressure, .shadow):
            patch = .acidThread
        case (.acidPressure, .response):
            patch = .acidSequence
        case (.acidPressure, .atmosphere):
            patch = .alienNoise
        case (.acidPressure, .transition):
            patch = .metalVeil
        case (.peakDrive, .anchor):
            patch = .glassRunner
        case (.peakDrive, .shadow):
            patch = .acidThread
        case (.peakDrive, .response):
            patch = .northStar
        case (.peakDrive, .atmosphere):
            patch = .alienNoise
        case (.peakDrive, .transition):
            patch = .metalVeil
        case (.brokenSuspension, .anchor), (.brokenSuspension, .shadow):
            patch = .glassRunner
        case (.brokenSuspension, .response):
            patch = .alienNoise
        case (.brokenSuspension, .atmosphere):
            patch = .dustCloud
        case (.brokenSuspension, .transition):
            patch = .metalVeil
        case (.ambientDrift, .anchor), (.ambientDrift, .shadow):
            patch = .darkChord
        case (.ambientDrift, .response):
            patch = .alienNoise
        case (.ambientDrift, .atmosphere), (.ambientDrift, .transition):
            patch = .dustCloud
        case (.melodicGlow, .anchor), (.melodicGlow, .response):
            patch = .northStar
        case (.melodicGlow, .shadow), (.melodicGlow, .atmosphere),
             (.melodicGlow, .transition):
            patch = .darkChord
        case (.hypnoticLock, let role):
            switch role {
            case .anchor:
                if chapter == .motion && (kind == .contrast || kind == .energyRelease) {
                    patch = .acidSequence
                } else if gesture == .corrode {
                    patch = .acidThread
                } else {
                    patch = [.northStar, .darkChord, .glassRunner][world.variation % 3]
                }
            case .shadow:
                patch = chapter == .motion ? .acidThread :
                    ([.glassRunner, .darkChord][world.variation % 2])
            case .response:
                if chapter == .motion {
                    patch = .acidSequence
                } else if chapter == .tone && kind != .majorBreak {
                    patch = .alienNoise
                } else {
                    patch = .northStar
                }
            case .atmosphere:
                patch = chapter == .breath || kind == .majorBreak ? .dustCloud : .alienNoise
            case .transition:
                patch = chapter == .memory ? .dustCloud : .metalVeil
            }
        }

        let base = automationBase(for: patch)
        let motionLift = min(0.42, mutationAmount * 0.42)
        let shapeLift = gesture == .suspend ? 0.22 : (gesture == .corrode ? -0.12 : 0)
        let roleSpace: Double = switch role {
        case .anchor: 0.10
        case .shadow, .response: 0.24
        case .atmosphere: 0.72
        case .transition: 0.58
        }
        return assignment(
            use: InstrumentUse(role: role),
            patch: patch,
            automation: InstrumentAutomation(
                color: base.color + mutationAmount * 0.32,
                shape: base.shape + shapeLift,
                motion: base.motion + motionLift,
                space: roleSpace + mutationAmount * 0.16
            ),
            pulseEchoEnabled: pulseEchoEnabled
        )
    }

    package static var isInternallyValid: Bool {
        let patches = capabilities.map(\.patch)
        guard capabilities.count == InstrumentPatch.allCases.count,
              Set(patches).count == patches.count,
              Set(patches) == Set(InstrumentPatch.allCases),
              Set(patches.map(\.architecture)) == Set(InstrumentArchitecture.allCases) else {
            return false
        }
        return capabilities.allSatisfy { capability in
            !capability.eligibleUses.isEmpty &&
                !capability.compatibleEffects.isEmpty
        }
    }

    private static func assignment(
        use: InstrumentUse,
        patch: InstrumentPatch,
        automation: InstrumentAutomation,
        pulseEchoEnabled: Bool
    ) -> InstrumentAssignment {
        let capability = capability(for: patch)
        var effects = capability?.compatibleEffects ?? []
        if !pulseEchoEnabled { effects.removeAll { $0 == .pulseEcho } }
        let result = InstrumentAssignment(
            use: use,
            patch: patch,
            automation: automation,
            effects: effects
        )
        precondition(result.isValid, "Instrument palette emitted an incompatible assignment")
        return result
    }

    private static func upperEffects(
        core: [InstrumentEffect],
        pulseEcho: Bool
    ) -> [InstrumentEffect] {
        core + [.chorus, .unsyncedEcho] + (pulseEcho ? [.pulseEcho] : []) +
            [.filteredReverb, .maskingGuard, .glue, .master]
    }

    private static func automationBase(for patch: InstrumentPatch) -> InstrumentAutomation {
        switch patch {
        case .bassPulse:
            InstrumentAutomation(color: 0.24, shape: 0.48, motion: 0.18, space: 0)
        case .bassPluck:
            InstrumentAutomation(color: 0.38, shape: 0.78, motion: 0.26, space: 0)
        case .acidThread:
            InstrumentAutomation(color: 0.46, shape: 0.62, motion: 0.58, space: 0.12)
        case .acidSequence:
            InstrumentAutomation(color: 0.58, shape: 0.55, motion: 0.72, space: 0.16)
        case .northStar:
            InstrumentAutomation(color: 0.52, shape: 0.44, motion: 0.34, space: 0.20)
        case .darkChord:
            InstrumentAutomation(color: 0.30, shape: 0.72, motion: 0.28, space: 0.36)
        case .glassRunner:
            InstrumentAutomation(color: 0.70, shape: 0.34, motion: 0.62, space: 0.24)
        case .alienNoise:
            InstrumentAutomation(color: 0.58, shape: 0.46, motion: 0.76, space: 0.62)
        case .metalVeil:
            InstrumentAutomation(color: 0.78, shape: 0.32, motion: 0.68, space: 0.52)
        case .dustCloud:
            InstrumentAutomation(color: 0.34, shape: 0.82, motion: 0.42, space: 0.78)
        }
    }

    private static func gestureIndex(_ gesture: SynthGesture) -> Int {
        SynthGesture.allCases.firstIndex(of: gesture) ?? 0
    }
}
