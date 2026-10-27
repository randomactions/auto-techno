import AutoTechnoCore
import Foundation

/// One physical source clock for the existing shared-noise percussion family.
/// The caller still owns score, event order, native articulation and evidence.
/// Scratch belongs to the detached workspace and never reaches continuation.
package enum PercussionReferenceSource {
    package static let sampleRate = 48_000.0
    package static let maximumFrameCount = 9_120

    @discardableResult
    package static func prepare(
        into source: inout [Float],
        durationSeconds: Double,
        availableFrames: Int,
        random: inout SeededGenerator,
        makeSample: (Double, Double) -> Float
    ) -> Bool {
        guard durationSeconds.isFinite, durationSeconds > 0,
              durationSeconds <= 0.19, availableFrames > 0 else { return false }
        let frames = min(Int(sampleRate * durationSeconds), availableFrames)
        guard frames > 0, frames <= maximumFrameCount else { return false }
        source.removeAll(keepingCapacity: true)
        source.reserveCapacity(maximumFrameCount)
        for frame in 0..<frames {
            let sample = makeSample(Double(frame) / sampleRate,
                random.unit() * 2 - 1)
            guard sample.isFinite else { return false }
            source.append(sample)
        }
        return true
    }

    package static func sample(_ source: [Float], frame: Int,
        nativeSampleRate: Double) -> Float {
        guard !source.isEmpty, frame >= 0,
              nativeSampleRate.isFinite, nativeSampleRate > 0 else { return .nan }
        let rate = sampleRate / nativeSampleRate
        return Float(BandLimitedInterpolator.sample(source,
            at: Double(frame) * rate, playbackRate: rate))
    }
}
