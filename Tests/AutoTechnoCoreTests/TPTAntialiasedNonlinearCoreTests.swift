@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Canonical TPT and antialiased nonlinear core")
struct TPTAntialiasedNonlinearCoreTests {
    @Test("First-order ADAA suppresses folded tanh harmonics")
    func antiderivativeAntialiasingSuppressesFoldedHarmonics() {
        let sampleRate = 48_000.0
        let frequency = 7_500.0
        let frameCount = 8_192
        let drive = TPTAntialiasedNonlinearCoreContract.maximumDrive
        var state = AntiderivativeAntialiasedTanhState()
        var direct = [Double]()
        var antialiased = [Double]()
        direct.reserveCapacity(frameCount)
        antialiased.reserveCapacity(frameCount)

        for frame in 0..<frameCount {
            let input = 0.92 * sin(2 * .pi * frequency * Double(frame) / sampleRate)
            direct.append(tanh(input * drive) / drive)
            antialiased.append(state.process(input * drive) / drive)
        }

        let foldedFrequencies = [4_500.0, 10_500.0, 19_500.0]
        let directFoldedEnergy = foldedFrequencies.reduce(0.0) {
            $0 + pow(magnitude(direct, frequency: $1, sampleRate: sampleRate), 2)
        }
        let antialiasedFoldedEnergy = foldedFrequencies.reduce(0.0) {
            $0 + pow(magnitude(antialiased, frequency: $1, sampleRate: sampleRate), 2)
        }
        let directFundamental = magnitude(
            direct, frequency: frequency, sampleRate: sampleRate
        )
        let antialiasedFundamental = magnitude(
            antialiased, frequency: frequency, sampleRate: sampleRate
        )

        #expect(antialiasedFoldedEnergy < directFoldedEnergy * 0.45)
        #expect(antialiasedFundamental > directFundamental * 0.80)
    }

    @Test("TPT low-pass response stays rate-normalized")
    func rateNormalizedResponse() {
        let gains = [44_100.0, 48_000.0, 96_000.0, 192_000.0].map { sampleRate in
            var filter = TPTStateVariableFilterState()
            let frameCount = Int(sampleRate)
            let settleFrame = Int(sampleRate * 0.25)
            var inputEnergy = 0.0
            var outputEnergy = 0.0
            var observed = 0
            for frame in 0..<frameCount {
                let input = sin(2 * .pi * 440 * Double(frame) / sampleRate)
                let output = filter.process(
                    input,
                    sampleRate: sampleRate,
                    cutoffHz: 1_200,
                    q: 0.707_106_781_186_547_6
                ).lowPass
                if frame >= settleFrame {
                    inputEnergy += input * input
                    outputEnergy += output * output
                    observed += 1
                }
            }
            return sqrt(outputEnergy / Double(observed)) /
                sqrt(inputEnergy / Double(observed))
        }

        #expect(gains.allSatisfy { $0.isFinite })
        #expect((gains.max() ?? 1) - (gains.min() ?? 0) < 0.005)
    }

