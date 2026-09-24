import Foundation

enum DeterministicSignalFixtureError: Error, Equatable {
    case invalidFrameCount
    case invalidSampleRate
    case invalidFrequency
    case invalidAmplitude
    case invalidPhase
    case invalidSweep
    case invalidImpulseIndex
    case invalidClipLevel
    case invalidEnvelope
    case invalidMusicalGeometry
    case invalidEventPattern
    case invalidTransition
}

enum MusicalFixtureRole: String, CaseIterable, Hashable {
    case kick
    case bass
    case hat
}

struct MusicalFixtureTrack: Equatable {
    let samples: [Float]
    let eventOnsets: [Int]
}

struct RoleSeparatedLoop: Equatable {
    let sampleRate: Double
    let tempoBPM: Double
    let bars: Int
    let framesPerBar: Int
    let tracks: [MusicalFixtureRole: MusicalFixtureTrack]

    var frameCount: Int { framesPerBar * bars }
}

struct MusicalPhraseChange: Equatable {
    let before: RoleSeparatedLoop
    let after: RoleSeparatedLoop
    let changedRole: MusicalFixtureRole
}

struct MusicalTransition: Equatable {
    let base: RoleSeparatedLoop
    let transitioned: RoleSeparatedLoop
    let boundaryFrame: Int
    let incomingRole: MusicalFixtureRole
}

/// Shared, test-only PCM constructors with explicit sample-index semantics.
enum DeterministicSignalFixtures {
    static let maximumFrameCount = 2_000_000
    static let minimumSampleRate = 8_000.0
    static let maximumSampleRate = 192_000.0

    /// One deterministic pitched kick body. The event begins at `onsetFrame`,
    /// sweeps down over `decayFrames`, and terminates at exact zero.
    static func kickHit(
        frameCount: Int,
        sampleRate: Double,
        onsetFrame: Int,
        startFrequencyHz: Double = 110,
        endFrequencyHz: Double = 42,
        amplitude: Double = 0.8,
        decayFrames: Int
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        try validateSampleRate(sampleRate)
        guard onsetFrame >= 0, onsetFrame < frameCount,
              decayFrames >= 3, decayFrames <= frameCount - onsetFrame,
              startFrequencyHz.isFinite, endFrequencyHz.isFinite,
              startFrequencyHz > endFrequencyHz, endFrequencyHz > 0,
              startFrequencyHz < sampleRate / 2 else {
            throw DeterministicSignalFixtureError.invalidMusicalGeometry
        }
        try validateAmplitude(amplitude)
        let body = try linearSweep(
            frameCount: decayFrames,
            sampleRate: sampleRate,
            startFrequencyHz: startFrequencyHz,
            endFrequencyHz: endFrequencyHz,
            amplitude: amplitude,
            phaseRadians: .pi / 2
        )
        var result = [Float](repeating: 0, count: frameCount)
        for frame in 0..<(decayFrames - 1) {
            let progress = Double(frame) / Double(decayFrames - 1)
            result[onsetFrame + frame] = Float(
                Double(body[frame]) * exp(-5 * progress)
            )
        }
        return result
    }

    /// A single pitched bass event with a short linear attack and release.
    static func bassNote(
        frameCount: Int,
        sampleRate: Double,
        onsetFrame: Int,
        durationFrames: Int,
        frequencyHz: Double = 55,
        amplitude: Double = 0.45
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        try validateSampleRate(sampleRate)
        guard onsetFrame >= 0, onsetFrame < frameCount,
              durationFrames >= 8, durationFrames <= frameCount - onsetFrame,
              frequencyHz.isFinite, frequencyHz > 0,
              frequencyHz < sampleRate / 2 else {
            throw DeterministicSignalFixtureError.invalidMusicalGeometry
        }
        try validateAmplitude(amplitude)
        let attackFrames = max(2, durationFrames / 12)
        let releaseFrames = max(2, durationFrames / 8)
        guard attackFrames + releaseFrames <= durationFrames else {
            throw DeterministicSignalFixtureError.invalidMusicalGeometry
        }
        let envelope = try linearEnvelope(
            frameCount: durationFrames,
            attackFrames: attackFrames,
            releaseFrames: releaseFrames,
            amplitude: amplitude
        )
        var result = [Float](repeating: 0, count: frameCount)
        for frame in 0..<durationFrames {
            let phase = 2 * Double.pi * frequencyHz * Double(frame) / sampleRate + .pi / 2
            result[onsetFrame + frame] = Float(sin(phase)) * envelope[frame]
        }
        return result
    }

