import AutoTechnoDSP
import Foundation
import Testing

@Suite("Professional Evidence v29 BS.1770")
struct BS1770AudioEvidenceTests {
    @Test("48 kHz K-weighting reproduces the BS.1770-5 coefficient tables")
    func referenceCoefficients() throws {
        let filters = try #require(
            BS1770AudioEvidence.kWeightingCoefficients(sampleRate: 48_000)
        )
        #expect(abs(filters.shelf.b0 - 1.53512485958697) < 1e-14)
        #expect(abs(filters.shelf.b1 - -2.69169618940638) < 1e-14)
        #expect(abs(filters.shelf.b2 - 1.19839281085285) < 1e-14)
        #expect(abs(filters.shelf.a1 - -1.69065929318241) < 1e-14)
        #expect(abs(filters.shelf.a2 - 0.73248077421585) < 1e-14)
        #expect(filters.highPass.b0 == 1)
        #expect(filters.highPass.b1 == -2)
        #expect(filters.highPass.b2 == 1)
        #expect(abs(filters.highPass.a1 - -1.99004745483398) < 1e-14)
        #expect(abs(filters.highPass.a2 - 0.99007225036621) < 1e-14)
    }

    @Test("997 Hz reference tone and channel summation follow BS.1770-5")
    func referenceToneAndStereoSummation() {
        let sampleRate = 48_000.0
        let tone = sine(
            frequency: 997,
            amplitude: 1,
            duration: 4,
            sampleRate: sampleRate
        )
        let silence = [Float](repeating: 0, count: tone.count)
        let mono = BS1770LoudnessMeasurement(
            left: tone,
            right: silence,
            sampleRate: sampleRate
        )
        let dualMono = BS1770LoudnessMeasurement(
            left: tone,
            right: tone,
            sampleRate: sampleRate
        )

        #expect(abs(mono.integratedLoudness - -3.01) < 0.03)
        #expect(abs(
            dualMono.integratedLoudness - mono.integratedLoudness - 3.01029995664
        ) < 0.000_1)
        #expect(mono.momentaryBlockCount == 37)
        #expect(mono.absoluteGatedBlockCount == mono.momentaryBlockCount)
        #expect(mono.relativeGatedBlockCount == mono.momentaryBlockCount)
    }

    @Test("Loudness evidence is physical-time equivalent across production rates")
    func representativeRateEquivalence() {
        var measurements: [BS1770LoudnessMeasurement] = []
        for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
            let tone = sine(
                frequency: 997,
                amplitude: 0.25,
                duration: 4,
                sampleRate: sampleRate
            )
            let silence = [Float](repeating: 0, count: tone.count)
            measurements.append(BS1770LoudnessMeasurement(
                left: tone,
                right: silence,
                sampleRate: sampleRate
            ))
        }
        for pair in zip(measurements, measurements.dropFirst()) {
            #expect(abs(
                pair.0.integratedLoudness - pair.1.integratedLoudness
            ) < 0.02)
            #expect(pair.0.momentaryBlockCount == pair.1.momentaryBlockCount)
            #expect(pair.0.shortTermBlockCount == pair.1.shortTermBlockCount)
        }
    }

    @Test("Absolute and relative gates exclude quiet programme blocks")
    func twoStageGating() {
        let sampleRate = 48_000.0
        let loud = sine(
            frequency: 997,
            amplitude: 0.1,
            duration: 4,
            sampleRate: sampleRate
        )
        let quiet = sine(
            frequency: 997,
            amplitude: 0.001,
            duration: 4,
            sampleRate: sampleRate
        )
        let programme = loud + quiet
        let silence = [Float](repeating: 0, count: programme.count)
        let measurement = BS1770LoudnessMeasurement(
            left: programme,
            right: silence,
            sampleRate: sampleRate
        )

        #expect(measurement.absoluteGatedBlockCount ==
                measurement.momentaryBlockCount)
        #expect(measurement.relativeGatedBlockCount <
                measurement.absoluteGatedBlockCount)
        #expect(measurement.relativeGatedBlockCount > 30)
        #expect(abs(measurement.integratedLoudness - -23.01) < 0.5)
    }

    @Test("Annex 2 FIR exposes an inter-sample peak missed by sample peak")
    func annex2TruePeak() throws {
        let samples = (0..<4_096).map { frame in
            Float(0.8 * sin(Double.pi * 0.5 * Double(frame) + Double.pi / 4))
        }
        let samplePeak = samples.reduce(0.0) { max($0, abs(Double($1))) }
        let truePeak = try #require(BS1770AudioEvidence.truePeak(samples))

        #expect(samplePeak < 0.57)
        #expect(truePeak > 0.77)
        #expect(truePeak > samplePeak + 0.20)
        #expect(abs(
            BS1770AudioEvidence.decibelsTruePeak(amplitude: truePeak) -
                20 * log10(truePeak)
        ) < 1e-12)
    }

    @Test("Annex 2 true peak remains level-consistent across production rates")
    func truePeakRateEquivalence() throws {
        var peaks: [Double] = []
        for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
            let signal = (0..<Int(sampleRate * 0.25)).map { frame in
                Float(0.8 * sin(
                    2 * Double.pi * 15_000 * Double(frame) / sampleRate + 0.37
                ))
            }
            peaks.append(try #require(BS1770AudioEvidence.truePeak(signal)))
        }
        #expect(peaks.allSatisfy { abs($0 - 0.8) < 0.03 })
        #expect((peaks.max() ?? 0) - (peaks.min() ?? 0) < 0.02)
    }

    @Test("Silence, incomplete windows, non-finite PCM, and cancellation stay truthful")
    func adversarialInputs() {
        let silence = [Float](repeating: 0, count: 48_000)
        let silent = BS1770LoudnessMeasurement(
            left: silence,
            right: silence,
            sampleRate: 48_000
        )
        #expect(silent.integratedLoudness == -120)
        #expect(silent.absoluteGatedBlockCount == 0)
        #expect(silent.relativeGatedBlockCount == 0)

        let short = [Float](repeating: 0.5, count: 19_199)
        let incomplete = BS1770LoudnessMeasurement(
            left: short,
            right: short,
            sampleRate: 48_000
        )
        #expect(incomplete.momentaryBlockCount == 0)
        #expect(incomplete.integratedLoudness == -120)

        var invalid = silence
        invalid[24_000] = .nan
        let nonFinite = BS1770LoudnessMeasurement(
            left: invalid,
            right: silence,
            sampleRate: 48_000
        )
        #expect(!nonFinite.integratedLoudness.isFinite)
        #expect(BS1770AudioEvidence.truePeak(invalid)?.isNaN == true)
        #expect(BS1770LoudnessMeasurement(
            left: silence,
            right: silence,
            sampleRate: 48_000,
            cancellationRequested: { true }
        ) == nil)
        #expect(BS1770AudioEvidence.truePeak(
            silence,
            cancellationRequested: { true }
        ) == nil)
    }

    private func sine(
        frequency: Double,
        amplitude: Double,
        duration: Double,
        sampleRate: Double
    ) -> [Float] {
        (0..<Int((duration * sampleRate).rounded())).map { frame in
            Float(amplitude * sin(
                2 * Double.pi * frequency * Double(frame) / sampleRate
            ))
        }
    }
}
