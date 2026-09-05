import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing
import XCTest

@Suite("Score-owned percussion echo texture")
struct PercussionEchoTextureTests {
    private struct ReleaseFixture {
        let state: AutonomousSessionState
        let plan: AutonomousPhrasePlan
        let firstWithheld: Int
        let secondWithheld: Int
        let recovery: Int
    }

    // Test-local holders keep large value results out of the @Test entry frame.
    // Hosted Swift 6.1.2 requested 692,400 bytes for the combined differential;
    // constructor-only extraction did not reduce that request.
    private final class ProtectedRendererInputs {
        let plan: AutonomousPhrasePlan
        let activeResolved: ResolvedPerformanceBar
        let neutralResolved: ResolvedPerformanceBar
        let activeSynth: SynthPerformancePlan
        let neutralSynth: SynthPerformancePlan

        init(
            plan: AutonomousPhrasePlan,
            activeResolved: ResolvedPerformanceBar,
            neutralResolved: ResolvedPerformanceBar,
            activeSynth: SynthPerformancePlan,
            neutralSynth: SynthPerformancePlan
        ) {
            self.plan = plan
            self.activeResolved = activeResolved
            self.neutralResolved = neutralResolved
            self.activeSynth = activeSynth
            self.neutralSynth = neutralSynth
        }
    }

    private final class ProtectedRendererOutputs {
        let active: RenderedBar
        let neutral: RenderedBar

        init(active: RenderedBar, neutral: RenderedBar) {
            self.active = active
            self.neutral = neutral
        }
    }

    @Test("The director resolves one bounded primary contrast gesture")
    func scoreOwnershipAndReachability() throws {
        let first = try #require(activePlanFixture())
        let second = try #require(activePlanFixture())
        #expect(first.plan == second.plan)
        #expect(first.state == second.state)

        let activeBars = first.plan.resolvedBars.filter {
            $0.percussionEchoTexture?.relation == .gatedEcho
        }
        #expect(!activeBars.isEmpty)
        for resolved in first.plan.resolvedBars {
            let expected = PercussionEchoTextureResolver.articulation(
                ensemble: resolved.ensemble,
                kind: first.plan.kind,
                character: resolved.performanceCharacter,
                gesture: resolved.arrangementGesture,
                absoluteBar: resolved.performance.bar,
                materialWorld: first.plan.materialWorld
            )
            #expect(resolved.percussionEchoTexture == expected)
            if let articulation = resolved.percussionEchoTexture,
               articulation.relation == .gatedEcho
            {
                let source = try #require(
                    PercussionEchoTextureResolver.eligibleSourceEvents(
                        in: resolved.ensemble
                    ).first
                )
                #expect(resolved.performanceCharacter == .brokenSuspension)
                #expect(resolved.arrangementGesture == .gearShift)
                #expect(articulation.inputStep == source.step)
                #expect(articulation.outputStartStep == source.step + 4)
                #expect(articulation.outputEndStep == source.step + 8)
                #expect(articulation.outputEndStep < 16)
            }
        }

