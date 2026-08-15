import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing

@Suite("Score-owned kick syntax")
struct KickSyntaxTests {
    private struct Fixture {
        let state: AutonomousSessionState
        let plan: AutonomousPhrasePlan
    }

    @Test("Paid release withholds two canonical kick bars before recovery")
    func paidReleaseArc() throws {
        let fixture = try #require(eligibleFixture())

        for plan in [fixture.plan] {
            let indexes = try #require(syntaxIndexes(in: plan))
            let baseline = canonicalBaseline(for: plan)

            #expect(plan.kind == .energyRelease)
            #expect(plan.startBar == 128)
            #expect(plan.paidDebtIDs == [77])
            #expect(plan.performanceCharacterEvidence.valid)
            #expect(plan.performanceCharacterEvidence.character == .peakDrive ||
                    plan.performanceCharacterEvidence.character == .acidPressure)
            #expect(indexes.setup == 12)
            #expect(indexes.firstWithheld == 13)
            #expect(indexes.secondWithheld == 14)
            #expect(indexes.recovery == 15)
            #expect(plan.resolvedBars[indexes.setup].performance.localBar == 12)
            #expect(plan.resolvedBars[indexes.firstWithheld].performance.localBar == 13)
            #expect(plan.resolvedBars[indexes.secondWithheld].performance.localBar == 14)
            #expect(plan.resolvedBars[indexes.recovery].performance.localBar == 15)
            #expect(plan.resolvedBars.enumerated().allSatisfy { index, resolved in
                let expected: KickSyntaxRole
                if index == indexes.firstWithheld || index == indexes.secondWithheld {
                    expected = .withheld
                } else if index == indexes.recovery {
                    expected = .recovery
                } else {
                    expected = .grounded
                }
                return resolved.kickSyntaxRole == expected
            })
            #expect(plan.resolvedBars[indexes.setup].ensemble.events.contains {
                $0.voice == .kick && $0.step == 0
            })

            for index in [indexes.firstWithheld, indexes.secondWithheld] {
                let resolved = plan.resolvedBars[index]
                #expect(WeakSixteenthStage(
                    absoluteBar: resolved.performance.bar
                ) == .pullback)
                #expect(resolved.ensemble.events.allSatisfy { $0.voice != .kick })
                #expect(resolved.ensemble.kickAnchors.isEmpty)
                #expect(resolved.groovePulses.map(\.step) ==
                        KickSyntaxResolver.canonicalWeakPulseSteps)
                #expect(resolved.ensemble.events.contains { $0.voice == .motif })
                #expect(!resolved.ensemble.events.contains {
                    $0.voice != .kick && $0.step == 0
                })
                #expect(resolved.foundationCompanion == .bass)
                #expect(resolved.foundationBehavior.companion == .bass)
                #expect(resolved.performanceCharacter ==
                        plan.performanceCharacterEvidence.character)
                #expect(resolved.closedHatDecayArticulations ==
                        ClosedHatDecayResolver.articulations(from: resolved.ensemble))
            }

            let recovery = plan.resolvedBars[indexes.recovery]
            #expect(recovery.performance.signatureEvent == .displacedKickRecovery)
            #expect(recovery.ensemble.events.contains {
                $0.voice == .kick && $0.step == 0
            })
            #expect(zip(plan.resolvedBars, baseline).allSatisfy { actual, original in
                actual.ensemble.events.filter { $0.voice != .kick } ==
                    original.ensemble.events.filter { $0.voice != .kick } &&
                    actual.performanceCharacter == original.performanceCharacter &&
                    actual.foundationBehavior == original.foundationBehavior
            })
            let baselineInterest = PhraseInterestEvaluator.evaluate(
                resolvedBars: baseline,
                kind: plan.kind,
                memory: fixture.state.memory,
                identityPreserved: plan.scene.seed == fixture.state.identitySeed
            )
            let expectedPulseClarity =
                Double(plan.barCount - 2) / Double(plan.barCount)
            #expect(abs(plan.interest.pulseClarity - expectedPulseClarity) < 0.000_000_001)
            #expect(plan.interest.intentionalSpace > baselineInterest.intentionalSpace)
            #expect(plan.interest.overactivityPenalty <= baselineInterest.overactivityPenalty)
            #expect(plan.interest.valid)
        }
    }

    @Test("Debt gates syntax while rumble DNA resolves the canonical bass arc")
    func neutralGates() throws {
        let fixture = try #require(eligibleFixture())
        let primary = fixture.plan
        let baseline = canonicalBaseline(for: primary)

        let noDebtState = releaseState(seed: fixture.state.rootSeed, withDebt: false)
        let noDebt = AutonomousSessionDirector(rootSeed: noDebtState.rootSeed)
            .plan(from: noDebtState)
        #expect(noDebt.kind == .energyRelease)
        #expect(noDebt.paidDebtIDs.isEmpty)
        #expect(noDebt.resolvedBars.allSatisfy {
            $0.kickSyntaxRole == .grounded
        })

        let marker = try #require(baseline.firstIndex {
            $0.arrangementGesture == .structuralMarker
        })
        let shortSource = Array(baseline[(marker - 2)...marker])
        let shortSetup = shortSource.enumerated().map { index, resolved in
            let source = resolved.performance
            return replacingBar(
                resolved,
                performance: PerformanceBar(
                    bar: source.bar,
                    phrase: source.phrase,
                    localBar: index,
                    phraseLength: shortSource.count,
                    section: source.section,
                    tension: source.tension,
                    roles: source.roles,
                    transformations: source.transformations,
                    signatureEvent: source.signatureEvent,
                    eventSeed: source.eventSeed,
                    accentContour: source.accentContour
                )
            )
        }
        let earlyMarker = KickSyntaxResolver.resolve(
            resolvedBars: shortSetup,
            kind: .energyRelease,
            paidDebtIDs: primary.paidDebtIDs
        )
        #expect(earlyMarker == shortSetup)
        #expect(earlyMarker.allSatisfy { $0.kickSyntaxRole == .grounded })

        let monoFixture = try #require(monoRumbleFixture())
        let monoPlan = monoFixture.plan
        #expect(monoPlan.dna.foundationCompanion == .monoRumble)
        #expect(monoPlan.resolvedBars.allSatisfy {
            $0.foundationCompanion == .bass &&
                $0.foundationBehavior.companion == .bass
        })
        #expect(syntaxIndexes(in: monoPlan) != nil)
    }

    @Test("Preflight rejects forged syntax roles and arbitrary kick deletion")
    func preflightRejectsTampering() throws {
        let fixture = try #require(eligibleFixture())
        let source = fixture.plan
        let indexes = try #require(syntaxIndexes(in: source))

        let prepared = try #require(preflight(
            fixture.plan,
            state: fixture.state
        ))
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.selectedCandidateEvidence.isComplete)
        let selectedAttemptIndex = try #require(
            prepared.candidateEvaluation.selectedAttemptIndex
        )
        let selectedAttempt = prepared.candidateEvaluation.attempts[
            selectedAttemptIndex
        ]
        #expect(selectedAttempt.evidenceComplete)
        #expect(selectedAttempt.reasonCodes.isEmpty)
        #expect(selectedAttempt.vector == prepared.selectedCandidateEvidence)

        let selectedSynth = SynthPerformancePlan(
            scene: source.scene,
            dna: source.dna,
            kind: source.kind,
            resolvedBars: source.resolvedBars
        )
        let expansionIndex = try #require(selectedSynth.bars.firstIndex {
            $0.tonalEnvelopeExpansionEligible
        })
        let expansion = try #require(
            prepared.selectedCandidateEvidence.instruments[expansionIndex]
                .architectures.first {
                    $0.architecture == InstrumentArchitecture.tonalMotion.rawValue
                }?.tonalEnvelopeExpansion
        )
        #expect(expansion.eligible && expansion.active)
        #expect(expansion.eventCount == 1)
        #expect(expansion.relation == UpperEnvelopeRelation.sustainedWash.rawValue)
        #expect(expansion.appliedSustain > expansion.baseSustain)
        #expect(expansion.appliedReleaseSeconds > expansion.baseReleaseSeconds)
        #expect(expansion.peak > 0 && expansion.rms > 0)
        #expect(expansion.attackRMS > 0 && expansion.tailRMS > 0)
        #expect(expansion.nonzeroSampleCount > 0)
        #expect(expansion.bindingValid && expansion.isFinite)
        #expect(expansion.isComplete(
            architectureEventCount: prepared.selectedCandidateEvidence
                .instruments[expansionIndex].architectures.first {
                    $0.architecture == InstrumentArchitecture.tonalMotion.rawValue
                }?.eventCount ?? 0,
            sampleRate: 8_000
        ))
        let evidence = prepared.selectedCandidateEvidence
        #expect(evidence.planFingerprint ==
                AutonomousCandidateFingerprint.plan(source))
        #expect(evidence.kickSyntax.count == source.resolvedBars.count)
        #expect(evidence.kickSyntax.map(\.bar) ==
                source.resolvedBars.map { $0.performance.bar })
        #expect(evidence.kickSyntax.map(\.role) ==
                source.resolvedBars.map { $0.kickSyntaxRole.rawValue })
        #expect(evidence.kickSyntax.allSatisfy {
            $0.detectorToAudibleScaleMatches && $0.renderPassesMatch &&
                $0.bindingValid
        })
        #expect(evidence.climaxArc.relation ==
                AutonomousClimaxArcRelation.dramaticDebtRecovery.rawValue)
        #expect(evidence.climaxArc.paidDebtCount ==
                fixture.state.memory.openDebts.count)
        #expect(evidence.climaxArc.contrastDebtCount == 1)
        #expect(evidence.climaxArc.majorBreakDebtCount == 0)
        #expect(evidence.climaxArc.earliestOpenedAtBar == 96)
        #expect(evidence.climaxArc.latestOpenedAtBar == 96)
        #expect(evidence.climaxArc.latestDueByBar == 224)
        #expect(evidence.climaxArc.setupBar ==
                source.resolvedBars[indexes.setup].performance.bar)
        #expect(evidence.climaxArc.firstWithheldBar ==
                source.resolvedBars[indexes.firstWithheld].performance.bar)
        #expect(evidence.climaxArc.secondWithheldBar ==
                source.resolvedBars[indexes.secondWithheld].performance.bar)
        #expect(evidence.climaxArc.recoveryBar ==
                source.resolvedBars[indexes.recovery].performance.bar)
        #expect(evidence.climaxArc.bindingValid)
        #expect(evidence.climaxArc.isComplete(
            phraseKind: evidence.symbolic.phraseKind,
            startBar: evidence.symbolic.startBar,
            declaredBarCount: evidence.symbolic.declaredBarCount,
            kickSyntax: evidence.kickSyntax
        ))

        for index in [indexes.firstWithheld, indexes.secondWithheld] {
            let syntax = evidence.kickSyntax[index]
            let zeroHash = AutonomousKickSyntaxBarEvidence.zeroSampleHash(
                renderedFrameCount: syntax.renderedFrameCount
            )
            let kickStem = try #require(evidence.stems[index].roles.first {
                $0.role == MixRole.kick.rawValue
            })
            #expect(syntax.role == KickSyntaxRole.withheld.rawValue)
            #expect(syntax.scoreKickEventCount == 0)
            #expect(syntax.renderedKickEventCount == 0)
            #expect(syntax.scoreKickStepMask == 0)
            #expect(syntax.renderedKickStepMask == 0)
            #expect(syntax.detectorSampleHash == zeroHash)
            #expect(syntax.audibleSampleHash == zeroHash)
            #expect(syntax.detectorPeak.bitPattern == 0)
            #expect(syntax.detectorRMS.bitPattern == 0)
            #expect(syntax.audiblePeak.bitPattern == 0)
            #expect(syntax.audibleRMS.bitPattern == 0)
            #expect(kickStem.peak.bitPattern == 0)
            #expect(kickStem.rms.bitPattern == 0)
            #expect(evidence.groovePulse[index].events.map(\.step) ==
                    KickSyntaxResolver.canonicalWeakPulseSteps)
            #expect(evidence.groovePulse[index].events.allSatisfy {
                $0.sourceRMS > 0 && $0.finite
            })
            #expect(evidence.instruments[index].architectures.contains {
                $0.assignments.contains { $0.use == InstrumentUse.motif.rawValue }
            })
        }

        let recovery = evidence.kickSyntax[indexes.recovery]
        #expect(recovery.role == KickSyntaxRole.recovery.rawValue)
        #expect(recovery.scoreKickEventCount > 0)
        #expect(recovery.renderedKickEventCount == recovery.scoreKickEventCount)
        #expect(recovery.scoreKickStepMask & 1 == 1)
        #expect(recovery.detectorPeak > 0)
        #expect(recovery.detectorRMS > 0)
        #expect(recovery.audiblePeak > 0)
        #expect(recovery.audibleRMS > 0)

        let noDebtState = releaseState(
            seed: fixture.state.rootSeed,
            withDebt: false
        )
        #expect(preflight(fixture.plan, state: noDebtState) == nil)

        var roleBars = source.resolvedBars
        roleBars[indexes.recovery] = replacingBar(
            roleBars[indexes.recovery],
            kickSyntaxRole: .grounded
        )
        let forgedRole = replacingBars(
            in: source,
            with: roleBars,
            memory: fixture.state.memory
        )
        #expect(AutonomousCandidateFingerprint.plan(forgedRole) !=
                AutonomousCandidateFingerprint.plan(source))
        #expect(preflight(forgedRole, state: fixture.state) == nil)

        let withheld = source.resolvedBars[indexes.firstWithheld]
        let sourcePulse = try #require(withheld.groovePulses.first)
        let forgedPulse = GroovePulseArticulation(
            step: sourcePulse.step,
            pulseClass: sourcePulse.pulseClass,
            stage: sourcePulse.stage,
            intensity: sourcePulse.intensity,
            timingOffsetInSteps: sourcePulse.timingOffsetInSteps == 0 ? 0.01 : 0,
            strikeZone: sourcePulse.strikeZone == .center ? .edge : .center,
            damping: sourcePulse.damping,
            timbreMicrovariation: sourcePulse.timbreMicrovariation
        )
        var forgedPulses = withheld.groovePulses
        forgedPulses[0] = forgedPulse
        var grooveBars = source.resolvedBars
        grooveBars[indexes.firstWithheld] = replacingBar(
            withheld,
            groovePulses: forgedPulses
        )
        let forgedGroove = replacingBars(
            in: source,
            with: grooveBars,
            memory: fixture.state.memory
        )
        #expect(preflight(forgedGroove, state: fixture.state) == nil)

        let groundedIndex = indexes.setup
        let grounded = source.resolvedBars[groundedIndex]
        let removedKick = try #require(grounded.ensemble.events.first {
            $0.voice == .kick
        })
        let forgedEvents = grounded.ensemble.events.filter { $0 != removedKick }
        let forgedAnchors = grounded.ensemble.kickAnchors.filter {
            $0 != removedKick.step
        }
        let forgedEnsemble = EnsembleContext(
            focusRole: grounded.ensemble.focusRole,
            events: forgedEvents,
            kickAnchors: forgedAnchors,
            intentionalPileup: grounded.ensemble.intentionalPileup
        )
        var kickBars = source.resolvedBars
        kickBars[groundedIndex] = replacingBar(
            grounded,
            ensemble: forgedEnsemble
        )
        let forgedKick = replacingBars(
            in: source,
            with: kickBars,
            memory: fixture.state.memory
        )
        #expect(preflight(forgedKick, state: fixture.state) == nil)

        var characterBars = source.resolvedBars
        let syntaxBar = characterBars[indexes.firstWithheld]
        characterBars[indexes.firstWithheld] = ResolvedPerformanceBar(
            performance: syntaxBar.performance,
            ensemble: syntaxBar.ensemble,
            arrangementGesture: syntaxBar.arrangementGesture,
            percussionGear: syntaxBar.percussionGear,
            performanceCharacter: .ambientDrift,
            foundationBehavior: syntaxBar.foundationBehavior,
            foundationCompanion: syntaxBar.foundationCompanion,
            pulseEchoEnabled: syntaxBar.pulseEchoEnabled,
            interlockChapter: syntaxBar.interlockChapter,
            groovePulses: syntaxBar.groovePulses,
            closedHatDecayArticulations: syntaxBar.closedHatDecayArticulations,
            spatialContrast: syntaxBar.spatialContrast,
            narrative: syntaxBar.narrative,
            kickSyntaxRole: syntaxBar.kickSyntaxRole
        )
        let forgedCharacter = replacingBars(
            in: source,
            with: characterBars,
            memory: fixture.state.memory
        )
        #expect(preflight(forgedCharacter, state: fixture.state) == nil)

        let otherCharacter: PerformanceCharacter =
            source.performanceCharacterEvidence.character == .peakDrive
                ? .acidPressure : .peakDrive
        let coherentWrongCharacterBars = recharacteredBars(
            in: source,
            as: otherCharacter
        )
        let coherentWrongCharacter = replacingBars(
            in: source,
            with: coherentWrongCharacterBars,
            memory: fixture.state.memory
        )
        #expect(coherentWrongCharacter.performanceCharacterEvidence.valid)
        #expect(preflight(coherentWrongCharacter, state: fixture.state) == nil)
    }

    private func eligibleFixture() -> Fixture? {
        let preferred: [UInt64] = [48_291, 42, 90_909, 7, 77_777]
        let seeds = preferred + (1...512).map { UInt64($0) }
        for seed in seeds {
            let state = releaseState(seed: seed, withDebt: true)
            let plan = AutonomousSessionDirector(rootSeed: seed)
                .plan(from: state)
            let synth = SynthPerformancePlan(
                scene: plan.scene,
                dna: plan.dna,
                kind: plan.kind,
                resolvedBars: plan.resolvedBars
            )
            if syntaxIndexes(in: plan) != nil,
               synth.bars.contains(where: \.tonalEnvelopeExpansionEligible) {
                return Fixture(state: state, plan: plan)
            }
        }
        return nil
    }

    private func monoRumbleFixture() -> Fixture? {
        let seeds = (1...512).map { UInt64($0) }
        for seed in seeds {
            let state = releaseState(seed: seed, withDebt: true)
            guard state.identityDNA.foundationCompanion == .monoRumble else {
                continue
            }
            let plan = AutonomousSessionDirector(rootSeed: seed)
                .plan(from: state)
            if syntaxIndexes(in: plan) != nil {
                return Fixture(state: state, plan: plan)
            }
        }
        return nil
    }

    private func releaseState(seed: UInt64, withDebt: Bool) -> AutonomousSessionState {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        state.phraseIndex = 12
        state.memory = TemporalMusicalMemory(
            totalBars: 128,
            lastContrastBar: 112,
            lastBreakBar: 96,
            openDebts: withDebt ? [SessionDramaticDebt(
                id: 77,
                openedAtBar: 96,
                dueByBar: 224,
                source: .contrast
            )] : []
        )
        return state
    }

    private func syntaxIndexes(
        in plan: AutonomousPhrasePlan
    ) -> (setup: Int, firstWithheld: Int, secondWithheld: Int, recovery: Int)? {
        guard let recovery = plan.resolvedBars.firstIndex(where: {
            $0.kickSyntaxRole == .recovery
        }), recovery >= 3,
        plan.resolvedBars[recovery - 3].kickSyntaxRole == .grounded,
        plan.resolvedBars[recovery - 2].kickSyntaxRole == .withheld,
        plan.resolvedBars[recovery - 1].kickSyntaxRole == .withheld else {
            return nil
        }
        return (recovery - 3, recovery - 2, recovery - 1, recovery)
    }

    private func canonicalBaseline(
        for plan: AutonomousPhrasePlan
    ) -> [ResolvedPerformanceBar] {
        plan.resolvedBars.map { resolved in
            let ensemble = AutonomousSessionDirector.ensemblePlan(
                dna: plan.dna,
                bar: resolved.performance,
                focus: resolved.ensemble.focusRole,
                release: plan.kind == .energyRelease,
                kind: plan.kind,
                character: resolved.performanceCharacter,
                foundationBehavior: resolved.foundationBehavior,
                companion: resolved.foundationCompanion,
                gear: resolved.percussionGear,
                gesture: resolved.arrangementGesture
            )
            return ResolvedPerformanceBar(
                performance: resolved.performance,
                ensemble: ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                performanceCharacter: resolved.performanceCharacter,
                foundationBehavior: resolved.foundationBehavior,
                foundationCompanion: resolved.foundationCompanion,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                interlockChapter: resolved.interlockChapter,
                groovePulses: GroovePulseResolver.articulations(
                    from: ensemble,
                    absoluteBar: resolved.performance.bar,
                    swingPercent: plan.dna.rhythm.swingPercent,
                    percussionGear: resolved.percussionGear,
                    eventSeed: resolved.performance.eventSeed
                ),
                closedHatDecayArticulations: ClosedHatDecayResolver.articulations(from: ensemble),
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }
    }

    private func recharacteredBars(
        in plan: AutonomousPhrasePlan,
        as character: PerformanceCharacter
    ) -> [ResolvedPerformanceBar] {
        let baseline = canonicalBaseline(for: plan).map { resolved in
            let behavior = PerformanceCharacterContract.foundationBehavior(
                for: character,
                gesture: resolved.arrangementGesture,
                localBar: resolved.performance.localBar,
                phraseLength: resolved.performance.phraseLength
            )
            let ensemble = AutonomousSessionDirector.ensemblePlan(
                dna: plan.dna,
                bar: resolved.performance,
                focus: resolved.ensemble.focusRole,
                release: plan.kind == .energyRelease,
                kind: plan.kind,
                character: character,
                foundationBehavior: behavior,
                companion: behavior.companion,
                gear: resolved.percussionGear,
                gesture: resolved.arrangementGesture
            )
            return ResolvedPerformanceBar(
                performance: resolved.performance,
                ensemble: ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                performanceCharacter: character,
                foundationBehavior: behavior,
                foundationCompanion: behavior.companion,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                interlockChapter: resolved.interlockChapter,
                groovePulses: GroovePulseResolver.articulations(
                    from: ensemble,
                    absoluteBar: resolved.performance.bar,
                    swingPercent: plan.dna.rhythm.swingPercent,
                    percussionGear: resolved.percussionGear,
                    eventSeed: resolved.performance.eventSeed
                ),
                closedHatDecayArticulations: ClosedHatDecayResolver.articulations(from: ensemble),
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative
            )
        }
        return KickSyntaxResolver.resolve(
            resolvedBars: baseline,
            kind: plan.kind,
            paidDebtIDs: plan.paidDebtIDs
        )
    }

    private func replacingBar(
        _ source: ResolvedPerformanceBar,
        performance: PerformanceBar? = nil,
        ensemble: EnsembleContext? = nil,
        foundationCompanion: FoundationCompanion? = nil,
        groovePulses: [GroovePulseArticulation]? = nil,
        kickSyntaxRole: KickSyntaxRole? = nil
    ) -> ResolvedPerformanceBar {
        let selectedEnsemble = ensemble ?? source.ensemble
        return ResolvedPerformanceBar(
            performance: performance ?? source.performance,
            ensemble: selectedEnsemble,
            arrangementGesture: source.arrangementGesture,
            percussionGear: source.percussionGear,
            performanceCharacter: source.performanceCharacter,
            foundationBehavior: source.foundationBehavior,
            foundationCompanion: foundationCompanion ?? source.foundationCompanion,
            pulseEchoEnabled: source.pulseEchoEnabled,
            interlockChapter: source.interlockChapter,
            groovePulses: groovePulses ?? source.groovePulses,
            closedHatDecayArticulations: ClosedHatDecayResolver.articulations(
                from: selectedEnsemble
            ),
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: kickSyntaxRole ?? source.kickSyntaxRole
        )
    }

    private func replacingBars(
        in plan: AutonomousPhrasePlan,
        with resolvedBars: [ResolvedPerformanceBar],
        memory: TemporalMusicalMemory
    ) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            barCount: plan.barCount,
            kind: plan.kind,
            scene: plan.scene,
            dna: plan.dna,
            resolvedBars: resolvedBars,
            openedDebt: plan.openedDebt,
            paidDebtIDs: plan.paidDebtIDs,
            requestsTopologyMutation: plan.requestsTopologyMutation,
            interest: PhraseInterestEvaluator.evaluate(
                resolvedBars: resolvedBars,
                kind: plan.kind,
                memory: memory,
                identityPreserved: plan.scene.seed == plan.dna.sceneSeed
            ),
            endingInterlockState: plan.endingInterlockState,
            endingSpatialContrastState: plan.endingSpatialContrastState,
            endingNarrativeState: plan.endingNarrativeState,
            harmonicContinuation: plan.incomingHarmonicContinuation
        )
    }

    private func preflight(
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