    /// Seeded, high-passed noise with a fixed exponential hat decay.
    static func hatBurst(
        frameCount: Int,
        sampleRate: Double,
        onsetFrame: Int,
        decayFrames: Int,
        amplitude: Double = 0.25,
        seed: UInt64
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        try validateSampleRate(sampleRate)
        guard onsetFrame >= 0, onsetFrame < frameCount,
              decayFrames >= 3, decayFrames <= frameCount - onsetFrame else {
            throw DeterministicSignalFixtureError.invalidMusicalGeometry
        }
        try validateAmplitude(amplitude)
        let noise = try uniformNoise(frameCount: decayFrames, amplitude: 1, seed: seed)
        var highPassed = [Float](repeating: 0, count: decayFrames)
        var previousInput = 0.0
        var previousOutput = 0.0
        let coefficient = 0.94
        for frame in 0..<decayFrames {
            let input = Double(noise[frame])
            let output = coefficient * (previousOutput + input - previousInput)
            highPassed[frame] = Float(output)
            previousInput = input
            previousOutput = output
        }
        let peak = highPassed.map { abs(Double($0)) }.max() ?? 0
        guard peak > 0 else { throw DeterministicSignalFixtureError.invalidAmplitude }
        var result = [Float](repeating: 0, count: frameCount)
        for frame in 0..<(decayFrames - 1) {
            let progress = Double(frame) / Double(decayFrames - 1)
            let decay = exp(-6 * progress)
            result[onsetFrame + frame] = Float(
                Double(highPassed[frame]) / peak * amplitude * decay
            )
        }
        return result
    }

    /// Fixed sixteenth-note grid with independently rendered role buffers.
    static func roleSeparatedLoop(
        bars: Int,
        sampleRate: Double,
        tempoBPM: Double,
        kickSteps: [Int],
        bassSteps: [Int],
        hatSteps: [Int],
        bassFrequencyHz: Double = 55,
        seed: UInt64 = 0xA770
    ) throws -> RoleSeparatedLoop {
        guard (1...16).contains(bars), sampleRate.isFinite,
              sampleRate >= minimumSampleRate, sampleRate <= maximumSampleRate,
              tempoBPM.isFinite, (40...240).contains(tempoBPM),
              bassFrequencyHz.isFinite, bassFrequencyHz > 0,
              bassFrequencyHz < sampleRate / 2 else {
            throw DeterministicSignalFixtureError.invalidMusicalGeometry
        }
        let framesPerBar = Int((sampleRate * 240 / tempoBPM).rounded())
        let frameCount = framesPerBar.multipliedReportingOverflow(by: bars)
        guard !frameCount.overflow, frameCount.partialValue <= maximumFrameCount else {
            throw DeterministicSignalFixtureError.invalidMusicalGeometry
        }
        let totalSteps = bars * 16
        for steps in [kickSteps, bassSteps, hatSteps] {
            guard steps == steps.sorted(), Set(steps).count == steps.count,
                  steps.allSatisfy({ (0..<totalSteps).contains($0) }) else {
                throw DeterministicSignalFixtureError.invalidEventPattern
            }
        }
        let kickDecay = max(3, Int((sampleRate * 0.18).rounded()))
        let bassDuration = max(8, framesPerBar / 4)
        let hatDecay = max(3, Int((sampleRate * 0.045).rounded()))
        guard kickSteps.allSatisfy({ onset($0, framesPerBar: framesPerBar) + kickDecay <= frameCount.partialValue }),
              bassSteps.allSatisfy({ onset($0, framesPerBar: framesPerBar) + bassDuration <= frameCount.partialValue }),
              hatSteps.allSatisfy({ onset($0, framesPerBar: framesPerBar) + hatDecay <= frameCount.partialValue }) else {
            throw DeterministicSignalFixtureError.invalidEventPattern
        }
        let kick = try renderTrack(frameCount: frameCount.partialValue, steps: kickSteps, framesPerBar: framesPerBar, eventDurationFrames: kickDecay) { duration, _ in
            try kickHit(frameCount: duration, sampleRate: sampleRate, onsetFrame: 0, decayFrames: duration)
        }
        let bass = try renderTrack(frameCount: frameCount.partialValue, steps: bassSteps, framesPerBar: framesPerBar, eventDurationFrames: bassDuration) { duration, _ in
            try bassNote(frameCount: duration, sampleRate: sampleRate, onsetFrame: 0, durationFrames: duration, frequencyHz: bassFrequencyHz)
        }
        let hats = try renderTrack(frameCount: frameCount.partialValue, steps: hatSteps, framesPerBar: framesPerBar, eventDurationFrames: hatDecay, seed: seed) { duration, eventSeed in
            try hatBurst(frameCount: duration, sampleRate: sampleRate, onsetFrame: 0, decayFrames: duration, seed: eventSeed)
        }
        return RoleSeparatedLoop(
            sampleRate: sampleRate,
            tempoBPM: tempoBPM,
            bars: bars,
            framesPerBar: framesPerBar,
            tracks: [
                .kick: MusicalFixtureTrack(samples: kick.samples, eventOnsets: kick.onsets),
                .bass: MusicalFixtureTrack(samples: bass.samples, eventOnsets: bass.onsets),
                .hat: MusicalFixtureTrack(samples: hats.samples, eventOnsets: hats.onsets)
            ]
        )
    }

