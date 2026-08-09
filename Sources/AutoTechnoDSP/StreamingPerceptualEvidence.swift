import Foundation

/// Bounded phrase-wide spectral and trajectory evidence. The analyzer consumes
/// immutable PCM incrementally and retains only one FFT window plus fixed
/// scratch buffers; it never constructs a phrase-sized mono or spectrogram
/// array.
package struct StreamingPerceptualEvidence: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package static let analyzerVersion =
        "autotechno-streaming-perceptual-evidence.v1"

    package let schemaVersion: Int
    package let analyzerVersion: String
    package let sourceFrameCount: Int
    package let fftFrameCount: Int
    package let hopFrameCount: Int
    package let analyzedWindowCount: Int
    package let activeWindowCount: Int
    package let maximumBufferedFrameCount: Int
    package let peakWorkingByteCount: Int
    package let spectralCentroidMeanHz: Double
    package let spectralCentroidSpreadHz: Double
    package let spectralBandwidthMeanHz: Double
    package let spectralFlatnessMean: Double
    package let spectralRolloff85MeanHz: Double
    package let positiveSpectralFluxMean: Double
    package let positiveSpectralFluxPeak: Double
    package let rmsTrajectoryDeltaMeanDB: Double
    package let rmsTrajectoryDeltaPeakDB: Double
    package let finite: Bool

    package var isComplete: Bool {
        let expectedWindows = sourceFrameCount >= fftFrameCount
            ? 1 + (sourceFrameCount - fftFrameCount) / hopFrameCount
            : 0
        return schemaVersion == Self.schemaVersion &&
            analyzerVersion == Self.analyzerVersion &&
            sourceFrameCount >= 0 && fftFrameCount >= 2 &&
            fftFrameCount.nonzeroBitCount == 1 &&
            hopFrameCount == fftFrameCount / 2 &&
            analyzedWindowCount == expectedWindows &&
            (0...analyzedWindowCount).contains(activeWindowCount) &&
            maximumBufferedFrameCount == min(sourceFrameCount, fftFrameCount) &&
            peakWorkingByteCount > 0 && finite
    }
}

