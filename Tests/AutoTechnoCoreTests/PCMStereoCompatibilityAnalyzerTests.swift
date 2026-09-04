import Foundation
import Testing
@testable import AutoTechnoDSP

@Suite("PCM stereo compatibility analyzer")
struct PCMStereoCompatibilityAnalyzerTests {
    @Test("Silence is inactive with explicit unavailable ratios")
    func silence() throws {
        let zeros = [Float](repeating: 0, count: 256)
        let evidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [zeros, zeros],
            sampleRate: 48_000,
            segmentFrameCount: 128
        ))

        #expect(evidence.summary.count == 5)
        #expect(evidence.segments.count == 2)
        #expect(evidence.summary.allSatisfy {
            $0.state == .inactive &&
                $0.correlation == nil &&
                $0.monoRetentionRatio == nil &&
                $0.monoLevelChangeDB == nil &&
                $0.sideEnergyShare == nil &&
                $0.sideToMidRatio == nil &&
                $0.finite
        })
        let encoded = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(evidence)
        ) as? [String: Any]
        let summary = try #require(encoded?["summary"] as? [[String: Any]])
        #expect(summary.allSatisfy { $0["correlation"] is NSNull })
        #expect(summary.allSatisfy { $0["sideToMidRatio"] is NSNull })
    }

    @Test("Exact dual mono is structurally safe in every active domain")
    func exactMono() throws {
        let signal = tone(frequency: 1_000, sampleRate: 48_000, frames: 4_800)
        let evidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [signal, signal],
            sampleRate: 48_000,
            segmentFrameCount: 2_400
        ))

        #expect(evidence.summary.allSatisfy {
            $0.state == .safeExactMono &&
                $0.correlation == 1 &&
                $0.monoRetentionRatio == 1 &&
                $0.monoLevelChangeDB == 0 &&
                $0.sideEnergyShare == 0 &&
                $0.sideToMidRatio == 0
        })
    }

    @Test("Native mono is repeated for compatibility math without hiding provenance")
    func nativeMono() throws {
        let signal = tone(frequency: 1_000, sampleRate: 48_000, frames: 4_800)
        let native = try #require(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [signal],
            sampleRate: 48_000,
            segmentFrameCount: 2_400
        ))
        let dual = try #require(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [signal, signal],
            sampleRate: 48_000,
            segmentFrameCount: 2_400
        ))

        #expect(native.sourceChannelCount == 1)
        #expect(dual.sourceChannelCount == 2)
        #expect(native.summary == dual.summary)
        #expect(native.segments == dual.segments)
        #expect(native.summary.allSatisfy { $0.state == .safeExactMono })
    }

    @Test("Exact polarity inversion is structurally unsafe in every active domain")
    func exactCancellation() throws {
        let left = tone(frequency: 733, sampleRate: 48_000, frames: 4_800)
        let right = left.map { -$0 }
        let evidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [left, right],
            sampleRate: 48_000,
            segmentFrameCount: 2_400
        ))

        #expect(evidence.summary.allSatisfy {
            $0.state == .unsafeExactCancellation &&
                $0.correlation == -1 &&
                $0.monoRetentionRatio == 0 &&
                $0.monoLevelChangeDB == -120 &&
                $0.sideEnergyShare == 1 &&
                $0.sideToMidRatio == nil
        })
    }

    @Test("One-sided audio is neither silence nor cancellation")
    func oneSided() throws {
        let left = tone(frequency: 330, sampleRate: 48_000, frames: 2_400)
        let silence = [Float](repeating: 0, count: left.count)
        for channels in [[left, silence], [silence, left]] {
            let evidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: channels,
                sampleRate: 48_000,
                segmentFrameCount: left.count
            ))
            let full = try #require(evidence.summary.first)
            #expect(full.state == .oneSided)
            #expect(full.correlation == nil)
            #expect(close(full.monoRetentionRatio, 0.5))
            #expect(close(full.sideEnergyShare, 0.5))
            #expect(close(full.sideToMidRatio, 1))
            #expect(close(full.monoLevelChangeDB, -3.010299956639812))
        }
    }

    @Test("Unequal aligned gain and sample delay remain descriptive mixed states")
    func mixedStates() throws {
        let left = tone(frequency: 440, sampleRate: 48_000, frames: 4_800)
        let reduced = left.map { $0 * 0.5 }
        let delayed = [Float](repeating: 0, count: 17) + left.dropLast(17)
        for right in [reduced, Array(delayed)] {
            let evidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: [left, right],
                sampleRate: 48_000,
                segmentFrameCount: 2_400
            ))
            #expect(evidence.summary[0].state == .mixed)
            #expect(evidence.summary[0].monoRetentionRatio != nil)
            #expect(evidence.summary[0].sideEnergyShare != nil)
        }
        let delayedEvidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [left, Array(delayed)],
            sampleRate: 48_000,
            segmentFrameCount: 2_400
        ))
        #expect((delayedEvidence.summary[0].correlation ?? 1) < 0.8)
    }

    @Test("Mid-side energy identity and ratios survive common amplitude scaling")
    func energyIdentityAndScaling() throws {
        let left: [Float] = (0..<2_003).map { frame in
            Float(sin(Double(frame) * 0.071) * 0.31)
        }
        let right: [Float] = (0..<2_003).map { frame in
            Float(cos(Double(frame) * 0.113) * 0.19)
        }
        func evidence(scale: Float) throws -> PCMStereoCompatibilityEvidence {
            try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: [left.map { $0 * scale }, right.map { $0 * scale }],
                sampleRate: 48_000,
                segmentFrameCount: 997
            ))
        }
        let original = try evidence(scale: 1)
        let scaled = try evidence(scale: 0.25)
        #expect(original.segments.map(\.frameCount) == [997, 997, 9])
        for (first, second) in zip(original.summary, scaled.summary) {
            #expect(close(first.stereoMeanSquare, first.midMeanSquare + first.sideMeanSquare))
            #expect(close(second.stereoMeanSquare, second.midMeanSquare + second.sideMeanSquare))
            #expect(close(first.correlation, second.correlation, tolerance: 2e-6))
            #expect(close(first.monoRetentionRatio, second.monoRetentionRatio, tolerance: 2e-6))
            #expect(close(first.sideEnergyShare, second.sideEnergyShare, tolerance: 2e-6))
            #expect(first.state == second.state)
        }
    }

    @Test("Declared causal bands separate low and high fixtures")
    func bandSeparation() throws {
        func summary(frequency: Double) throws -> [PCMStereoDomainEvidence] {
            let signal = tone(
                frequency: frequency,
                sampleRate: 48_000,
                frames: 48_000
            )
            return try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: [signal, signal],
                sampleRate: 48_000,
                segmentFrameCount: 48_000
            )).summary
        }
        let low = try summary(frequency: 70)
        let high = try summary(frequency: 6_000)
        #expect(low[1].stereoMeanSquare > low[4].stereoMeanSquare * 100)
        #expect(high[4].stereoMeanSquare > high[1].stereoMeanSquare * 100)
    }

    @Test("Physical-time fixtures preserve states at 44.1 and 48 kHz")
    func rateNormalized() throws {
        for rate in [44_100.0, 48_000.0] {
            let frames = Int(rate * 0.2)
            let mono = tone(frequency: 211, sampleRate: rate, frames: frames)
            let anti = mono.map { -$0 }
            let monoEvidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: [mono, mono],
                sampleRate: rate,
                segmentFrameCount: frames / 2
            ))
            let antiEvidence = try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: [mono, anti],
                sampleRate: rate,
                segmentFrameCount: frames / 2
            ))
            #expect(monoEvidence.summary.allSatisfy { $0.state == .safeExactMono })
            #expect(antiEvidence.summary.allSatisfy {
                $0.state == .unsafeExactCancellation
            })
        }
    }

    @Test("DC and deterministic noise retain their structural meaning")
    func dcAndNoise() throws {
        let dc = [Float](repeating: 0.2, count: 4_096)
        let noise: [Float] = (0..<4_096).map { frame in
            Float(((frame * 1_103 + 17) % 997) - 498) / 2_000
        }
        for signal in [dc, noise] {
            let mono = try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: [signal, signal],
                sampleRate: 48_000,
                segmentFrameCount: 2_048
            ))
            let anti = try #require(PCMStereoCompatibilityAnalyzer.analyze(
                channels: [signal, signal.map { -$0 }],
                sampleRate: 48_000,
                segmentFrameCount: 2_048
            ))
            #expect(mono.summary.allSatisfy { $0.state == .safeExactMono })
            #expect(anti.summary.allSatisfy {
                $0.state == .unsafeExactCancellation
            })
        }
    }

    @Test("Malformed geometry and samples fail closed")
    func invalidInput() {
        let valid = [Float](repeating: 0, count: 64)
        var nonfinite = valid
        nonfinite[31] = .nan
        #expect(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [], sampleRate: 48_000, segmentFrameCount: 64
        ) == nil)
        #expect(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [valid, valid, valid], sampleRate: 48_000,
            segmentFrameCount: 64
        ) == nil)
        #expect(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [valid, Array(valid.dropLast())], sampleRate: 48_000,
            segmentFrameCount: 64
        ) == nil)
        #expect(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [valid, nonfinite], sampleRate: 48_000,
            segmentFrameCount: 64
        ) == nil)
        #expect(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [valid, valid], sampleRate: 48_000.5,
            segmentFrameCount: 64
        ) == nil)
        #expect(PCMStereoCompatibilityAnalyzer.analyze(
            channels: [valid, valid], sampleRate: 48_000,
            segmentFrameCount: 0
        ) == nil)
    }

    private func tone(
        frequency: Double,
        sampleRate: Double,
        frames: Int
    ) -> [Float] {
        (0..<frames).map { frame in
            Float(sin(2 * Double.pi * frequency * Double(frame) / sampleRate) * 0.25)
        }
    }

    private func close(
        _ first: Double?,
        _ second: Double?,
        tolerance: Double = 1e-10
    ) -> Bool {
        guard let first, let second else { return first == nil && second == nil }
        return abs(first - second) <= tolerance * max(1, abs(first), abs(second))
    }
}
