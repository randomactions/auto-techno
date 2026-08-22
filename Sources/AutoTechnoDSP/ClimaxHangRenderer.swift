import AutoTechnoCore
import Foundation

package struct ClimaxHangRenderEvidence: Equatable, Sendable {
    package let active: Bool
    package let relation: ClimaxHangRelation?
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let startStep: Int
    package let endStep: Int
    package let releaseStartFrame: Int
    package let silenceStartFrame: Int
    package let releaseFrameCount: Int
    package let silenceFrameCount: Int
    package let preHangStereoSampleHash: String
    package let postHangStereoSampleHash: String
    package let silenceStereoSampleHash: String
    package let releaseInputRMS: Double
    package let silencePeak: Double
    package let silenceRMS: Double
    package let silenceNonzeroSampleCount: Int
    package let finite: Bool

    package static let neutral = ClimaxHangRenderEvidence(
        active: false,
        relation: nil,
        sampleRate: 0,
        renderedFrameCount: 0,
        startStep: -1,
        endStep: -1,
        releaseStartFrame: -1,
        silenceStartFrame: -1,
        releaseFrameCount: 0,
        silenceFrameCount: 0,
        preHangStereoSampleHash: "0123456789abcdef",
        postHangStereoSampleHash: "0123456789abcdef",
        silenceStereoSampleHash: "0123456789abcdef",
        releaseInputRMS: 0,
        silencePeak: 0,
        silenceRMS: 0,
        silenceNonzeroSampleCount: 0,
        finite: true
    )
}