        let activeIndex = try #require(first.plan.resolvedBars.firstIndex {
            $0.percussionEchoTexture?.relation == .gatedEcho
        })
        let activeBar = first.plan.resolvedBars[activeIndex]
        var neutralBars = first.plan.resolvedBars
        neutralBars[activeIndex] = replacingTexture(in: activeBar, with: nil)
        let neutralPlan = replacingBars(
            in: first.plan,
            with: neutralBars
        )
        #expect(AutonomousCandidateFingerprint.plan(first.plan) !=
                AutonomousCandidateFingerprint.plan(neutralPlan))
    }

    @Test("The later output gate changes only the protected percussion consequence")
    func protectedRendererDifferential() throws {
        let inputs = try makeProtectedRendererInputs()
        let outputs = Self.renderProtectedRendererOutputs(inputs)
        Self.expectPercussionReturnEvidence(outputs)
        Self.expectProtectedRendererEquality(outputs)
        try Self.expectOutputWindowIsolation(inputs, outputs)
    }

    @inline(never)
    private func makeProtectedRendererInputs() throws -> ProtectedRendererInputs {
        let fixture = try #require(activePlanFixture())
        let plan = fixture.plan
        let index = try #require(plan.resolvedBars.firstIndex {
            $0.percussionEchoTexture?.relation == .gatedEcho
        })
        let activeResolved = plan.resolvedBars[index]
        let neutralResolved = replacingTexture(in: activeResolved, with: nil)
        let activeSynth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [activeResolved]
        )
        let neutralSynth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: [neutralResolved]
        )
        #expect(activeSynth.bars == neutralSynth.bars)

        return ProtectedRendererInputs(
            plan: plan,
            activeResolved: activeResolved,
            neutralResolved: neutralResolved,
            activeSynth: activeSynth,
            neutralSynth: neutralSynth
        )
    }

    @inline(never)
    private static func renderProtectedRendererOutputs(
        _ inputs: ProtectedRendererInputs
    ) -> ProtectedRendererOutputs {
        var activeState = RenderState()
        activeState.barIndex = inputs.activeResolved.performance.bar
        var neutralState = activeState
        var activeWorkspace = RenderWorkspace()
        var neutralWorkspace = RenderWorkspace()
        let active = VoiceRenderer.renderBar(
            scene: inputs.plan.scene,
            sampleRate: 8_000,
            state: &activeState,
            dna: inputs.plan.dna,
            resolved: inputs.activeResolved,
            synthWorld: inputs.activeSynth.world,
            synthPerformance: inputs.activeSynth.bars[0],
            workspace: &activeWorkspace,
            layer: .protectedRhythm
        )
        let neutral = VoiceRenderer.renderBar(
            scene: inputs.plan.scene,
            sampleRate: 8_000,
            state: &neutralState,
            dna: inputs.plan.dna,
            resolved: inputs.neutralResolved,
            synthWorld: inputs.neutralSynth.world,
            synthPerformance: inputs.neutralSynth.bars[0],
            workspace: &neutralWorkspace,
            layer: .protectedRhythm
        )

        return ProtectedRendererOutputs(active: active, neutral: neutral)
    }

    @inline(never)
    private static func expectPercussionReturnEvidence(
        _ outputs: ProtectedRendererOutputs
    ) {
        let active = outputs.active
        let neutral = outputs.neutral
        let evidence = active.percussionEchoTextureRenderEvidence
        #expect(evidence.active)
        #expect(evidence.inputPeak > 0)
        #expect(evidence.inputRMS > 0)
        #expect(evidence.returnPeak > 0)
        #expect(evidence.returnRMS > 0)
        #expect(evidence.returnNonzeroSampleCount > 0)
        #expect(evidence.outOfWindowNonzeroSampleCount == 0)
        #expect(evidence.firstOutputSampleBitPattern & 0x7fff_ffff == 0)
        #expect(evidence.lastOutputSampleBitPattern & 0x7fff_ffff == 0)
        #expect(!neutral.percussionEchoTextureRenderEvidence.active)
    }

    @inline(never)
    private static func expectProtectedRendererEquality(
        _ outputs: ProtectedRendererOutputs
    ) {
        let active = outputs.active
        let neutral = outputs.neutral
        #expect(active.dryPercussionSampleHash == neutral.dryPercussionSampleHash)
        #expect(active.dryFoundationSampleHash == neutral.dryFoundationSampleHash)
        #expect(active.kickMix == neutral.kickMix)
        #expect(active.groovePulseRenderEvidence == neutral.groovePulseRenderEvidence)
        #expect(active.closedHatRenderEvidence == neutral.closedHatRenderEvidence)
    }

    @inline(never)
    private static func expectOutputWindowIsolation(
        _ inputs: ProtectedRendererInputs,
        _ outputs: ProtectedRendererOutputs
    ) throws {
        let active = outputs.active
        let neutral = outputs.neutral
        let activeResolved = inputs.activeResolved
        #expect(active.leftSamples != neutral.leftSamples)
        #expect(active.rightSamples != neutral.rightSamples)

        let articulation = try #require(activeResolved.percussionEchoTexture)
        let outputStartPosition = Double(articulation.outputStartStep) *
            Double(active.leftSamples.count) / 16.0
        let outputStartFrame = Int(outputStartPosition.rounded())
        #expect(Array(active.leftSamples.prefix(outputStartFrame)) ==
                Array(neutral.leftSamples.prefix(outputStartFrame)))
        #expect(Array(active.rightSamples.prefix(outputStartFrame)) ==
                Array(neutral.rightSamples.prefix(outputStartFrame)))
    }

    @Test("The established gated echo remains bit exact")
    func gatedEchoLegacyIdentity() {
        for sampleRate in [8_000.0, 44_100, 48_000, 96_000, 192_000] {
            let frameCount = Int((
                240 / AutonomousSessionDirector.bpm * sampleRate
            ).rounded())
            let articulation = PercussionEchoTextureArticulation(
                relation: .gatedEcho,
                inputStep: 3,
                outputStartStep: 7,
                outputEndStep: 11
            )
            let inputStart = Int((
                Double(articulation.inputStep) * Double(frameCount) / 16
            ).rounded())
            var source = [Float](repeating: 0, count: frameCount)
            source[inputStart + 1] = 0.2
            source[inputStart + max(2, frameCount / 64)] = -0.11
            var actual = [Float](repeating: 0, count: frameCount)
            let evidence = PercussionEchoTextureVoice.render(
                source: source,
                returnStem: &actual,
                articulation: articulation,
                bpm: AutonomousSessionDirector.bpm,
                sampleRate: sampleRate
            )
            let expected = legacyGatedEcho(
                source: source,
                articulation: articulation,
                sampleRate: sampleRate
            )

            #expect(actual == expected)
            #expect(evidence.relation == .gatedEcho)
            #expect(evidence.returnSampleHash ==
                    ExactPCMFingerprint.mono(expected))
        }
    }

    @Test("Preparation rejects a forged input window before rendering")
    func forgedScoreRejected() throws {
        let fixture = try #require(activePlanFixture())
        let activeIndex = try #require(fixture.plan.resolvedBars.firstIndex {
            $0.percussionEchoTexture?.relation == .gatedEcho
        })
        let activeBar = fixture.plan.resolvedBars[activeIndex]
        let articulation = try #require(activeBar.percussionEchoTexture)
        var forgedBars = fixture.plan.resolvedBars
        forgedBars[activeIndex] = replacingTexture(
            in: activeBar,
            with: PercussionEchoTextureArticulation(
                inputStep: articulation.inputStep + 1,
                outputStartStep: articulation.outputStartStep + 1,
                outputEndStep: articulation.outputEndStep + 1
            )
        )
        let forged = replacingBars(
            in: fixture.plan,
            with: forgedBars
        )
        var renderState = RenderState()
        renderState.barIndex = fixture.state.memory.totalBars
        let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: forged,
            sessionSeed: fixture.state.rootSeed,
            memory: fixture.state.memory,
            sampleRate: 8_000,
            incomingRenderState: renderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: fixture.state.quality,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: { false }
        )
        _ = renderState
        #expect(prepared == nil)
    }

    @Test("The final withheld release bar resolves one anticipation swell")
    func anticipationSwellScoreArc() throws {
        let first = try #require(releaseFixture())
        let second = try #require(releaseFixture())
        #expect(first.plan == second.plan)
        #expect(first.state == second.state)

        let active = first.plan.resolvedBars.enumerated().filter {
            $0.element.percussionEchoTexture?.relation == .anticipationSwell
        }
        #expect(active.count == 1)
        #expect(active.first?.offset == first.secondWithheld)
        let bar = try #require(active.first?.element)
        let articulation = try #require(bar.percussionEchoTexture)
        let source = try #require(
            PercussionEchoTextureResolver.eligibleSourceEvents(
                in: bar.ensemble
            ).first
        )
        #expect(bar.kickSyntaxRole == .withheld)
        #expect(bar.performance.localBar == 14)
        #expect(articulation.inputStep == source.step)
        #expect(articulation.outputStartStep == source.step + 1)
        #expect(articulation.outputEndStep == ClimaxHangContract.startStep)
        #expect(bar.climaxHang == ClimaxHangArticulation())
        #expect(first.plan.resolvedBars[first.firstWithheld]
            .percussionEchoTexture == nil)
        #expect(first.plan.resolvedBars[first.recovery]
            .percussionEchoTexture == nil)

        let noDebtState = releaseState(
            seed: first.state.rootSeed,
            withDebt: false
        )
        let noDebt = AutonomousSessionDirector(rootSeed: noDebtState.rootSeed)
            .plan(from: noDebtState)
        #expect(noDebt.resolvedBars.allSatisfy {
            $0.percussionEchoTexture?.relation != .anticipationSwell
        })

        var neutralBars = first.plan.resolvedBars
        neutralBars[first.secondWithheld] = replacingTexture(
            in: bar,
            with: nil
        )
        let neutral = replacingBars(in: first.plan, with: neutralBars)
        #expect(AutonomousCandidateFingerprint.plan(first.plan) !=
                AutonomousCandidateFingerprint.plan(neutral))
    }

    @Test("The anticipation swell rises and closes exactly at every supported route rate")
    func anticipationSwellRateGeometry() {
        for sampleRate in [8_000.0, 44_100, 48_000, 96_000, 192_000] {
            let evidence = renderAnticipationSwell(sampleRate: sampleRate)
            #expect(evidence.active)
            #expect(evidence.relation == .anticipationSwell)
            #expect(evidence.finite)
            #expect(evidence.inputPeak > 0)
            #expect(evidence.returnPeak > 0)
            #expect(evidence.returnRMS > 0)
            #expect(evidence.earlyOutputRMS > 0)
            #expect(evidence.lateOutputRMS > evidence.earlyOutputRMS)
            #expect(evidence.lateToEarlyDB >=
                    PercussionEchoTextureResolver.minimumAnticipationRiseDB)
            #expect(evidence.outOfWindowNonzeroSampleCount == 0)
            #expect(evidence.firstOutputSampleBitPattern & 0x7fff_ffff == 0)
            #expect(evidence.lastOutputSampleBitPattern & 0x7fff_ffff == 0)
        }
    }

    @Test("The anticipation relation changes only the existing percussion return")
    func anticipationSwellProtectedDifferential() throws {
        let fixture = try #require(releaseFixture())
        let activeResolved = fixture.plan.resolvedBars[fixture.secondWithheld]
        let neutralResolved = replacingTexture(in: activeResolved, with: nil)
        let activeSynth = SynthPerformancePlan(
            scene: fixture.plan.scene,
            dna: fixture.plan.dna,
            kind: fixture.plan.kind,
            resolvedBars: [activeResolved]
        )
        let neutralSynth = SynthPerformancePlan(
            scene: fixture.plan.scene,
            dna: fixture.plan.dna,
            kind: fixture.plan.kind,
            resolvedBars: [neutralResolved]
        )
        #expect(activeSynth.bars == neutralSynth.bars)

        var activeState = RenderState()
        activeState.barIndex = activeResolved.performance.bar
        var neutralState = activeState
        var activeWorkspace = RenderWorkspace()
        var neutralWorkspace = RenderWorkspace()
        let active = VoiceRenderer.renderBar(
            scene: fixture.plan.scene,
            sampleRate: 8_000,
            state: &activeState,
            dna: fixture.plan.dna,
            resolved: activeResolved,
            synthWorld: activeSynth.world,
            synthPerformance: activeSynth.bars[0],
            workspace: &activeWorkspace,
            layer: .protectedRhythm
        )
        let neutral = VoiceRenderer.renderBar(
            scene: fixture.plan.scene,
            sampleRate: 8_000,
            state: &neutralState,
            dna: fixture.plan.dna,
            resolved: neutralResolved,
            synthWorld: neutralSynth.world,
            synthPerformance: neutralSynth.bars[0],
            workspace: &neutralWorkspace,
            layer: .protectedRhythm
        )

        let evidence = active.percussionEchoTextureRenderEvidence
        #expect(evidence.relation == .anticipationSwell)
        #expect(evidence.lateOutputRMS > evidence.earlyOutputRMS)
        #expect(!neutral.percussionEchoTextureRenderEvidence.active)
        #expect(active.dryPercussionSampleHash == neutral.dryPercussionSampleHash)
        #expect(active.dryFoundationSampleHash == neutral.dryFoundationSampleHash)
        #expect(active.kickMix == neutral.kickMix)
        #expect(active.groovePulseRenderEvidence == neutral.groovePulseRenderEvidence)
        #expect(active.closedHatRenderEvidence == neutral.closedHatRenderEvidence)
        #expect(active.leftSamples != neutral.leftSamples)
        #expect(active.rightSamples != neutral.rightSamples)

        let articulation = try #require(activeResolved.percussionEchoTexture)
        let outputStartFrame = Int((
            Double(articulation.outputStartStep) *
                Double(active.leftSamples.count) / 16
        ).rounded())
        #expect(Array(active.leftSamples.prefix(outputStartFrame)) ==
                Array(neutral.leftSamples.prefix(outputStartFrame)))
        #expect(Array(active.rightSamples.prefix(outputStartFrame)) ==
                Array(neutral.rightSamples.prefix(outputStartFrame)))
    }

    @MainActor
    @Test("Prepared release retains the anticipation relation and rejects a forged relation")
    func anticipationPreparedEvidenceAndForgery() throws {
        let fixture = try #require(releaseFixture())
        let prepared = try #require(prepare(
            fixture.plan,
            state: fixture.state
        ))
        #expect(prepared.candidateEvaluation.isComplete)
        #expect(prepared.selectedCandidateEvidence.isComplete)
        #expect(prepared.commitEligible)
        let record = prepared.selectedCandidateEvidence
            .percussionEchoTexture[fixture.secondWithheld]
        #expect(record.active)
        #expect(record.relation ==
                PercussionEchoTextureRelation.anticipationSwell.rawValue)
        #expect(record.kickSyntaxRole == KickSyntaxRole.withheld.rawValue)
        #expect(record.lateOutputRMS > record.earlyOutputRMS)
        #expect(record.lateToEarlyDB >=
                PercussionEchoTextureResolver.minimumAnticipationRiseDB)
        #expect(record.isComplete(sampleRate: 8_000, phraseKind: .energyRelease))
        let observation = try ProfessionalQualityObservation(
            candidate: prepared.selectedCandidateEvidence,
            engineVersion: QualityQualificationContract.engineVersion,
            checkpoint: .release
        )
        #expect(observation[
            .percussionAnticipationSwellActiveBarRatio
        ] == 1.0 / Double(fixture.plan.barCount))
        #expect(observation[
            .percussionAnticipationSwellLateToEarlyDBMean
        ] == record.lateToEarlyDB)

        let sourceBar = fixture.plan.resolvedBars[fixture.secondWithheld]
        let source = try #require(sourceBar.percussionEchoTexture)
        var forgedBars = fixture.plan.resolvedBars
        forgedBars[fixture.secondWithheld] = replacingTexture(
            in: sourceBar,
            with: PercussionEchoTextureArticulation(
                relation: .gatedEcho,
                inputStep: source.inputStep,
                outputStartStep: source.outputStartStep,
                outputEndStep: source.outputEndStep
            )
        )
        let forged = replacingBars(in: fixture.plan, with: forgedBars)
        #expect(AutonomousCandidateFingerprint.plan(fixture.plan) !=
                AutonomousCandidateFingerprint.plan(forged))
        #expect(prepare(forged, state: fixture.state) == nil)
    }

    fileprivate func activePlanFixture() -> (
        state: AutonomousSessionState,
        plan: AutonomousPhrasePlan
    )? {
        for seed in UInt64(1)...64 {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var state = director.initialState()
            for _ in 0..<80 {
                let plan = director.plan(from: state)
                if plan.resolvedBars.contains(where: {
                    $0.percussionEchoTexture?.relation == .gatedEcho
                }) {
                    return (state, plan)
                }
                state.advancePlanning(using: plan)
            }
        }
        return nil
    }

    private func releaseFixture() -> ReleaseFixture? {
        let preferred: [UInt64] = [48_291, 42, 90_909, 7, 77_777]
        for seed in preferred + (1...512).map({ UInt64($0) }) {
            let state = releaseState(seed: seed, withDebt: true)
            let plan = AutonomousSessionDirector(rootSeed: seed).plan(from: state)
            guard let recovery = plan.resolvedBars.firstIndex(where: {
                $0.kickSyntaxRole == .recovery
            }), recovery >= 2,
            plan.resolvedBars[recovery - 2].kickSyntaxRole == .withheld,
            plan.resolvedBars[recovery - 1].kickSyntaxRole == .withheld,
            plan.resolvedBars[recovery - 1].percussionEchoTexture?.relation ==
                .anticipationSwell else { continue }
            return ReleaseFixture(
                state: state,
                plan: plan,
                firstWithheld: recovery - 2,
                secondWithheld: recovery - 1,
                recovery: recovery
            )
        }
        return nil
    }

    private func releaseState(
        seed: UInt64,
        withDebt: Bool
    ) -> AutonomousSessionState {
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

    @inline(never)
    private func renderAnticipationSwell(
        sampleRate: Double
    ) -> PercussionEchoTextureRenderEvidence {
        let frameCount = Int((
            240 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded())
        let inputStep = 3
        let inputStart = Int((
            Double(inputStep) * Double(frameCount) / 16
        ).rounded())
        var source = [Float](repeating: 0, count: frameCount)
        if inputStart + 1 < source.count {
            source[inputStart + 1] = 0.2
        }
        var output = [Float](repeating: 0, count: frameCount)
        return PercussionEchoTextureVoice.render(
            source: source,
            returnStem: &output,
            articulation: PercussionEchoTextureArticulation(
                relation: .anticipationSwell,
                inputStep: inputStep,
                outputStartStep: inputStep + 1,
                outputEndStep: ClimaxHangContract.startStep
            ),
            bpm: AutonomousSessionDirector.bpm,
            sampleRate: sampleRate
        )
    }

    /// Independent copy of the pre-anticipation gated-return formula. Keep it
    /// test-local so later renderer refactors must preserve the established PCM
    /// instead of merely agreeing with their own reduced evidence.
    private func legacyGatedEcho(
        source: [Float],
        articulation: PercussionEchoTextureArticulation,
        sampleRate: Double
    ) -> [Float] {
        let frameCount = source.count
        let stepFrames = Double(frameCount) / 16
        func frame(_ step: Int) -> Int {
            min(frameCount, max(0,
                Int((Double(step) * stepFrames).rounded())
            ))
        }
        let inputStartFrame = frame(articulation.inputStep)
        let inputEndFrame = frame(
            articulation.inputStep +
                PercussionEchoTextureResolver.inputWindowLengthInSteps
        )
        let outputStartFrame = frame(articulation.outputStartStep)
        let outputEndFrame = frame(articulation.outputEndStep)
        let delayFrameCount = max(1, Int(stepFrames.rounded()))
        let transitionFrames = PercussionEchoTextureVoice
            .transitionFrameCount(sampleRate: sampleRate)
        let highPassCoefficient = min(
            0.35,
            1 - exp(-2 * .pi * PercussionEchoTextureVoice.highPassHz /
                sampleRate)
        )
        let lowPassCoefficient = min(
            0.55,
            1 - exp(-2 * .pi * PercussionEchoTextureVoice.lowPassHz /
                sampleRate)
        )
        var delay = [Float](repeating: 0, count: delayFrameCount)
        var delayIndex = 0
        var highPassState = 0.0
        var lowPassState = 0.0
        var result = [Float](repeating: 0, count: frameCount)

        for index in 0..<frameCount {
            let read = delay[delayIndex]
            let admittedInput = index >= inputStartFrame &&
                index < inputEndFrame ? source[index] : 0
            delay[delayIndex] = admittedInput + read *
                Float(PercussionEchoTextureVoice.feedback)
            delayIndex = (delayIndex + 1) % delayFrameCount

            let readValue = Double(read)
            highPassState += (readValue - highPassState) *
                highPassCoefficient
            let highPassed = readValue - highPassState
            lowPassState += (highPassed - lowPassState) * lowPassCoefficient
            let insideOutput = index >= outputStartFrame &&
                index < outputEndFrame
            let gate: Double
            if insideOutput {
                let fadeIn = Double(index - outputStartFrame) /
                    Double(transitionFrames)
                let fadeOut = Double(outputEndFrame - 1 - index) /
                    Double(transitionFrames)
                gate = min(1, max(0, min(fadeIn, fadeOut)))
            } else {
                gate = 0
            }
            result[index] = Float(
                lowPassState * PercussionEchoTextureVoice.returnGain * gate
            )
        }
        return result
    }

    fileprivate func prepare(
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

    private func replacingTexture(
        in source: ResolvedPerformanceBar,
        with articulation: PercussionEchoTextureArticulation?
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
            upperPercussionTailArticulations:
                source.upperPercussionTailArticulations,
            modalPercussionArticulations:
                source.modalPercussionArticulations,
            spatialContrast: source.spatialContrast,
            narrative: source.narrative,
            kickSyntaxRole: source.kickSyntaxRole,
            climaxHang: source.climaxHang,
            percussionEchoTexture: articulation,
            harmonicDisclosureRelationship:
                source.harmonicDisclosureRelationship,
            kickMorphology: source.kickMorphology
        )
    }

    private func replacingBars(
        in source: AutonomousPhrasePlan,
        with bars: [ResolvedPerformanceBar]
    ) -> AutonomousPhrasePlan {
        AutonomousPhrasePlan(
            phraseIndex: source.phraseIndex,
            startBar: source.startBar,
            barCount: source.barCount,
            kind: source.kind,
            scene: source.scene,
            dna: source.dna,
            resolvedBars: bars,
            openedDebt: source.openedDebt,
            paidDebtIDs: source.paidDebtIDs,
            requestsTopologyMutation: source.requestsTopologyMutation,
            interest: source.interest,
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
        )
    }
}

/// Swift Testing executes `@Test` bodies on a bounded cooperative-task stack.
/// This synchronous end-to-end preparation intentionally exercises the full
/// canonical transaction and therefore runs on XCTest's normal test thread.
/// The production path and every asserted contract remain unchanged.
final class PercussionEchoTexturePreparedEvidenceTests: XCTestCase {
    func testPreparedProductEvidence() throws {
        let helper = PercussionEchoTextureTests()
        let fixture = try XCTUnwrap(helper.activePlanFixture())
        let prepared = try XCTUnwrap(helper.prepare(
            fixture.plan,
            state: fixture.state
        ))

        XCTAssertTrue(prepared.candidateEvaluation.isComplete)
        XCTAssertTrue(prepared.selectedCandidateEvidence.isComplete)
        XCTAssertTrue(prepared.commitEligible)

        let evidence = prepared.selectedCandidateEvidence
        let selected = fixture.plan
        XCTAssertEqual(
            evidence.percussionEchoTexture.count,
            selected.resolvedBars.count
        )
        XCTAssertEqual(
            evidence.percussionEchoTexture.map(\.bar),
            selected.resolvedBars.map { $0.performance.bar }
        )
        XCTAssertTrue(evidence.percussionEchoTexture.allSatisfy {
            $0.renderPassesMatch && $0.bindingValid && $0.finite
        })
        let active = evidence.percussionEchoTexture.filter(\.active)
        XCTAssertFalse(active.isEmpty)
        XCTAssertTrue(active.allSatisfy {
            $0.inputPeak > 0 && $0.inputRMS > 0 &&
                $0.returnPeak > 0 && $0.returnRMS > 0 &&
                $0.inputNonzeroSampleCount > 0 &&
                $0.returnNonzeroSampleCount > 0 &&
                $0.outOfWindowNonzeroSampleCount == 0 &&
                $0.firstOutputSampleBitPattern & 0x7fff_ffff == 0 &&
                $0.lastOutputSampleBitPattern & 0x7fff_ffff == 0
        })
        XCTAssertTrue(prepared.blocks.contains { block in
            block.effects.contains {
                $0.kind == .percussionEchoTexture && $0.active
            }
        })
    }
}
