@testable import AutoTechnoDSP
import AutoTechnoCore
import Foundation
import Testing

@Suite("Canonical instrument palette")
struct InstrumentPaletteTests {
    @Test("The catalog is complete, compatible, bounded, and deterministic")
    func catalogContract() {
        #expect(InstrumentPalette.isInternallyValid)
        #expect(InstrumentPalette.capabilities.filter {
            $0.compatibleEffects.contains(.comb)
        }.allSatisfy { $0.patch.architecture == .tonalMotion })
        #expect(InstrumentPalette.capabilities.map(\.patch) == InstrumentPatch.allCases)
        #expect(Set(InstrumentPalette.capabilities.map { $0.patch.architecture }) ==
                Set(InstrumentArchitecture.allCases))

        for capability in InstrumentPalette.capabilities {
            #expect(capability.eligibleUses == InstrumentUse.allCases.filter {
                capability.eligibleUses.contains($0)
            })
            #expect(capability.compatibleEffects == InstrumentEffect.allCases.filter {
                capability.compatibleEffects.contains($0)
            })
            for use in capability.eligibleUses {
                let assignment = InstrumentAssignment(
                    use: use,
                    patch: capability.patch,
                    automation: InstrumentAutomation(
                        color: -1, shape: 2, motion: 0.52,
                        space: use == .foundationBass ? 0 : 0.48
                    ),
                    effects: capability.compatibleEffects
                )
                #expect(assignment.isValid)
                #expect(assignment.automation.color == 0)
                #expect(assignment.automation.shape == 1)
                #expect(assignment.effects == capability.compatibleEffects)
            }
        }

        var selectedPatches = Set<InstrumentPatch>()
        var selectedArchitectures = Set<InstrumentArchitecture>()
        for seed in UInt64(0)..<32 {
            let world = fixtureWorld(seed: seed)
            for kind in AutonomousPhraseKind.allCases {
                for gesture in SynthGesture.allCases {
                    let foundation = InstrumentPalette.resolveFoundation(
                        world: world,
                        kind: kind,
                        gesture: gesture,
                        mutationAmount: 0.73,
                        conservative: false
                    )
                    #expect(foundation == InstrumentPalette.resolveFoundation(
                        world: world,
                        kind: kind,
                        gesture: gesture,
                        mutationAmount: 0.73,
                        conservative: false
                    ))
                    #expect(foundation.isValid)
                    #expect(foundation.automation.space == 0)
                    selectedPatches.insert(foundation.patch)
                    selectedArchitectures.insert(foundation.architecture)
                    for role in SynthRole.allCases {
                        for chapter in InterlockChapter.allCases {
                            let assignment = InstrumentPalette.resolveUpper(
                                role: role,
                                world: world,
                                kind: kind,
                                gesture: gesture,
                                chapter: chapter,
                                mutationAmount: 0.73,
                                conservative: false,
                                pulseEchoEnabled: true
                            )
                            #expect(assignment.isValid)
                            #expect(assignment == InstrumentPalette.resolveUpper(
                                role: role,
                                world: world,
                                kind: kind,
                                gesture: gesture,
                                chapter: chapter,
                                mutationAmount: 0.73,
                                conservative: false,
                                pulseEchoEnabled: true
                            ))
                            selectedPatches.insert(assignment.patch)
                            selectedArchitectures.insert(assignment.architecture)
                        }
                    }
                }
            }
        }
        #expect(selectedPatches == Set(InstrumentPatch.allCases))
        #expect(selectedArchitectures == Set(InstrumentArchitecture.allCases))
    }

    @Test("Fallback stays inside the same catalog and tonal home identity")
    func fallbackContract() {
        let world = fixtureWorld(seed: 48_291)
        #expect(InstrumentPalette.resolveFoundation(
            world: world,
            kind: .contrast,
            gesture: .corrode,
            mutationAmount: 1,
            conservative: true
        ) == InstrumentPalette.safeFoundation())
        for role in SynthRole.allCases {
            let fallback = InstrumentPalette.resolveUpper(
                role: role,
                world: world,
                kind: .contrast,
                gesture: .corrode,
                chapter: .motion,
                mutationAmount: 1,
                conservative: true,
                pulseEchoEnabled: true
            )
            #expect(fallback == InstrumentPalette.safeUpper(role: role))
            #expect(fallback.architecture == .tonalMotion)
            #expect(fallback.isValid)
        }
    }

    @Test("Foundation behaviors resolve to distinct bounded instrument consequences")
    func foundationBehaviorPCM() {
        let world = fixtureWorld(seed: 48_291)
        let audible: [FoundationBehavior] = [.subPulse, .monotone, .point, .pump]
        let assignments = audible.map { behavior in
            InstrumentPalette.resolveFoundation(
                world: world,
                kind: .energyRelease,
                gesture: .release,
                mutationAmount: 0.72,
                foundationBehavior: behavior,
                conservative: false
            )
        }
        for index in assignments.indices {
            for comparison in assignments.indices where comparison > index {
                #expect(assignments[index].automation != assignments[comparison].automation)
            }
        }
        #expect(assignments.allSatisfy {
            $0.isValid && $0.use == .foundationBass && $0.automation.space == 0
        })

        let renders = assignments.map { render(assignment: $0, role: .anchor).samples }
        for index in renders.indices {
            #expect(renders[index].contains { $0 != 0 && $0.isFinite })
            for comparison in renders.indices where comparison > index {
                #expect(renders[index] != renders[comparison])
            }
        }
    }

    @Test("Each architecture turns semantic automation into deterministic audible PCM")
    func architectureAutomationPCM() {
        let fixtures: [(InstrumentPatch, InstrumentUse, SynthRole)] = [
            (.acidSequence, .motif, .anchor),
            (.northStar, .motif, .anchor),
            (.alienNoise, .atmosphere, .atmosphere),
        ]
        for (patch, use, role) in fixtures {
            let low = assignment(
                patch: patch, use: use,
                automation: InstrumentAutomation(
                    color: 0.18, shape: 0.30, motion: 0.20, space: 0.14
                )
            )
            let high = assignment(
                patch: patch, use: use,
                automation: InstrumentAutomation(
                    color: 0.82, shape: 0.74, motion: 0.88, space: 0.64
                )
            )
            let lowRender = render(assignment: low, role: role)
            let replay = render(assignment: low, role: role)
            let highRender = render(assignment: high, role: role)

            #expect(lowRender.samples == replay.samples)
            #expect(lowRender.evidence == replay.evidence)
            #expect(lowRender.samples != highRender.samples)
            #expect(lowRender.samples.contains { $0 != 0 })
            #expect(highRender.samples.contains { $0 != 0 })
            #expect(lowRender.samples.allSatisfy { $0.isFinite })
            #expect(highRender.samples.allSatisfy { $0.isFinite })
            #expect((lowRender.samples.map { abs($0) }.max() ?? 0) < 1)
            #expect((highRender.samples.map { abs($0) }.max() ?? 0) < 1)
            #expect(lowRender.evidence.count == 1)
            #expect(lowRender.evidence[0].instrument == low)
            #expect(highRender.evidence[0].instrument == high)
        }
    }

    @Test("Acid patches apply bounded ordered and metallic operator relations")
    func resonantMonoAcidRelations() {
        let automation = InstrumentAutomation(
            color: 0.64, shape: 0.56, motion: 0.74, space: 0.16
        )
        let ordered = assignment(
            patch: .acidThread,
            use: .shadow,
            automation: automation
        )
        let metallic = assignment(
            patch: .acidSequence,
            use: .motif,
            automation: automation
        )
        #expect(ordered.resonantMonoSpectralRelation == .orderedHollow)
        #expect(metallic.resonantMonoSpectralRelation == .metallicTension)

        for sampleRate in [8_000.0, 44_100.0, 48_000.0, 192_000.0] {
            let orderedRender = render(
                assignment: ordered,
                role: .shadow,
                sampleRate: sampleRate
            )
            let metallicRender = render(
                assignment: metallic,
                role: .anchor,
                sampleRate: sampleRate
            )
            let orderedEvidence = orderedRender.evidence.first?
                .resonantMonoModulation
            let metallicEvidence = metallicRender.evidence.first?
                .resonantMonoModulation
            #expect(orderedEvidence?.relation == .orderedHollow)
            #expect(orderedEvidence?.modulatorRatio == 2.0)
            #expect(metallicEvidence?.relation == .metallicTension)
            #expect(metallicEvidence?.modulatorRatio ==
                    1.414_213_562_373_095_1)
            #expect((orderedEvidence?.appliedPeakIndex ?? 0) > 0)
            #expect((metallicEvidence?.appliedPeakIndex ?? 0) > 0)
            #expect((orderedEvidence?.appliedPeakIndex ?? .infinity) <=
                    (orderedEvidence?.requestedPeakIndex ?? 0))
            #expect((metallicEvidence?.appliedPeakIndex ?? .infinity) <=
                    (metallicEvidence?.requestedPeakIndex ?? 0))
            #expect(orderedRender.modulation.first?.bitPattern == 0)
            #expect(orderedRender.modulation.last?.bitPattern == 0)
            #expect(metallicRender.modulation.first?.bitPattern == 0)
            #expect(metallicRender.modulation.last?.bitPattern == 0)
            #expect(orderedRender.modulation.contains { $0 != 0 })
            #expect(metallicRender.modulation.contains { $0 != 0 })
            #expect(orderedRender.samples != metallicRender.samples)
            #expect(orderedRender.samples.allSatisfy { $0.isFinite })
            #expect(metallicRender.samples.allSatisfy { $0.isFinite })
        }

        for patch in [InstrumentPatch.bassPulse, .bassPluck] {
            let foundation = assignment(
                patch: patch,
                use: .foundationBass,
                automation: .neutral
            )
            #expect(foundation.resonantMonoSpectralRelation == nil)
            let rendered = render(assignment: foundation, role: .anchor)
            #expect(rendered.evidence.count == 1)
            #expect(rendered.evidence[0].resonantMonoModulation == nil)
            #expect(rendered.modulation.allSatisfy { $0.bitPattern == 0 })
            #expect(rendered.samples.contains { $0 != 0 })
        }
    }

    @Test("A tonal tail retains its resolved patch automation across a silent bar")
    func tonalTailContinuation() {
        let active = assignment(
            patch: .darkChord,
            use: .atmosphere,
            automation: InstrumentAutomation(
                color: 0.24, shape: 0.94, motion: 0.36, space: 0.72
            )
        )
        let sampleRate = 16_000.0
        var state = AlienVoiceState()
        var first = [Float](repeating: 0, count: 3_200)
        var firstMeasurement = [Float](repeating: 0, count: first.count)
        var firstArchitecture = [Float](repeating: 0, count: first.count)
        var firstPulse = [Float](repeating: 0, count: first.count)
        var firstReverb = [Float](repeating: 0, count: first.count)
        var firstEvidence: [UpperNoteRenderEvidence] = []
        let note = AlienVoiceNote(
            startFrame: 0,
            durationFrames: 800,
            frequency: 130.81,
            endFrequency: 130.81,
            velocity: 0.76,
            gate: .retrigger,
            timbreIntent: .home,
            instrument: active,
            role: .atmosphere,
            articulation: .neutral,
            dryScale: 1,
            spatialReverbSend: 0,
            narrativeGainScale: 1,
            narrativeSpectralScale: 1
        )
        AlienAnalogVoice.render(
            &first,
            measurement: &firstMeasurement,
            architectureMeasurement: &firstArchitecture,
            pulseEchoSend: &firstPulse,
            spatialReverbSend: &firstReverb,
            noteRenderEvidence: &firstEvidence,
            notes: [note],
            sampleRate: sampleRate,
            level: 0.08,
            world: fixtureWorld(seed: 48_291),
            bar: fixtureBar(),
            role: .atmosphere,
            state: &state
        )

        var tail = [Float](repeating: 0, count: 3_200)
        var tailMeasurement = [Float](repeating: 0, count: tail.count)
        var tailArchitecture = [Float](repeating: 0, count: tail.count)
        var tailPulse = [Float](repeating: 0, count: tail.count)
        var tailReverb = [Float](repeating: 0, count: tail.count)
        var tailEvidence: [UpperNoteRenderEvidence] = []
        AlienAnalogVoice.render(
            &tail,
            measurement: &tailMeasurement,
            architectureMeasurement: &tailArchitecture,
            pulseEchoSend: &tailPulse,
            spatialReverbSend: &tailReverb,
            noteRenderEvidence: &tailEvidence,
            notes: [],
            sampleRate: sampleRate,
            level: 0.08,
            world: fixtureWorld(seed: 48_291),
            bar: fixtureBar(),
            role: .atmosphere,
            state: &state
        )

        #expect(state.activeInstrument == active)
        #expect(tailEvidence.isEmpty)
        #expect(tail.contains { $0 != 0 })
        #expect(tail == tailMeasurement)
        #expect(tail == tailArchitecture)
    }

    @Test("A tonal patch boundary clears prior filter and effect memory")
    func tonalPatchBoundary() {
        let previous = assignment(
            patch: .northStar,
            use: .motif,
            automation: .neutral
        )
        let next = assignment(
            patch: .glassRunner,
            use: .motif,
            automation: .neutral
        )
        var state = AlienVoiceState()
        state.activeInstrument = previous
        state.envelope = 0.8
        state.filter1 = 0.7
        state.previousSource = 0.6
        state.echoLow = 0.5
        state.dcInput = 0.4
        state.dcOutput = 0.3
        state.tailLevel = 0.2
        state.comb = [0.9, -0.8]
        state.combIndex = 1
        state.allPass = [0.7, -0.6]
        state.allPassIndex = 1
        state.echo = [0.5, -0.4]
        state.echoIndex = 1

        state.prepare(
            sampleRate: 16_000,
            world: fixtureWorld(seed: 48_291),
            role: .anchor,
            instrument: next
        )

        #expect(state.activeInstrument == next)
        #expect(state.envelope == 0)
        #expect(state.filter1 == 0)
        #expect(state.previousSource == 0)
        #expect(state.echoLow == 0)
        #expect(state.dcInput == 0)
        #expect(state.dcOutput == 0)
        #expect(state.tailLevel == 0)
        #expect(state.comb.allSatisfy { $0 == 0 })
        #expect(state.combIndex == 0)
        #expect(state.allPass.allSatisfy { $0 == 0 })
        #expect(state.allPassIndex == 0)
        #expect(state.echo.allSatisfy { $0 == 0 })
        #expect(state.echoIndex == 0)
    }

    @Test("The canonical renderer emits exact architecture-local evidence")
    func canonicalRendererEvidence() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var session = director.initialState()
        var selectedPlan: AutonomousPhrasePlan?
        for _ in 0..<24 {
            let plan = director.candidates(from: session).primary
            let synth = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars,
                conservative: plan.conservative
            )
            let plannedArchitectures = Set(zip(plan.resolvedBars, synth.bars).flatMap {
                resolved, bar in
                let audibleFoundation = resolved.ensemble.events.contains {
                    $0.voice == .bass
                } ? [bar.foundationInstrument.architecture] : []
                return audibleFoundation + bar.upperNotes.map { $0.instrument.architecture }
            })
            if plannedArchitectures == Set(InstrumentArchitecture.allCases) {
                selectedPlan = plan
                break
            }
            session.advance(using: plan)
        }
        guard let plan = selectedPlan else {
            Issue.record("Expected the canonical session to schedule all architectures")
            return
        }
        let graph = DSPGraphGenerator.safePlan(sessionSeed: session.rootSeed)
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &renderState,
            graphState: &graphState
        )
        var observedArchitectures = Set<InstrumentArchitecture>()
        for block in blocks {
            let evidence = block.instrumentRenderEvidence
            let reduced = AutonomousInstrumentBarEvidence(
                bar: block.bar,
                evidence: evidence
            )
            #expect(reduced.isComplete)
            #expect(reduced.isFinite)
            for architecture in evidence {
                observedArchitectures.insert(architecture.architecture)
                #expect(architecture.finite)
                #expect(architecture.peak > 0)
                #expect(architecture.rms > 0)
                #expect(architecture.eventCount >= architecture.assignments.count)
                #expect(architecture.assignments.allSatisfy { $0.isValid })
                #expect(architecture.sampleHash.count == 16)
                if let modulation = architecture.resonantMonoModulation {
                    #expect(architecture.architecture == .resonantMono)
                    #expect(modulation.bindingValid)
                    #expect(modulation.operatorPeak > 0)
                    #expect(modulation.operatorRMS > 0)
                    #expect(modulation.lowBandEnergyRatio <=
                            ResonantMonoModulationContract.maximumLowBandEnergyRatio)
                }
            }
            for renderedNote in block.upperNoteRenderEvidence {
                #expect(evidence.contains { architecture in
                    architecture.architecture == renderedNote.instrument.architecture &&
                        architecture.assignments.contains(renderedNote.instrument)
                })
            }
        }
        #expect(observedArchitectures == Set(InstrumentArchitecture.allCases))

        var replayRenderState = RenderState()
        var replayGraphState = GeneratedDSPContinuationState()
        let replay = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &replayRenderState,
            graphState: &replayGraphState
        )
        #expect(blocks.map(\.instrumentRenderEvidence) ==
                replay.map(\.instrumentRenderEvidence))
        #expect(renderState == replayRenderState)
        #expect(graphState == replayGraphState)
    }

    @Test("The canonical journey reaches acid relations with truthful operator evidence")
    func canonicalAcidRelationEvidence() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var session = director.initialState()
        var selectedPlan: AutonomousPhrasePlan?
        var plannedRelations = Set<String>()
        for _ in 0..<64 {
            let plan = director.candidates(from: session).primary
            let synth = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars,
                conservative: plan.conservative
            )
            let relations = Set(synth.bars.flatMap(\.upperNotes).compactMap {
                $0.instrument.resonantMonoSpectralRelation?.rawValue
            })
            if !relations.isEmpty {
                selectedPlan = plan
                plannedRelations = relations
                break
            }
            session.advance(using: plan)
        }
        guard let plan = selectedPlan else {
            Issue.record("Expected the canonical session to schedule an acid relation")
            return
        }

        let graph = DSPGraphGenerator.safePlan(sessionSeed: session.rootSeed)
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &renderState,
            graphState: &graphState
        )
        var observedRelations = Set<String>()
        var sawCompleteReducedBar = false
        for block in blocks {
            let reduced = AutonomousInstrumentBarEvidence(
                bar: block.bar,
                evidence: block.instrumentRenderEvidence
            )
            #expect(reduced.isComplete)
            #expect(reduced.isFinite)
            for architecture in block.instrumentRenderEvidence {
                guard let modulation = architecture.resonantMonoModulation else {
                    continue
                }
                sawCompleteReducedBar = true
                #expect(architecture.architecture == .resonantMono)
                #expect(modulation.bindingValid)
                #expect(modulation.finite)
                #expect(modulation.operatorPeak > 0)
                #expect(modulation.operatorRMS > 0)
                #expect(modulation.operatorCrestFactor ==
                        modulation.operatorPeak / modulation.operatorRMS)
                #expect(modulation.lowBandEnergyRatio <=
                        ResonantMonoModulationContract.maximumLowBandEnergyRatio)
                if modulation.orderedEventCount > 0 {
                    observedRelations.insert(
                        ResonantMonoSpectralRelation.orderedHollow.rawValue
                    )
                }
                if modulation.metallicEventCount > 0 {
                    observedRelations.insert(
                        ResonantMonoSpectralRelation.metallicTension.rawValue
                    )
                }
            }
        }
        #expect(sawCompleteReducedBar)
        #expect(observedRelations == plannedRelations)

        var replayRenderState = RenderState()
        var replayGraphState = GeneratedDSPContinuationState()
        let replay = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &replayRenderState,
            graphState: &replayGraphState
        )
        #expect(blocks.map(\.instrumentRenderEvidence) ==
                replay.map(\.instrumentRenderEvidence))
        #expect(renderState == replayRenderState)
        #expect(graphState == replayGraphState)
    }

    @Test("Prepared evidence binds the selected acid score to its operator consequence")
    func preparedAcidRelationEvidence() throws {
        let fixture = try #require(activeAcidPrimaryFixture())
        var incomingRenderState = RenderState()
        incomingRenderState.barIndex = fixture.state.memory.totalBars
        let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
            candidates: fixture.candidates,
            sessionSeed: fixture.state.rootSeed,
            memory: fixture.state.memory,
            sampleRate: 8_000,
            incomingRenderState: incomingRenderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: fixture.state.quality,
            cancellationRequested: { false }
        )
        let prepared = try #require(preparedResult)

        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.candidateEvaluation.selectedSlot == .primary)
        #expect(prepared.selectedCandidateEvidence.slot == .primary)
        #expect(prepared.selectedCandidateEvidence.isComplete)
        #expect(!prepared.usedAlternate)
        #expect(!prepared.usedFallback)
        #expect(prepared.commitEligible)

        let evidence = prepared.selectedCandidateEvidence
        #expect(evidence.sourceInstrumentBarCount ==
                fixture.candidates.primary.resolvedBars.count)
        #expect(evidence.instruments.count == evidence.sourceInstrumentBarCount)
        let acidArchitectures = evidence.instruments.flatMap(\.architectures).filter {
            $0.resonantMonoModulation != nil
        }
        #expect(!acidArchitectures.isEmpty)
        #expect(acidArchitectures.allSatisfy { architecture in
            guard architecture.architecture ==
                    InstrumentArchitecture.resonantMono.rawValue,
                  let modulation = architecture.resonantMonoModulation else {
                return false
            }
            return architecture.isComplete && modulation.isComplete(
                assignments: architecture.assignments,
                architectureEventCount: architecture.eventCount
            )
        })
    }

    private func activeAcidPrimaryFixture() -> (
        state: AutonomousSessionState,
        candidates: AutonomousPhraseCandidates
    )? {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for _ in 0..<64 {
            let candidates = director.candidates(from: state)
            let synth = SynthPerformancePlan(
                scene: candidates.primary.scene,
                dna: candidates.primary.dna,
                kind: candidates.primary.kind,
                resolvedBars: candidates.primary.resolvedBars,
                conservative: candidates.primary.conservative
            )
            if synth.bars.flatMap(\.upperNotes).contains(where: {
                $0.instrument.resonantMonoSpectralRelation != nil
            }) {
                return (state, candidates)
            }
            state.advance(using: candidates.primary)
        }
        return nil
    }

    private func assignment(
        patch: InstrumentPatch,
        use: InstrumentUse,
        automation: InstrumentAutomation
    ) -> InstrumentAssignment {
        let effects = InstrumentPalette.capability(for: patch)?.compatibleEffects ?? []
        return InstrumentAssignment(
            use: use,
            patch: patch,
            automation: automation,
            effects: effects
        )
    }

    private func render(
        assignment: InstrumentAssignment,
        role: SynthRole,
        sampleRate: Double = 16_000.0
    ) -> (samples: [Float], evidence: [UpperNoteRenderEvidence],
          modulation: [Float]) {
        var output = [Float](
            repeating: 0,
            count: max(3_200, Int((sampleRate * 0.2).rounded()))
        )
        var roleMeasurement = [Float](repeating: 0, count: output.count)
        var architectureMeasurement = [Float](repeating: 0, count: output.count)
        var modulationMeasurement = [Float](repeating: 0, count: output.count)
        var pulseEcho = [Float](repeating: 0, count: output.count)
        var reverb = [Float](repeating: 0, count: output.count)
        var evidence: [UpperNoteRenderEvidence] = []
        let note = AlienVoiceNote(
            startFrame: 96,
            durationFrames: 2_100,
            frequency: 174.61,
            endFrequency: 220,
            velocity: 0.82,
            gate: .retrigger,
            timbreIntent: .home,
            instrument: assignment,
            role: role,
            articulation: .neutral,
            dryScale: 1,
            spatialReverbSend: 0,
            narrativeGainScale: 1,
            narrativeSpectralScale: 1
        )
        switch assignment.architecture {
        case .resonantMono:
            var state = ResonantMonoState()
            ResonantMonoVoice.renderUpper(
                &output,
                measurement: &roleMeasurement,
                architectureMeasurement: &architectureMeasurement,
                pulseEchoSend: &pulseEcho,
                spatialReverbSend: &reverb,
                modulationMeasurement: &modulationMeasurement,
                noteRenderEvidence: &evidence,
                notes: [note],
                sampleRate: sampleRate,
                level: 0.08,
                state: &state
            )
        case .tonalMotion:
            var state = AlienVoiceState()
            AlienAnalogVoice.render(
                &output,
                measurement: &roleMeasurement,
                architectureMeasurement: &architectureMeasurement,
                pulseEchoSend: &pulseEcho,
                spatialReverbSend: &reverb,
                noteRenderEvidence: &evidence,
                notes: [note],
                sampleRate: sampleRate,
                level: 0.08,
                world: fixtureWorld(seed: 48_291),
                bar: fixtureBar(),
                role: role,
                state: &state
            )
        case .spectralTexture:
            var state = SpectralTextureState()
            SpectralTextureVoice.render(
                &output,
                measurement: &roleMeasurement,
                architectureMeasurement: &architectureMeasurement,
                pulseEchoSend: &pulseEcho,
                spatialReverbSend: &reverb,
                noteRenderEvidence: &evidence,
                notes: [note],
                sampleRate: sampleRate,
                level: 0.08,
                state: &state
            )
        }
        #expect(output == roleMeasurement)
        #expect(output == architectureMeasurement)
        return (output, evidence, modulationMeasurement)
    }

    private func fixtureWorld(seed: UInt64) -> SynthWorldDNA {
        let scene = TechnoScene(
            intent: MusicalIntent(values: [.darkness: 0.76, .hypnosis: 0.82]),
            seed: seed,
            bpm: 130
        )
        return SynthWorldDNA(scene: scene, dna: SceneDNA(scene: scene))
    }

    private func fixtureBar() -> SynthPerformanceBar {
        SynthPerformanceBar(
            bar: 0,
            gesture: .interlock,
            mutationAmount: 0.48,
            relationalSteps: Array(repeating: .neutral, count: 16),
            upperNotes: []
        )
    }
}
