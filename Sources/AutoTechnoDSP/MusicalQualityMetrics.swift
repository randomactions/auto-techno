import Foundation

/// Offline-only perceptual and translation measurements. These calculations
/// run after immutable blocks are prepared and never execute on the callback.
package struct MusicalQualityMetrics: Equatable, Sendable {
    package let integratedLoudness: Double
    package let loudnessRange: Double
    package let maximumMomentaryLoudness: Double
    package let maximumShortTermLoudness: Double
    package let momentaryBlockCount: Int
    package let absoluteGatedBlockCount: Int
    package let relativeGatedBlockCount: Int
    package let shortTermBlockCount: Int
    package let crestFactor: Double
    package let spectralCentroid: Double
    package let lowEnergy: Double
    package let midEnergy: Double
    package let highEnergy: Double
    package let transientDensity: Double
    package let perceptualEvidence: StreamingPerceptualEvidence
    package let loudnessPeakWorkingByteCount: Int

    package init(left: [Float], right: [Float], sampleRate: Double) {
        guard let metrics = Self(
            left: left,
            right: right,
            sampleRate: sampleRate,
            cancellationRequested: { false }
        ) else {
            preconditionFailure("Non-cancellable musical metrics stopped unexpectedly")
        }
        self = metrics
    }

    package init?(
        left: [Float],
        right: [Float],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) {
        guard let loudness = BS1770LoudnessMeasurement(
            left: left,
            right: right,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ), let perceptual = StreamingPerceptualEvidenceAnalyzer.analyze(
            left: left,
            right: right,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        self.init(
            chunks: [(left, right)],
            sampleRate: sampleRate,
            loudness: loudness,
            perceptual: perceptual,
            cancellationRequested: cancellationRequested
        )
    }

    package init?(
        blocks: [RenderBlock],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) {
        guard let loudness = BS1770LoudnessMeasurement(
            blocks: blocks,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ), let perceptual = StreamingPerceptualEvidenceAnalyzer.analyze(
            blocks: blocks,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        self.init(
            chunks: blocks.map { ($0.left, $0.right) },
            sampleRate: sampleRate,
            loudness: loudness,
            perceptual: perceptual,
            cancellationRequested: cancellationRequested
        )
    }

    private init?(
        chunks: [([Float], [Float])],
        sampleRate: Double,
        loudness: BS1770LoudnessMeasurement,
        perceptual: StreamingPerceptualEvidence,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) {
        guard !cancellationRequested() else { return nil }
        let count = chunks.reduce(0) { result, chunk in
            result + min(chunk.0.count, chunk.1.count)
        }
        guard count > 0, sampleRate > 0 else {
            integratedLoudness = -120; loudnessRange = 0
            maximumMomentaryLoudness = -120
            maximumShortTermLoudness = -120
            momentaryBlockCount = 0; absoluteGatedBlockCount = 0
            relativeGatedBlockCount = 0; shortTermBlockCount = 0
            crestFactor = 0
            spectralCentroid = 0; lowEnergy = 0; midEnergy = 0
            highEnergy = 0; transientDensity = 0
            perceptualEvidence = perceptual
            loudnessPeakWorkingByteCount = loudness.peakWorkingByteCount
            return
        }
        integratedLoudness = loudness.integratedLoudness
        maximumMomentaryLoudness = loudness.maximumMomentaryLoudness
        maximumShortTermLoudness = loudness.maximumShortTermLoudness
        loudnessRange = loudness.loudnessRange
        momentaryBlockCount = loudness.momentaryBlockCount
        absoluteGatedBlockCount = loudness.absoluteGatedBlockCount
        relativeGatedBlockCount = loudness.relativeGatedBlockCount
        shortTermBlockCount = loudness.shortTermBlockCount

        var peak = 0.0
        var squareSum = 0.0
        var lowPass = 0.0
        var midPass = 0.0
        var lowSum = 0.0
        var midSum = 0.0
        var highSum = 0.0
        let lowCoefficient = 1 - exp(-2 * Double.pi * 180 / sampleRate)
        let midCoefficient = 1 - exp(-2 * Double.pi * 2_500 / sampleRate)
        var previousEnvelope = 0.0
        var transients = 0
        let refractory = max(1, Int(sampleRate * 0.035))
        let referenceEnvelopeCoefficient = 0.08
        let envelopeCoefficient = 1 - pow(
            1 - referenceEnvelopeCoefficient,
            48_000 / sampleRate
        )
        var lastTransient = -refractory
        var frame = 0
        for (left, right) in chunks {
            let chunkCount = min(left.count, right.count)
            for index in 0..<chunkCount {
                if frame.isMultiple(of: 16_384), cancellationRequested() {
                    return nil
                }
                let sample = (Double(left[index]) + Double(right[index])) * 0.5
                peak = max(peak, abs(sample))
                squareSum += sample * sample
                lowPass += (sample - lowPass) * lowCoefficient
                midPass += (sample - midPass) * midCoefficient
                let mid = midPass - lowPass
                let high = sample - midPass
                lowSum += lowPass * lowPass
                midSum += mid * mid
                highSum += high * high
                let envelope = abs(sample)
                if envelope - previousEnvelope > 0.055 &&
                    frame - lastTransient >= refractory {
                    transients += 1
                    lastTransient = frame
                }
                previousEnvelope +=
                    (envelope - previousEnvelope) * envelopeCoefficient
                frame += 1
            }
        }
        let meanSquare = squareSum / Double(count)
        crestFactor = peak / max(sqrt(meanSquare), 0.000_000_001)
        let total = max(lowSum + midSum + highSum, 0.000_000_001)
        lowEnergy = lowSum / total
        midEnergy = midSum / total
        highEnergy = highSum / total
        spectralCentroid = perceptual.spectralCentroidMeanHz
        transientDensity = Double(transients) / (Double(count) / sampleRate)
        perceptualEvidence = perceptual
        loudnessPeakWorkingByteCount = loudness.peakWorkingByteCount
    }

}
