import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Live feedback primary commit", .serialized)
struct LiveFeedbackPrimaryCommitTests {
    private struct RejectingPrimaryEvaluator: AutonomousCandidateEvaluating {
        let policyVersion = "test-primary-calibrated.v1"
        let evaluatorVersion = "test-primary-rejecting-live.v1"

        func requestsHomeUpperTimbreCorrection(
            for candidate: AutonomousCandidateEvaluationVector
        ) -> Bool { false }

        func terminalVerdict(
            selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction
        ) -> AutonomousCandidatePolicyVerdict {
            AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                reasonCodes: [.guardrailRegressionV1]
            )
        }
    }

    private struct Fixture {
        let sourceState: AutonomousSessionState
        let sourcePlan: AutonomousPhrasePlan
        let targetState: AutonomousSessionState
        let targetPlan: AutonomousPhrasePlan
        let incomingRenderState: RenderState
        let sampleRate: Double
        let liveTargetStartSample: Int64
        let binding: PendingLiveMasterHeadroomBinding
    }

    @Test("Pending proposal remains detached from incoming committed state")
    func pendingProposalDoesNotMutateIncomingState() {
        let fixture = makeFixture()
        let before = fixture.targetState
        let incomingRenderState = fixture.incomingRenderState

        let prepared = prepare(
            fixture,
            binding: fixture.binding,
            evaluator: AcceptingPrimaryTestEvaluator()
        )

        #expect(prepared != nil)
        #expect(fixture.targetState == before)
        #expect(incomingRenderState.liveMasterHeadroomState ==
                before.liveMasterHeadroom)
        #expect(before.liveMasterHeadroom.revision == 0)
    }

    @Test("Accepted primary candidate atomically commits quality and live state")
    func acceptedCandidateCommitsProposalAtomically() throws {
        let fixture = makeFixture()
        let prepared = try #require(prepare(
            fixture,
            binding: fixture.binding,
            evaluator: AcceptingPrimaryTestEvaluator()
        ))
        let expectedLive = fixture.targetState.liveMasterHeadroom.accepting(
            fixture.binding.proposal
        )

        #expect(prepared.commitEligible)
        #expect(prepared.incomingLiveMasterHeadroomState ==
                fixture.targetState.liveMasterHeadroom)
        #expect(prepared.liveMasterHeadroomContinuationState == expectedLive)
        let committed = fixture.targetState.advance(
            using: prepared.plan,
            quality: prepared.qualityContinuationState,
            liveMasterHeadroom: prepared.liveMasterHeadroomContinuationState
        )
        #expect(committed.phraseIndex == prepared.plan.phraseIndex + 1)
        #expect(committed.quality == prepared.qualityContinuationState)
        #expect(committed.liveMasterHeadroom == expectedLive)
    }

    @Test("Rejected primary candidate leaves live continuation unchanged")
    func rejectedCandidateLeavesLiveContinuationUnchanged() throws {
        let fixture = makeFixture()
        let prepared = try #require(prepare(
            fixture,
            binding: fixture.binding,
            evaluator: RejectingPrimaryEvaluator()
        ))
        var committed = fixture.targetState
        if prepared.commitEligible {
            committed = committed.advance(
                using: prepared.plan,
                quality: prepared.qualityContinuationState,
                liveMasterHeadroom:
                    prepared.liveMasterHeadroomContinuationState
            )
        }

        #expect(prepared.qualityDecision.outcome == .rejected)
        #expect(!prepared.commitEligible)
        #expect(committed == fixture.targetState)
        #expect(committed.liveMasterHeadroom ==
                fixture.targetState.liveMasterHeadroom)
    }

    @Test("Proposal must match source, route, revision, controller, target, and future boundary")
    func proposalMustMatchRoutePlanRevisionAndBoundary() throws {
        let fixture = makeFixture()
        let attacks = [
            proposal(fixture, sourcePhraseIndex: fixture.targetPlan.phraseIndex),
            proposal(
                fixture,
                sourcePlanFingerprint:
                    AutonomousCandidateFingerprint.plan(fixture.targetPlan)
            ),
            proposal(fixture, routeGeneration: 8),
            proposal(fixture, incomingRevision: 1),
            proposal(
                fixture,
                incomingStateFingerprint: "3333333333333333"
            ),
            proposal(fixture, controllerPolicyVersion: "wrong-controller"),
            proposal(
                fixture,
                targetFingerprint:
                    LiveMasterHeadroomProposal.unavailableTargetFingerprint
            ),
            proposal(fixture, earliestEligibleFutureSample: 8_000),
        ]

        for attack in attacks {
            #expect(!attack.isStructurallyValid(
                targetPlan: fixture.targetPlan,
                incoming: fixture.targetState.liveMasterHeadroom
            ))
        }
        let prepared = prepare(
            fixture,
            binding: attacks[0],
            evaluator: AcceptingPrimaryTestEvaluator()
        )
        #expect(prepared == nil)
    }

    @Test("Pending binding rejects an unrelated but valid source identity")
    func unrelatedValidSourceIdentityCannotAuthorizeProposal() {
        let fixture = authoritativeBindingFixture()
        let otherDirector = AutonomousSessionDirector(rootSeed: 90_909)
        let unrelatedPlan = otherDirector.plan(from: otherDirector.initialState())
        let attack = PendingLiveMasterHeadroomBinding(
            sourceIdentity: LiveOutputPlanSourceIdentity(plan: unrelatedPlan),
            evidence: fixture.binding.evidence,
            target: fixture.binding.target,
            proposal: fixture.binding.proposal,
            eligibleTarget: fixture.binding.eligibleTarget
        )

        #expect(!attack.isStructurallyValid(
            targetPlan: fixture.targetPlan,
            incoming: fixture.targetState.liveMasterHeadroom
        ))
    }

    @Test("Pending binding rejects forged canonical-looking target and observation identities")
    func forgedValidTargetAndObservationCannotAuthorizeProposal() {
        let fixture = authoritativeBindingFixture()
        let proposal = fixture.binding.proposal
        let forged = LiveMasterHeadroomProposal(
            controllerPolicyVersion: proposal.controllerPolicyVersion,
            targetFingerprint: "3333333333333333",
            sourcePhraseIndex: proposal.sourcePhraseIndex,
            sourcePlanFingerprint: proposal.sourcePlanFingerprint,
            routeGeneration: proposal.routeGeneration,
            playerSampleRange: proposal.playerSampleRange,
            observationFingerprint: "4444444444444444",
            incomingRevision: proposal.incomingRevision,
            incomingStateFingerprint: proposal.incomingStateFingerprint,
            outcome: proposal.outcome,
            reasonCodes: proposal.reasonCodes,
            proposedTrimDB: proposal.proposedTrimDB,
            proposedCleanWindows: proposal.proposedCleanWindows,
            earliestEligibleFutureSample:
                proposal.earliestEligibleFutureSample
        )
        let attack = PendingLiveMasterHeadroomBinding(
            sourceIdentity: fixture.binding.sourceIdentity,
            evidence: fixture.binding.evidence,
            target: fixture.binding.target,
            proposal: forged,
            eligibleTarget: fixture.binding.eligibleTarget
        )

        #expect(!attack.isStructurallyValid(
            targetPlan: fixture.targetPlan,
            incoming: fixture.targetState.liveMasterHeadroom
        ))
    }

    @Test("Pending binding requires the exact App-authoritative future boundary")
    func wrongEligibleFutureBoundaryCannotAuthorizeProposal() {
        let fixture = authoritativeBindingFixture()
        let target = fixture.binding.eligibleTarget
        let attack = PendingLiveMasterHeadroomBinding(
            sourceIdentity: fixture.binding.sourceIdentity,
            evidence: fixture.binding.evidence,
            target: fixture.binding.target,
            proposal: fixture.binding.proposal,
            eligibleTarget: LiveMasterHeadroomEligibleTarget(
                plan: fixture.targetPlan,
                routeGeneration: target.routeGeneration,
                sampleRate: target.sampleRate,
                earliestEligibleFutureSample:
                    target.earliestEligibleFutureSample + 1,
                qualityPolicyVersion: target.qualityPolicyVersion,
                evaluatorVersion: target.evaluatorVersion,
                controllerPolicyVersion: target.controllerPolicyVersion
            )
        )

        #expect(!attack.isStructurallyValid(
            targetPlan: fixture.targetPlan,
            incoming: fixture.targetState.liveMasterHeadroom
        ))
    }

    @Test("One primary correction cannot rewrite the live proposal")
    func onePrimaryCorrectionCannotRewriteLiveProposal() throws {
        let fixture = makeFixture()
        let prepared = try #require(prepare(
            fixture,
            binding: fixture.binding,
            evaluator: CorrectingPrimaryTestEvaluator()
        ))
        let attempts = prepared.candidateEvaluation.attempts

        #expect(attempts.count == 2)
        #expect(attempts[0].vector.liveProposalFingerprint ==
                fixture.binding.proposal.fingerprint)
        #expect(attempts[1].vector.liveProposalFingerprint ==
                fixture.binding.proposal.fingerprint)
        #expect(attempts[0].vector.liveObservationFingerprint ==
                attempts[1].vector.liveObservationFingerprint)
        #expect(attempts[0].vector.requestedLiveMasterTrimDB ==
                attempts[1].vector.requestedLiveMasterTrimDB)
        #expect(attempts[0].vector.outgoingLiveMasterStateFingerprint ==
                attempts[1].vector.outgoingLiveMasterStateFingerprint)
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.commitEligible)
    }

    private func makeFixture() -> Fixture {
        let sampleRate = 44_100.0
        let routeGeneration = 7
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let sourceState = director.initialState()
        let sourcePlan = director.plan(from: sourceState)
        let targetState = sourceState.advance(
            using: sourcePlan,
            quality: sourceState.quality,
            liveMasterHeadroom: sourceState.liveMasterHeadroom
        )
        let targetPlan = director.plan(from: targetState)
        var incomingRenderState = RenderState()
        incomingRenderState.barIndex = targetPlan.startBar
        incomingRenderState.liveMasterHeadroomState =
            targetState.liveMasterHeadroom
        let frameCount = try! #require(LiveOutputWindowAnalyzer.frameCount(
            sampleRate: sampleRate
        ))
        let signal = (0..<frameCount).map { frame in
            Float(0.2 * sin(
                2 * Double.pi * 997 * Double(frame) / sampleRate
            ))
        }
        let evidence = try! #require(LiveOutputWindowAnalyzer.analyze(
            left: signal,
            right: signal,
            planIdentity: LiveOutputPlanSourceIdentity(plan: sourcePlan),
            routeGeneration: routeGeneration,
            controllerRevision: targetState.liveMasterHeadroom.revision,
            playerSampleRange: 0..<Int64(frameCount),
            sampleRate: sampleRate,
            captureProvenance: captureProvenance(frameCount: frameCount),
            qualityPolicyVersion:
                LiveFeedbackTestSupport.fingerprintQualifiedPolicyVersion
        ))
        let loudnessUpper = evidence.maximumShortTermLoudnessLUFS - 0.8
        let loudnessLower = loudnessUpper - 2
        let truePeakUpper = evidence.truePeakDBTP - 0.8
        let truePeakLower = truePeakUpper - 2
        let checkpoint = evidence.applicableCheckpoints[0]
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
            profileFingerprint: LiveFeedbackTestSupport.profileFingerprint,
            loudnessLowerLUFS: loudnessLower,
            loudnessUpperLUFS: loudnessUpper,
            loudnessMidpointLUFS: (loudnessLower + loudnessUpper) / 2,
            truePeakLowerDBTP: truePeakLower,
            truePeakUpperDBTP: truePeakUpper,
            truePeakMidpointDBTP: (truePeakLower + truePeakUpper) / 2
        )
        let futureBoundary = Int64(frameCount) + 10_000
        let proposal = LiveMasterHeadroomController.propose(
            evidence: evidence,
            target: target,
            incoming: targetState.liveMasterHeadroom,
            earliestEligibleFutureSample: futureBoundary
        )
        let binding = PendingLiveMasterHeadroomBinding(
            sourceIdentity: LiveOutputPlanSourceIdentity(plan: sourcePlan),
            evidence: evidence,
            target: target,
            proposal: proposal,
            eligibleTarget: LiveMasterHeadroomEligibleTarget(
                plan: targetPlan,
                routeGeneration: routeGeneration,
                sampleRate: sampleRate,
                earliestEligibleFutureSample: futureBoundary,
                qualityPolicyVersion: evidence.qualityPolicyVersion,
                evaluatorVersion: evidence.evaluatorVersion,
                controllerPolicyVersion: evidence.controllerPolicyVersion
            )
        )
        let fixture = Fixture(
            sourceState: sourceState,
            sourcePlan: sourcePlan,
            targetState: targetState,
            targetPlan: targetPlan,
            incomingRenderState: incomingRenderState,
            sampleRate: sampleRate,
            liveTargetStartSample: futureBoundary,
            binding: binding
        )
        return fixture
    }

    private func authoritativeBindingFixture() -> Fixture {
        makeFixture()
    }

    private func captureProvenance(
        frameCount: Int
    ) -> LiveOutputCaptureProvenance {
        let packetCount = (
            frameCount +
                LiveOutputCaptureProvenance.requiredMaximumPacketFrameCount - 1
        ) / LiveOutputCaptureProvenance.requiredMaximumPacketFrameCount
        return LiveOutputCaptureProvenance(
            packetCount: packetCount,
            firstPacketSequence: 10,
            lastPacketSequence: 10 + UInt64(packetCount - 1),
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
    }

    private func proposal(
        _ fixture: Fixture,
        controllerPolicyVersion: String =
            LiveFeedbackContract.controllerPolicyVersion,
        targetFingerprint: String? = nil,
        sourcePhraseIndex: Int? = nil,
        sourcePlanFingerprint: String? = nil,
        routeGeneration: Int? = nil,
        incomingRevision: Int? = nil,
        incomingStateFingerprint: String? = nil,
        observationFingerprint: String? = nil,
        earliestEligibleFutureSample: Int64? = nil
    ) -> PendingLiveMasterHeadroomBinding {
        let source = fixture.binding.proposal
        let proposal = LiveMasterHeadroomProposal(
            controllerPolicyVersion: controllerPolicyVersion,
            targetFingerprint: targetFingerprint ?? source.targetFingerprint,
            sourcePhraseIndex: sourcePhraseIndex ??
                fixture.sourcePlan.phraseIndex,
            sourcePlanFingerprint: sourcePlanFingerprint ??
                AutonomousCandidateFingerprint.plan(fixture.sourcePlan),
            routeGeneration: routeGeneration ?? source.routeGeneration,
            playerSampleRange: source.playerSampleRange,
            observationFingerprint: observationFingerprint ??
                source.observationFingerprint,
            incomingRevision: incomingRevision ??
                fixture.targetState.liveMasterHeadroom.revision,
            incomingStateFingerprint: incomingStateFingerprint ??
                fixture.targetState.liveMasterHeadroom.fingerprint,
            outcome: .attenuate,
            reasonCodes: [.windowAccepted],
            proposedTrimDB: -0.25,
            proposedCleanWindows: 0,
            earliestEligibleFutureSample: earliestEligibleFutureSample ??
                source.earliestEligibleFutureSample
        )
        return PendingLiveMasterHeadroomBinding(
            sourceIdentity: fixture.binding.sourceIdentity,
            evidence: fixture.binding.evidence,
            target: fixture.binding.target,
            proposal: proposal,
            eligibleTarget: fixture.binding.eligibleTarget
        )
    }

    private func prepare<E: AutonomousCandidateEvaluating>(
        _ fixture: Fixture,
        binding: PendingLiveMasterHeadroomBinding?,
        evaluator: E
    ) -> PreparedAutonomousPhrase? {
        AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: fixture.targetPlan,
            sessionSeed: fixture.targetState.rootSeed,
            memory: fixture.targetState.memory,
            sampleRate: fixture.sampleRate,
            incomingRenderState: fixture.incomingRenderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: fixture.targetState.quality,
            routeGeneration: fixture.binding.eligibleTarget.routeGeneration,
            pendingLiveMasterBinding: binding,
            liveTargetStartSample: binding == nil ? nil :
                fixture.liveTargetStartSample,
            evaluator: evaluator,
            cancellationRequested: { false }
        )
    }
}

@Suite("Adaptive autonomous session")
struct AdaptiveAutonomousSessionTests {
    @Test("Accepted phrase commits quality and live state atomically")
    func sessionAdvanceCommitsLiveStateAtomicallyWithQuality() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let incoming = director.initialState()
        let plan = director.plan(from: incoming)
        let acceptedQuality = QualityContinuationState(revision: 7)
        let proposal = LiveMasterHeadroomProposal(
            controllerPolicyVersion: LiveFeedbackContract.controllerPolicyVersion,
            targetFingerprint: "target",
            sourcePhraseIndex: incoming.phraseIndex,
            sourcePlanFingerprint: "plan",
            routeGeneration: 1,
            playerSampleRange: 0..<132_300,
            observationFingerprint: "observation",
            incomingRevision: incoming.liveMasterHeadroom.revision,
            incomingStateFingerprint: incoming.liveMasterHeadroom.fingerprint,
            outcome: .attenuate,
            reasonCodes: [.windowAccepted],
            proposedTrimDB: -0.25,
            proposedCleanWindows: 0,
            earliestEligibleFutureSample: 192_000
        )
        let acceptedLive = incoming.liveMasterHeadroom.accepting(proposal)

        let advanced = incoming.advance(
            using: plan,
            quality: acceptedQuality,
            liveMasterHeadroom: acceptedLive
        )
        let replay = incoming.advance(
            using: plan,
            quality: acceptedQuality,
            liveMasterHeadroom: acceptedLive
        )

