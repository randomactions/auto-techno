import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Score-owned foundation rhythm")
struct FoundationRhythmicRelationTests {
    @Test("Dotted relation owns one exact kick-complementary two-bar cell")
    func dottedCellGeometry() {
        #expect(FoundationRhythmicRelationContract.cellLengthInBars == 2)
        #expect(FoundationRhythmicRelationContract.intervalInSteps == 3)
        #expect(FoundationRhythmicRelationContract.pairPhase(absoluteBar: 0) == 0)
        #expect(FoundationRhythmicRelationContract.pairPhase(absoluteBar: 1) == 1)
        #expect(FoundationRhythmicRelationContract.pairPhase(absoluteBar: 16) == 0)
        #expect(FoundationRhythmicRelationContract.firstBarBassSteps == [3, 6, 9, 15])
        #expect(FoundationRhythmicRelationContract.secondBarBassSteps == [2, 5, 11, 14])
        #expect(FoundationRhythmicRelationContract.stepMask(pairPhase: 0) == 0x8248)
        #expect(FoundationRhythmicRelationContract.stepMask(pairPhase: 1) == 0x4824)
    }

    @Test("Established evidence retains same-step bass multiplicity")
    func establishedEvidenceMultiplicity() {
        let duplicateStepMask = UInt16(1) << UInt16(5)
        let evidence = AutonomousFoundationRhythmBarEvidence(
            bar: 21,
            relation: .established,
            pairPhase: 1,
            scoreBassEventCount: 2,
            scoreBassStepMask: duplicateStepMask,
            renderedBassEventCount: 2,
            renderedBassStepMask: duplicateStepMask,
            renderedFrameCount: Int((
                240.0 / AutonomousSessionDirector.bpm * 8_000.0
            ).rounded()),
            renderedStartFrameFingerprint: "0123456789abcdef",
            dryFoundationSampleHash: "fedcba9876543210",
            peak: 0.1,
            rms: 0.05,
            bassPluckAssigned: false,
            renderPassesMatch: true,
            bindingValid: true,
            finite: true
        )
        #expect(evidence.isComplete(sampleRate: 8_000))
    }

