import Foundation
import Testing

struct DeterministicSignalFixturesTests {
    @Test("Musical role fixtures have exact onset, pitch, and decay properties")
    func musicalRoleFixtureProperties() throws {
        let kick = try DeterministicSignalFixtures.kickHit(
            frameCount: 2_000, sampleRate: 8_000, onsetFrame: 120,
            startFrequencyHz: 110, endFrequencyHz: 40,
            amplitude: 0.8, decayFrames: 800
        )
        #expect(kick.prefix(120).allSatisfy { $0 == 0 })
        #expect(kick[120] == 0.8)
        #expect(kick[919] == 0)
        #expect(kick.suffix(1_080).allSatisfy { $0 == 0 })
        #expect(kick.allSatisfy { $0.isFinite && abs($0) <= 0.8 })
        #expect(zeroCrossings(in: kick[120..<320]) >
                zeroCrossings(in: kick[650..<850]))

        let bass = try DeterministicSignalFixtures.bassNote(
            frameCount: 2_000, sampleRate: 8_000, onsetFrame: 200,
            durationFrames: 1_000, frequencyHz: 80, amplitude: 0.4
        )
        #expect(bass.prefix(200).allSatisfy { $0 == 0 })
        #expect(bass[200] == 0)
        #expect(bass[1_199] == 0)
        #expect(bass.suffix(800).allSatisfy { $0 == 0 })
        let bassCycles = positiveZeroCrossings(in: bass[202..<1_180])
        #expect(abs(bassCycles - 10) <= 1)