        #expect(incoming.phraseIndex == 0)
        #expect(incoming.quality.revision == 0)
        #expect(incoming.liveMasterHeadroom == LiveMasterHeadroomContinuationState())
        #expect(advanced.phraseIndex == plan.phraseIndex + 1)
        #expect(advanced.quality == acceptedQuality)
        #expect(advanced.liveMasterHeadroom == acceptedLive)
        #expect(advanced == replay)
    }

    @Test("Invalid live-state jump holds the whole session atomically")
    func invalidLiveJumpHoldsWholeSessionAtomically() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let incoming = director.initialState()
        let plan = director.plan(from: incoming)
        let invalidJump = LiveMasterHeadroomContinuationState(
            revision: 3,
            committedTrimDB: -0.75,
            consecutiveCleanWindows: 0,
            lastProposalFingerprint: "proposal",
            lastObservationFingerprint: "observation",
            lastAcceptedSourcePhraseIndex: incoming.phraseIndex,
            earliestEligibleFutureSample: 192_000
        )

        let rejected = incoming.advance(
            using: plan,
            quality: QualityContinuationState(revision: 7),
            liveMasterHeadroom: invalidJump
        )

        #expect(rejected == incoming)
        #expect(rejected.memory == incoming.memory)
        #expect(rejected.quality == incoming.quality)
        #expect(rejected.liveMasterHeadroom == incoming.liveMasterHeadroom)
    }

    @Test("Maximum live revision holds the whole session atomically")
    func maximumLiveRevisionHoldsWholeSessionAtomically() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let base = director.initialState()
        let maximumLive = LiveMasterHeadroomContinuationState(
            revision: .max,
            committedTrimDB: -0.5,
            consecutiveCleanWindows: 0,
            lastProposalFingerprint: "previous-proposal",
            lastObservationFingerprint: "previous-observation",
            lastAcceptedSourcePhraseIndex: 4,
            earliestEligibleFutureSample: 1_500
        )
        let incoming = AutonomousSessionState(
            rootSeed: base.rootSeed,
            phraseIndex: base.phraseIndex,
            intent: base.intent,
            memory: base.memory,
            quality: base.quality,
            liveMasterHeadroom: maximumLive
        )
        let plan = director.plan(from: incoming)
        let forgedSuccessor = LiveMasterHeadroomContinuationState(
            revision: .max,
            committedTrimDB: -0.75,
            consecutiveCleanWindows: 0,
            lastProposalFingerprint: "next-proposal",
            lastObservationFingerprint: "next-observation",
            lastAcceptedSourcePhraseIndex: 5,
            earliestEligibleFutureSample: 2_000
        )

        let rejected = incoming.advance(
            using: plan,
            quality: QualityContinuationState(revision: 1),
            liveMasterHeadroom: forgedSuccessor
        )

        #expect(rejected == incoming)
    }

    @Test("Fixed seeds replay the same variable phrases and bounded memories",
          arguments: [UInt64(42), 48_291, 90_909, 7, 77_777])
    func deterministicSession(seed: UInt64) {
        let first = sequence(seed: seed, phraseCount: 80)
        let second = sequence(seed: seed, phraseCount: 80)
        #expect(first.plans == second.plans)
        #expect(first.state == second.state)
        #expect(first.plans.allSatisfy { (4...16).contains($0.barCount) })
        #expect(first.plans.allSatisfy { $0.scene.bpm == 130 })
        #expect(first.plans.allSatisfy { $0.dna == first.state.identityDNA })
        #expect(first.state.memory.recentBars.count == 4)
        #expect(first.state.memory.currentPhrase.count <= 16)
        #expect(first.state.memory.previousPhrase.count <= 16)
        #expect(first.state.memory.dramaticArc.count <= 128)
        #expect(first.state.memory.sessionBars.count == 256)
        #expect(first.plans.contains { $0.kind == .contrast })
        #expect(first.plans.contains { $0.kind == .majorBreak })
        #expect(first.plans.contains { $0.kind == .energyRelease })
    }

    @Test("Structural phrases resolve on the macro grid and coordinated gears stay bounded",
          arguments: [UInt64(42), 48_291, 90_909])
    func macroGrammarAndTopologyRestraint(seed: UInt64) {
        let result = sequence(seed: seed, phraseCount: 100)
        for plan in result.plans {
            let structural = plan.kind == .majorBreak || plan.kind == .energyRelease ||
                plan.kind == .identityReturn
            if structural {
                #expect(plan.resolvedBars.contains {
                    $0.arrangementGesture == .structuralMarker &&
                        ($0.performance.bar + 1).isMultiple(of: 16) &&
                        $0.performance.signatureEvent != nil
                })
            }
            let expectedPercussionRelationship = structural
                ? plan.longHorizonEnergyCoordination.target.percussionActivity
                : plan.materialWorld.resolvedAxes.rhythmRelationship
            #expect(plan.resolvedBars.allSatisfy { resolved in
                resolved.percussionGear == coordinatedPercussionGear(
                    absoluteBar: resolved.performance.bar,
                    relationship: expectedPercussionRelationship
                )
            })
            #expect(!plan.requestsTopologyMutation ||
                    (plan.kind == .contrast || plan.kind == .majorBreak))
        }
    }

    @Test("Performance characters remain coherent and all authored behaviors are reachable")
    func performanceCharacterConductor() {
        var observed = Set<PerformanceCharacter>()
        for rawSeed in 1...24 {
            let result = sequence(seed: UInt64(rawSeed), phraseCount: 32)
            #expect(result.state.memory.recentPerformanceCharacters.count <= 2)
            for plan in result.plans {
                let character = plan.performanceCharacterEvidence.character
                observed.insert(character)
                #expect(plan.performanceCharacterEvidence.valid)
                #expect(plan.performanceCharacterEvidence.totalBars == plan.barCount)
                #expect(plan.resolvedBars.allSatisfy {
                    $0.performanceCharacter == character &&
                        PerformanceCharacterContract.foundationIsCompatible(
                            $0.foundationBehavior,
                            with: character
                        ) &&
                        $0.foundationCompanion == $0.foundationBehavior.companion &&
                        PerformanceCharacterContract.rolesAreCompatible(
                            $0.performance.roles,
                            with: character
                        ) &&
                        ($0.kickSyntaxRole == .withheld
                            ? $0.ensemble.kickAnchors.isEmpty &&
                                !$0.ensemble.events.contains { $0.voice == .kick }
                            : PerformanceCharacterContract.rhythmIsCompatible(
                                $0.ensemble,
                                with: character
                            ))
                })

                let synth = SynthPerformancePlan(
                    scene: plan.scene,
                    dna: plan.dna,
                    kind: plan.kind,
                    resolvedBars: plan.resolvedBars
                )
                for (resolved, synthBar) in zip(plan.resolvedBars, synth.bars) {
                    if resolved.foundationRhythmicRelation ==
                            .dottedThreeSixteenth {
                        #expect(resolved.foundationBehavior == .monotone)
                        #expect(synthBar.foundationInstrument.patch == .bassPluck)
                    } else {
                        switch resolved.foundationBehavior {
                        case .point:
                            #expect(synthBar.foundationInstrument.patch == .bassPluck)
                        case .subPulse, .monotone, .pump:
                            #expect(synthBar.foundationInstrument.patch == .bassPulse)
                        case .kickTail, .tunedPercussive, .absent:
                            #expect(!resolved.ensemble.events.contains {
                                $0.voice == .bass
                            })
                        }
                    }
                    if character == .acidPressure {
                        #expect(synthBar.upperNotes.filter {
                            $0.role == .anchor || $0.role == .response
                        }.allSatisfy {
                            $0.instrument.patch == .acidSequence
                        })
                    }
                    if character == .ambientDrift {
                        #expect(!resolved.performance.roles.contains(.percussion))
                        #expect(synthBar.upperNotes.filter {
                            $0.role == .atmosphere || $0.role == .transition
                        }.allSatisfy {
                            $0.instrument.patch == .dustCloud
                        })
                    }
                }
            }
        }
        #expect(observed == Set(PerformanceCharacter.allCases))
    }

    @Test("Character evidence rejects an incompatible foundation and rhythm")
    func performanceCharacterEvidenceRejectsTampering() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var source: ResolvedPerformanceBar?
        for _ in 0..<24 {
            let plan = director.plan(from: state)
            if plan.performanceCharacterEvidence.character == .peakDrive {
                source = plan.resolvedBars.first
                break
            }
            state.advancePlanning(using: plan)
        }
        guard let source else {
            Issue.record("Expected a reachable Peak Drive phrase")
            return
        }
        let tampered = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: .peakDrive,
            foundationBehavior: .absent,
            foundationCompanion: .empty,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations: source.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative
        )
        let evidence = PerformanceCharacterEvidence(
            resolvedBars: [tampered],
            kind: .lock,
            paidDebtIDs: []
        )
        #expect(!evidence.valid)
        #expect(evidence.compatibleFoundationBars == 0)
    }

    @Test("Weak-sixteenth classes and macro reveal use the authored hierarchy")
    func weakSixteenthVocabularyAndPatterns() {
        #expect((0..<4).map(SixteenthPulseClass.init(step:)) == [
            .downbeat, .leadingWeak, .upbeat, .trailingWeak,
        ])
        #expect((0..<16).map(WeakSixteenthStage.init(absoluteBar:)) ==
                Array(repeating: .skeleton, count: 4) +
                Array(repeating: .contour, count: 4) +
                Array(repeating: .syncopatedLean, count: 4) +
                Array(repeating: .pullback, count: 4))

        let contour = GroovePulseResolver.pattern(
            stage: .contour, gesture: .steady, macroEnding: false
        )
        #expect(contour.map(\.0) == [1, 3, 5, 7, 9, 11, 13, 15])
        #expect(contour.map(\.1) == [0.38, 0.52, 0.38, 0.52, 0.38, 0.52, 0.38, 0.52])
        let lean = GroovePulseResolver.pattern(
            stage: .syncopatedLean, gesture: .steady, macroEnding: false
        )
        #expect(lean.map(\.0) == contour.map(\.0))
        #expect(lean.map(\.1) == [0.30, 0.72, 0.30, 0.30, 0.72, 0.30, 0.30, 0.72])
        let leanReplay = GroovePulseResolver.pattern(
            stage: .syncopatedLean, gesture: .steady, macroEnding: false
        )
        #expect(leanReplay.map(\.0) == lean.map(\.0))
        #expect(leanReplay.map(\.1) == lean.map(\.1))
        let accentIndices = lean.indices.filter { lean[$0].1 == 0.72 }
        #expect(accentIndices == [1, 4, 7])
        guard let firstAccent = accentIndices.first else {
            Issue.record("Expected the bounded 3-3-2 accent cycle")
            return
        }
        let followingAccents = Array(accentIndices.dropFirst()) + [firstAccent + lean.count]
        #expect(zip(accentIndices, followingAccents).map { pair in
            pair.1 - pair.0
        } == [3, 3, 2])

        let fullResolved = EnsembleContext(
            focusRole: .percussion,
            events: lean.map { step, intensity in
                EnsembleResolvedEvent(
                    voice: .groovePulse,
                    step: step,
                    intensity: intensity,
                    relocated: false
                )
            },
            kickAnchors: [],
            intentionalPileup: false
        )
        let groupedResolved = GroovePulseResolver.resolvingAccentGrouping(
            in: fullResolved,
            absoluteBar: 8,
            gesture: .steady,
            majorBreak: false
        )
        #expect(groupedResolved.events.map(\.intensity) == lean.map(\.1))
        let collisionProposals = [
            EnsembleEventProposal(
                voice: .percussion, requestedStep: 7,
                priority: 70, intensity: 0.5
            ),
            EnsembleEventProposal(
                voice: .clap, requestedStep: 7,
                priority: 69, intensity: 0.5
            ),
            EnsembleEventProposal(
                voice: .openHat, requestedStep: 7,
                priority: 68, intensity: 0.5
            ),
        ]
        let partialResolved = EnsembleArbiter.resolve(
            proposals: collisionProposals + GroovePulseResolver.proposals(
                absoluteBar: 8,
                percussionActive: true,
                majorBreak: false,
                gesture: .steady
            ),
            focusRole: .percussion,
            intentionalPileup: false
        )
        #expect(partialResolved.events.filter {
            $0.voice == .groovePulse
        }.map(\.step) == [1, 3, 5, 9, 11, 13, 15])
        let partialGrouping = GroovePulseResolver.resolvingAccentGrouping(
            in: partialResolved,
            absoluteBar: 8,
            gesture: .steady,
            majorBreak: false
        )
        let partialGroove = partialGrouping.events.filter {
            $0.voice == .groovePulse
        }
        #expect(partialGroove.map(\.step) == [1, 3, 5, 9, 11, 13, 15])
        #expect(partialGroove.map(\.intensity) == [
            0.30, 0.72, 0.30, 0.72, 0.30, 0.30, 0.72,
        ])
        let minimal = GroovePulseResolver.pattern(
            stage: .syncopatedLean, gesture: .minimalize, macroEnding: false
        )
        #expect(minimal.map(\.0) == [7, 15])
        #expect(minimal.map(\.1) == [0.42, 0.42])
        let pullback = GroovePulseResolver.pattern(
            stage: .pullback, gesture: .turnaround, macroEnding: true
        )
        #expect(pullback.map(\.0) == [3, 7, 11, 15])
        #expect(pullback.map(\.1) == [0.50, 0.50, 0.50, 0.72])
        #expect(GroovePulseResolver.pattern(
            stage: .pullback, gesture: .structuralMarker,
            macroEnding: true, majorBreak: true
        ).isEmpty)
        #expect(QualityQualificationContract.engineVersion ==
                "autotechno-canonical-engine.v41")
    }

    @Test("Weak-sixteenth reveal follows the macro grid across phrase boundaries and breaks")
    func weakSixteenthMacroContinuity() {
        let result = sequence(seed: AutonomousSessionDirector.defaultSeed, phraseCount: 100)
        let plans = result.plans
        let firstMacro = plans.flatMap(\.resolvedBars)
            .filter { $0.performance.bar < 16 }
            .sorted { $0.performance.bar < $1.performance.bar }
        #expect(firstMacro.count == 16)
        for resolved in firstMacro {
            let expected = GroovePulseResolver.pattern(
                stage: WeakSixteenthStage(absoluteBar: resolved.performance.bar),
                gesture: resolved.arrangementGesture,
                macroEnding: (resolved.performance.bar + 1).isMultiple(of: 16)
            )
            let expectedByStep = Dictionary(uniqueKeysWithValues: expected)
            #expect(resolved.groovePulses.allSatisfy {
                expectedByStep[$0.step] == $0.intensity
            })
            #expect(resolved.groovePulses.allSatisfy {
                $0.stage == WeakSixteenthStage(absoluteBar: resolved.performance.bar) &&
                    ($0.pulseClass == .leadingWeak || $0.pulseClass == .trailingWeak) &&
                    $0.timingOffsetInSteps <= 0.12 &&
                    [-0.04, -0.02, 0, 0.02, 0.04].contains($0.timbreMicrovariation)
            })
            let expectedPhysical: (GroovePulseStrikeZone, Double)
            switch resolved.percussionGear {
            case .anchor: expectedPhysical = (.middle, 0.5)
            case .lift: expectedPhysical = (.middle, 0.4)
            case .contrast: expectedPhysical = (.edge, 0.25)
            case .turnaround: expectedPhysical = (.center, 0.75)
            }
            #expect(resolved.groovePulses.allSatisfy {
                $0.strikeZone == expectedPhysical.0 && $0.damping == expectedPhysical.1
            })
            let resolvedEvents = resolved.ensemble.events
                .filter { $0.voice == .groovePulse }
            #expect(resolvedEvents.map(\.step) == resolved.groovePulses.map(\.step))
            #expect(resolvedEvents.map(\.intensity) == resolved.groovePulses.map(\.intensity))
        }
        #expect(firstMacro[0...3].allSatisfy { $0.groovePulses.isEmpty })
        let completeLeanBars = firstMacro.filter {
            WeakSixteenthStage(absoluteBar: $0.performance.bar) == .syncopatedLean &&
                $0.arrangementGesture != .minimalize
        }
        #expect(completeLeanBars.count == 3)
        #expect(completeLeanBars.allSatisfy {
            !$0.groovePulses.isEmpty &&
                $0.groovePulses.allSatisfy {
                    [1, 3, 5, 7, 9, 11, 13, 15].contains($0.step)
                }
        })
        #expect(firstMacro[16 - 1].groovePulses.last?.intensity == 0.72)

        let midMacroBoundary = zip(plans, plans.dropFirst()).first { previous, next in
            previous.startBar + previous.barCount == next.startBar &&
                !next.startBar.isMultiple(of: 16)
        }
        guard let (_, next) = midMacroBoundary, let first = next.resolvedBars.first else {
            Issue.record("Expected an adaptive phrase boundary inside a macro")
            return
        }
        #expect(first.groovePulses.allSatisfy {
            $0.stage == WeakSixteenthStage(absoluteBar: first.performance.bar)
        })
        #expect(plans.filter { $0.kind == .majorBreak }.allSatisfy { plan in
            plan.resolvedBars.allSatisfy { $0.groovePulses.isEmpty }
        })
        #expect(plans.flatMap(\.resolvedBars).filter {
            !$0.performance.roles.contains(.percussion)
        }.allSatisfy { $0.groovePulses.isEmpty })
    }

    @Test("Closed-hat decay roles follow exact post-arbitration companions")
    func closedHatDecayRelationships() {
        let ensemble = EnsembleContext(
            focusRole: .percussion,
            events: [
                EnsembleResolvedEvent(
                    voice: .kick, step: 0, intensity: 1, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .percussion, step: 3, intensity: 0.48, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .openHat, step: 3, intensity: 0.42, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .percussion, step: 7, intensity: 0.48, relocated: true
                ),
                EnsembleResolvedEvent(
                    voice: .openHat, step: 7, intensity: 0.42, relocated: true
                ),
                EnsembleResolvedEvent(
                    voice: .percussion, step: 11, intensity: 0.48, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .percussion, step: 15, intensity: 0.48, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .percussion, step: 1, intensity: 0.48, relocated: false
                ),
            ],
            kickAnchors: [0],
            intentionalPileup: true
        )

        let authored = ClosedHatDecayResolver.articulations(from: ensemble)
        #expect(authored.count == 4)
        #expect(authored.map(\.scoreEventIndex) == [1, 3, 5, 6])
        #expect(authored.map(\.step) == [3, 7, 11, 15])
        #expect(authored.map(\.role) == [
            .openHatCompanion, .openHatCompanion, .neutral, .neutral,
        ])
        #expect(Set(authored.map(\.scoreEventIndex)).count == authored.count)

    }

    @Test("Director keys every closed-hat decay role to its surviving score event")
    func closedHatDecayDirectorIntegration() {
        let director = AutonomousSessionDirector()
        let candidates = director.plan(from: director.initialState())
        for plan in [candidates] {
            for resolved in plan.resolvedBars {
                let expected = Array(resolved.ensemble.events.enumerated().filter {
                    $0.element.voice == .percussion
                }.prefix(4))
                let articulations = resolved.closedHatDecayArticulations
                #expect(articulations.count == expected.count)
                #expect(articulations.map(\.scoreEventIndex) == expected.map(\.offset))
                #expect(articulations.map(\.step) == expected.map(\.element.step))
                #expect(Set(articulations.map(\.scoreEventIndex)).count == articulations.count)
                for articulation in articulations {
                    #expect(resolved.closedHatDecay(
                        atEventIndex: articulation.scoreEventIndex
                    ) == articulation)
                }
            }
        }
    }

    @Test("Ghost pulses contribute one fifth of an ordinary activity event")
    func groovePulseActivityWeight() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let plan = director.plan(from: state)
        guard let resolved = plan.resolvedBars.first(where: { !$0.groovePulses.isEmpty }) else {
            Issue.record("Expected a groove-pulse bar in the first phrase")
            return
        }
        let weightedEvents = resolved.ensemble.events.filter {
            $0.voice == .kick || $0.voice == .groovePulse
        }
        let weighted = ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: EnsembleContext(
                focusRole: resolved.ensemble.focusRole,
                events: weightedEvents,
                kickAnchors: resolved.ensemble.kickAnchors,
                intentionalPileup: resolved.ensemble.intentionalPileup
            ),
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
        let ordinaryEvents = weightedEvents.map { event in
            event.voice == .groovePulse
                ? EnsembleResolvedEvent(
                    voice: .percussion, step: event.step,
                    intensity: event.intensity, relocated: event.relocated
                )
                : event
        }
        let ordinary = ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: EnsembleContext(
                focusRole: resolved.ensemble.focusRole,
                events: ordinaryEvents,
                kickAnchors: resolved.ensemble.kickAnchors,
                intentionalPileup: resolved.ensemble.intentionalPileup
            ),
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative
        )
        let weightedReport = PhraseInterestEvaluator.evaluate(
            resolvedBars: [weighted], kind: plan.kind,
            memory: state.memory, identityPreserved: true
        )
        let ordinaryReport = PhraseInterestEvaluator.evaluate(
            resolvedBars: [ordinary], kind: plan.kind,
            memory: state.memory, identityPreserved: true
        )
        #expect(weightedReport.intentionalSpace > ordinaryReport.intentionalSpace)
        #expect(weightedReport.overactivityPenalty <= ordinaryReport.overactivityPenalty)
        let expectedWeakPositionCount = GroovePulseResolver.pattern(
            stage: WeakSixteenthStage(absoluteBar: resolved.performance.bar),
            gesture: resolved.arrangementGesture,
            macroEnding: (resolved.performance.bar + 1).isMultiple(of: 16)
        ).count
        #expect(expectedWeakPositionCount > 0)
        #expect(weightedReport.weakPositionCoverage ==
                Double(weighted.groovePulses.count) / Double(expectedWeakPositionCount))
        #expect(weightedReport.trailingSideRelationship == 1)
    }

    @Test("The three-step driver advances the five-stage follower and resets only on the macro grid")
    func relationalCyclePhases() {
        let phases = (0..<15).map(RelationalCyclePhase.init(macroStep:))
        #expect(phases.map(\.driverPhase) == [0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2])
        #expect(phases.map(\.followerStage) == [
            .anchor, .anchor, .anchor,
            .inhale, .inhale, .inhale,
            .open, .open, .open,
            .spill, .spill, .spill,
            .withdraw, .withdraw, .withdraw,
        ])
        #expect(RelationalCyclePhase(macroStep: 255).followerStage == .anchor)
        #expect(RelationalCyclePhase(macroStep: 256) == RelationalCyclePhase(macroStep: 0))
    }

    @Test("Relational chapters stay macro-bound, preserve onsets, and continue across phrases")
    func relationalChaptersFollowResolvedBars() {
        let result = sequence(seed: AutonomousSessionDirector.defaultSeed, phraseCount: 160)
        let bars = result.plans.flatMap(\.resolvedBars)
        let grouped = Dictionary(grouping: bars) { $0.performance.bar / 16 }
        var sawLiveBreathCascade = false
        #expect(grouped.values.allSatisfy { Set($0.map(\.interlockChapter)).count == 1 })
        #expect(bars.first?.interlockChapter == .home)
        #expect(Optional(result.state.memory.interlockEvolution) ==
                result.plans.last?.endingInterlockState)

        for plan in result.plans {
            let synth = SynthPerformancePlan(
                scene: plan.scene, dna: plan.dna, kind: plan.kind,
                resolvedBars: plan.resolvedBars
            )
            #expect(synth.bars.count == plan.resolvedBars.count)
            for (resolved, synthBar) in zip(plan.resolvedBars, synth.bars) {
                let motifSteps = resolved.ensemble.events
                    .filter { $0.voice == .motif }.map(\.step).sorted()
                let expectedShadowSteps = synthBar.gesture == .suspend ? [] : motifSteps
                #expect(synthBar.upperNotes(for: .shadow).map(\.onsetStep).sorted() ==
                        expectedShadowSteps)
                let expectedStart = RelationalCyclePhase(
                    macroStep: (resolved.performance.bar % 16) * 16
                )
                #expect(synthBar.articulation(at: 0).phase == expectedStart)
                let macroBar = ((resolved.performance.bar % 16) + 16) % 16
                if synthBar.upperTimingRelation == .harmonicCascade,
                   macroBar == 0 || macroBar == 15 {
                    #expect(synthBar.upperNotes.allSatisfy {
                        $0.timingOffsetInSteps == 0
                    })
                }
                if resolved.interlockChapter == .breath,
                   synthBar.upperNotes.contains(where: { $0.role == .anchor }),
                   synthBar.upperNotes.contains(where: {
                       $0.role == .shadow || $0.role == .response
                   }),
                   synthBar.upperNotes.contains(where: {
                       $0.timingOffsetInSteps > 0
                   }) {
                    sawLiveBreathCascade = true
                }
            }
        }
        #expect(sawLiveBreathCascade)

        let macroChapters = grouped.keys.sorted().compactMap {
            grouped[$0]?.first?.interlockChapter
        }
        var macrosWithoutHome = 0
        for (previous, current) in zip(macroChapters, macroChapters.dropFirst()) {
            if current == .home {
                macrosWithoutHome = 0
            } else {
                macrosWithoutHome += 1
                #expect(current != previous)
            }
            #expect(macrosWithoutHome <= 4)
        }
    }

    @Test("Tone chapters use exact raised-cosine complementary spectral sculpture")
    func toneChapterSpectralSculpture() {
        let followerScales = [1.00, 0.92, 1.06, 1.10, 0.88]
        for macroStep in 0..<256 {
            let phase = RelationalCyclePhase(macroStep: macroStep)
            let articulation = RelationalArticulation(
                chapter: .tone,
                phase: phase,
                pulseEchoEligible: false
            )
            let progress = Double(macroStep) / 255
            let sine = sin(.pi * progress)
            let expectedAperture = macroStep == 0 || macroStep == 255
                ? 0 : sine * sine
            let follower = followerScales[phase.followerStage.rawValue]
            let expectedAnchor = 1 + (follower - 1) * expectedAperture
            let expectedComplement = 1 - (follower - 1) * expectedAperture * 0.65
            #expect(abs(articulation.spectralAperture - expectedAperture) < 0.000_000_000_001)
            #expect(abs(articulation.anchorSpectralScale - expectedAnchor) <
                    0.000_000_000_001)
            #expect(abs(articulation.complementarySpectralScale - expectedComplement) <
                    0.000_000_000_001)
            #expect(abs(articulation.bandPassBlend - 0.15 * expectedAperture) <
                    0.000_000_000_001)
            #expect(articulation.bandPassBlend >= 0 && articulation.bandPassBlend <= 0.15)
        }

        for chapter in InterlockChapter.allCases where chapter != .tone {
            let neutral = RelationalArticulation(
                chapter: chapter,
                phase: RelationalCyclePhase(macroStep: 127),
                pulseEchoEligible: false
            )
            #expect(neutral.spectralAperture == 0)
            #expect(neutral.anchorSpectralScale == 1)
            #expect(neutral.complementarySpectralScale == 1)
            #expect(neutral.bandPassBlend == 0)
        }
        let explicitlyDisabled = RelationalArticulation(
            chapter: .tone,
            phase: RelationalCyclePhase(macroStep: 127),
            pulseEchoEligible: false,
            spectralSculptureEnabled: false
        )
        #expect(explicitlyDisabled.spectralAperture == 0)
        #expect(explicitlyDisabled.anchorSpectralScale == 1)
        #expect(explicitlyDisabled.complementarySpectralScale == 1)
        #expect(explicitlyDisabled.bandPassBlend == 0)

        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var sawIdentityTone = false
        var sawBreak = false
        for _ in 0..<80 where !(sawIdentityTone && sawBreak) {
            let plan = director.plan(from: state)
            if plan.kind == .identityReturn || plan.kind == .majorBreak {
                let synth = SynthPerformancePlan(
                    scene: plan.scene,
                    dna: plan.dna,
                    kind: plan.kind,
                    resolvedBars: plan.resolvedBars
                )
                #expect(synth.bars.flatMap(\.relationalSteps).allSatisfy {
                    $0.spectralAperture == 0 && $0.anchorSpectralScale == 1 &&
                        $0.complementarySpectralScale == 1 && $0.bandPassBlend == 0
                })
                if plan.kind == .identityReturn,
                   plan.resolvedBars.contains(where: { $0.interlockChapter == .tone }) {
                    sawIdentityTone = true
                }
                if plan.kind == .majorBreak { sawBreak = true }
            }
            state.advancePlanning(using: plan)
        }
        #expect(sawIdentityTone)
        #expect(sawBreak)
    }

    // This integration check intentionally renders several complete bars. Keep its
    // macro-expanded assertions off Swift Testing's bounded cooperative-worker stack.
    @MainActor
    @Test("Breath harmonics align, spread, and realign on the absolute macro grid")
    func upperHarmonicTimingApertureAndFallbacks() throws {
        try verifyUpperHarmonicTimingApertureAndFallbacks()
    }

    @inline(never)
    private func verifyUpperHarmonicTimingApertureAndFallbacks() throws {
        verifyUpperTimingApertureAndEligibility()

        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var sourcePlan: AutonomousPhrasePlan?
        var sourceBar: ResolvedPerformanceBar?
        for _ in 0..<24 where sourceBar == nil {
            let plan = director.plan(from: state)
            if let bar = plan.resolvedBars.first(where: {
                $0.ensemble.events.filter { $0.voice == .motif }.count >= 2
            }) {
                sourcePlan = plan
                sourceBar = bar
                break
            }
            state.advancePlanning(using: plan)
        }
        let plan = try #require(sourcePlan)
        let source = try #require(sourceBar)

        func replacing(absoluteBar: Int, phrase: Int = 3,
                       localBar: Int = 1,
                       chapter: InterlockChapter = .breath,
                       performanceCharacter: PerformanceCharacter? = nil)
            -> ResolvedPerformanceBar {
            let performance = PerformanceBar(
                bar: absoluteBar,
                phrase: phrase,
                localBar: localBar,
                phraseLength: max(8, source.performance.phraseLength),
                section: .build,
                tension: source.performance.tension,
                roles: source.performance.roles,
                transformations: source.performance.transformations,
                signatureEvent: nil,
                eventSeed: source.performance.eventSeed,
                accentContour: source.performance.accentContour
            )
            return ResolvedPerformanceBar(
                performance: performance,
                ensemble: source.ensemble,
                arrangementGesture: source.arrangementGesture,
                percussionGear: source.percussionGear,
                performanceCharacter: performanceCharacter,
                foundationBehavior: performanceCharacter == .melodicGlow
                    ? .subPulse : source.foundationBehavior,
                foundationCompanion: performanceCharacter == .melodicGlow
                    ? .bass : source.foundationCompanion,
                pulseEchoEnabled: source.pulseEchoEnabled,
                interlockChapter: chapter,
                groovePulses: source.groovePulses,
                closedHatDecayArticulations: source.closedHatDecayArticulations,
                upperPercussionTailArticulations:
                    source.upperPercussionTailArticulations,
                spatialContrast: source.spatialContrast,
                narrative: source.narrative
            )
        }

        func synthBar(_ resolved: ResolvedPerformanceBar,
                      kind: AutonomousPhraseKind = .lock,
                      forceHome: Bool = false) -> SynthPerformanceBar {
            SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: kind,
                resolvedBars: [resolved],
                forceHomeUpperTimbre: forceHome
            ).bars[0]
        }

        let spreadResolved = replacing(absoluteBar: 7)
        let spread = synthBar(spreadResolved)
        #expect(spread.upperNotes.contains { $0.role == .anchor })
        #expect(spread.upperNotes.contains { $0.role == .shadow })
        #expect(spread.upperNotes(for: .anchor).allSatisfy { $0.timingOffsetInSteps == 0 })
        #expect(spread.upperNotes(for: .shadow).allSatisfy {
            $0.timingOffsetInSteps == 0.06
        })
        #expect(spread.upperNotes(for: .response).allSatisfy {
            $0.timingOffsetInSteps == 0.12
        })
        #expect(spread.upperNotes(for: .atmosphere).allSatisfy {
            $0.timingOffsetInSteps == 0
        })
        #expect(spread.upperNotes(for: .transition).allSatisfy {
            $0.timingOffsetInSteps == 0
        })

        let sameAbsoluteBarAcrossPhraseBoundary = synthBar(replacing(
            absoluteBar: 7,
            phrase: 91,
            localBar: 6
        ))
        #expect(sameAbsoluteBarAcrossPhraseBoundary.upperNotes.map(\.timingOffsetInSteps) ==
                spread.upperNotes.map(\.timingOffsetInSteps))
        for endpoint in [0, 15, 16, 31] {
            #expect(synthBar(replacing(absoluteBar: endpoint)).upperNotes.allSatisfy {
                $0.timingOffsetInSteps == 0
            })
        }
        #expect(synthBar(replacing(absoluteBar: 7, chapter: .home))
            .upperNotes.allSatisfy { $0.timingOffsetInSteps == 0 })
        #expect(synthBar(replacing(absoluteBar: 7), forceHome: true)
            .upperNotes.allSatisfy { $0.timingOffsetInSteps == 0 })
        #expect(synthBar(replacing(absoluteBar: 7), kind: .identityReturn)
            .upperNotes.allSatisfy { $0.timingOffsetInSteps == 0 })
        #expect(synthBar(replacing(absoluteBar: 7), kind: .majorBreak)
            .upperNotes.allSatisfy { $0.timingOffsetInSteps == 0 })

        let performedResolved = replacing(
            absoluteBar: 7,
            chapter: .home,
            performanceCharacter: .melodicGlow
        )
        let performed = synthBar(performedResolved)
        let performedAnchors = performed.upperNotes(for: .anchor).sorted {
            $0.onsetStep < $1.onsetStep
        }
        #expect(performed.upperTimingRelation == .leadPerformance)
        #expect(performedAnchors.count >= 2)
        #expect(performedAnchors.enumerated().allSatisfy { index, note in
            note.timingOffsetInSteps ==
                SynthPerformancePlan.leadPerformanceOffsetInSteps(
                    performanceIndex: index
                )
        })
        #expect(performed.upperNotes.filter { $0.role != .anchor }.allSatisfy {
            $0.timingOffsetInSteps == 0
        })
        #expect(synthBar(performedResolved, forceHome: true)
            .upperTimingRelation == .aligned)

        let neutralNotes = spread.upperNotes.map { $0.withTimingOffsetInSteps(0) }
        let legacyNeutralNotes = neutralNotes.map { note in
            ResolvedUpperNote(
                role: note.role,
                onsetStep: note.onsetStep,
                durationInSteps: note.durationInSteps,
                startFrequencyRatio: note.startFrequencyRatio,
                endFrequencyRatio: note.endFrequencyRatio,
                velocity: note.velocity,
                gate: note.gate,
                timbreIntent: note.timbreIntent,
                spectralReveal: note.spectralReveal,
                instrument: note.instrument
            )
        }
        let neutralSynth = SynthPerformanceBar(
            bar: spread.bar,
            gesture: spread.gesture,
            mutationAmount: spread.mutationAmount,
            foundationInstrument: spread.foundationInstrument,
            relationalSteps: spread.relationalSteps,
            upperNotes: neutralNotes,
            pulseEchoTextureArticulation: spread.pulseEchoTextureArticulation
        )
        let legacyNeutralSynth = SynthPerformanceBar(
            bar: spread.bar,
            gesture: spread.gesture,
            mutationAmount: spread.mutationAmount,
            foundationInstrument: spread.foundationInstrument,
            relationalSteps: spread.relationalSteps,
            upperNotes: legacyNeutralNotes,
            pulseEchoTextureArticulation: spread.pulseEchoTextureArticulation
        )
        #expect(neutralSynth == legacyNeutralSynth)

        verifyNeutralAndActiveRendering(
            plan: plan,
            defaultResolved: spreadResolved,
            spread: spread,
            neutral: neutralSynth,
            legacyNeutral: legacyNeutralSynth
        )
        verifyLeadPerformanceRendering(
            plan: plan,
            defaultResolved: spreadResolved,
            performedResolved: performedResolved,
            performed: performed
        )
        verifyProtectedRhythmRendering(
            plan: plan,
            defaultResolved: spreadResolved,
            spread: spread,
            neutral: neutralSynth
        )

        let upperless = EnsembleContext(
            focusRole: source.ensemble.focusRole,
            events: source.ensemble.events.filter {
                $0.voice != .motif && $0.voice != .response
            },
            kickAnchors: source.ensemble.kickAnchors,
            intentionalPileup: source.ensemble.intentionalPileup
        )
        let upperlessResolved = ResolvedPerformanceBar(
            performance: replacing(absoluteBar: 7).performance,
            ensemble: upperless,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: .breath,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations: source.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative
        )
        #expect(synthBar(upperlessResolved).upperNotes.allSatisfy {
            $0.timingOffsetInSteps == 0
        })

        try verifyLivePreparedEvidence(director: director)
    }

    @inline(never)
    private func verifyUpperTimingApertureAndEligibility() {
        let expectedApertures: [Double] = [
            0.0, 1.0 / 7, 2.0 / 7, 3.0 / 7,
            4.0 / 7, 5.0 / 7, 6.0 / 7, 1.0,
            1.0, 6.0 / 7, 5.0 / 7, 4.0 / 7,
            3.0 / 7, 2.0 / 7, 1.0 / 7, 0.0,
        ]
        #expect((0..<16).map {
            SynthPerformancePlan.upperTimingAperture(absoluteBar: $0)
        } == expectedApertures)
        #expect(SynthPerformancePlan.upperTimingAperture(absoluteBar: -1) == 0)
        #expect(SynthPerformancePlan.upperTimingAperture(absoluteBar: 16) == 0)
        for role in [SynthRole.anchor, .atmosphere, .transition] {
            #expect(SynthPerformancePlan.upperTimingOffsetInSteps(
                for: role, absoluteBar: 7, enabled: true
            ) == 0)
        }
        #expect(SynthPerformancePlan.upperTimingOffsetInSteps(
            for: .shadow, absoluteBar: 7, enabled: true
        ) == 0.06)
        #expect(SynthPerformancePlan.upperTimingOffsetInSteps(
            for: .response, absoluteBar: 7, enabled: true
        ) == 0.12)
        #expect(SynthPerformancePlan.upperTimingOffsetInSteps(
            for: .response, absoluteBar: 15, enabled: true
        ) == 0)
        #expect(SynthPerformancePlan.upperTimingOffsetInSteps(
            for: .response, absoluteBar: 7, enabled: false
        ) == 0)

        let boundedFixture = ResolvedUpperNote(
            role: .response,
            onsetStep: 9,
            durationInSteps: 1.75,
            startFrequencyRatio: 2,
            endFrequencyRatio: 2.25,
            velocity: 0.7,
            gate: .retrigger,
            timbreIntent: .home,
            timingOffsetInSteps: 1
        )
        #expect(boundedFixture.timingOffsetInSteps == 0.12)
        #expect(boundedFixture.withTimingOffsetInSteps(-1).timingOffsetInSteps == 0)
        #expect(boundedFixture.withTimingOffsetInSteps(.nan).timingOffsetInSteps == 0)
        #expect(boundedFixture.withTimingOffsetInSteps(.infinity).timingOffsetInSteps == 0)
        let copiedFixture = boundedFixture.withTimingOffsetInSteps(0.04)
        #expect(copiedFixture.role == boundedFixture.role)
        #expect(copiedFixture.onsetStep == boundedFixture.onsetStep)
        #expect(copiedFixture.durationInSteps == boundedFixture.durationInSteps)
        #expect(copiedFixture.startFrequencyRatio == boundedFixture.startFrequencyRatio)
        #expect(copiedFixture.endFrequencyRatio == boundedFixture.endFrequencyRatio)
        #expect(copiedFixture.velocity == boundedFixture.velocity)
        #expect(copiedFixture.gate == boundedFixture.gate)
        #expect(copiedFixture.timbreIntent == boundedFixture.timbreIntent)
        #expect(copiedFixture.instrument == boundedFixture.instrument)
        let anchorFixture = ResolvedUpperNote(
            role: .anchor,
            onsetStep: boundedFixture.onsetStep,
            durationInSteps: boundedFixture.durationInSteps,
            startFrequencyRatio: boundedFixture.startFrequencyRatio,
            endFrequencyRatio: boundedFixture.endFrequencyRatio,
            velocity: boundedFixture.velocity,
            gate: boundedFixture.gate,
            timbreIntent: boundedFixture.timbreIntent
        )
        #expect(!SynthPerformancePlan.upperTimingEligible(
            notes: [anchorFixture], chapter: .breath, variationEnabled: true
        ))
        #expect(!SynthPerformancePlan.upperTimingEligible(
            notes: [boundedFixture], chapter: .breath, variationEnabled: true
        ))
        #expect(SynthPerformancePlan.upperTimingEligible(
            notes: [anchorFixture, boundedFixture],
            chapter: .breath,
            variationEnabled: true
        ))
        #expect(!SynthPerformancePlan.upperTimingEligible(
            notes: [anchorFixture, boundedFixture],
            chapter: .tone,
            variationEnabled: true
        ))
        #expect(!SynthPerformancePlan.upperTimingEligible(
            notes: [anchorFixture, boundedFixture],
            chapter: .breath,
            variationEnabled: false
        ))
    }

    @inline(never)
    private func renderUpperTimingBar(
        plan: AutonomousPhrasePlan,
        defaultResolved: ResolvedPerformanceBar,
        synth: SynthPerformanceBar,
        resolved: ResolvedPerformanceBar? = nil,
        layer: RenderLayer = .full
    ) -> RenderedBar {
        var renderState = RenderState()
        var workspace = RenderWorkspace()
        return VoiceRenderer.renderBar(
            scene: plan.scene,
            sampleRate: 8_000,
            state: &renderState,
            dna: plan.dna,
            resolved: resolved ?? defaultResolved,
            synthWorld: SynthWorldDNA(scene: plan.scene, dna: plan.dna),
            synthPerformance: synth,
            workspace: &workspace,
            layer: layer
        )
    }

    @inline(never)
    private func verifyNeutralAndActiveRendering(
        plan: AutonomousPhrasePlan,
        defaultResolved: ResolvedPerformanceBar,
        spread: SynthPerformanceBar,
        neutral: SynthPerformanceBar,
        legacyNeutral: SynthPerformanceBar
    ) {
        let legacyNeutralRender = renderUpperTimingBar(
            plan: plan,
            defaultResolved: defaultResolved,
            synth: legacyNeutral
        )
        let neutralRender = renderUpperTimingBar(
            plan: plan,
            defaultResolved: defaultResolved,
            synth: neutral
        )
        let activeRender = renderUpperTimingBar(
            plan: plan,
            defaultResolved: defaultResolved,
            synth: spread
        )
        #expect(neutralRender.leftSamples == legacyNeutralRender.leftSamples)
        #expect(neutralRender.rightSamples == legacyNeutralRender.rightSamples)
        #expect(neutralRender.dryFoundationSampleHash ==
                legacyNeutralRender.dryFoundationSampleHash)
        #expect(neutralRender.dryPercussionSampleHash ==
                legacyNeutralRender.dryPercussionSampleHash)
        #expect(activeRender.leftSamples != neutralRender.leftSamples)
        #expect(activeRender.resonantAnchorSamples == neutralRender.resonantAnchorSamples)
        #expect(activeRender.detunedCompanionSamples != neutralRender.detunedCompanionSamples)
        #expect(activeRender.upperTimingRenderEvidence.shadowSignal.sampleHash !=
                neutralRender.upperTimingRenderEvidence.shadowSignal.sampleHash)
        #expect(activeRender.dryFoundationSampleHash == neutralRender.dryFoundationSampleHash)
        #expect(activeRender.dryPercussionSampleHash == neutralRender.dryPercussionSampleHash)
        #expect(activeRender.groovePulseRenderEvidence ==
                neutralRender.groovePulseRenderEvidence)
        #expect(activeRender.closedHatRenderEvidence == neutralRender.closedHatRenderEvidence)
        #expect(activeRender.upperTimingRenderEvidence.events.contains {
            $0.role == .shadow && $0.requestedOffsetInSteps == 0.06 &&
                $0.appliedOnsetFrame == $0.expectedOnsetFrame
        })
        #expect(neutralRender.upperTimingRenderEvidence.events.allSatisfy {
            $0.requestedOffsetInSteps == 0 &&
                $0.appliedOnsetFrame == $0.expectedOnsetFrame
        })
        let activeUpperOnsets = Array(Set(activeRender.upperNoteRenderEvidence.compactMap {
            evidence -> Int? in
            switch evidence.role {
            case .anchor, .shadow, .response: evidence.onsetFrame
            case .atmosphere, .transition: nil
            }
        })).sorted()
        let activeUpperSamples = zip(
            activeRender.resonantAnchorSamples,
            activeRender.detunedCompanionSamples
        ).map { $0.0 + $0.1 }
        #expect(activeRender.stemObservations[.upperTonal] ==
                StemObservationAnalyzer.analyze(
                    activeUpperSamples,
                    sampleRate: 8_000,
                    onsetFrames: activeUpperOnsets
                ))
    }

    @inline(never)
    private func verifyLeadPerformanceRendering(
        plan: AutonomousPhrasePlan,
        defaultResolved: ResolvedPerformanceBar,
        performedResolved: ResolvedPerformanceBar,
        performed: SynthPerformanceBar
    ) {
        let performedNeutral = SynthPerformanceBar(
            bar: performed.bar,
            gesture: performed.gesture,
            mutationAmount: performed.mutationAmount,
            foundationInstrument: performed.foundationInstrument,
            relationalSteps: performed.relationalSteps,
            upperNotes: performed.upperNotes.map { $0.withTimingOffsetInSteps(0) },
            upperTimingRelation: .aligned,
            pulseEchoTextureArticulation: performed.pulseEchoTextureArticulation,
            tonalEnvelopeExpansionEligible:
                performed.tonalEnvelopeExpansionEligible,
            forceHomeUpperTimbre: performed.forceHomeUpperTimbre
        )
        let performedRender = renderUpperTimingBar(
            plan: plan,
            defaultResolved: defaultResolved,
            synth: performed,
            resolved: performedResolved
        )
        let performedNeutralRender = renderUpperTimingBar(
            plan: plan,
            defaultResolved: defaultResolved,
            synth: performedNeutral,
            resolved: performedResolved
        )
        #expect(performedRender.resonantAnchorSamples !=
                performedNeutralRender.resonantAnchorSamples)
        #expect(performedRender.detunedCompanionSamples ==
                performedNeutralRender.detunedCompanionSamples)
        #expect(performedRender.dryFoundationSampleHash ==
                performedNeutralRender.dryFoundationSampleHash)
        #expect(performedRender.dryPercussionSampleHash ==
                performedNeutralRender.dryPercussionSampleHash)
        #expect(performedRender.upperTimingRenderEvidence.relation ==
                .leadPerformance)
        #expect(performedRender.upperTimingRenderEvidence.anchorSignal.sampleHash !=
                performedNeutralRender.upperTimingRenderEvidence.anchorSignal.sampleHash)
        #expect(performedRender.upperTimingRenderEvidence.events.filter {
            $0.role == .anchor
        }.enumerated().allSatisfy { index, event in
            event.requestedOffsetInSteps ==
                SynthPerformancePlan.leadPerformanceOffsetInSteps(
                    performanceIndex: index
                ) && event.appliedOnsetFrame == event.expectedOnsetFrame
        })
    }

    @inline(never)
    private func verifyProtectedRhythmRendering(
        plan: AutonomousPhrasePlan,
        defaultResolved: ResolvedPerformanceBar,
        spread: SynthPerformanceBar,
        neutral: SynthPerformanceBar
    ) {
        let activeProtected = renderUpperTimingBar(
            plan: plan,
            defaultResolved: defaultResolved,
            synth: spread,
            layer: .protectedRhythm
        )
        let neutralProtected = renderUpperTimingBar(
            plan: plan,
            defaultResolved: defaultResolved,
            synth: neutral,
            layer: .protectedRhythm
        )
        #expect(activeProtected.leftSamples == neutralProtected.leftSamples)
        #expect(activeProtected.rightSamples == neutralProtected.rightSamples)
        #expect(activeProtected.dryFoundationSampleHash ==
                neutralProtected.dryFoundationSampleHash)
        #expect(activeProtected.dryPercussionSampleHash ==
                neutralProtected.dryPercussionSampleHash)
    }

    @inline(never)
    private func verifyLivePreparedEvidence(
        director: AutonomousSessionDirector
    ) throws {
        var liveState = director.initialState()
        var liveLeadPerformance: SynthPerformanceBar?
        var liveLeadPlan: AutonomousPhrasePlan?
        var liveLeadIncomingState: AutonomousSessionState?
        for _ in 0..<160 where liveLeadPerformance == nil {
            let candidates = director.plan(from: liveState)
            let candidateSynth = SynthPerformancePlan(
                scene: candidates.scene,
                dna: candidates.dna,
                kind: candidates.kind,
                resolvedBars: candidates.resolvedBars
            )
            liveLeadPerformance = candidateSynth.bars.first {
                $0.upperTimingRelation == .leadPerformance
            }
            if liveLeadPerformance != nil {
                liveLeadPlan = candidates
                liveLeadIncomingState = liveState
            } else {
                liveState.advancePlanning(using: candidates)
            }
        }
        let livePerformance = try #require(liveLeadPerformance)
        #expect(livePerformance.upperNotes(for: .anchor).filter {
            $0.timingOffsetInSteps > 0
        }.count == max(0, livePerformance.upperNotes(for: .anchor).count - 1))
        let livePlan = try #require(liveLeadPlan)
        let liveIncoming = try #require(liveLeadIncomingState)
        var liveRenderState = RenderState()
        liveRenderState.barIndex = liveIncoming.memory.totalBars
        let neverCancelled: @Sendable () -> Bool = { false }
        let livePrepared = try #require(
            AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: livePlan,
                sessionSeed: liveIncoming.rootSeed,
                memory: liveIncoming.memory,
                sampleRate: 8_000,
                incomingRenderState: liveRenderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: liveIncoming.quality,
                evaluator: AcceptingPrimaryTestEvaluator(),
                cancellationRequested: neverCancelled
            )
        )
        #expect(livePrepared.candidateEvaluation.isComplete)
        #expect(livePrepared.selectedCandidateEvidence.upperTiming.contains {
            $0.relation == UpperTimingRelation.leadPerformance.rawValue &&
                $0.isComplete(
                    routeSampleRate: 8_000,
                    phraseKind: .lock,
                )
        })
        #expect(livePrepared.blocks.contains {
            $0.upperTimingRenderEvidence.relation == .leadPerformance &&
                $0.upperTimingRenderEvidence.anchorSignal.peak > 0
        })
    }

    @Test("Upper-note frame geometry delays onset without consuming gate duration")
    func upperHarmonicTimingFrameGeometry() {
        let delayed = ResolvedUpperNote(
            role: .response,
            onsetStep: 14,
            durationInSteps: 0.75,
            startFrequencyRatio: 2,
            endFrequencyRatio: 2,
            velocity: 0.7,
            gate: .retrigger,
            timbreIntent: .home,
            timingOffsetInSteps: 0.12
        )
        let neutral = delayed.withTimingOffsetInSteps(0)
        for sampleRate in [8_000.0, 44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            let frameCount = Int((240.0 / 130 * sampleRate).rounded())
            let stepFrames = Double(frameCount) / 16
            let delayedStart = VoiceRenderer.upperNoteStartFrame(
                note: delayed,
                stepFrames: stepFrames,
                frameCount: frameCount
            )
            let neutralStart = VoiceRenderer.upperNoteStartFrame(
                note: neutral,
                stepFrames: stepFrames,
                frameCount: frameCount
            )
            #expect(delayedStart == Int(
                ((Double(delayed.onsetStep) + delayed.timingOffsetInSteps) * stepFrames)
                    .rounded()
            ))
            #expect(neutralStart == Int((Double(neutral.onsetStep) * stepFrames).rounded()))
            #expect(delayedStart > neutralStart)
            #expect(delayedStart < frameCount)
            let delayedDuration = VoiceRenderer.upperNoteDurationFrames(
                note: delayed,
                stepFrames: stepFrames
            )
            let neutralDuration = VoiceRenderer.upperNoteDurationFrames(
                note: neutral,
                stepFrames: stepFrames
            )
            #expect(delayedDuration == neutralDuration)
            #expect(delayedStart + delayedDuration < frameCount)
        }

        let director = AutonomousSessionDirector()
        let plan = director.plan(from: director.initialState())
        let sampleRate = 8_000.0
        let frameCount = Int((240.0 / plan.scene.bpm * sampleRate).rounded())
        let stepFrames = Double(frameCount) / 16
        let firstScore = ResolvedUpperNote(
            role: .response,
            onsetStep: 14,
            durationInSteps: 2,
            startFrequencyRatio: 2,
            endFrequencyRatio: 2,
            velocity: 0.7,
            gate: .retrigger,
            timbreIntent: .home,
            timingOffsetInSteps: 0.12
        )
        let secondScore = ResolvedUpperNote(
            role: .response,
            onsetStep: 15,
            durationInSteps: 0.5,
            startFrequencyRatio: 2.25,
            endFrequencyRatio: 2.25,
            velocity: 0.65,
            gate: .retrigger,
            timbreIntent: .home,
            timingOffsetInSteps: 0.12
        )
        let world = SynthWorldDNA(scene: plan.scene, dna: plan.dna)
        func alienNote(_ score: ResolvedUpperNote) -> AlienVoiceNote {
            AlienVoiceNote(
                startFrame: VoiceRenderer.upperNoteStartFrame(
                    note: score,
                    stepFrames: stepFrames,
                    frameCount: frameCount
                ),
                durationFrames: VoiceRenderer.upperNoteDurationFrames(
                    note: score,
                    stepFrames: stepFrames
                ),
                frequency: world.rootFrequency * score.startFrequencyRatio,
                endFrequency: world.rootFrequency * score.endFrequencyRatio,
                velocity: score.velocity,
                gate: score.gate,
                timbreIntent: score.timbreIntent,
                instrument: score.instrument,
                role: score.role,
                articulation: .neutral,
                dryScale: 1,
                spatialReverbSend: 0,
                narrativeGainScale: 1,
                narrativeSpectralScale: 1
            )
        }
        let synthBar = SynthPerformanceBar(
            bar: 7,
            gesture: .interlock,
            mutationAmount: 0.4,
            relationalSteps: Array(repeating: .neutral, count: 16),
            upperNotes: [firstScore, secondScore]
        )
        var output = [Float](repeating: 0, count: frameCount)
        var measurement = output
        var architectureMeasurement = output
        var pulseEchoSend = output
        var spatialReverbSend = output
        var evidence: [UpperNoteRenderEvidence] = []
        var voiceState = AlienVoiceState()
        AlienAnalogVoice.render(
            &output,
            measurement: &measurement,
            architectureMeasurement: &architectureMeasurement,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &evidence,
            notes: [alienNote(firstScore), alienNote(secondScore)],
            sampleRate: sampleRate,
            level: 0.08,
            world: world,
            bar: synthBar,
            role: .response,
            state: &voiceState
        )
        #expect(evidence.count == 2)
        let firstStart = VoiceRenderer.upperNoteStartFrame(
            note: firstScore,
            stepFrames: stepFrames,
            frameCount: frameCount
        )
        let secondStart = VoiceRenderer.upperNoteStartFrame(
            note: secondScore,
            stepFrames: stepFrames,
            frameCount: frameCount
        )
        #expect(evidence[0].onsetFrame == firstStart)
        #expect(evidence[0].requestedGateEndFrame == firstStart +
                VoiceRenderer.upperNoteDurationFrames(
                    note: firstScore,
                    stepFrames: stepFrames
                ))
        #expect(evidence[0].appliedGateEndFrame == secondStart)
        #expect(evidence[0].appliedGateEndFrame < evidence[0].requestedGateEndFrame)
        #expect(evidence[1].onsetFrame == secondStart)
        #expect(evidence[1].requestedGateEndFrame == secondStart +
                VoiceRenderer.upperNoteDurationFrames(
                    note: secondScore,
                    stepFrames: stepFrames
                ))
        #expect(evidence[1].appliedGateEndFrame <= frameCount)
    }

    @Test("Bounded interlock state evolves deterministically for more than eight hours")
    func indefiniteInterlockEvolution() {
        func journey() -> [InterlockEvolutionState] {
            var state = InterlockEvolutionState()
            var states: [InterlockEvolutionState] = [state]
            let kinds: [AutonomousPhraseKind] = [
                .lock, .contrast, .lock, .majorBreak, .energyRelease, .lock, .identityReturn,
            ]
            for macro in 1...1_024 {
                let kind = kinds[macro % kinds.count]
                let entropy = SceneDNA.derivedSeed(
                    scene: AutonomousSessionDirector.defaultSeed,
                    domain: 0x1A7E2C10,
                    index: macro
                )
                let previous = state
                state = state.advancing(for: kind, entropy: entropy)
                #expect(state.previousChapters.count <= 2)
                #expect(state.macrosSinceHome <= 4)
                if state.currentChapter != .home {
                    #expect(state.currentChapter != previous.currentChapter)
                }
                states.append(state)
            }
            return states
        }

        let first = journey()
        #expect(first == journey())
        #expect(first.last?.macroIndex == 1_024)
        #expect(Set(first.map(\.currentChapter)) == Set(InterlockChapter.allCases))
    }

    @Test("One thousand twenty-four macros keep bounded narrative and chapter variation")
    func indefiniteUnifiedEvolution() {
        func journey() -> (kinds: [AutonomousPhraseKind],
                           supports: [[PerformanceRole]],
                           finalState: AutonomousSessionState) {
            let director = AutonomousSessionDirector()
            var state = director.initialState()
            var kinds: [AutonomousPhraseKind] = []
            var supports: [[PerformanceRole]] = []
            var phraseCount = 0
            while state.memory.totalBars < 16 * 1_024, phraseCount < 5_000 {
                let plan = director.plan(from: state)
                kinds.append(plan.kind)
                supports.append(plan.endingNarrativeState.activeSupportingRoles)
                #expect(plan.endingNarrativeState.activeSupportingRoles.count <= 3)
                #expect(Set(plan.endingNarrativeState.activeSupportingRoles).count ==
                        plan.endingNarrativeState.activeSupportingRoles.count)
                #expect(plan.endingNarrativeState.protagonistPresence.isFinite)
                #expect((0...1).contains(plan.endingNarrativeState.protagonistPresence))
                #expect(plan.endingInterlockState.previousChapters.count <= 2)
                #expect(plan.endingInterlockState.macrosSinceHome <= 4)
                if plan.kind == .majorBreak {
                    #expect(plan.resolvedBars.allSatisfy {
                        $0.narrative.activeSupportingRoles == [.atmosphere]
                    })
                }
                state.advancePlanning(using: plan)
                #expect(state.memory.recentBars.count <= 4)
                #expect(state.memory.currentPhrase.count <= 16)
                #expect(state.memory.previousPhrase.count <= 16)
                #expect(state.memory.dramaticArc.count <= 128)
                #expect(state.memory.sessionBars.count <= 256)
                phraseCount += 1
            }
            #expect(phraseCount < 5_000)
            #expect(state.memory.interlockEvolution.macroIndex >= 1_024)
            return (kinds, supports, state)
        }

        let first = journey()
        let replay = journey()
        #expect(first.kinds == replay.kinds)
        #expect(first.supports == replay.supports)
        #expect(first.finalState == replay.finalState)
        #expect(Set(first.kinds) == Set(AutonomousPhraseKind.allCases))
        #expect(first.kinds.filter { $0 == .identityReturn }.count > 1)
        #expect(first.supports.contains { $0.count <= 1 })
        #expect(first.supports.contains { $0.count >= 2 })
        #expect(zip(first.supports, first.supports.dropFirst()).contains { $0.0 != $0.1 })
    }

    @Test("Foundation behaviors vary, leave space, and return to the hypnotic home")
    func foundationCompanionContinuity() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var sawContrastDeparture = false
        var sawBreakSpace = false
        for _ in 0..<100 {
            let plan = director.plan(from: state)
            if plan.kind == .contrast {
                sawContrastDeparture = sawContrastDeparture || plan.resolvedBars.contains {
                    $0.foundationBehavior == .point || $0.foundationBehavior == .kickTail
                }
            }
            if plan.kind == .majorBreak {
                sawBreakSpace = sawBreakSpace || plan.resolvedBars.contains {
                    $0.foundationBehavior == .absent || $0.foundationBehavior == .kickTail
                }
            }
            if plan.kind == .identityReturn {
                #expect(plan.resolvedBars.allSatisfy {
                    $0.performanceCharacter == .hypnoticLock &&
                        PerformanceCharacterContract.foundationIsCompatible(
                            $0.foundationBehavior,
                            with: .hypnoticLock
                        ) && $0.foundationCompanion == .bass
                })
            }
            state.advancePlanning(using: plan)
        }
        #expect(sawContrastDeparture)
        #expect(sawBreakSpace)
    }

    @Test("Director modal percussion follows only surviving tuned foundation events")
    func directorModalPercussionOwnsExistingFoundationEvents() {
        var foundModalFoundation = false
        for rawSeed in 1...24 {
            let result = sequence(seed: UInt64(rawSeed), phraseCount: 32)
            for plan in result.plans {
                for resolved in plan.resolvedBars {
                    let tunedEvents = resolved.ensemble.events.enumerated().filter {
                        $0.element.voice == .tunedTom
                    }
                    let articulations = resolved.modalPercussionArticulations
                    if !tunedEvents.isEmpty {
                        foundModalFoundation = true
                    }
                    #expect(articulations.count == tunedEvents.count)
                    #expect(articulations.count <= 2)
                    #expect(articulations.map(\.scoreEventIndex) == tunedEvents.map(\.offset))
                    #expect(zip(articulations, tunedEvents).allSatisfy { articulation, event in
                        articulation.use == .foundationCompanion &&
                            articulation.step == event.element.step &&
                            articulation.eventIntensity == event.element.intensity
                    })
                    #expect((resolved.foundationBehavior == .tunedPercussive) ==
                            !articulations.isEmpty)
                }
            }
        }
        #expect(foundModalFoundation)
    }

    @Test("Dark scenes can establish Phrygian identity without changing it between phrases")
    func phrygianIdentityAndMotifFingerprint() {
        let intent = MusicalIntent(values: [.darkness: 1, .atmosphericDarkness: 0.7])
        var matched: (AutonomousSessionDirector, AutonomousSessionState)?
        for seed in UInt64(1)...256 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = AutonomousSessionState(rootSeed: seed, intent: intent)
            if state.identityDNA.modalIdentity == .phrygian {
                matched = (director, state)
                break
            }
        }
        guard let (director, initialState) = matched else {
            Issue.record("Expected a deterministic dark seed to select Phrygian identity")
            return
        }
        #expect(initialState.identityDNA.modalDegrees == [0, 1, 3, 5, 7, 8, 10])
        #expect(initialState.identityDNA.motif.degrees.allSatisfy {
            [0, 1, 3, 5, 7, 8, 10, 12].contains($0)
        })
        var state = initialState
        var fingerprints: [MotifTimbreFingerprint] = []
        for _ in 0..<20 {
            let plan = director.plan(from: state)
            let world = SynthWorldDNA(scene: plan.scene, dna: plan.dna)
            let synth = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars
            )
            #expect([1, 3, 7, 12].contains(world.shadowInterval))
            fingerprints.append(world.motifFingerprint)
            for bar in synth.bars {
                #expect(bar.upperNotes(for: .anchor).allSatisfy { note in
                    let scaleDegree = Int((12 * log2(note.endFrequencyRatio)).rounded())
                    let pitchClass = ((scaleDegree % 12) + 12) % 12
                    return [0, 1, 3, 5, 7, 8, 10].contains(pitchClass)
                })
            }
            state.advancePlanning(using: plan)
        }
        let fingerprint = fingerprints.first
        #expect(fingerprints.dropFirst().allSatisfy { Optional($0) == fingerprint })
    }

    @Test("Structural promises remain bounded and releases pay every open debt",
          arguments: [UInt64(42), 48_291, 90_909])
    func dramaticPromises(seed: UInt64) {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        var contrastBars: [Int] = []
        var breakBars: [Int] = []
        var releaseBars: [Int] = []
        var completedEpisodes: [UInt64: LongHorizonCompletedEpisode] = [:]

        for _ in 0..<120 {
            let plan = director.plan(from: state)
            if plan.kind != .lock { contrastBars.append(plan.startBar) }
            if plan.kind == .majorBreak { breakBars.append(plan.startBar) }
            if plan.kind == .energyRelease {
                releaseBars.append(plan.startBar)
                #expect(Set(plan.paidDebtIDs) == Set(state.memory.openDebts.map(\.id)))
            }
            state.advancePlanning(using: plan)
            for episode in state.memory.longHorizon.recentEpisodes {
                completedEpisodes[episode.id] = episode
            }
            if plan.kind == .energyRelease { #expect(state.memory.openDebts.isEmpty) }
        }

        #expect(!completedEpisodes.isEmpty)
        #expect(completedEpisodes.values.allSatisfy { episode in
            episode.completedAtBar >= episode.minimumHoldUntilBar &&
                episode.completedAtBar <= episode.dueByBar + 15 &&
                episode.minimumHoldUntilBar - episode.startedAtBar >=
                    LongHorizonContinuationSchema.minimumEpisodeMacros * 16 &&
                episode.dueByBar - episode.startedAtBar <=
                    LongHorizonContinuationSchema.maximumEpisodeMacros * 16
        })
        #expect(intervals(contrastBars).allSatisfy { $0 >= 4 })
        #expect(intervals(breakBars).allSatisfy { $0 >= 4 })
        #expect(intervals(releaseBars).allSatisfy { $0 >= 4 })
        #expect(!contrastBars.isEmpty)
        #expect(!breakBars.isEmpty)
        #expect(!releaseBars.isEmpty)
    }

    @Test("Ensemble arbitration protects anchors and caps unplanned competition")
    func ensembleArbitration() {
        let proposals = [
            EnsembleEventProposal(voice: .kick, requestedStep: 0, priority: 100,
                                  intensity: 1, essential: true),
            EnsembleEventProposal(voice: .bass, requestedStep: 0, alternateSteps: [1, 3],
                                  priority: 90, intensity: 0.8, essential: true),
            EnsembleEventProposal(voice: .motif, requestedStep: 0, alternateSteps: [1, 2],
                                  priority: 70, intensity: 0.6),
            EnsembleEventProposal(voice: .response, requestedStep: 0, alternateSteps: [2, 3],
                                  priority: 60, intensity: 0.5),
            EnsembleEventProposal(voice: .percussion, requestedStep: 0, alternateSteps: [2, 4],
                                  priority: 50, intensity: 0.5),
        ]
        let result = EnsembleArbiter.resolve(
            proposals: proposals, focusRole: .motif, intentionalPileup: false
        )
        let occupancy = Dictionary(grouping: result.events, by: \.step).mapValues(\.count)
        #expect(result.kickAnchors == [0])
        #expect(result.events.contains { $0.voice == .kick && $0.step == 0 && !$0.relocated })
        #expect(result.events.filter { $0.voice == .bass }.allSatisfy { $0.step != 0 })
        #expect(occupancy.values.allSatisfy { $0 <= 3 })
        #expect(result.events.contains { $0.relocated })

        let groove = GroovePulseResolver.proposals(
            absoluteBar: 8, percussionActive: true,
            majorBreak: false, gesture: .steady
        )
        let withoutPulses = EnsembleArbiter.resolve(
            proposals: proposals, focusRole: .motif, intentionalPileup: false
        )
        let withPulses = EnsembleArbiter.resolve(
            proposals: proposals + groove, focusRole: .motif, intentionalPileup: false
        )
        #expect(withPulses.events.filter { $0.voice != .groovePulse } == withoutPulses.events)
        let withPulseOccupancy = Dictionary(grouping: withPulses.events, by: \.step)
            .mapValues(\.count)
        #expect(withPulseOccupancy.values.allSatisfy { $0 <= 3 })
    }

    @Test("Stale preparation epochs and late phrase policy fail coherently")
    func runtimePolicies() {
        var epoch = AutonomousPreparationEpoch()
        let stale = epoch.value
        #expect(epoch.accepts(stale))
        epoch.invalidate()
        #expect(!epoch.accepts(stale))
        #expect(epoch.accepts(epoch.value))
        #expect(AutonomousPhraseBoundaryPolicy.decide(successorPrepared: true) == .advance)
        #expect(AutonomousPhraseBoundaryPolicy.decide(successorPrepared: false) ==
                .repeatCurrentWithFrozenTopology)
    }

    private func sequence(seed: UInt64, phraseCount: Int)
        -> (plans: [AutonomousPhrasePlan], state: AutonomousSessionState) {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        var plans: [AutonomousPhrasePlan] = []
        for _ in 0..<phraseCount {
            let plan = director.plan(from: state)
            plans.append(plan)
            state.advancePlanning(using: plan)
        }
        return (plans, state)
    }

    private func coordinatedPercussionGear(
        absoluteBar: Int,
        relationship: LongHorizonEnergyRelationship
    ) -> PercussionGear {
        let baseline: PercussionGear = switch (absoluteBar % 16) / 4 {
        case 0: .anchor
        case 1: .lift
        case 2: .contrast
        default: .turnaround
        }
        guard relationship != .hold else { return baseline }
        let tiers: [PercussionGear] = [.anchor, .turnaround, .contrast, .lift]
        let index = tiers.firstIndex(of: baseline) ?? 0
        switch relationship {
        case .hold:
            return baseline
        case .lower, .home:
            return tiers[max(0, index - 1)]
        case .raise:
            return tiers[min(tiers.count - 1, index + 1)]
        case .change:
            if index == 0 { return tiers[1] }
            if index == tiers.count - 1 { return tiers[index - 1] }
            let quarter = (max(0, absoluteBar) % 16) / 4
            return quarter.isMultiple(of: 2) ? tiers[index + 1] : tiers[index - 1]
        }
    }

    private func intervals(_ values: [Int]) -> [Int] {
        zip(values, values.dropFirst()).map { $1 - $0 }
    }
}

