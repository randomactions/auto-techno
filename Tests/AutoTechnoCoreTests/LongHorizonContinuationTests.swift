import AutoTechnoCore
import Foundation
import Testing

@Suite("Long-horizon continuation")
struct LongHorizonContinuationTests {
    @Test("A fresh performance owns one bound, machine-readable hierarchy")
    func freshHierarchyIsBoundAndMachineReadable() throws {
        let continuation = AutonomousSessionDirector(rootSeed: 48_291)
            .initialState().memory.longHorizon
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(continuation)
        let decoded = try JSONDecoder().decode(
            LongHorizonContinuationState.self,
            from: data
        )

        #expect(continuation.isBound)
        #expect(continuation.rootSeed == 48_291)
        #expect(continuation.schemaVersion == 1)
        #expect(continuation.schemaIdentifier == "autotechno-long-horizon-continuation.v1")
        #expect(continuation.currentEpisode.operatorKind == .maintain)
        #expect(continuation.currentEpisode.startedAtBar == 0)
        #expect(continuation.currentEpisode.minimumHoldUntilBar >= 8 * 16)
        #expect(continuation.currentEpisode.dueByBar <= 32 * 16)
        #expect(
            continuation.currentEpisode.minimumHoldUntilBar < continuation.currentEpisode.dueByBar)
        #expect(continuation.arcEpisodeCount >= 3)
        #expect(continuation.arcEpisodeCount <= 6)
        #expect(
            continuation.capabilityRecency.count == LongHorizonSemanticCapability.allCases.count)
        #expect(continuation.characterRecency.count == PerformanceCharacter.allCases.count)
        #expect(continuation.harmonicRecency.count == PadHarmonicFunction.allCases.count)
        #expect(continuation.transformationRecency.count == MusicalTransformation.allCases.count)
        #expect(continuation.lastTrajectoryEvidenceSchema == nil)
        #expect(continuation.lastTrajectoryDecisionReason == "no-calibrated-long-horizon-policy")
        #expect(continuation.fingerprint.count == 16)
        #expect(decoded == continuation)
        #expect(try encoder.encode(decoded) == data)
        let unsupported = try encodedCopy(
            continuation,
            replacing: "schemaIdentifier",
            with: "autotechno-long-horizon-continuation.v999"
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                LongHorizonContinuationState.self,
                from: unsupported
            )
        }
    }

    @Test("Eight hours renew arcs while every retained collection stays bounded")
    func eightHourHierarchyIsRenewableAndBounded() throws {
        let journey = journeySnapshot(rootSeed: 48_291, requestedBars: 15_600)
        let continuation = journey.state.memory.longHorizon
        let operators = Set(
            journey.completedEpisodes.map(\.operatorKind) + [
                continuation.currentEpisode.operatorKind
            ])
        let oversized = try decodedWithOversizedRetainedCollections(continuation)

        print(
            "LONG_HORIZON_CONTINUATION_8H " + "episodes=\(journey.completedEpisodes.count) "
                + "arc=\(continuation.arcIndex) " + "state=\(continuation.fingerprint) "
                + "sequence=\(episodeSequenceFingerprint(journey.completedEpisodes))"
        )

        #expect(journey.state.memory.totalBars >= 15_600)
        #expect(journey.completedEpisodes.count == 75)
        #expect(continuation.arcIndex == 16)
        #expect(continuation.fingerprint == "008b96f48b2e955d")
        #expect(episodeSequenceFingerprint(journey.completedEpisodes) == "ffb454d66004e4bf")
        #expect(operators == Set(LongHorizonEpisodeOperator.allCases))
        #expect(
            journey.completedEpisodes.allSatisfy { episode in
                episode.completedAtBar >= episode.minimumHoldUntilBar
                    && episode.completedAtBar <= episode.dueByBar + 15
                    && episode.minimumHoldUntilBar - episode.startedAtBar >= 8 * 16
                    && episode.dueByBar - episode.startedAtBar <= 32 * 16
            })
        #expect(continuation.recentEpisodes.count <= 8)
        #expect(continuation.recentOperators.count <= 6)
        #expect(continuation.identityLandmarks.count <= 8)
        #expect(continuation.obligations.count <= 8)
        #expect(
            continuation.capabilityRecency.count == LongHorizonSemanticCapability.allCases.count)
        #expect(continuation.characterRecency.count == PerformanceCharacter.allCases.count)
        #expect(
            continuation.capabilityRecency.contains { entry in
                entry.name == LongHorizonSemanticCapability.pulseEcho.rawValue && entry.useCount > 0
                    && entry.lastUsedBar != nil
            })
        #expect(continuation.nextExpectedPhraseIndex == journey.state.phraseIndex)
        #expect(continuation.nextExpectedBar == journey.state.memory.totalBars)
        #expect(
            oversized.recentEpisodes.count == LongHorizonContinuationSchema.recentEpisodeCapacity)
        #expect(
            oversized.recentOperators.count == LongHorizonContinuationSchema.recentOperatorCapacity)
        #expect(
            oversized.identityLandmarks.count
                <= LongHorizonContinuationSchema.identityLandmarkCapacity)
        #expect(oversized.obligations.count <= LongHorizonContinuationSchema.obligationCapacity)
        #expect(oversized.capabilityRecency.count == LongHorizonSemanticCapability.allCases.count)
    }

    @Test("Identical complete state replays exactly while fresh roots vary episode form")
    func replayAndFreshRootVariability() throws {
        let first = journeySnapshot(rootSeed: 48_291, requestedBars: 7_800)
        let replay = journeySnapshot(rootSeed: 48_291, requestedBars: 7_800)
        let alternate = journeySnapshot(rootSeed: 48_292, requestedBars: 7_800)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        print(
            "LONG_HORIZON_CONTINUATION_4H " + "episodes=\(first.completedEpisodes.count) "
                + "arc=\(first.state.memory.longHorizon.arcIndex) "
                + "state=\(first.state.memory.longHorizon.fingerprint) "
                + "sequence=\(episodeSequenceFingerprint(first.completedEpisodes))"
        )

        #expect(first.state == replay.state)
        #expect(first.completedEpisodes == replay.completedEpisodes)
        #expect(first.completedEpisodes.count == 37)
        #expect(first.state.memory.longHorizon.arcIndex == 7)
        #expect(first.state.memory.longHorizon.fingerprint == "9790c22d98b4807e")
        #expect(episodeSequenceFingerprint(first.completedEpisodes) == "a3929317ea4e86ac")
        #expect(
            try encoder.encode(first.state.memory.longHorizon)
                == encoder.encode(replay.state.memory.longHorizon))
        #expect(
            first.state.memory.longHorizon.fingerprint
                == replay.state.memory.longHorizon.fingerprint)
        #expect(
            first.completedEpisodes.map(episodeGeometry)
                != alternate.completedEpisodes.map(episodeGeometry))
        #expect(
            first.state.memory.longHorizon.fingerprint
                != alternate.state.memory.longHorizon.fingerprint)
    }

    @Test("Discontinuous episode context cannot override the local fallback")
    func discontinuousEpisodeContextFallsBack() {
        let base = journeySnapshot(rootSeed: 48_291, requestedBars: 1_950).state
        let later = journeySnapshot(rootSeed: 48_291, requestedBars: 3_900).state
        let baseMemory = base.memory
        let swappedMemory = memory(
            copyingLocalStateFrom: baseMemory,
            longHorizon: later.memory.longHorizon
        )
        var swapped = base
        swapped.memory = swappedMemory
        let director = AutonomousSessionDirector(rootSeed: base.rootSeed)

        #expect(baseMemory.recentBars == swappedMemory.recentBars)
        #expect(baseMemory.currentPhrase == swappedMemory.currentPhrase)
        #expect(baseMemory.previousPhrase == swappedMemory.previousPhrase)
        #expect(baseMemory.dramaticArc == swappedMemory.dramaticArc)
        #expect(baseMemory.sessionBars == swappedMemory.sessionBars)
        #expect(baseMemory.totalBars == swappedMemory.totalBars)
        #expect(baseMemory.openDebts == swappedMemory.openDebts)
        #expect(baseMemory.interlockEvolution == swappedMemory.interlockEvolution)
        #expect(baseMemory.narrativeEvolution == swappedMemory.narrativeEvolution)
        #expect(baseMemory.longHorizon != swappedMemory.longHorizon)
        let basePlan = director.plan(from: base)
        let swappedPlan = director.plan(from: swapped)
        #expect(basePlan.kind == swappedPlan.kind)
        #expect(swappedPlan.longHorizonSelection.reason == .conservativeFallback)
    }

    @Test("Malformed or discontinuous updates preserve the accepted episode transactionally")
    func malformedUpdatesPreserveCurrentEpisode() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let initial = director.initialState()
        let continuation = initial.memory.longHorizon
        let plan = director.plan(from: initial)
        let otherPlan = AutonomousSessionDirector(rootSeed: 9_001)
            .plan(from: AutonomousSessionDirector(rootSeed: 9_001).initialState())
        var advanced = initial
        advanced.advancePlanning(using: plan)
        let nextPlan = director.plan(from: advanced)
        let shiftedState = AutonomousSessionState(
            rootSeed: 48_291,
            phraseIndex: 0,
            memory: TemporalMusicalMemory(totalBars: 4)
        )
        let shiftedPlan = director.plan(from: shiftedState)
        let overflowContinuation = LongHorizonContinuationState.initial(
            rootSeed: 48_291,
            startingPhraseIndex: Int.max
        )
        let overflowPlan = copiedPlan(
            copying: plan,
            phraseIndex: Int.max
        )

        #expect(
            LongHorizonContinuationState.unbound().applying(
                plan: plan,
                rootSeed: 48_291
            ) == .preserved(.unboundState))
        #expect(
            continuation.applying(
                plan: plan,
                rootSeed: 48_292
            ) == .preserved(.rootSeedMismatch))
        #expect(
            continuation.applying(
                plan: nextPlan,
                rootSeed: 48_291
            ) == .preserved(.phraseIndexDiscontinuity))
        #expect(
            continuation.applying(
                plan: shiftedPlan,
                rootSeed: 48_291
            ) == .preserved(.barDiscontinuity))
        #expect(
            continuation.applying(
                plan: otherPlan,
                rootSeed: 48_291
            ) == .preserved(.inconsistentCanonicalPlan))
        #expect(
            overflowContinuation.applying(
                plan: overflowPlan,
                rootSeed: 48_291
            ) == .preserved(.counterOverflow))
        #expect(initial.memory.longHorizon == continuation)
        var rejectedAdvance = initial
        rejectedAdvance.advancePlanning(using: shiftedPlan)
        #expect(rejectedAdvance == initial)
    }

    @Test("A complete new performance renews every reserve and forgets the prior hierarchy")
    func completePerformanceResetGetsFreshHierarchy() {
        let progressed = journeySnapshot(
            rootSeed: 48_291,
            requestedBars: 1_950
        ).state.memory.longHorizon
        let fresh = AutonomousSessionDirector(rootSeed: 90_001)
            .initialState().memory.longHorizon

        #expect(progressed.nextExpectedBar >= 1_950)
        #expect(progressed.capabilityRecency.contains { $0.useCount > 0 })
        #expect(fresh.rootSeed == 90_001)
        #expect(fresh.nextExpectedPhraseIndex == 0)
        #expect(fresh.nextExpectedBar == 0)
        #expect(fresh.arcIndex == 0)
        #expect(fresh.currentEpisode.operatorKind == .maintain)
        #expect(fresh.recentEpisodes.isEmpty)
        #expect(fresh.obligations.isEmpty)
        #expect(fresh.identityLandmarks.isEmpty)
        #expect(fresh.reserve.availableCount == 3)
        #expect(fresh.capabilityRecency.allSatisfy { $0.useCount == 0 })
        #expect(fresh.fingerprint != progressed.fingerprint)
    }
}

