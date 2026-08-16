import AutoTechnoCore
import Foundation

package struct ModalPercussionModeState: Equatable, Sendable {
    package var frequencyHz = 0.0
    package var poleRadius = 0.0
    package var coefficient = 0.0
    package var weight = 0.0
    package var y1 = 0.0
    package var y2 = 0.0

    package init() {}
}

package struct ModalPercussionVoiceSlotState: Equatable, Sendable {
    package var active = false
    package var articulationSeed: UInt64 = 0
    package var ageFrames = 0
    package var remainingFrames = 0
    package var mode0 = ModalPercussionModeState()
    package var mode1 = ModalPercussionModeState()
    package var mode2 = ModalPercussionModeState()
    package var mode3 = ModalPercussionModeState()
    package var mode4 = ModalPercussionModeState()
    package var mode5 = ModalPercussionModeState()

    package init() {}
}

package struct ModalPercussionVoiceState: Equatable, Sendable {
    package var sampleRate = 0.0
    package var slot0 = ModalPercussionVoiceSlotState()
    package var slot1 = ModalPercussionVoiceSlotState()
    package var slot2 = ModalPercussionVoiceSlotState()
    package var slot3 = ModalPercussionVoiceSlotState()

    package init() {}
}

package struct ScheduledModalPercussionEvent: Equatable, Sendable {
    package let articulation: ModalPercussionArticulation
    package let startFrame: Int
    package let level: Double

    package init(
        articulation: ModalPercussionArticulation,
        startFrame: Int,
        level: Double
    ) {
        self.articulation = articulation
        self.startFrame = max(0, startFrame)
        self.level = min(1, max(0, level.isFinite ? level : 0))
    }
}

package struct ModalPercussionRenderEventEvidence: Equatable, Sendable {
    package let articulation: ModalPercussionArticulation
    package let requestedFundamentalHz: Double
    package let appliedFundamentalHz: Double
    package let modeCount: Int
    package let modeRatioFingerprint: String
    package let minimumModeFrequencyHz: Double
    package let maximumModeFrequencyHz: Double
    package let maximumPoleRadius: Double
    package let excitationFingerprint: String
    package let drySampleHash: String
    package let renderedFrameCount: Int
    package let nonzeroSampleCount: Int
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let attackRMS: Double
    package let bodyRMS: Double
    package let tailRMS: Double
    package let tailToBodyDB: Double
    package let spectralCentroidHz: Double
    package let incomingVoiceStateFingerprint: String
    package let outgoingVoiceStateFingerprint: String
    package let finite: Bool
    package let stable: Bool
    package let capacityValid: Bool
    package let routeBindingValid: Bool
}

package struct ModalPercussionBarRenderEvidence: Equatable, Sendable {
    package let bar: Int
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let incomingStateFingerprint: String
    package let outgoingStateFingerprint: String
    package let dryBarSampleHash: String
    package let dryBarPeak: Double
    package let dryBarRMS: Double
    package let activeIncomingVoiceCount: Int
    package let activeOutgoingVoiceCount: Int
    package let continuationRendered: Bool
    package let events: [ModalPercussionRenderEventEvidence]
    package let finite: Bool
}

