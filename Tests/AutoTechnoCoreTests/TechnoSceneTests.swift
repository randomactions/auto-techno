import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Autonomous performance director")
struct AutonomousPerformanceDirectorTests {
    @Test("The shipped performance is deterministic and fixed at 130 BPM",
          arguments: [0, 1, 7, 8, 31])
    func fixedTempoDeterminism(position: Int) {
        let director = AutonomousPerformanceDirector()
        let first = director.scene(at: position)
        let second = director.scene(at: position)
        #expect(first == second)
        #expect(first.position == position)
        #expect(first.scene.bpm == AutonomousPerformanceDirector.bpm)
        #expect(first.scene.musicalIntent != nil)
    }

    @Test("Autonomous scenes evolve without adjacent seed repetition")
    func unattendedEvolution() {
        let director = AutonomousPerformanceDirector()
        let scenes = (0..<24).map(director.scene(at:))
        #expect(Set(scenes.map(\.seed)).count == scenes.count)
        #expect(zip(scenes, scenes.dropFirst()).allSatisfy { $0.seed != $1.seed })
        #expect(scenes[7].cycle == 0)
        #expect(scenes[8].cycle == 1)
        #expect(scenes.allSatisfy { $0.scene.bpm == 130 })
    }

    @Test("Negative positions clamp to the first autonomous scene")
    func negativePositionClamp() {
        let director = AutonomousPerformanceDirector(rootSeed: 42)
        #expect(director.scene(at: -1) == director.scene(at: 0))
    }
}

@Suite("Persistent musical performance")
struct MusicalPerformanceTests {
    private let seeds: [UInt64] = [42, 48291, 90909, 7, 77777]

    @Test("Scene DNA and performance plans are deterministic", arguments: [UInt64(42), 48291, 90909, 7, 77777])
    func deterministicIdentity(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.58, darkness: 0.72, hypnosis: 0.76)
        #expect(SceneDNA(scene: scene) == SceneDNA(scene: scene))
        #expect(PerformancePlan(scene: scene) == PerformancePlan(scene: scene))
    }

    @Test("The score is asymmetric but covers exactly 32 bars", arguments: [UInt64(42), 48291, 90909, 7, 77777])
    func completeAsymmetricForm(seed: UInt64) {
        let plan = PerformancePlan(scene: TechnoScene(seed: seed, drive: 0.58, darkness: 0.72, hypnosis: 0.76))
        #expect(plan.bars.count == 32)
        #expect(plan.bars.map(\.bar) == Array(0..<32))
        #expect(plan.phrases.reduce(0) { $0 + $1.barCount } == 32)
        #expect(plan.phrases.contains { $0.barCount != 8 })
        #expect(plan.phrases.last?.section == .returnSection)
    }

    @Test("Musical memory survives bounded transformations", arguments: [UInt64(42), 48291, 90909, 7, 77777])
    func boundedTransformations(seed: UInt64) {
        let plan = PerformancePlan(scene: TechnoScene(seed: seed, drive: 0.58, darkness: 0.72, hypnosis: 0.76))
        let transformations = plan.bars.flatMap(\.transformations)
        let repeats = transformations.filter { $0 == .`repeat` || $0 == .restore }.count
        #expect(repeats >= plan.bars.count / 3)
        #expect(Set(transformations).count >= 2)
        #expect(plan.bars.allSatisfy { $0.roles.count <= 4 })
        #expect(plan.dna.rhythm.kickSteps.contains(0))
        #expect(!plan.dna.rhythm.bassSteps.contains { plan.dna.rhythm.kickSteps.contains($0) })
    }

    @Test("Signature events stay rare and phrase-bound", arguments: [UInt64(42), 48291, 90909, 7, 77777])
    func rareEvents(seed: UInt64) {
        let plan = PerformancePlan(scene: TechnoScene(seed: seed, drive: 0.58, darkness: 0.72, hypnosis: 0.76))
        let signatures = plan.bars.filter { $0.signatureEvent != nil }
        #expect(signatures.count <= 3)
        #expect(signatures.allSatisfy { bar in
            plan.phrases.contains { $0.startBar + $0.barCount - 1 == bar.bar }
        })
    }

    @Test("Different seeds retain distinct identity")
    func distinctSeeds() {
        let identities = seeds.map { SceneDNA(scene: TechnoScene(seed: $0, drive: 0.58, darkness: 0.72, hypnosis: 0.76)) }
        #expect(Set(identities.map { "\($0.tonalCenter)-\($0.rhythm.bassSteps)-\($0.timbralFamily)" }).count >= 4)
    }

    @Test("Phrase accents breathe while staying restrained", arguments: [UInt64(42), 48291, 90909, 7, 77777])
    func restrainedAccentContours(seed: UInt64) {
        let plan = PerformancePlan(scene: TechnoScene(seed: seed, drive: 0.58, darkness: 0.72, hypnosis: 0.76))
        #expect(plan.bars.allSatisfy { $0.accentContour.count == 16 })
        #expect(plan.bars.flatMap(\.accentContour).allSatisfy { (0.78...1.18).contains($0) })
        #expect(Set(plan.bars.map(\.accentContour)).count > plan.phrases.count)
        #expect(plan.bars.filter { $0.tension > 0.76 }.allSatisfy { $0.roles.contains(.transition) })
        #expect(plan.bars.filter { $0.section == .breakdown }.allSatisfy { $0.roles.contains(.atmosphere) })
    }

    @Test("Every signature event has a deterministic reachable score case")
    func signatureVocabularyIsReachable() {
        let signatures = Set((1...2_000).flatMap { seed -> [SignatureEvent] in
            PerformancePlan(scene: TechnoScene(seed: UInt64(seed), drive: 0.58, darkness: 0.72, hypnosis: 0.76))
                .bars.compactMap(\.signatureEvent)
        })
        #expect(signatures == Set(SignatureEvent.allCases))
    }

    @Test("Alien synth clocks are deterministic, cross-bar, and kick-safe",
          arguments: [UInt64(42), 48291, 90909])
    func alienSynthPlan(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.58, darkness: 0.72, hypnosis: 0.76)
        let performance = PerformancePlan(scene: scene)
        let first = SynthPerformancePlan(scene: scene, performance: performance)
        let second = SynthPerformancePlan(scene: scene, performance: performance)
        #expect(first == second)
        #expect(first.bars.count == 32)
        #expect(first.bars.map(\.sevenStepPhase) == (0..<32).map { ($0 * 16) % 7 })
        #expect(first.bars.map(\.echoGatePhase) ==
                (0..<32).map { ($0 * 16 + first.world.echoRotation) % 3 })
        #expect(first.bars.allSatisfy { bar in
            bar.gesture == .suspend || bar.interlockEvents.count == 5
        })
        #expect(first.bars.flatMap(\.interlockEvents).allSatisfy { event in
            !performance.dna.rhythm.kickSteps.contains(event.stepIndex)
        })
        #expect(first.bars.flatMap(\.interlockEvents).contains { $0.sevenStepAccent })
        #expect(first.bars.flatMap(\.interlockEvents).contains { $0.echoGate })
    }

    @Test("Anchor-only synth plans preserve gestures but omit shadow events")
    func anchorOnlySynthPlan() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.58, darkness: 0.72, hypnosis: 0.76)
        let performance = PerformancePlan(scene: scene)
        let full = SynthPerformancePlan(scene: scene, performance: performance)
        let anchor = SynthPerformancePlan(scene: scene, performance: performance, includeInterlocks: false)
        #expect(full.world == anchor.world)
        #expect(full.bars.map(\.gesture) == anchor.bars.map(\.gesture))
        #expect(anchor.bars.allSatisfy { $0.interlockEvents.isEmpty })
        #expect(full.bars.contains { !$0.interlockEvents.isEmpty })
    }
}

@Suite("96-bar dramatic journey")
struct DramaticJourneyTests {
    private let seeds: [UInt64] = [42, 48291, 90909, 7, 77777]

