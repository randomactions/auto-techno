import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Professional quality calibration")
struct ProfessionalQualityCalibrationTests {
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

    @Test("Musical consequence metrics are versioned and non-compensable")
    func modalMetricContract() {
        #expect(ProfessionalQualityMetric.allCases.count == 67)
        #expect(ProfessionalQualityObservation.schemaVersion == 13)
        #expect(ProfessionalQualityObservation.observationVersion ==
                "autotechno-professional-quality-observation.v13")
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 16)
        #expect(ProfessionalEvidenceReportBank.evidenceVersion ==
                "autotechno-professional-evidence.v16")
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v13")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v13")
        #expect(ProfessionalQualityPrimaryEvaluator.requiredProfileVersion ==
                "autotechno-professional-quality-profile.v13")
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 13)
        #expect(ProfessionalQualityCalibrationProfile.profileVersion ==
                "autotechno-professional-quality-profile.v13")
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 14)
        #expect(ProfessionalQualityAdversarialSuiteReport.suiteVersion ==
                "autotechno-professional-quality-adversarial.v14")
        #expect(ProfessionalQualityHoldoutQualification.schemaVersion == 12)
        #expect(ProfessionalQualityHoldoutQualification.qualificationVersion ==
                "autotechno-professional-quality-holdout.v12")

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
        ).allSatisfy { $0.metric != .loudnessRangeLU })
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
        ).allSatisfy { $0.metric != .rmsTrajectoryDeltaPeakDB })

        let meanChanged = try observations.map { observation in
            observation.sampleRate == 44_100
                ? try observation.replacing(.rmsTrajectoryDeltaMeanDB, with: 120)
                : observation
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: meanChanged,
            against: profile
        ).contains {
            $0.kind == .rateConsistency &&
                $0.metric == .rmsTrajectoryDeltaMeanDB &&
                $0.checkpoint == .release
        })
    }

    @Test("Constructed v13 artifacts activate only the single primary policy")
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
    func legacyPolicyJSONIsRejected() throws {
        let artifacts = try diverseArtifacts()
        let observation = try #require(
            artifacts.calibration.trajectories.first?.observations.first
        )
        let currentObservationJSON = try observation.deterministicJSON()
        let oldObservationJSON = try replacingJSONIdentity(
            currentObservationJSON,
            replacements: [
                "\"schemaVersion\":13": "\"schemaVersion\":12",
                "autotechno-professional-quality-observation.v13":
                    "autotechno-professional-quality-observation.v12",
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
                "\"schemaVersion\":13": "\"schemaVersion\":12",
                "autotechno-professional-quality-profile.v13":
                    "autotechno-professional-quality-profile.v12",
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
                "\"schemaVersion\":14": "\"schemaVersion\":13",
                "autotechno-professional-quality-adversarial.v14":
                    "autotechno-professional-quality-adversarial.v13",
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
                "\"schemaVersion\":12": "\"schemaVersion\":11",
                "autotechno-professional-quality-holdout.v12":
                    "autotechno-professional-quality-holdout.v11",
                "autotechno-professional-quality-holdout-evaluator.v12":
                    "autotechno-professional-quality-holdout-evaluator.v11",
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

    @Test("Bundled v13 primary artifacts activate the exact v13 evaluator")
    func primaryArtifacts() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        #expect(artifacts.profile.fingerprint ==
                ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint)
        #expect(artifacts.adversarialSuite.fingerprint ==
                ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint)
        #expect(artifacts.holdoutQualification.fingerprint ==
                ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint)
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

    @Test("Holdout qualification requires disjoint accepted journeys")
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

    @Test("Primary preparation remains unavailable without v13 artifacts")
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
        ]
        return ProfessionalQualityMetric.allCases.map { metric in
            let metricRateOffset = metric ==
                .modalPercussionMaximumPoleRadius
                ? rateOffset * 0.01 : rateOffset
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
