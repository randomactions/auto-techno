/// Host-local listening attenuation. This state never enters score, rendered
/// PCM, quality, continuation, or live-feedback provenance.
package struct MonitoringOutputState: Equatable, Sendable {
    package static let defaultVolume = 1.0
    package static let minimumAudibleVolume = 0.001

    package private(set) var volume: Double
    package private(set) var isMuted: Bool
    private var lastAudibleVolume: Double

    package init(
        volume: Double = Self.defaultVolume,
        isMuted: Bool = false
    ) {
        let clamped = Self.clamp(volume)
        self.volume = clamped
        self.isMuted = isMuted || clamped < Self.minimumAudibleVolume
        lastAudibleVolume = clamped >= Self.minimumAudibleVolume
            ? clamped : Self.defaultVolume
    }

    package mutating func setVolume(_ proposedVolume: Double) {
        guard proposedVolume.isFinite else { return }
        let clamped = Self.clamp(proposedVolume)
        volume = clamped
        if clamped >= Self.minimumAudibleVolume {
            lastAudibleVolume = clamped
            isMuted = false
        } else {
            volume = 0
            isMuted = true
        }
    }

    package mutating func toggleMute() {
        if isMuted {
            if volume < Self.minimumAudibleVolume {
                volume = lastAudibleVolume
            }
            isMuted = false
        } else {
            if volume >= Self.minimumAudibleVolume {
                lastAudibleVolume = volume
            }
            isMuted = true
        }
    }

    package var linearGain: Float {
        isMuted ? 0 : Float(volume)
    }

    package var percentage: Int {
        Int((volume * 100).rounded())
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return defaultVolume }
        return min(1, max(0, value))
    }
}
