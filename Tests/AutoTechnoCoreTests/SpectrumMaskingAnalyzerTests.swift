import Foundation
import Testing
@testable import AutoTechnoDSP

@Suite("Spectrum masking analyzer")
struct SpectrumMaskingAnalyzerTests {
    @Test("Reusable sample filter preserves exact band-window evidence")
    func reusableFilterParity() throws {
        let sampleRate = 48_000.0
        let samples: [Float] = (0..<4_099).map { frame in
            Float(
                sin(2 * Double.pi * 93 * Double(frame) / sampleRate) * 0.2 +
                    sin(2 * Double.pi * 1_707 * Double(frame) / sampleRate) * 0.1
            )
        }
        let windows = try #require(SpectrumMaskingAnalyzer.bandEnergyWindows(
            samples,
            sampleRate: sampleRate
        ))
        var filter = try #require(MaskingBandFilter(sampleRate: sampleRate))
        var sums = Array(
            repeating: [Double](repeating: 0, count: 4),
            count: SpectrumMaskingAnalyzer.analyzedWindowCount
        )
        for (frame, sample) in samples.enumerated() {
            let processed = filter.process(Double(sample))
            let output = try #require(processed)
            let window = min(
                SpectrumMaskingAnalyzer.analyzedWindowCount - 1,
                frame * SpectrumMaskingAnalyzer.analyzedWindowCount /
                    samples.count
            )
            for band in output.values.indices {
                sums[window][band] += output.values[band] * output.values[band]
            }
        }
        for window in windows {
            for band in sums[window.index].indices {
                let expected = sums[window.index][band] /
                    Double(window.frameCount)
                #expect(window.bandMeanSquares[band] == expected)
            }
        }
    }

    @Test("Valid silence has a fixed truthful vector while malformed input is unavailable")
    func fixedShapeAndInvalidInput() {
        let silence = [Float](repeating: 0, count: 160)
        let observations = SpectrumMaskingAnalyzer.analyze(
            signals: [
                .foundation: silence,
                .percussion: silence,
                .upper: silence,
            ],
            sampleRate: 48_000
        )

        #expect(observations.count == 12)
        #expect(Set(observations.map { "\($0.firstRole.rawValue)/\($0.secondRole.rawValue)" }) == Set([
            "foundation/percussion",
            "foundation/upper",
            "percussion/upper",
        ]))
        #expect(observations.allSatisfy {
            $0.firstRole != $0.secondRole &&
                $0.analyzedWindowCount == 16 &&
                $0.activePairWindowCount == 0 &&
                $0.overlapWindowCount == 0 &&
                $0.longestOverlapRun == 0 &&
                $0.maximumOverlap == 0 &&
                !$0.isPersistent
        })

        #expect(SpectrumMaskingAnalyzer.analyze(
            signals: [.foundation: silence, .percussion: silence],
            sampleRate: 48_000
        ).isEmpty)
        #expect(SpectrumMaskingAnalyzer.analyze(
            signals: [
                .foundation: silence,
                .percussion: Array(silence.dropLast()),
                .upper: silence,
            ],
            sampleRate: 48_000
        ).isEmpty)
        var nonfinite = silence
        nonfinite[80] = .nan
        #expect(SpectrumMaskingAnalyzer.analyze(
            signals: [
                .foundation: nonfinite,
                .percussion: silence,
                .upper: silence,
            ],
            sampleRate: 48_000
        ).isEmpty)
        #expect(SpectrumMaskingAnalyzer.analyze(
            signals: [
                .foundation: silence,
                .percussion: silence,
                .upper: silence,
            ],
            sampleRate: .infinity
        ).isEmpty)
    }

    @Test("Adjacent overlap must persist while one early window and disjoint roles do not")
    func adjacentAndDisjointOverlap() throws {
        let sampleRate = 48_000.0
        let framesPerWindow = 512
        let adjacent = tone(
            sampleRate: sampleRate,
            framesPerWindow: framesPerWindow,
            activeWindows: [7, 8]
        )
        let oneWindow = tone(
            sampleRate: sampleRate,
            framesPerWindow: framesPerWindow,
            activeWindows: [7]
        )
        let silence = [Float](repeating: 0, count: adjacent.count)

        let persistent = try #require(observation(
            in: SpectrumMaskingAnalyzer.analyze(
                signals: [
                    .foundation: adjacent,
                    .percussion: silence,
                    .upper: adjacent,
                ],
                sampleRate: sampleRate
            ),
            first: .foundation,
            second: .upper,
            band: "mid"
        ))
        #expect(persistent.activePairWindowCount == 2)
        #expect(persistent.overlapWindowCount == 2)
        #expect(persistent.longestOverlapRun == 2)
        #expect(persistent.isPersistent)

        let transient = try #require(observation(
            in: SpectrumMaskingAnalyzer.analyze(
                signals: [
                    .foundation: oneWindow,
                    .percussion: silence,
                    .upper: oneWindow,
                ],
                sampleRate: sampleRate
            ),
            first: .foundation,
            second: .upper,
            band: "mid"
        ))
        #expect(transient.activePairWindowCount == 1)
        #expect(transient.overlapWindowCount == 1)
        #expect(transient.longestOverlapRun == 1)
        #expect(!transient.isPersistent)

        let earlyFoundation = tone(
            sampleRate: sampleRate,
            framesPerWindow: framesPerWindow,
            activeWindows: [2, 3]
        )
        let lateUpper = tone(
            sampleRate: sampleRate,
            framesPerWindow: framesPerWindow,
            activeWindows: [12, 13]
        )
        let disjoint = try #require(observation(
            in: SpectrumMaskingAnalyzer.analyze(
                signals: [
                    .foundation: earlyFoundation,
                    .percussion: silence,
                    .upper: lateUpper,
                ],
                sampleRate: sampleRate
            ),
            first: .foundation,
            second: .upper,
            band: "mid"
        ))
        #expect(disjoint.activePairWindowCount == 0)
        #expect(disjoint.overlapWindowCount == 0)
        #expect(!disjoint.isPersistent)
    }

    @Test("Overlap ratios preserve the strict threshold on every window")
    func strictOverlapThreshold() throws {
        let sampleRate = 48_000.0
        let framesPerWindow = 512
        let allWindows = Set(0..<SpectrumMaskingAnalyzer.analyzedWindowCount)
        let foundation = tone(
            sampleRate: sampleRate,
            framesPerWindow: framesPerWindow,
            activeWindows: allWindows
        )
        let silence = [Float](repeating: 0, count: foundation.count)

        func midBandObservation(targetOverlap: Double) throws
            -> RoleMaskingObservation {
            let upper = foundation.map {
                Float(Double($0) / sqrt(targetOverlap))
            }
            return try #require(observation(
                in: SpectrumMaskingAnalyzer.analyze(
                    signals: [
                        .foundation: foundation,
                        .percussion: silence,
                        .upper: upper,
                    ],
                    sampleRate: sampleRate
                ),
                first: .foundation,
                second: .upper,
                band: "mid"
            ))
        }

        let below = try midBandObservation(targetOverlap: 0.37)
        let above = try midBandObservation(targetOverlap: 0.39)

        #expect(below.activePairWindowCount == 16)
        #expect(above.activePairWindowCount == 16)
        #expect(abs(below.maximumOverlap - 0.37) < 0.000_01)
        #expect(abs(above.maximumOverlap - 0.39) < 0.000_01)
        #expect(below.overlapWindowCount == 0)
        #expect(below.longestOverlapRun == 0)
        #expect(above.overlapWindowCount == 16)
        #expect(above.longestOverlapRun == 16)
    }

    @Test("Equivalent physical-time fixtures retain masking classification across rates")
    func rateNormalizedClassification() {
        func observations(sampleRate: Double) -> [RoleMaskingObservation] {
            let frameCount = Int((sampleRate * 0.64).rounded())
            let signal: [Float] = (0..<frameCount).map { frame in
                let window = min(15, frame * 16 / frameCount)
                guard window == 14 || window == 15 else { return 0 }
                return Float(sin(2 * Double.pi * 1_000 * Double(frame) / sampleRate) * 0.22)
            }
            return SpectrumMaskingAnalyzer.analyze(
                signals: [
                    .foundation: signal,
                    .percussion: [Float](repeating: 0, count: frameCount),
                    .upper: signal,
                ],
                sampleRate: sampleRate
            )
        }
        func persistentKeys(_ observations: [RoleMaskingObservation]) -> Set<String> {
            Set(observations.filter(\.isPersistent).map {
                "\($0.firstRole.rawValue)/\($0.secondRole.rawValue)/\($0.band.name)"
            })
        }

        let at44 = observations(sampleRate: 44_100)
        let at48 = observations(sampleRate: 48_000)
        let at96 = observations(sampleRate: 96_000)
        #expect(at44.count == 12 && at48.count == 12 && at96.count == 12)
        #expect(persistentKeys(at44) == persistentKeys(at48))
        #expect(persistentKeys(at48) == persistentKeys(at96))
        #expect(persistentKeys(at48).contains("foundation/upper/mid"))
        #expect(at48 == observations(sampleRate: 48_000))
    }

    @Test("AT-0039 mechanistic masking controls separate on held-out tone frequencies")
    func mechanisticCalibrationControls() throws {
        struct Row: Codable {
            let split: String
            let label: String
            let sampleRate: Int
            let frequencyHz: Double
            let activePairWindows: Int
            let overlapWindows: Int
            let maximumOverlap: Double
            let longestOverlapRun: Int
            let predictedConflict: Bool
        }

        // Frequencies and labels are fixed before calling the analyzer. The
        // holdout frequencies are never used to define the classifier.
        let splits: [(String, [Double])] = [
            ("development", [48, 87]),
            ("held-out-frequency", [61, 105]),
        ]
        var rows: [Row] = []

        func tone(
            frequencyHz: Double,
            sampleRate: Double,
            frameCount: Int,
            framesPerWindow: Int,
            activeWindows: Set<Int>
        ) throws -> [Float] {
            var samples = try DeterministicSignalFixtures.sine(
                frameCount: frameCount,
                sampleRate: sampleRate,
                frequencyHz: frequencyHz,
                amplitude: 0.2,
                phaseRadians: .pi / 2
            )
            for frame in samples.indices
            where !activeWindows.contains(frame / framesPerWindow) {
                samples[frame] = 0
            }
            return samples
        }

        for sampleRate in [44_100.0, 48_000.0] {
            let framesPerWindow = Int((sampleRate * 0.04).rounded())
            let frameCount = framesPerWindow * SpectrumMaskingAnalyzer.analyzedWindowCount
            let silence = try DeterministicSignalFixtures.silence(frameCount: frameCount)

            for (split, frequencies) in splits {
                for frequency in frequencies {
                    let shared = try DeterministicSignalFixtures.sine(
                        frameCount: frameCount,
                        sampleRate: sampleRate,
                        frequencyHz: frequency,
                        amplitude: 0.2,
                        phaseRadians: .pi / 2
                    )
                    let disjointFirst = try tone(
                        frequencyHz: frequency,
                        sampleRate: sampleRate,
                        frameCount: frameCount,
                        framesPerWindow: framesPerWindow,
                        activeWindows: Set(0..<8)
                    )
                    let disjointSecond = try tone(
                        frequencyHz: frequency,
                        sampleRate: sampleRate,
                        frameCount: frameCount,
                        framesPerWindow: framesPerWindow,
                        activeWindows: Set(8..<16)
                    )

                    for (label, foundation, percussion, expectedConflict) in [
                        ("shared-sub-band-time", shared, shared, true),
                        ("time-disjoint-same-tone", disjointFirst, disjointSecond, false),
                    ] {
                        let observations = SpectrumMaskingAnalyzer.analyze(
                            signals: [
                                .foundation: foundation,
                                .percussion: percussion,
                                .upper: silence,
                            ],
                            sampleRate: sampleRate
                        )
                        let sub = try #require(observation(
                            in: observations,
                            first: .foundation,
                            second: .percussion,
                            band: "sub"
                        ))
                        let predictedConflict = sub.overlapWindowCount >= 2 &&
                            sub.maximumOverlap > SpectrumMaskingAnalyzer.overlapThreshold
                        rows.append(Row(
                            split: split,
                            label: label,
                            sampleRate: Int(sampleRate),
                            frequencyHz: frequency,
                            activePairWindows: sub.activePairWindowCount,
                            overlapWindows: sub.overlapWindowCount,
                            maximumOverlap: sub.maximumOverlap,
                            longestOverlapRun: sub.longestOverlapRun,
                            predictedConflict: predictedConflict
                        ))
                        #expect(predictedConflict == expectedConflict)
                        #expect(observations == SpectrumMaskingAnalyzer.analyze(
                            signals: [
                                .foundation: foundation,
                                .percussion: percussion,
                                .upper: silence,
                            ],
                            sampleRate: sampleRate
                        ))
                    }
                }
            }

        }

        let development = rows.filter { $0.split == "development" }
        let holdout = rows.filter { $0.split == "held-out-frequency" }
        #expect(development.count == 8)
        #expect(holdout.count == 8)
        #expect(development.filter(\.predictedConflict).count == 4)
        #expect(holdout.filter(\.predictedConflict).count == 4)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let report = try encoder.encode(rows)
        FileHandle.standardOutput.write(report)
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    private func tone(
        sampleRate: Double,
        framesPerWindow: Int,
        activeWindows: Set<Int>
    ) -> [Float] {
        let frameCount = framesPerWindow * 16
        return (0..<frameCount).map { frame in
            guard activeWindows.contains(frame / framesPerWindow) else { return 0 }
            return Float(sin(2 * Double.pi * 1_000 * Double(frame) / sampleRate) * 0.22)
        }
    }

    private func observation(
        in observations: [RoleMaskingObservation],
        first: MaskingRole,
        second: MaskingRole,
        band: String
    ) -> RoleMaskingObservation? {
        observations.first {
            $0.firstRole == first && $0.secondRole == second && $0.band.name == band
        }
    }
}
