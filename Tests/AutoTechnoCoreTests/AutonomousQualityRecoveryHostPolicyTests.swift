import AutoTechnoCore
import AutoTechnoDSP
import AutoTechnoTransport
import Testing

@Suite("Shared desktop recovery policy")
struct AutonomousQualityRecoveryHostPolicyTests {
    private let rejection = QualityDecision(policyVersion: "test-calibrated-policy",
        outcome: .rejected, reasonCodes: [.guardrailRegressionV1],
        recoveryIntent: AutonomousQualityRecoveryIntent(
            spectralMovement: .increase, kickCrestReduction: .increase))

    @Test("Initial recovery retains every old finite transition and opens persistent waves")
    func initialWaves() {
        var actual = AutonomousQualityRetryContinuation()
        var expected = AutonomousQualityRetryContinuation()
        for _ in 0..<35 {
            let step = actual.recoveringAfterRejection(decision: rejection,
                targetPhraseIndex: 0, initialPreparation: true, coherentRepeatCount: 0)
            // Frozen pre-consolidation host behavior, including the last ordinal
            // and the wave opening after its actual rejection.
            expected = expected.recordingCalibratedRejection(decision: rejection,
                targetPhraseIndex: 0)
            let exhausted = expected.isExhausted(for: 0)
            if exhausted { expected = expected.beginningNextWave(targetPhraseIndex: 0) }
            #expect(step.continuation == expected)
            #expect(step.waveExhausted == exhausted)
            #expect(step.scheduling == .continueSerially)
            #expect(step.continuation.context(for: 0) != actual.context(for: 0))
            actual = step.continuation
        }
        #expect(actual.wave == 3)
        #expect(actual.recoveryIntent == rejection.recoveryIntent)
    }

    @Test("Successor retry needs a coherent presentation and yields at each wave")
    func successorBoundaries() {
        var continuation = AutonomousQualityRetryContinuation()
        let first = continuation.recoveringAfterRejection(decision: rejection,
            targetPhraseIndex: 15, initialPreparation: false, coherentRepeatCount: 0)
        #expect(first.scheduling == .awaitFirstCoherentRepeat)
        continuation = first.continuation.recordingPresentedRepeat(
            targetPhraseIndex: 15, barCount: 16)
        for ordinal in 2...AutonomousQualityRetryContinuation.maximumOrdinal {
            let step = continuation.recoveringAfterRejection(decision: rejection,
                targetPhraseIndex: 15, initialPreparation: false, coherentRepeatCount: 1)
            #expect(step.scheduling == .continueSerially)
            #expect(step.continuation.ordinal == ordinal)
            continuation = step.continuation
        }
        let exhausted = continuation.recoveringAfterRejection(decision: rejection,
            targetPhraseIndex: 15, initialPreparation: false, coherentRepeatCount: 1)
        #expect(exhausted.scheduling == .yieldUntilNextBoundary)
        #expect(exhausted.continuation.wave == 0)
        #expect(exhausted.continuation.presentedRepeatBars == 16)
        let next = exhausted.continuation.recordingPresentedRepeat(
            targetPhraseIndex: 15, barCount: 16).beginningNextWave(targetPhraseIndex: 15)
        #expect(next.wave == 1)
        #expect(next.ordinal == 0)
        #expect(next.presentedRepeatBars == 32)
        #expect(next.recoveryIntent == rejection.recoveryIntent)
    }

    @Test("Safety, provenance, unavailable policy and invalid targets never open retries")
    func failClosed() {
        let previous = AutonomousQualityRetryContinuation(targetPhraseIndex: 4,
            ordinal: 9, wave: 2, presentedRepeatBars: 32,
            recoveryIntent: rejection.recoveryIntent, exhausted: true)
        let decisions = [
            QualityDecision(policyVersion: "test-calibrated-policy", outcome: .rejected,
                reasonCodes: [.hardGateFailedV1]),
            QualityDecision(policyVersion: "test-calibrated-policy", outcome: .rejected,
                reasonCodes: [.guardrailRegressionV1, .evidenceMismatchV1]),
            QualityDecision(policyVersion: "test-calibrated-policy", outcome: .qualificationUnavailable,
                reasonCodes: [.evaluatorUnavailableV1])]
        for decision in decisions {
            for initial in [true, false] {
                let step = previous.recoveringAfterRejection(decision: decision,
                    targetPhraseIndex: 4, initialPreparation: initial, coherentRepeatCount: 99)
                #expect(step.continuation == previous)
                #expect(step.scheduling == .failClosed)
                #expect(step.waveExhausted)
            }
        }
        let invalid = previous.recoveringAfterRejection(decision: rejection,
            targetPhraseIndex: -1, initialPreparation: true, coherentRepeatCount: 99)
        #expect(invalid.continuation == previous)
        #expect(invalid.scheduling == .failClosed)
    }

