import Foundation
import Testing
import AutoTechnoCore
@testable import AutoTechnoDSP

@Suite("Resolved tonal release boundary")
struct TonalEnvelopeBoundaryTests {
    /// This is bounded score-only reconstruction, not accepted runtime state.
    /// Engine v48 reproduced native refusal fingerprint b35405a7d3f63299.
    /// Engine v49 resolves the wash on a different anchor, changing the score
    /// fingerprint; its version separately invalidates quality provenance. No PCM,
    /// quality continuation, model or archived corpus is imported.
    private func nativeRefusalScore() -> AutonomousPhrasePlan {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        for phrase in 0..<153 {
            let context: AutonomousQualityRecoveryContext
            switch phrase {
            case 33:
                context = AutonomousQualityRecoveryContext(
                    ordinal: 2, presentedRepeatBars: 6)
            case 87:
                context = AutonomousQualityRecoveryContext(
                    ordinal: 1, presentedRepeatBars: 13)
            default:
                context = .neutral
            }
            state.advancePlanning(using: director.plan(from: state,
                qualityRecoveryContext: context))
        }
        return director.plan(from: state)
    }

    private func synth(_ plan: AutonomousPhrasePlan,
                       forceHome: Bool = false) -> SynthPerformancePlan {
        SynthPerformancePlan(scene: plan.scene, dna: plan.dna, kind: plan.kind,
            resolvedBars: plan.resolvedBars, materialWorld: plan.materialWorld,
            forceHomeUpperTimbre: forceHome,
            compositionBars: plan.phraseComposition)
    }

    @MainActor
    @Test("The wash follows the final rendered anchor after held polymetric relocation")
    func washFollowsRelocatedFinalAnchor() throws {
        let plan = nativeRefusalScore()
        #expect(plan.phraseIndex == 153 && plan.startBar == 1_652)
        #expect(QualityQualificationContract.engineVersion == "autotechno-canonical-engine.v49")
        #expect(AutonomousCandidateFingerprint.plan(plan) == "31b0c8d89a9dc03f")
        let bar = try #require(synth(plan).bars.first { $0.bar == 1_663 })
        let anchors = bar.upperNotes.filter { $0.role == .anchor }
        #expect(anchors.map(\.onsetStep).sorted() == [8, 11])
        let wash = anchors.filter { $0.envelopeRelation == .sustainedWash }
        #expect(bar.tonalEnvelopeExpansionEligible)
        #expect(wash.count == 1)
        #expect(wash.first?.onsetStep == 11)
        #expect(anchors.filter { $0.onsetStep == 8 }.allSatisfy {
            $0.envelopeRelation == .home
        })
        #expect(bar.sourceUpperStep(for: .anchor, appliedStep: 11) == 4)
        #expect(bar.sourceUpperStep(for: .anchor, appliedStep: 8) == 8)
        let corrected = try #require(synth(plan, forceHome: true).bars.first {
            $0.bar == 1_663
        })
        #expect(corrected.tonalEnvelopeExpansionEligible)
        #expect(corrected.upperNotes.allSatisfy {
            $0.envelopeRelation == .home
        })
    }

    @MainActor
    @Test("Late and legato final anchors preserve the home fallback")
    func finalAnchorFallbacks() throws {
        let plan = nativeRefusalScore()
        let index = try #require(plan.resolvedBars.firstIndex { $0.performance.bar == 1_663 })
        let resolved = plan.resolvedBars[index]
        let bar = synth(plan).bars[index]
        let selected = try #require(SynthPerformancePlan.tonalEnvelopeExpansionIndex(
            notes: bar.upperNotes, kind: plan.kind, performance: resolved.performance,
            arrangementGesture: resolved.arrangementGesture))
        var late = bar.upperNotes
        late[selected] = late[selected].withOnsetStep(13)
        #expect(SynthPerformancePlan.tonalEnvelopeExpansionIndex(
            notes: late, kind: plan.kind, performance: resolved.performance,
            arrangementGesture: resolved.arrangementGesture) == nil)
        var slide = bar.upperNotes
        let note = slide[selected]
        slide[selected] = ResolvedUpperNote(role: note.role, onsetStep: note.onsetStep,
            durationInSteps: note.durationInSteps,
            startFrequencyRatio: note.startFrequencyRatio,
            endFrequencyRatio: note.endFrequencyRatio, velocity: note.velocity,
            gate: .slide, timbreIntent: note.timbreIntent,
            spectralReveal: note.spectralReveal,
            timingOffsetInSteps: note.timingOffsetInSteps, instrument: note.instrument)
        #expect(SynthPerformancePlan.tonalEnvelopeExpansionIndex(
            notes: slide, kind: plan.kind, performance: resolved.performance,
            arrangementGesture: resolved.arrangementGesture) == nil)
        #expect(SynthPerformancePlan.tonalEnvelopeExpansionIndex(
            notes: bar.upperNotes, kind: .identityReturn, performance: resolved.performance,
            arrangementGesture: resolved.arrangementGesture) == nil)
        // Relocation changes only onset geometry; relation ownership is mirrored
        // on the same source index without sorting or losing the mapping.
        for i in bar.upperNotes.indices {
            #expect(bar.sourceUpperNotes[i].withOnsetStep(bar.upperNotes[i].onsetStep)
                == bar.upperNotes[i])
        }
    }

    @MainActor
    @Test("The final relocated wash reaches same-pass complete native tonal evidence",
          arguments: [44_100.0, 48_000.0])
    func relocatedWashNativeEvidence(sampleRate: Double) throws {
        let plan = nativeRefusalScore()
        let performance = synth(plan)
        let index = try #require(performance.bars.firstIndex { $0.bar == 1_663 })
        var state = RenderState(); state.barIndex = 1_663
        var workspace = RenderWorkspace()
        let rendered = VoiceRenderer.renderBar(scene: plan.scene,
            sampleRate: sampleRate, state: &state, dna: plan.dna,
            resolved: plan.resolvedBars[index], synthWorld: performance.world,
            synthPerformance: performance.bars[index], workspace: &workspace,
            layer: .full, phraseKind: plan.kind)
        let architecture = try #require(rendered.instrumentRenderEvidence.first {
            $0.architecture == .tonalMotion
        })
        let expansion = try #require(architecture.tonalEnvelopeExpansion)
        #expect(expansion.active && expansion.bindingValid && expansion.finite)
        #expect(expansion.eventCount == 1)
        #expect(expansion.attackRMS > 0 && expansion.tailRMS > 0)
        #expect(abs(expansion.tailToAttackDB) <= 160)
        let evidence = AutonomousInstrumentBarEvidence(bar: 1_663,
            evidence: rendered.instrumentRenderEvidence)
        #expect(evidence.isComplete(sampleRate: sampleRate))
        let event = try #require(rendered.upperNoteRenderEvidence.first {
            $0.role == .anchor && $0.envelopeRelation == .sustainedWash
        })
        #expect(event.onsetFrame == Int((11 * Double(rendered.samples.count) / 16).rounded()))
    }
}
