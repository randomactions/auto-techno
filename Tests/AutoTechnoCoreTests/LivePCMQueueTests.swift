import CAutoTechnoRealtime
import Testing

@Suite("Live PCM queue")
struct LivePCMQueueTests: Sendable {
    @Test("Allocated queue storage satisfies its extended alignment contract")
    func allocatedQueueMeetsRequiredAlignment() {
        withQueue { queue in
            #expect(
                UInt(bitPattern: queue) % UInt(AT_LIVE_PCM_QUEUE_ALIGNMENT) == 0
            )
        }
    }

    @Test("Native stereo packets round-trip in FIFO order")
    func nativeStereoRoundTripIsOrdered() {
        withQueue { queue in
            ATLivePCMQueueSetGeneration(queue, 7, 11)

            let firstLeft: [Float] = [0, 1, 2, 3]
            let firstRight: [Float] = [100, 101, 102, 103]
            let secondLeft: [Float] = [4, 5, 6]
            let secondRight: [Float] = [104, 105, 106]

            #expect(produce(
                queue: queue,
                firstMixerSample: 4_096,
                left: firstLeft,
                right: firstRight
            ))
            #expect(produce(
                queue: queue,
                firstMixerSample: 4_100,
                left: secondLeft,
                right: secondRight
            ))

            let first = consume(queue: queue)
            #expect(first?.metadata.packetSequence == 0)
            #expect(first?.metadata.firstMixerSample == 4_096)
            #expect(first?.metadata.frameCount == 4)
            #expect(first?.metadata.routeGeneration == 7)
            #expect(first?.metadata.controllerRevision == 11)
            #expect(first?.left == firstLeft)
            #expect(first?.right == firstRight)

            let second = consume(queue: queue)
            #expect(second?.metadata.packetSequence == 1)
            #expect(second?.metadata.firstMixerSample == 4_100)
            #expect(second?.left == secondLeft)
            #expect(second?.right == secondRight)
            #expect(consume(queue: queue)?.metadata.packetSequence == nil)
        }
    }

    @Test("A full queue drops the new packet without overwriting unread PCM")
    func fullQueueDropsWithoutOverwritingUnreadPCM() {
        withQueue { queue in
            for packet in 0..<Int(AT_LIVE_PCM_CAPACITY) {
                let sample = Float(packet)
                #expect(produce(
                    queue: queue,
                    firstMixerSample: Int64(packet),
                    left: [sample],
                    right: [-sample]
                ))
            }

            #expect(!produce(
                queue: queue,
                firstMixerSample: 999,
                left: [-999],
                right: [999]
            ))
            #expect(ATLivePCMQueueDroppedPacketCount(queue) == 1)

            for packet in 0..<Int(AT_LIVE_PCM_CAPACITY) {
                let consumed = consume(queue: queue)
                #expect(consumed?.metadata.packetSequence == UInt64(packet))
                #expect(consumed?.metadata.firstMixerSample == Int64(packet))
                #expect(consumed?.left == [Float(packet)])
                #expect(consumed?.right == [-Float(packet)])
            }
            #expect(consume(queue: queue)?.metadata.packetSequence == nil)
        }
    }

    @Test("Oversized and malformed packets are rejected before publication")
    func oversizedPacketIsRejected() {
        withQueue { queue in
            let validChannel = [Float](repeating: 0, count: Int(AT_LIVE_PCM_MAX_FRAMES) + 1)

            let oversized = validChannel.withUnsafeBufferPointer { samples in
                ATLivePCMQueueProduceNativeStereo(
                    queue,
                    0,
                    samples.baseAddress,
                    samples.baseAddress,
                    UInt32(samples.count)
                )
            }
            let missingLeft = validChannel.withUnsafeBufferPointer { samples in
                ATLivePCMQueueProduceNativeStereo(queue, 0, nil, samples.baseAddress, 1)
            }
            let zeroFrames = validChannel.withUnsafeBufferPointer { samples in
                ATLivePCMQueueProduceNativeStereo(queue, 0, samples.baseAddress, samples.baseAddress, 0)
            }

            #expect(!oversized)
            #expect(!missingLeft)
            #expect(!zeroFrames)
            #expect(ATLivePCMQueueRejectedPacketCount(queue) == 3)
            #expect(consume(queue: queue)?.metadata.packetSequence == nil)

            #expect(produce(queue: queue, firstMixerSample: 1, left: [1], right: [2]))
            #expect(consume(queue: queue)?.left == [1])
        }
    }

    @Test("Generation metadata is captured at each packet boundary")
    func metadataChangesAreObservedAtPacketBoundary() {
        withQueue { queue in
            ATLivePCMQueueSetGeneration(queue, 3, 5)
            #expect(produce(queue: queue, firstMixerSample: 100, left: [1], right: [2]))

            ATLivePCMQueueSetGeneration(queue, 4, 8)
            #expect(produce(queue: queue, firstMixerSample: 101, left: [3], right: [4]))

            let first = consume(queue: queue)
            let second = consume(queue: queue)
            #expect(first?.metadata.routeGeneration == 3)
            #expect(first?.metadata.controllerRevision == 5)
            #expect(second?.metadata.routeGeneration == 4)
            #expect(second?.metadata.controllerRevision == 8)
        }
    }

    @Test("Repeated fill and drain cycles preserve monotonic sequence and FIFO slots")
    func wraparoundPreservesSequence() {
        withQueue { queue in
            var expectedSequence: UInt64 = 0

            for cycle in 0..<3 {
                for offset in 0..<Int(AT_LIVE_PCM_CAPACITY) {
                    let marker = Float(cycle * Int(AT_LIVE_PCM_CAPACITY) + offset)
                    #expect(produce(
                        queue: queue,
                        firstMixerSample: Int64(marker),
                        left: [marker, marker + 0.25],
                        right: [-marker, -marker - 0.25]
                    ))
                }

                for _ in 0..<Int(AT_LIVE_PCM_CAPACITY) {
                    let packet = consume(queue: queue)
                    let marker = Float(expectedSequence)
                    #expect(packet?.metadata.packetSequence == expectedSequence)
                    #expect(packet?.left == [marker, marker + 0.25])
                    #expect(packet?.right == [-marker, -marker - 0.25])
                    expectedSequence += 1
                }
            }

            #expect(expectedSequence == UInt64(AT_LIVE_PCM_CAPACITY) * 3)
            #expect(consume(queue: queue)?.metadata.packetSequence == nil)
        }
    }

    @Test("One simultaneous producer and consumer preserve every packet")
    func simultaneousSPSCTransferPreservesPackets() async {
        let queue = ATLivePCMQueueCreate()
        #expect(queue != nil)
        guard let queue else { return }
        let handle = QueueHandle(queue)
        defer { ATLivePCMQueueDestroy(queue) }

        let packetCount = 1_024
        let frameCount = 8
        let maximumRetryCount = 1_000_000
        let firstSampleBase: Int64 = 65_536
        let routeGeneration: UInt32 = 13
        let controllerRevision: UInt32 = 21
        ATLivePCMQueueSetGeneration(queue, routeGeneration, controllerRevision)

        let producer = Task.detached { [self, handle] in
            var retryCount = 0
            for packetIndex in 0..<packetCount {
                let base = Float(packetIndex * frameCount)
                let left = (0..<frameCount).map { base + Float($0) * 0.25 }
                let right = (0..<frameCount).map { -base - Float($0) * 0.5 }

                while !produce(
                    queue: handle.pointer,
                    firstMixerSample: firstSampleBase + Int64(packetIndex * frameCount),
                    left: left,
                    right: right
                ) {
                    retryCount += 1
                    guard retryCount <= maximumRetryCount else { return false }
                    await Task.yield()
                }
            }
            return true
        }

        let consumer = Task.detached { [self, handle] in
            var packets: [ConsumedPacket] = []
            packets.reserveCapacity(packetCount)
            var emptyPollCount = 0

            while packets.count < packetCount {
                if let packet = consume(
                    queue: handle.pointer,
                    outputCapacity: frameCount
                ) {
                    packets.append(packet)
                } else {
                    emptyPollCount += 1
                    guard emptyPollCount <= maximumRetryCount else { return packets }
                    await Task.yield()
                }
            }
            return packets
        }

        let producerCompleted = await producer.value
        let packets = await consumer.value

        #expect(producerCompleted)
        #expect(packets.count == packetCount)
        #expect(ATLivePCMQueueRejectedPacketCount(queue) == 0)
        for (packetIndex, packet) in packets.enumerated() {
            let base = Float(packetIndex * frameCount)
            #expect(packet.metadata.packetSequence == UInt64(packetIndex))
            #expect(
                packet.metadata.firstMixerSample ==
                    firstSampleBase + Int64(packetIndex * frameCount)
            )
            #expect(packet.metadata.frameCount == UInt32(frameCount))
            #expect(packet.metadata.routeGeneration == routeGeneration)
            #expect(packet.metadata.controllerRevision == controllerRevision)
            #expect(packet.left == (0..<frameCount).map { base + Float($0) * 0.25 })
            #expect(packet.right == (0..<frameCount).map { -base - Float($0) * 0.5 })
        }
    }

    private final class QueueHandle: @unchecked Sendable {
        let pointer: OpaquePointer

        init(_ pointer: OpaquePointer) {
            self.pointer = pointer
        }
    }

    private struct ConsumedPacket: @unchecked Sendable {
        let metadata: ATLivePCMPacketMetadata
        let left: [Float]
        let right: [Float]
    }

    private func withQueue(_ body: (OpaquePointer) -> Void) {
        let queue = ATLivePCMQueueCreate()
        #expect(queue != nil)
        guard let queue else { return }
        defer { ATLivePCMQueueDestroy(queue) }
        body(queue)
    }

    private func produce(
        queue: OpaquePointer,
        firstMixerSample: Int64,
        left: [Float],
        right: [Float]
    ) -> Bool {
        guard left.count == right.count else { return false }
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

    private func consume(
        queue: OpaquePointer,
        outputCapacity: Int = Int(AT_LIVE_PCM_MAX_FRAMES)
    ) -> ConsumedPacket? {
        var metadata = ATLivePCMPacketMetadata()
        var left = [Float](repeating: .nan, count: outputCapacity)
        var right = [Float](repeating: .nan, count: outputCapacity)
        let consumed = left.withUnsafeMutableBufferPointer { leftBuffer in
            right.withUnsafeMutableBufferPointer { rightBuffer in
                ATLivePCMQueueConsume(
                    queue,
                    &metadata,
                    leftBuffer.baseAddress,
                    rightBuffer.baseAddress,
                    UInt32(outputCapacity)
                )
            }
        }
        guard consumed else { return nil }
        let frameCount = Int(metadata.frameCount)
        return ConsumedPacket(
            metadata: metadata,
            left: Array(left.prefix(frameCount)),
            right: Array(right.prefix(frameCount))
        )
    }
}
