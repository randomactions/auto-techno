@testable import AutoTechnoDSP
import AutoTechnoCore
import Foundation
import Testing

@Suite("Unified phrase composition")
struct PhraseCompositionTests {
    @Test("Band-limited slicing rejects rate-induced alias energy")
    func bandLimitedSliceRejectsAliasEnergy() {
        let sampleRate = 48_000.0
        let frameCount = 16_384
        let stepFrames = 4_096.0
        let sourceFrequency = 18_000.0
        var source = [Float](repeating: 0, count: frameCount)
        for index in source.indices {
            source[index] = Float(
                sin(2 * .pi * sourceFrequency * Double(index) / sampleRate)
            )
        }
        let plan = AudioSlicePlan(
            sourceStartStep: 0,
            sourceLengthInSteps: 2,
            triggers: [
                AudioSliceTrigger(
                    onsetStep: 0,
                    playbackRate: 2,
                    direction: .forward,
                    gain: 0.5
                ),
            ]
        )
        var output = [Float](repeating: 0, count: frameCount)
        _ = AudioSliceRenderer.render(
            source: source,
            output: &output,
            plan: plan,
            stepFrames: stepFrames,
            sampleRate: sampleRate
        )

        var legacyLinear = [Float](repeating: 0, count: frameCount)
        let fadeFrames = Int((sampleRate * AudioSliceRenderer.edgeFadeSeconds).rounded())
        for index in 0..<4_096 {
            let fadeIn = min(1, Double(index + 1) / Double(fadeFrames))
            let fadeOut = min(1, Double(4_096 - index) / Double(fadeFrames))
            legacyLinear[index] = source[index * 2] * Float(
                0.5 * min(fadeIn, fadeOut)
            )
        }
        let measurementRange = 512..<3_584
        let aliasFrequency = 12_000.0
        func projectedAmplitude(_ signal: [Float]) -> Double {
            let projection = measurementRange.reduce(
                into: (sine: 0.0, cosine: 0.0)
            ) { partial, index in
                let phase = 2 * Double.pi * aliasFrequency *
                    Double(index) / sampleRate
                partial.sine += Double(signal[index]) * sin(phase)
                partial.cosine += Double(signal[index]) * cos(phase)
            }
            return 2 * hypot(projection.sine, projection.cosine) /
                Double(measurementRange.count)
        }
        let legacyAliasAmplitude = projectedAmplitude(legacyLinear)
        let bandLimitedAliasAmplitude = projectedAmplitude(output)
        let rejectionDB = 20 * log10(
            bandLimitedAliasAmplitude / legacyAliasAmplitude
        )

        #expect(abs(legacyAliasAmplitude - 0.5) < 1e-12)
        #expect(bandLimitedAliasAmplitude < 0.005)
        #expect(rejectionDB < -40)
    }

    @Test("Band-limited slicing retains an in-band transposed tone")
    func bandLimitedSliceRetainsPassband() {
        let sampleRate = 48_000.0
        let frameCount = 16_384
        let stepFrames = 4_096.0
        var source = [Float](repeating: 0, count: frameCount)
        for index in source.indices {
            source[index] = Float(
                sin(2 * .pi * 3_000 * Double(index) / sampleRate)
            )
        }
        let plan = AudioSlicePlan(
            sourceStartStep: 0,
            sourceLengthInSteps: 2,
            triggers: [
                AudioSliceTrigger(onsetStep: 0, playbackRate: 2,
                                  direction: .forward, gain: 0.5),
            ]
        )
        var output = [Float](repeating: 0, count: frameCount)
        let evidence = AudioSliceRenderer.render(
            source: source,
            output: &output,
            plan: plan,
            stepFrames: stepFrames,
            sampleRate: sampleRate
        )
        let measurementRange = 512..<3_584
        let projection = measurementRange.reduce(
            into: (sine: 0.0, cosine: 0.0)
        ) { partial, index in
            let phase = 2 * Double.pi * 6_000 * Double(index) / sampleRate
            partial.sine += Double(output[index]) * sin(phase)
            partial.cosine += Double(output[index]) * cos(phase)
        }
        let amplitude = 2 * hypot(projection.sine, projection.cosine) /
            Double(measurementRange.count)

        #expect(evidence.active && evidence.finite)
        #expect(abs(amplitude - 0.5) < 0.01)
    }

    @Test("Unity-rate slicing preserves the exact existing PCM path")
    func unityRateSliceIsExact() {
        let sampleRate = 8_000.0
        let frameCount = 4_096
        let stepFrames = 512.0
        let source = (0..<frameCount).map { index in
            Float(sin(Double(index) * 0.071) * 0.73)
        }
        let plan = AudioSlicePlan(
            sourceStartStep: 0,
            sourceLengthInSteps: 1,
            triggers: [
                AudioSliceTrigger(onsetStep: 0, playbackRate: 1,
                                  direction: .forward, gain: 0.5),
            ]
        )
        var output = [Float](repeating: 0, count: frameCount)
        let evidence = AudioSliceRenderer.render(
            source: source,
            output: &output,
            plan: plan,
            stepFrames: stepFrames,
            sampleRate: sampleRate
        )
        let fadeFrames = Int((sampleRate * AudioSliceRenderer.edgeFadeSeconds).rounded())
        var expected = [Float](repeating: 0, count: frameCount)
        for index in 0..<512 {
            let fadeIn = min(1, Double(index + 1) / Double(fadeFrames))
            let fadeOut = min(1, Double(512 - index) / Double(fadeFrames))
            expected[index] = Float(
                Double(source[index]) * 0.5 * min(fadeIn, fadeOut)
            )
        }

        #expect(output == expected)
        #expect(evidence.active && evidence.finite)
        #expect(evidence.minimumPlaybackRate == 1)
        #expect(evidence.maximumPlaybackRate == 1)
        #expect(evidence.texture == .cut)
        #expect(evidence.textureSeedFingerprint.isEmpty)
        #expect(evidence.grainCount == 0)
        #expect(evidence.grainSourcePositionHash.isEmpty)
    }

    @Test("Invalid slice input remains an exact neutral fallback")
    func invalidSliceInputIsNeutral() {
        let plan = AudioSlicePlan(
            sourceStartStep: 0,
            sourceLengthInSteps: 1,
            triggers: [
                AudioSliceTrigger(onsetStep: 0, playbackRate: 2,
                                  direction: .reverse, gain: 0.5),
            ]
        )
        var output = [Float](repeating: 0, count: 64)
        let evidence = AudioSliceRenderer.render(
            source: [0],
            output: &output,
            plan: plan,
            stepFrames: 8,
            sampleRate: 8_000
        )

        #expect(evidence == .neutral)
        #expect(output.allSatisfy { $0 == 0 })
    }

