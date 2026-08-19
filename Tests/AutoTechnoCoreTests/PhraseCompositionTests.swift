@testable import AutoTechnoDSP
import AutoTechnoCore
import Foundation
import Testing

@Suite("Unified phrase composition")
struct PhraseCompositionTests {
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

    @Test("Pad rhythmic motion changes only existing pad filter and spatial send")
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
            #expect(modulated.3.spatialSendRMS > 0)
            #expect(modulated.3.outputSampleHash != baseline.3.outputSampleHash)
            #expect(modulated.3.spatialSendSampleHash !=
                    baseline.3.spatialSendSampleHash)
            #expect(modulated.3.finite)
            #expect(modulated.0.allSatisfy { $0.isFinite })
            #expect(modulated.1.allSatisfy { $0.isFinite })
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
                #expect(record.padSpatialSendRMS > 0)
                #expect(record.bindingValid && record.finite)
                #expect(record.isComplete(phraseKind: plan.kind.rawValue))
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

            let record = vector.phraseComposition[try #require(activeIndexes.first)]
            let encoded = try JSONEncoder().encode(record)
            let json = try #require(
                JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            )
            let keys = Set(json.keys)
            #expect(keys.isSuperset(of: [
                "section", "arrangementGesture",
                "padRhythmicModulationRelation",
                "padRhythmicModulationPhaseOffset",
                "padRhythmicModulationPatternFingerprint",
                "padFilterModulationDifferenceRMS",
                "padSpatialSendDifferenceRMS",
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
                forged("padFilterModulationDifferenceRMS", 0),
                forged("padSpatialSendDifferenceRMS", 0),
            ]
            #expect(tampered.allSatisfy {
                !$0.isComplete(phraseKind: plan.kind.rawValue)
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
