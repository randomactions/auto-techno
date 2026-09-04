@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("PCM transient and envelope evidence")
struct PCMTransientEnvelopeAnalyzerTests {
    @Test("Reusable tracker preserves the legacy whole-mix detector exactly")
    func legacyTrackerParity() throws {
        let sampleRate = 48_000.0
        var samples = [Float](repeating: 0, count: 48_000)
        for frame in stride(from: 500, to: samples.count, by: 4_000) {
            samples[frame] = frame.isMultiple(of: 8_000) ? 0.8 : -0.6
        }
        for frame in 20_000..<22_000 {
            samples[frame] += Float(frame - 20_000) / 4_000
        }

        var tracker = PCMTransientDensityTracker(sampleRate: sampleRate)
        var frames: [Int] = []
        for sample in samples {
            if tracker.process(Double(sample)) {
                frames.append(tracker.processedFrameCount - 1)
            }
        }
        let legacy = legacyTransientFrames(samples, sampleRate: sampleRate)
        #expect(frames == legacy)

        let metrics = MusicalQualityMetrics(
            left: samples,
            right: samples,
            sampleRate: sampleRate
        )
        #expect(metrics.transientDensity == Double(legacy.count))
    }

    @Test("Known attacks preserve duration and normalized-shape sign")
    func attackSensitivityAndSign() throws {
        let sampleRate = 48_000
        let fast = try available(makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.010,
            decaySeconds: 0.060,
            attackCurve: { $0 }
        ), sampleRate: sampleRate)
        let slow = try available(makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.050,
            decaySeconds: 0.060,
            attackCurve: { $0 }
        ), sampleRate: sampleRate)
        let concaveUp = try available(makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.050,
            decaySeconds: 0.060,
            attackCurve: { $0 * $0 }
        ), sampleRate: sampleRate)
        let concaveDown = try available(makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.050,
            decaySeconds: 0.060,
            attackCurve: { sqrt($0) }
        ), sampleRate: sampleRate)

        let fastEvent = try #require(fast.events.first)
        let slowEvent = try #require(slow.events.first)
        let upEvent = try #require(concaveUp.events.first)
        let downEvent = try #require(concaveDown.events.first)
        #expect(fast.events.count == 1)
        #expect(slow.events.count == 1)
        #expect(fastEvent.attackRiseSeconds < slowEvent.attackRiseSeconds)
        #expect(upEvent.attackMeanNormalizedEnvelope <
            slowEvent.attackMeanNormalizedEnvelope)
        #expect(slowEvent.attackMeanNormalizedEnvelope <
            downEvent.attackMeanNormalizedEnvelope)
        #expect(abs(slowEvent.attackRiseSeconds - 0.040) < 0.001)
    }

    @Test("Known decays preserve short/long occupancy sign")
    func decaySensitivityAndSign() throws {
        let sampleRate = 48_000
        let short = try available(makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.002,
            decaySeconds: 0.025,
            attackCurve: { $0 }
        ), sampleRate: sampleRate)
        let long = try available(makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.002,
            decaySeconds: 0.180,
            attackCurve: { $0 }
        ), sampleRate: sampleRate)
        let shortEvent = try #require(short.events.first)
        let longEvent = try #require(long.events.first)
        let shortDecay10 = try #require(shortEvent.decay10Frame)
        let longDecay10 = try #require(longEvent.decay10Frame)

        #expect(shortEvent.decayOccupancy < longEvent.decayOccupancy)
        #expect(shortDecay10 < longDecay10)
        #expect(shortEvent.decayActiveFrameCount <
            longEvent.decayActiveFrameCount)
    }

    @Test("Unmeasurable values encode as explicit nulls")
    func explicitNullEncoding() throws {
        let sampleRate = 48_000
        let silence = try available(
            [Float](repeating: 0, count: 2_000),
            sampleRate: sampleRate
        )
        let silenceObject = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(silence)
            ) as? [String: Any]
        )
        let silenceSummary = try #require(
            silenceObject["summary"] as? [String: Any]
        )
        for key in [
            "attackRiseSecondsMean",
            "attackMeanNormalizedEnvelopeMean",
            "decayOccupancyMean",
            "eventCrestFactorMean",
        ] {
            #expect(silenceSummary[key] is NSNull)
        }

        var sourceEndImpulse = [Float](repeating: 0, count: 2_000)
        sourceEndImpulse[sourceEndImpulse.count - 1] = 1
        let impulse = try available(
            sourceEndImpulse,
            sampleRate: sampleRate
        )
        let impulseObject = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(impulse)
            ) as? [String: Any]
        )
        let events = try #require(
            impulseObject["events"] as? [[String: Any]]
        )
        let event = try #require(events.first)
        #expect(event["decay10Frame"] is NSNull)
    }

    @Test("Relative shape, occupancy, and crest are amplitude-scale stable")
    func amplitudeScaleBehavior() throws {
        let sampleRate = 48_000
        let source = makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.035,
            decaySeconds: 0.090,
            attackCurve: { $0 * $0 }
        )
        let loud = try available(source, sampleRate: sampleRate)
        let quiet = try available(
            source.map { $0 * 0.25 },
            sampleRate: sampleRate
        )
        let loudEvent = try #require(loud.events.first)
        let quietEvent = try #require(quiet.events.first)

        #expect(loud.events.count == quiet.events.count)
        #expect(loudEvent.attackRiseFrameCount == quietEvent.attackRiseFrameCount)
        #expect(abs(loudEvent.attackMeanNormalizedEnvelope -
            quietEvent.attackMeanNormalizedEnvelope) < 1e-12)
        #expect(abs(loudEvent.decayOccupancy - quietEvent.decayOccupancy) < 1e-12)
        #expect(abs(loudEvent.crestFactor - quietEvent.crestFactor) < 1e-6)
    }

    @Test("Impulses separate after refractory and close the prior event")
    func impulseSeparation() throws {
        let sampleRate = 48_000
        var samples = [Float](repeating: 0, count: sampleRate / 2)
        samples[1_000] = 1
        samples[4_000] = 0.7
        samples[20_000] = 0.8
        let evidence = try available(samples, sampleRate: sampleRate)

        #expect(evidence.summary.legacyTransientCount == 3)
        #expect(evidence.summary.shapeEventCount == 3)
        #expect(evidence.events.map(\.onsetFrame) == [1_000, 4_000, 20_000])
        #expect(evidence.events[0].analysisEndFrame == 4_000)
        #expect(evidence.events[0].analysisEndSource == .nextEvent)
        #expect(evidence.events[1].analysisEndSource == .fixedWindow)
        #expect(evidence.events[2].analysisEndSource == .sourceEnd)
        #expect(evidence.events.allSatisfy { $0.attackRiseFrameCount == 0 })
    }

    @Test("Slow activity rise remains distinct from legacy flux")
    func onsetProvenance() throws {
        let sampleRate = 48_000
        let samples = makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.100,
            decaySeconds: 0.050,
            attackCurve: { $0 }
        )
        let evidence = try available(samples, sampleRate: sampleRate)

        #expect(evidence.summary.shapeEventCount == 1)
        #expect(evidence.events[0].onsetSource == .activityRise)
        #expect(evidence.summary.legacyTransientCount == 0)
    }

    @Test("Sample-rate normalized geometry agrees at 44.1 and 48 kHz")
    func sampleRateNormalization() throws {
        let evidence44 = try available(makeEnvelope(
            sampleRate: 44_100,
            attackSeconds: 0.040,
            decaySeconds: 0.100,
            attackCurve: { $0 }
        ), sampleRate: 44_100)
        let evidence48 = try available(makeEnvelope(
            sampleRate: 48_000,
            attackSeconds: 0.040,
            decaySeconds: 0.100,
            attackCurve: { $0 }
        ), sampleRate: 48_000)
        let event44 = try #require(evidence44.events.first)
        let event48 = try #require(evidence48.events.first)

        #expect(abs(event44.attackRiseSeconds - event48.attackRiseSeconds) < 0.000_1)
        #expect(abs(event44.decayOccupancy - event48.decayOccupancy) < 0.001)
        #expect(abs(event44.crestFactor - event48.crestFactor) < 0.001)
    }

    @Test("Arithmetic stereo fold reports aligned signal and exact cancellation")
    func stereoFold() throws {
        let sampleRate = 48_000
        let mono = makeEnvelope(
            sampleRate: sampleRate,
            attackSeconds: 0.020,
            decaySeconds: 0.080,
            attackCurve: { $0 }
        )
        let aligned = try #require(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [mono, mono],
            sampleRate: Double(sampleRate),
            segmentFrameCount: sampleRate / 4
        ))
        let cancelled = try #require(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [mono, mono.map { -$0 }],
            sampleRate: Double(sampleRate),
            segmentFrameCount: sampleRate / 4
        ))

        #expect(aligned.summary.shapeEventCount == 1)
        #expect(cancelled.summary.shapeEventCount == 0)
        #expect(cancelled.summary.legacyTransientCount == 0)
        #expect(cancelled.summary.crestFactor == 0)
        #expect(cancelled.summary.attackRiseSecondsMean == nil)
    }

    @Test("Silence and steady signal use explicit non-quality states")
    func silenceAndSteadySignal() throws {
        let silence = try available(
            [Float](repeating: 0, count: 8_000),
            sampleRate: 48_000
        )
        let steady = try available(
            [Float](repeating: 0.2, count: 8_000),
            sampleRate: 48_000
        )

        #expect(silence.events.isEmpty)
        #expect(silence.summary.shapeEventCount == 0)
        #expect(silence.summary.attackMeanNormalizedEnvelopeMean == nil)
        #expect(silence.summary.decayOccupancyMean == nil)
        #expect(steady.events.count == 1)
        #expect(steady.events[0].onsetFrame == 0)
        #expect(abs(steady.summary.crestFactor - 1) < 1e-12)
    }

    @Test("Segments are contiguous and attribute counts by onset")
    func segments() throws {
        var samples = [Float](repeating: 0, count: 12_000)
        samples[1_000] = 1
        samples[7_000] = 1
        let evidence = try #require(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [samples],
            sampleRate: 48_000,
            segmentFrameCount: 6_000
        ))

        #expect(evidence.segments.map(\.startFrame) == [0, 6_000])
        #expect(evidence.segments.map(\.frameCount) == [6_000, 6_000])
        #expect(evidence.segments.map(\.summary.shapeEventCount) == [1, 1])
        #expect(evidence.segments.map(\.summary.legacyTransientCount) == [1, 1])
        #expect(evidence.summary.shapeEventCount == 2)
    }

    @Test("Malformed and non-finite inputs fail closed")
    func malformedInputs() {
        #expect(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [], sampleRate: 48_000, segmentFrameCount: 1
        ) == nil)
        #expect(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [[0], [0, 1]], sampleRate: 48_000,
            segmentFrameCount: 1
        ) == nil)
        #expect(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [[0]], sampleRate: .nan, segmentFrameCount: 1
        ) == nil)
        #expect(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [[.nan]], sampleRate: 48_000, segmentFrameCount: 1
        ) == nil)
        #expect(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [[0]], sampleRate: 48_000, segmentFrameCount: 0
        ) == nil)
        #expect(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [[0], [0], [0]], sampleRate: 48_000,
            segmentFrameCount: 1
        ) == nil)
    }

    private func available(
        _ samples: [Float], sampleRate: Int
    ) throws -> PCMTransientEnvelopeEvidence {
        try #require(PCMTransientEnvelopeAnalyzer.analyze(
            channels: [samples],
            sampleRate: Double(sampleRate),
            segmentFrameCount: max(1, sampleRate / 4)
        ))
    }

    private func makeEnvelope(
        sampleRate: Int,
        attackSeconds: Double,
        decaySeconds: Double,
        attackCurve: (Double) -> Double
    ) -> [Float] {
        let silenceFrames = Int((Double(sampleRate) * 0.020).rounded())
        let attackFrames = max(2, Int((Double(sampleRate) * attackSeconds).rounded()))
        let decayFrames = max(2, Int((Double(sampleRate) * decaySeconds).rounded()))
        let total = silenceFrames + attackFrames + decayFrames + sampleRate / 4
        var samples = [Float](repeating: 0, count: total)
        for index in 0..<attackFrames {
            let progress = Double(index) / Double(attackFrames - 1)
            samples[silenceFrames + index] = Float(attackCurve(progress))
        }
        for index in 0..<decayFrames {
            let progress = Double(index) / Double(decayFrames - 1)
            samples[silenceFrames + attackFrames + index] = Float(1 - progress)
        }
        return samples
    }

    private func legacyTransientFrames(
        _ samples: [Float], sampleRate: Double
    ) -> [Int] {
        var previousEnvelope = 0.0
        let refractory = max(1, Int(sampleRate * 0.035))
        let coefficient = 1 - pow(1 - 0.08, 48_000 / sampleRate)
        var lastTransient = -refractory
        var frames: [Int] = []
        for (frame, value) in samples.enumerated() {
            let envelope = abs(Double(value))
            if envelope - previousEnvelope > 0.055 &&
                frame - lastTransient >= refractory {
                frames.append(frame)
                lastTransient = frame
            }
            previousEnvelope += (envelope - previousEnvelope) * coefficient
        }
        return frames
    }
}