private struct LongHorizonJourneySnapshot {
    let state: AutonomousSessionState
    let completedEpisodes: [LongHorizonCompletedEpisode]
}

private func journeySnapshot(
    rootSeed: UInt64,
    requestedBars: Int
) -> LongHorizonJourneySnapshot {
    let director = AutonomousSessionDirector(rootSeed: rootSeed)
    var state = director.initialState()
    var completed: [LongHorizonCompletedEpisode] = []
    while state.memory.totalBars < requestedBars {
        let priorEpisode = state.memory.longHorizon.currentEpisode.id
        let plan = director.plan(from: state)
        state.advancePlanning(using: plan)
        if state.memory.longHorizon.currentEpisode.id != priorEpisode,
            let episode = state.memory.longHorizon.recentEpisodes.last
        {
            completed.append(episode)
        }
    }
    return LongHorizonJourneySnapshot(state: state, completedEpisodes: completed)
}

private func episodeGeometry(_ episode: LongHorizonCompletedEpisode) -> String {
    [
        episode.operatorKind.rawValue,
        String(episode.minimumHoldUntilBar - episode.startedAtBar),
        String(episode.dueByBar - episode.startedAtBar),
        episode.completionReason.rawValue,
    ].joined(separator: ":")
}

private func episodeSequenceFingerprint(
    _ episodes: [LongHorizonCompletedEpisode]
) -> String {
    var value: UInt64 = 0xcbf2_9ce4_8422_2325
    for episode in episodes {
        for byte in episodeGeometry(episode).utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }
        value ^= 0xff
        value = value &* 0x0000_0100_0000_01b3
    }
    let raw = String(value, radix: 16)
    return String(repeating: "0", count: 16 - raw.count) + raw
}

