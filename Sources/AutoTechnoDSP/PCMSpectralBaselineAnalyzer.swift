import Foundation

package struct PCMSpectralWindowEvidence: Codable, Equatable, Sendable {
    package let index: Int
    package let cellStartFrame: Int
    package let cellFrameCount: Int
    package let spectrumStartFrame: Int
    package let spectrumFrameCount: Int
    package let fftFrameCount: Int
    package let sourceMeanSquare: Double
    package let sourceRMSDBFS: Double
    package let sourceActive: Bool
    package let spectrumActive: Bool
    package let spectralCentroidHz: Double
    package let spectralBandwidthHz: Double
    package let spectralRolloff85Hz: Double
    package let spectralFlatness: Double
    package let bandMeanSquares: [Double]
    package let bandShares: [Double]
    package let subBandShare: Double
    package let lowEndOccupied: Bool
}

package struct PCMSpectralSummary: Codable, Equatable, Sendable {
    package let frameCount: Int
    package let windowCount: Int
    package let activeSpectralWindowCount: Int
    package let sourceActiveWindowCount: Int
    package let lowEndOccupiedWindowCount: Int
    package let lowEndOccupancy: Double
    package let sourceMeanSquare: Double
    package let sourceRMSDBFS: Double
    package let spectralCentroidMeanHz: Double
    package let spectralCentroidMinimumHz: Double
    package let spectralCentroidMaximumHz: Double
    package let spectralBandwidthMeanHz: Double
    package let spectralRolloff85MeanHz: Double
    package let spectralFlatnessMean: Double
    package let subBandShareMean: Double
    package let bandMeanSquares: [Double]
    package let bandShares: [Double]
    package let finite: Bool
}

package struct PCMSpectralSegmentEvidence: Codable, Equatable, Sendable {
    package let startFrame: Int
    package let frameCount: Int
    package let summary: PCMSpectralSummary
    package let windows: [PCMSpectralWindowEvidence]
}

package struct PCMSpectralBaselineEvidence: Codable, Equatable, Sendable {
    package let schema: String
    package let sampleRate: Int
    package let sourceChannelCount: Int
    package let frameCount: Int
    package let segmentFrameCount: Int
    package let windowsPerSegment: Int
    package let spectrumFrameCount: Int
    package let fftFrameCount: Int
    package let bands: [MaskingBand]
    package let summary: PCMSpectralSummary
    package let segments: [PCMSpectralSegmentEvidence]
}

