import AutoTechnoCore
import Foundation

/// Versioned descriptive evidence produced from the real canonical director.
/// This type deliberately lives in the test target: it observes planning and cannot
/// influence runtime selection, continuation, rendering, or PCM.
struct LongHorizonPlanningBaselineReport: Codable, Equatable, Sendable {
    struct NamedCount: Codable, Equatable, Sendable {
        let name: String
        let count: Int
    }

    struct MemoryCounts: Codable, Equatable, Sendable {
        let recentBars: Int
        let currentPhrase: Int
        let previousPhrase: Int
        let dramaticArc: Int
        let sessionBars: Int
    }

    let schemaVersion: String
    let engineVersion: String
    let evidenceClassification: String
    let qualificationStatus: String
    let qualificationReason: String
    let rootSeed: UInt64
    let bpm: Int
    let requestedHours: Int
    let requestedBars: Int
    let totalBars: Int
    let phraseCount: Int
    let phraseKindCounts: [NamedCount]
    let performanceCharacterCounts: [NamedCount]
    let highTensionObservationFloor: Double
    let highTensionBarCount: Int
    let recoveryTensionObservationCeiling: Double
    let recoveryTensionBarCount: Int
    let distinctEventSignatureCount: Int
    let maximumOpenDebtCount: Int
    let maximumMemoryCounts: MemoryCounts
    let finalMemoryCounts: MemoryCounts
    let planSequenceFingerprint: String
    let barEvidenceFingerprint: String

    func canonicalJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}

enum LongHorizonPlanningBaselineProbe {
    static let schemaVersion = "long-horizon-planning-baseline.v3"

    static func snapshot(
        rootSeed: UInt64,
        hours: Int
    ) -> LongHorizonPlanningBaselineReport {
        precondition(hours > 0)
        let requestedBars = Int((
            Double(hours * 60) * AutonomousSessionDirector.bpm / 4
        ).rounded(.up))
        let director = AutonomousSessionDirector(rootSeed: rootSeed)
        var state = director.initialState()
        var phraseKindCounts: [AutonomousPhraseKind: Int] = [:]
        var performanceCharacterCounts: [PerformanceCharacter: Int] = [:]
        var highTensionBarCount = 0
        var recoveryTensionBarCount = 0
        var eventSignatures = Set<UInt64>()
        var maximumOpenDebtCount = 0
        var maximumMemoryCounts = memoryCounts(state)
        var phraseCount = 0
        var planHasher = StableBaselineHasher()
        var barHasher = StableBaselineHasher()

        while state.memory.totalBars < requestedBars {
            let plan = director.plan(from: state)
            let memoryBars = plan.memoryBars
            phraseKindCounts[plan.kind, default: 0] += 1
            if let character = plan.resolvedBars.first?.performanceCharacter {
                performanceCharacterCounts[character, default: 0] += 1
            }

            combine(plan, into: &planHasher)
            for memoryBar in memoryBars {
                if memoryBar.tension >= 0.8 { highTensionBarCount += 1 }
                if memoryBar.tension <= 0.4 { recoveryTensionBarCount += 1 }
                eventSignatures.insert(memoryBar.eventSignature)
                combine(memoryBar, into: &barHasher)
            }

            state.advancePlanning(using: plan)
            maximumOpenDebtCount = max(
                maximumOpenDebtCount,
                state.memory.openDebts.count
            )
            maximumMemoryCounts = elementwiseMaximum(
                maximumMemoryCounts,
                memoryCounts(state)
            )
            phraseCount += 1
        }

        return LongHorizonPlanningBaselineReport(
            schemaVersion: schemaVersion,
            engineVersion: QualityQualificationContract.engineVersion,
            evidenceClassification: "descriptive-structural-baseline",
            qualificationStatus: "unavailable",
            qualificationReason: "no-calibrated-long-horizon-policy",
            rootSeed: rootSeed,
            bpm: Int(AutonomousSessionDirector.bpm),
            requestedHours: hours,
            requestedBars: requestedBars,
            totalBars: state.memory.totalBars,
            phraseCount: phraseCount,
            phraseKindCounts: AutonomousPhraseKind.allCases.map {
                .init(name: $0.rawValue, count: phraseKindCounts[$0, default: 0])
            },
            performanceCharacterCounts: PerformanceCharacter.allCases.map {
                .init(name: $0.rawValue,
                      count: performanceCharacterCounts[$0, default: 0])
            },
            highTensionObservationFloor: 0.8,
            highTensionBarCount: highTensionBarCount,
            recoveryTensionObservationCeiling: 0.4,
            recoveryTensionBarCount: recoveryTensionBarCount,
            distinctEventSignatureCount: eventSignatures.count,
            maximumOpenDebtCount: maximumOpenDebtCount,
            maximumMemoryCounts: maximumMemoryCounts,
            finalMemoryCounts: memoryCounts(state),
            planSequenceFingerprint: planHasher.fingerprint,
            barEvidenceFingerprint: barHasher.fingerprint
        )
    }