    @Test("Director reaches bounded dotted pairs without changing non-bass score")
    func directorDottedPairs() throws {
        var activePairs = 0
        for rawSeed in 1...48 {
            let director = AutonomousSessionDirector(rootSeed: UInt64(rawSeed))
            var state = director.initialState()
            for _ in 0..<80 {
                let plan = director.plan(from: state)
                let synth = SynthPerformancePlan(
                    scene: plan.scene,
                    dna: plan.dna,
                    kind: plan.kind,
                    resolvedBars: plan.resolvedBars
                )
                for index in plan.resolvedBars.indices {
                    let resolved = plan.resolvedBars[index]
                    guard resolved.foundationRhythmicRelation ==
                            .dottedThreeSixteenth else {
                        continue
                    }
                    let phase = FoundationRhythmicRelationContract.pairPhase(
                        absoluteBar: resolved.performance.bar
                    )
                    let expectedSteps = FoundationRhythmicRelationContract
                        .bassSteps(pairPhase: phase)
                    let bassSteps = resolved.ensemble.events.filter {
                        $0.voice == .bass
                    }.map(\.step)
                    let baseline = AutonomousSessionDirector.ensemblePlan(
                        dna: plan.dna,
                        bar: resolved.performance,
                        focus: resolved.ensemble.focusRole,
                        release: false,
                        kind: plan.kind,
                        character: resolved.performanceCharacter,
                        foundationBehavior: resolved.foundationBehavior,
                        companion: resolved.foundationCompanion,
                        gear: resolved.percussionGear,
                        gesture: resolved.arrangementGesture
                    )
                    #expect(plan.kind == .lock)
                    #expect(resolved.performanceCharacter == .hypnoticLock)
                    #expect(resolved.foundationBehavior == .monotone)
                    #expect(resolved.foundationCompanion == .bass)
                    #expect(resolved.arrangementGesture == .steady)
                    #expect(resolved.ensemble.kickAnchors == [0, 4, 8, 12])
                    #expect(bassSteps == expectedSteps)
                    #expect(resolved.ensemble.events.filter { $0.voice != .bass } ==
                            baseline.events.filter { $0.voice != .bass })
                    #expect(synth.bars[index].foundationInstrument.patch == .bassPluck)
                    #expect(synth.bars[index].foundationInstrument.automation.space == 0)
                    if phase == 0 {
                        let next = try #require(
                            plan.resolvedBars.indices.contains(index + 1)
                                ? plan.resolvedBars[index + 1] : nil
                        )
                        #expect(next.foundationRhythmicRelation ==
                                .dottedThreeSixteenth)
                        activePairs += 1
                    }
                }
                state.advancePlanning(using: plan)
            }
        }
        #expect(activePairs > 0)
    }

    @Test("Incomplete and ineligible pairs remain established")
    func exactNeutralFallbacks() throws {
        let fixture = try #require(firstDottedPlan())
        let activeIndex = try #require(fixture.resolvedBars.firstIndex {
            $0.foundationRhythmicRelation == .dottedThreeSixteenth &&
                FoundationRhythmicRelationContract.pairPhase(
                    absoluteBar: $0.performance.bar
                ) == 0
        })
        let activePair = Array(fixture.resolvedBars[activeIndex...activeIndex + 1])
        let alreadyResolved = FoundationRhythmicRelationResolver.resolve(
            resolvedBars: activePair,
            kind: .lock,
            dna: fixture.dna
        )
        #expect(alreadyResolved == activePair)

        let incomplete = FoundationRhythmicRelationResolver.resolve(
            resolvedBars: [activePair[0]],
            kind: .lock,
            dna: fixture.dna
        )
        #expect(incomplete == [activePair[0]])

        let wrongKind = FoundationRhythmicRelationResolver.resolve(
            resolvedBars: activePair,
            kind: .contrast,
            dna: fixture.dna
        )
        #expect(wrongKind == activePair)
    }

    @Test("Dotted foundation rendering is bounded and isolated at every route rate")
    func dottedFoundationRendering() throws {
        let plan = try #require(firstDottedPlan())
        let activeIndex = try #require(plan.resolvedBars.firstIndex {
            $0.foundationRhythmicRelation == .dottedThreeSixteenth
        })
        let active = plan.resolvedBars[activeIndex]
        let established = establishedBaseline(from: active, plan: plan)

        for sampleRate in [8_000.0, 44_100, 48_000, 96_000, 192_000] {
            let activeProtected = renderProjection(
                resolved: active,
                plan: plan,
                sampleRate: sampleRate,
                layer: .protectedRhythm
            )
            let activeFull = renderProjection(
                resolved: active,
                plan: plan,
                sampleRate: sampleRate,
                layer: .full
            )
            let neutral = renderProjection(
                resolved: established,
                plan: plan,
                sampleRate: sampleRate,
                layer: .protectedRhythm
            )
            let evidence = activeProtected.foundation
            let expectedFrames = Int((
                240.0 / AutonomousSessionDirector.bpm * sampleRate
            ).rounded())
            let phase = FoundationRhythmicRelationContract.pairPhase(
                absoluteBar: active.performance.bar
            )

            #expect(evidence == activeFull.foundation)
            #expect(evidence.relation == .dottedThreeSixteenth)
            #expect(evidence.sampleRate == sampleRate)
            #expect(evidence.renderedFrameCount == expectedFrames)
            #expect(evidence.renderedBassEventCount == 4)
            #expect(evidence.renderedBassStepMask ==
                    FoundationRhythmicRelationContract.stepMask(
                        pairPhase: phase
                    ))
            #expect(evidence.renderedStartFrames.count == 4)
            #expect(evidence.peak > 0 && evidence.rms > 0)
            #expect(evidence.peak >= evidence.rms)
            #expect(evidence.finite)
            #expect(evidence.dryFoundationSampleHash !=
                    neutral.foundation.dryFoundationSampleHash)
            #expect(activeProtected.kickMix == neutral.kickMix)
            #expect(activeProtected.dryPercussionSampleHash ==
                    neutral.dryPercussionSampleHash)
            #expect(activeProtected.groovePulseRenderEvidence ==
                    neutral.groovePulseRenderEvidence)
            #expect(activeProtected.closedHatRenderEvidence ==
                    neutral.closedHatRenderEvidence)
        }
    }

    @MainActor
    @Test("Prepared evidence binds dotted score timing to dry foundation PCM")
    func dottedFoundationCandidateEvidence() throws {
        let director = AutonomousSessionDirector()
        var state = director.initialState()

        for _ in 0..<128 {
            let plan = director.plan(from: state)
            let activeIndexes = plan.resolvedBars.indices.filter {
                plan.resolvedBars[$0].foundationRhythmicRelation ==
                    .dottedThreeSixteenth
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
            #expect(vector.foundationRhythm.count == plan.barCount)
            #expect(vector.sourceFoundationRhythmBarCount == plan.barCount)

            let activeRecords = activeIndexes.map {
                vector.foundationRhythm[$0]
            }
            for (record, index) in zip(activeRecords, activeIndexes) {
                let score = plan.resolvedBars[index]
                let phase = FoundationRhythmicRelationContract.pairPhase(
                    absoluteBar: score.performance.bar
                )
                #expect(record.bar == score.performance.bar)
                #expect(record.relation ==
                        FoundationRhythmicRelation.dottedThreeSixteenth.rawValue)
                #expect(record.pairPhase == phase)
                #expect(record.scoreBassEventCount == 4)
                #expect(record.renderedBassEventCount == 4)
                #expect(record.scoreBassStepMask ==
                        FoundationRhythmicRelationContract.stepMask(
                            pairPhase: phase
                        ))
                #expect(record.scoreBassStepMask == record.renderedBassStepMask)
                #expect(record.peak > 0 && record.rms > 0)
                #expect(record.bassPluckAssigned)
                #expect(record.renderPassesMatch && record.bindingValid)
                #expect(record.isComplete(sampleRate: 8_000))
            }

            let applicable = CanonicalJourneyCheckpoint.applicable(
                phraseIndex: vector.symbolic.phraseIndex,
                phraseKind: .lock,
                chapterChanged: vector.symbolic.chapterChanged
            )
            if let checkpoint = applicable.first {
                let observation = try ProfessionalQualityObservation(
                    candidate: vector,
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: checkpoint
                )
                let expectedActiveRatio = Double(activeRecords.count) /
                    Double(plan.barCount)
                let activeCrestFactorSum = activeRecords.reduce(0.0) {
                    partial, record in
                    partial + 20 * (log10(record.peak) - log10(record.rms))
                }
                let expectedCrestFactor = activeCrestFactorSum /
                    Double(activeRecords.count)
                #expect(observation[
                    .foundationDottedRhythmActiveBarRatio
                ] == expectedActiveRatio)
                #expect(observation[
                    .foundationDottedRhythmCrestFactorDBMean
                ] == expectedCrestFactor)
            }

            let record = try #require(activeRecords.first)
            let encoded = try JSONEncoder().encode(record)
            let json = try #require(
                JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            )
            #expect(Set(json.keys) == [
                "bar", "relation", "pairPhase", "scoreBassEventCount",
                "scoreBassStepMask", "renderedBassEventCount",
                "renderedBassStepMask", "renderedFrameCount",
                "renderedStartFrameFingerprint", "dryFoundationSampleHash",
                "peak", "rms", "bassPluckAssigned", "renderPassesMatch",
                "bindingValid", "finite",
            ])
            func forged(_ key: String, _ value: Any) throws
                    -> AutonomousFoundationRhythmBarEvidence {
                var changed = json
                changed[key] = value
                return try JSONDecoder().decode(
                    AutonomousFoundationRhythmBarEvidence.self,
                    from: JSONSerialization.data(withJSONObject: changed)
                )
            }
            let invalid = try [
                forged("pairPhase", 2),
                forged("scoreBassEventCount", 3),
                forged("renderedBassStepMask", 0),
                forged("renderedFrameCount", 0),
                forged("renderedStartFrameFingerprint", "invalid"),
                forged("dryFoundationSampleHash", "invalid"),
                forged("peak", 0),
                forged("bassPluckAssigned", false),
                forged("renderPassesMatch", false),
                forged("bindingValid", false),
                forged("finite", false),
            ]
            #expect(invalid.allSatisfy { !$0.isComplete(sampleRate: 8_000) })

            let activeFingerprint = AutonomousCandidateFingerprint.plan(plan)
            var changedBars = plan.resolvedBars
            changedBars[activeIndexes[0]] = replacingRelation(
                in: changedBars[activeIndexes[0]],
                with: .established
            )
            let changedPlan = AutonomousPhrasePlan(
                phraseIndex: plan.phraseIndex,
                startBar: plan.startBar,
                barCount: plan.barCount,
                kind: plan.kind,
                scene: plan.scene,
                dna: plan.dna,
                resolvedBars: changedBars,
                openedDebt: plan.openedDebt,
                paidDebtIDs: plan.paidDebtIDs,
                requestsTopologyMutation: plan.requestsTopologyMutation,
                interest: plan.interest,
                endingInterlockState: plan.endingInterlockState,
                endingSpatialContrastState: plan.endingSpatialContrastState,
                endingNarrativeState: plan.endingNarrativeState,
                harmonicContinuation: plan.incomingHarmonicContinuation
            )
            #expect(AutonomousCandidateFingerprint.plan(changedPlan) !=
                    activeFingerprint)
            var forgedRenderState = RenderState()
            forgedRenderState.barIndex = state.memory.totalBars
            #expect(AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: changedPlan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: 8_000,
                incomingRenderState: forgedRenderState,
                incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil,
                incomingQualityState: state.quality,
                evaluator: AcceptingPrimaryTestEvaluator(),
                cancellationRequested: { false }
            ) == nil)
            return
        }
        Issue.record("Expected a naturally reachable dotted foundation phrase")
    }

    private struct RenderProjection {
        let foundation: FoundationRhythmRenderEvidence
        let kickMix: KickMixEvidence
        let dryPercussionSampleHash: String
        let groovePulseRenderEvidence: [GroovePulseRenderEvidence]
        let closedHatRenderEvidence: [ClosedHatRenderEvidence]
    }

    @inline(never)
    private func renderProjection(
        resolved: ResolvedPerformanceBar,
        plan: AutonomousPhrasePlan,
        sampleRate: Double,
        layer: RenderLayer
    ) -> RenderProjection {
        let synth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [resolved]
        )
        var state = RenderState()
        state.barIndex = resolved.performance.bar
        var workspace = RenderWorkspace()
        let rendered = VoiceRenderer.renderBar(
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
        return RenderProjection(
            foundation: rendered.foundationRhythmRenderEvidence,
            kickMix: rendered.kickMix,
            dryPercussionSampleHash: rendered.dryPercussionSampleHash,
            groovePulseRenderEvidence: rendered.groovePulseRenderEvidence,
            closedHatRenderEvidence: rendered.closedHatRenderEvidence
        )
    }

    private func establishedBaseline(
        from active: ResolvedPerformanceBar,
        plan: AutonomousPhrasePlan
    ) -> ResolvedPerformanceBar {
        let ensemble = AutonomousSessionDirector.ensemblePlan(
            dna: plan.dna,
            bar: active.performance,
            focus: active.ensemble.focusRole,
            release: false,
            kind: plan.kind,
            character: active.performanceCharacter,
            foundationBehavior: active.foundationBehavior,
            companion: active.foundationCompanion,
            gear: active.percussionGear,
            gesture: active.arrangementGesture
        )
        return replacingRelation(
            in: active,
            with: .established,
            ensemble: ensemble
        )
    }

    private func replacingRelation(
        in resolved: ResolvedPerformanceBar,
        with relation: FoundationRhythmicRelation,
        ensemble: EnsembleContext? = nil
    ) -> ResolvedPerformanceBar {
        ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: ensemble ?? resolved.ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            performanceCharacter: resolved.performanceCharacter,
            foundationBehavior: resolved.foundationBehavior,
            foundationRhythmicRelation: relation,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: resolved.groovePulses,
            closedHatDecayArticulations: resolved.closedHatDecayArticulations,
            upperPercussionTailArticulations:
                resolved.upperPercussionTailArticulations,
            modalPercussionArticulations:
                resolved.modalPercussionArticulations,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative,
            kickSyntaxRole: resolved.kickSyntaxRole,
            percussionEchoTexture: resolved.percussionEchoTexture
        )
    }

    private func firstDottedPlan() -> AutonomousPhrasePlan? {
        for rawSeed in 1...48 {
            let director = AutonomousSessionDirector(rootSeed: UInt64(rawSeed))
            var state = director.initialState()
            for _ in 0..<80 {
                let plan = director.plan(from: state)
                if plan.resolvedBars.contains(where: {
                    $0.foundationRhythmicRelation == .dottedThreeSixteenth
                }) {
                    return plan
                }
                state.advancePlanning(using: plan)
            }
        }
        return nil
    }
}
