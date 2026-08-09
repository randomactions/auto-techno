import AutoTechnoCore
import Foundation

package enum ProfessionalQualityCalibrationError: Error, Equatable, Sendable {
    case invalidIdentity
    case incompleteEvidence
    case incompleteRepresentativeRates
    case incompleteCheckpointCoverage
    case duplicateMetric
    case invalidMetricSet
    case invalidBounds
    case profileMismatch
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
}

package struct ProfessionalQualityMetricValue: Codable, Equatable, Sendable {
    package let metric: ProfessionalQualityMetric
    package let value: Double

    package init(metric: ProfessionalQualityMetric, value: Double) {
        self.metric = metric
        self.value = value
    }
}

/// A bounded, non-reconstructable projection of one selected phrase. It carries
/// no PCM, stems, event lists, or sample hashes.
package struct ProfessionalQualityObservation: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package static let observationVersion =
        "autotechno-professional-quality-observation.v1"

    package let schemaVersion: Int
    package let observationVersion: String
    package let engineVersion: String
    package let evidenceVersion: String
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let hardGatesPassed: Bool
    package let sourceMetricCount: Int
    package let metrics: [ProfessionalQualityMetricValue]

    package init(
        engineVersion: String,
        evidenceVersion: String = ProfessionalEvidenceReportBank.evidenceVersion,
        checkpoint: CanonicalJourneyCheckpoint,
        sampleRate: Double,
        hardGatesPassed: Bool,
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
        guard sorted.allSatisfy({ $0.value.isFinite }) else {
            throw ProfessionalQualityCalibrationError.incompleteEvidence
        }
        schemaVersion = Self.schemaVersion
        observationVersion = Self.observationVersion
        self.engineVersion = engineVersion
        self.evidenceVersion = evidenceVersion
        self.checkpoint = checkpoint
        self.sampleRate = sampleRate
        self.hardGatesPassed = hardGatesPassed
        sourceMetricCount = sourceMetrics.count
        metrics = sorted
    }

    package init(report: CanonicalJourneyQualificationReport) throws {
        let vector = report.selectedCandidateEvidence
        guard vector.isComplete, vector.isFinite,
              report.evidenceScope ==
                CanonicalJourneyQualificationReport.currentEvidenceScope else {
            throw ProfessionalQualityCalibrationError.incompleteEvidence
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
            return 20 * log10(numerator / denominator)
        }

        let masking = vector.masking.flatMap(\.observations)
        let maskingAnalyzedWindows = masking.reduce(0) {
            $0 + $1.analyzedWindowCount
        }
        let maskingOverlapWindows = masking.reduce(0) {
            $0 + $1.overlapWindowCount
        }
        let maskingLongestRun = masking.map(\.longestOverlapRun).max() ?? 0

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
        ]
        try self.init(
            engineVersion: report.engineVersion,
            checkpoint: report.checkpoint,
            sampleRate: report.sampleRate,
            hardGatesPassed: vector.hardGatesPassed,
            metrics: metrics
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
            metrics.allSatisfy { $0.value.isFinite }
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
            metrics: metrics.map {
                $0.metric == metric
                    ? ProfessionalQualityMetricValue(metric: metric, value: value)
                    : $0
            }
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
        value.isFinite && (lower...upper).contains(value)
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
    package static let schemaVersion = 1
    package static let profileVersion =
        "autotechno-professional-quality-profile.v1"
    package static let requiredSampleRates = [44_100.0, 48_000.0]

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

    /// Offline calibration seam for already reduced observations. It accepts no
    /// PCM and requires the same complete checkpoint/rate matrix as a report
    /// bank. Production profile generation uses the bank initializer above.
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
        schemaVersion == Self.schemaVersion &&
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
                $0.sourceObservationCount == Self.requiredSampleRates.count &&
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
            }
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
        (try? Self.fingerprint(of: deterministicJSON())) ?? ""
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
                .kickOverFoundationActiveDBMean:
            absoluteFloor = 0.75
        case .spectralCentroidMeanHz, .spectralCentroidSpreadHz,
                .spectralBandwidthMeanHz, .spectralRolloff85MeanHz,
                .barCentroidSpanHz:
            absoluteFloor = 120
        case .maximumBoundaryDelta, .absoluteDCOffset:
            absoluteFloor = 0.002
        default:
            absoluteFloor = 0.04
        }
        return max(absoluteFloor, observedRateDrift * 2, centerMagnitude * 0.08)
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
                .maskingLongestRunRatio, .activeKickFoundationBarRatio:
            return 0...1
        case .stereoCorrelation, .lowStereoCorrelation:
            return -1...1
        case .spectralCentroidMeanHz, .spectralCentroidSpreadHz,
                .spectralBandwidthMeanHz, .spectralRolloff85MeanHz,
                .barCentroidSpanHz:
            return 0...(QualityQualificationContract.maximumSupportedSampleRate / 2)
        case .loudnessRangeLU, .crestFactorDB,
                .rmsTrajectoryDeltaMeanDB, .rmsTrajectoryDeltaPeakDB,
                .barLoudnessSpanLU, .barTransientDensityMean,
                .barTransientDensitySpan, .barCrestFactorMean,
                .barCrestFactorSpan:
            return 0...120
        case .kickOverFoundationActiveDBMean:
            return -120...120
        }
    }

    private static func fingerprint(of data: Data) throws -> String {
        guard let string = String(data: data, encoding: .utf8) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        var sink = StreamingFNV1a()
        sink.domain("professional-quality-calibration-json.v1")
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
        for bounds in profile.trajectories {
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
        for bounds in profile.rateConsistency {
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
        for metric in ProfessionalQualityMetric.allCases {
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