    /// A paired phrase with only the bass note frequency changed.
    static func bassPhraseChange(
        bars: Int,
        sampleRate: Double,
        tempoBPM: Double,
        kickSteps: [Int],
        bassSteps: [Int],
        hatSteps: [Int],
        fromFrequencyHz: Double,
        toFrequencyHz: Double,
        seed: UInt64 = 0xA770
    ) throws -> MusicalPhraseChange {
        guard fromFrequencyHz != toFrequencyHz else {
            throw DeterministicSignalFixtureError.invalidMusicalGeometry
        }
        let before = try roleSeparatedLoop(bars: bars, sampleRate: sampleRate, tempoBPM: tempoBPM, kickSteps: kickSteps, bassSteps: bassSteps, hatSteps: hatSteps, bassFrequencyHz: fromFrequencyHz, seed: seed)
        let after = try roleSeparatedLoop(bars: bars, sampleRate: sampleRate, tempoBPM: tempoBPM, kickSteps: kickSteps, bassSteps: bassSteps, hatSteps: hatSteps, bassFrequencyHz: toFrequencyHz, seed: seed)
        return MusicalPhraseChange(before: before, after: after, changedRole: .bass)
    }

    /// A role-entry transition preserves the loop and fades one absent role in.
    static func roleEntryTransition(
        from base: RoleSeparatedLoop,
        incomingRole: MusicalFixtureRole,
        eventSteps: [Int],
        fadeFrames: Int,
        seed: UInt64 = 0xA770
    ) throws -> MusicalTransition {
        guard fadeFrames >= 2, fadeFrames <= base.framesPerBar,
              incomingRole == .hat,
              eventSteps == eventSteps.sorted(), Set(eventSteps).count == eventSteps.count,
              eventSteps.allSatisfy({ (0..<(base.bars * 16)).contains($0) }) else {
            throw DeterministicSignalFixtureError.invalidTransition
        }
        let boundaryFrame = base.frameCount - base.framesPerBar
        let stepFrames = Double(base.framesPerBar) / 16
        let onsets = eventSteps.map { Int((Double($0) * stepFrames).rounded()) }
        guard onsets.allSatisfy({ $0 >= boundaryFrame && $0 < base.frameCount }) else {
            throw DeterministicSignalFixtureError.invalidTransition
        }
        var transitionedTracks = base.tracks
        let original = base.tracks[incomingRole]?.samples ?? [Float](repeating: 0, count: base.frameCount)
        guard original.allSatisfy({ $0 == 0 }) else {
            throw DeterministicSignalFixtureError.invalidTransition
        }
        var samples = original
        for (eventIndex, eventOnset) in onsets.enumerated() {
            let burst = try hatBurst(frameCount: base.frameCount, sampleRate: base.sampleRate, onsetFrame: eventOnset, decayFrames: min(base.frameCount - eventOnset, max(3, Int(base.sampleRate * 0.045))), seed: seed &+ UInt64(eventIndex))
            let end = min(base.frameCount, eventOnset + fadeFrames)
            for frame in eventOnset..<end {
                let gain = Float(min(fadeFrames - 1, max(0, frame - boundaryFrame))) / Float(fadeFrames - 1)
                samples[frame] += burst[frame] * gain
            }
        }
        transitionedTracks[incomingRole] = MusicalFixtureTrack(samples: samples, eventOnsets: onsets)
        let transitioned = RoleSeparatedLoop(sampleRate: base.sampleRate, tempoBPM: base.tempoBPM, bars: base.bars, framesPerBar: base.framesPerBar, tracks: transitionedTracks)
        return MusicalTransition(base: base, transitioned: transitioned, boundaryFrame: boundaryFrame, incomingRole: incomingRole)
    }

