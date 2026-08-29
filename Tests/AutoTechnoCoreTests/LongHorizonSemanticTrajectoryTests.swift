import AutoTechnoCore
import Foundation
import Testing

@Suite("Long-horizon semantic trajectory")
struct LongHorizonSemanticTrajectoryTests {
    @Test("Canonical four-hour trajectory is bounded, replayable, and machine-readable")
    func canonicalFourHourTrajectory() throws {
        let first = canonicalReport(rootSeed: 48_291, hours: 4)
        let replay = canonicalReport(rootSeed: 48_291, hours: 4)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let firstData = try encoder.encode(first)
        let replayData = try encoder.encode(replay)
        let decoded = try JSONDecoder().decode(
            LongHorizonSemanticTrajectoryReport.self,
            from: firstData
        )
        print(
            "LONG_HORIZON_SEMANTIC_4H "
                + "bars=\(first.observedBarCount) phrases=\(first.observedPhraseCount) "
                + "trajectory=\(first.trajectoryFingerprint) "
                + "json=\(stableFingerprint(firstData)) "
                + "matchedRecall=\(first.identityRecall.matchedHomeSignatureBarCount) "
                + "unmatchedRecall=\(first.identityRecall.unmatchedHomeSignatureBarCount) "
                + "openedDebt=\(first.dramaticDebt.openedCount) "
                + "paidDebt=\(first.dramaticDebt.paidCount) "
                + "repeatedSignatures=\(first.eventSignatureRecurrence.repeatObservationCount)"
        )
        #expect(first == replay)
        #expect(firstData == replayData)
        #expect(decoded == first)
        #expect(first.schemaVersion == 1)
        #expect(first.schemaIdentifier == "autotechno-long-horizon-semantic.v1")
        #expect(first.engineVersion == QualityQualificationContract.engineVersion)
        #expect(first.availability == .available)
        #expect(first.unavailableReason == nil)
        #expect(first.qualificationStatus == .unavailable)
        #expect(first.qualificationReason == "no-calibrated-long-horizon-policy")
        #expect(first.observedBarCount == 7_802)
        #expect(first.observedPhraseCount == 725)
        #expect(first.trajectoryFingerprint == "cc5e12527ba89b5c")
        #expect(stableFingerprint(firstData) == "0472136b8e0de24b")
        #expect(first.phraseKindPhraseCounts.allSatisfy { $0.count > 0 })
        #expect(first.performanceCharacterPhraseCounts.allSatisfy { $0.count > 0 })
        #expect(first.tensionDwell.highBarCount == 629)
        #expect(first.tensionDwell.recoveryBarCount == 388)
        #expect(first.periodicity.count == 64)
        #expect(first.storage.periodicityLagCapacity == 64)
        #expect(first.storage.recentSemanticBarCapacity == 64)
        #expect(first.storage.recentSemanticBarCount == 64)
        #expect(first.storage.eventSignatureRecurrenceCapacity == 64)
        #expect(first.storage.eventSignatureRecurrenceCount == 64)
        #expect(first.storage.identityLandmarkCapacity == 16)
        #expect(first.storage.dramaticDebtCapacity == 16)
        #expect(first.trajectoryFingerprint.count == 16)
        #expect(!String(decoding: firstData, as: UTF8.self).contains("engagement"))
    }

