import AutoTechnoCore
import Foundation

/// Deterministic upper bound for numeric working storage during detached
/// primary preparation. This is a runtime-readiness contract, not a
/// runtime allocation counter and not a quality verdict.
package struct AutonomousPreparationResourceBudget: Equatable, Sendable {
    package static let representativeSampleRates = [44_100.0, 48_000.0]
    package static let maximumPeakWorkingByteCount = 128 * 1_024 * 1_024
    /// The shortest authored phrase is four bars. Its initial render and the
    /// one permitted corrective rerender must fit before the second frozen-
    /// topology hold boundary.
    package static let minimumPhraseLookaheadSeconds =
        4.0 * 240.0 / AutonomousSessionDirector.bpm
    package static let maximumSingleHoldLookaheadSeconds =
        2.0 * minimumPhraseLookaheadSeconds

    /// Covers the reusable render workspace, both temporary rendered bars,
    /// graph channel work, and small per-bar PCM taps. The source workspace has
    /// 22 mono arrays; 64 deliberately leaves headroom for the two rendered-bar
    /// products and graph-local channel arrays.
    package static let maximumScratchMonoChannelCount = 64

    package let sampleRate: Double
    package let barCount: Int
    package let renderPassCount: Int
    package let framesPerBar: Int
    package let phraseFrameCount: Int
    package let retainedCandidatePCMByteCount: Int
    package let continuationPCMByteCount: Int
    package let scratchPCMByteCount: Int
    package let analyzerWorkingByteCount: Int
    package let reducedEvidenceByteCount: Int
    package let peakWorkingByteCount: Int

    package init?(
        sampleRate: Double,
        barCount: Int,
        renderPassCount: Int
    ) {
        guard sampleRate.isFinite,
              sampleRate >= QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract.maximumSupportedSampleRate,
              (1...QualityQualificationContract.maximumPhraseBars).contains(barCount),
              (1...QualityQualificationContract.maximumRenderPasses)
                .contains(renderPassCount) else {
            return nil
        }
        self.sampleRate = sampleRate
        self.barCount = barCount
        self.renderPassCount = renderPassCount
        framesPerBar = max(1, Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded()))
        phraseFrameCount = framesPerBar * barCount

        let floatBytes = MemoryLayout<Float>.stride
        retainedCandidatePCMByteCount = phraseFrameCount * 2 * floatBytes * (
            renderPassCount +
                RepeatHoldEvolutionDSPContract.maximumPreparedVariantCount
        )

        // Mirrors every bounded variable-length continuation owner validated
        // by AutonomousPhrasePreparer. Both current and retiring graph states
        // are included for every live primary render product.
        let voiceContinuationSeconds = 5.0 * (0.34 + 0.009 + 0.005)
        let spatialFDNSeconds = Double(
            FeedbackDelayNetworkConfiguration.lineCount
        ) * FeedbackDelayNetworkConfiguration.maximumDelaySeconds
        let graphContinuationSeconds = 2.0 * Double(
            DSPGraphPlan.maximumNodeCount
        ) * 2.0 * 0.42
        let renderContinuationSeconds =
            0.5 + 0.75 + 0.013 + 0.045 +
            voiceContinuationSeconds + spatialFDNSeconds +
            graphContinuationSeconds
        let continuationFloatCount = Int(
            (sampleRate * renderContinuationSeconds).rounded(.up)
        )
        continuationPCMByteCount = continuationFloatCount * floatBytes *
            renderPassCount

        scratchPCMByteCount = framesPerBar *
            Self.maximumScratchMonoChannelCount * floatBytes
        analyzerWorkingByteCount =
            AutonomousFullMixEvidence.maximumAnalysisPeakWorkingByteCount
        reducedEvidenceByteCount =
            CanonicalJourneyQualificationReport.maximumEncodedBytes
        peakWorkingByteCount = retainedCandidatePCMByteCount +
            continuationPCMByteCount + scratchPCMByteCount +
            analyzerWorkingByteCount + reducedEvidenceByteCount
    }

    package var withinActivationBound: Bool {
        peakWorkingByteCount <= Self.maximumPeakWorkingByteCount
    }
}
