import AutoTechnoCore
import Foundation

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
        Sendable, AutonomousEvidenceCategorizedReport {
    package static let evidenceCategory: AutonomousEvidenceCategory =
        .calibratedQuality
    package let availability: ProfessionalQualityCandidateAssessmentAvailability
    package let sampleRate: Double?
    package let checkpoints: [CanonicalJourneyCheckpoint]
    package let verdicts: [ProfessionalQualityReportVerdict]
    package let calibrationTrajectoryCount: Int?
    package let support: ProfessionalQualityCalibrationSupport
    package let confidence: ProfessionalQualityConfidenceStatus

    package var accepted: Bool {
        availability == .available && support == .sufficient &&
            confidence == .notEstimated && !verdicts.isEmpty &&
            verdicts.allSatisfy(\.accepted)
    }

    fileprivate static func unavailable(
        _ availability: ProfessionalQualityCandidateAssessmentAvailability,
        sampleRate: Double? = nil,
        checkpoints: [CanonicalJourneyCheckpoint] = [],
        calibrationTrajectoryCount: Int?
    ) -> Self {
        Self(
            availability: availability,
            sampleRate: sampleRate,
            checkpoints: checkpoints,
            verdicts: [],
            calibrationTrajectoryCount: calibrationTrajectoryCount,
            support: (calibrationTrajectoryCount ?? 0) >=
                    ProfessionalQualityCalibrationProfile
                        .minimumCalibrationTrajectoryCount
                ? .sufficient : .insufficient,
            confidence: .unavailable
        )
    }
}

