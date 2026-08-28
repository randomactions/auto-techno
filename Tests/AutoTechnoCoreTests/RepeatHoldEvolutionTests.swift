import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Bounded repeat hold evolution", .serialized)
struct RepeatHoldEvolutionTests {
    @Test("Core activates only the qualified fallback after two repeats")
    func boundaryPolicyIsBounded() {
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 1,
            successorPrepared: false,
            qualifiedVariantAvailable: true
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 2,
            successorPrepared: false,
            qualifiedVariantAvailable: true
        ) == .qualifiedLowPass)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9,
            successorPrepared: true,
            qualifiedVariantAvailable: true
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9,
            successorPrepared: false,
            qualifiedVariantAvailable: false
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9,
            successorPrepared: false,
            qualifiedVariantAvailable: true,
            exactAcceptedPCMRequired: true
        ) == .exactAcceptedPCM)
        #expect(!RepeatHoldEvolutionPlaybackMode.qualifiedLowPass
            .participatesInCanonicalLiveFeedback)
    }

    @Test("Filter movement is deterministic and exact at phrase endpoints")
    func filterIsDeterministicAndBoundaryNeutral() throws {
        let sampleRate = 48_000.0
        let frameCount = 8_192
        let left = (0..<frameCount).map {
            sample(
                index: $0,
                sampleRate: sampleRate,
                lowFrequency: 330,
                lowGain: 0.18,
                highFrequency: 7_000,
                highGain: 0.08
            )
        }
        let right = (0..<frameCount).map {
            sample(
                index: $0,
                sampleRate: sampleRate,
                lowFrequency: 440,
                lowGain: 0.16,
                highFrequency: 6_200,
                highGain: 0.07
            )
        }
        var first = RepeatHoldEvolutionFilterState(
            sampleRate: sampleRate,
            totalFrameCount: frameCount
        )
        var second = RepeatHoldEvolutionFilterState(
            sampleRate: sampleRate,
            totalFrameCount: frameCount
        )
        let neverCancelled: @Sendable () -> Bool = { false }
        let renderedAResult = first.process(
            left: left,
            right: right,
            cancellationRequested: neverCancelled
        )
        let renderedBResult = second.process(
            left: left,
            right: right,
            cancellationRequested: neverCancelled
        )
        let renderedA = try #require(renderedAResult)
        let renderedB = try #require(renderedBResult)

        #expect(renderedA.left == renderedB.left)
        #expect(renderedA.right == renderedB.right)
        #expect(renderedA.left.first?.bitPattern == left.first?.bitPattern)
        #expect(renderedA.right.first?.bitPattern == right.first?.bitPattern)
        #expect(renderedA.left.last?.bitPattern == left.last?.bitPattern)
        #expect(renderedA.right.last?.bitPattern == right.last?.bitPattern)
        #expect(ExactPCMFingerprint.stereo(
            left: renderedA.left,
            right: renderedA.right
        ) != ExactPCMFingerprint.stereo(left: left, right: right))
    }

    @Test("Prepared phrase retains one independently qualified hold variant")
    func preparedVariantIsQualified() throws {
        // Seed 19 deterministically resolves an upper-rich opening phrase, so
        // the graph-remainder-only filter has a meaningful audible target.
        let director = AutonomousSessionDirector(rootSeed: 19)
        let state = director.initialState()
        let neverCancelled: @Sendable () -> Bool = { false }
        let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: director.plan(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 44_100,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            pendingLiveMasterBinding: nil,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: neverCancelled
        )
        let prepared = try #require(preparedResult)
        let preparationEvidence = prepared.repeatHoldEvolutionEvidence
        #expect(preparationEvidence.qualified)
        let variant = try #require(prepared.repeatHoldEvolution)
        let evidence = variant.evidence

        #expect(evidence.version == RepeatHoldEvolutionContract.version)
        #expect(evidence.qualified)
        #expect(evidence.signalSafetyValid)
        #expect(evidence.endpointsExact)
        #expect(evidence.protectedRoutingExact)
        #expect(evidence.highBandReductionDB >=
            RepeatHoldEvolutionDSPContract.minimumHighBandReductionDB)
        #expect(evidence.loudnessDeltaDB <=
            RepeatHoldEvolutionDSPContract.maximumLoudnessIncreaseDB)
        #expect(evidence.primarySampleHash ==
            prepared.audioPreflight.quality.sampleHash)
        #expect(evidence.variantSampleHash != evidence.primarySampleHash)
        #expect(variant.blocks.count == prepared.blocks.count)
        #expect(zip(prepared.blocks, variant.blocks).allSatisfy {
            $0.0.protectedRhythmSampleHash ==
                $0.1.protectedRhythmSampleHash
        })
    }

    private func sample(
        index: Int,
        sampleRate: Double,
        lowFrequency: Double,
        lowGain: Double,
        highFrequency: Double,
        highGain: Double
    ) -> Float {
        let time = Double(index) / sampleRate
        let low = sin(2 * Double.pi * lowFrequency * time) * lowGain
        let high = sin(2 * Double.pi * highFrequency * time) * highGain
        return Float(low + high)
    }
}