    @Test("Eight-hour canonical evidence retains only fixed-capacity storage")
    func eightHourStorageRemainsFixed() {
        let report = canonicalReport(rootSeed: 48_291, hours: 8)

        #expect(report.availability == .available)
        #expect(report.observedBarCount >= 15_600)
        #expect(report.observedBarCount < 15_616)
        #expect(report.storage.periodicityLagCount == 64)
        #expect(report.storage.recentSemanticBarCount == 64)
        #expect(report.storage.eventSignatureRecurrenceCount == 64)
        #expect(report.storage.identityLandmarkCount <= 16)
        #expect(report.storage.dramaticDebtCount <= 16)
        #expect(report.eventSignatureRecurrence.observationCount ==
                report.observedBarCount)
        #expect(report.qualificationStatus == .unavailable)
    }

    @Test("Malformed or discontinuous input becomes unavailable without partial mutation")
    func malformedInputIsUnavailable() {
        var initiallyEmpty = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 48_291,
            startingPhraseIndex: 0,
            startingBar: 0
        )
        #expect(initiallyEmpty.report().availability == .unavailable)
        #expect(initiallyEmpty.report().unavailableReason == .noObservations)
        #expect(initiallyEmpty.observe(syntheticPhrase(
            rootSeed: 48_291,
            phraseIndex: 0,
            startBar: 0,
            tensions: [0.5],
            eventSignatures: [1]
        )) == .accepted)
        #expect(initiallyEmpty.report().availability == .available)

        let expectedDirector = AutonomousSessionDirector(rootSeed: 48_291)
        let expectedState = expectedDirector.initialState()
        let otherDirector = AutonomousSessionDirector(rootSeed: 42)
        let otherState = otherDirector.initialState()
        let otherPlan = otherDirector.plan(from: otherState)
        var wrongSeed = LongHorizonSemanticTrajectoryAccumulator(
            startingState: expectedState
        )

        #expect(wrongSeed.observe(plan: otherPlan, incomingState: otherState) ==
                .unavailable(.rootSeedMismatch))
        #expect(wrongSeed.report().availability == .unavailable)
        #expect(wrongSeed.report().unavailableReason == .rootSeedMismatch)
        #expect(wrongSeed.report().observedBarCount == 0)

        var invalidScalar = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 48_291,
            startingPhraseIndex: 0,
            startingBar: 0
        )
        let malformed = syntheticPhrase(
            rootSeed: 48_291,
            phraseIndex: 0,
            startBar: 0,
            tensions: [1.2],
            eventSignatures: [1]
        )
        #expect(invalidScalar.observe(malformed) ==
                .unavailable(.invalidSemanticScalar))
        #expect(invalidScalar.report().observedPhraseCount == 0)
        #expect(invalidScalar.report().unavailableReason == .invalidSemanticScalar)

        var discontinuous = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 48_291,
            startingPhraseIndex: 0,
            startingBar: 0
        )
        let skipped = syntheticPhrase(
            rootSeed: 48_291,
            phraseIndex: 1,
            startBar: 0,
            tensions: [0.5],
            eventSignatures: [1]
        )
        #expect(discontinuous.observe(skipped) ==
                .unavailable(.phraseIndexDiscontinuity))
        #expect(discontinuous.report().observedBarCount == 0)

        var excessiveDebtInput = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 48_291,
            startingPhraseIndex: 0,
            startingBar: 0
        )
        let excessivePayment = syntheticPhrase(
            rootSeed: 48_291,
            phraseIndex: 0,
            startBar: 0,
            tensions: [0.5],
            eventSignatures: [1],
            paidDebtIDs: Array(0...16)
        )
        #expect(excessiveDebtInput.observe(excessivePayment) ==
                .unavailable(.invalidDebt))
        #expect(excessiveDebtInput.report().observedBarCount == 0)
    }

    @Test("Descriptive evidence exposes fixed periodicity, permanent peak, and capability fatigue")
    func adversarialTrajectoryIsObservable() {
        var accumulator = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 9_001,
            startingPhraseIndex: 0,
            startingBar: 0
        )

        for bar in 0..<128 {
            let phase = bar % 16
            let observation = syntheticPhrase(
                phraseIndex: bar,
                startBar: bar,
                tensions: [0.8 + Double(phase) * 0.01],
                eventSignatures: [UInt64(phase + 1)],
                capabilities: [.pulseEcho]
            )
            #expect(accumulator.observe(observation) == .accepted)
        }

        let report = accumulator.report()
        let lag16 = report.periodicity.first { $0.lagBars == 16 }
        let pulseEcho = report.capabilityRecurrence.first {
            $0.name == LongHorizonSemanticCapability.pulseEcho.rawValue
        }

        #expect(report.availability == .available)
        #expect(lag16?.comparisonCount == 112)
        #expect(lag16?.semanticMatchCount == 112)
        #expect(lag16?.eventSignatureMatchCount == 112)
        #expect(lag16?.tensionBandMatchCount == 112)
        #expect(report.eventSignatureRecurrence.repeatObservationCount == 112)
        #expect(report.eventSignatureRecurrence.recurrenceGapCount == 112)
        #expect(report.eventSignatureRecurrence.minimumInactiveGapBars == 15)
        #expect(report.eventSignatureRecurrence.maximumInactiveGapBars == 15)
        #expect(report.eventSignatureRecurrence.maximumRunBars == 1)
        #expect(report.tensionDwell.maximumHighDwellBars == 128)
        #expect(pulseEcho?.activeBarCount == 128)
        #expect(pulseEcho?.maximumRunBars == 128)
        #expect(report.qualificationStatus == .unavailable)
    }

    @Test("Identity-return evidence distinguishes exact home recall from an unmatched return")
    func identityRecallEvidence() {
        var accumulator = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 7_777,
            startingPhraseIndex: 0,
            startingBar: 0
        )
        let home = syntheticPhrase(
            rootSeed: 7_777,
            phraseIndex: 0,
            startBar: 0,
            kind: .lock,
            character: .hypnoticLock,
            tensions: [0.5],
            eventSignatures: [101]
        )
        let unmatched = syntheticPhrase(
            rootSeed: 7_777,
            phraseIndex: 1,
            startBar: 1,
            kind: .identityReturn,
            character: .hypnoticLock,
            tensions: [0.4],
            eventSignatures: [202]
        )
        let matched = syntheticPhrase(
            rootSeed: 7_777,
            phraseIndex: 2,
            startBar: 2,
            kind: .identityReturn,
            character: .hypnoticLock,
            tensions: [0.4],
            eventSignatures: [101]
        )

        #expect(accumulator.observe(home) == .accepted)
        #expect(accumulator.observe(unmatched) == .accepted)
        #expect(accumulator.observe(matched) == .accepted)
        #expect(accumulator.report().identityRecall.identityReturnBarCount == 2)
        #expect(accumulator.report().identityRecall.matchedHomeSignatureBarCount == 1)
        #expect(accumulator.report().identityRecall.unmatchedHomeSignatureBarCount == 1)
        #expect(accumulator.report().identityRecall.landmarkCount == 1)
        #expect(accumulator.report().identityRecall.minimumMatchedAbsenceBars == 2)
        #expect(accumulator.report().identityRecall.maximumMatchedAbsenceBars == 2)
    }

    @Test("Debt provenance, payoff age, and capacity failure are transactional")
    func dramaticDebtEvidenceIsBoundedAndTransactional() {
        var lifecycle = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 3_131,
            startingPhraseIndex: 0,
            startingBar: 0
        )
        let opened = syntheticPhrase(
            rootSeed: 3_131,
            phraseIndex: 0,
            startBar: 0,
            kind: .contrast,
            tensions: [0.5],
            eventSignatures: [1],
            openedDebt: .init(
                id: 10,
                openedAtBar: 0,
                dueByBar: 1,
                source: .contrast
            )
        )
        let paid = syntheticPhrase(
            rootSeed: 3_131,
            phraseIndex: 1,
            startBar: 1,
            tensions: [0.4],
            eventSignatures: [2],
            paidDebtIDs: [10]
        )
        let immediate = syntheticPhrase(
            rootSeed: 3_131,
            phraseIndex: 2,
            startBar: 2,
            kind: .majorBreak,
            tensions: [0.3],
            eventSignatures: [3],
            openedDebt: .init(
                id: 11,
                openedAtBar: 2,
                dueByBar: 2,
                source: .majorBreak
            ),
            paidDebtIDs: [11]
        )

        #expect(lifecycle.observe(opened) == .accepted)
        #expect(lifecycle.observe(paid) == .accepted)
        #expect(lifecycle.observe(immediate) == .accepted)
        let lifecycleReport = lifecycle.report()
        #expect(lifecycleReport.dramaticDebt.openedCount == 2)
        #expect(lifecycleReport.dramaticDebt.paidCount == 2)
        #expect(lifecycleReport.dramaticDebt.zeroAgePaidCount == 1)
        #expect(lifecycleReport.dramaticDebt.maximumObservedAgeBars == 1)
        #expect(lifecycleReport.dramaticDebt.outstandingCount == 0)
        #expect(lifecycleReport.dramaticDebt.sourceOpenedCounts.first {
            $0.name == AutonomousPhraseKind.contrast.rawValue
        }?.count == 1)
        #expect(lifecycleReport.dramaticDebt.sourcePaidCounts.first {
            $0.name == AutonomousPhraseKind.majorBreak.rawValue
        }?.count == 1)

        var capacity = LongHorizonSemanticTrajectoryAccumulator(
            rootSeed: 4_141,
            startingPhraseIndex: 0,
            startingBar: 0
        )
        for index in 0..<16 {
            let observation = syntheticPhrase(
                rootSeed: 4_141,
                phraseIndex: index,
                startBar: index,
                kind: .contrast,
                tensions: [0.5],
                eventSignatures: [UInt64(index)],
                openedDebt: .init(
                    id: index,
                    openedAtBar: index,
                    dueByBar: index + 32,
                    source: .contrast
                )
            )
            #expect(capacity.observe(observation) == .accepted)
        }
        let overflow = syntheticPhrase(
            rootSeed: 4_141,
            phraseIndex: 16,
            startBar: 16,
            kind: .contrast,
            tensions: [0.5],
            eventSignatures: [16],
            openedDebt: .init(
                id: 16,
                openedAtBar: 16,
                dueByBar: 48,
                source: .contrast
            )
        )
        #expect(capacity.observe(overflow) ==
                .unavailable(.dramaticDebtCapacityExceeded))
        #expect(capacity.report().observedPhraseCount == 16)
        #expect(capacity.report().dramaticDebt.openedCount == 16)
        #expect(capacity.report().dramaticDebt.outstandingCount == 16)
    }

    @Test("A mid-session observation window imports bounded outstanding debt")
    func midSessionDebtContinuation() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for _ in 0..<64 where state.memory.openDebts.isEmpty {
            state.advancePlanning(using: director.plan(from: state))
        }
        let initialOutstandingCount = state.memory.openDebts.count
        #expect(initialOutstandingCount > 0)

        var accumulator = LongHorizonSemanticTrajectoryAccumulator(
            startingState: state
        )
        #expect(accumulator.report().dramaticDebt.initialOutstandingCount ==
                initialOutstandingCount)
        #expect(accumulator.report().dramaticDebt.outstandingCount ==
                initialOutstandingCount)

        for _ in 0..<128 where accumulator.report().dramaticDebt.paidCount == 0 {
            let plan = director.plan(from: state)
            #expect(accumulator.observe(plan: plan, incomingState: state) == .accepted)
            state.advancePlanning(using: plan)
        }
        #expect(accumulator.report().availability == .available)
        #expect(accumulator.report().dramaticDebt.paidCount > 0)
    }

    private func canonicalReport(
        rootSeed: UInt64,
        hours: Int
    ) -> LongHorizonSemanticTrajectoryReport {
        let director = AutonomousSessionDirector(rootSeed: rootSeed)
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "offline-semantic-only",
            routeGeneration: 0
        )
        let requestedBars = Int((
            Double(hours * 60) * AutonomousSessionDirector.bpm / 4
        ).rounded(.up))
        return harness.semanticTrajectoryReport(
            director: director,
            requestedBarCount: requestedBars
        )
    }

    private func syntheticPhrase(
        rootSeed: UInt64 = 9_001,
        phraseIndex: Int,
        startBar: Int,
        kind: AutonomousPhraseKind = .lock,
        character: PerformanceCharacter = .hypnoticLock,
        tensions: [Double],
        eventSignatures: [UInt64],
        capabilities: [LongHorizonSemanticCapability] = [],
        openedDebt: LongHorizonSemanticDebtObservation? = nil,
        paidDebtIDs: [Int] = []
    ) -> LongHorizonSemanticPhraseObservation {
        let bars = zip(tensions, eventSignatures).enumerated().map {
            localBar, values in
            LongHorizonSemanticBarObservation(
                absoluteBar: startBar + localBar,
                section: kind == .identityReturn ? .returnSection : .groove,
                tension: values.0,
                roles: [.foundation, .percussion],
                transformations: kind == .identityReturn ? [.restore] : [.repeat],
                eventSignature: values.1,
                activity: 0.4,
                repetition: kind == .identityReturn ? 1 : 0.8,
                density: 0.34,
                focusRole: .foundation,
                foundationBehavior: .monotone,
                arrangementGesture: .steady,
                percussionGear: .anchor,
                kickSyntaxRole: .grounded,
                interlockChapter: .home,
                signatureEvent: nil,
                harmonicFunction: nil,
                capabilities: capabilities
            )
        }
        return LongHorizonSemanticPhraseObservation(
            rootSeed: rootSeed,
            phraseIndex: phraseIndex,
            startBar: startBar,
            kind: kind,
            character: character,
            bars: bars,
            openedDebt: openedDebt,
            paidDebtIDs: paidDebtIDs
        )
    }

    private func stableFingerprint(_ data: Data) -> String {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }
        let raw = String(value, radix: 16)
        return String(repeating: "0", count: 16 - raw.count) + raw
    }
}