    @Test("Journey planning is deterministic and covers exactly 96 bars",
          arguments: [UInt64(42), 48291, 90909, 7, 77777])
    func deterministicCompleteJourney(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let first = DramaticJourneyPlan(scene: scene)
        let second = DramaticJourneyPlan(scene: scene)
        #expect(first == second)
        #expect(first.bars.count == DramaticJourneyPlan.barCount)
        #expect(first.bars.map(\.bar) == Array(0..<DramaticJourneyPlan.barCount))
        #expect(Set(first.bars.map(\.phase)) == Set(DramaticPhase.allCases))
        #expect(first.bars.allSatisfy { bar in
            TensionDimension.allCases.allSatisfy { (0...1).contains(bar.tension[$0]) } &&
                (0...1).contains(bar.tension.overall) && bar.accentContour.count == 16 &&
                bar.accentContour.allSatisfy { (0.76...1.24).contains($0) }
        })
    }

    @Test("Every dramatic debt is paid exactly when promised",
          arguments: [UInt64(42), 48291, 90909])
    func debtsHavePayoffs(seed: UInt64) {
        let plan = DramaticJourneyPlan(scene: TechnoScene(seed: seed, drive: 0.65, darkness: 0.78, hypnosis: 0.74))
        #expect(plan.unpaidDebtIDs.isEmpty)
        #expect(plan.payoffs.count == plan.debts.count)
        for debt in plan.debts {
            let matching = plan.payoffs.filter { $0.debtID == debt.id }
            #expect(matching.count == 1)
            #expect(matching.first?.bar == debt.dueAtBar)
            #expect(plan.bars[debt.openedAtBar].activeDebts.contains { $0.id == debt.id })
            #expect(!plan.bars[debt.dueAtBar].activeDebts.contains { $0.id == debt.id })
        }
    }

    @Test("The final return pays substantially more tension than the false return",
          arguments: [UInt64(42), 48291, 90909])
    func earnedReturnContrast(seed: UInt64) {
        let plan = DramaticJourneyPlan(scene: TechnoScene(seed: seed, drive: 0.65, darkness: 0.78, hypnosis: 0.74))
        let falseReturn = plan.bars[24]
        let anticipation = plan.bars[79]
        let returnBar = plan.bars[80]
        #expect(falseReturn.payoffStrength < 0.5)
        #expect(returnBar.payoffStrength > falseReturn.payoffStrength + 0.35)
        #expect(anticipation.tension.overall > 0.80)
        #expect(returnBar.tension.overall < 0.30)
        #expect(anticipation.lowEndPresence < 0.12)
        #expect(returnBar.lowEndPresence == 1)
        #expect(anticipation.kickPresence < 0.20)
        #expect(returnBar.kickPresence == 1)
        #expect(returnBar.hasDryImpact)
        #expect(plan.bars[79].roles.contains(.transition))
    }

    @Test("Subtraction creates pressure without using density as a proxy")
    func independentTensionDimensions() {
        let plan = DramaticJourneyPlan(scene: TechnoScene(seed: 48291, drive: 0.65, darkness: 0.78, hypnosis: 0.74))
        let start = plan.bars[48].tension
        let end = plan.bars[63].tension
        #expect(end.density < start.density)
        #expect(end.spatialDistance > start.spatialDistance)
        #expect(end.lowEndUncertainty > start.lowEndUncertainty)
        #expect(end.motifIncompletion > start.motifIncompletion)
        #expect(end.overall > start.overall)
    }

    @Test("Authored patch DNA and macros remain deterministic and bounded",
          arguments: [UInt64(42), 48291, 90909])
    func authoredPatchContract(seed: UInt64) {
        let scene = TechnoScene(seed: seed, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let plan = DramaticJourneyPlan(scene: scene)
        #expect(plan.patch == DramaticJourneyPlan(scene: scene).patch)
        #expect(plan.patch.family == InstrumentPatchDNA.Family.shadowPressure)
        #expect((0..<4).contains(plan.patch.variation))
        #expect(plan.bars.allSatisfy { bar in
            let macro = bar.patchMacros
            return [macro.pressure, macro.motion, macro.bite, macro.decay,
                    macro.distance, macro.instability, macro.impact]
                .allSatisfy { (0...1).contains($0) }
        })
        #expect(plan.bars[79].patchMacros.pressure > plan.bars[80].patchMacros.pressure)
        #expect(plan.bars[80].patchMacros.impact > plan.bars[24].patchMacros.impact)
    }
}

@Suite("Deterministic scene planning")
struct TechnoSceneTests {
    @Test("Sequencer ambient is deterministic, variant-specific, and drum-locked", arguments: [UInt64(42), 48291, 90909])
    func sequencerAmbientRules(seed: UInt64) {
        let base = MusicalIntent(values: [.sequencerPresence: 0.8, .sequencerDensity: 0.6, .sequencerRepetition: 0.8])
        let pulse = TechnoScene(intent: MusicalIntent(values: [
            .sequencerPresence: 0.8, .sequencerStyle: 0.0, .sequencerDensity: 0.6, .sequencerRepetition: 0.8
        ]), seed: seed)
        let repeatPulse = TechnoScene(intent: MusicalIntent(values: [
            .sequencerPresence: 0.8, .sequencerStyle: 0.0, .sequencerDensity: 0.6, .sequencerRepetition: 0.8
        ]), seed: seed)
        #expect(pulse.sequencer == repeatPulse.sequencer)
        #expect(!pulse.sequencer.isEmpty)
        #expect(pulse.sequencer.allSatisfy { $0.stepIndex >= 0 && $0.stepIndex < 16 })
        #expect(pulse.sequencer.allSatisfy { pulse.steps[$0.stepIndex].hat || (pulse.steps[$0.stepIndex].kick && !pulse.steps[$0.stepIndex].bass) })
        #expect(base[.sequencerPresence] == 0.8)

        let arp = TechnoScene(intent: MusicalIntent(values: [.sequencerPresence: 0.8, .sequencerStyle: 0.5]), seed: seed)
        let texture = TechnoScene(intent: MusicalIntent(values: [.sequencerPresence: 0.8, .sequencerStyle: 1.0]), seed: seed)
        #expect(arp.sequencer.allSatisfy { $0.kind == .arpeggiatedMotif })
        #expect(texture.sequencer.allSatisfy { $0.kind == .texturalStepField })
        #expect(arp.sequencer.allSatisfy { arp.steps[$0.stepIndex].hat || (arp.steps[$0.stepIndex].kick && !arp.steps[$0.stepIndex].bass) })
        #expect(texture.sequencer.allSatisfy { texture.steps[$0.stepIndex].hat || (texture.steps[$0.stepIndex].kick && !texture.steps[$0.stepIndex].bass) })
    }

    @Test("Sequencer ambient is independent from drone")
    func sequencerAndDroneAreIndependent() {
        let intent = MusicalIntent(values: [.sequencerPresence: 0.75, .drone: 0.0])
        let scene = TechnoScene(intent: intent, seed: 42)
        #expect(scene.sequencer.count > 0)
        #expect(scene.drone == 0)
    }
    @Test("Same seed and intentions produce the same scene", arguments: [UInt64(42), 48291, 90909])
    func deterministicScene(seed: UInt64) {
        let first = TechnoScene(seed: seed, bpm: 130, drive: 0.68, darkness: 0.78, hypnosis: 0.76)
        let second = TechnoScene(seed: seed, bpm: 130, drive: 0.68, darkness: 0.78, hypnosis: 0.76)
        #expect(first == second)
    }

    @Test("The warehouse pulse stays anchored")
    func stablePulse() {
        let scene = TechnoScene(seed: 42, bpm: 130, drive: 0.7, darkness: 0.8, hypnosis: 0.75)
        // Step 0 always has kick (downbeat anchor)
        #expect(scene.steps[0].kick)
        #expect(scene.steps.enumerated().allSatisfy { !$0.element.bass || !$0.element.kick })
        #expect(scene.steps.contains { $0.hat })
    }

