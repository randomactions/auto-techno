import AutoTechnoCore
import Foundation

package enum ProfessionalQualityCalibrationError: Error, Equatable, Sendable {
    case invalidIdentity
    case incompleteRepresentativeRates
    case incompleteCheckpointCoverage
    case duplicateMetric
    case invalidMetricSet
    case nonFiniteMetric(ProfessionalQualityMetric)
    case incompleteKickSyntaxEvidence(CanonicalJourneyCheckpoint)
    case incompleteStemBarCoverage(
        CanonicalJourneyCheckpoint,
        [Int],
        [Int]
    )
    case incompleteStemRoleEvidence(
        CanonicalJourneyCheckpoint,
        [AutonomousStemRoleFailure]
    )
    case incompleteCandidateEvidence(
        CanonicalJourneyCheckpoint,
        [AutonomousCandidateCompletenessFailure]
    )
    case invalidBounds
    case profileMismatch
}

package struct AutonomousStemRoleFailure: Equatable, Sendable {
    package let bar: Int
    package let role: String
    package let failures: [AutonomousRoleStemCompletenessFailure]
}

/// Stable, independently evaluated dimensions retained from a complete
/// Professional Evidence bank. This is deliberately a vector rather than an
/// aggregate score: no strong dimension can compensate for a failed one.
package enum ProfessionalQualityMetric: String, CaseIterable, Codable, Sendable {
    case integratedLoudnessLUFS = "integrated-loudness-lufs"
    case maximumMomentaryLoudnessLUFS = "maximum-momentary-loudness-lufs"
    case maximumShortTermLoudnessLUFS = "maximum-short-term-loudness-lufs"
    case loudnessRangeLU = "loudness-range-lu"
    case truePeakDBTP = "true-peak-dbtp"
    case crestFactorDB = "crest-factor-db"
    case absoluteDCOffset = "absolute-dc-offset"
    case stereoCorrelation = "stereo-correlation"
    case lowStereoCorrelation = "low-stereo-correlation"
    case maximumBoundaryDelta = "maximum-boundary-delta"
    case movementScore = "movement-score"
    case activeWindowRatio = "active-window-ratio"
    case spectralCentroidMeanHz = "spectral-centroid-mean-hz"
    case spectralCentroidSpreadHz = "spectral-centroid-spread-hz"
    case spectralBandwidthMeanHz = "spectral-bandwidth-mean-hz"
    case spectralFlatnessMean = "spectral-flatness-mean"
    case spectralRolloff85MeanHz = "spectral-rolloff85-mean-hz"
    case positiveSpectralFluxMean = "positive-spectral-flux-mean"
    case positiveSpectralFluxPeak = "positive-spectral-flux-peak"
    case rmsTrajectoryDeltaMeanDB = "rms-trajectory-delta-mean-db"
    case rmsTrajectoryDeltaPeakDB = "rms-trajectory-delta-peak-db"
    case barLoudnessSpanLU = "bar-loudness-span-lu"
    case barCentroidSpanHz = "bar-centroid-span-hz"
    case barTransientDensityMean = "bar-transient-density-mean"
    case barTransientDensitySpan = "bar-transient-density-span"
    case barCrestFactorMean = "bar-crest-factor-mean"
    case barCrestFactorSpan = "bar-crest-factor-span"
    case maskingMaximumOverlap = "masking-maximum-overlap"
    case maskingOverlapWindowRatio = "masking-overlap-window-ratio"
    case maskingLongestRunRatio = "masking-longest-run-ratio"
    case activeKickFoundationBarRatio = "active-kick-foundation-bar-ratio"
    case kickOverFoundationActiveDBMean = "kick-over-foundation-active-db-mean"
    case kickGroundedBarRatio = "kick-grounded-bar-ratio"
    case kickWithheldBarRatio = "kick-withheld-bar-ratio"
    case kickRecoveryBarRatio = "kick-recovery-bar-ratio"
    case kickEventCountMean = "kick-event-count-mean"
    case kickAudibleToDetectorDBMean = "kick-audible-to-detector-db-mean"
    case kickDuckingEnvelopeRatioMean = "kick-ducking-envelope-ratio-mean"
    case kickAudibleGainMean = "kick-audible-gain-mean"
    case kickSourceOutputCrestFactorDBMean =
        "kick-source-output-crest-factor-db-mean"
    case kickSourceAttackToBodyDBMean =
        "kick-source-attack-to-body-db-mean"
    case kickSourceUpperMidEnergyRatioMean =
        "kick-source-upper-mid-energy-ratio-mean"
    case kickSourceCrestReductionDBMean =
        "kick-source-crest-reduction-db-mean"
    case foundationDottedRhythmActiveBarRatio =
        "foundation-dotted-rhythm-active-bar-ratio"
    case foundationDottedRhythmCrestFactorDBMean =
        "foundation-dotted-rhythm-crest-factor-db-mean"
    case foundationPreKickPocketSilenceRMSMaximum =
        "foundation-pre-kick-pocket-silence-rms-maximum"
    case modalPercussionActiveBarRatio =
        "modal-percussion-active-bar-ratio"
    case modalPercussionEventCountMean =
        "modal-percussion-event-count-mean"
    case modalPercussionPitchErrorCentsMaximum =
        "modal-percussion-pitch-error-cents-maximum"
    case modalPercussionAttackToBodyDBMean =
        "modal-percussion-attack-to-body-db-mean"
    case modalPercussionTailToBodyDBMean =
        "modal-percussion-tail-to-body-db-mean"
    case modalPercussionSpectralCentroidMeanHz =
        "modal-percussion-spectral-centroid-mean-hz"
    case modalPercussionMaskingMaximumOverlap =
        "modal-percussion-masking-maximum-overlap"
    case modalPercussionMaximumPoleRadius =
        "modal-percussion-maximum-pole-radius"
    case upperPercussionTailClearanceEventRatio =
        "upper-percussion-tail-clearance-event-ratio"
    case upperPercussionTailRenderedTailToAttackDBMean =
        "upper-percussion-tail-rendered-tail-to-attack-db-mean"
    case upperSpectralRevealActiveEventRatio =
        "upper-spectral-reveal-active-event-ratio"
    case upperSpectralRevealAppliedCutoffRatioMean =
        "upper-spectral-reveal-applied-cutoff-ratio-mean"
    case percussionAnticipationSwellActiveBarRatio =
        "percussion-anticipation-swell-active-bar-ratio"
    case percussionAnticipationSwellLateToEarlyDBMean =
        "percussion-anticipation-swell-late-to-early-db-mean"
    case padRhythmicModulationActiveBarRatio =
        "pad-rhythmic-modulation-active-bar-ratio"
    case padRhythmicFilterDifferenceToPadDBMean =
        "pad-rhythmic-filter-difference-to-pad-db-mean"
    case padRhythmicSpatialDifferenceToSendDBMean =
        "pad-rhythmic-spatial-difference-to-send-db-mean"
    case padHarmonicDisclosureRevealedBarRatio =
        "pad-harmonic-disclosure-revealed-bar-ratio"
    case padHarmonicDisclosureDistinctFunctionCount =
        "pad-harmonic-disclosure-distinct-function-count"

    package var acceptsSaferValuesBelowCalibration: Bool {
        switch self {
        case .truePeakDBTP, .absoluteDCOffset, .maximumBoundaryDelta,
                .maskingMaximumOverlap, .maskingOverlapWindowRatio,
                .maskingLongestRunRatio,
                .modalPercussionPitchErrorCentsMaximum,
                .modalPercussionMaskingMaximumOverlap,
                .modalPercussionMaximumPoleRadius,
                .foundationPreKickPocketSilenceRMSMaximum:
            return true
        default:
            return false
        }
    }

    /// EBU-style LRA is retained as descriptive phrase evidence. On short
    /// autonomous phrases its relative gate and percentile population can
    /// change discontinuously when one short-term block crosses the gate, so
    /// it is not a stable non-compensable policy dimension.
    package var participatesInQualification: Bool {
        self != .loudnessRangeLU
    }

    package var semanticMinimum: Double {
        switch self {
        case .truePeakDBTP, .modalPercussionAttackToBodyDBMean,
                .modalPercussionTailToBodyDBMean,
                .upperPercussionTailRenderedTailToAttackDBMean,
                .percussionAnticipationSwellLateToEarlyDBMean,
                .padRhythmicFilterDifferenceToPadDBMean,
                .padRhythmicSpatialDifferenceToSendDBMean,
                .kickSourceOutputCrestFactorDBMean,
                .kickSourceAttackToBodyDBMean,
                .kickSourceCrestReductionDBMean:
            return -120
        default: return 0
        }
    }
}

package struct ProfessionalQualityMetricValue: Codable, Equatable, Sendable {
    package let metric: ProfessionalQualityMetric
    package let value: Double

    package init(metric: ProfessionalQualityMetric, value: Double) {
        self.metric = metric
        self.value = value
    }
}

