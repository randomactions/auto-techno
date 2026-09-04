import Foundation
import Testing
@testable import AutoTechnoDSP

@Suite("PCM rhythmic baseline analyzer")
struct PCMRhythmicBaselineAnalyzerTests {
    @Test("Identical active bars are exact PCM and rhythmic repeats")
    func identicalLoop() throws {
        let rate = 48_000
        let bar = impulseBar(
            steps: [0, 4, 8, 12],
            sampleRate: rate,
            amplitude: 0.8
        )
        let evidence = try available(bar + bar, sampleRate: rate)
        let comparison = try #require(evidence.comparisons.first)

        #expect(evidence.bars.count == 2)
        #expect(comparison.availability == .available)
        #expect(comparison.exactPCMRepeat)
        #expect(comparison.exactOnsetFrameRepeat == true)
        #expect(comparison.gridMutationDistance == 0)
        #expect(comparison.gridSimilarity == 1)
        #expect(comparison.bestReferenceForwardRotationSteps == 0)
        #expect(comparison.bestRotationMutationDistance == 0)
        #expect(comparison.matchedMicrotimingDistanceSteps == 0)
    }

    @Test("One-event mutation is closer than unrelated churn")
    func boundedMutationAndChurn() throws {
        let rate = 48_000
        let source = impulseBar(
            steps: [0, 4, 8, 12], sampleRate: rate
        )
        let mutation = impulseBar(
            steps: [0, 4, 8, 12, 14], sampleRate: rate
        )
        let churn = impulseBar(
            steps: [1, 2, 6, 11, 15], sampleRate: rate
        )
        let evidence = try available(source + mutation + churn, sampleRate: rate)
        let oneEvent = try comparison(
            evidence, reference: 0, current: 1
        )
        let unrelated = try comparison(
            evidence, reference: 0, current: 2
        )

        #expect(oneEvent.gridMutationDistance == 1.0 / 9.0)
        #expect(oneEvent.gridSimilarity == 0.8)
        #expect((oneEvent.gridMutationDistance ?? 1) <
            (unrelated.gridMutationDistance ?? 0))
        #expect((oneEvent.bestRotationMutationDistance ?? 1) <
            (unrelated.bestRotationMutationDistance ?? 0))
    }

    @Test("Cyclic rotation stays distinct from mutation")
    func cyclicRotation() throws {
        let rate = 48_000
        let reference = impulseBar(
            steps: [0, 3, 7, 10], sampleRate: rate
        )
        let rotated = impulseBar(
            steps: [2, 5, 9, 12], sampleRate: rate
        )
        let evidence = try available(reference + rotated, sampleRate: rate)
        let value = try #require(evidence.comparisons.first)

        #expect((value.gridMutationDistance ?? 0) > 0)
        #expect(value.bestReferenceForwardRotationSteps == 2)
        #expect(value.bestRotationMutationDistance == 0)
    }

    @Test("Level and event-body changes preserve onset pattern without claiming PCM identity")
    func boundedLevelAndTimbreVariation() throws {
        let rate = 48_000
        let loud = impulseBar(
            steps: [0, 3, 7, 11], sampleRate: rate, amplitude: 0.8
        )
        var quiet = impulseBar(
            steps: [0, 3, 7, 11], sampleRate: rate, amplitude: 0.3
        )
        for frame in quiet.indices where quiet[frame] != 0 && frame + 1 < quiet.count {
            quiet[frame + 1] = quiet[frame] * 0.25
        }
        let evidence = try available(loud + quiet, sampleRate: rate)
        let value = try #require(evidence.comparisons.first)

        #expect(!value.exactPCMRepeat)
        #expect(value.exactOnsetFrameRepeat == true)
        #expect(value.gridMutationDistance == 0)
        #expect(value.gridSimilarity == 1)
    }

    @Test("Signal silence and rhythmic rest remain separate facts")
    func silenceAndSustain() throws {
        let rate = 48_000
        let barFrames = self.barFrames(rate)
        let silence = [Float](repeating: 0, count: barFrames * 2)
        let silentEvidence = try available(silence, sampleRate: rate)
        let silentComparison = try #require(silentEvidence.comparisons.first)

        #expect(silentEvidence.bars.allSatisfy {
            $0.exactSilenceOccupancy == 1 && $0.restOccupancy == 1
        })
        #expect(silentComparison.availability ==
            .unavailableNoOnsetsInEitherBar)
        #expect(silentComparison.exactPCMRepeat)
        #expect(silentComparison.exactOnsetFrameRepeat == nil)
        #expect(silentComparison.gridMutationDistance == nil)
        #expect(silentEvidence.summary.exactPCMRepeatCount == 0)

        let sustained = [Float](repeating: 0.15, count: barFrames * 3)
        let sustainedEvidence = try available(sustained, sampleRate: rate)
        #expect(sustainedEvidence.bars[0].onsetCount == 1)
        #expect(sustainedEvidence.bars[1].onsetCount == 0)
        #expect(sustainedEvidence.bars[1].exactSilenceOccupancy == 0)
        #expect(sustainedEvidence.bars[1].restOccupancy == 1)
        let noOnsetPair = try comparison(
            sustainedEvidence, reference: 1, current: 2
        )
        #expect(noOnsetPair.availability ==
            .unavailableNoOnsetsInEitherBar)
    }

    @Test("Microtiming remains separate from grid mutation and rate normalized")
    func microtimingAndRates() throws {
        var normalizedDistances: [Double] = []
        for rate in [44_100, 48_000] {
            let reference = impulseBar(
                steps: [0, 4, 8, 12], sampleRate: rate
            )
            let shifted = impulseBar(
                steps: [0, 4, 8, 12],
                sampleRate: rate,
                offsetSteps: 0.10
            )
            let evidence = try available(reference + shifted, sampleRate: rate)
            let value = try #require(evidence.comparisons.first)
            #expect(value.gridMutationDistance == 0)
            #expect(value.exactOnsetFrameRepeat == false)
            normalizedDistances.append(try #require(
                value.matchedMicrotimingDistanceSteps
            ))
        }
        #expect(abs(normalizedDistances[0] - 0.10) < 0.0002)
        #expect(abs(normalizedDistances[1] - 0.10) < 0.0002)
        #expect(abs(normalizedDistances[0] - normalizedDistances[1]) < 0.0002)
    }

    @Test("Named metrical proxies distinguish quarter pulse from displaced onsets")
    func metricalEvidence() throws {
        let rate = 48_000
        let quarters = impulseBar(
            steps: [0, 4, 8, 12], sampleRate: rate
        )
        let sixteenths = impulseBar(
            steps: [1, 5, 9, 13], sampleRate: rate
        )
        let evidence = try available(quarters + sixteenths, sampleRate: rate)

        #expect(evidence.bars[0].metricalDisplacement == 0)
        #expect(evidence.bars[0].adjacentStrongRestCount == 0)
        #expect(evidence.bars[1].metricalDisplacement == 1)
        #expect(evidence.bars[1].adjacentStrongRestCount == 4)
        #expect(evidence.bars[1].adjacentStrongRestPotential == 1)
    }

    @Test("Arithmetic onset fold cancellation does not masquerade as source silence")
    func stereoPhaseBehavior() throws {
        let rate = 48_000
        let source = impulseBar(
            steps: [0, 4, 8, 12], sampleRate: rate
        )
        let aligned = try #require(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [source, source], sampleRate: Double(rate)
        ))
        let cancelled = try #require(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [source, source.map { -$0 }], sampleRate: Double(rate)
        ))

        #expect(aligned.summary.onsetCount == 4)
        #expect(cancelled.summary.onsetCount == 0)
        #expect(cancelled.bars[0].exactSilenceOccupancy < 1)
        #expect(cancelled.bars[0].restOccupancy == 1)
    }

    @Test("Cyclic intervals close complete bars and partial bars fail closed locally")
    func intervalsAndPartialBar() throws {
        let rate = 48_000
        let complete = impulseBar(
            steps: [0, 4, 8, 12], sampleRate: rate
        )
        let partial = Array(complete.prefix(complete.count / 2))
        let evidence = try available(complete + partial, sampleRate: rate)

        #expect(evidence.bars[0].cyclicIntervalStatus == .available)
        #expect(evidence.bars[0].cyclicInterOnsetFrameIntervals.reduce(0, +) ==
            evidence.barFrameCount)
        #expect(!evidence.bars[1].complete)
        #expect(evidence.bars[1].cyclicIntervalStatus == .unavailablePartialBar)
        #expect(evidence.bars[1].cyclicInterOnsetFrameIntervals.isEmpty)
        #expect(evidence.comparisons.isEmpty)
        #expect(evidence.summary.partialBarCount == 1)
    }

    @Test("Unavailable quantities encode as explicit nulls")
    func explicitNullEncoding() throws {
        let rate = 48_000
        let silence = [Float](repeating: 0, count: barFrames(rate) * 2)
        let evidence = try available(silence, sampleRate: rate)
        let object = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(evidence)
        ) as? [String: Any])
        let bars = try #require(object["bars"] as? [[String: Any]])
        let comparisons = try #require(
            object["comparisons"] as? [[String: Any]]
        )
        #expect(bars[0]["meanAbsoluteMicrotimingSteps"] is NSNull)
        #expect(bars[0]["metricalDisplacement"] is NSNull)
        #expect(comparisons[0]["exactOnsetFrameRepeat"] is NSNull)
        #expect(comparisons[0]["gridMutationDistance"] is NSNull)
    }

    @Test("Malformed source geometry and non-finite samples are unavailable")
    func malformedInput() {
        let valid = [Float](repeating: 0, count: 64)
        var nonfinite = valid
        nonfinite[31] = .infinity
        #expect(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [], sampleRate: 48_000
        ) == nil)
        #expect(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [valid, valid, valid], sampleRate: 48_000
        ) == nil)
        #expect(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [valid, Array(valid.dropLast())], sampleRate: 48_000
        ) == nil)
        #expect(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [valid, nonfinite], sampleRate: 48_000
        ) == nil)
        #expect(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [valid], sampleRate: 48_000.5
        ) == nil)
    }

    private func available(
        _ samples: [Float], sampleRate: Int
    ) throws -> PCMRhythmicBaselineEvidence {
        try #require(PCMRhythmicBaselineAnalyzer.analyze(
            channels: [samples], sampleRate: Double(sampleRate)
        ))
    }

    private func comparison(
        _ evidence: PCMRhythmicBaselineEvidence,
        reference: Int,
        current: Int
    ) throws -> PCMRhythmicBarComparison {
        try #require(evidence.comparisons.first {
            $0.referenceBarIndex == reference && $0.currentBarIndex == current
        })
    }

    private func impulseBar(
        steps: [Int],
        sampleRate: Int,
        amplitude: Float = 0.8,
        offsetSteps: Double = 0
    ) -> [Float] {
        let frameCount = barFrames(sampleRate)
        var samples = [Float](repeating: 0, count: frameCount)
        for step in steps {
            let target = Double(step) * Double(frameCount) / 16.0
            let offset = offsetSteps * Double(frameCount) / 16.0
            let frame = Int((target + offset).rounded())
            if frame >= 0 && frame < samples.count {
                samples[frame] = amplitude
            }
        }
        return samples
    }

    private func barFrames(_ sampleRate: Int) -> Int {
        Int((Double(sampleRate) * 240.0 / 130.0).rounded())
    }
}
