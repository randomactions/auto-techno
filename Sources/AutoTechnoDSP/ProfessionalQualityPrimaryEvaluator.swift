import AutoTechnoCore

package enum ProfessionalQualityCandidateAssessmentAvailability: String,
        Codable, Equatable, Sendable {
    case available
    case noApplicableCheckpoint = "no-applicable-checkpoint"
    case unsupportedSampleRate = "unsupported-sample-rate"
    case invalidEvidence = "invalid-evidence"
}

/// Replayable per-candidate result under one exact calibrated profile. A
/// A candidate can contribute multiple offline structural observations, while
/// runtime terminal judgment selects the single most-specific whole-phrase
/// population. There is deliberately no aggregate score or distance-to-center
/// optimization.
package struct ProfessionalQualityCandidateAssessment: Codable, Equatable,
        Sendable {
    package let availability: ProfessionalQualityCandidateAssessmentAvailability
    package let sampleRate: Double?
    package let checkpoints: [CanonicalJourneyCheckpoint]
    package let verdicts: [ProfessionalQualityReportVerdict]

    package var accepted: Bool {
        availability == .available && !verdicts.isEmpty &&
            verdicts.allSatisfy(\.accepted)
    }

    fileprivate static func unavailable(
        _ availability: ProfessionalQualityCandidateAssessmentAvailability,
        sampleRate: Double? = nil,
        checkpoints: [CanonicalJourneyCheckpoint] = []
    ) -> Self {
        Self(
            availability: availability,
            sampleRate: sampleRate,
            checkpoints: checkpoints,
            verdicts: []
        )
    }
}

