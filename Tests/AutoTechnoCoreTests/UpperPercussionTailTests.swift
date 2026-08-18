import AutoTechnoCore
import Testing

@Suite("Score-owned upper-percussion tail")
struct UpperPercussionTailTests {
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
            phraseKind: .contrast,
            conservative: false
        )

        #expect(articulations.map(\.scoreEventIndex) == [1, 2, 3])
        #expect(articulations.map(\.voice) == [.clap, .openHat, .metallic])
        #expect(articulations.map(\.step) == [4, 6, 11])
        #expect(articulations.allSatisfy {
            $0.role == .foregroundClearance
        })
    }

    @Test("Featured, piled-up, conservative, and identity material stays natural")
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
                phraseKind: .contrast,
                conservative: false
            ),
            UpperPercussionTailResolver.articulations(
                from: piledUp,
                phraseKind: .contrast,
                conservative: false
            ),
            UpperPercussionTailResolver.articulations(
                from: supporting,
                phraseKind: .contrast,
                conservative: true
            ),
            UpperPercussionTailResolver.articulations(
                from: supporting,
                phraseKind: .identityReturn,
                conservative: false
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
            phraseKind: .lock,
            conservative: false
        )
        let replay = UpperPercussionTailResolver.articulations(
            from: ensemble,
            phraseKind: .lock,
            conservative: false
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
}
