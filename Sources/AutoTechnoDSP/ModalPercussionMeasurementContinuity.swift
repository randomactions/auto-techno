import AutoTechnoCore
import Foundation

/// Observation status never grants policy authority. Interrupted or unfinished
/// windows remain unavailable even when the audible resonator continues.
package enum ModalPercussionMeasurementStatus: String, Codable, Sendable {
    case complete, pending
    case barGap = "bar-gap"
    case routeChange = "route-change"
    case invalidInput = "invalid-input"
    case voiceCapacity = "voice-capacity"
    case observationCapacity = "observation-capacity"
}

/// One same-pass, source-separated 240 ms observation. The source identity is
/// the original bar plus exact articulation, never a reusable resonator slot.
package struct ModalPercussionContinuousEventEvidence: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let originBar: Int
    package let scoreEventIndex: Int
    package let articulationFingerprint: String
    package let sampleRate: Double
    package let startFrame: Int
    package let originFrameCount: Int
    package let lastObservedBar: Int
    package let observedFrameCount: Int
    package let status: ModalPercussionMeasurementStatus
    package let sampleFingerprint: String
    package let peak: Double
    package let attackRMS: Double
    package let bodyRMS: Double
    package let tailRMS: Double
    package let windowSupport: ModalPercussionWindowSupport

    package var identity: String { "\(originBar):\(scoreEventIndex):\(articulationFingerprint)" }

    package var isValid: Bool {
        guard schemaVersion == 1, originBar >= 0, scoreEventIndex >= 0,
              sampleRate.isFinite,
              (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate).contains(sampleRate),
              originFrameCount > 0, (0..<originFrameCount).contains(startFrame),
              lastObservedBar >= originBar,
              (0...Int(ceil(sampleRate * 0.240))).contains(observedFrameCount),
              articulationFingerprint.count == 16, sampleFingerprint.count == 16,
              [peak, attackRMS, bodyRMS, tailRMS].allSatisfy({ $0.isFinite && $0 >= 0 }),
              windowSupport.startFrame == 0 else { return false }
        func count(_ start: Double, _ end: Double) -> Int {
            max(0, min(observedFrameCount, Int(ceil(end * sampleRate))) -
                min(observedFrameCount, Int(ceil(start * sampleRate))))
        }
        return windowSupport.schemaVersion == 1 &&
            windowSupport.attackSampleCount == count(0, 0.010) &&
            windowSupport.bodySampleCount == count(0.020, 0.080) &&
            windowSupport.tailSampleCount == count(0.120, 0.240) &&
            (status == .complete ? observedFrameCount == Int(ceil(sampleRate * 0.240)) :
                observedFrameCount < Int(ceil(sampleRate * 0.240)))
    }
}

package struct ModalPercussionContinuousBarEvidence: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let bar: Int
    package let sampleRate: Double
    package let incomingStateFingerprint: String
    package let outgoingStateFingerprint: String
    package let completed: [ModalPercussionContinuousEventEvidence]
    package let pending: [ModalPercussionContinuousEventEvidence]
    package let droppedRecordCount: Int

    package var isValid: Bool {
        let all = completed + pending
        return schemaVersion == 1 && bar >= 0 && sampleRate.isFinite && sampleRate > 0 &&
            incomingStateFingerprint.count == 16 && outgoingStateFingerprint.count == 16 &&
            completed.count <= ModalPercussionMeasurementState.outputCapacity &&
            pending.count <= ModalPercussionMeasurementState.pendingCapacity &&
            droppedRecordCount >= 0 && Set(all.map(\.identity)).count == all.count &&
            all.allSatisfy { $0.isValid && $0.originBar <= bar && $0.lastObservedBar <= bar } &&
            completed.allSatisfy { $0.status != .pending } &&
            pending.allSatisfy { $0.status == .pending && $0.sampleRate == sampleRate }
    }
}

