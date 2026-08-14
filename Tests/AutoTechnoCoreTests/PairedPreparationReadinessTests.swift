import AutoTechnoCore
@testable import AutoTechnoDSP
import Darwin
import Dispatch
import Foundation
import Testing

@Suite("Bounded paired-preparation readiness", .serialized)
struct PairedPreparationReadinessTests {
    @Test("Representative rates fit the conservative four-pass working-set envelope")
    func representativeRateWorkingSetEnvelope() throws {
        var previousRatePeak = 0
        for sampleRate in AutonomousPreparationResourceBudget
            .representativeSampleRates {
            let minimum = try #require(AutonomousPreparationResourceBudget(
                sampleRate: sampleRate,
                barCount: 1,
                renderPassCount: 1
            ))
            let maximum = try #require(AutonomousPreparationResourceBudget(
                sampleRate: sampleRate,
                barCount: QualityQualificationContract.maximumPhraseBars,
                renderPassCount: QualityQualificationContract.maximumRenderPasses
            ))
            #expect(minimum.withinActivationBound)
            #expect(maximum.withinActivationBound)
            #expect(maximum.peakWorkingByteCount > minimum.peakWorkingByteCount)
            #expect(maximum.retainedCandidatePCMByteCount ==
                maximum.phraseFrameCount * 2 * MemoryLayout<Float>.stride *
                    QualityQualificationContract.maximumRenderPasses)
            #expect(maximum.analyzerWorkingByteCount ==
                AutonomousFullMixEvidence.maximumAnalysisPeakWorkingByteCount)
            #expect(maximum.peakWorkingByteCount >= previousRatePeak)
            previousRatePeak = maximum.peakWorkingByteCount
        }
        #expect(AutonomousPreparationResourceBudget(
            sampleRate: 48_000,
            barCount: QualityQualificationContract.maximumPhraseBars + 1,
            renderPassCount: QualityQualificationContract.maximumRenderPasses
        ) == nil)
        #expect(AutonomousPreparationResourceBudget(
            sampleRate: 48_000,
            barCount: QualityQualificationContract.maximumPhraseBars,
            renderPassCount: QualityQualificationContract.maximumRenderPasses + 1
        ) == nil)
    }

    /// Explicit release probe. It is intentionally excluded from normal CI:
    /// each iteration renders four complete 16-bar attempts at both calibrated
    /// route rates. Run in an isolated release test process so max RSS and
    /// latency describe this path rather than the rest of the suite.
    @Test("Measure representative-rate four-pass latency, memory, and cancellation")
    func operationalEnvelope() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_PAIRED_BUDGET"
        ] == "1" else { return }

        let iterations = min(9, max(3, Int(
            ProcessInfo.processInfo.environment[
                "AUTOTECHNO_PAIRED_BUDGET_ITERATIONS"
            ] ?? "3"
        ) ?? 3))
        let fixture = try maximumPreparationFixture()
        let baselineResidentBytes = maximumResidentSetSize()
        var rateRecords: [PairedPreparationRateRecord] = []
        var cancellationRecords: [PairedCancellationRecord] = []

        for sampleRate in AutonomousPreparationResourceBudget
            .representativeSampleRates {
            var pairedDurations: [Double] = []
            pairedDurations.reserveCapacity(iterations)
            for _ in 0..<iterations {
                let start = ContinuousClock.now
                let prepared = AutonomousPhrasePreparer.prepare(
                    candidates: fixture.pairedCandidates,
                    sessionSeed: fixture.state.rootSeed,
                    memory: fixture.state.memory,
                    sampleRate: sampleRate,
                    incomingRenderState: RenderState(),
                    incomingGraphState: GeneratedDSPContinuationState(),
                    previousGraph: nil,
                    evaluator: PairedReadinessEvaluator()
                )
                pairedDurations.append(seconds(ContinuousClock.now - start))
                #expect(prepared.candidateEvaluation.isComplete)
                #expect(prepared.candidateEvaluation.attempts.map(\.kind) == [
                    .initialRender, .initialRender,
                ])
                #expect(prepared.candidateEvaluation.attempts.map(\.slot) == [
                    .primary, .alternate,
                ])
                #expect(prepared.candidateEvaluation.selectedSlot == .primary)
                #expect(!prepared.usedFallback)
                #expect(prepared.commitEligible)
            }

            var fourPassDurations: [Double] = []
            fourPassDurations.reserveCapacity(iterations)
            for _ in 0..<iterations {
                let start = ContinuousClock.now
                let prepared = AutonomousPhrasePreparer.prepare(
                    candidates: fixture.fourPassCandidates,
                    sessionSeed: fixture.state.rootSeed,
                    memory: fixture.state.memory,
                    sampleRate: sampleRate,
                    incomingRenderState: RenderState(),
                    incomingGraphState: GeneratedDSPContinuationState(),
                    previousGraph: nil,
                    evaluator: FourPassReadinessEvaluator()
                )
                fourPassDurations.append(seconds(ContinuousClock.now - start))
                #expect(prepared.candidateEvaluation.isComplete)
                #expect(prepared.candidateEvaluation.attempts.map(\.kind) == [
                    .initialRender, .initialRender, .correctionRender,
                    .initialRender,
                ])
                #expect(prepared.candidateEvaluation.attempts.map(\.slot) == [
                    .primary, .alternate, .primary, .fallback,
                ])
                #expect(prepared.candidateEvaluation.selectedSlot == .fallback)
                #expect(prepared.usedFallback)
            }
            let rateRecord = PairedPreparationRateRecord(
                sampleRate: sampleRate,
                pairedDurationsSeconds: pairedDurations,
                fourPassDurationsSeconds: fourPassDurations
            )
            #expect(rateRecord.pairedWorstSeconds <
                AutonomousPreparationResourceBudget
                    .minimumPhraseLookaheadSeconds)
            #expect(rateRecord.fourPassWorstSeconds <
                AutonomousPreparationResourceBudget
                    .maximumSingleHoldLookaheadSeconds)
            rateRecords.append(rateRecord)

            let gate = RepresentativeCancellationGate()
            let cancelled = AutonomousPhrasePreparer.prepareIfNotCancelled(
                candidates: fixture.fourPassCandidates,
                sessionSeed: fixture.state.rootSeed,
                memory: fixture.state.memory,
                sampleRate: sampleRate,
                incomingRenderState: RenderState(),
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                evaluator: RepresentativeCancellationEvaluator(gate: gate),
                cancellationRequested: { gate.check() }
            )
            let cancellationLatency = try #require(gate.latencySeconds())
            #expect(cancelled == nil)
            #expect(gate.comparisonCount == 1)
            #expect(cancellationLatency < 0.100)
            cancellationRecords.append(PairedCancellationRecord(
                sampleRate: sampleRate,
                latencySeconds: cancellationLatency
            ))
        }

        let peakResidentBytes = maximumResidentSetSize()
        let record = PairedPreparationOperationalRecord(
            iterationCount: iterations,
            rates: rateRecords,
            cancellation: cancellationRecords,
            conservativePeakWorkingByteCount: try #require(
                AutonomousPreparationResourceBudget(
                    sampleRate: 48_000,
                    barCount: QualityQualificationContract.maximumPhraseBars,
                    renderPassCount:
                        QualityQualificationContract.maximumRenderPasses
                )
            ).peakWorkingByteCount,
            maximumResidentSetSizeBytes: peakResidentBytes,
            residentSetIncreaseBytes: peakResidentBytes > baselineResidentBytes
                ? peakResidentBytes - baselineResidentBytes : 0
        )
        #expect(record.maximumResidentSetSizeBytes < 512 * 1_024 * 1_024)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(record)
        print(try #require(String(data: data, encoding: .utf8)))
    }

    private func maximumPreparationFixture() throws -> (
        state: AutonomousSessionState,
        pairedCandidates: AutonomousPhraseCandidates,
        fourPassCandidates: AutonomousPhraseCandidates
    ) {
        let invalidInterest = PhraseInterestReport(
            pulseClarity: 0,
            intentionalSpace: 0,
            responseClosure: 0,
            structuralTimeliness: 0,
            identityContinuity: 0,
            weakPositionCoverage: 0,
            trailingSideRelationship: 0,
            overactivityPenalty: 1,
            overdueDebtCount: 1
        )
        for seed in UInt64(1)...4_096 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let source = director.candidates(from: state)
            guard source.primary.barCount ==
                    QualityQualificationContract.maximumPhraseBars,
                  source.alternate.barCount ==
                    QualityQualificationContract.maximumPhraseBars,
                  source.fallback.barCount ==
                    QualityQualificationContract.maximumPhraseBars else {
                continue
            }
            return (
                state,
                source,
                AutonomousPhraseCandidates(
                    primary: replacingInterest(
                        source.primary,
                        with: invalidInterest
                    ),
                    alternate: replacingInterest(
                        source.alternate,
                        with: invalidInterest
                    ),
                    fallback: source.fallback
                )
            )
        }
        throw PairedPreparationReadinessError.maximumFixtureUnavailable
    }

    private func replacingInterest(
        _ source: AutonomousPhrasePlan,
        with interest: PhraseInterestReport
    ) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
            phraseIndex: source.phraseIndex,
            startBar: source.startBar,
            barCount: source.barCount,
            kind: source.kind,
            scene: source.scene,
            dna: source.dna,
            resolvedBars: source.resolvedBars,
            openedDebt: source.openedDebt,
            paidDebtIDs: source.paidDebtIDs,
            requestsTopologyMutation: source.requestsTopologyMutation,
            alternate: source.alternate,
            conservative: source.conservative,
            interest: interest,
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
        )
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) +
            Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private func maximumResidentSetSize() -> Int {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return max(0, Int(usage.ru_maxrss))
    }
}

