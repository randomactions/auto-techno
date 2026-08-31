import AutoTechnoCore
import Foundation
import Testing

@Suite("Long-horizon polymetric grammar")
struct LongHorizonPolymetricGrammarTests {
    @Test("World-seeded grammar is deterministic and recurs only in the bounded full cycle")
    func deterministicBoundedCycle() throws {
        for seed in [UInt64(7), 48_291] {
            let grammar = LongHorizonPolymetricGrammarResolver.make(
                worldSeed: seed,
                activationBar: 37
            )
            #expect(grammar == LongHorizonPolymetricGrammarResolver.make(
                worldSeed: seed,
                activationBar: 37
            ))
            #expect(grammar.isValid)
            #expect(grammar.combinedPeriodInBars >= 64)
            #expect(grammar.combinedPeriodInBars <= 128)

            let period = grammar.combinedPeriodInSteps
            for lane in LongHorizonPolymetricLane.allCases {
                for offset in 0..<period {
                    #expect(
                        hit(grammar, lane: lane, offset: offset) ==
                            hit(grammar, lane: lane, offset: offset + period)
                    )
                }
            }
            for divisor in properDivisors(of: period) {
                #expect(LongHorizonPolymetricLane.allCases.contains { lane in
                    (0..<period).contains { offset in
                        hit(grammar, lane: lane, offset: offset) !=
                            hit(grammar, lane: lane, offset: offset + divisor)
                    }
                })
            }
        }
    }

    @Test("Activation origin is lineage and phase does not depend on replay order")
    func absoluteActivationPhase() {
        let first = LongHorizonMaterialWorldResolver.make(
            rootSeed: 913,
            episodeID: 4,
            operatorKind: .maintain,
            parent: nil,
            recallSource: nil,
            recentFingerprints: [],
            activationBar: 96
        )
        let shifted = LongHorizonMaterialWorldResolver.make(
            rootSeed: 913,
            episodeID: 4,
            operatorKind: .maintain,
            parent: nil,
            recallSource: nil,
            recentFingerprints: [],
            activationBar: 97
        )
        #expect(first.fingerprint != shifted.fingerprint)
        #expect(first.polymetricGrammar.activationBar == 96)
        #expect(shifted.polymetricGrammar.activationBar == 97)

        let grammar = first.polymetricGrammar
        let reference = LongHorizonPolymetricLane.allCases.map {
            grammar.phase(for: $0, absoluteBar: 137)
        }
        _ = grammar.phase(for: .anchorShadow, absoluteBar: 104)
        _ = grammar.phase(for: .nonFoundationPercussion, absoluteBar: 251)
        #expect(reference == LongHorizonPolymetricLane.allCases.map {
            grammar.phase(for: $0, absoluteBar: 137)
        })
    }

    @Test("Percussion relocation preserves event count and protected score exactly")
    func percussionRelocationContract() {
        let grammar = LongHorizonPolymetricGrammarResolver.make(
            worldSeed: 48_291,
            activationBar: 32
        )
        let source = EnsembleContext(
            focusRole: .percussion,
            events: [
                event(.kick, 0, 1), event(.bass, 4, 0.8),
                event(.rumble, 8, 0.7), event(.tunedTom, 12, 0.6),
                event(.percussion, 1, 0.5), event(.clap, 5, 0.55),
                event(.openHat, 9, 0.45), event(.metallic, 13, 0.4),
            ],
            kickAnchors: [0],
            intentionalPileup: false
        )
        let result = LongHorizonPolymetricGrammarResolver.relocatePercussion(
            ensemble: source,
            grammar: grammar,
            absoluteBar: 41
        )
        #expect(result.ensemble.events.count == source.events.count)
        #expect(result.evidence.eventCount == 4)
        #expect(result.evidence.protectedEventsEqual)
        #expect(result.evidence.combinedPeriodInSteps == grammar.combinedPeriodInSteps)
        #expect(result.ensemble.kickAnchors == source.kickAnchors)
        #expect(result.ensemble.events.filter(isProtected) == source.events.filter(isProtected))
        #expect(result.ensemble.events.filter(isEligible).allSatisfy { event in
            grammar.contains(
                lane: .nonFoundationPercussion,
                absoluteBar: 41,
                step: event.step
            )
        })
        #expect(LongHorizonPolymetricGrammarResolver.relocatePercussion(
            ensemble: source,
            grammar: .neutral,
            absoluteBar: 41
        ).ensemble == source)
    }

    @Test("Occupancy exhaustion retains the original onset and reports fallback")
    func boundedCollisionFallback() {
        let protected = (0..<16).map { event(.kick, $0, 0.6) }
        let source = EnsembleContext(
            focusRole: .percussion,
            events: protected + [event(.percussion, 3, 0.5)],
            kickAnchors: Array(0..<16),
            intentionalPileup: true
        )
        let result = LongHorizonPolymetricGrammarResolver.relocatePercussion(
            ensemble: source,
            grammar: LongHorizonPolymetricGrammarResolver.make(
                worldSeed: 99,
                activationBar: 0
            ),
            absoluteBar: 0
        )
        #expect(result.ensemble == source)
        #expect(result.evidence.collisionFallbackCount == 1)
        #expect(result.evidence.relocatedEventCount == 0)
        #expect(result.evidence.protectedEventsEqual)
    }

    @Test("Interest coverage follows final polymetric pulse geometry")
    func finalPulseGeometryOwnsInterestCoverage() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        let fixture = try #require((0..<64).lazy.compactMap { _ -> (
            plan: AutonomousPhrasePlan,
            bar: ResolvedPerformanceBar,
            memory: TemporalMusicalMemory
        )? in
            let plan = director.plan(from: state)
            defer { state.advancePlanning(using: plan) }
            guard let bar = plan.resolvedBars.first(where: { resolved in
                guard (resolved.percussionPolymetricEvidence?
                    .relocatedEventCount ?? 0) > 0,
                    !resolved.groovePulses.isEmpty else {
                    return false
                }
                let expectedCount = GroovePulseResolver.pattern(
                    stage: WeakSixteenthStage(
                        absoluteBar: resolved.performance.bar
                    ),
                    gesture: resolved.arrangementGesture,
                    macroEnding: (resolved.performance.bar + 1).isMultiple(of: 16)
                ).count
                return resolved.groovePulses.count == expectedCount
            }) else {
                return nil
            }
            return (plan, bar, state.memory)
        }.first)
        let report = PhraseInterestEvaluator.evaluate(
            resolvedBars: [fixture.bar],
            kind: fixture.plan.kind,
            memory: fixture.memory,
            identityPreserved: true
        )
        #expect(report.weakPositionCoverage == 1)
    }

    @Test("Upper relocation keeps slide chains atomic and preserves every non-onset attribute")
    func atomicUpperSlideChains() throws {
        let grammar = LongHorizonPolymetricGrammarResolver.make(
            worldSeed: 17,
            activationBar: 0
        )
        let source = [
            note(.anchor, 0, .retrigger, 1.0),
            note(.anchor, 1, .slide, 1.125),
            note(.response, 5, .retrigger, 1.5),
        ]
        let result = try #require((0..<64).lazy.map { bar in
            LongHorizonPolymetricGrammarResolver.relocateUpperNotes(
                source,
                grammar: grammar,
                absoluteBar: bar
            )
        }.first { resolved in
            resolved.notes.map(\.onsetStep) != source.map(\.onsetStep)
        })
        #expect(result.notes.count == source.count)
        #expect(
            result.notes[1].onsetStep - result.notes[0].onsetStep ==
                source[1].onsetStep - source[0].onsetStep
        )
        for index in source.indices {
            #expect(result.notes[index].withOnsetStep(source[index].onsetStep) == source[index])
        }
        let renderProjection = SynthPerformanceBar(
            bar: 0,
            gesture: .interlock,
            mutationAmount: 0.4,
            relationalSteps: Array(repeating: .neutral, count: 16),
            sourceUpperNotes: source,
            upperNotes: result.notes
        )
        for index in source.indices {
            #expect(renderProjection.sourceUpperStep(
                for: result.notes[index].role,
                appliedStep: result.notes[index].onsetStep
            ) == source[index].onsetStep)
        }
        #expect(result.evidence.map(\.eventCount).reduce(0, +) == source.count)
        #expect(result.evidence.contains { $0.relocatedEventCount > 0 })
        #expect(LongHorizonPolymetricGrammarResolver.relocateUpperNotes(
            source,
            grammar: .neutral,
            absoluteBar: 12
        ).notes == source)
    }

    private func hit(
        _ grammar: LongHorizonPolymetricGrammar,
        lane: LongHorizonPolymetricLane,
        offset: Int
    ) -> Bool {
        grammar.contains(
            lane: lane,
            absoluteBar: grammar.activationBar + offset / 16,
            step: offset % 16
        )
    }

    private func properDivisors(of value: Int) -> [Int] {
        (1..<value).filter { value % $0 == 0 }
    }

    private func event(
        _ voice: EnsembleVoice,
        _ step: Int,
        _ intensity: Double
    ) -> EnsembleResolvedEvent {
        EnsembleResolvedEvent(
            voice: voice,
            step: step,
            intensity: intensity,
            relocated: false
        )
    }

    private func isEligible(_ event: EnsembleResolvedEvent) -> Bool {
        [.percussion, .clap, .openHat, .metallic, .groovePulse].contains(event.voice)
    }

    private func isProtected(_ event: EnsembleResolvedEvent) -> Bool {
        !isEligible(event)
    }

    private func note(
        _ role: SynthRole,
        _ step: Int,
        _ gate: UpperNoteGate,
        _ ratio: Double
    ) -> ResolvedUpperNote {
        ResolvedUpperNote(
            role: role,
            onsetStep: step,
            durationInSteps: 1.75,
            startFrequencyRatio: ratio,
            endFrequencyRatio: ratio * 1.01,
            velocity: 0.73,
            gate: gate,
            timbreIntent: .detunedMotion(amount: 0.4),
            timingOffsetInSteps: 0.03
        )
    }
}
