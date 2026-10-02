import AutoTechnoCore
import AutoTechnoDSP

struct CanonicalJourneyPlanCheckpoint: Codable, Equatable {
    let checkpoint: CanonicalJourneyCheckpoint
    let phraseIndex: Int
    let startBar: Int
    let phraseKind: AutonomousPhraseKind
    let qualityRevision: Int
    let resolvedBarCount: Int
    let planFingerprint: String
    let fixtureFingerprint: String
    let continuationFingerprint: String
}

struct CanonicalCalibrationWindowFixture: Codable, Equatable {
    let ordinal: Int
    let rootSeed: UInt64
    let planned: CanonicalJourneyPlanCheckpoint
    let followingRelease: CanonicalJourneyPlanCheckpoint
}

/// A fresh outcome-blind trajectory retains every selected score checkpoint,
/// including the optional inherited four-bar major-break requirement.
struct CanonicalCalibrationCoverageFixture: Codable, Equatable {
    let ordinal: Int
    let rootSeed: UInt64
    let requiredMajorBreakBarCount: Int?
    let checkpoints: [CanonicalJourneyPlanCheckpoint]
}

/// Test-only canonical-journey harness. It discovers structural checkpoints by
/// advancing the real director/continuation, while report construction remains
/// an adapter for checkpoints that were actually rendered by a test.
struct CanonicalJourneyQualificationHarness {
    let engineVersion: String
    let routeFingerprint: String
    let routeGeneration: Int

    /// Streams the real director and continuation through the Core-owned,
    /// descriptive trajectory accumulator. It does not render, qualify, or
    /// feed the report back into phrase selection.
    func semanticTrajectoryReport(
        director: AutonomousSessionDirector,
        startingState: AutonomousSessionState? = nil,
        requestedBarCount: Int
    ) -> LongHorizonSemanticTrajectoryReport {
        var state = startingState ?? director.initialState()
        var accumulator = LongHorizonSemanticTrajectoryAccumulator(
            startingState: state
        )
        let nonnegativeRequest = max(0, requestedBarCount)
        let targetBar = state.memory.totalBars > Int.max - nonnegativeRequest
            ? Int.max : state.memory.totalBars + nonnegativeRequest

        while state.memory.totalBars < targetBar {
            let plan = director.plan(from: state)
            guard accumulator.observe(plan: plan, incomingState: state) == .accepted
            else { return accumulator.report() }
            state.advancePlanning(using: plan)
        }
        return accumulator.report()
    }

