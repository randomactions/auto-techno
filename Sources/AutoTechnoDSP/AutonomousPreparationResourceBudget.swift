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
    package let repeatHoldWorkingPCMByteCount: Int
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
        let maximumLooperCaptureFrameCount = Int((
            sampleRate *
                RepeatHoldEvolutionDSPContract
                    .totalMaximumLooperCaptureSeconds
        ).rounded(.up))
        repeatHoldWorkingPCMByteCount = maximumLooperCaptureFrameCount * 2 *
            floatBytes

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
            repeatHoldWorkingPCMByteCount + continuationPCMByteCount +
            scratchPCMByteCount +
            analyzerWorkingByteCount + reducedEvidenceByteCount
    }

    package var withinActivationBound: Bool {
        peakWorkingByteCount <= Self.maximumPeakWorkingByteCount
    }
}

/// Phase-aware numeric reservation for one detached chain under the existing
/// 128 MiB ceiling. A rendering phrase reserves its entire active pass budget;
/// suspended parents retain only immutable selected PCM/state/evidence. Scratch,
/// analyzer and looper workspaces die when each render call unwinds. No qualified
/// child or physical support requirement is removed to fit this bound.
package struct AutonomousPreparationChainResourceBudget: Equatable, Sendable {
    package static let version = "autotechno-preparation-chain-resource.v2"
    package let reservedPeakWorkingByteCount: Int
    package let retainedNumericByteCount: Int
    /// The root request stays alive across the entire chain, even after each
    /// source is suspended. Charge its allocated numeric capacity once; child
    /// incoming state already belongs to a retained completed source.
    package let retainedIncomingContinuationNumericByteCount: Int
    package let sourceCount: Int
    package let maximumRenderPassCount: Int
    private let completedSourceCount: Int
    private let completedRenderPassCount: Int

    package init() {
        reservedPeakWorkingByteCount = 0; retainedNumericByteCount = 0
        retainedIncomingContinuationNumericByteCount = 0
        sourceCount = 0; maximumRenderPassCount = 0
        completedSourceCount = 0; completedRenderPassCount = 0
    }

    /// Measured through the complete canonical typed inventory before PCM
    /// rendering. Unused capacity is retained storage, not an empty input.
    /// This supplements the existing conservative render/capture charges.
    package init?(incomingContinuationNumericByteCount: Int) {
        guard (0...AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount)
            .contains(incomingContinuationNumericByteCount) else { return nil }
        reservedPeakWorkingByteCount = incomingContinuationNumericByteCount
        retainedNumericByteCount = incomingContinuationNumericByteCount
        retainedIncomingContinuationNumericByteCount = incomingContinuationNumericByteCount
        sourceCount = 0; maximumRenderPassCount = 0
        completedSourceCount = 0; completedRenderPassCount = 0
    }

    private init(peak: Int, retained: Int, incoming: Int, count: Int, passes: Int,
        completedCount: Int, completedPasses: Int) {
        reservedPeakWorkingByteCount = peak; retainedNumericByteCount = retained
        retainedIncomingContinuationNumericByteCount = incoming
        sourceCount = count; maximumRenderPassCount = passes
        completedSourceCount = completedCount; completedRenderPassCount = completedPasses
    }

    package func reserving(sampleRate: Double, barCount: Int,
        renderPassCount: Int = QualityQualificationContract.maximumRenderPasses,
        diagnosticRoleStemCapture: Bool = false
    ) -> Self? {
        guard let source = AutonomousPreparationResourceBudget(sampleRate: sampleRate,
            barCount: barCount, renderPassCount: renderPassCount) else { return nil }
        let captureBytes = diagnosticRoleStemCapture
            ? source.phraseFrameCount * 32 * MemoryLayout<Float>.stride * source.renderPassCount : 0
        let active = source.peakWorkingByteCount.addingReportingOverflow(captureBytes)
        let total = retainedNumericByteCount.addingReportingOverflow(active.partialValue)
        let count = completedSourceCount.addingReportingOverflow(1)
        let passes = completedRenderPassCount.addingReportingOverflow(renderPassCount)
        guard !active.overflow, !total.overflow, !count.overflow, !passes.overflow,
            total.partialValue <= AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount
        else { return nil }
        return Self(peak: max(reservedPeakWorkingByteCount, total.partialValue),
            retained: retainedNumericByteCount,
            incoming: retainedIncomingContinuationNumericByteCount,
            count: count.partialValue, passes: passes.partialValue,
            completedCount: completedSourceCount, completedPasses: completedRenderPassCount)
    }

    /// Called only after the canonical pending finalizer has released candidate
    /// sidecars. A source needing its measured child owns no repeat variants:
    /// protected transport must consume that child. A closed leaf retains them.
    package func retainingCompletedSource(sampleRate: Double, barCount: Int,
        requiresQualifiedSuccessor: Bool, diagnosticRoleStemCapture: Bool = false,
        retainedContinuationNumericByteCount: Int? = nil
    ) -> Self? {
        guard sourceCount == completedSourceCount + 1,
            let source = AutonomousPreparationResourceBudget(sampleRate: sampleRate,
                barCount: barCount, renderPassCount: 1) else { return nil }
        let variants = requiresQualifiedSuccessor ? 0 : RepeatHoldEvolutionDSPContract.maximumPreparedVariantCount
        // Source/preview/finalized blocks and ending state are immutable aliases
        // of the selected product. No source copy is mutated after suspension.
        let pcm = source.phraseFrameCount * 2 * MemoryLayout<Float>.stride * (1 + variants)
        let capture = diagnosticRoleStemCapture ? source.phraseFrameCount * 32 * MemoryLayout<Float>.stride : 0
        let continuation = retainedContinuationNumericByteCount ?? source.continuationPCMByteCount
        guard (0...source.continuationPCMByteCount).contains(continuation) else { return nil }
        let bytes = pcm + continuation + source.reducedEvidenceByteCount + capture
        let retained = retainedNumericByteCount.addingReportingOverflow(bytes)
        guard !retained.overflow,
            retained.partialValue <= reservedPeakWorkingByteCount else { return nil }
        return Self(peak: reservedPeakWorkingByteCount, retained: retained.partialValue,
            incoming: retainedIncomingContinuationNumericByteCount,
            count: sourceCount, passes: maximumRenderPassCount,
            completedCount: sourceCount, completedPasses: maximumRenderPassCount)
    }
}
