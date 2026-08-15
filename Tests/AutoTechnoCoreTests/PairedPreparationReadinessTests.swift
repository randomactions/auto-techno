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

    @Test("Unsupported calibrated route preserves one uncalibrated primary")
    func unsupportedRouteStaysSinglePrimary() throws {
        let artifacts = try ProfessionalQualityPairedArtifacts.load()
        let evaluator = ProfessionalQualityPreparationEvaluator(
            sampleRate: 8_000,
            artifacts: artifacts
        )
        let fixture = try minimumPreparationFixture()
        let prepared = AutonomousPhrasePreparer.prepare(
            candidates: fixture.candidates,
            sessionSeed: fixture.state.rootSeed,
            memory: fixture.state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: evaluator
        )

        #expect(evaluator.availability == .unsupportedSampleRate)
        #expect(!evaluator.requiresPairedCandidates)
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.candidateEvaluation.attempts.map(\.slot) == [.primary])
        #expect(prepared.candidateEvaluation.comparison == .unavailable)
        #expect(prepared.candidateEvaluation.policyVersion ==
                QualityQualificationContract.uncalibratedPolicyVersion)
        #expect(prepared.candidateEvaluation.evaluatorVersion ==
                QualityQualificationContract.uncalibratedEvaluatorVersion)
        #expect(prepared.qualityDecision.outcome == .qualificationUnavailable)
        #expect(prepared.qualityDecision.reasonCodes.contains(
            .policyUncalibratedV1
        ))
        #expect(prepared.commitEligible)
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

    /// Explicit release probe for the exact pinned v19 evaluator. Resources
    /// load once before detached preparation; every timed iteration receives
    /// only the immutable route-local evaluator value. This remains opt-in so
    /// normal CI does not duplicate the generic maximum-path budget probe.
    @Test("Measure exact paired-policy latency, memory, fallback, and cancellation")
    func exactEvaluatorOperationalEnvelope() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_EXACT_PAIRED_POLICY"
        ] == "1" else { return }

        let iterations = min(9, max(3, Int(
            ProcessInfo.processInfo.environment[
                "AUTOTECHNO_EXACT_PAIRED_ITERATIONS"
            ] ?? "3"
        ) ?? 3))
        let loadStart = ContinuousClock.now
        let artifacts = try ProfessionalQualityPairedArtifacts.load()
        let artifactLoadSeconds = seconds(ContinuousClock.now - loadStart)
        let fixture = try maximumPreparationFixture()
        let baselineResidentBytes = maximumResidentSetSize()
        var rateRecords: [ExactPairedPreparationRateRecord] = []
        var cancellationRecords: [PairedCancellationRecord] = []

        for sampleRate in AutonomousPreparationResourceBudget
            .representativeSampleRates {
            let evaluator = ProfessionalQualityPreparationEvaluator(
                sampleRate: sampleRate,
                artifacts: artifacts
            )
            #expect(evaluator.availability == .available)
            #expect(evaluator.policyVersion == artifacts.evaluator.policyVersion)
            #expect(evaluator.evaluatorVersion ==
                    artifacts.evaluator.evaluatorVersion)

            var durations: [Double] = []
            durations.reserveCapacity(iterations)
            var outcome: ExactPairedPreparationOutcome?
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
                    evaluator: evaluator
                )
                durations.append(seconds(ContinuousClock.now - start))
                #expect(prepared.candidateEvaluation.isComplete)
                #expect((2...QualityQualificationContract.maximumRenderPasses)
                    .contains(prepared.candidateEvaluation.attempts.count))
                #expect(prepared.candidateEvaluation.comparison != .unavailable)
                #expect(prepared.candidateEvaluation.policyVersion ==
                        evaluator.policyVersion)
                #expect(prepared.candidateEvaluation.evaluatorVersion ==
                        evaluator.evaluatorVersion)
                #expect(prepared.qualityDecision.policyVersion ==
                        evaluator.policyVersion)
                #expect(prepared.commitEligible)
                let current = ExactPairedPreparationOutcome(
                    prepared: prepared,
                    evaluator: artifacts.evaluator
                )
                if let outcome {
                    #expect(current == outcome)
                } else {
                    outcome = current
                }
            }

            let rateRecord = ExactPairedPreparationRateRecord(
                sampleRate: sampleRate,
                durationsSeconds: durations,
                outcome: try #require(outcome)
            )
            let lookaheadBound = rateRecord.outcome.attemptCount <= 2
                ? AutonomousPreparationResourceBudget
                    .minimumPhraseLookaheadSeconds
                : AutonomousPreparationResourceBudget
                    .maximumSingleHoldLookaheadSeconds
            #expect(rateRecord.worstSeconds < lookaheadBound)
            rateRecords.append(rateRecord)

            let gate = RepresentativeCancellationGate()
            let observed = ExactPolicyCancellationEvaluator(
                base: evaluator,
                gate: gate
            )
            let cancelled = AutonomousPhrasePreparer.prepareIfNotCancelled(
                candidates: fixture.pairedCandidates,
                sessionSeed: fixture.state.rootSeed,
                memory: fixture.state.memory,
                sampleRate: sampleRate,
                incomingRenderState: RenderState(),
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                evaluator: observed,
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
        let record = ExactPairedPreparationOperationalRecord(
            iterationCount: iterations,
            artifactLoadSeconds: artifactLoadSeconds,
            profileFingerprint: artifacts.profile.fingerprint,
            adversarialSuiteFingerprint: artifacts.adversarialSuite.fingerprint,
            policyVersion: artifacts.evaluator.policyVersion,
            evaluatorVersion: artifacts.evaluator.evaluatorVersion,
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

    private func minimumPreparationFixture() throws -> (
        state: AutonomousSessionState,
        candidates: AutonomousPhraseCandidates
    ) {
        for seed in UInt64(1)...4_096 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let candidates = director.candidates(from: state)
            if candidates.primary.barCount == 4 {
                return (state, candidates)
            }
        }
        throw PairedPreparationReadinessError.minimumFixtureUnavailable
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
    case minimumFixtureUnavailable
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

private struct ExactPolicyCancellationEvaluator:
        AutonomousCandidateEvaluating {
    private let base: ProfessionalQualityPreparationEvaluator
    private let gate: RepresentativeCancellationGate

    fileprivate init(
        base: ProfessionalQualityPreparationEvaluator,
        gate: RepresentativeCancellationGate
    ) {
        self.base = base
        self.gate = gate
    }

    package var policyVersion: String { base.policyVersion }
    package var evaluatorVersion: String { base.evaluatorVersion }
    package var requiresPairedCandidates: Bool {
        base.requiresPairedCandidates
    }

    package func requestsPairedComparison(
        after primary: AutonomousCandidateEvaluationVector
    ) -> Bool {
        base.requestsPairedComparison(after: primary)
    }

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        let comparison = base.compare(
            primary: primary,
            alternate: alternate
        )
        gate.cancelAfterComparison()
        return comparison
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        base.requestsHomeUpperTimbreCorrection(for: candidate, slot: slot)
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        base.terminalVerdict(selected: selected, transaction: transaction)
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

private struct ExactPairedPreparationOperationalRecord: Encodable {
    let schemaVersion = 1
    let iterationCount: Int
    let artifactLoadSeconds: Double
    let profileFingerprint: String
    let adversarialSuiteFingerprint: String
    let policyVersion: String
    let evaluatorVersion: String
    let rates: [ExactPairedPreparationRateRecord]
    let cancellation: [PairedCancellationRecord]
    let conservativePeakWorkingByteCount: Int
    let maximumResidentSetSizeBytes: Int
    let residentSetIncreaseBytes: Int
}

private struct ExactPairedPreparationOutcome: Encodable, Equatable {
    let attemptCount: Int
    let selectedSlot: AutonomousCandidateSlot?
    let comparison: AutonomousCandidateComparison
    let decisionOutcome: QualityDecisionOutcome
    let reasonCodes: [QualityReasonCode]
    let assessments: [ExactCandidateAssessmentRecord]
    let transactionFingerprint: String

    init(
        prepared: PreparedAutonomousPhrase,
        evaluator: ProfessionalQualityPairedCandidateEvaluator
    ) {
        attemptCount = prepared.candidateEvaluation.attempts.count
        selectedSlot = prepared.candidateEvaluation.selectedSlot
        comparison = prepared.candidateEvaluation.comparison
        decisionOutcome = prepared.qualityDecision.outcome
        reasonCodes = prepared.qualityDecision.reasonCodes
        assessments = prepared.candidateEvaluation.attempts.map { attempt in
            ExactCandidateAssessmentRecord(
                attempt: attempt,
                assessment: evaluator.assessment(of: attempt.vector)
            )
        }
        transactionFingerprint = prepared.candidateEvaluationFingerprint
    }
}

private struct ExactCandidateAssessmentRecord: Encodable, Equatable {
    let slot: AutonomousCandidateSlot
    let attemptKind: AutonomousCandidateAttemptKind
    let availability: ProfessionalQualityCandidateAssessmentAvailability
    let accepted: Bool
    let checkpoints: [CanonicalJourneyCheckpoint]
    let verdicts: [ProfessionalQualityReportVerdict]

    init(
        attempt: AutonomousCandidateAttempt,
        assessment: ProfessionalQualityCandidateAssessment
    ) {
        slot = attempt.slot
        attemptKind = attempt.kind
        availability = assessment.availability
        accepted = assessment.accepted
        checkpoints = assessment.checkpoints
        verdicts = assessment.verdicts
    }
}

private struct ExactPairedPreparationRateRecord: Encodable {
    let sampleRate: Double
    let medianSeconds: Double
    let percentile95Seconds: Double
    let worstSeconds: Double
    let outcome: ExactPairedPreparationOutcome

    init(
        sampleRate: Double,
        durationsSeconds: [Double],
        outcome: ExactPairedPreparationOutcome
    ) {
        self.sampleRate = sampleRate
        let sorted = durationsSeconds.sorted()
        medianSeconds = Self.percentile(sorted, fraction: 0.50)
        percentile95Seconds = Self.percentile(sorted, fraction: 0.95)
        worstSeconds = sorted.last ?? 0
        self.outcome = outcome
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
