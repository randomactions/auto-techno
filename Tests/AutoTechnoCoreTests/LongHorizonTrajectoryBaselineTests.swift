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
        #expect(first == Self.expectedV1)
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

        // These strings are part of the evidence boundary. Phase 0 must not
        // imply that structural coverage qualifies four-hour entertainment.
        #expect(first.evidenceClassification == "descriptive-structural-baseline")
        #expect(first.qualificationStatus == "unavailable")
        #expect(first.qualificationReason == "no-calibrated-long-horizon-policy")
    }

    private static let expectedV1 = LongHorizonPlanningBaselineReport(
        schemaVersion: "long-horizon-planning-baseline.v1",
        engineVersion: "autotechno-canonical-engine.v32",
        evidenceClassification: "descriptive-structural-baseline",
        qualificationStatus: "unavailable",
        qualificationReason: "no-calibrated-long-horizon-policy",
        rootSeed: 48_291,
        bpm: 130,
        requestedHours: 4,
        requestedBars: 7_800,
        totalBars: 7_800,
        phraseCount: 710,
        phraseKindCounts: [
            .init(name: "lock", count: 257),
            .init(name: "contrast", count: 221),
            .init(name: "majorBreak", count: 97),
            .init(name: "energyRelease", count: 75),
            .init(name: "identityReturn", count: 60),
        ],
        performanceCharacterCounts: [
            .init(name: "hypnoticLock", count: 187),
            .init(name: "acidPressure", count: 119),
            .init(name: "peakDrive", count: 46),
            .init(name: "brokenSuspension", count: 126),
            .init(name: "ambientDrift", count: 52),
            .init(name: "melodicGlow", count: 180),
        ],
        highTensionObservationFloor: 0.8,
        highTensionBarCount: 764,
        recoveryTensionObservationCeiling: 0.4,
        recoveryTensionBarCount: 410,
        distinctEventSignatureCount: 572,
        maximumOpenDebtCount: 7,
        maximumMemoryCounts: .init(
            recentBars: 4,
            currentPhrase: 16,
            previousPhrase: 16,
            dramaticArc: 109,
            sessionBars: 256
        ),
        finalMemoryCounts: .init(
            recentBars: 4,
            currentPhrase: 4,
            previousPhrase: 6,
            dramaticArc: 56,
            sessionBars: 256
        ),
        planSequenceFingerprint: "b6642428b9d0fc3e",
        barEvidenceFingerprint: "ce2054dc1adc6b36"
    )
}
