import Foundation
import Testing
@testable import AutoTechnoCore
@testable import AutoTechnoDSP

@Suite("Upper spectral reveal DSP")
struct UpperSpectralRevealDSPTests {
    @Test("Home cutoff is exact and active aperture is bounded", arguments: [
        44_100.0, 48_000.0, 192_000.0,
    ])
    func cutoffMapping(sampleRate: Double) {
        let requested = sampleRate * 0.12
        let home = UpperSpectralRevealContract.appliedCutoffHz(
            requestedCutoffHz: requested,
            articulation: .home,
            sampleRate: sampleRate,
            maximumCutoffFraction: 0.18
        )
        let active = UpperSpectralRevealContract.appliedCutoffHz(
            requestedCutoffHz: requested,
            articulation: UpperSpectralRevealArticulation(
                relation: .emerging,
                aperture: 0.58
            ),
            sampleRate: sampleRate,
            maximumCutoffFraction: 0.18
        )

        #expect(home == requested)
        #expect(active == requested * 0.58)
        #expect(active >= TPTAntialiasedNonlinearCoreContract.minimumCutoffHz)
        #expect(active < home)
        #expect(active.isFinite)
    }

    @Test("Invalid cutoff inputs fail to the finite shared-core floor")
    func invalidInputs() {
        #expect(UpperSpectralRevealContract.appliedCutoffHz(
            requestedCutoffHz: .nan,
            articulation: UpperSpectralRevealArticulation(
                relation: .emerging,
                aperture: 0.5
            ),
            sampleRate: 48_000,
            maximumCutoffFraction: 0.18
        ) == TPTAntialiasedNonlinearCoreContract.minimumCutoffHz)
    }

    @Test("Prepared primary retains score, cutoff, and isolated anchor evidence")
    func preparedEvidence() throws {
        let fixture = try #require(activeFixture())
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
        let revealEvidence = vector.instruments.flatMap(\.architectures)
            .compactMap(\.upperSpectralReveal)
        let active = revealEvidence.filter(\.active)

        #expect(prepared.plan == fixture.plan)
        #expect(prepared.commitEligible)
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(vector.isComplete)
        #expect(vector.schemaVersion ==
                AutonomousCandidateEvaluationVector.schemaVersion)
        #expect(!active.isEmpty)
        #expect(active.allSatisfy {
            $0.eligible && $0.bindingValid && $0.finite &&
                $0.sourceScoreEventCount == $0.renderedEventCount &&
                $0.activeEventCount > 0 &&
                $0.minimumActiveAperture >=
                    UpperSpectralRevealArticulation.minimumAperture &&
                $0.maximumActiveAperture < 1 &&
                $0.minimumAppliedCutoffHz > 0 &&
                $0.maximumAppliedCutoffHz >= $0.minimumAppliedCutoffHz &&
                $0.anchorPeak > 0 && $0.anchorRMS > 0
        })
    }

    @Test("Home correction retains eligibility while neutralizing the reveal")
    func correctionRetainsEligibility() throws {
        let fixture = try #require(activeFixture())
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
            evaluator: CorrectingPrimaryTestEvaluator()
        )
        let attempts = prepared.candidateEvaluation.attempts
        let initialAttempt = try #require(attempts.first)
        let correctionAttempt = try #require(attempts.last)
        let initial = initialAttempt.vector.instruments.flatMap(
            \.architectures
        ).compactMap(\.upperSpectralReveal)
        let correction = correctionAttempt.vector.instruments.flatMap(
            \.architectures
        ).compactMap(\.upperSpectralReveal)

        #expect(attempts.count == 2)
        #expect(initial.contains { $0.eligible && $0.active })
        #expect(correction.contains { $0.eligible && !$0.active })
        #expect(initial.map(\.eligible) == correction.map(\.eligible))
        #expect(correction.allSatisfy { !$0.active && $0.activeEventCount == 0 })
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.commitEligible)

        let data = try JSONEncoder().encode(prepared.candidateEvaluation)
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var serializedAttempts = try #require(
            object["attempts"] as? [[String: Any]]
        )
        let correctionIndex = try #require(
            serializedAttempts.count == 2 ? 1 : nil
        )
        var correctionVector = try #require(
            serializedAttempts[correctionIndex]["vector"] as? [String: Any]
        )
        var instrumentBars = try #require(
            correctionVector["instruments"] as? [[String: Any]]
        )
        var didForge = false
        for barIndex in instrumentBars.indices where !didForge {
            var architectures = try #require(
                instrumentBars[barIndex]["architectures"] as?
                    [[String: Any]]
            )
            for architectureIndex in architectures.indices where !didForge {
                guard var reveal = architectures[architectureIndex][
                    "upperSpectralReveal"
                ] as? [String: Any], reveal["eligible"] as? Bool == true else {
                    continue
                }
                reveal["eligible"] = false
                architectures[architectureIndex]["upperSpectralReveal"] = reveal
                instrumentBars[barIndex]["architectures"] = architectures
                didForge = true
            }
        }
        #expect(didForge)
        correctionVector["instruments"] = instrumentBars
        serializedAttempts[correctionIndex]["vector"] = correctionVector
        object["attempts"] = serializedAttempts
        let forged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationTransaction.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(!forged.isComplete)
    }

    @Test("Decoded cutoff forgery invalidates the candidate vector")
    func decodedCutoffForgery() throws {
        let fixture = try #require(activeFixture())
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
        let data = try JSONEncoder().encode(
            prepared.selectedCandidateEvidence
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var instrumentBars = try #require(
            object["instruments"] as? [[String: Any]]
        )
        var didForge = false
        for barIndex in instrumentBars.indices where !didForge {
            var architectures = try #require(
                instrumentBars[barIndex]["architectures"] as?
                    [[String: Any]]
            )
            for architectureIndex in architectures.indices where !didForge {
                guard var reveal = architectures[architectureIndex][
                    "upperSpectralReveal"
                ] as? [String: Any], reveal["active"] as? Bool == true else {
                    continue
                }
                reveal["maximumAppliedCutoffHz"] = 8_000.0
                architectures[architectureIndex]["upperSpectralReveal"] = reveal
                instrumentBars[barIndex]["architectures"] = architectures
                didForge = true
            }
        }
        #expect(didForge)
        object["instruments"] = instrumentBars
        let forged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(!forged.isComplete)
    }

    @Test("Same score bar changes only each existing anchor spectral path",
          arguments: [
              InstrumentArchitecture.resonantMono,
              InstrumentArchitecture.tonalMotion,
          ])
    func rendererCausality(architecture: InstrumentArchitecture) throws {
        let fixture = try #require(activeRendererFixture(architecture: architecture))
        let activeSynth = fixture.synthPlan.bars[fixture.barIndex]
        let neutralSynth = SynthPerformanceBar(
            bar: activeSynth.bar,
            gesture: activeSynth.gesture,
            mutationAmount: activeSynth.mutationAmount,
            foundationInstrument: activeSynth.foundationInstrument,
            relationalSteps: activeSynth.relationalSteps,
            upperNotes: activeSynth.upperNotes.map {
                $0.role == .anchor ? $0.withSpectralReveal(.home) : $0
            },
            composition: activeSynth.composition,
            upperTimingRelation: activeSynth.upperTimingRelation,
            pulseEchoTextureArticulation:
                activeSynth.pulseEchoTextureArticulation,
            tonalEnvelopeExpansionEligible:
                activeSynth.tonalEnvelopeExpansionEligible,
            spectralRevealEligible: activeSynth.spectralRevealEligible,
            forceHomeUpperTimbre: activeSynth.forceHomeUpperTimbre
        )
        let resolved = fixture.plan.resolvedBars[fixture.barIndex]
        let active = render(
            plan: fixture.plan,
            resolved: resolved,
            synthWorld: fixture.synthPlan.world,
            synthPerformance: activeSynth,
            sampleRate: 48_000
        )
        let neutral = render(
            plan: fixture.plan,
            resolved: resolved,
            synthWorld: fixture.synthPlan.world,
            synthPerformance: neutralSynth,
            sampleRate: 48_000
        )
        let activeReveal = try #require(revealEvidence(in: active))
        let neutralReveal = try #require(revealEvidence(in: neutral))

        #expect(activeSynth.upperNotes.map(\.role) ==
                neutralSynth.upperNotes.map(\.role))
        #expect(activeSynth.upperNotes.map(\.onsetStep) ==
                neutralSynth.upperNotes.map(\.onsetStep))
        #expect(activeSynth.upperNotes.map(\.durationInSteps) ==
                neutralSynth.upperNotes.map(\.durationInSteps))
        #expect(activeSynth.upperNotes.map(\.startFrequencyRatio) ==
                neutralSynth.upperNotes.map(\.startFrequencyRatio))
        #expect(activeSynth.upperNotes.map(\.endFrequencyRatio) ==
                neutralSynth.upperNotes.map(\.endFrequencyRatio))
        #expect(activeSynth.upperNotes.map(\.velocity) ==
                neutralSynth.upperNotes.map(\.velocity))
        #expect(activeSynth.upperNotes.map(\.gate) ==
                neutralSynth.upperNotes.map(\.gate))
        #expect(activeReveal.active)
        #expect(!neutralReveal.active)
        #expect(activeReveal.maximumAppliedCutoffHz <
                neutralReveal.maximumAppliedCutoffHz)
        #expect(activeReveal.scoreFingerprint != neutralReveal.scoreFingerprint)
        #expect(activeReveal.renderFingerprint != neutralReveal.renderFingerprint)
        #expect(activeReveal.anchorSampleHash != neutralReveal.anchorSampleHash)
        #expect(active.resonantAnchorSamples != neutral.resonantAnchorSamples)
        #expect(active.detunedCompanionSamples == neutral.detunedCompanionSamples)
        #expect(active.dryFoundationSampleHash == neutral.dryFoundationSampleHash)
        #expect(active.dryPercussionSampleHash == neutral.dryPercussionSampleHash)
        #expect(active.dryModalPercussionSampleHash ==
                neutral.dryModalPercussionSampleHash)
        #expect(active.groovePulseRenderEvidence ==
                neutral.groovePulseRenderEvidence)
        #expect(active.closedHatRenderEvidence == neutral.closedHatRenderEvidence)
        #expect(active.upperPercussionTailRenderEvidence ==
                neutral.upperPercussionTailRenderEvidence)
        #expect(active.samples != neutral.samples)
    }

    private func activeFixture(
        architecture: InstrumentArchitecture? = nil
    ) -> (
        seed: UInt64,
        plan: AutonomousPhrasePlan,
        synthPlan: SynthPerformancePlan,
        barIndex: Int
    )? {
        for seed in UInt64(1)...1_024 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            let plan = director.plan(from: director.initialState())
            let synthPlan = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars,
                compositionBars: plan.phraseComposition
            )
            if let barIndex = synthPlan.bars.firstIndex(where: { bar in
                bar.spectralRevealEligible && bar.upperNotes.contains {
                    $0.role == .anchor &&
                        $0.spectralReveal.relation == .emerging &&
                        (architecture == nil ||
                            $0.instrument.architecture == architecture)
                }
            }) {
                return (seed, plan, synthPlan, barIndex)
            }
        }
        return nil
    }

    private func activeRendererFixture(
        architecture: InstrumentArchitecture
    ) -> (
        seed: UInt64,
        plan: AutonomousPhrasePlan,
        synthPlan: SynthPerformancePlan,
        barIndex: Int
    )? {
        let seed: UInt64 = 48_291
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        for _ in 0..<96 {
            let plan = director.plan(from: state)
            let synthPlan = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars,
                compositionBars: plan.phraseComposition
            )
            if let barIndex = synthPlan.bars.firstIndex(where: { bar in
                bar.spectralRevealEligible && bar.upperNotes.contains {
                    $0.role == .anchor &&
                        $0.spectralReveal.relation == .emerging &&
                        $0.instrument.architecture == architecture
                }
            }) {
                return (seed, plan, synthPlan, barIndex)
            }
            state.advancePlanning(using: plan)
        }
        return nil
    }

    private func render(
        plan: AutonomousPhrasePlan,
        resolved: ResolvedPerformanceBar,
        synthWorld: SynthWorldDNA,
        synthPerformance: SynthPerformanceBar,
        sampleRate: Double
    ) -> RenderedBar {
        var state = RenderState()
        state.barIndex = resolved.performance.bar
        var workspace = RenderWorkspace()
        return VoiceRenderer.renderBar(
            scene: plan.scene,
            sampleRate: sampleRate,
            state: &state,
            dna: plan.dna,
            resolved: resolved,
            synthWorld: synthWorld,
            synthPerformance: synthPerformance,
            workspace: &workspace,
            layer: .full,
            phraseKind: plan.kind
        )
    }

    private func revealEvidence(
        in rendered: RenderedBar
    ) -> UpperSpectralRevealRenderEvidence? {
        rendered.instrumentRenderEvidence.compactMap(
            \.upperSpectralReveal
        ).first
    }
}
