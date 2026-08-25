import Foundation

/// Fixed-cost sample-rate conversion for detached, phrase-local PCM reuse.
/// The kernel is stateless and deliberately small because score bounds already
/// limit each source window and trigger count.
package enum BandLimitedInterpolator {
    package static let kernelRadius = 16
    package static let downsamplingSafetyRatio = 0.94

    package static func sample(
        _ source: [Float],
        at position: Double,
        playbackRate: Double
    ) -> Double {
        guard !source.isEmpty,
              position.isFinite,
              playbackRate.isFinite,
              playbackRate > 0 else {
            return 0
        }

        let boundedPosition = min(
            Double(source.count - 1),
            max(0, position)
        )
        let nearestPosition = boundedPosition.rounded()
        if playbackRate <= 1,
           abs(boundedPosition - nearestPosition) <= 1e-12 {
            return Double(source[Int(nearestPosition)])
        }

        let cutoffRatio = playbackRate > 1
            ? downsamplingSafetyRatio / playbackRate : 1
        let center = Int(floor(boundedPosition))
        let firstIndex = center - kernelRadius + 1
        let lastIndex = center + kernelRadius
        var weightedSample = 0.0
        var weightSum = 0.0

        for unboundedIndex in firstIndex...lastIndex {
            let distance = boundedPosition - Double(unboundedIndex)
            guard abs(distance) < Double(kernelRadius) else { continue }
            let sinc: Double
            if abs(distance) <= 1e-12 {
                sinc = cutoffRatio
            } else {
                sinc = sin(.pi * cutoffRatio * distance) / (.pi * distance)
            }
            let window = 0.5 + 0.5 * cos(
                .pi * distance / Double(kernelRadius)
            )
            let weight = sinc * window
            let sourceIndex = min(
                source.count - 1,
                max(0, unboundedIndex)
            )
            weightedSample += Double(source[sourceIndex]) * weight
            weightSum += weight
        }

        guard weightSum.isFinite,
              abs(weightSum) > 1e-12,
              weightedSample.isFinite else {
            return 0
        }
        return weightedSample / weightSum
    }
}
