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
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "adversarial-bank-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let suite = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceObservations: observations
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
        ] {
            let attacked = try #require(suite.cases.first {
                $0.scenario == scenario
            })
            #expect(attacked.rejected)
            #expect(attacked.failedMetrics.contains(metric))
        }
    }

    @Test("Modal metrics are versioned, bounded, and non-compensable")
    func modalMetricContract() {
        #expect(ProfessionalQualityObservation.schemaVersion == 2)
        #expect(ProfessionalQualityObservation.observationVersion ==
                "autotechno-professional-quality-observation.v2")
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 5)
        #expect(ProfessionalEvidenceReportBank.evidenceVersion ==
                "autotechno-professional-evidence.v5")
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v2")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v2")
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 3)
        #expect(ProfessionalQualityAdversarialSuiteReport.suiteVersion ==
                "autotechno-professional-quality-adversarial.v3")

        for metric in [
            ProfessionalQualityMetric.modalPercussionPitchErrorCentsMaximum,
            .modalPercussionMaskingMaximumOverlap,
            .modalPercussionMaximumPoleRadius,
        ] {
            #expect(metric.acceptsSaferValuesBelowCalibration)
            #expect(metric.semanticMinimum == 0)
        }
        #expect(ProfessionalQualityMetric.modalPercussionActiveBarRatio
            .participatesInQualification)
        #expect(ProfessionalQualityMetric.modalPercussionEventCountMean
            .participatesInQualification)
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

    @Test("Exact-engine primary policy accepts only independently qualified evidence")
    func primaryCandidatePolicy() throws {
        let artifacts = try diverseArtifacts()
        let observations = artifacts.calibration.trajectories[1].observations
        let profile = artifacts.profile
        let adversarial = artifacts.adversarial
        let evaluator = try ProfessionalQualityPrimaryEvaluator(
            profile: profile,
            adversarialSuite: adversarial,
            holdoutQualification: artifacts.holdout
        )
        #expect(evaluator.policyVersion.contains(profile.fingerprint))
        #expect(evaluator.policyVersion.contains(adversarial.fingerprint))

        let primary = [try #require(observations.first {
            $0.checkpoint == .release && $0.sampleRate == 48_000
        })]
        let releaseProfile = try #require(profile[.release])
        let truePeakBounds = try #require(releaseProfile[.truePeakDBTP])
        let rejected = [try primary[0].replacing(
            .truePeakDBTP,
            with: truePeakBounds.upper + 0.01
        )]

        let acceptedAssessment = evaluator.assessment(of: primary)
        let rejectedAssessment = evaluator.assessment(of: rejected)
        #expect(acceptedAssessment.availability == .available)
        #expect(acceptedAssessment.accepted)
        #expect(rejectedAssessment.availability == .available)
        #expect(!rejectedAssessment.accepted)
        #expect(rejectedAssessment.verdicts.flatMap(\.failedMetrics) ==
                [.truePeakDBTP])
        #expect(evaluator.assessment(of: []).availability == .noApplicableCheckpoint)
    }

    @Test("Current primary artifacts load with exact engine and policy identities")
    func primaryArtifacts() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()

        #expect(artifacts.profile.isComplete)
        #expect(artifacts.adversarialSuite.passed)
        #expect(artifacts.profile.usesDiverseCalibration)
        #expect(artifacts.holdoutQualification.qualified)
        #expect(artifacts.profile.engineVersion ==
                QualityQualificationContract.engineVersion)
        #expect(artifacts.profile.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion)
        #expect(artifacts.profile.fingerprint ==
                ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint)
        #expect(artifacts.adversarialSuite.fingerprint ==
                ProfessionalQualityPrimaryArtifacts
                    .expectedAdversarialSuiteFingerprint)
        #expect(artifacts.evaluator.policyVersion.contains(
            ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint
        ))
        #expect(artifacts.evaluator.policyVersion.contains(
            ProfessionalQualityPrimaryArtifacts
                .expectedAdversarialSuiteFingerprint
        ))
        #expect(artifacts.evaluator.policyVersion.contains(
            ProfessionalQualityPrimaryArtifacts
                .expectedHoldoutQualificationFingerprint
        ))

        let reloaded = try ProfessionalQualityPrimaryArtifacts(
            profileData: artifacts.profile.deterministicJSON(),
            adversarialSuiteData: artifacts.adversarialSuite.deterministicJSON(),
            holdoutQualificationData: artifacts.holdoutQualification
                .deterministicJSON()
        )
        #expect(reloaded.profile == artifacts.profile)
        #expect(reloaded.adversarialSuite == artifacts.adversarialSuite)
        #expect(reloaded.holdoutQualification ==
                artifacts.holdoutQualification)
        #expect(reloaded.evaluator.policyVersion ==
                artifacts.evaluator.policyVersion)
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
        var rejectedObservations = try representativeObservations()
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
                    observations: representativeObservations()
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

    @Test("Primary preparation evaluator is available only for preloaded covered routes")
    func preparationEvaluatorAvailability() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let available = ProfessionalQualityPreparationEvaluator(
            sampleRate: 48_000,
            artifacts: artifacts
        )
        #expect(available.availability == .available)
        #expect(available.policyVersion == artifacts.evaluator.policyVersion)
        #expect(available.evaluatorVersion == artifacts.evaluator.evaluatorVersion)
        #expect(available.policyVersion.contains("primary-calibrated.v2"))

        let unsupported = ProfessionalQualityPreparationEvaluator(
            sampleRate: 8_000,
            artifacts: artifacts
        )
        #expect(unsupported.availability == .unsupportedSampleRate)
        #expect(unsupported.policyVersion ==
                QualityQualificationContract.uncalibratedPolicyVersion)
        #expect(unsupported.evaluatorVersion ==
                QualityQualificationContract.uncalibratedEvaluatorVersion)

        let missing = ProfessionalQualityPreparationEvaluator(
            sampleRate: 48_000,
            artifacts: nil
        )
        #expect(missing.availability == .artifactsUnavailable)
        #expect(missing.policyVersion ==
                QualityQualificationContract.uncalibratedPolicyVersion)
        #expect(missing.evaluatorVersion ==
                QualityQualificationContract.uncalibratedEvaluatorVersion)
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
                metrics: metrics
            )
        }
    }

    private func representativeObservations(
        trajectoryOffset: Double = 0
    ) throws
        -> [ProfessionalQualityObservation] {
        var observations: [ProfessionalQualityObservation] = []
        for (checkpointIndex, checkpoint) in
            CanonicalJourneyCheckpoint.allCases.enumerated() {
            for sampleRate in ProfessionalQualityCalibrationProfile
                .requiredSampleRates {
                observations.append(try ProfessionalQualityObservation(
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: checkpoint,
                    sampleRate: sampleRate,
                    hardGatesPassed: true,
                    metrics: metricValues(
                        checkpointIndex: checkpointIndex,
                        rateOffset: (sampleRate == 48_000 ? 0.01 : 0) +
                            trajectoryOffset
                    )
                ))
            }
        }
        return observations
    }

    private func diverseArtifacts() throws -> (
        calibration: ProfessionalQualityCalibrationCorpus,
        profile: ProfessionalQualityCalibrationProfile,
        adversarial: ProfessionalQualityAdversarialSuiteReport,
        holdout: ProfessionalQualityHoldoutQualification
    ) {
        let calibrationTrajectories = try (0..<24).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "calibration-\(index)",
                observations: representativeObservations()
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
            sourceCorpus: calibration
        )
        let holdoutTrajectories = try (0..<4).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "holdout-\(index)",
                observations: representativeObservations()
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
}
