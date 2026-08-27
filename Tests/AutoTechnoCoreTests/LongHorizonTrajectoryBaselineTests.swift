import AutoTechnoCore
import Foundation
import Testing

@Suite("Long-horizon trajectory baseline")
struct LongHorizonTrajectoryBaselineTests {
    @Test("Frozen four-hour planning snapshot is reproducible and bounded")
    func frozenFourHourPlanningBaseline() throws {
        let first = LongHorizonPlanningBaselineProbe.snapshot(
            rootSeed: 48_291,
            hours: 4
        )
        let replay = LongHorizonPlanningBaselineProbe.snapshot(
            rootSeed: 48_291,
            hours: 4
        )

        let canonicalJSON = try first.canonicalJSON()
        let replayJSON = try replay.canonicalJSON()
        let decoded = try JSONDecoder().decode(
            LongHorizonPlanningBaselineReport.self,
            from: Data(canonicalJSON.utf8)
        )

        print("LONG_HORIZON_PLANNING_BASELINE_JSON \(canonicalJSON)")
        #expect(first == replay)
        #expect(first == Self.expectedV3)
        #expect(canonicalJSON == replayJSON)
        #expect(decoded == first)
        #expect(first.totalBars >= first.requestedBars)
        #expect(first.totalBars - first.requestedBars < 16)
        #expect(first.phraseKindCounts.allSatisfy { $0.count > 0 })
        #expect(first.performanceCharacterCounts.allSatisfy { $0.count > 0 })
        #expect(first.highTensionBarCount > 0)
        #expect(first.recoveryTensionBarCount > 0)
        #expect(first.distinctEventSignatureCount > 1)
        #expect(first.maximumOpenDebtCount > 0)
        #expect(first.maximumMemoryCounts.recentBars <= 4)
        #expect(first.maximumMemoryCounts.currentPhrase <= 16)
        #expect(first.maximumMemoryCounts.previousPhrase <= 16)
        #expect(first.maximumMemoryCounts.dramaticArc <= 128)
        #expect(first.maximumMemoryCounts.sessionBars <= 256)

        // These strings are part of the evidence boundary. A descriptive
        // baseline must not imply that structural coverage qualifies four-hour
        // entertainment.
        #expect(first.evidenceClassification == "descriptive-structural-baseline")
        #expect(first.qualificationStatus == "unavailable")
        #expect(first.qualificationReason == "no-calibrated-long-horizon-policy")
    }

    private static let expectedV3 = LongHorizonPlanningBaselineReport(
        schemaVersion: "long-horizon-planning-baseline.v3",
        engineVersion: "autotechno-canonical-engine.v37",
        evidenceClassification: "descriptive-structural-baseline",
        qualificationStatus: "unavailable",
        qualificationReason: "no-calibrated-long-horizon-policy",
        rootSeed: 48_291,
        bpm: 130,
        requestedHours: 4,
        requestedBars: 7_800,
        totalBars: 7_801,
        phraseCount: 714,
        phraseKindCounts: [
            .init(name: "lock", count: 303),
            .init(name: "contrast", count: 192),
            .init(name: "majorBreak", count: 96),
            .init(name: "energyRelease", count: 69),
            .init(name: "identityReturn", count: 54),
        ],
        performanceCharacterCounts: [
            .init(name: "hypnoticLock", count: 205),
            .init(name: "acidPressure", count: 131),
            .init(name: "peakDrive", count: 44),
            .init(name: "brokenSuspension", count: 119),
            .init(name: "ambientDrift", count: 52),
            .init(name: "melodicGlow", count: 163),
        ],
        highTensionObservationFloor: 0.8,
        highTensionBarCount: 670,
        recoveryTensionObservationCeiling: 0.4,
        recoveryTensionBarCount: 390,
        distinctEventSignatureCount: 711,
        maximumOpenDebtCount: 6,
        maximumMemoryCounts: .init(
            recentBars: 4,
            currentPhrase: 16,
            previousPhrase: 16,
            dramaticArc: 128,
            sessionBars: 256
        ),
        finalMemoryCounts: .init(
            recentBars: 4,
            currentPhrase: 13,
            previousPhrase: 5,
            dramaticArc: 57,
            sessionBars: 256
        ),
        planSequenceFingerprint: "4a56c7cd78fe0184",
        barEvidenceFingerprint: "07417d6988caf5ba"
    )
}
