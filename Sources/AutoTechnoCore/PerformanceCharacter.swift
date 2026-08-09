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

    /// The canonical score-owned foundation interpretation for a resolved
    /// nonconservative phrase bar. The session director and preparation replay
    /// share this owner so a candidate cannot self-authorize a different
    /// companion relationship.
    package static func foundationBehavior(
        for character: PerformanceCharacter,
        gesture: ArrangementGesture,
        localBar: Int,
        phraseLength: Int
    ) -> FoundationBehavior {
        switch character {
        case .hypnoticLock:
            gesture == .minimalize ? .subPulse : .monotone
        case .acidPressure:
            gesture == .turnaround ? .point : .monotone
        case .peakDrive:
            localBar < phraseLength / 2 ? .point : .pump
        case .brokenSuspension:
            gesture == .structuralMarker ? .tunedPercussive : .kickTail
        case .ambientDrift:
            gesture == .structuralMarker ? .kickTail : .absent
        case .melodicGlow:
            gesture == .turnaround ? .point : .subPulse
        }
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

    package init(
        resolvedBars: [ResolvedPerformanceBar],
        kind: AutonomousPhraseKind,
        paidDebtIDs: [Int],
        conservative: Bool
    ) {
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
            let authorizedKickSyntax = Self.kickSyntaxArcIsCanonical(
                resolvedBars: resolvedBars,
                kind: kind,
                paidDebtIDs: paidDebtIDs
            )
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
                    (PerformanceCharacterContract.rhythmIsCompatible(
                        $0.ensemble,
                        with: selectedCharacter
                    ) || (authorizedKickSyntax && $0.kickSyntaxRole == .withheld))
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

    private static func kickSyntaxArcIsCanonical(
        resolvedBars: [ResolvedPerformanceBar],
        kind: AutonomousPhraseKind,
        paidDebtIDs: [Int]
    ) -> Bool {
        guard kind == .energyRelease,
              !paidDebtIDs.isEmpty,
              resolvedBars.count <= 16 else {
            return false
        }
        let recoveryIndices = resolvedBars.indices.filter {
            resolvedBars[$0].kickSyntaxRole == .recovery
        }
        guard recoveryIndices.count == 1,
              let recoveryIndex = recoveryIndices.first,
              recoveryIndex >= 3 else {
            return false
        }
        let firstWithheldIndex = recoveryIndex - 2
        let secondWithheldIndex = recoveryIndex - 1
        guard resolvedBars.indices.allSatisfy({ index in
                  let expected: KickSyntaxRole
                  if index == firstWithheldIndex || index == secondWithheldIndex {
                      expected = .withheld
                  } else if index == recoveryIndex {
                      expected = .recovery
                  } else {
                      expected = .grounded
                  }
                  return resolvedBars[index].kickSyntaxRole == expected
              }) else {
            return false
        }
        let setup = resolvedBars[recoveryIndex - 3]
        let recovery = resolvedBars[recoveryIndex]
        guard setup.ensemble.events.contains(where: {
                  $0.voice == .kick && $0.step == 0
              }),
              recovery.ensemble.events.contains(where: {
                  $0.voice == .kick && $0.step == 0
              }),
              recovery.performance.signatureEvent == .displacedKickRecovery,
              recovery.arrangementGesture == .structuralMarker else {
            return false
        }
        for index in [firstWithheldIndex, secondWithheldIndex] {
            let bar = resolvedBars[index]
            let grooveSteps = bar.ensemble.events
                .filter { $0.voice == .groovePulse }
                .map(\.step)
                .sorted()
            guard bar.ensemble.kickAnchors.isEmpty,
                  !bar.ensemble.events.contains(where: { $0.voice == .kick }),
                  grooveSteps == KickSyntaxResolver.canonicalWeakPulseSteps,
                  bar.groovePulses.map(\.step) ==
                    KickSyntaxResolver.canonicalWeakPulseSteps,
                  bar.ensemble.events.contains(where: { $0.voice == .motif }),
                  !bar.ensemble.events.contains(where: {
                      $0.voice != .kick && $0.step == 0
                  }) else {
                return false
            }
        }
        return true
    }
}
