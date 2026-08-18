import AutoTechnoCore
import Foundation

/// State-free physical-time envelope applied inside the existing bounded
/// upper-percussion event loop. It owns no continuation and allocates no PCM.
package enum UpperPercussionTailDSPContract {
    package static let attackDurationSeconds = 0.008
    package static let clearanceFinalMultiplier: Float = 0.25

    package static func attackFrameCount(
        sampleRate: Double,
        renderedFrameCount: Int
    ) -> Int {
        guard sampleRate.isFinite, sampleRate > 0,
              renderedFrameCount > 0 else {
            return 0
        }
        return min(
            renderedFrameCount,
            max(0, Int((attackDurationSeconds * sampleRate).rounded()))
        )
    }

    package static func multiplier(
        role: UpperPercussionTailRole,
        frame: Int,
        renderedFrameCount: Int,
        sampleRate: Double
    ) -> Float {
        guard role == .foregroundClearance,
              renderedFrameCount > 0 else {
            return 1
        }
        let boundedFrame = min(max(0, frame), renderedFrameCount - 1)
        let attackFrames = attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        guard boundedFrame >= attackFrames else { return 1 }
        let tailFrameCount = renderedFrameCount - attackFrames
        guard tailFrameCount > 1 else {
            return tailFrameCount == 1 ? clearanceFinalMultiplier : 1
        }
        let progress = Double(boundedFrame - attackFrames) /
            Double(tailFrameCount - 1)
        let eased = 0.5 - 0.5 * cos(.pi * progress)
        return Float(1.0 - 0.75 * eased)
    }

    package static func process(
        sample: Float,
        role: UpperPercussionTailRole,
        frame: Int,
        renderedFrameCount: Int,
        sampleRate: Double
    ) -> Float {
        guard role == .foregroundClearance else { return sample }
        guard sample != 0 else { return sample }
        return sample * multiplier(
            role: role,
            frame: frame,
            renderedFrameCount: renderedFrameCount,
            sampleRate: sampleRate
        )
    }
}
