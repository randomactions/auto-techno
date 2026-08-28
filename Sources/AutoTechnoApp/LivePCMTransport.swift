import AVFoundation
import CAutoTechnoRealtime
import Foundation

package final class LivePCMConsumerLease: @unchecked Sendable {
    package let identity: LiveFeedbackWorkerIdentity
    package let token = UUID()

    fileprivate init(identity: LiveFeedbackWorkerIdentity) {
        self.identity = identity
    }
}

/// Sole owner of the callback-facing C queue and canonical-capture-mixer tap.
/// Queue storage, generation updates, tap installation/removal, and
/// destruction are control-thread work. The callback captures only the
/// immutable C queue address.
package final class LivePCMTransport: @unchecked Sendable {
    package static let maximumPacketFrameCount = Int(AT_LIVE_PCM_MAX_FRAMES)
    package static let queueCapacity = Int(AT_LIVE_PCM_CAPACITY)
    package static let queueStorageByteCount = Int(
        ATLivePCMQueueStorageByteCount()
    )

    private var queue: OpaquePointer?
    private var boundConsumerLease: LivePCMConsumerLease?
    private weak var tappedMixer: AVAudioMixerNode?
    package private(set) var tapIsInstalled = false

    package init?() {
        guard let queue = ATLivePCMQueueCreate() else { return nil }
        self.queue = queue
    }

    deinit {
        // An unbound setup failure is safe to reclaim automatically. Bound or
        // tapped storage still fails loudly and is never freed underneath
        // possibly in-flight callback/consumer work.
        if !tapIsInstalled, boundConsumerLease == nil, let queue {
            ATLivePCMQueueDestroy(queue)
            self.queue = nil
        }
        assert(!tapIsInstalled && boundConsumerLease == nil && self.queue == nil,
               "LivePCMTransport requires explicit stopped/joined destruction")
    }

    package var queueHandle: OpaquePointer? { queue }
    package var consumerIsBound: Bool { boundConsumerLease != nil }

    package func bindConsumer(
        permit: LivePCMConsumerStartPermit
    ) -> LivePCMConsumerLease? {
        guard queue != nil,
              !tapIsInstalled,
              boundConsumerLease == nil else { return nil }
        let lease = LivePCMConsumerLease(identity: permit.identity)
        boundConsumerLease = lease
        return lease
    }

    package func setGeneration(
        routeGeneration: Int,
        controllerRevision: Int
    ) {
        guard let queue,
              routeGeneration >= 0,
              routeGeneration <= Int(UInt32.max),
              controllerRevision >= 0,
              controllerRevision <= Int(UInt32.max) else { return }
        ATLivePCMQueueSetGeneration(
            queue,
            UInt32(routeGeneration),
            UInt32(controllerRevision)
        )
    }

    /// Installs the one bounded producer callback. Do not add captures or work
    /// to this closure without rerunning the callback symbol/source audit.
    @discardableResult
    package func installTap(
        on canonicalMixer: AVAudioMixerNode,
        nativeStereoFormat: AVAudioFormat
    ) -> Bool {
        guard !tapIsInstalled,
              let queue,
              boundConsumerLease != nil,
              nativeStereoFormat.commonFormat == .pcmFormatFloat32,
              !nativeStereoFormat.isInterleaved,
              nativeStereoFormat.channelCount == 2,
              MixerPlayerClockMap.isSupported(
                sampleRate: nativeStereoFormat.sampleRate
              ) else { return false }

        canonicalMixer.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(AT_LIVE_PCM_MAX_FRAMES),
            format: nativeStereoFormat
        ) { [queue] buffer, time in
            guard time.isSampleTimeValid,
                  buffer.format.channelCount == 2,
                  buffer.frameLength > 0,
                  buffer.frameLength <= AT_LIVE_PCM_MAX_FRAMES,
                  let channels = buffer.floatChannelData else { return }
            _ = ATLivePCMQueueProduceNativeStereo(
                queue,
                time.sampleTime,
                channels[0],
                channels[1],
                buffer.frameLength
            )
        }
        tappedMixer = canonicalMixer
        tapIsInstalled = true
        return true
    }

    /// Must run while the engine is stopped or paused and before the consumer
    /// is joined or the queue can be released.
    package func removeTap() {
        guard tapIsInstalled else { return }
        tappedMixer?.removeTap(onBus: 0)
        tappedMixer = nil
        tapIsInstalled = false
    }

    /// The lifecycle owner proves that the producer was removed and the serial
    /// consumer joined before calling this method.
    @discardableResult
    package func destroyQueueAfterConsumerStopped(
        proof: LivePCMConsumerStopProof
    ) -> Bool {
        guard !tapIsInstalled,
              boundConsumerLease?.token == proof.token,
              boundConsumerLease?.identity == proof.identity,
              let queue else { return false }
        boundConsumerLease = nil
        self.queue = nil
        ATLivePCMQueueDestroy(queue)
        return true
    }

    /// A queue that was never bound to a consumer has no in-flight consumer
    /// storage. This is used only when setup fails before worker start.
    @discardableResult
    package func destroyQueueBeforeConsumerStarts() -> Bool {
        guard !tapIsInstalled,
              boundConsumerLease == nil,
              let queue else { return false }
        self.queue = nil
        ATLivePCMQueueDestroy(queue)
        return true
    }

    package var counters: LivePCMQueueCounterSnapshot {
        guard let queue else { return .zero }
        return LivePCMQueueCounterSnapshot(
            droppedPackets: ATLivePCMQueueDroppedPacketCount(queue),
            rejectedPackets: ATLivePCMQueueRejectedPacketCount(queue)
        )
    }

    /// Consumer-only. The supplied arrays must remain uniquely worker-owned and
    /// preallocated to the queue's maximum packet size.
    package func consume(
        metadata: inout ATLivePCMPacketMetadata,
        left: inout [Float],
        right: inout [Float]
    ) -> Bool {
        guard let queue,
              left.count >= Self.maximumPacketFrameCount,
              right.count >= Self.maximumPacketFrameCount else { return false }
        return left.withUnsafeMutableBufferPointer { leftBuffer in
            right.withUnsafeMutableBufferPointer { rightBuffer in
                ATLivePCMQueueConsume(
                    queue,
                    &metadata,
                    leftBuffer.baseAddress,
                    rightBuffer.baseAddress,
                    UInt32(Self.maximumPacketFrameCount)
                )
            }
        }
    }

    /// Consumer-only fixed-pointer path used by the production worker. The
    /// pointers are allocated once before producer startup and never resized.
    package func consume(
        metadata: inout ATLivePCMPacketMetadata,
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>
    ) -> Bool {
        guard let queue,
              left.count == Self.maximumPacketFrameCount,
              right.count == Self.maximumPacketFrameCount else { return false }
        return ATLivePCMQueueConsume(
            queue,
            &metadata,
            left.baseAddress,
            right.baseAddress,
            UInt32(Self.maximumPacketFrameCount)
        )
    }

    /// Deterministic queue replay seam. This runs off the callback and exists so
    /// App tests can prove the wrapper preserves the exact C packet contract.
    package func publishNativeStereoForOfflineReplay(
        firstMixerSample: Int64,
        left: [Float],
        right: [Float]
    ) -> Bool {
        guard let queue,
              !left.isEmpty,
              left.count == right.count,
              left.count <= Self.maximumPacketFrameCount else { return false }
        return left.withUnsafeBufferPointer { leftBuffer in
            right.withUnsafeBufferPointer { rightBuffer in
                ATLivePCMQueueProduceNativeStereo(
                    queue,
                    firstMixerSample,
                    leftBuffer.baseAddress,
                    rightBuffer.baseAddress,
                    UInt32(left.count)
                )
            }
        }
    }

    package func consumeOneForOfflineReplay() -> ConsumedLivePCMPacket? {
        var metadata = ATLivePCMPacketMetadata()
        var left = [Float](
            repeating: 0,
            count: Self.maximumPacketFrameCount
        )
        var right = left
        guard consume(metadata: &metadata, left: &left, right: &right) else {
            return nil
        }
        let frameCount = Int(metadata.frameCount)
        return ConsumedLivePCMPacket(
            packetSequence: metadata.packetSequence,
            firstMixerSample: metadata.firstMixerSample,
            routeGeneration: Int(metadata.routeGeneration),
            controllerRevision: Int(metadata.controllerRevision),
            counters: counters,
            left: Array(left.prefix(frameCount)),
            right: Array(right.prefix(frameCount))
        )
    }
}

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

    package func checkedMixerSample(forPlayerSample sample: Int64) -> Int64? {
        let result = sample.subtractingReportingOverflow(sampleOffset)
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