    @Test("Swing stays bounded and leaves kicks on the grid", arguments: [UInt64(42), 48291, 90909])
    func boundedSwing(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.7, darkness: 0.8, hypnosis: 0.75)
        #expect((0.50...0.56).contains(scene.groove.swingPercent))
        for event in scene.groove.events {
            if event.kind == .kick || event.kind == .clap {
                #expect(event.offsetInStep == 0)
            } else if event.offsetInStep > 0 {
                #expect(event.kind == .hat || event.kind == .bass)
                if event.kind == .hat {
                    #expect(event.stepIndex % 2 == 1 || event.stepIndex % 4 == 2)
                } else {
                    #expect(event.stepIndex % 2 == 1)
                }
                #expect(Double(event.stepIndex) + event.offsetInStep < 16)
            }
        }
    }

    @Test("Different seeds can vary eligible swing timing")
    func seedVariesTiming() {
        let first = TechnoScene(seed: 42, bpm: 130, drive: 0.7, darkness: 0.8, hypnosis: 0.75)
        let second = TechnoScene(seed: 48291, bpm: 130, drive: 0.7, darkness: 0.8, hypnosis: 0.75)
        #expect(first.groove.swingPercent != second.groove.swingPercent)
    }

    @Test("Motif is sparse, bounded, and deterministic", arguments: [UInt64(42), 48291, 90909])
    func motifRules(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.68, darkness: 0.78, hypnosis: 0.76)
        let repeatScene = TechnoScene(seed: seed, bpm: 130, drive: 0.68, darkness: 0.78, hypnosis: 0.76)
        #expect(scene.motif == repeatScene.motif)
        #expect((1...2).contains(scene.motif.count))
        #expect(scene.motif.allSatisfy { (110...440).contains($0.frequency) })
        #expect(scene.motif.allSatisfy { $0.stepIndex % 4 != 0 })
        #expect(scene.motif.allSatisfy { $0.offsetInStep >= 0 && $0.offsetInStep <= 0.12 })
        #expect(scene.motif.allSatisfy { Double($0.stepIndex) + $0.offsetInStep < 16 })
    }

    @Test("Variation remains bounded", arguments: [UInt64(42), 48291, 90909])
    func boundedVariation(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.8, darkness: 0.72, hypnosis: 0.7)
        let extraHats = scene.steps.enumerated().filter { index, step in step.hat && index % 4 != 2 }.count
        let bassNotes = scene.steps.filter(\.bass).count
        #expect(extraHats <= 4)
        #expect(bassNotes <= 5)
    }

    @Test("Surprise stays inside the intended warehouse range", arguments: [UInt64(42), 48291, 90909])
    func surpriseBounds(seed: UInt64) {
        let scene = TechnoScene.surprise(seed: seed, bpm: 130)
        #expect((0.42...0.82).contains(scene.drive))
        #expect((0.58...0.9).contains(scene.darkness))
        #expect((0.55...0.88).contains(scene.hypnosis))
    }

    @Test("Large changes use one exchange bar")
    func transitionPlan() {
        let current = TechnoScene(seed: 42, bpm: 130, drive: 0.2, darkness: 0.3, hypnosis: 0.3)
        let target = TechnoScene(seed: 43, bpm: 130, drive: 0.8, darkness: 0.9, hypnosis: 0.85)
        let plan = TransitionPlan(current: current, target: target, reason: .surprise)
        #expect(plan.narrative == .elementExchange)
        #expect(plan.transitionBars == 1)
    }

    @Test("Groove can never reach zero")
    func grooveFloor() {
        var intent = MusicalIntent()
        intent[.groove] = 0
        #expect(intent[.groove] == MusicalControl.groove.minimum)
    }

    @Test("Machine texture is deterministic and bounded", arguments: [UInt64(42), 48291, 90909])
    func machineTextureDeterminism(seed: UInt64) {
        var intent = MusicalIntent()
        intent[.machineTexture] = 0.82
        let first = TechnoScene(intent: intent, seed: seed)
        let second = TechnoScene(intent: intent, seed: seed)
        #expect(first == second)
        #expect((0...1).contains(first.machineTexture))
        #expect(first.steps[0].kick)
    }

    @Test("Drone is deterministic, bounded, and semantically distinct", arguments: [UInt64(42), 48291, 90909])
    func droneDeterminism(seed: UInt64) {
        var quiet = MusicalIntent()
        quiet[.drone] = 0.05
        var vast = quiet
        vast[.drone] = 0.95
        let first = TechnoScene(intent: vast, seed: seed)
        let second = TechnoScene(intent: vast, seed: seed)
        let restrained = TechnoScene(intent: quiet, seed: seed)
        #expect(first == second)
        #expect((0...1).contains(first.drone))
        #expect(first.drone > restrained.drone)
        #expect(first.steps[0].kick)
    }

    @Test("BPM is clamped to the valid range")
    func bpmClamping() {
        let tooLow = TechnoScene(seed: 42, bpm: 80, drive: 0.5, darkness: 0.5, hypnosis: 0.5)
        #expect(tooLow.bpm == TechnoScene.bpmRange.lowerBound)

        let tooHigh = TechnoScene(seed: 42, bpm: 200, drive: 0.5, darkness: 0.5, hypnosis: 0.5)
        #expect(tooHigh.bpm == TechnoScene.bpmRange.upperBound)

        let inRange = TechnoScene(seed: 42, bpm: 135, drive: 0.5, darkness: 0.5, hypnosis: 0.5)
        #expect(inRange.bpm == 135)
    }

    @Test("Same seed and BPM produce the same scene", arguments: [UInt64(42), 48291])
    func deterministicWithBpm(seed: UInt64) {
        let a = TechnoScene(seed: seed, bpm: 122, drive: 0.6, darkness: 0.7, hypnosis: 0.65)
        let b = TechnoScene(seed: seed, bpm: 122, drive: 0.6, darkness: 0.7, hypnosis: 0.65)
        #expect(a == b)
    }

    @Test("Different BPM changes only tempo, not pattern")
    func bpmDoesNotAffectPattern() {
        let slow = TechnoScene(seed: 42, bpm: 120, drive: 0.6, darkness: 0.7, hypnosis: 0.65)
        let fast = TechnoScene(seed: 42, bpm: 140, drive: 0.6, darkness: 0.7, hypnosis: 0.65)
        #expect(slow.steps == fast.steps)
        #expect(slow.groove.swingPercent == fast.groove.swingPercent)
        #expect(slow.motif == fast.motif)
        #expect(slow.bpm != fast.bpm)
    }

    @Test("Surprise preserves the given BPM")
    func surprisePreservesBpm() {
        let scene = TechnoScene.surprise(seed: 42, bpm: 125)
        #expect(scene.bpm == 125)
    }

    // MARK: - v0.4 Arrangement tests

    @Test("Arrangement is deterministic for the same seed and pace", arguments: [UInt64(42), 48291, 90909])
    func deterministicArrangement(seed: UInt64) {
        let first = ArrangementPlan(seed: seed, paceOfChange: 0.25)
        let second = ArrangementPlan(seed: seed, paceOfChange: 0.25)
        #expect(first == second)
    }

    @Test("Arrangement has phrases with valid bar counts")
    func arrangementStructure() {
        let plan = ArrangementPlan(seed: 48291, paceOfChange: 0.25)
        #expect(plan.phrases.count == 8)
        #expect(plan.phrases.allSatisfy { $0.barCount >= 4 && $0.barCount <= 8 })
        #expect(plan.totalBars > 0)
        // Phrases should be contiguous and start at bar 0.
        #expect(plan.phrases.first?.startBar == 0)
        for index in 1..<plan.phrases.count {
            let prev = plan.phrases[index - 1]
            let current = plan.phrases[index]
            #expect(current.startBar == prev.startBar + prev.barCount)
        }
    }

    @Test("Arrangement cycles through all four section kinds")
    func arrangementSectionCycle() {
        let plan = ArrangementPlan(seed: 48291, paceOfChange: 0.25)
        let sections = plan.phrases.map(\.section)
        #expect(sections.contains(.groove))
        #expect(sections.contains(.build))
        #expect(sections.contains(.breakdown))
        #expect(sections.contains(.returnSection))
    }

    @Test("Arrangement wraps around at totalBars")
    func arrangementWrapsAround() {
        let plan = ArrangementPlan(seed: 48291, paceOfChange: 0.25)
        let total = plan.totalBars
        #expect(plan.section(atBar: 0) == plan.section(atBar: total))
        #expect(plan.section(atBar: total + 1) == plan.section(atBar: 1))
    }

    @Test("barsToPhraseEnd is zero at the last bar of a phrase")
    func phraseEndDetection() {
        let plan = ArrangementPlan(seed: 48291, paceOfChange: 0.25)
        guard let firstPhrase = plan.phrases.first else { return }
        let lastBar = firstPhrase.startBar + firstPhrase.barCount - 1
        #expect(plan.barsToPhraseEnd(atBar: lastBar) == 0)
        #expect(plan.barsToPhraseEnd(atBar: firstPhrase.startBar) == firstPhrase.barCount - 1)
    }

    @Test("Slower pace produces longer phrases on average")
    func paceAffectsLength() {
        let slow = ArrangementPlan(seed: 48291, paceOfChange: 0.0)
        let fast = ArrangementPlan(seed: 48291, paceOfChange: 1.0)
        #expect(slow.totalBars >= fast.totalBars)
    }

    // MARK: - v0.4 Phrase-aware transition tests

    @Test("Phrase-aware plan uses breakdown and return at phrase boundary for large shifts")
    func breakdownAtPhraseEnd() {
        let current = TechnoScene(seed: 42, bpm: 130, drive: 0.2, darkness: 0.3, hypnosis: 0.3)
        let target = TechnoScene(seed: 43, bpm: 130, drive: 0.8, darkness: 0.9, hypnosis: 0.85)
        let phrase = PhraseContext(barsToPhraseEnd: 0, currentSection: .groove)
        let plan = TransitionPlan(current: current, target: target, reason: .drive, phrase: phrase)
        #expect(plan.narrative == .breakdownAndReturn)
        #expect(plan.transitionBars == 2)
    }

    @Test("Phrase-aware plan uses fill and turn near phrase boundary for medium shifts")
    func fillNearPhraseEnd() {
        let current = TechnoScene(seed: 42, bpm: 130, drive: 0.5, darkness: 0.5, hypnosis: 0.5)
        let target = TechnoScene(seed: 43, bpm: 130, drive: 0.8, darkness: 0.65, hypnosis: 0.65)
        let phrase = PhraseContext(barsToPhraseEnd: 1, currentSection: .groove)
        let plan = TransitionPlan(current: current, target: target, reason: .drive, phrase: phrase)
        #expect(plan.narrative == .fillAndTurn)
        #expect(plan.transitionBars == 1)
    }

    @Test("Phrase-aware plan uses long morph mid-phrase for medium shifts")
    func longMorphMidPhrase() {
        let current = TechnoScene(seed: 42, bpm: 130, drive: 0.5, darkness: 0.5, hypnosis: 0.5)
        let target = TechnoScene(seed: 43, bpm: 130, drive: 0.8, darkness: 0.65, hypnosis: 0.65)
        let phrase = PhraseContext(barsToPhraseEnd: 4, currentSection: .groove)
        let plan = TransitionPlan(current: current, target: target, reason: .drive, phrase: phrase)
        #expect(plan.narrative == .longMorph)
        #expect(plan.transitionBars == 4)
    }

    @Test("Phrase-aware plan uses crash and cut for surprise at phrase boundary")
    func crashAndCutForSurprise() {
        let current = TechnoScene(seed: 42, bpm: 130, drive: 0.2, darkness: 0.2, hypnosis: 0.2)
        let target = TechnoScene(seed: 43, bpm: 130, drive: 0.9, darkness: 0.9, hypnosis: 0.9)
        let phrase = PhraseContext(barsToPhraseEnd: 0, currentSection: .groove)
        let plan = TransitionPlan(current: current, target: target, reason: .surprise, phrase: phrase)
        #expect(plan.narrative == .crashAndCut)
        #expect(plan.transitionBars == 1)
    }

    @Test("Phrase-aware plan falls back to subtle drift for small changes")
    func subtleDriftForSmallChanges() {
        let current = TechnoScene(seed: 42, bpm: 130, drive: 0.6, darkness: 0.7, hypnosis: 0.7)
        let target = TechnoScene(seed: 43, bpm: 130, drive: 0.62, darkness: 0.71, hypnosis: 0.7)
        let phrase = PhraseContext(barsToPhraseEnd: 2, currentSection: .groove)
        let plan = TransitionPlan(current: current, target: target, reason: .drive, phrase: phrase)
        #expect(plan.narrative == .subtleDrift)
        #expect(plan.transitionBars == 0)
    }

    @Test("Non-phrase plan preserves original binary behavior")
    func nonPhrasePlanCompatibility() {
        let current = TechnoScene(seed: 42, bpm: 130, drive: 0.2, darkness: 0.3, hypnosis: 0.3)
        let target = TechnoScene(seed: 43, bpm: 130, drive: 0.8, darkness: 0.9, hypnosis: 0.85)
        let plan = TransitionPlan(current: current, target: target, reason: .surprise)
        #expect(plan.narrative == .elementExchange)
        #expect(plan.transitionBars == 1)
    }
}

