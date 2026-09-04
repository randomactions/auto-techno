import Foundation
import Testing
@testable import AutoTechnoCore

@Suite("Score motif baseline analyzer")
struct ScoreMotifBaselineAnalyzerTests {
    @Test("Exact active bars preserve every symbolic dimension")
    func exactRepeat() throws {
        let motif = [note(0, 0), note(4, 3), note(9, 7)]
        let evidence = try available(phrase([motif, motif]))
        let value = try comparison(evidence)

        #expect(value.exactRecurrence == true)
        #expect(value.onsetRecurrence == true)
        #expect(value.intervalContourRecurrence == true)
        #expect(value.normalizedMotifRecurrence == true)
        #expect(value.transpositionMilliSemitones == 0)
        #expect(value.noteMutationDistance == 0)
        #expect(value.onsetMutationDistance == 0)
        #expect(value.absolutePitchMutationDistance == 0)
        #expect(value.pitchClassMutationDistance == 0)
        #expect(value.intervalMutationDistance == 0)
        #expect(value.roleMutationDistance == 0)
        #expect(value.noteCountDelta == 0)
        #expect(value.densityDelta == 0)
        #expect(value.meanRegisterShiftMIDIMilliNotes == 0)
    }

    @Test("Octave displacement preserves contour and pitch class but exposes register")
    func octaveDisplacement() throws {
        let reference = [note(0, 0), note(4, 3), note(9, 7)]
        let displaced = [note(0, 12), note(4, 15), note(9, 19)]
        let value = try comparison(available(phrase([reference, displaced])))

        #expect(value.exactRecurrence == false)
        #expect(value.intervalContourRecurrence == true)
        #expect(value.normalizedMotifRecurrence == true)
        #expect(value.transpositionMilliSemitones == 12_000)
        #expect(value.absolutePitchMutationDistance == 1)
        #expect(value.pitchClassMutationDistance == 0)
        #expect(value.meanRegisterShiftMIDIMilliNotes == 12_000)
    }

    @Test("Modal transposition stays distinct from exact and pitch-class recurrence")
    func modalTransposition() throws {
        let reference = [note(0, 0), note(4, 3), note(9, 7)]
        let transposed = [note(0, 2), note(4, 5), note(9, 9)]
        let value = try comparison(available(phrase([reference, transposed])))

        #expect(value.intervalContourRecurrence == true)
        #expect(value.normalizedMotifRecurrence == true)
        #expect(value.transpositionMilliSemitones == 2_000)
        #expect(value.absolutePitchMutationDistance == 1)
        #expect(value.pitchClassMutationDistance == 1)
        #expect(value.meanRegisterShiftMIDIMilliNotes == 2_000)
    }

    @Test("Insertion deletion and substitution remain bounded edit facts")
    func editMutations() throws {
        let source = [note(0, 0), note(4, 3), note(9, 7)]
        let inserted = [note(0, 0), note(4, 3), note(7, 5), note(9, 7)]
        let insertion = try comparison(available(phrase([source, inserted])))
        #expect(insertion.noteCountDelta == 1)
        #expect(insertion.noteMutationDistance == 0.25)
        #expect((insertion.densityDelta ?? 0) > 0)

        let deleted = [note(0, 0), note(9, 7)]
        let deletion = try comparison(available(phrase([source, deleted])))
        #expect(deletion.noteCountDelta == -1)
        #expect(deletion.noteMutationDistance == 1.0 / 3.0)

        let substituted = [note(0, 0), note(4, 4), note(9, 7)]
        let substitution = try comparison(available(phrase([source, substituted])))
        #expect(substitution.noteCountDelta == 0)
        #expect(substitution.onsetMutationDistance == 0)
        #expect(substitution.absolutePitchMutationDistance == 1.0 / 3.0)
        #expect(substitution.noteMutationDistance == 1.0 / 3.0)
    }

    @Test("Onset rotation and pitch reorder are separately inspectable")
    func rotationAndReorder() throws {
        let source = [note(0, 0), note(3, 2), note(7, 7), note(10, 5)]
        let rotated = [note(2, 0), note(5, 2), note(9, 7), note(12, 5)]
        let rotation = try comparison(available(phrase([source, rotated])))
        #expect(rotation.onsetMutationDistance == 1)
        #expect(rotation.bestReferenceForwardRotationSteps == 2)
        #expect(rotation.rotationNormalizedOnsetMutationDistance == 0)

        let reordered = [note(0, 7), note(3, 2), note(7, 0), note(10, 5)]
        let order = try comparison(available(phrase([source, reordered])))
        #expect(order.onsetMutationDistance == 0)
        #expect((order.absolutePitchMutationDistance ?? 0) > 0)
        #expect((order.intervalMutationDistance ?? 0) > 0)
    }