@Suite("Generated DSP topology")
struct GeneratedDSPTopologyTests {
    @Test("One thousand graph sequences stay valid, bounded, protected, and reconstructable")
    func graphProperties() {
        for rawSeed in 1...1_000 {
            let seed = UInt64(rawSeed)
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            let firstPhrase = director.plan(from: state)
            let firstGraph = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: firstPhrase, memory: state.memory, previous: nil
            )
            state.advancePlanning(using: firstPhrase)
            let secondPhrase = director.plan(from: state)
            let secondGraph = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: secondPhrase, memory: state.memory, previous: firstGraph
            )

            for graph in [firstGraph, secondGraph] {
                let validation = DSPGraphValidator.validate(graph)
                #expect(validation.valid)
                #expect(graph.lowEndProtected)
                #expect(graph.protectedRouting.valid)
                #expect(!graph.nodes.isEmpty)
                #expect(graph.nodes.count <= DSPGraphPlan.maximumNodeCount)
                #expect(graph.maximumDepth <= DSPGraphPlan.maximumSerialDepth)
                #expect(graph.branchCount <= DSPGraphPlan.maximumBranchCount)
                #expect((graph.mutation?.affectedNodeIDs.count ?? 0) <= 2)
            }

            let replayFirst = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: firstPhrase,
                memory: director.initialState().memory, previous: nil
            )
            let replaySecond = DSPGraphGenerator.plan(
                sessionSeed: seed, phrase: secondPhrase, memory: state.memory,
                previous: replayFirst
            )
            #expect(firstGraph == replayFirst)
            #expect(secondGraph == replaySecond)
        }
    }

    @Test("Legacy random mutation suppression", .disabled("Replaced by target-directed material-world morph coverage"))
    func mutationSuppression() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var graph: DSPGraphPlan?
        var releasePlan: AutonomousPhrasePlan?
        for _ in 0..<40 {
            let plan = director.plan(from: state)
            graph = DSPGraphGenerator.plan(
                sessionSeed: state.rootSeed, phrase: plan, memory: state.memory, previous: graph
            )
            if plan.kind == .energyRelease {
                releasePlan = plan
                break
            }
            state.advancePlanning(using: plan)
        }
        guard let releasePlan, let graph else {
            Issue.record("Expected an energy release within forty phrases")
            return
        }
        let releaseGraph = DSPGraphGenerator.plan(
            sessionSeed: state.rootSeed, phrase: releasePlan, memory: state.memory, previous: graph
        )
        let recoveryGraph = DSPGraphGenerator.plan(
            sessionSeed: state.rootSeed, phrase: releasePlan, memory: state.memory,
            previous: graph, routeRecovery: true
        )
        #expect(releaseGraph.mutation == nil)
        #expect(recoveryGraph.mutation == nil)
        #expect(releaseGraph.hasSameTopology(as: graph))
        #expect(recoveryGraph.hasSameTopology(as: graph))

        var replacementNodes = graph.nodes
        let replaced = replacementNodes[0]
        replacementNodes[0] = DSPGraphNode(
            id: replaced.id,
            kind: replaced.kind == .waveFold ? .saturation : .waveFold,
            branch: replaced.branch,
            order: replaced.order,
            amount: replaced.amount,
            mix: replaced.mix,
            feedback: 0,
            delaySeconds: 0
        )
        let selectedTarget = DSPGraphPlan(
            sessionSeed: graph.sessionSeed,
            revision: graph.revision + 1,
            nodes: replacementNodes,
            mutation: DSPGraphMutation(
                kind: .replace,
                phraseIndex: releasePlan.phraseIndex,
                affectedNodeIDs: [replaced.id]
            )
        )
        let recoveredSelectedTarget = DSPGraphGenerator.plan(
            sessionSeed: state.rootSeed,
            phrase: releasePlan,
            memory: state.memory,
            previous: selectedTarget,
            routeRecovery: true
        )
        #expect(recoveredSelectedTarget == selectedTarget)
        #expect(recoveredSelectedTarget.mutation?.affectedNodeIDs == [replaced.id])
    }

    @Test("Legacy rejected random mutation", .disabled("Random operation selection was consolidated into bounded target convergence"))
    func rejectedMutationClearsPriorMetadata() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var mutationPlan: AutonomousPhrasePlan?
        var mutationMemory: TemporalMusicalMemory?
        for _ in 0..<64 {
            let plan = director.plan(from: state)
            if plan.requestsTopologyMutation && plan.kind != .energyRelease {
                mutationPlan = plan
                mutationMemory = state.memory
                break
            }
            state.advancePlanning(using: plan)
        }
        let plan = try #require(mutationPlan)
        let memory = try #require(mutationMemory)

        var selectedSeed: UInt64?
        var selectedIndex = 0
        for seed in UInt64(1)...UInt64(10_000) {
            let mutationSeed = SceneDNA.derivedSeed(
                scene: seed,
                domain: UInt64(plan.phraseIndex + memory.topologyRevision + 1),
                index: 0
            )
            let kind = DSPGraphMutationKind.allCases[
                Int(mutationSeed % UInt64(DSPGraphMutationKind.allCases.count))
            ]
            let index = Int((mutationSeed >> 11) % 5)
            if kind == .bypass && (1...3).contains(index) {
                selectedSeed = seed
                selectedIndex = index
                break
            }
        }
        let sessionSeed = try #require(selectedSeed)
        var nodes: [DSPGraphNode] = []
        for index in 0..<5 {
            let branch: Int
            let order: Int
            if index < selectedIndex {
                branch = 0
                order = index
            } else if index == selectedIndex {
                branch = 1
                order = 0
            } else {
                branch = 2
                order = index - selectedIndex - 1
            }
            nodes.append(DSPGraphNode(
                id: index,
                kind: .saturation,
                branch: branch,
                order: order,
                amount: 0.25,
                mix: 0.2
            ))
        }
        let previous = DSPGraphPlan(
            sessionSeed: sessionSeed,
            revision: 1,
            nodes: nodes,
            mutation: DSPGraphMutation(
                kind: .replace,
                phraseIndex: max(0, plan.phraseIndex - 1),
                affectedNodeIDs: [0]
            )
        )
        #expect(DSPGraphValidator.validate(previous).valid)

        let frozen = DSPGraphGenerator.plan(
            sessionSeed: sessionSeed,
            phrase: plan,
            memory: memory,
            previous: previous
        )
        #expect(frozen.hasSameTopology(as: previous))
        #expect(frozen.mutation == nil)
    }

    @Test("Topology transitions crossfade for one bar and retire tails after two")
    func crossfadeAndTail() {
        let first = DSPGraphGenerator.safePlan(sessionSeed: 42)
        let second = DSPGraphPlan(
            sessionSeed: 42,
            revision: 1,
            nodes: [
                DSPGraphNode(id: 10, kind: .waveFold, branch: 0, order: 0,
                             amount: 0.72, mix: 0.54),
                DSPGraphNode(id: 11, kind: .echo, branch: 1, order: 0,
                             amount: 0.46, mix: 0.36, feedback: 0.42, delaySeconds: 0.08),
            ],
            mutation: DSPGraphMutation(kind: .replace, phraseIndex: 1, affectedNodeIDs: [10])
        )
        let input = (0..<2_048).map { Float(sin(Double($0) * 0.031) * 0.2) }
        var state = GeneratedDSPContinuationState()
        _ = GeneratedDSPGraphRenderer.process(
            left: input, right: input, sampleRate: 8_000, plan: first, state: &state
        )
        var oldOnlyState = state
        let oldOnly = GeneratedDSPGraphRenderer.process(
            left: input, right: input, sampleRate: 8_000, plan: first, state: &oldOnlyState
        )
        let crossfaded = GeneratedDSPGraphRenderer.process(
            left: input, right: input, sampleRate: 8_000, plan: second, state: &state
        )
        #expect(abs(crossfaded.0[0] - oldOnly.0[0]) < 0.000_01)
        #expect(state.retiringBarsRemaining == 1)
        let silence = [Float](repeating: 0, count: input.count)
        let tail = GeneratedDSPGraphRenderer.process(
            left: silence, right: silence, sampleRate: 8_000, plan: second, state: &state
        )
        #expect(tail.0.contains { abs($0) > 0.000_001 })
        #expect(state.retiringBarsRemaining == 0)
        #expect(state.retiringGraph == nil)
        #expect(tail.0.allSatisfy(\.isFinite) && tail.1.allSatisfy(\.isFinite))
    }
}

