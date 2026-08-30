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
            let terminalEvidence = full.sourceTerminalDeclickRenderEvidence
                .filter { $0.voice == .kick }
            let oracle = legacyOracle(
                resolved: resolved,
                scene: plan.scene,
                sampleRate: sampleRate,
                renderedFrameCount: full.leftSamples.count
            )

            #expect(full.kickMix == protected.kickMix)
            #expect(full.sourceTerminalDeclickRenderEvidence ==
                    protected.sourceTerminalDeclickRenderEvidence)
            #expect(terminalEvidence.count ==
                    full.kickMix.renderedKickEventCount)
            #expect(terminalEvidence.allSatisfy {
                $0.isComplete(sampleRate: sampleRate) &&
                    $0.preFadeAttackSampleHash ==
                        $0.renderedAttackSampleHash
            })
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

    @Test("Held kick materials change exact PCM and authored presence at every route rate")
    func episodeMaterialsChangePCM() throws {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let plan = director.plan(from: director.initialState())
        let source = try #require(plan.resolvedBars.first { bar in
            bar.ensemble.events.contains { $0.voice == .kick }
        })
        let balanced = morphology(
            seed: plan.scene.seed,
            operatorKind: .maintain,
            previousOperatorKind: .maintain,
            relativeBar: 40
        )
        let relaxed = morphology(
            seed: plan.scene.seed,
            operatorKind: .reframe,
            previousOperatorKind: .maintain,
            relativeBar: 40
        )
        let ghost = morphology(
            seed: plan.scene.seed,
            operatorKind: .recover,
            previousOperatorKind: .payoff,
            relativeBar: 112
        )
        let accent = morphology(
            seed: plan.scene.seed,
            operatorKind: .payoff,
            previousOperatorKind: .maintain,
            relativeBar: 40
        )
        #expect(balanced.start.presenceScale == 1)
        #expect(relaxed.start.presenceScale == 0.78)
        #expect(ghost.start.presenceScale == 0.48)
        #expect(accent.start.presenceScale == 0.90)

        for sampleRate in [8_000.0, 44_100, 48_000, 96_000] {
            let renders = [balanced, relaxed, ghost, accent].map {
                render(
                    resolved: replacingMorphology(source, with: $0),
                    plan: plan,
                    sampleRate: sampleRate,
                    layer: .protectedRhythm
                )
            }
            #expect(Set(renders.map {
                $0.kickMix.sourceDynamics.inputSampleHash
            }).count == 4)
            #expect(Set(renders.map {
                $0.kickMix.sourceDynamics.outputSampleHash
            }).count == 4)
            #expect(renders[2].kickMix.sourceDynamics.outputRMS <
                    renders[1].kickMix.sourceDynamics.outputRMS)
            #expect(renders[2].kickMix.sourceDynamics.outputRMS > 0)
            #expect(renders[1].kickMix.sourceDynamics.outputRMS <
                    renders[0].kickMix.sourceDynamics.outputRMS)
            #expect(renders[3].kickMix.sourceDynamics.outputPeak <=
                    renders[0].kickMix.sourceDynamics.outputPeak)
            #expect(Set(renders.map {
                $0.kickMix.renderedKickEventCount
            }).count == 1)
            for (rendered, morphology) in zip(
                renders,
                [balanced, relaxed, ghost, accent]
            ) {
                #expect(rendered.kickMix.sourceDynamics.morphologyScoreHash ==
                        KickSourceDynamicsContract.morphologyScoreHash(
                            morphology
                        ))
                #expect(rendered.leftSamples.allSatisfy { $0.isFinite })
                #expect(rendered.sourceTerminalDeclickRenderEvidence
                    .filter { $0.voice == .kick }
                    .allSatisfy {
                        $0.preFadeAttackSampleHash ==
                            $0.renderedAttackSampleHash
                    })
            }
        }
    }

    @Test("Episode trajectory maps operators, stages recovery, and remains continuous")
    func episodeTrajectoryContract() {
        for seed in [UInt64(1), 42, 1_357_91, UInt64.max] {
            for operatorKind in LongHorizonEpisodeOperator.allCases {
                var previous: KickMorphologyArticulation?
                for bar in 0..<128 {
                    let first = morphology(
                        seed: seed,
                        operatorKind: operatorKind,
                        previousOperatorKind: .payoff,
                        relativeBar: bar
                    )
                    let replay = morphology(
                        seed: seed,
                        operatorKind: operatorKind,
                        previousOperatorKind: .payoff,
                        relativeBar: bar
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

        let reframeStart = morphology(
            operatorKind: .reframe,
            previousOperatorKind: .maintain,
            relativeBar: 0
        )
        let reframeMid = morphology(
            operatorKind: .reframe,
            previousOperatorKind: .maintain,
            relativeBar: 16
        )
        let reframeHeld = morphology(
            operatorKind: .reframe,
            previousOperatorKind: .maintain,
            relativeBar: 32
        )
        #expect(reframeStart.fromHome == .balanced)
        #expect(reframeStart.toHome == .relaxed)
        #expect(reframeStart.startProgress == 0)
        #expect(abs(reframeMid.startProgress - 0.5) < 0.000_001)
        #expect(reframeHeld.fromHome == .relaxed)
        #expect(reframeHeld.toHome == .relaxed)

        let recoveryBoundaries = [0, 32, 63, 64, 80, 96, 127].map {
            morphology(
                operatorKind: .recover,
                previousOperatorKind: .payoff,
                relativeBar: $0
            )
        }
        #expect(recoveryBoundaries[0].fromHome == .resonantAccent)
        #expect(recoveryBoundaries[0].toHome == .relaxed)
        #expect(recoveryBoundaries[1].fromHome == .relaxed)
        #expect(recoveryBoundaries[1].toHome == .relaxed)
        #expect(recoveryBoundaries[2].fromHome == .relaxed)
        #expect(recoveryBoundaries[2].toHome == .relaxed)
        #expect(recoveryBoundaries[3].fromHome == .relaxed)
        #expect(recoveryBoundaries[3].toHome == .ghostSoft)
        #expect(abs(recoveryBoundaries[4].startProgress - 0.5) < 0.000_001)
        #expect(recoveryBoundaries[5].fromHome == .ghostSoft)
        #expect(recoveryBoundaries[5].toHome == .ghostSoft)

        for operatorKind in [
            LongHorizonEpisodeOperator.maintain, .rise, .recall,
        ] {
            let held = morphology(
                operatorKind: operatorKind,
                previousOperatorKind: .maintain,
                relativeBar: 64
            )
            #expect(held.fromHome == .balanced)
            #expect(held.toHome == .balanced)
        }
        let payoff = morphology(
            operatorKind: .payoff,
            previousOperatorKind: .maintain,
            relativeBar: 64
        )
        #expect(payoff.fromHome == .resonantAccent)
        #expect(payoff.toHome == .resonantAccent)

        let fallback = KickMorphologyResolver.articulation(
            sessionSeed: 42,
            absoluteBar: 9,
            presentationBar: 1
        )
        #expect(fallback.fromHome == .balanced)
        #expect(fallback.toHome == .balanced)
        #expect(fallback.presentationBar == 9)
    }

    @Test("Serial retry pressure moves kick attack/body evidence in both bounded directions")
    func qualityRetryPressureContract() throws {
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 0) == 0)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 1) == 0.125)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 2) == -0.125)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 3) == 0.375)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 4) == -0.375)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 5) == 0.625)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 6) == -0.625)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 7) == 1)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 8) == -1)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: 9) == 1)
        #expect(KickMorphologyResolver.qualityRetryPressure(ordinal: Int.max) == 1)

        let seed: UInt64 = 42
        let baseline = KickMorphologyResolver.articulation(
            sessionSeed: seed,
            absoluteBar: 0
        )
        let explicitZero = KickMorphologyResolver.articulation(
            sessionSeed: seed,
            absoluteBar: 0,
            qualityRetryOrdinal: 0
        )
        let positive = KickMorphologyResolver.articulation(
            sessionSeed: seed,
            absoluteBar: 0,
            qualityRetryOrdinal: 1
        )
        let negative = KickMorphologyResolver.articulation(
            sessionSeed: seed,
            absoluteBar: 0,
            qualityRetryOrdinal: 2
        )
        let fullNegative = KickMorphologyResolver.articulation(
            sessionSeed: seed,
            absoluteBar: 0,
            qualityRetryOrdinal: 8
        )
        let transientRecovery = KickMorphologyResolver.articulation(
            sessionSeed: seed,
            absoluteBar: 0,
            qualityRetryOrdinal:
                AutonomousQualityRetryContinuation.maximumOrdinal
        )
        #expect(explicitZero == baseline)
        #expect(positive.isComplete)
        #expect(negative.isComplete)
        #expect(positive.start.bodyDecayPerSecond >
                baseline.start.bodyDecayPerSecond)
        #expect(negative.start.bodyDecayPerSecond <
                baseline.start.bodyDecayPerSecond)
        #expect(positive.start.noiseClickLevel > baseline.start.noiseClickLevel)
        #expect(negative.start.noiseClickLevel < baseline.start.noiseClickLevel)
        #expect(positive.start.bodyDrive > baseline.start.bodyDrive)
        #expect(negative.start.bodyDrive < baseline.start.bodyDrive)
        #expect(positive.start.subLevel > baseline.start.subLevel)
        #expect(negative.start.subLevel < baseline.start.subLevel)
        #expect(transientRecovery.start.bodyDecayPerSecond >
                baseline.start.bodyDecayPerSecond)
        #expect(transientRecovery.start.bodyDrive < baseline.start.bodyDrive)
        #expect(transientRecovery.start.subLevel < baseline.start.subLevel)
        #expect(transientRecovery.start.noiseClickLevel >
                baseline.start.noiseClickLevel)
        #expect(transientRecovery.start.tonalClickLevel >
                baseline.start.tonalClickLevel)

        for ordinal in 1...AutonomousQualityRetryContinuation.maximumOrdinal {
            #expect(abs(KickMorphologyResolver.qualityRetryPressure(
                ordinal: ordinal
            )) <= 1)
            var previous: KickMorphologyArticulation?
            for bar in 0..<260 {
                let articulation = KickMorphologyResolver.articulation(
                    sessionSeed: seed,
                    absoluteBar: bar,
                    qualityRetryOrdinal: ordinal
                )
                #expect(articulation.isComplete)
                if let previous {
                    #expect(previous.end == articulation.start)
                }
                previous = articulation
            }
        }

        let director = AutonomousSessionDirector(rootSeed: seed)
        let plan = director.plan(from: director.initialState())
        let source = try #require(plan.resolvedBars.first { bar in
            bar.ensemble.events.contains { $0.voice == .kick }
        })
        let baselineBar = render(
            resolved: replacingMorphology(source, with: baseline),
            plan: plan,
            sampleRate: 44_100,
            layer: .protectedRhythm
        )
        let positiveBar = render(
            resolved: replacingMorphology(source, with: positive),
            plan: plan,
            sampleRate: 44_100,
            layer: .protectedRhythm
        )
        let negativeBar = render(
            resolved: replacingMorphology(source, with: fullNegative),
            plan: plan,
            sampleRate: 44_100,
            layer: .protectedRhythm
        )
        let transientRecoveryBar = render(
            resolved: replacingMorphology(source, with: transientRecovery),
            plan: plan,
            sampleRate: 44_100,
            layer: .protectedRhythm
        )
        let renderedBaseline = baselineBar.kickMix.sourceDynamics
        let renderedPositive = positiveBar.kickMix.sourceDynamics
        let renderedNegative = negativeBar.kickMix.sourceDynamics
        let renderedTransientRecovery =
            transientRecoveryBar.kickMix.sourceDynamics
        let baselineAttackToBody = 20 * log10(
            renderedBaseline.outputAttackRMS /
                renderedBaseline.outputBodyRMS
        )
        let positiveAttackToBody = 20 * log10(
            renderedPositive.outputAttackRMS /
                renderedPositive.outputBodyRMS
        )
        #expect(renderedPositive.outputSampleHash !=
                renderedBaseline.outputSampleHash)
        #expect(positiveAttackToBody - baselineAttackToBody > 0.03)
        #expect(renderedNegative.outputSampleHash !=
                renderedBaseline.outputSampleHash)
        #expect(AutonomousKickSourceDynamicsEvidence(
            render: renderedNegative
        ).isComplete(
            sampleRate: 44_100,
            expectedEventCount: negativeBar.kickMix.renderedKickEventCount
        ))
        #expect(20 * log10(
            renderedNegative.outputRMS / renderedBaseline.outputRMS
        ) < -0.90)
        let baselineCrestReduction = 20 * log10(
            renderedBaseline.inputCrestFactor /
                renderedBaseline.outputCrestFactor
        )
        let transientAttackToBody = 20 * log10(
            renderedTransientRecovery.outputAttackRMS /
                renderedTransientRecovery.outputBodyRMS
        )
        let transientCrestReduction = 20 * log10(
            renderedTransientRecovery.inputCrestFactor /
                renderedTransientRecovery.outputCrestFactor
        )
        #expect(renderedTransientRecovery.outputSampleHash !=
                renderedBaseline.outputSampleHash)
        // The reproduced blocked target missed attack/body by 0.331 dB and
        // exceeded crest reduction by 0.103 dB on its ordinal-zero candidate.
        // Preserve measured recovery room beyond both exact misses.
        #expect(transientAttackToBody - baselineAttackToBody > 0.60)
        #expect(transientCrestReduction < baselineCrestReduction - 0.12)
        #expect(AutonomousKickSourceDynamicsEvidence(
            render: renderedTransientRecovery
        ).isComplete(
            sampleRate: 44_100,
            expectedEventCount:
                transientRecoveryBar.kickMix.renderedKickEventCount
        ))
        let baselineActive = try #require(
            baselineBar.stemObservations[.kick]?.activeRMS
        )
        let negativeActive = try #require(
            negativeBar.stemObservations[.kick]?.activeRMS
        )
        // The source-local output carries the full attenuation contract above.
        // Active-window stem RMS includes the fixed terminal tail, so retain a
        // separately audible but slightly smaller bound at that observation.
        #expect(20 * log10(negativeActive / baselineActive) < -0.70)

        for absoluteBar in [64, 127, 128, 192, 255] {
            let trajectoryBaseline = KickMorphologyResolver.articulation(
                sessionSeed: seed,
                absoluteBar: absoluteBar
            )
            let trajectoryNegative = KickMorphologyResolver.articulation(
                sessionSeed: seed,
                absoluteBar: absoluteBar,
                qualityRetryOrdinal: 8
            )
            let trajectoryBaselineBar = render(
                resolved: replacingMorphology(source, with: trajectoryBaseline),
                plan: plan,
                sampleRate: 44_100,
                layer: .protectedRhythm
            )
            let trajectoryNegativeBar = render(
                resolved: replacingMorphology(source, with: trajectoryNegative),
                plan: plan,
                sampleRate: 44_100,
                layer: .protectedRhythm
            )
            let baselineTrajectoryActive = try #require(
                trajectoryBaselineBar.stemObservations[.kick]?.activeRMS
            )
            let negativeTrajectoryActive = try #require(
                trajectoryNegativeBar.stemObservations[.kick]?.activeRMS
            )
            #expect(20 * log10(
                negativeTrajectoryActive / baselineTrajectoryActive
            ) < -0.70)
        }
    }

    @Test("Gentle negative retry remains complete inside neighboring source gates")
    func gentleNegativeRetryPreservesSourceGateRoom() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for _ in 0..<10 {
            state.advancePlanning(using: director.plan(from: state))
        }
        let plan = director.plan(from: state, qualityRetryOrdinal: 2)
        #expect(plan.phraseIndex == 10)
        var attackToBody: [Double] = []
        var crestReduction: [Double] = []
        for bar in plan.resolvedBars where
            bar.ensemble.events.contains(where: { $0.voice == .kick }) {
            let block = render(
                resolved: bar,
                plan: plan,
                sampleRate: 44_100,
                layer: .protectedRhythm
            )
            let rendered = block.kickMix.sourceDynamics
            #expect(AutonomousKickSourceDynamicsEvidence(
                render: rendered
            ).isComplete(
                sampleRate: 44_100,
                expectedEventCount: block.kickMix.renderedKickEventCount
            ))
            attackToBody.append(20 * log10(
                rendered.outputAttackRMS / rendered.outputBodyRMS
            ))
            crestReduction.append(20 * log10(
                rendered.inputCrestFactor / rendered.outputCrestFactor
            ))
        }
        let attack = attackToBody.reduce(0, +) / Double(attackToBody.count)
        let crest = crestReduction.reduce(0, +) /
            Double(crestReduction.count)
        #expect((5.75457012134268...7.962090072628294).contains(attack))
        #expect((1.207104324665403...1.5078683083490771).contains(crest))
    }

    @Test("Final retry corrects the reproduced low-attack high-crest miss")
    func finalTransientRecoveryCorrectsCoupledSourceMiss() throws {
        let seed: UInt64 = 42
        let director = AutonomousSessionDirector(rootSeed: seed)
        let plan = director.plan(from: director.initialState())
        let source = try #require(plan.resolvedBars.first { bar in
            bar.ensemble.events.contains { $0.voice == .kick }
        })

        // The blocked P12 ordinal-zero candidate was 0.331 dB below the
        // calibrated attack/body floor and 0.103 dB above the crest-reduction
        // ceiling. Prove source-local room beyond both misses across the
        // trajectory homes and segment boundaries on exact 44.1 kHz PCM.
        for absoluteBar in [0, 64, 127, 128, 192, 255] {
            let baseline = KickMorphologyResolver.articulation(
                sessionSeed: seed,
                absoluteBar: absoluteBar
            )
            let recovery = KickMorphologyResolver.articulation(
                sessionSeed: seed,
                absoluteBar: absoluteBar,
                qualityRetryOrdinal:
                    AutonomousQualityRetryContinuation.maximumOrdinal
            )
            let baselineRender = render(
                resolved: replacingMorphology(source, with: baseline),
                plan: plan,
                sampleRate: 44_100,
                layer: .protectedRhythm
            ).kickMix.sourceDynamics
            let recoveryBlock = render(
                resolved: replacingMorphology(source, with: recovery),
                plan: plan,
                sampleRate: 44_100,
                layer: .protectedRhythm
            )
            let recoveryRender = recoveryBlock.kickMix.sourceDynamics
            let attackLift = 20 * log10(
                recoveryRender.outputAttackRMS /
                    recoveryRender.outputBodyRMS
            ) - 20 * log10(
                baselineRender.outputAttackRMS /
                    baselineRender.outputBodyRMS
            )
            let crestReductionChange = 20 * log10(
                recoveryRender.inputCrestFactor /
                    recoveryRender.outputCrestFactor
            ) - 20 * log10(
                baselineRender.inputCrestFactor /
                    baselineRender.outputCrestFactor
            )
            #expect(recovery.isComplete)
            #expect(recoveryRender.outputSampleHash !=
                    baselineRender.outputSampleHash)
            #expect(attackLift > 0.34)
            #expect(crestReductionChange < -0.105)
            #expect(AutonomousKickSourceDynamicsEvidence(
                render: recoveryRender
            ).isComplete(
                sampleRate: 44_100,
                expectedEventCount:
                    recoveryBlock.kickMix.renderedKickEventCount
            ))
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

    private func morphology(
        seed: UInt64 = 42,
        operatorKind: LongHorizonEpisodeOperator,
        previousOperatorKind: LongHorizonEpisodeOperator?,
        relativeBar: Int
    ) -> KickMorphologyArticulation {
        KickMorphologyResolver.articulation(
            sessionSeed: seed,
            absoluteBar: relativeBar,
            presentationBar: 1_024 + relativeBar,
            episodeContext: KickMorphologyEpisodeContext(
                episodeID: 0x4B49_434B,
                episodeIndex: 3,
                operatorKind: operatorKind,
                startedAtPresentationBar: 1_024,
                previousOperatorKind: previousOperatorKind
            )
        )
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
                let conditioned = KickSourceDynamicsContract.process(
                    sample,
                    state: &dynamicsState
                )
                let output = SourceTerminalDeclickContract.process(
                    sample: conditioned,
                    voice: .kick,
                    frame: frame,
                    renderedFrameCount: frameCount,
                    sampleRate: sampleRate
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