package enum ModalPercussionVoice {
    package static let modeCount = 6
    package static let voiceCapacity = 4
    package static let maximumExcitationSeconds = 0.002

    private static let baseModeRatios = [1.0, 1.47, 2.09, 2.77, 3.62, 4.63]
    private static let excitationDomain: UInt64 = 0x4D4F44414C455843

    package static func renderBar(
        into dryOutput: inout [Float],
        bar: Int,
        sampleRate: Double,
        events: [ScheduledModalPercussionEvent],
        state: inout ModalPercussionVoiceState
    ) -> ModalPercussionBarRenderEvidence {
        let routeIsValid = sampleRate.isFinite && sampleRate > 0
        if !routeIsValid || state.sampleRate != sampleRate {
            state = ModalPercussionVoiceState()
            state.sampleRate = routeIsValid ? sampleRate : 0
        }
        let incomingStateFingerprint = stateFingerprint(state)
        let activeIncomingVoiceCount = activeVoiceCount(state)
        let frameCount = dryOutput.count
        var barFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frameCount
        )
        var barPeak = 0.0
        var barEnergy = 0.0
        var finite = routeIsValid

        let orderedEvents = events.sorted { lhs, rhs in
            if lhs.startFrame != rhs.startFrame {
                return lhs.startFrame < rhs.startFrame
            }
            if lhs.articulation.scoreEventIndex != rhs.articulation.scoreEventIndex {
                return lhs.articulation.scoreEventIndex < rhs.articulation.scoreEventIndex
            }
            return lhs.articulation.seed < rhs.articulation.seed
        }
        var runtimes = orderedEvents.map {
            EventRuntime(
                event: $0,
                sampleRate: sampleRate,
                frameCount: frameCount,
                incomingStateFingerprint: incomingStateFingerprint
            )
        }
        var eventCursor = 0
        var slotOwners = [Int?](repeating: nil, count: voiceCapacity)
        var slotExcitations = [[Double]?](repeating: nil, count: voiceCapacity)
        var eventSamples = [Double](repeating: 0, count: runtimes.count)
        if routeIsValid {
            for slotIndex in 0..<voiceCapacity {
                let slot = state.slot(at: slotIndex)
                if slot.active && slot.ageFrames < excitationFrameCount(sampleRate) {
                    slotExcitations[slotIndex] = excitationSamples(
                        seed: slot.articulationSeed,
                        sampleRate: sampleRate
                    )
                }
            }
        }

        for frame in 0..<frameCount {
            for index in eventSamples.indices {
                eventSamples[index] = 0
            }
            while eventCursor < runtimes.count,
                  runtimes[eventCursor].event.startFrame == frame {
                let incoming = stateFingerprint(state)
                runtimes[eventCursor].incomingStateFingerprint = incoming
                if routeIsValid, let slotIndex = firstInactiveSlot(state) {
                    let slot = configuredSlot(
                        for: runtimes[eventCursor].event,
                        configuration: runtimes[eventCursor].configuration,
                        sampleRate: sampleRate
                    )
                    state.setSlot(slot, at: slotIndex)
                    slotOwners[slotIndex] = eventCursor
                    slotExcitations[slotIndex] = excitationSamples(
                        seed: slot.articulationSeed,
                        sampleRate: sampleRate
                    )
                    runtimes[eventCursor].capacityValid = true
                }
                eventCursor += 1
            }

            var modalSample = 0.0
            if routeIsValid {
                for slotIndex in 0..<voiceCapacity {
                    var slot = state.slot(at: slotIndex)
                    guard slot.active else { continue }
                    let excitation: Double
                    if let samples = slotExcitations[slotIndex],
                       slot.ageFrames < samples.count {
                        excitation = samples[slot.ageFrames]
                    } else {
                        excitation = 0
                    }
                    let sample = renderSample(
                        excitation: excitation,
                        slot: &slot
                    )
                    modalSample += sample
                    if let owner = slotOwners[slotIndex] {
                        eventSamples[owner] += sample
                    }
                    slot.ageFrames += 1
                    slot.remainingFrames -= 1
                    if slot.remainingFrames <= 0 {
                        slot.active = false
                        slotOwners[slotIndex] = nil
                        slotExcitations[slotIndex] = nil
                    }
                    state.setSlot(slot, at: slotIndex)
                }
            }

            if !modalSample.isFinite {
                modalSample = 0
                finite = false
            }
            let floatSample = Float(modalSample)
            if floatSample.isFinite {
                dryOutput[frame] += floatSample
            } else {
                finite = false
            }
            barFingerprint.append(floatSample.isFinite ? floatSample : 0)
            barPeak = max(barPeak, abs(modalSample))
            barEnergy += modalSample * modalSample
            for index in runtimes.indices {
                runtimes[index].accumulator.append(
                    eventSamples[index],
                    frame: frame,
                    sampleRate: sampleRate
                )
            }
        }

        while eventCursor < runtimes.count {
            runtimes[eventCursor].incomingStateFingerprint = stateFingerprint(state)
            eventCursor += 1
        }
        let outgoingStateFingerprint = stateFingerprint(state)
        let eventEvidence = runtimes.map {
            $0.evidence(
                sampleRate: sampleRate,
                frameCount: frameCount,
                outgoingStateFingerprint: outgoingStateFingerprint
            )
        }.sorted {
            $0.articulation.scoreEventIndex < $1.articulation.scoreEventIndex
        }
        finite = finite && eventEvidence.allSatisfy { $0.finite }

        return ModalPercussionBarRenderEvidence(
            bar: bar,
            sampleRate: sampleRate,
            renderedFrameCount: frameCount,
            incomingStateFingerprint: incomingStateFingerprint,
            outgoingStateFingerprint: outgoingStateFingerprint,
            dryBarSampleHash: barFingerprint.fingerprint,
            dryBarPeak: barPeak,
            dryBarRMS: sqrt(barEnergy / Double(max(1, frameCount))),
            activeIncomingVoiceCount: activeIncomingVoiceCount,
            activeOutgoingVoiceCount: activeVoiceCount(state),
            continuationRendered: activeIncomingVoiceCount > 0,
            events: eventEvidence,
            finite: finite && dryOutput.allSatisfy { $0.isFinite }
        )
    }

    static func excitationSamples(
        articulation: ModalPercussionArticulation,
        sampleRate: Double
    ) -> [Double] {
        excitationSamples(seed: articulation.seed, sampleRate: sampleRate)
    }

    private static func excitationSamples(
        seed: UInt64,
        sampleRate: Double
    ) -> [Double] {
        let count = excitationFrameCount(sampleRate)
        guard count > 0 else { return [] }
        var raw = [Double](repeating: 0, count: count)
        var noise = [Double](repeating: 0, count: count)
        for index in 0..<count {
            let random = SceneDNA.derivedSeed(
                scene: seed,
                domain: excitationDomain,
                index: index
            )
            noise[index] = Double(random >> 11) /
                9_007_199_254_740_992 * 2 - 1
        }
        let noiseMean = noise.reduce(0, +) / Double(count)
        for index in 0..<count {
            let phase = count == 1 ? 0.5 : Double(index) / Double(count - 1)
            let impulse = pow(sin(Double.pi * phase), 2)
            raw[index] = impulse * 0.82 + (noise[index] - noiseMean) * 0.18
        }
        let mean = raw.reduce(0, +) / Double(count)
        for index in raw.indices {
            raw[index] -= mean
        }
        if count == 1 {
            raw[0] = 0
        } else {
            var prefix = 0.0
            for index in 0..<(count - 1) {
                prefix += raw[index]
            }
            raw[count - 1] = -prefix
        }
        return raw
    }

    private static func excitationFrameCount(_ sampleRate: Double) -> Int {
        guard sampleRate.isFinite, sampleRate > 0 else { return 0 }
        return max(1, Int((sampleRate * maximumExcitationSeconds).rounded(.up)))
    }

    private static func configuredSlot(
        for event: ScheduledModalPercussionEvent,
        configuration: ModeConfiguration,
        sampleRate: Double
    ) -> ModalPercussionVoiceSlotState {
        var slot = ModalPercussionVoiceSlotState()
        slot.active = true
        slot.articulationSeed = event.articulation.seed
        slot.remainingFrames = max(
            1,
            Int((configuration.t60Seconds * sampleRate).rounded(.up))
        )
        for index in 0..<modeCount {
            var mode = ModalPercussionModeState()
            mode.frequencyHz = configuration.frequencies[index]
            mode.poleRadius = configuration.poleRadius
            mode.coefficient = 2 * configuration.poleRadius * cos(
                2 * Double.pi * configuration.frequencies[index] / sampleRate
            )
            mode.weight = configuration.weights[index] *
                sqrt(max(0, 1 - configuration.poleRadius * configuration.poleRadius)) *
                event.level * event.articulation.eventIntensity *
                (0.25 + event.articulation.excitation * 0.75)
            slot.setMode(mode, at: index)
        }
        return slot
    }

    private static func renderSample(
        excitation: Double,
        slot: inout ModalPercussionVoiceSlotState
    ) -> Double {
        var output = 0.0
        for index in 0..<modeCount {
            var mode = slot.mode(at: index)
            let next = excitation * mode.weight + mode.coefficient * mode.y1 -
                mode.poleRadius * mode.poleRadius * mode.y2
            mode.y2 = mode.y1
            mode.y1 = next.isFinite ? next : 0
            output += mode.y1
            slot.setMode(mode, at: index)
        }
        return output
    }

    private static func firstInactiveSlot(
        _ state: ModalPercussionVoiceState
    ) -> Int? {
        for index in 0..<voiceCapacity where !state.slot(at: index).active {
            return index
        }
        return nil
    }

    private static func activeVoiceCount(_ state: ModalPercussionVoiceState) -> Int {
        (0..<voiceCapacity).reduce(0) {
            $0 + (state.slot(at: $1).active ? 1 : 0)
        }
    }

    private static func stateFingerprint(_ state: ModalPercussionVoiceState) -> String {
        var sink = StreamingFNV1a()
        sink.domain("modal-percussion-state.v1")
        sink.field("sampleRate"); sink.double(state.sampleRate)
        for slotIndex in 0..<voiceCapacity {
            let slot = state.slot(at: slotIndex)
            sink.field("slot"); sink.int(slotIndex)
            sink.field("active"); sink.bool(slot.active)
            sink.field("articulationSeed"); sink.uint64(slot.articulationSeed)
            sink.field("ageFrames"); sink.int(slot.ageFrames)
            sink.field("remainingFrames"); sink.int(slot.remainingFrames)
            for modeIndex in 0..<modeCount {
                let mode = slot.mode(at: modeIndex)
                sink.field("mode"); sink.int(modeIndex)
                sink.double(mode.frequencyHz)
                sink.double(mode.poleRadius)
                sink.double(mode.coefficient)
                sink.double(mode.weight)
                sink.double(mode.y1)
                sink.double(mode.y2)
            }
        }
        return fixedWidthFingerprintHex(sink.value)
    }

    private static func configuration(
        articulation: ModalPercussionArticulation,
        sampleRate: Double
    ) -> ModeConfiguration {
        let routeCeiling = (0.9 * sampleRate * 0.5).nextDown
        let fundamental = min(routeCeiling, max(1, articulation.fundamentalHz))
        var frequencies: [Double] = []
        var ratios: [Double] = []
        var rawWeights: [Double] = []
        for (index, baseRatio) in baseModeRatios.enumerated() {
            let ratio = baseRatio * (
                1 + articulation.inharmonicity * Double(index * index) / 25
            )
            ratios.append(ratio)
            frequencies.append(min(routeCeiling, fundamental * ratio))
            let brightnessBase = 0.18 + articulation.brightness * 0.72
            rawWeights.append(pow(brightnessBase, Double(index)) / sqrt(baseRatio))
        }
        let norm = sqrt(rawWeights.reduce(0) { $0 + $1 * $1 })
        let weights = rawWeights.map { $0 / max(1e-12, norm) }
        let t60Seconds = 0.18 + (0.65 - 0.18) * articulation.damping
        let poleRadius = pow(0.001, 1 / (t60Seconds * sampleRate))
        var ratioSink = StreamingFNV1a()
        ratioSink.domain("modal-percussion-mode-ratios.v1")
        for ratio in ratios { ratioSink.double(ratio) }
        let centroidDenominator = weights.reduce(0) { $0 + $1 * $1 }
        let centroid = zip(frequencies, weights).reduce(0) {
            $0 + $1.0 * $1.1 * $1.1
        } / max(1e-12, centroidDenominator)
        return ModeConfiguration(
            frequencies: frequencies,
            weights: weights,
            poleRadius: poleRadius,
            t60Seconds: t60Seconds,
            ratioFingerprint: fixedWidthFingerprintHex(ratioSink.value),
            centroidHz: centroid
        )
    }

    private struct ModeConfiguration {
        let frequencies: [Double]
        let weights: [Double]
        let poleRadius: Double
        let t60Seconds: Double
        let ratioFingerprint: String
        let centroidHz: Double
    }

    private struct EventRuntime {
        let event: ScheduledModalPercussionEvent
        let configuration: ModeConfiguration
        let excitationFingerprint: String
        var incomingStateFingerprint: String
        var capacityValid = false
        var accumulator: EventAccumulator

        init(
            event: ScheduledModalPercussionEvent,
            sampleRate: Double,
            frameCount: Int,
            incomingStateFingerprint: String
        ) {
            self.event = event
            configuration = ModalPercussionVoice.configuration(
                articulation: event.articulation,
                sampleRate: max(1, sampleRate.isFinite ? sampleRate : 1)
            )
            let excitation = ModalPercussionVoice.excitationSamples(
                seed: event.articulation.seed,
                sampleRate: sampleRate
            ).map(Float.init)
            excitationFingerprint = ExactPCMFingerprint.mono(excitation)
            self.incomingStateFingerprint = incomingStateFingerprint
            accumulator = EventAccumulator(
                frameCount: frameCount,
                startFrame: event.startFrame
            )
        }

        func evidence(
            sampleRate: Double,
            frameCount: Int,
            outgoingStateFingerprint: String
        ) -> ModalPercussionRenderEventEvidence {
            let metrics = accumulator.metrics
            let routeBindingValid = sampleRate.isFinite && sampleRate > 0 &&
                event.startFrame < frameCount &&
                configuration.frequencies.allSatisfy {
                    $0.isFinite && $0 > 0 && $0 < 0.9 * sampleRate * 0.5
                }
            let stable = configuration.poleRadius.isFinite &&
                configuration.poleRadius > 0 && configuration.poleRadius < 1
            return ModalPercussionRenderEventEvidence(
                articulation: event.articulation,
                requestedFundamentalHz: event.articulation.fundamentalHz,
                appliedFundamentalHz: configuration.frequencies.first ?? 0,
                modeCount: ModalPercussionVoice.modeCount,
                modeRatioFingerprint: configuration.ratioFingerprint,
                minimumModeFrequencyHz: configuration.frequencies.min() ?? 0,
                maximumModeFrequencyHz: configuration.frequencies.max() ?? 0,
                maximumPoleRadius: configuration.poleRadius,
                excitationFingerprint: excitationFingerprint,
                drySampleHash: metrics.sampleHash,
                renderedFrameCount: frameCount,
                nonzeroSampleCount: metrics.nonzeroSampleCount,
                peak: metrics.peak,
                rms: metrics.rms,
                crestFactor: metrics.rms > 0 ? metrics.peak / metrics.rms : 0,
                attackRMS: metrics.attackRMS,
                bodyRMS: metrics.bodyRMS,
                tailRMS: metrics.tailRMS,
                tailToBodyDB: metrics.tailToBodyDB,
                spectralCentroidHz: configuration.centroidHz,
                incomingVoiceStateFingerprint: incomingStateFingerprint,
                outgoingVoiceStateFingerprint: outgoingStateFingerprint,
                finite: metrics.finite && routeBindingValid && stable,
                stable: stable,
                capacityValid: capacityValid,
                routeBindingValid: routeBindingValid
            )
        }
    }

    private struct EventAccumulator {
        let startFrame: Int
        var fingerprint: ExactPCMFingerprint.MonoAccumulator
        var nonzeroSampleCount = 0
        var peak = 0.0
        var energy = 0.0
        var attackEnergy = 0.0
        var attackCount = 0
        var bodyEnergy = 0.0
        var bodyCount = 0
        var tailEnergy = 0.0
        var tailCount = 0
        var sampleCount = 0
        var finite = true

        init(frameCount: Int, startFrame: Int) {
            self.startFrame = startFrame
            fingerprint = ExactPCMFingerprint.MonoAccumulator(sampleCount: frameCount)
        }

        mutating func append(_ sample: Double, frame: Int, sampleRate: Double) {
            let finiteSample = sample.isFinite ? sample : 0
            finite = finite && sample.isFinite
            let floatSample = Float(finiteSample)
            fingerprint.append(floatSample)
            sampleCount += 1
            if floatSample != 0 { nonzeroSampleCount += 1 }
            peak = max(peak, abs(finiteSample))
            energy += finiteSample * finiteSample
            guard sampleRate > 0, frame >= startFrame else { return }
            let elapsed = Double(frame - startFrame) / sampleRate
            if elapsed < 0.010 {
                attackEnergy += finiteSample * finiteSample
                attackCount += 1
            } else if elapsed >= 0.020 && elapsed < 0.080 {
                bodyEnergy += finiteSample * finiteSample
                bodyCount += 1
            } else if elapsed >= 0.120 && elapsed < 0.240 {
                tailEnergy += finiteSample * finiteSample
                tailCount += 1
            }
        }

        var metrics: EventMetrics {
            let rms = sqrt(energy / Double(max(1, sampleCount)))
            let attack = sqrt(attackEnergy / Double(max(1, attackCount)))
            let body = sqrt(bodyEnergy / Double(max(1, bodyCount)))
            let tail = sqrt(tailEnergy / Double(max(1, tailCount)))
            let tailToBodyDB = body > 0
                ? max(-120, 20 * log10(max(1e-12, tail) / body))
                : -120
            return EventMetrics(
                sampleHash: fingerprint.fingerprint,
                nonzeroSampleCount: nonzeroSampleCount,
                peak: peak,
                rms: rms,
                attackRMS: attack,
                bodyRMS: body,
                tailRMS: tail,
                tailToBodyDB: tailToBodyDB,
                finite: finite && peak.isFinite && rms.isFinite &&
                    attack.isFinite && body.isFinite && tail.isFinite &&
                    tailToBodyDB.isFinite
            )
        }
    }

    private struct EventMetrics {
        let sampleHash: String
        let nonzeroSampleCount: Int
        let peak: Double
        let rms: Double
        let attackRMS: Double
        let bodyRMS: Double
        let tailRMS: Double
        let tailToBodyDB: Double
        let finite: Bool
    }
}

private extension ModalPercussionVoiceSlotState {
    func mode(at index: Int) -> ModalPercussionModeState {
        switch index {
        case 0: mode0
        case 1: mode1
        case 2: mode2
        case 3: mode3
        case 4: mode4
        default: mode5
        }
    }

    mutating func setMode(_ mode: ModalPercussionModeState, at index: Int) {
        switch index {
        case 0: mode0 = mode
        case 1: mode1 = mode
        case 2: mode2 = mode
        case 3: mode3 = mode
        case 4: mode4 = mode
        default: mode5 = mode
        }
    }
}

private extension ModalPercussionVoiceState {
    func slot(at index: Int) -> ModalPercussionVoiceSlotState {
        switch index {
        case 0: slot0
        case 1: slot1
        case 2: slot2
        default: slot3
        }
    }

    mutating func setSlot(_ slot: ModalPercussionVoiceSlotState, at index: Int) {
        switch index {
        case 0: slot0 = slot
        case 1: slot1 = slot
        case 2: slot2 = slot
        default: slot3 = slot
        }
    }
}
