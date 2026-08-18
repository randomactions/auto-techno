import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Upper-percussion tail DSP")
struct UpperPercussionTailDSPTests {
    @Test("Clearance preserves an 8 ms attack and reaches the bounded tail")
    func physicalTimeGeometry() {
        for sampleRate in [44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            let frameCount = Int((0.05 * sampleRate).rounded())
            let attackFrames = UpperPercussionTailDSPContract.attackFrameCount(
                sampleRate: sampleRate,
                renderedFrameCount: frameCount
            )
            let multipliers = (0..<frameCount).map { frame in
                UpperPercussionTailDSPContract.multiplier(
                    role: .foregroundClearance,
                    frame: frame,
                    renderedFrameCount: frameCount,
                    sampleRate: sampleRate
                )
            }

            #expect(attackFrames == Int((0.008 * sampleRate).rounded()))
            #expect(multipliers.prefix(attackFrames).allSatisfy { $0 == 1 })
            #expect(multipliers[attackFrames] == 1)
            #expect(multipliers.last ==
                    UpperPercussionTailDSPContract.clearanceFinalMultiplier)
            #expect(zip(multipliers, multipliers.dropFirst()).allSatisfy {
                $0 >= $1
            })
            #expect(multipliers.allSatisfy {
                $0.isFinite &&
                    $0 >= UpperPercussionTailDSPContract.clearanceFinalMultiplier &&
                    $0 <= 1
            })
        }
    }

    @Test("Natural body is a literal bit-exact bypass")
    func naturalBodyIdentity() {
        let samples: [Float] = [
            0,
            Float(bitPattern: 0x8000_0000),
            Float.leastNonzeroMagnitude,
            -Float.leastNonzeroMagnitude,
            0.125,
            -0.75,
        ]

        for (frame, sample) in samples.enumerated() {
            let rendered = UpperPercussionTailDSPContract.process(
                sample: sample,
                role: .naturalBody,
                frame: frame,
                renderedFrameCount: samples.count,
                sampleRate: 48_000
            )
            #expect(rendered.bitPattern == sample.bitPattern)
        }
    }

    @Test("Clearance changes only post-attack samples and preserves signed zero")
    func clearanceConsequence() {
        let sampleRate = 48_000.0
        let frameCount = Int((0.05 * sampleRate).rounded())
        let attackFrames = UpperPercussionTailDSPContract.attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: frameCount
        )
        let base = (0..<frameCount).map { frame in
            Float(sin(Double(frame) * 0.073)) * 0.3
        }
        let rendered = base.enumerated().map { frame, sample in
            UpperPercussionTailDSPContract.process(
                sample: sample,
                role: .foregroundClearance,
                frame: frame,
                renderedFrameCount: frameCount,
                sampleRate: sampleRate
            )
        }

        #expect(zip(base.prefix(attackFrames), rendered.prefix(attackFrames))
            .allSatisfy { $0.bitPattern == $1.bitPattern })
        #expect(zip(base.dropFirst(attackFrames + 1),
                    rendered.dropFirst(attackFrames + 1)).contains {
            $0.bitPattern != $1.bitPattern
        })
        #expect(abs(rendered.last ?? 0) <= abs(base.last ?? 0))

        let negativeZero = Float(bitPattern: 0x8000_0000)
        let processedZero = UpperPercussionTailDSPContract.process(
            sample: negativeZero,
            role: .foregroundClearance,
            frame: frameCount - 1,
            renderedFrameCount: frameCount,
            sampleRate: sampleRate
        )
        #expect(processedZero.bitPattern == negativeZero.bitPattern)
    }

    @Test("Degenerate geometry remains finite and bounded")
    func degenerateGeometry() {
        for frameCount in 0...3 {
            for frame in -1...4 {
                let value = UpperPercussionTailDSPContract.multiplier(
                    role: .foregroundClearance,
                    frame: frame,
                    renderedFrameCount: frameCount,
                    sampleRate: 8_000
                )
                #expect(value.isFinite)
                #expect(value >=
                        UpperPercussionTailDSPContract.clearanceFinalMultiplier)
                #expect(value <= 1)
            }
        }
    }
}
