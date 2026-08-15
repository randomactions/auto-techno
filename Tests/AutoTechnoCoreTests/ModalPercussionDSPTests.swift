import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Modal percussion DSP", .serialized)
struct ModalPercussionDSPTests {
    @Test("Six modal modes are stable and stay below the route ceiling")
    func sixModesAreStableAndBelowTheRouteCeiling() throws {
        let result = render(sampleRate: 44_100)
        let event = try #require(result.evidence.events.first)

        #expect(event.modeCount == 6)
        #expect(event.stable)
        #expect(event.finite)
        #expect(event.minimumModeFrequencyHz >= event.appliedFundamentalHz)
        #expect(event.maximumModeFrequencyHz < 0.9 * 44_100 * 0.5)
        #expect(event.maximumPoleRadius > 0 && event.maximumPoleRadius < 1)
        #expect(event.modeRatioFingerprint.count == 16)
    }

    @Test("The rendered fundamental matches the resolved score")
    func fundamentalPitchMatchesTheResolvedScore() throws {
        let sampleRate = 48_000.0
        let requested = 110.0
        let result = render(
            sampleRate: sampleRate,
            articulation: articulation(
                fundamentalHz: requested,
                brightness: 0,
                inharmonicity: 0
            )
        )
        let measured = dominantFrequency(
            result.output,
            sampleRate: sampleRate,
            expected: requested
        )
        let cents = abs(1_200 * log2(measured / requested))
        let evidence = try #require(result.evidence.events.first)

        #expect(abs(evidence.appliedFundamentalHz - requested) < 0.000_001)
        #expect(cents < 15)
    }

    @Test("Excitation is deterministic and exactly zero mean")
    func excitationIsDeterministicAndExactlyZeroMean() {
        let source = articulation()
        let first = ModalPercussionVoice.excitationSamples(
            articulation: source,
            sampleRate: 48_000
        )
        let replay = ModalPercussionVoice.excitationSamples(
            articulation: source,
            sampleRate: 48_000
        )

        #expect(first == replay)
        #expect(!first.isEmpty)
        #expect(first.count <= Int(48_000 * ModalPercussionVoice.maximumExcitationSeconds))
        #expect(first.reduce(0, +) == 0)
    }

    @Test("Different modal intent changes exact PCM")
    func differentModalIntentChangesPCM() {
        let first = render(sampleRate: 44_100, articulation: articulation())
        let second = render(
            sampleRate: 44_100,
            articulation: articulation(
                fundamentalHz: 146.832_383_958_703_8,
                modalDegree: 5,
                brightness: 0.82,
                inharmonicity: 0.09
            )
        )

        #expect(first.evidence.dryBarSampleHash != second.evidence.dryBarSampleHash)
        #expect(first.output != second.output)
    }

    @Test("Physical decay agrees at 44.1 and 48 kHz")
    func physicalDecayMatchesAt44100And48000() throws {
        let at441 = render(sampleRate: 44_100, durationSeconds: 0.8)
        let at480 = render(sampleRate: 48_000, durationSeconds: 0.8)
        let decay441 = decayTime(
            at441.output,
            sampleRate: 44_100
        )
        let decay480 = decayTime(
            at480.output,
            sampleRate: 48_000
        )
        let evidence441 = try #require(at441.evidence.events.first)
        let evidence480 = try #require(at480.evidence.events.first)

        #expect(abs(decay441 - decay480) < 0.025)
        #expect(abs(evidence441.tailToBodyDB - evidence480.tailToBodyDB) < 1.5)
        #expect(abs(evidence441.attackRMS - evidence480.attackRMS) < 0.02)
    }

