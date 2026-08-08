import Foundation

/// Offline-only perceptual and translation measurements. These calculations
/// run after immutable blocks are prepared and never execute on the callback.
public struct MusicalQualityMetrics: Equatable, Sendable {
    public let integratedLoudness: Double
    public let loudnessRange: Double
    public let maximumShortTermLoudness: Double
    public let crestFactor: Double
    public let spectralCentroid: Double
    public let lowEnergy: Double
    public let midEnergy: Double
    public let highEnergy: Double
    public let transientDensity: Double

    public init(left: [Float], right: [Float], sampleRate: Double) {
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

/// Offline-only guard against an exposed upper voice collapsing into a static,
/// recognizable primitive oscillator. Call this with a musical-voices stem;
/// it intentionally samples a few pressure-state windows instead of running a
/// live FFT or adding work to the audio callback.
public struct TimbreComplexityMetrics: Equatable, Sendable {
    public let activeWindowCount: Int
    public let significantNonFundamentalPartials: Int
    public let meanSpectralCentroid: Double
    public let spectralCentroidRange: Double
    public let passesComplexityGuard: Bool

    public init(blocks: [V2RenderBlock], sampleRate: Double) {
        guard sampleRate > 0, !blocks.isEmpty else {
            activeWindowCount = 0
            significantNonFundamentalPartials = 0
            meanSpectralCentroid = 0
            spectralCentroidRange = 0
            passesComplexityGuard = false
            return
        }

        let pressure = blocks.filter { $0.synthPerformance?.gesture == .corrode }
        let selected = Array((pressure.isEmpty ? blocks : pressure).prefix(3))
        let windowSize = 1_024
        var spectra: [[Double]] = []
        for block in selected {
            let count = min(block.left.count, block.right.count)
            guard count >= windowSize else { continue }
            for fraction in [0.18, 0.43, 0.68, 0.88] {
                let center = Int(Double(count) * fraction)
                let start = min(count - windowSize, max(0, center - windowSize / 2))
                let mono = (0..<windowSize).map { offset in
                    (Double(block.left[start + offset]) + Double(block.right[start + offset])) * 0.5
                }
                let energy = mono.reduce(0) { $0 + $1 * $1 } / Double(windowSize)
                if energy > 0.000_000_000_1 {
                    spectra.append(Self.spectrum(mono, sampleRate: sampleRate))
                }
            }
        }

        activeWindowCount = spectra.count
        guard let first = spectra.first else {
            significantNonFundamentalPartials = 0
            meanSpectralCentroid = 0
            spectralCentroidRange = 0
            passesComplexityGuard = false
            return
        }

        var average = [Double](repeating: 0, count: first.count)
        var centroids: [Double] = []
        centroids.reserveCapacity(spectra.count)
        for spectrum in spectra {
            var weighted = 0.0
            var total = 0.0
            for bin in spectrum.indices {
                average[bin] += spectrum[bin]
                let energy = spectrum[bin] * spectrum[bin]
                weighted += Double(bin) * sampleRate / Double(windowSize) * energy
                total += energy
            }
            centroids.append(weighted / max(total, 0.000_000_000_001))
        }
        for index in average.indices { average[index] /= Double(spectra.count) }

        let fundamental = blocks.compactMap(\.synthWorld?.rootFrequency).first ?? 65.41
        let fundamentalBin = min(average.count - 1, max(1, Int((fundamental * Double(windowSize) / sampleRate).rounded())))
        let fundamentalMagnitude = Self.localPeak(average, bin: fundamentalBin)
        let maximumMagnitude = average.max() ?? 0
        let threshold = max(fundamentalMagnitude * 0.04, maximumMagnitude * 0.018)
        significantNonFundamentalPartials = (2...12).reduce(into: 0) { result, harmonic in
            let bin = Int((fundamental * Double(harmonic) * Double(windowSize) / sampleRate).rounded())
            if bin < average.count, Self.localPeak(average, bin: bin) >= threshold { result += 1 }
        }
        meanSpectralCentroid = centroids.reduce(0, +) / Double(centroids.count)
        spectralCentroidRange = (centroids.max() ?? 0) - (centroids.min() ?? 0)
        passesComplexityGuard = activeWindowCount >= 2 &&
            significantNonFundamentalPartials >= 3 && spectralCentroidRange >= 40
    }

    private static func spectrum(_ samples: [Double], sampleRate: Double) -> [Double] {
        let count = samples.count
        let upperBin = min(count / 2, Int(10_000 * Double(count) / sampleRate))
        return (0...max(1, upperBin)).map { bin in
            var real = 0.0
            var imaginary = 0.0
            for index in samples.indices {
                let window = 0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(max(1, count - 1)))
                let angle = 2 * .pi * Double(bin * index) / Double(count)
                let value = samples[index] * window
                real += value * cos(angle)
                imaginary -= value * sin(angle)
            }
            return sqrt(real * real + imaginary * imaginary)
        }
    }

    private static func localPeak(_ spectrum: [Double], bin: Int) -> Double {
        let lower = max(0, bin - 1)
        let upper = min(spectrum.count - 1, bin + 1)
        return spectrum[lower...upper].max() ?? 0
    }
}