    @Test("Target change cannot import another phrase's direction or presentation debt")
    func targetIsolation() {
        let old = AutonomousQualityRetryContinuation(targetPhraseIndex: 15,
            ordinal: 9, wave: 3, presentedRepeatBars: 80,
            recoveryIntent: AutonomousQualityRecoveryIntent(symbolicDensity: .decrease),
            exhausted: true)
        let step = old.recoveringAfterRejection(decision: rejection,
            targetPhraseIndex: 16, initialPreparation: false, coherentRepeatCount: 0)
        #expect(step.continuation.ordinal == 1)
        #expect(step.continuation.wave == 0)
        #expect(step.continuation.presentedRepeatBars == 0)
        #expect(step.continuation.recoveryIntent == rejection.recoveryIntent)
        #expect(step.scheduling == .awaitFirstCoherentRepeat)
    }

    @Test("Recovery context reaches the one score and exact request replay identity")
    func requestAndScoreBinding() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let recovered = AutonomousQualityRetryContinuation().recoveringAfterRejection(
            decision: rejection, targetPhraseIndex: state.phraseIndex,
            initialPreparation: true, coherentRepeatCount: 0).continuation
        let context = recovered.context(for: state.phraseIndex)
        func request(_ context: AutonomousQualityRecoveryContext) -> PhrasePreparationRequest {
            let key = PhrasePreparationKey(sessionSeed: state.rootSeed,
                phraseIndex: state.phraseIndex, sampleRate: 48_000, channelCount: 2,
                routeRecovery: false, qualityRevision: state.quality.revision,
                qualityPolicyVersion: state.quality.policyVersion,
                qualityControllerFingerprint: state.quality.acceptedControllerStateFingerprint,
                routeGeneration: 0, incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil,
                liveTargetStartSample: nil, qualityRecoveryContext: context)
            return PhrasePreparationRequest(key: key, sourceState: state,
                incomingLongHorizonState: nil, incomingRenderState: RenderState(),
                incomingGraphState: GeneratedDSPContinuationState(), previousGraph: nil,
                pendingLiveMasterBinding: nil)
        }
        let first = request(context), replay = request(context), neutral = request(.neutral)
        #expect(first.replayIdentity.isComplete)
        #expect(first.replayIdentity.matches(first))
        #expect(first.replayIdentity == replay.replayIdentity)
        #expect(first.replayIdentity != neutral.replayIdentity)
        #expect(first.sourceState == neutral.sourceState)
        let plan = director.plan(from: first.sourceState,
            qualityRecoveryContext: first.key.qualityRecoveryContext)
        #expect(plan.qualityRecoveryContext == context)
        #expect(plan == director.plan(from: replay.sourceState,
            qualityRecoveryContext: replay.key.qualityRecoveryContext))
        #expect(plan != director.plan(from: neutral.sourceState))
    }

    @Test("Wave overflow and presentation saturation remain deterministic")
    func boundedCounters() {
        let prior = AutonomousQualityRetryContinuation(targetPhraseIndex: 0,
            ordinal: 9, wave: .max, presentedRepeatBars: .max,
            recoveryIntent: rejection.recoveryIntent, exhausted: true)
        let step = prior.recoveringAfterRejection(decision: rejection,
            targetPhraseIndex: 0, initialPreparation: true, coherentRepeatCount: 0)
        #expect(step.continuation.wave == 0)
        #expect(step.continuation.ordinal == 0)
        #expect(step.continuation.presentedRepeatBars == UInt64.max)
        #expect(step.continuation.recordingPresentedRepeat(targetPhraseIndex: 0,
            barCount: 16).presentedRepeatBars == UInt64.max)
        #expect(step.scheduling == .continueSerially)
    }
}
