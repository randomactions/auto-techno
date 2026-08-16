import Foundation

/// One off-callback relationship between the mixer and player sample domains.
/// `Double` sample positions are retained here so a fractional conversion is
/// rejected before it can become an integer callback-side offset.
package struct MixerPlayerClockProbe: Equatable, Sendable {
    package let mixerSample: Double
    package let playerSample: Double
    package let mixerSampleRate: Double
    package let playerSampleRate: Double

    package init(
        mixerSample: Double,
        playerSample: Double,
        mixerSampleRate: Double,
        playerSampleRate: Double
    ) {
        self.mixerSample = mixerSample
        self.playerSample = playerSample
        self.mixerSampleRate = mixerSampleRate
        self.playerSampleRate = playerSampleRate
    }
}

/// Frozen, route-local mapping established from two matching off-callback
/// probes. The callback records only mixer-domain integer positions.
package struct MixerPlayerClockMap: Equatable, Sendable {
    package let sampleOffset: Int64
    package let sampleRate: Double

    package init?(sampleOffset: Int64, sampleRate: Double) {
        guard Self.isSupported(sampleRate: sampleRate) else { return nil }
        self.sampleOffset = sampleOffset
        self.sampleRate = sampleRate
    }

    package static func stable(
        first: MixerPlayerClockProbe,
        second: MixerPlayerClockProbe
    ) -> MixerPlayerClockMap? {
        guard Self.isSupported(sampleRate: first.mixerSampleRate),
              first.mixerSampleRate == first.playerSampleRate,
              first.mixerSampleRate == second.mixerSampleRate,
              second.mixerSampleRate == second.playerSampleRate,
              second.mixerSample > first.mixerSample,
              second.playerSample > first.playerSample,
              let firstOffset = exactInt64(first.playerSample - first.mixerSample),
              let secondOffset = exactInt64(second.playerSample - second.mixerSample),
              firstOffset == secondOffset else {
            return nil
        }
        return MixerPlayerClockMap(
            sampleOffset: firstOffset,
            sampleRate: first.mixerSampleRate
        )
    }

    package func checkedPlayerSample(forMixerSample sample: Int64) -> Int64? {
        let result = sample.addingReportingOverflow(sampleOffset)
        return result.overflow ? nil : result.partialValue
    }

    package static func isSupported(sampleRate: Double) -> Bool {
        sampleRate == 44_100 || sampleRate == 48_000
    }

    private static func exactInt64(_ value: Double) -> Int64? {
        guard value.isFinite,
              value.rounded(.towardZero) == value,
              value > Double(Int64.min),
              value < Double(Int64.max) else {
            return nil
        }
        return Int64(value)
    }
}

/// Monotonic queue counters sampled by the detached consumer. Only deltas
/// during a source window invalidate that window; historical nonzero values do
/// not poison a newly constructed assembler with the same baseline.
package struct LivePCMQueueCounterSnapshot: Equatable, Sendable {
    package static let zero = LivePCMQueueCounterSnapshot(
        droppedPackets: 0,
        rejectedPackets: 0
    )

    package let droppedPackets: UInt64
    package let rejectedPackets: UInt64

    package init(droppedPackets: UInt64, rejectedPackets: UInt64) {
        self.droppedPackets = droppedPackets
        self.rejectedPackets = rejectedPackets
    }
}

/// A packet after the detached consumer has copied it out of the C queue.
/// These arrays are never constructed or retained by the audio callback.
package struct ConsumedLivePCMPacket: Equatable, Sendable {
    package let packetSequence: UInt64
    package let firstMixerSample: Int64
    package let routeGeneration: Int
    package let controllerRevision: Int
    package let counters: LivePCMQueueCounterSnapshot
    package let left: [Float]
    package let right: [Float]

    package init(
        packetSequence: UInt64,
        firstMixerSample: Int64,
        routeGeneration: Int,
        controllerRevision: Int,
        counters: LivePCMQueueCounterSnapshot,
        left: [Float],
        right: [Float]
    ) {
        self.packetSequence = packetSequence
        self.firstMixerSample = firstMixerSample
        self.routeGeneration = routeGeneration
        self.controllerRevision = controllerRevision
        self.counters = counters
        self.left = left
        self.right = right
    }
}
