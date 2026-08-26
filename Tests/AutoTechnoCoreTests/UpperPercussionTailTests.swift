import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing
import XCTest

@Suite("Score-owned upper-percussion tail")
struct UpperPercussionTailTests {
    fileprivate func forgedPreflightResults() -> (
        baselineAccepted: Bool,
        forgedRejected: [Bool]
    )? {
        guard let fixture = fingerprintFixture() else { return nil }
        let baselineAccepted = prepare(
            fixture.plan,
            state: fixture.state
        ) != nil

        let sourceBar = fixture.plan.resolvedBars[fixture.barIndex]
        guard let source = sourceBar.upperPercussionTailArticulations.first
        else { return nil }
        let missing = Array(
            sourceBar.upperPercussionTailArticulations.dropFirst()
        )
        let duplicate = sourceBar.upperPercussionTailArticulations + [source]
        var retargeted = sourceBar.upperPercussionTailArticulations
        retargeted[0] = UpperPercussionTailArticulation(
            scoreEventIndex: source.scoreEventIndex,
            voice: source.voice == .clap ? .openHat : .clap,
            step: source.step,
            role: source.role,
            body: source.voice == .clap ? .native : .clap
        )

        let forgedRejected = [missing, duplicate, retargeted].map {
            forgedArticulations in
            var bars = fixture.plan.resolvedBars
            bars[fixture.barIndex] = replacingBar(
                sourceBar,
                tailArticulations: forgedArticulations
            )
            let forged = replacingBars(in: fixture.plan, with: bars)
            return prepare(forged, state: fixture.state) == nil
        }
        return (baselineAccepted, forgedRejected)
    }