package enum StreamingPerceptualEvidenceAnalyzer {
    package static let targetWindowSeconds = 1.0 / 24.0
    package static let minimumFFTFrameCount = 512
    package static let maximumFFTFrameCount = 8_192

    package static func fftFrameCount(sampleRate: Double) -> Int {
        guard sampleRate.isFinite, sampleRate > 0 else {
            return minimumFFTFrameCount
        }
        let target = max(2, Int((sampleRate * targetWindowSeconds).rounded()))
        var lower = 1
        while lower <= target / 2 { lower *= 2 }
        let upper = lower < Int.max / 2 ? lower * 2 : lower
        let selected = target - lower <= upper - target ? lower : upper
        return min(maximumFFTFrameCount, max(minimumFFTFrameCount, selected))
    }

    package static func analyze(
        left: [Float],
        right: [Float],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> StreamingPerceptualEvidence? {
        analyze(
            chunks: [(left, right)],
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        )
    }

    package static func analyze(
        blocks: [RenderBlock],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> StreamingPerceptualEvidence? {
        analyze(
            chunks: blocks.map { ($0.left, $0.right) },
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        )
    }

    package static func analyze(
        leftChunks: [[Float]],
        rightChunks: [[Float]],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> StreamingPerceptualEvidence? {
        guard leftChunks.count == rightChunks.count else { return nil }
        return analyze(
            chunks: zip(leftChunks, rightChunks).map { ($0, $1) },
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        )
    }

    private static func analyze(
        chunks: [([Float], [Float])],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> StreamingPerceptualEvidence? {
        guard !cancellationRequested() else { return nil }
        var accumulator = Accumulator(sampleRate: sampleRate)
        for (left, right) in chunks {
            guard accumulator.consume(
                left: left,
                right: right,
                cancellationRequested: cancellationRequested
            ) else { return nil }
        }
        return accumulator.evidence
    }

    private struct Accumulator {
        let sampleRate: Double
        let fftSize: Int
        let hopSize: Int
        var ring: [Double]
        var real: [Double]
        var imaginary: [Double]
        var previousNormalizedMagnitude: [Double]
        var sourceFrameCount = 0
        var analyzedWindowCount = 0
        var activeWindowCount = 0
        var finite = true
        var centroidSum = 0.0
        var centroidMinimum = Double.greatestFiniteMagnitude
        var centroidMaximum = 0.0
        var bandwidthSum = 0.0
        var flatnessSum = 0.0
        var rolloffSum = 0.0
        var fluxSum = 0.0
        var fluxPeak = 0.0
        var fluxTransitionCount = 0
        var previousRMSDB: Double?
        var trajectoryDeltaSum = 0.0
        var trajectoryDeltaPeak = 0.0
        var trajectoryTransitionCount = 0

        init(sampleRate: Double) {
            self.sampleRate = sampleRate
            fftSize = StreamingPerceptualEvidenceAnalyzer.fftFrameCount(
                sampleRate: sampleRate
            )
            hopSize = fftSize / 2
            ring = [Double](repeating: 0, count: fftSize)
            real = [Double](repeating: 0, count: fftSize)
            imaginary = [Double](repeating: 0, count: fftSize)
            previousNormalizedMagnitude = [Double](
                repeating: 0,
                count: fftSize / 2 + 1
            )
        }

        mutating func consume(
            left: [Float],
            right: [Float],
            cancellationRequested: @escaping @Sendable () -> Bool
        ) -> Bool {
            let count = min(left.count, right.count)
            if left.count != right.count { finite = false }
            for index in 0..<count {
                if sourceFrameCount.isMultiple(of: 4_096),
                   cancellationRequested() {
                    return false
                }
                let leftSample = Double(left[index])
                let rightSample = Double(right[index])
                if !leftSample.isFinite || !rightSample.isFinite { finite = false }
                let mono = (leftSample + rightSample) * 0.5
                ring[sourceFrameCount % fftSize] = mono
                sourceFrameCount += 1
                if sourceFrameCount >= fftSize,
                   (sourceFrameCount - fftSize).isMultiple(of: hopSize) {
                    guard analyzeWindow(
                        cancellationRequested: cancellationRequested
                    ) else { return false }
                }
            }
            return true
        }

        mutating func analyzeWindow(
            cancellationRequested: @escaping @Sendable () -> Bool
        ) -> Bool {
            guard !cancellationRequested() else { return false }
            let oldest = sourceFrameCount % fftSize
            var squareSum = 0.0
            for index in 0..<fftSize {
                let sample = ring[(oldest + index) % fftSize]
                let window = 0.5 - 0.5 * cos(
                    2 * Double.pi * Double(index) / Double(fftSize - 1)
                )
                real[index] = sample * window
                imaginary[index] = 0
                squareSum += sample * sample
            }
            guard Self.fft(
                real: &real,
                imaginary: &imaginary,
                cancellationRequested: cancellationRequested
            ) else { return false }

            analyzedWindowCount += 1
            let rms = sqrt(squareSum / Double(fftSize))
            let rmsDB = rms > 0 ? 20 * log10(rms) : -120
            if let previousRMSDB {
                let delta = abs(rmsDB - previousRMSDB)
                trajectoryDeltaSum += delta
                trajectoryDeltaPeak = max(trajectoryDeltaPeak, delta)
                trajectoryTransitionCount += 1
            }
            previousRMSDB = rmsDB

            let binCount = fftSize / 2 + 1
            var magnitudeSum = 0.0
            var powerSum = 0.0
            for bin in 1..<binCount {
                let magnitude = hypot(real[bin], imaginary[bin])
                real[bin] = magnitude
                magnitudeSum += magnitude
                powerSum += magnitude * magnitude
            }
            guard magnitudeSum > 1e-15, powerSum > 1e-24 else {
                for bin in previousNormalizedMagnitude.indices {
                    previousNormalizedMagnitude[bin] = 0
                }
                return true
            }

            activeWindowCount += 1
            let binWidth = sampleRate / Double(fftSize)
            var weightedFrequency = 0.0
            var logarithmicPowerSum = 0.0
            let powerFloor = 1e-30
            for bin in 1..<binCount {
                let magnitude = real[bin]
                let frequency = Double(bin) * binWidth
                weightedFrequency += frequency * magnitude
                logarithmicPowerSum += log(magnitude * magnitude + powerFloor)
            }
            let centroid = weightedFrequency / magnitudeSum
            var bandwidthNumerator = 0.0
            var cumulativePower = 0.0
            var rolloff = 0.0
            let rolloffTarget = powerSum * 0.85
            var flux = 0.0
            for bin in 1..<binCount {
                let magnitude = real[bin]
                let frequency = Double(bin) * binWidth
                bandwidthNumerator += pow(frequency - centroid, 2) * magnitude
                cumulativePower += magnitude * magnitude
                if rolloff == 0, cumulativePower >= rolloffTarget {
                    rolloff = frequency
                }
                let normalized = magnitude / magnitudeSum
                flux += max(0, normalized - previousNormalizedMagnitude[bin])
                previousNormalizedMagnitude[bin] = normalized
            }
            let bandwidth = sqrt(bandwidthNumerator / magnitudeSum)
            let meanPower = powerSum / Double(binCount - 1)
            let flatness = exp(logarithmicPowerSum / Double(binCount - 1)) /
                max(meanPower, powerFloor)
            centroidSum += centroid
            centroidMinimum = min(centroidMinimum, centroid)
            centroidMaximum = max(centroidMaximum, centroid)
            bandwidthSum += bandwidth
            flatnessSum += flatness
            rolloffSum += rolloff
            if analyzedWindowCount > 1 {
                fluxSum += flux
                fluxPeak = max(fluxPeak, flux)
                fluxTransitionCount += 1
            }
            return true
        }

        var evidence: StreamingPerceptualEvidence {
            let activeDivisor = Double(max(1, activeWindowCount))
            let centroidMean = activeWindowCount > 0
                ? centroidSum / activeDivisor : 0
            let values = [
                centroidMean,
                activeWindowCount > 0 ? centroidMaximum - centroidMinimum : 0,
                bandwidthSum / activeDivisor,
                flatnessSum / activeDivisor,
                rolloffSum / activeDivisor,
                fluxTransitionCount > 0
                    ? fluxSum / Double(fluxTransitionCount) : 0,
                fluxPeak,
                trajectoryTransitionCount > 0
                    ? trajectoryDeltaSum / Double(trajectoryTransitionCount) : 0,
                trajectoryDeltaPeak,
            ]
            let scalarCount = fftSize * 3 + (fftSize / 2 + 1)
            return StreamingPerceptualEvidence(
                schemaVersion: StreamingPerceptualEvidence.schemaVersion,
                analyzerVersion: StreamingPerceptualEvidence.analyzerVersion,
                sourceFrameCount: sourceFrameCount,
                fftFrameCount: fftSize,
                hopFrameCount: hopSize,
                analyzedWindowCount: analyzedWindowCount,
                activeWindowCount: activeWindowCount,
                maximumBufferedFrameCount: min(sourceFrameCount, fftSize),
                peakWorkingByteCount: scalarCount * MemoryLayout<Double>.stride,
                spectralCentroidMeanHz: values[0],
                spectralCentroidSpreadHz: values[1],
                spectralBandwidthMeanHz: values[2],
                spectralFlatnessMean: values[3],
                spectralRolloff85MeanHz: values[4],
                positiveSpectralFluxMean: values[5],
                positiveSpectralFluxPeak: values[6],
                rmsTrajectoryDeltaMeanDB: values[7],
                rmsTrajectoryDeltaPeakDB: values[8],
                finite: finite && sampleRate.isFinite && sampleRate > 0 &&
                    values.allSatisfy { $0.isFinite }
            )
        }

        private static func fft(
            real: inout [Double],
            imaginary: inout [Double],
            cancellationRequested: @escaping @Sendable () -> Bool
        ) -> Bool {
            let count = real.count
            var destination = 0
            for source in 1..<count {
                var bit = count >> 1
                while destination & bit != 0 {
                    destination ^= bit
                    bit >>= 1
                }
                destination ^= bit
                if source < destination {
                    real.swapAt(source, destination)
                    imaginary.swapAt(source, destination)
                }
            }

            var length = 2
            while length <= count {
                guard !cancellationRequested() else { return false }
                let angle = -2 * Double.pi / Double(length)
                let stepReal = cos(angle)
                let stepImaginary = sin(angle)
                let half = length / 2
                var start = 0
                while start < count {
                    var twiddleReal = 1.0
                    var twiddleImaginary = 0.0
                    for offset in 0..<half {
                        let even = start + offset
                        let odd = even + half
                        let oddReal = real[odd] * twiddleReal -
                            imaginary[odd] * twiddleImaginary
                        let oddImaginary = real[odd] * twiddleImaginary +
                            imaginary[odd] * twiddleReal
                        let evenReal = real[even]
                        let evenImaginary = imaginary[even]
                        real[even] = evenReal + oddReal
                        imaginary[even] = evenImaginary + oddImaginary
                        real[odd] = evenReal - oddReal
                        imaginary[odd] = evenImaginary - oddImaginary
                        let nextReal = twiddleReal * stepReal -
                            twiddleImaginary * stepImaginary
                        twiddleImaginary = twiddleReal * stepImaginary +
                            twiddleImaginary * stepReal
                        twiddleReal = nextReal
                    }
                    start += length
                }
                length <<= 1
            }
            return true
        }
    }
}
