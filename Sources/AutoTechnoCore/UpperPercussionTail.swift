/// Semantic tail relationship for an already-arbitrated upper-percussion
/// score event. The neutral role preserves the current event body; foreground
/// clearance retains its attack while making room for another focused role.
package enum UpperPercussionTailRole: String, CaseIterable, Sendable {
    case naturalBody
    case foregroundClearance
}

/// Score-owned physical body for the existing upper-percussion event. The
/// native value is an explicit no-op for hat and metallic voices; clap, snare,
/// and rim remain articulations of the one already-arbitrated clap event rather
/// than additional voices or an alternative drum engine.
package enum UpperPercussionBody: String, CaseIterable, Sendable {
    case native
    case clap
    case snare
    case rim
}

package struct UpperPercussionTailArticulation: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let voice: EnsembleVoice
    package let step: Int
    package let role: UpperPercussionTailRole
    package let body: UpperPercussionBody

    package init(
        scoreEventIndex: Int,
        voice: EnsembleVoice,
        step: Int,
        role: UpperPercussionTailRole,
        body: UpperPercussionBody? = nil
    ) {
        self.scoreEventIndex = max(0, scoreEventIndex)
        self.voice = voice
        self.step = ((step % 16) + 16) % 16
        self.role = role
        self.body = body ?? (voice == .clap ? .clap : .native)
    }
}

/// Projects the final arbitrated score rather than proposal metadata, so a
/// relocated or removed event cannot retain stale tail intent.
package enum UpperPercussionTailResolver {
    package static let maximumEventCount = 4

    package static func articulations(
        from ensemble: EnsembleContext,
        phraseKind: AutonomousPhraseKind,
        performanceCharacter: PerformanceCharacter = .hypnoticLock
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
                role: role,
                body: body(
                    voice: event.voice,
                    phraseKind: phraseKind,
                    performanceCharacter: performanceCharacter
                )
            ))
        }
        return result
    }

    private static func body(
        voice: EnsembleVoice,
        phraseKind: AutonomousPhraseKind,
        performanceCharacter: PerformanceCharacter
    ) -> UpperPercussionBody {
        guard voice == .clap else { return .native }
        guard phraseKind != .identityReturn else { return .clap }
        return switch performanceCharacter {
        case .peakDrive:
            .snare
        case .brokenSuspension, .ambientDrift:
            .rim
        case .hypnoticLock, .acidPressure, .melodicGlow:
            .clap
        }
    }
}