/// Signal-free provenance for the one live master-headroom transition bound to
/// a professional-quality observation. Loudness and true peak remain the
/// existing calibrated metrics; this record is a non-compensable controller,
/// terminal-scaling, route, and future-boundary hard gate.
package struct ProfessionalQualityLiveMasterProvenance: Encodable, Equatable,
        Sendable {
    package static let schemaVersion = LiveMasterHeadroomContinuationState
        .schemaVersion

    package let schemaVersion: Int
    package let controllerPolicyVersion: String
    package let incomingRevision: Int
    package let outgoingRevision: Int
    package let revisionDelta: Int
    package let incomingStateFingerprint: String
    package let outgoingStateFingerprint: String
    package let proposalOutcome: LiveFeedbackProposalOutcome
    package let observationFingerprint: String?
    package let proposalFingerprint: String?
    package let incomingTrimDB: Double
    package let requestedTrimDB: Double
    package let appliedTrimDB: Double
    package let trimDeltaDB: Double
    package let appliedGain: Double
    package let incomingCleanWindowCount: Int
    package let outgoingCleanWindowCount: Int
    package let routeGeneration: Int
    package let routeGenerationValid: Bool
    package let proposalBindingValid: Bool
    package let preTrimPCMFingerprint: String
    package let postTrimPCMFingerprint: String
    package let preTrimBindingValid: Bool
    package let postTrimBindingValid: Bool
    package let terminalScalingValid: Bool
    package let earliestEligibleFutureSample: Int64?
    package let appliedFutureSample: Int64?
    package let boundaryValid: Bool

    private init(
        controllerPolicyVersion: String,
        incomingRevision: Int,
        outgoingRevision: Int,
        incomingStateFingerprint: String,
        outgoingStateFingerprint: String,
        proposalOutcome: LiveFeedbackProposalOutcome,
        observationFingerprint: String?,
        proposalFingerprint: String?,
        incomingTrimDB: Double,
        requestedTrimDB: Double,
        appliedTrimDB: Double,
        appliedGain: Double,
        incomingCleanWindowCount: Int,
        outgoingCleanWindowCount: Int,
        routeGeneration: Int,
        routeGenerationValid: Bool,
        proposalBindingValid: Bool,
        preTrimPCMFingerprint: String,
        postTrimPCMFingerprint: String,
        preTrimBindingValid: Bool,
        postTrimBindingValid: Bool,
        terminalScalingValid: Bool,
        earliestEligibleFutureSample: Int64?,
        appliedFutureSample: Int64?,
        boundaryValid: Bool
    ) {
        schemaVersion = Self.schemaVersion
        self.controllerPolicyVersion = controllerPolicyVersion
        self.incomingRevision = incomingRevision
        self.outgoingRevision = outgoingRevision
        revisionDelta = outgoingRevision - incomingRevision
        self.incomingStateFingerprint = incomingStateFingerprint
        self.outgoingStateFingerprint = outgoingStateFingerprint
        self.proposalOutcome = proposalOutcome
        self.observationFingerprint = observationFingerprint
        self.proposalFingerprint = proposalFingerprint
        self.incomingTrimDB = incomingTrimDB
        self.requestedTrimDB = requestedTrimDB
        self.appliedTrimDB = appliedTrimDB
        trimDeltaDB = appliedTrimDB - incomingTrimDB
        self.appliedGain = appliedGain
        self.incomingCleanWindowCount = incomingCleanWindowCount
        self.outgoingCleanWindowCount = outgoingCleanWindowCount
        self.routeGeneration = routeGeneration
        self.routeGenerationValid = routeGenerationValid
        self.proposalBindingValid = proposalBindingValid
        self.preTrimPCMFingerprint = preTrimPCMFingerprint
        self.postTrimPCMFingerprint = postTrimPCMFingerprint
        self.preTrimBindingValid = preTrimBindingValid
        self.postTrimBindingValid = postTrimBindingValid
        self.terminalScalingValid = terminalScalingValid
        self.earliestEligibleFutureSample = earliestEligibleFutureSample
        self.appliedFutureSample = appliedFutureSample
        self.boundaryValid = boundaryValid
    }

    package var isComplete: Bool {
        schemaVersion == Self.schemaVersion &&
            controllerPolicyVersion ==
                LiveFeedbackContract.controllerPolicyVersion &&
            incomingRevision >= 0 && outgoingRevision >= 0 &&
            isFingerprint(incomingStateFingerprint) &&
            isFingerprint(outgoingStateFingerprint) &&
            observationFingerprint.map(isFingerprint) ?? true &&
            proposalFingerprint.map(isFingerprint) ?? true &&
            isFingerprint(preTrimPCMFingerprint) &&
            isFingerprint(postTrimPCMFingerprint) &&
            incomingTrimDB.isFinite && requestedTrimDB.isFinite &&
            appliedTrimDB.isFinite && trimDeltaDB.isFinite &&
            appliedGain.isFinite &&
            revisionDelta == outgoingRevision - incomingRevision &&
            trimDeltaDB == appliedTrimDB - incomingTrimDB &&
            (0...2).contains(incomingCleanWindowCount) &&
            (0...2).contains(outgoingCleanWindowCount) &&
            routeGeneration >= 0 &&
            earliestEligibleFutureSample.map { $0 > 0 } ?? true &&
            appliedFutureSample.map { $0 > 0 } ?? true
    }

    package var hardGatesPassed: Bool {
        isComplete && controllerTransitionValid && terminalScaleIsValid &&
            !boostsAboveUnity && proposalBindingValid &&
            routeAndBoundaryAreValid
    }

    package var controllerTransitionValid: Bool {
        let hasProposal = proposalFingerprint != nil
        guard hasProposal else {
            return proposalOutcome == .hold && observationFingerprint == nil &&
                revisionDelta == 0 && trimDeltaDB == 0 &&
                incomingStateFingerprint == outgoingStateFingerprint &&
                incomingCleanWindowCount == outgoingCleanWindowCount &&
                earliestEligibleFutureSample == nil &&
                appliedFutureSample == nil
        }
        if proposalOutcome == .unavailable {
            return revisionDelta == 0 && trimDeltaDB == 0 &&
                incomingStateFingerprint == outgoingStateFingerprint &&
                incomingCleanWindowCount == outgoingCleanWindowCount
        }
        guard observationFingerprint != nil, revisionDelta == 1,
              incomingStateFingerprint != outgoingStateFingerprint else {
            return false
        }
        switch proposalOutcome {
        case .unavailable:
            return false
        case .hold:
            return trimDeltaDB == 0
        case .attenuate:
            return trimDeltaDB < 0 &&
                trimDeltaDB >= -LiveMasterHeadroomController.attackStepDB &&
                outgoingCleanWindowCount == 0
        case .recover:
            return trimDeltaDB > 0 &&
                trimDeltaDB <= LiveMasterHeadroomController.recoveryStepDB &&
                incomingCleanWindowCount >=
                    LiveMasterHeadroomController.cleanWindowsForRecovery - 1 &&
                outgoingCleanWindowCount == 0
        }
    }

    package var recoveryIsEarly: Bool {
        proposalOutcome == .recover && incomingCleanWindowCount <
            LiveMasterHeadroomController.cleanWindowsForRecovery - 1
    }

    package var exceedsTransitionSlew: Bool {
        switch proposalOutcome {
        case .attenuate:
            return trimDeltaDB < -LiveMasterHeadroomController.attackStepDB
        case .recover:
            return trimDeltaDB > LiveMasterHeadroomController.recoveryStepDB
        case .unavailable, .hold:
            return trimDeltaDB != 0
        }
    }

    package var boostsAboveUnity: Bool {
        incomingTrimDB > 0 || requestedTrimDB > 0 || appliedTrimDB > 0 ||
            appliedGain > 1
    }

    package var terminalScaleIsValid: Bool {
        preTrimBindingValid && postTrimBindingValid && terminalScalingValid &&
            requestedTrimDB == appliedTrimDB &&
            (-3...0).contains(appliedTrimDB) && appliedGain > 0 &&
            appliedGain <= 1 &&
            appliedGain == pow(10, appliedTrimDB / 20)
    }

    package var routeAndBoundaryAreValid: Bool {
        guard routeGenerationValid, boundaryValid else { return false }
        if proposalFingerprint == nil {
            return earliestEligibleFutureSample == nil &&
                appliedFutureSample == nil
        }
        guard let earliestEligibleFutureSample, let appliedFutureSample else {
            return false
        }
        return appliedFutureSample >= earliestEligibleFutureSample
    }

    package static func home(
        candidate: AutonomousCandidateEvaluationVector
    ) throws -> Self {
        let provenance = try candidateDerived(candidate)
        guard candidate.liveProposalFingerprint == nil,
              candidate.liveProposalOutcome == .hold,
              provenance.controllerTransitionValid,
              provenance.hardGatesPassed else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return provenance
    }

    package static func transition(
        candidate: AutonomousCandidateEvaluationVector
    ) throws -> Self {
        let provenance = try candidateDerived(candidate)
        guard candidate.liveProposalFingerprint != nil,
              candidate.liveProposalOutcome != .unavailable,
              provenance.controllerTransitionValid,
              provenance.hardGatesPassed else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return provenance
    }

    package static func candidateDerived(
        _ candidate: AutonomousCandidateEvaluationVector
    ) throws -> Self {
        guard candidate.isComplete,
              candidate.isFinite else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let hasProposal = candidate.liveProposalFingerprint != nil
        let boundaryValid: Bool
        if hasProposal,
           let earliest = candidate.liveEarliestEligibleFutureSample,
           let applied = candidate.liveAppliedFutureSample {
            boundaryValid = applied >= earliest
        } else {
            boundaryValid = !hasProposal &&
                candidate.liveEarliestEligibleFutureSample == nil &&
                candidate.liveAppliedFutureSample == nil
        }
        let provenance = Self(
            controllerPolicyVersion: LiveFeedbackContract.controllerPolicyVersion,
            incomingRevision: candidate.incomingLiveMasterRevision,
            outgoingRevision: candidate.outgoingLiveMasterRevision,
            incomingStateFingerprint:
                candidate.incomingLiveMasterStateFingerprint,
            outgoingStateFingerprint:
                candidate.outgoingLiveMasterStateFingerprint,
            proposalOutcome: candidate.liveProposalOutcome,
            observationFingerprint: candidate.liveObservationFingerprint,
            proposalFingerprint: candidate.liveProposalFingerprint,
            incomingTrimDB: candidate.incomingLiveMasterTrimDB,
            requestedTrimDB: candidate.requestedLiveMasterTrimDB,
            appliedTrimDB: candidate.appliedLiveMasterTrimDB,
            appliedGain: candidate.liveMasterGain,
            incomingCleanWindowCount:
                candidate.incomingLiveMasterCleanWindowCount,
            outgoingCleanWindowCount:
                candidate.outgoingLiveMasterCleanWindowCount,
            routeGeneration: candidate.routeContinuation.routeGeneration,
            routeGenerationValid: candidate.routeContinuation.isComplete,
            proposalBindingValid: candidate.liveProposalBindingMatches,
            preTrimPCMFingerprint: candidate.preLiveMasterPCMFingerprint,
            postTrimPCMFingerprint: candidate.postLiveMasterPCMFingerprint,
            preTrimBindingValid: isFingerprint(
                candidate.preLiveMasterPCMFingerprint
            ),
            postTrimBindingValid: isFingerprint(
                candidate.postLiveMasterPCMFingerprint
            ),
            terminalScalingValid: candidate.liveMasterScalingMatches,
            earliestEligibleFutureSample:
                candidate.liveEarliestEligibleFutureSample,
            appliedFutureSample: candidate.liveAppliedFutureSample,
            boundaryValid: boundaryValid
        )
        guard provenance.isComplete else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return provenance
    }

    package func attacked(
        _ attack: ProfessionalQualityLiveMasterAttack
    ) -> Self {
        Self(
            controllerPolicyVersion: controllerPolicyVersion,
            incomingRevision: incomingRevision,
            outgoingRevision: attack == .staleControllerRevision
                ? incomingRevision : outgoingRevision,
            incomingStateFingerprint: incomingStateFingerprint,
            outgoingStateFingerprint: outgoingStateFingerprint,
            proposalOutcome: proposalOutcome,
            observationFingerprint: observationFingerprint,
            proposalFingerprint: proposalFingerprint,
            incomingTrimDB: incomingTrimDB,
            requestedTrimDB: requestedTrimDB,
            appliedTrimDB: attack == .overAttack
                ? appliedTrimDB -
                    LiveMasterHeadroomController.attackStepDB
                : appliedTrimDB,
            appliedGain: attack == .boostAboveUnity ? 1.01 : appliedGain,
            incomingCleanWindowCount: attack == .earlyRecovery
                ? 0 : incomingCleanWindowCount,
            outgoingCleanWindowCount: outgoingCleanWindowCount,
            routeGeneration: routeGeneration,
            routeGenerationValid: attack != .staleRouteGeneration &&
                routeGenerationValid,
            proposalBindingValid: attack != .unboundProposalFingerprint &&
                proposalBindingValid,
            preTrimPCMFingerprint: preTrimPCMFingerprint,
            postTrimPCMFingerprint: postTrimPCMFingerprint,
            preTrimBindingValid: attack != .forgedPreTerminalScaling &&
                preTrimBindingValid,
            postTrimBindingValid: attack != .forgedPostTerminalScaling &&
                postTrimBindingValid,
            terminalScalingValid: terminalScalingValid,
            earliestEligibleFutureSample: earliestEligibleFutureSample,
            appliedFutureSample: attack == .earlyBoundary
                ? earliestEligibleFutureSample.map { $0 - 1 }
                : appliedFutureSample,
            boundaryValid: boundaryValid
        )
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }

    private func isFingerprint(_ value: String) -> Bool {
        Self.isFingerprint(value)
    }
}

