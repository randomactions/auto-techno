@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Physical-time final-mix response")
struct MixControlResponseTests {
    @Test("The authored mix route retains exact literal coefficients")
    func exactAuthoredRoute() {
        let c = MixControlResponse(sampleRate: 48_000)
        #expect(c.kickRelease == 0.992)
        #expect([c.upperLow, c.upperMid, c.midDetector, c.upperTone,
                 c.highDetector, c.centerLow] == [0.012, 0.055, 0.014, 0.11, 0.018, 0.045])
        for rate in [8_000.0, 44_100, 48_000, 96_000, 192_000] {
            let response = MixControlResponse(sampleRate: rate)
            #expect(response.kickRelease > 0 && response.kickRelease < 1)
            #expect(coefficients(response).allSatisfy { $0 > 0 && $0 < 1 && $0.isFinite })
        }
    }

    @Test("Mix response obeys independent physical-time step and release oracles")
    func physicalStepAndRelease() {
        for rate in [44_100.0, 48_000] {
            let c = MixControlResponse(sampleRate: rate)
            for seconds in [0.001, 0.005, 0.01, 0.025, 0.1] {
                let count = Int((rate * seconds).rounded())
                let exponent = 48_000 * Double(count) / rate
                var residual = 1.0
                for _ in 0..<count { residual *= c.kickRelease }
                #expect(abs(residual - pow(0.992, exponent)) <= accumulationBound(count))
                for (authored, actual) in zip([0.012, 0.055, 0.014, 0.11, 0.018, 0.045], coefficients(c)) {
                    var value = 0.0
                    for _ in 0..<count { value += (1 - value) * actual }
                    let expected = 1 - pow(1 - authored, exponent)
                    #expect(abs(value - expected) <= accumulationBound(count))
                    if rate == 44_100 && seconds == 0.001 {
                        let unscaled = 1 - pow(1 - authored, Double(count))
                        #expect(abs(unscaled - expected) > 1e-5)
                    }
                }
            }
        }
    }

    @Test("Mix filter tone response follows its independent transfer at both rates")
    func independentToneTransfer() {
        for (index, authored) in [0.012, 0.055, 0.014, 0.11, 0.018, 0.045].enumerated() {
            for frequency in [27.5, 55, 110, 220, 440, 880, 1_760, 3_520] {
                var measured: [Double: Double] = [:]
                for rate in [44_100.0, 48_000] {
                    let alpha = coefficients(MixControlResponse(sampleRate: rate))[index]
                    var state = 0.0, energy = 0.0
                    let settle = Int(rate), window = Int(rate * 2)
                    for frame in 0..<(settle + window) {
                        let input = sin(2 * Double.pi * frequency * Double(frame) / rate)
                        state += (input - state) * alpha
                        if frame >= settle { energy += state * state }
                    }
                    let gain = sqrt(2 * energy / Double(window))
                    let pole = 1 - alpha
                    let expected = alpha / sqrt(1 + pole * pole -
                        2 * pole * cos(2 * Double.pi * frequency / rate))
                    #expect(abs(gain - expected) <= 1e-12 + 1e-9 * abs(expected))
                    measured[rate] = gain
                }
                func oldGain(_ rate: Double) -> Double {
                    let pole = 1 - authored
                    return authored / sqrt(1 + pole * pole -
                        2 * pole * cos(2 * Double.pi * frequency / rate))
                }
                #expect(abs(measured[44_100]! - measured[48_000]!) <
                    abs(oldGain(44_100) - oldGain(48_000)))
            }
        }
    }

    private func coefficients(_ c: MixControlResponse) -> [Double] {
        [c.upperLow, c.upperMid, c.midDetector, c.upperTone, c.highDetector, c.centerLow]
    }

    private func accumulationBound(_ count: Int) -> Double {
        // Conservative gamma(n) forward-error budget for bounded unit-input
        // recurrences, including coefficient/exponential rounding. Fixed before
        // native output; it is not an audio-quality or holdout tolerance.
        let error = Double(64 * count + 64) * Double.ulpOfOne
        return 1e-12 + error / (1 - error)
    }
}
