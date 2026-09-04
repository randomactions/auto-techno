import AutoTechnoCore
import Foundation
import Testing

@Suite("Long-horizon session baseline")
struct LongHorizonSessionBaselineTests {
    @Test("Scalar summaries and fixed segments describe shape without ranking")
    func scalarShapeAndSegmentation() throws {
        let values = Array(0..<65)
        let phrases = stride(from: 0, to: values.count, by: 16).enumerated().map {
            phraseIndex, offset in
            let end = min(values.count, offset + 16)
            return phrase(
                phraseIndex: phraseIndex,
                startBar: offset,
                tensions: Array(repeating: 0.5, count: end - offset),
                activities: values[offset..<end].map { Double($0) / 64 },
                repetitions: values[offset..<end].map { 1 - Double($0) / 64 },
                densities: values[offset..<end].map { $0.isMultiple(of: 2) ? 0.1 : 0.9 },
                signatures: values[offset..<end].map(UInt64.init)
            )
        }

        let report = try availableReport(phrases)

        #expect(report.schemaIdentifier ==
                "autotechno-long-horizon-session-baseline.v1")
        #expect(report.qualificationStatus == "unavailable")
        #expect(report.qualificationReason ==
                "descriptive-score-only-no-quality-rank")
        #expect(report.realizedSignalAvailability == "unavailable")
        #expect(report.realizedSignalUnavailableReason ==
                "score-only-no-continuous-pcm")
        #expect(report.observedBarCount == 65)
        #expect(report.segments.count == 3)
        #expect(report.segments.map(\.barCount) == [32, 32, 1])
        #expect(report.segments.map(\.complete) == [true, true, false])
        #expect(report.segments[0].tension.minimum == 0.5)
        #expect(report.segments[0].tension.maximum == 0.5)
        #expect(report.segments[0].tension.directionChangeCount == 0)
        #expect(report.segments[0].activity.first == 0)
        #expect(report.segments[0].activity.last == 31.0 / 64.0)
        #expect(report.segments[0].activity.directionChangeCount == 0)
        #expect(report.segments[0].repetition.first == 1)
        #expect(report.segments[0].repetition.last == 33.0 / 64.0)
        #expect(report.segments[0].repetition.directionChangeCount == 0)
        #expect(report.segments[0].density.directionChangeCount == 30)
        #expect(report.segments[0].density.maximumAbsoluteStep == 0.8)
    }

    @Test("Payoff spacing and bounded recovery latency retain unresolved markers")
    func payoffAndRecoveryEvidence() throws {
        let phrases = [
            phrase(
                phraseIndex: 0,
                startBar: 0,
                kind: .energyRelease,
                operatorKind: .payoff,
                selectionReason: .episodeOperator,
                tensions: [0.8, 0.8, 0.7, 0.6]
            ),
            phrase(
                phraseIndex: 1,
                startBar: 4,
                kind: .majorBreak,
                operatorKind: .recover,
                selectionReason: .episodeOperator,
                tensions: [0.2, 0.2, 0.3, 0.3]
            ),
            phrase(
                phraseIndex: 2,
                startBar: 8,
                kind: .energyRelease,
                operatorKind: .payoff,
                selectionReason: .episodeOperator,
                tensions: [0.8, 0.8, 0.7, 0.6]
            ),
            phrase(
                phraseIndex: 3,
                startBar: 12,
                kind: .energyRelease,
                operatorKind: .payoff,
                selectionReason: .episodeOperator,
                tensions: [0.8, 0.8, 0.7, 0.6]
            )
        ]

        let report = try availableReport(phrases)

        #expect(report.payoffMarkerBars == [0, 8, 12])
        #expect(report.recoveryMarkerBars == [4])
        #expect(report.payoffSpacing.intervalCount == 2)
        #expect(report.payoffSpacing.minimumBars == 4)
        #expect(report.payoffSpacing.maximumBars == 8)
        #expect(report.payoffSpacing.meanBars == 6)
        #expect(report.payoffRecovery.count == 3)
        #expect(report.payoffRecovery[0].status == .observed)
        #expect(report.payoffRecovery[0].recoveryBar == 4)
        #expect(report.payoffRecovery[0].latencyBars == 4)
        #expect(report.payoffRecovery[1].status == .unresolvedWithinHorizon)
        #expect(report.payoffRecovery[2].status == .unresolvedWithinHorizon)
    }

    @Test("Recurrence and capability exposure preserve counts and maximum runs")
    func recurrenceAndCapabilityRuns() throws {
        let signatures: [UInt64] = [1, 1, 2, 2, 2, 1, 3, 3]
        let capabilities: [[LongHorizonSemanticCapability]] = [
            [.groovePulse, .pulseEcho],
            [.groovePulse, .pulseEcho],
            [.groovePulse, .pulseEcho],
            [.groovePulse, .pulseEcho],
            [.groovePulse, .pulseEcho],
            [.groovePulse],
            [.groovePulse, .pulseEcho],
            [.groovePulse, .pulseEcho]
        ]
        let report = try availableReport([
            phrase(
                phraseIndex: 0,
                startBar: 0,
                tensions: Array(repeating: 0.5, count: 8),
                signatures: signatures,
                capabilities: capabilities
            )
        ])
        let segment = try #require(report.segments.first)
        let pulseEcho = try #require(report.capabilityExposure.first {
            $0.capability == .pulseEcho
        })

        #expect(segment.repeatedEventSignatureBarCount == 5)
        #expect(segment.maximumEventSignatureRunBars == 3)
        #expect(pulseEcho.activeBarCount == 7)
        #expect(pulseEcho.maximumRunBars == 5)
    }

    @Test("Malformed, discontinuous, excessive, or noncanonical input fails closed")
    func malformedInputFailsClosed() throws {
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([]) ==
                .unavailable(.noObservations))

        let valid = phrase(phraseIndex: 0, startBar: 0, tensions: [0.5])
        let wrongRoot = phrase(
            rootSeed: 9_002,
            phraseIndex: 1,
            startBar: 1,
            tensions: [0.5]
        )
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([valid, wrongRoot]) ==
                .unavailable(.rootSeedMismatch))

        #expect(LongHorizonSessionBaselineAnalyzer.analyze([
            valid,
            phrase(phraseIndex: 2, startBar: 1, tensions: [0.5])
        ]) == .unavailable(.phraseIndexDiscontinuity))
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([
            valid,
            phrase(phraseIndex: 1, startBar: 2, tensions: [0.5])
        ]) == .unavailable(.barDiscontinuity))
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([
            phrase(phraseIndex: 0, startBar: 0, tensions: [])
        ]) == .unavailable(.emptyPhrase))
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([
            phrase(
                phraseIndex: 0,
                startBar: 0,
                tensions: Array(repeating: 0.5, count: 17)
            )
        ]) == .unavailable(.phraseTooLong))
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([
            phrase(phraseIndex: 0, startBar: 0, tensions: [.nan])
        ]) == .unavailable(.invalidScalar))
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([
            phrase(
                phraseIndex: 0,
                startBar: 0,
                kind: .lock,
                operatorKind: .payoff,
                selectionReason: .episodeOperator,
                tensions: [0.5]
            )
        ]) == .unavailable(.inconsistentSelection))

        let excessive = (0...512).map { index in
            phrase(
                phraseIndex: index,
                startBar: index * 16,
                tensions: Array(repeating: 0.5, count: 16)
            )
        }
        #expect(LongHorizonSessionBaselineAnalyzer.analyze(excessive) ==
                .unavailable(.barCapacityExceeded))

        let noncanonicalJSON = Data("""
        {
          "absoluteBar": 0,
          "section": "groove",
          "interlockChapter": "home",
          "tension": 0.5,
          "activity": 0.5,
          "repetition": 0.5,
          "density": 0.5,
          "eventSignature": 1,
          "capabilities": ["pulse-echo", "groove-pulse"]
        }
        """.utf8)
        let noncanonicalBar = try JSONDecoder().decode(
            LongHorizonSessionBaselineBarInput.self,
            from: noncanonicalJSON
        )
        let noncanonicalPhrase = LongHorizonSessionBaselinePhraseInput(
            rootSeed: 9_001,
            phraseIndex: 0,
            startBar: 0,
            phraseKind: .lock,
            operatorKind: nil,
            selectionReason: .conservativeFallback,
            bars: [noncanonicalBar]
        )
        #expect(LongHorizonSessionBaselineAnalyzer.analyze([
            noncanonicalPhrase
        ]) == .unavailable(.invalidCapabilityOrder))
    }

    @Test("Canonical plan conversion and report serialization are deterministic")
    func canonicalConversionAndSerialization() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let plan = director.plan(from: state)
        let firstInput = try #require(
            LongHorizonSessionBaselinePhraseInput.make(
                plan: plan,
                incomingState: state
            )
        )
        let replayInput = try #require(
            LongHorizonSessionBaselinePhraseInput.make(
                plan: plan,
                incomingState: state
            )
        )
        let otherState = AutonomousSessionDirector(rootSeed: 42).initialState()
        #expect(LongHorizonSessionBaselinePhraseInput.make(
            plan: plan,
            incomingState: otherState
        ) == nil)

        let first = try availableReport([firstInput])
        let replay = try availableReport([replayInput])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let firstData = try encoder.encode(first)
        let replayData = try encoder.encode(replay)
        let decoded = try JSONDecoder().decode(
            LongHorizonSessionBaselineReport.self,
            from: firstData
        )

        #expect(firstInput == replayInput)
        #expect(first == replay)
        #expect(firstData == replayData)
        #expect(decoded == first)
        #expect(first.reportFingerprint.count == 16)

        let changed = phrase(
            phraseIndex: 0,
            startBar: 0,
            tensions: [0.51]
        )
        let changedReport = try availableReport([changed])
        let unchangedReport = try availableReport([
            phrase(phraseIndex: 0, startBar: 0, tensions: [0.5])
        ])
        #expect(changedReport.reportFingerprint !=
                unchangedReport.reportFingerprint)
    }

    @Test("Canonical four-hour planning remains bounded and segment-complete")
    func canonicalFourHourPlanning() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var phrases: [LongHorizonSessionBaselinePhraseInput] = []
        let requestedBars = Int((
            4 * 60 * AutonomousSessionDirector.bpm / 4
        ).rounded(.up))

        while state.memory.totalBars < requestedBars {
            let plan = director.plan(from: state)
            let input = try #require(
                LongHorizonSessionBaselinePhraseInput.make(
                    plan: plan,
                    incomingState: state
                )
            )
            phrases.append(input)
            state.advancePlanning(using: plan)
        }

        let report = try availableReport(phrases)
        #expect(report.observedBarCount >= requestedBars)
        #expect(report.observedBarCount <=
                LongHorizonSessionBaselineSchema.maximumBarCount)
        #expect(report.observedPhraseCount == phrases.count)
        #expect(report.segments.count ==
                (report.observedBarCount + 31) / 32)
        #expect(report.segments.dropLast().allSatisfy { $0.complete })
        #expect(report.realizedSignalUnavailableReason ==
                "score-only-no-continuous-pcm")
    }

    private func availableReport(
        _ phrases: [LongHorizonSessionBaselinePhraseInput]
    ) throws -> LongHorizonSessionBaselineReport {
        switch LongHorizonSessionBaselineAnalyzer.analyze(phrases) {
        case let .available(report): return report
        case let .unavailable(reason):
            Issue.record("Expected available report, received \(reason.rawValue)")
            throw BaselineTestError.unavailable
        }
    }

    private func phrase(
        rootSeed: UInt64 = 9_001,
        phraseIndex: Int,
        startBar: Int,
        kind: AutonomousPhraseKind = .lock,
        operatorKind: LongHorizonEpisodeOperator? = nil,
        selectionReason: LongHorizonPhraseSelectionReason =
            .conservativeFallback,
        tensions: [Double],
        activities: [Double]? = nil,
        repetitions: [Double]? = nil,
        densities: [Double]? = nil,
        signatures: [UInt64]? = nil,
        capabilities: [[LongHorizonSemanticCapability]]? = nil
    ) -> LongHorizonSessionBaselinePhraseInput {
        let bars = tensions.indices.map { index in
            LongHorizonSessionBaselineBarInput(
                absoluteBar: startBar + index,
                section: kind == .majorBreak ? .breakdown : .groove,
                interlockChapter: .home,
                tension: tensions[index],
                activity: activities?[index] ?? 0.5,
                repetition: repetitions?[index] ?? 0.5,
                density: densities?[index] ?? 0.5,
                eventSignature: signatures?[index] ?? UInt64(index + 1),
                capabilities: capabilities?[index] ?? []
            )
        }
        return LongHorizonSessionBaselinePhraseInput(
            rootSeed: rootSeed,
            phraseIndex: phraseIndex,
            startBar: startBar,
            phraseKind: kind,
            operatorKind: operatorKind,
            selectionReason: selectionReason,
            bars: bars
        )
    }
}

private enum BaselineTestError: Error {
    case unavailable
}