    @Test("True slice playback reads rendered PCM at bounded rates and directions")
    func trueAudioSlicing() throws {
        let sampleRate = 8_000.0
        let frameCount = 8_000
        let stepFrames = Double(frameCount) / 16
        var source = [Float](repeating: 0, count: frameCount)
        let sourceStart = Int(stepFrames * 2)
        for index in 0..<Int(stepFrames) {
            source[sourceStart + index] = Float(
                sin(2 * .pi * 317 * Double(index) / sampleRate) *
                    exp(-Double(index) / 1_300)
            )
        }
        let plan = AudioSlicePlan(
            sourceStartStep: 2,
            sourceLengthInSteps: 1,
            triggers: [
                AudioSliceTrigger(onsetStep: 8, playbackRate: 0.75,
                                  direction: .forward, gain: 0.31),
                AudioSliceTrigger(onsetStep: 11, playbackRate: 1.5,
                                  direction: .reverse, gain: 0.27),
                AudioSliceTrigger(onsetStep: 14, playbackRate: 2,
                                  direction: .forward, gain: 0.22),
            ]
        )
        var first = [Float](repeating: 0, count: frameCount)
        var replay = [Float](repeating: 0, count: frameCount)
        let firstEvidence = AudioSliceRenderer.render(
            source: source, output: &first, plan: plan,
            stepFrames: stepFrames, sampleRate: sampleRate
        )
        let replayEvidence = AudioSliceRenderer.render(
            source: source, output: &replay, plan: plan,
            stepFrames: stepFrames, sampleRate: sampleRate
        )

        #expect(first == replay)
        #expect(firstEvidence == replayEvidence)
        #expect(firstEvidence.active)
        #expect(firstEvidence.triggerCount == 3)
        #expect(firstEvidence.reverseTriggerCount == 1)
        #expect(firstEvidence.minimumPlaybackRate == 0.75)
        #expect(firstEvidence.maximumPlaybackRate == 2)
        #expect(firstEvidence.sourceSampleHash != firstEvidence.outputSampleHash)
        #expect(firstEvidence.outputRMS > 0)
        #expect(first.allSatisfy { $0.isFinite })
        #expect(first[..<Int(stepFrames * 8)].allSatisfy { $0 == 0 })
    }

