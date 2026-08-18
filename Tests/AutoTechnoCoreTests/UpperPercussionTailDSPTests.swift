import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Upper-percussion tail DSP")
struct UpperPercussionTailDSPTests {
    @Test("Prepared primary retains complete score-to-render tail evidence")
    func preparedEvidence() throws {
        let fixture = try #require(activeResolvedBar())
        let director = AutonomousSessionDirector(rootSeed: fixture.seed)
        let state = director.initialState()
        let prepared = AutonomousPhrasePreparer.prepare(
            plan: fixture.plan,
            sessionSeed: fixture.seed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: AcceptingPrimaryTestEvaluator()
        )
        let vector = prepared.selectedCandidateEvidence
        let activeBars = vector.upperPercussionTail.filter { bar in
            bar.events.contains {
                $0.role == UpperPercussionTailRole.foregroundClearance.rawValue
            }
        }
        let allEvents = vector.upperPercussionTail.flatMap(\.events)
        let activeEvents = allEvents.filter {
            $0.role == UpperPercussionTailRole.foregroundClearance.rawValue
        }
        let observation = try ProfessionalQualityObservation(
            candidate: vector,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: .establishment
        )
        let expectedActiveRatio = Double(activeEvents.count) /
            Double(max(1, allEvents.count))
        let expectedRenderedTailMean = activeEvents.isEmpty ? 0 :
            activeEvents.map(\.renderedTailToAttackDB).reduce(0, +) /
                Double(activeEvents.count)

        #expect(prepared.plan == fixture.plan)
        #expect(prepared.commitEligible)
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(vector.isComplete)
        #expect(vector.upperPercussionTail.count == fixture.plan.barCount)
        #expect(vector.sourceUpperPercussionTailBarCount == fixture.plan.barCount)
        #expect(!activeBars.isEmpty)
        #expect(observation[.upperPercussionTailClearanceEventRatio] ==
                expectedActiveRatio)
        #expect(observation[.upperPercussionTailRenderedTailToAttackDBMean] ==
                expectedRenderedTailMean)
        #expect(activeBars.allSatisfy { bar in
            bar.bindingValid && bar.renderPassesMatch &&
                bar.sourceScoreEventCount == bar.sourceRenderEventCount &&
                bar.sourceScoreEventCount == bar.events.count &&
                bar.events.allSatisfy {
                    $0.baseAttackSampleHash == $0.renderedAttackSampleHash &&
                        $0.baseAttackRMS == $0.renderedAttackRMS &&
                        $0.renderedTailRMS < $0.baseTailRMS &&
                        $0.renderedSampleHash != $0.baseSampleHash &&
                        $0.differenceRMS > 0
                }
        })
    }

    @Test("Same-bar clearance changes only the intended post-attack event body")
    func rendererCausality() throws {
        let fixture = try #require(activeResolvedBar())
        let activeBar = fixture.resolved
        let neutralArticulations = activeBar.upperPercussionTailArticulations.map {
            UpperPercussionTailArticulation(
                scoreEventIndex: $0.scoreEventIndex,
                voice: $0.voice,
                step: $0.step,
                role: .naturalBody
            )
        }
        let neutralBar = replacingTail(
            in: activeBar,
            with: neutralArticulations
        )

        let active = render(
            plan: fixture.plan,
            resolved: activeBar,
            sampleRate: 48_000
        )
        let neutral = render(
            plan: fixture.plan,
            resolved: neutralBar,
            sampleRate: 48_000
        )

        #expect(active.upperPercussionTailRenderEvidence.count ==
                activeBar.upperPercussionTailArticulations.count)
        #expect(active.upperPercussionTailRenderEvidence.count ==
                neutral.upperPercussionTailRenderEvidence.count)
        #expect(active.upperPercussionTailRenderEvidence.allSatisfy {
            $0.role == .foregroundClearance && $0.finite
        })
        #expect(neutral.upperPercussionTailRenderEvidence.allSatisfy {
            $0.role == .naturalBody && $0.finite &&
                $0.baseSampleHash == $0.renderedSampleHash &&
                $0.differenceRMS == 0
        })

        for (activeEvent, neutralEvent) in zip(
            active.upperPercussionTailRenderEvidence,
            neutral.upperPercussionTailRenderEvidence
        ) {
            #expect(activeEvent.scoreEventIndex == neutralEvent.scoreEventIndex)
            #expect(activeEvent.voice == neutralEvent.voice)
            #expect(activeEvent.step == neutralEvent.step)
            #expect(activeEvent.renderedFrameCount == neutralEvent.renderedFrameCount)
            #expect(activeEvent.attackFrameCount == neutralEvent.attackFrameCount)
            #expect(activeEvent.baseSampleHash == neutralEvent.baseSampleHash)
            #expect(activeEvent.baseAttackSampleHash ==
                    activeEvent.renderedAttackSampleHash)
            #expect(activeEvent.renderedAttackSampleHash ==
                    neutralEvent.renderedAttackSampleHash)
            #expect(activeEvent.renderedSampleHash != neutralEvent.renderedSampleHash)
            #expect(activeEvent.differenceRMS > 0)
            #expect(activeEvent.renderedTailRMS < activeEvent.baseTailRMS)
            #expect(activeEvent.renderedTailToAttackDB <
                    activeEvent.baseTailToAttackDB)
        }

        #expect(active.dryFoundationSampleHash == neutral.dryFoundationSampleHash)
        #expect(active.dryModalPercussionSampleHash ==
                neutral.dryModalPercussionSampleHash)
        #expect(active.modalPercussionRenderEvidence ==
                neutral.modalPercussionRenderEvidence)
        #expect(active.groovePulseRenderEvidence ==
                neutral.groovePulseRenderEvidence)
        #expect(active.closedHatRenderEvidence == neutral.closedHatRenderEvidence)
        #expect(active.instrumentRenderEvidence == neutral.instrumentRenderEvidence)
        #expect(active.dryPercussionSampleHash != neutral.dryPercussionSampleHash)
    }

    @Test("Clearance preserves an 8 ms attack and reaches the bounded tail")
    func physicalTimeGeometry() {
        for sampleRate in [44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            let frameCount = Int((0.05 * sampleRate).rounded())
            let attackFrames = UpperPercussionTailDSPContract.attackFrameCount(
                sampleRate: sampleRate,
                renderedFrameCount: frameCount
            )
            let multipliers = (0..<frameCount).map { frame in
                UpperPercussionTailDSPContract.multiplier(
                    role: .foregroundClearance,
                    frame: frame,
                    renderedFrameCount: frameCount,
                    sampleRate: sampleRate
                )
            }

            #expect(attackFrames == Int((0.008 * sampleRate).rounded()))
            #expect(multipliers.prefix(attackFrames).allSatisfy { $0 == 1 })
            #expect(multipliers[attackFrames] == 1)
            #expect(multipliers.last ==
                    UpperPercussionTailDSPContract.clearanceFinalMultiplier)
            #expect(zip(multipliers, multipliers.dropFirst()).allSatisfy {
                $0 >= $1
            })
            #expect(multipliers.allSatisfy {
                $0.isFinite &&
                    $0 >= UpperPercussionTailDSPContract.clearanceFinalMultiplier &&
                    $0 <= 1
            })
        }
    }

    @Test("Natural body is a literal bit-exact bypass")
    func naturalBodyIdentity() {
        let samples: [Float] = [
            0,
            Float(bitPattern: 0x8000_0000),
            Float.leastNonzeroMagnitude,
            -Float.leastNonzeroMagnitude,
            0.125,
            -0.75,
        ]

        for (frame, sample) in samples.enumerated() {
            let rendered = UpperPercussionTailDSPContract.process(
                sample: sample,
                role: .naturalBody,
                frame: frame,
                renderedFrameCount: samples.count,
                sampleRate: 48_000
            )
            #expect(rendered.bitPattern == sample.bitPattern)
        }
    }

    @Test("Clearance changes only post-attack samples and preserves signed zero")
    func clearanceConsequence() {
        let sampleRate = 48_000.0
        let frameCount = Int((0.05 * sampleRate).rounded())
        let attackFrames = UpperPercussionTailDSPContract.attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: frameCount
        )
        let base = (0..<frameCount).map { frame in
            Float(sin(Double(frame) * 0.073)) * 0.3
        }
        let rendered = base.enumerated().map { frame, sample in
            UpperPercussionTailDSPContract.process(
                sample: sample,
                role: .foregroundClearance,
                frame: frame,
                renderedFrameCount: frameCount,
                sampleRate: sampleRate
            )
        }

        #expect(zip(base.prefix(attackFrames), rendered.prefix(attackFrames))
            .allSatisfy { $0.bitPattern == $1.bitPattern })
        #expect(zip(base.dropFirst(attackFrames + 1),
                    rendered.dropFirst(attackFrames + 1)).contains {
            $0.bitPattern != $1.bitPattern
        })
        #expect(abs(rendered.last ?? 0) <= abs(base.last ?? 0))

        let negativeZero = Float(bitPattern: 0x8000_0000)
        let processedZero = UpperPercussionTailDSPContract.process(
            sample: negativeZero,
            role: .foregroundClearance,
            frame: frameCount - 1,
            renderedFrameCount: frameCount,
            sampleRate: sampleRate
        )
        #expect(processedZero.bitPattern == negativeZero.bitPattern)
    }

    @Test("Degenerate geometry remains finite and bounded")
    func degenerateGeometry() {
        for frameCount in 0...3 {
            for frame in -1...4 {
                let value = UpperPercussionTailDSPContract.multiplier(
                    role: .foregroundClearance,
                    frame: frame,
                    renderedFrameCount: frameCount,
                    sampleRate: 8_000
                )
                #expect(value.isFinite)
                #expect(value >=
                        UpperPercussionTailDSPContract.clearanceFinalMultiplier)
                #expect(value <= 1)
            }
        }
    }

    private func activeResolvedBar() -> (
        seed: UInt64,
        plan: AutonomousPhrasePlan,
        resolved: ResolvedPerformanceBar
    )? {
        for seed in UInt64(1)...128 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let plan = director.plan(from: director.initialState())
            if let resolved = plan.resolvedBars.first(where: { bar in
                !bar.upperPercussionTailArticulations.isEmpty &&
                    bar.upperPercussionTailArticulations.allSatisfy {
                        $0.role == .foregroundClearance
                    }
            }) {
                return (seed, plan, resolved)
            }
        }
        return nil
    }

    private func replacingTail(
        in source: ResolvedPerformanceBar,
        with articulations: [UpperPercussionTailArticulation]
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: source.performance,
            ensemble: source.ensemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationCompanion: source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: source.groovePulses,
            closedHatDecayArticulations: source.closedHatDecayArticulations,
            upperPercussionTailArticulations: articulations,
            modalPercussionArticulations: source.modalPercussionArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: source.kickSyntaxRole,
            percussionEchoTexture: source.percussionEchoTexture
        )
    }

    private func render(
        plan: AutonomousPhrasePlan,
        resolved: ResolvedPerformanceBar,
        sampleRate: Double
    ) -> RenderedBar {
        let synthPlan = SynthPerformancePlan(
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
            synthWorld: synthPlan.world,
            synthPerformance: synthPlan.bars[0],
            workspace: &workspace,
            layer: .full,
            phraseKind: plan.kind
        )
    }
}