    private struct RenderedTrack {
        let samples: [Float]
        let onsets: [Int]
    }

    private static func onset(_ step: Int, framesPerBar: Int) -> Int {
        Int((Double(step) * Double(framesPerBar) / 16).rounded())
    }

    private static func renderTrack(
        frameCount: Int,
        steps: [Int],
        framesPerBar: Int,
        eventDurationFrames: Int,
        seed: UInt64 = 0,
        makeEvent: (Int, UInt64) throws -> [Float]
    ) throws -> RenderedTrack {
        let onsets = steps.map { onset($0, framesPerBar: framesPerBar) }
        guard zip(onsets, onsets.dropFirst()).allSatisfy({
            $0.1 - $0.0 >= eventDurationFrames
        }) else {
            throw DeterministicSignalFixtureError.invalidEventPattern
        }
        var samples = [Float](repeating: 0, count: frameCount)
        for (eventIndex, eventOnset) in onsets.enumerated() {
            let event = try makeEvent(eventDurationFrames, seed &+ UInt64(eventIndex))
            guard event.count == eventDurationFrames else {
                throw DeterministicSignalFixtureError.invalidMusicalGeometry
            }
            for offset in event.indices {
                samples[eventOnset + offset] += event[offset]
            }
        }
        return RenderedTrack(samples: samples, onsets: onsets)
    }

    static func silence(frameCount: Int) throws -> [Float] {
        try validateFrameCount(frameCount)
        return [Float](repeating: 0, count: frameCount)
    }

    static func dc(frameCount: Int, value: Float) throws -> [Float] {
        try validateFrameCount(frameCount)
        guard value.isFinite, abs(value) <= 1 else {
            throw DeterministicSignalFixtureError.invalidAmplitude
        }
        return [Float](repeating: value, count: frameCount)
    }

    static func sine(
        frameCount: Int,
        sampleRate: Double,
        frequencyHz: Double,
        amplitude: Double = 0.5,
        phaseRadians: Double = 0
    ) throws -> [Float] {
        try validateTone(
            frameCount: frameCount,
            sampleRate: sampleRate,
            frequencyHz: frequencyHz,
            amplitude: amplitude,
            phaseRadians: phaseRadians
        )
        return (0..<frameCount).map { frame in
            Float(amplitude * sin(
                2 * .pi * frequencyHz * Double(frame) / sampleRate +
                    phaseRadians
            ))
        }
    }

    static func linearSweep(
        frameCount: Int,
        sampleRate: Double,
        startFrequencyHz: Double,
        endFrequencyHz: Double,
        amplitude: Double = 0.5,
        phaseRadians: Double = 0
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        try validateSampleRate(sampleRate)
        guard frameCount >= 2,
              startFrequencyHz.isFinite, endFrequencyHz.isFinite,
              startFrequencyHz >= 0, endFrequencyHz >= 0,
              startFrequencyHz <= sampleRate / 2,
              endFrequencyHz <= sampleRate / 2,
              startFrequencyHz != endFrequencyHz else {
            throw DeterministicSignalFixtureError.invalidSweep
        }
        try validateAmplitude(amplitude)
        try validatePhase(phaseRadians)

        let duration = Double(frameCount - 1) / sampleRate
        return (0..<frameCount).map { frame in
            let progress = Double(frame) / Double(frameCount - 1)
            let phase = 2 * .pi * duration * (
                startFrequencyHz * progress +
                    0.5 * (endFrequencyHz - startFrequencyHz) * progress * progress
            ) + phaseRadians
            return Float(amplitude * sin(phase))
        }
    }

    static func impulse(
        frameCount: Int,
        index: Int,
        amplitude: Float = 1
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        guard index >= 0, index < frameCount else {
            throw DeterministicSignalFixtureError.invalidImpulseIndex
        }
        guard amplitude.isFinite, abs(amplitude) <= 1 else {
            throw DeterministicSignalFixtureError.invalidAmplitude
        }
        var samples = [Float](repeating: 0, count: frameCount)
        samples[index] = amplitude
        return samples
    }

