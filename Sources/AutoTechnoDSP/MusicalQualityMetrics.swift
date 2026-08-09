import Foundation

/// Offline-only perceptual and translation measurements. These calculations
/// run after immutable blocks are prepared and never execute on the callback.
package struct MusicalQualityMetrics: Equatable, Sendable {
    package let integratedLoudness: Double
    package let loudnessRange: Double
    package let maximumShortTermLoudness: Double
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
            maximumShortTermLoudness = -120; crestFactor = 0
            spectralCentroid = 0; lowEnergy = 0; midEnergy = 0
            highEnergy = 0; transientDensity = 0
            return
        }

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

        guard let momentary = Self.blockLoudness(
            mono,
            frames: max(1, Int(sampleRate * 0.4)),
            hop: max(1, Int(sampleRate * 0.1)),
            cancellationRequested: cancellationRequested
        ) else { return nil }
        let absoluteGated = momentary.filter { $0 > -70 }
        let ungatedMean = Self.energyMean(absoluteGated)
        let relativeGate = ungatedMean - 10
        let gated = absoluteGated.filter { $0 >= relativeGate }
        let integrated = Self.energyMean(gated)
        integratedLoudness = integrated

        guard let shortTerm = Self.blockLoudness(
            mono,
            frames: max(1, Int(sampleRate * 3)),
            hop: max(1, Int(sampleRate)),
            cancellationRequested: cancellationRequested
        ) else { return nil }
        maximumShortTermLoudness = shortTerm.max() ?? integrated
        let sorted = shortTerm.filter { $0 > integrated - 20 }.sorted()
        loudnessRange = sorted.count > 4
            ? Self.percentile(sorted, 0.95) - Self.percentile(sorted, 0.10)
            : 0

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

    private static func blockLoudness(
        _ samples: [Double],
        frames: Int,
        hop: Int,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> [Double]? {
        guard samples.count >= frames else {
            var sum = 0.0
            for (index, sample) in samples.enumerated() {
                if index.isMultiple(of: 16_384), cancellationRequested() {
                    return nil
                }
                sum += sample * sample
            }
            let energy = sum / Double(max(1, samples.count))
            return [-0.691 + 10 * log10(max(energy, 0.000_000_000_001))]
        }
        var result: [Double] = []
        var start = 0
        while start + frames <= samples.count {
            guard !cancellationRequested() else { return nil }
            var sum = 0.0
            for index in start..<(start + frames) {
                if (index - start).isMultiple(of: 16_384),
                   cancellationRequested() {
                    return nil
                }
                sum += samples[index] * samples[index]
            }
            let energy = sum / Double(frames)
            result.append(-0.691 + 10 * log10(max(energy, 0.000_000_000_001)))
            start += hop
        }
        return result
    }

    private static func energyMean(_ loudness: [Double]) -> Double {
        guard !loudness.isEmpty else { return -120 }
        let energy = loudness.reduce(0) { $0 + pow(10, ($1 + 0.691) / 10) } / Double(loudness.count)
        return -0.691 + 10 * log10(max(energy, 0.000_000_000_001))
    }

    private static func percentile(_ sorted: [Double], _ value: Double) -> Double {
        sorted[min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * value).rounded())))]
    }
}