    func planCheckpoints(
        director: AutonomousSessionDirector,
        startingState: AutonomousSessionState? = nil,
        maximumPhrases: Int = 128,
        requiredBarCounts: [CanonicalJourneyCheckpoint: Int] = [:]
    ) -> [CanonicalJourneyPlanCheckpoint] {
        var state = startingState ?? director.initialState()
        guard state.rootSeed == director.rootSeed else { return [] }
        var result: [CanonicalJourneyPlanCheckpoint] = []
        var previousChapter: InterlockChapter?

        func contains(_ checkpoint: CanonicalJourneyCheckpoint) -> Bool {
            result.contains { $0.checkpoint == checkpoint }
        }
        func candidate(
            _ checkpoint: CanonicalJourneyCheckpoint,
            plan: AutonomousPhrasePlan,
            state: AutonomousSessionState
        ) -> CanonicalJourneyPlanCheckpoint {
            CanonicalJourneyPlanCheckpoint(
                checkpoint: checkpoint,
                phraseIndex: plan.phraseIndex,
                startBar: plan.startBar,
                phraseKind: plan.kind,
                qualityRevision: state.quality.revision,
                resolvedBarCount: plan.resolvedBars.count,
                planFingerprint: AutonomousCandidateFingerprint.plan(plan),
                fixtureFingerprint: [
                    "seed-\(state.rootSeed)",
                    "phrase-\(plan.phraseIndex)",
                    "bar-\(plan.startBar)",
                    "kind-\(plan.kind.rawValue)",
                ].joined(separator: "."),
                continuationFingerprint: [
                    "phrase-\(state.phraseIndex)",
                    "bars-\(state.memory.totalBars)",
                    "quality-r\(state.quality.revision)",
                ].joined(separator: ".")
            )
        }

        for _ in 0..<max(1, maximumPhrases) {
            let plan = director.plan(from: state)
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let changesInsidePhrase = zip(chapters, chapters.dropFirst()).contains { pair in
                pair.0 != pair.1
            }
            let changesAtBoundary = previousChapter.map { previous in
                chapters.first.map { $0 != previous } ?? false
            } ?? false
            let checkpoints = CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: changesInsidePhrase || changesAtBoundary
            )

            for checkpoint in checkpoints where !contains(checkpoint) {
                if checkpoint == .release, requiredBarCounts[.majorBreak] != nil,
                   !contains(.majorBreak) { continue }
                if let required = requiredBarCounts[checkpoint],
                   plan.resolvedBars.count != required { continue }
                result.append(candidate(checkpoint, plan: plan, state: state))
            }
            previousChapter = chapters.last ?? previousChapter
            state.advancePlanning(using: plan)
            if CanonicalJourneyCheckpoint.allCases.allSatisfy(contains) { break }
        }
        return result
    }

    /// Freeze score geometry before PCM or evaluator outcomes are available.
    /// Reuse the original ordinal-to-root bijection; disjoint ordinal ranges
    /// and explicit exclusions preserve development/holdout independence.
    func windowFixtures(
        ordinals: Range<Int>,
        checkpoint: CanonicalJourneyCheckpoint,
        resolvedBarCount: Int,
        requestedCount: Int,
        excludedRoots: Set<UInt64>
    ) -> [CanonicalCalibrationWindowFixture] {
        guard ordinals.lowerBound >= 0, ordinals.count <= 256,
              (1...16).contains(resolvedBarCount),
              (1...4).contains(requestedCount) else { return [] }
        var fixtures: [CanonicalCalibrationWindowFixture] = []
        for ordinal in ordinals {
            let root = Self.windowRootSeed(ordinal)
            guard !excludedRoots.contains(root) else { continue }
            let checkpoints = planCheckpoints(
                director: AutonomousSessionDirector(rootSeed: root),
                requiredBarCounts: [checkpoint: resolvedBarCount]
            )
            guard checkpoints.count == CanonicalJourneyCheckpoint.allCases.count,
                  let planned = checkpoints.first(where: { $0.checkpoint == checkpoint }),
                  planned.resolvedBarCount == resolvedBarCount,
                  let release = checkpoints.first(where: { $0.checkpoint == .release }),
                  release.phraseIndex > planned.phraseIndex else { continue }
            fixtures.append(CanonicalCalibrationWindowFixture(
                ordinal: ordinal, rootSeed: root, planned: planned, followingRelease: release
            ))
            if fixtures.count == requestedCount { break }
        }
        // Insufficient support never becomes a smaller accepted population.
        return fixtures.count == requestedCount ? fixtures : []
    }

    /// Same bijective ordinal schedule as the original AT-0039 cohort, kept
    /// independent of the platform-specific local capture writer.
    static func windowRootSeed(_ ordinal: Int) -> UInt64 {
        precondition(ordinal >= 0)
        var value = UInt64(0x6175746f74656368)
            &+ (UInt64(ordinal) &+ 1) &* 0x9e3779b97f4a7c15
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }

    /// Select complete score journeys first, then the first remaining roots
    /// satisfying the inherited four-bar quota. No render, measurement,
    /// availability result or evaluator participates in this selection.
    func coverageFixtures(
        ordinals: Range<Int>, generalCount: Int, fourBarCount: Int,
        excludedRoots: Set<UInt64>
    ) -> [CanonicalCalibrationCoverageFixture] {
        guard ordinals.lowerBound >= 0, ordinals.count <= 256,
              (1...40).contains(generalCount), (0...4).contains(fourBarCount),
              generalCount + fourBarCount <= 48 else { return [] }
        var result: [CanonicalCalibrationCoverageFixture] = []
        for ordinal in ordinals {
            let root = Self.windowRootSeed(ordinal)
            guard !excludedRoots.contains(root) else { continue }
            let checkpoints = planCheckpoints(
                director: AutonomousSessionDirector(rootSeed: root))
            guard checkpoints.count == CanonicalJourneyCheckpoint.allCases.count
            else { continue }
            result.append(.init(ordinal: ordinal, rootSeed: root,
                requiredMajorBreakBarCount: nil, checkpoints: checkpoints))
            if result.count == generalCount { break }
        }
        guard result.count == generalCount else { return [] }
        if fourBarCount > 0 {
            let windows = windowFixtures(ordinals: ordinals,
                checkpoint: .majorBreak, resolvedBarCount: 4,
                requestedCount: fourBarCount,
                excludedRoots: excludedRoots.union(result.map(\.rootSeed)))
            guard windows.count == fourBarCount else { return [] }
            for window in windows {
                let checkpoints = planCheckpoints(
                    director: AutonomousSessionDirector(rootSeed: window.rootSeed),
                    requiredBarCounts: [.majorBreak: 4])
                guard checkpoints.first(where: { $0.checkpoint == .majorBreak }) == window.planned,
                      checkpoints.first(where: { $0.checkpoint == .release }) == window.followingRelease
                else { return [] }
                result.append(.init(ordinal: window.ordinal, rootSeed: window.rootSeed,
                    requiredMajorBreakBarCount: 4, checkpoints: checkpoints))
            }
        }
        return result.sorted { $0.ordinal < $1.ordinal }
    }

    func report(
        checkpoint: CanonicalJourneyCheckpoint,
        prepared: PreparedAutonomousPhrase,
        fixtureFingerprint: String,
        continuationFingerprint: String
    ) throws -> CanonicalJourneyQualificationReport {
        try CanonicalJourneyQualificationReport(
            engineVersion: engineVersion,
            policyVersion: prepared.qualityDecision.policyVersion,
            fixtureFingerprint: fixtureFingerprint,
            continuationFingerprint: continuationFingerprint,
            checkpoint: checkpoint,
            routeFingerprint: routeFingerprint,
            routeGeneration: routeGeneration,
            selectedCandidateEvidence: prepared.selectedCandidateEvidence,
            candidateEvaluation: prepared.candidateEvaluation,
            commitProvenance: prepared.commitProvenance,
            sampleHash: prepared.audioPreflight.quality.sampleHash,
            decision: prepared.qualityDecision,
            incomingState: prepared.incomingQualityState,
            outgoingState: prepared.qualityContinuationState,
            usedHomeTimbreCorrection: prepared.usedHomeTimbreCorrection,
            correctionRenderCount: prepared.correctionRenderCount
        )
    }

    func reportBank(
        reports: [CanonicalJourneyQualificationReport]
    ) throws -> ProfessionalEvidenceReportBank {
        try ProfessionalEvidenceReportBank(reports: reports)
    }
}
