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
        guard !cancellationRequested() else { return nil }
        let count = min(left.count, right.count)
        guard count > 0, sampleRate > 0 else {
            integratedLoudness = -120; loudnessRange = 0
            maximumMomentaryLoudness = -120
            maximumShortTermLoudness = -120
            momentaryBlockCount = 0; absoluteGatedBlockCount = 0
            relativeGatedBlockCount = 0; shortTermBlockCount = 0
            crestFactor = 0
            spectralCentroid = 0; lowEnergy = 0; midEnergy = 0
            highEnergy = 0; transientDensity = 0
            return
        }

        guard let loudness = BS1770LoudnessMeasurement(
            left: left,
            right: right,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        integratedLoudness = loudness.integratedLoudness
        maximumMomentaryLoudness = loudness.maximumMomentaryLoudness
        maximumShortTermLoudness = loudness.maximumShortTermLoudness
        loudnessRange = loudness.loudnessRange
        momentaryBlockCount = loudness.momentaryBlockCount
        absoluteGatedBlockCount = loudness.absoluteGatedBlockCount
        relativeGatedBlockCount = loudness.relativeGatedBlockCount
        shortTermBlockCount = loudness.shortTermBlockCount

        var mono: [Double] = []
        mono.reserveCapacity(count)
        var peak = 0.0
        var squareSum = 0.0
        for index in 0..<count {
            if index.isMultiple(of: 16_384), cancellationRequested() { return nil }
            let sample = (Double(left[index]) + Double(right[index])) * 0.5
            mono.append(sample)
            peak = max(peak, abs(sample))
            squareSum += sample * sample
        }
        let meanSquare = squareSum / Double(count)
        crestFactor = peak / max(sqrt(meanSquare), 0.000_000_001)

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
        var lastTransient = -refractory
        for (index, sample) in mono.enumerated() {
            if index.isMultiple(of: 16_384), cancellationRequested() { return nil }
            lowPass += (sample - lowPass) * lowCoefficient
            midPass += (sample - midPass) * midCoefficient
            let mid = midPass - lowPass
            let high = sample - midPass
            lowSum += lowPass * lowPass
            midSum += mid * mid
            highSum += high * high
            let envelope = abs(sample)
            if envelope - previousEnvelope > 0.055 &&
                index - lastTransient >= refractory {
                transients += 1
                lastTransient = index
            }
            previousEnvelope += (envelope - previousEnvelope) * 0.08
        }
        let total = max(lowSum + midSum + highSum, 0.000_000_001)
        lowEnergy = lowSum / total
        midEnergy = midSum / total
        highEnergy = highSum / total
        spectralCentroid = (
            lowEnergy * 90 + midEnergy * 900 + highEnergy * 6_000
        ) / (lowEnergy + midEnergy + highEnergy)
        transientDensity = Double(transients) / (Double(count) / sampleRate)
    }

}