    @Test("Rhythm duration and density mutations do not collapse together")
    func rhythmDurationAndDensity() throws {
        let source = [note(0, 0), note(4, 3), note(8, 7)]
        let rhythm = [note(1, 0), note(5, 3), note(9, 7)]
        let rhythmic = try comparison(available(phrase([source, rhythm])))
        #expect(rhythmic.onsetMutationDistance == 1)
        #expect(rhythmic.absolutePitchMutationDistance == 0)
        #expect(rhythmic.noteCountDelta == 0)

        let sustained = [
            note(0, 0, duration: 4), note(4, 3, duration: 4),
            note(8, 7, duration: 4),
        ]
        let duration = try comparison(available(phrase([source, sustained])))
        #expect(duration.onsetMutationDistance == 0)
        #expect(duration.absolutePitchMutationDistance == 0)
        #expect(duration.durationMutationDistance == 1)
        #expect(duration.noteCountDelta == 0)
        #expect(duration.densityDelta == 0)
    }

    @Test("Empty and inactive roles use explicit unavailable states")
    func emptyAndInactive() throws {
        let evidence = try available(phrase([[], []]))
        let combined = try comparison(evidence)
        #expect(combined.availability == .unavailableNoNotesInEitherBar)
        #expect(combined.exactRecurrence == nil)
        #expect(combined.noteMutationDistance == nil)
        #expect(evidence.summary.availableComparisonCount == 0)

        let encoded = try JSONEncoder().encode(evidence)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let bars = try #require(object["bars"] as? [[String: Any]])
        let encodedBar = try #require(bars.first {
            $0["phraseBarIndex"] as? Int == 0 && $0["scope"] as? String == "combined"
        })
        #expect(encodedBar["exactTokenFingerprint"] is NSNull)
        #expect(encodedBar["meanRegisterMIDIMilliNote"] is NSNull)
        let comparisons = try #require(
            object["comparisons"] as? [[String: Any]]
        )
        let encodedComparison = try #require(comparisons.first {
            $0["scope"] as? String == "combined" && $0["lagBars"] as? Int == 1
        })
        #expect(encodedComparison["exactRecurrence"] is NSNull)
        #expect(encodedComparison["noteMutationDistance"] is NSNull)
        let summary = try #require(object["summary"] as? [String: Any])
        #expect(summary["meanNoteMutationDistance"] is NSNull)
        #expect(summary["meanAbsoluteRegisterShiftSemitones"] is NSNull)

        let oneActive = try available(phrase([[note(0, 0)], []]))
        let inactive = try comparison(oneActive)
        #expect(inactive.availability == .unavailableNoNotesInCurrentBar)
        #expect(inactive.noteCountDelta == nil)
    }

    @Test("Arpeggiated duplicates and sustained glides retain exact score data")
    func arpeggiatedAndSustained() throws {
        let bar = [
            note(0, 0, duration: 0.5),
            note(0, 0, duration: 0.5),
            note(2, 4, duration: 0.5),
            note(4, 7, duration: 8, endSemitone: 12, gate: "slide"),
        ]
        let evidence = try available(phrase([bar, bar]))
        let record = try #require(evidence.bars.first {
            $0.phraseBarIndex == 0 && $0.scope == "anchor"
        })
        #expect(record.noteCount == 4)
        #expect(record.tokens[0].ordinal == 0)
        #expect(record.tokens[1].ordinal == 1)
        #expect(record.tokens.last?.durationMilliSteps == 8_000)
        #expect(record.tokens.last?.gate == "slide")
        #expect(try comparison(evidence).exactRecurrence == true)
    }

    @Test("Eligible and excluded roles remain named and role mutations stay visible")
    func roleSelection() throws {
        let reference = [
            note(0, 0),
            note(4, 3, role: "atmosphere"),
            note(8, 7, role: "transition"),
        ]
        let current = [note(0, 0, role: "response")]
        let evidence = try available(phrase([reference, current]))
        let value = try comparison(evidence)
        #expect(value.roleMutationDistance == 1)
        #expect(evidence.summary.eligibleNoteCount == 2)
        #expect(evidence.summary.excludedNoteCounts == [
            ScoreMotifNamedCount(name: "atmosphere", count: 1),
            ScoreMotifNamedCount(name: "transition", count: 1),
        ])
        let shadow = try #require(evidence.comparisons.first {
            $0.scope == "shadow" && $0.currentPhraseBarIndex == 1
        })
        #expect(shadow.availability == .unavailableNoNotesInEitherBar)
    }

    @Test("Malformed inputs fail closed and ordering is deterministic")
    func malformedAndDeterministic() throws {
        let valid = phrase([[note(4, 3), note(0, 0)], [note(4, 3), note(0, 0)]])
        let first = try available(valid)
        let second = try available(valid)
        #expect(first == second)
        #expect(first.evidenceFingerprint == second.evidenceFingerprint)
        #expect(first.bars.first?.tokens.map(\.onsetMilliSteps) == [0, 4_000])

        #expect(unavailable(ScoreMotifPhraseInput(
            phraseIndex: 0, startBar: 0, barCount: 0,
            tonalCenter: 0, bars: []
        )) == .invalidPhraseBounds)
        #expect(unavailable(ScoreMotifPhraseInput(
            phraseIndex: 0, startBar: 0, barCount: 1,
            tonalCenter: 0, bars: [ScoreMotifBarInput(
                absoluteBar: 1, notes: []
            )]
        )) == .inconsistentBarIdentity)
        #expect(unavailable(phrase([[ScoreMotifNoteInput(
            role: "anchor", onsetStep: 0, durationInSteps: .nan,
            startFrequencyRatio: 1
        )]])) == .nonFiniteNote)
        #expect(unavailable(phrase([[note(16, 0)]])) == .noteOutOfBounds)
        #expect(unavailable(phrase([[ScoreMotifNoteInput(
            role: "unknown", onsetStep: 0, durationInSteps: 1,
            startFrequencyRatio: 1
        )]])) == .unsupportedRole)
    }

    @Test("Canonical plan adapter replays resolved upper score without changing it")
    func canonicalPlanAdapter() throws {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let plan = director.plan(from: director.initialState())
        let input = try #require(
            ScoreMotifBaselineAnalyzer.canonicalInput(plan: plan)
        )
        let evidence = try availableResult(
            ScoreMotifBaselineAnalyzer.analyze(plan: plan)
        )
        #expect(input.phraseIndex == plan.phraseIndex)
        #expect(input.startBar == plan.startBar)
        #expect(input.barCount == plan.barCount)
        #expect(input.bars.count == plan.resolvedBars.count)
        #expect(evidence.barCount == plan.barCount)
        #expect(plan == director.plan(from: director.initialState()))
    }

    private func note(
        _ onset: Int,
        _ semitone: Int,
        duration: Double = 1,
        endSemitone: Int? = nil,
        gate: String = "retrigger",
        role: String = "anchor"
    ) -> ScoreMotifNoteInput {
        ScoreMotifNoteInput(
            role: role,
            onsetStep: onset,
            durationInSteps: duration,
            startFrequencyRatio: pow(2, Double(semitone) / 12),
            endFrequencyRatio: pow(2, Double(endSemitone ?? semitone) / 12),
            gate: gate
        )
    }

    private func phrase(
        _ bars: [[ScoreMotifNoteInput]]
    ) -> ScoreMotifPhraseInput {
        ScoreMotifPhraseInput(
            phraseIndex: 3,
            startBar: 24,
            barCount: bars.count,
            tonalCenter: 0,
            bars: bars.enumerated().map {
                ScoreMotifBarInput(absoluteBar: 24 + $0.offset, notes: $0.element)
            }
        )
    }

    private func available(
        _ input: ScoreMotifPhraseInput
    ) throws -> ScoreMotifBaselineEvidence {
        try availableResult(ScoreMotifBaselineAnalyzer.analyze(input: input))
    }

    private func availableResult(
        _ result: ScoreMotifBaselineAnalysisResult
    ) throws -> ScoreMotifBaselineEvidence {
        guard case .available(let evidence) = result else {
            Issue.record("Expected score motif evidence")
            throw FixtureError.unavailable
        }
        return evidence
    }

    private func unavailable(
        _ input: ScoreMotifPhraseInput
    ) -> ScoreMotifBaselineUnavailableReason? {
        guard case .unavailable(let reason) =
                ScoreMotifBaselineAnalyzer.analyze(input: input) else { return nil }
        return reason
    }

    private func comparison(
        _ evidence: ScoreMotifBaselineEvidence
    ) throws -> ScoreMotifBarComparison {
        try #require(evidence.comparisons.first {
            $0.scope == "combined" &&
                $0.referencePhraseBarIndex == 0 &&
                $0.currentPhraseBarIndex == 1 &&
                $0.lagBars == 1
        })
    }

    private enum FixtureError: Error { case unavailable }
}
