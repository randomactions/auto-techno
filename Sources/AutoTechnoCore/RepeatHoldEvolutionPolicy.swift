/// Versioned boundary policy for bounded treatments of already-accepted PCM
/// while a successor remains unavailable. The director remains the musical
/// owner: transports only apply this decision to immutable PCM at a phrase
/// boundary.
package enum RepeatHoldEvolutionContract {
    package static let version = "autotechno-repeat-hold-evolution.v2"
    package static let activationRepeatCount = 2
}

/// Three deliberately different phrase-scale gestures which reuse the same
/// protected low-pass capability. Their order describes a coherent long-hold
/// sentence: first one breath, then a more rhythmic answer, then a late veil.
package enum RepeatHoldEvolutionPatternFamily: String, CaseIterable, Codable,
    Hashable, Sendable {
    case deepBreath = "deep-breath"
    case twinPulse = "twin-pulse"
    case lateVeil = "late-veil"
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