    @Test("Tail role participates in the typed plan identity")
    func planFingerprintIncludesTailRole() throws {
        let fixture = try #require(fingerprintFixture())
        let plan = fixture.plan
        let barIndex = fixture.barIndex
        let sourceBar = plan.resolvedBars[barIndex]
        var changedArticulations = sourceBar.upperPercussionTailArticulations
        let source = changedArticulations[0]
        changedArticulations[0] = UpperPercussionTailArticulation(
            scoreEventIndex: source.scoreEventIndex,
            voice: source.voice,
            step: source.step,
            role: source.role == .naturalBody ?
                .foregroundClearance : .naturalBody,
            body: source.body
        )
        var changedBars = plan.resolvedBars
        changedBars[barIndex] = replacingBar(
            sourceBar,
            tailArticulations: changedArticulations
        )
        let changed = replacingBars(in: plan, with: changedBars)

        #expect(AutonomousCandidateFingerprint.plan(plan) !=
                AutonomousCandidateFingerprint.plan(changed))
    }

    @Test("Director retains the exact post-arbitration policy in every bar")
    func directorOwnsCanonicalArticulations() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        var sawForegroundClearance = false

        for _ in 0..<12 {
            let plan = director.plan(from: state)
            for resolved in plan.resolvedBars {
                let expected = UpperPercussionTailResolver.articulations(
                    from: resolved.ensemble,
                    phraseKind: plan.kind,
                    performanceCharacter: resolved.performanceCharacter
                )
                #expect(resolved.upperPercussionTailArticulations == expected)
                sawForegroundClearance = sawForegroundClearance || expected.contains {
                    $0.role == .foregroundClearance
                }
            }
            state.advancePlanning(using: plan)
        }

        #expect(sawForegroundClearance)
    }

    @Test("Supporting upper percussion resolves bounded foreground clearance")
    func supportingForegroundClearance() {
        let ensemble = context(
            focusRole: .motif,
            events: [
                event(.kick, step: 0),
                event(.clap, step: 4),
                event(.openHat, step: 6),
                event(.metallic, step: 11),
                event(.response, step: 12),
            ]
        )

        let articulations = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .contrast
        )

        #expect(articulations.map(\.scoreEventIndex) == [1, 2, 3])
        #expect(articulations.map(\.voice) == [.clap, .openHat, .metallic])
        #expect(articulations.map(\.step) == [4, 6, 11])
        #expect(articulations.allSatisfy {
            $0.role == .foregroundClearance
        })
    }

    @Test("One clap event resolves contextual clap, snare, and rim bodies")
    func contextualBodyVocabulary() {
        let ensemble = context(
            focusRole: .percussion,
            events: [event(.clap, step: 4), event(.openHat, step: 10)]
        )
        let clap = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .lock,
            performanceCharacter: .hypnoticLock
        )
        let snare = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .energyRelease,
            performanceCharacter: .peakDrive
        )
        let rim = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .majorBreak,
            performanceCharacter: .brokenSuspension
        )
        let identity = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .identityReturn,
            performanceCharacter: .peakDrive
        )

        #expect(clap.map(\.body) == [.clap, .native])
        #expect(snare.map(\.body) == [.snare, .native])
        #expect(rim.map(\.body) == [.rim, .native])
        #expect(identity.map(\.body) == [.clap, .native])
    }

    @Test("Featured, piled-up, and identity material stays natural")
    func neutralPolicyGates() {
        let supporting = context(
            focusRole: .motif,
            events: [event(.clap, step: 5), event(.openHat, step: 9)]
        )
        let percussionFocused = context(
            focusRole: .percussion,
            events: supporting.events
        )
        let piledUp = context(
            focusRole: .motif,
            events: supporting.events,
            intentionalPileup: true
        )

        let cases = [
            UpperPercussionTailResolver.articulations(
                from: percussionFocused,
                phraseKind: .contrast
            ),
            UpperPercussionTailResolver.articulations(
                from: piledUp,
                phraseKind: .contrast
            ),
            UpperPercussionTailResolver.articulations(
                from: supporting,
                phraseKind: .identityReturn
            ),
        ]

        #expect(cases.allSatisfy { articulations in
            articulations.count == 2 && articulations.allSatisfy {
                $0.role == .naturalBody
            }
        })
    }

    @Test("Resolver ignores other voices and is deterministic and bounded")
    func deterministicBoundedProjection() {
        let ensemble = context(
            focusRole: .response,
            events: [
                event(.kick, step: 0),
                event(.clap, step: -1),
                event(.motif, step: 2),
                event(.openHat, step: 17),
                event(.metallic, step: 19),
                event(.clap, step: 21),
                event(.openHat, step: 23),
            ]
        )

        let first = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .lock
        )
        let replay = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .lock
        )

        #expect(first == replay)
        #expect(first.count == UpperPercussionTailResolver.maximumEventCount)
        #expect(first.map(\.scoreEventIndex) == [1, 3, 4, 5])
        #expect(first.map(\.step) == [15, 1, 3, 5])
        #expect(first.allSatisfy { (0...15).contains($0.step) })
    }

    private func context(
        focusRole: PerformanceRole,
        events: [EnsembleResolvedEvent],
        intentionalPileup: Bool = false
    ) -> EnsembleContext {
        EnsembleContext(
            focusRole: focusRole,
            events: events,
            kickAnchors: events.filter { $0.voice == .kick }.map(\.step),
            intentionalPileup: intentionalPileup
        )
    }

    private func event(
        _ voice: EnsembleVoice,
        step: Int,
        intensity: Double = 0.5
    ) -> EnsembleResolvedEvent {
        EnsembleResolvedEvent(
            voice: voice,
            step: step,
            intensity: intensity,
            relocated: false
        )
    }

    private func replacingBar(
        _ source: ResolvedPerformanceBar,
        tailArticulations: [UpperPercussionTailArticulation]
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
            upperPercussionTailArticulations: tailArticulations,
            modalPercussionArticulations: source.modalPercussionArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: source.kickSyntaxRole,
            percussionEchoTexture: source.percussionEchoTexture
        )
    }

    private func replacingBars(
        in plan: AutonomousPhrasePlan,
        with bars: [ResolvedPerformanceBar]
    ) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            barCount: plan.barCount,
            kind: plan.kind,
            scene: plan.scene,
            dna: plan.dna,
            resolvedBars: bars,
            openedDebt: plan.openedDebt,
            paidDebtIDs: plan.paidDebtIDs,
            requestsTopologyMutation: plan.requestsTopologyMutation,
            interest: plan.interest,
            endingInterlockState: plan.endingInterlockState,
            endingSpatialContrastState: plan.endingSpatialContrastState,
            endingNarrativeState: plan.endingNarrativeState,
            harmonicContinuation: plan.incomingHarmonicContinuation
        )
    }

    private func fingerprintFixture() -> (
        state: AutonomousSessionState,
        plan: AutonomousPhrasePlan,
        barIndex: Int
    )? {
        for seed in 1...128 {
            let director = AutonomousSessionDirector(rootSeed: UInt64(seed))
            let state = director.initialState()
            let plan = director.plan(from: state)
            if let barIndex = plan.resolvedBars.firstIndex(where: {
                !$0.upperPercussionTailArticulations.isEmpty
            }) {
                return (state, plan, barIndex)
            }
        }
        return nil
    }

    private func prepare(
        _ plan: AutonomousPhrasePlan,
        state: AutonomousSessionState
    ) -> PreparedAutonomousPhrase? {
        var renderState = RenderState()
        renderState.barIndex = state.memory.totalBars
        return AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: plan,
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 8_000,
            incomingRenderState: renderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: { false }
        )
    }
}

/// Swift Testing executes `@Test` bodies on a bounded cooperative-task stack.
/// This test intentionally prepares four complete canonical transactions, so
/// execute it on XCTest's normal thread while preserving the same assertions.
final class UpperPercussionTailTestsPreflight: XCTestCase {
    func testPreflightRejectsMissingDuplicateAndRetargetedPolicy() throws {
        let results = try XCTUnwrap(
            UpperPercussionTailTests().forgedPreflightResults()
        )
        XCTAssertTrue(results.baselineAccepted)
        XCTAssertEqual(results.forgedRejected, [true, true, true])
    }
}