package enum ProfessionalQualityLiveMasterAttack: Sendable {
    case forgedPreTerminalScaling
    case forgedPostTerminalScaling
    case boostAboveUnity
    case overAttack
    case earlyRecovery
    case staleRouteGeneration
    case staleControllerRevision
    case unboundProposalFingerprint
    case earlyBoundary
}

/// A bounded, non-reconstructable projection of one selected phrase. It carries
/// no PCM, stems, event lists, or sample hashes.
package struct ProfessionalQualityObservation: Codable, Equatable, Sendable {
    package static let schemaVersion = 11
    package static let observationVersion =
        "autotechno-professional-quality-observation.v11"

    package let schemaVersion: Int
    package let observationVersion: String
    package let engineVersion: String
    package let evidenceVersion: String
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let hardGatesPassed: Bool
    package let liveMaster: ProfessionalQualityLiveMasterProvenance
    package let sourceMetricCount: Int
    package let metrics: [ProfessionalQualityMetricValue]

    package init(
        engineVersion: String,
        evidenceVersion: String = ProfessionalEvidenceReportBank.evidenceVersion,
        checkpoint: CanonicalJourneyCheckpoint,
        sampleRate: Double,
        hardGatesPassed: Bool,
        liveMaster: ProfessionalQualityLiveMasterProvenance,
        metrics sourceMetrics: [ProfessionalQualityMetricValue]
    ) throws {
        guard !engineVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
              evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion,
              sampleRate.isFinite,
              sampleRate >= QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract.maximumSupportedSampleRate else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let sorted = sourceMetrics.sorted { $0.metric.rawValue < $1.metric.rawValue }
        guard sorted.count == ProfessionalQualityMetric.allCases.count,
              Set(sorted.map(\.metric)).count == sorted.count else {
            throw ProfessionalQualityCalibrationError.invalidMetricSet
        }
        if let invalid = sorted.first(where: { !$0.value.isFinite }) {
            throw ProfessionalQualityCalibrationError.nonFiniteMetric(
                invalid.metric
            )
        }
        schemaVersion = Self.schemaVersion
        observationVersion = Self.observationVersion
        self.engineVersion = engineVersion
        self.evidenceVersion = evidenceVersion
        self.checkpoint = checkpoint
        self.sampleRate = sampleRate
        self.hardGatesPassed = hardGatesPassed
        self.liveMaster = liveMaster
        sourceMetricCount = sourceMetrics.count
        metrics = sorted
    }

    /// Projects one complete detached candidate into the same bounded metric
    /// observation used by the offline journey bank. The caller supplies only
    /// a Core-owned checkpoint that the candidate actually represents; no PCM,
    /// renderer state, or report wrapper is required by the primary evaluator.
    package init(
        candidate vector: AutonomousCandidateEvaluationVector,
        engineVersion: String,
        checkpoint: CanonicalJourneyCheckpoint
    ) throws {
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: vector.symbolic.phraseKind
        ), CanonicalJourneyCheckpoint.applicable(
            phraseIndex: vector.symbolic.phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: vector.symbolic.chapterChanged
        ).contains(checkpoint) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let sampleRate = vector.routeContinuation.sampleRate
        let expectedStemBars = vector.fullMix.bars.map(\.bar).sorted()
        let actualStemBars = vector.stems.map(\.bar).sorted()
        guard actualStemBars == expectedStemBars,
              vector.stems.count == vector.fullMix.sourceBarCount else {
            throw ProfessionalQualityCalibrationError
                .incompleteStemBarCoverage(
                    checkpoint,
                    expectedStemBars,
                    actualStemBars
                )
        }
        let stemRoleFailures = vector.stems.flatMap { stem in
            stem.roles.compactMap { role -> AutonomousStemRoleFailure? in
                let failures = role.completenessFailures
                return failures.isEmpty ? nil : AutonomousStemRoleFailure(
                    bar: stem.bar,
                    role: role.role,
                    failures: failures
                )
            }
        }
        guard stemRoleFailures.isEmpty else {
            throw ProfessionalQualityCalibrationError
                .incompleteStemRoleEvidence(
                    checkpoint,
                    stemRoleFailures
                )
        }
        guard vector.kickSyntax.count == vector.fullMix.sourceBarCount,
              vector.kickSyntax.allSatisfy({
                  $0.isComplete(sampleRate: sampleRate)
              }) else {
            throw ProfessionalQualityCalibrationError
                .incompleteKickSyntaxEvidence(checkpoint)
        }
        guard vector.isComplete, vector.isFinite else {
            throw ProfessionalQualityCalibrationError
                .incompleteCandidateEvidence(
                    checkpoint,
                    vector.completenessFailures
                )
        }
        let fullMix = vector.fullMix
        let perceptual = fullMix.perceptual
        let bars = fullMix.bars

        func span(_ values: [Double]) -> Double {
            guard let minimum = values.min(), let maximum = values.max() else {
                return 0
            }
            return maximum - minimum
        }
        func mean(_ values: [Double]) -> Double {
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
        func decibels(_ numerator: Double, _ denominator: Double) -> Double {
            guard numerator > 0, denominator > 0 else { return -120 }
            // Subtracting logarithms avoids an intermediate ratio that can
            // underflow to zero even when both bounded inputs are finite.
            return min(120, max(-120,
                20 * (log10(numerator) - log10(denominator))
            ))
        }

        let masking = vector.masking.flatMap(\.observations)
        let maskingAnalyzedWindows = masking.reduce(0) {
            $0 + $1.analyzedWindowCount
        }
        let maskingOverlapWindows = masking.reduce(0) {
            $0 + $1.overlapWindowCount
        }
        let maskingLongestRun = masking.map(\.longestOverlapRun).max() ?? 0

        let kickSyntax = vector.kickSyntax
        let kickRoles = kickSyntax.compactMap {
            KickSyntaxRole(rawValue: $0.role)
        }
        let activeKickSyntax = kickSyntax.filter {
            $0.detectorRMS > 0 && $0.audibleRMS > 0
        }
        let kickDivisor = Double(max(1, kickSyntax.count))
        let foundationRhythm = vector.foundationRhythm
        let activeFoundationRhythm = foundationRhythm.filter {
            $0.relation ==
                FoundationRhythmicRelation.dottedThreeSixteenth.rawValue
        }
        let foundationRhythmDivisor = Double(max(1, foundationRhythm.count))
        let activeFoundationPreKickPockets = activeFoundationRhythm.map(
            \.preKickPocket
        )

        let modalBars = vector.modalPercussion
        let activeModalBars = modalBars.filter {
            !$0.events.isEmpty || $0.activeIncomingVoiceCount > 0
        }
        let modalEvents = modalBars.flatMap(\.events)
        let modalDivisor = Double(max(1, modalBars.count))
        let activeModalBarSet = Set(activeModalBars.map(\.bar))
        let modalMasking = vector.masking
            .filter { activeModalBarSet.contains($0.bar) }
            .flatMap(\.observations)
            .filter {
                $0.firstRole == MaskingRole.foundation.rawValue &&
                    ($0.secondRole == MaskingRole.percussion.rawValue ||
                        $0.secondRole == MaskingRole.upper.rawValue)
            }

        let upperPercussionTailEvents = vector.upperPercussionTail
            .flatMap(\.events)
        let activeUpperPercussionTailEvents = upperPercussionTailEvents.filter {
            $0.role == UpperPercussionTailRole.foregroundClearance.rawValue
        }
        let upperPercussionTailDivisor = Double(
            max(1, upperPercussionTailEvents.count)
        )
        let spectralRevealEvidence = vector.instruments.flatMap(
            \.architectures
        ).compactMap(\.upperSpectralReveal)
        let activeSpectralRevealEvidence = spectralRevealEvidence.filter(
            \.active
        )
        let spectralRevealEventCount = spectralRevealEvidence.reduce(0) {
            $0 + $1.renderedEventCount
        }
        let activeSpectralRevealEventCount =
            activeSpectralRevealEvidence.reduce(0) {
                $0 + $1.activeEventCount
            }
        let spectralRevealDivisor = Double(max(1, spectralRevealEventCount))
        let anticipationSwellBars = vector.percussionEchoTexture.filter {
            $0.relation ==
                PercussionEchoTextureRelation.anticipationSwell.rawValue
        }
        let anticipationBarDivisor = Double(
            max(1, vector.percussionEchoTexture.count)
        )
        let rhythmicPadBars = vector.phraseComposition.filter {
            $0.padRhythmicModulationRelation ==
                PadRhythmicModulationRelation.threeStepPulse.rawValue
        }
        let phraseCompositionDivisor = Double(
            max(1, vector.phraseComposition.count)
        )
        let revealedPadBars = vector.phraseComposition.filter {
            $0.padActive && $0.padHarmonicDisclosureStage ==
                PadHarmonicDisclosureStage.revealed.rawValue
        }
        let distinctPadFunctionCount = Set(
            vector.phraseComposition.filter(\.padActive).map(\.padFunction)
        ).count

        var kickFoundationDifferences: [Double] = []
        for stemBar in vector.stems {
            guard let kick = stemBar.roles.first(where: {
                $0.role == MixRole.kick.rawValue
            }), let foundation = stemBar.roles.first(where: {
                $0.role == MixRole.foundation.rawValue
            }), kick.activeRMS > 0, foundation.activeRMS > 0 else { continue }
            kickFoundationDifferences.append(decibels(
                kick.activeRMS, foundation.activeRMS
            ))
        }

        let loudness = bars.map(\.loudness)
        let centroids = bars.map(\.spectralCentroid)
        let transients = bars.map(\.transientDensity)
        let crests = bars.map(\.crestFactor)
        let activeRatio = perceptual.analyzedWindowCount == 0 ? 0 :
            Double(perceptual.activeWindowCount) /
                Double(perceptual.analyzedWindowCount)
        let crestDB = fullMix.peak > 0 && fullMix.rms > 0
            ? decibels(fullMix.peak, fullMix.rms) : 0
        let metrics = [
            ProfessionalQualityMetricValue(metric: .integratedLoudnessLUFS,
                value: fullMix.integratedLoudness),
            ProfessionalQualityMetricValue(metric: .maximumMomentaryLoudnessLUFS,
                value: fullMix.maximumMomentaryLoudness),
            ProfessionalQualityMetricValue(metric: .maximumShortTermLoudnessLUFS,
                value: fullMix.maximumShortTermLoudness),
            ProfessionalQualityMetricValue(metric: .loudnessRangeLU,
                value: fullMix.loudnessRange),
            ProfessionalQualityMetricValue(metric: .truePeakDBTP,
                value: fullMix.truePeakDBTP),
            ProfessionalQualityMetricValue(metric: .crestFactorDB,
                value: crestDB),
            ProfessionalQualityMetricValue(metric: .absoluteDCOffset,
                value: abs(fullMix.dcOffset)),
            ProfessionalQualityMetricValue(metric: .stereoCorrelation,
                value: fullMix.stereoCorrelation),
            ProfessionalQualityMetricValue(metric: .lowStereoCorrelation,
                value: fullMix.lowStereoCorrelation),
            ProfessionalQualityMetricValue(metric: .maximumBoundaryDelta,
                value: fullMix.maximumBoundaryDelta),
            ProfessionalQualityMetricValue(metric: .movementScore,
                value: fullMix.movementScore),
            ProfessionalQualityMetricValue(metric: .activeWindowRatio,
                value: activeRatio),
            ProfessionalQualityMetricValue(metric: .spectralCentroidMeanHz,
                value: perceptual.spectralCentroidMeanHz),
            ProfessionalQualityMetricValue(metric: .spectralCentroidSpreadHz,
                value: perceptual.spectralCentroidSpreadHz),
            ProfessionalQualityMetricValue(metric: .spectralBandwidthMeanHz,
                value: perceptual.spectralBandwidthMeanHz),
            ProfessionalQualityMetricValue(metric: .spectralFlatnessMean,
                value: perceptual.spectralFlatnessMean),
            ProfessionalQualityMetricValue(metric: .spectralRolloff85MeanHz,
                value: perceptual.spectralRolloff85MeanHz),
            ProfessionalQualityMetricValue(metric: .positiveSpectralFluxMean,
                value: perceptual.positiveSpectralFluxMean),
            ProfessionalQualityMetricValue(metric: .positiveSpectralFluxPeak,
                value: perceptual.positiveSpectralFluxPeak),
            ProfessionalQualityMetricValue(metric: .rmsTrajectoryDeltaMeanDB,
                value: perceptual.rmsTrajectoryDeltaMeanDB),
            ProfessionalQualityMetricValue(metric: .rmsTrajectoryDeltaPeakDB,
                value: perceptual.rmsTrajectoryDeltaPeakDB),
            ProfessionalQualityMetricValue(metric: .barLoudnessSpanLU,
                value: span(loudness)),
            ProfessionalQualityMetricValue(metric: .barCentroidSpanHz,
                value: span(centroids)),
            ProfessionalQualityMetricValue(metric: .barTransientDensityMean,
                value: mean(transients)),
            ProfessionalQualityMetricValue(metric: .barTransientDensitySpan,
                value: span(transients)),
            ProfessionalQualityMetricValue(metric: .barCrestFactorMean,
                value: mean(crests)),
            ProfessionalQualityMetricValue(metric: .barCrestFactorSpan,
                value: span(crests)),
            ProfessionalQualityMetricValue(metric: .maskingMaximumOverlap,
                value: masking.map(\.maximumOverlap).max() ?? 0),
            ProfessionalQualityMetricValue(metric: .maskingOverlapWindowRatio,
                value: maskingAnalyzedWindows == 0 ? 0 :
                    Double(maskingOverlapWindows) /
                        Double(maskingAnalyzedWindows)),
            ProfessionalQualityMetricValue(metric: .maskingLongestRunRatio,
                value: maskingAnalyzedWindows == 0 ? 0 :
                    Double(maskingLongestRun) /
                        Double(SpectrumMaskingAnalyzer.analyzedWindowCount)),
            ProfessionalQualityMetricValue(metric: .activeKickFoundationBarRatio,
                value: vector.stems.isEmpty ? 0 :
                    Double(kickFoundationDifferences.count) /
                        Double(vector.stems.count)),
            ProfessionalQualityMetricValue(metric: .kickOverFoundationActiveDBMean,
                value: mean(kickFoundationDifferences)),
            ProfessionalQualityMetricValue(metric: .kickGroundedBarRatio,
                value: Double(kickRoles.filter { $0 == .grounded }.count) /
                    kickDivisor),
            ProfessionalQualityMetricValue(metric: .kickWithheldBarRatio,
                value: Double(kickRoles.filter { $0 == .withheld }.count) /
                    kickDivisor),
            ProfessionalQualityMetricValue(metric: .kickRecoveryBarRatio,
                value: Double(kickRoles.filter { $0 == .recovery }.count) /
                    kickDivisor),
            ProfessionalQualityMetricValue(metric: .kickEventCountMean,
                value: mean(kickSyntax.map { Double($0.scoreKickEventCount) })),
            ProfessionalQualityMetricValue(metric: .kickAudibleToDetectorDBMean,
                value: mean(activeKickSyntax.map {
                    decibels($0.audibleRMS, $0.detectorRMS)
                })),
            ProfessionalQualityMetricValue(metric: .kickDuckingEnvelopeRatioMean,
                value: mean(activeKickSyntax.map {
                    $0.duckingEnvelopePeak / max($0.detectorPeak, 1e-12)
                })),
            ProfessionalQualityMetricValue(metric: .kickAudibleGainMean,
                value: mean(kickSyntax.map(\.audibleGain))),
            ProfessionalQualityMetricValue(
                metric: .kickSourceOutputCrestFactorDBMean,
                value: mean(activeKickSyntax.map {
                    decibels(
                        $0.sourceDynamics.outputPeak,
                        $0.sourceDynamics.outputRMS
                    )
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .kickSourceAttackToBodyDBMean,
                value: mean(activeKickSyntax.map {
                    decibels(
                        $0.sourceDynamics.outputAttackRMS,
                        $0.sourceDynamics.outputBodyRMS
                    )
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .kickSourceUpperMidEnergyRatioMean,
                value: mean(activeKickSyntax.map {
                    $0.sourceDynamics.outputUpperMidEnergyRatio
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .kickSourceCrestReductionDBMean,
                value: mean(activeKickSyntax.map {
                    decibels(
                        $0.sourceDynamics.inputCrestFactor,
                        $0.sourceDynamics.outputCrestFactor
                    )
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .foundationDottedRhythmActiveBarRatio,
                value: Double(activeFoundationRhythm.count) /
                    foundationRhythmDivisor
            ),
            ProfessionalQualityMetricValue(
                metric: .foundationDottedRhythmCrestFactorDBMean,
                value: mean(activeFoundationRhythm.map {
                    decibels($0.peak, $0.rms)
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .foundationPreKickPocketSilenceRMSMaximum,
                value: activeFoundationPreKickPockets.map(\.silenceRMS).max() ?? 0
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionActiveBarRatio,
                value: Double(activeModalBars.count) / modalDivisor
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionEventCountMean,
                value: mean(modalBars.map { Double($0.events.count) })
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionPitchErrorCentsMaximum,
                value: modalEvents.map { event in
                    abs(1_200 * log2(
                        event.appliedFundamentalHz /
                            event.requestedFundamentalHz
                    ))
                }.max() ?? 0
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionAttackToBodyDBMean,
                value: mean(modalEvents.map {
                    decibels(max($0.attackRMS, 1e-12),
                             max($0.bodyRMS, 1e-12))
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionTailToBodyDBMean,
                value: mean(modalEvents.map {
                    decibels(max($0.tailRMS, 1e-12),
                             max($0.bodyRMS, 1e-12))
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionSpectralCentroidMeanHz,
                value: mean(modalEvents.map(\.spectralCentroidHz))
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionMaskingMaximumOverlap,
                value: modalMasking.map(\.maximumOverlap).max() ?? 0
            ),
            ProfessionalQualityMetricValue(
                metric: .modalPercussionMaximumPoleRadius,
                value: modalEvents.map(\.maximumPoleRadius).max() ?? 0
            ),
            ProfessionalQualityMetricValue(
                metric: .upperPercussionTailClearanceEventRatio,
                value: Double(activeUpperPercussionTailEvents.count) /
                    upperPercussionTailDivisor
            ),
            ProfessionalQualityMetricValue(
                metric: .upperPercussionTailRenderedTailToAttackDBMean,
                value: mean(activeUpperPercussionTailEvents.map(
                    \.renderedTailToAttackDB
                ))
            ),
            ProfessionalQualityMetricValue(
                metric: .upperSpectralRevealActiveEventRatio,
                value: Double(activeSpectralRevealEventCount) /
                    spectralRevealDivisor
            ),
            ProfessionalQualityMetricValue(
                metric: .upperSpectralRevealAppliedCutoffRatioMean,
                value: mean(activeSpectralRevealEvidence.map {
                    $0.maximumAppliedCutoffHz /
                        vector.routeContinuation.sampleRate
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .percussionAnticipationSwellActiveBarRatio,
                value: Double(anticipationSwellBars.count) /
                    anticipationBarDivisor
            ),
            ProfessionalQualityMetricValue(
                metric: .percussionAnticipationSwellLateToEarlyDBMean,
                value: mean(anticipationSwellBars.map(\.lateToEarlyDB))
            ),
            ProfessionalQualityMetricValue(
                metric: .padRhythmicModulationActiveBarRatio,
                value: Double(rhythmicPadBars.count) /
                    phraseCompositionDivisor
            ),
            ProfessionalQualityMetricValue(
                metric: .padRhythmicFilterDifferenceToPadDBMean,
                value: mean(rhythmicPadBars.map {
                    decibels(
                        $0.padFilterModulationDifferenceRMS,
                        $0.padRMS
                    )
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .padRhythmicSpatialDifferenceToSendDBMean,
                value: mean(rhythmicPadBars.map {
                    decibels(
                        $0.padSpatialSendDifferenceRMS,
                        $0.padSpatialSendRMS
                    )
                })
            ),
            ProfessionalQualityMetricValue(
                metric: .padHarmonicDisclosureRevealedBarRatio,
                value: Double(revealedPadBars.count) /
                    phraseCompositionDivisor
            ),
            ProfessionalQualityMetricValue(
                metric: .padHarmonicDisclosureDistinctFunctionCount,
                value: Double(distinctPadFunctionCount)
            ),
        ]
        try self.init(
            engineVersion: engineVersion,
            checkpoint: checkpoint,
            sampleRate: sampleRate,
            hardGatesPassed: vector.hardGatesPassed,
            liveMaster: try ProfessionalQualityLiveMasterProvenance
                .candidateDerived(vector),
            metrics: metrics
        )
    }

    package init(report: CanonicalJourneyQualificationReport) throws {
        guard report.evidenceScope ==
                CanonicalJourneyQualificationReport.currentEvidenceScope else {
            throw ProfessionalQualityCalibrationError
                .incompleteCandidateEvidence(
                    report.checkpoint,
                    report.selectedCandidateEvidence.completenessFailures
                )
        }
        try self.init(
            candidate: report.selectedCandidateEvidence,
            engineVersion: report.engineVersion,
            checkpoint: report.checkpoint
        )
    }

    package subscript(metric: ProfessionalQualityMetric) -> Double? {
        metrics.first { $0.metric == metric }?.value
    }

    package var isComplete: Bool {
        schemaVersion == Self.schemaVersion &&
            observationVersion == Self.observationVersion &&
            !engineVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty &&
            evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion &&
            sampleRate.isFinite &&
            sampleRate >= QualityQualificationContract.minimumSupportedSampleRate &&
            sampleRate <= QualityQualificationContract.maximumSupportedSampleRate &&
            sourceMetricCount == metrics.count &&
            metrics.count == ProfessionalQualityMetric.allCases.count &&
            Set(metrics.map(\.metric)).count == metrics.count &&
            metrics == metrics.sorted { $0.metric.rawValue < $1.metric.rawValue } &&
            metrics.allSatisfy { $0.value.isFinite } && liveMaster.isComplete
    }

    package func replacing(
        _ metric: ProfessionalQualityMetric,
        with value: Double,
        hardGatesPassed: Bool? = nil
    ) throws -> ProfessionalQualityObservation {
        try ProfessionalQualityObservation(
            engineVersion: engineVersion,
            evidenceVersion: evidenceVersion,
            checkpoint: checkpoint,
            sampleRate: sampleRate,
            hardGatesPassed: hardGatesPassed ?? self.hardGatesPassed,
            liveMaster: liveMaster,
            metrics: metrics.map {
                $0.metric == metric
                    ? ProfessionalQualityMetricValue(metric: metric, value: value)
                    : $0
            }
        )
    }

    package func replacingLiveMaster(
        _ provenance: ProfessionalQualityLiveMasterProvenance
    ) throws -> ProfessionalQualityObservation {
        try ProfessionalQualityObservation(
            engineVersion: engineVersion,
            evidenceVersion: evidenceVersion,
            checkpoint: checkpoint,
            sampleRate: sampleRate,
            hardGatesPassed: hardGatesPassed,
            liveMaster: provenance,
            metrics: metrics
        )
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    package static func decodeDeterministicJSON(
        _ data: Data
    ) throws -> ProfessionalQualityObservation {
        // Observations are transient projections of complete candidate
        // evidence. Profiles and reason-coded suites persist their reductions;
        // an independently serialized live provenance is never a trusted input.
        throw ProfessionalQualityCalibrationError.profileMismatch
    }

    package init(from decoder: any Decoder) throws {
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription:
                    "Professional observations must be candidate-derived"
            )
        )
    }

}

package struct ProfessionalQualityMetricBounds: Codable, Equatable, Sendable {
    package let metric: ProfessionalQualityMetric
    package let lower: Double
    package let upper: Double

    package init(
        metric: ProfessionalQualityMetric,
        lower: Double,
        upper: Double
    ) throws {
        guard lower.isFinite, upper.isFinite, lower <= upper else {
            throw ProfessionalQualityCalibrationError.invalidBounds
        }
        self.metric = metric
        self.lower = lower
        self.upper = upper
    }

    package func contains(_ value: Double) -> Bool {
        guard value.isFinite else { return false }
        if metric.acceptsSaferValuesBelowCalibration {
            return value >= metric.semanticMinimum && value <= upper
        }
        return (lower...upper).contains(value)
    }
}

package enum ProfessionalQualityTrajectory: String, CaseIterable, Codable,
        Sendable {
    case establishmentToChapterChange = "establishment-to-chapter-change"
    case establishmentToContrast = "establishment-to-contrast"
    case establishmentToMajorBreak = "establishment-to-major-break"
    case majorBreakToRelease = "major-break-to-release"
    case establishmentToIdentityReturn = "establishment-to-identity-return"
    case establishmentToLongContinuation =
        "establishment-to-long-continuation"

    package var checkpoints: (
        from: CanonicalJourneyCheckpoint,
        to: CanonicalJourneyCheckpoint
    ) {
        switch self {
        case .establishmentToChapterChange:
            return (.establishment, .chapterChange)
        case .establishmentToContrast:
            return (.establishment, .contrast)
        case .establishmentToMajorBreak:
            return (.establishment, .majorBreak)
        case .majorBreakToRelease:
            return (.majorBreak, .release)
        case .establishmentToIdentityReturn:
            return (.establishment, .identityReturn)
        case .establishmentToLongContinuation:
            return (.establishment, .longContinuation)
        }
    }
}

package struct ProfessionalQualityTrajectoryBounds: Codable, Equatable,
        Sendable {
    package let trajectory: ProfessionalQualityTrajectory
    package let metric: ProfessionalQualityMetric
    package let lowerDelta: Double
    package let upperDelta: Double

    package init(
        trajectory: ProfessionalQualityTrajectory,
        metric: ProfessionalQualityMetric,
        lowerDelta: Double,
        upperDelta: Double
    ) throws {
        guard lowerDelta.isFinite, upperDelta.isFinite,
              lowerDelta <= upperDelta else {
            throw ProfessionalQualityCalibrationError.invalidBounds
        }
        self.trajectory = trajectory
        self.metric = metric
        self.lowerDelta = lowerDelta
        self.upperDelta = upperDelta
    }
}

package struct ProfessionalQualityRateConsistencyBounds: Codable, Equatable,
        Sendable {
    package let checkpoint: CanonicalJourneyCheckpoint
    package let metric: ProfessionalQualityMetric
    package let maximumAbsoluteDelta: Double

    package init(
        checkpoint: CanonicalJourneyCheckpoint,
        metric: ProfessionalQualityMetric,
        maximumAbsoluteDelta: Double
    ) throws {
        guard maximumAbsoluteDelta.isFinite, maximumAbsoluteDelta >= 0 else {
            throw ProfessionalQualityCalibrationError.invalidBounds
        }
        self.checkpoint = checkpoint
        self.metric = metric
        self.maximumAbsoluteDelta = maximumAbsoluteDelta
    }
}

package struct ProfessionalQualityCheckpointProfile: Codable, Equatable, Sendable {
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sourceObservationCount: Int
    package let bounds: [ProfessionalQualityMetricBounds]

    package init(
        checkpoint: CanonicalJourneyCheckpoint,
        sourceObservationCount: Int,
        bounds sourceBounds: [ProfessionalQualityMetricBounds]
    ) throws {
        let sorted = sourceBounds.sorted { $0.metric.rawValue < $1.metric.rawValue }
        guard sourceObservationCount >= 2,
              sorted.count == ProfessionalQualityMetric.allCases.count,
              Set(sorted.map(\.metric)).count == sorted.count else {
            throw ProfessionalQualityCalibrationError.invalidMetricSet
        }
        self.checkpoint = checkpoint
        self.sourceObservationCount = sourceObservationCount
        bounds = sorted
    }

    package subscript(metric: ProfessionalQualityMetric) -> ProfessionalQualityMetricBounds? {
        bounds.first { $0.metric == metric }
    }

    package var isComplete: Bool {
        sourceObservationCount >= 2 &&
            bounds.count == ProfessionalQualityMetric.allCases.count &&
            Set(bounds.map(\.metric)).count == bounds.count &&
            bounds == bounds.sorted { $0.metric.rawValue < $1.metric.rawValue } &&
            bounds.allSatisfy {
                $0.lower.isFinite && $0.upper.isFinite && $0.lower <= $0.upper
            }
    }
}

package struct ProfessionalQualityCalibrationProfile: Codable, Equatable, Sendable {
    package static let schemaVersion = 11
    package static let profileVersion =
        "autotechno-professional-quality-profile.v11"
    package static let requiredSampleRates = [44_100.0, 48_000.0]
    package static let minimumCalibrationTrajectoryCount = 24

    package let schemaVersion: Int
    package let profileVersion: String
    package let observationVersion: String
    package let evidenceVersion: String
    package let engineVersion: String
    package let sourceBankFingerprint: String
    package let sampleRates: [Double]
    package let checkpoints: [ProfessionalQualityCheckpointProfile]
    package let trajectories: [ProfessionalQualityTrajectoryBounds]
    package let rateConsistency: [ProfessionalQualityRateConsistencyBounds]

    package init(bank: ProfessionalEvidenceReportBank) throws {
        guard bank.evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion,
              !bank.engineVersion.isEmpty else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        guard bank.sampleRates == Self.requiredSampleRates else {
            throw ProfessionalQualityCalibrationError.incompleteRepresentativeRates
        }
        let observations = try bank.reports.map(ProfessionalQualityObservation.init)
        try self.init(
            engineVersion: bank.engineVersion,
            evidenceVersion: bank.evidenceVersion,
            sourceBankFingerprint: try Self.fingerprint(
                of: bank.deterministicJSON()
            ),
            sampleRates: bank.sampleRates,
            observations: observations
        )
    }

    /// Current calibration path. Every metric envelope is learned across
    /// several complete canonical journeys while preserving journey identity
    /// for phrase-wide and rate-consistency relationships.
    package init(corpus: ProfessionalQualityCalibrationCorpus) throws {
        guard corpus.isComplete,
              corpus.sourceTrajectoryCount >=
                Self.minimumCalibrationTrajectoryCount,
              corpus.sampleRates == Self.requiredSampleRates,
              !corpus.fingerprint.isEmpty else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }

        var profiles: [ProfessionalQualityCheckpointProfile] = []
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            let sources = corpus.trajectories.flatMap { trajectory in
                trajectory.observations.filter { $0.checkpoint == checkpoint }
            }
            guard sources.count == corpus.sourceTrajectoryCount *
                    Self.requiredSampleRates.count else {
                throw ProfessionalQualityCalibrationError
                    .incompleteCheckpointCoverage
            }
            var metricBounds: [ProfessionalQualityMetricBounds] = []
            for metric in ProfessionalQualityMetric.allCases {
                let values = sources.compactMap { $0[metric] }
                guard values.count == sources.count,
                      let minimum = values.min(),
                      let maximum = values.max() else {
                    throw ProfessionalQualityCalibrationError.invalidMetricSet
                }
                let crossRateDrifts = try corpus.trajectories.map {
                    trajectory -> Double in
                    let values = trajectory.observations
                        .filter { $0.checkpoint == checkpoint }
                        .compactMap { $0[metric] }
                    guard values.count == Self.requiredSampleRates.count,
                          let minimum = values.min(),
                          let maximum = values.max() else {
                        throw ProfessionalQualityCalibrationError
                            .incompleteCheckpointCoverage
                    }
                    return maximum - minimum
                }
                let guardBand = Self.diverseGuardBand(
                    metric: metric,
                    values: values,
                    crossRateDrifts: crossRateDrifts
                )
                let domain = Self.domain(for: metric)
                metricBounds.append(try ProfessionalQualityMetricBounds(
                    metric: metric,
                    lower: max(domain.lowerBound, minimum - guardBand),
                    upper: min(domain.upperBound, maximum + guardBand)
                ))
            }
            profiles.append(try ProfessionalQualityCheckpointProfile(
                checkpoint: checkpoint,
                sourceObservationCount: sources.count,
                bounds: metricBounds
            ))
        }

        var trajectoryBounds: [ProfessionalQualityTrajectoryBounds] = []
        for trajectoryKind in ProfessionalQualityTrajectory.allCases {
            let pair = trajectoryKind.checkpoints
            for metric in ProfessionalQualityMetric.allCases {
                var deltas: [Double] = []
                var crossRateDrifts: [Double] = []
                for trajectory in corpus.trajectories {
                    let trajectoryDeltas = try Self.metricDeltas(
                        trajectory: trajectory,
                        from: pair.from,
                        to: pair.to,
                        metric: metric
                    )
                    deltas.append(contentsOf: trajectoryDeltas)
                    guard let minimum = trajectoryDeltas.min(),
                          let maximum = trajectoryDeltas.max() else {
                        throw ProfessionalQualityCalibrationError
                            .invalidMetricSet
                    }
                    crossRateDrifts.append(maximum - minimum)
                }
                guard let minimum = deltas.min(),
                      let maximum = deltas.max() else {
                    throw ProfessionalQualityCalibrationError.invalidMetricSet
                }
                let guardBand = Self.diverseGuardBand(
                    metric: metric,
                    values: deltas,
                    crossRateDrifts: crossRateDrifts
                )
                trajectoryBounds.append(try ProfessionalQualityTrajectoryBounds(
                    trajectory: trajectoryKind,
                    metric: metric,
                    lowerDelta: minimum - guardBand,
                    upperDelta: maximum + guardBand
                ))
            }
        }

        var rateBounds: [ProfessionalQualityRateConsistencyBounds] = []
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            for metric in ProfessionalQualityMetric.allCases {
                let absoluteDeltas = try corpus.trajectories.map {
                    trajectory -> Double in
                    let values = trajectory.observations
                        .filter { $0.checkpoint == checkpoint }
                        .compactMap { $0[metric] }
                    guard values.count == Self.requiredSampleRates.count,
                          let minimum = values.min(),
                          let maximum = values.max() else {
                        throw ProfessionalQualityCalibrationError
                            .incompleteCheckpointCoverage
                    }
                    return maximum - minimum
                }
                guard let maximum = absoluteDeltas.max() else {
                    throw ProfessionalQualityCalibrationError.invalidMetricSet
                }
                let guardBand = Self.diverseGuardBand(
                    metric: metric,
                    values: absoluteDeltas,
                    crossRateDrifts: []
                )
                rateBounds.append(try ProfessionalQualityRateConsistencyBounds(
                    checkpoint: checkpoint,
                    metric: metric,
                    maximumAbsoluteDelta: maximum + guardBand
                ))
            }
        }

        schemaVersion = Self.schemaVersion
        profileVersion = Self.profileVersion
        observationVersion = ProfessionalQualityObservation.observationVersion
        evidenceVersion = corpus.evidenceVersion
        engineVersion = corpus.engineVersion
        sourceBankFingerprint = corpus.fingerprint
        sampleRates = corpus.sampleRates
        checkpoints = profiles
        trajectories = trajectoryBounds
        rateConsistency = rateBounds
    }

    /// Reduced single-journey seam for deterministic metric unit tests. It
    /// accepts no PCM and cannot activate the primary evaluator because it is
    /// not a diverse calibration. Shipping profile generation uses the corpus
    /// initializer above.
    package init(
        engineVersion: String,
        evidenceVersion: String = ProfessionalEvidenceReportBank.evidenceVersion,
        sourceBankFingerprint: String,
        sampleRates: [Double],
        observations: [ProfessionalQualityObservation]
    ) throws {
        guard !engineVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
              evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion,
              !sourceBankFingerprint.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              observations.allSatisfy({
                  $0.isComplete && $0.engineVersion == engineVersion &&
                      $0.evidenceVersion == evidenceVersion
              }) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        guard sampleRates == Self.requiredSampleRates,
              observations.count == sampleRates.count *
                CanonicalJourneyCheckpoint.allCases.count else {
            throw ProfessionalQualityCalibrationError.incompleteRepresentativeRates
        }
        var profiles: [ProfessionalQualityCheckpointProfile] = []
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            let sources = observations.filter { $0.checkpoint == checkpoint }
            guard sources.count == Self.requiredSampleRates.count,
                  sources.map(\.sampleRate).sorted() == Self.requiredSampleRates else {
                throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
            }
            var metricBounds: [ProfessionalQualityMetricBounds] = []
            for metric in ProfessionalQualityMetric.allCases {
                let values = sources.compactMap { $0[metric] }
                guard values.count == sources.count,
                      let minimum = values.min(), let maximum = values.max() else {
                    throw ProfessionalQualityCalibrationError.invalidMetricSet
                }
                let guardBand = Self.guardBand(
                    metric: metric,
                    values: values,
                    minimum: minimum,
                    maximum: maximum
                )
                let domain = Self.domain(for: metric)
                metricBounds.append(try ProfessionalQualityMetricBounds(
                    metric: metric,
                    lower: max(domain.lowerBound, minimum - guardBand),
                    upper: min(domain.upperBound, maximum + guardBand)
                ))
            }
            profiles.append(try ProfessionalQualityCheckpointProfile(
                checkpoint: checkpoint,
                sourceObservationCount: sources.count,
                bounds: metricBounds
            ))
        }
        var trajectoryBounds: [ProfessionalQualityTrajectoryBounds] = []
        for trajectory in ProfessionalQualityTrajectory.allCases {
            let pair = trajectory.checkpoints
            for metric in ProfessionalQualityMetric.allCases {
                let deltas = try sampleRates.map { sampleRate -> Double in
                    guard let from = observations.first(where: {
                        $0.sampleRate == sampleRate &&
                            $0.checkpoint == pair.from
                    })?[metric],
                          let to = observations.first(where: {
                              $0.sampleRate == sampleRate &&
                                  $0.checkpoint == pair.to
                          })?[metric] else {
                        throw ProfessionalQualityCalibrationError
                            .incompleteCheckpointCoverage
                    }
                    return to - from
                }
                guard let minimum = deltas.min(), let maximum = deltas.max() else {
                    throw ProfessionalQualityCalibrationError.invalidMetricSet
                }
                let guardBand = Self.guardBand(
                    metric: metric,
                    values: deltas,
                    minimum: minimum,
                    maximum: maximum
                )
                trajectoryBounds.append(try ProfessionalQualityTrajectoryBounds(
                    trajectory: trajectory,
                    metric: metric,
                    lowerDelta: minimum - guardBand,
                    upperDelta: maximum + guardBand
                ))
            }
        }
        var rateBounds: [ProfessionalQualityRateConsistencyBounds] = []
        for checkpoint in CanonicalJourneyCheckpoint.allCases {
            let sources = observations.filter { $0.checkpoint == checkpoint }
            for metric in ProfessionalQualityMetric.allCases {
                let values = sources.compactMap { $0[metric] }
                guard values.count == sampleRates.count,
                      let minimum = values.min(), let maximum = values.max() else {
                    throw ProfessionalQualityCalibrationError.invalidMetricSet
                }
                let guardBand = Self.guardBand(
                    metric: metric,
                    values: values,
                    minimum: minimum,
                    maximum: maximum
                )
                rateBounds.append(try ProfessionalQualityRateConsistencyBounds(
                    checkpoint: checkpoint,
                    metric: metric,
                    maximumAbsoluteDelta: maximum - minimum + guardBand
                ))
            }
        }
        schemaVersion = Self.schemaVersion
        profileVersion = Self.profileVersion
        observationVersion = ProfessionalQualityObservation.observationVersion
        self.evidenceVersion = evidenceVersion
        self.engineVersion = engineVersion
        self.sourceBankFingerprint = sourceBankFingerprint
        self.sampleRates = sampleRates
        checkpoints = profiles
        trajectories = trajectoryBounds
        rateConsistency = rateBounds
    }

    package var isComplete: Bool {
        let expectedObservationCount = sourceTrajectoryCount *
            Self.requiredSampleRates.count
        return schemaVersion == Self.schemaVersion &&
            profileVersion == Self.profileVersion &&
            observationVersion == ProfessionalQualityObservation.observationVersion &&
            evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion &&
            !engineVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty &&
            !sourceBankFingerprint.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty &&
            sampleRates == Self.requiredSampleRates &&
            checkpoints.map(\.checkpoint) == CanonicalJourneyCheckpoint.allCases &&
            checkpoints.allSatisfy {
                $0.sourceObservationCount == expectedObservationCount &&
                    $0.isComplete && $0.bounds.allSatisfy { bounds in
                        let domain = Self.domain(for: bounds.metric)
                        return bounds.lower >= domain.lowerBound &&
                            bounds.upper <= domain.upperBound
                    }
            } &&
            trajectories.count == ProfessionalQualityTrajectory.allCases.count *
                ProfessionalQualityMetric.allCases.count &&
            trajectories.map {
                "\($0.trajectory.rawValue):\($0.metric.rawValue)"
            } == ProfessionalQualityTrajectory.allCases.flatMap { trajectory in
                ProfessionalQualityMetric.allCases.map {
                    "\(trajectory.rawValue):\($0.rawValue)"
                }
            } &&
            Set(trajectories.map {
                "\($0.trajectory.rawValue):\($0.metric.rawValue)"
            }).count == trajectories.count &&
            trajectories.allSatisfy {
                $0.lowerDelta.isFinite && $0.upperDelta.isFinite &&
                    $0.lowerDelta <= $0.upperDelta
            } &&
            rateConsistency.count == CanonicalJourneyCheckpoint.allCases.count *
                ProfessionalQualityMetric.allCases.count &&
            rateConsistency.map {
                "\($0.checkpoint.rawValue):\($0.metric.rawValue)"
            } == CanonicalJourneyCheckpoint.allCases.flatMap { checkpoint in
                ProfessionalQualityMetric.allCases.map {
                    "\(checkpoint.rawValue):\($0.rawValue)"
                }
            } &&
            Set(rateConsistency.map {
                "\($0.checkpoint.rawValue):\($0.metric.rawValue)"
            }).count == rateConsistency.count &&
            rateConsistency.allSatisfy {
                $0.maximumAbsoluteDelta.isFinite &&
                    $0.maximumAbsoluteDelta >= 0
            } &&
            sourceTrajectoryCount > 0
    }

    package var sourceTrajectoryCount: Int {
        guard let count = checkpoints.first?.sourceObservationCount,
              count.isMultiple(of: Self.requiredSampleRates.count) else {
            return 0
        }
        return count / Self.requiredSampleRates.count
    }

    package var usesDiverseCalibration: Bool {
        schemaVersion == Self.schemaVersion &&
            profileVersion == Self.profileVersion &&
            sourceTrajectoryCount >= Self.minimumCalibrationTrajectoryCount
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    package static func decodeDeterministicJSON(
        _ data: Data
    ) throws -> ProfessionalQualityCalibrationProfile {
        let decoded = try JSONDecoder().decode(
            ProfessionalQualityCalibrationProfile.self,
            from: data
        )
        guard decoded.isComplete,
              try decoded.deterministicJSON() == data else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return decoded
    }

    package var fingerprint: String {
        return (try? Self.fingerprint(
            of: deterministicJSON(),
            domain: "professional-quality-calibration-json.v3"
        )) ?? ""
    }

    package subscript(
        checkpoint: CanonicalJourneyCheckpoint
    ) -> ProfessionalQualityCheckpointProfile? {
        checkpoints.first { $0.checkpoint == checkpoint }
    }

    private static func guardBand(
        metric: ProfessionalQualityMetric,
        values: [Double],
        minimum: Double,
        maximum: Double
    ) -> Double {
        let centerMagnitude = abs(values.reduce(0, +) / Double(values.count))
        let observedRateDrift = maximum - minimum
        let absoluteFloor: Double
        switch metric {
        case .integratedLoudnessLUFS, .maximumMomentaryLoudnessLUFS,
                .maximumShortTermLoudnessLUFS, .loudnessRangeLU,
                .truePeakDBTP, .crestFactorDB, .rmsTrajectoryDeltaMeanDB,
                .rmsTrajectoryDeltaPeakDB, .barLoudnessSpanLU,
                .kickOverFoundationActiveDBMean,
                .kickAudibleToDetectorDBMean,
                .foundationDottedRhythmCrestFactorDBMean:
            absoluteFloor = 0.75
        case .spectralCentroidMeanHz, .spectralCentroidSpreadHz,
                .spectralBandwidthMeanHz, .spectralRolloff85MeanHz,
                .barCentroidSpanHz:
            absoluteFloor = 120
        case .maximumBoundaryDelta, .absoluteDCOffset:
            absoluteFloor = 0.002
        case .maskingOverlapWindowRatio, .maskingLongestRunRatio:
            absoluteFloor = 1 / Double(
                SpectrumMaskingAnalyzer.analyzedWindowCount
            )
        case .barTransientDensityMean, .barTransientDensitySpan:
            absoluteFloor = transientDensityQuantizationFloor
        case .kickEventCountMean:
            absoluteFloor = 0.25
        case .modalPercussionEventCountMean,
                .modalPercussionActiveBarRatio:
            absoluteFloor = 0.25
        case .padHarmonicDisclosureDistinctFunctionCount:
            absoluteFloor = 1
        case .modalPercussionPitchErrorCentsMaximum:
            absoluteFloor = 15
        case .modalPercussionAttackToBodyDBMean,
                .modalPercussionTailToBodyDBMean,
                .upperPercussionTailRenderedTailToAttackDBMean,
                .padRhythmicFilterDifferenceToPadDBMean,
                .padRhythmicSpatialDifferenceToSendDBMean:
            absoluteFloor = 1
        case .modalPercussionSpectralCentroidMeanHz:
            absoluteFloor = 60
        case .modalPercussionMaximumPoleRadius:
            absoluteFloor = 0.000_5
        case .foundationPreKickPocketSilenceRMSMaximum:
            absoluteFloor = 0.000_001
        default:
            absoluteFloor = 0.04
        }
        return max(absoluteFloor, observedRateDrift * 2, centerMagnitude * 0.08)
    }

    /// Transient density counts discrete events per second. At fixed 130 BPM,
    /// one changed event in one four-beat bar is the smallest physically
    /// meaningful difference; representative-rate frame rounding makes the
    /// exact resolution slightly rate-dependent.
    private static var transientDensityQuantizationFloor: Double {
        let barSeconds = 4 * 60 / AutonomousSessionDirector.bpm
        return requiredSampleRates.map { sampleRate in
            let frameCount = max(
                1,
                Int((barSeconds * sampleRate).rounded())
            )
            return sampleRate / Double(frameCount)
        }.max() ?? 0
    }

    /// A multi-journey envelope already includes the observed min/max musical
    /// diversity. Its extrapolation margin is therefore based on one observed
    /// spread plus the worst same-journey rate drift, rather
    /// than treating cross-journey variation as if it were measurement error.
    private static func diverseGuardBand(
        metric: ProfessionalQualityMetric,
        values: [Double],
        crossRateDrifts: [Double]
    ) -> Double {
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0
        }
        let centerMagnitude = abs(values.reduce(0, +) / Double(values.count))
        let observedSpread = maximum - minimum
        let maximumRateDrift = crossRateDrifts.max() ?? 0
        let absoluteFloor = guardBand(
            metric: metric,
            values: [0],
            minimum: 0,
            maximum: 0
        )
        return max(
            absoluteFloor,
            observedSpread,
            maximumRateDrift * 2,
            centerMagnitude * 0.08
        )
    }

    private static func metricDeltas(
        trajectory: ProfessionalQualityCalibrationTrajectory,
        from: CanonicalJourneyCheckpoint,
        to: CanonicalJourneyCheckpoint,
        metric: ProfessionalQualityMetric
    ) throws -> [Double] {
        try requiredSampleRates.map { sampleRate in
            guard let fromValue = trajectory.observations.first(where: {
                $0.sampleRate == sampleRate && $0.checkpoint == from
            })?[metric],
                  let toValue = trajectory.observations.first(where: {
                      $0.sampleRate == sampleRate && $0.checkpoint == to
                  })?[metric] else {
                throw ProfessionalQualityCalibrationError
                    .incompleteCheckpointCoverage
            }
            return toValue - fromValue
        }
    }

    private static func domain(
        for metric: ProfessionalQualityMetric
    ) -> ClosedRange<Double> {
        switch metric {
        case .integratedLoudnessLUFS, .maximumMomentaryLoudnessLUFS,
                .maximumShortTermLoudnessLUFS:
            return -120...24
        case .truePeakDBTP:
            return -120...0
        case .absoluteDCOffset, .maximumBoundaryDelta,
                .movementScore, .activeWindowRatio, .spectralFlatnessMean,
                .positiveSpectralFluxMean, .positiveSpectralFluxPeak,
                .maskingMaximumOverlap, .maskingOverlapWindowRatio,
                .maskingLongestRunRatio, .activeKickFoundationBarRatio,
                .kickGroundedBarRatio, .kickWithheldBarRatio,
                .kickRecoveryBarRatio, .kickDuckingEnvelopeRatioMean,
                .kickAudibleGainMean, .modalPercussionActiveBarRatio,
                .kickSourceUpperMidEnergyRatioMean,
                .foundationDottedRhythmActiveBarRatio,
                .foundationPreKickPocketSilenceRMSMaximum,
                .modalPercussionMaskingMaximumOverlap,
                .modalPercussionMaximumPoleRadius,
                .upperPercussionTailClearanceEventRatio,
                .upperSpectralRevealActiveEventRatio,
                .upperSpectralRevealAppliedCutoffRatioMean,
                .percussionAnticipationSwellActiveBarRatio,
                .padRhythmicModulationActiveBarRatio,
                .padHarmonicDisclosureRevealedBarRatio:
            return 0...1
        case .stereoCorrelation, .lowStereoCorrelation:
            return -1...1
        case .spectralCentroidMeanHz, .spectralCentroidSpreadHz,
                .spectralBandwidthMeanHz, .spectralRolloff85MeanHz,
                .barCentroidSpanHz,
                .modalPercussionSpectralCentroidMeanHz:
            return 0...(QualityQualificationContract.maximumSupportedSampleRate / 2)
        case .loudnessRangeLU, .crestFactorDB,
                .rmsTrajectoryDeltaMeanDB, .rmsTrajectoryDeltaPeakDB,
                .barLoudnessSpanLU, .barTransientDensityMean,
                .barTransientDensitySpan, .barCrestFactorMean,
                .barCrestFactorSpan,
                .foundationDottedRhythmCrestFactorDBMean,
                .kickSourceOutputCrestFactorDBMean:
            return 0...120
        case .kickOverFoundationActiveDBMean:
            return -120...120
        case .modalPercussionAttackToBodyDBMean,
                .modalPercussionTailToBodyDBMean,
                .upperPercussionTailRenderedTailToAttackDBMean,
                .percussionAnticipationSwellLateToEarlyDBMean,
                .padRhythmicFilterDifferenceToPadDBMean,
                .padRhythmicSpatialDifferenceToSendDBMean,
                .kickSourceAttackToBodyDBMean,
                .kickSourceCrestReductionDBMean:
            return -120...120
        case .kickAudibleToDetectorDBMean:
            return -120...0
        case .kickEventCountMean:
            return 0...16
        case .modalPercussionEventCountMean:
            return 0...2
        case .modalPercussionPitchErrorCentsMaximum:
            return 0...1_200
        case .padHarmonicDisclosureDistinctFunctionCount:
            return 0...Double(PadHarmonicFunction.allCases.count)
        }
    }

    private static func fingerprint(
        of data: Data,
        domain: String = "professional-quality-calibration-source-bank-json.v4"
    ) throws -> String {
        guard let string = String(data: data, encoding: .utf8) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        var sink = StreamingFNV1a()
        sink.domain(domain)
        sink.string(string)
        return fixedWidthFingerprintHex(sink.value)
    }
}

package enum ProfessionalQualityRejection: String, Codable, Hashable, Sendable {
    case profileMismatch = "profile-mismatch"
    case hardGateFailure = "hard-gate-failure"
    case incompleteObservation = "incomplete-observation"
    case metricOutOfRange = "metric-out-of-range"
    case trajectoryRelationshipFailed = "trajectory-relationship-failed"
    case rateConsistencyFailed = "rate-consistency-failed"
    case liveControllerMismatch = "live-controller-mismatch"
    case liveProposalMismatch = "live-proposal-mismatch"
    case liveTerminalScalingFailure = "live-terminal-scaling-failure"
    case liveBoostRejected = "live-boost-rejected"
    case liveTransitionOutOfBounds = "live-transition-out-of-bounds"
    case liveEarlyRecovery = "live-early-recovery"
    case liveRouteBoundaryFailure = "live-route-boundary-failure"
}

package struct ProfessionalQualityVerdict: Codable, Equatable, Sendable {
    package let accepted: Bool
    package let reasons: [ProfessionalQualityRejection]
    package let failedMetrics: [ProfessionalQualityMetric]
}

package enum ProfessionalQualityRelationshipFailureKind: String, Codable,
        Sendable {
    case trajectory = "trajectory"
    case rateConsistency = "rate-consistency"
}

package struct ProfessionalQualityRelationshipFailure: Codable, Equatable,
        Sendable {
    package let kind: ProfessionalQualityRelationshipFailureKind
    package let trajectory: ProfessionalQualityTrajectory?
    package let checkpoint: CanonicalJourneyCheckpoint?
    package let metric: ProfessionalQualityMetric
    package let observedDelta: Double
    package let lowerBound: Double
    package let upperBound: Double
}

package enum ProfessionalQualityRelationshipEvaluator {
    package static func evaluate(
        observations: [ProfessionalQualityObservation],
        against profile: ProfessionalQualityCalibrationProfile
    ) -> [ProfessionalQualityRelationshipFailure] {
        guard profile.isComplete else { return [] }
        var failures: [ProfessionalQualityRelationshipFailure] = []
        for bounds in profile.trajectories
            where bounds.metric.participatesInQualification {
            let pair = bounds.trajectory.checkpoints
            for sampleRate in profile.sampleRates {
                guard let from = observations.first(where: {
                    $0.sampleRate == sampleRate && $0.checkpoint == pair.from
                })?[bounds.metric],
                      let to = observations.first(where: {
                          $0.sampleRate == sampleRate && $0.checkpoint == pair.to
                      })?[bounds.metric] else { continue }
                let delta = to - from
                if !(bounds.lowerDelta...bounds.upperDelta).contains(delta) {
                    failures.append(ProfessionalQualityRelationshipFailure(
                        kind: .trajectory,
                        trajectory: bounds.trajectory,
                        checkpoint: nil,
                        metric: bounds.metric,
                        observedDelta: delta,
                        lowerBound: bounds.lowerDelta,
                        upperBound: bounds.upperDelta
                    ))
                }
            }
        }
        for bounds in profile.rateConsistency
            where bounds.metric.participatesInQualification {
            let values = profile.sampleRates.compactMap { sampleRate in
                observations.first {
                    $0.sampleRate == sampleRate &&
                        $0.checkpoint == bounds.checkpoint
                }?[bounds.metric]
            }
            guard let minimum = values.min(), let maximum = values.max(),
                  values.count == profile.sampleRates.count else { continue }
            let delta = maximum - minimum
            if delta > bounds.maximumAbsoluteDelta {
                failures.append(ProfessionalQualityRelationshipFailure(
                    kind: .rateConsistency,
                    trajectory: nil,
                    checkpoint: bounds.checkpoint,
                    metric: bounds.metric,
                    observedDelta: delta,
                    lowerBound: 0,
                    upperBound: bounds.maximumAbsoluteDelta
                ))
            }
        }
        return failures.sorted { left, right in
            let leftKey = [
                left.kind.rawValue,
                left.trajectory?.rawValue ?? "",
                left.checkpoint?.rawValue ?? "",
                left.metric.rawValue,
                String(left.observedDelta.bitPattern),
            ].joined(separator: ":")
            let rightKey = [
                right.kind.rawValue,
                right.trajectory?.rawValue ?? "",
                right.checkpoint?.rawValue ?? "",
                right.metric.rawValue,
                String(right.observedDelta.bitPattern),
            ].joined(separator: ":")
            return leftKey < rightKey
        }
    }
}

package enum ProfessionalQualityProfileEvaluator {
    package static func evaluate(
        _ observation: ProfessionalQualityObservation,
        against profile: ProfessionalQualityCalibrationProfile
    ) -> ProfessionalQualityVerdict {
        var reasons = Set<ProfessionalQualityRejection>()
        var failed = Set<ProfessionalQualityMetric>()
        guard profile.isComplete,
              observation.evidenceVersion == profile.evidenceVersion,
              profile.sampleRates.contains(observation.sampleRate),
              let checkpoint = profile[observation.checkpoint] else {
            return ProfessionalQualityVerdict(
                accepted: false,
                reasons: [.profileMismatch],
                failedMetrics: []
            )
        }
        if !observation.isComplete {
            reasons.insert(.incompleteObservation)
        }
        if !observation.hardGatesPassed {
            reasons.insert(.hardGateFailure)
        }
        let live = observation.liveMaster
        if !live.isComplete || live.controllerPolicyVersion !=
            LiveFeedbackContract.controllerPolicyVersion ||
            (!live.controllerTransitionValid && !live.recoveryIsEarly &&
                !live.exceedsTransitionSlew) {
            reasons.insert(.liveControllerMismatch)
        }
        if !live.proposalBindingValid {
            reasons.insert(.liveProposalMismatch)
        }
        if !live.preTrimBindingValid || !live.postTrimBindingValid ||
            !live.terminalScalingValid || !live.terminalScaleIsValid {
            reasons.insert(.liveTerminalScalingFailure)
        }
        if live.boostsAboveUnity {
            reasons.insert(.liveBoostRejected)
        }
        if live.exceedsTransitionSlew {
            reasons.insert(.liveTransitionOutOfBounds)
        }
        if live.recoveryIsEarly {
            reasons.insert(.liveEarlyRecovery)
        }
        if !live.routeAndBoundaryAreValid {
            reasons.insert(.liveRouteBoundaryFailure)
        }
        for metric in ProfessionalQualityMetric.allCases
            where metric.participatesInQualification {
            guard let value = observation[metric],
                  let bounds = checkpoint[metric],
                  bounds.contains(value) else {
                reasons.insert(.metricOutOfRange)
                failed.insert(metric)
                continue
            }
        }
        let sortedReasons = reasons.sorted { $0.rawValue < $1.rawValue }
        let sortedMetrics = failed.sorted { $0.rawValue < $1.rawValue }
        return ProfessionalQualityVerdict(
            accepted: sortedReasons.isEmpty,
            reasons: sortedReasons,
            failedMetrics: sortedMetrics
        )
    }
}