    private static func memoryCounts(
        _ state: AutonomousSessionState
    ) -> LongHorizonPlanningBaselineReport.MemoryCounts {
        .init(
            recentBars: state.memory.recentBars.count,
            currentPhrase: state.memory.currentPhrase.count,
            previousPhrase: state.memory.previousPhrase.count,
            dramaticArc: state.memory.dramaticArc.count,
            sessionBars: state.memory.sessionBars.count
        )
    }

    private static func elementwiseMaximum(
        _ lhs: LongHorizonPlanningBaselineReport.MemoryCounts,
        _ rhs: LongHorizonPlanningBaselineReport.MemoryCounts
    ) -> LongHorizonPlanningBaselineReport.MemoryCounts {
        .init(
            recentBars: max(lhs.recentBars, rhs.recentBars),
            currentPhrase: max(lhs.currentPhrase, rhs.currentPhrase),
            previousPhrase: max(lhs.previousPhrase, rhs.previousPhrase),
            dramaticArc: max(lhs.dramaticArc, rhs.dramaticArc),
            sessionBars: max(lhs.sessionBars, rhs.sessionBars)
        )
    }

    private static func combine(
        _ plan: AutonomousPhrasePlan,
        into hasher: inout StableBaselineHasher
    ) {
        hasher.combine("plan")
        hasher.combine(plan.phraseIndex)
        hasher.combine(plan.startBar)
        hasher.combine(plan.barCount)
        hasher.combine(plan.kind.rawValue)
        hasher.combine(plan.resolvedBars.first?.performanceCharacter.rawValue ?? "none")
        hasher.combine(plan.requestsTopologyMutation)
        if let debt = plan.openedDebt {
            hasher.combine("opened-debt")
            hasher.combine(debt.id)
            hasher.combine(debt.openedAtBar)
            hasher.combine(debt.dueByBar)
            hasher.combine(debt.source.rawValue)
        } else {
            hasher.combine("no-opened-debt")
        }
        hasher.combine(plan.paidDebtIDs.count)
        for debtID in plan.paidDebtIDs { hasher.combine(debtID) }
    }

    private static func combine(
        _ bar: MusicalMemoryBar,
        into hasher: inout StableBaselineHasher
    ) {
        hasher.combine("bar")
        hasher.combine(bar.absoluteBar)
        hasher.combine(bar.phraseIndex)
        hasher.combine(bar.section.rawValue)
        hasher.combine(bar.tension)
        hasher.combine(bar.roles.count)
        for role in bar.roles { hasher.combine(role.rawValue) }
        hasher.combine(bar.transformations.count)
        for transformation in bar.transformations {
            hasher.combine(transformation.rawValue)
        }
        hasher.combine(bar.eventSignature)
        hasher.combine(bar.activity)
        hasher.combine(bar.repetition)
        hasher.combine(bar.density)
    }
}

private struct StableBaselineHasher {
    private var value: UInt64 = 0xcbf2_9ce4_8422_2325

    var fingerprint: String {
        let raw = String(value, radix: 16)
        return String(repeating: "0", count: 16 - raw.count) + raw
    }

    mutating func combine(_ value: String) {
        for byte in value.utf8 { combine(byte) }
        combine(0xff)
    }

    mutating func combine(_ value: Int) {
        combine(UInt64(bitPattern: Int64(value)))
    }

    mutating func combine(_ value: UInt64) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            for byte in bytes { combine(byte) }
        }
    }

    mutating func combine(_ value: Double) {
        combine(value.bitPattern)
    }

    mutating func combine(_ value: Bool) {
        combine(value ? UInt64(1) : UInt64(0))
    }

    private mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value = value &* 0x0000_0100_0000_01b3
    }
}