    @Test("Bar continuation equals one continuous render")
    func barContinuationMatchesOneContinuousRender() {
        let sampleRate = 44_100.0
        let barFrames = Int(sampleRate * 0.25)
        let event = scheduled(articulation: articulation(), startFrame: 0)

        var continuousState = ModalPercussionVoiceState()
        var continuous = [Float](repeating: 0, count: barFrames * 2)
        _ = ModalPercussionVoice.renderBar(
            into: &continuous,
            bar: 0,
            sampleRate: sampleRate,
            events: [event],
            state: &continuousState
        )

        var splitState = ModalPercussionVoiceState()
        var first = [Float](repeating: 0, count: barFrames)
        var second = [Float](repeating: 0, count: barFrames)
        _ = ModalPercussionVoice.renderBar(
            into: &first,
            bar: 0,
            sampleRate: sampleRate,
            events: [event],
            state: &splitState
        )
        _ = ModalPercussionVoice.renderBar(
            into: &second,
            bar: 1,
            sampleRate: sampleRate,
            events: [],
            state: &splitState
        )

        #expect(first + second == continuous)
        #expect(splitState == continuousState)
    }

    @Test("Four-voice capacity is exact and a fifth voice cannot steal")
    func fourVoiceCapacityIsExactAndFifthVoiceDoesNotSteal() {
        let sampleRate = 44_100.0
        let events = (0..<5).map { index in
            scheduled(
                articulation: articulation(seed: UInt64(index + 1)),
                startFrame: 0
            )
        }
        let frames = Int(sampleRate * 0.05)
        var fiveState = ModalPercussionVoiceState()
        var fiveOutput = [Float](repeating: 0, count: frames)
        let fiveEvidence = ModalPercussionVoice.renderBar(
            into: &fiveOutput,
            bar: 0,
            sampleRate: sampleRate,
            events: events,
            state: &fiveState
        )

        var fourState = ModalPercussionVoiceState()
        var fourOutput = [Float](repeating: 0, count: frames)
        _ = ModalPercussionVoice.renderBar(
            into: &fourOutput,
            bar: 0,
            sampleRate: sampleRate,
            events: Array(events.prefix(4)),
            state: &fourState
        )

        #expect(fiveEvidence.events.count == 5)
        #expect(fiveEvidence.events.prefix(4).allSatisfy { $0.capacityValid })
        #expect(fiveEvidence.events.last?.capacityValid == false)
        #expect(fiveOutput == fourOutput)
        #expect(activeSeeds(fiveState) == activeSeeds(fourState))
        #expect(activeSeeds(fiveState) == [1, 2, 3, 4])
    }

    @Test("Aggressive finite articulation remains finite")
    func aggressiveFiniteArticulationRemainsFinite() throws {
        let result = render(
            sampleRate: 48_000,
            articulation: articulation(
                fundamentalHz: 196,
                excitation: 1,
                damping: 1,
                brightness: 1,
                inharmonicity: 0.12,
                intensity: 1
            )
        )
        let event = try #require(result.evidence.events.first)

        #expect(result.output.allSatisfy { $0.isFinite })
        #expect(result.evidence.finite)
        #expect(event.finite)
        #expect(event.stable)
        #expect(event.peak.isFinite)
        #expect(event.rms.isFinite)
    }

    @Test("Route rebuild is deterministic")
    func routeRebuildIsDeterministic() {
        var rebuiltState = ModalPercussionVoiceState()
        var oldRoute = [Float](repeating: 0, count: 4_410)
        _ = ModalPercussionVoice.renderBar(
            into: &oldRoute,
            bar: 0,
            sampleRate: 44_100,
            events: [scheduled(articulation: articulation(seed: 77), startFrame: 0)],
            state: &rebuiltState
        )

        let event = scheduled(articulation: articulation(seed: 99), startFrame: 0)
        var rebuilt = [Float](repeating: 0, count: 4_800)
        let rebuiltEvidence = ModalPercussionVoice.renderBar(
            into: &rebuilt,
            bar: 1,
            sampleRate: 48_000,
            events: [event],
            state: &rebuiltState
        )

        var freshState = ModalPercussionVoiceState()
        var fresh = [Float](repeating: 0, count: 4_800)
        let freshEvidence = ModalPercussionVoice.renderBar(
            into: &fresh,
            bar: 1,
            sampleRate: 48_000,
            events: [event],
            state: &freshState
        )

        #expect(rebuilt == fresh)
        #expect(rebuiltState == freshState)
        #expect(rebuiltEvidence == freshEvidence)
    }