@Suite("Autonomous preparation preflight")
struct AutonomousPreparationPreflightTests {
    private final class InputGateCancellationProbe: @unchecked Sendable {
        private(set) var callCount = 0

        func cancellationRequested() -> Bool {
            callCount += 1
            return callCount > 1
        }
    }

    private struct ModalPlanFixture {
        let state: AutonomousSessionState
        let plan: AutonomousPhrasePlan
        let barIndex: Int
    }

    private struct PulseEchoRenderProjection: Equatable {
        let events: [[VoiceEvent]]
        let upperNoteEvidence: [[UpperNoteRenderEvidence]]
        let instrumentEvidence: [[InstrumentArchitectureRenderEvidence]]
        let protectedFoundationHashes: [String]
        let percussionHashes: [String]
        let protectedRhythmHashes: [String]
        let pulseEchoEvidence: [PulseEchoReturnDriveRenderEvidence]
        let effects: [[EffectState]]
        let outputHashes: [String]
    }

    private struct PulseEchoRenderMaterial {
        let projection: PulseEchoRenderProjection
        let left: [Float]
    }

    private struct PulseEchoRenderPair {
        let first: PulseEchoRenderProjection
        let second: PulseEchoRenderProjection
        let differenceEnergy: Double
        let lowDifferenceEnergy: Double
    }

    @Test("Modal percussion plan fingerprint covers every score field")
    func modalPercussionPlanFingerprintCoversEveryScoreField() {
        guard let fixture = modalPlanFixture(),
              let source = fixture.plan.resolvedBars[fixture.barIndex]
                .modalPercussionArticulations.first else {
            Issue.record("Expected a canonical modal foundation articulation")
            return
        }
        let originalFingerprint = AutonomousCandidateFingerprint.plan(fixture.plan)
        let alternateIdentity = ModalIdentity.allCases.first {
            $0 != source.modalIdentity
        } ?? source.modalIdentity
        let changes: [ModalPercussionArticulation] = [
            replacing(source, scoreEventIndex: source.scoreEventIndex + 1),
            replacing(source, step: source.step + 1),
            replacing(source, use: .sparsePercussion),
            replacing(source, modalIdentity: alternateIdentity),
            replacing(source, modalDegree: source.modalDegree + 1),
            replacing(source, octave: source.octave + 1),
            replacing(source, fundamentalHz: min(196, source.fundamentalHz + 1)),
            replacing(source, excitation: source.excitation == 0 ? 1 : 0),
            replacing(source, damping: source.damping == 0 ? 1 : 0),
            replacing(source, brightness: source.brightness == 0 ? 1 : 0),
            replacing(
                source,
                inharmonicity: source.inharmonicity == 0 ? 0.12 : 0
            ),
            replacing(
                source,
                eventIntensity: source.eventIntensity == 0 ? 1 : 0
            ),
            replacing(source, seed: source.seed ^ 0xA5A5),
        ]

        for changed in changes {
            let changedPlan = replacingModalArticulations(
                in: fixture,
                with: fixture.plan.resolvedBars[fixture.barIndex]
                    .modalPercussionArticulations.map {
                        $0.scoreEventIndex == source.scoreEventIndex ? changed : $0
                    }
            )
            #expect(AutonomousCandidateFingerprint.plan(changedPlan) != originalFingerprint)
        }
    }

    @Test("Preflight rejects missing, duplicate, reordered, and forged modal articulations")
    func preflightRejectsMissingDuplicateReorderedAndForgedModalArticulations() {
        guard let fixture = modalPlanFixture(),
              fixture.plan.resolvedBars[fixture.barIndex]
                .modalPercussionArticulations.count == 2 else {
            Issue.record("Expected two canonical modal foundation articulations")
            return
        }
        let source = fixture.plan.resolvedBars[fixture.barIndex]
            .modalPercussionArticulations
        let reordered = [
            replacing(source[0], scoreEventIndex: source[1].scoreEventIndex),
            replacing(source[1], scoreEventIndex: source[0].scoreEventIndex),
        ]
        let forged = [
            replacing(
                source[0],
                fundamentalHz: min(196, source[0].fundamentalHz + 1)
            ),
            source[1],
        ]
        let attacks = [
            [ModalPercussionArticulation](),
            [source[0], source[0]],
            reordered,
            forged,
        ]

        for attack in attacks {
            let plan = replacingModalArticulations(in: fixture, with: attack)
            let probe = probePreparation(plan: plan, state: fixture.state)
            #expect(probe.prepared == nil)
            #expect(probe.cancellationCallCount == 1)
        }
    }

    @Test("Canonical kick replay preserves modal articulations")
    func canonicalKickReplayPreservesModalArticulations() {
        guard let fixture = modalPlanFixture() else {
            Issue.record("Expected a canonical modal foundation articulation")
            return
        }
        let probe = probePreparation(plan: fixture.plan, state: fixture.state)
        #expect(probe.prepared == nil)
        #expect(probe.cancellationCallCount > 1)
    }

    @Test("Fixed-seed phrase audio is deterministic and satisfies safety limits",
          arguments: [UInt64(42), 48_291, 90_909])
    func fixedSeedAudio(seed: UInt64) {
        let first = prepare(seed: seed, sampleRate: 8_000)
        let second = prepare(seed: seed, sampleRate: 8_000)
        #expect(first.plan == second.plan)
        #expect(first.graph == second.graph)
        #expect(first.blocks == second.blocks)
        #expect(first.endingGraphState == second.endingGraphState)
        #expect(first.audioPreflight == second.audioPreflight)
        #expect(first.audioPreflight.safetyValid)
        #expect(first.audioPreflight.quality.finite)
        #expect(first.audioPreflight.quality.truePeakEstimate <= 0.95)
        #expect(abs(first.audioPreflight.quality.dcOffset) < 0.05)
        #expect(first.audioPreflight.quality.lowStereoCorrelation > 0.94)
        #expect(first.audioPreflight.quality.maxBoundaryDelta < 0.65)
        #expect(first.audioPreflight.quality.sampleHash == second.audioPreflight.quality.sampleHash)
    }

    @Test("Kick fader trims only the audible and masking path")
    func kickMixHierarchy() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let sourcePlan = director.plan(from: state)
        guard let source = sourcePlan.resolvedBars.first(where: { resolved in
            resolved.ensemble.events.contains { $0.voice == .kick }
        }) else {
            Issue.record("Expected a resolved kick event")
            return
        }

