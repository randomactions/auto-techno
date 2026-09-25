import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

/*
 Render-sensitive fixture warning: tests that call `homeProvenance()` initialize
 `homeCandidateFixture` through `AutonomousPhrasePreparer` at 8 kHz. Tests that
 call `diverseArtifacts()` initialize `transitionCandidateFixture` through
 `LiveFeedbackTestSupport.renderLiveTransitionCandidates()` at 44.1 kHz. A
 focused test filter can therefore render transient PCM even when the selected
 assertion is about metric policy. Check the helper call graph before running
 this suite while governed source/baseline inputs are modified.
 */
@Suite("Professional quality calibration")
struct ProfessionalQualityCalibrationTests {
    @Test("Failed metric direction reduces to bounded Core recovery intent")
    func recoveryIntentReductionIsDirectional() {
        let low = ProfessionalQualityRecoveryIntentReducer.reduce([
            ProfessionalQualityRecoveryFailure(
                metric: .spectralCentroidSpreadHz,
                value: 1_804,
                lowerBound: 8_243,
                upperBound: 15_846
            ),
            ProfessionalQualityRecoveryFailure(
                metric: .kickSourceCrestReductionDBMean,
                value: 1.187,
                lowerBound: 1.206,
                upperBound: 2.4
            ),
        ])
        let highKick = ProfessionalQualityRecoveryIntentReducer.reduce([
            ProfessionalQualityRecoveryFailure(
                metric: .kickSourceCrestReductionDBMean,
                value: 3.0,
                lowerBound: 1.2,
                upperBound: 2.4
            ),
        ])

        #expect(low.spectralMovement == .increase)
        #expect(low.kickCrestReduction == .increase)
        #expect(low.symbolicDensity == .hold)
        #expect(highKick.kickCrestReduction == .decrease)
    }

    @Test("Representative observations derive a deterministic vector profile")
    func deterministicProfile() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "representative-bank-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )

