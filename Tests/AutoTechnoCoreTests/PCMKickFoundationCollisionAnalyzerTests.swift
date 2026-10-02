import Foundation
import Testing
@testable import AutoTechnoDSP

@Suite("PCM kick/foundation collision evidence")
struct PCMKickFoundationCollisionAnalyzerTests {
    @Test("AT-0039 swept-kick and enveloped-bass probe retains counterexamples")
    func sweptKickBassMechanisticControls() throws {
        struct Row: Codable {
            let split: String
            let label: String
            let sampleRate: Int
            let bassFrequencyHz: Double
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
            let expectedConflict: Bool
            let predictedLowBandConflict: Bool
        }

        let splits: [(String, [Double])] = [
            ("development", [48, 84]),
            ("held-out-frequency", [60, 99]),
        ]
        var rows: [Row] = []

        for sampleRate in [44_100, 48_000] {
            let fixture = makeFixture(sampleRate: sampleRate, step: 4)
            let kickDuration = Int((fixture.sampleRate * 0.18).rounded())
            let analysisDuration = fixture.analysisEnd - fixture.onset

            for (split, pitches) in splits {
                for pitch in pitches {
                    let kick = try DeterministicSignalFixtures.kickHit(
                        frameCount: fixture.barFrames,
                        sampleRate: fixture.sampleRate,
                        onsetFrame: fixture.onset,
                        amplitude: 0.24,
                        decayFrames: kickDuration
                    )
                    let bassOnsets = [
                        ("shared-low-band-time", fixture.onset, true),
                        ("bass-after-kick-window", fixture.onset + analysisDuration + 1, false),
                    ]

                    for (label, bassOnset, expectedConflict) in bassOnsets {
                        let bass = try DeterministicSignalFixtures.bassNote(
                            frameCount: fixture.barFrames,
                            sampleRate: fixture.sampleRate,
                            onsetFrame: bassOnset,
                            durationFrames: kickDuration,
                            frequencyHz: pitch,
                            amplitude: 0.24
                        )
                        let event = try #require(try available(analyze(
                            kick: kick,
                            foundation: bass,
                            fixture: fixture
                        )).events.first)
                        let predictedConflict = event.lowBandOverlapWindowCount > 0
                        rows.append(Row(
                            split: split,
                            label: label,
                            sampleRate: sampleRate,
                            bassFrequencyHz: pitch,
                            collisionClass: event.collisionClass.rawValue,
                            temporalOverlapWindows: event.temporalOverlapWindowCount,
                            lowBandOverlapWindows: event.lowBandOverlapWindowCount,
                            maximumSubBandSimilarity: event.maximumSubBandSimilarity,
                            expectedConflict: expectedConflict,
                            predictedLowBandConflict: predictedConflict
                        ))
                        #expect(event.finite)
                        #expect(event.maximumSubBandSimilarity.isFinite)
                    }
                }
            }
        }

        let development = rows.filter { $0.split == "development" }
        let holdout = rows.filter { $0.split == "held-out-frequency" }
        #expect(development.count == 8)
        #expect(holdout.count == 8)
        let shared = rows.filter(\.expectedConflict)
        let separated = rows.filter { !$0.expectedConflict }
        #expect(shared.count == 8)
        #expect(shared.filter(\.predictedLowBandConflict).count == 3)
        #expect(separated.count == 8)
        #expect(separated.filter(\.predictedLowBandConflict).count == 0)
        #expect(holdout.filter { $0.expectedConflict && $0.predictedLowBandConflict }.isEmpty)
        #expect(development.filter { $0.expectedConflict && $0.predictedLowBandConflict }.count == 3)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 composed role-separated loops retain onset-bound evidence")
    func composedLoopMechanisticControls() throws {
        struct Row: Codable {
            let sampleRate: Int
            let bassFrequencyHz: Double
            let bassStep: Int
            let expectedTemporalConflict: Bool
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
        }

        var rows: [Row] = []
        for sampleRate in [44_100.0, 48_000.0] {
            for bassFrequencyHz in [55.0, 90.0] {
                for bassStep in [4, 8] {
                    let loop = try DeterministicSignalFixtures.roleSeparatedLoop(
                        bars: 1,
                        sampleRate: sampleRate,
                        tempoBPM: 130,
                        kickSteps: [4],
                        bassSteps: [bassStep],
                        hatSteps: [],
                        bassFrequencyHz: bassFrequencyHz
                    )
                    let kick = try #require(loop.tracks[.kick])
                    let bass = try #require(loop.tracks[.bass])
                    let kickOnset = try #require(kick.eventOnsets.first)
                    let event = PCMKickFoundationEventInput(
                        id: "role-separated-loop-kick-step-4",
                        bar: 0,
                        step: 4,
                        barStartFrame: 0,
                        barFrameCount: loop.framesPerBar,
                        onsetFrame: kickOnset,
                        authoredFoundationRolesInBar: ["bass"]
                    )
                    guard case let .available(evidence) =
                        PCMKickFoundationCollisionAnalyzer.analyze(
                            kick: kick.samples,
                            foundation: bass.samples,
                            sampleRate: sampleRate,
                            events: [event]
                        ) else {
                        Issue.record("expected role-separated-loop collision evidence")
                        throw FixtureError.unavailable
                    }
                    let collision = try #require(evidence.events.first)
                    let expectedTemporalConflict = bassStep == 4
                    rows.append(Row(
                        sampleRate: Int(sampleRate),
                        bassFrequencyHz: bassFrequencyHz,
                        bassStep: bassStep,
                        expectedTemporalConflict: expectedTemporalConflict,
                        collisionClass: collision.collisionClass.rawValue,
                        temporalOverlapWindows: collision.temporalOverlapWindowCount,
                        lowBandOverlapWindows: collision.lowBandOverlapWindowCount,
                        maximumSubBandSimilarity: collision.maximumSubBandSimilarity
                    ))
                    #expect(
                        (collision.temporalOverlapWindowCount > 0) ==
                            expectedTemporalConflict
                    )
                    #expect(
                        (collision.lowBandOverlapWindowCount > 0) ==
                            expectedTemporalConflict
                    )
                    #expect(collision.finite)
                }
            }
        }

        #expect(rows.count == 8)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 independent harmonic generator exposes level and band-edge response")
    func independentHarmonicLevelAndBandEdgeSweep() throws {
        struct Row: Codable {
            let sampleRate: Int
            let bassFrequencyHz: Double
            let bassToKickAmplitudeRatio: Double
            let nominalFundamentalInSubBand: Bool
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
        }

        // This analytic chirp + harmonic-note generator is intentionally
        // independent of DeterministicSignalFixtures.kickHit/bassNote and the
        // roleSeparatedLoop composition used in the earlier pilots.
        let frequencies = [30.0, 36.0, 60.0, 119.0, 125.0]
        let amplitudeRatios = [0.5, 1.0, 2.0]
        var rows: [Row] = []

        for sampleRate in [44_100, 48_000] {
            let fixture = makeFixture(sampleRate: sampleRate, step: 4)
            let kickDuration = Int((fixture.sampleRate * 0.18).rounded())
            for frequency in frequencies {
                for amplitudeRatio in amplitudeRatios {
                    let signals = independentHarmonicKickBass(
                        frameCount: fixture.barFrames,
                        sampleRate: fixture.sampleRate,
                        onsetFrame: fixture.onset,
                        durationFrames: kickDuration,
                        bassFrequencyHz: frequency,
                        kickAmplitude: 0.24,
                        bassAmplitude: 0.24 * amplitudeRatio
                    )
                    let boundEvent = PCMKickFoundationEventInput(
                        id: "independent-analytic-kick-step-4",
                        bar: 0,
                        step: 4,
                        barStartFrame: 0,
                        barFrameCount: fixture.barFrames,
                        onsetFrame: fixture.onset,
                        authoredFoundationRolesInBar: ["bass"]
                    )
                    guard case let .available(evidence) =
                        PCMKickFoundationCollisionAnalyzer.analyze(
                            kick: signals.kick,
                            foundation: signals.bass,
                            sampleRate: fixture.sampleRate,
                            events: [boundEvent]
                        ) else {
                        Issue.record("expected independent-generator collision evidence")
                        throw FixtureError.unavailable
                    }
                    let collision = try #require(evidence.events.first)
                    rows.append(Row(
                        sampleRate: sampleRate,
                        bassFrequencyHz: frequency,
                        bassToKickAmplitudeRatio: amplitudeRatio,
                        nominalFundamentalInSubBand: (35...120).contains(frequency),
                        collisionClass: collision.collisionClass.rawValue,
                        temporalOverlapWindows: collision.temporalOverlapWindowCount,
                        lowBandOverlapWindows: collision.lowBandOverlapWindowCount,
                        maximumSubBandSimilarity: collision.maximumSubBandSimilarity
                    ))
                    #expect(collision.finite)
                    #expect(collision.maximumSubBandSimilarity.isFinite)
                }
            }
        }

        #expect(rows.count == 30)
        let inBand = rows.filter(\.nominalFundamentalInSubBand)
        let outsideBand = rows.filter { !$0.nominalFundamentalInSubBand }
        #expect(inBand.count == 18)
        #expect(outsideBand.count == 12)
        #expect(inBand.filter { $0.lowBandOverlapWindows > 0 }.count == 12)
        #expect(inBand.filter { $0.bassToKickAmplitudeRatio == 2 && $0.lowBandOverlapWindows == 0 }.count == 6)
        #expect(outsideBand.filter { $0.lowBandOverlapWindows > 0 }.count == 10)
        #expect(rows.filter { $0.bassFrequencyHz == 30 && $0.lowBandOverlapWindows > 0 }.count == 6)
        #expect(rows.filter { $0.bassFrequencyHz == 125 && $0.lowBandOverlapWindows > 0 }.count == 4)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 preregistered resonator/triangle family retains all 32 rows")
    func preregisteredResonatorTriangleFamilyHoldout() throws {
        struct Row: Codable {
            let relation: String
            let sampleRate: Int
            let bassFrequencyHz: Double
            let bassToKickAmplitudeRatio: Double
            let nominalFundamentalInSubBand: Bool
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
        }

        let frequencies = [30.0, 36.0, 60.0, 119.0, 125.0]
        let ratios = [0.75, 1.25]
        var rows: [Row] = []

        for sampleRate in [44_100, 48_000] {
            let fixture = makeFixture(sampleRate: sampleRate, step: 4)
            let durationFrames = Int((fixture.sampleRate * 0.18).rounded())
            let forEachFrequency = frequencies.map { ($0, (35...120).contains($0)) }
            for (frequency, nominallyInBand) in forEachFrequency {
                for ratio in ratios {
                    let relations: [(String, Int)] = [
                        (nominallyInBand ? "in-band-same-time" : "out-of-band-same-time", fixture.onset),
                    ] + (nominallyInBand
                        ? [("in-band-after-analysis-window", fixture.analysisEnd + 1)]
                        : [])

                    for (relation, bassOnset) in relations {
                        let signals = resonatorTriangleKickBass(
                            frameCount: fixture.barFrames,
                            sampleRate: fixture.sampleRate,
                            kickOnset: fixture.onset,
                            bassOnset: bassOnset,
                            durationFrames: durationFrames,
                            bassFrequencyHz: frequency,
                            kickAmplitude: 0.20,
                            bassAmplitude: 0.20 * ratio
                        )
                        let boundEvent = PCMKickFoundationEventInput(
                            id: "resonator-triangle-kick-step-4",
                            bar: 0,
                            step: 4,
                            barStartFrame: 0,
                            barFrameCount: fixture.barFrames,
                            onsetFrame: fixture.onset,
                            authoredFoundationRolesInBar: ["bass"]
                        )
                        guard case let .available(evidence) =
                            PCMKickFoundationCollisionAnalyzer.analyze(
                                kick: signals.kick,
                                foundation: signals.bass,
                                sampleRate: fixture.sampleRate,
                                events: [boundEvent]
                            ) else {
                            Issue.record("expected preregistered family collision evidence")
                            throw FixtureError.unavailable
                        }
                        let collision = try #require(evidence.events.first)
                        rows.append(Row(
                            relation: relation,
                            sampleRate: sampleRate,
                            bassFrequencyHz: frequency,
                            bassToKickAmplitudeRatio: ratio,
                            nominalFundamentalInSubBand: nominallyInBand,
                            collisionClass: collision.collisionClass.rawValue,
                            temporalOverlapWindows: collision.temporalOverlapWindowCount,
                            lowBandOverlapWindows: collision.lowBandOverlapWindowCount,
                            maximumSubBandSimilarity: collision.maximumSubBandSimilarity
                        ))
                        let expectedSameTime = bassOnset == fixture.onset
                        #expect(
                            (collision.temporalOverlapWindowCount > 0) == expectedSameTime
                        )
                        #expect(collision.finite)
                        #expect(collision.maximumSubBandSimilarity.isFinite)
                    }
                }
            }
        }

        #expect(rows.count == 32)
        #expect(rows.filter { $0.relation == "in-band-same-time" }.count == 12)
        #expect(rows.filter { $0.relation == "out-of-band-same-time" }.count == 8)
        #expect(rows.filter { $0.relation == "in-band-after-analysis-window" }.count == 12)
        #expect(rows.filter { $0.relation == "in-band-after-analysis-window" && $0.lowBandOverlapWindows > 0 }.isEmpty)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 seed-varied resonator/triangle cohort reports grouped rows")
    func seededResonatorTriangleCohort() throws {
        struct Row: Codable {
            let split: String
            let seed: UInt64
            let sampleRate: Int
            let relation: String
            let mode1FrequencyHz: Double
            let mode2FrequencyHz: Double
            let mode1DecaySeconds: Double
            let mode2DecaySeconds: Double
            let bassFrequencyHz: Double
            let bassToKickAmplitudeRatio: Double
            let attackSeconds: Double
            let releaseSeconds: Double
            let durationSeconds: Double
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
        }

        func nextUnit(_ state: inout UInt64) -> Double {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            value ^= value >> 31
            return Double(value >> 11) / 9_007_199_254_740_992
        }

        var rows: [Row] = []
        for (split, seeds) in [("development", Array(UInt64(11)...UInt64(34))),
                               ("held-out", Array(UInt64(1001)...UInt64(1024)))] {
            for seed in seeds {
                var randomState = seed
                let mode1FrequencyHz = 36 + 50 * nextUnit(&randomState)
                let mode2FrequencyHz = 70 + 48 * nextUnit(&randomState)
                let mode1DecaySeconds = 0.025 + 0.030 * nextUnit(&randomState)
                let mode2DecaySeconds = 0.015 + 0.025 * nextUnit(&randomState)
                let bassFrequencyHz = 37 + 82 * nextUnit(&randomState)
                let ratio = 0.6 + 1.2 * nextUnit(&randomState)
                let attackSeconds = 0.001 + 0.004 * nextUnit(&randomState)
                let releaseSeconds = 0.012 + 0.020 * nextUnit(&randomState)
                let durationSeconds = 0.150 + 0.080 * nextUnit(&randomState)

                for sampleRate in [44_100, 48_000] {
                    let fixture = makeFixture(sampleRate: sampleRate, step: 4)
                    let durationFrames = Int((Double(sampleRate) * durationSeconds).rounded())
                    for (relation, bassOnset) in [
                        ("same-onset", fixture.onset),
                        ("after-analysis-window", fixture.analysisEnd + 1),
                    ] {
                        let signals = resonatorTriangleKickBass(
                            frameCount: fixture.barFrames,
                            sampleRate: fixture.sampleRate,
                            kickOnset: fixture.onset,
                            bassOnset: bassOnset,
                            durationFrames: durationFrames,
                            bassFrequencyHz: bassFrequencyHz,
                            kickAmplitude: 0.20,
                            bassAmplitude: 0.20 * ratio,
                            mode1FrequencyHz: mode1FrequencyHz,
                            mode2FrequencyHz: mode2FrequencyHz,
                            mode1DecaySeconds: mode1DecaySeconds,
                            mode2DecaySeconds: mode2DecaySeconds,
                            attackSeconds: attackSeconds,
                            releaseSeconds: releaseSeconds
                        )
                        let event = PCMKickFoundationEventInput(
                            id: "at0039-seed-\(seed)-step-4",
                            bar: 0,
                            step: 4,
                            barStartFrame: 0,
                            barFrameCount: fixture.barFrames,
                            onsetFrame: fixture.onset,
                            authoredFoundationRolesInBar: ["bass"]
                        )
                        guard case let .available(evidence) =
                                PCMKickFoundationCollisionAnalyzer.analyze(
                                    kick: signals.kick,
                                    foundation: signals.bass,
                                    sampleRate: fixture.sampleRate,
                                    events: [event]
                                ) else {
                            Issue.record("expected seeded-cohort collision evidence")
                            throw FixtureError.unavailable
                        }
                        let collision = try #require(evidence.events.first)
                        #expect(collision.finite)
                        #expect(collision.maximumSubBandSimilarity.isFinite)
                        if relation == "after-analysis-window" {
                            #expect(collision.temporalOverlapWindowCount == 0)
                        }
                        rows.append(Row(
                            split: split,
                            seed: seed,
                            sampleRate: sampleRate,
                            relation: relation,
                            mode1FrequencyHz: mode1FrequencyHz,
                            mode2FrequencyHz: mode2FrequencyHz,
                            mode1DecaySeconds: mode1DecaySeconds,
                            mode2DecaySeconds: mode2DecaySeconds,
                            bassFrequencyHz: bassFrequencyHz,
                            bassToKickAmplitudeRatio: ratio,
                            attackSeconds: attackSeconds,
                            releaseSeconds: releaseSeconds,
                            durationSeconds: durationSeconds,
                            collisionClass: collision.collisionClass.rawValue,
                            temporalOverlapWindows: collision.temporalOverlapWindowCount,
                            lowBandOverlapWindows: collision.lowBandOverlapWindowCount,
                            maximumSubBandSimilarity: collision.maximumSubBandSimilarity
                        ))
                    }
                }
            }
        }

        #expect(rows.count == 192)
        #expect(rows.filter { $0.split == "development" }.count == 96)
        #expect(rows.filter { $0.split == "held-out" }.count == 96)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 distinct noise-kick/additive-saw family reports grouped rows")
    func seededNoiseKickSawBassFamily() throws {
        struct Row: Codable {
            let split: String
            let seed: UInt64
            let sampleRate: Int
            let relation: String
            let kickNoiseDecaySeconds: Double
            let bassFrequencyHz: Double
            let bassToKickAmplitudeRatio: Double
            let attackSeconds: Double
            let releaseSeconds: Double
            let durationSeconds: Double
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
        }

        var rows: [Row] = []
        for (split, seeds) in [
            ("development", Array(UInt64(2011)...UInt64(2034))),
            ("held-out", Array(UInt64(3001)...UInt64(3024))),
        ] {
            for seed in seeds {
                var parameterState = seed
                let kickNoiseDecaySeconds = 0.030 + 0.030 * splitmixUnit(&parameterState)
                let bassFrequencyHz = 111 + 9 * splitmixUnit(&parameterState)
                let ratio = 1.20 + 0.60 * splitmixUnit(&parameterState)
                let attackSeconds = 0.001 + 0.004 * splitmixUnit(&parameterState)
                let releaseSeconds = 0.012 + 0.020 * splitmixUnit(&parameterState)
                let durationSeconds = 0.150 + 0.080 * splitmixUnit(&parameterState)

                for sampleRate in [44_100, 48_000] {
                    let fixture = makeFixture(sampleRate: sampleRate, step: 4)
                    let durationFrames = Int((Double(sampleRate) * durationSeconds).rounded())
                    for (relation, bassOnset) in [
                        ("same-onset", fixture.onset),
                        ("after-analysis-window", fixture.analysisEnd + 1),
                    ] {
                        let signals = noiseKickAdditiveSawBass(
                            frameCount: fixture.barFrames,
                            sampleRate: fixture.sampleRate,
                            kickOnset: fixture.onset,
                            bassOnset: bassOnset,
                            durationFrames: durationFrames,
                            seed: seed,
                            kickNoiseDecaySeconds: kickNoiseDecaySeconds,
                            bassFrequencyHz: bassFrequencyHz,
                            bassToKickAmplitudeRatio: ratio,
                            attackSeconds: attackSeconds,
                            releaseSeconds: releaseSeconds
                        )
                        let event = PCMKickFoundationEventInput(
                            id: "at0039-noise-saw-seed-\(seed)-step-4",
                            bar: 0,
                            step: 4,
                            barStartFrame: 0,
                            barFrameCount: fixture.barFrames,
                            onsetFrame: fixture.onset,
                            authoredFoundationRolesInBar: ["bass"]
                        )
                        guard case let .available(evidence) =
                                PCMKickFoundationCollisionAnalyzer.analyze(
                                    kick: signals.kick,
                                    foundation: signals.bass,
                                    sampleRate: fixture.sampleRate,
                                    events: [event]
                                ) else {
                            Issue.record("expected noise-kick/additive-saw collision evidence")
                            throw FixtureError.unavailable
                        }
                        let collision = try #require(evidence.events.first)
                        #expect(collision.finite)
                        #expect(collision.maximumSubBandSimilarity.isFinite)
                        #expect((collision.temporalOverlapWindowCount > 0) == (relation == "same-onset"))
                        rows.append(Row(
                            split: split,
                            seed: seed,
                            sampleRate: sampleRate,
                            relation: relation,
                            kickNoiseDecaySeconds: kickNoiseDecaySeconds,
                            bassFrequencyHz: bassFrequencyHz,
                            bassToKickAmplitudeRatio: ratio,
                            attackSeconds: attackSeconds,
                            releaseSeconds: releaseSeconds,
                            durationSeconds: durationSeconds,
                            collisionClass: collision.collisionClass.rawValue,
                            temporalOverlapWindows: collision.temporalOverlapWindowCount,
                            lowBandOverlapWindows: collision.lowBandOverlapWindowCount,
                            maximumSubBandSimilarity: collision.maximumSubBandSimilarity
                        ))
                    }
                }
            }
        }

        #expect(rows.count == 192)
        #expect(rows.filter { $0.split == "development" }.count == 96)
        #expect(rows.filter { $0.split == "held-out" }.count == 96)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 shared-fundamental pulse-kick/triangle-bass cohort reports rows")
    func seededSharedFundamentalPulseTriangleFamily() throws {
        struct Row: Codable {
            let split: String
            let seed: UInt64
            let sampleRate: Int
            let relation: String
            let sharedFundamentalHz: Double
            let kickDecaySeconds: Double
            let bassToKickAmplitudeRatio: Double
            let attackSeconds: Double
            let releaseSeconds: Double
            let durationSeconds: Double
            let sharedFundamentalLabel: Bool
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
        }

        var rows: [Row] = []
        for (split, seeds) in [
            ("development", Array(UInt64(4011)...UInt64(4034))),
            ("held-out", Array(UInt64(5001)...UInt64(5024))),
        ] {
            for seed in seeds {
                var parameterState = seed
                let sharedFrequencyHz = 112 + 6 * splitmixUnit(&parameterState)
                let kickDecaySeconds = 0.080 + 0.040 * splitmixUnit(&parameterState)
                let ratio = 1.48 + 0.18 * splitmixUnit(&parameterState)
                let attackSeconds = 0.001 + 0.004 * splitmixUnit(&parameterState)
                let releaseSeconds = 0.012 + 0.020 * splitmixUnit(&parameterState)
                let durationSeconds = 0.150 + 0.080 * splitmixUnit(&parameterState)
                let commonPhase = splitmixUnit(&parameterState)

                for sampleRate in [44_100, 48_000] {
                    let fixture = makeFixture(sampleRate: sampleRate, step: 4)
                    let durationFrames = Int((Double(sampleRate) * durationSeconds).rounded())
                    for (relation, bassOnset) in [
                        ("same-onset", fixture.onset),
                        ("after-analysis-window", fixture.analysisEnd + 1),
                    ] {
                        let signals = squarePulseKickTriangleBass(
                            frameCount: fixture.barFrames,
                            sampleRate: fixture.sampleRate,
                            kickOnset: fixture.onset,
                            bassOnset: bassOnset,
                            durationFrames: durationFrames,
                            sharedFrequencyHz: sharedFrequencyHz,
                            kickDecaySeconds: kickDecaySeconds,
                            bassToKickAmplitudeRatio: ratio,
                            attackSeconds: attackSeconds,
                            releaseSeconds: releaseSeconds,
                            commonPhase: commonPhase
                        )
                        let event = PCMKickFoundationEventInput(
                            id: "at0039-shared-fundamental-seed-\(seed)-step-4",
                            bar: 0,
                            step: 4,
                            barStartFrame: 0,
                            barFrameCount: fixture.barFrames,
                            onsetFrame: fixture.onset,
                            authoredFoundationRolesInBar: ["bass"]
                        )
                        guard case let .available(evidence) =
                                PCMKickFoundationCollisionAnalyzer.analyze(
                                    kick: signals.kick,
                                    foundation: signals.bass,
                                    sampleRate: fixture.sampleRate,
                                    events: [event]
                                ) else {
                            Issue.record("expected shared-fundamental collision evidence")
                            throw FixtureError.unavailable
                        }
                        let collision = try #require(evidence.events.first)
                        #expect(collision.finite)
                        #expect(collision.maximumSubBandSimilarity.isFinite)
                        #expect((collision.temporalOverlapWindowCount > 0) == (relation == "same-onset"))
                        rows.append(Row(
                            split: split,
                            seed: seed,
                            sampleRate: sampleRate,
                            relation: relation,
                            sharedFundamentalHz: sharedFrequencyHz,
                            kickDecaySeconds: kickDecaySeconds,
                            bassToKickAmplitudeRatio: ratio,
                            attackSeconds: attackSeconds,
                            releaseSeconds: releaseSeconds,
                            durationSeconds: durationSeconds,
                            sharedFundamentalLabel: true,
                            collisionClass: collision.collisionClass.rawValue,
                            temporalOverlapWindows: collision.temporalOverlapWindowCount,
                            lowBandOverlapWindows: collision.lowBandOverlapWindowCount,
                            maximumSubBandSimilarity: collision.maximumSubBandSimilarity
                        ))
                    }
                }
            }
        }

        #expect(rows.count == 192)
        #expect(rows.filter { $0.split == "development" }.count == 96)
        #expect(rows.filter { $0.split == "held-out" }.count == 96)
        #expect(rows.filter { $0.sharedFundamentalLabel }.count == 192)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 preregistered shared-fundamental level-scaling cohort reports rows")
    func seededSharedFundamentalLevelScalingStress() throws {
        struct Row: Codable {
            let split: String
            let seed: UInt64
            let sampleRate: Int
            let bassAmplitudeFactor: Double
            let relation: String
            let sharedFundamentalHz: Double
            let sharedFundamentalLabel: Bool
            let collisionClass: String
            let temporalOverlapWindows: Int
            let lowBandOverlapWindows: Int
            let maximumSubBandSimilarity: Double
            let windowSimilarities: [Double]
            let windowOracleKickFundamentalMeanSquares: [Double]
            let windowOracleBassFundamentalMeanSquares: [Double]
            let windowOracleSimilarities: [Double]
        }

        let amplitudeFactors = [0.55, 0.62, 0.67, 0.72, 1.00, 1.50, 1.65, 1.80, 1.95]
        func sourceEquationWindowOracle(
            startFrame: Int,
            frameCount: Int,
            sampleRate: Double,
            kickOnsetFrame: Int,
            bassOnsetFrame: Int,
            durationFrames: Int,
            sharedFrequencyHz: Double,
            kickDecaySeconds: Double,
            bassToKickAmplitudeRatio: Double,
            bassAmplitudeFactor: Double,
            attackSeconds: Double,
            releaseSeconds: Double,
            commonPhase: Double
        ) -> (kickMeanSquare: Double, bassMeanSquare: Double, similarity: Double) {
            var kickSquareSum = 0.0
            var bassSquareSum = 0.0
            for frame in startFrame..<(startFrame + frameCount) {
                let kickOffset = frame - kickOnsetFrame
                if kickOffset >= 0 && kickOffset < durationFrames {
                    let t = Double(kickOffset) / sampleRate
                    let phase = (sharedFrequencyHz * t + commonPhase)
                        .truncatingRemainder(dividingBy: 1)
                    let fundamental = 0.20 * exp(-t / kickDecaySeconds)
                        * (4 / Double.pi) * sin(2 * Double.pi * phase)
                    kickSquareSum += fundamental * fundamental
                }

                let bassOffset = frame - bassOnsetFrame
                if bassOffset >= 0 && bassOffset < durationFrames {
                    let t = Double(bassOffset) / sampleRate
                    let phase = (sharedFrequencyHz * t + commonPhase)
                        .truncatingRemainder(dividingBy: 1)
                    let envelope = max(
                        0,
                        min(
                            1,
                            min(t / attackSeconds,
                                (Double(durationFrames) / sampleRate - t) / releaseSeconds)
                        )
                    )
                    let fundamental = 0.20 * bassToKickAmplitudeRatio
                        * bassAmplitudeFactor * envelope * (8 / pow(Double.pi, 2))
                        * -cos(2 * Double.pi * phase)
                    bassSquareSum += fundamental * fundamental
                }
            }
            let kickMeanSquare = kickSquareSum / Double(frameCount)
            let bassMeanSquare = bassSquareSum / Double(frameCount)
            let similarity = kickMeanSquare > 0 && bassMeanSquare > 0
                ? min(kickMeanSquare, bassMeanSquare) / max(kickMeanSquare, bassMeanSquare)
                : 0
            return (kickMeanSquare, bassMeanSquare, similarity)
        }

        var rows: [Row] = []
        for (split, seeds) in [
            ("development", Array(UInt64(4011)...UInt64(4034))),
            ("held-out", Array(UInt64(5001)...UInt64(5024))),
        ] {
            for seed in seeds {
                var parameterState = seed
                let sharedFrequencyHz = 112 + 6 * splitmixUnit(&parameterState)
                let kickDecaySeconds = 0.080 + 0.040 * splitmixUnit(&parameterState)
                let ratio = 1.48 + 0.18 * splitmixUnit(&parameterState)
                let attackSeconds = 0.001 + 0.004 * splitmixUnit(&parameterState)
                let releaseSeconds = 0.012 + 0.020 * splitmixUnit(&parameterState)
                let durationSeconds = 0.150 + 0.080 * splitmixUnit(&parameterState)
                let commonPhase = splitmixUnit(&parameterState)

                for sampleRate in [44_100, 48_000] {
                    let fixture = makeFixture(sampleRate: sampleRate, step: 4)
                    let durationFrames = Int((Double(sampleRate) * durationSeconds).rounded())
                    for factor in amplitudeFactors {
                        for (relation, bassOnset) in [
                            ("same-onset", fixture.onset),
                            ("after-analysis-window", fixture.analysisEnd + 1),
                        ] {
                            let signals = squarePulseKickTriangleBass(
                                frameCount: fixture.barFrames,
                                sampleRate: fixture.sampleRate,
                                kickOnset: fixture.onset,
                                bassOnset: bassOnset,
                                durationFrames: durationFrames,
                                sharedFrequencyHz: sharedFrequencyHz,
                                kickDecaySeconds: kickDecaySeconds,
                                bassToKickAmplitudeRatio: ratio,
                                attackSeconds: attackSeconds,
                                releaseSeconds: releaseSeconds,
                                commonPhase: commonPhase
                            )
                            let scaledBass = signals.bass.map { Float(Double($0) * factor) }
                            let event = PCMKickFoundationEventInput(
                                id: "at0039-level-scale-seed-\(seed)-step-4",
                                bar: 0,
                                step: 4,
                                barStartFrame: 0,
                                barFrameCount: fixture.barFrames,
                                onsetFrame: fixture.onset,
                                authoredFoundationRolesInBar: ["bass"]
                            )
                            guard case let .available(evidence) =
                                    PCMKickFoundationCollisionAnalyzer.analyze(
                                        kick: signals.kick,
                                        foundation: scaledBass,
                                        sampleRate: fixture.sampleRate,
                                        events: [event]
                                    ) else {
                                Issue.record("expected level-scaled collision evidence")
                                throw FixtureError.unavailable
                            }
                            let collision = try #require(evidence.events.first)
                            #expect(collision.finite)
                            #expect(collision.maximumSubBandSimilarity.isFinite)
                            #expect((collision.temporalOverlapWindowCount > 0) ==
                                    (relation == "same-onset"))
                            let oracleWindows = collision.windows.map { window in
                                sourceEquationWindowOracle(
                                    startFrame: window.startFrame,
                                    frameCount: window.frameCount,
                                    sampleRate: fixture.sampleRate,
                                    kickOnsetFrame: fixture.onset,
                                    bassOnsetFrame: bassOnset,
                                    durationFrames: durationFrames,
                                    sharedFrequencyHz: sharedFrequencyHz,
                                    kickDecaySeconds: kickDecaySeconds,
                                    bassToKickAmplitudeRatio: ratio,
                                    bassAmplitudeFactor: factor,
                                    attackSeconds: attackSeconds,
                                    releaseSeconds: releaseSeconds,
                                    commonPhase: commonPhase
                                )
                            }
                            #expect(oracleWindows.count == 16)
                            #expect(oracleWindows.filter {
                                $0.kickMeanSquare.isFinite && $0.bassMeanSquare.isFinite
                                    && $0.similarity.isFinite
                            }.count == 16)
                            if relation == "after-analysis-window" {
                                #expect(oracleWindows.filter { $0.bassMeanSquare == 0 }.count == 16)
                            }
                            rows.append(Row(
                                split: split,
                                seed: seed,
                                sampleRate: sampleRate,
                                bassAmplitudeFactor: factor,
                                relation: relation,
                                sharedFundamentalHz: sharedFrequencyHz,
                                sharedFundamentalLabel: true,
                                collisionClass: collision.collisionClass.rawValue,
                                temporalOverlapWindows: collision.temporalOverlapWindowCount,
                                lowBandOverlapWindows: collision.lowBandOverlapWindowCount,
                                maximumSubBandSimilarity: collision.maximumSubBandSimilarity,
                                windowSimilarities: collision.windows.map(\.subBandSimilarity),
                                windowOracleKickFundamentalMeanSquares: oracleWindows.map(\.kickMeanSquare),
                                windowOracleBassFundamentalMeanSquares: oracleWindows.map(\.bassMeanSquare),
                                windowOracleSimilarities: oracleWindows.map(\.similarity)
                            ))
                        }
                    }
                }
            }
        }

        #expect(rows.count == 1_728)
        #expect(rows.filter { $0.split == "development" }.count == 864)
        #expect(rows.filter { $0.split == "held-out" }.count == 864)
        #expect(rows.filter { $0.sharedFundamentalLabel }.count == 1_728)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(rows))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("Low-frequency overlap retains duration, attribution, and energy sign")
    func lowBandOverlap() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.20,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.13,
            sampleRate: fixture.sampleRate
        )

        let evidence = try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        ))
        let event = try #require(evidence.events.first)
        #expect(event.collisionClass == .lowBandOverlap)
        #expect(event.responsibleSignals == ["kick", "foundation"])
        #expect(event.temporalOverlapWindowCount == 16)
        #expect(event.lowBandOverlapWindowCount == 16)
        #expect(event.temporalOverlapFrameCount == event.analysisFrameCount)
        #expect(event.lowBandOverlapFrameCount == event.analysisFrameCount)
        #expect((event.kickOverFoundationDB ?? 0) > 3)
        #expect(event.maximumSubBandSimilarity > 0.38)
        #expect(event.confidence ==
                PCMKickFoundationCollisionAnalyzer.confidence)
        #expect(event.finite)
    }

    @Test("High foundation content is temporal overlap without low-band match")
    func temporalWithoutLowBandOverlap() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.15,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 4_000,
            amplitude: 0.15,
            sampleRate: fixture.sampleRate
        )

        let event = try #require(try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(event.collisionClass == .temporalOverlap)
        #expect(event.temporalOverlapWindowCount == 16)
        #expect(event.lowBandOverlapWindowCount == 0)
        #expect(event.lowBandOverlapFrameCount == 0)
    }

    @Test("Separated tails and valid silence states remain distinct")
    func separatedAndMissingRoles() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        let quarter = (fixture.analysisEnd - fixture.onset) / 4
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<(fixture.onset + quarter),
            frequency: 80,
            amplitude: 0.2,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: (fixture.analysisEnd - quarter)..<fixture.analysisEnd,
            frequency: 80,
            amplitude: 0.2,
            sampleRate: fixture.sampleRate
        )
        let separated = try #require(try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(separated.collisionClass == .separated)
        #expect(separated.temporalOverlapWindowCount == 0)
        #expect(separated.kickOverFoundationDB == nil)

        let kickOnly = try #require(try available(analyze(
            kick: kick,
            foundation: fixture.silence,
            fixture: fixture
        )).events.first)
        #expect(kickOnly.collisionClass == .kickOnly)

        let foundationOnly = try #require(try available(analyze(
            kick: fixture.silence,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(foundationOnly.collisionClass == .foundationOnly)

        let silence = try #require(try available(analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            fixture: fixture
        )).events.first)
        #expect(silence.collisionClass == .mutualSilence)
        #expect(silence.finite)
    }

    @Test("Exact pre-kick pocket is independent from post-onset collision")
    func pocketBinding() throws {
        var fixture = makeFixture(sampleRate: 48_000, step: 4)
        fixture.event = PCMKickFoundationEventInput(
            id: fixture.event.id,
            bar: fixture.event.bar,
            step: fixture.event.step,
            barStartFrame: fixture.event.barStartFrame,
            barFrameCount: fixture.event.barFrameCount,
            onsetFrame: fixture.event.onsetFrame,
            authoredFoundationRolesInBar: ["bass"],
            pocket: PCMKickFoundationPocketInput(
                releaseStartFrame: fixture.onset - 800,
                releaseEndFrame: fixture.onset - 400,
                kickFrame: fixture.onset,
                silenceFrameCount: 400,
                silencePeak: 0,
                silenceRMS: 0,
                applied: true,
                finite: true
            )
        )
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.15,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.12,
            sampleRate: fixture.sampleRate
        )

        let event = try #require(try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(event.pocketState == .exactSilence)
        #expect(event.pocketSilenceFrameCount == 400)
        #expect(event.collisionClass == .lowBandOverlap)
        #expect(event.authoredFoundationRolesInBar == ["bass"])
    }

    @Test("Phase inversion does not invent a role-sum cancellation claim")
    func phaseVariant() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        var kick = fixture.silence
        var same = fixture.silence
        var inverse = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 73,
            amplitude: 0.12,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &same,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 73,
            amplitude: 0.12,
            sampleRate: fixture.sampleRate
        )
        inverse = same.map { -$0 }
        let sameEvent = try #require(try available(analyze(
            kick: kick,
            foundation: same,
            fixture: fixture
        )).events.first)
        let inverseEvent = try #require(try available(analyze(
            kick: kick,
            foundation: inverse,
            fixture: fixture
        )).events.first)
        #expect(sameEvent.collisionClass == .lowBandOverlap)
        #expect(inverseEvent.collisionClass == .lowBandOverlap)
        #expect(sameEvent.temporalOverlapFrameCount ==
                inverseEvent.temporalOverlapFrameCount)
        #expect(sameEvent.lowBandOverlapFrameCount ==
                inverseEvent.lowBandOverlapFrameCount)
    }

    @Test("44.1 and 48 kHz use bounded score-relative geometry")
    func sampleRateGeometry() throws {
        for rate in [44_100, 48_000] {
            let fixture = makeFixture(sampleRate: rate, step: 12)
            var kick = fixture.silence
            fillSine(
                &kick,
                range: fixture.onset..<fixture.analysisEnd,
                frequency: 70,
                amplitude: 0.1,
                sampleRate: fixture.sampleRate
            )
            let evidence = try available(analyze(
                kick: kick,
                foundation: fixture.silence,
                fixture: fixture
            ))
            let event = try #require(evidence.events.first)
            #expect(evidence.sampleRate == rate)
            #expect(event.windows.count == 16)
            #expect(event.windows.reduce(0) { $0 + $1.frameCount } ==
                    event.analysisFrameCount)
            #expect(event.analysisFrameCount ==
                    Int((Double(fixture.barFrames) / 8.0).rounded()))
        }
    }

    @Test("Malformed geometry, PCM, and pockets fail with stable reasons")
    func unavailableReasons() {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: 96_000,
            events: [fixture.event]
        ) == .unavailable(.unsupportedSampleRate))
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: Array(fixture.silence.dropLast()),
            sampleRate: fixture.sampleRate,
            events: [fixture.event]
        ) == .unavailable(.unalignedSignals))
        var invalidPCM = fixture.silence
        invalidPCM[10] = .nan
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: invalidPCM,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [fixture.event]
        ) == .unavailable(.nonFinitePCM))
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [fixture.event, fixture.event]
        ) == .unavailable(.duplicateEvent))
        let invalidEvent = PCMKickFoundationEventInput(
            id: "invalid",
            bar: 0,
            step: 4,
            barStartFrame: 0,
            barFrameCount: fixture.barFrames,
            onsetFrame: fixture.onset + 1,
            authoredFoundationRolesInBar: []
        )
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [invalidEvent]
        ) == .unavailable(.invalidEventGeometry))
        let invalidPocket = PCMKickFoundationEventInput(
            id: "invalid-pocket",
            bar: 0,
            step: 4,
            barStartFrame: 0,
            barFrameCount: fixture.barFrames,
            onsetFrame: fixture.onset,
            authoredFoundationRolesInBar: ["bass"],
            pocket: PCMKickFoundationPocketInput(
                releaseStartFrame: fixture.onset - 800,
                releaseEndFrame: fixture.onset - 400,
                kickFrame: fixture.onset,
                silenceFrameCount: 400,
                silencePeak: 0.001,
                silenceRMS: 0,
                applied: true,
                finite: true
            )
        )
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [invalidPocket]
        ) == .unavailable(.invalidPocketBinding))
    }

    private struct Fixture {
        let sampleRate: Double
        let barFrames: Int
        let onset: Int
        let analysisEnd: Int
        let silence: [Float]
        var event: PCMKickFoundationEventInput
    }

    /// Independent analytic source pair used only by the AT-0039 calibration
    /// probe. It does not call the shared fixture constructors or a production
    /// renderer: kick is a damped linear chirp with a second harmonic; bass is
    /// an independently enveloped sustained oscillator with bounded harmonics.
    private func independentHarmonicKickBass(
        frameCount: Int,
        sampleRate: Double,
        onsetFrame: Int,
        durationFrames: Int,
        bassFrequencyHz: Double,
        kickAmplitude: Double,
        bassAmplitude: Double
    ) -> (kick: [Float], bass: [Float]) {
        var kick = [Float](repeating: 0, count: frameCount)
        var bass = [Float](repeating: 0, count: frameCount)
        let durationSeconds = Double(durationFrames) / sampleRate
        let chirpSlope = (35.0 - 110.0) / durationSeconds
        let useBassHarmonics = (35...120).contains(bassFrequencyHz)

        for offset in 0..<durationFrames {
            let t = Double(offset) / sampleRate
            let phase = 2 * Double.pi * (110 * t + 0.5 * chirpSlope * t * t)
            let envelope = exp(-5 * t / durationSeconds)
            kick[onsetFrame + offset] = Float(
                kickAmplitude * envelope * (sin(phase) + 0.2 * sin(2 * phase))
            )

            let attack = min(1, t / 0.003)
            let release = min(1, (durationSeconds - t) / 0.02)
            let bassEnvelope = max(0, min(attack, release))
            let bassPhase = 2 * Double.pi * bassFrequencyHz * t
            let harmonics = useBassHarmonics
                ? sin(bassPhase) + 0.28 * sin(2 * bassPhase) + 0.1 * sin(3 * bassPhase)
                : sin(bassPhase)
            bass[onsetFrame + offset] = Float(
                bassAmplitude * bassEnvelope * harmonics
            )
        }
        return (kick, bass)
    }

    /// AT-0039 preregistered waveform-family holdout: a two-mode damped
    /// resonator kick and piecewise-linear triangle bass, independent of the
    /// prior sinusoid/chirp constructors and the renderer.
    private func resonatorTriangleKickBass(
        frameCount: Int,
        sampleRate: Double,
        kickOnset: Int,
        bassOnset: Int,
        durationFrames: Int,
        bassFrequencyHz: Double,
        kickAmplitude: Double,
        bassAmplitude: Double,
        mode1FrequencyHz: Double = 48,
        mode2FrequencyHz: Double = 96,
        mode1DecaySeconds: Double = 0.035,
        mode2DecaySeconds: Double = 0.020,
        attackSeconds: Double = 0.002,
        releaseSeconds: Double = 0.020
    ) -> (kick: [Float], bass: [Float]) {
        var kick = [Float](repeating: 0, count: frameCount)
        var bass = [Float](repeating: 0, count: frameCount)
        let durationSeconds = Double(durationFrames) / sampleRate

        for offset in 0..<durationFrames {
            let t = Double(offset) / sampleRate
            let mode1 = exp(-t / mode1DecaySeconds)
                * sin(2 * Double.pi * mode1FrequencyHz * t)
            let mode2 = 0.35 * exp(-t / mode2DecaySeconds)
                * sin(2 * Double.pi * mode2FrequencyHz * t + 0.4)
            kick[kickOnset + offset] = Float(kickAmplitude * (mode1 + mode2))

            let attack = min(1, t / attackSeconds)
            let release = min(1, (durationSeconds - t) / releaseSeconds)
            let envelope = max(0, min(attack, release))
            let fundamentalPhase = (bassFrequencyHz * t).truncatingRemainder(dividingBy: 1)
            let secondPhase = (2 * bassFrequencyHz * t).truncatingRemainder(dividingBy: 1)
            let triangleFundamental = 1 - 4 * abs(fundamentalPhase - 0.5)
            let triangleSecond = 1 - 4 * abs(secondPhase - 0.5)
            bass[bassOnset + offset] = Float(
                bassAmplitude * envelope * (triangleFundamental + 0.2 * triangleSecond)
            )
        }
        return (kick, bass)
    }

    private func splitmixUnit(_ state: inout UInt64) -> Double {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value >> 11) / 9_007_199_254_740_992
    }

    private func noiseKickAdditiveSawBass(
        frameCount: Int,
        sampleRate: Double,
        kickOnset: Int,
        bassOnset: Int,
        durationFrames: Int,
        seed: UInt64,
        kickNoiseDecaySeconds: Double,
        bassFrequencyHz: Double,
        bassToKickAmplitudeRatio: Double,
        attackSeconds: Double,
        releaseSeconds: Double
    ) -> (kick: [Float], bass: [Float]) {
        var kick = [Float](repeating: 0, count: frameCount)
        var bass = [Float](repeating: 0, count: frameCount)
        let durationSeconds = Double(durationFrames) / sampleRate
        let sawNormalization = (1...8).reduce(0.0) { $0 + 1 / Double($1) }
        var noiseState = seed ^ 0xD1B54A32D192ED03
        var lowNoise = 0.0

        for offset in 0..<durationFrames {
            let t = Double(offset) / sampleRate
            let whiteNoise = 2 * splitmixUnit(&noiseState) - 1
            lowNoise = 0.88 * lowNoise + 0.12 * whiteNoise
            let transient = max(0, 1 - t / 0.003)
            kick[kickOnset + offset] = Float(
                0.20 * exp(-t / kickNoiseDecaySeconds)
                    * (0.65 * lowNoise + 0.35 * transient)
            )

            let attack = min(1, t / attackSeconds)
            let release = min(1, (durationSeconds - t) / releaseSeconds)
            let envelope = max(0, min(attack, release))
            var saw = 0.0
            for harmonic in 1...8 {
                saw += sin(2 * Double.pi * Double(harmonic) * bassFrequencyHz * t)
                    / Double(harmonic)
            }
            bass[bassOnset + offset] = Float(
                0.20 * bassToKickAmplitudeRatio * envelope * saw / sawNormalization
            )
        }
        return (kick, bass)
    }

    private func squarePulseKickTriangleBass(
        frameCount: Int,
        sampleRate: Double,
        kickOnset: Int,
        bassOnset: Int,
        durationFrames: Int,
        sharedFrequencyHz: Double,
        kickDecaySeconds: Double,
        bassToKickAmplitudeRatio: Double,
        attackSeconds: Double,
        releaseSeconds: Double,
        commonPhase: Double
    ) -> (kick: [Float], bass: [Float]) {
        var kick = [Float](repeating: 0, count: frameCount)
        var bass = [Float](repeating: 0, count: frameCount)
        let durationSeconds = Double(durationFrames) / sampleRate

        for offset in 0..<durationFrames {
            let t = Double(offset) / sampleRate
            let phase = (sharedFrequencyHz * t + commonPhase)
                .truncatingRemainder(dividingBy: 1)
            let squarePulse = phase < 0.5 ? 1.0 : -1.0
            let triangle = 1 - 4 * abs(phase - 0.5)
            kick[kickOnset + offset] = Float(
                0.20 * exp(-t / kickDecaySeconds) * squarePulse
            )

            let attack = min(1, t / attackSeconds)
            let release = min(1, (durationSeconds - t) / releaseSeconds)
            let envelope = max(0, min(attack, release))
            bass[bassOnset + offset] = Float(
                0.20 * bassToKickAmplitudeRatio * envelope * triangle
            )
        }
        return (kick, bass)
    }

    private func makeFixture(sampleRate: Int, step: Int) -> Fixture {
        let barFrames = Int((Double(sampleRate) * 240.0 / 130.0).rounded())
        let onset = Int((Double(step) * Double(barFrames) / 16.0).rounded())
        let analysisEnd = min(
            barFrames,
            onset + Int((Double(barFrames) / 8.0).rounded())
        )
        return Fixture(
            sampleRate: Double(sampleRate),
            barFrames: barFrames,
            onset: onset,
            analysisEnd: analysisEnd,
            silence: [Float](repeating: 0, count: barFrames),
            event: PCMKickFoundationEventInput(
                id: "bar-0-step-\(step)",
                bar: 0,
                step: step,
                barStartFrame: 0,
                barFrameCount: barFrames,
                onsetFrame: onset,
                authoredFoundationRolesInBar: ["rumble", "bass", "bass"]
            )
        )
    }

    private func analyze(
        kick: [Float],
        foundation: [Float],
        fixture: Fixture
    ) -> PCMKickFoundationCollisionAnalysisResult {
        PCMKickFoundationCollisionAnalyzer.analyze(
            kick: kick,
            foundation: foundation,
            sampleRate: fixture.sampleRate,
            events: [fixture.event]
        )
    }

    private func available(
        _ result: PCMKickFoundationCollisionAnalysisResult
    ) throws -> PCMKickFoundationCollisionEvidence {
        guard case let .available(evidence) = result else {
            Issue.record("expected available collision evidence, got \(result)")
            throw FixtureError.unavailable
        }
        return evidence
    }

    private func fillSine(
        _ samples: inout [Float],
        range: Range<Int>,
        frequency: Double,
        amplitude: Double,
        sampleRate: Double
    ) {
        for frame in range {
            samples[frame] = Float(amplitude * sin(
                2 * Double.pi * frequency * Double(frame - range.lowerBound) /
                    sampleRate
            ))
        }
    }

    private enum FixtureError: Error { case unavailable }
}
