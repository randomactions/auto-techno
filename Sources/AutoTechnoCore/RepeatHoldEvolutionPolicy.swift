/// Versioned boundary policy for the one bounded treatment of already-
/// accepted PCM while a successor remains unavailable. The director remains
/// the musical owner: transports only apply this decision to immutable PCM at
/// a phrase boundary.
package enum RepeatHoldEvolutionContract {
    package static let version = "autotechno-repeat-hold-evolution.v1"
    package static let activationRepeatCount = 2
}

package enum RepeatHoldEvolutionPlaybackMode: String, Equatable, Sendable {
    case exactAcceptedPCM = "exact-accepted-pcm"
    case qualifiedLowPass = "qualified-low-pass"

    /// Live feedback may only attribute captured PCM to the canonical accepted
    /// render. The bounded fallback has separate evidence and is deliberately
    /// excluded from that controller's source ledger.
    package var participatesInCanonicalLiveFeedback: Bool {
        self == .exactAcceptedPCM
    }
}

package enum RepeatHoldEvolutionBoundaryPolicy {
    package static func decide(
        coherentRepeatCount: Int,
        successorPrepared: Bool,
        qualifiedVariantAvailable: Bool,
        exactAcceptedPCMRequired: Bool = false
    ) -> RepeatHoldEvolutionPlaybackMode {
        guard !exactAcceptedPCMRequired,
              !successorPrepared,
              coherentRepeatCount >=
                RepeatHoldEvolutionContract.activationRepeatCount,
              qualifiedVariantAvailable else {
            return .exactAcceptedPCM
        }
        return .qualifiedLowPass
    }
}
