import AutoTechnoDSP
import Foundation
import Testing

@Suite("Streaming Perceptual Evidence")
struct StreamingPerceptualEvidenceTests {
    @Test("FFT geometry and tone evidence are physical-rate normalized")
    func rateNormalizedTone() throws {
        var centroids: [Double] = []
        for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
            let signal = sine(
                frequency: 1_000,
                amplitude: 0.25,
                duration: 1,
                sampleRate: sampleRate
            )
            let evidence = try #require(
                StreamingPerceptualEvidenceAnalyzer.analyze(
                    left: signal,
                    right: signal,
                    sampleRate: sampleRate
                )
            )
            #expect(evidence.isComplete)
            #expect(evidence.maximumBufferedFrameCount ==
                    evidence.analysisFrameCount)
            #expect(abs(
                Double(evidence.analysisFrameCount) / sampleRate -
                    StreamingPerceptualEvidenceAnalyzer.targetWindowSeconds
            ) < 0.000_05)
            #expect(abs(evidence.spectralCentroidMeanHz - 1_000) < 4)
            centroids.append(evidence.spectralCentroidMeanHz)
        }
        #expect((centroids.max() ?? 0) - (centroids.min() ?? 0) < 2)
    }

    @Test("Radix-two FFT agrees with an independent direct DFT")
    func independentDFTReference() throws {
        let sampleRate = 48_000.0
        let frameCount = StreamingPerceptualEvidenceAnalyzer.analysisFrameCount(
            sampleRate: sampleRate
        )
        let signal = (0..<frameCount).map { frame in
            Float(
                0.31 * sin(2 * Double.pi * 731 * Double(frame) / sampleRate) +
                0.12 * sin(2 * Double.pi * 2_113 * Double(frame) / sampleRate)
            )
        }
        let evidence = try #require(
            StreamingPerceptualEvidenceAnalyzer.analyze(
                left: signal,
                right: signal,
                sampleRate: sampleRate
            )
        )
        let reference = directDFTCentroid(
            signal,
            fftFrameCount: evidence.fftFrameCount,
            sampleRate: sampleRate
        )

        #expect(evidence.analyzedWindowCount == 1)
        #expect(abs(evidence.spectralCentroidMeanHz - reference) < 0.000_001)
    }

    @Test("Transient envelope and density use physical time at every rate")
    func rateNormalizedTransientDensity() {
        var densities: [Double] = []
        for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
            var signal = [Float](
                repeating: 0,
                count: Int((2 * sampleRate).rounded())
            )
            for time in stride(from: 0.1, through: 1.8, by: 0.1) {
                let frame = Int((time * sampleRate).rounded())
                signal[frame] = 0.8
            }
            let metrics = MusicalQualityMetrics(
                left: signal,
                right: signal,
                sampleRate: sampleRate
            )
            densities.append(metrics.transientDensity)
        }
        #expect((densities.max() ?? 0) - (densities.min() ?? 0) < 0.001)
    }

    @Test("Flatness and positive flux distinguish tone, noise, and change")
    func perceptualDimensions() throws {
        let sampleRate = 48_000.0
        let stable = sine(
            frequency: 500,
            amplitude: 0.2,
            duration: 1,
            sampleRate: sampleRate
        )
        let changed = sine(
            frequency: 500,
            amplitude: 0.2,
            duration: 0.5,
            sampleRate: sampleRate
        ) + sine(
            frequency: 4_000,
            amplitude: 0.2,
            duration: 0.5,
            sampleRate: sampleRate
        )
        let noise = deterministicNoise(
            frameCount: Int(sampleRate),
            amplitude: 0.2
        )
        let stableEvidence = try evidence(stable, sampleRate: sampleRate)
        let changedEvidence = try evidence(changed, sampleRate: sampleRate)
        let noiseEvidence = try evidence(noise, sampleRate: sampleRate)

        #expect(noiseEvidence.spectralFlatnessMean >
                stableEvidence.spectralFlatnessMean + 0.5)
        #expect(changedEvidence.positiveSpectralFluxPeak >
                stableEvidence.positiveSpectralFluxPeak + 0.4)
        #expect(changedEvidence.spectralCentroidSpreadHz > 3_000)
    }

    @Test("Working memory is fixed while phrase window count grows")
    func boundedWorkingMemory() throws {
        let sampleRate = 96_000.0
        let short = sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 1,
            sampleRate: sampleRate
        )
        let long = sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 8,
            sampleRate: sampleRate
        )
        let shortEvidence = try evidence(short, sampleRate: sampleRate)
        let longEvidence = try evidence(long, sampleRate: sampleRate)

        #expect(shortEvidence.peakWorkingByteCount ==
                longEvidence.peakWorkingByteCount)
        #expect(shortEvidence.maximumBufferedFrameCount ==
                longEvidence.maximumBufferedFrameCount)
        #expect(longEvidence.analyzedWindowCount >
                shortEvidence.analyzedWindowCount * 7)
        #expect(longEvidence.peakWorkingByteCount < 128 * 1_024)
    }

    @Test("Chunk boundaries preserve spectral, loudness, and true-peak evidence")
    func chunkBoundaryParity() throws {
        let sampleRate = 48_000.0
        let signal = (0..<Int(sampleRate * 4)).map { frame in
            Float(
                0.21 * sin(2 * Double.pi * 997 * Double(frame) / sampleRate) +
                0.07 * sin(2 * Double.pi * 11_300 * Double(frame) / sampleRate)
            )
        }
        let cut1 = 12_347
        let cut2 = 91_003
        let chunks = [
            Array(signal[..<cut1]),
            Array(signal[cut1..<cut2]),
            Array(signal[cut2...]),
        ]
        let contiguousPerceptual = try evidence(signal, sampleRate: sampleRate)
        let chunkedPerceptual = try #require(
            StreamingPerceptualEvidenceAnalyzer.analyze(
                leftChunks: chunks,
                rightChunks: chunks,
                sampleRate: sampleRate
            )
        )
        let contiguousLoudness = BS1770LoudnessMeasurement(
            left: signal,
            right: signal,
            sampleRate: sampleRate
        )
        let chunkedLoudness = try #require(BS1770LoudnessMeasurement(
            leftChunks: chunks,
            rightChunks: chunks,
            sampleRate: sampleRate
        ))
        let contiguousTruePeak = try #require(
            BS1770AudioEvidence.truePeak(signal)
        )
        let chunkedTruePeak = try #require(
            BS1770AudioEvidence.stereoTruePeak(
                leftChunks: chunks,
                rightChunks: chunks
            )
        )

        #expect(chunkedPerceptual == contiguousPerceptual)
        #expect(chunkedLoudness == contiguousLoudness)
        #expect(chunkedTruePeak.left == contiguousTruePeak)
        #expect(chunkedTruePeak.right == contiguousTruePeak)
    }

    @Test("Loudness rolling-window memory is duration-independent")
    func loudnessMemoryBound() {
        let sampleRate = 96_000.0
        let short = sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 1,
            sampleRate: sampleRate
        )
        let long = sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 8,
            sampleRate: sampleRate
        )
        let shortMeasurement = BS1770LoudnessMeasurement(
            left: short,
            right: short,
            sampleRate: sampleRate
        )
        let longMeasurement = BS1770LoudnessMeasurement(
            left: long,
            right: long,
            sampleRate: sampleRate
        )
        let expectedFrames = Int((sampleRate * 0.4).rounded()) +
            Int((sampleRate * 3).rounded())
        let expectedScratchScalars =
            BS1770LoudnessMeasurement.maximumMomentaryBlockCount * 4 +
            BS1770LoudnessMeasurement.maximumShortTermBlockCount * 3

        #expect(shortMeasurement.maximumBufferedFrameCount == expectedFrames)
        #expect(longMeasurement.maximumBufferedFrameCount == expectedFrames)
        #expect(shortMeasurement.peakWorkingByteCount ==
                longMeasurement.peakWorkingByteCount)
        #expect(longMeasurement.peakWorkingByteCount ==
                (expectedFrames + expectedScratchScalars) *
                MemoryLayout<Double>.stride)
    }

    @Test("Programme windows beyond the bounded phrase envelope are unavailable")
    func loudnessProgrammeBound() {
        let sampleRate = 8_000.0
        let overBound = sine(
            frequency: 997,
            amplitude: 0.1,
            duration: BS1770LoudnessMeasurement.maximumProgrammeSeconds + 1,
            sampleRate: sampleRate
        )
        let measurement = BS1770LoudnessMeasurement(
            left: overBound,
            right: overBound,
            sampleRate: sampleRate
        )

        #expect(!measurement.integratedLoudness.isFinite)
        #expect(measurement.momentaryBlockCount == 0)
        #expect(measurement.relativeGatedBlockCount == 0)
    }

    @Test("Cancellation and non-finite PCM remain explicit")
    func adversarialInputs() throws {
        let sampleRate = 48_000.0
        let signal = sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 1,
            sampleRate: sampleRate
        )
        #expect(StreamingPerceptualEvidenceAnalyzer.analyze(
            left: signal,
            right: signal,
            sampleRate: sampleRate,
            cancellationRequested: { true }
        ) == nil)

        var invalid = signal
        invalid[invalid.count / 2] = .nan
        let invalidEvidence = try #require(
            StreamingPerceptualEvidenceAnalyzer.analyze(
                left: invalid,
                right: signal,
                sampleRate: sampleRate
            )
        )
        #expect(!invalidEvidence.finite)
        // Failed PCM remains a structurally complete record so a rejected
        // candidate can retain exact analyzer provenance.
        #expect(invalidEvidence.isComplete)

        invalid = signal
        invalid[invalid.count - 1] = .infinity
        let trailingInvalidLoudness = BS1770LoudnessMeasurement(
            left: invalid,
            right: signal,
            sampleRate: sampleRate
        )
        #expect(!trailingInvalidLoudness.integratedLoudness.isFinite)
    }

    private func evidence(
        _ samples: [Float],
        sampleRate: Double
    ) throws -> StreamingPerceptualEvidence {
        try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
            left: samples,
            right: samples,
            sampleRate: sampleRate
        ))
    }

    private func sine(
        frequency: Double,
        amplitude: Double,
        duration: Double,
        sampleRate: Double
    ) -> [Float] {
        (0..<Int((duration * sampleRate).rounded())).map { frame in
            Float(amplitude * sin(
                2 * Double.pi * frequency * Double(frame) / sampleRate
            ))
        }
    }

    private func deterministicNoise(
        frameCount: Int,
        amplitude: Double
    ) -> [Float] {
        var state: UInt64 = 0x9e3779b97f4a7c15
        return (0..<frameCount).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let unit = Double(state >> 11) / Double(UInt64.max >> 11)
            return Float((unit * 2 - 1) * amplitude)
        }
    }

    private func directDFTCentroid(
        _ samples: [Float],
        fftFrameCount: Int,
        sampleRate: Double
    ) -> Double {
        let analysisCount = samples.count
        var magnitudeSum = 0.0
        var weightedFrequency = 0.0
        for bin in 1...fftFrameCount / 2 {
            var real = 0.0
            var imaginary = 0.0
            for frame in 0..<analysisCount {
                let window = 0.5 - 0.5 * cos(
                    2 * Double.pi * Double(frame) /
                        Double(analysisCount - 1)
                )
                let phase = -2 * Double.pi * Double(bin * frame) /
                    Double(fftFrameCount)
                let sample = Double(samples[frame]) * window
                real += sample * cos(phase)
                imaginary += sample * sin(phase)
            }
            let magnitude = hypot(real, imaginary)
            let frequency = Double(bin) * sampleRate /
                Double(fftFrameCount)
            magnitudeSum += magnitude
            weightedFrequency += frequency * magnitude
        }
        return weightedFrequency / magnitudeSum
    }
}
