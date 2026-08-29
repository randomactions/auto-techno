import AutoTechnoCore
import Testing

@Suite("Symbolic-interest retry recovery")
struct SymbolicInterestRetryTests {
    @Test("Every long-run phrase has a bounded symbolically valid realization")
    func everyLongRunPhraseHasBoundedRecovery() {
        let roots: [UInt64] = [
            48_291, 13, 89, 610,
        ]

        for rootSeed in roots {
            let director = AutonomousSessionDirector(rootSeed: rootSeed)
            var state = director.initialState()

            for _ in 0..<768 {
                let candidates = (0...AutonomousSessionDirector.maximumQualityRetryOrdinal)
                    .map { director.plan(from: state, qualityRetryOrdinal: $0) }
                guard let selected = candidates.first(where: { $0.interest.valid }) else {
                    let final = candidates[candidates.count - 1]
                    let fields = [
                        "No bounded symbolic recovery",
                        "root=\(rootSeed)",
                        "phrase=\(state.phraseIndex)",
                        "start=\(state.memory.totalBars)",
                        "kind=\(final.kind.rawValue)",
                        "score=\(final.interest.score)",
                        "pulse=\(final.interest.pulseClarity)",
                        "space=\(final.interest.intentionalSpace)",
                        "closure=\(final.interest.responseClosure)",
                        "timely=\(final.interest.structuralTimeliness)",
                        "weak=\(final.interest.weakPositionCoverage)",
                        "trailing=\(final.interest.trailingSideRelationship)",
                        "overactivity=\(final.interest.overactivityPenalty)",
                        "overdue=\(final.interest.overdueDebtCount)",
                    ]
                    var message = ""
                    for field in fields {
                        if !message.isEmpty { message.append(" ") }
                        message.append(field)
                    }
                    Issue.record(Comment(rawValue: message))
                    return
                }
                state.advancePlanning(using: selected)
            }
        }
    }

    @Test("Final recovery reuses minimalization without erasing a macro marker")
    func finalRecoveryOwnsBoundedDensityReduction() {
        let director = AutonomousSessionDirector(rootSeed: 13)
        var state = director.initialState()
        var selectedBaseline: AutonomousPhrasePlan?
        var selectedRecovery: AutonomousPhrasePlan?

        while state.phraseIndex < 768 {
            let baseline = director.plan(from: state)
            let recovery = director.plan(
                from: state,
                qualityRetryOrdinal:
                    AutonomousSessionDirector.maximumQualityRetryOrdinal
            )
            if !baseline.interest.valid && recovery.interest.valid &&
                recovery.interest.intentionalSpace > baseline.interest.intentionalSpace &&
                recovery.interest.overactivityPenalty < baseline.interest.overactivityPenalty &&
                recovery.resolvedBars.allSatisfy({
                    $0.arrangementGesture == .minimalize ||
                        $0.arrangementGesture == .structuralMarker
                }) {
                selectedBaseline = baseline
                selectedRecovery = recovery
                break
            }
            let selected = (0...AutonomousSessionDirector.maximumQualityRetryOrdinal)
                .map { director.plan(from: state, qualityRetryOrdinal: $0) }
                .first { $0.interest.valid }
            #expect(selected != nil)
            guard let selected else { return }
            state.advancePlanning(using: selected)
        }

        guard let baseline = selectedBaseline, let recovery = selectedRecovery else {
            Issue.record("Expected a bounded final minimalization recovery within 768 phrases")
            return
        }

        #expect(!baseline.interest.valid)
        #expect(recovery.interest.valid)
        #expect(recovery.interest.score >= 0.45)
        #expect(recovery.interest.intentionalSpace > baseline.interest.intentionalSpace)
        #expect(recovery.interest.overactivityPenalty < baseline.interest.overactivityPenalty)
        #expect(recovery.resolvedBars.allSatisfy {
            $0.arrangementGesture == .minimalize ||
                $0.arrangementGesture == .structuralMarker
        })
    }
}
