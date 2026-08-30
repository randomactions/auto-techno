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
        engineVersion: "autotechno-canonical-engine.v45",
        evidenceClassification: "descriptive-structural-baseline",
        qualificationStatus: "unavailable",
        qualificationReason: "no-calibrated-long-horizon-policy",
        rootSeed: 48_291,
        bpm: 130,
        requestedHours: 4,
        requestedBars: 7_800,
        totalBars: 7_802,
        phraseCount: 725,
        phraseKindCounts: [
            .init(name: "lock", count: 331),
            .init(name: "contrast", count: 194),
            .init(name: "majorBreak", count: 89),
            .init(name: "energyRelease", count: 65),
            .init(name: "identityReturn", count: 46),
        ],
        performanceCharacterCounts: [
            .init(name: "hypnoticLock", count: 77),
            .init(name: "acidPressure", count: 172),
            .init(name: "peakDrive", count: 49),
            .init(name: "brokenSuspension", count: 216),
            .init(name: "ambientDrift", count: 25),
            .init(name: "melodicGlow", count: 186),
        ],
        highTensionObservationFloor: 0.8,
        highTensionBarCount: 629,
        recoveryTensionObservationCeiling: 0.4,
        recoveryTensionBarCount: 388,
        distinctEventSignatureCount: 1_040,
        maximumOpenDebtCount: 7,
        maximumMemoryCounts: .init(
            recentBars: 4,
            currentPhrase: 16,
            previousPhrase: 16,
            dramaticArc: 128,
            sessionBars: 256
        ),
        finalMemoryCounts: .init(
            recentBars: 4,
            currentPhrase: 16,
            previousPhrase: 6,
            dramaticArc: 99,
            sessionBars: 256
        ),
        planSequenceFingerprint: "28d944266dfaa03e",
        barEvidenceFingerprint: "d57d500f3aa67a0e"
    )
}