/// Detached descriptive analysis for exact local corpus PCM. Spectral shape is
/// delegated to the canonical streaming Hann/FFT analyzer. Multiband energy is
/// delegated to the canonical causal masking filters. The two evidence families
/// share timeline cells but retain their distinct windows and units.
package enum PCMSpectralBaselineAnalyzer {
    package static let schema = "autotechno-pcm-spectral-baseline.v1"
    package static let analyzerVersion =
        "autotechno-pcm-spectral-baseline-analyzer.v1"
    package static let windowsPerSegment = SpectrumMaskingAnalyzer.analyzedWindowCount
    package static let activeMeanSquareThreshold =
        SpectrumMaskingAnalyzer.activeMeanSquareThreshold
    package static let minimumSubBandShare = 0.10
    package static let decibelFloor = -120.0
    package static let monoFold = "arithmetic-mean-of-source-channels"
    package static let spectrumWindowPlacement = "centered-in-causal-cell"
    package static let bandEnergyModel =
        "causal-one-pole-difference-non-power-complementary"

    package static func analyze(
        channels: [[Float]],
        sampleRate: Double,
        segmentFrameCount: Int
    ) -> PCMSpectralBaselineEvidence? {
        guard sampleRate.isFinite, sampleRate > 0,
              sampleRate.rounded() == sampleRate,
              sampleRate <= Double(Int.max),
              !channels.isEmpty,
              channels.count <= 2,
              let frameCount = channels.first?.count,
              frameCount > 0,
              channels.allSatisfy({ $0.count == frameCount }),
              channels.allSatisfy({ $0.allSatisfy(\.isFinite) }),
              segmentFrameCount > 0 else {
            return nil
        }
        let spectrumFrames = StreamingPerceptualEvidenceAnalyzer
            .analysisFrameCount(sampleRate: sampleRate)
        let fftFrames = StreamingPerceptualEvidenceAnalyzer
            .fftFrameCount(sampleRate: sampleRate)
        guard segmentFrameCount >= spectrumFrames,
              segmentFrameCount <= SpectrumMaskingAnalyzer.maximumFrames else {
            return nil
        }

        var segments: [PCMSpectralSegmentEvidence] = []
        segments.reserveCapacity(
            (frameCount + segmentFrameCount - 1) / segmentFrameCount
        )
        var allWindows: [PCMSpectralWindowEvidence] = []
        allWindows.reserveCapacity(
            segments.capacity * windowsPerSegment
        )
        var segmentStart = 0
        while segmentStart < frameCount {
            let count = min(segmentFrameCount, frameCount - segmentStart)
            guard count >= spectrumFrames else { return nil }
            var mono = [Float](repeating: 0, count: count)
            let divisor = Float(channels.count)
            for channel in channels {
                for frame in 0..<count {
                    mono[frame] += channel[segmentStart + frame] / divisor
                }
            }
            guard let causalWindows = SpectrumMaskingAnalyzer.bandEnergyWindows(
                mono,
                sampleRate: sampleRate
            ), causalWindows.count == windowsPerSegment else {
                return nil
            }
            var windows: [PCMSpectralWindowEvidence] = []
            windows.reserveCapacity(windowsPerSegment)
            for causal in causalWindows {
                let center = causal.startFrame + causal.frameCount / 2
                let unclampedStart = center - spectrumFrames / 2
                let spectrumStart = min(
                    max(0, unclampedStart),
                    count - spectrumFrames
                )
                let samples = Array(
                    mono[spectrumStart..<(spectrumStart + spectrumFrames)]
                )
                guard let spectrum = StreamingPerceptualEvidenceAnalyzer.analyze(
                    left: samples,
                    right: samples,
                    sampleRate: sampleRate
                ), spectrum.isComplete, spectrum.finite,
                   spectrum.analyzedWindowCount == 1,
                   spectrum.analysisFrameCount == spectrumFrames,
                   spectrum.fftFrameCount == fftFrames,
                   causal.bandMeanSquares.count ==
                    SpectrumMaskingAnalyzer.bands.count,
                   causal.bandMeanSquares.allSatisfy({ $0.isFinite && $0 >= 0 }),
                   causal.sourceMeanSquare.isFinite,
                   causal.sourceMeanSquare >= 0 else {
                    return nil
                }
                let bandTotal = causal.bandMeanSquares.reduce(0, +)
                let bandShares = bandTotal > 0
                    ? causal.bandMeanSquares.map { $0 / bandTotal }
                    : [Double](
                        repeating: 0,
                        count: causal.bandMeanSquares.count
                    )
                let subShare = bandShares.first ?? 0
                let sourceActive = causal.sourceMeanSquare >
                    activeMeanSquareThreshold
                let lowEndOccupied = sourceActive &&
                    causal.bandMeanSquares[0] > activeMeanSquareThreshold &&
                    subShare >= minimumSubBandShare
                windows.append(PCMSpectralWindowEvidence(
                    index: causal.index,
                    cellStartFrame: causal.startFrame,
                    cellFrameCount: causal.frameCount,
                    spectrumStartFrame: spectrumStart,
                    spectrumFrameCount: spectrumFrames,
                    fftFrameCount: fftFrames,
                    sourceMeanSquare: causal.sourceMeanSquare,
                    sourceRMSDBFS: decibels(
                        amplitude: sqrt(causal.sourceMeanSquare)
                    ),
                    sourceActive: sourceActive,
                    spectrumActive: spectrum.activeWindowCount == 1,
                    spectralCentroidHz: spectrum.spectralCentroidMeanHz,
                    spectralBandwidthHz: spectrum.spectralBandwidthMeanHz,
                    spectralRolloff85Hz: spectrum.spectralRolloff85MeanHz,
                    spectralFlatness: spectrum.spectralFlatnessMean,
                    bandMeanSquares: causal.bandMeanSquares,
                    bandShares: bandShares,
                    subBandShare: subShare,
                    lowEndOccupied: lowEndOccupied
                ))
            }
            let summary = summarize(windows)
            guard summary.finite else { return nil }
            segments.append(PCMSpectralSegmentEvidence(
                startFrame: segmentStart,
                frameCount: count,
                summary: summary,
                windows: windows
            ))
            allWindows.append(contentsOf: windows)
            segmentStart += count
        }
        let summary = summarize(allWindows)
        guard summary.finite else { return nil }
        return PCMSpectralBaselineEvidence(
            schema: schema,
            sampleRate: Int(sampleRate),
            sourceChannelCount: channels.count,
            frameCount: frameCount,
            segmentFrameCount: segmentFrameCount,
            windowsPerSegment: windowsPerSegment,
            spectrumFrameCount: spectrumFrames,
            fftFrameCount: fftFrames,
            bands: SpectrumMaskingAnalyzer.bands,
            summary: summary,
            segments: segments
        )
    }

    package static func summarize(
        _ windows: [PCMSpectralWindowEvidence]
    ) -> PCMSpectralSummary {
        let frameCount = windows.reduce(0) { $0 + $1.cellFrameCount }
        let activeSpectrum = windows.filter(\.spectrumActive)
        let activeSource = windows.filter(\.sourceActive)
        let lowEndCount = windows.filter(\.lowEndOccupied).count
        let frameDivisor = Double(max(1, frameCount))
        let sourceMeanSquare = windows.reduce(0.0) {
            $0 + $1.sourceMeanSquare * Double($1.cellFrameCount)
        } / frameDivisor
        var bandMeanSquares = [Double](
            repeating: 0,
            count: SpectrumMaskingAnalyzer.bands.count
        )
        for window in windows {
            for index in bandMeanSquares.indices {
                bandMeanSquares[index] += window.bandMeanSquares[index] *
                    Double(window.cellFrameCount)
            }
        }
        bandMeanSquares = bandMeanSquares.map { $0 / frameDivisor }
        let bandTotal = bandMeanSquares.reduce(0, +)
        let bandShares = bandTotal > 0
            ? bandMeanSquares.map { $0 / bandTotal }
            : [Double](repeating: 0, count: bandMeanSquares.count)
        let spectralDivisor = Double(max(1, activeSpectrum.count))
        let sourceDivisor = Double(max(1, activeSource.count))
        let centroids = activeSpectrum.map(\.spectralCentroidHz)
        let values = [
            sourceMeanSquare,
            activeSpectrum.reduce(0) { $0 + $1.spectralCentroidHz } /
                spectralDivisor,
            centroids.min() ?? 0,
            centroids.max() ?? 0,
            activeSpectrum.reduce(0) { $0 + $1.spectralBandwidthHz } /
                spectralDivisor,
            activeSpectrum.reduce(0) { $0 + $1.spectralRolloff85Hz } /
                spectralDivisor,
            activeSpectrum.reduce(0) { $0 + $1.spectralFlatness } /
                spectralDivisor,
            activeSource.reduce(0) { $0 + $1.subBandShare } /
                sourceDivisor,
        ]
        let occupancy = activeSource.isEmpty
            ? 0 : Double(lowEndCount) / Double(activeSource.count)
        return PCMSpectralSummary(
            frameCount: frameCount,
            windowCount: windows.count,
            activeSpectralWindowCount: activeSpectrum.count,
            sourceActiveWindowCount: activeSource.count,
            lowEndOccupiedWindowCount: lowEndCount,
            lowEndOccupancy: occupancy,
            sourceMeanSquare: sourceMeanSquare,
            sourceRMSDBFS: decibels(amplitude: sqrt(sourceMeanSquare)),
            spectralCentroidMeanHz: values[1],
            spectralCentroidMinimumHz: values[2],
            spectralCentroidMaximumHz: values[3],
            spectralBandwidthMeanHz: values[4],
            spectralRolloff85MeanHz: values[5],
            spectralFlatnessMean: values[6],
            subBandShareMean: values[7],
            bandMeanSquares: bandMeanSquares,
            bandShares: bandShares,
            finite: values.allSatisfy(\.isFinite) && occupancy.isFinite &&
                bandMeanSquares.allSatisfy(\.isFinite) &&
                bandShares.allSatisfy(\.isFinite)
        )
    }

    private static func decibels(amplitude: Double) -> Double {
        guard amplitude > 0 else { return decibelFloor }
        return max(decibelFloor, 20 * log10(amplitude))
    }
}