    @Test("Aggressive modulation stays finite and emits bounded evidence")
    func modulationBoundsAndEvidence() {
        for sampleRate in [8_000.0, 44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            var state = TPTAntialiasedNonlinearCoreState()
            var accumulator = TPTAntialiasedNonlinearCoreEvidenceAccumulator()
            let frameCount = Int(sampleRate * 0.20)
            var outputPeak = 0.0
            for frame in 0..<frameCount {
                let progress = Double(frame) / Double(max(1, frameCount - 1))
                let input = sin(2 * .pi * (90 + 2_900 * progress) *
                    Double(frame) / sampleRate)
                let output = TPTAntialiasedNonlinearCore.process(
                    input: input,
                    sampleRate: sampleRate,
                    cutoffHz: 1 + sampleRate * 0.40 * progress,
                    resonance: -0.5 + progress * 2,
                    inputDrive: 0.2 + progress * 4.2,
                    outputDrive: 4.2 - progress * 3.8,
                    bandMix: -0.2 + progress,
                    state: &state,
                    evidence: &accumulator
                )
                #expect(output.isFinite)
                outputPeak = max(outputPeak, abs(output))
            }
            let evidence = accumulator.evidence(
                sourceAssignmentCount: 1,
                sourceEventCount: 1
            )
            #expect(state.isFinite)
            #expect(outputPeak > 0)
            #expect(evidence.finite)
            #expect(evidence.bindingValid)
            #expect(evidence.processedSampleCount == frameCount)
            #expect(evidence.minimumCutoffHz >=
                    TPTAntialiasedNonlinearCoreContract.minimumCutoffHz)
            #expect(evidence.maximumCutoffHz <= sampleRate *
                    TPTAntialiasedNonlinearCoreContract.maximumCutoffFraction)
            #expect(evidence.minimumQ >=
                    TPTAntialiasedNonlinearCoreContract.minimumQ)
            #expect(evidence.maximumQ <=
                    TPTAntialiasedNonlinearCoreContract.maximumQ)
            #expect(evidence.minimumInputDrive >=
                    TPTAntialiasedNonlinearCoreContract.minimumDrive)
            #expect(evidence.maximumInputDrive <=
                    TPTAntialiasedNonlinearCoreContract.maximumDrive)
            #expect(evidence.maximumBandMix <=
                    TPTAntialiasedNonlinearCoreContract.maximumBandMix)
            #expect(evidence.inputSampleHash.count == 16)
            #expect(evidence.outputSampleHash.count == 16)
        }
    }

    @Test("Chunk boundaries preserve exact nonlinear continuation")
    func exactChunkContinuation() {
        let sampleRate = 48_000.0
        let inputs = (0..<4_096).map { frame in
            sin(2 * .pi * 173 * Double(frame) / sampleRate) * 0.72 +
                sin(2 * .pi * 2_137 * Double(frame) / sampleRate) * 0.18
        }
        let uninterrupted = render(inputs, sampleRate: sampleRate, splitAt: nil)
        let split = render(inputs, sampleRate: sampleRate, splitAt: 1_337)

        #expect(split.output == uninterrupted.output)
        #expect(split.state == uninterrupted.state)
        #expect(split.evidence == uninterrupted.evidence)
    }

    @Test("Patch boundaries and invalid samples reset bounded core state")
    func resetAndInvalidFallback() {
        var core = TPTAntialiasedNonlinearCoreState()
        var accumulator = TPTAntialiasedNonlinearCoreEvidenceAccumulator()
        _ = TPTAntialiasedNonlinearCore.process(
            input: 0.8,
            sampleRate: 48_000,
            cutoffHz: 1_200,
            resonance: 0.7,
            inputDrive: 2.2,
            outputDrive: 1.8,
            bandMix: 0.2,
            state: &core,
            evidence: &accumulator
        )
        #expect(core != TPTAntialiasedNonlinearCoreState())

        var voice = ResonantMonoState()
        voice.activePatch = .bassPulse
        voice.nonlinearCore = core
        voice.envelope = 0.8
        voice.prepare(patch: .acidThread)
        #expect(voice.activePatch == .acidThread)
        #expect(voice.nonlinearCore == TPTAntialiasedNonlinearCoreState())
        #expect(voice.envelope == 0)

        let invalid = TPTAntialiasedNonlinearCore.process(
            input: .nan,
            sampleRate: 48_000,
            cutoffHz: 1_200,
            resonance: 0.7,
            inputDrive: 2.2,
            outputDrive: 1.8,
            bandMix: 0.2,
            state: &core,
            evidence: &accumulator
        )
        #expect(invalid == 0)
        #expect(core == TPTAntialiasedNonlinearCoreState())
        #expect(!accumulator.evidence(
            sourceAssignmentCount: 1,
            sourceEventCount: 1
        ).finite)
    }

    private func render(
        _ input: [Double],
        sampleRate: Double,
        splitAt: Int?
    ) -> (
        output: [Double],
        state: TPTAntialiasedNonlinearCoreState,
        evidence: TPTAntialiasedNonlinearCoreRenderEvidence
    ) {
        var state = TPTAntialiasedNonlinearCoreState()
        var accumulator = TPTAntialiasedNonlinearCoreEvidenceAccumulator()
        var output = [Double]()
        output.reserveCapacity(input.count)
        let ranges: [Range<Int>]
        if let splitAt {
            ranges = [0..<splitAt, splitAt..<input.count]
        } else {
            ranges = [0..<input.count]
        }
        for range in ranges {
            for frame in range {
                let progress = Double(frame) / Double(max(1, input.count - 1))
                output.append(TPTAntialiasedNonlinearCore.process(
                    input: input[frame],
                    sampleRate: sampleRate,
                    cutoffHz: 180 + progress * 4_200,
                    resonance: 0.18 + progress * 0.68,
                    inputDrive: 1.1 + progress * 1.7,
                    outputDrive: 1.2 + progress * 0.9,
                    bandMix: 0.04 + progress * 0.30,
                    state: &state,
                    evidence: &accumulator
                ))
            }
        }
        return (
            output,
            state,
            accumulator.evidence(sourceAssignmentCount: 1, sourceEventCount: 1)
        )
    }

    private func magnitude(
        _ samples: [Double],
        frequency: Double,
        sampleRate: Double
    ) -> Double {
        var real = 0.0
        var imaginary = 0.0
        for (frame, sample) in samples.enumerated() {
            let phase = -2 * Double.pi * frequency * Double(frame) / sampleRate
            real += sample * cos(phase)
            imaginary += sample * sin(phase)
        }
        return 2 * hypot(real, imaginary) / Double(samples.count)
    }
}
