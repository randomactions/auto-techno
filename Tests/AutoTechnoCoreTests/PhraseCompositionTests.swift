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
            resolvedBars: bars, conservative: false
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

    @Test("Conservative and identity-return plans neutralize all four capabilities")
    func conservativeFallback() {
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
        for (kind, conservative) in [
            (AutonomousPhraseKind.identityReturn, false),
            (.majorBreak, true),
        ] {
            let composition = PhraseCompositionResolver.resolve(
                scene: scene, dna: dna, kind: kind,
                resolvedBars: [bar], conservative: conservative
            )
            #expect(composition == [.neutral(bar: 0)])
        }
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
            resolvedBars: firstBars, conservative: false
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
            resolvedBars: [secondBar], conservative: false,
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
            resolvedBars: [secondBar], conservative: false,
            harmonicContinuation: HarmonicContinuationState(voices: outgoing)
        ))
    }

    @Test("Session memory commits only the accepted harmonic continuation")
    func sessionOwnedHarmonicContinuation() throws {
        let director = AutonomousSessionDirector()
        var state = director.initialState()
        var acceptedVoices: [PadVoice]?

        for _ in 0..<96 {
            let plan = director.candidates(from: state).primary
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
            state.advance(using: plan)
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
        var breakBars = 0
        var breakPercussionBars = 0
        var breakSourceBars = 0

        for _ in 0..<128 {
            let plan = director.candidates(from: state).primary
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
                if composition.padVoicing != nil { padBars += 1 }
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
            state.advance(using: plan)
        }

        #expect(sliceBars > 0, "breaks=\(breakBars), percussion=\(breakPercussionBars), sources=\(breakSourceBars)")
        #expect(arpeggiatorBars > 0)
        #expect(padBars > 0)
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
        events: [EnsembleResolvedEvent]
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
            arrangementGesture: .minimalize,
            percussionGear: .contrast,
            performanceCharacter: character,
            foundationBehavior: .absent,
            foundationCompanion: .empty,
            pulseEchoEnabled: false,
            interlockChapter: .breath,
            spatialContrast: .foreground,
            narrative: NarrativeArticulation(
                presenceStart: 0.62,
                presenceEnd: 0.70,
                activeSupportingRoles: [.percussion, .atmosphere]
            )
        )
    }
}
