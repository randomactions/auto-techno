import Foundation

/// Immutable transport provenance for one scheduled occurrence of an accepted
/// phrase. Repeating the same plan uses a new player sample range and therefore
/// remains a distinct ledger record.
package struct ScheduledPhraseRange: Equatable, Hashable, Sendable {
    package let phraseIndex: Int
    package let planFingerprint: String
    package let playerSampleRange: Range<Int64>
    package let routeGeneration: Int
    package let controllerRevision: Int

    package init(
        phraseIndex: Int,
        planFingerprint: String,
        playerSampleRange: Range<Int64>,
        routeGeneration: Int,
        controllerRevision: Int
    ) {
        self.phraseIndex = phraseIndex
        self.planFingerprint = planFingerprint
        self.playerSampleRange = playerSampleRange
        self.routeGeneration = routeGeneration
        self.controllerRevision = controllerRevision
    }
}

/// Bounded transport ledger: current playback, its one scheduled successor,
/// and the two most recent occurrences. It is sample provenance, not another
/// musical timeline.
package struct ScheduledPhraseLedger: Equatable, Sendable {
    package private(set) var playing: ScheduledPhraseRange?
    package private(set) var scheduledSuccessor: ScheduledPhraseRange?
    package private(set) var recent: [ScheduledPhraseRange] = []

    package init() {}

    package var retainedRanges: [ScheduledPhraseRange] {
        [playing, scheduledSuccessor].compactMap { $0 } + recent
    }

    package mutating func setPlaying(_ range: ScheduledPhraseRange?) {
        guard playing != range else {
            if scheduledSuccessor == range { scheduledSuccessor = nil }
            return
        }
        if let previous = playing {
            recent.removeAll { $0 == previous }
            recent.insert(previous, at: 0)
        }
        if let range {
            recent.removeAll { $0 == range }
        }
        if recent.count > 2 {
            recent.removeLast(recent.count - 2)
        }
        playing = range
        scheduledSuccessor = nil
    }

    package mutating func setScheduledSuccessor(_ range: ScheduledPhraseRange?) {
        guard range != playing else {
            scheduledSuccessor = nil
            return
        }
        scheduledSuccessor = range
        if let range {
            recent.removeAll { $0 == range }
        }
    }

    package func contains(_ range: ScheduledPhraseRange) -> Bool {
        retainedRanges.contains(range)
    }

    fileprivate func firstWindowRange(
        overlapping sampleRange: Range<Int64>,
        frameCount: Int64
    ) -> ScheduledPhraseRange? {
        retainedRanges.first { range in
            let end = range.playerSampleRange.lowerBound
                .addingReportingOverflow(frameCount)
            guard !end.overflow else { return false }
            let window = range.playerSampleRange.lowerBound..<end.partialValue
            return window.overlaps(sampleRange)
        }
    }
}

package struct LivePhrasePCMWindow: Equatable, Sendable {
    package let phraseIndex: Int
    package let planFingerprint: String
    package let routeGeneration: Int
    package let controllerRevision: Int
    package let playerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let left: [Float]
    package let right: [Float]
}

package enum LivePhraseWindowUnavailabilityReason: String, Equatable, Sendable {
    case invalidSourceRange
    case invalidPacket
    case packetSequenceDiscontinuity
    case sampleGap
    case sampleOverlap
    case queueDropDelta
    case rejectedPacketDelta
    case routeGenerationMismatch
    case controllerRevisionMismatch
    case nonFiniteSample
    case ledgerEviction
    case staleScheduledOccurrence
}

