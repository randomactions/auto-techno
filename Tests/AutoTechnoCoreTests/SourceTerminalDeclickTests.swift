import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Source-terminal de-clicking")
struct SourceTerminalDeclickTests {
    @Test("Raised-cosine release preserves the first 8 ms and reaches exact zero")
    func physicalTimeGeometry() {
        for sampleRate in [44_100.0, 48_000.0] {
            for (voice, duration, fadeSeconds) in [
                (EnsembleVoice.kick, 0.32, 0.004),
                (.rumble, 0.68, 0.004),
                (.clap, 0.16, 0.002),
                (.openHat, 0.19, 0.002),
                (.metallic, 0.065, 0.002),
            ] {
                let frameCount = Int(sampleRate * duration)
                let attackFrames = SourceTerminalDeclickContract
                    .attackFrameCount(
                        sampleRate: sampleRate,
                        renderedFrameCount: frameCount
                    )
                let fadeFrames = SourceTerminalDeclickContract.fadeFrameCount(
                    voice: voice,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount
                )
                let multipliers = (0..<frameCount).map { frame in
                    SourceTerminalDeclickContract.multiplier(
                        voice: voice,
                        frame: frame,
                        renderedFrameCount: frameCount,
                        sampleRate: sampleRate
                    )
                }

                #expect(attackFrames == Int((sampleRate * 0.008).rounded()))
                #expect(fadeFrames == Int((sampleRate * fadeSeconds).rounded()))
                #expect(multipliers.prefix(attackFrames).allSatisfy { $0 == 1 })
                #expect(multipliers[frameCount - fadeFrames - 1] == 1)
                #expect(multipliers[frameCount - fadeFrames] == 1)
                #expect(multipliers.last?.bitPattern == 0)
                #expect(zip(multipliers, multipliers.dropFirst()).allSatisfy {
                    $0 >= $1
                })
                #expect(multipliers.allSatisfy {
                    $0.isFinite && $0 >= 0 && $0 <= 1
                })
            }
        }
    }

    @Test("Event-local evidence proves exact attack identity and zero terminal delta")
    func eventEvidence() {
        for sampleRate in [44_100.0, 48_000.0] {
            for (index, voice) in [
                EnsembleVoice.kick,
                .rumble,
                .clap,
                .openHat,
                .metallic,
            ].enumerated() {
                let frameCount = Int(sampleRate * 0.08)
                var evidence = SourceTerminalDeclickEvidenceAccumulator(
                    scoreEventIndex: index,
                    voice: voice,
                    step: index * 2,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount
                )
                for frame in 0..<frameCount {
                    let source = Float(0.2 + 0.1 *
                        sin(Double(frame) * 0.017))
                    let rendered = SourceTerminalDeclickContract.process(
                        sample: source,
                        voice: voice,
                        frame: frame,
                        renderedFrameCount: frameCount,
                        sampleRate: sampleRate
                    )
                    evidence.append(
                        frame: frame,
                        preFade: source,
                        rendered: rendered
                    )
                }

                let result = evidence.evidence
                #expect(result.isComplete(sampleRate: sampleRate))
                #expect(!result.isComplete(sampleRate: sampleRate * 0.5))
                #expect(result.preFadeAttackSampleHash ==
                        result.renderedAttackSampleHash)
                #expect(result.preFadeLastSampleBitPattern != 0)
                #expect(result.renderedLastSampleBitPattern == 0)
                #expect(result.preFadeTerminalDelta > 0)
                #expect(result.renderedTerminalDelta.bitPattern == 0)
                #expect(result.changedSampleCount == result.fadeFrameCount - 1)
            }
        }
    }

    @Test("Unsupported voices remain bit-exact")
    func unsupportedVoiceIdentity() {
        let samples: [Float] = [
            0,
            Float(bitPattern: 0x8000_0000),
            0.25,
            -0.75,
        ]
        for (frame, sample) in samples.enumerated() {
            let output = SourceTerminalDeclickContract.process(
                sample: sample,
                voice: .bass,
                frame: frame,
                renderedFrameCount: samples.count,
                sampleRate: 48_000
            )
            #expect(output.bitPattern == sample.bitPattern)
        }
    }
}
