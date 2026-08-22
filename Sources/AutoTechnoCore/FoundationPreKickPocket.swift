import Foundation

/// Durable score meaning for an existing foundation event yielding the final
/// low-end interval before an already-owned kick. The articulation adds no
/// onset, instrument, track, clock, effect, or persistent state.
package enum FoundationPreKickPocketRelation: String, Codable, Equatable, Sendable {
    case preKickClearance = "pre-kick-clearance"
}

package enum FoundationPreKickPocketContract {
    /// The current state-free release begins three sixteenths of one score step
    /// before the kick. This is renderer realization v1, not a musical target.
    package static let releaseLeadInSteps = 0.1875
    /// The event reaches exact zero one sixteenth of one score step before the
    /// kick, leaving a bounded dry-foundation pocket.
    package static let silenceLeadInSteps = 0.0625
    package static let maximumArticulationsPerBar = 1
}

package struct FoundationPreKickPocketArticulation:
    Codable, Equatable, Sendable
{
    package let relation: FoundationPreKickPocketRelation
    package let scoreEventIndex: Int
    package let bassStep: Int
    package let kickStep: Int
    package let releaseStartStep: Double
    package let releaseEndStep: Double

    package init(
        scoreEventIndex: Int,
        bassStep: Int,
        kickStep: Int,
        releaseStartStep: Double,
        releaseEndStep: Double
    ) {
        relation = .preKickClearance
        self.scoreEventIndex = scoreEventIndex
        self.bassStep = bassStep
        self.kickStep = kickStep
        self.releaseStartStep = releaseStartStep
        self.releaseEndStep = releaseEndStep
    }
}

/// Derives one fail-closed articulation from the exact already-resolved dotted
/// score. The renderer consumes this immutable fact; it never rediscovers a
/// musical relation from PCM or runs another sequencer.
package enum FoundationPreKickPocketResolver {
    package static func articulation(
        in resolved: ResolvedPerformanceBar
    ) -> FoundationPreKickPocketArticulation? {
        guard resolved.foundationRhythmicRelation == .dottedThreeSixteenth,
              resolved.performanceCharacter == .hypnoticLock,
              resolved.foundationBehavior == .monotone,
              resolved.foundationCompanion == .bass,
              resolved.arrangementGesture == .steady,
              resolved.kickSyntaxRole == .grounded,
              resolved.performance.roles.contains(.foundation),
              !resolved.performance.transformations.contains(.omit),
              resolved.ensemble.kickAnchors ==
                FoundationRhythmicRelationContract.requiredKickSteps else {
            return nil
        }

        let candidates = resolved.ensemble.events.enumerated().compactMap {
            index, event -> FoundationPreKickPocketArticulation? in
            guard event.voice == .bass,
                  (0..<15).contains(event.step),
                  resolved.ensemble.kickAnchors.contains(event.step + 1) else {
                return nil
            }
            let kickStep = event.step + 1
            return FoundationPreKickPocketArticulation(
                scoreEventIndex: index,
                bassStep: event.step,
                kickStep: kickStep,
                releaseStartStep: Double(kickStep) -
                    FoundationPreKickPocketContract.releaseLeadInSteps,
                releaseEndStep: Double(kickStep) -
                    FoundationPreKickPocketContract.silenceLeadInSteps
            )
        }
        guard candidates.count ==
                FoundationPreKickPocketContract.maximumArticulationsPerBar,
              let articulation = candidates.first else {
            return nil
        }
        let phase = FoundationRhythmicRelationContract.pairPhase(
            absoluteBar: resolved.performance.bar
        )
        let expectedBassStep = phase == 0 ? 3 : 11
        let expectedKickStep = phase == 0 ? 4 : 12
        guard articulation.bassStep == expectedBassStep,
              articulation.kickStep == expectedKickStep else {
            return nil
        }
        return articulation
    }
}
