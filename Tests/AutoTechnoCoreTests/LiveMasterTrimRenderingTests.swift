import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Live master trim terminal rendering")
struct LiveMasterTrimRenderingTests {
    @Test("Zero trim preserves exact terminal PCM")
    func zeroTrimPreservesExactPCM() throws {
        let render = try render(trimDB: 0)

        for block in render.blocks {
            let evidence = block.liveMasterTrimRenderEvidence
            let emittedFingerprint = ExactPCMFingerprint.stereo(
                left: block.left,
                right: block.right
            )
            #expect(evidence.requestedTrimDB == 0)
            #expect(evidence.appliedTrimDB == 0)
            #expect(evidence.appliedGain == 1)
            #expect(evidence.preTrimStereoSampleHash == emittedFingerprint)
            #expect(evidence.postTrimStereoSampleHash == emittedFingerprint)
            #expect(evidence.preTrimNonzeroSampleCount ==
                    evidence.postTrimNonzeroSampleCount)
            #expect(evidence.exactScaleMatches)
        }
    }

    @Test("Negative trim scales only the terminal stereo samples")
    func minusTrimScalesTerminalStereoOnly() throws {
        let home = try render(trimDB: 0)
        let attenuated = try render(trimDB: -1.25)
        let gain = pow(10.0, -1.25 / 20.0)

        #expect(home.blocks.count == attenuated.blocks.count)
        for (source, output) in zip(home.blocks, attenuated.blocks) {
            #expect(source.left.count == output.left.count)
            #expect(source.right.count == output.right.count)
            for (preTrim, postTrim) in zip(source.left, output.left) {
                let expected = Float(Double(preTrim) * gain)
                #expect(postTrim.bitPattern == expected.bitPattern)
            }
            for (preTrim, postTrim) in zip(source.right, output.right) {
                let expected = Float(Double(preTrim) * gain)
                #expect(postTrim.bitPattern == expected.bitPattern)
            }

            let evidence = output.liveMasterTrimRenderEvidence
            #expect(evidence.requestedTrimDB == -1.25)
            #expect(evidence.appliedTrimDB == -1.25)
            #expect(evidence.appliedGain == gain)
            #expect(evidence.preTrimStereoSampleHash ==
                    ExactPCMFingerprint.stereo(left: source.left, right: source.right))
            #expect(evidence.postTrimStereoSampleHash ==
                    ExactPCMFingerprint.stereo(left: output.left, right: output.right))
            #expect(evidence.exactScaleMatches)
        }
    }

    @Test("Live master trim does not change role and stem evidence")
    func trimDoesNotChangeRoleStemEvidence() throws {
        let home = try render(trimDB: 0)
        let attenuated = try render(trimDB: -2)

        for (source, output) in zip(home.blocks, attenuated.blocks) {
            #expect(source.masking == output.masking)
            #expect(source.stemObservations == output.stemObservations)
            #expect(source.protectedFoundationSampleHash ==
                    output.protectedFoundationSampleHash)
            #expect(source.percussionSampleHash == output.percussionSampleHash)
            #expect(source.dryModalPercussionSampleHash ==
                    output.dryModalPercussionSampleHash)
            #expect(source.groovePulseRenderEvidence ==
                    output.groovePulseRenderEvidence)
            #expect(source.closedHatRenderEvidence == output.closedHatRenderEvidence)
            #expect(source.instrumentRenderEvidence ==
                    output.instrumentRenderEvidence)
            #expect(source.upperNoteRenderEvidence == output.upperNoteRenderEvidence)
            #expect(source.upperTimingRenderEvidence == output.upperTimingRenderEvidence)
        }
    }

    @Test("Live master trim does not change internal dynamics")
    func trimDoesNotChangeInternalDynamics() throws {
        let home = try render(trimDB: 0)
        let attenuated = try render(trimDB: -2.5)

        for (source, output) in zip(home.blocks, attenuated.blocks) {
            #expect(source.kickMix == output.kickMix)
            #expect(source.automaticMix == output.automaticMix)
            #expect(source.busStates == output.busStates)
            #expect(source.stemReconstruction == output.stemReconstruction)
            #expect(source.graphInputRemainderTimbreEvidence ==
                    output.graphInputRemainderTimbreEvidence)
            #expect(source.postGraphRemainderTimbreEvidence ==
                    output.postGraphRemainderTimbreEvidence)
        }
        #expect(home.renderState.masterEnvelope ==
                attenuated.renderState.masterEnvelope)
        #expect(home.renderState.lowBandEnvelope ==
                attenuated.renderState.lowBandEnvelope)
        #expect(home.renderState.highBandEnvelope ==
                attenuated.renderState.highBandEnvelope)
        #expect(home.renderState.automaticMixState ==
                attenuated.renderState.automaticMixState)
        #expect(home.graphState == attenuated.graphState)
    }

    @Test("Committed trim persists across bars")
    func trimPersistsAcrossBars() throws {
        let render = try render(trimDB: -0.75, barCount: 2)

        #expect(render.blocks.count == 2)
        #expect(render.blocks.allSatisfy {
            $0.liveMasterTrimRenderEvidence.appliedTrimDB == -0.75 &&
                $0.liveMasterTrimRenderEvidence.exactScaleMatches
        })
        #expect(render.renderState.liveMasterHeadroomState.committedTrimDB == -0.75)
        #expect(render.renderState.liveMasterHeadroomState.revision == 7)
    }

    @Test("A RenderBlock copy preserves required terminal trim evidence")
    func trimmedRenderBlockCopyPreservesRequiredEvidence() throws {
        let source = try #require(render(trimDB: -1.5).blocks.first)
        let copy = copying(source)

        #expect(copy.left == source.left)
        #expect(copy.right == source.right)
        #expect(copy.liveMasterTrimRenderEvidence ==
                source.liveMasterTrimRenderEvidence)
        #expect(copy.liveMasterTrimRenderEvidence.appliedTrimDB == -1.5)
        #expect(copy.liveMasterTrimRenderEvidence.preTrimStereoSampleHash !=
                copy.liveMasterTrimRenderEvidence.postTrimStereoSampleHash)
    }

    private func render(trimDB: Double, barCount: Int = 1) throws -> (
        blocks: [RenderBlock],
        renderState: RenderState,
        graphState: GeneratedDSPContinuationState
    ) {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let source = director.plan(from: director.initialState())
        let resolvedBars = Array(source.resolvedBars.prefix(barCount))
        let plan = AutonomousPhrasePlan(
            phraseIndex: source.phraseIndex,
            startBar: source.startBar,
            barCount: resolvedBars.count,
            kind: source.kind,
            scene: source.scene,
            dna: source.dna,
            resolvedBars: resolvedBars,
            openedDebt: source.openedDebt,
            paidDebtIDs: source.paidDebtIDs,
            requestsTopologyMutation: source.requestsTopologyMutation,
            interest: source.interest,
            endingInterlockState: source.endingInterlockState,
            endingSpatialContrastState: source.endingSpatialContrastState,
            endingNarrativeState: source.endingNarrativeState,
            harmonicContinuation: source.incomingHarmonicContinuation
        )
        let graph = DSPGraphGenerator.safePlan(sessionSeed: plan.dna.sceneSeed)
        var renderState = RenderState()
        renderState.liveMasterHeadroomState = liveState(trimDB: trimDB)
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &renderState,
            graphState: &graphState
        )
        return (blocks, renderState, graphState)
    }

    private func liveState(trimDB: Double) -> LiveMasterHeadroomContinuationState {
        LiveMasterHeadroomContinuationState(
            revision: 7,
            committedTrimDB: trimDB,
            consecutiveCleanWindows: 1,
            lastProposalFingerprint: "proposal-7",
            lastObservationFingerprint: "observation-7",
            lastAcceptedSourcePhraseIndex: 4,
            earliestEligibleFutureSample: 64_000
        )
    }

    private func copying(_ source: RenderBlock) -> RenderBlock {
        RenderBlock(
            bar: source.bar,
            section: source.section,
            left: source.left,
            right: source.right,
            events: source.events,
            modulation: source.modulation,
            busStates: source.busStates,
            masking: source.masking,
            effects: source.effects,
            kickMix: source.kickMix,
            kickRenderPassesMatch: source.kickRenderPassesMatch,
            stemObservations: source.stemObservations,
            automaticMix: source.automaticMix,
            stemReconstruction: source.stemReconstruction,
            protectedFoundationSampleHash: source.protectedFoundationSampleHash,
            percussionSampleHash: source.percussionSampleHash,
            protectedRhythmSampleHash: source.protectedRhythmSampleHash,
            dryModalPercussionSampleHash: source.dryModalPercussionSampleHash,
            modalPercussionRenderEvidence: source.modalPercussionRenderEvidence,
            modalPercussionRenderPassesMatch:
                source.modalPercussionRenderPassesMatch,
            modalPercussionFoundationRoutingValid:
                source.modalPercussionFoundationRoutingValid,
            groovePulseRenderEvidence: source.groovePulseRenderEvidence,
            closedHatRenderEvidence: source.closedHatRenderEvidence,
            instrumentRenderEvidence: source.instrumentRenderEvidence,
            percussionEchoTextureRenderEvidence:
                source.percussionEchoTextureRenderEvidence,
            percussionEchoTextureRenderPassesMatch:
                source.percussionEchoTextureRenderPassesMatch,
            audioSliceRenderEvidence: source.audioSliceRenderEvidence,
            audioSliceRenderPassesMatch: source.audioSliceRenderPassesMatch,
            polyphonicPadRenderEvidence: source.polyphonicPadRenderEvidence,
            pulseEchoReturnDriveRenderEvidence:
                source.pulseEchoReturnDriveRenderEvidence,
            spatialFDNRenderEvidence: source.spatialFDNRenderEvidence,
            liveMasterTrimRenderEvidence: source.liveMasterTrimRenderEvidence,
            upperNoteRenderEvidence: source.upperNoteRenderEvidence,
            upperTimingRenderEvidence: source.upperTimingRenderEvidence,
            graphInputRemainderTimbreEvidence:
                source.graphInputRemainderTimbreEvidence,
            postGraphRemainderTimbreEvidence:
                source.postGraphRemainderTimbreEvidence,
            resolvedPerformance: source.resolvedPerformance,
            sceneDNA: source.sceneDNA,
            synthWorld: source.synthWorld,
            synthPerformance: source.synthPerformance
        )
    }
}
