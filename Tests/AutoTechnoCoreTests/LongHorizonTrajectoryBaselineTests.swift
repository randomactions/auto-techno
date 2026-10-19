import AutoTechnoCore
import Foundation
import Testing

@Suite("Long-horizon trajectory baseline")
struct LongHorizonTrajectoryBaselineTests {
    @Test("Frozen four-hour planning snapshot is reproducible and bounded")
    func frozenFourHourPlanningBaseline() throws {
        let first = LongHorizonPlanningBaselineProbe.snapshot(
            rootSeed: 48_291,
            hours: 4,
            traceBarFields: ProcessInfo.processInfo.environment[
                "AUTOTECHNO_TRACE_PLANNING_BASELINE"
            ] == "1"
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

    @Test("Canonical lock curve is portable, bounded and total")
    func canonicalLockCurve() throws {
        var digest: UInt64 = 0xcbf2_9ce4_8422_2325
        var count = 0
        for length in 4...16 {
            for index in 0..<length {
                let value = try #require(AutonomousSessionDirector.planningLockCycle(
                    localBar: index, phraseLength: length))
                #expect(value.isFinite && abs(value) <= 1)
                let reference = sin(Double(index) / Double(length - 1) * .pi * 2)
                #expect(abs(value - reference) <= 4 * Double.ulpOfOne)
                var bits = value.bitPattern.littleEndian
                withUnsafeBytes(of: &bits) { bytes in
                    for byte in bytes { digest = (digest ^ UInt64(byte)) &* 0x100_0000_01b3 }
                }
                count += 1
            }
        }
        #expect(count == 130)
        // Frozen independently from the pre-repair v49 diagnostic grid. The
        // existing four-hour test binds this capability to canonical score/state.
        #expect(digest == 0x16cd9177f76a8a7a)
        for length in [Int.min, -1, 0, 1, 3, 17, Int.max] {
            #expect(AutonomousSessionDirector.planningLockCycle(localBar: 0, phraseLength: length) == nil)
        }
        for index in [Int.min, -1, 16, Int.max] {
            #expect(AutonomousSessionDirector.planningLockCycle(localBar: index, phraseLength: 16) == nil)
        }
    }

    private static let expectedV3 = LongHorizonPlanningBaselineReport(
        schemaVersion: "long-horizon-planning-baseline.v3",
        engineVersion: "autotechno-canonical-engine.v56",
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
        distinctEventSignatureCount: 2_388,
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
        barEvidenceFingerprint: "a7323dff6a221311"
    )
}
