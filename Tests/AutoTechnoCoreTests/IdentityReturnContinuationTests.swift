import AutoTechnoCore
import Testing

@Suite("Identity-return narrative continuation")
struct IdentityReturnContinuationTests {
    @Test("Percussion restoration starts after the identity-return macro boundary")
    func percussionRestorationIsOutgoingState() {
        let director = AutonomousSessionDirector()
        var canonicalState = director.initialState()
        var identityInput: AutonomousSessionState?

        for _ in 0..<80 {
            let plan = director.plan(from: canonicalState)
            if plan.kind == .identityReturn,
               plan.startBar == 118,
               plan.resolvedBars.last?.performance.bar == 127 {
                identityInput = canonicalState
                break
            }
            canonicalState.advance(using: plan)
        }

        guard var state = identityInput else {
            Issue.record("Expected the canonical identity return at bars 118...127")
            return
        }

        let sourceMemory = state.memory
        let incomingNarrative = NarrativeEvolutionState(
            protagonistPresence: sourceMemory.narrativeEvolution.protagonistPresence,
            activeSupportingRoles: [.atmosphere],
            releaseSettlementPending: sourceMemory.narrativeEvolution.releaseSettlementPending
        )
        state = AutonomousSessionState(
            rootSeed: state.rootSeed,
            phraseIndex: state.phraseIndex,
            intent: state.intent,
            memory: TemporalMusicalMemory(
                recentBars: sourceMemory.recentBars,
                currentPhrase: sourceMemory.currentPhrase,
                previousPhrase: sourceMemory.previousPhrase,
                dramaticArc: sourceMemory.dramaticArc,
                sessionBars: sourceMemory.sessionBars,
                totalBars: sourceMemory.totalBars,
                lastContrastBar: sourceMemory.lastContrastBar,
                lastBreakBar: sourceMemory.lastBreakBar,
                lastReleaseBar: sourceMemory.lastReleaseBar,
                lastIdentityReturnBar: sourceMemory.lastIdentityReturnBar,
                topologyRevision: sourceMemory.topologyRevision,
                openDebts: sourceMemory.openDebts,
                interlockEvolution: sourceMemory.interlockEvolution,
                spatialContrast: sourceMemory.spatialContrast,
                narrativeEvolution: incomingNarrative
            )
        )

        let identity = director.plan(from: state)
        guard let finalIdentityBar = identity.resolvedBars.last else {
            Issue.record("Expected a resolved identity-return bar")
            return
        }
        #expect(identity.kind == .identityReturn)
        #expect(finalIdentityBar.performance.bar == 127)
        #expect(finalIdentityBar.arrangementGesture == .structuralMarker)
        #expect(!finalIdentityBar.narrative.activeSupportingRoles.contains(.percussion))
        #expect(!finalIdentityBar.performance.roles.contains(.percussion))
        #expect(!finalIdentityBar.ensemble.events.contains {
            $0.voice.role == .percussion
        })
        #expect(Set(identity.endingNarrativeState.activeSupportingRoles) ==
                Set(finalIdentityBar.narrative.activeSupportingRoles + [.percussion]))

        state.advance(using: identity)
        #expect(state.memory.narrativeEvolution == identity.endingNarrativeState)

        let next = director.plan(from: state)
        guard let firstNextMacroBar = next.resolvedBars.first else {
            Issue.record("Expected the next macro to contain a resolved bar")
            return
        }
        #expect(next.kind == .lock)
        #expect(firstNextMacroBar.performance.bar == 128)
        #expect(firstNextMacroBar.narrative.activeSupportingRoles.contains(.percussion))
        #expect(firstNextMacroBar.performance.roles.contains(.percussion))
        #expect(firstNextMacroBar.ensemble.events.contains {
            $0.voice.role == .percussion
        })
    }
}
