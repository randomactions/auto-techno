import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Source-terminal de-clicking")
struct SourceTerminalDeclickTests {
    @Test("Raised-cosine release preserves the first 8 ms and reaches exact zero")
    func physicalTimeGeometry() {
        for sampleRate in [44_100.0, 48_000.0] {
            for (voice, duration, fadeSeconds) in [
                (EnsembleVoice.kick, 0.32, 0.004),
                (.rumble, 0.68, 0.004),
                (.clap, 0.16, 0.002),
                (.openHat, 0.19, 0.002),
                (.metallic, 0.065, 0.002),
            ] {
                let frameCount = Int(sampleRate * duration)
                let attackFrames = SourceTerminalDeclickContract
                    .attackFrameCount(
                        sampleRate: sampleRate,
                        renderedFrameCount: frameCount
                    )
                let fadeFrames = SourceTerminalDeclickContract.fadeFrameCount(
                    voice: voice,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount
                )
                let multipliers = (0..<frameCount).map { frame in
                    SourceTerminalDeclickContract.multiplier(
                        voice: voice,
                        frame: frame,
                        renderedFrameCount: frameCount,
                        sampleRate: sampleRate
                    )
                }

                #expect(attackFrames == Int((sampleRate * 0.008).rounded()))
                #expect(fadeFrames == Int((sampleRate * fadeSeconds).rounded()))
                #expect(multipliers.prefix(attackFrames).allSatisfy { $0 == 1 })
                #expect(multipliers[frameCount - fadeFrames - 1] == 1)
                #expect(multipliers[frameCount - fadeFrames] == 1)
                #expect(multipliers.last?.bitPattern == 0)
                #expect(zip(multipliers, multipliers.dropFirst()).allSatisfy {
                    $0 >= $1
                })
                #expect(multipliers.allSatisfy {
                    $0.isFinite && $0 >= 0 && $0 <= 1
                })
            }
        }
    }

    @Test("Event-local evidence proves exact attack identity and zero terminal delta")
    func eventEvidence() {
        for sampleRate in [44_100.0, 48_000.0] {
            for (index, voice) in [
                EnsembleVoice.kick,
                .rumble,
                .clap,
                .openHat,
                .metallic,
            ].enumerated() {
                let frameCount = Int(sampleRate * 0.08)
                var evidence = SourceTerminalDeclickEvidenceAccumulator(
                    scoreEventIndex: index,
                    voice: voice,
                    step: index * 2,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount
                )
                for frame in 0..<frameCount {
                    let source = Float(0.2 + 0.1 *
                        sin(Double(frame) * 0.017))
                    let rendered = SourceTerminalDeclickContract.process(
                        sample: source,
                        voice: voice,
                        frame: frame,
                        renderedFrameCount: frameCount,
                        sampleRate: sampleRate
                    )
                    evidence.append(
                        frame: frame,
                        preFade: source,
                        rendered: rendered
                    )
                }

                let result = evidence.evidence
                #expect(result.isComplete(sampleRate: sampleRate))
                #expect(!result.isComplete(sampleRate: sampleRate * 0.5))
                #expect(result.preFadeAttackSampleHash ==
                        result.renderedAttackSampleHash)
                #expect(result.preFadeLastSampleBitPattern != 0)
                #expect(result.renderedLastSampleBitPattern == 0)
                #expect(result.preFadeTerminalDelta > 0)
                #expect(result.renderedTerminalDelta.bitPattern == 0)
                #expect(result.changedSampleCount == result.fadeFrameCount - 1)
            }
        }
    }

    @Test("AT-0039 rumble support distinguishes bar clipping from unauthorized shortening")
    func algorithmicRumbleDurationFaults() throws {
        // Freeze support before PCM: the existing source lasts 17/25 second,
        // clipped only by the original destination boundary. Roots/rates share
        // one constructor and cannot supply population uncertainty.
        var rows: [[String: Any]] = []
        for (seed, split) in [(UInt64(1), "development"), (UInt64(6011), "held-out-root")] {
            for rate in [44_100.0, 48_000.0] {
                let barFrames = Int((240.0 / 130.0 * rate).rounded())
                let naturalFrames = Int(rate) * 17 / 25
                for step in [0, 15] {
                    let start = Int((Double(step) * Double(barFrames) / 16).rounded())
                    let expectedFrames = min(naturalFrames, barFrames - start)
                    var reference = [Float](repeating: 0, count: barFrames)
                    var referenceMeasurement = reference
                    let referenceEvidence = try #require(VoiceRenderer.rumble(&reference,
                        measurement: &referenceMeasurement, scoreEventIndex: 0, start: start,
                        sampleRate: rate, level: 0.072, seed: seed, step: step))
                    #expect(reference == referenceMeasurement)
                    #expect(referenceEvidence.renderedFrameCount == expectedFrames)
                    for shortened in [false, true] {
                        let suppliedFrames = shortened ? start + expectedFrames / 2 : barFrames
                        var actual = [Float](repeating: 0, count: suppliedFrames)
                        var measurement = actual
                        let evidence = try #require(VoiceRenderer.rumble(&actual,
                            measurement: &measurement, scoreEventIndex: 0, start: start,
                            sampleRate: rate, level: 0.072, seed: seed, step: step))
                        #expect(actual == measurement)
                        let declickComplete = evidence.isComplete(sampleRate: rate)
                        let supportBinding = evidence.renderedFrameCount == expectedFrames
                        #expect(declickComplete) // Valid de-clicking does not prove duration.
                        #expect(supportBinding == !shortened)
                        let suppliedSupport = min(naturalFrames, suppliedFrames - start)
                        #expect(evidence.renderedFrameCount == suppliedSupport)
                        // The fault is applied before canonical rendering. Zero
                        // extension only aligns source outputs for comparison;
                        // it is never used as a nonlinear-mix counterfactual.
                        let aligned = actual + [Float](repeating: 0, count: barFrames - actual.count)
                        let protectedEnd = start + evidence.renderedFrameCount - evidence.fadeFrameCount
                        #expect(Array(aligned.prefix(protectedEnd)) == Array(reference.prefix(protectedEnd)))
                        let energy = zip(aligned, reference).reduce(0.0) {
                            let delta = Double($1.0) - Double($1.1)
                            return $0 + delta * delta
                        }
                        let errorRMS = sqrt(energy / Double(barFrames))
                        if shortened {
                            #expect(aligned != reference && errorRMS > 0)
                            #expect(reference.dropFirst(suppliedFrames).contains { $0 != 0 })
                        } else {
                            #expect(aligned == reference && errorRMS == 0)
                            #expect(evidence == referenceEvidence)
                        }
                        var replay = [Float](repeating: 0, count: suppliedFrames)
                        var replayMeasurement = replay
                        let replayEvidence = VoiceRenderer.rumble(&replay,
                            measurement: &replayMeasurement, scoreEventIndex: 0, start: start,
                            sampleRate: rate, level: 0.072, seed: seed, step: step)
                        #expect(replay == actual && replayMeasurement == measurement && replayEvidence == evidence)
                        rows.append(["rootSeed": seed, "split": split, "sampleRate": Int(rate),
                            "step": step, "scenario": shortened ? "unauthorized-shortening" : "original-support",
                            "originalBarFrames": barFrames, "eventStartFrame": start,
                            "naturalFrames": naturalFrames, "expectedFrames": expectedFrames,
                            "suppliedBufferFrames": suppliedFrames, "renderedFrames": evidence.renderedFrameCount,
                            "declickComplete": declickComplete, "expectedSupportBinding": !shortened,
                            "observedSupportBinding": supportBinding, "sampleErrorRMS": errorRMS,
                            "actualAlignedSampleHash": ExactPCMFingerprint.mono(aligned),
                            "referenceSampleHash": ExactPCMFingerprint.mono(reference), "replayExact": replay == actual])
                    }
                }
            }
        }
        #expect(rows.count == 16)
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: [
            "schema": "autotechno-rumble-duration-fault-component.v1",
            "scope": "canonical-rumble-source-support-with-original-destination-binding",
            "qualification": "unavailable",
            "unavailable": ["full-prepared-transaction", "nonlinear-full-mix",
                "perceptual-quality", "independent-constructor-holdout", "population-error-intervals"],
            "rows": rows
        ], options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("Unsupported voices remain bit-exact")
    func unsupportedVoiceIdentity() {
        let samples: [Float] = [
            0,
            Float(bitPattern: 0x8000_0000),
            0.25,
            -0.75,
        ]
        for (frame, sample) in samples.enumerated() {
            let output = SourceTerminalDeclickContract.process(
                sample: sample,
                voice: .bass,
                frame: frame,
                renderedFrameCount: samples.count,
                sampleRate: 48_000
            )
            #expect(output.bitPattern == sample.bitPattern)
        }
    }
}