/// Descriptive per-bar kick/foundation measurements retained alongside the
/// existing calibrated mean. This report is diagnostic only: it does not
/// change the primary profile verdict or claim that a spread is undesirable.
package struct ProfessionalQualityKickFoundationLocalEvidence: Codable,
        Equatable, Sendable, AutonomousEvidenceCategorizedReport {
    package static let evidenceCategory: AutonomousEvidenceCategory =
        .descriptive
    package static let schemaVersion = 1
    package static let evidenceVersion =
        "autotechno-kick-foundation-local-evidence.v1"

    package enum Availability: String, Codable, Sendable {
        case available
        case noActivePairedBars = "no-active-paired-bars"
    }

    package struct BarMeasurement: Codable, Equatable, Sendable {
        package let bar: Int
        package let kickOverFoundationDB: Double
    }

    package struct SourceBar: Equatable, Sendable {
        package let bar: Int
        package let kickActiveRMS: Double
        package let foundationActiveRMS: Double

        package init(
            bar: Int,
            kickActiveRMS: Double,
            foundationActiveRMS: Double
        ) {
            self.bar = bar
            self.kickActiveRMS = kickActiveRMS
            self.foundationActiveRMS = foundationActiveRMS
        }
    }

    package let schemaVersion: Int
    package let evidenceVersion: String
    package let engineVersion: String
    package let policyVersion: String
    package let sourceReportFingerprint: String
    package let planFingerprint: String
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let sourceBarCount: Int
    package let pairedBarCount: Int
    package let availability: Availability
    package let barMeasurements: [BarMeasurement]
    package let meanDB: Double?
    package let minimumDB: Double?
    package let maximumDB: Double?
    package let spreadDB: Double?

    package init(
        engineVersion: String,
        policyVersion: String,
        sourceReportFingerprint: String,
        planFingerprint: String,
        checkpoint: CanonicalJourneyCheckpoint,
        sampleRate: Double,
        sourceBarCount: Int,
        sourceBars: [SourceBar]
    ) throws {
        let barOrderIsContiguous = zip(sourceBars, sourceBars.dropFirst())
            .allSatisfy { previous, next in
                previous.bar < Int.max && next.bar == previous.bar + 1
            }
        guard !engineVersion.isEmpty,
              !policyVersion.isEmpty,
              !sourceReportFingerprint.isEmpty,
              !planFingerprint.isEmpty,
              sampleRate.isFinite,
              sampleRate >= QualityQualificationContract
                .minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract
                .maximumSupportedSampleRate,
              sourceBarCount > 0,
              sourceBarCount <= AutonomousCandidateEvaluationVector
                .maximumBarCount,
              sourceBars.count == sourceBarCount,
              sourceBars == sourceBars.sorted(by: { $0.bar < $1.bar }),
              Set(sourceBars.map(\.bar)).count == sourceBars.count,
              barOrderIsContiguous,
              sourceBars.allSatisfy({
                  $0.bar >= 0 && $0.bar < Int.max &&
                      $0.kickActiveRMS.isFinite &&
                      $0.kickActiveRMS >= 0 &&
                      $0.foundationActiveRMS.isFinite &&
                      $0.foundationActiveRMS >= 0
              }) else {
            throw ProfessionalQualityCalibrationError
                .invalidLocalFeatureEvidence
        }

        let paired = sourceBars.compactMap { source -> BarMeasurement? in
            guard source.kickActiveRMS > 0,
                  source.foundationActiveRMS > 0 else { return nil }
            let value = Self.decibels(
                source.kickActiveRMS,
                source.foundationActiveRMS
            )
            return BarMeasurement(bar: source.bar,
                                  kickOverFoundationDB: value)
        }
        guard paired.allSatisfy({ $0.kickOverFoundationDB.isFinite }) else {
            throw ProfessionalQualityCalibrationError
                .invalidLocalFeatureEvidence
        }

        schemaVersion = Self.schemaVersion
        evidenceVersion = Self.evidenceVersion
        self.engineVersion = engineVersion
        self.policyVersion = policyVersion
        self.sourceReportFingerprint = sourceReportFingerprint
        self.planFingerprint = planFingerprint
        self.checkpoint = checkpoint
        self.sampleRate = sampleRate
        self.sourceBarCount = sourceBarCount
        pairedBarCount = paired.count
        availability = paired.isEmpty ? .noActivePairedBars : .available
        barMeasurements = paired
        if let minimum = paired.map(\.kickOverFoundationDB).min(),
           let maximum = paired.map(\.kickOverFoundationDB).max() {
            meanDB = paired.map(\.kickOverFoundationDB).reduce(0, +) /
                Double(paired.count)
            minimumDB = minimum
            maximumDB = maximum
            spreadDB = maximum - minimum
        } else {
            meanDB = nil
            minimumDB = nil
            maximumDB = nil
            spreadDB = nil
        }
    }

    package init(
        report: CanonicalJourneyQualificationReport
    ) throws {
        guard report.evidenceScope ==
                CanonicalJourneyQualificationReport.currentEvidenceScope else {
            throw ProfessionalQualityCalibrationError
                .invalidLocalFeatureEvidence
        }
        try self.init(
            candidate: report.selectedCandidateEvidence,
            engineVersion: report.engineVersion,
            policyVersion: report.policyVersion,
            sourceReportFingerprint: report.evidenceFingerprint,
            checkpoint: report.checkpoint
        )
    }

    package init(
        candidate: AutonomousCandidateEvaluationVector,
        engineVersion: String,
        policyVersion: String,
        sourceReportFingerprint: String,
        checkpoint: CanonicalJourneyCheckpoint
    ) throws {
        guard candidate.isComplete,
              candidate.isFinite,
              candidate.stems.count == candidate.sourceStemBarCount,
              candidate.stems.count == candidate.fullMix.bars.count,
              candidate.stems.map(\.bar) ==
                candidate.fullMix.bars.map(\.bar) else {
            throw ProfessionalQualityCalibrationError
                .invalidLocalFeatureEvidence
        }
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ) else {
            throw ProfessionalQualityCalibrationError
                .invalidLocalFeatureEvidence
        }
        let primaryCheckpoint = CanonicalJourneyCheckpoint
            .primaryQualification(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: phraseKind,
                chapterChanged: candidate.symbolic.chapterChanged
            ) ?? .longContinuation
        guard CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).contains(checkpoint) || checkpoint == primaryCheckpoint else {
            throw ProfessionalQualityCalibrationError
                .invalidLocalFeatureEvidence
        }
        let sourceBars = try candidate.stems.map { stem -> SourceBar in
            guard stem.isComplete,
                  let kick = stem.roles.first(where: {
                      $0.role == MixRole.kick.rawValue
                  }),
                  let foundation = stem.roles.first(where: {
                      $0.role == MixRole.foundation.rawValue
                  }) else {
                throw ProfessionalQualityCalibrationError
                    .invalidLocalFeatureEvidence
            }
            return SourceBar(
                bar: stem.bar,
                kickActiveRMS: kick.activeRMS,
                foundationActiveRMS: foundation.activeRMS
            )
        }
        try self.init(
            engineVersion: engineVersion,
            policyVersion: policyVersion,
            sourceReportFingerprint: sourceReportFingerprint,
            planFingerprint: candidate.planFingerprint,
            checkpoint: checkpoint,
            sampleRate: candidate.routeContinuation.sampleRate,
            sourceBarCount: candidate.sourceStemBarCount,
            sourceBars: sourceBars
        )
    }

    private static func decibels(
        _ numerator: Double,
        _ denominator: Double
    ) -> Double {
        min(120, max(-120,
            20 * (log10(numerator) - log10(denominator))
        ))
    }
}

