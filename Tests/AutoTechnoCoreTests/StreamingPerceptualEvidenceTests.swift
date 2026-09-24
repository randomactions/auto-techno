import AutoTechnoDSP
import Foundation
import Testing

@Suite("Streaming Perceptual Evidence")
struct StreamingPerceptualEvidenceTests {
    @Test("FFT geometry and tone evidence are physical-rate normalized")
    func rateNormalizedTone() throws {
        var centroids: [Double] = []
        for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
            let signal = try sine(
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
        let reference = directDFTSpectralMetrics(
            signal,
            fftFrameCount: evidence.fftFrameCount,
            sampleRate: sampleRate
        )

        #expect(evidence.analyzedWindowCount == 1)
        #expect(abs(evidence.spectralCentroidMeanHz - reference.centroid) <
                0.000_001)
        #expect(abs(evidence.spectralBandwidthMeanHz - reference.bandwidth) <
                0.000_001)
        #expect(abs(evidence.spectralRolloff85MeanHz - reference.rolloff85) <
                0.000_001)
    }

    @Test("Spectral flatness matches the positive-bin power-floor reference")
    func spectralFlatnessDirectDFTReference() throws {
        let sampleRate = 48_000.0
        let frameCount = StreamingPerceptualEvidenceAnalyzer
            .analysisFrameCount(sampleRate: sampleRate)
        let fftFrameCount = StreamingPerceptualEvidenceAnalyzer
            .fftFrameCount(sampleRate: sampleRate)
        let tone = try sine(
            frequency: 997,
            amplitude: 0.2,
            duration: Double(frameCount) / sampleRate,
            sampleRate: sampleRate
        )
        let noise = try DeterministicSignalFixtures.uniformNoise(
            frameCount: frameCount, amplitude: 0.2,
            seed: 0x9E3779B97F4A7C15
        )
        let toneEvidence = try evidence(tone, sampleRate: sampleRate)
        let noiseEvidence = try evidence(noise, sampleRate: sampleRate)
        let toneReference = directDFTSpectralMetrics(
            tone,
            fftFrameCount: fftFrameCount,
            sampleRate: sampleRate
        )
        let noiseReference = directDFTSpectralMetrics(
            noise,
            fftFrameCount: fftFrameCount,
            sampleRate: sampleRate
        )

        #expect(toneEvidence.analyzedWindowCount == 1)
        #expect(noiseEvidence.analyzedWindowCount == 1)
        #expect(toneEvidence.activeWindowCount == 1)
        #expect(noiseEvidence.activeWindowCount == 1)
        #expect(abs(
            toneEvidence.spectralFlatnessMean - toneReference.flatness
        ) < 0.000_001)
        #expect(abs(
            noiseEvidence.spectralFlatnessMean - noiseReference.flatness
        ) < 0.000_001)
        #expect(noiseEvidence.spectralFlatnessMean >
                toneEvidence.spectralFlatnessMean + 0.5)
    }

    @Test("Sparse high-frequency burst controls windowed spectral extrema")
    func sparseHighFrequencyBurstWindowInfluence() throws {
        let sampleRate = 48_000.0
        let analysisFrames = StreamingPerceptualEvidenceAnalyzer
            .analysisFrameCount(sampleRate: sampleRate)
        let fftFrames = StreamingPerceptualEvidenceAnalyzer
            .fftFrameCount(sampleRate: sampleRate)
        let hopFrames = analysisFrames / 2
        let sourceFrames = analysisFrames + hopFrames * 2

        let stable = (0..<sourceFrames).map { frame in
            Float(0.08 * sin(
                2 * Double.pi * 500 * Double(frame) / sampleRate
            ))
        }
        var transient = stable
        for frame in analysisFrames - 200..<analysisFrames - 100 {
            transient[frame] += Float(0.8 * sin(
                2 * Double.pi * 12_000 * Double(frame - analysisFrames + 200) /
                    sampleRate
            ))
        }

        func evidence(_ samples: [Float]) throws
            -> StreamingPerceptualEvidence {
            try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
                left: samples,
                right: samples,
                sampleRate: sampleRate
            ))
        }

        func reference(_ samples: [Float]) -> [(
            centroid: Double,
            bandwidth: Double,
            rolloff85: Double,
            flatness: Double
        )] {
            stride(
                from: 0,
                through: samples.count - analysisFrames,
                by: hopFrames
            ).map { start in
                directDFTSpectralMetrics(
                    Array(samples[start..<(start + analysisFrames)]),
                    fftFrameCount: fftFrames,
                    sampleRate: sampleRate
                )
            }
        }

        let stableEvidence = try evidence(stable)
        let transientEvidence = try evidence(transient)
        let stableReference = reference(stable)
        let transientReference = reference(transient)
        let stableCentroids = stableReference.map(\.centroid)
        let stableCentroidSpread =
            (stableCentroids.max() ?? 0) - (stableCentroids.min() ?? 0)
        let expectedCentroidMean = transientReference.map(\.centroid)
            .reduce(0, +) / Double(transientReference.count)
        let expectedCentroidSpread = (transientReference.map(\.centroid).max() ?? 0) -
            (transientReference.map(\.centroid).min() ?? 0)
        let expectedBandwidthMean = transientReference.map(\.bandwidth)
            .reduce(0, +) / Double(transientReference.count)
        let expectedRolloffMean = transientReference.map(\.rolloff85)
            .reduce(0, +) / Double(transientReference.count)
        let expectedFlatnessMean = transientReference.map(\.flatness)
            .reduce(0, +) / Double(transientReference.count)

        #expect(stableEvidence.analyzedWindowCount == 3)
        #expect(transientEvidence.analyzedWindowCount == 3)
        #expect(transientEvidence.activeWindowCount == 3)
        #expect(abs(
            transientEvidence.spectralCentroidMeanHz - expectedCentroidMean
        ) < 0.000_001)
        #expect(abs(
            transientEvidence.spectralCentroidSpreadHz - expectedCentroidSpread
        ) < 0.000_001)
        #expect(abs(
            transientEvidence.spectralBandwidthMeanHz - expectedBandwidthMean
        ) < 0.000_001)
        #expect(abs(
            transientEvidence.spectralRolloff85MeanHz - expectedRolloffMean
        ) < 0.000_001)
        #expect(abs(
            transientEvidence.spectralFlatnessMean - expectedFlatnessMean
        ) < 0.000_001)
        #expect(transientEvidence.spectralCentroidMeanHz >
                stableEvidence.spectralCentroidMeanHz + 500)
        #expect(transientEvidence.spectralCentroidSpreadHz >
                stableCentroidSpread + 500)
    }

    @Test("RMS peak delta exposes the analysis-window grid")
    func trajectoryPeakWindowGridOffset() throws {
        let sampleRate = 48_000.0
        let frameCount = Int(sampleRate)
        let windowFrames = StreamingPerceptualEvidenceAnalyzer
            .analysisFrameCount(sampleRate: sampleRate)
        let hopFrames = windowFrames / 2

        func burst(offset: Int) -> [Float] {
            var samples = [Float](repeating: 0, count: frameCount)
            for frame in offset..<(offset + Int(sampleRate * 0.25)) {
                samples[frame] = 0.2
            }
            return samples
        }

        func referenceTrajectory(_ samples: [Float]) -> (Int, Double, Double) {
            var levels: [Double] = []
            var start = 0
            while start + windowFrames <= samples.count {
                let squareSum = samples[start..<(start + windowFrames)]
                    .reduce(0.0) { $0 + Double($1 * $1) }
                let rms = sqrt(squareSum / Double(windowFrames))
                levels.append(rms > 0 ? 20 * log10(rms) : -120)
                start += hopFrames
            }
            let deltas = zip(levels, levels.dropFirst()).map { abs($1 - $0) }
            return (
                levels.count,
                deltas.reduce(0, +) / Double(max(1, deltas.count)),
                deltas.max() ?? 0
            )
        }

        let alignedSamples = burst(offset: 0)
        let shiftedSamples = burst(offset: hopFrames / 4)
        let aligned = try evidence(alignedSamples, sampleRate: sampleRate)
        let shifted = try evidence(shiftedSamples, sampleRate: sampleRate)
        let alignedReference = referenceTrajectory(alignedSamples)
        let shiftedReference = referenceTrajectory(shiftedSamples)

        #expect(aligned.analyzedWindowCount == alignedReference.0)
        #expect(shifted.analyzedWindowCount == shiftedReference.0)
        #expect(abs(
            aligned.rmsTrajectoryDeltaMeanDB - alignedReference.1
        ) < 0.000_001)
        #expect(abs(
            shifted.rmsTrajectoryDeltaMeanDB - shiftedReference.1
        ) < 0.000_001)
        #expect(abs(
            aligned.rmsTrajectoryDeltaPeakDB - alignedReference.2
        ) < 0.000_001)
        #expect(abs(
            shifted.rmsTrajectoryDeltaPeakDB - shiftedReference.2
        ) < 0.000_001)
        #expect(abs(
            aligned.rmsTrajectoryDeltaPeakDB -
                shifted.rmsTrajectoryDeltaPeakDB
        ) > 2)
        #expect(abs(
            aligned.rmsTrajectoryDeltaMeanDB -
                shifted.rmsTrajectoryDeltaMeanDB
        ) > 0.01)
    }

    @Test("Active-window population and RMS trajectory preserve silence transitions")
    func activityAndTrajectoryWindowPopulation() throws {
        let sampleRate = 48_000.0
        let frameCount = Int(sampleRate)
        var signal = [Float](repeating: 0, count: frameCount)
        for frame in 0..<(frameCount / 2) {
            signal[frame] = Float(
                0.2 * sin(2 * Double.pi * 500 * Double(frame) / sampleRate)
            )
        }

        let measured = try evidence(signal, sampleRate: sampleRate)
        let silent = try evidence(
            [Float](repeating: 0, count: frameCount),
            sampleRate: sampleRate
        )

        #expect(measured.isComplete)
        #expect(measured.activeWindowCount > 0)
        #expect(measured.activeWindowCount < measured.analyzedWindowCount)
        #expect((0...1).contains(
            Double(measured.activeWindowCount) /
                Double(measured.analyzedWindowCount)
        ))
        #expect(silent.activeWindowCount == 0)
        #expect(silent.spectralFlatnessMean == 0)
        #expect(measured.rmsTrajectoryDeltaMeanDB > 0)
        #expect(measured.rmsTrajectoryDeltaPeakDB >
                measured.rmsTrajectoryDeltaMeanDB)
        #expect(measured.rmsTrajectoryDeltaPeakDB > 60)
    }

    @Test("Active-window ratio follows mono energy, numerical floors, and grid phase")
    func activeWindowRatioPopulationAndGrid() throws {
        let sampleRate = 48_000.0
        let analysisFrames = StreamingPerceptualEvidenceAnalyzer
            .analysisFrameCount(sampleRate: sampleRate)
        let fftFrames = StreamingPerceptualEvidenceAnalyzer
            .fftFrameCount(sampleRate: sampleRate)
        let hopFrames = analysisFrames / 2
        let sourceFrames = analysisFrames + hopFrames * 4

        func burst(offset: Int, amplitude: Double) -> [Float] {
            var samples = [Float](repeating: 0, count: sourceFrames)
            for frame in offset..<(offset + analysisFrames) {
                samples[frame] = Float(
                    amplitude * sin(
                        2 * Double.pi * 997 * Double(frame) / sampleRate
                    )
                )
            }
            return samples
        }

        func expectedActiveWindows(_ mono: [Float]) -> Int {
            stride(
                from: 0,
                through: mono.count - analysisFrames,
                by: hopFrames
            ).filter { start in
                directDFTNormalizedMagnitudes(
                    Array(mono[start..<(start + analysisFrames)]),
                    fftFrameCount: fftFrames
                ) != nil
            }.count
        }

        let aligned = burst(offset: 0, amplitude: 0.2)
        let quarterHopShifted = burst(offset: hopFrames / 2, amplitude: 0.2)
        let alignedEvidence = try evidence(aligned, sampleRate: sampleRate)
        let shiftedEvidence = try evidence(quarterHopShifted, sampleRate: sampleRate)
        let alignedExpected = expectedActiveWindows(aligned)
        let shiftedExpected = expectedActiveWindows(quarterHopShifted)

        #expect(alignedEvidence.analyzedWindowCount == 5)
        #expect(shiftedEvidence.analyzedWindowCount == 5)
        #expect(alignedEvidence.activeWindowCount == alignedExpected)
        #expect(shiftedEvidence.activeWindowCount == shiftedExpected)
        #expect(alignedEvidence.activeWindowCount == 2)
        #expect(shiftedEvidence.activeWindowCount == 3)
        #expect(Double(alignedEvidence.activeWindowCount) / 5 == 0.4)
        #expect(Double(shiftedEvidence.activeWindowCount) / 5 == 0.6)

        let inPhase = try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
            left: aligned,
            right: aligned,
            sampleRate: sampleRate
        ))
        let oppositePhase = try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
            left: aligned,
            right: aligned.map { -$0 },
            sampleRate: sampleRate
        ))
        #expect(inPhase.activeWindowCount == alignedExpected)
        #expect(oppositePhase.activeWindowCount == 0)

        let quiet = burst(offset: 0, amplitude: 1e-16)
        let quietEvidence = try evidence(quiet, sampleRate: sampleRate)
        #expect(expectedActiveWindows(quiet) == 0)
        #expect(quietEvidence.activeWindowCount == 0)
    }

    @Test("Transient envelope and density use physical time at every rate")
    func rateNormalizedTransientDensity() throws {
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
        let stable = try sine(
            frequency: 500,
            amplitude: 0.2,
            duration: 1,
            sampleRate: sampleRate
        )
        let changed = try sine(
            frequency: 500,
            amplitude: 0.2,
            duration: 0.5,
            sampleRate: sampleRate
        ) + (try sine(
            frequency: 4_000,
            amplitude: 0.2,
            duration: 0.5,
            sampleRate: sampleRate
        ))
        let noise = try DeterministicSignalFixtures.uniformNoise(
            frameCount: Int(sampleRate),
            amplitude: 0.2,
            seed: 0x9E3779B97F4A7C15
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

    @Test("Normalized flux remains bounded across exact silence")
    func normalizedFluxBounds() throws {
        for sampleRate in [44_100.0, 48_000.0] {
            let silence = try DeterministicSignalFixtures.silence(
                frameCount: Int(sampleRate * 0.5)
            )
            let onset = try DeterministicSignalFixtures.uniformNoise(
                frameCount: Int(sampleRate * 0.5),
                amplitude: 0.2,
                seed: 0x9E3779B97F4A7C15
            )
            let measured = try evidence(
                silence + onset,
                sampleRate: sampleRate
            )

            #expect(measured.isComplete)
            #expect((0...1).contains(measured.positiveSpectralFluxMean))
            #expect((0...1).contains(measured.positiveSpectralFluxPeak))
        }
    }

    @Test("Positive spectral flux resets across inactive windows")
    func spectralFluxActivityResetPopulation() throws {
        let sampleRate = 48_000.0
        let analysisFrames = StreamingPerceptualEvidenceAnalyzer
            .analysisFrameCount(sampleRate: sampleRate)
        let fftFrames = StreamingPerceptualEvidenceAnalyzer
            .fftFrameCount(sampleRate: sampleRate)
        let hopFrames = analysisFrames / 2
        let sourceFrames = analysisFrames + hopFrames * 6
        let continuous = try sine(
            frequency: 500,
            amplitude: 0.1,
            duration: Double(sourceFrames) / sampleRate,
            sampleRate: sampleRate
        )
        var interrupted = [Float](repeating: 0, count: sourceFrames)
        for frame in 0..<3_000 {
            interrupted[frame] = Float(
                0.1 * sin(2 * Double.pi * 500 * Double(frame) / sampleRate)
            )
        }
        for frame in 5_000..<sourceFrames {
            interrupted[frame] = Float(
                0.1 * sin(2 * Double.pi * 500 * Double(frame) / sampleRate)
            )
        }

        func expectedFlux(_ samples: [Float]) -> (Int, Int, Double, Double) {
            var previous = [Double](repeating: 0, count: fftFrames / 2)
            var analyzed = 0
            var active = 0
            var transitionCount = 0
            var fluxSum = 0.0
            var fluxPeak = 0.0
            var start = 0
            while start + analysisFrames <= samples.count {
                let window = Array(samples[start..<(start + analysisFrames)])
                if let normalized = directDFTNormalizedMagnitudes(
                    window,
                    fftFrameCount: fftFrames
                ) {
                    active += 1
                    if analyzed > 0 {
                        let flux = zip(normalized, previous).reduce(0.0) {
                            $0 + max(0, $1.0 - $1.1)
                        }
                        let bounded = min(1, max(0, flux))
                        fluxSum += bounded
                        fluxPeak = max(fluxPeak, bounded)
                        transitionCount += 1
                    }
                    previous = normalized
                } else {
                    previous = [Double](repeating: 0, count: fftFrames / 2)
                }
                analyzed += 1
                start += hopFrames
            }
            return (
                analyzed,
                active,
                transitionCount > 0
                    ? fluxSum / Double(transitionCount) : 0,
                fluxPeak
            )
        }

        let continuousEvidence = try evidence(continuous, sampleRate: sampleRate)
        let interruptedEvidence = try evidence(interrupted, sampleRate: sampleRate)
        let continuousReference = expectedFlux(continuous)
        let interruptedReference = expectedFlux(interrupted)

        #expect(continuousEvidence.analyzedWindowCount ==
                continuousReference.0)
        #expect(continuousEvidence.activeWindowCount == continuousReference.1)
        #expect(abs(
            continuousEvidence.positiveSpectralFluxMean -
                continuousReference.2
        ) < 0.000_01)
        #expect(abs(
            continuousEvidence.positiveSpectralFluxPeak -
                continuousReference.3
        ) < 0.000_01)
        #expect(interruptedEvidence.analyzedWindowCount ==
                interruptedReference.0)
        #expect(interruptedEvidence.activeWindowCount ==
                interruptedReference.1)
        #expect(interruptedEvidence.activeWindowCount == 6)
        #expect(abs(
            interruptedEvidence.positiveSpectralFluxMean -
                interruptedReference.2
        ) < 0.000_01)
        #expect(abs(
            interruptedEvidence.positiveSpectralFluxPeak -
                interruptedReference.3
        ) < 0.000_01)
        #expect(interruptedEvidence.positiveSpectralFluxPeak >
                continuousEvidence.positiveSpectralFluxPeak + 0.5)
    }

    @Test("Working memory is fixed while phrase window count grows")
    func boundedWorkingMemory() throws {
        let sampleRate = 96_000.0
        let short = try sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 1,
            sampleRate: sampleRate
        )
        let long = try sine(
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
    func loudnessMemoryBound() throws {
        let sampleRate = 96_000.0
        let short = try sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 1,
            sampleRate: sampleRate
        )
        let long = try sine(
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
    func loudnessProgrammeBound() throws {
        let sampleRate = 8_000.0
        let overBound = try sine(
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
        let signal = try sine(
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
    ) throws -> [Float] {
        try DeterministicSignalFixtures.sine(
            frameCount: Int((duration * sampleRate).rounded()),
            sampleRate: sampleRate,
            frequencyHz: frequency,
            amplitude: amplitude
        )
    }

    private func directDFTSpectralMetrics(
        _ samples: [Float],
        fftFrameCount: Int,
        sampleRate: Double
    ) -> (
        centroid: Double,
        bandwidth: Double,
        rolloff85: Double,
        flatness: Double
    ) {
        let analysisCount = samples.count
        var magnitudes: [(frequency: Double, magnitude: Double, power: Double)] = []
        var magnitudeSum = 0.0
        var powerSum = 0.0
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
            magnitudes.append((frequency, magnitude, magnitude * magnitude))
            magnitudeSum += magnitude
            powerSum += magnitude * magnitude
        }
        let centroid = magnitudes.reduce(0.0) {
            $0 + $1.frequency * $1.magnitude
        } / magnitudeSum
        let bandwidth = sqrt(magnitudes.reduce(0.0) {
            $0 + pow($1.frequency - centroid, 2) * $1.magnitude
        } / magnitudeSum)
        let rolloffTarget = powerSum * 0.85
        var cumulativePower = 0.0
        let rolloff85 = magnitudes.first { bin in
            cumulativePower += bin.power
            return cumulativePower >= rolloffTarget
        }?.frequency ?? 0
        let powerFloor = 1e-30
        let logarithmicPowerMean = magnitudes.reduce(0.0) {
            $0 + log($1.power + powerFloor)
        } / Double(magnitudes.count)
        let meanPower = powerSum / Double(magnitudes.count)
        let flatness = exp(logarithmicPowerMean) / max(meanPower, powerFloor)
        return (centroid, bandwidth, rolloff85, flatness)
    }

    private func directDFTNormalizedMagnitudes(
        _ samples: [Float],
        fftFrameCount: Int
    ) -> [Double]? {
        var magnitudes: [Double] = []
        var magnitudeSum = 0.0
        var powerSum = 0.0
        for bin in 1...fftFrameCount / 2 {
            var real = 0.0
            var imaginary = 0.0
            for frame in samples.indices {
                let window = 0.5 - 0.5 * cos(
                    2 * Double.pi * Double(frame) / Double(samples.count - 1)
                )
                let phase = -2 * Double.pi * Double(bin * frame) /
                    Double(fftFrameCount)
                let sample = Double(samples[frame]) * window
                real += sample * cos(phase)
                imaginary += sample * sin(phase)
            }
            let magnitude = hypot(real, imaginary)
            magnitudes.append(magnitude)
            magnitudeSum += magnitude
            powerSum += magnitude * magnitude
        }
        guard magnitudeSum > 1e-15, powerSum > 1e-24 else { return nil }
        return magnitudes.map { $0 / magnitudeSum }
    }
}
