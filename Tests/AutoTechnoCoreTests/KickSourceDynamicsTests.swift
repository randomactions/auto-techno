import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Source-local kick dynamics")
struct KickSourceDynamicsTests {
    @Test("ADAA transfer is odd, monotonic, bounded, finite, and zero preserving")
    func transferContract() {
        let inputs = stride(from: -1.25, through: 1.25, by: 0.005)
            .map(Float.init)
        var outputs: [Float] = []
        outputs.reserveCapacity(inputs.count)
        for input in inputs {
            var state = AntiderivativeAntialiasedTanhState()
            outputs.append(KickSourceDynamicsContract.process(
                input,
                state: &state
            ))
        }
        #expect(outputs.allSatisfy { $0.isFinite })
        #expect(outputs.allSatisfy {
            abs(Double($0)) <= KickSourceDynamicsContract.outputGain
        })
        #expect(zip(outputs, outputs.dropFirst()).allSatisfy { $0 <= $1 })
        for index in inputs.indices {
            let mirrored = outputs[outputs.count - 1 - index]
            #expect(abs(outputs[index] + mirrored) < 0.000_001)
        }

        for zero in [Float(0), -Float(0)] {
            var state = AntiderivativeAntialiasedTanhState()
            let output = KickSourceDynamicsContract.process(zero, state: &state)
            #expect(output.bitPattern == zero.bitPattern)
        }
        var invalidState = AntiderivativeAntialiasedTanhState()
        #expect(KickSourceDynamicsContract.process(
            .nan,
            state: &invalidState
        ) == 0)
    }

    @Test("Rendered kick source matches an independent morphology oracle at every rate")
    func renderedEvidenceAcrossRates() throws {
        let director = AutonomousSessionDirector(rootSeed: 1)
        let plan = director.plan(from: director.initialState())
        let resolved = try #require(plan.resolvedBars.first { bar in
            bar.ensemble.events.contains { $0.voice == .kick }
        })

        for sampleRate in [8_000.0, 44_100, 48_000, 96_000, 192_000] {
            let full = render(
                resolved: resolved,
                plan: plan,
                sampleRate: sampleRate,
                layer: .full
            )
            let protected = render(
                resolved: resolved,
                plan: plan,
                sampleRate: sampleRate,
                layer: .protectedRhythm
            )
            let source = full.kickMix.sourceDynamics
            let oracle = legacyOracle(
                resolved: resolved,
                scene: plan.scene,
                sampleRate: sampleRate,
                renderedFrameCount: full.leftSamples.count
            )

            #expect(full.kickMix == protected.kickMix)
            #expect(source.version == KickSourceDynamicsContract.version)
            #expect(source.antialiasOrder == 1)
            #expect(source.renderedEventCount == full.kickMix.renderedKickEventCount)
            #expect(source.processedSampleCount == oracle.sampleCount)
            #expect(source.inputSampleHash == oracle.sampleHash)
            #expect(source.inputPeak == oracle.peak)
            #expect(source.inputRMS == oracle.rms)
            #expect(source.outputSampleHash == oracle.outputSampleHash)
            #expect(source.outputPeak == oracle.outputPeak)
            #expect(source.outputRMS == oracle.outputRMS)
            #expect(source.outputAttackRMS == oracle.outputAttackRMS)
            #expect(source.outputBodyRMS == oracle.outputBodyRMS)
            #expect(source.inputSampleHash != oracle.outputSampleHash)
            #expect(source.outputCrestFactor < source.inputCrestFactor)
            #expect(source.outputBodyRMS / source.outputAttackRMS >
                    source.inputBodyRMS / source.inputAttackRMS)
            #expect(source.outputUpperMidEnergyRatio > 0)
            #expect(source.finite)
            #expect(full.kickMix.detectorPeak == source.outputPeak ||
                    full.kickMix.detectorPeak > source.outputPeak)
            #expect(full.leftSamples.allSatisfy { $0.isFinite })
            #expect(full.rightSamples.allSatisfy { $0.isFinite })
        }
    }

    @Test("An empty kick score carries exact empty source evidence")
    func emptyEvidence() throws {
        let director = AutonomousSessionDirector(rootSeed: 1)
        let plan = director.plan(from: director.initialState())
        let source = try #require(plan.resolvedBars.first)
        let withoutKick = replacingEnsemble(
            source,
            events: source.ensemble.events.filter { $0.voice != .kick },
            kickAnchors: []
        )
        let rendered = render(
            resolved: withoutKick,
            plan: plan,
            sampleRate: 8_000,
            layer: .protectedRhythm
        )
        #expect(rendered.kickMix.renderedKickEventCount == 0)
        #expect(rendered.kickMix.sourceDynamics ==
                KickSourceDynamicsRenderEvidence.empty(
                    morphology: withoutKick.kickMorphology
                ))
    }

    @Test("Minute-three and minute-fifty morphology change exact kick PCM at every route rate")
    func longHorizonMorphologyChangesPCM() throws {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let plan = director.plan(from: director.initialState())
        let source = try #require(plan.resolvedBars.first { bar in
            bar.ensemble.events.contains { $0.voice == .kick }
        })
        let minuteThreeBar = Int((3.0 * plan.scene.bpm / 4.0).rounded())
        let minuteFiftyBar = Int((50.0 * plan.scene.bpm / 4.0).rounded())
        let earlyMorphology = KickMorphologyResolver.articulation(
            sessionSeed: plan.scene.seed,
            absoluteBar: minuteThreeBar
        )
        let lateMorphology = KickMorphologyResolver.articulation(
            sessionSeed: plan.scene.seed,
            absoluteBar: minuteFiftyBar
        )
        #expect(earlyMorphology != lateMorphology)

        for sampleRate in [8_000.0, 44_100, 48_000, 96_000] {
            let early = render(
                resolved: replacingMorphology(source, with: earlyMorphology),
                plan: plan,
                sampleRate: sampleRate,
                layer: .protectedRhythm
            )
            let late = render(
                resolved: replacingMorphology(source, with: lateMorphology),
                plan: plan,
                sampleRate: sampleRate,
                layer: .protectedRhythm
            )
            #expect(early.kickMix.sourceDynamics.inputSampleHash !=
                    late.kickMix.sourceDynamics.inputSampleHash)
            #expect(early.kickMix.sourceDynamics.outputSampleHash !=
                    late.kickMix.sourceDynamics.outputSampleHash)
            #expect(early.kickMix.sourceDynamics.morphologyScoreHash ==
                    KickSourceDynamicsContract.morphologyScoreHash(
                        earlyMorphology
                    ))
            #expect(late.kickMix.sourceDynamics.morphologyScoreHash ==
                    KickSourceDynamicsContract.morphologyScoreHash(
                        lateMorphology
                    ))
            #expect(early.leftSamples.allSatisfy { $0.isFinite })
            #expect(late.leftSamples.allSatisfy { $0.isFinite })
        }
    }

    @Test("Morphology trajectory is deterministic, bounded, and continuous across bars")
    func morphologyTrajectoryContract() {
        for seed in [UInt64(1), 42, 1_357_91, UInt64.max] {
            var previous: KickMorphologyArticulation?
            for bar in 0..<512 {
                let first = KickMorphologyResolver.articulation(
                    sessionSeed: seed,
                    absoluteBar: bar
                )
                let replay = KickMorphologyResolver.articulation(
                    sessionSeed: seed,
                    absoluteBar: bar
                )
                #expect(first == replay)
                #expect(first.isComplete)
                if let previous {
                    #expect(previous.end == first.start)
                }
                previous = first
            }
        }
    }

    private struct LegacyOracle {
        let sampleCount: Int
        let sampleHash: String
        let peak: Double
        let rms: Double
        let outputSampleHash: String
        let outputPeak: Double
        let outputRMS: Double
        let outputAttackRMS: Double
        let outputBodyRMS: Double
    }

    private func legacyOracle(
        resolved: ResolvedPerformanceBar,
        scene: TechnoScene,
        sampleRate: Double,
        renderedFrameCount: Int
    ) -> LegacyOracle {
        let stepFrames = Double(renderedFrameCount) / 16
        var sampleCount = 0
        var peak = 0.0
        var energy = 0.0
        var outputPeak = 0.0
        var outputEnergy = 0.0
        var outputAttackEnergy = 0.0
        var outputBodyEnergy = 0.0
        var attackSampleCount = 0
        var bodySampleCount = 0
        var fingerprint = StreamingFNV1a()
        var outputFingerprint = StreamingFNV1a()
        fingerprint.domain("kick-source-dynamics.input.v1")
        outputFingerprint.domain("kick-source-dynamics.output.v1")
        var eventIndex = 0
        for event in resolved.ensemble.events where event.voice == .kick {
            let offset = VoiceRenderer.timingOffsetInSteps(
                for: .kick,
                step: event.step,
                dna: SceneDNA(scene: scene)
            )
            let start = Int(((Double(event.step) + offset) * stepFrames).rounded())
            guard start >= 0, start < renderedFrameCount else { continue }
            let frameCount = min(
                Int(sampleRate * KickSourceDynamicsContract
                    .maximumEventDurationSeconds),
                renderedFrameCount - start
            )
            guard frameCount > 0 else { continue }
            fingerprint.aggregate("event")
            fingerprint.int(eventIndex)
            outputFingerprint.aggregate("event")
            outputFingerprint.int(eventIndex)
            eventIndex += 1
            var dynamicsState = AntiderivativeAntialiasedTanhState()
            var random = SeededGenerator(
                seed: scene.seed ^ UInt64(event.step + 1) ^
                    0x9E3779B97F4A7C15
            )
            var bodyPhase = 0.0
            var subPhase = 0.0
            let level = KickMixBalance.detectorLevel(
                for: resolved.performance.section
            ) * resolved.performance.accent(at: event.step) * event.intensity
            for frame in 0..<frameCount {
                let time = Double(frame) / sampleRate
                let barDurationSeconds = 240.0 / scene.bpm
                let barProgress = min(
                    1,
                    max(0, Double(event.step) / 16.0 +
                        time / barDurationSeconds)
                )
                let parameters = resolved.kickMorphology.parameters(
                    atBarProgress: barProgress
                )
                let pitch = parameters.fundamentalHz +
                    parameters.pitchDepthHz * exp(
                        -time * parameters.pitchDecayPerSecond
                    ) + parameters.fastPitchDepthHz * exp(
                        -time * parameters.fastPitchDecayPerSecond
                    )
                bodyPhase += 2 * .pi * pitch / sampleRate
                subPhase += 2 * .pi * parameters.fundamentalHz / sampleRate
                let attack = min(1, time / 0.0012)
                let bodyEnvelope = attack * exp(
                    -time * parameters.bodyDecayPerSecond
                )
                let subEnvelope = min(1, time / 0.006) * exp(
                    -time * parameters.subDecayPerSecond
                )
                let body = tanh((sin(bodyPhase) +
                    sin(bodyPhase * 2) * parameters.secondHarmonicLevel) *
                    parameters.bodyDrive) * bodyEnvelope
                let sub = sin(subPhase) * subEnvelope * parameters.subLevel
                let transientEnvelope = exp(-time * 1_050)
                let transient = frame < Int(sampleRate * 0.0045)
                    ? ((random.unit() * 2 - 1) * parameters.noiseClickLevel +
                        sin(2 * .pi * parameters.clickFrequencyHz * time) *
                            parameters.tonalClickLevel) *
                        transientEnvelope
                    : 0
                let sample = Float((body + sub + transient) * level)
                let output = KickSourceDynamicsContract.process(
                    sample,
                    state: &dynamicsState
                )
                fingerprint.float(sample)
                outputFingerprint.float(output)
                let value = Double(sample)
                let outputValue = Double(output)
                peak = max(peak, abs(value))
                outputPeak = max(outputPeak, abs(outputValue))
                energy += value * value
                outputEnergy += outputValue * outputValue
                if frame < max(1, Int((sampleRate *
                    KickSourceDynamicsContract.attackWindowSeconds).rounded())) {
                    outputAttackEnergy += outputValue * outputValue
                    attackSampleCount += 1
                }
                let bodyStartFrame = max(
                    max(1, Int((sampleRate * KickSourceDynamicsContract
                        .attackWindowSeconds).rounded())),
                    Int((sampleRate * KickSourceDynamicsContract
                        .bodyWindowStartSeconds).rounded())
                )
                let bodyEndFrame = max(
                    bodyStartFrame + 1,
                    Int((sampleRate * KickSourceDynamicsContract
                        .bodyWindowEndSeconds).rounded())
                )
                if frame >= bodyStartFrame, frame < bodyEndFrame {
                    outputBodyEnergy += outputValue * outputValue
                    bodySampleCount += 1
                }
                sampleCount += 1
            }
        }
        return LegacyOracle(
            sampleCount: sampleCount,
            sampleHash: fixedWidthFingerprintHex(fingerprint.value),
            peak: peak,
            rms: sqrt(energy / Double(max(1, sampleCount))),
            outputSampleHash: fixedWidthFingerprintHex(
                outputFingerprint.value
            ),
            outputPeak: outputPeak,
            outputRMS: sqrt(outputEnergy / Double(max(1, sampleCount))),
            outputAttackRMS: sqrt(
                outputAttackEnergy / Double(max(1, attackSampleCount))
            ),
            outputBodyRMS: sqrt(
                outputBodyEnergy / Double(max(1, bodySampleCount))
            )
        )
    }

    @inline(never)
    private func render(
        resolved: ResolvedPerformanceBar,
        plan: AutonomousPhrasePlan,
        sampleRate: Double,
        layer: RenderLayer
    ) -> RenderedBar {
        let synth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [resolved]
        )
        var state = RenderState()
        state.barIndex = resolved.performance.bar
        var workspace = RenderWorkspace()
        return VoiceRenderer.renderBar(
            scene: plan.scene,
            sampleRate: sampleRate,
            state: &state,
            dna: plan.dna,
            resolved: resolved,
            synthWorld: synth.world,
            synthPerformance: synth.bars[0],
            workspace: &workspace,
            layer: layer,
            phraseKind: plan.kind
        )
    }

    private func replacingEnsemble(
        _ source: ResolvedPerformanceBar,
        events: [EnsembleResolvedEvent],
        kickAnchors: [Int]
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: EnsembleContext(
                focusRole: source.ensemble.focusRole,
                events: events,
                kickAnchors: kickAnchors,
                intentionalPileup: source.ensemble.intentionalPileup
            ),
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationRhythmicRelation: source.foundationRhythmicRelation,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations: source.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            modalPercussionArticulations: source.modalPercussionArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: .withheld,
            percussionEchoTexture: source.percussionEchoTexture
        )
    }

    private func replacingMorphology(
        _ source: ResolvedPerformanceBar,
        with morphology: KickMorphologyArticulation
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationRhythmicRelation: source.foundationRhythmicRelation,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations: source.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            modalPercussionArticulations: source.modalPercussionArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: source.kickSyntaxRole,
            climaxHang: source.climaxHang,
            percussionEchoTexture: source.percussionEchoTexture,
            harmonicDisclosureRelationship:
                source.harmonicDisclosureRelationship,
            kickMorphology: morphology
        )
    }
}
