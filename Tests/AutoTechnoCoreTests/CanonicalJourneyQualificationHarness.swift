import AutoTechnoCore
import AutoTechnoDSP

struct CanonicalJourneyPlanCheckpoint: Equatable {
    let checkpoint: CanonicalJourneyCheckpoint
    let phraseIndex: Int
    let startBar: Int
    let phraseKind: AutonomousPhraseKind
    let qualityRevision: Int
    let fixtureFingerprint: String
    let continuationFingerprint: String
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
        maximumPhrases: Int = 128
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
                result.append(candidate(checkpoint, plan: plan, state: state))
            }
            previousChapter = chapters.last ?? previousChapter
            state.advancePlanning(using: plan)
            if CanonicalJourneyCheckpoint.allCases.allSatisfy(contains) { break }
        }
        return result
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
