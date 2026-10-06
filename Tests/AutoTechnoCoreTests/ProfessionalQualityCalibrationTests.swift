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
    @Test("Pre-floor calibration evidence cannot activate the corrected analyzer")
    func preFloorEvidenceArtifactsAreIneligible() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let profileURL = repository.appendingPathComponent(
            "Sources/AutoTechnoDSP/Resources/professional-quality-primary-profile-v30.json")
        let object = try #require(JSONSerialization.jsonObject(
            with: Data(contentsOf: profileURL)) as? [String: Any])
        #expect(object["evidenceVersion"] as? String ==
                "autotechno-professional-evidence.v29")
        #expect(ProfessionalEvidenceReportBank.evidenceVersion ==
                "autotechno-professional-evidence.v30")
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            _ = try historicalV30PrimaryArtifacts()
        }
    }

    @Test("Window-supported profiles bind the new observation contract without activating v30")
    func windowSupportedContractIdentity() throws {
        let observations = try representativeObservations().map { try windowObservation($0) }
        let corpus = try windowCorpus(observations)
        let profile = try ProfessionalQualityCalibrationProfile(corpus: corpus)
        #expect(profile.isComplete)
        #expect(profile.profileVersion == ProfessionalQualityMeasurementContract.modalWindowProfileVersion)
        #expect(profile.profileVersion != ProfessionalQualityPrimaryEvaluator.requiredProfileVersion)
        #expect(profile.observationVersion == ProfessionalQualityMeasurementContract.modalWindowObservationVersion)
        #expect(try ProfessionalQualityCalibrationProfile.decodeDeterministicJSON(
            profile.deterministicJSON()) == profile)
        for observation in observations {
            #expect(observation.isComplete)
            #expect(ProfessionalQualityProfileEvaluator.evaluate(observation, against: profile).accepted)
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: observations, against: profile).accepted)
        let legacy = try representativeObservations()
        #expect(ProfessionalQualityProfileEvaluator.evaluate(legacy[0], against: profile)
            .reasons == [.profileMismatch])
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: legacy, against: profile).availability == .invalidObservations)
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationTrajectory(sourceBankFingerprint: "mixed-contract",
                observations: [legacy[0]] + Array(observations.dropFirst()))
        }
    }

    @Test("Required missing, partial, undefined and mixed modal windows fail every quality path")
    func unavailableWindowSupportIsNeverWaived() throws {
        let legacy = try representativeObservations()
        let observations = try legacy.map { try windowObservation($0) }
        let profile = try ProfessionalQualityCalibrationProfile(corpus: windowCorpus(observations))
        let index = try #require(observations.firstIndex {
            $0.checkpoint == .majorBreak && $0.sampleRate == 44_100
        })
        for kind in ["missing", "partial", "undefined", "mixed"] {
            let unsupported = try windowObservation(legacy[index], kind: kind)
            #expect(unsupported.isComplete)
            #expect(unsupported[.modalPercussionTailToBodyDBMean] == nil)
            #expect(unsupported.measurementApplicability(.modalPercussionTailToBodyDBMean) == .unavailable)
            let local = ProfessionalQualityProfileEvaluator.evaluate(unsupported, against: profile)
            #expect(!local.accepted)
            #expect(local.reasons.contains(.unavailableMeasurement))
            #expect(local.failedMetrics.contains(.modalPercussionTailToBodyDBMean))
            var attacked = observations
            attacked[index] = unsupported
            let numericalIndex = try #require(attacked.firstIndex {
                $0.checkpoint == .chapterChange && $0.sampleRate == 48_000
            })
            attacked[numericalIndex] = try attacked[numericalIndex]
                .replacing(.maximumBoundaryDelta, with: 100)
            let assessment = ProfessionalQualityRelationshipEvaluator.evaluate(
                observations: attacked, against: profile)
            #expect(assessment.availability == .unavailableMeasurementSupport)
            #expect(assessment.support == .insufficient)
            #expect(assessment.confidence == .unavailable)
            #expect(assessment.unavailableMeasurements.contains {
                $0.metric == .modalPercussionTailToBodyDBMean && $0.reason == .requiredWindowSupport
            })
            #expect(assessment.failures.contains { $0.metric == .maximumBoundaryDelta })
            let unavailable = try #require(ProfessionalQualityMeasurementContract
                .unavailableMeasurements(in: attacked).first)
            #expect(throws: ProfessionalQualityCalibrationError.unavailableMeasurement(unavailable)) {
                try ProfessionalQualityCalibrationProfile(corpus: windowCorpus(attacked))
            }
            let data = try unsupported.deterministicJSON()
            let wire = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let values = try #require(wire["metrics"] as? [[String: Any]])
            #expect(!values.contains { $0["metric"] as? String == ProfessionalQualityMetric.modalPercussionTailToBodyDBMean.rawValue })
            #expect(wire["modalWindowSupport"] != nil)
            if kind == "mixed" {
                #expect(unsupported.modalWindowSupport?.tailToBodyDBMean != nil)
                #expect(unsupported.modalWindowSupport?.tailBodyMeasuredEventCount == 1)
                #expect(unsupported.modalWindowSupport?.tailBodyExcludedEventCount == 1)
            }
        }
    }

    @Test("Score absence is not trained as zero and cannot qualify an unseen active relation")
    func absentWindowMeasurementsKeepCoverage() throws {
        let legacy = try representativeObservations()
        let observations = try legacy.map {
            try windowObservation($0, kind: $0.checkpoint == .majorBreak ? "absent" : "measured")
        }
        let profile = try ProfessionalQualityCalibrationProfile(corpus: windowCorpus(observations))
        #expect(profile.isComplete)
        for observation in observations where observation.checkpoint == .majorBreak {
            #expect(observation[.modalPercussionTailToBodyDBMean] == nil)
            #expect(observation.measurementApplicability(.modalPercussionTailToBodyDBMean) == .notRequired)
            #expect(ProfessionalQualityProfileEvaluator.evaluate(observation, against: profile).accepted)
        }
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: observations, against: profile).accepted)
        let conditional = try #require(profile.trajectories.first {
            $0.trajectory == .establishmentToMajorBreak &&
                $0.metric == .modalPercussionTailToBodyDBMean
        })
        #expect(conditional.sourceComparisonCount == 0)
        let nowActive = try legacy.map { try windowObservation($0) }
        let assessment = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: nowActive, against: profile)
        #expect(!assessment.accepted)
        #expect(assessment.availability == .unavailableCalibrationSupport)

        var asymmetric = nowActive
        let index = try #require(asymmetric.firstIndex {
            $0.checkpoint == .majorBreak && $0.sampleRate == 44_100
        })
        asymmetric[index] = observations[index]
        let mismatch = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: asymmetric, against: profile)
        #expect(mismatch.availability == .unavailableMeasurementSupport)
        #expect(mismatch.unavailableMeasurements.contains { $0.reason == .rateApplicabilityMismatch })
        #expect(throws: ProfessionalQualityCalibrationError.unavailableMeasurement(
            mismatch.unavailableMeasurements[0])) {
            try ProfessionalQualityCalibrationProfile(corpus: windowCorpus(asymmetric))
        }
    }

    @Test("Measured zero remains numeric while malformed support and fabricated absence fail closed")
    func windowSupportSerializationAndSilence() throws {
        let legacy = try representativeObservations()[0]
        let silent = try windowObservation(legacy, kind: "silent")
        #expect(silent[.modalPercussionTailToBodyDBMean] == -120)
        #expect(silent.measurementApplicability(.modalPercussionTailToBodyDBMean) == .measured)
        #expect(silent.modalWindowSupport?.tailBodySupport.measuredEventCount == 1)
        let absent = try windowObservation(legacy, kind: "absent")
        #expect(absent.metrics.count == legacy.metrics.count - 2)
        #expect(throws: ProfessionalQualityCalibrationError.invalidMetricSet) {
            try ProfessionalQualityObservation(engineVersion: absent.engineVersion,
                checkpoint: absent.checkpoint, sampleRate: absent.sampleRate,
                hardGatesPassed: true, liveMaster: absent.liveMaster,
                metrics: legacy.metrics, modalWindowSupport: absent.modalWindowSupport)
        }
        let support = try #require(silent.modalWindowSupport)
        var wire = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(support)) as? [String: Any])
        wire["tailBodyMeasuredEventCount"] = 0
        let forged = try JSONDecoder().decode(ProfessionalQualityModalWindowEvidence.self,
            from: JSONSerialization.data(withJSONObject: wire))
        #expect(!forged.isComplete)
        #expect(throws: ProfessionalQualityCalibrationError.invalidMetricSet) {
            try ProfessionalQualityObservation(engineVersion: silent.engineVersion,
                checkpoint: silent.checkpoint, sampleRate: silent.sampleRate,
                hardGatesPassed: true, liveMaster: silent.liveMaster,
                metrics: silent.metrics, modalWindowSupport: forged)
        }
        #expect(try JSONDecoder().decode(ProfessionalQualityModalWindowEvidence.self,
            from: JSONEncoder().encode(support)) == support)
    }

    private func windowCorpus(_ observations: [ProfessionalQualityObservation]) throws
        -> ProfessionalQualityCalibrationCorpus {
        try ProfessionalQualityCalibrationCorpus(trajectories: (0..<24).map {
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "window-contract-unit-fixture-\($0)", observations: observations)
        })
    }

    /// Reduced support fixtures test the algebra and failure contract, never
    /// shipping qualification. Candidate/DSP fixtures independently test geometry.
    private func windowObservation(_ legacy: ProfessionalQualityObservation,
                                   kind: String = "measured") throws -> ProfessionalQualityObservation {
        let count = kind == "absent" ? 0 : (kind == "mixed" ? 2 : 1)
        func counts(measured: Int, missing: Int = 0, partial: Int = 0, undefined: Int = 0)
            -> [String: Int] {
            ["sourceEventCount": count, "measuredEventCount": measured,
             "missingWindowEventCount": missing, "partialWindowEventCount": partial,
             "undefinedBodyEventCount": undefined]
        }
        let attackCount = kind == "undefined" ? 0 : count
        let tailCount = ["measured", "silent", "mixed"].contains(kind) ? 1 : 0
        let attackSupport = counts(measured: attackCount, undefined: kind == "undefined" ? 1 : 0)
        let tailSupport = counts(measured: tailCount,
            missing: ["missing", "mixed"].contains(kind) ? 1 : 0,
            partial: kind == "partial" ? 1 : 0, undefined: kind == "undefined" ? 1 : 0)
        var wire: [String: Any] = [
            "schemaVersion": 2, "checkpoint": legacy.checkpoint.rawValue,
            "sampleRate": legacy.sampleRate, "sourceReportFingerprint": "reduced-support-unit-fixture",
            "sourceEventCount": count, "attackBodyMeasuredEventCount": attackCount,
            "tailBodyMeasuredEventCount": tailCount,
            "attackBodyExcludedEventCount": count - attackCount,
            "tailBodyExcludedEventCount": count - tailCount,
            "attackBodySupport": attackSupport, "tailBodySupport": tailSupport,
        ]
        if attackCount > 0, let value = legacy[.modalPercussionAttackToBodyDBMean] { wire["attackToBodyDBMean"] = value }
        if tailCount > 0, let value = legacy[.modalPercussionTailToBodyDBMean] { wire["tailToBodyDBMean"] = kind == "silent" ? -120 : value }
        let support = try JSONDecoder().decode(ProfessionalQualityModalWindowEvidence.self,
            from: JSONSerialization.data(withJSONObject: wire))
        var metrics = legacy.metrics.filter {
            !ProfessionalQualityMeasurementContract.modalMetrics.contains($0.metric)
        }
        if support.attackBodySupport.applicability == .measured, let value = support.attackToBodyDBMean {
            metrics.append(.init(metric: .modalPercussionAttackToBodyDBMean, value: value))
        }
        if support.tailBodySupport.applicability == .measured, let value = support.tailToBodyDBMean {
            metrics.append(.init(metric: .modalPercussionTailToBodyDBMean, value: value))
        }
        return try ProfessionalQualityObservation(engineVersion: legacy.engineVersion,
            checkpoint: legacy.checkpoint, sampleRate: legacy.sampleRate,
            hardGatesPassed: legacy.hardGatesPassed, liveMaster: legacy.liveMaster,
            metrics: metrics, modalWindowSupport: support)
    }

    @Test("Range challenges skip absent tails, use source checkpoint bounds and retain every identity")
    func measuredRangeChallengeSourceSelection() throws {
        let observations = try representativeObservations().map { try windowObservation($0) }
        let profile = try ProfessionalQualityCalibrationProfile(corpus: windowCorpus(observations))
        let legacy = try representativeObservations()
        let absent = try windowObservation(try #require(legacy.first {
            $0.checkpoint == .establishment && $0.sampleRate == 48_000
        }), kind: "absent")
        let measured = try #require(observations.first {
            $0.checkpoint == .majorBreak && $0.sampleRate == 48_000
        })
        let metric = ProfessionalQualityMetric.modalPercussionTailToBodyDBMean
        #expect(absent[metric] == nil && absent.measurementApplicability(metric) == .notRequired)
        let originalJSON = try measured.deterministicJSON()
        for preferLower in [true, false] {
            let challenged = try ProfessionalQualityAdversarialSuiteReport.measuredRangeChallenge(
                metric, preferLower: preferLower, profile: profile, observations: [absent, measured])
            #expect(challenged.checkpoint == measured.checkpoint)
            #expect(challenged.sampleRate == measured.sampleRate)
            #expect(challenged.modalWindowSupport == measured.modalWindowSupport)
            #expect(challenged.continuousModalSource == measured.continuousModalSource)
            #expect(challenged.liveMaster == measured.liveMaster)
            #expect(challenged.hardGatesPassed == measured.hardGatesPassed)
            #expect(challenged[metric] != measured[metric])
            #expect(challenged.metrics.filter { $0.metric != metric } ==
                measured.metrics.filter { $0.metric != metric })
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(challenged, against: profile)
            #expect(verdict.reasons == [.metricOutOfRange] && verdict.failedMetrics == [metric])
            #expect(try measured.deterministicJSON() == originalJSON)
            #expect(try ProfessionalQualityAdversarialSuiteReport.measuredRangeChallenge(
                metric, preferLower: preferLower, profile: profile, observations: [absent, measured]) == challenged)
        }
    }

    @Test("Absent and unavailable challenge dimensions refuse; measured zero remains a numeric source")
    func measuredRangeChallengeSupportRefusal() throws {
        let legacy = try representativeObservations()
        let metric = ProfessionalQualityMetric.modalPercussionTailToBodyDBMean
        let observations = try legacy.map { observation in
            let supported = try windowObservation(observation)
            return observation.checkpoint == .majorBreak
                ? try supported.replacing(metric, with: 0) : supported
        }
        let profile = try ProfessionalQualityCalibrationProfile(corpus: windowCorpus(observations))
        let origin = try #require(legacy.first {
            $0.checkpoint == .majorBreak && $0.sampleRate == 48_000
        })
        for kind in ["absent", "missing", "partial", "undefined", "mixed"] {
            let unsupported = try windowObservation(origin, kind: kind)
            #expect(throws: ProfessionalQualityCalibrationError.invalidMetricSet) {
                try ProfessionalQualityAdversarialSuiteReport.measuredRangeChallenge(metric,
                    preferLower: false, profile: profile, observations: [unsupported])
            }
        }
        let zero = try #require(observations.first {
            $0.checkpoint == .majorBreak && $0.sampleRate == 48_000
        })
        #expect(zero[metric] == 0 && zero.measurementApplicability(metric) == .measured)
        let challenged = try ProfessionalQualityAdversarialSuiteReport.measuredRangeChallenge(
            metric, preferLower: false, profile: profile, observations: [zero])
        #expect(challenged[metric] != 0)
        #expect(ProfessionalQualityProfileEvaluator.evaluate(challenged, against: profile)
            .failedMetrics == [metric])
    }

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
        let cutoffRatios: [Double] = activeReveal.map {
            $0.maximumAppliedCutoffHz / candidate.routeContinuation.sampleRate
        }
        let expectedCutoffRatioMean: Double =
            cutoffRatios.reduce(0, +) / Double(activeReveal.count)
        #expect(observation[.upperSpectralRevealAppliedCutoffRatioMean] ==
                expectedCutoffRatioMean)
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
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 30)
        #expect(ProfessionalEvidenceReportBank.evidenceVersion ==
                "autotechno-professional-evidence.v30")
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v32")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v32")
        #expect(ProfessionalQualityPrimaryEvaluator.requiredProfileVersion ==
                "autotechno-professional-quality-profile.v33")
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 22)
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

    @Test("AT0038 typed local witness reconstructs current candidate fields without admission")
    func localAcceptanceReconstructsCandidateFields() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(rawValue: candidate.symbolic.phraseKind))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex, phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged).first)
        let policy = "at0038-descriptive-fixture.v1", source = "actual-focused-candidate"
        let kick = try ProfessionalQualityKickFoundationLocalEvidence(candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion, policyVersion: policy,
            sourceReportFingerprint: source, checkpoint: checkpoint)
        let masking = try ProfessionalQualityMaskingLocalEvidence(candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion, policyVersion: policy,
            sourceReportFingerprint: source, checkpoint: checkpoint)
        func inspect() throws -> AT0038LocalEvidenceWitness {
            try AT0038LocalEvidenceAcceptanceSupport.validate(candidate: candidate,
                checkpoint: checkpoint, engineVersion: QualityQualificationContract.engineVersion,
                policyVersion: policy, sourceReportFingerprint: source, kick: kick, masking: masking)
        }
        let witness = try inspect()
        #expect(try inspect() == witness)
        let existing = try ProfessionalQualityObservation(candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion, checkpoint: checkpoint)
        #expect(witness.kick.meanDB == existing[.kickOverFoundationActiveDBMean])
        #expect(witness.masking.observationCount == candidate.masking.reduce(0) {
            $0 + $1.observations.count
        })
        #expect(ProfessionalQualityKickFoundationLocalEvidence.evidenceCategory == .descriptive)
        #expect(ProfessionalQualityMaskingLocalEvidence.evidenceCategory == .descriptive)
    }

    @Test("AT0038 current labels cannot hide changed local projection fields")
    func localAcceptanceRejectsPoisonedProjection() throws {
        let candidate = try homeCandidate()
        let phraseKind = try #require(AutonomousPhraseKind(rawValue: candidate.symbolic.phraseKind))
        let checkpoint = try #require(CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex, phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged).first)
        let policy = "at0038-descriptive-fixture.v1", source = "actual-focused-candidate"
        let kick = try ProfessionalQualityKickFoundationLocalEvidence(candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion, policyVersion: policy,
            sourceReportFingerprint: source, checkpoint: checkpoint)
        let masking = try ProfessionalQualityMaskingLocalEvidence(candidate: candidate,
            engineVersion: QualityQualificationContract.engineVersion, policyVersion: policy,
            sourceReportFingerprint: source, checkpoint: checkpoint)
        let encoder = JSONEncoder()
        let originalKick = try #require(JSONSerialization.jsonObject(
            with: encoder.encode(kick)) as? [String: Any])
        let originalMask = try #require(JSONSerialization.jsonObject(
            with: encoder.encode(masking)) as? [String: Any])
        for (key, value) in [("sourceReportFingerprint", "foreign-report" as Any),
                             ("engineVersion", "foreign-engine" as Any),
                             ("schemaVersion", 999 as Any),
                             ("spreadDB", ((kick.spreadDB ?? 0) + 1) as Any)] {
            var poisoned = originalKick
            poisoned[key] = value
            let changed = try JSONDecoder().decode(ProfessionalQualityKickFoundationLocalEvidence.self,
                from: JSONSerialization.data(withJSONObject: poisoned))
            #expect(throws: AT0038AcceptanceError.self) {
                try AT0038LocalEvidenceAcceptanceSupport.validate(candidate: candidate,
                    checkpoint: checkpoint, engineVersion: QualityQualificationContract.engineVersion,
                    policyVersion: policy, sourceReportFingerprint: source, kick: changed, masking: masking)
            }
        }
        let observations = try #require(originalMask["observations"] as? [[String: Any]])
        let first = try #require(observations.first)
        let firstBar = try #require(first["bar"] as? Int)
        let firstOverlap = try #require(first["maximumOverlap"] as? Double)
        // Keep the report identity and candidate-wide counts unchanged while
        // moving one local field; reduced summaries must not conceal this.
        for (key, value) in [("bar", (firstBar + 1) as Any),
                             ("bandName", "foreign-band" as Any),
                             ("firstRole", "foreign-role" as Any),
                             ("maximumOverlap", (firstOverlap + 0.1) as Any)] {
            var changedObservations = observations
            changedObservations[0][key] = value
            var poisoned = originalMask
            poisoned["observations"] = changedObservations
            let changed = try JSONDecoder().decode(ProfessionalQualityMaskingLocalEvidence.self,
                from: JSONSerialization.data(withJSONObject: poisoned))
            #expect(throws: AT0038AcceptanceError.self) {
                try AT0038LocalEvidenceAcceptanceSupport.validate(candidate: candidate,
                    checkpoint: checkpoint, engineVersion: QualityQualificationContract.engineVersion,
                    policyVersion: policy, sourceReportFingerprint: source, kick: kick, masking: changed)
            }
        }
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
            try AT0038LocalFixtureAcceptanceSupport.maskingFixture(
                activeBar: activeBar, activeBand: activeBand)
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

    @Test("Tail applicability distinguishes absent score events from measured natural-body zero")
    func upperPercussionTailScoreApplicability() throws {
        let director = AutonomousSessionDirector(rootSeed: 91_773)
        var state = director.initialState()
        var seen = Set<String>()
        for _ in 0..<128 {
            let plan = director.plan(from: state)
            let scoreEvents = plan.resolvedBars.flatMap(\.upperPercussionTailArticulations)
            let clearanceCount = scoreEvents.filter { $0.role == .foregroundClearance }.count
            let kind = scoreEvents.isEmpty ? "absent" :
                (clearanceCount == 0 ? "natural" : "clearance")
            if seen.insert(kind).inserted {
                var renderState = RenderState()
                renderState.barIndex = plan.startBar
                let preparation = AutonomousPhrasePreparer.prepareIfNotCancelled(
                    plan: plan, sessionSeed: state.rootSeed, memory: state.memory,
                    sampleRate: 8_000, incomingRenderState: renderState,
                    incomingGraphState: GeneratedDSPContinuationState(), previousGraph: nil,
                    incomingQualityState: state.quality,
                    evaluator: AcceptingPrimaryTestEvaluator(), cancellationRequested: { false })
                let prepared = try #require(preparation)
                let vector = prepared.selectedCandidateEvidence
                #expect(vector.isComplete)
                let checkpoint = CanonicalJourneyCheckpoint.primaryQualification(
                    phraseIndex: plan.phraseIndex, phraseKind: plan.kind,
                    chapterChanged: vector.symbolic.chapterChanged) ?? .longContinuation
                let observation = try ProfessionalQualityObservation(candidate: vector,
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: checkpoint)
                let eventCount = vector.upperPercussionTail.flatMap(\.events).count
                let support = try #require(observation.upperPercussionTailSupport)
                #expect(support.isComplete && support.sourceEventCount == eventCount)
                #expect(support.foregroundClearanceEventCount == clearanceCount)
                let changed = try observation.replacing(.maximumBoundaryDelta, with: 100)
                #expect(changed.upperPercussionTailSupport == support)
                #expect(observation.foreignRateChallenge().upperPercussionTailSupport == support)
                #expect(eventCount == scoreEvents.count)
                #expect(observation[.upperPercussionTailClearanceEventRatio] ==
                    Double(clearanceCount) / Double(max(1, eventCount)))
                #expect(observation.measurementApplicability(
                    .upperPercussionTailClearanceEventRatio) ==
                    (eventCount == 0 ? .notRequired : .measured))
                #expect(observation.measurementApplicability(
                    .upperPercussionTailRenderedTailToAttackDBMean) ==
                    (clearanceCount == 0 ? .notRequired : .measured))
            }
            if seen.count == 3 { break }
            state.advancePlanning(using: plan)
        }
        #expect(seen == Set(["absent", "natural", "clearance"]))
        #expect(!ProfessionalQualityUpperPercussionTailSupport(
            sourceEventCount: -1, foregroundClearanceEventCount: 0).isComplete)
        #expect(!ProfessionalQualityUpperPercussionTailSupport(
            sourceEventCount: 0, foregroundClearanceEventCount: 1).isComplete)
        #expect(!ProfessionalQualityUpperPercussionTailSupport(
            sourceEventCount: AutonomousCandidateEvaluationVector.maximumBarCount *
                AutonomousCandidateEvaluationVector.maximumUpperPercussionTailEventsPerBar + 1,
            foregroundClearanceEventCount: 0).isComplete)
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

    @Test("Dotted-rhythm activation reuses measured checkpoint bounds only in the new continuous contract")
    func conditionalDottedRhythmBounds() throws {
        let metrics: [(ProfessionalQualityMetric, Double)] = [
            (.foundationDottedRhythmActiveBarRatio, 0.4),
            (.foundationDottedRhythmCrestFactorDBMean, 18.199913326947108),
        ]
        func fitted(active: Bool, localRatio: Double = 0) throws -> ProfessionalQualityCalibrationProfile {
            let observations = try representativeObservations().map { observation in
                let measured = active && [.establishment, .chapterChange].contains(observation.checkpoint)
                return try observation
                    .replacing(.foundationDottedRhythmActiveBarRatio,
                        with: measured ? 0.4 : (observation.checkpoint == .longContinuation ? localRatio : 0))
                    .replacing(.foundationDottedRhythmCrestFactorDBMean,
                        with: measured ? 18.199913326947108 : 0)
            }
            return try ProfessionalQualityCalibrationProfile(
                engineVersion: QualityQualificationContract.engineVersion,
                sourceBankFingerprint: "synthetic-dotted-bounds-control",
                sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
                observations: observations)
        }
        // A diagnostic scope fixture exercises the bounds owner; it is neither
        // a typed continuous corpus nor a diverse/qualified primary artifact.
        func scoped(_ profile: ProfessionalQualityCalibrationProfile,
                    scope: ProfessionalQualityMeasurementScope) throws -> ProfessionalQualityCalibrationProfile {
            var wire = try #require(JSONSerialization.jsonObject(
                with: profile.deterministicJSON()) as? [String: Any])
            wire["schemaVersion"] = scope.profileSchema
            wire["profileVersion"] = scope.profileVersion
            wire["observationVersion"] = scope.observationVersion
            return try JSONDecoder().decode(ProfessionalQualityCalibrationProfile.self,
                from: JSONSerialization.data(withJSONObject: wire))
        }
        let legacy = try fitted(active: true)
        let profile = try scoped(legacy, scope: .continuousModalWindow)
        #expect(profile.isComplete && !profile.usesDiverseCalibration)
        #expect(profile.profileVersion == "autotechno-professional-quality-profile.v33")
        #expect(profile.schemaVersion == 25)
        for (metric, value) in metrics {
            let local = try #require(profile[.longContinuation]?[metric])
            let envelope = try #require(metric.conditionalNeutralCalibrationEnvelope(for: .continuousModalWindow))
            #expect(local.lower == envelope.lowerBound && local.upper == envelope.upperBound)
            #expect(!local.contains(value))
            let active = profile.checkpoints.compactMap { checkpoint -> ProfessionalQualityMetricBounds? in
                guard let bounds = checkpoint[metric], bounds != local else { return nil }
                return bounds
            }
            let effective = try #require(profile.effectiveBounds(for: metric,
                at: .longContinuation, observedValue: value))
            #expect(effective.lower == active.map(\.lower).min())
            #expect(effective.upper == active.map(\.upper).max())
            #expect(effective.contains(value))
            #expect(profile.effectiveBounds(for: metric, at: .longContinuation, observedValue: 0) == local)
            for extreme in [-1.0, effective.upper + 1] {
                #expect(profile.effectiveBounds(for: metric, at: .longContinuation,
                    observedValue: extreme)?.contains(extreme) == false)
            }
            #expect(profile.effectiveBounds(for: metric, at: .establishment,
                observedValue: value) == profile[.establishment]?[metric])
            for scope in [ProfessionalQualityMeasurementScope.legacy, .barLocalModalWindow] {
                let historical = try scoped(legacy, scope: scope)
                #expect(historical.effectiveBounds(for: metric, at: .longContinuation,
                    observedValue: value) == historical[.longContinuation]?[metric])
            }
            let unseen = try scoped(fitted(active: false), scope: .continuousModalWindow)
            #expect(unseen.effectiveBounds(for: metric, at: .longContinuation,
                observedValue: value) == unseen[.longContinuation]?[metric])
            #expect(unseen.effectiveBounds(for: metric, at: .longContinuation,
                observedValue: value)?.contains(value) == false)
        }
        let locallyMeasured = try scoped(fitted(active: true, localRatio: 0.01), scope: .continuousModalWindow)
        #expect(locallyMeasured.effectiveBounds(for: .foundationDottedRhythmActiveBarRatio,
            at: .longContinuation, observedValue: 0.4) ==
            locallyMeasured[.longContinuation]?[.foundationDottedRhythmActiveBarRatio])
        var retired = try #require(JSONSerialization.jsonObject(
            with: profile.deterministicJSON()) as? [String: Any])
        retired["schemaVersion"] = 24
        retired["profileVersion"] = "autotechno-professional-quality-profile.v32"
        let retiredData = try JSONSerialization.data(withJSONObject: retired,
            options: [.sortedKeys, .withoutEscapingSlashes])
        let diagnostic = try JSONDecoder().decode(ProfessionalQualityCalibrationProfile.self, from: retiredData)
        #expect(diagnostic.measurementScope == nil && !diagnostic.isComplete)
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityCalibrationProfile.decodeDeterministicJSON(retiredData)
        }
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

    @Test("AT0038 paired mean controls cover every native checkpoint under supplied bounds")
    func localAcceptanceMeanControlsUseCanonicalBounds() throws {
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "at0038-mechanistic-profile-fixture",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: representativeObservations())
        var covered = Set<String>()
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            for rate in ProfessionalQualityCalibrationProfile.requiredSampleRates {
                let proof = try AT0038LocalFixtureAcceptanceSupport.pairedKickMeanControl(
                    profile: profile, checkpoint: checkpoint, sampleRate: rate)
                #expect(try AT0038LocalFixtureAcceptanceSupport.pairedKickMeanControl(
                    profile: profile, checkpoint: checkpoint, sampleRate: rate).localized == proof.localized)
                for (source, projected) in [(proof.uniformSource, proof.uniform),
                                            (proof.localizedSource, proof.localized)] {
                    let independent = source.map { 20 * log10($0.kickActiveRMS / $0.foundationActiveRMS) }
                    #expect(projected.barMeasurements.map(\.bar) == source.map(\.bar))
                    #expect(projected.barMeasurements.map(\.kickOverFoundationDB) == independent)
                    #expect(projected.meanDB == independent.reduce(0, +) / Double(independent.count))
                    let mean = try #require(projected.meanDB)
                    #expect(try #require(profile.effectiveBounds(for: .kickOverFoundationActiveDBMean,
                        at: checkpoint, observedValue: mean)).contains(mean))
                    #expect(projected.checkpoint == checkpoint && projected.sampleRate == rate)
                }
                #expect(proof.uniform.spreadDB == 0)
                #expect(try #require(proof.localized.spreadDB) > 0)
                #expect(proof.uniform.sourceReportFingerprint != proof.localized.sourceReportFingerprint)
                #expect(proof.profileFingerprint == profile.fingerprint)
                covered.insert(checkpoint.rawValue + ":" + String(rate))
            }
        }
        #expect(covered.count == 14)
        #expect(throws: AT0038AcceptanceError.invalidProjection) {
            try AT0038LocalFixtureAcceptanceSupport.pairedKickMeanControl(
                profile: profile, checkpoint: .establishment, sampleRate: 8_000)
        }
        // This mechanically fitted profile is not current qualified native authority.
    }

    @Test("AT0038 localized masking failure survives favorable peers across the native matrix")
    func localAcceptanceMaskingFailureUsesCanonicalVerdict() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "at0038-mechanistic-masking-profile",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations)
        var covered = Set<String>()
        for baseline in observations {
            let checkpoint = try #require(profile[baseline.checkpoint])
            let bounds = try #require(checkpoint[.maskingMaximumOverlap])
            let centered = try ProfessionalQualityObservation(
                engineVersion: baseline.engineVersion, checkpoint: baseline.checkpoint,
                sampleRate: baseline.sampleRate, hardGatesPassed: true, liveMaster: baseline.liveMaster,
                metrics: checkpoint.bounds.map { ProfessionalQualityMetricValue(
                    metric: $0.metric, value: $0.lower + ($0.upper - $0.lower) * 0.5) })
            let neutral = try AT0038LocalFixtureAcceptanceSupport.maskingFixture(
                activeBar: -1, activeBand: "none", checkpoint: baseline.checkpoint,
                sampleRate: baseline.sampleRate)
            #expect(try AT0038LocalFixtureAcceptanceSupport.maskingFixtureVerdict(neutral,
                baseline: centered, profile: profile).accepted)
            #expect(neutral.observations.allSatisfy {
                $0.activePairWindowCount == 0 && $0.overlapWindowCount == 0 && $0.maximumOverlap == 0
            })
            let localMaximum = bounds.upper + (1 - bounds.upper) * 0.5
            #expect(localMaximum > bounds.upper && localMaximum <= 1)
            for (bar, band) in [(50, "sub"), (51, "high")] {
                let local = try AT0038LocalFixtureAcceptanceSupport.maskingFixture(
                    activeBar: bar, activeBand: band, maximumOverlap: localMaximum,
                    checkpoint: baseline.checkpoint, sampleRate: baseline.sampleRate)
                let failed = try #require(local.observations.first { $0.maximumOverlap == localMaximum })
                #expect(failed.bar == bar && failed.bandName == band)
                #expect(local.observations.filter { $0.maximumOverlap == 0 }.count == 23)
                let verdict = try AT0038LocalFixtureAcceptanceSupport.maskingFixtureVerdict(local,
                    baseline: centered, profile: profile)
                #expect(!verdict.accepted)
                #expect(verdict.reasons == [.metricOutOfRange])
                #expect(verdict.failedMetrics == [.maskingMaximumOverlap])
                #expect(try AT0038LocalFixtureAcceptanceSupport.maskingFixtureVerdict(local,
                    baseline: centered, profile: profile) == verdict)
            }
            covered.insert(baseline.checkpoint.rawValue + ":" + String(baseline.sampleRate))
        }
        #expect(covered.count == 14)
        // Existing bound/evaluator mechanism only; no new local musical threshold.
    }

    @Test("AT0038 absent kick pairs stay explicitly unavailable across the native matrix")
    func localAcceptanceAbsentPairsKeepAvailability() throws {
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            for rate in ProfessionalQualityCalibrationProfile.requiredSampleRates {
                let source: [ProfessionalQualityKickFoundationLocalEvidence.SourceBar] = [
                    .init(bar: 8, kickActiveRMS: 0, foundationActiveRMS: 1),
                    .init(bar: 9, kickActiveRMS: 1, foundationActiveRMS: 0),
                    .init(bar: 10, kickActiveRMS: 0, foundationActiveRMS: 0),
                ]
                func reconstruct() throws -> ProfessionalQualityKickFoundationLocalEvidence {
                    try .init(engineVersion: QualityQualificationContract.engineVersion,
                        policyVersion: "at0038-mechanistic-absence.v1",
                        sourceReportFingerprint: "absent:" + checkpoint.rawValue + ":" + String(rate),
                        planFingerprint: "at0038-absent-fixture.v1", checkpoint: checkpoint,
                        sampleRate: rate, sourceBarCount: source.count, sourceBars: source)
                }
                let local = try reconstruct()
                #expect(try local == reconstruct())
                #expect(local.sourceBarCount == 3 && local.pairedBarCount == 0)
                #expect(local.availability == .noActivePairedBars && local.barMeasurements.isEmpty)
                #expect(local.meanDB == nil && local.minimumDB == nil && local.maximumDB == nil)
                #expect(local.spreadDB == nil)
                #expect(local.checkpoint == checkpoint && local.sampleRate == rate)
            }
        }
    }

    @Test("AT0038 masking fixture verdict refuses mismatched native context")
    func localAcceptanceMaskingRefusesContextMismatch() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "at0038-context-profile",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations)
        let baseline = try #require(observations.first {
            $0.checkpoint == .establishment && $0.sampleRate == 44_100
        })
        for (checkpoint, rate) in [(CanonicalJourneyCheckpoint.contrast, 44_100.0),
                                   (.establishment, 48_000.0), (.establishment, 8_000.0)] {
            let local = try AT0038LocalFixtureAcceptanceSupport.maskingFixture(
                activeBar: -1, activeBand: "none", checkpoint: checkpoint, sampleRate: rate)
            #expect(throws: AT0038AcceptanceError.invalidProjection) {
                try AT0038LocalFixtureAcceptanceSupport.maskingFixtureVerdict(local,
                    baseline: baseline, profile: profile)
            }
        }
        let unsupported = try ProfessionalQualityObservation(
            engineVersion: baseline.engineVersion, checkpoint: baseline.checkpoint,
            sampleRate: 8_000, hardGatesPassed: true, liveMaster: baseline.liveMaster,
            metrics: baseline.metrics)
        let unsupportedLocal = try AT0038LocalFixtureAcceptanceSupport.maskingFixture(
            activeBar: -1, activeBand: "none", sampleRate: 8_000)
        #expect(throws: AT0038AcceptanceError.invalidProjection) {
            try AT0038LocalFixtureAcceptanceSupport.maskingFixtureVerdict(unsupportedLocal,
                baseline: unsupported, profile: profile)
        }
        let foreignObservations = try observations.map {
            try ProfessionalQualityObservation(engineVersion: "foreign-engine", checkpoint: $0.checkpoint,
                sampleRate: $0.sampleRate, hardGatesPassed: $0.hardGatesPassed,
                liveMaster: $0.liveMaster, metrics: $0.metrics)
        }
        let foreignProfile = try ProfessionalQualityCalibrationProfile(
            engineVersion: "foreign-engine", sourceBankFingerprint: "foreign-source",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: foreignObservations)
        let local = try AT0038LocalFixtureAcceptanceSupport.maskingFixture(
            activeBar: -1, activeBand: "none", sampleRate: baseline.sampleRate)
        #expect(throws: AT0038AcceptanceError.invalidProjection) {
            try AT0038LocalFixtureAcceptanceSupport.maskingFixtureVerdict(local,
                baseline: baseline, profile: foreignProfile)
        }
    }

    @Test("AT0038 localized duration fails alone while pooled masking stays favorable")
    func localAcceptanceMaskingDurationMatrix() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "at0038-duration-mechanistic-profile",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations)
        let matrix = try AT0038LocalFixtureAcceptanceSupport.maskingDurationMatrix(
            profile: profile, observations: observations)
        #expect(matrix.count == 14)
        #expect(try AT0038LocalFixtureAcceptanceSupport.maskingDurationMatrix(
            profile: profile, observations: Array(observations.reversed())) == matrix)
        for control in matrix {
            let checkpoint = control.baseline.checkpoint
            let bounds = try #require(profile[checkpoint]?[.maskingLongestRunRatio])
            let ratio = Double(control.overlapRun) / Double(SpectrumMaskingAnalyzer.analyzedWindowCount)
            #expect(ratio > bounds.upper)
            #expect(Double(control.overlapRun - 1) / Double(SpectrumMaskingAnalyzer.analyzedWindowCount) <= bounds.upper)
            #expect(control.neutral.observations.allSatisfy { $0.activePairWindowCount == 0 })
            #expect(control.profileFingerprint == profile.fingerprint)
            for (local, verdict) in zip(control.localized, control.verdicts) {
                let active = try #require(local.observations.first { $0.longestOverlapRun > 0 })
                #expect(active.firstRole == MixRole.foundation.rawValue)
                #expect(active.secondRole == MixRole.percussion.rawValue)
                #expect([(50, "sub"), (51, "high")].contains { $0.0 == active.bar && $0.1 == active.bandName })
                #expect(active.activePairWindowCount == control.overlapRun)
                #expect(active.overlapWindowCount == control.overlapRun)
                #expect(local.observations.filter { $0.longestOverlapRun == 0 }.count == 23)
                let analyzed = local.observations.reduce(0) { $0 + $1.analyzedWindowCount }
                let pooled = Double(local.observations.reduce(0) { $0 + $1.overlapWindowCount }) / Double(analyzed)
                #expect(try #require(profile[checkpoint]?[.maskingOverlapWindowRatio]).contains(pooled))
                #expect(try #require(profile[checkpoint]?[.maskingMaximumOverlap]).contains(active.maximumOverlap))
                #expect(!verdict.accepted && verdict.failedMetrics == [.maskingLongestRunRatio])
                #expect(try AT0038LocalFixtureAcceptanceSupport.maskingFixtureVerdict(local,
                    baseline: control.baseline, profile: profile) == verdict)
            }
        }
        // The supplied fixture profile is not native/current artifact authority.
    }

    @Test("AT0038 duration matrix refuses missing duplicate foreign and unprovable contexts")
    func localAcceptanceMaskingDurationRefusesIncompleteMatrix() throws {
        let observations = try representativeObservations()
        let profile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "at0038-duration-context-profile",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            observations: observations)
        for partial in [Array(observations.dropLast()), observations + [observations[0]],
                        Array(observations.dropLast()) + [observations[0]]] {
            #expect(throws: AT0038AcceptanceError.incompleteNativeBank) {
                try AT0038LocalFixtureAcceptanceSupport.maskingDurationMatrix(profile: profile, observations: partial)
            }
        }
        let unsupported = try observations.map {
            try ProfessionalQualityObservation(engineVersion: $0.engineVersion, checkpoint: $0.checkpoint,
                sampleRate: 8_000, hardGatesPassed: $0.hardGatesPassed, liveMaster: $0.liveMaster, metrics: $0.metrics)
        }
        #expect(throws: AT0038AcceptanceError.incompleteNativeBank) {
            try AT0038LocalFixtureAcceptanceSupport.maskingDurationMatrix(profile: profile, observations: unsupported)
        }
        let foreign = try observations.map {
            try ProfessionalQualityObservation(engineVersion: "foreign-engine", checkpoint: $0.checkpoint,
                sampleRate: $0.sampleRate, hardGatesPassed: $0.hardGatesPassed, liveMaster: $0.liveMaster, metrics: $0.metrics)
        }
        #expect(throws: AT0038AcceptanceError.invalidProjection) {
            try AT0038LocalFixtureAcceptanceSupport.maskingDurationMatrix(profile: profile, observations: foreign)
        }
        let unprovable = try observations.map { try $0.replacing(.maskingLongestRunRatio, with: 1) }
        let unprovableProfile = try ProfessionalQualityCalibrationProfile(
            engineVersion: QualityQualificationContract.engineVersion,
            sourceBankFingerprint: "at0038-duration-full-range-profile",
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates, observations: unprovable)
        #expect(throws: AT0038AcceptanceError.invalidProjection) {
            try AT0038LocalFixtureAcceptanceSupport.maskingDurationMatrix(profile: unprovableProfile, observations: unprovable)
        }
        for invalidRun in [0, SpectrumMaskingAnalyzer.analyzedWindowCount + 1] {
            #expect(throws: AT0038AcceptanceError.invalidProjection) {
                try AT0038LocalFixtureAcceptanceSupport.maskingFixture(activeBar: 50,
                    activeBand: "sub", overlapRun: invalidRun)
            }
        }
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
        // The shared legacy relationship reducer retains support semantics,
        // but cannot authorize the sole continuous prepared policy.
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryEvaluator(profile: artifacts.profile,
                adversarialSuite: artifacts.adversarial, holdoutQualification: artifacts.holdout)
        }

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

    @Test("Constructed legacy artifacts cannot activate the sole continuous prepared policy")
    @MainActor
    func legacyConstructedPrimaryPolicyIsIneligible() throws {
        let artifacts = try diverseArtifacts()
        #expect(artifacts.profile.isComplete && artifacts.adversarial.passed && artifacts.holdout.qualified)
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryEvaluator(profile: artifacts.profile,
                adversarialSuite: artifacts.adversarial, holdoutQualification: artifacts.holdout)
        }
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

    @Test("Historical bundled primary artifacts are ineligible under the continuous policy")
    func legacyPrimaryArtifactsAreIneligible() {
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try historicalV30PrimaryArtifacts()
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

    @Test("Expanded calibration corpus retains a finite capacity and rejects duplicate sources")
    func windowCoverageCorpusCapacity() throws {
        let observations = try representativeObservations(trajectoryOffset: 0)
        let trajectories = try (0...48).map { index in
            try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "window-capacity-\(index)", observations: observations
            )
        }
        let complete = try ProfessionalQualityCalibrationCorpus(
            trajectories: Array(trajectories.prefix(48))
        )
        #expect(complete.isComplete)
        #expect(complete.sourceTrajectoryCount == 48)
        #expect(complete.sourceObservationCount == 672)
        #expect(complete.schemaVersion == 3)
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationCorpus(trajectories: trajectories)
        }
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationCorpus(
                trajectories: [trajectories[0], trajectories[0]]
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

    @Test("Unsupported conditional trajectories stay explicit and fail closed")
    func unsupportedConditionalTrajectorySupport() throws {
        let padMetrics: [ProfessionalQualityMetric] = [
            .padRhythmicFilterDifferenceToPadDBMean,
            .padRhythmicAmplitudeGateDifferenceToPadDBMean,
            .padRhythmicSpatialDifferenceToSendDBMean,
        ]
        let trajectories = try (0..<24).map { index in
            let observations = try representativeObservations().map { observation in
                let active = observation.checkpoint == .majorBreak
                var projected = try observation.replacing(
                    .padRhythmicModulationActiveBarRatio,
                    with: active ? 0.5 : 0
                )
                for metric in padMetrics {
                    projected = try projected.replacing(
                        metric,
                        with: active ? -12 + Double(index) * 0.01 : 20
                    )
                }
                return projected
            }
            return try ProfessionalQualityCalibrationTrajectory(
                sourceBankFingerprint: "unsupported-pad-trajectory-\(index)",
                observations: observations
            )
        }
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: ProfessionalQualityCalibrationCorpus(trajectories: trajectories)
        )
        #expect(profile.isComplete)
        let unsupported = profile.trajectories.filter {
            padMetrics.contains($0.metric)
        }
        #expect(unsupported.count == padMetrics.count *
            ProfessionalQualityTrajectory.allCases.count)
        #expect(unsupported.allSatisfy {
            $0.sourceComparisonCount == 0 &&
                $0.lowerDelta == 0 && $0.upperDelta == 0
        })
        #expect(throws: ProfessionalQualityCalibrationError.invalidBounds) {
            try ProfessionalQualityTrajectoryBounds(
                trajectory: .establishmentToMajorBreak,
                metric: .integratedLoudnessLUFS,
                lowerDelta: 0,
                upperDelta: 0,
                sourceComparisonCount: 0
            )
        }
        #expect(throws: ProfessionalQualityCalibrationError.invalidBounds) {
            try ProfessionalQualityTrajectoryBounds(
                trajectory: .establishmentToMajorBreak,
                metric: .padRhythmicAmplitudeGateDifferenceToPadDBMean,
                lowerDelta: -1,
                upperDelta: 1,
                sourceComparisonCount: 0
            )
        }
        #expect(profile.trajectories.filter {
            !padMetrics.contains($0.metric)
        }.allSatisfy { $0.sourceComparisonCount > 0 })
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            for metric in padMetrics {
                #expect(try #require(profile[checkpoint]?[metric]).upper < 0)
            }
        }
        let encoded = try profile.deterministicJSON()
        #expect(try ProfessionalQualityCalibrationProfile
            .decodeDeterministicJSON(encoded) == profile)
        let stale = try replacingJSONIdentity(encoded, replacements: [
            "\"schemaVersion\":22": "\"schemaVersion\":21",
        ])
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityCalibrationProfile.decodeDeterministicJSON(stale)
        }
        let observations = trajectories[0].observations
        #expect(ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: observations, against: profile
        ).accepted)
        let newlyApplicable = try observations.map { observation in
            if observation.checkpoint == .establishment {
                return try observation.replacing(
                    .padRhythmicModulationActiveBarRatio, with: 0.5
                )
            }
            if observation.checkpoint == .release {
                return try observation.replacing(.maskingMaximumOverlap, with: 1)
            }
            return observation
        }
        let unavailable = ProfessionalQualityRelationshipEvaluator.evaluate(
            observations: newlyApplicable, against: profile
        )
        #expect(unavailable.availability == .unavailableCalibrationSupport)
        #expect(unavailable.support == .insufficient)
        #expect(!unavailable.accepted)
        #expect(unavailable.failures.contains {
            $0.metric == .maskingMaximumOverlap
        })
        let active = try #require(observations.first {
            $0.checkpoint == .majorBreak
        })
        let disconnected = try active.replacing(
            .padRhythmicAmplitudeGateDifferenceToPadDBMean, with: 0
        )
        #expect(ProfessionalQualityProfileEvaluator.evaluate(
            disconnected, against: profile
        ).failedMetrics.contains(.padRhythmicAmplitudeGateDifferenceToPadDBMean))
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
            // A calibration fixture must contain paired applicable pad
            // evidence, rather than a zero default activated by rateOffset.
            .padRhythmicModulationActiveBarRatio: 0.5,
            .padRhythmicFilterDifferenceToPadDBMean: -24,
            .padRhythmicAmplitudeGateDifferenceToPadDBMean: -18,
            .padRhythmicSpatialDifferenceToSendDBMean: -12,
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
