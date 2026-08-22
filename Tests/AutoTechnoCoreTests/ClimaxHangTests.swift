import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Score-owned climax hang")
struct ClimaxHangTests {
    @Test("Terminal hold reaches exact silence at every supported route rate")
    func routeGeometry() throws {
        for sampleRate in [8_000.0, 44_100, 48_000, 96_000, 192_000] {
            let frameCount = Int((
                240 / AutonomousSessionDirector.bpm * sampleRate
            ).rounded())
            let left = (0..<frameCount).map { index in
                Float(0.2 * sin(2 * .pi * 173 * Double(index) / sampleRate))
            }
            let right = (0..<frameCount).map { index in
                Float(0.17 * sin(2 * .pi * 241 * Double(index) / sampleRate))
            }
            let rendered = ClimaxHangRenderer.render(
                left: left,
                right: right,
                articulation: ClimaxHangArticulation(),
                sampleRate: sampleRate
            )
            let evidence = rendered.evidence

            #expect(evidence.active)
            #expect(evidence.relation == .terminalRecoveryDelay)
            #expect(evidence.sampleRate == sampleRate)
            #expect(evidence.renderedFrameCount == frameCount)
            #expect(evidence.startStep == ClimaxHangContract.startStep)
            #expect(evidence.endStep == ClimaxHangContract.endStep)
            #expect(evidence.releaseStartFrame < evidence.silenceStartFrame)
            #expect(evidence.silenceStartFrame == Int((
                Double(ClimaxHangContract.startStep) * Double(frameCount) / 16
            ).rounded()))
            #expect(evidence.releaseFrameCount ==
                    evidence.silenceStartFrame - evidence.releaseStartFrame)
            #expect(evidence.silenceFrameCount ==
                    frameCount - evidence.silenceStartFrame)
            #expect(evidence.releaseInputRMS > 0)
            #expect(evidence.silencePeak == 0)
            #expect(evidence.silenceRMS == 0)
            #expect(evidence.silenceNonzeroSampleCount == 0)
            #expect(evidence.silenceStereoSampleHash ==
                    ExactPCMFingerprint.stereoZero(
                        sampleCount: evidence.silenceFrameCount
                    ))
            #expect(evidence.preHangStereoSampleHash !=
                    evidence.postHangStereoSampleHash)
            #expect(evidence.finite)
            #expect(rendered.left[evidence.releaseStartFrame] ==
                    left[evidence.releaseStartFrame])
            #expect(rendered.right[evidence.releaseStartFrame] ==
                    right[evidence.releaseStartFrame])
            #expect(rendered.left[evidence.silenceStartFrame - 1] == 0)
            #expect(rendered.right[evidence.silenceStartFrame - 1] == 0)
            #expect(rendered.left[evidence.silenceStartFrame...].allSatisfy {
                $0.bitPattern & 0x7fff_ffff == 0
            })
            #expect(rendered.right[evidence.silenceStartFrame...].allSatisfy {
                $0.bitPattern & 0x7fff_ffff == 0
            })
        }
    }

    @Test("Neutral hold is literal bit identity")
    func neutralIdentity() {
        let left: [Float] = [0, -0.0, 0.25, -0.5, 0.75]
        let right: [Float] = [-0.75, 0.5, -0.25, -0.0, 0]
        let rendered = ClimaxHangRenderer.render(
            left: left,
            right: right,
            articulation: nil,
            sampleRate: 48_000
        )

        #expect(rendered.left.map(\.bitPattern) == left.map(\.bitPattern))
        #expect(rendered.right.map(\.bitPattern) == right.map(\.bitPattern))
        #expect(!rendered.evidence.active)
        #expect(rendered.evidence.relation == nil)
        #expect(rendered.evidence.preHangStereoSampleHash ==
                rendered.evidence.postHangStereoSampleHash)
        #expect(rendered.evidence.finite)
    }

    @Test("Malformed hold fails evidence without touching PCM")
    func malformedGeometryFailsClosed() {
        let left: [Float] = [0.3, -0.2, 0.1, -0.05]
        let right: [Float] = [-0.1, 0.2, -0.3, 0.4]
        let rendered = ClimaxHangRenderer.render(
            left: left,
            right: right,
            articulation: ClimaxHangArticulation(startStep: 11, endStep: 16),
            sampleRate: 48_000
        )

        #expect(rendered.left.map(\.bitPattern) == left.map(\.bitPattern))
        #expect(rendered.right.map(\.bitPattern) == right.map(\.bitPattern))
        #expect(rendered.evidence.active)
        #expect(!rendered.evidence.finite)
        #expect(rendered.evidence.releaseStartFrame == -1)
        #expect(rendered.evidence.silenceStartFrame == -1)
        #expect(rendered.evidence.preHangStereoSampleHash ==
                rendered.evidence.postHangStereoSampleHash)
    }
}
