import Foundation

/// Phrase-local rhythmic meaning for the existing protected foundation voice.
/// The relation changes only the already-owned foundation lane; it never
/// creates a second bass track, transport clock, or effect route.
package enum FoundationRhythmicRelation: String, CaseIterable, Sendable {
    case established
    case dottedThreeSixteenth = "dotted-three-sixteenth"
}

/// One bounded two-bar dotted cell. The kick remains the physical anchor at
/// coincident low-end positions, so the bass realizes only the complementary
/// steps while the underlying three-sixteenth phase continues across the bar.
package enum FoundationRhythmicRelationContract {
    package static let cellLengthInBars = 2
    package static let intervalInSteps = 3
    package static let requiredKickSteps = [0, 4, 8, 12]
    package static let firstBarBassSteps = [3, 6, 9, 15]
    package static let secondBarBassSteps = [2, 5, 11, 14]

    package static func pairPhase(absoluteBar: Int) -> Int {
        positiveModulo(absoluteBar, cellLengthInBars)
    }

    package static func bassSteps(pairPhase: Int) -> [Int] {
        pairPhase == 0 ? firstBarBassSteps : secondBarBassSteps
    }

    package static func stepMask(pairPhase: Int) -> UInt16 {
        bassSteps(pairPhase: pairPhase).reduce(UInt16(0)) { mask, step in
            mask | (UInt16(1) << UInt16(step))
        }
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

/// Applies the relation only after the director has resolved and arbitrated a
/// complete phrase. This keeps every non-bass event byte-for-byte stable and
/// allows admission only when both bars of the cell fit the immutable phrase.
package enum FoundationRhythmicRelationResolver {
    package static func resolve(
        resolvedBars: [ResolvedPerformanceBar],
        kind: AutonomousPhraseKind,
        dna: SceneDNA
    ) -> [ResolvedPerformanceBar] {
        guard kind == .lock, resolvedBars.count <= 16 else {
            return resolvedBars
        }
        var result = resolvedBars
        var index = 0
        while index + 1 < resolvedBars.count {
            let first = resolvedBars[index]
            let second = resolvedBars[index + 1]
            guard pairIsEligible(first, second: second) else {
                index += 1
                continue
            }
            let firstSteps = FoundationRhythmicRelationContract.firstBarBassSteps
            let secondSteps = FoundationRhythmicRelationContract.secondBarBassSteps
            guard canReplaceBass(in: first, with: firstSteps),
                  canReplaceBass(in: second, with: secondSteps) else {
                index += 2
                continue
            }
            result[index] = replacingBass(
                in: first,
                with: firstSteps,
                phraseKind: kind,
                dna: dna
            )
            result[index + 1] = replacingBass(
                in: second,
                with: secondSteps,
                phraseKind: kind,
                dna: dna
            )
            index += 2
        }
        return result
    }

    private static func pairIsEligible(
        _ first: ResolvedPerformanceBar,
        second: ResolvedPerformanceBar
    ) -> Bool {
        let firstPerformance = first.performance
        let secondPerformance = second.performance
        guard firstPerformance.bar >= 0,
              firstPerformance.bar < Int.max,
              secondPerformance.bar == firstPerformance.bar + 1,
              firstPerformance.localBar >= 0,
              secondPerformance.localBar == firstPerformance.localBar + 1,
              firstPerformance.phrase == secondPerformance.phrase,
              firstPerformance.phraseLength == secondPerformance.phraseLength,
              firstPerformance.phraseLength <= 16,
              FoundationRhythmicRelationContract.pairPhase(
                absoluteBar: firstPerformance.bar
              ) == 0,
              positiveModulo(firstPerformance.bar, 4) == 0 else {
            return false
        }
        return barIsEligible(first) && barIsEligible(second)
    }

    private static func barIsEligible(_ bar: ResolvedPerformanceBar) -> Bool {
        guard bar.foundationRhythmicRelation == .established,
              bar.performanceCharacter == .hypnoticLock,
              bar.foundationBehavior == .monotone,
              bar.foundationCompanion == .bass,
              bar.arrangementGesture == .steady,
              bar.kickSyntaxRole == .grounded,
              bar.performance.roles.contains(.foundation),
              !bar.performance.transformations.contains(.omit),
              bar.ensemble.kickAnchors ==
                FoundationRhythmicRelationContract.requiredKickSteps else {
            return false
        }
        return bar.ensemble.events.contains { $0.voice == .bass }
    }

    private static func canReplaceBass(
        in resolved: ResolvedPerformanceBar,
        with steps: [Int]
    ) -> Bool {
        let nonBassEvents = resolved.ensemble.events.filter { $0.voice != .bass }
        let maximumAtOneStep = resolved.ensemble.intentionalPileup ? 6 : 3
        let occupancy = Dictionary(grouping: nonBassEvents) { $0.step }
        return steps.count == 4 && Set(steps).count == steps.count &&
            steps.allSatisfy { step in
                (0..<16).contains(step) &&
                    !resolved.ensemble.kickAnchors.contains(step) &&
                    (occupancy[step]?.count ?? 0) < maximumAtOneStep
            }
    }

    private static func replacingBass(
        in resolved: ResolvedPerformanceBar,
        with steps: [Int],
        phraseKind: AutonomousPhraseKind,
        dna: SceneDNA
    ) -> ResolvedPerformanceBar {
        let sourceEvents = resolved.ensemble.events
        let firstBassIndex = sourceEvents.firstIndex { $0.voice == .bass } ??
            sourceEvents.count
        let bassIntensity = sourceEvents.first { $0.voice == .bass }?.intensity ?? 0.74
        var events = sourceEvents.filter { $0.voice != .bass }
        let insertionIndex = min(firstBassIndex, events.count)
        events.insert(contentsOf: steps.map {
            EnsembleResolvedEvent(
                voice: .bass,
                step: $0,
                intensity: bassIntensity,
                relocated: false
            )
        }, at: insertionIndex)
        let ensemble = EnsembleContext(
            focusRole: resolved.ensemble.focusRole,
            events: events,
            kickAnchors: resolved.ensemble.kickAnchors,
            intentionalPileup: resolved.ensemble.intentionalPileup
        )
        return ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            performanceCharacter: resolved.performanceCharacter,
            foundationBehavior: resolved.foundationBehavior,
            foundationRhythmicRelation: .dottedThreeSixteenth,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            closedHatDecayArticulations: ClosedHatDecayResolver.articulations(
                from: ensemble
            ),
            upperPercussionTailArticulations:
                UpperPercussionTailResolver.articulations(
                    from: ensemble,
                    phraseKind: phraseKind
                ),
            modalPercussionArticulations:
                ModalPercussionResolver.foundationArticulations(
                    ensemble: ensemble,
                    dna: dna,
                    performance: resolved.performance,
                    character: resolved.performanceCharacter,
                    gesture: resolved.arrangementGesture,
                    behavior: resolved.foundationBehavior
                ),
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative,
            kickSyntaxRole: resolved.kickSyntaxRole,
            percussionEchoTexture: PercussionEchoTextureResolver.articulation(
                ensemble: ensemble,
                kind: phraseKind,
                character: resolved.performanceCharacter,
                gesture: resolved.arrangementGesture,
                kickSyntaxRole: resolved.kickSyntaxRole,
                absoluteBar: resolved.performance.bar
            )
        )
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