@Suite("Offline audio rendering")
struct SceneRendererTests {
    @Test("Machine texture changes only the upper texture destination", arguments: [UInt64(42), 48291, 90909])
    func machineTextureIsAudibleAndSafe(seed: UInt64) {
        var plain = MusicalIntent()
        plain[.machineTexture] = 0
        var fractured = plain
        fractured[.machineTexture] = 0.9
        let dry = SceneRenderer.render(scene: TechnoScene(intent: plain, seed: seed), sampleRate: 44_100)
        let wet = SceneRenderer.render(scene: TechnoScene(intent: fractured, seed: seed), sampleRate: 44_100)
        #expect(dry != wet)
        #expect(wet.samples.allSatisfy { $0.isFinite })
        #expect(wet.peak <= 0.82)
    }
    @Test("Shadow and Fog remain distinct audible destinations", arguments: [UInt64(42), 48291, 90909])
    func shadowAndFogAreDistinct(seed: UInt64) {
        var shadow = MusicalIntent()
        shadow[.darkness] = 0.9
        shadow[.atmosphere] = 0.15
        shadow[.atmosphericDarkness] = 0.1

        var fog = shadow
        fog[.darkness] = 0.15
        fog[.atmosphere] = 0.9
        fog[.atmosphericDarkness] = 0.9

        let shadowScene = TechnoScene(intent: shadow, seed: seed)
        let fogScene = TechnoScene(intent: fog, seed: seed)
        let shadowRender = SceneRenderer.render(scene: shadowScene, sampleRate: 44_100)
        let fogRender = SceneRenderer.render(scene: fogScene, sampleRate: 44_100)

        #expect(shadowScene.darkness != fogScene.darkness)
        #expect(shadowScene.atmosphericDarkness != fogScene.atmosphericDarkness)
        #expect(shadowRender != fogRender)
        #expect(fogRender.stereoCorrelation < shadowRender.stereoCorrelation)
    }

    @Test("Promoted high settings have bounded, deterministic effects", arguments: [UInt64(42), 48291, 90909])
    func promotedHighSettings(seed: UInt64) {
        var intent = MusicalIntent()
        intent[.atmosphere] = 1
        intent[.atmosphericDarkness] = 1
        intent[.aggression] = 1
        intent[.drumChaos] = 1
        intent[.noteActivity] = 1
        let scene = TechnoScene(intent: intent, seed: seed)
        let repeatScene = TechnoScene(intent: intent, seed: seed)
        let render = SceneRenderer.render(scene: scene, sampleRate: 44_100)

        #expect(scene == repeatScene)
        #expect(scene.motif.count >= 1)
        #expect(render.samples.allSatisfy { $0.isFinite })
        #expect(render.peak <= 0.82)
        #expect(render.stereoCorrelation < 0.99)
    }

    @Test("Rendered audio is deterministic", arguments: [UInt64(42), 48291, 90909])
    func deterministicAudio(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        #expect(SceneRenderer.render(scene: scene, sampleRate: 44_100) == SceneRenderer.render(scene: scene, sampleRate: 44_100))
    }