    static func uniformNoise(
        frameCount: Int,
        amplitude: Double = 0.5,
        seed: UInt64
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        try validateAmplitude(amplitude)
        var generator = SplitMix64(state: seed)
        return (0..<frameCount).map { _ in
            let unit = Double(generator.next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
            return Float((2 * unit - 1) * amplitude)
        }
    }

    static func hardClippedSine(
        frameCount: Int,
        sampleRate: Double,
        frequencyHz: Double,
        inputAmplitude: Double,
        clipLevel: Double,
        phaseRadians: Double = 0
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        try validateSampleRate(sampleRate)
        guard frequencyHz.isFinite, frequencyHz >= 0,
              frequencyHz <= sampleRate / 2 else {
            throw DeterministicSignalFixtureError.invalidFrequency
        }
        guard inputAmplitude.isFinite, inputAmplitude > 0,
              inputAmplitude <= 4 else {
            throw DeterministicSignalFixtureError.invalidAmplitude
        }
        guard clipLevel.isFinite, clipLevel > 0, clipLevel <= 1,
              inputAmplitude > clipLevel else {
            throw DeterministicSignalFixtureError.invalidClipLevel
        }
        try validatePhase(phaseRadians)
        return (0..<frameCount).map { frame in
            let raw = inputAmplitude * sin(
                2 * .pi * frequencyHz * Double(frame) / sampleRate +
                    phaseRadians
            )
            return Float(min(clipLevel, max(-clipLevel, raw)))
        }
    }

    static func stereoPhasePair(
        frameCount: Int,
        sampleRate: Double,
        frequencyHz: Double,
        amplitude: Double = 0.5,
        leftPhaseRadians: Double = 0,
        rightPhaseRadians: Double
    ) throws -> [[Float]] {
        let left = try sine(
            frameCount: frameCount,
            sampleRate: sampleRate,
            frequencyHz: frequencyHz,
            amplitude: amplitude,
            phaseRadians: leftPhaseRadians
        )
        let right: [Float]
        if rightPhaseRadians.isFinite,
           abs(rightPhaseRadians - leftPhaseRadians - .pi) < 1e-12 {
            right = left.map { -$0 }
        } else {
            right = try sine(
                frameCount: frameCount,
                sampleRate: sampleRate,
                frequencyHz: frequencyHz,
                amplitude: amplitude,
                phaseRadians: rightPhaseRadians
            )
        }
        return [left, right]
    }

    static func linearEnvelope(
        frameCount: Int,
        attackFrames: Int,
        releaseFrames: Int,
        amplitude: Double = 1
    ) throws -> [Float] {
        try validateFrameCount(frameCount)
        try validateAmplitude(amplitude)
        guard attackFrames >= 2, releaseFrames >= 2,
              attackFrames <= frameCount, releaseFrames <= frameCount,
              attackFrames <= frameCount - releaseFrames else {
            throw DeterministicSignalFixtureError.invalidEnvelope
        }
        let releaseStart = frameCount - releaseFrames
        return (0..<frameCount).map { frame in
            if frame < attackFrames {
                return Float(amplitude * Double(frame) / Double(attackFrames - 1))
            }
            if frame < releaseStart { return Float(amplitude) }
            let releaseProgress = Double(frame - releaseStart) /
                Double(releaseFrames - 1)
            return Float(amplitude * (1 - releaseProgress))
        }
    }

    private static func validateTone(
        frameCount: Int,
        sampleRate: Double,
        frequencyHz: Double,
        amplitude: Double,
        phaseRadians: Double
    ) throws {
        try validateFrameCount(frameCount)
        try validateSampleRate(sampleRate)
        guard frequencyHz.isFinite, frequencyHz >= 0,
              frequencyHz <= sampleRate / 2 else {
            throw DeterministicSignalFixtureError.invalidFrequency
        }
        try validateAmplitude(amplitude)
        try validatePhase(phaseRadians)
    }

    private static func validateFrameCount(_ frameCount: Int) throws {
        guard (1...maximumFrameCount).contains(frameCount) else {
            throw DeterministicSignalFixtureError.invalidFrameCount
        }
    }

    private static func validateSampleRate(_ sampleRate: Double) throws {
        guard sampleRate.isFinite,
              sampleRate >= minimumSampleRate,
              sampleRate <= maximumSampleRate else {
            throw DeterministicSignalFixtureError.invalidSampleRate
        }
    }

    private static func validateAmplitude(_ amplitude: Double) throws {
        guard amplitude.isFinite, amplitude >= 0, amplitude <= 1 else {
            throw DeterministicSignalFixtureError.invalidAmplitude
        }
    }

    private static func validatePhase(_ phaseRadians: Double) throws {
        guard phaseRadians.isFinite, abs(phaseRadians) <= 2 * .pi else {
            throw DeterministicSignalFixtureError.invalidPhase
        }
    }
}

private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