private func memory(
    copyingLocalStateFrom source: TemporalMusicalMemory,
    longHorizon: LongHorizonContinuationState
) -> TemporalMusicalMemory {
    TemporalMusicalMemory(
        recentBars: source.recentBars,
        currentPhrase: source.currentPhrase,
        previousPhrase: source.previousPhrase,
        dramaticArc: source.dramaticArc,
        sessionBars: source.sessionBars,
        totalBars: source.totalBars,
        lastContrastBar: source.lastContrastBar,
        lastBreakBar: source.lastBreakBar,
        lastReleaseBar: source.lastReleaseBar,
        lastIdentityReturnBar: source.lastIdentityReturnBar,
        topologyRevision: source.topologyRevision,
        openDebts: source.openDebts,
        interlockEvolution: source.interlockEvolution,
        spatialContrast: source.spatialContrast,
        narrativeEvolution: source.narrativeEvolution,
        recentPerformanceCharacters: source.recentPerformanceCharacters,
        harmonicContinuation: source.harmonicContinuation,
        longHorizon: longHorizon
    )
}

private func decodedWithOversizedRetainedCollections(
    _ continuation: LongHorizonContinuationState
) throws -> LongHorizonContinuationState {
    let encoded = try JSONEncoder().encode(continuation)
    guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
        let episodes = object["recentEpisodes"] as? [[String: Any]],
        let operators = object["recentOperators"] as? [String],
        let recency = object["capabilityRecency"] as? [[String: Any]]
    else {
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: [],
                debugDescription: "Expected encoded continuation object"
            ))
    }
    object["recentEpisodes"] = Array(repeating: episodes, count: 4).flatMap { $0 }
    object["recentOperators"] = Array(repeating: operators, count: 4).flatMap { $0 }
    object["capabilityRecency"] = Array(repeating: recency, count: 4).flatMap { $0 }
    let oversized = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(LongHorizonContinuationState.self, from: oversized)
}

private func encodedCopy(
    _ continuation: LongHorizonContinuationState,
    replacing key: String,
    with value: Any
) throws -> Data {
    let encoded = try JSONEncoder().encode(continuation)
    guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: [],
                debugDescription: "Expected encoded continuation object"
            ))
    }
    object[key] = value
    return try JSONSerialization.data(withJSONObject: object)
}

private func copiedPlan(
    copying source: AutonomousPhrasePlan,
    phraseIndex: Int
) -> AutonomousPhrasePlan {
    AutonomousPhrasePlan(
        phraseIndex: phraseIndex,
        startBar: source.startBar,
        barCount: source.barCount,
        kind: source.kind,
        scene: source.scene,
        dna: source.dna,
        resolvedBars: source.resolvedBars,
        openedDebt: source.openedDebt,
        paidDebtIDs: source.paidDebtIDs,
        requestsTopologyMutation: source.requestsTopologyMutation,
        interest: source.interest,
        endingInterlockState: source.endingInterlockState,
        endingSpatialContrastState: source.endingSpatialContrastState,
        endingNarrativeState: source.endingNarrativeState,
        harmonicContinuation: source.incomingHarmonicContinuation
    )
}
