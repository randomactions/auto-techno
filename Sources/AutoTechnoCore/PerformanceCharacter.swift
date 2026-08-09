import Foundation

/// Phrase-scale musical behavior selected by the canonical session director.
/// These are coordinated interpretations of one persistent identity, not genre
/// presets, alternate engines, or user-facing modes.
package enum PerformanceCharacter: String, CaseIterable, Sendable {
    case hypnoticLock
    case acidPressure
    case peakDrive
    case brokenSuspension
    case ambientDrift
    case melodicGlow
}

/// The audible relationship between the kick and its low-frequency companion.
/// A behavior resolves both score events and the existing foundation patch;
/// DSP never selects one independently.
package enum FoundationBehavior: String, CaseIterable, Sendable {
    case subPulse
    case monotone
    case point
    case pump
    case kickTail
    case tunedPercussive
    case absent

    package var companion: FoundationCompanion {
        switch self {
        case .subPulse, .monotone, .point, .pump: .bass
        case .kickTail: .monoRumble
        case .tunedPercussive: .tunedTom
        case .absent: .empty
        }
    }

    package init(companion: FoundationCompanion) {
        switch companion {
        case .bass: self = .monotone
        case .monoRumble: self = .kickTail
        case .tunedTom: self = .tunedPercussive
        case .empty: self = .absent
        }
    }
}

/// One compatibility owner prevents independent random choices from combining
/// mutually competitive foundation, rhythm, and foreground behaviors.
package enum PerformanceCharacterContract {
    package static func allowedFoundations(
        for character: PerformanceCharacter
    ) -> [FoundationBehavior] {
        switch character {
        case .hypnoticLock: [.subPulse, .monotone]
        case .acidPressure: [.monotone, .point]
        case .peakDrive: [.point, .pump]
        case .brokenSuspension: [.kickTail, .tunedPercussive]
        case .ambientDrift: [.absent, .kickTail]
        case .melodicGlow: [.subPulse, .point]
        }
    }

    package static func foundationIsCompatible(
        _ behavior: FoundationBehavior,
        with character: PerformanceCharacter
    ) -> Bool {
        allowedFoundations(for: character).contains(behavior)
    }

    package static func rolesAreCompatible(
        _ roles: [PerformanceRole],
        with character: PerformanceCharacter
    ) -> Bool {
        let set = Set(roles)
        guard set.contains(.foundation), (2...4).contains(roles.count) else { return false }
        switch character {
        case .hypnoticLock, .acidPressure, .peakDrive, .melodicGlow:
            return set.contains(.motif)
        case .brokenSuspension, .ambientDrift:
            return set.contains(.motif) || set.contains(.atmosphere)
        }
    }

    package static func rhythmIsCompatible(
        _ ensemble: EnsembleContext,
        with character: PerformanceCharacter
    ) -> Bool {
        let kicks = ensemble.events.filter { $0.voice == .kick }.map(\.step)
        guard !kicks.isEmpty, kicks.contains(0) else { return false }
        switch character {
        case .brokenSuspension:
            return kicks.count <= 5 && kicks.contains { !$0.isMultiple(of: 4) }
        case .peakDrive:
            return [0, 4, 8].allSatisfy(kicks.contains) &&
                (kicks.contains(12) || kicks.contains(13))
        case .hypnoticLock, .acidPressure, .ambientDrift, .melodicGlow:
            return true
        }
    }
}

/// Bounded, machine-readable structural evidence that a phrase expressed one
/// coherent character instead of independently randomized layers. Existing
/// instrument and architecture-local PCM evidence supplies the downstream
/// score-to-render consequence.
package struct PerformanceCharacterEvidence: Equatable, Sendable {
    package let character: PerformanceCharacter
    package let totalBars: Int
    package let compatibleFoundationBars: Int
    package let compatibleRoleBars: Int
    package let characteristicRhythmBars: Int
    package let valid: Bool

    package init(resolvedBars: [ResolvedPerformanceBar], conservative: Bool) {
        let selectedCharacter = resolvedBars.first?.performanceCharacter ?? .hypnoticLock
        let barCount = resolvedBars.count
        let foundationCount: Int
        let roleCount: Int
        let rhythmCount: Int
        if conservative {
            foundationCount = resolvedBars.filter {
                $0.performanceCharacter == selectedCharacter &&
                    $0.foundationBehavior.companion == $0.foundationCompanion
            }.count
            roleCount = resolvedBars.filter {
                $0.performanceCharacter == selectedCharacter
            }.count
            rhythmCount = resolvedBars.filter {
                $0.performanceCharacter == selectedCharacter &&
                    !$0.ensemble.events.filter { $0.voice == .kick }.isEmpty
            }.count
        } else {
            foundationCount = resolvedBars.filter {
                $0.performanceCharacter == selectedCharacter &&
                    $0.foundationBehavior.companion == $0.foundationCompanion &&
                    PerformanceCharacterContract.foundationIsCompatible(
                        $0.foundationBehavior,
                        with: selectedCharacter
                    )
            }.count
            roleCount = resolvedBars.filter {
                $0.performanceCharacter == selectedCharacter &&
                    PerformanceCharacterContract.rolesAreCompatible(
                        $0.performance.roles,
                        with: selectedCharacter
                    )
            }.count
            rhythmCount = resolvedBars.filter {
                $0.performanceCharacter == selectedCharacter &&
                    PerformanceCharacterContract.rhythmIsCompatible(
                        $0.ensemble,
                        with: selectedCharacter
                    )
            }.count
        }
        character = selectedCharacter
        totalBars = barCount
        compatibleFoundationBars = foundationCount
        compatibleRoleBars = roleCount
        characteristicRhythmBars = rhythmCount
        valid = barCount > 0 && foundationCount == barCount &&
            roleCount == barCount && rhythmCount == barCount
    }
}
