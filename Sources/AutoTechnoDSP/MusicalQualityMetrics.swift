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
        let count = min(left.count, right.count)
        guard count > 0, sampleRate > 0 else {
            integratedLoudness = -120; loudnessRange = 0; maximumShortTermLoudness = -120
            crestFactor = 0; spectralCentroid = 0; lowEnergy = 0; midEnergy = 0; highEnergy = 0; transientDensity = 0
            return
        }

        let mono = (0..<count).map { (Double(left[$0]) + Double(right[$0])) * 0.5 }
        let peak = mono.reduce(0) { max($0, abs($1)) }
        let meanSquare = mono.reduce(0) { $0 + $1 * $1 } / Double(count)
        crestFactor = peak / max(sqrt(meanSquare), 0.000_000_001)

        let momentary = Self.blockLoudness(mono, frames: max(1, Int(sampleRate * 0.4)), hop: max(1, Int(sampleRate * 0.1)))
        let absoluteGated = momentary.filter { $0 > -70 }
        let ungatedMean = Self.energyMean(absoluteGated)
        let relativeGate = ungatedMean - 10
        let gated = absoluteGated.filter { $0 >= relativeGate }
        let integrated = Self.energyMean(gated)
        integratedLoudness = integrated

        let shortTerm = Self.blockLoudness(mono, frames: max(1, Int(sampleRate * 3)), hop: max(1, Int(sampleRate)))
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
            lowPass += (sample - lowPass) * lowCoefficient
            midPass += (sample - midPass) * midCoefficient
            let mid = midPass - lowPass
            let high = sample - midPass
            lowSum += lowPass * lowPass; midSum += mid * mid; highSum += high * high
            let envelope = abs(sample)
            if envelope - previousEnvelope > 0.055 && index - lastTransient >= refractory {
                transients += 1; lastTransient = index
            }
            previousEnvelope += (envelope - previousEnvelope) * 0.08
        }
        let total = max(lowSum + midSum + highSum, 0.000_000_001)
        lowEnergy = lowSum / total; midEnergy = midSum / total; highEnergy = highSum / total
        spectralCentroid = (lowEnergy * 90 + midEnergy * 900 + highEnergy * 6_000) / (lowEnergy + midEnergy + highEnergy)
        transientDensity = Double(transients) / (Double(count) / sampleRate)
    }

    private static func blockLoudness(_ samples: [Double], frames: Int, hop: Int) -> [Double] {
        guard samples.count >= frames else {
            let energy = samples.reduce(0) { $0 + $1 * $1 } / Double(max(1, samples.count))
            return [-0.691 + 10 * log10(max(energy, 0.000_000_000_001))]
        }
        var result: [Double] = []
        var start = 0
        while start + frames <= samples.count {
            let energy = samples[start..<(start + frames)].reduce(0) { $0 + $1 * $1 } / Double(frames)
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
