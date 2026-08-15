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

    @Test("Frozen development policy evaluates later engines without enabling runtime ranking")
    func developmentPolicy() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "development-policy-bank-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let adversarial = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceObservations: observations
        )
        let policy = try ProfessionalQualityDevelopmentPolicy(
            profile: profile,
            adversarialSuite: adversarial
        )
        #expect(policy.isAvailable)

        let future = try observations.map { observation in
            try ProfessionalQualityObservation(
                engineVersion: "autotechno-canonical-engine.future-test",
                checkpoint: observation.checkpoint,
                sampleRate: observation.sampleRate,
                hardGatesPassed: observation.hardGatesPassed,
                metrics: observation.metrics
            )
        }
        let accepted = try policy.evaluate(observations: future)
        #expect(accepted.qualified)
        #expect(accepted.calibrationSourceEngineVersion ==
                QualityQualificationContract.engineVersion)
        #expect(accepted.evaluatedEngineVersion ==
                "autotechno-canonical-engine.future-test")
        #expect(accepted.policyVersion ==
                ProfessionalQualityDevelopmentPolicy.policyVersion)

        let establishment = try #require(profile[.establishment])
        let masking = try #require(establishment[.maskingMaximumOverlap])
        var regressed = future
        let targetIndex = try #require(regressed.firstIndex {
            $0.checkpoint == .establishment && $0.sampleRate == 44_100
        })
        regressed[targetIndex] = try regressed[targetIndex].replacing(
            .maskingMaximumOverlap,
            with: masking.upper + 0.01
        )
        let rejected = try policy.evaluate(observations: regressed)
        #expect(!rejected.qualified)
        #expect(rejected.acceptedObservationCount == future.count - 1)
        #expect(rejected.verdicts.contains {
            !$0.accepted && $0.failedMetrics == [.maskingMaximumOverlap]
        })
    }

    @Test("Frozen aggregate resources load with their pinned identities")
    func frozenArtifacts() throws {
        let artifacts = try ProfessionalQualityFrozenArtifacts.load()

        #expect(artifacts.profile.isComplete)
        #expect(artifacts.adversarialSuite.passed)
        #expect(artifacts.policy.isAvailable)
        #expect(artifacts.profile.fingerprint ==
                ProfessionalQualityFrozenArtifacts.expectedProfileFingerprint)
        #expect(artifacts.adversarialSuite.fingerprint ==
                ProfessionalQualityFrozenArtifacts
                    .expectedAdversarialSuiteFingerprint)
        #expect(artifacts.profile.engineVersion ==
                "autotechno-canonical-engine.v10")
        #expect(artifacts.profile.engineVersion !=
                QualityQualificationContract.engineVersion)
        #expect(artifacts.profile.sampleRates ==
                ProfessionalQualityCalibrationProfile.requiredSampleRates)
    }

    @Test("Exact-engine paired policy selects only independently accepted candidates")
    func pairedCandidatePolicy() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "paired-candidate-policy-test",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations
        )
        let adversarial = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceObservations: observations
        )
        let evaluator = try ProfessionalQualityPairedCandidateEvaluator(
            profile: profile,
            adversarialSuite: adversarial
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
        #expect(evaluator.compare(primary: primary, alternate: rejected) == .primary)
        #expect(evaluator.compare(primary: rejected, alternate: primary) == .alternate)
        #expect(evaluator.compare(primary: primary, alternate: primary) == .tie)
        #expect(evaluator.compare(primary: rejected, alternate: rejected) == .fallback)
        #expect(evaluator.compare(primary: [], alternate: []) == .unavailable)
    }

    @Test("Historical development artifacts cannot activate current-engine pairing")
    func staleProfileCannotActivatePairing() throws {
        let frozen = try ProfessionalQualityFrozenArtifacts.load()
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPairedCandidateEvaluator(
                profile: frozen.profile,
                adversarialSuite: frozen.adversarialSuite
            )
        }
    }

    @Test("Current paired artifacts load with exact engine and policy identities")
    func pairedArtifacts() throws {
        let artifacts = try ProfessionalQualityPairedArtifacts.load()

        #expect(artifacts.profile.isComplete)
        #expect(artifacts.adversarialSuite.passed)
        #expect(artifacts.profile.engineVersion ==
                QualityQualificationContract.engineVersion)
        #expect(artifacts.profile.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion)
        #expect(artifacts.profile.fingerprint ==
                ProfessionalQualityPairedArtifacts.expectedProfileFingerprint)
        #expect(artifacts.adversarialSuite.fingerprint ==
                ProfessionalQualityPairedArtifacts
                    .expectedAdversarialSuiteFingerprint)
        #expect(artifacts.evaluator.policyVersion.contains(
            ProfessionalQualityPairedArtifacts.expectedProfileFingerprint
        ))
        #expect(artifacts.evaluator.policyVersion.contains(
            ProfessionalQualityPairedArtifacts
                .expectedAdversarialSuiteFingerprint
        ))
        #expect(artifacts.evaluator.requiresPairedCandidates)

        let reloaded = try ProfessionalQualityPairedArtifacts(
            profileData: artifacts.profile.deterministicJSON(),
            adversarialSuiteData: artifacts.adversarialSuite.deterministicJSON()
        )
        #expect(reloaded.profile == artifacts.profile)
        #expect(reloaded.adversarialSuite == artifacts.adversarialSuite)
        #expect(reloaded.evaluator.policyVersion ==
                artifacts.evaluator.policyVersion)
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

    private func representativeObservations() throws
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
                        rateOffset: sampleRate == 48_000 ? 0.01 : 0
                    )
                ))
            }
        }
        return observations
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
        ]
        return ProfessionalQualityMetric.allCases.map { metric in
            ProfessionalQualityMetricValue(
                metric: metric,
                value: (scalar[metric] ?? 0) + rateOffset
            )
        }
    }
}