/// Detached-preparation realization of one score-owned terminal hold. The
/// graph and voice continuations keep advancing under the bounded output
/// projection; the next bar therefore resumes the existing canonical state.
package enum ClimaxHangRenderer {
    package static let releaseSeconds = 0.008

    package static func render(
        left: [Float],
        right: [Float],
        articulation: ClimaxHangArticulation?,
        sampleRate: Double
    ) -> (
        left: [Float],
        right: [Float],
        evidence: ClimaxHangRenderEvidence
    ) {
        let frameCount = min(left.count, right.count)
        let preHash = ExactPCMFingerprint.stereo(left: left, right: right)
        guard let articulation else {
            return (
                left,
                right,
                ClimaxHangRenderEvidence(
                    active: false,
                    relation: nil,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount,
                    startStep: -1,
                    endStep: -1,
                    releaseStartFrame: -1,
                    silenceStartFrame: -1,
                    releaseFrameCount: 0,
                    silenceFrameCount: 0,
                    preHangStereoSampleHash: preHash,
                    postHangStereoSampleHash: preHash,
                    silenceStereoSampleHash:
                        ExactPCMFingerprint.stereo(left: [], right: []),
                    releaseInputRMS: 0,
                    silencePeak: 0,
                    silenceRMS: 0,
                    silenceNonzeroSampleCount: 0,
                    finite: sampleRate.isFinite && sampleRate > 0 &&
                        !left.isEmpty && left.count == right.count &&
                        left.allSatisfy(\.isFinite) &&
                        right.allSatisfy(\.isFinite)
                )
            )
        }

        let geometryValid = sampleRate.isFinite && sampleRate > 0 &&
            !left.isEmpty && left.count == right.count &&
            articulation.relation == .terminalRecoveryDelay &&
            articulation.startStep == ClimaxHangContract.startStep &&
            articulation.endStep == ClimaxHangContract.endStep
        guard geometryValid else {
            return (
                left,
                right,
                ClimaxHangRenderEvidence(
                    active: true,
                    relation: articulation.relation,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount,
                    startStep: articulation.startStep,
                    endStep: articulation.endStep,
                    releaseStartFrame: -1,
                    silenceStartFrame: -1,
                    releaseFrameCount: 0,
                    silenceFrameCount: 0,
                    preHangStereoSampleHash: preHash,
                    postHangStereoSampleHash: preHash,
                    silenceStereoSampleHash:
                        ExactPCMFingerprint.stereo(left: [], right: []),
                    releaseInputRMS: 0,
                    silencePeak: 0,
                    silenceRMS: 0,
                    silenceNonzeroSampleCount: 0,
                    finite: false
                )
            )
        }

        let silenceStartFrame = Int((
            Double(articulation.startStep) * Double(frameCount) / 16
        ).rounded())
        let requestedReleaseFrames = max(
            1,
            Int((sampleRate * releaseSeconds).rounded())
        )
        let releaseStartFrame = max(
            0,
            silenceStartFrame - requestedReleaseFrames
        )
        let releaseFrameCount = silenceStartFrame - releaseStartFrame
        let silenceFrameCount = frameCount - silenceStartFrame
        var outputLeft = left
        var outputRight = right
        var releaseInputEnergy = 0.0

        if releaseFrameCount > 0 {
            for index in releaseStartFrame..<silenceStartFrame {
                let leftValue = Double(left[index])
                let rightValue = Double(right[index])
                releaseInputEnergy += leftValue * leftValue +
                    rightValue * rightValue
                let gain: Double
                if index == releaseStartFrame {
                    gain = 1
                } else if index == silenceStartFrame - 1 {
                    gain = 0
                } else {
                    let progress = Double(index - releaseStartFrame) /
                        Double(max(1, releaseFrameCount - 1))
                    gain = 0.5 + 0.5 * cos(.pi * progress)
                }
                outputLeft[index] = Float(leftValue * gain)
                outputRight[index] = Float(rightValue * gain)
            }
        }
        if silenceStartFrame < frameCount {
            for index in silenceStartFrame..<frameCount {
                outputLeft[index] = 0
                outputRight[index] = 0
            }
        }

        let silenceLeft = Array(outputLeft[silenceStartFrame..<frameCount])
        let silenceRight = Array(outputRight[silenceStartFrame..<frameCount])
        let silencePeak = zip(silenceLeft, silenceRight).reduce(0.0) {
            max($0, abs(Double($1.0)), abs(Double($1.1)))
        }
        let silenceEnergy = zip(silenceLeft, silenceRight).reduce(0.0) {
            $0 + Double($1.0) * Double($1.0) +
                Double($1.1) * Double($1.1)
        }
        let silenceRMS = silenceFrameCount > 0
            ? sqrt(silenceEnergy / Double(silenceFrameCount * 2)) : 0
        let silenceNonzeroSampleCount = silenceLeft.reduce(0) {
            $0 + ($1.bitPattern & 0x7fff_ffff == 0 ? 0 : 1)
        } + silenceRight.reduce(0) {
            $0 + ($1.bitPattern & 0x7fff_ffff == 0 ? 0 : 1)
        }
        let releaseInputRMS = releaseFrameCount > 0
            ? sqrt(releaseInputEnergy / Double(releaseFrameCount * 2)) : 0
        let postHash = ExactPCMFingerprint.stereo(
            left: outputLeft,
            right: outputRight
        )

        return (
            outputLeft,
            outputRight,
            ClimaxHangRenderEvidence(
                active: true,
                relation: articulation.relation,
                sampleRate: sampleRate,
                renderedFrameCount: frameCount,
                startStep: articulation.startStep,
                endStep: articulation.endStep,
                releaseStartFrame: releaseStartFrame,
                silenceStartFrame: silenceStartFrame,
                releaseFrameCount: releaseFrameCount,
                silenceFrameCount: silenceFrameCount,
                preHangStereoSampleHash: preHash,
                postHangStereoSampleHash: postHash,
                silenceStereoSampleHash: ExactPCMFingerprint.stereo(
                    left: silenceLeft,
                    right: silenceRight
                ),
                releaseInputRMS: releaseInputRMS,
                silencePeak: silencePeak,
                silenceRMS: silenceRMS,
                silenceNonzeroSampleCount: silenceNonzeroSampleCount,
                finite: outputLeft.allSatisfy(\.isFinite) &&
                    outputRight.allSatisfy(\.isFinite) &&
                    releaseInputRMS.isFinite && silencePeak.isFinite &&
                    silenceRMS.isFinite && releaseFrameCount > 1 &&
                    silenceFrameCount > 0
            )
        )
    }
}