        #expect(profile.isComplete)
        #expect(!profile.fingerprint.isEmpty)
        let profileJSON = try profile.deterministicJSON()
        #expect(try profile.deterministicJSON() == profileJSON)
        #expect(try ProfessionalQualityCalibrationProfile
            .decodeDeterministicJSON(profileJSON) == profile)
        #expect(profile.checkpoints.map(\.checkpoint) ==
                CanonicalJourneyCheckpoint.allCases)
        for observation in observations {
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                observation, against: profile
            )
            #expect(verdict.accepted)
            #expect(verdict.reasons.isEmpty)
            #expect(verdict.failedMetrics.isEmpty)
        }
        let futureEngineObservation = try ProfessionalQualityObservation(
            engineVersion: "autotechno-canonical-engine.future-test",
            checkpoint: observations[0].checkpoint,
            sampleRate: observations[0].sampleRate,
            hardGatesPassed: observations[0].hardGatesPassed,
            liveMaster: observations[0].liveMaster,
            metrics: observations[0].metrics
        )
        #expect(ProfessionalQualityProfileEvaluator.evaluate(
            futureEngineObservation, against: profile
        ).accepted)

        let repeated = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "representative-bank-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: Array(observations.reversed())
        )
        #expect(repeated == profile)
        #expect(repeated.fingerprint == profile.fingerprint)
    }

    @Test("The adversarial suite rejects every non-compensable failure")
    @MainActor
    func adversarialSuite() throws {
        let liveCandidates = try transitionCandidates()
        let observations = try representativeObservations(
            liveCandidates: liveCandidates
        )
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "adversarial-bank-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        #expect(liveCandidates.isCausal)
        #expect(liveCandidates.attenuation.outgoingLiveMasterStateFingerprint ==
                liveCandidates.cleanHold.incomingLiveMasterStateFingerprint)
        #expect(liveCandidates.cleanHold.outgoingLiveMasterStateFingerprint ==
                liveCandidates.recovery.incomingLiveMasterStateFingerprint)
        #expect(liveCandidates.attenuation.liveProposalOutcome == .attenuate)
        #expect(liveCandidates.cleanHold.liveProposalOutcome == .hold)
        #expect(liveCandidates.recovery.liveProposalOutcome == .recover)
        #expect(liveCandidates.attenuationTransition.isCausal)
        #expect(liveCandidates.cleanHoldTransition.isCausal)
        #expect(liveCandidates.recoveryTransition.isCausal)
        #expect(liveCandidates.attenuationTransition.targetOccurrence ==
                liveCandidates.cleanHoldTransition.sourceOccurrence)
        #expect(liveCandidates.cleanHoldTransition.targetOccurrence ==
                liveCandidates.recoveryTransition.sourceOccurrence)
        for candidate in [
            liveCandidates.attenuation,
            liveCandidates.recovery,
        ] {
            let kind = try #require(AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ))
            let checkpoint = try #require(
                CanonicalJourneyCheckpoint.applicable(
                    phraseIndex: candidate.symbolic.phraseIndex,
                    phraseKind: kind,
                    chapterChanged: candidate.symbolic.chapterChanged
                ).first
            )
            let observation = try ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: checkpoint
            )
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                observation,
                against: profile
            )
            #expect(verdict.reasons.isEmpty)
            #expect(verdict.failedMetrics.isEmpty)
            #expect(verdict.accepted)
        }
        let suite = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceObservations: observations,
            liveCandidateChain: liveCandidates
        )

        #expect(suite.passed)
        #expect(suite.cases.count ==
                ProfessionalQualityAdversarialScenario.allCases.count)
        #expect(suite.cases.allSatisfy { $0.rejected && $0.passed })
        #expect(!suite.fingerprint.isEmpty)
        let suiteJSON = try suite.deterministicJSON()
        #expect(try suite.deterministicJSON() == suiteJSON)
        #expect(try ProfessionalQualityAdversarialSuiteReport
            .decodeDeterministicJSON(suiteJSON) == suite)
        #expect(suite.cases.first {
            $0.scenario == .hardGateCompensation
        }?.actualReasons.contains(.hardGateFailure) == true)
        #expect(suite.cases.first {
            $0.scenario == .silentProxy
        }?.failedMetrics.isEmpty == false)
        for (scenario, metric) in [
            (ProfessionalQualityAdversarialScenario.modalDetuning,
             ProfessionalQualityMetric.modalPercussionPitchErrorCentsMaximum),
            (.modalRunawayTail, .modalPercussionTailToBodyDBMean),
            (.modalMaskingFlood, .modalPercussionMaskingMaximumOverlap),
            (.modalRateDrift, .modalPercussionSpectralCentroidMeanHz),
            (.upperPercussionTailRegression,
             .upperPercussionTailRenderedTailToAttackDBMean),
            (.foundationPreKickPocketContamination,
             .foundationPreKickPocketSilenceRMSMaximum),
            (.climaxHangContamination,
             .climaxHangSilenceRMSMaximum),
        ] {
            let attacked = try #require(suite.cases.first {
                $0.scenario == scenario
            })
            #expect(attacked.rejected)
            #expect(attacked.failedMetrics.contains(metric))
        }
        for (scenario, reason) in [
            (ProfessionalQualityAdversarialScenario.forgedPreTerminalScaling,
             ProfessionalQualityRejection.liveTerminalScalingFailure),
            (.forgedPostTerminalScaling, .liveTerminalScalingFailure),
            (.masterBoostAboveUnity, .liveBoostRejected),
            (.liveOverAttack, .liveTransitionOutOfBounds),
            (.liveEarlyRecovery, .liveEarlyRecovery),
            (.staleLiveRouteGeneration, .liveRouteBoundaryFailure),
            (.liveEarlyBoundary, .liveRouteBoundaryFailure),
            (.staleLiveControllerRevision, .liveControllerMismatch),
            (.unboundLiveProposalFingerprint, .liveProposalMismatch),
        ] {
            let attacked = try #require(suite.cases.first {
                $0.scenario == scenario
            })
            #expect(attacked.rejected)
            #expect(attacked.expectedReasons.contains(reason))
            #expect(attacked.actualReasons == attacked.expectedReasons)
            #expect(attacked.failedMetrics.isEmpty)
        }
        #expect(suite.liveBaselineAcceptanceCount == 2)
        #expect(suite.liveBaselineObservationFingerprints.count == 2)
    }

    @Test("Live adversarial candidates require one exact App-owned occurrence timeline")
    @MainActor
    func adversarialLiveOccurrenceTimelineRejectsMutations() throws {
        let chain = try transitionCandidates()
        let transition = chain.attenuationTransition
        let source = transition.sourceOccurrence
        let target = transition.targetOccurrence
        #expect(transition.isCausal)

        let forgedSourceController = copyOccurrence(
            source,
            controllerStateFingerprint: "aaaaaaaaaaaaaaaa"
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: forgedSourceController,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: target,
                candidate: transition.candidate
            )
        }

        let forgedTargetController = copyOccurrence(
            target,
            controllerStateFingerprint: "dddddddddddddddd"
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: source,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: forgedTargetController,
                candidate: transition.candidate
            )
        }

        let forgedSourcePlan = copyOccurrence(
            source,
            planFingerprint: "bbbbbbbbbbbbbbbb"
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: forgedSourcePlan,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: target,
                candidate: transition.candidate
            )
        }

        let forgedTargetPlan = copyOccurrence(
            target,
            planFingerprint: "cccccccccccccccc"
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: source,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: forgedTargetPlan,
                candidate: transition.candidate
            )
        }

        let forgedSourceRate = copyOccurrence(
            source,
            sampleRate: 48_000
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: forgedSourceRate,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: target,
                candidate: transition.candidate
            )
        }

        let forgedSourceRoute = copyOccurrence(
            source,
            routeGeneration: source.routeGeneration + 1
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: forgedSourceRoute,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: target,
                candidate: transition.candidate
            )
        }

        let forgedTargetEpoch = copyOccurrence(
            target,
            occurrenceEpoch: target.occurrenceEpoch + 1
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: source,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: forgedTargetEpoch,
                candidate: transition.candidate
            )
        }

        let shortSource = copyOccurrence(
            source,
            playerSampleRange: source.playerSampleRange.lowerBound..<(source
                .capturePlayerSampleRange.upperBound - 1)
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: shortSource,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: target,
                candidate: transition.candidate
            )
        }

        let shiftedTarget = copyOccurrence(
            target,
            playerSampleRange:
                (target.playerSampleRange.lowerBound + 1)..<(target
                    .playerSampleRange.upperBound + 1)
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: source,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: shiftedTarget,
                candidate: transition.candidate
            )
        }

        let shiftedBoundary = source.playerSampleRange.upperBound + 1
        let forgedSource = copyOccurrence(
            source,
            playerSampleRange:
                source.playerSampleRange.lowerBound..<shiftedBoundary
        )
        let forgedTarget = copyOccurrence(
            target,
            playerSampleRange: shiftedBoundary..<(shiftedBoundary +
                Int64(target.playerSampleRange.count))
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityLiveCandidateTransitionEvidence(
                sourceOccurrence: forgedSource,
                captureEvidence: transition.captureEvidence,
                targetOccurrence: forgedTarget,
                candidate: transition.candidate
            )
        }
    }

    @Test("Candidate projection matches foundation and climax evidence")
    func foundationClimaxProjectionMatchesEvidence() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        func expected(_ metric: ProfessionalQualityMetric) throws -> Double {
            try #require(observation[metric])
        }
        func mean(_ values: [Double]) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
        func ratioDB(_ numerator: Double, _ denominator: Double) -> Double {
            guard numerator > 0, denominator > 0 else { return -120 }
            return min(120, max(-120,
                20 * (log10(numerator) - log10(denominator))
            ))
        }

        let dottedBars = candidate.foundationRhythm.filter {
            $0.relation == FoundationRhythmicRelation.dottedThreeSixteenth.rawValue
        }
        let expectedDottedRatio = Double(dottedBars.count) /
            Double(max(1, candidate.foundationRhythm.count))
        let expectedDottedCrest = mean(dottedBars.map {
            ratioDB($0.peak, $0.rms)
        })
        #expect(try expected(.foundationDottedRhythmActiveBarRatio) ==
                expectedDottedRatio)
        #expect(try expected(.foundationDottedRhythmCrestFactorDBMean) ==
                expectedDottedCrest)
        #expect(try expected(.foundationPreKickPocketSilenceRMSMaximum) ==
                (dottedBars.map(\.preKickPocket.silenceRMS).max() ?? 0))
        #expect(dottedBars.allSatisfy {
            $0.preKickPocket.silencePeak == 0 && $0.preKickPocket.silenceRMS == 0
        }, "Complete pre-kick pocket evidence structurally enforces digital silence")

        let hang = candidate.climaxArc.hang
        #expect(try expected(.climaxHangSilenceRMSMaximum) ==
                (hang.active ? hang.silenceRMS : 0))
        #expect(!hang.active || (hang.silencePeak == 0 && hang.silenceRMS == 0),
                "Complete active hang evidence structurally enforces digital silence")
    }

    @Test("Dotted-rhythm crest mean follows selected complete-candidate bars")
    func dottedRhythmCrestPopulationAcrossCandidates() throws {
        var candidates: [AutonomousCandidateEvaluationVector] = []
        var selectedBarCounts = Set<Int>()

        search: for seed in [UInt64(1), 42, 48_291, 91_773] {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<24 {
                let plan = director.plan(from: state)
                let plannedDottedCount = plan.resolvedBars.filter {
                    $0.foundationRhythmicRelation == .dottedThreeSixteenth
                }.count
                guard plannedDottedCount > 0 else {
                    state.advancePlanning(using: plan)
                    continue
                }
                var renderState = RenderState()
                renderState.barIndex = plan.startBar
                guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                    plan: plan,
                    sessionSeed: state.rootSeed,
                    memory: state.memory,
                    sampleRate: 8_000,
                    incomingRenderState: renderState,
                    incomingGraphState: GeneratedDSPContinuationState(),
                    previousGraph: nil,
                    incomingQualityState: state.quality,
                    evaluator: AcceptingPrimaryTestEvaluator(),
                    cancellationRequested: { false }
                ), prepared.selectedCandidateEvidence.isComplete else {
                    Issue.record("Dotted-rhythm candidate preparation failed for seed \(seed)")
                    break search
                }
                let candidate = prepared.selectedCandidateEvidence
                let selectedCount = candidate.foundationRhythm.filter {
                    $0.relation == FoundationRhythmicRelation.dottedThreeSixteenth.rawValue
                }.count
                if selectedCount > 0 && selectedBarCounts.insert(selectedCount).inserted {
                    candidates.append(candidate)
                }
                if selectedBarCounts.count >= 2 { break search }
                state.advancePlanning(using: plan)
            }
        }

        #expect(candidates.count >= 2,
                "Complete candidates must expose distinct selected dotted-bar populations")
        #expect(selectedBarCounts.count >= 2)
        for candidate in candidates {
            let phraseKind = try #require(AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ))
            let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: phraseKind,
                chapterChanged: candidate.symbolic.chapterChanged
            ).first)
            let observation = try ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: checkpoint
            )
            let selectedBars = candidate.foundationRhythm.filter {
                $0.relation == FoundationRhythmicRelation.dottedThreeSixteenth.rawValue
            }
            let expected = selectedBars.map { bar -> Double in
                guard bar.peak > 0, bar.rms > 0 else { return -120 }
                return min(120, max(-120,
                    20 * (log10(bar.peak) - log10(bar.rms))
                ))
            }
            let expectedMean = expected.isEmpty ? 0 :
                expected.reduce(0, +) / Double(expected.count)
            #expect(observation[.foundationDottedRhythmCrestFactorDBMean] == expectedMean)
            #expect(expected.count == selectedBars.count)
        }
    }

    @Test("Candidate projection matches kick score and source evidence")
    func kickProjectionMatchesEvidence() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        func expected(_ metric: ProfessionalQualityMetric) throws -> Double {
            try #require(observation[metric])
        }
        func mean(_ values: [Double]) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
        func ratioDB(_ numerator: Double, _ denominator: Double) -> Double {
            guard numerator > 0, denominator > 0 else { return -120 }
            return min(120, max(-120,
                20 * (log10(numerator) - log10(denominator))
            ))
        }

        let syntax = candidate.kickSyntax
        let activeSyntax = syntax.filter {
            $0.detectorRMS > 0 && $0.audibleRMS > 0
        }
        #expect(!syntax.isEmpty)
        #expect(!activeSyntax.isEmpty)
        let roles = syntax.compactMap { KickSyntaxRole(rawValue: $0.role) }
        let roleRatio: (KickSyntaxRole) -> Double = { role in
            Double(roles.filter { $0 == role }.count) / Double(max(1, syntax.count))
        }
        var pairedKickFoundationDB: [Double] = []
        for stemBar in candidate.stems {
            guard let kick = stemBar.roles.first(where: {
                $0.role == MixRole.kick.rawValue
            }), let foundation = stemBar.roles.first(where: {
                $0.role == MixRole.foundation.rawValue
            }), kick.activeRMS > 0, foundation.activeRMS > 0 else { continue }
            pairedKickFoundationDB.append(ratioDB(kick.activeRMS, foundation.activeRMS))
        }
        let kickFoundationRatio = candidate.stems.isEmpty ? 0 :
            Double(pairedKickFoundationDB.count) / Double(candidate.stems.count)
        #expect(try expected(.activeKickFoundationBarRatio) == kickFoundationRatio)
        #expect(try expected(.kickOverFoundationActiveDBMean) ==
                mean(pairedKickFoundationDB))
        #expect(try expected(.kickGroundedBarRatio) == roleRatio(.grounded))
        #expect(try expected(.kickWithheldBarRatio) == roleRatio(.withheld))
        #expect(try expected(.kickRecoveryBarRatio) == roleRatio(.recovery))
        #expect(try expected(.kickEventCountMean) == mean(
            syntax.map { Double($0.scoreKickEventCount) }
        ))
        #expect(try expected(.kickAudibleToDetectorDBMean) == mean(
            activeSyntax.map { ratioDB($0.audibleRMS, $0.detectorRMS) }
        ))
        #expect(try expected(.kickDuckingEnvelopeRatioMean) == mean(
            activeSyntax.map { $0.duckingEnvelopePeak / max($0.detectorPeak, 1e-12) }
        ))
        #expect(try expected(.kickAudibleGainMean) ==
                mean(syntax.map(\.audibleGain)))
        #expect(try expected(.kickSourceOutputCrestFactorDBMean) == mean(
            activeSyntax.map { ratioDB($0.sourceDynamics.outputPeak, $0.sourceDynamics.outputRMS) }
        ))
        #expect(try expected(.kickSourceAttackToBodyDBMean) == mean(
            activeSyntax.map {
                ratioDB($0.sourceDynamics.outputAttackRMS, $0.sourceDynamics.outputBodyRMS)
            }
        ))
        #expect(try expected(.kickSourceUpperMidEnergyRatioMean) == mean(
            activeSyntax.map(\.sourceDynamics.outputUpperMidEnergyRatio)
        ))
        #expect(try expected(.kickSourceCrestReductionDBMean) == mean(
            activeSyntax.map {
                ratioDB($0.sourceDynamics.inputCrestFactor,
                        $0.sourceDynamics.outputCrestFactor)
            }
        ))
    }

    @Test("Kick-foundation metrics follow varied complete paired-bar populations")
    func kickFoundationPairingPopulationProjectionAcrossCandidates() throws {
        var statefulCandidates: [AutonomousCandidateEvaluationVector] = []
        var seenScorePairCounts = Set<Int>()
        var seenScoreKickEventTotals = Set<Int>()
        var distinctRenderedPairCounts = Set<Int>()
        var distinctKickEventTotals = Set<Int>()
        var distinctRolePopulations = Set<String>()
        var distinctActiveKickBarCounts = Set<Int>()

        search: for seed in [UInt64(1), 42, 48_291, 91_773] {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<16 {
                let plan = director.plan(from: state)
                let scorePairCount = plan.resolvedBars.filter { bar in
                    bar.ensemble.events.contains { $0.voice == .kick } &&
                        bar.ensemble.events.contains {
                            $0.voice == .bass || $0.voice == .rumble ||
                                $0.voice == .tunedTom
                        }
                }.count
                let scoreKickEventTotal = plan.resolvedBars.reduce(0) {
                    total, bar in
                    total + bar.ensemble.events.filter { $0.voice == .kick }.count
                }
                let newScorePairCount =
                    seenScorePairCounts.insert(scorePairCount).inserted
                let newScoreKickEventTotal =
                    seenScoreKickEventTotals.insert(scoreKickEventTotal).inserted
                let scorePopulationIsNew =
                    newScorePairCount || newScoreKickEventTotal
                if scorePopulationIsNew {
                    var renderState = RenderState()
                    renderState.barIndex = plan.startBar
                    if let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                        plan: plan,
                        sessionSeed: state.rootSeed,
                        memory: state.memory,
                        sampleRate: 8_000,
                        incomingRenderState: renderState,
                        incomingGraphState: GeneratedDSPContinuationState(),
                        previousGraph: nil,
                        incomingQualityState: state.quality,
                        evaluator: AcceptingPrimaryTestEvaluator(),
                        cancellationRequested: { false }
                    ), prepared.selectedCandidateEvidence.isComplete {
                        let candidate = prepared.selectedCandidateEvidence
                        let pairCount = candidate.stems.filter { stem in
                            guard let kick = stem.roles.first(where: {
                                $0.role == MixRole.kick.rawValue
                            }), let foundation = stem.roles.first(where: {
                                $0.role == MixRole.foundation.rawValue
                            }) else { return false }
                            return kick.activeRMS > 0 && foundation.activeRMS > 0
                        }.count
                        let kickEventTotal = candidate.kickSyntax.reduce(0) {
                            $0 + $1.scoreKickEventCount
                        }
                        let roleCounts = candidate.kickSyntax.compactMap {
                            KickSyntaxRole(rawValue: $0.role)
                        }
                        let rolePopulation = [
                            KickSyntaxRole.grounded,
                            .withheld,
                            .recovery,
                        ].map { role in roleCounts.filter { $0 == role }.count }
                        let newRolePopulation = distinctRolePopulations.insert(
                            rolePopulation.map { String($0) }.joined(separator: ":")
                        ).inserted
                        let activeKickBarCount = candidate.kickSyntax.filter {
                            $0.detectorRMS > 0 && $0.audibleRMS > 0
                        }.count
                        let newActiveKickPopulation =
                            distinctActiveKickBarCounts.insert(activeKickBarCount).inserted
                        let newRenderedPairCount =
                            distinctRenderedPairCounts.insert(pairCount).inserted
                        let newKickEventTotal =
                            distinctKickEventTotals.insert(kickEventTotal).inserted
                        let hasNewPopulation = newRenderedPairCount ||
                            newKickEventTotal || newRolePopulation ||
                            newActiveKickPopulation
                        if hasNewPopulation {
                            statefulCandidates.append(candidate)
                            if distinctRenderedPairCounts.count >= 2 &&
                                distinctKickEventTotals.count >= 2 &&
                                distinctRolePopulations.count >= 2 &&
                                distinctActiveKickBarCounts.count >= 2 {
                                break search
                            }
                        }
                    }
                }
                state.advancePlanning(using: plan)
            }
        }

        #expect(statefulCandidates.count >= 2,
                "Deterministic prepared candidates must expose different paired-bar and kick-event populations")
        #expect(distinctRenderedPairCounts.count >= 2)
        #expect(distinctKickEventTotals.count >= 2)
        #expect(distinctRolePopulations.count >= 2,
                "Candidates must expose distinct authored grounded/withheld/recovery bar populations")
        #expect(distinctActiveKickBarCounts.count >= 2,
                "Candidates must expose distinct audible active-kick populations")
        for candidate in statefulCandidates {
            let phraseKind = try #require(AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ))
            let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: phraseKind,
                chapterChanged: candidate.symbolic.chapterChanged
            ).first)
            let observation = try ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: checkpoint
            )
            func ratioDB(_ numerator: Double, _ denominator: Double) -> Double {
                guard numerator > 0, denominator > 0 else { return -120 }
                return min(120, max(-120,
                    20 * (log10(numerator) - log10(denominator))
                ))
            }
            let pairedDB = candidate.stems.compactMap { stem -> Double? in
                guard let kick = stem.roles.first(where: {
                    $0.role == MixRole.kick.rawValue
                }), let foundation = stem.roles.first(where: {
                    $0.role == MixRole.foundation.rawValue
                }), kick.activeRMS > 0, foundation.activeRMS > 0 else {
                    return nil
                }
                return ratioDB(kick.activeRMS, foundation.activeRMS)
            }
            let expectedRatio = Double(pairedDB.count) /
                Double(candidate.stems.count)
            let expectedBalance = pairedDB.isEmpty
                ? 0
                : pairedDB.reduce(0, +) / Double(pairedDB.count)

            #expect(candidate.stems.count == candidate.sourceStemBarCount)
            #expect(observation[.activeKickFoundationBarRatio] == expectedRatio)
            #expect(observation[.kickOverFoundationActiveDBMean] == expectedBalance)
            let syntax = candidate.kickSyntax
            let syntaxRoles = syntax.compactMap {
                KickSyntaxRole(rawValue: $0.role)
            }
            func roleRatio(_ role: KickSyntaxRole) -> Double {
                Double(syntaxRoles.filter { $0 == role }.count) /
                    Double(max(1, syntax.count))
            }
            #expect(observation[.kickGroundedBarRatio] == roleRatio(.grounded))
            #expect(observation[.kickWithheldBarRatio] == roleRatio(.withheld))
            #expect(observation[.kickRecoveryBarRatio] == roleRatio(.recovery))
            let expectedKickEventCountMean = candidate.kickSyntax.isEmpty
                ? 0
                : Double(candidate.kickSyntax.reduce(0) {
                    $0 + $1.scoreKickEventCount
                }) / Double(candidate.kickSyntax.count)
            #expect(observation[.kickEventCountMean] == expectedKickEventCountMean)
            func mean(_ values: [Double]) -> Double {
                values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            }
            let activeSyntax = syntax.filter {
                $0.detectorRMS > 0 && $0.audibleRMS > 0
            }
            #expect(observation[.kickAudibleToDetectorDBMean] == mean(
                activeSyntax.map { ratioDB($0.audibleRMS, $0.detectorRMS) }
            ))
            #expect(observation[.kickDuckingEnvelopeRatioMean] == mean(
                activeSyntax.map {
                    $0.duckingEnvelopePeak / max($0.detectorPeak, 1e-12)
                }
            ))
            #expect(observation[.kickAudibleGainMean] == mean(
                syntax.map(\.audibleGain)
            ))
            #expect(observation[.kickSourceOutputCrestFactorDBMean] == mean(
                activeSyntax.map {
                    ratioDB($0.sourceDynamics.outputPeak,
                            $0.sourceDynamics.outputRMS)
                }
            ))
            #expect(observation[.kickSourceAttackToBodyDBMean] == mean(
                activeSyntax.map {
                    ratioDB($0.sourceDynamics.outputAttackRMS,
                            $0.sourceDynamics.outputBodyRMS)
                }
            ))
            #expect(observation[.kickSourceUpperMidEnergyRatioMean] == mean(
                activeSyntax.map(\.sourceDynamics.outputUpperMidEnergyRatio)
            ))
            #expect(observation[.kickSourceCrestReductionDBMean] == mean(
                activeSyntax.map {
                    ratioDB($0.sourceDynamics.inputCrestFactor,
                            $0.sourceDynamics.outputCrestFactor)
                }
            ))
            #expect(observation.measurementIsApplicable(
                .kickOverFoundationActiveDBMean
            ) == !pairedDB.isEmpty)
        }
    }

    @Test("Candidate projection matches whole-mix and streaming evidence")
    func wholeMixStreamingProjectionMatchesEvidence() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        func expected(_ metric: ProfessionalQualityMetric) throws -> Double {
            try #require(observation[metric])
        }
        func mean(_ values: [Double]) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
        func span(_ values: [Double]) -> Double {
            guard let minimum = values.min(), let maximum = values.max() else {
                return 0
            }
            return maximum - minimum
        }
        func ratioDB(_ numerator: Double, _ denominator: Double) -> Double {
            guard numerator > 0, denominator > 0 else { return -120 }
            return min(120, max(-120,
                20 * (log10(numerator) - log10(denominator))
            ))
        }
        func spanContribution(_ values: [Double], scale: Double) -> Double {
            guard let minimum = values.min(), let maximum = values.max() else {
                return 0
            }
            return min(1, (maximum - minimum) / scale)
        }

        let fullMix = try #require(candidate.fullMix)
        let perceptual = fullMix.perceptual
        let bars = fullMix.bars
        #expect(perceptual.isComplete)
        #expect(perceptual.analyzedWindowCount > 0)
        #expect(!bars.isEmpty)
        let perBarExtremaInputs = [
            bars.map(\.loudness),
            bars.map(\.spectralCentroid),
            bars.map(\.crestFactor),
        ]
        for values in perBarExtremaInputs {
            #expect((values.min() ?? 0) < (values.max() ?? 0))
        }
        #expect(try expected(.integratedLoudnessLUFS) == fullMix.integratedLoudness)
        #expect(try expected(.maximumMomentaryLoudnessLUFS) ==
                fullMix.maximumMomentaryLoudness)
        #expect(try expected(.maximumShortTermLoudnessLUFS) ==
                fullMix.maximumShortTermLoudness)
        #expect(try expected(.loudnessRangeLU) == fullMix.loudnessRange)
        #expect(try expected(.truePeakDBTP) == fullMix.truePeakDBTP)
        #expect(try expected(.crestFactorDB) ==
                ratioDB(fullMix.peak, fullMix.rms))
        #expect(try expected(.absoluteDCOffset) == abs(fullMix.dcOffset))
        #expect(try expected(.stereoCorrelation) == fullMix.stereoCorrelation)
        #expect(try expected(.lowStereoCorrelation) == fullMix.lowStereoCorrelation)
        #expect(try expected(.maximumBoundaryDelta) == fullMix.maximumBoundaryDelta)
        #expect(try expected(.movementScore) == fullMix.movementScore)
        let independentlyDerivedMovementScore =
            spanContribution(bars.map(\.loudness), scale: 8) * 0.34 +
            spanContribution(bars.map(\.spectralCentroid), scale: 800) * 0.24 +
            spanContribution(bars.map(\.transientDensity), scale: 2.5) * 0.22 +
            spanContribution(bars.map(\.crestFactor), scale: 3) * 0.20
        #expect(abs(fullMix.movementScore - independentlyDerivedMovementScore) < 1e-12)
        #expect(try expected(.activeWindowRatio) ==
                Double(perceptual.activeWindowCount) /
                    Double(perceptual.analyzedWindowCount))
        #expect(try expected(.spectralCentroidMeanHz) ==
                perceptual.spectralCentroidMeanHz)
        #expect(try expected(.spectralCentroidSpreadHz) ==
                perceptual.spectralCentroidSpreadHz)
        #expect(try expected(.spectralBandwidthMeanHz) ==
                perceptual.spectralBandwidthMeanHz)
        #expect(try expected(.spectralFlatnessMean) == perceptual.spectralFlatnessMean)
        #expect(try expected(.spectralRolloff85MeanHz) ==
                perceptual.spectralRolloff85MeanHz)
        #expect(try expected(.positiveSpectralFluxMean) ==
                perceptual.positiveSpectralFluxMean)
        #expect(try expected(.positiveSpectralFluxPeak) ==
                perceptual.positiveSpectralFluxPeak)
        #expect(try expected(.rmsTrajectoryDeltaMeanDB) ==
                perceptual.rmsTrajectoryDeltaMeanDB)
        #expect(try expected(.rmsTrajectoryDeltaPeakDB) ==
                perceptual.rmsTrajectoryDeltaPeakDB)
        #expect(try expected(.barLoudnessSpanLU) == span(bars.map(\.loudness)))
        #expect(try expected(.barCentroidSpanHz) ==
                span(bars.map(\.spectralCentroid)))
        #expect(try expected(.barTransientDensityMean) ==
                mean(bars.map(\.transientDensity)))
        #expect(try expected(.barTransientDensitySpan) ==
                span(bars.map(\.transientDensity)))
        #expect(try expected(.barCrestFactorMean) ==
                mean(bars.map(\.crestFactor)))
        #expect(try expected(.barCrestFactorSpan) == span(bars.map(\.crestFactor)))
    }

    @Test("Transient-density span follows varied rendered bar evidence")
    func transientDensitySpanAcrossRenderedBars() throws {
        var selected: AutonomousCandidateEvaluationVector?

        search: for seed in [UInt64(91_773), 48_291, 42, 1, 2026] {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<24 {
                let plan = director.plan(from: state)
                let authoredEventCounts = plan.resolvedBars.map {
                    $0.ensemble.events.count
                }
                if Set(authoredEventCounts).count > 1 {
                    var renderState = RenderState()
                    renderState.barIndex = plan.startBar
                    if let prepared = AutonomousPhrasePreparer
                        .prepareIfNotCancelled(
                            plan: plan,
                            sessionSeed: state.rootSeed,
                            memory: state.memory,
                            sampleRate: 8_000,
                            incomingRenderState: renderState,
                            incomingGraphState:
                                GeneratedDSPContinuationState(),
                            previousGraph: nil,
                            incomingQualityState: state.quality,
                            evaluator: AcceptingPrimaryTestEvaluator(),
                            cancellationRequested: { false }
                        ), prepared.selectedCandidateEvidence.isComplete {
                        let values = prepared.selectedCandidateEvidence
                            .fullMix.bars.map(\.transientDensity)
                        if let minimum = values.min(),
                           let maximum = values.max(), maximum > minimum,
                           let phraseKind = AutonomousPhraseKind(
                            rawValue: prepared.selectedCandidateEvidence
                                .symbolic.phraseKind
                           ), !CanonicalJourneyCheckpoint.applicable(
                            phraseIndex: prepared.selectedCandidateEvidence
                                .symbolic.phraseIndex,
                            phraseKind: phraseKind,
                            chapterChanged: prepared.selectedCandidateEvidence
                                .symbolic.chapterChanged
                           ).isEmpty {
                            selected = prepared.selectedCandidateEvidence
                            break search
                        }
                    }
                }
                state.advancePlanning(using: plan)
            }
        }

        let candidate = try #require(selected)
        let fullMix = try #require(candidate.fullMix)
        let densities = fullMix.bars.map(\.transientDensity)
        #expect((densities.min() ?? 0) < (densities.max() ?? 0))
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        let mean = densities.reduce(0, +) / Double(densities.count)
        let span = (densities.max() ?? 0) - (densities.min() ?? 0)
        #expect(observation[.barTransientDensityMean] == mean)
        #expect(observation[.barTransientDensitySpan] == span)
    }

    @Test("Candidate projection matches bar-masking evidence")
    func maskingProjectionMatchesEvidence() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        func expected(_ metric: ProfessionalQualityMetric) throws -> Double {
            try #require(observation[metric])
        }

        let fullMix = try #require(candidate.fullMix)
        let masking = candidate.masking.flatMap(\.observations)
        #expect(!masking.isEmpty)
        #expect(candidate.masking.count == fullMix.bars.count)
        #expect(candidate.masking.allSatisfy { $0.observations.count == 12 })
        #expect(masking.allSatisfy {
            $0.analyzedWindowCount == SpectrumMaskingAnalyzer.analyzedWindowCount
        })
        let analyzedWindows = masking.reduce(0) {
            $0 + $1.analyzedWindowCount
        }
        let overlapWindows = masking.reduce(0) {
            $0 + $1.overlapWindowCount
        }
        let longestRun = masking.map(\.longestOverlapRun).max() ?? 0
        #expect(try expected(.maskingMaximumOverlap) ==
                (masking.map(\.maximumOverlap).max() ?? 0))
        #expect(try expected(.maskingOverlapWindowRatio) ==
                (analyzedWindows == 0 ? 0 :
                    Double(overlapWindows) / Double(analyzedWindows)))
        #expect(try expected(.maskingLongestRunRatio) ==
                (analyzedWindows == 0 ? 0 :
                    Double(longestRun) /
                        Double(SpectrumMaskingAnalyzer.analyzedWindowCount)))
        #expect(analyzedWindows ==
                candidate.masking.count * 12 *
                    SpectrumMaskingAnalyzer.analyzedWindowCount)
    }

    @Test("Candidate projection matches spectral-reveal and harmonic-tail evidence")
    func spectralRevealAndHarmonicTailProjectionMatchesEvidence() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        func expected(_ metric: ProfessionalQualityMetric) throws -> Double {
            try #require(observation[metric])
        }
        func mean(_ values: [Double]) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }

        let architectures = candidate.instruments.flatMap(\.architectures)
        let revealEvidence = architectures.compactMap(\.upperSpectralReveal)
        let activeRevealEvidence = revealEvidence.filter(\.active)
        let eligibleEventCount = revealEvidence.filter(\.eligible).reduce(0) {
            $0 + $1.renderedEventCount
        }
        let activeEventCount = activeRevealEvidence.reduce(0) {
            $0 + $1.activeEventCount
        }
        let revealRatio: Double
        if eligibleEventCount == 0 {
            revealRatio = activeEventCount == 0 ? 1 : 0
        } else if activeEventCount < 0 || activeEventCount > eligibleEventCount {
            revealRatio = 0
        } else {
            revealRatio = Double(activeEventCount) / Double(eligibleEventCount)
        }
        #expect(try expected(.upperSpectralRevealActiveEventRatio) == revealRatio)
        #expect(try expected(.upperSpectralRevealAppliedCutoffRatioMean) ==
                mean(activeRevealEvidence.map {
                    $0.maximumAppliedCutoffHz / candidate.routeContinuation.sampleRate
                }))

        let harmonicTailEvidence = architectures.compactMap(
            \.spectralTextureHarmonicTail
        )
        #expect(try expected(.spectralHarmonicTailUpperBandEnergyRatioMean) ==
                (harmonicTailEvidence.isEmpty ? 1 :
                    mean(harmonicTailEvidence.map(\.upperBandEnergyRatio))))
    }

    @Test("Active spectral reveal projects rendered eligible events")
    func activeSpectralRevealProjectionMatchesEvidence() throws {
        let candidate = try candidateWithActiveSpectralReveal()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        let reveal = candidate.instruments.flatMap(\.architectures)
            .compactMap(\.upperSpectralReveal)
        let eligibleEventCount = reveal.filter(\.eligible).reduce(0) {
            $0 + $1.renderedEventCount
        }
        let activeReveal = reveal.filter(\.active)
        let activeEventCount = activeReveal.reduce(0) {
            $0 + $1.activeEventCount
        }
        #expect(eligibleEventCount > 0)
        #expect(activeEventCount > 0)
        #expect(observation[.upperSpectralRevealActiveEventRatio] ==
                Double(activeEventCount) / Double(eligibleEventCount))
        #expect(observation[.upperSpectralRevealAppliedCutoffRatioMean] ==
                activeReveal.map {
                    $0.maximumAppliedCutoffHz /
                        candidate.routeContinuation.sampleRate
                }.reduce(0, +) / Double(activeReveal.count))
    }

    @Test("Spectral reveal ratio follows varied eligible event populations")
    func spectralRevealPopulationAcrossCandidates() throws {
        var candidates: [AutonomousCandidateEvaluationVector] = []
        var populations = Set<String>()

        search: for seed in UInt64(1)...1_024 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let plan = director.plan(from: state)
            let synthPlan = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars,
                compositionBars: plan.phraseComposition
            )
            let hasActiveAnchor = synthPlan.bars.contains { bar in
                bar.spectralRevealEligible && bar.upperNotes.contains {
                    $0.role == .anchor &&
                        $0.spectralReveal.relation == .emerging
                }
            }
            guard hasActiveAnchor else { continue }
            var renderState = RenderState()
            renderState.barIndex = plan.startBar
            guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: renderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator(),
                cancellationRequested: { false }
            ), prepared.selectedCandidateEvidence.isComplete else {
                Issue.record("Spectral-reveal candidate preparation failed for seed \(seed)")
                break search
            }
            let candidate = prepared.selectedCandidateEvidence
            let reveal = candidate.instruments.flatMap(\.architectures)
                .compactMap(\.upperSpectralReveal)
            let eligibleEvents = reveal.filter(\.eligible).reduce(0) {
                $0 + $1.renderedEventCount
            }
            let activeEvents = reveal.filter(\.active).reduce(0) {
                $0 + $1.activeEventCount
            }
            guard eligibleEvents > 0, activeEvents > 0,
                  activeEvents <= eligibleEvents else { continue }
            if populations.insert("\(eligibleEvents):\(activeEvents)").inserted {
                candidates.append(candidate)
            }
            if candidates.count == 2 { break search }
        }

        #expect(candidates.count == 2,
                "Two complete candidates must expose distinct eligible/active reveal populations")
        #expect(populations.count == 2)
        for candidate in candidates {
            let phraseKind = try #require(AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ))
            let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: phraseKind,
                chapterChanged: candidate.symbolic.chapterChanged
            ).first)
            let observation = try ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: checkpoint
            )
            let reveal = candidate.instruments.flatMap(\.architectures)
                .compactMap(\.upperSpectralReveal)
            let eligibleEvents = reveal.filter(\.eligible).reduce(0) {
                $0 + $1.renderedEventCount
            }
            let activeEvents = reveal.filter(\.active).reduce(0) {
                $0 + $1.activeEventCount
            }
            #expect(eligibleEvents > 0)
            #expect(activeEvents > 0 && activeEvents <= eligibleEvents)
            #expect(observation[.upperSpectralRevealActiveEventRatio] ==
                    Double(activeEvents) / Double(eligibleEvents))
        }
    }

    @Test("Pad projections follow varied phrase and modulation populations")
    func padPopulationProjectionsAcrossCandidates() throws {
        let director = AutonomousSessionDirector(rootSeed: 91_773)
        var state = director.initialState()
        var candidates: [AutonomousCandidateEvaluationVector] = []
        var populationSignatures = Set<String>()

        search: for _ in 0..<128 {
            let plan = director.plan(from: state)
            let selectedModulationCount = plan.phraseComposition.filter {
                $0.padVoicing?.rhythmicModulation.active == true
            }.count
            guard selectedModulationCount > 0 else {
                state.advancePlanning(using: plan)
                continue
            }
            var renderState = RenderState()
            renderState.barIndex = state.memory.totalBars
            let prepared = AutonomousPhrasePreparer.prepare(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: renderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator()
            )
            let candidate = prepared.selectedCandidateEvidence
            guard candidate.isComplete,
                  candidate.phraseComposition.count == plan.barCount else {
                Issue.record("Prepared pad candidate is incomplete")
                break search
            }
            let activeModulationCount = candidate.phraseComposition.filter {
                $0.padRhythmicModulationRelation ==
                    PadRhythmicModulationRelation.threeStepPulse.rawValue
            }.count
            let revealedCount = candidate.phraseComposition.filter {
                $0.padActive && $0.padHarmonicDisclosureStage ==
                    PadHarmonicDisclosureStage.revealed.rawValue
            }.count
            let signature = "\(candidate.phraseComposition.count):\(activeModulationCount):\(revealedCount)"
            if populationSignatures.insert(signature).inserted {
                candidates.append(candidate)
            }
            if candidates.count == 2 { break search }
            state.advancePlanning(using: plan)
        }

        #expect(candidates.count == 2,
                "Complete pad candidates must expose distinct phrase/modulation/disclosure populations")
        #expect(populationSignatures.count == 2)
        for candidate in candidates {
            let phraseKind = try #require(AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ))
            let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: phraseKind,
                chapterChanged: candidate.symbolic.chapterChanged
            ).first)
            let observation = try ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: checkpoint
            )
            let bars = candidate.phraseComposition
            let active = bars.filter {
                $0.padRhythmicModulationRelation ==
                    PadRhythmicModulationRelation.threeStepPulse.rawValue
            }
            let revealed = bars.filter {
                $0.padActive && $0.padHarmonicDisclosureStage ==
                    PadHarmonicDisclosureStage.revealed.rawValue
            }
            #expect(observation[.padRhythmicModulationActiveBarRatio] ==
                    Double(active.count) / Double(max(1, bars.count)))
            #expect(observation[.padHarmonicDisclosureRevealedBarRatio] ==
                    Double(revealed.count) / Double(max(1, bars.count)))
            func decibels(_ numerator: Double, _ denominator: Double) -> Double {
                guard numerator > 0, denominator > 0 else { return -120 }
                return min(120, max(-120,
                    20 * (log10(numerator) - log10(denominator))
                ))
            }
            let spatialMean = active.isEmpty ? 0 :
                active.map {
                    decibels($0.padSpatialSendDifferenceRMS,
                             $0.padSpatialSendRMS)
                }.reduce(0, +) / Double(active.count)
            #expect(observation[.padRhythmicSpatialDifferenceToSendDBMean] == spatialMean)
            let relationIsActive = !active.isEmpty
            for metric in [
                ProfessionalQualityMetric.padRhythmicFilterDifferenceToPadDBMean,
                .padRhythmicAmplitudeGateDifferenceToPadDBMean,
                .padRhythmicSpatialDifferenceToSendDBMean,
            ] {
                #expect(observation.measurementIsApplicable(metric) ==
                        relationIsActive)
            }
        }
    }

    @Test("Active harmonic tail projects rendered energy evidence")
    func activeHarmonicTailProjectionMatchesEvidence() throws {
        let candidate = try candidateWithActiveHarmonicTail()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        let tails = candidate.instruments.flatMap(\.architectures)
            .compactMap(\.spectralTextureHarmonicTail)
        #expect(!tails.isEmpty)
        #expect(observation[.spectralHarmonicTailUpperBandEnergyRatioMean] ==
                tails.map(\.upperBandEnergyRatio).reduce(0, +) /
                    Double(tails.count))
    }

    @Test("Candidate projection matches modal evidence")
    func modalProjectionMatchesEvidence() throws {
        let candidate = try candidateWithModalEvents()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        func expected(_ metric: ProfessionalQualityMetric) throws -> Double {
            try #require(observation[metric])
        }
        func mean(_ values: [Double]) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
        func ratioDB(_ numerator: Double, _ denominator: Double) -> Double {
            guard numerator > 0, denominator > 0 else { return -120 }
            return min(120, max(-120,
                20 * (log10(numerator) - log10(denominator))
            ))
        }

        let modalBars = candidate.modalPercussion
        let activeModalBars = modalBars.filter {
            !$0.events.isEmpty || $0.activeIncomingVoiceCount > 0
        }
        let modalEvents = modalBars.flatMap(\.events)
        #expect(!modalEvents.isEmpty)
        #expect(Set(modalEvents.map(\.step)).count > 1,
                "Candidate fixture exercises event-relative RMS windows at distinct score steps")
        #expect(try expected(.modalPercussionActiveBarRatio) ==
                Double(activeModalBars.count) / Double(max(1, modalBars.count)))
        #expect(try expected(.modalPercussionEventCountMean) ==
                mean(modalBars.map { Double($0.events.count) }))
        let expectedPitchError = modalEvents.map {
            abs(1_200 * log2($0.appliedFundamentalHz / $0.requestedFundamentalHz))
        }.max() ?? 0
        #expect(expectedPitchError == 0,
                "Complete modal evidence enforces requested/applied pitch identity")
        #expect(try expected(.modalPercussionPitchErrorCentsMaximum) ==
                expectedPitchError)
        #expect(try expected(.modalPercussionAttackToBodyDBMean) == mean(
            modalEvents.map { ratioDB(max($0.attackRMS, 1e-12), max($0.bodyRMS, 1e-12)) }
        ))
        #expect(try expected(.modalPercussionTailToBodyDBMean) == mean(
            modalEvents.map { ratioDB(max($0.tailRMS, 1e-12), max($0.bodyRMS, 1e-12)) }
        ))
        #expect(try expected(.modalPercussionSpectralCentroidMeanHz) ==
                mean(modalEvents.map(\.spectralCentroidHz)))
        let activeModalBarSet = Set(activeModalBars.map(\.bar))
        let applicableMasking = candidate.masking
            .filter { activeModalBarSet.contains($0.bar) }
            .flatMap(\.observations)
            .filter {
                $0.firstRole == MaskingRole.foundation.rawValue &&
                    ($0.secondRole == MaskingRole.percussion.rawValue ||
                     $0.secondRole == MaskingRole.upper.rawValue)
            }
        #expect(try expected(.modalPercussionMaskingMaximumOverlap) ==
                (applicableMasking.map(\.maximumOverlap).max() ?? 0))
        #expect(try expected(.modalPercussionMaximumPoleRadius) ==
                (modalEvents.map(\.maximumPoleRadius).max() ?? 0))
    }

    @Test("Modal event population projections vary across complete candidates")
    func modalEventPopulationProjectionAcrossCandidates() throws {
        var candidates: [AutonomousCandidateEvaluationVector] = []
        var populationSignatures = Set<String>()

        search: for seed in [UInt64(1), 42, 48_291, 91_773] {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<24 {
                let plan = director.plan(from: state)
                guard plan.resolvedBars.contains(where: {
                    !$0.modalPercussionArticulations.isEmpty
                }) else {
                    state.advancePlanning(using: plan)
                    continue
                }
                var renderState = RenderState()
                renderState.barIndex = plan.startBar
                guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                    plan: plan,
                    sessionSeed: state.rootSeed,
                    memory: state.memory,
                    sampleRate: 8_000,
                    incomingRenderState: renderState,
                    incomingGraphState: GeneratedDSPContinuationState(),
                    previousGraph: nil,
                    incomingQualityState: state.quality,
                    evaluator: AcceptingPrimaryTestEvaluator(),
                    cancellationRequested: { false }
                ), prepared.selectedCandidateEvidence.isComplete,
                    prepared.selectedCandidateEvidence.modalPercussion.contains(where: {
                        !$0.events.isEmpty
                    }) else {
                    Issue.record("Modal candidate preparation failed for seed \(seed)")
                    break search
                }
                let candidate = prepared.selectedCandidateEvidence
                let modalBars = candidate.modalPercussion
                let eventCount = modalBars.reduce(0) { $0 + $1.events.count }
                let activeBarCount = modalBars.filter {
                    !$0.events.isEmpty || $0.activeIncomingVoiceCount > 0
                }.count
                let signature = "\(modalBars.count):\(activeBarCount):\(eventCount)"
                if populationSignatures.insert(signature).inserted {
                    candidates.append(candidate)
                }
                if candidates.count == 2 { break search }
                state.advancePlanning(using: plan)
            }
        }

        #expect(candidates.count == 2,
                "The fixture must produce distinct complete modal populations")
        let signatures = candidates.map { candidate in
            let bars = candidate.modalPercussion
            let eventCount = bars.reduce(0) { $0 + $1.events.count }
            let activeBarCount = bars.filter {
                !$0.events.isEmpty || $0.activeIncomingVoiceCount > 0
            }.count
            return "\(bars.count):\(activeBarCount):\(eventCount)"
        }
        #expect(Set(signatures).count == candidates.count)

        for candidate in candidates {
            let phraseKind = try #require(AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ))
            let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: phraseKind,
                chapterChanged: candidate.symbolic.chapterChanged
            ).first)
            let observation = try ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: checkpoint
            )
            let bars = candidate.modalPercussion
            let activeBars = bars.filter {
                !$0.events.isEmpty || $0.activeIncomingVoiceCount > 0
            }
            let meanEventCount = bars.isEmpty ? 0 :
                Double(bars.reduce(0) { $0 + $1.events.count }) /
                    Double(bars.count)
            let eventTailToBody = bars.flatMap(\.events).map { event in
                min(120, max(-120,
                    20 * (log10(max(event.tailRMS, 1e-12)) -
                          log10(max(event.bodyRMS, 1e-12)))
                ))
            }
            let meanTailToBody = eventTailToBody.isEmpty ? 0 :
                eventTailToBody.reduce(0, +) / Double(eventTailToBody.count)
            let events = bars.flatMap(\.events)
            let eventAttackToBody = events.map { event in
                min(120, max(-120,
                    20 * (log10(max(event.attackRMS, 1e-12)) -
                          log10(max(event.bodyRMS, 1e-12)))
                ))
            }
            let meanAttackToBody = eventAttackToBody.isEmpty ? 0 :
                eventAttackToBody.reduce(0, +) / Double(eventAttackToBody.count)
            let meanConfigurationCentroid = events.isEmpty ? 0 :
                events.map(\.spectralCentroidHz).reduce(0, +) /
                    Double(events.count)
            let maximumPoleRadius = events.map(\.maximumPoleRadius).max() ?? 0
            #expect(Set(events.map(\.step)).count > 1,
                    "Modal attack/body windows must cover distinct score-step events")
            #expect(observation[.modalPercussionActiveBarRatio] ==
                    Double(activeBars.count) / Double(max(1, bars.count)))
            #expect(observation[.modalPercussionEventCountMean] == meanEventCount)
            #expect(observation[.modalPercussionTailToBodyDBMean] == meanTailToBody,
                    "Tail/body mean uses rendered events, not modal bars, as its population")
            #expect(observation[.modalPercussionAttackToBodyDBMean] == meanAttackToBody,
                    "Attack/body mean uses clamped per-event RMS windows")
            #expect(observation[.modalPercussionSpectralCentroidMeanHz] ==
                    meanConfigurationCentroid,
                    "The configuration-derived centroid averages rendered event configurations")
            #expect(observation[.modalPercussionMaximumPoleRadius] ==
                    maximumPoleRadius,
                    "The stability statistic is the maximum over rendered events")
        }
    }

    @Test("Musical consequence metrics are versioned and non-compensable")
    func modalMetricContract() {
        #expect(ProfessionalQualityMetric.allCases.count == 68)
        #expect(ProfessionalQualityObservation.schemaVersion == 21)
        #expect(ProfessionalQualityObservation.observationVersion ==
                "autotechno-professional-quality-observation.v21")
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 29)
        #expect(ProfessionalEvidenceReportBank.evidenceVersion ==
                "autotechno-professional-evidence.v29")
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v30")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v30")
        #expect(ProfessionalQualityPrimaryEvaluator.requiredProfileVersion ==
                "autotechno-professional-quality-profile.v30")
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 21)
        #expect(ProfessionalQualityCalibrationProfile.profileVersion ==
                "autotechno-professional-quality-profile.v30")
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 22)
        #expect(ProfessionalQualityAdversarialSuiteReport.suiteVersion ==
                "autotechno-professional-quality-adversarial.v23")
        #expect(ProfessionalQualityHoldoutQualification.schemaVersion == 20)
        #expect(ProfessionalQualityHoldoutQualification.qualificationVersion ==
                "autotechno-professional-quality-holdout.v20")

        for metric in [
            ProfessionalQualityMetric.modalPercussionPitchErrorCentsMaximum,
            .modalPercussionMaskingMaximumOverlap,
            .modalPercussionMaximumPoleRadius,
        ] {
            #expect(metric.conditionalNeutralSentinel == 0)
        }
        #expect(ProfessionalQualityMetric
            .modalPercussionAttackToBodyDBMean
            .conditionalNeutralCalibrationEnvelope == -1...1)
        #expect(ProfessionalQualityMetric
            .modalPercussionTailToBodyDBMean
            .conditionalNeutralCalibrationEnvelope == -1...1)
        #expect(ProfessionalQualityMetric
            .modalPercussionSpectralCentroidMeanHz
            .conditionalNeutralCalibrationEnvelope == 0...60)
        #expect(ProfessionalQualityMetric
            .kickOverFoundationActiveDBMean
            .conditionalNeutralSentinel == 0)
        #expect(ProfessionalQualityMetric
            .kickOverFoundationActiveDBMean
            .conditionalNeutralCalibrationEnvelope == -0.75...0.75)
        #expect(ProfessionalQualityMetric
            .upperSpectralRevealActiveEventRatio
            .conditionalNeutralSentinel == 1)
        #expect(ProfessionalQualityMetric
            .upperSpectralRevealActiveEventRatio
            .isConditionalNeutral(1))
        for metric in [
            ProfessionalQualityMetric.modalPercussionPitchErrorCentsMaximum,
            .modalPercussionMaskingMaximumOverlap,
            .modalPercussionMaximumPoleRadius,
        ] {
            #expect(metric.acceptsSaferValuesBelowCalibration)
            #expect(metric.semanticMinimum == 0)
        }
        for metric in [
            ProfessionalQualityMetric.kickSourceOutputCrestFactorDBMean,
            .kickSourceAttackToBodyDBMean,
            .kickSourceUpperMidEnergyRatioMean,
            .kickSourceCrestReductionDBMean,
        ] {
            #expect(metric.participatesInQualification)
            #expect(!metric.acceptsSaferValuesBelowCalibration)
        }
        #expect(ProfessionalQualityMetric.modalPercussionActiveBarRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric.modalPercussionEventCountMean
            .participatesInQualification)
        #expect(ProfessionalQualityMetric.upperPercussionTailClearanceEventRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric.upperSpectralRevealActiveEventRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .upperSpectralRevealAppliedCutoffRatioMean
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .percussionAnticipationSwellActiveBarRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .percussionAnticipationSwellLateToEarlyDBMean
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .padRhythmicModulationActiveBarRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .padRhythmicFilterDifferenceToPadDBMean
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .padRhythmicSpatialDifferenceToSendDBMean
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .padHarmonicDisclosureRevealedBarRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .padHarmonicDisclosureDistinctFunctionCount
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .foundationDottedRhythmActiveBarRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .foundationDottedRhythmCrestFactorDBMean
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .foundationPreKickPocketSilenceRMSMaximum
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .foundationPreKickPocketSilenceRMSMaximum
            .acceptsSaferValuesBelowCalibration)
        #expect(ProfessionalQualityMetric.climaxHangSilenceRMSMaximum
            .participatesInQualification)
        #expect(ProfessionalQualityMetric.climaxHangSilenceRMSMaximum
            .acceptsSaferValuesBelowCalibration)
        #expect(ProfessionalQualityMetric.climaxHangSilenceRMSMaximum
            .semanticMinimum == 0)
        #expect(ProfessionalQualityMetric
            .padRhythmicFilterDifferenceToPadDBMean.semanticMinimum == -120)
        #expect(ProfessionalQualityMetric
            .padRhythmicSpatialDifferenceToSendDBMean.semanticMinimum == -120)
        #expect(ProfessionalQualityMetric.upperPercussionTailClearanceEventRatio
            .semanticMinimum == 0)
        #expect(ProfessionalQualityMetric
            .upperPercussionTailRenderedTailToAttackDBMean
            .participatesInQualification)
        #expect(ProfessionalQualityMetric
            .upperPercussionTailRenderedTailToAttackDBMean
            .semanticMinimum == -120)
        #expect(ProfessionalQualityMetric
            .percussionAnticipationSwellLateToEarlyDBMean
            .semanticMinimum == -120)
        #expect(ProfessionalQualityMetric.rmsTrajectoryDeltaPeakDB
            .participatesInQualification)
        #expect(!ProfessionalQualityMetric.rmsTrajectoryDeltaPeakDB
            .participatesInRateConsistency)
        #expect(ProfessionalQualityMetric.rmsTrajectoryDeltaMeanDB
            .participatesInRateConsistency)
    }

    @Test("Descriptive local kick-foundation spread exposes a hidden bar defect")
    func kickFoundationLocalSpreadPreservesBarEvidence() throws {
        func report(_ ratios: [Double]) throws ->
            ProfessionalQualityKickFoundationLocalEvidence {
            let bars = ratios.enumerated().map { index, ratio in
                ProfessionalQualityKickFoundationLocalEvidence.SourceBar(
                    bar: 8 + index,
                    kickActiveRMS: ratio,
                    foundationActiveRMS: 1
                )
            }
            return try ProfessionalQualityKickFoundationLocalEvidence(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: "descriptive-local-feature-test.v1",
                sourceReportFingerprint: "paired-bar-source",
                planFingerprint: "paired-bar-plan",
                checkpoint: .establishment,
                sampleRate: 44_100,
                sourceBarCount: bars.count,
                sourceBars: bars
            )
        }

        let uniform = try report([1, 1, 1, 1])
        let localized = try report([0.1, 1, 1, 10])
        #expect(ProfessionalQualityKickFoundationLocalEvidence
            .evidenceCategory == .descriptive)
        #expect(uniform.availability == .available)
        #expect(uniform.meanDB == 0)
        #expect(uniform.spreadDB == 0)
        #expect(localized.meanDB == 0)
        #expect(localized.minimumDB == -20)
        #expect(localized.maximumDB == 20)
        #expect(localized.spreadDB == 40)
        #expect(localized.barMeasurements.map(\.bar) == [8, 9, 10, 11])
        #expect(localized.barMeasurements.map(\.kickOverFoundationDB) ==
                [-20, 0, 0, 20])
        #expect(localized.sourceReportFingerprint == "paired-bar-source")
        #expect(localized.sampleRate == 44_100)

        let inactive = try ProfessionalQualityKickFoundationLocalEvidence(
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: "descriptive-local-feature-test.v1",
            sourceReportFingerprint: "inactive-pair-source",
            planFingerprint: "inactive-pair-plan",
            checkpoint: .establishment,
            sampleRate: 48_000,
            sourceBarCount: 2,
            sourceBars: [
                .init(bar: 0, kickActiveRMS: 0, foundationActiveRMS: 0),
                .init(bar: 1, kickActiveRMS: 1, foundationActiveRMS: 0),
            ]
        )
        #expect(inactive.availability == .noActivePairedBars)
        #expect(inactive.pairedBarCount == 0)
        #expect(inactive.meanDB == nil)
        #expect(inactive.spreadDB == nil)

        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityKickFoundationLocalEvidence(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: "descriptive-local-feature-test.v1",
                sourceReportFingerprint: "duplicate-bars",
                planFingerprint: "duplicate-bars-plan",
                checkpoint: .establishment,
                sampleRate: 44_100,
                sourceBarCount: 2,
                sourceBars: [
                    .init(bar: 3, kickActiveRMS: 1, foundationActiveRMS: 1),
                    .init(bar: 3, kickActiveRMS: 1, foundationActiveRMS: 1),
                ]
            )
        }
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityKickFoundationLocalEvidence(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: "descriptive-local-feature-test.v1",
                sourceReportFingerprint: "missing-bar",
                planFingerprint: "missing-bar-plan",
                checkpoint: .establishment,
                sampleRate: 44_100,
                sourceBarCount: 2,
                sourceBars: [
                    .init(bar: 2, kickActiveRMS: 1, foundationActiveRMS: 1),
                    .init(bar: 4, kickActiveRMS: 1, foundationActiveRMS: 1),
                ]
            )
        }
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityKickFoundationLocalEvidence(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: "descriptive-local-feature-test.v1",
                sourceReportFingerprint: "nonfinite-source",
                planFingerprint: "nonfinite-source-plan",
                checkpoint: .establishment,
                sampleRate: 44_100,
                sourceBarCount: 1,
                sourceBars: [
                    .init(bar: 0, kickActiveRMS: .infinity,
                          foundationActiveRMS: 1),
                ]
            )
        }
    }

    @Test("Descriptive masking evidence localizes equal candidate-wide summaries")
    func maskingLocalEvidencePreservesBarRoleAndBand() throws {
        func report(activeBar: Int, activeBand: String) throws ->
            ProfessionalQualityMaskingLocalEvidence {
            let bars = [50, 51].map { bar in
                let observations = SpectrumMaskingAnalyzer.rolePairs.flatMap {
                    pair in
                    let firstRole = pair.0
                    let secondRole = pair.1
                    return SpectrumMaskingAnalyzer.bands.map { band in
                        let active = bar == activeBar &&
                            band.name == activeBand &&
                            firstRole == .foundation &&
                            secondRole == .percussion
                        return AutonomousMaskingObservationEvidence(
                            bandName: band.name,
                            lowerHz: band.lowerHz,
                            upperHz: band.upperHz,
                            firstRole: firstRole.rawValue,
                            secondRole: secondRole.rawValue,
                            analyzedWindowCount: SpectrumMaskingAnalyzer
                                .analyzedWindowCount,
                            activePairWindowCount: active ? 2 : 0,
                            overlapWindowCount: active ? 1 : 0,
                            longestOverlapRun: active ? 1 : 0,
                            maximumOverlap: active ? 0.8 : 0
                        )
                    }
                }
                return AutonomousMaskingBarEvidence(
                    bar: bar,
                    sourceObservationCount: observations.count,
                    observations: observations
                )
            }
            return try ProfessionalQualityMaskingLocalEvidence(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: "masking-local-test.v1",
                sourceReportFingerprint: "same-candidate-source",
                planFingerprint: "same-plan",
                checkpoint: .establishment,
                sampleRate: 44_100,
                sourceBars: bars
            )
        }

        let subBar50 = try report(activeBar: 50, activeBand: "sub")
        let highBar51 = try report(activeBar: 51, activeBand: "high")
        let neutral = try report(activeBar: -1, activeBand: "none")
        #expect(ProfessionalQualityMaskingLocalEvidence.evidenceCategory ==
                .descriptive)
        #expect(subBar50.sourceBarCount == 2)
        #expect(subBar50.observationCount == 24)
        #expect(subBar50.observations.count == 24)
        #expect(subBar50.observations.first(where: {
            $0.maximumOverlap == 0.8
        })?.bar == 50)
        #expect(subBar50.observations.first(where: {
            $0.maximumOverlap == 0.8
        })?.bandName == "sub")
        #expect(highBar51.observations.first(where: {
            $0.maximumOverlap == 0.8
        })?.bar == 51)
        #expect(highBar51.observations.first(where: {
            $0.maximumOverlap == 0.8
        })?.bandName == "high")
        #expect(neutral.observationCount == 24)
        #expect(neutral.observations.allSatisfy {
            $0.activePairWindowCount == 0 &&
                $0.overlapWindowCount == 0 && $0.maximumOverlap == 0
        })

        func existingSummary(_ value: ProfessionalQualityMaskingLocalEvidence)
            -> (maximum: Double, overlapRatio: Double, longestRun: Int) {
            let observations = value.observations
            let analyzed = observations.reduce(0) {
                $0 + $1.analyzedWindowCount
            }
            return (
                observations.map(\.maximumOverlap).max() ?? 0,
                analyzed == 0 ? 0 : Double(observations.reduce(0) {
                    $0 + $1.overlapWindowCount
                }) / Double(analyzed),
                observations.map(\.longestOverlapRun).max() ?? 0
            )
        }
        #expect(existingSummary(subBar50).maximum ==
                existingSummary(highBar51).maximum)
        #expect(existingSummary(subBar50).overlapRatio ==
                existingSummary(highBar51).overlapRatio)
        #expect(existingSummary(subBar50).longestRun ==
                existingSummary(highBar51).longestRun)
    }

    @Test("Local masking report projects exact candidate observations")
    func maskingLocalEvidenceProjectsCandidate() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let report = try ProfessionalQualityMaskingLocalEvidence(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: "masking-local-candidate-test.v1",
            sourceReportFingerprint: "masking-candidate-report",
            checkpoint: checkpoint
        )
        let repeatedReport = try ProfessionalQualityMaskingLocalEvidence(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: "masking-local-candidate-test.v1",
            sourceReportFingerprint: "masking-candidate-report",
            checkpoint: checkpoint
        )
        #expect(report == repeatedReport)
        #expect(report.sourceBarCount == candidate.sourceMaskingBarCount)
        #expect(report.observationCount == candidate.masking.reduce(0) {
            $0 + $1.observations.count
        })
        let expected = candidate.masking.flatMap { bar in
            bar.observations.map { (bar.bar, $0) }
        }
        for ((bar, source), projected) in zip(expected, report.observations) {
            #expect(projected.bar == bar)
            #expect(projected.bandName == source.bandName)
            #expect(projected.firstRole == source.firstRole)
            #expect(projected.secondRole == source.secondRole)
            #expect(projected.lowerHz == source.lowerHz)
            #expect(projected.upperHz == source.upperHz)
            #expect(projected.analyzedWindowCount == source.analyzedWindowCount)
            #expect(projected.activePairWindowCount ==
                    source.activePairWindowCount)
            #expect(projected.overlapWindowCount == source.overlapWindowCount)
            #expect(projected.longestOverlapRun == source.longestOverlapRun)
            #expect(projected.maximumOverlap == source.maximumOverlap)
        }
    }

    @Test("Local masking evidence rejects incomplete source observations")
    func maskingLocalEvidenceRejectsIncompleteSource() throws {
        let bar = AutonomousMaskingBarEvidence(
            bar: 0,
            sourceObservationCount: 1,
            observations: []
        )
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityMaskingLocalEvidence(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: "masking-local-invalid-test.v1",
                sourceReportFingerprint: "invalid-mask-source",
                planFingerprint: "invalid-mask-plan",
                checkpoint: .establishment,
                sampleRate: 44_100,
                sourceBars: [bar]
            )
        }

        func completeBar(_ index: Int) -> AutonomousMaskingBarEvidence {
            let observations = SpectrumMaskingAnalyzer.rolePairs.flatMap {
                pair in
                SpectrumMaskingAnalyzer.bands.map { band in
                    AutonomousMaskingObservationEvidence(
                        bandName: band.name,
                        lowerHz: band.lowerHz,
                        upperHz: band.upperHz,
                        firstRole: pair.0.rawValue,
                        secondRole: pair.1.rawValue,
                        analyzedWindowCount: SpectrumMaskingAnalyzer
                            .analyzedWindowCount,
                        activePairWindowCount: 0,
                        overlapWindowCount: 0,
                        longestOverlapRun: 0,
                        maximumOverlap: 0
                    )
                }
            }
            return AutonomousMaskingBarEvidence(
                bar: index,
                sourceObservationCount: observations.count,
                observations: observations
            )
        }
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try ProfessionalQualityMaskingLocalEvidence(
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: "masking-local-gapped-test.v1",
                sourceReportFingerprint: "gapped-mask-source",
                planFingerprint: "gapped-mask-plan",
                checkpoint: .establishment,
                sampleRate: 44_100,
                sourceBars: [completeBar(4), completeBar(6)]
            )
        }
    }

    @Test("Local kick-foundation evidence projects exact candidate stem bars")
    func kickFoundationLocalEvidenceProjectsCandidate() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).first)
        let report = try ProfessionalQualityKickFoundationLocalEvidence(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: "candidate-local-feature-test.v1",
            sourceReportFingerprint: "candidate-report-fingerprint",
            checkpoint: checkpoint
        )
        let observation = try ProfessionalQualityObservation(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: checkpoint
        )
        let repeatedReport = try ProfessionalQualityKickFoundationLocalEvidence(
            candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: "candidate-local-feature-test.v1",
            sourceReportFingerprint: "candidate-report-fingerprint",
            checkpoint: checkpoint
        )
        let independentPairs = candidate.stems.compactMap { stem ->
            (bar: Int, value: Double)? in
            guard let kick = stem.roles.first(where: {
                $0.role == MixRole.kick.rawValue
            }), let foundation = stem.roles.first(where: {
                $0.role == MixRole.foundation.rawValue
            }), kick.activeRMS > 0, foundation.activeRMS > 0 else {
                return nil
            }
            return (
                stem.bar,
                min(120, max(-120,
                    20 * (log10(kick.activeRMS) - log10(foundation.activeRMS))
                ))
            )
        }
        #expect(report.sourceBarCount == candidate.sourceStemBarCount)
        #expect(report.pairedBarCount == independentPairs.count)
        #expect(report.barMeasurements.map(\.bar) ==
                independentPairs.map(\.bar))
        #expect(report.barMeasurements.map(\.kickOverFoundationDB) ==
                independentPairs.map(\.value))
        #expect(report.meanDB == (independentPairs.isEmpty ? nil :
            independentPairs.map(\.value).reduce(0, +) /
                Double(independentPairs.count)))
        #expect(report.spreadDB == (independentPairs.isEmpty ? nil :
            (independentPairs.map(\.value).max()! -
                independentPairs.map(\.value).min()!)))
        #expect(report.meanDB == observation[.kickOverFoundationActiveDBMean])
        #expect(report.planFingerprint == candidate.planFingerprint)
        #expect(report.sampleRate == candidate.routeContinuation.sampleRate)
        #expect(report == repeatedReport)
    }

    @Test("Spectral reveal absence is neutral but eligible inactivity fails")
    func conditionalSpectralRevealRatio() throws {
        #expect(ProfessionalQualityObservation
            .upperSpectralRevealActiveEventRatio(
                eligibleEventCount: 0,
                activeEventCount: 0
            ) == 1)
        #expect(ProfessionalQualityObservation
            .upperSpectralRevealActiveEventRatio(
                eligibleEventCount: 4,
                activeEventCount: 0
            ) == 0)
        #expect(ProfessionalQualityObservation
            .upperSpectralRevealActiveEventRatio(
                eligibleEventCount: 4,
                activeEventCount: 3
            ) == 0.75)
        #expect(ProfessionalQualityObservation
            .upperSpectralRevealActiveEventRatio(
                eligibleEventCount: 0,
                activeEventCount: 1
            ) == 0)
        let legacyInactiveBounds = try ProfessionalQualityMetricBounds(
            metric: .upperSpectralRevealActiveEventRatio,
            lower: 0,
            upper: 0.04
        )
        #expect(legacyInactiveBounds.contains(1))
        let activeBounds = try ProfessionalQualityMetricBounds(
            metric: .upperSpectralRevealActiveEventRatio,
            lower: 0.92,
            upper: 1
        )
        #expect(activeBounds.contains(1))
        #expect(!activeBounds.contains(0))
    }

    @Test("Kick-foundation balance requires an active comparison")
    func conditionalKickFoundationBalance() throws {
        let observations = try representativeObservations()
        let active = try #require(observations.first)
        let noActiveBars = try active.replacing(
            .activeKickFoundationBarRatio,
            with: 0
        )
        let inactive = try noActiveBars.replacing(
            .kickOverFoundationActiveDBMean,
            with: 0
        )

        #expect(active.measurementIsApplicable(
            .kickOverFoundationActiveDBMean
        ))
        #expect(!inactive.measurementIsApplicable(
            .kickOverFoundationActiveDBMean
        ))
        #expect(inactive[.kickOverFoundationActiveDBMean] == 0)
        let activeOnlyBounds = try ProfessionalQualityMetricBounds(
            metric: .kickOverFoundationActiveDBMean,
            lower: 10,
            upper: 33
        )
        #expect(!activeOnlyBounds.contains(0))
    }

    @Test("Neutral-only modal checkpoints reuse qualified active bounds")
    func conditionalModalBoundsFromCurrentProfile() throws {
        let observations = try representativeObservations().map { observation in
            guard observation.checkpoint == .chapterChange else {
                return observation
            }
            return try observation
                .replacing(.modalPercussionAttackToBodyDBMean, with: 0)
                .replacing(.modalPercussionTailToBodyDBMean, with: 0)
                .replacing(.modalPercussionSpectralCentroidMeanHz, with: 0)
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "conditional-modal-bounds-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let examples: [(ProfessionalQualityMetric, Double)] = [
            (.modalPercussionAttackToBodyDBMean, 6),
            (.modalPercussionTailToBodyDBMean, -8),
            (.modalPercussionSpectralCentroidMeanHz, 620),
        ]
        for (metric, value) in examples {
            let local = try #require(profile[.chapterChange]?[metric])
            #expect(!local.contains(value))
            let effective = try #require(profile.effectiveBounds(
                for: metric,
                at: .chapterChange,
                observedValue: value
            ))
            #expect(effective.contains(value))

            let neutral = try #require(profile.effectiveBounds(
                for: metric,
                at: .chapterChange,
                observedValue: 0
            ))
            #expect(neutral == local)
        }
        let extreme = try #require(profile.effectiveBounds(
            for: .modalPercussionAttackToBodyDBMean,
            at: .chapterChange,
            observedValue: 100
        ))
        #expect(!extreme.contains(100))
    }

    @Test("One failed dimension cannot be compensated by centered peers")
    func noAggregateCompensation() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "no-compensation-bank-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let baseline = try #require(observations.first {
            $0.checkpoint == .establishment && $0.sampleRate == 48_000
        })
        let checkpoint = try #require(profile[.establishment])
        _ = try #require(checkpoint[.truePeakDBTP])
        let centered = try ProfessionalQualityObservation(
            engineVersion: baseline.engineVersion,
            checkpoint: baseline.checkpoint,
            sampleRate: baseline.sampleRate,
            hardGatesPassed: true,
            liveMaster: baseline.liveMaster,
            metrics: checkpoint.bounds.map { bounds in
                ProfessionalQualityMetricValue(
                    metric: bounds.metric,
                    value: bounds.metric == .truePeakDBTP
                        ? bounds.upper + 0.1
                        : (bounds.lower + bounds.upper) * 0.5
                )
            }
        )
        let verdict = ProfessionalQualityProfileEvaluator.evaluate(
            centered, against: profile
        )
        #expect(!verdict.accepted)
        #expect(verdict.reasons == [.metricOutOfRange])
        #expect(verdict.failedMetrics == [.truePeakDBTP])
    }

    @Test("Safer one-sided metrics accept improvement but reject regression")
    func directionalSafetyBounds() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "directional-safety-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let baseline = try #require(observations.first {
            $0.checkpoint == .establishment && $0.sampleRate == 48_000
        })
        let checkpoint = try #require(profile[.establishment])
        for metric in [
            ProfessionalQualityMetric.truePeakDBTP,
            .absoluteDCOffset,
            .maximumBoundaryDelta,
            .maskingMaximumOverlap,
            .maskingOverlapWindowRatio,
            .maskingLongestRunRatio,
            .modalPercussionPitchErrorCentsMaximum,
            .modalPercussionMaskingMaximumOverlap,
            .modalPercussionMaximumPoleRadius,
        ] {
            let bounds = try #require(checkpoint[metric])
            let improved = try baseline.replacing(
                metric,
                with: metric.semanticMinimum
            )
            let regressed = try baseline.replacing(
                metric,
                with: bounds.upper + max(0.001, abs(bounds.upper) * 0.01)
            )
            #expect(ProfessionalQualityProfileEvaluator.evaluate(
                improved, against: profile
            ).accepted)
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                regressed, against: profile
            )
            #expect(!verdict.accepted)
            #expect(verdict.failedMetrics == [metric])
        }
    }

    @Test("Conditional metrics pool active evidence and ignore activation edges")
    func conditionalMetricCalibration() throws {
        let trajectories = try (0..<24).map { index in
            let observations = try representativeObservations().map {
                observation in
                let modalMasking = observation.checkpoint == .chapterChange
                    ? (observation.sampleRate == 48_000 ? 0.72 : 0.70)
                    : 0
                let harmonicTail = observation.checkpoint == .contrast
                    ? (observation.sampleRate == 48_000 ? 0.62 : 0.60)
                    : 1
                // v30 pad means require score-owned active-bar evidence;
                // keep this synthetic corpus representative for every metric.
                let padSupported = try observation
                    .replacing(
                        .padRhythmicModulationActiveBarRatio,
                        with: 0.5
                    )
                    .replacing(
                        .padRhythmicFilterDifferenceToPadDBMean,
                        with: -24 + Double(index) * 0.01
                    )
                    .replacing(
                        .padRhythmicAmplitudeGateDifferenceToPadDBMean,
                        with: -18 + Double(index) * 0.01
                    )
                    .replacing(
                        .padRhythmicSpatialDifferenceToSendDBMean,
                        with: -12 + Double(index) * 0.01
                    )
                return try padSupported
                    .replacing(
                        .modalPercussionMaskingMaximumOverlap,
                        with: modalMasking
                    )
                    .replacing(
                        .spectralHarmonicTailUpperBandEnergyRatioMean,
                        with: harmonicTail
                    )
            }
            return try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "conditional-calibration-\(index)",
                observations: observations
            )
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: ProfessionalQualityCalibrationCorpus(
                trajectories: trajectories
            )
        )
        let release = try #require(profile[.release])
        #expect(try #require(release[
            .modalPercussionMaskingMaximumOverlap
        ]).contains(0.72))
        let longContinuation = try #require(profile[.longContinuation])
        #expect(try #require(longContinuation[
            .spectralHarmonicTailUpperBandEnergyRatioMean
        ]).contains(0.60))

        let holdout = try representativeObservations().map { observation in
            let modalMasking = observation.checkpoint == .release
                ? (observation.sampleRate == 48_000 ? 0.72 : 0.70)
                : 0
            let harmonicTail = observation.checkpoint == .longContinuation
                ? (observation.sampleRate == 48_000 ? 0.62 : 0.60)
                : 1
            let padSupported = try observation
                .replacing(
                    .padRhythmicModulationActiveBarRatio,
                    with: 0.5
                )
                .replacing(
                    .padRhythmicFilterDifferenceToPadDBMean,
                    with: -24
                )
                .replacing(
                    .padRhythmicAmplitudeGateDifferenceToPadDBMean,
                    with: -18
                )
                .replacing(
                    .padRhythmicSpatialDifferenceToSendDBMean,
                    with: -12
                )
            return try padSupported
                .replacing(
                    .modalPercussionMaskingMaximumOverlap,
                    with: modalMasking
                )
                .replacing(
                    .spectralHarmonicTailUpperBandEnergyRatioMean,
                    with: harmonicTail
                )
        }
        #expect(holdout.allSatisfy {
            ProfessionalQualityProfileEvaluator.evaluate(
                $0,
                against: profile
            ).accepted
        })
        let relationshipFailures =
            ProfessionalQualityRelationshipEvaluator.evaluate(
                observations: holdout,
                against: profile
            ).failures
        #expect(relationshipFailures.allSatisfy {
            $0.metric != .modalPercussionMaskingMaximumOverlap &&
                $0.metric !=
                .spectralHarmonicTailUpperBandEnergyRatioMean
        })
    }

    @Test("Relationship bounds preserve one-sided safer movement")
    func directionalRelationshipBounds() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "directional-relationship-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let improved = try observations.map { observation in
            observation.checkpoint == .longContinuation
                ? try observation.replacing(
                    .maskingMaximumOverlap,
                    with: ProfessionalQualityMetric.maskingMaximumOverlap
                        .semanticMinimum
                )
                : observation
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: improved,
            against: profile
        ).failures.allSatisfy { $0.metric != .maskingMaximumOverlap })

        let regressed = try observations.map { observation in
            observation.checkpoint == .longContinuation
                ? try observation.replacing(
                    .maskingMaximumOverlap,
                    with: 0.90
                )
                : observation
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: regressed,
            against: profile
        ).failures.contains {
            $0.kind == .trajectory &&
                $0.metric == .maskingMaximumOverlap
        })
    }

    @Test("Relationship assessment distinguishes support from statistical confidence")
    @MainActor
    func relationshipAssessmentSupportAndAvailability() throws {
        let artifacts = try diverseArtifacts()
        let observations = try #require(
            artifacts.calibration.trajectories.first?.observations
        )
        let qualified = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: observations,
            against: artifacts.profile
        )
        #expect(qualified.availability == .available)
        #expect(qualified.support == .sufficient)
        #expect(qualified.confidence == .notEstimated)
        #expect(qualified.accepted)
        #expect(qualified.observationCount == qualified.requiredObservationCount)
        let primaryEvaluator = try ProfessionalQualityPrimaryEvaluator(
            profile: artifacts.profile,
            adversarialSuite: artifacts.adversarial,
            holdoutQualification: artifacts.holdout
        )
        let candidateAssessment = primaryEvaluator.assessment(
            of: [observations[0]]
        )
        #expect(candidateAssessment.availability == .available)
        #expect(candidateAssessment.calibrationTrajectoryCount == 24)
        #expect(candidateAssessment.support == .sufficient)
        #expect(candidateAssessment.confidence == .notEstimated)
        #expect(candidateAssessment.accepted)

        let trajectoryOnly = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: observations.filter { $0.sampleRate == 48_000 },
            against: artifacts.profile
        )
        #expect(trajectoryOnly.availability == .available)
        #expect(trajectoryOnly.coverage == .trajectoryOnly)
        #expect(trajectoryOnly.confidence == .unavailable)
        #expect(!trajectoryOnly.accepted)

        let incomplete = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: Array(observations.dropLast()),
            against: artifacts.profile
        )
        #expect(incomplete.availability == .incompleteObservations)
        #expect(incomplete.confidence == .unavailable)
        #expect(!incomplete.accepted)
        #expect(incomplete.failures.isEmpty)

        let duplicate = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: Array(observations.dropLast()) + [observations[0]],
            against: artifacts.profile
        )
        #expect(duplicate.availability == .invalidObservations)
        #expect(duplicate.confidence == .unavailable)
        #expect(!duplicate.accepted)

        var mixedProvenance = observations
        let sourceObservation = observations[0]
        mixedProvenance[0] = try ProfessionalQualityObservation(
            engineVersion: "foreign-engine-version",
            evidenceVersion: sourceObservation.evidenceVersion,
            checkpoint: sourceObservation.checkpoint,
            sampleRate: sourceObservation.sampleRate,
            hardGatesPassed: sourceObservation.hardGatesPassed,
            liveMaster: sourceObservation.liveMaster,
            metrics: sourceObservation.metrics
        )
        let mixed = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: mixedProvenance,
            against: artifacts.profile
        )
        #expect(mixed.availability == .invalidObservations)
        #expect(mixed.confidence == .unavailable)
        #expect(!mixed.accepted)

        var unsupportedRate = observations
        unsupportedRate[0] = try ProfessionalQualityObservation(
            engineVersion: sourceObservation.engineVersion,
            evidenceVersion: sourceObservation.evidenceVersion,
            checkpoint: sourceObservation.checkpoint,
            sampleRate: 96_000,
            hardGatesPassed: sourceObservation.hardGatesPassed,
            liveMaster: sourceObservation.liveMaster,
            metrics: sourceObservation.metrics
        )
        let unsupported = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: unsupportedRate,
            against: artifacts.profile
        )
        #expect(unsupported.availability == .unsupportedSampleRate)
        #expect(unsupported.confidence == .unavailable)
        #expect(!unsupported.accepted)
        let unsupportedCandidate = primaryEvaluator.assessment(
            of: [unsupportedRate[0]]
        )
        #expect(unsupportedCandidate.availability == .unsupportedSampleRate)
        #expect(unsupportedCandidate.support == .sufficient)
        #expect(unsupportedCandidate.confidence == .unavailable)
        #expect(!unsupportedCandidate.accepted)

        let lowSupportProfile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "low-support-relationship-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: representativeObservations()
        )
        let lowSupport = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: observations,
            against: lowSupportProfile
        )
        #expect(lowSupport.availability == .available)
        #expect(lowSupport.support == .insufficient)
        #expect(lowSupport.confidence == .unavailable)
        #expect(!lowSupport.accepted)
    }

    @Test("Short-phrase loudness range remains descriptive")
    func descriptiveLoudnessRange() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "descriptive-lra-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let baseline = try #require(observations.first {
            $0.checkpoint == .release && $0.sampleRate == 48_000
        })
        let extreme = try baseline.replacing(.loudnessRangeLU, with: 120)
        #expect(ProfessionalQualityProfileEvaluator.evaluate(
            extreme, against: profile
        ).accepted)

        let changed = try observations.map { observation in
            observation.checkpoint == .release && observation.sampleRate == 44_100
                ? try observation.replacing(.loudnessRangeLU, with: 120)
                : observation
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: changed,
            against: profile
        ).failures.allSatisfy { $0.metric != .loudnessRangeLU })
    }

    @Test("RMS trajectory peak stays local while its mean gates route rates")
    func rmsTrajectoryRateConsistency() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "rms-trajectory-rate-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let peakChanged = try observations.map { observation in
            observation.sampleRate == 44_100
                ? try observation.replacing(.rmsTrajectoryDeltaPeakDB, with: 120)
                : observation
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: peakChanged,
            against: profile
        ).failures.allSatisfy { $0.metric != .rmsTrajectoryDeltaPeakDB })

        let meanChanged = try observations.map { observation in
            observation.sampleRate == 44_100
                ? try observation.replacing(.rmsTrajectoryDeltaMeanDB, with: 120)
                : observation
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: meanChanged,
            against: profile
        ).failures.contains {
            $0.kind == .rateConsistency &&
                $0.metric == .rmsTrajectoryDeltaMeanDB &&
                $0.checkpoint == .release
        })
    }

    @Test("Bar crest rate bounds include only a sub-audible quantization margin")
    func barCrestRateConsistencyQuantizationMargin() throws {
        let trajectories = try (0..<24).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "crest-rate-margin-\(index)",
                observations: representativeObservations()
            )
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: ProfessionalQualityCalibrationCorpus(
                trajectories: trajectories
            )
        )
        let mean = try #require(profile.rateConsistency.first {
            $0.checkpoint == .establishment &&
                $0.metric == .barCrestFactorMean
        })
        let span = try #require(profile.rateConsistency.first {
            $0.checkpoint == .establishment &&
                $0.metric == .barCrestFactorSpan
        })
        #expect(abs(mean.maximumAbsoluteDelta - 0.06) < 0.000_000_001)
        #expect(abs(span.maximumAbsoluteDelta - 0.06) < 0.000_000_001)
    }

    @Test("Kick event bounds include one authored pattern step")
    func kickEventPatternGuardBand() throws {
        let trajectories = try (0..<24).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "kick-pattern-margin-\(index)",
                observations: representativeObservations()
            )
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: ProfessionalQualityCalibrationCorpus(
                trajectories: trajectories
            )
        )
        let contrast = try #require(profile[.contrast]?[.kickEventCountMean])
        #expect(contrast.contains(3))
        #expect(contrast.contains(5))
        #expect(!contrast.contains(2.99))
        #expect(!contrast.contains(5.02))
    }

    @Test("Masking rate bounds include only normalized overlap quantization")
    func maskingRateConsistencyQuantizationMargin() throws {
        let trajectories = try (0..<24).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "masking-rate-margin-\(index)",
                observations: representativeObservations()
            )
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: ProfessionalQualityCalibrationCorpus(
                trajectories: trajectories
            )
        )
        let masking = try #require(profile.rateConsistency.first {
            $0.checkpoint == .release &&
                $0.metric == .maskingMaximumOverlap
        })
        #expect(abs(masking.maximumAbsoluteDelta - 0.06) < 0.000_000_001)
    }

    @Test("Transient-density bounds include only a floating-point margin")
    func transientDensityCheckpointQuantizationMargin() throws {
        let trajectories = try (0..<24).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "density-margin-\(index)",
                observations: representativeObservations()
            )
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: ProfessionalQualityCalibrationCorpus(
                trajectories: trajectories
            )
        )
        let density = try #require(profile[.establishment]?[.barTransientDensitySpan])
        let barSeconds = 4 * 60 / AutonomousSessionDirector.bpm
        let quantizationFloor = ProfessionalQualityCalibrationProfile
            .requiredSampleRates.map { sampleRate in
                let frameCount = max(
                    1,
                    Int((barSeconds * sampleRate).rounded())
                )
                return sampleRate / Double(frameCount)
            }.max() ?? 0
        #expect(abs(density.lower - (1 - quantizationFloor - 0.000_001)) <
                0.000_000_001)
        #expect(abs(density.upper - (1.01 + quantizationFloor + 0.000_001)) <
                0.000_000_001)
    }

    @Test("Constructed current artifacts activate only the single primary policy")
    @MainActor
    func primaryCandidatePolicy() throws {
        let artifacts = try diverseArtifacts()
        #expect(artifacts.profile.profileVersion ==
                ProfessionalQualityCalibrationProfile.profileVersion)
        #expect(artifacts.profile.profileVersion ==
                ProfessionalQualityPrimaryEvaluator.requiredProfileVersion)
        let evaluator = try ProfessionalQualityPrimaryEvaluator(
            profile: artifacts.profile,
            adversarialSuite: artifacts.adversarial,
            holdoutQualification: artifacts.holdout
        )
        #expect(evaluator.policyVersion.hasPrefix(
            ProfessionalQualityPrimaryEvaluator.policyFamilyVersion
        ))
    }

    @Test("Live master provenance is non-compensable and missing evidence is a hold")
    @MainActor
    func liveMasterProvenanceHardGates() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "live-policy-bank-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let baseline = try #require(observations.first {
            $0.checkpoint == .establishment && $0.sampleRate == 48_000
        })
        #expect(baseline.liveMaster.proposalOutcome == .hold)
        #expect(baseline.liveMaster.proposalFingerprint == nil)
        #expect(baseline.liveMaster.hardGatesPassed)
        #expect(ProfessionalQualityProfileEvaluator.evaluate(
            baseline,
            against: profile
        ).accepted)

        let candidates = try transitionCandidates()
        let validAttack = try ProfessionalQualityLiveMasterProvenance
            .transition(candidate: candidates.attenuation)
        let validRecovery = try ProfessionalQualityLiveMasterProvenance
            .transition(candidate: candidates.recovery)
        #expect(validAttack.hardGatesPassed)
        #expect(validRecovery.hardGatesPassed)

        let attacks: [(ProfessionalQualityLiveMasterProvenance,
            [ProfessionalQualityRejection])] = [
            (validAttack.attacked(.forgedPreTerminalScaling),
             [.liveTerminalScalingFailure]),
            (validAttack.attacked(.forgedPostTerminalScaling),
             [.liveTerminalScalingFailure]),
            (validAttack.attacked(.boostAboveUnity),
             [.liveBoostRejected, .liveTerminalScalingFailure]),
            (validAttack.attacked(.overAttack),
             [.liveTerminalScalingFailure, .liveTransitionOutOfBounds]),
            (validRecovery.attacked(.earlyRecovery),
             [.liveEarlyRecovery]),
            (validAttack.attacked(.staleRouteGeneration),
             [.liveRouteBoundaryFailure]),
            (validAttack.attacked(.staleControllerRevision),
             [.liveControllerMismatch]),
            (validAttack.attacked(.unboundProposalFingerprint),
             [.liveProposalMismatch]),
            (validAttack.attacked(.earlyBoundary),
             [.liveRouteBoundaryFailure]),
        ]
        for (provenance, expected) in attacks {
            let observation = try baseline.replacingLiveMaster(provenance)
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                observation,
                against: profile
            )
            #expect(!verdict.accepted)
            #expect(verdict.reasons == expected.sorted {
                $0.rawValue < $1.rawValue
            })
            #expect(verdict.failedMetrics.isEmpty)
        }
    }

    @Test("Old observation profile adversarial and holdout JSON is rejected")
    @MainActor
    func legacyPolicyJSONIsRejected() throws {
        let artifacts = try diverseArtifacts()
        let observation = try #require(
            artifacts.calibration.trajectories.first?.observations.first
        )
        let currentObservationJSON = try observation.deterministicJSON()
        let oldObservationJSON = try replacingJSONIdentity(
            currentObservationJSON,
            replacements: [
                "\"schemaVersion\":18": "\"schemaVersion\":17",
                "autotechno-professional-quality-observation.v18":
                    "autotechno-professional-quality-observation.v17",
            ]
        )
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityObservation.decodeDeterministicJSON(
                oldObservationJSON
            )
        }

        let oldProfileJSON = try replacingJSONIdentity(
            artifacts.profile.deterministicJSON(),
            replacements: [
                "\"schemaVersion\":18": "\"schemaVersion\":17",
                ProfessionalQualityCalibrationProfile.profileVersion:
                    "autotechno-professional-quality-profile.v25",
            ]
        )
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityCalibrationProfile.decodeDeterministicJSON(
                oldProfileJSON
            )
        }

        let oldAdversarialJSON = try replacingJSONIdentity(
            artifacts.adversarial.deterministicJSON(),
            replacements: [
                "\"schemaVersion\":22": "\"schemaVersion\":21",
                ProfessionalQualityAdversarialSuiteReport.suiteVersion:
                    "autotechno-professional-quality-adversarial.v21",
            ]
        )
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityAdversarialSuiteReport.decodeDeterministicJSON(
                oldAdversarialJSON
            )
        }

        let oldHoldoutJSON = try replacingJSONIdentity(
            artifacts.holdout.deterministicJSON(),
            replacements: [
                "\"schemaVersion\":20": "\"schemaVersion\":19",
                "autotechno-professional-quality-holdout.v20":
                    "autotechno-professional-quality-holdout.v19",
                "autotechno-professional-quality-holdout-evaluator.v20":
                    "autotechno-professional-quality-holdout-evaluator.v19",
            ]
        )
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityHoldoutQualification.decodeDeterministicJSON(
                oldHoldoutJSON
            )
        }
    }

    @Test("Serialized live observation provenance is never trusted")
    func serializedLiveObservationProvenanceIsRejected() throws {
        let observation = try #require(
            try representativeObservations().first
        )
        let current = try observation.deterministicJSON()
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityObservation.decodeDeterministicJSON(current)
        }
        for field in [
            "routeGenerationValid",
            "proposalBindingValid",
            "preTrimBindingValid",
            "postTrimBindingValid",
            "terminalScalingValid",
            "boundaryValid",
        ] {
            let malicious = try replacingJSONIdentity(
                current,
                replacements: ["\"\(field)\":true": "\"\(field)\":false"]
            )
            #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
                try ProfessionalQualityObservation.decodeDeterministicJSON(
                    malicious
                )
            }
        }
    }

    @Test("Missing v30 artifacts cannot activate the v30 evaluator")
    func legacyPrimaryArtifactsAreIneligible() {
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityPrimaryArtifacts.load()
        }
    }

    @Test("Diverse corpus identity is ordered and bounded")
    func diverseCorpusIdentity() throws {
        let trajectories = try (0..<24).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "corpus-\(index)",
                observations: representativeObservations(
                    trajectoryOffset: Double(index) * 0.001
                )
            )
        }
        let forward = try ProfessionalQualityCalibrationCorpus(
            trajectories: trajectories
        )
        let reversed = try ProfessionalQualityCalibrationCorpus(
            trajectories: Array(trajectories.reversed())
        )

        #expect(forward == reversed)
        #expect(forward.fingerprint == reversed.fingerprint)
        #expect(forward.sourceTrajectoryCount == 24)
        #expect(forward.sourceObservationCount == 24 * 14)
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationProfile(
                corpus: ProfessionalQualityCalibrationCorpus(
                    trajectories: Array(trajectories.dropLast())
                )
            )
        }
    }

    @Test("Score-inapplicable pad values do not train calibration bounds")
    func scoreInapplicablePadValuesDoNotTrainBounds() throws {
        let padMetrics: [ProfessionalQualityMetric] = [
            .padRhythmicFilterDifferenceToPadDBMean,
            .padRhythmicAmplitudeGateDifferenceToPadDBMean,
            .padRhythmicSpatialDifferenceToSendDBMean,
        ]
        let trajectories = try (0..<24).map { index in
            let observations = try representativeObservations(
                trajectoryOffset: Double(index) * 0.001
            ).map { observation in
                let inapplicable = index == 0 &&
                    observation.checkpoint == .chapterChange
                let checkpointIndex = try #require(
                    CanonicalJourneyCheckpoint.allCases.firstIndex(
                        of: observation.checkpoint
                    )
                )
                let activeValue = -24 + Double(checkpointIndex) * 0.25 +
                    Double(index) * 0.01 +
                    (observation.sampleRate == 48_000 ? 0.2 : 0)
                let inapplicableValue = observation.sampleRate == 48_000
                    ? 20.0
                    : 0.0
                var projected = try observation.replacing(
                    .padRhythmicModulationActiveBarRatio,
                    with: inapplicable ? 0 : 0.5
                )
                for (metricIndex, metric) in padMetrics.enumerated() {
                    projected = try projected.replacing(
                        metric,
                        with: inapplicable
                            ? inapplicableValue
                            : activeValue + Double(metricIndex) * 0.1
                    )
                }
                return projected
            }
            return try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "pad-applicability-\(index)",
                observations: observations
            )
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: ProfessionalQualityCalibrationCorpus(
                trajectories: trajectories
            )
        )

        for metric in padMetrics {
            let checkpointBounds = try #require(
                profile[.chapterChange]?[metric]
            )
            #expect(checkpointBounds.upper < 0)
            let trajectoryBounds = try #require(
                profile.trajectories.first {
                    $0.trajectory == .establishmentToChapterChange &&
                        $0.metric == metric
                }
            )
            #expect(trajectoryBounds.lowerDelta > -3)
            #expect(trajectoryBounds.upperDelta < 3)
            let rateBounds = try #require(profile.rateConsistency.first {
                $0.checkpoint == .chapterChange && $0.metric == metric
            })
            #expect(rateBounds.maximumAbsoluteDelta < 2)
        }
    }

    @Test("Holdout qualification requires disjoint accepted journeys")
    @MainActor
    func holdoutDisjointnessAndAcceptance() throws {
        let artifacts = try diverseArtifacts()
        let liveCandidates = try transitionCandidates()
        let overlapCorpus = try ProfessionalQualityCalibrationCorpus(
            trajectories: [artifacts.calibration.trajectories[0]] +
                (0..<3).map { index in
                    try ProfessionalQualityCalibrationTrajectory(
                        sourceBankFingerprint: "overlap-holdout-\(index)",
                        observations: representativeObservations()
                    )
                }
        )
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityHoldoutQualification(
                profile: artifacts.profile,
                adversarialSuite: artifacts.adversarial,
                calibrationCorpus: artifacts.calibration,
                holdoutCorpus: overlapCorpus
            )
        }

        let release = try #require(artifacts.profile[.release])
        let peak = try #require(release[.truePeakDBTP])
        var rejectedObservations = try representativeObservations(
            liveCandidates: liveCandidates
        )
        let targetIndex = try #require(rejectedObservations.firstIndex {
            $0.checkpoint == .release && $0.sampleRate == 48_000
        })
        rejectedObservations[targetIndex] = try rejectedObservations[targetIndex]
            .replacing(.truePeakDBTP, with: peak.upper + 0.1)
        let rejectedCorpus = try ProfessionalQualityCalibrationCorpus(
            trajectories: [
                try ProfessionalQualityCalibrationTrajectory(
                    sourceBankFingerprint: "rejected-holdout",
                    observations: rejectedObservations
                ),
            ] + (0..<3).map { index in
                try ProfessionalQualityCalibrationTrajectory(
                    sourceBankFingerprint: "accepted-holdout-\(index)",
                    observations: representativeObservations(
                        liveCandidates: liveCandidates
                    )
                )
            }
        )
        let holdout = try ProfessionalQualityHoldoutQualification(
            profile: artifacts.profile,
            adversarialSuite: artifacts.adversarial,
            calibrationCorpus: artifacts.calibration,
            holdoutCorpus: rejectedCorpus
        )
        #expect(!holdout.qualified)
        #expect(holdout.acceptedObservationCount ==
                holdout.sourceObservationCount - 1)
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryEvaluator(
                profile: artifacts.profile,
                adversarialSuite: artifacts.adversarial,
                holdoutQualification: holdout
            )
        }
    }

    @Test("Primary preparation remains unavailable without current artifacts")
    func preparationEvaluatorAvailability() {
        let representativeRate = ProfessionalQualityPreparationEvaluator(
            sampleRate: 48_000,
            artifacts: nil
        )
        let unsupportedRate = ProfessionalQualityPreparationEvaluator(
            sampleRate: 8_000,
            artifacts: nil
        )
        for evaluator in [representativeRate, unsupportedRate] {
            #expect(evaluator.availability == .artifactsUnavailable)
            #expect(evaluator.policyVersion ==
                    QualityQualificationContract.uncalibratedPolicyVersion)
            #expect(evaluator.evaluatorVersion ==
                    QualityQualificationContract.uncalibratedEvaluatorVersion)
        }
    }

    @Test("Incomplete rate matrices and non-finite metrics cannot calibrate")
    func invalidCalibrationInputs() throws {
        let observations = try representativeObservations()
        #expect(throws: ProfessionalQualityCalibrationError
            .incompleteRepresentativeRates) {
            try ProfessionalQualityCalibrationProfile(
                engineVersion: QualityQualificationContract.engineVersion,
                sourceBankFingerprint: "incomplete-bank-test",
                sampleRates: [48_000],
                observations: observations.filter { $0.sampleRate == 48_000 }
            )
        }

        var metrics = metricValues(checkpointIndex: 0, rateOffset: 0)
        metrics[0] = ProfessionalQualityMetricValue(
            metric: metrics[0].metric,
            value: .nan
        )
        #expect(throws: ProfessionalQualityCalibrationError.nonFiniteMetric(
            metrics[0].metric
        )) {
            try ProfessionalQualityObservation(
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: .establishment,
                sampleRate: 48_000,
                hardGatesPassed: true,
                liveMaster: try homeProvenance(),
                metrics: metrics
            )
        }
    }

    private func representativeObservations(
        trajectoryOffset: Double = 0,
        liveCandidates: ProfessionalQualityLiveCandidateChain? = nil
    ) throws
        -> [ProfessionalQualityObservation] {
        let liveObservations: [ProfessionalQualityObservation]
        if let liveCandidates {
            liveObservations = try [
                liveCandidates.attenuation,
                liveCandidates.recovery,
            ].map { candidate in
                guard let phraseKind = AutonomousPhraseKind(
                    rawValue: candidate.symbolic.phraseKind
                ), let checkpoint = CanonicalJourneyCheckpoint.applicable(
                    phraseIndex: candidate.symbolic.phraseIndex,
                    phraseKind: phraseKind,
                    chapterChanged: candidate.symbolic.chapterChanged
                ).first else {
                    throw ProfessionalQualityCalibrationError.profileMismatch
                }
                return try ProfessionalQualityObservation(
                    candidate: candidate,
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: checkpoint
                )
            }
        } else {
            liveObservations = []
        }
        var observations: [ProfessionalQualityObservation] = []
        for (checkpointIndex, checkpoint) in
            CanonicalJourneyCheckpoint.allCases.enumerated() {
            let liveAtCheckpoint = liveObservations.filter {
                $0.checkpoint == checkpoint
            }
            for (rateIndex, sampleRate) in ProfessionalQualityCalibrationProfile
                .requiredSampleRates.enumerated() {
                let metrics = liveAtCheckpoint.isEmpty
                    ? metricValues(
                        checkpointIndex: checkpointIndex,
                        rateOffset: (sampleRate == 48_000 ? 0.01 : 0) +
                            trajectoryOffset
                    )
                    : liveAtCheckpoint[
                        min(rateIndex, liveAtCheckpoint.count - 1)
                    ].metrics
                observations.append(try ProfessionalQualityObservation(
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: checkpoint,
                    sampleRate: sampleRate,
                    hardGatesPassed: true,
                    liveMaster: try homeProvenance(),
                    metrics: metrics
                ))
            }
        }
        return observations
    }

    private func copyOccurrence(
        _ source: ProfessionalQualityLiveScheduledOccurrenceEvidence,
        playerSampleRange: Range<Int64>? = nil,
        planFingerprint: String? = nil,
        sampleRate: Double? = nil,
        routeGeneration: Int? = nil,
        occurrenceEpoch: UInt64? = nil,
        controllerStateFingerprint: String? = nil
    ) -> ProfessionalQualityLiveScheduledOccurrenceEvidence {
        let resolvedRange = playerSampleRange ?? source.playerSampleRange
        return ProfessionalQualityLiveScheduledOccurrenceEvidence(
            phraseIndex: source.phraseIndex,
            planFingerprint: planFingerprint ?? source.planFingerprint,
            playerSampleRange: resolvedRange,
            capturePlayerSampleRange: source.capturePlayerSampleRange,
            sampleRate: sampleRate ?? source.sampleRate,
            routeGeneration: routeGeneration ?? source.routeGeneration,
            occurrenceEpoch: occurrenceEpoch ?? source.occurrenceEpoch,
            controllerRevision: source.controllerRevision,
            qualityPolicyVersion: source.qualityPolicyVersion,
            evaluatorVersion: source.evaluatorVersion,
            controllerPolicyVersion: source.controllerPolicyVersion,
            controllerStateFingerprint: controllerStateFingerprint ??
                source.controllerStateFingerprint,
            appliedMasterTrimDB: source.appliedMasterTrimDB,
            applicableCheckpoints: source.applicableCheckpoints,
            earliestEligibleFutureSample: resolvedRange.upperBound
        )
    }

    @MainActor
    private func diverseArtifacts() throws -> (
        calibration: ProfessionalQualityCalibrationCorpus,
        profile: ProfessionalQualityCalibrationProfile,
        adversarial: ProfessionalQualityAdversarialSuiteReport,
        holdout: ProfessionalQualityHoldoutQualification
    ) {
        let liveCandidates = try transitionCandidates()
        let calibrationTrajectories = try (0..<24).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "calibration-\(index)",
                observations: representativeObservations(
                    liveCandidates: liveCandidates
                )
            )
        }
        let calibration = try ProfessionalQualityCalibrationCorpus(
            trajectories: calibrationTrajectories
        )
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: calibration
        )
        let adversarial = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceCorpus: calibration,
            liveCandidateChain: liveCandidates
        )
        let holdoutTrajectories = try (0..<4).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "holdout-\(index)",
                observations: representativeObservations(
                    liveCandidates: liveCandidates
                )
            )
        }
        let holdoutCorpus = try ProfessionalQualityCalibrationCorpus(
            trajectories: holdoutTrajectories
        )
        let holdout = try ProfessionalQualityHoldoutQualification(
            profile: profile,
            adversarialSuite: adversarial,
            calibrationCorpus: calibration,
            holdoutCorpus: holdoutCorpus
        )
        return (calibration, profile, adversarial, holdout)
    }

    private static let homeCandidateFixture:
        AutonomousCandidateEvaluationVector? = {
        let director = AutonomousSessionDirector(rootSeed: 91_773)
        let state = director.initialState()
        guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: director.plan(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: { false }
        ), prepared.selectedCandidateEvidence.isComplete else { return nil }
        return prepared.selectedCandidateEvidence
    }()

    private func candidateWithModalEvents() throws
        -> AutonomousCandidateEvaluationVector {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for _ in 0..<128 {
            let plan = director.plan(from: state)
            guard plan.resolvedBars.contains(where: {
                !$0.modalPercussionArticulations.isEmpty
            }) else {
                state.advancePlanning(using: plan)
                continue
            }
            var renderState = RenderState()
            renderState.barIndex = plan.startBar
            guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: renderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator(),
                cancellationRequested: { false }
            ), prepared.selectedCandidateEvidence.isComplete,
                prepared.selectedCandidateEvidence.modalPercussion.contains(where: {
                    !$0.events.isEmpty
                }) else {
                throw ProfessionalQualityCalibrationError.profileMismatch
            }
            return prepared.selectedCandidateEvidence
        }
        throw ProfessionalQualityCalibrationError.profileMismatch
    }

    private func candidateWithActiveSpectralReveal() throws
        -> AutonomousCandidateEvaluationVector {
        for seed in UInt64(1)...1_024 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let state = director.initialState()
            let plan = director.plan(from: state)
            let synthPlan = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars,
                compositionBars: plan.phraseComposition
            )
            let hasActiveAnchor = synthPlan.bars.contains { bar in
                bar.spectralRevealEligible && bar.upperNotes.contains {
                    $0.role == .anchor &&
                        $0.spectralReveal.relation == .emerging
                }
            }
            guard hasActiveAnchor else { continue }
            var renderState = RenderState()
            renderState.barIndex = plan.startBar
            guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: renderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator(),
                cancellationRequested: { false }
            ), prepared.selectedCandidateEvidence.isComplete,
                prepared.selectedCandidateEvidence.instruments
                    .flatMap(\.architectures)
                    .compactMap(\.upperSpectralReveal)
                    .contains(where: { $0.eligible && $0.active }) else {
                throw ProfessionalQualityCalibrationError.profileMismatch
            }
            return prepared.selectedCandidateEvidence
        }
        throw ProfessionalQualityCalibrationError.profileMismatch
    }

    private func candidateWithActiveHarmonicTail() throws
        -> AutonomousCandidateEvaluationVector {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for _ in 0..<128 {
            let plan = director.plan(from: state)
            let synthPlan = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars,
                compositionBars: plan.phraseComposition
            )
            guard synthPlan.bars.flatMap(\.upperNotes).contains(where: {
                $0.instrument.spectralTextureHarmonicTailRelation != nil
            }) else {
                state.advancePlanning(using: plan)
                continue
            }
            var renderState = RenderState()
            renderState.barIndex = plan.startBar
            guard let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: renderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator(),
                cancellationRequested: { false }
            ), prepared.selectedCandidateEvidence.isComplete,
                prepared.selectedCandidateEvidence.instruments
                    .flatMap(\.architectures)
                    .contains(where: {
                        $0.spectralTextureHarmonicTail != nil
                    }) else {
                throw ProfessionalQualityCalibrationError.profileMismatch
            }
            return prepared.selectedCandidateEvidence
        }
        throw ProfessionalQualityCalibrationError.profileMismatch
    }

    private func homeCandidate() throws
        -> AutonomousCandidateEvaluationVector {
        guard let candidate = Self.homeCandidateFixture else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return candidate
    }

    private func homeProvenance() throws
        -> ProfessionalQualityLiveMasterProvenance {
        try .home(candidate: homeCandidate())
    }

    private static let transitionCandidateFixture:
        ProfessionalQualityLiveCandidateChain? =
            try? LiveFeedbackTestSupport.renderLiveTransitionCandidates()

    @MainActor
    private func transitionCandidates() throws
        -> ProfessionalQualityLiveCandidateChain {
        guard let candidates = Self.transitionCandidateFixture else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return candidates
    }

    private func metricValues(
        checkpointIndex: Int,
        rateOffset: Double
    ) -> [ProfessionalQualityMetricValue] {
        let movement = 0.50 + Double(checkpointIndex) * 0.025 + rateOffset
        let scalar: [ProfessionalQualityMetric: Double] = [
            .integratedLoudnessLUFS: -10 + Double(checkpointIndex) * 0.2,
            .maximumMomentaryLoudnessLUFS: -8,
            .maximumShortTermLoudnessLUFS: -9,
            .loudnessRangeLU: 4 + Double(checkpointIndex) * 0.1,
            .truePeakDBTP: -1.2,
            .crestFactorDB: 8,
            .absoluteDCOffset: 0.0001,
            .stereoCorrelation: 0.72,
            .lowStereoCorrelation: 0.98,
            .maximumBoundaryDelta: 0.05,
            .movementScore: movement,
            .activeWindowRatio: 0.92,
            .spectralCentroidMeanHz: 1_800 + Double(checkpointIndex) * 40,
            .spectralCentroidSpreadHz: 1_200,
            .spectralBandwidthMeanHz: 1_600,
            .spectralFlatnessMean: 0.20,
            .spectralRolloff85MeanHz: 5_000,
            .positiveSpectralFluxMean: 0.08,
            .positiveSpectralFluxPeak: 0.20,
            .rmsTrajectoryDeltaMeanDB: 1.5,
            .rmsTrajectoryDeltaPeakDB: 6,
            .barLoudnessSpanLU: 4,
            .barCentroidSpanHz: 1_200,
            .barTransientDensityMean: 2,
            .barTransientDensitySpan: 1,
            .barCrestFactorMean: 5,
            .barCrestFactorSpan: 2,
            .maskingMaximumOverlap: 0.50,
            .maskingOverlapWindowRatio: 0.10,
            .maskingLongestRunRatio: 0.15,
            .activeKickFoundationBarRatio: 0.80,
            .kickOverFoundationActiveDBMean: 15,
            .kickGroundedBarRatio: 0.75,
            .kickWithheldBarRatio: 0.125,
            .kickRecoveryBarRatio: 0.125,
            .kickEventCountMean: 4,
            .kickAudibleToDetectorDBMean: -9,
            .kickDuckingEnvelopeRatioMean: 0.90,
            .kickAudibleGainMean: 0.35,
            .modalPercussionActiveBarRatio: 0.5,
            .modalPercussionEventCountMean: 1,
            .modalPercussionPitchErrorCentsMaximum: 0,
            .modalPercussionAttackToBodyDBMean: 6,
            .modalPercussionTailToBodyDBMean: -8,
            .modalPercussionSpectralCentroidMeanHz: 620,
            .modalPercussionMaskingMaximumOverlap: 0.2,
            .modalPercussionMaximumPoleRadius: 0.998,
            .upperSpectralRevealActiveEventRatio: 1,
            .spectralHarmonicTailUpperBandEnergyRatioMean: 0.42,
        ]
        return ProfessionalQualityMetric.allCases.map { metric in
            let metricRateOffset: Double = switch metric {
            case .upperSpectralRevealActiveEventRatio: 0
            case .modalPercussionMaximumPoleRadius: rateOffset * 0.01
            default: rateOffset
            }
            return ProfessionalQualityMetricValue(
                metric: metric,
                value: (scalar[metric] ?? 0) + metricRateOffset
            )
        }
    }

    private func replacingJSONIdentity(
        _ data: Data,
        replacements: [String: String]
    ) throws -> Data {
        var json = try #require(String(data: data, encoding: .utf8))
        for (source, replacement) in replacements {
            json = json.replacingOccurrences(of: source, with: replacement)
        }
        return try #require(json.data(using: .utf8))
    }
}