/// Detached renderer-owned observation continuation. Eight records cover two
/// generations per four voice slots: 240 ms < 2 * minimum 180 ms voice life.
/// Retired records keep observing actual zero contribution until their horizon.
/// No PCM is retained. Slots do not steal; observation overflow fails closed.
package struct ModalPercussionMeasurementState: Equatable, Sendable {
    package static let pendingCapacity = 8
    package static let outputCapacity = 32
    var pending: [Pending] = []
    var expectedBar: Int?

    package var fingerprint: String {
        var sink = StreamingFNV1a()
        sink.domain("modal-measurement-continuation.v1")
        sink.presence(expectedBar != nil)
        if let expectedBar { sink.int(expectedBar) }
        sink.collection(pending.count)
        for value in pending {
            sink.int(value.originBar); sink.int(value.scoreEventIndex)
            sink.string(value.articulationFingerprint); sink.double(value.sampleRate)
            sink.int(value.startFrame); sink.int(value.originFrameCount)
            sink.int(value.lastObservedBar); sink.int(value.observedFrameCount)
            sink.presence(value.slotIndex != nil)
            if let slot = value.slotIndex { sink.int(slot) }
            sink.string(value.hash.fingerprint); sink.double(value.peak)
            sink.double(value.attackEnergy); sink.double(value.bodyEnergy)
            sink.double(value.tailEnergy)
            sink.int(value.attackCount); sink.int(value.bodyCount); sink.int(value.tailCount)
        }
        return fixedWidthFingerprintHex(sink.value)
    }

    mutating func begin(bar: Int, sampleRate: Double, frameCount: Int,
                        completed: inout [ModalPercussionContinuousEventEvidence],
                        dropped: inout Int) {
        let reason: ModalPercussionMeasurementStatus?
        if pending.contains(where: { $0.sampleRate != sampleRate }) { reason = .routeChange }
        else if expectedBar != nil && expectedBar != bar { reason = .barGap }
        else if frameCount <= 0 || bar < 0 || bar == Int.max ||
                    pending.count > Self.pendingCapacity || pending.contains(where: {
                        !$0.evidence(status: .pending).isValid ||
                            $0.slotIndex.map { !(0..<ModalPercussionVoice.voiceCapacity).contains($0) } == true
                    }) {
            reason = .invalidInput
        } else { reason = nil }
        if let reason {
            for value in pending.prefix(Self.pendingCapacity) {
                Self.emit(value.evidence(status: reason), into: &completed, dropped: &dropped)
            }
            dropped += max(0, pending.count - Self.pendingCapacity)
            pending.removeAll(keepingCapacity: true)
            expectedBar = nil
        }
    }

    mutating func start(event: ScheduledModalPercussionEvent, bar: Int,
                        sampleRate: Double, frameCount: Int, slotIndex: Int?,
                        completed: inout [ModalPercussionContinuousEventEvidence],
                        dropped: inout Int) {
        let source = Pending(event: event, bar: bar, sampleRate: sampleRate,
                             frameCount: frameCount, slotIndex: slotIndex)
        let supported = sampleRate.isFinite &&
            (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate).contains(sampleRate)
        guard supported, frameCount > 0, bar >= 0,
              event.startFrame < frameCount else {
            Self.emit(source.evidence(status: .invalidInput), into: &completed, dropped: &dropped)
            return
        }
        guard slotIndex != nil else {
            Self.emit(source.evidence(status: .voiceCapacity), into: &completed, dropped: &dropped)
            return
        }
        guard pending.count < Self.pendingCapacity else {
            Self.emit(source.evidence(status: .observationCapacity), into: &completed, dropped: &dropped)
            return
        }
        pending.append(source)
    }

    mutating func observe(slotSamples: [Double], retired: [Bool], bar: Int,
                          completed: inout [ModalPercussionContinuousEventEvidence],
                          dropped: inout Int) {
        for index in pending.indices {
            let slot = pending[index].slotIndex
            let sample = slot.map { slotSamples[$0] } ?? 0
            pending[index].append(sample, bar: bar)
            if let slot, retired[slot] { pending[index].slotIndex = nil }
            if pending[index].observedFrameCount == pending[index].horizon {
                Self.emit(pending[index].evidence(status: .complete), into: &completed, dropped: &dropped)
            }
        }
        pending.removeAll { $0.observedFrameCount == $0.horizon }
    }

    mutating func finish(bar: Int) {
        expectedBar = pending.isEmpty ? nil : (bar == Int.max ? nil : bar + 1)
    }

    private static func emit(_ value: ModalPercussionContinuousEventEvidence,
                             into output: inout [ModalPercussionContinuousEventEvidence],
                             dropped: inout Int) {
        if output.count < outputCapacity { output.append(value) }
        else { dropped += 1 }
    }

    struct Pending: Equatable, Sendable {
        let originBar: Int
        let scoreEventIndex: Int
        let articulationFingerprint: String
        let sampleRate: Double
        let startFrame: Int
        let originFrameCount: Int
        var slotIndex: Int?
        var lastObservedBar: Int
        var observedFrameCount = 0
        var hash: ExactPCMFingerprint.MonoAccumulator
        var peak = 0.0
        var attackEnergy = 0.0, bodyEnergy = 0.0, tailEnergy = 0.0
        var attackCount = 0, bodyCount = 0, tailCount = 0

        var horizon: Int { Int(ceil(sampleRate * 0.240)) }

        init(event: ScheduledModalPercussionEvent, bar: Int, sampleRate: Double,
             frameCount: Int, slotIndex: Int?) {
            originBar = bar; scoreEventIndex = event.articulation.scoreEventIndex
            articulationFingerprint = AutonomousTypedFingerprint.modalArticulation(event.articulation)
            self.sampleRate = sampleRate.isFinite &&
                (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate).contains(sampleRate)
                ? sampleRate : 1
            startFrame = event.startFrame; originFrameCount = frameCount
            self.slotIndex = slotIndex; lastObservedBar = bar
            hash = ExactPCMFingerprint.MonoAccumulator(sampleCount: Int(ceil(self.sampleRate * 0.240)))
        }

        mutating func append(_ sample: Double, bar: Int) {
            // Exactly the Float contribution emitted by this canonical slot.
            // Preserve non-finite evidence, rather than manufacturing silence.
            let value = Float(sample)
            hash.append(value)
            let amplitude = Double(value)
            peak = max(peak, abs(amplitude))
            let elapsed = Double(observedFrameCount) / sampleRate
            if elapsed < 0.010 { attackEnergy += amplitude * amplitude; attackCount += 1 }
            else if elapsed >= 0.020 && elapsed < 0.080 { bodyEnergy += amplitude * amplitude; bodyCount += 1 }
            else if elapsed >= 0.120 && elapsed < 0.240 { tailEnergy += amplitude * amplitude; tailCount += 1 }
            observedFrameCount += 1
            lastObservedBar = bar
        }

        func evidence(status: ModalPercussionMeasurementStatus) -> ModalPercussionContinuousEventEvidence {
            .init(schemaVersion: 1, originBar: originBar, scoreEventIndex: scoreEventIndex,
                  articulationFingerprint: articulationFingerprint, sampleRate: sampleRate,
                  startFrame: startFrame, originFrameCount: originFrameCount,
                  lastObservedBar: lastObservedBar, observedFrameCount: observedFrameCount,
                  status: status, sampleFingerprint: hash.fingerprint, peak: peak,
                  attackRMS: sqrt(attackEnergy / Double(max(1, attackCount))),
                  bodyRMS: sqrt(bodyEnergy / Double(max(1, bodyCount))),
                  tailRMS: sqrt(tailEnergy / Double(max(1, tailCount))),
                  windowSupport: .init(startFrame: 0, attackSampleCount: attackCount,
                      bodySampleCount: bodyCount, tailSampleCount: tailCount))
        }
    }
}
