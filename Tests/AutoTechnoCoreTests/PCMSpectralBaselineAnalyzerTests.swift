import Foundation
import Testing
@testable import AutoTechnoDSP

@Suite("PCM spectral baseline evidence")
struct PCMSpectralBaselineAnalyzerTests {
    @Test("Low and high tones retain causal band and occupancy sign")
    func lowAndHighBandSign() throws {
        let sampleRate = 48_000.0
        let low = sine(frequency: 60, sampleRate: sampleRate)
        let high = sine(frequency: 4_000, sampleRate: sampleRate)
        let lowEvidence = try #require(analyze(low, sampleRate: sampleRate))
        let highEvidence = try #require(analyze(high, sampleRate: sampleRate))

        #expect(lowEvidence.summary.subBandShareMean >
                highEvidence.summary.subBandShareMean + 0.5)
        #expect(lowEvidence.summary.lowEndOccupancy == 1)
        #expect(highEvidence.summary.lowEndOccupancy == 0)
        #expect(lowEvidence.summary.bandShares[0] > 0.5)
        #expect(highEvidence.summary.bandShares[3] > 0.5)
        #expect(abs(lowEvidence.summary.spectralCentroidMeanHz - 60) < 8)
        #expect(abs(highEvidence.summary.spectralCentroidMeanHz - 4_000) < 8)
    }

    @Test("Canonical spectral shape distinguishes tone, mixture, and noise")
    func shapeFixtures() throws {
        let sampleRate = 48_000.0
        let tone = sine(frequency: 500, sampleRate: sampleRate)
        let mixture = zip(
            tone,
            sine(frequency: 4_000, amplitude: 0.12, sampleRate: sampleRate)
        ).map { $0.0 + $0.1 }
        let noise = deterministicNoise(frameCount: tone.count, amplitude: 0.2)
        let toneEvidence = try #require(analyze(tone, sampleRate: sampleRate))
        let mixtureEvidence = try #require(analyze(mixture, sampleRate: sampleRate))
        let noiseEvidence = try #require(analyze(noise, sampleRate: sampleRate))

        #expect(mixtureEvidence.summary.spectralCentroidMeanHz >
                toneEvidence.summary.spectralCentroidMeanHz + 700)
        #expect(mixtureEvidence.summary.spectralRolloff85MeanHz >
                toneEvidence.summary.spectralRolloff85MeanHz + 2_000)
        #expect(noiseEvidence.summary.spectralFlatnessMean >
                toneEvidence.summary.spectralFlatnessMean + 0.5)
    }

    @Test("Silence and DC are valid measured states, not unavailable evidence")
    func silenceAndDC() throws {
        let sampleRate = 48_000.0
        let frameCount = Int(sampleRate)
        let silence = [Float](repeating: 0, count: frameCount)
        let dc = [Float](repeating: 0.2, count: frameCount)
        let silenceEvidence = try #require(analyze(silence, sampleRate: sampleRate))
        let dcEvidence = try #require(analyze(dc, sampleRate: sampleRate))

        #expect(silenceEvidence.summary.windowCount == 16)
        #expect(silenceEvidence.summary.activeSpectralWindowCount == 0)
        #expect(silenceEvidence.summary.sourceActiveWindowCount == 0)
        #expect(silenceEvidence.summary.lowEndOccupancy == 0)
        #expect(silenceEvidence.summary.bandMeanSquares.allSatisfy { $0 == 0 })
        #expect(silenceEvidence.summary.finite)

        #expect(dcEvidence.summary.sourceActiveWindowCount == 16)
        #expect(dcEvidence.summary.sourceMeanSquare > 0.039)
        #expect(dcEvidence.summary.finite)
    }

    @Test("Bar and FFT geometry remain physical-rate normalized")
    func routeGeometry() throws {
        for sampleRate in [44_100.0, 48_000.0] {
            let segmentFrames = Int((sampleRate * 240 / 130).rounded())
            let signal = sine(
                frequency: 997,
                frameCount: segmentFrames,
                sampleRate: sampleRate
            )
            let evidence = try #require(PCMSpectralBaselineAnalyzer.analyze(
                channels: [signal],
                sampleRate: sampleRate,
                segmentFrameCount: segmentFrames
            ))

            #expect(evidence.segments.count == 1)
            #expect(evidence.summary.frameCount == segmentFrames)
            #expect(evidence.summary.windowCount == 16)
            #expect(evidence.spectrumFrameCount ==
                    StreamingPerceptualEvidenceAnalyzer.analysisFrameCount(
                        sampleRate: sampleRate
                    ))
            #expect(evidence.fftFrameCount == 2_048)
            var nextStart = 0
            for window in evidence.segments[0].windows {
                #expect(window.cellStartFrame == nextStart)
                nextStart += window.cellFrameCount
                #expect(window.spectrumFrameCount == evidence.spectrumFrameCount)
                #expect(window.spectrumStartFrame >= 0)
                #expect(window.spectrumStartFrame + window.spectrumFrameCount <=
                        segmentFrames)
            }
            #expect(nextStart == segmentFrames)
        }
    }

    @Test("Window facts exactly reuse both canonical analyzers")
    func canonicalOwnerParity() throws {
        let sampleRate = 48_000.0
        let signal = sine(frequency: 731, sampleRate: sampleRate)
        let evidence = try #require(analyze(signal, sampleRate: sampleRate))
        let window = evidence.segments[0].windows[7]
        let spectrumEnd = window.spectrumStartFrame + window.spectrumFrameCount
        let samples = Array(signal[window.spectrumStartFrame..<spectrumEnd])
        let spectrum = try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
            left: samples,
            right: samples,
            sampleRate: sampleRate
        ))
        let causal = try #require(SpectrumMaskingAnalyzer.bandEnergyWindows(
            signal,
            sampleRate: sampleRate
        ))[7]

        #expect(window.spectralCentroidHz == spectrum.spectralCentroidMeanHz)
        #expect(window.spectralBandwidthHz == spectrum.spectralBandwidthMeanHz)
        #expect(window.spectralRolloff85Hz == spectrum.spectralRolloff85MeanHz)
        #expect(window.spectralFlatness == spectrum.spectralFlatnessMean)
        #expect(window.sourceMeanSquare == causal.sourceMeanSquare)
        #expect(window.bandMeanSquares == causal.bandMeanSquares)
    }

    @Test("Mono fold, boundary cells, and malformed inputs fail truthfully")
    func boundariesAndInvalidInputs() throws {
        let sampleRate = 48_000.0
        let frameCount = Int(sampleRate)
        var impulses = [Float](repeating: 0, count: frameCount)
        impulses[0] = 0.8
        impulses[frameCount - 1] = -0.8
        let evidence = try #require(analyze(impulses, sampleRate: sampleRate))
        #expect(evidence.segments[0].windows[0].sourceActive)
        #expect(evidence.segments[0].windows[15].sourceActive)

        let cancelled = try #require(PCMSpectralBaselineAnalyzer.analyze(
            channels: [impulses, impulses.map { -$0 }],
            sampleRate: sampleRate,
            segmentFrameCount: frameCount
        ))
        #expect(cancelled.summary.sourceMeanSquare == 0)
        #expect(cancelled.summary.activeSpectralWindowCount == 0)

        var invalid = impulses
        invalid[10] = .nan
        #expect(PCMSpectralBaselineAnalyzer.analyze(
            channels: [invalid], sampleRate: sampleRate,
            segmentFrameCount: frameCount
        ) == nil)
        #expect(PCMSpectralBaselineAnalyzer.analyze(
            channels: [impulses, Array(impulses.dropLast())],
            sampleRate: sampleRate,
            segmentFrameCount: frameCount
        ) == nil)
        #expect(PCMSpectralBaselineAnalyzer.analyze(
            channels: [[Float](repeating: 0, count: 100)],
            sampleRate: sampleRate,
            segmentFrameCount: 100
        ) == nil)
    }

    private func analyze(
        _ samples: [Float],
        sampleRate: Double
    ) -> PCMSpectralBaselineEvidence? {
        PCMSpectralBaselineAnalyzer.analyze(
            channels: [samples],
            sampleRate: sampleRate,
            segmentFrameCount: samples.count
        )
    }

    private func sine(
        frequency: Double,
        amplitude: Double = 0.2,
        frameCount: Int? = nil,
        sampleRate: Double
    ) -> [Float] {
        let count = frameCount ?? Int(sampleRate)
        return (0..<count).map { frame in
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
}