    private func render(
        sampleRate: Double,
        durationSeconds: Double = 0.5,
        articulation: ModalPercussionArticulation? = nil
    ) -> (
        output: [Float],
        evidence: ModalPercussionBarRenderEvidence,
        state: ModalPercussionVoiceState
    ) {
        let resolvedArticulation = articulation ?? self.articulation()
        var state = ModalPercussionVoiceState()
        var output = [Float](
            repeating: 0,
            count: Int((sampleRate * durationSeconds).rounded())
        )
        let evidence = ModalPercussionVoice.renderBar(
            into: &output,
            bar: 0,
            sampleRate: sampleRate,
            events: [scheduled(articulation: resolvedArticulation, startFrame: 0)],
            state: &state
        )
        return (output, evidence, state)
    }

    private func scheduled(
        articulation: ModalPercussionArticulation,
        startFrame: Int
    ) -> ScheduledModalPercussionEvent {
        ScheduledModalPercussionEvent(
            articulation: articulation,
            startFrame: startFrame,
            level: 0.10
        )
    }

    private func articulation(
        fundamentalHz: Double = 110,
        modalDegree: Int = 0,
        excitation: Double = 0.72,
        damping: Double = 0.82,
        brightness: Double = 0.34,
        inharmonicity: Double = 0.025,
        intensity: Double = 0.58,
        seed: UInt64 = 0xA11CE
    ) -> ModalPercussionArticulation {
        ModalPercussionArticulation(
            scoreEventIndex: 0,
            step: 10,
            use: .foundationCompanion,
            modalIdentity: .dorian,
            modalDegree: modalDegree,
            octave: 1,
            fundamentalHz: fundamentalHz,
            excitation: excitation,
            damping: damping,
            brightness: brightness,
            inharmonicity: inharmonicity,
            eventIntensity: intensity,
            seed: seed
        )
    }

    private func activeSeeds(_ state: ModalPercussionVoiceState) -> [UInt64] {
        [state.slot0, state.slot1, state.slot2, state.slot3]
            .filter { $0.active }
            .map { $0.articulationSeed }
    }

    private func dominantFrequency(
        _ samples: [Float],
        sampleRate: Double,
        expected: Double
    ) -> Double {
        let start = min(samples.count, Int(sampleRate * 0.006))
        let end = min(samples.count, start + Int(sampleRate * 0.14))
        let minimumLag = max(1, Int(sampleRate / (expected * 1.08)))
        let maximumLag = max(minimumLag, Int(sampleRate / (expected * 0.92)))
        var bestLag = minimumLag
        var bestCorrelation = -Double.infinity
        for lag in minimumLag...maximumLag where start + lag < end {
            var correlation = 0.0
            var energyA = 0.0
            var energyB = 0.0
            for index in (start + lag)..<end {
                let a = Double(samples[index])
                let b = Double(samples[index - lag])
                correlation += a * b
                energyA += a * a
                energyB += b * b
            }
            let normalized = correlation / sqrt(max(1e-30, energyA * energyB))
            if normalized > bestCorrelation {
                bestCorrelation = normalized
                bestLag = lag
            }
        }
        return sampleRate / Double(bestLag)
    }

    private func decayTime(_ samples: [Float], sampleRate: Double) -> Double {
        let window = max(1, Int(sampleRate * 0.010))
        var values: [Double] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + window)
            let energy = samples[start..<end].reduce(0.0) {
                $0 + Double($1) * Double($1)
            }
            values.append(sqrt(energy / Double(max(1, end - start))))
            start = end
        }
        let peak = values.max() ?? 0
        let threshold = peak * 0.01
        let index = values.lastIndex { $0 >= threshold } ?? 0
        return Double(index * window) / sampleRate
    }
}