private enum PairedPreparationReadinessError: Error {
    case maximumFixtureUnavailable
}

private struct PairedReadinessEvaluator: AutonomousCandidateEvaluating {
    package let policyVersion = "test-paired-readiness.v1"
    package let evaluatorVersion = "test-paired-readiness.v1"
    package let requiresPairedCandidates = true

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        .primary
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        false
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1]
        )
    }
}

private struct FourPassReadinessEvaluator: AutonomousCandidateEvaluating {
    package let policyVersion = "test-paired-readiness.v1"
    package let evaluatorVersion = "test-paired-readiness.v1"
    package let requiresPairedCandidates = true

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        .primary
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        slot == .primary
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .conservativeFallback,
            reasonCodes: [.conservativeFallbackV1]
        )
    }
}

private final class RepresentativeCancellationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var cancellationNanoseconds: UInt64?
    private var completionNanoseconds: UInt64?
    private var comparisons = 0

    var comparisonCount: Int { lock.withLock { comparisons } }

    func cancelAfterComparison() {
        lock.withLock {
            comparisons += 1
            cancelled = true
            cancellationNanoseconds = DispatchTime.now().uptimeNanoseconds
        }
    }

    func check() -> Bool {
        lock.withLock {
            if cancelled, completionNanoseconds == nil {
                completionNanoseconds = DispatchTime.now().uptimeNanoseconds
            }
            return cancelled
        }
    }

    func latencySeconds() -> Double? {
        lock.withLock {
            guard let cancellationNanoseconds,
                  let completionNanoseconds,
                  completionNanoseconds >= cancellationNanoseconds else {
                return nil
            }
            return Double(completionNanoseconds - cancellationNanoseconds) /
                1_000_000_000
        }
    }
}

