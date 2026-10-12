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

    @Test("Dotted score owns one bounded in-bar pre-kick pocket per phase")
    func preKickPocketScoreOwnership() throws {
        let plan = try #require(firstDottedPlan())
        let activeBars = plan.resolvedBars.filter {
            $0.foundationRhythmicRelation == .dottedThreeSixteenth
        }
        #expect(!activeBars.isEmpty)

        for resolved in activeBars {
            let articulation = try #require(
                FoundationPreKickPocketResolver.articulation(in: resolved)
            )
            let phase = FoundationRhythmicRelationContract.pairPhase(
                absoluteBar: resolved.performance.bar
            )
            let expectedBassStep = phase == 0 ? 3 : 11
            let expectedKickStep = phase == 0 ? 4 : 12
            #expect(articulation.relation == .preKickClearance)
            #expect(articulation.bassStep == expectedBassStep)
            #expect(articulation.kickStep == expectedKickStep)
            #expect(articulation.releaseStartStep ==
                    Double(expectedKickStep) -
                        FoundationPreKickPocketContract.releaseLeadInSteps)
            #expect(articulation.releaseEndStep ==
                    Double(expectedKickStep) -
                        FoundationPreKickPocketContract.silenceLeadInSteps)
            #expect(resolved.ensemble.events.indices.contains(
                articulation.scoreEventIndex
            ))
            #expect(resolved.ensemble.events[articulation.scoreEventIndex].voice == .bass)
            #expect(resolved.ensemble.events[articulation.scoreEventIndex].step ==
                    expectedBassStep)
            #expect(resolved.ensemble.kickAnchors.contains(expectedKickStep))
        }
    }

    @Test("Established and malformed foundation relations remain pocket-neutral")
    func preKickPocketNeutralFallback() throws {
        let plan = try #require(firstDottedPlan())
        let active = try #require(plan.resolvedBars.first {
            $0.foundationRhythmicRelation == .dottedThreeSixteenth
        })
        #expect(FoundationPreKickPocketResolver.articulation(
            in: replacingRelation(in: active, with: .established)
        ) == nil)

        let malformedEnsemble = EnsembleContext(
            focusRole: active.ensemble.focusRole,
            events: active.ensemble.events.filter {
                !($0.voice == .bass && $0.step + 1 == 4)
            },
            kickAnchors: active.ensemble.kickAnchors,
            intentionalPileup: active.ensemble.intentionalPileup
        )
        #expect(FoundationPreKickPocketResolver.articulation(
            in: replacingRelation(
                in: active,
                with: .dottedThreeSixteenth,
                ensemble: malformedEnsemble
            )
        ) == nil)
    }

    @Test("Pre-kick terminal release is bounded, monotone, and exactly neutral")
    func preKickPocketReleaseCurve() {
        let release = 4..<12
        #expect(ResonantMonoVoice.terminalReleaseGain(
            frameIndex: 0,
            release: nil
        ) == 1)
        #expect(ResonantMonoVoice.terminalReleaseGain(
            frameIndex: release.lowerBound - 1,
            release: release
        ) == 1)
        #expect(ResonantMonoVoice.terminalReleaseGain(
            frameIndex: release.lowerBound,
            release: release
        ) == 1)
        #expect(ResonantMonoVoice.terminalReleaseGain(
            frameIndex: release.upperBound,
            release: release
        ) == 0)
        let gains = (release.lowerBound...release.upperBound).map {
            ResonantMonoVoice.terminalReleaseGain(
                frameIndex: $0,
                release: release
            )
        }
        #expect(gains.allSatisfy { (0...1).contains($0) })
        #expect(zip(gains, gains.dropFirst()).allSatisfy { pair in
            pair.0 >= pair.1
        })
    }

    @Test("Pre-kick release changes only the same foundation event tail")
    func preKickPocketSameEventPCMOracle() throws {
        let plan = try #require(firstDottedPlan())
        let active = try #require(plan.resolvedBars.first {
            $0.foundationRhythmicRelation == .dottedThreeSixteenth
        })
        let articulation = try #require(
            FoundationPreKickPocketResolver.articulation(in: active)
        )
        let event = active.ensemble.events[articulation.scoreEventIndex]
        let sampleRate = 48_000.0
        let frameCount = Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded())
        let stepFrames = Double(frameCount) / 16.0
        let eventOffset = VoiceRenderer.timingOffsetInSteps(
            for: event.voice,
            step: event.step,
            dna: plan.dna
        )
        let eventStartFrame = Int((
            (Double(event.step) + eventOffset) * stepFrames
        ).rounded())
        let kickOffset = VoiceRenderer.timingOffsetInSteps(
            for: .kick,
            step: articulation.kickStep,
            dna: plan.dna
        )
        let releaseStartFrame = Int(((
            articulation.releaseStartStep + kickOffset
        ) * stepFrames).rounded())
        let releaseEndFrame = Int(((
            articulation.releaseEndStep + kickOffset
        ) * stepFrames).rounded())
        let kickFrame = Int(((
            Double(articulation.kickStep) + kickOffset
        ) * stepFrames).rounded())
        let synth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [active]
        )

        func render(
            releaseStart: Int?,
            releaseEnd: Int?
        ) -> (
            samples: [Float],
            measurement: [Float],
            result: ResonantMonoFoundationRenderResult
        ) {
            var output = [Float](repeating: 0, count: frameCount)
            var measurement = [Float](repeating: 0, count: frameCount)
            var architecture = [Float](repeating: 0, count: frameCount)
            var pulseEcho = [Float](repeating: 0, count: frameCount)
            var reverb = [Float](repeating: 0, count: frameCount)
            var state = ResonantMonoState()
            var nonlinearCoreEvidence =
                TPTAntialiasedNonlinearCoreEvidenceAccumulator()
            let result = ResonantMonoVoice.renderFoundation(
                &output,
                measurement: &measurement,
                architectureMeasurement: &architecture,
                pulseEchoSend: &pulseEcho,
                spatialReverbSend: &reverb,
                start: eventStartFrame,
                sampleRate: sampleRate,
                level: 0.12,
                frequency: 110,
                assignment: synth.bars[0].foundationInstrument,
                velocity: 0.82,
                terminalReleaseStartFrame: releaseStart,
                terminalReleaseEndFrame: releaseEnd,
                state: &state,
                nonlinearCoreEvidence: &nonlinearCoreEvidence
            )
            return (output, measurement, result)
        }

        let neutral = render(releaseStart: nil, releaseEnd: nil)
        let pocket = render(
            releaseStart: releaseStartFrame,
            releaseEnd: releaseEndFrame
        )
        #expect(!neutral.result.terminalReleaseApplied)
        #expect(pocket.result.terminalReleaseApplied)
        #expect(neutral.result.naturalFrameCount ==
                pocket.result.naturalFrameCount)
        #expect(eventStartFrame + neutral.result.naturalFrameCount > kickFrame)
        #expect(eventStartFrame + pocket.result.appliedFrameCount ==
                releaseEndFrame)
        #expect(Array(neutral.samples[..<releaseStartFrame]) ==
                Array(pocket.samples[..<releaseStartFrame]))
        #expect(pocket.samples[releaseEndFrame..<kickFrame].allSatisfy {
            $0 == 0
        })
        #expect(neutral.samples[releaseEndFrame..<kickFrame].contains {
            $0 != 0
        })
        #expect(pocket.samples != neutral.samples)
        #expect(pocket.measurement == pocket.samples)
        #expect(neutral.measurement == neutral.samples)
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

    @Test("Director reaches bounded dotted pairs without changing post-polymetric non-bass score")
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
                    let postPolymetricBaseline =
                        LongHorizonPolymetricGrammarResolver.relocatePercussion(
                            ensemble: baseline,
                            grammar: plan.materialWorld.polymetricGrammar,
                            absoluteBar: resolved.performance.bar
                        ).ensemble
                    #expect(plan.kind == .lock)
                    #expect(resolved.performanceCharacter == .hypnoticLock)
                    #expect(resolved.foundationBehavior == .monotone)
                    #expect(resolved.foundationCompanion == .bass)
                    #expect(resolved.arrangementGesture == .steady)
                    #expect(resolved.ensemble.kickAnchors == [0, 4, 8, 12])
                    #expect(bassSteps == expectedSteps)
                    #expect(resolved.ensemble.events.filter { $0.voice != .bass } ==
                            postPolymetricBaseline.events.filter {
                                $0.voice != .bass
                            })
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
            let pocket = evidence.preKickPocket
            let expectedBassStep = phase == 0 ? 3 : 11
            let expectedKickStep = phase == 0 ? 4 : 12
            let expectedKickFrame = Int((
                Double(expectedKickStep) * Double(expectedFrames) / 16.0
            ).rounded())
            let expectedReleaseStart = Int(((
                Double(expectedKickStep) -
                    FoundationPreKickPocketContract.releaseLeadInSteps
            ) * Double(expectedFrames) / 16.0).rounded())
            let expectedReleaseEnd = Int(((
                Double(expectedKickStep) -
                    FoundationPreKickPocketContract.silenceLeadInSteps
            ) * Double(expectedFrames) / 16.0).rounded())
            #expect(pocket.relation == .preKickClearance)
            #expect(pocket.bassStep == expectedBassStep)
            #expect(pocket.kickStep == expectedKickStep)
            #expect(pocket.eventStartFrame == evidence.renderedStartFrames.first {
                $0 < expectedKickFrame && $0 >= Int(Double(expectedBassStep) *
                    Double(expectedFrames) / 16.0)
            })
            #expect(pocket.naturalEndFrame > pocket.kickFrame)
            #expect(pocket.releaseStartFrame == expectedReleaseStart)
            #expect(pocket.releaseEndFrame == expectedReleaseEnd)
            #expect(pocket.kickFrame == expectedKickFrame)
            #expect(pocket.releaseFrameCount ==
                    expectedReleaseEnd - expectedReleaseStart)
            #expect(pocket.silenceFrameCount ==
                    expectedKickFrame - expectedReleaseEnd)
            #expect(pocket.silenceSampleHash.count == 16)
            #expect(pocket.silencePeak == 0)
            #expect(pocket.silenceRMS == 0)
            #expect(pocket.applied && pocket.finite)
            #expect(evidence.dryFoundationSampleHash !=
                    neutral.foundation.dryFoundationSampleHash)
            #expect(neutral.foundation.preKickPocket == .neutral)
            #expect(activeProtected.kickMix == neutral.kickMix)
            #expect(activeProtected.dryPercussionSampleHash ==
                    neutral.dryPercussionSampleHash)
            #expect(activeProtected.groovePulseRenderEvidence ==
                    neutral.groovePulseRenderEvidence)
            #expect(activeProtected.closedHatRenderEvidence ==
                    neutral.closedHatRenderEvidence)
        }
    }

    @Test("Home-upper correction preserves the score-owned foundation pocket")
    func correctionPreservesPreKickPocket() throws {
        let plan = try #require(firstDottedPlan())
        let active = try #require(plan.resolvedBars.first {
            $0.foundationRhythmicRelation == .dottedThreeSixteenth
        })
        let initial = renderProjection(
            resolved: active,
            plan: plan,
            sampleRate: 48_000,
            layer: .full
        )
        let correction = renderProjection(
            resolved: active,
            plan: plan,
            sampleRate: 48_000,
            layer: .full,
            forceHomeUpperTimbre: true
        )

        #expect(initial.foundation.preKickPocket.applied)
        #expect(initial.foundation == correction.foundation)
        #expect(initial.kickMix == correction.kickMix)
        #expect(initial.dryPercussionSampleHash ==
                correction.dryPercussionSampleHash)
        #expect(initial.groovePulseRenderEvidence ==
                correction.groovePulseRenderEvidence)
        #expect(initial.closedHatRenderEvidence ==
                correction.closedHatRenderEvidence)
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
                #expect(record.preKickPocket.relation ==
                        FoundationPreKickPocketRelation.preKickClearance.rawValue)
                #expect(record.preKickPocket.silencePeak == 0)
                #expect(record.preKickPocket.silenceRMS == 0)
                #expect(record.preKickPocket.isComplete(
                    sampleRate: 8_000,
                    renderedFrameCount: record.renderedFrameCount
                ))
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
                #expect(observation[
                    .foundationPreKickPocketSilenceRMSMaximum
                ] == 0)
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
                "preKickPocket", "bindingValid", "finite",
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

            var contaminatedJSON = json
            var contaminatedPocket = try #require(
                contaminatedJSON["preKickPocket"] as? [String: Any]
            )
            contaminatedPocket["silenceRMS"] = 0.01
            contaminatedJSON["preKickPocket"] = contaminatedPocket
            let contaminated = try JSONDecoder().decode(
                AutonomousFoundationRhythmBarEvidence.self,
                from: JSONSerialization.data(withJSONObject: contaminatedJSON)
            )
            #expect(!contaminated.isComplete(sampleRate: 8_000))

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

    @MainActor
    @Test("Native full-phrase bass faults cannot bind to the original transaction")
    func algorithmicFullPhraseBassFaults() throws {
        try fullPhraseFoundationFaults(voice: .bass)
    }

    @MainActor
    @Test("Native full-phrase companion faults cannot bind to the original transaction")
    func algorithmicFullPhraseCompanionFaults() throws {
        try fullPhraseFoundationFaults(voice: .rumble)
        try fullPhraseFoundationFaults(voice: .tunedTom)
    }

    @MainActor
    private func fullPhraseFoundationFaults(voice: EnsembleVoice) throws {
        struct Row: Encodable {
            let rootSeed: UInt64
            let split: String
            let sampleRate: Int
            let scenario: String
            let originalPlanFingerprint: String
            let renderedPlanFingerprint: String
            let originalSampleHash: String
            let renderedSampleHash: String
            let originalBassEvents: Int?
            let renderedBassEvents: Int?
            let companionVoice: String?
            let originalCompanionEvents: Int?
            let renderedCompanionEvents: Int?
            let companionMatchesOriginal: Bool?
            let frameCount: Int
            let differenceRMS: Double
            let foundationComplete: Bool
            let vectorComplete: Bool
            let transactionComplete: Bool
            let exactReplay: Bool
        }
        struct Report: Encodable {
            let schema: String
            let scope = "canonical-full-phrase-render-and-candidate-transaction-binding"
            let unavailable: [String]
            let rows: [Row]
        }
        let unavailable = ["all-foundation-behaviors", voice == .bass ? "companion-and-truncation-faults" : "unauthorized-truncation",
                "accepted-continuous-journey", "production-calibration", "perceptual-quality",
                "full-prepared-commit-fault-matrix", "population-error-intervals"]
        // Fixed before native PCM inspection. Select the first score-only phrase
        // with positive target-voice events within128 proposals, retaining its
        // canonical plan, memory and graph. Rates/replays are paired observations.
        // Fault PCM is rerendered through the complete canonical phrase graph;
        // never subtract a dry stem from an already processed nonlinear mix.
        var rows: [Row] = []
        for seed: UInt64 in [1, 6011] {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var session = director.initialState()
            var chosen: AutonomousPhrasePlan?
            for _ in 0..<128 {
                let plan = director.plan(from: session)
                if plan.resolvedBars.contains(where: { bar in
                    (voice != .bass || bar.foundationRhythmicRelation == .established) &&
                    bar.ensemble.events.contains(where: { $0.voice == voice && $0.intensity > 0 })
                }) {
                    chosen = plan; break
                }
                session.advancePlanning(using: plan)
            }
            let original = try #require(chosen)
            let originalEvents = original.resolvedBars.flatMap(\.ensemble.events).filter { $0.voice == voice }.count
            #expect(originalEvents > 0)
            func copyingPlan(_ bars: [ResolvedPerformanceBar]) -> AutonomousPhrasePlan {
                AutonomousPhrasePlan(phraseIndex: original.phraseIndex, startBar: original.startBar,
                    barCount: original.barCount, kind: original.kind, scene: original.scene, dna: original.dna,
                    resolvedBars: bars, openedDebt: original.openedDebt, paidDebtIDs: original.paidDebtIDs,
                    requestsTopologyMutation: original.requestsTopologyMutation, interest: original.interest,
                    endingInterlockState: original.endingInterlockState,
                    endingSpatialContrastState: original.endingSpatialContrastState,
                    endingNarrativeState: original.endingNarrativeState,
                    harmonicContinuation: original.incomingHarmonicContinuation,
                    resampledMemory: original.incomingResampledMemory,
                    longHorizonSelection: original.longHorizonSelection,
                    longHorizonEnergyCoordination: original.longHorizonEnergyCoordination,
                    materialWorld: original.materialWorld,
                    incomingEffectCarrierState: session.memory.longHorizon.effectCarrierState,
                    qualityRecoveryContext: original.qualityRecoveryContext,
                    presentationStartBar: original.presentationStartBar)
            }
            // Require a lossless no-op reconstruction before permitting the
            // intervention. Constructor normalization must not hide another edit.
            try #require(copyingPlan(original.resolvedBars) == original)
            // Reuse the frozen component recipes verbatim. These roots and
            // recipes are already known; this adds canonical nonlinear coverage,
            // not new independent families or held-out population evidence.
            let deleted = voice == .bass ? "deleted-bass" : "deleted-companion"
            let shifted = voice == .bass ? "shifted-bass" : "shifted-companion"
            let scenarios = ["unaltered", deleted, shifted, "wrong-voice", "zero-intensity"]
            let variants = try scenarios.map { scenario -> (String, AutonomousPhrasePlan) in
                let bars = original.resolvedBars.map { bar in
                    let events = bar.ensemble.events.compactMap { event -> EnsembleResolvedEvent? in
                        guard event.voice == voice else { return event }
                        switch scenario {
                        case deleted: return nil
                        case shifted:
                            return EnsembleResolvedEvent(voice: voice, step: (event.step + 1) % 16,
                                intensity: event.intensity, relocated: event.relocated)
                        case "wrong-voice":
                            return EnsembleResolvedEvent(voice: .percussion, step: event.step,
                                intensity: event.intensity, relocated: event.relocated)
                        case "zero-intensity":
                            return EnsembleResolvedEvent(voice: voice, step: event.step,
                                intensity: 0, relocated: event.relocated)
                        default: return event
                        }
                    }
                    // Modal intent owns event intensity and onset as well as
                    // the ensemble. Apply the fault to both source declarations.
                    let articulations = bar.modalPercussionArticulations.compactMap { articulation -> ModalPercussionArticulation? in
                        guard voice == .tunedTom else { return articulation }
                        if scenario == deleted || scenario == "wrong-voice" { return nil }
                        return ModalPercussionArticulation(scoreEventIndex: articulation.scoreEventIndex,
                            step: scenario == shifted ? (articulation.step + 1) % 16 : articulation.step,
                            use: articulation.use, modalIdentity: articulation.modalIdentity,
                            modalDegree: articulation.modalDegree, octave: articulation.octave,
                            fundamentalHz: articulation.fundamentalHz, excitation: articulation.excitation,
                            damping: articulation.damping, brightness: articulation.brightness,
                            inharmonicity: articulation.inharmonicity,
                            eventIntensity: scenario == "zero-intensity" ? 0 : articulation.eventIntensity,
                            seed: articulation.seed, material: articulation.material, coupling: articulation.coupling)
                    }
                    return replacingRelation(in: bar, with: bar.foundationRhythmicRelation,
                        ensemble: EnsembleContext(focusRole: bar.ensemble.focusRole, events: events,
                            kickAnchors: bar.ensemble.kickAnchors,
                            intentionalPileup: bar.ensemble.intentionalPileup),
                        modalArticulations: articulations)
                }
                let variant = copyingPlan(bars)
                try #require(variant.resolvedBars == bars)
                if scenario == "unaltered" { try #require(variant == original) }
                else { try #require(variant != original) }
                return (scenario, variant)
            }
            for rate in [44_100.0, 48_000.0] {
                var incoming = RenderState(); incoming.barIndex = original.startBar
                let graphIncoming = GeneratedDSPContinuationState()
                let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
                    plan: original, sessionSeed: seed, memory: session.memory, sampleRate: rate,
                    incomingRenderState: incoming, incomingGraphState: graphIncoming,
                    previousGraph: nil, incomingQualityState: session.quality,
                    evaluator: AcceptingPrimaryTestEvaluator(), cancellationRequested: { false })
                let prepared = try #require(preparedResult)
                let reference = prepared.selectedCandidateEvidence
                try #require(reference.isComplete)
                try #require(prepared.candidateEvaluation.correctionCount == 0)
                try #require(reference.crossPhraseTransition == .initial)
                let route = reference.routeContinuation
                for (scenario, renderPlan) in variants {
                    var outgoing = incoming
                    var graphOutgoing = graphIncoming
                    let blocks = try #require(AutonomousPhraseRenderer.renderIfNotCancelled(
                        plan: renderPlan, graph: prepared.graph, sampleRate: rate,
                        state: &outgoing, graphState: &graphOutgoing, cancellationRequested: { false }))
                    let preflightResult = PhraseAudioPreflight(blocks: blocks, sampleRate: rate,
                        cancellationRequested: { false })
                    let preflight = try #require(preflightResult)
                    let vectorResult = AutonomousCandidateEvaluationVector.make(
                        plan: original, graph: prepared.graph, planFingerprint: reference.planFingerprint,
                        graphFingerprint: reference.graphFingerprint, blocks: blocks, audioPreflight: preflight,
                        crossPhraseTransition: .initial,
                        upperTimbreEvidence: UpperTimbreEvidence.aggregating(blocks.map(\.postGraphRemainderTimbreEvidence)),
                        sampleRate: rate, routeChannelCount: route.channelCount, routeGeneration: route.routeGeneration,
                        routeFingerprint: route.routeFingerprint,
                        incomingContinuationFingerprint: route.incomingContinuationFingerprint,
                        incomingRenderDSPFingerprint: route.incomingRenderDSPFingerprint,
                        incomingQualityStateFingerprint: route.incomingQualityStateFingerprint,
                        incomingKickCorrectionDB: route.incomingKickCorrectionDB,
                        incomingTopologyRevision: route.incomingTopologyRevision,
                        previousGraphFingerprint: route.previousGraphFingerprint, routeRecovery: route.routeRecovery,
                        outgoingRenderDSPFingerprint: AutonomousCandidateFingerprint.renderDSPContinuation(
                            renderState: outgoing, generatedDSPState: graphOutgoing),
                        controllerStateFingerprint: AutonomousCandidateFingerprint.combinedController(
                            kickCorrectionDB: outgoing.automaticMixState.kickCorrectionDB,
                            liveMasterHeadroom: prepared.liveMasterHeadroomContinuationState, proposalFingerprint: nil),
                        incomingLiveMasterState: prepared.incomingLiveMasterHeadroomState,
                        outgoingLiveMasterState: prepared.liveMasterHeadroomContinuationState,
                        liveProposal: nil, liveProposalOutcome: .hold, liveTargetStartSample: nil,
                        incomingDramaticDebts: session.memory.openDebts, cancellationRequested: { false })
                    let vector = try #require(vectorResult)
                    let transaction = AutonomousCandidateEvaluationTransaction(
                        engineVersion: prepared.candidateEvaluation.engineVersion,
                        policyVersion: prepared.candidateEvaluation.policyVersion,
                        evaluatorVersion: prepared.candidateEvaluation.evaluatorVersion,
                        planFingerprint: reference.planFingerprint,
                        attempts: [AutonomousCandidateAttempt(kind: .initialRender, vector: vector)],
                        selectedAttemptIndex: 0, correctionCount: 0)
                    let valid = scenario == "unaltered"
                    let renderedEventCount = blocks.reduce(0) { count, block in
                        if voice == .bass { return count + block.foundationRhythmRenderEvidence.renderedBassEventCount }
                        if voice == .rumble {
                            return count + block.sourceTerminalDeclickRenderEvidence.filter { $0.voice == .rumble }.count
                        }
                        return count + block.modalPercussionRenderEvidence.events.count
                    }
                    // The renderer counts scheduled bass voices with a natural
                    // duration, including zero-intensity events. Silence is a
                    // PCM/binding fault, not deletion of the scheduled event.
                    let retainsBassEvents = valid || scenario == shifted || scenario == "zero-intensity"
                    if voice == .bass {
                        #expect(renderedEventCount == (retainsBassEvents ? originalEvents : 0))
                    } else if valid {
                        #expect(renderedEventCount == originalEvents)
                    } else if scenario == deleted || scenario == "wrong-voice" {
                        #expect(renderedEventCount == 0)
                    }
                    #expect((AutonomousCandidateFingerprint.plan(renderPlan) == reference.planFingerprint) == valid)
                    let foundationComplete = vector.foundationRhythm.allSatisfy { $0.isComplete(sampleRate: rate) }
                    if voice == .bass { #expect(foundationComplete == valid) }
                    // Companion failures must refuse the complete original-score
                    // vector and transaction even when bass-only evidence holds.
                    #expect(vector.isComplete == valid)
                    #expect(transaction.isComplete == valid)
                    #expect(blocks.count == prepared.blocks.count)
                    let companionMatchesOriginal: Bool? = voice == .bass ? nil : zip(blocks, prepared.blocks).allSatisfy { actual, expected in
                        if voice == .rumble {
                            return actual.sourceTerminalDeclickRenderEvidence.filter { $0.voice == .rumble }
                                == expected.sourceTerminalDeclickRenderEvidence.filter { $0.voice == .rumble }
                        }
                        return actual.modalPercussionRenderEvidence == expected.modalPercussionRenderEvidence
                    }
                    if let companionMatchesOriginal { #expect(companionMatchesOriginal == valid) }
                    var errorEnergy = 0.0
                    var sampleCount = 0
                    for (actual, expected) in zip(blocks, prepared.blocks) {
                        try #require(actual.left.count == expected.left.count && actual.right.count == expected.right.count)
                        for (a, b) in zip(actual.left, expected.left) { let d = Double(a)-Double(b); errorEnergy += d*d }
                        for (a, b) in zip(actual.right, expected.right) { let d = Double(a)-Double(b); errorEnergy += d*d }
                        sampleCount += actual.left.count + actual.right.count
                    }
                    let difference = sqrt(errorEnergy / Double(max(1, sampleCount)))
                    #expect(difference.isFinite && (valid ? difference == 0 : difference > 0))
                    if valid {
                        let exactBlocks = blocks == prepared.blocks
                        let exactVector = vector == reference
                        try #require(exactBlocks)
                        try #require(exactVector)
                    }
                    else { #expect(vector.fullMix.sampleHash != reference.fullMix.sampleHash) }
                    var replayState = incoming
                    var replayGraph = graphIncoming
                    let replay = try #require(AutonomousPhraseRenderer.renderIfNotCancelled(
                        plan: renderPlan, graph: prepared.graph, sampleRate: rate,
                        state: &replayState, graphState: &replayGraph, cancellationRequested: { false }))
                    let exactReplay = replay == blocks &&
                        AutonomousCandidateFingerprint.renderDSPContinuation(renderState: replayState, generatedDSPState: replayGraph) ==
                        AutonomousCandidateFingerprint.renderDSPContinuation(renderState: outgoing, generatedDSPState: graphOutgoing)
                    #expect(exactReplay)
                    rows.append(Row(rootSeed: seed, split: seed == 1 ? "development" : "held-out-root",
                        sampleRate: Int(rate), scenario: scenario, originalPlanFingerprint: reference.planFingerprint,
                        renderedPlanFingerprint: AutonomousCandidateFingerprint.plan(renderPlan),
                        originalSampleHash: reference.fullMix.sampleHash, renderedSampleHash: vector.fullMix.sampleHash,
                        originalBassEvents: voice == .bass ? originalEvents : nil,
                        renderedBassEvents: voice == .bass ? renderedEventCount : nil,
                        companionVoice: voice == .bass ? nil : voice.rawValue,
                        originalCompanionEvents: voice == .bass ? nil : originalEvents,
                        renderedCompanionEvents: voice == .bass ? nil : renderedEventCount,
                        companionMatchesOriginal: companionMatchesOriginal,
                        frameCount: sampleCount / 2, differenceRMS: difference,
                        foundationComplete: foundationComplete, vectorComplete: vector.isComplete,
                        transactionComplete: transaction.isComplete, exactReplay: exactReplay))
                }
            }
        }
        #expect(rows.count == 20)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(Report(
            schema: voice == .bass ? "autotechno-full-phrase-bass-faults.v2" : "autotechno-full-phrase-companion-faults.v1",
            unavailable: unavailable, rows: rows)))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @MainActor
    @Test("Native foundation bass binding rejects score-to-PCM faults")
    func algorithmicFoundationBassFaults() throws {
        struct Row: Encodable {
            let rootSeed: UInt64
            let split: String
            let behavior: String
            let referencePlanFingerprint: String
            let sampleRate: Int
            let scenario: String
            let scoreBar: Int
            let scoreEventCount: Int
            let renderedEventCount: Int
            let scoreStepMask: UInt16
            let renderedStepMask: UInt16
            let expectedStartFrames: [Int]
            let renderedStartFrames: [Int]
            let scoreSteps: [Int]
            let barFrameCount: Int
            let scoreSwingPercent: Double
            let independentTimingOracle: String
            let drySampleHash: String
            let peak: Double
            let rms: Double
            let expectedComplete: Bool
            let observedComplete: Bool
            let renderPassesMatch: Bool
        }
        struct Report: Encodable {
            let schema = "autotechno-foundation-bass-fault-component.v2"
            let scope = "native-established-bass-score-binding-with-independent-onset-equation"
            let behaviors = ["subPulse", "monotone", "point", "pump", "absent"]
            let unavailableBehaviors = ["kickTail:requires-rumble-event-evidence",
                                       "tunedPercussive:requires-modal-event-evidence"]
            let unavailable = ["dotted-authorized-release", "unauthorized-truncation",
                               "full-prepared-transaction", "nonlinear-full-mix-quality",
                               "perceptual-quality", "population-error-intervals"]
            let rows: [Row]
        }
        // Freeze roots, selection and recipes before observing PCM. Each root
        // contributes paired rate/fault measurements, not independent samples.
        // First eligible score bar per behavior within 128 planned phrases;
        // missing coverage fails rather than selecting a replacement root.
        let roots: [(UInt64, String)] = [(1, "development"), (6011, "held-out-root")]
        let behaviors: [FoundationBehavior] = [.subPulse, .monotone, .point, .pump, .absent]
        var rows: [Row] = []
        for (seed, split) in roots {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            var selected: [(FoundationBehavior, AutonomousPhrasePlan, ResolvedPerformanceBar)] = []
            for _ in 0..<128 {
                let plan = director.plan(from: state)
                for source in plan.resolvedBars {
                    let behavior = source.foundationBehavior
                    guard behaviors.contains(behavior),
                          !selected.contains(where: { $0.0 == behavior }),
                          source.foundationRhythmicRelation == .established,
                          source.performance.signatureEvent != .delayedBassEntry,
                          !source.ensemble.events.contains(where: {
                              $0.voice == .rumble || $0.voice == .tunedTom
                          }) else { continue }
                    let bass = source.ensemble.events.filter { $0.voice == .bass }
                    guard behavior == .absent ? bass.isEmpty :
                        !bass.isEmpty && bass.allSatisfy({ (0..<16).contains($0.step) && $0.intensity > 0 })
                    else { continue }
                    selected.append((behavior, plan, source))
                }
                if selected.count == behaviors.count { break }
                state.advancePlanning(using: plan)
            }
            for behavior in behaviors {
                let (_, plan, source) = try #require(selected.first { $0.0 == behavior })
                let originalEvents = source.ensemble.events.filter { $0.voice == .bass }
                let expectedMask = originalEvents.reduce(UInt16(0)) {
                    $0 | (UInt16(1) << UInt16($1.step))
                }
                let assignment = SynthPerformancePlan(scene: plan.scene, dna: plan.dna,
                    kind: plan.kind, resolvedBars: [source]).bars[0].foundationInstrument
                for rate in [44_100.0, 48_000.0] {
                    // Exact positive integer rounding of (24/13)*sampleRate at130 BPM.
                    let frames = (48 * Int(rate) + 13) / 26
                    // Independent score equation: even sixteenths stay on the
                    // grid; odd bass sixteenths add clamp(2*swing-1, 0, 6/25).
                    // Convert the nonnegative position with floor(x+1/2).
                    // Never call the renderer's timing/start helpers or derive
                    // the expected offset from measured starts or audio peaks.
                    let expectedStarts = originalEvents.map { event in
                        let displacement = event.step % 2 == 0 ? 0.0 :
                            min(6.0 / 25.0, max(0.0, 2.0 * plan.dna.rhythm.swingPercent - 1.0))
                        return Int(floor((Double(event.step) + displacement) *
                            Double(frames) / 16.0 + 0.5))
                    }
                    let scenarios = behavior == .absent ? ["declared-absence"] :
                        ["unaltered", "deleted-bass", "shifted-bass", "wrong-voice", "zero-intensity"]
                    var baselineHash: String?
                    for scenario in scenarios {
                        let events = source.ensemble.events.compactMap { event -> EnsembleResolvedEvent? in
                            guard event.voice == .bass else { return event }
                            switch scenario {
                            case "deleted-bass": return nil
                            case "shifted-bass":
                                return EnsembleResolvedEvent(voice: .bass, step: (event.step + 1) % 16,
                                    intensity: event.intensity, relocated: event.relocated)
                            case "wrong-voice":
                                return EnsembleResolvedEvent(voice: .percussion, step: event.step,
                                    intensity: event.intensity, relocated: event.relocated)
                            case "zero-intensity":
                                return EnsembleResolvedEvent(voice: .bass, step: event.step,
                                    intensity: 0, relocated: event.relocated)
                            default: return event
                            }
                        }
                        let altered = replacingRelation(in: source, with: source.foundationRhythmicRelation,
                            ensemble: EnsembleContext(focusRole: source.ensemble.focusRole, events: events,
                                kickAnchors: source.ensemble.kickAnchors,
                                intentionalPileup: source.ensemble.intentionalPileup))
                        let expectedComplete = scenario == "unaltered" || scenario == "declared-absence"
                        if expectedComplete { #expect(altered == source) }
                        let actual = renderProjection(resolved: altered, plan: plan,
                            sampleRate: rate, layer: .full).foundation
                        let protected = renderProjection(resolved: altered, plan: plan,
                            sampleRate: rate, layer: .protectedRhythm).foundation
                        let passMatch = actual == protected
                        if scenario == "unaltered" { baselineHash = actual.dryFoundationSampleHash }
                        else if behavior != .absent { #expect(actual.dryFoundationSampleHash != baselineHash) }
                        let binding = actual.bar == source.performance.bar &&
                            actual.relation == source.foundationRhythmicRelation && actual.sampleRate == rate &&
                            actual.renderedStartFrames == expectedStarts
                        let evidence = AutonomousFoundationRhythmBarEvidence(
                            bar: source.performance.bar, relation: source.foundationRhythmicRelation,
                            pairPhase: FoundationRhythmicRelationContract.pairPhase(absoluteBar: source.performance.bar),
                            scoreBassEventCount: originalEvents.count, scoreBassStepMask: expectedMask,
                            renderedBassEventCount: actual.renderedBassEventCount,
                            renderedBassStepMask: actual.renderedBassStepMask, renderedFrameCount: actual.renderedFrameCount,
                            renderedStartFrameFingerprint: AutonomousFoundationRhythmBarEvidence.startFrameFingerprint(actual.renderedStartFrames),
                            dryFoundationSampleHash: actual.dryFoundationSampleHash, peak: actual.peak, rms: actual.rms,
                            bassPluckAssigned: assignment.patch == .bassPluck,
                            preKickPocket: AutonomousFoundationPreKickPocketEvidence(render: actual.preKickPocket),
                            renderPassesMatch: passMatch, bindingValid: binding, finite: actual.finite)
                        let complete = evidence.isComplete(sampleRate: rate)
                        #expect(passMatch && actual.finite)
                        #expect(complete == expectedComplete)
                        if ["deleted-bass", "wrong-voice", "zero-intensity", "declared-absence"].contains(scenario) {
                            #expect(actual.peak == 0 && actual.rms == 0)
                        }
                        if scenario == "shifted-bass" {
                            #expect(actual.renderedBassEventCount == originalEvents.count)
                            #expect(actual.renderedStartFrames != expectedStarts)
                        }
                        if expectedComplete {
                            if behavior != .absent { #expect(actual.peak > 0 && actual.rms > 0) }
                            #expect(actual == renderProjection(resolved: altered, plan: plan,
                                sampleRate: rate, layer: .full).foundation)
                        }
                        rows.append(Row(rootSeed: seed, split: split, behavior: behavior.rawValue,
                            referencePlanFingerprint: AutonomousCandidateFingerprint.plan(plan), sampleRate: Int(rate),
                            scenario: scenario, scoreBar: source.performance.bar, scoreEventCount: originalEvents.count,
                            renderedEventCount: actual.renderedBassEventCount, scoreStepMask: expectedMask,
                            renderedStepMask: actual.renderedBassStepMask, expectedStartFrames: expectedStarts,
                            renderedStartFrames: actual.renderedStartFrames,
                            scoreSteps: originalEvents.map(\.step), barFrameCount: frames,
                            scoreSwingPercent: plan.dna.rhythm.swingPercent,
                            independentTimingOracle: "floor((step + (odd ? clamp(2*swing-1,0,6/25) : 0))*frames/16+1/2)",
                            drySampleHash: actual.dryFoundationSampleHash,
                            peak: actual.peak, rms: actual.rms, expectedComplete: expectedComplete,
                            observedComplete: complete, renderPassesMatch: passMatch))
                    }
                }
            }
        }
        #expect(rows.count == 84)
        #expect(rows.filter { $0.expectedComplete }.count == 20)
        #expect(rows.filter { !$0.expectedComplete }.count == 64)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(Report(rows: rows)))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @MainActor
    @Test("Native rumble and modal companions preserve original score binding")
    func algorithmicFoundationCompanionFaults() throws {
        struct Row: Encodable {
            let rootSeed: UInt64
            let split: String
            let behavior: String
            let referencePlanFingerprint: String
            let sampleRate: Int
            let scenario: String
            let scoreBar: Int
            let scoreEventIndexes: [Int]
            let renderedEventIndexes: [Int]
            let scoreSteps: [Int]
            let renderedSteps: [Int]
            let expectedStartFrames: [Int]
            let renderedStartFrames: [Int]?
            let firstNonzeroFrame: Int?
            let expectedFirstOnsetShift: Int?
            let observedFirstOnsetShift: Int?
            let drySampleHash: String
            let peak: Double
            let rms: Double
            let expectedBinding: Bool
            let observedBinding: Bool
            let renderPassesMatch: Bool
        }
        struct Report: Encodable {
            let schema = "autotechno-foundation-companion-fault-component.v1"
            let scope = "native-rumble-and-modal-source-score-binding"
            let behaviors = ["kickTail", "tunedPercussive"]
            let unavailable = ["absolute-per-event-rumble-sample-starts",
                "continuing-modal-tail-support", "unauthorized-truncation",
                "dotted-authorized-release", "full-prepared-transaction",
                "nonlinear-full-mix-quality", "perceptual-quality", "population-error-intervals"]
            let rows: [Row]
        }
        // Frozen before rendering: paired rates/recipes are not independent
        // samples. The first score match is used; missing coverage fails.
        let roots: [(UInt64, String)] = [(1, "development"), (6011, "held-out-root")]
        let behaviors: [FoundationBehavior] = [.kickTail, .tunedPercussive]
        var rows: [Row] = []
        for (seed, split) in roots {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            var selected: [(FoundationBehavior, AutonomousPhrasePlan, ResolvedPerformanceBar)] = []
            for _ in 0..<128 {
                let plan = director.plan(from: state)
                for source in plan.resolvedBars {
                    let behavior = source.foundationBehavior
                    guard behaviors.contains(behavior),
                          !selected.contains(where: { $0.0 == behavior }) else { continue }
                    let voice: EnsembleVoice = behavior == .kickTail ? .rumble : .tunedTom
                    let declared = source.ensemble.events.enumerated().filter { $0.element.voice == voice }
                    guard !declared.isEmpty,
                          declared.allSatisfy({ (0..<15).contains($0.element.step) && $0.element.intensity > 0 }),
                          !source.ensemble.events.contains(where: {
                              [.bass, .rumble, .tunedTom].contains($0.voice) && $0.voice != voice
                          }) else { continue }
                    if behavior == .tunedPercussive {
                        guard source.modalPercussionArticulations.count == declared.count,
                              declared.allSatisfy({ indexed in
                                  source.modalPercussionArticulations.contains {
                                      $0.scoreEventIndex == indexed.offset && $0.step == indexed.element.step &&
                                          $0.eventIntensity == indexed.element.intensity && $0.use == .foundationCompanion
                                  }
                              }) else { continue }
                    }
                    selected.append((behavior, plan, source))
                }
                if selected.count == behaviors.count { break }
                state.advancePlanning(using: plan)
            }
            for behavior in behaviors {
                let (_, plan, source) = try #require(selected.first { $0.0 == behavior })
                let voice: EnsembleVoice = behavior == .kickTail ? .rumble : .tunedTom
                let declared = source.ensemble.events.enumerated().filter { $0.element.voice == voice }
                let indexes = declared.map(\.offset)
                let steps = declared.map { $0.element.step }
                for rate in [44_100.0, 48_000.0] {
                    let frames = Int((240.0 / 130.0 * rate).rounded())
                    // Rumble and tunedTom are unswung. Use independent score
                    // arithmetic, never an onset found in observed PCM.
                    let starts = steps.map { Int((Double($0) * Double(frames) / 16).rounded()) }
                    let firstStep = try #require(steps.min())
                    let expectedShift = Int((Double(firstStep + 1) * Double(frames) / 16).rounded()) -
                        Int((Double(firstStep) * Double(frames) / 16).rounded())
                    var baseline: CompanionProjection?
                    for scenario in ["unaltered", "deleted-companion", "shifted-companion", "wrong-voice", "zero-intensity"] {
                        let events = source.ensemble.events.compactMap { event -> EnsembleResolvedEvent? in
                            guard event.voice == voice else { return event }
                            if scenario == "deleted-companion" { return nil }
                            return EnsembleResolvedEvent(
                                voice: scenario == "wrong-voice" ? .percussion : event.voice,
                                step: scenario == "shifted-companion" ? event.step + 1 : event.step,
                                intensity: scenario == "zero-intensity" ? 0 : event.intensity,
                                relocated: event.relocated)
                        }
                        // Modal intent owns its intensity independently of the
                        // ensemble record. Mutate both coherently for this fault.
                        let articulations = source.modalPercussionArticulations.map { articulation in
                            ModalPercussionArticulation(scoreEventIndex: articulation.scoreEventIndex,
                                step: scenario == "shifted-companion" ? articulation.step + 1 : articulation.step,
                                use: articulation.use, modalIdentity: articulation.modalIdentity,
                                modalDegree: articulation.modalDegree, octave: articulation.octave,
                                fundamentalHz: articulation.fundamentalHz, excitation: articulation.excitation,
                                damping: articulation.damping, brightness: articulation.brightness,
                                inharmonicity: articulation.inharmonicity,
                                eventIntensity: scenario == "zero-intensity" ? 0 : articulation.eventIntensity,
                                seed: articulation.seed, material: articulation.material, coupling: articulation.coupling)
                        }
                        let altered = replacingRelation(in: source, with: source.foundationRhythmicRelation,
                            ensemble: EnsembleContext(focusRole: source.ensemble.focusRole, events: events,
                                kickAnchors: source.ensemble.kickAnchors,
                                intentionalPileup: source.ensemble.intentionalPileup),
                            modalArticulations: articulations)
                        let expectedBinding = scenario == "unaltered"
                        if expectedBinding { #expect(altered == source) }
                        let actual = try renderCompanionProjection(resolved: altered, plan: plan, sampleRate: rate, layer: .full)
                        let protected = try renderCompanionProjection(resolved: altered, plan: plan, sampleRate: rate, layer: .protectedRhythm)
                        let passMatch = actual == protected
                        #expect(passMatch && actual.finite && actual.frameCount == frames)
                        let renderedIndexes: [Int]
                        let renderedSteps: [Int]
                        let renderedStarts: [Int]?
                        let sourceBinding: Bool
                        if behavior == .kickTail {
                            renderedIndexes = actual.rumble.map(\.scoreEventIndex)
                            renderedSteps = actual.rumble.map(\.step)
                            renderedStarts = nil // Terminal evidence has no absolute sample-start field.
                            sourceBinding = renderedIndexes == indexes && renderedSteps == steps &&
                                actual.rumble.allSatisfy { $0.isComplete(sampleRate: rate) }
                        } else {
                            renderedIndexes = actual.modal.events.map { $0.articulation.scoreEventIndex }
                            renderedSteps = actual.modal.events.map { $0.articulation.step }
                            renderedStarts = actual.modal.events.map { $0.windowSupport.startFrame }
                            sourceBinding = actual.modal.bar == source.performance.bar && actual.modal.sampleRate == rate &&
                                actual.modal.renderedFrameCount == frames && actual.modal.finite && actual.modalRoutingValid &&
                                renderedIndexes == indexes && renderedSteps == steps && renderedStarts == starts &&
                                actual.modal.dryBarSampleHash == actual.sampleHash &&
                                actual.modal.events.allSatisfy { event in
                                    source.modalPercussionArticulations.contains(event.articulation) &&
                                        event.appliedFundamentalHz == event.articulation.fundamentalHz &&
                                        event.requestedFundamentalHz == event.articulation.fundamentalHz &&
                                        event.nonzeroSampleCount > 0 && event.peak > 0 && event.rms > 0 &&
                                        event.finite && event.stable && event.capacityValid && event.routeBindingValid &&
                                        event.windowSupport.isValid(sampleRate: rate, frameCount: frames)
                                }
                        }
                        let binding = passMatch && sourceBinding && actual.peak > 0 && actual.rms > 0 && actual.finite
                        #expect(binding == expectedBinding)
                        var onsetShift: Int?
                        if expectedBinding {
                            #expect(actual.firstNonzeroFrame != nil)
                            let replay = try renderCompanionProjection(
                                resolved: altered, plan: plan, sampleRate: rate, layer: .full
                            )
                            #expect(actual == replay)
                            baseline = actual
                        } else {
                            let original = try #require(baseline)
                            #expect(actual.sampleHash != original.sampleHash)
                            if scenario == "shifted-companion" {
                                let changedStart = try #require(actual.firstNonzeroFrame)
                                let originalStart = try #require(original.firstNonzeroFrame)
                                onsetShift = changedStart - originalStart
                                #expect(onsetShift == expectedShift)
                                #expect(renderedIndexes == indexes && renderedSteps == steps.map { $0 + 1 })
                            } else {
                                #expect(actual.firstNonzeroFrame == nil && actual.peak == 0 && actual.rms == 0)
                            }
                        }
                        rows.append(Row(rootSeed: seed, split: split, behavior: behavior.rawValue,
                            referencePlanFingerprint: AutonomousCandidateFingerprint.plan(plan), sampleRate: Int(rate),
                            scenario: scenario, scoreBar: source.performance.bar, scoreEventIndexes: indexes,
                            renderedEventIndexes: renderedIndexes, scoreSteps: steps, renderedSteps: renderedSteps,
                            expectedStartFrames: starts, renderedStartFrames: renderedStarts,
                            firstNonzeroFrame: actual.firstNonzeroFrame,
                            expectedFirstOnsetShift: scenario == "shifted-companion" ? expectedShift : nil,
                            observedFirstOnsetShift: onsetShift, drySampleHash: actual.sampleHash,
                            peak: actual.peak, rms: actual.rms, expectedBinding: expectedBinding,
                            observedBinding: binding, renderPassesMatch: passMatch))
                    }
                }
            }
        }
        #expect(rows.count == 40)
        #expect(rows.filter { $0.observedBinding }.count == 8)
        #expect(rows.filter { !$0.observedBinding }.count == 32)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(Report(rows: rows)))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @MainActor
    @Test("Native source release distinguishes score authority from truncation")
    func algorithmicFoundationReleaseFaults() throws {
        struct Row: Encodable {
            let rootSeed: UInt64
            let split: String
            let referencePlanFingerprint: String
            let scoreBar: Int
            let phase: Int
            let sampleRate: Int
            let scenario: String
            let eventStartFrame: Int
            let authorizedReleaseStartFrame: Int
            let authorizedReleaseEndFrame: Int
            let kickFrame: Int
            let suppliedReleaseStartFrame: Int?
            let suppliedReleaseEndFrame: Int?
            let naturalFrameCount: Int
            let appliedFrameCount: Int
            let prefixMatchesUngated: Bool
            let declaredSilenceIsZero: Bool
            let expectedBinding: Bool
            let observedBinding: Bool
            let drySampleHash: String
            let replayExact: Bool
        }
        struct RootCoverage: Encodable {
            let rootSeed: UInt64
            let phases: [Int]
            let scoreBars: [Int]
            let planFingerprints: [String]
        }
        struct Selection: Encodable {
            let split: String
            let firstRoot: UInt64
            let lastRoot: UInt64
            let examined: [RootCoverage]
        }
        struct SelectedRoot {
            let seed: UInt64
            let split: String
            let bars: [(Int, AutonomousPhrasePlan, ResolvedPerformanceBar)]
        }
        struct Report: Encodable {
            let schema = "autotechno-foundation-release-fault-component.v2"
            let selection: [Selection]
            let scope = "score-derived-release-support-in-canonical-single-source-render"
            let unavailable = ["full-prepared-transaction", "shared-nonlinear-full-mix-quality",
                "continuing-source-state", "other-foundation-behavior-truncation",
                "independent-bass-timing-offset-equations", "perceptual-quality", "population-error-intervals"]
            let rows: [Row]
        }
        #expect(FoundationPreKickPocketContract.releaseLeadInSteps == 3.0 / 16)
        #expect(FoundationPreKickPocketContract.silenceLeadInSteps == 1.0 / 16)
        // v1 failed before PCM because its fixed roots lacked score coverage.
        // v2 freezes disjoint domains and a score-only first-eligible rule.
        // Finish both selections before observing any source PCM; never choose
        // or replace a root based on a rendered result.
        var selection: [Selection] = []
        var selectedRoots: [SelectedRoot] = []
        for (first, last, split) in [(UInt64(1), UInt64(48), "development"),
                                     (UInt64(6001), UInt64(6048), "held-out-root")] {
            var examined: [RootCoverage] = []
            for seed in first...last {
                let director = AutonomousSessionDirector(rootSeed: seed)
                var state = director.initialState()
                var selected: [(Int, AutonomousPhrasePlan, ResolvedPerformanceBar)] = []
                for _ in 0..<128 {
                    let plan = director.plan(from: state)
                    for source in plan.resolvedBars {
                        let phase = source.performance.bar % 2
                        guard !selected.contains(where: { $0.0 == phase }),
                              source.foundationRhythmicRelation == .dottedThreeSixteenth,
                              FoundationPreKickPocketResolver.articulation(in: source) != nil else { continue }
                        selected.append((phase, plan, source))
                    }
                    if selected.count == 2 { break }
                    state.advancePlanning(using: plan)
                }
                let ordered = selected.sorted { $0.0 < $1.0 }
                examined.append(RootCoverage(rootSeed: seed, phases: ordered.map { $0.0 },
                    scoreBars: ordered.map { $0.2.performance.bar },
                    planFingerprints: ordered.map { AutonomousCandidateFingerprint.plan($0.1) }))
                if selected.count == 2 {
                    selectedRoots.append(SelectedRoot(seed: seed, split: split, bars: selected))
                    break
                }
            }
            selection.append(Selection(split: split, firstRoot: first, lastRoot: last, examined: examined))
        }
        // Preserve missing coverage as a pre-PCM diagnostic, never a pass.
        let selectionEncoder = JSONEncoder(); selectionEncoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try selectionEncoder.encode(selection))
        FileHandle.standardOutput.write(Data([0x0A]))
        try #require(selectedRoots.count == 2)
        var rows: [Row] = []
        for selectedRoot in selectedRoots {
            let seed = selectedRoot.seed
            let split = selectedRoot.split
            let selected = selectedRoot.bars
            for phase in [0, 1] {
                let (_, plan, source) = try #require(selected.first { $0.0 == phase })
                let articulation = try #require(FoundationPreKickPocketResolver.articulation(in: source))
                let event = source.ensemble.events[articulation.scoreEventIndex]
                let synth = SynthPerformancePlan(scene: plan.scene, dna: plan.dna,
                    kind: plan.kind, resolvedBars: [source])
                let kickStep = phase == 0 ? 4 : 12
                #expect(articulation.bassStep == kickStep - 1 && articulation.kickStep == kickStep)
                #expect(event.voice == .bass && event.step == kickStep - 1)
                #expect(VoiceRenderer.timingOffsetInSteps(for: .kick, step: kickStep, dna: plan.dna) == 0)
                for rate in [44_100.0, 48_000.0] {
                    let frames = Int((240.0 / 130.0 * rate).rounded())
                    let stepFrames = Double(frames) / 16
                    let eventStart = Int(((Double(event.step) + VoiceRenderer.timingOffsetInSteps(
                        for: .bass, step: event.step, dna: plan.dna)) * stepFrames).rounded())
                    let releaseStart = Int(((Double(kickStep) - 3.0 / 16) * stepFrames).rounded())
                    let releaseEnd = Int(((Double(kickStep) - 1.0 / 16) * stepFrames).rounded())
                    let kickFrame = Int((Double(kickStep) * stepFrames).rounded())
                    let earlyStart = Int(((Double(kickStep) - 3.0 / 16 - 0.25) * stepFrames).rounded())
                    let earlyEnd = Int(((Double(kickStep) - 1.0 / 16 - 0.25) * stepFrames).rounded())
                    #expect(eventStart < earlyStart && earlyStart < earlyEnd && earlyEnd < releaseStart)
                    #expect(releaseStart < releaseEnd && releaseEnd < kickFrame && kickFrame < frames)
                    let frequency = FoundationPitchResolver.frequency(dna: plan.dna, step: event.step)
                    func render(_ start: Int?, _ end: Int?) -> (pcm: [Float], result: ResonantMonoFoundationRenderResult) {
                        var pcm = [Float](repeating: 0, count: frames)
                        var measurement = pcm; var architecture = pcm
                        var echo = pcm; var reverb = pcm
                        var sourceState = ResonantMonoState()
                        var nonlinear = TPTAntialiasedNonlinearCoreEvidenceAccumulator()
                        let result = ResonantMonoVoice.renderFoundation(&pcm, measurement: &measurement,
                            architectureMeasurement: &architecture, pulseEchoSend: &echo,
                            spatialReverbSend: &reverb, start: eventStart, sampleRate: rate, level: 0.12,
                            frequency: frequency, assignment: synth.bars[0].foundationInstrument,
                            velocity: event.intensity, terminalReleaseStartFrame: start,
                            terminalReleaseEndFrame: end, state: &sourceState, nonlinearCoreEvidence: &nonlinear)
                        #expect(pcm.map(\.bitPattern) == measurement.map(\.bitPattern))
                        #expect(pcm.map(\.bitPattern) == architecture.map(\.bitPattern))
                        let finite = pcm.allSatisfy { $0.isFinite }
                        #expect(finite)
                        return (pcm, result)
                    }
                    let ungated = render(nil, nil)
                    #expect(!ungated.result.terminalReleaseApplied)
                    #expect(eventStart + ungated.result.naturalFrameCount > kickFrame)
                    #expect(ungated.pcm[earlyEnd..<releaseStart].contains { $0 != 0 })
                    #expect(ungated.pcm[releaseEnd..<kickFrame].contains { $0 != 0 })
                    for scenario in ["authorized-release", "early-release", "omitted-release"] {
                        let start: Int? = scenario == "omitted-release" ? nil :
                            (scenario == "early-release" ? earlyStart : releaseStart)
                        let end: Int? = scenario == "omitted-release" ? nil :
                            (scenario == "early-release" ? earlyEnd : releaseEnd)
                        let actual = render(start, end)
                        let replay = render(start, end)
                        let replayExact = actual.pcm.map(\.bitPattern) == replay.pcm.map(\.bitPattern) &&
                            actual.result == replay.result
                        #expect(replayExact)
                        let prefixMatches = actual.pcm[..<releaseStart].map(\.bitPattern) ==
                            ungated.pcm[..<releaseStart].map(\.bitPattern)
                        let silenceIsZero = actual.pcm[releaseEnd...].allSatisfy { $0 == 0 }
                        let expected = scenario == "authorized-release"
                        let binding = prefixMatches && silenceIsZero && actual.result.terminalReleaseApplied &&
                            eventStart + actual.result.appliedFrameCount == releaseEnd
                        #expect(binding == expected)
                        #expect(actual.result.naturalFrameCount == ungated.result.naturalFrameCount)
                        if scenario == "early-release" {
                            #expect(!prefixMatches && silenceIsZero)
                            #expect(eventStart + actual.result.appliedFrameCount == earlyEnd)
                            #expect(actual.pcm[earlyEnd...].allSatisfy { $0 == 0 })
                        } else if scenario == "omitted-release" {
                            #expect(prefixMatches && !silenceIsZero)
                            #expect(actual.pcm.map(\.bitPattern) == ungated.pcm.map(\.bitPattern))
                        } else {
                            #expect(prefixMatches && silenceIsZero)
                            #expect(actual.pcm[releaseStart..<releaseEnd].contains { $0 != 0 })
                            #expect(actual.pcm != ungated.pcm)
                        }
                        rows.append(Row(rootSeed: seed, split: split,
                            referencePlanFingerprint: AutonomousCandidateFingerprint.plan(plan),
                            scoreBar: source.performance.bar, phase: phase, sampleRate: Int(rate), scenario: scenario,
                            eventStartFrame: eventStart, authorizedReleaseStartFrame: releaseStart,
                            authorizedReleaseEndFrame: releaseEnd, kickFrame: kickFrame,
                            suppliedReleaseStartFrame: start, suppliedReleaseEndFrame: end,
                            naturalFrameCount: actual.result.naturalFrameCount,
                            appliedFrameCount: actual.result.appliedFrameCount,
                            prefixMatchesUngated: prefixMatches, declaredSilenceIsZero: silenceIsZero,
                            expectedBinding: expected, observedBinding: binding,
                            drySampleHash: ExactPCMFingerprint.mono(actual.pcm), replayExact: replayExact))
                    }
                }
            }
        }
        #expect(rows.count == 24)
        #expect(rows.filter { $0.observedBinding }.count == 8)
        #expect(rows.filter { !$0.observedBinding }.count == 16)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(Report(selection: selection, rows: rows)))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    private struct CompanionProjection: Equatable {
        // Test-local exact PCM comparison; never encoded in the report.
        let sampleBits: [UInt32]
        let frameCount: Int
        let sampleHash: String
        let firstNonzeroFrame: Int?
        let peak: Double
        let rms: Double
        let finite: Bool
        let rumble: [SourceTerminalDeclickRenderEvidence]
        let modal: ModalPercussionBarRenderEvidence
        let modalRoutingValid: Bool
    }

    @inline(never)
    private func renderCompanionProjection(resolved: ResolvedPerformanceBar,
        plan: AutonomousPhrasePlan, sampleRate: Double, layer: RenderLayer) throws -> CompanionProjection {
        let synth = SynthPerformancePlan(scene: plan.scene, dna: plan.dna,
            kind: plan.kind, resolvedBars: [resolved])
        var state = RenderState(); state.barIndex = resolved.performance.bar
        var workspace = RenderWorkspace()
        let rendered = VoiceRenderer.renderBar(scene: plan.scene, sampleRate: sampleRate,
            state: &state, dna: plan.dna, resolved: resolved, synthWorld: synth.world,
            synthPerformance: synth.bars[0], workspace: &workspace, layer: layer,
            phraseKind: plan.kind, diagnosticRoleStemCapture: true)
        let capture = try #require(rendered.diagnosticRoleStemCapture)
        let samples = resolved.foundationBehavior == .kickTail ? capture.foundation : capture.modalFoundation
        let energy = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        return CompanionProjection(sampleBits: samples.map(\.bitPattern),
            frameCount: samples.count, sampleHash: ExactPCMFingerprint.mono(samples),
            firstNonzeroFrame: samples.firstIndex(where: { $0 != 0 }),
            peak: samples.reduce(0.0) { max($0, abs(Double($1))) },
            rms: sqrt(energy / Double(max(1, samples.count))), finite: samples.allSatisfy(\.isFinite),
            rumble: rendered.sourceTerminalDeclickRenderEvidence.filter { $0.voice == .rumble },
            modal: rendered.modalPercussionRenderEvidence,
            modalRoutingValid: rendered.modalPercussionFoundationRoutingValid)
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
        layer: RenderLayer,
        forceHomeUpperTimbre: Bool = false
    ) -> RenderProjection {
        let synth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [resolved],
            forceHomeUpperTimbre: forceHomeUpperTimbre
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
        let established = AutonomousSessionDirector.ensemblePlan(
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
        let firstBassIndex = active.ensemble.events.firstIndex {
            $0.voice == .bass
        } ?? active.ensemble.events.count
        var events = active.ensemble.events.filter { $0.voice != .bass }
        events.insert(
            contentsOf: established.events.filter { $0.voice == .bass },
            at: min(firstBassIndex, events.count)
        )
        let ensemble = EnsembleContext(
            focusRole: active.ensemble.focusRole,
            events: events,
            kickAnchors: active.ensemble.kickAnchors,
            intentionalPileup: active.ensemble.intentionalPileup
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
        ensemble: EnsembleContext? = nil,
        modalArticulations: [ModalPercussionArticulation]? = nil
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
                modalArticulations ?? resolved.modalPercussionArticulations,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative,
            kickSyntaxRole: resolved.kickSyntaxRole,
            climaxHang: resolved.climaxHang,
            percussionEchoTexture: resolved.percussionEchoTexture,
            percussionPolymetricEvidence:
                resolved.percussionPolymetricEvidence,
            upperMusicalPump: resolved.upperMusicalPump,
            harmonicDisclosureRelationship:
                resolved.harmonicDisclosureRelationship,
            kickMorphology: resolved.kickMorphology
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
