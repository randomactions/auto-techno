import Foundation

package enum LongHorizonPolymetricGrammarSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier = "autotechno-long-horizon-polymetric-grammar.v1"
    package static let stepsPerBar = 16
    package static let minimumCombinedPeriodInBars = 64.0
    package static let maximumCombinedPeriodInBars = 128.0
}

package enum LongHorizonPolymetricLane: String, CaseIterable, Codable, Hashable, Sendable {
    case anchorShadow = "anchor-shadow"
    case responseAtmosphereTransition = "response-atmosphere-transition"
    case nonFoundationPercussion = "non-foundation-percussion"
}

package struct LongHorizonPolymetricLaneGeometry: Codable, Equatable, Sendable {
    package let lane: LongHorizonPolymetricLane
    package let stepLength: Int
    package let pulseCount: Int
    package let rotation: Int

    package var isValid: Bool {
        stepLength >= 2 && pulseCount > 0 && pulseCount < stepLength &&
            rotation >= 0 && rotation < stepLength &&
            Self.greatestCommonDivisor(stepLength, pulseCount) == 1
    }

    package init(
        lane: LongHorizonPolymetricLane,
        stepLength: Int,
        pulseCount: Int,
        rotation: Int
    ) {
        self.lane = lane
        self.stepLength = stepLength
        self.pulseCount = pulseCount
        self.rotation = rotation
    }

    package func contains(globalStep: Int) -> Bool {
        guard isValid else { return false }
        let phase = Self.positiveModulo(globalStep + rotation, stepLength)
        // The bucket form is the exact finite Euclidean distribution: pulses
        // are spread as evenly as possible without a mutable sequencer.
        return Self.positiveModulo(phase * pulseCount, stepLength) < pulseCount
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = abs(lhs)
        var b = abs(rhs)
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return a
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

/// One held three-lane grammar attached to a material-world lineage. Its phase
/// is anchored to the episode activation bar, so retries and transport events
/// can only replay the same geometry.
package struct LongHorizonPolymetricGrammar: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let isEnabled: Bool
    package let activationBar: Int
    package let laneGeometries: [LongHorizonPolymetricLaneGeometry]
    package let combinedPeriodInSteps: Int
    package let fingerprint: String

    package static let neutral = LongHorizonPolymetricGrammar(
        isEnabled: false,
        activationBar: 0,
        laneGeometries: [],
        combinedPeriodInSteps: 0,
        fingerprint: "neutral"
    )

    package var combinedPeriodInBars: Double {
        Double(combinedPeriodInSteps) /
            Double(LongHorizonPolymetricGrammarSchema.stepsPerBar)
    }

    package var isValid: Bool {
        guard schemaVersion == LongHorizonPolymetricGrammarSchema.schemaVersion,
              schemaIdentifier == LongHorizonPolymetricGrammarSchema.schemaIdentifier,
              activationBar >= 0,
              !fingerprint.isEmpty else {
            return false
        }
        guard isEnabled else {
            return laneGeometries.isEmpty && combinedPeriodInSteps == 0 &&
                fingerprint == "neutral"
        }
        guard laneGeometries.count == LongHorizonPolymetricLane.allCases.count,
              Set(laneGeometries.map(\.lane)).count == laneGeometries.count,
              laneGeometries.allSatisfy(\.isValid) else {
            return false
        }
        return combinedPeriodInBars >=
                LongHorizonPolymetricGrammarSchema.minimumCombinedPeriodInBars &&
            combinedPeriodInBars <=
                LongHorizonPolymetricGrammarSchema.maximumCombinedPeriodInBars
    }

    package init(
        isEnabled: Bool,
        activationBar: Int,
        laneGeometries: [LongHorizonPolymetricLaneGeometry],
        combinedPeriodInSteps: Int,
        fingerprint: String
    ) {
        schemaVersion = LongHorizonPolymetricGrammarSchema.schemaVersion
        schemaIdentifier = LongHorizonPolymetricGrammarSchema.schemaIdentifier
        self.isEnabled = isEnabled
        self.activationBar = max(0, activationBar)
        self.laneGeometries = laneGeometries.sorted {
            Self.laneOrder($0.lane) < Self.laneOrder($1.lane)
        }
        self.combinedPeriodInSteps = max(0, combinedPeriodInSteps)
        self.fingerprint = fingerprint
    }

    package func geometry(
        for lane: LongHorizonPolymetricLane
    ) -> LongHorizonPolymetricLaneGeometry? {
        laneGeometries.first { $0.lane == lane }
    }

    package func phase(
        for lane: LongHorizonPolymetricLane,
        absoluteBar: Int
    ) -> Int {
        guard let geometry = geometry(for: lane), geometry.isValid else { return 0 }
        let relativeSteps = (absoluteBar - activationBar) *
            LongHorizonPolymetricGrammarSchema.stepsPerBar
        let remainder = relativeSteps % geometry.stepLength
        return remainder >= 0 ? remainder : remainder + geometry.stepLength
    }

    package func contains(
        lane: LongHorizonPolymetricLane,
        absoluteBar: Int,
        step: Int
    ) -> Bool {
        guard isEnabled, isValid, let geometry = geometry(for: lane) else {
            return false
        }
        let relativeBar = absoluteBar - activationBar
        let globalStep = relativeBar *
            LongHorizonPolymetricGrammarSchema.stepsPerBar + step
        return geometry.contains(globalStep: globalStep)
    }

    private static func laneOrder(_ lane: LongHorizonPolymetricLane) -> Int {
        LongHorizonPolymetricLane.allCases.firstIndex(of: lane) ?? Int.max
    }
}

package struct LongHorizonPolymetricBarEvidence: Codable, Equatable, Sendable {
    package let absoluteBar: Int
    package let lane: LongHorizonPolymetricLane
    package let lanePhase: Int
    package let sourceMask: UInt16
    package let appliedMask: UInt16
    package let eventCount: Int
    package let relocatedEventCount: Int
    package let collisionFallbackCount: Int
    package let combinedPeriodInSteps: Int
    package let protectedEventFingerprintBefore: UInt64
    package let protectedEventFingerprintAfter: UInt64

    package init(
        absoluteBar: Int,
        lane: LongHorizonPolymetricLane,
        lanePhase: Int,
        sourceMask: UInt16,
        appliedMask: UInt16,
        eventCount: Int,
        relocatedEventCount: Int,
        collisionFallbackCount: Int,
        combinedPeriodInSteps: Int,
        protectedEventFingerprintBefore: UInt64,
        protectedEventFingerprintAfter: UInt64
    ) {
        self.absoluteBar = absoluteBar
        self.lane = lane
        self.lanePhase = lanePhase
        self.sourceMask = sourceMask
        self.appliedMask = appliedMask
        self.eventCount = eventCount
        self.relocatedEventCount = relocatedEventCount
        self.collisionFallbackCount = collisionFallbackCount
        self.combinedPeriodInSteps = combinedPeriodInSteps
        self.protectedEventFingerprintBefore = protectedEventFingerprintBefore
        self.protectedEventFingerprintAfter = protectedEventFingerprintAfter
    }

    package var protectedEventsEqual: Bool {
        protectedEventFingerprintBefore == protectedEventFingerprintAfter
    }
}

package enum LongHorizonPolymetricGrammarResolver {
    // Pairwise-coprime-enough tuples whose least common multiple spans the
    // requested listener-scale 64...128-bar recurrence window.
    private static let stepLengthTuples = [
        [9, 11, 13],   // 80.4375 bars
        [10, 11, 13],  // 89.375 bars
        [11, 12, 13],  // 107.25 bars
        [11, 13, 14],  // 125.125 bars
        [12, 13, 14],  // 68.25 bars
    ]

    package static func make(
        worldSeed: UInt64,
        activationBar: Int
    ) -> LongHorizonPolymetricGrammar {
        let tuple = stepLengthTuples[Int(worldSeed % UInt64(stepLengthTuples.count))]
        let geometries = zip(LongHorizonPolymetricLane.allCases, tuple).enumerated().map {
            laneIndex, pair in
            let (lane, length) = pair
            let seed = SceneDNA.derivedSeed(
                scene: worldSeed ^ 0x504F_4C59_4D45_5445,
                domain: UInt64(laneIndex + 1),
                index: max(0, activationBar)
            )
            let candidates = (2..<length).filter { pulse in
                Double(pulse) / Double(length) >= 0.24 &&
                    Double(pulse) / Double(length) <= 0.58 &&
                    greatestCommonDivisor(length, pulse) == 1
            }
            let pulseCount = candidates[Int(seed % UInt64(candidates.count))]
            let rotation = Int((seed >> 16) % UInt64(length))
            return LongHorizonPolymetricLaneGeometry(
                lane: lane,
                stepLength: length,
                pulseCount: pulseCount,
                rotation: rotation
            )
        }
        let combinedPeriod = geometries.map(\.stepLength).reduce(1, leastCommonMultiple)
        var hasher = LongHorizonPolymetricHasher()
        hasher.combine(max(0, activationBar))
        for geometry in geometries {
            hasher.combine(geometry.lane.rawValue)
            hasher.combine(geometry.stepLength)
            hasher.combine(geometry.pulseCount)
            hasher.combine(geometry.rotation)
        }
        hasher.combine(combinedPeriod)
        return LongHorizonPolymetricGrammar(
            isEnabled: true,
            activationBar: activationBar,
            laneGeometries: geometries,
            combinedPeriodInSteps: combinedPeriod,
            fingerprint: hasher.fingerprint
        )
    }

    package static func relocatePercussion(
        ensemble: EnsembleContext,
        grammar: LongHorizonPolymetricGrammar,
        absoluteBar: Int
    ) -> (ensemble: EnsembleContext, evidence: LongHorizonPolymetricBarEvidence) {
        let lane = LongHorizonPolymetricLane.nonFoundationPercussion
        let sourceMask = mask(ensemble.events.filter(isEligiblePercussion).map(\.step))
        let before = protectedFingerprint(ensemble.events)
        guard grammar.isEnabled, grammar.isValid else {
            return (
                ensemble,
                evidence(
                    absoluteBar: absoluteBar,
                    lane: lane,
                    grammar: grammar,
                    sourceMask: sourceMask,
                    appliedMask: sourceMask,
                    eventCount: ensemble.events.filter(isEligiblePercussion).count,
                    relocatedCount: 0,
                    fallbackCount: 0,
                    protectedBefore: before,
                    protectedAfter: before
                )
            )
        }

        // Reserve every source onset until its event is processed. This keeps
        // an earlier relocation from consuming a later event's only legal
        // fallback position when the bar is densely occupied.
        var occupancy: [Int: Int] = [:]
        for event in ensemble.events {
            occupancy[event.step, default: 0] += 1
        }
        var relocatedCount = 0
        var fallbackCount = 0
        let events = ensemble.events.map { event -> EnsembleResolvedEvent in
            guard isEligiblePercussion(event) else { return event }
            decrement(&occupancy, step: event.step)
            guard let target = nextLegalStep(
                from: event.step,
                lane: lane,
                absoluteBar: absoluteBar,
                grammar: grammar,
                occupied: Set(occupancy.keys)
            ) else {
                fallbackCount += 1
                occupancy[event.step, default: 0] += 1
                return event
            }
            occupancy[target, default: 0] += 1
            if target != event.step { relocatedCount += 1 }
            return EnsembleResolvedEvent(
                voice: event.voice,
                step: target,
                intensity: event.intensity,
                relocated: event.relocated || target != event.step
            )
        }
        let resolved = EnsembleContext(
            focusRole: ensemble.focusRole,
            events: events,
            kickAnchors: ensemble.kickAnchors,
            intentionalPileup: ensemble.intentionalPileup
        )
        let after = protectedFingerprint(resolved.events)
        return (
            resolved,
            evidence(
                absoluteBar: absoluteBar,
                lane: lane,
                grammar: grammar,
                sourceMask: sourceMask,
                appliedMask: mask(events.filter(isEligiblePercussion).map(\.step)),
                eventCount: events.filter(isEligiblePercussion).count,
                relocatedCount: relocatedCount,
                fallbackCount: fallbackCount,
                protectedBefore: before,
                protectedAfter: after
            )
        )
    }

    package static func relocateUpperNotes(
        _ notes: [ResolvedUpperNote],
        grammar: LongHorizonPolymetricGrammar,
        absoluteBar: Int
    ) -> (notes: [ResolvedUpperNote], evidence: [LongHorizonPolymetricBarEvidence]) {
        let lanes: [LongHorizonPolymetricLane] = [
            .anchorShadow, .responseAtmosphereTransition,
        ]
        guard grammar.isEnabled, grammar.isValid else {
            return (
                notes,
                lanes.map { lane in
                    let laneNotes = notes.filter { upperLane(for: $0.role) == lane }
                    let source = mask(laneNotes.map(\.onsetStep))
                    return evidence(
                        absoluteBar: absoluteBar,
                        lane: lane,
                        grammar: grammar,
                        sourceMask: source,
                        appliedMask: source,
                        eventCount: laneNotes.count,
                        relocatedCount: 0,
                        fallbackCount: 0,
                        protectedBefore: 0,
                        protectedAfter: 0
                    )
                }
            )
        }

        var result = notes
        var occupancy: [Int: Int] = [:]
        for note in notes { occupancy[note.onsetStep, default: 0] += 1 }
        var relocated: [LongHorizonPolymetricLane: Int] = [:]
        var fallbacks: [LongHorizonPolymetricLane: Int] = [:]
        var processed = Set<Int>()
        let orderedIndices = notes.indices.sorted {
            if notes[$0].onsetStep != notes[$1].onsetStep {
                return notes[$0].onsetStep < notes[$1].onsetStep
            }
            return $0 < $1
        }

        for index in orderedIndices where !processed.contains(index) {
            let role = notes[index].role
            let lane = upperLane(for: role)
            var group = [index]
            let roleIndices = orderedIndices.filter { notes[$0].role == role }
            var cursor = roleIndices.firstIndex(of: index) ?? 0
            while cursor + 1 < roleIndices.count {
                let candidate = roleIndices[cursor + 1]
                guard notes[candidate].gate == .slide else { break }
                group.append(candidate)
                cursor += 1
            }
            processed.formUnion(group)
            for member in group {
                decrement(&occupancy, step: notes[member].onsetStep)
            }
            let sourceSteps = group.map { notes[$0].onsetStep }
            let root = sourceSteps.min() ?? notes[index].onsetStep
            let maximum = sourceSteps.max() ?? notes[index].onsetStep
            var selectedOffset: Int?
            if maximum <= 15 {
                for offset in 0...(15 - maximum) {
                    let targets = sourceSteps.map { $0 + offset }
                    guard grammar.contains(
                        lane: lane,
                        absoluteBar: absoluteBar,
                        step: root + offset
                    ), targets.allSatisfy({ occupancy[$0, default: 0] == 0 }) else {
                        continue
                    }
                    selectedOffset = offset
                    break
                }
            }
            guard let offset = selectedOffset else {
                fallbacks[lane, default: 0] += group.count
                for member in group {
                    occupancy[notes[member].onsetStep, default: 0] += 1
                }
                continue
            }
            for member in group {
                let target = notes[member].onsetStep + offset
                if target != notes[member].onsetStep {
                    relocated[lane, default: 0] += 1
                    result[member] = notes[member].withOnsetStep(target)
                }
                occupancy[target, default: 0] += 1
            }
        }

        return (
            result,
            lanes.map { lane in
                let source = notes.filter { upperLane(for: $0.role) == lane }
                let applied = result.filter { upperLane(for: $0.role) == lane }
                return evidence(
                    absoluteBar: absoluteBar,
                    lane: lane,
                    grammar: grammar,
                    sourceMask: mask(source.map(\.onsetStep)),
                    appliedMask: mask(applied.map(\.onsetStep)),
                    eventCount: applied.count,
                    relocatedCount: relocated[lane, default: 0],
                    fallbackCount: fallbacks[lane, default: 0],
                    protectedBefore: 0,
                    protectedAfter: 0
                )
            }
        )
    }

    private static func nextLegalStep(
        from source: Int,
        lane: LongHorizonPolymetricLane,
        absoluteBar: Int,
        grammar: LongHorizonPolymetricGrammar,
        occupied: Set<Int>
    ) -> Int? {
        guard source <= 15 else { return nil }
        for candidate in source...15 where
            !occupied.contains(candidate) &&
            grammar.contains(lane: lane, absoluteBar: absoluteBar, step: candidate) {
            return candidate
        }
        return nil
    }

    private static func isEligiblePercussion(_ event: EnsembleResolvedEvent) -> Bool {
        switch event.voice {
        case .percussion, .clap, .openHat, .metallic, .groovePulse: true
        case .kick, .bass, .rumble, .tunedTom, .motif, .response,
                .atmosphere, .transition: false
        }
    }

    private static func upperLane(for role: SynthRole) -> LongHorizonPolymetricLane {
        switch role {
        case .anchor, .shadow: .anchorShadow
        case .response, .atmosphere, .transition: .responseAtmosphereTransition
        }
    }

    private static func evidence(
        absoluteBar: Int,
        lane: LongHorizonPolymetricLane,
        grammar: LongHorizonPolymetricGrammar,
        sourceMask: UInt16,
        appliedMask: UInt16,
        eventCount: Int,
        relocatedCount: Int,
        fallbackCount: Int,
        protectedBefore: UInt64,
        protectedAfter: UInt64
    ) -> LongHorizonPolymetricBarEvidence {
        LongHorizonPolymetricBarEvidence(
            absoluteBar: absoluteBar,
            lane: lane,
            lanePhase: grammar.phase(for: lane, absoluteBar: absoluteBar),
            sourceMask: sourceMask,
            appliedMask: appliedMask,
            eventCount: eventCount,
            relocatedEventCount: relocatedCount,
            collisionFallbackCount: fallbackCount,
            combinedPeriodInSteps: grammar.combinedPeriodInSteps,
            protectedEventFingerprintBefore: protectedBefore,
            protectedEventFingerprintAfter: protectedAfter
        )
    }

    private static func mask(_ steps: [Int]) -> UInt16 {
        steps.reduce(into: UInt16(0)) { value, step in
            value |= UInt16(1) << UInt16(min(15, max(0, step)))
        }
    }

    private static func protectedFingerprint(
        _ events: [EnsembleResolvedEvent]
    ) -> UInt64 {
        var hasher = LongHorizonPolymetricHasher()
        for (index, event) in events.enumerated() where !isEligiblePercussion(event) {
            hasher.combine(index)
            hasher.combine(event.voice.rawValue)
            hasher.combine(event.step)
            hasher.combine(event.intensity.bitPattern)
            hasher.combine(event.relocated ? 1 : 0)
        }
        return hasher.value
    }

    private static func decrement(_ occupancy: inout [Int: Int], step: Int) {
        let next = occupancy[step, default: 0] - 1
        if next <= 0 { occupancy.removeValue(forKey: step) }
        else { occupancy[step] = next }
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = abs(lhs)
        var b = abs(rhs)
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return a
    }

    private static func leastCommonMultiple(_ lhs: Int, _ rhs: Int) -> Int {
        lhs / greatestCommonDivisor(lhs, rhs) * rhs
    }
}

private struct LongHorizonPolymetricHasher {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325

    var fingerprint: String {
        let raw = String(value, radix: 16)
        return String(repeating: "0", count: max(0, 16 - raw.count)) + raw
    }

    mutating func combine(_ string: String) {
        for byte in string.utf8 { combine(byte) }
        combine(0xff)
    }

    mutating func combine(_ integer: Int) {
        combine(UInt64(bitPattern: Int64(integer)))
    }

    mutating func combine(_ integer: UInt64) {
        var littleEndian = integer.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            for byte in bytes { combine(byte) }
        }
    }

    private mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value = value &* 0x0000_0100_0000_01b3
    }
}
