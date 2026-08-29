/// Versioned boundary policy for bounded treatments of already-accepted PCM
/// while a successor remains unavailable. The director remains the musical
/// owner: transports only apply this decision to immutable PCM at a phrase
/// boundary.
package enum RepeatHoldEvolutionContract {
    package static let version = "autotechno-repeat-hold-evolution.v4"
    package static let activationRepeatCount = 2
}

package enum RepeatHoldEvolutionEffectKind: String, Codable, Hashable,
    Sendable {
    case filter
    case looper
    case deckChain = "deck-chain"
}

package enum RepeatHoldEvolutionTarget: String, Codable, Hashable, Sendable {
    case wholeMix = "whole-mix"
    case protectedRhythm = "protected-rhythm"
    case melodicRemainder = "melodic-remainder"
    case upperPercussion = "upper-percussion"
    case kick
}

/// Five deliberately different deck-scale chains. Every family intersects a
/// whole-mix filter gesture with a loop on a musically narrower target. Their
/// order moves from a one-bar full-mix memory through rhythm and melodic cuts
/// into percussion and kick micro-edits down to one thirty-second note.
package enum RepeatHoldEvolutionPatternFamily: String, CaseIterable, Codable,
    Hashable, Sendable {
    case oneBarCarousel = "loop-1-bar-whole-mix-carousel"
    case halfBarSwitchback = "loop-1-2-bar-rhythm-switchback"
    case quarterBarMelodyRatchet = "loop-1-4-bar-melody-ratchet"
    case percussionMicroCascade = "loop-1-8-1-16-1-32-percussion-cascade"
    case kickPunchCut = "loop-1-16-1-32-kick-punch-cut"

    package var effectKind: RepeatHoldEvolutionEffectKind {
        .deckChain
    }

    package var target: RepeatHoldEvolutionTarget {
        switch self {
        case .oneBarCarousel: .wholeMix
        case .halfBarSwitchback: .protectedRhythm
        case .quarterBarMelodyRatchet: .melodicRemainder
        case .percussionMicroCascade: .upperPercussion
        case .kickPunchCut: .kick
        }
    }
}

package enum RepeatHoldEvolutionPlaybackMode: Equatable, Sendable {
    case exactAcceptedPCM
    case qualifiedPattern(RepeatHoldEvolutionPatternFamily)

    /// Live feedback may only attribute captured PCM to the canonical accepted
    /// render. The bounded fallback has separate evidence and is deliberately
    /// excluded from that controller's source ledger.
    package var participatesInCanonicalLiveFeedback: Bool {
        self == .exactAcceptedPCM
    }

    package var patternFamily: RepeatHoldEvolutionPatternFamily? {
        guard case let .qualifiedPattern(patternFamily) = self else {
            return nil
        }
        return patternFamily
    }
}

package enum RepeatHoldEvolutionBoundaryPolicy {
    package static func decide(
        coherentRepeatCount: Int,
        successorPrepared: Bool,
        qualifiedPatternFamilies: [RepeatHoldEvolutionPatternFamily],
        exactAcceptedPCMRequired: Bool = false
    ) -> RepeatHoldEvolutionPlaybackMode {
        guard !exactAcceptedPCMRequired,
              !successorPrepared,
              coherentRepeatCount >=
                RepeatHoldEvolutionContract.activationRepeatCount,
              !qualifiedPatternFamilies.isEmpty else {
            return .exactAcceptedPCM
        }
        let qualified = RepeatHoldEvolutionPatternFamily.allCases.filter {
            qualifiedPatternFamilies.contains($0)
        }
        guard !qualified.isEmpty else { return .exactAcceptedPCM }
        let ordinal = coherentRepeatCount -
            RepeatHoldEvolutionContract.activationRepeatCount
        return .qualifiedPattern(qualified[ordinal % qualified.count])
    }
}