    @Test("Swing changes the rendered waveform without changing loudness bounds")
    func swingChangesAudio() {
        let comparisons = [UInt64(42), 48291, 90909].map { seed in
            let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
            let straight = SceneRenderer.render(scene: scene, sampleRate: 44_100, applyGroove: false)
            let swung = SceneRenderer.render(scene: scene, sampleRate: 44_100, applyGroove: true)
            let differs = zip(straight.samples, swung.samples).contains { abs($0 - $1) > 0.0001 }
            return (differs, straight.peak, swung.peak)
        }
        #expect(comparisons.contains { $0.0 })
        #expect(comparisons.allSatisfy { $0.1 <= 0.82 && $0.2 <= 0.82 })
    }

    @Test("Motif changes the rendered waveform while remaining subordinate")
    func motifChangesAudio() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let withMotif = SceneRenderer.render(scene: scene, sampleRate: 44_100)
        let withoutMotif = SceneRenderer.render(scene: scene, sampleRate: 44_100, includeMotif: false)
        let differs = zip(withMotif.samples, withoutMotif.samples).contains { abs($0 - $1) > 0.0001 }
        #expect(differs)
        #expect(withMotif.peak <= 0.82)
    }

    @Test("Bass phrase remains deterministic while changing pitch content")
    func bassHasPitchMovement() {
        let first = TechnoScene(seed: 42, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let second = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let firstRender = SceneRenderer.render(scene: first, sampleRate: 44_100)
        let secondRender = SceneRenderer.render(scene: second, sampleRate: 44_100)
        #expect(firstRender != secondRender)
        #expect(firstRender.samples.allSatisfy { $0.isFinite })
        #expect(secondRender.samples.allSatisfy { $0.isFinite })
    }

    @Test("Rendered audio is finite, audible, and conservatively limited")
    func signalSafety() {
        let render = SceneRenderer.render(
            scene: TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74),
            sampleRate: 44_100
        )
        #expect(render.samples.allSatisfy { $0.isFinite })
        #expect(render.peak > 0.1)
        #expect(render.peak <= 0.82)
        #expect(render.leftSamples != render.rightSamples)
        #expect(render.leftSamples.allSatisfy { $0.isFinite })
        #expect(render.rightSamples.allSatisfy { $0.isFinite })
        #expect(render.rms > 0)
        #expect(render.crestFactor >= 1)
        #expect((-1...1).contains(render.stereoCorrelation))
        let sketch = SceneRenderer.render(
            scene: TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74),
            sampleRate: 44_100,
            treatment: .sketch
        )
        #expect(sketch != render)
        #expect(sketch.stereoCorrelation == 1)
    }

    @Test("Bar boundaries return to silence")
    func boundaryContinuity() {
        let render = SceneRenderer.render(
            scene: TechnoScene(seed: 90909, bpm: 130, drive: 0.8, darkness: 0.7, hypnosis: 0.8),
            sampleRate: 48_000
        )
        #expect(abs(render.samples.first ?? 1) < 0.0001)
        #expect(abs(render.samples.last ?? 1) < 0.0001)
    }

    @Test("Section changes the rendered waveform while staying within loudness bounds")
    func sectionChangesAudio() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let groove = SceneRenderer.render(scene: scene, sampleRate: 44_100, section: .groove)
        let breakdown = SceneRenderer.render(scene: scene, sampleRate: 44_100, section: .breakdown)
        let build = SceneRenderer.render(scene: scene, sampleRate: 44_100, section: .build)
        let differs = zip(groove.samples, breakdown.samples).contains { abs($0 - $1) > 0.0001 }
        #expect(differs)
        #expect(breakdown.peak <= groove.peak + 0.001)
        #expect(build.peak <= 0.82)
        #expect(breakdown.peak <= 0.82)
    }

    @Test("Effect state carries ambience across bars")
    func persistentAtmosphereState() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74,
                                atmosphere: 0.85, atmosphericDarkness: 0.35)
        var state = SceneRenderState()
        _ = SceneRenderer.render(scene: scene, sampleRate: 44_100, state: &state)
        #expect(state.hasAtmosphereMemory)
        let second = SceneRenderer.render(scene: scene, sampleRate: 44_100, state: &state)
        let isolated = SceneRenderer.render(scene: scene, sampleRate: 44_100)
        #expect(state.hasAtmosphereMemory)
        #expect(second != isolated)
    }
}

@Suite("Taste learning")
struct TasteModelTests {
    @Test("Taste candidates are deterministic and varied")
    func deterministicCandidates() {
        let profile = TasteProfile()
        let first = TasteSession(sessionSeed: 1234, round: 0, profile: profile)
        let second = TasteSession(sessionSeed: 1234, round: 0, profile: profile)
        #expect(first == second)
        #expect(first.candidates.count == 3)
        #expect(Set(first.candidates.map(\.seed)).count == 3)
        #expect(Set(first.candidates.map { $0.intent[.groove] }).count > 1)
    }

    @Test("Learning updates semantic preferences and survives persistence")
    func learningAndPersistence() {
        let intent = MusicalIntent.random(seed: 42)
        var profile = TasteProfile()
        profile.learn(from: intent)
        #expect(profile.observationCount == 1)
        let data = profile.encoded()
        #expect(data != nil)
        #expect(data.flatMap(TasteProfile.init(encoded:)) == profile)
    }

    @Test("Teaching observations preserve winner and alternatives")
    func observationEvidencePersistence() {
        let session = TasteSession(sessionSeed: 48291, round: 3, profile: TasteProfile())
        var profile = TasteProfile()
        profile.learn(from: session.candidates[1].intent)
        profile.record(observation: TasteObservation(sessionSeed: session.sessionSeed,
                                                     round: session.round,
                                                     selectedIndex: 1,
                                                     candidates: session.candidates))
        #expect(profile.observations.count == 1)
        #expect(profile.observations[0].selectedIndex == 1)
        #expect(profile.observations[0].candidateSeeds == session.candidates.map(\.seed))
        #expect(profile.encoded().flatMap(TasteProfile.init(encoded:)) == profile)
    }

    @Test("Invalid profiles fail safely and version one migrates")
    func persistenceRecovery() {
        let invalid = Data(#"{"version":999,"preferences":{}}"#.utf8)
        #expect(TasteProfile(encoded: invalid) == nil)

        // Swift's synthesized Codable representation for an enum-keyed
        // dictionary is an unkeyed key/value array in the v1 profile.
        let legacy = Data(#"{"version":1,"preferences":[["groove",{"preferredValue":0.72,"confidence":3}]]}"#.utf8)
        let migrated = TasteProfile(encoded: legacy)
        #expect(migrated?.version == TasteProfile.currentVersion)
        #expect(migrated?.preference(for: MusicalControl.groove)?.preferredValue == 0.72)
        #expect(migrated?.observations.isEmpty == true)
    }

    @Test("Reset clears learned taste")
    func reset() {
        var profile = TasteProfile()
        profile.learn(from: MusicalIntent.random(seed: 42))
        profile.reset()
        #expect(profile == TasteProfile())
    }

    @Test("Profile bias moves candidates toward learned values")
    func profileBias() {
        var profile = TasteProfile()
        var preferred = MusicalIntent()
        preferred[.groove] = 0.95
        profile.learn(from: preferred)
        let candidates = TasteSession(sessionSeed: 1234, round: 0, profile: profile).candidates
        #expect(candidates.allSatisfy { $0.profileBias > 0 })
        #expect(candidates.map { $0.intent[.groove] }.reduce(0, +) / 3 > 0.55)
        #expect(candidates.allSatisfy { candidate in
            candidate.intent[.atmosphere] <= candidate.intent[.darkness] + 0.25 &&
                candidate.intent[.aggression] <= max(0.15, 0.85 - candidate.intent[.atmosphere] * 0.5)
        })
    }

