import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Modal percussion DSP", .serialized)
struct ModalPercussionDSPTests {
    @Test("AT-0039 actual successor samples complete all fixed late modal windows")
    func continuousModalWindowMatrix() throws {
        var rows: [[String: Any]] = []
        var maximumRMSError = 0.0
        for rate in [44_100.0, 48_000.0] {
            let frames = Int((240 / AutonomousSessionDirector.bpm * rate).rounded())
            for material in ModalPercussionMaterial.allCases {
                for damping in [0.0, 0.5, 1.0] {
                    for step in [14, 15] {
                        for level in [0.0, 0.2] {
                            let onset = Int((Double(step) * Double(frames) / 16).rounded())
                            let event = ScheduledModalPercussionEvent(articulation: articulation(
                                damping: damping, seed: 12_648_430, material: material, step: step),
                                startFrame: onset, level: level)
                            var state = ModalPercussionVoiceState()
                            var first = [Float](repeating: 0, count: frames)
                            let opening = ModalPercussionVoice.renderBar(into: &first, bar: 0,
                                sampleRate: rate, events: [event], state: &state)
                            #expect(opening.continuousWindows.pending.count == 1)
                            #expect(opening.events[0].windowSupport.tail(sampleRate: rate) != .complete)
                            let frozen = state
                            var second = [Float](repeating: 0, count: Int(ceil(rate * 0.3)))
                            let closing = ModalPercussionVoice.renderBar(into: &second, bar: 1,
                                sampleRate: rate, events: [], state: &state)
                            let measured = try #require(closing.continuousWindows.completed.first)
                            #expect(measured.isValid && measured.status == .complete)
                            #expect(closing.continuousWindows.pending.isEmpty)
                            #expect(opening.continuousWindows.outgoingStateFingerprint ==
                                closing.continuousWindows.incomingStateFingerprint)
                            var replayState = frozen
                            var replay = [Float](repeating: 0, count: second.count)
                            let replayEvidence = ModalPercussionVoice.renderBar(into: &replay, bar: 1,
                                sampleRate: rate, events: [], state: &replayState)
                            #expect(replay == second && replayEvidence == closing && replayState == state)
                            var oneState = ModalPercussionVoiceState()
                            var one = [Float](repeating: 0, count: first.count + second.count)
                            _ = ModalPercussionVoice.renderBar(into: &one, bar: 0,
                                sampleRate: rate, events: [event], state: &oneState)
                            #expect(first + second == one)
                            let support = measured.windowSupport
                            let counts = [support.attackSampleCount, support.bodySampleCount, support.tailSampleCount]
                            let rms = [measured.attackRMS, measured.bodyRMS, measured.tailRMS]
                            for (index, interval) in [(0.0, 0.010), (0.020, 0.080), (0.120, 0.240)].enumerated() {
                                let oracle = DeterministicSignalFixtures.timestampWindow(samples: one,
                                    onsetFrame: onset, sampleRate: rate,
                                    startSeconds: interval.0, endSeconds: interval.1)
                                #expect(counts[index] == oracle.count)
                                let error = abs(rms[index] - oracle.rms)
                                maximumRMSError = max(maximumRMSError, error)
                                #expect(error <= 2 * Double(Float.ulpOfOne) * measured.peak)
                            }
                            #expect((support.tailToBodyDB(tailRMS: measured.tailRMS,
                                bodyRMS: measured.bodyRMS, sampleRate: rate) != nil) == (level > 0))
                            if level == 0 { #expect(measured.bodyRMS == 0) }
                            else { #expect(measured.bodyRMS > 0) }
                            rows.append(["rate": rate, "material": material.rawValue,
                                "damping": damping, "step": step, "level": level,
                                "observedFrames": measured.observedFrameCount,
                                "tailSamples": support.tailSampleCount, "bodyRMS": measured.bodyRMS,
                                "tailRMS": measured.tailRMS, "status": measured.status.rawValue])
                        }
                    }
                }
            }
        }
        #expect(rows.count == 96)
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:
            ["fixture": "modal-measurement-continuity.v1", "caseCount": rows.count,
             "maximumRMSError": maximumRMSError, "qualification": "unavailable", "rows": rows],
            options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("Continuous observation preserves retired-slot identity and overlap source separation")
    func continuousModalRetirementAndOverlap() throws {
        for rate in [44_101.0, 96_000.0] {
            let cut = Int(ceil(rate * 0.190))
            let event = scheduled(articulation: articulation(damping: 0, seed: 1), startFrame: 0)
            var state = ModalPercussionVoiceState()
            var first = [Float](repeating: 0, count: cut)
            _ = ModalPercussionVoice.renderBar(into: &first, bar: 0, sampleRate: rate,
                events: [event], state: &state)
            #expect(!state.slot0.active && state.measurement.pending.count == 1)
            #expect(state.measurement.pending[0].slotIndex == nil)
            var second = [Float](repeating: 0, count: Int(ceil(rate * 0.3)))
            let other = scheduled(articulation: articulation(seed: 2), startFrame: 0)
            let closing = ModalPercussionVoice.renderBar(into: &second, bar: 1, sampleRate: rate,
                events: [other], state: &state)
            let original = try #require(closing.continuousWindows.completed.first { $0.originBar == 0 })
            var isolatedState = ModalPercussionVoiceState()
            var isolated = [Float](repeating: 0, count: first.count + second.count)
            _ = ModalPercussionVoice.renderBar(into: &isolated, bar: 0, sampleRate: rate,
                events: [event], state: &isolatedState)
            let oracle = DeterministicSignalFixtures.timestampWindow(samples: isolated,
                onsetFrame: 0, sampleRate: rate, startSeconds: 0.120, endSeconds: 0.240)
            #expect(original.isValid && original.tailRMS == oracle.rms)
            #expect(second.contains { $0 != 0 })
            // Two simultaneous overlapping sources retain their own RMS,
            // rather than measuring the summed modal stem twice.
            var overlapState = ModalPercussionVoiceState()
            var overlap = [Float](repeating: 0, count: second.count)
            let pair = ModalPercussionVoice.renderBar(into: &overlap, bar: 0, sampleRate: rate,
                events: [event, other], state: &overlapState)
            let own = try #require(pair.continuousWindows.completed.first {
                $0.articulationFingerprint == AutonomousTypedFingerprint.modalArticulation(event.articulation)
            })
            #expect(own.tailRMS == original.tailRMS)
        }
    }

    @Test("Pending modal windows reject gaps and route resets without invented successor silence")
    func continuousModalInterruptionAndBounds() throws {
        let rate = 44_100.0
        var state = ModalPercussionVoiceState()
        var first = [Float](repeating: 0, count: Int(rate * 0.05))
        _ = ModalPercussionVoice.renderBar(into: &first, bar: 0, sampleRate: rate,
            events: [scheduled(articulation: articulation(), startFrame: 0)], state: &state)
        let frozen = state
        let pending = try #require(state.measurement.pending.first?.evidence(status: .pending))
        #expect(pending.windowSupport.body(sampleRate: rate) == .partial)
        #expect(pending.windowSupport.tail(sampleRate: rate) == .missing)
        for (bar, nextRate, reason) in [(2, rate, ModalPercussionMeasurementStatus.barGap),
                                     (1, 48_000.0, .routeChange)] {
            var copy = frozen
            var next = [Float](repeating: 0, count: Int(nextRate * 0.3))
            let ended = ModalPercussionVoice.renderBar(into: &next, bar: bar,
                sampleRate: nextRate, events: [], state: &copy)
            let interrupted = try #require(ended.continuousWindows.completed.first)
            #expect(interrupted.status == reason && interrupted.observedFrameCount == first.count)
            #expect(interrupted.tailRMS == 0)
            #expect(interrupted.windowSupport.tail(sampleRate: rate) == .missing)
        }
        var poisoned = frozen
        poisoned.measurement.pending[0].bodyEnergy += 0.01
        var left = RenderState(), right = RenderState()
        left.modalPercussionState = frozen; right.modalPercussionState = poisoned
        #expect(AutonomousTypedFingerprint.renderState(left) != AutonomousTypedFingerprint.renderState(right))
        #expect(frozen == state)
        // Four retired voices plus four newly occupied voices exercise the
        // full eight-record bound; a ninth onset cannot steal a voice.
        var bounded = ModalPercussionVoiceState()
        var opening = [Float](repeating: 0, count: Int(ceil(rate * 0.190)))
        let events = (1...4).map { scheduled(articulation: articulation(damping: 0, seed: UInt64($0)), startFrame: 0) }
        _ = ModalPercussionVoice.renderBar(into: &opening, bar: 0, sampleRate: rate,
            events: events, state: &bounded)
        var ending = [Float](repeating: 0, count: 1)
        let result = ModalPercussionVoice.renderBar(into: &ending, bar: 1, sampleRate: rate,
            events: events + [scheduled(articulation: articulation(seed: 5), startFrame: 0)], state: &bounded)
        #expect(bounded.measurement.pending.count == ModalPercussionMeasurementState.pendingCapacity)
        #expect(result.continuousWindows.completed.contains { $0.status == .voiceCapacity })
        #expect(result.events.last?.capacityValid == false)
    }
    @Test("AT-0039 frozen material/morphology/bar-phase matrix preserves truthful window support")
    func modalMorphologyTimingCoverage() throws {
        let controls = [("low", 48.0, 0.2, 0.0, 0.0, 0.0, 0.0),
                        ("middle", 110.0, 0.6, 0.5, 0.5, 0.06, 0.18),
                        ("high", 196.0, 1.0, 1.0, 1.0, 0.12, 0.6)]
        let seeds: [UInt64] = [12_648_430, 219_540_062]
        var rows: [[String: Any]] = []
        var maximumRMSError = 0.0
        for rate in [44_100.0, 48_000.0] {
            let frames = Int((240 / AutonomousSessionDirector.bpm * rate).rounded())
            let full = [Float](repeating: 0, count: Int(rate * 0.3) + 2)
            for material in ModalPercussionMaterial.allCases {
                for control in controls {
                    for step in 0..<16 {
                        let onset = Int((Double(step) * Double(frames) / 16).rounded())
                        for (seedIndex, seed) in seeds.enumerated() {
                            var state = ModalPercussionVoiceState()
                            var pcm = [Float](repeating: 0, count: frames)
                            let rendered = ModalPercussionVoice.renderBar(
                                into: &pcm, bar: 0, sampleRate: rate,
                                events: [.init(articulation: articulation(
                                    fundamentalHz: control.1, excitation: control.2,
                                    damping: control.3, brightness: control.4,
                                    inharmonicity: control.5, seed: seed,
                                    material: material, coupling: control.6, step: step),
                                    startFrame: onset, level: 0.2)], state: &state)
                            let event = try #require(rendered.events.first)
                            #expect(event.finite && event.stable && event.capacityValid)
                            #expect(event.windowSupport.isValid(sampleRate: rate, frameCount: frames))
                            let ranges = [(0.0, 0.010), (0.020, 0.080), (0.120, 0.240)]
                            let counts = [event.windowSupport.attackSampleCount,
                                event.windowSupport.bodySampleCount, event.windowSupport.tailSampleCount]
                            let rms = [event.attackRMS, event.bodyRMS, event.tailRMS]
                            let statuses = [event.windowSupport.attack(sampleRate: rate),
                                event.windowSupport.body(sampleRate: rate), event.windowSupport.tail(sampleRate: rate)]
                            var windows: [[String: Any]] = []
                            for index in ranges.indices {
                                let (start, end) = ranges[index]
                                let oracle = DeterministicSignalFixtures.timestampWindow(
                                    samples: pcm, onsetFrame: onset, sampleRate: rate,
                                    startSeconds: start, endSeconds: end)
                                let complete = DeterministicSignalFixtures.timestampWindow(
                                    samples: full, onsetFrame: 0, sampleRate: rate,
                                    startSeconds: start, endSeconds: end).count
                                let expected: ModalPercussionWindowSupport.Availability =
                                    oracle.count == 0 ? .missing :
                                    (oracle.count == complete ? .complete : .partial)
                                let error = abs(rms[index] - oracle.rms)
                                let bound = 2 * Double(Float.ulpOfOne) * event.peak
                                maximumRMSError = max(maximumRMSError, error)
                                #expect(counts[index] == oracle.count)
                                #expect(statuses[index] == expected)
                                #expect(error <= bound)
                                windows.append(["window": index, "expectedCount": oracle.count,
                                    "observedCount": counts[index], "fullCount": complete,
                                    "availability": expected.rawValue, "pcmRMS": oracle.rms,
                                    "eventRMS": rms[index], "roundingError": error, "roundingBound": bound])
                            }
                            if step == 14 { #expect(statuses[2] == .partial) }
                            if step == 15 {
                                #expect(statuses[2] == .missing)
                                #expect(event.windowSupport.tailToBodyDB(tailRMS: event.tailRMS,
                                    bodyRMS: event.bodyRMS, sampleRate: rate) == nil)
                            }
                            rows.append(["sampleRate": rate, "material": material.rawValue,
                                "morphology": control.0, "step": step, "onsetFrame": onset,
                                "seed": seed, "split": seedIndex == 0 ? "development-construction" : "held-out-excitation-construction",
                                "windows": windows])
                        }
                    }
                }
            }
        }
        #expect(rows.count == 768)
        let report: [String: Any] = ["fixture": "modal-morphology-timing.v1",
            "caseCount": rows.count, "maximumRMSError": maximumRMSError,
            "qualityQualification": "unavailable", "rows": rows]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("AT-0039 timestamp oracles independently bound modal counts and PCM RMS")
    func independentModalWindowOracles() throws {
        // Frozen before measurement in independent-measurement-fixtures-v1.
        // Extra rates are primitive holdouts, not qualified playback routes.
        var cases = 0
        var maximumRMSError = 0.0
        var rows: [[String: Any]] = []
        for rate in [44_100.0, 48_000.0, 44_101.0, 96_000.0] {
            var lengths = [Int((rate * 0.3).rounded())]
            for endpoint in [0.010, 0.020, 0.080, 0.120, 0.240] {
                for offset in [-1, 0, 1] {
                    lengths.append(Int((rate * endpoint).rounded()) + offset)
                }
            }
            let full = [Float](repeating: 0, count: Int(rate * 0.3) + 2)
            for onset in [37, 101] {
                for level in [0.0, 0.2] {
                    for length in lengths {
                        var state = ModalPercussionVoiceState()
                        var pcm = [Float](repeating: 0, count: onset + length)
                        let rendered = ModalPercussionVoice.renderBar(
                            into: &pcm, bar: 0, sampleRate: rate,
                            events: [.init(articulation: articulation(),
                                           startFrame: onset, level: level)], state: &state)
                        let event = try #require(rendered.events.first)
                        let support = event.windowSupport
                        #expect(support.isValid(sampleRate: rate, frameCount: pcm.count))
                        let ranges = [(0.0, 0.010), (0.020, 0.080), (0.120, 0.240)]
                        let counts = [support.attackSampleCount, support.bodySampleCount,
                                      support.tailSampleCount]
                        let rms = [event.attackRMS, event.bodyRMS, event.tailRMS]
                        let statuses = [support.attack(sampleRate: rate),
                                        support.body(sampleRate: rate), support.tail(sampleRate: rate)]
                        var windowRows: [[String: Any]] = []
                        for index in ranges.indices {
                            let (start, end) = ranges[index]
                            let oracle = DeterministicSignalFixtures.timestampWindow(
                                samples: pcm, onsetFrame: onset, sampleRate: rate,
                                startSeconds: start, endSeconds: end)
                            let complete = DeterministicSignalFixtures.timestampWindow(
                                samples: full, onsetFrame: 0, sampleRate: rate,
                                startSeconds: start, endSeconds: end).count
                            let expected: ModalPercussionWindowSupport.Availability =
                                oracle.count == 0 ? .missing :
                                (oracle.count == complete ? .complete : .partial)
                            #expect(counts[index] == oracle.count)
                            #expect(statuses[index] == expected)
                            let error = abs(rms[index] - oracle.rms)
                            maximumRMSError = max(maximumRMSError, error)
                            // RMS is Lipschitz under bounded per-sample Float
                            // rounding; this bound is not fitted from errors.
                            #expect(error <= 2 * Double(Float.ulpOfOne) * event.peak)
                            windowRows.append(["window": index, "expectedCount": oracle.count,
                                "observedCount": counts[index], "fullCount": complete,
                                "expectedAvailability": expected.rawValue,
                                "observedAvailability": statuses[index].rawValue,
                                "pcmRMS": oracle.rms, "eventRMS": rms[index],
                                "roundingError": error,
                                "roundingBound": 2 * Double(Float.ulpOfOne) * event.peak])
                        }
                        if level == 0 {
                            #expect(event.bodyRMS == 0)
                            #expect(support.attackToBodyDB(attackRMS: event.attackRMS,
                                bodyRMS: event.bodyRMS, sampleRate: rate) == nil)
                            #expect(support.tailToBodyDB(tailRMS: event.tailRMS,
                                bodyRMS: event.bodyRMS, sampleRate: rate) == nil)
                        }
                        cases += 1
                        rows.append(["sampleRate": rate, "onsetFrame": onset,
                            "availableFrames": length, "level": level,
                            "split": [44_100.0, 48_000.0].contains(rate) ? "development-rate" : "held-out-primitive-rate",
                            "windows": windowRows])
                    }
                }
            }
        }
        #expect(cases == 256)
        let report: [String: Any] = ["fixture": "independent-modal-window-oracle.v1",
            "caseCount": cases, "maximumRMSError": maximumRMSError,
            "uncertainty": "bounded-float-rounding-not-statistical-confidence",
            "qualityQualification": "unavailable", "rows": rows]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("Eight coupled modal modes are stable and stay below the route ceiling")
    func eightModesAreStableAndBelowTheRouteCeiling() throws {
        let result = render(sampleRate: 44_100)
        let event = try #require(result.evidence.events.first)

        #expect(event.modeCount == 8)
        #expect(event.stable)
        #expect(event.finite)
        #expect(event.minimumModeFrequencyHz >= event.appliedFundamentalHz)
        #expect(event.maximumModeFrequencyHz < 0.9 * 44_100 * 0.5)
        #expect((event.minimumModeFrequencyHz...event.maximumModeFrequencyHz)
            .contains(event.spectralCentroidHz))
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

    @Test("Coupled materials produce four deterministic rhythmic worlds")
    func coupledMaterialsProduceDistinctDeterministicPCM() throws {
        let recipes: [(ModalPercussionMaterial, Double)] = [
            (.stretchedMembrane, 0.14),
            (.hollowWood, 0.26),
            (.bronzePlate, 0.46),
            (.ceramicShell, 0.34),
        ]
        let rendered = recipes.map { material, coupling in
            render(
                sampleRate: 48_000,
                articulation: articulation(
                    material: material,
                    coupling: coupling
                )
            )
        }

        #expect(Set(rendered.map(\.evidence.dryBarSampleHash)).count == 4)
        let events = try rendered.map {
            try #require($0.evidence.events.first)
        }
        #expect(Set(events.map(\.modeRatioFingerprint)).count == 4)
        #expect(events.map(\.material) == recipes.map { $0.0 })
        #expect(events.map(\.coupling) == recipes.map { $0.1 })
        #expect(events.allSatisfy {
            $0.modeCount == ModalPercussionVoice.modeCount &&
                $0.stable && $0.finite && $0.peak <= 1
        })

        let replay = render(
            sampleRate: 48_000,
            articulation: articulation(
                material: .bronzePlate,
                coupling: 0.46
            )
        )
        #expect(replay.output == rendered[2].output)
        #expect(replay.evidence == rendered[2].evidence)
        #expect(replay.state == rendered[2].state)
    }

    @Test("Body-to-shell coupling changes only the existing bounded voice")
    func bodyToShellCouplingIsCausalAndBounded() throws {
        let uncoupled = render(
            sampleRate: 44_100,
            articulation: articulation(
                material: .hollowWood,
                coupling: 0
            )
        )
        let coupled = render(
            sampleRate: 44_100,
            articulation: articulation(
                material: .hollowWood,
                coupling: 0.6
            )
        )
        let uncoupledEvent = try #require(uncoupled.evidence.events.first)
        let coupledEvent = try #require(coupled.evidence.events.first)

        #expect(uncoupled.output != coupled.output)
        #expect(uncoupledEvent.excitationFingerprint ==
                coupledEvent.excitationFingerprint)
        #expect(uncoupledEvent.appliedFundamentalHz ==
                coupledEvent.appliedFundamentalHz)
        #expect(uncoupledEvent.coupling == 0)
        #expect(coupledEvent.coupling == 0.6)
        #expect(coupled.output.allSatisfy { $0.isFinite })
        #expect(coupledEvent.peak <= 1)
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
        func attackToBodyDB(_ attackRMS: Double, _ bodyRMS: Double) -> Double {
            min(120, max(-120,
                20 * (log10(max(attackRMS, 1e-12)) -
                      log10(max(bodyRMS, 1e-12)))
            ))
        }
        let attackToBody441 = attackToBodyDB(
            evidence441.attackRMS,
            evidence441.bodyRMS
        )
        let attackToBody480 = attackToBodyDB(
            evidence480.attackRMS,
            evidence480.bodyRMS
        )

        #expect(abs(decay441 - decay480) < 0.025)
        #expect(abs(evidence441.tailToBodyDB - evidence480.tailToBodyDB) < 1.5)
        #expect(abs(evidence441.attackRMS - evidence480.attackRMS) < 0.02)
        #expect(evidence441.bodyRMS > 0 && evidence480.bodyRMS > 0)
        #expect(abs(attackToBody441 - attackToBody480) < 1.5)
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
        let firstEvidence = ModalPercussionVoice.renderBar(
            into: &first,
            bar: 0,
            sampleRate: sampleRate,
            events: [event],
            state: &splitState
        )
        let secondEvidence = ModalPercussionVoice.renderBar(
            into: &second,
            bar: 1,
            sampleRate: sampleRate,
            events: [],
            state: &splitState
        )

        #expect(firstEvidence.activeOutgoingVoiceCount > 0)
        #expect(secondEvidence.events.isEmpty)
        #expect(secondEvidence.activeIncomingVoiceCount > 0)
        #expect(secondEvidence.continuationRendered)
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

    @Test("A late bar strike reports the bounded missing-tail sentinel")
    func lateBarStrikeHasBoundedTailEvidence() throws {
        let sampleRate = 44_100.0
        let frameCount = Int((
            240 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded())
        let startFrame = frameCount - Int((sampleRate * 0.10).rounded())
        var state = ModalPercussionVoiceState()
        var output = [Float](repeating: 0, count: frameCount)
        let evidence = ModalPercussionVoice.renderBar(
            into: &output,
            bar: 0,
            sampleRate: sampleRate,
            events: [scheduled(
                articulation: articulation(),
                startFrame: startFrame
            )],
            state: &state
        )
        let event = try #require(evidence.events.first)

        #expect(event.bodyRMS > 0)
        #expect(event.tailRMS == 0)
        #expect(event.tailToBodyDB == -120)
        #expect(event.tailToBodyDB >= -120)
        #expect(event.finite)
        #expect(event.windowSupport.tail(sampleRate: sampleRate) == .missing)
        #expect(event.windowSupport.tailSampleCount == 0)
        #expect(event.windowSupport.tailToBodyDB(
            tailRMS: event.tailRMS, bodyRMS: event.bodyRMS,
            sampleRate: sampleRate
        ) == nil)
    }

    @Test("Window support separates absent, partial, complete, and measured silence",
          arguments: [44_100.0, 48_000.0])
    func windowSupportUsesMeasuredSampleGeometry(sampleRate: Double) throws {
        // End immediately before the first tail sample, just after it, and at
        // the exclusive end. Nonzero onset catches absolute/relative mistakes.
        let onset = 37
        let tailStart = Int(sampleRate * 0.120)
        let tailEnd = Int(sampleRate * 0.240)
        for (available, expected) in [
            (tailStart, ModalPercussionWindowSupport.Availability.missing),
            (tailStart + 1, .partial), (tailEnd - 1, .partial),
            (tailEnd, .complete), (tailEnd + 1, .complete),
        ] {
            var state = ModalPercussionVoiceState()
            var output = [Float](repeating: 0, count: onset + available)
            let rendered = ModalPercussionVoice.renderBar(
                into: &output, bar: 0, sampleRate: sampleRate,
                events: [ScheduledModalPercussionEvent(
                    articulation: articulation(), startFrame: onset, level: 0
                )], state: &state
            )
            let event = try #require(rendered.events.first)
            let support = event.windowSupport
            #expect(support.isValid(sampleRate: sampleRate, frameCount: output.count))
            #expect(support.attack(sampleRate: sampleRate) == .complete)
            #expect(support.body(sampleRate: sampleRate) == .complete)
            #expect(support.tail(sampleRate: sampleRate) == expected)
            #expect(event.tailRMS == 0)
            #expect(output.allSatisfy { $0 == 0 })
            let ratio = support.tailToBodyDB(tailRMS: 0, bodyRMS: 0.05,
                                             sampleRate: sampleRate)
            #expect(ratio == (expected == .complete ? -120 : nil))
            #expect(support.tailToBodyDB(tailRMS: 0, bodyRMS: 1e-20,
                                        sampleRate: sampleRate) ==
                    (expected == .complete ? -120 : nil))
            #expect(support.tailToBodyDB(tailRMS: Double.leastNonzeroMagnitude,
                                        bodyRMS: Double.leastNonzeroMagnitude,
                                        sampleRate: sampleRate) ==
                    (expected == .complete ? 0 : nil))
            #expect(support.tailToBodyDB(tailRMS: 0, bodyRMS: 0,
                                        sampleRate: sampleRate) == nil)
            let json = try JSONEncoder().encode(support)
            #expect(try JSONDecoder().decode(ModalPercussionWindowSupport.self,
                                             from: json) == support)
            let forged = ModalPercussionWindowSupport(
                startFrame: onset, attackSampleCount: support.attackSampleCount,
                bodySampleCount: support.bodySampleCount,
                tailSampleCount: support.tailSampleCount + 1
            )
            #expect(!forged.isValid(sampleRate: sampleRate, frameCount: output.count))
        }
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
        let legacyRebuilt = ModalPercussionBarRenderEvidence(
            bar: rebuiltEvidence.bar, sampleRate: rebuiltEvidence.sampleRate,
            renderedFrameCount: rebuiltEvidence.renderedFrameCount,
            incomingStateFingerprint: rebuiltEvidence.incomingStateFingerprint,
            outgoingStateFingerprint: rebuiltEvidence.outgoingStateFingerprint,
            dryBarSampleHash: rebuiltEvidence.dryBarSampleHash,
            dryBarPeak: rebuiltEvidence.dryBarPeak, dryBarRMS: rebuiltEvidence.dryBarRMS,
            activeIncomingVoiceCount: rebuiltEvidence.activeIncomingVoiceCount,
            activeOutgoingVoiceCount: rebuiltEvidence.activeOutgoingVoiceCount,
            continuationRendered: rebuiltEvidence.continuationRendered,
            events: rebuiltEvidence.events, continuousWindows: freshEvidence.continuousWindows,
            finite: rebuiltEvidence.finite)
        #expect(legacyRebuilt == freshEvidence)
        #expect(rebuiltEvidence.continuousWindows.completed.first?.status == .routeChange)
        #expect(rebuiltEvidence.continuousWindows.completed.first?.observedFrameCount == oldRoute.count)
        #expect(rebuiltEvidence.continuousWindows.pending == freshEvidence.continuousWindows.pending)
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
        seed: UInt64 = 0xA11CE,
        material: ModalPercussionMaterial = .stretchedMembrane,
        coupling: Double = 0.18,
        step: Int = 10
    ) -> ModalPercussionArticulation {
        ModalPercussionArticulation(
            scoreEventIndex: 0,
            step: step,
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
            seed: seed,
            material: material,
            coupling: coupling
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
