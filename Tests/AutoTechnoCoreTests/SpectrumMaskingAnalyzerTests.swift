import Testing
import Foundation
@testable import AutoTechnoDSP

@Suite("Spectrum masking analyzer")
struct SpectrumMaskingAnalyzerTests {
    @Test("isolated and silent roles do not create masking")
    func isolatedRoles() {
        let silence = [Float](repeating: 0, count: 256)
        let kick: [Float] = (0..<256).map { index in
            Float(sin(Double(index) * 2.0 * Double.pi * 60.0 / 44_100.0))
        }
        let decisions = SpectrumMaskingAnalyzer.analyze(
            signals: [.kickBass: kick, .percussion: silence, .synth: silence, .texture: silence],
            sampleRate: 44_100)
        #expect(decisions.isEmpty)
    }

    @Test("persistent overlap produces bounded upper-role cuts")
    func overlapIsBounded() {
        let signal: [Float] = (0..<256).map { index in
            Float(sin(Double(index) * 2.0 * Double.pi * 220.0 / 44_100.0))
        }
        let decisions = SpectrumMaskingAnalyzer.analyze(
            signals: [.kickBass: signal, .synth: signal, .percussion: [], .texture: []],
            sampleRate: 44_100)
        #expect(decisions.contains { decision in
            decision.protectedRole == MaskingRole.kickBass && decision.yieldingRole == MaskingRole.synth
        })
        #expect(decisions.allSatisfy { $0.cut <= 0.24 && $0.cut > 0 })
    }

    @Test("analysis is deterministic")
    func deterministic() {
        let signal: [Float] = (0..<256).map { index in
            Float(sin(Double(index) * 2.0 * Double.pi * 440.0 / 44_100.0))
        }
        let inputs: [MaskingRole: [Float]] = [.kickBass: signal, .synth: signal]
        #expect(SpectrumMaskingAnalyzer.analyze(signals: inputs, sampleRate: 44_100) ==
                SpectrumMaskingAnalyzer.analyze(signals: inputs, sampleRate: 44_100))
    }
}
