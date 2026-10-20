import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Physical-time voice DC blocking")
struct VoiceDCBlockingTests {
    @Test("The authored reference route is exact and invalid coefficients refuse")
    func referenceRouteAndInvalidParameters() throws {
        for reference in [0.995, 0.994] {
            let stage = try #require(VoiceDCBlocking(referencePole: reference, sampleRate: 48_000))
            #expect(stage.pole == reference && stage.differenceGain == 1)
            var priorInput = 0.0, actualPrior = 0.0, referencePrior = 0.0
            var exact = true
            for index in 0..<4_096 {
                let input = sin(Double(index) * 0.071) + (index.isMultiple(of: 37) ? 0.25 : 0)
                let actual = stage.process(input, previousInput: priorInput, previousOutput: actualPrior)
                let expected = input - priorInput + reference * referencePrior
                exact = exact && actual.bitPattern == expected.bitPattern
                priorInput = input; actualPrior = actual; referencePrior = expected
            }
            #expect(exact)
        }
        for rate in [0.0, -1, .infinity, -.infinity, .nan] {
            #expect(VoiceDCBlocking(referencePole: 0.995, sampleRate: rate) == nil)
        }
        for reference in [0.0, -1, 1, .infinity, .nan] {
            #expect(VoiceDCBlocking(referencePole: reference, sampleRate: 48_000) == nil)
        }
    }

    @Test("DC carry decays in physical time independently at both native rates")
    func physicalTimeCarry() throws {
        for reference in [0.995, 0.994] {
            for rate in [44_100.0, 48_000.0] {
                let stage = try #require(VoiceDCBlocking(referencePole: reference, sampleRate: rate))
                for seconds in [0.001, 0.005, 0.01, 0.025, 0.1] {
                    let count = Int((rate * seconds).rounded())
                    var residual = 1.0
                    for _ in 0..<count {
                        residual = stage.process(0, previousInput: 0, previousOutput: residual)
                    }
                    let expected = pow(reference, 48_000 * Double(count) / rate)
                    #expect(abs(residual - expected) <= 1e-12 + 1e-10 * abs(expected))
                    if rate == 44_100 && seconds <= 0.025 {
                        #expect(abs(pow(reference, Double(count)) - expected) > 1e-4)
                    }
                }
            }
        }
    }

    @Test("Actual tone response matches an independent transfer oracle and reduces each rate error")
    func transferMatchesAnalyticResponse() throws {
        for reference in [0.995, 0.994] {
            for frequency in [27.5, 55, 110, 220, 440, 880] {
                var measured: [Double: Double] = [:]
                for rate in [44_100.0, 48_000.0] {
                    let stage = try #require(VoiceDCBlocking(referencePole: reference, sampleRate: rate))
                    var previousInput = 0.0, previousOutput = 0.0, energy = 0.0
                    let settleCount = Int(rate * 2), windowCount = Int(rate * 2)
                    for index in 0..<(settleCount + windowCount) {
                        let input = sin(2 * Double.pi * frequency * Double(index) / rate)
                        let output = stage.process(input, previousInput: previousInput,
                                                   previousOutput: previousOutput)
                        previousInput = input; previousOutput = output
                        if index >= settleCount { energy += output * output }
                    }
                    let gain = sqrt(2 * energy / Double(windowCount))
                    let cosine = cos(2 * Double.pi * frequency / rate)
                    let expected = stage.differenceGain * sqrt((2 - 2 * cosine) /
                        (1 + stage.pole * stage.pole - 2 * stage.pole * cosine))
                    #expect(abs(gain - expected) <= 1e-12 + 1e-9 * abs(expected))
                    measured[rate] = gain
                }
                func legacyGain(rate: Double) -> Double {
                    let cosine = cos(2 * Double.pi * frequency / rate)
                    return sqrt((2 - 2 * cosine) /
                        (1 + reference * reference - 2 * reference * cosine))
                }
                let lower = try #require(measured[44_100]), upper = try #require(measured[48_000])
                #expect(abs(lower - upper) < abs(legacyGain(rate: 44_100) - legacyGain(rate: 48_000)))
            }
        }
    }

    @Test("Caller-owned continuation preserves chunking, exact zero and nonfinite refusal evidence")
    func streamPartitionAndNonfinitePropagation() throws {
        for rate in [44_100.0, 48_000.0] {
            let stage = try #require(VoiceDCBlocking(referencePole: 0.995, sampleRate: rate))
            #expect(stage.process(0, previousInput: 0, previousOutput: 0) == 0)
            let invalid = stage.process(.nan, previousInput: 0, previousOutput: 0)
            #expect(invalid.isNaN)
            let input = (0..<512).map { sin(Double($0) * 0.13) }
            func run(boundary: Int) -> [Double] {
                var previousInput = 0.0, previousOutput = 0.0, output: [Double] = []
                for range in [0..<boundary, boundary..<input.count] {
                    for index in range {
                        let value = stage.process(input[index], previousInput: previousInput,
                                                  previousOutput: previousOutput)
                        output.append(value); previousInput = input[index]; previousOutput = value
                    }
                }
                return output
            }
            #expect(run(boundary: 0) == run(boundary: 73))
            #expect(run(boundary: 512) == run(boundary: 73))
        }
    }
}