package struct ProfessionalQualityRecoveryFailure: Equatable, Sendable {
    package let metric: ProfessionalQualityMetric
    package let value: Double
    package let lowerBound: Double
    package let upperBound: Double

    package init(
        metric: ProfessionalQualityMetric,
        value: Double,
        lowerBound: Double,
        upperBound: Double
    ) {
        self.metric = metric
        self.value = value
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

package enum ProfessionalQualityRecoveryIntentReducer {
    package static func reduce(
        _ failures: [ProfessionalQualityRecoveryFailure]
    ) -> AutonomousQualityRecoveryIntent {
        var spectral: AutonomousQualityRecoveryDirection = .hold
        var kickCrestReduction: AutonomousQualityRecoveryDirection = .hold
        for failure in failures where failure.value.isFinite &&
                failure.lowerBound.isFinite && failure.upperBound.isFinite &&
                failure.lowerBound <= failure.upperBound {
            let direction: AutonomousQualityRecoveryDirection
            if failure.value < failure.lowerBound {
                direction = .increase
            } else if failure.value > failure.upperBound {
                direction = .decrease
            } else {
                direction = .hold
            }
            switch failure.metric {
            case .spectralCentroidSpreadHz,
                    .barCentroidSpanHz,
                    .movementScore,
                    .positiveSpectralFluxMean,
                    .positiveSpectralFluxPeak:
                spectral = spectral.merging(direction)
            case .kickSourceCrestReductionDBMean:
                kickCrestReduction = kickCrestReduction.merging(direction)
            default:
                break
            }
        }
        return AutonomousQualityRecoveryIntent(
            spectralMovement: spectral,
            kickCrestReduction: kickCrestReduction
        )
    }
}

/// Exact-engine calibrated evaluator for the bounded primary preparation
/// transaction. Construction requires a complete adversarially challenged
/// profile and qualified holdout produced by the current canonical engine.
package struct ProfessionalQualityPrimaryEvaluator:
        AutonomousCandidateEvaluating {
    package static let policyFamilyVersion =
        "autotechno-quality.primary-calibrated.v22"
    package static let evaluatorVersionIdentifier =
        "autotechno-candidate-evaluator.primary-calibrated.v22"
    package static let requiredProfileVersion =
        "autotechno-professional-quality-profile.v22"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    package let holdoutQualification: ProfessionalQualityHoldoutQualification
    package let policyVersion: String
    package let evaluatorVersion = Self.evaluatorVersionIdentifier

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        adversarialSuite: ProfessionalQualityAdversarialSuiteReport,
        holdoutQualification: ProfessionalQualityHoldoutQualification
    ) throws {
        guard profile.isComplete,
              profile.usesDiverseCalibration,
              profile.profileVersion == Self.requiredProfileVersion,
              adversarialSuite.passed,
              !profile.fingerprint.isEmpty,
              adversarialSuite.profileFingerprint == profile.fingerprint,
              !adversarialSuite.fingerprint.isEmpty,
              adversarialSuite.schemaVersion ==
                ProfessionalQualityAdversarialSuiteReport.schemaVersion,
              holdoutQualification.qualified,
              holdoutQualification.engineVersion == profile.engineVersion,
              holdoutQualification.profileFingerprint == profile.fingerprint,
              holdoutQualification.adversarialSuiteFingerprint ==
                adversarialSuite.fingerprint,
              holdoutQualification.calibrationCorpusFingerprint ==
                profile.sourceBankFingerprint,
              profile.engineVersion == QualityQualificationContract.engineVersion,
              profile.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        self.profile = profile
        self.adversarialSuite = adversarialSuite
        self.holdoutQualification = holdoutQualification
        policyVersion = [
            Self.policyFamilyVersion,
            "profile-\(profile.fingerprint)",
            "adversarial-\(adversarialSuite.fingerprint)",
            "holdout-\(holdoutQualification.fingerprint)",
        ].joined(separator: ".")
    }

    package func assessment(
        of candidate: AutonomousCandidateEvaluationVector
    ) -> ProfessionalQualityCandidateAssessment {
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ) else {
            return .unavailable(.invalidEvidence)
        }
        let primaryCheckpoint = CanonicalJourneyCheckpoint.primaryQualification(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        )
        // Ordinary lock phrases use the continuation envelope. It is derived
        // from the same engine's later steady-state journey observations and
        // gives every primary phrase a calibrated, non-aggregate judgment.
        let checkpoints = [primaryCheckpoint ?? .longContinuation]
        let sampleRate = candidate.routeContinuation.sampleRate
        guard !checkpoints.isEmpty else {
            return .unavailable(
                .noApplicableCheckpoint,
                sampleRate: sampleRate
            )
        }
        guard profile.sampleRates.contains(sampleRate) else {
            return .unavailable(
                .unsupportedSampleRate,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        do {
            let observations = try checkpoints.map {
                try ProfessionalQualityObservation(
                    candidate: candidate,
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: $0
                )
            }
            return assessment(of: observations)
        } catch {
            return .unavailable(
                .invalidEvidence,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
    }

    /// Reduced-observation seam used by deterministic policy and adversarial
    /// tests. All observations must describe one candidate at one route rate.
    package func assessment(
        of observations: [ProfessionalQualityObservation]
    ) -> ProfessionalQualityCandidateAssessment {
        let checkpoints = CanonicalJourneyCheckpoint.allCases.filter {
            checkpoint in observations.contains { $0.checkpoint == checkpoint }
        }
        guard let sampleRate = observations.first?.sampleRate else {
            return .unavailable(.noApplicableCheckpoint)
        }
        guard profile.sampleRates.contains(sampleRate) else {
            return .unavailable(
                .unsupportedSampleRate,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        let identities = Set(observations.map(\.checkpoint))
        guard !checkpoints.isEmpty,
              identities.count == observations.count,
              checkpoints.count == observations.count,
              observations.allSatisfy({
                  $0.isComplete &&
                      $0.engineVersion ==
                        QualityQualificationContract.engineVersion &&
                      $0.evidenceVersion == profile.evidenceVersion &&
                      $0.sampleRate == sampleRate
              }) else {
            return .unavailable(
                .invalidEvidence,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        let verdicts = checkpoints.compactMap { checkpoint in
            observations.first { $0.checkpoint == checkpoint }.map {
                observation in
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                )
                return ProfessionalQualityReportVerdict(
                    checkpoint: checkpoint,
                    sampleRate: sampleRate,
                    accepted: verdict.accepted,
                    reasons: verdict.reasons,
                    failedMetrics: verdict.failedMetrics
                )
            }
        }
        guard verdicts.count == observations.count else {
            return .unavailable(
                .invalidEvidence,
                sampleRate: sampleRate,
                checkpoints: checkpoints
            )
        }
        return ProfessionalQualityCandidateAssessment(
            availability: .available,
            sampleRate: sampleRate,
            checkpoints: checkpoints,
            verdicts: verdicts
        )
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector
    ) -> Bool {
        candidate.hardGates.symbolicValid &&
            candidate.hardGates.graphValid &&
            candidate.hardGates.audioSafetyValid &&
            candidate.hardGates.fullMixFinite &&
            candidate.hardGates.blocksPresent &&
            candidate.hardGates.blockChannelsAligned &&
            candidate.hardGates.allSamplesFinite &&
            candidate.hardGates.completeInputs &&
            !candidate.postGraphUpperTimbreEvidence.finite
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        let selectedAttemptMatches = transaction.selectedAttemptIndex.flatMap {
            transaction.attempts.indices.contains($0)
                ? transaction.attempts[$0].vector == selected : nil
        } == true
        let transactionFailures = [
            transaction.isComplete ? nil : "transaction-incomplete",
            transaction.engineVersion == profile.engineVersion
                ? nil : "engine-version",
            transaction.policyVersion == policyVersion
                ? nil : "policy-version",
            transaction.evaluatorVersion == evaluatorVersion
                ? nil : "evaluator-version",
            transaction.planFingerprint == selected.planFingerprint
                ? nil : "plan-fingerprint",
            selectedAttemptMatches ? nil : "selected-attempt",
            transaction.liveProposalFingerprint ==
                selected.liveProposalFingerprint
                ? nil : "live-proposal-fingerprint",
        ].compactMap { $0 }
        guard transactionFailures.isEmpty else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                reasonCodes: [.guardrailRegressionV1],
                diagnosticDetails: transactionFailures
            )
        }
        guard selected.hardGatesPassed else {
            return Self.hardGateRejectionVerdict(for: selected)
        }
        let result = assessment(of: selected)
        guard result.availability == .available else {
            var diagnosticDetails = [
                "assessment=\(result.availability.rawValue)",
                "checkpoints=\(result.checkpoints.map(\.rawValue).joined(separator: ","))",
            ]
            if let sampleRate = result.sampleRate {
                diagnosticDetails.append("sample-rate=\(sampleRate)")
            }
            if result.availability == .invalidEvidence {
                diagnosticDetails.append(contentsOf:
                    invalidEvidenceDiagnostics(
                        candidate: selected,
                        checkpoints: result.checkpoints
                    )
                )
            }
            return AutonomousCandidatePolicyVerdict(
                outcome: .qualificationUnavailable,
                reasonCodes: [.evaluatorUnavailableV1],
                diagnosticDetails: diagnosticDetails
            )
        }
        guard result.accepted else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                reasonCodes: [.guardrailRegressionV1],
                diagnosticDetails: rejectionDiagnostics(
                    candidate: selected,
                    assessment: result
                ),
                recoveryIntent: recoveryIntent(
                    candidate: selected,
                    assessment: result
                )
            )
        }
        return AutonomousCandidatePolicyVerdict(
            outcome: transaction.correctionCount == 0 ? .qualified : .adjusted,
            reasonCodes: transaction.correctionCount == 0
                ? [.candidateQualifiedV1] : [.candidateAdjustedV1]
        )
    }

    /// Deterministic reason reduction for a candidate that already failed the
    /// primary hard-gate boundary. Keeping this independent of installed
    /// artifacts preserves fail-closed runtime activation while allowing the
    /// reason contract itself to be verified when an engine revision has not
    /// yet been recalibrated.
    package static func hardGateRejectionVerdict(
        for selected: AutonomousCandidateEvaluationVector
    ) -> AutonomousCandidatePolicyVerdict {
        let hardGateFailures = [
            selected.isComplete ? nil : "candidate-incomplete",
            selected.isFinite ? nil : "candidate-nonfinite",
            selected.hardGates.passed ? nil : "candidate-hard-gates",
            selected.symbolic.interestValid ? nil : "symbolic-interest",
            selected.graph.validationValid ? nil : "graph-validation",
            selected.fullMix.signalSafetyValid ? nil : "signal-safety",
            selected.liveProposalOutcome != .unavailable
                ? nil : "live-proposal-unavailable",
            selected.postGraphUpperTimbreEvidence.finite
                ? nil : "upper-timbre-nonfinite",
        ].compactMap { $0 }
        var reasonCodes: [QualityReasonCode] = [.hardGateFailedV1]
        if selected.symbolicInterestIsOnlyHardGateFailure {
            reasonCodes.append(.symbolicInterestFailedV1)
        }
        return AutonomousCandidatePolicyVerdict(
            outcome: .rejected,
            reasonCodes: reasonCodes,
            diagnosticDetails: hardGateFailures,
            recoveryIntent: selected.symbolicInterestIsOnlyHardGateFailure
                ? AutonomousQualityRecoveryIntent(symbolicDensity: .decrease)
                : .neutral
        )
    }

    /// Converts exact failed metric direction into the fixed Core-owned
    /// recovery coordinates. Thresholds and metric identities remain DSP
    /// implementation details and never cross the module boundary.
    private func recoveryIntent(
        candidate: AutonomousCandidateEvaluationVector,
        assessment: ProfessionalQualityCandidateAssessment
    ) -> AutonomousQualityRecoveryIntent {
        var failures: [ProfessionalQualityRecoveryFailure] = []
        for verdict in assessment.verdicts {
            guard let observation = try? ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: verdict.checkpoint
            ) else { continue }
            for metric in verdict.failedMetrics {
                guard let value = observation[metric],
                      let bounds = profile.effectiveBounds(
                        for: metric,
                        at: verdict.checkpoint,
                        observedValue: value
                      ) else { continue }
                let lower = metric.acceptsSaferValuesBelowCalibration
                    ? metric.semanticMinimum : bounds.lower
                let upper = metric.acceptsSaferValuesAboveCalibration
                    ? metric.semanticMaximum : bounds.upper
                failures.append(ProfessionalQualityRecoveryFailure(
                    metric: metric,
                    value: value,
                    lowerBound: lower,
                    upperBound: upper
                ))
            }
        }
        return ProfessionalQualityRecoveryIntentReducer.reduce(failures)
    }

    private func invalidEvidenceDiagnostics(
        candidate: AutonomousCandidateEvaluationVector,
        checkpoints: [CanonicalJourneyCheckpoint]
    ) -> [String] {
        guard AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ) != nil else {
            return ["observation=phrase-kind"]
        }
        var details: [String] = []
        for checkpoint in checkpoints {
            do {
                _ = try ProfessionalQualityObservation(
                    candidate: candidate,
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: checkpoint
                )
            } catch let error as ProfessionalQualityCalibrationError {
                details.append(contentsOf: Self.diagnosticDetails(
                    for: error,
                    checkpoint: checkpoint
                ))
            } catch {
                details.append(
                    "\(checkpoint.rawValue):observation=unknown-error"
                )
            }
        }
        return Array(details.prefix(20))
    }

    private func rejectionDiagnostics(
        candidate: AutonomousCandidateEvaluationVector,
        assessment: ProfessionalQualityCandidateAssessment
    ) -> [String] {
        var details: [String] = []
        for verdict in assessment.verdicts {
            let checkpointName = verdict.checkpoint.rawValue
            details.append(contentsOf: verdict.reasons.map {
                "\(checkpointName):reason=\($0.rawValue)"
            })
            let observation = try? ProfessionalQualityObservation(
                candidate: candidate,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: verdict.checkpoint
            )
            for metric in verdict.failedMetrics {
                guard let value = observation?[metric],
                      let bounds = profile.effectiveBounds(
                        for: metric,
                        at: verdict.checkpoint,
                        observedValue: value
                      ) else {
                    details.append(
                        "\(checkpointName):\(metric.rawValue)=unavailable"
                    )
                    continue
                }
                let lower = metric.acceptsSaferValuesBelowCalibration
                    ? metric.semanticMinimum : bounds.lower
                let upper = metric.acceptsSaferValuesAboveCalibration
                    ? metric.semanticMaximum : bounds.upper
                details.append(
                    "\(checkpointName):\(metric.rawValue)=\(value)" +
                    " outside \(lower)...\(upper)"
                )
            }
        }
        return Array(details.prefix(24))
    }

    private static func diagnosticDetails(
        for error: ProfessionalQualityCalibrationError,
        checkpoint: CanonicalJourneyCheckpoint
    ) -> [String] {
        let prefix = "\(checkpoint.rawValue):"
        switch error {
        case .invalidIdentity:
            return [prefix + "observation=invalid-identity"]
        case .incompleteRepresentativeRates:
            return [prefix + "observation=representative-rates"]
        case .incompleteCheckpointCoverage:
            return [prefix + "observation=checkpoint-coverage"]
        case .duplicateMetric:
            return [prefix + "observation=duplicate-metric"]
        case .invalidMetricSet:
            return [prefix + "observation=metric-set"]
        case let .nonFiniteMetric(metric):
            return [prefix + "metric=\(metric.rawValue)-nonfinite"]
        case .incompleteKickSyntaxEvidence:
            return [prefix + "observation=kick-syntax"]
        case let .incompleteStemBarCoverage(_, expected, actual):
            return [
                prefix + "observation=stem-bar-coverage",
                prefix + "expected-stem-bars=\(expected.count)",
                prefix + "actual-stem-bars=\(actual.count)",
            ]
        case let .incompleteStemRoleEvidence(_, failures):
            return [prefix + "observation=stem-role"] + failures.flatMap {
                failure in failure.failures.map {
                    prefix + "stem-role=\(failure.role):\($0.rawValue)"
                }
            }
        case let .incompleteCandidateEvidence(_, failures):
            return [prefix + "observation=candidate"] + failures.map {
                prefix + "candidate=\($0.rawValue)"
            }
        case .invalidBounds:
            return [prefix + "observation=bounds"]
        case .profileMismatch:
            return [prefix + "observation=profile"]
        }
    }
}
