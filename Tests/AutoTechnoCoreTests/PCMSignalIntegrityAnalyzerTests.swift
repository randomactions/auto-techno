import AutoTechnoDSP
import Foundation
import Testing

@Suite("PCM signal-integrity evidence")
struct PCMSignalIntegrityAnalyzerTests {
    @Test("Impulse, RMS, crest, DC, clipping, and bar segments retain units")
    func levelAndSegmentMetrics() throws {
        let evidence = try #require(PCMSignalIntegrityAnalyzer.analyze(
            channels: [[-1, 0, 1, 0]],
            sampleRate: 44_100,
            segmentFrameCount: 2
        ))

        #expect(evidence.schema == PCMSignalIntegrityEvidence.schema)
        #expect(evidence.channelCount == 1)
        #expect(evidence.frameCount == 4)
        #expect(evidence.segments.count == 2)
        #expect(evidence.segments.map(\.startFrame) == [0, 2])
        #expect(evidence.segments.allSatisfy { $0.frameCount == 2 })
        #expect(evidence.combined.samplePeak == 1)
        #expect(evidence.combined.samplePeakDBFS == 0)
        #expect(abs(try #require(evidence.combined.rms) - sqrt(0.5)) < 1e-12)
        #expect(abs(try #require(evidence.combined.crestFactor) - sqrt(2)) < 1e-12)
        #expect(evidence.combined.dcOffset == 0)
        #expect(evidence.combined.clippedSampleCount == 2)
        #expect(evidence.combined.exactZeroSampleCount == 2)
        #expect(evidence.combined.nearSilenceSampleCount == 2)
        #expect(evidence.nearSilentFrameCount == 2)
        #expect(evidence.longestNearSilentFrameRun == 1)
        #expect(try #require(evidence.combined.truePeak) >= 1)
    }

    @Test("Stereo silence requires every channel and preserves the longest run")
    func stereoSilenceRuns() throws {
        let threshold = Float(PCMSignalIntegrityAnalyzer.nearSilenceAmplitude)
        let evidence = try #require(PCMSignalIntegrityAnalyzer.analyze(
            channels: [
                [0, threshold * 0.5, threshold * 2, 0, 0],
                [0, 0, 0, 0, threshold * 2],
            ],
            sampleRate: 48_000,
            segmentFrameCount: 5
        ))

        #expect(evidence.nearSilentFrameCount == 3)
        #expect(evidence.longestNearSilentFrameRun == 2)
        #expect(evidence.channels[0].nearSilenceSampleCount == 4)
        #expect(evidence.channels[1].nearSilenceSampleCount == 4)
        #expect(evidence.combined.nearSilenceSampleCount == 8)
    }

    @Test("DC and complete silence retain interpretable finite sentinels")
    func dcAndSilence() throws {
        let dc = try #require(PCMSignalIntegrityAnalyzer.analyze(
            channels: [[Float](repeating: 0.25, count: 8)],
            sampleRate: 48_000,
            segmentFrameCount: 4
        ))
        #expect(dc.combined.samplePeak == 0.25)
        #expect(dc.combined.rms == 0.25)
        #expect(dc.combined.crestFactor == 1)
        #expect(dc.combined.dcOffset == 0.25)
        #expect(dc.nearSilentFrameCount == 0)

        let silence = try #require(PCMSignalIntegrityAnalyzer.analyze(
            channels: [[Float](repeating: 0, count: 8)],
            sampleRate: 48_000,
            segmentFrameCount: 4
        ))
        #expect(silence.combined.samplePeak == 0)
        #expect(silence.combined.samplePeakDBFS == -120)
        #expect(silence.combined.truePeak == 0)
        #expect(silence.combined.truePeakDBTP == -120)
        #expect(silence.combined.rms == 0)
        #expect(silence.combined.crestFactor == 0)
        #expect(silence.nearSilentFrameCount == 8)
        #expect(silence.longestNearSilentFrameRun == 8)
    }

    @Test("Annex 2 ownership exposes the same inter-sample peak")
    func canonicalTruePeak() throws {
        let samples = (0..<4_096).map { frame in
            Float(0.8 * sin(
                Double.pi * 0.5 * Double(frame) + Double.pi / 4
            ))
        }
        let evidence = try #require(PCMSignalIntegrityAnalyzer.analyze(
            channels: [samples],
            sampleRate: 48_000,
            segmentFrameCount: samples.count
        ))
        let samplePeak = try #require(evidence.combined.samplePeak)
        let truePeak = try #require(evidence.combined.truePeak)
        #expect(samplePeak < 0.57)
        #expect(truePeak > 0.77)
        #expect(truePeak > samplePeak + 0.20)
        #expect(
            PCMSignalIntegrityAnalyzer.truePeakStandard ==
                BS1770AudioEvidence.truePeakStandard
        )
    }

    @Test("Subnormal and non-finite samples remain visible and fail numeric fields")
    func invalidSamples() throws {
        let tiny = Float.leastNonzeroMagnitude
        let evidence = try #require(PCMSignalIntegrityAnalyzer.analyze(
            channels: [[tiny, .nan, .infinity, 0]],
            sampleRate: 48_000,
            segmentFrameCount: 4
        ))
        #expect(!evidence.combined.finite)
        #expect(evidence.combined.sampleCount == 4)
        #expect(evidence.combined.finiteSampleCount == 2)
        #expect(evidence.combined.nonfiniteSampleCount == 2)
        #expect(evidence.combined.subnormalSampleCount == 1)
        #expect(evidence.combined.exactZeroSampleCount == 1)
        #expect(evidence.combined.samplePeak == nil)
        #expect(evidence.combined.truePeak == nil)
        #expect(evidence.combined.rms == nil)
        #expect(evidence.nearSilentFrameCount == 2)
        #expect(evidence.longestNearSilentFrameRun == 1)
    }

    @Test("Malformed geometry and invalid routes fail closed")
    func malformedInputs() {
        #expect(PCMSignalIntegrityAnalyzer.analyze(
            channels: [], sampleRate: 48_000, segmentFrameCount: 1
        ) == nil)
        #expect(PCMSignalIntegrityAnalyzer.analyze(
            channels: [[0], [0, 1]], sampleRate: 48_000, segmentFrameCount: 1
        ) == nil)
        #expect(PCMSignalIntegrityAnalyzer.analyze(
            channels: [[0]], sampleRate: .nan, segmentFrameCount: 1
        ) == nil)
        #expect(PCMSignalIntegrityAnalyzer.analyze(
            channels: [[0]], sampleRate: 48_000, segmentFrameCount: 0
        ) == nil)
    }
}