/// Descriptive localization of the existing masking observations by rendered
/// bar, role pair, and canonical frequency band. It preserves the analyzer's
/// fixed-window evidence without changing calibrated candidate-wide metrics.
package struct ProfessionalQualityMaskingLocalEvidence: Codable,
        Equatable, Sendable, AutonomousEvidenceCategorizedReport {
    package static let evidenceCategory: AutonomousEvidenceCategory =
        .descriptive
    package static let schemaVersion = 1
    package static let evidenceVersion =
        "autotechno-masking-local-evidence.v1"

    package struct Observation: Codable, Equatable, Sendable {
        package let bar: Int
        package let bandName: String
        package let lowerHz: Double
        package let upperHz: Double
        package let firstRole: String
        package let secondRole: String
        package let analyzedWindowCount: Int
        package let activePairWindowCount: Int
        package let overlapWindowCount: Int
        package let longestOverlapRun: Int
        package let maximumOverlap: Double

        package init(bar: Int,
                     bandName: String,
                     lowerHz: Double,
                     upperHz: Double,
                     firstRole: String,
                     secondRole: String,
                     analyzedWindowCount: Int,
                     activePairWindowCount: Int,
                     overlapWindowCount: Int,
                     longestOverlapRun: Int,
                     maximumOverlap: Double) {
            self.bar = bar
            self.bandName = bandName
            self.lowerHz = lowerHz
            self.upperHz = upperHz
            self.firstRole = firstRole
            self.secondRole = secondRole
            self.analyzedWindowCount = analyzedWindowCount
            self.activePairWindowCount = activePairWindowCount
            self.overlapWindowCount = overlapWindowCount
            self.longestOverlapRun = longestOverlapRun
            self.maximumOverlap = maximumOverlap
        }

        fileprivate init(bar: Int,
                         source: AutonomousMaskingObservationEvidence) {
            self.init(
                bar: bar,
                bandName: source.bandName,
                lowerHz: source.lowerHz,
                upperHz: source.upperHz,
                firstRole: source.firstRole,
                secondRole: source.secondRole,
                analyzedWindowCount: source.analyzedWindowCount,
                activePairWindowCount: source.activePairWindowCount,
                overlapWindowCount: source.overlapWindowCount,
                longestOverlapRun: source.longestOverlapRun,
                maximumOverlap: source.maximumOverlap
            )
        }
    }

    package let schemaVersion: Int
    package let evidenceVersion: String
    package let engineVersion: String
    package let policyVersion: String
    package let sourceReportFingerprint: String
    package let planFingerprint: String
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let sourceBarCount: Int
    package let observationCount: Int
    package let observations: [Observation]

    package init(engineVersion: String,
                 policyVersion: String,
                 sourceReportFingerprint: String,
                 planFingerprint: String,
                 checkpoint: CanonicalJourneyCheckpoint,
                 sampleRate: Double,
                 sourceBars: [AutonomousMaskingBarEvidence]) throws {
        let canonicalObservationKeys = SpectrumMaskingAnalyzer.rolePairs
            .flatMap { pair in
                SpectrumMaskingAnalyzer.bands.map { band in
                    "\(pair.0.rawValue)|\(pair.1.rawValue)|\(band.name)"
                }
            }
        let barsAreOrderedAndContiguous = zip(sourceBars, sourceBars.dropFirst())
            .allSatisfy { previous, next in
                previous.bar < Int.max && next.bar == previous.bar + 1
            }
        guard !engineVersion.isEmpty,
              !policyVersion.isEmpty,
              !sourceReportFingerprint.isEmpty,
              !planFingerprint.isEmpty,
              sampleRate.isFinite,
              sampleRate >= QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract.maximumSupportedSampleRate,
              !sourceBars.isEmpty,
              sourceBars.count <= AutonomousCandidateEvaluationVector.maximumBarCount,
              sourceBars == sourceBars.sorted(by: { $0.bar < $1.bar }),
              Set(sourceBars.map(\.bar)).count == sourceBars.count,
              barsAreOrderedAndContiguous,
              sourceBars.allSatisfy({
                  $0.bar >= 0 && $0.bar < Int.max && $0.isComplete && $0.isFinite &&
                      $0.observations.map({
                          "\($0.firstRole)|\($0.secondRole)|\($0.bandName)"
                      }) == canonicalObservationKeys
              }) else {
            throw ProfessionalQualityCalibrationError.invalidLocalFeatureEvidence
        }

        let observations = sourceBars.flatMap { bar in
            bar.observations.map {
                Observation(bar: bar.bar, source: $0)
            }
        }
        guard observations.count == sourceBars.count *
                AutonomousCandidateEvaluationVector.maximumMaskingObservationsPerBar,
              observations.allSatisfy({
                  $0.lowerHz.isFinite && $0.upperHz.isFinite &&
                      $0.maximumOverlap.isFinite
              }) else {
            throw ProfessionalQualityCalibrationError.invalidLocalFeatureEvidence
        }

        schemaVersion = Self.schemaVersion
        evidenceVersion = Self.evidenceVersion
        self.engineVersion = engineVersion
        self.policyVersion = policyVersion
        self.sourceReportFingerprint = sourceReportFingerprint
        self.planFingerprint = planFingerprint
        self.checkpoint = checkpoint
        self.sampleRate = sampleRate
        sourceBarCount = sourceBars.count
        observationCount = observations.count
        self.observations = observations
    }

    package init(report: CanonicalJourneyQualificationReport) throws {
        guard report.evidenceScope ==
                CanonicalJourneyQualificationReport.currentEvidenceScope else {
            throw ProfessionalQualityCalibrationError.invalidLocalFeatureEvidence
        }
        try self.init(
            candidate: report.selectedCandidateEvidence,
            engineVersion: report.engineVersion,
            policyVersion: report.policyVersion,
            sourceReportFingerprint: report.evidenceFingerprint,
            checkpoint: report.checkpoint
        )
    }

    package init(candidate: AutonomousCandidateEvaluationVector,
                 engineVersion: String,
                 policyVersion: String,
                 sourceReportFingerprint: String,
                 checkpoint: CanonicalJourneyCheckpoint) throws {
        guard candidate.isComplete,
              candidate.isFinite,
              candidate.masking.count == candidate.sourceMaskingBarCount,
              candidate.masking.count == candidate.fullMix.bars.count,
              candidate.masking.map(\.bar) == candidate.fullMix.bars.map(\.bar) else {
            throw ProfessionalQualityCalibrationError.invalidLocalFeatureEvidence
        }
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: candidate.symbolic.phraseKind
        ) else {
            throw ProfessionalQualityCalibrationError.invalidLocalFeatureEvidence
        }
        let primaryCheckpoint = CanonicalJourneyCheckpoint.primaryQualification(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ) ?? .longContinuation
        guard CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged
        ).contains(checkpoint) || checkpoint == primaryCheckpoint else {
            throw ProfessionalQualityCalibrationError.invalidLocalFeatureEvidence
        }
        try self.init(
            engineVersion: engineVersion,
            policyVersion: policyVersion,
            sourceReportFingerprint: sourceReportFingerprint,
            planFingerprint: candidate.planFingerprint,
            checkpoint: checkpoint,
            sampleRate: candidate.routeContinuation.sampleRate,
            sourceBars: candidate.masking
        )
    }
}