    @Test("Semantic mutation is deterministic, bounded, and correlated")
    func semanticMutation() {
        let base = MusicalIntent.random(seed: 48291)
        let first = MusicalIntent.mutated(base, seed: 90909)
        let second = MusicalIntent.mutated(base, seed: 90909)
        #expect(first == second)
        #expect(MusicalControl.allCases.allSatisfy { control in
            (control.minimum...1).contains(first[control])
        })
        #expect(first[.atmosphere] <= first[.darkness] + 0.25)
        #expect(first[.aggression] <= max(0.15, 0.85 - first[.atmosphere] * 0.5))
        #expect(first[.drumChaos] <= first[.overallChaos] + 0.2)
    }

    @Test("Jukebox plan is deterministic and varies around the learned profile")
    func jukeboxPlan() {
        var profile = TasteProfile()
        var preferred = MusicalIntent()
        preferred[.darkness] = 0.9
        preferred[.hypnosis] = 0.86
        profile.learn(from: preferred)
        let first = JukeboxPlan(sessionSeed: 42, profile: profile, sceneCount: 8)
        let second = JukeboxPlan(sessionSeed: 42, profile: profile, sceneCount: 8)
        #expect(first == second)
        #expect(first.scenes.count == 8)
        #expect(Set(first.scenes.map(\.seed)).count == 8)
        #expect(Set(first.scenes.map { $0.intent[.darkness] }).count > 1)
        #expect(first.scenes.allSatisfy { $0.intent[.darkness] >= 0.55 })
    }

    @Test("Jukebox cycles are deterministic but do not repeat")
    func jukeboxCycles() {
        let profile = TasteProfile()
        let first = JukeboxPlan.cycle(sessionSeed: 48291, cycle: 1, profile: profile)
        let repeatCycle = JukeboxPlan.cycle(sessionSeed: 48291, cycle: 1, profile: profile)
        let next = JukeboxPlan.cycle(sessionSeed: 48291, cycle: 2, profile: profile)
        #expect(first == repeatCycle)
        #expect(first != next)
        #expect(Set(first.scenes.map(\.seed)).isDisjoint(with: Set(next.scenes.map(\.seed))))
    }

    @Test("Jukebox quality report validates bounded taste-centered plans")
    func jukeboxQualityReport() {
        let plan = JukeboxPlan(sessionSeed: 42, profile: TasteProfile())
        let report = JukeboxPlanReport(plan: plan, profile: TasteProfile())
        #expect(report.valid)
        #expect(report.sceneCount == 8)
        #expect(report.uniqueSeedCount == 8)
        #expect(report.maximumNovelty <= 0.28)
        #expect(report.meanTasteDistance >= 0)
    }

    @Test("Long-play validation keeps multiple cycles unique and bounded")
    func jukeboxLongPlayReport() {
        let report = JukeboxLongPlayReport(sessionSeed: 48_291, cycles: 4,
                                           profile: TasteProfile(), sceneCount: 8)
        #expect(report.valid)
        #expect(report.cycleCount == 4)
        #expect(report.totalSceneCount == 32)
        #expect(report.uniqueSeedCount == 32)
        #expect(report.adjacentCycleOverlap == 0)
        #expect(report.maximumNovelty <= 0.28)
    }
}

@Suite("Procedural v2 orchestration")
struct V2ProceduralEngineTests {
    private let seeds: [UInt64] = [42, 48291, 90909]

