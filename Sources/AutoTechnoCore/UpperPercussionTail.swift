/// Semantic tail relationship for an already-arbitrated upper-percussion
/// score event. The neutral role preserves the current event body; foreground
/// clearance retains its attack while making room for another focused role.
package enum UpperPercussionTailRole: String, CaseIterable, Sendable {
    case naturalBody
    case foregroundClearance
}

package struct UpperPercussionTailArticulation: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let voice: EnsembleVoice
    package let step: Int
    package let role: UpperPercussionTailRole

    package init(
        scoreEventIndex: Int,
        voice: EnsembleVoice,
        step: Int,
        role: UpperPercussionTailRole
    ) {
        self.scoreEventIndex = max(0, scoreEventIndex)
        self.voice = voice
        self.step = ((step % 16) + 16) % 16
        self.role = role
    }
}

/// Projects the final arbitrated score rather than proposal metadata, so a
/// relocated or removed event cannot retain stale tail intent.
package enum UpperPercussionTailResolver {
    package static let maximumEventCount = 4

    package static func articulations(
        from ensemble: EnsembleContext,
        phraseKind: AutonomousPhraseKind
    ) -> [UpperPercussionTailArticulation] {
        let useForegroundClearance = phraseKind != .identityReturn &&
            ensemble.focusRole != .percussion &&
            !ensemble.intentionalPileup
        let role: UpperPercussionTailRole = useForegroundClearance ?
            .foregroundClearance : .naturalBody

        var result: [UpperPercussionTailArticulation] = []
        result.reserveCapacity(maximumEventCount)
        for (scoreEventIndex, event) in ensemble.events.enumerated() {
            guard event.voice == .clap ||
                    event.voice == .openHat ||
                    event.voice == .metallic else {
                continue
            }
            guard result.count < maximumEventCount else { break }
            result.append(UpperPercussionTailArticulation(
                scoreEventIndex: scoreEventIndex,
                voice: event.voice,
                step: event.step,
                role: role
            ))
        }
        return result
    }
}