package struct ProfessionalQualityRecoveryFailure: Equatable, Sendable,
        AutonomousEvidenceCategorizedReport {
    package static let evidenceCategory: AutonomousEvidenceCategory =
        .calibratedQuality
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
        "autotechno-quality.primary-calibrated.v29"
    package static let evaluatorVersionIdentifier =
        "autotechno-candidate-evaluator.primary-calibrated.v29"
    package static let requiredProfileVersion =
        "autotechno-professional-quality-profile.v29"

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
            return .unavailable(
                .invalidEvidence,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
            )
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
                sampleRate: sampleRate,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
            )
        }
        guard profile.sampleRates.contains(sampleRate) else {
            return .unavailable(
                .unsupportedSampleRate,
                sampleRate: sampleRate,
                checkpoints: checkpoints,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
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
                checkpoints: checkpoints,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
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
            return .unavailable(
                .noApplicableCheckpoint,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
            )
        }
        guard profile.sampleRates.contains(sampleRate) else {
            return .unavailable(
                .unsupportedSampleRate,
                sampleRate: sampleRate,
                checkpoints: checkpoints,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
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
                checkpoints: checkpoints,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
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
                checkpoints: checkpoints,
                calibrationTrajectoryCount: profile.sourceTrajectoryCount
            )
        }
        return ProfessionalQualityCandidateAssessment(
            availability: .available,
            sampleRate: sampleRate,
            checkpoints: checkpoints,
            verdicts: verdicts,
            calibrationTrajectoryCount: profile.sourceTrajectoryCount,
            support: profile.usesDiverseCalibration
                ? .sufficient : .insufficient,
            confidence: profile.usesDiverseCalibration
                ? .notEstimated : .unavailable
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
                decisionBasis: .hardGate,
                reasonCodes: [.hardGateFailedV1],
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
                decisionBasis: .unavailable,
                reasonCodes: [.evaluatorUnavailableV1],
                diagnosticDetails: diagnosticDetails
            )
        }
        guard result.accepted else {
            return AutonomousCandidatePolicyVerdict(
                outcome: .rejected,
                decisionBasis: .calibratedQuality,
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
            decisionBasis: .calibratedQuality,
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
            decisionBasis: .hardGate,
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
        case .invalidLocalFeatureEvidence:
            return [prefix + "observation=local-feature"]
        }
    }
}