    @Test("V2 renders a deterministic 32-bar form", arguments: [42, 48291, 90909])
    func deterministic32Bars(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var firstState = V2RenderState()
        var secondState = V2RenderState()
        let first = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &firstState)
        let second = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &secondState)
        #expect(first == second)
        #expect(first.count == 32)
        #expect(first.map(\.bar) == Array(0..<32))
    }

    @Test("V2 form contains contrast and bounded stereo output")
    func structureAndSafety() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var state = V2RenderState()
        let blocks = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &state)
        #expect(blocks.contains { $0.section == .breakdown })
        #expect(blocks.contains { $0.section == .returnSection })
        #expect(blocks.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) })
        #expect(blocks.allSatisfy { $0.peak <= 0.9 })
        #expect(blocks.allSatisfy { (-1...1).contains($0.stereoCorrelation) })
        #expect(Set(blocks.map { $0.events.count }).count > 1)
        #expect(blocks.allSatisfy { $0.busStates[.kick] != nil })
        #expect(blocks.contains { $0.busStates[.bass] != nil })
        #expect(blocks.contains { $0.section != .breakdown && $0.busStates[.synth] != nil })
        #expect(blocks.allSatisfy { $0.busStates.values.allSatisfy { (0...1).contains($0.headroom) && $0.level >= 0 } })
    }

    @Test("V2 reset reproduces the same stateful render")
    func resetReproducibility() {
        let scene = TechnoScene(seed: 90909, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var state = V2RenderState()
        let first = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &state)
        state.reset()
        let second = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &state)
        #expect(first == second)
    }

    @Test("V2 blocks retain the deterministic dramatic thesis")
    func dramaticThesisTelemetry() {
        let scene = TechnoScene(seed: 42, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var state = V2RenderState()
        let blocks = V2ProceduralEngine.renderPersistent32Bars(scene: scene, sampleRate: 8_000, state: &state)
        let expected = PerformancePlan(scene: scene).thesis
        #expect(blocks.allSatisfy { $0.dramaticThesis == expected })
        #expect(blocks.allSatisfy { $0.performance != nil })
    }

    @Test("V2 stereo motion is deterministic and bounded")
    func stereoMotion() {
        let scene = TechnoScene(seed: 42, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var firstState = V2RenderState()
        var secondState = V2RenderState()
        let first = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &firstState)
        let second = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &secondState)
        #expect(first == second)
        #expect(first.allSatisfy { (-1...1).contains($0.stereoCorrelation) })
        #expect(first.contains { abs($0.stereoCorrelation - 1) > 0.0001 })
    }

    @Test("Persistent performance adds restrained tuned and metallic percussion accents")
    func percussionPalette() {
        var intent = MusicalIntent()
        intent[.drumChaos] = 0.42
        intent[.synthPresence] = 0.35
        let scene = TechnoScene(intent: intent, seed: 48291, bpm: 130)
        var state = V2RenderState()
        let blocks = V2ProceduralEngine.renderPersistent32Bars(scene: scene, sampleRate: 44_100, state: &state)
        #expect(blocks.contains { $0.events.contains { $0.voice == .percussion } })
        #expect(blocks.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) && $0.peak <= 0.9 })
    }

    @Test("Pulse sequencer uses a distinct deterministic acid voice")
    func acidSequencerVoice() {
        let pulseIntent = MusicalIntent(values: [.sequencerPresence: 0.8, .sequencerStyle: 0.0])
        let textureIntent = MusicalIntent(values: [.sequencerPresence: 0.8, .sequencerStyle: 1.0])
        let pulse = TechnoScene(intent: pulseIntent, seed: 48291, bpm: 130)
        let texture = TechnoScene(intent: textureIntent, seed: 48291, bpm: 130)
        var pulseState = V2RenderState()
        var textureState = V2RenderState()
        let pulseBlocks = V2ProceduralEngine.render32Bars(scene: pulse, sampleRate: 44_100, state: &pulseState)
        let textureBlocks = V2ProceduralEngine.render32Bars(scene: texture, sampleRate: 44_100, state: &textureState)
        #expect(V2QualityReport(blocks: pulseBlocks).sampleHash != V2QualityReport(blocks: textureBlocks).sampleHash)
        #expect(pulseBlocks.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) && $0.peak <= 0.9 })
    }

    @Test("V2 long modulation lanes stay bounded and deterministic")
    func modulationLanes() {
        let scene = TechnoScene(seed: 90909, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var firstState = V2RenderState()
        var secondState = V2RenderState()
        let first = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &firstState)
        let second = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &secondState)
        #expect(first.map(\.modulation) == second.map(\.modulation))
        #expect(first.allSatisfy {
            let m = $0.modulation
            return (0...1).contains(m.brightness) && (0...1).contains(m.density) &&
                (0...1).contains(m.space) && (0...1).contains(m.cutoff) &&
                (0...1).contains(m.resonance) && (0...1).contains(m.bassArticulation) &&
                (0...1).contains(m.fillIntensity)
        })
        #expect(Set(first.map { $0.modulation.cutoff }).count > 8)
    }

    @Test("V2 quality report is deterministic and safe", arguments: [UInt64(42), 48291, 90909])
    func qualityReport(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var state = V2RenderState()
        let blocks = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &state)
        let report = V2QualityReport(blocks: blocks)
        #expect(report.finite)
        #expect(report.peak <= 0.9)
        #expect(report.truePeakEstimate <= 0.95)
        #expect(report.rms > 0)
        #expect(report.loudnessEstimate.isFinite)
        #expect((-120...0).contains(report.loudnessEstimate))
        #expect(abs(report.dcOffset) < 0.05)
        #expect((-1...1).contains(report.stereoCorrelation))
        #expect(report.lowStereoCorrelation > 0.94)
        #expect(report.maxBoundaryDelta < 0.3)
        #expect(report.sampleHash.count == 16)
    }

    @Test("V2 polished and sketch treatments are deterministic but distinct")
    func treatmentComparison() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var polishedState = V2RenderState()
        var sketchState = V2RenderState()
        let polished = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &polishedState, treatment: .polished)
        let sketch = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &sketchState, treatment: .sketch)
        #expect(V2QualityReport(blocks: polished).sampleHash != V2QualityReport(blocks: sketch).sampleHash)
        #expect(polished.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) })
        #expect(sketch.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) })
    }

    @Test("Mastering profiles are deterministic, distinct, and safe")
    func masteringProfiles() {
        let scene = TechnoScene(seed: 90909, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var clubState = V2RenderState()
        var headroomState = V2RenderState()
        let club = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &clubState, mastering: .clubPunch)
        let headroom = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &headroomState, mastering: .headroomReference)
        #expect(V2QualityReport(blocks: club).sampleHash != V2QualityReport(blocks: headroom).sampleHash)
        #expect(club.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) && $0.truePeakEstimate <= 0.95 })
        #expect(headroom.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) && $0.truePeakEstimate <= 0.95 })
    }

    @Test("Effect profiles are deterministic, distinct, and safe")
    func effectProfiles() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var fullState = V2RenderState()
        var motionState = V2RenderState()
        var dryState = V2RenderState()
        let full = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &fullState, effects: .full)
        let motion = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &motionState, effects: .motionOnly)
        let dry = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &dryState, effects: .dryReference)
        #expect(V2QualityReport(blocks: full).sampleHash != V2QualityReport(blocks: motion).sampleHash)
        #expect(V2QualityReport(blocks: motion).sampleHash != V2QualityReport(blocks: dry).sampleHash)
        for blocks in [full, motion, dry] {
            #expect(blocks.allSatisfy { block in
                block.left.allSatisfy(\.isFinite) && block.right.allSatisfy(\.isFinite)
                    && block.truePeakEstimate <= 0.95
            })
        }
        let dryEffects = dry[8].effects
        #expect(dryEffects.first { $0.kind == .delay }?.active == false)
        #expect(dryEffects.first { $0.kind == .reverb }?.active == false)
        #expect(dryEffects.first { $0.kind == .textureRack }?.active == false)
    }

    @Test("V2 effect telemetry is complete, bounded, and deterministic")
    func effectTelemetry() {
        let scene = TechnoScene(seed: 42, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var firstState = V2RenderState()
        var secondState = V2RenderState()
        let first = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &firstState)
        let second = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 44_100, state: &secondState)
        #expect(first.map(\.effects) == second.map(\.effects))
        #expect(first.allSatisfy { block in
            block.effects.count == 13 && block.effects.allSatisfy { (0...1).contains($0.amount) }
        })
        #expect(first.allSatisfy { $0.effects.contains { $0.kind == .earlyReflection } })
    }

    @Test("Offline stems are deterministic, finite, and role-distinct")
    func offlineStems() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.58, darkness: 0.72, hypnosis: 0.76,
                                atmosphere: 0.4, melodicity: 0.35, synthPresence: 0.4)
        let first = V2ProceduralEngine.renderStems32Bars(scene: scene, sampleRate: 8_000)
        let second = V2ProceduralEngine.renderStems32Bars(scene: scene, sampleRate: 8_000)
        #expect(first == second)
        #expect(Set(first.keys) == Set(V2StemKind.allCases))
        let hashes = first.values.map { V2QualityReport(blocks: $0).sampleHash }
        #expect(Set(hashes).count == V2StemKind.allCases.count)
        #expect(first.values.allSatisfy { blocks in
            blocks.count == 32 && blocks.allSatisfy { $0.left.allSatisfy(\.isFinite) && $0.right.allSatisfy(\.isFinite) }
        })
    }

    @Test("Perceptual quality metrics are finite and normalized")
    func perceptualMetrics() {
        let sampleRate = 8_000.0
        let left = (0..<Int(sampleRate * 4)).map { index in
            Float(sin(2 * Double.pi * 110 * Double(index) / sampleRate) * 0.25)
        }
        let metrics = MusicalQualityMetrics(left: left, right: left, sampleRate: sampleRate)
        #expect(metrics.integratedLoudness.isFinite)
        #expect(metrics.maximumShortTermLoudness.isFinite)
        #expect(metrics.crestFactor > 1)
        #expect(abs(metrics.lowEnergy + metrics.midEnergy + metrics.highEnergy - 1) < 0.0001)
        #expect(metrics.spectralCentroid > 0)
        #expect(metrics.transientDensity >= 0)
    }

    @Test("V2 quality reports use the supplied route sample rate")
    func qualityReportSampleRate() {
        let scene = TechnoScene(seed: 42, bpm: 130, drive: 0.58, darkness: 0.72, hypnosis: 0.76)
        var state = V2RenderState()
        let blocks = V2ProceduralEngine.renderPersistent32Bars(scene: scene, sampleRate: 8_000, state: &state)
        let routeReport = V2QualityReport(blocks: blocks, sampleRate: 8_000)
        let legacyDefault = V2QualityReport(blocks: blocks)
        #expect(routeReport.musical.transientDensity != legacyDefault.musical.transientDensity)
        #expect(routeReport.musical.integratedLoudness.isFinite)
    }

    @Test("Approved v2 and persistent v3 remain separate A/B paths")
    func performanceModelComparison() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.58, darkness: 0.72, hypnosis: 0.76)
        var baselineState = V2RenderState()
        var candidateState = V2RenderState()
        let baseline = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: 8_000, state: &baselineState)
        let candidate = V2ProceduralEngine.renderPersistent32Bars(scene: scene, sampleRate: 8_000, state: &candidateState)
        #expect(baseline.allSatisfy { $0.performance == nil && $0.dramaticThesis == nil })
        #expect(candidate.allSatisfy { $0.performance != nil && $0.dramaticThesis != nil })
        #expect(V2QualityReport(blocks: baseline).sampleHash != V2QualityReport(blocks: candidate).sampleHash)
    }

    @Test("Persistent v3 is deterministic after a state reset")
    func persistentV3Determinism() {
        let scene = TechnoScene(seed: 90909, bpm: 130, drive: 0.58, darkness: 0.72, hypnosis: 0.76)
        var state = V2RenderState()
        let first = V2ProceduralEngine.renderPersistent32Bars(scene: scene, sampleRate: 8_000, state: &state)
        state.reset()
        let second = V2ProceduralEngine.renderPersistent32Bars(scene: scene, sampleRate: 8_000, state: &state)
        #expect(first == second)
        #expect(first.allSatisfy { block in
            block.left.allSatisfy(\.isFinite) && block.right.allSatisfy(\.isFinite) &&
                block.truePeakEstimate <= 0.95
        })
    }

    @Test("Alien timbre and cross-rhythm are isolated A/B/C layers",
          arguments: [UInt64(42), 48291, 90909])
    func alienSynthComparison(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.58, darkness: 0.72,
                                hypnosis: 0.76, atmosphere: 0.34,
                                melodicity: 0.36, synthPresence: 0.46)
        var legacyState = V2RenderState()
        var voiceState = V2RenderState()
        var interlockedState = V2RenderState()
        let legacy = V2ProceduralEngine.renderPersistent32Bars(
            scene: scene, sampleRate: 8_000, state: &legacyState,
            synthEngine: .legacyReference, synthRhythm: .anchorOnly)
        let voice = V2ProceduralEngine.renderPersistent32Bars(
            scene: scene, sampleRate: 8_000, state: &voiceState,
            synthEngine: .alienAnalogV1, synthRhythm: .anchorOnly)
        let interlocked = V2ProceduralEngine.renderPersistent32Bars(
            scene: scene, sampleRate: 8_000, state: &interlockedState,
            synthEngine: .alienAnalogV1, synthRhythm: .interlocked)
        let reports = [legacy, voice, interlocked].map {
            V2QualityReport(blocks: $0, sampleRate: 8_000)
        }
        #expect(Set(reports.map(\.sampleHash)).count == 3)
        #expect(reports.allSatisfy { report in
            report.finite && report.truePeakEstimate <= 0.95 &&
                report.lowStereoCorrelation > 0.94 && abs(report.dcOffset) < 0.05
        })
        let foundation: ([V2RenderBlock]) -> [[V2VoiceEvent]] = { blocks in
            blocks.map { block in
                block.events.filter { $0.voice == .kick || $0.voice == .bass ||
                    $0.voice == .hats || $0.voice == .clap }
            }
        }
        #expect(foundation(legacy) == foundation(voice))
        #expect(foundation(voice) == foundation(interlocked))
        #expect(voice.allSatisfy { $0.synthEngine == .alienAnalogV1 && $0.synthWorld != nil })
        #expect(voice.allSatisfy { $0.synthPerformance?.interlockEvents.isEmpty == true })
        #expect(interlocked.contains { $0.synthPerformance?.interlockEvents.isEmpty == false })
    }

    @Test("Alien runtime resets exactly and exposes bounded mutation evidence")
    func alienResetAndEvidence() {
        let scene = TechnoScene(seed: 90909, bpm: 130, drive: 0.58, darkness: 0.72,
                                hypnosis: 0.76, atmosphere: 0.34,
                                melodicity: 0.36, synthPresence: 0.46)
        var state = V2RenderState()
        let first = V2ProceduralEngine.renderPersistent32Bars(
            scene: scene, sampleRate: 8_000, state: &state)
        state.reset()
        let second = V2ProceduralEngine.renderPersistent32Bars(
            scene: scene, sampleRate: 8_000, state: &state)
        #expect(first == second)
        #expect(first.allSatisfy { block in
            guard let synth = block.synthPerformance else { return false }
            return (0...1).contains(synth.mutationAmount) &&
                block.effects.contains { $0.kind == .alienHarmonics } &&
                block.effects.contains { $0.kind == .feedbackFilter } &&
                block.effects.contains { $0.kind == .unsyncedEcho }
        })
        let gestures = Set(first.compactMap { $0.synthPerformance?.gesture })
        #expect(gestures.contains(.reveal))
        #expect(gestures.contains(.corrode))
        #expect(gestures.contains(.release))
        let performance = PerformancePlan(scene: scene)
        #expect(zip(performance.bars, first).allSatisfy { performanceBar, block in
            performanceBar.section != .breakdown || block.synthPerformance?.gesture == .suspend
        })

        var stemState = V2RenderState()
        let voiceStem = V2ProceduralEngine.render32Bars(
            scene: scene, sampleRate: 8_000, state: &stemState,
            treatment: .polished, mastering: .headroomReference,
            isolatedStem: .musicalVoices, performanceModel: .persistentV3,
            synthEngine: .alienAnalogV1, synthRhythm: .anchorOnly)
        let timbre = TimbreComplexityMetrics(blocks: voiceStem, sampleRate: 8_000)
        #expect(timbre.significantNonFundamentalPartials >= 3)
        #expect(timbre.spectralCentroidRange >= 40)
        #expect(timbre.passesComplexityGuard)
    }

    @Test("Dramatic journey renders a deterministic safe 96-bar candidate")
    func dramaticJourneyRender() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var firstState = V2RenderState()
        var secondState = V2RenderState()
        let first = V2ProceduralEngine.renderDramaticJourney96Bars(
            scene: scene, sampleRate: 8_000, state: &firstState)
        let second = V2ProceduralEngine.renderDramaticJourney96Bars(
            scene: scene, sampleRate: 8_000, state: &secondState)
        #expect(first == second)
        #expect(first.count == DramaticJourneyPlan.barCount)
        #expect(first.map(\.bar) == Array(0..<DramaticJourneyPlan.barCount))
        #expect(first.allSatisfy { block in
            block.performance != nil && block.dramaticJourney != nil && block.instrumentPatch != nil &&
                block.left.allSatisfy(\.isFinite) && block.right.allSatisfy(\.isFinite) &&
                block.truePeakEstimate <= 0.95
        })
        #expect(V2QualityReport(blocks: first, sampleRate: 8_000).finite)
    }

    @Test("The decisive return restores audible foundation contracts")
    func dramaticJourneyPayoffRender() {
        let scene = TechnoScene(seed: 42, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var state = V2RenderState()
        let blocks = V2ProceduralEngine.renderDramaticJourney96Bars(
            scene: scene, sampleRate: 8_000, state: &state)
        let anticipation = blocks[79]
        let payoff = blocks[80]
        #expect(!anticipation.events.contains { $0.voice == .bass })
        #expect(payoff.events.contains { $0.voice == .bass })
        #expect(anticipation.dramaticJourney?.kickPresence ?? 1 < 0.20)
        #expect(payoff.dramaticJourney?.kickPresence == 1)
        #expect(payoff.dramaticJourney?.hasDryImpact == true)
        #expect(anticipation.modulation.space > payoff.modulation.space + 0.60)
        #expect(anticipation.modulation.cutoff > payoff.modulation.cutoff + 0.45)
        #expect(anticipation.modulation.fillIntensity > payoff.modulation.fillIntensity + 0.45)
    }

    @Test("Authored patch is an isolated deterministic A/B layer")
    func dramaticInstrumentComparison() {
        let scene = TechnoScene(seed: 90909, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        var legacyState = V2RenderState()
        var authoredState = V2RenderState()
        let legacy = V2ProceduralEngine.renderDramaticJourney96Bars(
            scene: scene, sampleRate: 8_000, state: &legacyState, instrument: .legacyVoice)
        let authored = V2ProceduralEngine.renderDramaticJourney96Bars(
            scene: scene, sampleRate: 8_000, state: &authoredState, instrument: .authoredPatch)
        #expect(legacy.allSatisfy { $0.instrumentPatch == nil })
        #expect(authored.allSatisfy { $0.instrumentPatch?.family == .shadowPressure })
        #expect(V2QualityReport(blocks: legacy, sampleRate: 8_000).sampleHash !=
                V2QualityReport(blocks: authored, sampleRate: 8_000).sampleHash)
        #expect([legacy, authored].allSatisfy { blocks in
            let report = V2QualityReport(blocks: blocks, sampleRate: 8_000)
            return report.finite && report.truePeakEstimate <= 0.95 && report.lowStereoCorrelation > 0.94
        })
    }
}

@Suite("MVP reference metrics")
struct MVPReferenceTests {
    @Test("Fixed seeds produce finite reference metrics", arguments: [UInt64(42), 48291, 90909])
    func fixedSeedMetrics(seed: UInt64) {
        let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let render = SceneRenderer.render(scene: scene, sampleRate: 44_100, treatment: .polished)
        let metrics = ReferenceMetrics(render)
        #expect(metrics.sampleHash.count == 16)
        #expect(metrics.peak <= 0.9)
        #expect(metrics.truePeakEstimate <= 0.95)
        #expect(metrics.rms > 0)
        #expect(metrics.crestFactor >= 1)
        #expect(abs(metrics.boundaryStart) < 0.001)
        #expect(abs(metrics.boundaryEnd) < 0.01)
    }

    @Test("Reference metrics are deterministic")
    func deterministicReferenceMetrics() {
        let scene = TechnoScene(seed: 48291, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
        let first = ReferenceMetrics(SceneRenderer.render(scene: scene, sampleRate: 44_100, treatment: .polished))
        let second = ReferenceMetrics(SceneRenderer.render(scene: scene, sampleRate: 44_100, treatment: .polished))
        #expect(first == second)
    }
}