    @Test("Granular memory is deterministic, seed-bound, and rate-scaled")
    func granularMemoryIsDeterministicAndRateScaled() {
        func render(sampleRate: Double, seed: UInt64) ->
                (samples: [Float], evidence: AudioSliceRenderEvidence) {
            let frameCount = Int(sampleRate * 2)
            let stepFrames = sampleRate * 60 /
                AutonomousSessionDirector.bpm / 4
            let source = (0..<frameCount).map { index in
                let time = Double(index) / sampleRate
                return Float(
                    (sin(2 * .pi * 173 * time) * 0.52) +
                    (sin(2 * .pi * 431 * time) * 0.19) +
                    (sin(2 * .pi * 0.7 * time) * 0.08)
                )
            }
            let plan = AudioSlicePlan(
                sourceStartStep: 0,
                sourceLengthInSteps: 2,
                texture: .granularMemory,
                textureSeed: seed,
                triggers: [
                    AudioSliceTrigger(
                        onsetStep: 2,
                        playbackRate: 0.75,
                        direction: .forward,
                        gain: 0.31
                    ),
                    AudioSliceTrigger(
                        onsetStep: 7,
                        playbackRate: 1.5,
                        direction: .reverse,
                        gain: 0.24
                    ),
                ]
            )
            var output = [Float](repeating: 0, count: frameCount)
            let evidence = AudioSliceRenderer.render(
                source: source,
                output: &output,
                plan: plan,
                stepFrames: stepFrames,
                sampleRate: sampleRate
            )
            return (output, evidence)
        }

        let first = render(sampleRate: 8_000, seed: 0xA11CE)
        let replay = render(sampleRate: 8_000, seed: 0xA11CE)
        let changedSeed = render(sampleRate: 8_000, seed: 0xB0B)
        let higherRate = render(sampleRate: 16_000, seed: 0xA11CE)

        #expect(first.samples == replay.samples)
        #expect(first.evidence == replay.evidence)
        #expect(first.samples != changedSeed.samples)
        #expect(first.evidence.grainSourcePositionHash !=
                changedSeed.evidence.grainSourcePositionHash)
        #expect(first.evidence.active && first.evidence.finite)
        #expect(first.evidence.texture == .granularMemory)
        #expect(first.evidence.textureSeedFingerprint.count == 16)
        #expect(first.evidence.grainCount > 0)
        #expect(first.evidence.grainCount <=
                AudioSlicePlan.maximumTriggerCount *
                    AudioSliceRenderer.maximumGrainsPerTrigger)
        #expect(first.evidence.grainHopFrames <=
                first.evidence.grainLengthFrames)
        #expect(first.evidence.grainSourcePositionHash.count == 16)
        #expect(first.evidence.outputRMS > 0)
        #expect(first.samples.allSatisfy { $0.isFinite })
        let firstDuration = Double(first.evidence.grainLengthFrames) / 8_000
        let higherRateDuration = Double(
            higherRate.evidence.grainLengthFrames
        ) / 16_000
        #expect(abs(firstDuration - higherRateDuration) < 1 / 8_000)
    }

    @Test("Four independent modal pad voices render simultaneous bounded PCM")
    func polyphonicPadPCM() {
        let voices = [0, 3, 7, 10].map {
            PadVoice(modalDegree: $0, semitone: $0)
        }
        let voicing = PadVoicing(
            function: .tonic,
            onsetStep: 0,
            durationInSteps: 16,
            voices: voices,
            previousVoices: voices,
            instrument: InstrumentPalette.safeUpper(role: .atmosphere)
        )
        let sampleRate = 8_000.0
        let frameCount = Int((240 / AutonomousSessionDirector.bpm * sampleRate).rounded())
        var output = [Float](repeating: 0, count: frameCount)
        var measurement = output
        var send = output
        var state = PolyphonicPadState()
        let evidence = PolyphonicPadVoice.render(
            &output,
            measurement: &measurement,
            spatialReverbSend: &send,
            voicing: voicing,
            rootFrequency: 65.41,
            sampleRate: sampleRate,
            stepFrames: Double(frameCount) / 16,
            level: 0.04,
            state: &state
        )

        #expect(evidence.active)
        #expect(evidence.voiceCount == 4)
        #expect(evidence.requestedFrequencyRatios.count == 4)
        #expect(Set(evidence.requestedFrequencyRatios).count == 4)
        #expect(evidence.outputRMS > 0)
        #expect(evidence.outputPeak > evidence.outputRMS)
        #expect(output.contains { $0 != 0 })
        #expect(send.contains { $0 != 0 })
        #expect(evidence.finite && output.allSatisfy { $0.isFinite })
    }

    @Test("A held pad acquires one score-owned three-step timbre rhythm")
    func rhythmicPadScoreOwnership() throws {
        let scene = fixtureScene()
        let dna = SceneDNA(scene: scene)
        let bars = (8...10).map { bar in
            fixtureResolved(
                bar: bar,
                section: .breakdown,
                character: .ambientDrift,
                roles: [.foundation, .atmosphere],
                events: [
                    EnsembleResolvedEvent(
                        voice: .atmosphere, step: 0,
                        intensity: 0.55, relocated: false
                    ),
                    EnsembleResolvedEvent(
                        voice: .kick, step: 0,
                        intensity: 1, relocated: false
                    ),
                ],
                arrangementGesture: .steady,
                interlockChapter: .breath
            )
        }
        let composition = PhraseCompositionResolver.resolve(
            scene: scene,
            dna: dna,
            kind: .majorBreak,
            resolvedBars: bars
        )
        let modulations = try composition.map {
            try #require($0.padVoicing).rhythmicModulation
        }

        #expect(modulations.map(\.relation) == [
            .threeStepPulse, .threeStepPulse, .threeStepPulse,
        ])
        #expect(modulations.map(\.phaseOffset) == [2, 0, 1])
        #expect(modulations[0].filterScale(atStep: 0) == 0.62)
        #expect(modulations[0].filterScale(atStep: 1) == 0.38)
        #expect(modulations[0].filterScale(atStep: 2) == 1)
        #expect(modulations[0].spatialSendScale(atStep: 0) == 1.28)
        #expect((0..<6).map {
            modulations[0].amplitudeGateTarget(atStep: $0)
        } == [0, 0, 1, 0, 0, 1])

        let first = PhraseCompositionResolver.resolve(
            scene: scene, dna: dna, kind: .majorBreak,
            resolvedBars: Array(bars.prefix(2))
        )
        let continuation = HarmonicContinuationState(
            voices: try #require(first.last?.padVoicing).voices
        )
        let split = PhraseCompositionResolver.resolve(
            scene: scene, dna: dna, kind: .majorBreak,
            resolvedBars: [bars[2]], harmonicContinuation: continuation
        )
        #expect(split.first?.padVoicing == composition[2].padVoicing)

        let minimal = fixtureResolved(
            bar: 8, section: .breakdown, character: .ambientDrift,
            roles: [.foundation, .atmosphere], events: bars[0].ensemble.events,
            arrangementGesture: .minimalize, interlockChapter: .breath
        )
        let early = fixtureResolved(
            bar: 4, section: .breakdown, character: .ambientDrift,
            roles: [.foundation, .atmosphere], events: bars[0].ensemble.events,
            arrangementGesture: .steady, interlockChapter: .breath
        )
        for neutralBar in [minimal, early] {
            let neutral = PhraseCompositionResolver.resolve(
                scene: scene, dna: dna, kind: .majorBreak,
                resolvedBars: [neutralBar]
            )
            #expect(neutral.first?.padVoicing?.rhythmicModulation == .neutral)
        }
    }

    @Test("Pad rhythmic motion gates only the existing pad and spatial send")
    func rhythmicPadPCMAndNeutralIdentity() {
        let voices = [0, 3, 7, 10].map {
            PadVoice(modalDegree: $0, semitone: $0)
        }
        let neutral = PadVoicing(
            function: .tonic, onsetStep: 0, durationInSteps: 16,
            voices: voices, previousVoices: voices,
            instrument: InstrumentPalette.safeUpper(role: .atmosphere)
        )
        let active = PadVoicing(
            function: neutral.function,
            onsetStep: neutral.onsetStep,
            durationInSteps: neutral.durationInSteps,
            voices: neutral.voices,
            previousVoices: neutral.voices,
            instrument: neutral.instrument,
            rhythmicModulation: PadRhythmicModulation(
                relation: .threeStepPulse,
                phaseOffset: 1
            )
        )

        for sampleRate in [8_000.0, 44_100, 48_000, 96_000, 192_000] {
            let frameCount = Int((
                240 / AutonomousSessionDirector.bpm * sampleRate
            ).rounded())
            func render(_ voicing: PadVoicing) -> (
                [Float], [Float], PolyphonicPadState,
                PolyphonicPadRenderEvidence
            ) {
                var output = [Float](repeating: 0, count: frameCount)
                var measurement = output
                var send = output
                var state = PolyphonicPadState()
                let evidence = PolyphonicPadVoice.render(
                    &output,
                    measurement: &measurement,
                    spatialReverbSend: &send,
                    voicing: voicing,
                    rootFrequency: 65.41,
                    sampleRate: sampleRate,
                    stepFrames: Double(frameCount) / 16,
                    level: 0.04,
                    state: &state
                )
                return (output, send, state, evidence)
            }

            let baseline = render(neutral)
            let explicitNeutral = render(PadVoicing(
                function: neutral.function,
                onsetStep: neutral.onsetStep,
                durationInSteps: neutral.durationInSteps,
                voices: neutral.voices,
                previousVoices: neutral.voices,
                instrument: neutral.instrument,
                rhythmicModulation: .neutral
            ))
            let modulated = render(active)

            #expect(baseline.0 == explicitNeutral.0)
            #expect(baseline.1 == explicitNeutral.1)
            #expect(baseline.2 == explicitNeutral.2)
            #expect(baseline.3 == explicitNeutral.3)
            #expect(baseline.3.rhythmicModulationRelation == .neutral)
            #expect(baseline.3.filterModulationDifferenceRMS == 0)
            #expect(baseline.3.spatialSendDifferenceRMS == 0)
            #expect(baseline.3.minimumAmplitudeGateGain == 1)
            #expect(baseline.3.maximumAmplitudeGateGain == 1)
            #expect(baseline.3.amplitudeGateTransitionFrameCount == 0)
            #expect(baseline.3.amplitudeGateClosedFrameCount == 0)
            #expect(baseline.3.amplitudeGateDifferenceRMS == 0)
            #expect(baseline.3.spatialAmplitudeGateDifferenceRMS == 0)
            #expect(baseline.3.preAmplitudeGateOutputSampleHash ==
                    baseline.3.outputSampleHash)
            #expect(baseline.3.preAmplitudeGateSpatialSendSampleHash ==
                    baseline.3.spatialSendSampleHash)

            #expect(modulated.0 != baseline.0)
            #expect(modulated.1 != baseline.1)
            #expect(modulated.3.renderedFrameCount == frameCount)
            #expect(modulated.3.rhythmicModulationRelation == .threeStepPulse)
            #expect(modulated.3.rhythmicModulationPhaseOffset == 1)
            #expect(modulated.3.minimumFilterScale == 0.38)
            #expect(modulated.3.maximumFilterScale == 1)
            #expect(modulated.3.minimumSpatialSendScale == 0.72)
            #expect(modulated.3.maximumSpatialSendScale == 1.28)
            #expect(modulated.3.filterModulationDifferenceRMS > 0)
            #expect(modulated.3.spatialSendDifferenceRMS > 0)
            #expect(modulated.3.minimumAmplitudeGateGain == 0)
            #expect(modulated.3.maximumAmplitudeGateGain == 1)
            #expect(modulated.3.amplitudeGateTransitionFrameCount == max(
                2,
                Int((sampleRate * PolyphonicPadVoice
                    .amplitudeGateTransitionSeconds).rounded())
            ))
            #expect(modulated.3.amplitudeGateOpenFrameCount > 0)
            #expect(modulated.3.amplitudeGateClosedFrameCount >
                    modulated.3.amplitudeGateOpenFrameCount)
            #expect(modulated.3.amplitudeGateDifferenceRMS > 0)
            #expect(modulated.3.spatialAmplitudeGateDifferenceRMS > 0)
            #expect(modulated.3.amplitudeGateClosedOutputRMS == 0)
            #expect(modulated.3.amplitudeGateClosedSpatialSendRMS == 0)
            #expect(modulated.3.preAmplitudeGateOutputSampleHash !=
                    modulated.3.outputSampleHash)
            #expect(modulated.3.preAmplitudeGateSpatialSendSampleHash !=
                    modulated.3.spatialSendSampleHash)
            #expect(modulated.3.spatialSendRMS > 0)
            #expect(modulated.3.outputSampleHash != baseline.3.outputSampleHash)
            #expect(modulated.3.spatialSendSampleHash !=
                    baseline.3.spatialSendSampleHash)
            #expect(modulated.3.finite)
            #expect(modulated.0.allSatisfy { $0.isFinite })
            #expect(modulated.1.allSatisfy { $0.isFinite })
            for index in modulated.0.indices {
                let step = min(
                    PadRhythmicModulation.stepCount - 1,
                    Int(Double(index) / (Double(frameCount) / 16))
                )
                if active.rhythmicModulation.amplitudeGateTarget(
                    atStep: step
                ) == 0 {
                    #expect(modulated.0[index].bitPattern & 0x7fff_ffff == 0)
                    #expect(modulated.1[index].bitPattern & 0x7fff_ffff == 0)
                }
            }
        }
    }

    @MainActor
    @Test("Prepared evidence binds the score-owned pad rhythm to its PCM")
    func rhythmicPadCandidateEvidence() throws {
        try verifyRhythmicPadCandidateEvidence()
    }

    @inline(never)
    private func verifyRhythmicPadCandidateEvidence() throws {
        let director = AutonomousSessionDirector()
        var state = director.initialState()

        for _ in 0..<128 {
            let plan = director.plan(from: state)
            let activeIndexes = plan.phraseComposition.indices.filter {
                plan.phraseComposition[$0].padVoicing?
                    .rhythmicModulation.active == true
            }
            guard !activeIndexes.isEmpty else {
                state.advancePlanning(using: plan)
                continue
            }

            var renderState = RenderState()
            renderState.barIndex = state.memory.totalBars
            let prepared = AutonomousPhrasePreparer.prepare(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: renderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator()
            )
            let vector = prepared.selectedCandidateEvidence
            #expect(prepared.candidateEvaluation.isComplete)
            #expect(vector.isComplete)
            #expect(vector.phraseComposition.count == plan.barCount)

            for index in activeIndexes {
                let score = try #require(
                    plan.phraseComposition[index].padVoicing
                ).rhythmicModulation
                let record = vector.phraseComposition[index]
                #expect(record.bar == plan.resolvedBars[index].performance.bar)
                #expect(record.section == SectionKind.breakdown.rawValue)
                #expect(record.padRhythmicModulationRelation ==
                        PadRhythmicModulationRelation.threeStepPulse.rawValue)
                #expect(record.padRhythmicModulationPhaseOffset ==
                        score.phaseOffset)
                #expect(record.padRhythmicModulationPatternFingerprint ==
                        PadRhythmicModulationFingerprint.make(score))
                #expect(record.padFilterModulationDifferenceRMS > 0)
                #expect(record.padSpatialSendDifferenceRMS > 0)
                #expect(record.padMinimumAmplitudeGateGain == 0)
                #expect(record.padMaximumAmplitudeGateGain == 1)
                #expect(record.padAmplitudeGateTransitionFrameCount > 1)
                #expect(record.padAmplitudeGateOpenFrameCount > 0)
                #expect(record.padAmplitudeGateClosedFrameCount >
                        record.padAmplitudeGateOpenFrameCount)
                #expect(record.padAmplitudeGateDifferenceRMS > 0)
                #expect(record.padSpatialAmplitudeGateDifferenceRMS > 0)
                #expect(record.padAmplitudeGateClosedOutputRMS == 0)
                #expect(record.padAmplitudeGateClosedSpatialSendRMS == 0)
                #expect(record.padPreAmplitudeGateOutputSampleHash !=
                        record.padSampleHash)
                #expect(record.padPreAmplitudeGateSpatialSendSampleHash !=
                        record.padSpatialSendSampleHash)
                #expect(record.padSpatialSendRMS > 0)
                #expect(record.bindingValid && record.finite)
                #expect(record.isComplete(
                    phraseKind: plan.kind.rawValue,
                    expectedLocalBar: index,
                    expectedPhraseLength: plan.barCount,
                    expectedSampleRate: 8_000
                ))
            }

            let activeRecords = activeIndexes.map {
                vector.phraseComposition[$0]
            }
            let observation = try ProfessionalQualityObservation(
                candidate: vector,
                engineVersion: QualityQualificationContract.engineVersion,
                checkpoint: .majorBreak
            )
            #expect(observation[.padRhythmicModulationActiveBarRatio] ==
                    Double(activeRecords.count) / Double(plan.barCount))
            func decibels(_ numerator: Double, _ denominator: Double) -> Double {
                min(120, max(-120,
                    20 * (log10(numerator) - log10(denominator))
                ))
            }
            #expect(observation[.padRhythmicFilterDifferenceToPadDBMean] ==
                    activeRecords.map {
                        decibels(
                            $0.padFilterModulationDifferenceRMS,
                            $0.padRMS
                        )
                    }.reduce(0, +) / Double(activeRecords.count))
            #expect(observation[.padRhythmicSpatialDifferenceToSendDBMean] ==
                    activeRecords.map {
                        decibels(
                            $0.padSpatialSendDifferenceRMS,
                            $0.padSpatialSendRMS
                        )
                    }.reduce(0, +) / Double(activeRecords.count))
            #expect(observation[
                .padRhythmicAmplitudeGateDifferenceToPadDBMean
            ] == activeRecords.map {
                decibels(
                    $0.padAmplitudeGateDifferenceRMS,
                    $0.padRMS
                )
            }.reduce(0, +) / Double(activeRecords.count))
            #expect(observation[.padHarmonicDisclosureRevealedBarRatio] ==
                    Double(vector.phraseComposition.filter {
                        $0.padActive && $0.padHarmonicDisclosureStage ==
                            PadHarmonicDisclosureStage.revealed.rawValue
                    }.count) / Double(plan.barCount))
            #expect(observation[
                .padHarmonicDisclosureDistinctFunctionCount
            ] == Double(Set(vector.phraseComposition.filter(\.padActive).map {
                $0.padFunction
            }).count))

            let record = vector.phraseComposition[try #require(activeIndexes.first)]
            let encoded = try JSONEncoder().encode(record)
            let json = try #require(
                JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            )
            let keys = Set(json.keys)
            #expect(keys.isSuperset(of: [
                "localBar", "phraseLength", "section", "arrangementGesture",
                "arpeggiatorScorePitchFingerprint",
                "arpeggiatorRenderPitchFingerprint",
                "padHarmonicDisclosureStage",
                "padRhythmicModulationRelation",
                "padRhythmicModulationPhaseOffset",
                "padRhythmicModulationPatternFingerprint",
                "padFilterModulationDifferenceRMS",
                "padSpatialSendDifferenceRMS",
                "padMinimumAmplitudeGateGain",
                "padMaximumAmplitudeGateGain",
                "padAmplitudeGateTransitionFrameCount",
                "padAmplitudeGateOpenFrameCount",
                "padAmplitudeGateClosedFrameCount",
                "padPreAmplitudeGateOutputSampleHash",
                "padPreAmplitudeGateSpatialSendSampleHash",
                "padAmplitudeGateDifferenceRMS",
                "padSpatialAmplitudeGateDifferenceRMS",
                "padAmplitudeGateClosedOutputRMS",
                "padAmplitudeGateClosedSpatialSendRMS",
                "padSpatialSendSampleHash", "padSpatialSendRMS",
            ]))

            func forged(_ key: String, _ value: Any) throws
                    -> AutonomousPhraseCompositionBarEvidence {
                var changed = json
                changed[key] = value
                return try JSONDecoder().decode(
                    AutonomousPhraseCompositionBarEvidence.self,
                    from: JSONSerialization.data(withJSONObject: changed)
                )
            }
            func forged(_ updates: [String: Any]) throws
                    -> AutonomousPhraseCompositionBarEvidence {
                var changed = json
                for (key, value) in updates { changed[key] = value }
                return try JSONDecoder().decode(
                    AutonomousPhraseCompositionBarEvidence.self,
                    from: JSONSerialization.data(withJSONObject: changed)
                )
            }
            let wrongPhase = (record.padRhythmicModulationPhaseOffset + 1) %
                PadRhythmicModulation.cellLength
            let wrongPhaseModulation = PadRhythmicModulation(
                relation: .threeStepPulse,
                phaseOffset: wrongPhase
            )
            let tampered = try [
                forged("section", SectionKind.groove.rawValue),
                forged("arrangementGesture",
                       ArrangementGesture.minimalize.rawValue),
                forged("padRhythmicModulationPhaseOffset", 3),
                forged([
                    "padRhythmicModulationPhaseOffset": wrongPhase,
                    "padRhythmicModulationPatternFingerprint":
                        PadRhythmicModulationFingerprint.make(
                            wrongPhaseModulation
                        ),
                ]),
                forged("padRhythmicModulationPatternFingerprint",
                       "0000000000000000"),
                forged("localBar", record.localBar + 1),
                forged("phraseLength", record.phraseLength + 1),
                forged("padHarmonicDisclosureStage",
                       PadHarmonicDisclosureStage.concealed.rawValue),
                forged("padFilterModulationDifferenceRMS", 0),
                forged("padSpatialSendDifferenceRMS", 0),
                forged("padMinimumAmplitudeGateGain", 0.1),
                forged("padMaximumAmplitudeGateGain", 0.9),
                forged("padAmplitudeGateTransitionFrameCount", 0),
                forged("padAmplitudeGateOpenFrameCount", 0),
                forged("padAmplitudeGateClosedFrameCount", 0),
                forged("padPreAmplitudeGateOutputSampleHash",
                       record.padSampleHash),
                forged("padPreAmplitudeGateSpatialSendSampleHash",
                       record.padSpatialSendSampleHash),
                forged("padAmplitudeGateDifferenceRMS", 0),
                forged("padSpatialAmplitudeGateDifferenceRMS", 0),
                forged("padAmplitudeGateClosedOutputRMS", 0.1),
                forged("padAmplitudeGateClosedSpatialSendRMS", 0.1),
            ]
            #expect(tampered.allSatisfy {
                !$0.isComplete(
                    phraseKind: plan.kind.rawValue,
                    expectedLocalBar: record.localBar,
                    expectedPhraseLength: record.phraseLength,
                    expectedSampleRate: 8_000
                )
            })
            return
        }
        Issue.record("Expected a naturally reachable rhythmic pad phrase")
    }

    @Test("Arpeggiation and pad harmony share modal pitches and minimal motion")
    func harmonicComposition() throws {
        let scene = fixtureScene()
        let dna = SceneDNA(scene: scene)
        let bars = (0..<16).map { bar in
            fixtureResolved(
                bar: bar,
                section: .groove,
                character: .melodicGlow,
                roles: [.motif, .atmosphere, .percussion],
                events: [
                    EnsembleResolvedEvent(voice: .motif, step: 2,
                                          intensity: 0.72, relocated: false),
                    EnsembleResolvedEvent(voice: .atmosphere, step: 0,
                                          intensity: 0.54, relocated: false),
                    EnsembleResolvedEvent(voice: .percussion, step: 1,
                                          intensity: 0.64, relocated: false),
                ]
            )
        }
        let composition = PhraseCompositionResolver.resolve(
            scene: scene, dna: dna, kind: .lock,
            resolvedBars: bars
        )

        #expect(composition.count == 16)
        #expect(composition.allSatisfy { $0.arpeggiator != nil && $0.padVoicing != nil })
        for bar in composition {
            let pad = try #require(bar.padVoicing)
            let arpeggiator = try #require(bar.arpeggiator)
            #expect(pad.voices.count == 4)
            #expect(pad.maximumLeapInSemitones <= 12)
            #expect(pad.totalMovementInSemitones <= 24)
            #expect(arpeggiator.steps.count >= 8)
            #expect(arpeggiator.steps.count <= 16)
            #expect(arpeggiator.steps.map(\.onsetStep) ==
                    arpeggiator.steps.map(\.onsetStep).sorted())
            #expect(arpeggiator.steps.allSatisfy { step in
                dna.modalDegrees.contains(where: { degree in
                    abs(((Int(round(12 * log2(step.frequencyRatio))) - degree) % 12 + 12) % 12) == 0
                })
            })
        }
        #expect(Set(composition.compactMap { $0.padVoicing?.function }).count >= 3)
        #expect(Set(composition.compactMap { $0.arpeggiator?.direction }).count >= 2)
    }

    @Test("Harmonic disclosure conceals, previews, reveals, and contracts")
    func harmonicDisclosureGeometry() {
        for phraseLength in 4...16 {
            let lockStages = (0..<phraseLength).map { localBar in
                PhraseCompositionResolver.harmonicDisclosureStage(
                    kind: .lock,
                    localBar: localBar,
                    phraseLength: phraseLength
                )
            }
            #expect(lockStages.prefix(phraseLength / 2).allSatisfy {
                $0 == .concealed
            })
            #expect(lockStages.dropFirst(phraseLength / 2).allSatisfy {
                $0 == .partial
            })

            let lockFunctions = (0..<phraseLength).map { localBar in
                PhraseCompositionResolver.disclosedHarmonicFunction(
                    established: .subdominant,
                    kind: .lock,
                    localBar: localBar,
                    phraseLength: phraseLength
                )
            }
            #expect(lockFunctions.prefix(phraseLength / 2).allSatisfy {
                $0 == .tonic
            })
            #expect(Set(lockFunctions).isSubset(of: [.tonic, .modalColor]))
            #expect(lockFunctions.last == .modalColor)

            let revealed = (0..<phraseLength).map { localBar in
                PhraseCompositionResolver.disclosedHarmonicFunction(
                    established: .returnPull,
                    kind: .majorBreak,
                    localBar: localBar,
                    phraseLength: phraseLength
                )
            }
            #expect(revealed == (0..<phraseLength).map { localBar in
                [PadHarmonicFunction.tonic, .modalColor, .subdominant,
                 .returnPull][localBar % 4]
            })
            #expect((0..<phraseLength).allSatisfy { localBar in
                PhraseCompositionResolver.harmonicDisclosureStage(
                    kind: .majorBreak,
                    localBar: localBar,
                    phraseLength: phraseLength
                ) == .revealed
            })

            for kind in [AutonomousPhraseKind.contrast, .energyRelease,
                         .identityReturn] {
                #expect((0..<phraseLength).allSatisfy { localBar in
                    PhraseCompositionResolver.harmonicDisclosureStage(
                        kind: kind,
                        localBar: localBar,
                        phraseLength: phraseLength
                    ) == .established &&
                    PhraseCompositionResolver.disclosedHarmonicFunction(
                        established: .subdominant,
                        kind: kind,
                        localBar: localBar,
                        phraseLength: phraseLength
                    ) == .subdominant
                })
            }
        }
    }

    @Test("One disclosed chord changes only its existing tonal carriers")
    func harmonicDisclosurePCMIsolation() throws {
        let scene = fixtureScene()
        let dna = SceneDNA(scene: scene)
        let resolved = fixtureResolved(
            bar: 2,
            section: .groove,
            character: .melodicGlow,
            roles: [.motif, .atmosphere, .percussion],
            events: [
                EnsembleResolvedEvent(
                    voice: .motif, step: 2,
                    intensity: 0.72, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .atmosphere, step: 0,
                    intensity: 0.54, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .percussion, step: 1,
                    intensity: 0.64, relocated: false
                ),
            ],
            arrangementGesture: .steady,
            interlockChapter: .breath
        )
        let disclosedComposition = try #require(
            PhraseCompositionResolver.resolve(
                scene: scene, dna: dna, kind: .lock,
                resolvedBars: [resolved]
            ).first
        )
        let legacyComposition = try #require(
            PhraseCompositionResolver.resolve(
                scene: scene, dna: dna, kind: .contrast,
                resolvedBars: [resolved]
            ).first
        )
        let disclosedPad = try #require(disclosedComposition.padVoicing)
        let legacyPad = try #require(legacyComposition.padVoicing)
        #expect(disclosedPad.harmonicDisclosureStage == .concealed)
        #expect(disclosedPad.function == .tonic)
        #expect(legacyPad.function == .subdominant)

        let establishedPad = PadVoicing(
            function: legacyPad.function,
            harmonicDisclosureStage: .established,
            onsetStep: disclosedPad.onsetStep,
            durationInSteps: disclosedPad.durationInSteps,
            voices: legacyPad.voices,
            previousVoices: legacyPad.voices,
            instrument: disclosedPad.instrument,
            rhythmicModulation: disclosedPad.rhythmicModulation
        )
        let establishedComposition = PhraseCompositionBar(
            bar: disclosedComposition.bar,
            audioSlice: disclosedComposition.audioSlice,
            arpeggiator: legacyComposition.arpeggiator,
            padVoicing: establishedPad
        )
        let disclosedSynth = SynthPerformancePlan(
            scene: scene, dna: dna, kind: .lock,
            resolvedBars: [resolved],
            compositionBars: [disclosedComposition]
        )
        let establishedSynth = SynthPerformancePlan(
            scene: scene, dna: dna, kind: .lock,
            resolvedBars: [resolved],
            compositionBars: [establishedComposition]
        )
        let disclosedBar = try #require(disclosedSynth.bars.first)
        let establishedBar = try #require(establishedSynth.bars.first)
        let disclosedAnchors = disclosedBar.upperNotes.filter {
            $0.role == .anchor
        }
        let establishedAnchors = establishedBar.upperNotes.filter {
            $0.role == .anchor
        }
        #expect(disclosedAnchors.map(\.onsetStep) ==
                establishedAnchors.map(\.onsetStep))
        #expect(disclosedAnchors.map(\.durationInSteps) ==
                establishedAnchors.map(\.durationInSteps))
        #expect(disclosedAnchors.map(\.velocity) ==
                establishedAnchors.map(\.velocity))
        #expect(disclosedAnchors.map(\.startFrequencyRatio) !=
                establishedAnchors.map(\.startFrequencyRatio))
        #expect(disclosedBar.upperNotes.filter { $0.role != .anchor } ==
                establishedBar.upperNotes.filter { $0.role != .anchor })

        func render(_ synth: SynthPerformancePlan,
                    _ bar: SynthPerformanceBar) -> RenderedBar {
            var state = RenderState()
            var workspace = RenderWorkspace()
            return VoiceRenderer.renderBar(
                scene: scene,
                sampleRate: 8_000,
                state: &state,
                dna: dna,
                resolved: resolved,
                synthWorld: synth.world,
                synthPerformance: bar,
                workspace: &workspace,
                layer: .full
            )
        }
        let disclosed = render(disclosedSynth, disclosedBar)
        let established = render(establishedSynth, establishedBar)
        #expect(disclosed.leftSamples != established.leftSamples)
        #expect(disclosed.rightSamples != established.rightSamples)
        #expect(disclosed.polyphonicPadRenderEvidence.outputSampleHash !=
                established.polyphonicPadRenderEvidence.outputSampleHash)
        #expect(disclosed.resonantAnchorSamples !=
                established.resonantAnchorSamples)
        #expect(disclosed.detunedCompanionSamples ==
                established.detunedCompanionSamples)
        #expect(disclosed.dryFoundationSampleHash ==
                established.dryFoundationSampleHash)
        #expect(disclosed.foundationRhythmRenderEvidence ==
                established.foundationRhythmRenderEvidence)
        #expect(disclosed.dryPercussionSampleHash ==
                established.dryPercussionSampleHash)
        #expect(disclosed.dryModalPercussionSampleHash ==
                established.dryModalPercussionSampleHash)
        #expect(disclosed.groovePulseRenderEvidence ==
                established.groovePulseRenderEvidence)
        #expect(disclosed.kickMix == established.kickMix)
    }

    @MainActor
    @Test("Candidate evidence binds every arpeggiator pitch to the renderer")
    func arpeggiatorPitchEvidence() throws {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        for _ in 0..<128 {
            let plan = director.plan(from: state)
            guard let index = plan.phraseComposition.firstIndex(where: {
                $0.arpeggiator != nil
            }) else {
                state.advancePlanning(using: plan)
                continue
            }
            var renderState = RenderState()
            renderState.barIndex = state.memory.totalBars
            let prepared = AutonomousPhrasePreparer.prepare(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: renderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator()
            )
            let record = prepared.selectedCandidateEvidence
                .phraseComposition[index]
            #expect(record.arpeggiatorActive)
            #expect(record.arpeggiatorScorePitchFingerprint ==
                    record.arpeggiatorRenderPitchFingerprint)
            #expect(record.isComplete(
                phraseKind: plan.kind.rawValue,
                expectedLocalBar: index,
                expectedPhraseLength: plan.barCount,
                expectedSampleRate: 8_000
            ))
            let encoded = try JSONEncoder().encode(record)
            var json = try #require(
                JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            )
            json["arpeggiatorRenderPitchFingerprint"] = "0000000000000000"
            let forged = try JSONDecoder().decode(
                AutonomousPhraseCompositionBarEvidence.self,
                from: JSONSerialization.data(withJSONObject: json)
            )
            #expect(!forged.isComplete(
                phraseKind: plan.kind.rawValue,
                expectedLocalBar: index,
                expectedPhraseLength: plan.barCount,
                expectedSampleRate: 8_000
            ))
            return
        }
        Issue.record("Expected a naturally reachable arpeggiated phrase")
    }

    @Test("Identity-return plans neutralize all four capabilities")
    func identityReturnNeutrality() {
        let scene = fixtureScene()
        let dna = SceneDNA(scene: scene)
        let bar = fixtureResolved(
            bar: 0,
            section: .breakdown,
            character: .brokenSuspension,
            roles: [.motif, .atmosphere, .percussion],
            events: [
                EnsembleResolvedEvent(voice: .motif, step: 2,
                                      intensity: 0.72, relocated: false),
                EnsembleResolvedEvent(voice: .atmosphere, step: 0,
                                      intensity: 0.54, relocated: false),
                EnsembleResolvedEvent(voice: .percussion, step: 1,
                                      intensity: 0.64, relocated: false),
            ]
        )
        let composition = PhraseCompositionResolver.resolve(
            scene: scene, dna: dna, kind: .identityReturn,
            resolvedBars: [bar]
        )
        #expect(composition == [.neutral(bar: 0)])
    }

    @Test("Accepted pad voicing continues across phrase boundaries")
    func harmonicContinuation() throws {
        let scene = fixtureScene()
        let dna = SceneDNA(scene: scene)
        let firstBars = (0..<4).map { bar in
            fixtureResolved(
                bar: bar,
                section: .breakdown,
                character: .ambientDrift,
                roles: [.atmosphere],
                events: [EnsembleResolvedEvent(
                    voice: .atmosphere, step: 0,
                    intensity: 0.55, relocated: false
                )]
            )
        }
        let first = PhraseCompositionResolver.resolve(
            scene: scene, dna: dna, kind: .majorBreak,
            resolvedBars: firstBars
        )
        let outgoing = try #require(first.last?.padVoicing?.voices)
        let secondBar = fixtureResolved(
            bar: 4,
            section: .breakdown,
            character: .ambientDrift,
            roles: [.atmosphere],
            events: [EnsembleResolvedEvent(
                voice: .atmosphere, step: 0,
                intensity: 0.55, relocated: false
            )]
        )
        let continued = PhraseCompositionResolver.resolve(
            scene: scene, dna: dna, kind: .majorBreak,
            resolvedBars: [secondBar],
            harmonicContinuation: HarmonicContinuationState(voices: outgoing)
        )
        let next = try #require(continued.first?.padVoicing)
        let expectedMovement = zip(outgoing, next.voices).reduce(0) {
            $0 + abs($1.0.semitone - $1.1.semitone)
        }
        #expect(next.totalMovementInSemitones == expectedMovement)
        #expect(next.maximumLeapInSemitones <= 12)
        #expect(continued == PhraseCompositionResolver.resolve(
            scene: scene, dna: dna, kind: .majorBreak,
            resolvedBars: [secondBar],
            harmonicContinuation: HarmonicContinuationState(voices: outgoing)
        ))
    }

    @Test("Session memory commits only the accepted harmonic continuation")
    func sessionOwnedHarmonicContinuation() throws {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var acceptedVoices: [PadVoice]?

        for _ in 0..<96 {
            let plan = director.plan(from: state)
            if let incoming = acceptedVoices,
               let firstPad = plan.phraseComposition.compactMap(\.padVoicing).first {
                let expectedMovement = zip(incoming, firstPad.voices).reduce(0) {
                    $0 + abs($1.0.semitone - $1.1.semitone)
                }
                #expect(firstPad.totalMovementInSemitones == expectedMovement)
                return
            }
            if let outgoing = plan.phraseComposition.compactMap(\.padVoicing).last?.voices {
                acceptedVoices = outgoing
            }
            state.advancePlanning(using: plan)
            if let acceptedVoices {
                #expect(state.memory.harmonicContinuation.voices == acceptedVoices)
            }
        }
        Issue.record("Expected two naturally reachable pad phrases")
    }

    @Test("The canonical journey naturally reaches slicing, arpeggiation, and pads")
    func canonicalJourneyReachability() {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var sliceBars = 0
        var arpeggiatorBars = 0
        var padBars = 0
        var rhythmicallyModulatedPadBars = 0
        var disclosureStages = Set<PadHarmonicDisclosureStage>()
        var revealedBeforeContraction = false
        var sawContractionAfterReveal = false
        var breakBars = 0
        var breakPercussionBars = 0
        var breakSourceBars = 0

        for _ in 0..<128 {
            let plan = director.plan(from: state)
            if plan.kind == .majorBreak {
                breakBars += plan.resolvedBars.count
                breakPercussionBars += plan.resolvedBars.filter {
                    $0.performance.roles.contains(.percussion)
                }.count
                breakSourceBars += plan.resolvedBars.filter {
                    !PercussionEchoTextureResolver.eligibleSourceEvents(in: $0.ensemble).isEmpty
                }.count
            }
            for composition in plan.phraseComposition {
                if composition.audioSlice != nil { sliceBars += 1 }
                if composition.arpeggiator != nil { arpeggiatorBars += 1 }
                if let pad = composition.padVoicing {
                    padBars += 1
                    disclosureStages.insert(pad.harmonicDisclosureStage)
                    if pad.harmonicDisclosureStage == .revealed {
                        revealedBeforeContraction = true
                    } else if revealedBeforeContraction &&
                                pad.harmonicDisclosureStage == .concealed {
                        sawContractionAfterReveal = true
                    }
                    if pad.rhythmicModulation.active {
                        rhythmicallyModulatedPadBars += 1
                    }
                }
                if let arpeggiator = composition.arpeggiator,
                   let pad = composition.padVoicing {
                    let padPitchClasses = Set(pad.voices.map {
                        (($0.semitone % 12) + 12) % 12
                    })
                    let arpPitchClasses = Set(arpeggiator.steps.map {
                        let semitone = Int(round(12 * log2($0.frequencyRatio)))
                        return ((semitone % 12) + 12) % 12
                    })
                    #expect(arpPitchClasses.isSubset(of: padPitchClasses))
                }
            }
            state.advancePlanning(using: plan)
        }

        #expect(sliceBars > 0, "breaks=\(breakBars), percussion=\(breakPercussionBars), sources=\(breakSourceBars)")
        #expect(arpeggiatorBars > 0)
        #expect(padBars > 0)
        #expect(rhythmicallyModulatedPadBars > 0)
        #expect(disclosureStages.isSuperset(of: [
            .concealed, .partial, .revealed,
        ]))
        #expect(sawContractionAfterReveal)
    }

    @Test("Broken major breaks resample their exact rendered percussion source")
    func integratedSliceRender() throws {
        let scene = fixtureScene()
        let dna = SceneDNA(scene: scene)
        let resolved = fixtureResolved(
            bar: 3,
            section: .breakdown,
            character: .brokenSuspension,
            roles: [.atmosphere, .percussion],
            events: [
                EnsembleResolvedEvent(voice: .percussion, step: 1,
                                      intensity: 0.82, relocated: false),
                EnsembleResolvedEvent(voice: .atmosphere, step: 0,
                                      intensity: 0.55, relocated: false),
            ]
        )
        let synth = SynthPerformancePlan(
            scene: scene, dna: dna, kind: .majorBreak,
            resolvedBars: [resolved]
        )
        let synthBar = try #require(synth.bars.first)
        #expect(synthBar.composition.audioSlice != nil)
        #expect(synthBar.composition.audioSlice?.texture == .cut)
        var state = RenderState()
        var workspace = RenderWorkspace()
        let rendered = VoiceRenderer.renderBar(
            scene: scene,
            sampleRate: 8_000,
            state: &state,
            dna: dna,
            resolved: resolved,
            synthWorld: synth.world,
            synthPerformance: synthBar,
            workspace: &workspace,
            layer: .full
        )
        #expect(rendered.audioSliceRenderEvidence.active)
        #expect(rendered.audioSliceRenderEvidence.triggerCount >= 3)
        #expect(rendered.audioSliceRenderEvidence.texture == .cut)
        #expect(rendered.audioSliceRenderEvidence.grainCount == 0)
        #expect(rendered.audioSliceRenderEvidence.sourceSampleHash !=
                rendered.audioSliceRenderEvidence.outputSampleHash)
        #expect(rendered.audioSliceRenderEvidence.outputRMS > 0)
        #expect(rendered.leftSamples.allSatisfy { $0.isFinite })
        #expect(rendered.rightSamples.allSatisfy { $0.isFinite })
    }

    @Test("Ambient major breaks resample the resolved kick when percussion is absent")
    func integratedKickSliceRender() throws {
        let scene = fixtureScene()
        let dna = SceneDNA(scene: scene)
        let resolved = fixtureResolved(
            bar: 4,
            section: .breakdown,
            character: .ambientDrift,
            roles: [.foundation, .atmosphere],
            events: [
                EnsembleResolvedEvent(voice: .kick, step: 0,
                                      intensity: 1, relocated: false),
                EnsembleResolvedEvent(voice: .atmosphere, step: 0,
                                      intensity: 0.55, relocated: false),
            ]
        )
        let synth = SynthPerformancePlan(
            scene: scene, dna: dna, kind: .majorBreak,
            resolvedBars: [resolved]
        )
        let synthBar = try #require(synth.bars.first)
        #expect(synthBar.composition.audioSlice?.sourceKind == .kick)
        #expect(synthBar.composition.audioSlice?.texture == .granularMemory)
        #expect(synthBar.composition.audioSlice?.textureSeed != 0)
        var state = RenderState()
        var workspace = RenderWorkspace()
        let rendered = VoiceRenderer.renderBar(
            scene: scene,
            sampleRate: 8_000,
            state: &state,
            dna: dna,
            resolved: resolved,
            synthWorld: synth.world,
            synthPerformance: synthBar,
            workspace: &workspace,
            layer: .full
        )
        #expect(rendered.audioSliceRenderEvidence.active)
        #expect(rendered.audioSliceRenderEvidence.texture == .granularMemory)
        #expect(rendered.audioSliceRenderEvidence.grainCount > 0)
        #expect(rendered.audioSliceRenderEvidence.grainSourcePositionHash.count == 16)
        #expect(rendered.audioSliceRenderEvidence.sourceSampleHash.count == 16)
        #expect(rendered.audioSliceRenderEvidence.outputRMS > 0)
        #expect(rendered.kickMix.renderedKickEventCount == 1)
    }

    private func fixtureScene() -> TechnoScene {
        TechnoScene(
            intent: MusicalIntent(),
            seed: 48_291,
            bpm: AutonomousSessionDirector.bpm
        )
    }

    private func fixtureResolved(
        bar: Int,
        section: SectionKind,
        character: PerformanceCharacter,
        roles: [PerformanceRole],
        events: [EnsembleResolvedEvent],
        arrangementGesture: ArrangementGesture = .minimalize,
        interlockChapter: InterlockChapter = .breath
    ) -> ResolvedPerformanceBar {
        let performance = PerformanceBar(
            bar: bar,
            phrase: 0,
            localBar: bar,
            phraseLength: 8,
            section: section,
            tension: 0.58,
            roles: roles,
            transformations: [],
            signatureEvent: nil,
            eventSeed: UInt64(100 + bar),
            accentContour: (0..<16).map { $0.isMultiple(of: 4) ? 0.92 : 0.56 }
        )
        return ResolvedPerformanceBar(
            performance: performance,
            ensemble: EnsembleContext(
                focusRole: roles.contains(.motif) ? .motif : .atmosphere,
                events: events,
                kickAnchors: [],
                intentionalPileup: false
            ),
            arrangementGesture: arrangementGesture,
            percussionGear: .contrast,
            performanceCharacter: character,
            foundationBehavior: .absent,
            foundationCompanion: .empty,
            pulseEchoEnabled: false,
            interlockChapter: interlockChapter,
            spatialContrast: .foreground,
            narrative: NarrativeArticulation(
                presenceStart: 0.62,
                presenceEnd: 0.70,
                activeSupportingRoles: [.percussion, .atmosphere]
            )
        )
    }
}