/// Mutable state owned by the detached packet consumer. It copies only the
/// first exact three seconds of one retained phrase at a time and emits one
/// immutable native-stereo value. No state or array in this type is reachable
/// from the real-time producer.
package struct LivePhraseWindowAssembler: Sendable {
    private struct Assembly: Sendable {
        let range: ScheduledPhraseRange
        let windowRange: Range<Int64>
        var left: [Float]
        var right: [Float]

        var nextExpectedPlayerSample: Int64 {
            windowRange.lowerBound + Int64(left.count)
        }
    }

    package let sampleRate: Double
    package let clockMap: MixerPlayerClockMap
    package let windowFrameCount: Int

    private var counters: LivePCMQueueCounterSnapshot
    private var lastPacketSequence: UInt64?
    private var knownRanges: Set<ScheduledPhraseRange> = []
    private var assembly: Assembly?
    private var emittedRanges: Set<ScheduledPhraseRange> = []
    private var unavailableRanges: [ScheduledPhraseRange: LivePhraseWindowUnavailabilityReason] = [:]
    package private(set) var lastUnavailabilityReason: LivePhraseWindowUnavailabilityReason?
    package private(set) var retirementRouteGeneration: Int?
    package private(set) var retiredThroughPlayerSample: Int64?

    package init?(
        sampleRate: Double,
        clockMap: MixerPlayerClockMap,
        initialCounters: LivePCMQueueCounterSnapshot
    ) {
        guard sampleRate == clockMap.sampleRate else { return nil }
        let windowFrameCount: Int
        switch sampleRate {
        case 44_100:
            windowFrameCount = 132_300
        case 48_000:
            windowFrameCount = 144_000
        default:
            return nil
        }
        self.sampleRate = sampleRate
        self.clockMap = clockMap
        self.windowFrameCount = windowFrameCount
        self.counters = initialCounters
    }

    package mutating func reconcile(with ledger: ScheduledPhraseLedger) {
        let retained = Set(ledger.retainedRanges)
        if let newestGeneration = retained.map(\.routeGeneration).max() {
            if retirementRouteGeneration.map({ newestGeneration > $0 }) ?? true {
                retirementRouteGeneration = newestGeneration
                retiredThroughPlayerSample = nil
            }
        }

        let evictedRanges = knownRanges.subtracting(retained)
        for evicted in evictedRanges {
            reject(evicted, reason: .ledgerEviction)
        }
        for evicted in evictedRanges
            where emittedRanges.contains(evicted) || unavailableRanges[evicted] != nil {
            advanceRetirementProof(with: evicted)
        }
        knownRanges = retained

        if let active = assembly,
           isStale(active.range) || !retained.contains(active.range) {
            reject(
                active.range,
                reason: isStale(active.range)
                    ? .staleScheduledOccurrence
                    : .ledgerEviction
            )
        }
        emittedRanges.formIntersection(retained)
        unavailableRanges = unavailableRanges.filter { retained.contains($0.key) }
    }

    package mutating func consume(
        _ packet: ConsumedLivePCMPacket,
        ledger: ScheduledPhraseLedger
    ) -> LivePhrasePCMWindow? {
        reconcile(with: ledger)

        let priorSequence = lastPacketSequence
        lastPacketSequence = packet.packetSequence
        let sequenceDiscontinuity: Bool
        if let priorSequence {
            let expected = priorSequence.addingReportingOverflow(1)
            sequenceDiscontinuity = expected.overflow || packet.packetSequence != expected.partialValue
        } else {
            sequenceDiscontinuity = false
        }

        let priorCounters = counters
        counters = packet.counters

        guard windowFrameCount > 0,
              sampleRate == clockMap.sampleRate,
              !packet.left.isEmpty,
              packet.left.count == packet.right.count,
              packet.left.count <= 1_024,
              let playerStart = clockMap.checkedPlayerSample(
                forMixerSample: packet.firstMixerSample
              ) else {
            rejectActive(reason: .invalidPacket)
            return nil
        }
        let end = playerStart.addingReportingOverflow(Int64(packet.left.count))
        guard !end.overflow else {
            rejectActive(reason: .invalidPacket)
            return nil
        }
        let packetRange = playerStart..<end.partialValue

        var target = assembly?.range
        if let active = assembly,
           !active.windowRange.overlaps(packetRange) {
            if packetRange.lowerBound >= active.nextExpectedPlayerSample {
                reject(active.range, reason: .sampleGap)
            } else {
                reject(active.range, reason: .sampleOverlap)
            }
            target = nil
        }
        if target == nil {
            target = ledger.firstWindowRange(
                overlapping: packetRange,
                frameCount: Int64(windowFrameCount)
            )
        }
        guard let target else { return nil }
        if isStale(target) {
            reject(target, reason: .staleScheduledOccurrence)
            return nil
        }
        guard !emittedRanges.contains(target),
              unavailableRanges[target] == nil else {
            return nil
        }

        var beganAssemblyAtPhraseOnset = false
        if assembly == nil {
            let sourceLength = target.playerSampleRange.upperBound
                .subtractingReportingOverflow(target.playerSampleRange.lowerBound)
            guard !sourceLength.overflow,
                  sourceLength.partialValue >= Int64(windowFrameCount) else {
                reject(target, reason: .invalidSourceRange)
                return nil
            }
            var left: [Float] = []
            var right: [Float] = []
            left.reserveCapacity(windowFrameCount)
            right.reserveCapacity(windowFrameCount)
            let windowRange = target.playerSampleRange.lowerBound..<(target.playerSampleRange.lowerBound + Int64(windowFrameCount))
            beganAssemblyAtPhraseOnset = packetRange.lowerBound <= windowRange.lowerBound &&
                packetRange.upperBound > windowRange.lowerBound
            assembly = Assembly(
                range: target,
                windowRange: windowRange,
                left: left,
                right: right
            )
        }

        guard let active = assembly,
              active.range == target else {
            return nil
        }
        if !beganAssemblyAtPhraseOnset && sequenceDiscontinuity {
            reject(target, reason: .packetSequenceDiscontinuity)
            return nil
        }
        if !beganAssemblyAtPhraseOnset &&
            packet.counters.droppedPackets != priorCounters.droppedPackets {
            reject(target, reason: .queueDropDelta)
            return nil
        }
        if !beganAssemblyAtPhraseOnset &&
            packet.counters.rejectedPackets != priorCounters.rejectedPackets {
            reject(target, reason: .rejectedPacketDelta)
            return nil
        }
        guard packet.routeGeneration == target.routeGeneration else {
            reject(target, reason: .routeGenerationMismatch)
            return nil
        }
        guard packet.controllerRevision == target.controllerRevision else {
            reject(target, reason: .controllerRevisionMismatch)
            return nil
        }

        let intersection = packetRange.clamped(to: active.windowRange)
        guard !intersection.isEmpty else { return nil }
        if intersection.lowerBound > active.nextExpectedPlayerSample {
            reject(target, reason: .sampleGap)
            return nil
        }
        if intersection.lowerBound < active.nextExpectedPlayerSample {
            reject(target, reason: .sampleOverlap)
            return nil
        }

        let packetOffset = Int(intersection.lowerBound - packetRange.lowerBound)
        let copyCount = Int(intersection.upperBound - intersection.lowerBound)
        let copyRange = packetOffset..<(packetOffset + copyCount)
        guard copyRange.lowerBound >= 0,
              copyRange.upperBound <= packet.left.count else {
            reject(target, reason: .invalidPacket)
            return nil
        }
        guard packet.left[copyRange].allSatisfy(\.isFinite),
              packet.right[copyRange].allSatisfy(\.isFinite) else {
            reject(target, reason: .nonFiniteSample)
            return nil
        }

        assembly?.left.append(contentsOf: packet.left[copyRange])
        assembly?.right.append(contentsOf: packet.right[copyRange])
        guard let completed = assembly,
              completed.left.count == windowFrameCount,
              completed.right.count == windowFrameCount else {
            return nil
        }

        let window = LivePhrasePCMWindow(
            phraseIndex: target.phraseIndex,
            planFingerprint: target.planFingerprint,
            routeGeneration: target.routeGeneration,
            controllerRevision: target.controllerRevision,
            playerSampleRange: completed.windowRange,
            sampleRate: sampleRate,
            left: completed.left,
            right: completed.right
        )
        emittedRanges.insert(target)
        assembly = nil
        return window
    }

    package func hasEmitted(_ range: ScheduledPhraseRange) -> Bool {
        emittedRanges.contains(range)
    }

    package func unavailability(
        for range: ScheduledPhraseRange
    ) -> LivePhraseWindowUnavailabilityReason? {
        unavailableRanges[range]
    }

    package var trackedEmissionCount: Int {
        emittedRanges.count
    }

    package var trackedUnavailabilityCount: Int {
        unavailableRanges.count
    }

    package var bookkeepingIdentityCount: Int {
        emittedRanges.count + unavailableRanges.count
    }

    private func isStale(_ range: ScheduledPhraseRange) -> Bool {
        guard let retirementRouteGeneration else { return false }
        if range.routeGeneration < retirementRouteGeneration { return true }
        if range.routeGeneration > retirementRouteGeneration { return false }
        guard let retiredThroughPlayerSample else { return false }
        return range.playerSampleRange.lowerBound <= retiredThroughPlayerSample
    }

    private mutating func advanceRetirementProof(with range: ScheduledPhraseRange) {
        guard range.routeGeneration == retirementRouteGeneration else { return }
        let finalRetiredSample = range.playerSampleRange.isEmpty
            ? range.playerSampleRange.lowerBound
            : range.playerSampleRange.upperBound - 1
        retiredThroughPlayerSample = max(
            retiredThroughPlayerSample ?? Int64.min,
            finalRetiredSample
        )
    }

    private mutating func rejectActive(reason: LivePhraseWindowUnavailabilityReason) {
        guard let active = assembly else { return }
        reject(active.range, reason: reason)
    }

    private mutating func reject(
        _ range: ScheduledPhraseRange,
        reason: LivePhraseWindowUnavailabilityReason
    ) {
        guard !emittedRanges.contains(range) else { return }
        lastUnavailabilityReason = reason
        if unavailableRanges[range] == nil {
            unavailableRanges[range] = reason
        }
        if assembly?.range == range {
            assembly = nil
        }
    }
}