        let hat = try DeterministicSignalFixtures.hatBurst(
            frameCount: 2_000, sampleRate: 8_000, onsetFrame: 100,
            decayFrames: 400, amplitude: 0.3, seed: 0xA770
        )
        let repeatedHat = try DeterministicSignalFixtures.hatBurst(
            frameCount: 2_000, sampleRate: 8_000, onsetFrame: 100,
            decayFrames: 400, amplitude: 0.3, seed: 0xA770
        )
        let otherHat = try DeterministicSignalFixtures.hatBurst(
            frameCount: 2_000, sampleRate: 8_000, onsetFrame: 100,
            decayFrames: 400, amplitude: 0.3, seed: 0xA771
        )
        #expect(hat == repeatedHat)
        #expect(hat != otherHat)
        #expect(hat.prefix(100).allSatisfy { $0 == 0 })
        #expect(hat[499] == 0)
        #expect(hat.suffix(1_500).allSatisfy { $0 == 0 })
        #expect(hat.allSatisfy { $0.isFinite && abs($0) <= 0.3 })
    }

    @Test("Role-separated loops preserve grid events and phrase changes isolate bass")
    func roleSeparatedLoopAndPhraseChange() throws {
        let args: (Double, Double, [Int], [Int], [Int]) =
            (8_000, 120, [0, 16], [0, 4, 16, 20], [0, 8, 16, 24])
        let loop = try DeterministicSignalFixtures.roleSeparatedLoop(
            bars: 2, sampleRate: args.0, tempoBPM: args.1,
            kickSteps: args.2, bassSteps: args.3, hatSteps: args.4,
            seed: 0xBEEF
        )
        #expect(loop.frameCount == 32_000)
        #expect(loop.framesPerBar == 16_000)
        #expect(loop.tracks[.kick]?.eventOnsets == [0, 16_000])
        #expect(loop.tracks[.bass]?.eventOnsets == [0, 4_000, 16_000, 20_000])
        #expect(loop.tracks[.hat]?.eventOnsets == [0, 8_000, 16_000, 24_000])
        #expect(loop.tracks.values.allSatisfy { $0.samples.count == loop.frameCount })
        for onset in loop.tracks[.kick]?.eventOnsets ?? [] {
            #expect(loop.tracks[.kick]?.samples[onset] != 0)
            #expect(loop.tracks[.kick]?.samples[onset + 1_440] == 0)
        }
        for onset in loop.tracks[.bass]?.eventOnsets ?? [] {
            #expect(loop.tracks[.bass]?.samples[onset] == 0)
            #expect(loop.tracks[.bass]?.samples[onset + 1] != 0)
            #expect(loop.tracks[.bass]?.samples[onset + 3_999] == 0)
        }
        for onset in loop.tracks[.hat]?.eventOnsets ?? [] {
            #expect(loop.tracks[.hat]?.samples[onset] != 0)
            #expect(loop.tracks[.hat]?.samples[onset + 359] == 0)
        }

        let pair = try DeterministicSignalFixtures.bassPhraseChange(
            bars: 2, sampleRate: args.0, tempoBPM: args.1,
            kickSteps: args.2, bassSteps: args.3, hatSteps: args.4,
            fromFrequencyHz: 55, toFrequencyHz: 65, seed: 0xBEEF
        )
        #expect(pair.changedRole == .bass)
        #expect(pair.before.tracks[.kick] == pair.after.tracks[.kick])
        #expect(pair.before.tracks[.hat] == pair.after.tracks[.hat])
        #expect(pair.before.tracks[.bass]?.eventOnsets == pair.after.tracks[.bass]?.eventOnsets)
        #expect(pair.before.tracks[.bass]?.samples != pair.after.tracks[.bass]?.samples)
        let repeatedBefore = try DeterministicSignalFixtures.roleSeparatedLoop(
            bars: 2, sampleRate: args.0, tempoBPM: args.1,
            kickSteps: args.2, bassSteps: args.3, hatSteps: args.4,
            bassFrequencyHz: 55, seed: 0xBEEF
        )
        #expect(pair.before == repeatedBefore)
    }

    @Test("Role-entry transition changes one role at a declared phrase boundary")
    func roleEntryTransitionIsolation() throws {
        let base = try DeterministicSignalFixtures.roleSeparatedLoop(
            bars: 2, sampleRate: 8_000, tempoBPM: 120,
            kickSteps: [0, 16], bassSteps: [0, 4, 16, 20], hatSteps: []
        )
        let transition = try DeterministicSignalFixtures.roleEntryTransition(
            from: base, incomingRole: .hat, eventSteps: [16, 20, 24, 28],
            fadeFrames: 800, seed: 0xA770
        )
        #expect(transition.boundaryFrame == 16_000)
        #expect(transition.incomingRole == .hat)
        #expect(transition.transitioned.tracks[.kick] == base.tracks[.kick])
        #expect(transition.transitioned.tracks[.bass] == base.tracks[.bass])
        #expect(transition.transitioned.tracks[.hat]?.eventOnsets == [16_000, 20_000, 24_000, 28_000])
        #expect(transition.transitioned.tracks[.hat]?.samples.prefix(16_000).allSatisfy { $0 == 0 } == true)
        #expect(transition.transitioned.tracks[.hat]?.samples[16_000] == 0)
        #expect(transition.transitioned.tracks[.hat]?.samples[16_001..<16_800].contains(where: { $0 != 0 }) == true)
    }

    @Test("Musical fixture builders reject invalid geometry and event patterns")
    func invalidMusicalFixtureRequests() {
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.kickHit(
                frameCount: 100, sampleRate: 8_000, onsetFrame: 100,
                decayFrames: 10
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.bassNote(
                frameCount: 100, sampleRate: 8_000, onsetFrame: 0,
                durationFrames: 100, frequencyHz: 4_000
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.hatBurst(
                frameCount: 100, sampleRate: .nan, onsetFrame: 0,
                decayFrames: 10, seed: 1
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.roleSeparatedLoop(
                bars: 2, sampleRate: 8_000, tempoBPM: 120,
                kickSteps: [4, 0], bassSteps: [], hatSteps: []
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.roleSeparatedLoop(
                bars: 2, sampleRate: 8_000, tempoBPM: 120,
                kickSteps: [0, 0], bassSteps: [], hatSteps: []
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.bassPhraseChange(
                bars: 1, sampleRate: 8_000, tempoBPM: 120,
                kickSteps: [], bassSteps: [0], hatSteps: [],
                fromFrequencyHz: 55, toFrequencyHz: 55
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.roleSeparatedLoop(
                bars: 16, sampleRate: 192_000, tempoBPM: 40,
                kickSteps: [], bassSteps: [], hatSteps: []
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.roleSeparatedLoop(
                bars: 1, sampleRate: 8_000, tempoBPM: 120,
                kickSteps: [], bassSteps: [], hatSteps: [],
                bassFrequencyHz: .nan
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.roleSeparatedLoop(
                bars: 1, sampleRate: 8_000, tempoBPM: .nan,
                kickSteps: [], bassSteps: [], hatSteps: []
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            let base = try DeterministicSignalFixtures.roleSeparatedLoop(
                bars: 2, sampleRate: 8_000, tempoBPM: 120,
                kickSteps: [], bassSteps: [], hatSteps: []
            )
            _ = try DeterministicSignalFixtures.roleEntryTransition(
                from: base, incomingRole: .bass, eventSteps: [16],
                fadeFrames: 100
            )
        }
    }

    @Test("Silence, DC, and impulses have exact sample-index boundaries")
    func exactSignalBoundaries() throws {
        #expect(try DeterministicSignalFixtures.silence(frameCount: 9) ==
                [Float](repeating: 0, count: 9))
        #expect(try DeterministicSignalFixtures.dc(
            frameCount: 9, value: -0.25
        ) == [Float](repeating: -0.25, count: 9))

        let impulse = try DeterministicSignalFixtures.impulse(
            frameCount: 9, index: 4, amplitude: -0.75
        )
        #expect(impulse == [0, 0, 0, 0, -0.75, 0, 0, 0, 0])
    }

    @Test("Sines and sweeps preserve explicit phase, amplitude, and direction")
    func toneAndSweepProperties() throws {
        let sine = try DeterministicSignalFixtures.sine(
            frameCount: 80,
            sampleRate: 8_000,
            frequencyHz: 1_000,
            amplitude: 0.5,
            phaseRadians: .pi / 2
        )
        #expect(sine[0] == 0.5)
        #expect(abs(Double(sine[1]) - 0.5 * cos(.pi / 4)) < 1e-7)
        let repeatedSine = try DeterministicSignalFixtures.sine(
            frameCount: 80,
            sampleRate: 8_000,
            frequencyHz: 1_000,
            amplitude: 0.5,
            phaseRadians: .pi / 2
        )
        #expect(sine == repeatedSine)

        let rising = try DeterministicSignalFixtures.linearSweep(
            frameCount: 8_000,
            sampleRate: 8_000,
            startFrequencyHz: 100,
            endFrequencyHz: 2_000,
            amplitude: 0.3
        )
        #expect(rising.allSatisfy { $0.isFinite && abs($0) <= 0.3 })
        #expect(zeroCrossings(in: rising.suffix(2_000)) >
                zeroCrossings(in: rising.prefix(2_000)))
    }

    @Test("Noise is seeded, clipping is bounded, and stereo phase is explicit")
    func noiseClippingAndStereoPhase() throws {
        let noise = try DeterministicSignalFixtures.uniformNoise(
            frameCount: 4_096, amplitude: 0.2, seed: 0xA770
        )
        let repeatedNoise = try DeterministicSignalFixtures.uniformNoise(
            frameCount: 4_096, amplitude: 0.2, seed: 0xA770
        )
        let otherSeedNoise = try DeterministicSignalFixtures.uniformNoise(
            frameCount: 4_096, amplitude: 0.2, seed: 0xA771
        )
        #expect(noise == repeatedNoise)
        #expect(noise != otherSeedNoise)
        #expect(noise.allSatisfy { $0.isFinite && abs($0) <= 0.2 })

        let clipped = try DeterministicSignalFixtures.hardClippedSine(
            frameCount: 80,
            sampleRate: 8_000,
            frequencyHz: 1_000,
            inputAmplitude: 2,
            clipLevel: 0.75
        )
        #expect(clipped.allSatisfy { abs($0) <= 0.75 })
        #expect(clipped[2] == 0.75)
        #expect(clipped[6] == -0.75)
        #expect(clipped.filter { abs($0) == 0.75 }.count > 0)

        let inPhase = try DeterministicSignalFixtures.stereoPhasePair(
            frameCount: 80, sampleRate: 8_000, frequencyHz: 1_000,
            amplitude: 0.25, leftPhaseRadians: 0, rightPhaseRadians: 0
        )
        let inverted = try DeterministicSignalFixtures.stereoPhasePair(
            frameCount: 80, sampleRate: 8_000, frequencyHz: 1_000,
            amplitude: 0.25, leftPhaseRadians: 0, rightPhaseRadians: .pi
        )
        let quadrature = try DeterministicSignalFixtures.stereoPhasePair(
            frameCount: 80, sampleRate: 8_000, frequencyHz: 1_000,
            amplitude: 0.25, leftPhaseRadians: 0, rightPhaseRadians: .pi / 2
        )
        #expect(inPhase[0] == inPhase[1])
        #expect(zip(inverted[0], inverted[1]).allSatisfy { $0.0 == -$0.1 })
        let crossProduct = zip(quadrature[0], quadrature[1]).reduce(0.0) {
            $0 + Double($1.0) * Double($1.1)
        }
        #expect(abs(crossProduct) < 1e-6)
    }

    @Test("Linear envelope transitions land on declared frames")
    func envelopeBoundaries() throws {
        let envelope = try DeterministicSignalFixtures.linearEnvelope(
            frameCount: 10, attackFrames: 3, releaseFrames: 3, amplitude: 0.8
        )
        #expect(envelope == [0, 0.4, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.4, 0])
    }

    @Test("Fixture constructors reject malformed dimensions and signal bounds")
    func invalidRequests() {
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.silence(frameCount: 0)
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.sine(
                frameCount: 16, sampleRate: 8_000,
                frequencyHz: 4_001
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.sine(
                frameCount: 16, sampleRate: .nan,
                frequencyHz: 1_000
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.sine(
                frameCount: 16, sampleRate: 8_000,
                frequencyHz: 1_000, phaseRadians: .greatestFiniteMagnitude
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.impulse(
                frameCount: 16, index: 16
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.linearEnvelope(
                frameCount: 8, attackFrames: 5, releaseFrames: 4
            )
        }
        #expect(throws: DeterministicSignalFixtureError.self) {
            try DeterministicSignalFixtures.linearEnvelope(
                frameCount: 8, attackFrames: .max, releaseFrames: 2
            )
        }
    }

    private func zeroCrossings<Samples: Collection>(in samples: Samples) -> Int
    where Samples.Element == Float {
        zip(samples, samples.dropFirst()).reduce(0) { count, pair in
            (pair.0 < 0 && pair.1 >= 0) || (pair.0 >= 0 && pair.1 < 0) ?
                count + 1 : count
        }
    }

    private func positiveZeroCrossings<Samples: Collection>(in samples: Samples) -> Int
    where Samples.Element == Float {
        zip(samples, samples.dropFirst()).reduce(0) {
            $0 + ($1.0 <= 0 && $1.1 > 0 ? 1 : 0)
        }
    }
}
