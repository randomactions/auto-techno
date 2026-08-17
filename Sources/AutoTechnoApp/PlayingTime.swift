import Foundation

/// Main-thread presentation state derived from the player's rendered sample
/// clock. It never runs on, or introduces work into, the audio callback.
package struct PlayingTimeClock: Sendable {
    package private(set) var elapsedWholeSeconds = 0

    private var elapsedSeconds = 0.0
    private var timelineBaseSeconds = 0.0

    package init() {}

    @discardableResult
    package mutating func observe(
        sampleTime: Int64,
        sampleRate: Double
    ) -> Int {
        guard sampleTime >= 0,
              sampleRate.isFinite,
              sampleRate > 0 else { return elapsedWholeSeconds }

        let timelineSeconds = Double(sampleTime) / sampleRate
        guard timelineSeconds.isFinite, timelineSeconds >= 0 else {
            return elapsedWholeSeconds
        }

        elapsedSeconds = max(
            elapsedSeconds,
            timelineBaseSeconds + timelineSeconds
        )
        elapsedWholeSeconds = Int(min(
            elapsedSeconds.rounded(.down),
            Double(Int.max)
        ))
        return elapsedWholeSeconds
    }

    /// Player sample time restarts at zero after route recovery. Preserve the
    /// already rendered duration as the base of the replacement timeline.
    package mutating func preserveForTimelineReset() {
        timelineBaseSeconds = elapsedSeconds
    }

    package mutating func reset() {
        elapsedSeconds = 0
        timelineBaseSeconds = 0
        elapsedWholeSeconds = 0
    }
}

package enum PlayingTimeFormatter {
    package static func string(forWholeSeconds seconds: Int) -> String {
        let bounded = max(0, seconds)
        let hours = bounded / 3_600
        let minutes = bounded % 3_600 / 60
        let remainingSeconds = bounded % 60

        if hours > 0 {
            return "\(hours):\(twoDigits(minutes)):\(twoDigits(remainingSeconds))"
        }
        return "\(twoDigits(minutes)):\(twoDigits(remainingSeconds))"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
