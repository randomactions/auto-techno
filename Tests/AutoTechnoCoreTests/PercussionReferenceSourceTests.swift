import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Shared percussion reference clock")
struct PercussionReferenceSourceTests {
    @Test("Source entropy follows physical duration, including the next event")
    func entropyAndReferenceIdentity() {
        for seed: UInt64 in [1, 421, 433, 449] {
            var random = SeededGenerator(seed: seed)
            var oracle = SeededGenerator(seed: seed)
            var source: [Float] = []
            for duration in [0.05, 0.08, 0.16, 0.065, 0.19] {
                let count = Int(48_000 * duration)
                let expected = (0..<count).map { _ in Float(oracle.unit() * 2 - 1) }
                #expect(PercussionReferenceSource.prepare(into: &source,
                    durationSeconds: duration, availableFrames: 96_000,
                    random: &random, makeSample: { _, noise in Float(noise) }))
                #expect(source == expected)
                #expect(source.count == count)
                #expect((0..<count).allSatisfy { frame in
                    PercussionReferenceSource.sample(source, frame: frame,
                        nativeSampleRate: 48_000).bitPattern == expected[frame].bitPattern
                })
                // Reads at a different native grid must never consume entropy.
                #expect((0..<Int(44_100 * duration)).allSatisfy { frame in
                    PercussionReferenceSource.sample(source, frame: frame,
                        nativeSampleRate: 44_100).isFinite
                })
            }
            #expect(random.next() == oracle.next())
        }
    }

    @Test("One physical envelope is realized at both native clocks")
    func physicalEnvelope() {
        var random = SeededGenerator(seed: 421)
        var source: [Float] = []
        #expect(PercussionReferenceSource.prepare(into: &source,
            durationSeconds: 0.05, availableFrames: 96_000, random: &random,
            makeSample: { time, _ in Float(exp(-120 * time)) }))
        // Interior physical times avoid source-boundary extension. This tests
        // the rendered clock against an analytic envelope, not a rate-specific
        // PCM hash or a value fitted to the rejected study.
        for time in [0.01, 0.02, 0.03, 0.04] {
            let expected = Float(exp(-120 * time))
            for rate in [44_100.0, 48_000.0] {
                let frame = Int((time * rate).rounded())
                let actual = PercussionReferenceSource.sample(source,
                    frame: frame, nativeSampleRate: rate)
                #expect(abs(actual - expected) <= 0.000_01)
            }
        }
    }

    @Test("Clipped support consumes only its reference frames and storage is reused")
    func clippedSupportAndStorage() {
        var random = SeededGenerator(seed: 433)
        var oracle = SeededGenerator(seed: 433)
        var source: [Float] = []
        #expect(PercussionReferenceSource.prepare(into: &source,
            durationSeconds: 0.19, availableFrames: 113, random: &random,
            makeSample: { _, noise in Float(noise) }))
        let expected = (0..<113).map { _ in Float(oracle.unit() * 2 - 1) }
        #expect(source == expected)
        #expect(random.next() == oracle.next())
        let capacity = source.capacity
        #expect(source.count == 113 && capacity >= 9_120)
        #expect(PercussionReferenceSource.prepare(into: &source,
            durationSeconds: 0.19, availableFrames: 96_000, random: &random,
            makeSample: { _, _ in 0 }))
        #expect(source.count == 9_120 && source.capacity == capacity)
        #expect(source.allSatisfy { $0 == 0 })
    }

    @Test("Invalid geometry refuses before drawing and nonfinite source refuses")
    func invalidInputs() {
        for duration in [0.0, -1, 0.191, .nan, .infinity] {
            var random = SeededGenerator(seed: 449)
            var oracle = SeededGenerator(seed: 449)
            var source: [Float] = []
            #expect(!PercussionReferenceSource.prepare(into: &source,
                durationSeconds: duration, availableFrames: 96_000,
                random: &random, makeSample: { _, _ in 0 }))
            #expect(source.isEmpty && random.next() == oracle.next())
        }
        var random = SeededGenerator(seed: 449)
        var source: [Float] = []
        #expect(!PercussionReferenceSource.prepare(into: &source,
            durationSeconds: 0.05, availableFrames: 0,
            random: &random, makeSample: { _, _ in 0 }))
        #expect(!PercussionReferenceSource.prepare(into: &source,
            durationSeconds: 0.05, availableFrames: 2,
            random: &random, makeSample: { _, _ in .nan }))
        for rate in [0.0, -1, .nan, .infinity] {
            #expect(PercussionReferenceSource.sample([1], frame: 0,
                nativeSampleRate: rate).isNaN)
        }
        #expect(PercussionReferenceSource.sample([], frame: 0,
            nativeSampleRate: 48_000).isNaN)
        #expect(PercussionReferenceSource.sample([1], frame: -1,
            nativeSampleRate: 48_000).isNaN)
    }

    @Test("The connected renderer retains original reference hat PCM and exact replay")
    func canonicalReferenceHats() throws {
        // Selection uses only the canonical score, before any PCM is generated.
        let fixture = try #require(hatOnlySharedNoiseBar())
        let plan = fixture.plan, resolved = fixture.bar
        let rendered = render(plan: plan, resolved: resolved, sampleRate: 48_000)
        let replay = render(plan: plan, resolved: resolved, sampleRate: 48_000)
        #expect(rendered == replay)
        let frames = Int((240.0 / plan.scene.bpm * 48_000).rounded())
        var oracle = SeededGenerator(seed: resolved.performance.eventSeed)
        var expectedIndices: [Int] = []
        for (index, event) in resolved.ensemble.events.enumerated()
            where event.voice == .percussion {
            expectedIndices.append(index)
            let evidence = try #require(rendered.closedHatRenderEvidence.first {
                $0.scoreEventIndex == index
            })
            let offset = VoiceRenderer.timingOffsetInSteps(for: .percussion,
                step: event.step, dna: plan.dna)
            let start = Int(((Double(event.step) + offset) * Double(frames) / 16).rounded())
            let count = min(2_400, frames - start)
            let accent = resolved.performance.accent(at: event.step) * event.intensity
            let level = ClosedHatVoiceContract.level(
                section: resolved.performance.section, combinedAccent: accent)
            let role = resolved.closedHatDecay(atEventIndex: index)?.role ?? .neutral
            let decay = ClosedHatVoiceContract.decayRate(
                brightness: plan.scene.character.percussionBrightness, role: role)
            // Original authored48 recurrence, independent of the new source helper.
            var state = 0.0
            var expected: [Float] = []
            for frame in 0..<count {
                let noise = oracle.unit() * 2 - 1
                state += (noise - state) *
                    (0.25 + plan.scene.character.percussionBrightness * 0.25)
                expected.append(Float((noise - state * 0.7) *
                    exp(-Double(frame) / 48_000 * decay) * level))
            }
            #expect(evidence.renderedFrameCount == count)
            #expect(evidence.sampleHash == ExactPCMFingerprint.mono(expected))
        }
        #expect(rendered.closedHatRenderEvidence.map(\.scoreEventIndex).sorted() == expectedIndices)
        let lower = render(plan: plan, resolved: resolved, sampleRate: 44_100)
        #expect(lower == render(plan: plan, resolved: resolved, sampleRate: 44_100))
        #expect(lower.closedHatRenderEvidence.count == expectedIndices.count)
        #expect(lower.closedHatRenderEvidence.allSatisfy { $0.finite })
        #expect(lower.closedHatRenderEvidence.map(\.sampleHash) !=
                rendered.closedHatRenderEvidence.map(\.sampleHash))
    }

    private func hatOnlySharedNoiseBar() -> (plan: AutonomousPhrasePlan,
                                             bar: ResolvedPerformanceBar)? {
        for seed in UInt64(1)...128 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let plan = director.plan(from: director.initialState())
            for bar in plan.resolvedBars {
                let shared = bar.ensemble.events.filter {
                    [EnsembleVoice.percussion, .clap, .openHat, .metallic].contains($0.voice)
                }
                if shared.count >= 2 && shared.allSatisfy({ $0.voice == .percussion }) {
                    return (plan, bar)
                }
            }
        }
        return nil
    }

    @inline(never)
    private func render(plan: AutonomousPhrasePlan, resolved: ResolvedPerformanceBar,
                        sampleRate: Double) -> RenderedBar {
        let synth = SynthPerformancePlan(scene: plan.scene, dna: plan.dna,
            kind: plan.kind, resolvedBars: [resolved])
        var state = RenderState()
        state.barIndex = resolved.performance.bar
        var workspace = RenderWorkspace()
        return VoiceRenderer.renderBar(scene: plan.scene, sampleRate: sampleRate,
            state: &state, dna: plan.dna, resolved: resolved,
            synthWorld: synth.world, synthPerformance: synth.bars[0],
            workspace: &workspace, layer: .full, phraseKind: plan.kind)
    }
}