        func replacingSection(_ section: SectionKind) -> ResolvedPerformanceBar {
            let performance = source.performance
            return ResolvedPerformanceBar(
                performance: PerformanceBar(
                    bar: performance.bar,
                    phrase: performance.phrase,
                    localBar: performance.localBar,
                    phraseLength: performance.phraseLength,
                    section: section,
                    tension: performance.tension,
                    roles: performance.roles,
                    transformations: performance.transformations,
                    signatureEvent: performance.signatureEvent,
                    eventSeed: performance.eventSeed,
                    accentContour: performance.accentContour
                ),
                ensemble: source.ensemble,
                arrangementGesture: source.arrangementGesture,
                percussionGear: source.percussionGear,
                foundationCompanion: source.foundationCompanion,
                pulseEchoEnabled: source.pulseEchoEnabled,
                interlockChapter: source.interlockChapter,
                groovePulses: source.groovePulses,
                spatialContrast: source.spatialContrast,
                narrative: source.narrative
            )
        }

        func render(_ resolved: ResolvedPerformanceBar) -> RenderBlock {
            let plan = replacingResolvedBars(
                in: sourcePlan, with: [resolved], memory: state.memory
            )
            var renderState = RenderState()
            var graphState = GeneratedDSPContinuationState()
            return AutonomousPhraseRenderer.render(
                plan: plan,
                graph: DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed),
                sampleRate: 8_000,
                state: &renderState,
                graphState: &graphState
            )[0]
        }

        let regular = render(replacingSection(.groove))
        let breakdown = render(replacingSection(.breakdown))
        #expect(abs(KickMixBalance.audibleLevel(for: .groove) - 0.605_804) < 0.000_001)
        #expect(abs(KickMixBalance.audibleLevel(for: .breakdown) - 0.454_353) < 0.000_001)

        for block in [regular, breakdown] {
            let mix = block.kickMix
            #expect(mix.detectorRMS > 0)
            let measuredTrim = 20 * log10(Double(mix.audibleRMS / mix.detectorRMS))
            let automaticTrim = block.automaticMix.gainsDB[.kick] ?? 0
            let expectedTrim = KickMixBalance.attenuationDB + automaticTrim
            #expect(abs(measuredTrim - expectedTrim) <= 0.05)
            #expect(abs(Double(mix.audiblePeak / mix.detectorPeak) -
                        KickMixBalance.audibleGain * block.automaticMix.gain(for: .kick)) < 0.000_001)
            #expect(abs(mix.audibleGain -
                        KickMixBalance.audibleGain * block.automaticMix.gain(for: .kick)) < 0.000_001)
            #expect(automaticTrim <= AutomaticMixBalancer.homeKickCorrectionDB)
            #expect(automaticTrim >= AutomaticMixBalancer.minimumKickCorrectionDB)
            #expect(abs(mix.duckingEnvelopePeak - mix.detectorPeak) < 0.000_001)
            #expect(abs((block.busStates[.kick]?.level ?? -1) -
                        Double(mix.audibleRMS)) < 0.000_001)
            let renderedKickSteps = block.events.filter { $0.voice == .kick }.map(\.step)
            let resolvedKickSteps = block.resolvedPerformance.ensemble.events
                .filter { $0.voice == .kick }.map(\.step)
            #expect(renderedKickSteps == resolvedKickSteps)
        }

        let regularInputUnitRMS =
            regular.kickMix.sourceDynamics.inputRMS /
            KickMixBalance.regularDetectorLevel
        let breakdownInputUnitRMS =
            breakdown.kickMix.sourceDynamics.inputRMS /
            KickMixBalance.breakdownDetectorLevel
        #expect(abs(regularInputUnitRMS - breakdownInputUnitRMS) < 0.000_001)
        let regularTransfer = regular.kickMix.sourceDynamics.outputRMS /
            regular.kickMix.sourceDynamics.inputRMS
        let breakdownTransfer = breakdown.kickMix.sourceDynamics.outputRMS /
            breakdown.kickMix.sourceDynamics.inputRMS
        #expect(regularTransfer < breakdownTransfer)
    }

    @Test("Role stems reconstruct the dry buses and report actual levels")
    func roleStemTruth() {
        let prepared = prepare(seed: 42, sampleRate: 8_000)
        for block in prepared.blocks {
            #expect(block.stemReconstruction.dryCenterMaximumError < 0.000_001)
            #expect(block.stemReconstruction.upperMaximumError < 0.000_001)
            #expect(Set(block.stemObservations.keys) == Set(MixRole.allCases))
            #expect(abs((block.stemObservations[.kick]?.rms ?? -1) -
                        Double(block.kickMix.audibleRMS)) < 0.000_001)
            for role in MixRole.allCases where role != .kick {
                #expect(block.automaticMix.gainsDB[role] == 0)
                #expect(block.automaticMix.gain(for: role) == 1)
            }
            for observation in block.stemObservations.values {
                #expect(observation.rms.isFinite)
                #expect(observation.activeRMS.isFinite)
                #expect(observation.onsetRMS.isFinite)
                #expect(observation.peak.isFinite)
                #expect(observation.occupancy >= 0 && observation.occupancy <= 1)
                #expect(observation.bandEnergy.values.allSatisfy { $0.isFinite && $0 >= 0 })
            }
            for event in block.events {
                let role: MixRole = switch event.voice {
                case .kick: .kick
                case .bass, .rumble, .tunedTom: .foundation
                case .percussion, .clap, .openHat, .metallic, .groovePulse: .percussion
                case .synth, .lead: .upperTonal
                case .pad, .riser: .atmosphere
                }
                #expect(abs((block.busStates[event.voice]?.level ?? -1) -
                            (block.stemObservations[role]?.rms ?? -2)) < 0.000_001)
            }
        }
    }

    @Test("Sub-gate stems retain internally consistent active evidence")
    func subGateStemEvidence() {
        let observation = StemObservationAnalyzer.analyze(
            [0, 0.000_000_001_1, 0, 0],
            sampleRate: 44_100
        )

        #expect(observation.peak > 0)
        #expect(observation.rms > 0)
        #expect(observation.activeRMS >= observation.rms)
        #expect(observation.activeRMS <= observation.peak)
        #expect(observation.occupancy > 0)
    }

    @Test("Automatic mix trims excessive kick hierarchy without gain drift")
    func automaticMixBounds() {
        func observation(activeRMS: Double, occupancy: Double = 0.5) -> StemObservation {
            StemObservation(
                rms: activeRMS * 0.6,
                activeRMS: activeRMS,
                onsetRMS: activeRMS,
                peak: activeRMS * 1.4,
                crestFactor: 2.3,
                occupancy: occupancy,
                bandEnergy: Dictionary(
                    uniqueKeysWithValues: MixBand.allCases.map { ($0, activeRMS * activeRMS) }
                )
            )
        }
        let excessive: [MixRole: StemObservation] = [
            .kick: observation(activeRMS: 0.50),
            .foundation: observation(activeRMS: 0.01),
        ]
        var state = AutomaticMixState()
        let first = AutomaticMixBalancer.resolve(
            observations: excessive,
            companion: .monoRumble,
            section: .groove,
            state: &state
        )
        #expect(first.gainsDB[.kick] == -2.35)
        #expect(first.measuredKickOverFoundationDB != nil)
        #expect(first.targetKickOverFoundationDB == 27.5)
        #expect(first.sourceKickRMS == excessive[.kick]?.rms)
        #expect(first.sourceKickActiveRMS == excessive[.kick]?.activeRMS)
        #expect(first.residualKickExcessDB != nil)
        #expect(first.kickRelationshipIsResolved == false)

        let beforeBreak = state
        let breakPlan = AutomaticMixBalancer.resolve(
            observations: excessive,
            companion: .monoRumble,
            section: .breakdown,
            state: &state
        )
        #expect(state == beforeBreak)
        #expect(breakPlan.gainsDB[.kick] == beforeBreak.kickCorrectionDB)
        #expect(breakPlan.sourceKickRMS == nil)
        #expect(breakPlan.sourceKickActiveRMS == nil)

        for _ in 0..<1_024 {
            _ = AutomaticMixBalancer.resolve(
                observations: excessive,
                companion: .monoRumble,
                section: .groove,
                state: &state
            )
            #expect(state.kickCorrectionDB >= AutomaticMixBalancer.minimumKickCorrectionDB)
            #expect(state.kickCorrectionDB <= 0)
            #expect(state.kickCorrectionDB.isFinite)
        }
        let measuredDifference = first.measuredKickOverFoundationDB ?? 0
        let targetDifference = first.targetKickOverFoundationDB ?? 0
        #expect(abs(measuredDifference + state.kickCorrectionDB - targetDifference) <=
                AutomaticMixBalancer.deadbandDB)
        let settled = AutomaticMixBalancer.resolve(
            observations: excessive,
            companion: .monoRumble,
            section: .groove,
            state: &state
        )
        #expect(settled.kickRelationshipIsResolved == true)
        let settledCorrection = state.kickCorrectionDB
        for _ in 0..<1_024 {
            _ = AutomaticMixBalancer.resolve(
                observations: excessive,
                companion: .monoRumble,
                section: .groove,
                state: &state
            )
        }
        #expect(state.kickCorrectionDB == settledCorrection)

        let silentFoundation: [MixRole: StemObservation] = [
            .kick: observation(activeRMS: 0.30),
            .foundation: .silent,
        ]
        let held = state
        _ = AutomaticMixBalancer.resolve(
            observations: silentFoundation,
            companion: .empty,
            section: .groove,
            state: &state
        )
        #expect(state == held)

        let calibrationOutlier: [MixRole: StemObservation] = [
            .kick: observation(activeRMS: 0.30),
            .foundation: observation(activeRMS: 0.001),
        ]
        var limitedState = AutomaticMixState()
        var limitedPlan = AutomaticMixPlan.unity
        for _ in 0..<1_024 {
            limitedPlan = AutomaticMixBalancer.resolve(
                observations: calibrationOutlier,
                companion: .bass,
                section: .groove,
                state: &limitedState
            )
        }
        #expect(limitedState.kickCorrectionDB ==
                AutomaticMixBalancer.minimumKickCorrectionDB)
        #expect((limitedPlan.residualKickExcessDB ?? 0) >
                AutomaticMixBalancer.deadbandDB)
        #expect(limitedPlan.kickRelationshipIsResolved == false)
    }

    @Test("Waveform display retains absolute level relationships")
    func waveformUsesFixedDecibelScale() {
        let loud = [Float](repeating: 0.10, count: 640)
        let quiet = [Float](repeating: 0.05, count: 640)
        let loudEnvelope = WaveformEnvelope.fixedDB(left: loud, right: loud, buckets: 10)
        let quietEnvelope = WaveformEnvelope.fixedDB(left: quiet, right: quiet, buckets: 10)
        #expect(loudEnvelope.count == 10)
        #expect(quietEnvelope.count == 10)
        #expect(zip(loudEnvelope, quietEnvelope).allSatisfy { $0.0 > $0.1 })
        #expect(loudEnvelope == WaveformEnvelope.fixedDB(left: loud, right: loud, buckets: 10))
        let silence = [Float](repeating: 0, count: 640)
        #expect(WaveformEnvelope.fixedDB(left: silence, right: silence, buckets: 10)
            .allSatisfy { $0 == 0.04 })
    }

    @Test("Continuation state reproduces successor phrases exactly")
    func continuationReplay() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var sessionA = director.initialState()
        var sessionB = director.initialState()
        let firstA = prepare(state: sessionA, sampleRate: 8_000)
        let firstB = prepare(state: sessionB, sampleRate: 8_000)
        sessionA = sessionA.advance(
            using: firstA.plan,
            quality: firstA.qualityContinuationState,
            liveMasterHeadroom: firstA.liveMasterHeadroomContinuationState
        )
        sessionB = sessionB.advance(
            using: firstB.plan,
            quality: firstB.qualityContinuationState,
            liveMasterHeadroom: firstB.liveMasterHeadroomContinuationState
        )
        let nextA = prepare(
            state: sessionA, sampleRate: 8_000,
            renderState: firstA.endingRenderState,
            graphState: firstA.endingGraphState,
            previousGraph: firstA.graph
        )
        let nextB = prepare(
            state: sessionB, sampleRate: 8_000,
            renderState: firstB.endingRenderState,
            graphState: firstB.endingGraphState,
            previousGraph: firstB.graph
        )
        #expect(nextA.plan == nextB.plan)
        #expect(nextA.graph == nextB.graph)
        #expect(nextA.blocks == nextB.blocks)
        #expect(nextA.endingRenderState == nextB.endingRenderState)
        #expect(nextA.endingGraphState == nextB.endingGraphState)
        let transition = nextA.selectedCandidateEvidence.crossPhraseTransition
        #expect(transition.predecessorAvailable)
        #expect(transition.routeComparable)
        #expect(transition.spatialGeometryRetained)
        #expect(transition.finite)
        #expect(transition.isComplete)
        #expect(transition.hardGateValid)
        #expect(transition.maximumBoundaryDelta <=
                Double(nextA.audioPreflight.quality.maxBoundaryDelta))
        #expect(!transition.spatialTailContinuationRequired ||
                transition.spatialTailContinuationObserved)
        #expect(nextA.blocks.first?.spatialFDNRenderEvidence.geometryRetained ==
                true)
        #expect(nextA.blocks.first?.spatialFDNRenderEvidence.delayFrameCounts ==
                firstA.endingRenderState.spatialFDNState.lineLengths)
    }

    @Test("Different valid topology plans produce audibly distinct sample hashes")
    func topologyDistinction() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let phrase = director.plan(from: state)
        let graphA = DSPGraphGenerator.safePlan(sessionSeed: 42)
        let graphB = DSPGraphPlan(
            sessionSeed: 42, revision: 1,
            nodes: [DSPGraphNode(id: 20, kind: .waveFold, branch: 0, order: 0,
                                amount: 0.88, mix: 0.72)],
            mutation: DSPGraphMutation(kind: .replace, phraseIndex: 0, affectedNodeIDs: [20])
        )
        var renderA = RenderState(), renderB = RenderState()
        var stateA = GeneratedDSPContinuationState(), stateB = GeneratedDSPContinuationState()
        let blocksA = AutonomousPhraseRenderer.render(
            plan: phrase, graph: graphA, sampleRate: 8_000,
            state: &renderA, graphState: &stateA
        )
        let blocksB = AutonomousPhraseRenderer.render(
            plan: phrase, graph: graphB, sampleRate: 8_000,
            state: &renderB, graphState: &stateB
        )
        #expect(AudioQualityReport(blocks: blocksA, sampleRate: 8_000).sampleHash !=
                AudioQualityReport(blocks: blocksB, sampleRate: 8_000).sampleHash)
    }

    @Test("Resolved ensemble events are the audible and reported source of truth")
    func resolvedEventChangesPCMAndMetadata() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let original = director.plan(from: state)
        guard let barIndex = original.resolvedBars.firstIndex(where: { resolved in
            resolved.ensemble.events.contains { $0.voice != .kick }
        }), let target = original.resolvedBars[barIndex].ensemble.events.first(where: {
            $0.voice != .kick
        }) else {
            Issue.record("Expected a non-kick resolved event")
            return
        }
        let sourceResolved = original.resolvedBars[barIndex]
        var events = sourceResolved.ensemble.events
        events.remove(at: events.firstIndex(of: target)!)
        let changedContext = EnsembleContext(
            focusRole: sourceResolved.ensemble.focusRole,
            events: events,
            kickAnchors: sourceResolved.ensemble.kickAnchors,
            intentionalPileup: sourceResolved.ensemble.intentionalPileup
        )
        let changedResolved = ResolvedPerformanceBar(
            performance: sourceResolved.performance,
            ensemble: changedContext,
            arrangementGesture: sourceResolved.arrangementGesture,
            percussionGear: sourceResolved.percussionGear,
            foundationCompanion: sourceResolved.foundationCompanion,
            pulseEchoEnabled: sourceResolved.pulseEchoEnabled,
            interlockChapter: sourceResolved.interlockChapter,
            groovePulses: sourceResolved.groovePulses,
            spatialContrast: sourceResolved.spatialContrast,
            narrative: sourceResolved.narrative,
            kickMorphology: sourceResolved.kickMorphology
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        #expect(AutonomousCandidateFingerprint.plan(original) !=
                AutonomousCandidateFingerprint.plan(changed))

        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )

        #expect(originalBlocks[barIndex].events.count == sourceResolved.ensemble.events.count)
        #expect(changedBlocks[barIndex].events.count == changedContext.events.count)
        #expect(originalBlocks[barIndex].events != changedBlocks[barIndex].events)
        let barFrames = originalBlocks[barIndex].left.count
        let start = min(barFrames - 1, target.step * barFrames / 16)
        let end = min(barFrames, start + max(32, barFrames / 16))
        let windowDelta = zip(
            originalBlocks[barIndex].left[start..<end],
            changedBlocks[barIndex].left[start..<end]
        ).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        #expect(windowDelta > 0.000_1)
    }

    @Test("Changing a relational stage changes its metadata and corresponding PCM window")
    func relationalStageChangesPCMAndMetadata() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let original = director.plan(from: state)
        guard let barIndex = original.resolvedBars.firstIndex(where: { resolved in
            resolved.ensemble.events.contains { $0.voice == .motif }
        }), let event = original.resolvedBars[barIndex].ensemble.events.first(where: {
            $0.voice == .motif
        }) else {
            Issue.record("Expected a resolved motif event")
            return
        }

        let source = original.resolvedBars[barIndex]
        let sourcePhase = RelationalCyclePhase(
            macroStep: (source.performance.bar % 16) * 16 + event.step
        )
        guard let barOffset = (1...15).first(where: { offset in
            RelationalCyclePhase(
                macroStep: ((source.performance.bar + offset) % 16) * 16 + event.step
            ).followerStage != sourcePhase.followerStage
        }) else {
            Issue.record("Expected a distinct follower stage in the macro")
            return
        }
        let performance = source.performance
        let shiftedPerformance = PerformanceBar(
            bar: performance.bar + barOffset,
            phrase: performance.phrase,
            localBar: performance.localBar,
            phraseLength: performance.phraseLength,
            section: performance.section,
            tension: performance.tension,
            roles: performance.roles,
            transformations: performance.transformations,
            signatureEvent: performance.signatureEvent,
            eventSeed: performance.eventSeed,
            accentContour: performance.accentContour
        )
        let changedResolved = ResolvedPerformanceBar(
            performance: shiftedPerformance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickMorphology: source.kickMorphology
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        #expect(AutonomousCandidateFingerprint.plan(original) !=
                AutonomousCandidateFingerprint.plan(changed))
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )

        let originalBlock = originalBlocks[barIndex]
        let changedBlock = changedBlocks[barIndex]
        let originalArticulation = originalBlock.synthPerformance.articulation(at: event.step)
        let changedArticulation = changedBlock.synthPerformance.articulation(at: event.step)
        #expect(originalBlock.events.count == changedBlock.events.count)
        #expect(zip(originalBlock.events, changedBlock.events).allSatisfy { original, changed in
            original.voice == changed.voice && original.step == changed.step &&
                original.intensity == changed.intensity
        })
        #expect(originalArticulation != changedArticulation)
        #expect(originalArticulation.phase.followerStage !=
                changedArticulation.phase.followerStage)
        #expect(originalArticulation.chapter == changedArticulation.chapter)
        let start = event.step * originalBlock.left.count / 16
        let end = min(originalBlock.left.count, start + max(32, originalBlock.left.count / 8))
        let delta = zip(
            originalBlock.left[start..<end], changedBlock.left[start..<end]
        ).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        #expect(delta > 0.000_1)
    }

    @Test("Resolved groove pulse drives metadata, PCM, percussion stem, and no mix decision")
    func groovePulseResolvedRendering() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let original = director.plan(from: state)
        guard let barIndex = original.resolvedBars.firstIndex(where: {
            WeakSixteenthStage(absoluteBar: $0.performance.bar) == .syncopatedLean &&
                $0.arrangementGesture != .minimalize &&
                !$0.groovePulses.isEmpty
        }) else {
            Issue.record("Expected a surviving resolved syncopated-lean pulse")
            return
        }
        let source = original.resolvedBars[barIndex]
        guard let target = source.groovePulses.first(where: { $0.step == 7 }) ??
                source.groovePulses.first else {
            Issue.record("Expected a resolved groove pulse")
            return
        }
        let changedMicrovariation = target.timbreMicrovariation == 0
            ? 0.04 : -target.timbreMicrovariation
        let changedPulse = GroovePulseArticulation(
            step: target.step,
            pulseClass: target.pulseClass,
            stage: target.stage,
            intensity: target.intensity,
            timingOffsetInSteps: target.timingOffsetInSteps,
            strikeZone: target.strikeZone == .edge ? .center : .edge,
            damping: target.damping == 0.75 ? 0.25 : 0.75,
            timbreMicrovariation: changedMicrovariation
        )
        let changedPulses = source.groovePulses.map {
            $0.step == target.step ? changedPulse : $0
        }
        let changedResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationRhythmicRelation: source.foundationRhythmicRelation,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: changedPulses,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickMorphology: source.kickMorphology
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        #expect(AutonomousCandidateFingerprint.plan(original) !=
                AutonomousCandidateFingerprint.plan(changed))

        let intensity = target.intensity == 0.72 ? 0.52 : 0.72
        let intensityEvents = source.ensemble.events.map { event in
            guard event.voice == .groovePulse, event.step == target.step else {
                return event
            }
            return EnsembleResolvedEvent(
                voice: event.voice,
                step: event.step,
                intensity: intensity,
                relocated: event.relocated
            )
        }
        let intensityPulses = source.groovePulses.map { pulse in
            GroovePulseArticulation(
                step: pulse.step,
                pulseClass: pulse.pulseClass,
                stage: pulse.stage,
                intensity: pulse.step == target.step ? intensity : pulse.intensity,
                timingOffsetInSteps: pulse.timingOffsetInSteps,
                strikeZone: pulse.strikeZone,
                damping: pulse.damping,
                timbreMicrovariation: pulse.timbreMicrovariation
            )
        }
        let intensityPulse = intensityPulses.first { $0.step == target.step }
        let intensityResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: EnsembleContext(
                focusRole: source.ensemble.focusRole,
                events: intensityEvents,
                kickAnchors: source.ensemble.kickAnchors,
                intentionalPileup: source.ensemble.intentionalPileup
            ),
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationRhythmicRelation: source.foundationRhythmicRelation,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: intensityPulses,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickMorphology: source.kickMorphology
        )
        var intensityBars = original.resolvedBars
        intensityBars[barIndex] = intensityResolved
        let intensityChanged = replacingResolvedBars(
            in: original,
            with: intensityBars,
            memory: state.memory
        )
        #expect(AutonomousCandidateFingerprint.plan(original) !=
                AutonomousCandidateFingerprint.plan(intensityChanged))
        #expect(target.step == intensityPulse?.step)
        #expect(target.timingOffsetInSteps == intensityPulse?.timingOffsetInSteps)
        #expect(target.strikeZone == intensityPulse?.strikeZone)
        #expect(target.damping == intensityPulse?.damping)
        #expect(target.timbreMicrovariation == intensityPulse?.timbreMicrovariation)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var intensityRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        var intensityGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )
        let intensityBlocks = AutonomousPhraseRenderer.render(
            plan: intensityChanged, graph: graph, sampleRate: 8_000,
            state: &intensityRender, graphState: &intensityGraph
        )
        let originalBlock = originalBlocks[barIndex]
        let changedBlock = changedBlocks[barIndex]
        let intensityBlock = intensityBlocks[barIndex]
        let originalEvent = originalBlock.events.first {
            $0.voice == .groovePulse && $0.step == target.step
        }
        let changedEvent = changedBlock.events.first {
            $0.voice == .groovePulse && $0.step == target.step
        }
        #expect(originalEvent?.pulseClass == target.pulseClass)
        #expect(originalEvent?.timingOffsetInSteps == target.timingOffsetInSteps)
        #expect(originalEvent?.intensity == target.intensity)
        #expect(changedEvent?.intensity == changedPulse.intensity)
        #expect(originalBlock.events.filter {
            !($0.voice == .groovePulse && $0.step == target.step)
        } == changedBlock.events.filter {
            !($0.voice == .groovePulse && $0.step == target.step)
        })
        let start = Int((Double(target.step) + target.timingOffsetInSteps) *
                        Double(originalBlock.left.count) / 16.0)
        let end = min(originalBlock.left.count, start + Int(8_000 * 0.12))
        let windowDelta = zip(
            originalBlock.left[start..<end], changedBlock.left[start..<end]
        ).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        #expect(windowDelta > 0.000_1)
        #expect(originalBlock.automaticMix == changedBlock.automaticMix)
        #expect(originalBlock.stemObservations[.kick] == changedBlock.stemObservations[.kick])
        #expect(originalBlock.stemObservations[.foundation] ==
                changedBlock.stemObservations[.foundation])
        #expect(originalBlock.stemObservations[.percussion] !=
                changedBlock.stemObservations[.percussion])
        #expect(originalBlock.protectedFoundationSampleHash ==
                changedBlock.protectedFoundationSampleHash)
        #expect(originalBlock.percussionSampleHash != changedBlock.percussionSampleHash)
        #expect(originalBlock.protectedRhythmSampleHash !=
                changedBlock.protectedRhythmSampleHash)
        let originalPulseEvidence = originalBlock.groovePulseRenderEvidence.first {
            $0.step == target.step
        }
        let changedPulseEvidence = changedBlock.groovePulseRenderEvidence.first {
            $0.step == target.step
        }
        #expect(originalPulseEvidence?.sampleHash != changedPulseEvidence?.sampleHash)
        #expect(originalPulseEvidence?.strikeZone == target.strikeZone)
        #expect(changedPulseEvidence?.strikeZone == changedPulse.strikeZone)
        #expect(originalPulseEvidence?.damping == target.damping)
        #expect(changedPulseEvidence?.damping == changedPulse.damping)
        #expect(originalPulseEvidence?.finite == true)
        #expect(changedPulseEvidence?.finite == true)
        #expect(originalBlock.groovePulseRenderEvidence.filter {
            $0.step != target.step
        } == changedBlock.groovePulseRenderEvidence.filter {
            $0.step != target.step
        })
        #expect(originalBlock.busStates[.groovePulse]?.level ==
                originalBlock.stemObservations[.percussion]?.rms)

        let intensityEvent = intensityBlock.events.first {
            $0.voice == .groovePulse && $0.step == target.step
        }
        let intensityEvidence = intensityBlock.groovePulseRenderEvidence.first {
            $0.step == target.step
        }
        #expect(intensityEvent?.intensity == intensity)
        #expect(Array(originalBlocks[..<barIndex]) ==
                Array(intensityBlocks[..<barIndex]))
        #expect(originalBlock.events.filter {
            $0.voice != .groovePulse
        } == intensityBlock.events.filter {
            $0.voice != .groovePulse
        })
        let originalGrooveEvents = originalBlock.events.filter {
            $0.voice == .groovePulse
        }
        let intensityChangedGrooveEvents = intensityBlock.events.filter {
            $0.voice == .groovePulse
        }
        #expect(originalGrooveEvents.map(\.step) == intensityChangedGrooveEvents.map(\.step))
        #expect(zip(originalGrooveEvents, intensityChangedGrooveEvents).allSatisfy {
            $0.pulseClass == $1.pulseClass &&
                $0.timingOffsetInSteps == $1.timingOffsetInSteps
        })
        #expect(originalBlock.automaticMix == intensityBlock.automaticMix)
        #expect(originalBlock.stemObservations[.kick] ==
                intensityBlock.stemObservations[.kick])
        #expect(originalBlock.stemObservations[.foundation] ==
                intensityBlock.stemObservations[.foundation])
        #expect(originalBlock.protectedFoundationSampleHash ==
                intensityBlock.protectedFoundationSampleHash)
        #expect(originalBlock.percussionSampleHash != intensityBlock.percussionSampleHash)
        #expect(originalBlock.protectedRhythmSampleHash !=
                intensityBlock.protectedRhythmSampleHash)
        #expect(originalPulseEvidence?.sampleHash != intensityEvidence?.sampleHash)
        #expect(originalPulseEvidence?.rms != intensityEvidence?.rms)
        #expect(originalPulseEvidence?.strikeZone == intensityEvidence?.strikeZone)
        #expect(originalPulseEvidence?.damping == intensityEvidence?.damping)
        #expect(originalPulseEvidence?.timbreMicrovariation ==
                intensityEvidence?.timbreMicrovariation)
        let originalCellEvidence = originalBlock.groovePulseRenderEvidence
        let intensityCellEvidence = intensityBlock.groovePulseRenderEvidence
        #expect(originalCellEvidence.map(\.step) == intensityCellEvidence.map(\.step))
        let changedIntensitySteps = zip(
            originalCellEvidence, intensityCellEvidence
        ).compactMap { original, changed in
            original.intensity == changed.intensity ? nil : original.step
        }
        #expect(changedIntensitySteps == [target.step])
        #expect(zip(originalCellEvidence, intensityCellEvidence).allSatisfy {
            $0.pulseClass == $1.pulseClass &&
                $0.stage == $1.stage &&
                $0.timingOffsetInSteps == $1.timingOffsetInSteps &&
                $0.strikeZone == $1.strikeZone &&
                $0.damping == $1.damping &&
                $0.timbreMicrovariation == $1.timbreMicrovariation
        })
        #expect(zip(originalCellEvidence, intensityCellEvidence).allSatisfy {
            let intensityChanged = $0.intensity != $1.intensity
            return ($0.sampleHash != $1.sampleHash) == intensityChanged &&
                ($0.rms != $1.rms) == intensityChanged
        })
    }

    @Test("Selective depth resolves once per macro and continues deterministically")
    func selectiveSpatialDepthResolution() {
        func expectedDepth(
            kind: AutonomousPhraseKind,
            gesture: ArrangementGesture,
            relationship: LongHorizonEnergyRelationship
        ) -> (voices: [EnsembleVoice], send: Double)? {
            switch relationship {
            case .lower, .home:
                return nil
            case .hold:
                return switch (kind, gesture) {
                case (.contrast, .turnaround): ([.response, .transition], 0.22)
                case (.majorBreak, .structuralMarker): ([.transition, .atmosphere], 0.30)
                default: nil
                }
            case .raise, .change:
                guard gesture == .gearShift || gesture == .turnaround ||
                        gesture == .structuralMarker else { return nil }
                return relationship == .raise
                    ? ([.atmosphere, .transition, .response], 0.30)
                    : ([.response, .atmosphere, .transition], 0.24)
            }
        }

        func journey() -> [SpatialContrastArticulation] {
            let director = AutonomousSessionDirector()
            var state = director.initialState()
            var articulations: [SpatialContrastArticulation] = []
            var carriersPerMacro: [Int: Int] = [:]
            var previousCarrier: EnsembleVoice?
            var sawContrastCarrier = false
            var sawBreakCarrier = false
            var sawCoordinatedCarrier = false

            for _ in 0..<80 {
                let plan = director.plan(from: state)
                let relationship = plan.longHorizonEnergyCoordination.target.spatialDistance
                for resolved in plan.resolvedBars {
                    let spatial = resolved.spatialContrast
                    articulations.append(spatial)
                    let expected = expectedDepth(
                        kind: plan.kind,
                        gesture: resolved.arrangementGesture,
                        relationship: relationship
                    )
                    if expected == nil {
                        #expect(spatial == .foreground)
                    }
                    guard spatial.depthPosition == .distant else { continue }
                    guard let expected else {
                        Issue.record("Unexpected distant carrier without an eligible relationship")
                        continue
                    }
                    let macro = resolved.performance.bar / 16
                    carriersPerMacro[macro, default: 0] += 1
                    #expect(carriersPerMacro[macro] == 1)
                    #expect(spatial.dryScale == 0.72)
                    #expect(spatial.highPassHz == 300)
                    #expect(spatial.lowPassHz == 4_200)
                    #expect(spatial.carrierVoice != .kick)
                    #expect(spatial.carrierVoice != .bass)
                    #expect(spatial.carrierVoice != .percussion)
                    #expect(spatial.carrierVoice != .groovePulse)
                    #expect(resolved.ensemble.events.contains { spatial.applies(to: $0) })
                    #expect(spatial.reverbSend == expected.send)
                    #expect(spatial.carrierVoice.map(expected.voices.contains) == true)

                    if relationship == .hold, plan.kind == .contrast {
                        sawContrastCarrier = true
                    } else if relationship == .hold, plan.kind == .majorBreak {
                        sawBreakCarrier = true
                    } else if relationship == .raise || relationship == .change {
                        sawCoordinatedCarrier = true
                    }

                    if let previousCarrier {
                        let hasAlternative = resolved.ensemble.events.contains {
                            $0.voice != previousCarrier && expected.voices.contains($0.voice)
                        }
                        if hasAlternative { #expect(spatial.carrierVoice != previousCarrier) }
                    }
                    previousCarrier = spatial.carrierVoice
                }
                state.advancePlanning(using: plan)
            }
            #expect(sawContrastCarrier)
            #expect(sawBreakCarrier)
            #expect(sawCoordinatedCarrier)
            #expect(carriersPerMacro.values.allSatisfy { $0 == 1 })
            return articulations
        }

        let first = journey()
        #expect(first == journey())
    }

    @Test("Resolved spatial carrier drives matching metadata and its PCM window")
    func selectiveSpatialDepthRendering() {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var matched: (AutonomousSessionState, AutonomousPhrasePlan, Int)?
        for _ in 0..<80 where matched == nil {
            let plan = director.plan(from: state)
            if let barIndex = plan.resolvedBars.firstIndex(where: {
                $0.spatialContrast.depthPosition == .distant
            }) {
                matched = (state, plan, barIndex)
            } else {
                state.advancePlanning(using: plan)
            }
        }
        guard let (sourceState, original, barIndex) = matched else {
            Issue.record("Expected a deterministic selective spatial carrier")
            return
        }

        let source = original.resolvedBars[barIndex]
        guard let carrierStep = source.spatialContrast.carrierStep else {
            Issue.record("Expected the distant carrier to retain its resolved step")
            return
        }
        let dryResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            spatialContrast: .foreground,
            narrative: source.narrative,
            kickMorphology: source.kickMorphology
        )
        var dryBars = original.resolvedBars
        dryBars[barIndex] = dryResolved
        let dry = replacingResolvedBars(in: original, with: dryBars, memory: sourceState.memory)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: sourceState.rootSeed)
        var distantRender = RenderState(), dryRender = RenderState()
        var distantGraph = GeneratedDSPContinuationState()
        var dryGraph = GeneratedDSPContinuationState()
        let distantBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &distantRender, graphState: &distantGraph
        )
        let dryBlocks = AutonomousPhraseRenderer.render(
            plan: dry, graph: graph, sampleRate: 8_000,
            state: &dryRender, graphState: &dryGraph
        )

        #expect(Array(distantBlocks[..<barIndex]) == Array(dryBlocks[..<barIndex]))
        let distantBlock = distantBlocks[barIndex]
        let dryBlock = dryBlocks[barIndex]
        let distantEvent = distantBlock.events.first {
            $0.step == carrierStep && $0.spatialDepthPosition == .distant
        }
        #expect(distantEvent?.spatialReverbSend == source.spatialContrast.reverbSend)
        #expect(dryBlock.events.allSatisfy {
            $0.spatialDepthPosition == .foreground && $0.spatialReverbSend == 0
        })
        #expect(zip(distantBlock.events, dryBlock.events).allSatisfy { distant, foreground in
            distant.voice == foreground.voice && distant.step == foreground.step &&
                distant.intensity == foreground.intensity
        })
        #expect(distantBlock.automaticMix == dryBlock.automaticMix)
        #expect(distantBlock.stemObservations[.kick] == dryBlock.stemObservations[.kick])
        #expect(distantBlock.stemObservations[.foundation] ==
                dryBlock.stemObservations[.foundation])

        let start = carrierStep * distantBlock.left.count / 16
        #expect(Array(distantBlock.left[..<start]) == Array(dryBlock.left[..<start]))
        let delta = zip(distantBlock.left[start...], dryBlock.left[start...]).reduce(0.0) {
            $0 + abs(Double($1.0 - $1.1))
        }
        #expect(delta > 0.000_1)
    }

    @Test("Narrative presence and support evolve continuously at structural boundaries")
    func narrativeEvolutionAndSupportGating() {
        func expectedNarrativeTrajectory(
            initialPresence: Double,
            settlementPending: Bool,
            kind: AutonomousPhraseKind,
            startBar: Int,
            length: Int,
            relationship: LongHorizonEnergyRelationship
        ) -> (endpoints: [Double], settlementPending: Bool) {
            var endpoints: [Double] = []
            var pending = false
            if kind == .energyRelease {
                let peakIndex = (0..<length).first {
                    (startBar + $0 + 1).isMultiple(of: 16)
                } ?? (length - 1)
                for index in 0...peakIndex {
                    let progress = Double(index + 1) / Double(peakIndex + 1)
                    endpoints.append(initialPresence + (0.90 - initialPresence) * progress)
                }
                let settlingBars = length - peakIndex - 1
                if settlingBars > 0 {
                    for settlingIndex in 1...settlingBars {
                        let progress = Double(settlingIndex) / Double(settlingBars)
                        endpoints.append(0.90 + (0.60 - 0.90) * progress)
                    }
                }
                pending = settlingBars == 0
            } else {
                let target: Double = switch kind {
                case .lock: 0.56
                case .contrast: 0.76
                case .majorBreak: 0.20
                case .identityReturn: 0.58
                case .energyRelease: 0.60
                }
                if settlementPending {
                    endpoints.append(0.60)
                    let remainingBars = length - 1
                    if remainingBars > 0 {
                        for index in 1..<length {
                            let progress = Double(index) / Double(remainingBars)
                            endpoints.append(0.60 + (target - 0.60) * progress)
                        }
                    }
                } else {
                    for index in 0..<length {
                        let progress = Double(index + 1) / Double(length)
                        endpoints.append(initialPresence + (target - initialPresence) * progress)
                    }
                }
            }

            guard relationship != .hold else { return (endpoints, pending) }
            let changeDirection = initialPresence >= 0.5 ? -1.0 : 1.0
            var previous = min(0.92, max(0.12, initialPresence))
            let coordinated = endpoints.enumerated().map { index, endpoint in
                let progress = Double(index + 1) / Double(endpoints.count)
                let value: Double = switch relationship {
                case .hold: endpoint
                case .lower: endpoint - 0.12 * progress
                case .raise: endpoint + 0.12 * progress
                case .change: endpoint + changeDirection * 0.10 * progress
                case .home: endpoint + (0.58 - endpoint) * progress
                }
                let bounded = min(0.92, max(0.12, value))
                let slewed = min(previous + 0.16, max(previous - 0.16, bounded))
                previous = slewed
                return slewed
            }
            return (coordinated, pending)
        }

        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var previousPresence = 0.50
        var previousContext: (roles: [PerformanceRole], gesture: ArrangementGesture,
                              direction: NarrativeDirection, kind: AutonomousPhraseKind)?
        var observedKinds = Set<AutonomousPhraseKind>()
        var sawSupportAdmission = false
        var sawSupportRemoval = false

        for _ in 0..<80 {
            let plan = director.plan(from: state)
            observedKinds.insert(plan.kind)
            let expectedTrajectory = expectedNarrativeTrajectory(
                initialPresence: previousPresence,
                settlementPending: state.memory.narrativeEvolution.releaseSettlementPending,
                kind: plan.kind,
                startBar: plan.startBar,
                length: plan.barCount,
                relationship:
                    plan.longHorizonEnergyCoordination.target.protagonistPresence
            )
            #expect(abs((plan.resolvedBars.first?.narrative.presenceStart ?? -1) -
                        previousPresence) < 0.000_000_1)

            for (barIndex, resolved) in plan.resolvedBars.enumerated() {
                let narrative = resolved.narrative
                #expect((0...1).contains(narrative.presenceStart))
                #expect((0...1).contains(narrative.presenceEnd))
                #expect(abs(narrative.presenceEnd - expectedTrajectory.endpoints[barIndex]) <
                        0.000_000_1)
                #expect(resolved.performance.roles.contains(.foundation))
                if plan.kind != .majorBreak {
                    #expect(resolved.performance.roles.contains(.motif))
                } else {
                    #expect(narrative.activeSupportingRoles == [.atmosphere])
                    #expect(!resolved.performance.roles.contains(.percussion))
                    #expect(!resolved.performance.roles.contains(.response))
                }
                #expect(narrative.activeSupportingRoles.count <= 3)

                if let previousContext,
                   previousContext.roles != narrative.activeSupportingRoles {
                    let previousSet = Set(previousContext.roles)
                    let currentSet = Set(narrative.activeSupportingRoles)
                    let changedCount = previousSet.symmetricDifference(currentSet).count
                    let phraseBoundary = resolved.performance.localBar == 0
                    if phraseBoundary {
                        #expect(changedCount <= 3)
                    } else {
                        #expect(changedCount == 1)
                        #expect(resolved.performance.bar.isMultiple(of: 4))
                    }
                    if currentSet.count > previousSet.count, !phraseBoundary {
                        sawSupportAdmission = true
                        #expect(previousContext.gesture != .minimalize)
                        #expect(previousContext.direction == .emerging ||
                                previousContext.kind == .contrast ||
                                previousContext.kind == .energyRelease ||
                                previousContext.kind == .identityReturn)
                    } else if currentSet.count < previousSet.count, !phraseBoundary {
                        sawSupportRemoval = true
                        #expect(previousContext.direction == .receding)
                        #expect(previousContext.gesture == .turnaround)
                    }
                }

                previousPresence = narrative.presenceEnd
                previousContext = (
                    narrative.activeSupportingRoles,
                    resolved.arrangementGesture,
                    narrative.direction,
                    plan.kind
                )
            }

            #expect(plan.endingNarrativeState.releaseSettlementPending ==
                    expectedTrajectory.settlementPending)
            #expect(plan.endingNarrativeState.activeSupportingRoles.count <= 3)
            #expect(abs(plan.endingNarrativeState.protagonistPresence - previousPresence) <
                    0.000_000_1)
            state.advancePlanning(using: plan)
        }

        #expect(observedKinds == Set(AutonomousPhraseKind.allCases))
        #expect(sawSupportAdmission)
        #expect(sawSupportRemoval)
    }

    @Test("Resolved narrative articulation drives motif metadata and PCM only")
    func narrativeRenderingTruth() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()
        let original = director.plan(from: state)
        guard let barIndex = original.resolvedBars.firstIndex(where: { resolved in
            resolved.ensemble.events.contains { $0.voice == .motif }
        }), let motif = original.resolvedBars[barIndex].ensemble.events
            .filter({ $0.voice == .motif }).min(by: { $0.step < $1.step }) else {
            Issue.record("Expected a resolved dominant motif")
            return
        }
        let source = original.resolvedBars[barIndex]
        let changedNarrative = NarrativeArticulation(
            presenceStart: 0.90,
            presenceEnd: 0.90,
            activeSupportingRoles: source.narrative.activeSupportingRoles
        )
        let changedResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationRhythmicRelation: source.foundationRhythmicRelation,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations:
                source.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            modalPercussionArticulations:
                source.modalPercussionArticulations,
            spatialContrast: source.spatialContrast,
            narrative: changedNarrative,
            kickSyntaxRole: source.kickSyntaxRole,
            climaxHang: source.climaxHang,
            percussionEchoTexture: source.percussionEchoTexture,
            harmonicDisclosureRelationship:
                source.harmonicDisclosureRelationship,
            kickMorphology: source.kickMorphology
        )
        var changedBars = original.resolvedBars
        changedBars[barIndex] = changedResolved
        let changed = replacingResolvedBars(in: original, with: changedBars, memory: state.memory)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var originalRender = RenderState(), changedRender = RenderState()
        var originalGraph = GeneratedDSPContinuationState()
        var changedGraph = GeneratedDSPContinuationState()
        let originalBlocks = AutonomousPhraseRenderer.render(
            plan: original, graph: graph, sampleRate: 8_000,
            state: &originalRender, graphState: &originalGraph
        )
        let changedBlocks = AutonomousPhraseRenderer.render(
            plan: changed, graph: graph, sampleRate: 8_000,
            state: &changedRender, graphState: &changedGraph
        )

        #expect(Array(originalBlocks[..<barIndex]) == Array(changedBlocks[..<barIndex]))
        let originalBlock = originalBlocks[barIndex]
        let changedBlock = changedBlocks[barIndex]
        let originalEvent = originalBlock.events.first {
            $0.step == motif.step && $0.narrativePresence != nil
        }
        let changedEvent = changedBlock.events.first {
            $0.step == motif.step && $0.narrativePresence != nil
        }
        #expect(originalEvent?.narrativePresence == source.narrative.presence(atStep: motif.step))
        #expect(changedEvent?.narrativeDirection == .holding)
        #expect(changedEvent?.narrativePresence == 0.90)
        #expect(changedEvent?.narrativeGainScale ==
                changedNarrative.motifGainScale(atStep: motif.step))
        #expect(changedEvent?.narrativeSpectralScale ==
                changedNarrative.motifSpectralScale(atStep: motif.step))
        #expect(zip(originalBlock.events, changedBlock.events).allSatisfy { original, changed in
            original.voice == changed.voice && original.step == changed.step &&
                original.intensity == changed.intensity
        })
        #expect(changedBlock.events.filter { $0.narrativePresence != nil }.allSatisfy {
            $0.voice == .synth
        })
        #expect(originalBlock.synthWorld.motifFingerprint ==
                changedBlock.synthWorld.motifFingerprint)
        #expect(originalBlock.automaticMix == changedBlock.automaticMix)
        #expect(originalBlock.stemObservations[.kick] == changedBlock.stemObservations[.kick])
        #expect(originalBlock.stemObservations[.foundation] ==
                changedBlock.stemObservations[.foundation])
        #expect(originalBlock.stemObservations[.percussion] ==
                changedBlock.stemObservations[.percussion])
        #expect(originalBlock.stemObservations[.upperTonal] !=
                changedBlock.stemObservations[.upperTonal])

        let delta = zip(originalBlock.left, changedBlock.left).reduce(0.0) {
            $0 + abs(Double($1.0 - $1.1))
        }
        #expect(delta > 0.000_1)
    }

    @Test("Tone spectral sculpture reports and renders one complementary source")
    func toneSpectralRenderingTruth() {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var matched: (AutonomousSessionState, AutonomousPhrasePlan, Int,
                      EnsembleResolvedEvent)?
        for _ in 0..<80 where matched == nil {
            let plan = director.plan(from: state)
            let synth = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars
            )
            let candidates = plan.resolvedBars.indices.compactMap { index ->
                (Int, EnsembleResolvedEvent, Double)? in
                let resolved = plan.resolvedBars[index]
                let arpeggiatorEligible = resolved.performanceCharacter == .melodicGlow
                    || resolved.performanceCharacter == .acidPressure
                    || resolved.performanceCharacter == .peakDrive
                guard !arpeggiatorEligible,
                      resolved.interlockChapter == .tone,
                      let motif = resolved.ensemble.events.first(where: {
                          $0.voice == .motif
                      }) else { return nil }
                let articulation = synth.bars[index].articulation(at: motif.step)
                guard articulation.spectralAperture > 0.25,
                      abs(articulation.anchorSpectralScale - 1) > 0.005 else { return nil }
                return (index, motif, articulation.spectralAperture)
            }
            if let selected = candidates.max(by: { $0.2 < $1.2 }) {
                matched = (state, plan, selected.0, selected.1)
            } else {
                state.advancePlanning(using: plan)
            }
        }
        guard let (sourceState, original, barIndex, motif) = matched else {
            Issue.record("Expected a tone-chapter motif inside the spectral aperture")
            return
        }

        let source = original.resolvedBars[barIndex]
        let neutralResolved = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationRhythmicRelation:
                source.foundationRhythmicRelation,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: .home,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations:
                source.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            modalPercussionArticulations:
                source.modalPercussionArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: source.kickSyntaxRole,
            climaxHang: source.climaxHang,
            percussionEchoTexture: source.percussionEchoTexture,
            harmonicDisclosureRelationship:
                source.harmonicDisclosureRelationship,
            kickMorphology: source.kickMorphology
        )
        var neutralBars = original.resolvedBars
        neutralBars[barIndex] = neutralResolved
        let neutral = replacingResolvedBars(
            in: original,
            with: neutralBars,
            memory: sourceState.memory
        )
        let graph = DSPGraphGenerator.safePlan(sessionSeed: sourceState.rootSeed)
        var sculptedRender = RenderState(), neutralRender = RenderState()
        var sculptedGraph = GeneratedDSPContinuationState()
        var neutralGraph = GeneratedDSPContinuationState()
        let sculptedBlocks = AutonomousPhraseRenderer.render(
            plan: original,
            graph: graph,
            sampleRate: 8_000,
            state: &sculptedRender,
            graphState: &sculptedGraph
        )
        let neutralBlocks = AutonomousPhraseRenderer.render(
            plan: neutral,
            graph: graph,
            sampleRate: 8_000,
            state: &neutralRender,
            graphState: &neutralGraph
        )

        #expect(Array(sculptedBlocks[..<barIndex]) == Array(neutralBlocks[..<barIndex]))
        let sculptedBlock = sculptedBlocks[barIndex]
        let neutralBlock = neutralBlocks[barIndex]
        let articulation = sculptedBlock.synthPerformance.articulation(at: motif.step)
        let sculptedEvent = sculptedBlock.events.first {
            $0.step == motif.step && $0.narrativePresence != nil
        }
        let neutralEvent = neutralBlock.events.first {
            $0.step == motif.step && $0.narrativePresence != nil
        }
        #expect(sculptedEvent?.spectralAperture == articulation.spectralAperture)
        #expect(sculptedEvent?.anchorSpectralScale == articulation.anchorSpectralScale)
        #expect(sculptedEvent?.complementarySpectralScale ==
                articulation.complementarySpectralScale)
        #expect(sculptedEvent?.bandPassBlend == articulation.bandPassBlend)
        let narrativeScale = source.narrative.motifSpectralScale(atStep: motif.step)
        let expectedCombined = MotifSpectralSculpture.combinedMultiplier(
            narrativeScale: narrativeScale,
            anchorScale: articulation.anchorSpectralScale
        )
        #expect(sculptedEvent?.motifSpectralMultiplier == expectedCombined)
        #expect(neutralEvent?.spectralAperture == 0)
        #expect(neutralEvent?.anchorSpectralScale == 1)
        #expect(neutralEvent?.complementarySpectralScale == 1)
        #expect(neutralEvent?.bandPassBlend == 0)
        #expect(MotifSpectralSculpture.combinedMultiplier(
            narrativeScale: 0.50,
            anchorScale: 0.50
        ) == 0.84)
        #expect(MotifSpectralSculpture.combinedMultiplier(
            narrativeScale: 2.0,
            anchorScale: 2.0
        ) == 1.16)
        #expect(zip(sculptedBlock.events, neutralBlock.events).allSatisfy { sculpted, plain in
            sculpted.voice == plain.voice && sculpted.step == plain.step &&
                sculpted.intensity == plain.intensity
        })
        #expect(sculptedBlock.synthPerformance.upperNotes(for: .shadow).map(\.onsetStep) ==
                neutralBlock.synthPerformance.upperNotes(for: .shadow).map(\.onsetStep))
        #expect(sculptedBlock.synthWorld.motifFingerprint ==
                neutralBlock.synthWorld.motifFingerprint)
        #expect(sculptedBlock.automaticMix == neutralBlock.automaticMix)
        #expect(sculptedBlock.stemObservations[.kick] == neutralBlock.stemObservations[.kick])
        #expect(sculptedBlock.stemObservations[.foundation] ==
                neutralBlock.stemObservations[.foundation])
        #expect(sculptedBlock.stemObservations[.percussion] ==
                neutralBlock.stemObservations[.percussion])
        #expect(sculptedBlock.stemObservations[.atmosphere] ==
                neutralBlock.stemObservations[.atmosphere])
        #expect(sculptedBlock.stemObservations[.upperTonal] !=
                neutralBlock.stemObservations[.upperTonal])

        let sculptedUpperOnsets = [SynthRole.anchor, .shadow, .response]
            .flatMap { sculptedBlock.synthPerformance.upperNotes(for: $0) }
            .map(\.onsetStep)
        let neutralUpperOnsets = [SynthRole.anchor, .shadow, .response]
            .flatMap { neutralBlock.synthPerformance.upperNotes(for: $0) }
            .map(\.onsetStep)
        #expect(sculptedUpperOnsets == neutralUpperOnsets)
        let earliestAffectedStep = sculptedUpperOnsets.min() ?? motif.step
        let start = earliestAffectedStep * sculptedBlock.left.count / 16
        #expect(Array(sculptedBlock.left[..<start]) == Array(neutralBlock.left[..<start]))
        let delta = zip(sculptedBlock.left[start...], neutralBlock.left[start...]).reduce(0.0) {
            $0 + abs(Double($1.0 - $1.1))
        }
        #expect(delta > 0.000_1)
    }

    @Test("Groove pulse carrier is deterministic, mono, short, and low-cut")
    func groovePulseCarrierSignal() {
        let sampleRate = 44_100.0
        let start = 97
        let count = Int(sampleRate * 0.09)
        func articulation(intensity: Double) -> GroovePulseArticulation {
            GroovePulseArticulation(
                step: 7,
                pulseClass: .trailingWeak,
                stage: .contour,
                intensity: intensity,
                timingOffsetInSteps: 0.08,
                strikeZone: .middle,
                damping: 0.5,
                timbreMicrovariation: 0
            )
        }
        func render(intensity: Double) -> ([Float], GroovePulseRenderEvidence?) {
            var output = [Float](repeating: 0, count: count)
            var measurement = [Float](repeating: 0, count: count)
            let evidence = GroovePulseVoice.render(
                &output, measurement: &measurement,
                start: start, sampleRate: sampleRate,
                articulation: articulation(intensity: intensity), seed: 48_291
            )
            #expect(output == measurement)
            return (output, evidence)
        }
        func legacyRender(intensity: Double) -> [Float] {
            var output = [Float](repeating: 0, count: count)
            let frames = min(Int(sampleRate * 0.045), output.count - start)
            var random = SeededGenerator(seed: 48_291)
            var highPassState = 0.0
            var lowPassState = 0.0
            let highPassCoefficient = min(
                0.35,
                1 - exp(-2 * .pi * 550 / sampleRate)
            )
            let lowPassCoefficient = min(
                0.55,
                1 - exp(-2 * .pi * 3_200 / sampleRate)
            )
            for index in 0..<frames {
                let time = Double(index) / sampleRate
                let noise = random.unit() * 2 - 1
                highPassState += (noise - highPassState) * highPassCoefficient
                let highPassed = noise - highPassState
                let mutedClick = sin(2 * .pi * 1_180 * time) *
                    exp(-time * 145) * 0.24
                lowPassState += (highPassed * 0.78 + mutedClick - lowPassState) *
                    lowPassCoefficient
                let attack = min(1, time / 0.0008)
                let envelope = attack * exp(-time * 72)
                output[start + index] += Float(
                    tanh(lowPassState * 1.16) * envelope * 0.045 * intensity
                )
            }
            return output
        }
        let (left, evidence) = render(intensity: 0.72)
        let (right, replayEvidence) = render(intensity: 0.72)
        let (quieter, quieterEvidence) = render(intensity: 0.30)
        #expect(left == right)
        #expect(left == legacyRender(intensity: 0.72))
        #expect(evidence == replayEvidence)
        #expect(left != quieter)
        #expect((evidence?.rms ?? 0) > (quieterEvidence?.rms ?? 0))
        #expect(evidence?.sampleHash != quieterEvidence?.sampleHash)
        #expect(abs((evidence?.spectralCentroidHz ?? 0) -
                    (quieterEvidence?.spectralCentroidHz ?? 0)) < 0.001)
        #expect(abs((evidence?.tailToAttackDB ?? 0) -
                    (quieterEvidence?.tailToAttackDB ?? 0)) < 0.001)
        #expect(left[..<start].allSatisfy { $0 == 0 })
        let expectedEnd = start + Int(sampleRate * GroovePulseVoice.durationSeconds)
        #expect(left[expectedEnd...].allSatisfy { $0 == 0 })
        #expect(left.contains { abs($0) > 0.000_001 })
        let delta = zip(left, quieter).map { Double($0.0 - $0.1) }
        #expect(delta[..<start].allSatisfy { $0 == 0 })
        #expect(delta[expectedEnd...].allSatisfy { $0 == 0 })

        var low = 0.0
        let coefficient = 1 - exp(-2 * Double.pi * 300 / sampleRate)
        var lowEnergy = 0.0
        var totalEnergy = 0.0
        for sample in left {
            let value = Double(sample)
            low += (value - low) * coefficient
            lowEnergy += low * low
            totalEnergy += value * value
        }
        #expect(lowEnergy / max(totalEnergy, 0.000_000_1) < 0.12)
        #expect(GroovePulseVoice.baseLevel == 0.045)
        #expect(GroovePulseVoice.highPassFrequency == 550)
        #expect(GroovePulseVoice.lowPassFrequency == 3_200)
        #expect(evidence?.appliedHighPassHz == 550)
        #expect(evidence?.appliedLowPassHz == 3_200)
        #expect(evidence?.appliedClickHz == 1_180)
        #expect(evidence?.appliedEnvelopeDecay == 72)
        #expect(evidence?.appliedClickDecay == 145)
        #expect(evidence?.renderedFrameCount == Int(sampleRate * 0.045))
        #expect(evidence?.sampleHash.isEmpty == false)
        #expect(evidence?.finite == true)
        let bandEnergyRatioSum: Double =
            (evidence?.lowBandEnergyRatio ?? 0) +
            (evidence?.midBandEnergyRatio ?? 0) +
            (evidence?.highBandEnergyRatio ?? 0)
        #expect(abs(bandEnergyRatioSum - 1) < 0.000_001)
    }

    @Test("Groove pulse physical articulation has bounded causal evidence across rates")
    func groovePulsePhysicalArticulationEvidence() throws {
        let sampleRates = [8_000.0, 44_100.0, 48_000.0, 96_000.0, 192_000.0]
        for sampleRate in sampleRates {
            let start = 23
            let count = start + Int(sampleRate * 0.07)
            func render(zone: GroovePulseStrikeZone, damping: Double,
                        microvariation: Double) throws -> ([Float], GroovePulseRenderEvidence) {
                let articulation = GroovePulseArticulation(
                    step: 3,
                    pulseClass: .trailingWeak,
                    stage: .syncopatedLean,
                    intensity: 0.72,
                    timingOffsetInSteps: 0.08,
                    strikeZone: zone,
                    damping: damping,
                    timbreMicrovariation: microvariation
                )
                var output = [Float](repeating: 0, count: count)
                var measurement = [Float](repeating: 0, count: count)
                let evidence = GroovePulseVoice.render(
                    &output,
                    measurement: &measurement,
                    start: start,
                    sampleRate: sampleRate,
                    articulation: articulation,
                    seed: 8_081
                )
                #expect(output == measurement)
                return (output, try #require(evidence))
            }

            let (center, centerEvidence) = try render(
                zone: .center, damping: 0.5, microvariation: 0
            )
            let (edge, edgeEvidence) = try render(
                zone: .edge, damping: 0.5, microvariation: 0
            )
            let (_, openEvidence) = try render(
                zone: .middle, damping: 0.25, microvariation: 0
            )
            let (_, dampedEvidence) = try render(
                zone: .middle, damping: 0.75, microvariation: 0
            )
            let (_, lowerVariation) = try render(
                zone: .middle, damping: 0.5, microvariation: -0.04
            )
            let (_, upperVariation) = try render(
                zone: .middle, damping: 0.5, microvariation: 0.04
            )

            #expect(center != edge)
            #expect(centerEvidence.sampleHash != edgeEvidence.sampleHash)
            #expect(centerEvidence.renderedFrameCount == edgeEvidence.renderedFrameCount)
            if sampleRate >= 44_100 {
                #expect(edgeEvidence.highBandEnergyRatio > centerEvidence.highBandEnergyRatio)
                #expect(edgeEvidence.spectralCentroidHz > centerEvidence.spectralCentroidHz)
            }
            #expect(dampedEvidence.tailToAttackRatio < openEvidence.tailToAttackRatio)
            #expect(dampedEvidence.tailToAttackDB < openEvidence.tailToAttackDB)
            #expect(lowerVariation.sampleHash != upperVariation.sampleHash)
            #expect(lowerVariation.renderedFrameCount == upperVariation.renderedFrameCount)
            for evidence in [
                centerEvidence, edgeEvidence, openEvidence, dampedEvidence,
                lowerVariation, upperVariation,
            ] {
                #expect(evidence.finite)
                #expect(evidence.renderedFrameCount == Int(sampleRate * 0.045))
                #expect((0...(sampleRate / 2)).contains(evidence.spectralCentroidHz))
                #expect((0...1).contains(evidence.lowBandEnergyRatio))
                #expect((0...1).contains(evidence.midBandEnergyRatio))
                #expect((0...1).contains(evidence.highBandEnergyRatio))
                #expect(abs(evidence.lowBandEnergyRatio + evidence.midBandEnergyRatio +
                            evidence.highBandEnergyRatio - 1) < 0.000_001)
            }
        }
    }

    @Test("Rumble remains a protected mono-compatible foundation companion")
    func monoRumbleProtection() {
        var matched: (UInt64, AutonomousPhrasePlan)?
        for seed in UInt64(1)...16 where matched == nil {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<32 {
                let plan = director.plan(from: state)
                if plan.resolvedBars.contains(where: {
                    $0.foundationCompanion == .monoRumble
                }) {
                    matched = (seed, plan)
                    break
                }
                state.advancePlanning(using: plan)
            }
        }
        guard let (seed, plan) = matched else {
            Issue.record("Expected a deterministic rumble identity")
            return
        }
        let graph = DSPGraphGenerator.safePlan(sessionSeed: seed)
        var render = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan, graph: graph, sampleRate: 8_000,
            state: &render, graphState: &graphState
        )
        let report = AudioQualityReport(blocks: blocks, sampleRate: 8_000)
        #expect(blocks.flatMap(\.events).contains { $0.voice == .rumble })
        #expect(report.lowStereoCorrelation > 0.98)
    }

    @Test("Three-sixteenth pulse echo is sparse, audible, and low-cut")
    func pulseEchoSignalBehavior() {
        func replacingEcho(
            in resolved: ResolvedPerformanceBar,
            enabled: Bool,
            companion: FoundationCompanion? = nil,
            chapter: InterlockChapter = .memory
        ) -> ResolvedPerformanceBar {
            ResolvedPerformanceBar(
                performance: resolved.performance,
                ensemble: resolved.ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                foundationCompanion: companion ?? resolved.foundationCompanion,
                pulseEchoEnabled: enabled,
                interlockChapter: chapter,
                groovePulses: resolved.groovePulses,
                closedHatDecayArticulations: resolved.closedHatDecayArticulations,
                upperPercussionTailArticulations:
                    resolved.upperPercussionTailArticulations,
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }

        var matched: (AutonomousSessionState, AutonomousPhrasePlan, Int)?
        for fixture in UInt64(1)...64 where matched == nil {
            let director = AutonomousSessionDirector(rootSeed: fixture)
            var state = director.initialState()
            for _ in 0..<40 where matched == nil {
                let plan = director.plan(from: state)
                #expect(plan.resolvedBars.filter(\.pulseEchoEnabled).allSatisfy {
                    $0.foundationCompanion != .monoRumble &&
                        ($0.arrangementGesture == .gearShift ||
                         $0.arrangementGesture == .turnaround)
                })
                if plan.kind == .identityReturn || plan.kind == .majorBreak {
                    state.advancePlanning(using: plan)
                    continue
                }
                for (barIndex, resolved) in plan.resolvedBars.enumerated() {
                    guard resolved.foundationCompanion != .monoRumble,
                          barIndex + 1 < plan.resolvedBars.count else { continue }
                    let memoryResolved = replacingEcho(in: resolved, enabled: true)
                    let synthBar = SynthPerformancePlan(
                        scene: plan.scene,
                        dna: plan.dna,
                        kind: plan.kind,
                        resolvedBars: [memoryResolved]
                    ).bars[0]
                    guard synthBar.pulseEchoTextureArticulation.appliedAmount > 0 else {
                        continue
                    }
                    if resolved.ensemble.events.contains(where: { event in
                        guard event.voice == .motif || event.voice == .response else { return false }
                        let macroStep = (resolved.performance.bar % 16) * 16 + event.step
                        let stage = RelationalCyclePhase(macroStep: macroStep).followerStage
                        return event.step <= 12 && (stage == .open || stage == .spill)
                    }) {
                        matched = (state, plan, barIndex)
                        break
                    }
                }
                if matched == nil { state.advancePlanning(using: plan) }
            }
        }
        guard let (sourceState, sourcePlan, barIndex) = matched else {
            Issue.record("Expected a relationally echoable upper-voice event")
            return
        }
        let sourceBar = sourcePlan.resolvedBars[barIndex]
        var wetBars = sourcePlan.resolvedBars.map { resolved in
            replacingEcho(
                in: resolved,
                enabled: false,
                chapter: resolved.interlockChapter
            )
        }
        var dryBars = wetBars
        wetBars[barIndex] = replacingEcho(in: sourceBar, enabled: true)
        dryBars[barIndex] = replacingEcho(in: sourceBar, enabled: false)
        wetBars[barIndex + 1] = replacingEcho(
            in: wetBars[barIndex + 1],
            enabled: false
        )
        dryBars[barIndex + 1] = replacingEcho(
            in: dryBars[barIndex + 1],
            enabled: false
        )
        let protected = replacingEcho(in: sourceBar, enabled: true, companion: .monoRumble)
        #expect(!protected.pulseEchoEnabled)

        func synthBar(
            resolved: ResolvedPerformanceBar,
            kind: AutonomousPhraseKind,
            forceHome: Bool = false
        ) -> SynthPerformanceBar {
            SynthPerformancePlan(
                scene: sourcePlan.scene,
                dna: sourcePlan.dna,
                kind: kind,
                resolvedBars: [resolved],
                forceHomeUpperTimbre: forceHome
            ).bars[0]
        }

        let eligibleSynthBar = synthBar(
            resolved: wetBars[barIndex],
            kind: sourcePlan.kind
        )
        let eligibleTexture = eligibleSynthBar.pulseEchoTextureArticulation
        #expect(eligibleTexture.machineTexture == sourcePlan.scene.machineTexture)
        #expect(eligibleTexture.earliestPulseEchoOnsetStep != nil)
        #expect((eligibleTexture.earliestPulseEchoOnsetStep ?? 16) <=
                PulseEchoTextureArticulation.latestDrivenOnsetStep)
        #expect(eligibleTexture.driveEligible)
        #expect(eligibleTexture.appliedAmount == min(
            PulseEchoTextureArticulation.maximumAppliedAmount,
            sourcePlan.scene.machineTexture
        ))
        #expect(eligibleSynthBar.upperNotes.contains {
            $0.instrument.effects.contains(.pulseEcho)
        })
        let scoreDisabled = synthBar(
            resolved: dryBars[barIndex],
            kind: sourcePlan.kind
        ).pulseEchoTextureArticulation
        let nonMemory = synthBar(
            resolved: replacingEcho(in: sourceBar, enabled: true, chapter: .tone),
            kind: sourcePlan.kind
        ).pulseEchoTextureArticulation
        let forceHome = synthBar(
            resolved: wetBars[barIndex],
            kind: sourcePlan.kind,
            forceHome: true
        ).pulseEchoTextureArticulation
        let identityReturn = synthBar(
            resolved: wetBars[barIndex],
            kind: .identityReturn
        ).pulseEchoTextureArticulation
        let majorBreak = synthBar(
            resolved: wetBars[barIndex],
            kind: .majorBreak
        ).pulseEchoTextureArticulation
        let upperlessEnsemble = EnsembleContext(
            focusRole: sourceBar.ensemble.focusRole,
            events: sourceBar.ensemble.events.filter {
                $0.voice != .motif && $0.voice != .response
            },
            kickAnchors: sourceBar.ensemble.kickAnchors,
            intentionalPileup: sourceBar.ensemble.intentionalPileup
        )
        let upperlessResolved = ResolvedPerformanceBar(
            performance: sourceBar.performance,
            ensemble: upperlessEnsemble,
            arrangementGesture: sourceBar.arrangementGesture,
            percussionGear: sourceBar.percussionGear,
            foundationCompanion: sourceBar.foundationCompanion,
            pulseEchoEnabled: true,
            interlockChapter: .memory,
            groovePulses: sourceBar.groovePulses,
            spatialContrast: sourceBar.spatialContrast,
            narrative: sourceBar.narrative
        )
        let upperless = synthBar(
            resolved: upperlessResolved,
            kind: sourcePlan.kind
        ).pulseEchoTextureArticulation
        for bypassed in [
            scoreDisabled, nonMemory, forceHome,
            identityReturn, majorBreak, upperless,
        ] {
            #expect(!bypassed.driveEligible)
            #expect(bypassed.appliedAmount == 0)
        }
        #expect(PulseEchoTextureArticulation.neutral.appliedAmount == 0)
        #expect(!PulseEchoTextureArticulation.neutral.driveEligible)
        for source in [
            -Double.infinity, -1, 0, 0.24, 0.55, 0.82, 1, 2,
            Double.infinity, Double.nan,
        ] {
            let expectedSource = source.isFinite ? min(1, max(0, source)) : 0
            let articulation = PulseEchoTextureArticulation(
                machineTexture: source,
                enabled: true,
                earliestPulseEchoOnsetStep: 0
            )
            #expect(articulation.machineTexture == expectedSource)
            #expect(articulation.driveEligible)
            #expect(articulation.appliedAmount == min(
                PulseEchoTextureArticulation.maximumAppliedAmount,
                expectedSource
            ))
            #expect((0...1).contains(articulation.machineTexture))
            #expect((0...PulseEchoTextureArticulation.maximumAppliedAmount)
                .contains(articulation.appliedAmount))
        }
        let lateOnlyTexture = PulseEchoTextureArticulation(
            machineTexture: sourcePlan.scene.machineTexture,
            enabled: true,
            earliestPulseEchoOnsetStep: 13
        )
        #expect(lateOnlyTexture.earliestPulseEchoOnsetStep == 13)
        #expect(!lateOnlyTexture.driveEligible)
        #expect(lateOnlyTexture.appliedAmount == 0)
        for filteredSample in [-2.0, -1, -0.4, -0.01, 0, 0.01, 0.4, 1, 2] {
            let preDriveSample = Float(filteredSample * 0.18)
            let neutralSample = PulseEchoReturnDriveContract.process(
                preDriveSample: preDriveSample,
                amount: 0
            )
            let drivenSample = PulseEchoReturnDriveContract.process(
                preDriveSample: preDriveSample,
                amount: eligibleTexture.appliedAmount
            )
            #expect(neutralSample == preDriveSample)
            let neutralMagnitude = abs(Double(neutralSample))
            let drivenMagnitude = abs(Double(drivenSample))
            #expect(drivenMagnitude <= neutralMagnitude *
                    PulseEchoReturnDriveContract.maximumLowLevelGain + 0.000_001)
            #expect(drivenMagnitude <= max(
                neutralMagnitude,
                PulseEchoReturnDriveContract.normalizationAmplitude
            ) + 0.000_001)
            if abs(filteredSample) > 0 && abs(filteredSample) < 0.5 {
                #expect(drivenMagnitude > neutralMagnitude)
            }
            #expect(Double(drivenSample) * filteredSample >= 0)
        }
        #expect(abs(PulseEchoReturnDriveContract.maximumLowLevelGain - 3.2) <
                0.000_000_000_001)
        for zero in [Float(bitPattern: 0), Float(bitPattern: 0x8000_0000)] {
            #expect(PulseEchoReturnDriveContract.process(
                preDriveSample: zero,
                amount: PulseEchoReturnDriveContract.maximumAmount
            ).bitPattern == zero.bitPattern)
        }
        let tinyDriveInput = Float(0.20)
        let tinyDriveOutput = PulseEchoReturnDriveContract.process(
            preDriveSample: tinyDriveInput,
            amount: 0.000_000_000_001
        )
        #expect(tinyDriveOutput.bitPattern != tinyDriveInput.bitPattern)
        #expect(tinyDriveOutput == PulseEchoReturnDriveContract.process(
            preDriveSample: tinyDriveInput,
            amount: 0.000_000_000_001
        ))
        let transitionFrameCount =
            PulseEchoReturnDriveContract.transitionFrameCount(sampleRate: 8_000)
        let transitionTotalFrameCount = max(
            transitionFrameCount * 2 + 3,
            1_024
        )
        let targetAmount = eligibleTexture.appliedAmount
        let firstAmount = PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: targetAmount,
            frame: 0,
            totalFrameCount: transitionTotalFrameCount,
            transitionFrameCount: transitionFrameCount
        )
        let lastAmount = PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: targetAmount,
            frame: transitionTotalFrameCount - 1,
            totalFrameCount: transitionTotalFrameCount,
            transitionFrameCount: transitionFrameCount
        )
        #expect(transitionFrameCount == 64)
        #expect(PulseEchoReturnDriveContract.transitionFrameCount(
            sampleRate: 44_100
        ) == 353)
        #expect(PulseEchoReturnDriveContract.transitionFrameCount(
            sampleRate: 48_000
        ) == 384)
        #expect(firstAmount == 0)
        #expect(lastAmount == 0)
        #expect(PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: targetAmount,
            frame: transitionFrameCount,
            totalFrameCount: transitionTotalFrameCount,
            transitionFrameCount: transitionFrameCount
        ) == targetAmount)
        let boundaryPreDriveSample = Float(-0.12)
        let firstBoundaryOutput = PulseEchoReturnDriveContract.process(
            preDriveSample: boundaryPreDriveSample,
            amount: firstAmount
        )
        let lastBoundaryOutput = PulseEchoReturnDriveContract.process(
            preDriveSample: boundaryPreDriveSample,
            amount: lastAmount
        )
        #expect(firstBoundaryOutput == boundaryPreDriveSample)
        #expect(lastBoundaryOutput == boundaryPreDriveSample)
        #expect((firstBoundaryOutput - boundaryPreDriveSample).bitPattern == 0)
        #expect((lastBoundaryOutput - boundaryPreDriveSample).bitPattern == 0)
        let maximumAmountDelta = targetAmount / Double(transitionFrameCount)
        for frame in 1..<transitionTotalFrameCount {
            let previous = PulseEchoReturnDriveContract.effectiveAmount(
                targetAmount: targetAmount,
                frame: frame - 1,
                totalFrameCount: transitionTotalFrameCount,
                transitionFrameCount: transitionFrameCount
            )
            let current = PulseEchoReturnDriveContract.effectiveAmount(
                targetAmount: targetAmount,
                frame: frame,
                totalFrameCount: transitionTotalFrameCount,
                transitionFrameCount: transitionFrameCount
            )
            #expect(abs(current - previous) <= maximumAmountDelta + 0.000_000_000_001)
        }

        let wetPlan = replacingResolvedBars(
            in: sourcePlan, with: wetBars, memory: sourceState.memory
        )
        let dryPlan = replacingResolvedBars(
            in: sourcePlan, with: dryBars, memory: sourceState.memory
        )
        var zeroTextureIntent = wetPlan.scene.musicalIntent
        zeroTextureIntent[.machineTexture] = 0
        let zeroTextureScene = TechnoScene(
            intent: zeroTextureIntent,
            seed: wetPlan.scene.seed,
            bpm: wetPlan.scene.bpm
        )
        #expect(zeroTextureScene.machineTexture == 0)
        #expect(TechnoScene(
            intent: wetPlan.scene.musicalIntent,
            seed: wetPlan.scene.seed,
            bpm: wetPlan.scene.bpm
        ) == wetPlan.scene)
        func replacingScene(
            in plan: AutonomousPhrasePlan,
            with scene: TechnoScene
        ) -> AutonomousPhrasePlan {
            AutonomousPhrasePlan(
                phraseIndex: plan.phraseIndex,
                startBar: plan.startBar,
                barCount: plan.barCount,
                kind: plan.kind,
                scene: scene,
                dna: plan.dna,
                resolvedBars: plan.resolvedBars,
                openedDebt: plan.openedDebt,
                paidDebtIDs: plan.paidDebtIDs,
                requestsTopologyMutation: plan.requestsTopologyMutation,
                interest: plan.interest,
                endingInterlockState: plan.endingInterlockState,
                endingSpatialContrastState: plan.endingSpatialContrastState,
                endingNarrativeState: plan.endingNarrativeState,
                harmonicContinuation: plan.incomingHarmonicContinuation,
                longHorizonSelection: plan.longHorizonSelection,
                longHorizonEnergyCoordination:
                    plan.longHorizonEnergyCoordination,
                materialWorld: plan.materialWorld
            )
        }
        let zeroDrivePlan = replacingScene(in: wetPlan, with: zeroTextureScene)
        let dryZeroDrivePlan = replacingScene(in: dryPlan, with: zeroTextureScene)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: sourceState.rootSeed)
        let sampleRate = 8_000.0
        let drivePair = pulseEchoRenderPair(
            firstPlan: wetPlan,
            secondPlan: zeroDrivePlan,
            graph: graph,
            sampleRate: sampleRate
        )
        let sendPair = pulseEchoRenderPair(
            firstPlan: zeroDrivePlan,
            secondPlan: dryZeroDrivePlan,
            graph: graph,
            sampleRate: sampleRate
        )
        let wet = drivePair.first
        let zeroDrive = drivePair.second
        let replayedZeroDrive = sendPair.first
        let dry = sendPair.second
        #expect(zeroDrive == replayedZeroDrive)

        let lateEchoBase = replacingEcho(in: sourceBar, enabled: true)
        let nonUpperEvents = lateEchoBase.ensemble.events.filter { event in
            switch event.voice {
            case .motif, .response, .atmosphere, .transition:
                return false
            default:
                return true
            }
        }
        let lateOnlyResolved = ResolvedPerformanceBar(
            performance: lateEchoBase.performance,
            ensemble: EnsembleContext(
                focusRole: lateEchoBase.ensemble.focusRole,
                events: nonUpperEvents + [EnsembleResolvedEvent(
                    voice: .motif,
                    step: 13,
                    intensity: 0.82,
                    relocated: true
                )],
                kickAnchors: lateEchoBase.ensemble.kickAnchors,
                intentionalPileup: lateEchoBase.ensemble.intentionalPileup
            ),
            arrangementGesture: lateEchoBase.arrangementGesture,
            percussionGear: lateEchoBase.percussionGear,
            foundationCompanion: lateEchoBase.foundationCompanion,
            pulseEchoEnabled: lateEchoBase.pulseEchoEnabled,
            interlockChapter: lateEchoBase.interlockChapter,
            groovePulses: lateEchoBase.groovePulses,
            spatialContrast: lateEchoBase.spatialContrast,
            narrative: lateEchoBase.narrative
        )
        let lateOnlyPlan = replacingResolvedBars(
            in: sourcePlan,
            with: [lateOnlyResolved, wetBars[barIndex + 1]],
            memory: sourceState.memory
        )
        let lateOnlyRender = pulseEchoRenderMaterial(
            plan: lateOnlyPlan,
            graph: graph,
            sampleRate: sampleRate
        ).projection
        let lateOnlyEvidence = lateOnlyRender.pulseEchoEvidence[0]
        let lateOnlyTailEvidence = lateOnlyRender.pulseEchoEvidence[1]
        #expect(lateOnlyEvidence.earliestPulseEchoOnsetStep == 13)
        #expect(!lateOnlyEvidence.driveEligible)
        #expect(lateOnlyEvidence.appliedAmount == 0)
        #expect(lateOnlyEvidence.currentSendRMS > 0)
        #expect(lateOnlyEvidence.preDriveSampleHash ==
                lateOnlyEvidence.postDriveSampleHash)
        #expect(lateOnlyEvidence.differenceRMS == 0)
        #expect(!lateOnlyTailEvidence.driveEligible)
        #expect(lateOnlyTailEvidence.appliedAmount == 0)
        #expect(lateOnlyTailEvidence.currentSendRMS == 0)
        #expect(lateOnlyTailEvidence.preDriveRMS > 0)
        #expect(lateOnlyTailEvidence.preDriveSampleHash ==
                lateOnlyTailEvidence.postDriveSampleHash)
        #expect(lateOnlyTailEvidence.differenceRMS == 0)

        #expect(wet.events == zeroDrive.events)
        #expect(wet.upperNoteEvidence == zeroDrive.upperNoteEvidence)
        #expect(wet.instrumentEvidence == zeroDrive.instrumentEvidence)
        #expect(wet.protectedFoundationHashes == zeroDrive.protectedFoundationHashes)
        #expect(wet.percussionHashes == zeroDrive.percussionHashes)
        #expect(wet.protectedRhythmHashes.prefix(barIndex + 1) ==
                zeroDrive.protectedRhythmHashes.prefix(barIndex + 1))
        #expect(wet.pulseEchoEvidence.map { $0.currentSendRMS } ==
                zeroDrive.pulseEchoEvidence.map { $0.currentSendRMS })
        #expect(wet.pulseEchoEvidence.map { $0.preDriveSampleHash } ==
                zeroDrive.pulseEchoEvidence.map { $0.preDriveSampleHash })

        let wetEvidence = wet.pulseEchoEvidence[barIndex]
        let zeroDriveEvidence = zeroDrive.pulseEchoEvidence[barIndex]
        let dryEvidence = dry.pulseEchoEvidence[barIndex]
        let expectedDelayFrameCount = max(
            1,
            Int((60.0 / wetPlan.scene.bpm * 0.75 * sampleRate).rounded())
        )
        let expectedRenderedFrameCount = max(
            1,
            Int((240.0 / wetPlan.scene.bpm * sampleRate).rounded())
        )
        for evidence in [wetEvidence, zeroDriveEvidence, dryEvidence] {
            #expect(evidence.bar == sourceBar.performance.bar)
            #expect(evidence.bpm == wetPlan.scene.bpm)
            #expect(evidence.delayFrameCount == expectedDelayFrameCount)
            #expect(evidence.transitionFrameCount == transitionFrameCount)
            #expect(evidence.renderedFrameCount == expectedRenderedFrameCount)
            #expect(evidence.finite)
            #expect(evidence.preDriveSampleHash.count == 16)
            #expect(evidence.postDriveSampleHash.count == 16)
            #expect(evidence.firstPreDriveSampleBitPattern ==
                    evidence.firstPostDriveSampleBitPattern)
            #expect(evidence.lastPreDriveSampleBitPattern ==
                    evidence.lastPostDriveSampleBitPattern)
            if evidence.appliedAmount > 0 {
                #expect((0..<evidence.renderedFrameCount).contains(
                    evidence.changedFrameIndex
                ))
                let changedPreDriveSample = Float(
                    bitPattern: evidence.changedPreDriveSampleBitPattern
                )
                let changedEffectiveAmount =
                    PulseEchoReturnDriveContract.effectiveAmount(
                        targetAmount: evidence.appliedAmount,
                        frame: evidence.changedFrameIndex,
                        totalFrameCount: evidence.renderedFrameCount,
                        transitionFrameCount: evidence.transitionFrameCount
                    )
                #expect(PulseEchoReturnDriveContract.process(
                    preDriveSample: changedPreDriveSample,
                    amount: changedEffectiveAmount
                ).bitPattern != evidence.changedPreDriveSampleBitPattern)
            } else {
                #expect(evidence.changedFrameIndex == -1)
                #expect(evidence.changedPreDriveSampleBitPattern == 0)
            }
            #expect(evidence.preDrivePeak == Double(Float(evidence.preDrivePeak)))
            #expect(evidence.preDriveRMS <= evidence.preDrivePeak + 0.000_001)
            #expect(evidence.postDriveRMS <= evidence.postDrivePeak + 0.000_001)
            #expect(evidence.preDriveLowBandRMS <= evidence.preDriveRMS + 0.000_001)
            #expect(evidence.postDriveLowBandRMS <= evidence.postDriveRMS + 0.000_001)
            #expect((0..<evidence.renderedFrameCount).contains(
                evidence.preDrivePeakFrameIndex
            ))
            #expect((0..<evidence.renderedFrameCount).contains(
                evidence.postDrivePeakFrameIndex
            ))
            let prePeakEffectiveAmount =
                PulseEchoReturnDriveContract.effectiveAmount(
                    targetAmount: evidence.appliedAmount,
                    frame: evidence.preDrivePeakFrameIndex,
                    totalFrameCount: evidence.renderedFrameCount,
                    transitionFrameCount: evidence.transitionFrameCount
                )
            let expectedPostMagnitudeAtPrePeak = abs(Double(
                PulseEchoReturnDriveContract.process(
                    preDriveSample: Float(evidence.preDrivePeak),
                    amount: prePeakEffectiveAmount
                )
            ))
            #expect(evidence.postDrivePeak >= expectedPostMagnitudeAtPrePeak)
            #expect(evidence.postDrivePeak <= min(
                evidence.preDrivePeak *
                    PulseEchoReturnDriveContract.maximumLowLevelGain,
                max(
                    evidence.preDrivePeak,
                    PulseEchoReturnDriveContract.normalizationAmplitude
                )
            ) + 0.000_001)
            #expect(evidence.postDriveRMS <= evidence.preDriveRMS *
                    PulseEchoReturnDriveContract.maximumLowLevelGain + 0.000_001)
            #expect(evidence.postDrivePeakEffectiveAmount ==
                    PulseEchoReturnDriveContract.effectiveAmount(
                        targetAmount: evidence.appliedAmount,
                        frame: evidence.postDrivePeakFrameIndex,
                        totalFrameCount: evidence.renderedFrameCount,
                        transitionFrameCount: evidence.transitionFrameCount
                    ))
            #expect(evidence.postDrivePeak == abs(Double(
                PulseEchoReturnDriveContract.process(
                    preDriveSample: Float(evidence.postDrivePeakPreDriveSample),
                    amount: evidence.postDrivePeakEffectiveAmount
                )
            )))
            #expect(PulseEchoReturnDriveContract.effectiveAmount(
                targetAmount: evidence.appliedAmount,
                frame: 0,
                totalFrameCount: evidence.renderedFrameCount,
                transitionFrameCount: evidence.transitionFrameCount
            ) == 0)
            #expect(PulseEchoReturnDriveContract.effectiveAmount(
                targetAmount: evidence.appliedAmount,
                frame: evidence.renderedFrameCount - 1,
                totalFrameCount: evidence.renderedFrameCount,
                transitionFrameCount: evidence.transitionFrameCount
            ) == 0)
            #expect(evidence.differenceRMS + 0.000_001 >=
                    abs(evidence.preDriveRMS - evidence.postDriveRMS))
            #expect(evidence.differenceRMS <=
                    evidence.preDriveRMS + evidence.postDriveRMS + 0.000_001)
        }
        #expect(wetEvidence.machineTexture == wetPlan.scene.machineTexture)
        #expect(wetEvidence.scoreEnabled)
        #expect(wetEvidence.earliestPulseEchoOnsetStep ==
                eligibleTexture.earliestPulseEchoOnsetStep)
        #expect(wetEvidence.driveEligible)
        #expect(wetEvidence.appliedAmount == eligibleTexture.appliedAmount)
        #expect(wetEvidence.currentSendRMS > 0)
        #expect(wetEvidence.preDriveRMS > 0)
        #expect(wetEvidence.preDriveSampleHash == zeroDriveEvidence.preDriveSampleHash)
        #expect(wetEvidence.preDrivePeak == zeroDriveEvidence.preDrivePeak)
        #expect(wetEvidence.preDriveRMS == zeroDriveEvidence.preDriveRMS)
        #expect(wetEvidence.preDriveLowBandRMS == zeroDriveEvidence.preDriveLowBandRMS)
        #expect(wetEvidence.postDriveSampleHash != zeroDriveEvidence.postDriveSampleHash)
        #expect(wetEvidence.changedFrameIndex > 0)
        #expect(wetEvidence.differenceRMS > 0)
        #expect(wetEvidence.postDrivePeak > wetEvidence.preDrivePeak)
        #expect(wetEvidence.postDriveRMS > wetEvidence.preDriveRMS)
        let prePeakEffectiveAmount = PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: wetEvidence.appliedAmount,
            frame: wetEvidence.preDrivePeakFrameIndex,
            totalFrameCount: wetEvidence.renderedFrameCount,
            transitionFrameCount: wetEvidence.transitionFrameCount
        )
        let drivenPrePeak = abs(Double(PulseEchoReturnDriveContract.process(
            preDriveSample: Float(wetEvidence.preDrivePeak),
            amount: prePeakEffectiveAmount
        )))
        #expect(wetEvidence.postDrivePeak >= drivenPrePeak)

        #expect(zeroDriveEvidence.machineTexture == 0)
        #expect(zeroDriveEvidence.scoreEnabled)
        #expect(zeroDriveEvidence.driveEligible)
        #expect(zeroDriveEvidence.appliedAmount == 0)
        #expect(zeroDriveEvidence.currentSendRMS == wetEvidence.currentSendRMS)
        #expect(zeroDriveEvidence.preDriveSampleHash == zeroDriveEvidence.postDriveSampleHash)
        #expect(zeroDriveEvidence.preDrivePeak == zeroDriveEvidence.postDrivePeak)
        #expect(zeroDriveEvidence.preDriveRMS == zeroDriveEvidence.postDriveRMS)
        #expect(zeroDriveEvidence.preDriveLowBandRMS ==
                zeroDriveEvidence.postDriveLowBandRMS)
        #expect(zeroDriveEvidence.changedFrameIndex == -1)
        #expect(zeroDriveEvidence.changedPreDriveSampleBitPattern == 0)
        #expect(zeroDriveEvidence.differenceRMS == 0)

        #expect(!dryEvidence.scoreEnabled)
        #expect(!dryEvidence.driveEligible)
        #expect(dryEvidence.appliedAmount == 0)
        #expect(dryEvidence.currentSendRMS == 0)
        #expect(dryEvidence.preDriveSampleHash == dryEvidence.postDriveSampleHash)
        #expect(dryEvidence.changedFrameIndex == -1)
        #expect(dryEvidence.changedPreDriveSampleBitPattern == 0)
        #expect(dryEvidence.differenceRMS == 0)

        let tailEvidence = wet.pulseEchoEvidence[barIndex + 1]
        let zeroDriveTailEvidence = zeroDrive.pulseEchoEvidence[barIndex + 1]
        #expect(!tailEvidence.scoreEnabled)
        #expect(!tailEvidence.driveEligible)
        #expect(tailEvidence.appliedAmount == 0)
        #expect(tailEvidence.currentSendRMS == 0)
        #expect(tailEvidence.preDriveRMS > 0)
        #expect(tailEvidence.postDriveRMS > 0)
        #expect(tailEvidence.preDriveSampleHash == tailEvidence.postDriveSampleHash)
        #expect(tailEvidence.preDriveRMS == tailEvidence.postDriveRMS)
        #expect(tailEvidence.changedFrameIndex == -1)
        #expect(tailEvidence.changedPreDriveSampleBitPattern == 0)
        #expect(tailEvidence.differenceRMS == 0)
        #expect(tailEvidence.postDrivePeakEffectiveAmount == 0)
        #expect(PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: tailEvidence.appliedAmount,
            frame: 0,
            totalFrameCount: tailEvidence.renderedFrameCount,
            transitionFrameCount: tailEvidence.transitionFrameCount
        ) == 0)
        #expect(PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: tailEvidence.appliedAmount,
            frame: tailEvidence.renderedFrameCount - 1,
            totalFrameCount: tailEvidence.renderedFrameCount,
            transitionFrameCount: tailEvidence.transitionFrameCount
        ) == 0)
        #expect(tailEvidence.currentSendRMS == zeroDriveTailEvidence.currentSendRMS)
        #expect(tailEvidence.preDriveSampleHash == zeroDriveTailEvidence.preDriveSampleHash)
        #expect(tailEvidence.postDriveSampleHash == zeroDriveTailEvidence.postDriveSampleHash)
        #expect(tailEvidence.preDriveRMS == zeroDriveTailEvidence.preDriveRMS)
        #expect(tailEvidence.postDriveRMS == zeroDriveTailEvidence.postDriveRMS)
        #expect(wet.effects[barIndex + 1].contains {
            $0.kind == .pulseEcho && $0.active
        })
        #expect(wet.outputHashes[barIndex] != zeroDrive.outputHashes[barIndex])

        for (evidence, effects) in [
            (wetEvidence, wet.effects[barIndex]),
            (zeroDriveEvidence, zeroDrive.effects[barIndex]),
            (dryEvidence, dry.effects[barIndex]),
        ] {
            let effect = effects.first { $0.kind == .pulseEcho }
            #expect(effect != nil)
            #expect(effect?.active ==
                    (evidence.currentSendRMS > 0 || evidence.postDriveRMS > 0))
        }
        #expect(wet.effects[barIndex].contains { $0.kind == .pulseEcho && $0.active })
        #expect(zeroDrive.effects[barIndex].contains {
            $0.kind == .pulseEcho && $0.active && $0.amount > 0
        })
        #expect(!dry.effects[barIndex].contains { $0.kind == .pulseEcho && $0.active })

        #expect(drivePair.differenceEnergy > 0.000_000_000_001)
        #expect(sendPair.differenceEnergy > 0.000_000_1)
        #expect(sendPair.lowDifferenceEnergy /
                max(sendPair.differenceEnergy, 0.000_000_1) < 0.45)
    }

    @Test("Representative 44.1 and 48 kHz renders remain finite and bounded")
    func deviceSampleRates() throws {
        for (seed, sampleRate) in [(UInt64(42), 44_100.0), (UInt64(90_909), 48_000.0)] {
            let prepared = prepare(seed: seed, sampleRate: sampleRate)
            let report = prepared.audioPreflight.quality
            #expect(report.finite)
            #expect(report.truePeakEstimate <= 0.95)
            #expect(abs(report.dcOffset) < 0.05)
            #expect(report.lowStereoCorrelation > 0.94)
            #expect(report.maxBoundaryDelta < 0.65)
            #expect(prepared.selectedCandidateEvidence.isComplete)
            #expect(prepared.selectedCandidateEvidence.hardGatesPassed)
            #expect(prepared.hardGatesPassed)
            let qualification = try CanonicalJourneyQualificationReport(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: prepared.qualityDecision.policyVersion,
                fixtureFingerprint: "device-rate-\(Int(sampleRate))",
                continuationFingerprint: "device-rate-continuation-\(seed)",
                checkpoint: .establishment,
                routeFingerprint: prepared.selectedCandidateEvidence
                    .routeContinuation.routeFingerprint,
                routeGeneration: prepared.selectedCandidateEvidence
                    .routeContinuation.routeGeneration,
                selectedCandidateEvidence: prepared.selectedCandidateEvidence,
                candidateEvaluation: prepared.candidateEvaluation,
                commitProvenance: prepared.commitProvenance,
                sampleHash: report.sampleHash,
                decision: prepared.qualityDecision,
                incomingState: prepared.incomingQualityState,
                outgoingState: prepared.qualityContinuationState,
                usedHomeTimbreCorrection: prepared.usedHomeTimbreCorrection,
                correctionRenderCount: prepared.correctionRenderCount
            )
            #expect(qualification.commitProvenance == prepared.commitProvenance)
        }
    }

    private func prepare(seed: UInt64, sampleRate: Double) -> PreparedAutonomousPhrase {
        let director = AutonomousSessionDirector(rootSeed: seed)
        return prepare(state: director.initialState(), sampleRate: sampleRate)
    }

    @inline(never)
    private func pulseEchoRenderMaterial(
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        sampleRate: Double
    ) -> PulseEchoRenderMaterial {
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: sampleRate,
            state: &renderState,
            graphState: &graphState
        )
        return PulseEchoRenderMaterial(
            projection: PulseEchoRenderProjection(
                events: blocks.map { $0.events },
                upperNoteEvidence: blocks.map { $0.upperNoteRenderEvidence },
                instrumentEvidence: blocks.map { $0.instrumentRenderEvidence },
                protectedFoundationHashes: blocks.map {
                    $0.protectedFoundationSampleHash
                },
                percussionHashes: blocks.map { $0.percussionSampleHash },
                protectedRhythmHashes: blocks.map { $0.protectedRhythmSampleHash },
                pulseEchoEvidence: blocks.map {
                    $0.pulseEchoReturnDriveRenderEvidence
                },
                effects: blocks.map { $0.effects },
                outputHashes: blocks.map {
                    ExactPCMFingerprint.stereo(left: $0.left, right: $0.right)
                }
            ),
            left: blocks.flatMap { $0.left }
        )
    }

    @inline(never)
    private func pulseEchoRenderPair(
        firstPlan: AutonomousPhrasePlan,
        secondPlan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        sampleRate: Double
    ) -> PulseEchoRenderPair {
        let first = pulseEchoRenderMaterial(
            plan: firstPlan,
            graph: graph,
            sampleRate: sampleRate
        )
        let second = pulseEchoRenderMaterial(
            plan: secondPlan,
            graph: graph,
            sampleRate: sampleRate
        )
        var differenceEnergy = 0.0
        var lowDifferenceEnergy = 0.0
        var low = 0.0
        let coefficient = 1 - exp(-2 * Double.pi * 120 / sampleRate)
        for (firstSample, secondSample) in zip(first.left, second.left) {
            let difference = Double(firstSample - secondSample)
            differenceEnergy += difference * difference
            low += (difference - low) * coefficient
            lowDifferenceEnergy += low * low
        }
        return PulseEchoRenderPair(
            first: first.projection,
            second: second.projection,
            differenceEnergy: differenceEnergy,
            lowDifferenceEnergy: lowDifferenceEnergy
        )
    }

    private func modalPlanFixture() -> ModalPlanFixture? {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for _ in 0..<128 {
            let plan = director.plan(from: state)
            if let barIndex = plan.resolvedBars.firstIndex(where: {
                $0.modalPercussionArticulations.count == 2
            }) {
                return ModalPlanFixture(state: state, plan: plan, barIndex: barIndex)
            }
            state.advancePlanning(using: plan)
        }
        return nil
    }

    private func replacingModalArticulations(
        in fixture: ModalPlanFixture,
        with articulations: [ModalPercussionArticulation]
    ) -> AutonomousPhrasePlan {
        let source = fixture.plan.resolvedBars[fixture.barIndex]
        let changed = ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations: source.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            modalPercussionArticulations: articulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: source.kickSyntaxRole,
            percussionEchoTexture: source.percussionEchoTexture
        )
        var bars = fixture.plan.resolvedBars
        bars[fixture.barIndex] = changed
        return replacingResolvedBars(
            in: fixture.plan,
            with: bars,
            memory: fixture.state.memory
        )
    }

    private func replacing(
        _ source: ModalPercussionArticulation,
        scoreEventIndex: Int? = nil,
        step: Int? = nil,
        use: ModalPercussionUse? = nil,
        modalIdentity: ModalIdentity? = nil,
        modalDegree: Int? = nil,
        octave: Int? = nil,
        fundamentalHz: Double? = nil,
        excitation: Double? = nil,
        damping: Double? = nil,
        brightness: Double? = nil,
        inharmonicity: Double? = nil,
        eventIntensity: Double? = nil,
        seed: UInt64? = nil
    ) -> ModalPercussionArticulation {
        ModalPercussionArticulation(
            scoreEventIndex: scoreEventIndex ?? source.scoreEventIndex,
            step: step ?? source.step,
            use: use ?? source.use,
            modalIdentity: modalIdentity ?? source.modalIdentity,
            modalDegree: modalDegree ?? source.modalDegree,
            octave: octave ?? source.octave,
            fundamentalHz: fundamentalHz ?? source.fundamentalHz,
            excitation: excitation ?? source.excitation,
            damping: damping ?? source.damping,
            brightness: brightness ?? source.brightness,
            inharmonicity: inharmonicity ?? source.inharmonicity,
            eventIntensity: eventIntensity ?? source.eventIntensity,
            seed: seed ?? source.seed
        )
    }

    private func probePreparation(
        plan: AutonomousPhrasePlan,
        state: AutonomousSessionState
    ) -> (prepared: PreparedAutonomousPhrase?, cancellationCallCount: Int) {
        var renderState = RenderState()
        renderState.barIndex = plan.startBar
        let probe = InputGateCancellationProbe()
        let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: plan,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: renderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: probe.cancellationRequested
        )
        return (prepared, probe.callCount)
    }

    private func replacingResolvedBars(in plan: AutonomousPhrasePlan,
                                       with resolvedBars: [ResolvedPerformanceBar],
                                       memory: TemporalMusicalMemory) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            barCount: resolvedBars.count,
            kind: plan.kind,
            scene: plan.scene,
            dna: plan.dna,
            resolvedBars: resolvedBars,
            openedDebt: plan.openedDebt,
            paidDebtIDs: plan.paidDebtIDs,
            requestsTopologyMutation: plan.requestsTopologyMutation,
            interest: PhraseInterestEvaluator.evaluate(
                resolvedBars: resolvedBars,
                kind: plan.kind,
                memory: memory,
                identityPreserved: plan.scene.seed == plan.dna.sceneSeed
            ),
            endingInterlockState: plan.endingInterlockState,
            endingSpatialContrastState: plan.endingSpatialContrastState,
            endingNarrativeState: plan.endingNarrativeState,
            harmonicContinuation: plan.incomingHarmonicContinuation,
            longHorizonSelection: plan.longHorizonSelection,
            longHorizonEnergyCoordination:
                plan.longHorizonEnergyCoordination,
            materialWorld: plan.materialWorld
        )
    }

    private func prepare(state: AutonomousSessionState, sampleRate: Double,
                         renderState: RenderState = RenderState(),
                         graphState: GeneratedDSPContinuationState = GeneratedDSPContinuationState(),
                         previousGraph: DSPGraphPlan? = nil) -> PreparedAutonomousPhrase {
        let director = AutonomousSessionDirector(rootSeed: state.rootSeed)
        return AutonomousPhrasePreparer.prepare(
            plan: director.plan(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: sampleRate,
            incomingRenderState: renderState,
            incomingGraphState: graphState,
            previousGraph: previousGraph,
            incomingQualityState: state.quality,
            evaluator: AcceptingPrimaryTestEvaluator()
        )
    }
}
