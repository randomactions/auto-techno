import AutoTechnoApp
import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("TechnoEngine live feedback scheduling")
struct TechnoEngineLiveFeedbackTests {
    @MainActor
    @Test("Production orchestration maps before capture and designates the first future occurrence")
    func startupAndResumeDesignateFreshOccurrence() {
        let owner = LiveFeedbackEngineOrchestrator(routeGeneration: 3)
        var starts = 0
        var stops = 0
        let start: (
            MixerPlayerClockMap,
            LiveFeedbackWorkerIdentity,
            LiveFeedbackRuntimeCoordinator
        ) -> Bool = { _, identity, runtime in
            starts += 1
            return runtime.consumerDidStart(identity: identity) &&
                runtime.producerDidStart(identity: identity)
        }
        let stop = { stops += 1 }

        #expect(owner.stageOccurrence(draft(
            phraseIndex: 2,
            startSample: 0,
            routeGeneration: 3
        )) == nil)
        #expect(owner.observeClock(
            probe(mixer: 0, player: 0),
            startCapture: start
        ) == .awaitingStableMap)
        #expect(starts == 0)
        let started = owner.observeClock(
            probe(mixer: 1_024, player: 1_024),
            startCapture: start
        )
        guard case .captureStarted = started else {
            Issue.record("expected capture after two stable probes")
            return
        }
        #expect(starts == 1)
        #expect(owner.ledger.playing == nil)
        let firstPostMap = owner.stageOccurrence(draft(
            phraseIndex: 2,
            startSample: 200_000,
            routeGeneration: 3
        ))
        #expect(firstPostMap != nil)
        #expect(owner.ledger.playing == firstPostMap)
        let alreadyScheduledPostResume = owner.stageOccurrence(draft(
            phraseIndex: 3,
            startSample: 400_000,
            routeGeneration: 3
        ))
        #expect(owner.ledger.scheduledSuccessor == alreadyScheduledPostResume)

        owner.pause(stopCapture: stop)
        #expect(stops == 1)
        #expect(owner.ledger.playing == nil)
        #expect(owner.clockMap == nil)
        owner.resume(routeGeneration: 3)
        _ = owner.observeClock(
            probe(mixer: 20_000, player: 20_000),
            startCapture: start
        )
        _ = owner.observeClock(
            probe(mixer: 21_024, player: 21_024),
            startCapture: start
        )
        let firstPostResume = owner.ledger.playing
        #expect(firstPostResume != nil)
        #expect(firstPostResume != firstPostMap)
        #expect(firstPostResume?.playerSampleRange ==
                alreadyScheduledPostResume?.playerSampleRange)
        #expect(owner.ledger.playing == firstPostResume)
    }

    @MainActor
    @Test("Clock-map failure never starts capture and leaves no owner state")
    func mapFailureCleansUpOwnership() {
        let owner = LiveFeedbackEngineOrchestrator(routeGeneration: 2)
        var starts = 0
        _ = owner.observeClock(
            probe(mixer: 0, player: 0),
            startCapture: { _, _, _ in starts += 1; return true }
        )
        #expect(owner.observeClock(
            probe(mixer: 1_024, player: 1_025),
            startCapture: { _, _, _ in starts += 1; return true }
        ) == .unavailable)
        #expect(starts == 0)
        // A running engine is not yet producer-quiescent. Clock failure may
        // request recovery, but it must not tear down the tap/queue inline.
        #expect(owner.clockMap == nil)
        #expect(owner.runtime.captureOwnership == .inactive)
        #expect(owner.runtime.activeIdentity == nil)
    }

    @MainActor
    @Test("Running clock drift requests recovery before producer teardown")
    func runningClockDriftRequiresRecovery() {
        let owner = activeOwner(routeGeneration: 2)
        #expect(owner.runtime.captureOwnership == .producerEnabled)

        let observation = owner.observeClock(
            probe(mixer: 2_048, player: 2_049),
            startCapture: { _, _, _ in
                Issue.record("drift must not start another producer")
                return false
            }
        )

        #expect(observation == .recoveryRequired)
        #expect(owner.clockMap == nil)
        #expect(owner.runtime.captureOwnership == .inactive)
        #expect(owner.runtime.activeIdentity == nil)
    }

    @MainActor
    @Test("Production capture lifecycle authorizes before tap and quiesces before destruction")
    func captureLifecycleOrdering() {
        let lifecycle = LiveFeedbackCaptureLifecycle()
        var startup: [String] = []
        #expect(lifecycle.startProducer(
            consumerDidStart: { startup.append("consumer"); return true },
            producerDidStart: { startup.append("producer"); return true },
            installTap: { startup.append("tap"); return true }
        ))
        #expect(startup == ["consumer", "producer", "tap"])

        startup = []
        #expect(!lifecycle.startProducer(
            consumerDidStart: { startup.append("consumer"); return true },
            producerDidStart: { startup.append("producer"); return false },
            installTap: {
                startup.append("tap")
                Issue.record("tap cannot install after producer denial")
                return true
            }
        ))
        #expect(startup == ["consumer", "producer"])

        var teardown: [String] = []
        var producerQuiesced = false
        lifecycle.quiesceAndTearDown(
            mode: .stop,
            quiescePlayer: { _ in teardown.append("player.stop") },
            quiesceEngine: { _ in
                teardown.append("engine.stop")
                producerQuiesced = true
            },
            removeTap: {
                #expect(producerQuiesced)
                teardown.append("tap.remove")
            },
            cancelAndJoinConsumer: {
                #expect(producerQuiesced)
                teardown.append("consumer.join")
                return "joined"
            },
            destroyQueue: { proof in
                #expect(producerQuiesced)
                teardown.append("queue.destroy.\(proof ?? "missing")")
            }
        )
        #expect(teardown == [
            "player.stop",
            "engine.stop",
            "tap.remove",
            "consumer.join",
            "queue.destroy.joined",
        ])
    }

    @Test("TechnoEngine delegates recovery, cache, context, and boundary work to production owners")
    func technoEngineWiresProductionOwners() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/TechnoEngine.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains(
            "liveFeedbackCaptureLifecycle.quiesceAndTearDown("
        ))
        #expect(source.contains(
            "liveFeedbackCaptureLifecycle.startProducer("
        ))
        #expect(source.contains(
            "liveFeedbackPreparation.analysisContext("
        ))
        #expect(source.contains(
            "liveFeedbackPreparation.correctionPayload("
        ))
        #expect(source.contains("if observation == .recoveryRequired"))
        #expect(source.contains("beginRecovery()"))
        #expect(source.contains(
            "liveFeedbackPreparation.completeSourceAdvance("
        ))
        #expect(source.contains(
            "liveFeedbackOrchestrator.completeSourceAdvance("
        ))
        #expect(!source.contains(
            "holdCorrectedSuccessorAtBoundaryMismatch("
        ))
        #expect(!source.contains(
            "liveTargetStartSample: nextTarget.partialValue"
        ))
        let feedbackHandler = try #require(source.range(
            of: "private func handleLiveFeedbackResult("
        ))
        let feedbackExpiration = try #require(source.range(
            of: "private func expirePendingLiveFeedbackAtBoundary("
        ))
        let feedbackHandlerBody = source[
            feedbackHandler.lowerBound..<feedbackExpiration.lowerBound
        ]
        #expect(!feedbackHandlerBody.contains(
            "liveFeedbackPreparation.removeCached {"
        ))
        #expect(!feedbackHandlerBody.contains(
            "preparationTask?.cancel()"
        ))
        let admission = try #require(source.range(of:
            "let correctedBoundaryDecision = LiveCorrectedSuccessorBoundaryPolicy.decide("
        ))
        let stateCommit = try #require(source.range(of:
            "currentPhrase = next"
        ))
        let cacheCommit = try #require(source.range(of:
            "liveFeedbackPreparation.removeCachedValue(forKey: nextKey)"
        ))
        let purgeCommit = try #require(source.range(of:
            "if correctedBoundaryDecision == .advance,\n" +
                "               nextKey.pendingLiveMasterProposalFingerprint != nil,\n" +
                "               !untrimmedPreparationAllowed {\n" +
                "                purgeUntrimmedSuccessor("
        ))
        let commitSearchRange = admission.lowerBound..<source.endIndex
        let sessionCommit = try #require(source.range(
            of: "sessionState = advancedState",
            range: commitSearchRange
        ))
        let longHorizonCommit = try #require(source.range(
            of: "longHorizonState = next.outgoingLongHorizonState",
            range: commitSearchRange
        ))
        let proposalCommit = try #require(source.range(of:
            "if next.request.pendingLiveMasterBinding != nil {\n" +
                "                    pendingLiveMasterBinding = nil"
        ))
        let successorCommit = try #require(source.range(of:
            "requestSuccessor(after: next)"
        ))
        for commit in [
            cacheCommit,
            purgeCommit,
            stateCommit,
            sessionCommit,
            longHorizonCommit,
            proposalCommit,
            successorCommit,
        ] {
            #expect(admission.lowerBound < commit.lowerBound)
        }
    }

    @MainActor
    @Test("Target mismatch expires one correction before repeating immutably")
    func targetMismatchExpiresBeforeAnyCommit() throws {
        let owner = activeOwner(routeGeneration: 12)
        let source = try #require(owner.stageOccurrence(draft(
            phraseIndex: 6,
            startSample: 200_000,
            routeGeneration: 12
        )))
        let identity = try #require(owner.runtime.activeIdentity)
        let proposalFingerprint = "proposal-boundary"
        #expect(owner.authorize(
            identity: identity,
            sourceOccurrence: source,
            targetPhraseIndex: 7,
            proposalFingerprint: proposalFingerprint
        ) == .invalidateUnscheduledSuccessor)

        let cache = LiveFeedbackPreparationOwner<Int, String, String>()
        cache.insertCachedValue("corrected", forKey: 7)
        var currentPhraseIndex = 6
        var sessionRevision = 4
        var pendingProposal: String? = proposalFingerprint
        var activeRequest: String? = proposalFingerprint
        var queuedRequest: String? = proposalFingerprint
        var expirationCount = 0
        var repeatCount = 0
        var secondRequestCount = 0

        let mismatch = LiveCorrectedSuccessorBoundaryPolicy.decide(
            hasLiveProposal: true,
            preparedTargetStartSample: 400_000,
            earliestEligibleFutureSample: 350_000,
            actualStartSample: 450_000
        )
        #expect(mismatch == .repeatAfterExpiringProposal)
        owner.performBoundary(
            sourcePhraseIndex: 6,
            targetPhraseIndex: 7,
            correctedSuccessorAvailable: mismatch == .advance,
            expireCorrectedSuccessor: {
                expirationCount += 1
                cache.removeCached { _, _ in true }
                pendingProposal = nil
                activeRequest = nil
                queuedRequest = nil
            },
            advanceCorrectedSuccessor: {
                currentPhraseIndex = 7
                sessionRevision += 1
            },
            repeatAcceptedPCM: { repeatCount += 1 }
        )

        #expect(currentPhraseIndex == 6)
        #expect(sessionRevision == 4)
        #expect(pendingProposal == nil)
        #expect(activeRequest == nil)
        #expect(queuedRequest == nil)
        #expect(cache.cachedCount == 0)
        #expect(expirationCount == 1)
        #expect(repeatCount == 1)
        #expect(owner.runtime.acceptedPCMHold?.proposalFingerprint ==
                proposalFingerprint)
        #expect(owner.runtime.acceptedPCMHold?
            .preserveCoursePreparationReleased == false)
        #expect(!owner.allowsUntrimmedPreparation(
            sourcePhraseIndex: 6,
            targetPhraseIndex: 7
        ))

        owner.runtime.performBoundary(
            sourcePhraseIndex: 6,
            targetPhraseIndex: 7,
            correctedSuccessorAvailable: false,
            expireCorrectedSuccessor: { expirationCount += 1 },
            advanceCorrectedSuccessor: {
                Issue.record("an expired proposal cannot advance")
            },
            repeatAcceptedPCM: { repeatCount += 1 },
            requestUntrimmedSuccessor: { secondRequestCount += 1 }
        )
        #expect(expirationCount == 1)
        #expect(repeatCount == 2)
        #expect(secondRequestCount == 1)
        #expect(cache.cachedCount == 0)
        #expect(owner.runtime.acceptedPCMHold?
            .preserveCoursePreparationReleased == true)
        #expect(owner.allowsUntrimmedPreparation(
            sourcePhraseIndex: 6,
            targetPhraseIndex: 7
        ))

        currentPhraseIndex = 7
        sessionRevision += 1
        owner.completeSourceAdvance(
            sourcePhraseIndex: 6,
            targetPhraseIndex: 7
        )
        #expect(currentPhraseIndex == 7)
        #expect(sessionRevision == 5)
        #expect(pendingProposal == nil)
        #expect(cache.cachedCount == 0)
        #expect(owner.runtime.acceptedPCMHold == nil)
    }

    @MainActor
    @Test("A late source result cannot authorize after its target is playing")
    func lateSourceExpiresWhenTargetIsPlaying() {
        let owner = activeOwner(routeGeneration: 5)
        let source = owner.stageOccurrence(draft(
            phraseIndex: 4,
            startSample: 200_000,
            routeGeneration: 5
        ))!
        let target = owner.stageOccurrence(draft(
            phraseIndex: 5,
            startSample: 400_000,
            routeGeneration: 5
        ))!
        owner.promote(playerSample: target.playerSampleRange.lowerBound)
        let identity = owner.runtime.activeIdentity!

        #expect(owner.authorize(
            identity: identity,
            sourceOccurrence: source,
            targetPhraseIndex: 5,
            proposalFingerprint: "late"
        ) == .invalidPhraseRelationship)
        #expect(owner.runtime.invalidatedSourceOccurrences.isEmpty)
        #expect(owner.ledger.playing == target)
    }

    @MainActor
    @Test("Route reset preserves committed trim and releases preserve-course recovery at a boundary")
    func routeResetPreservesTrimAndReleasesRecoveryAtBoundary() {
        let owner = activeOwner(routeGeneration: 3)
        let source = owner.stageOccurrence(draft(
            phraseIndex: 7,
            startSample: 200_000,
            routeGeneration: 3,
            appliedMasterTrimDB: -0.75
        ))!
        let identity = owner.runtime.activeIdentity!
        #expect(owner.authorize(
            identity: identity,
            sourceOccurrence: source,
            targetPhraseIndex: 8,
            proposalFingerprint: "proposal-a"
        ) == .invalidateUnscheduledSuccessor)
        owner.rejectCorrectedSuccessor(
            sourceOccurrence: source,
            targetPhraseIndex: 8,
            proposalFingerprint: "proposal-a",
            expireCorrectedSuccessor: {}
        )
        owner.routeReset(routeGeneration: 4, stopCapture: {})

        #expect(owner.runtime.acceptedPCMHold?.sourceOccurrence == source)
        #expect(owner.runtime.acceptedPCMHold?.sourceOccurrence
            .appliedMasterTrimDB == -0.75)
        #expect(!owner.allowsUntrimmedPreparation(
            sourcePhraseIndex: 7,
            targetPhraseIndex: 8
        ))

        _ = owner.observeClock(
            probe(mixer: 0, player: 0),
            startCapture: { _, _, _ in true }
        )
        _ = owner.observeClock(
            probe(mixer: 1_024, player: 1_024),
            startCapture: { _, identity, runtime in
                runtime.consumerDidStart(identity: identity) &&
                    runtime.producerDidStart(identity: identity)
            }
        )
        let repeated = owner.stageOccurrence(draft(
            phraseIndex: 7,
            startSample: 400_000,
            routeGeneration: 4,
            appliedMasterTrimDB: -0.75
        ))!
        let freshIdentity = owner.runtime.activeIdentity!
        #expect(owner.authorize(
            identity: freshIdentity,
            sourceOccurrence: source,
            targetPhraseIndex: 8,
            proposalFingerprint: "forged-old"
        ) == .invalidPhraseRelationship)
        #expect(owner.authorize(
            identity: freshIdentity,
            sourceOccurrence: repeated,
            targetPhraseIndex: 8,
            proposalFingerprint: "proposal-b"
        ) == .duplicateSourcePhrase)
        #expect(owner.runtime.acceptedPCMHold != nil)

        var repeats = 0
        var preserveCourseRequests = 0
        owner.runtime.performBoundary(
            sourcePhraseIndex: 7,
            targetPhraseIndex: 8,
            correctedSuccessorAvailable: false,
            expireCorrectedSuccessor: {},
            advanceCorrectedSuccessor: {
                Issue.record("a rejected correction cannot advance")
            },
            repeatAcceptedPCM: { repeats += 1 },
            requestUntrimmedSuccessor: { preserveCourseRequests += 1 }
        )
        #expect(repeats == 1)
        #expect(preserveCourseRequests == 1)
        #expect(owner.allowsUntrimmedPreparation(
            sourcePhraseIndex: 7,
            targetPhraseIndex: 8
        ))

        owner.completeSourceAdvance(
            sourcePhraseIndex: 7,
            targetPhraseIndex: 8
        )
        #expect(owner.runtime.acceptedPCMHold == nil)
    }

    @MainActor
    @Test("Held accepted PCM preserves the qualified target recipe for course recovery")
    func heldRepeatPreservesQualifiedTargetRecipe() throws {
        let plans = sourceAndTargetPlans()
        let preparation = LiveFeedbackPreparationOwner<
            TestPreparationKey,
            Int,
            String
        >()
        let baseKey = TestPreparationKey(
            phraseIndex: plans.target.phraseIndex,
            proposalFingerprint: nil
        )
        preparation.insertCachedValue(1, forKey: baseKey)
        #expect(preparation.rememberTargetReference(
            sourcePlan: plans.source,
            targetPlan: plans.target,
            routeGeneration: 3,
            sampleRate: 48_000,
            basePayload: "base-request"
        ))

        let owner = activeOwner(routeGeneration: 3)
        let sourceRange = scheduledRange(
            plan: plans.source,
            incoming: plans.incoming,
            startSample: 800_000,
            routeGeneration: 3,
            qualityPolicyVersion: testLiveQualityPolicyVersion
        )
        let source = try #require(owner.stageOccurrence(
            LiveFeedbackScheduledOccurrenceDraft(copying: sourceRange)
        ))
        let identity = try #require(owner.runtime.activeIdentity)
        #expect(owner.authorize(
            identity: identity,
            sourceOccurrence: source,
            targetPhraseIndex: plans.target.phraseIndex,
            proposalFingerprint: "proposal-a"
        ) == .invalidateUnscheduledSuccessor)

        var expired = 0
        owner.rejectCorrectedSuccessor(
            sourceOccurrence: source,
            targetPhraseIndex: plans.target.phraseIndex,
            proposalFingerprint: "proposal-a",
            expireCorrectedSuccessor: { expired += 1 }
        )
        var repeats = 0
        var preserveCourseRequests = 0
        owner.runtime.performBoundary(
            sourcePhraseIndex: plans.source.phraseIndex,
            targetPhraseIndex: plans.target.phraseIndex,
            correctedSuccessorAvailable: false,
            expireCorrectedSuccessor: { expired += 1 },
            advanceCorrectedSuccessor: {},
            repeatAcceptedPCM: { repeats += 1 },
            requestUntrimmedSuccessor: { preserveCourseRequests += 1 }
        )
        #expect(expired == 1)
        #expect(repeats == 1)
        #expect(preserveCourseRequests == 1)
        #expect(preparation.firstCached(where: { key, _ in
            key == baseKey
        })?.value == 1)
        #expect(preparation.hasTargetReference)
        #expect(preparation.hasCurrentTargetPayload)
        #expect(owner.allowsUntrimmedPreparation(
            sourcePhraseIndex: plans.source.phraseIndex,
            targetPhraseIndex: plans.target.phraseIndex
        ))

        #expect(owner.authorize(
            identity: identity,
            sourceOccurrence: source,
            targetPhraseIndex: plans.target.phraseIndex,
            proposalFingerprint: "proposal-b"
        ) == .duplicateSourcePhrase)

        preparation.completeSourceAdvance(
            sourcePhraseIndex: plans.source.phraseIndex,
        )
        owner.completeSourceAdvance(
            sourcePhraseIndex: plans.source.phraseIndex,
            targetPhraseIndex: plans.target.phraseIndex
        )
        #expect(owner.runtime.acceptedPCMHold == nil)
        #expect(!preparation.hasTargetReference)
    }

    @MainActor
    @Test("A missed corrected successor releases one preserve-course preparation")
    func missedCorrectedSuccessorReleasesPreserveCoursePreparation() {
        let runtime = activeRuntime(routeGeneration: 8)
        let identity = try! #require(runtime.activeIdentity)
        #expect(runtime.authorizeCorrection(
            identity: identity,
            sourceOccurrence: occurrence(phraseIndex: 4, startSample: 1_000, routeGeneration: 8),
            targetPhraseIndex: 5,
            proposalFingerprint: "proposal-a",
            sourceIsExactPlayingOccurrence: true,
            targetHasScheduledSamples: false
        ) == .invalidateUnscheduledSuccessor)

        var acceptedPCMRepeatCount = 0
        var fallbackPreparationCount = 0
        var correctedExpirationCount = 0
        runtime.performBoundary(
            sourcePhraseIndex: 4,
            targetPhraseIndex: 5,
            correctedSuccessorAvailable: false,
            expireCorrectedSuccessor: { correctedExpirationCount += 1 },
            advanceCorrectedSuccessor: {},
            repeatAcceptedPCM: { acceptedPCMRepeatCount += 1 },
            requestUntrimmedSuccessor: { fallbackPreparationCount += 1 }
        )

        #expect(runtime.acceptedPCMHold?.sourcePhraseIndex == 4)
        #expect(runtime.acceptedPCMHold?.targetPhraseIndex == 5)
        #expect(runtime.acceptedPCMHold?
            .preserveCoursePreparationReleased == false)
        #expect(correctedExpirationCount == 1)
        #expect(acceptedPCMRepeatCount == 1)
        #expect(fallbackPreparationCount == 0)
        #expect(!runtime.allowsUntrimmedPreparation(
            sourcePhraseIndex: 4,
            targetPhraseIndex: 5
        ))

        runtime.performBoundary(
            sourcePhraseIndex: 4,
            targetPhraseIndex: 5,
            correctedSuccessorAvailable: false,
            expireCorrectedSuccessor: { correctedExpirationCount += 1 },
            advanceCorrectedSuccessor: {},
            repeatAcceptedPCM: { acceptedPCMRepeatCount += 1 },
            requestUntrimmedSuccessor: { fallbackPreparationCount += 1 }
        )
        #expect(correctedExpirationCount == 1)
        #expect(acceptedPCMRepeatCount == 2)
        #expect(fallbackPreparationCount == 1)
        #expect(runtime.acceptedPCMHold?
            .preserveCoursePreparationReleased == true)
        #expect(runtime.allowsUntrimmedPreparation(
            sourcePhraseIndex: 4,
            targetPhraseIndex: 5
        ))

        runtime.performBoundary(
            sourcePhraseIndex: 4,
            targetPhraseIndex: 5,
            correctedSuccessorAvailable: false,
            expireCorrectedSuccessor: { correctedExpirationCount += 1 },
            advanceCorrectedSuccessor: {},
            repeatAcceptedPCM: { acceptedPCMRepeatCount += 1 },
            requestUntrimmedSuccessor: { fallbackPreparationCount += 1 }
        )
        #expect(correctedExpirationCount == 1)
        #expect(acceptedPCMRepeatCount == 3)
        #expect(fallbackPreparationCount == 1)

        #expect(runtime.authorizeCorrection(
            identity: identity,
            sourceOccurrence: occurrence(
                phraseIndex: 4,
                startSample: 200_000,
                routeGeneration: 8
            ),
            targetPhraseIndex: 5,
            proposalFingerprint: "proposal-b",
            sourceIsExactPlayingOccurrence: true,
            targetHasScheduledSamples: false
        ) == .duplicateSourcePhrase)

        runtime.completeSourceAdvance(
            sourcePhraseIndex: 4,
            targetPhraseIndex: 5
        )
        #expect(runtime.acceptedPCMHold == nil)
    }

    @MainActor
    @Test("A rejected corrected candidate survives lifecycle reset and releases bounded recovery")
    func rejectedCorrectionReleasesBoundedRecovery() {
        let runtime = activeRuntime(routeGeneration: 3)
        let identity = try! #require(runtime.activeIdentity)
        #expect(runtime.authorizeCorrection(
            identity: identity,
            sourceOccurrence: occurrence(phraseIndex: 7, startSample: 1_000, routeGeneration: 3),
            targetPhraseIndex: 8,
            proposalFingerprint: "proposal-a",
            sourceIsExactPlayingOccurrence: true,
            targetHasScheduledSamples: false
        ) == .invalidateUnscheduledSuccessor)

        var expired = 0
        runtime.rejectCorrectedSuccessor(
            sourceOccurrence: occurrence(phraseIndex: 7, startSample: 1_000, routeGeneration: 3),
            targetPhraseIndex: 8,
            proposalFingerprint: "proposal-a",
            expireCorrectedSuccessor: { expired += 1 }
        )
        #expect(expired == 1)
        #expect(runtime.acceptedPCMHold != nil)
        #expect(!runtime.allowsUntrimmedPreparation(
            sourcePhraseIndex: 7,
            targetPhraseIndex: 8
        ))

        runtime.pause()
        runtime.resume(routeGeneration: 3)
        #expect(runtime.acceptedPCMHold != nil)

        let freshIdentity = runtime.recreateCoordinator(routeGeneration: 3)
        #expect(runtime.consumerDidStart(identity: freshIdentity))
        #expect(runtime.producerDidStart(identity: freshIdentity))
        #expect(runtime.authorizeCorrection(
            identity: freshIdentity,
            sourceOccurrence: occurrence(phraseIndex: 7, startSample: 200_000, routeGeneration: 3),
            targetPhraseIndex: 8,
            proposalFingerprint: "proposal-b",
            sourceIsExactPlayingOccurrence: true,
            targetHasScheduledSamples: false
        ) == .duplicateSourcePhrase)
        #expect(runtime.acceptedPCMHold != nil)

        runtime.routeReset(routeGeneration: 4)
        #expect(runtime.acceptedPCMHold != nil)
        var repeats = 0
        var preserveCourseRequests = 0
        runtime.performBoundary(
            sourcePhraseIndex: 7,
            targetPhraseIndex: 8,
            correctedSuccessorAvailable: false,
            expireCorrectedSuccessor: { expired += 1 },
            advanceCorrectedSuccessor: {},
            repeatAcceptedPCM: { repeats += 1 },
            requestUntrimmedSuccessor: { preserveCourseRequests += 1 }
        )
        #expect(expired == 1)
        #expect(repeats == 1)
        #expect(preserveCourseRequests == 1)
        #expect(runtime.allowsUntrimmedPreparation(
            sourcePhraseIndex: 7,
            targetPhraseIndex: 8
        ))
    }

    @MainActor
    @Test("Already-scheduled and duplicate sources never invalidate preparation")
    func invalidationIsFutureOnlyAndOncePerSource() {
        let runtime = activeRuntime(routeGeneration: 3)
        let identity = try! #require(runtime.activeIdentity)

        #expect(runtime.authorizeCorrection(
            identity: identity,
            sourceOccurrence: occurrence(phraseIndex: 4, startSample: 1_000, routeGeneration: 3),
            targetPhraseIndex: 5,
            proposalFingerprint: "scheduled",
            sourceIsExactPlayingOccurrence: true,
            targetHasScheduledSamples: true
        ) == .deferAlreadyScheduledSuccessor)
        #expect(runtime.authorizeCorrection(
            identity: identity,
            sourceOccurrence: occurrence(phraseIndex: 4, startSample: 1_000, routeGeneration: 3),
            targetPhraseIndex: 5,
            proposalFingerprint: "first",
            sourceIsExactPlayingOccurrence: true,
            targetHasScheduledSamples: false
        ) == .invalidateUnscheduledSuccessor)
        #expect(runtime.authorizeCorrection(
            identity: identity,
            sourceOccurrence: occurrence(phraseIndex: 4, startSample: 1_000, routeGeneration: 3),
            targetPhraseIndex: 5,
            proposalFingerprint: "duplicate",
            sourceIsExactPlayingOccurrence: true,
            targetHasScheduledSamples: false
        ) == .duplicateSourcePhrase)
    }

    @MainActor
    @Test("Invalidated occurrence history stays fixed while one phrase repeats")
    func invalidationHistoryIsBounded() {
        let runtime = activeRuntime(routeGeneration: 3)
        let identity = try! #require(runtime.activeIdentity)

        for repetition in 0..<12 {
            #expect(runtime.authorizeCorrection(
                identity: identity,
                sourceOccurrence: occurrence(
                    phraseIndex: 4,
                    startSample: Int64(1_000 + repetition * 200_000),
                    routeGeneration: 3
                ),
                targetPhraseIndex: 5,
                proposalFingerprint: "proposal-\(repetition)",
                sourceIsExactPlayingOccurrence: true,
                targetHasScheduledSamples: false
            ) == .invalidateUnscheduledSuccessor)
        }

        #expect(runtime.invalidatedSourceOccurrences.count ==
                LiveFeedbackRuntimeCoordinator
                    .maximumRetainedInvalidatedSources)
    }

    @MainActor
    @Test("Playback occurrence epoch overflow fails closed")
    func playbackOccurrenceEpochOverflowFailsClosed() {
        let runtime = LiveFeedbackRuntimeCoordinator(
            routeGeneration: 3,
            occurrenceEpoch: .max
        )
        runtime.resume(routeGeneration: 3)
        let identity = runtime.recreateCoordinator(routeGeneration: 3)
        #expect(runtime.consumerDidStart(identity: identity))
        #expect(runtime.producerDidStart(identity: identity))

        #expect(!runtime.resetPlaybackTimeline(routeGeneration: 3))
        #expect(runtime.occurrenceEpoch == .max)
        #expect(runtime.activeIdentity == nil)
        #expect(runtime.captureOwnership == .inactive)
    }

    @MainActor
    @Test("A queued pre-pause result is dropped by exact lifecycle and coordinator identity")
    func queuedPrePauseResultIsDropped() async {
        let runtime = activeRuntime(routeGeneration: 9)
        let staleIdentity = try! #require(runtime.activeIdentity)
        let delivery = BufferedLiveFeedbackResultDelivery()
        var invalidationCount = 0

        delivery.enqueue(identity: staleIdentity) { identity in
            if runtime.authorizeCorrection(
                identity: identity,
                sourceOccurrence: occurrence(phraseIndex: 2, startSample: 1_000, routeGeneration: 9),
                targetPhraseIndex: 3,
                proposalFingerprint: "stale",
                sourceIsExactPlayingOccurrence: true,
                targetHasScheduledSamples: false
            ) == .invalidateUnscheduledSuccessor {
                invalidationCount += 1
            }
        }
        runtime.pause()
        runtime.resume(routeGeneration: 9)
        let freshIdentity = runtime.recreateCoordinator(routeGeneration: 9)
        #expect(freshIdentity.lifecycleToken > staleIdentity.lifecycleToken)
        #expect(freshIdentity.coordinatorID != staleIdentity.coordinatorID)
        #expect(runtime.consumerDidStart(identity: freshIdentity))
        #expect(runtime.producerDidStart(identity: freshIdentity))

        await delivery.flush()

        #expect(invalidationCount == 0)
        #expect(runtime.invalidatedSourceOccurrences.isEmpty)
    }

    @MainActor
    @Test("Producer ownership requires a running consumer and resume creates a fresh generation")
    func producerRequiresConsumerAndResumeIsFresh() {
        let runtime = LiveFeedbackRuntimeCoordinator(routeGeneration: 5)
        runtime.resume(routeGeneration: 5)
        let first = runtime.recreateCoordinator(routeGeneration: 5)

        #expect(!runtime.producerDidStart(identity: first))
        #expect(runtime.consumerDidStart(identity: first))
        #expect(runtime.producerDidStart(identity: first))
        #expect(runtime.captureOwnership == .producerEnabled)

        runtime.clockMapFailed()
        #expect(runtime.captureOwnership == .inactive)
        #expect(runtime.activeIdentity == nil)

        runtime.resume(routeGeneration: 5)
        let second = runtime.recreateCoordinator(routeGeneration: 5)
        #expect(second.lifecycleToken > first.lifecycleToken)
        #expect(second.coordinatorID != first.coordinatorID)
        #expect(runtime.captureOwnership == .queueReady)
        #expect(runtime.consumerDidStart(identity: second))
        #expect(runtime.producerDidStart(identity: second))
    }

    @MainActor
    @Test("Every lifecycle boundary rotates identity monotonically")
    func everyLifecycleBoundaryRotatesIdentity() {
        let runtime = activeRuntime(routeGeneration: 5)
        let initial = runtime.lifecycleToken

        runtime.pause()
        let paused = runtime.lifecycleToken
        runtime.resume(routeGeneration: 5)
        let resumed = runtime.lifecycleToken
        _ = runtime.recreateCoordinator(routeGeneration: 5)
        let recreated = runtime.lifecycleToken
        runtime.routeReset(routeGeneration: 6)
        let routed = runtime.lifecycleToken
        runtime.shutdown()
        let shutDown = runtime.lifecycleToken

        #expect(initial < paused)
        #expect(paused < resumed)
        #expect(resumed < recreated)
        #expect(recreated < routed)
        #expect(routed < shutDown)
        #expect(runtime.captureOwnership == .inactive)
        #expect(runtime.activeIdentity == nil)
    }

    @MainActor
    private func activeRuntime(
        routeGeneration: Int
    ) -> LiveFeedbackRuntimeCoordinator {
        let runtime = LiveFeedbackRuntimeCoordinator(
            routeGeneration: routeGeneration
        )
        runtime.resume(routeGeneration: routeGeneration)
        let identity = runtime.recreateCoordinator(
            routeGeneration: routeGeneration
        )
        #expect(runtime.consumerDidStart(identity: identity))
        #expect(runtime.producerDidStart(identity: identity))
        return runtime
    }

    @MainActor
    private func activeOwner(
        routeGeneration: Int
    ) -> LiveFeedbackEngineOrchestrator {
        let owner = LiveFeedbackEngineOrchestrator(
            routeGeneration: routeGeneration
        )
        _ = owner.observeClock(
            probe(mixer: 0, player: 0),
            startCapture: { _, _, _ in true }
        )
        _ = owner.observeClock(
            probe(mixer: 1_024, player: 1_024),
            startCapture: { _, identity, runtime in
                runtime.consumerDidStart(identity: identity) &&
                    runtime.producerDidStart(identity: identity)
            }
        )
        return owner
    }

    private func probe(
        mixer: Double,
        player: Double
    ) -> MixerPlayerClockProbe {
        MixerPlayerClockProbe(
            mixerSample: mixer,
            playerSample: player,
            mixerSampleRate: 48_000,
            playerSampleRate: 48_000
        )
    }

    private func draft(
        phraseIndex: Int,
        startSample: Int64,
        routeGeneration: Int,
        occurrenceEpoch: UInt64 = 0,
        appliedMasterTrimDB: Double = 0
    ) -> LiveFeedbackScheduledOccurrenceDraft {
        let range = occurrence(
            phraseIndex: phraseIndex,
            startSample: startSample,
            routeGeneration: routeGeneration
        )
        return LiveFeedbackScheduledOccurrenceDraft(
            phraseIndex: range.phraseIndex,
            planFingerprint: range.planFingerprint,
            playerSampleRange: range.playerSampleRange,
            sampleRate: range.sampleRate,
            routeGeneration: range.routeGeneration,
            occurrenceEpoch: occurrenceEpoch,
            controllerRevision: range.controllerRevision,
            qualityPolicyVersion: range.qualityPolicyVersion,
            evaluatorVersion: range.evaluatorVersion,
            controllerPolicyVersion: range.controllerPolicyVersion,
            controllerStateFingerprint: range.controllerStateFingerprint,
            appliedMasterTrimDB: appliedMasterTrimDB,
            applicableCheckpoints: range.applicableCheckpoints
        )
    }

    private func occurrence(
        phraseIndex: Int,
        startSample: Int64,
        routeGeneration: Int
    ) -> ScheduledPhraseRange {
        ScheduledPhraseRange(
            phraseIndex: phraseIndex,
            planFingerprint: "0123456789abcdef",
            playerSampleRange: startSample..<(startSample + 160_000),
            mixerSampleRange: startSample..<(startSample + 160_000),
            sampleRate: 48_000,
            routeGeneration: routeGeneration,
            controllerRevision: 0,
            qualityPolicyVersion: "policy",
            evaluatorVersion: ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier,
            controllerPolicyVersion: LiveFeedbackContract
                .controllerPolicyVersion,
            controllerStateFingerprint: "fedcba9876543210",
            appliedMasterTrimDB: 0,
            applicableCheckpoints: [.establishment],
            earliestEligibleFutureSample: startSample + 160_000
        )
    }

    private struct TestPreparationKey: Hashable {
        let phraseIndex: Int
        let proposalFingerprint: String?
    }

    private var testLiveQualityPolicyVersion: String {
        [
            ProfessionalQualityPrimaryEvaluator.policyFamilyVersion,
            "profile-1111111111111111",
            "adversarial-2222222222222222",
            "holdout-3333333333333333",
        ].joined(separator: ".")
    }

    private func sourceAndTargetPlans() -> (
        source: AutonomousPhrasePlan,
        target: AutonomousPhrasePlan,
        incoming: LiveMasterHeadroomContinuationState
    ) {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let source = director.plan(from: state)
        let targetState = state.advance(
            using: source,
            quality: state.quality,
            liveMasterHeadroom: state.liveMasterHeadroom
        )
        return (
            source,
            director.plan(from: targetState),
            state.liveMasterHeadroom
        )
    }

    private func scheduledRange(
        plan: AutonomousPhrasePlan,
        incoming: LiveMasterHeadroomContinuationState,
        startSample: Int64,
        routeGeneration: Int,
        occurrenceEpoch: UInt64 = 0,
        qualityPolicyVersion: String
    ) -> ScheduledPhraseRange {
        let identity = LiveOutputPlanSourceIdentity(plan: plan)
        let upper = startSample + 160_000
        return ScheduledPhraseRange(
            phraseIndex: plan.phraseIndex,
            planFingerprint: identity.planFingerprint,
            playerSampleRange: startSample..<upper,
            mixerSampleRange: startSample..<upper,
            sampleRate: 48_000,
            routeGeneration: routeGeneration,
            occurrenceEpoch: occurrenceEpoch,
            controllerRevision: incoming.revision,
            qualityPolicyVersion: qualityPolicyVersion,
            evaluatorVersion: ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier,
            controllerPolicyVersion: LiveFeedbackContract
                .controllerPolicyVersion,
            controllerStateFingerprint: incoming.fingerprint,
            appliedMasterTrimDB: incoming.committedTrimDB,
            applicableCheckpoints: identity.applicableCheckpoints,
            earliestEligibleFutureSample: upper
        )
    }

    private func realBinding(
        context: LiveFeedbackAnalysisContext
    ) -> PendingLiveMasterHeadroomBinding? {
        guard let frameCount = LiveOutputWindowAnalyzer.frameCount(
            sampleRate: context.sourceRange.sampleRate
        ) else { return nil }
        var signal = [Float](repeating: 0, count: frameCount)
        for index in signal.indices {
            signal[index] = 0.18 * Float(sin(
                2 * Double.pi * 220 * Double(index) /
                    context.sourceRange.sampleRate
            ))
        }
        let packetCount = (frameCount + 1_023) / 1_024
        let capture = LiveOutputCaptureProvenance(
            packetCount: packetCount,
            firstPacketSequence: 500,
            lastPacketSequence: 500 + UInt64(packetCount - 1),
            droppedPacketDelta: 0,
            rejectedPacketDelta: 0,
            queueCapacity: LiveOutputCaptureProvenance.requiredQueueCapacity,
            maximumPacketFrameCount:
                LiveOutputCaptureProvenance.requiredMaximumPacketFrameCount,
            queueStorageByteCount:
                LiveOutputCaptureProvenance.requiredQueueStorageByteCount,
            consumerScratchByteCount:
                LiveOutputCaptureProvenance.requiredConsumerScratchByteCount,
            activeWindowByteCount:
                frameCount * 2 * MemoryLayout<Float>.stride,
            workingMemoryByteCount:
                LiveOutputCaptureProvenance.requiredQueueStorageByteCount +
                LiveOutputCaptureProvenance.requiredConsumerScratchByteCount +
                frameCount * 2 * MemoryLayout<Float>.stride,
            coveredFrameCount: frameCount,
            sampleDiscontinuityCount: 0,
            gapFrameCount: 0,
            overlapFrameCount: 0
        )
        let evidenceStart = context.sourceRange.playerSampleRange.lowerBound
        let evidenceRange = evidenceStart..<(evidenceStart + Int64(frameCount))
        guard let evidence = LiveOutputWindowAnalyzer.analyze(
            left: signal,
            right: signal,
            planIdentity: context.sourceIdentity,
            routeGeneration: context.sourceRange.routeGeneration,
            controllerRevision: context.sourceRange.controllerRevision,
            playerSampleRange: evidenceRange,
            sampleRate: context.sourceRange.sampleRate,
            captureProvenance: capture,
            qualityPolicyVersion: context.qualityPolicyVersion
        ), let checkpoint = evidence.applicableCheckpoints.first else {
            return nil
        }
        let loudnessLower = evidence.maximumShortTermLoudnessLUFS - 2
        let loudnessUpper = evidence.maximumShortTermLoudnessLUFS + 1
        let truePeakLower = evidence.truePeakDBTP - 2
        let truePeakUpper = evidence.truePeakDBTP + 1
        let target = LiveMasterHeadroomTarget(
            schemaVersion: LiveMasterHeadroomTarget.schemaVersion,
            sourceObservationFingerprint: evidence.fingerprint,
            phraseIndex: evidence.phraseIndex,
            planFingerprint: evidence.planFingerprint,
            routeGeneration: evidence.routeGeneration,
            controllerRevision: evidence.controllerRevision,
            playerSampleRange: evidence.playerSampleRange,
            sampleRate: evidence.sampleRate,
            applicableCheckpoints: evidence.applicableCheckpoints,
            selectedLoudnessCheckpoint: checkpoint,
            selectedTruePeakCheckpoint: checkpoint,
            analyzerVersion: evidence.analyzerVersion,
            engineVersion: evidence.engineVersion,
            evidenceVersion: evidence.evidenceVersion,
            qualityPolicyVersion: evidence.qualityPolicyVersion,
            evaluatorVersion: evidence.evaluatorVersion,
            controllerPolicyVersion: evidence.controllerPolicyVersion,
            profileVersion:
                ProfessionalQualityPrimaryEvaluator.requiredProfileVersion,
            profileFingerprint: "1111111111111111",
            loudnessLowerLUFS: loudnessLower,
            loudnessUpperLUFS: loudnessUpper,
            loudnessMidpointLUFS: (loudnessLower + loudnessUpper) / 2,
            truePeakLowerDBTP: truePeakLower,
            truePeakUpperDBTP: truePeakUpper,
            truePeakMidpointDBTP: (truePeakLower + truePeakUpper) / 2
        )
        guard target.isStructurallyValid(sourceEvidence: evidence) else {
            return nil
        }
        let proposal = LiveMasterHeadroomController.propose(
            evidence: evidence,
            target: target,
            incoming: context.incomingState,
            earliestEligibleFutureSample:
                context.earliestEligibleFutureSample
        )
        guard proposal.outcome != .unavailable else { return nil }
        let eligibleTarget = LiveMasterHeadroomEligibleTarget(
            plan: context.targetPlan,
            routeGeneration: context.sourceRange.routeGeneration,
            sampleRate: context.sourceRange.sampleRate,
            earliestEligibleFutureSample:
                context.earliestEligibleFutureSample,
            qualityPolicyVersion: evidence.qualityPolicyVersion,
            evaluatorVersion: evidence.evaluatorVersion,
            controllerPolicyVersion: evidence.controllerPolicyVersion
        )
        let binding = PendingLiveMasterHeadroomBinding(
            sourceIdentity: context.sourceIdentity,
            evidence: evidence,
            target: target,
            proposal: proposal,
            eligibleTarget: eligibleTarget
        )
        return binding.isStructurallyValid(
            targetPlan: context.targetPlan,
            incoming: context.incomingState
        ) ? binding : nil
    }
}
