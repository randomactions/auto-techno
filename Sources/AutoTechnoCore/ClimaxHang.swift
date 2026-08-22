/// Durable score meaning for the bounded absence between an already-owned
/// climax rise and its unchanged recovery. The articulation adds no onset,
/// track, instrument, effect, clock, or persistent state.
package enum ClimaxHangRelation: String, Codable, Equatable, Sendable {
    case terminalRecoveryDelay = "terminal-recovery-delay"
}

package enum ClimaxHangContract {
    package static let startStep = 12
    package static let endStep = 16
    package static let preHangWeakPulseSteps = [3, 7, 11]
    package static let macroPosition = 14
}

package struct ClimaxHangArticulation: Codable, Equatable, Sendable {
    package let relation: ClimaxHangRelation
    package let startStep: Int
    package let endStep: Int

    package init(
        relation: ClimaxHangRelation = .terminalRecoveryDelay,
        startStep: Int = ClimaxHangContract.startStep,
        endStep: Int = ClimaxHangContract.endStep
    ) {
        self.relation = relation
        self.startStep = startStep
        self.endStep = endStep
    }
}

/// Resolves only from the existing paid-debt kick-syntax arc. The role and
/// exact macro position together prove that the next bar is the established
/// structural recovery; no independent break sequencer is introduced.
package enum ClimaxHangResolver {
    package static func articulation(
        kind: AutonomousPhraseKind,
        character: PerformanceCharacter,
        gesture: ArrangementGesture,
        kickSyntaxRole: KickSyntaxRole,
        absoluteBar: Int
    ) -> ClimaxHangArticulation? {
        guard kind == .energyRelease,
              character == .peakDrive || character == .acidPressure,
              gesture == .steady,
              kickSyntaxRole == .withheld,
              positiveModulo(absoluteBar, 16) ==
                ClimaxHangContract.macroPosition else {
            return nil
        }
        return ClimaxHangArticulation()
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