private struct RepresentativeCancellationEvaluator:
        AutonomousCandidateEvaluating {
    package let policyVersion = "test-representative-cancellation.v1"
    package let evaluatorVersion = "test-representative-cancellation.v1"
    package let requiresPairedCandidates = true
    private let gate: RepresentativeCancellationGate

    init(gate: RepresentativeCancellationGate) {
        self.gate = gate
    }

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        gate.cancelAfterComparison()
        return .primary
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        false
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .qualified,
            reasonCodes: [.candidateQualifiedV1]
        )
    }
}

private struct PairedPreparationOperationalRecord: Encodable {
    let schemaVersion = 1
    let iterationCount: Int
    let rates: [PairedPreparationRateRecord]
    let cancellation: [PairedCancellationRecord]
    let conservativePeakWorkingByteCount: Int
    let maximumResidentSetSizeBytes: Int
    let residentSetIncreaseBytes: Int
}

private struct PairedPreparationRateRecord: Encodable {
    let sampleRate: Double
    let pairedMedianSeconds: Double
    let pairedPercentile95Seconds: Double
    let pairedWorstSeconds: Double
    let fourPassMedianSeconds: Double
    let fourPassPercentile95Seconds: Double
    let fourPassWorstSeconds: Double

    init(
        sampleRate: Double,
        pairedDurationsSeconds: [Double],
        fourPassDurationsSeconds: [Double]
    ) {
        self.sampleRate = sampleRate
        let paired = pairedDurationsSeconds.sorted()
        pairedMedianSeconds = Self.percentile(paired, fraction: 0.50)
        pairedPercentile95Seconds = Self.percentile(paired, fraction: 0.95)
        pairedWorstSeconds = paired.last ?? 0
        let fourPass = fourPassDurationsSeconds.sorted()
        fourPassMedianSeconds = Self.percentile(fourPass, fraction: 0.50)
        fourPassPercentile95Seconds = Self.percentile(
            fourPass,
            fraction: 0.95
        )
        fourPassWorstSeconds = fourPass.last ?? 0
    }

    private static func percentile(
        _ sorted: [Double],
        fraction: Double
    ) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let rank = Int(ceil(fraction * Double(sorted.count))) - 1
        return sorted[min(sorted.count - 1, max(0, rank))]
    }
}

private struct PairedCancellationRecord: Encodable {
    let sampleRate: Double
    let latencySeconds: Double
}
